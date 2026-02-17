# Multi-Layer Gameplay Design

## Overview

EpochEngine operates at two distinct zoom levels, each with its own gameplay loop and visual style. The world map plays like Risk/Stellaris/Civ (grand strategy). Clicking into a region plays like Civ/Age of Empires/Pharaoh (city-building and resource management).

## Layer 1: World Map (Zoomed Out)

**Inspiration:** Risk, Stellaris, Civilization (strategic map)

### What the player sees
- Political map with Voronoi regions, colored by civilization
- Borders, armies, supply lines, alliance overlays
- 116 regions forming an organic continent

### What the player does
- Declare war, seek peace, propose alliances
- Expand into neutral territory
- Manage national-level strategy: which fronts to reinforce, where to invest

### Current state
- Fully implemented in Phase 1 + Phase 2
- Region selection, diplomacy buttons, fast-forward, event log
- AI runs 2 competing civilizations autonomously

---

## Layer 2: Region View (Zoomed In)

**Inspiration:** Civilization (city screen), Age of Empires (economy), Pharaoh (town planning)

### What the player sees
- Interior of a single region showing terrain features
- Multiple towns/cities within the region
- Roads connecting towns to each other
- Buildings within each town (granary, barracks, market, etc.)
- Local resource deposits and extraction sites

### What the player does
- Found new towns within a region (multiple cities per region)
- Construct buildings that affect local production, defense, population
- Build roads/infrastructure connecting towns
- Manage local resource extraction and trade
- Connect regional infrastructure to the national network

### Town Model

Each region can contain 1-N towns. Towns have:

```
TownData:
  id: int
  town_name: String
  region_id: int               # parent region
  population: int
  buildings: Array[BuildingData]
  local_infrastructure: int    # roads, walls, etc.
  position: Vector2            # position within the region sub-map
```

Towns produce resources based on their buildings and surrounding terrain. A region's total output is the sum of its towns' contributions.

### Building System

Buildings are constructed in towns and provide bonuses:

| Building     | Effect                              | Cost     |
|-------------|-------------------------------------|----------|
| Granary     | +food storage, reduces famine risk  | Low      |
| Barracks    | +military recruitment rate          | Medium   |
| Market      | +production, enables trade routes   | Medium   |
| Walls       | +defense modifier for the town      | High     |
| Workshop    | +production yield                   | Medium   |
| Library     | +tech emergence pressure            | High     |
| Monument    | +stability, +golden age chance      | High     |

### Infrastructure Layers

Infrastructure operates at three connected levels:

```
National Infrastructure
  |
  +-- Region Infrastructure (roads between towns, regional upgrades)
        |
        +-- Town Infrastructure (buildings, local improvements)
```

1. **Town-level**: Buildings within a single town. Local production, defense, housing.
2. **Region-level**: Roads connecting towns. Determines how efficiently towns share resources. Affects region defense (connected walls are stronger than isolated ones).
3. **National-level**: Trade routes and supply lines between regions. Already partially modeled by the adjacency + supply system.

**Connectivity matters**: A town connected by roads to the regional capital contributes its full output. An isolated town contributes less. This mirrors the national-level supply system (regions connected to the capital get full supply).

---

## How This Connects to Current Systems

### RegionData Extension

Current `RegionData` has flat yields (`food_yield`, `production_yield`). With towns:

- `food_yield` becomes the sum of all towns' food production in that region
- `production_yield` becomes the sum of all towns' production
- `infrastructure_level` becomes a composite of town infrastructure + inter-town roads
- `defense_modifier` factors in walls, terrain, and town positions

### Economy Pipeline

Current: `EconomySimulation.calculate_food_production()` sums `region.food_yield` per region.

Future: Each region's yield is computed from its towns:
```
region.effective_food = sum(town.food_output for town in region.towns) * connectivity_factor
```

### Population

Current: Each region has a single `population` value.

Future: Population is distributed across towns. Migration between towns within a region happens automatically based on jobs/food/housing.

### War Resolution

Current: Battles happen at the region level.

Future: Attacking a region means attacking its towns. Well-connected, fortified towns are harder to take. Destroying infrastructure (roads) weakens the region's defense.

---

## Phasing

This feature set spans multiple phases:

### Phase 2 (Current) - Foundation Compatibility
- Ensure `RegionData` is extensible (already has `size_factor`, `resource_stock`)
- Infrastructure levels should decompose cleanly into town-level infra later
- Economy pipeline sums from regions; later it sums from towns within regions
- **No town implementation yet** - just ensure nothing blocks it

### Phase 3 - Town Layer (Future)
- `TownData` resource class
- Region sub-map rendering (click region to see interior)
- Town founding, building construction
- Local infrastructure (roads between towns)
- Town-level economy feeding into region totals

### Phase 4 - Societal Connectivity (Future)
- National trade routes (region-to-region, building on supply system)
- Infrastructure network visualization on world map
- Economic interdependence between regions
- Cultural/ideological spread along trade routes

---

## Design Principles

1. **Seamless zoom**: Transitioning between world map and region view should feel natural, not like loading a different game.

2. **Aggregation**: The world map should always reflect the sum of what's happening in the region views. A player who never zooms in should still see meaningful numbers.

3. **Automation at scale**: Players can't micromanage 40+ regions. Towns in AI-controlled or unvisited regions should run themselves via the same AI logic. Player towns get manual control.

4. **Geography still drives destiny**: Town placement within a region should be influenced by terrain (river towns grow faster, mountain towns are defensible, coastal towns enable trade).

5. **Infrastructure as connective tissue**: The key insight is that infrastructure isn't just "level 0-5 on a region." It's a network of connections - town to town, region to region, nation to nation. Cutting connections (in war) should have cascading effects.

---

## Open Questions for Team Review

1. **Region sub-map generation**: Procedural terrain within regions (rivers, hills, resource deposits) or hand-placed templates per terrain type?

2. **Town limit per region**: Fixed cap (e.g., 3-5 towns per region scaled by `size_factor`)? Or unlimited with diminishing returns?

3. **Building slots**: Limited slots per town (Pharaoh-style) or unlimited with escalating costs (Civ-style)?

4. **Auto-management**: How much should AI manage player towns? Toggle per-town? Per-region? Global "governor" setting?

5. **UI transition**: Smooth zoom-in animation to region view, or panel/overlay that replaces the world map?

6. **When to build this**: Should town layer come before or after supply logistics (Sprint G)? Supply logistics would inform how town connectivity works.
