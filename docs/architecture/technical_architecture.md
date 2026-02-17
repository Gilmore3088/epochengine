# Technical Architecture

## Engine

Godot 4 (2D), GDScript

## Core Architectural Principles

- **Simulation separated from rendering** -- All game logic lives in pure GDScript classes/Resources, not in scene tree nodes
- **Event-driven communication** -- EventBus singleton with signals bridges simulation and UI
- **Data-driven design** -- Custom Resources (.tres) for all game data
- **Deterministic simulation** -- Seeded RNG for repeatable outcomes when desired

## Core Classes

| Class | Type | Responsibility |
|-------|------|----------------|
| `RegionData` | Resource | Region properties, yields, adjacency, towns, deposits |
| `CivilizationData` | Resource | Civ state, stockpiles, wars, traits, tech metrics |
| `HeroData` | Resource | Hero type, age, modifiers |
| `TownData` | Resource | Town population, buildings, workforce preset |
| `GameState` | Autoload | Central state, lookups, deterministic RNG |
| `EventBus` | Autoload | Signal-based event system |
| `TurnManager` | Autoload | Turn orchestration and UI event bridge |
| `SaveManager` | Autoload | Save/load via Resource serialization |
| `History` | Core | Persistent event store + stability history |
| `SimulationEngine` | Core | Pure simulation pipeline |

## Project Structure

```
epochengine/
├── project.godot              # Godot 4 project config
├── autoload/                  # Singletons (game_state, event_bus, turn_manager, save_manager)
├── core/                      # Pure simulation logic (no rendering)
│   ├── constants.gd
│   ├── enums.gd
│   ├── history.gd
│   └── simulation/            # population, stability, war_resolver, supply, towns, tech
├── resources/                 # Resource class definitions (.gd)
├── data/                      # Resource instances (.tres)
│   ├── civilizations/
│   └── regions/
├── scenes/                    # Godot scenes (.tscn)
├── scripts/                   # Scene-attached scripts (world + UI)
├── assets/                    # Art, audio, fonts
└── tests/                     # GUT test framework
```

## Key Architectural Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Rendering | Polygon2D | Regions are irregular geographic areas |
| Data model | Custom Resources | Editor-inspectable, auto-serialization, type-safe |
| Communication | EventBus signals | Decouples simulation from rendering |
| Simulation | Pure GDScript (no nodes) | Avoids scene tree overhead |
| Save system | Resource-based | Handles nested structures natively |
| Testing | GUT framework | Standard Godot unit testing |

## Turn Processing Pipeline

Strict execution order per simulated year:

```
1. Population Growth               → core/simulation/population.gd
1.3 Town Auto-Spawn                → core/simulation/town_simulation.gd
1.5 Development Tier Evaluation    → core/simulation/development_tier.gd
2-3 Economy (prod+consumption)     → core/simulation/economy.gd
2.5 Resource Pyramid               → core/simulation/resource_production.gd
3.5 Collapse regionless civs       → SimulationEngine helper
3.6 Supply routing (Dijkstra)      → core/simulation/supply_system.gd
3.7 Starvation attrition           → SimulationEngine helper
3.8 War duration ticking           → SimulationEngine helper
4. Stability recalculation         → core/simulation/stability.gd
4.5 Governance tier evaluation     → core/simulation/governance.gd
5. AI / Player actions             → core/simulation/ai_logic.gd + player_actions.gd
6. War resolution                  → core/simulation/war_resolver.gd
7. Hero aging                       → SimulationEngine helper
8. Golden age evaluation           → SimulationEngine helper
9. Tech emergence                  → core/simulation/tech_emergence.gd
10. Metrics logging (optional)     → core/simulation/metrics_logger.gd
```
