class_name DisasterSimulation
extends RefCounted

## Natural disaster simulation: volcanic eruptions, earthquakes, floods, droughts.
## Ticks down existing disasters and rolls for new ones each turn.
## Uses GameState.sim_rng for determinism.


static func process_disasters(events: Dictionary) -> void:
	## Tick existing disasters and roll for new ones across all regions.
	if not events.has("disaster_events"):
		events["disaster_events"] = []

	for region in GameState.regions.values():
		# Tick down existing disaster
		if region.active_disaster >= 0:
			region.disaster_years_remaining -= 1
			if region.disaster_years_remaining <= 0:
				region.active_disaster = -1
				region.disaster_yield_penalty = 0.0
			continue  # No stacking: skip new disaster roll while one is active

		# Roll for new disaster based on terrain risk
		_roll_disaster(region, events)


static func _roll_disaster(region: RegionData, events: Dictionary) -> void:
	## Check each disaster type against region terrain and roll probability.
	for disaster_type in Constants.DISASTER_RISKS:
		var risk: Dictionary = Constants.DISASTER_RISKS[disaster_type]
		var valid_terrains: Array = risk["terrains"]

		if not valid_terrains.has(region.terrain_type):
			continue

		# Floods only affect regions with rivers
		if disaster_type == Enums.DisasterType.FLOOD and not region.has_river:
			continue

		var roll := GameState.sim_rng.randf()
		if roll >= risk["annual_pct"]:
			continue

		# Disaster strikes!
		region.active_disaster = disaster_type
		region.disaster_years_remaining = risk["duration"]
		region.disaster_yield_penalty = risk["yield_penalty"]

		# Population loss
		if risk["pop_loss"] > 0.0 and region.population > 0:
			var pop_lost: int = int(float(region.population) * float(risk["pop_loss"]))
			region.population = maxi(region.population - pop_lost, 10)

		# Infrastructure damage
		if risk["infra_dmg"] > 0 and region.infrastructure_level > 0:
			region.infrastructure_level = maxi(region.infrastructure_level - risk["infra_dmg"], 0)

		# Record event
		var disaster_names := {
			Enums.DisasterType.VOLCANIC_ERUPTION: "Volcanic Eruption",
			Enums.DisasterType.EARTHQUAKE: "Earthquake",
			Enums.DisasterType.FLOOD: "Flood",
			Enums.DisasterType.DROUGHT: "Drought",
		}

		events["disaster_events"].append({
			"region_id": region.id,
			"region_name": region.region_name,
			"disaster_type": disaster_type,
			"disaster_name": disaster_names.get(disaster_type, "Disaster"),
			"owner_id": region.owner_id,
			"duration": risk["duration"],
		})

		break  # Only one disaster per region per turn
