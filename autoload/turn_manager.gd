extends Node

## Thin orchestrator that delegates simulation to SimulationEngine
## and bridges results to the presentation layer via EventBus signals.

var is_turn_processing: bool = false


func advance_year() -> void:
	## Execute one full simulation year and emit all events as signals.
	if is_turn_processing:
		return

	is_turn_processing = true
	GameState.current_year += 1
	GameState.clear_turn_log()

	EventBus.turn_started.emit(GameState.current_year)

	# Run pure simulation - returns all events for the year
	var events := SimulationEngine.process_year()

	# Bridge simulation events to presentation signals
	_emit_events(events)

	# Update fog of war visibility (after all events processed, before visual refresh)
	GameState.update_all_visibility()
	EventBus.visibility_updated.emit()

	EventBus.turn_ended.emit(GameState.current_year)
	is_turn_processing = false


func advance_years(count: int) -> void:
	## Fast-forward multiple years.
	for i in range(count):
		advance_year()


# --- Event Bridge: Simulation -> Presentation ---

func _emit_events(events: Dictionary) -> void:
	# Population changes
	for change in events["population_changes"]:
		EventBus.population_changed.emit(
			change["region_id"], change["old_pop"], change["new_pop"]
		)

	# Economy results (shortages)
	for result in events["economy_results"]:
		var civ_id: int = result["civ_id"]
		if result["food_shortage"]:
			var stockpile: int = GameState.get_civilization(civ_id).food_stockpile
			EventBus.food_shortage.emit(civ_id, stockpile)
			GameState.log_event("food_shortage", {
				"civ": result["civ_name"], "stockpile": stockpile,
			})
			History.record_event({
				"year": GameState.current_year, "type": "shortage",
				"civ_id": civ_id, "civ_name": result["civ_name"],
				"description": "%s: food shortage (%d)" % [result["civ_name"], stockpile],
			})
		if result["prod_shortage"]:
			var stockpile: int = GameState.get_civilization(civ_id).production_stockpile
			EventBus.production_shortage.emit(civ_id, stockpile)
			GameState.log_event("production_shortage", {
				"civ": result["civ_name"], "stockpile": stockpile,
			})
			History.record_event({
				"year": GameState.current_year, "type": "shortage",
				"civ_id": civ_id, "civ_name": result["civ_name"],
				"description": "%s: production shortage (%d)" % [result["civ_name"], stockpile],
			})

	# Stability changes
	for change in events["stability_changes"]:
		EventBus.stability_changed.emit(
			change["civ_id"], change["old_stability"], change["new_stability"]
		)

	# Legitimacy changes
	for change in events.get("legitimacy_changes", []):
		EventBus.legitimacy_changed.emit(
			change["civ_id"], change["old_legitimacy"], change["new_legitimacy"]
		)
		var delta: float = float(change["new_legitimacy"]) - float(change["old_legitimacy"])
		if absf(delta) >= 5.0:
			History.record_event({
				"year": GameState.current_year, "type": "legitimacy_shift",
				"civ_id": change["civ_id"], "civ_name": change["civ_name"],
				"description": "%s legitimacy %s%.0f" % [
					change["civ_name"], "+" if delta > 0 else "", delta
				],
			})

	# Record stability for all alive civs every year (for trend accuracy)
	for civ in GameState.get_alive_civilizations():
		History.record_stability(civ.id, GameState.current_year, civ.stability)
		History.record_legitimacy(civ.id, GameState.current_year, civ.legitimacy)

	# Collapses
	for collapse in events["collapses"]:
		EventBus.civilization_collapsed.emit(collapse["civ_id"])
		GameState.log_event("collapse", {"civ": collapse["civ_name"]})
		History.record_event({
			"year": GameState.current_year, "type": "collapse",
			"civ_id": collapse["civ_id"], "civ_name": collapse["civ_name"],
			"description": "%s has collapsed" % collapse["civ_name"],
		})

	# Owner changes (from expansion, battles, collapses)
	for change in events["owner_changes"]:
		EventBus.region_owner_changed.emit(
			change["region_id"], change["old_owner"], change["new_owner"]
		)

	# AI events (expansions, wars, peace, infrastructure)
	for event in events["ai_events"]:
		match event["type"]:
			"expansion":
				EventBus.ai_decision_made.emit(event["civ_id"], "expand", {
					"region": event["region_name"], "cost": event["cost"],
				})
				GameState.log_event("expansion", {
					"civ": event["civ_name"],
					"region": event["region_name"],
					"cost": event["cost"],
				})
				History.record_event({
					"year": GameState.current_year, "type": "expansion",
					"civ_id": event["civ_id"], "civ_name": event["civ_name"],
					"region_id": event["region_id"], "region_name": event["region_name"],
					"description": "%s expands into %s" % [event["civ_name"], event["region_name"]],
				})
			"war_declared":
				EventBus.war_declared.emit(event["attacker_id"], event["defender_id"])
				GameState.log_event("war_declared", {
					"attacker": event["attacker_name"],
					"defender": event["defender_name"],
				})
				History.record_event({
					"year": GameState.current_year, "type": "war_declared",
					"civ_id": event["attacker_id"], "civ_name": event["attacker_name"],
					"description": "%s declares war on %s" % [event["attacker_name"], event["defender_name"]],
				})
			"peace":
				EventBus.peace_declared.emit(event["civ_a_id"], event["civ_b_id"])
				GameState.log_event("peace", {
					"civ_a": event["civ_a_name"],
					"civ_b": event["civ_b_name"],
				})
				History.record_event({
					"year": GameState.current_year, "type": "peace",
					"civ_id": event["civ_a_id"], "civ_name": event["civ_a_name"],
					"description": "%s and %s declare peace" % [event["civ_a_name"], event["civ_b_name"]],
				})
			"infrastructure_upgrade":
				var infra_parts: Array[String] = []
				if event.get("food_delta", 0) != 0:
					infra_parts.append("+%d food" % event["food_delta"])
				if event.get("prod_delta", 0) != 0:
					infra_parts.append("+%d prod" % event["prod_delta"])
				if event.get("def_delta", 0.0) > 0.001:
					infra_parts.append("+%.0f%% def" % (event["def_delta"] * 100))
				if event.get("tier_changed", false):
					infra_parts.append("TIER UP!")
				elif event.get("next_tier_infra_needed", -1) > 0:
					infra_parts.append("%d infra to next tier" % event["next_tier_infra_needed"])
				var infra_detail := " | ".join(infra_parts) if not infra_parts.is_empty() else ""
				EventBus.infrastructure_upgraded.emit(
					event["civ_id"], event["region_name"], event["new_level"]
				)
				var _infra_name: String = event.get("infra_name", "level %d" % event["new_level"])
				var infra_desc: String = "%s builds %s in %s" % [event["civ_name"], _infra_name, event["region_name"]]
				if not infra_detail.is_empty():
					infra_desc += " (%s)" % infra_detail
				GameState.log_event("infrastructure", {
					"civ": event["civ_name"],
					"region": event["region_name"],
					"level": event["new_level"],
					"detail": infra_detail,
				})
				History.record_event({
					"year": GameState.current_year, "type": "infra_upgrade",
					"civ_id": event["civ_id"], "civ_name": event["civ_name"],
					"region_id": event["region_id"], "region_name": event["region_name"],
					"description": infra_desc,
				})
			"town_founded":
				EventBus.town_founded.emit(event["region_id"], event["town_name"])
				GameState.log_event("town_founded", {
					"civ": event["civ_name"],
					"region": event["region_name"],
					"town": event["town_name"],
				})
				History.record_event({
					"year": GameState.current_year, "type": "town_founded",
					"civ_id": event["civ_id"], "civ_name": event["civ_name"],
					"region_id": event["region_id"], "region_name": event["region_name"],
					"description": "%s founds %s in %s" % [event["civ_name"], event["town_name"], event["region_name"]],
				})
			"building_constructed":
				EventBus.building_constructed.emit(
					event["region_id"], event["town_name"], event["building_name"]
				)
				GameState.log_event("building_constructed", {
					"civ": event["civ_name"],
					"region": event["region_name"],
					"town": event["town_name"],
					"building": event["building_name"],
				})
				History.record_event({
					"year": GameState.current_year, "type": "building_constructed",
					"civ_id": event["civ_id"], "civ_name": event["civ_name"],
					"region_id": event["region_id"], "region_name": event["region_name"],
					"description": "%s builds %s in %s" % [event["civ_name"], event["building_name"], event["town_name"]],
				})
			"workforce_preset_changed":
				EventBus.workforce_preset_changed.emit(
					event["region_id"], event["town_name"], event["preset_name"]
				)
				GameState.log_event("workforce_changed", {
					"civ": event["civ_name"],
					"town": event["town_name"],
					"preset": event["preset_name"],
				})
			"research_focus_changed":
				EventBus.research_focus_changed.emit(
					event["civ_id"], event["focus_name"]
				)
				GameState.log_event("research_focus_changed", {
					"civ": event["civ_name"], "focus": event["focus_name"],
				})
			"spending_priority_changed":
				EventBus.spending_priority_changed.emit(
					event["civ_id"], event["priority_name"]
				)
				GameState.log_event("spending_priority_changed", {
					"civ": event["civ_name"], "priority": event["priority_name"],
				})
			"alliance_formed":
				EventBus.alliance_formed.emit(event["civ_a_id"], event["civ_b_id"])
				GameState.log_event("alliance_formed", {
					"civ_a": event["civ_a_name"],
					"civ_b": event["civ_b_name"],
				})
				History.record_event({
					"year": GameState.current_year, "type": "alliance_formed",
					"civ_id": event["civ_a_id"], "civ_name": event["civ_a_name"],
					"description": "%s and %s form alliance" % [event["civ_a_name"], event["civ_b_name"]],
				})
			"alliance_broken":
				EventBus.alliance_broken.emit(event["civ_a_id"], event["civ_b_id"])
				GameState.log_event("alliance_broken", {
					"civ_a": event["civ_a_name"],
					"civ_b": event["civ_b_name"],
				})
				History.record_event({
					"year": GameState.current_year, "type": "alliance_broken",
					"civ_id": event["civ_a_id"], "civ_name": event["civ_a_name"],
					"description": "%s breaks alliance with %s" % [event["civ_a_name"], event["civ_b_name"]],
				})
			"nap_formed":
				EventBus.nap_formed.emit(event["civ_a_id"], event["civ_b_id"])
				GameState.log_event("nap_formed", {
					"civ_a": event["civ_a_name"],
					"civ_b": event["civ_b_name"],
				})
				History.record_event({
					"year": GameState.current_year, "type": "nap_formed",
					"civ_id": event["civ_a_id"], "civ_name": event["civ_a_name"],
					"description": "%s and %s sign non-aggression pact" % [event["civ_a_name"], event["civ_b_name"]],
				})
			"nap_broken":
				EventBus.nap_broken.emit(event["civ_a_id"], event["civ_b_id"])
				GameState.log_event("nap_broken", {
					"civ_a": event["civ_a_name"],
					"civ_b": event["civ_b_name"],
				})
				History.record_event({
					"year": GameState.current_year, "type": "nap_broken",
					"civ_id": event["civ_a_id"], "civ_name": event["civ_a_name"],
					"description": "%s breaks pact with %s" % [event["civ_a_name"], event["civ_b_name"]],
				})
			"trade_formed":
				EventBus.trade_formed.emit(event["civ_a_id"], event["civ_b_id"])
				GameState.log_event("trade_formed", {
					"civ_a": event["civ_a_name"],
					"civ_b": event["civ_b_name"],
				})
				History.record_event({
					"year": GameState.current_year, "type": "trade_formed",
					"civ_id": event["civ_a_id"], "civ_name": event["civ_a_name"],
					"description": "%s and %s establish trade" % [event["civ_a_name"], event["civ_b_name"]],
				})
			"trade_broken":
				EventBus.trade_broken.emit(event["civ_a_id"], event["civ_b_id"])
				GameState.log_event("trade_broken", {
					"civ_a": event["civ_a_name"],
					"civ_b": event["civ_b_name"],
				})
				History.record_event({
					"year": GameState.current_year, "type": "trade_broken",
					"civ_id": event["civ_a_id"], "civ_name": event["civ_a_name"],
					"description": "%s and %s trade collapses" % [event["civ_a_name"], event["civ_b_name"]],
				})
			"tribute_demanded":
				EventBus.tribute_demanded.emit(
					event["demander_id"], event["target_id"], event["accepted"]
				)
				var tribute_result: String = "accepted" if bool(event["accepted"]) else "refused"
				GameState.log_event("tribute_demanded", {
					"demander": event["demander_name"],
					"target": event["target_name"],
					"accepted": event["accepted"],
				})
				History.record_event({
					"year": GameState.current_year, "type": "tribute_demanded",
					"civ_id": event["demander_id"], "civ_name": event["demander_name"],
					"description": "%s demands tribute from %s (%s)" % [event["demander_name"], event["target_name"], tribute_result],
				})

	# Political events (AI-resolved)
	for pe in events.get("political_events", []):
		var desc: String = "%s — %s" % [
			pe.get("title", "Political Event"),
			pe.get("resolved_choice", "Decision"),
		]
		History.record_event({
			"year": pe.get("year", GameState.current_year),
			"type": pe.get("type", "political"),
			"civ_id": pe.get("civ_id", -1),
			"civ_name": pe.get("civ_name", ""),
			"description": desc,
		})

	# Diplomacy tick events (NAP expiry, trade auto-break)
	for diplo_evt in events.get("diplomacy_events", []):
		match diplo_evt["type"]:
			"nap_broken":
				EventBus.nap_broken.emit(diplo_evt["civ_a_id"], diplo_evt["civ_b_id"])
				GameState.log_event("nap_broken", {
					"civ_a": diplo_evt["civ_a_name"],
					"civ_b": diplo_evt["civ_b_name"],
					"reason": diplo_evt.get("reason", ""),
				})
				History.record_event({
					"year": GameState.current_year, "type": "nap_broken",
					"civ_id": diplo_evt["civ_a_id"], "civ_name": diplo_evt["civ_a_name"],
					"description": "%s and %s pact expires" % [diplo_evt["civ_a_name"], diplo_evt["civ_b_name"]],
				})
			"trade_broken":
				EventBus.trade_broken.emit(diplo_evt["civ_a_id"], diplo_evt["civ_b_id"])
				GameState.log_event("trade_broken", {
					"civ_a": diplo_evt["civ_a_name"],
					"civ_b": diplo_evt["civ_b_name"],
					"reason": diplo_evt.get("reason", ""),
				})
				History.record_event({
					"year": GameState.current_year, "type": "trade_broken",
					"civ_id": diplo_evt["civ_a_id"], "civ_name": diplo_evt["civ_a_name"],
					"description": "%s and %s trade collapses (war)" % [diplo_evt["civ_a_name"], diplo_evt["civ_b_name"]],
				})

	# Town auto-spawn events
	for town_event in events["town_events"]:
		EventBus.town_founded.emit(town_event["region_id"], town_event["town_name"])

	# Battles
	for battle in events["battles"]:
		EventBus.battle_resolved.emit(
			battle["region_id"],
			battle["attacker_id"],
			battle["defender_id"],
			battle["winner_id"],
		)
		var winner_name: String = battle["attacker_name"] if battle["winner_id"] == battle["attacker_id"] else battle["defender_name"]
		GameState.log_event("battle", {
			"region": battle["region_name"],
			"attacker": battle["attacker_name"],
			"defender": battle["defender_name"],
			"winner": "attacker" if battle["winner_id"] == battle["attacker_id"] else "defender",
		})
		History.record_event({
			"year": GameState.current_year, "type": "battle",
			"civ_id": battle["winner_id"], "civ_name": winner_name,
			"region_id": battle["region_id"], "region_name": battle["region_name"],
			"description": "%s wins battle for %s" % [winner_name, battle["region_name"]],
		})

	# Dead heroes
	for hero_event in events["dead_heroes"]:
		EventBus.hero_died.emit(hero_event["hero_id"], hero_event["civ_id"])
		GameState.log_event("hero_died", {
			"hero": hero_event["hero_name"],
			"civ": hero_event["civ_name"],
		})
		History.record_event({
			"year": GameState.current_year, "type": "hero_died",
			"civ_id": hero_event["civ_id"], "civ_name": hero_event["civ_name"],
			"description": "%s loses hero %s" % [hero_event["civ_name"], hero_event["hero_name"]],
		})

	# Spawned heroes
	for hero_event in events["spawned_heroes"]:
		EventBus.hero_spawned.emit(
			hero_event["hero_id"], hero_event["civ_id"], hero_event["hero_type"]
		)
		var hero_type_name: String = Enums.HeroType.keys()[hero_event["hero_type"]]
		GameState.log_event("hero_spawned", {
			"hero": hero_event["hero_name"],
			"type": hero_type_name,
			"civ": hero_event["civ_name"],
		})
		History.record_event({
			"year": GameState.current_year, "type": "hero_spawned",
			"civ_id": hero_event["civ_id"], "civ_name": hero_event["civ_name"],
			"description": "%s gains %s %s" % [hero_event["civ_name"], hero_type_name, hero_event["hero_name"]],
		})

	# Golden ages
	for ga in events["golden_age_starts"]:
		EventBus.golden_age_started.emit(ga["civ_id"])
		GameState.log_event("golden_age_started", {"civ": ga["civ_name"]})
		History.record_event({
			"year": GameState.current_year, "type": "golden_age_start",
			"civ_id": ga["civ_id"], "civ_name": ga["civ_name"],
			"description": "%s enters a Golden Age" % ga["civ_name"],
		})
	for ga in events["golden_age_ends"]:
		EventBus.golden_age_ended.emit(ga["civ_id"])
		GameState.log_event("golden_age_ended", {"civ": ga["civ_name"]})
		History.record_event({
			"year": GameState.current_year, "type": "golden_age_end",
			"civ_id": ga["civ_id"], "civ_name": ga["civ_name"],
			"description": "%s Golden Age ended" % ga["civ_name"],
		})

	# Development tier changes
	for change in events["development_tier_changes"]:
		EventBus.development_tier_changed.emit(
			change["region_id"], change["civ_id"],
			change["old_tier"], change["new_tier"]
		)
		GameState.log_event("development_tier_changed", {
			"region": change["region_name"],
			"civ": change["civ_name"],
			"old_tier": change["old_tier"],
			"new_tier": change["new_tier"],
		})
		History.record_event({
			"year": GameState.current_year, "type": "dev_tier_change",
			"civ_id": change["civ_id"], "civ_name": change["civ_name"],
			"region_id": change["region_id"], "region_name": change["region_name"],
			"description": "%s: %s -> %s" % [change["region_name"], change["old_tier"], change["new_tier"]],
		})

	# Resource events
	for res_event in events["resource_events"]:
		var civ_id: int = res_event["civ_id"]
		var civ_name: String = res_event["civ_name"]

		# Maintenance failures
		for penalty in res_event["maintenance_penalties"]:
			var res_name: String = ResourceProduction.get_resource_name(int(penalty["resource"]))
			EventBus.resource_maintenance_failure.emit(
				civ_id, res_name, penalty["missing_inputs"]
			)
			GameState.log_event("maintenance_failure", {
				"civ": civ_name,
				"resource": res_name,
				"missing": penalty["missing_inputs"],
			})
			History.record_event({
				"year": GameState.current_year, "type": "maintenance_failure",
				"civ_id": civ_id, "civ_name": civ_name,
				"description": "%s: %s maintenance failure" % [civ_name, res_name],
			})

		# Deposit depletions
		for depleted in res_event.get("depleted_deposits", []):
			EventBus.resource_deposit_depleted.emit(
				depleted["region_id"], civ_id, depleted["resource_name"]
			)
			GameState.log_event("deposit_depleted", {
				"civ": civ_name,
				"region": depleted["region_name"],
				"resource": depleted["resource_name"],
			})
			History.record_event({
				"year": GameState.current_year, "type": "deposit_depleted",
				"civ_id": civ_id, "civ_name": civ_name,
				"region_id": depleted["region_id"], "region_name": depleted["region_name"],
				"description": "%s deposits depleted in %s" % [depleted["resource_name"], depleted["region_name"]],
			})

	# Tech emergences
	for tech in events["tech_emergences"]:
		EventBus.technology_emerged.emit(tech["civ_id"], tech["tech_name"])
		GameState.log_event("tech_emerged", {
			"civ": tech["civ_name"],
			"tech": tech["tech_name"],
		})
		History.record_event({
			"year": GameState.current_year, "type": "tech",
			"civ_id": tech["civ_id"], "civ_name": tech["civ_name"],
			"description": "%s discovers %s" % [tech["civ_name"], tech["tech_name"]],
		})

	# Era transitions
	for era in events["era_changes"]:
		EventBus.era_changed.emit(era["civ_id"], era["era_name"])
		GameState.log_event("era_changed", {
			"civ": era["civ_name"],
			"era": era["era_name"],
		})
		History.record_event({
			"year": GameState.current_year, "type": "era",
			"civ_id": era["civ_id"], "civ_name": era["civ_name"],
			"description": "%s enters the %s era" % [era["civ_name"], era["era_name"]],
		})

	# Governance changes (no EventBus signal — history only)
	for change in events["governance_changes"]:
		History.record_event({
			"year": GameState.current_year, "type": "governance_change",
			"civ_id": change["civ_id"], "civ_name": change["civ_name"],
			"description": "%s: %s -> %s" % [change["civ_name"], change["old_tier"], change["new_tier"]],
		})

	# Victory/Defeat events
	for v_event in events["victory_events"]:
		if v_event.has("victory_type"):
			EventBus.game_won.emit(v_event["victory_type"], v_event)
			History.record_event({
				"year": GameState.current_year, "type": "victory",
				"civ_id": v_event["civ_id"], "civ_name": v_event["civ_name"],
				"description": "%s achieves %s victory" % [v_event["civ_name"], v_event["victory_type"]],
			})
		elif v_event.has("defeat_reason"):
			EventBus.game_lost.emit(v_event["defeat_reason"], v_event)
			History.record_event({
				"year": GameState.current_year, "type": "defeat",
				"civ_id": v_event["civ_id"], "civ_name": v_event["civ_name"],
				"description": "%s defeated: %s" % [v_event["civ_name"], v_event["defeat_reason"]],
			})

	# Unit events
	for unit_evt in events.get("unit_events", []):
		match unit_evt["type"]:
			"unit_moved":
				EventBus.unit_moved.emit(
					unit_evt["unit_id"], unit_evt["from_region_id"], unit_evt["to_region_id"]
				)
				GameState.log_event("unit_moved", {
					"unit": unit_evt["unit_name"],
					"from": unit_evt["from_region_name"],
					"to": unit_evt["to_region_name"],
				})
			"unit_trained":
				EventBus.unit_trained.emit(
					unit_evt["unit_id"], unit_evt["civ_id"],
					unit_evt["unit_type"], unit_evt["region_id"]
				)
				var type_name: String = Constants.UNIT_TYPE_NAMES.get(unit_evt["unit_type"], "Unit")
				GameState.log_event("unit_trained", {
					"civ": unit_evt.get("civ_name", ""),
					"unit": unit_evt.get("unit_name", ""),
					"type": type_name,
				})

	# Disaster events
	for disaster_evt in events.get("disaster_events", []):
		EventBus.disaster_occurred.emit(
			disaster_evt["region_id"],
			disaster_evt["disaster_name"],
			disaster_evt["owner_id"],
		)
		GameState.log_event("disaster", {
			"region": disaster_evt["region_name"],
			"disaster": disaster_evt["disaster_name"],
		})
		History.record_event({
			"year": GameState.current_year, "type": "disaster",
			"region_id": disaster_evt["region_id"],
			"description": "%s strikes %s (%d yr)" % [
				disaster_evt["disaster_name"],
				disaster_evt["region_name"],
				disaster_evt["duration"],
			],
		})

	# Trait evolution events
	for trait_evt in events.get("trait_changes", []):
		var old_display: String = trait_evt["old_tag"] if trait_evt["old_tag"] != "" else "Neutral"
		var new_display: String = trait_evt["new_tag"] if trait_evt["new_tag"] != "" else "Neutral"
		EventBus.trait_changed.emit(
			trait_evt["civ_id"], trait_evt["bias_display"],
			trait_evt["old_tag"], trait_evt["new_tag"],
		)
		GameState.log_event("trait_changed", {
			"civ": trait_evt["civ_name"],
			"bias": trait_evt["bias_display"],
			"old_tag": old_display,
			"new_tag": new_display,
			"reason": trait_evt["reason"],
		})
		History.record_event({
			"year": GameState.current_year, "type": "trait_changed",
			"civ_id": trait_evt["civ_id"], "civ_name": trait_evt["civ_name"],
			"description": "%s: %s shifts from %s to %s (%s)" % [
				trait_evt["civ_name"], trait_evt["bias_display"],
				old_display, new_display, trait_evt["reason"],
			],
		})

	# Pending player political events (show modal)
	if not GameState.pending_political_events.is_empty():
		EventBus.political_event_pending.emit(GameState.pending_political_events[0])
