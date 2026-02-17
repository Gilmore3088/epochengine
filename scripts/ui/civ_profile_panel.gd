class_name CivProfilePanel
extends PanelContainer

## Insight-driven civilization profile panel.
## 5 zones: Header/Mood, Stat Cards, Economy, Stability, Insights.
## C key (player civ) or EventBus.open_civ_profile signal.

var _civ_id: int = -1
var _scroll: ScrollContainer
var _content: VBoxContainer


func _ready() -> void:
	_build_shell()
	visible = false
	EventBus.open_civ_profile.connect(_on_open)


func _build_shell() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -280
	offset_right = 280
	offset_top = -320
	offset_bottom = 320
	custom_minimum_size = Vector2(560, 0)

	add_theme_stylebox_override("panel", UITheme.make_panel_style(
		Color(0.07, 0.06, 0.09, 0.95),
		Color(0.50, 0.42, 0.28, 0.6),
		10, 1, 20
	))

	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)


func _on_open(civ_id: int) -> void:
	if visible and _civ_id == civ_id:
		_dismiss()
		return
	_civ_id = civ_id
	_rebuild()
	visible = true


func _rebuild() -> void:
	for child in _content.get_children():
		child.queue_free()

	var civ := GameState.get_civilization(_civ_id)
	if not civ:
		_dismiss()
		return

	var regions: Array[RegionData] = []
	regions.assign(GameState.get_regions_by_owner(_civ_id))
	var econ := _compute_economy(civ, regions)
	var admin_cap := _compute_admin_cap(civ, regions)

	_build_header(civ, regions)
	_add_sep()
	_build_stat_cards(civ, econ)
	_add_sep()
	_build_economy(civ, econ)
	_add_sep()
	_build_stability_section(civ, regions)
	_add_sep()
	_build_insights(civ, regions, econ, admin_cap)

	# Hidden metrics + tech proximity (player civ only)
	if civ.id == GameState.player_civ_id:
		_add_sep()
		_build_tech_proximity(civ)
		_add_sep()
		_build_discoveries(civ)

	var has_diplo: bool = (
		not civ.war_targets.is_empty()
		or not civ.alliance_partners.is_empty()
		or not civ.hero_ids.is_empty()
	)
	if has_diplo:
		_add_sep()
		_build_diplomacy(civ)


# --- Data Computation ---

func _compute_economy(civ: CivilizationData, regions: Array[RegionData]) -> Dictionary:
	var food_produced: int = EconomySimulation.calculate_food_production(civ, regions)
	var food_consumed: int = EconomySimulation.calculate_food_consumption(civ)
	var prod_produced: int = EconomySimulation.calculate_production_output(civ, regions)
	var prod_upkeep: int = EconomySimulation.calculate_military_upkeep(civ)
	return {
		"food_produced": food_produced,
		"food_consumed": food_consumed,
		"food_net": food_produced - food_consumed,
		"prod_produced": prod_produced,
		"prod_upkeep": prod_upkeep,
		"prod_net": prod_produced - prod_upkeep,
	}


func _compute_admin_cap(civ: CivilizationData, regions: Array[RegionData]) -> int:
	var base: int = Constants.ADMIN_CAPACITY_BASE
	var infra_total := 0
	for region in regions:
		infra_total += region.infrastructure_level
	var infra_bonus: int = floori(float(infra_total) * Constants.ADMIN_INFRA_BONUS_PER_LEVEL)
	var stab_bonus: int = floori(civ.stability / Constants.ADMIN_STABILITY_DIVISOR)
	var gov_bonus: int = GovernanceSimulation.get_admin_bonus(civ.governance_tier)
	var dev_bonus := 0
	for region in regions:
		dev_bonus += DevelopmentTierSimulation.get_admin_bonus(region.development_tier)
	return base + infra_bonus + stab_bonus + gov_bonus + dev_bonus


func _compute_drivers(civ: CivilizationData, regions: Array[RegionData]) -> Array[Dictionary]:
	var drivers: Array[Dictionary] = []
	var region_count := regions.size()
	var is_compact: bool = region_count <= Constants.COMPACT_STATE_THRESHOLD

	# Food surplus
	var food_factor: float = clampf(float(civ.food_stockpile) / 20.0, -5.0, 5.0)
	if absf(food_factor) > 0.05:
		var fname: String = "Food surplus" if food_factor > 0 else "Food deficit"
		drivers.append({"name": fname, "value": food_factor})

	# War exhaustion
	if not civ.war_targets.is_empty():
		var exhaust := 0.0
		for target_id in civ.war_targets:
			var dur: int = civ.war_durations.get(target_id, 0)
			exhaust += minf(
				Constants.WAR_EXHAUSTION_BASE + float(dur) * Constants.WAR_EXHAUSTION_ESCALATION,
				Constants.WAR_EXHAUSTION_MAX_PER_FRONT,
			)
		if is_compact:
			exhaust *= (1.0 - Constants.COMPACT_WAR_EXHAUSTION_REDUCTION)
		if exhaust > 0.05:
			drivers.append({"name": "War exhaustion", "value": -exhaust})

	# Overextension
	var admin_cap := _compute_admin_cap(civ, regions)
	var excess: float = maxf(float(region_count - admin_cap), 0.0)
	var overext: float = (excess * excess) / Constants.ADMIN_OVEREXTENSION_DIVISOR
	if overext > 0.05:
		drivers.append({"name": "Overextension (%d/%d)" % [region_count, admin_cap], "value": -overext})

	# Supply strain
	var supply_pen := 0.0
	for region in regions:
		if region.id == civ.capital_region_id:
			continue
		if region.supply_value < Constants.SUPPLY_MIN_THRESHOLD:
			supply_pen += Constants.SUPPLY_CUTOFF_PENALTY_PER_REGION
		elif region.supply_value < 0.5:
			var sev: float = (0.5 - region.supply_value) / 0.3
			supply_pen += Constants.SUPPLY_LOW_PENALTY_PER_REGION * sev
	if supply_pen > 0.05:
		drivers.append({"name": "Supply strain", "value": -supply_pen})

	# Hero (reformer)
	var hero_bonus := 0.0
	for hero_id in civ.hero_ids:
		var hero: HeroData = GameState.get_hero(hero_id)
		if hero and hero.type == Enums.HeroType.REFORMER:
			hero_bonus += hero.get_modifier_value()
	if hero_bonus > 0.05:
		drivers.append({"name": "Reformer hero", "value": hero_bonus})

	# Mean reversion
	var mean_rev: float = (Constants.STABILITY_EQUILIBRIUM - civ.stability) * Constants.STABILITY_MEAN_REVERSION_RATE
	if absf(mean_rev) > 0.05:
		var mrname: String = "Recovery toward 50" if mean_rev > 0 else "Regression toward 50"
		drivers.append({"name": mrname, "value": mean_rev})

	# Resource shortage
	var deficit_thresh := -20
	var shortage := 0.0
	if civ.food_stockpile < deficit_thresh:
		var sev: float = float(-civ.food_stockpile + deficit_thresh) / 80.0
		shortage += lerpf(
			Constants.RESOURCE_SHORTAGE_PENALTY_MIN,
			Constants.RESOURCE_SHORTAGE_PENALTY_MAX,
			clampf(sev, 0.0, 1.0),
		)
	if civ.production_stockpile < deficit_thresh:
		var sev: float = float(-civ.production_stockpile + deficit_thresh) / 80.0
		shortage += lerpf(
			Constants.RESOURCE_SHORTAGE_PENALTY_MIN,
			Constants.RESOURCE_SHORTAGE_PENALTY_MAX,
			clampf(sev, 0.0, 1.0),
		)
	if shortage > 0.05:
		drivers.append({"name": "Resource shortage", "value": -shortage})

	drivers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var av: float = absf(a.get("value", 0.0))
		var bv: float = absf(b.get("value", 0.0))
		return av > bv
	)
	return drivers


# --- Section Builders ---

func _build_header(civ: CivilizationData, regions: Array[RegionData]) -> void:
	var header_bg := PanelContainer.new()
	header_bg.add_theme_stylebox_override("panel", UITheme.make_panel_style(
		_stability_mood_color(civ.stability), Color.TRANSPARENT, 6, 0, 12
	))
	_content.add_child(header_bg)

	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	header_bg.add_child(header)

	var title_row := HBoxContainer.new()
	header.add_child(title_row)

	var name_lbl := Label.new()
	name_lbl.text = civ.civ_name
	UITheme.style_label_header(name_lbl, 24)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(name_lbl)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(32, 28)
	close_btn.pressed.connect(_dismiss)
	UITheme.style_button(close_btn)
	title_row.add_child(close_btn)

	var tags := civ.get_personality_tags()
	var tags_text: String = " | ".join(tags) if not tags.is_empty() else "Balanced"
	var tags_lbl := Label.new()
	tags_lbl.text = tags_text
	UITheme.style_label_body(tags_lbl, 13, Color(0.70, 0.60, 0.85))
	header.add_child(tags_lbl)

	var era_names: Array[String] = ["Prehistoric", "Classical", "Industrial", "Future"]
	var era_idx: int = clampi(civ.current_era, 0, 3)
	var tier_name := GovernanceSimulation.get_tier_name(civ.governance_tier)
	var info_lbl := Label.new()
	info_lbl.text = "%s  |  %s  |  %d regions" % [tier_name, era_names[era_idx], regions.size()]
	UITheme.style_label_body(info_lbl, 14, UITheme.PARCHMENT)
	header.add_child(info_lbl)

	# Strategy selectors (player civ only)
	if civ.id == GameState.player_civ_id:
		var strat_row := HBoxContainer.new()
		strat_row.add_theme_constant_override("separation", 12)
		header.add_child(strat_row)

		# Research focus selector
		var focus_box := VBoxContainer.new()
		focus_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		strat_row.add_child(focus_box)
		var focus_hdr := Label.new()
		focus_hdr.text = "Research Focus"
		UITheme.style_label_body(focus_hdr, 11, UITheme.PARCHMENT_DIM)
		focus_box.add_child(focus_hdr)
		var focus_opt := OptionButton.new()
		focus_opt.focus_mode = Control.FOCUS_NONE
		for fid in Constants.RESEARCH_FOCUS_NAMES:
			focus_opt.add_item(Constants.RESEARCH_FOCUS_NAMES[fid], fid)
		focus_opt.selected = civ.research_focus
		if civ.research_focus_cooldown > 0:
			focus_opt.disabled = true
			focus_hdr.text = "Research Focus (%dyr)" % civ.research_focus_cooldown
		focus_opt.item_selected.connect(func(idx: int) -> void:
			PlayerActions.queue_action({"type": "set_research_focus", "focus": idx})
		)
		UITheme.style_button(focus_opt)
		focus_box.add_child(focus_opt)

		# Spending priority selector
		var spend_box := VBoxContainer.new()
		spend_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		strat_row.add_child(spend_box)
		var spend_hdr := Label.new()
		spend_hdr.text = "Spending Priority"
		UITheme.style_label_body(spend_hdr, 11, UITheme.PARCHMENT_DIM)
		spend_box.add_child(spend_hdr)
		var spend_opt := OptionButton.new()
		spend_opt.focus_mode = Control.FOCUS_NONE
		for pid in Constants.SPENDING_PRIORITY_NAMES:
			spend_opt.add_item(Constants.SPENDING_PRIORITY_NAMES[pid], pid)
		spend_opt.selected = civ.spending_priority
		if civ.spending_priority_cooldown > 0:
			spend_opt.disabled = true
			spend_hdr.text = "Spending Priority (%dyr)" % civ.spending_priority_cooldown
		spend_opt.item_selected.connect(func(idx: int) -> void:
			PlayerActions.queue_action({"type": "set_spending_priority", "priority": idx})
		)
		UITheme.style_button(spend_opt)
		spend_box.add_child(spend_opt)


func _build_stat_cards(civ: CivilizationData, econ: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_content.add_child(row)

	_add_card(row, "Stability", "%.0f%%" % civ.stability, _stability_color(civ.stability))
	_add_card(row, "Population", _fmt_pop(civ.total_population), UITheme.PARCHMENT)
	_add_card(row, "Military", "%.0f" % civ.military_strength, UITheme.COLOR_MILITARY)

	var food_net: int = econ["food_net"]
	var food_clr: Color = UITheme.COLOR_FOOD if food_net >= 0 else UITheme.COLOR_MILITARY
	_add_card(row, "Food", "%+d/yr" % food_net, food_clr)

	var prod_net: int = econ["prod_net"]
	var prod_clr: Color = UITheme.COLOR_PRODUCTION if prod_net >= 0 else UITheme.COLOR_MILITARY
	_add_card(row, "Prod", "%+d/yr" % prod_net, prod_clr)


func _build_economy(civ: CivilizationData, econ: Dictionary) -> void:
	var lbl := Label.new()
	lbl.text = "Economy"
	UITheme.style_label_header(lbl, 16)
	_content.add_child(lbl)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	_content.add_child(cols)

	# Food column
	var food_col := VBoxContainer.new()
	food_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	food_col.add_theme_constant_override("separation", 2)
	cols.add_child(food_col)

	var fh := Label.new()
	fh.text = "Food"
	UITheme.style_label_stat(fh, 14, UITheme.COLOR_FOOD)
	food_col.add_child(fh)

	var fp: int = econ["food_produced"]
	var fc: int = econ["food_consumed"]
	var fn: int = econ["food_net"]
	_add_econ_row(food_col, "Produced", str(fp), UITheme.PARCHMENT)
	_add_econ_row(food_col, "Consumed", "-%d" % fc, Color(0.75, 0.55, 0.35))
	var fn_clr: Color = UITheme.COLOR_FOOD if fn >= 0 else UITheme.COLOR_MILITARY
	_add_econ_row(food_col, "Net", "%+d/yr" % fn, fn_clr)
	_add_econ_row(food_col, "Stockpile", str(civ.food_stockpile), UITheme.PARCHMENT_DIM)

	# Production column
	var prod_col := VBoxContainer.new()
	prod_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prod_col.add_theme_constant_override("separation", 2)
	cols.add_child(prod_col)

	var ph := Label.new()
	ph.text = "Production"
	UITheme.style_label_stat(ph, 14, UITheme.COLOR_PRODUCTION)
	prod_col.add_child(ph)

	var pp: int = econ["prod_produced"]
	var pu: int = econ["prod_upkeep"]
	var pn: int = econ["prod_net"]
	_add_econ_row(prod_col, "Produced", str(pp), UITheme.PARCHMENT)
	_add_econ_row(prod_col, "Military upkeep", "-%d" % pu, Color(0.75, 0.55, 0.35))
	var pn_clr: Color = UITheme.COLOR_PRODUCTION if pn >= 0 else UITheme.COLOR_MILITARY
	_add_econ_row(prod_col, "Net", "%+d/yr" % pn, pn_clr)
	_add_econ_row(prod_col, "Stockpile", str(civ.production_stockpile), UITheme.PARCHMENT_DIM)


func _build_stability_section(civ: CivilizationData, regions: Array[RegionData]) -> void:
	var lbl := Label.new()
	lbl.text = "Stability"
	UITheme.style_label_header(lbl, 16)
	_content.add_child(lbl)

	_build_trend_chart()

	var drv_lbl := Label.new()
	drv_lbl.text = "Current Drivers"
	UITheme.style_label_body(drv_lbl, 12, UITheme.PARCHMENT_DIM)
	_content.add_child(drv_lbl)

	var drivers := _compute_drivers(civ, regions)
	var driver_box := VBoxContainer.new()
	driver_box.add_theme_constant_override("separation", 3)
	_content.add_child(driver_box)

	for d in drivers:
		var dname: String = d.get("name", "")
		var dval: float = d.get("value", 0.0)
		_add_driver_row(driver_box, dname, dval)

	if drivers.is_empty():
		var none := Label.new()
		none.text = "Stable equilibrium"
		UITheme.style_label_body(none, 12, UITheme.PARCHMENT_DIM)
		driver_box.add_child(none)


func _build_trend_chart() -> void:
	var trend := History.get_stability_trend(_civ_id, 20)
	if trend.is_empty():
		var no_data := Label.new()
		no_data.text = "No trend data yet"
		UITheme.style_label_body(no_data, 12, UITheme.PARCHMENT_DIM)
		_content.add_child(no_data)
		return

	var chart := HBoxContainer.new()
	chart.add_theme_constant_override("separation", 2)
	chart.custom_minimum_size = Vector2(0, 36)
	_content.add_child(chart)

	for entry in trend:
		var v: float = entry.get("value", 50.0)
		var bar_h: float = maxf(v / 100.0 * 32.0, 2.0)

		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(0, 36)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chart.add_child(col)

		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(spacer)

		var bar := ColorRect.new()
		bar.custom_minimum_size = Vector2(0, bar_h)
		bar.color = _stability_color(v)
		col.add_child(bar)


func _build_insights(
	civ: CivilizationData, regions: Array[RegionData],
	econ: Dictionary, admin_cap: int,
) -> void:
	var region_count := regions.size()
	var food_net: int = econ["food_net"]
	var prod_net: int = econ["prod_net"]

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	_content.add_child(cols)

	# Pressures
	var press_col := VBoxContainer.new()
	press_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	press_col.add_theme_constant_override("separation", 4)
	cols.add_child(press_col)

	var press_hdr := Label.new()
	press_hdr.text = "Pressures"
	UITheme.style_label_stat(press_hdr, 14, Color(0.82, 0.32, 0.30))
	press_col.add_child(press_hdr)

	var pressures: Array[String] = []
	if food_net < 0:
		pressures.append("Food deficit: %+d/yr" % food_net)
	if prod_net < 0:
		pressures.append("Prod deficit: %+d/yr" % prod_net)
	if region_count > admin_cap:
		pressures.append("Overextended: %d/%d" % [region_count, admin_cap])

	var cutoff := 0
	var low_supply := 0
	for region in regions:
		if region.id == civ.capital_region_id:
			continue
		if region.supply_value < Constants.SUPPLY_MIN_THRESHOLD:
			cutoff += 1
		elif region.supply_value < 0.5:
			low_supply += 1
	if cutoff > 0:
		pressures.append("%d regions cut off" % cutoff)
	elif low_supply > 0:
		pressures.append("%d regions low supply" % low_supply)

	for target_id in civ.war_targets:
		var target := GameState.get_civilization(target_id)
		if target:
			var dur: int = civ.war_durations.get(target_id, 0)
			pressures.append("War: %s (%dyr)" % [target.civ_name, dur])

	if pressures.is_empty():
		_add_insight_line(press_col, "None", UITheme.PARCHMENT_DIM)
	else:
		for p in pressures:
			_add_insight_line(press_col, p, Color(0.82, 0.45, 0.35))

	# Opportunities
	var opp_col := VBoxContainer.new()
	opp_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opp_col.add_theme_constant_override("separation", 4)
	cols.add_child(opp_col)

	var opp_hdr := Label.new()
	opp_hdr.text = "Opportunities"
	UITheme.style_label_stat(opp_hdr, 14, Color(0.45, 0.78, 0.42))
	opp_col.add_child(opp_hdr)

	var opps: Array[String] = []
	if civ.can_enter_golden_age():
		opps.append("Golden Age ready!")
	elif civ.stability > 70.0 and civ.golden_age_cooldown <= 0:
		opps.append("Nearing Golden Age")

	if region_count <= Constants.COMPACT_STATE_THRESHOLD:
		opps.append("Compact: +25% defense")

	for hero_id in civ.hero_ids:
		var hero: HeroData = GameState.get_hero(hero_id)
		if hero:
			var tname: String = Enums.HeroType.keys()[hero.type]
			opps.append("Hero: %s (%s)" % [hero.hero_name, tname])

	for ally_id in civ.alliance_partners:
		var ally := GameState.get_civilization(ally_id)
		if ally:
			opps.append("Allied: %s" % ally.civ_name)

	if region_count < admin_cap:
		opps.append("Admin headroom: +%d" % (admin_cap - region_count))

	if opps.is_empty():
		_add_insight_line(opp_col, "None", UITheme.PARCHMENT_DIM)
	else:
		for o in opps:
			_add_insight_line(opp_col, o, Color(0.50, 0.78, 0.45))


func _build_tech_proximity(civ: CivilizationData) -> void:
	var lbl := Label.new()
	lbl.text = "Research Progress"
	UITheme.style_label_header(lbl, 16)
	_content.add_child(lbl)

	# Hidden metrics display
	var metrics_row := HBoxContainer.new()
	metrics_row.add_theme_constant_override("separation", 4)
	_content.add_child(metrics_row)

	var proximity := TechEmergence.get_next_tech_proximity(civ)
	var metric_data := [
		{"name": "Kn", "value": civ.knowledge},
		{"name": "En", "value": civ.energy},
		{"name": "So", "value": civ.social_coordination},
		{"name": "Ec", "value": civ.economic_surplus},
		{"name": "Mi", "value": civ.military_pressure},
	]
	var metric_keys := ["Knowledge", "Energy", "Social", "Economic", "Military"]

	for i in range(metric_data.size()):
		var md: Dictionary = metric_data[i]
		var color := _metric_color(md["value"], metric_keys[i], proximity)
		_add_card(metrics_row, md["name"], "%.0f" % md["value"], color)

	# "Discovery brewing" label
	var any_brewing := false
	for entry in proximity:
		if entry["all_met"]:
			any_brewing = true
			break

	if any_brewing:
		var brew_lbl := Label.new()
		brew_lbl.text = "A discovery is possible..."
		UITheme.style_label_body(brew_lbl, 13, Color(0.45, 0.78, 0.42))
		_content.add_child(brew_lbl)

	# Show closest undiscovered techs (top 3, without revealing names — show gap count)
	var shown := 0
	var hint_box := VBoxContainer.new()
	hint_box.add_theme_constant_override("separation", 2)
	_content.add_child(hint_box)
	for entry in proximity:
		if shown >= 3:
			break
		var gaps: Array = entry["gaps"]
		if entry["all_met"]:
			_add_insight_line(hint_box, "??? — Thresholds met, awaiting emergence", Color(0.45, 0.78, 0.42))
		elif gaps.size() <= 2:
			var gap_parts: Array[String] = []
			for g in gaps:
				gap_parts.append("%s: %.0f/%.0f" % [g["metric"], g["current"], g["needed"]])
			_add_insight_line(hint_box, "??? — Need: %s" % ", ".join(gap_parts), Color(0.82, 0.72, 0.28))
		else:
			continue
		shown += 1

	# Golden age proximity
	if not civ.is_in_golden_age() and civ.golden_age_cooldown <= 0:
		if civ.stability >= 60.0:
			var ga_lbl := Label.new()
			ga_lbl.text = "Golden Age: Stability %.0f / %.0f" % [
				civ.stability, Constants.GOLDEN_AGE_STABILITY_THRESHOLD]
			var ga_color: Color
			if civ.stability >= Constants.GOLDEN_AGE_STABILITY_THRESHOLD:
				ga_color = Color(0.45, 0.78, 0.42)
			else:
				ga_color = Color(0.82, 0.72, 0.28)
			UITheme.style_label_body(ga_lbl, 13, ga_color)
			_content.add_child(ga_lbl)
	elif civ.is_in_golden_age():
		var ga_lbl := Label.new()
		ga_lbl.text = "Golden Age: %d years remaining" % civ.golden_age_years_remaining
		UITheme.style_label_body(ga_lbl, 13, Color(0.90, 0.80, 0.20))
		_content.add_child(ga_lbl)


func _build_discoveries(civ: CivilizationData) -> void:
	var hdr := Label.new()
	hdr.text = "Discoveries"
	UITheme.style_label_header(hdr, 16)
	_content.add_child(hdr)

	var count_lbl := Label.new()
	count_lbl.text = "%d / %d discovered" % [civ.technologies.size(), TechEmergence.TECH_TABLE.size()]
	UITheme.style_label_body(count_lbl, 12, UITheme.PARCHMENT_DIM)
	_content.add_child(count_lbl)

	var grid := VBoxContainer.new()
	grid.add_theme_constant_override("separation", 2)
	_content.add_child(grid)

	for tech in TechEmergence.TECH_TABLE:
		var tech_name: String = tech["name"]
		var discovered := civ.technologies.has(tech_name)
		var lbl := Label.new()
		if discovered:
			lbl.text = "  %s" % tech_name
			UITheme.style_label_body(lbl, 12, Color(0.6, 0.85, 0.5))
		else:
			lbl.text = "  ???"
			UITheme.style_label_body(lbl, 12, Color(0.4, 0.38, 0.35))
		grid.add_child(lbl)


func _metric_color(value: float, metric_key: String, proximity: Array[Dictionary]) -> Color:
	# Green if meets any undiscovered tech threshold, yellow if within 15, gray otherwise
	for entry in proximity:
		if entry["all_met"]:
			continue
		for g in entry["gaps"]:
			if g["metric"] == metric_key:
				if value >= g["needed"]:
					return Color(0.45, 0.78, 0.42)  # green — met
				elif g["needed"] - value <= 15.0:
					return Color(0.82, 0.72, 0.28)  # gold — close
	# Check if this metric is met for all undiscovered techs that need it
	var any_need := false
	for entry in proximity:
		for g in entry["gaps"]:
			if g["metric"] == metric_key:
				any_need = true
	if not any_need and not proximity.is_empty():
		return Color(0.45, 0.78, 0.42)  # green — all thresholds met for this metric
	return UITheme.PARCHMENT_DIM  # gray — far


func _build_diplomacy(civ: CivilizationData) -> void:
	var lbl := Label.new()
	lbl.text = "Diplomacy"
	UITheme.style_label_header(lbl, 16)
	_content.add_child(lbl)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	_content.add_child(box)

	for target_id in civ.war_targets:
		var target := GameState.get_civilization(target_id)
		if target:
			var dur: int = civ.war_durations.get(target_id, 0)
			var line := Label.new()
			line.text = "AT WAR with %s (%dyr)" % [target.civ_name, dur]
			UITheme.style_label_body(line, 13, Color(0.9, 0.3, 0.3))
			box.add_child(line)

	for ally_id in civ.alliance_partners:
		var ally := GameState.get_civilization(ally_id)
		if ally:
			var line := Label.new()
			line.text = "Allied with %s" % ally.civ_name
			UITheme.style_label_body(line, 13, Color(0.54, 0.67, 1.0))
			box.add_child(line)

	for hero_id in civ.hero_ids:
		var hero: HeroData = GameState.get_hero(hero_id)
		if hero:
			var tname: String = Enums.HeroType.keys()[hero.type]
			var line := Label.new()
			line.text = "Hero: %s (%s, age %d)" % [hero.hero_name, tname, hero.age]
			UITheme.style_label_body(line, 13, Color(0.36, 0.80, 0.88))
			box.add_child(line)


# --- UI Helpers ---

func _add_card(parent: HBoxContainer, title: String, value: String, color: Color) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.make_panel_style(
		Color(0.10, 0.09, 0.12, 0.7), UITheme.PANEL_BORDER, 4, 1, 8
	))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label_body(t, 11, UITheme.PARCHMENT_DIM)
	vbox.add_child(t)

	var v := Label.new()
	v.text = value
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label_stat(v, 16, color)
	vbox.add_child(v)


func _add_econ_row(parent: VBoxContainer, label: String, value: String, color: Color) -> void:
	var row := HBoxContainer.new()

	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_label_body(l, 12, UITheme.PARCHMENT_DIM)
	row.add_child(l)

	var v := Label.new()
	v.text = value
	UITheme.style_label_body(v, 12, color)
	row.add_child(v)

	parent.add_child(row)


func _add_driver_row(parent: VBoxContainer, label: String, value: float) -> void:
	if absf(value) < 0.05:
		return

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var is_positive: bool = value > 0
	var dot_color: Color = Color(0.45, 0.78, 0.42) if is_positive else Color(0.82, 0.32, 0.30)

	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(4, 14)
	dot.color = dot_color
	row.add_child(dot)

	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_label_body(l, 12, UITheme.PARCHMENT)
	row.add_child(l)

	var v := Label.new()
	v.text = "%+.1f" % value
	v.custom_minimum_size = Vector2(40, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.style_label_stat(v, 12, dot_color)
	row.add_child(v)


func _add_insight_line(parent: VBoxContainer, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_label_body(l, 12, color)
	parent.add_child(l)


func _add_sep() -> void:
	var sep := ColorRect.new()
	sep.color = UITheme.PANEL_BORDER
	sep.custom_minimum_size = Vector2(0, 1)
	_content.add_child(sep)


# --- Utility ---

func _stability_color(value: float) -> Color:
	if value >= 70.0:
		return Color(0.45, 0.78, 0.42)
	elif value >= 30.0:
		return Color(0.82, 0.72, 0.28)
	return Color(0.82, 0.32, 0.30)


func _stability_mood_color(stability: float) -> Color:
	if stability >= 70.0:
		return Color(0.12, 0.18, 0.10, 0.5)
	elif stability >= 40.0:
		return Color(0.15, 0.13, 0.08, 0.4)
	return Color(0.20, 0.08, 0.08, 0.5)


func _fmt_pop(n: int) -> String:
	if n >= 1000000:
		return "%.1fM" % (float(n) / 1000000.0)
	elif n >= 1000:
		return "%.1fK" % (float(n) / 1000.0)
	return str(n)


func _dismiss() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_dismiss()
			get_viewport().set_input_as_handled()
