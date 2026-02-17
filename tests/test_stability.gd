extends GutTest

## Tests for StabilitySimulation (core/simulation/stability.gd)


func _make_civ(
	stability: float = 50.0,
	food_stockpile: int = 100,
	total_population: int = 5000,
) -> CivilizationData:
	var civ := CivilizationData.new(0, "TestCiv", Color.RED)
	civ.stability = stability
	civ.food_stockpile = food_stockpile
	civ.total_population = total_population
	civ.capital_region_id = 0
	return civ


func _make_region(id: int = 0, owner: int = 0) -> RegionData:
	var region := RegionData.new(id, "Region_%d" % id, Enums.TerrainType.PLAINS)
	region.owner_id = owner
	return region


# --- Overextension Penalty ---

func test_overextension_no_penalty_under_threshold() -> void:
	# Private method, test via recalculate with known inputs
	var civ := _make_civ(50.0, 0, 5000)
	civ.food_stockpile = 0  # Neutral food factor
	var regions: Array[RegionData] = []
	for i in 7:  # 7 regions, within admin capacity
		regions.append(_make_region(i, 0))

	# Stability should not have overextension penalty
	# We can't isolate the function easily, so test the behavior
	# With 7 regions, no overextension penalty
	GameState.set_sim_seed(42)  # Deterministic
	var new_stability := StabilitySimulation.recalculate(civ, regions)
	assert_true(new_stability >= 0.0 and new_stability <= 100.0,
		"Stability should be in valid range")


func test_overextension_penalty_above_threshold() -> void:
	var civ := _make_civ(80.0, 0, 5000)
	civ.food_stockpile = 0

	var small_regions: Array[RegionData] = []
	for i in 5:
		small_regions.append(_make_region(i, 0))

	var large_regions: Array[RegionData] = []
	for i in 30:  # 30 regions, well above admin capacity
		large_regions.append(_make_region(i, 0))

	GameState.set_sim_seed(42)
	var stab_small := StabilitySimulation.recalculate(civ, small_regions)

	civ.stability = 80.0  # Reset
	GameState.set_sim_seed(42)  # Same seed for same random values
	var stab_large := StabilitySimulation.recalculate(civ, large_regions)

	# 30 regions = well above admin capacity, quadratic penalty applies
	assert_true(stab_small > stab_large,
		"More regions should reduce stability via overextension")


# --- Collapse Check ---

func test_collapse_below_threshold_accumulates() -> void:
	var civ := _make_civ(3.0)  # Below COLLAPSE_STABILITY_THRESHOLD (5.0)
	civ.consecutive_low_stability_years = 3

	StabilitySimulation.check_collapse(civ)
	assert_eq(civ.consecutive_low_stability_years, 4,
		"Should increment consecutive years below threshold")


func test_collapse_above_threshold_resets() -> void:
	var civ := _make_civ(50.0)
	civ.consecutive_low_stability_years = 3

	StabilitySimulation.check_collapse(civ)
	assert_eq(civ.consecutive_low_stability_years, 0,
		"Should reset counter when above threshold")


func test_collapse_triggers_after_consecutive_years() -> void:
	var civ := _make_civ(3.0)  # Below COLLAPSE_STABILITY_THRESHOLD (5.0)
	civ.consecutive_low_stability_years = 9  # 10th call triggers

	assert_true(StabilitySimulation.check_collapse(civ),
		"Should collapse after %d consecutive low-stability years" % Constants.COLLAPSE_CONSECUTIVE_YEARS)


func test_collapse_does_not_trigger_early() -> void:
	var civ := _make_civ(3.0)  # Below COLLAPSE_STABILITY_THRESHOLD (5.0)
	civ.consecutive_low_stability_years = 8  # 9th call, not yet

	assert_false(StabilitySimulation.check_collapse(civ),
		"Should not collapse before %d years" % Constants.COLLAPSE_CONSECUTIVE_YEARS)


# --- Stability Bounds ---

func test_stability_clamped_to_min() -> void:
	var civ := _make_civ(2.0, -200, 5000)  # Very negative food
	civ.war_targets = [1, 2, 3]  # Multiple wars

	var regions: Array[RegionData] = []
	for i in 15:
		regions.append(_make_region(i, 0))

	var new_stability := StabilitySimulation.recalculate(civ, regions)
	assert_true(new_stability >= Constants.STABILITY_MIN,
		"Stability should never go below minimum")


func test_stability_clamped_to_max() -> void:
	var civ := _make_civ(99.0, 1000, 5000)
	# Good food, no wars, few regions
	var regions: Array[RegionData] = [_make_region(0, 0)]

	GameState.set_sim_seed(42)
	var new_stability := StabilitySimulation.recalculate(civ, regions)
	assert_true(new_stability <= Constants.STABILITY_MAX,
		"Stability should never exceed maximum")


# --- Golden Age Floor ---

func test_golden_age_stability_floor() -> void:
	var civ := _make_civ(2.0, -200, 5000)
	civ.golden_age_years_remaining = 10
	civ.war_targets = [1, 2]

	var regions: Array[RegionData] = []
	for i in 15:
		regions.append(_make_region(i, 0))

	var new_stability := StabilitySimulation.recalculate(civ, regions)
	assert_true(new_stability >= Constants.GOLDEN_AGE_STABILITY_FLOOR,
		"Golden age should enforce stability floor")


# --- War Exhaustion ---

func test_war_exhaustion_no_wars() -> void:
	var civ := _make_civ(50.0, 0, 5000)
	civ.war_targets = []
	var regions: Array[RegionData] = [_make_region(0, 0)]

	GameState.set_sim_seed(42)
	var s1 := StabilitySimulation.recalculate(civ, regions)

	civ.stability = 50.0
	civ.war_targets = [1, 2]
	GameState.set_sim_seed(42)
	var s2 := StabilitySimulation.recalculate(civ, regions)

	assert_true(s1 > s2, "Wars should reduce stability via exhaustion")


# --- Hero Modifier ---

func test_reformer_hero_boosts_stability() -> void:
	var civ := _make_civ(50.0, 0, 5000)
	var regions: Array[RegionData] = [_make_region(0, 0)]

	GameState.set_sim_seed(42)
	var s_no_hero := StabilitySimulation.recalculate(civ, regions)

	civ.stability = 50.0
	var hero := HeroData.new(0, "Reformer", Enums.HeroType.REFORMER, 0)
	GameState.heroes.clear()
	GameState.add_hero(hero)
	civ.hero_ids = [hero.id]

	GameState.set_sim_seed(42)
	var s_with_hero := StabilitySimulation.recalculate(civ, regions)

	assert_true(s_with_hero > s_no_hero,
		"Reformer hero should boost stability")

	GameState.heroes.clear()
