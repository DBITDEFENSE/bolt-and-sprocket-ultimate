shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;
// Catwalk grating (UPDATE 09 section 5.3, DECISIONS T-147; our own): bearing bars every `bar_pitch` along U, cross
// rods every `rod_pitch` along V, the gaps discarded so the sub-floor, the beams (and over the bay's breach the
// night and the sea) show through. Far away, where a pixel covers several bars, it stops discarding and draws the
// average instead (no moire). UVs in metres (the shell's floors, gen_map04b's dressing quads).

uniform vec4 bar_color : source_color = vec4(0.22, 0.23, 0.21, 1.0);
uniform float bar_pitch = 0.034;
uniform float bar_width = 0.006;
uniform float rod_pitch = 0.1;
uniform float rod_width = 0.008;
uniform float rough = 0.55;
uniform float metal = 0.6;

void fragment() {
	vec2 uv = UV;
	float aa = max(fwidth(uv.x), fwidth(uv.y));
	float bu = abs(fract(uv.x / bar_pitch) - 0.5) * bar_pitch;
	float rv = abs(fract(uv.y / rod_pitch) - 0.5) * rod_pitch;
	float bar = 1.0 - smoothstep(bar_width * 0.5 - aa * 0.5, bar_width * 0.5 + aa * 0.5, bar_pitch * 0.5 - bu);
	float rod = 1.0 - smoothstep(rod_width * 0.5 - aa * 0.5, rod_width * 0.5 + aa * 0.5, rod_pitch * 0.5 - rv);
	float solid = max(bar, rod);
	float far = smoothstep(bar_pitch * 0.35, bar_pitch * 0.9, aa);
	if (solid < 0.5 && far < 0.5) {
		discard;
	}
	float wear = 0.85 + 0.15 * fract(sin(dot(floor(uv / vec2(bar_pitch, rod_pitch)), vec2(12.9898, 78.233))) * 43758.5453);
	ALBEDO = bar_color.rgb * wear * mix(1.0, 0.75, far);
	ROUGHNESS = rough;
	METALLIC = metal;
}
