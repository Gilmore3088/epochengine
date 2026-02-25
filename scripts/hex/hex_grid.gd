class_name HexGrid
extends Node2D

## Builds a hex grid and renders it using HexCellVisual nodes.

@export var width: int = 32
@export var height: int = 22
@export var cell_radius: float = 18.0
@export var seed: int = 42
@export var sea_level: float = 0.35
@export var era: int = 0

var cells: Dictionary = {}  # Vector2i -> HexCellData
var visuals: Dictionary = {}  # Vector2i -> HexCellVisual
var river_paths: Array[Array[Vector2i]] = []
var _cell_container: Node2D
var _river_layer: Node2D
const RIVER_FLOW_THRESHOLD := 6.0

func _ready() -> void:
	HexMetrics.set_size(cell_radius)
	_build_grid()
	_compute_hydrology()
	_build_visuals()
	_build_river_lines()


func _build_grid() -> void:
	cells.clear()
	visuals.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var elev_noise := FastNoiseLite.new()
	elev_noise.seed = seed
	elev_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	elev_noise.frequency = 0.08

	var moist_noise := FastNoiseLite.new()
	moist_noise.seed = seed + 1337
	moist_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	moist_noise.frequency = 0.06

	for r in height:
		for q in width:
			var cell := HexCellData.new()
			cell.q = q
			cell.r = r
			var e := (elev_noise.get_noise_2d(float(q), float(r)) + 1.0) * 0.5
			var m := (moist_noise.get_noise_2d(float(q), float(r)) + 1.0) * 0.5
			cell.elevation = e
			cell.water_level = sea_level
			cell.moisture = m
			cell.terrain_type = _pick_terrain(e, m)
			cell.population = int(200 + m * 800)
			cell.town_level = _pick_town_level(cell.population)
			cells[cell.axial_key()] = cell


func _pick_terrain(e: float, m: float) -> Enums.TerrainType:
	if e < sea_level:
		return Enums.TerrainType.COASTLINE
	if e > 0.82:
		return Enums.TerrainType.MOUNTAINS
	if e > 0.72:
		return Enums.TerrainType.TUNDRA
	if m < 0.25:
		return Enums.TerrainType.DESERT
	if m > 0.75:
		return Enums.TerrainType.JUNGLE
	if m > 0.55:
		return Enums.TerrainType.RIVER_BASIN
	if m > 0.40:
		return Enums.TerrainType.PLAINS
	return Enums.TerrainType.STEPPE


func _pick_town_level(pop: int) -> int:
	if pop < 350:
		return 0
	if pop < 650:
		return 1
	if pop < 900:
		return 2
	return 3


func _build_visuals() -> void:
	if not _cell_container:
		_cell_container = Node2D.new()
		add_child(_cell_container)
	for child in _cell_container.get_children():
		child.queue_free()

	for key in cells:
		var cell: HexCellData = cells[key]
		var center := HexMetrics.axial_to_world(cell.q, cell.r)
		var pts := HexMetrics.corners()
		var local := PackedVector2Array()
		for p in pts:
			local.append(p)
		var vis := HexCellVisual.new()
		vis.position = center
		vis.initialize(cell, local, era)
		_cell_container.add_child(vis)
		visuals[key] = vis


func _compute_hydrology() -> void:
	river_paths.clear()

	# Determine downslope neighbor for each cell
	var downslope: Dictionary = {}
	for key in cells:
		var cell: HexCellData = cells[key]
		if cell.terrain_type == Enums.TerrainType.COASTLINE:
			continue
		var best := _lowest_neighbor(key)
		if best != null:
			downslope[key] = best

	# Initialize flow accumulation
	var sorted_keys: Array = cells.keys()
	sorted_keys.sort_custom(func(a, b):
		return cells[a].elevation > cells[b].elevation
	)
	for key in sorted_keys:
		cells[key].flow_accum = 1.0

	for key in sorted_keys:
		if downslope.has(key):
			var down: Vector2i = downslope[key]
			cells[down].flow_accum += cells[key].flow_accum

	# Build river paths from sources (high flow, no upstream)
	var upstream_count: Dictionary = {}
	for key in cells:
		upstream_count[key] = 0
	for key in downslope:
		var down: Vector2i = downslope[key]
		upstream_count[down] = upstream_count.get(down, 0) + 1

	for key in cells:
		var cell: HexCellData = cells[key]
		if cell.terrain_type == Enums.TerrainType.COASTLINE:
			continue
		if cell.flow_accum < RIVER_FLOW_THRESHOLD:
			continue
		if upstream_count.get(key, 0) > 0:
			continue
		var path := _flow_river_from(key, downslope)
		if path.size() >= 3:
			river_paths.append(path)


func _flow_river_from(start: Vector2i, downslope: Dictionary) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current := start
	var visited: Dictionary = {}
	for _step in range(80):
		if visited.has(current):
			break
		visited[current] = true
		path.append(current)
		var cell: HexCellData = cells[current]
		cell.has_river = true

		if cell.terrain_type == Enums.TerrainType.COASTLINE:
			break

		if not downslope.has(current):
			break
		var next: Vector2i = downslope[current]
		cell.river_out_dir = _dir_to(current, next)
		current = next

	return path


func _lowest_neighbor(key: Vector2i) -> Vector2i:
	var cell: HexCellData = cells[key]
	var dirs := HexMetrics.neighbor_directions()
	var best: Vector2i = Vector2i(0, 0)
	var has_best := false
	var best_e := cell.elevation
	for i in dirs.size():
		var nk := key + dirs[i]
		if not cells.has(nk):
			continue
		var n: HexCellData = cells[nk]
		if n.elevation <= best_e:
			best_e = n.elevation
			best = nk
			has_best = true
	if has_best and best != key:
		return best
	return null


func _dir_to(a: Vector2i, b: Vector2i) -> int:
	var dirs := HexMetrics.neighbor_directions()
	for i in dirs.size():
		if a + dirs[i] == b:
			return i
	return -1


func _build_river_lines() -> void:
	if _river_layer:
		_river_layer.queue_free()
	_river_layer = Node2D.new()
	_river_layer.z_index = 10
	add_child(_river_layer)

	for path in river_paths:
		var pts := PackedVector2Array()
		for key in path:
			var cell: HexCellData = cells[key]
			pts.append(HexMetrics.axial_to_world(cell.q, cell.r))

		if pts.size() < 2:
			continue

		# Glow
		var glow := Line2D.new()
		glow.points = pts
		glow.width = 6.0
		glow.default_color = Color(0.30, 0.75, 0.92, 0.35)
		glow.antialiased = true
		_river_layer.add_child(glow)

		# Core
		var core := Line2D.new()
		core.points = pts
		core.width = 3.0
		core.default_color = Color(0.08, 0.34, 0.70, 0.85)
		core.antialiased = true
		_river_layer.add_child(core)
