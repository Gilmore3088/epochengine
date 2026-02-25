class_name DiplomacyPanel
extends PanelContainer

## Diplomacy overview panel showing all civilizations, relationships, and actions.
## D key toggles. Shows war/alliance/neutral status, peace cooldowns, and action buttons.

var _scroll: ScrollContainer
var _content: VBoxContainer
var _close_btn: Button
var _is_open: bool = false


func _ready() -> void:
	_build_shell()
	visible = false


func _build_shell() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -300
	offset_right = 300
	offset_top = -320
	offset_bottom = 320
	custom_minimum_size = Vector2(600, 0)

	add_theme_stylebox_override("panel", UITheme.make_panel_style(
		Color(0.07, 0.06, 0.09, 0.95),
		Color(0.50, 0.42, 0.28, 0.6),
		10, 1, 20
	))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	margin.add_child(outer)

	# Header row with title and close button
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	outer.add_child(header)

	var title := Label.new()
	title.text = "DIPLOMACY"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_label_header(title, 18)
	header.add_child(title)

	_close_btn = Button.new()
	_close_btn.text = "X"
	_close_btn.focus_mode = Control.FOCUS_NONE
	UITheme.style_button(_close_btn)
	_close_btn.add_theme_font_size_override("font_size", 12)
	_close_btn.custom_minimum_size = Vector2(28, 28)
	_close_btn.pressed.connect(_close)
	header.add_child(_close_btn)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	outer.add_child(sep)

	# Scroll area
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(0, 500)
	outer.add_child(_scroll)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)


func toggle() -> void:
	if _is_open:
		_close()
	else:
		_open()


func _open() -> void:
	_is_open = true
	_rebuild_content()
	PanelAnimator.open_panel(self)


func _close() -> void:
	_is_open = false
	PanelAnimator.close_panel(self)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and visible:
		_close()
		get_viewport().set_input_as_handled()


func _rebuild_content() -> void:
	for child in _content.get_children():
		child.queue_free()

	var player := GameState.get_player_civ()
	if not player:
		return

	# Player summary at top
	_add_player_summary(player)

	# Each other civ gets a card
	for civ in GameState.civilizations.values():
		if civ.id == player.id:
			continue
		_add_civ_card(player, civ)


func _add_player_summary(player: CivilizationData) -> void:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UITheme.make_panel_style(
		Color(0.10, 0.09, 0.12, 0.8),
		Color(0.50, 0.42, 0.28, 0.3),
		6, 1, 10
	))
	_content.add_child(box)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	box.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = "%s (You)" % player.civ_name
	UITheme.style_label_header(name_lbl, 15)
	name_lbl.add_theme_color_override("font_color", player.color)
	vbox.add_child(name_lbl)

	var regions := GameState.get_regions_by_owner(player.id)
	var info_text := "%d regions | Pop %s | Stability %.0f%%" % [
		regions.size(),
		_format_pop(player.total_population),
		player.stability,
	]
	var info_lbl := Label.new()
	info_lbl.text = info_text
	UITheme.style_label_body(info_lbl, 11, UITheme.PARCHMENT_DIM)
	vbox.add_child(info_lbl)

	# Active relationships summary
	var summary_parts: Array[String] = []
	if player.war_targets.size() > 0:
		summary_parts.append("At war with %d" % player.war_targets.size())
	if player.alliance_partners.size() > 0:
		summary_parts.append("Allied with %d" % player.alliance_partners.size())
	if player.is_in_golden_age():
		summary_parts.append("Golden Age")

	if summary_parts.size() > 0:
		var status_lbl := Label.new()
		status_lbl.text = " | ".join(summary_parts)
		UITheme.style_label_body(status_lbl, 11, UITheme.GOLD)
		vbox.add_child(status_lbl)


func _add_civ_card(player: CivilizationData, civ: CivilizationData) -> void:
	var card := PanelContainer.new()
	var bg_color := Color(0.08, 0.07, 0.10, 0.85)
	if civ.is_collapsed:
		bg_color = Color(0.05, 0.04, 0.05, 0.6)
	card.add_theme_stylebox_override("panel", UITheme.make_panel_style(
		bg_color,
		Color(0.40, 0.35, 0.25, 0.4),
		6, 1, 10
	))
	_content.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# Row 1: Name + relationship status
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	vbox.add_child(header_row)

	var name_lbl := Label.new()
	name_lbl.text = civ.civ_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_color := civ.color if not civ.is_collapsed else Color(0.4, 0.38, 0.35)
	UITheme.style_label_header(name_lbl, 14)
	name_lbl.add_theme_color_override("font_color", name_color)
	header_row.add_child(name_lbl)

	var rel_lbl := Label.new()
	var rel_text: String
	var rel_color: Color
	if civ.is_collapsed:
		rel_text = "COLLAPSED"
		rel_color = Color(0.4, 0.38, 0.35)
	elif player.war_targets.has(civ.id):
		var war_years: int = player.war_durations.get(civ.id, 0)
		rel_text = "AT WAR (%dyr)" % war_years
		rel_color = Color(0.9, 0.25, 0.2)
	elif player.alliance_partners.has(civ.id):
		rel_text = "ALLIED"
		rel_color = Color(0.3, 0.75, 0.4)
	elif player.nap_partners.has(civ.id):
		var nap_years: int = player.nap_partners.get(civ.id, 0)
		rel_text = "NAP (%dyr left)" % nap_years
		rel_color = Color(0.4, 0.6, 0.9)
	else:
		rel_text = "NEUTRAL"
		rel_color = Color(0.6, 0.58, 0.55)
	UITheme.style_label_body(rel_lbl, 12, rel_color)
	rel_lbl.text = rel_text
	header_row.add_child(rel_lbl)

	if civ.is_collapsed:
		return

	# Row 2: Stats
	var regions := GameState.get_regions_by_owner(civ.id)
	var stats_text := "%d regions | Pop %s | Military %.0f | Stability %.0f%%" % [
		regions.size(),
		_format_pop(civ.total_population),
		civ.military_strength,
		civ.stability,
	]
	var stats_lbl := Label.new()
	stats_lbl.text = stats_text
	UITheme.style_label_body(stats_lbl, 11, UITheme.PARCHMENT_DIM)
	vbox.add_child(stats_lbl)

	# Row 3: Personality tags + era
	var era_name: String = Enums.Epoch.keys()[civ.current_era]
	var tags := civ.get_personality_tags()
	var traits_text := era_name
	if tags.size() > 0:
		traits_text += " | " + ", ".join(tags)
	var traits_lbl := Label.new()
	traits_lbl.text = traits_text
	UITheme.style_label_body(traits_lbl, 10, Color(0.55, 0.53, 0.50))
	vbox.add_child(traits_lbl)

	# Row 3.5: Trade status
	if player.trade_partners.has(civ.id):
		var trade_lbl := Label.new()
		trade_lbl.text = "Trade Agreement (+%d%% food/prod)" % int(Constants.TRADE_FOOD_BONUS_PERCENT * 100)
		UITheme.style_label_body(trade_lbl, 10, Color(0.5, 0.8, 0.5))
		vbox.add_child(trade_lbl)

	# Row 4: Peace cooldown (if any)
	var cooldown: int = player.peace_cooldowns.get(civ.id, 0)
	if cooldown > 0 and not player.war_targets.has(civ.id):
		var cd_lbl := Label.new()
		cd_lbl.text = "Peace cooldown: %d years" % cooldown
		UITheme.style_label_body(cd_lbl, 10, Color(0.7, 0.55, 0.3))
		vbox.add_child(cd_lbl)

	# Row 5: Heroes
	var heroes := GameState.get_heroes_by_civ(civ.id)
	if heroes.size() > 0:
		var hero_parts: Array[String] = []
		for hero in heroes:
			var tname: String = Enums.HeroType.keys()[hero.type]
			hero_parts.append("%s (%s)" % [hero.hero_name, tname])
		var hero_lbl := Label.new()
		hero_lbl.text = "Heroes: " + ", ".join(hero_parts)
		UITheme.style_label_body(hero_lbl, 10, Color(0.36, 0.80, 0.88))
		vbox.add_child(hero_lbl)

	# Row 6: Actions (only for non-collapsed civs)
	var actions_row := HBoxContainer.new()
	actions_row.add_theme_constant_override("separation", 6)
	vbox.add_child(actions_row)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_row.add_child(spacer)

	if player.war_targets.has(civ.id):
		# At war: offer peace
		var peace_btn := Button.new()
		peace_btn.text = "Seek Peace"
		peace_btn.focus_mode = Control.FOCUS_NONE
		UITheme.style_button(peace_btn)
		peace_btn.add_theme_font_size_override("font_size", 11)
		peace_btn.pressed.connect(_on_seek_peace.bind(civ.id))
		actions_row.add_child(peace_btn)
	else:
		# Not at war
		if not player.alliance_partners.has(civ.id):
			# Offer alliance
			var ally_btn := Button.new()
			ally_btn.text = "Seek Alliance"
			ally_btn.focus_mode = Control.FOCUS_NONE
			UITheme.style_button(ally_btn)
			ally_btn.add_theme_font_size_override("font_size", 11)
			ally_btn.pressed.connect(_on_seek_alliance.bind(civ.id))
			actions_row.add_child(ally_btn)

		# Seek NAP (when neutral — not war, not allied, not already NAP'd)
		if not player.alliance_partners.has(civ.id) and not player.nap_partners.has(civ.id):
			var nap_btn := Button.new()
			nap_btn.text = "Seek NAP"
			nap_btn.focus_mode = Control.FOCUS_NONE
			UITheme.style_button(nap_btn)
			nap_btn.add_theme_font_size_override("font_size", 11)
			nap_btn.pressed.connect(_on_seek_nap.bind(civ.id))
			actions_row.add_child(nap_btn)

		# Seek Trade (when at peace and not already trading)
		if not player.trade_partners.has(civ.id):
			var trade_btn := Button.new()
			trade_btn.text = "Seek Trade"
			trade_btn.focus_mode = Control.FOCUS_NONE
			UITheme.style_button(trade_btn)
			trade_btn.add_theme_font_size_override("font_size", 11)
			trade_btn.pressed.connect(_on_seek_trade.bind(civ.id))
			actions_row.add_child(trade_btn)

		# Demand Tribute (when not allied, player military > target * ratio)
		if not player.alliance_partners.has(civ.id):
			var strength_ratio := player.military_strength / maxf(civ.military_strength, 1.0)
			var tribute_cd: int = player.tribute_cooldowns.get(civ.id, 0)
			if strength_ratio >= Constants.TRIBUTE_STRENGTH_RATIO and tribute_cd <= 0:
				var tribute_btn := Button.new()
				tribute_btn.text = "Demand Tribute"
				tribute_btn.focus_mode = Control.FOCUS_NONE
				UITheme.style_button(tribute_btn)
				tribute_btn.add_theme_font_size_override("font_size", 11)
				tribute_btn.pressed.connect(_on_demand_tribute.bind(civ.id))
				actions_row.add_child(tribute_btn)

		# Declare war (disabled during peace cooldown)
		var war_btn := Button.new()
		war_btn.text = "Declare War"
		war_btn.focus_mode = Control.FOCUS_NONE
		UITheme.style_button(war_btn)
		war_btn.add_theme_font_size_override("font_size", 11)
		if cooldown > 0:
			war_btn.disabled = true
			war_btn.tooltip_text = "Peace cooldown: %d years" % cooldown
		war_btn.pressed.connect(_on_declare_war.bind(civ.id))
		actions_row.add_child(war_btn)


func _on_declare_war(target_civ_id: int) -> void:
	var action := {"type": "declare_war", "target_civ_id": target_civ_id}
	PlayerActions.queue_action(action)
	EventBus.player_action_queued.emit("declare_war", action)
	_rebuild_content()


func _on_seek_peace(target_civ_id: int) -> void:
	var action := {"type": "seek_peace", "target_civ_id": target_civ_id}
	PlayerActions.queue_action(action)
	EventBus.player_action_queued.emit("seek_peace", action)
	_rebuild_content()


func _on_seek_alliance(target_civ_id: int) -> void:
	var action := {"type": "seek_alliance", "target_civ_id": target_civ_id}
	PlayerActions.queue_action(action)
	EventBus.player_action_queued.emit("seek_alliance", action)
	_rebuild_content()


func _on_seek_nap(target_civ_id: int) -> void:
	var action := {"type": "seek_nap", "target_civ_id": target_civ_id}
	PlayerActions.queue_action(action)
	EventBus.player_action_queued.emit("seek_nap", action)
	_rebuild_content()


func _on_seek_trade(target_civ_id: int) -> void:
	var action := {"type": "seek_trade", "target_civ_id": target_civ_id}
	PlayerActions.queue_action(action)
	EventBus.player_action_queued.emit("seek_trade", action)
	_rebuild_content()


func _on_demand_tribute(target_civ_id: int) -> void:
	var action := {"type": "demand_tribute", "target_civ_id": target_civ_id}
	PlayerActions.queue_action(action)
	EventBus.player_action_queued.emit("demand_tribute", action)
	_rebuild_content()


static func _format_pop(pop: int) -> String:
	if pop >= 10000:
		return "%.1fk" % (pop / 1000.0)
	return str(pop)
