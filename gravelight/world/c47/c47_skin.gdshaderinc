// UPDATE 12 section 5 (T-211): GRAVELIGHT ONE's skin. The paint (or a real model's own albedo texture), the shared
// wear texture (the library's olive-over-rust set, triplanar in world space), and the build's vertex colour:
//   R scorch: the fuel fire's blistered, charred paint (with a brown heat ring round it)
//   G soot / dirt: darkening; streaks off the fires
//   B snow allowance: up-facing surfaces under the sky gather snow
// One-sided (cull_back: cull_disabled with SDFGI crashed the Vulkan pipeline on Godot 4.7.2, T-211); the build doubles
// the exterior skin with flipped faces so a tear shows its back, not a hole. Alpha scissor for the markings atlas.

uniform vec4 paint_color : source_color = vec4(0.25, 0.26, 0.17, 1.0);
uniform bool use_tex = false;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_normal_tex = false;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wear_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wear_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float wear_scale = 0.7;
uniform float wear_amount : hint_range(0.0, 1.0) = 0.45;
uniform float roughness_base : hint_range(0.0, 1.0) = 0.72;
uniform float metal_amount : hint_range(0.0, 1.0) = 0.0;
uniform float snow_amount : hint_range(0.0, 1.0) = 1.0;
uniform vec4 snow_tint : source_color = vec4(0.70, 0.73, 0.78, 1.0);   // T-214: was 0.82/0.85/0.92 (paper white on the flat panels)
uniform vec4 char_tint : source_color = vec4(0.03, 0.026, 0.022, 1.0);
uniform vec4 heat_tint : source_color = vec4(0.22, 0.14, 0.08, 1.0);
uniform float alpha_clip : hint_range(0.0, 1.0) = 0.5;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

float hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

vec4 tri(sampler2D t, vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= dot(w, vec3(1.0));
	return texture(t, p.zy) * w.x + texture(t, p.xz) * w.y + texture(t, p.xy) * w.z;
}

void fragment() {
	vec3 base = paint_color.rgb;
	float alpha = 1.0;
	if (use_tex) {
		vec4 t = texture(albedo_tex, UV);
		base = t.rgb * paint_color.rgb;
		alpha = t.a;
	}
	vec3 wp = wpos * wear_scale;
	vec3 wear = tri(wear_tex, wp, wnrm).rgb;
	float wl = dot(wear, vec3(0.333));
	// the paint's wear: faded, streaked, chipped where the wear set shows rust
	float chip = smoothstep(0.55, 0.75, wl + vnoise(wpos * 3.1) * 0.25) * wear_amount * (0.4 + COLOR.g);
	vec3 col = base * mix(1.0, 0.75 + wl * 0.6, wear_amount);
	col = mix(col, wear * 0.75, chip * 0.6);
	// soot and dirt
	col *= 1.0 - 0.55 * clamp(COLOR.g, 0.0, 1.0);
	// the fire: a brown heat ring, then charred and blistered
	float n = vnoise(wpos * 4.7) * 0.6 + vnoise(wpos * 13.0) * 0.4;
	float sc = clamp(COLOR.r * (0.75 + 0.5 * n), 0.0, 1.0);
	col = mix(col, heat_tint.rgb, smoothstep(0.1, 0.45, sc) * 0.7);
	col = mix(col, char_tint.rgb * (0.7 + 0.6 * n), smoothstep(0.45, 0.8, sc));
	float rough = mix(roughness_base, 0.95, smoothstep(0.3, 0.8, sc));
	float metal = metal_amount * (1.0 - smoothstep(0.3, 0.7, sc));
	// snow on what faces the sky
	float up = smoothstep(0.45, 0.85, wnrm.y) * COLOR.b * snow_amount;
	float sn = smoothstep(0.25, 0.6, up * (0.55 + 0.6 * vnoise(wpos * 1.3 + 7.0)));
	col = mix(col, snow_tint.rgb * (0.8 + 0.32 * vnoise(wpos * 3.7 + 11.0)), sn);   // T-214: drifted, not a flat sheet
	rough = mix(rough, 0.82, sn);
	metal = mix(metal, 0.0, sn);
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.4;
	NORMAL_MAP = use_normal_tex ? texture(normal_tex, UV).rgb : tri(wear_normal, wp, wnrm).rgb;
	NORMAL_MAP_DEPTH = mix(0.6, 0.15, sn);
	// (no FRONT_FACING darkening of the skin's back: with the triplanar normal map it took the Vulkan pipeline down
	// on the RTX 5090 / Godot 4.7.2, silently; T-211)
#ifdef C47_DECAL
	ALPHA = alpha;
	ALPHA_SCISSOR_THRESHOLD = alpha_clip;
#endif
}
