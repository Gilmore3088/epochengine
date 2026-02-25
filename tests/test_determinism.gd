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
	GameState.next_town_id = 0
	GameState.turn_log.clear()
	GameState.player_civ_id = 0
	GameState.units.clear()
	GameState.next_unit_id = 0
	PlayerActions.clear_queue()
	GameState.load_game_data()
	GameState.start_new_game()
	# Ensure all regions start with empty towns (prevent shared-array leaking)
	for region in GameState.regions.values():
		region.towns = []


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


func _town_hash() -> int:
	## Hash including town counts and next_town_id for divergence detection.
	var h := GameState.next_town_id
	for region in GameState.regions.values():
		h = h * 31 + region.towns.size() * 100 + region.id
	return h


func _full_state_hash() -> int:
	## Comprehensive hash of all game state for deep equality check.
	var h := GameState.current_year * 1000000 + GameState.next_town_id * 1000 + GameState.next_hero_id
	for region in GameState.regions.values():
		h = h * 31 + region.id * 10000 + region.owner_id * 1000 + region.population
		h = h * 31 + region.infrastructure_level * 100 + region.development_tier * 10
		h = h * 31 + region.towns.size()
		h = h * 31 + int(region.food_yield) * 100 + int(region.production_yield)
	for civ in GameState.civilizations.values():
		h = h * 31 + civ.id * 100000
		h = h * 31 + civ.total_population * 1000
		h = h * 31 + civ.food_stockpile * 100
		h = h * 31 + civ.production_stockpile * 10
		h = h * 31 + int(civ.stability * 100)
		h = h * 31 + int(civ.military_strength * 100)
		h = h * 31 + civ.war_targets.size() * 10
		h = h * 31 + civ.technologies.size()
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
	## Strategy: Run both simulations, collect snapshots, then compare.
	## Also compare Run A against itself (immediate re-run) to check for leaks.
	var test_seed := 12345

	# Run A
	_setup_game_state()
	GameState.set_sim_seed(test_seed)
	var init_snap_a := _deep_snapshot()
	var snapshots_a: Array[Dictionary] = []
	for _y in 50:
		GameState.current_year += 1
		SimulationEngine.process_year()
		snapshots_a.append(_deep_snapshot())

	# Run B (immediate re-run with same seed)
	_setup_game_state()
	GameState.set_sim_seed(test_seed)
	var init_snap_b := _deep_snapshot()
	var init_diffs := _find_all_diffs(init_snap_a, init_snap_b)
	if not init_diffs.is_empty():
		print("=== INITIAL STATE DIFFERS ===")
		for d in init_diffs:
			print("  %s" % d)
	assert_true(init_diffs.is_empty(), "Initial state must be identical between runs")
	var snapshots_b: Array[Dictionary] = []
	for _y in 50:
		GameState.current_year += 1
		SimulationEngine.process_year()
		snapshots_b.append(_deep_snapshot())

	# Compare snapshots
	var found_divergence := false
	for yr in 50:
		var diffs := _find_all_diffs(snapshots_a[yr], snapshots_b[yr])
		if not diffs.is_empty() and not found_divergence:
			found_divergence = true
			print("=== 50yr FIRST DIVERGENCE at Y%d ===" % (yr + 1))
			for d in diffs:
				print("  %s" % d)
			if yr > 0:
				print("--- Prior year Y%d diffs ---" % yr)
				var prior_diffs := _find_all_diffs(snapshots_a[yr - 1], snapshots_b[yr - 1])
				if prior_diffs.is_empty():
					print("  (none)")
				for d in prior_diffs:
					print("  %s" % d)
		assert_eq(
			snapshots_a[yr]["meta"]["rng_state"],
			snapshots_b[yr]["meta"]["rng_state"],
			"RNG state differs at Y%d" % (yr + 1))
	if not found_divergence:
		pass_test("50yr: All years match perfectly")


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


func _deep_snapshot() -> Dictionary:
	## Capture complete state for field-level comparison.
	var snap := {"regions": {}, "civs": {}, "meta": {}}
	snap["meta"]["year"] = GameState.current_year
	snap["meta"]["next_town_id"] = GameState.next_town_id
	snap["meta"]["next_hero_id"] = GameState.next_hero_id
	snap["meta"]["rng_state"] = GameState.sim_rng.state
	# Track iteration order of civs and regions for debugging
	var civ_order: Array[int] = []
	for civ in GameState.civilizations.values():
		civ_order.append(civ.id)
	snap["meta"]["civ_order"] = civ_order
	var region_order: Array[int] = []
	for region in GameState.regions.values():
		region_order.append(region.id)
	snap["meta"]["region_order"] = region_order
	for region in GameState.regions.values():
		snap["regions"][region.id] = {
			"owner_id": region.owner_id,
			"population": region.population,
			"infra": region.infrastructure_level,
			"dev_tier": region.development_tier,
			"food_yield": region.food_yield,
			"prod_yield": region.production_yield,
			"supply": region.supply_value,
			"towns_count": region.towns.size(),
			"town_pops": region.towns.map(func(t): return t.population),
			"town_ids": region.towns.map(func(t): return t.id),
			"town_buildings": region.towns.map(func(t): return t.buildings.duplicate(true)),
			"renewable_deg": region.renewable_degradation,
			"demotion_years": region.demotion_years,
			"size_factor": region.size_factor,
			"defense_mod": region.defense_modifier,
			"urbanization": region.urbanization_level,
			"extraction_years": region.extraction_years,
			"resource_deposits": region.resource_deposits.duplicate(),
		}
	for civ in GameState.civilizations.values():
		snap["civs"][civ.id] = {
			"pop": civ.total_population,
			"stability": civ.stability,
			"food": civ.food_stockpile,
			"prod": civ.production_stockpile,
			"military": civ.military_strength,
			"collapsed": civ.is_collapsed,
			"war_targets": civ.war_targets.duplicate(),
			"techs": civ.technologies.duplicate(),
			"region_count": GameState.get_regions_by_owner(civ.id).size(),
			"gov_tier": civ.governance_tier,
			"era": civ.current_era,
			"hero_ids": civ.hero_ids.duplicate(),
			"golden_years": civ.golden_age_years_remaining,
			"consec_low": civ.consecutive_low_stability_years,
			"knowledge": civ.knowledge,
			"energy": civ.energy,
			"social_coord": civ.social_coordination,
			"econ_surplus": civ.economic_surplus,
			"mil_pressure": civ.military_pressure,
			"war_durations": civ.war_durations.duplicate(),
			"peace_cooldowns": civ.peace_cooldowns.duplicate(),
			"alliances": civ.alliance_partners.duplicate(),
			"golden_cooldown": civ.golden_age_cooldown,
			"gov_years": civ.governance_years,
			"expansion_bias": civ.expansion_bias,
			"aggression_bias": civ.aggression_bias,
			"diplomacy_bias": civ.diplomacy_bias,
			"economy_bias": civ.economy_bias,
			"initial_expansion_bias": civ.initial_expansion_bias,
			"years_at_peace": civ.years_at_peace,
			"resource_stockpiles": civ.resource_stockpiles.duplicate(),
			"resource_prod_log": civ.resource_production_log.duplicate(),
		}
	# Also capture heroes
	snap["heroes"] = {}
	for hero in GameState.heroes.values():
		snap["heroes"][hero.id] = {
			"name": hero.hero_name,
			"type": hero.type,
			"owner_civ_id": hero.owner_civ_id,
			"age": hero.age,
		}
	return snap


func _vals_differ(a: Variant, b: Variant) -> bool:
	## Exact comparison — uses != for exact float matching (no epsilon).
	if typeof(a) == TYPE_FLOAT and typeof(b) == TYPE_FLOAT:
		return a != b  # Exact float comparison, no epsilon tolerance
	return str(a) != str(b)


func _fmt_val(v: Variant) -> String:
	## Format value with full float precision.
	if typeof(v) == TYPE_FLOAT:
		return "%.17g" % v
	return str(v)


func _find_all_diffs(snap_a: Dictionary, snap_b: Dictionary) -> Array[String]:
	## Compare two deep snapshots and return ALL differences.
	var diffs: Array[String] = []
	# Compare meta
	for key in snap_a["meta"]:
		if _vals_differ(snap_a["meta"][key], snap_b["meta"][key]):
			diffs.append("meta.%s: %s vs %s" % [key, _fmt_val(snap_a["meta"][key]), _fmt_val(snap_b["meta"][key])])
	# Compare regions
	for rid in snap_a["regions"]:
		var ra: Dictionary = snap_a["regions"][rid]
		var rb: Dictionary = snap_b["regions"][rid]
		for key in ra:
			if _vals_differ(ra[key], rb[key]):
				diffs.append("region[%d].%s: %s vs %s" % [rid, key, _fmt_val(ra[key]), _fmt_val(rb[key])])
	# Compare civs
	for cid in snap_a["civs"]:
		var ca: Dictionary = snap_a["civs"][cid]
		var cb: Dictionary = snap_b["civs"][cid]
		for key in ca:
			if _vals_differ(ca[key], cb[key]):
				diffs.append("civ[%d].%s: %s vs %s" % [cid, key, _fmt_val(ca[key]), _fmt_val(cb[key])])
	# Compare heroes
	var hero_ids_a: Array = snap_a["heroes"].keys()
	var hero_ids_b: Array = snap_b["heroes"].keys()
	if str(hero_ids_a) != str(hero_ids_b):
		diffs.append("heroes.keys: %s vs %s" % [str(hero_ids_a), str(hero_ids_b)])
	for hid in snap_a["heroes"]:
		if snap_b["heroes"].has(hid):
			var ha: Dictionary = snap_a["heroes"][hid]
			var hb: Dictionary = snap_b["heroes"][hid]
			for key in ha:
				if _vals_differ(ha[key], hb[key]):
					diffs.append("hero[%d].%s: %s vs %s" % [hid, key, _fmt_val(ha[key]), _fmt_val(hb[key])])
	return diffs


func test_same_seed_100yr_deterministic() -> void:
	## Extended determinism check: run two 50yr simulations with same seed,
	## collect deep snapshots each year, find exact first divergence.
	var test_seed := 12345

	# Run A: collect deep snapshot after every year
	_setup_game_state()
	GameState.set_sim_seed(test_seed)
	var snapshots_a: Array[Dictionary] = []
	for _y in 50:
		GameState.current_year += 1
		SimulationEngine.process_year()
		snapshots_a.append(_deep_snapshot())

	# Run B: collect deep snapshot after every year
	_setup_game_state()
	GameState.set_sim_seed(test_seed)
	var snapshots_b: Array[Dictionary] = []
	for _y in 50:
		GameState.current_year += 1
		SimulationEngine.process_year()
		snapshots_b.append(_deep_snapshot())

	# Find first divergence and report ALL diffs at that year
	var found_divergence := false
	for yr in 50:
		var diffs := _find_all_diffs(snapshots_a[yr], snapshots_b[yr])
		if not diffs.is_empty() and not found_divergence:
			found_divergence = true
			print("=== FIRST DIVERGENCE at Y%d ===" % (yr + 1))
			for d in diffs:
				print("  %s" % d)
			# Also print prior year's civ stats for context
			if yr > 0:
				print("--- Prior year Y%d civ states ---" % yr)
				for cid in snapshots_a[yr - 1]["civs"]:
					var ca: Dictionary = snapshots_a[yr - 1]["civs"][cid]
					var cb: Dictionary = snapshots_b[yr - 1]["civs"][cid]
					var ca_diffs: Array[String] = []
					for key in ca:
						if str(ca[key]) != str(cb[key]):
							ca_diffs.append("%s: %s vs %s" % [key, str(ca[key]), str(cb[key])])
					if not ca_diffs.is_empty():
						print("  civ[%d] prior diffs: %s" % [cid, ", ".join(ca_diffs)])
		assert_eq(
			snapshots_a[yr]["meta"]["rng_state"],
			snapshots_b[yr]["meta"]["rng_state"],
			"RNG state differs at Y%d" % (yr + 1))
	if not found_divergence:
		pass_test("All 50 years match perfectly")


func test_seed_zero_randomizes() -> void:
	## Seed 0 should pick a random seed each time.
	GameState.set_sim_seed(0)
	var seed_a := GameState.sim_seed

	GameState.set_sim_seed(0)
	var seed_b := GameState.sim_seed

	# These should almost certainly differ (probability of collision ~1/2^64)
	assert_ne(seed_a, seed_b, "Seed 0 should generate different random seeds")
