class_name VictoryChecker
extends RefCounted

## Checks victory and defeat conditions for civilizations.
## Pure static class — returns data, no signals.

# Victory thresholds
const DOMINATION_REGION_PERCENT := 0.60  # 60% of all regions
const CULTURAL_MIN_AVG_TIER := 3.0
const CULTURAL_MIN_REGIONS := 8

# Defeat conditions checked by is_collapsed and territory count


static func check_victory(civ: CivilizationData) -> Dictionary:
	## Returns victory dict if civ has won, empty dict otherwise.
	## Priority: domination > cultural > federation.
	if civ.is_collapsed:
		return {}

	var owned_regions := GameState.get_regions_by_owner(civ.id)
	var region_count := owned_regions.size()
	var total_regions := GameState.regions.size()

	# Domination: own >= 60% of all regions
	if total_regions > 0 and float(region_count) / float(total_regions) >= DOMINATION_REGION_PERCENT:
		return {
			"victory_type": "domination",
			"civ_id": civ.id,
			"civ_name": civ.civ_name,
			"regions_owned": region_count,
			"regions_total": total_regions,
		}

	# Cultural: average dev tier >= 3.0 across 8+ owned regions
	if region_count >= CULTURAL_MIN_REGIONS:
		var tier_sum := 0.0
		for region in owned_regions:
			tier_sum += float(region.development_tier)
		var avg_tier := tier_sum / float(region_count)
		if avg_tier >= CULTURAL_MIN_AVG_TIER:
			return {
				"victory_type": "cultural",
				"civ_id": civ.id,
				"civ_name": civ.civ_name,
				"avg_dev_tier": avg_tier,
				"region_count": region_count,
			}

	# Federation: governance tier == FEDERATION + 2+ alliance partners
	if civ.governance_tier == Enums.GovernanceTier.FEDERATION and civ.alliance_partners.size() >= 2:
		return {
			"victory_type": "federation",
			"civ_id": civ.id,
			"civ_name": civ.civ_name,
			"alliance_count": civ.alliance_partners.size(),
		}

	return {}


static func get_progress(civ: CivilizationData) -> Dictionary:
	## Returns progress toward all 3 victory conditions as percentages.
	var owned_regions := GameState.get_regions_by_owner(civ.id)
	var region_count := owned_regions.size()
	var total_regions := maxi(GameState.regions.size(), 1)

	# Domination: 60% of all regions
	var dom_target := ceili(float(total_regions) * DOMINATION_REGION_PERCENT)
	var dom_pct := clampf(float(region_count) / float(dom_target), 0.0, 1.0)

	# Cultural: avg dev tier >= 3.0 across 8+ regions
	var tier_sum := 0.0
	for region in owned_regions:
		tier_sum += float(region.development_tier)
	var avg_tier := tier_sum / maxf(float(region_count), 1.0)
	var tier_pct := clampf(avg_tier / CULTURAL_MIN_AVG_TIER, 0.0, 1.0)
	var region_pct := clampf(float(region_count) / float(CULTURAL_MIN_REGIONS), 0.0, 1.0)
	var cultural_pct := tier_pct * region_pct

	# Federation: FEDERATION governance + 2 allies
	var gov_target: int = Enums.GovernanceTier.FEDERATION
	var gov_pct := clampf(float(civ.governance_tier) / float(gov_target), 0.0, 1.0)
	var ally_pct := clampf(float(civ.alliance_partners.size()) / 2.0, 0.0, 1.0)
	var federation_pct := (gov_pct + ally_pct) / 2.0

	return {
		"domination": {"current": region_count, "target": dom_target, "pct": dom_pct},
		"cultural": {"avg_tier": avg_tier, "qualifying_regions": region_count, "target_tier": CULTURAL_MIN_AVG_TIER, "target_regions": CULTURAL_MIN_REGIONS, "pct": cultural_pct},
		"federation": {"governance_tier": civ.governance_tier, "target_tier": gov_target, "allies": civ.alliance_partners.size(), "target_allies": 2, "pct": federation_pct},
	}


static func check_defeat(civ: CivilizationData) -> Dictionary:
	## Returns defeat dict if civ has been defeated, empty dict otherwise.
	if civ.is_collapsed:
		return {
			"defeat_reason": "collapse",
			"civ_id": civ.id,
			"civ_name": civ.civ_name,
		}

	var owned_regions := GameState.get_regions_by_owner(civ.id)
	if owned_regions.is_empty():
		return {
			"defeat_reason": "no_territory",
			"civ_id": civ.id,
			"civ_name": civ.civ_name,
		}

	return {}
