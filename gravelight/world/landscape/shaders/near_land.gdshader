// The near terrain around Map 0's snow slab (T-052). It samples the slab's own "snow" textures (Mats) with the
// same world-space top projection, so the seam at the slab edge disappears, and adds the vertex-colour masks for
// the roads running on into the dark (r), the frozen stream (g) and the odd pine's needle litter (b).
// Uses the map's own fog, like everything else inside ~140 m.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float uv_scale = 0.12;
uniform vec3 road_tint : source_color = vec3(0.6, 0.61, 0.66);
uniform vec3 ice : source_color = vec3(0.22, 0.29, 0.38);
uniform vec3 litter : source_color = vec3(0.16, 0.17, 0.16);

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
	vec3 c = texture(albedo_tex, uv).rgb;
	// ruts: two darker lines along the road band
	float rut = smoothstep(0.35, 0.0, abs(fract(COLOR.r * 3.0) - 0.5)) * step(0.6, COLOR.r);
	c = mix(c, c * road_tint * (0.9 + 0.2 * vnoise(wpos.xz * 1.7)) - rut * 0.04, COLOR.r);
	// the stream: glazed ice with snow lying in its cracks
	float crack = smoothstep(0.08, 0.0, abs(vnoise(wpos.xz * 0.8) - 0.5));
	vec3 ice_c = mix(ice * (0.8 + 0.4 * vnoise(wpos.xz * 0.35)), c * 0.9, crack * 0.7 + vnoise(wpos.xz * 2.5) * 0.25);
	c = mix(c, ice_c, COLOR.g);
	c = mix(c, litter, COLOR.b * 0.45 * smoothstep(0.3, 0.8, vnoise(wpos.xz * 0.6)));
	ALBEDO = c;
	ROUGHNESS = mix(0.55, 0.12, COLOR.g);
	SPECULAR = mix(0.7, 0.9, COLOR.g);
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	NORMAL_MAP_DEPTH = mix(1.0, 0.3, COLOR.g);
	vec3 t = (VIEW_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz;
	TANGENT = normalize(t - NORMAL * dot(NORMAL, t));
	BINORMAL = normalize(cross(NORMAL, TANGENT));
}
