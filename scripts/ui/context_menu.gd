extends PopupMenu

## Context menu for right-clicking regions on the map.
## Shows player actions based on the region's relationship to the player civ.

var target_region_id: int = -1

# Menu item IDs
const ITEM_DECLARE_WAR := 0
const ITEM_SEEK_PEACE := 1
const ITEM_SEEK_ALLIANCE := 2
const ITEM_UPGRADE_INFRA := 3
const ITEM_FOUND_TOWN := 4
const ITEM_CLAIM_REGION := 5


func _ready() -> void:
	id_pressed.connect(_on_item_pressed)
	EventBus.region_right_clicked.connect(show_for_region)
	_apply_theme()


func _apply_theme() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.07, 0.10, 0.95)
	panel_style.border_color = UITheme.GOLD_DIM
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(4)
	panel_style.set_content_margin_all(6)
	add_theme_stylebox_override("panel", panel_style)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.20, 0.17, 0.12, 0.90)
	hover_style.set_corner_radius_all(2)
	hover_style.set_content_margin_all(6)
	add_theme_stylebox_override("hover", hover_style)

	add_theme_font_override("font", UITheme.get_body_bold_font())
	add_theme_font_size_override("font_size", 14)
	add_theme_color_override("font_color", UITheme.PARCHMENT)
	add_theme_color_override("font_hover_color", UITheme.GOLD)
	add_theme_color_override("font_disabled_color", Color(0.4, 0.38, 0.35))


func show_for_region(region_id: int, screen_pos: Vector2) -> void:
	target_region_id = region_id
	clear()

	var region := GameState.get_region(region_id)
	if not region:
		return

	var player_civ := GameState.get_player_civ()
	if not player_civ or player_civ.is_collapsed:
		return

	_populate_menu(region, player_civ)

	if item_count > 0:
		position = Vector2i(int(screen_pos.x), int(screen_pos.y))
		popup()


func _populate_menu(region: RegionData, player_civ: CivilizationData) -> void:
	# No actions on regions the player can't see (fog of war)
	var vis := GameState.get_player_visibility(region.id)
	if vis != Enums.VisibilityState.VISIBLE:
		return

	var player_id := player_civ.id

	if region.owner_id == player_id:
		# Player owns this region
		if region.infrastructure_level < Constants.INFRASTRUCTURE_MAX_LEVEL:
			var cost := Constants.INFRASTRUCTURE_UPGRADE_COST * (region.infrastructure_level + 1)
			var can_afford := player_civ.production_stockpile >= cost
			add_item("Upgrade Infrastructure (-%d prod)" % cost, ITEM_UPGRADE_INFRA)
			if not can_afford:
				set_item_disabled(item_count - 1, true)
		if TownSimulation.can_found_town(region, player_civ):
			var town_cost := TownSimulation.calculate_town_cost(region)
			add_item("Found Town (-%d prod)" % town_cost, ITEM_FOUND_TOWN)
			if player_civ.production_stockpile < town_cost:
				set_item_disabled(item_count - 1, true)
		return

	if region.owner_id < 0:
		# Neutral region - offer claim if adjacent to player territory
		if _is_adjacent_to_player(region, player_civ):
			var region_count := GameState.get_regions_by_owner(player_id).size()
			var cost := EconomySimulation.calculate_expansion_cost(player_civ, region_count)
			var can_afford := EconomySimulation.can_afford_expansion(player_civ, region_count)
			add_item("Claim Region (-%d prod)" % cost, ITEM_CLAIM_REGION)
			if not can_afford:
				set_item_disabled(item_count - 1, true)
		return

	# Region belongs to another civ
	var owner_civ := GameState.get_civilization(region.owner_id)
	if not owner_civ or owner_civ.is_collapsed:
		return

	var owner_id := owner_civ.id

	if player_civ.war_targets.has(owner_id):
		add_item("Seek Peace with %s" % owner_civ.civ_name, ITEM_SEEK_PEACE)
	else:
		add_item("Declare War on %s" % owner_civ.civ_name, ITEM_DECLARE_WAR)
		if not player_civ.alliance_partners.has(owner_id):
			add_item("Propose Alliance with %s" % owner_civ.civ_name, ITEM_SEEK_ALLIANCE)


func _is_adjacent_to_player(region: RegionData, player_civ: CivilizationData) -> bool:
	for neighbor_id in region.adjacency_list:
		var neighbor := GameState.get_region(neighbor_id)
		if neighbor and neighbor.owner_id == player_civ.id:
			return true
	return false


func _on_item_pressed(id: int) -> void:
	var region := GameState.get_region(target_region_id)
	if not region:
		return

	var action: Dictionary
	match id:
		ITEM_DECLARE_WAR:
			action = {"type": "declare_war", "target_civ_id": region.owner_id}
		ITEM_SEEK_PEACE:
			action = {"type": "seek_peace", "target_civ_id": region.owner_id}
		ITEM_SEEK_ALLIANCE:
			action = {"type": "seek_alliance", "target_civ_id": region.owner_id}
		ITEM_UPGRADE_INFRA:
			action = {"type": "invest_infrastructure", "region_id": target_region_id}
		ITEM_FOUND_TOWN:
			action = {"type": "found_town", "region_id": target_region_id}
		ITEM_CLAIM_REGION:
			action = {"type": "claim_region", "region_id": target_region_id}
		_:
			return

	PlayerActions.queue_action(action)
	EventBus.player_action_queued.emit(action["type"], action)
