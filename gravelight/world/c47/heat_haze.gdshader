shader_type spatial;
// UPDATE 12 section 5 (T-211): the heat haze over GRAVELIGHT ONE's fuel fire: a camera-facing card that bends what
// is behind it (the screen texture) with rising ripples, strongest low over the flames, fading at the card's edges.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled, fog_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 0.05) = 0.012;
uniform float speed = 1.6;

void vertex() {
	// a Y-axis billboard
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0), vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0), MODEL_MATRIX[3]);
}

void fragment() {
	float edge = smoothstep(0.0, 0.25, UV.x) * smoothstep(1.0, 0.75, UV.x) * smoothstep(0.0, 0.2, 1.0 - UV.y) * smoothstep(0.0, 0.15, UV.y);
	float low = UV.y;
	vec2 w = vec2(sin(UV.y * 31.0 + TIME * 5.3 * speed + UV.x * 7.0), cos(UV.x * 23.0 - TIME * 4.1 * speed + UV.y * 17.0));
	vec2 off = w * strength * edge * (0.4 + 0.6 * low);
	ALBEDO = textureLod(screen_tex, SCREEN_UV + off, 0.0).rgb;
	ALPHA = edge;
}
