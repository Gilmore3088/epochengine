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
	assert_eq(town.get_food_bonus(), Constants.BUILDING_GRANARY_FOOD)
	town.add_building(Enums.BuildingType.GRANARY)
	assert_eq(town.get_food_bonus(), Constants.BUILDING_GRANARY_FOOD * 2)


func test_town_production_bonus() -> void:
	var town := TownData.new(0, "Town", 0)
	town.add_building(Enums.BuildingType.MARKET)
	assert_eq(town.get_production_bonus(), Constants.BUILDING_MARKET_PRODUCTION)
	town.add_building(Enums.BuildingType.WORKSHOP)
	assert_eq(town.get_production_bonus(), Constants.BUILDING_MARKET_PRODUCTION + Constants.BUILDING_WORKSHOP_PRODUCTION)


func test_town_defense_bonus() -> void:
	var town := TownData.new(0, "Town", 0)
	town.add_building(Enums.BuildingType.WALLS)
	assert_almost_eq(town.get_defense_bonus(), Constants.BUILDING_WALLS_DEFENSE, 0.001)
	town.add_building(Enums.BuildingType.BARRACKS)
	assert_almost_eq(
		town.get_defense_bonus(),
		Constants.BUILDING_WALLS_DEFENSE + Constants.BUILDING_BARRACKS_DEFENSE,
		0.001,
	)


func test_town_stability_bonus() -> void:
	var town := TownData.new(0, "Town", 0)
	town.add_building(Enums.BuildingType.MONUMENT)
	assert_almost_eq(town.get_stability_bonus(), Constants.BUILDING_MONUMENT_STABILITY, 0.001)
	town.add_building(Enums.BuildingType.MARKET)
	assert_almost_eq(
		town.get_stability_bonus(),
		Constants.BUILDING_MONUMENT_STABILITY + Constants.BUILDING_MARKET_STABILITY,
		0.001,
	)


func test_town_maintenance_cost() -> void:
	var town := TownData.new(0, "Town", 0)
	assert_eq(town.get_maintenance_cost(), 0)
	town.add_building(Enums.BuildingType.GRANARY)
	town.add_building(Enums.BuildingType.MARKET)
	assert_eq(town.get_maintenance_cost(), 2 * Constants.BUILDING_MAINTENANCE_PER)


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
	assert_eq(total, 3 + Constants.BUILDING_GRANARY_FOOD)


func test_aggregate_production_with_buildings() -> void:
	var region := _make_region(Enums.TerrainType.PLAINS)
	var town := TownData.new(0, "T1", 0)
	town.add_building(Enums.BuildingType.WORKSHOP)
	region.towns = [town]
	var total := TownSimulation.aggregate_region_production(region)
	assert_eq(total, 3 + Constants.BUILDING_WORKSHOP_PRODUCTION)


func test_aggregate_defense_bonus() -> void:
	var region := _make_region()
	var town := TownData.new(0, "T1", 0)
	town.add_building(Enums.BuildingType.WALLS)
	region.towns = [town]
	assert_almost_eq(
		TownSimulation.aggregate_region_defense_bonus(region),
		Constants.BUILDING_WALLS_DEFENSE,
		0.001,
	)


func test_aggregate_maintenance() -> void:
	var region := _make_region()
	var town := TownData.new(0, "T1", 0)
	town.add_building(Enums.BuildingType.GRANARY)
	town.add_building(Enums.BuildingType.MARKET)
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
	# Town food: base 5/1 + granary 2 = 7, plus infra 0 = 7
	assert_eq(food, 7, "Town-based region should use aggregated town output")


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
