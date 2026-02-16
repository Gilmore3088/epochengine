class_name PlayerActions
extends RefCounted

## Processes queued player actions during the simulation pipeline.
## Same interface as AILogic: returns Array[Dictionary] of event dicts.
## Player actions execute without probability rolls (the player chose to do it).

static var _action_queue: Array[Dictionary] = []


static func queue_action(action: Dictionary) -> void:
	_action_queue.append(action)


static func has_queued_actions() -> bool:
	return not _action_queue.is_empty()


static func get_queue_size() -> int:
	return _action_queue.size()


static func clear_queue() -> void:
	_action_queue.clear()


static func process_queued_actions(civ: CivilizationData) -> Array[Dictionary]:
	## Execute all queued player actions. Returns event dicts matching AILogic format.
	var events: Array[Dictionary] = []
	for action in _action_queue:
		match action.get("type", ""):
			"declare_war":
				events.append_array(_execute_declare_war(civ, action))
			"seek_peace":
				events.append_array(_execute_seek_peace(civ, action))
			"invest_infrastructure":
				events.append_array(_execute_invest_infrastructure(civ, action))
			"seek_alliance":
				events.append_array(_execute_seek_alliance(civ, action))
	_action_queue.clear()
	return events


static func _execute_declare_war(
	civ: CivilizationData, action: Dictionary
) -> Array[Dictionary]:
	var target_id: int = action.get("target_civ_id", -1)
	var target := GameState.get_civilization(target_id)
	if not target or target.is_collapsed:
		return []
	if civ.war_targets.has(target_id):
		return []
	if civ.alliance_partners.has(target_id):
		civ.alliance_partners.erase(target_id)
		target.alliance_partners.erase(civ.id)

	civ.war_targets.append(target_id)
	target.war_targets.append(civ.id)
	civ.war_durations[target_id] = 0
	target.war_durations[civ.id] = 0

	return [{
		"type": "war_declared",
		"attacker_id": civ.id,
		"defender_id": target_id,
		"attacker_name": civ.civ_name,
		"defender_name": target.civ_name,
	}]


static func _execute_seek_peace(
	civ: CivilizationData, action: Dictionary
) -> Array[Dictionary]:
	var target_id: int = action.get("target_civ_id", -1)
	var target := GameState.get_civilization(target_id)
	if not target:
		return []
	if not civ.war_targets.has(target_id):
		return []

	civ.war_targets.erase(target_id)
	target.war_targets.erase(civ.id)
	civ.war_durations.erase(target_id)
	target.war_durations.erase(civ.id)
	civ.peace_cooldowns[target_id] = Constants.PEACE_COOLDOWN_YEARS
	target.peace_cooldowns[civ.id] = Constants.PEACE_COOLDOWN_YEARS

	return [{
		"type": "peace",
		"civ_a_id": civ.id,
		"civ_b_id": target_id,
		"civ_a_name": civ.civ_name,
		"civ_b_name": target.civ_name,
	}]


static func _execute_invest_infrastructure(
	civ: CivilizationData, action: Dictionary
) -> Array[Dictionary]:
	var region_id: int = action.get("region_id", -1)
	var region := GameState.get_region(region_id)
	if not region or region.owner_id != civ.id:
		return []

	if not EconomySimulation.try_upgrade_infrastructure(civ, region):
		return []

	return [{
		"type": "infrastructure_upgrade",
		"civ_id": civ.id,
		"civ_name": civ.civ_name,
		"region_id": region.id,
		"region_name": region.region_name,
		"new_level": region.infrastructure_level,
	}]


static func _execute_seek_alliance(
	civ: CivilizationData, action: Dictionary
) -> Array[Dictionary]:
	var target_id: int = action.get("target_civ_id", -1)
	var target := GameState.get_civilization(target_id)
	if not target or target.is_collapsed:
		return []
	if civ.alliance_partners.has(target_id):
		return []
	if civ.war_targets.has(target_id):
		return []

	civ.alliance_partners.append(target_id)
	target.alliance_partners.append(civ.id)

	return [{
		"type": "alliance_formed",
		"civ_a_id": civ.id,
		"civ_b_id": target_id,
		"civ_a_name": civ.civ_name,
		"civ_b_name": target.civ_name,
	}]
