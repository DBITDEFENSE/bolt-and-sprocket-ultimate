// Minimap bake, pass 2 (Update 04 section 1, DECISIONS T-065): turns the G-buffer of map_encode.gdshader into the
// floor image, in one of three styles:
//   0 ink (GRAVELIGHT): a field sketch, ink on paper, paper grain, pencil shading from the materials and
//     cross-hatched walls, matching the ledger-stamp HUD;
//   1 holo (Bolt & Sprocket): a clean glass panel, cyan edges, orange walls, a faint scan line;
//   2 blueprint (Fine Print / Helvetia Works): white technical lines on Prussian blue with a metre grid.
// Empty space stays transparent (the map canvas draws the paper and the ghosted floors under it). mask_tex limits
// the floor to its XZ rects (white = keep).
shader_type canvas_item;
render_mode blend_disabled;   // the image stores straight (not premultiplied) alpha

uniform sampler2D gbuf : filter_nearest;
uniform sampler2D mask_tex : filter_linear, hint_default_white;
uniform vec2 texel = vec2(0.001);
uniform int style = 0;
uniform vec4 paper : source_color = vec4(0.91, 0.87, 0.78, 1.0);
uniform vec4 paper_dark : source_color = vec4(0.8, 0.73, 0.6, 1.0);
uniform vec4 ink : source_color = vec4(0.16, 0.13, 0.09, 1.0);
uniform vec4 wall_col : source_color = vec4(0.23, 0.18, 0.13, 1.0);
uniform vec4 accent : source_color = vec4(0.62, 0.1, 0.09, 1.0);
uniform vec4 world_rect = vec4(0.0, 0.0, 100.0, 100.0);
uniform float hscale = 3.0;       // metres per unit of the height channel (cut - y_lo)
uniform float ppm = 6.0;          // pixels per metre
uniform float seed = 0.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21) + seed);
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += vnoise(p) * a;
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

bool is_wall(vec4 g) { return g.a > 0.5 && g.g > 0.85; }
bool has(vec4 g) { return g.a > 0.5; }

void fragment() {
	vec2 uv = UV;
	vec4 g = texture(gbuf, uv);
	vec2 px = uv / texel;
	vec2 wp = world_rect.xy + uv * world_rect.zw;   // world x, z
	// neighbourhood (1 px and 2 px)
	vec4 n[8];
	n[0] = texture(gbuf, uv + vec2(-texel.x, 0.0));
	n[1] = texture(gbuf, uv + vec2(texel.x, 0.0));
	n[2] = texture(gbuf, uv + vec2(0.0, -texel.y));
	n[3] = texture(gbuf, uv + vec2(0.0, texel.y));
	n[4] = texture(gbuf, uv + vec2(-texel.x, -texel.y));
	n[5] = texture(gbuf, uv + vec2(texel.x, texel.y));
	n[6] = texture(gbuf, uv + vec2(texel.x, -texel.y));
	n[7] = texture(gbuf, uv + vec2(-texel.x, texel.y));
	bool me = has(g);
	bool wall = is_wall(g);
	float wall_edge = 0.0;
	float h_edge = 0.0;
	float c_edge = 0.0;
	float near_wall = 0.0;
	for (int i = 0; i < 8; i++) {
		bool nw = is_wall(n[i]);
		bool nh = has(n[i]);
		if (me && nh && nw != wall) { wall_edge = 1.0; }
		if (nw) { near_wall = 1.0; }
		if (me != nh) { c_edge = 1.0; }
		if (me && nh && !wall && !nw) {
			float dh = abs(n[i].r - g.r) * hscale;
			h_edge = max(h_edge, smoothstep(0.12, 0.35, dh));
		}
	}
	float mask = texture(mask_tex, uv).r;
	bool empty = !me && c_edge < 0.5;
	float lum = g.b;
	float h = g.r;
	vec4 col = vec4(0.0);
	if (style == 0) {
		// ---- ink on paper
		float grain = fbm(px * 0.35) * 0.6 + vnoise(px * 1.7) * 0.4;
		vec3 base = mix(paper_dark.rgb, paper.rgb, 0.78 + 0.22 * grain);
		// pencil shading: darker materials get diagonal pencil strokes (world-anchored, ~0.45 m apart)
		float tone = clamp((0.62 - lum) * 1.25, 0.0, 1.0) + (1.0 - h) * 0.12;
		float stroke = abs(fract((wp.x - wp.y) * 2.2 + vnoise(wp * 0.7) * 0.6) - 0.5);
		float pencil = smoothstep(0.5 - tone * 0.32, 0.5 - tone * 0.32 - 0.05, 0.5 - stroke) * tone;
		base = mix(base, ink.rgb * 1.6, pencil * 0.32);
		if (g.g > 0.5 && g.g < 0.85) { base = mix(base, paper_dark.rgb, 0.45); }   // steep faces: a darker wash
		if (wall) {
			// walls: dark ink with cross-hatching
			float hx = step(mod(px.x + px.y, 3.0), 1.1);
			float hy = step(mod(px.x - px.y + 300.0, 3.0), 1.1);
			base = mix(wall_col.rgb * 1.35, ink.rgb, max(hx, hy) * 0.85);
		}
		float line = max(max(wall_edge, c_edge), h_edge * 0.8);
		float wobble = 0.82 + 0.18 * vnoise(px * 0.9);
		base = mix(base, ink.rgb, clamp(line * wobble, 0.0, 1.0));
		col = vec4(base, me ? 1.0 : 0.85 * c_edge);
	} else if (style == 1) {
		// ---- holo panel
		float scan = 0.92 + 0.08 * step(0.5, fract(px.y * 0.25));
		vec3 base = paper.rgb * (0.8 + 0.4 * lum) * scan;
		float a = 0.78;
		if (g.g > 0.5 && g.g < 0.85) { base = mix(base, ink.rgb * 0.35, 0.35); }
		if (wall) {
			base = wall_col.rgb * (0.75 + 0.25 * step(0.5, fract((px.x + px.y) * 0.2)));
			a = 0.95;
		}
		float line = max(wall_edge * 0.8, max(c_edge, h_edge));
		base = mix(base, ink.rgb, clamp(line, 0.0, 1.0));
		col = vec4(base, me ? a : c_edge);
	} else {
		// ---- Swiss blueprint
		vec2 gm = abs(fract(wp) - 0.5);
		float grid = step(0.5 - 0.6 / ppm, max(gm.x, gm.y));
		vec2 g5 = abs(fract(wp / 5.0) - 0.5);
		float grid5 = step(0.5 - 0.6 / (ppm * 5.0), max(g5.x, g5.y));
		vec3 base = mix(paper.rgb, paper_dark.rgb, (1.0 - lum) * 0.35);
		base = mix(base, ink.rgb, grid * 0.12 + grid5 * 0.18);
		if (wall) {
			float hx = step(mod(px.x + px.y, 4.0), 1.0);
			base = mix(paper.rgb, wall_col.rgb, 0.35 + hx * 0.55);
		}
		float line = max(max(wall_edge, c_edge), h_edge * 0.85);
		base = mix(base, ink.rgb, clamp(line, 0.0, 1.0));
		col = vec4(base, me ? 1.0 : c_edge);
	}
	col.a *= mask;
	COLOR = empty ? vec4(0.0) : col;
}
