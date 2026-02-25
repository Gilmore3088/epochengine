extends GutTest

## Tests for Sprint E: Player Agency
## Covers PlayerActions queue, GameState player tracking,
## SimulationEngine pipeline integration, and save/load.


var _saved_regions: Dictionary
var _saved_civs: Dictionary
var _saved_heroes: Dictionary
var _saved_units: Dictionary
var _saved_year: int
var _saved_player_id: int
var _saved_next_unit_id: int


func before_each() -> void:
	# Snapshot GameState so we can restore after each test
	_saved_regions = GameState.regions.duplicate()
	_saved_civs = GameState.civilizations.duplicate()
	_saved_heroes = GameState.heroes.duplicate()
	_saved_units = GameState.units.duplicate()
	_saved_year = GameState.current_year
	_saved_player_id = GameState.player_civ_id
	_saved_next_unit_id = GameState.next_unit_id
	PlayerActions.clear_queue()


func after_each() -> void:
	GameState.regions = _saved_regions
	GameState.civilizations = _saved_civs
	GameState.heroes = _saved_heroes
	GameState.units = _saved_units
	GameState.current_year = _saved_year
	GameState.player_civ_id = _saved_player_id
	GameState.next_unit_id = _saved_next_unit_id
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
	GameState.units.clear()
	GameState.next_unit_id = 0
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

	# Add a worker at capital so infrastructure/construction tests work
	var worker := UnitData.new(-1, "Worker", Enums.UnitType.WORKER, 0, 0)
	GameState.add_unit(worker)

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
	# Cost = 10 * (0 + 1) = 10
	assert_eq(civs[0].production_stockpile, 90)


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


# ==================== Research Focus ====================

func test_research_focus_action() -> void:
	var civs := _setup_two_civs()
	PlayerActions.queue_action({"type": "set_research_focus", "focus": 1})
	var events := PlayerActions.process_queued_actions(civs[0])

	assert_eq(events.size(), 1)
	assert_eq(events[0]["type"], "research_focus_changed")
	assert_eq(events[0]["focus_name"], "Knowledge")
	assert_eq(civs[0].research_focus, 1)
	assert_eq(civs[0].research_focus_cooldown, Constants.RESEARCH_FOCUS_COOLDOWN_YEARS)


func test_research_focus_cooldown_enforced() -> void:
	var civs := _setup_two_civs()
	civs[0].research_focus = 1
	civs[0].research_focus_cooldown = 2

	PlayerActions.queue_action({"type": "set_research_focus", "focus": 3})
	var events := PlayerActions.process_queued_actions(civs[0])

	assert_eq(events.size(), 0, "Should reject focus change during cooldown")
	assert_eq(civs[0].research_focus, 1, "Focus should remain unchanged")


func test_research_focus_save_load() -> void:
	var civs := _setup_two_civs()
	civs[0].research_focus = 3
	civs[0].research_focus_cooldown = 2
	GameState.current_year = 50

	SaveManager.save_game("test_research_focus")
	civs[0].research_focus = 0
	civs[0].research_focus_cooldown = 0

	SaveManager.load_game("test_research_focus")
	var civ: CivilizationData = GameState.civilizations[0]
	assert_eq(civ.research_focus, 3)
	assert_eq(civ.research_focus_cooldown, 2)
	SaveManager.delete_save("test_research_focus")


# ==================== Spending Priority ====================

func test_spending_priority_default() -> void:
	var civs := _setup_two_civs()
	assert_eq(civs[0].spending_priority, 0, "Default spending priority should be 0")


func test_spending_priority_action() -> void:
	var civs := _setup_two_civs()
	PlayerActions.queue_action({"type": "set_spending_priority", "priority": 1})
	var events := PlayerActions.process_queued_actions(civs[0])

	assert_eq(events.size(), 1)
	assert_eq(events[0]["type"], "spending_priority_changed")
	assert_eq(events[0]["priority_name"], "Growth")
	assert_eq(civs[0].spending_priority, 1)
	assert_eq(civs[0].spending_priority_cooldown, Constants.SPENDING_PRIORITY_COOLDOWN_YEARS)


func test_spending_priority_cooldown_enforced() -> void:
	var civs := _setup_two_civs()
	civs[0].spending_priority = 1
	civs[0].spending_priority_cooldown = 3

	PlayerActions.queue_action({"type": "set_spending_priority", "priority": 2})
	var events := PlayerActions.process_queued_actions(civs[0])

	assert_eq(events.size(), 0, "Should reject priority change during cooldown")
	assert_eq(civs[0].spending_priority, 1, "Priority should remain unchanged")


# ==================== Infra Feedback ====================

func test_infra_upgrade_returns_deltas() -> void:
	var civs := _setup_two_civs()
	var region: RegionData = GameState.regions[0]
	region.infrastructure_level = 0

	PlayerActions.queue_action({"type": "invest_infrastructure", "region_id": 0})
	var events := PlayerActions.process_queued_actions(civs[0])

	assert_eq(events.size(), 1)
	assert_true(events[0].has("food_delta"), "Should have food_delta key")
	assert_true(events[0].has("prod_delta"), "Should have prod_delta key")
	assert_true(events[0].has("def_delta"), "Should have def_delta key")
	assert_true(events[0].has("tier_changed"), "Should have tier_changed key")
	assert_true(events[0].has("next_tier_infra_needed"), "Should have next_tier_infra_needed key")


func test_infra_to_next_tier_helper() -> void:
	var civs := _setup_two_civs()
	var region: RegionData = GameState.regions[0]
	region.infrastructure_level = 1
	region.development_tier = 1
	# Tier 2 gate: infra >= 2. Current = 1. Gap = 1
	var gap := PlayerActions._infra_to_next_tier(region)
	assert_eq(gap, 1, "Should need 1 more infra for tier 2")

	region.infrastructure_level = 5
	region.development_tier = 5  # Max tier
	gap = PlayerActions._infra_to_next_tier(region)
	assert_eq(gap, -1, "Max tier should return -1")


func test_spending_priority_save_load() -> void:
	var civs := _setup_two_civs()
	civs[0].spending_priority = 2
	civs[0].spending_priority_cooldown = 4
	GameState.current_year = 50

	SaveManager.save_game("test_spending_priority")
	civs[0].spending_priority = 0
	civs[0].spending_priority_cooldown = 0

	SaveManager.load_game("test_spending_priority")
	var civ: CivilizationData = GameState.civilizations[0]
	assert_eq(civ.spending_priority, 2)
	assert_eq(civ.spending_priority_cooldown, 4)
	SaveManager.delete_save("test_spending_priority")


# ==================== T6: AI Awareness Integration ====================

func test_ai_sets_research_focus_when_growing() -> void:
	var civs := _setup_two_civs()
	var ai: CivilizationData = civs[1]
	ai.stability = 80.0  # > 70 → GROWING state
	ai.research_focus = 0  # Balanced
	ai.research_focus_cooldown = 0
	ai.technologies = []  # 0 techs < threshold 2 → Knowledge
	ai.current_era = Enums.Epoch.PREHISTORIC
	GameState.current_year = 10  # divisible by 10

	AILogic.make_decisions(ai)

	assert_eq(ai.research_focus, 1, "GROWING AI with few techs should pick Knowledge focus")
	assert_gt(ai.research_focus_cooldown, 0, "Cooldown should be set after change")


func test_ai_sets_spending_priority_declining_food_deficit() -> void:
	var civs := _setup_two_civs()
	var ai: CivilizationData = civs[1]
	ai.stability = 20.0  # < 30 → DECLINING state
	ai.spending_priority = 0  # Balanced
	ai.spending_priority_cooldown = 0
	ai.food_stockpile = -50  # Negative food
	GameState.current_year = 20  # divisible by 10

	AILogic.make_decisions(ai)

	assert_eq(ai.spending_priority, 1, "DECLINING AI with food deficit should pick Growth priority")
	assert_gt(ai.spending_priority_cooldown, 0, "Cooldown should be set after change")


func test_spending_priority_growth_boosts_food() -> void:
	# Integration: spending priority = Growth should increase food via economy pipeline
	var civs := _setup_two_civs()
	var player: CivilizationData = civs[0]
	var region: RegionData = GameState.regions[0]
	region.population = 2000
	player.total_population = 2000
	player.food_stockpile = 50
	player.production_stockpile = 50

	var owned: Array[RegionData] = [region]

	# Run one turn with Balanced (0)
	player.spending_priority = 0
	var food_before := player.food_stockpile
	EconomySimulation.process_economy(player, owned)
	var food_balanced := player.food_stockpile
	var food_delta_balanced := food_balanced - food_before

	# Reset and run with Growth (1)
	player.food_stockpile = 50
	player.production_stockpile = 50
	player.spending_priority = 1
	food_before = player.food_stockpile
	EconomySimulation.process_economy(player, owned)
	var food_growth := player.food_stockpile
	var food_delta_growth := food_growth - food_before

	assert_gt(food_delta_growth, food_delta_balanced,
		"Growth spending priority should produce more food than Balanced")


func test_research_focus_knowledge_boosts_metric() -> void:
	# Integration: research focus = Knowledge should boost knowledge metric
	var civs := _setup_two_civs()
	var player: CivilizationData = civs[0]
	var region: RegionData = GameState.regions[0]
	region.production_yield = 5
	player.knowledge = 10.0
	player.energy = 10.0
	player.social_coordination = 10.0
	player.economic_surplus = 10.0
	player.military_pressure = 10.0
	player.total_population = 5000
	player.stability = 50.0

	var owned: Array[RegionData] = [region]

	# Run 5 turns with Balanced (0)
	player.research_focus = 0
	for i in range(5):
		TechEmergence.update_hidden_metrics(player, owned)
	var knowledge_balanced := player.knowledge

	# Reset and run 5 turns with Knowledge (1)
	player.knowledge = 10.0
	player.energy = 10.0
	player.social_coordination = 10.0
	player.economic_surplus = 10.0
	player.military_pressure = 10.0
	player.research_focus = 1
	for i in range(5):
		TechEmergence.update_hidden_metrics(player, owned)
	var knowledge_focused := player.knowledge

	assert_gt(knowledge_focused, knowledge_balanced,
		"Knowledge focus should produce higher knowledge than Balanced")


# ==================== Claim Region ====================


func _setup_claim_scenario() -> Array:
	## Set up player civ with one region, and an adjacent neutral region.
	GameState.regions.clear()
	GameState.civilizations.clear()
	GameState.player_civ_id = 0

	var player := _make_civ(0, "PlayerCiv")
	player.is_player = true
	player.production_stockpile = 200
	player.total_population = 5000
	GameState.civilizations[0] = player

	var owned := _make_region(0, "Home", 0)
	owned.population = 2000
	owned.adjacency_list = [1, 2]
	GameState.regions[0] = owned

	var neutral := _make_region(1, "Frontier", -1)
	neutral.population = 50
	neutral.adjacency_list = [0]
	GameState.regions[1] = neutral

	var far_neutral := _make_region(2, "Far Away", -1)
	far_neutral.population = 30
	far_neutral.adjacency_list = [0]
	GameState.regions[2] = far_neutral

	return [player, owned, neutral, far_neutral]


func test_claim_region_basic() -> void:
	var setup := _setup_claim_scenario()
	var player: CivilizationData = setup[0]
	var neutral: RegionData = setup[2]

	var prod_before := player.production_stockpile
	PlayerActions.queue_action({"type": "claim_region", "region_id": 1})
	var events := PlayerActions.process_queued_actions(player)

	assert_eq(events.size(), 1, "Should produce one expansion event")
	assert_eq(events[0]["type"], "expansion")
	assert_eq(neutral.owner_id, player.id, "Neutral region should now be owned by player")
	assert_true(player.production_stockpile < prod_before,
		"Production should be deducted")
	assert_true(neutral.population >= Constants.EXPANSION_SETTLER_POP,
		"Region population should be at least settler minimum")


func test_claim_region_fails_non_adjacent() -> void:
	var setup := _setup_claim_scenario()
	var player: CivilizationData = setup[0]

	# Create a region not adjacent to player
	var isolated := _make_region(10, "Isolated", -1)
	isolated.adjacency_list = []
	GameState.regions[10] = isolated

	PlayerActions.queue_action({"type": "claim_region", "region_id": 10})
	var events := PlayerActions.process_queued_actions(player)

	assert_eq(events.size(), 0, "Should fail for non-adjacent region")
	assert_eq(isolated.owner_id, -1, "Isolated region should remain neutral")


func test_claim_region_fails_insufficient_production() -> void:
	var setup := _setup_claim_scenario()
	var player: CivilizationData = setup[0]

	player.production_stockpile = 0
	player.total_population = 100  # Also below settler minimum

	PlayerActions.queue_action({"type": "claim_region", "region_id": 1})
	var events := PlayerActions.process_queued_actions(player)

	assert_eq(events.size(), 0, "Should fail when cannot afford expansion")
	assert_eq(GameState.get_region(1).owner_id, -1,
		"Neutral region should remain neutral")
