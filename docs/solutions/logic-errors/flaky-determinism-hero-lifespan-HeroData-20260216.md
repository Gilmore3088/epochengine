---
module: Simulation Engine
date: 2026-02-16
problem_type: logic_error
component: testing_framework
symptoms:
  - "Determinism tests pass intermittently (3/5 runs pass, 2/5 fail)"
  - "First divergence is always hero_ids differing between two same-seed runs"
  - "RNG state matches at every pipeline step yet state diverges"
  - "Divergence year varies randomly between test executions (Y35-Y45)"
root_cause: logic_error
resolution_type: code_fix
severity: critical
tags: [determinism, rng, hero, flaky-test, godot-rng, simulation]
---

# Troubleshooting: Flaky Determinism Tests Due to Unseeded RNG in HeroData._init()

## Problem
Two identical-seed simulation runs would intermittently produce different game states, with hero_ids being the first field to diverge. The bug was caused by `HeroData._init()` using Godot's global unseeded `randi_range()` instead of the seeded `GameState.sim_rng.randi_range()`.

## Environment
- Module: Simulation Engine / HeroData
- Engine: Godot 4.6, GDScript
- Affected Component: `resources/hero_data.gd` line 25
- Date: 2026-02-16

## Symptoms
- `test_same_seed_50yr_deterministic` and `test_same_seed_100yr_deterministic` fail intermittently
- Deep snapshot comparison shows hero_ids differ with NO prior-year state differences
- Per-step RNG state logging shows RNG matches at EVERY pipeline step including hero step
- Single-year determinism test always passes (bug only manifests over many years)

## What Didn't Work

**Attempted Solution 1:** Disabled town system (auto-spawn + AI town founding)
- **Why it failed:** Divergence still occurred. Towns were not the source of non-determinism.

**Attempted Solution 2:** Added exact float comparison (no epsilon)
- **Why it failed:** No hidden float diffs found. The divergence was integer hero_ids.

**Attempted Solution 3:** Per-step RNG state logging between every SimEngine pipeline step
- **Why it failed:** RNG matched at every checkpoint including before/after hero step. This was the critical clue: if RNG matches but hero_ids differ, the non-determinism must come from OUTSIDE the seeded RNG.

**Attempted Solution 4:** Checked TownData.buildings shared mutable default array
- **Why it failed:** Not the cause. Buildings array was properly isolated.

## Solution

**Code change:**
```gdscript
# Before (broken) - hero_data.gd line 25:
lifespan = randi_range(Constants.HERO_LIFESPAN_MIN, Constants.HERO_LIFESPAN_MAX)

# After (fixed):
lifespan = GameState.sim_rng.randi_range(Constants.HERO_LIFESPAN_MIN, Constants.HERO_LIFESPAN_MAX)
```

## Why This Works

1. **ROOT CAUSE:** `randi_range()` (bare, no object) calls Godot's global RandomNumberGenerator which is NOT seeded by `GameState.set_sim_seed()`. Every call produces unpredictable values.

2. **Why hero_ids diverge:** Heroes are spawned with random lifespans. When lifespan differs between runs, heroes die at different years, causing `civ.hero_ids` to diverge. This cascades: different heroes -> different military/stability/production bonuses -> different AI decisions -> complete state divergence.

3. **Why RNG checkpoints matched:** The seeded `GameState.sim_rng` was perfectly deterministic. The non-determinism came from the global RNG which is invisible to checkpoint logging.

4. **Why it was flaky:** The global RNG produces different values each process invocation. Sometimes the lifespans happened to match (test passes), sometimes they didn't (test fails).

## Key Debugging Insight Chain

```
hero_ids differ with no prior state diffs
  -> hero spawn or death timing differs
    -> per-step RNG matches including hero step
      -> hero spawn IS identical, so DEATH timing differs
        -> death depends on `age < lifespan`
          -> lifespan set in HeroData._init()
            -> _init() uses bare randi_range() = GLOBAL RNG!
```

## Prevention

- **NEVER use bare `randi_range()`, `randf()`, `randi()` in simulation code.** Always use `GameState.sim_rng.randi_range()` etc.
- **Grep audit:** Run `grep -rn "randi_range\|randf\|randi()" core/ resources/ --include="*.gd"` and verify every hit uses `sim_rng.` prefix or is in non-simulation code (UI, decorations).
- **Test determinism over 50+ years:** Single-year tests won't catch this class of bug because hero spawning is rare.
- **When RNG checkpoints match but state diverges:** Look for RNG calls OUTSIDE the seeded RNG object (global calls, _init() methods, sort comparators).

## Related Issues

No related issues documented yet.
