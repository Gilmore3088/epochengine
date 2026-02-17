class_name SimulationEngine
extends RefCounted

## Pure simulation orchestrator. Runs the 10-step turn pipeline
## and returns all events that occurred. No signals, no UI - just math.
## TurnManager wraps this and handles signal emission.

static var _MetricsLogger := preload("res://core/simulation/metrics_logger.gd")


static func process_year() -> Dictionary:
	## Run one full simulation year. Returns all events for the year.
	var events: Dictionary = {
		"population_changes": [],
		"economy_results": [],
		"stability_changes": [],
		"collapses": [],
		"ai_events": [],
		"battles": [],
		"owner_changes": [],
		"dead_heroes": [],
		"spawned_heroes": [],
		"golden_age_starts": [],
		"golden_age_ends": [],
		"tech_emergences": [],
		"governance_changes": [],
		"development_tier_changes": [],
		"resource_events": [],
		"town_events": [],
	}

	# Accumulator for resource stability penalties (applied in stability step)
	var _resource_stability_penalties: Dictionary = {}  # {civ_id: float}

	# Step 1: Population Growth
	_step_population_growth(events)

	# Step 1.3: Auto-spawn initial towns for regions that qualify
	_step_town_auto_spawn(events)

	# Step 1.5: Development Tier Evaluation
	_step_development_tiers(events)

	# Step 2-3: Economy (production + consumption combined)
	_step_economy(events)

	# Step 2.5: Resource Pyramid production, maintenance, complexity tax
	_step_resource_production(events, _resource_stability_penalties)

	# Step 3.5: Collapse civs with no regions (lost everything to war)
	_step_check_regionless(events)

	# Step 3.6: Supply route calculation (Dijkstra from capital)
	_step_supply_routes()

	# Step 3.7: Starvation attrition for cut-off regions
	_step_supply_attrition(events)

	# Step 3.75: Renewable resource recovery for unowned/lightly-developed regions
	ResourceProduction.process_renewable_recovery(GameState.regions.values())

	# Step 3.8: Tick war durations
	_step_war_durations()

	# Step 4: Stability Recalculation
	_step_stability(events, _resource_stability_penalties)

	# Step 4.5: Governance Tier Evaluation
	_step_governance(events)

	# Step 5: AI Decisions
	_step_ai_decisions(events)

	# Step 6: War Resolution
	_step_war_resolution(events)

	# Owner changes can affect civ totals (expansions/war/collapse)
	GameState._recalculate_civ_populations()

	# Step 7: Hero Aging & Effects
	_step_hero_aging(events)

	# Step 8: Golden Age Evaluation
	_step_golden_age_evaluation(events)

	# Step 9: Tech Emergence
	_step_tech_emergence(events)

	# Step 10: Metrics logging (if enabled)
	_MetricsLogger.log_year()

	return events


# --- Step 1: Population Growth ---

static func _step_population_growth(events: Dictionary) -> void:
	for civ in GameState.get_alive_civilizations():
		for region in GameState.get_regions_by_owner(civ.id):
			var old_pop := region.population
			region.population = PopulationSimulation.calculate_growth(region, civ)
			if old_pop != region.population:
				events["population_changes"].append({
					"region_id": region.id,
					"old_pop": old_pop,
					"new_pop": region.population,
				})

	GameState._recalculate_civ_populations()


# --- Step 1.3: Town Auto-Spawn ---

static func _step_town_auto_spawn(events: Dictionary) -> void:
	## Auto-spawn initial towns in owned regions that have sufficient population
	## but no towns yet. This bootstraps the town system for existing regions.
	for civ in GameState.get_alive_civilizations():
		for region in GameState.get_regions_by_owner(civ.id):
			if region.towns.is_empty() and region.population >= Constants.TOWN_AUTO_SPAWN_POP:
				var town: TownData = TownSimulation.auto_spawn_initial_town(region, civ)
				if town:
					events["town_events"].append({
						"type": "town_auto_spawned",
						"region_id": region.id,
						"region_name": region.region_name,
						"civ_id": civ.id,
						"town_name": town.town_name,
					})


# --- Step 1.5: Development Tier Evaluation ---

static func _step_development_tiers(events: Dictionary) -> void:
	for civ in GameState.get_alive_civilizations():
		for region in GameState.get_regions_by_owner(civ.id):
			var result := DevelopmentTierSimulation.evaluate_development(region, civ)
			if result["tier_changed"]:
				events["development_tier_changes"].append({
					"region_id": region.id,
					"region_name": region.region_name,
					"civ_id": civ.id,
					"civ_name": civ.civ_name,
					"old_tier": DevelopmentTierSimulation.get_tier_name(result["old_tier"]),
					"new_tier": DevelopmentTierSimulation.get_tier_name(result["new_tier"]),
				})


# --- Steps 2-3: Economy (production + consumption) ---

static func _step_economy(events: Dictionary) -> void:
	for civ in GameState.get_alive_civilizations():
		var owned_regions := GameState.get_regions_by_owner(civ.id)
		var result := EconomySimulation.process_economy(civ, owned_regions)
		result["civ_id"] = civ.id
		result["civ_name"] = civ.civ_name
		events["economy_results"].append(result)


# --- Step 2.5: Resource Pyramid ---

static func _step_resource_production(
	events: Dictionary, stability_penalties: Dictionary
) -> void:
	for civ in GameState.get_alive_civilizations():
		var owned_regions := GameState.get_regions_by_owner(civ.id)
		var result := ResourceProduction.process_resources(civ, owned_regions)

		if result["total_stability_penalty"] > 0.0:
			stability_penalties[civ.id] = result["total_stability_penalty"]

		result["civ_id"] = civ.id
		result["civ_name"] = civ.civ_name
		events["resource_events"].append(result)


# --- Step 4: Stability Recalculation ---

static func _step_stability(
	events: Dictionary, resource_penalties: Dictionary = {}
) -> void:
	for civ in GameState.get_alive_civilizations():
		var owned_regions := GameState.get_regions_by_owner(civ.id)
		var old_stability := civ.stability
		civ.stability = StabilitySimulation.recalculate(civ, owned_regions)

		# Apply resource maintenance and complexity tax penalties
		var res_penalty: float = resource_penalties.get(civ.id, 0.0)
		if res_penalty > 0.0:
			civ.stability = maxf(civ.stability - res_penalty, Constants.STABILITY_MIN)

		if old_stability != civ.stability:
			events["stability_changes"].append({
				"civ_id": civ.id,
				"old_stability": old_stability,
				"new_stability": civ.stability,
			})

		# Check for collapse
		if StabilitySimulation.check_collapse(civ):
			_collapse_civilization(civ, events)


# --- Step 4.5: Governance Tier Evaluation ---

static func _step_governance(events: Dictionary) -> void:
	for civ in GameState.get_alive_civilizations():
		var region_count := GameState.get_regions_by_owner(civ.id).size()
		var result := GovernanceSimulation.evaluate_governance(civ, region_count)
		if result["tier_changed"]:
			events["governance_changes"].append({
				"civ_id": civ.id,
				"civ_name": civ.civ_name,
				"old_tier": GovernanceSimulation.get_tier_name(result["old_tier"]),
				"new_tier": GovernanceSimulation.get_tier_name(result["new_tier"]),
			})


# --- Step 5: AI Decisions ---

static func _step_ai_decisions(events: Dictionary) -> void:
	for civ in GameState.get_alive_civilizations():
		var ai_events: Array[Dictionary]
		if GameState.is_player_civ(civ.id):
			ai_events = PlayerActions.process_queued_actions(civ)
		else:
			ai_events = AILogic.make_decisions(civ)
		for event in ai_events:
			events["ai_events"].append(event)

			# Track owner changes from expansions
			if event["type"] == "expansion":
				events["owner_changes"].append({
					"region_id": event["region_id"],
					"old_owner": event["old_owner"],
					"new_owner": event["civ_id"],
				})


# --- Step 6: War Resolution ---

static func _step_war_resolution(events: Dictionary) -> void:
	for civ in GameState.get_alive_civilizations():
		if civ.war_targets.is_empty():
			continue

		for enemy_id in civ.war_targets.duplicate():
			var enemy := GameState.get_civilization(enemy_id)
			if not enemy or enemy.is_collapsed:
				civ.war_targets.erase(enemy_id)
				continue

			var contested := _find_contested_region(civ, enemy)
			if contested:
				var result := WarResolver.resolve_battle(civ, enemy, contested)
				var battle_event := WarResolver.apply_battle_result(
					result, civ, enemy, contested
				)
				events["battles"].append(battle_event)
				events["owner_changes"].append({
					"region_id": battle_event["region_id"],
					"old_owner": battle_event["old_owner"],
					"new_owner": battle_event["winner_id"],
				})


# --- Step 7: Hero Aging & Effects ---

static func _step_hero_aging(events: Dictionary) -> void:
	var dead_hero_ids: Array[int] = []

	for hero in GameState.heroes.values():
		hero.age_one_year()
		if not hero.is_alive():
			dead_hero_ids.append(hero.id)

	for hero_id in dead_hero_ids:
		var hero := GameState.get_hero(hero_id)
		if hero:
			var civ := GameState.get_civilization(hero.owner_civ_id)
			if civ:
				civ.hero_ids.erase(hero_id)
			events["dead_heroes"].append({
				"hero_id": hero_id,
				"hero_name": hero.hero_name,
				"civ_id": hero.owner_civ_id,
				"civ_name": civ.civ_name if civ else "unknown",
			})
			GameState.remove_hero(hero_id)

	# Try spawning new heroes
	for civ in GameState.get_alive_civilizations():
		_try_spawn_hero(civ, events)


# --- Step 8: Golden Age Evaluation ---

static func _step_golden_age_evaluation(events: Dictionary) -> void:
	for civ in GameState.get_alive_civilizations():
		if civ.is_in_golden_age():
			civ.golden_age_years_remaining -= 1

			if civ.stability < Constants.GOLDEN_AGE_END_STABILITY or civ.is_at_war():
				civ.golden_age_years_remaining = 0

			if civ.golden_age_years_remaining <= 0:
				civ.golden_age_cooldown = Constants.GOLDEN_AGE_COOLDOWN_YEARS
				events["golden_age_ends"].append({"civ_id": civ.id, "civ_name": civ.civ_name})
		else:
			if civ.golden_age_cooldown > 0:
				civ.golden_age_cooldown -= 1

			if civ.can_enter_golden_age():
				civ.golden_age_years_remaining = Constants.GOLDEN_AGE_DURATION_YEARS
				events["golden_age_starts"].append({"civ_id": civ.id, "civ_name": civ.civ_name})


# --- Step 9: Tech Emergence ---

static func _step_tech_emergence(events: Dictionary) -> void:
	for civ in GameState.get_alive_civilizations():
		var owned_regions := GameState.get_regions_by_owner(civ.id)
		TechEmergence.update_hidden_metrics(civ, owned_regions)

		var new_techs := TechEmergence.check_emergence(civ)
		for tech_name in new_techs:
			events["tech_emergences"].append({
				"civ_id": civ.id,
				"civ_name": civ.civ_name,
				"tech_name": tech_name,
			})

		# Update era based on current tech count
		civ.current_era = TechEmergence.compute_era(civ.technologies.size())


# --- Step 3.6: Supply Route Calculation ---

static func _step_supply_routes() -> void:
	for civ in GameState.get_alive_civilizations():
		var owned_regions := GameState.get_regions_by_owner(civ.id)
		SupplySystem.calculate_supply_map(civ, owned_regions)


# --- Step 3.7: Starvation Attrition ---

static func _step_supply_attrition(events: Dictionary) -> void:
	## Cut-off regions lose population due to starvation/desertion.
	for civ in GameState.get_alive_civilizations():
		for region in GameState.get_regions_by_owner(civ.id):
			if region.supply_value < Constants.SUPPLY_MIN_THRESHOLD:
				var old_pop := region.population
				var loss := ceili(float(region.population) * Constants.STARVATION_ATTRITION_RATE)
				region.population = maxi(region.population - loss, 100)
				if old_pop != region.population:
					events["population_changes"].append({
						"region_id": region.id,
						"old_pop": old_pop,
						"new_pop": region.population,
					})
	GameState._recalculate_civ_populations()


# --- War Duration Tracking ---

static func _step_war_durations() -> void:
	for civ in GameState.get_alive_civilizations():
		for target_id in civ.war_targets:
			civ.war_durations[target_id] = civ.war_durations.get(target_id, 0) + 1
		# Tick down peace cooldowns
		var expired: Array[int] = []
		for cid in civ.peace_cooldowns:
			civ.peace_cooldowns[cid] = civ.peace_cooldowns[cid] - 1
			if civ.peace_cooldowns[cid] <= 0:
				expired.append(cid)
		for cid in expired:
			civ.peace_cooldowns.erase(cid)


# --- Helpers ---

static func _step_check_regionless(events: Dictionary) -> void:
	for civ in GameState.get_alive_civilizations():
		if GameState.get_regions_by_owner(civ.id).is_empty():
			_collapse_civilization(civ, events)


static func _collapse_civilization(civ: CivilizationData, events: Dictionary) -> void:
	civ.is_collapsed = true

	for region in GameState.get_regions_by_owner(civ.id):
		var old_owner := region.owner_id
		region.owner_id = -1
		events["owner_changes"].append({
			"region_id": region.id,
			"old_owner": old_owner,
			"new_owner": -1,
		})

	for enemy_id in civ.war_targets.duplicate():
		var enemy := GameState.get_civilization(enemy_id)
		if enemy:
			enemy.war_targets.erase(civ.id)
	civ.war_targets.clear()

	events["collapses"].append({
		"civ_id": civ.id,
		"civ_name": civ.civ_name,
	})


static func _find_contested_region(
	attacker: CivilizationData, defender: CivilizationData
) -> RegionData:
	var attacker_regions := GameState.get_regions_by_owner(attacker.id)
	for region in attacker_regions:
		for adj_id in region.adjacency_list:
			var adj := GameState.get_region(adj_id)
			if adj and adj.owner_id == defender.id:
				return adj
	return null


static func _try_spawn_hero(civ: CivilizationData, events: Dictionary) -> void:
	if not civ.can_spawn_hero():
		return
	if civ.stability < Constants.HERO_SPAWN_STABILITY_THRESHOLD:
		return

	var spawn_chance := (
		Constants.HERO_SPAWN_BASE_CHANCE
		* (civ.stability / Constants.STABILITY_MAX)
		* clampf(log(float(civ.total_population)) / 10.0, 0.1, 1.0)
	)

	if GameState.sim_rng.randf() > spawn_chance:
		return

	var type_roll := GameState.sim_rng.randi() % 3
	var hero_type: Enums.HeroType
	match type_roll:
		0: hero_type = Enums.HeroType.GENERAL
		1: hero_type = Enums.HeroType.REFORMER
		_: hero_type = Enums.HeroType.VISIONARY

	var hero_names := [
		"Alexander", "Zenobia", "Kael", "Miriam", "Theron",
		"Livia", "Darius", "Amara", "Orin", "Selene",
		"Magnus", "Freya", "Caspian", "Yara", "Lysander",
	]

	var hero := HeroData.new(
		-1,
		hero_names[GameState.sim_rng.randi() % hero_names.size()],
		hero_type,
		civ.id,
	)
	hero.age = GameState.sim_rng.randi_range(20, 35)
	hero.birth_year = GameState.current_year - hero.age

	GameState.add_hero(hero)
	civ.hero_ids.append(hero.id)

	events["spawned_heroes"].append({
		"hero_id": hero.id,
		"hero_name": hero.hero_name,
		"hero_type": hero_type,
		"civ_id": civ.id,
		"civ_name": civ.civ_name,
	})
