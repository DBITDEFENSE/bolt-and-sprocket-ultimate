shader_type spatial;
uniform vec4 liquid_color : source_color = vec4(0.08, 0.007, 0.005, 1.0);
varying vec3 local_pos;

void vertex() { local_pos = VERTEX; }

void fragment() {
	vec2 p = local_pos.xz / 0.052;
	float rings = sin(length(p - vec2(0.3, 0.2)) * 28.0 - TIME * 1.1);
	float ripple = rings * 0.015;
	NORMAL_MAP = vec3(0.5 + ripple, 0.5 + ripple * 0.3, 1.0);
	ALBEDO = liquid_color.rgb * (0.65 + 0.2 * rings);
	ROUGHNESS = 0.14;
	SPECULAR = 0.85;
	// Reflection of the nearby oil lantern in the otherwise unlit crypt.
	float glint = exp(-dot((p - vec2(-0.44, 0.3)) * vec2(6.0, 17.0), (p - vec2(-0.44, 0.3)) * vec2(6.0, 17.0)));
	EMISSION = vec3(0.32, 0.19, 0.065) * glint * (0.94 + 0.06 * sin(TIME * 8.0));
}
