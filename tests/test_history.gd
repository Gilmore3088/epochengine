extends GutTest

## Tests for History behavior (per-year stability, load reset)

const TEST_SLOT := "test_history_load"


func after_each() -> void:
	SaveManager.delete_save(TEST_SLOT)
	History.clear()


func _empty_events() -> Dictionary:
	return {
		"population_changes": [],
		"economy_results": [],
		"stability_changes": [],
		"collapses": [],
		"ai_events": [],
		"battles": [],
		"owner_changes": [],
		"dead_heroes": [],
		"spawned_heroes": [],
		"golden_age_starts": [],
		"golden_age_ends": [],
		"tech_emergences": [],
		"era_changes": [],
		"governance_changes": [],
		"development_tier_changes": [],
		"resource_events": [],
		"town_events": [],
		"victory_events": [],
	}


func test_stability_recorded_each_year() -> void:
	GameState.civilizations.clear()
	var civ := CivilizationData.new(0, "TestCiv", Color.RED)
	civ.stability = 55.0
	GameState.civilizations[civ.id] = civ

	History.clear()

	GameState.current_year = 1
	TurnManager._emit_events(_empty_events())

	GameState.current_year = 2
	TurnManager._emit_events(_empty_events())

	var trend := History.get_stability_trend(civ.id, 10)
	assert_eq(trend.size(), 2)
	assert_eq(trend[0]["year"], 1)
	assert_eq(trend[1]["year"], 2)
	assert_eq(trend[0]["value"], 55.0)
	assert_eq(trend[1]["value"], 55.0)


func test_history_cleared_on_load() -> void:
	# Minimal state for save/load
	GameState.regions.clear()
	GameState.civilizations.clear()
	GameState.heroes.clear()

	var region := RegionData.new(0, "Test Region", Enums.TerrainType.PLAINS)
	region.owner_id = 0
	GameState.regions[region.id] = region

	var civ := CivilizationData.new(0, "TestCiv", Color.RED)
	GameState.civilizations[civ.id] = civ

	History.record_event({
		"year": 1, "type": "tech",
		"civ_id": 0, "civ_name": "TestCiv",
		"description": "Test event",
	})
	assert_true(History.events.size() == 1)

	SaveManager.save_game(TEST_SLOT)
	SaveManager.load_game(TEST_SLOT)

	assert_eq(History.events.size(), 0)
