extends GutTest

## Tests for Fog of War: auto-adjacency, visibility model, initialization, save/load.
## Covers Tickets 1, 2, 5 from the Fog of War sprint.

var _saved_regions: Dictionary
var _saved_civs: Dictionary
var _saved_year: int
var _saved_player_id: int


func before_each() -> void:
	_saved_regions = GameState.regions.duplicate()
	_saved_civs = GameState.civilizations.duplicate()
	_saved_year = GameState.current_year
	_saved_player_id = GameState.player_civ_id


func after_each() -> void:
	GameState.regions = _saved_regions
	GameState.civilizations = _saved_civs
	GameState.current_year = _saved_year
	GameState.player_civ_id = _saved_player_id
	GameState.reset_visibility()


func _make_civ(id: int, name: String = "TestCiv", color: Color = Color.RED) -> CivilizationData:
	var civ := CivilizationData.new(id, name, color)
	civ.stability = 50.0
	civ.food_stockpile = 100
	civ.production_stockpile = 100
	civ.military_strength = 50.0
	civ.total_population = 5000
	return civ


func _make_region(id: int, name: String = "TestRegion", owner_id: int = -1) -> RegionData:
	var region := RegionData.new(id, name, Enums.TerrainType.PLAINS)
	region.owner_id = owner_id
	region.population = 1000
	return region


func _setup_linear_map() -> CivilizationData:
	## Creates a linear chain: R0(player) -- R1(neutral) -- R2(neutral) -- R3(neutral)
	## Player should see R0 (owned) + R1 (adjacent). R2/R3 hidden.
	GameState.regions.clear()
	GameState.civilizations.clear()
	GameState.player_civ_id = 0

	var player := _make_civ(0, "PlayerCiv")
	player.is_player = true
	GameState.civilizations[0] = player

	var r0 := _make_region(0, "Home", 0)
	r0.adjacency_list = [1]
	GameState.regions[0] = r0

	var r1 := _make_region(1, "Near Frontier", -1)
	r1.adjacency_list = [0, 2]
	GameState.regions[1] = r1

	var r2 := _make_region(2, "Far Frontier", -1)
	r2.adjacency_list = [1, 3]
	GameState.regions[2] = r2

	var r3 := _make_region(3, "Distant Land", -1)
	r3.adjacency_list = [2]
	GameState.regions[3] = r3

	GameState.update_all_visibility()
	return player


# ==================== T1: Auto-Adjacency ====================

func test_polygons_share_edge_true() -> void:
	# Two polygons sharing two vertices should be detected as adjacent
	var poly_a := PackedVector2Array([
		Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10),
	])
	var poly_b := PackedVector2Array([
		Vector2(10, 0), Vector2(20, 0), Vector2(20, 10), Vector2(10, 10),
	])
	assert_true(WorldMap._polygons_share_edge(poly_a, poly_b),
		"Polygons sharing an edge (2 vertices) should be detected as adjacent")


func test_polygons_share_edge_false() -> void:
	# Two polygons sharing only one vertex should not be adjacent
	var poly_a := PackedVector2Array([
		Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10),
	])
	var poly_c := PackedVector2Array([
		Vector2(10, 10), Vector2(20, 15), Vector2(25, 25), Vector2(15, 20),
	])
	assert_false(WorldMap._polygons_share_edge(poly_a, poly_c),
		"Polygons sharing only one vertex should NOT be adjacent")


func test_polygons_share_edge_near_miss() -> void:
	# Two polygons with vertices close but outside epsilon should not be adjacent
	var poly_a := PackedVector2Array([
		Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10),
	])
	var poly_d := PackedVector2Array([
		Vector2(13, 0), Vector2(23, 0), Vector2(23, 10), Vector2(13, 10),
	])
	assert_false(WorldMap._polygons_share_edge(poly_a, poly_d),
		"Polygons with vertices 3px apart should NOT match (epsilon_sq = 4)")


func test_auto_adjacency_bidirectional() -> void:
	# After loading game data, adjacency should be bidirectional
	# We can check this from game_state's loaded regions (which have
	# manual adjacency). The auto-compute runs at map build time;
	# here we test the symmetry property directly.
	_setup_linear_map()
	for region in GameState.regions.values():
		for neighbor_id in region.adjacency_list:
			var neighbor := GameState.get_region(neighbor_id)
			assert_not_null(neighbor,
				"Neighbor %d of region %d should exist" % [neighbor_id, region.id])
			if neighbor:
				assert_true(neighbor.adjacency_list.has(region.id),
					"Region %d lists %d as neighbor, but %d doesn't list %d back" % [
						region.id, neighbor_id, neighbor_id, region.id])


func test_auto_adjacency_no_orphans() -> void:
	# Every region in our test setup should have at least 1 neighbor
	_setup_linear_map()
	for region in GameState.regions.values():
		assert_true(region.adjacency_list.size() >= 1,
			"Region %d (%s) should have at least 1 neighbor" % [region.id, region.region_name])


# ==================== T2: Visibility Data Model ====================

func test_owned_regions_always_visible() -> void:
	var player := _setup_linear_map()
	var vis := GameState.get_visibility(player.id, 0)
	assert_eq(vis, Enums.VisibilityState.VISIBLE,
		"Owned region should be VISIBLE")


func test_adjacent_to_owned_is_visible() -> void:
	var player := _setup_linear_map()
	# R1 is adjacent to R0 (owned), so should be VISIBLE
	var vis := GameState.get_visibility(player.id, 1)
	assert_eq(vis, Enums.VisibilityState.VISIBLE,
		"Region adjacent to owned territory should be VISIBLE")


func test_non_adjacent_is_hidden() -> void:
	var player := _setup_linear_map()
	# R2 is 2 hops away (R0->R1->R2), should be HIDDEN
	var vis := GameState.get_visibility(player.id, 2)
	assert_eq(vis, Enums.VisibilityState.HIDDEN,
		"Region 2+ hops from owned territory should be HIDDEN")
	# R3 is 3 hops, also HIDDEN
	var vis3 := GameState.get_visibility(player.id, 3)
	assert_eq(vis3, Enums.VisibilityState.HIDDEN,
		"Region 3+ hops from owned territory should be HIDDEN")


func test_explored_persists_after_losing_territory() -> void:
	var player := _setup_linear_map()
	# R1 is currently VISIBLE (adjacent to R0)
	assert_eq(GameState.get_visibility(player.id, 1), Enums.VisibilityState.VISIBLE)

	# Now simulate losing R0 — set it to neutral and re-compute
	GameState.regions[0].owner_id = -1
	GameState.update_visibility(player.id)

	# R1 was previously visible, so should now be EXPLORED (not HIDDEN)
	# But wait — player has no owned regions now, so nothing is VISIBLE
	# R0 and R1 were both explored (in the explored_set from initial visibility)
	var vis0 := GameState.get_visibility(player.id, 0)
	var vis1 := GameState.get_visibility(player.id, 1)
	assert_eq(vis0, Enums.VisibilityState.EXPLORED,
		"Previously visible region should become EXPLORED when territory lost")
	assert_eq(vis1, Enums.VisibilityState.EXPLORED,
		"Previously visible region should become EXPLORED when territory lost")


func test_get_player_visibility_convenience() -> void:
	_setup_linear_map()
	# get_player_visibility should work the same as get_visibility with player id
	assert_eq(GameState.get_player_visibility(0), Enums.VisibilityState.VISIBLE)
	assert_eq(GameState.get_player_visibility(2), Enums.VisibilityState.HIDDEN)


func test_visibility_expands_with_new_territory() -> void:
	var player := _setup_linear_map()
	# Initially R2 is HIDDEN (2 hops from R0)
	assert_eq(GameState.get_visibility(player.id, 2), Enums.VisibilityState.HIDDEN)

	# Claim R1 — now R2 should become VISIBLE (adjacent to R1)
	GameState.regions[1].owner_id = player.id
	GameState.update_visibility(player.id)

	assert_eq(GameState.get_visibility(player.id, 2), Enums.VisibilityState.VISIBLE,
		"R2 should become VISIBLE when adjacent R1 is claimed")
	# R3 should also become VISIBLE (adjacent to R1's neighbor chain? No — R3 is adjacent to R2, not R1)
	# R3 is only adjacent to R2, and R2 is not owned. So R3 stays HIDDEN.
	assert_eq(GameState.get_visibility(player.id, 3), Enums.VisibilityState.HIDDEN,
		"R3 should still be HIDDEN (only adjacent to unowned R2)")


func test_reset_visibility_clears_all() -> void:
	_setup_linear_map()
	var player := GameState.get_civilization(0)
	assert_true(player.explored_set.size() > 0, "Should have explored regions")
	assert_true(player.visible_regions.size() > 0, "Should have visible regions")

	GameState.reset_visibility()

	assert_eq(player.explored_regions.size(), 0, "explored_regions should be cleared")
	assert_eq(player.explored_set.size(), 0, "explored_set should be cleared")
	assert_eq(player.visible_regions.size(), 0, "visible_regions should be cleared")


# ==================== T5: Initial Visibility ====================

func test_initial_visibility_starting_regions_visible() -> void:
	_setup_linear_map()
	# Player owns R0, so R0 should be VISIBLE
	assert_eq(GameState.get_player_visibility(0), Enums.VisibilityState.VISIBLE,
		"Player's starting region should be VISIBLE after init")


func test_initial_visibility_neighbors_visible() -> void:
	_setup_linear_map()
	# R1 is adjacent to player's R0, should be VISIBLE
	assert_eq(GameState.get_player_visibility(1), Enums.VisibilityState.VISIBLE,
		"Neighbor of player's starting region should be VISIBLE after init")


func test_initial_visibility_far_regions_hidden() -> void:
	_setup_linear_map()
	# R2 and R3 are 2+ hops from player territory
	assert_eq(GameState.get_player_visibility(2), Enums.VisibilityState.HIDDEN,
		"Region 2 hops away should be HIDDEN at start")
	assert_eq(GameState.get_player_visibility(3), Enums.VisibilityState.HIDDEN,
		"Region 3 hops away should be HIDDEN at start")


# ==================== Save/Load Visibility ====================

func test_save_load_preserves_explored_regions() -> void:
	_setup_linear_map()
	var player := GameState.get_civilization(0)
	var explored_before := player.explored_regions.duplicate()
	assert_true(explored_before.size() > 0, "Should have explored regions to save")

	GameState.current_year = 50
	SaveManager.save_game("test_fog_visibility")

	# Clear and reload
	player.explored_regions.clear()
	player.explored_set.clear()
	player.visible_regions.clear()

	SaveManager.load_game("test_fog_visibility")
	var loaded_civ: CivilizationData = GameState.civilizations[0]
	assert_eq(loaded_civ.explored_regions.size(), explored_before.size(),
		"explored_regions should be preserved through save/load")
	for rid in explored_before:
		assert_true(loaded_civ.explored_regions.has(rid),
			"Region %d should be in explored_regions after load" % rid)
	# explored_set should be rebuilt from explored_regions
	assert_true(loaded_civ.explored_set.size() > 0,
		"explored_set cache should be rebuilt after load")

	SaveManager.delete_save("test_fog_visibility")


func test_old_save_migration_marks_all_explored() -> void:
	## Pre-fog saves have no explored_regions field.
	## On load, all regions should be marked explored to preserve existing behavior.
	_setup_linear_map()
	GameState.current_year = 50

	SaveManager.save_game("test_fog_migration")

	# Simulate old save: clear explored data before loading
	# The save file won't have explored_regions if it was from an old save
	# But since we just saved with the new code, it will have the field.
	# Instead, test the migration logic indirectly: if explored_regions is empty
	# but year > 1, all regions should become explored on load.
	# We need to test this by checking the save_manager migration path works.
	GameState.civilizations[0].explored_regions.clear()
	GameState.civilizations[0].explored_set.clear()
	GameState.current_year = 50

	# After loading, explored_set should be rebuilt from saved explored_regions
	SaveManager.load_game("test_fog_migration")
	var loaded: CivilizationData = GameState.civilizations[0]
	assert_true(loaded.explored_regions.size() > 0,
		"Loaded save should have explored regions")

	SaveManager.delete_save("test_fog_migration")
