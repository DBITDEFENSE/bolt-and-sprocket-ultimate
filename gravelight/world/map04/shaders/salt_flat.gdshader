// Groom Lake's dry lake bed (UPDATE 09 §5.4, T-148): white salt crust broken into polygons by raised ridges (the
// playa's shrinkage cracks), a beige undertone in the troughs, faint grit, a glint in the crust. World-space
// (the generator's batches carry no UVs), so it tiles seamlessly over every salt slab. `wear` darkens the crust
// The black salt (T-148): two scorch slots (xz centre, radius, z squash) burn the crust soot-black round the wreck
// and the impeller core's crater, ragged-edged, with the crack ridges still showing through the soot.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 crust : source_color = vec3(0.86, 0.84, 0.8);
uniform vec3 trough : source_color = vec3(0.66, 0.6, 0.52);
uniform vec3 ridge : source_color = vec3(0.95, 0.94, 0.92);
uniform float cell = 2.2;          // polygon size, metres
uniform float ridge_w = 0.09;
uniform float grit = 0.14;
uniform float tint_var = 0.08;
uniform vec4 scorch_a = vec4(0.0, -22.0, 44.0, 0.75);   // the wreck: x, z, radius, z scale (north edge pulled in)
uniform vec4 scorch_b = vec4(20.0, 19.0, 7.0, 1.0);     // the impeller core's crater
uniform vec3 soot : source_color = vec3(0.035, 0.032, 0.03);
uniform vec3 burnt : source_color = vec3(0.19, 0.15, 0.12);

varying vec3 wpos;

vec2 h22(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}
float h21(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 15731.743); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), u.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), u.x), u.y);
}

// distance to the nearest Voronoi edge (cell borders = the raised crack ridges)
float edge(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	vec2 mg = vec2(0.0);
	vec2 mr = vec2(0.0);
	float md = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = h22(n + g) * 0.85;
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < md) { md = d; mr = r; mg = g; }
		}
	}
	md = 8.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			vec2 g = mg + vec2(float(i), float(j));
			vec2 o = h22(n + g) * 0.85;
			vec2 r = g + o - f;
			if (dot(mr - r, mr - r) > 0.00001) {
				md = min(md, dot(0.5 * (mr + r), normalize(r - mr)));
			}
		}
	}
	return md;
}

float fbm3(vec2 p) {
	return vnoise(p) * 0.5 + vnoise(p * 2.03 + 7.1) * 0.3 + vnoise(p * 4.1 + 3.3) * 0.2;
}

// 1 = burnt black, 0 = clean crust
float scorch(vec4 sc, vec2 xz) {
	if (sc.z <= 0.0) {
		return 0.0;
	}
	vec2 rel = vec2(xz.x - sc.x, (xz.y - sc.y) / sc.w);
	float d = length(rel) / sc.z;
	float k = d + (fbm3(xz * 0.07) - 0.5) * 0.5;
	return 1.0 - smoothstep(0.5, 1.0, k);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz / cell;
	float e = edge(p);
	float r = 1.0 - smoothstep(0.0, ridge_w, e);            // 1 on a ridge
	float inner = smoothstep(ridge_w, ridge_w * 3.5, e);      // the polygon's flat
	float big = vnoise(wpos.xz * 0.035);
	float fine = vnoise(wpos.xz * 3.1) * 0.6 + vnoise(wpos.xz * 9.7) * 0.4;
	vec3 c = mix(trough, crust, inner * 0.85 + 0.15);
	c = mix(c, ridge, r);
	c *= 1.0 - tint_var + tint_var * 2.0 * big;
	c *= 1.0 - grit * (1.0 - fine);
	// far away the cracks would alias: settle into the crust's average tone (still varied at the large scale)
	float fd = smoothstep(45.0, 170.0, length(VERTEX));
	c = mix(c, mix(trough, crust, 0.82) * (1.0 - tint_var + tint_var * 2.0 * big), fd);
	r *= 1.0 - fd;
	float burn = max(scorch(scorch_a, wpos.xz), scorch(scorch_b, wpos.xz));
	float streak = fbm3(vec2(wpos.x * 0.3, wpos.z * 0.05));
	vec3 bc = mix(soot, burnt, smoothstep(0.35, 0.95, (1.0 - burn) + (streak - 0.5) * 0.4));
	c = mix(c, bc * (0.85 + 0.3 * r), burn);
	ALBEDO = c;
	ROUGHNESS = mix(0.95, 0.75, r);
	SPECULAR = 0.35;
	// the crack ridges stand up a little: tilt the normal across each ridge
	float dx = edge(p + vec2(0.02, 0.0)) - e;
	float dz = edge(p + vec2(0.0, 0.02)) - e;
	vec3 nw = normalize(vec3(-dx * r * 6.0, 1.0, -dz * r * 6.0));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
}
