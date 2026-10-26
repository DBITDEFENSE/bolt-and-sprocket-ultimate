// The scripted spruces, birches and bushes (UPDATE_05 section 5, T-093; meshes from tools_src/blender/nature/
// make_trees.py). One texture per material: a painted frond / twig card (alpha-scissored, seen from both sides) or a
// bark (opaque, alpha 1). Snow settles where the foliage normals point up (the meshes' normals lean up and out of
// the crown), the tips sway a little in the wind, and the far rings fade with the capped far fog like the old cone
// pines. The near rings and the map's own tree line use a copy without fog_disabled and fog_max = 0 (Landscape).
shader_type spatial;
render_mode diffuse_burley, specular_disabled, cull_disabled, fog_disabled;

#include "res://gravelight/world/landscape/shaders/far_fog.gdshaderinc"

uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform vec2 uv_mul = vec2(1.0, 1.0);
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.42;
uniform vec3 snow : source_color = vec3(0.70, 0.74, 0.82);
uniform float snow_amount : hint_range(0.0, 1.0) = 0.0;
uniform float wind : hint_range(0.0, 0.2) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.92;

varying vec3 wnrm;
varying float seed;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	seed = hash(origin.xz);
	// sway grows with height up the (unit-height) tree; nothing moves at the root
	float h = max(VERTEX.y, 0.0);
	float s = sin(TIME * (0.6 + seed * 0.3) + origin.x * 0.21 + origin.z * 0.17);
	VERTEX.x += s * wind * h * h;
	VERTEX.z += s * wind * h * h * 0.6;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec4 t = texture(tex, UV * uv_mul);
	vec3 c = t.rgb * tint * (0.88 + 0.24 * seed);
	float up = smoothstep(0.55, 0.95, wnrm.y);
	c = mix(c, snow * (0.9 + 0.1 * seed), up * snow_amount);
	float f = far_fog_amount(length(VERTEX));
	ALBEDO = c * (1.0 - f);
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = roughness;
	EMISSION = fog_color * f;
}
