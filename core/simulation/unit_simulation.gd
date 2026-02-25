class_name UnitSimulation
extends RefCounted

## Pure simulation logic for unit movement, worker checks, explorer reveals,
## and leader bonuses. No signals, no UI - just data.


static func process_unit_movement(events: Dictionary) -> void:
	## Process all units with a pending move. Called once per turn.
	## Owned territory: instant. Neutral/foreign: 1 turn delay.
	for unit in GameState.units.values():
		if unit.target_region_id == -1:
			continue

		var from_region := GameState.get_region(unit.region_id)
		var to_region := GameState.get_region(unit.target_region_id)
		if not from_region or not to_region:
			unit.target_region_id = -1
			unit.turns_in_transit = 0
			continue

		# Adjacency check
		if unit.target_region_id not in from_region.adjacency_list:
			unit.target_region_id = -1
			unit.turns_in_transit = 0
			continue

		# Owned territory = instant move
		if to_region.owner_id == unit.owner_civ_id:
			_execute_move(unit, from_region, to_region, events)
		else:
			# Neutral/foreign: 1 turn delay
			if unit.turns_in_transit >= 1:
				_execute_move(unit, from_region, to_region, events)
			else:
				unit.turns_in_transit += 1


static func _execute_move(
	unit: UnitData, from_region: RegionData, to_region: RegionData,
	events: Dictionary,
) -> void:
	var old_region_id := unit.region_id
	unit.region_id = to_region.id
	unit.target_region_id = -1
	unit.turns_in_transit = 0

	events["unit_events"].append({
		"type": "unit_moved",
		"unit_id": unit.id,
		"unit_name": unit.unit_name,
		"unit_type": unit.unit_type,
		"civ_id": unit.owner_civ_id,
		"from_region_id": old_region_id,
		"from_region_name": from_region.region_name,
		"to_region_id": to_region.id,
		"to_region_name": to_region.region_name,
	})

	# Explorers reveal fog when they move
	if unit.is_explorer():
		_explorer_reveal(unit)


static func _explorer_reveal(unit: UnitData) -> void:
	## Mark explorer's region + adjacent as explored for owner civ.
	var civ := GameState.get_civilization(unit.owner_civ_id)
	if not civ:
		return
	var region := GameState.get_region(unit.region_id)
	if not region:
		return

	# Mark current region explored
	if not civ.explored_set.has(region.id):
		civ.explored_regions.append(region.id)
		civ.explored_set[region.id] = true

	# Mark adjacent regions explored
	for neighbor_id in region.adjacency_list:
		if not civ.explored_set.has(neighbor_id):
			civ.explored_regions.append(neighbor_id)
			civ.explored_set[neighbor_id] = true


static func get_leader_bonus(civ_id: int) -> Dictionary:
	## Find the living leader unit for a civ and return its trait bonuses.
	## Returns {"production": 0.0, "military": 0.0, "stability": 0.0,
	##          "tech": 0.0, "food": 0.0}
	var bonus := {
		"production": 0.0, "military": 0.0, "stability": 0.0,
		"tech": 0.0, "food": 0.0,
	}

	for unit in GameState.units.values():
		if unit.owner_civ_id == civ_id and unit.is_leader():
			_apply_trait(bonus, unit.leader_trait_a)
			_apply_trait(bonus, unit.leader_trait_b)
			break  # Only one leader per civ

	return bonus


static func _apply_trait(bonus: Dictionary, trait_id: int) -> void:
	if trait_id < 0:
		return
	var trait_data: Dictionary = Constants.LEADER_TRAITS.get(trait_id, {})
	if trait_data.is_empty():
		return
	var btype: String = trait_data["bonus_type"]
	var bvalue: float = trait_data["bonus_value"]
	bonus[btype] = bonus.get(btype, 0.0) + bvalue


static func has_idle_worker_in_region(region_id: int, civ_id: int) -> bool:
	## Check if a civ has an idle worker in the given region.
	## AI civs always return true (virtual workers in V0.1).
	if not GameState.is_player_civ(civ_id):
		return true

	for unit in GameState.units.values():
		if (unit.owner_civ_id == civ_id
			and unit.is_worker()
			and unit.region_id == region_id
			and unit.is_idle()):
			return true

	return false


static func can_train_unit(
	unit_type: int, region_id: int, civ_id: int
) -> Dictionary:
	## Check if a unit can be trained at the given region.
	## Returns {"can_train": bool, "reason": String, "cost": int}
	var civ := GameState.get_civilization(civ_id)
	if not civ:
		return {"can_train": false, "reason": "No civilization", "cost": 0}

	var region := GameState.get_region(region_id)
	if not region:
		return {"can_train": false, "reason": "No region", "cost": 0}

	if region.owner_id != civ_id:
		return {"can_train": false, "reason": "Not your region", "cost": 0}

	var cost := 0
	var required_building := -1

	match unit_type:
		Enums.UnitType.WORKER:
			cost = Constants.WORKER_TRAIN_COST
			required_building = Enums.BuildingType.WORKSHOP
		Enums.UnitType.EXPLORER:
			cost = Constants.EXPLORER_TRAIN_COST
			required_building = Enums.BuildingType.BARRACKS
		Enums.UnitType.LEADER:
			return {"can_train": false, "reason": "Leaders cannot be trained", "cost": 0}

	# Check building requirement
	if required_building >= 0:
		var has_building := false
		for town in region.towns:
			if town.get_building_count(required_building) > 0:
				has_building = true
				break
		if not has_building:
			var bname: String = Enums.BuildingType.keys()[required_building]
			return {"can_train": false, "reason": "Requires " + bname.capitalize(), "cost": cost}

	# Check cost
	if civ.production_stockpile < cost:
		return {"can_train": false, "reason": "Need %d prod (have %d)" % [cost, civ.production_stockpile], "cost": cost}

	return {"can_train": true, "reason": "", "cost": cost}


static func train_unit(
	unit_type: int, region_id: int, civ_id: int
) -> UnitData:
	## Train a new unit. Deducts cost, creates UnitData, adds to GameState.
	## Returns null if training fails.
	var check := can_train_unit(unit_type, region_id, civ_id)
	if not check["can_train"]:
		return null

	var civ := GameState.get_civilization(civ_id)
	civ.production_stockpile -= check["cost"]

	# Pick a name from the pool
	var name_pool: Array
	match unit_type:
		Enums.UnitType.WORKER:
			name_pool = Constants.WORKER_NAME_POOL
		Enums.UnitType.EXPLORER:
			name_pool = Constants.EXPLORER_NAME_POOL
		_:
			name_pool = ["Unit"]

	var name_index := (GameState.next_unit_id * 7 + region_id * 3) % name_pool.size()
	var unit_name: String = name_pool[name_index]

	var unit := UnitData.new(
		-1, unit_name, unit_type, civ_id, region_id
	)
	unit.created_year = GameState.current_year
	GameState.add_unit(unit)

	return unit
