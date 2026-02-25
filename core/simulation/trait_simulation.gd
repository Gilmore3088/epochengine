class_name TraitSimulation
extends RefCounted

## Trait Evolution Engine.
## Evolves civilization personality biases based on game events.
## Called after hero aging + golden age evaluation (Step 8.5).
## Returns Array[Dictionary] of trait change events for the chronicle.

const BIAS_NAMES: Array[String] = [
	"expansion_bias", "aggression_bias", "diplomacy_bias", "economy_bias"
]

const BIAS_DISPLAY_NAMES: Dictionary = {
	"expansion_bias": "Expansion",
	"aggression_bias": "Aggression",
	"diplomacy_bias": "Diplomacy",
	"economy_bias": "Economy",
}


static func evolve_traits(
	civ: CivilizationData, events_this_turn: Dictionary
) -> Array[Dictionary]:
	## Main entry point. Scans turn events for mutation triggers,
	## applies hero influence and annual drift.
	## Returns trait_change events (only tag-crossing ones).
	var trait_events: Array[Dictionary] = []

	# 1) Event-driven mutations
	trait_events.append_array(_process_battle_events(civ, events_this_turn))
	trait_events.append_array(_process_golden_age_events(civ, events_this_turn))
	trait_events.append_array(_process_expansion_events(civ, events_this_turn))
	trait_events.append_array(_process_diplomacy_events(civ, events_this_turn))
	trait_events.append_array(_process_era_events(civ, events_this_turn))

	# 2) Long peace detection
	trait_events.append_array(_process_long_peace(civ))

	# 3) Hero influence (passive per-year effect)
	trait_events.append_array(_hero_influence(civ))

	# 4) Annual random drift
	trait_events.append_array(_annual_drift(civ))

	return trait_events


static func _apply_mutation(
	civ: CivilizationData, bias_name: String, delta: float, reason: String
) -> Dictionary:
	## Apply a bias mutation. Returns event dict if a tag threshold is crossed.
	## Empty dict if no tag change (mutation still applied silently).
	var old_value: float = civ.get(bias_name)
	var old_tag := _get_tag_for_bias(bias_name, old_value)

	var new_value := clampf(old_value + delta, Constants.TRAIT_MIN, Constants.TRAIT_MAX)
	civ.set(bias_name, new_value)

	var new_tag := _get_tag_for_bias(bias_name, new_value)

	if old_tag != new_tag:
		return {
			"type": "trait_changed",
			"civ_id": civ.id,
			"civ_name": civ.civ_name,
			"bias_name": bias_name,
			"bias_display": BIAS_DISPLAY_NAMES.get(bias_name, bias_name),
			"old_value": old_value,
			"new_value": new_value,
			"old_tag": old_tag,
			"new_tag": new_tag,
			"reason": reason,
		}

	return {}


static func _get_tag_for_bias(bias_name: String, value: float) -> String:
	## Returns the personality tag for a specific bias value.
	if value >= Constants.TRAIT_TAG_HIGH_THRESHOLD:
		match bias_name:
			"expansion_bias": return "Expansionist"
			"aggression_bias": return "Warlike"
			"diplomacy_bias": return "Diplomatic"
			"economy_bias": return "Mercantile"
	elif value <= Constants.TRAIT_TAG_LOW_THRESHOLD:
		match bias_name:
			"expansion_bias": return "Insular"
			"aggression_bias": return "Pacifist"
			"diplomacy_bias": return "Isolationist"
			"economy_bias": return "Austere"
	return ""


# --- Event-Driven Mutations ---


static func _process_battle_events(
	civ: CivilizationData, events: Dictionary
) -> Array[Dictionary]:
	## Win battle: +aggression. Lose: -aggression, +diplomacy.
	var results: Array[Dictionary] = []
	for battle in events.get("battles", []):
		if battle["attacker_id"] != civ.id and battle["defender_id"] != civ.id:
			continue
		var won: bool = battle["winner_id"] == civ.id
		if won:
			var evt := _apply_mutation(
				civ, "aggression_bias",
				Constants.TRAIT_BATTLE_WIN_AGGRESSION,
				"Won battle for %s" % battle.get("region_name", "unknown")
			)
			if not evt.is_empty():
				results.append(evt)
		else:
			var evt1 := _apply_mutation(
				civ, "aggression_bias",
				Constants.TRAIT_BATTLE_LOSE_AGGRESSION,
				"Lost battle for %s" % battle.get("region_name", "unknown")
			)
			if not evt1.is_empty():
				results.append(evt1)
			var evt2 := _apply_mutation(
				civ, "diplomacy_bias",
				Constants.TRAIT_BATTLE_LOSE_DIPLOMACY,
				"Lost battle for %s" % battle.get("region_name", "unknown")
			)
			if not evt2.is_empty():
				results.append(evt2)
	return results


static func _process_golden_age_events(
	civ: CivilizationData, events: Dictionary
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	# Golden age start: reinforce dominant bias
	for ga in events.get("golden_age_starts", []):
		if ga["civ_id"] != civ.id:
			continue
		var dominant := civ.get_dominant_bias_name()
		var evt := _apply_mutation(
			civ, dominant,
			Constants.TRAIT_GOLDEN_AGE_START_REINFORCE,
			"Golden Age reinforces %s" % BIAS_DISPLAY_NAMES.get(dominant, dominant)
		)
		if not evt.is_empty():
			results.append(evt)

	# Golden age end: regress all biases toward 0.5
	for ga in events.get("golden_age_ends", []):
		if ga["civ_id"] != civ.id:
			continue
		for bias_name in BIAS_NAMES:
			var current: float = civ.get(bias_name)
			if absf(current - 0.5) < 0.02:
				continue
			var direction := signf(0.5 - current)
			var evt := _apply_mutation(
				civ, bias_name,
				Constants.TRAIT_GOLDEN_AGE_END_REGRESS * direction,
				"Golden Age ended"
			)
			if not evt.is_empty():
				results.append(evt)
	return results


static func _process_expansion_events(
	civ: CivilizationData, events: Dictionary
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for ai_event in events.get("ai_events", []):
		if ai_event.get("civ_id", -1) != civ.id:
			continue
		if ai_event.get("type", "") == "expansion":
			var evt := _apply_mutation(
				civ, "expansion_bias",
				Constants.TRAIT_EXPANSION_CAPTURE,
				"Expanded into %s" % ai_event.get("region_name", "unknown")
			)
			if not evt.is_empty():
				results.append(evt)
	return results


static func _process_diplomacy_events(
	civ: CivilizationData, events: Dictionary
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for ai_event in events.get("ai_events", []):
		var event_type: String = ai_event.get("type", "")
		if event_type == "alliance_formed":
			if ai_event.get("civ_a_id", -1) == civ.id or ai_event.get("civ_b_id", -1) == civ.id:
				var evt := _apply_mutation(
					civ, "diplomacy_bias",
					Constants.TRAIT_ALLIANCE_FORMED_DIPLOMACY,
					"Formed alliance"
				)
				if not evt.is_empty():
					results.append(evt)
		elif event_type == "alliance_broken":
			if ai_event.get("civ_a_id", -1) == civ.id or ai_event.get("civ_b_id", -1) == civ.id:
				var evt := _apply_mutation(
					civ, "diplomacy_bias",
					Constants.TRAIT_ALLIANCE_BROKEN_DIPLOMACY,
					"Broke alliance"
				)
				if not evt.is_empty():
					results.append(evt)
	return results


static func _process_era_events(
	civ: CivilizationData, events: Dictionary
) -> Array[Dictionary]:
	## Era transitions moderate extreme biases toward 0.5.
	var results: Array[Dictionary] = []
	for era_event in events.get("era_changes", []):
		if era_event.get("civ_id", -1) != civ.id:
			continue
		for bias_name in BIAS_NAMES:
			var current: float = civ.get(bias_name)
			if current >= Constants.TRAIT_ERA_EXTREME_THRESHOLD:
				var evt := _apply_mutation(
					civ, bias_name,
					-Constants.TRAIT_ERA_MODERATION,
					"Era transition moderates extremism"
				)
				if not evt.is_empty():
					results.append(evt)
			elif current <= (1.0 - Constants.TRAIT_ERA_EXTREME_THRESHOLD):
				var evt := _apply_mutation(
					civ, bias_name,
					Constants.TRAIT_ERA_MODERATION,
					"Era transition moderates extremism"
				)
				if not evt.is_empty():
					results.append(evt)
	return results


static func _process_long_peace(civ: CivilizationData) -> Array[Dictionary]:
	## Track years at peace. At threshold, shift aggression down, economy up.
	var results: Array[Dictionary] = []
	if civ.is_at_war():
		civ.years_at_peace = 0
	else:
		civ.years_at_peace += 1

	if civ.years_at_peace >= Constants.TRAIT_LONG_PEACE_YEARS:
		var evt1 := _apply_mutation(
			civ, "aggression_bias",
			Constants.TRAIT_LONG_PEACE_AGGRESSION,
			"%d years of peace" % civ.years_at_peace
		)
		if not evt1.is_empty():
			results.append(evt1)
		var evt2 := _apply_mutation(
			civ, "economy_bias",
			Constants.TRAIT_LONG_PEACE_ECONOMY,
			"%d years of peace" % civ.years_at_peace
		)
		if not evt2.is_empty():
			results.append(evt2)
		civ.years_at_peace = 0
	return results


static func _hero_influence(civ: CivilizationData) -> Array[Dictionary]:
	## Active heroes passively nudge biases each year.
	var results: Array[Dictionary] = []
	for hero_id in civ.hero_ids:
		var hero: HeroData = GameState.get_hero(hero_id)
		if not hero:
			continue
		match hero.type:
			Enums.HeroType.GENERAL:
				var evt := _apply_mutation(
					civ, "aggression_bias",
					Constants.TRAIT_HERO_INFLUENCE_PER_YEAR,
					"General %s inspires militarism" % hero.hero_name
				)
				if not evt.is_empty():
					results.append(evt)
			Enums.HeroType.REFORMER:
				var evt := _apply_mutation(
					civ, "diplomacy_bias",
					Constants.TRAIT_HERO_INFLUENCE_PER_YEAR,
					"Reformer %s promotes diplomacy" % hero.hero_name
				)
				if not evt.is_empty():
					results.append(evt)
			Enums.HeroType.VISIONARY:
				var evt := _apply_mutation(
					civ, "economy_bias",
					Constants.TRAIT_HERO_INFLUENCE_PER_YEAR,
					"Visionary %s drives commerce" % hero.hero_name
				)
				if not evt.is_empty():
					results.append(evt)
	return results


static func _annual_drift(civ: CivilizationData) -> Array[Dictionary]:
	## Small random walk each year for organic personality evolution.
	var results: Array[Dictionary] = []
	var idx := GameState.sim_rng.randi() % BIAS_NAMES.size()
	var bias_name: String = BIAS_NAMES[idx]
	var direction := 1.0 if GameState.sim_rng.randf() < 0.5 else -1.0
	var evt := _apply_mutation(
		civ, bias_name,
		Constants.TRAIT_ANNUAL_DRIFT_MAGNITUDE * direction,
		"Natural drift"
	)
	if not evt.is_empty():
		results.append(evt)
	return results
