class_name RegionVisual
extends Node2D

## Visual representation of a single map region.
## Renders as a Polygon2D with terrain coloring and owner blending.

var region_data: RegionData
var polygon: Polygon2D
var collision: CollisionPolygon2D
var label: Label
var area: Area2D

var is_hovered: bool = false
var is_selected: bool = false

# Terrain base colors
const TERRAIN_COLORS := {
	Enums.TerrainType.RIVER_BASIN: Color(0.35, 0.65, 0.35),
	Enums.TerrainType.PLAINS: Color(0.70, 0.72, 0.40),
	Enums.TerrainType.MOUNTAINS: Color(0.55, 0.45, 0.35),
	Enums.TerrainType.DESERT: Color(0.85, 0.78, 0.50),
	Enums.TerrainType.JUNGLE: Color(0.20, 0.50, 0.20),
	Enums.TerrainType.COASTLINE: Color(0.40, 0.60, 0.75),
	Enums.TerrainType.TUNDRA: Color(0.75, 0.80, 0.85),
}

const NEUTRAL_COLOR := Color(0.5, 0.5, 0.5, 0.3)
const HOVER_LIGHTEN := 0.15
const SELECT_LIGHTEN := 0.25
const OWNER_BLEND := 0.4
const BORDER_WIDTH := 2.0


func initialize(data: RegionData, points: PackedVector2Array) -> void:
	region_data = data

	# Polygon2D for fill
	polygon = Polygon2D.new()
	polygon.polygon = points
	add_child(polygon)

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

	# Region name label
	label = Label.new()
	label.text = data.region_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)

	# Center label on polygon centroid
	var centroid := _calculate_centroid(points)
	label.position = centroid - Vector2(40, 8)
	label.size = Vector2(80, 16)
	add_child(label)

	# Listen for ownership changes
	EventBus.region_owner_changed.connect(_on_region_owner_changed)
	EventBus.region_deselected.connect(_on_deselected)

	update_appearance()


func update_appearance() -> void:
	if not polygon or not region_data:
		return

	var base_color: Color = TERRAIN_COLORS.get(
		region_data.terrain_type, Color(0.5, 0.5, 0.5)
	)

	# Blend with owner color
	if region_data.owner_id >= 0:
		var civ := GameState.get_civilization(region_data.owner_id)
		if civ:
			base_color = base_color.lerp(civ.color, OWNER_BLEND)
	else:
		base_color = base_color.lerp(NEUTRAL_COLOR, 0.15)

	# Hover / selection effects
	if is_selected:
		base_color = base_color.lightened(SELECT_LIGHTEN)
	elif is_hovered:
		base_color = base_color.lightened(HOVER_LIGHTEN)

	polygon.color = base_color


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


static func _calculate_centroid(points: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for point in points:
		sum += point
	return sum / float(points.size())
