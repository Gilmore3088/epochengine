class_name TerrainDecorations
extends RefCounted

## Procedural terrain decoration builders.
## Creates connected, organic terrain features inside region polygons:
## mountain ridgelines, tree canopy clusters, dune lines, etc.
## Fallback for when no terrain texture is available.

# Terrain decoration colors
const COL_MOUNTAIN := Color(0.30, 0.26, 0.22, 0.45)
const COL_MOUNTAIN_SHADOW := Color(0.15, 0.12, 0.10, 0.25)
const COL_SNOW := Color(0.85, 0.85, 0.90, 0.30)
const COL_RIVER := Color(0.20, 0.38, 0.55, 0.35)
const COL_JUNGLE := Color(0.12, 0.30, 0.10, 0.40)
const COL_JUNGLE_SHADOW := Color(0.06, 0.15, 0.05, 0.25)
const COL_DESERT := Color(0.55, 0.45, 0.28, 0.28)
const COL_DESERT_OASIS := Color(0.20, 0.45, 0.18, 0.35)
const COL_COAST := Color(0.30, 0.45, 0.58, 0.28)
const COL_COAST_FOAM := Color(0.80, 0.85, 0.90, 0.22)
const COL_TUNDRA_ICE := Color(0.78, 0.82, 0.88, 0.30)
const COL_TUNDRA_ROCK := Color(0.42, 0.40, 0.38, 0.28)
const COL_TUNDRA_CRACK := Color(0.35, 0.50, 0.62, 0.22)
const COL_PLAINS := Color(0.35, 0.45, 0.25, 0.28)
const COL_STEPPE := Color(0.50, 0.45, 0.28, 0.24)
const COL_VOLCANIC := Color(0.40, 0.22, 0.15, 0.30)
const COL_LAVA := Color(0.85, 0.40, 0.12, 0.25)
const COL_STEAM := Color(0.65, 0.65, 0.68, 0.18)


static func build(
	terrain_type: Enums.TerrainType,
	centroid: Vector2,
	region_id: int,
	parent: Node2D,
	density: float = 1.0,
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = region_id * 7919

	match terrain_type:
		Enums.TerrainType.MOUNTAINS:
			_draw_mountain_ridgelines(centroid, rng, parent, density)
		Enums.TerrainType.RIVER_BASIN:
			_draw_tributaries(centroid, rng, parent, density)
		Enums.TerrainType.JUNGLE:
			_draw_canopy_clusters(centroid, rng, parent, density)
		Enums.TerrainType.DESERT:
			_draw_dune_lines(centroid, rng, parent, density)
		Enums.TerrainType.COASTLINE:
			_draw_shore_waves(centroid, rng, parent, density)
		Enums.TerrainType.TUNDRA:
			_draw_ice_patches(centroid, rng, parent, density)
		Enums.TerrainType.PLAINS:
			_draw_grass_clusters(centroid, rng, parent, density)
		Enums.TerrainType.STEPPE:
			_draw_windswept_grass(centroid, rng, parent, density)
		Enums.TerrainType.VOLCANIC_RIDGE:
			_draw_crater_lava(centroid, rng, parent, density)


static func _draw_mountain_ridgelines(
	centroid: Vector2, rng: RandomNumberGenerator, parent: Node2D,
	density: float = 1.0,
) -> void:
	## Connected mountain chain: ridge line with peaks rising from it.
	var ridge_count := maxi(1, int(2 * density))
	for r in ridge_count:
		var y_off := rng.randf_range(-20, 20)
		var ridge_start := centroid + Vector2(-35, y_off)
		var ridge_pts := PackedVector2Array()
		var peak_count := rng.randi_range(3, 5)

		# Build ridge path (gentle curve)
		for i in peak_count + 1:
			var t := float(i) / float(peak_count)
			var x_pos := lerpf(ridge_start.x, ridge_start.x + 70, t)
			var y_pos := ridge_start.y + sin(t * PI * 1.5) * 8.0 + rng.randf_range(-3, 3)
			ridge_pts.append(Vector2(x_pos, y_pos))

		# Shadow line (offset SE)
		var shadow := Line2D.new()
		var shadow_pts := PackedVector2Array()
		for p in ridge_pts:
			shadow_pts.append(p + Vector2(2, 3))
		shadow.points = shadow_pts
		shadow.width = 2.5
		shadow.default_color = COL_MOUNTAIN_SHADOW
		shadow.antialiased = true
		parent.add_child(shadow)

		# Main ridge line
		var ridge := Line2D.new()
		ridge.points = ridge_pts
		ridge.width = 2.0
		ridge.default_color = COL_MOUNTAIN
		ridge.antialiased = true
		parent.add_child(ridge)

		# Peaks rising from ridge
		for i in peak_count:
			var t := (float(i) + 0.5) / float(peak_count)
			var base_x := lerpf(ridge_start.x, ridge_start.x + 70, t)
			var base_y := ridge_start.y + sin(t * PI * 1.5) * 8.0
			var peak_h := rng.randf_range(8, 16)
			var peak_w := rng.randf_range(5, 9)
			var base_pos := Vector2(base_x, base_y)

			var peak := Polygon2D.new()
			peak.polygon = PackedVector2Array([
				base_pos + Vector2(0, -peak_h),
				base_pos + Vector2(-peak_w, 2),
				base_pos + Vector2(peak_w, 2),
			])
			peak.color = COL_MOUNTAIN
			parent.add_child(peak)

			# Snow cap on tall peaks
			if peak_h > 11:
				var cap := Polygon2D.new()
				var cap_h := peak_h * 0.35
				var cap_w := peak_w * 0.4
				cap.polygon = PackedVector2Array([
					base_pos + Vector2(0, -peak_h),
					base_pos + Vector2(-cap_w, -peak_h + cap_h),
					base_pos + Vector2(cap_w, -peak_h + cap_h),
				])
				cap.color = COL_SNOW
				parent.add_child(cap)


static func _draw_canopy_clusters(
	centroid: Vector2, rng: RandomNumberGenerator, parent: Node2D,
	density: float = 1.0,
) -> void:
	## Tree canopy clusters with shadows -- Poisson-like placement.
	var cluster_count := maxi(2, int(5 * density))
	var placed: Array[Vector2] = []

	for _i in cluster_count * 3:  # Try more, accept fewer (rejection sampling)
		if placed.size() >= cluster_count:
			break
		var offset := Vector2(rng.randf_range(-30, 30), rng.randf_range(-22, 22))
		var pos := centroid + offset

		# Reject if too close to another cluster
		var too_close := false
		for p in placed:
			if pos.distance_to(p) < 12.0:
				too_close = true
				break
		if too_close:
			continue
		placed.append(pos)

		var tree_count := rng.randi_range(3, 5)
		for t in tree_count:
			var tree_off := Vector2(rng.randf_range(-6, 6), rng.randf_range(-5, 5))
			var tree_pos := pos + tree_off
			var radius := rng.randf_range(3.0, 5.5)

			# Shadow underneath
			var shadow := _make_circle(tree_pos + Vector2(1.5, 2.0), radius * 0.9, 8)
			shadow.color = COL_JUNGLE_SHADOW
			parent.add_child(shadow)

			# Canopy circle
			var canopy := _make_circle(tree_pos, radius, 8)
			canopy.color = Color(
				COL_JUNGLE.r + rng.randf_range(-0.03, 0.03),
				COL_JUNGLE.g + rng.randf_range(-0.04, 0.04),
				COL_JUNGLE.b + rng.randf_range(-0.02, 0.02),
				COL_JUNGLE.a,
			)
			parent.add_child(canopy)


static func _draw_dune_lines(
	centroid: Vector2, rng: RandomNumberGenerator, parent: Node2D,
	density: float = 1.0,
) -> void:
	## Parallel curved dune lines with consistent wind direction.
	var dune_count := maxi(2, int(4 * density))
	var wind_angle := 0.4  # NW-SE consistent direction

	for i in dune_count:
		var y_off := rng.randf_range(-25, 25)
		var line := Line2D.new()
		var pts := PackedVector2Array()
		var width := rng.randf_range(1.0, 2.0)

		for x in range(-35, 36, 5):
			var wave := sin(float(x) * 0.08 + float(i) * 1.5) * 5.0
			var px := float(x) * cos(wind_angle) - wave * sin(wind_angle)
			var py := float(x) * sin(wind_angle) + wave * cos(wind_angle)
			pts.append(centroid + Vector2(px, y_off + py))

		line.points = pts
		line.width = width
		line.default_color = COL_DESERT
		line.antialiased = true
		parent.add_child(line)

	# Occasional oasis (1 in 4 desert regions)
	if rng.randf() < 0.25:
		var oasis_pos := centroid + Vector2(rng.randf_range(-15, 15), rng.randf_range(-10, 10))
		var oasis := _make_circle(oasis_pos, 3.5, 8)
		oasis.color = COL_DESERT_OASIS
		parent.add_child(oasis)


static func _draw_tributaries(
	centroid: Vector2, rng: RandomNumberGenerator, parent: Node2D,
	density: float = 1.0,
) -> void:
	## Thin tributary lines converging toward centroid + lush patches.
	var trib_count := maxi(1, int(3 * density))

	for i in trib_count:
		var angle := rng.randf_range(0, TAU)
		var start := centroid + Vector2(cos(angle), sin(angle)) * rng.randf_range(20, 35)
		var line := Line2D.new()
		var pts := PackedVector2Array()
		var steps := 6

		for s in steps + 1:
			var t := float(s) / float(steps)
			var pos := start.lerp(centroid, t)
			pos += Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))
			pts.append(pos)

		line.points = pts
		line.width = 1.2
		line.default_color = COL_RIVER
		line.antialiased = true
		parent.add_child(line)

	# Green vegetation patches near water
	for _i in maxi(1, int(3 * density)):
		var off := Vector2(rng.randf_range(-18, 18), rng.randf_range(-14, 14))
		var patch := _make_circle(centroid + off, rng.randf_range(2.5, 4.5), 6)
		patch.color = Color(0.25, 0.45, 0.20, 0.20)
		parent.add_child(patch)


static func _draw_shore_waves(
	centroid: Vector2, rng: RandomNumberGenerator, parent: Node2D,
	density: float = 1.0,
) -> void:
	## Concentric arc-like waves + foam + scattered rocks.
	var wave_count := maxi(1, int(3 * density))

	for i in wave_count:
		var y_off := rng.randf_range(-15, 15)
		var x_start := rng.randf_range(-20, -5)
		var line := Line2D.new()
		var pts := PackedVector2Array()

		for x in range(0, 22, 3):
			var wave := sin(float(x) * 0.35 + float(i) * 0.8) * 3.5
			pts.append(centroid + Vector2(x_start + x, y_off + wave))

		line.points = pts
		line.width = 1.5
		line.default_color = COL_COAST
		line.antialiased = true
		parent.add_child(line)

		# Foam highlight (thinner, lighter)
		var foam := Line2D.new()
		var foam_pts := PackedVector2Array()
		for p in pts:
			foam_pts.append(p + Vector2(0, -1.5))
		foam.points = foam_pts
		foam.width = 0.8
		foam.default_color = COL_COAST_FOAM
		foam.antialiased = true
		parent.add_child(foam)

	# Scattered rock dots along shore
	for _i in maxi(1, int(4 * density)):
		var rpos := centroid + Vector2(rng.randf_range(-25, 25), rng.randf_range(-18, 18))
		var rock := _make_circle(rpos, rng.randf_range(1.0, 2.0), 5)
		rock.color = Color(0.40, 0.38, 0.35, 0.30)
		parent.add_child(rock)


static func _draw_ice_patches(
	centroid: Vector2, rng: RandomNumberGenerator, parent: Node2D,
	density: float = 1.0,
) -> void:
	## Irregular ice/snow patches + grey rocks + blue cracks.
	# Ice patches (irregular white blobs)
	for _i in maxi(1, int(3 * density)):
		var off := Vector2(rng.randf_range(-28, 28), rng.randf_range(-20, 20))
		var pos := centroid + off
		var sides := rng.randi_range(5, 7)
		var patch := Polygon2D.new()
		var pts := PackedVector2Array()
		for j in sides:
			var angle := float(j) * TAU / float(sides) + rng.randf_range(-0.4, 0.4)
			var r := rng.randf_range(3.0, 6.0)
			pts.append(pos + Vector2(cos(angle), sin(angle)) * r)
		patch.polygon = pts
		patch.color = COL_TUNDRA_ICE
		parent.add_child(patch)

	# Grey rock clusters
	for _i in maxi(1, int(3 * density)):
		var off := Vector2(rng.randf_range(-25, 25), rng.randf_range(-18, 18))
		var rock := _make_circle(centroid + off, rng.randf_range(1.5, 3.0), 6)
		rock.color = COL_TUNDRA_ROCK
		parent.add_child(rock)

	# Ice cracks (thin blue lines)
	for _i in maxi(1, int(2 * density)):
		var start := centroid + Vector2(rng.randf_range(-22, 22), rng.randf_range(-16, 16))
		var crack := Line2D.new()
		var pts := PackedVector2Array()
		var segs := rng.randi_range(3, 5)
		pts.append(start)
		for s in segs:
			var prev: Vector2 = pts[pts.size() - 1]
			var dir := Vector2(rng.randf_range(-6, 6), rng.randf_range(-4, 4))
			pts.append(prev + dir)
		crack.points = pts
		crack.width = 0.8
		crack.default_color = COL_TUNDRA_CRACK
		crack.antialiased = true
		parent.add_child(crack)


static func _draw_grass_clusters(
	centroid: Vector2, rng: RandomNumberGenerator, parent: Node2D,
	density: float = 1.0,
) -> void:
	## Grass blade clusters + occasional single tree.
	var cluster_count := maxi(2, int(5 * density))

	for _i in cluster_count:
		var cluster_pos := centroid + Vector2(
			rng.randf_range(-30, 30), rng.randf_range(-22, 22)
		)
		var blade_count := rng.randi_range(3, 5)
		for _b in blade_count:
			var base := cluster_pos + Vector2(rng.randf_range(-3, 3), rng.randf_range(-2, 2))
			var lean := rng.randf_range(-2, 2)
			var height := rng.randf_range(5, 9)
			var line := Line2D.new()
			line.points = PackedVector2Array([base, base + Vector2(lean, -height)])
			line.width = 0.8
			line.default_color = COL_PLAINS
			line.antialiased = true
			parent.add_child(line)

	# Occasional single tree (1 in 3 plains regions)
	if rng.randf() < 0.33:
		var tree_pos := centroid + Vector2(rng.randf_range(-15, 15), rng.randf_range(-10, 10))
		# Trunk
		var trunk := Line2D.new()
		trunk.points = PackedVector2Array([tree_pos, tree_pos + Vector2(0, -8)])
		trunk.width = 1.2
		trunk.default_color = Color(0.35, 0.28, 0.18, 0.30)
		parent.add_child(trunk)
		# Canopy
		var canopy := _make_circle(tree_pos + Vector2(0, -10), 4.0, 7)
		canopy.color = Color(0.25, 0.40, 0.18, 0.32)
		parent.add_child(canopy)


static func _draw_windswept_grass(
	centroid: Vector2, rng: RandomNumberGenerator, parent: Node2D,
	density: float = 1.0,
) -> void:
	## Long diagonal strokes in consistent wind direction.
	var stroke_count := maxi(2, int(4 * density))
	var wind_dir := Vector2(1.0, -0.4).normalized()  # Consistent wind direction

	for _i in stroke_count:
		var base := centroid + Vector2(
			rng.randf_range(-40, 40), rng.randf_range(-28, 28)
		)
		var length := rng.randf_range(8, 14)
		var line := Line2D.new()
		line.points = PackedVector2Array([base, base + wind_dir * length])
		line.width = 0.8
		line.default_color = COL_STEPPE
		line.antialiased = true
		parent.add_child(line)


static func _draw_crater_lava(
	centroid: Vector2, rng: RandomNumberGenerator, parent: Node2D,
	density: float = 1.0,
) -> void:
	## Central crater ring with radial lava lines + steam vents.
	var crater_pos := centroid + Vector2(rng.randf_range(-8, 8), rng.randf_range(-6, 6))

	# Crater ring (arc of small dots)
	var crater_radius := rng.randf_range(8, 12)
	var ring_count := maxi(6, int(10 * density))
	for i in ring_count:
		var angle := float(i) / float(ring_count) * TAU + rng.randf_range(-0.2, 0.2)
		var dot_pos := crater_pos + Vector2(cos(angle), sin(angle)) * crater_radius
		var dot := _make_circle(dot_pos, 1.5, 5)
		dot.color = COL_VOLCANIC
		parent.add_child(dot)

	# Radial lava lines from crater
	var lava_count := maxi(2, int(4 * density))
	for _i in lava_count:
		var angle := rng.randf_range(0, TAU)
		var length := rng.randf_range(15, 30)
		var start := crater_pos + Vector2(cos(angle), sin(angle)) * crater_radius
		var line := Line2D.new()
		var pts := PackedVector2Array()
		var segs := 4
		pts.append(start)
		for s in segs:
			var prev: Vector2 = pts[pts.size() - 1]
			var dir := Vector2(cos(angle), sin(angle)) * (length / float(segs))
			dir += Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))
			pts.append(prev + dir)
		line.points = pts
		line.width = 1.5
		line.default_color = COL_LAVA
		line.antialiased = true
		parent.add_child(line)

	# Steam vent circles
	for _i in maxi(1, int(3 * density)):
		var off := Vector2(rng.randf_range(-18, 18), rng.randf_range(-14, 14))
		var vent := _make_circle(crater_pos + off, rng.randf_range(2.0, 3.5), 6)
		vent.color = COL_STEAM
		parent.add_child(vent)


# --- Helpers ---

static func _make_circle(pos: Vector2, radius: float, segments: int) -> Polygon2D:
	var circle := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in segments:
		var angle := float(i) * TAU / float(segments)
		pts.append(pos + Vector2(cos(angle), sin(angle)) * radius)
	circle.polygon = pts
	return circle
