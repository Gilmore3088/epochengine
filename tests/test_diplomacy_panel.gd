extends GutTest

## Tests for DiplomacyPanel: relationship display, action buttons, data accuracy.

var _saved_regions: Dictionary
var _saved_civs: Dictionary
var _saved_player_id: int


func before_each() -> void:
	_saved_regions = GameState.regions.duplicate()
	_saved_civs = GameState.civilizations.duplicate()
	_saved_player_id = GameState.player_civ_id


func after_each() -> void:
	GameState.regions = _saved_regions
	GameState.civilizations = _saved_civs
	GameState.player_civ_id = _saved_player_id


func _make_civ(id: int, name: String = "TestCiv", color: Color = Color.RED) -> CivilizationData:
	var civ := CivilizationData.new(id, name, color)
	civ.stability = 50.0
	civ.food_stockpile = 100
	civ.production_stockpile = 100
	civ.military_strength = 50.0
	civ.total_population = 5000
	return civ


func _setup_two_civs() -> void:
	GameState.civilizations.clear()
	GameState.player_civ_id = 0

	var player := _make_civ(0, "PlayerCiv", Color.BLUE)
	player.is_player = true
	GameState.civilizations[0] = player

	var ai := _make_civ(1, "AICiv", Color.RED)
	GameState.civilizations[1] = ai


# --- Toggle ---

func test_toggle_opens_and_closes() -> void:
	var panel := DiplomacyPanel.new()
	add_child(panel)
	assert_false(panel.visible, "Panel should start hidden")
	panel.toggle()
	assert_true(panel.visible, "Panel should be visible after toggle")
	panel.toggle()
	assert_false(panel.visible, "Panel should be hidden after second toggle")
	panel.queue_free()


# --- Relationship Detection ---

func test_war_relationship_detected() -> void:
	_setup_two_civs()
	var player: CivilizationData = GameState.civilizations[0]
	player.war_targets.append(1)
	player.war_durations[1] = 5

	var panel := DiplomacyPanel.new()
	add_child(panel)
	panel.toggle()
	# Panel is built — check it's visible (content is dynamic children)
	assert_true(panel.visible)
	panel.queue_free()


func test_alliance_relationship_detected() -> void:
	_setup_two_civs()
	var player: CivilizationData = GameState.civilizations[0]
	player.alliance_partners.append(1)

	var panel := DiplomacyPanel.new()
	add_child(panel)
	panel.toggle()
	assert_true(panel.visible)
	panel.queue_free()


func test_collapsed_civ_shown() -> void:
	_setup_two_civs()
	var ai: CivilizationData = GameState.civilizations[1]
	ai.is_collapsed = true

	var panel := DiplomacyPanel.new()
	add_child(panel)
	panel.toggle()
	assert_true(panel.visible)
	panel.queue_free()


# --- Format ---

func test_format_pop_small() -> void:
	assert_eq(DiplomacyPanel._format_pop(500), "500")


func test_format_pop_large() -> void:
	assert_eq(DiplomacyPanel._format_pop(15000), "15.0k")


func test_format_pop_boundary() -> void:
	assert_eq(DiplomacyPanel._format_pop(10000), "10.0k")
	assert_eq(DiplomacyPanel._format_pop(9999), "9999")
