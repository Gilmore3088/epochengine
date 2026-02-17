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
	var base_share := region.food_yield / town_count
	return base_share + town.get_food_bonus()


static func get_town_production_output(town: TownData, region: RegionData) -> int:
	## A town's production output: share of region base yield + building bonuses.
	var town_count := maxi(region.towns.size(), 1)
	var base_share := region.production_yield / town_count
	return base_share + town.get_production_bonus()


static func aggregate_region_food(region: RegionData) -> int:
	## Total food from all towns in a region. Used by economy pipeline.
	if region.towns.is_empty():
		return 0
	var total := 0
	for town in region.towns:
		total += get_town_food_output(town, region)
	return total


static func aggregate_region_production(region: RegionData) -> int:
	## Total production from all towns in a region.
	if region.towns.is_empty():
		return 0
	var total := 0
	for town in region.towns:
		total += get_town_production_output(town, region)
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


static func aggregate_region_maintenance(region: RegionData) -> int:
	## Total building maintenance cost for all towns.
	var total := 0
	for town in region.towns:
		total += town.get_maintenance_cost()
	return total


static func _create_town(region: RegionData, civ: CivilizationData) -> TownData:
	## Create a new TownData with auto-assigned ID and random name.
	var town_id := GameState.next_town_id
	GameState.next_town_id += 1

	var name_index := (town_id * 7 + region.id * 13) % Constants.TOWN_NAME_POOL.size()
	var town_name: String = Constants.TOWN_NAME_POOL[name_index]

	var town := TownData.new(town_id, town_name, region.id)
	town.founded_year = GameState.current_year
	return town
