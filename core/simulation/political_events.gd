class_name PoliticalEvents
extends RefCounted

## Political events: succession, elections, coups.
## Handles default political state, event generation, and choice resolution.

static func ensure_civ_state(civ: CivilizationData) -> void:
	# Legitimacy defaults
	if civ.legitimacy <= 0.0:
		civ.legitimacy = Constants.LEGITIMACY_START

	# Government form derived from governance tier
	var derived_form := _derive_government_form(civ.governance_tier)
	if civ.government_form == Enums.GovernmentForm.TRIBAL and derived_form != Enums.GovernmentForm.TRIBAL:
		civ.government_form = derived_form
	civ.succession_law = _derive_succession_law(civ.government_form)

	# Power blocs
	if civ.power_blocs.is_empty():
		civ.power_blocs = Constants.POWER_BLOC_DEFAULTS.duplicate(true)
	_normalize_blocs(civ.power_blocs)

	# Ruler / dynasty
	if civ.election_interval <= 0:
		civ.election_interval = Constants.DEFAULT_ELECTION_INTERVAL
	if civ.ruler_lifespan <= 0:
		civ.ruler_lifespan = GameState.sim_rng.randi_range(55, 80)
	if civ.dynasty_name == "" and civ.government_form != Enums.GovernmentForm.REPUBLIC:
		civ.dynasty_name = _random_from(Constants.DYNASTY_NAME_POOL)
	if civ.ruler_name == "":
		_install_new_ruler(civ, true)
	if civ.government_form != Enums.GovernmentForm.REPUBLIC and civ.heir_name == "":
		_generate_heir(civ)


static func generate_events(civ: CivilizationData) -> Array[Dictionary]:
	ensure_civ_state(civ)

	# Tick ruler aging and election timer
	civ.ruler_age += 1
	if civ.heir_name != "":
		civ.heir_age += 1
	if civ.government_form == Enums.GovernmentForm.REPUBLIC:
		civ.years_since_election += 1

	var events: Array[Dictionary] = []
	var emergency_election := false

	if civ.government_form == Enums.GovernmentForm.REPUBLIC:
		if civ.ruler_age >= civ.ruler_lifespan:
			emergency_election = true
		if emergency_election or civ.years_since_election >= civ.election_interval:
			events.append(_make_election_event(civ, emergency_election))
	else:
		if civ.ruler_age >= civ.ruler_lifespan:
			events.append(_make_succession_event(civ))

	if _should_trigger_coup(civ):
		events.append(_make_coup_event(civ))

	return events


static func resolve_event_choice(event: Dictionary, choice_index: int, record_history: bool = true) -> String:
	var civ: CivilizationData = GameState.get_civilization(event.get("civ_id", -1))
	if not civ:
		return ""
	ensure_civ_state(civ)

	var choices: Array = event.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return ""
	var choice: Dictionary = choices[choice_index]

	var old_legitimacy: float = civ.legitimacy
	_apply_effects(civ, choice.get("effects", {}), event.get("type", ""))

	if record_history:
		var desc: String = "%s — %s" % [event.get("title", "Political Event"), choice.get("label", "Decision")]
		History.record_event({
			"year": event.get("year", GameState.current_year),
			"type": event.get("type", "political"),
			"civ_id": civ.id,
			"civ_name": civ.civ_name,
			"description": desc,
		})

	if civ.legitimacy != old_legitimacy:
		EventBus.legitimacy_changed.emit(civ.id, old_legitimacy, civ.legitimacy)

	match event.get("type", ""):
		"succession":
			EventBus.succession_event.emit(civ.id, int(event.get("id", -1)))
		"election":
			EventBus.election_held.emit(civ.id, int(event.get("id", -1)))
		"coup":
			EventBus.coup_attempted.emit(civ.id, int(event.get("id", -1)))

	return choice.get("label", "")


static func pick_ai_choice(event: Dictionary) -> int:
	var civ: CivilizationData = GameState.get_civilization(event.get("civ_id", -1))
	if not civ:
		return 0
	ensure_civ_state(civ)

	var event_type: String = event.get("type", "")
	match event_type:
		"succession":
			if civ.heir_name != "":
				return 0
			var military: float = civ.power_blocs.get("military", 0.2)
			return 0 if military >= 0.28 else 1
		"election":
			var merchants: float = civ.power_blocs.get("merchants", 0.18)
			var nobles: float = civ.power_blocs.get("nobles", 0.22)
			var clergy: float = civ.power_blocs.get("clergy", 0.16)
			if merchants >= 0.24:
				return 0
			if nobles >= 0.25 or clergy >= 0.22:
				return 1
			return 2
		"coup":
			var military: float = civ.power_blocs.get("military", 0.2)
			if military >= 0.35:
				return 1  # purge
			return 0  # negotiate
	return 0


static func drift_power_blocs(civ: CivilizationData, _owned_regions: Array[RegionData]) -> void:
	ensure_civ_state(civ)
	var blocs: Dictionary = civ.power_blocs

	var econ_surplus: float = float(civ.food_stockpile + civ.production_stockpile) / 200.0
	var econ_shift: float = clampf(econ_surplus, -0.02, 0.02)
	blocs["merchants"] = float(blocs.get("merchants", 0.18)) + econ_shift

	if not civ.war_targets.is_empty():
		blocs["military"] = float(blocs.get("military", 0.20)) + 0.02
	else:
		blocs["military"] = float(blocs.get("military", 0.20)) - 0.01

	if civ.stability > 60.0:
		blocs["clergy"] = float(blocs.get("clergy", 0.16)) + 0.01
	elif civ.stability < 35.0:
		blocs["clergy"] = float(blocs.get("clergy", 0.16)) - 0.01

	blocs["nobles"] = float(blocs.get("nobles", 0.22)) + float(civ.governance_tier) * 0.002

	# Commoners absorb residual through normalization
	_normalize_blocs(blocs)


# --- Event Builders ---

static func _make_succession_event(civ: CivilizationData) -> Dictionary:
	var has_heir := civ.heir_name != ""
	var choices: Array = []
	if has_heir:
		choices.append({
			"label": "Crown the heir",
			"effects": {"install_heir": true, "legitimacy_delta": 6.0, "stability_delta": 2.0,
				"bloc_delta": {"nobles": 0.05}},
		})
		choices.append({
			"label": "Form a regency council",
			"effects": {"install_council": true, "legitimacy_delta": -4.0, "stability_delta": 1.0,
				"bloc_delta": {"merchants": 0.03, "military": 0.03}},
		})
	else:
		choices.append({
			"label": "Elevate a general",
			"effects": {"install_new_ruler": true, "legitimacy_delta": -8.0, "stability_delta": -1.0,
				"bloc_delta": {"military": 0.08}},
		})
		choices.append({
			"label": "Elect a claimant",
			"effects": {"install_new_ruler": true, "legitimacy_delta": -3.0, "stability_delta": 1.0,
				"bloc_delta": {"commoners": 0.05}},
		})

	return _make_event(civ, "succession", "Succession Crisis", choices)


static func _make_election_event(civ: CivilizationData, emergency: bool) -> Dictionary:
	var title: String = "Emergency Election" if emergency else "Election Year"
	var choices: Array = [
		{
			"label": "Reformist platform",
			"effects": {"install_new_ruler": true, "legitimacy_delta": 4.0, "stability_delta": 1.0,
				"bloc_delta": {"merchants": 0.05, "clergy": -0.02}},
		},
		{
			"label": "Traditionalist platform",
			"effects": {"install_new_ruler": true, "legitimacy_delta": 2.0, "stability_delta": 2.0,
				"bloc_delta": {"nobles": 0.05, "merchants": -0.03}},
		},
		{
			"label": "Populist platform",
			"effects": {"install_new_ruler": true, "legitimacy_delta": 3.0, "stability_delta": -1.0,
				"bloc_delta": {"commoners": 0.06, "nobles": -0.03}},
		},
	]
	return _make_event(civ, "election", title, choices)


static func _make_coup_event(civ: CivilizationData) -> Dictionary:
	var choices: Array = [
		{
			"label": "Negotiate with generals",
			"effects": {"legitimacy_delta": 3.0, "stability_delta": 1.0,
				"bloc_delta": {"military": -0.05}},
		},
		{
			"label": "Purge the plotters",
			"effects": {"legitimacy_delta": -5.0, "stability_delta": -4.0,
				"bloc_delta": {"military": 0.05}},
		},
		{
			"label": "Step down",
			"effects": {"install_new_ruler": true, "set_legitimacy": 40.0, "stability_delta": -2.0,
				"government_form": Enums.GovernmentForm.AUTOCRACY, "bloc_delta": {"military": 0.05}},
		},
	]
	return _make_event(civ, "coup", "Coup Attempt", choices)


static func _make_event(civ: CivilizationData, event_type: String, title: String, choices: Array) -> Dictionary:
	var event_id: int = GameState.next_political_event_id
	GameState.next_political_event_id += 1
	return {
		"id": event_id,
		"year": GameState.current_year,
		"civ_id": civ.id,
		"civ_name": civ.civ_name,
		"type": event_type,
		"title": title,
		"description": _event_description(civ, event_type),
		"choices": choices,
	}


static func _event_description(civ: CivilizationData, event_type: String) -> String:
	match event_type:
		"succession":
			return "The ruler of %s has died. The realm awaits a new hand." % civ.civ_name
		"election":
			return "%s prepares to choose a new government." % civ.civ_name
		"coup":
			return "Elements of the military challenge the current regime in %s." % civ.civ_name
	return "A political decision confronts %s." % civ.civ_name


# --- Helpers ---

static func _should_trigger_coup(civ: CivilizationData) -> bool:
	if civ.legitimacy >= Constants.LEGITIMACY_COUP_THRESHOLD:
		return false
	var military: float = civ.power_blocs.get("military", 0.2)
	if military < Constants.COUP_MILITARY_BLOC_THRESHOLD:
		return false
	var severity := clampf(
		(Constants.LEGITIMACY_COUP_THRESHOLD - civ.legitimacy) / Constants.LEGITIMACY_COUP_THRESHOLD,
		0.0, 1.0
	)
	var chance := Constants.COUP_BASE_CHANCE * severity
	return GameState.sim_rng.randf() < chance


static func _apply_effects(civ: CivilizationData, effects: Dictionary, event_type: String) -> void:
	if effects.has("government_form"):
		civ.government_form = effects["government_form"]
		civ.succession_law = _derive_succession_law(civ.government_form)

	if effects.has("set_legitimacy"):
		civ.legitimacy = clampf(float(effects["set_legitimacy"]), 0.0, 100.0)
	if effects.has("legitimacy_delta"):
		civ.legitimacy = clampf(civ.legitimacy + float(effects["legitimacy_delta"]), 0.0, 100.0)

	if effects.has("stability_delta"):
		civ.stability = clampf(civ.stability + float(effects["stability_delta"]), 0.0, 100.0)

	if effects.has("bloc_delta"):
		var bloc_delta: Dictionary = effects["bloc_delta"]
		for key in bloc_delta:
			civ.power_blocs[key] = float(civ.power_blocs.get(key, 0.0)) + float(bloc_delta[key])
		_normalize_blocs(civ.power_blocs)

	if effects.has("install_heir") and effects["install_heir"]:
		_install_heir_as_ruler(civ)
	elif effects.has("install_new_ruler") and effects["install_new_ruler"]:
		_install_new_ruler(civ, false)
	elif effects.has("install_council") and effects["install_council"]:
		civ.ruler_name = "Regency Council"
		civ.ruler_age = 0
		civ.ruler_lifespan = 999

	# Election resets
	if event_type == "election":
		civ.years_since_election = 0


static func _install_new_ruler(civ: CivilizationData, first_install: bool) -> void:
	var first := _random_from(Constants.RULER_FIRST_NAME_POOL)
	if civ.government_form == Enums.GovernmentForm.REPUBLIC:
		civ.ruler_name = first
	else:
		if civ.dynasty_name == "":
			civ.dynasty_name = _random_from(Constants.DYNASTY_NAME_POOL)
		civ.ruler_name = "%s %s" % [first, civ.dynasty_name]
	civ.ruler_age = GameState.sim_rng.randi_range(22, 50) if first_install else GameState.sim_rng.randi_range(18, 45)
	civ.ruler_lifespan = GameState.sim_rng.randi_range(55, 80)
	if civ.government_form != Enums.GovernmentForm.REPUBLIC:
		_generate_heir(civ)
	else:
		civ.heir_name = ""


static func _install_heir_as_ruler(civ: CivilizationData) -> void:
	if civ.heir_name == "":
		_install_new_ruler(civ, false)
		return
	civ.ruler_name = civ.heir_name
	civ.ruler_age = max(civ.heir_age, 16)
	civ.ruler_lifespan = GameState.sim_rng.randi_range(55, 80)
	_generate_heir(civ)


static func _generate_heir(civ: CivilizationData) -> void:
	if civ.government_form == Enums.GovernmentForm.REPUBLIC:
		civ.heir_name = ""
		return
	var first := _random_from(Constants.RULER_FIRST_NAME_POOL)
	if civ.dynasty_name == "":
		civ.dynasty_name = _random_from(Constants.DYNASTY_NAME_POOL)
	civ.heir_name = "%s %s" % [first, civ.dynasty_name]
	civ.heir_age = GameState.sim_rng.randi_range(4, 18)


static func _derive_government_form(tier: Enums.GovernanceTier) -> Enums.GovernmentForm:
	match tier:
		Enums.GovernanceTier.TRIBAL, Enums.GovernanceTier.CHIEFDOM:
			return Enums.GovernmentForm.TRIBAL
		Enums.GovernanceTier.CITY_STATE, Enums.GovernanceTier.KINGDOM:
			return Enums.GovernmentForm.MONARCHY
		Enums.GovernanceTier.EMPIRE:
			return Enums.GovernmentForm.AUTOCRACY
		Enums.GovernanceTier.FEDERATION:
			return Enums.GovernmentForm.REPUBLIC
	return Enums.GovernmentForm.TRIBAL


static func _derive_succession_law(form: Enums.GovernmentForm) -> Enums.SuccessionLaw:
	match form:
		Enums.GovernmentForm.REPUBLIC:
			return Enums.SuccessionLaw.ELECTIVE
		Enums.GovernmentForm.TRIBAL:
			return Enums.SuccessionLaw.MERITOCRATIC
	return Enums.SuccessionLaw.PRIMOGENITURE


static func _normalize_blocs(blocs: Dictionary) -> void:
	var total := 0.0
	for key in blocs:
		var v: float = float(blocs[key])
		if v < 0.01:
			v = 0.01
		blocs[key] = v
		total += v
	if total <= 0.0:
		return
	for key in blocs:
		blocs[key] = float(blocs[key]) / total


static func _random_from(pool: Array) -> String:
	if pool.is_empty():
		return "Unknown"
	var idx := GameState.sim_rng.randi_range(0, pool.size() - 1)
	return str(pool[idx])
