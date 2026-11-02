// The black salt round the Kranich wreck (UPDATE 09 §5.4, T-148): a ground card a few cm over the salt, soot-black
// at the centre, burnt brown and grey-ash streaks outward, a ragged edge fading into the white crust. World-space;
// the card's own radius comes from `centre` / `radius` so one material serves every patch.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, shadows_disabled;

uniform vec3 centre = vec3(0.0, 0.0, -20.0);
uniform float radius = 50.0;
uniform vec3 soot : source_color = vec3(0.035, 0.032, 0.03);
uniform vec3 burnt : source_color = vec3(0.2, 0.15, 0.11);
uniform vec3 ash : source_color = vec3(0.45, 0.43, 0.41);
uniform vec2 stretch = vec2(1.0, 1.35);   // the wind laid the smoke northward

varying vec3 wpos;

float h21(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 15731.743); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), u.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) { s += a * vnoise(p); p = p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
	return s;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 rel = (wpos.xz - centre.xz) / stretch;
	float d = length(rel) / radius;
	float n = fbm(wpos.xz * 0.06);
	float streak = fbm(vec2(wpos.x * 0.35, wpos.z * 0.05));
	float k = d + (n - 0.5) * 0.55;
	float a = 1.0 - smoothstep(0.55, 1.0, k);
	vec3 c = mix(soot, burnt, smoothstep(0.15, 0.7, k + (streak - 0.5) * 0.4));
	c = mix(c, ash, smoothstep(0.55, 0.85, streak) * 0.5 * smoothstep(0.2, 0.6, k));
	ALBEDO = c;
	ROUGHNESS = 0.97;
	ALPHA = clamp(a * (0.75 + 0.25 * n), 0.0, 1.0);
}
