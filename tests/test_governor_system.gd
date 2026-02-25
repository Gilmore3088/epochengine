extends GutTest

## Tests for GovernorSimulation


func _make_region(
	region_id: int,
	terrain: Enums.TerrainType = Enums.TerrainType.PLAINS,
	owner_id: int = 0,
) -> RegionData:
	var region := RegionData.new(region_id, "Region_%d" % region_id, terrain)
	region.owner_id = owner_id
	region.population = 2000
	region.infrastructure_level = 2
	region.development_tier = 2
	return region


func _make_civ(civ_id: int = 0) -> CivilizationData:
	var civ := CivilizationData.new(civ_id, "TestCiv", Color.RED)
	civ.capital_region_id = 0
	civ.stability = 50.0
	civ.total_population = 5000
	return civ


func before_each() -> void:
	GameState.regions.clear()
	GameState.civilizations.clear()
	GameState.sim_rng.seed = 42


func test_influence_calculation() -> void:
	var civ := _make_civ()
	GameState.civilizations[0] = civ

	var r0 := _make_region(0)
	r0.population = 5000
	var r1 := _make_region(1)
	r1.population = 1000
	GameState.regions[0] = r0
	GameState.regions[1] = r1

	var events := {}
	GovernorSimulation.process_governors(events)

	# Capital with higher pop should have higher influence
	assert_gt(r0.political_influence, r1.political_influence,
		"Capital with more pop should have higher influence")


func test_capital_gets_max_influence() -> void:
	var civ := _make_civ()
	GameState.civilizations[0] = civ

	var r0 := _make_region(0)
	r0.population = 1000  # Lower pop but is capital
	var r1 := _make_region(1)
	r1.population = 1000  # Same pop, not capital
	r1.infrastructure_level = r0.infrastructure_level
	r1.development_tier = r0.development_tier
	GameState.regions[0] = r0
	GameState.regions[1] = r1

	var events := {}
	GovernorSimulation.process_governors(events)

	# Capital bonus should give r0 higher influence
	assert_gt(r0.political_influence, r1.political_influence,
		"Capital should get influence bonus")


func test_lobby_request_generation() -> void:
	var civ := _make_civ()
	GameState.civilizations[0] = civ

	var r0 := _make_region(0)
	r0.population = 5000  # High pop = high influence
	r0.infrastructure_level = 3
	r0.development_tier = 3
	GameState.regions[0] = r0

	# Run many turns to eventually get a lobby request
	var got_lobby := false
	for _i in 50:
		r0.lobby_request = -1
		r0.lobby_ignore_years = 0
		var events := {}
		GovernorSimulation.process_governors(events)
		if r0.lobby_request >= 0:
			got_lobby = true
			break

	assert_true(got_lobby, "High-influence region should eventually get lobby request")


func test_ignored_lobby_stability_penalty() -> void:
	var civ := _make_civ()
	GameState.civilizations[0] = civ

	var r0 := _make_region(0)
	r0.lobby_request = Enums.GovernorFocus.GROWTH
	r0.lobby_ignore_years = 0
	GameState.regions[0] = r0

	var events := {}
	var mods := GovernorSimulation.process_governors(events)

	# Should have negative stability modifier (lobby penalty + capital bonus)
	var net_mod: float = mods.get(0, 0.0)
	# Capital bonus is +5, lobby penalty is -2 per ignored region
	assert_true(net_mod < Constants.CAPITAL_STABILITY_BONUS,
		"Ignored lobby should reduce net stability modifier")
	assert_eq(r0.lobby_ignore_years, 1, "Ignore years should increment")


func test_fulfill_lobby_returns_bonus() -> void:
	var region := _make_region(0)
	region.lobby_request = Enums.GovernorFocus.MILITARY
	region.lobby_ignore_years = 3

	var bonus := GovernorSimulation.fulfill_lobby(region)

	assert_eq(region.lobby_request, -1, "Lobby should be cleared")
	assert_eq(region.lobby_ignore_years, 0, "Ignore years should reset")
	assert_gt(bonus, 0.0, "Should return positive stability bonus")


func test_collapsed_civ_skipped() -> void:
	var civ := _make_civ()
	civ.is_collapsed = true
	GameState.civilizations[0] = civ

	var r0 := _make_region(0)
	GameState.regions[0] = r0

	var events := {}
	var mods := GovernorSimulation.process_governors(events)

	assert_false(mods.has(0), "Collapsed civ should be skipped")
