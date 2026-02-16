extends Node2D

## Renders the world map by creating RegionVisual nodes for each region.
## Generates hexagonal polygon shapes positioned by map zone.

const HEX_SIZE := 60.0
const HEX_SPACING_X := HEX_SIZE * 1.8
const HEX_SPACING_Y := HEX_SIZE * 1.6
const ZONE_GAP := 40.0

var region_visuals: Dictionary = {}  # {region_id: RegionVisual}
var selected_region_id: int = -1


func _ready() -> void:
	_build_map()
	EventBus.region_selected.connect(_on_region_selected)
	EventBus.turn_ended.connect(_on_turn_ended)


func _build_map() -> void:
	for child in get_children():
		child.queue_free()
	region_visuals.clear()

	# Layout regions by zone
	var layout := _generate_layout()

	for region_id in layout:
		var region_data := GameState.get_region(region_id)
		if not region_data:
			continue

		var pos: Vector2 = layout[region_id]
		var hex_points := _generate_hex_polygon(HEX_SIZE)

		var visual := RegionVisual.new()
		visual.position = pos
		visual.initialize(region_data, hex_points)
		add_child(visual)
		region_visuals[region_id] = visual


func _generate_layout() -> Dictionary:
	## Returns {region_id: Vector2 position} for all regions.
	var layout: Dictionary = {}

	# Northern Mountains (IDs 0-6) -- top row
	var mountain_start := Vector2(200, 80)
	_place_row(layout, range(0, 7), mountain_start, HEX_SPACING_X)

	# Western Desert (IDs 7-14) -- left side, two rows
	var desert_start := Vector2(50, 80 + HEX_SPACING_Y + ZONE_GAP)
	_place_row(layout, range(7, 11), desert_start, HEX_SPACING_X)
	_place_row(layout, range(11, 15), desert_start + Vector2(HEX_SPACING_X * 0.5, HEX_SPACING_Y), HEX_SPACING_X)

	# Central River Basin (IDs 15-22) -- center, two rows
	var river_start := Vector2(300, 80 + HEX_SPACING_Y + ZONE_GAP)
	_place_row(layout, range(15, 19), river_start, HEX_SPACING_X)
	_place_row(layout, range(19, 23), river_start + Vector2(HEX_SPACING_X * 0.5, HEX_SPACING_Y), HEX_SPACING_X)

	# Eastern Coastline (IDs 23-29) -- right side, two rows
	var coast_start := Vector2(600, 80 + HEX_SPACING_Y + ZONE_GAP)
	_place_row(layout, range(23, 27), coast_start, HEX_SPACING_X)
	_place_row(layout, range(27, 30), coast_start + Vector2(HEX_SPACING_X * 0.5, HEX_SPACING_Y), HEX_SPACING_X)

	# Southern Plains (IDs 30-35) -- bottom row
	var plains_start := Vector2(200, 80 + (HEX_SPACING_Y + ZONE_GAP) * 2 + HEX_SPACING_Y)
	_place_row(layout, range(30, 36), plains_start, HEX_SPACING_X)

	return layout


func _place_row(layout: Dictionary, ids: Array, start: Vector2, spacing: float) -> void:
	for i in ids.size():
		layout[ids[i]] = start + Vector2(i * spacing, 0)


func _generate_hex_polygon(size: float) -> PackedVector2Array:
	## Generate a regular hexagon (pointy-top).
	var points := PackedVector2Array()
	for i in 6:
		var angle := deg_to_rad(60.0 * i - 30.0)
		points.append(Vector2(cos(angle) * size, sin(angle) * size))
	return points


func _on_region_selected(region_id: int) -> void:
	# Deselect previous
	if selected_region_id >= 0 and selected_region_id != region_id:
		EventBus.region_deselected.emit()

	selected_region_id = region_id


func _on_turn_ended(_year: int) -> void:
	# Refresh all region visuals after a turn
	for visual in region_visuals.values():
		visual.update_appearance()


func get_map_bounds() -> Rect2:
	## Returns the bounding rectangle of the map for camera clamping.
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)

	for visual in region_visuals.values():
		var pos: Vector2 = visual.position
		min_pos.x = minf(min_pos.x, pos.x)
		min_pos.y = minf(min_pos.y, pos.y)
		max_pos.x = maxf(max_pos.x, pos.x)
		max_pos.y = maxf(max_pos.y, pos.y)

	var padding := HEX_SIZE * 2
	return Rect2(
		min_pos - Vector2(padding, padding),
		(max_pos - min_pos) + Vector2(padding * 2, padding * 2),
	)
