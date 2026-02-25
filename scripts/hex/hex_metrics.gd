class_name HexMetrics
extends RefCounted

## Hex grid metrics and coordinate helpers (pointy-top axial).

static var outer_radius: float = 18.0
static var inner_radius: float = outer_radius * 0.8660254

static func set_size(radius: float) -> void:
	outer_radius = radius
	inner_radius = outer_radius * 0.8660254

static func axial_to_world(q: int, r: int) -> Vector2:
	var x := outer_radius * sqrt(3.0) * (float(q) + float(r) * 0.5)
	var y := outer_radius * 1.5 * float(r)
	return Vector2(x, y)

static func world_to_axial(pos: Vector2) -> Vector2:
	# Inverse of axial_to_world for pointy-top axial coordinates.
	var q := (sqrt(3.0) / 3.0 * pos.x - 1.0 / 3.0 * pos.y) / outer_radius
	var r := (2.0 / 3.0 * pos.y) / outer_radius
	return Vector2(q, r)

static func corner(offset: int) -> Vector2:
	var angle := TAU * (float(offset) + 0.5) / 6.0
	return Vector2(cos(angle), sin(angle)) * outer_radius

static func corners() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		pts.append(corner(i))
	return pts

static func neighbor_directions() -> Array[Vector2i]:
	# Axial coordinates for pointy-top hexes.
	return [
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
	]

static func axial_distance(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	return int((abs(dq) + abs(dq + dr) + abs(dr)) / 2)
