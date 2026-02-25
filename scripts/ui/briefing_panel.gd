class_name BriefingPanel
extends PanelContainer

## Start-of-year briefing. Highlights major risks and upcoming events.

var _year_label: Label
var _warnings_box: VBoxContainer
var _continue_btn: Button


func _ready() -> void:
	_build_ui()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	EventBus.turn_started.connect(_on_turn_started)


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_top = 70
	offset_left = -220
	offset_right = 220
	offset_bottom = 260

	add_theme_stylebox_override("panel", UITheme.make_panel_style(
		Color(0.06, 0.05, 0.08, 0.94),
		UITheme.PANEL_BORDER,
		6, 1, 14
	))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	_year_label = Label.new()
	_year_label.text = "Year 0 Briefing"
	UITheme.style_label_header(_year_label, 18)
	_year_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_year_label)

	var sep := ColorRect.new()
	sep.color = UITheme.PANEL_BORDER
	sep.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(sep)

	_warnings_box = VBoxContainer.new()
	_warnings_box.add_theme_constant_override("separation", 4)
	vbox.add_child(_warnings_box)

	_continue_btn = Button.new()
	_continue_btn.text = "Continue"
	UITheme.style_button(_continue_btn)
	_continue_btn.pressed.connect(_dismiss)
	vbox.add_child(_continue_btn)


func _on_turn_started(year: int) -> void:
	var hud: Node = _get_hud()
	if hud and (hud.is_fast_forwarding or hud.is_auto_playing):
		return

	var warnings: Array = _collect_warnings()
	if warnings.is_empty():
		return

	_year_label.text = "Year %d Briefing" % year
	for child in _warnings_box.get_children():
		child.queue_free()

	for item in warnings:
		var lbl := Label.new()
		lbl.text = "• %s" % item["text"]
		UITheme.style_label_body(lbl, 13, item["color"])
		_warnings_box.add_child(lbl)

	visible = true
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.2)


func _collect_warnings() -> Array:
	var result: Array = []
	var civ: CivilizationData = GameState.get_player_civ()
	if not civ:
		return result

	if civ.legitimacy < 40.0:
		result.append({"text": "Legitimacy is low (%.0f%%)" % civ.legitimacy, "color": Color(0.9, 0.4, 0.35)})

	if civ.food_stockpile < Constants.SHORTAGE_THRESHOLD:
		result.append({"text": "Food shortage risk (stockpile %d)" % civ.food_stockpile, "color": UITheme.COLOR_FOOD})

	if civ.production_stockpile < Constants.SHORTAGE_THRESHOLD:
		result.append({"text": "Production shortage risk (stockpile %d)" % civ.production_stockpile, "color": UITheme.COLOR_PRODUCTION})

	if not civ.war_targets.is_empty():
		result.append({"text": "Active war fronts (%d)" % civ.war_targets.size(), "color": Color(0.9, 0.3, 0.3)})

	var war_exhaust := StabilitySimulation.get_war_exhaustion(civ)
	if war_exhaust >= 6.0:
		result.append({"text": "War exhaustion rising (%.1f)" % war_exhaust, "color": Color(0.9, 0.35, 0.3)})

	if civ.government_form == Enums.GovernmentForm.REPUBLIC:
		var yrs_left := civ.election_interval - civ.years_since_election
		if yrs_left <= 1:
			result.append({"text": "Election due next year", "color": UITheme.GOLD_DIM})
	else:
		if civ.ruler_lifespan - civ.ruler_age <= 3:
			result.append({"text": "Succession risk: ruler is aging", "color": UITheme.GOLD_DIM})

	var disaster_count := 0
	for region in GameState.get_regions_by_owner(civ.id):
		if region.active_disaster >= 0:
			disaster_count += 1
	if disaster_count > 0:
		result.append({"text": "Active disasters in %d regions" % disaster_count, "color": Color(0.75, 0.55, 0.35)})

	return result


func _dismiss() -> void:
	visible = false


func _get_hud() -> Node:
	var parent := get_parent()
	while parent:
		if parent.has_method("_toggle_auto_play"):
			return parent
		parent = parent.get_parent()
	return null
