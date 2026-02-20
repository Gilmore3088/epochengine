---
title: "Town Founding Button Hidden When Unaffordable"
category: ui-bugs
tags: [godot, town-founding, ui-feedback, affordability, button-state]
module: RegionPanel
symptom: "Region shows 'Ready to found a town!' but no 'Found Town' button appears"
root_cause: "Button visibility logic checked full affordability but hint text checked only population"
severity: high
date_solved: 2026-02-17
files_changed:
  - scripts/ui/region_panel.gd
---

## Problem

The Region Panel shows "Ready to found a town!" message, indicating the player has enough population to found a town. However, the "Found Town" button is completely hidden, giving no way for the player to take action despite the encouraging message.

## Symptoms

- Hint text displays: "Ready to found a town!"
- No "Found Town" button appears in the panel
- Player has sufficient population (≥ `TOWN_MIN_POP_TO_FOUND`)
- Player does not have enough production stockpile to pay the town cost
- Player receives mixed signals: "Ready to do this" but "Can't actually do it"

## Root Cause

**Visibility logic checked full affordability while hint text checked only population.**

The hint text at line ~618 checked only the population requirement:

```gdscript
if region.population >= Constants.TOWN_MIN_POP_TO_FOUND:
    hint_text = "Ready to found a town!"
```

But the button visibility at line ~628 checked both population AND production:

```gdscript
found_town_btn.visible = TownSimulation.can_found_town(region, player_civ)
```

Where `TownSimulation.can_found_town()` requires:
- Sufficient population: `region.population >= TOWN_MIN_POP_TO_FOUND`
- Sufficient production: `civ.production_stockpile >= town_cost`

### The User Experience Problem

1. Player sees region with good population
2. Text encourages action: "Ready to found a town!"
3. No button appears — UI sends contradictory signals
4. Player assumes the feature is broken or the UI is unfinished
5. Player has no way to see what's actually preventing the action (missing production)
6. Player cannot plan resource gathering without visible feedback

### Why This Wasn't Caught

All UI feedback and button state decisions went through `can_found_town()` checks, but the **hint text was written before the affordability check existed**, creating an inconsistency. The hint text is positive encouragement without any cost information, while the button silently hides when unaffordable.

## Solution

Show the "Found Town" button whenever population is sufficient. Disable (not hide) the button when the player can't afford the cost, and show a tooltip explaining the actual requirement:

```gdscript
# scripts/ui/region_panel.gd
if region.population >= Constants.TOWN_MIN_POP_TO_FOUND:
    var town_cost := TownSimulation.calculate_town_cost(region)
    found_town_btn.text = "Found Town (-%d prod)" % town_cost
    found_town_btn.visible = true

    var can_afford := player_civ.production_stockpile >= town_cost
    found_town_btn.disabled = not can_afford

    if not can_afford:
        found_town_btn.tooltip_text = "Need %d production (have %d)" % [
            town_cost,
            player_civ.production_stockpile
        ]
    else:
        found_town_btn.tooltip_text = ""
else:
    hint_text = "Need %d population to found a town" % Constants.TOWN_MIN_POP_TO_FOUND
    found_town_btn.visible = false
```

### Key Improvements

1. **Button Always Visible**: Once population requirement is met, the button appears
2. **Cost Shown in Label**: Button text includes production cost: "Found Town (-120 prod)"
3. **Disabled State Instead of Hidden**: When unaffordable, button is present but disabled (grayed out)
4. **Tooltip Feedback**: Hover shows exactly what's missing: "Need 120 production (have 45)"
5. **Consistent With Existing Pattern**: Matches the `claim_btn` implementation (lines 632-640) which already uses this disabled+tooltip pattern

### Comparison With Claim Button Pattern

The claim button already implements this correctly:

```gdscript
# scripts/ui/region_panel.gd (existing, lines 632-640)
claim_btn.visible = true
claim_btn.disabled = player_civ.population < region.population
if claim_btn.disabled:
    claim_btn.tooltip_text = "Insufficient population"
```

The found town button now follows the same pattern:
- Show button when prerequisite is met
- Disable when cost cannot be paid
- Show tooltip explaining the blocker

## Prevention

### 1. Consistency Rule: Hint and Button Must Agree

Any positive hint text ("Ready to...", "You can...") must correspond to a visible button. If an action requires multiple conditions, hint text should reflect ALL conditions:

```gdscript
# GOOD: Hint matches all button visibility requirements
if region.population >= TOWN_MIN_POP and player_civ.production >= town_cost:
    hint_text = "Ready to found a town!"
    found_town_btn.visible = true

# AVOID: Hint checks subset of requirements
if region.population >= TOWN_MIN_POP:  # Missing affordability check
    hint_text = "Ready to found a town!"
found_town_btn.visible = can_afford  # Different check = mismatch
```

### 2. Disabled vs Hidden Pattern

Use this decision tree for button states:

```
If action is POSSIBLE (all prerequisites met):
    ├─ Can AFFORD? → visible, enabled
    └─ Cannot afford? → visible, disabled, tooltip shows cost

If action is IMPOSSIBLE (prerequisite not met):
    └─ hidden
```

### 3. UI Feedback Template

Every actionable button should have three states:

```gdscript
var is_prerequisite_met = region.population >= TOWN_MIN_POP
var can_afford = player_civ.production >= town_cost

if is_prerequisite_met:
    button.visible = true
    button.disabled = not can_afford
    if not can_afford:
        button.tooltip_text = "Need %d (have %d)" % [cost, have]
else:
    button.visible = false
```

### 4. Test Coverage

Add tests that verify consistency:

```gdscript
func test_found_town_button_states():
    # Prerequisite met, can afford
    assert_true(found_town_btn.visible)
    assert_false(found_town_btn.disabled)

    # Prerequisite met, cannot afford
    player_civ.production_stockpile = 1  # Less than cost
    refresh_panel()
    assert_true(found_town_btn.visible)
    assert_true(found_town_btn.disabled)
    assert_not_empty(found_town_btn.tooltip_text)

    # Prerequisite not met
    region.population = 1  # Less than minimum
    refresh_panel()
    assert_false(found_town_btn.visible)
```

## Related

- Claim Button Pattern: `scripts/ui/region_panel.gd` lines 632-640
- Town Cost Calculation: `core/simulation/town_simulation.gd`
- Region Panel UI: `scripts/ui/region_panel.gd`
- Godot Control States: visibility, disabled, tooltip_text
