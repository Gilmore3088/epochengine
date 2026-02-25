class_name UnitData
extends Resource

## A movable unit on the map: Worker, Leader, or Explorer.

@export var id: int = -1
@export var unit_name: String = ""
@export var unit_type: int = 0  # Enums.UnitType
@export var owner_civ_id: int = -1
@export var region_id: int = -1
@export var target_region_id: int = -1  # -1 = idle/no move queued
@export var created_year: int = 0
@export var leader_trait_a: int = -1  # Leader only: index into Constants.LEADER_TRAITS
@export var leader_trait_b: int = -1  # Leader only: second trait slot
@export var turns_in_transit: int = 0


func _init(
	p_id: int = -1,
	p_name: String = "",
	p_type: int = 0,
	p_owner: int = -1,
	p_region: int = -1,
) -> void:
	id = p_id
	unit_name = p_name
	unit_type = p_type
	owner_civ_id = p_owner
	region_id = p_region


func is_idle() -> bool:
	return target_region_id == -1


func is_worker() -> bool:
	return unit_type == Enums.UnitType.WORKER


func is_leader() -> bool:
	return unit_type == Enums.UnitType.LEADER


func is_explorer() -> bool:
	return unit_type == Enums.UnitType.EXPLORER


func to_dict() -> Dictionary:
	return {
		"id": id,
		"unit_name": unit_name,
		"unit_type": unit_type,
		"owner_civ_id": owner_civ_id,
		"region_id": region_id,
		"target_region_id": target_region_id,
		"created_year": created_year,
		"leader_trait_a": leader_trait_a,
		"leader_trait_b": leader_trait_b,
		"turns_in_transit": turns_in_transit,
	}


static func from_dict(data: Dictionary) -> UnitData:
	var unit := UnitData.new(
		data.get("id", -1),
		data.get("unit_name", ""),
		data.get("unit_type", 0),
		data.get("owner_civ_id", -1),
		data.get("region_id", -1),
	)
	unit.target_region_id = data.get("target_region_id", -1)
	unit.created_year = data.get("created_year", 0)
	unit.leader_trait_a = data.get("leader_trait_a", -1)
	unit.leader_trait_b = data.get("leader_trait_b", -1)
	unit.turns_in_transit = data.get("turns_in_transit", 0)
	return unit
