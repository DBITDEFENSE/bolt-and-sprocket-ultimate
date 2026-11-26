// T-280: what a near blast does to the eye: a short warm flash over the whole view and a radial blur pulled
// toward the blast for a few tenths of a second. Only drawn while one is on (BlastScreen hides it otherwise).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float flash = 0.0;
uniform float blur = 0.0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform vec3 tint : source_color = vec3(1.0, 0.82, 0.6);

void fragment() {
	vec2 d = SCREEN_UV - centre;
	vec3 c = vec3(0.0);
	for (int i = 0; i < 6; i++) {
		c += textureLod(screen_tex, SCREEN_UV - d * blur * 0.06 * float(i) / 5.0, 0.0).rgb;
	}
	c /= 6.0;
	c = mix(c, c + tint, flash);
	COLOR = vec4(c, 1.0);
}
