shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley;
// Canvas and rope in the slipstream (T-220, der Kranich's plane pass; our own): a vertex wave that grows with the
// vertex's freedom (COLOR.r: 0 where it is tied, 1 at the loose end), streaming aft (-Z) and snapping across, faster
// and harder in a turbulence gust (`gust`, KranichExterior.gust_now). Cosmetic: nothing collides with it.

uniform vec4 albedo : source_color = vec4(0.3, 0.29, 0.24, 1.0);
uniform float amp = 0.1;
uniform float freq = 9.0;
uniform float gust : hint_range(0.0, 1.0) = 0.0;
uniform float roughness_v : hint_range(0.0, 1.0) = 0.92;

void vertex() {
	float free_k = COLOR.r;
	float ph = COLOR.g * 6.2831;
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float f = freq * (1.0 + gust * 0.8);
	float a = amp * (1.0 + gust * 1.6) * free_k;
	float wave = sin(TIME * f + w.z * 2.3 + w.x * 0.9 + ph) + 0.45 * sin(TIME * f * 2.17 + w.z * 5.1 + ph * 1.7);
	vec3 side = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 disp = side * wave * a + vec3(0.0, wave * a * 0.35, -abs(wave) * a * 0.4);
	VERTEX += (inverse(MODEL_MATRIX) * vec4(disp, 0.0)).xyz;
}

void fragment() {
	// a little dirt and wear along the hem
	float n = fract(sin(dot(floor(UV * vec2(40.0, 30.0)), vec2(12.9898, 78.233))) * 43758.5453);
	ALBEDO = albedo.rgb * (0.85 + 0.2 * n) * (1.0 - COLOR.r * 0.15);
	ROUGHNESS = roughness_v;
}
