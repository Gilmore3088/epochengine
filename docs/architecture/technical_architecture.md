# Technical Architecture

## Engine

Godot 4 (2D), GDScript

## Core Architectural Principles

- **Simulation separated from rendering** -- All game logic lives in pure GDScript classes/Resources, not in scene tree nodes
- **Event-driven communication** -- EventBus singleton with signals bridges simulation and UI
- **Data-driven design** -- Custom Resources (.tres) for all game data
- **Deterministic simulation with bounded randomness** -- Seed-based world generation, probabilistic outcomes

## Core Classes

| Class | Type | Responsibility |
|-------|------|----------------|
| `RegionData` | Resource | Region properties, yields, adjacency |
| `CivilizationData` | Resource | Civ state, stockpiles, hero list |
| `HeroData` | Resource | Hero type, age, modifiers |
| `ArmyData` | Resource | Manpower, morale, supply (future) |
| `GameState` | Autoload | Central state, region/civ lookups |
| `EventBus` | Autoload | Signal-based event system |
| `TurnManager` | Autoload | 10-step turn pipeline |
| `SaveManager` | Autoload | Save/load with Resource serialization |

## Project Structure

```
epochengine/
├── project.godot              # Godot 4 project config
├── autoload/                  # Singletons (game_state, event_bus, turn_manager, save_manager)
├── core/                      # Pure simulation logic (no rendering)
│   ├── constants.gd
│   ├── enums.gd
│   └── simulation/            # population, stability, war_resolver, tech_emergence, ai_logic
├── resources/                 # Custom Resource class definitions (.gd)
├── data/                      # Resource instances (.tres)
│   ├── civilizations/
│   ├── regions/
│   └── heroes/
├── scenes/                    # Godot scenes (.tscn)
│   ├── world/
│   └── ui/
├── scripts/                   # Scene-attached scripts
├── assets/                    # Art, audio, fonts
└── tests/                     # GUT test framework
```

## Key Architectural Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Rendering | Polygon2D | Regions are irregular geographic areas |
| Data model | Custom Resources (.tres) | Editor-inspectable, auto-serialization, type-safe |
| Communication | EventBus signals | Decouples simulation from rendering |
| Simulation | Pure GDScript (no nodes) | Performance: avoids scene tree overhead |
| Save system | Resource-based | Handles nested structures natively |
| Testing | GUT framework | Standard Godot unit testing |

## Turn Processing Pipeline

Strict execution order per simulated year:

```
1. Population Growth         → core/simulation/population.gd
2. Resource Production       → region yields applied to civ stockpiles
3. Resource Consumption      → population eats food, military consumes production
4. Stability Recalculation   → core/simulation/stability.gd
5. AI Decisions              → core/simulation/ai_logic.gd
6. War Resolution            → core/simulation/war_resolver.gd
7. Hero Aging & Effects      → age++, check lifespan, apply modifiers
8. Golden Age Evaluation     → stability > 80, surplus, no war → 20yr bonus
9. Tech Emergence Check      → core/simulation/tech_emergence.gd
10. End-of-Year Logging      → event_bus signals → UI updates
```
