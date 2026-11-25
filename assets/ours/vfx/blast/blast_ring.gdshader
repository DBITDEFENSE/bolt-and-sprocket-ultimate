// T-280: the blast wave on the ground: a ring of dust racing out from a ground burst and fading, with a short bright
// rim at its birth. A flat quad; one material for every blast: `k` (0 at the instant -> 1 gone) and `tint` (the
// ground's dust) are instance uniforms.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

instance uniform float k = 1.0;
instance uniform vec4 tint : source_color = vec4(0.5, 0.45, 0.4, 1.0);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float front = mix(0.12, 0.96, sqrt(k));
	float w = 0.06 + 0.3 * k;
	float band = smoothstep(front - w, front, r) * (1.0 - smoothstep(front, front + 0.03, r));
	float a = atan(p.y, p.x);
	float rag = 0.75 + 0.25 * sin(a * 11.0 + r * 9.0) * sin(a * 7.0 - 1.3);
	float fade = 1.0 - k;
	vec3 hot = vec3(1.0, 0.7, 0.4) * (1.0 - smoothstep(0.0, 0.18, k));
	ALBEDO = tint.rgb + hot;
	ALPHA = clamp(band * rag * fade * fade * tint.a, 0.0, 1.0);
}
