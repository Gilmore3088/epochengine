class_name VictoryTracker
extends PanelContainer

## Compact victory progress tracker, bottom-right of screen.
## Shows progress toward all 3 victory conditions with color-coded bars.
## Toggle with V key.

const FONT_HEADER := 13
const FONT_STAT := 11

var _content: VBoxContainer
var _bars: Dictionary = {}  # {"domination": ProgressBar, ...}
var _labels: Dictionary = {}  # {"domination": Label, ...}


func _ready() -> void:
	_build_shell()
	visible = false
	EventBus.turn_ended.connect(_on_turn_ended)


func _build_shell() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -260
	offset_right = -8
	offset_top = -170
	offset_bottom = -8

	add_theme_stylebox_override("panel", UITheme.make_panel_style(
		Color(0.06, 0.05, 0.08, 0.90),
		Color(0.40, 0.34, 0.22, 0.5),
		8, 1, 12
	))

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 4)
	add_child(_content)

	var title := Label.new()
	title.text = "Victory Progress"
	UITheme.style_label_stat(title, FONT_HEADER, UITheme.GOLD_DIM)
	_content.add_child(title)

	_add_tracker_row("domination", "Domination", Color(1.0, 0.85, 0.3),
		"Domination Victory: Control 60%% of all regions.")
	_add_tracker_row("cultural", "Cultural", Color(0.7, 0.55, 0.9),
		"Cultural Victory: Avg dev tier 3.0+\nacross 8+ qualifying regions.")
	_add_tracker_row("federation", "Federation", Color(0.45, 0.75, 0.45),
		"Federation Victory: Reach Federation\ngovernance with 2+ alliance partners.")


func _add_tracker_row(key: String, display_name: String, color: Color, tip: String = "") -> void:
	var lbl := Label.new()
	lbl.text = "%s: --" % display_name
	UITheme.style_label_body(lbl, FONT_STAT, UITheme.PARCHMENT_DIM)
	if tip != "":
		lbl.tooltip_text = tip
	_content.add_child(lbl)
	_labels[key] = lbl

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(230, 8)
	bar.max_value = 1.0
	bar.value = 0.0
	bar.show_percentage = false

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.15, 0.13, 0.18, 0.6)
	bar_bg.corner_radius_top_left = 3
	bar_bg.corner_radius_top_right = 3
	bar_bg.corner_radius_bottom_left = 3
	bar_bg.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = color
	bar_fill.corner_radius_top_left = 3
	bar_fill.corner_radius_top_right = 3
	bar_fill.corner_radius_bottom_left = 3
	bar_fill.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("fill", bar_fill)

	if tip != "":
		bar.tooltip_text = tip
	_content.add_child(bar)
	_bars[key] = bar


func _on_turn_ended(_year: int) -> void:
	if visible:
		_update()


func toggle() -> void:
	visible = not visible
	if visible:
		_update()


func _update() -> void:
	var civ := GameState.get_civilization(GameState.player_civ_id)
	if not civ:
		return

	var progress := VictoryChecker.get_progress(civ)

	# Domination
	var dom: Dictionary = progress["domination"]
	_labels["domination"].text = "Domination: %d/%d regions" % [dom["current"], dom["target"]]
	_bars["domination"].value = dom["pct"]
	_color_bar("domination", dom["pct"])

	# Cultural
	var cult: Dictionary = progress["cultural"]
	_labels["cultural"].text = "Cultural: Tier %.1f/%.1f (%d regions)" % [cult["avg_tier"], cult["target_tier"], cult["qualifying_regions"]]
	_bars["cultural"].value = cult["pct"]
	_color_bar("cultural", cult["pct"])

	# Federation
	var fed: Dictionary = progress["federation"]
	var gov_name: String = _governance_name(int(fed["governance_tier"]))
	_labels["federation"].text = "Federation: %s | Allies: %d/%d" % [gov_name, fed["allies"], fed["target_allies"]]
	_bars["federation"].value = fed["pct"]
	_color_bar("federation", fed["pct"])


func _color_bar(key: String, pct: float) -> void:
	var bar: ProgressBar = _bars[key]
	var fill: StyleBoxFlat = bar.get_theme_stylebox("fill")
	if pct < 0.33:
		fill.bg_color = Color(0.8, 0.25, 0.25)
	elif pct < 0.66:
		fill.bg_color = Color(0.8, 0.7, 0.2)
	else:
		fill.bg_color = Color(0.3, 0.75, 0.3)


func _governance_name(tier: int) -> String:
	match tier:
		0: return "Tribal"
		1: return "Chiefdom"
		2: return "City-State"
		3: return "Kingdom"
		4: return "Empire"
		5: return "Federation"
	return "Unknown"
