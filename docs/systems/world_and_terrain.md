# World & Terrain (Aligned)

## Region Properties
Each region has:
- `terrain_type` — determines yields, defense, and supply throughput
- `population`, `owner_id`
- `food_yield`, `production_yield`, `defense_modifier`
- `resource_deposits` — finite resources by type
- `adjacency_list` — neighboring region IDs
- `infrastructure_level`
- `size_factor` — normalized region area
- `development_tier`
- `supply_value`
- `towns` — array of TownData

## Terrain Types & Effects
Terrain affects yields, defense, and supply throughput. Supported types:
- River Basin
- Plains
- Mountains
- Desert
- Jungle
- Coastline
- Tundra
- Steppe
- Volcanic Ridge

## Resources
- Finite deposits extracted over time
- Renewable yields come from terrain and infrastructure
- Resource availability is era‑gated

## Map Design
- Handcrafted continent of 116 Voronoi regions
- Regions are grouped into geographic zones (mountain, desert, river basin, coast, plains)
