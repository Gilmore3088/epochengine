class_name AILogic
extends RefCounted

## AI decision-making based on weighted probabilities.
## Logic from docs/systems/ai_behavior.md


static func make_decisions(civ: CivilizationData) -> void:
	## Executes AI decisions for one civilization for this turn.
	if civ.is_collapsed:
		return

	var state := civ.get_state()

	match state:
		Enums.CivState.DECLINING:
			_try_seek_peace(civ)
		Enums.CivState.STABLE:
			_try_expand(civ)
		Enums.CivState.GROWING:
			_try_expand(civ)
			_try_declare_war(civ)


static func _try_expand(civ: CivilizationData) -> void:
	## Attempt to expand into adjacent neutral regions.
	if civ.stability < Constants.AI_EXPANSION_STABILITY_THRESHOLD:
		return
	if civ.food_stockpile <= 0:
		return

	var targets := GameState.get_adjacent_targets(civ.id)
	var neutral_targets: Array[RegionData] = []
	for target in targets:
		if target.is_neutral():
			neutral_targets.append(target)

	if neutral_targets.is_empty():
		return

	# Weighted by expansion bias
	var expand_roll := randf()
	if expand_roll > civ.expansion_bias:
		return

	# Pick highest food_yield neutral region
	neutral_targets.sort_custom(func(a: RegionData, b: RegionData) -> bool:
		return a.food_yield > b.food_yield
	)

	var target := neutral_targets[0]
	var old_owner := target.owner_id
	target.owner_id = civ.id
	target.population = maxi(target.population, 200)

	EventBus.region_owner_changed.emit(target.id, old_owner, civ.id)
	EventBus.ai_decision_made.emit(civ.id, "expand", {"region": target.region_name})
	GameState.log_event("expansion", {
		"civ": civ.civ_name,
		"region": target.region_name,
	})


static func _try_declare_war(civ: CivilizationData) -> void:
	## Attempt to declare war on a weaker neighbor.
	if civ.stability < Constants.WAR_DECLARATION_STABILITY_THRESHOLD:
		return

	var neighbor_ids := GameState.get_neighboring_civs(civ.id)
	for neighbor_id in neighbor_ids:
		if civ.war_targets.has(neighbor_id):
			continue
		if civ.alliance_partners.has(neighbor_id):
			continue

		var neighbor := GameState.get_civilization(neighbor_id)
		if not neighbor or neighbor.is_collapsed:
			continue

		# Must be significantly stronger
		if civ.military_strength < neighbor.military_strength * Constants.WAR_DECLARATION_STRENGTH_RATIO:
			continue

		var strength_ratio := civ.military_strength / maxf(neighbor.military_strength, 1.0)
		var war_chance := 0.1 * strength_ratio * civ.aggression_bias * randf()

		if war_chance > 0.3:
			civ.war_targets.append(neighbor_id)
			neighbor.war_targets.append(civ.id)

			EventBus.war_declared.emit(civ.id, neighbor_id)
			EventBus.ai_decision_made.emit(civ.id, "declare_war", {
				"target": neighbor.civ_name,
			})
			GameState.log_event("war_declared", {
				"attacker": civ.civ_name,
				"defender": neighbor.civ_name,
			})
			return  # Only declare one war per turn


static func _try_seek_peace(civ: CivilizationData) -> void:
	## Attempt to end wars when stability is critically low.
	if civ.war_targets.is_empty():
		return

	var peace_chance := (1.0 - civ.stability / Constants.STABILITY_MAX) * civ.diplomacy_bias
	if randf() < peace_chance:
		var target_id: int = civ.war_targets[0]
		var target := GameState.get_civilization(target_id)

		civ.war_targets.erase(target_id)
		if target:
			target.war_targets.erase(civ.id)
			EventBus.peace_declared.emit(civ.id, target_id)
			GameState.log_event("peace", {
				"civ_a": civ.civ_name,
				"civ_b": target.civ_name,
			})
