shader_type spatial;
render_mode cull_disabled;
uniform float breath = 0.0;
uniform vec4 linen : source_color = vec4(0.65, 0.65, 0.58, 1.0);
varying vec3 cloth_position;

void vertex() {
	float x = (VERTEX.x + 0.27) / 0.36;
	float z = VERTEX.z / 0.26;
	float rise = breath * exp(-x * x * 2.0 - z * z * 2.0);
	VERTEX.y += rise;
	NORMAL = normalize(NORMAL + vec3(rise * 4.0 * x / 0.36, 0.0, rise * 4.0 * z / 0.26));
	cloth_position = VERTEX;
}

void fragment() {
	float weave = sin(cloth_position.x * 1600.0) * sin(cloth_position.z * 1500.0);
	float wear = sin(cloth_position.x * 31.0 + sin(cloth_position.z * 17.0)) * 0.018;
	ALBEDO = linen.rgb * (0.98 + weave * 0.025 + wear);
	ROUGHNESS = 0.94;
	SPECULAR = 0.18;
}
