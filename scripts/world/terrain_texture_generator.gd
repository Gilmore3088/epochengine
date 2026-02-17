class_name TerrainTextureGenerator
extends RefCounted

## Generates procedural terrain textures using FastNoiseLite.
## Called once per terrain type on first access, then cached for the session.

static var _cache: Dictionary = {}

const TEX_SIZE := 256


static func get_texture(terrain_type: int) -> ImageTexture:
	if _cache.has(terrain_type):
		return _cache[terrain_type]
	var tex := _generate(terrain_type)
	_cache[terrain_type] = tex
	return tex


static func _generate(terrain_type: int) -> ImageTexture:
	var image := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)

	var noise := FastNoiseLite.new()
	noise.seed = terrain_type * 7919
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = _get_frequency(terrain_type)

	# Second noise layer for detail
	var detail := FastNoiseLite.new()
	detail.seed = terrain_type * 7919 + 31337
	detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	detail.frequency = _get_frequency(terrain_type) * 3.0

	var base_color: Color = _get_base_color(terrain_type)
	var contrast := _get_contrast(terrain_type)

	for x in TEX_SIZE:
		for y in TEX_SIZE:
			var n := noise.get_noise_2d(float(x), float(y))
			var d := detail.get_noise_2d(float(x), float(y)) * 0.3
			var brightness := 0.85 + (n + d) * contrast
			var c := Color(
				clampf(base_color.r * brightness, 0.0, 1.0),
				clampf(base_color.g * brightness, 0.0, 1.0),
				clampf(base_color.b * brightness, 0.0, 1.0),
				1.0
			)
			image.set_pixel(x, y, c)

	return ImageTexture.create_from_image(image)


static func _get_base_color(terrain_type: int) -> Color:
	# Use terrain tint colors from RegionVisual as base
	var tints := {
		0: Color(0.32, 0.48, 0.28),  # RIVER_BASIN
		1: Color(0.52, 0.52, 0.34),  # PLAINS
		2: Color(0.42, 0.38, 0.32),  # MOUNTAINS
		3: Color(0.62, 0.56, 0.36),  # DESERT
		4: Color(0.22, 0.38, 0.20),  # JUNGLE
		5: Color(0.35, 0.45, 0.50),  # COASTLINE
		6: Color(0.52, 0.55, 0.58),  # TUNDRA
		7: Color(0.55, 0.50, 0.35),  # STEPPE
		8: Color(0.38, 0.30, 0.28),  # VOLCANIC_RIDGE
	}
	return tints.get(terrain_type, Color(0.5, 0.5, 0.5))


static func _get_frequency(terrain_type: int) -> float:
	match terrain_type:
		2: return 0.04    # Mountains — rough, rocky
		3: return 0.02    # Desert — smooth dunes
		4: return 0.05    # Jungle — dense canopy
		6: return 0.015   # Tundra — flat expanses
		8: return 0.045   # Volcanic — harsh terrain
		_: return 0.03    # Default


static func _get_contrast(terrain_type: int) -> float:
	match terrain_type:
		2: return 0.25    # Mountains — high contrast
		3: return 0.12    # Desert — subtle
		4: return 0.20    # Jungle — moderate
		6: return 0.08    # Tundra — very flat
		8: return 0.30    # Volcanic — dramatic
		_: return 0.15    # Default
