// Fog cards (T-052): big soft quads of mist lying in the valleys between the landscape's layers, the old matte-
// painting trick for depth. Noise-broken alpha that drifts slowly, faded at the card's edges, softened where it cuts
// the terrain (depth fade) and toward the camera, coloured like the night haze.
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform vec3 color : source_color = vec3(0.09, 0.11, 0.17);
uniform float opacity = 0.55;
uniform float soft = 6.0;          // metres of depth over which the card fades into the ground
uniform float near_fade = 40.0;
uniform vec2 drift = vec2(0.006, 0.002);
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;

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

void fragment() {
	vec2 e = min(UV, 1.0 - UV);
	float edge = smoothstep(0.0, 0.3, e.x) * smoothstep(0.0, 0.35, e.y);
	float n = fbm(UV * vec2(5.0, 2.0) + TIME * drift);
	float a = smoothstep(0.25, 0.75, n) * edge * opacity;
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float scene_d = -vp.z / vp.w;
	a *= clamp((scene_d + VERTEX.z) / soft, 0.0, 1.0);
	a *= smoothstep(near_fade * 0.5, near_fade, length(VERTEX));
	ALBEDO = color;
	ALPHA = a;
}
