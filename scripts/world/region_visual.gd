class_name RegionVisual
extends Node2D

## Visual representation of a single map region.
## Layered scene graph: base terrain -> political tint -> decorations -> UI.
## Supports both textured mode (seamless PNGs) and fallback mode (flat colors).

var region_data: RegionData
var polygon: Polygon2D
var detail_overlay: Polygon2D
var tint_overlay: Polygon2D
var terrain_deco: Node2D
var area: Area2D
var select_outline: Line2D
var select_marker: Polygon2D
var label: Label

var is_hovered: bool = false
var is_selected: bool = false
var current_zoom: float = 1.0
var _has_texture: bool = false
var _local_points: PackedVector2Array
var _current_visibility: Enums.VisibilityState = Enums.VisibilityState.VISIBLE
var _pending_battle_flash: bool = false
var _current_era: int = 2  # Player civ era (default Industrial)
var _infra_deco: Node2D  # Infrastructure + town markers layer
var _town_detail: Node2D  # Town detail layer (zoom > 2.5)
var _town_detail_visible: bool = false
var _micro_deco: Node2D  # Micro terrain decals (zoom-aware)
var _micro_deco_visible: bool = false
var _detail_overlay_visible: bool = false
var _town_overlay: Polygon2D
var _town_overlay_visible: bool = false
var _terrace_deco: Node2D
var _terrace_visible: bool = false

# Golden age glow
var _golden_age_tween: Tween
var _in_golden_age: bool = false

# Selection pulse
var _select_pulse_tween: Tween

# Label fade
var _label_tween: Tween

# Muted terrain tint colors (blended under political color in fallback mode)
const TERRAIN_TINTS := {
	Enums.TerrainType.RIVER_BASIN: Color(0.24, 0.50, 0.34),
	Enums.TerrainType.PLAINS: Color(0.44, 0.52, 0.32),
	Enums.TerrainType.MOUNTAINS: Color(0.40, 0.38, 0.34),
	Enums.TerrainType.DESERT: Color(0.70, 0.62, 0.42),
	Enums.TerrainType.JUNGLE: Color(0.18, 0.36, 0.22),
	Enums.TerrainType.COASTLINE: Color(0.32, 0.48, 0.58),
	Enums.TerrainType.TUNDRA: Color(0.52, 0.60, 0.68),
	Enums.TerrainType.STEPPE: Color(0.58, 0.50, 0.32),
	Enums.TerrainType.VOLCANIC_RIDGE: Color(0.36, 0.30, 0.28),
}

# Pure terrain colors (for terrain overlay in fallback mode)
const TERRAIN_COLORS := {
	Enums.TerrainType.RIVER_BASIN: Color(0.28, 0.58, 0.32),
	Enums.TerrainType.PLAINS: Color(0.54, 0.64, 0.40),
	Enums.TerrainType.MOUNTAINS: Color(0.52, 0.48, 0.42),
	Enums.TerrainType.DESERT: Color(0.82, 0.74, 0.50),
	Enums.TerrainType.JUNGLE: Color(0.14, 0.40, 0.20),
	Enums.TerrainType.COASTLINE: Color(0.30, 0.50, 0.66),
	Enums.TerrainType.TUNDRA: Color(0.62, 0.70, 0.78),
	Enums.TerrainType.STEPPE: Color(0.70, 0.60, 0.40),
	Enums.TerrainType.VOLCANIC_RIDGE: Color(0.42, 0.34, 0.30),
}

const NEUTRAL_BASE := Color(0.55, 0.52, 0.42)
const TERRAIN_BLEND := 0.35
const HOVER_LIGHTEN := 0.08
const SELECT_LIGHTEN := 0.12

# Selection visuals
const SELECT_OUTLINE_COLOR := Color(1.0, 0.88, 0.4, 0.85)
const SELECT_OUTLINE_WIDTH := 2.5
const SELECT_MARKER_COLOR := Color(1.0, 0.90, 0.45, 0.95)
const SELECT_MARKER_SIZE := 5.0
const MICRO_DECO_SHOW_ZOOM := 1.2
const MICRO_DECO_HIDE_ZOOM := 0.95
const DETAIL_OVERLAY_SHOW_ZOOM := 1.2
const DETAIL_OVERLAY_HIDE_ZOOM := 1.0
const DETAIL_TILE_SCALE_NEAR := 240.0
const DETAIL_TILE_SCALE_MID := 320.0
const TOWN_OVERLAY_SHOW_ZOOM := 2.0
const DETAIL_OVERLAY_ALPHA := 0.55
const TOWN_OVERLAY_ALPHA := 0.55
const TERRACE_SHOW_ZOOM := 1.8
const TERRACE_HIDE_ZOOM := 1.4

# Dim base color for heatmap overlays when textured
const HEATMAP_BASE_DIM := Color(0.7, 0.7, 0.7)

# Lighting constants (Phase 5: elevation + directional NW light)
const MAP_CENTER := Vector2(412.0, 420.0)
const MAP_HALF_DIAG := 1400.0

# Fog of war constants
const FOG_COLOR := Color(0.18, 0.16, 0.13, 1.0)  # Dark parchment fog
const EXPLORED_MODULATE := Color(0.65, 0.65, 0.70, 1.0)  # Cool desaturated tint


func initialize(data: RegionData, points: PackedVector2Array) -> void:
	region_data = data
	_local_points = points

	# Base terrain polygon (z=0)
	polygon = Polygon2D.new()
	polygon.polygon = points
	polygon.antialiased = true
	add_child(polygon)

	# Detail overlay (z=1)
	detail_overlay = Polygon2D.new()
	detail_overlay.polygon = points
	detail_overlay.z_index = 1
	detail_overlay.visible = false
	add_child(detail_overlay)

	# Political/data tint overlay (z=2)
	tint_overlay = Polygon2D.new()
	tint_overlay.polygon = points
	tint_overlay.z_index = 2
	tint_overlay.visible = false
	add_child(tint_overlay)

	# Try to apply terrain texture; cache result
	_has_texture = _apply_terrain_texture(points)

	var centroid := _calculate_centroid(points)

	# Micro decal layer (optional scatter)
	_micro_deco = Node2D.new()
	_micro_deco.z_index = 1
	_micro_deco.visible = false
	add_child(_micro_deco)

	# Terrain decoration layer - fallback when no texture (z=3)
	terrain_deco = Node2D.new()
	terrain_deco.z_index = 3
	terrain_deco.visible = not _has_texture
	add_child(terrain_deco)
	if not _has_texture:
		TerrainDecorations.build(
			region_data.terrain_type, centroid, region_data.id, terrain_deco
		)

	# Infrastructure + town markers layer (z=4)
	_infra_deco = Node2D.new()
	_infra_deco.z_index = 4
	_infra_deco.visible = false
	add_child(_infra_deco)

	# Town density overlay (z=5)
	_town_overlay = Polygon2D.new()
	_town_overlay.polygon = points
	_town_overlay.z_index = 5
	_town_overlay.visible = false
	add_child(_town_overlay)

	# Town detail layer (z=6, shown at high zoom)
	_town_detail = Node2D.new()
	_town_detail.z_index = 6
	_town_detail.visible = false
	add_child(_town_detail)

	# Terrace relief layer (z=2, above detail overlay)
	_terrace_deco = Node2D.new()
	_terrace_deco.z_index = 2
	_terrace_deco.visible = false
	add_child(_terrace_deco)

	# Area2D for mouse detection
	area = Area2D.new()
	area.input_pickable = true
	add_child(area)

	var col_shape := CollisionPolygon2D.new()
	col_shape.polygon = points
	area.add_child(col_shape)

	area.mouse_entered.connect(_on_mouse_entered)
	area.mouse_exited.connect(_on_mouse_exited)
	area.input_event.connect(_on_input_event)

	# Selection outline (gold, hidden by default)
	select_outline = Line2D.new()
	var outline_pts := PackedVector2Array(points)
	outline_pts.append(points[0])
	select_outline.points = outline_pts
	select_outline.width = SELECT_OUTLINE_WIDTH
	select_outline.default_color = SELECT_OUTLINE_COLOR
	select_outline.antialiased = true
	select_outline.visible = false
	select_outline.z_index = 8
	add_child(select_outline)

	# Selection pin marker (small diamond at centroid)
	select_marker = Polygon2D.new()
	select_marker.polygon = PackedVector2Array([
		centroid + Vector2(0, -SELECT_MARKER_SIZE),
		centroid + Vector2(SELECT_MARKER_SIZE, 0),
		centroid + Vector2(0, SELECT_MARKER_SIZE),
		centroid + Vector2(-SELECT_MARKER_SIZE, 0),
	])
	select_marker.color = SELECT_MARKER_COLOR
	select_marker.visible = false
	select_marker.z_index = 9
	add_child(select_marker)

	# Region name label
	label = Label.new()
	label.text = data.region_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UITheme.get_body_bold_font())
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.z_index = 10
	label.position = centroid - Vector2(55, 8)
	label.size = Vector2(110, 16)
	add_child(label)

	EventBus.region_owner_changed.connect(_on_region_owner_changed)
	EventBus.battle_resolved.connect(_on_battle_resolved)
	EventBus.region_deselected.connect(_on_deselected)
	EventBus.zoom_changed.connect(_on_zoom_changed)
	EventBus.golden_age_started.connect(_on_golden_age_started)
	EventBus.golden_age_ended.connect(_on_golden_age_ended)

	update_appearance()


# --- Terrain Textures ---

func _apply_terrain_texture(points: PackedVector2Array) -> bool:
	## Apply a tiling terrain texture to this region's polygon.
	## Returns true if a texture was applied, false to fall back to procedural.
	## Uses era-specific textures from TerrainTextureGenerator.
	var terrain_int: int = region_data.terrain_type
	var tex_path: String = Constants.TERRAIN_TEXTURE_PATHS.get(terrain_int, "")

	var tex: Texture2D
	if not tex_path.is_empty():
		tex = load(tex_path)
	else:
		tex = TerrainTextureGenerator.get_texture_for_era(terrain_int, _current_era)

	if not tex:
		return false

	polygon.texture = tex
	polygon.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	polygon.color = Color.WHITE
	polygon.uv = _compute_world_space_uv(points, tex.get_size())
	return true


func _compute_world_space_uv(
	points: PackedVector2Array, tex_size: Vector2,
) -> PackedVector2Array:
	## Compute world-space UVs with per-region rotation and offset.
	## Converts local polygon points to global, applies rotation, then tiles.
	var rng := RandomNumberGenerator.new()
	rng.seed = region_data.id * 5381

	# Random UV offset to break wallpaper repetition
	var uv_offset := Vector2(
		rng.randf_range(0.0, tex_size.x),
		rng.randf_range(0.0, tex_size.y),
	)

	# Random 90-degree rotation
	var rotation_idx: int = rng.randi_range(0, 3)
	var angle: float = Constants.UV_ROTATIONS[rotation_idx]
	var cos_a := cos(angle)
	var sin_a := sin(angle)

	# Per-terrain tile scale override, falling back to global default
	var override_scale: float = Constants.TERRAIN_TILE_SCALE_OVERRIDE.get(
		region_data.terrain_type, 0.0
	)
	var tile_scale: float = override_scale if override_scale > 0.0 else Constants.TERRAIN_TILE_SCALE

	var uv := PackedVector2Array()
	for local_p in points:
		# Convert to global coordinates
		var global_p: Vector2 = position + local_p

		# Apply rotation around origin
		var rotated_p := Vector2(
			global_p.x * cos_a - global_p.y * sin_a,
			global_p.x * sin_a + global_p.y * cos_a,
		)

		# Scale to UV space and add offset
		uv.append(Vector2(
			(rotated_p.x + uv_offset.x) / tile_scale,
			(rotated_p.y + uv_offset.y) / tile_scale,
		))
	return uv


# --- Appearance ---

func _get_era_params() -> Dictionary:
	return Constants.ERA_VISUAL_PARAMS.get(_current_era, Constants.ERA_VISUAL_PARAMS[2])


func update_appearance() -> void:
	if not polygon or not region_data:
		return

	# Track player civ era for visual style
	var player_civ := GameState.get_player_civ()
	if player_civ:
		_current_era = player_civ.current_era

	_current_visibility = GameState.get_player_visibility(region_data.id)

	# Reset self_modulate before rendering (prevents desaturation compounding)
	self_modulate = Color.WHITE

	if _current_visibility == Enums.VisibilityState.HIDDEN:
		_render_hidden()
		return

	# Restore terrain texture if previously hidden (fog texture or null from _render_hidden)
	if _has_texture:
		var needs_restore: bool = polygon.texture == null or polygon.texture == TerrainTextureGenerator.get_fog_texture(_current_era)
		if needs_restore:
			_apply_terrain_texture(_local_points)

	match GameState.current_overlay:
		Enums.MapOverlay.POLITICAL:
			_render_political()
		Enums.MapOverlay.TERRAIN:
			_render_terrain()
		Enums.MapOverlay.RESOURCES:
			if _current_visibility == Enums.VisibilityState.EXPLORED:
				_render_hidden()
				return
			_render_resources()
		Enums.MapOverlay.SUPPLY_LINES:
			if _current_visibility == Enums.VisibilityState.EXPLORED:
				_render_hidden()
				return
			_render_supply()
		Enums.MapOverlay.ALLIANCES:
			if _current_visibility == Enums.VisibilityState.EXPLORED:
				_render_hidden()
				return
			_render_fronts()
		_:
			_render_political()

	# Apply elevation + directional lighting (political/terrain overlays only)
	if GameState.current_overlay == Enums.MapOverlay.POLITICAL or GameState.current_overlay == Enums.MapOverlay.TERRAIN:
		_apply_lighting()
		_apply_color_grading()

	# Apply explored desaturation via self_modulate (era-specific, no compounding)
	if _current_visibility == Enums.VisibilityState.EXPLORED:
		self_modulate = _get_era_params()["explored_modulate"]

	# Dev tier warm tint for civilized regions
	if _current_visibility == Enums.VisibilityState.VISIBLE:
		_apply_dev_tier_tint()

	_apply_interaction_feedback()

	if select_outline:
		select_outline.visible = is_selected
		if is_selected and not _select_pulse_tween:
			_start_select_pulse()
		elif not is_selected and _select_pulse_tween:
			_stop_select_pulse()
	if select_marker:
		select_marker.visible = is_selected

	# Golden age glow management
	var should_glow := _check_golden_age()
	if should_glow and not _in_golden_age:
		_start_golden_glow()
	elif not should_glow and _in_golden_age:
		_stop_golden_glow()

	# Terrain decorations: visible in political/terrain when no texture and not hidden
	if terrain_deco:
		var overlay_shows_deco := (
			GameState.current_overlay == Enums.MapOverlay.POLITICAL
			or GameState.current_overlay == Enums.MapOverlay.TERRAIN
		)
		terrain_deco.visible = overlay_shows_deco and not _has_texture

	# Infrastructure + town indicators (visible in political/terrain overlays)
	if _infra_deco:
		var overlay_shows_infra := (
			GameState.current_overlay == Enums.MapOverlay.POLITICAL
			or GameState.current_overlay == Enums.MapOverlay.TERRAIN
		)
		if overlay_shows_infra:
			_update_infra_indicators()
		else:
			_infra_deco.visible = false

	_update_label_style()
	_update_micro_deco_visibility()
	_update_detail_overlay_visibility()
	_update_town_overlay_visibility()


func _apply_interaction_feedback() -> void:
	## Apply hover/selection visual feedback.
	## Textured mode: lighten tint_overlay. Fallback mode: lighten polygon.color.
	if not is_selected and not is_hovered:
		return

	var delta := SELECT_LIGHTEN if is_selected else HOVER_LIGHTEN

	if _has_texture and tint_overlay.visible:
		tint_overlay.color = tint_overlay.color.lightened(delta)
	else:
		polygon.color = polygon.color.lightened(delta)


# --- Fog of War ---

func _render_hidden() -> void:
	## Render region with noise-based fog texture.
	## Uses world-space UVs (no per-region offset) so fog tiles seamlessly.
	var fog_tex := TerrainTextureGenerator.get_fog_texture(_current_era)
	if fog_tex:
		polygon.texture = fog_tex
		polygon.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		polygon.color = Color.WHITE
		polygon.uv = _compute_fog_uv(_local_points, fog_tex.get_size())
	else:
		# Fallback: flat fog color
		var era_params := _get_era_params()
		polygon.texture = null
		polygon.color = era_params["fog_color"]

	tint_overlay.visible = false
	if terrain_deco:
		terrain_deco.visible = false
	if _micro_deco:
		_micro_deco.visible = false
	if _terrace_deco:
		_terrace_deco.visible = false
		_terrace_visible = false
	if detail_overlay:
		detail_overlay.visible = false
		_detail_overlay_visible = false
	if _town_overlay:
		_town_overlay.visible = false
		_town_overlay_visible = false
	if label:
		label.visible = false
	if select_outline:
		select_outline.visible = false
	if select_marker:
		select_marker.visible = false


const FOG_TILE_SCALE := 600.0  # Larger than terrain for slow variation

func _compute_fog_uv(points: PackedVector2Array, tex_size: Vector2) -> PackedVector2Array:
	## World-space UVs with NO per-region offset/rotation so fog is seamless.
	var uv := PackedVector2Array()
	for p in points:
		var gp: Vector2 = position + p
		uv.append(Vector2(gp.x / FOG_TILE_SCALE, gp.y / FOG_TILE_SCALE))
	return uv


# --- Overlay Renderers ---

func _render_political() -> void:
	var terrain_tint: Color = TERRAIN_TINTS.get(
		region_data.terrain_type, Color(0.45, 0.45, 0.40)
	)
	var variation := _region_color_variation()

	# Check if this is a border region (adjacent to a different civ)
	var is_border := _is_border_region()

	if _has_texture:
		polygon.color = Color.WHITE
		# Per-terrain tint alpha override, falling back to era-aware default
		var alpha_override: float = Constants.TERRAIN_TINT_ALPHA_OVERRIDE.get(
			region_data.terrain_type, 0.0
		)
		var era_tint_alpha: float = _get_era_params()["tint_alpha"]
		var tint_alpha: float = alpha_override if alpha_override > 0.0 else era_tint_alpha
		if is_border:
			tint_alpha += 0.05
		if region_data.owner_id >= 0:
			var civ: CivilizationData = GameState.get_civilization(region_data.owner_id)
			if civ:
				var saturated := _boost_saturation(civ.color, 0.20)
				var tint_color := Color(saturated.r, saturated.g, saturated.b, tint_alpha)
				tint_overlay.color = tint_color.lightened(variation)
				tint_overlay.visible = true
				return
		# Neutral textured: no tint overlay — let terrain texture show clean
		tint_overlay.visible = false
	else:
		tint_overlay.visible = false
		if region_data.owner_id >= 0:
			var civ: CivilizationData = GameState.get_civilization(region_data.owner_id)
			if civ:
				var saturated := _boost_saturation(civ.color, 0.20)
				var base_color := saturated.lerp(terrain_tint, TERRAIN_BLEND)
				polygon.color = base_color.lightened(variation)
				return
		polygon.color = NEUTRAL_BASE.lerp(terrain_tint, 0.45).lightened(variation)


func _render_terrain() -> void:
	if _has_texture:
		polygon.color = Color.WHITE
		tint_overlay.visible = false
	else:
		tint_overlay.visible = false
		polygon.color = TERRAIN_COLORS.get(
			region_data.terrain_type, Color(0.45, 0.45, 0.40)
		)


func _update_infra_indicators() -> void:
	## Draw infrastructure roads and town markers for owned regions.
	for child in _infra_deco.get_children():
		child.queue_free()

	if _current_visibility == Enums.VisibilityState.HIDDEN:
		_infra_deco.visible = false
		return

	var infra := region_data.infrastructure_level
	var has_towns := not region_data.towns.is_empty()

	if infra <= 0 and not has_towns:
		_infra_deco.visible = false
		return

	_infra_deco.visible = true
	var centroid := _calculate_centroid(_local_points)

	# Infrastructure road lines from centroid toward border edges
	if infra > 0:
		var era_params := _get_era_params()
		var road_color: Color
		match _current_era:
			0: road_color = Color(0.45, 0.35, 0.22, 0.35)  # warm brown
			1: road_color = Color(0.50, 0.42, 0.30, 0.40)  # tan
			3: road_color = Color(0.45, 0.55, 0.70, 0.45)  # blue-white
			_: road_color = Color(0.40, 0.38, 0.35, 0.40)  # grey

		var road_width: float = 1.0 + 0.3 * infra
		if infra >= 5:
			road_color.a = minf(road_color.a + 0.15, 0.65)

		# Draw 2-3 road stubs from centroid toward polygon edges
		var rng := RandomNumberGenerator.new()
		rng.seed = region_data.id * 4217
		var stub_count := mini(2 + infra / 3, 3)
		for i in stub_count:
			var edge_idx := rng.randi_range(0, _local_points.size() - 1)
			var edge_pt := _local_points[edge_idx]
			var direction := (edge_pt - centroid).normalized()
			var length := centroid.distance_to(edge_pt) * 0.7

			var road := Line2D.new()
			road.points = PackedVector2Array([centroid, centroid + direction * length])
			road.width = road_width
			road.default_color = road_color
			road.antialiased = true
			_infra_deco.add_child(road)

	# Capital marker: gold diamond outline at capital region
	if region_data.owner_id >= 0:
		var civ: CivilizationData = GameState.get_civilization(region_data.owner_id)
		if civ and civ.capital_region_id == region_data.id:
			var cap_size := 7.0
			var cap_outline := Line2D.new()
			cap_outline.points = PackedVector2Array([
				centroid + Vector2(0, -cap_size),
				centroid + Vector2(cap_size, 0),
				centroid + Vector2(0, cap_size),
				centroid + Vector2(-cap_size, 0),
				centroid + Vector2(0, -cap_size),
			])
			cap_outline.width = 2.0
			cap_outline.default_color = Color(0.95, 0.85, 0.35, 0.85)
			cap_outline.antialiased = true
			_infra_deco.add_child(cap_outline)

	# Town markers: small filled squares at offset from centroid
	if has_towns:
		var town_color: Color
		var player_civ := GameState.get_player_civ()
		if player_civ and region_data.owner_id == player_civ.id:
			town_color = Color(0.85, 0.72, 0.35, 0.70)  # golden
		else:
			town_color = Color(0.55, 0.50, 0.45, 0.55)  # neutral
		var rng := RandomNumberGenerator.new()
		rng.seed = region_data.id * 6131
		for i in region_data.towns.size():
			var offset := Vector2(
				rng.randf_range(-12, 12), rng.randf_range(-10, 10)
			)
			var pos := centroid + offset
			var half := 3.0
			var marker := Polygon2D.new()
			marker.polygon = PackedVector2Array([
				pos + Vector2(-half, -half), pos + Vector2(half, -half),
				pos + Vector2(half, half), pos + Vector2(-half, half),
			])
			marker.color = town_color
			_infra_deco.add_child(marker)

			# Building count dots: 1 dot per 2 buildings above town marker
			var town: TownData = region_data.towns[i]
			var bldg_count := 0
			for entry in town.buildings:
				bldg_count += entry.get("count", 0)
			var dot_count := bldg_count / 2
			for d in dot_count:
				var dot_pos := pos + Vector2(-3 + d * 3, -half - 3)
				var dot := Polygon2D.new()
				var dot_pts := PackedVector2Array()
				for j in 6:
					var angle := float(j) * TAU / 6.0
					dot_pts.append(dot_pos + Vector2(cos(angle), sin(angle)) * 1.2)
				dot.polygon = dot_pts
				dot.color = town_color
				_infra_deco.add_child(dot)


func _apply_dev_tier_tint() -> void:
	## Apply subtle warm tint for high-development regions.
	var dev := region_data.development_tier
	if dev >= 3:
		var gold := Color(1.0, 0.92, 0.70)
		var blend := 0.05 if dev < 5 else 0.08
		polygon.color = polygon.color.lerp(gold, blend)

	# Coastline regions get a subtle blue tint for water/sand gradient feel
	if region_data.terrain_type == Enums.TerrainType.COASTLINE:
		var shore_blue := Color(0.30, 0.48, 0.58)
		polygon.color = polygon.color.lerp(shore_blue, 0.08)


func _render_resources() -> void:
	var res_color := _compute_resource_overlay_color()
	if _has_texture:
		polygon.color = HEATMAP_BASE_DIM
		tint_overlay.color = Color(res_color.r, res_color.g, res_color.b, Constants.TINT_ALPHA_HEATMAP)
		tint_overlay.visible = true
	else:
		tint_overlay.visible = false
		polygon.color = res_color


func _compute_resource_overlay_color() -> Color:
	## Compute resource overlay color based on terrain yields + deposits.
	## Richness = number of distinct resource types. Hue shifts by dominant era.
	## Regions with active deposits are brighter/more saturated.
	var terrain_key: int = region_data.terrain_type
	var terrain_yields: Dictionary = Constants.RESOURCE_TERRAIN_YIELDS.get(terrain_key, {})
	var richness: int = terrain_yields.size()

	# Count active deposits
	var active_deposits: int = 0
	for res_type in region_data.resource_deposits:
		if region_data.resource_deposits[res_type] > 0:
			active_deposits += 1

	if richness == 0 and active_deposits == 0:
		return Color(0.22, 0.20, 0.18, 0.6)

	# Base hue by dominant resource era
	# Classical (era 1): warm gold, Industrial (era 2): copper/orange, Future (era 3): teal/blue
	var era_sum := 0
	var era_count := 0
	for res_type in terrain_yields:
		var unlock_era: int = Constants.RESOURCE_ERA_UNLOCK.get(res_type, 1)
		era_sum += unlock_era
		era_count += 1
	for res_type in region_data.resource_deposits:
		if region_data.resource_deposits[res_type] > 0:
			var unlock_era: int = Constants.RESOURCE_ERA_UNLOCK.get(res_type, 1)
			era_sum += unlock_era
			era_count += 1

	var avg_era: float = float(era_sum) / float(maxi(era_count, 1))

	# Color interpolation: Classical=gold, Industrial=copper, Future=teal
	var base_color: Color
	if avg_era < 1.5:
		base_color = Color(0.72, 0.62, 0.22)  # gold
	elif avg_era < 2.5:
		base_color = Color(0.72, 0.48, 0.22)  # copper
	else:
		base_color = Color(0.28, 0.58, 0.68)  # teal

	# Brighten by richness (1-5 types -> 0.6 to 1.0 brightness)
	var brightness := lerpf(0.6, 1.0, clampf(float(richness) / 5.0, 0.0, 1.0))
	base_color = base_color * brightness

	# Active deposits add extra saturation/brightness
	if active_deposits > 0:
		base_color = base_color.lightened(0.12 * minf(float(active_deposits), 3.0))

	return base_color


func _render_supply() -> void:
	if region_data.owner_id < 0:
		polygon.color = Color(0.25, 0.25, 0.22, 0.5)
		tint_overlay.visible = false
		return
	var civ: CivilizationData = GameState.get_civilization(region_data.owner_id)
	if not civ:
		polygon.color = Color(0.25, 0.25, 0.22, 0.5)
		tint_overlay.visible = false
		return

	# Gradient: green (>0.6) -> yellow (0.3-0.6) -> red (<0.2)
	var supply := region_data.supply_value
	var supply_color: Color
	if supply > 0.6:
		supply_color = Color(0.2, 0.65, 0.2)
	elif supply > 0.3:
		var t := (supply - 0.3) / 0.3
		supply_color = Color(0.75, 0.65, 0.1).lerp(Color(0.2, 0.65, 0.2), t)
	else:
		var t := supply / 0.3
		supply_color = Color(0.75, 0.2, 0.15).lerp(Color(0.75, 0.65, 0.1), t)

	if _has_texture:
		polygon.color = HEATMAP_BASE_DIM
		tint_overlay.color = Color(
			supply_color.r, supply_color.g, supply_color.b,
			Constants.TINT_ALPHA_HEATMAP
		)
		tint_overlay.visible = true
	else:
		tint_overlay.visible = false
		polygon.color = civ.color.lerp(supply_color, 0.45)


func _render_fronts() -> void:
	if region_data.owner_id < 0:
		polygon.color = Color(0.22, 0.22, 0.20, 0.5)
		tint_overlay.visible = false
		return
	var civ: CivilizationData = GameState.get_civilization(region_data.owner_id)
	if not civ:
		polygon.color = Color(0.22, 0.22, 0.20, 0.5)
		tint_overlay.visible = false
		return

	var is_front := false
	for adj_id in region_data.adjacency_list:
		var adj: RegionData = GameState.get_region(adj_id)
		if adj and adj.owner_id >= 0 and adj.owner_id != region_data.owner_id:
			if adj.owner_id in civ.war_targets:
				is_front = true
				break

	var front_color: Color
	if is_front:
		front_color = Color(0.85, 0.15, 0.1)
	else:
		front_color = civ.color.darkened(0.3)

	if _has_texture:
		polygon.color = HEATMAP_BASE_DIM
		tint_overlay.color = Color(
			front_color.r, front_color.g, front_color.b,
			Constants.TINT_ALPHA_HEATMAP
		)
		tint_overlay.visible = true
	else:
		tint_overlay.visible = false
		polygon.color = front_color


# --- Elevation & Directional Lighting (Phase 5) ---

func _compute_lighting_mod() -> float:
	## Brightness modifier from terrain elevation + simulated NW light source.
	## Returns a value in [-0.08, +0.06] that darkens or lightens the region.
	var mod := 0.0

	# Elevation component: high terrain slightly darkens, low terrain brightens
	var elevation: int = region_data.elevation
	match elevation:
		3: mod -= 0.035  # high mountains/volcanic
		2: mod -= 0.018  # mid elevation
		1: mod -= 0.005  # low elevation
		0: mod += 0.03   # lowlands

	# NW directional light: top-left regions slightly brighter
	var global_pos: Vector2 = position + _calculate_centroid(_local_points)
	var offset := global_pos - MAP_CENTER
	var nx := clampf(offset.x / MAP_HALF_DIAG, -1.0, 1.0)
	var ny := clampf(offset.y / MAP_HALF_DIAG, -1.0, 1.0)
	var light_factor := (-nx - ny) * 0.5
	mod += light_factor * 0.025

	return clampf(mod, -0.06, 0.06)


func _apply_lighting() -> void:
	## Post-process polygon color with elevation + directional light mod.
	var mod := _compute_lighting_mod()
	if absf(mod) < 0.001:
		return
	if mod > 0:
		polygon.color = polygon.color.lightened(mod)
	else:
		polygon.color = polygon.color.darkened(-mod)


func _apply_color_grading() -> void:
	## Shift land regions slightly toward warm tones for cohesive atmosphere.
	## 3.5% lerp toward a warm golden tint. Skips coastline (water-adjacent).
	if region_data.terrain_type == Enums.TerrainType.COASTLINE:
		return
	var warm := Color(1.0, 0.92, 0.78)
	polygon.color = polygon.color.lerp(warm, 0.035)


# --- Helpers ---

func _region_color_variation() -> float:
	## Subtle brightness variation per region based on ID hash.
	var hash_val := (region_data.id * 2654435761) % 1000
	return (float(hash_val) / 1000.0 - 0.5) * Constants.VARIATION_BRIGHTNESS_RANGE * 2.0


func _is_border_region() -> bool:
	## True if this owned region is adjacent to a region owned by a different civ.
	if region_data.owner_id < 0:
		return false
	for adj_id in region_data.adjacency_list:
		var adj: RegionData = GameState.get_region(adj_id)
		if adj and adj.owner_id >= 0 and adj.owner_id != region_data.owner_id:
			return true
	return false


func _boost_saturation(col: Color, amount: float) -> Color:
	## Increase color saturation by amount (0-1) for more vivid political overlay.
	var h := col.h
	var s := minf(col.s + amount, 1.0)
	var v := col.v
	return Color.from_hsv(h, s, v)


# --- Label Management ---

func _update_label_style() -> void:
	if not label:
		return
	if _current_visibility == Enums.VisibilityState.HIDDEN:
		label.visible = false
		return

	var should_show: bool = is_selected or current_zoom > 0.6
	if should_show and not label.visible:
		label.visible = true
		label.modulate.a = 0.0
		if _label_tween:
			_label_tween.kill()
		_label_tween = create_tween()
		_label_tween.tween_property(label, "modulate:a", 1.0, 0.2)
	elif not should_show and label.visible:
		if _label_tween:
			_label_tween.kill()
		_label_tween = create_tween()
		_label_tween.tween_property(label, "modulate:a", 0.0, 0.15)
		_label_tween.tween_callback(func() -> void: label.visible = false)

	var era_params := _get_era_params()
	var era_font_size: int = era_params["label_font_size"]
	var era_label_alpha: float = era_params["label_alpha"]

	if is_selected:
		label.add_theme_font_override("font", UITheme.get_header_font())
		label.add_theme_font_size_override("font_size", era_font_size + 2)
		label.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT)
	else:
		label.add_theme_font_override("font", UITheme.get_body_bold_font())
		label.add_theme_font_size_override("font_size", era_font_size)
		var label_color := Color(0.92, 0.88, 0.78, era_label_alpha)
		label.add_theme_color_override("font_color", label_color)


# --- Golden Age Glow (B-1) ---

func _check_golden_age() -> bool:
	if not region_data or region_data.owner_id < 0:
		return false
	var civ := GameState.get_civilization(region_data.owner_id)
	return civ != null and civ.is_in_golden_age()


func _on_golden_age_started(civ_id: int) -> void:
	if region_data and region_data.owner_id == civ_id:
		_start_golden_glow()


func _on_golden_age_ended(civ_id: int) -> void:
	if region_data and region_data.owner_id == civ_id:
		_stop_golden_glow()


func _start_golden_glow() -> void:
	_in_golden_age = true
	_pulse_golden_glow()


func _pulse_golden_glow() -> void:
	if not _in_golden_age:
		return
	if _golden_age_tween:
		_golden_age_tween.kill()
	_golden_age_tween = create_tween()
	_golden_age_tween.tween_property(self, "modulate", Color(1.12, 1.08, 0.85), 1.2).set_ease(Tween.EASE_IN_OUT)
	_golden_age_tween.tween_property(self, "modulate", Color.WHITE, 1.2).set_ease(Tween.EASE_IN_OUT)
	_golden_age_tween.tween_callback(_pulse_golden_glow)


func _stop_golden_glow() -> void:
	_in_golden_age = false
	if _golden_age_tween:
		_golden_age_tween.kill()
		_golden_age_tween = null
	modulate = Color.WHITE


# --- Selection Pulse (B-2) ---

func _start_select_pulse() -> void:
	_pulse_select()


func _pulse_select() -> void:
	if not is_selected or not select_outline:
		return
	if _select_pulse_tween:
		_select_pulse_tween.kill()
	_select_pulse_tween = create_tween()
	_select_pulse_tween.tween_property(select_outline, "width", SELECT_OUTLINE_WIDTH + 1.5, 0.8).set_ease(Tween.EASE_IN_OUT)
	_select_pulse_tween.tween_property(select_outline, "width", SELECT_OUTLINE_WIDTH, 0.8).set_ease(Tween.EASE_IN_OUT)
	_select_pulse_tween.tween_callback(_pulse_select)


func _stop_select_pulse() -> void:
	if _select_pulse_tween:
		_select_pulse_tween.kill()
		_select_pulse_tween = null
	if select_outline:
		select_outline.width = SELECT_OUTLINE_WIDTH


# --- Input Handlers ---

func _on_mouse_entered() -> void:
	if _current_visibility == Enums.VisibilityState.HIDDEN:
		return
	is_hovered = true
	update_appearance()


func _on_mouse_exited() -> void:
	is_hovered = false
	update_appearance()


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_selected = true
			update_appearance()
			EventBus.region_selected.emit(region_data.id)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			EventBus.region_right_clicked.emit(region_data.id, event.global_position)


func _on_deselected() -> void:
	is_selected = false
	update_appearance()


func _on_region_owner_changed(region_id: int, old_owner: int, new_owner: int) -> void:
	if region_data and region_id == region_data.id:
		_flash_ownership_change(old_owner, new_owner)
		update_appearance()


func _on_battle_resolved(region_id: int, _attacker_id: int, _defender_id: int, winner_id: int) -> void:
	if not region_data or region_id != region_data.id:
		return
	_pending_battle_flash = true
	_show_battle_marker(winner_id == _attacker_id)


func _show_battle_marker(attacker_won: bool) -> void:
	## Display a temporary crossed-swords marker at the region centroid.
	var centroid := _calculate_centroid(_local_points)
	var marker := Node2D.new()
	marker.position = centroid
	marker.z_index = 15

	var color := Color(1.0, 0.3, 0.2) if attacker_won else Color(0.9, 0.7, 0.3)
	var arm := 12.0

	# Crossed lines forming an X
	var line_a := Line2D.new()
	line_a.points = PackedVector2Array([Vector2(-arm, -arm), Vector2(arm, arm)])
	line_a.width = 2.5
	line_a.default_color = color
	marker.add_child(line_a)

	var line_b := Line2D.new()
	line_b.points = PackedVector2Array([Vector2(arm, -arm), Vector2(-arm, arm)])
	line_b.width = 2.5
	line_b.default_color = color
	marker.add_child(line_b)

	# Small diamond at center
	var diamond := Polygon2D.new()
	diamond.polygon = PackedVector2Array([
		Vector2(0, -4), Vector2(4, 0), Vector2(0, 4), Vector2(-4, 0),
	])
	diamond.color = color
	marker.add_child(diamond)

	add_child(marker)

	# Animate: pop in, hold, fade out, remove
	marker.scale = Vector2(0.5, 0.5)
	var tween := create_tween()
	tween.tween_property(marker, "scale", Vector2(1.2, 1.2), 0.15).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.5)
	tween.tween_property(marker, "modulate:a", 0.0, 0.35)
	tween.tween_callback(marker.queue_free)


func _flash_ownership_change(old_owner: int, new_owner: int) -> void:
	## Brief color flash when region changes hands.
	var flash_color: Color
	var duration: float
	if old_owner < 0 and new_owner >= 0:
		# Expansion into neutral territory - green flash
		flash_color = Color(0.5, 1.3, 0.5)
		duration = 0.3
	elif old_owner >= 0 and new_owner < 0:
		# Collapse to neutral - dark fade
		flash_color = Color(0.4, 0.3, 0.3)
		duration = 0.5
	elif _pending_battle_flash:
		# Battle conquest - double-pulse red flash
		_pending_battle_flash = false
		modulate = Color(1.3, 0.3, 0.3)
		var tween := create_tween()
		tween.tween_property(self, "modulate", Color(0.6, 0.4, 0.4), 0.15)
		tween.tween_property(self, "modulate", Color(1.3, 0.3, 0.3), 0.15)
		tween.tween_property(self, "modulate", Color.WHITE, 0.3).set_ease(Tween.EASE_OUT)
		return
	else:
		# Conquest (non-battle) - red flash
		flash_color = Color(1.3, 0.4, 0.4)
		duration = 0.5
	modulate = flash_color
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, duration).set_ease(Tween.EASE_OUT)


func _on_zoom_changed(zoom_level: float) -> void:
	current_zoom = zoom_level
	_update_label_style()
	_update_town_detail_visibility()
	_update_micro_deco_visibility()
	_update_detail_overlay_visibility()
	_update_town_overlay_visibility()
	_update_terrace_visibility()


func _update_town_detail_visibility() -> void:
	## Show/hide town detail layer with hysteresis (show > 2.5, hide < 2.0).
	if not _town_detail:
		return
	if _current_visibility != Enums.VisibilityState.VISIBLE:
		if _town_detail_visible:
			_town_detail.visible = false
			_town_detail_visible = false
		return

	if current_zoom > 2.5 and not _town_detail_visible:
		_town_detail_visible = true
		_build_town_detail()
		_town_detail.visible = true
	elif current_zoom < 2.0 and _town_detail_visible:
		_town_detail_visible = false
		_town_detail.visible = false
		for child in _town_detail.get_children():
			child.queue_free()


func _update_micro_deco_visibility() -> void:
	if not _micro_deco or _current_visibility == Enums.VisibilityState.HIDDEN:
		if _micro_deco_visible:
			_micro_deco.visible = false
			_micro_deco_visible = false
		return
	var overlay_shows_deco := (
		GameState.current_overlay == Enums.MapOverlay.POLITICAL
		or GameState.current_overlay == Enums.MapOverlay.TERRAIN
	)
	if not overlay_shows_deco:
		if _micro_deco_visible:
			_micro_deco.visible = false
			_micro_deco_visible = false
		return

	if current_zoom > MICRO_DECO_SHOW_ZOOM and not _micro_deco_visible:
		_micro_deco_visible = true
		_build_micro_deco()
		_micro_deco.visible = true
	elif current_zoom < MICRO_DECO_HIDE_ZOOM and _micro_deco_visible:
		_micro_deco_visible = false
		_micro_deco.visible = false
		for child in _micro_deco.get_children():
			child.queue_free()


func _update_terrace_visibility() -> void:
	if not _terrace_deco or _current_visibility == Enums.VisibilityState.HIDDEN:
		if _terrace_visible:
			_terrace_deco.visible = false
			_terrace_visible = false
		return
	if current_zoom > TERRACE_SHOW_ZOOM and not _terrace_visible:
		_terrace_visible = true
		_build_terrace_bands()
		_terrace_deco.visible = true
	elif current_zoom < TERRACE_HIDE_ZOOM and _terrace_visible:
		_terrace_visible = false
		_terrace_deco.visible = false
		for child in _terrace_deco.get_children():
			child.queue_free()


func _update_detail_overlay_visibility() -> void:
	if not detail_overlay or _current_visibility == Enums.VisibilityState.HIDDEN:
		if _detail_overlay_visible:
			detail_overlay.visible = false
			_detail_overlay_visible = false
		return

	var overlay_shows_detail := (
		GameState.current_overlay == Enums.MapOverlay.POLITICAL
		or GameState.current_overlay == Enums.MapOverlay.TERRAIN
	)
	if not overlay_shows_detail or not _has_texture:
		if _detail_overlay_visible:
			detail_overlay.visible = false
			_detail_overlay_visible = false
		return

	if current_zoom > DETAIL_OVERLAY_SHOW_ZOOM:
		_detail_overlay_visible = true
		_apply_detail_overlay()
		detail_overlay.visible = true
	elif current_zoom < DETAIL_OVERLAY_HIDE_ZOOM and _detail_overlay_visible:
		_detail_overlay_visible = false
		detail_overlay.visible = false


func _apply_detail_overlay() -> void:
	if not detail_overlay:
		return
	var tex := TerrainTextureGenerator.get_detail_texture(region_data.terrain_type, _current_era)
	if not tex:
		detail_overlay.visible = false
		_detail_overlay_visible = false
		return

	detail_overlay.texture = tex
	detail_overlay.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	detail_overlay.color = Color(1, 1, 1, DETAIL_OVERLAY_ALPHA)

	var tile_scale := DETAIL_TILE_SCALE_MID
	if current_zoom > 2.2:
		tile_scale = DETAIL_TILE_SCALE_NEAR

	detail_overlay.uv = _compute_detail_uv(_local_points, tile_scale)


func _compute_detail_uv(points: PackedVector2Array, tile_scale: float) -> PackedVector2Array:
	## World-space UVs (no per-region rotation) so detail tiles align across borders.
	var uv := PackedVector2Array()
	for p in points:
		var gp: Vector2 = position + p
		uv.append(Vector2(gp.x / tile_scale, gp.y / tile_scale))
	return uv


func _update_town_overlay_visibility() -> void:
	if not _town_overlay or _current_visibility != Enums.VisibilityState.VISIBLE:
		if _town_overlay_visible:
			_town_overlay.visible = false
			_town_overlay_visible = false
		return

	if current_zoom < TOWN_OVERLAY_SHOW_ZOOM:
		if _town_overlay_visible:
			_town_overlay.visible = false
			_town_overlay_visible = false
		return

	var has_towns := not region_data.towns.is_empty()
	if not has_towns:
		if _town_overlay_visible:
			_town_overlay.visible = false
			_town_overlay_visible = false
		return

	_town_overlay_visible = true
	_apply_town_overlay()
	_town_overlay.visible = true


func _apply_town_overlay() -> void:
	if not _town_overlay:
		return
	var density := 0
	if region_data.development_tier >= 4:
		density = 2
	elif region_data.development_tier >= 2:
		density = 1

	var tex := TerrainTextureGenerator.get_urban_texture(density)
	if not tex:
		_town_overlay.visible = false
		_town_overlay_visible = false
		return

	_town_overlay.texture = tex
	_town_overlay.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_town_overlay.color = Color(1, 1, 1, TOWN_OVERLAY_ALPHA)
	_town_overlay.uv = _compute_detail_uv(_local_points, DETAIL_TILE_SCALE_NEAR * 0.85)


func _build_micro_deco() -> void:
	for child in _micro_deco.get_children():
		child.queue_free()
	if not region_data or not _has_texture:
		return
	var centroid := _calculate_centroid(_local_points)
	TerrainDecorations.build(region_data.terrain_type, centroid, region_data.id, _micro_deco, 1.0)
	var alpha := minf(0.40 * 1.6, 0.65)
	_micro_deco.modulate = Color(1, 1, 1, alpha)
	_micro_deco.scale = Vector2(1.8, 1.8)


func _build_terrace_bands() -> void:
	for child in _terrace_deco.get_children():
		child.queue_free()

	var elev := region_data.elevation
	if elev <= 0:
		return

	var centroid := _calculate_centroid(_local_points)
	var band_count := 1 if elev == 1 else 2 if elev == 2 else 3
	var base: Color = TERRAIN_TINTS.get(region_data.terrain_type, Color(0.45, 0.45, 0.40))
	var band_col := Color(base.r * 0.6, base.g * 0.6, base.b * 0.6, 0.20 + elev * 0.05)

	for i in range(band_count):
		var scale := 1.0 - 0.10 * float(i + 1)
		var pts := PackedVector2Array()
		for p in _local_points:
			var offset := (p - centroid) * scale
			pts.append(centroid + offset)
		pts.append(pts[0])

		var band := Line2D.new()
		band.points = pts
		band.width = 2.0 + float(i)
		band.default_color = band_col
		band.antialiased = true
		_terrace_deco.add_child(band)


func _build_town_detail() -> void:
	## Render town buildings and labels at high zoom.
	for child in _town_detail.get_children():
		child.queue_free()

	if not region_data or region_data.towns.is_empty():
		return

	var centroid := _calculate_centroid(_local_points)
	var town_count := region_data.towns.size()

	for i in town_count:
		var town: TownData = region_data.towns[i]
		# Offset each town from centroid in a ring
		var angle := float(i) / float(maxi(town_count, 1)) * TAU
		var offset_dist := 20.0 if town_count > 1 else 0.0
		var town_pos := centroid + Vector2(cos(angle), sin(angle)) * offset_dist

		# Town center square
		var center := Polygon2D.new()
		var half := 4.0
		center.polygon = PackedVector2Array([
			Vector2(town_pos.x - half, town_pos.y - half),
			Vector2(town_pos.x + half, town_pos.y - half),
			Vector2(town_pos.x + half, town_pos.y + half),
			Vector2(town_pos.x - half, town_pos.y + half),
		])
		center.color = Color(0.85, 0.75, 0.45, 0.9)
		_town_detail.add_child(center)

		# Building count - small rectangles around center
		var bldg_count := town.buildings.size() if town.buildings else 0
		for b in bldg_count:
			var b_angle := float(b) / float(maxi(bldg_count, 1)) * TAU
			var b_pos := town_pos + Vector2(cos(b_angle), sin(b_angle)) * 8.0
			var bldg := Polygon2D.new()
			var bh := 2.0
			bldg.polygon = PackedVector2Array([
				Vector2(b_pos.x - bh, b_pos.y - bh),
				Vector2(b_pos.x + bh, b_pos.y - bh),
				Vector2(b_pos.x + bh, b_pos.y + bh),
				Vector2(b_pos.x - bh, b_pos.y + bh),
			])
			bldg.color = Color(0.6, 0.55, 0.4, 0.7)
			_town_detail.add_child(bldg)

		# Town name label (at zoom > 3.0)
		if current_zoom > 3.0:
			var name_lbl := Label.new()
			name_lbl.text = town.name
			UITheme.style_label_body(name_lbl, 8, Color(0.9, 0.85, 0.7, 0.85))
			name_lbl.position = town_pos + Vector2(-15, 10)
			_town_detail.add_child(name_lbl)


static func _calculate_centroid(points: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for point in points:
		sum += point
	return sum / float(points.size())
