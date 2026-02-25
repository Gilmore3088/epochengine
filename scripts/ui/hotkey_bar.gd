extends PanelContainer

## Keyboard shortcut reference bar at the bottom of the screen.
## Auto-fades after turn 15 or on early dismissal.

var _turn_count: int = 0
const FADE_AFTER_TURNS := 15

var SHORTCUTS := [
	"Space: Next Year", "P: Auto-Play", "C: Profile",
	"D: Diplomacy", "V: Victory", "T: Timeline",
	"Tab: Overlay", "Esc: Menu",
]


func _ready() -> void:
	_build_ui()
	EventBus.turn_ended.connect(_on_turn_ended)


func _build_ui() -> void:
	# Panel style
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.08, 0.06, 0.80)
	style.set_corner_radius_all(0)
	style.set_content_margin_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	add_theme_stylebox_override("panel", style)

	# Position: full width at bottom
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_top = -28
	offset_bottom = 0

	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hbox)

	for shortcut in SHORTCUTS:
		var lbl := Label.new()
		lbl.text = shortcut
		UITheme.style_label_body(lbl, 12, Color(0.7, 0.7, 0.7))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(lbl)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(20, 20)
	UITheme.style_button(close_btn)
	close_btn.pressed.connect(_fade_and_remove)
	hbox.add_child(close_btn)


func _on_turn_ended(_year: int) -> void:
	_turn_count += 1
	if _turn_count >= FADE_AFTER_TURNS:
		_fade_and_remove()


func _fade_and_remove() -> void:
	EventBus.turn_ended.disconnect(_on_turn_ended)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	tween.tween_callback(queue_free)
