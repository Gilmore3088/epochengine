class_name UITheme
extends RefCounted

## Shared font and style resources for the historical UI theme.
## Loads Cinzel (headers) and EB Garamond (body) fonts.

static var _header_font: Font
static var _body_font: Font
static var _body_bold_font: Font

# Color palette
const GOLD := Color(0.85, 0.75, 0.45)
const GOLD_BRIGHT := Color(1.0, 0.90, 0.55)
const GOLD_DIM := Color(0.65, 0.58, 0.38)
const PARCHMENT := Color(0.92, 0.88, 0.78)
const PARCHMENT_DIM := Color(0.70, 0.66, 0.58)
const INK := Color(0.12, 0.10, 0.08)
const INK_LIGHT := Color(0.25, 0.22, 0.18)
const PANEL_BG := Color(0.08, 0.07, 0.10, 0.92)
const PANEL_BG_LIGHT := Color(0.12, 0.10, 0.14, 0.88)
const PANEL_BORDER := Color(0.35, 0.30, 0.22, 0.6)
const PANEL_BORDER_HIGHLIGHT := Color(0.55, 0.48, 0.32, 0.4)

# Stat colors
const COLOR_FOOD := Color(0.45, 0.78, 0.42)
const COLOR_PRODUCTION := Color(0.82, 0.62, 0.28)
const COLOR_MILITARY := Color(0.82, 0.32, 0.30)
const COLOR_STABILITY_HIGH := Color(0.3, 0.65, 0.3)
const COLOR_STABILITY_MID := Color(0.75, 0.65, 0.2)
const COLOR_STABILITY_LOW := Color(0.75, 0.2, 0.2)


static func get_header_font() -> Font:
	if not _header_font:
		_header_font = load("res://assets/fonts/Cinzel-Bold.ttf")
	return _header_font


static func get_body_font() -> Font:
	if not _body_font:
		_body_font = load("res://assets/fonts/EBGaramond-Regular.ttf")
	return _body_font


static func get_body_bold_font() -> Font:
	if not _body_bold_font:
		_body_bold_font = load("res://assets/fonts/EBGaramond-SemiBold.ttf")
	return _body_bold_font


static func make_panel_style(
	bg: Color = PANEL_BG,
	border: Color = PANEL_BORDER,
	corner_radius: int = 6,
	border_width: int = 1,
	margin: int = 14,
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(corner_radius)
	style.set_content_margin_all(margin)
	style.border_color = border
	style.set_border_width_all(border_width)
	# Subtle inner highlight at top
	style.shadow_color = Color(1, 1, 1, 0.03)
	style.shadow_size = 1
	return style


static func make_button_style_normal() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.12, 0.16, 0.85)
	style.border_color = Color(0.35, 0.30, 0.22, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(6)
	return style


static func make_button_style_hover() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.20, 0.17, 0.22, 0.90)
	style.border_color = GOLD_DIM
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(6)
	return style


static func make_button_style_pressed() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.22, 0.15, 0.90)
	style.border_color = GOLD
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(6)
	return style


static func style_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", make_button_style_normal())
	btn.add_theme_stylebox_override("hover", make_button_style_hover())
	btn.add_theme_stylebox_override("pressed", make_button_style_pressed())
	btn.add_theme_font_override("font", get_body_bold_font())
	btn.add_theme_color_override("font_color", PARCHMENT_DIM)
	btn.add_theme_color_override("font_hover_color", PARCHMENT)
	btn.add_theme_color_override("font_pressed_color", GOLD)
	btn.focus_mode = Control.FOCUS_NONE  # Prevent buttons from stealing keyboard shortcuts


static func style_label_header(lbl: Label, size: int = 18) -> void:
	lbl.add_theme_font_override("font", get_header_font())
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", GOLD)


static func style_label_body(lbl: Label, size: int = 15, color: Color = PARCHMENT_DIM) -> void:
	lbl.add_theme_font_override("font", get_body_font())
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)


static func style_label_stat(lbl: Label, size: int = 15, color: Color = PARCHMENT) -> void:
	lbl.add_theme_font_override("font", get_body_bold_font())
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)


static func style_button_animated(btn: Button) -> void:
	## Style button with hover scale animation and click sound.
	style_button(btn)
	btn.pivot_offset = btn.size / 2.0
	btn.mouse_entered.connect(func() -> void:
		btn.pivot_offset = btn.size / 2.0
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1).set_ease(Tween.EASE_OUT)
		var am: AudioManager = btn.get_node_or_null("/root/AudioManager") as AudioManager
		if am:
			am.play_ui_hover()
	)
	btn.mouse_exited.connect(func() -> void:
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, 0.1).set_ease(Tween.EASE_OUT)
	)
	btn.pressed.connect(func() -> void:
		var am: AudioManager = btn.get_node_or_null("/root/AudioManager") as AudioManager
		if am:
			am.play_ui_click()
	)


static func make_tooltip_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.08, 0.95)
	sb.border_color = GOLD_DIM
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(8)
	return sb
