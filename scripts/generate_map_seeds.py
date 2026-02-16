#!/usr/bin/env python3
"""Generate visual seed positions for 80 new regions using force-directed layout.
Outputs GDScript BASE_SEEDS dictionary entries for world_map.gd."""

import math
import random

# Existing seed positions (fixed anchors)
EXISTING = {
    0: (130, 100), 1: (310, 80), 2: (490, 115),
    3: (670, 90), 4: (850, 108), 5: (1030, 82),
    6: (1210, 100),
    7: (110, 275), 8: (290, 260), 9: (440, 295),
    10: (110, 435), 11: (280, 420), 12: (430, 450),
    13: (130, 585), 14: (310, 570),
    15: (570, 270), 16: (730, 255), 17: (570, 415),
    18: (730, 400), 19: (570, 555), 20: (730, 540),
    21: (880, 280), 22: (880, 435),
    23: (1010, 265), 24: (1170, 275), 25: (1310, 260),
    26: (1010, 425), 27: (1170, 415), 28: (1310, 435),
    29: (1090, 565),
    30: (310, 715), 31: (510, 700), 32: (710, 720),
    33: (910, 705), 34: (1110, 715), 35: (1290, 702),
}

# New region adjacency data
NEW_ADJACENCY = {
    36: [0, 37, 38],
    37: [36, 38, 39],
    38: [36, 37, 40],
    39: [37, 41, 42],
    40: [38, 41, 43],
    41: [39, 40, 42, 43],
    42: [39, 41, 44],
    43: [40, 41, 112],
    44: [42, 1],
    45: [7, 46, 47],
    46: [45, 47, 48],
    47: [45, 46, 49],
    48: [46, 50, 10],
    49: [47, 51, 52],
    50: [48, 51, 14],
    51: [49, 50, 52, 53],
    52: [49, 51, 54],
    53: [51, 54],
    54: [52, 53, 103],
    55: [6, 56, 57, 115],
    56: [55, 57, 58],
    57: [55, 56, 59],
    58: [56, 59, 60, 30],
    59: [57, 58, 61],
    60: [58, 61, 62],
    61: [59, 60, 62],
    62: [60, 61, 96],
    63: [17, 64, 65],
    64: [63, 65, 66],
    65: [63, 64, 67],
    66: [64, 68, 20],
    67: [65, 68, 69],
    68: [66, 67, 69, 70],
    69: [67, 68, 70, 71],
    70: [68, 69, 71, 72],
    71: [69, 70, 72, 21],
    72: [70, 71, 32],
    73: [19, 74, 75],
    74: [73, 75, 76],
    75: [73, 74, 77],
    76: [74, 78, 13],
    77: [75, 78, 79],
    78: [76, 77, 79, 80],
    79: [77, 78, 80, 81],
    80: [78, 79, 81],
    81: [79, 80, 82],
    82: [81, 33, 88],
    83: [27, 84, 85],
    84: [83, 85, 86],
    85: [83, 84, 87],
    86: [84, 87, 29],
    87: [85, 86, 89],
    88: [82, 89, 90, 95],
    89: [87, 88, 90, 91],
    90: [88, 89, 91, 92],
    91: [89, 90, 92],
    92: [90, 91],
    93: [34, 94, 95],
    94: [93, 95, 96],
    95: [93, 94, 97, 88],
    96: [62, 94, 97, 98],
    97: [95, 96, 98, 99],
    98: [96, 97, 99, 100],
    99: [97, 98, 100, 101],
    100: [98, 99, 101, 102],
    101: [99, 100, 102],
    102: [100, 101, 35],
    103: [54, 104, 105],
    104: [103, 105, 106],
    105: [103, 104, 107],
    106: [104, 107, 108],
    107: [105, 106, 108, 109],
    108: [106, 107, 109, 110],
    109: [107, 108, 111],
    110: [108, 111],
    111: [109, 110],
    112: [43, 113, 114],
    113: [112, 114, 115],
    114: [112, 113, 115],
    115: [113, 114, 55],
}

# Zone hints: push new regions outward from center to form a larger continent
# (region_id, direction_x, direction_y) - bias for initial placement
ZONE_BIAS = {}
# Northern tundra: push north
for rid in range(36, 45):
    ZONE_BIAS[rid] = (0, -180)
# Eastern desert: push west/south
for rid in range(45, 55):
    ZONE_BIAS[rid] = (-200, 50)
# Western foothills: push east/south
for rid in range(55, 63):
    ZONE_BIAS[rid] = (200, 150)
# Central river extension: push south
for rid in range(63, 73):
    ZONE_BIAS[rid] = (0, 200)
# Jungle belt: push south
for rid in range(73, 83):
    ZONE_BIAS[rid] = (-50, 200)
# Extended coastline: push east/south
for rid in range(83, 93):
    ZONE_BIAS[rid] = (150, 200)
# Southern plains: push south
for rid in range(93, 103):
    ZONE_BIAS[rid] = (0, 300)
# Far eastern oasis: push far west
for rid in range(103, 112):
    ZONE_BIAS[rid] = (-350, 100)
# Northwestern connection: push north-east
for rid in range(112, 116):
    ZONE_BIAS[rid] = (150, -250)


def initialize_positions():
    """Set initial positions based on neighbor averages + zone bias."""
    positions = dict(EXISTING)

    # Multiple passes since some new regions depend on other new regions
    for _ in range(5):
        for rid, adj in NEW_ADJACENCY.items():
            if rid in positions:
                continue
            # Average position of placed neighbors
            placed = [(positions[n][0], positions[n][1]) for n in adj if n in positions]
            if not placed:
                continue
            avg_x = sum(p[0] for p in placed) / len(placed)
            avg_y = sum(p[1] for p in placed) / len(placed)

            # Add zone bias
            bx, by = ZONE_BIAS.get(rid, (0, 0))
            positions[rid] = (avg_x + bx, avg_y + by)

    return positions


def force_directed_layout(positions, iterations=300):
    """Refine positions using spring-force simulation."""
    pos = {k: list(v) for k, v in positions.items()}
    fixed = set(EXISTING.keys())

    # Build full adjacency including existing region connections
    all_adj = dict(NEW_ADJACENCY)

    REPEL_STRENGTH = 50000.0
    ATTRACT_STRENGTH = 0.01
    MIN_DIST = 100.0  # Minimum distance between any two seeds
    DAMPING = 0.85

    new_ids = list(NEW_ADJACENCY.keys())
    all_ids = list(pos.keys())

    for iteration in range(iterations):
        forces = {k: [0.0, 0.0] for k in new_ids}

        # Repulsion between all pairs of new+existing nodes (but only apply to new)
        for i, id_a in enumerate(all_ids):
            if id_a not in forces:
                continue
            for id_b in all_ids:
                if id_a == id_b:
                    continue
                dx = pos[id_a][0] - pos[id_b][0]
                dy = pos[id_a][1] - pos[id_b][1]
                dist = max(math.sqrt(dx*dx + dy*dy), 1.0)
                if dist < MIN_DIST * 3:
                    force = REPEL_STRENGTH / (dist * dist)
                    forces[id_a][0] += (dx / dist) * force
                    forces[id_a][1] += (dy / dist) * force

        # Attraction along edges (toward neighbors)
        for rid in new_ids:
            for neighbor in all_adj.get(rid, []):
                if neighbor not in pos:
                    continue
                dx = pos[neighbor][0] - pos[rid][0]
                dy = pos[neighbor][1] - pos[rid][1]
                dist = math.sqrt(dx*dx + dy*dy)
                target_dist = 160.0  # Ideal distance between neighbors
                if dist > 0:
                    force = (dist - target_dist) * ATTRACT_STRENGTH
                    forces[rid][0] += (dx / dist) * force
                    forces[rid][1] += (dy / dist) * force

        # Apply forces
        max_move = 0
        for rid in new_ids:
            if rid in fixed:
                continue
            move_x = forces[rid][0] * DAMPING
            move_y = forces[rid][1] * DAMPING
            # Limit max movement per step
            mag = math.sqrt(move_x*move_x + move_y*move_y)
            if mag > 30:
                move_x = move_x / mag * 30
                move_y = move_y / mag * 30
            pos[rid][0] += move_x
            pos[rid][1] += move_y
            max_move = max(max_move, mag)

        if max_move < 0.5:
            print(f"  Converged at iteration {iteration}")
            break

    return {k: (round(v[0]), round(v[1])) for k, v in pos.items()}


def format_output(positions):
    """Format as GDScript BASE_SEEDS entries."""
    # Group by zone
    zones = {
        "Northern Tundra": range(36, 45),
        "Eastern Desert Extension": range(45, 55),
        "Western Foothills": range(55, 63),
        "Central River Extension": range(63, 73),
        "Jungle Belt": range(73, 83),
        "Extended Coastline": range(83, 93),
        "Southern Plains": range(93, 103),
        "Far Eastern Oasis": range(103, 112),
        "Northwestern Connection": range(112, 116),
    }

    lines = []
    for zone_name, id_range in zones.items():
        lines.append(f"\t# {zone_name} (IDs {id_range.start}-{id_range.stop - 1})")
        row = "\t"
        for rid in id_range:
            x, y = positions[rid]
            entry = f"{rid}: Vector2({x}, {y}), "
            if len(row) + len(entry) > 80:
                lines.append(row.rstrip())
                row = "\t"
            row += entry
        if row.strip():
            lines.append(row.rstrip())

    return "\n".join(lines)


def compute_bounds(positions):
    """Compute map bounds for ocean/canvas sizing."""
    xs = [p[0] for p in positions.values()]
    ys = [p[1] for p in positions.values()]
    return min(xs), min(ys), max(xs), max(ys)


def generate_ocean_seeds(min_x, min_y, max_x, max_y, margin=200):
    """Generate ocean seeds around the expanded map."""
    seeds = []
    # Expand bounds
    ox1 = min_x - margin
    oy1 = min_y - margin
    ox2 = max_x + margin
    oy2 = max_y + margin

    # Top edge
    for x in range(int(ox1), int(ox2), 300):
        seeds.append((x, oy1 - 100))
    # Bottom edge
    for x in range(int(ox1), int(ox2), 300):
        seeds.append((x, oy2 + 100))
    # Left edge
    for y in range(int(oy1), int(oy2), 300):
        seeds.append((ox1 - 100, y))
    # Right edge
    for y in range(int(oy1), int(oy2), 300):
        seeds.append((ox2 + 100, y))

    return seeds


def main():
    print("Generating map seed positions...")

    # Initialize positions
    positions = initialize_positions()
    missing = [rid for rid in NEW_ADJACENCY if rid not in positions]
    if missing:
        print(f"WARNING: Could not place regions: {missing}")
        return
    print(f"  Initialized {len(NEW_ADJACENCY)} new positions")

    # Force-directed refinement
    print("  Running force-directed layout...")
    positions = force_directed_layout(positions)

    # Compute stats
    min_x, min_y, max_x, max_y = compute_bounds(positions)
    print(f"\n  Map bounds: X({min_x} to {max_x}), Y({min_y} to {max_y})")
    print(f"  Map size: {max_x - min_x}px x {max_y - min_y}px")

    # Output new seeds
    print("\n# --- Add to BASE_SEEDS in world_map.gd ---\n")
    print(format_output(positions))

    # Ocean seeds
    ocean = generate_ocean_seeds(min_x, min_y, max_x, max_y)
    print(f"\n# --- OCEAN_SEEDS ({len(ocean)} seeds) ---")
    print("var OCEAN_SEEDS: Array[Vector2] = [")
    for i, (x, y) in enumerate(ocean):
        comma = "," if i < len(ocean) - 1 else ""
        print(f"\tVector2({x}, {y}){comma}")
    print("]")

    # Bounds for ocean rendering
    print(f"\n# --- Ocean rendering bounds ---")
    print(f"# bounds_pos = Vector2({min_x - 500}, {min_y - 500})")
    print(f"# bounds_end = Vector2({max_x + 500}, {max_y + 500})")


if __name__ == "__main__":
    main()
