extends Node

## Central game state. Holds all runtime data and provides lookup methods.

var current_year: int = 0
var game_speed: Enums.GameSpeed = Enums.GameSpeed.NORMAL
var is_running: bool = false

# Core data dictionaries keyed by id
var regions: Dictionary = {}         # {int: RegionData}
var civilizations: Dictionary = {}   # {int: CivilizationData}
var heroes: Dictionary = {}          # {int: HeroData}

# Tracking
var next_hero_id: int = 0
var turn_log: Array[Dictionary] = []  # Events logged this turn


func _ready() -> void:
	load_game_data()


func load_game_data() -> void:
	_load_regions()
	_load_civilizations()
	_recalculate_civ_populations()


func _load_regions() -> void:
	var dir := DirAccess.open("res://data/regions/")
	if not dir:
		push_error("Cannot open regions directory")
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var region: RegionData = load("res://data/regions/" + file_name)
			if region:
				regions[region.id] = region
		file_name = dir.get_next()
	dir.list_dir_end()


func _load_civilizations() -> void:
	var dir := DirAccess.open("res://data/civilizations/")
	if not dir:
		push_error("Cannot open civilizations directory")
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var civ: CivilizationData = load("res://data/civilizations/" + file_name)
			if civ:
				civilizations[civ.id] = civ
		file_name = dir.get_next()
	dir.list_dir_end()


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
	return Array(targets.values(), TYPE_OBJECT, "RefCounted", RegionData)


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
	return Array(neighbor_civ_ids.keys(), TYPE_INT, "", null)


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
