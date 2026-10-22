// Snow-laden spruce for the MultiMesh forests (T-052). The mesh is code-built (trunk + stacked cones, vertex colour
// r = foliage). Needles go near-black green; snow settles on upward-facing tiers. The near strays use a copy of
// this shader without fog_disabled and fog_max = 0 (the map's own fog then applies); the forest on the mid hills
// uses the capped far fog.
shader_type spatial;
render_mode diffuse_burley, specular_disabled, fog_disabled;

#include "res://gravelight/world/landscape/shaders/far_fog.gdshaderinc"

uniform vec3 needles : source_color = vec3(0.045, 0.07, 0.055);
uniform vec3 bark : source_color = vec3(0.08, 0.06, 0.05);
uniform vec3 snow : source_color = vec3(0.42, 0.46, 0.55);

varying vec3 wnrm;
varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float seed = hash(floor(wpos.xz * 1.7) + floor(wpos.y * 3.1));
	float up = smoothstep(0.15, 0.6, wnrm.y);
	vec3 c = mix(bark, needles * (0.75 + 0.5 * seed), COLOR.r);
	c = mix(c, snow * (0.85 + 0.15 * seed), up * COLOR.r * smoothstep(0.45, 0.9, seed + up * 0.3) * 0.8);
	float f = far_fog_amount(length(VERTEX));
	ALBEDO = c * (1.0 - f);
	ROUGHNESS = 0.9;
	EMISSION = fog_color * f;
}
