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
			events.append_array(_try_seek_alliance(civ))
			events.append_array(_try_seek_nap(civ))
			events.append_array(_try_seek_trade(civ))
			events.append_array(_try_declining_recovery(civ))
		Enums.CivState.STABLE:
			events.append_array(_try_expand(civ))
			events.append_array(_try_declare_war(civ))
			events.append_array(_try_invest_infrastructure(civ))
			events.append_array(_try_found_town(civ))
			events.append_array(_try_construct_building(civ))
			events.append_array(_try_seek_alliance(civ))
			events.append_array(_try_break_alliance(civ))
			events.append_array(_try_seek_nap(civ))
			events.append_array(_try_seek_trade(civ))
			events.append_array(_try_demand_tribute(civ))
		Enums.CivState.GROWING:
			events.append_array(_try_expand(civ))
			events.append_array(_try_declare_war(civ))
			events.append_array(_try_invest_infrastructure(civ))
			events.append_array(_try_found_town(civ))
			events.append_array(_try_construct_building(civ))
			events.append_array(_try_seek_alliance(civ))
			events.append_array(_try_break_alliance(civ))
			events.append_array(_try_seek_nap(civ))
			events.append_array(_try_seek_trade(civ))
			events.append_array(_try_demand_tribute(civ))

	# Update strategy (research focus + spending priority) every 10 years
	if GameState.current_year % 10 == 0:
		_update_ai_strategy(civ, state)

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

	# Expansion friction: growth slows as empire gets larger
	# Governance tier reduces friction (better-organized states expand more efficiently)
	var gov_friction_mod := GovernanceSimulation.get_expansion_friction_mod(civ.governance_tier)
	var effective_divisor := Constants.EXPANSION_FRICTION_DIVISOR / gov_friction_mod
	var expansion_factor := 1.0 / (1.0 + float(region_count) / effective_divisor)
	if GameState.sim_rng.randf() > civ.expansion_bias * expansion_factor:
		return []

	# Pick best neutral region: supply proximity > high-tier neighbors > resource deposits > food yield
	neutral_targets.sort_custom(func(a: RegionData, b: RegionData) -> bool:
		# Prefer targets adjacent to well-supplied owned regions
		var a_supply := _best_adjacent_supply(a, civ.id)
		var b_supply := _best_adjacent_supply(b, civ.id)
		if absf(a_supply - b_supply) > 0.2:
			return a_supply > b_supply
		var a_adj_tier := _best_adjacent_tier(a, civ.id)
		var b_adj_tier := _best_adjacent_tier(b, civ.id)
		if a_adj_tier != b_adj_tier:
			return a_adj_tier > b_adj_tier
		var a_res := _resource_value(a)
		var b_res := _resource_value(b)
		if a_res != b_res:
			return a_res > b_res
		return a.food_yield > b.food_yield
	)

	var target: RegionData = neutral_targets[0]

	# Reject expansion into poorly supplied territory
	if _best_adjacent_supply(target, civ.id) < Constants.SUPPLY_MIN_THRESHOLD:
		return []

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
	## Attempt to declare war using border tension model.
	## Military parity (within 30%) dampens war probability (Cold War standoff).
	## Military imbalance (attacker stronger) increases probability.
	## Weaker civs never initiate.
	if civ.stability < Constants.WAR_DECLARATION_STABILITY_THRESHOLD:
		return []

	var neighbor_ids := GameState.get_neighboring_civs(civ.id)
	for neighbor_id in neighbor_ids:
		if civ.war_targets.has(neighbor_id):
			continue
		if civ.alliance_partners.has(neighbor_id):
			continue
		if civ.nap_partners.has(neighbor_id):
			continue
		# Peace cooldown prevents immediate redeclaration
		if civ.peace_cooldowns.get(neighbor_id, 0) > 0:
			continue

		var neighbor := GameState.get_civilization(neighbor_id)
		if not neighbor or neighbor.is_collapsed:
			continue

		var strength_ratio := civ.military_strength / maxf(neighbor.military_strength, 1.0)

		# Weaker civs don't initiate war (below parity band)
		if strength_ratio < (1.0 - Constants.WAR_PARITY_THRESHOLD):
			continue

		var war_chance: float
		if absf(strength_ratio - 1.0) <= Constants.WAR_PARITY_THRESHOLD:
			# Military parity - evenly matched civs avoid costly wars
			war_chance = Constants.WAR_BASE_CHANCE * Constants.WAR_PARITY_DAMPENER * civ.aggression_bias
		else:
			# Attacker is stronger - imbalance encourages opportunistic war
			var imbalance := (strength_ratio - 1.0) / Constants.WAR_PARITY_THRESHOLD
			war_chance = Constants.WAR_BASE_CHANCE * minf(imbalance, Constants.WAR_IMBALANCE_MULTIPLIER) * civ.aggression_bias

		if GameState.sim_rng.randf() < war_chance:
			civ.war_targets.append(neighbor_id)
			neighbor.war_targets.append(civ.id)
			civ.war_durations[neighbor_id] = 0
			neighbor.war_durations[civ.id] = 0

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

	# Longer wars increase peace desire
	var longest_war := 0
	for tid in civ.war_targets:
		longest_war = maxi(longest_war, int(civ.war_durations.get(tid, 0)))
	var fatigue_boost := minf(float(longest_war) * 0.05, 0.4)
	var peace_chance := ((1.0 - civ.stability / Constants.STABILITY_MAX) + fatigue_boost) * civ.diplomacy_bias
	if GameState.sim_rng.randf() < peace_chance:
		var target_id: int = civ.war_targets[0]
		var target := GameState.get_civilization(target_id)

		civ.war_targets.erase(target_id)
		civ.war_durations.erase(target_id)
		civ.peace_cooldowns[target_id] = Constants.PEACE_COOLDOWN_YEARS
		if target:
			target.war_targets.erase(civ.id)
			target.war_durations.erase(civ.id)
			target.peace_cooldowns[civ.id] = Constants.PEACE_COOLDOWN_YEARS
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
	# Prioritize regions closest to next tier promotion gate
	owned_regions.sort_custom(func(a: RegionData, b: RegionData) -> bool:
		var a_gap := _infra_gap_to_next_tier(a)
		var b_gap := _infra_gap_to_next_tier(b)
		if a_gap != b_gap:
			return a_gap < b_gap  # smaller gap = closer to promotion
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
				"infra_name": Constants.INFRASTRUCTURE_NAMES.get(region.infrastructure_level, "Level %d" % region.infrastructure_level),
			}]

	return []


static func _try_seek_alliance(civ: CivilizationData) -> Array[Dictionary]:
	## AI seeks alliances with non-hostile neighbors.
	## Higher diplomacy_bias and shared enemies increase probability.
	if civ.stability < Constants.ALLIANCE_STABILITY_THRESHOLD:
		return []

	var neighbor_ids := GameState.get_neighboring_civs(civ.id)
	for neighbor_id in neighbor_ids:
		if civ.alliance_partners.has(neighbor_id):
			continue
		if civ.war_targets.has(neighbor_id):
			continue

		var neighbor := GameState.get_civilization(neighbor_id)
		if not neighbor or neighbor.is_collapsed:
			continue

		# Shared enemy bonus: both at war with same civ
		var shared_enemy_bonus := 0.0
		for enemy_id in civ.war_targets:
			if neighbor.war_targets.has(enemy_id):
				shared_enemy_bonus = Constants.ALLIANCE_SHARED_ENEMY_BONUS
				break

		var alliance_chance := (
			Constants.ALLIANCE_BASE_CHANCE
			* civ.diplomacy_bias
			* neighbor.diplomacy_bias
			+ shared_enemy_bonus
		)

		if GameState.sim_rng.randf() < alliance_chance:
			civ.alliance_partners.append(neighbor_id)
			neighbor.alliance_partners.append(civ.id)
			return [{
				"type": "alliance_formed",
				"civ_a_id": civ.id,
				"civ_b_id": neighbor_id,
				"civ_a_name": civ.civ_name,
				"civ_b_name": neighbor.civ_name,
			}]

	return []


static func _try_found_town(civ: CivilizationData) -> Array[Dictionary]:
	## AI founds towns in high-population regions that can afford it.
	if civ.production_stockpile < Constants.TOWN_AI_INVEST_THRESHOLD:
		return []

	var owned_regions := GameState.get_regions_by_owner(civ.id)

	for region in owned_regions:
		if TownSimulation.can_found_town(region, civ):
			var town: TownData = TownSimulation.found_town(region, civ)
			if town:
				return [{
					"type": "town_founded",
					"civ_id": civ.id,
					"civ_name": civ.civ_name,
					"region_id": region.id,
					"region_name": region.region_name,
					"town_name": town.town_name,
				}]

	return []


static func _try_construct_building(civ: CivilizationData) -> Array[Dictionary]:
	if civ.production_stockpile < Constants.TOWN_AI_INVEST_THRESHOLD:
		return []

	var owned_regions := GameState.get_regions_by_owner(civ.id)
	for region in owned_regions:
		if region.towns.is_empty():
			continue
		for town in region.towns:
			var building_type := _pick_ai_building_type(civ)
			if TownSimulation.can_construct_building(town, building_type, civ):
				if TownSimulation.construct_building(town, building_type, civ):
					var bname: String = Constants.BUILDING_NAMES.get(building_type, "Building")
					return [{
						"type": "building_constructed",
						"civ_id": civ.id,
						"civ_name": civ.civ_name,
						"region_id": region.id,
						"region_name": region.region_name,
						"town_name": town.town_name,
						"building_name": bname,
					}]
	return []


static func _pick_ai_building_type(civ: CivilizationData) -> int:
	## Choose building type based on civ needs.
	if civ.food_stockpile < 0:
		return Enums.BuildingType.GRANARY
	if civ.is_at_war():
		if GameState.sim_rng.randf() < 0.5:
			return Enums.BuildingType.BARRACKS
		return Enums.BuildingType.WALLS
	if civ.stability < 40.0:
		return Enums.BuildingType.MONUMENT
	# Tech pressure: build Library when tech count is low for current era
	if civ.technologies.size() < _era_tech_threshold(civ.current_era):
		if GameState.sim_rng.randf() < 0.15:
			return Enums.BuildingType.LIBRARY
	# Small chance to build Town Hall for workforce management
	if GameState.sim_rng.randf() < 0.10:
		return Enums.BuildingType.TOWN_HALL
	# Default: economy buildings weighted by economy_bias
	if GameState.sim_rng.randf() < civ.economy_bias:
		return Enums.BuildingType.WORKSHOP
	return Enums.BuildingType.MARKET


static func _best_adjacent_tier(target: RegionData, civ_id: int) -> int:
	## Returns the highest development_tier of owned regions adjacent to target.
	var best := 0
	for adj_id in target.adjacency_list:
		var adj := GameState.get_region(adj_id)
		if adj and adj.owner_id == civ_id:
			best = maxi(best, adj.development_tier)
	return best


static func _infra_gap_to_next_tier(region: RegionData) -> int:
	## Returns infrastructure gap to the next tier gate. Lower = closer to promotion.
	var next_tier := region.development_tier + 1
	if next_tier >= Constants.DEV_TIER_GATES.size():
		return 99  # already max, deprioritize
	var needed_infra: int = Constants.DEV_TIER_GATES[next_tier][0]
	return maxi(needed_infra - region.infrastructure_level, 0)


static func _best_adjacent_supply(target: RegionData, civ_id: int) -> float:
	## Returns the highest supply_value of owned regions adjacent to target.
	return SupplySystem.get_best_adjacent_supply(target, civ_id)


static func _try_break_alliance(civ: CivilizationData) -> Array[Dictionary]:
	## Consider breaking alliances with unstable or problematic allies.
	if civ.alliance_partners.is_empty():
		return []

	for ally_id in civ.alliance_partners.duplicate():
		var ally := GameState.get_civilization(ally_id)
		if not ally:
			continue

		var should_consider := false
		# Break if ally stability is critically low
		if ally.stability < 30.0:
			should_consider = true
		# Break if ally is at war with one of our other allies
		for other_ally_id in civ.alliance_partners:
			if other_ally_id != ally_id and ally.war_targets.has(other_ally_id):
				should_consider = true
				break

		if should_consider and GameState.sim_rng.randf() < 0.05:
			civ.alliance_partners.erase(ally_id)
			ally.alliance_partners.erase(civ.id)
			return [{
				"type": "alliance_broken",
				"civ_a_id": civ.id,
				"civ_b_id": ally_id,
				"civ_a_name": civ.civ_name,
				"civ_b_name": ally.civ_name,
			}]

	return []


static func _try_declining_recovery(civ: CivilizationData) -> Array[Dictionary]:
	## DECLINING state: invest in infrastructure or build granaries to recover.
	# Invest in infrastructure with low bar (10% chance if stockpile > 50)
	if civ.production_stockpile > 50 and GameState.sim_rng.randf() < 0.10:
		var owned_regions := GameState.get_regions_by_owner(civ.id)
		for region in owned_regions:
			if EconomySimulation.try_upgrade_infrastructure(civ, region):
				return [{
					"type": "infrastructure_upgrade",
					"civ_id": civ.id,
					"civ_name": civ.civ_name,
					"region_id": region.id,
					"region_name": region.region_name,
					"new_level": region.infrastructure_level,
					"infra_name": Constants.INFRASTRUCTURE_NAMES.get(region.infrastructure_level, "Level %d" % region.infrastructure_level),
				}]

	# Build granary in towns if food deficit
	if civ.food_stockpile < 0:
		var owned_regions := GameState.get_regions_by_owner(civ.id)
		for region in owned_regions:
			for town in region.towns:
				if TownSimulation.can_construct_building(town, Enums.BuildingType.GRANARY, civ):
					if TownSimulation.construct_building(town, Enums.BuildingType.GRANARY, civ):
						return [{
							"type": "building_constructed",
							"civ_id": civ.id,
							"civ_name": civ.civ_name,
							"region_id": region.id,
							"region_name": region.region_name,
							"town_name": town.town_name,
							"building_name": "Granary",
						}]

	return []


static func _era_tech_threshold(era: int) -> int:
	## Returns tech count threshold below which AI should invest in Libraries.
	match era:
		Enums.Epoch.PREHISTORIC: return 2
		Enums.Epoch.CLASSICAL: return 5
		Enums.Epoch.INDUSTRIAL: return 8
		Enums.Epoch.FUTURE: return 12
	return 2


static func _update_ai_strategy(civ: CivilizationData, state: int) -> void:
	## Set research focus and spending priority based on civ state and bias profile.
	# Research focus (only change if off cooldown)
	if civ.research_focus_cooldown <= 0:
		var new_focus := 0  # Balanced
		match state:
			Enums.CivState.GROWING:
				# Prioritize Knowledge or Economic based on tech deficit
				if civ.technologies.size() < _era_tech_threshold(civ.current_era):
					new_focus = 1  # Knowledge
				else:
					new_focus = 4  # Economic
			Enums.CivState.DECLINING:
				# Shore up weak areas
				if civ.is_at_war():
					new_focus = 5  # Military
				else:
					new_focus = 3  # Social (stability helps recovery)
			Enums.CivState.STABLE:
				# Use bias profile
				var roll := GameState.sim_rng.randf()
				if civ.aggression_bias > 0.7 and roll < 0.4:
					new_focus = 5  # Military
				elif civ.economy_bias > 0.7 and roll < 0.6:
					new_focus = 4  # Economic
				elif civ.expansion_bias > 0.7 and roll < 0.7:
					new_focus = 2  # Energy
				elif roll < 0.3:
					new_focus = 1  # Knowledge
				# else stays 0 (Balanced)
		if new_focus != civ.research_focus:
			civ.research_focus = new_focus
			civ.research_focus_cooldown = Constants.RESEARCH_FOCUS_COOLDOWN_YEARS

	# Spending priority (only change if off cooldown)
	if civ.spending_priority_cooldown <= 0:
		var new_priority := 0  # Balanced
		match state:
			Enums.CivState.DECLINING:
				if civ.food_stockpile < 0:
					new_priority = 1  # Growth
				elif civ.is_at_war():
					new_priority = 3  # Military
			Enums.CivState.GROWING:
				if civ.economy_bias > 0.6:
					new_priority = 2  # Production
				else:
					new_priority = 1  # Growth
			Enums.CivState.STABLE:
				var roll := GameState.sim_rng.randf()
				if civ.aggression_bias > 0.7 and roll < 0.4:
					new_priority = 3  # Military
				elif civ.economy_bias > 0.7 and roll < 0.5:
					new_priority = 2  # Production
				elif civ.expansion_bias > 0.7 and roll < 0.5:
					new_priority = 1  # Growth
				# else stays 0 (Balanced)
		if new_priority != civ.spending_priority:
			civ.spending_priority = new_priority
			civ.spending_priority_cooldown = Constants.SPENDING_PRIORITY_COOLDOWN_YEARS


static func _resource_value(region: RegionData) -> int:
	## Estimates total resource value of a region (deposits + terrain yields).
	var value := 0
	for res_type in region.resource_deposits:
		@warning_ignore("integer_division")
		value += region.resource_deposits[res_type] / 100  # normalize large deposit values
	var terrain_key: int = region.terrain_type
	if Constants.RESOURCE_TERRAIN_YIELDS.has(terrain_key):
		for res_type in Constants.RESOURCE_TERRAIN_YIELDS[terrain_key]:
			value += Constants.RESOURCE_TERRAIN_YIELDS[terrain_key][res_type]
	return value


static func _try_seek_nap(civ: CivilizationData) -> Array[Dictionary]:
	## AI seeks non-aggression pacts with non-hostile neighbors.
	if civ.stability < 40.0:
		return []

	var neighbor_ids := GameState.get_neighboring_civs(civ.id)
	for neighbor_id in neighbor_ids:
		if civ.war_targets.has(neighbor_id):
			continue
		if civ.alliance_partners.has(neighbor_id):
			continue
		if civ.nap_partners.has(neighbor_id):
			continue

		var neighbor := GameState.get_civilization(neighbor_id)
		if not neighbor or neighbor.is_collapsed:
			continue

		var nap_chance := Constants.NAP_BASE_CHANCE * civ.diplomacy_bias * neighbor.diplomacy_bias

		if GameState.sim_rng.randf() < nap_chance:
			civ.nap_partners[neighbor_id] = Constants.NAP_DURATION
			neighbor.nap_partners[civ.id] = Constants.NAP_DURATION
			return [{
				"type": "nap_formed",
				"civ_a_id": civ.id,
				"civ_b_id": neighbor_id,
				"civ_a_name": civ.civ_name,
				"civ_b_name": neighbor.civ_name,
			}]

	return []


static func _try_seek_trade(civ: CivilizationData) -> Array[Dictionary]:
	## AI seeks trade agreements with non-hostile civs.
	## Bonus chance if allied or NAP'd.
	if civ.stability < Constants.TRADE_STABILITY_THRESHOLD:
		return []

	for other in GameState.civilizations.values():
		if other.id == civ.id or other.is_collapsed:
			continue
		if civ.war_targets.has(other.id):
			continue
		if civ.trade_partners.has(other.id):
			continue

		var trade_chance: float = Constants.TRADE_BASE_CHANCE * civ.economy_bias * other.economy_bias
		if civ.alliance_partners.has(other.id):
			trade_chance += 0.04
		elif civ.nap_partners.has(other.id):
			trade_chance += 0.02

		if GameState.sim_rng.randf() < trade_chance:
			civ.trade_partners.append(other.id)
			other.trade_partners.append(civ.id)
			return [{
				"type": "trade_formed",
				"civ_a_id": civ.id,
				"civ_b_id": other.id,
				"civ_a_name": civ.civ_name,
				"civ_b_name": other.civ_name,
			}]

	return []


static func _try_demand_tribute(civ: CivilizationData) -> Array[Dictionary]:
	## Strong AI demands production from weaker neighbors.
	if civ.stability < 50.0:
		return []

	var neighbor_ids := GameState.get_neighboring_civs(civ.id)
	for neighbor_id in neighbor_ids:
		if civ.alliance_partners.has(neighbor_id):
			continue
		if civ.nap_partners.has(neighbor_id):
			continue
		if civ.tribute_cooldowns.get(neighbor_id, 0) > 0:
			continue

		var neighbor := GameState.get_civilization(neighbor_id)
		if not neighbor or neighbor.is_collapsed:
			continue

		var strength_ratio := civ.military_strength / maxf(neighbor.military_strength, 1.0)
		if strength_ratio < Constants.TRIBUTE_STRENGTH_RATIO:
			continue

		var demand_chance := Constants.TRIBUTE_BASE_CHANCE * civ.aggression_bias
		if GameState.sim_rng.randf() < demand_chance:
			civ.tribute_cooldowns[neighbor_id] = Constants.TRIBUTE_COOLDOWN_YEARS
			neighbor.tribute_cooldowns[civ.id] = Constants.TRIBUTE_COOLDOWN_YEARS

			# Acceptance: weaker civ with high diplomacy more likely to accept
			var accept_chance := 0.3 + neighbor.diplomacy_bias * 0.3
			var accepted: bool = GameState.sim_rng.randf() < accept_chance

			var events: Array[Dictionary] = []
			if accepted:
				var amount := mini(Constants.TRIBUTE_PRODUCTION_AMOUNT, neighbor.production_stockpile)
				neighbor.production_stockpile -= amount
				civ.production_stockpile += amount
				events.append({
					"type": "tribute_demanded",
					"demander_id": civ.id,
					"target_id": neighbor_id,
					"demander_name": civ.civ_name,
					"target_name": neighbor.civ_name,
					"accepted": true,
					"amount": amount,
				})
			else:
				events.append({
					"type": "tribute_demanded",
					"demander_id": civ.id,
					"target_id": neighbor_id,
					"demander_name": civ.civ_name,
					"target_name": neighbor.civ_name,
					"accepted": false,
				})
				# Refused tribute may lead to war
				var war_chance := Constants.TRIBUTE_REFUSAL_WAR_CHANCE * civ.aggression_bias
				if GameState.sim_rng.randf() < war_chance:
					if not civ.war_targets.has(neighbor_id):
						civ.war_targets.append(neighbor_id)
						neighbor.war_targets.append(civ.id)
						civ.war_durations[neighbor_id] = 0
						neighbor.war_durations[civ.id] = 0
						events.append({
							"type": "war_declared",
							"attacker_id": civ.id,
							"defender_id": neighbor_id,
							"attacker_name": civ.civ_name,
							"defender_name": neighbor.civ_name,
						})
			return events

	return []
