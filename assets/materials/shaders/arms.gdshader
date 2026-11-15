// The first-person arms' surface (2026-11-12, the owner: the hands read as "plain untextured shapes"). Arms
// (gravelight/weapons/arms.gd) swaps each surface of a survivor's arms GLB for this, keeping its colour, roughness
// and metal, and lays real detail over it in object space (triplanar, the node's scale taken out so a stretched
// sleeve keeps its weave): the ambientCG fabric on sleeves, cuffs and wool or work gloves, the ambientCG leather on
// leather gloves, palms and straps, a fine pore grain on bare skin, a faint grain on brass.
shader_type spatial;
render_mode cull_back;

uniform vec4 base_color : source_color = vec4(1.0);
uniform float roughness = 0.8;
uniform float metallic = 0.0;
// 0 fabric, 1 leather, 2 skin, 3 metal
uniform int kind = 0;
uniform sampler2D detail_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_orm : filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
// repeats per metre, the detail texture's mean luminance (so the colour stays the character's), its weights
uniform float detail_scale = 9.0;
uniform float detail_mean = 0.5;
uniform float albedo_amount = 0.6;
uniform float normal_strength = 0.6;
uniform float orm_amount = 0.5;

// the gore rework: blood on the hands and sleeves after a kill at arm's length (GoreFx.hands sets it, 0..1; it wears off)
global uniform float gl_hand_blood;

varying vec3 v_p;
varying vec3 v_n;

float blood_hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

// value noise in object space (the arms have no shared UV layout)
float blood_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(blood_hash(i), blood_hash(i + vec3(1, 0, 0)), f.x), mix(blood_hash(i + vec3(0, 1, 0)), blood_hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(blood_hash(i + vec3(0, 0, 1)), blood_hash(i + vec3(1, 0, 1)), f.x), mix(blood_hash(i + vec3(0, 1, 1)), blood_hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	vec3 s = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	v_p = VERTEX * s;
	v_n = NORMAL;
}

vec3 unpack_n(vec4 t, float k) {
	vec2 xy = (t.xy * 2.0 - 1.0) * k;
	return vec3(xy, sqrt(clamp(1.0 - dot(xy, xy), 0.0, 1.0)));
}

void fragment() {
	vec3 n = normalize(v_n);
	vec3 w = pow(abs(n), vec3(4.0));
	w /= max(w.x + w.y + w.z, 1e-5);
	float sc = detail_scale;
	vec2 uvx = v_p.zy * sc;
	vec2 uvy = v_p.xz * sc;
	vec2 uvz = v_p.xy * sc;
	vec3 alb = texture(detail_albedo, uvx).rgb * w.x + texture(detail_albedo, uvy).rgb * w.y + texture(detail_albedo, uvz).rgb * w.z;
	vec3 orm = texture(detail_orm, uvx).rgb * w.x + texture(detail_orm, uvy).rgb * w.y + texture(detail_orm, uvz).rgb * w.z;
	float lum = dot(alb, vec3(0.333)) / max(detail_mean, 0.05);
	vec3 col = base_color.rgb * clamp(mix(1.0, lum, albedo_amount), 0.45, 1.6);
	float r = mix(roughness, clamp(orm.g, 0.3, 1.0), orm_amount);
	if (kind == 2) {
		// skin: the detail is only a grain; a little warmth in the creases
		col = base_color.rgb * mix(0.94, 1.04, lum * 0.5);
		r = roughness;
	}
	if (gl_hand_blood > 0.001) {
		float bn = blood_noise(v_p * 34.0) * 0.65 + blood_noise(v_p * 90.0) * 0.35;
		float edge = 1.0 - 0.5 * gl_hand_blood;                  // at most about half the surface
		float bm = smoothstep(edge, edge + 0.1, bn);
		col = mix(col, vec3(0.035, 0.002, 0.003), bm * 0.85);    // dark, not a red glove
		r = mix(r, 0.3, bm);
	}
	ALBEDO = col;
	ROUGHNESS = r;
	METALLIC = metallic;
	AO = mix(1.0, orm.r, orm_amount * (kind == 2 ? 0.0 : 1.0));
	AO_LIGHT_AFFECT = 0.4;
	// whiteout-blended triplanar normal in object space
	vec3 tx = unpack_n(texture(detail_normal, uvx), normal_strength);
	vec3 ty = unpack_n(texture(detail_normal, uvy), normal_strength);
	vec3 tz = unpack_n(texture(detail_normal, uvz), normal_strength);
	vec3 nx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
	vec3 ny = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
	vec3 nz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
	vec3 n_obj = normalize(nx.zyx * w.x + ny.xzy * w.y + nz.xyz * w.z);
	NORMAL = normalize(mat3(VIEW_MATRIX) * (MODEL_NORMAL_MATRIX * n_obj));
}
