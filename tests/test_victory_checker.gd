extends GutTest

## Tests for VictoryChecker victory/defeat conditions.


func before_each() -> void:
	GameState.regions.clear()
	GameState.civilizations.clear()


func _make_civ(id: int = 0) -> CivilizationData:
	var civ := CivilizationData.new(id, "TestCiv%d" % id, Color.RED)
	civ.stability = 50.0
	GameState.civilizations[civ.id] = civ
	return civ


func _make_regions(count: int, owner_id: int = 0) -> Array[RegionData]:
	var start_id := GameState.regions.size()
	var result: Array[RegionData] = []
	for i in range(count):
		var rid := start_id + i
		var region := RegionData.new(rid, "Region%d" % rid, Enums.TerrainType.PLAINS)
		region.owner_id = owner_id
		region.population = 1000
		GameState.regions[region.id] = region
		result.append(region)
	return result


# --- Victory Tests ---

func test_no_victory_initially() -> void:
	var civ := _make_civ()
	_make_regions(5, civ.id)
	_make_regions(10, -1)  # 5/15 = 33%, no domination
	var result := VictoryChecker.check_victory(civ)
	assert_true(result.is_empty(), "No victory with 5 of 15 regions")


func test_domination_victory() -> void:
	var civ := _make_civ()
	# 10 total regions, 7 owned = 70% > 60% threshold
	for i in range(10):
		var region := RegionData.new(i, "Region%d" % i, Enums.TerrainType.PLAINS)
		region.population = 1000
		if i < 7:
			region.owner_id = civ.id
		else:
			region.owner_id = -1
		GameState.regions[region.id] = region

	var result := VictoryChecker.check_victory(civ)
	assert_false(result.is_empty(), "Should have victory")
	assert_eq(result["victory_type"], "domination")
	assert_eq(result["regions_owned"], 7)
	assert_eq(result["regions_total"], 10)


func test_no_domination_below_threshold() -> void:
	var civ := _make_civ()
	# 10 total, 5 owned = 50% < 60%
	for i in range(10):
		var region := RegionData.new(i, "Region%d" % i, Enums.TerrainType.PLAINS)
		region.population = 1000
		if i < 5:
			region.owner_id = civ.id
		else:
			region.owner_id = -1
		GameState.regions[region.id] = region

	var result := VictoryChecker.check_victory(civ)
	assert_true(result.is_empty(), "50% should not trigger domination")


func test_cultural_victory() -> void:
	var civ := _make_civ()
	# 8 owned regions at tier 3+ plus 14 neutral = 8/22 = 36%, no domination
	var regions := _make_regions(8, civ.id)
	_make_regions(14, -1)
	for region in regions:
		region.development_tier = 3

	var result := VictoryChecker.check_victory(civ)
	assert_false(result.is_empty(), "Should have cultural victory")
	assert_eq(result["victory_type"], "cultural")
	assert_eq(result["region_count"], 8)


func test_cultural_needs_min_regions() -> void:
	var civ := _make_civ()
	# 5 high-tier regions < 8 minimum; 10 neutral = 5/15 = 33%, no domination
	var regions := _make_regions(5, civ.id)
	_make_regions(10, -1)
	for region in regions:
		region.development_tier = 5

	var result := VictoryChecker.check_victory(civ)
	assert_true(result.is_empty(), "5 regions below cultural minimum of 8")


func test_federation_victory() -> void:
	var civ := _make_civ()
	civ.governance_tier = Enums.GovernanceTier.FEDERATION
	civ.alliance_partners = [1, 2]
	_make_regions(5, civ.id)
	_make_regions(10, -1)  # 5/15 = 33%, no domination

	var result := VictoryChecker.check_victory(civ)
	assert_false(result.is_empty(), "Should have federation victory")
	assert_eq(result["victory_type"], "federation")
	assert_eq(result["alliance_count"], 2)


func test_federation_needs_two_allies() -> void:
	var civ := _make_civ()
	civ.governance_tier = Enums.GovernanceTier.FEDERATION
	civ.alliance_partners = [1]  # Only 1 ally
	_make_regions(5, civ.id)
	_make_regions(10, -1)  # 5/15 = 33%, no domination

	var result := VictoryChecker.check_victory(civ)
	assert_true(result.is_empty(), "1 ally not enough for federation victory")


# --- Defeat Tests ---

func test_defeat_on_collapse() -> void:
	var civ := _make_civ()
	civ.is_collapsed = true

	var result := VictoryChecker.check_defeat(civ)
	assert_false(result.is_empty(), "Should detect defeat")
	assert_eq(result["defeat_reason"], "collapse")


func test_defeat_no_territory() -> void:
	var civ := _make_civ()
	# No regions owned by this civ
	_make_regions(3, 99)  # owned by someone else

	var result := VictoryChecker.check_defeat(civ)
	assert_false(result.is_empty(), "Should detect defeat")
	assert_eq(result["defeat_reason"], "no_territory")


func test_no_defeat_when_alive() -> void:
	var civ := _make_civ()
	_make_regions(3, civ.id)

	var result := VictoryChecker.check_defeat(civ)
	assert_true(result.is_empty(), "Should not be defeated with territory")


func test_domination_checked_first() -> void:
	# Civ qualifies for both domination and cultural - domination wins
	var civ := _make_civ()
	civ.governance_tier = Enums.GovernanceTier.FEDERATION
	civ.alliance_partners = [1, 2]

	# 10 regions, 7 owned at tier 3+ (qualifies for domination + cultural + federation)
	for i in range(10):
		var region := RegionData.new(i, "Region%d" % i, Enums.TerrainType.PLAINS)
		region.population = 1000
		region.development_tier = 3
		if i < 7:
			region.owner_id = civ.id
		else:
			region.owner_id = -1
		GameState.regions[region.id] = region

	var result := VictoryChecker.check_victory(civ)
	assert_eq(result["victory_type"], "domination", "Domination should be checked first")


# --- Victory Panel Stats Tests ---

func test_victory_panel_data_domination() -> void:
	var civ := _make_civ()
	GameState.player_civ_id = civ.id
	GameState.current_year = 150
	# Add some history events
	History.clear()
	History.record_event({"year": 50, "type": "war_declared", "attacker_id": civ.id, "defender_id": 1})
	History.record_event({"year": 80, "type": "tech", "civ_id": civ.id, "description": "Metallurgy"})
	History.record_event({"year": 100, "type": "town_founded", "civ_id": civ.id, "town_name": "TestTown"})
	_make_regions(7, civ.id)
	_make_regions(3, -1)

	var details := {"civ_id": civ.id, "civ_name": "TestCiv0", "victory_type": "domination"}
	var stats := VictoryPanel.build_stats_dict(details)
	assert_eq(stats["Years Survived"], 150)
	assert_eq(stats["Regions Owned"], 7)
	assert_eq(stats["Wars Fought"], 1)
	assert_eq(stats["Technologies"], 1)
	assert_eq(stats["Towns Founded"], 1)


func test_victory_panel_data_defeat() -> void:
	var civ := _make_civ()
	GameState.player_civ_id = civ.id
	GameState.current_year = 80
	History.clear()
	# No regions owned (defeat)
	_make_regions(5, 99)

	var details := {"civ_id": civ.id, "civ_name": "TestCiv0", "defeat_reason": "no_territory"}
	var stats := VictoryPanel.build_stats_dict(details)
	assert_eq(stats["Years Survived"], 80)
	assert_eq(stats["Regions Owned"], 0)
	assert_eq(stats["Wars Fought"], 0)


func test_victory_narratives_exist() -> void:
	var required_keys := ["domination", "cultural", "federation", "collapse", "no_territory"]
	for key in required_keys:
		assert_true(VictoryPanel.NARRATIVES.has(key), "Missing narrative for: %s" % key)
		var text: String = VictoryPanel.NARRATIVES[key]
		assert_true(text.length() > 20, "Narrative too short for: %s" % key)


# --- Victory Progress Tests ---

func test_victory_progress_domination() -> void:
	var civ := _make_civ()
	# 70 total regions, 35 owned = 50% of target (target = ceil(70*0.6) = 42)
	_make_regions(35, civ.id)
	_make_regions(35, -1)

	var progress := VictoryChecker.get_progress(civ)
	assert_true(progress.has("domination"))
	var dom: Dictionary = progress["domination"]
	assert_eq(dom["current"], 35)
	assert_eq(dom["target"], 42)
	# 35/42 ~ 0.833
	assert_almost_eq(dom["pct"], 35.0 / 42.0, 0.01)


func test_victory_progress_cultural() -> void:
	var civ := _make_civ()
	# 10 regions at tier 1.5 avg -> tier_pct = 1.5/3.0 = 0.5, region_pct = 10/8 = 1.0
	var regions := _make_regions(10, civ.id)
	for i in range(regions.size()):
		regions[i].development_tier = 1 if i % 2 == 0 else 2  # avg = 1.5
	_make_regions(10, -1)

	var progress := VictoryChecker.get_progress(civ)
	var cult: Dictionary = progress["cultural"]
	assert_almost_eq(cult["avg_tier"], 1.5, 0.01)
	assert_eq(cult["qualifying_regions"], 10)
	# pct = tier_pct * region_pct = (1.5/3.0) * min(10/8, 1.0) = 0.5 * 1.0 = 0.5
	assert_almost_eq(cult["pct"], 0.5, 0.01)


func test_victory_progress_federation() -> void:
	var civ := _make_civ()
	civ.governance_tier = Enums.GovernanceTier.KINGDOM  # tier 3 of 5
	civ.alliance_partners = [1]  # 1 of 2 needed
	_make_regions(5, civ.id)
	_make_regions(10, -1)

	var progress := VictoryChecker.get_progress(civ)
	var fed: Dictionary = progress["federation"]
	assert_eq(fed["governance_tier"], Enums.GovernanceTier.KINGDOM)
	assert_eq(fed["allies"], 1)
	# gov_pct = 3/5 = 0.6, ally_pct = 1/2 = 0.5, avg = 0.55
	assert_almost_eq(fed["pct"], 0.55, 0.01)
