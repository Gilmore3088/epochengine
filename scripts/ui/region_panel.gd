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
var resources_label: Label

# Action elements
var actions_container: VBoxContainer
var upgrade_btn: Button
var war_btn: Button
var peace_btn: Button
var alliance_btn: Button
var queued_label: Label
var queued_timer: float = 0.0

# Visual elements
var header_bar: PanelContainer
var header_hbox: HBoxContainer
var divider: ColorRect
var scale_down_btn: Button
var scale_up_btn: Button

# Drag state
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

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

	# -- Body content area --
	var body := MarginContainer.new()
	body.add_theme_constant_override("margin_left", 14)
	body.add_theme_constant_override("margin_right", 14)
	body.add_theme_constant_override("margin_top", 10)
	body.add_theme_constant_override("margin_bottom", 12)
	outer_vbox.add_child(body)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	body.add_child(vbox)

	# -- Identity section --
	terrain_label = _add_info_row(vbox, "Terrain", "--")
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
	infrastructure_label = _add_stat_row(vbox, "Infrastructure", "--", UITheme.PARCHMENT_DIM)

	# -- Resources (if any) --
	_add_separator(vbox)
	resources_label = Label.new()
	resources_label.text = ""
	resources_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	UITheme.style_label_body(resources_label, FONT_BODY, UITheme.PARCHMENT_DIM)
	vbox.add_child(resources_label)
	_body_labels.append(resources_label)

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

	# Scale all tracked labels
	for lbl in _header_labels:
		lbl.add_theme_font_size_override("font_size", int(FONT_HEADER * ui_scale))
	for lbl in _body_labels:
		lbl.add_theme_font_size_override("font_size", int(FONT_BODY * ui_scale))
	for lbl in _stat_labels:
		lbl.add_theme_font_size_override("font_size", int(FONT_STAT * ui_scale))
	for lbl in _section_labels:
		lbl.add_theme_font_size_override("font_size", int(FONT_SECTION * ui_scale))

	# Scale button font sizes
	for btn in [upgrade_btn, war_btn, peace_btn, alliance_btn]:
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
	visible = true


func _process(delta: float) -> void:
	if queued_timer > 0.0:
		queued_timer -= delta
		if queued_timer <= 0.0:
			queued_label.visible = false


func _update_display() -> void:
	var region := GameState.get_region(current_region_id)
	if not region:
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

	if region.resource_stock.is_empty():
		resources_label.text = ""
		resources_label.visible = false
	else:
		var parts: Array[String] = []
		for res_name in region.resource_stock:
			parts.append("%s: %d" % [res_name, region.resource_stock[res_name]])
		resources_label.text = ", ".join(parts)
		resources_label.visible = true

	# Action buttons
	var player_civ := GameState.get_player_civ()
	var is_player_owned := region.owner_id == GameState.player_civ_id

	# Hide all action buttons first
	upgrade_btn.visible = false
	war_btn.visible = false
	peace_btn.visible = false
	alliance_btn.visible = false

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


func _on_turn_ended(_year: int) -> void:
	if visible and current_region_id >= 0:
		_update_display()


func _on_region_owner_changed(region_id: int, _old: int, _new: int) -> void:
	if region_id == current_region_id and visible:
		_update_display()


func _close() -> void:
	visible = false
	current_region_id = -1


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
