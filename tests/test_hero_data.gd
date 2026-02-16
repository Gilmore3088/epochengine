extends GutTest

## Tests for HeroData (resources/hero_data.gd)


# --- Modifier Values ---

func test_general_modifier() -> void:
	var hero := HeroData.new(0, "General", Enums.HeroType.GENERAL, 0)
	assert_eq(hero.get_modifier_type(), "military")
	assert_eq(hero.get_modifier_value(), Constants.HERO_GENERAL_MILITARY_BONUS)


func test_reformer_modifier() -> void:
	var hero := HeroData.new(0, "Reformer", Enums.HeroType.REFORMER, 0)
	assert_eq(hero.get_modifier_type(), "stability")
	assert_eq(hero.get_modifier_value(), Constants.HERO_REFORMER_STABILITY_BONUS)


func test_visionary_modifier() -> void:
	var hero := HeroData.new(0, "Visionary", Enums.HeroType.VISIONARY, 0)
	assert_eq(hero.get_modifier_type(), "production")
	assert_eq(hero.get_modifier_value(), Constants.HERO_VISIONARY_PRODUCTION_BONUS)


# --- Aging & Lifespan ---

func test_age_one_year() -> void:
	var hero := HeroData.new(0, "Test", Enums.HeroType.GENERAL, 0)
	hero.age = 30
	hero.age_one_year()
	assert_eq(hero.age, 31)


func test_is_alive() -> void:
	var hero := HeroData.new(0, "Test", Enums.HeroType.GENERAL, 0)
	hero.age = 30
	hero.lifespan = 60
	assert_true(hero.is_alive())

	hero.age = 60
	assert_false(hero.is_alive())


func test_lifespan_in_range() -> void:
	# Lifespan is randomly assigned in constructor
	for i in 50:
		var hero := HeroData.new(0, "Test", Enums.HeroType.GENERAL, 0)
		assert_true(hero.lifespan >= Constants.HERO_LIFESPAN_MIN,
			"Lifespan %d should be >= min" % hero.lifespan)
		assert_true(hero.lifespan <= Constants.HERO_LIFESPAN_MAX,
			"Lifespan %d should be <= max" % hero.lifespan)
