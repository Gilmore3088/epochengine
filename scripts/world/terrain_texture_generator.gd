class_name TerrainTextureGenerator
extends RefCounted

## Generates procedural terrain textures using multi-pass FastNoiseLite.
## Each terrain type has a distinct visual identity: mountains have ridgelines,
## deserts have dune lines, jungles have canopy clusters, etc.
## Supports era-specific styles: Prehistoric (blobby/rough) through Future (sharp/satellite).
## Cached per terrain_type + era combination for the session.

static var _cache: Dictionary = {}

const TEX_SIZE := 512
const DETAIL_TEX_SIZE := 256
const URBAN_TEX_SIZE := 256

# Per-terrain color palettes: [dark, mid, light] — separated hues, readable at distance
const PALETTES := {
	0: [Color(0.22, 0.48, 0.32), Color(0.34, 0.62, 0.42), Color(0.52, 0.78, 0.56)],  # RIVER_BASIN: cool lush green
	1: [Color(0.40, 0.50, 0.30), Color(0.56, 0.62, 0.38), Color(0.72, 0.74, 0.48)],  # PLAINS: warm olive
	2: [Color(0.36, 0.34, 0.30), Color(0.52, 0.50, 0.46), Color(0.78, 0.78, 0.80)],  # MOUNTAINS: muted brown/grey
	3: [Color(0.78, 0.66, 0.44), Color(0.88, 0.78, 0.56), Color(0.95, 0.88, 0.68)],  # DESERT: warm sand
	4: [Color(0.12, 0.32, 0.18), Color(0.20, 0.46, 0.26), Color(0.34, 0.62, 0.38)],  # JUNGLE: deep cool green
	5: [Color(0.70, 0.66, 0.52), Color(0.46, 0.60, 0.70), Color(0.22, 0.45, 0.70)],  # COASTLINE: sand to blue
	6: [Color(0.52, 0.58, 0.64), Color(0.70, 0.76, 0.82), Color(0.90, 0.94, 0.96)],  # TUNDRA: blue-grey ice
	7: [Color(0.52, 0.44, 0.28), Color(0.68, 0.58, 0.38), Color(0.82, 0.72, 0.50)],  # STEPPE: dry brown-khaki
	8: [Color(0.20, 0.18, 0.18), Color(0.38, 0.28, 0.24), Color(0.85, 0.45, 0.18)],  # VOLCANIC: dark to lava
}


static func get_texture(terrain_type: int) -> ImageTexture:
	## Legacy accessor -- returns Industrial-era texture (era 2).
	return get_texture_for_era(terrain_type, 2)


static func get_fog_texture(era: int) -> ImageTexture:
	## Returns a noise-based fog texture for the given era.
	## Uses cache keys 100+ to avoid collision with terrain types.
	var cache_key := 100 + era
	if _cache.has(cache_key):
		return _cache[cache_key]
	var tex := _generate_fog(era)
	_cache[cache_key] = tex
	return tex


static func _generate_fog(era: int) -> ImageTexture:
	## Generate a 512x512 noise fog texture with 3 layers (cloud, wisp, grain).
	## Per-era color pairs: warm brown parchment → dark blue-grey.
	var image := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)

	# Per-era dark/light fog color pairs
	var fog_dark: Color
	var fog_light: Color
	match era:
		0:  # Prehistoric: warm brown parchment
			fog_dark = Color(0.18, 0.15, 0.10)
			fog_light = Color(0.32, 0.28, 0.20)
		1:  # Classical: aged paper
			fog_dark = Color(0.15, 0.13, 0.10)
			fog_light = Color(0.28, 0.25, 0.18)
		2:  # Industrial: cool grey-brown
			fog_dark = Color(0.13, 0.12, 0.10)
			fog_light = Color(0.25, 0.22, 0.18)
		_:  # Future: dark blue-grey
			fog_dark = Color(0.07, 0.09, 0.13)
			fog_light = Color(0.15, 0.17, 0.22)

	# Cloud layer: large rolling fog banks
	var cloud := _make_noise(era * 31337, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.006)
	# Wisp layer: medium tendrils
	var wisp := _make_noise(era * 31337 + 500, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.018)
	# Grain layer: fine parchment texture
	var grain := _make_noise(era * 31337 + 1000, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.045)

	for x in TEX_SIZE:
		for y in TEX_SIZE:
			var c_val := cloud.get_noise_2d(float(x), float(y))
			var w_val := wisp.get_noise_2d(float(x), float(y))
			var g_val := grain.get_noise_2d(float(x), float(y))
			# Combine: 55% cloud, 30% wisp, 15% grain
			var combined := (c_val * 0.55 + w_val * 0.30 + g_val * 0.15 + 1.0) * 0.5
			combined = clampf(combined, 0.0, 1.0)
			var c := fog_dark.lerp(fog_light, combined)
			image.set_pixel(x, y, c)

	return ImageTexture.create_from_image(image)


static func get_texture_for_era(terrain_type: int, era: int) -> ImageTexture:
	var cache_key := terrain_type * 10 + era
	if _cache.has(cache_key):
		return _cache[cache_key]
	var tex := _generate(terrain_type, era)
	_cache[cache_key] = tex
	return tex


static func get_detail_texture(terrain_type: int, era: int) -> ImageTexture:
	var cache_key := 1000 + terrain_type * 10 + era
	if _cache.has(cache_key):
		return _cache[cache_key]
	var tex := _generate_detail(terrain_type, era)
	_cache[cache_key] = tex
	return tex


static func get_urban_texture(density: int) -> ImageTexture:
	var cache_key := 2000 + density
	if _cache.has(cache_key):
		return _cache[cache_key]
	var tex := _generate_urban(density)
	_cache[cache_key] = tex
	return tex


static func _generate(terrain_type: int, era: int = 2) -> ImageTexture:
	var image := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)

	var era_params: Dictionary = Constants.ERA_VISUAL_PARAMS.get(era, Constants.ERA_VISUAL_PARAMS[2])
	var freq_mult: float = era_params["noise_frequency_mult"]
	var contrast_mult: float = era_params["noise_contrast_mult"]

	# Prehistoric smudge layer
	var smudge: FastNoiseLite = null
	if era == 0:
		smudge = FastNoiseLite.new()
		smudge.seed = terrain_type * 7919 + 99991
		smudge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		smudge.frequency = 0.004

	match terrain_type:
		0: _gen_river_basin(image, freq_mult, contrast_mult, smudge)
		1: _gen_plains(image, freq_mult, contrast_mult, smudge)
		2: _gen_mountains(image, freq_mult, contrast_mult, smudge)
		3: _gen_desert(image, freq_mult, contrast_mult, smudge)
		4: _gen_jungle(image, freq_mult, contrast_mult, smudge)
		5: _gen_coastline(image, freq_mult, contrast_mult, smudge)
		6: _gen_tundra(image, freq_mult, contrast_mult, smudge)
		7: _gen_steppe(image, freq_mult, contrast_mult, smudge)
		8: _gen_volcanic(image, freq_mult, contrast_mult, smudge)
		_: _gen_default(image, terrain_type, freq_mult, contrast_mult, smudge)

	_apply_grain(image, terrain_type, era, freq_mult)

	return ImageTexture.create_from_image(image)


static func _generate_detail(terrain_type: int, era: int) -> ImageTexture:
	var image := Image.create(DETAIL_TEX_SIZE, DETAIL_TEX_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	var freq_mult: float = Constants.ERA_VISUAL_PARAMS.get(era, Constants.ERA_VISUAL_PARAMS[2])["noise_frequency_mult"]
	var noise_a := _make_noise(terrain_type * 1301 + era * 17, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.04 * freq_mult)
	var noise_b := _make_noise(terrain_type * 1301 + era * 19, FastNoiseLite.TYPE_CELLULAR, 0.06 * freq_mult)
	noise_b.cellular_return_type = FastNoiseLite.RETURN_DISTANCE

	var base_color: Color
	match terrain_type:
		Enums.TerrainType.RIVER_BASIN:
			base_color = Color(0.25, 0.45, 0.25, 0.35)
		Enums.TerrainType.PLAINS:
			base_color = Color(0.35, 0.45, 0.25, 0.30)
		Enums.TerrainType.MOUNTAINS:
			base_color = Color(0.25, 0.22, 0.20, 0.35)
		Enums.TerrainType.DESERT:
			base_color = Color(0.60, 0.50, 0.30, 0.28)
		Enums.TerrainType.JUNGLE:
			base_color = Color(0.10, 0.30, 0.16, 0.38)
		Enums.TerrainType.COASTLINE:
			base_color = Color(0.25, 0.55, 0.70, 0.25)
		Enums.TerrainType.TUNDRA:
			base_color = Color(0.55, 0.65, 0.75, 0.25)
		Enums.TerrainType.STEPPE:
			base_color = Color(0.45, 0.40, 0.25, 0.28)
		Enums.TerrainType.VOLCANIC_RIDGE:
			base_color = Color(0.60, 0.30, 0.18, 0.30)
		_:
			base_color = Color(0.3, 0.3, 0.3, 0.25)

	for x in DETAIL_TEX_SIZE:
		for y in DETAIL_TEX_SIZE:
			var nx := noise_a.get_noise_2d(float(x), float(y))
			var nb := noise_b.get_noise_2d(float(x), float(y))
			var alpha := 0.0

			match terrain_type:
				Enums.TerrainType.MOUNTAINS, Enums.TerrainType.VOLCANIC_RIDGE:
					# Ridgeline strokes
					if absf(nb) < 0.08:
						alpha = 0.55
				Enums.TerrainType.DESERT:
					# Dune bands
					var band := sin(float(x) * 0.12 + float(y) * 0.04)
					if absf(band) < 0.1:
						alpha = 0.45
				Enums.TerrainType.JUNGLE:
					# Canopy clusters
					if nx > 0.25:
						alpha = 0.50
				Enums.TerrainType.RIVER_BASIN:
					# Moisture patches + subtle lines
					if nx > 0.2:
						alpha = 0.35
				Enums.TerrainType.PLAINS, Enums.TerrainType.STEPPE:
					# Patchy grain
					if nx > 0.3:
						alpha = 0.30
				Enums.TerrainType.COASTLINE:
					# Shore ripples
					var ripple := sin(float(x) * 0.08 + float(y) * 0.02)
					if absf(ripple) < 0.08:
						alpha = 0.35
				Enums.TerrainType.TUNDRA:
					# Ice cracks
					if absf(nb) < 0.06:
						alpha = 0.35
				_:
					if nx > 0.35:
						alpha = 0.25

			if alpha > 0.0:
				var c := Color(base_color.r, base_color.g, base_color.b, base_color.a * alpha)
				image.set_pixel(x, y, c)

	return ImageTexture.create_from_image(image)


static func _generate_urban(density: int) -> ImageTexture:
	var image := Image.create(URBAN_TEX_SIZE, URBAN_TEX_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	var grid := 18 if density == 0 else 12 if density == 1 else 8
	var line_col := Color(0.35, 0.30, 0.25, 0.35)
	var fill_col := Color(0.55, 0.50, 0.42, 0.25)

	for x in URBAN_TEX_SIZE:
		for y in URBAN_TEX_SIZE:
			var gx := x % grid
			var gy := y % grid
			var is_street := gx < 2 or gy < 2
			if is_street:
				image.set_pixel(x, y, line_col)
			else:
				if density >= 1 and (gx > 2 and gx < grid - 2 and gy > 2 and gy < grid - 2):
					image.set_pixel(x, y, fill_col)

	return ImageTexture.create_from_image(image)


# --- Per-Terrain Generators ---

static func _gen_mountains(img: Image, fm: float, cm: float, smudge: FastNoiseLite) -> void:
	var base := _make_noise(2 * 7919, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.035 * fm)
	var ridge := _make_noise(2 * 7919 + 100, FastNoiseLite.TYPE_CELLULAR, 0.018 * fm)
	ridge.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	var detail := _make_noise(2 * 7919 + 200, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.12 * fm)
	var pal: Array = PALETTES[2]

	for x in TEX_SIZE:
		for y in TEX_SIZE:
			# Stretch ridge noise diagonally (NW-SE) for elongated ridgelines
			var rx := float(x) * 0.6 + float(y) * 0.4
			var ry := float(x) * -0.3 + float(y) * 0.7
			var n := base.get_noise_2d(float(x), float(y))
			var r := ridge.get_noise_2d(rx, ry)
			var d := detail.get_noise_2d(float(x), float(y)) * 0.15
			# Ridge creates sharp bright peaks where cellular distance is low
			var ridge_factor := clampf(1.0 - absf(r) * 2.5, 0.0, 1.0)
			var combined := clampf(0.55 + (n * 0.3 + ridge_factor * 0.45 + d) * cm, 0.0, 1.0)
			combined = _apply_smudge(combined, smudge, x, y)
			# Blend: dark rock -> mid rock -> snow on peaks
			var c := _palette_blend(pal, combined)
			img.set_pixel(x, y, c)


static func _gen_desert(img: Image, fm: float, cm: float, smudge: FastNoiseLite) -> void:
	var base := _make_noise(3 * 7919, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.015 * fm)
	var dune := _make_noise(3 * 7919 + 100, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.025 * fm)
	var wind := _make_noise(3 * 7919 + 200, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.08 * fm)
	var pal: Array = PALETTES[3]

	for x in TEX_SIZE:
		for y in TEX_SIZE:
			var n := base.get_noise_2d(float(x), float(y))
			# Stretch dune noise for directional dune lines (NW-SE wind)
			var dx := float(x) * 2.0 + float(y) * 0.3
			var dy := float(y) * 0.5
			var dn := dune.get_noise_2d(dx, dy)
			var w := wind.get_noise_2d(float(x), float(y)) * 0.1
			var combined := clampf(0.48 + (n * 0.25 + dn * 0.50 + w) * cm, 0.0, 1.0)
			combined = _apply_smudge(combined, smudge, x, y)
			var c := _palette_blend(pal, combined)
			img.set_pixel(x, y, c)


static func _gen_jungle(img: Image, fm: float, cm: float, smudge: FastNoiseLite) -> void:
	var base := _make_noise(4 * 7919, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.04 * fm)
	var canopy := _make_noise(4 * 7919 + 100, FastNoiseLite.TYPE_CELLULAR, 0.03 * fm)
	canopy.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	var detail := _make_noise(4 * 7919 + 200, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.1 * fm)
	var pal: Array = PALETTES[4]

	for x in TEX_SIZE:
		for y in TEX_SIZE:
			var n := base.get_noise_2d(float(x), float(y))
			var cn := canopy.get_noise_2d(float(x), float(y))
			var d := detail.get_noise_2d(float(x), float(y)) * 0.15
			# Canopy creates distinct cell blobs (dark gaps between canopy clusters)
			var canopy_factor := clampf((cn + 1.0) * 0.5, 0.0, 1.0)
			var combined := clampf(0.42 + (n * 0.25 + canopy_factor * 0.50 + d) * cm, 0.0, 1.0)
			combined = _apply_smudge(combined, smudge, x, y)
			var c := _palette_blend(pal, combined)
			img.set_pixel(x, y, c)


static func _gen_river_basin(img: Image, fm: float, cm: float, smudge: FastNoiseLite) -> void:
	var base := _make_noise(0 * 7919 + 1, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.025 * fm)
	var moisture := _make_noise(0 * 7919 + 100, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.012 * fm)
	var detail := _make_noise(0 * 7919 + 200, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.07 * fm)
	var pal: Array = PALETTES[0]

	for x in TEX_SIZE:
		for y in TEX_SIZE:
			var n := base.get_noise_2d(float(x), float(y))
			var m := moisture.get_noise_2d(float(x), float(y))
			var d := detail.get_noise_2d(float(x), float(y)) * 0.12
			# Moisture creates darker, wetter patches (farmland-like variety)
			var combined := clampf(0.45 + (n * 0.30 + m * 0.35 + d) * cm, 0.0, 1.0)
			combined = _apply_smudge(combined, smudge, x, y)
			var c := _palette_blend(pal, combined)
			img.set_pixel(x, y, c)


static func _gen_coastline(img: Image, fm: float, cm: float, smudge: FastNoiseLite) -> void:
	var base := _make_noise(5 * 7919, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.02 * fm)
	var shore := _make_noise(5 * 7919 + 100, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.04 * fm)
	var detail := _make_noise(5 * 7919 + 200, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.09 * fm)
	var pal: Array = PALETTES[5]

	for x in TEX_SIZE:
		for y in TEX_SIZE:
			var n := base.get_noise_2d(float(x), float(y))
			var s := shore.get_noise_2d(float(x), float(y))
			var d := detail.get_noise_2d(float(x), float(y)) * 0.1
			# Gradient: sandy (low y) to blue-green (high y) for shore transition
			var grad := float(y) / float(TEX_SIZE)
			var combined := clampf(grad * 0.35 + (n * 0.2 + s * 0.25 + d) * cm + 0.3, 0.0, 1.0)
			combined = _apply_smudge(combined, smudge, x, y)
			var c := _palette_blend(pal, combined)
			img.set_pixel(x, y, c)


static func _gen_tundra(img: Image, fm: float, cm: float, smudge: FastNoiseLite) -> void:
	var base := _make_noise(6 * 7919, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.015 * fm)
	var ice := _make_noise(6 * 7919 + 100, FastNoiseLite.TYPE_CELLULAR, 0.02 * fm)
	ice.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	var detail := _make_noise(6 * 7919 + 200, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.06 * fm)
	var pal: Array = PALETTES[6]

	for x in TEX_SIZE:
		for y in TEX_SIZE:
			var n := base.get_noise_2d(float(x), float(y))
			var ic := ice.get_noise_2d(float(x), float(y))
			var d := detail.get_noise_2d(float(x), float(y)) * 0.1
			# Cellular creates cracked ice pattern: dark where distance is mid-range
			var crack := clampf(absf(ic) * 3.0, 0.0, 1.0)
			var combined := clampf(0.50 + (n * 0.20 + crack * 0.40 + d) * cm, 0.0, 1.0)
			combined = _apply_smudge(combined, smudge, x, y)
			var c := _palette_blend(pal, combined)
			img.set_pixel(x, y, c)


static func _gen_plains(img: Image, fm: float, cm: float, smudge: FastNoiseLite) -> void:
	var base := _make_noise(1 * 7919, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.018 * fm)
	var roll := _make_noise(1 * 7919 + 100, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.008 * fm)
	var grass := _make_noise(1 * 7919 + 200, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.06 * fm)
	var pal: Array = PALETTES[1]

	for x in TEX_SIZE:
		for y in TEX_SIZE:
			var n := base.get_noise_2d(float(x), float(y))
			var r := roll.get_noise_2d(float(x), float(y))
			var g := grass.get_noise_2d(float(x), float(y)) * 0.12
			# Gentle rolling hills with grass streaks
			var combined := clampf(0.42 + (n * 0.28 + r * 0.45 + g) * cm, 0.0, 1.0)
			combined = _apply_smudge(combined, smudge, x, y)
			var c := _palette_blend(pal, combined)
			img.set_pixel(x, y, c)


static func _gen_steppe(img: Image, fm: float, cm: float, smudge: FastNoiseLite) -> void:
	var base := _make_noise(7 * 7919, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.02 * fm)
	var wind := _make_noise(7 * 7919 + 100, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.035 * fm)
	var scrub := _make_noise(7 * 7919 + 200, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.08 * fm)
	var pal: Array = PALETTES[7]

	for x in TEX_SIZE:
		for y in TEX_SIZE:
			var n := base.get_noise_2d(float(x), float(y))
			# Directional wind streaks (horizontal)
			var wn := wind.get_noise_2d(float(x) * 2.5, float(y) * 0.6)
			var sc := scrub.get_noise_2d(float(x), float(y)) * 0.12
			var combined := clampf(0.40 + (n * 0.30 + wn * 0.45 + sc) * cm, 0.0, 1.0)
			combined = _apply_smudge(combined, smudge, x, y)
			var c := _palette_blend(pal, combined)
			img.set_pixel(x, y, c)


static func _gen_volcanic(img: Image, fm: float, cm: float, smudge: FastNoiseLite) -> void:
	var base := _make_noise(8 * 7919, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.04 * fm)
	var vein := _make_noise(8 * 7919 + 100, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.06 * fm)
	var glow := _make_noise(8 * 7919 + 200, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.02 * fm)
	var pal: Array = PALETTES[8]

	for x in TEX_SIZE:
		for y in TEX_SIZE:
			var n := base.get_noise_2d(float(x), float(y))
			var v := vein.get_noise_2d(float(x), float(y))
			var gl := glow.get_noise_2d(float(x), float(y))
			# Veins: high-contrast branching lines where noise crosses zero
			var vein_factor := clampf(1.0 - absf(v) * 4.0, 0.0, 1.0)
			# Glow spots where noise is very high
			var glow_factor := clampf((gl - 0.3) * 2.0, 0.0, 1.0)
			var combined := clampf(0.45 + (n * 0.15 + vein_factor * 0.2 + glow_factor * 0.4) * cm, 0.0, 1.0)
			combined = _apply_smudge(combined, smudge, x, y)
			var c := _palette_blend(pal, combined)
			img.set_pixel(x, y, c)


static func _gen_default(img: Image, terrain_type: int, fm: float, cm: float, smudge: FastNoiseLite) -> void:
	var base := _make_noise(terrain_type * 7919, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.03 * fm)
	var detail := _make_noise(terrain_type * 7919 + 200, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.09 * fm)
	var pal: Array = PALETTES.get(terrain_type, [Color(0.4, 0.4, 0.4), Color(0.5, 0.5, 0.5), Color(0.6, 0.6, 0.6)])

	for x in TEX_SIZE:
		for y in TEX_SIZE:
			var n := base.get_noise_2d(float(x), float(y))
			var d := detail.get_noise_2d(float(x), float(y)) * 0.15
			var combined := clampf(0.5 + (n * 0.4 + d) * cm, 0.0, 1.0)
			combined = _apply_smudge(combined, smudge, x, y)
			var c := _palette_blend(pal, combined)
			img.set_pixel(x, y, c)


# --- Utilities ---

static func _make_noise(seed_val: int, noise_type: int, frequency: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_val
	n.noise_type = noise_type
	n.frequency = frequency
	return n


static func _palette_blend(pal: Array, t: float) -> Color:
	## Blend between 3 palette colors: dark(0) -> mid(0.5) -> light(1.0).
	var dark: Color = pal[0]
	var mid: Color = pal[1]
	var light: Color = pal[2]
	if t < 0.5:
		return dark.lerp(mid, t * 2.0)
	return mid.lerp(light, (t - 0.5) * 2.0)


static func _apply_smudge(val: float, smudge: FastNoiseLite, x: int, y: int) -> float:
	## Prehistoric era smudge: flatten detail toward uniform base.
	if smudge:
		var s := smudge.get_noise_2d(float(x), float(y))
		return lerpf(val, 0.5, 0.4 + s * 0.2)
	return val


static func _apply_grain(img: Image, terrain_type: int, era: int, freq_mult: float) -> void:
	## Subtle micro-grain to avoid flat tiles; scale with era for clarity.
	var grain := _make_noise(terrain_type * 9013 + era * 131, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.18 * freq_mult)
	var intensity := 0.035 if era <= 1 else 0.028
	for x in TEX_SIZE:
		for y in TEX_SIZE:
			var c := img.get_pixel(x, y)
			var g := grain.get_noise_2d(float(x), float(y))
			if g > 0.0:
				c = c.lightened(g * intensity)
			else:
				c = c.darkened(-g * intensity)
			img.set_pixel(x, y, c)
