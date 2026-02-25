class_name WorldMap
extends Node2D

## Renders world map using a hex grid projection for province shapes.
## Keeps the existing simulation data while swapping the visual topology.

const MAP_SEED := 42
const JITTER_AMOUNT := 30.0
const HEX_RADIUS := 80.0
const HEX_BOUNDS_PAD := 2

# Border styling
const PROVINCE_BORDER_COLOR := Color(0.06, 0.05, 0.03, 0.45)
const PROVINCE_BORDER_WIDTH := 1.5
const OCEAN_COLOR := Color(0.08, 0.11, 0.21)
const RIVER_GHOST_ALPHA := 0.30
const RIVER_EXPLORED_ALPHA := 0.70
const RIVER_VISIBLE_ALPHA := 1.0
const RIVER_MAJOR_ORDER := 2
const RIVER_ZOOM_MINOR := 0.9
const RIVER_ZOOM_DECO := 0.45
const ROAD_ZOOM_SHOW := 0.8
const BORDER_ZOOM_HIDE := 0.45
const BORDER_ZOOM_FADE := 0.95
const BORDER_ALPHA_FAR := 0.0
const BORDER_ALPHA_MID := 0.25
const BORDER_ALPHA_NEAR := 0.55
const RIVER_BASE_WIDTH := 1.3
const RIVER_WIDTH_SCALE := 1.0
const RIVER_SPLINE_OFFSET := 28.0
const RIVER_EDGE_INSET := 6.0
const ROAD_EDGE_INSET := 3.0
const ROAD_COLOR := Color(0.46, 0.40, 0.30, 0.80)
const ROAD_GLOW := Color(0.80, 0.74, 0.60, 0.25)
const ROAD_WIDTH := 2.2

var region_visuals: Dictionary = {}
var selected_region_id: int = -1
var seed_positions: Dictionary = {}
var region_polygons: Dictionary = {}
var border_container: Node2D
var blend_container: Node2D
var _vignette_container: Node2D
var _click_handled: bool = false
var _river_container: Node2D
var _river_major: Node2D
var _river_minor: Node2D
var _river_lakes: Node2D
var _road_container: Node2D
var _current_zoom: float = 1.0

# War border pulse
var _war_border_lines: Array[Line2D] = []
var _war_border_tween: Tween

# Ocean shimmer
var _ocean_shallow: Polygon2D
var _ocean_shimmer_tween: Tween

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
	EventBus.visibility_updated.connect(_on_visibility_updated)
	EventBus.zoom_changed.connect(_on_zoom_changed)
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


func _build_roads() -> void:
	_build_roads_impl()


func _build_map() -> void:
	for child in get_children():
		child.queue_free()
	region_visuals.clear()
	seed_positions.clear()
	region_polygons.clear()

	# Layered ocean with depth gradient
	_build_ocean()

	# Generate hex polygons aligned to the existing seed layout
	_build_hex_grid()

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

	# Auto-compute adjacency from polygon geometry (replaces manual .tres data)
	# MUST happen BEFORE visibility init or any simulation that uses adjacency
	_compute_adjacency_from_polygons()

	# Initialize fog of war: compute visibility from owned regions + neighbors
	# MUST happen AFTER adjacency is computed and civs have starting regions
	GameState.update_all_visibility()

	# Build rivers (z=3, between terrain and borders)
	_build_rivers()

	# Build roads (above rivers, below borders)
	_build_roads()

	# Shore bands along coastline regions (z=-1, between ocean and land)
	_build_shore_bands()

	# Edge blending between different terrain types (z=2, between terrain and borders)
	_build_edge_blending()

	# Build border lines on top of everything
	border_container = Node2D.new()
	border_container.z_index = 5
	add_child(border_container)
	_build_all_borders()

	# Refresh all region visuals now that visibility, rivers, and borders exist
	for visual in region_visuals.values():
		visual.update_appearance()

	# Map edge vignette (dark gradient around edges)
	_build_vignette()

	# Start ocean shimmer animation
	_start_ocean_shimmer()


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


func _build_hex_grid() -> void:
	## Build a hex grid map from GameState hex coordinates.
	HexMetrics.set_size(HEX_RADIUS)

	if GameState.region_hex_coords.is_empty():
		push_warning("No hex coords available; map will be empty.")
		return

	for region_id in GameState.region_hex_coords:
		var coord: Vector2i = GameState.region_hex_coords[region_id]
		var center := HexMetrics.axial_to_world(coord.x, coord.y)
		seed_positions[region_id] = center

		var poly := PackedVector2Array()
		for corner in HexMetrics.corners():
			poly.append(center + corner)
		region_polygons[region_id] = poly


func _compute_axial_bounds(bounds: Rect2) -> Dictionary:
	var corners := [
		bounds.position,
		Vector2(bounds.position.x + bounds.size.x, bounds.position.y),
		Vector2(bounds.position.x + bounds.size.x, bounds.position.y + bounds.size.y),
		Vector2(bounds.position.x, bounds.position.y + bounds.size.y),
	]

	var q_min := INF
	var q_max := -INF
	var r_min := INF
	var r_max := -INF

	for corner in corners:
		var axial := HexMetrics.world_to_axial(corner)
		q_min = minf(q_min, axial.x)
		q_max = maxf(q_max, axial.x)
		r_min = minf(r_min, axial.y)
		r_max = maxf(r_max, axial.y)

	return {
		"q_min": int(floor(q_min)) - HEX_BOUNDS_PAD,
		"q_max": int(ceil(q_max)) + HEX_BOUNDS_PAD,
		"r_min": int(floor(r_min)) - HEX_BOUNDS_PAD,
		"r_max": int(ceil(r_max)) + HEX_BOUNDS_PAD,
	}


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
	## Compute each region's size_factor from polygon area.
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


func _get_era_params() -> Dictionary:
	var player_civ := GameState.get_player_civ()
	var era: int = player_civ.current_era if player_civ else 2
	return Constants.ERA_VISUAL_PARAMS.get(era, Constants.ERA_VISUAL_PARAMS[2])


static func _wobble_points(pts: PackedVector2Array, region_id: int) -> PackedVector2Array:
	## Apply deterministic vertex wobble for prehistoric "hand-drawn" border style.
	var rng := RandomNumberGenerator.new()
	rng.seed = region_id * 3571
	var wobbled := PackedVector2Array()
	for p in pts:
		var offset := Vector2(
			rng.randf_range(-2.0, 2.0),
			rng.randf_range(-2.0, 2.0),
		)
		wobbled.append(p + offset)
	return wobbled


func _build_rivers() -> void:
	## Draw variable-width centerline rivers through region interiors.
	_clear_rivers()
	_river_container = Node2D.new()
	_river_container.z_index = 6
	add_child(_river_container)

	_river_major = Node2D.new()
	_river_minor = Node2D.new()
	_river_lakes = Node2D.new()
	_river_container.add_child(_river_major)
	_river_container.add_child(_river_minor)
	_river_container.add_child(_river_lakes)

	# Build edge-aligned river channels (CatlikeCoding-style)
	_build_river_edges()

	# Draw lakes with shore ring and inner highlight
	for region_id in region_polygons:
		var region: RegionData = GameState.get_region(region_id)
		if not region or not region.has_lake:
			continue

		var poly: PackedVector2Array = region_polygons[region_id]
		if poly.size() < 3:
			continue

		var cx := 0.0
		var cy := 0.0
		for v in poly:
			cx += v.x
			cy += v.y
		cx /= float(poly.size())
		cy /= float(poly.size())
		var center := Vector2(cx, cy)

		var lake_alpha := _get_river_alpha(region_id, -1)
		# Shore ring
		var shore_ring := _make_circle_line(center, 12.0, 12, Color(0.22, 0.55, 0.72, 0.30 * lake_alpha), 2.5)
		_river_lakes.add_child(shore_ring)

		# Main lake body (deep blue)
		var lake := _make_filled_circle(center, 10.0, 12, Color(0.10, 0.38, 0.70, 0.80 * lake_alpha))
		_river_lakes.add_child(lake)

		# Inner highlight (brighter blue center)
		var highlight := _make_filled_circle(center, 5.0, 8, Color(0.55, 0.86, 1.0, 0.40 * lake_alpha))
		_river_lakes.add_child(highlight)

	_update_river_visibility()


func _build_all_borders() -> void:
	for child in border_container.get_children():
		child.queue_free()

	var era_params := _get_era_params()
	var border_w: float = era_params["border_width"]
	var border_a: float = era_params["border_alpha"]
	var border_style: String = era_params["border_style"]

	# Province outlines (thin lines around every region -- skip HIDDEN)
	for region_id in region_polygons:
		var vis := GameState.get_player_visibility(region_id)
		if vis == Enums.VisibilityState.HIDDEN:
			continue

		var poly: PackedVector2Array = region_polygons[region_id]
		if poly.size() < 3:
			continue

		var region: RegionData = GameState.get_region(region_id)

		# Check if region is fully interior to an empire (all neighbors same owner)
		var is_interior := false
		if region and region.owner_id >= 0:
			is_interior = true
			for adj_id in region.adjacency_list:
				var adj: RegionData = GameState.get_region(adj_id)
				if not adj or adj.owner_id != region.owner_id:
					is_interior = false
					break

		var line := Line2D.new()
		var pts := PackedVector2Array(poly)
		pts.append(poly[0])

		# Prehistoric rough style: wobble vertices
		if border_style == "rough":
			pts = _wobble_points(pts, region_id)

		line.points = pts

		if is_interior:
			# Interior province: much thinner and more transparent
			line.width = border_w * Constants.SAME_EMPIRE_PROVINCE_BORDER_WIDTH_MULT
			line.default_color = Color(PROVINCE_BORDER_COLOR.r, PROVINCE_BORDER_COLOR.g,
				PROVINCE_BORDER_COLOR.b, Constants.SAME_EMPIRE_PROVINCE_BORDER_ALPHA)
		else:
			line.width = border_w
			line.default_color = Color(PROVINCE_BORDER_COLOR.r, PROVINCE_BORDER_COLOR.g,
				PROVINCE_BORDER_COLOR.b, border_a)
		line.antialiased = true
		border_container.add_child(line)

	# CK3-style colored empire borders
	_draw_civ_borders()


func _draw_civ_borders() -> void:
	var drawn: Dictionary = {}
	_war_border_lines.clear()
	if _war_border_tween:
		_war_border_tween.kill()
		_war_border_tween = null

	var era_params := _get_era_params()
	var civ_border_w: float = era_params["civ_border_width"]
	var border_style: String = era_params["border_style"]

	for region_id in region_polygons:
		var region: RegionData = GameState.get_region(region_id)
		if not region:
			continue

		var vis_a := GameState.get_player_visibility(region_id)
		if vis_a == Enums.VisibilityState.HIDDEN:
			continue

		for adj_id in region.adjacency_list:
			if not region_polygons.has(adj_id):
				continue

			var vis_b := GameState.get_player_visibility(adj_id)
			if vis_b == Enums.VisibilityState.HIDDEN:
				continue

			var pair_key: int = mini(region_id, adj_id) * 10000 + maxi(region_id, adj_id)
			if drawn.has(pair_key):
				continue
			drawn[pair_key] = true

			var adj: RegionData = GameState.get_region(adj_id)
			if not adj or region.owner_id == adj.owner_id:
				continue

			# Detect war front
			var is_war_front := false
			if region.owner_id >= 0 and adj.owner_id >= 0:
				var civ_a := GameState.get_civilization(region.owner_id)
				if civ_a and adj.owner_id in civ_a.war_targets:
					is_war_front = true

			var shared := _find_shared_edge(region_id, adj_id)
			if shared.size() < 2:
				continue

			if is_war_front:
				_draw_war_border(shared, civ_border_w, border_style)
			else:
				var color_a := _get_border_color(region.owner_id)
				var color_b := _get_border_color(adj.owner_id)
				_draw_empire_border_edge(shared, color_a, color_b, civ_border_w, border_style)

	_animate_war_borders()


func _get_border_color(owner_id: int) -> Color:
	## Returns the civ color for an owner, or neutral muted brown for unowned.
	if owner_id < 0:
		return Color(0.35, 0.33, 0.28, 0.6)
	var civ := GameState.get_civilization(owner_id)
	if not civ:
		return Color(0.35, 0.33, 0.28, 0.6)
	return civ.color


static func _blend_two_colors(a: Color, b: Color) -> Color:
	## Average two colors with a slight saturation boost for vibrancy.
	var blended := a.lerp(b, 0.5)
	var h := blended.h
	var s := minf(blended.s + 0.1, 1.0)
	var v := blended.v
	return Color.from_hsv(h, s, v)


func _draw_empire_border_edge(
	shared: PackedVector2Array,
	color_a: Color,
	color_b: Color,
	base_width: float,
	border_style: String,
) -> void:
	## Draw CK3/Stellaris-style colored empire border with multi-layer glow.
	var blend_color := _blend_two_colors(color_a, color_b)

	# Layer 1: Outer diffuse glow (widest, most transparent)
	var outer_glow := Line2D.new()
	outer_glow.points = shared
	outer_glow.antialiased = true
	outer_glow.z_index = 1
	outer_glow.width = base_width + Constants.EMPIRE_BORDER_OUTER_GLOW_EXTRA_WIDTH
	outer_glow.default_color = Color(
		blend_color.r, blend_color.g, blend_color.b,
		Constants.EMPIRE_BORDER_OUTER_GLOW_ALPHA)
	if border_style == "glow":
		outer_glow.width += 4.0
		outer_glow.default_color.a += 0.05
	border_container.add_child(outer_glow)

	# Layer 2: Inner glow (narrower, brighter)
	var inner_glow := Line2D.new()
	inner_glow.points = shared
	inner_glow.antialiased = true
	inner_glow.z_index = 1
	inner_glow.width = base_width + Constants.EMPIRE_BORDER_INNER_GLOW_EXTRA_WIDTH
	inner_glow.default_color = Color(
		blend_color.r, blend_color.g, blend_color.b,
		Constants.EMPIRE_BORDER_INNER_GLOW_ALPHA)
	border_container.add_child(inner_glow)

	# Layer 3: Main border line (darkened civ color blend)
	var main_line := Line2D.new()
	main_line.points = shared
	main_line.antialiased = true
	main_line.z_index = 2
	main_line.width = base_width
	var main_color := blend_color.darkened(0.25)
	main_line.default_color = Color(
		main_color.r, main_color.g, main_color.b,
		Constants.EMPIRE_BORDER_MAIN_ALPHA)
	border_container.add_child(main_line)


func _draw_war_border(
	shared: PackedVector2Array,
	base_width: float,
	border_style: String,
) -> void:
	## Draw pulsing red war front border with intense glow.
	# Red outer glow
	var glow := Line2D.new()
	glow.points = shared
	glow.antialiased = true
	glow.z_index = 1
	glow.width = base_width + Constants.EMPIRE_BORDER_OUTER_GLOW_EXTRA_WIDTH
	glow.default_color = Color(0.8, 0.1, 0.05, 0.25)
	if border_style == "glow":
		glow.width += 4.0
	border_container.add_child(glow)

	# Inner red glow
	var inner := Line2D.new()
	inner.points = shared
	inner.antialiased = true
	inner.z_index = 1
	inner.width = base_width + Constants.EMPIRE_BORDER_INNER_GLOW_EXTRA_WIDTH
	inner.default_color = Color(0.9, 0.15, 0.1, 0.30)
	border_container.add_child(inner)

	# Main red line
	var line := Line2D.new()
	line.points = shared
	line.width = base_width
	line.default_color = Color(0.85, 0.15, 0.1, 0.9)
	line.antialiased = true
	line.z_index = 2
	border_container.add_child(line)
	_war_border_lines.append(line)


func _find_shared_edge(id_a: int, id_b: int) -> PackedVector2Array:
	## Find the shared boundary between two adjacent polygons.
	var poly_a: PackedVector2Array = region_polygons.get(id_a, PackedVector2Array())
	var poly_b: PackedVector2Array = region_polygons.get(id_b, PackedVector2Array())
	if poly_a.size() < 3 or poly_b.size() < 3:
		return PackedVector2Array()

	const EPS := 3.0
	var shared: Array[Vector2] = []

	for va in poly_a:
		for vb in poly_b:
			if va.distance_squared_to(vb) <= EPS * EPS:
				var is_dup := false
				for existing in shared:
					if va.distance_squared_to(existing) <= 1.0:
						is_dup = true
						break
				if not is_dup:
					shared.append(va)

	if shared.size() < 2:
		return PackedVector2Array()

	var center := Vector2.ZERO
	for v in shared:
		center += v
	center /= float(shared.size())

	shared.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return atan2(a.y - center.y, a.x - center.x) < atan2(b.y - center.y, b.x - center.x)
	)

	var result := PackedVector2Array()
	for v in shared:
		result.append(v)
	return result


func _make_filled_circle(center: Vector2, radius: float, segments: int, color: Color) -> Polygon2D:
	var pts := PackedVector2Array()
	for i in segments:
		var angle := float(i) / float(segments) * TAU
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	var circle := Polygon2D.new()
	circle.polygon = pts
	circle.color = color
	return circle


func _make_circle_line(center: Vector2, radius: float, segments: int, color: Color, width: float) -> Line2D:
	var pts := PackedVector2Array()
	for i in segments + 1:
		var angle := float(i) / float(segments) * TAU
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	var line := Line2D.new()
	line.points = pts
	line.width = width
	line.default_color = color
	line.antialiased = true
	return line


# --- Signal Handlers ---

func _on_region_selected(region_id: int) -> void:
	_click_handled = true
	if selected_region_id >= 0 and selected_region_id != region_id:
		EventBus.region_deselected.emit()
	selected_region_id = region_id


func _on_region_deselected() -> void:
	selected_region_id = -1


func _on_turn_ended(_year: int) -> void:
	# Visual refresh is handled by _on_visibility_updated (emitted before turn_ended)
	# Only rebuild borders here for ownership changes during the turn
	pass


func _on_visibility_updated() -> void:
	## Refresh all region visuals and borders when fog of war changes.
	for visual in region_visuals.values():
		visual.update_appearance()
	_build_all_borders()
	_build_rivers()


func _on_owner_changed(_region_id: int, _old: int, _new: int) -> void:
	_refresh_civ_borders()


func _on_overlay_changed(_overlay: int) -> void:
	for visual in region_visuals.values():
		visual.update_appearance()


func _refresh_civ_borders() -> void:
	# Remove civ borders (z_index >= 1), keep province outlines (z_index 0)
	for child in border_container.get_children():
		if child.z_index >= 1:
			child.queue_free()
	_draw_civ_borders()


func _on_zoom_changed(zoom_level: float) -> void:
	_current_zoom = zoom_level
	_update_river_visibility()
	_update_road_visibility()
	_update_border_visibility()


func _update_river_visibility() -> void:
	if not _river_major or not _river_minor:
		return
	_river_minor.visible = _current_zoom >= RIVER_ZOOM_MINOR
	_river_major.visible = _current_zoom >= RIVER_ZOOM_DECO


func _update_road_visibility() -> void:
	if _road_container:
		_road_container.visible = _current_zoom >= ROAD_ZOOM_SHOW


func _update_border_visibility() -> void:
	if not border_container:
		return
	var alpha := BORDER_ALPHA_NEAR
	if _current_zoom < BORDER_ZOOM_HIDE:
		alpha = BORDER_ALPHA_FAR
	elif _current_zoom < BORDER_ZOOM_FADE:
		alpha = BORDER_ALPHA_MID
	border_container.modulate = Color(1.0, 1.0, 1.0, alpha)


func _clear_rivers() -> void:
	if _river_container:
		_river_container.queue_free()
		_river_container = null
		_river_major = null
		_river_minor = null
		_river_lakes = null


func _clear_roads() -> void:
	if _road_container:
		_road_container.queue_free()
		_road_container = null


func _get_river_alpha(region_id: int, adj_id: int) -> float:
	var vis_a := GameState.get_player_visibility(region_id)
	var vis_b := vis_a
	if adj_id >= 0:
		vis_b = GameState.get_player_visibility(adj_id)
	var vis := maxi(vis_a, vis_b)
	match vis:
		Enums.VisibilityState.VISIBLE:
			return RIVER_VISIBLE_ALPHA
		Enums.VisibilityState.EXPLORED:
			return RIVER_EXPLORED_ALPHA
		_:
			return RIVER_GHOST_ALPHA


func _add_delta_fan(center: Vector2, dir: Vector2, width: float, alpha: float, parent: Node2D) -> void:
	var side := Vector2(-dir.y, dir.x)
	var len := width * 3.0
	var left := center + (dir * len) + side * (width * 1.2)
	var right := center + (dir * len) - side * (width * 1.2)
	var fan := Polygon2D.new()
	fan.polygon = PackedVector2Array([center, left, right])
	fan.color = Color(0.35, 0.78, 0.95, 0.30 * alpha)
	parent.add_child(fan)


func _build_river_paths() -> void:
	## Build continuous river paths by following directed river connections.
	var river_nodes: Array[int] = []
	for region_id in region_polygons:
		var region: RegionData = GameState.get_region(region_id)
		if region and region.has_river:
			river_nodes.append(region_id)

	if river_nodes.is_empty():
		return

	# Build directed graph: upstream -> downstream
	var outgoing: Dictionary = {}
	var incoming_count: Dictionary = {}
	for region_id in river_nodes:
		outgoing[region_id] = []
		incoming_count[region_id] = 0

	for region_id in river_nodes:
		var region: RegionData = GameState.get_region(region_id)
		for adj_id in region.river_connections:
			if not outgoing.has(adj_id):
				continue
			var adj: RegionData = GameState.get_region(adj_id)
			if not adj:
				continue

			var from_id := region_id
			var to_id := adj_id
			if region.river_order > adj.river_order:
				from_id = adj_id
				to_id = region_id
			elif region.river_order == adj.river_order:
				# Fallback to elevation: higher -> lower
				if region.elevation < adj.elevation:
					from_id = adj_id
					to_id = region_id

			# Avoid duplicate edges
			if to_id in outgoing[from_id]:
				continue
			outgoing[from_id].append(to_id)
			incoming_count[to_id] = incoming_count.get(to_id, 0) + 1

	# Sources = nodes with no incoming edges
	var sources: Array[int] = []
	for region_id in river_nodes:
		if incoming_count.get(region_id, 0) == 0:
			sources.append(region_id)

	# Draw each river path
	var drawn_nodes: Dictionary = {}
	for source_id in sources:
		var path: Array[int] = _walk_river_path(source_id, outgoing)
		if path.size() < 2:
			continue
		for pid in path:
			drawn_nodes[pid] = true
		_draw_river_path(path)

	# Fallback: any isolated loops or missed nodes
	for region_id in river_nodes:
		if drawn_nodes.has(region_id):
			continue
		var fallback := _walk_river_path(region_id, outgoing)
		if fallback.size() >= 2:
			_draw_river_path(fallback)


func _walk_river_path(start_id: int, outgoing: Dictionary) -> Array[int]:
	var path: Array[int] = []
	var visited: Dictionary = {}
	var current := start_id
	while true:
		if visited.has(current):
			break
		visited[current] = true
		path.append(current)
		var next_list: Array = outgoing.get(current, [])
		if next_list.is_empty():
			break
		# Choose downstream: highest river_order, then lowest elevation
		var best_id: int = int(next_list[0])
		var best_order := GameState.get_region(best_id).river_order
		var best_elev := GameState.get_region(best_id).elevation
		for candidate_id in next_list:
			var cand := GameState.get_region(candidate_id)
			if not cand:
				continue
			if cand.river_order > best_order or (cand.river_order == best_order and cand.elevation < best_elev):
				best_id = candidate_id
				best_order = cand.river_order
				best_elev = cand.elevation
		current = best_id
	return path


func _draw_river_path(path: Array[int]) -> void:
	var pts := PackedVector2Array()
	var max_order := 1
	var vis_alpha := 0.0
	var has_coast := false
	var bulge_drawn: Dictionary = {}

	for rid in path:
		if not region_polygons.has(rid):
			continue
		var region: RegionData = GameState.get_region(rid)
		max_order = maxi(max_order, region.river_order)
		if region.terrain_type == Enums.TerrainType.COASTLINE:
			has_coast = true
		vis_alpha = maxf(vis_alpha, _get_river_alpha(rid, -1))
		pts.append(_centroid(region_polygons[rid]))

	if pts.size() < 2:
		return

	var river_width := RIVER_BASE_WIDTH + float(max_order) * RIVER_WIDTH_SCALE
	if has_coast:
		river_width *= 2.0

	var target_container := _river_major if max_order >= RIVER_MAJOR_ORDER else _river_minor
	var spline := _make_river_spline_path(pts, max_order * 7919, river_width, vis_alpha)
	target_container.add_child(spline)

	# Junction bulges + delta fans
	for i in pts.size():
		var rid: int = int(path[i])
		var region := GameState.get_region(rid)
		if region and region.river_connections.size() >= 2 and not bulge_drawn.has(rid):
			bulge_drawn[rid] = true
			var bulge := _make_filled_circle(pts[i], river_width * 0.7, 12, Color(0.25, 0.70, 0.90, 0.35 * vis_alpha))
			target_container.add_child(bulge)

		# Delta fan at coastline
		if region and region.terrain_type == Enums.TerrainType.COASTLINE and i > 0:
			var dir := (pts[i] - pts[i - 1]).normalized()
			_add_delta_fan(pts[i], dir, river_width, vis_alpha, target_container)


func _make_river_spline_path(points: PackedVector2Array, seed: int, width: float, alpha: float) -> Node2D:
	## Create a smooth spline through a path of points (Catmull-Rom style).
	var container := Node2D.new()
	if points.size() < 2:
		return container

	var smooth := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var jitter_amp := minf(10.0, float(points.size()) * 1.2)

	for i in points.size():
		var p0 := points[maxi(i - 1, 0)]
		var p1 := points[i]
		var p2 := points[mini(i + 1, points.size() - 1)]
		var p3 := points[mini(i + 2, points.size() - 1)]
		var steps := 6
		for s in steps:
			var t := float(s) / float(steps)
			var pt := _catmull_rom(p0, p1, p2, p3, t)
			var dir := (p2 - p1).normalized()
			var perp := Vector2(-dir.y, dir.x)
			var jitter := sin(t * TAU + rng.randf()) * jitter_amp * 0.15
			pt += perp * jitter
			smooth.append(pt)

	smooth.append(points[points.size() - 1])

	# Outer glow
	var glow := Line2D.new()
	glow.points = smooth
	glow.width = width * 1.4
	glow.default_color = Color(0.30, 0.75, 0.92, 0.28 * alpha)
	glow.antialiased = true
	container.add_child(glow)

	# Core line
	var core := Line2D.new()
	core.points = smooth
	core.width = width
	core.default_color = Color(0.08, 0.34, 0.70, 0.85 * alpha)
	core.antialiased = true
	container.add_child(core)

	# Inner highlight
	var highlight := Line2D.new()
	highlight.points = smooth
	highlight.width = maxf(width * 0.45, 1.0)
	highlight.default_color = Color(0.60, 0.88, 1.0, 0.35 * alpha)
	highlight.antialiased = true
	container.add_child(highlight)

	return container


func _build_river_edges() -> void:
	## Draw rivers along shared hex edges, offset slightly toward downstream.
	var drawn: Dictionary = {}
	for region_id in region_polygons:
		var region: RegionData = GameState.get_region(region_id)
		if not region or region.river_connections.is_empty():
			continue
		for adj_id in region.river_connections:
			if adj_id == region_id:
				continue
			var a: int = mini(region_id, adj_id)
			var b: int = maxi(region_id, adj_id)
			var key: String = "%d:%d" % [a, b]
			if drawn.has(key):
				continue
			drawn[key] = true

			var adj: RegionData = GameState.get_region(adj_id)
			if not adj:
				continue

			var edge: PackedVector2Array = _find_shared_edge(region_id, adj_id)
			if edge.size() < 2:
				continue

			var p0: Vector2 = edge[0]
			var p1: Vector2 = edge[edge.size() - 1]

			var max_order := maxi(region.river_order, adj.river_order)
			var width := RIVER_BASE_WIDTH + float(max_order) * RIVER_WIDTH_SCALE
			if region.terrain_type == Enums.TerrainType.COASTLINE or adj.terrain_type == Enums.TerrainType.COASTLINE:
				width *= 1.8

			var alpha := _get_river_alpha(region_id, adj_id)
			var downstream: RegionData = _pick_downstream_region(region, adj)
			var downstream_center: Vector2 = seed_positions.get(downstream.id, Vector2.ZERO)
			var shifted: Array[Vector2] = _offset_edge_toward(p0, p1, downstream_center, RIVER_EDGE_INSET + width * 0.2)

			_add_river_segment(shifted[0], shifted[1], width, alpha, max_order)

			if downstream.terrain_type == Enums.TerrainType.COASTLINE:
				var dir := (shifted[1] - shifted[0]).normalized()
				_add_delta_fan((shifted[0] + shifted[1]) * 0.5, dir, width, alpha, _river_major)

	# Junction bulges at confluences
	for region_id in region_polygons:
		var region: RegionData = GameState.get_region(region_id)
		if not region or region.river_connections.size() < 2:
			continue
		var center: Vector2 = seed_positions.get(region_id, Vector2.ZERO)
		var width := RIVER_BASE_WIDTH + float(region.river_order) * RIVER_WIDTH_SCALE
		var alpha := _get_river_alpha(region_id, -1)
		var bulge := _make_filled_circle(center, width * 0.75, 12, Color(0.25, 0.70, 0.90, 0.35 * alpha))
		_river_minor.add_child(bulge)


func _pick_downstream_region(a: RegionData, b: RegionData) -> RegionData:
	if a.river_order > b.river_order:
		return a
	if b.river_order > a.river_order:
		return b
	if a.elevation < b.elevation:
		return a
	if b.elevation < a.elevation:
		return b
	return a


func _offset_edge_toward(p0: Vector2, p1: Vector2, target: Vector2, amount: float) -> Array[Vector2]:
	var mid := (p0 + p1) * 0.5
	var dir := (p1 - p0).normalized()
	var perp := Vector2(-dir.y, dir.x)
	if (target - mid).dot(perp) < 0.0:
		perp = -perp
	var offset := perp * amount
	return [p0 + offset, p1 + offset]


func _add_river_segment(p0: Vector2, p1: Vector2, width: float, alpha: float, order: int) -> void:
	var target_container := _river_major if order >= RIVER_MAJOR_ORDER else _river_minor
	var pts := PackedVector2Array([p0, p1])

	var glow := Line2D.new()
	glow.points = pts
	glow.width = width * 2.4
	glow.default_color = Color(0.25, 0.60, 0.90, 0.22 * alpha)
	glow.antialiased = true
	target_container.add_child(glow)

	var core := Line2D.new()
	core.points = pts
	core.width = width * 1.35
	core.default_color = Color(0.16, 0.45, 0.78, 0.80 * alpha)
	core.antialiased = true
	target_container.add_child(core)

	var highlight := Line2D.new()
	highlight.points = pts
	highlight.width = maxf(1.0, width * 0.55)
	highlight.default_color = Color(0.55, 0.86, 1.0, 0.55 * alpha)
	highlight.antialiased = true
	target_container.add_child(highlight)


func _catmull_rom(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (
		(2.0 * p1) +
		(-p0 + p2) * t +
		(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
		(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)


func _make_river_spline(start: Vector2, end: Vector2, seed: int, width: float, alpha: float) -> Node2D:
	## Build a curved centerline spline between two centroids.
	var container := Node2D.new()
	var dir := (end - start).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7919
	var dist := start.distance_to(end)
	var offset_scale := clampf(dist / 200.0, 0.4, 1.0)
	var offset1 := rng.randf_range(-RIVER_SPLINE_OFFSET, RIVER_SPLINE_OFFSET) * offset_scale
	var offset2 := rng.randf_range(-RIVER_SPLINE_OFFSET, RIVER_SPLINE_OFFSET) * offset_scale

	var mid1 := start + (end - start) * 0.35 + perp * offset1
	var mid2 := start + (end - start) * 0.65 + perp * offset2

	var steps := clampi(int(dist / 25.0), 6, 16)
	var pts := PackedVector2Array()
	var phase := rng.randf_range(0.0, TAU)
	var jitter_amp := minf(8.0, dist * 0.08)
	for i in steps + 1:
		var t := float(i) / float(steps)
		var p := _bezier_point(start, mid1, mid2, end, t)
		var falloff := 1.0 - absf(t - 0.5) * 2.0
		var jitter := sin(t * TAU * 1.2 + phase) * jitter_amp * falloff
		p += perp * jitter
		pts.append(p)

	# Outer glow
	var glow := Line2D.new()
	glow.points = pts
	glow.width = width * 1.4
	glow.default_color = Color(0.30, 0.75, 0.92, 0.28 * alpha)
	glow.antialiased = true
	container.add_child(glow)

	# Core line
	var core := Line2D.new()
	core.points = pts
	core.width = width
	core.default_color = Color(0.08, 0.34, 0.70, 0.85 * alpha)
	core.antialiased = true
	container.add_child(core)

	# Inner highlight
	var highlight := Line2D.new()
	highlight.points = pts
	highlight.width = maxf(width * 0.45, 1.0)
	highlight.default_color = Color(0.60, 0.88, 1.0, 0.35 * alpha)
	highlight.antialiased = true
	container.add_child(highlight)

	return container


func _bezier_point(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var it := 1.0 - t
	return p0 * (it * it * it) + p1 * (3.0 * it * it * t) + p2 * (3.0 * it * t * t) + p3 * (t * t * t)


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
	ocean_deep.color = Color(0.05, 0.07, 0.17)
	ocean_deep.z_index = -10
	add_child(ocean_deep)

	# Mid ocean ring (slightly lighter near land)
	var ocean_mid := Polygon2D.new()
	ocean_mid.polygon = PackedVector2Array([
		Vector2(-1500, -1200), Vector2(2300, -1200),
		Vector2(2300, 2000), Vector2(-1500, 2000),
	])
	ocean_mid.color = Color(0.07, 0.09, 0.20)
	ocean_mid.z_index = -9
	add_child(ocean_mid)

	# Shallow ocean ring (closest to coast) with noise-based color variation
	_ocean_shallow = Polygon2D.new()
	var shallow_pts := PackedVector2Array([
		Vector2(-1300, -1000), Vector2(2100, -1000),
		Vector2(2100, 1900), Vector2(-1300, 1900),
	])
	_ocean_shallow.polygon = shallow_pts
	_ocean_shallow.color = Color.WHITE
	_ocean_shallow.z_index = -8
	# Generate ocean noise texture for subtle depth variation
	var ocean_tex := _generate_ocean_texture()
	if ocean_tex:
		_ocean_shallow.texture = ocean_tex
		_ocean_shallow.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		var tex_size := ocean_tex.get_size()
		var uv := PackedVector2Array()
		for p in shallow_pts:
			uv.append(Vector2(p.x / tex_size.x, p.y / tex_size.y) * 0.5)
		_ocean_shallow.uv = uv
	else:
		_ocean_shallow.color = OCEAN_COLOR
	add_child(_ocean_shallow)

	# Subtle compass rose indicator (small cross in ocean corner)
	_build_compass_rose()


func _generate_ocean_texture() -> ImageTexture:
	## Generate a 512x512 noise texture for ocean depth variation.
	var size := 512
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = 7777
	noise.frequency = 0.004

	var detail := FastNoiseLite.new()
	detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	detail.seed = 8888
	detail.frequency = 0.015

	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var base_col := OCEAN_COLOR
	var deep := Color(0.06, 0.09, 0.18)
	var light := Color(0.12, 0.16, 0.24)

	for y in size:
		for x in size:
			var n := noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var d := detail.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var combined := n * 0.7 + d * 0.3
			var col := deep.lerp(light, combined)
			img.set_pixel(x, y, col)

	return ImageTexture.create_from_image(img)


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


func _build_shore_bands() -> void:
	## Draw semi-transparent shore bands along coastline region perimeters.
	## Creates a soft water-edge effect between ocean and land.
	var shore_container := Node2D.new()
	shore_container.z_index = -1
	add_child(shore_container)

	for region_id in region_polygons:
		var region: RegionData = GameState.get_region(region_id)
		if not region or region.terrain_type != Enums.TerrainType.COASTLINE:
			continue

		var poly: PackedVector2Array = region_polygons[region_id]
		if poly.size() < 3:
			continue

		# Foam line: thin white-blue line along entire polygon perimeter
		var foam := Line2D.new()
		var foam_pts := PackedVector2Array(poly)
		foam_pts.append(poly[0])
		foam.points = foam_pts
		foam.width = 1.5
		foam.default_color = Color(0.75, 0.82, 0.90, 0.30)
		foam.antialiased = true
		shore_container.add_child(foam)

		# Shore gradient: wider translucent blue band
		var shore := Line2D.new()
		shore.points = foam_pts
		shore.width = 7.0
		shore.default_color = Color(0.20, 0.35, 0.55, 0.20)
		shore.antialiased = true
		shore_container.add_child(shore)


func _build_roads_impl() -> void:
	## Draw simple roads along shared edges between owned regions with infrastructure.
	_clear_roads()
	_road_container = Node2D.new()
	_road_container.z_index = 7
	add_child(_road_container)

	var drawn: Dictionary = {}
	for region_id in region_polygons:
		var region: RegionData = GameState.get_region(region_id)
		if not region or region.infrastructure_level <= 0:
			continue
		if region.owner_id < 0:
			continue

		for adj_id in region.adjacency_list:
			var a: int = mini(region_id, adj_id)
			var b: int = maxi(region_id, adj_id)
			var key: String = "%d:%d" % [a, b]
			if drawn.has(key):
				continue

			var adj: RegionData = GameState.get_region(adj_id)
			if not adj or adj.infrastructure_level <= 0 or adj.owner_id != region.owner_id:
				continue
			# Skip roads that would overlap a river edge
			if adj_id in region.river_connections:
				continue

			var edge: PackedVector2Array = _find_shared_edge(region_id, adj_id)
			if edge.size() < 2:
				continue

			drawn[key] = true
			var p0: Vector2 = edge[0]
			var p1: Vector2 = edge[edge.size() - 1]
			var mid := (p0 + p1) * 0.5
			var center: Vector2 = (seed_positions.get(region_id, Vector2.ZERO) + seed_positions.get(adj_id, Vector2.ZERO)) * 0.5
			var shifted: Array[Vector2] = _offset_edge_toward(p0, p1, center, ROAD_EDGE_INSET)
			_add_road_segment(shifted[0], shifted[1])


func _add_road_segment(p0: Vector2, p1: Vector2) -> void:
	var pts := PackedVector2Array([p0, p1])

	var glow := Line2D.new()
	glow.points = pts
	glow.width = ROAD_WIDTH * 2.0
	glow.default_color = ROAD_GLOW
	glow.antialiased = true
	_road_container.add_child(glow)

	var line := Line2D.new()
	line.points = pts
	line.width = ROAD_WIDTH
	line.default_color = ROAD_COLOR
	line.antialiased = true
	_road_container.add_child(line)


func _center_camera() -> void:
	## Center camera on the continent after map build.
	var camera := get_viewport().get_camera_2d()
	if camera and camera.has_method("center_on_map"):
		var bounds := get_map_bounds()
		camera.center_on_map(bounds)


func _compute_adjacency_from_polygons() -> void:
	## Auto-compute region adjacency from shared polygon edges.
	## Two regions are adjacent if their polygons share 2+ vertices within EPSILON.
	## This replaces the manually curated adjacency_list data in .tres files.
	var region_ids: Array = region_polygons.keys()

	# Clear all existing adjacency data
	for id in region_ids:
		var region := GameState.get_region(id)
		if region:
			region.adjacency_list.clear()

	# Check each unique pair once (i < j avoids duplicates)
	for i in region_ids.size():
		for j in range(i + 1, region_ids.size()):
			var id_a: int = region_ids[i]
			var id_b: int = region_ids[j]
			if _polygons_share_edge(region_polygons[id_a], region_polygons[id_b]):
				var ra := GameState.get_region(id_a)
				var rb := GameState.get_region(id_b)
				if ra and rb:
					ra.adjacency_list.append(id_b)
					rb.adjacency_list.append(id_a)


static func _polygons_share_edge(
	poly_a: PackedVector2Array, poly_b: PackedVector2Array
) -> bool:
	## Returns true if two polygons share an edge (2+ vertices within EPSILON).
	const EPSILON_SQ := 4.0  # 2.0 pixels squared (avoids sqrt)
	var shared_count := 0
	for va in poly_a:
		for vb in poly_b:
			if va.distance_squared_to(vb) < EPSILON_SQ:
				shared_count += 1
				if shared_count >= 2:
					return true
	return false


# --- War Border Pulse (B-4) ---

func _animate_war_borders() -> void:
	if _war_border_lines.is_empty():
		return
	if _war_border_tween:
		_war_border_tween.kill()
	_pulse_war_borders()


func _pulse_war_borders() -> void:
	if _war_border_lines.is_empty():
		return
	_war_border_tween = create_tween()
	var bright := Color(1.0, 0.35, 0.25, 0.95)
	var dim := Color(0.65, 0.12, 0.08, 0.7)
	for line in _war_border_lines:
		_war_border_tween.parallel().tween_property(line, "default_color", bright, 0.6).set_ease(Tween.EASE_IN_OUT)
	_war_border_tween.chain()
	for line in _war_border_lines:
		_war_border_tween.parallel().tween_property(line, "default_color", dim, 0.6).set_ease(Tween.EASE_IN_OUT)
	_war_border_tween.tween_callback(_pulse_war_borders)


# --- Edge Blending ---

func _build_edge_blending() -> void:
	## Draw overlapping semi-transparent Line2D strips between regions with
	## different terrain types.  Creates a soft transition effect.
	var blend_container := Node2D.new()
	blend_container.z_index = 2
	add_child(blend_container)

	var drawn: Dictionary = {}
	var default_tint := Color(0.45, 0.45, 0.40)

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
			if not adj or region.terrain_type == adj.terrain_type:
				continue

			var shared := _find_shared_edge(region_id, adj_id)
			if shared.size() < 2:
				continue

			var color_a: Color = RegionVisual.TERRAIN_TINTS.get(region.terrain_type, default_tint)
			var color_b: Color = RegionVisual.TERRAIN_TINTS.get(adj.terrain_type, default_tint)

			# Draw blend layers in both directions (region's color bleeds into neighbor and vice versa)
			for layer in Constants.EDGE_BLEND_LAYERS:
				var w: float = Constants.EDGE_BLEND_BASE_WIDTH + float(layer) * Constants.EDGE_BLEND_WIDTH_STEP
				var a: float = Constants.EDGE_BLEND_BASE_ALPHA - float(layer) * Constants.EDGE_BLEND_ALPHA_DECAY

				# Color A bleeds toward B
				var line_a := Line2D.new()
				line_a.points = shared
				line_a.width = w
				line_a.default_color = Color(color_a.r, color_a.g, color_a.b, a)
				line_a.antialiased = true
				blend_container.add_child(line_a)

				# Color B bleeds toward A
				var line_b := Line2D.new()
				line_b.points = shared
				line_b.width = w
				line_b.default_color = Color(color_b.r, color_b.g, color_b.b, a)
				line_b.antialiased = true
				blend_container.add_child(line_b)


# --- Map Edge Vignette ---

func _build_vignette() -> void:
	## Add dark gradient around map edges for atmospheric depth.
	## 8 quads: 4 edge bands + 4 corners with vertex colors.
	var vignette := Node2D.new()
	vignette.z_index = 20
	add_child(vignette)

	# Map center and bounds
	var cx := 412.0
	var cy := 420.0
	var inner_hw := 1100.0
	var inner_hh := 900.0
	var outer_hw := 1800.0
	var outer_hh := 1400.0

	# Inner rectangle corners (transparent)
	var it := Vector2(cx - inner_hw, cy - inner_hh)  # top-left
	var irt := Vector2(cx + inner_hw, cy - inner_hh)  # top-right
	var irb := Vector2(cx + inner_hw, cy + inner_hh)  # bottom-right
	var ib := Vector2(cx - inner_hw, cy + inner_hh)  # bottom-left

	# Outer rectangle corners (dark)
	var ot := Vector2(cx - outer_hw, cy - outer_hh)
	var ort := Vector2(cx + outer_hw, cy - outer_hh)
	var orb := Vector2(cx + outer_hw, cy + outer_hh)
	var ob := Vector2(cx - outer_hw, cy + outer_hh)

	var dark := Color(0.02, 0.02, 0.04, 0.50)
	var clear := Color(0.02, 0.02, 0.04, 0.0)

	# Top edge
	_vignette_quad(vignette, ot, ort, irt, it, [dark, dark, clear, clear])
	# Bottom edge
	_vignette_quad(vignette, ib, irb, orb, ob, [clear, clear, dark, dark])
	# Left edge
	_vignette_quad(vignette, ot, it, ib, ob, [dark, clear, clear, dark])
	# Right edge
	_vignette_quad(vignette, irt, ort, orb, irb, [clear, dark, dark, clear])

	# Corners (all dark on outer 2, clear on inner 1, mid on edges)
	var mid := Color(0.02, 0.02, 0.04, 0.35)
	# Top-left corner
	_vignette_quad(vignette, ot, Vector2(it.x, ot.y), it, Vector2(ot.x, it.y), [dark, mid, clear, mid])
	# Top-right corner
	_vignette_quad(vignette, Vector2(irt.x, ort.y), ort, Vector2(ort.x, irt.y), irt, [mid, dark, mid, clear])
	# Bottom-right corner
	_vignette_quad(vignette, irb, Vector2(orb.x, irb.y), orb, Vector2(irb.x, orb.y), [clear, mid, dark, mid])
	# Bottom-left corner
	_vignette_quad(vignette, Vector2(ob.x, ib.y), ib, Vector2(ib.x, ob.y), ob, [mid, clear, mid, dark])


func _vignette_quad(
	parent: Node2D,
	a: Vector2, b: Vector2, c: Vector2, d: Vector2,
	colors: Array,
) -> void:
	## Create a single vertex-colored quad for vignette gradient.
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([a, b, c, d])
	poly.vertex_colors = PackedColorArray([colors[0], colors[1], colors[2], colors[3]])
	parent.add_child(poly)


# --- Ocean Shimmer (B-5) ---

func _start_ocean_shimmer() -> void:
	if not _ocean_shallow:
		return
	_pulse_ocean_shimmer()


func _pulse_ocean_shimmer() -> void:
	if not _ocean_shallow:
		return
	if _ocean_shimmer_tween:
		_ocean_shimmer_tween.kill()
	var base := OCEAN_COLOR
	var bright := Color(base.r + 0.02, base.g + 0.02, base.b + 0.03)
	_ocean_shimmer_tween = create_tween()
	_ocean_shimmer_tween.tween_property(_ocean_shallow, "color", bright, 3.0).set_ease(Tween.EASE_IN_OUT)
	_ocean_shimmer_tween.tween_property(_ocean_shallow, "color", base, 3.0).set_ease(Tween.EASE_IN_OUT)
	_ocean_shimmer_tween.tween_callback(_pulse_ocean_shimmer)


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
