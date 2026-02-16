class_name WarResolver
extends RefCounted

## Auto-resolve combat between civilizations.
## Formula from docs/systems/war_and_logistics.md


static func resolve_battle(
	attacker_civ: CivilizationData,
	defender_civ: CivilizationData,
	contested_region: RegionData,
) -> Dictionary:
	## Resolves a battle over a contested region.
	## Returns {winner_id, loser_id, attacker_strength, defender_strength}.
	var atk_strength := _calculate_strength(attacker_civ, contested_region, true)
	var def_strength := _calculate_strength(defender_civ, contested_region, false)

	var winner_id: int
	var loser_id: int

	if atk_strength > def_strength:
		winner_id = attacker_civ.id
		loser_id = defender_civ.id
	else:
		winner_id = defender_civ.id
		loser_id = attacker_civ.id

	return {
		"winner_id": winner_id,
		"loser_id": loser_id,
		"attacker_strength": atk_strength,
		"defender_strength": def_strength,
		"region_id": contested_region.id,
	}


static func apply_battle_result(
	result: Dictionary,
	attacker_civ: CivilizationData,
	defender_civ: CivilizationData,
	contested_region: RegionData,
) -> void:
	## Applies the battle result: transfers region, applies stability loss.
	var winner_id: int = result["winner_id"]
	var loser_id: int = result["loser_id"]

	var old_owner := contested_region.owner_id

	# Transfer region to winner
	contested_region.owner_id = winner_id

	# Stability loss for loser
	var stability_loss := randi_range(
		Constants.WAR_STABILITY_LOSS_MIN, Constants.WAR_STABILITY_LOSS_MAX
	)

	var loser_civ: CivilizationData
	if loser_id == attacker_civ.id:
		loser_civ = attacker_civ
	else:
		loser_civ = defender_civ

	loser_civ.stability = clampf(
		loser_civ.stability - stability_loss,
		Constants.STABILITY_MIN,
		Constants.STABILITY_MAX,
	)

	# Military attrition for both sides
	var intensity := (result["attacker_strength"] + result["defender_strength"]) / 2.0
	var attrition_ratio := clampf(intensity / 1000.0, 0.05, 0.20)
	attacker_civ.military_strength *= (1.0 - attrition_ratio)
	defender_civ.military_strength *= (1.0 - attrition_ratio * 0.7)

	# Emit signals
	EventBus.region_owner_changed.emit(contested_region.id, old_owner, winner_id)
	EventBus.battle_resolved.emit(
		contested_region.id, attacker_civ.id, defender_civ.id, winner_id
	)

	GameState.log_event("battle", {
		"region": contested_region.region_name,
		"attacker": attacker_civ.civ_name,
		"defender": defender_civ.civ_name,
		"winner": "attacker" if winner_id == attacker_civ.id else "defender",
	})


static func _calculate_strength(
	civ: CivilizationData,
	region: RegionData,
	is_attacker: bool,
) -> float:
	## Calculates effective combat strength for one side.
	var military := civ.military_strength
	var morale := _morale_from_stability(civ)
	var equipment := 1.0  # Flat in Phase 1
	var doctrine := _doctrine_modifier(civ)
	var terrain := _terrain_modifier(region, is_attacker)
	var supply := _supply_modifier(civ, region)
	var variance := randf_range(
		Constants.BATTLE_VARIANCE_MIN, Constants.BATTLE_VARIANCE_MAX
	)

	# General hero bonus
	var hero_bonus := 1.0
	for hero_id in civ.hero_ids:
		var hero: HeroData = GameState.get_hero(hero_id)
		if hero and hero.type == Enums.HeroType.GENERAL:
			hero_bonus += hero.get_modifier_value()

	return military * morale * equipment * doctrine * terrain * supply * variance * hero_bonus


static func _morale_from_stability(civ: CivilizationData) -> float:
	## Maps stability (0-100) to morale (0.5-1.2).
	var t := civ.stability / Constants.STABILITY_MAX
	return lerpf(0.5, 1.2, t)


static func _doctrine_modifier(civ: CivilizationData) -> float:
	## Flat per civilization in Phase 1. Varies by aggression bias.
	return lerpf(
		Constants.DOCTRINE_MODIFIER_MIN,
		Constants.DOCTRINE_MODIFIER_MAX,
		civ.aggression_bias,
	)


static func _terrain_modifier(region: RegionData, is_attacker: bool) -> float:
	## Defender gets terrain bonus, attacker gets penalty.
	if is_attacker:
		return 1.0 / region.defense_modifier
	else:
		return region.defense_modifier


static func _supply_modifier(civ: CivilizationData, region: RegionData) -> float:
	## Phase 1: simplified to connected/disconnected check.
	if region.owner_id == civ.id:
		return Constants.SUPPLY_MODIFIER_CONNECTED

	# Check if attacker has supply route
	var all_regions := GameState.regions
	for adj_id in region.adjacency_list:
		var adj_region: RegionData = all_regions.get(adj_id)
		if adj_region and adj_region.owner_id == civ.id:
			return Constants.SUPPLY_MODIFIER_CONNECTED

	return Constants.SUPPLY_MODIFIER_DISCONNECTED
