class_name LegitimacySimulation
extends RefCounted

## Legitimacy simulation: derives a target legitimacy score from
## stability, governance, food, war exhaustion, shortages, and disasters.

static func update_legitimacy(
	civ: CivilizationData, owned_regions: Array[RegionData]
) -> Dictionary:
	var old_val: float = civ.legitimacy
	var target: float = _compute_target(civ, owned_regions)
	civ.legitimacy = clampf(lerpf(old_val, target, Constants.LEGITIMACY_LERP), 0.0, 100.0)
	return {"old": old_val, "new": civ.legitimacy, "target": target}


static func _compute_target(civ: CivilizationData, owned_regions: Array[RegionData]) -> float:
	var gov_bonus: float = float(civ.governance_tier) * Constants.LEGITIMACY_GOV_TIER_BONUS
	var food_factor: float = clampf(float(civ.food_stockpile) / 20.0, -5.0, 5.0)
	var war_exhaust: float = StabilitySimulation.get_war_exhaustion(civ)
	var shortage: float = StabilitySimulation.get_shortage_penalty(civ, owned_regions)

	var disaster_count := 0
	for region in owned_regions:
		if region.active_disaster >= 0:
			disaster_count += 1
	var disaster_penalty: float = float(disaster_count) * Constants.LEGITIMACY_DISASTER_PENALTY

	var target := (
		civ.stability
		+ gov_bonus
		+ food_factor * Constants.LEGITIMACY_FOOD_FACTOR_SCALE
		- war_exhaust * Constants.LEGITIMACY_WAR_EXHAUST_SCALE
		- shortage * Constants.LEGITIMACY_SHORTAGE_PENALTY_SCALE
		- disaster_penalty
	)
	return clampf(target, 0.0, 100.0)
