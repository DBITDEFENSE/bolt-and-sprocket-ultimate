shader_type spatial;
// Trench-bottom water: dark, silty, broken by rain ripples so it never reads as a flat grey sheet of sky.
varying vec3 world_pos;
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = world_pos.xz;
	float ripple = sin(p.x * 31.0 + p.y * 19.0 - TIME * 3.0);
	float cross_ripple = sin(p.x * 13.0 - p.y * 37.0 + TIME * 2.1);
	float slow = sin(p.x * 2.3 + p.y * 5.1 + TIME * 0.4) * 0.5 + 0.5;   // patches of scum dull the reflection
	NORMAL_MAP = vec3(0.5 + ripple * 0.09, 0.5 + cross_ripple * 0.075, 1.0);
	ALBEDO = mix(vec3(0.05, 0.034, 0.018), vec3(0.085, 0.062, 0.035), slow);
	ROUGHNESS = mix(0.3, 0.62, slow) + 0.05 * ripple;
	SPECULAR = mix(0.16, 0.06, slow);
}
