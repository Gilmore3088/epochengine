extends GutTest

## Tests for TechEmergence (core/simulation/tech_emergence.gd)


func _make_civ(
	knowledge: float = 0.0,
	energy: float = 0.0,
	social: float = 0.0,
	economic: float = 0.0,
	military: float = 0.0,
) -> CivilizationData:
	var civ := CivilizationData.new(0, "TestCiv", Color.RED)
	civ.knowledge = knowledge
	civ.energy = energy
	civ.social_coordination = social
	civ.economic_surplus = economic
	civ.military_pressure = military
	civ.total_population = 5000
	civ.food_stockpile = 100
	civ.production_stockpile = 100
	civ.stability = 50.0
	return civ


# --- Threshold Checks ---

func test_no_tech_when_metrics_zero() -> void:
	var civ := _make_civ()
	var techs := TechEmergence.check_emergence(civ)
	assert_eq(techs.size(), 0, "No techs should emerge with zero metrics")


func test_irrigation_can_emerge() -> void:
	# Irrigation needs: knowledge >= 20, social >= 30, economic >= 20
	var civ := _make_civ(30.0, 0.0, 40.0, 30.0, 0.0)

	var emerged := false
	for i in 200:
		seed(i)
		civ.technologies = []  # Reset
		var techs := TechEmergence.check_emergence(civ)
		if techs.has("Irrigation"):
			emerged = true
			break

	assert_true(emerged, "Irrigation should eventually emerge with high metrics")


func test_tech_not_discovered_twice() -> void:
	var civ := _make_civ(30.0, 0.0, 40.0, 30.0, 0.0)
	civ.technologies = ["Irrigation"]

	# With Irrigation already discovered, it shouldn't emerge again
	for i in 100:
		seed(i)
		var techs := TechEmergence.check_emergence(civ)
		assert_false(techs.has("Irrigation"),
			"Already-discovered tech should not emerge again")


func test_advanced_tech_needs_high_metrics() -> void:
	# Steam Power needs: knowledge >= 60, energy >= 60, social >= 40, economic >= 50
	var civ_low := _make_civ(30.0, 30.0, 20.0, 25.0, 0.0)
	var civ_high := _make_civ(70.0, 70.0, 50.0, 60.0, 0.0)

	var low_discovered := false
	var high_discovered := false

	for i in 200:
		seed(i)
		civ_low.technologies = []
		if TechEmergence.check_emergence(civ_low).has("Steam Power"):
			low_discovered = true

		civ_high.technologies = []
		if TechEmergence.check_emergence(civ_high).has("Steam Power"):
			high_discovered = true

	assert_false(low_discovered, "Low metrics should not discover Steam Power")
	assert_true(high_discovered, "High metrics should discover Steam Power")


# --- Hidden Metric Updates ---

func test_metrics_grow_with_population() -> void:
	var civ := _make_civ()
	civ.total_population = 10000
	civ.stability = 80.0
	var regions: Array[RegionData] = [
		RegionData.new(0, "R1", Enums.TerrainType.PLAINS),
	]
	regions[0].owner_id = 0

	var old_knowledge := civ.knowledge
	TechEmergence.update_hidden_metrics(civ, regions)

	assert_true(civ.knowledge > old_knowledge,
		"Knowledge should grow with population and stability")


func test_metrics_clamped_to_max() -> void:
	var civ := _make_civ(99.0, 99.0, 99.0, 99.0, 99.0)
	civ.total_population = 100000
	civ.stability = 100.0
	civ.food_stockpile = 10000
	civ.production_stockpile = 10000
	civ.military_strength = 10000.0
	civ.war_targets = [1, 2, 3]

	var regions: Array[RegionData] = []
	for i in 20:
		var r := RegionData.new(i, "R%d" % i, Enums.TerrainType.PLAINS)
		r.owner_id = 0
		regions.append(r)

	TechEmergence.update_hidden_metrics(civ, regions)

	assert_true(civ.knowledge <= Constants.TECH_METRIC_MAX)
	assert_true(civ.energy <= Constants.TECH_METRIC_MAX)
	assert_true(civ.social_coordination <= Constants.TECH_METRIC_MAX)
	assert_true(civ.economic_surplus <= Constants.TECH_METRIC_MAX)
	assert_true(civ.military_pressure <= Constants.TECH_METRIC_MAX)


func test_golden_age_boosts_social() -> void:
	var civ := _make_civ(0.0, 0.0, 0.0, 0.0, 0.0)
	civ.total_population = 5000
	civ.stability = 80.0
	var regions: Array[RegionData] = [
		RegionData.new(0, "R1", Enums.TerrainType.PLAINS),
	]
	regions[0].owner_id = 0

	TechEmergence.update_hidden_metrics(civ, regions)
	var normal_social := civ.social_coordination

	civ.social_coordination = 0.0
	civ.golden_age_years_remaining = 10
	TechEmergence.update_hidden_metrics(civ, regions)
	var golden_social := civ.social_coordination

	assert_true(golden_social > normal_social,
		"Golden age should boost social coordination growth")


func test_metrics_decay_with_low_pop() -> void:
	var civ := _make_civ(50.0, 50.0, 0.0, 0.0, 0.0)
	civ.total_population = 1000  # Below 5000 threshold
	civ.stability = 50.0

	var regions: Array[RegionData] = [
		RegionData.new(0, "R1", Enums.TerrainType.TUNDRA),  # Low production
	]
	regions[0].owner_id = 0

	TechEmergence.update_hidden_metrics(civ, regions)

	# Knowledge should have been decayed slightly (growth - 0.05)
	# Hard to assert exact value due to growth + decay interaction,
	# but with very low pop, the net should be minimal
	assert_true(civ.knowledge <= 50.1,
		"Knowledge should barely grow or decay with low population")


# --- Research Focus ---

func test_research_focus_default_balanced() -> void:
	var civ := _make_civ()
	assert_eq(civ.research_focus, 0, "Default research focus should be 0 (Balanced)")
	assert_eq(civ.research_focus_cooldown, 0, "Default cooldown should be 0")


func test_research_focus_boosts_knowledge() -> void:
	var civ_normal := _make_civ()
	civ_normal.total_population = 10000
	civ_normal.stability = 80.0
	var regions: Array[RegionData] = [
		RegionData.new(0, "R1", Enums.TerrainType.PLAINS),
	]
	regions[0].owner_id = 0

	TechEmergence.update_hidden_metrics(civ_normal, regions)
	var knowledge_normal := civ_normal.knowledge

	var civ_focused := _make_civ()
	civ_focused.total_population = 10000
	civ_focused.stability = 80.0
	civ_focused.research_focus = 1  # Knowledge focus

	TechEmergence.update_hidden_metrics(civ_focused, regions)
	var knowledge_focused := civ_focused.knowledge

	assert_true(knowledge_focused > knowledge_normal,
		"Knowledge focus should produce higher knowledge growth (%.3f vs %.3f)" % [knowledge_focused, knowledge_normal])
	# Should be approximately 2x the growth
	assert_almost_eq(knowledge_focused, knowledge_normal * 2.0, 0.01)


# --- Tech Proximity ---

func test_next_tech_proximity_sorted() -> void:
	# Civ close to Irrigation (knowledge 20, social 30, economic 20)
	var civ := _make_civ(18.0, 0.0, 28.0, 19.0, 0.0)
	var results := TechEmergence.get_next_tech_proximity(civ)
	assert_true(results.size() > 0, "Should have undiscovered techs")
	# Results should be sorted by fewest gaps first
	for i in range(results.size() - 1):
		assert_true(results[i]["gaps"].size() <= results[i + 1]["gaps"].size(),
			"Results should be sorted by gap count ascending")
	# Irrigation should be near the top (3 gaps, all close)
	var irrigation_found := false
	for entry in results:
		if entry["name"] == "Irrigation":
			irrigation_found = true
			assert_eq(entry["gaps"].size(), 3, "Irrigation should have 3 gaps")
			break
	assert_true(irrigation_found, "Irrigation should appear in results")


func test_next_tech_proximity_empty_when_all_discovered() -> void:
	var civ := _make_civ(100.0, 100.0, 100.0, 100.0, 100.0)
	# Discover all techs
	for tech in TechEmergence.TECH_TABLE:
		civ.technologies.append(tech["name"])
	var results := TechEmergence.get_next_tech_proximity(civ)
	assert_eq(results.size(), 0, "No proximity info when all techs discovered")


func test_research_focus_cooldown_decrements() -> void:
	var civ := _make_civ()
	civ.total_population = 10000
	civ.stability = 50.0
	civ.research_focus_cooldown = 3
	var regions: Array[RegionData] = [
		RegionData.new(0, "R1", Enums.TerrainType.PLAINS),
	]
	regions[0].owner_id = 0

	TechEmergence.update_hidden_metrics(civ, regions)
	assert_eq(civ.research_focus_cooldown, 2, "Cooldown should decrement by 1 per turn")

	TechEmergence.update_hidden_metrics(civ, regions)
	assert_eq(civ.research_focus_cooldown, 1)

	TechEmergence.update_hidden_metrics(civ, regions)
	assert_eq(civ.research_focus_cooldown, 0)

	TechEmergence.update_hidden_metrics(civ, regions)
	assert_eq(civ.research_focus_cooldown, 0, "Should not go negative")


func test_era_change_at_three_techs() -> void:
	# 2 techs = Prehistoric, 3 techs = Classical
	assert_eq(TechEmergence.compute_era(2), Enums.Epoch.PREHISTORIC,
		"2 techs should be Prehistoric")
	assert_eq(TechEmergence.compute_era(3), Enums.Epoch.CLASSICAL,
		"3 techs should be Classical")


func test_era_no_change_within_same_tier() -> void:
	# 0-2 techs all Prehistoric — no era change
	for i in range(3):
		assert_eq(TechEmergence.compute_era(i), Enums.Epoch.PREHISTORIC,
			"%d techs should be Prehistoric" % i)


func test_tech_table_entries_have_names() -> void:
	assert_gt(TechEmergence.TECH_TABLE.size(), 0, "TECH_TABLE should not be empty")
	for tech in TechEmergence.TECH_TABLE:
		assert_true(tech.has("name"), "Each tech entry must have a 'name' key")
		assert_true(tech["name"] is String, "Tech name must be a String")
		assert_gt(tech["name"].length(), 0, "Tech name must not be empty")
