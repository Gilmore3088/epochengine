class_name Constants
extends RefCounted

## All simulation constants for Epoch Engine.
## Values sourced from docs/systems/simulation_math.md

# --- Population Growth ---
const BASE_GROWTH_RATE_MIN := 0.01
const BASE_GROWTH_RATE_MAX := 0.03
const FOOD_MODIFIER_MIN := 0.5
const FOOD_MODIFIER_MAX := 1.5
const STABILITY_MODIFIER_MIN := 0.7
const STABILITY_MODIFIER_MAX := 1.2
const RANDOM_VARIANCE_MIN := 0.98
const RANDOM_VARIANCE_MAX := 1.02

# --- Stability ---
const STABILITY_MIN := 0.0
const STABILITY_MAX := 100.0
const STABILITY_START := 50.0
const WAR_EXHAUSTION_BASE := 1.5  # base exhaustion per war per year
const WAR_EXHAUSTION_ESCALATION := 0.5  # additional exhaustion per year of war duration
const WAR_EXHAUSTION_MAX_PER_FRONT := 8.0  # cap per front
const WAR_FATIGUE_PEACE_RECOVERY := 0.6  # fraction of duration reset on peace (partial memory)
const RESOURCE_SHORTAGE_PENALTY_MIN := 1.0
const RESOURCE_SHORTAGE_PENALTY_MAX := 8.0
const RANDOM_POLITICAL_SHIFT_MIN := -2.0
const RANDOM_POLITICAL_SHIFT_MAX := 2.0
const COLLAPSE_STABILITY_THRESHOLD := 5.0
const COLLAPSE_CONSECUTIVE_YEARS := 10
const STABILITY_MEAN_REVERSION_RATE := 0.10  # pull 10% toward equilibrium per year
const STABILITY_EQUILIBRIUM := 50.0  # target for mean-reversion

# --- War / Combat ---
const TERRAIN_MODIFIER_MIN := 0.7
const TERRAIN_MODIFIER_MAX := 1.3
const SUPPLY_MODIFIER_CONNECTED := 1.0
const SUPPLY_MODIFIER_DISCONNECTED := 0.5
const DOCTRINE_MODIFIER_MIN := 0.8
const DOCTRINE_MODIFIER_MAX := 1.2
const BATTLE_VARIANCE_MIN := 0.85
const BATTLE_VARIANCE_MAX := 1.15
const WAR_STABILITY_LOSS_MIN := 5
const WAR_STABILITY_LOSS_MAX := 15
const WAR_DECLARATION_STABILITY_THRESHOLD := 45.0
const WAR_PARITY_THRESHOLD := 0.3  # strength ratio within 30% = parity, lowers war chance
const WAR_BASE_CHANCE := 0.04  # base probability per eligible neighbor per year
const WAR_IMBALANCE_MULTIPLIER := 2.0  # how much strength advantage increases war chance
const WAR_PARITY_DAMPENER := 0.2  # multiplier when in parity (makes war unlikely)
const PEACE_COOLDOWN_YEARS := 15  # years before can redeclare war on same civ
const ALLIANCE_BASE_CHANCE := 0.06  # base probability of seeking alliance per neighbor per year
const ALLIANCE_STABILITY_THRESHOLD := 50.0  # min stability to seek alliance
const ALLIANCE_SHARED_ENEMY_BONUS := 0.15  # extra chance if both at war with same civ

# --- Heroes ---
const HERO_LIFESPAN_MIN := 40
const HERO_LIFESPAN_MAX := 80
const HERO_SPAWN_BASE_CHANCE := 0.08
const HERO_SPAWN_STABILITY_THRESHOLD := 60.0
const HERO_MAX_PER_CIV := 3
const HERO_GENERAL_MILITARY_BONUS := 0.10
const HERO_REFORMER_STABILITY_BONUS := 5.0
const HERO_VISIONARY_PRODUCTION_BONUS := 0.10

# --- Golden Age ---
const GOLDEN_AGE_STABILITY_THRESHOLD := 80.0
const GOLDEN_AGE_DURATION_YEARS := 20
const GOLDEN_AGE_FOOD_BONUS := 0.50
const GOLDEN_AGE_PRODUCTION_BONUS := 0.50
const GOLDEN_AGE_STABILITY_FLOOR := 10.0
const GOLDEN_AGE_END_STABILITY := 60.0
const GOLDEN_AGE_COOLDOWN_YEARS := 30

# --- AI Behavior ---
const AI_EXPANSION_STABILITY_THRESHOLD := 40.0
const AI_SURVIVAL_STABILITY_THRESHOLD := 30.0
const AI_CAUTIOUS_STABILITY_THRESHOLD := 50.0

# --- Tech Emergence Hidden Metrics ---
const TECH_METRIC_MIN := 0.0
const TECH_METRIC_MAX := 100.0

# --- Terrain Defense Modifiers ---
const DEFENSE_RIVER_BASIN := 0.8
const DEFENSE_PLAINS := 0.7
const DEFENSE_MOUNTAINS := 1.4
const DEFENSE_DESERT := 1.0
const DEFENSE_JUNGLE := 1.1
const DEFENSE_COASTLINE := 0.8
const DEFENSE_TUNDRA := 1.0
const DEFENSE_STEPPE := 0.8
const DEFENSE_VOLCANIC_RIDGE := 1.1

# --- Terrain Base Yields [food, production] ---
const YIELD_RIVER_BASIN := Vector2i(5, 3)
const YIELD_PLAINS := Vector2i(3, 3)
const YIELD_MOUNTAINS := Vector2i(1, 1)
const YIELD_DESERT := Vector2i(1, 1)
const YIELD_JUNGLE := Vector2i(3, 1)
const YIELD_COASTLINE := Vector2i(3, 4)
const YIELD_TUNDRA := Vector2i(1, 1)
const YIELD_STEPPE := Vector2i(2, 2)
const YIELD_VOLCANIC_RIDGE := Vector2i(2, 5)

# --- Performance ---
const FAST_FORWARD_5X := 5
const FAST_FORWARD_10X := 10

# --- Economy ---
const FOOD_PER_POP_DIVISOR := 2000  # 1 food consumed per 2000 population
const MILITARY_UPKEEP_DIVISOR := 25.0  # military_strength / 25 = production upkeep
const MILITARY_REINFORCE_RATE := 0.1  # fraction of surplus production -> military
const MILITARY_REINFORCE_MAX := 20.0  # max military gain per year from production
const SHORTAGE_THRESHOLD := -50  # stockpile below this = critical shortage
const INFRASTRUCTURE_MAX_LEVEL := 5
const INFRASTRUCTURE_UPGRADE_COST := 15  # base cost * (level+1)
const INFRASTRUCTURE_AUTO_INVEST_THRESHOLD := 40  # min surplus before AI upgrades

# --- Admin Capacity & Overextension ---
const ADMIN_CAPACITY_BASE := 5  # base regions a civ can manage
const ADMIN_INFRA_BONUS_PER_LEVEL := 0.2  # each infra level across all regions adds capacity
const ADMIN_STABILITY_DIVISOR := 20.0  # stability / this = bonus admin capacity
const ADMIN_OVEREXTENSION_DIVISOR := 10.0  # penalty = excess^2 / this
const DISCONNECTED_TERRITORY_PENALTY := 3.0  # stability drain per disconnected region

# --- Compact State Bonus ---
const COMPACT_STATE_THRESHOLD := 5  # region count at or below = compact
const COMPACT_STABILITY_FLOOR := 5.0  # minimum stability bonus for compact civs
const COMPACT_WAR_EXHAUSTION_REDUCTION := 0.25  # 25% less war exhaustion
const COMPACT_DEFENSE_BONUS := 0.25  # 25% extra defense for compact civs

# --- Expansion / Snowball Control ---
const EXPANSION_BASE_PRODUCTION_COST := 15  # base production to settle a region
const EXPANSION_COST_ESCALATION := 5  # additional cost per region above threshold
const EXPANSION_SETTLER_POP := 300  # population moved to new region
const EXPANSION_FRICTION_DIVISOR := 10.0  # factor = 1 / (1 + region_count / this)

# --- Infrastructure Effects ---
const INFRA_STABILITY_FLOOR_PER_LEVEL := 2.0  # avg_infra * this = stability floor
const INFRA_MILITARY_REINFORCE_BONUS := 0.05  # 5% faster military reinforce per avg level

# --- Epoch / Era ---
const ERA_TECH_THRESHOLDS := [0, 3, 6, 9]  # tech count boundaries per era
const ERA_TIER_CAPS := [2, 3, 4, 5]  # max practical dev tier per era

# --- Governance Tiers ---
const GOVERNANCE_DEMOTION_HYSTERESIS_YEARS := 5

# --- Development Tier System ---
const DEV_DEMOTION_HYSTERESIS_YEARS := 3
const DEV_CONQUEST_TIER_DROP := 1  # tiers lost when region is conquered

# Tier gate: [min_infra, min_pop_density, min_stability, min_governance, min_era]
const DEV_TIER_GATES := [
	[0, 0.0, 0.0, 0, 0],       # Tier 0: Wild (always valid)
	[0, 0.10, 25.0, 0, 0],     # Tier 1: Rural Settlement (infra 0 OK per WP4.1)
	[2, 0.25, 30.0, 1, 0],     # Tier 2: Structured Agriculture
	[3, 0.45, 40.0, 2, 1],     # Tier 3: Urbanized (needs Classical era)
	[4, 0.65, 45.0, 3, 2],     # Tier 4: Industrialized (needs Industrial era)
	[5, 0.80, 50.0, 4, 3],     # Tier 5: Advanced (needs Future era)
]

# Tier economy multiplier (sub-linear, applied to base food/prod yields)
const DEV_TIER_ECONOMY_MULT := [1.0, 1.15, 1.30, 1.45, 1.55, 1.60]

# Tier defense bonus (additive to terrain defense_modifier)
const DEV_TIER_DEFENSE_BONUS := [0.0, 0.0, 0.05, 0.10, 0.15, 0.20]

# Tier admin capacity contribution per region
const DEV_TIER_ADMIN_BONUS := [0, 0, 1, 2, 3, 4]

# Terrain population capacity (absolute max pop before density = 1.0)
# Scaled by size_factor.
const TERRAIN_POP_CAPACITY := {
	0: 12000,  # RIVER_BASIN
	1: 10000,  # PLAINS
	2: 4000,   # MOUNTAINS
	3: 3000,   # DESERT
	4: 6000,   # JUNGLE
	5: 9000,   # COASTLINE
	6: 2500,   # TUNDRA
	7: 5000,   # STEPPE
	8: 4500,   # VOLCANIC_RIDGE
}

# --- Resource Pyramid System ---

# Era required to unlock each resource type (ResourceType enum -> Epoch enum)
const RESOURCE_ERA_UNLOCK := {
	0: 1,  # METALS -> CLASSICAL
	1: 1,  # COMMERCE -> CLASSICAL
	2: 1,  # LUXURY_GOODS -> CLASSICAL
	3: 2,  # FUELS -> INDUSTRIAL
	4: 2,  # MANUFACTURED -> INDUSTRIAL
	5: 2,  # RARE_MATERIALS -> INDUSTRIAL
	6: 3,  # DATA -> FUTURE
	7: 3,  # STRATEGIC -> FUTURE
	8: 3,  # ADV_ENERGY -> FUTURE
}

# Resource names for display
const RESOURCE_NAMES := {
	0: "Metals",
	1: "Commerce",
	2: "Luxury Goods",
	3: "Fuels",
	4: "Manufactured Goods",
	5: "Rare Materials",
	6: "Data",
	7: "Strategic Materials",
	8: "Advanced Energy",
}

# Terrain yields per resource type: {terrain_int: {resource_int: base_yield}}
# Only non-zero entries included for performance
const RESOURCE_TERRAIN_YIELDS := {
	0: {1: 2, 4: 1, 6: 1, 8: 1},           # RIVER_BASIN: commerce 2, manufactured 1, data 1, adv_energy 1
	1: {4: 1, 6: 1},                          # PLAINS: manufactured 1, data 1
	2: {0: 3, 5: 2, 7: 2},                    # MOUNTAINS: metals 3, rare_materials 2, strategic 2
	3: {2: 1, 3: 2, 7: 1, 8: 3},              # DESERT: luxury 1, fuels 2, strategic 1, adv_energy 3
	4: {2: 3},                                 # JUNGLE: luxury 3
	5: {1: 3, 2: 1, 4: 2, 6: 1, 8: 2},        # COASTLINE: commerce 3, luxury 1, manufactured 2, data 1, adv_energy 2
	6: {3: 1},                                 # TUNDRA: fuels 1
	7: {0: 1, 3: 1},                           # STEPPE: metals 1, fuels 1
	8: {0: 2, 3: 3, 5: 2, 7: 2},               # VOLCANIC_RIDGE: metals 2, fuels 3, rare_materials 2, strategic 2
}

# Maintenance requirements: {resource_int: [required_resource_ints]}
# Resources at the bottom of the pyramid have empty requirements
const RESOURCE_MAINTENANCE := {
	0: [],          # METALS: no inputs
	1: [],          # COMMERCE: no inputs
	2: [1],         # LUXURY_GOODS: requires COMMERCE
	3: [],          # FUELS: no inputs (deposit-based)
	4: [0, 3],      # MANUFACTURED: requires METALS + FUELS
	5: [],          # RARE_MATERIALS: no inputs (deposit-based)
	6: [1, 4],      # DATA: requires COMMERCE + MANUFACTURED
	7: [5, 4],      # STRATEGIC: requires RARE_MATERIALS + MANUFACTURED
	8: [3, 6],      # ADV_ENERGY: requires FUELS + DATA
}

const RESOURCE_MAINTENANCE_AMOUNT := 1  # consumed per input per turn
const RESOURCE_MISSING_EFFICIENCY_PENALTY := 0.25  # per missing input
const RESOURCE_MISSING_STABILITY_PENALTY := 5.0  # per missing input per year
const RESOURCE_MAX_EFFICIENCY_LOSS := 0.50  # cap on efficiency reduction

# Complexity tax
const COMPLEXITY_TAX_THRESHOLD := 3  # no penalty at 3 or fewer resource types
const COMPLEXITY_TAX_PER_TYPE := 0.5  # stability drain per extra type per year
const COMPLEXITY_TAX_GOVERNANCE_REDUCTION := 0.1  # reduced per governance tier above TRIBAL

# Deposit quantities by terrain: {terrain_int: {resource_int: [min, max]}}
const DEPOSIT_QUANTITIES := {
	2: {3: [200, 600], 5: [500, 1500]},      # MOUNTAINS: fuels, rare_materials
	3: {3: [600, 1500]},                       # DESERT: fuels
	6: {3: [300, 800]},                        # TUNDRA: fuels
	8: {3: [800, 2000], 5: [400, 1200]},       # VOLCANIC_RIDGE: fuels, rare_materials
}

# Base extraction rate per turn (scaled by dev tier)
const DEPOSIT_BASE_EXTRACTION := 5
const DEPOSIT_DEV_TIER_EXTRACTION_BONUS := 0.2  # +20% per dev tier

# Development tier resource gates: resources required for promotion
# [tier_0_reqs, tier_1_reqs, ..., tier_5_reqs]
# Each entry is an array of resource type ints (empty = no resource gate)
const DEV_TIER_RESOURCE_GATES := [
	[],     # Tier 0: Wild - no requirements
	[],     # Tier 1: Rural Settlement - no requirements
	[],     # Tier 2: Structured Agriculture - no requirements
	[0],    # Tier 3: Urbanized - requires METALS
	[4],    # Tier 4: Industrialized - requires MANUFACTURED
	[6],    # Tier 5: Advanced - requires DATA
]

# Infrastructure bonus to resource yields (per 2 infra levels)
const RESOURCE_INFRA_BONUS_PER_2_LEVELS := 1

# --- Supply & Logistics ---
const SUPPLY_DECAY_PER_HOP := 0.08  # supply drops 8% per cost unit from capital
const SUPPLY_MIN_THRESHOLD := 0.2  # below this = effectively cut off
const SUPPLY_INFRASTRUCTURE_BONUS_PER_LEVEL := 0.10  # 10% cost reduction per infra level
const SUPPLY_INTERDICTION_PENALTY := 0.3  # added to edge cost when adjacent to enemy at war
const STARVATION_ATTRITION_RATE := 0.05  # 5% pop loss per year for cut-off regions
const SUPPLY_LOW_PENALTY_PER_REGION := 2.0  # stability penalty per poorly supplied region (0.2-0.5 supply)
const SUPPLY_CUTOFF_PENALTY_PER_REGION := 4.0  # stability penalty per cut-off region (< 0.2 supply)

# Terrain throughput for supply routes (higher = easier to supply through)
# Edge cost = 1.0 / throughput, so lower throughput = more expensive
const TERRAIN_SUPPLY_THROUGHPUT := {
	0: 1.00,  # RIVER_BASIN: best supply (river trade)
	1: 0.80,  # PLAINS: flat, easy
	2: 0.30,  # MOUNTAINS: difficult terrain
	3: 0.35,  # DESERT: harsh
	4: 0.40,  # JUNGLE: dense vegetation
	5: 0.70,  # COASTLINE: coastal trade routes
	6: 0.30,  # TUNDRA: harsh cold
	7: 0.70,  # STEPPE: open grassland
	8: 0.25,  # VOLCANIC_RIDGE: very difficult
}

# --- Terrain Texture Paths ---
# Resource paths to 512x512 seamless PNG tiles per terrain type.
# Empty string = use procedural decorations as fallback.
const TERRAIN_TEXTURE_PATHS := {
	0: "",  # RIVER_BASIN -> terrain_river_basin.png
	1: "",  # PLAINS -> terrain_temperate_plains.png
	2: "",  # MOUNTAINS -> terrain_mountain.png
	3: "",  # DESERT -> terrain_desert.png
	4: "",  # JUNGLE -> terrain_jungle.png
	5: "",  # COASTLINE -> terrain_coastal.png
	6: "",  # TUNDRA -> terrain_tundra.png (not yet assigned)
	7: "",  # STEPPE -> terrain_steppe.png
	8: "",  # VOLCANIC_RIDGE -> terrain_volcanic.png
}

# --- Terrain Texture Tiling ---
const TERRAIN_TILE_SCALE := 300.0  # default world units per texture tile
const UV_ROTATIONS := [0.0, PI * 0.5, PI, PI * 1.5]  # 90-degree increments

# Per-terrain tile scale override (world units per tile). 0.0 = use TERRAIN_TILE_SCALE default.
# Designers: increase for zoomed-out (less detail), decrease for zoomed-in (more detail).
const TERRAIN_TILE_SCALE_OVERRIDE := {
	0: 0.0,  # RIVER_BASIN
	1: 0.0,  # PLAINS
	2: 0.0,  # MOUNTAINS
	3: 0.0,  # DESERT
	4: 0.0,  # JUNGLE
	5: 0.0,  # COASTLINE
	6: 0.0,  # TUNDRA
	7: 0.0,  # STEPPE
	8: 0.0,  # VOLCANIC_RIDGE
}

# --- Political Tint Overlay ---
const TINT_ALPHA_POLITICAL := 0.35  # owned regions in political mode
const TINT_ALPHA_NEUTRAL := 0.20  # unowned regions in political mode
const TINT_ALPHA_HEATMAP := 0.70  # supply, resources, alliances overlays

# Per-terrain tint strength override. 0.0 = use TINT_ALPHA_POLITICAL default.
# Designers: useful when a terrain texture clashes with civ colors at default alpha.
const TERRAIN_TINT_ALPHA_OVERRIDE := {
	0: 0.0,  # RIVER_BASIN
	1: 0.0,  # PLAINS
	2: 0.0,  # MOUNTAINS
	3: 0.0,  # DESERT
	4: 0.0,  # JUNGLE
	5: 0.0,  # COASTLINE
	6: 0.0,  # TUNDRA
	7: 0.0,  # STEPPE
	8: 0.0,  # VOLCANIC_RIDGE
}

# --- Per-Region Variation ---
const VARIATION_BRIGHTNESS_RANGE := 0.03  # +/- 3% brightness per region
