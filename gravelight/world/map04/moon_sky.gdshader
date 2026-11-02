// The Moon's sky (U09 s5, T-149): black, with hard unblinking stars (no air to twinkle through), a faint band of the
// galaxy, and the Sun as a hard white disc with a small glare where the first directional light (the "Moon" node,
// which on Mondlicht is the Sun) comes from. Procedural, so it costs no texture and reads the same on the web.
shader_type sky;

uniform float star_density : hint_range(0.0, 1.0) = 0.035;
uniform float star_scale = 220.0;
uniform float star_gain = 2.4;
uniform vec3 band_axis = vec3(0.35, 0.25, 0.9);
uniform vec4 band_color : source_color = vec4(0.16, 0.15, 0.2, 1.0);
uniform float band_gain = 0.08;
uniform float sun_size = 0.9994;      // cos of the disc's angular radius
uniform float sun_gain = 22.0;
uniform float glare_gain = 0.6;

vec3 hash33(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yxz + 19.19);
	return fract((p.xxy + p.yxx) * p.zyx);
}

float stars(vec3 dir, float scale, float density) {
	vec3 p = dir * scale;
	vec3 cell = floor(p);
	vec3 f = fract(p);
	vec3 h = hash33(cell);
	if (h.x > density) {
		return 0.0;
	}
	vec3 c = 0.25 + h * 0.5;
	float d = length(f - c);
	float size = 0.06 + h.y * 0.08;
	return smoothstep(size, 0.0, d) * (0.35 + h.z * 0.65);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 col = vec3(0.0);
	if (!AT_CUBEMAP_PASS) {
		float s = stars(d, star_scale, star_density) + stars(d, star_scale * 2.3, star_density * 1.6) * 0.55;
		vec3 tintc = mix(vec3(0.75, 0.82, 1.0), vec3(1.0, 0.88, 0.75), hash33(floor(d * star_scale)).y);
		col += tintc * s * star_gain;
		float band = 1.0 - abs(dot(d, normalize(band_axis)));
		col += band_color.rgb * pow(band, 8.0) * band_gain;
	}
	if (LIGHT0_ENABLED) {
		float c = dot(d, LIGHT0_DIRECTION);
		col += LIGHT0_COLOR * smoothstep(sun_size - 0.00015, sun_size, c) * sun_gain;
		col += LIGHT0_COLOR * pow(max(c, 0.0), 900.0) * glare_gain;
	}
	COLOR = col;
}
