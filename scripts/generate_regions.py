#!/usr/bin/env python3
"""Generate 80 new region .tres files and update existing adjacency lists."""

import os

REGIONS_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "regions")

# Terrain type enum values matching enums.gd
RIVER_BASIN = 0
PLAINS = 1
MOUNTAINS = 2
DESERT = 3
JUNGLE = 4
COASTLINE = 5
TUNDRA = 6

# Yields per terrain (food, prod, defense)
TERRAIN_STATS = {
    RIVER_BASIN: (5, 3, 0.8),
    PLAINS: (3, 3, 0.7),
    MOUNTAINS: (1, 1, 1.4),
    DESERT: (1, 1, 1.0),
    JUNGLE: (3, 1, 1.1),
    COASTLINE: (3, 4, 0.8),
    TUNDRA: (1, 1, 1.0),
}

# New regions: (id, name, terrain, population, adjacency_list)
NEW_REGIONS = [
    # Group A: Northern Tundra (36-44)
    (36, "Frost Spire", MOUNTAINS, 400, [0, 37, 38]),
    (37, "Snow Pass", TUNDRA, 300, [36, 38, 39]),
    (38, "Ice Crown", TUNDRA, 250, [36, 37, 40]),
    (39, "Frozen Reach", TUNDRA, 200, [37, 41, 42]),
    (40, "Glacial Valley", TUNDRA, 350, [38, 41, 43]),
    (41, "White Wastes", TUNDRA, 200, [39, 40, 42, 43]),
    (42, "Northern Barrens", TUNDRA, 250, [39, 41, 44]),
    (43, "Permafrost Steppe", TUNDRA, 150, [40, 41, 112]),
    (44, "Wind Howl", MOUNTAINS, 500, [42, 1]),

    # Group B: Eastern Desert Extension (45-54)
    (45, "Copper Canyon", DESERT, 350, [7, 46, 47]),
    (46, "Scorpion Wastes", DESERT, 250, [45, 47, 48]),
    (47, "Sandstone Arch", DESERT, 300, [45, 46, 49]),
    (48, "Dried Riverbed", DESERT, 400, [46, 50, 10]),
    (49, "Storm Flats", DESERT, 200, [47, 51, 52]),
    (50, "Obsidian Sands", DESERT, 350, [48, 51, 14]),
    (51, "Eastern Dunes", DESERT, 300, [49, 50, 52, 53]),
    (52, "Mirage Lake", DESERT, 250, [49, 51, 54]),
    (53, "Cactus Ridge", DESERT, 300, [51, 54]),
    (54, "Sunbaked Wastes", DESERT, 200, [52, 53, 103]),

    # Group C: Western Foothills (55-62)
    (55, "Western Ridge", MOUNTAINS, 500, [6, 56, 57, 115]),
    (56, "Pine Valley", PLAINS, 1200, [55, 57, 58]),
    (57, "Wolf Den", MOUNTAINS, 400, [55, 56, 59]),
    (58, "Shepherd's Field", PLAINS, 1500, [56, 59, 60, 30]),
    (59, "Hawk Perch", MOUNTAINS, 350, [57, 58, 61]),
    (60, "Wildflower Meadow", PLAINS, 1400, [58, 61, 62]),
    (61, "Mossy Bluff", JUNGLE, 800, [59, 60, 62]),
    (62, "Vine Hollow", JUNGLE, 700, [60, 61, 96]),

    # Group D: Central River Extension (63-72)
    (63, "Mudflat Reach", RIVER_BASIN, 2000, [17, 64, 65]),
    (64, "Oxbow Lake", RIVER_BASIN, 2200, [63, 65, 66]),
    (65, "Willow Creek", RIVER_BASIN, 1800, [63, 64, 67]),
    (66, "Harvest Plain", PLAINS, 1600, [64, 68, 20]),
    (67, "Cattail Marsh", RIVER_BASIN, 1900, [65, 68, 69]),
    (68, "Breadbasket", PLAINS, 1700, [66, 67, 69, 70]),
    (69, "Lazy Bend", RIVER_BASIN, 2100, [67, 68, 70, 71]),
    (70, "Fisher's Cross", RIVER_BASIN, 2300, [68, 69, 71, 72]),
    (71, "Heron Lake", RIVER_BASIN, 2000, [69, 70, 72, 21]),
    (72, "Tall Reeds", PLAINS, 1400, [70, 71, 32]),

    # Group E: Jungle Belt (73-82)
    (73, "Emerald Canopy", JUNGLE, 800, [19, 74, 75]),
    (74, "Serpent's Trail", JUNGLE, 600, [73, 75, 76]),
    (75, "Ancient Grove", JUNGLE, 900, [73, 74, 77]),
    (76, "Parrot Ridge", JUNGLE, 500, [74, 78, 13]),
    (77, "Monsoon Basin", JUNGLE, 1000, [75, 78, 79]),
    (78, "Orchid Falls", JUNGLE, 750, [76, 77, 79, 80]),
    (79, "Bamboo Thicket", JUNGLE, 650, [77, 78, 80, 81]),
    (80, "Hidden Temple", JUNGLE, 400, [78, 79, 81]),
    (81, "Fern Gully", JUNGLE, 550, [79, 80, 82]),
    (82, "Jungle's Edge", PLAINS, 1100, [81, 33, 88]),

    # Group F: Extended Coastline (83-92)
    (83, "Lighthouse Point", COASTLINE, 1100, [27, 84, 85]),
    (84, "Fisherman's Wharf", COASTLINE, 1300, [83, 85, 86]),
    (85, "Seagull Cliffs", COASTLINE, 900, [83, 84, 87]),
    (86, "Lagoon Shore", COASTLINE, 1200, [84, 87, 29]),
    (87, "Mangrove Swamp", COASTLINE, 700, [85, 86, 89]),
    (88, "Smuggler's Cove", COASTLINE, 1000, [82, 89, 90, 95]),
    (89, "Turquoise Bay", COASTLINE, 1400, [87, 88, 90, 91]),
    (90, "Whale Rock", COASTLINE, 800, [88, 89, 91, 92]),
    (91, "Sunset Harbor", COASTLINE, 1500, [89, 90, 92]),
    (92, "Far Reach Port", COASTLINE, 600, [90, 91]),

    # Group G: Southern Plains & Frontier (93-102)
    (93, "Windswept Savanna", PLAINS, 1300, [34, 94, 95]),
    (94, "Buffalo Range", PLAINS, 1100, [93, 95, 96]),
    (95, "Dry Creek", PLAINS, 1000, [93, 94, 97, 88]),
    (96, "Frontier Post", PLAINS, 1200, [62, 94, 97, 98]),
    (97, "Sunset Bluffs", PLAINS, 900, [95, 96, 98, 99]),
    (98, "Badlands", DESERT, 400, [96, 97, 99, 100]),
    (99, "Dust Devil Pass", DESERT, 350, [97, 98, 100, 101]),
    (100, "Coyote Gulch", PLAINS, 800, [98, 99, 101, 102]),
    (101, "Mesa Heights", MOUNTAINS, 500, [99, 100, 102]),
    (102, "Twin Buttes", PLAINS, 700, [100, 101, 35]),

    # Group H: Far Eastern Oasis (103-111)
    (103, "Silk Road", DESERT, 300, [54, 104, 105]),
    (104, "Hidden Oasis", RIVER_BASIN, 1500, [103, 105, 106]),
    (105, "Caravan Rest", DESERT, 350, [103, 104, 107]),
    (106, "Palm Springs", RIVER_BASIN, 1200, [104, 107, 108]),
    (107, "Nomad's Crossing", DESERT, 250, [105, 106, 108, 109]),
    (108, "Sandstorm Ridge", DESERT, 200, [106, 107, 109, 110]),
    (109, "Distant Sands", DESERT, 180, [107, 108, 111]),
    (110, "Lost Temple", JUNGLE, 350, [108, 111]),
    (111, "Edge of the World", DESERT, 150, [109, 110]),

    # Group I: Northwestern Connection (112-115)
    (112, "Polar Steppe", TUNDRA, 200, [43, 113, 114]),
    (113, "Aurora Watch", TUNDRA, 180, [112, 114, 115]),
    (114, "Crystal Cavern", MOUNTAINS, 400, [112, 113, 115]),
    (115, "Snowdrift Pass", MOUNTAINS, 350, [113, 114, 55]),
]

# Adjacency additions for existing regions: {region_id: [new_neighbor_ids]}
EXISTING_UPDATES = {
    0: [36],
    1: [44],
    6: [55],
    7: [45],
    10: [48],
    13: [76],
    14: [50],
    17: [63],
    19: [73],
    20: [66],
    21: [71],
    27: [83],
    29: [86],
    30: [58],
    32: [72],
    33: [82],
    34: [93],
    35: [102],
}

TRES_TEMPLATE = '''[gd_resource type="Resource" script_class="RegionData" load_steps=2 format=3]

[ext_resource type="Script" path="res://resources/region_data.gd" id="1"]

[resource]
script = ExtResource("1")
id = {id}
region_name = "{name}"
terrain_type = {terrain}
population = {pop}
owner_id = -1
food_yield = {food}
production_yield = {prod}
defense_modifier = {defense}
resource_stock = {{}}
adjacency_list = Array[int]([{adj}])
infrastructure_level = 0
'''


def write_region(region_id, name, terrain, pop, adj):
    food, prod, defense = TERRAIN_STATS[terrain]
    adj_str = ", ".join(str(a) for a in adj)
    content = TRES_TEMPLATE.format(
        id=region_id, name=name, terrain=terrain,
        pop=pop, food=food, prod=prod, defense=defense, adj=adj_str,
    )
    filename = f"region_{region_id:02d}.tres"
    filepath = os.path.join(REGIONS_DIR, filename)
    with open(filepath, "w") as f:
        f.write(content)
    return filename


def update_existing_region(region_id, new_neighbors):
    filename = f"region_{region_id:02d}.tres"
    filepath = os.path.join(REGIONS_DIR, filename)

    with open(filepath, "r") as f:
        content = f.read()

    # Find the adjacency_list line and update it
    import re
    match = re.search(r'adjacency_list = Array\[int\]\(\[([^\]]*)\]\)', content)
    if not match:
        print(f"  WARNING: Could not find adjacency_list in {filename}")
        return

    existing_adj = match.group(1)
    existing_ids = [int(x.strip()) for x in existing_adj.split(",") if x.strip()]
    updated_ids = sorted(set(existing_ids + new_neighbors))
    new_adj_str = ", ".join(str(a) for a in updated_ids)

    new_line = f"adjacency_list = Array[int]([{new_adj_str}])"
    content = content[:match.start()] + new_line + content[match.end():]

    with open(filepath, "w") as f:
        f.write(content)
    print(f"  Updated {filename}: added {new_neighbors} -> [{new_adj_str}]")


def validate_adjacency():
    """Verify all adjacencies are bidirectional."""
    all_regions = {}
    for r in NEW_REGIONS:
        all_regions[r[0]] = r[4]

    errors = 0
    for rid, name, terrain, pop, adj in NEW_REGIONS:
        for neighbor in adj:
            if neighbor in all_regions:
                if rid not in all_regions[neighbor]:
                    print(f"  ERROR: {rid} lists {neighbor} but {neighbor} does not list {rid}")
                    errors += 1
            # Neighbors in existing regions are handled by EXISTING_UPDATES
    return errors


def main():
    print("Epoch Engine Region Generator")
    print("=" * 40)

    # Validate adjacency consistency
    print("\nValidating adjacency...")
    errors = validate_adjacency()
    if errors:
        print(f"  {errors} adjacency errors found! Fix before proceeding.")
        return
    print("  All adjacencies valid.")

    # Write new region files
    print(f"\nWriting {len(NEW_REGIONS)} new region files...")
    for rid, name, terrain, pop, adj in NEW_REGIONS:
        fname = write_region(rid, name, terrain, pop, adj)
        print(f"  {fname}: {name} ({['RB','PL','MT','DS','JG','CL','TN'][terrain]}) pop={pop}")

    # Update existing region adjacencies
    print(f"\nUpdating {len(EXISTING_UPDATES)} existing region files...")
    for rid, new_neighbors in sorted(EXISTING_UPDATES.items()):
        update_existing_region(rid, new_neighbors)

    # Summary stats
    terrain_counts = {}
    terrain_names = {0: "River Basin", 1: "Plains", 2: "Mountains",
                     3: "Desert", 4: "Jungle", 5: "Coastline", 6: "Tundra"}
    total_pop = 0
    for _, _, terrain, pop, _ in NEW_REGIONS:
        terrain_counts[terrain] = terrain_counts.get(terrain, 0) + 1
        total_pop += pop

    print(f"\nSummary:")
    print(f"  New regions: {len(NEW_REGIONS)}")
    print(f"  Total new population: {total_pop:,}")
    for t, count in sorted(terrain_counts.items()):
        print(f"  {terrain_names[t]}: {count}")
    print(f"\n  Grand total regions: 36 + {len(NEW_REGIONS)} = {36 + len(NEW_REGIONS)}")


if __name__ == "__main__":
    main()
