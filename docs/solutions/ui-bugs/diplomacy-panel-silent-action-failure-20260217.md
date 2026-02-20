---
title: "Diplomacy Panel Silent Action Failure"
category: ui-bugs
tags: [godot, diplomacy, signal, action-queue, key-mismatch]
module: DiplomacyPanel
symptom: "Clicking Declare War, Seek Peace, or Seek Alliance buttons does nothing"
root_cause: "Key name mismatch between signal emitter (target_id) and consumer (target_civ_id)"
severity: critical
date_solved: 2026-02-17
files_changed:
  - scripts/ui/diplomacy_panel.gd
---

## Problem

Player opens the Diplomacy Panel (D key), clicks "Declare War", "Seek Peace", or "Seek Alliance" toward a target civilization, and nothing happens. No error message, no visual feedback, no event generated — the action silently fails.

## Symptoms

- Diplomacy Panel opens and displays target civilizations correctly
- Clicking any of the three action buttons produces no visible result
- No warning/error logs in the debug console
- Right-click context menu actions (declare war, seek peace, seek alliance) from Region Panel work correctly
- The diplomacy action literally never registers with the simulation

## Root Cause

**Key name mismatch between the action dictionary writer and reader.**

In `scripts/ui/diplomacy_panel.gd`, the signal handlers used the dictionary key `"target_id"`:

```gdscript
func _on_declare_war(target_civ_id: int) -> void:
    var action := {"type": "declare_war", "target_id": target_civ_id}  # WRONG KEY
    PlayerActions.queue_action(action)
```

But in `core/simulation/player_actions.gd`, the action executor reads the key `"target_civ_id"`:

```gdscript
static func _execute_declare_war(civ, action):
    var target_id: int = action.get("target_civ_id", -1)  # Gets -1, fails silently
```

### Why This Silently Failed

The `.get("target_civ_id", -1)` fallback returns `-1` when the key doesn't exist. Then:

```gdscript
var target_civ = GameState.get_civilization(target_id)  # get_civilization(-1) = null
if not target_civ:
    return []  # Returns empty array — no event generated
```

A null lookup silently returns an empty event array with no error. The action queue processes it and moves on. No feedback, no crash, no log entry.

### Why This Wasn't Caught

The bug only affected diplomacy panel actions. Identical actions worked perfectly from the **Region Panel** right-click context menu because `region_panel.gd` had the **correct key name** (`"target_civ_id"`):

```gdscript
# scripts/ui/region_panel.gd - THIS WAS CORRECT
func _on_declare_war_context(target_civ_id: int) -> void:
    var action := {"type": "declare_war", "target_civ_id": target_civ_id}  # CORRECT
    PlayerActions.queue_action(action)
```

This inconsistency meant:
- Declare war from context menu → works
- Declare war from diplomacy panel → fails silently
- Tests only verified the panel opened/closed, not that actions executed
- Two different code paths for the same action type, one correct and one wrong

Same bug affected all three actions: `declare_war`, `seek_peace`, and `seek_alliance`.

## Solution

Changed the dictionary key from `"target_id"` to `"target_civ_id"` in all three diplomacy panel action handlers to match what `player_actions.gd` expects:

```gdscript
# scripts/ui/diplomacy_panel.gd

func _on_declare_war(target_civ_id: int) -> void:
    var action := {"type": "declare_war", "target_civ_id": target_civ_id}  # FIXED
    PlayerActions.queue_action(action)
    EventBus.player_action_queued.emit("declare_war", action)

func _on_seek_peace(target_civ_id: int) -> void:
    var action := {"type": "seek_peace", "target_civ_id": target_civ_id}  # FIXED
    PlayerActions.queue_action(action)
    EventBus.player_action_queued.emit("seek_peace", action)

func _on_seek_alliance(target_civ_id: int) -> void:
    var action := {"type": "seek_alliance", "target_civ_id": target_civ_id}  # FIXED
    PlayerActions.queue_action(action)
    EventBus.player_action_queued.emit("seek_alliance", action)
```

Now the key name in the dictionary matches the expected parameter in `player_actions.gd`. The action handler receives the correct target ID, successfully looks up the civilization, and generates the appropriate event.

## Prevention

### 1. Action Dictionary Contract Pattern

When adding new actions, establish a clear "contract" between emitter and consumer:

```gdscript
# At the top of player_actions.gd, document expected keys
static func _execute_declare_war(civ, action):
    # Expected action dict: {"type": "declare_war", "target_civ_id": int}
    var target_id: int = action.get("target_civ_id", -1)
```

### 2. Consistent Key Naming

All similar actions must use the same key names:
- Use `target_civ_id` for any action involving a target civilization
- Use `region_id` for region-specific actions
- Use `unit_id` for unit-specific actions

### 3. Runtime Validation

Add a validation step to catch missing keys:

```gdscript
static func _execute_declare_war(civ, action):
    var target_id: int = action.get("target_civ_id", -1)
    if target_id == -1:
        push_error("declare_war action missing 'target_civ_id' key: %s" % action)
        return []
```

### 4. Test Coverage

Add tests that verify actions actually execute, not just that they queue:

```gdscript
func test_declare_war_from_diplomacy_panel():
    # Simulate clicking declare war button
    var events = PlayerActions._execute_declare_war(player_civ, {
        "type": "declare_war",
        "target_civ_id": enemy_civ.id
    })
    assert_not_empty(events, "declare_war should emit events")
```

## Related

- Action Queue Pattern: `core/simulation/player_actions.gd`
- Region Panel Implementation: `scripts/ui/region_panel.gd` (correct reference)
- Diplomacy Panel UI: `scripts/ui/diplomacy_panel.gd`
- Event Bus: `core/event_bus.gd`
