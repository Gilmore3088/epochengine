class_name RegionVisual
extends Node2D

## Visual representation of a single map region.
## Layered scene graph: base terrain -> political tint -> decorations -> UI.
## Supports both textured mode (seamless PNGs) and fallback mode (flat colors).

var region_data: RegionData
var polygon: Polygon2D
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

# Muted terrain tint colors (blended under political color in fallback mode)
const TERRAIN_TINTS := {
	Enums.TerrainType.RIVER_BASIN: Color(0.32, 0.48, 0.28),
	Enums.TerrainType.PLAINS: Color(0.52, 0.52, 0.34),
	Enums.TerrainType.MOUNTAINS: Color(0.42, 0.38, 0.32),
	Enums.TerrainType.DESERT: Color(0.62, 0.56, 0.36),
	Enums.TerrainType.JUNGLE: Color(0.22, 0.38, 0.20),
	Enums.TerrainType.COASTLINE: Color(0.35, 0.45, 0.50),
	Enums.TerrainType.TUNDRA: Color(0.52, 0.55, 0.58),
	Enums.TerrainType.STEPPE: Color(0.55, 0.50, 0.35),
	Enums.TerrainType.VOLCANIC_RIDGE: Color(0.38, 0.30, 0.28),
}

# Pure terrain colors (for terrain overlay in fallback mode)
const TERRAIN_COLORS := {
	Enums.TerrainType.RIVER_BASIN: Color(0.30, 0.55, 0.25),
	Enums.TerrainType.PLAINS: Color(0.60, 0.62, 0.38),
	Enums.TerrainType.MOUNTAINS: Color(0.50, 0.44, 0.36),
	Enums.TerrainType.DESERT: Color(0.75, 0.68, 0.42),
	Enums.TerrainType.JUNGLE: Color(0.18, 0.42, 0.18),
	Enums.TerrainType.COASTLINE: Color(0.38, 0.52, 0.58),
	Enums.TerrainType.TUNDRA: Color(0.60, 0.65, 0.68),
	Enums.TerrainType.STEPPE: Color(0.65, 0.60, 0.40),
	Enums.TerrainType.VOLCANIC_RIDGE: Color(0.45, 0.35, 0.30),
}

const NEUTRAL_BASE := Color(0.60, 0.56, 0.46)
const TERRAIN_BLEND := 0.18
const HOVER_LIGHTEN := 0.08
const SELECT_LIGHTEN := 0.12

# Selection visuals
const SELECT_OUTLINE_COLOR := Color(1.0, 0.88, 0.4, 0.85)
const SELECT_OUTLINE_WIDTH := 2.5
const SELECT_MARKER_COLOR := Color(1.0, 0.90, 0.45, 0.95)
const SELECT_MARKER_SIZE := 5.0

# Dim base color for heatmap overlays when textured
const HEATMAP_BASE_DIM := Color(0.7, 0.7, 0.7)


func initialize(data: RegionData, points: PackedVector2Array) -> void:
	region_data = data
	_local_points = points

	# Base terrain polygon (z=0)
	polygon = Polygon2D.new()
	polygon.polygon = points
	polygon.antialiased = true
	add_child(polygon)

	# Political/data tint overlay (z=1)
	tint_overlay = Polygon2D.new()
	tint_overlay.polygon = points
	tint_overlay.z_index = 1
	tint_overlay.visible = false
	add_child(tint_overlay)

	# Try to apply terrain texture; cache result
	_has_texture = _apply_terrain_texture(points)

	var centroid := _calculate_centroid(points)

	# Terrain decoration layer - fallback when no texture (z=2)
	terrain_deco = Node2D.new()
	terrain_deco.z_index = 2
	terrain_deco.visible = not _has_texture
	add_child(terrain_deco)
	if not _has_texture:
		TerrainDecorations.build(
			region_data.terrain_type, centroid, region_data.id, terrain_deco
		)

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
	EventBus.region_deselected.connect(_on_deselected)
	EventBus.zoom_changed.connect(_on_zoom_changed)

	update_appearance()


# --- Terrain Textures ---

func _apply_terrain_texture(points: PackedVector2Array) -> bool:
	## Apply a tiling terrain texture to this region's polygon.
	## Returns true if a texture was applied, false to fall back to procedural.
	var tex_path: String = Constants.TERRAIN_TEXTURE_PATHS.get(
		region_data.terrain_type, ""
	)
	if tex_path.is_empty():
		return false

	var tex: Texture2D = load(tex_path)
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

func update_appearance() -> void:
	if not polygon or not region_data:
		return

	match GameState.current_overlay:
		Enums.MapOverlay.POLITICAL:
			_render_political()
		Enums.MapOverlay.TERRAIN:
			_render_terrain()
		Enums.MapOverlay.RESOURCES:
			_render_resources()
		Enums.MapOverlay.SUPPLY_LINES:
			_render_supply()
		Enums.MapOverlay.ALLIANCES:
			_render_fronts()
		_:
			_render_political()

	_apply_interaction_feedback()

	if select_outline:
		select_outline.visible = is_selected
	if select_marker:
		select_marker.visible = is_selected

	# Terrain decorations: visible in political/terrain when no texture
	if terrain_deco:
		var overlay_shows_deco := (
			GameState.current_overlay == Enums.MapOverlay.POLITICAL
			or GameState.current_overlay == Enums.MapOverlay.TERRAIN
		)
		terrain_deco.visible = overlay_shows_deco and not _has_texture

	_update_label_style()


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


# --- Overlay Renderers ---

func _render_political() -> void:
	var terrain_tint: Color = TERRAIN_TINTS.get(
		region_data.terrain_type, Color(0.45, 0.45, 0.40)
	)
	var variation := _region_color_variation()

	if _has_texture:
		polygon.color = Color.WHITE
		# Per-terrain tint alpha override, falling back to global default
		var alpha_override: float = Constants.TERRAIN_TINT_ALPHA_OVERRIDE.get(
			region_data.terrain_type, 0.0
		)
		var tint_alpha: float = alpha_override if alpha_override > 0.0 else Constants.TINT_ALPHA_POLITICAL
		if region_data.owner_id >= 0:
			var civ: CivilizationData = GameState.get_civilization(region_data.owner_id)
			if civ:
				var tint_color := Color(civ.color.r, civ.color.g, civ.color.b, tint_alpha)
				tint_overlay.color = tint_color.lightened(variation)
				tint_overlay.visible = true
				return
		# Neutral: faint terrain-tinted overlay
		var neutral_tint := NEUTRAL_BASE.lerp(terrain_tint, 0.3)
		neutral_tint.a = Constants.TINT_ALPHA_NEUTRAL
		tint_overlay.color = neutral_tint.lightened(variation)
		tint_overlay.visible = true
	else:
		tint_overlay.visible = false
		if region_data.owner_id >= 0:
			var civ: CivilizationData = GameState.get_civilization(region_data.owner_id)
			if civ:
				var base_color := civ.color.lerp(terrain_tint, TERRAIN_BLEND)
				polygon.color = base_color.lightened(variation)
				return
		polygon.color = NEUTRAL_BASE.lerp(terrain_tint, 0.3).lightened(variation)


func _render_terrain() -> void:
	if _has_texture:
		polygon.color = Color.WHITE
		tint_overlay.visible = false
	else:
		tint_overlay.visible = false
		polygon.color = TERRAIN_COLORS.get(
			region_data.terrain_type, Color(0.45, 0.45, 0.40)
		)


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


# --- Helpers ---

func _region_color_variation() -> float:
	## Subtle brightness variation per region based on ID hash.
	var hash_val := (region_data.id * 2654435761) % 1000
	return (float(hash_val) / 1000.0 - 0.5) * Constants.VARIATION_BRIGHTNESS_RANGE * 2.0


# --- Label Management ---

func _update_label_style() -> void:
	if not label:
		return
	label.visible = is_selected or current_zoom > 0.6
	if is_selected:
		label.add_theme_font_override("font", UITheme.get_header_font())
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT)
	else:
		label.add_theme_font_override("font", UITheme.get_body_bold_font())
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))


# --- Input Handlers ---

func _on_mouse_entered() -> void:
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
	else:
		# Conquest - red flash
		flash_color = Color(1.3, 0.4, 0.4)
		duration = 0.5
	modulate = flash_color
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, duration).set_ease(Tween.EASE_OUT)


func _on_zoom_changed(zoom_level: float) -> void:
	current_zoom = zoom_level
	_update_label_style()


static func _calculate_centroid(points: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for point in points:
		sum += point
	return sum / float(points.size())
