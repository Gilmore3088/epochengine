extends PanelContainer

## Region detail panel shown when a region is selected.
## Draggable (by header), edge-snapping, resizable font.
## Closes on Esc, click-off, or clicking another region.

const SNAP_MARGIN := 40.0  # pixels from edge to trigger snap
const EDGE_PAD := 12.0     # padding when snapped to an edge
const SCALE_MIN := 0.8
const SCALE_MAX := 1.4
const SCALE_STEP := 0.1
const BASE_WIDTH := 270.0
const MAX_WIDTH_RATIO := 0.25  # max 25% of viewport width

# Base font sizes (scaled by ui_scale)
const FONT_HEADER := 17
const FONT_BODY := 13
const FONT_STAT := 14
const FONT_SECTION := 11
const FONT_BUTTON := 13
const FONT_QUEUED := 12

var name_label: Label
var terrain_label: Label
var owner_label: Label
var population_label: Label
var food_label: Label
var production_label: Label
var defense_label: Label
var infrastructure_label: Label
var dev_tier_label: Label
var pop_density_label: Label
var resources_label: Label
var resources_header: Label
var supply_label: Label

# Action elements
var actions_container: VBoxContainer
var upgrade_btn: Button
var war_btn: Button
var peace_btn: Button
var alliance_btn: Button
var claim_btn: Button
var queued_label: Label
var queued_timer: float = 0.0

# Town section
var towns_container: VBoxContainer
var found_town_btn: Button

# Tier progress ("Almost There")
var tier_progress_container: VBoxContainer

# Visual elements
var header_bar: PanelContainer
var header_hbox: HBoxContainer
var divider: ColorRect
var scale_down_btn: Button
var scale_up_btn: Button

# Drag state
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _home_x: float = 0.0

# Scale
var ui_scale: float = 1.0

var current_region_id: int = -1

# Track all font labels for rescaling
var _header_labels: Array[Label] = []
var _body_labels: Array[Label] = []
var _stat_labels: Array[Label] = []
var _section_labels: Array[Label] = []


func _ready() -> void:
	_build_ui()
	_connect_signals()
	visible = false
	# Position at right-center of viewport
	call_deferred("_set_initial_position")


func _set_initial_position() -> void:
	var vp_size := get_viewport_rect().size
	position = Vector2(vp_size.x - size.x - EDGE_PAD, (vp_size.y - size.y) / 2.0)
	_home_x = position.x


func _build_ui() -> void:
	# Use absolute positioning (top-left anchor, manual position)
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	custom_minimum_size = Vector2(BASE_WIDTH, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Main panel style
	var panel_style := UITheme.make_panel_style(
		UITheme.PANEL_BG,
		UITheme.PANEL_BORDER,
		8, 1, 0,
	)
	add_theme_stylebox_override("panel", panel_style)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 0)
	add_child(outer_vbox)

	# -- Header bar (draggable) --
	header_bar = PanelContainer.new()
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = Color(0.12, 0.10, 0.08, 0.6)
	header_style.set_corner_radius_all(0)
	header_style.corner_radius_top_left = 7
	header_style.corner_radius_top_right = 7
	header_style.set_content_margin_all(8)
	header_style.content_margin_left = 10
	header_style.content_margin_right = 6
	header_bar.add_theme_stylebox_override("panel", header_style)
	header_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	header_bar.mouse_default_cursor_shape = Control.CURSOR_MOVE
	header_bar.gui_input.connect(_on_header_gui_input)
	outer_vbox.add_child(header_bar)

	header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 4)
	header_bar.add_child(header_hbox)

	name_label = Label.new()
	name_label.text = "Region Name"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_label_header(name_label, FONT_HEADER)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_hbox.add_child(name_label)
	_header_labels.append(name_label)

	# Scale buttons
	scale_down_btn = Button.new()
	scale_down_btn.text = "A-"
	scale_down_btn.custom_minimum_size = Vector2(28, 24)
	UITheme.style_button(scale_down_btn)
	scale_down_btn.add_theme_font_size_override("font_size", 11)
	scale_down_btn.pressed.connect(_on_scale_down)
	scale_down_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	header_hbox.add_child(scale_down_btn)

	scale_up_btn = Button.new()
	scale_up_btn.text = "A+"
	scale_up_btn.custom_minimum_size = Vector2(28, 24)
	UITheme.style_button(scale_up_btn)
	scale_up_btn.add_theme_font_size_override("font_size", 11)
	scale_up_btn.pressed.connect(_on_scale_up)
	scale_up_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	header_hbox.add_child(scale_up_btn)

	# -- Gold divider line under header --
	divider = ColorRect.new()
	divider.color = UITheme.GOLD_DIM
	divider.custom_minimum_size = Vector2(0, 1)
	outer_vbox.add_child(divider)

	# -- Body content area (scrollable) --
	var body := MarginContainer.new()
	body.add_theme_constant_override("margin_left", 14)
	body.add_theme_constant_override("margin_right", 14)
	body.add_theme_constant_override("margin_top", 10)
	body.add_theme_constant_override("margin_bottom", 12)
	outer_vbox.add_child(body)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(vbox)

	# -- Identity section --
	terrain_label = _add_info_row(vbox, "Terrain", "--")
	terrain_label.tooltip_text = "Terrain affects food, production,\ndefense, and supply cost."
	owner_label = _add_info_row(vbox, "Owner", "--")
	population_label = _add_info_row(vbox, "Population", "--")

	# -- Separator --
	_add_separator(vbox)

	# -- Yields section header --
	var yields_header := Label.new()
	yields_header.text = "YIELDS"
	UITheme.style_label_body(yields_header, FONT_SECTION, UITheme.GOLD_DIM)
	yields_header.add_theme_constant_override("margin_top", 2)
	vbox.add_child(yields_header)
	_section_labels.append(yields_header)

	food_label = _add_stat_row(vbox, "Food", "--", UITheme.COLOR_FOOD)
	production_label = _add_stat_row(vbox, "Production", "--", UITheme.COLOR_PRODUCTION)
	defense_label = _add_stat_row(vbox, "Defense", "--", Color(0.55, 0.55, 0.78))
	defense_label.tooltip_text = "Defense modifier for battles.\nAffected by terrain and dev tier."
	infrastructure_label = _add_stat_row(vbox, "Infrastructure", "--", UITheme.PARCHMENT_DIM)
	infrastructure_label.tooltip_text = "Infrastructure level (0-5).\nIncreases yields, reduces supply costs.\nUpgrade with production stockpile."
	supply_label = _add_stat_row(vbox, "Supply", "--", UITheme.PARCHMENT_DIM)
	supply_label.tooltip_text = "Supply efficiency from capital.\nAffects town output and reinforcement.\n100% = full, <50% = penalties."

	# -- Development section --
	_add_separator(vbox)

	var dev_header := Label.new()
	dev_header.text = "DEVELOPMENT"
	UITheme.style_label_body(dev_header, FONT_SECTION, UITheme.GOLD_DIM)
	dev_header.add_theme_constant_override("margin_top", 2)
	vbox.add_child(dev_header)
	_section_labels.append(dev_header)

	dev_tier_label = _add_stat_row(vbox, "Tier", "--", Color(0.65, 0.55, 0.85))
	dev_tier_label.tooltip_text = "Development Tier: Wild (0) to Advanced (5).\nHigher tiers boost economy and defense.\nRequires infra, population, stability, era."
	pop_density_label = _add_stat_row(vbox, "Pop. Density", "--", UITheme.PARCHMENT_DIM)
	pop_density_label.tooltip_text = "Population as percentage of terrain capacity.\nHigher density required for tier promotion."

	# -- Resources section --
	_add_separator(vbox)

	resources_header = Label.new()
	resources_header.text = "RESOURCES"
	UITheme.style_label_body(resources_header, FONT_SECTION, UITheme.GOLD_DIM)
	resources_header.add_theme_constant_override("margin_top", 2)
	vbox.add_child(resources_header)
	_section_labels.append(resources_header)

	resources_label = Label.new()
	resources_label.text = ""
	resources_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	UITheme.style_label_body(resources_label, FONT_BODY, UITheme.PARCHMENT_DIM)
	vbox.add_child(resources_label)
	_body_labels.append(resources_label)

	# -- Towns section --
	_add_separator(vbox)

	var towns_header := Label.new()
	towns_header.text = "TOWNS"
	UITheme.style_label_body(towns_header, FONT_SECTION, UITheme.GOLD_DIM)
	towns_header.add_theme_constant_override("margin_top", 2)
	vbox.add_child(towns_header)
	_section_labels.append(towns_header)

	towns_container = VBoxContainer.new()
	towns_container.add_theme_constant_override("separation", 2)
	vbox.add_child(towns_container)

	found_town_btn = Button.new()
	found_town_btn.text = "Found Town"
	UITheme.style_button(found_town_btn)
	found_town_btn.visible = false
	found_town_btn.pressed.connect(_on_found_town_pressed)
	vbox.add_child(found_town_btn)

	# -- Tier progress ("Almost There") --
	_add_separator(vbox)

	var progress_header := Label.new()
	progress_header.text = "NEXT TIER"
	UITheme.style_label_body(progress_header, FONT_SECTION, UITheme.GOLD_DIM)
	progress_header.add_theme_constant_override("margin_top", 2)
	vbox.add_child(progress_header)
	_section_labels.append(progress_header)

	tier_progress_container = VBoxContainer.new()
	tier_progress_container.add_theme_constant_override("separation", 1)
	vbox.add_child(tier_progress_container)

	# -- Actions --
	_add_separator(vbox)
	actions_container = VBoxContainer.new()
	actions_container.add_theme_constant_override("separation", 4)
	vbox.add_child(actions_container)

	upgrade_btn = Button.new()
	upgrade_btn.text = "Upgrade Infrastructure"
	UITheme.style_button(upgrade_btn)
	upgrade_btn.visible = false
	upgrade_btn.pressed.connect(_on_upgrade_pressed)
	actions_container.add_child(upgrade_btn)

	war_btn = Button.new()
	war_btn.text = "Declare War"
	UITheme.style_button(war_btn)
	war_btn.visible = false
	war_btn.pressed.connect(_on_war_pressed)
	actions_container.add_child(war_btn)

	peace_btn = Button.new()
	peace_btn.text = "Seek Peace"
	UITheme.style_button(peace_btn)
	peace_btn.visible = false
	peace_btn.pressed.connect(_on_peace_pressed)
	actions_container.add_child(peace_btn)

	alliance_btn = Button.new()
	alliance_btn.text = "Propose Alliance"
	UITheme.style_button(alliance_btn)
	alliance_btn.visible = false
	alliance_btn.pressed.connect(_on_alliance_pressed)
	actions_container.add_child(alliance_btn)

	claim_btn = Button.new()
	claim_btn.text = "Claim Region"
	UITheme.style_button(claim_btn)
	claim_btn.visible = false
	claim_btn.pressed.connect(_on_claim_pressed)
	actions_container.add_child(claim_btn)

	queued_label = Label.new()
	queued_label.text = "Queued! Press Next Year to execute."
	UITheme.style_label_body(queued_label, FONT_QUEUED, UITheme.COLOR_FOOD)
	queued_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	queued_label.visible = false
	actions_container.add_child(queued_label)
	_body_labels.append(queued_label)


# ==================== DRAG & SNAP ====================

func _on_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_offset = event.global_position - global_position
		else:
			_dragging = false
			_snap_to_edge()
		get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion and _dragging:
		position = event.global_position - _drag_offset
		_clamp_to_viewport()
		get_viewport().set_input_as_handled()


func _clamp_to_viewport() -> void:
	var vp_size := get_viewport_rect().size
	position.x = clampf(position.x, 0, vp_size.x - size.x)
	position.y = clampf(position.y, 0, vp_size.y - size.y)


func _snap_to_edge() -> void:
	var vp_size := get_viewport_rect().size
	var panel_size := size

	# Check distances to each edge
	var dist_left := position.x
	var dist_right := vp_size.x - (position.x + panel_size.x)
	var dist_top := position.y
	var dist_bottom := vp_size.y - (position.y + panel_size.y)

	# Horizontal snap
	if dist_left < SNAP_MARGIN:
		position.x = EDGE_PAD
	elif dist_right < SNAP_MARGIN:
		position.x = vp_size.x - panel_size.x - EDGE_PAD

	# Vertical snap
	if dist_top < SNAP_MARGIN:
		position.y = EDGE_PAD
	elif dist_bottom < SNAP_MARGIN:
		position.y = vp_size.y - panel_size.y - EDGE_PAD

	_home_x = position.x


# ==================== FONT SCALING ====================

func _on_scale_down() -> void:
	ui_scale = maxf(ui_scale - SCALE_STEP, SCALE_MIN)
	_apply_scale()


func _on_scale_up() -> void:
	ui_scale = minf(ui_scale + SCALE_STEP, SCALE_MAX)
	_apply_scale()


func _apply_scale() -> void:
	# Update panel width
	var vp_width := get_viewport_rect().size.x
	var max_width := vp_width * MAX_WIDTH_RATIO
	var new_width := clampf(BASE_WIDTH * ui_scale, 220.0, max_width)
	custom_minimum_size.x = new_width

	# Scale all tracked labels (skip freed instances from dynamic rebuilds)
	for lbl in _header_labels:
		if is_instance_valid(lbl):
			lbl.add_theme_font_size_override("font_size", int(FONT_HEADER * ui_scale))
	for lbl in _body_labels:
		if is_instance_valid(lbl):
			lbl.add_theme_font_size_override("font_size", int(FONT_BODY * ui_scale))
	for lbl in _stat_labels:
		if is_instance_valid(lbl):
			lbl.add_theme_font_size_override("font_size", int(FONT_STAT * ui_scale))
	for lbl in _section_labels:
		if is_instance_valid(lbl):
			lbl.add_theme_font_size_override("font_size", int(FONT_SECTION * ui_scale))

	# Scale button font sizes
	for btn in [upgrade_btn, war_btn, peace_btn, alliance_btn, claim_btn]:
		if is_instance_valid(btn):
			btn.add_theme_font_size_override("font_size", int(FONT_BUTTON * ui_scale))

	# Keep panel on screen after resize
	call_deferred("_clamp_to_viewport")


# ==================== ROW BUILDERS ====================

func _add_info_row(parent: Control, key_text: String, value: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var key_lbl := Label.new()
	key_lbl.text = key_text
	UITheme.style_label_body(key_lbl, FONT_BODY, UITheme.PARCHMENT_DIM)
	key_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(key_lbl)
	_body_labels.append(key_lbl)

	var val_lbl := Label.new()
	val_lbl.text = value
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.style_label_stat(val_lbl, FONT_BODY, UITheme.PARCHMENT)
	row.add_child(val_lbl)
	_body_labels.append(val_lbl)

	return val_lbl


func _add_stat_row(parent: Control, key_text: String, value: String, color: Color) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var key_lbl := Label.new()
	key_lbl.text = key_text
	UITheme.style_label_body(key_lbl, FONT_BODY, UITheme.PARCHMENT_DIM)
	key_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(key_lbl)
	_body_labels.append(key_lbl)

	var val_lbl := Label.new()
	val_lbl.text = value
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.style_label_stat(val_lbl, FONT_STAT, color)
	row.add_child(val_lbl)
	_stat_labels.append(val_lbl)

	return val_lbl


func _add_separator(parent: Control) -> void:
	var sep := ColorRect.new()
	sep.color = UITheme.PANEL_BORDER
	sep.custom_minimum_size = Vector2(0, 1)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	margin.add_child(sep)
	parent.add_child(margin)


# ==================== SIGNALS ====================

func _connect_signals() -> void:
	EventBus.region_selected.connect(_on_region_selected)
	EventBus.region_deselected.connect(_close)
	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.region_owner_changed.connect(_on_region_owner_changed)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and visible:
		EventBus.region_deselected.emit()
		get_viewport().set_input_as_handled()


func _on_region_selected(region_id: int) -> void:
	current_region_id = region_id
	_update_display()
	_slide_in()


func _process(delta: float) -> void:
	if queued_timer > 0.0:
		queued_timer -= delta
		if queued_timer <= 0.0:
			queued_label.visible = false


func _update_display() -> void:
	var region := GameState.get_region(current_region_id)
	if not region:
		return

	var vis := GameState.get_player_visibility(region.id)

	if vis == Enums.VisibilityState.HIDDEN:
		_show_hidden_display(region)
		return

	if vis == Enums.VisibilityState.EXPLORED:
		_show_explored_display(region)
		return

	name_label.text = region.region_name

	var terrain_names := {
		Enums.TerrainType.RIVER_BASIN: "River Basin",
		Enums.TerrainType.PLAINS: "Plains",
		Enums.TerrainType.MOUNTAINS: "Mountains",
		Enums.TerrainType.DESERT: "Desert",
		Enums.TerrainType.JUNGLE: "Jungle",
		Enums.TerrainType.COASTLINE: "Coastline",
		Enums.TerrainType.TUNDRA: "Tundra",
		Enums.TerrainType.STEPPE: "Steppe",
		Enums.TerrainType.VOLCANIC_RIDGE: "Volcanic Ridge",
	}
	terrain_label.text = terrain_names.get(region.terrain_type, "Unknown")

	if region.owner_id >= 0:
		var civ := GameState.get_civilization(region.owner_id)
		owner_label.text = civ.civ_name if civ else "Unknown"
	else:
		owner_label.text = "Neutral"

	population_label.text = _format_number(region.population)
	food_label.text = "%d" % region.food_yield
	production_label.text = "%d" % region.production_yield
	defense_label.text = "%.1fx" % region.defense_modifier
	infrastructure_label.text = "%d / %d" % [region.infrastructure_level, Constants.INFRASTRUCTURE_MAX_LEVEL]

	# Supply efficiency
	var supply_pct := region.supply_value * 100.0
	supply_label.text = "%d%%" % int(supply_pct)
	if supply_pct >= 80.0:
		supply_label.add_theme_color_override("font_color", UITheme.COLOR_STABILITY_HIGH)
	elif supply_pct >= 50.0:
		supply_label.add_theme_color_override("font_color", UITheme.COLOR_STABILITY_MID)
	else:
		supply_label.add_theme_color_override("font_color", UITheme.COLOR_STABILITY_LOW)

	# Development tier info
	dev_tier_label.text = DevelopmentTierSimulation.get_tier_name(region.development_tier)

	# Population density
	var capacity: int = Constants.TERRAIN_POP_CAPACITY.get(region.terrain_type, 5000)
	var effective_cap := int(float(capacity) * region.size_factor)
	if effective_cap > 0:
		var density := clampf(float(region.population) / float(effective_cap), 0.0, 1.0)
		pop_density_label.text = "%.0f%%" % (density * 100.0)
	else:
		pop_density_label.text = "0%"

	# Resource pyramid display
	var res_parts: Array[String] = []
	var player_civ_for_res := GameState.get_player_civ()
	var current_era: int = player_civ_for_res.current_era if player_civ_for_res else 0

	# Terrain yields (renewable)
	var terrain_key: int = region.terrain_type
	if Constants.RESOURCE_TERRAIN_YIELDS.has(terrain_key):
		var terrain_yields: Dictionary = Constants.RESOURCE_TERRAIN_YIELDS[terrain_key]
		for res_type in terrain_yields:
			if ResourceProduction.is_resource_unlocked(res_type, current_era):
				var yield_val: int = terrain_yields[res_type]
				if yield_val > 0:
					res_parts.append("%s: %d/yr" % [ResourceProduction.get_resource_name(res_type), yield_val])

	# Deposits (finite)
	for res_type in region.resource_deposits:
		var remaining: int = region.resource_deposits[res_type]
		var name_str := ResourceProduction.get_resource_name(res_type)
		if remaining > 0:
			res_parts.append("%s: %d left" % [name_str, remaining])
		else:
			res_parts.append("%s: Depleted" % name_str)

	if res_parts.is_empty():
		resources_label.text = ""
		resources_label.visible = false
		resources_header.visible = false
	else:
		resources_label.text = "\n".join(res_parts)
		resources_label.visible = true
		resources_header.visible = true

	# Towns display
	_update_towns_display(region)

	# Tier progress ("Almost There")
	_update_tier_progress(region)

	# Action buttons
	var player_civ := GameState.get_player_civ()
	var is_player_owned := region.owner_id == GameState.player_civ_id

	# Hide all action buttons first
	upgrade_btn.visible = false
	war_btn.visible = false
	peace_btn.visible = false
	alliance_btn.visible = false
	claim_btn.visible = false
	found_town_btn.visible = false

	if not player_civ or player_civ.is_collapsed:
		return

	if is_player_owned:
		# Player owns this region - show upgrade
		var can_upgrade := region.infrastructure_level < Constants.INFRASTRUCTURE_MAX_LEVEL
		upgrade_btn.visible = can_upgrade
		if can_upgrade:
			var cost := Constants.INFRASTRUCTURE_UPGRADE_COST * (region.infrastructure_level + 1)
			upgrade_btn.text = "Upgrade Infrastructure (-%d prod)" % cost
			upgrade_btn.disabled = player_civ.production_stockpile < cost
		# Found town button (in actions area, separate from towns_container)
		if region.population >= Constants.TOWN_MIN_POP_TO_FOUND:
			var town_cost := TownSimulation.calculate_town_cost(region)
			found_town_btn.text = "Found Town (-%d prod)" % town_cost
			found_town_btn.visible = true
			var can_afford := player_civ.production_stockpile >= town_cost
			found_town_btn.disabled = not can_afford
			if not can_afford:
				found_town_btn.tooltip_text = "Need %d production (have %d)" % [town_cost, player_civ.production_stockpile]
			else:
				found_town_btn.tooltip_text = "Found a new town in this region"
	elif region.is_neutral():
		# Neutral region - show claim if adjacent to player territory AND visible
		if vis == Enums.VisibilityState.VISIBLE and _is_adjacent_to_player(region):
			var region_count := GameState.get_regions_by_owner(player_civ.id).size()
			var cost := EconomySimulation.calculate_expansion_cost(player_civ, region_count)
			var can_afford := EconomySimulation.can_afford_expansion(player_civ, region_count)
			claim_btn.text = "Claim Region (-%d prod)" % cost
			claim_btn.visible = true
			claim_btn.disabled = not can_afford
			if not can_afford:
				claim_btn.tooltip_text = "Need %d production (have %d)" % [cost, player_civ.production_stockpile]
			else:
				claim_btn.tooltip_text = "Sends settlers from your nearest region"
	elif region.owner_id >= 0:
		# Region belongs to another civ - show diplomacy actions
		var owner_civ := GameState.get_civilization(region.owner_id)
		if owner_civ and not owner_civ.is_collapsed:
			var owner_id := owner_civ.id
			if player_civ.war_targets.has(owner_id):
				peace_btn.text = "Seek Peace with %s" % owner_civ.civ_name
				peace_btn.visible = true
			else:
				war_btn.text = "Declare War on %s" % owner_civ.civ_name
				war_btn.visible = true
				if not player_civ.alliance_partners.has(owner_id):
					alliance_btn.text = "Propose Alliance with %s" % owner_civ.civ_name
					alliance_btn.visible = true


func _show_hidden_display(region: RegionData) -> void:
	## Show minimal info for unknown territory (HIDDEN fog state).
	name_label.text = "Unknown Territory"
	terrain_label.text = "???"
	owner_label.text = "???"
	population_label.text = "???"
	food_label.text = "?"
	production_label.text = "?"
	defense_label.text = "?"
	infrastructure_label.text = "?"
	supply_label.text = "?"
	dev_tier_label.text = "?"
	pop_density_label.text = "?"
	resources_label.text = ""
	resources_label.visible = false
	resources_header.visible = false
	for child in towns_container.get_children():
		child.queue_free()
	for child in tier_progress_container.get_children():
		child.queue_free()
	upgrade_btn.visible = false
	war_btn.visible = false
	peace_btn.visible = false
	alliance_btn.visible = false
	claim_btn.visible = false
	found_town_btn.visible = false


func _show_explored_display(region: RegionData) -> void:
	## Show terrain and yields only for explored-but-not-visible regions.
	var terrain_names := {
		Enums.TerrainType.RIVER_BASIN: "River Basin",
		Enums.TerrainType.PLAINS: "Plains",
		Enums.TerrainType.MOUNTAINS: "Mountains",
		Enums.TerrainType.DESERT: "Desert",
		Enums.TerrainType.JUNGLE: "Jungle",
		Enums.TerrainType.COASTLINE: "Coastline",
		Enums.TerrainType.TUNDRA: "Tundra",
		Enums.TerrainType.STEPPE: "Steppe",
		Enums.TerrainType.VOLCANIC_RIDGE: "Volcanic Ridge",
	}
	name_label.text = region.region_name
	terrain_label.text = terrain_names.get(region.terrain_type, "Unknown")
	owner_label.text = "Beyond your borders"
	population_label.text = "???"
	food_label.text = "%d" % region.food_yield
	production_label.text = "%d" % region.production_yield
	defense_label.text = "%.1fx" % region.defense_modifier
	infrastructure_label.text = "???"
	supply_label.text = "???"
	dev_tier_label.text = "???"
	pop_density_label.text = "???"
	resources_label.text = ""
	resources_label.visible = false
	resources_header.visible = false
	for child in towns_container.get_children():
		child.queue_free()
	for child in tier_progress_container.get_children():
		child.queue_free()
	upgrade_btn.visible = false
	war_btn.visible = false
	peace_btn.visible = false
	alliance_btn.visible = false
	claim_btn.visible = false
	found_town_btn.visible = false


func _on_turn_ended(_year: int) -> void:
	if visible and current_region_id >= 0:
		_update_display()


func _on_region_owner_changed(region_id: int, _old: int, _new: int) -> void:
	if region_id == current_region_id and visible:
		_update_display()


func _close() -> void:
	_slide_out()


func _slide_in() -> void:
	if not visible:
		position.x = get_viewport_rect().size.x
	visible = true
	var tween := create_tween()
	tween.tween_property(self, "position:x", _home_x, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _slide_out() -> void:
	_home_x = position.x
	var tween := create_tween()
	tween.tween_property(self, "position:x", get_viewport_rect().size.x, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(func():
		visible = false
		current_region_id = -1
	)


# ==================== ACTIONS ====================

func _on_upgrade_pressed() -> void:
	if current_region_id < 0:
		return
	PlayerActions.queue_action({
		"type": "invest_infrastructure",
		"region_id": current_region_id,
	})
	EventBus.player_action_queued.emit("invest_infrastructure", {"region_id": current_region_id})
	_show_queued_feedback()
	upgrade_btn.disabled = true


func _on_war_pressed() -> void:
	var region := GameState.get_region(current_region_id)
	if not region or region.owner_id < 0:
		return
	PlayerActions.queue_action({
		"type": "declare_war",
		"target_civ_id": region.owner_id,
	})
	EventBus.player_action_queued.emit("declare_war", {"target_civ_id": region.owner_id})
	_show_queued_feedback()
	war_btn.disabled = true


func _on_peace_pressed() -> void:
	var region := GameState.get_region(current_region_id)
	if not region or region.owner_id < 0:
		return
	PlayerActions.queue_action({
		"type": "seek_peace",
		"target_civ_id": region.owner_id,
	})
	EventBus.player_action_queued.emit("seek_peace", {"target_civ_id": region.owner_id})
	_show_queued_feedback()
	peace_btn.disabled = true


func _on_alliance_pressed() -> void:
	var region := GameState.get_region(current_region_id)
	if not region or region.owner_id < 0:
		return
	PlayerActions.queue_action({
		"type": "seek_alliance",
		"target_civ_id": region.owner_id,
	})
	EventBus.player_action_queued.emit("seek_alliance", {"target_civ_id": region.owner_id})
	_show_queued_feedback()
	alliance_btn.disabled = true


func _on_claim_pressed() -> void:
	if current_region_id < 0:
		return
	PlayerActions.queue_action({
		"type": "claim_region",
		"region_id": current_region_id,
	})
	EventBus.player_action_queued.emit("claim_region", {"region_id": current_region_id})
	_show_queued_feedback()
	claim_btn.disabled = true


func _is_adjacent_to_player(region: RegionData) -> bool:
	var player_civ := GameState.get_player_civ()
	if not player_civ:
		return false
	for neighbor_id in region.adjacency_list:
		var neighbor := GameState.get_region(neighbor_id)
		if neighbor and neighbor.owner_id == player_civ.id:
			return true
	return false


func _show_queued_feedback() -> void:
	queued_label.visible = true
	queued_timer = 3.0


static func _format_number(n: int) -> String:
	if n >= 1000000:
		return "%.1fM" % (float(n) / 1000000.0)
	elif n >= 1000:
		return "%.1fK" % (float(n) / 1000.0)
	else:
		return str(n)


# ==================== TOWN DISPLAY ====================

func _update_towns_display(region: RegionData) -> void:
	for child in towns_container.get_children():
		child.queue_free()

	if region.towns.is_empty():
		var no_towns := Label.new()
		if region.owner_id == GameState.player_civ_id:
			if region.population >= Constants.TOWN_MIN_POP_TO_FOUND:
				no_towns.text = "Ready to found a town!"
				UITheme.style_label_body(no_towns, FONT_BODY, Color(0.5, 0.78, 0.42))
			else:
				no_towns.text = "Need %d+ pop to found (have %s)" % [
					Constants.TOWN_MIN_POP_TO_FOUND, _format_number(region.population)]
				UITheme.style_label_body(no_towns, FONT_BODY, UITheme.PARCHMENT_DIM)
		else:
			no_towns.text = "No towns"
			UITheme.style_label_body(no_towns, FONT_BODY, UITheme.PARCHMENT_DIM)
		towns_container.add_child(no_towns)
		_body_labels.append(no_towns)
		return

	var is_player_owned := region.owner_id == GameState.player_civ_id
	var player_civ := GameState.get_player_civ()

	for i in range(region.towns.size()):
		var town: TownData = region.towns[i]
		var town_box := VBoxContainer.new()
		town_box.add_theme_constant_override("separation", 1)

		# Town name + population + Details button
		var header_row := HBoxContainer.new()
		header_row.add_theme_constant_override("separation", 4)
		var header := Label.new()
		header.text = "%s (pop %s)" % [town.town_name, _format_number(town.population)]
		UITheme.style_label_stat(header, FONT_STAT, UITheme.PARCHMENT)
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header_row.add_child(header)
		if is_player_owned:
			var detail_btn := Button.new()
			detail_btn.text = "Details"
			UITheme.style_button(detail_btn)
			detail_btn.add_theme_font_size_override("font_size", int(10 * ui_scale))
			detail_btn.pressed.connect(func(): EventBus.open_town_detail.emit(region.id, i))
			header_row.add_child(detail_btn)
		town_box.add_child(header_row)

		# Buildings summary
		var bldg_parts: Array[String] = []
		for entry in town.buildings:
			var btype: int = entry.get("type", -1)
			var bcount: int = entry.get("count", 0)
			if bcount > 0:
				var bname: String = Constants.BUILDING_NAMES.get(btype, "?")
				bldg_parts.append("%s x%d" % [bname, bcount])
		if not bldg_parts.is_empty():
			var bldg_label := Label.new()
			bldg_label.text = "  " + ", ".join(bldg_parts)
			UITheme.style_label_body(bldg_label, FONT_BODY, UITheme.PARCHMENT_DIM)
			bldg_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			town_box.add_child(bldg_label)

		# Output breakdown
		var outputs := TownSimulation.compute_town_outputs(town, region)
		_add_town_output_breakdown(town_box, outputs)

		# Specialization label (non-player towns with buildings)
		if not is_player_owned and not town.buildings.is_empty():
			var spec := _get_town_specialization(town)
			if spec != "":
				var spec_label := Label.new()
				spec_label.text = "  Focus: %s" % spec
				UITheme.style_label_body(spec_label, FONT_BODY, UITheme.GOLD_DIM)
				town_box.add_child(spec_label)

		# Recommended actions (player-owned only)
		if is_player_owned and player_civ and not player_civ.is_collapsed:
			_add_recommended_actions(town_box, town, region, player_civ)

			var build_row := HBoxContainer.new()
			build_row.add_theme_constant_override("separation", 4)

			var option := OptionButton.new()
			for btype in Constants.BUILDING_NAMES:
				var bname: String = Constants.BUILDING_NAMES[btype]
				var cost := TownSimulation.calculate_building_cost(town, btype)
				option.add_item("%s (%d)" % [bname, cost], btype)
			option.add_theme_font_size_override("font_size", int(11 * ui_scale))
			option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			build_row.add_child(option)

			var build_btn := Button.new()
			build_btn.text = "Build"
			UITheme.style_button(build_btn)
			build_btn.add_theme_font_size_override("font_size", int(11 * ui_scale))
			build_btn.pressed.connect(
				_on_construct_building_pressed.bind(region.id, i, option)
			)
			build_row.add_child(build_btn)

			town_box.add_child(build_row)

		towns_container.add_child(town_box)

	# Town capacity hint (player-owned only)
	if is_player_owned and region.population >= Constants.TOWN_MIN_POP_TO_FOUND:
		@warning_ignore("integer_division")
		var potential := region.population / Constants.TOWN_MIN_POP_TO_FOUND
		if potential > region.towns.size():
			var hint := Label.new()
			hint.text = "Pop supports %d towns (have %d)" % [potential, region.towns.size()]
			UITheme.style_label_body(hint, FONT_SECTION, UITheme.PARCHMENT_DIM)
			towns_container.add_child(hint)
			_section_labels.append(hint)


func _on_found_town_pressed() -> void:
	if current_region_id < 0:
		return
	PlayerActions.queue_action({
		"type": "found_town",
		"region_id": current_region_id,
	})
	EventBus.player_action_queued.emit("found_town", {"region_id": current_region_id})
	_show_queued_feedback()
	found_town_btn.disabled = true


func _on_construct_building_pressed(region_id: int, town_index: int, option: OptionButton) -> void:
	var building_type: int = option.get_selected_id()
	PlayerActions.queue_action({
		"type": "construct_building",
		"region_id": region_id,
		"town_index": town_index,
		"building_type": building_type,
	})
	EventBus.player_action_queued.emit("construct_building", {
		"region_id": region_id, "town_index": town_index, "building_type": building_type,
	})
	_show_queued_feedback()


func _add_town_output_breakdown(parent: VBoxContainer, outputs: Dictionary) -> void:
	var supply_pct := int(outputs["supply_efficiency"] * 100.0)
	var supply_tag := "" if supply_pct >= 100 else " x%d%%" % supply_pct

	# Food line
	var food_text := "  Food: %d base + %d bldg%s = %d" % [
		outputs["base_food"], outputs["bldg_food"], supply_tag, outputs["total_food"],
	]
	var food_label := Label.new()
	food_label.text = food_text
	UITheme.style_label_body(food_label, FONT_BODY, UITheme.PARCHMENT_DIM)
	parent.add_child(food_label)

	# Production line
	var net: int = outputs["net_prod"]
	var prod_color: Color = UITheme.PARCHMENT_DIM
	if net < 0:
		prod_color = Color(0.9, 0.3, 0.3)  # red for deficit
	var prod_text := "  Prod: %d base + %d bldg%s - %d upkeep = %d" % [
		outputs["base_prod"], outputs["bldg_prod"], supply_tag,
		outputs["upkeep"], net,
	]
	var prod_label := Label.new()
	prod_label.text = prod_text
	UITheme.style_label_body(prod_label, FONT_BODY, prod_color)
	parent.add_child(prod_label)

	# Deficit warning
	if net < 0:
		var warn := Label.new()
		warn.text = "  ! Production deficit"
		UITheme.style_label_body(warn, FONT_BODY, Color(0.9, 0.3, 0.3))
		parent.add_child(warn)

	# Military/stability/tech (only show if non-zero)
	var extras: Array[String] = []
	if outputs["bldg_mil"] > 0.0:
		extras.append("Mil +%.0f" % outputs["total_mil"])
	if outputs["bldg_stab"] > 0.0:
		extras.append("Stab +%.0f" % outputs["total_stab"])
	if outputs["bldg_def"] > 0.0:
		extras.append("Def +%.0f%%" % (outputs["total_def"] * 100.0))
	if outputs["bldg_tech"] > 0.0:
		extras.append("Tech +%.1f" % outputs["total_tech"])
	if not extras.is_empty():
		var extra_label := Label.new()
		extra_label.text = "  " + ", ".join(extras)
		UITheme.style_label_body(extra_label, FONT_BODY, UITheme.PARCHMENT_DIM)
		parent.add_child(extra_label)


func _add_recommended_actions(
	parent: VBoxContainer, town: TownData, region: RegionData, civ: CivilizationData
) -> void:
	var suggestions: Array[String] = []

	var outputs := TownSimulation.compute_town_outputs(town, region)

	if outputs["total_food"] < 3:
		suggestions.append("Build Granary (+2 food)")
	if civ.stability < 40.0:
		suggestions.append("Build Monument (+3 stab)")
	if civ.is_at_war():
		suggestions.append("Build Barracks (+2 mil)")
	if outputs["net_prod"] > 4 and suggestions.is_empty():
		suggestions.append("Build Workshop (+3 prod)")

	if suggestions.is_empty():
		return

	# Show max 3 suggestions
	for j in range(mini(suggestions.size(), 3)):
		var sug_label := Label.new()
		sug_label.text = "  > %s" % suggestions[j]
		UITheme.style_label_body(sug_label, FONT_BODY, UITheme.GOLD_DIM)
		parent.add_child(sug_label)


func _get_town_specialization(town: TownData) -> String:
	var category_counts := {}
	for entry in town.buildings:
		var btype: int = entry.get("type", -1)
		var count: int = entry.get("count", 0)
		if Constants.BUILDING_RULES.has(btype):
			var cat: String = Constants.BUILDING_RULES[btype]["category"]
			category_counts[cat] = category_counts.get(cat, 0) + count
	if category_counts.is_empty():
		return ""
	var best_cat := ""
	var best_count := 0
	for cat in category_counts:
		if category_counts[cat] > best_count:
			best_count = category_counts[cat]
			best_cat = cat
	return best_cat.capitalize()


# ==================== TIER PROGRESS ====================

func _update_tier_progress(region: RegionData) -> void:
	for child in tier_progress_container.get_children():
		child.queue_free()

	if region.owner_id != GameState.player_civ_id:
		return
	var player_civ := GameState.get_player_civ()
	if not player_civ:
		return

	if region.development_tier >= 5:
		var max_label := Label.new()
		max_label.text = "Maximum tier reached"
		UITheme.style_label_body(max_label, FONT_BODY, UITheme.COLOR_FOOD)
		tier_progress_container.add_child(max_label)
		return

	var next_tier: int = region.development_tier + 1
	if next_tier >= Constants.DEV_TIER_GATES.size():
		return
	var gate: Array = Constants.DEV_TIER_GATES[next_tier]

	var pop_density := _calc_pop_density(region)

	# gate = [min_infra, min_pop_density, min_stability, min_governance, min_era]
	var reqs: Array[Dictionary] = [
		{"name": "Infra", "need": gate[0], "have": region.infrastructure_level, "met": region.infrastructure_level >= gate[0]},
		{"name": "Density", "need": gate[1], "have": pop_density, "met": pop_density >= gate[1], "fmt": "%.2f"},
		{"name": "Stability", "need": gate[2], "have": player_civ.stability, "met": player_civ.stability >= gate[2], "fmt": "%.0f"},
		{"name": "Governance", "need": gate[3], "have": player_civ.governance_tier, "met": player_civ.governance_tier >= gate[3]},
		{"name": "Era", "need": gate[4], "have": player_civ.current_era, "met": player_civ.current_era >= gate[4]},
	]

	# Resource gates
	if next_tier < Constants.DEV_TIER_RESOURCE_GATES.size():
		var res_gate: Array = Constants.DEV_TIER_RESOURCE_GATES[next_tier]
		for res_type in res_gate:
			var has_it: bool = player_civ.resource_stockpiles.get(res_type, 0) > 0
			reqs.append({
				"name": ResourceProduction.get_resource_name(res_type),
				"need": 1, "have": 1 if has_it else 0, "met": has_it,
			})

	var tier_name := DevelopmentTierSimulation.get_tier_name(next_tier)
	var title := Label.new()
	title.text = "%s" % tier_name
	UITheme.style_label_body(title, FONT_BODY, UITheme.PARCHMENT)
	tier_progress_container.add_child(title)

	for req in reqs:
		var color: Color
		if req["met"]:
			color = UITheme.COLOR_FOOD
		else:
			var need_f := float(req["need"])
			var have_f := float(req["have"])
			if need_f > 0 and have_f / need_f >= 0.80:
				color = UITheme.GOLD
			else:
				color = UITheme.COLOR_MILITARY

		var fmt: String = req.get("fmt", "%d")
		var text: String
		if req["met"]:
			text = "  %s: OK" % req["name"]
		else:
			text = "  %s: need %s (have %s)" % [req["name"], fmt % req["need"], fmt % req["have"]]

		var lbl := Label.new()
		lbl.text = text
		UITheme.style_label_body(lbl, FONT_BODY, color)
		tier_progress_container.add_child(lbl)

		# Add governance hint when unmet
		if req["name"] == "Governance" and not req["met"]:
			var needed_regions := _governance_region_hint(int(req["need"]))
			if needed_regions > 0:
				var hint := Label.new()
				hint.text = "    (Need %d+ regions)" % needed_regions
				UITheme.style_label_body(hint, FONT_BODY - 1, UITheme.PARCHMENT_DIM)
				tier_progress_container.add_child(hint)


func _governance_region_hint(needed_tier: int) -> int:
	if needed_tier < GovernanceSimulation.TIER_DATA.size():
		return GovernanceSimulation.TIER_DATA[needed_tier][0]
	return 0


static func _calc_pop_density(region: RegionData) -> float:
	var capacity: int = Constants.TERRAIN_POP_CAPACITY.get(region.terrain_type, 5000)
	var effective_cap := int(float(capacity) * region.size_factor)
	if effective_cap <= 0:
		return 0.0
	return clampf(float(region.population) / float(effective_cap), 0.0, 1.0)
