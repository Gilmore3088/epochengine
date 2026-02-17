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
			"found_town":
				events.append_array(_execute_found_town(civ, action))
			"construct_building":
				events.append_array(_execute_construct_building(civ, action))
			"set_workforce_preset":
				events.append_array(_execute_set_workforce_preset(civ, action))
			"set_research_focus":
				events.append_array(_execute_set_research_focus(civ, action))
			"set_spending_priority":
				events.append_array(_execute_set_spending_priority(civ, action))
			"claim_region":
				events.append_array(_execute_claim_region(civ, action))
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

	# Snapshot before upgrade
	var food_before := region.food_yield
	var prod_before := region.production_yield
	var def_before := region.defense_modifier
	var tier_before := region.development_tier

	if not EconomySimulation.try_upgrade_infrastructure(civ, region):
		return []

	# Compute deltas
	var food_delta := region.food_yield - food_before
	var prod_delta := region.production_yield - prod_before
	var def_delta := region.defense_modifier - def_before
	var tier_changed := region.development_tier != tier_before

	return [{
		"type": "infrastructure_upgrade",
		"civ_id": civ.id,
		"civ_name": civ.civ_name,
		"region_id": region.id,
		"region_name": region.region_name,
		"new_level": region.infrastructure_level,
		"food_delta": food_delta,
		"prod_delta": prod_delta,
		"def_delta": def_delta,
		"tier_changed": tier_changed,
		"next_tier_infra_needed": _infra_to_next_tier(region),
	}]


static func _infra_to_next_tier(region: RegionData) -> int:
	var next_tier: int = region.development_tier + 1
	if next_tier >= Constants.DEV_TIER_GATES.size():
		return -1
	var gate: Array = Constants.DEV_TIER_GATES[next_tier]
	return maxi(gate[0] - region.infrastructure_level, 0)


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


static func _execute_found_town(
	civ: CivilizationData, action: Dictionary
) -> Array[Dictionary]:
	var region_id: int = action.get("region_id", -1)
	var region := GameState.get_region(region_id)
	if not region or region.owner_id != civ.id:
		return []
	if not TownSimulation.can_found_town(region, civ):
		return []

	var town: TownData = TownSimulation.found_town(region, civ)
	if not town:
		return []

	return [{
		"type": "town_founded",
		"civ_id": civ.id,
		"civ_name": civ.civ_name,
		"region_id": region.id,
		"region_name": region.region_name,
		"town_name": town.town_name,
	}]


static func _execute_construct_building(
	civ: CivilizationData, action: Dictionary
) -> Array[Dictionary]:
	var region_id: int = action.get("region_id", -1)
	var town_index: int = action.get("town_index", 0)
	var building_type: int = action.get("building_type", 0)

	var region := GameState.get_region(region_id)
	if not region or region.owner_id != civ.id:
		return []
	if town_index < 0 or town_index >= region.towns.size():
		return []

	var town: TownData = region.towns[town_index]
	if not TownSimulation.construct_building(town, building_type, civ):
		return []

	var bname: String = Constants.BUILDING_NAMES.get(building_type, "Building")
	return [{
		"type": "building_constructed",
		"civ_id": civ.id,
		"civ_name": civ.civ_name,
		"region_id": region.id,
		"region_name": region.region_name,
		"town_name": town.town_name,
		"building_name": bname,
	}]


static func _execute_set_workforce_preset(
	civ: CivilizationData, action: Dictionary
) -> Array[Dictionary]:
	var region_id: int = action.get("region_id", -1)
	var town_index: int = action.get("town_index", 0)
	var preset: int = action.get("preset", 0)

	var region := GameState.get_region(region_id)
	if not region or region.owner_id != civ.id:
		return []
	if town_index < 0 or town_index >= region.towns.size():
		return []
	if not Constants.WORKFORCE_PRESETS.has(preset):
		return []

	var town: TownData = region.towns[town_index]

	# Non-Balanced presets require a Town Hall
	if preset != 0 and town.get_building_count(Enums.BuildingType.TOWN_HALL) == 0:
		return []

	town.workforce_preset = preset
	var preset_name: String = Constants.WORKFORCE_PRESETS[preset]["name"]
	return [{
		"type": "workforce_preset_changed",
		"civ_id": civ.id,
		"civ_name": civ.civ_name,
		"region_id": region.id,
		"region_name": region.region_name,
		"town_name": town.town_name,
		"preset_name": preset_name,
	}]


static func _execute_set_research_focus(
	civ: CivilizationData, action: Dictionary
) -> Array[Dictionary]:
	var focus: int = action.get("focus", 0)
	if not Constants.RESEARCH_FOCUS_NAMES.has(focus):
		return []
	if civ.research_focus_cooldown > 0:
		return []
	var old_focus := civ.research_focus
	civ.research_focus = focus
	if focus != old_focus:
		civ.research_focus_cooldown = Constants.RESEARCH_FOCUS_COOLDOWN_YEARS
	var focus_name: String = Constants.RESEARCH_FOCUS_NAMES[focus]
	return [{
		"type": "research_focus_changed",
		"civ_id": civ.id,
		"civ_name": civ.civ_name,
		"focus": focus,
		"focus_name": focus_name,
	}]


static func _execute_set_spending_priority(
	civ: CivilizationData, action: Dictionary
) -> Array[Dictionary]:
	var priority: int = action.get("priority", 0)
	if not Constants.SPENDING_PRIORITIES.has(priority):
		return []
	if civ.spending_priority_cooldown > 0:
		return []
	var old_priority := civ.spending_priority
	civ.spending_priority = priority
	if priority != old_priority:
		civ.spending_priority_cooldown = Constants.SPENDING_PRIORITY_COOLDOWN_YEARS
	var priority_name: String = Constants.SPENDING_PRIORITY_NAMES[priority]
	return [{
		"type": "spending_priority_changed",
		"civ_id": civ.id,
		"civ_name": civ.civ_name,
		"priority": priority,
		"priority_name": priority_name,
	}]


static func _execute_claim_region(
	civ: CivilizationData, action: Dictionary
) -> Array[Dictionary]:
	## Claim an adjacent neutral region. Mirrors AI expansion logic.
	var region_id: int = action.get("region_id", -1)
	var region := GameState.get_region(region_id)
	if not region or not region.is_neutral():
		return []

	var owned := GameState.get_regions_by_owner(civ.id)
	var region_count := owned.size()
	if not EconomySimulation.can_afford_expansion(civ, region_count):
		return []

	# Find best adjacent owned region as settler source (highest population)
	var source_region: RegionData = null
	var best_pop := 0
	for r in owned:
		if region.adjacency_list.has(r.id) and r.population > best_pop:
			source_region = r
			best_pop = r.population
	if not source_region:
		return []

	var cost := EconomySimulation.pay_expansion_cost(civ, region_count, source_region)
	region.owner_id = civ.id
	region.population = maxi(region.population, Constants.EXPANSION_SETTLER_POP)

	# Refresh visibility so newly adjacent regions become visible immediately
	GameState.update_visibility(civ.id)

	return [{
		"type": "expansion",
		"civ_id": civ.id,
		"civ_name": civ.civ_name,
		"region_id": region.id,
		"region_name": region.region_name,
		"source_region_name": source_region.region_name,
		"cost": cost,
	}]
