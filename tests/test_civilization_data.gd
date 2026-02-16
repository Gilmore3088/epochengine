extends GutTest

## Tests for CivilizationData (resources/civilization_data.gd)


func _make_civ(stability: float = 50.0) -> CivilizationData:
	var civ := CivilizationData.new(0, "TestCiv", Color.RED)
	civ.stability = stability
	civ.total_population = 5000
	civ.food_stockpile = 100
	civ.production_stockpile = 100
	return civ


# --- State Machine ---

func test_collapsed_state() -> void:
	var civ := _make_civ()
	civ.is_collapsed = true
	assert_eq(civ.get_state(), Enums.CivState.COLLAPSED)


func test_declining_state() -> void:
	var civ := _make_civ(20.0)  # Below AI_SURVIVAL threshold (30)
	assert_eq(civ.get_state(), Enums.CivState.DECLINING)


func test_growing_state_high_stability() -> void:
	var civ := _make_civ(80.0)  # Above 70
	assert_eq(civ.get_state(), Enums.CivState.GROWING)


func test_growing_state_golden_age() -> void:
	var civ := _make_civ(50.0)
	civ.golden_age_years_remaining = 10
	assert_eq(civ.get_state(), Enums.CivState.GROWING)


func test_stable_state() -> void:
	var civ := _make_civ(50.0)  # Between 30 and 70
	assert_eq(civ.get_state(), Enums.CivState.STABLE)


# --- War ---

func test_is_at_war() -> void:
	var civ := _make_civ()
	assert_false(civ.is_at_war())
	civ.war_targets = [1]
	assert_true(civ.is_at_war())


# --- Golden Age ---

func test_is_in_golden_age() -> void:
	var civ := _make_civ()
	assert_false(civ.is_in_golden_age())
	civ.golden_age_years_remaining = 5
	assert_true(civ.is_in_golden_age())


func test_can_enter_golden_age_all_conditions() -> void:
	var civ := _make_civ(85.0)
	civ.food_stockpile = 100
	civ.production_stockpile = 100
	civ.war_targets = []
	civ.golden_age_cooldown = 0
	assert_true(civ.can_enter_golden_age())


func test_cannot_enter_golden_age_low_stability() -> void:
	var civ := _make_civ(70.0)  # Below 80 threshold
	civ.food_stockpile = 100
	civ.production_stockpile = 100
	assert_false(civ.can_enter_golden_age())


func test_cannot_enter_golden_age_at_war() -> void:
	var civ := _make_civ(85.0)
	civ.food_stockpile = 100
	civ.production_stockpile = 100
	civ.war_targets = [1]
	assert_false(civ.can_enter_golden_age())


func test_cannot_enter_golden_age_food_deficit() -> void:
	var civ := _make_civ(85.0)
	civ.food_stockpile = -10
	civ.production_stockpile = 100
	assert_false(civ.can_enter_golden_age())


func test_cannot_enter_golden_age_on_cooldown() -> void:
	var civ := _make_civ(85.0)
	civ.food_stockpile = 100
	civ.production_stockpile = 100
	civ.golden_age_cooldown = 15
	assert_false(civ.can_enter_golden_age())


# --- Heroes ---

func test_hero_count() -> void:
	var civ := _make_civ()
	assert_eq(civ.hero_count(), 0)
	civ.hero_ids = [1, 2]
	assert_eq(civ.hero_count(), 2)


func test_can_spawn_hero() -> void:
	var civ := _make_civ()
	civ.hero_ids = []
	assert_true(civ.can_spawn_hero())

	civ.hero_ids = [1, 2, 3]  # Max is 3
	assert_false(civ.can_spawn_hero())
