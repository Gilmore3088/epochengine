extends GutTest

## Tests for EconomySimulation (core/simulation/economy.gd)


func _make_civ(
	food_stockpile: int = 100,
	production_stockpile: int = 100,
	military_strength: float = 50.0,
	total_population: int = 5000,
) -> CivilizationData:
	var civ := CivilizationData.new(0, "TestCiv", Color.RED)
	civ.food_stockpile = food_stockpile
	civ.production_stockpile = production_stockpile
	civ.military_strength = military_strength
	civ.total_population = total_population
	return civ


func _make_region(
	terrain: Enums.TerrainType = Enums.TerrainType.PLAINS,
	infra: int = 0,
) -> RegionData:
	var region := RegionData.new(0, "TestRegion", terrain)
	region.infrastructure_level = infra
	return region


# --- Food Production ---

func test_food_production_basic() -> void:
	var civ := _make_civ()
	var regions: Array[RegionData] = [_make_region(Enums.TerrainType.RIVER_BASIN)]
	# River basin yields 5 food + 0 infra = 5
	var food := EconomySimulation.calculate_food_production(civ, regions)
	assert_eq(food, 5, "River basin should produce 5 food with no infra")


func test_food_production_with_infrastructure() -> void:
	var civ := _make_civ()
	var region := _make_region(Enums.TerrainType.RIVER_BASIN)
	region.infrastructure_level = 3
	var regions: Array[RegionData] = [region]
	# River basin yields 5 + 3 infra = 8
	var food := EconomySimulation.calculate_food_production(civ, regions)
	assert_eq(food, 8, "Should add infrastructure to food yield")


func test_food_production_golden_age() -> void:
	var civ := _make_civ()
	civ.golden_age_years_remaining = 10
	var regions: Array[RegionData] = [_make_region(Enums.TerrainType.RIVER_BASIN)]
	var food := EconomySimulation.calculate_food_production(civ, regions)
	# 5 base * 1.5 golden age bonus = 7.5 -> 7 (truncated)
	assert_eq(food, 7, "Golden age should boost food by 50%")


func test_food_production_multiple_regions() -> void:
	var civ := _make_civ()
	var regions: Array[RegionData] = [
		_make_region(Enums.TerrainType.RIVER_BASIN),  # 5
		_make_region(Enums.TerrainType.PLAINS),        # 3
		_make_region(Enums.TerrainType.MOUNTAINS),     # 1
	]
	var food := EconomySimulation.calculate_food_production(civ, regions)
	assert_eq(food, 9, "Should sum food across all regions")


# --- Production Output ---

func test_production_output_basic() -> void:
	var civ := _make_civ()
	var regions: Array[RegionData] = [_make_region(Enums.TerrainType.COASTLINE)]
	# Coastline yields 4 production
	var prod := EconomySimulation.calculate_production_output(civ, regions)
	assert_eq(prod, 4, "Coastline should produce 4 production")


func test_production_visionary_hero_bonus() -> void:
	var civ := _make_civ()
	# Add a visionary hero to GameState
	var hero := HeroData.new(0, "Wise One", Enums.HeroType.VISIONARY, 0)
	GameState.heroes.clear()
	GameState.add_hero(hero)
	civ.hero_ids = [hero.id]

	var regions: Array[RegionData] = [_make_region(Enums.TerrainType.COASTLINE)]
	# 4 base * (1.0 + 0.10 visionary) = 4.4 -> 4 (truncated)
	var prod := EconomySimulation.calculate_production_output(civ, regions)
	assert_eq(prod, 4, "Visionary bonus should apply to production")

	GameState.heroes.clear()


# --- Food Consumption ---

func test_food_consumption() -> void:
	var civ := _make_civ(0, 0, 0.0, 5000)
	# 5000 / 2000 = 2
	var consumed := EconomySimulation.calculate_food_consumption(civ)
	assert_eq(consumed, 2, "Should consume 1 food per 2000 population")


func test_food_consumption_zero_pop() -> void:
	var civ := _make_civ(0, 0, 0.0, 0)
	assert_eq(EconomySimulation.calculate_food_consumption(civ), 0)


func test_food_consumption_small_pop() -> void:
	var civ := _make_civ(0, 0, 0.0, 500)
	# 500 / 2000 = 0 (integer division)
	assert_eq(EconomySimulation.calculate_food_consumption(civ), 0)


# --- Military Upkeep ---

func test_military_upkeep() -> void:
	var civ := _make_civ(0, 0, 100.0, 0)
	# 100 / 25 = 4
	assert_eq(EconomySimulation.calculate_military_upkeep(civ), 4)


func test_military_upkeep_zero() -> void:
	var civ := _make_civ(0, 0, 0.0, 0)
	assert_eq(EconomySimulation.calculate_military_upkeep(civ), 0)


# --- Process Economy ---

func test_process_economy_surplus() -> void:
	var civ := _make_civ(100, 100, 50.0, 3000)
	var regions: Array[RegionData] = [
		_make_region(Enums.TerrainType.RIVER_BASIN),  # 5 food, 3 prod
		_make_region(Enums.TerrainType.RIVER_BASIN),  # 5 food, 3 prod
	]
	var result := EconomySimulation.process_economy(civ, regions)

	# Food: 10 produced - 1 consumed (3000/2000) = +9 net
	assert_eq(result["food_produced"], 10)
	assert_eq(result["food_consumed"], 1)
	assert_eq(result["food_net"], 9)

	# Production: 6 produced - 2 upkeep (50/25) = +4 net
	assert_eq(result["prod_produced"], 6)
	assert_eq(result["military_upkeep"], 2)
	assert_eq(result["prod_net"], 4)

	# Stockpiles updated
	assert_eq(civ.food_stockpile, 109, "Food stockpile should increase by net")
	assert_eq(civ.production_stockpile, 104, "Prod stockpile should increase by net")

	# No shortage
	assert_false(result["food_shortage"])
	assert_false(result["prod_shortage"])


func test_process_economy_detects_shortage() -> void:
	var civ := _make_civ(-40, -44, 200.0, 10000)
	var regions: Array[RegionData] = [_make_region(Enums.TerrainType.TUNDRA)]  # 1 food, 1 prod

	var result := EconomySimulation.process_economy(civ, regions)

	# Food: 1 - 5 (10000/2000) = -4, stockpile: -40 + (-4) = -44 (above -50 threshold)
	# Prod: 1 - 8 (200/25) = -7, stockpile: -44 + (-7) = -51 (below -50)
	assert_false(result["food_shortage"], "Food at -44 should not trigger shortage")
	assert_true(result["prod_shortage"], "Prod at -51 should trigger shortage")


# --- Expansion Cost ---

func test_expansion_cost_below_threshold() -> void:
	var civ := _make_civ()
	# 5 regions, threshold is 10 -> no escalation
	var cost := EconomySimulation.calculate_expansion_cost(civ, 5)
	assert_eq(cost, 20, "Base cost should be 20 below threshold")


func test_expansion_cost_above_threshold() -> void:
	var civ := _make_civ()
	# 8 regions, base admin capacity is 5 -> 3 excess * 8 = 24 extra + 20 base = 44
	var cost := EconomySimulation.calculate_expansion_cost(civ, 8)
	assert_eq(cost, 44, "Cost should escalate above admin capacity base")


func test_can_afford_expansion_true() -> void:
	var civ := _make_civ(0, 50, 0.0, 1000)
	# Cost at 5 regions = 20, has 50 prod and 1000 pop >= 300
	assert_true(EconomySimulation.can_afford_expansion(civ, 5))


func test_can_afford_expansion_no_production() -> void:
	var civ := _make_civ(0, 10, 0.0, 1000)
	# Cost at 5 regions = 20, only 10 prod
	assert_false(EconomySimulation.can_afford_expansion(civ, 5))


func test_can_afford_expansion_no_population() -> void:
	var civ := _make_civ(0, 50, 0.0, 200)
	# Has prod but pop < 300
	assert_false(EconomySimulation.can_afford_expansion(civ, 5))


# --- Pay Expansion Cost ---

func test_pay_expansion_cost() -> void:
	var civ := _make_civ(0, 100, 0.0, 5000)
	var source := _make_region()
	source.population = 4000

	var cost := EconomySimulation.pay_expansion_cost(civ, 5, source)
	assert_eq(cost, 20, "Should return cost paid")
	assert_eq(civ.production_stockpile, 80, "Should deduct production cost")
	# Settlers: min(4000/4, 300) = 300
	assert_eq(source.population, 3700, "Should move 300 settlers from source")


# --- Infrastructure Upgrade ---

func test_upgrade_infrastructure_success() -> void:
	var civ := _make_civ(0, 200, 0.0, 0)
	var region := _make_region()
	region.infrastructure_level = 0
	# Cost: 15 * (0+1) = 15
	assert_true(EconomySimulation.try_upgrade_infrastructure(civ, region))
	assert_eq(region.infrastructure_level, 1)
	assert_eq(civ.production_stockpile, 185)


func test_upgrade_infrastructure_max_level() -> void:
	var civ := _make_civ(0, 200, 0.0, 0)
	var region := _make_region()
	region.infrastructure_level = 5
	assert_false(EconomySimulation.try_upgrade_infrastructure(civ, region))


func test_upgrade_infrastructure_too_expensive() -> void:
	var civ := _make_civ(0, 10, 0.0, 0)
	var region := _make_region()
	region.infrastructure_level = 3
	# Cost: 15 * (3+1) = 60, only has 10
	assert_false(EconomySimulation.try_upgrade_infrastructure(civ, region))


# --- Spending Priority ---

func test_spending_growth_boosts_food() -> void:
	var civ := _make_civ(0, 0, 50.0, 3000)
	civ.spending_priority = 1  # Growth: food 1.5
	var regions: Array[RegionData] = [
		_make_region(Enums.TerrainType.RIVER_BASIN),  # 5 food, 3 prod
	]
	var result := EconomySimulation.process_economy(civ, regions)
	# Food net: 5 - 1 (3000/2000) = 4. * 1.5 = 6.0 -> int 6
	assert_eq(civ.food_stockpile, int(4.0 * 1.5), "Growth priority should boost food accumulation")

	var civ_balanced := _make_civ(0, 0, 50.0, 3000)
	civ_balanced.spending_priority = 0  # Balanced
	EconomySimulation.process_economy(civ_balanced, regions)
	assert_true(civ.food_stockpile > civ_balanced.food_stockpile,
		"Growth food (%d) should exceed Balanced food (%d)" % [civ.food_stockpile, civ_balanced.food_stockpile])


func test_spending_production_reduces_food() -> void:
	var civ := _make_civ(0, 0, 50.0, 3000)
	civ.spending_priority = 2  # Production: food 0.85
	var regions: Array[RegionData] = [
		_make_region(Enums.TerrainType.RIVER_BASIN),  # 5 food
	]
	var result := EconomySimulation.process_economy(civ, regions)
	# Food net: 4. * 0.85 = 3.4 -> int 3
	assert_eq(civ.food_stockpile, int(4.0 * 0.85), "Production priority should reduce food")


func test_spending_cooldown_decrements() -> void:
	var civ := _make_civ(100, 100, 50.0, 3000)
	civ.spending_priority_cooldown = 3
	var regions: Array[RegionData] = [_make_region(Enums.TerrainType.PLAINS)]
	EconomySimulation.process_economy(civ, regions)
	assert_eq(civ.spending_priority_cooldown, 2, "Cooldown should decrement by 1")
