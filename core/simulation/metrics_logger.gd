class_name MetricsLogger
extends RefCounted

## Per-year, per-civ CSV metrics logger for simulation tuning.
## Writes to user://metrics/ directory. Enable with MetricsLogger.enabled = true.

static var enabled: bool = false
static var _file: FileAccess = null
static var _path: String = ""


static func start(filename: String = "") -> void:
	if not enabled:
		return
	if filename.is_empty():
		filename = "sim_%d" % Time.get_unix_time_from_system()
	_path = "user://metrics/%s.csv" % filename
	DirAccess.make_dir_recursive_absolute("user://metrics")
	_file = FileAccess.open(_path, FileAccess.WRITE)
	if _file:
		_file.store_line(",".join([
			"year", "civ_id", "civ_name", "alive",
			"region_count", "stability", "population",
			"food_stockpile", "production_stockpile",
			"military_strength", "wars_active",
			"admin_capacity", "overextension_penalty",
			"war_exhaustion", "food_factor",
			"mean_reversion", "collapse_risk",
			"golden_age", "hero_count", "tech_count",
			"avg_dev_tier", "era",
			"metals", "commerce", "luxury_goods",
			"fuels", "manufactured", "rare_materials",
			"data", "strategic", "adv_energy",
			"resource_types_active",
		]))


static func log_year() -> void:
	if not enabled or _file == null:
		return
	var year := GameState.current_year
	for civ in GameState.civilizations.values():
		var owned := GameState.get_regions_by_owner(civ.id)
		var region_count := owned.size()
		var admin_cap := _calc_admin_capacity(civ, owned)
		var overext := _calc_overextension(region_count, admin_cap)
		var war_ex := _calc_war_exhaustion(civ)
		var food_fac := _calc_food_factor(civ)
		var mean_rev := _calc_mean_reversion(civ)
		var collapse_risk: int = civ.consecutive_low_stability_years

		var res: Dictionary = civ.resource_stockpiles
		var active_count := 0
		for rt in res:
			if res[rt] > 0:
				active_count += 1

		_file.store_line(",".join([
			str(year), str(civ.id), civ.civ_name, str(not civ.is_collapsed),
			str(region_count), "%.1f" % civ.stability, str(civ.total_population),
			str(civ.food_stockpile), str(civ.production_stockpile),
			"%.1f" % civ.military_strength, str(civ.war_targets.size()),
			str(admin_cap), "%.2f" % overext,
			"%.2f" % war_ex, "%.2f" % food_fac,
			"%.2f" % mean_rev, str(collapse_risk),
			str(civ.is_in_golden_age()), str(civ.hero_ids.size()),
			str(civ.technologies.size()),
			"%.2f" % _calc_avg_dev_tier(owned), str(civ.current_era),
			str(res.get(0, 0)), str(res.get(1, 0)), str(res.get(2, 0)),
			str(res.get(3, 0)), str(res.get(4, 0)), str(res.get(5, 0)),
			str(res.get(6, 0)), str(res.get(7, 0)), str(res.get(8, 0)),
			str(active_count),
		]))


static func finish() -> void:
	if _file:
		_file.close()
		_file = null
		if not _path.is_empty():
			print("  Metrics written to: %s" % _path)


static func _calc_admin_capacity(civ: CivilizationData, owned: Array[RegionData]) -> int:
	var base := Constants.ADMIN_CAPACITY_BASE
	var infra_bonus := 0
	for region in owned:
		infra_bonus += region.infrastructure_level
	var infra_contrib := floori(float(infra_bonus) * Constants.ADMIN_INFRA_BONUS_PER_LEVEL)
	var stab_contrib := floori(civ.stability / Constants.ADMIN_STABILITY_DIVISOR)
	return base + infra_contrib + stab_contrib


static func _calc_overextension(region_count: int, admin_cap: int) -> float:
	var excess := maxf(float(region_count - admin_cap), 0.0)
	return (excess * excess) / Constants.ADMIN_OVEREXTENSION_DIVISOR


static func _calc_war_exhaustion(civ: CivilizationData) -> float:
	if civ.war_targets.is_empty():
		return 0.0
	var exhaustion := 0.0
	for target_id in civ.war_targets:
		var duration: int = civ.war_durations.get(target_id, 0)
		exhaustion += minf(
			Constants.WAR_EXHAUSTION_BASE + float(duration) * Constants.WAR_EXHAUSTION_ESCALATION,
			Constants.WAR_EXHAUSTION_MAX_PER_FRONT,
		)
	return exhaustion


static func _calc_food_factor(civ: CivilizationData) -> float:
	return clampf(float(civ.food_stockpile) / 20.0, -5.0, 5.0)


static func _calc_mean_reversion(civ: CivilizationData) -> float:
	return (Constants.STABILITY_EQUILIBRIUM - civ.stability) * Constants.STABILITY_MEAN_REVERSION_RATE


static func _calc_avg_dev_tier(owned: Array[RegionData]) -> float:
	if owned.is_empty():
		return 0.0
	var total := 0
	for region in owned:
		total += region.development_tier
	return float(total) / float(owned.size())
