class_name History
extends RefCounted

## Persistent event store for the game session.
## Records all simulation events with canonical schema for UI consumption.
## Cleared on new game via History.clear().

# All recorded events across the entire game.
# Schema: {year, type, severity, civ_id, civ_name, region_id, region_name, description}
static var events: Array[Dictionary] = []

# Stability snapshots per civ per year for trend sparklines.
# {civ_id: Array[{year: int, value: float}]}
static var stability_history: Dictionary = {}

# Severity levels
const SEVERITY_MINOR := 1   # infra, dev tier, shortage
const SEVERITY_NOTABLE := 2  # tech, expansion, hero, alliance
const SEVERITY_MAJOR := 3    # war, collapse, golden age, peace

# Type -> severity mapping
const TYPE_SEVERITY: Dictionary = {
	"war_declared": SEVERITY_MAJOR,
	"peace": SEVERITY_MAJOR,
	"collapse": SEVERITY_MAJOR,
	"golden_age_start": SEVERITY_MAJOR,
	"golden_age_end": SEVERITY_MINOR,
	"battle": SEVERITY_NOTABLE,
	"tech": SEVERITY_NOTABLE,
	"expansion": SEVERITY_NOTABLE,
	"hero_spawned": SEVERITY_NOTABLE,
	"hero_died": SEVERITY_MINOR,
	"alliance_formed": SEVERITY_NOTABLE,
	"governance_change": SEVERITY_NOTABLE,
	"dev_tier_change": SEVERITY_MINOR,
	"infra_upgrade": SEVERITY_MINOR,
	"shortage": SEVERITY_MINOR,
	"deposit_depleted": SEVERITY_MINOR,
	"maintenance_failure": SEVERITY_MINOR,
	"town_founded": SEVERITY_MINOR,
	"building_constructed": SEVERITY_MINOR,
	"alliance_broken": SEVERITY_NOTABLE,
	"workforce_changed": SEVERITY_MINOR,
}


static func record_event(event: Dictionary) -> void:
	## Record a single event. Automatically assigns severity from type.
	if not event.has("severity"):
		event["severity"] = TYPE_SEVERITY.get(event.get("type", ""), SEVERITY_MINOR)
	if not event.has("region_id"):
		event["region_id"] = -1
	if not event.has("region_name"):
		event["region_name"] = ""
	events.append(event)


static func record_stability(civ_id: int, year: int, value: float) -> void:
	## Record a stability snapshot for sparkline rendering.
	if not stability_history.has(civ_id):
		stability_history[civ_id] = []
	stability_history[civ_id].append({"year": year, "value": value})


static func get_events_for_year(year: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event in events:
		if event.get("year", -1) == year:
			result.append(event)
	return result


static func get_events_by_type(type: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event in events:
		if event.get("type", "") == type:
			result.append(event)
	return result


static func get_events_by_civ(civ_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event in events:
		if event.get("civ_id", -1) == civ_id:
			result.append(event)
	return result


static func get_stability_trend(civ_id: int, last_n: int = 20) -> Array[Dictionary]:
	## Returns the last N stability snapshots for a civ.
	var snapshots: Array = stability_history.get(civ_id, [])
	var result: Array[Dictionary] = []
	if snapshots.size() <= last_n:
		result.assign(snapshots)
	else:
		result.assign(snapshots.slice(snapshots.size() - last_n))
	return result


static func get_top_events(year: int, n: int = 3) -> Array[Dictionary]:
	## Returns the top N events for a given year, sorted by severity (highest first).
	var year_events := get_events_for_year(year)
	year_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.get("severity", 0) > b.get("severity", 0)
	)
	if year_events.size() <= n:
		return year_events
	var result: Array[Dictionary] = []
	result.assign(year_events.slice(0, n))
	return result


static func clear() -> void:
	## Reset all history. Called on new game.
	events.clear()
	stability_history.clear()
