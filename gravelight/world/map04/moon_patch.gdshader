// A feathered patch of regolith detail (boot prints, tracks, scorch) laid over the yard's floor (U09 s5, T-149).
// The texture tiles in metres along the patch's own axes (so a path of footprints follows the patch's yaw), and the
// alpha fades out toward every edge over `fade_m` with a little noise, so the patch melts into the dusted floor
// instead of showing a hard rectangle. Works in Forward+ and Compatibility (no decals there).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_tex = true;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 tile_m = vec2(1.6, 1.6);   // metres covered by one tile along the patch's local X / Z
uniform float fade_m = 0.8;             // metres of feathering at each edge
uniform float alpha_max : hint_range(0.0, 1.0) = 0.92;
uniform float roughness_v : hint_range(0.0, 1.0) = 0.95;
uniform float normal_depth : hint_range(0.0, 2.0) = 1.0;

varying vec2 local_m;
varying vec2 half_m;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	vec2 s = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[2].xyz));
	local_m = VERTEX.xz * s;
	half_m = s * 0.5;
}

void fragment() {
	vec2 uv = local_m / tile_m;
	vec2 edge = half_m - abs(local_m);
	float n = vnoise(local_m * 0.9) * 0.6 + vnoise(local_m * 3.1) * 0.4;
	float a = smoothstep(0.0, fade_m, min(edge.x, edge.y) - (n - 0.5) * fade_m * 0.8);
	vec3 col = tint.rgb;
	if (use_tex) {
		col *= texture(albedo_tex, uv).rgb;
		NORMAL_MAP = texture(normal_tex, uv).rgb;
		NORMAL_MAP_DEPTH = normal_depth;
	}
	ALBEDO = col;
	ROUGHNESS = roughness_v;
	ALPHA = a * alpha_max * tint.a;
}
