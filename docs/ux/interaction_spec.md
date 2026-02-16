# UX & Interaction Specification

## Core Screens

| Screen | Purpose |
|--------|---------|
| Main Map View | Primary gameplay -- colored regions, civilization borders |
| Region Detail Panel | Click a region to see population, terrain, owner, yields |
| Diplomacy Screen | View and manage alliances, declare war |
| War Overview | Active fronts, military strength comparison |
| Timeline Log | Scrollable history of events per year |
| Fast-Forward Summary Modal | Recap of important events during fast-forward |

## Core HUD Elements

Persistent on-screen during gameplay:

- **Year Counter** -- Current simulated year
- **Stability Meter** -- Player civilization's stability (0-100 bar)
- **Resource Panel** -- Food stockpile, production stockpile, military strength
- **Military Strength Display** -- Army size and morale indicator
- **Fast Forward Controls** -- Play/pause, 5x, 10x speed buttons
- **Map Overlay Toggle** -- Switch between terrain/resource/supply/alliance views

## Map Overlays

| Overlay | Shows |
|---------|-------|
| Terrain | Terrain type coloring (green plains, brown mountains, etc.) |
| Resources | Resource deposits and depletion status |
| Supply Lines | Connection paths from capitals |
| Alliances | Color-coded alliance groupings |

## Player Actions (V0.1)

- **Declare War** -- Select enemy civilization from diplomacy screen
- **Offer Alliance** -- Propose alliance to neighboring civilization
- **Adjust Military Investment** -- Slider to allocate production to military
- **Advance Year** -- Process one simulation year
- **Toggle Fast Forward** -- 5x or 10x speed, pauses on important events

## Fast-Forward Behavior

- Runs multiple yearly ticks automatically
- **Auto-pauses on:**
  - War declaration (by any civilization)
  - Hero emergence or death
  - Golden age start or end
  - Civilization collapse
  - Technology emergence
- Summary modal shows all events that occurred during fast-forward period

## Input Controls

- **Left Click** -- Select region
- **Right Click** -- Context menu (declare war, offer alliance)
- **Scroll Wheel** -- Zoom map
- **WASD / Arrow Keys** -- Pan map
- **Space** -- Advance year
- **1/2/3** -- Normal / 5x / 10x speed
