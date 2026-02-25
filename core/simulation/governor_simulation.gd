class_name GovernorSimulation
extends RefCounted

## Governor and political geography simulation.
## Computes political influence, generates lobby requests,
## applies capital bonuses, and tracks ignored request penalties.


static func process_governors(events: Dictionary) -> Dictionary:
	## Process governors for all civs. Returns stability modifiers per civ.
	## {civ_id: float} - positive for fulfilled lobbies, negative for ignored.
	var stability_mods: Dictionary = {}

	for civ in GameState.civilizations.values():
		if civ.is_collapsed:
			continue
		var owned: Array[RegionData] = []
		for region in GameState.regions.values():
			if region.owner_id == civ.id:
				owned.append(region)
		if owned.is_empty():
			continue

		var civ_mod := 0.0

		# Compute influence scores
		var max_pop := 1
		var max_infra := 1
		for region in owned:
			max_pop = maxi(max_pop, region.population)
			max_infra = maxi(max_infra, region.infrastructure_level)

		for region in owned:
			# Political influence: weighted score from pop, dev, infra, capital
			var pop_score := float(region.population) / float(max_pop)
			var dev_score := float(region.development_tier) / 5.0
			var infra_score := float(region.infrastructure_level) / float(maxi(max_infra, 1))
			var capital_score := 1.0 if region.id == civ.capital_region_id else 0.0

			region.political_influence = clampf(
				pop_score * Constants.INFLUENCE_WEIGHT_POP
				+ dev_score * Constants.INFLUENCE_WEIGHT_DEV
				+ infra_score * Constants.INFLUENCE_WEIGHT_INFRA
				+ capital_score * Constants.INFLUENCE_WEIGHT_CAPITAL,
				0.0, 1.0) * 100.0

			# Process existing lobby requests
			if region.lobby_request >= 0:
				region.lobby_ignore_years += 1
				civ_mod -= Constants.LOBBY_IGNORE_STABILITY_PENALTY
			else:
				# Roll for new lobby request (high-influence regions only)
				if region.political_influence > 30.0:
					var roll := GameState.sim_rng.randf()
					if roll < Constants.LOBBY_ANNUAL_CHANCE:
						region.lobby_request = _pick_lobby_request(region)

		# Capital stability bonus
		var capital := GameState.get_region(civ.capital_region_id)
		if capital and capital.owner_id == civ.id:
			civ_mod += Constants.CAPITAL_STABILITY_BONUS

		stability_mods[civ.id] = civ_mod

	return stability_mods


static func _pick_lobby_request(region: RegionData) -> int:
	## Pick a building type that the region needs, based on its conditions.
	## Returns GovernorFocus int.
	if region.food_yield < 4:
		return Enums.GovernorFocus.GROWTH
	if region.infrastructure_level < 2:
		return Enums.GovernorFocus.INFRASTRUCTURE
	if region.defense_modifier < 1.0:
		return Enums.GovernorFocus.MILITARY
	# Default to trade or knowledge
	if GameState.sim_rng.randf() < 0.5:
		return Enums.GovernorFocus.TRADE
	return Enums.GovernorFocus.KNOWLEDGE


static func fulfill_lobby(region: RegionData) -> float:
	## Called when player approves a lobby request.
	## Returns stability bonus.
	region.lobby_request = -1
	region.lobby_ignore_years = 0
	return Constants.LOBBY_FULFILL_STABILITY_BONUS


static func apply_capital_bonuses(civ: CivilizationData, owned_regions: Array[RegionData]) -> void:
	## Apply capital region bonuses (defense, production boost handled in economy).
	var capital := GameState.get_region(civ.capital_region_id)
	if not capital or capital.owner_id != civ.id:
		return
	# Capital defense bonus is applied in war_resolver via region check
	# Stability bonus is applied in stability step
