class_name FutureSimulation
extends RefCounted

## Future era simulation: terraforming, space program, land reclamation.
## Only active for civs in the FUTURE era.


static func process_terraforming(events: Dictionary) -> void:
	## Tick down active terraforming projects and apply terrain changes.
	if not events.has("terraform_events"):
		events["terraform_events"] = []

	for region in GameState.regions.values():
		if region.terraform_target < 0:
			continue
		region.terraform_years_remaining -= 1
		if region.terraform_years_remaining <= 0:
			var old_terrain: int = region.terrain_type
			region.terrain_type = region.terraform_target
			region.terraform_target = -1
			# Recalculate base yields for new terrain
			_recalculate_terrain_yields(region)
			events["terraform_events"].append({
				"region_id": region.id,
				"region_name": region.region_name,
				"old_terrain": old_terrain,
				"new_terrain": region.terrain_type,
				"owner_id": region.owner_id,
			})


static func start_terraform(
	civ: CivilizationData, region: RegionData, target_terrain: int
) -> bool:
	## Start terraforming a region. Returns true if successful.
	if civ.current_era != Enums.Epoch.FUTURE:
		return false
	if region.owner_id != civ.id:
		return false
	if region.terraform_target >= 0:
		return false  # Already terraforming
	if not Constants.TERRAFORM_TARGETS.has(region.terrain_type):
		return false
	var valid_targets: Array = Constants.TERRAFORM_TARGETS[region.terrain_type]
	if not valid_targets.has(target_terrain):
		return false
	if civ.production_stockpile < Constants.TERRAFORM_COST:
		return false

	civ.production_stockpile -= Constants.TERRAFORM_COST
	region.terraform_target = target_terrain
	region.terraform_years_remaining = Constants.TERRAFORM_DURATION
	return true


static func start_reclamation(civ: CivilizationData, region: RegionData) -> bool:
	## Start land reclamation on a coastal region.
	if civ.current_era != Enums.Epoch.FUTURE:
		return false
	if region.owner_id != civ.id:
		return false
	if region.terrain_type != Enums.TerrainType.COASTLINE:
		return false
	if region.reclamation_bonus >= Constants.RECLAMATION_MAX_BONUS:
		return false
	if civ.production_stockpile < Constants.RECLAMATION_COST:
		return false

	civ.production_stockpile -= Constants.RECLAMATION_COST
	region.reclamation_bonus += Constants.RECLAMATION_SIZE_BONUS
	region.reclamation_bonus = minf(region.reclamation_bonus, Constants.RECLAMATION_MAX_BONUS)
	region.size_factor += Constants.RECLAMATION_SIZE_BONUS
	return true


static func launch_space_program(civ: CivilizationData) -> bool:
	## Launch space program: reveal entire map. Requires Future era + knowledge + production.
	if civ.current_era != Enums.Epoch.FUTURE:
		return false
	if civ.knowledge < Constants.SPACE_PROGRAM_KNOWLEDGE_REQ:
		return false
	if civ.production_stockpile < Constants.SPACE_PROGRAM_PROD_COST:
		return false
	if not civ.technologies.has("fusion_research"):
		return false

	civ.production_stockpile -= Constants.SPACE_PROGRAM_PROD_COST

	# Reveal entire map
	for region_id in GameState.regions:
		if not civ.explored_set.has(region_id):
			civ.explored_regions.append(region_id)
			civ.explored_set[region_id] = true
		civ.visible_regions[region_id] = true

	return true


static func _recalculate_terrain_yields(region: RegionData) -> void:
	## Reset base yields after terrain change.
	var terrain_yields := {
		Enums.TerrainType.RIVER_BASIN: [6, 3],
		Enums.TerrainType.PLAINS: [5, 4],
		Enums.TerrainType.MOUNTAINS: [1, 6],
		Enums.TerrainType.DESERT: [2, 2],
		Enums.TerrainType.JUNGLE: [4, 3],
		Enums.TerrainType.COASTLINE: [4, 3],
		Enums.TerrainType.TUNDRA: [2, 2],
		Enums.TerrainType.STEPPE: [3, 4],
		Enums.TerrainType.VOLCANIC_RIDGE: [1, 5],
	}
	var yields: Array = terrain_yields.get(region.terrain_type, [3, 3])
	region.food_yield = yields[0]
	region.production_yield = yields[1]
	# Update elevation for new terrain
	region.elevation = Constants.ELEVATION_BY_TERRAIN.get(region.terrain_type, 0)
