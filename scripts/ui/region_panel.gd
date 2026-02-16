extends PanelContainer

## Region detail panel shown when a region is selected.
## Historical parchment-on-dark theme using UITheme.
## Closes on Esc, click-off, or clicking another region.

var name_label: Label
var terrain_label: Label
var owner_label: Label
var population_label: Label
var food_label: Label
var production_label: Label
var defense_label: Label
var infrastructure_label: Label
var resources_label: Label

# Visual elements
var header_bar: PanelContainer
var divider: ColorRect

var current_region_id: int = -1


func _ready() -> void:
	_build_ui()
	_connect_signals()
	visible = false


func _build_ui() -> void:
	anchors_preset = Control.PRESET_CENTER_RIGHT
	offset_left = -290
	offset_top = -220
	offset_right = -12
	offset_bottom = 220
	custom_minimum_size = Vector2(270, 0)

	# Main panel style
	var panel_style := UITheme.make_panel_style(
		UITheme.PANEL_BG,
		UITheme.PANEL_BORDER,
		8,   # corner_radius
		1,   # border_width
		0,   # margin (we handle padding in inner containers)
	)
	add_theme_stylebox_override("panel", panel_style)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 0)
	add_child(outer_vbox)

	# -- Header bar with region name --
	header_bar = PanelContainer.new()
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = Color(0.12, 0.10, 0.08, 0.6)
	header_style.set_corner_radius_all(0)
	header_style.corner_radius_top_left = 7
	header_style.corner_radius_top_right = 7
	header_style.set_content_margin_all(10)
	header_style.content_margin_bottom = 8
	header_bar.add_theme_stylebox_override("panel", header_style)
	outer_vbox.add_child(header_bar)

	name_label = Label.new()
	name_label.text = "Region Name"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label_header(name_label, 17)
	header_bar.add_child(name_label)

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
	UITheme.style_label_body(yields_header, 11, UITheme.GOLD_DIM)
	yields_header.add_theme_constant_override("margin_top", 2)
	vbox.add_child(yields_header)

	food_label = _add_stat_row(vbox, "Food", "--", UITheme.COLOR_FOOD)
	production_label = _add_stat_row(vbox, "Production", "--", UITheme.COLOR_PRODUCTION)
	defense_label = _add_stat_row(vbox, "Defense", "--", Color(0.55, 0.55, 0.78))
	infrastructure_label = _add_stat_row(vbox, "Infrastructure", "--", UITheme.PARCHMENT_DIM)

	# -- Resources (if any) --
	_add_separator(vbox)
	resources_label = Label.new()
	resources_label.text = ""
	resources_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	UITheme.style_label_body(resources_label, 13, UITheme.PARCHMENT_DIM)
	vbox.add_child(resources_label)


func _add_info_row(parent: Control, key: String, value: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var key_lbl := Label.new()
	key_lbl.text = key
	UITheme.style_label_body(key_lbl, 13, UITheme.PARCHMENT_DIM)
	key_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(key_lbl)

	var val_lbl := Label.new()
	val_lbl.text = value
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.style_label_stat(val_lbl, 13, UITheme.PARCHMENT)
	row.add_child(val_lbl)

	return val_lbl


func _add_stat_row(parent: Control, key: String, value: String, color: Color) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var key_lbl := Label.new()
	key_lbl.text = key
	UITheme.style_label_body(key_lbl, 13, UITheme.PARCHMENT_DIM)
	key_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(key_lbl)

	var val_lbl := Label.new()
	val_lbl.text = value
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.style_label_stat(val_lbl, 14, color)
	row.add_child(val_lbl)

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


func _on_turn_ended(_year: int) -> void:
	if visible and current_region_id >= 0:
		_update_display()


func _on_region_owner_changed(region_id: int, _old: int, _new: int) -> void:
	if region_id == current_region_id and visible:
		_update_display()


func _close() -> void:
	visible = false
	current_region_id = -1


static func _format_number(n: int) -> String:
	if n >= 1000000:
		return "%.1fM" % (float(n) / 1000000.0)
	elif n >= 1000:
		return "%.1fK" % (float(n) / 1000.0)
	else:
		return str(n)
