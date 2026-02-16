extends CanvasLayer

## Heads-up display showing year, stability, resources, and speed controls.

var year_label: Label
var stability_bar: ProgressBar
var stability_label: Label
var food_label: Label
var production_label: Label
var military_label: Label
var speed_label: Label
var advance_button: Button
var speed_1x_button: Button
var speed_5x_button: Button
var speed_10x_button: Button
var event_log: RichTextLabel

var player_civ_id: int = 0  # Default to first civ for display
var fast_forward_count: int = 0
var fast_forward_target: int = 0


func _ready() -> void:
	_build_ui()
	_connect_signals()
	_update_display()


func _build_ui() -> void:
	# Top bar container
	var top_bar := HBoxContainer.new()
	top_bar.offset_left = 10
	top_bar.offset_top = 10
	top_bar.offset_right = -10
	top_bar.add_theme_constant_override("separation", 20)
	add_child(top_bar)

	# Year
	year_label = Label.new()
	year_label.text = "Year: 0"
	year_label.add_theme_font_size_override("font_size", 22)
	year_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.70))
	top_bar.add_child(year_label)

	# Stability
	var stability_box := VBoxContainer.new()
	top_bar.add_child(stability_box)

	stability_label = Label.new()
	stability_label.text = "Stability: 50"
	stability_label.add_theme_font_size_override("font_size", 14)
	stability_box.add_child(stability_label)

	stability_bar = ProgressBar.new()
	stability_bar.min_value = 0
	stability_bar.max_value = 100
	stability_bar.value = 50
	stability_bar.custom_minimum_size = Vector2(120, 16)
	stability_bar.show_percentage = false
	stability_box.add_child(stability_bar)

	# Resources
	food_label = Label.new()
	food_label.text = "Food: 0"
	food_label.add_theme_font_size_override("font_size", 14)
	food_label.add_theme_color_override("font_color", Color(0.5, 0.85, 0.5))
	top_bar.add_child(food_label)

	production_label = Label.new()
	production_label.text = "Production: 0"
	production_label.add_theme_font_size_override("font_size", 14)
	production_label.add_theme_color_override("font_color", Color(0.85, 0.65, 0.3))
	top_bar.add_child(production_label)

	military_label = Label.new()
	military_label.text = "Military: 0"
	military_label.add_theme_font_size_override("font_size", 14)
	military_label.add_theme_color_override("font_color", Color(0.85, 0.35, 0.35))
	top_bar.add_child(military_label)

	# Speed controls
	var speed_box := HBoxContainer.new()
	speed_box.add_theme_constant_override("separation", 5)
	top_bar.add_child(speed_box)

	advance_button = Button.new()
	advance_button.text = "Next Year"
	advance_button.pressed.connect(_on_advance_pressed)
	speed_box.add_child(advance_button)

	speed_1x_button = Button.new()
	speed_1x_button.text = "1x"
	speed_1x_button.toggle_mode = true
	speed_1x_button.button_pressed = true
	speed_1x_button.pressed.connect(_on_speed_1x)
	speed_box.add_child(speed_1x_button)

	speed_5x_button = Button.new()
	speed_5x_button.text = "5x"
	speed_5x_button.pressed.connect(_on_speed_5x)
	speed_box.add_child(speed_5x_button)

	speed_10x_button = Button.new()
	speed_10x_button.text = "10x"
	speed_10x_button.pressed.connect(_on_speed_10x)
	speed_box.add_child(speed_10x_button)

	speed_label = Label.new()
	speed_label.text = ""
	speed_label.add_theme_font_size_override("font_size", 14)
	speed_box.add_child(speed_label)

	# Event log (bottom-left)
	event_log = RichTextLabel.new()
	event_log.offset_left = 10
	event_log.offset_top = -220
	event_log.offset_right = 350
	event_log.offset_bottom = -10
	event_log.anchors_preset = Control.PRESET_BOTTOM_LEFT
	event_log.bbcode_enabled = true
	event_log.scroll_following = true
	event_log.add_theme_font_size_override("normal_font_size", 12)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.8)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	event_log.add_theme_stylebox_override("normal", style)
	add_child(event_log)


func _connect_signals() -> void:
	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.stability_changed.connect(_on_stability_changed)
	EventBus.war_declared.connect(_on_war_declared)
	EventBus.hero_spawned.connect(_on_hero_spawned)
	EventBus.hero_died.connect(_on_hero_died)
	EventBus.golden_age_started.connect(_on_golden_age_started)
	EventBus.golden_age_ended.connect(_on_golden_age_ended)
	EventBus.technology_emerged.connect(_on_tech_emerged)
	EventBus.civilization_collapsed.connect(_on_civ_collapsed)
	EventBus.battle_resolved.connect(_on_battle_resolved)


func _update_display() -> void:
	var civ := GameState.get_civilization(player_civ_id)
	if not civ:
		return

	year_label.text = "Year: %d" % GameState.current_year
	stability_label.text = "Stability: %.0f" % civ.stability
	stability_bar.value = civ.stability
	food_label.text = "Food: %d" % civ.food_stockpile
	production_label.text = "Prod: %d" % civ.production_stockpile
	military_label.text = "Military: %.0f" % civ.military_strength


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("advance_year"):
		_on_advance_pressed()


func _on_advance_pressed() -> void:
	if TurnManager.is_processing:
		return
	TurnManager.advance_year()


func _on_speed_5x() -> void:
	if TurnManager.is_processing:
		return
	speed_label.text = "Fast forwarding 5 years..."
	fast_forward_target = 5
	fast_forward_count = 0
	_fast_forward_step()


func _on_speed_10x() -> void:
	if TurnManager.is_processing:
		return
	speed_label.text = "Fast forwarding 10 years..."
	fast_forward_target = 10
	fast_forward_count = 0
	_fast_forward_step()


func _on_speed_1x() -> void:
	fast_forward_target = 0
	speed_label.text = ""


func _fast_forward_step() -> void:
	if fast_forward_count >= fast_forward_target:
		speed_label.text = ""
		return

	TurnManager.advance_year()
	fast_forward_count += 1

	# Use deferred call for next step so UI can breathe
	if fast_forward_count < fast_forward_target:
		call_deferred("_fast_forward_step")
	else:
		speed_label.text = ""


func _on_turn_ended(_year: int) -> void:
	_update_display()


func _on_stability_changed(civ_id: int, _old: float, _new: float) -> void:
	if civ_id == player_civ_id:
		_update_display()


func _log(text: String) -> void:
	event_log.append_text("[color=#aaa]Y%d:[/color] %s\n" % [GameState.current_year, text])


func _on_war_declared(attacker_id: int, defender_id: int) -> void:
	var a := GameState.get_civilization(attacker_id)
	var d := GameState.get_civilization(defender_id)
	if a and d:
		_log("[color=#e55]%s declares war on %s![/color]" % [a.civ_name, d.civ_name])


func _on_hero_spawned(hero_id: int, civ_id: int, _type: Enums.HeroType) -> void:
	var hero := GameState.get_hero(hero_id)
	var civ := GameState.get_civilization(civ_id)
	if hero and civ:
		_log("[color=#5ce]%s gains hero: %s (%s)[/color]" % [
			civ.civ_name, hero.hero_name, Enums.HeroType.keys()[hero.type]
		])


func _on_hero_died(hero_id: int, civ_id: int) -> void:
	var civ := GameState.get_civilization(civ_id)
	if civ:
		_log("[color=#999]A hero of %s has died[/color]" % civ.civ_name)


func _on_golden_age_started(civ_id: int) -> void:
	var civ := GameState.get_civilization(civ_id)
	if civ:
		_log("[color=#fd5]%s enters a Golden Age![/color]" % civ.civ_name)


func _on_golden_age_ended(civ_id: int) -> void:
	var civ := GameState.get_civilization(civ_id)
	if civ:
		_log("[color=#a85]%s's Golden Age has ended[/color]" % civ.civ_name)


func _on_tech_emerged(civ_id: int, tech_name: String) -> void:
	var civ := GameState.get_civilization(civ_id)
	if civ:
		_log("[color=#5e5]%s discovers %s![/color]" % [civ.civ_name, tech_name])


func _on_civ_collapsed(civ_id: int) -> void:
	var civ := GameState.get_civilization(civ_id)
	if civ:
		_log("[color=#f33]%s has COLLAPSED![/color]" % civ.civ_name)


func _on_battle_resolved(region_id: int, attacker_id: int, _defender_id: int, winner_id: int) -> void:
	var region := GameState.get_region(region_id)
	var winner := GameState.get_civilization(winner_id)
	if region and winner:
		var result_text := "won" if winner_id == attacker_id else "defended"
		_log("%s %s battle for %s" % [winner.civ_name, result_text, region.region_name])
