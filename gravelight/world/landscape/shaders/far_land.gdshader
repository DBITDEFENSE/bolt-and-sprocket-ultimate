// The mid hills and the ridge bands beyond Map 0 (T-052): snow, wind-scoured rock, forest floor, the road's
// trodden band and the frozen stream, all from vertex-colour masks and value noise (no textures). Lit by the
// moon and the war's flash light, then faded with the capped far fog (far_fog.gdshaderinc).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, fog_disabled;

#include "res://gravelight/world/landscape/shaders/far_fog.gdshaderinc"

uniform vec3 snow_lo : source_color = vec3(0.50, 0.55, 0.66);
uniform vec3 snow_hi : source_color = vec3(0.80, 0.84, 0.92);
uniform vec3 rock : source_color = vec3(0.16, 0.16, 0.18);
uniform vec3 wood_floor : source_color = vec3(0.10, 0.11, 0.10);
uniform vec3 road : source_color = vec3(0.34, 0.35, 0.39);
uniform vec3 ice : source_color = vec3(0.26, 0.33, 0.42);
uniform float ridge = 0.0;          // 1 = a ridge band: COLOR.r is snow cover, COLOR.b wooded
uniform float noise_scale = 0.05;
// T-093: the library's boulder albedo breaks up the rock faces and the ridges' scree (sampled in world space, big)
uniform sampler2D rock_tex : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float rock_tex_scale = 0.045;

varying vec3 wpos;
varying vec3 wnrm;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) { s += a * vnoise(p); p *= 2.07; a *= 0.5; }
	return s;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float n = fbm(wpos.xz * noise_scale);
	float fine = vnoise(wpos.xz * 0.9);
	vec3 snow = mix(snow_lo, snow_hi, clamp(n * 1.2 - 0.1 + fine * 0.15, 0.0, 1.0));
	float steep = 1.0 - smoothstep(0.55, 0.85, wnrm.y);
	vec3 rt = texture(rock_tex, vec2(wpos.x + wpos.z, wpos.y * 1.6) * rock_tex_scale).rgb;
	vec3 rock_c = rock * (0.55 + 0.9 * dot(rt, vec3(0.333)));
	vec3 c;
	if (ridge > 0.5) {
		// ridges: snowfields high up, scoured rock on the steep faces, dark woods on the nearer band
		float cover = clamp(COLOR.r + (n - 0.5) * 0.5, 0.0, 1.0);
		c = mix(rock_c * (0.7 + 0.6 * n), snow * 0.62, smoothstep(0.35, 0.6, cover) * (1.0 - steep * 0.8));
		c = mix(c, wood_floor * (0.8 + 0.4 * n), COLOR.b * smoothstep(0.3, 0.7, fbm(wpos.xz * 0.11 + 3.0)) * 0.75);
	} else {
		c = mix(snow, rock_c, steep * 0.5);
		c = mix(c, wood_floor, COLOR.b * 0.65);
		c = mix(c, road * (0.8 + 0.4 * fine), COLOR.r * 0.85);
		c = mix(c, ice * (0.85 + 0.3 * n), COLOR.g);
	}
	float f = far_fog_amount(length(VERTEX));
	ALBEDO = c * (1.0 - f);
	ROUGHNESS = mix(0.75, 0.25, COLOR.g * (1.0 - ridge));
	SPECULAR = 0.25 * (1.0 - f);
	EMISSION = fog_color * f;
}
