# Hidden Tech Emergence Specification

## Philosophy

Technology is strongly emergent. Players never select technologies from a tree. Instead, technologies emerge when systemic conditions within a civilization reach specific thresholds.

This means:
- Tech unlocks are not selected by the player
- They emerge when systemic thresholds are met
- The same civilization may develop different techs across different playthroughs
- Pressure (war, scarcity) can accelerate certain tech paths

## Core Hidden Metrics

Each civilization tracks these metrics (hidden from the player in V0.1):

| Metric | Range | Driven By |
|--------|-------|-----------|
| Knowledge Complexity | 0-100 | Population size, stability, hero (Visionary) |
| Energy Capacity | 0-100 | Production output, resource extraction |
| Social Coordination | 0-100 | Stability, population density, golden ages |
| Economic Surplus | 0-100 | Food + production stockpile levels |
| Military Pressure | 0-100 | Active wars, border threats, army size |

## Emergence Rules

A technology becomes eligible when threshold conditions are met. Then a weighted probability roll determines if it actually emerges this year.

```
If threshold_conditions_met:
  emergence_chance = base_probability * pressure_multiplier * random_roll
  If emergence_chance > threshold:
    Technology emerges
```

## Example Technologies

| Technology | Knowledge | Energy | Social | Economic | Military | Effect |
|-----------|-----------|--------|--------|----------|----------|--------|
| Irrigation | 20 | - | 30 | 20 | - | +30% food in river regions |
| Bronze Working | 30 | 20 | - | - | 30 | +20% military equipment |
| Writing | 40 | - | 40 | 30 | - | +10% knowledge growth |
| Gunpowder | 50 | 40 | - | - | 60 | +50% military equipment |
| Steam Power | 60 | 60 | 40 | 50 | - | +40% production |
| Fusion Research | 70+ | 60+ | - | 50+ | - | Massive energy bonus |
| Advanced Weapons | - | - | - | 60+ | 70+ | Dominant military tech |

## Metric Growth

Hidden metrics grow naturally each year based on civilization state:

```
knowledge_growth = base_rate * (population / 10000) * stability_factor * hero_bonus
energy_growth = base_rate * production_output * infrastructure_level
social_growth = base_rate * stability * (population_density) * golden_age_bonus
economic_growth = base_rate * (food_surplus + production_surplus)
military_growth = base_rate * army_size * war_count
```

Metrics decay slowly if their drivers weaken (e.g., knowledge drops if population collapses).
