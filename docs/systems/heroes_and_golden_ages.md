# Heroes & Golden Ages

## Hero Types

| Type | Modifier | Effect |
|------|----------|--------|
| General | +10% military effectiveness | Boosts battle_strength for owning civilization |
| Reformer | +5 stability annually | Directly added to stability calculation |
| Visionary | +10% production | Boosts production_yield across all owned regions |

## Hero Lifecycle

- **Spawn:** Random chance each year based on civilization prosperity (stability > 60)
- **Age:** Heroes age 1 year per turn
- **Lifespan:** Randomized between 40-80 years
- **Death:** When age >= lifespan, hero dies and modifier is removed
- **Limit:** Maximum 3 active heroes per civilization

## Hero Spawn Probability

```
spawn_chance =
  base_chance (0.05)
  * stability_factor (stability / 100)
  * population_factor (log(population) / 10)
```

A civilization with high stability and large population is more likely to produce heroes.

## Golden Age

### Trigger Conditions

All three must be true simultaneously:
- Stability > 80
- Economy has surplus (food_stockpile > 0 AND production_stockpile > 0)
- No active wars

### Effects

- **Duration:** 20 years (unless destabilized)
- **Bonuses:** +50% food production, +50% production, +10 stability floor
- **Early End:** If stability drops below 60 OR war is declared, golden age ends immediately

### Cooldown

After a golden age ends, a civilization cannot enter another for 30 years.

## Future Hero Types (Phase 2+)

- **Unifier** -- Diplomacy bonuses, alliance stability
- **Space Architect** -- Space expansion bonuses (Phase 4)
