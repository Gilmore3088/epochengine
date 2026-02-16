# Simulation Math & Emergence Specification

## 1. Population Growth

```
population_next =
  population_current *
  (1 + base_growth_rate) *
  food_modifier *
  stability_modifier *
  random_variance
```

Where:
- `base_growth_rate` = 0.01 - 0.03 (varies by terrain fertility)
- `food_modifier` = 0.5 - 1.5 (based on food surplus/deficit)
- `stability_modifier` = 0.7 - 1.2 (low stability slows growth)
- `random_variance` = 0.98 - 1.02 (bounded noise)

Population cannot go below 0. Famine (food_modifier < 0.7) triggers stability penalty.

## 2. Stability Formula

```
stability =
  base_stability
  + food_surplus_factor
  - war_exhaustion
  - resource_shortage_penalty
  + hero_modifier
  + random_political_shift
```

- **Range:** 0 - 100 (clamped)
- `base_stability` = 50 (starting value for new civilizations)
- `food_surplus_factor` = surplus / population * scaling_constant
- `war_exhaustion` = 2-5 per active war front per year
- `resource_shortage_penalty` = 5-15 depending on severity
- `hero_modifier` = Reformer hero adds +5 annually
- `random_political_shift` = -3 to +3 (bounded noise)

### Collapse Threshold

If stability drops below 10 for 5 consecutive years, civilization collapses (regions become neutral).

## 3. War Strength Formula (Auto-Resolve)

```
effective_strength =
  (military * morale * equipment_quality)
  * terrain_modifier
  * supply_modifier
  * doctrine_modifier
  * random_battle_variance
```

- `terrain_modifier` = 0.7 (attacking mountains) to 1.3 (attacking plains)
- `supply_modifier` = 1.0 (adjacent to capital) to 0.5 (far from capital)
- `doctrine_modifier` = 0.8 - 1.2 (based on civilization traits)
- `random_battle_variance` = 0.85 - 1.15

### Battle Resolution

- Compare effective_strength of attacker vs defender
- Winner gains the contested region
- Loser loses 5-15 stability points
- Both sides lose military proportional to battle intensity

### Phase 1 Simplifications

- Supply simplified to adjacency count from capital
- Equipment quality is flat per civilization
- Doctrine modifier is flat per civilization

## 4. Emergent Tech Threshold Example

Technologies are not selected by the player. They emerge when systemic thresholds are met.

### Core Hidden Metrics

- **Knowledge Complexity** (0-100)
- **Energy Capacity** (0-100)
- **Social Coordination** (0-100)
- **Economic Surplus** (0-100)
- **Military Pressure** (0-100)

### Example Emergence

```
If:
  Knowledge > 70
  AND Energy > 60
  AND Economic Surplus > threshold
  AND random_roll < weighted_probability
Then:
  Fusion Research Emerges
```

```
If:
  Military Pressure > 70
  AND Production > 60 (industrial base)
Then:
  Advanced Weapons Emerge
```

Emergence probabilities increase under pressure conditions. Multiple techs can emerge in the same year.
