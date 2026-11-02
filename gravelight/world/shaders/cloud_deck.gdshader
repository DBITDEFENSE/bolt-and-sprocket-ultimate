// Werk Thalbach's low cloud deck (UPDATE 09 §5, T-146; gravelight/world/map04/thalbach_sky.gd): drifting fbm cloud
// seen from below, dark, with the searchlights' spots glowing where the beams hit it (up to 4 spots), and a cold
// band toward the east where the dawn never comes. Unshaded and fog-free (the scene fog would swallow it); works
// in Compatibility.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 cloud_color : source_color = vec4(0.09, 0.1, 0.13, 0.85);
uniform vec4 lit_color : source_color = vec4(0.62, 0.68, 0.8, 1.0);
uniform vec4 dawn_color : source_color = vec4(0.26, 0.2, 0.24, 1.0);
uniform vec3 dawn_dir = vec3(1.0, 0.0, -0.25);
uniform float scale = 0.006;
uniform float drift = 2.0;
uniform float spot_radius = 16.0;
uniform vec4 spots[4];
uniform float radius = 650.0;

varying vec3 wpos;

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
	for (int i = 0; i < 5; i++) {
		s += a * vnoise(p);
		p = p * 2.07 + vec2(3.1, 1.7);
		a *= 0.5;
	}
	return s;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz * scale + vec2(TIME * drift * scale, TIME * drift * scale * 0.4);
	float c = smoothstep(0.32, 0.78, fbm(p));
	vec3 col = cloud_color.rgb * (0.6 + 0.6 * c);
	float lit = 0.0;
	for (int i = 0; i < 4; i++) {
		vec2 d = wpos.xz - spots[i].xz;
		lit += spots[i].w * exp(-dot(d, d) / (spot_radius * spot_radius)) * (0.35 + 0.9 * c);
	}
	col += lit_color.rgb * lit;
	vec2 cen = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xz;
	vec2 off = wpos.xz - cen;
	float dist = length(off);
	float east = max(0.0, dot(normalize(off), normalize(dawn_dir.xz)));
	col += dawn_color.rgb * pow(east, 3.0) * smoothstep(radius * 0.25, radius, dist) * (0.4 + 0.6 * c);
	ALBEDO = col;
	ALPHA = cloud_color.a * (0.35 + 0.65 * c) * (1.0 - smoothstep(radius * 0.7, radius, dist));
}
