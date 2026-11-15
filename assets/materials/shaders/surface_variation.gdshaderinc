// UPDATE 19 (T-252): what breaks a tiling texture on a big surface, shared by surface_pbr.gdshader (the generator's
// boxes) and the landscape's near_land.gdshader (Map 0's terrain round the snow slab), so the two meet without a seam.
// World space only; no texture of its own.
//   sv_macro     a slow brightness drift (two octaves, `scale` metres and 3.7x that): 1.0 +- amount * 0.5
//   sv_detile_k  how much of the second, larger sample shows: patches near the camera, most of it far away, where
//                the repeat of a 2-3 m tile is what the eye reads
//   SV_DETILE_SCALE / SV_DETILE_OFFSET  the second sample's uv = uv * scale + offset
//   sv_glint     snow sparkle: a few 1 cm cells get a tilted normal and a low roughness, so they flash under a lamp
//                or the moon as the camera moves and stay dark where no light reaches (never emissive)

const float SV_DETILE_SCALE = 0.37;
const vec3 SV_DETILE_OFFSET = vec3(0.31, 0.57, 0.13);

float sv_hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float sv_vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = sv_hash3(i), n100 = sv_hash3(i + vec3(1, 0, 0)), n010 = sv_hash3(i + vec3(0, 1, 0)), n110 = sv_hash3(i + vec3(1, 1, 0));
	float n001 = sv_hash3(i + vec3(0, 0, 1)), n101 = sv_hash3(i + vec3(1, 0, 1)), n011 = sv_hash3(i + vec3(0, 1, 1)), n111 = sv_hash3(i + vec3(1, 1, 1));
	float x00 = mix(n000, n100, f.x), x10 = mix(n010, n110, f.x), x01 = mix(n001, n101, f.x), x11 = mix(n011, n111, f.x);
	return mix(mix(x00, x10, f.y), mix(x01, x11, f.y), f.z);
}

float sv_macro(vec3 wp, float scale, float amount) {
	float n = sv_vnoise(wp / scale + 71.0) * 0.6 + sv_vnoise(wp / (scale * 3.7) + 13.0) * 0.4;
	return 1.0 + (n - 0.5) * amount;
}

float sv_detile_k(vec3 wp, float dist, float amount) {
	float patch = smoothstep(0.38, 0.66, sv_vnoise(wp / 4.3 + 37.0));
	return amount * mix(patch * 0.55, 0.8, smoothstep(7.0, 32.0, dist));
}

// xy = the tilt of the glinting cell's normal (-1..1), z = how much of a glint this fragment is (0 almost everywhere)
vec3 sv_glint(vec3 wp, float dist, float amount) {
	vec3 cell = floor(vec3(wp.x, 0.0, wp.z) * 85.0);   // xz only: a flat floor at y = 0 must not flip cells on rounding
	float h = sv_hash3(cell);
	float on = step(1.0 - 0.02 * amount, h) * (1.0 - smoothstep(5.0, 16.0, dist));
	return vec3(sv_hash3(cell + 17.0) * 2.0 - 1.0, sv_hash3(cell + 43.0) * 2.0 - 1.0, on);
}
