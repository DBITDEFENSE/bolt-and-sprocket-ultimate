// Cut-out meshes for the generators' detail library (UPDATE 09 §5, T-146): patterns drawn in WORLD space, so the
// static batching may merge the panels (it drops UVs) and a panel of any size keeps the same mesh pitch.
//   kind 0 chain-link   a diamond wire mesh (fences, the tool cage)
//   kind 1 camo netting a knotted net with cloth scrim patches in two greens and a brown; the vertices sag
//                       between the support points (sag_m) so a flat plane drapes
//   kind 2 broken glass a dirty pane with holes punched in it (shards stay at the frame)
// Alpha scissor, double-sided, lit; casts no shadow by default (the generator turns it off on the node).
shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha, specular_schlick_ggx;

uniform int kind = 0;
uniform vec4 color_a : source_color = vec4(0.42, 0.43, 0.42, 1.0);
uniform vec4 color_b : source_color = vec4(0.25, 0.3, 0.18, 1.0);
uniform vec4 color_c : source_color = vec4(0.32, 0.26, 0.17, 1.0);
uniform float pitch = 0.06;          // chain-link diamond size / net mesh size (m)
uniform float wire = 0.12;           // wire thickness as a fraction of the pitch
uniform float scrim = 0.55;          // netting: share of the net covered by cloth scrim
uniform float sag_m = 0.0;           // netting: the drape between the support points
uniform float post_step = 6.0;       // netting: support spacing (m)
uniform float metal = 0.4;
uniform float rough = 0.6;

varying vec3 wpos;
varying vec3 wnrm;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (sag_m > 0.0) {
		vec2 q = fract(w.xz / post_step) - 0.5;
		float d = 1.0 - max(abs(q.x), abs(q.y)) * 2.0;     // 1 between the posts, 0 at them
		float drop = sag_m * clamp(d, 0.0, 1.0) * (0.75 + 0.5 * vnoise(w.xz * 0.21));
		w.y -= drop;
		VERTEX = (inverse(MODEL_MATRIX) * vec4(w, 1.0)).xyz;
	}
	wpos = w;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// project the world position on the panel's plane: pick the two axes the normal is not
	vec3 an = abs(wnrm);
	vec2 p = an.y > max(an.x, an.z) ? wpos.xz : (an.x > an.z ? wpos.zy : wpos.xy);
	vec3 col = color_a.rgb;
	float keep = 1.0;
	if (kind == 0) {
		vec2 r = vec2(p.x + p.y, p.x - p.y) / pitch;
		vec2 f = abs(fract(r) - 0.5);
		float m = min(f.x, f.y);
		keep = step(m, wire);
		col *= 0.8 + 0.3 * vnoise(p * 3.0);
	} else if (kind == 1) {
		vec2 g = p / pitch;
		vec2 f2 = abs(fract(g) - 0.5);
		float knot = step(min(f2.x, f2.y), wire);
		float n = vnoise(p * 1.3) * 0.6 + vnoise(p * 3.7) * 0.4;
		float cloth = step(1.0 - scrim, n);
		keep = max(knot, cloth);
		float pick = vnoise(p * 0.6 + 11.0);
		col = pick < 0.4 ? color_a.rgb : (pick < 0.72 ? color_b.rgb : color_c.rgb);
		col *= 0.75 + 0.35 * vnoise(p * 9.0);
		if (cloth < 0.5) {
			col = color_c.rgb * 0.6;
		}
	} else {
		vec2 cell = floor(p * 2.3);
		float hole = vnoise(p * 2.1) + vnoise(p * 7.0) * 0.3;
		keep = step(hole, 0.62);
		col = mix(color_a.rgb, color_c.rgb, vnoise(p * 4.0));
	}
	if (keep < 0.5) {
		discard;
	}
	ALBEDO = col;
	METALLIC = metal;
	ROUGHNESS = rough;
}
