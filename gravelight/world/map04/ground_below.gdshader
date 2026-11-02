shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, fog_disabled, shadows_disabled;
// What lies under der Kranich (UPDATE 09 section 5.3, DECISIONS T-147; our own). A camera-following plane far below
// with everything procedural in world space plus `scroll` (the flight): the North Sea / the Atlantic (black water,
// long swells, the moon's glitter path), a coastline sweeping past (`coast_z`, the line's world z; land on the +Z side
// when land_ahead, else on the -Z side) with surf, blacked-out fields and a few town lights, London (a river and the
// city's dim grid of light round `city_pos`, fires), and the salt flat at dawn for the crash (`desert`). It fades to
// the sky's haze colour before the camera's far plane, so the edge is never seen.

uniform vec2 scroll = vec2(0.0);
uniform vec3 center = vec3(0.0);
uniform float radius = 390.0;
uniform vec4 haze_color : source_color = vec4(0.03, 0.036, 0.055, 1.0);
uniform vec4 sea_color : source_color = vec4(0.02, 0.03, 0.05, 1.0);
uniform vec4 land_color : source_color = vec4(0.035, 0.038, 0.032, 1.0);
uniform vec4 light_color : source_color = vec4(1.0, 0.7, 0.4, 1.0);
uniform vec3 moon_dir = vec3(-0.4, 0.45, 0.8);   // toward the moon
uniform float coast_z = 100000.0;
uniform float land_ahead = 1.0;
uniform float lights : hint_range(0.0, 1.0) = 0.1;
uniform float city : hint_range(0.0, 1.0) = 0.0;
uniform vec3 city_pos = vec3(74.0, -40.0, -120.0);
uniform float fires : hint_range(0.0, 1.0) = 0.0;
uniform float desert : hint_range(0.0, 1.0) = 0.0;
uniform vec4 desert_color : source_color = vec4(0.78, 0.74, 0.66, 1.0);
uniform float world_scale = 1.0;                 // > 1 makes features look further away (altitude)

varying vec3 wpos;

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.07 + vec2(5.3, 1.7);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 w = (wpos.xz + scroll) * world_scale;
	// the sea: long swells across the track, the moon's path
	float swell = sin(w.x * 0.05 + vnoise(w * 0.01) * 6.0 + TIME * 0.3) * 0.5 + 0.5;
	float chop = vnoise(w * 0.12 + vec2(TIME * 0.05, 0.0));
	vec3 v = normalize(CAMERA_POSITION_WORLD - wpos);
	vec3 n = normalize(vec3((chop - 0.5) * 0.35, 1.0, (swell - 0.5) * 0.25));
	vec3 hlf = normalize(normalize(moon_dir) + v);
	float glit = pow(max(dot(n, hlf), 0.0), 220.0) * 3.0;
	vec3 sea = sea_color.rgb * (0.7 + 0.5 * swell) + vec3(0.6, 0.65, 0.8) * glit;
	// the land: fields and woods, blacked out, a few lights (towns that forgot)
	float fields = vnoise(floor(w / 37.0)) * 0.6 + fbm(w * 0.02) * 0.4;
	vec3 land = land_color.rgb * (0.6 + fields * 0.8);
	vec2 cell = floor(w / 9.0);
	float lr = hash12(cell);
	float lp = smoothstep(0.42, 0.0, length(fract(w / 9.0) - 0.5 - (vec2(hash12(cell + 3.0), hash12(cell + 7.0)) - 0.5) * 0.6));
	float town = smoothstep(0.55, 0.8, fbm(w * 0.004 + 11.0));
	land += light_color.rgb * lp * step(1.0 - lights * (0.04 + 0.4 * town), lr) * 1.4;
	// London: the river and the grid of the city round city_pos, its fires
	if (city > 0.0) {
		vec2 cp = wpos.xz - city_pos.xz;
		float cd = length(cp);
		float urban = smoothstep(260.0, 40.0, cd);
		float river = smoothstep(9.0, 4.0, abs(cp.y - 30.0 * sin(cp.x * 0.012) - 12.0 * sin(cp.x * 0.041)));
		vec2 g = abs(fract(cp / vec2(6.0, 8.0)) - 0.5);
		float streets = smoothstep(0.47, 0.5, max(g.x, g.y));
		vec3 c = land_color.rgb * 1.4 + light_color.rgb * streets * 0.25 * urban;
		c += light_color.rgb * lp * step(0.75, lr) * urban * 1.2;
		float fire = smoothstep(0.62, 0.9, fbm(cp * 0.05 + TIME * 0.1)) * urban * fires;
		c += vec3(1.0, 0.45, 0.15) * fire * 1.6 + vec3(0.6, 0.25, 0.9) * fire * 0.5;
		c = mix(c, sea_color.rgb * 1.6 + vec3(0.04, 0.05, 0.08) * glit, river);
		land = mix(land, c, urban * city);
	}
	// the coastline: a wavy line across the track at coast_z, surf on it
	float line = wpos.z - coast_z + (fbm(vec2(wpos.x * 0.004, 3.0)) - 0.5) * 220.0;
	float side = land_ahead > 0.5 ? line : -line;
	float on_land = smoothstep(-3.0, 3.0, side);
	float surf = (1.0 - smoothstep(0.0, 6.0, abs(side))) * (0.6 + 0.4 * sin(TIME * 1.3 + wpos.x * 0.1));
	vec3 col = mix(sea, land, on_land) + vec3(0.25, 0.28, 0.32) * surf * 0.5;
	// the salt flat at dawn (the crash)
	vec3 salt = desert_color.rgb * (0.85 + 0.15 * fbm(w * 0.05)) * 0.9;
	col = mix(col, salt, desert);
	// haze to the sky's colour before the far plane
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	float haze = smoothstep(radius * 0.25, radius * 0.95, dist);
	col = mix(col, haze_color.rgb * mix(1.0, 6.0, desert), haze);
	ALBEDO = col;
}
