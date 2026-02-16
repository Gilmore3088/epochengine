class_name RegionVisual
extends Node2D

## Visual representation of a single map region.
## CK2/EU4 political map style with terrain decorations, overlay modes,
## and selection feedback.

var region_data: RegionData
var polygon: Polygon2D
var collision: CollisionPolygon2D
var label: Label
var area: Area2D
var select_outline: Line2D
var select_marker: Polygon2D
var terrain_deco: Node2D

var is_hovered: bool = false
var is_selected: bool = false
var current_zoom: float = 1.0
var _local_points: PackedVector2Array

# Muted terrain tint colors (blended under political color)
const TERRAIN_TINTS := {
	Enums.TerrainType.RIVER_BASIN: Color(0.32, 0.48, 0.28),
	Enums.TerrainType.PLAINS: Color(0.52, 0.52, 0.34),
	Enums.TerrainType.MOUNTAINS: Color(0.42, 0.38, 0.32),
	Enums.TerrainType.DESERT: Color(0.62, 0.56, 0.36),
	Enums.TerrainType.JUNGLE: Color(0.22, 0.38, 0.20),
	Enums.TerrainType.COASTLINE: Color(0.35, 0.45, 0.50),
	Enums.TerrainType.TUNDRA: Color(0.52, 0.55, 0.58),
}

# Pure terrain colors (for terrain overlay)
const TERRAIN_COLORS := {
	Enums.TerrainType.RIVER_BASIN: Color(0.30, 0.55, 0.25),
	Enums.TerrainType.PLAINS: Color(0.60, 0.62, 0.38),
	Enums.TerrainType.MOUNTAINS: Color(0.50, 0.44, 0.36),
	Enums.TerrainType.DESERT: Color(0.75, 0.68, 0.42),
	Enums.TerrainType.JUNGLE: Color(0.18, 0.42, 0.18),
	Enums.TerrainType.COASTLINE: Color(0.38, 0.52, 0.58),
	Enums.TerrainType.TUNDRA: Color(0.60, 0.65, 0.68),
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

# Terrain decoration colors (subtle, semi-transparent)
const DECO_COLOR_MOUNTAIN := Color(0.25, 0.22, 0.18, 0.30)
const DECO_COLOR_RIVER := Color(0.20, 0.35, 0.50, 0.25)
const DECO_COLOR_JUNGLE := Color(0.12, 0.25, 0.10, 0.28)
const DECO_COLOR_DESERT := Color(0.50, 0.42, 0.25, 0.18)
const DECO_COLOR_COAST := Color(0.25, 0.38, 0.50, 0.22)
const DECO_COLOR_TUNDRA := Color(0.55, 0.58, 0.62, 0.20)


func initialize(data: RegionData, points: PackedVector2Array) -> void:
	region_data = data
	_local_points = points

	# Polygon2D fill
	polygon = Polygon2D.new()
	polygon.polygon = points
	polygon.antialiased = true
	add_child(polygon)

	# Terrain decoration layer
	terrain_deco = Node2D.new()
	terrain_deco.z_index = 1
	add_child(terrain_deco)
	_build_terrain_decorations(points)

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
	var centroid := _calculate_centroid(points)
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


# --- Terrain Decorations ---

func _build_terrain_decorations(points: PackedVector2Array) -> void:
	## Draw terrain-specific visual markers inside the polygon.
	var centroid := _calculate_centroid(points)
	var rng := RandomNumberGenerator.new()
	rng.seed = region_data.id * 7919  # Deterministic per region

	match region_data.terrain_type:
		Enums.TerrainType.MOUNTAINS:
			_draw_mountain_peaks(centroid, rng)
		Enums.TerrainType.RIVER_BASIN:
			_draw_river_lines(centroid, rng)
		Enums.TerrainType.JUNGLE:
			_draw_jungle_dots(centroid, rng)
		Enums.TerrainType.DESERT:
			_draw_desert_stipple(centroid, rng)
		Enums.TerrainType.COASTLINE:
			_draw_coast_waves(centroid, rng)
		Enums.TerrainType.TUNDRA:
			_draw_tundra_marks(centroid, rng)
		Enums.TerrainType.PLAINS:
			_draw_plains_grass(centroid, rng)


func _draw_mountain_peaks(centroid: Vector2, rng: RandomNumberGenerator) -> void:
	## Small triangle peaks scattered across the region.
	for i in 5:
		var offset := Vector2(
			rng.randf_range(-35, 35), rng.randf_range(-25, 25)
		)
		var base := centroid + offset
		var peak_h := rng.randf_range(6, 14)
		var peak_w := rng.randf_range(5, 9)

		var peak := Polygon2D.new()
		peak.polygon = PackedVector2Array([
			base + Vector2(0, -peak_h),
			base + Vector2(-peak_w, 0),
			base + Vector2(peak_w, 0),
		])
		peak.color = DECO_COLOR_MOUNTAIN
		terrain_deco.add_child(peak)

		# Snow cap on taller peaks
		if peak_h > 10:
			var cap := Polygon2D.new()
			var cap_h := peak_h * 0.35
			var cap_w := peak_w * 0.4
			cap.polygon = PackedVector2Array([
				base + Vector2(0, -peak_h),
				base + Vector2(-cap_w, -peak_h + cap_h),
				base + Vector2(cap_w, -peak_h + cap_h),
			])
			cap.color = Color(0.85, 0.85, 0.90, 0.25)
			terrain_deco.add_child(cap)


func _draw_river_lines(centroid: Vector2, rng: RandomNumberGenerator) -> void:
	## Wavy horizontal lines representing river/fertile land.
	for i in 3:
		var y_off := rng.randf_range(-20, 20)
		var line := Line2D.new()
		var pts := PackedVector2Array()
		for x in range(-30, 31, 8):
			var wave := sin(float(x) * 0.15 + float(i)) * 4.0
			pts.append(centroid + Vector2(x, y_off + wave))
		line.points = pts
		line.width = 1.5
		line.default_color = DECO_COLOR_RIVER
		line.antialiased = true
		terrain_deco.add_child(line)


func _draw_jungle_dots(centroid: Vector2, rng: RandomNumberGenerator) -> void:
	## Small tree-like circles scattered across the region.
	for i in 8:
		var offset := Vector2(
			rng.randf_range(-30, 30), rng.randf_range(-22, 22)
		)
		var pos := centroid + offset
		var r := rng.randf_range(2.5, 5.0)

		# Tree canopy (small filled circle approximated with polygon)
		var circle := Polygon2D.new()
		var circle_pts := PackedVector2Array()
		for j in 8:
			var angle := float(j) * TAU / 8.0
			circle_pts.append(pos + Vector2(cos(angle), sin(angle)) * r)
		circle.polygon = circle_pts
		circle.color = DECO_COLOR_JUNGLE
		terrain_deco.add_child(circle)


func _draw_desert_stipple(centroid: Vector2, rng: RandomNumberGenerator) -> void:
	## Scattered dots representing sand/arid terrain.
	for i in 12:
		var offset := Vector2(
			rng.randf_range(-32, 32), rng.randf_range(-24, 24)
		)
		var pos := centroid + offset
		var dot := Polygon2D.new()
		var dot_pts := PackedVector2Array()
		for j in 6:
			var angle := float(j) * TAU / 6.0
			dot_pts.append(pos + Vector2(cos(angle), sin(angle)) * 1.5)
		dot.polygon = dot_pts
		dot.color = DECO_COLOR_DESERT
		terrain_deco.add_child(dot)


func _draw_coast_waves(centroid: Vector2, rng: RandomNumberGenerator) -> void:
	## Small wave arcs near the region edge.
	for i in 3:
		var y_off := rng.randf_range(-18, 18)
		var x_start := rng.randf_range(-25, -5)
		var line := Line2D.new()
		var pts := PackedVector2Array()
		for x in range(0, 20, 3):
			var wave := sin(float(x) * 0.3) * 3.0
			pts.append(centroid + Vector2(x_start + x, y_off + wave))
		line.points = pts
		line.width = 1.2
		line.default_color = DECO_COLOR_COAST
		line.antialiased = true
		terrain_deco.add_child(line)


func _draw_tundra_marks(centroid: Vector2, rng: RandomNumberGenerator) -> void:
	## Small asterisk/snowflake marks.
	for i in 5:
		var offset := Vector2(
			rng.randf_range(-28, 28), rng.randf_range(-20, 20)
		)
		var pos := centroid + offset
		for j in 3:
			var angle := float(j) * PI / 3.0
			var line := Line2D.new()
			var d := Vector2(cos(angle), sin(angle)) * 3.0
			line.points = PackedVector2Array([pos - d, pos + d])
			line.width = 1.0
			line.default_color = DECO_COLOR_TUNDRA
			terrain_deco.add_child(line)


func _draw_plains_grass(centroid: Vector2, rng: RandomNumberGenerator) -> void:
	## Small grass blade marks.
	for i in 6:
		var offset := Vector2(
			rng.randf_range(-30, 30), rng.randf_range(-22, 22)
		)
		var base := centroid + offset
		var line := Line2D.new()
		var lean := rng.randf_range(-2, 2)
		line.points = PackedVector2Array([
			base,
			base + Vector2(lean, -rng.randf_range(4, 8)),
		])
		line.width = 1.0
		line.default_color = Color(0.35, 0.42, 0.25, 0.20)
		terrain_deco.add_child(line)


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

	if is_selected:
		polygon.color = polygon.color.lightened(SELECT_LIGHTEN)
	elif is_hovered:
		polygon.color = polygon.color.lightened(HOVER_LIGHTEN)

	if select_outline:
		select_outline.visible = is_selected
	if select_marker:
		select_marker.visible = is_selected

	# Show/hide terrain decorations based on overlay
	if terrain_deco:
		terrain_deco.visible = (
			GameState.current_overlay == Enums.MapOverlay.POLITICAL
			or GameState.current_overlay == Enums.MapOverlay.TERRAIN
		)

	_update_label_style()


# --- Overlay Renderers ---

func _render_political() -> void:
	var terrain_tint: Color = TERRAIN_TINTS.get(
		region_data.terrain_type, Color(0.45, 0.45, 0.40)
	)
	if region_data.owner_id >= 0:
		var civ: CivilizationData = GameState.get_civilization(region_data.owner_id)
		if civ:
			# Add subtle per-region variation so provinces don't look identical
			var variation := _region_color_variation()
			var base_color := civ.color.lerp(terrain_tint, TERRAIN_BLEND)
			polygon.color = base_color.lightened(variation)
			return
	# Neutral region - parchment base
	var variation := _region_color_variation()
	polygon.color = NEUTRAL_BASE.lerp(terrain_tint, 0.3).lightened(variation)


func _render_terrain() -> void:
	polygon.color = TERRAIN_COLORS.get(
		region_data.terrain_type, Color(0.45, 0.45, 0.40)
	)


func _render_resources() -> void:
	if not region_data.resource_stock.is_empty():
		polygon.color = Color(0.72, 0.58, 0.18)
	else:
		polygon.color = Color(0.28, 0.26, 0.22, 0.7)


func _render_supply() -> void:
	if region_data.owner_id < 0:
		polygon.color = Color(0.25, 0.25, 0.22, 0.5)
		return
	var civ: CivilizationData = GameState.get_civilization(region_data.owner_id)
	if not civ:
		polygon.color = Color(0.25, 0.25, 0.22, 0.5)
		return
	var connected: bool = region_data.is_connected_to_capital(
		GameState.regions, civ.capital_region_id
	)
	if connected:
		polygon.color = civ.color.lerp(Color(0.2, 0.65, 0.2), 0.45)
	else:
		polygon.color = civ.color.lerp(Color(0.75, 0.2, 0.15), 0.45)


func _render_fronts() -> void:
	if region_data.owner_id < 0:
		polygon.color = Color(0.22, 0.22, 0.20, 0.5)
		return
	var civ: CivilizationData = GameState.get_civilization(region_data.owner_id)
	if not civ:
		polygon.color = Color(0.22, 0.22, 0.20, 0.5)
		return
	var is_front := false
	for adj_id in region_data.adjacency_list:
		var adj: RegionData = GameState.get_region(adj_id)
		if adj and adj.owner_id >= 0 and adj.owner_id != region_data.owner_id:
			if adj.owner_id in civ.war_targets:
				is_front = true
				break
	if is_front:
		polygon.color = Color(0.85, 0.15, 0.1)
	else:
		polygon.color = civ.color.darkened(0.3)


# --- Helpers ---

func _region_color_variation() -> float:
	## Subtle brightness variation per region based on ID hash.
	## Makes provinces visually distinct even within the same civ.
	var hash_val := (region_data.id * 2654435761) % 1000
	return (float(hash_val) / 1000.0 - 0.5) * 0.06


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
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		is_selected = true
		update_appearance()
		EventBus.region_selected.emit(region_data.id)


func _on_deselected() -> void:
	is_selected = false
	update_appearance()


func _on_region_owner_changed(region_id: int, _old_owner: int, _new_owner: int) -> void:
	if region_data and region_id == region_data.id:
		update_appearance()


func _on_zoom_changed(zoom_level: float) -> void:
	current_zoom = zoom_level
	_update_label_style()


static func _calculate_centroid(points: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for point in points:
		sum += point
	return sum / float(points.size())
