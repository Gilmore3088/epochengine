extends Node

## Central game state. Holds all runtime data and provides lookup methods.

var current_year: int = 0
var game_speed: Enums.GameSpeed = Enums.GameSpeed.NORMAL
var is_running: bool = false
var current_overlay: int = Enums.MapOverlay.POLITICAL
var player_civ_id: int = 0
var map_config: MapConfig = MapConfig.new()

# Seeded RNG for deterministic simulation. All simulation randomness goes through this.
var sim_rng := RandomNumberGenerator.new()
var sim_seed: int = 0

# Core data dictionaries keyed by id
var regions: Dictionary = {}         # {int: RegionData}
var civilizations: Dictionary = {}   # {int: CivilizationData}
var heroes: Dictionary = {}          # {int: HeroData}
var units: Dictionary = {}           # {int: UnitData}
var region_hex_coords: Dictionary = {}  # {int: Vector2i}
var land_hex_coords: Array[Vector2i] = []
var starting_capital_ids: Array[int] = []
var pending_political_events: Array[Dictionary] = []
var next_political_event_id: int = 0

# Tracking
var next_hero_id: int = 0
var next_town_id: int = 0
var next_unit_id: int = 0
var turn_log: Array[Dictionary] = []  # Events logged this turn


func _ready() -> void:
	set_sim_seed(0)  # Default seed; benchmark/tests can override
	load_game_data()


func set_sim_seed(seed_value: int) -> void:
	## Set the simulation RNG seed. Use 0 for random seed.
	if seed_value == 0:
		sim_seed = randi()
	else:
		sim_seed = seed_value
	sim_rng.seed = sim_seed


func load_game_data() -> void:
	History.clear()
	pending_political_events.clear()
	next_political_event_id = 0
	_generate_regions()
	_load_civilizations()
	_assign_starting_capitals()
	_recalculate_civ_populations()


func start_new_game() -> void:
	## Called after player_civ_id is set (e.g. from PregameScreen).
	## Clears stale units and spawns fresh starting units for the chosen civ.
	units.clear()
	next_unit_id = 0
	current_year = 0
	turn_log.clear()
	pending_political_events.clear()
	next_political_event_id = 0
	_spawn_starting_units()


func _load_regions() -> void:
	var dir := DirAccess.open("res://data/regions/")
	if not dir:
		push_error("Cannot open regions directory")
		return

	# Collect and sort file names for deterministic load order
	var file_names: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			file_names.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	file_names.sort()

	for fname in file_names:
		var region: RegionData = ResourceLoader.load(
			"res://data/regions/" + fname, "", ResourceLoader.CACHE_MODE_IGNORE
		)
		if region:
			region.initialize_deposits()
			regions[region.id] = region


func _generate_regions() -> void:
	regions.clear()
	region_hex_coords.clear()
	land_hex_coords.clear()

	if map_config.seed == 0:
		map_config.seed = sim_seed

	var result: Dictionary = HexWorldGenerator.generate(map_config)
	regions = result.get("regions", {})
	region_hex_coords = result.get("hex_coords", {})
	land_hex_coords.clear()
	for coord in result.get("land_coords", []):
		if coord is Vector2i:
			land_hex_coords.append(coord)
	starting_capital_ids.clear()
	for cid in result.get("capital_ids", []):
		starting_capital_ids.append(int(cid))


func _assign_starting_capitals() -> void:
	if regions.is_empty() or civilizations.is_empty():
		return

	var capital_ids: Array[int] = starting_capital_ids
	if capital_ids.is_empty():
		capital_ids = HexWorldGenerator.pick_starting_capitals(regions, region_hex_coords, map_config)

	var civ_ids: Array[int] = []
	for key in civilizations.keys():
		civ_ids.append(int(key))
	civ_ids.sort()
	for i in civ_ids.size():
		if i >= capital_ids.size():
			break
		var civ: CivilizationData = civilizations[civ_ids[i]]
		var region_id := capital_ids[i]
		civ.capital_region_id = region_id
		var region: RegionData = regions.get(region_id)
		if region:
			region.owner_id = civ.id


func _load_civilizations() -> void:
	var dir := DirAccess.open("res://data/civilizations/")
	if not dir:
		push_error("Cannot open civilizations directory")
		return

	# Collect and sort file names for deterministic load order
	var file_names: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			file_names.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	file_names.sort()

	for fname in file_names:
		var civ: CivilizationData = ResourceLoader.load(
			"res://data/civilizations/" + fname, "", ResourceLoader.CACHE_MODE_IGNORE
		)
		if civ:
			PoliticalEvents.ensure_civ_state(civ)
			civilizations[civ.id] = civ


func queue_political_event(event: Dictionary) -> void:
	pending_political_events.append(event)


func pop_next_political_event() -> Dictionary:
	if pending_political_events.is_empty():
		return {}
	return pending_political_events.pop_front()


func _recalculate_civ_populations() -> void:
	for civ in civilizations.values():
		civ.total_population = 0
	for region in regions.values():
		if region.owner_id >= 0 and civilizations.has(region.owner_id):
			civilizations[region.owner_id].total_population += region.population


func _spawn_starting_units() -> void:
	## Spawn default starting units for the player civ at their capital.
	## Until the pre-game screen is implemented, use default leader traits.
	if units.size() > 0:
		return  # Already have units (e.g. loaded from save)
	var player_civ := get_civilization(player_civ_id)
	if not player_civ:
		return
	var capital_id := player_civ.capital_region_id

	# Worker at capital
	var worker := UnitData.new(-1, Constants.WORKER_NAME_POOL[0], Enums.UnitType.WORKER, player_civ_id, capital_id)
	add_unit(worker)

	# Explorer at capital
	var explorer := UnitData.new(-1, Constants.EXPLORER_NAME_POOL[0], Enums.UnitType.EXPLORER, player_civ_id, capital_id)
	add_unit(explorer)

	# Leader at capital with default traits (Builder + Merchant)
	var leader := UnitData.new(-1, "Leader", Enums.UnitType.LEADER, player_civ_id, capital_id)
	leader.leader_trait_a = 0  # Builder: +10% production
	leader.leader_trait_b = 4  # Merchant: +10% food
	add_unit(leader)


# --- Region Lookups ---

func get_region(region_id: int) -> RegionData:
	return regions.get(region_id)


func get_regions_by_owner(owner_id: int) -> Array[RegionData]:
	var result: Array[RegionData] = []
	for region in regions.values():
		if region.owner_id == owner_id:
			result.append(region)
	return result


func get_neutral_regions() -> Array[RegionData]:
	return get_regions_by_owner(-1)


func get_border_regions(civ_id: int) -> Array[RegionData]:
	## Returns regions owned by civ_id that are adjacent to regions not owned by civ_id.
	var result: Array[RegionData] = []
	for region in get_regions_by_owner(civ_id):
		for neighbor_id in region.adjacency_list:
			var neighbor := get_region(neighbor_id)
			if neighbor and neighbor.owner_id != civ_id:
				result.append(region)
				break
	return result


func get_adjacent_targets(civ_id: int) -> Array[RegionData]:
	## Returns regions NOT owned by civ_id that are adjacent to civ_id territory.
	var targets: Dictionary = {}
	for region in get_regions_by_owner(civ_id):
		for neighbor_id in region.adjacency_list:
			var neighbor := get_region(neighbor_id)
			if neighbor and neighbor.owner_id != civ_id:
				targets[neighbor_id] = neighbor
	var result: Array[RegionData] = []
	for val in targets.values():
		if val is RegionData:
			result.append(val)
	return result


# --- Civilization Lookups ---

func get_civilization(civ_id: int) -> CivilizationData:
	return civilizations.get(civ_id)


func get_alive_civilizations() -> Array[CivilizationData]:
	var result: Array[CivilizationData] = []
	for civ in civilizations.values():
		if not civ.is_collapsed:
			result.append(civ)
	return result


func get_neighboring_civs(civ_id: int) -> Array[int]:
	## Returns IDs of civilizations that share a border with civ_id.
	var neighbor_civ_ids: Dictionary = {}
	for region in get_regions_by_owner(civ_id):
		for neighbor_id in region.adjacency_list:
			var neighbor := get_region(neighbor_id)
			if neighbor and neighbor.owner_id >= 0 and neighbor.owner_id != civ_id:
				neighbor_civ_ids[neighbor.owner_id] = true
	var result: Array[int] = []
	for key in neighbor_civ_ids.keys():
		result.append(int(key))
	return result


# --- Hero Lookups ---

func get_hero(hero_id: int) -> HeroData:
	return heroes.get(hero_id)


func get_heroes_by_civ(civ_id: int) -> Array[HeroData]:
	var result: Array[HeroData] = []
	for hero in heroes.values():
		if hero.owner_civ_id == civ_id:
			result.append(hero)
	return result


func add_hero(hero: HeroData) -> void:
	hero.id = next_hero_id
	next_hero_id += 1
	heroes[hero.id] = hero


func remove_hero(hero_id: int) -> void:
	heroes.erase(hero_id)


# --- Unit Lookups ---

func get_unit(unit_id: int) -> UnitData:
	return units.get(unit_id)


func get_units_by_civ(civ_id: int) -> Array[UnitData]:
	var result: Array[UnitData] = []
	for unit in units.values():
		if unit.owner_civ_id == civ_id:
			result.append(unit)
	return result


func get_units_in_region(region_id: int) -> Array[UnitData]:
	var result: Array[UnitData] = []
	for unit in units.values():
		if unit.region_id == region_id:
			result.append(unit)
	return result


func add_unit(unit: UnitData) -> void:
	unit.id = next_unit_id
	next_unit_id += 1
	units[unit.id] = unit


func remove_unit(unit_id: int) -> void:
	units.erase(unit_id)


# --- Turn Logging ---

func log_event(event_type: String, details: Dictionary = {}) -> void:
	turn_log.append({
		"year": current_year,
		"type": event_type,
		"details": details,
	})


func clear_turn_log() -> void:
	turn_log.clear()


# --- Overlay ---

func set_overlay(overlay: int) -> void:
	if current_overlay != overlay:
		current_overlay = overlay
		EventBus.overlay_changed.emit(overlay)


# --- Player ---

func get_player_civ() -> CivilizationData:
	return civilizations.get(player_civ_id)


func is_player_civ(civ_id: int) -> bool:
	return civ_id == player_civ_id


# --- Visibility (Fog of War) ---

func get_visibility(civ_id: int, region_id: int) -> Enums.VisibilityState:
	var civ := get_civilization(civ_id)
	if not civ:
		return Enums.VisibilityState.HIDDEN
	if civ.visible_regions.has(region_id):
		return Enums.VisibilityState.VISIBLE
	if civ.explored_set.has(region_id):
		return Enums.VisibilityState.EXPLORED
	return Enums.VisibilityState.HIDDEN


func get_player_visibility(region_id: int) -> Enums.VisibilityState:
	return get_visibility(player_civ_id, region_id)


func update_visibility(civ_id: int) -> void:
	## Recompute visible and explored regions for a civilization.
	## Owned regions + neighbors (depth based on cartography skill) are VISIBLE.
	## All visible become permanently EXPLORED.
	var civ := get_civilization(civ_id)
	if not civ:
		return
	civ.visible_regions.clear()

	# Determine reveal depth based on cartography skill
	var reveal_depth := 1
	var thresholds: Array = Constants.CARTOGRAPHY_REVEAL_THRESHOLDS
	for i in range(thresholds.size() - 1, -1, -1):
		if civ.cartography_skill >= thresholds[i]:
			reveal_depth = i + 1
			break

	# Owned regions are always visible; flood-fill neighbors to reveal_depth
	for region in get_regions_by_owner(civ_id):
		_flood_reveal(civ, region.id, reveal_depth)

	# Explorer units grant visibility at their position + adjacent (depth 1 extra)
	for unit in units.values():
		if unit.owner_civ_id == civ_id and unit.is_explorer() and unit.region_id >= 0:
			_flood_reveal(civ, unit.region_id, reveal_depth)

	# All visible regions become permanently explored
	for region_id in civ.visible_regions:
		if not civ.explored_set.has(region_id):
			civ.explored_regions.append(region_id)
			civ.explored_set[region_id] = true


func _flood_reveal(civ: CivilizationData, start_id: int, max_depth: int) -> void:
	## BFS flood-fill visibility from start_id out to max_depth hops.
	var queue: Array = [[start_id, 0]]
	var visited: Dictionary = {}

	while not queue.is_empty():
		var entry: Array = queue.pop_front()
		var rid: int = entry[0]
		var depth: int = entry[1]

		if visited.has(rid):
			continue
		visited[rid] = true
		civ.visible_regions[rid] = true

		if depth < max_depth:
			var region := get_region(rid)
			if region:
				for neighbor_id in region.adjacency_list:
					if not visited.has(neighbor_id):
						queue.append([neighbor_id, depth + 1])


func update_all_visibility() -> void:
	## Update visibility for the player civ (AI doesn't need fog in V0.1).
	update_visibility(player_civ_id)


func reset_visibility() -> void:
	## Clear all visibility state. Call on game reset / "Play Again".
	for civ in civilizations.values():
		civ.explored_regions.clear()
		civ.explored_set.clear()
		civ.visible_regions.clear()
