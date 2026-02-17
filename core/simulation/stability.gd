class_name StabilitySimulation
extends RefCounted

## Pure simulation logic for stability recalculation.
## Formula from docs/systems/simulation_math.md


static func recalculate(civ: CivilizationData, owned_regions: Array[RegionData]) -> float:
	## Returns the new stability value for a civilization.
	var base := civ.stability
	var region_count := owned_regions.size()
	var is_compact := region_count <= Constants.COMPACT_STATE_THRESHOLD

	var food_factor := _food_surplus_factor(civ)
	var war_exhaust := _war_exhaustion(civ)
	if is_compact:
		war_exhaust *= (1.0 - Constants.COMPACT_WAR_EXHAUSTION_REDUCTION)
	var shortage := _resource_shortage_penalty(civ, owned_regions)
	var hero_mod := _hero_modifier(civ)
	var admin_cap := _admin_capacity(civ, owned_regions)
	var overextension := _overextension_penalty(region_count, admin_cap)
	var disconnected := _disconnected_territory_penalty(civ, owned_regions)
	var political := GameState.sim_rng.randf_range(
		Constants.RANDOM_POLITICAL_SHIFT_MIN,
		Constants.RANDOM_POLITICAL_SHIFT_MAX,
	)

	# Pressure-aware mean-reversion: recovery weakened under duress
	var recovery_rate := Constants.STABILITY_MEAN_REVERSION_RATE
	if not civ.war_targets.is_empty():
		recovery_rate *= 0.5
	if civ.food_stockpile < 0:
		recovery_rate *= 0.5
	if overextension > 0.0:
		recovery_rate *= 0.5

	var mean_reversion := (
		(Constants.STABILITY_EQUILIBRIUM - base) * recovery_rate
	)

	# Golden age provides a stability floor
	var golden_floor := 0.0
	if civ.is_in_golden_age():
		golden_floor = Constants.GOLDEN_AGE_STABILITY_FLOOR

	# Compact state provides a stability floor
	var compact_floor := 0.0
	if is_compact:
		compact_floor = Constants.COMPACT_STABILITY_FLOOR

	# Infrastructure provides a stability floor (developed civs resist total collapse)
	var infra_floor := _average_infrastructure(owned_regions) * Constants.INFRA_STABILITY_FLOOR_PER_LEVEL

	# Town building stability bonus (Markets, Monuments)
	var town_stab_bonus := 0.0
	for region in owned_regions:
		town_stab_bonus += TownSimulation.aggregate_region_stability_bonus(region)

	# Town deficit penalty (towns where upkeep > supply-scaled production)
	var town_deficit_penalty := 0.0
	for region in owned_regions:
		var deficit_info := TownSimulation.compute_region_deficit_info(region)
		town_deficit_penalty += float(deficit_info["deficit_towns"]) * Constants.DEFICIT_STABILITY_PENALTY_PER_TOWN

	var new_stability := (
		base + food_factor - war_exhaust - shortage
		+ hero_mod - overextension - disconnected + political
		+ mean_reversion
		+ town_stab_bonus - town_deficit_penalty
	)
	new_stability = clampf(new_stability, Constants.STABILITY_MIN, Constants.STABILITY_MAX)
	new_stability = maxf(new_stability, golden_floor)
	new_stability = maxf(new_stability, compact_floor)
	new_stability = maxf(new_stability, infra_floor)

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
	## War exhaustion escalates with duration per front.
	if civ.war_targets.is_empty():
		return 0.0

	var exhaustion := 0.0
	for target_id in civ.war_targets:
		var duration: int = civ.war_durations.get(target_id, 0)
		var front_exhaustion := minf(
			Constants.WAR_EXHAUSTION_BASE + float(duration) * Constants.WAR_EXHAUSTION_ESCALATION,
			Constants.WAR_EXHAUSTION_MAX_PER_FRONT,
		)
		exhaustion += front_exhaustion
	return exhaustion


static func _resource_shortage_penalty(
	civ: CivilizationData, _owned_regions: Array[RegionData]
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


static func _admin_capacity(civ: CivilizationData, owned_regions: Array[RegionData]) -> int:
	## Calculate how many regions a civ can effectively manage.
	var base := Constants.ADMIN_CAPACITY_BASE
	var infra_total := 0
	for region in owned_regions:
		infra_total += region.infrastructure_level
	var infra_bonus := floori(float(infra_total) * Constants.ADMIN_INFRA_BONUS_PER_LEVEL)
	var stability_bonus := floori(civ.stability / Constants.ADMIN_STABILITY_DIVISOR)
	var gov_bonus := GovernanceSimulation.get_admin_bonus(civ.governance_tier)
	var dev_tier_bonus := 0
	for region in owned_regions:
		dev_tier_bonus += DevelopmentTierSimulation.get_admin_bonus(region.development_tier)
	return base + infra_bonus + stability_bonus + gov_bonus + dev_tier_bonus


static func _overextension_penalty(region_count: int, admin_cap: int) -> float:
	## Quadratic penalty when region count exceeds admin capacity.
	var excess := maxf(float(region_count - admin_cap), 0.0)
	return (excess * excess) / Constants.ADMIN_OVEREXTENSION_DIVISOR


static func _disconnected_territory_penalty(
	civ: CivilizationData, owned_regions: Array[RegionData]
) -> float:
	## Stability drain based on supply gradient from Dijkstra routing.
	## Cut-off regions (supply < 0.2) get full penalty.
	## Poorly supplied regions (0.2-0.5) get partial penalty.
	if civ.capital_region_id < 0:
		return 0.0

	var penalty := 0.0
	for region in owned_regions:
		if region.id == civ.capital_region_id:
			continue
		if region.supply_value < Constants.SUPPLY_MIN_THRESHOLD:
			penalty += Constants.SUPPLY_CUTOFF_PENALTY_PER_REGION
		elif region.supply_value < 0.5:
			# Partial penalty scaled by how far below 0.5
			var severity := (0.5 - region.supply_value) / 0.3  # 0.0 at 0.5, 1.0 at 0.2
			penalty += Constants.SUPPLY_LOW_PENALTY_PER_REGION * severity

	return penalty


static func _average_infrastructure(owned_regions: Array[RegionData]) -> float:
	## Average infrastructure level across all owned regions.
	if owned_regions.is_empty():
		return 0.0
	var total := 0
	for region in owned_regions:
		total += region.infrastructure_level
	return float(total) / float(owned_regions.size())
