class_name CivilizationData
extends Resource

## Data resource for a civilization.

@export var id: int = -1
@export var civ_name: String = ""
@export var color: Color = Color.WHITE
@export var stability: float = Constants.STABILITY_START
@export var total_population: int = 0
@export var food_stockpile: int = 0
@export var production_stockpile: int = 0
@export var military_strength: float = 0.0
@export var capital_region_id: int = -1
@export var hero_ids: Array[int] = []
@export var is_collapsed: bool = false
@export var is_player: bool = false
@export var governance_tier: Enums.GovernanceTier = Enums.GovernanceTier.TRIBAL
@export var governance_years: int = 0  # years spent in current tier
@export var current_era: Enums.Epoch = Enums.Epoch.PREHISTORIC

# Golden age state
@export var golden_age_years_remaining: int = 0
@export var golden_age_cooldown: int = 0

# Hidden tech metrics (0-100 each)
@export var knowledge: float = 0.0
@export var energy: float = 0.0
@export var social_coordination: float = 0.0
@export var economic_surplus: float = 0.0
@export var military_pressure: float = 0.0

# AI personality biases (0.0-1.0)
@export var expansion_bias: float = 0.5
@export var aggression_bias: float = 0.5
@export var diplomacy_bias: float = 0.5
@export var economy_bias: float = 0.5

# War tracking
@export var war_targets: Array[int] = []  # civ IDs at war with
@export var war_durations: Dictionary = {}  # {civ_id: years_at_war}
@export var peace_cooldowns: Dictionary = {}  # {civ_id: years_remaining}
@export var alliance_partners: Array[int] = []  # civ IDs allied with
@export var consecutive_low_stability_years: int = 0

# Discovered technologies
@export var technologies: Array[String] = []

# Resource pyramid stockpiles (pooled at civ level)
@export var resource_stockpiles: Dictionary = {}  # {resource_type_int: amount}
@export var resource_production_log: Dictionary = {}  # {resource_type_int: last_turn_production}


func _init(
	p_id: int = -1,
	p_name: String = "",
	p_color: Color = Color.WHITE,
) -> void:
	id = p_id
	civ_name = p_name
	color = p_color


func is_at_war() -> bool:
	return not war_targets.is_empty()


func is_in_golden_age() -> bool:
	return golden_age_years_remaining > 0


func can_enter_golden_age() -> bool:
	return (
		stability > Constants.GOLDEN_AGE_STABILITY_THRESHOLD
		and food_stockpile > 0
		and production_stockpile > 0
		and not is_at_war()
		and golden_age_cooldown <= 0
	)


func hero_count() -> int:
	return hero_ids.size()


func can_spawn_hero() -> bool:
	return hero_count() < Constants.HERO_MAX_PER_CIV


func get_state() -> Enums.CivState:
	if is_collapsed:
		return Enums.CivState.COLLAPSED
	if stability < Constants.AI_SURVIVAL_STABILITY_THRESHOLD:
		return Enums.CivState.DECLINING
	if is_in_golden_age() or stability > 70.0:
		return Enums.CivState.GROWING
	return Enums.CivState.STABLE
