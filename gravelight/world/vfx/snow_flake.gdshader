// Snow flake billboard for GPUParticles3D draw passes (T-100). Like StandardMaterial3D's BILLBOARD_PARTICLES, plus
// two guards against the "white blur near the camera" (a flake drifting through the near plane filled a chunk of the
// screen as a soft white disc):
//   - distance fade: a flake is invisible inside `fade_near` metres of the camera and fully drawn past `fade_far`;
//   - on-screen size cap: a flake is never wider than `max_angle` radians as seen from the camera (its world size
//     shrinks as it nears), so no flake reads as a blob at any distance or resolution.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D flake_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(0.88, 0.9, 0.96, 0.8);
uniform float fade_near = 1.0;
uniform float fade_far = 2.5;
uniform float max_angle = 0.012;
uniform float quad_size = 0.085;

varying float v_fade;

void vertex() {
	vec3 centre_view = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	float d = length(centre_view);
	float s = length(MODEL_MATRIX[0].xyz);
	// world width of this flake = quad_size * s; cap it at max_angle * d
	float cap = max_angle * d / max(quad_size, 0.0001);
	float k = min(s, cap);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(k, 0.0, 0.0, 0.0), vec4(0.0, k, 0.0, 0.0), vec4(0.0, 0.0, k, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	v_fade = smoothstep(fade_near, fade_far, d);
}

void fragment() {
	vec4 t = texture(flake_tex, UV);
	ALBEDO = tint.rgb * t.rgb;
	ALPHA = tint.a * t.a * v_fade;
}
