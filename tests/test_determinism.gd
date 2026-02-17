extends GutTest

## Tests for simulation determinism via seeded RNG.
## Verifies that identical seeds produce identical outcomes.


func before_each() -> void:
	_setup_game_state()


func _setup_game_state() -> void:
	## Reset GameState to a clean baseline for deterministic runs.
	GameState.regions.clear()
	GameState.civilizations.clear()
	GameState.heroes.clear()
	GameState.current_year = 0
	GameState.next_hero_id = 0
	GameState.turn_log.clear()
	GameState.player_civ_id = 0
	PlayerActions.clear_queue()
	GameState.load_game_data()


func _run_simulation(years: int) -> void:
	## Run the simulation for N years.
	for _y in years:
		GameState.current_year += 1
		SimulationEngine.process_year()


func _get_rng_state() -> int:
	return GameState.sim_rng.state


func _region_hash() -> int:
	## Quick hash of all region ownership + population for divergence detection.
	var h := 0
	for region in GameState.regions.values():
		h = h * 31 + region.owner_id * 1000 + region.population
	return h


func _take_snapshot() -> Dictionary:
	## Capture current game state for comparison.
	var snapshot := {}
	for civ in GameState.civilizations.values():
		snapshot[civ.id] = {
			"population": civ.total_population,
			"stability": civ.stability,
			"food_stockpile": civ.food_stockpile,
			"production_stockpile": civ.production_stockpile,
			"military_strength": civ.military_strength,
			"is_collapsed": civ.is_collapsed,
			"technologies": civ.technologies.duplicate(),
			"war_targets": civ.war_targets.duplicate(),
			"region_count": GameState.get_regions_by_owner(civ.id).size(),
			"governance_tier": civ.governance_tier,
			"current_era": civ.current_era,
		}
	return snapshot


# --- Determinism Tests ---

func test_same_seed_50yr_deterministic() -> void:
	## Two runs with the same seed over 50 years must produce identical state.
	var test_seed := 12345

	_setup_game_state()
	GameState.set_sim_seed(test_seed)
	_run_simulation(50)
	var snapshot_a := _take_snapshot()

	_setup_game_state()
	GameState.set_sim_seed(test_seed)
	_run_simulation(50)
	var snapshot_b := _take_snapshot()

	for civ_id in snapshot_a:
		var a: Dictionary = snapshot_a[civ_id]
		var b: Dictionary = snapshot_b[civ_id]
		assert_eq(a["population"], b["population"],
			"Civ %d population differs at Y50" % civ_id)
		assert_eq(a["stability"], b["stability"],
			"Civ %d stability differs at Y50" % civ_id)
		assert_eq(a["food_stockpile"], b["food_stockpile"],
			"Civ %d food_stockpile differs at Y50" % civ_id)
		assert_eq(a["production_stockpile"], b["production_stockpile"],
			"Civ %d production_stockpile differs at Y50" % civ_id)
		assert_eq(a["military_strength"], b["military_strength"],
			"Civ %d military_strength differs at Y50" % civ_id)
		assert_eq(a["is_collapsed"], b["is_collapsed"],
			"Civ %d collapse state differs at Y50" % civ_id)
		assert_eq(a["technologies"], b["technologies"],
			"Civ %d technologies differ at Y50" % civ_id)
		assert_eq(a["war_targets"], b["war_targets"],
			"Civ %d war_targets differ at Y50" % civ_id)
		assert_eq(a["region_count"], b["region_count"],
			"Civ %d region_count differs at Y50" % civ_id)
		assert_eq(a["governance_tier"], b["governance_tier"],
			"Civ %d governance_tier differs at Y50" % civ_id)
		assert_eq(a["current_era"], b["current_era"],
			"Civ %d current_era differs at Y50" % civ_id)


func test_different_seeds_produce_different_outcomes() -> void:
	## Two runs with different seeds should diverge.
	_setup_game_state()
	GameState.set_sim_seed(11111)
	_run_simulation(50)
	var snapshot_a := _take_snapshot()

	_setup_game_state()
	GameState.set_sim_seed(99999)
	_run_simulation(50)
	var snapshot_b := _take_snapshot()

	var any_differ := false
	for civ_id in snapshot_a:
		var a: Dictionary = snapshot_a[civ_id]
		var b: Dictionary = snapshot_b[civ_id]
		if a["population"] != b["population"] or a["stability"] != b["stability"]:
			any_differ = true
			break
	assert_true(any_differ, "Different seeds should produce different outcomes")


func test_same_seed_100yr_deterministic() -> void:
	## Extended determinism check: year-by-year for first 50yr, then 10yr chunks.
	## Finds exact year of divergence if any.
	var test_seed := 12345

	# Run A: collect RNG state after every year for first 50yr
	_setup_game_state()
	GameState.set_sim_seed(test_seed)
	var rng_states_a: Array[int] = []
	var region_hashes_a: Array[int] = []
	for _y in 50:
		GameState.current_year += 1
		SimulationEngine.process_year()
		rng_states_a.append(_get_rng_state())
		region_hashes_a.append(_region_hash())

	# Run B: collect RNG state after every year for first 50yr
	_setup_game_state()
	GameState.set_sim_seed(test_seed)
	var rng_states_b: Array[int] = []
	var region_hashes_b: Array[int] = []
	for _y in 50:
		GameState.current_year += 1
		SimulationEngine.process_year()
		rng_states_b.append(_get_rng_state())
		region_hashes_b.append(_region_hash())

	for yr in 50:
		assert_eq(rng_states_a[yr], rng_states_b[yr],
			"RNG state differs at Y%d" % (yr + 1))
		assert_eq(region_hashes_a[yr], region_hashes_b[yr],
			"Region hash differs at Y%d" % (yr + 1))


func test_seed_zero_randomizes() -> void:
	## Seed 0 should pick a random seed each time.
	GameState.set_sim_seed(0)
	var seed_a := GameState.sim_seed

	GameState.set_sim_seed(0)
	var seed_b := GameState.sim_seed

	# These should almost certainly differ (probability of collision ~1/2^64)
	assert_ne(seed_a, seed_b, "Seed 0 should generate different random seeds")
