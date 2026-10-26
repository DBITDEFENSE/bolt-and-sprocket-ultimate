// GRAVELIGHT wonder weapons (T-090): the baked body of a wonder weapon. The texture set is painted per material
// (brass, bronze, painted steel, wood, leather, porcelain, rope... tools_src/blender/wonder/wonder_lib.py), so unlike
// the shared gun shader (weapon.gdshader, which has to guess wood from metal on downloaded models) this one trusts the
// maps: albedo, OpenGL normal, ORM exactly as baked. On top:
//   frost       rime on the up faces on cold maps (WonderLook passes WeaponShader's per-map value);
//   patina      the Crucible look of a weapon whose upgrade is a colour (Mitternacht's midnight-blue patina): tints the
//               metal only (by the ORM metallic), with its own roughness;
//   veins       Nachtglas veins glowing through the metal (0 = none; a weapon's model_fit decides);
//   energy      per-instance brightness of the veins (the drivers pulse it).
shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic;
uniform float normal_depth = 1.0;
uniform float frost = 0.0;
uniform vec3 up_axis = vec3(0.0, 1.0, 0.0);
uniform vec4 patina : source_color = vec4(0.16, 0.22, 0.42, 0.0);
uniform float patina_rough = 0.45;
uniform float veins = 0.0;
uniform vec4 vein_color : source_color = vec4(0.55, 0.2, 1.0, 1.0);
instance uniform float energy = 1.0;
instance uniform float flash = 0.0;   // (same order as the other wonder shaders)

varying vec3 v_pos;
varying vec3 v_nrm;

float h31(vec3 p) {
	p = fract(p * vec3(0.1031, 0.103, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float vn(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h31(i), h31(i + vec3(1, 0, 0)), f.x), mix(h31(i + vec3(0, 1, 0)), h31(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h31(i + vec3(0, 0, 1)), h31(i + vec3(1, 0, 1)), f.x), mix(h31(i + vec3(0, 1, 1)), h31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	return vn(p) * 0.5 + vn(p * 2.03 + 7.1) * 0.3 + vn(p * 4.1 + 3.3) * 0.2;
}

void vertex() {
	v_pos = VERTEX;
	v_nrm = NORMAL;
}

void fragment() {
	vec3 col = texture(albedo_tex, UV).rgb;
	vec3 orm = texture(orm_tex, UV).rgb;
	float ao = orm.r;
	float rough = orm.g;
	float metal = orm.b;
	if (patina.a > 0.0) {
		float lum = dot(col, vec3(0.3, 0.59, 0.11));
		float k = patina.a * smoothstep(0.3, 0.8, metal);
		float var = fbm(v_pos * 40.0);
		col = mix(col, patina.rgb * (0.45 + lum * 1.1) * mix(0.8, 1.15, var), k);
		rough = mix(rough, patina_rough, k * 0.8);
	}
	float up_face = dot(normalize(v_nrm), normalize(up_axis));
	float rime = frost * smoothstep(0.1, 0.75, up_face) * smoothstep(0.35, 0.7, fbm(v_pos * 70.0));
	col = mix(col, vec3(0.84, 0.9, 0.98), rime);
	rough = mix(rough, 0.88, rime);
	metal *= 1.0 - rime;
	vec3 emis = vec3(0.0);
	if (veins > 0.0) {
		float v1 = 1.0 - abs(2.0 * fbm(v_pos * 45.0 + 41.0) - 1.0);
		float vein = smoothstep(0.9, 0.97, v1) * smoothstep(0.3, 0.8, metal);
		emis = vein * vein_color.rgb * veins * energy * (2.4 + flash * 3.0);
		col = mix(col, col * vec3(0.5, 0.4, 0.62), veins * 0.4);
	}
	ALBEDO = col;
	METALLIC = metal;
	ROUGHNESS = clamp(rough, 0.04, 1.0);
	AO = ao;
	AO_LIGHT_AFFECT = 0.4;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
	EMISSION = emis;
}
