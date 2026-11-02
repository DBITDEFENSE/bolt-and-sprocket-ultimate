// The Earth over the Moon's yard (U09 s5, T-149): oceans, continents, ice caps and a slow cloud deck from procedural
// noise on the sphere, lit by the Sun from `sun_dir` (object space, toward the Sun) with a soft terminator, the night
// side blacked out (1945: the cities are dark; the violet points are earth_sky.gd's own spheres on top), and a blue
// rim of atmosphere. Unshaded and fog-free: it is a sky object, there is no air between it and the yard.
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;

uniform vec3 sun_dir = vec3(0.8, 0.35, 0.45);
uniform vec4 ocean_deep : source_color = vec4(0.015, 0.05, 0.17, 1.0);
uniform vec4 ocean_shallow : source_color = vec4(0.05, 0.17, 0.38, 1.0);
uniform vec4 land_green : source_color = vec4(0.13, 0.2, 0.08, 1.0);
uniform vec4 land_dry : source_color = vec4(0.45, 0.36, 0.22, 1.0);
uniform vec4 atmosphere : source_color = vec4(0.32, 0.56, 1.0, 1.0);
uniform float land_level : hint_range(0.0, 1.0) = 0.53;
uniform float brightness = 1.35;
uniform float night_level = 0.012;

varying vec3 obj_n;

float h31(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vn(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h31(i), h31(i + vec3(1, 0, 0)), f.x), mix(h31(i + vec3(0, 1, 0)), h31(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h31(i + vec3(0, 0, 1)), h31(i + vec3(1, 0, 1)), f.x), mix(h31(i + vec3(0, 1, 1)), h31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 5; i++) {
		s += vn(p) * a;
		p = p * 2.03 + vec3(1.7, 9.2, 3.3);
		a *= 0.5;
	}
	return s;
}

void vertex() {
	obj_n = normalize(VERTEX);
}

void fragment() {
	vec3 n = normalize(obj_n);
	float c = fbm(n * 1.7 + vec3(4.1, 1.3, 7.7));
	float land = smoothstep(land_level, land_level + 0.025, c);
	vec3 ocean = mix(ocean_deep.rgb, ocean_shallow.rgb, smoothstep(land_level - 0.12, land_level, c));
	vec3 ground = mix(land_green.rgb, land_dry.rgb, smoothstep(0.35, 0.65, fbm(n * 4.3 + vec3(2.0))) * (1.0 - abs(n.y)));
	vec3 col = mix(ocean, ground, land);
	float ice = smoothstep(0.8, 0.88, abs(n.y) + (fbm(n * 6.0) - 0.5) * 0.1);
	col = mix(col, vec3(0.86, 0.9, 0.95), ice);
	float cl = smoothstep(0.5, 0.72, fbm(n * 3.2 + vec3(TIME * 0.003, 0.0, TIME * 0.002)));
	col = mix(col, vec3(0.93, 0.95, 0.98), cl * 0.85);
	float ndl = dot(n, normalize(sun_dir));
	float day = smoothstep(-0.06, 0.22, ndl);
	vec3 lit = col * (0.18 + 0.95 * max(ndl, 0.0)) * brightness;
	vec3 dark = col * night_level;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.6);
	vec3 outc = mix(dark, lit, day) + atmosphere.rgb * rim * (0.08 + 0.9 * day);
	ALBEDO = outc;
}
