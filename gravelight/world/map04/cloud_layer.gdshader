shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
// One cloud sheet under der Kranich (UPDATE 09 section 5.3, DECISIONS T-147; our own). A quad that follows the
// camera (FlightSky moves it) with the pattern in world space plus `scroll`, so the sheet flows aft at its own speed
// while the quad stays under the viewer. Moonlit tops, dark bellies, ragged edges from a few octaves of value noise,
// alpha fading out toward the quad's rim and the horizon (the far plane never shows an edge), flashes from flak.

uniform vec2 scroll = vec2(0.0);
uniform float scale = 420.0;            // metres per noise unit
uniform float coverage : hint_range(0.0, 1.0) = 0.55;
uniform float opacity : hint_range(0.0, 1.0) = 0.8;
uniform float softness : hint_range(0.01, 1.0) = 0.22;
uniform vec4 lit_color : source_color = vec4(0.55, 0.6, 0.74, 1.0);
uniform vec4 dark_color : source_color = vec4(0.09, 0.11, 0.16, 1.0);
uniform vec4 violet_color : source_color = vec4(0.45, 0.18, 0.6, 1.0);
uniform float violet : hint_range(0.0, 1.0) = 0.0;
uniform vec3 center = vec3(0.0);        // the camera (xz) for the rim fade
uniform float radius = 380.0;
uniform float flash = 0.0;
uniform vec3 flash_pos = vec3(0.0, -1000.0, 0.0);
uniform vec4 flash_color : source_color = vec4(1.0, 0.75, 0.45, 1.0);

varying vec3 wpos;

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = (wpos.xz + scroll) / scale;
	float n = fbm(p);
	float detail = fbm(p * 3.7 + vec2(3.0, 7.0));
	float density = smoothstep(1.0 - coverage - softness, 1.0 - coverage + softness, n * 0.8 + detail * 0.3);
	float rim = 1.0 - smoothstep(radius * 0.55, radius, length(wpos.xz - center.xz));
	float a = density * opacity * rim;
	if (a < 0.003) {
		discard;
	}
	// tops lit by the moon, thicker parts darker underneath; a violet cast to the east after London
	vec3 col = mix(dark_color.rgb, lit_color.rgb, clamp(detail * 1.3 - density * 0.35 + 0.2, 0.0, 1.0));
	col = mix(col, col + violet_color.rgb * 0.5, violet * clamp((wpos.x - center.x) / radius * 0.5 + 0.5, 0.0, 1.0));
	float fl = flash * exp(-length(wpos - flash_pos) / 60.0);
	col += flash_color.rgb * fl * density;
	ALBEDO = col;
	ALPHA = a;
}
