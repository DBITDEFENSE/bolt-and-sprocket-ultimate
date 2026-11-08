shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;
// Der Kranich's OUTER skin (T-220, the plane pass; our own). Everything is procedural in world space (metres), so one
// material covers the whole generated hull (gravelight/world/map04/kranich_exterior.gd): the upper camouflage in two
// greys, the night-black underside, the sheet seams and the rivet rows (the ribs every rib_pitch m along the span, the
// staggered sheet seams along the chord, a stringer rivet row between), access panels with their screws and the oil
// that runs aft from them in the slipstream, wear on the panel edges down to bare metal, exhaust soot behind the four
// nozzles, the stencils from the markings atlas (top only), the frost the act's living world raises on the inner skin
// (copied over). The base grain is the CC0 plate the inner skin uses (data/gravelight/materials.json kranich_skin).
// Backfaces cull: from inside the plane (a blister, the glass, a breach) the outer skin never draws.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D marks_tex : source_color, filter_linear_mipmap_anisotropic, hint_default_transparent;
uniform float tile_m = 2.5;
uniform vec4 top_a : source_color = vec4(0.231, 0.243, 0.216, 1.0);
uniform vec4 top_b : source_color = vec4(0.29, 0.31, 0.263, 1.0);
uniform vec4 under : source_color = vec4(0.098, 0.102, 0.11, 1.0);
uniform vec4 bare : source_color = vec4(0.55, 0.57, 0.59, 1.0);
uniform vec4 soot_color : source_color = vec4(0.082, 0.075, 0.067, 1.0);
uniform vec4 oil_color : source_color = vec4(0.165, 0.13, 0.086, 1.0);
uniform float rib_pitch = 1.5;
uniform float seam_pitch = 2.4;
uniform float rivet_spacing = 0.07;
uniform float rivet_radius = 0.009;
uniform float grime : hint_range(0.0, 1.0) = 0.5;
uniform float frost : hint_range(0.0, 1.0) = 0.0;
// the nozzles: (x, exit z, forward end z, radius); soot runs aft of the fairing over the trailing edge apron
uniform vec4 engines[4];
uniform int engine_count = 0;
// stencils: rect (centre x, centre z, half w, half h), cell (atlas row 0..7), rotation (rad), colour
uniform vec4 mk_rect[12];
uniform vec4 mk_cell[12];     // x = row, y = cos, z = sin
uniform vec4 mk_col[12];
uniform int mk_count = 0;

varying vec3 wpos;
varying vec3 wnrm;

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

float fbm3(vec2 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.1 + 7.3) * 0.3 + vnoise(p * 4.3 + 1.7) * 0.15;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(wnrm);
	bool top = n.y > 0.35;
	bool bottom = n.y < -0.35;
	// the surface coordinate: span (x) and chord (z) on the wing's faces, the face's own plane on the steep ones
	vec2 s;
	if (top || bottom) {
		s = wpos.xz;
	} else if (abs(n.x) > abs(n.z)) {
		s = vec2(wpos.z, wpos.y);
	} else {
		s = vec2(wpos.x, wpos.y);
	}
	vec2 tuv = s / tile_m;
	vec3 base = texture(albedo_tex, tuv).rgb;
	vec3 orm = texture(orm_tex, tuv).rgb;
	vec2 nxy = texture(normal_tex, tuv).rgb.xy * 2.0 - 1.0;
	float lum = dot(base, vec3(0.299, 0.587, 0.114));
	float grain = clamp(1.0 + (lum - 0.16) / 0.16 * 0.35, 0.6, 1.4);

	// paint: a soft-edged two-grey splinter on top, black underneath
	float camo = smoothstep(0.47, 0.53, fbm3(s * vec2(0.035, 0.05) + vec2(3.1, 1.7)));
	vec3 paint = bottom ? under.rgb : mix(top_a.rgb, top_b.rgb, camo);
	// each sheet a hair different (re-skinned, touched up)
	float rib_u = s.x / rib_pitch;
	float rib_k = floor(rib_u);
	float seam_off = hash12(vec2(rib_k, 3.0)) * seam_pitch;
	float seam_v = (s.y + seam_off) / seam_pitch;
	float seam_k = floor(seam_v);
	vec2 sheet = vec2(rib_k, seam_k);
	paint *= 0.86 + 0.28 * hash12(sheet + 11.0);
	vec3 col = paint * grain;
	float rough = mix(0.4, 0.62, orm.g);
	float metal = 0.42;
	float ao = mix(1.0, orm.r, 0.6);

	// seams, rivets (faded out with distance so they never shimmer)
	float aa = max(fwidth(s.x), fwidth(s.y));
	float fade = clamp(1.0 - aa * 40.0, 0.0, 1.0);
	float du = (fract(rib_u) - 0.5) * rib_pitch;          // metres from the panel's centre line across the span
	float d_rib = 0.5 * rib_pitch - abs(du);              // metres to the nearest rib line
	float d_seam = (0.5 - abs(fract(seam_v) - 0.5)) * seam_pitch;
	float sw = 0.004 + aa * 0.8;
	float seam = max(1.0 - smoothstep(0.0, sw, d_rib), 1.0 - smoothstep(0.0, sw, d_seam));
	col *= 1.0 - seam * 0.55;
	// rivets: a double row either side of every rib line, a single row on the seams and on a stringer mid-sheet
	float rr = rivet_radius;
	vec2 q1 = vec2(abs(d_rib - 0.03), (fract(s.y / rivet_spacing) - 0.5) * rivet_spacing);
	float d_str = abs((fract(seam_v) - 0.5) * seam_pitch);
	vec2 q2 = vec2(min(d_seam - 0.025, d_str) , (fract(s.x / (rivet_spacing * 1.3)) - 0.5) * rivet_spacing * 1.3);
	q2.x = abs(q2.x);
	float head = max(1.0 - smoothstep(rr - aa, rr + aa, length(q1)), 1.0 - smoothstep(rr * 0.85 - aa, rr * 0.85 + aa, length(q2))) * fade;
	col = mix(col, col * 1.22 + vec3(0.025), head);
	rough = mix(rough, 0.36, head);
	vec2 tilt = (length(q1) < length(q2) ? vec2(q1.x, q1.y) : vec2(q2.y, q2.x)) / max(rr, 1e-4) * 0.7 * head;
	nxy = mix(nxy * 0.6, tilt, head);

	// access panels: one sheet in ~14 carries a screwed panel; oil runs aft (-z) from it in the slipstream
	float oil = 0.0;
	if (top || bottom) {
		float ph = hash12(sheet + 41.0);
		if (ph < 0.07) {
			vec2 c = vec2((rib_k + 0.5) * rib_pitch, (seam_k + 0.5) * seam_pitch - seam_off);
			vec2 hs = vec2(0.32 + 0.12 * hash12(sheet + 5.0), 0.42 + 0.3 * hash12(sheet + 9.0));
			vec2 dp = abs(s - c) - hs;
			float edge = 1.0 - smoothstep(0.0, sw * 1.5, abs(max(dp.x, dp.y)));
			col *= 1.0 - edge * 0.6 * fade;
			vec2 sc = abs(abs(s - c) - hs + 0.045);
			float screw = 1.0 - smoothstep(0.011, 0.016, length(sc));
			col = mix(col, bare.rgb * 0.7, screw * fade);
			// the streak behind it (aft = -z), ragged
			float behind = c.y - hs.y - s.y;
			if (behind > 0.0 && abs(s.x - c.x) < hs.x) {
				oil = max(oil, exp(-behind / (2.5 + 4.0 * ph * 14.0)) * smoothstep(0.35, 0.75, vnoise(vec2(s.x * 14.0, s.y * 0.6))));
			}
		}
		// the long faint slipstream streaks everywhere (dirt carried aft)
		float streak = vnoise(vec2(s.x * 3.1, s.y * 0.08)) * vnoise(vec2(s.x * 0.7, s.y * 0.05 + 3.0));
		oil = max(oil, smoothstep(0.35, 0.7, streak) * 0.35);
	}
	col = mix(col, oil_color.rgb, oil * 0.55);
	rough = mix(rough, 0.32, oil * 0.5);

	// wear: chipped paint near seams and rivets, bare metal showing (up-faces more: boots, hail, ice)
	float chip = smoothstep(0.66, 0.78, fbm3(s * 7.0)) * (1.0 - smoothstep(0.0, 0.09, min(d_rib, d_seam))) * (top ? 1.0 : 0.35);
	col = mix(col, bare.rgb * grain, chip * 0.8);
	metal = mix(metal, 0.85, chip);
	rough = mix(rough, 0.42, chip);

	// exhaust soot over the trailing-edge apron behind and either side of each nozzle
	float soot = 0.0;
	for (int i = 0; i < engine_count; i++) {
		vec4 e = engines[i];
		float dx = abs(wpos.x - e.x);
		float along = e.z + 9.0 - wpos.z;                     // from the fairing's tail to the trailing edge, growing aft
		if (along > 0.0) {
			float w = e.w * 1.3 + along * 0.18;
			float k = exp(-(dx * dx) / (w * w)) * smoothstep(0.0, 6.0, along) * (0.6 + 0.4 * vnoise(vec2(wpos.x * 2.0, wpos.z * 0.4)));
			soot = max(soot, k);
		}
	}
	col = mix(col, soot_color.rgb, clamp(soot, 0.0, 1.0) * 0.85);
	rough = mix(rough, 0.86, soot);
	metal = mix(metal, 0.05, soot);

	// stencils (the upper skin only), worn by the same grime
	if (top) {
		for (int i = 0; i < mk_count; i++) {
			vec4 r = mk_rect[i];
			vec2 d = wpos.xz - r.xy;
			vec2 l = vec2(d.x * mk_cell[i].y + d.y * mk_cell[i].z, -d.x * mk_cell[i].z + d.y * mk_cell[i].y);
			vec2 u = l / r.zw * 0.5 + 0.5;
			if (u.x > 0.0 && u.x < 1.0 && u.y > 0.0 && u.y < 1.0) {
				float a = texture(marks_tex, vec2(u.x, (mk_cell[i].x + 1.0 - u.y) / 8.0)).a;
				a *= 1.0 - smoothstep(0.45, 0.8, fbm3(wpos.xz * 2.3)) * 0.7;
				col = mix(col, mk_col[i].rgb * grain, a * 0.85);
			}
		}
	}

	// grime: dark and dull in the low-frequency blotches
	float g = fbm3(s * 0.45);
	col = mix(col, col * vec3(0.7, 0.68, 0.63), clamp(g * grime, 0.0, 0.6));

	if (frost > 0.0 && top) {
		float fn = fbm3(s * 1.7) + n.y * 0.1;
		float fr = frost * smoothstep(0.62 - frost * 0.3, 0.9, fn);
		col = mix(col, vec3(0.72, 0.77, 0.82), fr * 0.65);
		rough = mix(rough, 0.6, fr);
	}
	ALBEDO = col;
	ROUGHNESS = clamp(rough, 0.35, 1.0);
	METALLIC = metal;
	AO = ao;
	AO_LIGHT_AFFECT = 0.3;
	NORMAL_MAP = vec3(nxy * 0.5 + 0.5, 1.0);
	NORMAL_MAP_DEPTH = 0.8;
}
