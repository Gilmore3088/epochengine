extends GutTest

## Tests for FutureSimulation (terraforming, space program, reclamation).


func _make_region(
	region_id: int,
	terrain: Enums.TerrainType = Enums.TerrainType.DESERT,
	owner_id: int = 0,
) -> RegionData:
	var region := RegionData.new(region_id, "Region_%d" % region_id, terrain)
	region.owner_id = owner_id
	region.population = 2000
	return region


func _make_future_civ(civ_id: int = 0) -> CivilizationData:
	var civ := CivilizationData.new(civ_id, "FutureCiv", Color.BLUE)
	civ.current_era = Enums.Epoch.FUTURE
	civ.capital_region_id = 0
	civ.stability = 60.0
	civ.production_stockpile = 500
	civ.knowledge = 90.0
	civ.technologies = ["fusion_research"]
	return civ


func before_each() -> void:
	GameState.regions.clear()
	GameState.civilizations.clear()


func test_terraform_desert_to_plains() -> void:
	var civ := _make_future_civ()
	var region := _make_region(0, Enums.TerrainType.DESERT, 0)
	GameState.regions[0] = region
	GameState.civilizations[0] = civ

	var success := FutureSimulation.start_terraform(civ, region, Enums.TerrainType.PLAINS)

	assert_true(success, "Should succeed terraforming desert to plains")
	assert_eq(region.terraform_target, int(Enums.TerrainType.PLAINS))
	assert_eq(region.terraform_years_remaining, Constants.TERRAFORM_DURATION)
	assert_eq(civ.production_stockpile, 500 - Constants.TERRAFORM_COST)


func test_terraform_requires_future_era() -> void:
	var civ := _make_future_civ()
	civ.current_era = Enums.Epoch.INDUSTRIAL
	var region := _make_region(0, Enums.TerrainType.DESERT, 0)
	GameState.regions[0] = region

	var success := FutureSimulation.start_terraform(civ, region, Enums.TerrainType.PLAINS)

	assert_false(success, "Should fail without Future era")


func test_terraform_invalid_target() -> void:
	var civ := _make_future_civ()
	var region := _make_region(0, Enums.TerrainType.JUNGLE, 0)
	GameState.regions[0] = region

	# Jungle is not a valid terraform source
	var success := FutureSimulation.start_terraform(civ, region, Enums.TerrainType.PLAINS)

	assert_false(success, "Should fail for invalid terrain source")


func test_terraform_completion() -> void:
	var region := _make_region(0, Enums.TerrainType.DESERT, 0)
	region.terraform_target = int(Enums.TerrainType.PLAINS)
	region.terraform_years_remaining = 1
	GameState.regions[0] = region

	var events := {"terraform_events": []}
	FutureSimulation.process_terraforming(events)

	assert_eq(region.terrain_type, int(Enums.TerrainType.PLAINS),
		"Terrain should change on completion")
	assert_eq(region.terraform_target, -1, "Target should reset")
	assert_eq(events["terraform_events"].size(), 1, "Should emit event")


func test_reclamation_coastal_only() -> void:
	var civ := _make_future_civ()
	var region := _make_region(0, Enums.TerrainType.PLAINS, 0)
	GameState.regions[0] = region

	var success := FutureSimulation.start_reclamation(civ, region)

	assert_false(success, "Reclamation should only work on coastline")


func test_reclamation_increases_size() -> void:
	var civ := _make_future_civ()
	var region := _make_region(0, Enums.TerrainType.COASTLINE, 0)
	var old_size := region.size_factor
	GameState.regions[0] = region

	var success := FutureSimulation.start_reclamation(civ, region)

	assert_true(success, "Should succeed for coastal region")
	assert_gt(region.size_factor, old_size, "Size factor should increase")
	assert_gt(region.reclamation_bonus, 0.0, "Reclamation bonus should be set")


func test_space_program_requires_tech() -> void:
	var civ := _make_future_civ()
	civ.technologies = []  # No fusion research
	GameState.civilizations[0] = civ

	var success := FutureSimulation.launch_space_program(civ)

	assert_false(success, "Should fail without fusion_research tech")


func test_space_program_reveals_all() -> void:
	var civ := _make_future_civ()
	GameState.civilizations[0] = civ
	GameState.regions[0] = _make_region(0, Enums.TerrainType.PLAINS, 0)
	GameState.regions[1] = _make_region(1, Enums.TerrainType.DESERT, -1)
	GameState.regions[2] = _make_region(2, Enums.TerrainType.MOUNTAINS, -1)

	var success := FutureSimulation.launch_space_program(civ)

	assert_true(success, "Should succeed with all requirements")
	assert_true(civ.explored_set.has(1), "Region 1 should be explored")
	assert_true(civ.explored_set.has(2), "Region 2 should be explored")
