class_name SimulationEngine
extends RefCounted

## Pure simulation orchestrator. Runs the 10-step turn pipeline
## and returns all events that occurred. No signals, no UI - just math.
## TurnManager wraps this and handles signal emission.


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
	}

	# Step 1: Population Growth
	_step_population_growth(events)

	# Step 2-3: Economy (production + consumption combined)
	_step_economy(events)

	# Step 3.5: Collapse civs with no regions (lost everything to war)
	_step_check_regionless(events)

	# Step 4: Stability Recalculation
	_step_stability(events)

	# Step 5: AI Decisions
	_step_ai_decisions(events)

	# Step 6: War Resolution
	_step_war_resolution(events)

	# Step 7: Hero Aging & Effects
	_step_hero_aging(events)

	# Step 8: Golden Age Evaluation
	_step_golden_age_evaluation(events)

	# Step 9: Tech Emergence
	_step_tech_emergence(events)

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


# --- Steps 2-3: Economy (production + consumption) ---

static func _step_economy(events: Dictionary) -> void:
	for civ in GameState.get_alive_civilizations():
		var owned_regions := GameState.get_regions_by_owner(civ.id)
		var result := EconomySimulation.process_economy(civ, owned_regions)
		result["civ_id"] = civ.id
		result["civ_name"] = civ.civ_name
		events["economy_results"].append(result)


# --- Step 4: Stability Recalculation ---

static func _step_stability(events: Dictionary) -> void:
	for civ in GameState.get_alive_civilizations():
		var owned_regions := GameState.get_regions_by_owner(civ.id)
		var old_stability := civ.stability
		civ.stability = StabilitySimulation.recalculate(civ, owned_regions)

		if old_stability != civ.stability:
			events["stability_changes"].append({
				"civ_id": civ.id,
				"old_stability": old_stability,
				"new_stability": civ.stability,
			})

		# Check for collapse
		if StabilitySimulation.check_collapse(civ):
			_collapse_civilization(civ, events)


# --- Step 5: AI Decisions ---

static func _step_ai_decisions(events: Dictionary) -> void:
	for civ in GameState.get_alive_civilizations():
		var ai_events := AILogic.make_decisions(civ)
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

	if randf() > spawn_chance:
		return

	var type_roll := randi() % 3
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
		hero_names[randi() % hero_names.size()],
		hero_type,
		civ.id,
	)
	hero.age = randi_range(20, 35)
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
