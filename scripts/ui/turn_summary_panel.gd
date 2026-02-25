class_name TurnSummaryPanel
extends PanelContainer

## Compact end-of-turn summary shown after each manual turn.
## Displays top events, stability delta, and territory changes.
## Auto-fades after a few seconds. Click to dismiss early.

var header_label: Label
var events_container: VBoxContainer
var stability_delta_label: Label
var _prev_stability: float = -1.0
var _prev_territories: int = -1
var _deferred: bool = false


func _ready() -> void:
	_build_ui()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.political_events_resolved.connect(_on_political_events_resolved)


func _build_ui() -> void:
	# Position at bottom-center
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_top = -160
	offset_bottom = -12
	offset_left = -190
	offset_right = 190
	custom_minimum_size = Vector2(380, 0)

	add_theme_stylebox_override("panel", UITheme.make_panel_style(
		Color(0.06, 0.05, 0.08, 0.94),
		UITheme.PANEL_BORDER,
		6, 1, 12
	))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	header_label = Label.new()
	header_label.text = "Year 0"
	UITheme.style_label_header(header_label, 16)
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header_label)

	# Thin separator
	var sep := ColorRect.new()
	sep.color = UITheme.PANEL_BORDER
	sep.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(sep)

	events_container = VBoxContainer.new()
	events_container.add_theme_constant_override("separation", 2)
	vbox.add_child(events_container)

	stability_delta_label = Label.new()
	stability_delta_label.text = ""
	UITheme.style_label_body(stability_delta_label, 13, UITheme.PARCHMENT_DIM)
	stability_delta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stability_delta_label)


func _on_turn_started(_year: int) -> void:
	# Capture state before the turn for delta calculation
	var civ := GameState.get_player_civ()
	if civ:
		_prev_stability = civ.stability
		_prev_territories = GameState.get_regions_by_owner(civ.id).size()


func _on_turn_ended(_year: int) -> void:
	# Get reference to hud to check auto-play / fast-forward state
	var hud := _get_hud()
	if hud and (hud.is_fast_forwarding or hud.is_auto_playing):
		return
	if not GameState.pending_political_events.is_empty():
		_deferred = true
		return

	_populate_and_show()


func _on_political_events_resolved() -> void:
	if _deferred:
		_deferred = false
		_populate_and_show()


func _populate_and_show() -> void:
	var year := GameState.current_year
	header_label.text = "Year %d" % year

	# Clear old event lines
	for child in events_container.get_children():
		child.queue_free()

	# Get top events
	var top_events := History.get_top_events(year, 3)

	if top_events.is_empty():
		var quiet := Label.new()
		quiet.text = "A quiet year."
		UITheme.style_label_body(quiet, 13, UITheme.PARCHMENT_DIM)
		quiet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		events_container.add_child(quiet)
	else:
		for event in top_events:
			var lbl := RichTextLabel.new()
			lbl.bbcode_enabled = true
			lbl.fit_content = true
			lbl.scroll_active = false
			lbl.custom_minimum_size = Vector2(350, 0)
			lbl.add_theme_font_override("normal_font", UITheme.get_body_font())
			lbl.add_theme_font_override("bold_font", UITheme.get_body_bold_font())
			lbl.add_theme_font_size_override("normal_font_size", 13)

			var color: Color = _type_color(event.get("type", ""))
			var prefix: String = _type_prefix(event.get("type", ""))
			var desc: String = event.get("description", "")
			var severity: int = event.get("severity", 1)

			if severity >= 3:
				lbl.append_text("[b][color=%s]%s %s[/color][/b]" % [color, prefix, desc])
			else:
				lbl.append_text("[color=%s]%s %s[/color]" % [color, prefix, desc])

			events_container.add_child(lbl)

	# Stability delta
	var civ := GameState.get_player_civ()
	if civ and _prev_stability >= 0:
		var delta := civ.stability - _prev_stability
		var terr_now := GameState.get_regions_by_owner(civ.id).size()
		var terr_delta := terr_now - _prev_territories if _prev_territories >= 0 else 0

		var parts: Array[String] = []

		# Stability with 5yr mini-sparkline
		if absf(delta) > 0.1:
			var arrow := "+" if delta > 0 else ""
			var color := "#5e5" if delta > 0 else "#e55"
			var spark := _mini_sparkline(civ.id, 5)
			parts.append("Stability: [color=%s]%s%.0f[/color] %s" % [color, arrow, delta, spark])

		# Territory
		if terr_delta != 0:
			var arrow := "+" if terr_delta > 0 else ""
			var color := "#5e5" if terr_delta > 0 else "#e55"
			parts.append("Regions: [color=%s]%s%d[/color]" % [color, arrow, terr_delta])

		stability_delta_label.text = ""
		if not parts.is_empty():
			# Use a RichTextLabel for bbcode in the delta line
			stability_delta_label.visible = false
			var delta_rtl := RichTextLabel.new()
			delta_rtl.bbcode_enabled = true
			delta_rtl.fit_content = true
			delta_rtl.scroll_active = false
			delta_rtl.add_theme_font_override("normal_font", UITheme.get_body_font())
			delta_rtl.add_theme_font_size_override("normal_font_size", 12)
			delta_rtl.append_text("  ".join(parts))
			delta_rtl.name = "DeltaRTL"
			# Remove old delta RTL if exists
			var old_delta := events_container.get_parent().find_child("DeltaRTL", false)
			if old_delta:
				old_delta.queue_free()
			events_container.get_parent().add_child(delta_rtl)
		else:
			stability_delta_label.visible = false
	else:
		stability_delta_label.visible = false

	# Show with animation
	visible = true
	modulate.a = 0.0
	position.y += 20
	var target_y := position.y - 20
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(self, "position:y", target_y, 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_interval(4.0)
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(_dismiss)


func _dismiss() -> void:
	visible = false
	# Clean up delta RTL
	var old_delta := events_container.get_parent().find_child("DeltaRTL", false)
	if old_delta:
		old_delta.queue_free()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_dismiss()
		get_viewport().set_input_as_handled()


func _get_hud() -> Node:
	# Walk up to find the HUD (CanvasLayer parent)
	var parent := get_parent()
	while parent:
		if parent.has_method("_toggle_auto_play"):
			return parent
		parent = parent.get_parent()
	return null


func _type_color(type: String) -> String:
	match type:
		"war_declared": return "#e55"
		"peace": return "#8b8"
		"battle": return "#da8"
		"expansion": return "#8c8"
		"collapse": return "#f33"
		"tech": return "#5e5"
		"hero_spawned": return "#5ce"
		"hero_died": return "#999"
		"golden_age_start": return "#fd5"
		"golden_age_end": return "#a85"
		"governance_change": return "#a8d"
		"dev_tier_change": return "#a8d"
		"alliance_formed": return "#8af"
		"alliance_broken": return "#da8"
		"nap_formed": return "#8af"
		"nap_broken": return "#8af"
		"trade_formed": return "#8c8"
		"trade_broken": return "#8c8"
		"tribute_demanded": return "#e85"
		"succession": return "#f8b"
		"election": return "#8cf"
		"coup": return "#f66"
		"legitimacy_shift": return "#caa"
		"trait_changed": return "#c8a"
		_: return "#aaa"


func _mini_sparkline(civ_id: int, n: int) -> String:
	var trend := History.get_stability_trend(civ_id, n)
	if trend.size() < 2:
		return ""
	var bars: Array[String] = ["_", ".", "-", "~", "=", "#"]
	var result := ""
	for entry in trend:
		var v: float = entry.get("value", 50.0)
		var idx := clampi(int(v / 16.7), 0, bars.size() - 1)
		result += bars[idx]
	return "[color=#888]%s[/color]" % result


func _type_prefix(type: String) -> String:
	match type:
		"war_declared": return "[WAR]"
		"peace": return "[PEACE]"
		"battle": return "[BATTLE]"
		"expansion": return "[EXPAND]"
		"collapse": return "[COLLAPSE]"
		"tech": return "[TECH]"
		"hero_spawned": return "[HERO]"
		"hero_died": return "[HERO]"
		"golden_age_start": return "[GOLDEN]"
		"golden_age_end": return "[GOLDEN]"
		"governance_change": return "[GOV]"
		"dev_tier_change": return "[DEV]"
		"alliance_formed": return "[ALLIANCE]"
		"alliance_broken": return "[ALLIANCE]"
		"nap_formed": return "[NAP]"
		"nap_broken": return "[NAP]"
		"trade_formed": return "[TRADE]"
		"trade_broken": return "[TRADE]"
		"tribute_demanded": return "[TRIBUTE]"
		"shortage": return "[SHORTAGE]"
		"infra_upgrade": return "[INFRA]"
		"succession": return "[SUCCESSION]"
		"election": return "[ELECTION]"
		"coup": return "[COUP]"
		"legitimacy_shift": return "[LEGIT]"
		"trait_changed": return "[TRAIT]"
		_: return ""
