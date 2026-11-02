// Weathering cards for the generators' detail library (UPDATE 09 §5, T-146; gravelight/tools_src/gen_detail_lib.gd):
// a unit quad laid on a wall or a floor that draws its own mask procedurally, so no texture is stored and the
// cards batch as one MultiMesh per kind. Works in Forward+ and Compatibility (no decals, no instance uniforms):
// the per-card variation comes from the card's world position.
//   kind 0 rust streak   a rust bloom at the top running down in drips (wall)
//   kind 1 frost         a feathered rime patch with crystal speckle (wall or floor)
//   kind 2 soot          a scorch: dark centre, ragged edge (wall or floor)
//   kind 3 water stain   a dark wet run with a tide line (wall)
//   kind 4 chalk         a pale dusty smear (floor: the edge of a chalk game; wall: rubbed-out marks)
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx;

uniform int kind = 0;
uniform vec4 tint : source_color = vec4(0.36, 0.17, 0.08, 0.8);
uniform float roughness_v = 0.9;

varying vec3 seed_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return s;
}

void vertex() {
	seed_pos = MODEL_MATRIX[3].xyz;
}

void fragment() {
	vec2 uv = UV;
	float s = hash(seed_pos.xz + seed_pos.yy * 0.37) * 37.0;
	float a = 0.0;
	vec3 col = tint.rgb;
	if (kind == 0) {
		// rust: a bloom near the top (uv.y 0), drips running down in columns
		float cols = vnoise(vec2(uv.x * 9.0 + s, 0.5));
		float drip = smoothstep(0.35, 0.95, cols) * (1.0 - smoothstep(0.15 + cols * 0.75, 0.25 + cols * 0.8, uv.y));
		float bloom = (1.0 - smoothstep(0.0, 0.22, uv.y)) * smoothstep(0.0, 0.25, uv.x) * smoothstep(0.0, 0.25, 1.0 - uv.x);
		a = max(drip, bloom * 0.8) * (0.55 + 0.45 * fbm(uv * 7.0 + s));
		col *= 0.7 + 0.5 * fbm(uv * 13.0 - s);
	} else if (kind == 1) {
		vec2 c = uv - 0.5;
		float r = length(c) * 2.0 + (fbm(uv * 5.0 + s) - 0.5) * 0.7;
		a = (1.0 - smoothstep(0.45, 1.0, r)) * (0.45 + 0.55 * fbm(uv * 23.0 + s));
		a *= 0.75 + 0.5 * step(0.82, hash(floor(uv * 90.0) + s));
	} else if (kind == 2) {
		vec2 c2 = uv - 0.5;
		float r2 = length(c2) * 2.0 + (fbm(uv * 4.0 + s) - 0.5) * 0.9;
		a = 1.0 - smoothstep(0.2, 0.95, r2);
		col *= 0.6 + 0.6 * fbm(uv * 9.0 + s);
	} else if (kind == 3) {
		float wob = (fbm(vec2(uv.y * 3.0, s)) - 0.5) * 0.3;
		float band = 1.0 - smoothstep(0.18, 0.5, abs(uv.x - 0.5 + wob) * 2.0 * (0.6 + uv.y));
		a = band * (1.0 - smoothstep(0.7, 1.0, uv.y)) * (0.5 + 0.5 * fbm(uv * 6.0 + s));
		a += 0.25 * smoothstep(0.02, 0.0, abs(uv.y - 0.08 - wob * 0.2)) * band;
	} else {
		vec2 c3 = uv - 0.5;
		float r3 = max(abs(c3.x), abs(c3.y)) * 2.0 + (fbm(uv * 8.0 + s) - 0.5) * 0.5;
		a = (1.0 - smoothstep(0.55, 1.0, r3)) * fbm(uv * 18.0 + s) * 0.9;
	}
	ALBEDO = col;
	ALPHA = clamp(a * tint.a, 0.0, 1.0);
	ROUGHNESS = roughness_v;
	SPECULAR = 0.2;
}
