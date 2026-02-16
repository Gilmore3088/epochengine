extends GutTest

## Tests for PopulationSimulation (core/simulation/population.gd)


func _make_civ(
	stability: float = 50.0,
	food_stockpile: int = 100,
	total_population: int = 5000,
) -> CivilizationData:
	var civ := CivilizationData.new(0, "TestCiv", Color.RED)
	civ.stability = stability
	civ.food_stockpile = food_stockpile
	civ.total_population = total_population
	return civ


func _make_region(
	terrain: Enums.TerrainType = Enums.TerrainType.PLAINS,
	population: int = 1000,
) -> RegionData:
	var region := RegionData.new(0, "TestRegion", terrain)
	region.population = population
	return region


# --- Growth Rate ---

func test_population_grows_in_normal_conditions() -> void:
	var civ := _make_civ(50.0, 100, 5000)
	var region := _make_region(Enums.TerrainType.PLAINS, 1000)

	seed(42)
	var new_pop := PopulationSimulation.calculate_growth(region, civ)
	assert_true(new_pop > 1000, "Population should grow in normal conditions")


func test_river_basin_grows_fastest() -> void:
	var civ := _make_civ(50.0, 100, 5000)
	var river := _make_region(Enums.TerrainType.RIVER_BASIN, 1000)
	var tundra := _make_region(Enums.TerrainType.TUNDRA, 1000)

	seed(42)
	var pop_river := PopulationSimulation.calculate_growth(river, civ)
	seed(42)
	var pop_tundra := PopulationSimulation.calculate_growth(tundra, civ)

	assert_true(pop_river > pop_tundra,
		"River basin should have higher growth than tundra")


func test_golden_age_boosts_growth() -> void:
	var civ := _make_civ(50.0, 100, 5000)
	var region := _make_region(Enums.TerrainType.PLAINS, 1000)

	seed(42)
	var normal_pop := PopulationSimulation.calculate_growth(region, civ)

	civ.golden_age_years_remaining = 10
	region.population = 1000
	seed(42)
	var golden_pop := PopulationSimulation.calculate_growth(region, civ)

	assert_true(golden_pop > normal_pop,
		"Golden age should boost population growth")


func test_famine_reduces_growth() -> void:
	var civ_surplus := _make_civ(50.0, 500, 5000)
	var civ_famine := _make_civ(50.0, -500, 5000)
	var region := _make_region(Enums.TerrainType.PLAINS, 1000)

	seed(42)
	var pop_surplus := PopulationSimulation.calculate_growth(region, civ_surplus)

	region.population = 1000
	seed(42)
	var pop_famine := PopulationSimulation.calculate_growth(region, civ_famine)

	assert_true(pop_surplus > pop_famine,
		"Famine should reduce growth compared to surplus")


func test_low_stability_reduces_growth() -> void:
	var civ_stable := _make_civ(80.0, 100, 5000)
	var civ_unstable := _make_civ(10.0, 100, 5000)
	var region := _make_region(Enums.TerrainType.PLAINS, 1000)

	seed(42)
	var pop_stable := PopulationSimulation.calculate_growth(region, civ_stable)

	region.population = 1000
	seed(42)
	var pop_unstable := PopulationSimulation.calculate_growth(region, civ_unstable)

	assert_true(pop_stable > pop_unstable,
		"Low stability should reduce growth")


func test_population_never_negative() -> void:
	var civ := _make_civ(5.0, -1000, 100)
	var region := _make_region(Enums.TerrainType.TUNDRA, 10)

	var new_pop := PopulationSimulation.calculate_growth(region, civ)
	assert_true(new_pop >= 0, "Population should never go negative")


func test_zero_population_stays_zero() -> void:
	var civ := _make_civ(50.0, 100, 5000)
	var region := _make_region(Enums.TerrainType.PLAINS, 0)

	var new_pop := PopulationSimulation.calculate_growth(region, civ)
	assert_eq(new_pop, 0, "Zero population should stay zero")


func test_zero_total_population_food_modifier() -> void:
	# Edge case: civ has 0 total_population - should not divide by zero
	var civ := _make_civ(50.0, 100, 0)
	var region := _make_region(Enums.TerrainType.PLAINS, 100)

	# Should not crash
	var new_pop := PopulationSimulation.calculate_growth(region, civ)
	assert_true(new_pop >= 0, "Should handle zero total population gracefully")
