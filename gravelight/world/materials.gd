class_name Mats
extends RefCounted
## Shared procedural material library (original; no downloaded textures). Every surface uses world-space
## triplanar mapping, so plain boxes texture seamlessly at any size. Textures are NoiseTexture2D resources
## that Godot regenerates from their parameters at load time, so the .tscn stays small.
##
## Art direction (GDD §17): late-war grit. Desaturated cold blues and snow outside, warm sodium and
## firelight pools inside, Nachtglas violet as the only saturated accent.

static var _cache: Dictionary = {}


static func get_mat(key: String) -> Material:
	if _cache.has(key):
		return _cache[key]
	var m: Material = _build(key)
	_cache[key] = m
	return m


static func _noise(type: FastNoiseLite.NoiseType, freq: float, octaves: int = 3, seed_v: int = 7) -> FastNoiseLite:
	var n: FastNoiseLite = FastNoiseLite.new()
	n.noise_type = type
	n.frequency = freq
	n.fractal_octaves = octaves
	n.seed = seed_v
	return n


static func _ramp(stops: Array) -> Gradient:
	var offs: PackedFloat32Array = []
	var cols: PackedColorArray = []
	for s: Array in stops:
		offs.append(float(s[0]))
		cols.append(s[1] as Color)
	var g: Gradient = Gradient.new()
	g.offsets = offs
	g.colors = cols
	return g


static func _tex(noise: FastNoiseLite, ramp: Gradient, size: int = 256) -> NoiseTexture2D:
	var t: NoiseTexture2D = NoiseTexture2D.new()
	t.width = size
	t.height = size
	t.seamless = true
	t.noise = noise
	t.color_ramp = ramp
	return t


static func _normal(noise: FastNoiseLite, strength: float, size: int = 256) -> NoiseTexture2D:
	var t: NoiseTexture2D = NoiseTexture2D.new()
	t.width = size
	t.height = size
	t.seamless = true
	t.as_normal_map = true
	t.bump_strength = strength
	t.noise = noise
	return t


## Triplanar textured material. `scale` is world tiles per metre on each axis (anisotropic = planks).
static func _surface(albedo: NoiseTexture2D, normal: NoiseTexture2D, scale: Vector3, rough: float,
		normal_scale: float = 1.0, metal: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_texture = albedo
	m.roughness = rough
	m.metallic = metal
	if normal != null:
		m.normal_enabled = true
		m.normal_texture = normal
		m.normal_scale = normal_scale
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = scale
	m.uv1_triplanar_sharpness = 4.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## Straight boards: a square cell grid (no jitter) stretched by the world scale, one tone per board,
## straight seams in the normal map, and a fine grain mixed in.
static func _boards(seed_v: int, stops: Array, scale: Vector3, rough: float) -> StandardMaterial3D:
	var c: FastNoiseLite = _noise(FastNoiseLite.TYPE_CELLULAR, 0.04, 1, seed_v)
	c.cellular_jitter = 0.0
	c.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	var e: FastNoiseLite = _noise(FastNoiseLite.TYPE_CELLULAR, 0.04, 1, seed_v)
	e.cellular_jitter = 0.0
	e.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	return _surface(_tex(c, _ramp(stops)), _normal(e, 2.5), scale, rough, 0.8)


static func _flat(c: Color, rough: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


static func _glow(c: Color, energy: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = _flat(c, 0.6)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


static func _build(key: String) -> Material:
	var simplex: FastNoiseLite.NoiseType = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var cell: FastNoiseLite.NoiseType = FastNoiseLite.TYPE_CELLULAR
	match key:
		# ---- walls
		"plaster":
			var n: FastNoiseLite = _noise(simplex, 0.012, 4, 3)
			return _surface(_tex(n, _ramp([[0.0, Color(0.58, 0.52, 0.43)], [0.55, Color(0.70, 0.64, 0.54)], [1.0, Color(0.78, 0.73, 0.63)]])),
				_normal(_noise(simplex, 0.08, 3, 4), 2.0), Vector3(0.35, 0.35, 0.35), 0.95, 0.5)
		"plaster_upper":
			var n2: FastNoiseLite = _noise(simplex, 0.014, 4, 9)
			return _surface(_tex(n2, _ramp([[0.0, Color(0.42, 0.42, 0.40)], [0.6, Color(0.55, 0.54, 0.50)], [1.0, Color(0.63, 0.62, 0.57)]])),
				_normal(_noise(simplex, 0.08, 3, 10), 2.0), Vector3(0.35, 0.35, 0.35), 0.95, 0.5)
		"wainscot":
			return _boards(21, [[0.0, Color(0.17, 0.09, 0.05)], [1.0, Color(0.28, 0.16, 0.09)]], Vector3(2.6, 0.12, 2.6), 0.55)
		"planks":   # rough-sawn barn boards, horizontal
			return _boards(33, [[0.0, Color(0.22, 0.16, 0.11)], [0.5, Color(0.33, 0.24, 0.16)], [1.0, Color(0.40, 0.30, 0.20)]], Vector3(0.12, 1.3, 0.12), 0.92)
		"floorboards":   # boards run along X
			return _boards(41, [[0.0, Color(0.16, 0.10, 0.06)], [0.5, Color(0.25, 0.16, 0.09)], [1.0, Color(0.32, 0.22, 0.14)]], Vector3(0.1, 0.1, 0.95), 0.7)
		"stone":   # fieldstone with dark mortar
			var sc: FastNoiseLite = _noise(cell, 0.045, 1, 51)
			sc.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
			sc.cellular_jitter = 0.9
			return _surface(_tex(sc, _ramp([[0.0, Color(0.10, 0.09, 0.08)], [0.08, Color(0.22, 0.21, 0.20)], [0.25, Color(0.40, 0.38, 0.35)], [1.0, Color(0.50, 0.47, 0.43)]])),
				_normal(sc, 10.0), Vector3(0.9, 0.9, 0.9), 0.95, 1.4)
		"roof":   # weathered shingles in horizontal rows
			return _boards(61, [[0.0, Color(0.10, 0.10, 0.11)], [1.0, Color(0.23, 0.22, 0.22)]], Vector3(0.6, 1.2, 0.6), 0.9)
		"beam":   # dark old timber
			return _surface(_tex(_noise(simplex, 0.03, 5, 71), _ramp([[0.0, Color(0.09, 0.06, 0.04)], [1.0, Color(0.20, 0.13, 0.08)]])),
				_normal(_noise(simplex, 0.1, 3, 72), 2.0), Vector3(0.9, 0.5, 0.9), 0.85, 0.6)
		"furniture":   # stained, worn oak
			return _surface(_tex(_noise(simplex, 0.02, 5, 81), _ramp([[0.0, Color(0.18, 0.11, 0.06)], [0.6, Color(0.30, 0.19, 0.10)], [1.0, Color(0.36, 0.24, 0.13)]])),
				_normal(_noise(simplex, 0.2, 3, 82), 2.0), Vector3(4.0, 0.6, 4.0), 0.55, 0.6)
		"dirt":
			return _surface(_tex(_noise(simplex, 0.02, 5, 91), _ramp([[0.0, Color(0.13, 0.11, 0.08)], [0.5, Color(0.22, 0.18, 0.12)], [1.0, Color(0.30, 0.25, 0.16)]])),
				_normal(_noise(simplex, 0.1, 4, 92), 3.0), Vector3(0.4, 0.4, 0.4), 1.0)
		"snow":
			var m_snow: StandardMaterial3D = _surface(_tex(_noise(simplex, 0.01, 4, 101), _ramp([[0.0, Color(0.58, 0.63, 0.72)], [0.6, Color(0.75, 0.79, 0.86)], [1.0, Color(0.86, 0.89, 0.94)]])),
				_normal(_noise(simplex, 0.05, 4, 102), 1.5), Vector3(0.12, 0.12, 0.12), 0.55)
			m_snow.metallic_specular = 0.7
			return m_snow
		"snow_trodden":
			return _surface(_tex(_noise(simplex, 0.03, 4, 111), _ramp([[0.0, Color(0.30, 0.31, 0.34)], [0.5, Color(0.46, 0.48, 0.53)], [1.0, Color(0.62, 0.65, 0.71)]])),
				_normal(_noise(simplex, 0.1, 3, 112), 3.0), Vector3(0.25, 0.25, 0.25), 0.7)
		"hay":
			return _surface(_tex(_noise(simplex, 0.09, 4, 121), _ramp([[0.0, Color(0.36, 0.27, 0.11)], [0.5, Color(0.62, 0.50, 0.24)], [1.0, Color(0.78, 0.66, 0.36)]])),
				_normal(_noise(simplex, 0.3, 3, 122), 6.0), Vector3(0.4, 2.0, 0.4), 1.0)
		"straw_floor":
			return _surface(_tex(_noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.12, 3, 123), _ramp([[0.0, Color(0.16, 0.12, 0.06)], [1.0, Color(0.34, 0.27, 0.13)]])),
				null, Vector3(1.5, 1.5, 4.0), 1.0)
		"iron":
			return _surface(_tex(_noise(simplex, 0.05, 4, 131), _ramp([[0.0, Color(0.06, 0.06, 0.06)], [1.0, Color(0.20, 0.19, 0.18)]])),
				_normal(_noise(simplex, 0.2, 3, 132), 2.0), Vector3(1.0, 1.0, 1.0), 0.6, 1.0, 0.7)
		"wreck":   # olive drab, burnt
			return _surface(_tex(_noise(simplex, 0.03, 5, 141), _ramp([[0.0, Color(0.04, 0.04, 0.03)], [0.45, Color(0.16, 0.17, 0.12)], [1.0, Color(0.26, 0.28, 0.19)]])),
				_normal(_noise(simplex, 0.1, 3, 142), 3.0), Vector3(0.3, 0.3, 0.3), 0.8, 1.0, 0.3)
		"cloth_red":
			return _surface(_tex(_noise(simplex, 0.15, 3, 151), _ramp([[0.0, Color(0.22, 0.05, 0.04)], [1.0, Color(0.38, 0.10, 0.07)]])), null, Vector3(2, 2, 2), 1.0)
		"cloth_green":
			return _surface(_tex(_noise(simplex, 0.15, 3, 161), _ramp([[0.0, Color(0.10, 0.14, 0.09)], [1.0, Color(0.19, 0.24, 0.15)]])), null, Vector3(2, 2, 2), 1.0)
		"linen":
			return _surface(_tex(_noise(simplex, 0.2, 3, 171), _ramp([[0.0, Color(0.55, 0.52, 0.46)], [1.0, Color(0.70, 0.67, 0.60)]])), null, Vector3(2, 2, 2), 1.0)
		"rug":
			var rgc: FastNoiseLite = _noise(cell, 0.06, 1, 181)
			rgc.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
			return _surface(_tex(rgc, _ramp([[0.0, Color(0.20, 0.05, 0.04)], [0.5, Color(0.35, 0.12, 0.06)], [1.0, Color(0.30, 0.20, 0.10)]])),
				_normal(_noise(simplex, 0.4, 2, 182), 1.0), Vector3(2.0, 2.0, 2.0), 1.0)
		# ---- flat accents
		"brass":
			return _flat(Color(0.62, 0.45, 0.18), 0.3, 0.9)
		"bottle_green":
			var bg: StandardMaterial3D = _flat(Color(0.10, 0.22, 0.10, 0.85), 0.08)
			bg.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			bg.metallic_specular = 1.0
			return bg
		"bottle_amber":
			var ba: StandardMaterial3D = _flat(Color(0.35, 0.16, 0.04, 0.85), 0.08)
			ba.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ba.metallic_specular = 1.0
			return ba
		"stein":
			return _flat(Color(0.52, 0.48, 0.40), 0.35)
		"paper":
			return _flat(Color(0.72, 0.66, 0.52), 0.9)
		"frame_gold":
			return _flat(Color(0.40, 0.30, 0.12), 0.4, 0.6)
		"picture":
			return _surface(_tex(_noise(simplex, 0.04, 4, 191), _ramp([[0.0, Color(0.10, 0.10, 0.12)], [0.5, Color(0.25, 0.24, 0.20)], [1.0, Color(0.45, 0.40, 0.30)]])), null, Vector3(3, 3, 3), 0.9)
		"antler":
			return _flat(Color(0.62, 0.56, 0.46), 0.7)
		"lantern_glass":
			return _glow(Color(1.0, 0.70, 0.35), 3.5)
		"candle":
			return _glow(Color(1.0, 0.75, 0.40), 5.0)
		"ember":
			return _glow(Color(1.0, 0.35, 0.08), 4.0)
		"fire":
			return _glow(Color(1.0, 0.45, 0.12), 6.0)
		"char":
			return _flat(Color(0.03, 0.03, 0.03), 1.0)
		"nachtglas":
			var ng: StandardMaterial3D = _glow(Color(0.55, 0.20, 1.0), 3.0)
			ng.albedo_color = Color(0.08, 0.03, 0.12)
			return ng
		"window_dark":   # the night beyond a shutter
			return _flat(Color(0.02, 0.03, 0.05), 1.0)
	var m1: Material = _build_mine(key)
	if m1 != null:
		return m1
	var m2: Material = _build_art(key)
	if m2 != null:
		return m2
	var m3: Material = _build_map0(key)
	if m3 != null:
		return m3
	var m4: Material = _build_map2(key)
	if m4 != null:
		return m4
	push_warning("Mats: unknown key %s" % key)
	return _flat(Color(1, 0, 1))


# ================================================================== Map 1 (Kaltenbrunn) additions

## Running-bond brick, projected in world space on the dominant axis (walls are axis-aligned boxes), with a
## tone per brick, soot towards the ground, and recessed (occluded) lime mortar. No textures.
const BRICK_SHADER: String = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec3 brick_dark : source_color = vec3(0.20, 0.085, 0.06);
uniform vec3 brick_light : source_color = vec3(0.46, 0.22, 0.14);
uniform vec3 mortar : source_color = vec3(0.40, 0.38, 0.35);
uniform vec2 brick_size = vec2(0.25, 0.075);
uniform float joint = 0.011;
varying vec3 wpos;
varying vec3 wnrm;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 an = abs(wnrm);
	vec2 uv = an.x > an.z ? wpos.zy : wpos.xy;
	if (an.y > max(an.x, an.z)) { uv = wpos.xz; }
	vec2 s = uv / brick_size;
	float row = floor(s.y);
	s.x += mod(row, 2.0) * 0.5;
	vec2 cell = floor(s);
	vec2 f = fract(s) * brick_size;
	vec2 d = min(f, brick_size - f);
	float m = 1.0 - smoothstep(joint * 0.6, joint, min(d.x, d.y));
	float tone = hash(cell);
	float grime = vnoise(uv * 1.3) * 0.5 + vnoise(uv * 6.0) * 0.25;
	vec3 b = mix(brick_dark, brick_light, clamp(tone * 0.75 + grime * 0.4, 0.0, 1.0));
	b *= mix(0.55, 1.0, smoothstep(-0.2, 1.4, wpos.y - floor(wpos.y / 12.0 + 0.001) * 12.0));
	ALBEDO = mix(b, mortar * (0.7 + grime * 0.4), m);
	ROUGHNESS = mix(0.82, 0.95, m);
	AO = 1.0 - m * 0.65;
	AO_LIGHT_AFFECT = 0.4;
}
"""

## Masonry/tiles: a square cell grid stretched by the world scale, one tone per unit, and coloured mortar
## (or grout) mixed over it with a triplanar detail layer that shares the grid.
static func _masonry(seed_v: int, tones: Array, mortar: Color, scale: Vector3, rough: float, joint: float = 0.07,
		normal_strength: float = 3.0) -> StandardMaterial3D:
	var c: FastNoiseLite = _noise(FastNoiseLite.TYPE_CELLULAR, 0.04, 1, seed_v)
	c.cellular_jitter = 0.0
	c.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	var e: FastNoiseLite = _noise(FastNoiseLite.TYPE_CELLULAR, 0.04, 1, seed_v)
	e.cellular_jitter = 0.0
	e.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	var m: StandardMaterial3D = _surface(_tex(c, _ramp(tones)), _normal(e, normal_strength), scale, rough, 0.9)
	var clear: Color = Color(mortar.r, mortar.g, mortar.b, 0.0)
	m.detail_enabled = true
	m.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	m.detail_uv_layer = BaseMaterial3D.DETAIL_UV_1
	m.detail_albedo = _tex(e, _ramp([[0.0, mortar], [joint, mortar], [joint + 0.03, clear], [1.0, clear]]))
	return m


## Natural rock: banded albedo (anisotropic scale = strata), faceted normals, and a cellular roughness map so
## some facets catch the light (halite sparkle).
static func _rock(seed_v: int, stops: Array, scale: Vector3, sparkle: float, normal_strength: float) -> StandardMaterial3D:
	var band: FastNoiseLite = _noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.018, 5, seed_v)
	var facet: FastNoiseLite = _noise(FastNoiseLite.TYPE_CELLULAR, 0.05, 2, seed_v + 1)
	facet.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	var m: StandardMaterial3D = _surface(_tex(band, _ramp(stops)), _normal(facet, normal_strength), scale, 0.85, 1.0)
	if sparkle > 0.0:
		var gl: FastNoiseLite = _noise(FastNoiseLite.TYPE_CELLULAR, 0.09, 1, seed_v + 2)
		gl.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
		m.roughness = 1.0
		m.roughness_texture = _tex(gl, _ramp([[0.0, Color(0.9, 0.9, 0.9)], [1.0 - sparkle, Color(0.85, 0.85, 0.85)],
			[1.0 - sparkle + 0.02, Color(0.12, 0.12, 0.12)], [1.0, Color(0.08, 0.08, 0.08)]]))
		m.metallic_specular = 0.85
	return m


static func _clear(c: Color, rough: float, energy: float = 0.0, emit: Color = Color.BLACK) -> StandardMaterial3D:
	var m: StandardMaterial3D = _flat(c, rough)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic_specular = 1.0
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = energy
	return m


static func _build_mine(key: String) -> Material:
	var simplex: FastNoiseLite.NoiseType = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var cell: FastNoiseLite.NoiseType = FastNoiseLite.TYPE_CELLULAR
	match key:
		# ---- masonry & finishes
		"brick":   # industrial red-brown brick in running bond, pale lime mortar (world-space shader)
			var bs: Shader = Shader.new()
			bs.code = BRICK_SHADER
			var bm: ShaderMaterial = ShaderMaterial.new()
			bm.shader = bs
			return bm
		"stucco":   # weathered ochre render
			return _surface(_tex(_noise(simplex, 0.01, 5, 211), _ramp([[0.0, Color(0.40, 0.36, 0.29)], [0.35, Color(0.60, 0.54, 0.42)],
				[0.75, Color(0.70, 0.64, 0.51)], [1.0, Color(0.76, 0.71, 0.58)]])),
				_normal(_noise(simplex, 0.09, 4, 212), 2.5), Vector3(0.22, 0.22, 0.22), 0.95, 0.6)
		"stucco_trim":   # pale lime-washed surrounds and cornices
			return _surface(_tex(_noise(simplex, 0.03, 4, 215), _ramp([[0.0, Color(0.55, 0.54, 0.50)], [1.0, Color(0.74, 0.73, 0.68)]])),
				_normal(_noise(simplex, 0.1, 3, 216), 1.5), Vector3(0.5, 0.5, 0.5), 0.9, 0.4)
		"concrete":
			return _surface(_tex(_noise(simplex, 0.03, 6, 221), _ramp([[0.0, Color(0.27, 0.27, 0.26)], [0.45, Color(0.36, 0.36, 0.35)],
				[0.8, Color(0.42, 0.41, 0.39)], [1.0, Color(0.47, 0.46, 0.43)]])),
				_normal(_noise(cell, 0.06, 2, 222), 1.5), Vector3(0.3, 0.3, 0.3), 0.92, 0.5)
		"concrete_floor":   # oil-stained machine-hall floor
			return _surface(_tex(_noise(simplex, 0.012, 5, 225), _ramp([[0.0, Color(0.08, 0.08, 0.08)], [0.3, Color(0.20, 0.20, 0.19)],
				[0.7, Color(0.30, 0.30, 0.29)], [1.0, Color(0.36, 0.35, 0.33)]])),
				_normal(_noise(simplex, 0.1, 3, 226), 1.2), Vector3(0.2, 0.2, 0.2), 0.75, 0.4)
		"paint_cream":   # institutional cream paint over plaster
			return _surface(_tex(_noise(simplex, 0.04, 6, 231), _ramp([[0.0, Color(0.52, 0.50, 0.42)], [0.5, Color(0.62, 0.60, 0.51)], [1.0, Color(0.68, 0.66, 0.57)]])),
				_normal(_noise(simplex, 0.12, 3, 232), 1.2), Vector3(0.3, 0.3, 0.3), 0.8, 0.4)
		"paint_green":   # industrial dado green
			return _surface(_tex(_noise(simplex, 0.03, 5, 235), _ramp([[0.0, Color(0.10, 0.14, 0.11)], [0.6, Color(0.18, 0.26, 0.20)], [1.0, Color(0.24, 0.32, 0.25)]])),
				_normal(_noise(simplex, 0.15, 3, 236), 1.2), Vector3(0.4, 0.4, 0.4), 0.55, 0.4)
		"tile_wall":   # glazed pale green-white wall tiles, grey grout
			return _masonry(241, [[0.0, Color(0.52, 0.58, 0.53)], [0.6, Color(0.64, 0.69, 0.63)], [1.0, Color(0.72, 0.75, 0.69)]],
				Color(0.22, 0.22, 0.20), Vector3(0.62, 0.62, 0.62), 0.22, 0.06, 0.7)
		"tile_floor":   # two-tone terrazzo tiles
			return _masonry(245, [[0.0, Color(0.14, 0.14, 0.13)], [0.48, Color(0.18, 0.17, 0.16)], [0.52, Color(0.46, 0.44, 0.39)], [1.0, Color(0.54, 0.51, 0.45)]],
				Color(0.08, 0.08, 0.08), Vector3(0.33, 0.33, 0.33), 0.35, 0.05, 0.6)
		# ---- rock
		"halite":   # pinkish-grey rock salt in strata, sparkling facets
			return _rock(251, [[0.0, Color(0.30, 0.25, 0.25)], [0.3, Color(0.50, 0.42, 0.41)], [0.55, Color(0.66, 0.57, 0.55)],
				[0.7, Color(0.48, 0.47, 0.49)], [0.85, Color(0.74, 0.66, 0.63)], [1.0, Color(0.82, 0.76, 0.73)]],
				Vector3(0.035, 0.3, 0.035), 0.12, 6.0)
		"halite_carved":   # the chapel's dressed salt: lighter, smoother, still glinting
			return _rock(255, [[0.0, Color(0.56, 0.49, 0.47)], [0.5, Color(0.72, 0.65, 0.62)], [1.0, Color(0.84, 0.79, 0.76)]],
				Vector3(0.35, 0.35, 0.35), 0.1, 1.5)
		"halite_floor":   # trodden salt floor
			return _rock(259, [[0.0, Color(0.26, 0.22, 0.21)], [0.5, Color(0.44, 0.38, 0.36)], [1.0, Color(0.58, 0.52, 0.49)]],
				Vector3(0.2, 0.2, 0.2), 0.06, 2.0)
		"rock_dark":   # the Core's dark country rock
			return _rock(263, [[0.0, Color(0.05, 0.05, 0.06)], [0.4, Color(0.11, 0.11, 0.13)], [0.8, Color(0.19, 0.18, 0.21)], [1.0, Color(0.25, 0.23, 0.27)]],
				Vector3(0.12, 0.3, 0.12), 0.05, 8.0)
		"rock_floor":
			return _rock(267, [[0.0, Color(0.06, 0.06, 0.07)], [0.5, Color(0.14, 0.13, 0.15)], [1.0, Color(0.22, 0.21, 0.23)]],
				Vector3(0.3, 0.3, 0.3), 0.04, 4.0)
		"salt_crystal":   # loose halite crystals and chandelier drops (opaque, glassy)
			var sc: StandardMaterial3D = _flat(Color(0.86, 0.80, 0.82), 0.08)
			sc.metallic_specular = 1.0
			sc.rim_enabled = true
			sc.rim = 0.6
			return sc
		"salt_crystal_lit":   # chandelier drops with the power on
			var scl: StandardMaterial3D = _glow(Color(1.0, 0.86, 0.72), 2.2)
			scl.albedo_color = Color(0.9, 0.84, 0.82)
			return scl
		# ---- metal & machinery
		"machine_green":
			return _surface(_tex(_noise(simplex, 0.04, 5, 271), _ramp([[0.0, Color(0.08, 0.09, 0.08)], [0.25, Color(0.15, 0.20, 0.16)],
				[0.8, Color(0.21, 0.28, 0.23)], [1.0, Color(0.30, 0.34, 0.28)]])),
				_normal(_noise(simplex, 0.2, 3, 272), 1.0), Vector3(0.6, 0.6, 0.6), 0.5, 0.5, 0.35)
		"machine_grey":
			return _surface(_tex(_noise(simplex, 0.04, 5, 275), _ramp([[0.0, Color(0.08, 0.08, 0.08)], [0.3, Color(0.22, 0.23, 0.24)], [1.0, Color(0.36, 0.37, 0.38)]])),
				_normal(_noise(simplex, 0.2, 3, 276), 1.0), Vector3(0.6, 0.6, 0.6), 0.5, 0.5, 0.45)
		"rust":
			return _surface(_tex(_noise(simplex, 0.06, 5, 281), _ramp([[0.0, Color(0.10, 0.05, 0.03)], [0.5, Color(0.28, 0.13, 0.06)], [1.0, Color(0.44, 0.22, 0.09)]])),
				_normal(_noise(simplex, 0.3, 3, 282), 3.0), Vector3(1.0, 1.0, 1.0), 0.9, 0.8, 0.3)
		"loco_black":
			return _surface(_tex(_noise(simplex, 0.05, 5, 285), _ramp([[0.0, Color(0.02, 0.02, 0.025)], [0.7, Color(0.07, 0.07, 0.08)], [1.0, Color(0.16, 0.13, 0.11)]])),
				_normal(_noise(simplex, 0.2, 3, 286), 1.0), Vector3(0.6, 0.6, 0.6), 0.45, 0.5, 0.6)
		"steel":
			return _flat(Color(0.46, 0.47, 0.48), 0.32, 0.85)
		"copper":
			return _flat(Color(0.60, 0.34, 0.20), 0.35, 0.9)
		"steel_grate":   # chequer-plate catwalk decking
			return _masonry(291, [[0.0, Color(0.12, 0.12, 0.12)], [1.0, Color(0.22, 0.22, 0.22)]], Color(0.03, 0.03, 0.03),
				Vector3(2.5, 2.5, 2.5), 0.45, 0.12, 4.0)
		"rubber":
			return _flat(Color(0.035, 0.035, 0.035), 0.7)
		"gauge_face":
			return _flat(Color(0.82, 0.78, 0.64), 0.35)
		"enamel_white":
			return _flat(Color(0.80, 0.80, 0.76), 0.22)
		"enamel_green":
			return _flat(Color(0.10, 0.22, 0.15), 0.3)
		"black_paint":
			return _flat(Color(0.05, 0.05, 0.05), 0.6)
		"red_paint":
			return _flat(Color(0.42, 0.07, 0.05), 0.6)
		"yellow_paint":
			return _flat(Color(0.62, 0.46, 0.08), 0.6)
		# ---- timber, cloth, ground
		"pine":   # newer pit-prop timber
			return _surface(_tex(_noise(simplex, 0.03, 5, 301), _ramp([[0.0, Color(0.20, 0.14, 0.08)], [0.6, Color(0.36, 0.26, 0.15)], [1.0, Color(0.46, 0.35, 0.21)]])),
				_normal(_noise(simplex, 0.12, 3, 302), 2.0), Vector3(1.6, 0.2, 1.6), 0.9, 0.6)
		"shutter_green":   # Alpine shutters, vertical boards
			return _boards(305, [[0.0, Color(0.06, 0.12, 0.08)], [0.5, Color(0.10, 0.19, 0.12)], [1.0, Color(0.15, 0.24, 0.16)]], Vector3(1.3, 0.12, 1.3), 0.8)
		"wood_red":   # boxcar planking
			return _boards(309, [[0.0, Color(0.16, 0.06, 0.04)], [0.5, Color(0.26, 0.10, 0.06)], [1.0, Color(0.34, 0.14, 0.08)]], Vector3(1.3, 0.12, 1.3), 0.85)
		"sandbag":
			return _surface(_tex(_noise(simplex, 0.08, 4, 313), _ramp([[0.0, Color(0.22, 0.19, 0.13)], [1.0, Color(0.40, 0.35, 0.24)]])),
				_normal(_noise(simplex, 0.3, 3, 314), 3.0), Vector3(1.5, 1.5, 1.5), 1.0)
		"tarp":
			return _surface(_tex(_noise(simplex, 0.06, 4, 317), _ramp([[0.0, Color(0.11, 0.12, 0.08)], [1.0, Color(0.22, 0.24, 0.16)]])),
				_normal(_noise(simplex, 0.15, 3, 318), 2.0), Vector3(0.8, 0.8, 0.8), 1.0)
		"ballast":
			var bc: FastNoiseLite = _noise(cell, 0.12, 1, 321)
			return _surface(_tex(bc, _ramp([[0.0, Color(0.12, 0.11, 0.10)], [0.5, Color(0.25, 0.24, 0.22)], [1.0, Color(0.36, 0.34, 0.31)]])),
				_normal(bc, 6.0), Vector3(1.2, 1.2, 1.2), 1.0, 1.2)
		"coal":
			var cc: FastNoiseLite = _noise(cell, 0.1, 1, 325)
			return _surface(_tex(cc, _ramp([[0.0, Color(0.01, 0.01, 0.01)], [1.0, Color(0.08, 0.08, 0.085)]])), _normal(cc, 8.0), Vector3(1.5, 1.5, 1.5), 0.35, 1.4)
		"ore_salt":   # broken salt rock heaped in carts
			var oc: FastNoiseLite = _noise(cell, 0.1, 1, 329)
			return _surface(_tex(oc, _ramp([[0.0, Color(0.32, 0.27, 0.27)], [1.0, Color(0.74, 0.66, 0.64)]])), _normal(oc, 8.0), Vector3(1.5, 1.5, 1.5), 0.5, 1.4)
		"mountain":
			return _surface(_tex(_noise(simplex, 0.02, 5, 331), _ramp([[0.0, Color(0.05, 0.06, 0.08)], [0.6, Color(0.10, 0.11, 0.14)], [0.75, Color(0.40, 0.44, 0.52)], [1.0, Color(0.55, 0.60, 0.68)]])),
				null, Vector3(0.01, 0.01, 0.01), 1.0)
		# ---- lamps & glass (the glowing keys are the powered states)
		"bulb_off":
			var bo: StandardMaterial3D = _flat(Color(0.20, 0.19, 0.16), 0.1)
			bo.metallic_specular = 1.0
			return bo
		"bulb_warm":   # incandescent
			return _glow(Color(1.0, 0.80, 0.52), 7.0)
		"sodium":   # sodium-vapour amber
			return _glow(Color(1.0, 0.60, 0.24), 6.0)
		"flood_glass":   # cold floodlight lens
			return _glow(Color(0.86, 0.92, 1.0), 9.0)
		"emergency_red":
			return _glow(Color(1.0, 0.12, 0.07), 4.5)
		"gauge_lit":
			return _glow(Color(1.0, 0.85, 0.55), 1.4)
		"glass":
			return _clear(Color(0.62, 0.72, 0.72, 0.16), 0.04)
		"nachtglas_liquid":   # the tanks' violet suspension
			return _clear(Color(0.30, 0.08, 0.55, 0.62), 0.1, 2.2, Color(0.55, 0.18, 1.0))
		"nachtglas_crystal":
			var nc: StandardMaterial3D = _glow(Color(0.62, 0.24, 1.0), 1.15)
			nc.albedo_color = Color(0.16, 0.05, 0.28)
			nc.roughness = 0.12
			nc.metallic_specular = 1.0
			return nc
		"nachtglas_dim":
			var nd: StandardMaterial3D = _glow(Color(0.45, 0.16, 0.8), 0.35)
			nd.albedo_color = Color(0.08, 0.03, 0.14)
			nd.roughness = 0.15
			return nd
		"nachtglas_vein":   # cracks in the Core floor
			return _glow(Color(0.7, 0.3, 1.0), 2.2)
	return null


# ================================================================== interactable art (D-063)

## Hazard stripes in object space (they ride along with moving parts): diagonal bands of `col_a` and near-black,
## with value-noise wear and scorch toward the bottom.
const STRIPE_SHADER: String = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec3 col_a : source_color = vec3(0.8, 0.45, 0.08);
uniform vec3 col_b : source_color = vec3(0.025, 0.025, 0.025);
uniform float width = 0.09;
varying vec3 lpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	lpos = VERTEX;
}

void fragment() {
	float s = fract((lpos.x + lpos.y + lpos.z * 0.5) / (2.0 * width));
	float m = smoothstep(0.48, 0.52, s);
	float wear = vnoise(lpos.xy * 9.0 + lpos.zz * 5.0) * 0.6 + vnoise(lpos.xy * 31.0) * 0.4;
	vec3 c = mix(col_a, col_b, m);
	c = mix(c, vec3(0.16, 0.15, 0.14), smoothstep(0.72, 0.9, wear) * 0.7);
	ALBEDO = c;
	ROUGHNESS = mix(0.45, 0.8, wear);
	METALLIC = smoothstep(0.75, 0.95, wear) * 0.6;
}
"""


static func _parse_color(key: String) -> Color:
	var i: int = key.find(":")
	return Color(key.substr(i + 1)) if i >= 0 else Color.MAGENTA


## Interactable art keys. Parametrised keys carry a colour after a colon ("enamel:#9e2a1e"); any key with the suffix
## "@local" is that material mapped in object space instead of world space (for parts that move, so the texture
## doesn't swim).
static func _build_art(key: String) -> Material:
	var simplex: FastNoiseLite.NoiseType = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	if key.ends_with("@local"):
		var base: Material = get_mat(key.trim_suffix("@local"))
		var dup: Material = base.duplicate()
		if dup is StandardMaterial3D:
			(dup as StandardMaterial3D).uv1_world_triplanar = false
		return dup
	if key.begins_with("enamel:"):   # glossy vitreous enamel with chipped, darker edges
		var c: Color = _parse_color(key)
		var en: StandardMaterial3D = _surface(_tex(_noise(simplex, 0.05, 4, 401 + int(c.r * 97.0)), _ramp([[0.0, c.darkened(0.55)], [0.14, c.darkened(0.2)],
			[0.3, c], [1.0, c.lightened(0.06)]])), _normal(_noise(simplex, 0.2, 2, 402), 0.6), Vector3(0.9, 0.9, 0.9), 0.3, 0.3)
		en.metallic_specular = 0.65
		return en
	if key.begins_with("paint:"):
		return _flat(_parse_color(key), 0.6)
	if key.begins_with("neon:"):   # lit neon tube / lit lamp glass in a colour
		var nc: Color = _parse_color(key)
		var ne: StandardMaterial3D = _glow(nc.lightened(0.2), 4.5)
		ne.albedo_color = nc.lightened(0.5)
		return ne
	if key.begins_with("glow_soft:"):
		return _glow(_parse_color(key), 1.4)
	if key.begins_with("glass:"):   # tinted bottle glass
		var gc: Color = _parse_color(key)
		return _clear(Color(gc.r * 0.7, gc.g * 0.7, gc.b * 0.7, 0.7), 0.06)
	if key.begins_with("stripes:"):
		var sm: ShaderMaterial = ShaderMaterial.new()
		var sh: Shader = Shader.new()
		sh.code = STRIPE_SHADER
		sm.shader = sh
		var sc: Color = _parse_color(key)
		sm.set_shader_parameter("col_a", Vector3(sc.r, sc.g, sc.b))
		return sm
	match key:
		"chrome":
			return _flat(Color(0.74, 0.74, 0.76), 0.14, 1.0)
		"chrome_worn":   # scorched, smoky chrome
			return _surface(_tex(_noise(simplex, 0.06, 4, 411), _ramp([[0.0, Color(0.10, 0.09, 0.08)], [0.4, Color(0.42, 0.41, 0.40)], [1.0, Color(0.70, 0.70, 0.71)]])),
				null, Vector3(1.5, 1.5, 1.5), 0.3, 1.0, 0.9)
		"walnut":   # polished walnut veneer
			return _surface(_tex(_noise(simplex, 0.03, 5, 415), _ramp([[0.0, Color(0.09, 0.04, 0.02)], [0.5, Color(0.20, 0.10, 0.05)], [1.0, Color(0.30, 0.16, 0.08)]])),
				_normal(_noise(simplex, 0.2, 2, 416), 0.6), Vector3(4.0, 0.5, 4.0), 0.28, 0.4)
		"cream":
			return _flat(Color(0.80, 0.74, 0.58), 0.3)
		"frosted":
			return _clear(Color(0.82, 0.86, 0.90, 0.5), 0.45)
		"neon_off":   # an unlit tube / lamp: dark glass with a glint
			var no: StandardMaterial3D = _flat(Color(0.10, 0.10, 0.11), 0.12)
			no.metallic_specular = 1.0
			return no
		"lamp_red_off":
			return _flat(Color(0.20, 0.03, 0.02), 0.12)
		"lamp_green_off":
			return _flat(Color(0.03, 0.13, 0.05), 0.12)
		"lamp_green":
			return _glow(Color(0.35, 1.0, 0.45), 4.0)
		"lamp_amber":
			return _glow(Color(1.0, 0.68, 0.25), 3.0)
		"bakelite":
			return _flat(Color(0.09, 0.05, 0.03), 0.22)
		"leather":
			return _surface(_tex(_noise(simplex, 0.08, 4, 421), _ramp([[0.0, Color(0.10, 0.05, 0.03)], [1.0, Color(0.26, 0.14, 0.07)]])),
				_normal(_noise(simplex, 0.3, 3, 422), 1.5), Vector3(2.0, 2.0, 2.0), 0.65)
		"wax":   # phonograph-cylinder wax
			return _flat(Color(0.22, 0.12, 0.05), 0.3)
		"nameplate":   # dark enamel backing behind gameplay labels (keeps them readable in any light)
			return _flat(Color(0.05, 0.045, 0.04), 0.45)
		"board_wood":   # a single nailed plank: grain along X, object space (boards fly off), tinted per vertex
			var bw: StandardMaterial3D = _surface(_tex(_noise(simplex, 0.02, 5, 431), _ramp([[0.0, Color(0.20, 0.15, 0.10)], [0.45, Color(0.36, 0.28, 0.19)],
				[0.8, Color(0.46, 0.37, 0.26)], [1.0, Color(0.52, 0.43, 0.31)]])), _normal(_noise(simplex, 0.15, 3, 432), 2.0),
				Vector3(0.35, 4.0, 4.0), 0.9, 0.7)
			bw.uv1_world_triplanar = false
			bw.vertex_color_use_as_albedo = true
			return bw
		"board_wood_v", "board_wood_v2":   # vertical door planks (object space: doors slide away)
			var dark: bool = key.ends_with("2")
			var bv: StandardMaterial3D = _surface(_tex(_noise(simplex, 0.02, 5, 437 if dark else 431), _ramp([[0.0, Color(0.16, 0.11, 0.07)],
				[0.5, Color(0.27, 0.2, 0.13) if dark else Color(0.34, 0.26, 0.17)], [1.0, Color(0.36, 0.28, 0.19) if dark else Color(0.46, 0.37, 0.26)]])),
				_normal(_noise(simplex, 0.15, 3, 438), 2.0), Vector3(4.0, 0.35, 4.0), 0.9, 0.7)
			bv.uv1_world_triplanar = false
			return bv
		"brass_2s":   # brass seen from inside too (horn bells)
			var b2: StandardMaterial3D = (get_mat("brass") as StandardMaterial3D).duplicate() as StandardMaterial3D
			b2.cull_mode = BaseMaterial3D.CULL_DISABLED
			return b2
		"lumi_paint":   # air-raid luminous paint (Leuchtfarbe): a faint green-white glow on edges and jambs
			var lp: StandardMaterial3D = _glow(Color(0.5, 0.95, 0.62), 0.55)
			lp.albedo_color = Color(0.62, 0.7, 0.6)
			return lp
		"felt_green":
			return _surface(_tex(_noise(simplex, 0.2, 3, 435), _ramp([[0.0, Color(0.05, 0.12, 0.07)], [1.0, Color(0.10, 0.20, 0.12)]])), null, Vector3(3, 3, 3), 1.0)
	return null


# ================================================================== Map 0 (Crossroads Inn) art pass

## Coursed rubble / flagstones in world space (walls are axis-aligned boxes): rows of constant height, random
## block widths per row, ragged recessed joints, a bevel toward each joint, a damp band rising from `floor_y`
## on vertical faces (mossy tint, low roughness), and optional wet patches on horizontal faces. No textures.
const STONE_SHADER: String = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec3 stone_dark : source_color = vec3(0.16, 0.15, 0.13);
uniform vec3 stone_light : source_color = vec3(0.46, 0.43, 0.38);
uniform vec3 mortar : source_color = vec3(0.24, 0.22, 0.19);
uniform vec3 damp_tint : source_color = vec3(0.5, 0.58, 0.52);
uniform vec2 block_size = vec2(0.55, 0.26);
uniform float joint = 0.016;
uniform float floor_y = -3.2;
uniform float damp_height = 0.9;
uniform float wet = 0.0;
varying vec3 wpos;
varying vec3 wnrm;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 an = abs(wnrm);
	vec2 uv = an.x > an.z ? wpos.zy : wpos.xy;
	float horiz = 0.0;
	if (an.y > max(an.x, an.z)) { uv = wpos.xz; horiz = 1.0; }
	float row = floor(uv.y / block_size.y);
	float rh = hash(vec2(row, 7.0));
	float bw = block_size.x * (0.75 + 0.6 * rh);
	float ux = uv.x + rh * 3.0;
	vec2 cell = vec2(floor(ux / bw), row);
	vec2 f = vec2(fract(ux / bw) * bw, fract(uv.y / block_size.y) * block_size.y);
	vec2 d = min(f, vec2(bw, block_size.y) - f);
	float edge = min(d.x, d.y) + (vnoise(uv * 35.0) - 0.5) * 0.012;
	float m = 1.0 - smoothstep(joint * 0.6, joint * 1.4, edge);
	float tone = hash(cell);
	float grime = vnoise(uv * 2.0 + cell) * 0.5 + vnoise(uv * 9.0) * 0.3;
	vec3 s = mix(stone_dark, stone_light, clamp(tone * 0.7 + grime * 0.45, 0.0, 1.0));
	s *= 0.72 + 0.28 * smoothstep(0.0, 0.07, edge);
	vec3 c = mix(s, mortar * (0.75 + grime * 0.5), m);
	float rough = mix(0.9, 0.98, m);
	float h = wpos.y - floor_y;
	float damp = (1.0 - smoothstep(0.05, damp_height, h + vnoise(uv * 3.0) * 0.5)) * (1.0 - horiz);
	c = mix(c, c * damp_tint, damp * 0.85);
	rough = mix(rough, 0.35, damp * 0.6);
	float w = wet * smoothstep(0.5, 0.72, vnoise(uv * 0.55 + 11.0)) * horiz;
	c = mix(c, c * 0.45, w);
	rough = mix(rough, 0.12, w);
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = 0.4;
	AO = 1.0 - m * 0.6;
	AO_LIGHT_AFFECT = 0.4;
}
"""

## Procedural "paintings" in canvas UV space (for QuadMesh canvases): a landscape, a bust portrait (no face),
## a hunting print, a faded group photograph, an inn licence and a still life, all built from gradients, value
## noise and simple shapes, then aged (grain, sepia fade, varnish vignette). Original; no images.
const PAINTING_SHADER: String = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform int style = 0;
uniform float seed = 1.0;
uniform vec3 col_a : source_color = vec3(0.55, 0.62, 0.72);
uniform vec3 col_b : source_color = vec3(0.25, 0.28, 0.22);
uniform vec3 col_c : source_color = vec3(0.85, 0.80, 0.70);
uniform float fade = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) { s += a * vnoise(p); p *= 2.1; a *= 0.5; }
	return s;
}
float ell(vec2 p, vec2 c, vec2 r) { vec2 q = (p - c) / r; return step(dot(q, q), 1.0); }
float seg(vec2 p, vec2 a, vec2 b, float w) {
	vec2 d = b - a;
	float t = clamp(dot(p - a, d) / dot(d, d), 0.0, 1.0);
	return step(length(p - (a + d * t)), w);
}

vec3 landscape(vec2 p) {
	vec3 sky = mix(col_c, col_a, smoothstep(0.3, 1.0, p.y));
	vec2 sp = vec2(0.3 + 0.4 * hash(vec2(seed, 3.0)), 0.74);
	sky = mix(sky, col_c * 1.2, smoothstep(0.07, 0.055, distance(p, sp)) * 0.85);
	float cl = smoothstep(0.55, 0.75, fbm(p * vec2(3.0, 7.0) + seed));
	sky = mix(sky, col_c, cl * 0.3 * smoothstep(0.45, 0.55, p.y));
	float r1 = 0.46 + 0.2 * fbm(vec2(p.x * 2.5 + seed, 1.0));
	vec3 mcol = mix(col_a * 0.5, col_c * 0.95, smoothstep(r1 - 0.12, r1 - 0.02, p.y) * 0.8);
	float r2 = 0.28 + 0.12 * fbm(vec2(p.x * 3.5 + seed * 2.0, 7.0));
	vec3 hcol = col_b * (0.55 + 0.5 * fbm(p * 8.0));
	float r3 = 0.17 + 0.03 * vnoise(vec2(p.x * 6.0, 2.0));
	vec3 fcol = mix(col_c * 0.85, col_b * 0.6, 0.35 + 0.35 * vnoise(p * vec2(12.0, 40.0)));
	vec3 c = sky;
	c = mix(c, mcol, step(p.y, r1));
	c = mix(c, hcol, step(p.y, r2));
	c = mix(c, fcol, step(p.y, r3));
	vec2 hp = vec2(0.58 + 0.2 * hash(vec2(seed, 9.0)), r3 + 0.02);
	float house = step(abs(p.x - hp.x), 0.035) * step(hp.y, p.y) * step(p.y, hp.y + 0.05);
	float roof = step(abs(p.x - hp.x), max(0.0, 0.045 - (p.y - hp.y - 0.05) * 1.3)) * step(hp.y + 0.05, p.y);
	float tower = step(abs(p.x - hp.x + 0.045), 0.008) * step(hp.y, p.y) * step(p.y, hp.y + 0.13);
	float spire = step(abs(p.x - hp.x + 0.045), max(0.0, 0.012 - (p.y - hp.y - 0.13) * 0.6)) * step(hp.y + 0.13, p.y);
	c = mix(c, col_b * 0.22, max(max(house, roof), max(tower, spire)));
	float win = step(abs(p.x - hp.x), 0.006) * step(abs(p.y - hp.y - 0.025), 0.008);
	c = mix(c, col_c * 1.1, win);
	return c;
}

vec3 portrait(vec2 p) {
	vec3 c = mix(col_b * 0.45, col_b, smoothstep(0.85, 0.15, distance(p, vec2(0.5, 0.6))));
	float body = ell(p, vec2(0.5, 0.02), vec2(0.44, 0.46));
	float collar = body * step(abs(p.x - 0.5), 0.07) * step(0.3, p.y) * step(p.y, 0.44) * step(0.05, abs(p.x - 0.5) + (p.y - 0.3) * 0.3);
	float head = ell(p, vec2(0.5, 0.6), vec2(0.14, 0.19));
	float hair = head * smoothstep(0.62, 0.7, p.y + 0.15 * abs(p.x - 0.5));
	vec3 skin = col_c * (0.7 + 0.35 * smoothstep(0.3, 0.7, p.x)) * (0.85 + 0.15 * smoothstep(0.45, 0.6, p.y));
	c = mix(c, col_a * 0.5 * (0.8 + 0.3 * vnoise(p * 25.0)), body);
	c = mix(c, col_c * 0.9, collar);
	c = mix(c, skin, head);
	c = mix(c, col_a * 0.25, hair);
	return c;
}

vec3 hunting(vec2 p) {
	vec3 paper = col_c;
	vec3 ink = col_b;
	float ground = step(p.y, 0.3 + 0.05 * vnoise(vec2(p.x * 5.0, seed)));
	vec3 c = mix(paper, mix(paper, ink, 0.35 + 0.2 * vnoise(p * 20.0)), ground);
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float tx = 0.06 + 0.22 * fi + 0.08 * hash(vec2(fi, seed));
		float w = 0.012 + 0.012 * hash(vec2(seed, fi));
		float trunk = step(abs(p.x - tx + 0.01 * sin(p.y * 20.0 + fi)), w) * step(0.22, p.y);
		c = mix(c, ink * 0.8, trunk * (0.8 + 0.2 * vnoise(p * 30.0)));
		float cnp = smoothstep(0.2, 0.1, distance(p, vec2(tx, 0.8 + 0.12 * hash(vec2(seed + 1.0, fi))))) * (0.4 + 0.5 * fbm(p * 15.0 + fi));
		c = mix(c, ink * 0.9, cnp * 0.85);
	}
	vec2 sc = vec2(0.5, 0.4);
	float stag = ell(p, sc, vec2(0.13, 0.07));
	stag = max(stag, ell(p, sc + vec2(0.11, 0.08), vec2(0.035, 0.09)));
	stag = max(stag, ell(p, sc + vec2(0.145, 0.17), vec2(0.05, 0.028)));
	for (int k = 0; k < 4; k++) {
		float lx = sc.x - 0.09 + 0.06 * float(k);
		stag = max(stag, seg(p, vec2(lx, sc.y), vec2(lx + 0.01 * float(k % 2), sc.y - 0.2), 0.008));
	}
	vec2 ab = sc + vec2(0.15, 0.19);
	for (int k = 0; k < 2; k++) {
		float s = (k == 0) ? -1.0 : 1.0;
		vec2 tip = ab + vec2(s * 0.06, 0.12);
		stag = max(stag, seg(p, ab, tip, 0.006));
		stag = max(stag, seg(p, mix(ab, tip, 0.5), mix(ab, tip, 0.5) + vec2(s * 0.05, 0.02), 0.005));
		stag = max(stag, seg(p, mix(ab, tip, 0.8), mix(ab, tip, 0.8) + vec2(s * 0.03, 0.035), 0.005));
	}
	c = mix(c, ink * 0.5, stag);
	return c;
}

vec3 photo(vec2 p) {
	vec3 c = mix(col_b, col_c, 0.5 + 0.25 * vnoise(p * 6.0));
	float win = 0.0;
	for (int i = 0; i < 3; i++) {
		vec2 wc = vec2(0.2 + 0.3 * float(i), 0.74);
		win = max(win, step(abs(p.x - wc.x), 0.06) * step(abs(p.y - wc.y), 0.09));
	}
	c = mix(c, col_b * 0.45, win);
	c = mix(c, mix(col_b, col_c, 0.4) * (0.9 + 0.2 * vnoise(p * 15.0)), step(p.y, 0.2));
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		float fx = 0.2 + 0.2 * fi + 0.04 * hash(vec2(seed, fi));
		float fh = 0.48 + 0.1 * hash(vec2(fi, seed));
		float bodyf = ell(p, vec2(fx, 0.2), vec2(0.075, fh - 0.06)) * step(0.0, p.y - 0.14);
		bodyf = max(bodyf, step(abs(p.x - fx), 0.07) * step(0.14, p.y) * step(p.y, 0.2 + (fh - 0.06) * 0.5));
		float headf = step(distance(p, vec2(fx, 0.2 + fh - 0.03)), 0.045);
		vec3 fc = (i % 2 == 0) ? col_b * 0.45 : col_b * 0.75;
		c = mix(c, fc, bodyf);
		c = mix(c, mix(col_c, col_b, 0.3), headf);
	}
	return c;
}

vec3 licence(vec2 p) {
	vec3 c = col_c * (0.9 + 0.1 * vnoise(p * 30.0));
	c = mix(c, col_b, 0.3 * smoothstep(0.55, 0.85, fbm(p * 4.0 + seed)));
	float head = step(abs(p.x - 0.5), 0.26) * step(abs(p.y - 0.85), 0.028);
	head = max(head, step(abs(p.x - 0.5), 0.18) * step(abs(p.y - 0.78), 0.012));
	float lines = 0.0;
	for (int i = 0; i < 9; i++) {
		float fi = float(i);
		float ly = 0.7 - 0.052 * fi;
		float len = 0.5 + 0.3 * hash(vec2(fi, seed));
		float ln = step(abs(p.y - ly), 0.007) * step(0.12, p.x) * step(p.x, 0.12 + len) * step(0.35, vnoise(vec2(p.x * 70.0, fi * 3.0)));
		lines = max(lines, ln);
	}
	c = mix(c, col_b * 0.35, max(head, lines) * 0.9);
	float sd = distance(p, vec2(0.78, 0.17));
	c = mix(c, col_a, smoothstep(0.075, 0.07, sd) * 0.9);
	c = mix(c, col_a * 0.6, smoothstep(0.06, 0.055, sd) - smoothstep(0.045, 0.04, sd));
	float sig = step(abs(p.y - (0.2 + 0.025 * sin(p.x * 60.0) + 0.02 * sin(p.x * 23.0 + seed))), 0.005) * step(0.15, p.x) * step(p.x, 0.5);
	c = mix(c, col_b * 0.3, sig);
	c *= 1.0 - 0.15 * smoothstep(0.012, 0.0, abs(p.y - 0.5));
	return c;
}

vec3 stilllife(vec2 p) {
	vec3 c = mix(col_b * 0.35, col_b * 0.8, p.y);
	c += col_c * 0.15 * smoothstep(0.7, 0.0, distance(p, vec2(0.3, 0.8)));
	c = mix(c, col_b * 0.6 * (0.8 + 0.3 * vnoise(p * 20.0)), step(p.y, 0.32));
	c = mix(c, col_c * 0.5, step(abs(p.y - 0.32), 0.006));
	float bottle = max(step(abs(p.x - 0.3), 0.06) * step(0.3, p.y) * step(p.y, 0.62), step(abs(p.x - 0.3), 0.02) * step(0.62, p.y) * step(p.y, 0.78));
	c = mix(c, col_a * 0.45, bottle);
	c = mix(c, col_c, bottle * 0.5 * smoothstep(0.04, 0.0, abs(p.x - 0.27)));
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		vec2 fc = vec2(0.5 + 0.13 * fi - 0.06 * float(i % 2), 0.37 + 0.04 * float(i % 2));
		float r = 0.055 + 0.012 * hash(vec2(fi, seed));
		float fr = step(distance(p, fc), r);
		vec3 col = (i % 2 == 0) ? col_a : mix(col_a, col_c, 0.5);
		col *= 0.55 + 0.6 * smoothstep(r, 0.0, distance(p, fc - vec2(0.02, -0.02)));
		c = mix(c, col, fr);
	}
	return c;
}

void fragment() {
	vec2 p = vec2(UV.x, 1.0 - UV.y);
	vec3 c;
	if (style == 0) { c = landscape(p); }
	else if (style == 1) { c = portrait(p); }
	else if (style == 2) { c = hunting(p); }
	else if (style == 3) { c = photo(p); }
	else if (style == 4) { c = licence(p); }
	else { c = stilllife(p); }
	c *= 0.92 + 0.12 * vnoise(p * 160.0);
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 sep = vec3(lum) * vec3(1.1, 0.9, 0.65);
	c = mix(c, mix(sep, col_c * 0.9, 0.25), fade);
	float vig = smoothstep(0.0, 0.22, p.x) * smoothstep(1.0, 0.78, p.x) * smoothstep(0.0, 0.22, p.y) * smoothstep(1.0, 0.78, p.y);
	c *= 0.62 + 0.38 * vig;
	ALBEDO = c;
	ROUGHNESS = (style >= 2 && style <= 4) ? 0.9 : 0.45;
	SPECULAR = 0.35;
}
"""

static var _stone_shader: Shader
static var _painting_shader: Shader

## Styles: name -> [index, [palettes: [col_a, col_b, col_c, fade], ...]] (the seed picks the palette).
const PAINTING_STYLES: Dictionary = {
	"landscape": [0, [[Color(0.42, 0.50, 0.66), Color(0.20, 0.24, 0.17), Color(0.88, 0.82, 0.70), 0.15],
		[Color(0.62, 0.42, 0.36), Color(0.16, 0.14, 0.12), Color(0.95, 0.80, 0.55), 0.25],
		[Color(0.22, 0.28, 0.45), Color(0.12, 0.14, 0.16), Color(0.80, 0.84, 0.92), 0.1]]],
	"portrait": [1, [[Color(0.16, 0.12, 0.09), Color(0.30, 0.22, 0.14), Color(0.85, 0.70, 0.55), 0.3],
		[Color(0.10, 0.11, 0.14), Color(0.26, 0.24, 0.20), Color(0.80, 0.68, 0.56), 0.35]]],
	"hunting": [2, [[Color(0.5, 0.4, 0.3), Color(0.28, 0.18, 0.10), Color(0.84, 0.76, 0.60), 0.4]]],
	"photo": [3, [[Color(0.5, 0.4, 0.3), Color(0.30, 0.24, 0.18), Color(0.78, 0.72, 0.60), 0.85]]],
	"licence": [4, [[Color(0.55, 0.12, 0.08), Color(0.22, 0.16, 0.10), Color(0.84, 0.78, 0.62), 0.3]]],
	"stilllife": [5, [[Color(0.60, 0.22, 0.12), Color(0.30, 0.20, 0.12), Color(0.85, 0.72, 0.45), 0.2],
		[Color(0.45, 0.50, 0.20), Color(0.24, 0.18, 0.12), Color(0.80, 0.74, 0.52), 0.25]]],
}


static func _stone(dark: Color, light: Color, mortar: Color, damp: Color, block: Vector2, joint: float, floor_y: float,
		damp_h: float, wet: float) -> ShaderMaterial:
	if _stone_shader == null:
		_stone_shader = Shader.new()
		_stone_shader.code = STONE_SHADER
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = _stone_shader
	m.set_shader_parameter("stone_dark", Vector3(dark.r, dark.g, dark.b))
	m.set_shader_parameter("stone_light", Vector3(light.r, light.g, light.b))
	m.set_shader_parameter("mortar", Vector3(mortar.r, mortar.g, mortar.b))
	m.set_shader_parameter("damp_tint", Vector3(damp.r, damp.g, damp.b))
	m.set_shader_parameter("block_size", block)
	m.set_shader_parameter("joint", joint)
	m.set_shader_parameter("floor_y", floor_y)
	m.set_shader_parameter("damp_height", damp_h)
	m.set_shader_parameter("wet", wet)
	return m


## Map 0 art-pass materials: the Helvetia cellar, the stairwell and its framed pictures ("painting:<style>:<n>").
static func _build_map0(key: String) -> Material:
	var simplex: FastNoiseLite.NoiseType = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var cell: FastNoiseLite.NoiseType = FastNoiseLite.TYPE_CELLULAR
	if key.begins_with("painting:"):
		var parts: PackedStringArray = key.split(":")
		var style: Array = PAINTING_STYLES.get(parts[1] if parts.size() > 1 else "landscape", PAINTING_STYLES["landscape"])
		var n: int = parts[2].to_int() if parts.size() > 2 else 0
		var pals: Array = style[1]
		var pal: Array = pals[n % pals.size()]
		if _painting_shader == null:
			_painting_shader = Shader.new()
			_painting_shader.code = PAINTING_SHADER
		var pm: ShaderMaterial = ShaderMaterial.new()
		pm.shader = _painting_shader
		pm.set_shader_parameter("style", int(style[0]))
		pm.set_shader_parameter("seed", float(n) * 1.7 + 0.37)
		for i: int in 3:
			var c: Color = pal[i]
			pm.set_shader_parameter(["col_a", "col_b", "col_c"][i], Vector3(c.r, c.g, c.b))
		pm.set_shader_parameter("fade", float(pal[3]))
		return pm
	match key:
		"cellar_stone":   # the vault: coursed grey-brown rubble, mossy damp at the floor
			return _stone(Color(0.13, 0.12, 0.105), Color(0.34, 0.32, 0.28), Color(0.17, 0.16, 0.14), Color(0.5, 0.6, 0.5),
				Vector2(0.42, 0.2), 0.011, -3.2, 0.9, 0.0)
		"cellar_floor":   # big worn flagstones, wet patches
			return _stone(Color(0.12, 0.11, 0.10), Color(0.32, 0.30, 0.27), Color(0.08, 0.075, 0.07), Color(0.6, 0.6, 0.55),
				Vector2(0.8, 0.55), 0.018, -3.2, 0.0, 1.0)
		"limewash":   # the stair hall: limewashed rubble, grimy toward the steps
			return _stone(Color(0.46, 0.44, 0.39), Color(0.66, 0.64, 0.58), Color(0.50, 0.48, 0.43), Color(0.62, 0.58, 0.50),
				Vector2(0.42, 0.2), 0.009, -3.2, 1.2, 0.0)
		"brick_cellar":   # old handmade brick for the vault soffit and arches, lime mortar
			var bs: Shader = Shader.new()
			bs.code = BRICK_SHADER
			var bm: ShaderMaterial = ShaderMaterial.new()
			bm.shader = bs
			bm.set_shader_parameter("brick_dark", Vector3(0.20, 0.10, 0.07))
			bm.set_shader_parameter("brick_light", Vector3(0.44, 0.26, 0.17))
			bm.set_shader_parameter("mortar", Vector3(0.46, 0.43, 0.37))
			bm.set_shader_parameter("brick_size", Vector2(0.24, 0.07))
			bm.set_shader_parameter("joint", 0.012)
			return bm
		"oak_stave":   # barrel staves (vertical boards, lighter oak)
			return _boards(501, [[0.0, Color(0.28, 0.19, 0.11)], [0.5, Color(0.40, 0.28, 0.16)], [1.0, Color(0.48, 0.35, 0.21)]], Vector3(3.0, 0.1, 3.0), 0.8)
		"puddle":
			var pd: StandardMaterial3D = _clear(Color(0.02, 0.03, 0.04, 0.62), 0.03)
			pd.metallic = 0.2
			return pd
		"cobweb":   # a cellular lattice ramped into alpha: strands, seen from both sides
			var wn: FastNoiseLite = _noise(cell, 0.18, 1, 511)
			wn.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
			wn.cellular_jitter = 0.8
			var wm: StandardMaterial3D = _surface(_tex(wn, _ramp([[0.0, Color(0.55, 0.55, 0.5, 0.4)], [0.04, Color(0.5, 0.5, 0.45, 0.14)],
				[0.1, Color(0.5, 0.5, 0.45, 0.0)], [1.0, Color(0.5, 0.5, 0.45, 0.0)]])), null, Vector3(3.0, 3.0, 3.0), 1.0)
			wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			wm.cull_mode = BaseMaterial3D.CULL_DISABLED
			wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			return wm
		"runner":   # stair/hall runner: deep red with a woven pattern
			var rn: FastNoiseLite = _noise(cell, 0.14, 1, 521)
			rn.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
			return _surface(_tex(rn, _ramp([[0.0, Color(0.26, 0.06, 0.05)], [0.5, Color(0.40, 0.11, 0.06)], [0.75, Color(0.34, 0.20, 0.09)], [1.0, Color(0.30, 0.08, 0.05)]])),
				_normal(_noise(simplex, 0.5, 2, 522), 0.8), Vector3(3.0, 3.0, 3.0), 1.0)
		"mirror":
			return _flat(Color(0.55, 0.57, 0.60), 0.04, 1.0)
		"frame_walnut":
			return _flat(Color(0.15, 0.08, 0.04), 0.45)
		"frame_black":
			return _flat(Color(0.05, 0.05, 0.05), 0.5)
		"gilt":
			return _flat(Color(0.58, 0.44, 0.18), 0.32, 0.85)
		"paper_old":
			return _flat(Color(0.60, 0.53, 0.38), 0.95)
		"jar_red":   # preserves
			return _clear(Color(0.45, 0.12, 0.06, 0.78), 0.1)
		"tin":   # galvanised lamp shades, buckets
			return _flat(Color(0.52, 0.53, 0.52), 0.45, 0.65)
		"plaster_cellar":   # the hall's plaster strip above the limewash (upstairs-stair match)
			return get_mat("plaster_upper")
		"wainscot_matte":   # the stairwell's sloped panels: the same boards without the varnish highlight
			var wmat: StandardMaterial3D = (get_mat("wainscot") as StandardMaterial3D).duplicate() as StandardMaterial3D
			wmat.roughness = 0.88
			return wmat
	return null


# ================================================================== Map 2 (Totenhafen) additions (T-036)

## The Baltic in a winter storm: a flat plane that the vertex shader heaves with crossing wind chop, dark
## green-black water with a cold fresnel sheen, foam streaks along the crests, and a soft depth fade at the
## edges. The tide controller moves the plane; the shader does not need to know.
const SEA_SHADER: String = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;
uniform vec3 deep : source_color = vec3(0.012, 0.035, 0.045);
uniform vec3 shallow : source_color = vec3(0.05, 0.12, 0.13);
uniform vec3 foam : source_color = vec3(0.55, 0.62, 0.64);
uniform float amp = 0.18;
uniform float chop = 0.9;
uniform float speed = 1.0;
uniform float alpha = 0.9;
varying float crest;

float wave(vec2 p, vec2 dir, float k, float w, float t) {
	return sin(dot(p, dir) * k + t * w);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * speed;
	float h = wave(wp.xz, vec2(0.80, 0.60), 0.55, 1.7, t) * 0.5
		+ wave(wp.xz, vec2(-0.35, 0.94), 1.10, 2.6, t) * 0.3
		+ wave(wp.xz, vec2(0.98, -0.20), 2.30, 3.9, t) * 0.2;
	VERTEX.y += h * amp;
	crest = clamp(h * 0.5 + 0.5, 0.0, 1.0);
	float dx = cos(wp.x * 0.55 + t * 1.7) * 0.55 * amp;
	float dz = cos(wp.z * 1.10 + t * 2.6) * 1.10 * amp * chop;
	NORMAL = normalize(vec3(-dx, 1.0, -dz));
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	vec3 col = mix(deep, shallow, fres * 0.8 + crest * 0.2);
	float streak = smoothstep(0.78, 0.96, crest);
	col = mix(col, foam, streak * 0.35);
	ALBEDO = col;
	ROUGHNESS = 0.08 + streak * 0.5;
	METALLIC = 0.0;
	SPECULAR = 0.6;
	ALPHA = alpha;
}
"""
static var _sea_shader: Shader


static func _build_map2(key: String) -> Material:
	var simplex: FastNoiseLite.NoiseType = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var cell: FastNoiseLite.NoiseType = FastNoiseLite.TYPE_CELLULAR
	match key:
		"sea_water":   # the Baltic, in the pens and off the quay (vertex-heaved plane)
			if _sea_shader == null:
				_sea_shader = Shader.new()
				_sea_shader.code = SEA_SHADER
			var sm: ShaderMaterial = ShaderMaterial.new()
			sm.shader = _sea_shader
			return sm
		"bunker_concrete":   # cold shuttered concrete, board marks, damp streaks: the 18 m bunker
			var bn: FastNoiseLite = _noise(simplex, 0.025, 5, 611)
			var m: StandardMaterial3D = _surface(_tex(bn, _ramp([[0.0, Color(0.22, 0.23, 0.24)], [0.4, Color(0.31, 0.32, 0.33)],
				[0.75, Color(0.38, 0.39, 0.39)], [1.0, Color(0.44, 0.44, 0.43)]])),
				_normal(_noise(cell, 0.05, 2, 612), 1.6), Vector3(0.3, 0.3, 0.3), 0.9, 0.6)
			var streak: FastNoiseLite = _noise(simplex, 0.5, 2, 613)
			m.detail_enabled = true
			m.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
			m.detail_uv_layer = BaseMaterial3D.DETAIL_UV_1
			m.detail_albedo = _tex(streak, _ramp([[0.0, Color(0.62, 0.64, 0.66)], [0.5, Color(1, 1, 1)], [1.0, Color(1, 1, 1)]]))
			return m
		"wet_concrete":   # the quay and the pier decks: darker, glossier, puddled
			return _surface(_tex(_noise(simplex, 0.02, 5, 621), _ramp([[0.0, Color(0.09, 0.10, 0.11)], [0.35, Color(0.17, 0.18, 0.19)],
				[0.7, Color(0.24, 0.25, 0.25)], [1.0, Color(0.30, 0.30, 0.29)]])),
				_normal(_noise(simplex, 0.08, 3, 622), 0.9), Vector3(0.25, 0.25, 0.25), 0.42, 0.4)
		"pier_concrete":   # pier and apron sides seen from the water: tide-stained, algae at the foot
			return _surface(_tex(_noise(simplex, 0.03, 5, 625), _ramp([[0.0, Color(0.10, 0.13, 0.11)], [0.3, Color(0.22, 0.24, 0.22)],
				[0.7, Color(0.33, 0.34, 0.33)], [1.0, Color(0.40, 0.40, 0.39)]])),
				_normal(_noise(cell, 0.05, 2, 626), 1.4), Vector3(0.3, 0.12, 0.3), 0.85, 0.6)
		"u_hull":   # the boat: grey-black anti-fouling with rust weeping from the seams
			return _surface(_tex(_noise(simplex, 0.08, 5, 631), _ramp([[0.0, Color(0.05, 0.05, 0.055)], [0.55, Color(0.12, 0.12, 0.13)],
				[0.85, Color(0.18, 0.18, 0.19)], [1.0, Color(0.30, 0.17, 0.10)]])),
				_normal(_noise(simplex, 0.25, 3, 632), 1.2), Vector3(1.0, 1.0, 1.0), 0.55, 0.6, 0.5)
		"u_interior":   # the pressure hull inside: grey-green paint, sweat and grime
			return _surface(_tex(_noise(simplex, 0.06, 4, 635), _ramp([[0.0, Color(0.14, 0.17, 0.15)], [0.6, Color(0.25, 0.29, 0.26)], [1.0, Color(0.34, 0.37, 0.33)]])),
				_normal(_noise(simplex, 0.2, 3, 636), 1.0), Vector3(0.8, 0.8, 0.8), 0.6, 0.5, 0.3)
		"lead":   # the sealed coffins: dull, soft, scratched
			return _surface(_tex(_noise(simplex, 0.1, 4, 641), _ramp([[0.0, Color(0.20, 0.21, 0.23)], [0.6, Color(0.30, 0.31, 0.33)], [1.0, Color(0.38, 0.39, 0.40)]])),
				_normal(_noise(simplex, 0.4, 2, 642), 0.6), Vector3(2.0, 2.0, 2.0), 0.55, 0.4, 0.8)
		"rope":   # hemp hawsers, mooring lines
			return _surface(_tex(_noise(cell, 0.9, 1, 651), _ramp([[0.0, Color(0.30, 0.24, 0.14)], [1.0, Color(0.48, 0.40, 0.25)]])),
				_normal(_noise(cell, 0.9, 1, 652), 2.0), Vector3(6.0, 6.0, 6.0), 0.95)
		"net":   # heaped fishing nets: dark olive, matted
			var nn: FastNoiseLite = _noise(cell, 0.6, 2, 655)
			nn.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
			return _surface(_tex(nn, _ramp([[0.0, Color(0.08, 0.10, 0.06)], [0.5, Color(0.16, 0.19, 0.11)], [1.0, Color(0.24, 0.26, 0.16)]])),
				_normal(nn, 2.5), Vector3(4.0, 4.0, 4.0), 1.0)
		"zinc":   # gutting tables, cannery lines
			return _surface(_tex(_noise(simplex, 0.15, 3, 661), _ramp([[0.0, Color(0.40, 0.42, 0.43)], [1.0, Color(0.56, 0.58, 0.58)]])),
				_normal(_noise(simplex, 0.5, 2, 662), 0.5), Vector3(1.5, 1.5, 1.5), 0.38, 0.4, 0.7)
		"tide_mark":   # the high-water band: wet black-green slime
			return _surface(_tex(_noise(simplex, 0.3, 3, 665), _ramp([[0.0, Color(0.03, 0.05, 0.04)], [1.0, Color(0.09, 0.13, 0.10)]])),
				null, Vector3(1.0, 1.0, 1.0), 0.25)
		"weed":   # bladderwrack on the grilles and the boat's waterline
			return _surface(_tex(_noise(cell, 0.5, 2, 668), _ramp([[0.0, Color(0.06, 0.09, 0.05)], [0.6, Color(0.12, 0.16, 0.08)], [1.0, Color(0.20, 0.22, 0.10)]])),
				_normal(_noise(cell, 0.5, 2, 669), 2.0), Vector3(3.0, 3.0, 3.0), 0.7)
		"bulb_cold":   # the pen hall's mercury floods and the boat's white lamps, lit
			return _glow(Color(0.82, 0.9, 1.0), 4.5)
		"lamp_red_lit":   # battle lanterns in the boat
			return _glow(Color(1.0, 0.22, 0.14), 3.5)
		"signal_glass":   # the signal lamp's lens
			return _glow(Color(1.0, 0.92, 0.75), 6.0)
		"hull_red":   # the boat's lower hull, red lead
			return _surface(_tex(_noise(simplex, 0.08, 4, 672), _ramp([[0.0, Color(0.22, 0.07, 0.05)], [0.7, Color(0.36, 0.12, 0.08)], [1.0, Color(0.30, 0.19, 0.12)]])),
				_normal(_noise(simplex, 0.25, 3, 673), 1.0), Vector3(1.0, 1.0, 1.0), 0.7, 0.5, 0.3)
		"brass_plate":
			return _flat(Color(0.62, 0.50, 0.24), 0.3, 0.9)
		"grey_paint":   # torpedo bodies, cradles, the crane
			return _surface(_tex(_noise(simplex, 0.1, 4, 676), _ramp([[0.0, Color(0.30, 0.31, 0.30)], [1.0, Color(0.44, 0.45, 0.43)]])),
				_normal(_noise(simplex, 0.3, 2, 677), 0.6), Vector3(1.0, 1.0, 1.0), 0.5, 0.4, 0.4)
		"crane_yellow":
			return _surface(_tex(_noise(simplex, 0.1, 4, 681), _ramp([[0.0, Color(0.45, 0.33, 0.08)], [0.6, Color(0.66, 0.50, 0.12)], [1.0, Color(0.72, 0.58, 0.18)]])),
				_normal(_noise(simplex, 0.3, 2, 682), 0.8), Vector3(1.0, 1.0, 1.0), 0.6, 0.5, 0.3)
		"shingle":   # the beach beyond the cannery windows
			var sh: FastNoiseLite = _noise(cell, 0.9, 1, 685)
			sh.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
			return _surface(_tex(sh, _ramp([[0.0, Color(0.14, 0.14, 0.13)], [0.5, Color(0.26, 0.25, 0.23)], [1.0, Color(0.36, 0.34, 0.31)]])),
				_normal(_noise(cell, 0.9, 1, 686), 2.5), Vector3(4.0, 4.0, 4.0), 0.9)
		"cliff":   # the headland behind the harbour
			return _rock(691, [[0.0, Color(0.08, 0.09, 0.09)], [0.4, Color(0.16, 0.17, 0.17)], [0.8, Color(0.24, 0.24, 0.23)], [1.0, Color(0.30, 0.30, 0.28)]],
				Vector3(0.1, 0.03, 0.1), 0.0, 2.0)
		"can_tin":   # stacked cans
			return _flat(Color(0.58, 0.58, 0.55), 0.35, 0.8)
		"dial_red":
			return _flat(Color(0.5, 0.08, 0.06), 0.5)
	return null
