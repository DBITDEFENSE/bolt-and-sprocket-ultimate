// Impostor cards for the far forests (T-052): one camera-facing (Y-axis) quad per tree in a MultiMesh, the spruce
// silhouette drawn procedurally from the UVs (tiers, ragged edges, a trunk), alpha-scissored, snow on the tiers,
// faded with the capped far fog. Instance scale: x = width, y = height.
shader_type spatial;
render_mode diffuse_burley, specular_disabled, fog_disabled, skip_vertex_transform, cull_disabled;

#include "res://gravelight/world/landscape/shaders/far_fog.gdshaderinc"

uniform vec3 needles : source_color = vec3(0.04, 0.06, 0.05);
uniform vec3 snow : source_color = vec3(0.36, 0.4, 0.48);

varying float seed;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	vec3 to_cam = CAMERA_POSITION_WORLD - origin;
	to_cam.y = 0.0;
	to_cam = normalize(to_cam + vec3(0.0001, 0.0, 0.0));
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), to_cam));
	vec3 world = origin + right * VERTEX.x * sx + vec3(0.0, 1.0, 0.0) * (VERTEX.y + 0.5) * sy;
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(to_cam + vec3(0.0, 0.6, 0.0)), 0.0)).xyz);
	seed = hash(origin.xz);
}

void fragment() {
	float y = 1.0 - UV.y;            // 0 at the foot, 1 at the tip
	float x = abs(UV.x - 0.5) * 2.0;  // 0 at the trunk, 1 at the card's edge
	float tiers = 5.0 + floor(seed * 3.0);
	float t = fract(y * tiers + seed * 0.37);
	float rag = hash(floor(vec2(UV.x * 40.0, y * 60.0)) + seed) * 0.12;
	float w = pow(max(1.0 - y, 0.0), 0.85) * (0.5 + 0.5 * (1.0 - t)) + rag - 0.06;
	float trunk = step(y, 0.12) * step(x, 0.07);
	float leaf = step(x, w) * step(0.06, y);
	if (max(trunk, leaf) < 0.5) {
		discard;
	}
	float snowy = smoothstep(0.55, 0.95, t) * step(x, w * 0.85) * leaf * (0.6 + 0.4 * seed);
	vec3 c = mix(needles * (0.8 + 0.4 * seed), snow, snowy);
	float f = far_fog_amount(length(VERTEX));
	ALBEDO = c * (1.0 - f);
	ROUGHNESS = 0.95;
	EMISSION = fog_color * f;
}
