// Map 0's night sky (T-052): a dome that follows the camera, drawn inside the far plane. A heavy snow-cloud deck
// with breaks, the moon smeared behind it, a few stars in the gaps, the burning town's glow under the clouds on
// one horizon, and the distant war lighting the cloud base: artillery flashes (`flashes`, xyz = direction,
// w = intensity, with `flash_cols` rgb + w = spread) and searchlight spots where the beams hit the deck (`beams`).
// MapAmbience writes those arrays every frame; Landscape keeps the base colours in step with the environment.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_front, shadows_disabled;

uniform vec3 zenith : source_color = vec3(0.004, 0.006, 0.013);
uniform vec3 horizon : source_color = vec3(0.05, 0.062, 0.1);
uniform vec3 cloud_tint : source_color = vec3(0.07, 0.08, 0.115);
uniform vec3 moon_dir = vec3(0.36, 0.64, 0.68);
uniform vec3 moon_color : source_color = vec3(0.55, 0.62, 0.85);
uniform vec3 town_dir = vec3(0.88, 0.0, -0.47);
uniform vec3 town_color : source_color = vec3(1.0, 0.36, 0.1);
uniform float town_strength = 0.35;
uniform float cloud_cover = 0.62;
uniform float cloud_scale = 0.55;
uniform vec2 wind = vec2(0.004, 0.0015);
uniform float exposure = 1.0;
uniform vec4 flashes[8];
uniform vec4 flash_cols[8];
uniform vec4 beams[4];

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float hash3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
// gradient noise with a quintic fade (value noise thresholded shows its grid as straight creases)
vec2 grad(vec2 p) {
	float a = hash(p) * 6.2831853;
	return vec2(cos(a), sin(a));
}
float gnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = dot(grad(i), f);
	float b = dot(grad(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
	float c = dot(grad(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
	float d = dot(grad(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 0.75 + 0.5;
}
float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	mat2 r = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));
	for (int i = 0; i < 5; i++) { s += a * gnoise(p); p = r * p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
	return s;
}

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 dir = normalize(wp - CAMERA_POSITION_WORLD);
	float up = max(dir.y, 0.0);
	float horiz = pow(1.0 - up, 4.0);
	vec3 col = mix(zenith, horizon, horiz);
	// the cloud deck: a plane projection, thickening into a solid band at the horizon
	vec2 cp = dir.xz / (up + 0.08) * cloud_scale + TIME * wind;
	cp += vec2(fbm(cp * 0.7 + 3.1), fbm(cp * 0.7 - 5.3)) * 0.8;   // a little domain warp: billows, not blobs
	float n = fbm(cp);
	float c = smoothstep(1.0 - cloud_cover - 0.12, 1.0 - cloud_cover + 0.22, n);
	c = mix(c, 1.0, smoothstep(0.25, 0.0, up) * 0.7);
	float shade = fbm(cp * 2.3 + 4.0);
	// light on the cloud base: the moon (silvered edges near it), the burning town, the war
	float md = max(dot(dir, normalize(moon_dir)), 0.0);
	vec3 lit = cloud_tint * (0.75 + 0.5 * shade) + moon_color * (0.025 + 0.11 * pow(md, 6.0));
	vec2 th = normalize(town_dir.xz);
	vec2 dh = normalize(dir.xz + vec2(0.0001));
	float tb = max(dot(dh, th), 0.0);
	vec3 town = town_color * town_strength * pow(tb, 26.0) * exp(-up * 7.0) * (0.85 + 0.15 * sin(TIME * 1.7 + shade * 6.0));
	vec3 war = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		if (flashes[i].w > 0.001) {
			float k = max(dot(dir, normalize(flashes[i].xyz)), 0.0);
			war += flash_cols[i].rgb * flashes[i].w * pow(k, max(flash_cols[i].w, 1.0)) * (1.0 - smoothstep(0.0, 0.6, up));
		}
	}
	float spots = 0.0;
	for (int j = 0; j < 4; j++) {
		if (beams[j].w > 0.001) {
			float k = max(dot(dir, normalize(beams[j].xyz)), 0.0);
			spots += beams[j].w * (pow(k, 2200.0) * 1.4 + pow(k, 260.0) * 0.25);
		}
	}
	col = mix(col, lit, c * 0.85);
	col += town * (0.45 + 1.3 * c);
	col += war * (0.35 + 0.9 * c);
	col += vec3(0.75, 0.78, 0.85) * spots * (0.25 + 0.75 * c);
	// the moon itself, a smear behind the deck; stars in the gaps
	col += moon_color * (pow(md, 900.0) * 1.6 * (1.0 - c * 0.85) + pow(md, 60.0) * 0.05);
	float star = step(0.9975, hash3(floor(dir * 420.0))) * (1.0 - c) * (1.0 - c) * smoothstep(0.08, 0.3, up);
	col += vec3(0.6, 0.65, 0.8) * star * (0.4 + 0.6 * hash3(floor(dir * 97.0)));
	ALBEDO = col * exposure;
}
