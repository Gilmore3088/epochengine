# AI Behavior Model (Emergent Bias-Based)

## Design Principle

AI decisions are driven by weighted probabilities rather than deterministic triggers. This ensures emergent, unpredictable behavior that creates compelling narratives.

## Expansion Logic

```
If:
  food_surplus > threshold
  AND stability > 50
Then:
  Expand to adjacent weakest region

Priority: Regions with highest food_yield first
Tiebreaker: Lowest defense_modifier
```

AI will not expand if stability < 50 (internal problems take priority).

## War Declaration Logic

```
If:
  military > neighbor_military * 1.3
  AND stability > 60
Then:
  war_probability = base_chance * strength_ratio * aggressive_bias * random_factor

If war_probability > threshold:
  Declare war on neighbor
```

AI considers:
- Relative military strength (must be 30%+ stronger)
- Current stability (must be > 60)
- Number of existing wars (penalty for multi-front wars)
- Aggressive bias per civilization (some civs are more warlike)

## Alliance Logic

```
If:
  neighbor_stability is high
  AND threat_from_third_party exists
Then:
  alliance_probability increases

If:
  neighbor_is_at_war
  AND common_enemy exists
Then:
  alliance_probability significantly increases
```

Alliances are defensive -- allied civilizations will not attack each other and provide mutual defense modifiers.

## AI Decision Priority (Per Year)

1. **Survive** -- If stability < 30, focus on internal recovery (no wars, no expansion)
2. **Stabilize** -- If stability 30-50, cautious behavior (defend only)
3. **Grow** -- If stability > 50, expand to adjacent weak regions
4. **Compete** -- If stability > 60 and military advantage, consider war
5. **Dominate** -- If stability > 80 and golden age, aggressive expansion

## Per-Civilization Bias

Each civilization has personality weights:

| Bias | River Basin | Mountain | Coastal |
|------|------------|----------|---------|
| Expansion | High | Low | Medium |
| Aggression | Medium | Medium | High |
| Diplomacy | Medium | High | Low |
| Economy | High | Low | High |
