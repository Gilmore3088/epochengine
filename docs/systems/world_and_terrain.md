# World & Terrain Specification

## Region Properties

Each region has:
- `id` -- Unique identifier
- `terrain_type` -- Determines yields, defense, and special bonuses
- `population` -- Current inhabitants
- `owner_id` -- Controlling civilization (-1 = neutral)
- `food_yield` -- Base food production per year
- `production_yield` -- Base industrial output per year
- `defense_modifier` -- Multiplier for defending armies
- `resource_stock` -- Finite resources (coal, oil, rare earths)
- `adjacency_list` -- Neighboring region IDs
- `infrastructure_level` -- Improves yields over time

## Terrain Types & Effects

| Terrain | Food | Production | Defense | Special |
|---------|------|------------|---------|---------|
| River Basin | High | Medium | Low | +20% population growth |
| Plains | Medium | Medium | Low | Balanced, easy to conquer |
| Mountains | Low | Low | High | +40% defense bonus, supply difficulty |
| Desert | Very Low | Low | Medium | Solar bonuses (late game), water stress |
| Jungle | Medium | Low | Medium | Biotech bonuses (late game) |
| Coastline | Medium | High | Low | Trade potential, naval bonuses |
| Tundra | Very Low | Low | Medium | Resource deposits |

## Resource Depletion

- **Finite resources:** Coal, Oil, Rare Earths -- deplete with extraction
- **Renewable resources:** Food, Wood -- degrade with overuse but regenerate
- Overuse penalty: if extraction > regeneration_rate for 10+ years, yield drops permanently

## V0 Map Design

### Layout (100-120 handcrafted regions)

- **Northern mountain range** -- Defensive corridor, low food
- **Central river basin** -- High food, population center
- **Western desert** -- Low food, strategic minerals
- **Eastern coastline** -- Trade routes, production
- **Southern plains** -- Balanced, contested territory

### Starting Civilizations

| Civilization | Starting Region | Advantage |
|-------------|----------------|-----------|
| River Basin Power | Central river basin | High food, fast growth |
| Mountain Stronghold | Northern mountains | Defensive, hard to conquer |
| Coastal Expansionist | Eastern coastline | Production, trade |
