class_name HexCellData
extends Resource

## Data resource for a single hex cell.

@export var q: int = 0
@export var r: int = 0
@export var elevation: float = 0.0
@export var water_level: float = 0.0
@export var flow_accum: float = 0.0
@export var basin_id: int = -1
@export var river_id: int = -1
@export var floodplain_level: float = 0.0
@export var moisture: float = 0.0
@export var terrain_type: Enums.TerrainType = Enums.TerrainType.PLAINS
@export var biome_id: int = 0

@export var has_river: bool = false
@export var river_out_dir: int = -1  # 0..5 (axial directions), -1 = none

@export var owner_id: int = -1
@export var population: int = 0
@export var town_level: int = 0  # 0 none, 1 hamlet, 2 town, 3 city

func axial_key() -> Vector2i:
	return Vector2i(q, r)
