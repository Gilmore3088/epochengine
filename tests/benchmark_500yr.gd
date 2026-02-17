extends Node

## 500-year headless benchmark.
## Runs the full simulation pipeline and reports performance + event stats.
## Usage: godot --headless --path . res://tests/benchmark_500yr.tscn

const YEARS := 500
const RUNS := 20
const CSV_PATH := "user://benchmark_results.csv"

var run_results: Array[Dictionary] = []


func _ready() -> void:
	# Delay one frame to ensure autoloads are fully initialized
	call_deferred("_run_all")


func _run_all() -> void:
	print("=" .repeat(60))
	print("EPOCH ENGINE - 500-YEAR BENCHMARK (%d runs)" % RUNS)
	print("=" .repeat(60))
	print("")

	for run_idx in RUNS:
		_reset_game_state()
		var result := _run_benchmark(run_idx)
		run_results.append(result)
		_print_run_result(run_idx, result)

	print("")
	_print_aggregate()
	_export_csv()
	get_tree().quit()


func _reset_game_state() -> void:
	GameState.regions.clear()
	GameState.civilizations.clear()
	GameState.heroes.clear()
	GameState.current_year = 0
	GameState.next_hero_id = 0
	GameState.turn_log.clear()
	GameState.load_game_data()


func _run_benchmark(run_idx: int) -> Dictionary:
	GameState.set_sim_seed(run_idx * 31337 + 42)

	var stats := {
		"collapses": 0,
		"golden_ages": 0,
		"wars": 0,
		"battles": 0,
		"techs": 0,
		"expansions": 0,
		"heroes_spawned": 0,
		"heroes_died": 0,
		"shortages": 0,
		"peace_treaties": 0,
		"infrastructure_upgrades": 0,
		"years_completed": 0,
		"total_time_ms": 0.0,
		"time_per_10yr_ms": 0.0,
		"final_civs_alive": 0,
		"final_total_pop": 0,
		"final_regions_owned": {},
		"final_techs": {},
		"collapse_years": {},
		"error": "",
	}

	var start_time := Time.get_ticks_msec()
	var time_10yr_start := start_time

	for year in YEARS:
		GameState.current_year += 1
		var events := SimulationEngine.process_year()

		stats["collapses"] += events["collapses"].size()
		stats["golden_ages"] += events["golden_age_starts"].size()
		stats["wars"] += _count_type(events["ai_events"], "war_declared")
		stats["battles"] += events["battles"].size()
		stats["techs"] += events["tech_emergences"].size()
		stats["expansions"] += _count_type(events["ai_events"], "expansion")
		stats["heroes_spawned"] += events["spawned_heroes"].size()
		stats["heroes_died"] += events["dead_heroes"].size()
		stats["shortages"] += _count_shortages(events["economy_results"])
		stats["peace_treaties"] += _count_type(events["ai_events"], "peace")
		stats["infrastructure_upgrades"] += _count_type(events["ai_events"], "infrastructure_upgrade")

		for collapse in events["collapses"]:
			stats["collapse_years"][collapse["civ_name"]] = year + 1

		# Detailed log for first run (every 5 years for first 100, then every 50)
		if run_idx == 0 and ((year + 1 <= 100 and (year + 1) % 5 == 0) or (year + 1 > 100 and (year + 1) % 50 == 0)):
			_print_year_snapshot(year + 1)

		stats["years_completed"] = year + 1

		if (year + 1) % 10 == 0:
			var elapsed := Time.get_ticks_msec() - time_10yr_start
			if elapsed > stats["time_per_10yr_ms"]:
				stats["time_per_10yr_ms"] = elapsed
			time_10yr_start = Time.get_ticks_msec()

	var total_time := Time.get_ticks_msec() - start_time
	stats["total_time_ms"] = total_time

	var alive := GameState.get_alive_civilizations()
	stats["final_civs_alive"] = alive.size()

	var total_pop := 0
	for civ in GameState.civilizations.values():
		var owned := GameState.get_regions_by_owner(civ.id)
		stats["final_regions_owned"][civ.civ_name] = owned.size()
		stats["final_techs"][civ.civ_name] = civ.technologies.duplicate()
		total_pop += civ.total_population
	stats["final_total_pop"] = total_pop

	return stats


func _print_year_snapshot(year: int) -> void:
	var line := "  [Y%d]" % year
	for civ in GameState.civilizations.values():
		var regions := GameState.get_regions_by_owner(civ.id).size()
		if civ.is_collapsed:
			line += " %s:DEAD" % civ.civ_name.left(8)
		else:
			line += " %s: pop=%s stab=%.0f food=%d prod=%d mil=%.0f rgn=%d" % [
				civ.civ_name.left(8), _fmt_pop(civ.total_population),
				civ.stability, civ.food_stockpile, civ.production_stockpile,
				civ.military_strength, regions,
			]
	print(line)


func _count_type(events: Array, type_name: String) -> int:
	var count := 0
	for event in events:
		if event.get("type", "") == type_name:
			count += 1
	return count


func _count_shortages(economy_results: Array) -> int:
	var count := 0
	for result in economy_results:
		if result.get("food_shortage", false):
			count += 1
		if result.get("prod_shortage", false):
			count += 1
	return count


func _print_run_result(idx: int, r: Dictionary) -> void:
	print("--- Run %d ---" % (idx + 1))
	print("  Years: %d | Time: %dms (%.1fs) | Peak 10yr: %dms" % [
		r["years_completed"], r["total_time_ms"],
		r["total_time_ms"] / 1000.0, r["time_per_10yr_ms"]
	])
	print("  Civs alive: %d | Total pop: %s" % [
		r["final_civs_alive"], _fmt_pop(r["final_total_pop"])
	])
	print("  Collapses: %d | Golden ages: %d | Wars: %d | Battles: %d" % [
		r["collapses"], r["golden_ages"], r["wars"], r["battles"]
	])
	print("  Expansions: %d | Techs: %d | Heroes: +%d/-%d" % [
		r["expansions"], r["techs"], r["heroes_spawned"], r["heroes_died"]
	])
	print("  Shortages: %d | Peace: %d | Infra upgrades: %d" % [
		r["shortages"], r["peace_treaties"], r["infrastructure_upgrades"]
	])

	for civ_name in r["final_regions_owned"]:
		var regions: int = r["final_regions_owned"][civ_name]
		var techs: Array = r["final_techs"].get(civ_name, [])
		print("  %s: %d regions, %d techs %s" % [
			civ_name, regions, techs.size(), techs
		])

	if not r["collapse_years"].is_empty():
		var parts: Array[String] = []
		for civ_name in r["collapse_years"]:
			parts.append("%s:Y%d" % [civ_name, r["collapse_years"][civ_name]])
		print("  Collapse years: %s" % ", ".join(parts))

	if r["error"] != "":
		print("  ERROR: %s" % r["error"])
	print("")


func _print_aggregate() -> void:
	print("=" .repeat(60))
	print("AGGREGATE RESULTS (%d runs x %d years)" % [RUNS, YEARS])
	print("=" .repeat(60))

	var total_collapses := 0
	var total_golden_ages := 0
	var total_wars := 0
	var total_battles := 0
	var total_techs := 0
	var total_expansions := 0
	var total_time := 0.0
	var max_10yr := 0.0
	var all_completed := true
	var runs_with_collapse := 0
	var runs_with_golden_age := 0
	var runs_with_multi_civ := 0
	var total_final_alive := 0
	var runs_with_wars := 0
	var total_peace_treaties := 0

	for r in run_results:
		total_collapses += r["collapses"]
		total_golden_ages += r["golden_ages"]
		total_wars += r["wars"]
		total_battles += r["battles"]
		total_techs += r["techs"]
		total_expansions += r["expansions"]
		total_time += r["total_time_ms"]
		if r["time_per_10yr_ms"] > max_10yr:
			max_10yr = r["time_per_10yr_ms"]
		if r["years_completed"] < YEARS:
			all_completed = false
		if r["collapses"] > 0:
			runs_with_collapse += 1
		if r["golden_ages"] > 0:
			runs_with_golden_age += 1
		if r["final_civs_alive"] >= 2:
			runs_with_multi_civ += 1
		total_final_alive += r["final_civs_alive"]
		if r["wars"] > 0:
			runs_with_wars += 1
		total_peace_treaties += r["peace_treaties"]

	var avg_time := total_time / RUNS
	var avg_alive := float(total_final_alive) / RUNS

	print("")
	print("Performance:")
	print("  Avg time per 500yr run: %.0fms (%.1fs)" % [avg_time, avg_time / 1000.0])
	print("  Peak 10-year window: %.0fms" % max_10yr)
	print("  All runs completed: %s" % ("YES" if all_completed else "NO"))
	print("")
	print("Events (totals across %d runs):" % RUNS)
	print("  Collapses: %d (in %d/%d runs)" % [total_collapses, runs_with_collapse, RUNS])
	print("  Golden Ages: %d (in %d/%d runs)" % [total_golden_ages, runs_with_golden_age, RUNS])
	print("  Wars: %d | Battles: %d" % [total_wars, total_battles])
	print("  Expansions: %d | Techs: %d" % [total_expansions, total_techs])
	print("")

	print("ACCEPTANCE CRITERIA (Stage 1):")
	print("  [%s] 500-year simulation without crash" % ("PASS" if all_completed else "FAIL"))
	print("  [%s] 10-year fast-forward < 2000ms (peak: %.0fms)" % [
		"PASS" if max_10yr < 2000 else "FAIL", max_10yr
	])
	print("  [%s] At least 1 collapse in 10 runs (%d found)" % [
		"PASS" if runs_with_collapse >= 1 else "FAIL", runs_with_collapse
	])
	print("  [%s] At least 1 golden age in 10 runs (%d found)" % [
		"PASS" if runs_with_golden_age >= 1 else "FAIL", runs_with_golden_age
	])
	print("")
	print("ACCEPTANCE CRITERIA (Stage 2 - Equilibrium):")
	print("  [%s] Multiple civs survive to Y500 in >50%% of runs (%d/%d)" % [
		"PASS" if runs_with_multi_civ > RUNS / 2 else "FAIL",
		runs_with_multi_civ, RUNS
	])
	print("  [%s] Average civs alive at Y500 >= 1.5 (avg: %.1f)" % [
		"PASS" if avg_alive >= 1.5 else "FAIL", avg_alive
	])
	print("  [%s] Wars occur in most runs (%d/%d)" % [
		"PASS" if runs_with_wars > RUNS / 2 else "FAIL",
		runs_with_wars, RUNS
	])
	print("  [%s] Peace treaties occur (total: %d)" % [
		"PASS" if total_peace_treaties > 0 else "FAIL", total_peace_treaties
	])
	print("")


func _export_csv() -> void:
	var file := FileAccess.open(CSV_PATH, FileAccess.WRITE)
	if not file:
		print("ERROR: Cannot write CSV to %s" % CSV_PATH)
		return

	# Header
	file.store_csv_line(PackedStringArray([
		"run", "seed", "time_ms", "peak_10yr_ms", "years",
		"civs_alive", "total_pop", "collapses", "golden_ages",
		"wars", "battles", "peace_treaties", "expansions", "techs",
		"heroes_spawned", "heroes_died", "shortages", "infra_upgrades",
	]))

	# Rows
	for i in run_results.size():
		var r: Dictionary = run_results[i]
		file.store_csv_line(PackedStringArray([
			str(i + 1),
			str(i * 31337 + 42),
			str(r["total_time_ms"]),
			str(r["time_per_10yr_ms"]),
			str(r["years_completed"]),
			str(r["final_civs_alive"]),
			str(r["final_total_pop"]),
			str(r["collapses"]),
			str(r["golden_ages"]),
			str(r["wars"]),
			str(r["battles"]),
			str(r["peace_treaties"]),
			str(r["expansions"]),
			str(r["techs"]),
			str(r["heroes_spawned"]),
			str(r["heroes_died"]),
			str(r["shortages"]),
			str(r["infrastructure_upgrades"]),
		]))

	file.close()
	var abs_path := ProjectSettings.globalize_path(CSV_PATH)
	print("CSV exported to: %s" % abs_path)


func _fmt_pop(n: int) -> String:
	if n >= 1000000:
		return "%.1fM" % (float(n) / 1000000.0)
	elif n >= 1000:
		return "%.1fK" % (float(n) / 1000.0)
	return str(n)
