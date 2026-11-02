// A dust-storm sweep (UPDATE 09 §5.4, T-148): a tall card of blowing sand, scrolling noise in the wind direction,
// soft at every edge and near the camera, its opacity driven by `amount` (DustStormFx fades it in and out with the
// GroomController's special round). Visible in both renderers (the web profile has no volumetric fog).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 tint : source_color = vec3(0.78, 0.68, 0.52);
uniform float amount = 0.0;
uniform vec2 wind = vec2(0.35, 0.05);
uniform float near_fade = 6.0;

float h21(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 15731.743); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), u.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) { s += a * vnoise(p); p = p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
	return s;
}

void fragment() {
	vec2 uv = UV;
	float n = fbm(vec2(uv.x * 6.0, uv.y * 2.5) - TIME * wind * vec2(1.0, 0.4));
	float n2 = fbm(vec2(uv.x * 14.0, uv.y * 5.0) - TIME * wind * 2.3);
	float edge = smoothstep(0.0, 0.18, uv.x) * smoothstep(1.0, 0.82, uv.x) * smoothstep(0.0, 0.5, uv.y) * smoothstep(1.0, 0.92, uv.y);
	float near = smoothstep(0.5, near_fade, -VERTEX.z);
	ALBEDO = tint * (0.85 + 0.3 * n2);
	ALPHA = clamp(amount * edge * near * (0.35 + 0.65 * n) * (0.7 + 0.3 * n2), 0.0, 0.92);
}
