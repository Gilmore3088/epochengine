extends GutTest

## Tests for the graphics rendering overhaul (Phases 1-6).
## Verifies texture generation, decorations, lighting, and river enhancements.


# --- Phase 1: Multi-Pass Terrain Textures ---

func test_each_terrain_produces_512x512_texture() -> void:
	## Every terrain type (0-8) must produce a valid 512x512 texture.
	for terrain_type in 9:
		var tex := TerrainTextureGenerator.get_texture(terrain_type)
		assert_not_null(tex, "Terrain %d should produce a texture" % terrain_type)
		assert_eq(tex.get_width(), 512, "Terrain %d width should be 512" % terrain_type)
		assert_eq(tex.get_height(), 512, "Terrain %d height should be 512" % terrain_type)


func test_texture_cache_works() -> void:
	## Same terrain+era should return the same cached texture object.
	var tex_a := TerrainTextureGenerator.get_texture_for_era(2, 1)
	var tex_b := TerrainTextureGenerator.get_texture_for_era(2, 1)
	assert_same(tex_a, tex_b, "Same terrain+era should return cached texture")


func test_era_multipliers_produce_different_textures() -> void:
	## Different eras for the same terrain must produce distinct textures.
	TerrainTextureGenerator._cache.clear()
	var tex_prehistoric := TerrainTextureGenerator.get_texture_for_era(0, 0)
	var tex_future := TerrainTextureGenerator.get_texture_for_era(0, 3)
	# They must not be the same image (different noise params)
	var img_a := tex_prehistoric.get_image()
	var img_b := tex_future.get_image()
	var same := true
	# Spot-check a few pixels
	for pos in [Vector2i(100, 100), Vector2i(256, 256), Vector2i(400, 50)]:
		if img_a.get_pixelv(pos) != img_b.get_pixelv(pos):
			same = false
			break
	assert_false(same, "Prehistoric and Future textures should differ")


func test_all_terrains_have_palettes() -> void:
	## PALETTES dict must have an entry for every terrain type 0-8.
	for terrain_type in 9:
		assert_true(
			TerrainTextureGenerator.PALETTES.has(terrain_type),
			"Palette missing for terrain %d" % terrain_type)
		var pal: Array = TerrainTextureGenerator.PALETTES[terrain_type]
		assert_eq(pal.size(), 3, "Palette for terrain %d should have 3 colors" % terrain_type)


# --- Phase 2: Terrain Decorations ---

func test_each_terrain_generates_decorations() -> void:
	## Every terrain type should produce decorations without error.
	for terrain_type in 9:
		var parent := Node2D.new()
		add_child_autofree(parent)
		var centroid := Vector2(100, 100)
		TerrainDecorations.build(terrain_type, centroid, terrain_type * 10 + 1, parent)
		assert_gt(parent.get_child_count(), 0,
			"Terrain %d should produce at least 1 decoration" % terrain_type)


func test_decorations_deterministic() -> void:
	## Same region_id + terrain must produce same decoration count.
	var parent_a := Node2D.new()
	add_child_autofree(parent_a)
	TerrainDecorations.build(2, Vector2(50, 50), 42, parent_a)

	var parent_b := Node2D.new()
	add_child_autofree(parent_b)
	TerrainDecorations.build(2, Vector2(50, 50), 42, parent_b)

	assert_eq(parent_a.get_child_count(), parent_b.get_child_count(),
		"Same inputs should produce same decoration count")


# --- Phase 5: Elevation & Directional Lighting ---

func test_lighting_mod_range() -> void:
	## Lighting mod must stay within [-0.08, +0.06] for any region.
	_setup_game_state()
	for region in GameState.regions.values():
		var visual := RegionVisual.new()
		visual.position = Vector2(float(region.id) * 20.0, float(region.id) * 15.0)
		var pts := PackedVector2Array([
			Vector2(-10, -10), Vector2(10, -10), Vector2(10, 10), Vector2(-10, 10)
		])
		visual.region_data = region
		visual._local_points = pts
		var mod := visual._compute_lighting_mod()
		assert_gte(mod, -0.04, "Region %d lighting mod too low: %f" % [region.id, mod])
		assert_lte(mod, 0.04, "Region %d lighting mod too high: %f" % [region.id, mod])
		visual.free()


func test_lighting_elevation_component() -> void:
	## Mountains (elev 3) should have negative mod, low terrain (elev 0) positive.
	_setup_game_state()
	# Find a mountain and a river basin region
	var mountain_region: RegionData = null
	var lowland_region: RegionData = null
	for region in GameState.regions.values():
		if region.terrain_type == Enums.TerrainType.MOUNTAINS and not mountain_region:
			mountain_region = region
		if region.terrain_type == Enums.TerrainType.RIVER_BASIN and not lowland_region:
			lowland_region = region

	if mountain_region and lowland_region:
		var pts := PackedVector2Array([
			Vector2(-10, -10), Vector2(10, -10), Vector2(10, 10), Vector2(-10, 10)
		])
		# Place both at map center to isolate elevation component
		var vis_m := RegionVisual.new()
		vis_m.position = RegionVisual.MAP_CENTER
		vis_m.region_data = mountain_region
		vis_m._local_points = pts
		var mod_m := vis_m._compute_lighting_mod()

		var vis_l := RegionVisual.new()
		vis_l.position = RegionVisual.MAP_CENTER
		vis_l.region_data = lowland_region
		vis_l._local_points = pts
		var mod_l := vis_l._compute_lighting_mod()

		assert_lt(mod_m, mod_l, "Mountains should be darker than lowlands")
		vis_m.free()
		vis_l.free()
	else:
		pass_test("Skipped: no mountain or lowland region found")


# --- Phase 4: River Enhancement ---

func test_river_order_assigned() -> void:
	## After RiverGenerator runs, some regions should have river_order > 0.
	_setup_game_state()
	RiverGenerator.generate(GameState.regions, 42)
	var has_order := false
	for region in GameState.regions.values():
		if region.river_order > 0:
			has_order = true
			break
	assert_true(has_order, "At least one region should have river_order > 0")


func test_river_order_increases_downstream() -> void:
	## Downstream regions should have higher river_order than headwaters.
	_setup_game_state()
	RiverGenerator.generate(GameState.regions, 42)
	var max_order := 0
	var min_order := 999
	for region in GameState.regions.values():
		if region.river_order > 0:
			max_order = maxi(max_order, region.river_order)
			min_order = mini(min_order, region.river_order)
	if max_order > 0:
		assert_gt(max_order, min_order, "River system should have varying orders")
	else:
		pass_test("Skipped: no rivers generated")


# --- Phase 6: Political Overlay ---

func test_tint_alpha_values_reasonable() -> void:
	## ERA_VISUAL_PARAMS tint_alpha should be <=0.35 for all eras (terrain shows through).
	for era in Constants.ERA_VISUAL_PARAMS:
		var tint_alpha: float = Constants.ERA_VISUAL_PARAMS[era]["tint_alpha"]
		assert_lte(tint_alpha, 0.35, "Era %d tint_alpha should be <= 0.35" % era)


func test_border_tint_alpha_exists() -> void:
	## Constants should have TINT_ALPHA_BORDER.
	assert_gt(Constants.TINT_ALPHA_BORDER, Constants.TINT_ALPHA_POLITICAL,
		"Border alpha should be higher than political alpha")


# --- Graphics Polish: Terrain Contrast ---

func test_plains_palette_green_dominant() -> void:
	## Plains mid-palette should have green > red (verdant meadow).
	var pal: Array = TerrainTextureGenerator.PALETTES[1]
	var mid: Color = pal[1]
	assert_gt(mid.g, mid.r, "Plains mid-palette green should exceed red")


func test_steppe_palette_red_dominant() -> void:
	## Steppe mid-palette should have red > green (dry brown earth).
	var pal: Array = TerrainTextureGenerator.PALETTES[7]
	var mid: Color = pal[1]
	assert_gt(mid.r, mid.g, "Steppe mid-palette red should exceed green")


# --- Graphics Polish: Empire Borders ---

func test_get_border_color_civ_owned() -> void:
	## _get_border_color should return civ color for owned regions.
	_setup_game_state()
	var civ := GameState.get_civilization(0)
	if civ:
		var map := WorldMap.new()
		var color := map._get_border_color(0)
		assert_eq(color, civ.color, "Border color should match civ color")
		map.free()
	else:
		pass_test("Skipped: no civ 0")


func test_get_border_color_neutral() -> void:
	## _get_border_color should return muted brown for neutral (owner_id < 0).
	var map := WorldMap.new()
	var color := map._get_border_color(-1)
	assert_lt(color.r, 0.5, "Neutral border should be muted")
	map.free()


func test_blend_two_colors_symmetric() -> void:
	## _blend_two_colors(a, b) == _blend_two_colors(b, a)
	var a := Color(0.8, 0.2, 0.1)
	var b := Color(0.1, 0.3, 0.9)
	var ab := WorldMap._blend_two_colors(a, b)
	var ba := WorldMap._blend_two_colors(b, a)
	assert_almost_eq(ab.r, ba.r, 0.01, "Blended colors should be symmetric (r)")
	assert_almost_eq(ab.g, ba.g, 0.01, "Blended colors should be symmetric (g)")
	assert_almost_eq(ab.b, ba.b, 0.01, "Blended colors should be symmetric (b)")


# --- Graphics Polish: Fog Textures ---

func test_fog_texture_non_null_all_eras() -> void:
	## get_fog_texture(era) must return non-null for eras 0-3.
	for era in 4:
		var tex := TerrainTextureGenerator.get_fog_texture(era)
		assert_not_null(tex, "Fog texture for era %d should not be null" % era)


func test_fog_texture_512x512() -> void:
	## Fog texture should be 512x512.
	var tex := TerrainTextureGenerator.get_fog_texture(0)
	assert_eq(tex.get_width(), 512, "Fog texture width should be 512")
	assert_eq(tex.get_height(), 512, "Fog texture height should be 512")


func test_fog_texture_cached() -> void:
	## Same era fog texture should return cached object.
	var tex_a := TerrainTextureGenerator.get_fog_texture(1)
	var tex_b := TerrainTextureGenerator.get_fog_texture(1)
	assert_same(tex_a, tex_b, "Same era fog should return cached texture")


func test_fog_textures_differ_by_era() -> void:
	## Different eras should produce different fog textures.
	TerrainTextureGenerator._cache.clear()
	var tex_0 := TerrainTextureGenerator.get_fog_texture(0)
	var tex_3 := TerrainTextureGenerator.get_fog_texture(3)
	var img_a := tex_0.get_image()
	var img_b := tex_3.get_image()
	var same := true
	for pos in [Vector2i(100, 100), Vector2i(256, 256), Vector2i(400, 50)]:
		if img_a.get_pixelv(pos) != img_b.get_pixelv(pos):
			same = false
			break
	assert_false(same, "Prehistoric and Future fog textures should differ")


# --- Graphics Polish: Edge Blending ---

func test_edge_blend_alpha_positive() -> void:
	## All edge blend layers should have positive alpha.
	for layer in Constants.EDGE_BLEND_LAYERS:
		var a: float = Constants.EDGE_BLEND_BASE_ALPHA - float(layer) * Constants.EDGE_BLEND_ALPHA_DECAY
		assert_gt(a, 0.0, "Edge blend layer %d alpha should be positive" % layer)


func test_each_terrain_has_blend_tint() -> void:
	## Every terrain type should have a valid tint color for blending.
	for terrain_type in 9:
		assert_true(
			RegionVisual.TERRAIN_TINTS.has(terrain_type),
			"TERRAIN_TINTS missing for terrain %d" % terrain_type)


# --- Graphics Polish: Color Grading ---

func test_color_grading_warms_polygon() -> void:
	## After color grading, polygon red channel should increase (warmer).
	_setup_game_state()
	var region: RegionData = null
	for r in GameState.regions.values():
		if r.terrain_type == Enums.TerrainType.PLAINS:
			region = r
			break
	if not region:
		pass_test("Skipped: no plains region")
		return
	var visual := RegionVisual.new()
	visual.region_data = region
	visual.polygon = Polygon2D.new()
	# Use a cool-ish color so the warm grading effect is clearly measurable
	visual.polygon.color = Color(0.3, 0.4, 0.5)
	var before_r: float = visual.polygon.color.r
	visual._apply_color_grading()
	var after_r: float = visual.polygon.color.r
	assert_gt(after_r, before_r, "Color grading should increase red channel (warmer)")
	visual.polygon.free()
	visual.free()


# --- Helpers ---

func _setup_game_state() -> void:
	GameState.regions.clear()
	GameState.civilizations.clear()
	GameState.heroes.clear()
	GameState.current_year = 0
	GameState.next_hero_id = 0
	GameState.next_town_id = 0
	GameState.turn_log.clear()
	GameState.player_civ_id = 0
	GameState.units.clear()
	GameState.next_unit_id = 0
	PlayerActions.clear_queue()
	GameState.load_game_data()
	GameState.start_new_game()
	for region in GameState.regions.values():
		region.towns = []
