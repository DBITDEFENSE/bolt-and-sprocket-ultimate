// Heat distortion over the wreck's fires (UPDATE 09 §5.4, T-148): a camera-facing card that refracts the screen
// behind it with rising noise, strongest in the middle and fading to nothing at the edges and the top. Uses the
// screen texture, which both renderers (Forward+ and Compatibility) provide.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.012;
uniform float speed = 1.4;
uniform float scale = 7.0;

float h21(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 15731.743); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), u.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	// billboard round the vertical axis
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], MODEL_MATRIX[1], vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, MODEL_MATRIX[1].xyz)), 0.0), MODEL_MATRIX[3]);
}

void fragment() {
	vec2 uv = UV;
	float edge = smoothstep(0.0, 0.3, uv.x) * smoothstep(1.0, 0.7, uv.x) * smoothstep(0.0, 0.25, 1.0 - uv.y) * smoothstep(1.0, 0.75, 1.0 - uv.y);
	vec2 q = vec2(uv.x * scale, uv.y * scale * 1.6 + TIME * speed);
	vec2 off = vec2(vnoise(q) - 0.5, vnoise(q + vec2(13.1, 7.3)) - 0.5) * strength * edge;
	ALBEDO = textureLod(screen_tex, SCREEN_UV + off, 0.0).rgb;
	ALPHA = edge;
}
