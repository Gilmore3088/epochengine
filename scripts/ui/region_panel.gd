extends PanelContainer

## Region detail panel shown when a region is selected.

var name_label: Label
var terrain_label: Label
var owner_label: Label
var population_label: Label
var food_label: Label
var production_label: Label
var defense_label: Label
var infrastructure_label: Label
var resources_label: Label

var current_region_id: int = -1


func _ready() -> void:
	_build_ui()
	_connect_signals()
	visible = false


func _build_ui() -> void:
	# Position at right side of screen
	anchors_preset = Control.PRESET_CENTER_RIGHT
	offset_left = -280
	offset_top = -200
	offset_right = -10
	offset_bottom = 200
	custom_minimum_size = Vector2(260, 0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.9)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	name_label = _add_label(vbox, "Region Name", 18, Color(0.95, 0.90, 0.70))
	terrain_label = _add_label(vbox, "Terrain: --")
	owner_label = _add_label(vbox, "Owner: --")
	population_label = _add_label(vbox, "Population: --")

	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)

	food_label = _add_label(vbox, "Food Yield: --", 14, Color(0.5, 0.85, 0.5))
	production_label = _add_label(vbox, "Production: --", 14, Color(0.85, 0.65, 0.3))
	defense_label = _add_label(vbox, "Defense: --", 14, Color(0.6, 0.6, 0.85))
	infrastructure_label = _add_label(vbox, "Infrastructure: --")
	resources_label = _add_label(vbox, "")

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_close)
	vbox.add_child(close_btn)


func _add_label(
	parent: Control,
	text: String,
	size: int = 14,
	color: Color = Color(0.85, 0.85, 0.85),
) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	parent.add_child(lbl)
	return lbl


func _connect_signals() -> void:
	EventBus.region_selected.connect(_on_region_selected)
	EventBus.region_deselected.connect(_close)
	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.region_owner_changed.connect(_on_region_owner_changed)


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
	terrain_label.text = "Terrain: %s" % terrain_names.get(region.terrain_type, "Unknown")

	if region.owner_id >= 0:
		var civ := GameState.get_civilization(region.owner_id)
		owner_label.text = "Owner: %s" % (civ.civ_name if civ else "Unknown")
	else:
		owner_label.text = "Owner: Neutral"

	population_label.text = "Population: %s" % _format_number(region.population)
	food_label.text = "Food Yield: %d" % region.food_yield
	production_label.text = "Production: %d" % region.production_yield
	defense_label.text = "Defense: %.1fx" % region.defense_modifier
	infrastructure_label.text = "Infrastructure: %d/5" % region.infrastructure_level

	if region.resource_stock.is_empty():
		resources_label.text = ""
	else:
		var parts: Array[String] = []
		for res_name in region.resource_stock:
			parts.append("%s: %d" % [res_name, region.resource_stock[res_name]])
		resources_label.text = "Resources: %s" % ", ".join(parts)


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
