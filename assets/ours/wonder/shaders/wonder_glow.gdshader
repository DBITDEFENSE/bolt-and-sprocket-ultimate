// GRAVELIGHT wonder weapons (T-090): everything on a wonder weapon that gives off its own Nachtglas light. One
// shader, a `mode` per surface (WonderLook sets it from the GLB material name):
//   0 glow       a steady pulse (the Ashlight's emitter crystal, the halo beads);
//   1 coil       the core glowing between the coil turns: a slow crawl along the coil, hot on a shot;
//   2 arc        the Sankt-Elmsfeuer's discharge: hard flicker, bands racing along it, gaps where it breaks;
//   3 runes      Mitternacht's runes: dark until the bell rings, then they flare and fade with it;
//   4 orb        Kugelblitz's ball lightning: a swirling core with a crackling shell;
//   5 halo       the Ashlight Corona's ring: a filament that runs around the ring.
// energy / flash are per-instance (WonderLook.tick drives them from the holder: shots, tolls, the wind, charge).
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform int mode = 0;
uniform vec4 color : source_color = vec4(0.55, 0.20, 1.00, 1.0);
uniform vec4 hot : source_color = vec4(0.95, 0.85, 1.00, 1.0);
uniform float strength = 2.5;
uniform vec3 center = vec3(0.0);
instance uniform float energy = 1.0;
instance uniform float flash = 0.0;

varying vec3 v_local;

float h31(vec3 p) {
	p = fract(p * vec3(0.1031, 0.103, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float vn(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h31(i), h31(i + vec3(1, 0, 0)), f.x), mix(h31(i + vec3(0, 1, 0)), h31(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h31(i + vec3(0, 0, 1)), h31(i + vec3(1, 0, 1)), f.x), mix(h31(i + vec3(0, 1, 1)), h31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	v_local = VERTEX - center;
}

void fragment() {
	float t = TIME;
	float k = 1.0;
	float heat = 0.0;
	if (mode == 0) {
		k = 0.8 + 0.2 * sin(t * 3.1) + 0.15 * vn(v_local * 300.0 + t);
	} else if (mode == 1) {
		k = 0.45 + 0.55 * vn(vec3(v_local.xy * 200.0, v_local.z * 120.0 - t * 2.5));
		heat = flash;
	} else if (mode == 2) {
		float flick = step(0.35, h31(vec3(floor(t * 24.0))));
		float band = vn(vec3(v_local.xy * 900.0, v_local.z * 400.0 + t * 40.0));
		k = (0.4 + 1.6 * band) * (0.35 + 0.65 * flick);
		heat = 0.35 * band + flash;
	} else if (mode == 3) {
		k = 0.08 + 0.12 * sin(t * 1.3);
	} else if (mode == 4) {
		float sw = vn(v_local * 400.0 + vec3(sin(t * 3.0), t * 2.0, cos(t * 2.4)));
		float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		k = 0.7 + 1.3 * sw + pow(1.0 - ndv, 2.0) * 1.5;
		heat = 0.4 * sw + flash;
	} else {
		float a = atan(v_local.y, v_local.x);
		k = 0.5 + 0.8 * pow(0.5 + 0.5 * sin(a * 3.0 - t * 4.0), 6.0) + 0.2 * vn(v_local * 500.0 + t);
		heat = flash;
	}
	vec3 c = mix(color.rgb, hot.rgb, clamp(heat, 0.0, 1.0));
	ALBEDO = c * strength * k * energy * (1.0 + flash * 2.0);
}
