extends Node

## Orchestrates the strict 10-step turn pipeline.
## Each step processes all civilizations before moving to the next.

var is_processing: bool = false


func advance_year() -> void:
	## Execute one full simulation year. Call this to tick the game forward.
	if is_processing:
		return

	is_processing = true
	GameState.current_year += 1
	GameState.clear_turn_log()

	EventBus.turn_started.emit(GameState.current_year)

	# Strict 10-step pipeline
	_step_population_growth()
	_step_resource_production()
	_step_resource_consumption()
	_step_stability_recalculation()
	_step_ai_decisions()
	_step_war_resolution()
	_step_hero_aging()
	_step_golden_age_evaluation()
	_step_tech_emergence()
	_step_end_of_year_logging()

	EventBus.turn_ended.emit(GameState.current_year)
	is_processing = false


func advance_years(count: int) -> void:
	## Fast-forward multiple years.
	for i in count:
		advance_year()


# --- Step 1: Population Growth ---

func _step_population_growth() -> void:
	EventBus.turn_phase_started.emit(Enums.TurnPhase.POPULATION_GROWTH)

	for civ in GameState.get_alive_civilizations():
		for region in GameState.get_regions_by_owner(civ.id):
			var old_pop := region.population
			region.population = PopulationSimulation.calculate_growth(region, civ)
			if old_pop != region.population:
				EventBus.population_changed.emit(region.id, old_pop, region.population)

	# Recalculate total populations
	GameState._recalculate_civ_populations()
	EventBus.turn_phase_completed.emit(Enums.TurnPhase.POPULATION_GROWTH)


# --- Step 2: Resource Production ---

func _step_resource_production() -> void:
	EventBus.turn_phase_started.emit(Enums.TurnPhase.RESOURCE_PRODUCTION)

	for civ in GameState.get_alive_civilizations():
		var total_food := 0
		var total_production := 0

		for region in GameState.get_regions_by_owner(civ.id):
			var food := region.food_yield
			var prod := region.production_yield

			# Infrastructure bonus
			food += region.infrastructure_level
			prod += region.infrastructure_level

			# Visionary hero bonus
			var hero_prod_bonus := 1.0
			for hero_id in civ.hero_ids:
				var hero: HeroData = GameState.get_hero(hero_id)
				if hero and hero.type == Enums.HeroType.VISIONARY:
					hero_prod_bonus += hero.get_modifier_value()

			prod = int(prod * hero_prod_bonus)

			# Golden age bonus
			if civ.is_in_golden_age():
				food = int(food * (1.0 + Constants.GOLDEN_AGE_FOOD_BONUS))
				prod = int(prod * (1.0 + Constants.GOLDEN_AGE_PRODUCTION_BONUS))

			total_food += food
			total_production += prod

		civ.food_stockpile += total_food
		civ.production_stockpile += total_production

	EventBus.turn_phase_completed.emit(Enums.TurnPhase.RESOURCE_PRODUCTION)


# --- Step 3: Resource Consumption ---

func _step_resource_consumption() -> void:
	EventBus.turn_phase_started.emit(Enums.TurnPhase.RESOURCE_CONSUMPTION)

	for civ in GameState.get_alive_civilizations():
		# Population eats food: roughly 1 food per 1000 population
		var food_consumed := civ.total_population / 1000
		civ.food_stockpile -= food_consumed

		# Military consumes production
		var military_upkeep := int(civ.military_strength / 10.0)
		civ.production_stockpile -= military_upkeep

		# Military replenishment from remaining production
		if civ.production_stockpile > 0:
			var reinforce := minf(float(civ.production_stockpile) * 0.1, 20.0)
			civ.military_strength += reinforce

	EventBus.turn_phase_completed.emit(Enums.TurnPhase.RESOURCE_CONSUMPTION)


# --- Step 4: Stability Recalculation ---

func _step_stability_recalculation() -> void:
	EventBus.turn_phase_started.emit(Enums.TurnPhase.STABILITY_RECALCULATION)

	for civ in GameState.get_alive_civilizations():
		var owned_regions := GameState.get_regions_by_owner(civ.id)
		var old_stability := civ.stability
		civ.stability = StabilitySimulation.recalculate(civ, owned_regions)

		if old_stability != civ.stability:
			EventBus.stability_changed.emit(civ.id, old_stability, civ.stability)

		# Check for collapse
		if StabilitySimulation.check_collapse(civ):
			_collapse_civilization(civ)

	EventBus.turn_phase_completed.emit(Enums.TurnPhase.STABILITY_RECALCULATION)


# --- Step 5: AI Decisions ---

func _step_ai_decisions() -> void:
	EventBus.turn_phase_started.emit(Enums.TurnPhase.AI_DECISIONS)

	for civ in GameState.get_alive_civilizations():
		AILogic.make_decisions(civ)

	EventBus.turn_phase_completed.emit(Enums.TurnPhase.AI_DECISIONS)


# --- Step 6: War Resolution ---

func _step_war_resolution() -> void:
	EventBus.turn_phase_started.emit(Enums.TurnPhase.WAR_RESOLUTION)

	for civ in GameState.get_alive_civilizations():
		if civ.war_targets.is_empty():
			continue

		for enemy_id in civ.war_targets.duplicate():
			var enemy := GameState.get_civilization(enemy_id)
			if not enemy or enemy.is_collapsed:
				civ.war_targets.erase(enemy_id)
				continue

			# Find a contested border region to fight over
			var contested := _find_contested_region(civ, enemy)
			if contested:
				var result := WarResolver.resolve_battle(civ, enemy, contested)
				WarResolver.apply_battle_result(result, civ, enemy, contested)

	EventBus.turn_phase_completed.emit(Enums.TurnPhase.WAR_RESOLUTION)


# --- Step 7: Hero Aging & Effects ---

func _step_hero_aging() -> void:
	EventBus.turn_phase_started.emit(Enums.TurnPhase.HERO_AGING)

	var dead_hero_ids: Array[int] = []

	for hero in GameState.heroes.values():
		hero.age_one_year()
		if not hero.is_alive():
			dead_hero_ids.append(hero.id)

	# Remove dead heroes
	for hero_id in dead_hero_ids:
		var hero := GameState.get_hero(hero_id)
		if hero:
			var civ := GameState.get_civilization(hero.owner_civ_id)
			if civ:
				civ.hero_ids.erase(hero_id)
			EventBus.hero_died.emit(hero_id, hero.owner_civ_id)
			GameState.log_event("hero_died", {
				"hero": hero.hero_name,
				"civ": civ.civ_name if civ else "unknown",
			})
			GameState.remove_hero(hero_id)

	# Try spawning new heroes
	for civ in GameState.get_alive_civilizations():
		_try_spawn_hero(civ)

	EventBus.turn_phase_completed.emit(Enums.TurnPhase.HERO_AGING)


# --- Step 8: Golden Age Evaluation ---

func _step_golden_age_evaluation() -> void:
	EventBus.turn_phase_started.emit(Enums.TurnPhase.GOLDEN_AGE_EVALUATION)

	for civ in GameState.get_alive_civilizations():
		if civ.is_in_golden_age():
			civ.golden_age_years_remaining -= 1

			# Check early end
			if civ.stability < Constants.GOLDEN_AGE_END_STABILITY or civ.is_at_war():
				civ.golden_age_years_remaining = 0

			if civ.golden_age_years_remaining <= 0:
				civ.golden_age_cooldown = Constants.GOLDEN_AGE_COOLDOWN_YEARS
				EventBus.golden_age_ended.emit(civ.id)
				GameState.log_event("golden_age_ended", {"civ": civ.civ_name})
		else:
			# Tick cooldown
			if civ.golden_age_cooldown > 0:
				civ.golden_age_cooldown -= 1

			# Check if golden age should start
			if civ.can_enter_golden_age():
				civ.golden_age_years_remaining = Constants.GOLDEN_AGE_DURATION_YEARS
				EventBus.golden_age_started.emit(civ.id)
				GameState.log_event("golden_age_started", {"civ": civ.civ_name})

	EventBus.turn_phase_completed.emit(Enums.TurnPhase.GOLDEN_AGE_EVALUATION)


# --- Step 9: Tech Emergence ---

func _step_tech_emergence() -> void:
	EventBus.turn_phase_started.emit(Enums.TurnPhase.TECH_EMERGENCE)

	for civ in GameState.get_alive_civilizations():
		var owned_regions := GameState.get_regions_by_owner(civ.id)

		# Update hidden metrics first
		TechEmergence.update_hidden_metrics(civ, owned_regions)

		# Check for new technologies
		var new_techs := TechEmergence.check_emergence(civ)
		for tech_name in new_techs:
			EventBus.technology_emerged.emit(civ.id, tech_name)
			GameState.log_event("tech_emerged", {
				"civ": civ.civ_name,
				"tech": tech_name,
			})

	EventBus.turn_phase_completed.emit(Enums.TurnPhase.TECH_EMERGENCE)


# --- Step 10: End-of-Year Logging ---

func _step_end_of_year_logging() -> void:
	EventBus.turn_phase_started.emit(Enums.TurnPhase.END_OF_YEAR_LOGGING)
	EventBus.turn_phase_completed.emit(Enums.TurnPhase.END_OF_YEAR_LOGGING)


# --- Helpers ---

func _collapse_civilization(civ: CivilizationData) -> void:
	## All regions become neutral, civ is marked collapsed.
	civ.is_collapsed = true

	for region in GameState.get_regions_by_owner(civ.id):
		var old_owner := region.owner_id
		region.owner_id = -1
		EventBus.region_owner_changed.emit(region.id, old_owner, -1)

	# End all wars
	for enemy_id in civ.war_targets.duplicate():
		var enemy := GameState.get_civilization(enemy_id)
		if enemy:
			enemy.war_targets.erase(civ.id)
	civ.war_targets.clear()

	EventBus.civilization_collapsed.emit(civ.id)
	GameState.log_event("collapse", {"civ": civ.civ_name})


func _find_contested_region(
	attacker: CivilizationData, defender: CivilizationData
) -> RegionData:
	## Find a defender region adjacent to attacker territory.
	var attacker_regions := GameState.get_regions_by_owner(attacker.id)
	for region in attacker_regions:
		for adj_id in region.adjacency_list:
			var adj := GameState.get_region(adj_id)
			if adj and adj.owner_id == defender.id:
				return adj
	return null


func _try_spawn_hero(civ: CivilizationData) -> void:
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

	# Pick random hero type
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

	EventBus.hero_spawned.emit(hero.id, civ.id, hero_type)
	GameState.log_event("hero_spawned", {
		"hero": hero.hero_name,
		"type": Enums.HeroType.keys()[hero_type],
		"civ": civ.civ_name,
	})
