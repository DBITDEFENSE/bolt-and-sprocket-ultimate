// T-280: the flash of a detonation: a white-hot core, an orange halo and a few short rays, camera-facing, additive.
// One material for every blast: `k` (1 at the instant -> 0) and `seed` are instance uniforms.
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled, fog_disabled;

instance uniform float k = 0.0;
instance uniform float seed = 0.0;

void vertex() {
	mat4 mat_world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat_world * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float rays = pow(abs(sin(ang * 3.0 + seed)), 24.0) + pow(abs(sin(ang * 5.0 + seed * 2.3)), 40.0) * 0.7;
	float core = exp(-r * r * 22.0);
	float halo = exp(-r * 3.2) * (1.0 - smoothstep(0.7, 1.0, r));
	float streak = rays * exp(-r * 2.6) * (1.0 - smoothstep(0.6, 1.0, r));
	vec3 c = vec3(1.0, 0.95, 0.85) * core * 6.0 + vec3(1.0, 0.55, 0.18) * (halo * 1.4 + streak * 1.6);
	ALBEDO = c * k * k;
	ALPHA = 1.0;
}
