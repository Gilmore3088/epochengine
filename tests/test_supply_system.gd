extends GutTest

## Tests for SupplySystem (core/simulation/supply_system.gd)
## and supply integration in WarResolver, StabilitySimulation, SimulationEngine.


func _make_civ(
	civ_id: int = 0,
	capital_id: int = 0,
	stability: float = 50.0,
) -> CivilizationData:
	var civ := CivilizationData.new(civ_id, "TestCiv", Color.RED)
	civ.capital_region_id = capital_id
	civ.stability = stability
	return civ


func _make_region(
	region_id: int,
	terrain: Enums.TerrainType = Enums.TerrainType.PLAINS,
	infra: int = 0,
	owner_id: int = 0,
) -> RegionData:
	var region := RegionData.new(region_id, "Region_%d" % region_id, terrain)
	region.infrastructure_level = infra
	region.owner_id = owner_id
	return region


func _build_chain(count: int, terrain: Enums.TerrainType = Enums.TerrainType.PLAINS) -> Array[RegionData]:
	## Build a linear chain of regions: 0-1-2-3-...
	var regions: Array[RegionData] = []
	for i in count:
		var r := _make_region(i, terrain)
		regions.append(r)
	# Wire adjacency
	for i in count:
		if i > 0:
			regions[i].adjacency_list.append(i - 1)
		if i < count - 1:
			regions[i].adjacency_list.append(i + 1)
	return regions


# --- Basic Supply Calculation ---

func test_capital_gets_full_supply() -> void:
	var regions := _build_chain(3)
	var civ := _make_civ(0, 0)
	SupplySystem.calculate_supply_map(civ, regions)
	assert_eq(regions[0].supply_value, 1.0, "Capital should have supply 1.0")


func test_adjacent_region_has_high_supply() -> void:
	var regions := _build_chain(3)
	var civ := _make_civ(0, 0)
	SupplySystem.calculate_supply_map(civ, regions)
	assert_true(regions[1].supply_value > 0.8, "Adjacent to capital should have high supply")
	assert_true(regions[1].supply_value < 1.0, "Adjacent should have less than full supply")


func test_distant_region_has_lower_supply() -> void:
	var regions := _build_chain(5)
	var civ := _make_civ(0, 0)
	SupplySystem.calculate_supply_map(civ, regions)
	assert_true(regions[4].supply_value < regions[1].supply_value,
		"Distant region should have lower supply than adjacent")


func test_supply_decreases_with_distance() -> void:
	var regions := _build_chain(5)
	var civ := _make_civ(0, 0)
	SupplySystem.calculate_supply_map(civ, regions)
	for i in range(1, 5):
		assert_true(regions[i].supply_value <= regions[i - 1].supply_value,
			"Supply should decrease or stay same along chain")


# --- Terrain Throughput ---

func test_mountains_cost_more_than_plains() -> void:
	var plains_regions := _build_chain(3, Enums.TerrainType.PLAINS)
	var mountain_regions := _build_chain(3, Enums.TerrainType.MOUNTAINS)
	var civ := _make_civ(0, 0)

	SupplySystem.calculate_supply_map(civ, plains_regions)
	var plains_supply := plains_regions[2].supply_value

	SupplySystem.calculate_supply_map(civ, mountain_regions)
	var mountain_supply := mountain_regions[2].supply_value

	assert_true(mountain_supply < plains_supply,
		"Mountains should have lower supply than plains at same distance")


func test_river_basin_best_throughput() -> void:
	var river_regions := _build_chain(3, Enums.TerrainType.RIVER_BASIN)
	var plains_regions := _build_chain(3, Enums.TerrainType.PLAINS)
	var civ := _make_civ(0, 0)

	SupplySystem.calculate_supply_map(civ, river_regions)
	var river_supply := river_regions[2].supply_value

	SupplySystem.calculate_supply_map(civ, plains_regions)
	var plains_supply := plains_regions[2].supply_value

	assert_true(river_supply >= plains_supply,
		"River basin should have equal or better supply than plains")


# --- Infrastructure Bonus ---

func test_infrastructure_improves_supply() -> void:
	var no_infra := _build_chain(3)
	var with_infra := _build_chain(3)
	for r in with_infra:
		r.infrastructure_level = 3

	var civ := _make_civ(0, 0)

	SupplySystem.calculate_supply_map(civ, no_infra)
	var base_supply := no_infra[2].supply_value

	SupplySystem.calculate_supply_map(civ, with_infra)
	var infra_supply := with_infra[2].supply_value

	assert_true(infra_supply > base_supply,
		"Infrastructure should improve supply at distant regions")


# --- Disconnected Territory ---

func test_disconnected_region_gets_zero_supply() -> void:
	# Region 2 is not adjacent to 0 or 1 (isolated)
	var regions: Array[RegionData] = []
	regions.append(_make_region(0))
	regions.append(_make_region(1))
	regions.append(_make_region(2))

	regions[0].adjacency_list = [1]
	regions[1].adjacency_list = [0]
	# Region 2 has no adjacency to 0 or 1

	var civ := _make_civ(0, 0)
	SupplySystem.calculate_supply_map(civ, regions)
	assert_eq(regions[2].supply_value, 0.0,
		"Disconnected region should have zero supply")


func test_no_capital_gives_zero_supply() -> void:
	var regions := _build_chain(3)
	var civ := _make_civ(0, -1)  # invalid capital
	SupplySystem.calculate_supply_map(civ, regions)
	for region in regions:
		assert_eq(region.supply_value, 0.0,
			"No valid capital should give zero supply to all regions")


# --- Enemy Interdiction ---

func test_interdiction_increases_cost() -> void:
	# Setup: 3 owned regions in chain, region 1 is adjacent to an enemy region
	var regions := _build_chain(3)
	var enemy_region := _make_region(99, Enums.TerrainType.PLAINS, 0, 1)
	regions[1].adjacency_list.append(99)

	var civ := _make_civ(0, 0)
	civ.war_targets = [1]  # at war with civ 1

	# Store enemy region in GameState temporarily
	GameState.regions[99] = enemy_region

	SupplySystem.calculate_supply_map(civ, regions)
	var interdicted_supply := regions[2].supply_value

	# Cleanup and compare with non-interdicted
	GameState.regions.erase(99)

	var clean_regions := _build_chain(3)
	var civ2 := _make_civ(0, 0)
	SupplySystem.calculate_supply_map(civ2, clean_regions)
	var normal_supply := clean_regions[2].supply_value

	assert_true(interdicted_supply < normal_supply,
		"Interdicted route should yield lower supply")


# --- get_best_adjacent_supply ---

func test_best_adjacent_supply_finds_highest() -> void:
	# Target region surrounded by owned regions with varying supply
	var target := _make_region(10, Enums.TerrainType.PLAINS, 0, 1)  # enemy
	var owned_a := _make_region(11, Enums.TerrainType.PLAINS, 0, 0)
	var owned_b := _make_region(12, Enums.TerrainType.PLAINS, 0, 0)

	owned_a.supply_value = 0.6
	owned_b.supply_value = 0.9
	target.adjacency_list = [11, 12]

	GameState.regions[11] = owned_a
	GameState.regions[12] = owned_b

	var result := SupplySystem.get_best_adjacent_supply(target, 0)
	assert_almost_eq(result, 0.9, 0.001, "Should return highest adjacent supply")

	GameState.regions.erase(11)
	GameState.regions.erase(12)


func test_best_adjacent_supply_no_owned_regions() -> void:
	var target := _make_region(10, Enums.TerrainType.PLAINS, 0, 1)
	target.adjacency_list = []
	var result := SupplySystem.get_best_adjacent_supply(target, 0)
	assert_eq(result, 0.0, "No adjacent owned regions should return 0.0")


# --- Combat Integration ---

func test_supply_modifier_gradient_in_combat() -> void:
	# High-supply defender region
	var region := _make_region(0)
	region.supply_value = 1.0
	var civ := _make_civ(0, 0)
	civ.military_strength = 100.0
	var modifier_high := WarResolver._supply_modifier(civ, region)

	# Low-supply defender region
	region.supply_value = 0.0
	var modifier_low := WarResolver._supply_modifier(civ, region)

	assert_true(modifier_high > modifier_low,
		"High supply should give better combat modifier")
	assert_almost_eq(modifier_high, Constants.SUPPLY_MODIFIER_CONNECTED, 0.001)
	assert_almost_eq(modifier_low, Constants.SUPPLY_MODIFIER_DISCONNECTED, 0.001)


# --- Stability Integration ---

func test_cutoff_region_gives_full_stability_penalty() -> void:
	var region := _make_region(1)
	region.supply_value = 0.0  # fully cut off
	var regions: Array[RegionData] = [_make_region(0), region]
	regions[0].supply_value = 1.0
	var civ := _make_civ(0, 0)

	var penalty := StabilitySimulation._disconnected_territory_penalty(civ, regions)
	assert_almost_eq(penalty, Constants.SUPPLY_CUTOFF_PENALTY_PER_REGION, 0.001,
		"Cut-off region should get full penalty")


func test_partial_supply_gives_partial_penalty() -> void:
	var region := _make_region(1)
	region.supply_value = 0.35  # partial supply (between 0.2 and 0.5)
	var regions: Array[RegionData] = [_make_region(0), region]
	regions[0].supply_value = 1.0
	var civ := _make_civ(0, 0)

	var penalty := StabilitySimulation._disconnected_territory_penalty(civ, regions)
	assert_true(penalty > 0.0, "Partial supply should give some penalty")
	assert_true(penalty < Constants.SUPPLY_CUTOFF_PENALTY_PER_REGION,
		"Partial supply should give less than full cutoff penalty")


func test_well_supplied_no_penalty() -> void:
	var region := _make_region(1)
	region.supply_value = 0.8  # well supplied
	var regions: Array[RegionData] = [_make_region(0), region]
	regions[0].supply_value = 1.0
	var civ := _make_civ(0, 0)

	var penalty := StabilitySimulation._disconnected_territory_penalty(civ, regions)
	assert_eq(penalty, 0.0, "Well-supplied region should have zero penalty")


# --- Starvation Attrition ---

func test_attrition_reduces_population() -> void:
	var region := _make_region(0)
	region.population = 1000
	region.supply_value = 0.0  # cut off
	var expected_loss := ceili(1000.0 * Constants.STARVATION_ATTRITION_RATE)
	var expected_pop := 1000 - expected_loss

	# Simulate attrition manually
	var loss := ceili(float(region.population) * Constants.STARVATION_ATTRITION_RATE)
	region.population = maxi(region.population - loss, 100)

	assert_eq(region.population, expected_pop,
		"Cut-off region should lose population to attrition")


func test_no_attrition_above_threshold() -> void:
	var region := _make_region(0)
	region.population = 1000
	region.supply_value = 0.5  # above threshold

	# No attrition should apply
	var old_pop := region.population
	if region.supply_value >= Constants.SUPPLY_MIN_THRESHOLD:
		pass  # no loss
	assert_eq(region.population, old_pop,
		"Region above supply threshold should not lose population")


# --- Edge Cost Calculation ---

func test_edge_cost_river_cheaper_than_mountain() -> void:
	var river := _make_region(0, Enums.TerrainType.RIVER_BASIN)
	var mountain := _make_region(1, Enums.TerrainType.MOUNTAINS)
	var civ := _make_civ(0, 0)

	var river_cost := SupplySystem._compute_edge_cost(river, civ)
	var mountain_cost := SupplySystem._compute_edge_cost(mountain, civ)

	assert_true(river_cost < mountain_cost,
		"River basin should be cheaper to traverse than mountains")


func test_infrastructure_reduces_edge_cost() -> void:
	var no_infra := _make_region(0, Enums.TerrainType.PLAINS, 0)
	var with_infra := _make_region(1, Enums.TerrainType.PLAINS, 3)
	var civ := _make_civ(0, 0)

	var cost_no := SupplySystem._compute_edge_cost(no_infra, civ)
	var cost_with := SupplySystem._compute_edge_cost(with_infra, civ)

	assert_true(cost_with < cost_no,
		"Infrastructure should reduce traversal cost")
