shader_type spatial;
varying vec3 local_pos;

float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }

void vertex() {
	local_pos = VERTEX;
	float facets = sin(VERTEX.x * 8.0 + VERTEX.y * 3.0) * sin(VERTEX.z * 7.0 - VERTEX.y * 5.0);
	VERTEX += NORMAL * facets * 0.055;
}

void fragment() {
	vec3 p = local_pos * 7.0;
	vec3 cell = floor(p);
	float first = 10.0;
	float second = 10.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				vec3 c = cell + vec3(float(x), float(y), float(z));
				vec3 offset = vec3(hash(c), hash(c + 13.0), hash(c + 29.0));
				float d = length(c + offset - p);
				if (d < first) { second = first; first = d; }
				else { second = min(second, d); }
			}
		}
	}
	float vein = 1.0 - smoothstep(0.012, 0.055, second - first);
	float pulse = 0.7 + 0.3 * sin(TIME * 1.4 + local_pos.y * 3.0);
	ALBEDO = mix(vec3(0.018, 0.014, 0.025), vec3(0.12, 0.07, 0.18), first);
	ROUGHNESS = 0.27 + first * 0.2;
	METALLIC = 0.25;
	EMISSION = vec3(0.24, 0.09, 0.42) * vein * pulse;
}
