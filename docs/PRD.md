# Product Requirements Document

## 1. Product Overview

**Working Title:** Epoch Engine
**Platform:** macOS (Godot 4, 2D)
**Mode:** Single-player
**Core Philosophy:** Strongly emergent, map-driven civilization simulation spanning millennia.

## 2. Core Design Pillars

1. Geography shapes destiny
2. Logistics determines victory
3. Technology emerges from systemic pressure
4. Heroes catalyze historical inflection points
5. Strong emergence over scripted outcomes

## 3. Objectives

- Build playable V0.1 in 6 months
- Region-based Earth simulation
- 1 year per turn with 5x/10x fast-forward

## 4. V0.1 Scope (Locked)

### Included

- 100-120 handcrafted region map
- 3 civilizations
- 1 year per turn
- 5x / 10x fast-forward
- Auto-resolve warfare
- Hero system (3 types: General, Reformer, Visionary)
- Golden age mechanic
- Food, Production, Stability, Military systems

### Explicitly Excluded

- Tactical battle layer
- Climate collapse
- Space layer
- Alien civilizations
- Advanced ideology branches
- Multiplayer
- Procedural map generation

## 5. Simulation Architecture

### Turn Order (Strict)

1. Population Growth
2. Resource Production
3. Resource Consumption
4. Stability Recalculation
5. AI Decisions (Expansion, Diplomacy, War)
6. War Resolution
7. Hero Aging & Effects
8. Golden Age Evaluation
9. Event Processing (Tech Emergence)
10. End-of-Year Logging

## 6. Performance Requirements

- 10-year fast-forward < 2 seconds
- 500-year stability test without crash
- Save file < 5MB

## 7. Definition of Done (Phase 1)

- 500-year stable simulation
- At least one collapse event across 10 runs
- At least one golden age observed across 10 runs
- Save/load round-trip preserves state
