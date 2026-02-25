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

	History.clear()
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
	save.set_meta("next_town_id", GameState.next_town_id)
	save.set_meta("next_unit_id", GameState.next_unit_id)
	save.set_meta("player_civ_id", GameState.player_civ_id)
	save.set_meta("map_size", GameState.map_config.map_size)
	save.set_meta("map_seed", GameState.map_config.seed)

	# Serialize hex coordinates
	var coord_list: Array[Dictionary] = []
	for region_id in GameState.region_hex_coords:
		var coord: Vector2i = GameState.region_hex_coords[region_id]
		coord_list.append({
			"id": region_id,
			"q": coord.x,
			"r": coord.y,
		})
	save.set_meta("region_hex_coords", coord_list)

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
			"development_tier": region.development_tier,
			"demotion_years": region.demotion_years,
			"size_factor": region.size_factor,
			"urbanization_level": region.urbanization_level,
			"towns": _serialize_towns(region.towns),
			"supply_value": region.supply_value,
			"resource_deposits": region.resource_deposits,
			"extraction_years": region.extraction_years,
			"renewable_degradation": region.renewable_degradation,
			"has_river": region.has_river,
			"river_connections": region.river_connections,
			"has_lake": region.has_lake,
			"elevation": region.elevation,
			"moisture": region.moisture,
			"flow_accum": region.flow_accum,
			"basin_id": region.basin_id,
			"active_disaster": region.active_disaster,
			"disaster_years_remaining": region.disaster_years_remaining,
			"disaster_yield_penalty": region.disaster_yield_penalty,
			"governor_focus": region.governor_focus,
			"political_influence": region.political_influence,
			"lobby_request": region.lobby_request,
			"lobby_ignore_years": region.lobby_ignore_years,
			"terraform_target": region.terraform_target,
			"terraform_years_remaining": region.terraform_years_remaining,
			"reclamation_bonus": region.reclamation_bonus,
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
			"governance_tier": civ.governance_tier,
			"governance_years": civ.governance_years,
			"current_era": civ.current_era,
			"legitimacy": civ.legitimacy,
			"government_form": civ.government_form,
			"succession_law": civ.succession_law,
			"dynasty_name": civ.dynasty_name,
			"ruler_name": civ.ruler_name,
			"ruler_age": civ.ruler_age,
			"ruler_lifespan": civ.ruler_lifespan,
			"heir_name": civ.heir_name,
			"heir_age": civ.heir_age,
			"years_since_election": civ.years_since_election,
			"election_interval": civ.election_interval,
			"power_blocs": civ.power_blocs,
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
			"war_durations": civ.war_durations,
			"peace_cooldowns": civ.peace_cooldowns,
			"alliance_partners": civ.alliance_partners,
			"consecutive_low_stability_years": civ.consecutive_low_stability_years,
			"technologies": civ.technologies,
			"resource_stockpiles": civ.resource_stockpiles,
			"resource_production_log": civ.resource_production_log,
			"research_focus": civ.research_focus,
			"research_focus_cooldown": civ.research_focus_cooldown,
			"spending_priority": civ.spending_priority,
			"spending_priority_cooldown": civ.spending_priority_cooldown,
			"explored_regions": civ.explored_regions,
			"initial_expansion_bias": civ.initial_expansion_bias,
			"initial_aggression_bias": civ.initial_aggression_bias,
			"initial_diplomacy_bias": civ.initial_diplomacy_bias,
			"initial_economy_bias": civ.initial_economy_bias,
			"years_at_peace": civ.years_at_peace,
			"nap_partners": civ.nap_partners,
			"trade_partners": civ.trade_partners,
			"tribute_cooldowns": civ.tribute_cooldowns,
			"cartography_skill": civ.cartography_skill,
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

	# Serialize units
	var unit_list: Array[Dictionary] = []
	for unit in GameState.units.values():
		unit_list.append(unit.to_dict())
	save.set_meta("units", unit_list)

	# Tutorial state
	save.set_meta("tutorial", TutorialManager.get_save_data())

	return save


func _restore_save_data(save: Resource) -> void:
	## Restore all game state from a save Resource.
	GameState.current_year = save.get_meta("current_year")
	GameState.next_hero_id = save.get_meta("next_hero_id")
	GameState.next_town_id = save.get_meta("next_town_id", 0)
	GameState.next_unit_id = save.get_meta("next_unit_id", 0)
	GameState.player_civ_id = save.get_meta("player_civ_id", 0)
	if save.has_meta("map_size"):
		GameState.map_config.map_size = save.get_meta("map_size", Enums.MapSize.MEDIUM)
	if save.has_meta("map_seed"):
		GameState.map_config.seed = save.get_meta("map_seed", 0)

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
		region.development_tier = data.get("development_tier", 0)
		region.demotion_years = data.get("demotion_years", 0)
		region.size_factor = data.get("size_factor", 1.0)
		region.urbanization_level = data.get("urbanization_level", 0.0)
		region.towns = _deserialize_towns(data.get("towns", []))
		region.supply_value = data.get("supply_value", 1.0)
		region.resource_deposits = data.get("resource_deposits", {})
		region.extraction_years = data.get("extraction_years", 0)
		region.renewable_degradation = data.get("renewable_degradation", 0.0)
		region.has_river = data.get("has_river", false)
		region.river_connections = data.get("river_connections", [])
		region.has_lake = data.get("has_lake", false)
		region.elevation = data.get("elevation", 0)
		region.moisture = data.get("moisture", 0.0)
		region.flow_accum = data.get("flow_accum", 0.0)
		region.basin_id = data.get("basin_id", -1)
		region.active_disaster = data.get("active_disaster", -1)
		region.disaster_years_remaining = data.get("disaster_years_remaining", 0)
		region.disaster_yield_penalty = data.get("disaster_yield_penalty", 0.0)
		region.governor_focus = data.get("governor_focus", 0)
		region.political_influence = data.get("political_influence", 0.0)
		region.lobby_request = data.get("lobby_request", -1)
		region.lobby_ignore_years = data.get("lobby_ignore_years", 0)
		region.terraform_target = data.get("terraform_target", -1)
		region.terraform_years_remaining = data.get("terraform_years_remaining", 0)
		region.reclamation_bonus = data.get("reclamation_bonus", 0.0)
		GameState.regions[region.id] = region

	# Restore hex coordinates
	GameState.region_hex_coords.clear()
	GameState.land_hex_coords.clear()
	for entry in save.get_meta("region_hex_coords", []):
		var rid: int = int(entry["id"])
		var coord := Vector2i(entry["q"], entry["r"])
		GameState.region_hex_coords[rid] = coord
		GameState.land_hex_coords.append(coord)

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
		civ.hero_ids.assign(data.get("hero_ids", []))
		civ.is_collapsed = data["is_collapsed"]
		civ.is_player = data.get("is_player", false)
		civ.governance_tier = data.get("governance_tier", Enums.GovernanceTier.TRIBAL)
		civ.governance_years = data.get("governance_years", 0)
		civ.current_era = data.get("current_era", Enums.Epoch.PREHISTORIC)
		civ.legitimacy = data.get("legitimacy", Constants.LEGITIMACY_START)
		civ.government_form = data.get("government_form", Enums.GovernmentForm.TRIBAL)
		civ.succession_law = data.get("succession_law", Enums.SuccessionLaw.PRIMOGENITURE)
		civ.dynasty_name = data.get("dynasty_name", "")
		civ.ruler_name = data.get("ruler_name", "")
		civ.ruler_age = data.get("ruler_age", 30)
		civ.ruler_lifespan = data.get("ruler_lifespan", 70)
		civ.heir_name = data.get("heir_name", "")
		civ.heir_age = data.get("heir_age", 12)
		civ.years_since_election = data.get("years_since_election", 0)
		civ.election_interval = data.get("election_interval", Constants.DEFAULT_ELECTION_INTERVAL)
		civ.power_blocs = data.get("power_blocs", {})
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
		civ.war_targets.assign(data.get("war_targets", []))
		civ.war_durations = data.get("war_durations", {})
		civ.peace_cooldowns = data.get("peace_cooldowns", {})
		civ.alliance_partners.assign(data.get("alliance_partners", []))
		civ.consecutive_low_stability_years = data["consecutive_low_stability_years"]
		civ.technologies.assign(data.get("technologies", []))
		civ.resource_stockpiles = data.get("resource_stockpiles", {})
		civ.resource_production_log = data.get("resource_production_log", {})
		civ.research_focus = data.get("research_focus", 0)
		civ.research_focus_cooldown = data.get("research_focus_cooldown", 0)
		civ.spending_priority = data.get("spending_priority", 0)
		civ.spending_priority_cooldown = data.get("spending_priority_cooldown", 0)
		# Trait evolution tracking
		civ.initial_expansion_bias = data.get("initial_expansion_bias", -1.0)
		civ.initial_aggression_bias = data.get("initial_aggression_bias", -1.0)
		civ.initial_diplomacy_bias = data.get("initial_diplomacy_bias", -1.0)
		civ.initial_economy_bias = data.get("initial_economy_bias", -1.0)
		civ.years_at_peace = data.get("years_at_peace", 0)
		civ.nap_partners = data.get("nap_partners", {})
		civ.trade_partners.assign(data.get("trade_partners", []))
		civ.tribute_cooldowns = data.get("tribute_cooldowns", {})
		civ.cartography_skill = data.get("cartography_skill", 0.0)
		PoliticalEvents.ensure_civ_state(civ)
		# Fog of war: restore explored regions and rebuild O(1) lookup cache
		var saved_explored: Array = data.get("explored_regions", [])
		civ.explored_regions.clear()
		civ.explored_set.clear()
		if saved_explored.is_empty() and GameState.current_year > 1:
			# Old save migration: pre-fog saves get all regions marked explored
			for region_id in GameState.regions:
				civ.explored_regions.append(region_id)
				civ.explored_set[region_id] = true
		else:
			for rid in saved_explored:
				civ.explored_regions.append(rid)
				civ.explored_set[rid] = true
		GameState.civilizations[civ.id] = civ

	# Restore tutorial state
	TutorialManager.load_save_data(save.get_meta("tutorial") if save.has_meta("tutorial") else {})

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

	# Restore units
	GameState.units.clear()
	for data in save.get_meta("units", []):
		var unit := UnitData.from_dict(data)
		GameState.units[unit.id] = unit


func _serialize_towns(towns: Array) -> Array:
	var result: Array[Dictionary] = []
	for town in towns:
		if town is TownData:
			result.append(town.to_dict())
	return result


func _deserialize_towns(data: Array) -> Array:
	var result: Array = []
	for entry in data:
		if entry is Dictionary:
			result.append(TownData.from_dict(entry))
	return result


func _ensure_save_directory() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)
