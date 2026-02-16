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
const WAR_EXHAUSTION_PER_FRONT_MIN := 2.0
const WAR_EXHAUSTION_PER_FRONT_MAX := 5.0
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
const WAR_DECLARATION_STRENGTH_RATIO := 1.3
const WAR_DECLARATION_STABILITY_THRESHOLD := 45.0

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

# --- Terrain Base Yields [food, production] ---
const YIELD_RIVER_BASIN := Vector2i(5, 3)
const YIELD_PLAINS := Vector2i(3, 3)
const YIELD_MOUNTAINS := Vector2i(1, 1)
const YIELD_DESERT := Vector2i(1, 1)
const YIELD_JUNGLE := Vector2i(3, 1)
const YIELD_COASTLINE := Vector2i(3, 4)
const YIELD_TUNDRA := Vector2i(1, 1)

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

# --- Expansion / Snowball Control ---
const EXPANSION_BASE_PRODUCTION_COST := 15  # base production to settle a region
const EXPANSION_COST_ESCALATION := 5  # additional cost per region above threshold
const EXPANSION_SETTLER_POP := 300  # population moved to new region
const OVEREXTENSION_REGION_THRESHOLD := 25  # regions before overextension kicks in
const OVEREXTENSION_STABILITY_PER_REGION := 1.0  # stability drain per excess region
const DISCONNECTED_TERRITORY_PENALTY := 3.0  # stability drain per disconnected region

# --- Resource Depletion ---
const OVERUSE_THRESHOLD_YEARS := 10
const RENEWABLE_REGEN_RATE := 0.05
