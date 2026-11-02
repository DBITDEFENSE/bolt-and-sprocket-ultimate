// The mountains round Groom Lake (UPDATE 09 §5.4, T-148): two ridge rings beyond the berm, lit by the low sun,
// darker toward their feet, then faded with a capped haze of their own toward the horizon colour (fog_disabled)
// so they read as layered silhouettes against the blue hour, in Forward+ and in the web profile alike.
shader_type spatial;
render_mode diffuse_burley, specular_disabled, fog_disabled;

uniform vec3 rock : source_color = vec3(0.32, 0.27, 0.27);
uniform vec3 foot : source_color = vec3(0.2, 0.18, 0.2);
uniform vec3 haze : source_color = vec3(0.5, 0.56, 0.7);
uniform float haze_max = 0.7;
uniform float haze_k = 0.006;
uniform float top_y = 40.0;

varying vec3 wpos;

float h21(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 15731.743); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), u.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = vnoise(wpos.xz * 0.05 + wpos.y * 0.08) * 0.6 + vnoise(wpos.xz * 0.21) * 0.4;
	vec3 c = mix(foot, rock, smoothstep(0.0, top_y, wpos.y)) * (0.8 + 0.4 * n);
	float f = clamp(haze_max * (1.0 - exp(-haze_k * length(VERTEX))), 0.0, 0.95);
	ALBEDO = c * (1.0 - f);
	EMISSION = haze * f;
	ROUGHNESS = 1.0;
}
