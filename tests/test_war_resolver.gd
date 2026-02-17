extends GutTest

## Tests for WarResolver (core/simulation/war_resolver.gd)


func _make_civ(
	id: int = 0,
	military: float = 100.0,
	stability: float = 50.0,
	aggression: float = 0.5,
) -> CivilizationData:
	var civ := CivilizationData.new(id, "Civ_%d" % id, Color.RED)
	civ.military_strength = military
	civ.stability = stability
	civ.aggression_bias = aggression
	return civ


func _make_region(
	id: int = 0,
	owner: int = 1,
	terrain: Enums.TerrainType = Enums.TerrainType.PLAINS,
) -> RegionData:
	var region := RegionData.new(id, "Region_%d" % id, terrain)
	region.owner_id = owner
	return region


# --- Battle Resolution ---

func test_stronger_army_wins() -> void:
	var attacker := _make_civ(0, 200.0, 50.0)
	var defender := _make_civ(1, 50.0, 50.0)
	var region := _make_region(0, 1, Enums.TerrainType.PLAINS)

	# Run many battles to confirm statistical win rate
	var attacker_wins := 0
	for i in 100:
		seed(i)
		var result := WarResolver.resolve_battle(attacker, defender, region)
		if result["winner_id"] == 0:
			attacker_wins += 1

	assert_true(attacker_wins > 70,
		"4:1 military advantage should win most battles (won %d/100)" % attacker_wins)


func test_mountains_help_defender() -> void:
	var attacker := _make_civ(0, 100.0, 50.0)
	var defender := _make_civ(1, 100.0, 50.0)

	var plains := _make_region(0, 1, Enums.TerrainType.PLAINS)
	var mountains := _make_region(1, 1, Enums.TerrainType.MOUNTAINS)

	var plains_def_wins := 0
	var mountain_def_wins := 0

	for i in 200:
		seed(i)
		var r1 := WarResolver.resolve_battle(attacker, defender, plains)
		if r1["winner_id"] == 1:
			plains_def_wins += 1

		seed(i)
		var r2 := WarResolver.resolve_battle(attacker, defender, mountains)
		if r2["winner_id"] == 1:
			mountain_def_wins += 1

	assert_true(mountain_def_wins > plains_def_wins,
		"Mountains should favor defender (mtn: %d, plains: %d)" % [mountain_def_wins, plains_def_wins])


# --- Apply Battle Result ---

func test_apply_battle_transfers_region() -> void:
	var attacker := _make_civ(0, 100.0, 50.0)
	var defender := _make_civ(1, 100.0, 50.0)
	var region := _make_region(0, 1)

	var result := {"winner_id": 0, "loser_id": 1,
		"attacker_strength": 100.0, "defender_strength": 80.0, "region_id": 0}

	var event := WarResolver.apply_battle_result(result, attacker, defender, region)

	assert_eq(region.owner_id, 0, "Region should transfer to winner")
	assert_eq(event["old_owner"], 1)
	assert_eq(event["winner_id"], 0)


func test_apply_battle_loser_loses_stability() -> void:
	var attacker := _make_civ(0, 100.0, 80.0)
	var defender := _make_civ(1, 100.0, 80.0)
	var region := _make_region(0, 1)

	var result := {"winner_id": 0, "loser_id": 1,
		"attacker_strength": 100.0, "defender_strength": 80.0, "region_id": 0}

	GameState.set_sim_seed(42)
	WarResolver.apply_battle_result(result, attacker, defender, region)

	assert_true(defender.stability < 80.0,
		"Loser should lose stability")


func test_apply_battle_both_lose_military() -> void:
	var attacker := _make_civ(0, 100.0, 50.0)
	var defender := _make_civ(1, 100.0, 50.0)
	var region := _make_region(0, 1)

	var result := {"winner_id": 0, "loser_id": 1,
		"attacker_strength": 100.0, "defender_strength": 100.0, "region_id": 0}

	WarResolver.apply_battle_result(result, attacker, defender, region)

	assert_true(attacker.military_strength < 100.0,
		"Attacker should lose military from attrition")
	assert_true(defender.military_strength < 100.0,
		"Defender should lose military from attrition")


func test_apply_battle_returns_event_dict() -> void:
	var attacker := _make_civ(0, 100.0, 50.0)
	var defender := _make_civ(1, 100.0, 50.0)
	var region := _make_region(0, 1)

	var result := {"winner_id": 0, "loser_id": 1,
		"attacker_strength": 100.0, "defender_strength": 80.0, "region_id": 0}

	var event := WarResolver.apply_battle_result(result, attacker, defender, region)

	assert_has(event, "region_id")
	assert_has(event, "old_owner")
	assert_has(event, "winner_id")
	assert_has(event, "attacker_id")
	assert_has(event, "defender_id")
	assert_has(event, "region_name")
	assert_has(event, "attacker_name")
	assert_has(event, "defender_name")
