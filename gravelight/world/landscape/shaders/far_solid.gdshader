// Distant buildings (the farmhouse, the church on the hill; T-052): a plain wall tone with snow on every
// upward face, lit, then faded with the capped far fog so they sit in the same haze as the hills.
shader_type spatial;
render_mode diffuse_burley, specular_disabled, fog_disabled;

#include "res://gravelight/world/landscape/shaders/far_fog.gdshaderinc"

uniform vec3 wall : source_color = vec3(0.2, 0.19, 0.18);
uniform vec3 snow : source_color = vec3(0.72, 0.76, 0.85);

varying vec3 wnrm;

void vertex() {
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = mix(wall, snow, smoothstep(0.3, 0.6, wnrm.y));
	float f = far_fog_amount(length(VERTEX));
	ALBEDO = c * (1.0 - f);
	ROUGHNESS = 0.9;
	EMISSION = fog_color * f;
}
