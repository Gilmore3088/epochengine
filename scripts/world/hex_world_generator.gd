class_name HexWorldGenerator
extends RefCounted

const MAP_COUNTS := {
	Enums.MapSize.SMALL: 120,
	Enums.MapSize.MEDIUM: 240,
	Enums.MapSize.LARGE: 420,
}

const GRID_PADDING := 5
const RIVER_FLOW_MIN := 6.0
const RIVER_FLOW_MAX := 18.0

static func generate(map_config: MapConfig) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	var seed = map_config.seed
	if seed == 0:
		seed = randi()
	rng.seed = seed

	var land_target: int = MAP_COUNTS.get(map_config.map_size, 240)
	var land_radius: int = int(ceil(sqrt(float(land_target) / 3.0))) + 1
	var grid_radius: int = land_radius + GRID_PADDING

	HexMetrics.set_size(80.0)

	var coords: Array[Vector2i] = _build_hex_disk(grid_radius)
	var elev_noise = FastNoiseLite.new()
	elev_noise.seed = seed * 131 + 17
	elev_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	elev_noise.frequency = 0.08

	var moist_noise = FastNoiseLite.new()
	moist_noise.seed = seed * 193 + 71
	moist_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	moist_noise.frequency = 0.07

	var score_map: Dictionary = {}
	var elev_map: Dictionary = {}
	var moist_map: Dictionary = {}

	for coord in coords:
		var e: float = elev_noise.get_noise_2d(float(coord.x), float(coord.y)) * 0.5 + 0.5
		var m: float = moist_noise.get_noise_2d(float(coord.x), float(coord.y)) * 0.5 + 0.5
		var dist: float = float(HexMetrics.axial_distance(coord, Vector2i.ZERO)) / float(grid_radius)
		var mask: float = clampf(1.0 - pow(dist, 1.7), 0.0, 1.0)
		var score: float = e * 0.75 + mask * 0.85 + rng.randf_range(-0.03, 0.03)

		score_map[coord] = score
		elev_map[coord] = e
		moist_map[coord] = m

	var sorted_coords: Array = coords.duplicate()
	sorted_coords.sort_custom(func(a, b):
		return score_map[a] > score_map[b]
	)

	var land_seed: Dictionary = {}
	for i in range(mini(land_target, sorted_coords.size())):
		var c: Vector2i = sorted_coords[i]
		land_seed[c] = true

	var land_set: Dictionary = _largest_component(land_seed)
	_expand_contiguous_land(land_set, sorted_coords, score_map, land_target)

	# Trim if we somehow overshot (should be rare, but keep safe)
	if land_set.size() > land_target:
		var land_list: Array = land_set.keys()
		land_list.sort_custom(func(a, b):
			return score_map[a] > score_map[b]
		)
		land_set.clear()
		for i in range(land_target):
			land_set[land_list[i]] = true

	# Coastline detection
	var coast_set: Dictionary = {}
	for coord in land_set.keys():
		if _touches_ocean(coord, land_set):
			coast_set[coord] = true

	# Hydrology
	var hydro: Dictionary = _compute_hydrology(land_set, elev_map)
	var flow_accum: Dictionary = hydro["flow_accum"]
	var river_paths: Array = hydro["river_paths"]
	var downslope: Dictionary = hydro["downslope"]

	var river_threshold: float = clampf(float(land_target) / 60.0, RIVER_FLOW_MIN, RIVER_FLOW_MAX)

	var river_conn: Dictionary = {}
	var river_order: Dictionary = {}
	var basin_id_map: Dictionary = {}
	var has_lake: Dictionary = {}

	for path_i in range(river_paths.size()):
		var path: Array = river_paths[path_i]
		var order := 1
		for idx in range(path.size()):
			var coord: Vector2i = path[idx]
			var next_idx := idx + 1
			river_order[coord] = maxi(river_order.get(coord, 0), order)
			basin_id_map[coord] = path_i
			if next_idx < path.size():
				var next_coord: Vector2i = path[next_idx]
				if not river_conn.has(coord):
					river_conn[coord] = []
				if not river_conn.has(next_coord):
					river_conn[next_coord] = []
				if not (next_coord in river_conn[coord]):
					river_conn[coord].append(next_coord)
				if not (coord in river_conn[next_coord]):
					river_conn[next_coord].append(coord)
			order += 1

	for coord in land_set.keys():
		if downslope.get(coord, null) == null and not coast_set.has(coord):
			has_lake[coord] = true

	# Build RegionData
	var regions: Dictionary = {}
	var hex_coords: Dictionary = {}
	var land_coords: Array[Vector2i] = []
	var name_pool: Array[String] = _load_region_name_pool()

	var coord_list: Array = land_set.keys()
	coord_list.sort_custom(func(a, b):
		return a.x == b.x and a.y < b.y or a.x < b.x
	)

	for idx in range(coord_list.size()):
		var coord: Vector2i = coord_list[idx]
		var region_id: int = idx
		var name: String = _pick_region_name(idx, name_pool, rng)
		var elevation: float = elev_map[coord]
		var moisture: float = moist_map[coord]

		var terrain: int = _pick_terrain(coord, elevation, moisture, coast_set.has(coord))
		if flow_accum.get(coord, 0.0) >= river_threshold and terrain != Enums.TerrainType.MOUNTAINS and terrain != Enums.TerrainType.DESERT and not coast_set.has(coord):
			terrain = Enums.TerrainType.RIVER_BASIN

		var region: RegionData = RegionData.new(region_id, name, terrain)
		region.population = _base_population(terrain, rng)
		region.owner_id = -1
		region.elevation = _quantize_elevation(elevation)
		region.moisture = moisture
		region.flow_accum = flow_accum.get(coord, 0.0)
		region.basin_id = basin_id_map.get(coord, -1)
		region.has_river = river_conn.has(coord)
		region.river_order = river_order.get(coord, 0)
		region.has_lake = has_lake.has(coord)

		regions[region_id] = region
		hex_coords[region_id] = coord
		land_coords.append(coord)

	# Build adjacency and river connections in region-id space
	var coord_to_id: Dictionary = {}
	for region_id in hex_coords:
		coord_to_id[hex_coords[region_id]] = region_id

	for region_id in regions:
		var region: RegionData = regions[region_id]
		var coord: Vector2i = hex_coords[region_id]
		region.adjacency_list.clear()
		for dir in HexMetrics.neighbor_directions():
			var nk := coord + dir
			if coord_to_id.has(nk):
				region.adjacency_list.append(coord_to_id[nk])

		if river_conn.has(coord):
			for rc in river_conn[coord]:
				if coord_to_id.has(rc):
					region.river_connections.append(coord_to_id[rc])

	var capital_ids: Array[int] = pick_starting_capitals(regions, hex_coords, map_config)

	return {
		"regions": regions,
		"hex_coords": hex_coords,
		"land_coords": land_coords,
		"capital_ids": capital_ids,
	}


static func pick_starting_capitals(regions: Dictionary, hex_coords: Dictionary, map_config: MapConfig) -> Array[int]:
	var rng = RandomNumberGenerator.new()
	var seed = map_config.seed
	if seed == 0:
		seed = randi()
	rng.seed = seed + 9991

	var candidates: Array[int] = []
	for region in regions.values():
		if region.terrain_type == Enums.TerrainType.MOUNTAINS or region.terrain_type == Enums.TerrainType.DESERT:
			continue
		var score: int = region.food_yield + region.production_yield
		if region.has_river:
			score += 3
		if region.terrain_type == Enums.TerrainType.RIVER_BASIN:
			score += 2
		if score >= 6:
			candidates.append(region.id)

	if candidates.is_empty():
		for key in regions.keys():
			candidates.append(int(key))

	var starts: Array[int] = []
	var first: int = candidates[rng.randi_range(0, candidates.size() - 1)]
	starts.append(first)

	while starts.size() < 3 and starts.size() < candidates.size():
		var best_id: int = -1
		var best_dist: int = -1
		for cid in candidates:
			if cid in starts:
				continue
			var min_dist: int = 9999
			for sid in starts:
				var d: int = HexMetrics.axial_distance(hex_coords[cid], hex_coords[sid])
				min_dist = mini(min_dist, d)
			if min_dist > best_dist:
				best_dist = min_dist
				best_id = cid
		if best_id >= 0:
			starts.append(best_id)
		else:
			break

	return starts


static func _build_hex_disk(radius: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for q in range(-radius, radius + 1):
		var r1: int = maxi(-radius, -q - radius)
		var r2: int = mini(radius, -q + radius)
		for r in range(r1, r2 + 1):
			cells.append(Vector2i(q, r))
	return cells


static func _expand_contiguous_land(
	land_set: Dictionary,
	sorted_coords: Array,
	score_map: Dictionary,
	land_target: int
) -> void:
	## Expand land only via adjacency to keep a single connected landmass.
	if land_set.size() >= land_target:
		return

	var frontier: Dictionary = {}
	for coord in land_set.keys():
		var c: Vector2i = coord
		for dir in HexMetrics.neighbor_directions():
			var n: Vector2i = c + dir
			if land_set.has(n) or frontier.has(n):
				continue
			if score_map.has(n):
				frontier[n] = true

	while land_set.size() < land_target:
		if frontier.is_empty():
			break
		var best_coord: Vector2i = frontier.keys()[0]
		var best_score: float = float(score_map.get(best_coord, -INF))
		for coord in frontier.keys():
			var c: Vector2i = coord
			var s: float = float(score_map.get(c, -INF))
			if s > best_score:
				best_score = s
				best_coord = c
		frontier.erase(best_coord)
		land_set[best_coord] = true

		for dir in HexMetrics.neighbor_directions():
			var n: Vector2i = best_coord + dir
			if land_set.has(n) or frontier.has(n):
				continue
			if score_map.has(n):
				frontier[n] = true

	# Fallback: if still short, add nearest-scoring neighbors until target
	if land_set.size() < land_target:
		for coord in sorted_coords:
			if land_set.size() >= land_target:
				break
			if land_set.has(coord):
				continue
			if _touches_land(coord, land_set):
				land_set[coord] = true


static func _largest_component(seed_set: Dictionary) -> Dictionary:
	var visited: Dictionary = {}
	var best: Dictionary = {}
	for coord in seed_set.keys():
		if visited.has(coord):
			continue
		var queue: Array[Vector2i] = [coord]
		visited[coord] = true
		var comp: Dictionary = {}
		while not queue.is_empty():
			var c: Vector2i = queue.pop_front()
			comp[c] = true
			for dir in HexMetrics.neighbor_directions():
				var n := c + dir
				if seed_set.has(n) and not visited.has(n):
					visited[n] = true
					queue.append(n)
		if comp.size() > best.size():
			best = comp
	return best


static func _touches_land(coord: Vector2i, land_set: Dictionary) -> bool:
	for dir in HexMetrics.neighbor_directions():
		if land_set.has(coord + dir):
			return true
	return false


static func _touches_ocean(coord: Vector2i, land_set: Dictionary) -> bool:
	for dir in HexMetrics.neighbor_directions():
		if not land_set.has(coord + dir):
			return true
	return false


static func _compute_hydrology(land_set: Dictionary, elev_map: Dictionary) -> Dictionary:
	var downslope: Dictionary = {}
	for coord in land_set.keys():
		var best = _lowest_neighbor(coord, land_set, elev_map)
		if best != null:
			downslope[coord] = best

	var sorted: Array = land_set.keys()
	sorted.sort_custom(func(a, b):
		return elev_map[a] > elev_map[b]
	)

	var flow_accum: Dictionary = {}
	for coord in sorted:
		flow_accum[coord] = 1.0
	for coord in sorted:
		if downslope.has(coord):
			var down: Vector2i = downslope[coord]
			flow_accum[down] = flow_accum.get(down, 0.0) + flow_accum[coord]

	var upstream_count: Dictionary = {}
	for coord in land_set.keys():
		upstream_count[coord] = 0
	for coord in downslope.keys():
		var down: Vector2i = downslope[coord]
		upstream_count[down] = upstream_count.get(down, 0) + 1

	var river_paths: Array = []
	for coord in land_set.keys():
		if flow_accum.get(coord, 0.0) < RIVER_FLOW_MIN:
			continue
		if upstream_count.get(coord, 0) > 0:
			continue
		var path: Array = []
		var current: Vector2i = coord
		var visited: Dictionary = {}
		for _step in range(120):
			if visited.has(current):
				break
			visited[current] = true
			path.append(current)
			if not downslope.has(current):
				break
			current = downslope[current]
		if path.size() >= 3:
			river_paths.append(path)

	return {
		"flow_accum": flow_accum,
		"river_paths": river_paths,
		"downslope": downslope,
	}


static func _lowest_neighbor(coord: Vector2i, land_set: Dictionary, elev_map: Dictionary):
	var best = null
	var best_e: float = elev_map[coord]
	for dir in HexMetrics.neighbor_directions():
		var nk := coord + dir
		if not land_set.has(nk):
			continue
		var e: float = elev_map[nk]
		if e < best_e:
			best_e = e
			best = nk
	return best


static func _quantize_elevation(e: float) -> int:
	if e > 0.75:
		return 3
	if e > 0.60:
		return 2
	if e > 0.45:
		return 1
	return 0


static func _pick_terrain(coord: Vector2i, elev: float, moist: float, is_coast: bool) -> int:
	if is_coast:
		return Enums.TerrainType.COASTLINE
	if elev > 0.78:
		return Enums.TerrainType.MOUNTAINS
	var lat: float = absf(float(coord.y)) / 30.0
	if lat > 0.9:
		return Enums.TerrainType.TUNDRA
	if moist < 0.22:
		return Enums.TerrainType.DESERT
	if moist < 0.35:
		return Enums.TerrainType.STEPPE
	if moist > 0.68 and elev < 0.55:
		return Enums.TerrainType.JUNGLE
	return Enums.TerrainType.PLAINS


static func _base_population(terrain: int, rng: RandomNumberGenerator) -> int:
	var base: int = 700
	match terrain:
		Enums.TerrainType.MOUNTAINS:
			base = 350
		Enums.TerrainType.DESERT:
			base = 300
		Enums.TerrainType.JUNGLE:
			base = 550
		Enums.TerrainType.RIVER_BASIN:
			base = 900
		Enums.TerrainType.COASTLINE:
			base = 750
		Enums.TerrainType.TUNDRA:
			base = 300
		_:
			base = 650
	return int(float(base) * rng.randf_range(0.85, 1.15))


static func _load_region_name_pool() -> Array[String]:
	var names: Array[String] = []
	var dir = DirAccess.open("res://data/regions/")
	if not dir:
		return names
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var region: RegionData = ResourceLoader.load("res://data/regions/" + file_name, "", ResourceLoader.CACHE_MODE_IGNORE)
			if region:
				names.append(region.region_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	return names


static func _pick_region_name(index: int, pool: Array[String], rng: RandomNumberGenerator) -> String:
	if index < pool.size():
		return pool[index]
	var syll_start: Array[String] = ["Mar", "Bel", "Kor", "Val", "Dor", "Fen", "Ash", "Il", "Nor", "Tar", "Cal"]
	var syll_mid: Array[String] = ["an", "en", "or", "ur", "il", "av", "em", "un", "ar", "os", "ir"]
	var syll_end: Array[String] = ["dor", "mar", "hold", "vale", "reach", "watch", "ford", "crest", "moor", "gate"]
	return syll_start[rng.randi_range(0, syll_start.size() - 1)] \
		+ syll_mid[rng.randi_range(0, syll_mid.size() - 1)] \
		+ " " + syll_end[rng.randi_range(0, syll_end.size() - 1)]
