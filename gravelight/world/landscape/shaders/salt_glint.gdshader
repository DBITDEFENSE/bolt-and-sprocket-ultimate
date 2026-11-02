// Salt crystals glinting in the viewer's light (UPDATE 10 section 5, T-161). An additive pass laid over the halite
// materials as their next_pass (MapAmbience._u10_build_glint): the wall is cut into ~7 cm cells, each with its own
// random crystal face; a cell flashes only when that face mirrors the lamp into the eye, so the sparkles crawl over
// the wall as the player's head moves. The "lamp" is the viewer's headlamp cone (the game has no flashlight):
// MapAmbience writes lamp_pos / lamp_dir / lamp_on from the local camera every 50 ms and switches it on underground.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, fog_disabled, shadows_disabled;

uniform vec3 lamp_pos = vec3(0.0);
uniform vec3 lamp_dir = vec3(0.0, 0.0, -1.0);
uniform float lamp_on = 0.0;
uniform float lamp_range = 16.0;
uniform float cone_cos = 0.78;
uniform float strength = 1.5;
uniform float cell = 0.07;
uniform vec3 tint : source_color = vec3(0.92, 0.96, 1.0);

varying vec3 wpos;
varying vec3 wnrm;

float h31(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (lamp_on < 0.01) {
		discard;
	}
	vec3 q = wpos / cell;
	vec3 id = floor(q);
	float r = h31(id);
	if (r < 0.7) {
		discard;
	}
	// a round-ish speck inside the cell
	vec3 f = fract(q) - 0.5;
	float speck = smoothstep(0.42, 0.12, length(f));
	// the crystal face: the wall normal tilted at random
	vec3 jit = vec3(h31(id + 3.1), h31(id + 7.7), h31(id + 1.3)) - 0.5;
	vec3 n = normalize(wnrm + jit * 1.5);
	vec3 L = lamp_pos - wpos;
	float dist = length(L);
	L /= max(dist, 0.001);
	vec3 V = normalize(CAMERA_POSITION_WORLD - wpos);
	float mirror = pow(max(dot(n, normalize(L + V)), 0.0), 120.0);
	float cone = smoothstep(cone_cos, cone_cos + 0.1, dot(-L, normalize(lamp_dir)));
	float reach = 1.0 - smoothstep(lamp_range * 0.45, lamp_range, dist);
	float tw = 0.55 + 0.45 * sin(TIME * (2.0 + r * 6.0) + r * 60.0);
	float s = speck * mirror * cone * reach * tw;
	if (s < 0.02) {
		discard;
	}
	ALBEDO = tint * s * strength * lamp_on * 4.0;
}
