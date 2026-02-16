class_name PopulationSimulation
extends RefCounted

## Pure simulation logic for population growth.
## Formula from docs/systems/simulation_math.md


static func calculate_growth(region: RegionData, civ: CivilizationData) -> int:
	## Returns the new population for a region after one year of growth.
	var base_rate := _get_base_growth_rate(region)
	var food_mod := _get_food_modifier(civ)
	var stability_mod := _get_stability_modifier(civ)
	var variance := randf_range(
		Constants.RANDOM_VARIANCE_MIN, Constants.RANDOM_VARIANCE_MAX
	)

	# Modifiers only affect the growth RATE, not the base population
	var effective_rate := base_rate * food_mod * stability_mod * variance

	# Golden age gives a modest growth bonus
	if civ.is_in_golden_age():
		effective_rate *= 1.5

	# Carrying capacity: growth slows as region approaches food-based limit
	var capacity := (region.food_yield + region.infrastructure_level) * Constants.FOOD_PER_POP_DIVISOR
	if capacity > 0 and region.population > 0:
		var capacity_ratio := clampf(1.0 - float(region.population) / float(capacity), -1.0, 1.0)
		effective_rate *= maxf(capacity_ratio, -0.05)  # Cap decline at 5% per year

	var new_pop := int(region.population * (1.0 + effective_rate))
	return maxi(new_pop, 0)


static func _get_base_growth_rate(region: RegionData) -> float:
	## Higher for fertile terrain, lower for harsh terrain.
	match region.terrain_type:
		Enums.TerrainType.RIVER_BASIN:
			return Constants.BASE_GROWTH_RATE_MAX
		Enums.TerrainType.PLAINS, Enums.TerrainType.COASTLINE:
			return lerp(Constants.BASE_GROWTH_RATE_MIN, Constants.BASE_GROWTH_RATE_MAX, 0.5)
		Enums.TerrainType.JUNGLE:
			return lerp(Constants.BASE_GROWTH_RATE_MIN, Constants.BASE_GROWTH_RATE_MAX, 0.4)
		_:
			return Constants.BASE_GROWTH_RATE_MIN


static func _get_food_modifier(civ: CivilizationData) -> float:
	## Based on food surplus/deficit. Famine when stockpile is deeply negative.
	if civ.total_population == 0:
		return 1.0

	var food_per_capita := float(civ.food_stockpile) / float(civ.total_population)

	if food_per_capita > 0.01:
		return clampf(1.0 + food_per_capita * 2.0, 1.0, Constants.FOOD_MODIFIER_MAX)
	elif food_per_capita < -0.005:
		return clampf(1.0 + food_per_capita * 5.0, Constants.FOOD_MODIFIER_MIN, 1.0)
	else:
		return 1.0


static func _get_stability_modifier(civ: CivilizationData) -> float:
	## Stability 0-100 maps to modifier 0.7-1.2.
	var t := civ.stability / Constants.STABILITY_MAX
	return lerpf(Constants.STABILITY_MODIFIER_MIN, Constants.STABILITY_MODIFIER_MAX, t)
