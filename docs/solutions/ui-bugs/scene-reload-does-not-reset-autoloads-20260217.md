---
title: "Scene Reload Does Not Reset Autoload Singletons"
category: ui-bugs
tags: [godot, autoload, scene-management, state-reset, signal-safety]
module: VictoryPanel
symptom: "After 'Play Again' reloads scene, game state carries over from previous session"
root_cause: "reload_current_scene() and change_scene_to_file() do not reset Autoload singletons"
severity: high
date_solved: 2026-02-17
files_changed:
  - scripts/ui/victory_panel.gd
  - core/history.gd
---

## Problem

When implementing a "Play Again" button on the victory/defeat screen, using `get_tree().reload_current_scene()` reloads the scene but all Autoload singletons (GameState, EventBus, SaveManager, History) retain their state from the previous game session. The new game starts with the old year count, old civilizations, old history events, etc.

## Symptoms

- "Play Again" restarts the scene but shows "Year 347" instead of "Year 0"
- Previous game's civilizations appear in the new game
- History panel shows events from the previous session
- Victory conditions may immediately trigger again

## Root Cause

In Godot 4.6, Autoload singletons persist across scene changes and reloads. They are initialized once when the application starts and are never destroyed or reset by scene management. This is by design — Autoloads are meant to be persistent.

Additionally, calling `change_scene_to_file()` from within a signal handler (e.g., button `pressed` signal) can cause errors because the scene tree is being modified during signal propagation.

## Solution

### 1. Clear persistent state explicitly before reloading

```gdscript
# scripts/ui/victory_panel.gd
func _on_play_again() -> void:
    History.clear()  # Must clear History explicitly
    # GameState will be reset by load_game_data() in main.gd _ready()
    get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")
```

### 2. Use call_deferred for scene changes from signal handlers

```gdscript
# WRONG - can crash or cause errors:
get_tree().change_scene_to_file("res://scenes/main.tscn")

# CORRECT - defers to next frame, safe from signals:
get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")
```

### 3. Ensure main scene re-initializes state

The main scene's `_ready()` must call `GameState.load_game_data()` which resets all regions, civilizations, heroes, and counters from the .tres resource files.

### Key Details

- `History.clear()` is the only explicit reset needed because History stores events in a static Array that isn't touched by `load_game_data()`
- `EventBus` has no state to clear (just signal declarations)
- `SaveManager` has no state to clear (just utility methods)
- `GameState` is reset by `load_game_data()` which clears and reloads all dicts

## Prevention

- Any "restart" or "new game" flow must audit ALL Autoloads for persistent state
- Pattern: Create a `reset()` method on each Autoload that has mutable state
- Always use `call_deferred()` for scene changes triggered from UI callbacks
- Test the restart flow: play a game to victory, click "Play Again", verify clean state

## Related

- [Godot docs: Autoload](https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html)
- `core/history.gd` — `clear()` method resets events array and snapshots dict
