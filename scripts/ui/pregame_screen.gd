class_name PregameScreen
extends Control

## Pre-game screen: civ selection, game configuration, and start button.
## Shows available civilizations with previews and lets the player choose.

var _selected_civ_id: int = 0
var _civ_buttons: Array[Button] = []
var _start_btn: Button
var _description_label: RichTextLabel
var _map_size_option: OptionButton
var _selected_map_size: int = Enums.MapSize.MEDIUM

const CIV_PREVIEWS := {
	0: {"name": "Terran Republic", "color": Color(0.2, 0.4, 0.8),
		"desc": "Balanced expansion and diplomacy. Start near river basins."},
	1: {"name": "Ashkari Dominion", "color": Color(0.7, 0.2, 0.15),
		"desc": "Aggressive military focus. Start near mountains."},
	2: {"name": "Verdant Collective", "color": Color(0.15, 0.6, 0.25),
		"desc": "Economy and growth focus. Start near plains."},
}


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# Full-screen background
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.08, 0.12)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	# Main container
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(600, 500)
	vbox.position = Vector2(-300, -250)
	vbox.add_theme_constant_override("separation", 20)
	add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "EPOCH ENGINE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label_header(title, 32)
	vbox.add_child(title)

	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "Choose Your Civilization"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label_body(subtitle, 14, Color(0.6, 0.58, 0.52))
	vbox.add_child(subtitle)

	# Civ selection buttons
	var btn_container := HBoxContainer.new()
	btn_container.add_theme_constant_override("separation", 15)
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_container)

	for civ_id in CIV_PREVIEWS:
		var preview: Dictionary = CIV_PREVIEWS[civ_id]
		var btn := Button.new()
		btn.text = preview["name"]
		btn.custom_minimum_size = Vector2(170, 60)
		btn.focus_mode = FOCUS_NONE
		UITheme.style_button(btn)
		btn.pressed.connect(_on_civ_selected.bind(civ_id))
		btn_container.add_child(btn)
		_civ_buttons.append(btn)

	# Description panel
	_description_label = RichTextLabel.new()
	_description_label.custom_minimum_size = Vector2(500, 80)
	_description_label.bbcode_enabled = true
	_description_label.fit_content = true
	_description_label.scroll_active = false
	vbox.add_child(_description_label)

	# Map size selection
	var size_row := HBoxContainer.new()
	size_row.alignment = BoxContainer.ALIGNMENT_CENTER
	size_row.add_theme_constant_override("separation", 10)
	vbox.add_child(size_row)

	var size_label := Label.new()
	size_label.text = "Map Size"
	UITheme.style_label_body(size_label, 12, Color(0.7, 0.68, 0.62))
	size_row.add_child(size_label)

	_map_size_option = OptionButton.new()
	_map_size_option.custom_minimum_size = Vector2(180, 32)
	UITheme.style_button(_map_size_option)
	_map_size_option.add_item("Small (120)", Enums.MapSize.SMALL)
	_map_size_option.add_item("Medium (240)", Enums.MapSize.MEDIUM)
	_map_size_option.add_item("Large (420)", Enums.MapSize.LARGE)
	_map_size_option.item_selected.connect(_on_map_size_selected)
	size_row.add_child(_map_size_option)

	# Default to current config
	for i in range(_map_size_option.item_count):
		if _map_size_option.get_item_id(i) == GameState.map_config.map_size:
			_map_size_option.select(i)
			_selected_map_size = GameState.map_config.map_size
			break

	# Start button
	_start_btn = Button.new()
	_start_btn.text = "Begin Epoch"
	_start_btn.custom_minimum_size = Vector2(200, 50)
	_start_btn.focus_mode = FOCUS_NONE
	UITheme.style_button(_start_btn)
	_start_btn.pressed.connect(_on_start_pressed)
	vbox.add_child(_start_btn)

	# Version label
	var version := Label.new()
	version.text = "v0.1 - Map Evolution Build"
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label_body(version, 10, Color(0.4, 0.38, 0.35))
	vbox.add_child(version)

	# Select first civ by default
	_on_civ_selected(0)


func _on_civ_selected(civ_id: int) -> void:
	_selected_civ_id = civ_id
	var preview: Dictionary = CIV_PREVIEWS[civ_id]

	# Update button highlights
	for i in _civ_buttons.size():
		var btn := _civ_buttons[i]
		if i == civ_id:
			btn.modulate = Color(1.2, 1.2, 1.0)
		else:
			btn.modulate = Color(0.7, 0.7, 0.7)

	# Update description
	_description_label.text = "[center][color=#c8b87a]%s[/color]\n%s[/center]" % [
		preview["name"], preview["desc"]]


func _on_map_size_selected(index: int) -> void:
	_selected_map_size = _map_size_option.get_item_id(index)


func _on_start_pressed() -> void:
	# Set player civ before changing scene, then spawn units for correct civ
	GameState.map_config.map_size = _selected_map_size
	GameState.load_game_data()
	GameState.player_civ_id = _selected_civ_id
	GameState.start_new_game()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
