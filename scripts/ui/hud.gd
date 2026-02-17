extends CanvasLayer

## HUD with historical theme, Cinzel/Garamond fonts, grouped status strip,
## overlay buttons, event log, and fast-forward summary modal.

# --- Top bar elements ---
var year_label: Label
var stability_bar: ProgressBar
var stability_label: Label
var food_label: Label
var production_label: Label
var military_label: Label
var advance_button: Button
var speed_5x_button: Button
var speed_10x_button: Button
var speed_label: Label
var era_label: Label
var governance_label: Label
var regions_label: Label
var zoom_in_btn: Button
var zoom_out_btn: Button

# --- Resource bar elements ---
var resource_bar_bg: Panel
var resource_labels: Dictionary = {}  # {resource_type_int: Label}

# --- Overlay buttons ---
var overlay_buttons: Dictionary = {}

# --- Event log ---
var event_log: RichTextLabel

# --- Summary modal ---
var summary_bg: ColorRect
var summary_panel: PanelContainer
var summary_year_label: Label
var summary_content: RichTextLabel
var summary_continue_btn: Button

# --- State ---
var player_civ_id: int:
	get: return GameState.player_civ_id
var fast_forward_count: int = 0
var fast_forward_target: int = 0
var is_fast_forwarding: bool = false
var ff_should_pause: bool = false

# Auto-play state
var is_auto_playing: bool = false
var auto_play_interval: float = 0.8
var play_btn: Button
var playing_label: Label

# Toast notification elements
var toast_container: VBoxContainer

# Pre-fast-forward state snapshot
var ff_pre_state: Dictionary = {}

# Event counters during fast-forward
var ff_counters: Dictionary = {}


func _ready() -> void:
	_build_ui()
	_connect_signals()
	_update_display()
	# Auto-play timer
	var timer := Timer.new()
	timer.name = "AutoPlayTimer"
	timer.wait_time = auto_play_interval
	timer.one_shot = false
	timer.timeout.connect(_on_auto_play_timeout)
	add_child(timer)


func _build_ui() -> void:
	_build_top_bar()
	_build_resource_bar()
	_build_overlay_strip()
	_build_event_log()
	_build_toast_container()
	_build_summary_modal()
	_build_info_panels()


# ==================== TOP BAR ====================

func _build_top_bar() -> void:
	var top_bg := Panel.new()
	top_bg.anchors_preset = Control.PRESET_TOP_WIDE
	top_bg.offset_bottom = 52
	var bg_style := UITheme.make_panel_style(
		Color(0.06, 0.05, 0.08, 0.92),
		Color(0.30, 0.26, 0.18, 0.4),
		0, 0, 0
	)
	bg_style.border_width_bottom = 1
	bg_style.border_color = Color(0.30, 0.26, 0.18, 0.35)
	top_bg.add_theme_stylebox_override("panel", bg_style)
	add_child(top_bg)

	var top_bar := HBoxContainer.new()
	top_bar.offset_left = 16
	top_bar.offset_top = 8
	top_bar.offset_right = -16
	top_bar.add_theme_constant_override("separation", 8)
	add_child(top_bar)

	# --- State group ---
	var state_group := HBoxContainer.new()
	state_group.add_theme_constant_override("separation", 16)
	top_bar.add_child(state_group)

	year_label = Label.new()
	year_label.text = "Year 0"
	UITheme.style_label_header(year_label, 28)
	state_group.add_child(year_label)

	var stability_box := VBoxContainer.new()
	stability_box.add_theme_constant_override("separation", 2)
	state_group.add_child(stability_box)

	stability_label = Label.new()
	stability_label.text = "Stability: 50"
	UITheme.style_label_body(stability_label, 13, UITheme.PARCHMENT_DIM)
	stability_box.add_child(stability_label)

	stability_bar = ProgressBar.new()
	stability_bar.min_value = 0
	stability_bar.max_value = 100
	stability_bar.value = 50
	stability_bar.custom_minimum_size = Vector2(160, 12)
	stability_bar.show_percentage = false
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.12, 0.10, 0.08, 0.6)
	bar_bg.set_corner_radius_all(2)
	stability_bar.add_theme_stylebox_override("background", bar_bg)
	stability_box.add_child(stability_bar)

	_add_separator(top_bar)

	# --- Economy group ---
	var econ_group := HBoxContainer.new()
	econ_group.add_theme_constant_override("separation", 16)
	top_bar.add_child(econ_group)

	food_label = Label.new()
	food_label.text = "Food: 0"
	UITheme.style_label_stat(food_label, 15, UITheme.COLOR_FOOD)
	econ_group.add_child(food_label)

	production_label = Label.new()
	production_label.text = "Production: 0"
	UITheme.style_label_stat(production_label, 15, UITheme.COLOR_PRODUCTION)
	econ_group.add_child(production_label)

	_add_separator(top_bar)

	# --- Military ---
	military_label = Label.new()
	military_label.text = "Military: 0"
	UITheme.style_label_stat(military_label, 15, UITheme.COLOR_MILITARY)
	top_bar.add_child(military_label)

	_add_separator(top_bar)

	# --- Empire info group ---
	var empire_group := HBoxContainer.new()
	empire_group.add_theme_constant_override("separation", 12)
	top_bar.add_child(empire_group)

	era_label = Label.new()
	era_label.text = "Prehistoric"
	UITheme.style_label_stat(era_label, 14, Color(0.65, 0.55, 0.85))
	empire_group.add_child(era_label)

	governance_label = Label.new()
	governance_label.text = "Tribal"
	UITheme.style_label_stat(governance_label, 14, Color(0.55, 0.75, 0.65))
	empire_group.add_child(governance_label)

	regions_label = Label.new()
	regions_label.text = "0 regions"
	UITheme.style_label_stat(regions_label, 14, UITheme.PARCHMENT_DIM)
	empire_group.add_child(regions_label)

	_add_separator(top_bar)

	# --- Time group ---
	var time_group := HBoxContainer.new()
	time_group.add_theme_constant_override("separation", 6)
	top_bar.add_child(time_group)

	advance_button = Button.new()
	advance_button.text = "Next Year"
	advance_button.pressed.connect(_on_advance_pressed)
	UITheme.style_button(advance_button)
	time_group.add_child(advance_button)

	play_btn = Button.new()
	play_btn.text = "Play"
	play_btn.pressed.connect(_toggle_auto_play)
	UITheme.style_button(play_btn)
	time_group.add_child(play_btn)

	speed_5x_button = Button.new()
	speed_5x_button.text = "+5"
	speed_5x_button.pressed.connect(func() -> void: _start_fast_forward(5))
	UITheme.style_button(speed_5x_button)
	time_group.add_child(speed_5x_button)

	speed_10x_button = Button.new()
	speed_10x_button.text = "+10"
	speed_10x_button.pressed.connect(func() -> void: _start_fast_forward(10))
	UITheme.style_button(speed_10x_button)
	time_group.add_child(speed_10x_button)

	speed_label = Label.new()
	speed_label.text = ""
	UITheme.style_label_body(speed_label, 13, UITheme.PARCHMENT_DIM)
	time_group.add_child(speed_label)

	playing_label = Label.new()
	playing_label.text = ""
	UITheme.style_label_stat(playing_label, 13, UITheme.COLOR_FOOD)
	time_group.add_child(playing_label)

	_add_separator(top_bar)

	# --- Zoom group ---
	var zoom_group := HBoxContainer.new()
	zoom_group.add_theme_constant_override("separation", 4)
	top_bar.add_child(zoom_group)

	zoom_out_btn = Button.new()
	zoom_out_btn.text = "-"
	zoom_out_btn.custom_minimum_size = Vector2(30, 0)
	zoom_out_btn.pressed.connect(func() -> void: _zoom_camera(-0.1))
	UITheme.style_button(zoom_out_btn)
	zoom_group.add_child(zoom_out_btn)

	var zoom_label := Label.new()
	zoom_label.text = "Zoom"
	UITheme.style_label_body(zoom_label, 13, UITheme.PARCHMENT_DIM)
	zoom_group.add_child(zoom_label)

	zoom_in_btn = Button.new()
	zoom_in_btn.text = "+"
	zoom_in_btn.custom_minimum_size = Vector2(30, 0)
	zoom_in_btn.pressed.connect(func() -> void: _zoom_camera(0.1))
	UITheme.style_button(zoom_in_btn)
	zoom_group.add_child(zoom_in_btn)

	_add_separator(top_bar)

	# --- Info panel buttons ---
	var info_group := HBoxContainer.new()
	info_group.add_theme_constant_override("separation", 4)
	top_bar.add_child(info_group)

	var profile_btn := Button.new()
	profile_btn.text = "Profile(C)"
	profile_btn.pressed.connect(func() -> void: EventBus.open_civ_profile.emit(player_civ_id))
	UITheme.style_button(profile_btn)
	info_group.add_child(profile_btn)

	var timeline_btn := Button.new()
	timeline_btn.text = "Timeline(T)"
	timeline_btn.pressed.connect(func() -> void: EventBus.open_timeline.emit())
	UITheme.style_button(timeline_btn)
	info_group.add_child(timeline_btn)


func _add_separator(parent: Control) -> void:
	var sep := VSeparator.new()
	sep.custom_minimum_size = Vector2(2, 32)
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.30, 0.26, 0.18, 0.3)
	sep_style.set_content_margin_all(0)
	sep.add_theme_stylebox_override("separator", sep_style)
	parent.add_child(sep)


# ==================== RESOURCE BAR ====================

func _build_resource_bar() -> void:
	resource_bar_bg = Panel.new()
	resource_bar_bg.anchors_preset = Control.PRESET_TOP_WIDE
	resource_bar_bg.offset_top = 52
	resource_bar_bg.offset_bottom = 78
	var bg_style := UITheme.make_panel_style(
		Color(0.05, 0.04, 0.07, 0.85),
		Color(0.25, 0.22, 0.16, 0.3),
		0, 0, 0
	)
	bg_style.border_width_bottom = 1
	bg_style.border_color = Color(0.25, 0.22, 0.16, 0.25)
	resource_bar_bg.add_theme_stylebox_override("panel", bg_style)
	resource_bar_bg.visible = false
	add_child(resource_bar_bg)

	var bar := HBoxContainer.new()
	bar.offset_left = 16
	bar.offset_top = 55
	bar.offset_right = -16
	bar.add_theme_constant_override("separation", 14)
	add_child(bar)

	var title := Label.new()
	title.text = "Resources:"
	UITheme.style_label_body(title, 12, UITheme.GOLD_DIM)
	bar.add_child(title)

	# Create a label for each resource type (hidden until unlocked)
	for res_type in range(9):
		var lbl := Label.new()
		lbl.text = ""
		lbl.visible = false
		UITheme.style_label_stat(lbl, 12, UITheme.PARCHMENT_DIM)
		bar.add_child(lbl)
		resource_labels[res_type] = lbl


func _update_resource_bar() -> void:
	var civ := GameState.get_civilization(player_civ_id)
	if not civ:
		resource_bar_bg.visible = false
		return

	var has_any := false
	for res_type in range(9):
		var lbl: Label = resource_labels[res_type]
		if not ResourceProduction.is_resource_unlocked(res_type, civ.current_era):
			lbl.visible = false
			continue

		var stockpile: int = civ.resource_stockpiles.get(res_type, 0)
		var production: int = civ.resource_production_log.get(res_type, 0)
		var res_name: String = ResourceProduction.get_resource_name(res_type)

		# Color: green if producing, yellow if low, red if zero
		var color: Color
		if stockpile <= 0 and production <= 0:
			color = Color(0.82, 0.32, 0.30)  # red
		elif stockpile < 5:
			color = Color(0.82, 0.72, 0.28)  # yellow
		else:
			color = Color(0.45, 0.78, 0.42)  # green

		lbl.text = "%s: %d (+%d)" % [res_name, stockpile, production]
		lbl.add_theme_color_override("font_color", color)
		lbl.visible = true
		has_any = true

	resource_bar_bg.visible = has_any


# ==================== OVERLAY STRIP ====================

func _build_overlay_strip() -> void:
	var strip_bg := Panel.new()
	strip_bg.offset_left = 10
	strip_bg.offset_top = 80
	strip_bg.offset_right = 400
	strip_bg.offset_bottom = 108
	var strip_style := UITheme.make_panel_style(
		Color(0.06, 0.05, 0.08, 0.75),
		Color(0.25, 0.22, 0.16, 0.25),
		4, 1, 4
	)
	strip_bg.add_theme_stylebox_override("panel", strip_style)
	add_child(strip_bg)

	var strip := HBoxContainer.new()
	strip.offset_left = 14
	strip.offset_top = 82
	strip.add_theme_constant_override("separation", 2)
	add_child(strip)

	var overlays: Array[Dictionary] = [
		{"name": "Political", "mode": Enums.MapOverlay.POLITICAL},
		{"name": "Terrain", "mode": Enums.MapOverlay.TERRAIN},
		{"name": "Resources", "mode": Enums.MapOverlay.RESOURCES},
		{"name": "Supply", "mode": Enums.MapOverlay.SUPPLY_LINES},
		{"name": "Fronts", "mode": Enums.MapOverlay.ALLIANCES},
	]

	for info in overlays:
		var btn := Button.new()
		btn.text = info["name"]
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(72, 22)
		UITheme.style_button(btn)
		btn.add_theme_font_size_override("font_size", 11)
		var mode: int = info["mode"]
		if mode == Enums.MapOverlay.POLITICAL:
			btn.button_pressed = true
		btn.pressed.connect(_on_overlay_pressed.bind(mode))
		strip.add_child(btn)
		overlay_buttons[mode] = btn


func _on_overlay_pressed(mode: int) -> void:
	for m in overlay_buttons:
		overlay_buttons[m].button_pressed = (m == mode)
	GameState.set_overlay(mode)


const OVERLAY_CYCLE_ORDER: Array[int] = [
	Enums.MapOverlay.POLITICAL,
	Enums.MapOverlay.TERRAIN,
	Enums.MapOverlay.RESOURCES,
	Enums.MapOverlay.SUPPLY_LINES,
	Enums.MapOverlay.ALLIANCES,
]


func _cycle_overlay() -> void:
	## Cycle to the next map overlay mode (Tab key).
	var current := GameState.current_overlay
	var idx := OVERLAY_CYCLE_ORDER.find(current)
	var next_idx := (idx + 1) % OVERLAY_CYCLE_ORDER.size()
	var next_mode := OVERLAY_CYCLE_ORDER[next_idx]
	_on_overlay_pressed(next_mode)


# ==================== EVENT LOG ====================

func _build_event_log() -> void:
	var log_panel := PanelContainer.new()
	log_panel.offset_left = 10
	log_panel.offset_top = -240
	log_panel.offset_right = 390
	log_panel.offset_bottom = -10
	log_panel.anchors_preset = Control.PRESET_BOTTOM_LEFT
	log_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(
		Color(0.05, 0.04, 0.07, 0.88),
		UITheme.PANEL_BORDER,
		5, 1, 10
	))
	add_child(log_panel)

	event_log = RichTextLabel.new()
	event_log.bbcode_enabled = true
	event_log.scroll_following = true
	event_log.fit_content = false
	event_log.add_theme_font_override("normal_font", UITheme.get_body_font())
	event_log.add_theme_font_override("bold_font", UITheme.get_body_bold_font())
	event_log.add_theme_font_size_override("normal_font_size", 13)
	log_panel.add_child(event_log)

	# Title label above the log
	var log_title := Label.new()
	log_title.text = "Chronicle"
	UITheme.style_label_header(log_title, 13)
	log_title.add_theme_color_override("font_color", UITheme.GOLD_DIM)
	log_title.position = Vector2(16, -258)
	log_title.anchors_preset = Control.PRESET_BOTTOM_LEFT
	add_child(log_title)


# ==================== TOAST NOTIFICATIONS ====================

func _build_toast_container() -> void:
	toast_container = VBoxContainer.new()
	toast_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_container.offset_top = 58
	toast_container.offset_left = -180
	toast_container.offset_right = 180
	toast_container.add_theme_constant_override("separation", 4)
	toast_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_container)


func _show_toast(text: String, color: Color) -> void:
	while toast_container.get_child_count() >= 3:
		var oldest := toast_container.get_child(0)
		toast_container.remove_child(oldest)
		oldest.queue_free()

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.08, 0.92)
	style.border_color = color
	style.set_border_width_all(1)
	style.border_width_left = 3
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label_body(lbl, 13, color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lbl)

	toast_container.add_child(panel)

	# Slide in from top then fade out
	panel.modulate.a = 0.0
	panel.position.y = -20
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(panel, "position:y", 0.0, 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_interval(2.5)
	tween.tween_property(panel, "modulate:a", 0.0, 0.4)
	tween.tween_callback(panel.queue_free)


# ==================== SUMMARY MODAL ====================

func _build_summary_modal() -> void:
	# Fullscreen container so anchors resolve correctly
	summary_bg = ColorRect.new()
	summary_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	summary_bg.color = Color(0, 0, 0, 0.60)
	summary_bg.visible = false
	summary_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(summary_bg)

	# Center container to hold the panel
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary_bg.add_child(center)

	summary_panel = PanelContainer.new()
	summary_panel.custom_minimum_size = Vector2(440, 0)
	summary_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(
		Color(0.08, 0.07, 0.10, 0.96),
		UITheme.PANEL_BORDER,
		8, 1, 22
	))
	center.add_child(summary_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	summary_panel.add_child(vbox)

	summary_year_label = Label.new()
	summary_year_label.text = "Years 0 to 0"
	UITheme.style_label_header(summary_year_label, 22)
	summary_year_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(summary_year_label)

	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = UITheme.PANEL_BORDER
	sep_style.set_content_margin_all(0)
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	summary_content = RichTextLabel.new()
	summary_content.bbcode_enabled = true
	summary_content.custom_minimum_size = Vector2(380, 320)
	summary_content.add_theme_font_override("normal_font", UITheme.get_body_font())
	summary_content.add_theme_font_override("bold_font", UITheme.get_body_bold_font())
	summary_content.add_theme_font_size_override("normal_font_size", 15)
	summary_content.fit_content = true
	vbox.add_child(summary_content)

	summary_continue_btn = Button.new()
	summary_continue_btn.text = "Continue"
	summary_continue_btn.custom_minimum_size = Vector2(140, 34)
	summary_continue_btn.pressed.connect(_dismiss_summary)
	UITheme.style_button(summary_continue_btn)
	summary_continue_btn.add_theme_font_size_override("font_size", 15)
	vbox.add_child(summary_continue_btn)


func _capture_pre_state() -> void:
	var civ: CivilizationData = GameState.get_civilization(player_civ_id)
	if not civ:
		return
	ff_pre_state = {
		"year": GameState.current_year,
		"stability": civ.stability,
		"population": civ.total_population,
		"food": civ.food_stockpile,
		"production": civ.production_stockpile,
		"military": civ.military_strength,
		"territories": GameState.get_regions_by_owner(player_civ_id).size(),
	}
	ff_counters = {
		"wars": 0, "heroes": 0, "techs": 0,
		"battles": 0, "collapses": 0, "golden_ages": 0,
		"expansions": 0, "shortages": 0,
	}


func _show_summary() -> void:
	var civ: CivilizationData = GameState.get_civilization(player_civ_id)
	if not civ or ff_pre_state.is_empty():
		return

	var start_year: int = ff_pre_state["year"]
	var end_year: int = GameState.current_year
	summary_year_label.text = "Years %d - %d" % [start_year, end_year]

	var lines: Array[String] = []

	var delta_stab: float = civ.stability - float(ff_pre_state["stability"])
	var delta_pop: int = civ.total_population - int(ff_pre_state["population"])
	var delta_food: int = civ.food_stockpile - int(ff_pre_state["food"])
	var delta_prod: int = civ.production_stockpile - int(ff_pre_state["production"])
	var delta_mil: float = civ.military_strength - float(ff_pre_state["military"])
	var curr_terr: int = GameState.get_regions_by_owner(player_civ_id).size()
	var delta_terr: int = curr_terr - int(ff_pre_state["territories"])

	lines.append("[b]State Changes[/b]")
	lines.append(_fmt_delta("Stability", "%.0f" % ff_pre_state["stability"], "%.0f" % civ.stability, delta_stab))
	lines.append(_fmt_delta("Population", _fmt_pop(int(ff_pre_state["population"])), _fmt_pop(civ.total_population), delta_pop))
	lines.append(_fmt_delta("Food", str(ff_pre_state["food"]), str(civ.food_stockpile), delta_food))
	lines.append(_fmt_delta("Production", str(ff_pre_state["production"]), str(civ.production_stockpile), delta_prod))
	lines.append(_fmt_delta("Military", "%.0f" % ff_pre_state["military"], "%.0f" % civ.military_strength, delta_mil))
	lines.append(_fmt_delta("Territories", str(ff_pre_state["territories"]), str(curr_terr), delta_terr))

	lines.append("")
	lines.append("[b]Events[/b]")

	var has_events := false
	if int(ff_counters["wars"]) > 0:
		lines.append("[color=#e55]%d war(s) declared[/color]" % ff_counters["wars"])
		has_events = true
	if int(ff_counters["battles"]) > 0:
		lines.append("[color=#da8]%d battle(s) fought[/color]" % ff_counters["battles"])
		has_events = true
	if int(ff_counters["heroes"]) > 0:
		lines.append("[color=#5ce]%d hero(es) emerged[/color]" % ff_counters["heroes"])
		has_events = true
	if int(ff_counters["golden_ages"]) > 0:
		lines.append("[color=#fd5]%d golden age(s) began[/color]" % ff_counters["golden_ages"])
		has_events = true
	if int(ff_counters["techs"]) > 0:
		lines.append("[color=#5e5]%d technology(ies) discovered[/color]" % ff_counters["techs"])
		has_events = true
	if int(ff_counters["collapses"]) > 0:
		lines.append("[color=#f33]%d civilization(s) collapsed[/color]" % ff_counters["collapses"])
		has_events = true
	if int(ff_counters["expansions"]) > 0:
		lines.append("[color=#8c8]%d expansion(s)[/color]" % ff_counters["expansions"])
		has_events = true
	if int(ff_counters["shortages"]) > 0:
		lines.append("[color=#e85]%d shortage(s) detected[/color]" % ff_counters["shortages"])
		has_events = true
	if not has_events:
		lines.append("[color=#888]No major events[/color]")

	summary_content.clear()
	summary_content.append_text("\n".join(lines))
	summary_bg.visible = true


func _fmt_delta(label_text: String, before: String, after: String, delta: Variant) -> String:
	var d: float = float(delta)
	var color := "#5e5" if d > 0 else ("#e55" if d < 0 else "#888")
	var sign := "+" if d > 0 else ""
	if delta is float:
		return "  %s: %s -> %s  [color=%s](%s%.0f)[/color]" % [label_text, before, after, color, sign, d]
	return "  %s: %s -> %s  [color=%s](%s%d)[/color]" % [label_text, before, after, color, sign, int(delta)]


func _fmt_pop(n: int) -> String:
	if n >= 1000000:
		return "%.1fM" % (float(n) / 1000000.0)
	elif n >= 1000:
		return "%.1fK" % (float(n) / 1000.0)
	return str(n)


func _dismiss_summary() -> void:
	summary_bg.visible = false


# ==================== SIGNALS ====================

func _connect_signals() -> void:
	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.stability_changed.connect(_on_stability_changed)
	EventBus.war_declared.connect(_on_war_declared)
	EventBus.hero_spawned.connect(_on_hero_spawned)
	EventBus.hero_died.connect(_on_hero_died)
	EventBus.golden_age_started.connect(_on_golden_age_started)
	EventBus.golden_age_ended.connect(_on_golden_age_ended)
	EventBus.technology_emerged.connect(_on_tech_emerged)
	EventBus.civilization_collapsed.connect(_on_civ_collapsed)
	EventBus.battle_resolved.connect(_on_battle_resolved)
	EventBus.food_shortage.connect(_on_food_shortage)
	EventBus.production_shortage.connect(_on_production_shortage)
	EventBus.ai_decision_made.connect(_on_ai_decision)
	EventBus.infrastructure_upgraded.connect(_on_infrastructure_upgraded)
	EventBus.peace_declared.connect(_on_peace_declared)
	EventBus.development_tier_changed.connect(_on_dev_tier_changed)
	EventBus.resource_deposit_depleted.connect(_on_deposit_depleted)
	EventBus.resource_maintenance_failure.connect(_on_maintenance_failure)


func _update_display() -> void:
	var civ := GameState.get_civilization(player_civ_id)
	if not civ:
		return

	year_label.text = "Year %d" % GameState.current_year
	stability_label.text = "Stability: %.0f%%" % civ.stability
	# Smooth stability bar animation
	var bar_tween := create_tween()
	bar_tween.tween_property(stability_bar, "value", civ.stability, 0.3)
	_update_stability_color(civ.stability)
	food_label.text = "Food: %d" % civ.food_stockpile
	production_label.text = "Prod: %d" % civ.production_stockpile
	military_label.text = "Army: %.0f" % civ.military_strength

	# Era and governance with badge styling
	var era_names := ["Prehistoric", "Classical", "Industrial", "Future"]
	var era_colors := [
		Color(0.4, 0.35, 0.25, 0.7),
		Color(0.35, 0.30, 0.55, 0.7),
		Color(0.30, 0.45, 0.30, 0.7),
		Color(0.25, 0.38, 0.55, 0.7),
	]
	var era_idx := clampi(civ.current_era, 0, 3)
	era_label.text = " %s " % era_names[era_idx]
	var era_style := StyleBoxFlat.new()
	era_style.bg_color = era_colors[era_idx]
	era_style.set_corner_radius_all(3)
	era_style.set_content_margin_all(3)
	era_label.add_theme_stylebox_override("normal", era_style)
	governance_label.text = GovernanceSimulation.get_tier_name(civ.governance_tier)
	regions_label.text = "%d regions" % GameState.get_regions_by_owner(civ.id).size()

	# Resource bar
	_update_resource_bar()


func _update_stability_color(value: float) -> void:
	var fill_style := StyleBoxFlat.new()
	fill_style.set_corner_radius_all(2)
	if value > 70:
		fill_style.bg_color = UITheme.COLOR_STABILITY_HIGH
	elif value > 30:
		fill_style.bg_color = UITheme.COLOR_STABILITY_MID
	else:
		fill_style.bg_color = UITheme.COLOR_STABILITY_LOW
	stability_bar.add_theme_stylebox_override("fill", fill_style)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_autoplay"):
		_toggle_auto_play()
	elif event.is_action_pressed("advance_year"):
		if is_auto_playing:
			_pause_auto_play()
		else:
			_on_advance_pressed()
	elif event.is_action_pressed("speed_normal"):
		if is_auto_playing:
			_set_auto_play_speed(1.2)
		else:
			_on_advance_pressed()
	elif event.is_action_pressed("speed_fast"):
		if is_auto_playing:
			_set_auto_play_speed(0.8)
		else:
			_start_fast_forward(5)
	elif event.is_action_pressed("speed_fastest"):
		if is_auto_playing:
			_set_auto_play_speed(0.3)
		else:
			_start_fast_forward(10)
	elif event.is_action_pressed("cycle_overlay"):
		_cycle_overlay()
	elif event.is_action_pressed("open_civ_profile"):
		EventBus.open_civ_profile.emit(player_civ_id)
	elif event.is_action_pressed("open_timeline"):
		EventBus.open_timeline.emit()
	if event is InputEventKey and event.pressed and summary_bg.visible:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_ENTER:
			_dismiss_summary()
			get_viewport().set_input_as_handled()


func _zoom_camera(amount: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera:
		camera.target_zoom = clampf(camera.target_zoom + amount, 0.2, 4.0)
		camera.zoom = Vector2(camera.target_zoom, camera.target_zoom)
		EventBus.zoom_changed.emit(camera.target_zoom)


func _on_advance_pressed() -> void:
	if TurnManager.is_processing or summary_bg.visible:
		return
	TurnManager.advance_year()


# ==================== AUTO-PLAY ====================

func _toggle_auto_play() -> void:
	if is_auto_playing:
		_pause_auto_play()
	else:
		_start_auto_play()


func _start_auto_play() -> void:
	if summary_bg.visible or is_fast_forwarding:
		return
	is_auto_playing = true
	play_btn.text = "Pause"
	playing_label.text = "PLAYING"
	var timer: Timer = get_node("AutoPlayTimer")
	timer.wait_time = auto_play_interval
	timer.start()
	_pulse_playing_label()


func _pause_auto_play() -> void:
	is_auto_playing = false
	play_btn.text = "Play"
	playing_label.text = ""
	var timer: Timer = get_node("AutoPlayTimer")
	timer.stop()


func _on_auto_play_timeout() -> void:
	if TurnManager.is_processing or summary_bg.visible:
		return
	TurnManager.advance_year()


func _set_auto_play_speed(interval: float) -> void:
	auto_play_interval = interval
	if is_auto_playing:
		var timer: Timer = get_node("AutoPlayTimer")
		timer.wait_time = interval
		timer.start()
	var dots := ""
	if interval >= 1.0:
		dots = ">"
	elif interval >= 0.5:
		dots = ">>"
	else:
		dots = ">>>"
	speed_label.text = dots


func _pulse_playing_label() -> void:
	if not is_auto_playing:
		return
	var tween := create_tween()
	tween.tween_property(playing_label, "modulate:a", 0.3, 0.6)
	tween.tween_property(playing_label, "modulate:a", 1.0, 0.6)
	tween.tween_callback(_pulse_playing_label)


# ==================== FAST FORWARD ====================

func _start_fast_forward(years: int) -> void:
	if TurnManager.is_processing or summary_bg.visible:
		return
	_capture_pre_state()
	is_fast_forwarding = true
	ff_should_pause = false
	fast_forward_target = years
	fast_forward_count = 0
	speed_label.text = "Running %d years..." % years
	_fast_forward_step()


func _fast_forward_step() -> void:
	if fast_forward_count >= fast_forward_target:
		_end_fast_forward()
		return

	TurnManager.advance_year()
	fast_forward_count += 1

	if ff_should_pause:
		_end_fast_forward()
		return

	if fast_forward_count < fast_forward_target:
		call_deferred("_fast_forward_step")
	else:
		_end_fast_forward()


func _end_fast_forward() -> void:
	speed_label.text = ""
	is_fast_forwarding = false
	ff_should_pause = false
	_show_summary()


# ==================== EVENT HANDLERS ====================

func _on_turn_ended(_year: int) -> void:
	_update_display()


func _on_stability_changed(civ_id: int, _old: float, _new: float) -> void:
	if civ_id == player_civ_id:
		_update_display()


func _log(text: String) -> void:
	event_log.append_text("[b][color=#888]Y%d[/color][/b] %s\n" % [GameState.current_year, text])


func _on_war_declared(attacker_id: int, defender_id: int) -> void:
	if is_fast_forwarding:
		ff_counters["wars"] += 1
		if attacker_id == player_civ_id or defender_id == player_civ_id:
			ff_should_pause = true
	var a := GameState.get_civilization(attacker_id)
	var d := GameState.get_civilization(defender_id)
	if a and d:
		_log("[color=#e55][WAR] %s declares war on %s[/color]" % [a.civ_name, d.civ_name])
		if is_auto_playing:
			_show_toast("%s declares war on %s" % [a.civ_name, d.civ_name], Color(0.9, 0.3, 0.3))
			if attacker_id == player_civ_id or defender_id == player_civ_id:
				_pause_auto_play()


func _on_hero_spawned(hero_id: int, civ_id: int, _type: Enums.HeroType) -> void:
	if is_fast_forwarding:
		ff_counters["heroes"] += 1
		if civ_id == player_civ_id:
			ff_should_pause = true
	var hero := GameState.get_hero(hero_id)
	var civ := GameState.get_civilization(civ_id)
	if hero and civ:
		_log("[color=#5ce][HERO] %s gains hero %s (%s)[/color]" % [
			civ.civ_name, hero.hero_name, Enums.HeroType.keys()[hero.type]
		])
		if is_auto_playing:
			_show_toast("%s gains hero %s" % [civ.civ_name, hero.hero_name], Color(0.36, 0.80, 0.88))
			if civ_id == player_civ_id:
				_pause_auto_play()


func _on_hero_died(hero_id: int, civ_id: int) -> void:
	if is_fast_forwarding and civ_id == player_civ_id:
		ff_should_pause = true
	var civ := GameState.get_civilization(civ_id)
	if civ:
		_log("[color=#999]A hero of %s has died[/color]" % civ.civ_name)


func _on_golden_age_started(civ_id: int) -> void:
	if is_fast_forwarding:
		ff_counters["golden_ages"] += 1
		if civ_id == player_civ_id:
			ff_should_pause = true
	var civ := GameState.get_civilization(civ_id)
	if civ:
		_log("[color=#fd5][GOLDEN] %s enters a Golden Age[/color]" % civ.civ_name)
		if is_auto_playing:
			_show_toast("%s enters a Golden Age" % civ.civ_name, Color(0.99, 0.84, 0.33))


func _on_golden_age_ended(civ_id: int) -> void:
	if is_fast_forwarding and civ_id == player_civ_id:
		ff_should_pause = true
	var civ := GameState.get_civilization(civ_id)
	if civ:
		_log("[color=#a85]%s Golden Age ended[/color]" % civ.civ_name)


func _on_tech_emerged(civ_id: int, tech_name: String) -> void:
	if is_fast_forwarding:
		ff_counters["techs"] += 1
		if civ_id == player_civ_id:
			ff_should_pause = true
	var civ := GameState.get_civilization(civ_id)
	if civ:
		_log("[color=#5e5][TECH] %s discovers %s[/color]" % [civ.civ_name, tech_name])
		if is_auto_playing:
			_show_toast("%s discovers %s" % [civ.civ_name, tech_name], Color(0.37, 0.88, 0.37))


func _on_civ_collapsed(civ_id: int) -> void:
	if is_fast_forwarding:
		ff_counters["collapses"] += 1
		ff_should_pause = true  # Always pause on any collapse
	var civ := GameState.get_civilization(civ_id)
	if civ:
		_log("[color=#f33][COLLAPSE] %s has COLLAPSED[/color]" % civ.civ_name)
		if is_auto_playing:
			_show_toast("%s has COLLAPSED" % civ.civ_name, Color(0.95, 0.2, 0.2))
			_pause_auto_play()


func _on_battle_resolved(region_id: int, attacker_id: int, _defender_id: int, winner_id: int) -> void:
	if is_fast_forwarding:
		ff_counters["battles"] += 1
	var region := GameState.get_region(region_id)
	var winner := GameState.get_civilization(winner_id)
	if region and winner:
		var result_text := "won" if winner_id == attacker_id else "defended"
		_log("[color=#da8][BATTLE] %s %s battle for %s[/color]" % [winner.civ_name, result_text, region.region_name])
		if is_auto_playing and (attacker_id == player_civ_id or _defender_id == player_civ_id):
			_show_toast("%s %s battle for %s" % [winner.civ_name, result_text, region.region_name], Color(0.85, 0.66, 0.5))


func _on_food_shortage(civ_id: int, stockpile: int) -> void:
	if is_fast_forwarding:
		ff_counters["shortages"] += 1
	var civ := GameState.get_civilization(civ_id)
	if civ:
		_log("[color=#e85]%s: FOOD SHORTAGE (%d)[/color]" % [civ.civ_name, stockpile])


func _on_production_shortage(civ_id: int, stockpile: int) -> void:
	if is_fast_forwarding:
		ff_counters["shortages"] += 1
	var civ := GameState.get_civilization(civ_id)
	if civ:
		_log("[color=#da5]%s: PRODUCTION SHORTAGE (%d)[/color]" % [civ.civ_name, stockpile])


func _on_ai_decision(civ_id: int, decision_type: String, details: Dictionary) -> void:
	if decision_type == "expand":
		if is_fast_forwarding:
			ff_counters["expansions"] += 1
		var civ := GameState.get_civilization(civ_id)
		if civ:
			var cost_text := " (-%d prod)" % details.get("cost", 0) if details.has("cost") else ""
			_log("[color=#8c8][EXPAND] %s expands into %s%s[/color]" % [
				civ.civ_name, details.get("region", "?"), cost_text
			])


func _on_infrastructure_upgraded(civ_id: int, region_name: String, new_level: int) -> void:
	var civ := GameState.get_civilization(civ_id)
	if civ:
		_log("[color=#9ab][INFRA] %s upgrades %s to level %d[/color]" % [
			civ.civ_name, region_name, new_level
		])


func _on_peace_declared(civ_a_id: int, civ_b_id: int) -> void:
	var a := GameState.get_civilization(civ_a_id)
	var b := GameState.get_civilization(civ_b_id)
	if a and b:
		_log("[color=#8b8][PEACE] %s and %s declare peace[/color]" % [a.civ_name, b.civ_name])
		if is_auto_playing:
			_show_toast("%s and %s declare peace" % [a.civ_name, b.civ_name], Color(0.55, 0.73, 0.55))


func _on_dev_tier_changed(region_id: int, civ_id: int, old_tier: String, new_tier: String) -> void:
	var region := GameState.get_region(region_id)
	var civ := GameState.get_civilization(civ_id)
	if region and civ:
		_log("[color=#a8d][DEV] %s: %s -> %s[/color]" % [region.region_name, old_tier, new_tier])


func _on_deposit_depleted(region_id: int, _civ_id: int, resource_name: String) -> void:
	var region := GameState.get_region(region_id)
	if region:
		_log("[color=#e85]%s deposits depleted in %s[/color]" % [resource_name, region.region_name])


func _on_maintenance_failure(civ_id: int, resource_name: String, missing_inputs: int) -> void:
	if civ_id == player_civ_id:
		_log("[color=#da5]Maintenance failure: %s (missing %d input%s)[/color]" % [
			resource_name, missing_inputs, "s" if missing_inputs > 1 else ""
		])


# ==================== INFO PANELS ====================

func _build_info_panels() -> void:
	var turn_summary := TurnSummaryPanel.new()
	add_child(turn_summary)

	var civ_profile := CivProfilePanel.new()
	add_child(civ_profile)

	var timeline := TimelinePanel.new()
	add_child(timeline)
