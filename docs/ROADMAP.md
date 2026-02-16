# Roadmap & Milestones

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
- [x] Supply simplified to adjacency to capital
- [x] Terrain-based defense modifiers

### Month 3: Heroes & Polish
- [x] Hero system (3 types: General, Reformer, Visionary)
- [x] Golden age mechanic
- [x] Fast-forward (5x / 10x)
- [x] 500-year stability benchmark (129 tests, 467 assertions)
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
- [x] All 129 tests pass, benchmark equilibrium maintained

### UX Improvements [COMPLETE]
- [x] Zoom +/- buttons (MacBook trackpad support)
- [x] Action buttons directly in region panel (no right-click required)
- [x] Fixed Space key conflict with UI buttons (focus_mode = FOCUS_NONE)
- [x] Draggable region panel with edge snapping
- [x] Resizable panel with A-/A+ font scaling (0.8x to 1.4x)
- [x] Fixed panel closing on button click (_unhandled_input fix)

### Sprint F: Map Polish [NOT STARTED]
- [ ] Retune seed positions (tighten continent bounds)
- [ ] Recompute ocean/compass for new bounds
- [ ] Center camera on new continent

### Sprint G: Supply & Logistics [NOT STARTED]
- [ ] Dijkstra supply system from capital
- [ ] Terrain-based throughput
- [ ] Combat integration (supply gradient)
- [ ] Stability integration (disconnected penalty gradient)
- [ ] Starvation attrition
- [ ] Enemy interdiction (cutting supply lines)
- [ ] AI supply awareness
- [ ] Supply overlay visualization

### Sprint H: Resource Depth [NOT STARTED]
- [ ] Resource deposits by terrain (coal, oil, rare earths, wood)
- [ ] Extraction and depletion system
- [ ] Renewable resource degradation
- [ ] Economy integration (effective yields)
- [ ] Resource overlay, AI awareness, save/load

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
