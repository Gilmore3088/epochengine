extends GutTest

## Tests for DevelopmentTierSimulation (core/simulation/development_tier.gd)
## and TechEmergence.compute_era (core/simulation/tech_emergence.gd)


func _make_civ(
	stability: float = 50.0,
	governance_tier: int = 0,
	era: int = 0,
	tech_count: int = 0,
) -> CivilizationData:
	var civ := CivilizationData.new(0, "TestCiv", Color.RED)
	civ.stability = stability
	civ.governance_tier = governance_tier
	civ.current_era = era
	for i in tech_count:
		civ.technologies.append("tech_%d" % i)
	return civ


func _make_region(
	terrain: Enums.TerrainType = Enums.TerrainType.PLAINS,
	infra: int = 0,
	pop: int = 0,
	size_factor: float = 1.0,
	dev_tier: int = 0,
) -> RegionData:
	var region := RegionData.new(0, "TestRegion", terrain)
	region.infrastructure_level = infra
	region.population = pop
	region.size_factor = size_factor
	region.development_tier = dev_tier
	return region


# --- Era System ---

func test_era_prehistoric_default() -> void:
	assert_eq(TechEmergence.compute_era(0), Enums.Epoch.PREHISTORIC,
		"0 techs should be PREHISTORIC")
	assert_eq(TechEmergence.compute_era(2), Enums.Epoch.PREHISTORIC,
		"2 techs should be PREHISTORIC")


func test_era_classical_at_3_techs() -> void:
	assert_eq(TechEmergence.compute_era(3), Enums.Epoch.CLASSICAL,
		"3 techs should be CLASSICAL")
	assert_eq(TechEmergence.compute_era(5), Enums.Epoch.CLASSICAL,
		"5 techs should be CLASSICAL")


func test_era_industrial_at_6_techs() -> void:
	assert_eq(TechEmergence.compute_era(6), Enums.Epoch.INDUSTRIAL,
		"6 techs should be INDUSTRIAL")
	assert_eq(TechEmergence.compute_era(8), Enums.Epoch.INDUSTRIAL,
		"8 techs should be INDUSTRIAL")


func test_era_future_at_9_techs() -> void:
	assert_eq(TechEmergence.compute_era(9), Enums.Epoch.FUTURE,
		"9 techs should be FUTURE")
	assert_eq(TechEmergence.compute_era(10), Enums.Epoch.FUTURE,
		"10 techs should be FUTURE")


# --- Development Tier Defaults ---

func test_wild_tier_default() -> void:
	var region := _make_region()
	assert_eq(region.development_tier, 0, "New region should start at tier 0 (Wild)")
	assert_eq(region.demotion_years, 0, "New region should have 0 demotion years")


# --- Promotion Tests ---

func test_promotion_to_rural() -> void:
	# Plains capacity = 10000, pop 1200 = density 0.12 > 0.10 threshold
	var region := _make_region(Enums.TerrainType.PLAINS, 0, 1200)
	var civ := _make_civ(50.0)
	var result := DevelopmentTierSimulation.evaluate_development(region, civ)
	assert_true(result["tier_changed"], "Should promote to Rural Settlement")
	assert_eq(region.development_tier, 1)


func test_promotion_to_structured() -> void:
	# Plains capacity = 10000, pop 3000 = density 0.30 > 0.25, infra 2, governance 1
	var region := _make_region(Enums.TerrainType.PLAINS, 2, 3000)
	region.development_tier = 1
	var civ := _make_civ(50.0, Enums.GovernanceTier.CHIEFDOM)
	var result := DevelopmentTierSimulation.evaluate_development(region, civ)
	assert_true(result["tier_changed"], "Should promote to Structured Agriculture")
	assert_eq(region.development_tier, 2)


func test_promotion_to_urbanized() -> void:
	# Plains capacity = 10000, pop 5000 = density 0.50 > 0.45, infra 3, gov 2, era 1
	var region := _make_region(Enums.TerrainType.PLAINS, 3, 5000)
	region.development_tier = 2
	var civ := _make_civ(50.0, Enums.GovernanceTier.CITY_STATE, Enums.Epoch.CLASSICAL)
	civ.resource_stockpiles = {Enums.ResourceType.METALS: 10}  # tier 3 gate
	var result := DevelopmentTierSimulation.evaluate_development(region, civ)
	assert_true(result["tier_changed"], "Should promote to Urbanized")
	assert_eq(region.development_tier, 3)


func test_promotion_to_industrialized() -> void:
	# Plains capacity = 10000, pop 7000 = density 0.70 > 0.65, infra 4, gov 3, era 2
	var region := _make_region(Enums.TerrainType.PLAINS, 4, 7000)
	region.development_tier = 3
	var civ := _make_civ(50.0, Enums.GovernanceTier.KINGDOM, Enums.Epoch.INDUSTRIAL)
	civ.resource_stockpiles = {
		Enums.ResourceType.METALS: 10,
		Enums.ResourceType.MANUFACTURED: 10,  # tier 4 gate
	}
	var result := DevelopmentTierSimulation.evaluate_development(region, civ)
	assert_true(result["tier_changed"], "Should promote to Industrialized")
	assert_eq(region.development_tier, 4)


func test_promotion_to_advanced() -> void:
	# Plains capacity = 10000, pop 8500 = density 0.85 > 0.80, infra 5, gov 4, era 3
	var region := _make_region(Enums.TerrainType.PLAINS, 5, 8500)
	region.development_tier = 4
	var civ := _make_civ(55.0, Enums.GovernanceTier.EMPIRE, Enums.Epoch.FUTURE)
	civ.resource_stockpiles = {
		Enums.ResourceType.METALS: 10,
		Enums.ResourceType.MANUFACTURED: 10,
		Enums.ResourceType.DATA: 10,  # tier 5 gate
	}
	var result := DevelopmentTierSimulation.evaluate_development(region, civ)
	assert_true(result["tier_changed"], "Should promote to Advanced")
	assert_eq(region.development_tier, 5)


# --- Blocking Conditions ---

func test_no_promotion_low_infra() -> void:
	# Has population but lacks infrastructure
	var region := _make_region(Enums.TerrainType.PLAINS, 1, 5000)
	region.development_tier = 1
	var civ := _make_civ(50.0, Enums.GovernanceTier.CHIEFDOM)
	var result := DevelopmentTierSimulation.evaluate_development(region, civ)
	assert_false(result["tier_changed"], "Insufficient infra should block promotion")
	assert_eq(region.development_tier, 1)


func test_no_promotion_low_pop() -> void:
	# Has infrastructure but low population density
	var region := _make_region(Enums.TerrainType.PLAINS, 2, 500)
	region.development_tier = 1
	var civ := _make_civ(50.0, Enums.GovernanceTier.CHIEFDOM)
	var result := DevelopmentTierSimulation.evaluate_development(region, civ)
	assert_false(result["tier_changed"], "Insufficient pop density should block promotion")
	assert_eq(region.development_tier, 1)


func test_no_promotion_epoch_cap() -> void:
	# Prehistoric civ cannot reach tier 3 (Urbanized requires Classical era)
	var region := _make_region(Enums.TerrainType.PLAINS, 3, 5000)
	region.development_tier = 2
	var civ := _make_civ(50.0, Enums.GovernanceTier.CITY_STATE, Enums.Epoch.PREHISTORIC)
	var result := DevelopmentTierSimulation.evaluate_development(region, civ)
	assert_false(result["tier_changed"], "Prehistoric civ should not promote past tier 2")
	assert_eq(region.development_tier, 2)


# --- Demotion / Hysteresis ---

func test_demotion_hysteresis() -> void:
	# Region at tier 2 but stability drops below threshold -- should NOT instant demote
	var region := _make_region(Enums.TerrainType.PLAINS, 2, 3000)
	region.development_tier = 2
	var civ := _make_civ(20.0, Enums.GovernanceTier.CHIEFDOM)  # stability 20 < 30 required for tier 2
	var result := DevelopmentTierSimulation.evaluate_development(region, civ)
	assert_false(result["tier_changed"], "Should not instant-demote on first year below threshold")
	assert_eq(region.demotion_years, 1)


func test_demotion_after_hysteresis() -> void:
	# Region at tier 2 with hysteresis already at threshold - 1
	# Stability 28 passes tier 1 gate (25) but fails tier 2 gate (30), so target = 1
	var region := _make_region(Enums.TerrainType.PLAINS, 2, 3000)
	region.development_tier = 2
	region.demotion_years = Constants.DEV_DEMOTION_HYSTERESIS_YEARS - 1
	var civ := _make_civ(28.0, Enums.GovernanceTier.CHIEFDOM)
	var result := DevelopmentTierSimulation.evaluate_development(region, civ)
	assert_true(result["tier_changed"], "Should demote after full hysteresis period")
	assert_eq(region.development_tier, 1)
	assert_eq(region.demotion_years, 0, "Demotion years should reset after demotion")


func test_hysteresis_resets_on_recovery() -> void:
	# Region has accumulated some demotion_years but meets threshold again
	var region := _make_region(Enums.TerrainType.PLAINS, 2, 3000)
	region.development_tier = 2
	region.demotion_years = 2
	var civ := _make_civ(50.0, Enums.GovernanceTier.CHIEFDOM)
	var result := DevelopmentTierSimulation.evaluate_development(region, civ)
	assert_false(result["tier_changed"])
	assert_eq(region.demotion_years, 0, "Demotion years should reset when conditions are met again")


# --- Terrain Capacity ---

func test_population_density_terrain_river() -> void:
	# River basin: capacity 12000. Pop 1200 -> density 0.10
	var region := _make_region(Enums.TerrainType.RIVER_BASIN, 0, 1200)
	var civ := _make_civ(50.0)
	var result := DevelopmentTierSimulation.evaluate_development(region, civ)
	assert_true(result["tier_changed"], "River basin with 1200 pop should reach Rural")
	assert_eq(region.development_tier, 1)


func test_population_density_terrain_desert() -> void:
	# Desert: capacity 3000. Pop 300 -> density 0.10 -> should promote to Rural
	var region := _make_region(Enums.TerrainType.DESERT, 0, 300)
	var civ := _make_civ(50.0)
	var result := DevelopmentTierSimulation.evaluate_development(region, civ)
	assert_true(result["tier_changed"], "Desert with 300 pop should reach Rural (lower capacity)")
	assert_eq(region.development_tier, 1)


func test_population_density_terrain_desert_insufficient() -> void:
	# Desert: capacity 3000. Pop 200 -> density 0.067 < 0.10
	var region := _make_region(Enums.TerrainType.DESERT, 0, 200)
	var civ := _make_civ(50.0)
	var result := DevelopmentTierSimulation.evaluate_development(region, civ)
	assert_false(result["tier_changed"], "Desert with 200 pop should NOT reach Rural")
	assert_eq(region.development_tier, 0)


# --- Economy Multiplier ---

func test_tier_economy_multiplier_wild() -> void:
	assert_eq(DevelopmentTierSimulation.get_economy_multiplier(0), 1.0,
		"Wild tier should give 1.0x economy")


func test_tier_economy_multiplier_urbanized() -> void:
	assert_almost_eq(DevelopmentTierSimulation.get_economy_multiplier(3), 1.45, 0.001,
		"Urbanized tier should give 1.45x economy")


func test_tier_economy_multiplier_advanced() -> void:
	assert_almost_eq(DevelopmentTierSimulation.get_economy_multiplier(5), 1.60, 0.001,
		"Advanced tier should give 1.60x economy")


# --- Defense Bonus ---

func test_tier_defense_bonus_wild() -> void:
	assert_eq(DevelopmentTierSimulation.get_defense_bonus(0), 0.0,
		"Wild tier should give no defense bonus")


func test_tier_defense_bonus_industrialized() -> void:
	assert_almost_eq(DevelopmentTierSimulation.get_defense_bonus(4), 0.15, 0.001,
		"Industrialized tier should give +0.15 defense")


# --- Admin Bonus ---

func test_tier_admin_bonus() -> void:
	assert_eq(DevelopmentTierSimulation.get_admin_bonus(0), 0)
	assert_eq(DevelopmentTierSimulation.get_admin_bonus(2), 1)
	assert_eq(DevelopmentTierSimulation.get_admin_bonus(3), 2)
	assert_eq(DevelopmentTierSimulation.get_admin_bonus(5), 4)


# --- Tier Names ---

func test_tier_names() -> void:
	assert_eq(DevelopmentTierSimulation.get_tier_name(0), "Wild")
	assert_eq(DevelopmentTierSimulation.get_tier_name(1), "Rural Settlement")
	assert_eq(DevelopmentTierSimulation.get_tier_name(2), "Structured Agriculture")
	assert_eq(DevelopmentTierSimulation.get_tier_name(3), "Urbanized")
	assert_eq(DevelopmentTierSimulation.get_tier_name(4), "Industrialized")
	assert_eq(DevelopmentTierSimulation.get_tier_name(5), "Advanced")


# --- Urbanization Level ---

func test_urbanization_level_updated_on_promotion() -> void:
	var region := _make_region(Enums.TerrainType.PLAINS, 3, 5000)
	region.development_tier = 2
	var civ := _make_civ(50.0, Enums.GovernanceTier.CITY_STATE, Enums.Epoch.CLASSICAL)
	civ.resource_stockpiles = {Enums.ResourceType.METALS: 10}  # tier 3 gate
	DevelopmentTierSimulation.evaluate_development(region, civ)
	assert_almost_eq(region.urbanization_level, 3.0 / 5.0, 0.001,
		"Urbanization level should be tier/5.0 after promotion")


# --- Tier Progress (Almost There) ---

func test_tier_progress_returns_gates() -> void:
	# Tier 0 region: next tier is 1, which needs pop_density >= 0.10, stability >= 25
	var region := _make_region(Enums.TerrainType.PLAINS, 0, 500)  # density 0.05
	var civ := _make_civ(30.0)
	var result := DevelopmentTierSimulation.get_tier_progress(region, civ)
	assert_eq(result["next_tier"], 1)
	assert_true(result["gates"].has("infra"))
	assert_true(result["gates"].has("pop_density"))
	assert_true(result["gates"].has("stability"))
	assert_true(result["gates"].has("governance"))
	assert_true(result["gates"].has("era"))
	# Infra gate: need 0 (tier 1 needs 0), have 0 → met
	assert_true(result["gates"]["infra"]["met"], "Infra gate should be met (need 0)")
	# Pop density: 500/10000 = 0.05 < 0.10 → not met
	assert_false(result["gates"]["pop_density"]["met"], "Pop density 0.05 < 0.10 should not be met")
	# Stability: 30 >= 25 → met
	assert_true(result["gates"]["stability"]["met"], "Stability 30 >= 25 should be met")
	# Not all met (pop density fails)
	assert_false(result["all_met"])


func test_tier_progress_all_met() -> void:
	# Plains capacity 10000. Pop 1200 -> density 0.12 >= 0.10
	var region := _make_region(Enums.TerrainType.PLAINS, 0, 1200)
	var civ := _make_civ(50.0)
	var result := DevelopmentTierSimulation.get_tier_progress(region, civ)
	assert_eq(result["next_tier"], 1)
	assert_true(result["all_met"], "All gates for tier 1 should be met")
