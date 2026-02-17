class_name TimelinePanel
extends PanelContainer

## Scrollable, filterable historical timeline showing all game events.
## Opened via T key or EventBus.open_timeline signal.

var content: RichTextLabel
var filter_buttons: Dictionary = {}  # {category: Button}
var active_filters: Dictionary = {}  # {category: bool}
var close_btn: Button

# Filter category -> event types
const FILTER_CATEGORIES: Dictionary = {
	"All": [],
	"War": ["war_declared", "battle", "peace"],
	"Tech": ["tech"],
	"Hero": ["hero_spawned", "hero_died"],
	"Govern": ["collapse", "golden_age_start", "golden_age_end", "governance_change"],
	"Economy": ["expansion", "shortage", "infra_upgrade", "deposit_depleted", "maintenance_failure"],
}


func _ready() -> void:
	_build_ui()
	visible = false
	EventBus.open_timeline.connect(_on_open_timeline)


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -280
	offset_right = 280
	offset_top = -320
	offset_bottom = 320
	custom_minimum_size = Vector2(560, 640)

	add_theme_stylebox_override("panel", UITheme.make_panel_style(
		Color(0.06, 0.05, 0.08, 0.96),
		UITheme.PANEL_BORDER,
		8, 1, 16
	))

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 12
	root.offset_top = 12
	root.offset_right = -12
	root.offset_bottom = -12
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	# --- Header row ---
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	root.add_child(header_row)

	var title := Label.new()
	title.text = "TIMELINE"
	UITheme.style_label_header(title, 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title)

	close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(32, 28)
	close_btn.pressed.connect(_dismiss)
	UITheme.style_button(close_btn)
	header_row.add_child(close_btn)

	# --- Filter strip ---
	var filter_strip := HBoxContainer.new()
	filter_strip.add_theme_constant_override("separation", 4)
	root.add_child(filter_strip)

	for category in FILTER_CATEGORIES:
		var btn := Button.new()
		btn.text = category
		btn.toggle_mode = true
		btn.button_pressed = (category == "All")
		btn.custom_minimum_size = Vector2(64, 24)
		UITheme.style_button(btn)
		btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(_on_filter_pressed.bind(category))
		filter_strip.add_child(btn)
		filter_buttons[category] = btn

	active_filters["All"] = true

	# --- Separator ---
	var sep := ColorRect.new()
	sep.color = UITheme.PANEL_BORDER
	sep.custom_minimum_size = Vector2(0, 1)
	root.add_child(sep)

	# --- Scrollable content ---
	content = RichTextLabel.new()
	content.bbcode_enabled = true
	content.scroll_active = true
	content.fit_content = false
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_font_override("normal_font", UITheme.get_body_font())
	content.add_theme_font_override("bold_font", UITheme.get_body_bold_font())
	content.add_theme_font_size_override("normal_font_size", 13)
	root.add_child(content)


func _on_open_timeline() -> void:
	if visible:
		_dismiss()
		return
	_refresh()
	visible = true


func _on_filter_pressed(category: String) -> void:
	if category == "All":
		# Toggle All off/on, deactivate others
		for cat in active_filters:
			active_filters[cat] = false
		active_filters["All"] = true
		for cat in filter_buttons:
			filter_buttons[cat].button_pressed = (cat == "All")
	else:
		active_filters["All"] = false
		filter_buttons["All"].button_pressed = false
		active_filters[category] = filter_buttons[category].button_pressed

	# If nothing is selected, re-enable All
	var any_active := false
	for cat in active_filters:
		if active_filters[cat]:
			any_active = true
			break
	if not any_active:
		active_filters["All"] = true
		filter_buttons["All"].button_pressed = true

	_refresh()


func _refresh() -> void:
	content.clear()

	# Determine which event types to show
	var allowed_types: Dictionary = {}
	var show_all: bool = active_filters.get("All", false)

	if not show_all:
		for cat in active_filters:
			if active_filters[cat] and FILTER_CATEGORIES.has(cat):
				for etype in FILTER_CATEGORIES[cat]:
					allowed_types[etype] = true

	# Iterate events in reverse (newest first)
	var last_year := -1
	var count := 0
	var max_entries := 200

	for i in range(History.events.size() - 1, -1, -1):
		if count >= max_entries:
			break

		var event: Dictionary = History.events[i]
		var etype: String = event.get("type", "")

		if not show_all and not allowed_types.has(etype):
			continue

		var year: int = event.get("year", 0)
		if year != last_year:
			content.append_text("\n[b][color=#888]--- Year %d ---[/color][/b]\n" % year)
			last_year = year

		var severity: int = event.get("severity", 1)
		var color := _type_color(etype)
		var prefix := _type_prefix(etype)
		var desc: String = event.get("description", "")

		if severity >= 3:
			content.append_text("[b][color=%s]%s %s[/color][/b]\n" % [color, prefix, desc])
		else:
			content.append_text("[color=%s]%s %s[/color]\n" % [color, prefix, desc])

		count += 1

	if count == 0:
		content.append_text("[color=#888]No events recorded yet.[/color]")


func _type_color(type: String) -> String:
	match type:
		"war_declared": return "#e55"
		"peace": return "#8b8"
		"battle": return "#da8"
		"expansion": return "#8c8"
		"collapse": return "#f33"
		"tech": return "#5e5"
		"hero_spawned": return "#5ce"
		"hero_died": return "#999"
		"golden_age_start": return "#fd5"
		"golden_age_end": return "#a85"
		"governance_change": return "#a8d"
		"dev_tier_change": return "#a8d"
		"alliance_formed": return "#8af"
		"shortage": return "#e85"
		"infra_upgrade": return "#9ab"
		"deposit_depleted": return "#e85"
		"maintenance_failure": return "#da5"
		_: return "#aaa"


func _type_prefix(type: String) -> String:
	match type:
		"war_declared": return "[WAR]"
		"peace": return "[PEACE]"
		"battle": return "[BATTLE]"
		"expansion": return "[EXPAND]"
		"collapse": return "[COLLAPSE]"
		"tech": return "[TECH]"
		"hero_spawned": return "[HERO]"
		"hero_died": return "[HERO]"
		"golden_age_start": return "[GOLDEN]"
		"golden_age_end": return "[GOLDEN]"
		"governance_change": return "[GOV]"
		"dev_tier_change": return "[DEV]"
		"alliance_formed": return "[ALLIANCE]"
		"shortage": return "[SHORTAGE]"
		"infra_upgrade": return "[INFRA]"
		"deposit_depleted": return "[DEPLETED]"
		"maintenance_failure": return "[MAINT]"
		_: return ""


func _dismiss() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_dismiss()
			get_viewport().set_input_as_handled()
