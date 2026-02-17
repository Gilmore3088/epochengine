class_name GovernanceSimulation
extends RefCounted

## Pure simulation logic for governance tier transitions.
## Civs progress through tiers as they grow; demotion uses hysteresis.

# Tier definitions: [min_regions, min_stability, admin_bonus, expansion_friction_mod]
# Ordered by tier enum value (TRIBAL=0 through FEDERATION=5).
const TIER_DATA := [
	[1, 0.0, 0, 1.0],       # TRIBAL
	[6, 35.0, 2, 0.95],     # CHIEFDOM
	[9, 40.0, 4, 0.90],     # CITY_STATE
	[13, 45.0, 7, 0.80],    # KINGDOM
	[19, 50.0, 12, 0.70],   # EMPIRE
	[26, 55.0, 18, 0.60],   # FEDERATION
]


static func evaluate_governance(civ: CivilizationData, region_count: int) -> Dictionary:
	## Evaluate and potentially transition a civ's governance tier.
	## Returns {"tier_changed": bool, "old_tier": int, "new_tier": int}
	var old_tier := civ.governance_tier
	var target_tier := _compute_target_tier(region_count, civ.stability)

	if target_tier > old_tier:
		# Promotion: immediate when meeting thresholds
		civ.governance_tier = target_tier
		civ.governance_years = 0
		return {"tier_changed": true, "old_tier": old_tier, "new_tier": target_tier}

	if target_tier < old_tier:
		# Demotion: only after hysteresis period
		civ.governance_years += 1
		if civ.governance_years >= Constants.GOVERNANCE_DEMOTION_HYSTERESIS_YEARS:
			civ.governance_tier = target_tier
			civ.governance_years = 0
			return {"tier_changed": true, "old_tier": old_tier, "new_tier": target_tier}
		return {"tier_changed": false, "old_tier": old_tier, "new_tier": old_tier}

	# Same tier: reset hysteresis counter, increment years in tier
	civ.governance_years += 1
	return {"tier_changed": false, "old_tier": old_tier, "new_tier": old_tier}


static func _compute_target_tier(region_count: int, stability: float) -> Enums.GovernanceTier:
	## Determine the highest tier a civ qualifies for based on current size and stability.
	var best_tier := Enums.GovernanceTier.TRIBAL
	for i in range(TIER_DATA.size()):
		var min_regions: int = TIER_DATA[i][0]
		var min_stability: float = TIER_DATA[i][1]
		if region_count >= min_regions and stability >= min_stability:
			best_tier = i as Enums.GovernanceTier
	return best_tier


static func get_admin_bonus(tier: Enums.GovernanceTier) -> int:
	## Admin capacity bonus from governance tier.
	return TIER_DATA[tier][2]


static func get_expansion_friction_mod(tier: Enums.GovernanceTier) -> float:
	## Expansion friction multiplier from governance tier.
	## Lower = easier to expand (better organized states expand more efficiently).
	return TIER_DATA[tier][3]


static func get_tier_name(tier: Enums.GovernanceTier) -> String:
	## Human-readable tier name for UI and logs.
	match tier:
		Enums.GovernanceTier.TRIBAL:
			return "Tribal"
		Enums.GovernanceTier.CHIEFDOM:
			return "Chiefdom"
		Enums.GovernanceTier.CITY_STATE:
			return "City-State"
		Enums.GovernanceTier.KINGDOM:
			return "Kingdom"
		Enums.GovernanceTier.EMPIRE:
			return "Empire"
		Enums.GovernanceTier.FEDERATION:
			return "Federation"
	return "Unknown"
