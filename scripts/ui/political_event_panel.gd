class_name PoliticalEventPanel
extends PanelContainer

## Modal for player political events (succession, elections, coups).

var _title: Label
var _desc: RichTextLabel
var _choices_box: VBoxContainer
var _current_event: Dictionary = {}


func _ready() -> void:
	_build_ui()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	EventBus.political_event_pending.connect(_on_event_pending)


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(420, 0)
	offset_left = -220
	offset_right = 220
	offset_top = -160
	offset_bottom = 160

	add_theme_stylebox_override("panel", UITheme.make_panel_style(
		Color(0.06, 0.05, 0.08, 0.96),
		UITheme.PANEL_BORDER,
		6, 1, 16
	))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	_title = Label.new()
	_title.text = "Political Event"
	UITheme.style_label_header(_title, 18)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title)

	var sep := ColorRect.new()
	sep.color = UITheme.PANEL_BORDER
	sep.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(sep)

	_desc = RichTextLabel.new()
	_desc.bbcode_enabled = true
	_desc.fit_content = true
	_desc.scroll_active = false
	_desc.add_theme_font_override("normal_font", UITheme.get_body_font())
	_desc.add_theme_font_override("bold_font", UITheme.get_body_bold_font())
	_desc.add_theme_font_size_override("normal_font_size", 13)
	_desc.add_theme_color_override("default_color", UITheme.PARCHMENT)
	vbox.add_child(_desc)

	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 6)
	vbox.add_child(_choices_box)


func _on_event_pending(_event_data: Dictionary) -> void:
	if visible:
		return
	_show_next_event()


func _show_next_event() -> void:
	_current_event = GameState.pop_next_political_event()
	if _current_event.is_empty():
		visible = false
		EventBus.political_events_resolved.emit()
		return

	_title.text = _current_event.get("title", "Political Event")
	_desc.clear()
	_desc.append_text(_current_event.get("description", "A political decision confronts you."))

	for child in _choices_box.get_children():
		child.queue_free()

	var choices: Array = _current_event.get("choices", [])
	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		var btn := Button.new()
		btn.text = choice.get("label", "Option")
		UITheme.style_button(btn)
		btn.pressed.connect(func() -> void:
			PoliticalEvents.resolve_event_choice(_current_event, i, true)
			_show_next_event()
		)
		_choices_box.add_child(btn)

	visible = true
