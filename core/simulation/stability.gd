class_name StabilitySimulation
extends RefCounted

## Pure simulation logic for stability recalculation.
## Formula from docs/systems/simulation_math.md


static func recalculate(civ: CivilizationData, owned_regions: Array[RegionData]) -> float:
	## Returns the new stability value for a civilization.
	var base := civ.stability

	var food_factor := _food_surplus_factor(civ)
	var war_exhaust := _war_exhaustion(civ)
	var shortage := _resource_shortage_penalty(civ, owned_regions)
	var hero_mod := _hero_modifier(civ)
	var overextension := _overextension_penalty(owned_regions.size())
	var disconnected := _disconnected_territory_penalty(civ, owned_regions)
	var political := randf_range(
		Constants.RANDOM_POLITICAL_SHIFT_MIN,
		Constants.RANDOM_POLITICAL_SHIFT_MAX,
	)

	# Mean-reversion: gently pull stability toward equilibrium
	var mean_reversion := (
		(Constants.STABILITY_EQUILIBRIUM - base)
		* Constants.STABILITY_MEAN_REVERSION_RATE
	)

	# Golden age provides a stability floor
	var golden_floor := 0.0
	if civ.is_in_golden_age():
		golden_floor = Constants.GOLDEN_AGE_STABILITY_FLOOR

	var new_stability := (
		base + food_factor - war_exhaust - shortage
		+ hero_mod - overextension - disconnected + political
		+ mean_reversion
	)
	new_stability = clampf(new_stability, Constants.STABILITY_MIN, Constants.STABILITY_MAX)
	new_stability = maxf(new_stability, golden_floor)

	return new_stability


static func check_collapse(civ: CivilizationData) -> bool:
	## Returns true if the civilization should collapse this year.
	if civ.stability < Constants.COLLAPSE_STABILITY_THRESHOLD:
		civ.consecutive_low_stability_years += 1
	else:
		civ.consecutive_low_stability_years = 0

	return civ.consecutive_low_stability_years >= Constants.COLLAPSE_CONSECUTIVE_YEARS


static func _food_surplus_factor(civ: CivilizationData) -> float:
	## Positive when food surplus, negative when deficit.
	## Stockpile of +50 gives +2.5, stockpile of -50 gives -2.5.
	return clampf(float(civ.food_stockpile) / 20.0, -5.0, 5.0)


static func _war_exhaustion(civ: CivilizationData) -> float:
	## Each active war front costs 2-5 stability per year.
	if civ.war_targets.is_empty():
		return 0.0

	var exhaustion := 0.0
	for _target in civ.war_targets:
		exhaustion += randf_range(
			Constants.WAR_EXHAUSTION_PER_FRONT_MIN,
			Constants.WAR_EXHAUSTION_PER_FRONT_MAX,
		)
	return exhaustion


static func _resource_shortage_penalty(
	civ: CivilizationData, owned_regions: Array[RegionData]
) -> float:
	## Penalty when food or production stockpiles are significantly negative.
	## Only kicks in below -20 to avoid punishing minor deficits.
	var penalty := 0.0
	var deficit_threshold := -20

	if civ.food_stockpile < deficit_threshold:
		var severity := float(-civ.food_stockpile - (-deficit_threshold)) / 80.0
		penalty += lerpf(
			Constants.RESOURCE_SHORTAGE_PENALTY_MIN,
			Constants.RESOURCE_SHORTAGE_PENALTY_MAX,
			clampf(severity, 0.0, 1.0),
		)

	if civ.production_stockpile < deficit_threshold:
		var severity := float(-civ.production_stockpile - (-deficit_threshold)) / 80.0
		penalty += lerpf(
			Constants.RESOURCE_SHORTAGE_PENALTY_MIN,
			Constants.RESOURCE_SHORTAGE_PENALTY_MAX,
			clampf(severity, 0.0, 1.0),
		)

	return penalty


static func _hero_modifier(civ: CivilizationData) -> float:
	## Reformer heroes add stability directly.
	var bonus := 0.0
	for hero_id in civ.hero_ids:
		var hero: HeroData = GameState.get_hero(hero_id)
		if hero and hero.type == Enums.HeroType.REFORMER:
			bonus += hero.get_modifier_value()
	return bonus


static func _overextension_penalty(region_count: int) -> float:
	## Stability drain when controlling too many regions.
	## Kicks in above OVEREXTENSION_REGION_THRESHOLD.
	var excess := maxi(region_count - Constants.OVEREXTENSION_REGION_THRESHOLD, 0)
	return float(excess) * Constants.OVEREXTENSION_STABILITY_PER_REGION


static func _disconnected_territory_penalty(
	civ: CivilizationData, owned_regions: Array[RegionData]
) -> float:
	## Stability drain for regions not connected to the capital via owned territory.
	if civ.capital_region_id < 0:
		return 0.0

	var disconnected_count := 0
	for region in owned_regions:
		if region.id == civ.capital_region_id:
			continue
		if not region.is_connected_to_capital(GameState.regions, civ.capital_region_id):
			disconnected_count += 1

	return float(disconnected_count) * Constants.DISCONNECTED_TERRITORY_PENALTY
