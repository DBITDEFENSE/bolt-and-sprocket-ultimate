// GRAVELIGHT wonder weapons (T-090): the Nachtglas fluid in the Ashlight's capsule.
// A closed cylinder of fluid, cut by a plane: everything above the surface is discarded, and the inside back faces
// that show through the cut are drawn flat as the meniscus, so the fluid reads as a liquid with a level.
//   level   0..1, the charge (WonderLook drives it from the magazine fraction, smoothed);
//   surf_n  the surface's up in mesh space (gravity plus the gun's own motion, through a spring: it sloshes);
//   wobble  ripple amplitude (the spring's speed), flash 0..1 on a shot, energy the brightness (Corona: brighter).
// It glows violet (Nachtglas emission, ART_BIBLE section 2) with a slow swirl and rising specks; the glass around
// it (wonder_glass.gdshader) refracts it.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform vec3 center = vec3(0.0);
uniform float radius = 0.01;
uniform vec4 deep : source_color = vec4(0.10, 0.02, 0.20, 1.0);
uniform vec4 glow : source_color = vec4(0.55, 0.20, 1.00, 1.0);
// instance uniforms in the same order in every wonder shader (one instance can mix them: indices must agree)
instance uniform float energy = 1.0;
instance uniform float flash = 0.0;
instance uniform float level = 1.0;
instance uniform vec3 surf_n = vec3(0.0, 1.0, 0.0);
instance uniform float wobble = 0.0;

varying vec3 v_local;

float h31(vec3 p) {
	p = fract(p * vec3(0.1031, 0.103, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float vn(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h31(i), h31(i + vec3(1, 0, 0)), f.x), mix(h31(i + vec3(0, 1, 0)), h31(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h31(i + vec3(0, 0, 1)), h31(i + vec3(1, 0, 1)), f.x), mix(h31(i + vec3(0, 1, 1)), h31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	v_local = VERTEX;
}

void fragment() {
	vec3 n = normalize(surf_n);
	vec3 rel = v_local - center;
	float h = dot(rel, n);
	float ripple = (sin(rel.z * 520.0 + TIME * 13.0) + sin(rel.x * 410.0 - TIME * 9.0) * 0.6) * wobble * radius * 0.18;
	float lvl = mix(-radius * 1.02, radius * 1.02, clamp(level, 0.0, 1.0));
	if (level <= 0.002 || h > lvl + ripple) {
		discard;
	}
	float swirl = vn(v_local * 260.0 + vec3(0.0, TIME * 0.35, TIME * 0.6));
	float swirl2 = vn(v_local * 90.0 - vec3(TIME * 0.2, 0.0, TIME * 0.25));
	// specks rising toward the surface
	vec3 sp = v_local * 900.0 - n * TIME * 6.0;
	float speck = step(0.985, h31(floor(sp))) * smoothstep(0.6, 0.0, length(fract(sp) - 0.5));
	float e = energy * (0.9 + 0.8 * swirl * swirl2 + 3.0 * flash);
	if (!FRONT_FACING) {
		// the meniscus: the cut seen from above, flat and bright at the rim
		NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(n, 0.0)).xyz);
		ALBEDO = deep.rgb;
		ROUGHNESS = 0.06;
		EMISSION = glow.rgb * e * 1.4 + vec3(speck) * 0.6;
	} else {
		float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
		ALBEDO = deep.rgb;
		ROUGHNESS = 0.08;
		SPECULAR = 0.7;
		EMISSION = glow.rgb * e * (0.75 + fres * 1.2) + vec3(0.9, 0.7, 1.0) * speck * energy;
	}
}
