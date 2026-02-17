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

### Phase 1 — Earth Core (Complete)
- Yearly turn pipeline
- Population growth, stability, war
- Save/load

### Phase 2 — Simulation to Game (Mostly Complete)
- Supply system (Dijkstra routing, terrain throughput, interdiction, attrition)
- Resource pyramid (deposits, extraction, maintenance, complexity)
- Governance + development tiers
- UX information layer (turn summary, civ profile, timeline)

### Phase 3 — Town Layer (Next Major Step)
- Town UI + per-town decisions
- Building construction
- Workforce allocation (presets)
- “Almost there” indicators
- Region totals derived from towns

### Phase 4 — Climate & Industrial Pressure (Future)
- Migration & environmental stress
- Industrial tradeoffs
- Ideology/cultural drift

### Phase 5 — Solar Expansion (Future)
- Planetary colonies
- Star systems
- Galactic governance

---

## 3. Systems (Aligned)

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

### Towns (Planned)
- Town UI and building system
- Workforce allocation
- Urban gravity

---

## 4. UX (Aligned)

### Information Layer
- Turn summary panel
- Civilization profile panel
- Timeline log

### Decision Surface
- Currently thin
- Town UI becomes the primary choice layer

---

## 5. Roadmap

### Next Sprint (Phase 3A)
- Town UI + building construction
- Workforce presets
- “Almost there” indicators

### Phase 3B
- Victory conditions + defeat flow
- Empire report summary

### Later
- Trait/ideology engine
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
