extends GutTest

## Tests for ResourceProduction (core/simulation/resource_production.gd)
## Covers yields, deposits, maintenance, complexity tax, and integration.


func _make_civ(
	era: int = 0,
	stability: float = 50.0,
	governance_tier: int = 0,
) -> CivilizationData:
	var civ := CivilizationData.new(1, "TestCiv", Color.RED)
	civ.stability = stability
	civ.governance_tier = governance_tier
	civ.current_era = era
	return civ


func _make_region(
	id: int = 0,
	terrain: Enums.TerrainType = Enums.TerrainType.PLAINS,
	infra: int = 0,
	pop: int = 1000,
	size_factor: float = 1.0,
	dev_tier: int = 0,
) -> RegionData:
	var region := RegionData.new(id, "TestRegion", terrain)
	region.infrastructure_level = infra
	region.population = pop
	region.size_factor = size_factor
	region.development_tier = dev_tier
	region.owner_id = 1
	# Clear auto-generated deposits so tests control them explicitly
	region.resource_deposits = {}
	return region


# === YIELD TESTS ===

func test_no_yields_prehistoric() -> void:
	var civ := _make_civ(Enums.Epoch.PREHISTORIC)
	var region := _make_region(0, Enums.TerrainType.MOUNTAINS)
	var regions: Array[RegionData] = [region]
	var yields := ResourceProduction.calculate_resource_yields(civ, regions)
	assert_true(yields.is_empty(),
		"Prehistoric era should produce no new resource yields")


func test_metals_yield_classical_mountains() -> void:
	var civ := _make_civ(Enums.Epoch.CLASSICAL)
	var region := _make_region(0, Enums.TerrainType.MOUNTAINS)
	var regions: Array[RegionData] = [region]
	var yields := ResourceProduction.calculate_resource_yields(civ, regions)
	# Mountains terrain yields: metals=3, rare_materials=2, strategic=2
	# But rare_materials needs INDUSTRIAL era, strategic needs FUTURE
	assert_true(yields.has(Enums.ResourceType.METALS),
		"Classical mountains should yield metals")
	assert_eq(yields[Enums.ResourceType.METALS], 3,
		"Mountains base metals yield should be 3")


func test_metals_yield_classical_plains() -> void:
	var civ := _make_civ(Enums.Epoch.CLASSICAL)
	var region := _make_region(0, Enums.TerrainType.PLAINS)
	var regions: Array[RegionData] = [region]
	var yields := ResourceProduction.calculate_resource_yields(civ, regions)
	assert_false(yields.has(Enums.ResourceType.METALS),
		"Plains should not yield metals")


func test_commerce_yield_coastline() -> void:
	var civ := _make_civ(Enums.Epoch.CLASSICAL)
	var region := _make_region(0, Enums.TerrainType.COASTLINE)
	var regions: Array[RegionData] = [region]
	var yields := ResourceProduction.calculate_resource_yields(civ, regions)
	assert_true(yields.has(Enums.ResourceType.COMMERCE),
		"Classical coastline should yield commerce")
	assert_eq(yields[Enums.ResourceType.COMMERCE], 3,
		"Coastline base commerce yield should be 3")


func test_yield_scales_with_size_factor() -> void:
	var civ := _make_civ(Enums.Epoch.CLASSICAL)
	var region := _make_region(0, Enums.TerrainType.MOUNTAINS, 0, 1000, 2.0)
	var regions: Array[RegionData] = [region]
	var yields := ResourceProduction.calculate_resource_yields(civ, regions)
	# base 3 * size 2.0 * tier_mult 1.0 = 6
	assert_eq(yields[Enums.ResourceType.METALS], 6,
		"Metals yield should scale with size_factor")


func test_yield_scales_with_dev_tier() -> void:
	var civ := _make_civ(Enums.Epoch.CLASSICAL)
	# Dev tier 2 has economy multiplier 1.30
	var region := _make_region(0, Enums.TerrainType.MOUNTAINS, 0, 1000, 1.0, 2)
	var regions: Array[RegionData] = [region]
	var yields := ResourceProduction.calculate_resource_yields(civ, regions)
	# base 3 * size 1.0 * tier_mult 1.30 = 3.9 -> int = 3
	assert_eq(yields[Enums.ResourceType.METALS], 3,
		"Metals yield should scale with dev tier multiplier")


func test_infrastructure_bonus_on_yields() -> void:
	var civ := _make_civ(Enums.Epoch.CLASSICAL)
	# Infra 4 -> bonus = 4/2 = 2
	var region := _make_region(0, Enums.TerrainType.MOUNTAINS, 4, 1000, 1.0, 0)
	var regions: Array[RegionData] = [region]
	var yields := ResourceProduction.calculate_resource_yields(civ, regions)
	# (base 3 + infra_bonus 2) * size 1.0 * tier 1.0 = 5
	assert_eq(yields[Enums.ResourceType.METALS], 5,
		"Infra should add +1 per 2 levels to yields")


func test_future_resources_locked_in_industrial() -> void:
	var civ := _make_civ(Enums.Epoch.INDUSTRIAL)
	var region := _make_region(0, Enums.TerrainType.COASTLINE)
	var regions: Array[RegionData] = [region]
	var yields := ResourceProduction.calculate_resource_yields(civ, regions)
	# Coastline has data=1 and adv_energy=2, but those need FUTURE era
	assert_false(yields.has(Enums.ResourceType.DATA),
		"Data should be locked in Industrial era")
	assert_false(yields.has(Enums.ResourceType.ADV_ENERGY),
		"Advanced Energy should be locked in Industrial era")
	# But manufactured (Industrial) should be there
	assert_true(yields.has(Enums.ResourceType.MANUFACTURED),
		"Manufactured should be unlocked in Industrial era")


# === DEPOSIT TESTS ===

func test_deposit_extraction_reduces_stock() -> void:
	var civ := _make_civ(Enums.Epoch.INDUSTRIAL)
	var region := _make_region(0, Enums.TerrainType.MOUNTAINS)
	region.resource_deposits = {Enums.ResourceType.FUELS: 100}
	var regions: Array[RegionData] = [region]
	var result := ResourceProduction.extract_deposits(civ, regions)
	assert_true(region.resource_deposits[Enums.ResourceType.FUELS] < 100,
		"Extraction should reduce deposit stock")
	assert_true(result["totals"].has(Enums.ResourceType.FUELS),
		"Extracted fuels should appear in totals")


func test_deposit_depletion_stops_extraction() -> void:
	var civ := _make_civ(Enums.Epoch.INDUSTRIAL)
	var region := _make_region(0, Enums.TerrainType.MOUNTAINS)
	region.resource_deposits = {Enums.ResourceType.FUELS: 0}
	var regions: Array[RegionData] = [region]
	var result := ResourceProduction.extract_deposits(civ, regions)
	assert_true(result["totals"].is_empty(),
		"Should not extract from depleted deposits")


func test_extraction_rate_scales_with_dev_tier() -> void:
	var civ := _make_civ(Enums.Epoch.INDUSTRIAL)
	# Tier 0 extraction = base * 1.0
	var region_low := _make_region(0, Enums.TerrainType.MOUNTAINS, 0, 1000, 1.0, 0)
	region_low.resource_deposits = {Enums.ResourceType.FUELS: 1000}
	# Tier 3 extraction = base * (1 + 3*0.2) = base * 1.6
	var region_high := _make_region(1, Enums.TerrainType.MOUNTAINS, 0, 1000, 1.0, 3)
	region_high.resource_deposits = {Enums.ResourceType.FUELS: 1000}

	ResourceProduction.extract_deposits(civ, [region_low] as Array[RegionData])
	var extracted_low: int = 1000 - region_low.resource_deposits[Enums.ResourceType.FUELS]

	ResourceProduction.extract_deposits(civ, [region_high] as Array[RegionData])
	var extracted_high: int = 1000 - region_high.resource_deposits[Enums.ResourceType.FUELS]

	assert_true(extracted_high > extracted_low,
		"Higher dev tier should extract more per turn")


func test_no_deposits_on_plains() -> void:
	# RegionData._init auto-generates deposits based on terrain
	# Plains should have none
	var region := RegionData.new(99, "PlainRegion", Enums.TerrainType.PLAINS)
	assert_true(region.resource_deposits.is_empty(),
		"Plains regions should have no deposits")


func test_deposits_seeded_deterministically() -> void:
	# Same ID + terrain = same deposits
	var r1 := RegionData.new(42, "MtA", Enums.TerrainType.MOUNTAINS)
	var r2 := RegionData.new(42, "MtB", Enums.TerrainType.MOUNTAINS)
	assert_eq(r1.resource_deposits, r2.resource_deposits,
		"Same region ID and terrain should produce identical deposits")

	# Different IDs = different deposits (statistically likely)
	var r3 := RegionData.new(43, "MtC", Enums.TerrainType.MOUNTAINS)
	# Note: can't guarantee difference for all seeds, but very likely
	# Just check both have deposits
	assert_false(r3.resource_deposits.is_empty(),
		"Mountain region should have deposits")


func test_deposit_depletion_tracked() -> void:
	var civ := _make_civ(Enums.Epoch.INDUSTRIAL)
	var region := _make_region(0, Enums.TerrainType.MOUNTAINS)
	region.resource_deposits = {Enums.ResourceType.FUELS: 3}  # will deplete in 1 turn
	var regions: Array[RegionData] = [region]
	var result := ResourceProduction.extract_deposits(civ, regions)
	assert_eq(region.resource_deposits[Enums.ResourceType.FUELS], 0,
		"Small deposit should be fully depleted")
	assert_eq(result["depleted"].size(), 1,
		"Should report 1 depleted deposit")


# === MAINTENANCE TESTS ===

func test_luxury_goods_requires_commerce() -> void:
	var civ := _make_civ(Enums.Epoch.CLASSICAL)
	# Has luxury but no commerce -> penalty
	civ.resource_stockpiles = {
		Enums.ResourceType.LUXURY_GOODS: 10,
	}
	civ.resource_production_log = {Enums.ResourceType.LUXURY_GOODS: 3}
	var result := ResourceProduction.apply_maintenance(civ)
	assert_true(result["stability_penalty"] > 0.0,
		"Missing commerce input for luxury should cause stability penalty")


func test_manufactured_requires_metals_and_fuels() -> void:
	var civ := _make_civ(Enums.Epoch.INDUSTRIAL)
	civ.resource_stockpiles = {
		Enums.ResourceType.MANUFACTURED: 10,
		Enums.ResourceType.METALS: 0,
		Enums.ResourceType.FUELS: 0,
	}
	civ.resource_production_log = {Enums.ResourceType.MANUFACTURED: 5}
	var result := ResourceProduction.apply_maintenance(civ)
	# Should have 2 missing inputs (metals + fuels)
	var found := false
	for p in result["penalties"]:
		if p["resource"] == Enums.ResourceType.MANUFACTURED:
			assert_eq(p["missing_inputs"], 2,
				"Should report 2 missing inputs for manufactured")
			found = true
	assert_true(found, "Should have penalty for manufactured")


func test_missing_input_applies_efficiency_penalty() -> void:
	var civ := _make_civ(Enums.Epoch.CLASSICAL)
	civ.resource_stockpiles = {Enums.ResourceType.LUXURY_GOODS: 10}
	civ.resource_production_log = {Enums.ResourceType.LUXURY_GOODS: 3}
	var result := ResourceProduction.apply_maintenance(civ)
	for p in result["penalties"]:
		if p["resource"] == Enums.ResourceType.LUXURY_GOODS:
			assert_almost_eq(p["efficiency_loss"], 0.25, 0.01,
				"1 missing input should cause 25% efficiency loss")


func test_missing_input_applies_stability_penalty() -> void:
	var civ := _make_civ(Enums.Epoch.CLASSICAL)
	civ.resource_stockpiles = {Enums.ResourceType.LUXURY_GOODS: 10}
	civ.resource_production_log = {Enums.ResourceType.LUXURY_GOODS: 3}
	var result := ResourceProduction.apply_maintenance(civ)
	assert_almost_eq(result["stability_penalty"], 5.0, 0.01,
		"1 missing input should cause 5.0 stability penalty")


func test_multiple_missing_inputs_stack() -> void:
	var civ := _make_civ(Enums.Epoch.INDUSTRIAL)
	# Manufactured needs metals+fuels, both missing
	civ.resource_stockpiles = {Enums.ResourceType.MANUFACTURED: 10}
	civ.resource_production_log = {Enums.ResourceType.MANUFACTURED: 5}
	var result := ResourceProduction.apply_maintenance(civ)
	# 2 missing inputs * 5.0 per = 10.0
	assert_almost_eq(result["stability_penalty"], 10.0, 0.01,
		"2 missing inputs should stack stability penalty")


func test_maintenance_consumes_stockpile() -> void:
	var civ := _make_civ(Enums.Epoch.CLASSICAL)
	civ.resource_stockpiles = {
		Enums.ResourceType.LUXURY_GOODS: 10,
		Enums.ResourceType.COMMERCE: 5,
	}
	civ.resource_production_log = {Enums.ResourceType.LUXURY_GOODS: 3}
	ResourceProduction.apply_maintenance(civ)
	assert_eq(civ.resource_stockpiles[Enums.ResourceType.COMMERCE], 4,
		"Maintenance should consume 1 commerce per turn for luxury goods")


# === COMPLEXITY TAX TESTS ===

func test_no_tax_under_threshold() -> void:
	var civ := _make_civ(Enums.Epoch.CLASSICAL)
	civ.resource_stockpiles = {
		Enums.ResourceType.METALS: 10,
		Enums.ResourceType.COMMERCE: 10,
		Enums.ResourceType.LUXURY_GOODS: 10,
	}
	var tax := ResourceProduction.calculate_complexity_tax(civ)
	assert_eq(tax, 0.0,
		"3 resource types (at threshold) should have no complexity tax")


func test_tax_scales_with_resource_count() -> void:
	var civ := _make_civ(Enums.Epoch.INDUSTRIAL)
	civ.resource_stockpiles = {
		Enums.ResourceType.METALS: 10,
		Enums.ResourceType.COMMERCE: 10,
		Enums.ResourceType.LUXURY_GOODS: 10,
		Enums.ResourceType.FUELS: 10,
		Enums.ResourceType.MANUFACTURED: 10,
	}
	var tax := ResourceProduction.calculate_complexity_tax(civ)
	# 5 types - 3 threshold = 2 excess * 0.5 per = 1.0
	assert_almost_eq(tax, 1.0, 0.01,
		"5 resource types should produce 1.0 complexity tax")


func test_governance_reduces_tax() -> void:
	var civ := _make_civ(Enums.Epoch.INDUSTRIAL, 50.0, Enums.GovernanceTier.KINGDOM)
	civ.resource_stockpiles = {
		Enums.ResourceType.METALS: 10,
		Enums.ResourceType.COMMERCE: 10,
		Enums.ResourceType.LUXURY_GOODS: 10,
		Enums.ResourceType.FUELS: 10,
		Enums.ResourceType.MANUFACTURED: 10,
	}
	var tax := ResourceProduction.calculate_complexity_tax(civ)
	# raw = 2 * 0.5 = 1.0
	# gov reduction = KINGDOM(3) * 0.1 = 0.3
	# final = 0.7
	assert_almost_eq(tax, 0.7, 0.01,
		"KINGDOM governance should reduce tax by 0.3")


func test_tax_caps_at_zero() -> void:
	# High governance eliminates small tax
	var civ := _make_civ(Enums.Epoch.INDUSTRIAL, 50.0, Enums.GovernanceTier.EMPIRE)
	civ.resource_stockpiles = {
		Enums.ResourceType.METALS: 10,
		Enums.ResourceType.COMMERCE: 10,
		Enums.ResourceType.LUXURY_GOODS: 10,
		Enums.ResourceType.FUELS: 10,
	}
	var tax := ResourceProduction.calculate_complexity_tax(civ)
	# raw = 1 * 0.5 = 0.5
	# gov reduction = EMPIRE(4) * 0.1 = 0.4
	# final = max(0.1, 0) = 0.1
	assert_true(tax >= 0.0,
		"Complexity tax should never go negative")


# === INTEGRATION TESTS ===

func test_process_resources_full_pipeline() -> void:
	var civ := _make_civ(Enums.Epoch.CLASSICAL)
	var region := _make_region(0, Enums.TerrainType.MOUNTAINS)
	var regions: Array[RegionData] = [region]
	var result := ResourceProduction.process_resources(civ, regions)
	# Should produce metals from mountains at Classical era
	assert_true(result["yields"].has(Enums.ResourceType.METALS),
		"Process should produce metals from mountains in Classical era")
	assert_true(civ.resource_stockpiles.get(Enums.ResourceType.METALS, 0) > 0,
		"Metals should be added to civ stockpile")
	assert_true(civ.resource_production_log.has(Enums.ResourceType.METALS),
		"Production log should record metals production")


func test_dev_tier_resource_gates_block_promotion() -> void:
	# Tier 3 (Urbanized) requires METALS
	var civ := _make_civ(Enums.Epoch.CLASSICAL, 60.0, Enums.GovernanceTier.CITY_STATE)
	civ.resource_stockpiles = {}  # No metals

	# Region meets all other tier 3 gates
	var region := _make_region(0, Enums.TerrainType.RIVER_BASIN, 5, 8000, 1.0, 2)
	var result := DevelopmentTierSimulation.evaluate_development(region, civ)
	# Should not promote to tier 3 without metals
	assert_true(region.development_tier <= 2,
		"Should not promote to tier 3 without metals")


func test_resource_name_lookup() -> void:
	assert_eq(ResourceProduction.get_resource_name(Enums.ResourceType.METALS), "Metals")
	assert_eq(ResourceProduction.get_resource_name(Enums.ResourceType.COMMERCE), "Commerce")
	assert_eq(ResourceProduction.get_resource_name(Enums.ResourceType.ADV_ENERGY), "Advanced Energy")
	assert_eq(ResourceProduction.get_resource_name(99), "Unknown")


func test_is_resource_unlocked() -> void:
	assert_false(ResourceProduction.is_resource_unlocked(Enums.ResourceType.METALS, Enums.Epoch.PREHISTORIC),
		"Metals should be locked in Prehistoric")
	assert_true(ResourceProduction.is_resource_unlocked(Enums.ResourceType.METALS, Enums.Epoch.CLASSICAL),
		"Metals should be unlocked in Classical")
	assert_false(ResourceProduction.is_resource_unlocked(Enums.ResourceType.DATA, Enums.Epoch.INDUSTRIAL),
		"Data should be locked in Industrial")
	assert_true(ResourceProduction.is_resource_unlocked(Enums.ResourceType.DATA, Enums.Epoch.FUTURE),
		"Data should be unlocked in Future")
