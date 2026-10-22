// A soft additive shaft of light on a cone or box (T-052): the searchlights sweeping the clouds, and the moonlight
// leaking through the stable's board gaps. The sides fade across UV.x and the faces fade with the
// view angle so the volume never shows its silhouette; it also fades out near the camera. The mesh runs along
// its local Y, the source at -Y (instance uniform beam_len = the mesh's length).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform vec3 color : source_color = vec3(0.8, 0.85, 0.95);
uniform float intensity = 0.25;
uniform float length_falloff = 1.6;   // brightness ~ (1 - v)^falloff along the shaft
uniform float edge_power = 1.6;
uniform float near_fade = 2.0;        // metres from the camera where the shaft is invisible
uniform float flow = 0.0;             // >0: drifting dust in the shaft
instance uniform float beam_len = 1.0;

varying float along;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	along = clamp(VERTEX.y / beam_len + 0.5, 0.0, 1.0);
}

void fragment() {
	float a = pow(1.0 - along, length_falloff) * smoothstep(0.0, 0.04, along);
	float edge = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), edge_power);
	float nf = smoothstep(near_fade * 0.4, near_fade, length(VERTEX)) * smoothstep(0.0, 0.3, min(UV.x, 1.0 - UV.x));
	float dust = 1.0;
	if (flow > 0.0) {
		dust = 0.65 + 0.7 * vnoise(vec2(UV.x * 9.0, along * 14.0 - TIME * flow));
	}
	ALBEDO = color * intensity * a * edge * nf * dust;
}
