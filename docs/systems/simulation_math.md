# Simulation Math & Emergence (Aligned)

## 1. Population Growth

```
population_next = population_current * (1 + base_rate) * food_mod * stability_mod * variance
```
- **base_rate** varies by terrain
- **food_mod** from food stockpile per capita
- **stability_mod** maps stability 0–100 to a growth modifier
- **variance** bounded random noise

Population is clamped at 0, and growth slows near carrying capacity.

---

## 2. Stability

Stability integrates:
- Food surplus/deficit
- War exhaustion (duration-based)
- Resource shortage penalties
- Hero modifiers (Reformer)
- Overextension penalty (admin capacity)
- Supply penalties (cutoff/low supply)
- Political noise + mean reversion

Collapse trigger:
- Stability below threshold for multiple consecutive years

---

## 3. Economy

- Food/Production are computed from region yields
- If towns exist, outputs aggregate town production and upkeep
- Golden ages boost food/production

---

## 4. War Resolution

```
strength = military * morale * doctrine * terrain * supply * variance
```
- Defender terrain bonus and compact defense bonus
- Attacker supply uses best adjacent supply

---

## 5. Tech Emergence

Techs emerge when hidden metrics exceed thresholds:
- Knowledge
- Energy
- Social coordination
- Economic surplus
- Military pressure

Probabilities scale with overshoot (“pressure multiplier”).
