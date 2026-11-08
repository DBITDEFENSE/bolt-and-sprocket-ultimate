shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// The impellers' exhaust (T-220, der Kranich's plane pass; our own): an open cone streaming aft of each nozzle that
// bends what is behind it (the screen, offset by a scrolling noise: heat shimmer), strongest at the nozzle and along
// the cone's middle, fading to nothing at its rim and its tail; at night a faint warm breath of glow in it (`night`).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 glow : source_color = vec4(1.0, 0.6, 0.32, 1.0);
uniform float strength = 0.008;
uniform float night : hint_range(0.0, 1.0) = 1.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	// UV.y runs along the cone (CylinderMesh: 0 at the top = the nozzle end), UV.x around it
	float along = UV.y;
	float edge = abs(dot(normalize(NORMAL), normalize(VIEW)));       // 1 face-on (the cone's middle), 0 at its rim
	float k = smoothstep(0.05, 0.6, edge) * (1.0 - smoothstep(0.25, 1.0, along)) * smoothstep(0.0, 0.05, along);
	vec2 q = vec2(UV.x * 9.0, along * 6.0 - TIME * 7.0);
	vec2 off = (vec2(vnoise(q), vnoise(q + 17.3)) - 0.5) * strength * k;
	vec3 bent = textureLod(screen_tex, SCREEN_UV + off, 0.0).rgb;
	ALBEDO = bent;
	ALPHA = clamp(k, 0.0, 1.0);
}
