shader_type spatial;
render_mode cull_disabled;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edge = length(p) + 0.12 * sin(p.y * 19.0 + sin(p.x * 13.0));
	if (edge > 0.93) { discard; }
	ALBEDO = vec3(0.065, 0.052, 0.035);
	ROUGHNESS = mix(0.23, 0.8, smoothstep(0.65, 0.94, edge));
	SPECULAR = 0.25;
	NORMAL_MAP = vec3(0.5 + sin(UV.y * 92.0) * 0.012, 0.5, 1.0);
}
