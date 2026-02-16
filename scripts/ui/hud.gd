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
var player_civ_id: int = 0
var fast_forward_count: int = 0
var fast_forward_target: int = 0
var is_fast_forwarding: bool = false

# Pre-fast-forward state snapshot
var ff_pre_state: Dictionary = {}

# Event counters during fast-forward
var ff_counters: Dictionary = {}


func _ready() -> void:
	_build_ui()
	_connect_signals()
	_update_display()


func _build_ui() -> void:
	_build_top_bar()
	_build_overlay_strip()
	_build_event_log()
	_build_summary_modal()


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
	UITheme.style_label_header(year_label, 22)
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
	stability_bar.custom_minimum_size = Vector2(100, 10)
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

	# --- Time group ---
	var time_group := HBoxContainer.new()
	time_group.add_theme_constant_override("separation", 6)
	top_bar.add_child(time_group)

	advance_button = Button.new()
	advance_button.text = "Next Year"
	advance_button.pressed.connect(_on_advance_pressed)
	UITheme.style_button(advance_button)
	time_group.add_child(advance_button)

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


func _add_separator(parent: Control) -> void:
	var sep := VSeparator.new()
	sep.custom_minimum_size = Vector2(2, 32)
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.30, 0.26, 0.18, 0.3)
	sep_style.set_content_margin_all(0)
	sep.add_theme_stylebox_override("separator", sep_style)
	parent.add_child(sep)


# ==================== OVERLAY STRIP ====================

func _build_overlay_strip() -> void:
	var strip_bg := Panel.new()
	strip_bg.offset_left = 10
	strip_bg.offset_top = 54
	strip_bg.offset_right = 400
	strip_bg.offset_bottom = 82
	var strip_style := UITheme.make_panel_style(
		Color(0.06, 0.05, 0.08, 0.75),
		Color(0.25, 0.22, 0.16, 0.25),
		4, 1, 4
	)
	strip_bg.add_theme_stylebox_override("panel", strip_style)
	add_child(strip_bg)

	var strip := HBoxContainer.new()
	strip.offset_left = 14
	strip.offset_top = 56
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


# ==================== SUMMARY MODAL ====================

func _build_summary_modal() -> void:
	summary_bg = ColorRect.new()
	summary_bg.anchors_preset = Control.PRESET_FULL_RECT
	summary_bg.color = Color(0, 0, 0, 0.60)
	summary_bg.visible = false
	summary_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(summary_bg)

	summary_panel = PanelContainer.new()
	summary_panel.anchors_preset = Control.PRESET_CENTER
	summary_panel.offset_left = -220
	summary_panel.offset_right = 220
	summary_panel.offset_top = -240
	summary_panel.offset_bottom = 240
	summary_panel.visible = false
	summary_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(
		Color(0.08, 0.07, 0.10, 0.96),
		UITheme.PANEL_BORDER,
		8, 1, 22
	))

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

	add_child(summary_panel)


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
	summary_panel.visible = true


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
	summary_panel.visible = false


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


func _update_display() -> void:
	var civ := GameState.get_civilization(player_civ_id)
	if not civ:
		return

	year_label.text = "Year %d" % GameState.current_year
	stability_label.text = "Stability: %.0f" % civ.stability
	stability_bar.value = civ.stability
	_update_stability_color(civ.stability)
	food_label.text = "Food: %d" % civ.food_stockpile
	production_label.text = "Prod: %d" % civ.production_stockpile
	military_label.text = "Army: %.0f" % civ.military_strength


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
	if event.is_action_pressed("advance_year"):
		_on_advance_pressed()
	if event is InputEventKey and event.pressed and summary_bg.visible:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_ENTER:
			_dismiss_summary()
			get_viewport().set_input_as_handled()


func _on_advance_pressed() -> void:
	if TurnManager.is_processing or summary_bg.visible:
		return
	TurnManager.advance_year()


# ==================== FAST FORWARD ====================

func _start_fast_forward(years: int) -> void:
	if TurnManager.is_processing or summary_bg.visible:
		return
	_capture_pre_state()
	is_fast_forwarding = true
	fast_forward_target = years
	fast_forward_count = 0
	speed_label.text = "Running %d years..." % years
	_fast_forward_step()


func _fast_forward_step() -> void:
	if fast_forward_count >= fast_forward_target:
		speed_label.text = ""
		is_fast_forwarding = false
		_show_summary()
		return

	TurnManager.advance_year()
	fast_forward_count += 1

	if fast_forward_count < fast_forward_target:
		call_deferred("_fast_forward_step")
	else:
		speed_label.text = ""
		is_fast_forwarding = false
		_show_summary()


# ==================== EVENT HANDLERS ====================

func _on_turn_ended(_year: int) -> void:
	_update_display()


func _on_stability_changed(civ_id: int, _old: float, _new: float) -> void:
	if civ_id == player_civ_id:
		_update_display()


func _log(text: String) -> void:
	event_log.append_text("[color=#666]Y%d[/color] %s\n" % [GameState.current_year, text])


func _on_war_declared(attacker_id: int, defender_id: int) -> void:
	if is_fast_forwarding:
		ff_counters["wars"] += 1
	var a := GameState.get_civilization(attacker_id)
	var d := GameState.get_civilization(defender_id)
	if a and d:
		_log("[color=#e55]%s declares war on %s[/color]" % [a.civ_name, d.civ_name])


func _on_hero_spawned(hero_id: int, civ_id: int, _type: Enums.HeroType) -> void:
	if is_fast_forwarding:
		ff_counters["heroes"] += 1
	var hero := GameState.get_hero(hero_id)
	var civ := GameState.get_civilization(civ_id)
	if hero and civ:
		_log("[color=#5ce]%s gains hero %s (%s)[/color]" % [
			civ.civ_name, hero.hero_name, Enums.HeroType.keys()[hero.type]
		])


func _on_hero_died(hero_id: int, civ_id: int) -> void:
	var civ := GameState.get_civilization(civ_id)
	if civ:
		_log("[color=#999]A hero of %s has died[/color]" % civ.civ_name)


func _on_golden_age_started(civ_id: int) -> void:
	if is_fast_forwarding:
		ff_counters["golden_ages"] += 1
	var civ := GameState.get_civilization(civ_id)
	if civ:
		_log("[color=#fd5]%s enters a Golden Age[/color]" % civ.civ_name)


func _on_golden_age_ended(civ_id: int) -> void:
	var civ := GameState.get_civilization(civ_id)
	if civ:
		_log("[color=#a85]%s Golden Age ended[/color]" % civ.civ_name)


func _on_tech_emerged(civ_id: int, tech_name: String) -> void:
	if is_fast_forwarding:
		ff_counters["techs"] += 1
	var civ := GameState.get_civilization(civ_id)
	if civ:
		_log("[color=#5e5]%s discovers %s[/color]" % [civ.civ_name, tech_name])


func _on_civ_collapsed(civ_id: int) -> void:
	if is_fast_forwarding:
		ff_counters["collapses"] += 1
	var civ := GameState.get_civilization(civ_id)
	if civ:
		_log("[color=#f33]%s has COLLAPSED[/color]" % civ.civ_name)


func _on_battle_resolved(region_id: int, attacker_id: int, _defender_id: int, winner_id: int) -> void:
	if is_fast_forwarding:
		ff_counters["battles"] += 1
	var region := GameState.get_region(region_id)
	var winner := GameState.get_civilization(winner_id)
	if region and winner:
		var result_text := "won" if winner_id == attacker_id else "defended"
		_log("%s %s battle for %s" % [winner.civ_name, result_text, region.region_name])


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
			_log("[color=#8c8]%s expands into %s%s[/color]" % [
				civ.civ_name, details.get("region", "?"), cost_text
			])


func _on_infrastructure_upgraded(civ_id: int, region_name: String, new_level: int) -> void:
	var civ := GameState.get_civilization(civ_id)
	if civ:
		_log("[color=#9ab]%s upgrades %s to level %d[/color]" % [
			civ.civ_name, region_name, new_level
		])


func _on_peace_declared(civ_a_id: int, civ_b_id: int) -> void:
	var a := GameState.get_civilization(civ_a_id)
	var b := GameState.get_civilization(civ_b_id)
	if a and b:
		_log("[color=#8b8]%s and %s declare peace[/color]" % [a.civ_name, b.civ_name])
