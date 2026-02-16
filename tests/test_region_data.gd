extends GutTest

## Tests for RegionData (resources/region_data.gd)
## Focused on BFS connectivity check and terrain defaults.


# --- Terrain Defaults ---

func test_river_basin_defaults() -> void:
	var region := RegionData.new(0, "River", Enums.TerrainType.RIVER_BASIN)
	assert_eq(region.food_yield, Constants.YIELD_RIVER_BASIN.x)
	assert_eq(region.production_yield, Constants.YIELD_RIVER_BASIN.y)
	assert_eq(region.defense_modifier, Constants.DEFENSE_RIVER_BASIN)


func test_mountains_defaults() -> void:
	var region := RegionData.new(0, "Mountain", Enums.TerrainType.MOUNTAINS)
	assert_eq(region.food_yield, Constants.YIELD_MOUNTAINS.x)
	assert_eq(region.production_yield, Constants.YIELD_MOUNTAINS.y)
	assert_eq(region.defense_modifier, Constants.DEFENSE_MOUNTAINS)


func test_coastline_defaults() -> void:
	var region := RegionData.new(0, "Coast", Enums.TerrainType.COASTLINE)
	assert_eq(region.food_yield, Constants.YIELD_COASTLINE.x)
	assert_eq(region.production_yield, Constants.YIELD_COASTLINE.y)
	assert_eq(region.defense_modifier, Constants.DEFENSE_COASTLINE)


func test_all_terrain_types_have_defaults() -> void:
	for terrain_type in Enums.TerrainType.values():
		var region := RegionData.new(0, "Test", terrain_type)
		assert_true(region.food_yield >= 0, "Terrain %d should have non-negative food yield" % terrain_type)
		assert_true(region.production_yield >= 0, "Terrain %d should have non-negative production" % terrain_type)
		assert_true(region.defense_modifier > 0.0, "Terrain %d should have positive defense" % terrain_type)


# --- BFS Connectivity ---

func _build_chain(count: int, owner: int = 0) -> Dictionary:
	## Build a linear chain of connected regions: 0-1-2-...(count-1)
	var regions: Dictionary = {}
	for i in count:
		var r := RegionData.new(i, "R%d" % i, Enums.TerrainType.PLAINS)
		r.owner_id = owner
		if i > 0:
			r.adjacency_list.append(i - 1)
		if i < count - 1:
			r.adjacency_list.append(i + 1)
		regions[i] = r
	return regions


func test_connected_to_capital_direct() -> void:
	var regions := _build_chain(3, 0)
	# Region 1 is adjacent to region 0 (capital)
	assert_true(regions[1].is_connected_to_capital(regions, 0))


func test_connected_to_capital_via_chain() -> void:
	var regions := _build_chain(5, 0)
	# Region 4 connects to 0 via 4->3->2->1->0
	assert_true(regions[4].is_connected_to_capital(regions, 0))


func test_disconnected_when_chain_broken() -> void:
	var regions := _build_chain(5, 0)
	# Break the chain: region 2 becomes neutral
	regions[2].owner_id = -1

	# Region 4 can't reach capital (0) because region 2 is neutral
	assert_false(regions[4].is_connected_to_capital(regions, 0))


func test_capital_is_always_connected() -> void:
	var regions := _build_chain(3, 0)
	assert_true(regions[0].is_connected_to_capital(regions, 0))


func test_disconnected_when_enemy_blocks() -> void:
	var regions := _build_chain(4, 0)
	# Enemy blocks path
	regions[1].owner_id = 1

	# Region 3 can't reach capital (0) through enemy territory
	assert_false(regions[3].is_connected_to_capital(regions, 0))


# --- is_neutral ---

func test_is_neutral() -> void:
	var region := RegionData.new(0, "Test", Enums.TerrainType.PLAINS)
	region.owner_id = -1
	assert_true(region.is_neutral())

	region.owner_id = 0
	assert_false(region.is_neutral())
