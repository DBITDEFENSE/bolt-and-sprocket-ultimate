// Ground fog that also reads in the Compatibility renderer (UPDATE 09 §5, T-146; the web build has no volumetric
// fog, contract C4): a horizontal sheet of drifting soft noise. Stack two or three at different heights. A sheet
// fades out when the eye is close to its plane (so it never shows as a line) and toward its edges.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(0.62, 0.66, 0.74, 0.16);
uniform float scale = 0.07;          // noise tiles per metre
uniform float drift = 0.25;          // m/s
uniform float edge = 0.2;            // fraction of the sheet that fades at each edge
uniform float near_fade = 0.6;       // eye height above/below the sheet where it is gone (m)

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz * scale;
	float t = TIME * drift * scale;
	float n = vnoise(p + vec2(t, t * 0.3)) * 0.6 + vnoise(p * 2.7 - vec2(t * 0.7, -t)) * 0.4;
	float e = smoothstep(0.0, edge, UV.x) * smoothstep(0.0, edge, 1.0 - UV.x) * smoothstep(0.0, edge, UV.y) * smoothstep(0.0, edge, 1.0 - UV.y);
	vec3 cam = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float nf = smoothstep(0.0, near_fade, abs(cam.y - wpos.y));
	ALBEDO = color.rgb;
	ALPHA = clamp(color.a * smoothstep(0.25, 0.85, n) * e * nf, 0.0, 1.0);
}
