// The Earth's atmosphere seen edge-on (U09 s5, T-149): a shell a little larger than the globe, additive, bright at
// the limb and brighter on the sunlit side, so the planet has a thin blue halo against the black.
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, fog_disabled;

uniform vec3 sun_dir = vec3(0.8, 0.35, 0.45);
uniform vec4 halo : source_color = vec4(0.3, 0.55, 1.0, 1.0);
uniform float gain = 1.1;

varying vec3 obj_n;

void vertex() {
	obj_n = normalize(VERTEX);
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float limb = pow(1.0 - facing, 3.0) * smoothstep(0.0, 0.25, facing);
	float day = smoothstep(-0.35, 0.4, dot(normalize(obj_n), normalize(sun_dir)));
	ALBEDO = halo.rgb * limb * gain * (0.12 + 0.88 * day);
}
