extends GutTest

## Tests for SaveManager save/load round-trip (autoload/save_manager.gd)

const TEST_SLOT := "test_round_trip"


func after_each() -> void:
	SaveManager.delete_save(TEST_SLOT)


func _setup_known_state() -> void:
	GameState.regions.clear()
	GameState.civilizations.clear()
	GameState.heroes.clear()
	GameState.current_year = 142
	GameState.next_hero_id = 5

	# Region with non-default values
	var r := RegionData.new(10, "Test Delta", Enums.TerrainType.RIVER_BASIN)
	r.population = 4200
	r.owner_id = 0
	r.infrastructure_level = 3
	r.resource_stock = {"coal": 50, "iron": 30}
	r.adjacency_list = [11, 12]
	GameState.regions[r.id] = r

	var r2 := RegionData.new(11, "Test Peak", Enums.TerrainType.MOUNTAINS)
	r2.population = 800
	r2.owner_id = 0
	r2.adjacency_list = [10]
	GameState.regions[r2.id] = r2

	# Neutral region
	var r3 := RegionData.new(12, "Neutral Plains", Enums.TerrainType.PLAINS)
	r3.population = 500
	r3.adjacency_list = [10]
	GameState.regions[r3.id] = r3

	# Civ with modified values
	var civ := CivilizationData.new(0, "TestCiv", Color.RED)
	civ.stability = 72.5
	civ.total_population = 5000
	civ.food_stockpile = 250
	civ.production_stockpile = -30
	civ.military_strength = 88.0
	civ.capital_region_id = 10
	civ.hero_ids = [0, 2]
	civ.is_collapsed = false
	civ.golden_age_years_remaining = 8
	civ.golden_age_cooldown = 0
	civ.knowledge = 45.0
	civ.energy = 30.0
	civ.social_coordination = 25.0
	civ.economic_surplus = 60.0
	civ.military_pressure = 15.0
	civ.expansion_bias = 0.7
	civ.aggression_bias = 0.3
	civ.diplomacy_bias = 0.6
	civ.economy_bias = 0.9
	civ.war_targets = [1]
	civ.war_durations = {1: 7}
	civ.peace_cooldowns = {2: 3}
	civ.alliance_partners = []
	civ.consecutive_low_stability_years = 0
	civ.technologies = ["irrigation", "bronze_working"]
	GameState.civilizations[civ.id] = civ

	# Collapsed civ
	var civ2 := CivilizationData.new(1, "FallenCiv", Color.BLUE)
	civ2.is_collapsed = true
	civ2.stability = 0.0
	civ2.consecutive_low_stability_years = 12
	GameState.civilizations[civ2.id] = civ2

	# Hero
	var hero := HeroData.new(0, "Test General", Enums.HeroType.GENERAL, 0)
	hero.id = 0
	hero.age = 35
	hero.lifespan = 70
	hero.birth_year = 107
	GameState.heroes[hero.id] = hero

	var hero2 := HeroData.new(2, "Test Visionary", Enums.HeroType.VISIONARY, 0)
	hero2.id = 2
	hero2.age = 50
	hero2.lifespan = 65
	hero2.birth_year = 92
	GameState.heroes[hero2.id] = hero2


# --- Round-trip Tests ---

func test_save_and_load_returns_true() -> void:
	_setup_known_state()
	assert_true(SaveManager.save_game(TEST_SLOT), "Save should succeed")
	assert_true(SaveManager.load_game(TEST_SLOT), "Load should succeed")


func test_load_nonexistent_file_does_not_exist() -> void:
	var path := "user://saves/nonexistent_slot_xyz.tres"
	assert_false(FileAccess.file_exists(path), "Nonexistent save should not exist")


func test_round_trip_preserves_year_and_hero_id() -> void:
	_setup_known_state()
	SaveManager.save_game(TEST_SLOT)

	GameState.current_year = 999
	GameState.next_hero_id = 999
	SaveManager.load_game(TEST_SLOT)

	assert_eq(GameState.current_year, 142)
	assert_eq(GameState.next_hero_id, 5)


func test_round_trip_preserves_region_count() -> void:
	_setup_known_state()
	SaveManager.save_game(TEST_SLOT)

	GameState.regions.clear()
	SaveManager.load_game(TEST_SLOT)

	assert_eq(GameState.regions.size(), 3)


func test_round_trip_preserves_region_fields() -> void:
	_setup_known_state()
	SaveManager.save_game(TEST_SLOT)

	GameState.regions.clear()
	SaveManager.load_game(TEST_SLOT)

	var r: RegionData = GameState.regions[10]
	assert_eq(r.id, 10)
	assert_eq(r.region_name, "Test Delta")
	assert_eq(r.terrain_type, Enums.TerrainType.RIVER_BASIN)
	assert_eq(r.population, 4200)
	assert_eq(r.owner_id, 0)
	assert_eq(r.food_yield, 5)
	assert_eq(r.production_yield, 3)
	assert_almost_eq(r.defense_modifier, 0.8, 0.01)
	assert_eq(r.infrastructure_level, 3)
	assert_eq(r.resource_stock.get("coal"), 50)
	assert_eq(r.resource_stock.get("iron"), 30)


func test_round_trip_preserves_adjacency() -> void:
	_setup_known_state()
	SaveManager.save_game(TEST_SLOT)

	GameState.regions.clear()
	SaveManager.load_game(TEST_SLOT)

	var r: RegionData = GameState.regions[10]
	assert_eq(r.adjacency_list.size(), 2)
	assert_true(11 in r.adjacency_list)
	assert_true(12 in r.adjacency_list)


func test_round_trip_preserves_neutral_region() -> void:
	_setup_known_state()
	SaveManager.save_game(TEST_SLOT)

	GameState.regions.clear()
	SaveManager.load_game(TEST_SLOT)

	var r: RegionData = GameState.regions[12]
	assert_eq(r.owner_id, -1, "Neutral region should stay neutral")
	assert_eq(r.region_name, "Neutral Plains")


func test_round_trip_preserves_civilization_fields() -> void:
	_setup_known_state()
	SaveManager.save_game(TEST_SLOT)

	GameState.civilizations.clear()
	SaveManager.load_game(TEST_SLOT)

	var civ: CivilizationData = GameState.civilizations[0]
	assert_eq(civ.id, 0)
	assert_eq(civ.civ_name, "TestCiv")
	assert_almost_eq(civ.stability, 72.5, 0.01)
	assert_eq(civ.total_population, 5000)
	assert_eq(civ.food_stockpile, 250)
	assert_eq(civ.production_stockpile, -30)
	assert_almost_eq(civ.military_strength, 88.0, 0.01)
	assert_eq(civ.capital_region_id, 10)
	assert_false(civ.is_collapsed)
	assert_eq(civ.golden_age_years_remaining, 8)
	assert_eq(civ.golden_age_cooldown, 0)


func test_round_trip_preserves_tech_metrics() -> void:
	_setup_known_state()
	SaveManager.save_game(TEST_SLOT)

	GameState.civilizations.clear()
	SaveManager.load_game(TEST_SLOT)

	var civ: CivilizationData = GameState.civilizations[0]
	assert_almost_eq(civ.knowledge, 45.0, 0.01)
	assert_almost_eq(civ.energy, 30.0, 0.01)
	assert_almost_eq(civ.social_coordination, 25.0, 0.01)
	assert_almost_eq(civ.economic_surplus, 60.0, 0.01)
	assert_almost_eq(civ.military_pressure, 15.0, 0.01)


func test_round_trip_preserves_ai_biases() -> void:
	_setup_known_state()
	SaveManager.save_game(TEST_SLOT)

	GameState.civilizations.clear()
	SaveManager.load_game(TEST_SLOT)

	var civ: CivilizationData = GameState.civilizations[0]
	assert_almost_eq(civ.expansion_bias, 0.7, 0.01)
	assert_almost_eq(civ.aggression_bias, 0.3, 0.01)
	assert_almost_eq(civ.diplomacy_bias, 0.6, 0.01)
	assert_almost_eq(civ.economy_bias, 0.9, 0.01)


func test_round_trip_preserves_war_and_tech() -> void:
	_setup_known_state()
	SaveManager.save_game(TEST_SLOT)

	GameState.civilizations.clear()
	SaveManager.load_game(TEST_SLOT)

	var civ: CivilizationData = GameState.civilizations[0]
	assert_eq(civ.war_targets.size(), 1)
	assert_true(1 in civ.war_targets)
	assert_eq(civ.technologies.size(), 2)
	assert_true("irrigation" in civ.technologies)
	assert_true("bronze_working" in civ.technologies)


func test_round_trip_preserves_war_timers() -> void:
	_setup_known_state()
	SaveManager.save_game(TEST_SLOT)

	GameState.civilizations.clear()
	SaveManager.load_game(TEST_SLOT)

	var civ: CivilizationData = GameState.civilizations[0]
	assert_eq(civ.war_durations.get(1), 7)
	assert_eq(civ.peace_cooldowns.get(2), 3)


func test_round_trip_preserves_collapsed_civ() -> void:
	_setup_known_state()
	SaveManager.save_game(TEST_SLOT)

	GameState.civilizations.clear()
	SaveManager.load_game(TEST_SLOT)

	var civ: CivilizationData = GameState.civilizations[1]
	assert_true(civ.is_collapsed)
	assert_almost_eq(civ.stability, 0.0, 0.01)
	assert_eq(civ.consecutive_low_stability_years, 12)


func test_round_trip_preserves_heroes() -> void:
	_setup_known_state()
	SaveManager.save_game(TEST_SLOT)

	GameState.heroes.clear()
	SaveManager.load_game(TEST_SLOT)

	assert_eq(GameState.heroes.size(), 2)

	var hero: HeroData = GameState.heroes[0]
	assert_eq(hero.hero_name, "Test General")
	assert_eq(hero.type, Enums.HeroType.GENERAL)
	assert_eq(hero.age, 35)
	assert_eq(hero.lifespan, 70)
	assert_eq(hero.owner_civ_id, 0)
	assert_eq(hero.birth_year, 107)

	var hero2: HeroData = GameState.heroes[2]
	assert_eq(hero2.hero_name, "Test Visionary")
	assert_eq(hero2.type, Enums.HeroType.VISIONARY)
	assert_eq(hero2.age, 50)


func test_round_trip_hero_ids_on_civ() -> void:
	_setup_known_state()
	SaveManager.save_game(TEST_SLOT)

	GameState.civilizations.clear()
	SaveManager.load_game(TEST_SLOT)

	var civ: CivilizationData = GameState.civilizations[0]
	assert_eq(civ.hero_ids.size(), 2)
	assert_true(0 in civ.hero_ids)
	assert_true(2 in civ.hero_ids)


func test_save_file_under_5mb() -> void:
	# Load real game data and save it
	GameState.load_game_data()
	SaveManager.save_game(TEST_SLOT)

	var save_path := "user://saves/" + TEST_SLOT + ".tres"
	var file := FileAccess.open(save_path, FileAccess.READ)
	assert_not_null(file, "Save file should exist")
	if file:
		var size_bytes := file.get_length()
		file.close()
		var size_mb := float(size_bytes) / (1024.0 * 1024.0)
		assert_true(size_mb < 5.0, "Save file should be under 5MB (actual: %.2f MB)" % size_mb)
		gut.p("Save file size: %d bytes (%.3f MB)" % [size_bytes, size_mb])

	# Restore real game data after test
	GameState.load_game_data()


func test_delete_save() -> void:
	_setup_known_state()
	SaveManager.save_game(TEST_SLOT)
	assert_true(SaveManager.delete_save(TEST_SLOT))
	var path := "user://saves/" + TEST_SLOT + ".tres"
	assert_false(FileAccess.file_exists(path), "File should not exist after delete")


func test_save_list_contains_slot() -> void:
	_setup_known_state()
	SaveManager.save_game(TEST_SLOT)
	var saves := SaveManager.get_save_list()
	assert_true(TEST_SLOT in saves, "Save list should contain test slot")


func test_save_manager_get_save_list_multiple() -> void:
	_setup_known_state()
	SaveManager.save_game("test_multi_1")
	SaveManager.save_game("test_multi_2")
	var saves := SaveManager.get_save_list()
	assert_true("test_multi_1" in saves, "Save list should contain first slot")
	assert_true("test_multi_2" in saves, "Save list should contain second slot")
	# Cleanup
	SaveManager.delete_save("test_multi_1")
	SaveManager.delete_save("test_multi_2")


func test_save_manager_autosave_name() -> void:
	_setup_known_state()
	SaveManager.save_game("autosave_1")
	var saves := SaveManager.get_save_list()
	assert_true("autosave_1" in saves, "Autosave slot should be in save list")
	SaveManager.delete_save("autosave_1")
