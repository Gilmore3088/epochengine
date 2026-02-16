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
	36: Vector2(-52, -87), 37: Vector2(122, -220), 38: Vector2(-87, -356),
	39: Vector2(202, -436), 40: Vector2(-35, -644), 41: Vector2(199, -662),
	42: Vector2(408, -508), 43: Vector2(150, -880), 44: Vector2(418, -209),
	# Eastern Desert Extension (IDs 45-54)
	45: Vector2(-135, 231), 46: Vector2(-312, 182), 47: Vector2(-406, 360),
	48: Vector2(-146, 432), 49: Vector2(-636, 408), 50: Vector2(-146, 644),
	51: Vector2(-535, 636), 52: Vector2(-827, 551), 53: Vector2(-802, 773),
	54: Vector2(-1093, 696),
	# Western Foothills (IDs 55-62)
	55: Vector2(1311, -99), 56: Vector2(1455, 288), 57: Vector2(1598, 176),
	58: Vector2(1196, 611), 59: Vector2(1613, 543), 60: Vector2(1411, 970),
	61: Vector2(1706, 904), 62: Vector2(1613, 1190),
	# Central River Extension (IDs 63-72)
	63: Vector2(585, 795), 64: Vector2(664, 930), 65: Vector2(481, 979),
	66: Vector2(885, 814), 67: Vector2(496, 1178), 68: Vector2(732, 1065),
	69: Vector2(673, 1209), 70: Vector2(875, 1207), 71: Vector2(835, 920),
	72: Vector2(949, 1026),
	# Jungle Belt (IDs 73-82)
	73: Vector2(343, 868), 74: Vector2(162, 978), 75: Vector2(293, 1095),
	76: Vector2(4, 904), 77: Vector2(262, 1279), 78: Vector2(45, 1256),
	79: Vector2(272, 1452), 80: Vector2(124, 1545), 81: Vector2(458, 1541),
	82: Vector2(732, 1360),
	# Extended Coastline (IDs 83-92)
	83: Vector2(1447, 589), 84: Vector2(1450, 769), 85: Vector2(1539, 899),
	86: Vector2(1218, 894), 87: Vector2(1375, 1151), 88: Vector2(939, 1548),
	89: Vector2(1218, 1438), 90: Vector2(1175, 1733), 91: Vector2(1457, 1641),
	92: Vector2(1523, 1839),
	# Southern Plains (IDs 93-102)
	93: Vector2(1123, 1055), 94: Vector2(1225, 1259), 95: Vector2(1031, 1340),
	96: Vector2(1445, 1438), 97: Vector2(1132, 1594), 98: Vector2(1326, 1766),
	99: Vector2(1090, 1891), 100: Vector2(1356, 1956), 101: Vector2(1196, 2036),
	102: Vector2(1308, 1547),
	# Far Eastern Oasis (IDs 103-111)
	103: Vector2(-1497, 786), 104: Vector2(-1737, 845), 105: Vector2(-1893, 888),
	106: Vector2(-2070, 942), 107: Vector2(-2236, 980), 108: Vector2(-2394, 1038),
	109: Vector2(-2556, 1069), 110: Vector2(-2695, 1123), 111: Vector2(-2875, 1166),
	# Northwestern Connection (IDs 112-115)
	112: Vector2(444, -940), 113: Vector2(674, -749), 114: Vector2(743, -933),
	115: Vector2(940, -590),
}

# Virtual ocean seeds for coastline generation (not rendered).
# These push coastal cells inward, creating an organic coastline.
var OCEAN_SEEDS: Array[Vector2] = [
	# Top ocean
	Vector2(-3075, -1240), Vector2(-2775, -1240), Vector2(-2475, -1240),
	Vector2(-2175, -1240), Vector2(-1875, -1240), Vector2(-1575, -1240),
	Vector2(-1275, -1240), Vector2(-975, -1240), Vector2(-675, -1240),
	Vector2(-375, -1240), Vector2(-75, -1240), Vector2(225, -1240),
	Vector2(525, -1240), Vector2(825, -1240), Vector2(1125, -1240),
	Vector2(1425, -1240), Vector2(1725, -1240),
	# Bottom ocean
	Vector2(-3075, 2336), Vector2(-2775, 2336), Vector2(-2475, 2336),
	Vector2(-2175, 2336), Vector2(-1875, 2336), Vector2(-1575, 2336),
	Vector2(-1275, 2336), Vector2(-975, 2336), Vector2(-675, 2336),
	Vector2(-375, 2336), Vector2(-75, 2336), Vector2(225, 2336),
	Vector2(525, 2336), Vector2(825, 2336), Vector2(1125, 2336),
	Vector2(1425, 2336), Vector2(1725, 2336),
	# Left ocean
	Vector2(-3175, -1140), Vector2(-3175, -840), Vector2(-3175, -540),
	Vector2(-3175, -240), Vector2(-3175, 60), Vector2(-3175, 360),
	Vector2(-3175, 660), Vector2(-3175, 960), Vector2(-3175, 1260),
	Vector2(-3175, 1560), Vector2(-3175, 1860), Vector2(-3175, 2160),
	# Right ocean
	Vector2(2006, -1140), Vector2(2006, -840), Vector2(2006, -540),
	Vector2(2006, -240), Vector2(2006, 60), Vector2(2006, 360),
	Vector2(2006, 660), Vector2(2006, 960), Vector2(2006, 1260),
	Vector2(2006, 1560), Vector2(2006, 1860), Vector2(2006, 2160),
]


func _ready() -> void:
	_build_map()
	EventBus.region_selected.connect(_on_region_selected)
	EventBus.region_deselected.connect(_on_region_deselected)
	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.region_owner_changed.connect(_on_owner_changed)
	EventBus.overlay_changed.connect(_on_overlay_changed)


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
	var bounds_pos := Vector2(-3600, -1600)
	var bounds_end := Vector2(2400, 2800)

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
	# Bounds must cover the full expanded map (-2875..1706 x, -940..2036 y)
	var bounds := [Vector2(-3500, -1500), Vector2(2300, -1500),
		Vector2(2300, 2700), Vector2(-3500, 2700)]

	# Deep ocean base
	var ocean_deep := Polygon2D.new()
	ocean_deep.polygon = PackedVector2Array(bounds)
	ocean_deep.color = Color(0.06, 0.08, 0.16)
	ocean_deep.z_index = -10
	add_child(ocean_deep)

	# Mid ocean ring (slightly lighter near land)
	var ocean_mid := Polygon2D.new()
	ocean_mid.polygon = PackedVector2Array([
		Vector2(-3200, -1200), Vector2(2000, -1200),
		Vector2(2000, 2400), Vector2(-3200, 2400),
	])
	ocean_mid.color = Color(0.08, 0.10, 0.19)
	ocean_mid.z_index = -9
	add_child(ocean_mid)

	# Shallow ocean ring (closest to coast)
	var ocean_shallow := Polygon2D.new()
	ocean_shallow.polygon = PackedVector2Array([
		Vector2(-3000, -1000), Vector2(1800, -1000),
		Vector2(1800, 2200), Vector2(-3000, 2200),
	])
	ocean_shallow.color = OCEAN_COLOR
	ocean_shallow.z_index = -8
	add_child(ocean_shallow)

	# Subtle compass rose indicator (small cross in ocean corner)
	_build_compass_rose()


func _build_compass_rose() -> void:
	## Subtle directional indicator in the bottom-right ocean area.
	var center := Vector2(2050, 2400)
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
