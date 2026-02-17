class_name TerrainDecorations
extends RefCounted

## Procedural terrain decoration builders.
## Creates visual markers (peaks, rivers, trees, etc.) inside region polygons
## as a fallback when no terrain texture is available.

# Terrain decoration colors (semi-transparent)
const DECO_COLOR_MOUNTAIN := Color(0.25, 0.22, 0.18, 0.38)
const DECO_COLOR_RIVER := Color(0.20, 0.35, 0.50, 0.32)
const DECO_COLOR_JUNGLE := Color(0.12, 0.25, 0.10, 0.36)
const DECO_COLOR_DESERT := Color(0.50, 0.42, 0.25, 0.24)
const DECO_COLOR_COAST := Color(0.25, 0.38, 0.50, 0.28)
const DECO_COLOR_TUNDRA := Color(0.55, 0.58, 0.62, 0.26)
const DECO_COLOR_PLAINS := Color(0.35, 0.42, 0.25, 0.26)
const DECO_COLOR_STEPPE := Color(0.50, 0.45, 0.28, 0.22)
const DECO_COLOR_VOLCANIC := Color(0.40, 0.22, 0.15, 0.25)


static func build(
	terrain_type: Enums.TerrainType,
	centroid: Vector2,
	region_id: int,
	parent: Node2D,
) -> void:
	## Build procedural terrain decorations as children of parent node.
	var rng := RandomNumberGenerator.new()
	rng.seed = region_id * 7919  # Deterministic per region

	match terrain_type:
		Enums.TerrainType.MOUNTAINS:
			_draw_mountain_peaks(centroid, rng, parent)
		Enums.TerrainType.RIVER_BASIN:
			_draw_river_lines(centroid, rng, parent)
		Enums.TerrainType.JUNGLE:
			_draw_jungle_dots(centroid, rng, parent)
		Enums.TerrainType.DESERT:
			_draw_desert_stipple(centroid, rng, parent)
		Enums.TerrainType.COASTLINE:
			_draw_coast_waves(centroid, rng, parent)
		Enums.TerrainType.TUNDRA:
			_draw_tundra_marks(centroid, rng, parent)
		Enums.TerrainType.PLAINS:
			_draw_plains_grass(centroid, rng, parent)
		Enums.TerrainType.STEPPE:
			_draw_steppe_grass(centroid, rng, parent)
		Enums.TerrainType.VOLCANIC_RIDGE:
			_draw_volcanic_vents(centroid, rng, parent)


static func _draw_mountain_peaks(
	centroid: Vector2, rng: RandomNumberGenerator, parent: Node2D,
) -> void:
	for i in 5:
		var offset := Vector2(
			rng.randf_range(-35, 35), rng.randf_range(-25, 25)
		)
		var base := centroid + offset
		var peak_h := rng.randf_range(6, 14)
		var peak_w := rng.randf_range(5, 9)

		var peak := Polygon2D.new()
		peak.polygon = PackedVector2Array([
			base + Vector2(0, -peak_h),
			base + Vector2(-peak_w, 0),
			base + Vector2(peak_w, 0),
		])
		peak.color = DECO_COLOR_MOUNTAIN
		parent.add_child(peak)

		# Snow cap on taller peaks
		if peak_h > 10:
			var cap := Polygon2D.new()
			var cap_h := peak_h * 0.35
			var cap_w := peak_w * 0.4
			cap.polygon = PackedVector2Array([
				base + Vector2(0, -peak_h),
				base + Vector2(-cap_w, -peak_h + cap_h),
				base + Vector2(cap_w, -peak_h + cap_h),
			])
			cap.color = Color(0.85, 0.85, 0.90, 0.25)
			parent.add_child(cap)


static func _draw_river_lines(
	centroid: Vector2, rng: RandomNumberGenerator, parent: Node2D,
) -> void:
	for i in 3:
		var y_off := rng.randf_range(-20, 20)
		var line := Line2D.new()
		var pts := PackedVector2Array()
		for x in range(-30, 31, 8):
			var wave := sin(float(x) * 0.15 + float(i)) * 4.0
			pts.append(centroid + Vector2(x, y_off + wave))
		line.points = pts
		line.width = 1.5
		line.default_color = DECO_COLOR_RIVER
		line.antialiased = true
		parent.add_child(line)


static func _draw_jungle_dots(
	centroid: Vector2, rng: RandomNumberGenerator, parent: Node2D,
) -> void:
	for i in 8:
		var offset := Vector2(
			rng.randf_range(-30, 30), rng.randf_range(-22, 22)
		)
		var pos := centroid + offset
		var r := rng.randf_range(2.5, 5.0)

		var circle := Polygon2D.new()
		var circle_pts := PackedVector2Array()
		for j in 8:
			var angle := float(j) * TAU / 8.0
			circle_pts.append(pos + Vector2(cos(angle), sin(angle)) * r)
		circle.polygon = circle_pts
		circle.color = DECO_COLOR_JUNGLE
		parent.add_child(circle)


static func _draw_desert_stipple(
	centroid: Vector2, rng: RandomNumberGenerator, parent: Node2D,
) -> void:
	for i in 12:
		var offset := Vector2(
			rng.randf_range(-32, 32), rng.randf_range(-24, 24)
		)
		var pos := centroid + offset
		var dot := Polygon2D.new()
		var dot_pts := PackedVector2Array()
		for j in 6:
			var angle := float(j) * TAU / 6.0
			dot_pts.append(pos + Vector2(cos(angle), sin(angle)) * 1.5)
		dot.polygon = dot_pts
		dot.color = DECO_COLOR_DESERT
		parent.add_child(dot)


static func _draw_coast_waves(
	centroid: Vector2, rng: RandomNumberGenerator, parent: Node2D,
) -> void:
	for i in 3:
		var y_off := rng.randf_range(-18, 18)
		var x_start := rng.randf_range(-25, -5)
		var line := Line2D.new()
		var pts := PackedVector2Array()
		for x in range(0, 20, 3):
			var wave := sin(float(x) * 0.3) * 3.0
			pts.append(centroid + Vector2(x_start + x, y_off + wave))
		line.points = pts
		line.width = 1.2
		line.default_color = DECO_COLOR_COAST
		line.antialiased = true
		parent.add_child(line)


static func _draw_tundra_marks(
	centroid: Vector2, rng: RandomNumberGenerator, parent: Node2D,
) -> void:
	for i in 5:
		var offset := Vector2(
			rng.randf_range(-28, 28), rng.randf_range(-20, 20)
		)
		var pos := centroid + offset
		for j in 3:
			var angle := float(j) * PI / 3.0
			var line := Line2D.new()
			var d := Vector2(cos(angle), sin(angle)) * 3.0
			line.points = PackedVector2Array([pos - d, pos + d])
			line.width = 1.0
			line.default_color = DECO_COLOR_TUNDRA
			parent.add_child(line)


static func _draw_plains_grass(
	centroid: Vector2, rng: RandomNumberGenerator, parent: Node2D,
) -> void:
	for i in 6:
		var offset := Vector2(
			rng.randf_range(-30, 30), rng.randf_range(-22, 22)
		)
		var base := centroid + offset
		var line := Line2D.new()
		var lean := rng.randf_range(-2, 2)
		line.points = PackedVector2Array([
			base,
			base + Vector2(lean, -rng.randf_range(4, 8)),
		])
		line.width = 1.0
		line.default_color = DECO_COLOR_PLAINS
		parent.add_child(line)


static func _draw_steppe_grass(
	centroid: Vector2, rng: RandomNumberGenerator, parent: Node2D,
) -> void:
	# Sparse diagonal strokes — wider spread than plains, windswept look
	for i in 4:
		var offset := Vector2(
			rng.randf_range(-40, 40), rng.randf_range(-28, 28)
		)
		var base := centroid + offset
		var lean := rng.randf_range(3, 6)
		var line := Line2D.new()
		line.points = PackedVector2Array([
			base,
			base + Vector2(lean, -rng.randf_range(5, 10)),
		])
		line.width = 1.0
		line.default_color = DECO_COLOR_STEPPE
		parent.add_child(line)


static func _draw_volcanic_vents(
	centroid: Vector2, rng: RandomNumberGenerator, parent: Node2D,
) -> void:
	# Dark irregular rock shapes + orange glow dots
	for i in 4:
		var offset := Vector2(
			rng.randf_range(-30, 30), rng.randf_range(-22, 22)
		)
		var pos := centroid + offset
		var rock_size := rng.randf_range(3, 6)
		var sides := rng.randi_range(3, 5)
		var rock := Polygon2D.new()
		var pts := PackedVector2Array()
		for j in sides:
			var angle := float(j) * TAU / float(sides) + rng.randf_range(-0.3, 0.3)
			var r := rock_size * rng.randf_range(0.6, 1.0)
			pts.append(pos + Vector2(cos(angle), sin(angle)) * r)
		rock.polygon = pts
		rock.color = DECO_COLOR_VOLCANIC
		parent.add_child(rock)

	# Orange vent glow dots
	for i in 3:
		var offset := Vector2(
			rng.randf_range(-20, 20), rng.randf_range(-15, 15)
		)
		var pos := centroid + offset
		var dot := Polygon2D.new()
		var dot_pts := PackedVector2Array()
		for j in 6:
			var angle := float(j) * TAU / 6.0
			dot_pts.append(pos + Vector2(cos(angle), sin(angle)) * 1.8)
		dot.polygon = dot_pts
		dot.color = Color(0.85, 0.45, 0.15, 0.20)
		parent.add_child(dot)
