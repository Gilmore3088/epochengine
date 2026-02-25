class_name HexCellVisual
extends Node2D

## Visual for a single hex cell: base terrain, detail overlay, optional urban overlay.

var cell: HexCellData
var base_poly: Polygon2D
var detail_poly: Polygon2D
var town_poly: Polygon2D

var _current_zoom: float = 1.0

const DETAIL_SHOW_ZOOM := 1.2
const DETAIL_HIDE_ZOOM := 1.0
const DETAIL_TILE_NEAR := 120.0
const DETAIL_TILE_MID := 180.0
const TOWN_SHOW_ZOOM := 2.0

func initialize(data: HexCellData, points: PackedVector2Array, era: int) -> void:
	cell = data

	# Base terrain
	base_poly = Polygon2D.new()
	base_poly.polygon = points
	base_poly.antialiased = true
	base_poly.texture = TerrainTextureGenerator.get_texture_for_era(cell.terrain_type, era)
	base_poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	base_poly.uv = _compute_uv(points, DETAIL_TILE_MID)
	add_child(base_poly)

	# Detail overlay (pattern fill)
	detail_poly = Polygon2D.new()
	detail_poly.polygon = points
	detail_poly.antialiased = true
	detail_poly.texture = TerrainTextureGenerator.get_detail_texture(cell.terrain_type, era)
	detail_poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	detail_poly.modulate = Color(1, 1, 1, 0.45)
	detail_poly.visible = false
	add_child(detail_poly)

	# Town density overlay
	town_poly = Polygon2D.new()
	town_poly.polygon = points
	town_poly.antialiased = true
	town_poly.visible = false
	add_child(town_poly)

	EventBus.zoom_changed.connect(_on_zoom_changed)
	_update_overlays()


func _on_zoom_changed(zoom_level: float) -> void:
	_current_zoom = zoom_level
	_update_overlays()


func _update_overlays() -> void:
	if _current_zoom >= DETAIL_SHOW_ZOOM:
		detail_poly.visible = true
		var scale := DETAIL_TILE_NEAR if _current_zoom >= 1.8 else DETAIL_TILE_MID
		detail_poly.uv = _compute_uv(base_poly.polygon, scale)
	else:
		detail_poly.visible = false

	if cell.town_level > 0 and _current_zoom >= TOWN_SHOW_ZOOM:
		var density := clampi(cell.town_level - 1, 0, 2)
		town_poly.texture = TerrainTextureGenerator.get_urban_texture(density)
		town_poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		town_poly.uv = _compute_uv(base_poly.polygon, 90.0)
		town_poly.modulate = Color(1, 1, 1, 0.55)
		town_poly.visible = true
	else:
		town_poly.visible = false


func _compute_uv(points: PackedVector2Array, scale: float) -> PackedVector2Array:
	var uv := PackedVector2Array()
	for p in points:
		var gp := global_position + p
		uv.append(Vector2(gp.x / scale, gp.y / scale))
	return uv
