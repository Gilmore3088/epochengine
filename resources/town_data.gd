class_name TownData
extends Resource

## Data resource for a single town within a region.
## Towns produce food/production based on terrain share + buildings.

@export var id: int = -1
@export var town_name: String = ""
@export var region_id: int = -1
@export var population: int = 0
@export var buildings: Array[Dictionary] = []  # [{type: BuildingType, count: int}]
@export var infrastructure_level: int = 0
@export var founded_year: int = 0
@export var workforce_preset: int = 0  # index into Constants.WORKFORCE_PRESETS


func _init(
	p_id: int = -1,
	p_name: String = "",
	p_region_id: int = -1,
) -> void:
	id = p_id
	town_name = p_name
	region_id = p_region_id


func get_building_count(building_type: int) -> int:
	for entry in buildings:
		if entry.get("type", -1) == building_type:
			return entry.get("count", 0)
	return 0


func get_total_building_count() -> int:
	var total := 0
	for entry in buildings:
		total += entry.get("count", 0)
	return total


func add_building(building_type: int) -> void:
	for entry in buildings:
		if entry.get("type", -1) == building_type:
			entry["count"] = entry.get("count", 0) + 1
			return
	buildings.append({"type": building_type, "count": 1})


func get_food_bonus() -> int:
	## Food bonus from all buildings via BUILDING_RULES.
	var bonus := 0
	for entry in buildings:
		var btype: int = entry.get("type", -1)
		var count: int = entry.get("count", 0)
		if Constants.BUILDING_RULES.has(btype):
			bonus += count * int(Constants.BUILDING_RULES[btype]["outputs"]["food"])
	return bonus


func get_production_bonus() -> int:
	## Production bonus from all buildings via BUILDING_RULES.
	var bonus := 0
	for entry in buildings:
		var btype: int = entry.get("type", -1)
		var count: int = entry.get("count", 0)
		if Constants.BUILDING_RULES.has(btype):
			bonus += count * int(Constants.BUILDING_RULES[btype]["outputs"]["production"])
	return bonus


func get_defense_bonus() -> float:
	## Defense bonus from all buildings via BUILDING_RULES.
	var bonus := 0.0
	for entry in buildings:
		var btype: int = entry.get("type", -1)
		var count: int = entry.get("count", 0)
		if Constants.BUILDING_RULES.has(btype):
			bonus += float(count) * float(Constants.BUILDING_RULES[btype]["outputs"]["defense"])
	return bonus


func get_stability_bonus() -> float:
	## Stability bonus from all buildings via BUILDING_RULES.
	var bonus := 0.0
	for entry in buildings:
		var btype: int = entry.get("type", -1)
		var count: int = entry.get("count", 0)
		if Constants.BUILDING_RULES.has(btype):
			bonus += float(count) * float(Constants.BUILDING_RULES[btype]["outputs"]["stability"])
	return bonus


func get_military_bonus() -> float:
	## Military bonus from all buildings via BUILDING_RULES.
	var bonus := 0.0
	for entry in buildings:
		var btype: int = entry.get("type", -1)
		var count: int = entry.get("count", 0)
		if Constants.BUILDING_RULES.has(btype):
			bonus += float(count) * float(Constants.BUILDING_RULES[btype]["outputs"]["military"])
	return bonus


func get_maintenance_cost() -> int:
	## Total production maintenance via BUILDING_RULES upkeep_cost.
	var total := 0
	for entry in buildings:
		var btype: int = entry.get("type", -1)
		var count: int = entry.get("count", 0)
		if Constants.BUILDING_RULES.has(btype):
			total += count * int(Constants.BUILDING_RULES[btype]["upkeep_cost"])
		else:
			total += count * Constants.BUILDING_MAINTENANCE_PER
	return total


func to_dict() -> Dictionary:
	return {
		"id": id,
		"town_name": town_name,
		"region_id": region_id,
		"population": population,
		"buildings": buildings.duplicate(true),
		"infrastructure_level": infrastructure_level,
		"founded_year": founded_year,
		"workforce_preset": workforce_preset,
	}


static func from_dict(data: Dictionary) -> Resource:
	var script = load("res://resources/town_data.gd")
	var town = script.new(
		data.get("id", -1),
		data.get("town_name", ""),
		data.get("region_id", -1),
	)
	town.population = data.get("population", 0)
	town.buildings = data.get("buildings", [])
	town.infrastructure_level = data.get("infrastructure_level", 0)
	town.founded_year = data.get("founded_year", 0)
	town.workforce_preset = data.get("workforce_preset", 0)
	return town
