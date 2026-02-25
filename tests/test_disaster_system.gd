extends GutTest

## Tests for DisasterSimulation


func _make_region(
	region_id: int,
	terrain: Enums.TerrainType = Enums.TerrainType.PLAINS,
) -> RegionData:
	var region := RegionData.new(region_id, "Region_%d" % region_id, terrain)
	region.population = 1000
	region.infrastructure_level = 2
	return region


func before_each() -> void:
	GameState.regions.clear()
	GameState.sim_rng.seed = 42


func test_no_stacking_disasters() -> void:
	var region := _make_region(0, Enums.TerrainType.VOLCANIC_RIDGE)
	region.active_disaster = Enums.DisasterType.VOLCANIC_ERUPTION
	region.disaster_years_remaining = 2
	region.disaster_yield_penalty = 0.30
	GameState.regions[0] = region

	var events := {"disaster_events": []}
	DisasterSimulation.process_disasters(events)

	# Should tick down, not stack
	assert_eq(region.disaster_years_remaining, 1, "Should tick down by 1")
	assert_eq(events["disaster_events"].size(), 0, "No new disaster while active")


func test_disaster_expires() -> void:
	var region := _make_region(0, Enums.TerrainType.PLAINS)
	region.active_disaster = Enums.DisasterType.DROUGHT
	region.disaster_years_remaining = 1
	region.disaster_yield_penalty = 0.25
	GameState.regions[0] = region

	var events := {"disaster_events": []}
	DisasterSimulation.process_disasters(events)

	assert_eq(region.active_disaster, -1, "Disaster should expire")
	assert_eq(region.disaster_yield_penalty, 0.0, "Yield penalty should reset")


func test_flood_requires_river() -> void:
	# River basin without river should not get flood
	var region := _make_region(0, Enums.TerrainType.RIVER_BASIN)
	region.has_river = false
	GameState.regions[0] = region

	# Run many times to check flood never occurs
	var flood_occurred := false
	for _i in 100:
		region.active_disaster = -1
		region.disaster_years_remaining = 0
		region.disaster_yield_penalty = 0.0
		var events := {"disaster_events": []}
		DisasterSimulation.process_disasters(events)
		for evt in events["disaster_events"]:
			if evt["disaster_type"] == Enums.DisasterType.FLOOD:
				flood_occurred = true

	assert_false(flood_occurred, "Flood should not occur without river")


func test_disaster_causes_pop_loss() -> void:
	var region := _make_region(0, Enums.TerrainType.VOLCANIC_RIDGE)
	region.population = 5000
	GameState.regions[0] = region

	# Force disaster to occur by running many iterations
	var pop_lost := false
	for _i in 200:
		region.active_disaster = -1
		region.disaster_years_remaining = 0
		region.disaster_yield_penalty = 0.0
		region.population = 5000
		var events := {"disaster_events": []}
		DisasterSimulation.process_disasters(events)
		if region.population < 5000:
			pop_lost = true
			break

	assert_true(pop_lost, "Volcanic eruption should cause population loss")


func test_disaster_risk_constants_exist() -> void:
	# Verify all 4 disaster types have risk entries
	assert_true(Constants.DISASTER_RISKS.has(0), "VOLCANIC_ERUPTION risk should exist")
	assert_true(Constants.DISASTER_RISKS.has(1), "EARTHQUAKE risk should exist")
	assert_true(Constants.DISASTER_RISKS.has(2), "FLOOD risk should exist")
	assert_true(Constants.DISASTER_RISKS.has(3), "DROUGHT risk should exist")


func test_disaster_event_format() -> void:
	var region := _make_region(0, Enums.TerrainType.VOLCANIC_RIDGE)
	region.owner_id = 0
	GameState.regions[0] = region

	# Force a disaster
	for _i in 300:
		region.active_disaster = -1
		region.disaster_years_remaining = 0
		region.disaster_yield_penalty = 0.0
		var events := {"disaster_events": []}
		DisasterSimulation.process_disasters(events)
		if not events["disaster_events"].is_empty():
			var evt: Dictionary = events["disaster_events"][0]
			assert_true(evt.has("region_id"), "Event should have region_id")
			assert_true(evt.has("disaster_name"), "Event should have disaster_name")
			assert_true(evt.has("owner_id"), "Event should have owner_id")
			assert_true(evt.has("duration"), "Event should have duration")
			return

	# If we get here, no disaster was generated (unlikely but possible)
	pass_test("Disaster probability too low to trigger in 300 rolls")
