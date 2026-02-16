extends PopupMenu

## Context menu for right-clicking regions on the map.
## Shows player actions based on the region's relationship to the player civ.

var target_region_id: int = -1

# Menu item IDs
const ITEM_DECLARE_WAR := 0
const ITEM_SEEK_PEACE := 1
const ITEM_SEEK_ALLIANCE := 2
const ITEM_UPGRADE_INFRA := 3


func _ready() -> void:
	id_pressed.connect(_on_item_pressed)
	EventBus.region_right_clicked.connect(show_for_region)


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
	var player_id := player_civ.id

	if region.owner_id == player_id:
		# Player owns this region
		if region.infrastructure_level < Constants.INFRASTRUCTURE_MAX_LEVEL:
			var cost := Constants.INFRASTRUCTURE_UPGRADE_COST * (region.infrastructure_level + 1)
			var can_afford := player_civ.production_stockpile >= cost
			add_item("Upgrade Infrastructure (-%d prod)" % cost, ITEM_UPGRADE_INFRA)
			if not can_afford:
				set_item_disabled(item_count - 1, true)
		return

	if region.owner_id < 0:
		# Neutral region - no actions available
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
		_:
			return

	PlayerActions.queue_action(action)
	EventBus.player_action_queued.emit(action["type"], action)
