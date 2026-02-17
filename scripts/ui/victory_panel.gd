class_name VictoryPanel
extends PanelContainer

## Full-screen victory/defeat panel with narrative, stats, and options.
## Connects to EventBus.game_won / game_lost.
## Replaces the summary_bg modal for game-ending events.

const FONT_TITLE := 28
const FONT_SUBTITLE := 18
const FONT_STAT := 14
const FONT_BODY := 13

const NARRATIVES := {
	"domination": "Your armies have swept across the known world. From humble origins, your civilization rose to dominate every corner of the map. History will remember you as the supreme conqueror.",
	"cultural": "Your civilization's achievements echo through the ages. Art, science, and culture flourished under your guidance, creating a golden legacy that will inspire generations to come.",
	"federation": "Through diplomacy and shared vision, the great federation stands united. Where others chose conquest, you chose cooperation, forging bonds that will endure for centuries.",
	"collapse": "Internal strife has torn your civilization apart. Years of instability eroded the foundations of your society, and your people scattered to the winds. Your legacy fades into memory.",
	"no_territory": "Your last territory has fallen to foreign conquerors. Without land, your people have no home. The story of your civilization ends here, a cautionary tale for future nations.",
}

var _bg: ColorRect
var _scroll: ScrollContainer
var _content: VBoxContainer
var _is_victory: bool = false


func _ready() -> void:
	visible = false
	EventBus.game_won.connect(_on_game_won)
	EventBus.game_lost.connect(_on_game_lost)


func _on_game_won(victory_type: String, details: Dictionary) -> void:
	_is_victory = true
	_build_overlay()
	_build_victory_content(victory_type, details)
	visible = true


func _on_game_lost(reason: String, details: Dictionary) -> void:
	_is_victory = false
	_build_overlay()
	_build_defeat_content(reason, details)
	visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# Block Esc from closing — game is over
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()


func _build_overlay() -> void:
	# Clear any previous content
	for child in get_children():
		child.queue_free()

	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0.02, 0.02, 0.04, 0.88)
	add_child(_bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var inner := PanelContainer.new()
	inner.custom_minimum_size = Vector2(600, 0)
	inner.add_theme_stylebox_override("panel", UITheme.make_panel_style(
		Color(0.07, 0.06, 0.09, 0.97),
		Color(0.50, 0.42, 0.28, 0.7),
		12, 2, 24
	))
	center.add_child(inner)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(600, 500)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inner.add_child(_scroll)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(margin)
	margin.add_child(_content)


func _build_victory_content(victory_type: String, details: Dictionary) -> void:
	var civ_name: String = details.get("civ_name", "Unknown")
	var is_player: bool = details.get("civ_id", -1) == GameState.player_civ_id

	# Title
	var title_color := _victory_color(victory_type)
	var title_text := "VICTORY" if is_player else "%s WINS" % civ_name.to_upper()
	_add_title(title_text, title_color)

	# Victory type subtitle
	var type_names := {"domination": "Domination Victory", "cultural": "Cultural Victory", "federation": "Federation Victory"}
	_add_subtitle(type_names.get(victory_type, "Victory"), title_color)

	_add_sep()

	# Narrative
	var narrative: String = NARRATIVES.get(victory_type, "")
	if not is_player:
		narrative = "%s achieved %s victory. %s" % [civ_name, victory_type, narrative]
	_add_body(narrative)

	_add_sep()

	# Stats
	_add_subtitle("Game Summary", UITheme.PARCHMENT)
	_add_stats(details)

	_add_sep()

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER

	if is_player:
		var continue_btn := _make_btn("Continue Watching")
		continue_btn.pressed.connect(_on_continue_watching)
		btn_row.add_child(continue_btn)

	var replay_btn := _make_btn("Play Again")
	replay_btn.pressed.connect(_on_play_again)
	btn_row.add_child(replay_btn)

	_content.add_child(btn_row)


func _build_defeat_content(reason: String, details: Dictionary) -> void:
	# Title
	_add_title("DEFEAT", Color(0.9, 0.3, 0.3))

	var reason_text := "Collapse" if reason == "collapse" else "All Territory Lost"
	_add_subtitle(reason_text, Color(0.8, 0.35, 0.35))

	_add_sep()

	# Narrative
	_add_body(NARRATIVES.get(reason, "Your civilization has fallen."))

	_add_sep()

	# What Went Well
	_add_subtitle("What Went Well", UITheme.GOLD_DIM)
	var highlights := _compute_highlights()
	for h in highlights:
		_add_stat_line(h, UITheme.PARCHMENT_DIM)

	_add_sep()

	# Stats
	_add_subtitle("Game Summary", UITheme.PARCHMENT)
	_add_stats(details)

	_add_sep()

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER

	var replay_btn := _make_btn("Play Again")
	replay_btn.pressed.connect(_on_play_again)
	btn_row.add_child(replay_btn)

	_content.add_child(btn_row)


func _add_stats(details: Dictionary) -> void:
	var stats := build_stats_dict(details)
	for key in stats:
		var val: String = str(stats[key])
		_add_stat_line("%s: %s" % [key, val], UITheme.PARCHMENT_DIM)


func _compute_highlights() -> Array[String]:
	var highlights: Array[String] = []
	var civ_id := GameState.player_civ_id
	var regions := GameState.get_regions_by_owner(civ_id)

	# Peak region count (approximate — use current since History doesn't track peak)
	var expansion_events := History.get_events_by_type("expansion")
	var player_expansions := 0
	for e in expansion_events:
		if e.get("civ_id", -1) == civ_id:
			player_expansions += 1
	if player_expansions > 0:
		highlights.append("Expanded %d times across the map" % player_expansions)

	var techs := History.get_events_by_type("tech")
	var player_techs := 0
	for e in techs:
		if e.get("civ_id", -1) == civ_id:
			player_techs += 1
	if player_techs > 0:
		highlights.append("Discovered %d technologies" % player_techs)

	var towns := History.get_events_by_type("town_founded")
	var player_towns := 0
	for t in towns:
		if t.get("civ_id", -1) == civ_id:
			player_towns += 1
	if player_towns > 0:
		highlights.append("Founded %d towns" % player_towns)

	if highlights.is_empty():
		highlights.append("You survived %d years" % GameState.current_year)

	return highlights


static func build_stats_dict(details: Dictionary) -> Dictionary:
	## Build stats dictionary for display. Static for testability.
	var civ_id: int = details.get("civ_id", GameState.player_civ_id)
	var stats := {}

	stats["Years Survived"] = GameState.current_year
	stats["Regions Owned"] = GameState.get_regions_by_owner(civ_id).size()

	var wars := History.get_events_by_type("war_declared")
	var war_count := 0
	for w in wars:
		if w.get("attacker_id", -1) == civ_id or w.get("defender_id", -1) == civ_id:
			war_count += 1
	stats["Wars Fought"] = war_count

	var techs := History.get_events_by_type("tech")
	var tech_count := 0
	for t in techs:
		if t.get("civ_id", -1) == civ_id:
			tech_count += 1
	stats["Technologies"] = tech_count

	var towns := History.get_events_by_type("town_founded")
	var town_count := 0
	for t in towns:
		if t.get("civ_id", -1) == civ_id:
			town_count += 1
	stats["Towns Founded"] = town_count

	return stats


func _on_continue_watching() -> void:
	# Hide panel, keep game running as spectator
	visible = false


func _on_play_again() -> void:
	History.clear()
	get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")


# --- UI Helpers ---

func _add_title(text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", UITheme.get_header_font())
	lbl.add_theme_font_size_override("font_size", FONT_TITLE)
	lbl.add_theme_color_override("font_color", color)
	_content.add_child(lbl)


func _add_subtitle(text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label_stat(lbl, FONT_SUBTITLE, color)
	_content.add_child(lbl)


func _add_body(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	UITheme.style_label_body(lbl, FONT_BODY, UITheme.PARCHMENT_DIM)
	_content.add_child(lbl)


func _add_stat_line(text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	UITheme.style_label_body(lbl, FONT_STAT, color)
	_content.add_child(lbl)


func _add_sep() -> void:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
	_content.add_child(sep)


func _make_btn(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	UITheme.style_button(btn)
	btn.add_theme_font_size_override("font_size", FONT_STAT)
	btn.custom_minimum_size.x = 160
	return btn


func _victory_color(victory_type: String) -> Color:
	match victory_type:
		"domination":
			return Color(1.0, 0.85, 0.3)
		"cultural":
			return Color(0.7, 0.55, 0.9)
		"federation":
			return Color(0.45, 0.75, 0.45)
	return UITheme.GOLD
