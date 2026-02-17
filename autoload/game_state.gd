extends Node

## Central game state. Holds all runtime data and provides lookup methods.

var current_year: int = 0
var game_speed: Enums.GameSpeed = Enums.GameSpeed.NORMAL
var is_running: bool = false
var current_overlay: int = Enums.MapOverlay.POLITICAL
var player_civ_id: int = 0

# Seeded RNG for deterministic simulation. All simulation randomness goes through this.
var sim_rng := RandomNumberGenerator.new()
var sim_seed: int = 0

# Core data dictionaries keyed by id
var regions: Dictionary = {}         # {int: RegionData}
var civilizations: Dictionary = {}   # {int: CivilizationData}
var heroes: Dictionary = {}          # {int: HeroData}

# Tracking
var next_hero_id: int = 0
var next_town_id: int = 0
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
	_load_regions()
	_load_civilizations()
	_recalculate_civ_populations()


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
			civilizations[civ.id] = civ


func _recalculate_civ_populations() -> void:
	for civ in civilizations.values():
		civ.total_population = 0
	for region in regions.values():
		if region.owner_id >= 0 and civilizations.has(region.owner_id):
			civilizations[region.owner_id].total_population += region.population


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
	result.assign(targets.values())
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
	result.assign(neighbor_civ_ids.keys())
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
	## Owned regions + their neighbors are VISIBLE. All visible become permanently EXPLORED.
	var civ := get_civilization(civ_id)
	if not civ:
		return
	civ.visible_regions.clear()
	# Owned regions are always visible
	for region in get_regions_by_owner(civ_id):
		civ.visible_regions[region.id] = true
		# Adjacent regions are also visible
		for neighbor_id in region.adjacency_list:
			civ.visible_regions[neighbor_id] = true
	# All visible regions become permanently explored
	for region_id in civ.visible_regions:
		if not civ.explored_set.has(region_id):
			civ.explored_regions.append(region_id)
			civ.explored_set[region_id] = true


func update_all_visibility() -> void:
	## Update visibility for the player civ (AI doesn't need fog in V0.1).
	update_visibility(player_civ_id)


func reset_visibility() -> void:
	## Clear all visibility state. Call on game reset / "Play Again".
	for civ in civilizations.values():
		civ.explored_regions.clear()
		civ.explored_set.clear()
		civ.visible_regions.clear()
