// GRAVELIGHT wonder weapons (T-090): glass (the Ashlight's chamber and capsule, the Sankt-Elmsfeuer's coil sleeve,
// gauge covers). Drawn last: it refracts what is behind it (the screen texture, so the Nachtglas fluid and the coil
// bend through it), darkens and tints at grazing angles, and keeps sharp lamp highlights. A little grime in the
// lower half and a frost rim on cold maps (the same `frost` WeaponShader sets).
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.82, 0.86, 0.84, 1.0);
uniform float refraction = 0.012;
uniform float frost = 0.0;
uniform float grime = 0.35;

varying vec3 v_local;

float h31(vec3 p) {
	p = fract(p * vec3(0.1031, 0.103, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	v_local = VERTEX;
}

void fragment() {
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 3.0);
	vec2 off = NORMAL.xy * refraction * (0.4 + fres);
	vec3 behind = textureLod(screen_tex, SCREEN_UV - off, 0.0).rgb;
	float dirt = grime * smoothstep(0.55, 1.0, h31(floor(v_local * 1800.0))) * 0.25;
	vec3 base = behind * tint.rgb * (1.0 - fres * 0.55) * (1.0 - dirt);
	float rime = frost * smoothstep(0.2, 0.8, h31(floor(v_local * 700.0))) * fres;
	ALBEDO = vec3(0.0);
	METALLIC = 0.0;
	ROUGHNESS = mix(0.03, 0.4, rime + dirt);
	SPECULAR = 0.9;
	EMISSION = base + vec3(0.75, 0.8, 0.85) * rime * 0.08;
	ALPHA = 1.0;
}
