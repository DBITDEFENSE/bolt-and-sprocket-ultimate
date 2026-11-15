shader_type spatial;
// The blood on the world (GoreFx, docs/gore/gore_rework_2026-11.md): every mark is one instance of one MultiMesh
// quad, shaped here from a noise texture, so a room full of blood is a single draw call and nothing is ticked on
// the CPU: a mark's age comes from its birth time against `now`.
//   INSTANCE_CUSTOM  x = birth (s, GoreFx's clock), y = grow seconds (pool spread / drip run),
//                    z = kind + seed (kind 0 spatter, 1 pool, 2 drip, 3 boot print, 4 smear; seed in [0, 0.99]),
//                    w = strength in [0, 1], + 2 on snow
// Wet blood is a dark arterial red with a low roughness (it catches a lamp); it dries to a near-black brown crust.
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float now = 0.0;
uniform float dry_seconds = 50.0;
uniform float pool_start = 0.22;
uniform vec3 wet_color : source_color = vec3(0.30, 0.012, 0.018);
uniform vec3 dry_color : source_color = vec3(0.075, 0.018, 0.012);
uniform vec3 snow_halo : source_color = vec3(0.42, 0.07, 0.08);

varying float v_age;
varying float v_kind;
varying float v_seed;
varying float v_snow;
varying float v_strength;
varying float v_grow;

void vertex() {
	v_kind = floor(INSTANCE_CUSTOM.z);
	v_seed = fract(INSTANCE_CUSTOM.z);
	v_snow = step(1.5, INSTANCE_CUSTOM.w);
	v_strength = clamp(INSTANCE_CUSTOM.w - 2.0 * v_snow, 0.0, 1.0);
	v_age = max(0.0, now - INSTANCE_CUSTOM.x);
	v_grow = max(0.01, INSTANCE_CUSTOM.y);
	if (v_kind == 1.0) {
		// a pool creeps outward: fast at first, then it slows
		float k = clamp(v_age / v_grow, 0.0, 1.0);
		k = 1.0 - (1.0 - k) * (1.0 - k);
		VERTEX.xy *= mix(pool_start, 1.0, k);
	}
}

float n1(vec2 p) {
	return texture(noise_tex, p).r;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x) / 6.2831853 + 0.5;
	float seed = v_seed * 17.0;
	float mask = 0.0;
	float thick = 0.0;
	if (v_kind == 0.0) {
		// spatter: a ragged core, thin thrown fingers and satellite droplets
		float lobe = n1(vec2(ang * 2.0 + seed, seed * 0.37));
		float ray = n1(vec2(ang * 7.0 + seed * 1.3, 0.61 + seed * 0.11));
		float edge = 0.26 + 0.22 * lobe + 0.46 * smoothstep(0.62, 0.92, ray);
		float core = smoothstep(edge, edge - 0.07, r);
		float dn = n1(p * 1.35 + vec2(seed, seed * 0.7));
		float dots = smoothstep(0.69, 0.74, dn) * smoothstep(1.0, 0.82, r) * smoothstep(edge - 0.1, edge + 0.15, r);
		mask = max(core, dots);
		thick = core * smoothstep(edge, edge * 0.3, r);
	} else if (v_kind == 1.0) {
		// pool: a smooth, lobed blob with a meniscus
		float lobe = n1(vec2(ang + seed, seed * 0.21)) * 0.6 + n1(p * 0.35 + vec2(seed)) * 0.4;
		float edge = 0.52 + 0.42 * lobe;
		mask = smoothstep(edge, edge - 0.035, r);
		thick = smoothstep(edge, edge * 0.45, r);
	} else if (v_kind == 2.0) {
		// drip: a run down the wall from a blot at the top, its front a heavier bead
		float front = clamp(v_age / v_grow, 0.02, 1.0);
		float y = UV.y;
		float cx = (n1(vec2(seed, y * 0.45)) - 0.5) * 0.5 * y;
		float w = mix(0.34, 0.16, smoothstep(0.0, 0.5, y)) * (0.7 + 0.6 * n1(vec2(seed * 2.0, y * 1.3)));
		float line = smoothstep(w, w * 0.45, abs(p.x - cx)) * step(y, front);
		float bead = smoothstep(0.42, 0.2, length(vec2((p.x - cx) * 1.0, (y - front) * 9.0)));
		float blot = smoothstep(0.75, 0.45, length(vec2(p.x, y * 7.0)));
		mask = max(max(line, bead * step(y, front + 0.04)), blot);
		thick = max(bead, line * 0.5);
	} else if (v_kind == 3.0) {
		// boot print: the ball and the heel of a sole, broken up where less blood was left on it
		float ball = smoothstep(1.0, 0.82, length((p - vec2(0.0, -0.3)) / vec2(0.6, 0.62)));
		float heel = smoothstep(1.0, 0.8, length((p - vec2(0.0, 0.66)) / vec2(0.46, 0.3)));
		float worn = smoothstep(0.75 - 0.6 * v_strength, 0.9 - 0.5 * v_strength, n1(p * 0.9 + vec2(seed)));
		float tread = 0.55 + 0.45 * step(0.5, fract(p.y * 5.0 + 0.2));
		mask = max(ball, heel) * (1.0 - worn) * tread;
		thick = 0.0;
	} else {
		// smear: dragged streaks along +x, thinning out toward the far end
		float streak = n1(vec2(UV.x * 0.22 + seed, UV.y * 2.3 + seed * 0.4));
		float body = smoothstep(0.34, 0.6, streak + 0.35 * (1.0 - UV.x));
		float ends = smoothstep(0.0, 0.12, UV.x) * smoothstep(1.0, 0.55, UV.x);
		float side = smoothstep(1.0, 0.72, abs(p.y));
		mask = body * ends * side;
		thick = mask * 0.3;
	}
	// drying: thin edges first, the thick middle of a pool last; a pool stays wet while it still spreads
	float dry_t = v_age - (v_kind == 1.0 ? v_grow : 0.0);
	float dry = clamp(dry_t / (dry_seconds * (0.55 + 0.9 * thick)), 0.0, 1.0);
	vec3 col = mix(wet_color, dry_color, dry);
	col *= mix(1.0, 0.72, thick);                          // deeper where it is thick
	float alpha = mask * mix(0.93, 0.86, dry) * (v_kind == 3.0 ? 0.35 + 0.65 * v_strength : mix(0.75, 1.0, v_strength));
	float rough = mix(0.07 + 0.1 * n1(p * 2.0 + vec2(seed)), 0.78, dry);
	float spec = mix(0.7, 0.25, dry);
	if (v_snow > 0.5) {
		// on snow it soaks in: a stark dark core, a pink halo where it bled into the snow around it, no gloss
		float halo = smoothstep(1.0, 0.25, r) * (0.5 + 0.5 * n1(p * 0.8 + vec2(seed * 0.5)));
		float soak = clamp(v_age / 6.0, 0.0, 1.0);
		float ha = halo * mix(0.25, 0.5, soak) * (v_kind == 3.0 ? v_strength : 1.0);
		col = mix(snow_halo, col * 1.15, clamp(mask * 1.2, 0.0, 1.0));
		alpha = max(alpha, ha * (1.0 - mask));
		rough = mix(0.55, 0.95, soak);
		spec = 0.25;
	}
	ALBEDO = col;
	ALPHA = alpha;
	ROUGHNESS = rough;
	SPECULAR = spec;
	METALLIC = 0.0;
}
