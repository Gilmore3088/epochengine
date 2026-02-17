class_name TechEmergence
extends RefCounted

## Hidden tech emergence system. Technologies emerge from systemic thresholds.
## Logic from docs/systems/tech_emergence.md

# Tech definitions: {name: {thresholds + effect description}}
const TECH_TABLE: Array[Dictionary] = [
	{
		"name": "Irrigation",
		"knowledge": 20, "energy": 0, "social": 30, "economic": 20, "military": 0,
		"base_probability": 0.15,
	},
	{
		"name": "Bronze Working",
		"knowledge": 30, "energy": 20, "social": 0, "economic": 0, "military": 30,
		"base_probability": 0.12,
	},
	{
		"name": "Writing",
		"knowledge": 40, "energy": 0, "social": 40, "economic": 30, "military": 0,
		"base_probability": 0.10,
	},
	{
		"name": "Iron Working",
		"knowledge": 40, "energy": 30, "social": 0, "economic": 20, "military": 40,
		"base_probability": 0.10,
	},
	{
		"name": "Gunpowder",
		"knowledge": 50, "energy": 40, "social": 0, "economic": 0, "military": 60,
		"base_probability": 0.08,
	},
	{
		"name": "Printing Press",
		"knowledge": 55, "energy": 0, "social": 50, "economic": 40, "military": 0,
		"base_probability": 0.08,
	},
	{
		"name": "Steam Power",
		"knowledge": 60, "energy": 60, "social": 40, "economic": 50, "military": 0,
		"base_probability": 0.06,
	},
	{
		"name": "Electricity",
		"knowledge": 65, "energy": 65, "social": 45, "economic": 55, "military": 0,
		"base_probability": 0.05,
	},
	{
		"name": "Advanced Weapons",
		"knowledge": 50, "energy": 40, "social": 0, "economic": 60, "military": 70,
		"base_probability": 0.05,
	},
	{
		"name": "Fusion Research",
		"knowledge": 70, "energy": 60, "social": 0, "economic": 50, "military": 0,
		"base_probability": 0.03,
	},
]


static func compute_era(tech_count: int) -> Enums.Epoch:
	## Derive the civilization's era from the number of discovered technologies.
	if tech_count >= Constants.ERA_TECH_THRESHOLDS[3]:
		return Enums.Epoch.FUTURE
	if tech_count >= Constants.ERA_TECH_THRESHOLDS[2]:
		return Enums.Epoch.INDUSTRIAL
	if tech_count >= Constants.ERA_TECH_THRESHOLDS[1]:
		return Enums.Epoch.CLASSICAL
	return Enums.Epoch.PREHISTORIC


static func check_emergence(civ: CivilizationData) -> Array[String]:
	## Check all techs and return names of any that emerge this year.
	var emerged: Array[String] = []

	for tech in TECH_TABLE:
		if civ.technologies.has(tech["name"]):
			continue

		if _meets_thresholds(civ, tech):
			var probability: float = tech["base_probability"]
			# Pressure multiplier: higher metrics increase chance
			var pressure := _pressure_multiplier(civ, tech)
			var roll := GameState.sim_rng.randf()

			if roll < probability * pressure:
				emerged.append(tech["name"])
				civ.technologies.append(tech["name"])

	return emerged


static func update_hidden_metrics(
	civ: CivilizationData, owned_regions: Array[RegionData]
) -> void:
	## Update hidden metrics based on civilization state.
	var total_production := 0
	for region in owned_regions:
		total_production += region.production_yield

	# Compute all growth values first
	var knowledge_growth := 0.3 * (float(civ.total_population) / 10000.0) * (civ.stability / 100.0)
	var energy_growth := 0.2 * (float(total_production) / 10.0)
	var region_count := maxf(owned_regions.size(), 1.0)
	var density := float(civ.total_population) / region_count
	var social_growth := 0.2 * (civ.stability / 100.0) * clampf(density / 2000.0, 0.1, 2.0)
	if civ.is_in_golden_age():
		social_growth *= 1.5
	var surplus_signal := float(civ.food_stockpile + civ.production_stockpile) / 100.0
	var econ_growth := 0.2 * clampf(surplus_signal, -0.5, 1.0)
	var war_factor := float(civ.war_targets.size()) * 0.5
	var army_factor := clampf(civ.military_strength / 300.0, 0.0, 1.0)
	var mil_growth := 0.2 * (war_factor + army_factor)

	# Apply research focus boost (+100% to focused metric)
	if civ.research_focus > 0:
		var focus_mult := 1.0 + Constants.RESEARCH_FOCUS_BOOST
		match civ.research_focus:
			1: knowledge_growth *= focus_mult
			2: energy_growth *= focus_mult
			3: social_growth *= focus_mult
			4: econ_growth *= focus_mult
			5: mil_growth *= focus_mult

	# Apply all growths to civ metrics
	civ.knowledge = clampf(civ.knowledge + knowledge_growth, Constants.TECH_METRIC_MIN, Constants.TECH_METRIC_MAX)
	civ.energy = clampf(civ.energy + energy_growth, Constants.TECH_METRIC_MIN, Constants.TECH_METRIC_MAX)
	civ.social_coordination = clampf(civ.social_coordination + social_growth, Constants.TECH_METRIC_MIN, Constants.TECH_METRIC_MAX)
	civ.economic_surplus = clampf(civ.economic_surplus + econ_growth, Constants.TECH_METRIC_MIN, Constants.TECH_METRIC_MAX)
	civ.military_pressure = clampf(civ.military_pressure + mil_growth, Constants.TECH_METRIC_MIN, Constants.TECH_METRIC_MAX)

	# Decrement research focus cooldown
	if civ.research_focus_cooldown > 0:
		civ.research_focus_cooldown -= 1

	# Decay: metrics drop slightly if their drivers are weak
	if civ.total_population < 5000:
		civ.knowledge = maxf(civ.knowledge - 0.05, 0.0)
	if total_production < 5:
		civ.energy = maxf(civ.energy - 0.05, 0.0)


static func get_next_tech_proximity(civ: CivilizationData) -> Array[Dictionary]:
	## Returns proximity info for each undiscovered tech.
	## [{name, all_met: bool, gaps: [{metric, current, needed}]}]
	## Sorted by fewest unmet gaps first (closest techs first).
	var results: Array[Dictionary] = []
	for tech in TECH_TABLE:
		if civ.technologies.has(tech["name"]):
			continue
		var gaps: Array[Dictionary] = []
		if tech["knowledge"] > 0 and civ.knowledge < float(tech["knowledge"]):
			gaps.append({"metric": "Knowledge", "current": civ.knowledge, "needed": float(tech["knowledge"])})
		if tech["energy"] > 0 and civ.energy < float(tech["energy"]):
			gaps.append({"metric": "Energy", "current": civ.energy, "needed": float(tech["energy"])})
		if tech["social"] > 0 and civ.social_coordination < float(tech["social"]):
			gaps.append({"metric": "Social", "current": civ.social_coordination, "needed": float(tech["social"])})
		if tech["economic"] > 0 and civ.economic_surplus < float(tech["economic"]):
			gaps.append({"metric": "Economic", "current": civ.economic_surplus, "needed": float(tech["economic"])})
		if tech["military"] > 0 and civ.military_pressure < float(tech["military"]):
			gaps.append({"metric": "Military", "current": civ.military_pressure, "needed": float(tech["military"])})
		results.append({"name": tech["name"], "all_met": gaps.is_empty(), "gaps": gaps})
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["gaps"].size() < b["gaps"].size()
	)
	return results


static func _meets_thresholds(civ: CivilizationData, tech: Dictionary) -> bool:
	if tech["knowledge"] > 0 and civ.knowledge < tech["knowledge"]:
		return false
	if tech["energy"] > 0 and civ.energy < tech["energy"]:
		return false
	if tech["social"] > 0 and civ.social_coordination < tech["social"]:
		return false
	if tech["economic"] > 0 and civ.economic_surplus < tech["economic"]:
		return false
	if tech["military"] > 0 and civ.military_pressure < tech["military"]:
		return false
	return true


static func _pressure_multiplier(civ: CivilizationData, tech: Dictionary) -> float:
	## Higher overshoot of thresholds increases emergence chance.
	var overshoot := 0.0
	var count := 0

	if tech["knowledge"] > 0:
		overshoot += (civ.knowledge - tech["knowledge"]) / tech["knowledge"]
		count += 1
	if tech["energy"] > 0:
		overshoot += (civ.energy - tech["energy"]) / tech["energy"]
		count += 1
	if tech["social"] > 0:
		overshoot += (civ.social_coordination - tech["social"]) / tech["social"]
		count += 1
	if tech["economic"] > 0:
		overshoot += (civ.economic_surplus - tech["economic"]) / tech["economic"]
		count += 1
	if tech["military"] > 0:
		overshoot += (civ.military_pressure - tech["military"]) / tech["military"]
		count += 1

	if count == 0:
		return 1.0

	var avg_overshoot := overshoot / float(count)
	return clampf(1.0 + avg_overshoot, 1.0, 3.0)
