class_name TownPanel
extends PanelContainer

## Dedicated per-town detail panel.
## Shows stats, workforce selector, building construction, and hints.
## Opened via "Details" button in RegionPanel or EventBus.open_town_detail.

const FONT_HEADER := 18
const FONT_STAT := 14
const FONT_BODY := 12

var _region_id: int = -1
var _town_index: int = -1
var _scroll: ScrollContainer
var _content: VBoxContainer


func _ready() -> void:
	_build_shell()
	visible = false
	EventBus.open_town_detail.connect(_on_open)
	EventBus.turn_ended.connect(_on_turn_ended)


func _build_shell() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -260
	offset_right = 260
	offset_top = -300
	offset_bottom = 300
	custom_minimum_size = Vector2(520, 0)

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
	_content.add_theme_constant_override("separation", 10)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)


func _on_open(region_id: int, town_index: int) -> void:
	if visible and _region_id == region_id and _town_index == town_index:
		_dismiss()
		return
	_region_id = region_id
	_town_index = town_index
	_rebuild()
	visible = true


func _on_turn_ended(_year: int) -> void:
	if visible:
		_rebuild()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_dismiss()
		get_viewport().set_input_as_handled()


func _dismiss() -> void:
	visible = false
	_region_id = -1
	_town_index = -1


func _rebuild() -> void:
	for child in _content.get_children():
		child.queue_free()

	var region := GameState.get_region(_region_id)
	if not region or _town_index < 0 or _town_index >= region.towns.size():
		_dismiss()
		return

	var town: TownData = region.towns[_town_index]
	var civ := GameState.get_civilization(region.owner_id)
	if not civ:
		_dismiss()
		return

	_build_header(town, region)
	_add_sep()
	_build_outputs(town, region)
	_add_sep()
	_build_workforce(town, region)
	_add_sep()
	_build_buildings(town, region, civ)

	var hints := TownSimulation.compute_town_hints(town, region, civ)
	if not hints.is_empty():
		_add_sep()
		_build_hints(hints)


# --- Zone 1: Header ---

func _build_header(town: TownData, region: RegionData) -> void:
	var title := Label.new()
	title.text = town.town_name
	UITheme.style_label_stat(title, FONT_HEADER, UITheme.GOLD)
	_content.add_child(title)

	var info := Label.new()
	var gravity := TownSimulation.compute_urban_gravity(town, region)
	info.text = "Region: %s  |  Pop: %s  |  Founded: %d  |  Gravity: %d" % [
		region.region_name,
		_fmt(town.population),
		town.founded_year,
		int(gravity),
	]
	UITheme.style_label_body(info, FONT_BODY, UITheme.PARCHMENT_DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	_content.add_child(info)


# --- Zone 2: Output Breakdown ---

func _build_outputs(town: TownData, region: RegionData) -> void:
	var sec := Label.new()
	sec.text = "Output"
	UITheme.style_label_stat(sec, FONT_STAT, UITheme.PARCHMENT)
	_content.add_child(sec)

	var outputs := TownSimulation.compute_town_outputs(town, region)
	var supply_pct := int(outputs["supply_efficiency"] * 100.0)
	var supply_tag := "" if supply_pct >= 100 else " x%d%%" % supply_pct

	_add_stat("Food: %d base + %d bldg%s = %d" % [
		outputs["base_food"], outputs["bldg_food"], supply_tag, outputs["total_food"],
	], UITheme.PARCHMENT_DIM)

	var net: int = outputs["net_prod"]
	var prod_color: Color = UITheme.PARCHMENT_DIM if net >= 0 else Color(0.9, 0.3, 0.3)
	_add_stat("Prod: %d base + %d bldg%s - %d upkeep = %d" % [
		outputs["base_prod"], outputs["bldg_prod"], supply_tag, outputs["upkeep"], net,
	], prod_color)

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
		_add_stat(", ".join(extras), UITheme.PARCHMENT_DIM)

	if outputs.get("has_town_hall", false) and outputs.get("workforce_preset", 0) != 0:
		var preset_name: String = Constants.WORKFORCE_PRESETS[outputs["workforce_preset"]]["name"]
		_add_stat("Workforce: %s" % preset_name, UITheme.GOLD_DIM)


# --- Zone 3: Workforce Selector ---

func _build_workforce(town: TownData, _region: RegionData) -> void:
	var sec := Label.new()
	sec.text = "Workforce"
	UITheme.style_label_stat(sec, FONT_STAT, UITheme.PARCHMENT)
	_content.add_child(sec)

	var has_town_hall: bool = town.get_building_count(Enums.BuildingType.TOWN_HALL) > 0

	if not has_town_hall:
		_add_stat("Build a Town Hall to manage workforce", UITheme.PARCHMENT_DIM)
		return

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var option := OptionButton.new()
	for preset_id in Constants.WORKFORCE_PRESETS:
		var preset: Dictionary = Constants.WORKFORCE_PRESETS[preset_id]
		option.add_item(preset["name"], preset_id)
	option.add_theme_font_size_override("font_size", FONT_BODY)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Select current preset
	for idx in range(option.item_count):
		if option.get_item_id(idx) == town.workforce_preset:
			option.select(idx)
			break
	row.add_child(option)

	var apply_btn := Button.new()
	apply_btn.text = "Apply"
	UITheme.style_button(apply_btn)
	apply_btn.add_theme_font_size_override("font_size", FONT_BODY)
	apply_btn.pressed.connect(_on_workforce_apply.bind(option))
	row.add_child(apply_btn)

	_content.add_child(row)

	# Show current multipliers
	var wf: Dictionary = Constants.WORKFORCE_PRESETS.get(town.workforce_preset, Constants.WORKFORCE_PRESETS[0])
	var mults := "F:%.1f P:%.1f M:%.1f S:%.1f T:%.1f" % [
		wf["food"], wf["production"], wf["military"], wf["stability"], wf["tech"],
	]
	_add_stat(mults, UITheme.PARCHMENT_DIM)


func _on_workforce_apply(option: OptionButton) -> void:
	var preset_id: int = option.get_selected_id()
	PlayerActions.queue_action({
		"type": "set_workforce_preset",
		"region_id": _region_id,
		"town_index": _town_index,
		"preset": preset_id,
	})
	EventBus.player_action_queued.emit("set_workforce_preset", {
		"region_id": _region_id, "town_index": _town_index, "preset": preset_id,
	})
	_show_queued()


# --- Zone 4: Buildings ---

func _build_buildings(town: TownData, _region: RegionData, civ: CivilizationData) -> void:
	var sec := Label.new()
	sec.text = "Buildings"
	UITheme.style_label_stat(sec, FONT_STAT, UITheme.PARCHMENT)
	_content.add_child(sec)

	# List existing
	if town.buildings.is_empty():
		_add_stat("No buildings yet", UITheme.PARCHMENT_DIM)
	else:
		for entry in town.buildings:
			var btype: int = entry.get("type", -1)
			var bcount: int = entry.get("count", 0)
			if bcount > 0:
				var bname: String = Constants.BUILDING_NAMES.get(btype, "?")
				var desc: String = ""
				if Constants.BUILDING_RULES.has(btype):
					desc = Constants.BUILDING_RULES[btype].get("description", "")
				_add_stat("%s x%d  -  %s" % [bname, bcount, desc], UITheme.PARCHMENT_DIM)

	# Build controls (player-owned only)
	var is_player := _region_id >= 0 and GameState.get_region(_region_id) and GameState.get_region(_region_id).owner_id == GameState.player_civ_id
	if is_player and not civ.is_collapsed:
		var build_row := HBoxContainer.new()
		build_row.add_theme_constant_override("separation", 4)

		var option := OptionButton.new()
		for btype in Constants.BUILDING_NAMES:
			var bname: String = Constants.BUILDING_NAMES[btype]
			var cost := TownSimulation.calculate_building_cost(town, btype)
			option.add_item("%s (%d)" % [bname, cost], btype)
		option.add_theme_font_size_override("font_size", FONT_BODY)
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		build_row.add_child(option)

		var build_btn := Button.new()
		build_btn.text = "Build"
		UITheme.style_button(build_btn)
		build_btn.add_theme_font_size_override("font_size", FONT_BODY)
		build_btn.pressed.connect(_on_build_pressed.bind(option))
		build_row.add_child(build_btn)

		_content.add_child(build_row)


func _on_build_pressed(option: OptionButton) -> void:
	var building_type: int = option.get_selected_id()
	PlayerActions.queue_action({
		"type": "construct_building",
		"region_id": _region_id,
		"town_index": _town_index,
		"building_type": building_type,
	})
	EventBus.player_action_queued.emit("construct_building", {
		"region_id": _region_id, "town_index": _town_index, "building_type": building_type,
	})
	_show_queued()


# --- Zone 5: Hints ---

func _build_hints(hints: Array[String]) -> void:
	var sec := Label.new()
	sec.text = "Suggestions"
	UITheme.style_label_stat(sec, FONT_STAT, UITheme.GOLD_DIM)
	_content.add_child(sec)

	for hint in hints:
		_add_stat(hint, UITheme.GOLD_DIM)


# --- Helpers ---

func _add_sep() -> void:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
	_content.add_child(sep)


func _add_stat(text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	UITheme.style_label_body(lbl, FONT_BODY, color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_content.add_child(lbl)


func _show_queued() -> void:
	var lbl := Label.new()
	lbl.text = "Queued! Press Next Year to apply."
	UITheme.style_label_body(lbl, FONT_BODY, UITheme.GOLD)
	_content.add_child(lbl)


func _fmt(value: int) -> String:
	if value >= 1000:
		return "%.1fk" % (float(value) / 1000.0)
	return str(value)
