extends GutTest

## Tests for RiverGenerator, river/lake bonuses in economy and supply,
## and river defense penalty in war resolver.


func _make_region(
	region_id: int,
	terrain: Enums.TerrainType = Enums.TerrainType.PLAINS,
	owner_id: int = -1,
) -> RegionData:
	var region := RegionData.new(region_id, "Region_%d" % region_id, terrain)
	region.owner_id = owner_id
	return region


func _set_adj(region: RegionData, ids: Array) -> void:
	region.adjacency_list.clear()
	for id in ids:
		region.adjacency_list.append(id)


func _make_civ(civ_id: int = 0) -> CivilizationData:
	var civ := CivilizationData.new(civ_id, "TestCiv", Color.RED)
	civ.capital_region_id = 0
	civ.stability = 50.0
	civ.total_population = 1000
	return civ


# --- River Generator Tests ---

func test_elevation_assignment_by_terrain() -> void:
	var regions := {}
	regions[0] = _make_region(0, Enums.TerrainType.MOUNTAINS)
	regions[1] = _make_region(1, Enums.TerrainType.PLAINS)
	regions[2] = _make_region(2, Enums.TerrainType.COASTLINE)
	regions[3] = _make_region(3, Enums.TerrainType.TUNDRA)
	regions[4] = _make_region(4, Enums.TerrainType.VOLCANIC_RIDGE)

	_set_adj(regions[0], [1])
	_set_adj(regions[1], [0, 2])
	_set_adj(regions[2], [1])
	_set_adj(regions[3], [])
	_set_adj(regions[4], [])

	RiverGenerator.generate(regions, 42)

	assert_eq(regions[0].elevation, 3, "Mountains elevation should be 3")
	assert_eq(regions[1].elevation, 0, "Plains elevation should be 0")
	assert_eq(regions[2].elevation, 0, "Coastline elevation should be 0")
	assert_eq(regions[3].elevation, 2, "Tundra elevation should be 2")
	assert_eq(regions[4].elevation, 3, "Volcanic elevation should be 3")


func test_river_basin_auto_river() -> void:
	var regions := {}
	regions[0] = _make_region(0, Enums.TerrainType.RIVER_BASIN)
	_set_adj(regions[0], [])

	RiverGenerator.generate(regions, 42)

	assert_true(regions[0].has_river, "River basin should auto-get has_river")


func test_river_generation_deterministic() -> void:
	var regions_a := {}
	var regions_b := {}
	for i in 5:
		var t: Enums.TerrainType = Enums.TerrainType.MOUNTAINS if i == 0 else Enums.TerrainType.PLAINS
		regions_a[i] = _make_region(i, t)
		regions_b[i] = _make_region(i, t)

	for i in 4:
		regions_a[i].adjacency_list.append(i + 1)
		regions_a[i + 1].adjacency_list.append(i)
		regions_b[i].adjacency_list.append(i + 1)
		regions_b[i + 1].adjacency_list.append(i)

	RiverGenerator.generate(regions_a, 99)
	RiverGenerator.generate(regions_b, 99)

	for i in 5:
		assert_eq(regions_a[i].has_river, regions_b[i].has_river,
			"Region %d river should match with same seed" % i)


func test_lake_placement_avoids_coast_and_desert() -> void:
	var regions := {}
	regions[0] = _make_region(0, Enums.TerrainType.COASTLINE)
	regions[1] = _make_region(1, Enums.TerrainType.DESERT)
	_set_adj(regions[0], [1])
	_set_adj(regions[1], [0])

	RiverGenerator.generate(regions, 42)

	assert_false(regions[0].has_lake, "Coastline should not get lake")
	assert_false(regions[1].has_lake, "Desert should not get lake")


func test_river_flows_downhill() -> void:
	var regions := {}
	regions[0] = _make_region(0, Enums.TerrainType.MOUNTAINS)
	regions[1] = _make_region(1, Enums.TerrainType.PLAINS)
	regions[2] = _make_region(2, Enums.TerrainType.COASTLINE)
	_set_adj(regions[0], [1])
	_set_adj(regions[1], [0, 2])
	_set_adj(regions[2], [1])

	RiverGenerator.generate(regions, 42)

	assert_true(regions[0].has_river, "Mountain (river start) should have river")
	var downstream: bool = regions[1].has_river or regions[2].has_river
	assert_true(downstream, "River should flow to at least one downstream region")


# --- Economy Bonus Tests ---

func test_river_food_bonus() -> void:
	var civ := _make_civ()
	var region := _make_region(0, Enums.TerrainType.PLAINS, 0)
	region.food_yield = 5
	region.has_river = false
	var regions: Array[RegionData] = [region]
	var food_no_river := EconomySimulation.calculate_food_production(civ, regions)

	region.has_river = true
	var food_with_river := EconomySimulation.calculate_food_production(civ, regions)

	assert_gt(food_with_river, food_no_river, "River should increase food production")


func test_lake_food_bonus() -> void:
	var civ := _make_civ()
	var region := _make_region(0, Enums.TerrainType.PLAINS, 0)
	region.food_yield = 5
	region.has_lake = false
	var regions: Array[RegionData] = [region]
	var food_no_lake := EconomySimulation.calculate_food_production(civ, regions)

	region.has_lake = true
	var food_with_lake := EconomySimulation.calculate_food_production(civ, regions)

	assert_gt(food_with_lake, food_no_lake, "Lake should increase food production")


# --- Supply System Bonus Test ---

func test_river_supply_throughput_bonus() -> void:
	var civ := _make_civ()
	var r0 := _make_region(0, Enums.TerrainType.PLAINS, 0)
	var r1 := _make_region(1, Enums.TerrainType.PLAINS, 0)
	r0.owner_id = 0
	r1.owner_id = 0
	_set_adj(r0, [1])
	_set_adj(r1, [0])

	GameState.regions.clear()
	GameState.regions[0] = r0
	GameState.regions[1] = r1

	r1.has_river = false
	var regions_arr: Array[RegionData] = [r0, r1]
	SupplySystem.calculate_supply_map(civ, regions_arr)
	var supply_no_river := r1.supply_value

	r1.has_river = true
	SupplySystem.calculate_supply_map(civ, regions_arr)
	var supply_with_river := r1.supply_value

	assert_gt(supply_with_river, supply_no_river,
		"River should improve supply throughput")


# --- War Resolver River Defense Test ---

func test_river_attacker_penalty() -> void:
	assert_lt(Constants.RIVER_DEFENSE_PENALTY, 0.0,
		"River defense penalty should be negative (hurts attacker)")


func test_lake_defender_bonus() -> void:
	assert_gt(Constants.LAKE_DEFENSE_BONUS, 0.0,
		"Lake defense bonus should be positive (helps defender)")
