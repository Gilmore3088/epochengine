# Epoch Engine

A map-driven civilization evolution simulator built in Godot 4.

## Vision

A strongly emergent geopolitical simulation where geography, logistics, heroes, and systemic pressure shape history from prehistoric tribes to planetary dominance.

## Core Pillars

1. **Geography shapes destiny** -- Terrain determines resources, defense, growth
2. **Logistics determines victory** -- Supply lines matter more than army size
3. **Technology emerges from pressure** -- No tech tree; techs appear when conditions are met
4. **Heroes catalyze history** -- Named individuals shift the course of civilizations
5. **Strong emergence** -- Probabilistic outcomes, never scripted

## Current Status

**v0.0.1** -- Documentation and project structure established.

**Phase 1 Goal:** Run a stable 500-year Earth simulation with 3 asymmetric civilizations.

## Tech Stack

- **Engine:** Godot 4 (2D)
- **Language:** GDScript
- **Platform:** macOS
- **Architecture:** Resource-based data model, EventBus signals, simulation separated from rendering

## Project Structure

```
epochengine/
├── autoload/          # Singletons (GameState, EventBus, TurnManager, SaveManager)
├── core/              # Pure simulation logic (no rendering)
│   ├── constants.gd
│   ├── enums.gd
│   └── simulation/    # Population, stability, war, tech, AI
├── resources/         # Custom Resource class definitions
├── data/              # Resource instances (.tres files)
├── scenes/            # Godot scenes (.tscn)
├── scripts/           # Scene-attached scripts
├── assets/            # Art, audio, fonts
├── tests/             # GUT test framework
└── docs/              # Game design documentation
```

## Documentation

- [Vision & Pillars](docs/VISION.md)
- [Product Requirements](docs/PRD.md)
- [Game Design Document](docs/GDD.md)
- [Roadmap](docs/ROADMAP.md)
- [Technical Architecture](docs/architecture/technical_architecture.md)
- [Data Schema](docs/data/schema.md)

### System Specs

- [Simulation Math](docs/systems/simulation_math.md)
- [World & Terrain](docs/systems/world_and_terrain.md)
- [War & Logistics](docs/systems/war_and_logistics.md)
- [Heroes & Golden Ages](docs/systems/heroes_and_golden_ages.md)
- [Tech Emergence](docs/systems/tech_emergence.md)
- [AI Behavior](docs/systems/ai_behavior.md)
- [UX & Interaction](docs/ux/interaction_spec.md)

## Getting Started

1. Install [Godot 4](https://godotengine.org/download/)
2. Clone this repository
3. Open `project.godot` in Godot
4. Press F5 to run

## License

All rights reserved.
