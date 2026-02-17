---
title: "Pause Menu Freezes When Game Tree Is Paused"
category: ui-bugs
tags: [godot, process_mode, pause, ui, input]
module: PauseMenu
symptom: "Pause menu UI is unresponsive after calling get_tree().paused = true"
root_cause: "All nodes default to PROCESS_MODE_INHERIT which stops processing when tree is paused"
severity: high
date_solved: 2026-02-17
files_changed:
  - scripts/ui/pause_menu.gd
  - scripts/ui/hud.gd
---

## Problem

When implementing a pause menu that pauses the game tree (`get_tree().paused = true`), the pause menu itself becomes completely unresponsive. Buttons cannot be clicked, `_unhandled_input` stops firing, and the player is softlocked.

## Symptoms

- Pressing Esc opens pause menu and pauses game
- Pause menu buttons do not respond to clicks
- Keyboard input (Esc to close) does not work
- Game is permanently frozen with no way to unpause

## Root Cause

In Godot 4.6, all nodes default to `process_mode = PROCESS_MODE_INHERIT`. When the scene tree is paused, EVERY node inherits the paused state and stops processing entirely — including the pause menu that triggered the pause.

This is the first usage of `get_tree().paused` in the entire EpochEngine project (zero prior `process_mode` references existed), making it a novel pattern with no existing example to follow.

## Solution

Set `process_mode = Node.PROCESS_MODE_WHEN_PAUSED` on the pause menu node in `_ready()`:

```gdscript
# scripts/ui/pause_menu.gd
func _ready() -> void:
    process_mode = Node.PROCESS_MODE_WHEN_PAUSED
    visible = false
    # ... rest of setup
```

This tells Godot: "This node should ONLY process when the tree IS paused." The pause menu is invisible during normal gameplay (no processing needed) and active only when paused.

### Key Details

1. **WHEN_PAUSED vs ALWAYS**: Use `PROCESS_MODE_WHEN_PAUSED` for pause-exclusive UI (menus, overlays). Use `PROCESS_MODE_ALWAYS` for nodes that must work in both states (like audio managers or analytics).

2. **Input handling**: The pause menu handles its own `_unhandled_input` for Esc-to-close. This works because `WHEN_PAUSED` enables full input processing during pause.

3. **Child nodes inherit**: All children of the pause menu (buttons, labels, containers) automatically inherit `WHEN_PAUSED` from their parent. No need to set it on each child.

4. **Companion gotcha — button focus_mode**: All buttons in the pause menu must set `focus_mode = Control.FOCUS_NONE` to prevent the Space key from triggering a focused button instead of reaching `_unhandled_input` for the advance-turn handler.

```gdscript
var resume_btn := Button.new()
resume_btn.text = "Resume"
resume_btn.focus_mode = Control.FOCUS_NONE  # Prevent Space key conflict
resume_btn.pressed.connect(_on_resume)
```

## Prevention

- Any time `get_tree().paused = true` is used, the triggering UI MUST set `process_mode`
- Add a comment in the pause code referencing this pattern:
  ```gdscript
  # IMPORTANT: process_mode = WHEN_PAUSED is set in _ready()
  # Without it, this menu freezes along with everything else
  get_tree().paused = true
  ```
- Search for `get_tree().paused` in codebase to audit all pause points

## Related

- [Godot docs: Process Mode](https://docs.godotengine.org/en/stable/tutorials/scripting/pausing_game_tree.html)
- Sprint V1 focus_mode bug: Space key eaten by focused buttons before `_unhandled_input`
