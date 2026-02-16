# War & Logistics Specification

## Strategic Layer

- **Region-based fronts** -- Wars are fought over regions, not individual tiles
- **Supply traced from capital** -- Strength degrades with distance from capital
- **Attrition from terrain + climate** -- Mountains, deserts, and tundra cause losses
- **Morale affected by stability** -- Low stability = low morale = weaker armies

## Auto-Resolve Formula

```
battle_strength =
  (manpower * equipment * morale * doctrine)
  + terrain_modifier
  - supply_penalty
```

### Detailed Breakdown

- `manpower` -- Total soldiers committed
- `equipment` -- Quality multiplier (0.5 - 1.5)
- `morale` -- Based on stability and recent battle history (0.5 - 1.2)
- `doctrine` -- Civilization's military philosophy modifier (0.8 - 1.2)
- `terrain_modifier` -- Defender gets bonus from terrain type
- `supply_penalty` -- Attacker penalized for distance from capital

### Resolution

1. Both sides calculate battle_strength
2. Higher strength wins the region
3. Winner takes ownership
4. Loser loses 5-15 stability points
5. Both sides lose proportional military strength

## Supply System (Phase 1 -- Simplified)

- Supply = adjacency count to capital through owned regions
- If a region is not connected to capital through owned territory, supply_modifier = 0.5
- Connected regions get full supply (1.0)

## Supply System (Phase 2 -- Full)

- Supply traced through specific routes
- Terrain affects supply throughput (mountains = slow, rivers = fast)
- Enemy interdiction can cut supply lines
- Starvation attrition for cut-off armies

## Optional Tactical Engagement (Future Phase)

- Player can choose: Engage / Observe / Simulate
- Same core stats as strategic layer
- Adds positional decisions within a region
