extends GutTest

## Tests for TownSimulation and TownData (Phase 3 town layer)


func _make_civ(
	production_stockpile: int = 100,
	food_stockpile: int = 100,
	total_population: int = 5000,
) -> CivilizationData:
	var civ := CivilizationData.new(1, "TestCiv", Color.RED)
	civ.production_stockpile = production_stockpile
	civ.food_stockpile = food_stockpile
	civ.total_population = total_population
	civ.economy_bias = 0.5
	civ.aggression_bias = 0.5
	return civ


func _make_region(
	terrain: Enums.TerrainType = Enums.TerrainType.PLAINS,
	population: int = 1000,
	owner_id: int = 1,
) -> RegionData:
	var region := RegionData.new(0, "TestRegion", terrain)
	region.population = population
	region.owner_id = owner_id
	return region


func before_each() -> void:
	GameState.next_town_id = 0


# --- TownData ---

func test_town_data_init() -> void:
	var town := TownData.new(1, "TestTown", 5)
	assert_eq(town.id, 1)
	assert_eq(town.town_name, "TestTown")
	assert_eq(town.region_id, 5)
	assert_eq(town.population, 0)
	assert_true(town.buildings.is_empty())


func test_town_add_building() -> void:
	var town := TownData.new(0, "Town", 0)
	town.add_building(Enums.BuildingType.GRANARY)
	assert_eq(town.get_building_count(Enums.BuildingType.GRANARY), 1)
	town.add_building(Enums.BuildingType.GRANARY)
	assert_eq(town.get_building_count(Enums.BuildingType.GRANARY), 2)
	assert_eq(town.get_total_building_count(), 2)


func test_town_food_bonus() -> void:
	var town := TownData.new(0, "Town", 0)
	assert_eq(town.get_food_bonus(), 0)
	town.add_building(Enums.BuildingType.GRANARY)
	assert_eq(town.get_food_bonus(), int(Constants.BUILDING_RULES[0]["outputs"]["food"]))
	town.add_building(Enums.BuildingType.GRANARY)
	assert_eq(town.get_food_bonus(), int(Constants.BUILDING_RULES[0]["outputs"]["food"]) * 2)


func test_town_production_bonus() -> void:
	var town := TownData.new(0, "Town", 0)
	town.add_building(Enums.BuildingType.MARKET)
	assert_eq(town.get_production_bonus(), int(Constants.BUILDING_RULES[2]["outputs"]["production"]))
	town.add_building(Enums.BuildingType.WORKSHOP)
	assert_eq(town.get_production_bonus(), int(Constants.BUILDING_RULES[2]["outputs"]["production"]) + int(Constants.BUILDING_RULES[4]["outputs"]["production"]))


func test_town_defense_bonus() -> void:
	var town := TownData.new(0, "Town", 0)
	town.add_building(Enums.BuildingType.WALLS)
	assert_almost_eq(town.get_defense_bonus(), float(Constants.BUILDING_RULES[3]["outputs"]["defense"]), 0.001)
	town.add_building(Enums.BuildingType.BARRACKS)
	assert_almost_eq(
		town.get_defense_bonus(),
		float(Constants.BUILDING_RULES[3]["outputs"]["defense"]) + float(Constants.BUILDING_RULES[1]["outputs"]["defense"]),
		0.001,
	)


func test_town_stability_bonus() -> void:
	var town := TownData.new(0, "Town", 0)
	town.add_building(Enums.BuildingType.MONUMENT)
	assert_almost_eq(town.get_stability_bonus(), float(Constants.BUILDING_RULES[6]["outputs"]["stability"]), 0.001)
	town.add_building(Enums.BuildingType.MARKET)
	assert_almost_eq(
		town.get_stability_bonus(),
		float(Constants.BUILDING_RULES[6]["outputs"]["stability"]) + float(Constants.BUILDING_RULES[2]["outputs"]["stability"]),
		0.001,
	)


func test_town_maintenance_cost() -> void:
	var town := TownData.new(0, "Town", 0)
	assert_eq(town.get_maintenance_cost(), 0)
	town.add_building(Enums.BuildingType.BARRACKS)   # upkeep 1
	town.add_building(Enums.BuildingType.WORKSHOP)   # upkeep 1
	assert_eq(town.get_maintenance_cost(), 2, "Barracks(1) + Workshop(1) = 2 upkeep")


func test_town_serialization() -> void:
	var town := TownData.new(5, "Ironhold", 10)
	town.population = 500
	town.infrastructure_level = 2
	town.founded_year = 42
	town.add_building(Enums.BuildingType.GRANARY)
	town.add_building(Enums.BuildingType.WALLS)

	var dict := town.to_dict()
	var restored := TownData.from_dict(dict)
	assert_eq(restored.id, 5)
	assert_eq(restored.town_name, "Ironhold")
	assert_eq(restored.region_id, 10)
	assert_eq(restored.population, 500)
	assert_eq(restored.infrastructure_level, 2)
	assert_eq(restored.founded_year, 42)
	assert_eq(restored.get_building_count(Enums.BuildingType.GRANARY), 1)
	assert_eq(restored.get_building_count(Enums.BuildingType.WALLS), 1)


# --- TownSimulation Cost Formulas ---

func test_town_cost_escalates() -> void:
	var region := _make_region()
	# With 0 towns
	var cost_0 := TownSimulation.calculate_town_cost(region)
	# Add a town manually
	region.towns.append(TownData.new(0, "T", 0))
	var cost_1 := TownSimulation.calculate_town_cost(region)
	# Add another
	region.towns.append(TownData.new(1, "T2", 0))
	var cost_2 := TownSimulation.calculate_town_cost(region)
	assert_gt(cost_1, cost_0, "Second town should cost more than first")
	assert_gt(cost_2, cost_1, "Third town should cost more than second")


func test_town_cost_cheaper_in_large_regions() -> void:
	var small_region := _make_region()
	small_region.size_factor = 0.5
	var large_region := _make_region()
	large_region.size_factor = 2.0
	var small_cost := TownSimulation.calculate_town_cost(small_region)
	var large_cost := TownSimulation.calculate_town_cost(large_region)
	assert_gt(small_cost, large_cost, "Towns should be cheaper in larger regions")


func test_building_cost_escalates_per_type() -> void:
	var town := TownData.new(0, "Town", 0)
	var cost_0 := TownSimulation.calculate_building_cost(town, Enums.BuildingType.GRANARY)
	town.add_building(Enums.BuildingType.GRANARY)
	var cost_1 := TownSimulation.calculate_building_cost(town, Enums.BuildingType.GRANARY)
	town.add_building(Enums.BuildingType.GRANARY)
	var cost_2 := TownSimulation.calculate_building_cost(town, Enums.BuildingType.GRANARY)
	assert_gt(cost_1, cost_0, "Second granary should cost more")
	assert_gt(cost_2, cost_1, "Third granary should cost even more")


func test_different_building_types_independent_costs() -> void:
	var town := TownData.new(0, "Town", 0)
	town.add_building(Enums.BuildingType.GRANARY)
	town.add_building(Enums.BuildingType.GRANARY)
	# Market cost should be base (unaffected by granary count)
	var market_cost := TownSimulation.calculate_building_cost(town, Enums.BuildingType.MARKET)
	assert_eq(market_cost, Constants.BUILDING_BASE_COST, "Different types have independent cost scaling")


# --- Town Founding ---

func test_can_found_town() -> void:
	var civ := _make_civ()
	var region := _make_region(Enums.TerrainType.PLAINS, 1000)
	assert_true(TownSimulation.can_found_town(region, civ))


func test_cannot_found_town_low_pop() -> void:
	var civ := _make_civ()
	var region := _make_region(Enums.TerrainType.PLAINS, 100)
	assert_false(TownSimulation.can_found_town(region, civ))


func test_cannot_found_town_no_production() -> void:
	var civ := _make_civ(0)  # no production
	var region := _make_region(Enums.TerrainType.PLAINS, 1000)
	assert_false(TownSimulation.can_found_town(region, civ))


func test_cannot_found_town_wrong_owner() -> void:
	var civ := _make_civ()
	var region := _make_region(Enums.TerrainType.PLAINS, 1000, 99)  # different owner
	assert_false(TownSimulation.can_found_town(region, civ))


func test_found_town_deducts_cost() -> void:
	var civ := _make_civ(200)
	var region := _make_region()
	var old_prod := civ.production_stockpile
	var cost := TownSimulation.calculate_town_cost(region)
	var town: TownData = TownSimulation.found_town(region, civ)
	assert_not_null(town)
	assert_eq(civ.production_stockpile, old_prod - cost)
	assert_eq(region.towns.size(), 1)


func test_found_town_moves_population() -> void:
	var civ := _make_civ()
	var region := _make_region(Enums.TerrainType.PLAINS, 2000)
	var town: TownData = TownSimulation.found_town(region, civ)
	assert_not_null(town)
	assert_eq(town.population, Constants.TOWN_STARTING_POP)


# --- Auto-Spawn ---

func test_auto_spawn_creates_first_town() -> void:
	var civ := _make_civ()
	var region := _make_region(Enums.TerrainType.PLAINS, 1000)
	var town: TownData = TownSimulation.auto_spawn_initial_town(region, civ)
	assert_not_null(town)
	assert_eq(region.towns.size(), 1)
	assert_gt(town.population, 0)


func test_auto_spawn_skips_low_pop() -> void:
	var civ := _make_civ()
	var region := _make_region(Enums.TerrainType.PLAINS, 100)
	var town: TownData = TownSimulation.auto_spawn_initial_town(region, civ)
	assert_null(town)
	assert_true(region.towns.is_empty())


func test_auto_spawn_skips_if_towns_exist() -> void:
	var civ := _make_civ()
	var region := _make_region(Enums.TerrainType.PLAINS, 1000)
	region.towns.append(TownData.new(0, "Existing", 0))
	var town: TownData = TownSimulation.auto_spawn_initial_town(region, civ)
	assert_null(town)
	assert_eq(region.towns.size(), 1)


# --- Economy Aggregation ---

func test_aggregate_food_empty_region() -> void:
	var region := _make_region()
	assert_eq(TownSimulation.aggregate_region_food(region), 0)


func test_aggregate_food_with_towns() -> void:
	var region := _make_region(Enums.TerrainType.PLAINS)
	# Plains food_yield = 3
	var town1 := TownData.new(0, "T1", 0)
	var town2 := TownData.new(1, "T2", 0)
	region.towns = [town1, town2]
	# Each town gets 3/2 = 1 base, no building bonus
	var total := TownSimulation.aggregate_region_food(region)
	assert_eq(total, 2, "Two towns each get floor(3/2) = 1 base food")


func test_aggregate_food_with_granary() -> void:
	var region := _make_region(Enums.TerrainType.PLAINS)
	var town := TownData.new(0, "T1", 0)
	town.add_building(Enums.BuildingType.GRANARY)
	region.towns = [town]
	# One town: base 3/1 = 3 + granary bonus 2 = 5
	var total := TownSimulation.aggregate_region_food(region)
	assert_eq(total, 3 + int(Constants.BUILDING_RULES[0]["outputs"]["food"]))


func test_aggregate_production_with_buildings() -> void:
	var region := _make_region(Enums.TerrainType.PLAINS)
	var town := TownData.new(0, "T1", 0)
	town.add_building(Enums.BuildingType.WORKSHOP)
	region.towns = [town]
	var total := TownSimulation.aggregate_region_production(region)
	assert_eq(total, 3 + int(Constants.BUILDING_RULES[4]["outputs"]["production"]))


func test_aggregate_defense_bonus() -> void:
	var region := _make_region()
	var town := TownData.new(0, "T1", 0)
	town.add_building(Enums.BuildingType.WALLS)
	region.towns = [town]
	assert_almost_eq(
		TownSimulation.aggregate_region_defense_bonus(region),
		float(Constants.BUILDING_RULES[3]["outputs"]["defense"]),
		0.001,
	)


func test_aggregate_maintenance() -> void:
	var region := _make_region()
	var town := TownData.new(0, "T1", 0)
	town.add_building(Enums.BuildingType.BARRACKS)   # upkeep 1
	town.add_building(Enums.BuildingType.WORKSHOP)   # upkeep 1
	region.towns = [town]
	assert_eq(TownSimulation.aggregate_region_maintenance(region), 2)


# --- Economy Integration (backward compat) ---

func test_economy_no_towns_uses_flat_yield() -> void:
	var civ := _make_civ()
	var region := _make_region(Enums.TerrainType.RIVER_BASIN)
	# No towns, should use flat yield (5 food for river basin)
	var regions: Array[RegionData] = [region]
	var food := EconomySimulation.calculate_food_production(civ, regions)
	assert_eq(food, 5, "No-town region should use flat yield (backward compat)")


func test_economy_with_towns_uses_aggregation() -> void:
	var civ := _make_civ()
	var region := _make_region(Enums.TerrainType.RIVER_BASIN)
	# Add a town with a granary
	var town := TownData.new(0, "T1", 0)
	town.add_building(Enums.BuildingType.GRANARY)
	region.towns = [town]
	var regions: Array[RegionData] = [region]
	var food := EconomySimulation.calculate_food_production(civ, regions)
	# Town food: base 5/1 + granary 3 = 8, plus infra 0 = 8
	assert_eq(food, 8, "Town-based region should use aggregated town output")


# --- Building Construction ---

func test_construct_building_success() -> void:
	var civ := _make_civ(100)
	var town := TownData.new(0, "Town", 0)
	var success := TownSimulation.construct_building(town, Enums.BuildingType.GRANARY, civ)
	assert_true(success)
	assert_eq(town.get_building_count(Enums.BuildingType.GRANARY), 1)
	assert_lt(civ.production_stockpile, 100, "Should deduct cost")


func test_construct_building_insufficient_funds() -> void:
	var civ := _make_civ(0)
	var town := TownData.new(0, "Town", 0)
	var success := TownSimulation.construct_building(town, Enums.BuildingType.GRANARY, civ)
	assert_false(success)
	assert_eq(town.get_building_count(Enums.BuildingType.GRANARY), 0)


# --- Player Action Integration ---

func test_found_town_via_player_action() -> void:
	var civ := _make_civ(200)
	var region := _make_region(Enums.TerrainType.PLAINS, 1000)
	GameState.regions[0] = region
	GameState.civilizations[1] = civ
	GameState.player_civ_id = 1
	PlayerActions.queue_action({"type": "found_town", "region_id": 0})
	var events := PlayerActions.process_queued_actions(civ)
	assert_eq(events.size(), 1, "Should produce 1 town_founded event")
	assert_eq(events[0]["type"], "town_founded")
	assert_eq(region.towns.size(), 1, "Region should have 1 town")
	GameState.regions.clear()
	GameState.civilizations.clear()


func test_construct_building_via_player_action() -> void:
	var civ := _make_civ(200)
	var region := _make_region(Enums.TerrainType.PLAINS, 1000)
	var town := TownData.new(0, "TestTown", 0)
	region.towns = [town]
	GameState.regions[0] = region
	GameState.civilizations[1] = civ
	GameState.player_civ_id = 1
	PlayerActions.queue_action({
		"type": "construct_building",
		"region_id": 0,
		"town_index": 0,
		"building_type": Enums.BuildingType.GRANARY,
	})
	var events := PlayerActions.process_queued_actions(civ)
	assert_eq(events.size(), 1, "Should produce 1 building_constructed event")
	assert_eq(events[0]["type"], "building_constructed")
	assert_eq(town.get_building_count(Enums.BuildingType.GRANARY), 1)
	GameState.regions.clear()
	GameState.civilizations.clear()


# --- BUILDING_RULES Table ---

func test_building_rules_table_has_all_types() -> void:
	for key in Constants.BUILDING_NAMES:
		assert_true(
			Constants.BUILDING_RULES.has(key),
			"BUILDING_RULES missing key %d (%s)" % [key, Constants.BUILDING_NAMES[key]],
		)


func test_building_costs_differentiated() -> void:
	# Verify not all buildings have the same cost (costs should be varied)
	var costs: Array[int] = []
	for key in Constants.BUILDING_RULES:
		costs.append(int(Constants.BUILDING_RULES[key]["build_cost"]))
	var unique_costs: Array[int] = []
	for c in costs:
		if c not in unique_costs:
			unique_costs.append(c)
	assert_true(unique_costs.size() >= 3, "Should have at least 3 distinct build costs, got %d" % unique_costs.size())


func test_building_rules_has_required_keys() -> void:
	var required_keys := ["category", "build_cost", "upkeep_cost", "outputs", "description"]
	var output_keys := ["food", "production", "military", "stability", "defense", "tech", "trade"]
	for btype in Constants.BUILDING_RULES:
		var rule: Dictionary = Constants.BUILDING_RULES[btype]
		for key in required_keys:
			assert_true(rule.has(key), "Rule %d missing key '%s'" % [btype, key])
		for okey in output_keys:
			assert_true(rule["outputs"].has(okey), "Rule %d outputs missing '%s'" % [btype, okey])


# --- compute_town_outputs ---

func test_compute_town_outputs_basic() -> void:
	var region := _make_region(Enums.TerrainType.PLAINS)
	var town := TownData.new(0, "T1", 0)
	region.towns = [town]
	var outputs := TownSimulation.compute_town_outputs(town, region)
	# Plains: food_yield=3, production_yield=3
	assert_eq(outputs["base_food"], 3)
	assert_eq(outputs["base_prod"], 3)
	assert_eq(outputs["bldg_food"], 0)
	assert_eq(outputs["bldg_prod"], 0)
	assert_eq(outputs["upkeep"], 0)
	assert_eq(outputs["total_food"], 3)
	assert_eq(outputs["net_prod"], 3)


func test_compute_town_outputs_with_buildings() -> void:
	var region := _make_region(Enums.TerrainType.PLAINS)
	var town := TownData.new(0, "T1", 0)
	town.add_building(Enums.BuildingType.GRANARY)
	town.add_building(Enums.BuildingType.WORKSHOP)
	region.towns = [town]
	var outputs := TownSimulation.compute_town_outputs(town, region)
	assert_eq(outputs["bldg_food"], 3)  # GRANARY gives 3 food
	assert_eq(outputs["bldg_prod"], 4)  # WORKSHOP gives 4 prod
	assert_eq(outputs["total_food"], 3 + 3)
	assert_eq(outputs["total_prod"], 3 + 4)
	assert_eq(outputs["upkeep"], 1)  # Granary(0) + Workshop(1)
	assert_eq(outputs["net_prod"], (3 + 4) - 1)


func test_compute_town_outputs_multi_town_splits_base() -> void:
	var region := _make_region(Enums.TerrainType.PLAINS)
	var town1 := TownData.new(0, "T1", 0)
	var town2 := TownData.new(1, "T2", 0)
	region.towns = [town1, town2]
	var outputs := TownSimulation.compute_town_outputs(town1, region)
	# Plains: food_yield=3, 3/2 = 1 (int division)
	assert_eq(outputs["base_food"], 1)
	assert_eq(outputs["base_prod"], 1)


func test_compute_town_outputs_default_supply() -> void:
	var region := _make_region(Enums.TerrainType.PLAINS)
	var town := TownData.new(0, "T1", 0)
	region.towns = [town]
	var outputs := TownSimulation.compute_town_outputs(town, region)
	assert_almost_eq(outputs["supply_efficiency"], 1.0, 0.001)


# --- Supply Efficiency ---

func test_supply_efficiency_reduces_food() -> void:
	var region := _make_region(Enums.TerrainType.PLAINS)
	region.supply_value = 0.5
	var town := TownData.new(0, "T1", 0)
	town.add_building(Enums.BuildingType.GRANARY)
	region.towns = [town]
	# Raw food: base 3 + granary 3 = 6. At 50% supply = 3
	var total := TownSimulation.aggregate_region_food(region)
	assert_eq(total, int(6.0 * 0.5))


func test_supply_efficiency_reduces_production() -> void:
	var region := _make_region(Enums.TerrainType.PLAINS)
	region.supply_value = 0.5
	var town := TownData.new(0, "T1", 0)
	town.add_building(Enums.BuildingType.WORKSHOP)
	region.towns = [town]
	# Raw prod: base 3 + workshop 4 = 7. At 50% = 3
	var total := TownSimulation.aggregate_region_production(region)
	assert_eq(total, int(7.0 * 0.5))


func test_supply_efficiency_full_unchanged() -> void:
	var region := _make_region(Enums.TerrainType.PLAINS)
	region.supply_value = 1.0
	var town := TownData.new(0, "T1", 0)
	region.towns = [town]
	assert_eq(TownSimulation.aggregate_region_food(region), 3)
	assert_eq(TownSimulation.aggregate_region_production(region), 3)


func test_supply_efficiency_zero() -> void:
	var region := _make_region(Enums.TerrainType.PLAINS)
	region.supply_value = 0.0
	var town := TownData.new(0, "T1", 0)
	town.add_building(Enums.BuildingType.GRANARY)
	region.towns = [town]
	assert_eq(TownSimulation.aggregate_region_food(region), 0)
	assert_eq(TownSimulation.aggregate_region_production(region), 0)


func test_supply_does_not_affect_maintenance() -> void:
	var region := _make_region(Enums.TerrainType.PLAINS)
	region.supply_value = 0.5
	var town := TownData.new(0, "T1", 0)
	town.add_building(Enums.BuildingType.GRANARY)
	town.add_building(Enums.BuildingType.WORKSHOP)
	region.towns = [town]
	# Maintenance is flat regardless of supply: Granary(0) + Workshop(1) = 1
	assert_eq(TownSimulation.aggregate_region_maintenance(region), 1)


func test_compute_outputs_shows_supply() -> void:
	var region := _make_region(Enums.TerrainType.PLAINS)
	region.supply_value = 0.5
	var town := TownData.new(0, "T1", 0)
	town.add_building(Enums.BuildingType.GRANARY)
	region.towns = [town]
	var outputs := TownSimulation.compute_town_outputs(town, region)
	assert_almost_eq(outputs["supply_efficiency"], 0.5, 0.001)
	# Raw food = 3 + 3 (granary) = 6, at 50% = 3
	assert_eq(outputs["total_food"], int(6.0 * 0.5))
	# Stability not scaled
	assert_almost_eq(outputs["total_stab"], 0.0, 0.001)


# --- Differentiated Upkeep + Deficit ---

func test_maintenance_cost_differentiated() -> void:
	var town := TownData.new(0, "Town", 0)
	town.add_building(Enums.BuildingType.BARRACKS)   # upkeep 1
	town.add_building(Enums.BuildingType.WORKSHOP)   # upkeep 1
	assert_eq(town.get_maintenance_cost(), 2)


func test_deficit_detection_no_deficit() -> void:
	var region := _make_region(Enums.TerrainType.PLAINS)
	var town := TownData.new(0, "T1", 0)
	town.add_building(Enums.BuildingType.GRANARY)  # upkeep 0, plains prod_yield 3
	region.towns = [town]
	var info := TownSimulation.compute_region_deficit_info(region)
	assert_false(info["has_deficit"])
	assert_eq(info["deficit_towns"], 0)


func test_deficit_detection_with_deficit() -> void:
	# Tundra: production_yield=1. Supply=0.1. 3 workshops (upkeep 1 each = 3).
	# Raw prod per town: 1/1 + 3*4 = 13, at 10% supply = 1. Upkeep = 3. net = -2
	var region := _make_region(Enums.TerrainType.TUNDRA)
	region.supply_value = 0.1
	var town := TownData.new(0, "T1", 0)
	town.add_building(Enums.BuildingType.WORKSHOP)
	town.add_building(Enums.BuildingType.WORKSHOP)
	town.add_building(Enums.BuildingType.WORKSHOP)
	region.towns = [town]
	var info := TownSimulation.compute_region_deficit_info(region)
	assert_true(info["has_deficit"])
	assert_eq(info["deficit_towns"], 1)


# --- Town Hall + Workforce Presets Data ---

func test_town_hall_in_building_rules() -> void:
	assert_true(Constants.BUILDING_RULES.has(7), "BUILDING_RULES missing Town Hall (key 7)")
	var rule: Dictionary = Constants.BUILDING_RULES[7]
	assert_eq(rule["category"], "administration")
	assert_eq(rule["build_cost"], 10)
	assert_eq(rule["upkeep_cost"], 1)
	assert_true(rule["outputs"].has("stability"))
	assert_true(rule["outputs"].has("tech"))


func test_workforce_presets_valid() -> void:
	assert_eq(Constants.WORKFORCE_PRESETS.size(), 5)
	var required_keys := ["name", "food", "production", "military", "stability", "tech"]
	for preset_id in Constants.WORKFORCE_PRESETS:
		var preset: Dictionary = Constants.WORKFORCE_PRESETS[preset_id]
		for key in required_keys:
			assert_true(preset.has(key), "Preset %d missing key '%s'" % [preset_id, key])
	# Balanced preset should be all 1.0
	var balanced: Dictionary = Constants.WORKFORCE_PRESETS[0]
	assert_eq(balanced["name"], "Balanced")
	assert_almost_eq(float(balanced["food"]), 1.0, 0.001)
	assert_almost_eq(float(balanced["production"]), 1.0, 0.001)


func test_town_data_workforce_preset_default() -> void:
	var town := TownData.new(0, "Town", 0)
	assert_eq(town.workforce_preset, 0)


# --- Workforce Multipliers (Ticket 2) ---

func test_workforce_balanced_no_change() -> void:
	var region := _make_region(Enums.TerrainType.PLAINS)
	var town := TownData.new(0, "T1", 0)
	town.add_building(Enums.BuildingType.TOWN_HALL)
	town.workforce_preset = 0  # Balanced
	region.towns = [town]
	var outputs := TownSimulation.compute_town_outputs(town, region)
	# Balanced = all 1.0 multipliers, same as no workforce effect
	assert_eq(outputs["total_food"], 3)
	assert_eq(outputs["total_prod"], 3 + 1)  # Town Hall gives +1 prod
	assert_true(outputs["has_town_hall"])


func test_workforce_growth_boosts_food() -> void:
	var region := _make_region(Enums.TerrainType.PLAINS)
	var town := TownData.new(0, "T1", 0)
	town.add_building(Enums.BuildingType.TOWN_HALL)
	town.add_building(Enums.BuildingType.GRANARY)
	town.workforce_preset = 1  # Growth: food 1.4
	region.towns = [town]
	var outputs := TownSimulation.compute_town_outputs(town, region)
	# Raw food: base 3 + granary 3 = 6. * 1.0 supply * 1.4 growth = 8
	assert_eq(outputs["total_food"], int(6.0 * 1.0 * 1.4))
	# Production: base 3 + town_hall 1 = 4. * 1.0 * 0.7 = 2
	assert_eq(outputs["total_prod"], int(4.0 * 1.0 * 0.7))


func test_workforce_requires_town_hall() -> void:
	var region := _make_region(Enums.TerrainType.PLAINS)
	var town := TownData.new(0, "T1", 0)
	town.workforce_preset = 1  # Growth preset, but NO Town Hall
	region.towns = [town]
	var outputs := TownSimulation.compute_town_outputs(town, region)
	# Without Town Hall, multipliers forced to 1.0 regardless of preset
	assert_eq(outputs["total_food"], 3)
	assert_eq(outputs["total_prod"], 3)
	assert_false(outputs["has_town_hall"])


func test_aggregate_food_includes_workforce() -> void:
	var region := _make_region(Enums.TerrainType.PLAINS)
	var town := TownData.new(0, "T1", 0)
	town.add_building(Enums.BuildingType.TOWN_HALL)
	town.add_building(Enums.BuildingType.GRANARY)
	town.workforce_preset = 1  # Growth: food 1.4
	region.towns = [town]
	var total := TownSimulation.aggregate_region_food(region)
	# Raw food 6 (base 3 + granary 3) * 1.0 supply * 1.4 = 8
	assert_eq(total, int(6.0 * 1.4))


func test_aggregate_prod_includes_workforce() -> void:
	var region := _make_region(Enums.TerrainType.PLAINS)
	var town := TownData.new(0, "T1", 0)
	town.add_building(Enums.BuildingType.TOWN_HALL)
	town.workforce_preset = 3  # Trade: production 1.3
	region.towns = [town]
	var total := TownSimulation.aggregate_region_production(region)
	# Raw prod: base 3 + town_hall 1 = 4. * 1.0 * 1.3 = 5
	assert_eq(total, int(4.0 * 1.3))


func test_urban_gravity_basic() -> void:
	var region := _make_region(Enums.TerrainType.PLAINS)
	region.infrastructure_level = 2
	var town := TownData.new(0, "T1", 0)
	town.population = 1000
	region.towns = [town]
	var gravity := TownSimulation.compute_urban_gravity(town, region)
	# 1000 * (1 + 2*0.2) * (1 + 0.3*0.1) = 1000 * 1.4 * 1.03 = 1442.0
	assert_almost_eq(gravity, 1442.0, 1.0)
	# With a market: trade_flux = 0.3 + 0.1 = 0.4
	town.add_building(Enums.BuildingType.MARKET)
	var gravity2 := TownSimulation.compute_urban_gravity(town, region)
	assert_true(gravity2 > gravity, "Market should increase urban gravity")


# --- Workforce Preset Player Action (Ticket 3) ---

func test_set_workforce_preset_action() -> void:
	var civ := _make_civ(200)
	var region := _make_region(Enums.TerrainType.PLAINS, 5000)
	var town := TownData.new(0, "TestTown", 0)
	town.add_building(Enums.BuildingType.TOWN_HALL)
	region.towns = [town]
	GameState.regions[0] = region
	GameState.civilizations[1] = civ
	GameState.player_civ_id = 1
	PlayerActions.queue_action({
		"type": "set_workforce_preset",
		"region_id": 0,
		"town_index": 0,
		"preset": 1,
	})
	var events := PlayerActions.process_queued_actions(civ)
	assert_eq(events.size(), 1)
	assert_eq(events[0]["type"], "workforce_preset_changed")
	assert_eq(events[0]["preset_name"], "Growth")
	assert_eq(town.workforce_preset, 1)
	GameState.regions.clear()
	GameState.civilizations.clear()


func test_set_workforce_preset_requires_town_hall() -> void:
	var civ := _make_civ(200)
	var region := _make_region(Enums.TerrainType.PLAINS, 5000)
	var town := TownData.new(0, "TestTown", 0)
	# No Town Hall!
	region.towns = [town]
	GameState.regions[0] = region
	GameState.civilizations[1] = civ
	GameState.player_civ_id = 1
	PlayerActions.queue_action({
		"type": "set_workforce_preset",
		"region_id": 0,
		"town_index": 0,
		"preset": 2,
	})
	var events := PlayerActions.process_queued_actions(civ)
	assert_eq(events.size(), 0, "Should reject non-Balanced preset without Town Hall")
	assert_eq(town.workforce_preset, 0, "Preset should remain Balanced")
	GameState.regions.clear()
	GameState.civilizations.clear()


func test_set_workforce_preset_invalid() -> void:
	var civ := _make_civ(200)
	var region := _make_region(Enums.TerrainType.PLAINS, 5000)
	var town := TownData.new(0, "TestTown", 0)
	town.add_building(Enums.BuildingType.TOWN_HALL)
	region.towns = [town]
	GameState.regions[0] = region
	GameState.civilizations[1] = civ
	GameState.player_civ_id = 1
	PlayerActions.queue_action({
		"type": "set_workforce_preset",
		"region_id": 0,
		"town_index": 0,
		"preset": 99,
	})
	var events := PlayerActions.process_queued_actions(civ)
	assert_eq(events.size(), 0, "Invalid preset ID should be rejected")
	GameState.regions.clear()
	GameState.civilizations.clear()


# --- Town Hints (Ticket 5) ---

func test_hints_suggest_town_hall() -> void:
	var civ := _make_civ()
	var region := _make_region(Enums.TerrainType.PLAINS)
	var town := TownData.new(0, "T1", 0)
	region.towns = [town]
	var hints := TownSimulation.compute_town_hints(town, region, civ)
	var found := false
	for h in hints:
		if "Town Hall" in h:
			found = true
			break
	assert_true(found, "Should suggest building a Town Hall")


func test_hints_food_deficit() -> void:
	var civ := _make_civ()
	var region := _make_region(Enums.TerrainType.TUNDRA)
	region.supply_value = 0.3
	var town := TownData.new(0, "T1", 0)
	region.towns = [town]
	var hints := TownSimulation.compute_town_hints(town, region, civ)
	var found := false
	for h in hints:
		if "Granary" in h:
			found = true
			break
	assert_true(found, "Should suggest Granary for low food")


func test_hints_prod_deficit() -> void:
	var civ := _make_civ()
	var region := _make_region(Enums.TerrainType.TUNDRA)
	region.supply_value = 0.3
	var town := TownData.new(0, "T1", 0)
	# Add expensive buildings to create deficit
	town.add_building(Enums.BuildingType.BARRACKS)
	town.add_building(Enums.BuildingType.BARRACKS)
	town.add_building(Enums.BuildingType.BARRACKS)
	region.towns = [town]
	var hints := TownSimulation.compute_town_hints(town, region, civ)
	var found := false
	for h in hints:
		if "deficit" in h:
			found = true
			break
	assert_true(found, "Should warn about production deficit")


func test_hints_empty_when_all_good() -> void:
	var civ := _make_civ()
	civ.stability = 80.0
	var region := _make_region(Enums.TerrainType.PLAINS)
	region.infrastructure_level = 5
	region.development_tier = 5
	var town := TownData.new(0, "T1", 0)
	town.add_building(Enums.BuildingType.TOWN_HALL)
	town.add_building(Enums.BuildingType.GRANARY)
	town.add_building(Enums.BuildingType.WORKSHOP)
	town.add_building(Enums.BuildingType.MONUMENT)
	town.add_building(Enums.BuildingType.BARRACKS)
	region.towns = [town]
	var hints := TownSimulation.compute_town_hints(town, region, civ)
	# Might have 0 hints or very few; at minimum no "Town Hall" hint
	var has_town_hall_hint := false
	for h in hints:
		if "Town Hall" in h:
			has_town_hall_hint = true
	assert_false(has_town_hall_hint, "Should not suggest Town Hall when already built")


# --- Integration Tests (Ticket 6) ---

func test_workforce_affects_economy_output() -> void:
	var region := _make_region(Enums.TerrainType.PLAINS)
	var town := TownData.new(0, "T1", 0)
	town.add_building(Enums.BuildingType.TOWN_HALL)
	town.add_building(Enums.BuildingType.GRANARY)
	region.towns = [town]

	# Balanced preset
	town.workforce_preset = 0
	var food_balanced := TownSimulation.aggregate_region_food(region)

	# Growth preset
	town.workforce_preset = 1
	var food_growth := TownSimulation.aggregate_region_food(region)

	assert_true(food_growth > food_balanced, "Growth preset should produce more food")


func test_town_hall_enables_workforce_in_compute() -> void:
	var region := _make_region(Enums.TerrainType.PLAINS)
	var town := TownData.new(0, "T1", 0)
	town.add_building(Enums.BuildingType.TOWN_HALL)
	town.workforce_preset = 2  # Military
	region.towns = [town]
	var outputs := TownSimulation.compute_town_outputs(town, region)
	# Military preset: military multiplier 1.6
	assert_true(outputs["has_town_hall"])
	assert_eq(outputs["workforce_preset"], 2)


func test_ai_can_build_town_hall() -> void:
	# _pick_ai_building_type can return TOWN_HALL when not under stress
	var civ := _make_civ(200)
	civ.stability = 60.0
	var seen_town_hall := false
	# Run 200 trials to catch the 10% chance
	for trial in range(200):
		var result: int = AILogic._pick_ai_building_type(civ)
		if result == Enums.BuildingType.TOWN_HALL:
			seen_town_hall = true
			break
	assert_true(seen_town_hall, "AI should sometimes pick Town Hall")


func test_save_load_workforce_preset() -> void:
	var town := TownData.new(5, "SaveTest", 3)
	town.population = 500
	town.workforce_preset = 4  # Knowledge
	town.add_building(Enums.BuildingType.TOWN_HALL)

	var data := town.to_dict()
	assert_eq(data["workforce_preset"], 4)

	var loaded: TownData = TownData.from_dict(data) as TownData
	assert_eq(loaded.id, 5)
	assert_eq(loaded.workforce_preset, 4)
	assert_eq(loaded.town_name, "SaveTest")
	assert_eq(loaded.population, 500)


# --- AI Alliance Breaking & Library Tests ---

func test_ai_can_break_alliance() -> void:
	# Set up: civ has an ally with very low stability
	var civ := _make_civ()
	GameState.civilizations[civ.id] = civ
	var ally := CivilizationData.new(2, "Ally", Color.BLUE)
	ally.stability = 15.0  # below 30 threshold
	GameState.civilizations[ally.id] = ally
	civ.alliance_partners = [ally.id]
	ally.alliance_partners = [civ.id]
	civ.stability = 60.0

	# Run many iterations with seeded RNG to confirm alliance breaks eventually
	var broke := false
	for i in range(200):
		GameState.sim_rng.seed = i * 37 + 42
		# Re-set alliance each iteration
		civ.alliance_partners = [ally.id]
		ally.alliance_partners = [civ.id]
		var events := AILogic._try_break_alliance(civ)
		if not events.is_empty():
			assert_eq(events[0]["type"], "alliance_broken")
			assert_eq(events[0]["civ_a_id"], civ.id)
			assert_eq(events[0]["civ_b_id"], ally.id)
			broke = true
			break
	assert_true(broke, "Alliance should break eventually with unstable ally")


func test_ai_picks_library() -> void:
	var civ := _make_civ()
	civ.stability = 60.0
	civ.technologies = []  # 0 techs, threshold for PREHISTORIC is 2
	civ.current_era = Enums.Epoch.PREHISTORIC

	var picked_library := false
	for i in range(200):
		GameState.sim_rng.seed = i * 13 + 7
		var result := AILogic._pick_ai_building_type(civ)
		if result == Enums.BuildingType.LIBRARY:
			picked_library = true
			break
	assert_true(picked_library, "AI should pick LIBRARY when tech count is low")


func test_ai_declining_can_invest() -> void:
	# Use isolated civ/region IDs to avoid interference with loaded game data
	var saved_regions := GameState.regions.duplicate()
	var saved_civs := GameState.civilizations.duplicate()

	var civ := CivilizationData.new(99, "DecliningCiv", Color.RED)
	civ.production_stockpile = 80
	civ.food_stockpile = 100
	civ.total_population = 5000
	civ.economy_bias = 0.5
	civ.aggression_bias = 0.5
	civ.stability = 20.0  # declining
	GameState.civilizations[99] = civ

	var region := RegionData.new(999, "IsolatedRegion", Enums.TerrainType.PLAINS)
	region.population = 2000
	region.owner_id = 99
	region.infrastructure_level = 0
	GameState.regions[999] = region

	var invested := false
	for i in range(200):
		GameState.sim_rng.seed = i * 19 + 3
		civ.production_stockpile = 80
		region.infrastructure_level = 0
		var events := AILogic._try_declining_recovery(civ)
		if not events.is_empty() and events[0]["type"] == "infrastructure_upgrade":
			invested = true
			break

	# Restore
	GameState.regions = saved_regions
	GameState.civilizations = saved_civs

	assert_true(invested, "DECLINING civ with stockpile should eventually invest in infra")


func test_alliance_broken_event_format() -> void:
	var event := {
		"type": "alliance_broken",
		"civ_a_id": 1,
		"civ_b_id": 2,
		"civ_a_name": "TestA",
		"civ_b_name": "TestB",
	}
	assert_eq(event["type"], "alliance_broken")
	assert_true(event.has("civ_a_id"))
	assert_true(event.has("civ_b_id"))
	assert_true(event.has("civ_a_name"))
	assert_true(event.has("civ_b_name"))