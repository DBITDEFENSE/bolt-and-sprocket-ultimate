// Map 0's night sky (T-052): a dome that follows the camera, drawn inside the far plane. A heavy snow-cloud deck
// with breaks, the moon smeared behind it, a few stars in the gaps, the burning town's glow under the clouds on
// one horizon, and the distant war lighting the cloud base: artillery flashes (`flashes`, xyz = direction,
// w = intensity, with `flash_cols` rgb + w = spread) and searchlight spots where the beams hit the deck (`beams`).
// MapAmbience writes those arrays every frame; Landscape keeps the base colours in step with the environment.
//
// UPDATE 19 (T-252), the same sky drawn better; nothing here lights the scene (unshaded, the Environment's own
// background and ambient are untouched, so no interior changes brightness):
//   - the moon is a disc (a waning gibbous with maria and a soft limb) where a break shows it, and a corona that
//     spreads through thin cloud where the deck covers it;
//   - the deck has depth: its edges silver toward the moon, the side away from it is shaded (one more noise sample
//     toward the moon), and a thin high veil drifts across the breaks at its own speed;
//   - the stars are round points of several sizes and colours on two grids, twinkling a little, instead of one
//     grid of square cells;
//   - on Forward+ the deck's mean brightness is the old one (deck_light), with more contrast inside it; on the
//     Compatibility renderer (the web build) the grade's contrast is applied in linear space and takes everything
//     under about 0.08 to black, so there the sky is black but for the moon and its corona, as it was before;
//   - a half-bit of screen noise breaks the banding of the near-black gradient.
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
uniform float moon_size = 0.021;       // the disc's angular radius, radians (1.2 degrees: a film moon, 2.3x the real one)
uniform float moon_gain = 1.9;
uniform float star_gain = 1.0;
uniform float deck_light = 0.05;       // the moon on the whole deck from above (what makes the overcast read at all)
uniform float high_veil = 0.4;         // the thin high layer in the breaks (0 = none)
uniform vec4 flashes[8];
uniform vec4 flash_cols[8];
uniform vec4 beams[4];

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec3 hash33(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yxz + 19.19);
	return fract((p.xxy + p.yxx) * p.zyx);
}
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
float fbm3(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	mat2 r = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));
	for (int i = 0; i < 3; i++) { s += a * gnoise(p); p = r * p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
	return s / 0.875;
}

// One grid of stars: a candidate per cell, most cells empty; x = brightness, y = a 0..1 colour pick.
vec2 star_grid(vec3 dir, float scale, float density) {
	vec3 p = dir * scale;
	vec3 cell = floor(p);
	vec3 h = hash33(cell);
	if (h.x > density) {
		return vec2(0.0);
	}
	vec3 c = 0.3 + hash33(cell + 7.0) * 0.4;
	float d = length(fract(p) - c);
	float mag = h.x / density;                       // 0..1, uniform among the stars that exist
	float size = 0.12 + (1.0 - mag) * (1.0 - mag) * 0.18;   // a few big ones, many small (the disc stays inside its cell)
	float tw = 0.82 + 0.18 * sin(TIME * (1.2 + h.y * 2.6) + h.z * 60.0);
	return vec2(smoothstep(size, size * 0.3, d) * (0.25 + (1.0 - mag) * (1.0 - mag) * 0.9) * tw, h.z);
}

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 dir = normalize(wp - CAMERA_POSITION_WORLD);
	float up = max(dir.y, 0.0);
	float horiz = pow(1.0 - up, 4.0);
	vec3 col = mix(zenith, horizon, horiz);
	vec3 mdir = normalize(moon_dir);
	float md = max(dot(dir, mdir), 0.0);
	// the cloud deck: a plane projection, thickening into a solid band at the horizon
	vec2 cp = dir.xz / (up + 0.08) * cloud_scale + TIME * wind;
	cp += vec2(fbm3(cp * 0.7 + 3.1), fbm3(cp * 0.7 - 5.3)) * 0.8;   // a little domain warp: billows, not blobs
	float n = fbm(cp);
	float lo = 1.0 - cloud_cover - 0.12;
	float hi = 1.0 - cloud_cover + 0.22;
	float c = smoothstep(lo, hi, n);
	float band = smoothstep(0.25, 0.0, up) * 0.7;
	c = mix(c, 1.0, band);
	float shade = fbm3(cp * 2.3 + 4.0);
	// depth: the deck sampled a step toward the moon; thinner there = this side faces the moon
	vec2 toward = normalize(mdir.xz + vec2(0.0001)) * 0.16;
	float c_m = smoothstep(lo, hi, fbm(cp + toward));
	float facing = clamp((c - c_m) * 1.6 + 0.5, 0.0, 1.0);          // 1 = lit flank, 0 = the far side
	float edge = c * (1.0 - c) * 4.0;                                 // 1 on a cloud's thin rim
	// light on the cloud base: the moon (silvered edges near it), the burning town, the war
	vec3 lit = cloud_tint * (0.62 + 0.5 * shade + 0.26 * (facing - 0.5));
	lit += moon_color * (deck_light + 0.11 * pow(md, 6.0)) * (0.35 + 0.65 * facing) * (0.6 + 0.8 * shade);
	lit += moon_color * edge * (0.035 + 0.5 * pow(md, 24.0)) * (1.0 - band);
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
	// the breaks: a thin high veil (its own drift), then the stars and the moon behind everything
	float veil = 0.0;
	if (high_veil > 0.001) {
		vec2 hp = dir.xz / (up + 0.22) * cloud_scale * 2.1 - TIME * wind * 0.6 + vec2(31.0, 17.0);
		veil = smoothstep(0.42, 0.85, fbm3(vec2(hp.x * 0.6, hp.y * 1.7))) * high_veil * smoothstep(0.03, 0.25, up);
		col = mix(col, cloud_tint * 0.55 + moon_color * (0.012 + 0.09 * pow(md, 10.0)), veil);
	}
	float gap = (1.0 - c) * (1.0 - c);
	float sky_clear = gap * (1.0 - veil * 0.8) * smoothstep(0.06, 0.3, up);
	if (sky_clear > 0.01) {
		vec2 s1 = star_grid(dir, 120.0, 0.03);     // a 5 px cell at 720p: discs of 0.6 to 1.6 px
		vec2 s2 = star_grid(dir, 260.0, 0.012);    // the faint field
		vec3 warm = vec3(1.0, 0.86, 0.72);
		vec3 cold = vec3(0.72, 0.8, 1.0);
		col += (mix(cold, warm, s1.y * s1.y) * s1.x + mix(cold, warm, s2.y * s2.y) * s2.x * 0.6) * 0.9 * star_gain * sky_clear;
	}
	// the moon: a disc with maria where the sky is open, a corona that spreads where cloud covers it
	float ang = acos(clamp(dot(dir, mdir), -1.0, 1.0));
	vec3 mt = normalize(cross(mdir, vec3(0.0, 1.0, 0.0)));
	vec3 mb = cross(mt, mdir);
	vec2 q = vec2(dot(dir, mt), dot(dir, mb)) / moon_size;
	float disc = smoothstep(1.0, 0.9, length(q)) * step(0.0, dot(dir, mdir));
	float lit_side = smoothstep(-0.08, 0.08, q.x * 0.9 + 0.62 * sqrt(max(0.0, 1.0 - q.y * q.y)));   // waning gibbous
	float maria = 0.72 + 0.28 * smoothstep(0.35, 0.7, fbm3(q * 1.3 + 11.0));
	float limb = 0.75 + 0.25 * sqrt(max(0.0, 1.0 - dot(q, q)));
	float open = (1.0 - c * 0.93) * (1.0 - veil * 0.5);
	col = mix(col, lit, c * 0.85);
	col += moon_color * disc * lit_side * maria * limb * moon_gain * open;
	float corona = exp(-ang * ang / (moon_size * moon_size * 9.0)) * 0.55 + exp(-ang / (moon_size * 7.0)) * 0.1;
	col += moon_color * corona * (0.18 + 0.5 * c * (1.0 - c * 0.6) + 0.35 * veil) * (1.0 - disc * open);
	col += town * (0.45 + 1.3 * c);
	col += war * (0.35 + 0.9 * c);
	col += vec3(0.75, 0.78, 0.85) * spots * (0.25 + 0.75 * c);
	col += (hash(FRAGCOORD.xy + fract(TIME) * 61.0) - 0.5) * 0.0009;   // half a display bit: no banding in the near-black
	ALBEDO = max(col, vec3(0.0)) * exposure;
}
