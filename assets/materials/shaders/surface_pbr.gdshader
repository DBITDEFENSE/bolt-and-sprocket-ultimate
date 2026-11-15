shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;
// GRAVELIGHT's shared world surface (docs/ART_BIBLE.md section 3, UPDATE_05 section 1, T-088).
// Albedo + normal (OpenGL +Y) + ORM (R occlusion, G roughness, B metallic) from the CC0 library, with the three wear
// parameters every world material exposes: grime (a world-space noise mask, strongest near the floor and in the
// occluded corners), wetness (darker albedo, roughness toward 0.15) and a frost edge (a pale rim on up-facing
// surfaces above frost_height). Triplanar (world space) for the generator's untextured boxes, plain UVs for props.
// Vertex colour can mask the wear per vertex (R grime, G wetness, B frost) when use_vertex_mask is on.
// UPDATE 19 (T-252), triplanar surfaces only (surface_variation.gdshaderinc): macro_var, a slow world-space brightness
// drift on every big surface; detile, a second larger sample blended in patches and with distance (ground: snow,
// yards, concrete floors; data/gravelight/materials.json turns it on per key); sparkle, snow glints that only a light
// can set off. A scene baked before U19 has none of the three uniforms and takes the defaults below; the per-key
// values reach it at load (MaterialLibrary.apply_runtime).

#include "surface_variation.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform float albedo_saturation : hint_range(0.0, 1.0) = 1.0;   // U12 T-208: the material pass desaturates a texture that fights the palette
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
uniform float rough_min : hint_range(0.0, 1.0) = 0.0;
uniform float rough_max : hint_range(0.0, 1.0) = 1.0;
uniform float metallic_mul : hint_range(0.0, 1.0) = 1.0;
uniform float ao_strength : hint_range(0.0, 1.0) = 1.0;
uniform float specular_amount : hint_range(0.0, 1.0) = 0.5;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy : hint_range(0.0, 8.0) = 0.0;

// Mapping: triplanar in world space (tiles per metre per axis) or the mesh's UVs scaled by uv_scale.xy.
uniform bool triplanar = true;
uniform vec3 uv_scale = vec3(0.5, 0.5, 0.5);
uniform float triplanar_sharpness : hint_range(0.5, 16.0) = 4.0;

// Wear.
uniform float grime : hint_range(0.0, 1.0) = 0.35;
uniform vec4 grime_tint : source_color = vec4(0.42, 0.37, 0.30, 1.0);
uniform float grime_floor_y = 0.0;          // world y of the floor the grime climbs from
uniform float grime_height : hint_range(0.05, 4.0) = 0.7;   // metres it climbs
uniform float grime_scale : hint_range(0.05, 4.0) = 0.6;    // noise feature size, metres
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform float frost : hint_range(0.0, 1.0) = 0.0;
uniform vec4 frost_tint : source_color = vec4(0.86, 0.90, 0.97, 1.0);
uniform float frost_height = -1000.0;       // world y above which frost sits
uniform float frost_softness : hint_range(0.05, 3.0) = 0.6;
uniform float frost_up : hint_range(0.0, 1.0) = 0.45;      // how up-facing a surface must be
uniform bool use_vertex_mask = false;

// Variation (T-252).
uniform float macro_var : hint_range(0.0, 1.0) = 0.18;
uniform float macro_scale : hint_range(1.0, 40.0) = 7.0;   // metres
uniform float detile : hint_range(0.0, 1.0) = 0.0;
uniform float sparkle : hint_range(0.0, 1.0) = 0.0;

varying vec3 tri_pos;
varying vec3 tri_w;
varying vec3 world_pos;
varying vec3 world_nrm;
varying vec3 vmask;

void vertex() {
	vec3 wn = normalize(mat3(MODEL_MATRIX) * NORMAL);
	world_nrm = wn;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vmask = use_vertex_mask ? COLOR.rgb : vec3(1.0);
	if (triplanar) {
		tri_w = pow(abs(wn), vec3(triplanar_sharpness));
		tri_w /= dot(tri_w, vec3(1.0));
		tri_pos = world_pos * uv_scale;
		tri_pos *= vec3(1.0, -1.0, 1.0);
		// Godot's triplanar tangent frame (StandardMaterial3D): per dominant axis of the model-space normal.
		TANGENT = vec3(0.0, 0.0, -1.0) * abs(NORMAL.x) + vec3(1.0, 0.0, 0.0) * abs(NORMAL.y) + vec3(1.0, 0.0, 0.0) * abs(NORMAL.z);
		TANGENT = normalize(TANGENT);
		BINORMAL = vec3(0.0, 1.0, 0.0) * abs(NORMAL.x) + vec3(0.0, 0.0, -1.0) * abs(NORMAL.y) + vec3(0.0, 1.0, 0.0) * abs(NORMAL.z);
		BINORMAL = normalize(BINORMAL);
	} else {
		UV = UV * uv_scale.xy;
	}
}

vec4 tri_sample(sampler2D tex, vec3 w, vec3 p) {
	vec4 s = texture(tex, p.xy) * w.z;
	s += texture(tex, p.xz) * w.y;
	s += texture(tex, p.zy * vec2(-1.0, 1.0)) * w.x;
	return s;
}

float hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

// Two-octave value noise in world space, 0..1.
float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash3(i), n100 = hash3(i + vec3(1, 0, 0)), n010 = hash3(i + vec3(0, 1, 0)), n110 = hash3(i + vec3(1, 1, 0));
	float n001 = hash3(i + vec3(0, 0, 1)), n101 = hash3(i + vec3(1, 0, 1)), n011 = hash3(i + vec3(0, 1, 1)), n111 = hash3(i + vec3(1, 1, 1));
	float x00 = mix(n000, n100, f.x), x10 = mix(n010, n110, f.x), x01 = mix(n001, n101, f.x), x11 = mix(n011, n111, f.x);
	return mix(mix(x00, x10, f.y), mix(x01, x11, f.y), f.z);
}

float noise2(vec3 p) {
	return vnoise(p) * 0.65 + vnoise(p * 2.7 + 11.3) * 0.35;
}

void fragment() {
	vec4 alb;
	vec3 nrm;
	vec3 orm;
	if (triplanar) {
		alb = tri_sample(albedo_tex, tri_w, tri_pos);
		nrm = tri_sample(normal_tex, tri_w, tri_pos).rgb;
		orm = tri_sample(orm_tex, tri_w, tri_pos).rgb;
	} else {
		alb = texture(albedo_tex, UV);
		nrm = texture(normal_tex, UV).rgb;
		orm = texture(orm_tex, UV).rgb;
	}
	float cam_dist = length(CAMERA_POSITION_WORLD - world_pos);
	if (triplanar && detile > 0.001) {
		float dk = sv_detile_k(world_pos, cam_dist, detile);
		vec3 p2 = tri_pos * SV_DETILE_SCALE + SV_DETILE_OFFSET;
		alb = mix(alb, tri_sample(albedo_tex, tri_w, p2), dk);
		nrm = mix(nrm, tri_sample(normal_tex, tri_w, p2).rgb, dk);
	}
	vec3 albedo = alb.rgb * albedo_tint.rgb;
	if (triplanar) {
		albedo *= sv_macro(world_pos, macro_scale, macro_var);
	}
	albedo = mix(vec3(dot(albedo, vec3(0.299, 0.587, 0.114))), albedo, albedo_saturation);
	float ao = mix(1.0, orm.r, ao_strength);
	float rough = clamp(orm.g, rough_min, rough_max);
	float metal = orm.b * metallic_mul;
	float nstr = normal_strength;

	// grime: noise + the floor gradient + the occluded corners
	float n = noise2(world_pos / grime_scale);
	float floor_g = 1.0 - smoothstep(0.0, grime_height, world_pos.y - grime_floor_y);
	float corner = 1.0 - orm.r;
	float g = clamp(n * 0.55 + floor_g * 0.5 + corner * 0.5, 0.0, 1.0) * grime * vmask.r;
	albedo = mix(albedo, albedo * grime_tint.rgb * 1.6, g);
	rough = mix(rough, 1.0, g * 0.5);

	// wetness: melt water, blood, the cellar's damp
	float w = clamp(noise2(world_pos / (grime_scale * 1.7) + 5.0) * 0.6 + floor_g * 0.5, 0.0, 1.0) * wetness * vmask.g;
	albedo = mix(albedo, albedo * 0.5, w);
	rough = mix(rough, 0.15, w);

	// frost: up-facing surfaces above frost_height, broken by noise
	float up = smoothstep(frost_up - 0.25, frost_up + 0.25, world_nrm.y);
	float hgt = smoothstep(frost_height - frost_softness, frost_height + frost_softness, world_pos.y);
	float f = up * hgt * (0.45 + 0.55 * noise2(world_pos / (grime_scale * 0.8) + 23.0)) * frost * vmask.b;
	f = smoothstep(0.15, 0.7, f);
	albedo = mix(albedo, frost_tint.rgb, f);
	rough = mix(rough, 0.8, f);
	metal = mix(metal, 0.0, f);
	nstr = mix(nstr, nstr * 0.4, f);
	ao = mix(ao, 1.0, f * 0.6);

	float spec = specular_amount;
	if (triplanar && sparkle > 0.001) {
		vec3 gl = sv_glint(world_pos, cam_dist, sparkle);
		float gk = gl.z * (1.0 - g) * smoothstep(0.5, 0.85, world_nrm.y);
		nrm = mix(nrm, vec3(0.5 + gl.xy * 0.13, 1.0), gk);
		nstr = mix(nstr, 1.0, gk);
		rough = mix(rough, 0.14, gk);
		spec = mix(spec, 1.0, gk);
	}

	ALBEDO = albedo;
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = nstr;
	ROUGHNESS = rough;
	METALLIC = metal;
	AO = ao;
	AO_LIGHT_AFFECT = 0.4;
	SPECULAR = spec;
	if (emission_energy > 0.0) {
		EMISSION = emission_color.rgb * emission_energy;
	}
}
