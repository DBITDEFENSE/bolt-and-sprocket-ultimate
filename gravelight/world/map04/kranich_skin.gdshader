shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;
// Der Kranich's riveted skin (UPDATE 09 section 5.3, DECISIONS T-147). The base is a CC0 painted steel sheet
// (Poly Haven "Blue Metal Plate", data/gravelight/materials.json "kranich_skin"), desaturated and tinted to the
// grey-green interior primer; on top this shader draws what the brief asks of the skin, procedurally (our own work):
// the rivet rows on the frame lines (a double row), the rivet rows on the stringer lines, the sheet seams every
// other frame bay and every third stringer, a little oil and wear. The shell's UVs are metres along (the frame axis,
// the profile's arc) (tools_src/blender/world/kranich_shell.py), so frame_offset / frame_pitch put the rows exactly on
// the frames of each room. Compatibility-safe (no derivatives beyond fwidth, no screen textures).

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile_m = 2.5;
uniform vec4 primer : source_color = vec4(0.40, 0.42, 0.37, 1.0);   // RLM 02-ish grey-green
uniform float tex_contrast : hint_range(0.0, 2.0) = 0.9;
uniform float rough_min : hint_range(0.0, 1.0) = 0.38;
uniform float rough_max : hint_range(0.0, 1.0) = 0.82;
uniform float metal : hint_range(0.0, 1.0) = 0.25;
// the rivet layout (metres)
uniform bool rivets = true;
uniform float frame_offset = 0.75;
uniform float frame_pitch = 1.5;
uniform float stringer_offset = 0.45;
uniform float stringer_pitch = 0.55;
uniform float rivet_spacing = 0.05;
uniform float rivet_radius = 0.007;
uniform float row_gap = 0.032;       // the double row either side of a frame line
uniform float seam_darken : hint_range(0.0, 1.0) = 0.55;
uniform float grime : hint_range(0.0, 1.0) = 0.3;

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

// distance to the nearest rivet of a row along the line coord == 0 (d_line = distance across the row, s = along it)
vec2 rivet(float d_line, float s, float spacing) {
	float ds = (fract(s / spacing + 0.5) - 0.5) * spacing;
	return vec2(d_line, ds);
}

void fragment() {
	vec2 uv = UV;
	vec2 tuv = uv / tile_m;
	vec3 base = texture(albedo_tex, tuv).rgb;
	float lum = dot(base, vec3(0.299, 0.587, 0.114));
	float lum_mid = 0.16;
	vec3 col = primer.rgb * clamp(1.0 + (lum - lum_mid) / lum_mid * 0.5 * tex_contrast, 0.35, 1.8);
	vec3 orm = texture(orm_tex, tuv).rgb;
	vec3 nm = texture(normal_tex, tuv).rgb;
	vec2 nxy = nm.xy * 2.0 - 1.0;
	float rough = mix(rough_min, rough_max, orm.g);
	float ao = mix(1.0, orm.r, 0.7);

	if (rivets) {
		float aa = max(fwidth(uv.x), fwidth(uv.y));
		float fade = clamp(1.0 - aa * 55.0, 0.0, 1.0);          // rivets fade out far away (no shimmer)
		// frame lines
		float fu = (uv.x - frame_offset) / frame_pitch;
		float fk = floor(fu + 0.5);
		float du = (fu - fk) * frame_pitch;                        // metres across the frame line
		// sheet seam on every other frame line, every third stringer line
		float su = (uv.y - stringer_offset) / stringer_pitch;
		float sk = floor(su + 0.5);
		float dv = (su - sk) * stringer_pitch;
		bool seam_u = mod(fk, 2.0) < 0.5;
		bool seam_v = mod(sk, 3.0) < 0.5;
		float seam = 0.0;
		float sw = 0.0035 + aa;
		if (seam_u) { seam = max(seam, 1.0 - smoothstep(0.0, sw, abs(du))); }
		if (seam_v) { seam = max(seam, 1.0 - smoothstep(0.0, sw, abs(dv))); }
		// rivet heads: a double row on the frames, a single row on the stringers
		float r = rivet_radius;
		vec2 q1 = rivet(abs(abs(du) - row_gap), uv.y, rivet_spacing);
		vec2 q2 = rivet(abs(dv), uv.x, rivet_spacing * 1.4);
		float d1 = length(q1);
		float d2 = length(q2);
		float m1 = 1.0 - smoothstep(r - aa, r + aa, d1);
		float m2 = 1.0 - smoothstep(r * 0.85 - aa, r * 0.85 + aa, d2);
		float head = max(m1, m2) * fade;
		// the dome's normal tilt (tangent space x along u, y along v)
		vec2 off = d1 < d2 ? vec2(sign(abs(du) - row_gap) * sign(du) * q1.x, q1.y) : vec2(q2.y, sign(dv) * q2.x);
		vec2 tilt = off / max(r, 1e-4) * 0.8 * head;
		nxy = mix(nxy, tilt, head);
		// the rows' oil streaks and the heads catching the light
		col *= 1.0 - seam * seam_darken * fade;
		col = mix(col, col * 1.25 + vec3(0.03), head);
		rough = mix(rough, 0.3, head);
		// a faint lap shadow along the frame lines (the sheet overlaps)
		float lap = 1.0 - smoothstep(0.0, 0.06, abs(du));
		ao *= 1.0 - lap * 0.25;
	}
	// oil and grime pooled low (y = arc metres from the deck)
	float g = vnoise(uv * 1.7) * 0.6 + vnoise(uv * 6.3) * 0.4;
	float low = 1.0 - smoothstep(0.0, 1.1, uv.y);
	col = mix(col, col * vec3(0.55, 0.5, 0.42), clamp(g * grime + low * grime * 0.6, 0.0, 0.8));

	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal * orm.b + metal * 0.3;
	AO = ao;
	AO_LIGHT_AFFECT = 0.4;
	NORMAL_MAP = vec3(nxy * 0.5 + 0.5, 1.0);
	NORMAL_MAP_DEPTH = 1.0;
}
