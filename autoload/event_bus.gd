extends Node

## Global signal bus for decoupled communication between systems.
## All cross-system signals go through EventBus.

# --- Turn Lifecycle ---
signal turn_started(year: int)
signal turn_phase_started(phase: Enums.TurnPhase)
signal turn_phase_completed(phase: Enums.TurnPhase)
signal turn_ended(year: int)

# --- Population ---
signal population_changed(region_id: int, old_pop: int, new_pop: int)

# --- Resources ---
signal food_stockpile_changed(civ_id: int, amount: int)
signal production_stockpile_changed(civ_id: int, amount: int)

# --- Stability ---
signal stability_changed(civ_id: int, old_value: float, new_value: float)
signal civilization_collapsed(civ_id: int)

# --- Territory ---
signal region_owner_changed(region_id: int, old_owner: int, new_owner: int)

# --- War ---
signal war_declared(attacker_id: int, defender_id: int)
signal battle_resolved(region_id: int, attacker_id: int, defender_id: int, winner_id: int)
signal peace_declared(civ_a_id: int, civ_b_id: int)

# --- Heroes ---
signal hero_spawned(hero_id: int, civ_id: int, hero_type: Enums.HeroType)
signal hero_died(hero_id: int, civ_id: int)

# --- Golden Age ---
signal golden_age_started(civ_id: int)
signal golden_age_ended(civ_id: int)

# --- Tech Emergence ---
signal technology_emerged(civ_id: int, tech_name: String)

# --- AI ---
signal ai_decision_made(civ_id: int, decision_type: String, details: Dictionary)

# --- Diplomacy ---
signal alliance_formed(civ_a_id: int, civ_b_id: int)
signal alliance_broken(civ_a_id: int, civ_b_id: int)

# --- Economy ---
signal food_shortage(civ_id: int, stockpile: int)
signal production_shortage(civ_id: int, stockpile: int)
signal infrastructure_upgraded(civ_id: int, region_name: String, new_level: int)

# --- Player Actions ---
signal region_right_clicked(region_id: int, screen_position: Vector2)
signal player_action_queued(action_type: String, details: Dictionary)

# --- Development Tiers ---
signal development_tier_changed(region_id: int, civ_id: int, old_tier: String, new_tier: String)

# --- Resources ---
signal resource_deposit_depleted(region_id: int, civ_id: int, resource_name: String)
signal resource_maintenance_failure(civ_id: int, resource_name: String, missing_inputs: int)

# --- UI ---
signal region_selected(region_id: int)
signal region_deselected()
signal game_speed_changed(speed: Enums.GameSpeed)
signal overlay_changed(overlay: Enums.MapOverlay)
signal fast_forward_summary_ready(events: Array[Dictionary])
signal zoom_changed(zoom_level: float)
signal open_civ_profile(civ_id: int)
signal open_timeline()
