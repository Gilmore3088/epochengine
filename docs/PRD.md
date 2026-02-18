# Product Requirements Document (PRD)

## 1. Overview

### Summary
Epoch Engine is a map-driven civilization evolution simulator where geography, logistics, and systemic pressure shape history from prehistoric tribes to interplanetary empires.

### Vision
A strongly emergent geopolitical simulation where terrain, logistics, heroes, and systemic friction create divergent outcomes across civilizations.

### Design Principles
1. No hard genre switches
2. Systems expand, not reset
3. Emergent identity over scripted arcs
4. Scaling introduces friction, not inevitability

### Core Pillars
- Geography shapes destiny
- Logistics determines victory
- Tech emerges from pressure
- Heroes catalyze history
- Strong emergence

---

## 2. Features by Phase

### Phase 1 — Earth Core [Complete]
- Yearly turn pipeline
- Population growth, stability, war
- Save/load

### Phase 2 — Simulation to Game [Complete]
- Supply system (Dijkstra routing, terrain throughput, interdiction, attrition)
- Resource pyramid (deposits, extraction, maintenance, complexity)
- Governance + development tiers
- UX information layer (turn summary, civ profile, timeline)

### Phase 3 — Player Experience [Complete]
- Town simulation + UI (TownPanel, buildings, workforce presets)
- Player expansion (claim neutral regions, expansion cost preview)
- Victory/defeat system (domination, cultural, federation + collapse/territory defeat)
- Heroes + golden ages (spawn, aging, 3 types, effects on military/stability/production)
- Fog of war (3-state visibility, auto-adjacency from Voronoi polygons)
- Diplomacy panel (D key, all civ relationships, action buttons)
- Research focus + spending priorities
- "Almost there" indicators (tier gates, tech proximity, town hints)
- Procedural terrain textures (FastNoiseLite, 9 terrain types)
- Era transition announcements
- Keyboard shortcuts (P=play, Space=advance, 1/2/3=speed, C=profile, T=timeline, V=victory, D=diplomacy, Esc=pause)

### Phase 4 — Climate & Industrial Pressure [Future]
- Migration & environmental stress
- Industrial tradeoffs
- Ideology/cultural drift

### Phase 5 — Solar Expansion [Future]
- Planetary colonies
- Star systems
- Galactic governance

---

## 3. Systems

### Supply
- Dijkstra routing from capital
- Terrain throughput + interdiction
- Supply affects economy and stability

### Resources
- Deposits + extraction
- Maintenance penalties
- Complexity tax

### Governance & Development
- Tier gates by infra/pop/stability/era
- Hysteresis for demotion
- Admin capacity bonuses

### Towns
- Town founding (pop >= 500), auto-spawn (pop >= 3000)
- 6 building types (Granary, Workshop, Barracks, Market, Monument, Walls)
- 5 workforce presets
- Town outputs aggregated into region yields

### Heroes & Golden Ages
- 3 hero types: General (+10% military), Reformer (+5 stability), Visionary (+10% production)
- Spawn chance scales with stability + population, max 3 per civ
- Golden age: stability > 80, no wars, +50% food/production, 20yr duration, 30yr cooldown

### Victory & Defeat
- Domination (>60% regions), Cultural (>7 techs + stability), Federation (>3 allies)
- Defeat: collapse or territory loss

### Fog of War
- Three-state visibility: HIDDEN, EXPLORED, VISIBLE
- Auto-adjacency computed from Voronoi polygon shared edges
- Player-only (AI omniscient in V0.1)

---

## 4. UX

### Information Layer
- Turn summary panel (bottom-center, auto-dismiss)
- Civilization profile panel (C key, 5-zone insight)
- Timeline log (T key, filterable events)
- Victory tracker (V key, 3-bar progress)
- Diplomacy panel (D key, all relationships + actions)

### Decision Surface
- Research focus (6 options, +100% metric boost)
- Spending priorities (4 options)
- Infrastructure investment (per-region)
- Town founding + building construction + workforce presets
- Claim neutral regions (right-click adjacent)
- Declare war / seek peace / seek alliance

---

## 5. Roadmap

### Immediate (V0.1 Polish)
- Balance pass (survival regression: avg 1.2 civs at Y500, target 1.5+)
- Manual playtesting sessions
- Bug fixes from playtesting

### Next (V0.2)
- Trait/ideology engine
- War visualization / front goals
- Tutorial/onboarding tooltips

### Later (V0.3+)
- Climate systems
- Planetary expansion

---

## Document Index

Canonical source of truth: **docs/PRD.md**

Supporting (aligned to PRD):
- docs/ROADMAP.md
- docs/architecture/technical_architecture.md
- docs/ux/interaction_spec.md
- docs/systems/*

Legacy (archived for historical context):
- docs/legacy/MULTI_LAYER_GAMEPLAY.md
