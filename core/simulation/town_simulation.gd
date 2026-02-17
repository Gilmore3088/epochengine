class_name TownSimulation
extends RefCounted

## Pure simulation logic for town management.
## Handles town founding, building construction, cost formulas,
## and town-level economy aggregation.


static func auto_spawn_initial_town(region: RegionData, civ: CivilizationData) -> TownData:
	## Spawn the first town in a newly owned region if population is sufficient.
	## Called when a region is first claimed (expansion) or at game start.
	if not region.towns.is_empty():
		return null
	if region.population < Constants.TOWN_AUTO_SPAWN_POP:
		return null

	var town := _create_town(region, civ)
	@warning_ignore("integer_division")
	town.population = mini(region.population / 2, region.population - 100)
	region.towns.append(town)
	return town


static func can_found_town(region: RegionData, civ: CivilizationData) -> bool:
	## Check if a new town can be founded in this region.
	if region.owner_id != civ.id:
		return false
	if region.population < Constants.TOWN_MIN_POP_TO_FOUND:
		return false
	var cost := calculate_town_cost(region)
	return civ.production_stockpile >= cost


static func found_town(region: RegionData, civ: CivilizationData) -> TownData:
	## Found a new town: deduct cost, move pop, return TownData.
	var cost := calculate_town_cost(region)
	civ.production_stockpile -= cost

	var town := _create_town(region, civ)
	town.population = Constants.TOWN_STARTING_POP

	# Move settlers from region's largest town or from region pop directly
	if not region.towns.is_empty():
		var largest: TownData = region.towns[0]
		for t in region.towns:
			if t.population > largest.population:
				largest = t
		largest.population = maxi(largest.population - Constants.TOWN_STARTING_POP, 100)
	else:
		region.population = maxi(region.population - Constants.TOWN_STARTING_POP, 100)

	region.towns.append(town)
	return town


static func calculate_town_cost(region: RegionData) -> int:
	## Soft-cap cost: escalates with existing towns, cheaper in larger regions.
	var existing := region.towns.size()
	var size_mod := maxf(region.size_factor, 0.1)
	return ceili(
		Constants.TOWN_BASE_COST
		* pow(1.0 + float(existing), Constants.TOWN_COST_EXPONENT)
		/ size_mod
	)


static func can_construct_building(
	town: TownData, building_type: int, civ: CivilizationData
) -> bool:
	var cost := calculate_building_cost(town, building_type)
	return civ.production_stockpile >= cost


static func construct_building(
	town: TownData, building_type: int, civ: CivilizationData
) -> bool:
	## Build a building in a town. Returns true if successful.
	var cost := calculate_building_cost(town, building_type)
	if civ.production_stockpile < cost:
		return false
	civ.production_stockpile -= cost
	town.add_building(building_type)
	return true


static func calculate_building_cost(town: TownData, building_type: int) -> int:
	## Escalating cost: more of the same type = more expensive.
	var existing := town.get_building_count(building_type)
	return ceili(
		Constants.BUILDING_BASE_COST
		* pow(Constants.BUILDING_COST_ESCALATION, float(existing))
	)


static func get_town_food_output(town: TownData, region: RegionData) -> int:
	## A town's food output: share of region base yield + building bonuses.
	var town_count := maxi(region.towns.size(), 1)
	@warning_ignore("integer_division")
	var base_share := region.food_yield / town_count
	return base_share + town.get_food_bonus()


static func get_town_production_output(town: TownData, region: RegionData) -> int:
	## A town's production output: share of region base yield + building bonuses.
	var town_count := maxi(region.towns.size(), 1)
	@warning_ignore("integer_division")
	var base_share := region.production_yield / town_count
	return base_share + town.get_production_bonus()


static func compute_town_outputs(town: TownData, region: RegionData) -> Dictionary:
	## Compute full output breakdown for a single town. Used by UI panels.
	var town_count := maxi(region.towns.size(), 1)
	@warning_ignore("integer_division")
	var base_food := region.food_yield / town_count
	@warning_ignore("integer_division")
	var base_prod := region.production_yield / town_count
	var bldg_food := town.get_food_bonus()
	var bldg_prod := town.get_production_bonus()
	var bldg_mil := town.get_military_bonus()
	var bldg_stab := town.get_stability_bonus()
	var bldg_def := town.get_defense_bonus()
	var bldg_tech := _get_town_tech_bonus(town)
	var upkeep := town.get_maintenance_cost()
	var supply_eff := clampf(region.supply_value, 0.0, 1.0)

	# Workforce preset multipliers (require Town Hall for non-Balanced)
	var wf: Dictionary = Constants.WORKFORCE_PRESETS.get(town.workforce_preset, Constants.WORKFORCE_PRESETS[0])
	var has_town_hall: bool = town.get_building_count(Enums.BuildingType.TOWN_HALL) > 0
	var wf_food: float = wf["food"] if has_town_hall else 1.0
	var wf_prod: float = wf["production"] if has_town_hall else 1.0
	var wf_mil: float = wf["military"] if has_town_hall else 1.0
	var wf_stab: float = wf["stability"] if has_town_hall else 1.0
	var wf_tech: float = wf["tech"] if has_town_hall else 1.0

	var raw_food := base_food + bldg_food
	var raw_prod := base_prod + bldg_prod
	return {
		"base_food": base_food, "base_prod": base_prod,
		"bldg_food": bldg_food, "bldg_prod": bldg_prod,
		"bldg_mil": bldg_mil, "bldg_stab": bldg_stab,
		"bldg_def": bldg_def, "bldg_tech": bldg_tech,
		"supply_efficiency": supply_eff,
		"workforce_preset": town.workforce_preset,
		"has_town_hall": has_town_hall,
		"total_food": int(float(raw_food) * supply_eff * wf_food),
		"total_prod": int(float(raw_prod) * supply_eff * wf_prod),
		"total_mil": bldg_mil * supply_eff * wf_mil,
		"total_stab": bldg_stab * wf_stab,
		"total_def": bldg_def,    # structural, not scaled
		"total_tech": bldg_tech * supply_eff * wf_tech,
		"upkeep": upkeep,
		"net_prod": int(float(raw_prod) * supply_eff * wf_prod) - upkeep,
	}


static func _get_town_tech_bonus(town: TownData) -> float:
	## Tech bonus from buildings via BUILDING_RULES.
	var bonus := 0.0
	for entry in town.buildings:
		var btype: int = entry.get("type", -1)
		var count: int = entry.get("count", 0)
		if Constants.BUILDING_RULES.has(btype):
			bonus += float(count) * float(Constants.BUILDING_RULES[btype]["outputs"]["tech"])
	return bonus


static func aggregate_region_food(region: RegionData) -> int:
	## Total food from all towns, including workforce multipliers and supply.
	if region.towns.is_empty():
		return 0
	var total := 0
	for town in region.towns:
		var outputs := compute_town_outputs(town, region)
		total += outputs["total_food"]
	return total


static func aggregate_region_production(region: RegionData) -> int:
	## Total production from all towns, including workforce multipliers and supply.
	if region.towns.is_empty():
		return 0
	var total := 0
	for town in region.towns:
		var outputs := compute_town_outputs(town, region)
		total += outputs["total_prod"]
	return total


static func aggregate_region_defense_bonus(region: RegionData) -> float:
	## Total defense bonus from all town buildings in a region.
	var total := 0.0
	for town in region.towns:
		total += town.get_defense_bonus()
	return total


static func aggregate_region_stability_bonus(region: RegionData) -> float:
	## Total stability bonus from town buildings.
	var total := 0.0
	for town in region.towns:
		total += town.get_stability_bonus()
	return total


static func compute_region_deficit_info(region: RegionData) -> Dictionary:
	## Check how many towns have production deficit (upkeep > supply-scaled output).
	var deficit_towns := 0
	var total_deficit := 0
	for town in region.towns:
		var outputs := compute_town_outputs(town, region)
		if outputs["net_prod"] < 0:
			deficit_towns += 1
			total_deficit += absi(outputs["net_prod"])
	return {
		"deficit_towns": deficit_towns,
		"total_deficit": total_deficit,
		"has_deficit": deficit_towns > 0,
	}


static func aggregate_region_maintenance(region: RegionData) -> int:
	## Total building maintenance cost for all towns.
	var total := 0
	for town in region.towns:
		total += town.get_maintenance_cost()
	return total


static func compute_urban_gravity(town: TownData, region: RegionData) -> float:
	## Urban gravity score: higher for populous, well-connected, trading towns.
	var trade_flux := Constants.URBAN_GRAVITY_DEFAULT_TRADE_FLUX
	if town.get_building_count(Enums.BuildingType.MARKET) > 0:
		trade_flux += 0.1 * float(town.get_building_count(Enums.BuildingType.MARKET))
	return float(town.population) * (1.0 + float(region.infrastructure_level) * Constants.URBAN_GRAVITY_INFRA_FACTOR) * (1.0 + trade_flux * Constants.URBAN_GRAVITY_TRADE_FACTOR)


static func compute_town_hints(town: TownData, region: RegionData, civ: CivilizationData) -> Array[String]:
	## Context-aware progression suggestions for a town.
	var hints: Array[String] = []
	if town.get_building_count(Enums.BuildingType.TOWN_HALL) == 0:
		hints.append("Build a Town Hall to unlock workforce management")
	var outputs := compute_town_outputs(town, region)
	if outputs["total_food"] < 2:
		hints.append("Low food output - build a Granary (+2 food)")
	if outputs["net_prod"] < 0:
		hints.append("Production deficit! Build Workshop or reduce buildings")
	if outputs["supply_efficiency"] < 0.5:
		hints.append("Poor supply route - output reduced by %d%%" % int((1.0 - outputs["supply_efficiency"]) * 100))
	if civ.stability < 40.0 and town.get_building_count(Enums.BuildingType.MONUMENT) == 0:
		hints.append("Low stability - build a Monument (+3 stab)")
	if civ.is_at_war() and town.get_building_count(Enums.BuildingType.BARRACKS) == 0:
		hints.append("At war! Build Barracks for military strength")
	var next_tier: int = region.development_tier + 1
	if next_tier < Constants.DEV_TIER_GATES.size():
		var gate: Array = Constants.DEV_TIER_GATES[next_tier]
		if region.infrastructure_level < gate[0]:
			hints.append("Region needs Infra %d for next tier (have %d)" % [gate[0], region.infrastructure_level])
	return hints


static func _create_town(region: RegionData, _civ: CivilizationData) -> TownData:
	## Create a new TownData with auto-assigned ID and random name.
	var town_id := GameState.next_town_id
	GameState.next_town_id += 1

	var name_index := (town_id * 7 + region.id * 13) % Constants.TOWN_NAME_POOL.size()
	var town_name: String = Constants.TOWN_NAME_POOL[name_index]

	var town := TownData.new(town_id, town_name, region.id)
	town.founded_year = GameState.current_year
	return town
