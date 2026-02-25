extends GutTest

## Tests for TraitSimulation (core/simulation/trait_simulation.gd)


func _make_civ(
	expansion: float = 0.5, aggression: float = 0.5,
	diplomacy: float = 0.5, economy: float = 0.5,
) -> CivilizationData:
	var civ := CivilizationData.new(0, "TestCiv", Color.RED)
	civ.expansion_bias = expansion
	civ.aggression_bias = aggression
	civ.diplomacy_bias = diplomacy
	civ.economy_bias = economy
	civ.capital_region_id = 0
	return civ


func _empty_events() -> Dictionary:
	return {
		"battles": [],
		"golden_age_starts": [],
		"golden_age_ends": [],
		"ai_events": [],
		"era_changes": [],
	}


# --- Clamping Tests ---

func test_apply_mutation_clamps_high() -> void:
	var civ := _make_civ(0.5, 0.88, 0.5, 0.5)
	var evt := TraitSimulation._apply_mutation(civ, "aggression_bias", 0.05, "test")
	assert_lte(civ.aggression_bias, Constants.TRAIT_MAX,
		"Bias should be clamped to TRAIT_MAX")


func test_apply_mutation_clamps_low() -> void:
	var civ := _make_civ(0.5, 0.12, 0.5, 0.5)
	var evt := TraitSimulation._apply_mutation(civ, "aggression_bias", -0.05, "test")
	assert_gte(civ.aggression_bias, Constants.TRAIT_MIN,
		"Bias should be clamped to TRAIT_MIN")


# --- Tag Crossing Tests ---

func test_apply_mutation_tag_cross_returns_event() -> void:
	# aggression at 0.59, +0.02 -> 0.61 crosses 0.6 threshold (Neutral -> Warlike)
	var civ := _make_civ(0.5, 0.59, 0.5, 0.5)
	var evt := TraitSimulation._apply_mutation(civ, "aggression_bias", 0.02, "test")
	assert_false(evt.is_empty(), "Tag crossing should produce event")
	assert_eq(evt["new_tag"], "Warlike")
	assert_eq(evt["type"], "trait_changed")


func test_apply_mutation_no_tag_change_returns_empty() -> void:
	# aggression at 0.5, +0.02 -> 0.52, still in neutral zone
	var civ := _make_civ(0.5, 0.50, 0.5, 0.5)
	var evt := TraitSimulation._apply_mutation(civ, "aggression_bias", 0.02, "test")
	assert_true(evt.is_empty(), "No tag crossing should return empty dict")


# --- Battle Events ---

func test_battle_win_increases_aggression() -> void:
	var civ := _make_civ(0.5, 0.50, 0.5, 0.5)
	var events := _empty_events()
	events["battles"] = [{"attacker_id": 0, "defender_id": 1, "winner_id": 0, "region_name": "Plains"}]
	TraitSimulation._process_battle_events(civ, events)
	assert_gt(civ.aggression_bias, 0.50, "Win should increase aggression")


func test_battle_loss_decreases_aggression_increases_diplomacy() -> void:
	var civ := _make_civ(0.5, 0.50, 0.50, 0.5)
	var events := _empty_events()
	events["battles"] = [{"attacker_id": 0, "defender_id": 1, "winner_id": 1, "region_name": "Plains"}]
	TraitSimulation._process_battle_events(civ, events)
	assert_lt(civ.aggression_bias, 0.50, "Loss should decrease aggression")
	assert_gt(civ.diplomacy_bias, 0.50, "Loss should increase diplomacy")


# --- Golden Age Events ---

func test_golden_age_start_reinforces_dominant() -> void:
	# economy is highest at 0.7
	var civ := _make_civ(0.5, 0.5, 0.5, 0.70)
	var events := _empty_events()
	events["golden_age_starts"] = [{"civ_id": 0}]
	TraitSimulation._process_golden_age_events(civ, events)
	assert_gt(civ.economy_bias, 0.70, "Golden age start should reinforce dominant bias")


func test_golden_age_end_regresses_toward_center() -> void:
	var civ := _make_civ(0.5, 0.80, 0.5, 0.5)
	var events := _empty_events()
	events["golden_age_ends"] = [{"civ_id": 0}]
	TraitSimulation._process_golden_age_events(civ, events)
	assert_lt(civ.aggression_bias, 0.80, "Golden age end should regress extreme biases toward 0.5")


# --- Expansion Events ---

func test_expansion_increases_expansion_bias() -> void:
	var civ := _make_civ(0.50, 0.5, 0.5, 0.5)
	var events := _empty_events()
	events["ai_events"] = [{"type": "expansion", "civ_id": 0, "region_name": "Desert"}]
	TraitSimulation._process_expansion_events(civ, events)
	assert_gt(civ.expansion_bias, 0.50, "Expansion should increase expansion_bias")


# --- Alliance Events ---

func test_alliance_formed_increases_diplomacy() -> void:
	var civ := _make_civ(0.5, 0.5, 0.50, 0.5)
	var events := _empty_events()
	events["ai_events"] = [{"type": "alliance_formed", "civ_a_id": 0, "civ_b_id": 1}]
	TraitSimulation._process_diplomacy_events(civ, events)
	assert_gt(civ.diplomacy_bias, 0.50, "Alliance formed should increase diplomacy")


func test_alliance_broken_decreases_diplomacy() -> void:
	var civ := _make_civ(0.5, 0.5, 0.50, 0.5)
	var events := _empty_events()
	events["ai_events"] = [{"type": "alliance_broken", "civ_a_id": 0, "civ_b_id": 1}]
	TraitSimulation._process_diplomacy_events(civ, events)
	assert_lt(civ.diplomacy_bias, 0.50, "Alliance broken should decrease diplomacy")


# --- Era Events ---

func test_era_moderates_extreme_biases() -> void:
	var civ := _make_civ(0.5, 0.85, 0.5, 0.5)
	var events := _empty_events()
	events["era_changes"] = [{"civ_id": 0}]
	TraitSimulation._process_era_events(civ, events)
	assert_lt(civ.aggression_bias, 0.85, "Era change should moderate extreme high biases")


func test_era_does_not_affect_moderate_biases() -> void:
	var civ := _make_civ(0.5, 0.50, 0.5, 0.5)
	var events := _empty_events()
	events["era_changes"] = [{"civ_id": 0}]
	TraitSimulation._process_era_events(civ, events)
	assert_eq(civ.aggression_bias, 0.50, "Era change should not affect moderate biases")


func test_era_moderates_extreme_low_biases() -> void:
	var civ := _make_civ(0.5, 0.15, 0.5, 0.5)
	var events := _empty_events()
	events["era_changes"] = [{"civ_id": 0}]
	TraitSimulation._process_era_events(civ, events)
	assert_gt(civ.aggression_bias, 0.15, "Era change should moderate extreme low biases")


# --- Long Peace ---

func test_long_peace_shifts_after_threshold() -> void:
	var civ := _make_civ(0.5, 0.50, 0.5, 0.50)
	civ.years_at_peace = Constants.TRAIT_LONG_PEACE_YEARS - 1  # One year short
	# Not at war — peace counter will increment to threshold
	TraitSimulation._process_long_peace(civ)
	assert_lt(civ.aggression_bias, 0.50, "Long peace should decrease aggression")
	assert_gt(civ.economy_bias, 0.50, "Long peace should increase economy")
	assert_eq(civ.years_at_peace, 0, "Counter should reset after triggering")


func test_long_peace_resets_at_war() -> void:
	var civ := _make_civ(0.5, 0.50, 0.5, 0.50)
	civ.years_at_peace = 15
	civ.war_targets = [1]
	TraitSimulation._process_long_peace(civ)
	assert_eq(civ.years_at_peace, 0, "Counter should reset when at war")
	assert_eq(civ.aggression_bias, 0.50, "Biases unchanged when at war")


# --- Hero Influence ---

func test_hero_general_increases_aggression() -> void:
	var civ := _make_civ(0.5, 0.50, 0.5, 0.5)
	var hero := HeroData.new()
	hero.id = 99
	hero.type = Enums.HeroType.GENERAL
	hero.owner_civ_id = 0
	GameState.heroes[99] = hero
	civ.hero_ids = [99]
	TraitSimulation._hero_influence(civ)
	assert_gt(civ.aggression_bias, 0.50, "General should increase aggression")
	GameState.heroes.erase(99)


func test_hero_reformer_increases_diplomacy() -> void:
	var civ := _make_civ(0.5, 0.5, 0.50, 0.5)
	var hero := HeroData.new()
	hero.id = 99
	hero.type = Enums.HeroType.REFORMER
	hero.owner_civ_id = 0
	GameState.heroes[99] = hero
	civ.hero_ids = [99]
	TraitSimulation._hero_influence(civ)
	assert_gt(civ.diplomacy_bias, 0.50, "Reformer should increase diplomacy")
	GameState.heroes.erase(99)


func test_hero_visionary_increases_economy() -> void:
	var civ := _make_civ(0.5, 0.5, 0.5, 0.50)
	var hero := HeroData.new()
	hero.id = 99
	hero.type = Enums.HeroType.VISIONARY
	hero.owner_civ_id = 0
	GameState.heroes[99] = hero
	civ.hero_ids = [99]
	TraitSimulation._hero_influence(civ)
	assert_gt(civ.economy_bias, 0.50, "Visionary should increase economy")
	GameState.heroes.erase(99)


# --- Annual Drift ---

func test_annual_drift_deterministic() -> void:
	var civ1 := _make_civ()
	var civ2 := _make_civ()
	GameState.set_sim_seed(42)
	TraitSimulation._annual_drift(civ1)
	GameState.set_sim_seed(42)
	TraitSimulation._annual_drift(civ2)
	# Same seed should produce same mutation
	assert_eq(civ1.expansion_bias, civ2.expansion_bias)
	assert_eq(civ1.aggression_bias, civ2.aggression_bias)
	assert_eq(civ1.diplomacy_bias, civ2.diplomacy_bias)
	assert_eq(civ1.economy_bias, civ2.economy_bias)


# --- Tracking ---

func test_initial_bias_tracking_set_once() -> void:
	var civ := _make_civ(0.6, 0.7, 0.4, 0.5)
	civ.initialize_trait_tracking()
	assert_eq(civ.initial_expansion_bias, 0.6)
	# Change biases and reinitialize — initial should NOT change
	civ.expansion_bias = 0.8
	civ.initialize_trait_tracking()
	assert_eq(civ.initial_expansion_bias, 0.6,
		"Initial bias should only be set once")


# --- Integration ---

func test_evolve_traits_empty_events_only_drift() -> void:
	var civ := _make_civ()
	GameState.set_sim_seed(42)
	var events := _empty_events()
	var result := TraitSimulation.evolve_traits(civ, events)
	# Only annual drift should modify exactly one bias by 0.01
	var changes := 0
	if civ.expansion_bias != 0.5: changes += 1
	if civ.aggression_bias != 0.5: changes += 1
	if civ.diplomacy_bias != 0.5: changes += 1
	if civ.economy_bias != 0.5: changes += 1
	assert_eq(changes, 1, "Empty events should only cause 1 bias to drift")


# --- Tag Name Tests ---

func test_get_tag_for_bias_high_values() -> void:
	assert_eq(TraitSimulation._get_tag_for_bias("expansion_bias", 0.7), "Expansionist")
	assert_eq(TraitSimulation._get_tag_for_bias("aggression_bias", 0.8), "Warlike")
	assert_eq(TraitSimulation._get_tag_for_bias("diplomacy_bias", 0.6), "Diplomatic")
	assert_eq(TraitSimulation._get_tag_for_bias("economy_bias", 0.9), "Mercantile")


func test_get_tag_for_bias_low_values() -> void:
	assert_eq(TraitSimulation._get_tag_for_bias("expansion_bias", 0.2), "Insular")
	assert_eq(TraitSimulation._get_tag_for_bias("aggression_bias", 0.1), "Pacifist")
	assert_eq(TraitSimulation._get_tag_for_bias("diplomacy_bias", 0.3), "Isolationist")
	assert_eq(TraitSimulation._get_tag_for_bias("economy_bias", 0.15), "Austere")


func test_get_tag_for_bias_neutral() -> void:
	assert_eq(TraitSimulation._get_tag_for_bias("aggression_bias", 0.5), "")
	assert_eq(TraitSimulation._get_tag_for_bias("expansion_bias", 0.4), "")
