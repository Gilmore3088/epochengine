# Epoch Engine -- AI Assistant Context

## Project Overview

Epoch Engine is a single-player, map-driven civilization evolution simulator built in Godot 4 (2D) with GDScript, targeting macOS.

## Core Architecture

- **Simulation separated from rendering** -- Game logic in pure GDScript classes/Resources, not scene tree nodes
- **EventBus singleton** -- Signal-based communication between simulation and UI
- **Custom Resources (.tres)** -- All game data stored as Godot Resources
- **Strict turn pipeline** -- 10-step execution order per simulated year (see docs/PRD.md)

## Key Directories

| Directory | Purpose |
|-----------|---------|
| `autoload/` | Singletons: GameState, EventBus, TurnManager, SaveManager |
| `core/simulation/` | Pure simulation formulas (population, stability, war, tech, AI) |
| `resources/` | Resource class definitions (.gd files) |
| `data/` | Resource instances (.tres files) |
| `scenes/` | Godot scenes (.tscn) |
| `scripts/` | Scene-attached scripts |
| `tests/` | GUT framework tests |
| `docs/` | All game design documentation |

## Design Principles

1. Simulation is probabilistic, not deterministic
2. No visible tech tree -- technology emerges from hidden metric thresholds
3. AI uses weighted probability decisions, not scripted behavior
4. Geography drives gameplay -- terrain affects yields, defense, supply
5. Keep rendering and simulation completely decoupled

## V0.1 Scope (Locked)

Included: 100-120 regions, 3 civilizations, yearly turns, auto-resolve war, heroes, golden ages.
Excluded: Tactical battles, space, climate, multiplayer, procedural maps.

## Coding Conventions

- Follow Godot GDScript style guide (snake_case functions/variables, PascalCase classes)
- Type hints on all function signatures and exported variables
- Constants in CONSTANT_CASE
- Signals in past tense (turn_finished, region_claimed)
- Keep simulation functions pure -- no side effects, no UI references
- Tests for all simulation formulas

## Testing

- Framework: GUT (Godot Unit Testing)
- Test all formulas in `core/simulation/`
- Benchmark: 500-year simulation must not crash

## Documentation

All design docs live in `docs/`. The canonical references are:
- `docs/PRD.md` -- Product requirements and scope
- `docs/systems/simulation_math.md` -- All formulas
- `docs/data/schema.md` -- Data model definitions
- `docs/architecture/technical_architecture.md` -- Project structure and patterns
