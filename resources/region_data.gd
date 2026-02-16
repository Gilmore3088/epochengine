class_name RegionData
extends Resource

## Data resource for a single map region.

@export var id: int = -1
@export var region_name: String = ""
@export var terrain_type: Enums.TerrainType = Enums.TerrainType.PLAINS
@export var population: int = 0
@export var owner_id: int = -1  # -1 = neutral
@export var food_yield: int = 3
@export var production_yield: int = 3
@export var defense_modifier: float = 1.0
@export var resource_stock: Dictionary = {}  # {"coal": 100, "oil": 50}
@export var adjacency_list: Array[int] = []
@export var infrastructure_level: int = 0  # 0-5


func _init(
	p_id: int = -1,
	p_name: String = "",
	p_terrain: Enums.TerrainType = Enums.TerrainType.PLAINS,
) -> void:
	id = p_id
	region_name = p_name
	terrain_type = p_terrain
	_apply_terrain_defaults()


func _apply_terrain_defaults() -> void:
	match terrain_type:
		Enums.TerrainType.RIVER_BASIN:
			food_yield = Constants.YIELD_RIVER_BASIN.x
			production_yield = Constants.YIELD_RIVER_BASIN.y
			defense_modifier = Constants.DEFENSE_RIVER_BASIN
		Enums.TerrainType.PLAINS:
			food_yield = Constants.YIELD_PLAINS.x
			production_yield = Constants.YIELD_PLAINS.y
			defense_modifier = Constants.DEFENSE_PLAINS
		Enums.TerrainType.MOUNTAINS:
			food_yield = Constants.YIELD_MOUNTAINS.x
			production_yield = Constants.YIELD_MOUNTAINS.y
			defense_modifier = Constants.DEFENSE_MOUNTAINS
		Enums.TerrainType.DESERT:
			food_yield = Constants.YIELD_DESERT.x
			production_yield = Constants.YIELD_DESERT.y
			defense_modifier = Constants.DEFENSE_DESERT
		Enums.TerrainType.JUNGLE:
			food_yield = Constants.YIELD_JUNGLE.x
			production_yield = Constants.YIELD_JUNGLE.y
			defense_modifier = Constants.DEFENSE_JUNGLE
		Enums.TerrainType.COASTLINE:
			food_yield = Constants.YIELD_COASTLINE.x
			production_yield = Constants.YIELD_COASTLINE.y
			defense_modifier = Constants.DEFENSE_COASTLINE
		Enums.TerrainType.TUNDRA:
			food_yield = Constants.YIELD_TUNDRA.x
			production_yield = Constants.YIELD_TUNDRA.y
			defense_modifier = Constants.DEFENSE_TUNDRA


func is_neutral() -> bool:
	return owner_id == -1


func is_connected_to_capital(regions: Dictionary, civ_capital_id: int) -> bool:
	## BFS to check if this region connects to the capital through owned territory.
	if id == civ_capital_id:
		return true

	var visited: Dictionary = {}
	var queue: Array[int] = [id]
	visited[id] = true

	while not queue.is_empty():
		var current_id: int = queue.pop_front()
		for neighbor_id in adjacency_list if current_id == id else regions[current_id].adjacency_list:
			if visited.has(neighbor_id):
				continue
			if neighbor_id == civ_capital_id:
				return true
			if regions.has(neighbor_id) and regions[neighbor_id].owner_id == owner_id:
				visited[neighbor_id] = true
				queue.append(neighbor_id)

	return false
