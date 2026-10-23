// Minimap bake, pass 1 (Update 04 section 1, DECISIONS T-065): every level mesh is drawn top-down with this
// override and writes a small G-buffer instead of a lit colour:
//   R = height inside the slice band (0 = y_lo, 1 = y_hi = the cut),
//   G = class (0.333 floor-like top faces, 0.666 steep faces, 1.0 a back face = solid cut by the slice: a wall),
//   B = albedo luminance (the material's own texture, so boards / cobbles / snow read in the sketch),
//   A = 1 where anything is drawn.
// Values are pre-linearised so the 8-bit sRGB render target stores them as written.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled, fog_disabled;

uniform float y_lo = 0.0;
uniform float y_hi = 2.0;
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform bool triplanar = false;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);
uniform bool force_wall = false;   // section caps of walls cut by the slice

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 to_lin(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void fragment() {
	float h = clamp((wpos.y - y_lo) / max(0.01, y_hi - y_lo), 0.0, 1.0);
	vec3 tex = triplanar ? texture(albedo_tex, wpos.xz * uv_scale.xz + uv_offset.xz).rgb
		: texture(albedo_tex, UV * uv_scale.xy + uv_offset.xy).rgb;
	float l = clamp(dot(tex * albedo.rgb, vec3(0.299, 0.587, 0.114)), 0.0, 1.0);
	float cls = (force_wall || !FRONT_FACING) ? 1.0 : (wnorm.y > 0.55 ? 0.333 : 0.666);
	ALBEDO = to_lin(vec3(h, cls, l));
}
