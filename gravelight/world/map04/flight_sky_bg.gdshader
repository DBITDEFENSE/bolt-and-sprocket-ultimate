shader_type sky;
// Der Kranich's night (UPDATE 09 section 5.3, DECISIONS T-147; our own): the sky behind every window, blister and
// breach. A deep blue-black gradient, a hard star field (no stars in the radiance pass, so the interior's reflections
// stay dark), the moon's disc and halo where the act's Moon light comes from (LIGHT0), the haze under the horizon
// that the ground plane fades into (FlightSky keeps them the same colour so the far plane never shows), the violet
// glow to the east after the London window (`east_glow`), and the dawn for the crash (`dawn`).

uniform vec4 top_color : source_color = vec4(0.012, 0.018, 0.045, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.07, 0.09, 0.16, 1.0);
uniform vec4 haze_color : source_color = vec4(0.06, 0.075, 0.12, 1.0);
uniform vec4 moon_color : source_color = vec4(0.92, 0.94, 1.0, 1.0);
uniform float moon_size = 0.022;          // radians
uniform float star_density : hint_range(0.0, 1.0) = 0.6;
uniform float star_gain = 6.0;
uniform float east_glow : hint_range(0.0, 1.0) = 0.0;
uniform vec4 east_color : source_color = vec4(0.32, 0.1, 0.45, 1.0);
uniform float dawn : hint_range(0.0, 1.0) = 0.0;
uniform vec4 dawn_color : source_color = vec4(0.95, 0.55, 0.3, 1.0);
uniform float flash : hint_range(0.0, 4.0) = 0.0;   // flak / searchlight wash over the lower sky
// UPDATE 10 (T-156): the night turning to dawn across the act (FlightSky.set_sunrise from the living world): the
// glow comes up behind the wing (aft, -Z: the Kranich flies west, away from the sun), the stars fade, the top lifts
uniform float sunrise : hint_range(0.0, 1.0) = 0.0;
uniform vec4 sunrise_color : source_color = vec4(0.95, 0.5, 0.28, 1.0);
// T-220 (the plane pass): the world banks a few degrees and recovers (KranichAir; radians about the flight axis +Z:
// the horizon, the stars and the far deck tilt, the floor never does), the far cloud deck to the horizon (a plane
// deck_alt m below seen through the haze, scrolling aft by deck_scroll m: the sea shows through its gaps), and the
// moon's disc turning into the low sun behind the wing as the key light swings over at dawn (sun_k)
uniform float bank = 0.0;
uniform float deck = 1.0;
uniform float deck_alt = 2400.0;
uniform float deck_scale = 1500.0;
uniform float deck_cover : hint_range(0.0, 1.0) = 0.55;
uniform float deck_scroll = 0.0;
uniform vec4 deck_lit : source_color = vec4(0.55, 0.6, 0.74, 1.0);
uniform vec4 deck_dark : source_color = vec4(0.07, 0.085, 0.125, 1.0);
uniform vec4 sea_far : source_color = vec4(0.025, 0.032, 0.05, 1.0);
uniform float sun_k : hint_range(0.0, 1.0) = 0.0;
uniform vec4 sun_color : source_color = vec4(1.0, 0.72, 0.45, 1.0);
// T-221: the golden hour of the bomb run (KranichSunset): a strong gradient, orange at the horizon behind the wing,
// a pink band over it, deep blue overhead and ahead; the sun's glow wide; the far deck's tops gold over blue shadow
uniform float golden : hint_range(0.0, 1.0) = 0.0;
uniform vec4 gold_horizon : source_color = vec4(1.0, 0.44, 0.12, 1.0);
uniform vec4 gold_pink : source_color = vec4(0.62, 0.26, 0.34, 1.0);
uniform vec4 gold_zenith : source_color = vec4(0.04, 0.07, 0.2, 1.0);
uniform vec4 gold_ahead : source_color = vec4(0.22, 0.2, 0.38, 1.0);

float hash12d(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12d(i), hash12d(i + vec2(1.0, 0.0)), u.x), mix(hash12d(i + vec2(0.0, 1.0)), hash12d(i + vec2(1.0, 1.0)), u.x), u.y);
}

float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

void sky() {
	vec3 dw = normalize(EYEDIR);
	// the bank: the world rolls about the flight axis (the moon is the light itself, rotated by the same bank)
	float cb = cos(bank);
	float sb = sin(bank);
	vec3 d = vec3(dw.x * cb + dw.y * sb, -dw.x * sb + dw.y * cb, dw.z);
	float h = d.y;
	vec3 col;
	if (h >= 0.0) {
		col = mix(horizon_color.rgb, top_color.rgb, pow(clamp(h, 0.0, 1.0), 0.45));
	} else {
		col = mix(horizon_color.rgb, haze_color.rgb, clamp(-h * 6.0, 0.0, 1.0));
	}
	// the east (+X, starboard) turns violet after London; dawn warms the horizon ahead and low
	float east = clamp(d.x * 0.5 + 0.5, 0.0, 1.0);
	col += east_color.rgb * east_glow * pow(east, 3.0) * exp(-abs(h) * 5.0);
	col = mix(col, mix(col, dawn_color.rgb * 0.6, exp(-abs(h) * 4.0)), dawn);
	col += vec3(0.25, 0.22, 0.3) * flash * exp(-max(-h, 0.0) * 3.0) * 0.08;
	float aft = clamp(-d.z * 0.5 + 0.5, 0.0, 1.0);
	col += sunrise_color.rgb * sunrise * pow(aft, 2.5) * exp(-abs(h) * 3.5) * 0.9;
	col = mix(col, col + vec3(0.06, 0.08, 0.14), sunrise * smoothstep(-0.05, 0.6, h));
	// the far deck below the horizon (the near sheets and the ground plane are FlightSky's own meshes inside the camera's
	// far plane; past their rims, 30 degrees down and flatter, this is what lies to the horizon)
	if (h < 0.0 && deck > 0.0) {
		float t = deck_alt / max(-h, 0.012);
		vec2 p = d.xz * t + vec2(0.0, deck_scroll);
		float n = vnoise2(p / deck_scale) * 0.55 + vnoise2(p / deck_scale * 2.3 + 4.1) * 0.3;
		if (!AT_CUBEMAP_PASS) {
			n += vnoise2(p / deck_scale * 5.7 + 9.3) * 0.15;
		}
		float cl = smoothstep(1.0 - deck_cover - 0.12, 1.0 - deck_cover + 0.12, n);
		float lit = clamp(n * 1.4 - 0.25, 0.0, 1.0);
		vec3 tops = mix(mix(deck_dark.rgb, vec3(0.05, 0.07, 0.19), golden), deck_lit.rgb, lit);
		float aftg = clamp(-d.z * 0.5 + 0.5, 0.0, 1.0);
		tops = mix(tops, tops * vec3(1.5, 0.95, 0.75) + vec3(0.35, 0.14, 0.06) * lit, golden * pow(aftg, 0.6));
		float aftk = clamp(-d.z * 0.5 + 0.5, 0.0, 1.0);
		tops += sunrise_color.rgb * sunrise * pow(aftk, 2.0) * 0.35 * lit;
		tops += east_color.rgb * east_glow * pow(clamp(d.x * 0.5 + 0.5, 0.0, 1.0), 3.0) * 0.4;
		vec3 below = mix(sea_far.rgb, sea_far.rgb * 1.6, vnoise2(p / 300.0));
		vec3 dk = mix(below, tops, cl);
		// the air between: the haze thickens to the horizon; steeply down it hands over to the ground plane's rim
		float air = 1.0 - exp(-t / 16000.0);
		dk = mix(dk, mix(horizon_color.rgb * 0.9, mix(gold_ahead.rgb, gold_horizon.rgb * 0.8, pow(aftg, 2.0)), golden), air);
		float band = smoothstep(-0.62, -0.36, h) * deck;
		col = mix(col, dk, band);
	}
	if (golden > 0.0) {
		float aft2 = clamp(-d.z * 0.5 + 0.5, 0.0, 1.0);
		float up = clamp(h, 0.0, 1.0);
		vec3 gsky = mix(mix(gold_ahead.rgb, gold_horizon.rgb, pow(aft2, 2.2)), gold_zenith.rgb, pow(up, 0.45));
		gsky += gold_pink.rgb * exp(-abs(h - 0.14) * 7.0) * pow(aft2, 1.4) * 0.8;
		col = mix(col, gsky, golden * (h >= 0.0 ? 0.92 : 0.35));
	}
	if (!AT_CUBEMAP_PASS) {
		// stars: one candidate per cell of a cube-ish grid on the sphere, twinkling
		if (h > -0.05) {
			vec3 g = d * 170.0;
			vec3 cell = floor(g);
			float rnd = hash13(cell);
			if (rnd > 1.0 - star_density * 0.12) {
				vec3 c = cell + vec3(hash13(cell + 1.7), hash13(cell + 3.1), hash13(cell + 5.9));
				float dist = length(g - c);
				float tw = 0.75 + 0.25 * sin(TIME * (1.5 + rnd * 4.0) + rnd * 40.0);
				float s = smoothstep(0.42, 0.0, dist) * tw * (0.3 + 0.7 * fract(rnd * 17.0));
				col += vec3(0.85, 0.9, 1.0) * s * star_gain * smoothstep(-0.05, 0.12, h) * (1.0 - dawn) * (1.0 - sunrise * 0.85) * (1.0 - golden);
			}
		}
		if (LIGHT0_ENABLED) {
			float a = acos(clamp(dot(dw, LIGHT0_DIRECTION), -1.0, 1.0));
			float disc = smoothstep(moon_size, moon_size * 0.92, a);
			// a few maria
			vec3 mp = dw - LIGHT0_DIRECTION;
			float maria = 0.82 + 0.18 * sin(mp.x * 400.0) * sin(mp.y * 350.0 + 1.0);
			float disc_s = mix(1.0, 1.35, sun_k);
			disc = smoothstep(moon_size * disc_s, moon_size * disc_s * 0.92, a);
			col = mix(col, mix(moon_color.rgb * 1.6 * maria, sun_color.rgb * 2.6, sun_k), disc);
			col += sun_color.rgb * sun_k * 0.35 * exp(-a * 3.5);
			col += gold_horizon.rgb * golden * (1.2 * exp(-a * 10.0) + 0.12 * exp(-a * 2.5));
			col += moon_color.rgb * 0.3 * exp(-a * 6.0) * (1.0 - dawn);
		}
	}
	COLOR = col;
}
