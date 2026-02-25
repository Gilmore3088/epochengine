extends GutTest

## Tests for RegionVisual terrain texture system (dual-mode rendering,
## UV tiling, tint overlay, fallback behavior, and TerrainDecorations).


func _make_region(
	region_id: int = 0,
	terrain: Enums.TerrainType = Enums.TerrainType.PLAINS,
) -> RegionData:
	return RegionData.new(region_id, "TestRegion_%d" % region_id, terrain)


func _make_points() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-20, -15),
		Vector2(20, -15),
		Vector2(25, 10),
		Vector2(-10, 20),
		Vector2(-25, 5),
	])


# --- UV Tiling ---

func test_world_space_uv_returns_correct_count() -> void:
	var visual := RegionVisual.new()
	visual.region_data = _make_region(42)
	visual.position = Vector2(400, 300)
	var points := _make_points()
	var tex_size := Vector2(512, 512)

	var uv := visual._compute_world_space_uv(points, tex_size)
	assert_eq(uv.size(), points.size(),
		"UV array should have same count as polygon points")
	visual.free()


func test_world_space_uv_deterministic() -> void:
	var points := _make_points()
	var tex_size := Vector2(512, 512)

	var v1 := RegionVisual.new()
	v1.region_data = _make_region(7)
	v1.position = Vector2(100, 200)
	var uv1 := v1._compute_world_space_uv(points, tex_size)
	v1.free()

	var v2 := RegionVisual.new()
	v2.region_data = _make_region(7)
	v2.position = Vector2(100, 200)
	var uv2 := v2._compute_world_space_uv(points, tex_size)
	v2.free()

	for i in uv1.size():
		assert_almost_eq(uv1[i].x, uv2[i].x, 0.0001,
			"UV x should be deterministic for same region")
		assert_almost_eq(uv1[i].y, uv2[i].y, 0.0001,
			"UV y should be deterministic for same region")


func test_world_space_uv_different_regions_differ() -> void:
	var points := _make_points()
	var tex_size := Vector2(512, 512)

	var v1 := RegionVisual.new()
	v1.region_data = _make_region(10)
	v1.position = Vector2(100, 200)
	var uv1 := v1._compute_world_space_uv(points, tex_size)
	v1.free()

	var v2 := RegionVisual.new()
	v2.region_data = _make_region(20)
	v2.position = Vector2(100, 200)
	var uv2 := v2._compute_world_space_uv(points, tex_size)
	v2.free()

	var all_same := true
	for i in uv1.size():
		if not is_equal_approx(uv1[i].x, uv2[i].x) or not is_equal_approx(uv1[i].y, uv2[i].y):
			all_same = false
			break
	assert_false(all_same,
		"Different region IDs should produce different UV coordinates")


func test_world_space_uv_uses_global_position() -> void:
	var points := _make_points()
	var tex_size := Vector2(512, 512)

	var v1 := RegionVisual.new()
	v1.region_data = _make_region(5)
	v1.position = Vector2(0, 0)
	var uv1 := v1._compute_world_space_uv(points, tex_size)
	v1.free()

	var v2 := RegionVisual.new()
	v2.region_data = _make_region(5)
	v2.position = Vector2(500, 500)
	var uv2 := v2._compute_world_space_uv(points, tex_size)
	v2.free()

	var all_same := true
	for i in uv1.size():
		if not is_equal_approx(uv1[i].x, uv2[i].x) or not is_equal_approx(uv1[i].y, uv2[i].y):
			all_same = false
			break
	assert_false(all_same,
		"Different global positions should produce different UVs")


# --- Fallback Behavior ---

func test_has_texture_true_with_generated_fallback() -> void:
	# Generated textures now provide fallback when paths are empty
	var visual := RegionVisual.new()
	visual.region_data = _make_region(0)
	visual.polygon = Polygon2D.new()
	var result := visual._apply_terrain_texture(_make_points())
	assert_true(result, "_apply_terrain_texture should return true with generated texture")
	visual.polygon.free()
	visual.free()


func test_has_texture_true_for_all_terrain_types() -> void:
	for terrain_int in range(9):
		var visual := RegionVisual.new()
		visual.region_data = _make_region(terrain_int, terrain_int as Enums.TerrainType)
		visual.polygon = Polygon2D.new()
		var result := visual._apply_terrain_texture(_make_points())
		assert_true(result,
			"Terrain type %d should have generated texture" % terrain_int)
		visual.polygon.free()
		visual.free()


# --- Tint Overlay Constants ---

func test_tint_alpha_political_in_range() -> void:
	assert_true(Constants.TINT_ALPHA_POLITICAL >= 0.25,
		"Political tint alpha should be at least 0.25")
	assert_true(Constants.TINT_ALPHA_POLITICAL <= 0.45,
		"Political tint alpha should be at most 0.45")


func test_tint_alpha_heatmap_higher_than_political() -> void:
	assert_true(Constants.TINT_ALPHA_HEATMAP > Constants.TINT_ALPHA_POLITICAL,
		"Heatmap alpha should be higher than political for data readability")


func test_terrain_tile_scale_positive() -> void:
	assert_true(Constants.TERRAIN_TILE_SCALE > 0.0,
		"Tile scale must be positive")


func test_uv_rotations_has_four_entries() -> void:
	assert_eq(Constants.UV_ROTATIONS.size(), 4,
		"Should have exactly 4 UV rotation options (0/90/180/270)")


# --- Per-Region Variation ---

func test_variation_within_range() -> void:
	var visual := RegionVisual.new()
	for id in [0, 1, 50, 99, 115]:
		visual.region_data = _make_region(id)
		var v := visual._region_color_variation()
		assert_true(v >= -Constants.VARIATION_BRIGHTNESS_RANGE,
			"Variation for region %d should be >= -%f" % [id, Constants.VARIATION_BRIGHTNESS_RANGE])
		assert_true(v <= Constants.VARIATION_BRIGHTNESS_RANGE,
			"Variation for region %d should be <= %f" % [id, Constants.VARIATION_BRIGHTNESS_RANGE])
	visual.free()


func test_variation_differs_between_regions() -> void:
	var visual := RegionVisual.new()
	visual.region_data = _make_region(0)
	var v0 := visual._region_color_variation()
	visual.region_data = _make_region(1)
	var v1 := visual._region_color_variation()
	assert_true(not is_equal_approx(v0, v1),
		"Different region IDs should produce different variations")
	visual.free()


# --- TerrainDecorations ---

func test_decorations_build_adds_children_for_mountains() -> void:
	var parent := Node2D.new()
	add_child(parent)  # Need scene tree for add_child
	TerrainDecorations.build(
		Enums.TerrainType.MOUNTAINS,
		Vector2.ZERO,
		42,
		parent,
	)
	assert_true(parent.get_child_count() > 0,
		"MOUNTAINS should add decoration children")
	parent.queue_free()


func test_decorations_build_adds_children_for_river() -> void:
	var parent := Node2D.new()
	add_child(parent)
	TerrainDecorations.build(
		Enums.TerrainType.RIVER_BASIN,
		Vector2.ZERO,
		10,
		parent,
	)
	assert_true(parent.get_child_count() > 0,
		"RIVER_BASIN should add decoration children")
	parent.queue_free()


func test_decorations_build_steppe_has_children() -> void:
	var parent := Node2D.new()
	add_child(parent)
	TerrainDecorations.build(
		Enums.TerrainType.STEPPE,
		Vector2.ZERO,
		5,
		parent,
	)
	assert_gt(parent.get_child_count(), 0,
		"STEPPE should add grass decorations")
	parent.queue_free()


func test_decorations_build_volcanic_has_children() -> void:
	var parent := Node2D.new()
	add_child(parent)
	TerrainDecorations.build(
		Enums.TerrainType.VOLCANIC_RIDGE,
		Vector2.ZERO,
		6,
		parent,
	)
	assert_gt(parent.get_child_count(), 0,
		"VOLCANIC_RIDGE should add vent decorations")
	parent.queue_free()


func test_decorations_deterministic() -> void:
	var parent1 := Node2D.new()
	var parent2 := Node2D.new()
	add_child(parent1)
	add_child(parent2)
	TerrainDecorations.build(Enums.TerrainType.MOUNTAINS, Vector2.ZERO, 7, parent1)
	TerrainDecorations.build(Enums.TerrainType.MOUNTAINS, Vector2.ZERO, 7, parent2)
	assert_eq(parent1.get_child_count(), parent2.get_child_count(),
		"Same region ID should produce same number of decorations")
	parent1.queue_free()
	parent2.queue_free()


# --- Centroid Calculation ---

func test_calculate_centroid() -> void:
	var points := PackedVector2Array([
		Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10),
	])
	var centroid := RegionVisual._calculate_centroid(points)
	assert_almost_eq(centroid.x, 5.0, 0.001, "Centroid X should be 5")
	assert_almost_eq(centroid.y, 5.0, 0.001, "Centroid Y should be 5")


# --- Config Flex (F0.1) ---

func test_tile_scale_override_all_zero_by_default() -> void:
	for terrain_int in range(9):
		var override_val: float = Constants.TERRAIN_TILE_SCALE_OVERRIDE.get(terrain_int, 0.0)
		assert_eq(override_val, 0.0,
			"Terrain %d tile scale override should default to 0.0" % terrain_int)


func test_tint_alpha_override_all_zero_by_default() -> void:
	for terrain_int in range(9):
		var override_val: float = Constants.TERRAIN_TINT_ALPHA_OVERRIDE.get(terrain_int, 0.0)
		assert_eq(override_val, 0.0,
			"Terrain %d tint alpha override should default to 0.0" % terrain_int)


func test_tile_scale_override_used_when_nonzero() -> void:
	# With override = 0.0, tile_scale should equal the global default.
	var override_val: float = Constants.TERRAIN_TILE_SCALE_OVERRIDE.get(0, 0.0)
	var effective: float = override_val if override_val > 0.0 else Constants.TERRAIN_TILE_SCALE
	assert_eq(effective, Constants.TERRAIN_TILE_SCALE,
		"Zero override should fall back to global TERRAIN_TILE_SCALE")


func test_override_dicts_cover_all_terrain_types() -> void:
	assert_eq(Constants.TERRAIN_TILE_SCALE_OVERRIDE.size(), 9,
		"Tile scale override should have 9 entries (one per terrain type)")
	assert_eq(Constants.TERRAIN_TINT_ALPHA_OVERRIDE.size(), 9,
		"Tint alpha override should have 9 entries (one per terrain type)")


# --- TerrainTextureGenerator ---

func test_terrain_texture_generator_returns_texture() -> void:
	for terrain_int in range(9):
		var tex := TerrainTextureGenerator.get_texture(terrain_int)
		assert_not_null(tex,
			"Terrain type %d should return a non-null texture" % terrain_int)


func test_terrain_texture_generator_deterministic() -> void:
	# Clear cache to force re-generation
	TerrainTextureGenerator._cache.clear()
	var tex1 := TerrainTextureGenerator.get_texture(2)
	# Second call should return cached texture (same instance)
	var tex2 := TerrainTextureGenerator.get_texture(2)
	assert_eq(tex1, tex2,
		"Same terrain type should return the same cached texture")


# --- Fog of War Rendering ---

func test_hidden_region_shows_muted_terrain_shape() -> void:
	var visual := RegionVisual.new()
	visual.region_data = _make_region(0)
	visual.polygon = Polygon2D.new()
	visual.tint_overlay = Polygon2D.new()
	visual._local_points = PackedVector2Array([
		Vector2(-10, -10), Vector2(10, -10), Vector2(10, 10), Vector2(-10, 10)
	])
	visual._current_era = 2  # Industrial
	visual._render_hidden()
	# Should use fog texture (not null) now
	assert_not_null(visual.polygon.texture,
		"Hidden region should have fog texture")
	assert_false(visual.tint_overlay.visible,
		"Hidden region should hide tint overlay")
	visual.tint_overlay.free()
	visual.polygon.free()
	visual.free()


func test_explored_modulate_applied() -> void:
	# EXPLORED_MODULATE should be a desaturated color (not white, not zero)
	var mod := RegionVisual.EXPLORED_MODULATE
	assert_true(mod.r < 1.0, "EXPLORED_MODULATE red should be less than 1.0")
	assert_true(mod.g < 1.0, "EXPLORED_MODULATE green should be less than 1.0")
	assert_true(mod.r > 0.0, "EXPLORED_MODULATE red should be greater than 0.0")
	assert_eq(mod.a, 1.0, "EXPLORED_MODULATE alpha should be 1.0")


# --- Era-Aware Rendering ---

func test_era_visual_params_all_eras_present() -> void:
	for era in [0, 1, 2, 3]:
		assert_true(Constants.ERA_VISUAL_PARAMS.has(era),
			"ERA_VISUAL_PARAMS should have entry for era %d" % era)


func test_era_visual_params_required_keys() -> void:
	var required_keys := [
		"border_width", "border_alpha", "civ_border_width", "border_style",
		"fog_color", "explored_modulate", "tint_alpha",
		"noise_frequency_mult", "noise_contrast_mult", "deco_density",
		"label_font_size", "label_alpha",
	]
	for era in [0, 1, 2, 3]:
		var params: Dictionary = Constants.ERA_VISUAL_PARAMS[era]
		for key in required_keys:
			assert_true(params.has(key),
				"Era %d should have key '%s'" % [era, key])


func test_era_fog_colors_differ() -> void:
	var prehistoric_fog: Color = Constants.ERA_VISUAL_PARAMS[0]["fog_color"]
	var future_fog: Color = Constants.ERA_VISUAL_PARAMS[3]["fog_color"]
	assert_ne(prehistoric_fog, future_fog,
		"Prehistoric and Future fog colors should differ")


func test_era_texture_cache_keying() -> void:
	TerrainTextureGenerator._cache.clear()
	var tex_prehistoric := TerrainTextureGenerator.get_texture_for_era(1, 0)
	var tex_industrial := TerrainTextureGenerator.get_texture_for_era(1, 2)
	assert_not_null(tex_prehistoric, "Prehistoric texture should not be null")
	assert_not_null(tex_industrial, "Industrial texture should not be null")
	assert_ne(tex_prehistoric, tex_industrial,
		"Different eras should produce different cached textures")


func test_hidden_fog_color_per_era() -> void:
	# Prehistoric and Future hidden renders should use different fog textures
	var visual := RegionVisual.new()
	visual.region_data = _make_region(0, Enums.TerrainType.PLAINS)
	visual.polygon = Polygon2D.new()
	visual.tint_overlay = Polygon2D.new()
	visual._local_points = PackedVector2Array([
		Vector2(-10, -10), Vector2(10, -10), Vector2(10, 10), Vector2(-10, 10)
	])

	visual._current_era = 0
	visual._render_hidden()
	var prehistoric_tex := visual.polygon.texture

	visual._current_era = 3
	visual._render_hidden()
	var future_tex := visual.polygon.texture

	assert_not_same(prehistoric_tex, future_tex,
		"Hidden fog texture should differ between Prehistoric and Future eras")

	visual.tint_overlay.free()
	visual.polygon.free()
	visual.free()


func test_get_era_params_returns_dict() -> void:
	var visual := RegionVisual.new()
	visual.region_data = _make_region(0)
	visual._current_era = 1
	var params := visual._get_era_params()
	assert_true(params is Dictionary, "Era params should be a Dictionary")
	assert_true(params.has("fog_color"), "Params should contain fog_color")
	visual.free()


func test_get_era_params_fallback_to_industrial() -> void:
	var visual := RegionVisual.new()
	visual.region_data = _make_region(0)
	visual._current_era = 99  # Invalid era
	var params := visual._get_era_params()
	var industrial := Constants.ERA_VISUAL_PARAMS[2]
	assert_eq(params["fog_color"], industrial["fog_color"],
		"Invalid era should fall back to Industrial (era 2)")
	visual.free()


func test_noise_frequency_scales_with_era() -> void:
	# Prehistoric should have lower freq mult, Future higher
	var prehistoric_freq: float = Constants.ERA_VISUAL_PARAMS[0]["noise_frequency_mult"]
	var industrial_freq: float = Constants.ERA_VISUAL_PARAMS[2]["noise_frequency_mult"]
	var future_freq: float = Constants.ERA_VISUAL_PARAMS[3]["noise_frequency_mult"]
	assert_true(prehistoric_freq < industrial_freq,
		"Prehistoric noise freq should be less than Industrial")
	assert_true(future_freq > industrial_freq,
		"Future noise freq should be greater than Industrial")
