class_name EconomySimulation
extends RefCounted

## Pure simulation logic for the economy loop.
## Handles food/production yields, consumption, surplus/deficit, and infrastructure.


static func calculate_food_production(
	civ: CivilizationData, owned_regions: Array[RegionData]
) -> int:
	## Total food produced by all owned regions this year.
	var total := 0
	for region in owned_regions:
		var food := region.food_yield + region.infrastructure_level

		# Visionary hero bonus (applies to production but not food)
		# Food is unmodified by heroes

		# Golden age bonus
		if civ.is_in_golden_age():
			food = int(food * (1.0 + Constants.GOLDEN_AGE_FOOD_BONUS))

		total += food
	return total


static func calculate_production_output(
	civ: CivilizationData, owned_regions: Array[RegionData]
) -> int:
	## Total production from all owned regions this year.
	var total := 0
	for region in owned_regions:
		var prod := region.production_yield + region.infrastructure_level

		# Visionary hero bonus
		var hero_bonus := 1.0
		for hero_id in civ.hero_ids:
			var hero: HeroData = GameState.get_hero(hero_id)
			if hero and hero.type == Enums.HeroType.VISIONARY:
				hero_bonus += hero.get_modifier_value()
		prod = int(prod * hero_bonus)

		# Golden age bonus
		if civ.is_in_golden_age():
			prod = int(prod * (1.0 + Constants.GOLDEN_AGE_PRODUCTION_BONUS))

		total += prod
	return total


static func calculate_food_consumption(civ: CivilizationData) -> int:
	## Food consumed by population. 1 food per FOOD_PER_POP_DIVISOR population.
	return civ.total_population / Constants.FOOD_PER_POP_DIVISOR


static func calculate_military_upkeep(civ: CivilizationData) -> int:
	## Production consumed to maintain military forces.
	return int(civ.military_strength / Constants.MILITARY_UPKEEP_DIVISOR)


static func process_economy(civ: CivilizationData, owned_regions: Array[RegionData]) -> Dictionary:
	## Run the full economy tick for one civilization.
	## Returns a result dictionary with all computed values for logging/signals.
	var food_produced := calculate_food_production(civ, owned_regions)
	var food_consumed := calculate_food_consumption(civ)
	var food_net := food_produced - food_consumed

	var prod_produced := calculate_production_output(civ, owned_regions)
	var military_upkeep := calculate_military_upkeep(civ)
	var prod_net := prod_produced - military_upkeep

	# Apply to stockpiles
	var old_food := civ.food_stockpile
	var old_prod := civ.production_stockpile
	var old_military := civ.military_strength

	civ.food_stockpile += food_net
	civ.production_stockpile += prod_net

	# Military replenishment from remaining production surplus
	var reinforcement := 0.0
	if civ.production_stockpile > 0:
		reinforcement = minf(
			float(civ.production_stockpile) * Constants.MILITARY_REINFORCE_RATE,
			Constants.MILITARY_REINFORCE_MAX,
		)
		civ.military_strength += reinforcement

	# Detect shortages
	var food_shortage := civ.food_stockpile < Constants.SHORTAGE_THRESHOLD
	var prod_shortage := civ.production_stockpile < Constants.SHORTAGE_THRESHOLD

	return {
		"food_produced": food_produced,
		"food_consumed": food_consumed,
		"food_net": food_net,
		"prod_produced": prod_produced,
		"military_upkeep": military_upkeep,
		"prod_net": prod_net,
		"reinforcement": reinforcement,
		"food_shortage": food_shortage,
		"prod_shortage": prod_shortage,
		"old_food": old_food,
		"old_prod": old_prod,
		"old_military": old_military,
	}


static func calculate_expansion_cost(civ: CivilizationData, region_count: int) -> int:
	## Production cost to expand into a new region.
	## Escalates with number of owned regions (snowball control).
	var base_cost := Constants.EXPANSION_BASE_PRODUCTION_COST
	var excess := maxi(region_count - Constants.OVEREXTENSION_REGION_THRESHOLD, 0)
	return base_cost + excess * Constants.EXPANSION_COST_ESCALATION


static func can_afford_expansion(civ: CivilizationData, region_count: int) -> bool:
	## Check if a civilization can afford to expand.
	var cost := calculate_expansion_cost(civ, region_count)
	return civ.production_stockpile >= cost and civ.total_population >= Constants.EXPANSION_SETTLER_POP


static func pay_expansion_cost(
	civ: CivilizationData, region_count: int, source_region: RegionData
) -> int:
	## Deduct expansion costs. Returns production spent.
	var cost := calculate_expansion_cost(civ, region_count)
	civ.production_stockpile -= cost

	# Move settlers from source region
	var settlers := mini(source_region.population / 4, Constants.EXPANSION_SETTLER_POP)
	source_region.population -= settlers

	return cost


static func try_upgrade_infrastructure(
	civ: CivilizationData, region: RegionData
) -> bool:
	## Attempt to upgrade a region's infrastructure if affordable.
	if region.infrastructure_level >= Constants.INFRASTRUCTURE_MAX_LEVEL:
		return false
	var cost := Constants.INFRASTRUCTURE_UPGRADE_COST * (region.infrastructure_level + 1)
	if civ.production_stockpile < cost:
		return false
	civ.production_stockpile -= cost
	region.infrastructure_level += 1
	return true
