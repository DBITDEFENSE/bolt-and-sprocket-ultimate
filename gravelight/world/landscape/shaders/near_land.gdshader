// The near terrain around Map 0's snow slab (T-052; T-093 art pass). It samples the slab's own snow set (the CC0
// library's, handed over by Landscape._near_land_textures) with the same world-space top projection, so the seam
// at the slab edge disappears. The vertex-colour masks: r = the roads running on into the dark, where the snow is
// height-blended into the frozen-mud set (the snow's own brightness is its height, so mud shows in the hollows
// first) with two cart ruts; g = the frozen stream; b = the pines' needle litter. Uses the map's own fog.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_mud = false;
uniform float uv_scale = 0.12;
uniform float mud_uv_scale = 0.5;
uniform vec3 snow_tint : source_color = vec3(1.0);
uniform vec3 mud_tint : source_color = vec3(0.62, 0.6, 0.58);
uniform vec3 road_tint : source_color = vec3(0.6, 0.61, 0.66);
uniform vec3 ice : source_color = vec3(0.22, 0.29, 0.38);
uniform vec3 litter : source_color = vec3(0.16, 0.17, 0.16);
uniform float blend_soft : hint_range(0.01, 0.5) = 0.12;

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wpos.xz * uv_scale;
	vec3 snow = texture(albedo_tex, uv).rgb * snow_tint;
	vec3 nrm = texture(normal_tex, uv).rgb;
	vec3 c = snow;
	float rough = 0.7;
	// ruts: two darker lines along the road band's middle
	float rut = smoothstep(0.35, 0.0, abs(fract(COLOR.r * 3.0) - 0.5)) * step(0.6, COLOR.r);
	if (use_mud) {
		vec2 muv = wpos.xz * mud_uv_scale;
		vec3 mud = texture(mud_tex, muv).rgb * mud_tint;
		// height blend: the road mask plus the ruts against the snow's own brightness (bright = lying high)
		float snow_h = dot(snow, vec3(0.333)) + vnoise(wpos.xz * 0.7) * 0.25;
		float want = COLOR.r * 0.85 + rut * 0.5;
		float m = smoothstep(snow_h - blend_soft, snow_h + blend_soft, want * 1.25);
		c = mix(snow, mud * (0.85 + 0.25 * vnoise(wpos.xz * 1.3)), m);
		nrm = mix(nrm, texture(mud_normal_tex, muv).rgb, m);
		rough = mix(0.7, 0.85, m);
	} else {
		c = mix(c, c * road_tint * (0.9 + 0.2 * vnoise(wpos.xz * 1.7)) - rut * 0.04, COLOR.r);
	}
	// the stream: glazed ice with snow lying in its cracks
	float crack = smoothstep(0.08, 0.0, abs(vnoise(wpos.xz * 0.8) - 0.5));
	vec3 ice_c = mix(ice * (0.8 + 0.4 * vnoise(wpos.xz * 0.35)), c * 0.9, crack * 0.7 + vnoise(wpos.xz * 2.5) * 0.25);
	c = mix(c, ice_c, COLOR.g);
	c = mix(c, litter, COLOR.b * 0.45 * smoothstep(0.3, 0.8, vnoise(wpos.xz * 0.6)));
	ALBEDO = c;
	ROUGHNESS = mix(rough, 0.12, COLOR.g);
	SPECULAR = mix(0.5, 0.9, COLOR.g);
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = mix(1.0, 0.3, COLOR.g);
	vec3 t = (VIEW_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz;
	TANGENT = normalize(t - NORMAL * dot(NORMAL, t));
	BINORMAL = normalize(cross(NORMAL, TANGENT));
}
