extends Node2D

## Renders world map using Voronoi tessellation for irregular province shapes.
## CK2/EU4-style political map with strong borders and flat coloring.

const MAP_SEED := 42
const JITTER_AMOUNT := 30.0

# Border styling
const PROVINCE_BORDER_COLOR := Color(0.06, 0.05, 0.03, 0.45)
const PROVINCE_BORDER_WIDTH := 1.5
const CIV_BORDER_COLOR := Color(0.03, 0.02, 0.01, 0.85)
const CIV_BORDER_WIDTH := 3.5
const OCEAN_COLOR := Color(0.09, 0.12, 0.20)

var region_visuals: Dictionary = {}
var selected_region_id: int = -1
var seed_positions: Dictionary = {}
var region_polygons: Dictionary = {}
var border_container: Node2D
var _click_handled: bool = false

# Base seed positions for each region (before jitter).
# Placed across 5 geographic zones to form an organic continent.
var BASE_SEEDS: Dictionary = {
	# Northern Mountains (IDs 0-6)
	0: Vector2(130, 100), 1: Vector2(310, 80), 2: Vector2(490, 115),
	3: Vector2(670, 90), 4: Vector2(850, 108), 5: Vector2(1030, 82),
	6: Vector2(1210, 100),
	# Western Desert (IDs 7-14)
	7: Vector2(110, 275), 8: Vector2(290, 260), 9: Vector2(440, 295),
	10: Vector2(110, 435), 11: Vector2(280, 420), 12: Vector2(430, 450),
	13: Vector2(130, 585), 14: Vector2(310, 570),
	# Central River Basin (IDs 15-22)
	15: Vector2(570, 270), 16: Vector2(730, 255), 17: Vector2(570, 415),
	18: Vector2(730, 400), 19: Vector2(570, 555), 20: Vector2(730, 540),
	21: Vector2(880, 280), 22: Vector2(880, 435),
	# Eastern Coastline (IDs 23-29)
	23: Vector2(1010, 265), 24: Vector2(1170, 275), 25: Vector2(1310, 260),
	26: Vector2(1010, 425), 27: Vector2(1170, 415), 28: Vector2(1310, 435),
	29: Vector2(1090, 565),
	# Southern Plains (IDs 30-35)
	30: Vector2(310, 715), 31: Vector2(510, 700), 32: Vector2(710, 720),
	33: Vector2(910, 705), 34: Vector2(1110, 715), 35: Vector2(1290, 702),
	# Northern Tundra (IDs 36-44)
	36: Vector2(-52, -69), 37: Vector2(82, -141), 38: Vector2(-135, -256),
	39: Vector2(123, -297), 40: Vector2(-77, -489), 41: Vector2(129, -466),
	42: Vector2(299, -308), 43: Vector2(147, -638), 44: Vector2(408, -128),
	# Eastern Desert Extension (IDs 45-54)
	45: Vector2(-98, 100), 46: Vector2(-91, 248), 47: Vector2(-292, 89),
	48: Vector2(166, 341), 49: Vector2(-416, 250), 50: Vector2(10, 514),
	51: Vector2(-185, 421), 52: Vector2(-349, 403), 53: Vector2(-97, 630),
	54: Vector2(-270, 579),
	# Western Foothills (IDs 55-62)
	55: Vector2(1047, -116), 56: Vector2(1078, 160), 57: Vector2(1229, -21),
	58: Vector2(854, 541), 59: Vector2(1090, 348), 60: Vector2(1014, 678),
	61: Vector2(1212, 597), 62: Vector2(1144, 859),
	# Central River Extension (IDs 63-72)
	63: Vector2(464, 371), 64: Vector2(609, 198), 65: Vector2(443, 586),
	66: Vector2(645, 489), 67: Vector2(472, 891), 68: Vector2(613, 808),
	69: Vector2(616, 973), 70: Vector2(769, 942), 71: Vector2(807, 753),
	72: Vector2(910, 885),
	# Jungle Belt (IDs 73-82)
	73: Vector2(342, 840), 74: Vector2(172, 942), 75: Vector2(340, 1037),
	76: Vector2(21, 875), 77: Vector2(273, 1192), 78: Vector2(74, 1156),
	79: Vector2(272, 1373), 80: Vector2(122, 1351), 81: Vector2(459, 1306),
	82: Vector2(690, 1111),
	# Extended Coastline (IDs 83-92)
	83: Vector2(1529, 435), 84: Vector2(1584, 668), 85: Vector2(1706, 595),
	86: Vector2(1410, 610), 87: Vector2(1455, 818), 88: Vector2(845, 1236),
	89: Vector2(1063, 1034), 90: Vector2(918, 1138), 91: Vector2(994, 1305),
	92: Vector2(840, 1421),
	# Southern Plains (IDs 93-102)
	93: Vector2(1257, 935), 94: Vector2(1409, 1010), 95: Vector2(1141, 1148),
	96: Vector2(1276, 1109), 97: Vector2(1186, 1321), 98: Vector2(1354, 1293),
	99: Vector2(1289, 1478), 100: Vector2(1541, 1344), 101: Vector2(1467, 1476),
	102: Vector2(1505, 1130),
	# Far Eastern Oasis (IDs 103-111)
	103: Vector2(-198, 790), 104: Vector2(-375, 762), 105: Vector2(-337, 931),
	106: Vector2(-570, 908), 107: Vector2(-534, 734), 108: Vector2(-717, 730),
	109: Vector2(-635, 554), 110: Vector2(-800, 470), 111: Vector2(-881, 629),
	# Northwestern Connection (IDs 112-115)
	112: Vector2(421, -547), 113: Vector2(583, -346), 114: Vector2(658, -502),
	115: Vector2(811, -286),
}

# Virtual ocean seeds for coastline generation (not rendered).
# These push coastal cells inward, creating an organic coastline.
var OCEAN_SEEDS: Array[Vector2] = [
	# Top ocean
	Vector2(-1081, -938), Vector2(-781, -938), Vector2(-481, -938),
	Vector2(-181, -938), Vector2(119, -938), Vector2(419, -938),
	Vector2(719, -938), Vector2(1019, -938), Vector2(1319, -938),
	Vector2(1619, -938),
	# Bottom ocean
	Vector2(-1081, 1778), Vector2(-781, 1778), Vector2(-481, 1778),
	Vector2(-181, 1778), Vector2(119, 1778), Vector2(419, 1778),
	Vector2(719, 1778), Vector2(1019, 1778), Vector2(1319, 1778),
	Vector2(1619, 1778),
	# Left ocean
	Vector2(-1181, -838), Vector2(-1181, -538), Vector2(-1181, -238),
	Vector2(-1181, 62), Vector2(-1181, 362), Vector2(-1181, 662),
	Vector2(-1181, 962), Vector2(-1181, 1262), Vector2(-1181, 1562),
	# Right ocean
	Vector2(2006, -838), Vector2(2006, -538), Vector2(2006, -238),
	Vector2(2006, 62), Vector2(2006, 362), Vector2(2006, 662),
	Vector2(2006, 962), Vector2(2006, 1262), Vector2(2006, 1562),
]


func _ready() -> void:
	_build_map()
	EventBus.region_selected.connect(_on_region_selected)
	EventBus.region_deselected.connect(_on_region_deselected)
	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.region_owner_changed.connect(_on_owner_changed)
	EventBus.overlay_changed.connect(_on_overlay_changed)
	# Center camera on continent after map is built
	call_deferred("_center_camera")


func _unhandled_input(event: InputEvent) -> void:
	# Detect clicks that miss all regions (click-off to deselect).
	# Using _unhandled_input so UI button clicks don't trigger deselect.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click_handled = false
		call_deferred("_check_deselect")


func _check_deselect() -> void:
	if not _click_handled and selected_region_id >= 0:
		EventBus.region_deselected.emit()


func _build_map() -> void:
	for child in get_children():
		child.queue_free()
	region_visuals.clear()
	seed_positions.clear()
	region_polygons.clear()

	# Layered ocean with depth gradient
	_build_ocean()

	# Generate seed positions with deterministic jitter
	_init_seeds()

	# Compute Voronoi polygons
	_compute_voronoi()

	# Compute region size factors from polygon areas
	_compute_size_factors()

	# Create region visuals
	for region_id in region_polygons:
		var poly: PackedVector2Array = region_polygons[region_id]
		if poly.size() < 3:
			continue

		var region_data: RegionData = GameState.get_region(region_id)
		if not region_data:
			continue

		var centroid := _centroid(poly)

		# Translate polygon to local coordinates (relative to centroid)
		var local_poly := PackedVector2Array()
		for p in poly:
			local_poly.append(p - centroid)

		var visual := RegionVisual.new()
		visual.position = centroid
		visual.initialize(region_data, local_poly)
		add_child(visual)
		region_visuals[region_id] = visual

	# Build border lines on top of everything
	border_container = Node2D.new()
	border_container.z_index = 5
	add_child(border_container)
	_build_all_borders()


func _init_seeds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = MAP_SEED
	for region_id in BASE_SEEDS:
		var base: Vector2 = BASE_SEEDS[region_id]
		var jitter := Vector2(
			rng.randf_range(-JITTER_AMOUNT, JITTER_AMOUNT),
			rng.randf_range(-JITTER_AMOUNT, JITTER_AMOUNT),
		)
		seed_positions[region_id] = base + jitter


func _compute_voronoi() -> void:
	# Combine real region seeds with virtual ocean seeds
	var all_seeds: Dictionary = {}
	for id in seed_positions:
		all_seeds[id] = seed_positions[id]
	for i in OCEAN_SEEDS.size():
		all_seeds[-(i + 1)] = OCEAN_SEEDS[i]

	var all_ids: Array = all_seeds.keys()

	# Bounding rectangle (much larger than map to avoid edge artifacts)
	var bounds_pos := Vector2(-1381, -1138)
	var bounds_end := Vector2(2206, 1978)

	for id_a in all_ids:
		# Start each cell as the bounding rectangle
		var cell := PackedVector2Array([
			bounds_pos,
			Vector2(bounds_end.x, bounds_pos.y),
			bounds_end,
			Vector2(bounds_pos.x, bounds_end.y),
		])

		var seed_a: Vector2 = all_seeds[id_a]

		# Clip by half-plane for every other seed
		for id_b in all_ids:
			if id_a == id_b:
				continue
			if cell.size() < 3:
				break

			var seed_b: Vector2 = all_seeds[id_b]
			var mid := (seed_a + seed_b) * 0.5
			var normal := (seed_a - seed_b).normalized()
			cell = _clip_polygon(cell, mid, normal)

		# Only store cells for real regions (id >= 0)
		if id_a >= 0 and cell.size() >= 3:
			region_polygons[id_a] = cell


func _clip_polygon(
	poly: PackedVector2Array, point: Vector2, normal: Vector2,
) -> PackedVector2Array:
	## Sutherland-Hodgman half-plane clip.
	## Keeps the side where dot(p - point, normal) >= 0.
	if poly.size() < 3:
		return PackedVector2Array()

	var output := PackedVector2Array()
	var prev := poly[poly.size() - 1]
	var prev_d: float = (prev - point).dot(normal)

	for i in poly.size():
		var curr := poly[i]
		var curr_d: float = (curr - point).dot(normal)

		if curr_d >= 0.0:
			if prev_d < 0.0:
				var t: float = prev_d / (prev_d - curr_d)
				output.append(prev.lerp(curr, t))
			output.append(curr)
		elif prev_d >= 0.0:
			var t: float = prev_d / (prev_d - curr_d)
			output.append(prev.lerp(curr, t))

		prev = curr
		prev_d = curr_d

	return output


func _compute_size_factors() -> void:
	## Compute each region's size_factor from Voronoi polygon area.
	## Uses the Shoelace formula. Normalizes so 1.0 = average region.
	var areas: Dictionary = {}
	var total_area := 0.0
	var count := 0

	for region_id in region_polygons:
		var poly: PackedVector2Array = region_polygons[region_id]
		if poly.size() < 3:
			continue
		var area := _polygon_area(poly)
		areas[region_id] = area
		total_area += area
		count += 1

	if count == 0:
		return

	var avg_area := total_area / float(count)

	for region_id in areas:
		var region_data: RegionData = GameState.get_region(region_id)
		if region_data:
			region_data.size_factor = areas[region_id] / avg_area


static func _polygon_area(poly: PackedVector2Array) -> float:
	## Shoelace formula for polygon area.
	var area := 0.0
	var n := poly.size()
	for i in n:
		var j := (i + 1) % n
		area += poly[i].x * poly[j].y
		area -= poly[j].x * poly[i].y
	return absf(area) * 0.5


func _build_all_borders() -> void:
	for child in border_container.get_children():
		child.queue_free()

	# Province outlines (thin lines around every region)
	for region_id in region_polygons:
		var poly: PackedVector2Array = region_polygons[region_id]
		if poly.size() < 3:
			continue

		var line := Line2D.new()
		var pts := PackedVector2Array(poly)
		pts.append(poly[0])
		line.points = pts
		line.width = PROVINCE_BORDER_WIDTH
		line.default_color = PROVINCE_BORDER_COLOR
		line.antialiased = true
		border_container.add_child(line)

	# Thick borders between regions of different owners
	_draw_civ_borders()


func _draw_civ_borders() -> void:
	var drawn: Dictionary = {}

	for region_id in region_polygons:
		var region: RegionData = GameState.get_region(region_id)
		if not region:
			continue

		for adj_id in region.adjacency_list:
			if not region_polygons.has(adj_id):
				continue

			var pair_key: int = mini(region_id, adj_id) * 10000 + maxi(region_id, adj_id)
			if drawn.has(pair_key):
				continue
			drawn[pair_key] = true

			var adj: RegionData = GameState.get_region(adj_id)
			if not adj or region.owner_id == adj.owner_id:
				continue

			var shared := _find_shared_edge(region_id, adj_id)
			if shared.size() >= 2:
				# Glow layer (wider, semi-transparent)
				var glow := Line2D.new()
				glow.points = shared
				glow.width = CIV_BORDER_WIDTH + 3.0
				glow.default_color = Color(0.02, 0.01, 0.0, 0.35)
				glow.antialiased = true
				glow.z_index = 1
				border_container.add_child(glow)

				# Main border line
				var line := Line2D.new()
				line.points = shared
				line.width = CIV_BORDER_WIDTH
				line.default_color = CIV_BORDER_COLOR
				line.antialiased = true
				line.z_index = 2
				border_container.add_child(line)


func _find_shared_edge(id_a: int, id_b: int) -> PackedVector2Array:
	## Find the shared boundary between two adjacent Voronoi cells.
	## Shared vertices lie on the perpendicular bisector (equidistant to both seeds).
	var poly_a: PackedVector2Array = region_polygons.get(id_a, PackedVector2Array())
	var poly_b: PackedVector2Array = region_polygons.get(id_b, PackedVector2Array())
	if poly_a.size() < 3 or poly_b.size() < 3:
		return PackedVector2Array()

	var seed_a: Vector2 = seed_positions[id_a]
	var seed_b: Vector2 = seed_positions[id_b]
	var tolerance := 3.0

	var shared := PackedVector2Array()

	for v in poly_a:
		var diff: float = absf(v.distance_to(seed_a) - v.distance_to(seed_b))
		if diff < tolerance:
			shared.append(v)

	# Also check poly_b vertices for robustness (avoid duplicates)
	for v in poly_b:
		var diff: float = absf(v.distance_to(seed_a) - v.distance_to(seed_b))
		if diff < tolerance:
			var is_dup := false
			for existing in shared:
				if v.distance_to(existing) < 2.0:
					is_dup = true
					break
			if not is_dup:
				shared.append(v)

	return shared


# --- Signal Handlers ---

func _on_region_selected(region_id: int) -> void:
	_click_handled = true
	if selected_region_id >= 0 and selected_region_id != region_id:
		EventBus.region_deselected.emit()
	selected_region_id = region_id


func _on_region_deselected() -> void:
	selected_region_id = -1


func _on_turn_ended(_year: int) -> void:
	for visual in region_visuals.values():
		visual.update_appearance()
	_refresh_civ_borders()


func _on_owner_changed(_region_id: int, _old: int, _new: int) -> void:
	_refresh_civ_borders()


func _on_overlay_changed(_overlay: int) -> void:
	for visual in region_visuals.values():
		visual.update_appearance()


func _refresh_civ_borders() -> void:
	# Remove civ borders (z_index 1), keep province outlines (z_index 0)
	for child in border_container.get_children():
		if child.z_index == 1:
			child.queue_free()
	_draw_civ_borders()


static func _centroid(poly: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in poly:
		sum += p
	return sum / float(poly.size())


func _build_ocean() -> void:
	## Layered ocean with depth rings for visual richness.
	# Bounds cover the tightened map (-881..1706 x, -638..1478 y)
	var bounds := [Vector2(-1800, -1400), Vector2(2500, -1400),
		Vector2(2500, 2200), Vector2(-1800, 2200)]

	# Deep ocean base
	var ocean_deep := Polygon2D.new()
	ocean_deep.polygon = PackedVector2Array(bounds)
	ocean_deep.color = Color(0.06, 0.08, 0.16)
	ocean_deep.z_index = -10
	add_child(ocean_deep)

	# Mid ocean ring (slightly lighter near land)
	var ocean_mid := Polygon2D.new()
	ocean_mid.polygon = PackedVector2Array([
		Vector2(-1500, -1200), Vector2(2300, -1200),
		Vector2(2300, 2000), Vector2(-1500, 2000),
	])
	ocean_mid.color = Color(0.08, 0.10, 0.19)
	ocean_mid.z_index = -9
	add_child(ocean_mid)

	# Shallow ocean ring (closest to coast)
	var ocean_shallow := Polygon2D.new()
	ocean_shallow.polygon = PackedVector2Array([
		Vector2(-1300, -1000), Vector2(2100, -1000),
		Vector2(2100, 1900), Vector2(-1300, 1900),
	])
	ocean_shallow.color = OCEAN_COLOR
	ocean_shallow.z_index = -8
	add_child(ocean_shallow)

	# Subtle compass rose indicator (small cross in ocean corner)
	_build_compass_rose()


func _build_compass_rose() -> void:
	## Subtle directional indicator in the bottom-right ocean area.
	var center := Vector2(2100, 1800)
	var arm_len := 18.0
	var color := Color(0.25, 0.22, 0.18, 0.25)

	# N-S line
	var ns := Line2D.new()
	ns.points = PackedVector2Array([
		center + Vector2(0, -arm_len), center + Vector2(0, arm_len)
	])
	ns.width = 1.5
	ns.default_color = color
	ns.z_index = -5
	add_child(ns)

	# E-W line
	var ew := Line2D.new()
	ew.points = PackedVector2Array([
		center + Vector2(-arm_len, 0), center + Vector2(arm_len, 0)
	])
	ew.width = 1.5
	ew.default_color = color
	ew.z_index = -5
	add_child(ew)

	# North arrow
	var arrow := Polygon2D.new()
	arrow.polygon = PackedVector2Array([
		center + Vector2(0, -arm_len - 6),
		center + Vector2(-4, -arm_len + 2),
		center + Vector2(4, -arm_len + 2),
	])
	arrow.color = Color(0.30, 0.26, 0.20, 0.30)
	arrow.z_index = -5
	add_child(arrow)

	# "N" label
	var n_label := Label.new()
	n_label.text = "N"
	n_label.add_theme_font_override("font", UITheme.get_header_font())
	n_label.add_theme_font_size_override("font_size", 10)
	n_label.add_theme_color_override("font_color", Color(0.30, 0.26, 0.20, 0.30))
	n_label.position = center + Vector2(-4, -arm_len - 22)
	n_label.z_index = -5
	add_child(n_label)


func _center_camera() -> void:
	## Center camera on the continent after map build.
	var camera := get_viewport().get_camera_2d()
	if camera and camera.has_method("center_on_map"):
		var bounds := get_map_bounds()
		camera.center_on_map(bounds)


func get_map_bounds() -> Rect2:
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)

	for poly in region_polygons.values():
		for p in poly:
			min_pos.x = minf(min_pos.x, p.x)
			min_pos.y = minf(min_pos.y, p.y)
			max_pos.x = maxf(max_pos.x, p.x)
			max_pos.y = maxf(max_pos.y, p.y)

	var padding := 120.0
	return Rect2(
		min_pos - Vector2(padding, padding),
		(max_pos - min_pos) + Vector2(padding * 2, padding * 2),
	)
