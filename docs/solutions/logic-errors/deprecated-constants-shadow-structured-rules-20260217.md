---
title: "Deprecated Flat Constants Shadow Structured Rules Dict"
category: logic-errors
tags: [gdscript, constants, refactoring, data-modeling, dead-code]
module: Constants
symptom: "Building cost changes in BUILDING_RULES have no effect because tests validate against deprecated flat constants"
root_cause: "Parallel data sources - flat constants and structured dict - create divergence risk"
severity: medium
date_solved: 2026-02-17
files_changed:
  - core/constants.gd
  - tests/test_town_simulation.gd
---

## Problem

After introducing `BUILDING_RULES` as the single source of truth for building data (cost, upkeep, outputs), 10 legacy flat constants (`BUILDING_GRANARY_FOOD`, `BUILDING_BARRACKS_DEFENSE`, etc.) remained in `constants.gd`. Tests validated that BUILDING_RULES matched these flat constants, creating a circular dependency that prevented cost differentiation.

When building costs were changed (Granary: 10->8, Walls: 10->14, etc.), the test `test_building_rules_outputs_match_legacy` would fail because it compared against the now-stale flat constants.

## Symptoms

- Changing `build_cost` in BUILDING_RULES causes test failure
- Two sources of truth for the same data
- New code might reference either the flat constant or BUILDING_RULES
- Grep for "BUILDING_GRANARY" returns both the constant and the BUILDING_RULES entry

## Root Cause

During the Town v1 sprint, `BUILDING_RULES` was introduced as a structured replacement for flat constants. However, the flat constants were kept "for backward compatibility" and a test was added to ensure they stayed in sync. This created an anti-pattern where:

1. The authoritative data source (BUILDING_RULES) couldn't be modified independently
2. The deprecated constants appeared actively used (referenced by the sync test)
3. Cost differentiation was blocked until the flat constants were removed

## Solution

### 1. Remove all deprecated flat constants

```gdscript
# REMOVED from core/constants.gd:
# const BUILDING_GRANARY_FOOD := 2
# const BUILDING_BARRACKS_DEFENSE := 0.15
# const BUILDING_BARRACKS_MILITARY := 3
# const BUILDING_MARKET_TRADE := 2
# const BUILDING_MARKET_STABILITY := 1.0
# const BUILDING_WORKSHOP_PRODUCTION := 2
# const BUILDING_WALLS_DEFENSE := 0.2
# const BUILDING_LIBRARY_TECH := 2.0
# const BUILDING_MONUMENT_STABILITY := 3.0
# const BUILDING_MONUMENT_CULTURE := 1
```

### 2. Update all test references to use BUILDING_RULES

```gdscript
# BEFORE (references deprecated constant):
assert_eq(outputs["total_food"], int(Constants.BUILDING_GRANARY_FOOD))

# AFTER (references authoritative source):
assert_eq(outputs["total_food"], int(Constants.BUILDING_RULES[0]["outputs"]["food"]))
```

### 3. Replace sync test with differentiation test

```gdscript
# REMOVED: test_building_rules_outputs_match_legacy (circular validation)
# ADDED: test_building_costs_differentiated (verifies costs aren't all the same)
func test_building_costs_differentiated() -> void:
    var costs: Array = []
    for key in Constants.BUILDING_RULES:
        costs.append(Constants.BUILDING_RULES[key]["build_cost"])
    var unique_costs := {}
    for c in costs:
        unique_costs[c] = true
    assert_true(unique_costs.size() >= 3,
        "Building costs should have at least 3 distinct values, got %d" % unique_costs.size())
```

### 4. Dead code audit — what to keep for save compatibility

Fields that appear unused in simulation but are serialized in save files should be KEPT to avoid breaking backward save compatibility:
- `RegionData.resource_stock` — legacy per-region dict, only in save_manager
- `TownData.infrastructure_level` — never read in simulation, but serialized
- `RegionData.urbanization_level` — actually IS used (DevelopmentTierSimulation, WarResolver)

## Prevention

- **Single source of truth**: When introducing a structured replacement for flat constants, remove the flat constants in the SAME commit
- **No sync tests**: Never write tests that validate one data source matches another. Test behavior, not data duplication
- **Save compatibility audit**: Before removing any `@export` field, grep for it in `save_manager.gd`, `to_dict()`, and `from_dict()`. If found, keep the field or add migration code
- **Dead code verification**: Before removing a field assumed to be "inert", grep ALL .gd files. `urbanization_level` appeared inert in the plan but was actively written by DevelopmentTierSimulation

## Related

- Town v1 sprint: Introduced BUILDING_RULES as structured replacement
- `core/constants.gd` BUILDING_RULES dict (keys 0-7)
