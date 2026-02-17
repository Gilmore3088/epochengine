class_name ResourceProduction
extends RefCounted

## Resource Pyramid production system.
## Calculates per-region yields, extracts deposits, applies maintenance,
## and computes complexity tax. All functions are static (pure simulation).


static func process_resources(
	civ: CivilizationData, owned_regions: Array[RegionData]
) -> Dictionary:
	## Main entry point. Runs full resource tick for one civilization.
	## Returns event dict with production log and any penalties.
	var yields := calculate_resource_yields(civ, owned_regions)
	var deposit_result := extract_deposits(civ, owned_regions)
	var extracted: Dictionary = deposit_result["totals"]
	var depleted_deposits: Array = deposit_result["depleted"]

	# Merge extracted deposits into yields
	for res_type in extracted:
		yields[res_type] = yields.get(res_type, 0) + extracted[res_type]

	# Apply yields to stockpiles
	for res_type in yields:
		civ.resource_stockpiles[res_type] = civ.resource_stockpiles.get(res_type, 0) + yields[res_type]

	# Store production log for UI
	civ.resource_production_log = yields.duplicate()

	# Apply maintenance (consumes inputs, returns penalties)
	var maintenance := apply_maintenance(civ)

	# Apply efficiency penalties to production (reduce stockpile gains)
	for penalty_info in maintenance["penalties"]:
		var res_type: int = penalty_info["resource"]
		var eff_loss: float = penalty_info["efficiency_loss"]
		if eff_loss > 0.0 and yields.has(res_type):
			var reduction := int(float(yields[res_type]) * eff_loss)
			civ.resource_stockpiles[res_type] = maxi(
				civ.resource_stockpiles.get(res_type, 0) - reduction, 0
			)

	# Complexity tax
	var complexity_penalty := calculate_complexity_tax(civ)

	var total_stability_penalty: float = maintenance["stability_penalty"] + complexity_penalty

	return {
		"yields": yields,
		"extracted": extracted,
		"maintenance_penalties": maintenance["penalties"],
		"maintenance_stability": maintenance["stability_penalty"],
		"complexity_tax": complexity_penalty,
		"total_stability_penalty": total_stability_penalty,
		"depleted_deposits": depleted_deposits,
	}


static func calculate_resource_yields(
	civ: CivilizationData, owned_regions: Array[RegionData]
) -> Dictionary:
	## Calculate renewable per-turn yields from terrain for all unlocked resources.
	## Applies renewable degradation to each region's yields.
	## Returns {resource_type_int: total_yield}.
	var totals: Dictionary = {}
	var era: int = civ.current_era

	for region in owned_regions:
		var terrain_key: int = region.terrain_type
		if not Constants.RESOURCE_TERRAIN_YIELDS.has(terrain_key):
			continue

		var terrain_yields: Dictionary = Constants.RESOURCE_TERRAIN_YIELDS[terrain_key]
		var size_mod: float = region.size_factor
		var tier_mult: float = DevelopmentTierSimulation.get_economy_multiplier(
			region.development_tier
		)
		@warning_ignore("integer_division")
		var infra_bonus: int = region.infrastructure_level / 2  # +1 per 2 levels
		var degradation_mult: float = 1.0 - region.renewable_degradation

		for res_type in terrain_yields:
			# Era gate: skip resources not yet unlocked
			if Constants.RESOURCE_ERA_UNLOCK.get(res_type, 99) > era:
				continue

			var base_yield: int = terrain_yields[res_type]
			var adjusted := int(float(base_yield + infra_bonus) * size_mod * tier_mult * degradation_mult)
			totals[res_type] = totals.get(res_type, 0) + adjusted

		# Increase degradation from extraction pressure
		if not terrain_yields.is_empty():
			region.renewable_degradation = minf(
				region.renewable_degradation + Constants.RENEWABLE_DEGRADATION_RATE,
				Constants.RENEWABLE_MAX_DEGRADATION,
			)

	return totals


static func extract_deposits(
	civ: CivilizationData, owned_regions: Array[RegionData]
) -> Dictionary:
	## Extract finite resources from deposits in owned regions.
	## Decrements deposit quantities.
	## Returns {"totals": {res_type: amount}, "depleted": [{region_id, region_name, resource_name}]}.
	var totals: Dictionary = {}
	var depleted: Array[Dictionary] = []
	var era: int = civ.current_era

	for region in owned_regions:
		if region.resource_deposits.is_empty():
			continue

		var tier_mod := 1.0 + region.development_tier * Constants.DEPOSIT_DEV_TIER_EXTRACTION_BONUS

		for res_type in region.resource_deposits.keys():
			# Era gate
			if Constants.RESOURCE_ERA_UNLOCK.get(res_type, 99) > era:
				continue

			var remaining: int = region.resource_deposits[res_type]
			if remaining <= 0:
				continue

			var extraction := int(float(Constants.DEPOSIT_BASE_EXTRACTION) * tier_mod)
			extraction = mini(extraction, remaining)
			region.resource_deposits[res_type] = remaining - extraction
			region.extraction_years += 1

			totals[res_type] = totals.get(res_type, 0) + extraction

			# Track newly depleted deposits
			if region.resource_deposits[res_type] <= 0:
				depleted.append({
					"region_id": region.id,
					"region_name": region.region_name,
					"resource_name": get_resource_name(res_type),
				})

	return {"totals": totals, "depleted": depleted}


static func apply_maintenance(civ: CivilizationData) -> Dictionary:
	## Check maintenance requirements for dependent resources.
	## Consumes inputs from stockpiles. Returns penalties for missing inputs.
	var penalties: Array[Dictionary] = []
	var stability_penalty := 0.0

	for res_type in Constants.RESOURCE_MAINTENANCE:
		var required_inputs: Array = Constants.RESOURCE_MAINTENANCE[res_type]
		if required_inputs.is_empty():
			continue

		# Only check maintenance for resources we're actually producing
		if civ.resource_stockpiles.get(res_type, 0) <= 0 and \
				civ.resource_production_log.get(res_type, 0) <= 0:
			continue

		var missing_count := 0
		for input_type in required_inputs:
			var available: int = civ.resource_stockpiles.get(input_type, 0)
			if available >= Constants.RESOURCE_MAINTENANCE_AMOUNT:
				# Consume maintenance input
				civ.resource_stockpiles[input_type] = available - Constants.RESOURCE_MAINTENANCE_AMOUNT
			else:
				missing_count += 1

		if missing_count > 0:
			var eff_loss := minf(
				float(missing_count) * Constants.RESOURCE_MISSING_EFFICIENCY_PENALTY,
				Constants.RESOURCE_MAX_EFFICIENCY_LOSS,
			)
			var stab_loss := float(missing_count) * Constants.RESOURCE_MISSING_STABILITY_PENALTY
			stability_penalty += stab_loss
			penalties.append({
				"resource": res_type,
				"missing_inputs": missing_count,
				"efficiency_loss": eff_loss,
			})

	return {
		"penalties": penalties,
		"stability_penalty": stability_penalty,
	}


static func calculate_complexity_tax(civ: CivilizationData) -> float:
	## Returns stability penalty from producing many diverse resource types.
	## Mitigated by governance tier.
	var distinct_count := 0
	for res_type in civ.resource_stockpiles:
		if civ.resource_stockpiles[res_type] > 0:
			distinct_count += 1

	if distinct_count <= Constants.COMPLEXITY_TAX_THRESHOLD:
		return 0.0

	var excess := distinct_count - Constants.COMPLEXITY_TAX_THRESHOLD
	var raw_penalty := float(excess) * Constants.COMPLEXITY_TAX_PER_TYPE

	# Governance tier mitigates (TRIBAL=0 gives no reduction)
	var gov_reduction := float(civ.governance_tier) * Constants.COMPLEXITY_TAX_GOVERNANCE_REDUCTION
	return maxf(raw_penalty - gov_reduction, 0.0)


static func process_renewable_recovery(all_regions: Array) -> void:
	## Gradually recover degradation for unowned or lightly-developed regions.
	## Called once per turn for all regions.
	for region in all_regions:
		if region.renewable_degradation <= 0.0:
			continue
		# Recover if unowned or low infrastructure
		if region.owner_id < 0 or region.infrastructure_level <= Constants.RENEWABLE_RECOVERY_THRESHOLD:
			region.renewable_degradation = maxf(
				region.renewable_degradation - Constants.RENEWABLE_RECOVERY_RATE, 0.0
			)


static func get_resource_name(res_type: int) -> String:
	return Constants.RESOURCE_NAMES.get(res_type, "Unknown")


static func is_resource_unlocked(res_type: int, era: int) -> bool:
	return era >= Constants.RESOURCE_ERA_UNLOCK.get(res_type, 99)
