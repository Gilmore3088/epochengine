extends Node

## Save/load system using Godot Resource serialization.

const SAVE_DIR := "user://saves/"
const SAVE_EXTENSION := ".tres"


func _ready() -> void:
	_ensure_save_directory()


func save_game(slot_name: String) -> bool:
	## Saves the current game state to a slot.
	var save_data := _create_save_data()
	var save_path := SAVE_DIR + slot_name + SAVE_EXTENSION
	var error := ResourceSaver.save(save_data, save_path)

	if error == OK:
		return true
	else:
		push_error("Failed to save game: %s" % error)
		return false


func load_game(slot_name: String) -> bool:
	## Loads a game state from a slot.
	var save_path := SAVE_DIR + slot_name + SAVE_EXTENSION

	if not FileAccess.file_exists(save_path):
		push_error("Save file not found: %s" % save_path)
		return false

	var save_data: Resource = load(save_path)
	if not save_data:
		push_error("Failed to load save file")
		return false

	_restore_save_data(save_data)
	return true


func get_save_list() -> Array[String]:
	var saves: Array[String] = []
	var dir := DirAccess.open(SAVE_DIR)
	if not dir:
		return saves

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(SAVE_EXTENSION):
			saves.append(file_name.trim_suffix(SAVE_EXTENSION))
		file_name = dir.get_next()
	dir.list_dir_end()

	return saves


func delete_save(slot_name: String) -> bool:
	var save_path := SAVE_DIR + slot_name + SAVE_EXTENSION
	if FileAccess.file_exists(save_path):
		return DirAccess.remove_absolute(save_path) == OK
	return false


func _create_save_data() -> Resource:
	## Serialize all game state into a dictionary-based Resource.
	var save := Resource.new()
	save.set_meta("save_version", 1)
	save.set_meta("current_year", GameState.current_year)
	save.set_meta("next_hero_id", GameState.next_hero_id)
	save.set_meta("player_civ_id", GameState.player_civ_id)

	# Serialize regions
	var region_list: Array[Dictionary] = []
	for region in GameState.regions.values():
		region_list.append({
			"id": region.id,
			"region_name": region.region_name,
			"terrain_type": region.terrain_type,
			"population": region.population,
			"owner_id": region.owner_id,
			"food_yield": region.food_yield,
			"production_yield": region.production_yield,
			"defense_modifier": region.defense_modifier,
			"resource_stock": region.resource_stock,
			"adjacency_list": region.adjacency_list,
			"infrastructure_level": region.infrastructure_level,
		})
	save.set_meta("regions", region_list)

	# Serialize civilizations
	var civ_list: Array[Dictionary] = []
	for civ in GameState.civilizations.values():
		civ_list.append({
			"id": civ.id,
			"civ_name": civ.civ_name,
			"color": civ.color,
			"stability": civ.stability,
			"total_population": civ.total_population,
			"food_stockpile": civ.food_stockpile,
			"production_stockpile": civ.production_stockpile,
			"military_strength": civ.military_strength,
			"capital_region_id": civ.capital_region_id,
			"hero_ids": civ.hero_ids,
			"is_collapsed": civ.is_collapsed,
			"is_player": civ.is_player,
			"golden_age_years_remaining": civ.golden_age_years_remaining,
			"golden_age_cooldown": civ.golden_age_cooldown,
			"knowledge": civ.knowledge,
			"energy": civ.energy,
			"social_coordination": civ.social_coordination,
			"economic_surplus": civ.economic_surplus,
			"military_pressure": civ.military_pressure,
			"expansion_bias": civ.expansion_bias,
			"aggression_bias": civ.aggression_bias,
			"diplomacy_bias": civ.diplomacy_bias,
			"economy_bias": civ.economy_bias,
			"war_targets": civ.war_targets,
			"alliance_partners": civ.alliance_partners,
			"consecutive_low_stability_years": civ.consecutive_low_stability_years,
			"technologies": civ.technologies,
		})
	save.set_meta("civilizations", civ_list)

	# Serialize heroes
	var hero_list: Array[Dictionary] = []
	for hero in GameState.heroes.values():
		hero_list.append({
			"id": hero.id,
			"hero_name": hero.hero_name,
			"type": hero.type,
			"age": hero.age,
			"lifespan": hero.lifespan,
			"owner_civ_id": hero.owner_civ_id,
			"birth_year": hero.birth_year,
		})
	save.set_meta("heroes", hero_list)

	return save


func _restore_save_data(save: Resource) -> void:
	## Restore all game state from a save Resource.
	GameState.current_year = save.get_meta("current_year")
	GameState.next_hero_id = save.get_meta("next_hero_id")
	GameState.player_civ_id = save.get_meta("player_civ_id", 0)

	# Restore regions
	GameState.regions.clear()
	for data in save.get_meta("regions"):
		var region := RegionData.new()
		region.id = data["id"]
		region.region_name = data["region_name"]
		region.terrain_type = data["terrain_type"]
		region.population = data["population"]
		region.owner_id = data["owner_id"]
		region.food_yield = data["food_yield"]
		region.production_yield = data["production_yield"]
		region.defense_modifier = data["defense_modifier"]
		region.resource_stock = data["resource_stock"]
		region.adjacency_list = data["adjacency_list"]
		region.infrastructure_level = data["infrastructure_level"]
		GameState.regions[region.id] = region

	# Restore civilizations
	GameState.civilizations.clear()
	for data in save.get_meta("civilizations"):
		var civ := CivilizationData.new()
		civ.id = data["id"]
		civ.civ_name = data["civ_name"]
		civ.color = data["color"]
		civ.stability = data["stability"]
		civ.total_population = data["total_population"]
		civ.food_stockpile = data["food_stockpile"]
		civ.production_stockpile = data["production_stockpile"]
		civ.military_strength = data["military_strength"]
		civ.capital_region_id = data["capital_region_id"]
		civ.hero_ids = data["hero_ids"]
		civ.is_collapsed = data["is_collapsed"]
		civ.is_player = data.get("is_player", false)
		civ.golden_age_years_remaining = data["golden_age_years_remaining"]
		civ.golden_age_cooldown = data["golden_age_cooldown"]
		civ.knowledge = data["knowledge"]
		civ.energy = data["energy"]
		civ.social_coordination = data["social_coordination"]
		civ.economic_surplus = data["economic_surplus"]
		civ.military_pressure = data["military_pressure"]
		civ.expansion_bias = data["expansion_bias"]
		civ.aggression_bias = data["aggression_bias"]
		civ.diplomacy_bias = data["diplomacy_bias"]
		civ.economy_bias = data["economy_bias"]
		civ.war_targets = data["war_targets"]
		civ.alliance_partners = data["alliance_partners"]
		civ.consecutive_low_stability_years = data["consecutive_low_stability_years"]
		civ.technologies = data["technologies"]
		GameState.civilizations[civ.id] = civ

	# Restore heroes
	GameState.heroes.clear()
	for data in save.get_meta("heroes"):
		var hero := HeroData.new()
		hero.id = data["id"]
		hero.hero_name = data["hero_name"]
		hero.type = data["type"]
		hero.age = data["age"]
		hero.lifespan = data["lifespan"]
		hero.owner_civ_id = data["owner_civ_id"]
		hero.birth_year = data["birth_year"]
		GameState.heroes[hero.id] = hero


func _ensure_save_directory() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)
