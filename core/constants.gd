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
const WAR_EXHAUSTION_BASE := 1.0  # base exhaustion per war per year
const WAR_EXHAUSTION_ESCALATION := 0.3  # additional exhaustion per year of war duration
const WAR_EXHAUSTION_MAX_PER_FRONT := 8.0  # cap per front
const WAR_FATIGUE_PEACE_RECOVERY := 0.6  # fraction of duration reset on peace (partial memory)
const RESOURCE_SHORTAGE_PENALTY_MIN := 1.0
const RESOURCE_SHORTAGE_PENALTY_MAX := 8.0
const RANDOM_POLITICAL_SHIFT_MIN := -2.0
const RANDOM_POLITICAL_SHIFT_MAX := 2.0
const COLLAPSE_STABILITY_THRESHOLD := 5.0
const COLLAPSE_CONSECUTIVE_YEARS := 15
const STABILITY_MEAN_REVERSION_RATE := 0.15  # pull 15% toward equilibrium per year
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
const WAR_STABILITY_LOSS_MIN := 3
const WAR_STABILITY_LOSS_MAX := 10
const WAR_DECLARATION_STABILITY_THRESHOLD := 55.0
const WAR_PARITY_THRESHOLD := 0.3  # strength ratio within 30% = parity, lowers war chance
const WAR_BASE_CHANCE := 0.015  # base probability per eligible neighbor per year
const WAR_IMBALANCE_MULTIPLIER := 1.2  # how much strength advantage increases war chance
const WAR_PARITY_DAMPENER := 0.15  # multiplier when in parity (makes war unlikely)
const PEACE_COOLDOWN_YEARS := 10  # years before can redeclare war on same civ
const ALLIANCE_BASE_CHANCE := 0.06  # base probability of seeking alliance per neighbor per year
const ALLIANCE_STABILITY_THRESHOLD := 50.0  # min stability to seek alliance
const ALLIANCE_SHARED_ENEMY_BONUS := 0.15  # extra chance if both at war with same civ

# --- Non-Aggression Pacts ---
const NAP_DURATION := 15
const NAP_BREAK_STABILITY_PENALTY := 8.0
const NAP_BASE_CHANCE := 0.04

# --- Trade Agreements ---
const TRADE_FOOD_BONUS_PERCENT := 0.05
const TRADE_PRODUCTION_BONUS_PERCENT := 0.05
const TRADE_STABILITY_THRESHOLD := 45.0
const TRADE_BASE_CHANCE := 0.06

# --- Tribute ---
const TRIBUTE_STRENGTH_RATIO := 1.5
const TRIBUTE_PRODUCTION_AMOUNT := 10
const TRIBUTE_REFUSAL_WAR_CHANCE := 0.35
const TRIBUTE_COOLDOWN_YEARS := 8
const TRIBUTE_BASE_CHANCE := 0.03

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
const AI_EXPANSION_STABILITY_THRESHOLD := 45.0
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
const MILITARY_REINFORCE_RATE := 0.12  # fraction of surplus production -> military
const MILITARY_REINFORCE_MAX := 20.0  # max military gain per year from production
const SHORTAGE_THRESHOLD := -50  # stockpile below this = critical shortage
const INFRASTRUCTURE_MAX_LEVEL := 5
const INFRASTRUCTURE_UPGRADE_COST := 10  # base cost * (level+1)
const INFRASTRUCTURE_AUTO_INVEST_THRESHOLD := 40  # min surplus before AI upgrades

# Infrastructure tier names (display only — level int stays in data model)
const INFRASTRUCTURE_NAMES := {
	0: "Trails",
	1: "Paths",
	2: "Roads",
	3: "Railways",
	4: "Highways",
	5: "Maglev Network",
}

# Tech required to upgrade TO this level (empty string = no requirement)
const INFRASTRUCTURE_TECH_GATES := {
	0: "",
	1: "",
	2: "Bronze Working",
	3: "Steam Power",
	4: "Electricity",
	5: "Fusion Research",
}

# --- Admin Capacity & Overextension ---
const ADMIN_CAPACITY_BASE := 5  # base regions a civ can manage
const ADMIN_INFRA_BONUS_PER_LEVEL := 0.2  # each infra level across all regions adds capacity
const ADMIN_STABILITY_DIVISOR := 20.0  # stability / this = bonus admin capacity
const ADMIN_OVEREXTENSION_DIVISOR := 8.0  # penalty = excess^2 / this
const DISCONNECTED_TERRITORY_PENALTY := 3.0  # stability drain per disconnected region

# --- Compact State Bonus ---
const COMPACT_STATE_THRESHOLD := 8  # region count at or below = compact
const COMPACT_STABILITY_FLOOR := 15.0  # minimum stability floor for compact civs
const COMPACT_WAR_EXHAUSTION_REDUCTION := 0.40  # 40% less war exhaustion
const COMPACT_DEFENSE_BONUS := 0.40  # 40% extra defense for compact civs

# --- Expansion / Snowball Control ---
const EXPANSION_BASE_PRODUCTION_COST := 20  # base production to settle a region
const EXPANSION_COST_ESCALATION := 8  # additional cost per region above threshold
const EXPANSION_SETTLER_POP := 300  # population moved to new region
const EXPANSION_FRICTION_DIVISOR := 6.0  # factor = 1 / (1 + region_count / this)

# --- Infrastructure Effects ---
const INFRA_STABILITY_FLOOR_PER_LEVEL := 2.0  # avg_infra * this = stability floor
const INFRA_MILITARY_REINFORCE_BONUS := 0.05  # 5% faster military reinforce per avg level

# --- Epoch / Era ---
const ERA_TECH_THRESHOLDS := [0, 3, 6, 9]  # tech count boundaries per era
const ERA_TIER_CAPS := [2, 3, 4, 5]  # max practical dev tier per era
const ERA_NAMES := {0: "Prehistoric", 1: "Classical", 2: "Industrial", 3: "Future"}

# --- Geographic Features ---
const RIVER_FOOD_BONUS := 1
const RIVER_TRADE_BONUS := 1
const RIVER_DEFENSE_PENALTY := -0.05
const RIVER_SUPPLY_THROUGHPUT_BONUS := 0.15
const LAKE_FOOD_BONUS := 1
const LAKE_DEFENSE_BONUS := 0.05
const ELEVATION_BY_TERRAIN := {
	# RIVER_BASIN=0, PLAINS=1, MOUNTAINS=2, DESERT=3, JUNGLE=4,
	# COASTLINE=5, TUNDRA=6, STEPPE=7, VOLCANIC_RIDGE=8
	0: 0, 1: 0, 2: 3, 3: 1, 4: 1, 5: 0, 6: 2, 7: 1, 8: 3,
}

# --- Natural Disasters ---
const DISASTER_RISKS := {
	# DisasterType: {terrains: [TerrainType ints], annual_pct, pop_loss, infra_dmg, yield_penalty, duration}
	0: {"terrains": [8], "annual_pct": 0.03, "pop_loss": 0.10, "infra_dmg": 1, "yield_penalty": 0.30, "duration": 3},  # VOLCANIC_ERUPTION
	1: {"terrains": [2, 8], "annual_pct": 0.02, "pop_loss": 0.05, "infra_dmg": 1, "yield_penalty": 0.15, "duration": 2},  # EARTHQUAKE
	2: {"terrains": [0], "annual_pct": 0.04, "pop_loss": 0.03, "infra_dmg": 0, "yield_penalty": 0.10, "duration": 1},  # FLOOD (river_basin with river)
	3: {"terrains": [1, 3, 7], "annual_pct": 0.03, "pop_loss": 0.02, "infra_dmg": 0, "yield_penalty": 0.25, "duration": 3},  # DROUGHT
}

# --- Governors / Political Geography ---
const CAPITAL_STABILITY_BONUS := 5.0
const CAPITAL_PRODUCTION_BONUS := 0.15
const CAPITAL_DEFENSE_BONUS := 0.10
const LOBBY_ANNUAL_CHANCE := 0.15
const LOBBY_IGNORE_STABILITY_PENALTY := 2.0
const LOBBY_FULFILL_STABILITY_BONUS := 3.0
const INFLUENCE_WEIGHT_POP := 0.40
const INFLUENCE_WEIGHT_DEV := 0.30
const INFLUENCE_WEIGHT_INFRA := 0.20
const INFLUENCE_WEIGHT_CAPITAL := 0.10

# --- Future Era ---
const TERRAFORM_COST := 100
const TERRAFORM_DURATION := 10
const SPACE_PROGRAM_KNOWLEDGE_REQ := 85.0
const SPACE_PROGRAM_PROD_COST := 200
const RECLAMATION_COST := 80
const RECLAMATION_DURATION := 5
const RECLAMATION_SIZE_BONUS := 0.30
const RECLAMATION_MAX_BONUS := 0.60
const TERRAFORM_TARGETS := {
	3: [1, 0],  # Desert -> Plains or River Basin
	6: [1, 7],  # Tundra -> Plains or Steppe
	7: [1, 0],  # Steppe -> Plains or River Basin
	2: [8],     # Mountains -> Volcanic Ridge
}

# --- Cartography ---
const CARTOGRAPHY_REVEAL_THRESHOLDS := [0.0, 0.5, 0.8]  # skill levels for 1/2/3 hop reveal
const CARTOGRAPHY_GROWTH_EXPLORER := 0.01
const CARTOGRAPHY_GROWTH_TRADE := 0.005
const CARTOGRAPHY_GROWTH_KNOWLEDGE := 0.002
const CARTOGRAPHY_LIVE_DATA_THRESHOLD := 0.6

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
const TINT_ALPHA_POLITICAL := 0.18  # owned regions in political mode
const TINT_ALPHA_NEUTRAL := 0.08  # unowned regions in political mode
const TINT_ALPHA_BORDER := 0.22  # border regions (adjacent to different civ)
const TINT_ALPHA_HEATMAP := 0.70  # supply, resources, alliances overlays

# --- Empire Border Styling ---
const EMPIRE_BORDER_INNER_GLOW_ALPHA := 0.18
const EMPIRE_BORDER_OUTER_GLOW_ALPHA := 0.12
const EMPIRE_BORDER_MAIN_ALPHA := 0.75
const EMPIRE_BORDER_INNER_GLOW_EXTRA_WIDTH := 8.0
const EMPIRE_BORDER_OUTER_GLOW_EXTRA_WIDTH := 14.0
const SAME_EMPIRE_PROVINCE_BORDER_ALPHA := 0.15
const SAME_EMPIRE_PROVINCE_BORDER_WIDTH_MULT := 0.5

# --- Edge Blending ---
const EDGE_BLEND_LAYERS := 3
const EDGE_BLEND_BASE_WIDTH := 6.0
const EDGE_BLEND_WIDTH_STEP := 5.0
const EDGE_BLEND_BASE_ALPHA := 0.12
const EDGE_BLEND_ALPHA_DECAY := 0.04

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

# --- Political System ---
const LEGITIMACY_START := 60.0
const LEGITIMACY_LERP := 0.25
const LEGITIMACY_GOV_TIER_BONUS := 2.5
const LEGITIMACY_FOOD_FACTOR_SCALE := 2.0
const LEGITIMACY_WAR_EXHAUST_SCALE := 1.5
const LEGITIMACY_DISASTER_PENALTY := 2.0
const LEGITIMACY_SHORTAGE_PENALTY_SCALE := 1.0
const LEGITIMACY_COUP_THRESHOLD := 30.0
const COUP_MILITARY_BLOC_THRESHOLD := 0.35
const COUP_BASE_CHANCE := 0.25
const DEFAULT_ELECTION_INTERVAL := 5

const POWER_BLOC_DEFAULTS := {
	"nobles": 0.22,
	"merchants": 0.18,
	"military": 0.20,
	"clergy": 0.16,
	"commoners": 0.24,
}

const RULER_FIRST_NAME_POOL := [
	"Alden", "Bran", "Corin", "Darian", "Edric", "Fen", "Galen", "Hadrian",
	"Ilan", "Jorin", "Kael", "Lucan", "Marek", "Nolan", "Oren", "Perrin",
	"Quin", "Ronan", "Soren", "Tavin", "Ulric", "Varr", "Wren", "Xander",
	"Yorin", "Zarek",
]

const DYNASTY_NAME_POOL := [
	"Ashcroft", "Blackstone", "Crownhall", "Duskfall", "Emberlyn", "Frostmere",
	"Goldmere", "Highwatch", "Ironmark", "Kingswell", "Lionsgate", "Mooncrest",
	"Nightfall", "Oakshield", "Ravenholt", "Stormvale", "Thornwall", "Valeward",
	"Whitehelm", "Wyrmspire",
]

# --- Renewable Resource Degradation ---
const RENEWABLE_DEGRADATION_RATE := 0.02   # +2% degradation per year under extraction
const RENEWABLE_RECOVERY_RATE := 0.01      # -1% recovery per year when unowned/light extraction
const RENEWABLE_MAX_DEGRADATION := 0.40    # cap at 40% yield reduction
const RENEWABLE_RECOVERY_THRESHOLD := 2    # infra level at or below triggers recovery

# --- Town System ---
const TOWN_BASE_COST := 20                 # base production to found a town
const TOWN_COST_EXPONENT := 1.5            # cost = base * (1 + existing)^exponent / size_factor
const TOWN_MIN_POP_TO_FOUND := 500         # region needs this much pop to found a town
const TOWN_STARTING_POP := 200             # population moved to new town from region
const TOWN_AUTO_SPAWN_POP := 300           # min region pop to auto-spawn first town
const TOWN_AI_INVEST_THRESHOLD := 30       # min production surplus before AI founds towns

# Town names pool
const TOWN_NAME_POOL := [
	"Ashford", "Millbrook", "Ironhold", "Riverside", "Cliffside",
	"Thornwick", "Goldvale", "Havenport", "Oakmere", "Stonewall",
	"Brightwater", "Duskfield", "Frostpeak", "Greenhollow", "Shadowfen",
	"Sunridge", "Windmere", "Copperhill", "Silverlake", "Mudshore",
	"Ambervale", "Pinecrest", "Redmarsh", "Whitecross", "Blackthorn",
]

# --- Building System ---
const BUILDING_BASE_COST := 6              # base production to construct a building
const BUILDING_COST_ESCALATION := 1.3      # cost = base * escalation^count_of_same_type
const BUILDING_MAINTENANCE_PER := 1        # production/yr maintenance per building


# Structured building metadata table (keyed by BuildingType int)
const BUILDING_RULES := {
	0: {"category": "food", "build_cost": 5, "upkeep_cost": 0, "outputs": {"food": 3, "production": 0, "military": 0.0, "stability": 0.0, "defense": 0.0, "tech": 0.0, "trade": 0}, "description": "Stores grain, boosting food output."},
	1: {"category": "military", "build_cost": 8, "upkeep_cost": 1, "outputs": {"food": 0, "production": 0, "military": 3.0, "stability": 0.0, "defense": 0.05, "tech": 0.0, "trade": 0}, "description": "Trains soldiers and fortifies garrison."},
	2: {"category": "trade", "build_cost": 6, "upkeep_cost": 0, "outputs": {"food": 0, "production": 3, "military": 0.0, "stability": 1.0, "defense": 0.0, "tech": 0.0, "trade": 1}, "description": "Commerce hub boosting production and stability."},
	3: {"category": "military", "build_cost": 10, "upkeep_cost": 1, "outputs": {"food": 0, "production": 0, "military": 0.0, "stability": 0.0, "defense": 0.10, "tech": 0.0, "trade": 0}, "description": "Stone fortifications improving defense."},
	4: {"category": "production", "build_cost": 7, "upkeep_cost": 1, "outputs": {"food": 0, "production": 4, "military": 0.0, "stability": 0.0, "defense": 0.0, "tech": 0.0, "trade": 0}, "description": "Artisan workshops for manufacturing."},
	5: {"category": "knowledge", "build_cost": 10, "upkeep_cost": 1, "outputs": {"food": 0, "production": 0, "military": 0.0, "stability": 0.0, "defense": 0.0, "tech": 1.5, "trade": 0}, "description": "Repository advancing hidden tech metrics."},
	6: {"category": "administration", "build_cost": 6, "upkeep_cost": 0, "outputs": {"food": 0, "production": 0, "military": 0.0, "stability": 3.0, "defense": 0.0, "tech": 0.0, "trade": 0}, "description": "Grand monument inspiring civic unity."},
	7: {"category": "administration", "build_cost": 10, "upkeep_cost": 1, "outputs": {"food": 0, "production": 1, "military": 0.0, "stability": 2.0, "defense": 0.0, "tech": 0.5, "trade": 1}, "description": "Civic center enabling workforce management."},
}

# Building names for display
const BUILDING_NAMES := {
	0: "Granary",
	1: "Barracks",
	2: "Market",
	3: "Walls",
	4: "Workshop",
	5: "Library",
	6: "Monument",
	7: "Town Hall",
}

# Workforce presets (index -> multiplier dict)
const WORKFORCE_PRESETS := {
	0: {"name": "Balanced",  "food": 1.0, "production": 1.0, "military": 1.0, "stability": 1.0, "tech": 1.0},
	1: {"name": "Growth",    "food": 1.4, "production": 0.7, "military": 0.6, "stability": 1.0, "tech": 0.8},
	2: {"name": "Military",  "food": 0.8, "production": 0.8, "military": 1.6, "stability": 0.8, "tech": 0.6},
	3: {"name": "Trade",     "food": 0.8, "production": 1.3, "military": 0.5, "stability": 1.2, "tech": 1.0},
	4: {"name": "Knowledge", "food": 0.7, "production": 0.8, "military": 0.5, "stability": 1.0, "tech": 1.6},
}

# Urban gravity formula factors
const URBAN_GRAVITY_INFRA_FACTOR := 0.2
const URBAN_GRAVITY_TRADE_FACTOR := 0.1
const URBAN_GRAVITY_DEFAULT_TRADE_FLUX := 0.3

const DEFICIT_STABILITY_PENALTY_PER_TOWN := 2.0  # stability penalty per town in production deficit

# --- Research Focus ---
const RESEARCH_FOCUS_NAMES := {
	0: "Balanced", 1: "Knowledge", 2: "Energy",
	3: "Social", 4: "Economic", 5: "Military",
}
const RESEARCH_FOCUS_BOOST := 1.0  # +100% = 2x multiplier on focused metric growth
const RESEARCH_FOCUS_COOLDOWN_YEARS := 3

# --- Spending Priorities ---
const SPENDING_PRIORITY_NAMES := {
	0: "Balanced", 1: "Growth", 2: "Production", 3: "Military",
}
const SPENDING_PRIORITIES := {
	0: {"food": 1.0, "production": 1.0, "military": 1.0},
	1: {"food": 1.5, "production": 0.75, "military": 0.80},
	2: {"food": 0.85, "production": 1.5, "military": 0.80},
	3: {"food": 0.75, "production": 0.75, "military": 1.6},
}
const SPENDING_PRIORITY_COOLDOWN_YEARS := 5

# --- Trait Evolution ---
const TRAIT_MIN := 0.1
const TRAIT_MAX := 0.9
const TRAIT_TAG_HIGH_THRESHOLD := 0.6
const TRAIT_TAG_LOW_THRESHOLD := 0.3
const TRAIT_ANNUAL_DRIFT_MAGNITUDE := 0.01
const TRAIT_BATTLE_WIN_AGGRESSION := 0.02
const TRAIT_BATTLE_LOSE_AGGRESSION := -0.02
const TRAIT_BATTLE_LOSE_DIPLOMACY := 0.02
const TRAIT_GOLDEN_AGE_START_REINFORCE := 0.03
const TRAIT_GOLDEN_AGE_END_REGRESS := 0.01
const TRAIT_HERO_INFLUENCE_PER_YEAR := 0.01
const TRAIT_EXPANSION_CAPTURE := 0.02
const TRAIT_ALLIANCE_FORMED_DIPLOMACY := 0.02
const TRAIT_ALLIANCE_BROKEN_DIPLOMACY := -0.02
const TRAIT_ERA_MODERATION := 0.02
const TRAIT_ERA_EXTREME_THRESHOLD := 0.75
const TRAIT_LONG_PEACE_YEARS := 20
const TRAIT_LONG_PEACE_AGGRESSION := -0.02
const TRAIT_LONG_PEACE_ECONOMY := 0.02

# --- Unit System ---
const WORKER_TRAIN_COST := 8
const EXPLORER_TRAIN_COST := 12
const STARTING_WORKERS := 1
const STARTING_EXPLORERS := 1
const STARTING_LEADERS := 1

const UNIT_TYPE_NAMES := {
	0: "Worker",
	1: "Leader",
	2: "Explorer",
}

const WORKER_NAME_POOL := [
	"Artisan", "Mason", "Smith", "Carpenter", "Surveyor",
	"Engineer", "Builder", "Foreman", "Craftsman", "Laborer",
]

const EXPLORER_NAME_POOL := [
	"Scout", "Pathfinder", "Ranger", "Trailblazer", "Wayfinder",
	"Pioneer", "Vanguard", "Navigator", "Outrider", "Tracker",
]

# --- Leader Traits ---
# Each trait gives a civ-wide bonus. Player picks 2 at game start.
const LEADER_TRAITS := {
	0: {"name": "Builder", "bonus_type": "production", "bonus_value": 0.10},
	1: {"name": "Conqueror", "bonus_type": "military", "bonus_value": 0.10},
	2: {"name": "Diplomat", "bonus_type": "stability", "bonus_value": 5.0},
	3: {"name": "Visionary", "bonus_type": "tech", "bonus_value": 0.15},
	4: {"name": "Merchant", "bonus_type": "food", "bonus_value": 0.10},
}

# --- Society Traits ---
# Modifies starting civ personality biases. Player picks 1 at game start.
const SOCIETY_TRAITS := {
	0: {"name": "Warlike", "expansion_mod": 0.0, "aggression_mod": 0.15, "diplomacy_mod": -0.10, "economy_mod": 0.0},
	1: {"name": "Mercantile", "expansion_mod": 0.0, "aggression_mod": -0.10, "diplomacy_mod": 0.10, "economy_mod": 0.15},
	2: {"name": "Expansionist", "expansion_mod": 0.15, "aggression_mod": 0.0, "diplomacy_mod": 0.0, "economy_mod": 0.0},
	3: {"name": "Balanced", "expansion_mod": 0.0, "aggression_mod": 0.0, "diplomacy_mod": 0.0, "economy_mod": 0.0},
	4: {"name": "Isolationist", "expansion_mod": -0.10, "aggression_mod": -0.10, "diplomacy_mod": -0.10, "economy_mod": 0.15},
}


# --- Era-Scaled Map Visual Parameters ---
# Keys match Enums.Epoch values (0=PREHISTORIC, 1=CLASSICAL, 2=INDUSTRIAL, 3=FUTURE)
const ERA_VISUAL_PARAMS := {
	0: {  # PREHISTORIC -- rough parchment, hand-drawn feel
		"border_width": 0.8,
		"border_alpha": 0.25,
		"civ_border_width": 2.0,
		"border_style": "rough",
		"fog_color": Color(0.24, 0.21, 0.15, 1.0),
		"explored_modulate": Color(0.55, 0.52, 0.48, 1.0),
		"tint_alpha": 0.14,
		"noise_frequency_mult": 0.6,
		"noise_contrast_mult": 0.5,
		"deco_density": 0.5,
		"label_font_size": 10,
		"label_alpha": 0.6,
	},
	1: {  # CLASSICAL -- cleaner cartographic style
		"border_width": 1.2,
		"border_alpha": 0.35,
		"civ_border_width": 3.0,
		"border_style": "clean",
		"fog_color": Color(0.20, 0.18, 0.14, 1.0),
		"explored_modulate": Color(0.60, 0.58, 0.55, 1.0),
		"tint_alpha": 0.18,
		"noise_frequency_mult": 0.8,
		"noise_contrast_mult": 0.8,
		"deco_density": 0.8,
		"label_font_size": 11,
		"label_alpha": 0.8,
	},
	2: {  # INDUSTRIAL -- precise, detailed (current default look)
		"border_width": 1.5,
		"border_alpha": 0.45,
		"civ_border_width": 3.5,
		"border_style": "clean",
		"fog_color": Color(0.18, 0.16, 0.13, 1.0),
		"explored_modulate": Color(0.65, 0.65, 0.70, 1.0),
		"tint_alpha": 0.18,
		"noise_frequency_mult": 1.0,
		"noise_contrast_mult": 1.0,
		"deco_density": 1.0,
		"label_font_size": 11,
		"label_alpha": 1.0,
	},
	3: {  # FUTURE -- satellite/digital, sharp and vivid
		"border_width": 1.8,
		"border_alpha": 0.55,
		"civ_border_width": 4.0,
		"border_style": "glow",
		"fog_color": Color(0.10, 0.12, 0.16, 1.0),
		"explored_modulate": Color(0.72, 0.72, 0.78, 1.0),
		"tint_alpha": 0.22,
		"noise_frequency_mult": 1.5,
		"noise_contrast_mult": 1.3,
		"deco_density": 1.0,
		"label_font_size": 12,
		"label_alpha": 1.0,
	},
}
