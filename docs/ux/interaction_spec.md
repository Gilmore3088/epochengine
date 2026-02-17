# UX & Interaction Specification (Aligned to PRD)

## Core Screens / Panels

| Screen / Panel | Purpose |
|---------------|---------|
| Main Map View | Primary gameplay — regions, borders, overlays |
| Region Detail Panel | Click a region to view terrain, owner, yields, towns, actions |
| Town Detail Panel | (In progress) Town stats, buildings, workforce presets |
| Turn Summary Panel | End-of-turn recap (top events + deltas) |
| Civ Profile Panel | Deep dive on civ drivers and trends |
| Timeline Panel | Scrollable event history with filters |
| Victory Panel | Endgame summary (victory/defeat) |

## Core HUD Elements

Persistent during gameplay:
- **Year Counter**
- **Stability Meter** (bar + label)
- **Food / Production / Military** stats
- **Era Badge + Governance Tier**
- **Next Year / Auto-Play** controls
- **Overlay Buttons** (Political, Terrain, Resources, Supply, Fronts)
- **Event Log** (left-bottom)

## Map Overlays

| Overlay | Shows |
|---------|-------|
| Political | Civ ownership tint |
| Terrain | Terrain type coloring |
| Resources | Deposit richness + terrain yield signal |
| Supply | Supply efficiency heatmap |
| Fronts | War front / alliance view |

## Player Actions (Current)

- **Advance Year**
- **Auto-Play (P)**
- **Upgrade Infrastructure** (owned region)
- **Declare War / Seek Peace / Alliance** (via region panel or context menu)
- **Found Town** (owned region, if eligible)
- **Construct Building** (via town actions in region panel)

## Fast-Forward / Auto-Play

- Auto-play advances years on a timer (P to toggle)
- Speed shortcuts: 1/2/3
- Auto-pauses on player-impact events (war, collapse, hero spawn)
- Summary modal shows fast-forward event recap

## Input Controls

- **Left Click** — Select region
- **Right Click** — Context menu
- **Scroll Wheel** — Zoom
- **WASD / Arrow Keys** — Pan
- **Space** — Advance year
- **1/2/3** — Speed presets
- **P** — Toggle auto-play
- **C** — Civ profile
- **T** — Timeline
- **Tab** — Cycle overlays

## UX Priorities (Phase 3)

- Expand town UI to create meaningful per-turn decisions
- Add “almost there” indicators (tier gates, infra gaps, stability thresholds)
- Improve player feedback on action outcomes
