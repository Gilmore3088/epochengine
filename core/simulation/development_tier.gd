class_name DevelopmentTierSimulation
extends RefCounted

## Evaluates region development tier transitions based on infrastructure,
## population density, governance, era, and stability gates.
## Follows the same gate-based pattern as GovernanceSimulation.


static func evaluate_development(
	region: RegionData, civ: CivilizationData
) -> Dictionary:
	## Evaluate and potentially transition a region's development tier.
	## Returns {"tier_changed": bool, "old_tier": int, "new_tier": int}
	var old_tier := region.development_tier
	var target_tier := _compute_target_tier(region, civ)

	if target_tier > old_tier:
		# Promotion: immediate
		region.development_tier = target_tier
		region.demotion_years = 0
		region.urbanization_level = float(region.development_tier) / 5.0
		return {"tier_changed": true, "old_tier": old_tier, "new_tier": target_tier}

	if target_tier < old_tier:
		# Demotion: hysteresis
		region.demotion_years += 1
		if region.demotion_years >= Constants.DEV_DEMOTION_HYSTERESIS_YEARS:
			region.development_tier = target_tier
			region.demotion_years = 0
			region.urbanization_level = float(region.development_tier) / 5.0
			return {"tier_changed": true, "old_tier": old_tier, "new_tier": target_tier}
		return {"tier_changed": false, "old_tier": old_tier, "new_tier": old_tier}

	# Same tier: reset hysteresis
	region.demotion_years = 0
	return {"tier_changed": false, "old_tier": old_tier, "new_tier": old_tier}


static func _compute_target_tier(region: RegionData, civ: CivilizationData) -> int:
	var pop_density := _population_density(region)
	var best_tier := 0
	for i in range(Constants.DEV_TIER_GATES.size()):
		var gate: Array = Constants.DEV_TIER_GATES[i]
		if (region.infrastructure_level >= gate[0]
			and pop_density >= gate[1]
			and civ.stability >= gate[2]
			and civ.governance_tier >= gate[3]
			and civ.current_era >= gate[4]
			and _meets_resource_gate(i, civ)):
			best_tier = i
	return best_tier


static func _meets_resource_gate(tier: int, civ: CivilizationData) -> bool:
	if tier >= Constants.DEV_TIER_RESOURCE_GATES.size():
		return true
	var required: Array = Constants.DEV_TIER_RESOURCE_GATES[tier]
	for res_type in required:
		if civ.resource_stockpiles.get(res_type, 0) <= 0:
			return false
	return true


static func _population_density(region: RegionData) -> float:
	var capacity: int = Constants.TERRAIN_POP_CAPACITY.get(
		region.terrain_type, 5000
	)
	var effective_capacity := int(float(capacity) * region.size_factor)
	if effective_capacity <= 0:
		return 0.0
	return clampf(float(region.population) / float(effective_capacity), 0.0, 1.0)


static func get_economy_multiplier(tier: int) -> float:
	return Constants.DEV_TIER_ECONOMY_MULT[clampi(tier, 0, 5)]


static func get_defense_bonus(tier: int) -> float:
	return Constants.DEV_TIER_DEFENSE_BONUS[clampi(tier, 0, 5)]


static func get_admin_bonus(tier: int) -> int:
	return Constants.DEV_TIER_ADMIN_BONUS[clampi(tier, 0, 5)]


static func get_tier_name(tier: int) -> String:
	match tier:
		0: return "Wild"
		1: return "Rural Settlement"
		2: return "Structured Agriculture"
		3: return "Urbanized"
		4: return "Industrialized"
		5: return "Advanced"
	return "Unknown"


static func get_tier_progress(region: RegionData, civ: CivilizationData) -> Dictionary:
	## Returns gate progress toward the next development tier.
	## {"next_tier": int, "gates": {name: {current, needed, met}}, "all_met": bool}
	var next_tier: int = region.development_tier + 1
	if next_tier >= Constants.DEV_TIER_GATES.size():
		return {"next_tier": -1, "gates": {}, "all_met": false}
	var gate: Array = Constants.DEV_TIER_GATES[next_tier]
	var pop_density := _population_density(region)
	var gates := {
		"infra": {"current": region.infrastructure_level, "needed": gate[0],
				   "met": region.infrastructure_level >= gate[0]},
		"pop_density": {"current": pop_density, "needed": gate[1],
						"met": pop_density >= gate[1]},
		"stability": {"current": civ.stability, "needed": gate[2],
					   "met": civ.stability >= gate[2]},
		"governance": {"current": civ.governance_tier, "needed": gate[3],
					    "met": civ.governance_tier >= gate[3]},
		"era": {"current": civ.current_era, "needed": gate[4],
				"met": civ.current_era >= gate[4]},
	}
	var all_met := true
	for key in gates:
		if not gates[key]["met"]:
			all_met = false
			break
	# Also check resource gates
	if all_met and next_tier < Constants.DEV_TIER_RESOURCE_GATES.size():
		if not _meets_resource_gate(next_tier, civ):
			all_met = false
	return {"next_tier": next_tier, "gates": gates, "all_met": all_met}
