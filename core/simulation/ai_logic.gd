class_name AILogic
extends RefCounted

## AI decision-making based on weighted probabilities.
## Logic from docs/systems/ai_behavior.md
## Returns event arrays instead of emitting signals (pure simulation).


static func make_decisions(civ: CivilizationData) -> Array[Dictionary]:
	## Executes AI decisions for one civilization for this turn.
	## Returns an array of event dictionaries.
	if civ.is_collapsed:
		return []

	var events: Array[Dictionary] = []
	var state := civ.get_state()

	match state:
		Enums.CivState.DECLINING:
			events.append_array(_try_seek_peace(civ))
		Enums.CivState.STABLE:
			events.append_array(_try_expand(civ))
			events.append_array(_try_declare_war(civ))
			events.append_array(_try_invest_infrastructure(civ))
		Enums.CivState.GROWING:
			events.append_array(_try_expand(civ))
			events.append_array(_try_declare_war(civ))
			events.append_array(_try_invest_infrastructure(civ))

	return events


static func _try_expand(civ: CivilizationData) -> Array[Dictionary]:
	## Attempt to expand into adjacent neutral regions.
	## Costs production and moves settlers from existing territory.
	if civ.stability < Constants.AI_EXPANSION_STABILITY_THRESHOLD:
		return []
	if civ.food_stockpile <= 0:
		return []

	var owned_regions := GameState.get_regions_by_owner(civ.id)
	var region_count := owned_regions.size()

	if not EconomySimulation.can_afford_expansion(civ, region_count):
		return []

	var targets := GameState.get_adjacent_targets(civ.id)
	var neutral_targets: Array[RegionData] = []
	for target in targets:
		if target.is_neutral():
			neutral_targets.append(target)

	if neutral_targets.is_empty():
		return []

	# Weighted by expansion bias
	if randf() > civ.expansion_bias:
		return []

	# Pick highest food_yield neutral region
	neutral_targets.sort_custom(func(a: RegionData, b: RegionData) -> bool:
		return a.food_yield > b.food_yield
	)

	var target := neutral_targets[0]

	# Find best source region for settlers (highest population, adjacent to target)
	var source_region: RegionData = null
	for region in owned_regions:
		if target.id in region.adjacency_list:
			if not source_region or region.population > source_region.population:
				source_region = region
	if not source_region:
		source_region = owned_regions[0]

	# Pay the cost
	var cost := EconomySimulation.pay_expansion_cost(civ, region_count, source_region)

	var old_owner := target.owner_id
	target.owner_id = civ.id
	target.population = maxi(target.population, Constants.EXPANSION_SETTLER_POP)

	return [{
		"type": "expansion",
		"civ_id": civ.id,
		"civ_name": civ.civ_name,
		"region_id": target.id,
		"region_name": target.region_name,
		"old_owner": old_owner,
		"cost": cost,
	}]


static func _try_declare_war(civ: CivilizationData) -> Array[Dictionary]:
	## Attempt to declare war on a weaker neighbor.
	if civ.stability < Constants.WAR_DECLARATION_STABILITY_THRESHOLD:
		return []

	var neighbor_ids := GameState.get_neighboring_civs(civ.id)
	for neighbor_id in neighbor_ids:
		if civ.war_targets.has(neighbor_id):
			continue
		if civ.alliance_partners.has(neighbor_id):
			continue

		var neighbor := GameState.get_civilization(neighbor_id)
		if not neighbor or neighbor.is_collapsed:
			continue

		if civ.military_strength < neighbor.military_strength * Constants.WAR_DECLARATION_STRENGTH_RATIO:
			continue

		var strength_ratio := civ.military_strength / maxf(neighbor.military_strength, 1.0)
		var war_chance := 0.2 * strength_ratio * civ.aggression_bias

		if randf() < war_chance:
			civ.war_targets.append(neighbor_id)
			neighbor.war_targets.append(civ.id)

			return [{
				"type": "war_declared",
				"attacker_id": civ.id,
				"defender_id": neighbor_id,
				"attacker_name": civ.civ_name,
				"defender_name": neighbor.civ_name,
			}]

	return []


static func _try_seek_peace(civ: CivilizationData) -> Array[Dictionary]:
	## Attempt to end wars when stability is critically low.
	if civ.war_targets.is_empty():
		return []

	var peace_chance := (1.0 - civ.stability / Constants.STABILITY_MAX) * civ.diplomacy_bias
	if randf() < peace_chance:
		var target_id: int = civ.war_targets[0]
		var target := GameState.get_civilization(target_id)

		civ.war_targets.erase(target_id)
		if target:
			target.war_targets.erase(civ.id)
			return [{
				"type": "peace",
				"civ_a_id": civ.id,
				"civ_b_id": target_id,
				"civ_a_name": civ.civ_name,
				"civ_b_name": target.civ_name,
			}]

	return []


static func _try_invest_infrastructure(civ: CivilizationData) -> Array[Dictionary]:
	## AI invests in infrastructure when surplus is high enough.
	if civ.production_stockpile < Constants.INFRASTRUCTURE_AUTO_INVEST_THRESHOLD:
		return []

	var owned_regions := GameState.get_regions_by_owner(civ.id)
	# Sort by lowest infrastructure (upgrade weakest first)
	owned_regions.sort_custom(func(a: RegionData, b: RegionData) -> bool:
		return a.infrastructure_level < b.infrastructure_level
	)

	for region in owned_regions:
		if EconomySimulation.try_upgrade_infrastructure(civ, region):
			return [{
				"type": "infrastructure_upgrade",
				"civ_id": civ.id,
				"civ_name": civ.civ_name,
				"region_id": region.id,
				"region_name": region.region_name,
				"new_level": region.infrastructure_level,
			}]

	return []
