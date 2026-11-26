// T-280: one puff of an explosion (the fireball, the smoke column, the thrown dirt, the dust skirt). Drawn on the
// particles of a GPUParticles3D; every blast shares this one material, and each emitter says through instance
// uniforms what its puffs are: `tint` (the smoke's or the ground's colour), `heat` (0 = dust that never glows,
// 1 = a fireball), `burn` (the share of a puff's life it spends as fire before it is smoke) and `size_k` (the
// blast's scale: the emitter's node scale spreads the particles but does not size them). The texture is a
// 2 x 2 atlas (gen_blast_textures.py): R the light from above, G heat, B fine noise, A density.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_disabled, diffuse_lambert_wrap, shadows_disabled;

uniform sampler2D puff_tex : hint_default_white, filter_linear_mipmap, repeat_disable;
instance uniform vec4 tint : source_color = vec4(0.13, 0.12, 0.11, 1.0);
instance uniform float heat = 0.0;
instance uniform float burn = 0.2;
instance uniform float size_k = 1.0;   // the blast's visual scale (a particle's size does not follow its emitter's scale)

varying float v_age;
varying float v_alpha;

void vertex() {
	VERTEX.xy *= size_k;
	// a camera-facing quad that keeps the particle's scale and spins by its angle (BILLBOARD_PARTICLES)
	mat4 mat_world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	float a = INSTANCE_CUSTOM.x;
	mat_world = mat_world * mat4(vec4(cos(a), -sin(a), 0.0, 0.0), vec4(sin(a), cos(a), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat_world;
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	float frame = clamp(floor(INSTANCE_CUSTOM.z * 4.0), 0.0, 3.0);
	UV = (UV + vec2(mod(frame, 2.0), floor(frame * 0.5))) * 0.5;
	v_age = INSTANCE_CUSTOM.y;
	v_alpha = COLOR.a;
}

void fragment() {
	vec4 t = texture(puff_tex, UV);
	float hot = heat * (1.0 - smoothstep(burn * 0.35, burn, v_age));          // 1 while fire -> 0 as smoke
	float h = clamp(t.g * (0.6 + 0.6 * hot) - (1.0 - hot) * 0.5, 0.0, 1.0) * hot;
	vec3 fire = mix(vec3(0.75, 0.16, 0.02), vec3(1.0, 0.55, 0.16), smoothstep(0.2, 0.75, h));
	fire = mix(fire, vec3(1.0, 0.82, 0.5), smoothstep(0.85, 1.0, h * hot));
	vec3 smoke = tint.rgb * (0.45 + 0.75 * t.r);
	ALBEDO = mix(smoke, vec3(0.05, 0.03, 0.02), hot * 0.6);                  // a burning puff is charred under its glow
	EMISSION = fire * h * (1.2 + 4.5 * hot);
	ALPHA = clamp(t.a * v_alpha * tint.a * (1.0 + 0.3 * hot), 0.0, 1.0);
}
