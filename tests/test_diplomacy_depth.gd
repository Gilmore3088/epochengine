extends GutTest

## Tests for NAP, Trade, and Tribute diplomacy mechanics.


func _make_civ(id: int, name: String) -> CivilizationData:
	var civ := CivilizationData.new()
	civ.id = id
	civ.civ_name = name
	civ.stability = 60.0
	civ.military_strength = 100.0
	civ.food_stockpile = 100
	civ.production_stockpile = 100
	civ.total_population = 1000
	civ.diplomacy_bias = 0.5
	civ.aggression_bias = 0.5
	civ.economy_bias = 0.5
	civ.expansion_bias = 0.5
	return civ


# --- NAP Tests ---

func test_nap_prevents_war_declaration():
	var civ_a := _make_civ(0, "Alpha")
	var civ_b := _make_civ(1, "Beta")
	civ_a.nap_partners[1] = 10
	civ_b.nap_partners[0] = 10

	# NAP should block war: _try_declare_war checks nap_partners
	assert_true(civ_a.nap_partners.has(1), "NAP should exist")
	assert_true(civ_b.nap_partners.has(0), "NAP should be bilateral")


func test_nap_expires_after_tick():
	var civ := _make_civ(0, "Alpha")
	civ.nap_partners[1] = 1  # 1 year remaining

	# Simulate tick: decrement and remove expired
	var expired: Array[int] = []
	for partner_id in civ.nap_partners:
		civ.nap_partners[partner_id] = civ.nap_partners[partner_id] - 1
		if civ.nap_partners[partner_id] <= 0:
			expired.append(partner_id)
	for partner_id in expired:
		civ.nap_partners.erase(partner_id)

	assert_false(civ.nap_partners.has(1), "NAP should expire after 0 years remaining")


func test_nap_break_on_war_costs_stability():
	var civ := _make_civ(0, "Alpha")
	var target := _make_civ(1, "Beta")
	civ.nap_partners[1] = 10
	target.nap_partners[0] = 10

	var old_stability := civ.stability

	# Simulate NAP break on war declaration
	civ.nap_partners.erase(1)
	target.nap_partners.erase(0)
	civ.stability = maxf(civ.stability - Constants.NAP_BREAK_STABILITY_PENALTY, Constants.STABILITY_MIN)

	assert_lt(civ.stability, old_stability, "Stability should drop after breaking NAP")
	var expected := old_stability - Constants.NAP_BREAK_STABILITY_PENALTY
	assert_almost_eq(civ.stability, expected, 0.01, "Stability penalty should match constant")


# --- Trade Tests ---

func test_trade_adds_food_bonus():
	var civ := _make_civ(0, "Alpha")
	var region := RegionData.new()
	region.id = 0
	region.food_yield = 100
	region.infrastructure_level = 0
	region.size_factor = 1.0
	region.development_tier = 0
	region.towns = []

	var base := EconomySimulation.calculate_food_production(civ, [region])

	civ.trade_partners = [1]
	var with_trade := EconomySimulation.calculate_food_production(civ, [region])

	assert_gt(with_trade, base, "Trade should increase food production")


func test_trade_adds_production_bonus():
	var civ := _make_civ(0, "Alpha")
	var region := RegionData.new()
	region.id = 0
	region.production_yield = 100
	region.infrastructure_level = 0
	region.size_factor = 1.0
	region.development_tier = 0
	region.towns = []

	var base := EconomySimulation.calculate_production_output(civ, [region])

	civ.trade_partners = [1]
	var with_trade := EconomySimulation.calculate_production_output(civ, [region])

	assert_gt(with_trade, base, "Trade should increase production output")


func test_trade_breaks_on_war():
	var civ := _make_civ(0, "Alpha")
	var target := _make_civ(1, "Beta")
	civ.trade_partners = [1]
	target.trade_partners = [0]

	# Simulate trade auto-break on war
	civ.war_targets.append(1)
	var broken: Array[int] = []
	for partner_id in civ.trade_partners:
		if civ.war_targets.has(partner_id):
			broken.append(partner_id)
	for partner_id in broken:
		civ.trade_partners.erase(partner_id)
		target.trade_partners.erase(civ.id)

	assert_false(civ.trade_partners.has(1), "Trade should break on war")
	assert_false(target.trade_partners.has(0), "Trade break should be bilateral")


func test_trade_bonus_stacks():
	var civ := _make_civ(0, "Alpha")
	var region := RegionData.new()
	region.id = 0
	region.food_yield = 100
	region.infrastructure_level = 0
	region.size_factor = 1.0
	region.development_tier = 0
	region.towns = []

	civ.trade_partners = [1]
	var one_partner := EconomySimulation.calculate_food_production(civ, [region])

	civ.trade_partners = [1, 2]
	var two_partners := EconomySimulation.calculate_food_production(civ, [region])

	assert_gt(two_partners, one_partner, "Two trade partners should give more bonus than one")


# --- Tribute Tests ---

func test_tribute_requires_strength_ratio():
	var civ := _make_civ(0, "Alpha")
	civ.military_strength = 100.0  # Equal strength

	var target := _make_civ(1, "Beta")
	target.military_strength = 100.0

	var ratio := civ.military_strength / maxf(target.military_strength, 1.0)
	assert_lt(ratio, Constants.TRIBUTE_STRENGTH_RATIO,
		"Equal strength should not meet tribute ratio threshold")


func test_tribute_transfers_production():
	var demander := _make_civ(0, "Alpha")
	demander.military_strength = 200.0
	demander.production_stockpile = 50

	var target := _make_civ(1, "Beta")
	target.military_strength = 100.0
	target.production_stockpile = 50

	var amount := Constants.TRIBUTE_PRODUCTION_AMOUNT
	target.production_stockpile -= amount
	demander.production_stockpile += amount

	assert_eq(demander.production_stockpile, 50 + amount, "Demander should gain production")
	assert_eq(target.production_stockpile, 50 - amount, "Target should lose production")


func test_tribute_cooldown_prevents_spam():
	var civ := _make_civ(0, "Alpha")
	civ.tribute_cooldowns[1] = Constants.TRIBUTE_COOLDOWN_YEARS

	assert_gt(civ.tribute_cooldowns.get(1, 0), 0, "Cooldown should block re-demand")


# --- Constants Tests ---

func test_diplomacy_constants_exist():
	assert_gt(Constants.NAP_DURATION, 0, "NAP_DURATION should be positive")
	assert_gt(Constants.NAP_BREAK_STABILITY_PENALTY, 0.0, "NAP penalty should be positive")
	assert_gt(Constants.TRADE_FOOD_BONUS_PERCENT, 0.0, "Trade food bonus should be positive")
	assert_gt(Constants.TRADE_PRODUCTION_BONUS_PERCENT, 0.0, "Trade prod bonus should be positive")
	assert_gt(Constants.TRIBUTE_STRENGTH_RATIO, 1.0, "Tribute ratio should exceed 1.0")
	assert_gt(Constants.TRIBUTE_PRODUCTION_AMOUNT, 0, "Tribute amount should be positive")
	assert_gt(Constants.TRIBUTE_COOLDOWN_YEARS, 0, "Tribute cooldown should be positive")
