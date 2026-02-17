# AI Behavior Model (Aligned)

## Design Principle
AI decisions are driven by weighted probabilities and state thresholds to create emergent behavior.

## Decision States
AI evaluates a civ state each year:
- **Declining** (low stability) → seek peace, alliances
- **Stable/Growing** → expand, consider war, invest in infrastructure

## Expansion Logic
- Requires stability above threshold and non‑negative food
- Uses expansion friction (slower growth as empire grows)
- Prioritizes adjacent neutral regions with better supply, higher tier neighbors, resource value, and food yield

## War Declaration Logic
- Stability threshold gate
- Uses military parity model (near parity discourages war, strong advantage increases chance)
- Honors peace cooldown and alliance constraints

## Peace Logic
- Low stability + long war duration increases peace chance
- Peace creates cooldown before re‑declaration

## Alliance Logic
- Requires stability threshold
- Increased chance with shared enemies

## Infrastructure Investment
- AI upgrades infrastructure when surplus production exceeds threshold
- Prioritizes regions closest to next dev‑tier gate

## Personality Biases
Each civ has bias weights:
- Expansion
- Aggression
- Diplomacy
- Economy

These biases modulate expansion, war, and alliance probabilities.
