extends Node

## Tutorial system: event-driven contextual tips for new players.
## Tracks which tips have been shown, queues tips, persists across save/load.

const TIPS := [
	{
		"id": "welcome",
		"title": "Welcome to Epoch Engine",
		"body": "You control a civilization evolving over thousands of years. Click any colored region on the map to see its details.",
		"priority": 0,
	},
	{
		"id": "advance_turn",
		"title": "Advancing Time",
		"body": "Press Space or click Next Year to advance one year. Press P to auto-play. Use 1/2/3 to change speed.",
		"priority": 1,
	},
	{
		"id": "region_panel",
		"title": "Region Details",
		"body": "This panel shows population, terrain, food yield, and infrastructure. Upgrade infrastructure with the button at the bottom.",
		"priority": 2,
	},
	{
		"id": "food_shortage",
		"title": "Food Shortage",
		"body": "Your civilization is running low on food! Food comes from your regions' terrain. Expanding to fertile land (River Basin, Plains) helps.",
		"priority": 3,
	},
	{
		"id": "stability_warning",
		"title": "Stability Dropping",
		"body": "Low stability increases collapse risk. Build infrastructure, avoid overexpansion, and maintain food surplus to stabilize.",
		"priority": 4,
	},
	{
		"id": "production_intro",
		"title": "Understanding Production",
		"body": "Production is your building resource. Each region produces it based on terrain and infrastructure level. Your military costs production upkeep every year. Expansion, infrastructure, and buildings also cost production. Build Workshops in towns or upgrade infrastructure to produce more.",
		"priority": 5,
	},
	{
		"id": "production_low",
		"title": "Production Running Low",
		"body": "Your production stockpile is getting low. Military upkeep drains production every year. To recover: avoid expanding or building until surplus grows, upgrade infrastructure in productive regions (Coastline, Volcanic, Plains), or set Spending Priority to 'Production' in your Civ Profile (C).",
		"priority": 6,
	},
	{
		"id": "expansion",
		"title": "Expanding Your Territory",
		"body": "Right-click an adjacent neutral region to claim it. Expansion costs production and transfers population from nearby regions.",
		"priority": 7,
	},
	{
		"id": "context_menu",
		"title": "Right-Click Actions",
		"body": "Right-click any region for actions: claim neutral territory, upgrade infrastructure, or view details.",
		"priority": 8,
	},
	{
		"id": "war_declared",
		"title": "War!",
		"body": "Another civilization has declared war. Battles happen automatically at borders. Military strength and supply lines determine outcomes.",
		"priority": 9,
	},
	{
		"id": "hero_spawned",
		"title": "A Hero Emerges",
		"body": "Heroes boost your civilization: Generals aid combat, Reformers improve diplomacy, Visionaries boost economy. They age and eventually pass.",
		"priority": 10,
	},
	{
		"id": "golden_age",
		"title": "Golden Age!",
		"body": "Your civilization entered a golden age! Growth and production bonuses apply. Golden ages trigger when stability and surplus are high.",
		"priority": 11,
	},
	{
		"id": "tech_discovered",
		"title": "Technology Discovered",
		"body": "Technologies emerge from pressure: knowledge, energy, social coordination. Press C to see your civilization profile and discovered techs.",
		"priority": 12,
	},
	{
		"id": "era_change",
		"title": "New Era",
		"body": "Your civilization advanced to a new era! Higher eras unlock advanced resources, buildings, and development tiers.",
		"priority": 13,
	},
	{
		"id": "diplomacy_hint",
		"title": "Diplomacy",
		"body": "Press D to open the Diplomacy panel. You can form alliances, declare war, or negotiate peace with other civilizations.",
		"priority": 14,
	},
	{
		"id": "civ_profile_hint",
		"title": "Civilization Profile",
		"body": "Press C to see your full civilization profile: economy, military, technologies, personality traits, and more.",
		"priority": 15,
	},
	{
		"id": "victory_hint",
		"title": "Paths to Victory",
		"body": "Press V to see victory progress. Win by Domination (70%+ regions), Culture (stability + techs), or Federation (all alliances). Avoid collapse!",
		"priority": 16,
	},
]

# Tip ID -> Dictionary lookup (built once in _ready)
var _tip_lookup: Dictionary = {}

# State
var shown_tips: Dictionary = {}
var tip_queue: Array[String] = []
var is_dismissed_all: bool = false


func _ready() -> void:
	# Build lookup
	for tip in TIPS:
		_tip_lookup[tip["id"]] = tip

	# Connect signals
	EventBus.region_selected.connect(_on_region_selected)
	EventBus.war_declared.connect(_on_war_declared)
	EventBus.hero_spawned.connect(_on_hero_spawned)
	EventBus.golden_age_started.connect(_on_golden_age_started)
	EventBus.technology_emerged.connect(_on_tech_emerged)
	EventBus.era_changed.connect(_on_era_changed)
	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.region_right_clicked.connect(_on_region_right_clicked)


func try_show_tip(tip_id: String) -> void:
	if is_dismissed_all or shown_tips.has(tip_id):
		return
	shown_tips[tip_id] = true
	tip_queue.append(tip_id)
	if tip_queue.size() == 1:
		_emit_current_tip()


func _emit_current_tip() -> void:
	if tip_queue.is_empty():
		return
	var tip_id: String = tip_queue[0]
	var tip_data: Dictionary = _tip_lookup.get(tip_id, {})
	if tip_data.is_empty():
		tip_queue.pop_front()
		_emit_current_tip()
		return
	EventBus.tutorial_tip_requested.emit(tip_data)


func on_tip_dismissed() -> void:
	if not tip_queue.is_empty():
		tip_queue.pop_front()
	_emit_current_tip()


func dismiss_all() -> void:
	is_dismissed_all = true
	tip_queue.clear()
	EventBus.tutorial_dismissed_all.emit()


func get_save_data() -> Dictionary:
	return {
		"shown_tips": shown_tips.duplicate(),
		"is_dismissed_all": is_dismissed_all,
	}


func load_save_data(data: Dictionary) -> void:
	shown_tips = data.get("shown_tips", {})
	is_dismissed_all = data.get("is_dismissed_all", false)
	tip_queue.clear()


# --- Signal handlers ---

func _on_region_selected(_region_id: int) -> void:
	try_show_tip("region_panel")


func _on_war_declared(_attacker_id: int, _defender_id: int) -> void:
	try_show_tip("war_declared")


func _on_hero_spawned(_hero_id: int, _civ_id: int, _hero_type: Enums.HeroType) -> void:
	try_show_tip("hero_spawned")


func _on_golden_age_started(_civ_id: int) -> void:
	try_show_tip("golden_age")


func _on_tech_emerged(_civ_id: int, _tech_name: String) -> void:
	try_show_tip("tech_discovered")


func _on_era_changed(_civ_id: int, _era_name: String) -> void:
	try_show_tip("era_change")


func _on_region_right_clicked(_region_id: int, _screen_pos: Vector2) -> void:
	try_show_tip("context_menu")


func _on_turn_ended(_year: int) -> void:
	var year := GameState.current_year

	# Year-based tips
	if year >= 3:
		try_show_tip("production_intro")
	if year >= 10:
		try_show_tip("diplomacy_hint")
	if year >= 15:
		try_show_tip("civ_profile_hint")
	if year >= 20:
		try_show_tip("victory_hint")

	# Condition-based tips
	var player_civ := GameState.get_civilization(GameState.player_civ_id)
	if not player_civ:
		return

	if player_civ.food_stockpile < 0:
		try_show_tip("food_shortage")
	if player_civ.production_stockpile < 20:
		try_show_tip("production_low")
	if player_civ.stability < 40.0:
		try_show_tip("stability_warning")

	# Check for adjacent neutral regions (expansion tip)
	if not shown_tips.has("expansion"):
		var player_regions := GameState.get_regions_by_owner(GameState.player_civ_id)
		for region in player_regions:
			for adj_id in region.adjacency_list:
				var adj_region := GameState.get_region(adj_id)
				if adj_region and adj_region.owner_id == -1:
					try_show_tip("expansion")
					return
