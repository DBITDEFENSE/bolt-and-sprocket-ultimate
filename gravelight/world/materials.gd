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
