// Groom Lake's blue hour (UPDATE 09 §5.4, DECISIONS T-148): the huge desert sky that is most of every frame.
// A deep indigo zenith over a pale cyan band, the dawn glow low in the east (rose to amber, strongest where the sun
// is about to come up), the earth shadow's violet belt opposite it in the west, stars that fade into the glow and
// the horizon, and a few high streaks of cirrus catching the first light. A real sky shader, so it works in the
// Compatibility renderer (the web profile) and in Forward+ alike; the radiance pass gets the plain gradient.
shader_type sky;
render_mode use_debanding;

uniform vec3 zenith : source_color = vec3(0.035, 0.06, 0.2);
uniform vec3 upper : source_color = vec3(0.16, 0.27, 0.55);
uniform vec3 band : source_color = vec3(0.52, 0.63, 0.78);
uniform vec3 glow : source_color = vec3(1.0, 0.58, 0.36);
uniform vec3 glow_core : source_color = vec3(1.0, 0.82, 0.55);
uniform vec3 belt : source_color = vec3(0.38, 0.3, 0.5);
uniform vec3 ground : source_color = vec3(0.16, 0.15, 0.2);
uniform vec3 glow_dir = vec3(0.97, 0.06, 0.2);   // where the sun is about to rise (east, a little north)
uniform float glow_width = 3.0;
uniform float star_density = 0.0045;
uniform float star_gain = 1.6;
uniform float cirrus = 0.55;
uniform float exposure = 1.0;

float hash3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), u.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) { s += a * vnoise(p); p = p * 2.07 + vec2(3.1, 7.7); a *= 0.5; }
	return s;
}

// stars on a fine direction grid: one candidate per cell, most cells empty
float stars(vec3 d) {
	vec3 g = d * 260.0;
	vec3 c = floor(g);
	float h = hash3(c);
	if (h > star_density) {
		return 0.0;
	}
	vec3 f = fract(g) - 0.5;
	float r = length(f);
	float mag = hash3(c + 17.0);
	float tw = 0.75 + 0.25 * sin(TIME * (1.5 + mag * 3.0) + h * 600.0);
	return smoothstep(0.42, 0.0, r) * (0.25 + mag * mag * 1.6) * tw;
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	float up = max(h, 0.0);
	// the vertical gradient: indigo zenith -> blue -> the pale band at the horizon
	vec3 col = mix(band, upper, smoothstep(0.0, 0.22, up));
	col = mix(col, zenith, smoothstep(0.18, 0.85, up));
	// the dawn glow: azimuthal toward glow_dir, hugging the horizon
	vec2 gd = normalize(glow_dir.xz);
	vec2 dd = normalize(d.xz + vec2(1e-5));
	float az = dot(dd, gd) * 0.5 + 0.5;               // 1 toward the glow, 0 opposite
	float low = exp(-up * (9.0 / glow_width));
	float g = pow(az, 3.0) * low;
	col = mix(col, glow, clamp(g * 0.95, 0.0, 1.0));
	float core = pow(az, 18.0) * exp(-up * 22.0);
	col += glow_core * core * 0.9;
	// the earth shadow's violet belt in the west, a little above the horizon
	float w = pow(1.0 - az, 3.0) * exp(-abs(up - 0.06) * 16.0);
	col = mix(col, belt, clamp(w * 0.55, 0.0, 1.0));
	// high cirrus streaks lit pink on the glow side, grey-blue opposite
	if (up > 0.02) {
		vec2 cp = d.xz / (up + 0.12);
		float n = fbm(vec2(cp.x * 0.7, cp.y * 2.6) + vec2(TIME * 0.004, 0.0));
		float c = smoothstep(0.62, 0.9, n) * cirrus * smoothstep(0.02, 0.2, up) * (1.0 - smoothstep(0.5, 0.95, up));
		vec3 ccol = mix(vec3(0.42, 0.45, 0.6), vec3(1.0, 0.66, 0.6), pow(az, 2.0));
		col = mix(col, ccol, c);
	}
	// stars: brightest overhead, gone in the glow and the horizon haze; never in the radiance cubemap
	if (!AT_CUBEMAP_PASS && up > 0.04) {
		float s = stars(d);
		float fade = smoothstep(0.06, 0.45, up) * (1.0 - clamp(g * 1.6, 0.0, 1.0));
		col += vec3(0.85, 0.9, 1.0) * s * fade * star_gain;
	}
	// below the horizon: the dark land (the ridges cover most of it)
	if (h < 0.0) {
		col = mix(band * 0.8, ground, smoothstep(0.0, 0.08, -h));
	}
	COLOR = col * exposure;
}
