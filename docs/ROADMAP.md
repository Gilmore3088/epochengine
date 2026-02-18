# Roadmap & Milestones

## Current State Snapshot (as of Feb 2026)
- All core simulation systems complete (supply, resources, governance, development tiers, war, heroes, golden ages, tech emergence)
- Full UX information layer (turn summary, civ profile, timeline, victory tracker, diplomacy panel)
- Player decision surface: research focus, spending priorities, town management, expansion, diplomacy
- Fog of war with 3-state visibility model
- 116 handcrafted regions, 3 civs, Voronoi tessellation map
- 404 GUT tests, 1345 assertions, 21 test suites

---

## Short-Term Goals (V0.1 Polish)
- Balance pass: address survival regression (avg 1.2 civs at Y500, target 1.5+)
- Manual playtesting and bug fixing
- Performance verification (currently avg 1.5s per 500yr run)

## Mid-Term Goals (V0.2)
- Trait/ideology engine
- War visualization / front goals
- Tutorial/onboarding tooltips
- Diplomacy depth (trade, non-aggression pacts)

## Long-Term Goals (V0.3+)
- Climate + migration systems
- Industrial pressure tradeoffs
- Planetary expansion (solar system colonies)

---

## Phase 1 — Earth Core [Complete]
- Yearly turn pipeline
- Population growth, stability, war
- Save/load with autosave

## Phase 2 — Simulation to Game [Complete]
- Supply system (Dijkstra routing, terrain throughput, interdiction, attrition)
- Resource pyramid (deposits, extraction, maintenance, complexity)
- Governance + development tiers (6 tiers: Tribal to Federation)
- UX information layer (turn summary, civ profile, timeline)

## Phase 3 — Player Experience [Complete]
- Town simulation + UI (TownPanel, buildings, workforce presets)
- Player expansion (claim neutral regions, cost preview)
- Victory/defeat system (3 victory types + 2 defeat conditions)
- Heroes + golden ages (3 types, spawn/aging/effects)
- Fog of war (HIDDEN/EXPLORED/VISIBLE, auto-adjacency)
- Diplomacy panel (D key toggle)
- Research focus + spending priorities
- "Almost there" indicators
- Procedural terrain textures
- Era transition announcements

## Phase 4 — Climate & Industrial Pressure [Future]
- Migration & environmental stress
- Industrial tradeoffs
- Ideology/cultural drift

## Phase 5 — Solar Expansion [Future]
- Planetary colonies
- Star systems
- Galactic governance

---

## Legacy Documentation
Canonical source of truth: **docs/PRD.md**

Legacy docs archived under docs/legacy/ and should not be treated as current design guidance.
