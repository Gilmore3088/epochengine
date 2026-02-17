extends GutTest

## Tests for GovernanceSimulation (core/simulation/governance.gd)


func _make_civ(
	stability: float = 50.0,
	region_count: int = 3,
) -> CivilizationData:
	var civ := CivilizationData.new(0, "TestCiv", Color.RED)
	civ.stability = stability
	civ.capital_region_id = 0
	return civ


# --- Default Tier ---

func test_tribal_default() -> void:
	var civ := _make_civ()
	assert_eq(civ.governance_tier, Enums.GovernanceTier.TRIBAL,
		"New civ should start as TRIBAL")


func test_governance_years_default() -> void:
	var civ := _make_civ()
	assert_eq(civ.governance_years, 0,
		"New civ should start with 0 governance years")


# --- Promotions ---

func test_promotion_to_chiefdom() -> void:
	var civ := _make_civ(40.0)
	var result := GovernanceSimulation.evaluate_governance(civ, 6)
	assert_true(result["tier_changed"], "Should promote with 6 regions and stability 40")
	assert_eq(civ.governance_tier, Enums.GovernanceTier.CHIEFDOM)


func test_promotion_to_city_state() -> void:
	var civ := _make_civ(45.0)
	var result := GovernanceSimulation.evaluate_governance(civ, 10)
	assert_true(result["tier_changed"], "Should promote with 10 regions and stability 45")
	assert_eq(civ.governance_tier, Enums.GovernanceTier.CITY_STATE)


func test_promotion_to_kingdom() -> void:
	var civ := _make_civ(50.0)
	var result := GovernanceSimulation.evaluate_governance(civ, 15)
	assert_true(result["tier_changed"], "Should promote with 15 regions and stability 50")
	assert_eq(civ.governance_tier, Enums.GovernanceTier.KINGDOM)


func test_promotion_to_empire() -> void:
	var civ := _make_civ(55.0)
	var result := GovernanceSimulation.evaluate_governance(civ, 20)
	assert_true(result["tier_changed"], "Should promote with 20 regions and stability 55")
	assert_eq(civ.governance_tier, Enums.GovernanceTier.EMPIRE)


func test_promotion_to_federation() -> void:
	var civ := _make_civ(60.0)
	var result := GovernanceSimulation.evaluate_governance(civ, 30)
	assert_true(result["tier_changed"], "Should promote with 30 regions and stability 60")
	assert_eq(civ.governance_tier, Enums.GovernanceTier.FEDERATION)


func test_no_promotion_insufficient_stability() -> void:
	var civ := _make_civ(30.0)  # Below 35 needed for CHIEFDOM
	var result := GovernanceSimulation.evaluate_governance(civ, 8)
	assert_false(result["tier_changed"], "Should NOT promote with low stability")
	assert_eq(civ.governance_tier, Enums.GovernanceTier.TRIBAL)


func test_no_promotion_insufficient_regions() -> void:
	var civ := _make_civ(60.0)
	var result := GovernanceSimulation.evaluate_governance(civ, 4)  # Below 6 for CHIEFDOM
	assert_false(result["tier_changed"], "Should NOT promote with too few regions")
	assert_eq(civ.governance_tier, Enums.GovernanceTier.TRIBAL)


# --- Demotion Hysteresis ---

func test_demotion_hysteresis_no_instant_drop() -> void:
	var civ := _make_civ(50.0)
	civ.governance_tier = Enums.GovernanceTier.KINGDOM
	civ.governance_years = 0

	# Drop to 4 regions (below KINGDOM threshold of 13)
	var result := GovernanceSimulation.evaluate_governance(civ, 4)
	assert_false(result["tier_changed"], "Should NOT instantly demote")
	assert_eq(civ.governance_tier, Enums.GovernanceTier.KINGDOM,
		"Should remain KINGDOM during hysteresis")


func test_demotion_after_hysteresis() -> void:
	var civ := _make_civ(50.0)
	civ.governance_tier = Enums.GovernanceTier.KINGDOM
	civ.governance_years = 0

	# Simulate 5 years below threshold
	for i in Constants.GOVERNANCE_DEMOTION_HYSTERESIS_YEARS - 1:
		GovernanceSimulation.evaluate_governance(civ, 4)
	assert_eq(civ.governance_tier, Enums.GovernanceTier.KINGDOM,
		"Should still be KINGDOM before hysteresis expires")

	# The 5th evaluation should trigger demotion
	var result := GovernanceSimulation.evaluate_governance(civ, 4)
	assert_true(result["tier_changed"], "Should demote after hysteresis period")
	assert_eq(civ.governance_tier, Enums.GovernanceTier.TRIBAL,
		"Should demote to tier matching region count")


# --- Admin Bonus ---

func test_admin_bonus_tribal() -> void:
	assert_eq(GovernanceSimulation.get_admin_bonus(Enums.GovernanceTier.TRIBAL), 0)


func test_admin_bonus_kingdom() -> void:
	assert_eq(GovernanceSimulation.get_admin_bonus(Enums.GovernanceTier.KINGDOM), 7)


func test_admin_bonus_federation() -> void:
	assert_eq(GovernanceSimulation.get_admin_bonus(Enums.GovernanceTier.FEDERATION), 18)


# --- Expansion Friction Mod ---

func test_expansion_friction_tribal() -> void:
	assert_almost_eq(
		GovernanceSimulation.get_expansion_friction_mod(Enums.GovernanceTier.TRIBAL),
		1.0, 0.001)


func test_expansion_friction_federation() -> void:
	assert_almost_eq(
		GovernanceSimulation.get_expansion_friction_mod(Enums.GovernanceTier.FEDERATION),
		0.6, 0.001)


# --- Tier Names ---

func test_tier_name_tribal() -> void:
	assert_eq(GovernanceSimulation.get_tier_name(Enums.GovernanceTier.TRIBAL), "Tribal")


func test_tier_name_city_state() -> void:
	assert_eq(GovernanceSimulation.get_tier_name(Enums.GovernanceTier.CITY_STATE), "City-State")


# --- Multi-Step Promotion ---

func test_skip_tiers_on_rapid_growth() -> void:
	var civ := _make_civ(55.0)
	# Jump straight from TRIBAL to EMPIRE with 20 regions
	var result := GovernanceSimulation.evaluate_governance(civ, 20)
	assert_true(result["tier_changed"])
	assert_eq(civ.governance_tier, Enums.GovernanceTier.EMPIRE,
		"Should skip intermediate tiers on rapid growth")
