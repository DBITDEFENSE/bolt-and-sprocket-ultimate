shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// One puff of a cloud bank streaming through der Kranich's wing (T-220, the plane pass; our own): a camera-facing
// card with a ragged noise edge, moonlit on top and dark underneath, warmed by the dawn behind the wing; soft where it
// meets the hull (the depth fade) and thinned right in front of the eye so it never fills the screen as a flat card.

uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;
uniform float seed = 0.0;
uniform float dawn : hint_range(0.0, 1.0) = 0.0;
uniform vec4 lit : source_color = vec4(0.5, 0.55, 0.66, 1.0);
uniform vec4 dark : source_color = vec4(0.13, 0.15, 0.2, 1.0);
uniform vec4 dawn_color : source_color = vec4(0.9, 0.6, 0.45, 1.0);
uniform float opacity = 0.75;
uniform float soft_m = 6.0;
uniform float near_m = 9.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	// billboard: keep the card's centre, face the camera
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	vec2 q = UV * 3.2 + seed;
	float n = vnoise(q) * 0.55 + vnoise(q * 2.2 + 3.1) * 0.3 + vnoise(q * 5.1 + 7.7) * 0.15;
	float body = 1.0 - smoothstep(0.35, 1.0, length(c) + (n - 0.5) * 0.75);
	// lit from above: the top of the card brighter, the belly dark
	vec3 col = mix(dark.rgb, lit.rgb, clamp(0.35 + (1.0 - UV.y) * 0.6 + (n - 0.5) * 0.5, 0.0, 1.0));
	col = mix(col, col * dawn_color.rgb * 1.4, dawn * 0.6);
	// soft against the hull, thin right in front of the eye
	float scene_d = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 sp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_d, 1.0);
	float scene_z = -sp.z / sp.w;
	float frag_z = -VERTEX.z;
	float soft = clamp((scene_z - frag_z) / soft_m, 0.0, 1.0);
	float near = smoothstep(2.0, near_m, frag_z);
	ALBEDO = col;
	ALPHA = clamp(body * opacity * soft * near, 0.0, 1.0);
}
