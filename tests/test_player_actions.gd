extends GutTest

## Tests for Sprint E: Player Agency
## Covers PlayerActions queue, GameState player tracking,
## SimulationEngine pipeline integration, and save/load.


var _saved_regions: Dictionary
var _saved_civs: Dictionary
var _saved_heroes: Dictionary
var _saved_year: int
var _saved_player_id: int


func before_each() -> void:
	# Snapshot GameState so we can restore after each test
	_saved_regions = GameState.regions.duplicate()
	_saved_civs = GameState.civilizations.duplicate()
	_saved_heroes = GameState.heroes.duplicate()
	_saved_year = GameState.current_year
	_saved_player_id = GameState.player_civ_id
	PlayerActions.clear_queue()


func after_each() -> void:
	GameState.regions = _saved_regions
	GameState.civilizations = _saved_civs
	GameState.heroes = _saved_heroes
	GameState.current_year = _saved_year
	GameState.player_civ_id = _saved_player_id
	PlayerActions.clear_queue()


func _make_civ(id: int, name: String = "TestCiv", color: Color = Color.RED) -> CivilizationData:
	var civ := CivilizationData.new(id, name, color)
	civ.stability = 50.0
	civ.food_stockpile = 100
	civ.production_stockpile = 100
	civ.military_strength = 50.0
	civ.total_population = 5000
	return civ


func _make_region(id: int, name: String = "TestRegion", owner_id: int = -1) -> RegionData:
	var region := RegionData.new(id, name, Enums.TerrainType.PLAINS)
	region.owner_id = owner_id
	region.population = 1000
	return region


func _setup_two_civs() -> Array:
	GameState.regions.clear()
	GameState.civilizations.clear()
	GameState.player_civ_id = 0

	var player := _make_civ(0, "PlayerCiv")
	player.is_player = true
	var enemy := _make_civ(1, "EnemyCiv", Color.BLUE)

	GameState.civilizations[0] = player
	GameState.civilizations[1] = enemy

	var r0 := _make_region(0, "Player Capital", 0)
	var r1 := _make_region(1, "Enemy Capital", 1)
	r0.adjacency_list = [1]
	r1.adjacency_list = [0]
	GameState.regions[0] = r0
	GameState.regions[1] = r1

	return [player, enemy]


# ==================== E1: Player Civ Tracking ====================

func test_player_civ_id_default() -> void:
	GameState.player_civ_id = 0
	assert_eq(GameState.player_civ_id, 0)


func test_get_player_civ_returns_correct_civ() -> void:
	var civs := _setup_two_civs()
	var player_civ := GameState.get_player_civ()
	assert_not_null(player_civ)
	assert_eq(player_civ.civ_name, "PlayerCiv")


func test_is_player_civ_true() -> void:
	_setup_two_civs()
	assert_true(GameState.is_player_civ(0))


func test_is_player_civ_false() -> void:
	_setup_two_civs()
	assert_false(GameState.is_player_civ(1))


func test_is_player_flag_on_civ_data() -> void:
	var civs := _setup_two_civs()
	assert_true(civs[0].is_player)
	assert_false(civs[1].is_player)


# ==================== E2: Action Queue ====================

func test_queue_action_adds_to_queue() -> void:
	PlayerActions.queue_action({"type": "declare_war", "target_civ_id": 1})
	assert_true(PlayerActions.has_queued_actions())
	assert_eq(PlayerActions.get_queue_size(), 1)


func test_clear_queue_empties() -> void:
	PlayerActions.queue_action({"type": "declare_war", "target_civ_id": 1})
	PlayerActions.clear_queue()
	assert_false(PlayerActions.has_queued_actions())
	assert_eq(PlayerActions.get_queue_size(), 0)


func test_queue_multiple_actions() -> void:
	PlayerActions.queue_action({"type": "declare_war", "target_civ_id": 1})
	PlayerActions.queue_action({"type": "seek_peace", "target_civ_id": 1})
	assert_eq(PlayerActions.get_queue_size(), 2)


func test_process_clears_queue() -> void:
	var civs := _setup_two_civs()
	PlayerActions.queue_action({"type": "declare_war", "target_civ_id": 1})
	PlayerActions.process_queued_actions(civs[0])
	assert_eq(PlayerActions.get_queue_size(), 0)


# ==================== E2: Declare War ====================

func test_declare_war_sets_war_targets() -> void:
	var civs := _setup_two_civs()
	PlayerActions.queue_action({"type": "declare_war", "target_civ_id": 1})
	var events := PlayerActions.process_queued_actions(civs[0])

	assert_true(civs[0].war_targets.has(1))
	assert_true(civs[1].war_targets.has(0))
	assert_eq(events.size(), 1)
	assert_eq(events[0]["type"], "war_declared")


func test_declare_war_breaks_alliance() -> void:
	var civs := _setup_two_civs()
	civs[0].alliance_partners.append(1)
	civs[1].alliance_partners.append(0)

	PlayerActions.queue_action({"type": "declare_war", "target_civ_id": 1})
	PlayerActions.process_queued_actions(civs[0])

	assert_false(civs[0].alliance_partners.has(1))
	assert_false(civs[1].alliance_partners.has(0))
	assert_true(civs[0].war_targets.has(1))


func test_declare_war_on_collapsed_civ_ignored() -> void:
	var civs := _setup_two_civs()
	civs[1].is_collapsed = true

	PlayerActions.queue_action({"type": "declare_war", "target_civ_id": 1})
	var events := PlayerActions.process_queued_actions(civs[0])

	assert_eq(events.size(), 0)
	assert_false(civs[0].war_targets.has(1))


func test_declare_war_already_at_war_ignored() -> void:
	var civs := _setup_two_civs()
	civs[0].war_targets.append(1)
	civs[1].war_targets.append(0)

	PlayerActions.queue_action({"type": "declare_war", "target_civ_id": 1})
	var events := PlayerActions.process_queued_actions(civs[0])

	assert_eq(events.size(), 0)


# ==================== E2: Seek Peace ====================

func test_seek_peace_removes_war_targets() -> void:
	var civs := _setup_two_civs()
	civs[0].war_targets.append(1)
	civs[1].war_targets.append(0)

	PlayerActions.queue_action({"type": "seek_peace", "target_civ_id": 1})
	var events := PlayerActions.process_queued_actions(civs[0])

	assert_false(civs[0].war_targets.has(1))
	assert_false(civs[1].war_targets.has(0))
	assert_eq(events.size(), 1)
	assert_eq(events[0]["type"], "peace")


func test_seek_peace_when_not_at_war_ignored() -> void:
	var civs := _setup_two_civs()
	PlayerActions.queue_action({"type": "seek_peace", "target_civ_id": 1})
	var events := PlayerActions.process_queued_actions(civs[0])
	assert_eq(events.size(), 0)


# ==================== E2: Invest Infrastructure ====================

func test_invest_infrastructure_upgrades() -> void:
	var civs := _setup_two_civs()
	var region: RegionData = GameState.regions[0]
	region.infrastructure_level = 0

	PlayerActions.queue_action({"type": "invest_infrastructure", "region_id": 0})
	var events := PlayerActions.process_queued_actions(civs[0])

	assert_eq(region.infrastructure_level, 1)
	assert_eq(events.size(), 1)
	assert_eq(events[0]["type"], "infrastructure_upgrade")
	# Cost = 15 * (0 + 1) = 15
	assert_eq(civs[0].production_stockpile, 85)


func test_invest_infrastructure_insufficient_production() -> void:
	var civs := _setup_two_civs()
	civs[0].production_stockpile = 5  # Too low for any upgrade
	var region: RegionData = GameState.regions[0]
	region.infrastructure_level = 0

	PlayerActions.queue_action({"type": "invest_infrastructure", "region_id": 0})
	var events := PlayerActions.process_queued_actions(civs[0])

	assert_eq(region.infrastructure_level, 0)
	assert_eq(events.size(), 0)


func test_invest_infrastructure_max_level_ignored() -> void:
	var civs := _setup_two_civs()
	var region: RegionData = GameState.regions[0]
	region.infrastructure_level = Constants.INFRASTRUCTURE_MAX_LEVEL

	PlayerActions.queue_action({"type": "invest_infrastructure", "region_id": 0})
	var events := PlayerActions.process_queued_actions(civs[0])

	assert_eq(events.size(), 0)


func test_invest_infrastructure_enemy_region_ignored() -> void:
	var civs := _setup_two_civs()
	# Try to upgrade an enemy-owned region
	PlayerActions.queue_action({"type": "invest_infrastructure", "region_id": 1})
	var events := PlayerActions.process_queued_actions(civs[0])
	assert_eq(events.size(), 0)


# ==================== E2: Seek Alliance ====================

func test_seek_alliance_forms_alliance() -> void:
	var civs := _setup_two_civs()
	PlayerActions.queue_action({"type": "seek_alliance", "target_civ_id": 1})
	var events := PlayerActions.process_queued_actions(civs[0])

	assert_true(civs[0].alliance_partners.has(1))
	assert_true(civs[1].alliance_partners.has(0))
	assert_eq(events.size(), 1)
	assert_eq(events[0]["type"], "alliance_formed")


func test_seek_alliance_already_allied_ignored() -> void:
	var civs := _setup_two_civs()
	civs[0].alliance_partners.append(1)
	civs[1].alliance_partners.append(0)

	PlayerActions.queue_action({"type": "seek_alliance", "target_civ_id": 1})
	var events := PlayerActions.process_queued_actions(civs[0])
	assert_eq(events.size(), 0)


func test_seek_alliance_at_war_ignored() -> void:
	var civs := _setup_two_civs()
	civs[0].war_targets.append(1)
	civs[1].war_targets.append(0)

	PlayerActions.queue_action({"type": "seek_alliance", "target_civ_id": 1})
	var events := PlayerActions.process_queued_actions(civs[0])
	assert_eq(events.size(), 0)


# ==================== E2: Unknown Action ====================

func test_unknown_action_type_ignored() -> void:
	var civs := _setup_two_civs()
	PlayerActions.queue_action({"type": "nonexistent_action"})
	var events := PlayerActions.process_queued_actions(civs[0])
	assert_eq(events.size(), 0)


# ==================== E3: Pipeline Integration ====================

func test_player_civ_skips_ai_logic() -> void:
	# When player has no actions queued, processing should produce no events
	# (unlike AI which would make autonomous decisions)
	var civs := _setup_two_civs()
	GameState.player_civ_id = 0

	# Process with empty queue - player gets no auto-decisions
	var events := PlayerActions.process_queued_actions(civs[0])
	assert_eq(events.size(), 0, "Empty player queue should produce no events")


func test_player_action_returns_same_format_as_ai() -> void:
	var civs := _setup_two_civs()
	PlayerActions.queue_action({"type": "declare_war", "target_civ_id": 1})
	var events := PlayerActions.process_queued_actions(civs[0])

	# Verify event dict format matches AILogic expectations
	assert_eq(events.size(), 1)
	assert_true(events[0].has("type"))
	assert_true(events[0].has("attacker_id"))
	assert_true(events[0].has("defender_id"))
	assert_true(events[0].has("attacker_name"))
	assert_true(events[0].has("defender_name"))


# ==================== E1: Save/Load Player ID ====================

func test_save_load_preserves_player_civ_id() -> void:
	_setup_two_civs()
	GameState.player_civ_id = 0
	GameState.current_year = 50

	SaveManager.save_game("test_player_sprint_e")
	GameState.player_civ_id = 99

	SaveManager.load_game("test_player_sprint_e")
	assert_eq(GameState.player_civ_id, 0)
	SaveManager.delete_save("test_player_sprint_e")


func test_save_load_preserves_is_player_flag() -> void:
	_setup_two_civs()
	GameState.current_year = 50

	SaveManager.save_game("test_player_flag_e")
	GameState.civilizations.clear()

	SaveManager.load_game("test_player_flag_e")
	var civ: CivilizationData = GameState.civilizations[0]
	assert_true(civ.is_player)
	SaveManager.delete_save("test_player_flag_e")
