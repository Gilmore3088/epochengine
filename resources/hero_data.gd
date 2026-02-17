class_name HeroData
extends Resource

## Data resource for a hero character.

@export var id: int = -1
@export var hero_name: String = ""
@export var type: Enums.HeroType = Enums.HeroType.GENERAL
@export var age: int = 20
@export var lifespan: int = 60
@export var owner_civ_id: int = -1
@export var birth_year: int = 0


func _init(
	p_id: int = -1,
	p_name: String = "",
	p_type: Enums.HeroType = Enums.HeroType.GENERAL,
	p_owner: int = -1,
) -> void:
	id = p_id
	hero_name = p_name
	type = p_type
	owner_civ_id = p_owner
	lifespan = GameState.sim_rng.randi_range(Constants.HERO_LIFESPAN_MIN, Constants.HERO_LIFESPAN_MAX)


func get_modifier_type() -> String:
	match type:
		Enums.HeroType.GENERAL:
			return "military"
		Enums.HeroType.REFORMER:
			return "stability"
		Enums.HeroType.VISIONARY:
			return "production"
	return ""


func get_modifier_value() -> float:
	match type:
		Enums.HeroType.GENERAL:
			return Constants.HERO_GENERAL_MILITARY_BONUS
		Enums.HeroType.REFORMER:
			return Constants.HERO_REFORMER_STABILITY_BONUS
		Enums.HeroType.VISIONARY:
			return Constants.HERO_VISIONARY_PRODUCTION_BONUS
	return 0.0


func is_alive() -> bool:
	return age < lifespan


func age_one_year() -> void:
	age += 1
