extends Node

## Thin orchestrator that delegates simulation to SimulationEngine
## and bridges results to the presentation layer via EventBus signals.

var is_processing: bool = false


func advance_year() -> void:
	## Execute one full simulation year and emit all events as signals.
	if is_processing:
		return

	is_processing = true
	GameState.current_year += 1
	GameState.clear_turn_log()

	EventBus.turn_started.emit(GameState.current_year)

	# Run pure simulation - returns all events for the year
	var events := SimulationEngine.process_year()

	# Bridge simulation events to presentation signals
	_emit_events(events)

	EventBus.turn_ended.emit(GameState.current_year)
	is_processing = false


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
		if result["prod_shortage"]:
			var stockpile: int = GameState.get_civilization(civ_id).production_stockpile
			EventBus.production_shortage.emit(civ_id, stockpile)
			GameState.log_event("production_shortage", {
				"civ": result["civ_name"], "stockpile": stockpile,
			})

	# Stability changes
	for change in events["stability_changes"]:
		EventBus.stability_changed.emit(
			change["civ_id"], change["old_stability"], change["new_stability"]
		)

	# Collapses
	for collapse in events["collapses"]:
		EventBus.civilization_collapsed.emit(collapse["civ_id"])
		GameState.log_event("collapse", {"civ": collapse["civ_name"]})

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
			"war_declared":
				EventBus.war_declared.emit(event["attacker_id"], event["defender_id"])
				GameState.log_event("war_declared", {
					"attacker": event["attacker_name"],
					"defender": event["defender_name"],
				})
			"peace":
				EventBus.peace_declared.emit(event["civ_a_id"], event["civ_b_id"])
				GameState.log_event("peace", {
					"civ_a": event["civ_a_name"],
					"civ_b": event["civ_b_name"],
				})
			"infrastructure_upgrade":
				EventBus.infrastructure_upgraded.emit(
					event["civ_id"], event["region_name"], event["new_level"]
				)
				GameState.log_event("infrastructure", {
					"civ": event["civ_name"],
					"region": event["region_name"],
					"level": event["new_level"],
				})

	# Battles
	for battle in events["battles"]:
		EventBus.battle_resolved.emit(
			battle["region_id"],
			battle["attacker_id"],
			battle["defender_id"],
			battle["winner_id"],
		)
		GameState.log_event("battle", {
			"region": battle["region_name"],
			"attacker": battle["attacker_name"],
			"defender": battle["defender_name"],
			"winner": "attacker" if battle["winner_id"] == battle["attacker_id"] else "defender",
		})

	# Dead heroes
	for hero_event in events["dead_heroes"]:
		EventBus.hero_died.emit(hero_event["hero_id"], hero_event["civ_id"])
		GameState.log_event("hero_died", {
			"hero": hero_event["hero_name"],
			"civ": hero_event["civ_name"],
		})

	# Spawned heroes
	for hero_event in events["spawned_heroes"]:
		EventBus.hero_spawned.emit(
			hero_event["hero_id"], hero_event["civ_id"], hero_event["hero_type"]
		)
		GameState.log_event("hero_spawned", {
			"hero": hero_event["hero_name"],
			"type": Enums.HeroType.keys()[hero_event["hero_type"]],
			"civ": hero_event["civ_name"],
		})

	# Golden ages
	for ga in events["golden_age_starts"]:
		EventBus.golden_age_started.emit(ga["civ_id"])
		GameState.log_event("golden_age_started", {"civ": ga["civ_name"]})
	for ga in events["golden_age_ends"]:
		EventBus.golden_age_ended.emit(ga["civ_id"])
		GameState.log_event("golden_age_ended", {"civ": ga["civ_name"]})

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

	# Resource events
	for res_event in events["resource_events"]:
		var civ_id: int = res_event["civ_id"]
		var civ_name: String = res_event["civ_name"]

		# Maintenance failures
		for penalty in res_event["maintenance_penalties"]:
			var res_name := ResourceProduction.get_resource_name(penalty["resource"])
			EventBus.resource_maintenance_failure.emit(
				civ_id, res_name, penalty["missing_inputs"]
			)
			GameState.log_event("maintenance_failure", {
				"civ": civ_name,
				"resource": res_name,
				"missing": penalty["missing_inputs"],
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

	# Tech emergences
	for tech in events["tech_emergences"]:
		EventBus.technology_emerged.emit(tech["civ_id"], tech["tech_name"])
		GameState.log_event("tech_emerged", {
			"civ": tech["civ_name"],
			"tech": tech["tech_name"],
		})
