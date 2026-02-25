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

# Political state
@export var legitimacy: float = Constants.LEGITIMACY_START
@export var government_form: Enums.GovernmentForm = Enums.GovernmentForm.TRIBAL
@export var succession_law: Enums.SuccessionLaw = Enums.SuccessionLaw.PRIMOGENITURE
@export var dynasty_name: String = ""
@export var ruler_name: String = ""
@export var ruler_age: int = 30
@export var ruler_lifespan: int = 70
@export var heir_name: String = ""
@export var heir_age: int = 12
@export var years_since_election: int = 0
@export var election_interval: int = Constants.DEFAULT_ELECTION_INTERVAL
@export var power_blocs: Dictionary = {}

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

# Trait evolution tracking
@export var initial_expansion_bias: float = -1.0
@export var initial_aggression_bias: float = -1.0
@export var initial_diplomacy_bias: float = -1.0
@export var initial_economy_bias: float = -1.0
@export var years_at_peace: int = 0
@export var cartography_skill: float = 0.0  # 0-1, grows per turn

# War tracking
@export var war_targets: Array[int] = []  # civ IDs at war with
@export var war_durations: Dictionary = {}  # {civ_id: years_at_war}
@export var peace_cooldowns: Dictionary = {}  # {civ_id: years_remaining}
@export var alliance_partners: Array[int] = []  # civ IDs allied with
@export var nap_partners: Dictionary = {}      # {civ_id: years_remaining}
@export var trade_partners: Array[int] = []
@export var tribute_cooldowns: Dictionary = {} # {civ_id: years_remaining}
@export var consecutive_low_stability_years: int = 0

# Discovered technologies
@export var technologies: Array[String] = []

# Resource pyramid stockpiles (pooled at civ level)
@export var resource_stockpiles: Dictionary = {}  # {resource_type_int: amount}
@export var resource_production_log: Dictionary = {}  # {resource_type_int: last_turn_production}

# Research focus and spending priority (Player Agency Sprint)
@export var research_focus: int = 0  # 0=Balanced, 1=Knowledge, 2=Energy, 3=Social, 4=Economic, 5=Military
@export var research_focus_cooldown: int = 0  # years remaining before can change
@export var spending_priority: int = 0  # 0=Balanced, 1=Growth, 2=Production, 3=Military
@export var spending_priority_cooldown: int = 0  # years remaining before can change

# Fog of War visibility tracking (player-only for V0.1)
@export var explored_regions: Array[int] = []  # Permanently explored region IDs (saved)
var explored_set: Dictionary = {}              # {region_id: true} O(1) lookup cache
var visible_regions: Dictionary = {}           # {region_id: true} computed each turn (not saved)


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


func initialize_trait_tracking() -> void:
	## Snapshot initial biases for "how much have I changed" display.
	## Only sets if not already initialized (supports save/load).
	if initial_expansion_bias < 0.0:
		initial_expansion_bias = expansion_bias
		initial_aggression_bias = aggression_bias
		initial_diplomacy_bias = diplomacy_bias
		initial_economy_bias = economy_bias


func get_dominant_bias_name() -> String:
	## Returns the field name of the highest bias.
	var max_val := expansion_bias
	var max_name := "expansion_bias"
	if aggression_bias > max_val:
		max_val = aggression_bias
		max_name = "aggression_bias"
	if diplomacy_bias > max_val:
		max_val = diplomacy_bias
		max_name = "diplomacy_bias"
	if economy_bias > max_val:
		max_val = economy_bias
		max_name = "economy_bias"
	return max_name


func get_personality_tags() -> Array[String]:
	## Returns human-readable personality tags based on AI biases.
	var tags: Array[String] = []
	if expansion_bias >= 0.6:
		tags.append("Expansionist")
	elif expansion_bias <= 0.3:
		tags.append("Insular")
	if aggression_bias >= 0.6:
		tags.append("Warlike")
	elif aggression_bias <= 0.3:
		tags.append("Pacifist")
	if diplomacy_bias >= 0.6:
		tags.append("Diplomatic")
	elif diplomacy_bias <= 0.3:
		tags.append("Isolationist")
	if economy_bias >= 0.6:
		tags.append("Mercantile")
	elif economy_bias <= 0.3:
		tags.append("Austere")
	return tags


func get_state() -> Enums.CivState:
	if is_collapsed:
		return Enums.CivState.COLLAPSED
	if stability < Constants.AI_SURVIVAL_STABILITY_THRESHOLD:
		return Enums.CivState.DECLINING
	if is_in_golden_age() or stability > 70.0:
		return Enums.CivState.GROWING
	return Enums.CivState.STABLE
