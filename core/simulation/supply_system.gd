class_name SupplySystem
extends RefCounted

## Dijkstra-based supply routing from capital through owned territory.
## Computes supply_value (0.0 to 1.0) for every region owned by a civ.
## Called once per civ per turn; results cached on RegionData.supply_value.


static func calculate_supply_map(
	civ: CivilizationData, owned_regions: Array[RegionData],
) -> void:
	## Compute supply values for all owned regions using Dijkstra from capital.
	## Writes results directly to region.supply_value.
	if owned_regions.is_empty():
		return

	# Build lookup of owned region IDs for fast access
	var owned_ids: Dictionary = {}  # {region_id: RegionData}
	for region in owned_regions:
		owned_ids[region.id] = region

	# Capital gets full supply
	var capital_id := civ.capital_region_id
	if capital_id < 0 or not owned_ids.has(capital_id):
		# No valid capital - all regions get zero supply
		for region in owned_regions:
			region.supply_value = 0.0
		return

	# Dijkstra shortest-path from capital
	var costs: Dictionary = {}  # {region_id: float} - cumulative cost from capital
	var visited: Dictionary = {}
	costs[capital_id] = 0.0

	# Priority queue: [[cost, region_id], ...] - sorted by cost ascending
	var queue: Array = [[0.0, capital_id]]

	while not queue.is_empty():
		# Pop lowest cost (linear scan - fine for 116 regions)
		var min_idx := 0
		for i in range(1, queue.size()):
			if queue[i][0] < queue[min_idx][0]:
				min_idx = i
		var current: Array = queue[min_idx]
		queue.remove_at(min_idx)

		var current_cost: float = current[0]
		var current_id: int = current[1]

		if visited.has(current_id):
			continue
		visited[current_id] = true

		var current_region: RegionData = owned_ids[current_id]

		# Explore neighbors
		for adj_id in current_region.adjacency_list:
			if visited.has(adj_id):
				continue
			if not owned_ids.has(adj_id):
				continue

			var adj_region: RegionData = owned_ids[adj_id]
			var edge_cost := _compute_edge_cost(adj_region, civ)
			var total_cost := current_cost + edge_cost

			if total_cost < costs.get(adj_id, INF):
				costs[adj_id] = total_cost
				queue.append([total_cost, adj_id])

	# Convert cumulative costs to supply values and write to regions
	for region in owned_regions:
		if costs.has(region.id):
			var cost: float = costs[region.id]
			region.supply_value = maxf(0.0, 1.0 - cost * Constants.SUPPLY_DECAY_PER_HOP)
		else:
			# Unreachable from capital
			region.supply_value = 0.0


static func _compute_edge_cost(
	target_region: RegionData, civ: CivilizationData,
) -> float:
	## Compute the supply cost to traverse into target_region.
	## Lower throughput = higher cost. Infrastructure reduces cost.
	## Enemy adjacency adds interdiction penalty.
	var terrain_key: int = target_region.terrain_type
	var throughput: float = Constants.TERRAIN_SUPPLY_THROUGHPUT.get(terrain_key, 0.5)
	var base_cost := 1.0 / throughput

	# Infrastructure bonus: each level reduces cost by 10%
	var infra_reduction := target_region.infrastructure_level * Constants.SUPPLY_INFRASTRUCTURE_BONUS_PER_LEVEL
	base_cost *= maxf(0.3, 1.0 - infra_reduction)  # cap at 70% reduction

	# Enemy interdiction: adjacent enemy-at-war regions disrupt supply
	if not civ.war_targets.is_empty():
		var interdicted := _is_interdicted(target_region, civ)
		if interdicted:
			base_cost += Constants.SUPPLY_INTERDICTION_PENALTY

	return base_cost


static func _is_interdicted(region: RegionData, civ: CivilizationData) -> bool:
	## Check if any adjacent region is owned by a civ we're at war with.
	for adj_id in region.adjacency_list:
		var adj: RegionData = GameState.regions.get(adj_id)
		if adj and adj.owner_id >= 0 and adj.owner_id != civ.id:
			if civ.war_targets.has(adj.owner_id):
				return true
	return false


static func get_best_adjacent_supply(region: RegionData, civ_id: int) -> float:
	## Returns the highest supply_value among adjacent regions owned by civ_id.
	## Used for combat: attackers get supply from their best adjacent region.
	var best := 0.0
	for adj_id in region.adjacency_list:
		var adj: RegionData = GameState.regions.get(adj_id)
		if adj and adj.owner_id == civ_id:
			best = maxf(best, adj.supply_value)
	return best
