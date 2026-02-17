# Roadmap & Milestones

## Current State Snapshot (as of Feb 16, 2026)
- Phase 2 simulation complete: governance, dev tiers, supply, resources, visual polish
- 249 tests passing, 834 assertions
- 20-seed benchmark: all 8 acceptance criteria PASS (avg 503ms/500yr, 16/20 multi-civ survival)

## Status & Goals

### Current Status
- Core simulation loop is feature-complete for Phase 2
- Visual polish complete: auto-play, map flashes, toasts, event log, panel animations
- Player agency systems exist (action queue, player civ tracking, UI controls)
- Map polish partially done (terrain render pass, overlay cycling), seed/bounds/camera tuning pending
- Supply/resource overlays not yet visualized on map

### Short-Term Goals (next 2-6 weeks)
- Supply overlay + resource overlay visualization on map
- Map polish: seed retune, ocean/compass, camera centering
- Remaining Sprint H items (renewable resource degradation, resource overlay)

### Long-Term Goals (Phase 3+)
- Town layer prototype (region sub-map, town connectivity, building construction)
- Climate and migration systems tied to supply/resource networks
- Industrial pressure tradeoffs and cultural spread via trade routes
- Solar expansion with orbital regions and optional tactical layer

### Task Backlog (Concrete, Ordered)
1) Supply overlay visualization (Sprint G)
2) Resource overlay visualization (Sprint H)
3) Map polish: seed retune -> ocean/compass -> camera centering
4) Town layer MVP plan + data model extension proposal

## Phase 1 -- Earth Core [COMPLETE]

### Month 1: Foundation
- [x] Static handcrafted continent map (116 regions across 9 geographic zones)
- [x] 3 civilizations with starting positions
- [x] 1 year per turn simulation engine
- [x] Population growth formula
- [x] Basic stability system

### Month 2: Conflict & Expansion
- [x] Expansion logic (AI)
- [x] Auto-resolve war system
- [x] Supply routing system (Dijkstra from capital with terrain throughput)
- [x] Terrain-based defense modifiers

### Month 3: Heroes & Polish
- [x] Hero system (3 types: General, Reformer, Visionary)
- [x] Golden age mechanic
- [x] Fast-forward (5x / 10x)
- [x] 500-year stability benchmark (tests pass, see CI)
- [x] Save/load system

### Results
- 500-year stable simulation without crash
- Collapses, golden ages, wars, tech emergence all verified
- 10-year fast-forward < 2 seconds (peak 23ms)

---

## Phase 2 -- From Simulation to Game [IN PROGRESS]

### Sprint E: Player Agency [COMPLETE]
- [x] Player civilization tracking (GameState.player_civ_id)
- [x] Player action queue (PlayerActions static class)
- [x] Turn pipeline integration (player vs AI branching)
- [x] Right-click context menu
- [x] Region panel action buttons (upgrade, war, peace, alliance)
- [x] Keyboard shortcuts (1/2/3 for speed, Space for advance)
- [x] Auto-pause during fast-forward on player events

### Stage 1: Simulation Stability [COMPLETE]
- [x] 500yr benchmark without crash
- [x] At least 1 collapse and 1 golden age in 10 runs
- [x] Fast-forward performance < 2s per 10yr

### Stage 2: Equilibrium Tuning [COMPLETE]
- [x] Border tension model (parity-aware war probability)
- [x] War fatigue escalation (duration-based)
- [x] Peace cooldown (15yr after treaty)
- [x] AI alliance seeking (shared enemy bonus)
- [x] Compact defense bonus (+25% for small civs)
- [x] Result: 7/10 runs have 2+ civs surviving 500yr, avg 1.8 alive

### Stage 3: Region Size Factor [COMPLETE]
- [x] Voronoi polygon area calculation (Shoelace formula)
- [x] size_factor applied to carrying capacity, food/production yields, defense
- [x] Tests pass (224 tests, 633 assertions as of Feb 17, 2026)

### UX Improvements [COMPLETE]
- [x] Zoom +/- buttons (MacBook trackpad support)
- [x] Action buttons directly in region panel (no right-click required)
- [x] Fixed Space key conflict with UI buttons (focus_mode = FOCUS_NONE)
- [x] Draggable region panel with edge snapping
- [x] Resizable panel with A-/A+ font scaling (0.8x to 1.4x)
- [x] Fixed panel closing on button click (_unhandled_input fix)

### Stage 4: Governance Architecture [COMPLETE]
- [x] GovernanceTier enum (Tribal, Chiefdom, City-State, Kingdom, Empire, Federation)
- [x] Governance fields on CivilizationData (tier, years in tier)
- [x] Tier transition logic with promotion and demotion hysteresis (5yr)
- [x] Admin capacity bonus from governance tier
- [x] Expansion friction reduction for higher-tier civs
- [x] Infrastructure stability floor (avg_infra * 2.0)
- [x] Infrastructure military reinforcement bonus (+5% per avg level)
- [x] Future-compat placeholders on RegionData (urbanization_level, town_count, supply_value)
- [x] New terrain types: STEPPE, VOLCANIC_RIDGE (enums + constants, no regions assigned)
- [x] Save/load for all new fields (backward compatible)
- [x] Tests pass (224 tests, 633 assertions as of Feb 17, 2026)

### Stage 5: Development Tiers [COMPLETE]
- [x] DevelopmentTier enum (Wild → Advanced)
- [x] Era system (Prehistoric → Future) with tech-based thresholds
- [x] Tier gates by infra, pop density, stability, governance, era, resources
- [x] Tier effects on economy, defense, and admin capacity

### Sprint V1: Visual Polish + Auto-Play [COMPLETE]
- [x] Auto-play toggle (P key, Timer-based, 0.8s default)
- [x] Speed controls during auto-play (1/2/3 keys: 1.2s/0.8s/0.3s)
- [x] Auto-pause on player war, collapse, hero spawn
- [x] Map event flashes (green=expansion, red=conquest, dark=collapse)
- [x] Toast notifications (slide-down, color-coded, max 3 stacked)
- [x] Top bar polish (28px year, 160px stability bar with %, era badge)
- [x] Event log prefixes and color-coding ([WAR], [PEACE], [TECH], etc.)
- [x] Region panel slide-in/out animations
- [x] Context menu dark theme with gold accents

### Benchmark B1: 20-Seed CSV Export [COMPLETE]
- [x] Expanded from 10 to 20 seeds
- [x] CSV export to user://benchmark_results.csv
- [x] All 8 acceptance criteria PASS (16/20 multi-civ, avg 2.1 alive, 46 wars)

### Sprint F: Map Polish [IN PROGRESS]
- [x] Terrain rendering pass (dual-mode textures + fallback)
- [x] Map overlay cycling (Tab key)
- [ ] Retune seed positions (tighten continent bounds)
- [ ] Recompute ocean/compass for new bounds
- [ ] Center camera on new continent

### Sprint G: Supply & Logistics [IN PROGRESS]
- [x] Dijkstra supply system from capital
- [x] Terrain-based throughput
- [x] Combat integration (supply gradient)
- [x] Stability integration (disconnected penalty gradient)
- [x] Starvation attrition
- [x] Enemy interdiction (cutting supply lines)
- [x] AI supply awareness
- [ ] Supply overlay visualization

### Sprint H: Resource Depth [IN PROGRESS]
- [x] Resource deposits by terrain (fuels, rare materials, etc.)
- [x] Extraction and depletion system
- [ ] Renewable resource degradation
- [x] Economy integration (effective yields)
- [x] Save/load support for resource stockpiles and logs
- [ ] Resource overlay + AI awareness (surface to UI)

---

## Phase 3 -- Town Layer & Societal Connectivity [FUTURE]

**Design doc:** `docs/design/MULTI_LAYER_GAMEPLAY.md`

Two zoom levels of gameplay:
- **World map** (zoomed out): Risk/Stellaris/Civ grand strategy (current system)
- **Region view** (zoomed in): Civ/AoE/Pharaoh city-building

### Key Features
- Multiple towns/cities per region
- Building construction (granary, barracks, market, walls, etc.)
- Three-tier infrastructure: town, region, national
- Town connectivity affects regional output
- Region sub-map rendering
- Smooth transition between zoom levels

### Prerequisites
- Phase 2 supply system (Sprint G) informs town connectivity model
- Phase 2 resource system (Sprint H) provides extraction framework
- RegionData extensibility (size_factor, resource_stock already added)

---

## Phase 4 -- Climate & Industrial Pressure [FUTURE]

- Environmental stress systems
- Migration patterns driven by climate
- Industrial tradeoffs (production vs environmental degradation)
- Advanced ideology branches
- Cultural spread along trade routes

---

## Phase 5 -- Solar Expansion [FUTURE]

- Orbital regions
- Planetary colonies
- Alien civilizations
- Tactical battle layer (optional engagement)
