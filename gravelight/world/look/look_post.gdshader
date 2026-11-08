shader_type canvas_item;
render_mode unshaded;
// UPDATE 12 section 2 (DECISIONS T-208): the one post pass every map, the menu and the in-engine cutscenes share.
// A full-screen ColorRect on a CanvasLayer under the HUD reads the screen once and draws: the edge-only lens softness
// and chromatic aberration (extra taps only past 60% of the half-diagonal; the centre is one tap), the oval vignette,
// the luma-weighted monochrome film grain and the projector flicker (menu / reels). The tonemap, the per-map grade and
// the fog are the Environment's (LookGrade). Numbers: docs/ART_BIBLE.md section 5, data/look/<map>.json `post`.
// `legacy` is the pre-U12 PostFx film look (vignette + cold shadow lift), kept for a map with no grade and for the
// `--look=off` "before" frames. Works on Forward+ and Compatibility / WebGL 2 (no mipmaps, no compute).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float grain = 0.0;
uniform float vignette = 0.42;
uniform float edge_soft = 0.0;
uniform float ca = 0.0;
uniform float flicker = 0.0;
uniform float legacy = 1.0;
uniform vec3 shadow_tint = vec3(0.86, 0.92, 1.08);
uniform float frame = 0.0;   // the grain's frame counter (LookPost advances it; the TIME-free form keeps captures repeatable)

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 q = uv * 2.0 - 1.0;                       // -1..1, the corners at |q| = sqrt(2)
	float r = length(q) * 0.70710678;              // 0 centre .. 1 the corners (the half-diagonal)
	float e = smoothstep(0.6, 1.0, r);             // the edge band: zero inside 60% of the half-diagonal
	vec3 c;
	if (e > 0.001 && (edge_soft > 0.0 || ca > 0.0)) {
		vec2 px = SCREEN_PIXEL_SIZE;
		float rad = edge_soft * e * 7.0;           // px: 0.2 -> 1.4 px at the corner, 0.4 -> 2.8 px
		vec2 o1 = vec2(rad, rad * 0.5) * px;
		vec2 o2 = vec2(-rad * 0.5, rad) * px;
		c = texture(screen_tex, uv).rgb * 0.2;
		c += texture(screen_tex, uv + o1).rgb * 0.2;
		c += texture(screen_tex, uv - o1).rgb * 0.2;
		c += texture(screen_tex, uv + o2).rgb * 0.2;
		c += texture(screen_tex, uv - o2).rgb * 0.2;
		if (ca > 0.0) {
			vec2 off = normalize(q + vec2(1e-5)) * ca * e * vec2(1.0, px.y / max(px.x, 1e-6));   // radial, same px both axes
			c.r = mix(c.r, texture(screen_tex, uv + off).r, 0.85);
			c.b = mix(c.b, texture(screen_tex, uv - off).b, 0.85);
		}
	} else {
		c = texture(screen_tex, uv).rgb;
	}
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	if (legacy > 0.0) {
		c = mix(c, mix(c * shadow_tint, c, smoothstep(0.0, 0.35, lum)), legacy);
	}
	// the oval vignette (1.15 : 1), from 55% of the half-diagonal
	vec2 vq = q * vec2(1.0, 1.15);
	float rv = length(vq) / length(vec2(1.0, 1.15));
	float vlegacy = smoothstep(0.85, 0.25, length((uv - 0.5) * vec2(1.15, 1.0)));   // the old PostFx falloff
	float v = mix(1.0 - smoothstep(0.55, 1.0, rv), vlegacy, legacy);
	c *= mix(1.0 - vignette, 1.0, v);
	// monochrome grain, strongest in the shadows (luma-weighted), a new pattern every frame
	if (grain > 0.0) {
		vec2 fp = floor(FRAGCOORD.xy) + vec2(mod(frame * 37.0, 1021.0), mod(frame * 61.0, 977.0));
		float n = hash12(fp) + hash12(fp + 17.31) - 1.0;   // triangular -1..1
		c += vec3(n * grain * mix(0.9, 0.35, clamp(lum, 0.0, 1.0)));
	}
	if (flicker > 0.0) {
		float f = hash12(vec2(floor(frame / 3.0), 7.0)) * 2.0 - 1.0;
		c *= 1.0 + flicker * f;
	}
	COLOR = vec4(max(c, vec3(0.0)), 1.0);
}
