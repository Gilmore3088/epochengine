class_name RiverGenerator
extends RefCounted

## Procedural river and lake generator.
## Runs once at map build. Assigns elevation, generates river systems
## flowing from high-elevation regions downhill toward coastlines,
## and places lakes in low-elevation interior regions.

const RIVER_SYSTEM_COUNT := 4
const LAKE_COUNT := 3


static func generate(regions: Dictionary, seed_value: int) -> void:
	## Main entry: assign elevations, generate rivers, place lakes.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	_assign_elevations(regions)
	_generate_river_systems(regions, rng)
	_place_lakes(regions, rng)


static func _assign_elevations(regions: Dictionary) -> void:
	## Set elevation by terrain type.
	for region in regions.values():
		var terrain_key: int = region.terrain_type
		region.elevation = Constants.ELEVATION_BY_TERRAIN.get(terrain_key, 0)


static func _generate_river_systems(regions: Dictionary, rng: RandomNumberGenerator) -> void:
	## Generate river systems flowing from mountains/high terrain toward coast.
	## All RIVER_BASIN regions automatically get has_river = true.

	# Mark all river basins as having rivers
	for region in regions.values():
		if region.terrain_type == Enums.TerrainType.RIVER_BASIN:
			region.has_river = true

	# Find starting points (high-elevation regions)
	var high_regions: Array[int] = []
	for region in regions.values():
		if region.elevation >= 2:
			high_regions.append(region.id)

	if high_regions.is_empty():
		return

	# Generate river systems
	for _sys in RIVER_SYSTEM_COUNT:
		var start_id: int = high_regions[rng.randi_range(0, high_regions.size() - 1)]
		_flow_river(regions, start_id, rng)


static func _flow_river(regions: Dictionary, start_id: int, rng: RandomNumberGenerator) -> void:
	## Flow a river from start_id downhill toward coast/lowland.
	var current_id := start_id
	var visited: Dictionary = {}
	var max_steps := 15
	var hop := 0

	for _step in max_steps:
		if visited.has(current_id):
			break
		visited[current_id] = true

		var region: RegionData = regions.get(current_id)
		if not region:
			break
		region.has_river = true
		hop += 1
		# River order: higher = further downstream (wider river)
		region.river_order = maxi(region.river_order, hop)

		# Stop at coastline
		if region.terrain_type == Enums.TerrainType.COASTLINE:
			break

		# Find lowest-elevation neighbor (prefer unvisited, break ties with RNG)
		var best_id := -1
		var best_elev := 999
		for neighbor_id in region.adjacency_list:
			if visited.has(neighbor_id):
				continue
			var neighbor: RegionData = regions.get(neighbor_id)
			if not neighbor:
				continue
			if neighbor.elevation < best_elev or (neighbor.elevation == best_elev and rng.randf() < 0.4):
				best_elev = neighbor.elevation
				best_id = neighbor_id

		if best_id < 0:
			break

		# Connect river between current and next
		region.river_connections.append(best_id)
		var next_region: RegionData = regions.get(best_id)
		if next_region:
			next_region.river_connections.append(current_id)

		current_id = best_id


static func _place_lakes(regions: Dictionary, rng: RandomNumberGenerator) -> void:
	## Place lakes in low-elevation interior (non-coastal) regions.
	var candidates: Array[int] = []
	for region in regions.values():
		if region.elevation <= 1 and region.terrain_type != Enums.TerrainType.COASTLINE \
				and region.terrain_type != Enums.TerrainType.DESERT \
				and not region.has_lake:
			candidates.append(region.id)

	var placed := 0
	while placed < LAKE_COUNT and not candidates.is_empty():
		var idx := rng.randi_range(0, candidates.size() - 1)
		var region_id: int = candidates[idx]
		candidates.remove_at(idx)

		var region: RegionData = regions.get(region_id)
		if region:
			region.has_lake = true
			region.has_river = true  # lakes feed rivers
			placed += 1
