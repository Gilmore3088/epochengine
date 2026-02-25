extends PanelContainer

## Dismissable tutorial tip panel. Centered on screen.
## Connects to EventBus.tutorial_tip_requested to show tips.

var _title_label: Label
var _body_label: Label
var _got_it_btn: Button
var _skip_all_btn: Button
var _close_btn: Button
var _is_active: bool = false


func _ready() -> void:
	_build_ui()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.tutorial_tip_requested.connect(_on_tip_requested)
	EventBus.tutorial_dismissed_all.connect(_on_dismissed_all)


func _build_ui() -> void:
	# Panel style
	var panel_style := UITheme.make_panel_style(
		Color(0.12, 0.10, 0.08, 0.94),
		UITheme.GOLD_DIM,
		8, 1, 16,
	)
	add_theme_stylebox_override("panel", panel_style)

	# Position: center of screen for maximum visibility
	set_anchors_preset(Control.PRESET_CENTER)
	anchor_top = 0.5
	anchor_bottom = 0.5
	anchor_left = 0.5
	anchor_right = 0.5
	offset_left = -240
	offset_right = 240
	offset_top = -80
	offset_bottom = 80

	# Content
	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	# Header row: title + close button
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(header)

	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_label_header(_title_label, 16)
	header.add_child(_title_label)

	_close_btn = Button.new()
	_close_btn.text = "X"
	_close_btn.custom_minimum_size = Vector2(28, 28)
	UITheme.style_button(_close_btn)
	_close_btn.pressed.connect(_dismiss)
	header.add_child(_close_btn)

	# Body text
	_body_label = Label.new()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_label_body(_body_label, 14, UITheme.PARCHMENT)
	vbox.add_child(_body_label)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(spacer)

	# Button row
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	_got_it_btn = Button.new()
	_got_it_btn.text = "Got it!"
	UITheme.style_button(_got_it_btn)
	_got_it_btn.pressed.connect(_dismiss)
	btn_row.add_child(_got_it_btn)

	_skip_all_btn = Button.new()
	_skip_all_btn.text = "Skip All"
	UITheme.style_button(_skip_all_btn)
	_skip_all_btn.add_theme_color_override("font_color", Color(0.5, 0.45, 0.4))
	_skip_all_btn.pressed.connect(_skip_all)
	btn_row.add_child(_skip_all_btn)


func _on_tip_requested(tip_data: Dictionary) -> void:
	_title_label.text = tip_data.get("title", "Tip")
	_body_label.text = tip_data.get("body", "")
	_is_active = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Fade in
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)


func _on_dismissed_all() -> void:
	_is_active = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _dismiss() -> void:
	_is_active = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	TutorialManager.on_tip_dismissed()


func _skip_all() -> void:
	_is_active = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	TutorialManager.dismiss_all()


func _unhandled_key_input(event: InputEvent) -> void:
	if not _is_active or not visible:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_dismiss()
