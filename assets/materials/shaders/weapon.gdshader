// GRAVELIGHT shared weapon shader (UPDATE_05 section 2, T-089). One shader for every downloaded gun so the two
// packs (Sketchfab PBR heroes, OpenGameArt flat-colour palette guns) read as one set: the PBR maps when a surface
// has them, and on top of them, in object space (triplanar, so the 8x8 palette guns get real surface detail):
//   wood     grain bands along the barrel axis, lighter polished high spots, flecks; camo tints the wood only;
//   metal    a cold bluing / parkerizing cast, edge wear (facet edges from the normal's screen derivative plus a
//            scratch mask) rubbing through to bright steel, fine scratches, a roughness mottle;
//   grime    low-frequency dirt that sits in the ambient-occlusion / cavity and on the lower faces;
//   frost    rime on the upward faces on cold maps (uniform `frost`, set per map by WeaponShader);
//   nachtglas the Crucible look (section 2.6): the same mesh darkened to deep violet glass with violet and amber
//            veins glowing through it.
// WeaponShader (gravelight/weapons/weapon_shader.gd) builds one ShaderMaterial per source surface and sets the
// uniforms; nothing here is per weapon except what model_fit.json "shader" asks for.
shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic;
uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform float has_normal = 0.0;
uniform float normal_depth = 1.0;
// glTF occlusion / roughness / metallic packed as R / G / B (Godot imports the same image into ao, roughness
// and metallic with those channels).
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic;
uniform float has_orm = 0.0;
uniform float metallic_f = 1.0;
uniform float roughness_f = 1.0;
// 1 = a palette gun: flat colours, so the shader decides wood vs metal by colour and adds every bit of detail.
uniform float palette = 0.0;
// -1 = classify wood by colour; otherwise a fixed share of wood for this surface.
uniform float wood_force = -1.0;
// mesh-local -> metres, and the gun's barrel / up axes in mesh-local space (grain runs along the barrel, frost
// and dust settle on the up faces).
uniform float detail_scale = 1.0;
uniform vec3 fwd_axis = vec3(0.0, 0.0, -1.0);
uniform vec3 up_axis = vec3(0.0, 1.0, 0.0);
uniform float wear = 0.5;
uniform float grime = 0.5;
uniform float scratches = 0.5;
uniform float frost = 0.0;
uniform float nachtglas = 0.0;
uniform vec3 bluing = vec3(0.86, 0.9, 1.0);
uniform vec4 camo_tint : source_color = vec4(1.0, 1.0, 1.0, 0.0);
// 1 = the camo is a whitewash (winter; WeaponShader sets it for a tint brighter than white), T-098
uniform float whitewash = 0.0;
uniform float camo_metal = 0.0;
uniform vec4 metal_tint : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float metal_metallic = -1.0;
uniform float metal_roughness = -1.0;
uniform float grain_scale = 1.0;
uniform float seed = 0.0;
uniform float debug = 0.0;

varying vec3 v_pos;
varying vec3 v_nrm;


float hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973) + seed);
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash3(i);
	float n100 = hash3(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash3(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash3(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash3(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash3(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash3(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash3(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y), mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float a = 0.5;
	float s = 0.0;
	for (int k = 0; k < 3; k++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec3(7.1, 3.3, 1.7);
		a *= 0.5;
	}
	return s;
}

void vertex() {
	v_pos = VERTEX * detail_scale;
	v_nrm = NORMAL;
}

void fragment() {
	vec4 alb = texture(albedo_tex, UV) * base_color;
	vec3 col = alb.rgb;
	vec3 orm = has_orm > 0.5 ? texture(orm_tex, UV).rgb : vec3(1.0, roughness_f, metallic_f);
	float ao = has_orm > 0.5 ? orm.r : 1.0;
	float rough = has_orm > 0.5 ? orm.g * roughness_f : roughness_f;
	float metal = has_orm > 0.5 ? orm.b * metallic_f : metallic_f;

	// ---- what is this pixel: wood or metal (palette guns and untagged PBR by colour)
	float mx = max(col.r, max(col.g, col.b));
	float mn = min(col.r, min(col.g, col.b));
	float sat = (mx - mn) / max(mx, 0.001);
	// wood is a warm red-brown (red well above green, green at or above blue); on a PBR surface it is also
	// non-metal by the ORM map, so rust and brass on the steel never take the wood look or the camo
	float warm = smoothstep(1.08, 1.25, col.r / max(col.g, 0.004)) * step(col.b * 0.85, col.g);
	float wood = wood_force >= 0.0 ? wood_force : smoothstep(0.2, 0.36, sat) * warm;
	if (has_orm > 0.5 && wood_force < 0.0) wood *= 1.0 - smoothstep(0.2, 0.5, orm.b);
	if (palette > 0.5) {
		metal = mix(0.82, 0.0, wood);
		rough = mix(0.46, 0.62, wood);
	}

	// ---- a frame along the gun: side / up / forward, in mesh-local metres
	vec3 f = normalize(fwd_axis);
	vec3 u = normalize(up_axis - f * dot(up_axis, f));
	vec3 s = cross(u, f);
	vec3 q = vec3(dot(v_pos, s), dot(v_pos, u), dot(v_pos, f));
	vec3 nl = normalize(v_nrm);
	float up_face = clamp(dot(nl, u), -1.0, 1.0);
	float n_big = fbm(q * 4.0);
	float n_mid = fbm(q * 18.0 + 11.0);
	float n_fine = fbm(q * 90.0 + 5.0);

	// ---- wood: grain bands stretched along the barrel, flecks, polished high spots
	float ring = fbm(vec3(q.x, q.y, q.z * 0.12) * 28.0 * grain_scale + 3.0);
	float band = 0.5 + 0.5 * sin(ring * 22.0 + q.z * 9.0);
	band = pow(band, 2.2);
	vec3 wood_col = col * mix(0.72, 1.14, band) * mix(0.9, 1.08, n_fine);
	wood_col *= mix(1.0, 1.18, smoothstep(0.55, 0.85, n_mid) * 0.5);
	float wood_rough = mix(0.68, 0.5, band) + (n_fine - 0.5) * 0.1;
	if (camo_tint.a > 0.0 && whitewash > 0.5) {
		// winter (a tint above 1): a field whitewash, not paint from a tin. Dirty off-white capped well below snow
		// (T-098: it read as a glowing white stock), streaked along the grain, thin and chipped so the wood shows
		// through on the worn patches; the grime pass below dirties it further.
		float thin = smoothstep(0.5, 0.78, n_mid * 0.6 + n_big * 0.4 + (1.0 - band) * 0.12);
		vec3 ws = vec3(0.3, 0.3, 0.28) * mix(0.8, 1.0, band) * mix(0.9, 1.04, n_fine);
		ws = mix(ws, wood_col * 1.15 + vec3(0.04, 0.035, 0.03), thin * 0.75);
		wood_col = mix(wood_col, min(ws, vec3(0.36)), camo_tint.a);
		wood_rough = mix(wood_rough, 0.86, camo_tint.a * (1.0 - thin * 0.6));
	} else if (camo_tint.a > 0.0) {
		// the camo colour carries the grain's light and dark
		float lum = dot(wood_col, vec3(0.3, 0.59, 0.11));
		vec3 tinted = min(camo_tint.rgb * (0.3 + 0.7 * clamp(lum / 0.22, 0.0, 1.4)), vec3(0.92));
		wood_col = mix(wood_col, tinted, camo_tint.a);
	}

	// ---- metal: bluing cast, edge wear to bright steel, scratches, roughness mottle
	// 2026-11-12 (the owner's screenshots: the M1911 and the MP40 "missing textures"): the palette guns are flat-shaded
	// low-poly meshes, so fwidth(NORMAL) is high along every triangle edge, not just the real ones; the edge wear lit
	// the whole gun in bright-steel facets and the mottle read as a broken texture. On a palette gun the facet term is
	// a faint hint and the scratches half as strong; the PBR guns (smooth normals) keep the full wear.
	float pal_k = palette > 0.5 ? 0.18 : 1.0;
	float edge = clamp(length(fwidth(NORMAL)) * 2.2, 0.0, 1.0) * pal_k;
	float scr = smoothstep(0.66, 0.72, fbm(vec3(q.x * 160.0, q.y * 160.0, q.z * 9.0) + 17.0));
	float scr2 = smoothstep(0.7, 0.75, fbm(vec3(q.x * 14.0, q.y * 220.0, q.z * 220.0) + 29.0));
	float patch = smoothstep(0.42, 0.72, n_mid * 0.7 + n_big * 0.3);
	float worn = clamp(edge * wear * 1.2 * (0.4 + patch) + (scr + scr2 * 0.5) * scratches * mix(0.3, 0.6, pal_k) + patch * wear * 0.05, 0.0, 1.0);
	vec3 metal_col = col * bluing;
	if (metal_tint.a > 0.0) {
		float lum_m = dot(metal_col, vec3(0.3, 0.59, 0.11));
		metal_col = mix(metal_col, metal_tint.rgb * (0.35 + lum_m * 1.3), metal_tint.a);
	}
	vec3 steel = vec3(0.58, 0.59, 0.61);
	metal_col = mix(metal_col, steel * mix(0.85, 1.05, n_fine), worn);
	float metal_m = max(metal, 0.75);
	if (metal_metallic >= 0.0) metal_m = metal_metallic;
	float metal_rough = rough * mix(0.85, 1.15, n_mid);
	if (metal_roughness >= 0.0) metal_rough = metal_roughness;
	metal_m = mix(metal_m, 0.95, worn);
	metal_rough = mix(metal_rough, 0.28, worn);
	if (camo_metal > 0.0) {
		wood_col = mix(wood_col, min(camo_tint.rgb * mix(0.8, 1.05, band), vec3(0.95)), camo_tint.a);
	}

	// ---- blend by material kind
	vec3 base = mix(metal_col, wood_col, wood);
	vec3 dbg7 = base;
	float m_out = mix(metal_m, camo_metal > 0.0 ? camo_metal : 0.0, wood);
	float r_out = mix(metal_rough, camo_metal > 0.0 ? 0.25 : wood_rough, wood);

	// ---- grime: dirt in the cavities and on the under faces, dust on the top faces
	float cav = 1.0 - ao;
	float dirt = grime * clamp(0.55 * (1.0 - n_big) + 0.45 * smoothstep(0.35, 0.8, n_mid) + cav * 0.8 + 0.25 * (-up_face), 0.0, 1.0) * 0.55;
	base = mix(base, base * vec3(0.4, 0.36, 0.3) + vec3(0.02, 0.018, 0.012), dirt);
	r_out = mix(r_out, 0.9, dirt * 0.7);
	m_out *= 1.0 - dirt * 0.5;
	vec3 dbg8 = base;

	// ---- frost on the up faces (cold maps)
	float rime = frost * smoothstep(0.05, 0.75, up_face) * smoothstep(0.32, 0.7, n_mid * 0.55 + n_fine * 0.45 + n_big * 0.15);
	base = mix(base, vec3(0.84, 0.9, 0.98), rime);
	r_out = mix(r_out, 0.88, rime);
	m_out *= 1.0 - rime;

	// ---- Nachtglas (the Crucible version): dark violet glass, veins of violet and amber light
	vec3 emis = vec3(0.0);
	if (nachtglas > 0.0) {
		float v1 = 1.0 - abs(2.0 * fbm(q * 38.0 + 41.0) - 1.0);
		float v2 = 1.0 - abs(2.0 * fbm(q * 52.0 + 97.0) - 1.0);
		float vein = smoothstep(0.9, 0.97, v1);
		float amber = smoothstep(0.94, 0.99, v2);
		vec3 glass = base * vec3(0.3, 0.16, 0.45) + vec3(0.035, 0.012, 0.07);
		base = mix(base, glass, nachtglas * 0.85);
		r_out = mix(r_out, 0.16, nachtglas);
		m_out = mix(m_out, 0.45, nachtglas);
		emis = nachtglas * (vein * vec3(0.55, 0.2, 1.0) * 2.6 + amber * vec3(1.0, 0.55, 0.15) * 2.4);
	}

	bool plain_normal = false;
	if (debug > 9.5 && debug < 11.5) {
		// 10: the final albedo with a flat dielectric; 11: the same without the procedural bump
		m_out = 0.0;
		r_out = 1.0;
		plain_normal = true;
	} else if (debug > 0.5) {
		base = alb.rgb;
		if (debug > 1.5) base = vec3(wood);
		if (debug > 2.5) base = vec3(worn);
		if (debug > 3.5) base = vec3(dirt);
		if (debug > 4.5) base = vec3(rime);
		if (debug > 5.5) base = vec3(edge);
		if (debug > 6.5) base = dbg7;
		if (debug > 7.5) base = dbg8;
		if (debug > 8.5) base = vec3(m_out, r_out, 0.0);
		if (debug > 11.5) base = vec3(n_fine, n_mid, n_big);
		if (debug > 12.5) base = vec3(band, ring, 0.0);
		if (debug > 13.5) base = nl * 0.5 + 0.5;
		if (debug > 14.5) base = vec3(isnan(dot(q, q)) ? 1.0 : 0.0, isnan(dot(nl, nl)) ? 1.0 : 0.0, isnan(wood_col.r) ? 1.0 : 0.0);
		if (debug > 15.5) base = q * 2.0 + 0.5;
		if (debug > 16.5) base = fract(VERTEX * 4.0);
		if (debug > 17.5) base = fract((inverse(MODEL_MATRIX) * (INV_VIEW_MATRIX * vec4(VERTEX, 1.0))).xyz * 4.0);
		m_out = 0.0;
		r_out = 1.0;
		emis = vec3(0.0);
	}
	ALBEDO = base;
	METALLIC = clamp(m_out, 0.0, 1.0);
	ROUGHNESS = clamp(r_out, 0.04, 1.0);
	AO = ao;
	AO_LIGHT_AFFECT = 0.6;
	EMISSION = emis;
	// normal: a procedural bump (grain on wood, pitting on metal) perturbed in object space, so it needs no
	// tangents (the palette meshes' per-face UVs are degenerate and their generated tangents are garbage), then
	// the pack's normal map on top where there is one
	vec3 t_obj = normalize(cross(nl, abs(dot(nl, u)) < 0.9 ? u : s));
	vec3 b_obj = cross(nl, t_obj);
	vec3 tq = vec3(dot(t_obj, s), dot(t_obj, u), dot(t_obj, f));
	vec3 bq = vec3(dot(b_obj, s), dot(b_obj, u), dot(b_obj, f));
	float e = 0.0025;
	float bump_k = mix(0.9, 1.6, wood) * (palette > 0.5 ? 0.55 : 0.45) * (1.0 - rime);   // (palette 1.0 until 2026-11-12: the pitting read as noise)
	float h0 = fbm(q * 70.0 + 2.0);
	float ht = fbm((q + e * tq) * 70.0 + 2.0);
	float hb = fbm((q + e * bq) * 70.0 + 2.0);
	vec3 n_obj = normalize(nl - (t_obj * (ht - h0) + b_obj * (hb - h0)) * (bump_k * 0.0035 / e));
	if (plain_normal) n_obj = nl;
	NORMAL = normalize(mat3(VIEW_MATRIX) * (MODEL_NORMAL_MATRIX * n_obj));
	if (has_normal > 0.5) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_depth;
	}
}
