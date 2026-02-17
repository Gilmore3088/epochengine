# War & Logistics (Aligned)

## Strategic Layer
- **Region-based fronts** — wars are fought over regions
- **Supply routed from capital** — Dijkstra supply graph, terrain throughput affects cost
- **Interdiction** — adjacent enemy regions at war increase supply cost
- **Attrition** — cut‑off regions lose population annually
- **Morale from stability** — stability maps to morale modifier

## Auto-Resolve Formula (Conceptual)
```
strength = military * morale * doctrine * terrain * supply * variance
```
- **Terrain** favors defenders (tier + terrain bonuses)
- **Supply** uses region supply value or best adjacent supply
- **Variance** introduces bounded randomness

## Battle Resolution
1) Attacker/defender strengths computed
2) Winner gains region
3) Loser stability reduced (5–15)
4) Both sides lose military via attrition ratio

## Supply System Details
- Capital gets full supply
- Dijkstra cost uses terrain throughput + infra bonuses
- Supply value in [0,1]
- Supply affects town output, combat modifiers, and stability penalties

## Future (Optional)
- Tactical engagement is optional and not in current scope
