extends GutTest

## Tests for Unit System: UnitData, UnitSimulation, GameState storage,
## movement, worker gating, explorer fog, leader bonuses, training.

var _saved_regions: Dictionary
var _saved_civs: Dictionary
var _saved_units: Dictionary
var _saved_year: int
var _saved_player_id: int
var _saved_next_unit_id: int


func before_each() -> void:
	_saved_regions = GameState.regions.duplicate()
	_saved_civs = GameState.civilizations.duplicate()
	_saved_units = GameState.units.duplicate()
	_saved_year = GameState.current_year
	_saved_player_id = GameState.player_civ_id
	_saved_next_unit_id = GameState.next_unit_id


func after_each() -> void:
	GameState.regions = _saved_regions
	GameState.civilizations = _saved_civs
	GameState.units = _saved_units
	GameState.current_year = _saved_year
	GameState.player_civ_id = _saved_player_id
	GameState.next_unit_id = _saved_next_unit_id
	GameState.reset_visibility()


func _make_civ(id: int, name: String = "TestCiv") -> CivilizationData:
	var civ := CivilizationData.new(id, name, Color.RED)
	civ.stability = 50.0
	civ.food_stockpile = 100
	civ.production_stockpile = 100
	civ.military_strength = 40.0
	civ.total_population = 5000
	return civ


func _make_region(id: int, name: String = "TestRegion", owner_id: int = -1) -> RegionData:
	var region := RegionData.new(id, name, Enums.TerrainType.PLAINS)
	region.owner_id = owner_id
	region.population = 1000
	return region


func _setup_test_map() -> CivilizationData:
	## R0(player) -- R1(player) -- R2(neutral) -- R3(neutral)
	GameState.regions.clear()
	GameState.civilizations.clear()
	GameState.units.clear()
	GameState.next_unit_id = 0
	GameState.player_civ_id = 0

	var player := _make_civ(0, "PlayerCiv")
	player.is_player = true
	GameState.civilizations[0] = player

	var r0 := _make_region(0, "Capital", 0)
	r0.adjacency_list = [1]
	GameState.regions[0] = r0

	var r1 := _make_region(1, "Province", 0)
	r1.adjacency_list = [0, 2]
	GameState.regions[1] = r1

	var r2 := _make_region(2, "Frontier", -1)
	r2.adjacency_list = [1, 3]
	GameState.regions[2] = r2

	var r3 := _make_region(3, "Distant", -1)
	r3.adjacency_list = [2]
	GameState.regions[3] = r3

	return player


# ==================== UnitData Creation ====================

func test_unit_data_creation() -> void:
	var unit := UnitData.new(0, "Scout", Enums.UnitType.EXPLORER, 0, 5)
	assert_eq(unit.id, 0)
	assert_eq(unit.unit_name, "Scout")
	assert_eq(unit.unit_type, Enums.UnitType.EXPLORER)
	assert_eq(unit.owner_civ_id, 0)
	assert_eq(unit.region_id, 5)
	assert_true(unit.is_idle(), "New unit should be idle")
	assert_true(unit.is_explorer(), "Should be explorer type")
	assert_false(unit.is_worker(), "Should not be worker")
	assert_false(unit.is_leader(), "Should not be leader")


func test_unit_data_serialization() -> void:
	var unit := UnitData.new(42, "Builder", Enums.UnitType.WORKER, 1, 7)
	unit.target_region_id = 8
	unit.created_year = 15
	unit.turns_in_transit = 1

	var data := unit.to_dict()
	var restored := UnitData.from_dict(data)

	assert_eq(restored.id, 42)
	assert_eq(restored.unit_name, "Builder")
	assert_eq(restored.unit_type, Enums.UnitType.WORKER)
	assert_eq(restored.owner_civ_id, 1)
	assert_eq(restored.region_id, 7)
	assert_eq(restored.target_region_id, 8)
	assert_eq(restored.created_year, 15)
	assert_eq(restored.turns_in_transit, 1)


# ==================== GameState Unit Storage ====================

func test_game_state_unit_storage() -> void:
	_setup_test_map()

	var unit := UnitData.new(-1, "Worker1", Enums.UnitType.WORKER, 0, 0)
	GameState.add_unit(unit)
	assert_eq(unit.id, 0, "First unit gets id 0")
	assert_eq(GameState.next_unit_id, 1, "next_unit_id increments")

	var fetched := GameState.get_unit(0)
	assert_not_null(fetched)
	assert_eq(fetched.unit_name, "Worker1")

	var by_civ := GameState.get_units_by_civ(0)
	assert_eq(by_civ.size(), 1)

	var in_region := GameState.get_units_in_region(0)
	assert_eq(in_region.size(), 1)

	GameState.remove_unit(0)
	assert_null(GameState.get_unit(0))
	assert_eq(GameState.get_units_by_civ(0).size(), 0)


# ==================== Movement ====================

func test_movement_instant_in_owned() -> void:
	## Unit moves instantly within owned territory.
	var _civ := _setup_test_map()
	var events := {"unit_events": []}

	var unit := UnitData.new(-1, "Worker", Enums.UnitType.WORKER, 0, 0)
	GameState.add_unit(unit)
	unit.target_region_id = 1  # R0 -> R1, both owned

	UnitSimulation.process_unit_movement(events)

	assert_eq(unit.region_id, 1, "Should arrive immediately in owned territory")
	assert_eq(unit.target_region_id, -1, "Target cleared after move")
	assert_eq(events["unit_events"].size(), 1, "One move event")
	assert_eq(events["unit_events"][0]["type"], "unit_moved")


func test_movement_delayed_in_neutral() -> void:
	## Unit takes 1 turn to move through neutral territory.
	var _civ := _setup_test_map()
	var events := {"unit_events": []}

	var unit := UnitData.new(-1, "Explorer", Enums.UnitType.EXPLORER, 0, 1)
	GameState.add_unit(unit)
	unit.target_region_id = 2  # R1(owned) -> R2(neutral)

	# First call: should increment turns_in_transit but not move
	UnitSimulation.process_unit_movement(events)
	assert_eq(unit.region_id, 1, "Should still be in R1 after 1st call")
	assert_eq(unit.turns_in_transit, 1, "Should have 1 turn in transit")
	assert_eq(events["unit_events"].size(), 0, "No move event yet")

	# Second call: should complete the move
	UnitSimulation.process_unit_movement(events)
	assert_eq(unit.region_id, 2, "Should arrive in R2 after 2nd call")
	assert_eq(unit.target_region_id, -1, "Target cleared")
	assert_eq(unit.turns_in_transit, 0, "Transit counter reset")
	assert_eq(events["unit_events"].size(), 1, "One move event")


func test_movement_adjacency_check() -> void:
	## Non-adjacent move target is rejected.
	var _civ := _setup_test_map()
	var events := {"unit_events": []}

	var unit := UnitData.new(-1, "Worker", Enums.UnitType.WORKER, 0, 0)
	GameState.add_unit(unit)
	unit.target_region_id = 2  # R0 -> R2, NOT adjacent

	UnitSimulation.process_unit_movement(events)
	assert_eq(unit.region_id, 0, "Should not have moved")
	assert_eq(unit.target_region_id, -1, "Target cleared on invalid move")


# ==================== Worker Gating ====================

func test_worker_gates_construction() -> void:
	## Player can't build without a worker in the region.
	var civ := _setup_test_map()
	civ.production_stockpile = 100

	var region := GameState.get_region(0)
	var town := TownData.new(0, "TestTown", 0)
	town.population = 500
	region.towns = [town]

	# No worker in region => can't build
	var can_build := TownSimulation.can_construct_building(town, Enums.BuildingType.GRANARY, civ)
	assert_false(can_build, "Should not be able to build without worker")


func test_worker_allows_construction() -> void:
	## Player can build when a worker is present.
	var civ := _setup_test_map()
	civ.production_stockpile = 100

	var region := GameState.get_region(0)
	var town := TownData.new(0, "TestTown", 0)
	town.population = 500
	region.towns = [town]

	# Add idle worker
	var worker := UnitData.new(-1, "Worker", Enums.UnitType.WORKER, 0, 0)
	GameState.add_unit(worker)

	var can_build := TownSimulation.can_construct_building(town, Enums.BuildingType.GRANARY, civ)
	assert_true(can_build, "Should be able to build with worker present")


func test_ai_bypasses_worker_check() -> void:
	## AI civs can build without workers (virtual workers).
	GameState.regions.clear()
	GameState.civilizations.clear()
	GameState.units.clear()
	GameState.next_unit_id = 0
	GameState.player_civ_id = 0

	var ai_civ := _make_civ(1, "AICiv")  # id != player_civ_id
	GameState.civilizations[1] = ai_civ
	ai_civ.production_stockpile = 100

	var region := _make_region(0, "AIRegion", 1)
	GameState.regions[0] = region
	var town := TownData.new(0, "AITown", 0)
	town.population = 500
	region.towns = [town]

	# No workers at all, but AI should bypass
	var can_build := TownSimulation.can_construct_building(town, Enums.BuildingType.GRANARY, ai_civ)
	assert_true(can_build, "AI should bypass worker check")


# ==================== Explorer Reveals Fog ====================

func test_explorer_reveals_fog() -> void:
	## Explorer moving into a region marks it + adjacent as explored.
	var civ := _setup_test_map()
	var events := {"unit_events": []}

	# Place explorer in R1 (owned), target R2 (neutral)
	var explorer := UnitData.new(-1, "Scout", Enums.UnitType.EXPLORER, 0, 1)
	GameState.add_unit(explorer)
	explorer.target_region_id = 2

	# Before move: R2 and R3 should NOT be explored
	GameState.update_all_visibility()
	# R0 owned, R1 owned, so R0,R1,R2(adj to R1) visible, R3 hidden
	assert_eq(GameState.get_player_visibility(3), Enums.VisibilityState.HIDDEN)

	# Tick 1: transit
	UnitSimulation.process_unit_movement(events)
	# Tick 2: arrive
	UnitSimulation.process_unit_movement(events)

	assert_eq(explorer.region_id, 2, "Explorer should be in R2")
	# Explorer in R2 should have explored R2 + R3 (adjacent to R2)
	assert_true(civ.explored_set.has(2), "R2 should be explored")
	assert_true(civ.explored_set.has(3), "R3 should be explored (adjacent to explorer)")


# ==================== Explorer Claim Region ====================

func test_explorer_claim_region() -> void:
	## Explorer claims a neutral region via player action.
	var civ := _setup_test_map()
	civ.production_stockpile = 200

	# Place idle explorer in R1 (owned, adjacent to R2)
	var explorer := UnitData.new(-1, "Scout", Enums.UnitType.EXPLORER, 0, 1)
	GameState.add_unit(explorer)

	PlayerActions.queue_action({
		"type": "explorer_claim",
		"region_id": 2,
		"explorer_id": explorer.id,
	})

	var events := PlayerActions.process_queued_actions(civ)
	assert_eq(events.size(), 1, "Should have 1 expansion event")
	assert_eq(events[0]["type"], "expansion")
	assert_eq(GameState.get_region(2).owner_id, 0, "Region 2 should be claimed by player")
	assert_eq(explorer.region_id, 2, "Explorer should move into claimed region")


# ==================== Training ====================

func test_train_worker_requires_workshop() -> void:
	## Training a worker fails without a Workshop building.
	var civ := _setup_test_map()
	civ.production_stockpile = 100

	var region := GameState.get_region(0)
	var town := TownData.new(0, "Capital Town", 0)
	town.population = 500
	region.towns = [town]

	var check := UnitSimulation.can_train_unit(Enums.UnitType.WORKER, 0, 0)
	assert_false(check["can_train"], "Should not train worker without Workshop")
	assert_true(check["reason"].find("Workshop") >= 0, "Reason should mention Workshop")


func test_train_worker_with_workshop() -> void:
	## Training a worker succeeds with Workshop and enough production.
	var civ := _setup_test_map()
	civ.production_stockpile = 100

	var region := GameState.get_region(0)
	var town := TownData.new(0, "Capital Town", 0)
	town.population = 500
	town.add_building(Enums.BuildingType.WORKSHOP)
	region.towns = [town]

	var unit := UnitSimulation.train_unit(Enums.UnitType.WORKER, 0, 0)
	assert_not_null(unit, "Should successfully train worker")
	assert_eq(unit.unit_type, Enums.UnitType.WORKER)
	assert_eq(unit.region_id, 0)
	assert_eq(civ.production_stockpile, 100 - Constants.WORKER_TRAIN_COST)


# ==================== Leader Bonus ====================

func test_leader_bonus_applied() -> void:
	## Leader unit with traits returns correct bonus dict.
	GameState.units.clear()
	GameState.next_unit_id = 0

	var leader := UnitData.new(-1, "King", Enums.UnitType.LEADER, 0, 0)
	leader.leader_trait_a = 0  # Builder: +10% production
	leader.leader_trait_b = 4  # Merchant: +10% food
	GameState.add_unit(leader)

	var bonus := UnitSimulation.get_leader_bonus(0)
	assert_almost_eq(bonus["production"], 0.10, 0.001, "Builder trait should give +10% production")
	assert_almost_eq(bonus["food"], 0.10, 0.001, "Merchant trait should give +10% food")
	assert_almost_eq(bonus["military"], 0.0, 0.001, "No military bonus")
	assert_almost_eq(bonus["stability"], 0.0, 0.001, "No stability bonus")
	assert_almost_eq(bonus["tech"], 0.0, 0.001, "No tech bonus")


# ==================== Infrastructure Requires Worker ====================

func test_infrastructure_requires_worker() -> void:
	## Infrastructure upgrade fails without a worker in the region.
	var civ := _setup_test_map()
	civ.production_stockpile = 500

	var region := GameState.get_region(0)
	# No worker in region 0
	var result := EconomySimulation.try_upgrade_infrastructure(civ, region)
	assert_false(result, "Should not upgrade infrastructure without worker")
	assert_eq(civ.production_stockpile, 500, "Stockpile should be unchanged")


func test_infrastructure_succeeds_with_worker() -> void:
	## Infrastructure upgrade succeeds with a worker present.
	var civ := _setup_test_map()
	civ.production_stockpile = 500

	var region := GameState.get_region(0)
	var worker := UnitData.new(-1, "Worker", Enums.UnitType.WORKER, 0, 0)
	GameState.add_unit(worker)

	var result := EconomySimulation.try_upgrade_infrastructure(civ, region)
	assert_true(result, "Should upgrade with worker present")
	assert_eq(region.infrastructure_level, 1, "Infra should be level 1")
