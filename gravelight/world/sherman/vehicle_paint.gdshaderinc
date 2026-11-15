// T-253 (UPDATE 19): the paint of the vehicles built in code (the Sherman, the dive bomber). Our own work.
// One tiling mask (grime / chips / streaks / grain) and one steel normal map, sampled triplanar in MODEL space, so the
// weathering is fixed to the part and does not slide when it drives, turns or flies. On top of the base colour
// (tint x vertex colour): broad grime, rain streaks down the upright faces, paint chipped to bare metal (most along
// the bevelled edges, which ProcKit marks in the vertex colour's alpha: edge = 1 - a), frozen mud up from the ground,
// snow lying on what faces the sky (world space), and the burnt look of the wreck. Optional, for the aircraft:
// a two-tone splinter scheme, a pale underside, panel lines and plain straight-armed crosses, all laid out in model
// space (no decals, nothing to z-fight). Works in Forward+ and in the Compatibility renderer (the web build).
// This file is the body; vehicle_paint.gdshader and vehicle_paint_sky.gdshader (no fog: an aircraft far up in the
// night) include it.

uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D mask_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tex_scale = 0.6;
uniform float rough = 0.72;
uniform float metal = 0.2;
uniform float bump = 0.3;
uniform float grime = 0.5;
uniform vec3 grime_color : source_color = vec3(0.09, 0.075, 0.055);
uniform float chips = 0.45;
uniform vec3 chip_color : source_color = vec3(0.17, 0.13, 0.11);
uniform float chip_cut = 0.0;            // > 0: chipped places are cut away instead (a painted marking over the hull)
uniform float streaks = 0.35;
uniform float snow = 0.0;
uniform vec3 snow_color : source_color = vec3(0.86, 0.9, 0.96);
uniform float mud = 0.0;
uniform vec3 mud_color : source_color = vec3(0.2, 0.16, 0.12);
uniform vec2 mud_y = vec2(0.3, 1.1);     // model y: full mud below x, none above y
uniform float burnt = 0.0;
uniform float glow = 0.0;                // a lamp's lens: emission of the base colour
uniform float lift_hemi = 1.0;
uniform float night_lift = 0.0;          // a little of its own colour given back in the dark, so its shape and paint read at night
// the aircraft's scheme (off when scheme < 0.5)
uniform float scheme = 0.0;
uniform vec3 camo_b : source_color = vec3(0.1, 0.12, 0.1);
uniform vec3 belly_color : source_color = vec3(0.5, 0.6, 0.67);
uniform vec3 band_color : source_color = vec3(0.8, 0.62, 0.1);
uniform vec4 wing_cross = vec4(4.75, -0.42, 0.62, 0.0);   // |x| of its centre, z, half length
uniform vec4 side_cross = vec4(2.35, 0.06, 0.36, 0.0);    // z of its centre, y, half length
uniform vec2 band_z = vec2(2.95, 3.4);
uniform float crosses = 1.0;            // 0: no crosses at all

varying vec3 m_pos;
varying vec3 m_nrm;
varying vec3 ax_x;
varying vec3 ax_y;
varying vec3 ax_z;

void vertex() {
	m_pos = VERTEX;
	m_nrm = NORMAL;
	ax_x = normalize(MODELVIEW_NORMAL_MATRIX * vec3(1.0, 0.0, 0.0));
	ax_y = normalize(MODELVIEW_NORMAL_MATRIX * vec3(0.0, 1.0, 0.0));
	ax_z = normalize(MODELVIEW_NORMAL_MATRIX * vec3(0.0, 0.0, 1.0));
}

float cross_mask(vec2 d, float l, out float white) {
	// a straight-armed cross: black arms of half width 0.2 l, a white edge along them
	vec2 a = abs(d);
	float arm = 0.2 * l;
	float edge = 0.115 * l;
	float aa = 0.012;
	float black = max(
		(1.0 - smoothstep(arm - aa, arm + aa, a.x)) * (1.0 - smoothstep(l - aa, l + aa, a.y)),
		(1.0 - smoothstep(arm - aa, arm + aa, a.y)) * (1.0 - smoothstep(l - aa, l + aa, a.x)));
	float wide = max(
		(1.0 - smoothstep(arm + edge - aa, arm + edge + aa, a.x)) * (1.0 - smoothstep(l - aa, l + aa, a.y)),
		(1.0 - smoothstep(arm + edge - aa, arm + edge + aa, a.y)) * (1.0 - smoothstep(l - aa, l + aa, a.x)));
	white = clamp(wide - black, 0.0, 1.0);
	return black;
}

void fragment() {
	vec3 n = normalize(m_nrm);
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 p = m_pos * tex_scale;
	vec4 mx = texture(mask_tex, p.zy);
	vec4 my = texture(mask_tex, p.xz);
	vec4 mz = texture(mask_tex, p.xy);
	vec4 m = mx * w.x + my * w.y + mz * w.z;
	// a second, broad octave of the grime so the tiling never shows on a long hull side
	vec4 m2 = texture(mask_tex, p.zy * 0.23 + 0.37) * w.x + texture(mask_tex, p.xz * 0.23 + 0.11) * w.y + texture(mask_tex, p.xy * 0.23 + 0.71) * w.z;
	vec3 tx = texture(normal_tex, p.zy * 1.5).xyz * 2.0 - 1.0;
	vec3 ty = texture(normal_tex, p.xz * 1.5).xyz * 2.0 - 1.0;
	vec3 tz = texture(normal_tex, p.xy * 1.5).xyz * 2.0 - 1.0;
	vec3 d = vec3(0.0, tx.y, tx.x) * w.x + vec3(ty.x, 0.0, ty.y) * w.y + vec3(tz.x, tz.y, 0.0) * w.z;

	vec3 base = tint.rgb * COLOR.rgb;
	float edge = clamp(1.0 - COLOR.a, 0.0, 1.0);
	float rgh = rough;
	float mtl = metal;
	float up_m = n.y;

	if (scheme > 0.5) {
		// splinter: straight-edged fields from a few planes through the airframe, top surfaces only
		float f = 0.0;
		f += step(0.0, m_pos.z * 0.8 + m_pos.x * 0.55 + 0.9);
		f += step(0.0, m_pos.z * 0.3 - m_pos.x * 0.95 - 1.6);
		f += step(0.0, -m_pos.z * 0.75 + m_pos.x * 0.66 - 2.9);
		f += step(0.0, m_pos.z * 0.9 + m_pos.x * 0.2 - 2.4);
		f += step(0.0, -m_pos.z * 0.5 - m_pos.x * 0.86 - 3.3);
		f += step(0.0, m_pos.z * 0.2 + m_pos.x * 0.98 - 4.9);
		float alt = mod(f, 2.0);
		base = mix(base, camo_b * COLOR.rgb, alt);
		// the underside
		float under = smoothstep(-0.05, -0.4, n.y);
		base = mix(base, belly_color, under);
		// the theatre band round the rear fuselage
		float bandm = step(band_z.x, m_pos.z) * step(m_pos.z, band_z.y) * step(abs(m_pos.x), 0.6) * step(m_pos.y, 0.62);
		base = mix(base, band_color, bandm);
		// the crosses: on and under each wing (projected along y), on each side of the fuselage (along x)
		float wh = 0.0;
		float bl = 0.0;
		if (abs(n.y) > 0.5 && abs(m_pos.x) > 1.5) {
			bl = cross_mask(vec2(abs(m_pos.x) - wing_cross.x, m_pos.z - wing_cross.y), wing_cross.z, wh);
		} else if (abs(n.x) > 0.45 && abs(m_pos.x) < 0.62 && abs(n.y) < 0.8) {
			bl = cross_mask(vec2(m_pos.z - side_cross.x, m_pos.y - side_cross.y), side_cross.z, wh);
		}
		base = mix(base, vec3(0.82, 0.82, 0.78), wh * crosses);
		base = mix(base, vec3(0.03, 0.03, 0.03), bl * crosses);
		// panel lines: frames along the fuselage, ribs and spars on the wings
		float fr = abs(fract(m_pos.z / 0.62) - 0.5);
		float rb = abs(fract(m_pos.x / 0.55) - 0.5);
		float line = 0.0;
		if (abs(m_pos.x) < 0.62) {
			line = 1.0 - smoothstep(0.0, 0.012, fr);
			line = max(line, (1.0 - smoothstep(0.0, 0.02, abs(fract(m_pos.y / 0.3) - 0.5))) * 0.6);
		} else {
			line = 1.0 - smoothstep(0.0, 0.014, rb);
			line = max(line, (1.0 - smoothstep(0.0, 0.012, abs(fract(m_pos.z / 0.7 + 0.2) - 0.5))) * 0.7);
		}
		base *= 1.0 - 0.3 * line;
		rgh = mix(rgh, rgh * 1.15, line);
	}

	// grime: broad darkening, heavier in the mask's low places; streaks down the upright faces
	float g = clamp(m.r * 0.6 + m2.r * 0.6 - 0.1, 0.0, 1.0);
	base = mix(base, base * 0.55 + grime_color * 0.45, g * grime);
	float upright = 1.0 - smoothstep(0.35, 0.8, abs(n.y));
	vec2 suv = (w.x > w.z) ? vec2(m_pos.z * 1.9, m_pos.y * 0.21) : vec2(m_pos.x * 1.9, m_pos.y * 0.21);
	float st = texture(mask_tex, suv).b;
	base *= 1.0 - streaks * upright * smoothstep(0.5, 0.95, st) * 0.3;
	base *= 0.92 + 0.16 * m.a;

	// chips: where the speckle is high; edges chip first
	float thr = 1.0 - chips * 0.36 - edge * 0.45;
	float chip = smoothstep(thr, thr + 0.05, m.g * 0.8 + m2.g * 0.25);
	chip = max(chip, edge * smoothstep(0.25, 0.6, m.g + m.a * 0.3) * step(0.001, chips));
	if (chip_cut > 0.5) {
		if (chip > 0.5) {
			discard;
		}
	} else {
		base = mix(base, chip_color * (0.7 + 0.6 * m.a), chip);
		rgh = mix(rgh, 0.45, chip);
		mtl = mix(mtl, 0.75, chip);
	}

	// frozen mud from the ground up
	float mudm = (1.0 - smoothstep(mud_y.x, mud_y.y, m_pos.y + (m2.r - 0.5) * 0.35)) * mud;
	mudm *= 0.55 + 0.45 * smoothstep(0.2, 0.7, m.r + m.a * 0.3);
	base = mix(base, mud_color * (0.75 + 0.5 * m.a), mudm);
	rgh = mix(rgh, 0.95, mudm);
	mtl *= 1.0 - mudm;

	// the wreck: paint burnt to scale and rust, ash on the flats
	if (burnt > 0.01) {
		vec3 charred = mix(vec3(0.035, 0.032, 0.03), vec3(0.2, 0.09, 0.04), smoothstep(0.35, 0.8, m.r * 0.7 + m2.g * 0.5));
		charred = mix(charred, vec3(0.3, 0.29, 0.28), smoothstep(0.55, 0.9, m2.r) * smoothstep(0.3, 0.9, up_m) * 0.7);
		base = mix(base, charred * (0.8 + 0.4 * m.a), burnt);
		rgh = mix(rgh, 0.93, burnt);
		mtl = mix(mtl, 0.15, burnt);
	}

	vec3 nm = normalize(n + d * bump);
	vec3 nv = normalize(ax_x * nm.x + ax_y * nm.y + ax_z * nm.z);
	if (!FRONT_FACING) {
		nv = -nv;
	}

	// snow on what faces the sky (world space), patchy; a little frost everywhere
	float sn = snow * (1.0 - burnt);
	if (sn > 0.01) {
		vec3 nw = (INV_VIEW_MATRIX * vec4(nv, 0.0)).xyz;
		float lie = smoothstep(0.74, 0.96, nw.y);
		float patch = smoothstep(1.0 - sn, 1.0 - sn + 0.22, m.r * 0.55 + m2.r * 0.6 + m.a * 0.15);
		float cover = lie * patch;
		cover = max(cover, smoothstep(0.2, 0.9, nw.y) * sn * 0.1 * smoothstep(0.3, 0.8, m.g));
		base = mix(base, snow_color * (0.9 + 0.1 * m.a), cover);
		rgh = mix(rgh, 0.82, cover);
		mtl *= 1.0 - cover;
		nv = normalize(mix(nv, normalize(ax_x * n.x + ax_y * n.y + ax_z * n.z) * (FRONT_FACING ? 1.0 : -1.0), cover * 0.7));
	}

	ALBEDO = base;
	ROUGHNESS = clamp(rgh, 0.05, 1.0);
	METALLIC = clamp(mtl, 0.0, 1.0);
	NORMAL = nv;
	// the night's lift: a little of the paint's own colour given back, so the shape reads where no lamp reaches. It
	// comes as the sky's light would (more on what faces up, a little blue; lift_hemi 0 makes it even, for an aircraft
	// seen from below) and it is pressed flat for pale paint, so a white star or a pale belly never glows.
	vec3 nl = (INV_VIEW_MATRIX * vec4(nv, 0.0)).xyz;
	vec3 soft = base / (1.0 + 6.0 * base);
	EMISSION = base * glow + soft * vec3(0.8, 0.9, 1.15) * (night_lift * mix(1.0, 0.6 + 0.4 * nl.y, lift_hemi));
}
