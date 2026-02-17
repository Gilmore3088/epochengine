class_name PauseMenu
extends PanelContainer

## Pause menu overlay with Save, Load, Resume, and Quit.
## Esc toggles. Pauses game tree while open.
## Uses PROCESS_MODE_WHEN_PAUSED so it remains active during pause.

const FONT_TITLE := 24
const FONT_BUTTON := 14
const FONT_BODY := 12

var _content: VBoxContainer
var _save_list_container: VBoxContainer
var _feedback_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	_build_shell()


func _build_shell() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.02, 0.04, 0.80)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var inner := PanelContainer.new()
	inner.custom_minimum_size = Vector2(360, 0)
	inner.add_theme_stylebox_override("panel", UITheme.make_panel_style(
		Color(0.07, 0.06, 0.09, 0.97),
		Color(0.50, 0.42, 0.28, 0.7),
		12, 2, 24
	))
	center.add_child(inner)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	inner.add_child(margin)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(_content)

	# Title
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UITheme.get_header_font())
	title.add_theme_font_size_override("font_size", FONT_TITLE)
	title.add_theme_color_override("font_color", UITheme.GOLD)
	_content.add_child(title)

	_add_sep()

	# Resume button
	var resume_btn := _make_btn("Resume")
	resume_btn.pressed.connect(_on_resume)
	_content.add_child(resume_btn)

	# Save button
	var save_btn := _make_btn("Save Game")
	save_btn.pressed.connect(_on_save)
	_content.add_child(save_btn)

	# Load button
	var load_btn := _make_btn("Load Game")
	load_btn.pressed.connect(_on_load)
	_content.add_child(load_btn)

	_add_sep()

	# Quit button
	var quit_btn := _make_btn("Quit to Desktop")
	quit_btn.pressed.connect(_on_quit)
	_content.add_child(quit_btn)

	# Feedback label (hidden by default)
	_feedback_label = Label.new()
	_feedback_label.text = ""
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label_body(_feedback_label, FONT_BODY, UITheme.GOLD)
	_content.add_child(_feedback_label)

	# Save list container (for load game)
	_save_list_container = VBoxContainer.new()
	_save_list_container.add_theme_constant_override("separation", 4)
	_save_list_container.visible = false
	_content.add_child(_save_list_container)


func open_menu() -> void:
	if visible:
		return
	visible = true
	get_tree().paused = true
	_feedback_label.text = ""
	_save_list_container.visible = false


func close_menu() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if visible:
			close_menu()
			get_viewport().set_input_as_handled()


func _on_resume() -> void:
	close_menu()


func _on_save() -> void:
	var success := SaveManager.save_game("manual")
	if success:
		_feedback_label.text = "Game saved!"
	else:
		_feedback_label.text = "Save failed."


func _on_load() -> void:
	_save_list_container.visible = not _save_list_container.visible
	if _save_list_container.visible:
		_rebuild_save_list()


func _on_quit() -> void:
	get_tree().paused = false
	get_tree().quit()


func _rebuild_save_list() -> void:
	for child in _save_list_container.get_children():
		child.queue_free()

	var saves := SaveManager.get_save_list()
	if saves.is_empty():
		var lbl := Label.new()
		lbl.text = "No saves found."
		UITheme.style_label_body(lbl, FONT_BODY, UITheme.PARCHMENT_DIM)
		_save_list_container.add_child(lbl)
		return

	for slot_name in saves:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var name_lbl := Label.new()
		name_lbl.text = slot_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.style_label_body(name_lbl, FONT_BODY, UITheme.PARCHMENT_DIM)
		row.add_child(name_lbl)

		var load_btn := Button.new()
		load_btn.text = "Load"
		load_btn.focus_mode = Control.FOCUS_NONE
		UITheme.style_button(load_btn)
		load_btn.add_theme_font_size_override("font_size", FONT_BODY)
		load_btn.pressed.connect(_on_load_slot.bind(slot_name))
		row.add_child(load_btn)

		_save_list_container.add_child(row)


func _on_load_slot(slot_name: String) -> void:
	var success := SaveManager.load_game(slot_name)
	if success:
		close_menu()
		EventBus.turn_ended.emit(GameState.current_year)
	else:
		_feedback_label.text = "Load failed."


func _add_sep() -> void:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
	_content.add_child(sep)


func _make_btn(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	UITheme.style_button(btn)
	btn.add_theme_font_size_override("font_size", FONT_BUTTON)
	btn.custom_minimum_size = Vector2(200, 36)
	return btn
