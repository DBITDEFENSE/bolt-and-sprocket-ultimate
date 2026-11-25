class_name DetailMap02
extends RefCounted
## Totenhafen's detail pieces (UPDATE 09 section 5, DECISIONS T-145): static builders gen_map02.gd calls to dress the
## seven zones. Pure functions of their arguments: each adds visual nodes under `parent` (no colliders; the generator
## keeps every collider it had) and returns what it made where useful. Primitive parts go through Props (so
## gen_map02.merge_static_meshes batches them); the curved hulls are lofted ArrayMeshes (SurfaceTool), one
## MeshInstance3D per material, built here instead of in Blender: the shapes are parametric (a Type VII section that
## keeps U-1047's 6 m gameplay deck, a clinker cutter) and stay in the generator, with no GLB to import.
## Frame as gen_map02: +X east, +Z south, y up; yaw in degrees, a group's local -Z faces "front" unless noted.

const DRIP_SHADER: String = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(0.55, 0.62, 0.7, 0.55);
void fragment() {
	float d = abs(UV.x - 0.5) * 2.0;
	ALBEDO = tint.rgb;
	ALPHA = tint.a * (1.0 - d) * smoothstep(0.0, 0.3, UV.y) * COLOR.a;
}
"""

const STORM_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform float flash = 0.0;
uniform vec3 sky_top : source_color = vec3(0.02, 0.025, 0.04);
uniform vec3 sky_low : source_color = vec3(0.07, 0.085, 0.11);
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float a = 0.5; float s = 0.0; for (int k = 0; k < 5; k++) { s += a * vn(p); p *= 2.03; a *= 0.5; } return s; }
void fragment() {
	vec2 uv = UV * vec2(6.0, 2.5) + vec2(TIME * 0.035, TIME * 0.01);
	float c = fbm(uv) * 0.75 + 0.25 * fbm(uv * 3.1 - vec2(TIME * 0.08, 0.0));
	vec3 col = mix(sky_low, sky_top, UV.y);
	col *= 0.6 + 0.8 * c;
	col += flash * vec3(0.55, 0.6, 0.75) * (0.35 + c);
	ALBEDO = col;
}
"""

static var _drip_mat: ShaderMaterial = null


# ================================================================== lofting

## A strip surface through `lines` (one PackedVector3Array per section, all the same length, sections in order):
## quads between consecutive sections, normals then smoothed. Returns an ArrayMesh.
## T-282: every quad is wound the same way from the order the strip is built in, so neighbours always agree; the
## strip as a whole is then turned once so its front faces away from `axis_c(p)` (the hull's centre line at that
## point), by an area-weighted vote over all its triangles. A per-triangle guess flipped single faces where the hint
## is poor (at the keel, on the shoulder), and the old test had Godot's rule backwards (the front face is the one
## whose normal is (c - a) x (b - a), clockwise seen from the front): every hull was drawn inside out, so from
## outside you saw through the near side to the inner face of the far one, and into whatever stood inside.
## A strip with walls facing both ways (the tower's outer and inner skin) is built as one strip in one order: the
## bigger outward area wins the vote and the inner skin faces in.
static func strip(lines: Array, axis_c: Callable, flat: bool = false) -> ArrayMesh:
	var tris: PackedVector3Array = []
	var vote: float = 0.0
	for s: int in lines.size() - 1:
		var a: PackedVector3Array = lines[s]
		var b: PackedVector3Array = lines[s + 1]
		for i: int in a.size() - 1:
			for t: Array in [[a[i], a[i + 1], b[i + 1]], [a[i], b[i + 1], b[i]]]:
				var p0: Vector3 = t[0]
				var p1: Vector3 = t[1]
				var p2: Vector3 = t[2]
				var n: Vector3 = front_normal(p0, p1, p2)
				if n.length_squared() < 1e-10:
					continue
				var c: Vector3 = (p0 + p1 + p2) / 3.0
				vote += n.dot((c - (axis_c.call(c) as Vector3)).normalized())
				tris.append_array([p0, p1, p2])
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if not flat:
		st.set_smooth_group(0)
	for k: int in range(0, tris.size(), 3):
		st.add_vertex(tris[k])
		st.add_vertex(tris[k + 1] if vote >= 0.0 else tris[k + 2])
		st.add_vertex(tris[k + 2] if vote >= 0.0 else tris[k + 1])
	st.generate_normals()
	return st.commit()


## The normal of the face Godot draws for the triangle (p0, p1, p2) (its front: clockwise seen from that side), not
## normalized (its length is twice the area).
static func front_normal(p0: Vector3, p1: Vector3, p2: Vector3) -> Vector3:
	return (p2 - p0).cross(p1 - p0)


## One triangle turned so its front faces away from `axis_c` (for small flat pieces where the hint is unambiguous,
## like a transom; a curved surface goes through strip()).
static func _tri(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, axis_c: Callable) -> void:
	var n: Vector3 = front_normal(p0, p1, p2)
	if n.length_squared() < 1e-10:
		return
	var c: Vector3 = (p0 + p1 + p2) / 3.0
	var out: Vector3 = c - (axis_c.call(c) as Vector3)
	if n.dot(out) < 0.0:
		st.add_vertex(p0)
		st.add_vertex(p2)
		st.add_vertex(p1)
	else:
		st.add_vertex(p0)
		st.add_vertex(p1)
		st.add_vertex(p2)


## The cap across a symmetric section: `side` runs down one side of the section (x >= 0, top to bottom), its mirror
## in x is the other side; quads pair each point with its mirror, so a y-monotone section closes with trapezoids
## whatever its shape (a fan from a fixed centre spilled past a section whose keel rose above it, and left the top
## edge open). The front faces `out`.
static func section_cap(side: PackedVector3Array, out: Vector3, flat: bool = true) -> ArrayMesh:
	var lines: Array = []
	for p: Vector3 in side:
		lines.append(PackedVector3Array([Vector3(-p.x, p.y, p.z), p]))
	return strip(lines, func(p: Vector3) -> Vector3: return p - out, flat)


## A mesh instance for a lofted surface under `parent` with the material key (library or procedural, via Mats).
static func surface(parent: Node3D, n: String, mesh: ArrayMesh, key: String, shadow: bool = true) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = n
	mi.mesh = mesh
	mi.material_override = Mats.get_mat(key)
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## T-282: marks a surface that only adds faces over a shape already there (the inside of the cutter's planks, the
## tower's lip, inner skin, floor and base), so gen_map02's fitted colliders (T-180, built from the art) leave it out
## and stay as they were. A generation-time mark: gen_map02 clears it before saving.
static func no_fit(mi: MeshInstance3D) -> MeshInstance3D:
	mi.set_meta("t282_no_fit", true)
	return mi


# ================================================================== U-1047, a Type VII

## Half-section of the boat at u (0 bow .. 1 stern), as points from the deck edge down to the keel on the starboard
## side (x >= 0), in boat space (deck at y 0). `m` points: 4 on the shoulder (deck edge -> widest point at the saddle
## tanks), the rest on the bilge (widest -> keel). Midships the beam over the saddle tanks is 6.8 m (a VIIC's 6.2 m
## widened to clear U-1047's 6 m gameplay deck) and the keel 6.4 m below the deck (draught ~4.7 m below the water).
static func vii_half(u: float, m: int = 12, enclose: float = 0.0) -> PackedVector3Array:
	var hd: float = 3.0 if u < 0.83 else lerpf(3.0, 0.5, (u - 0.83) / 0.17)          # deck half width
	var mid: float = smoothstep(0.0, 0.16, u) * (1.0 - smoothstep(0.62, 1.0, u))
	var hb: float = lerpf(1.3 if u < 0.5 else 0.35, 3.4, mid)                        # half beam at the tanks
	var yb: float = lerpf(-1.6, -2.6, mid)                                            # height of the widest point
	var yk: float = lerpf(-3.2 if u < 0.5 else -2.0, -6.4, smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.75, 1.0, u)))
	# T-180: where the boat's gameplay interior (a 6 m x 3.5 m box under the deck) runs, the hull must hold it: the
	# narrowing bow and stern let the box's plating poke out, and the hall saw into the hidden compartments there
	if enclose > 0.0:
		hb = lerpf(hb, maxf(hb, 3.15), enclose)
		yb = lerpf(yb, minf(yb, -3.65), enclose)
		yk = lerpf(yk, minf(yk, -4.6), enclose)
	var out: PackedVector3Array = []
	var k_sh: int = 4
	for i: int in k_sh:
		var t: float = float(i) / float(k_sh)
		var a: float = t * PI * 0.5
		out.append(Vector3(hd + (hb - hd) * sin(a), yb * (1.0 - cos(a)), 0.0))
	var k_bl: int = m - k_sh
	for j: int in k_bl:
		var t2: float = float(j) / float(k_bl - 1)
		var a2: float = t2 * PI * 0.5
		out.append(Vector3(hb * cos(a2), yb + (yk - yb) * sin(a2), 0.0))
	return out


## U-1047's hull, tower, deck gun, planes, rudders and screws under `g` (a group at the bow end of the deck: local +Z
## runs aft, y 0 is the deck top). length: deck bow to stern tip (m). Waterline split (boot-top) at local y `boot`.
## Keys: hull plating, red lead below the boot-top, deck slats, fittings.
static func type_vii(g: Node3D, length: float, boot: float, k_hull: String = "m2_hull", k_red: String = "m2_hull_red",
		k_fit: String = "iron", hold_to: float = -1.0) -> void:
	var secs: int = 34
	var m: int = 12
	var split: int = 7   # the boot-top: points 0..split are topsides, split..m-1 the red bottom
	var up_r: Array = []
	var up_l: Array = []
	var lo: Array = []
	var deck: Array = []
	for s: int in secs + 1:
		var u: float = float(s) / float(secs)
		u = u * u * (3.0 - 2.0 * u) * 0.35 + u * 0.65   # more sections at the bow and stern, where it curves
		var z: float = u * length
		var half: PackedVector3Array = vii_half(u, m, _hold(z, hold_to))
		var r: PackedVector3Array = []
		var l: PackedVector3Array = []
		for i: int in split + 1:
			r.append(Vector3(half[i].x, half[i].y - 0.02, z))
			l.append(Vector3(-half[i].x, half[i].y - 0.02, z))
		up_r.append(r)
		up_l.append(l)
		var b: PackedVector3Array = []
		for i2: int in range(split, m):
			b.append(Vector3(half[i2].x, half[i2].y - 0.02, z))
		for i3: int in range(m - 2, split - 1, -1):
			b.append(Vector3(-half[i3].x, half[i3].y - 0.02, z))
		lo.append(b)
		deck.append(PackedVector3Array([Vector3(-half[0].x, -0.02, z), Vector3(half[0].x, -0.02, z)]))
	var axis: Callable = func(p: Vector3) -> Vector3: return Vector3(0.0, minf(p.y, -2.0) if absf(p.x) < 0.3 else -2.0, p.z)
	surface(g, "HullTop_R", strip(up_r, axis), k_hull)
	surface(g, "HullTop_L", strip(up_l, axis), k_hull)
	surface(g, "HullBottom", strip(lo, axis), k_red)
	var deck_up: Callable = func(p: Vector3) -> Vector3: return p - Vector3.UP
	surface(g, "DeckCasing", strip(deck, deck_up, true), k_hull)
	# bow and stern ends: the end section closed from the deck edge to the keel (the casing's bluff bow, the stern
	# tip). T-282: was a fan from a fixed point (0, -2.4) that missed the deck edge's span (a triangular hole under
	# the casing at each end) and hung below the stern's keel (-2.0)
	# (the topsides in the hull's colour, below the boot-top in red lead, like the sides)
	for end: int in [0, secs]:
		var lo_end: PackedVector3Array = lo[end]
		var outd: Vector3 = Vector3(0, 0, -1) if end == 0 else Vector3(0, 0, 1)
		var nm: String = "HullEnd_Bow" if end == 0 else "HullEnd_Stern"
		surface(g, nm, section_cap(up_r[end], outd), k_hull)
		surface(g, nm + "_Red", section_cap(lo_end.slice(0, m - split), outd), k_red)   # the starboard half of the bottom
	# the boot-top line and a rubbing strake at the tanks
	var bt: Array = []
	for s2: int in secs + 1:
		var u2: float = float(s2) / float(secs)
		u2 = u2 * u2 * (3.0 - 2.0 * u2) * 0.35 + u2 * 0.65
		var h2: PackedVector3Array = vii_half(u2, m, _hold(u2 * length, hold_to))
		bt.append(PackedVector3Array([Vector3(h2[split].x + 0.03, h2[split].y + 0.12, u2 * length), Vector3(h2[split].x + 0.03, h2[split].y - 0.02, u2 * length)]))
	surface(g, "BootTop_R", strip(bt, func(p: Vector3) -> Vector3: return Vector3(0, p.y, p.z), true), "black_paint", false)
	var bt_l: Array = []
	for line: PackedVector3Array in bt:
		bt_l.append(PackedVector3Array([Vector3(-line[0].x, line[0].y, line[0].z), Vector3(-line[1].x, line[1].y, line[1].z)]))
	surface(g, "BootTop_L", strip(bt_l, func(p: Vector3) -> Vector3: return Vector3(0, p.y, p.z), true), "black_paint", false)
	# free-flooding slots along the casing sides under the deck edge
	for k: int in 30:
		var z2: float = 4.0 + k * 1.45
		if z2 > length * 0.8:
			break
		for sx: float in [-1.0, 1.0]:
			Props.block(g, Vector3(sx * 3.02 - 0.012, -0.55, z2), Vector3(sx * 3.02 + 0.012, -0.32, z2 + 0.7), "black_paint", false)
	# bow planes (folded up against the casing) and the stern: planes, rudder, twin screws on their shafts
	for sx2: float in [-1.0, 1.0]:
		Props.obox(g, Vector3(sx2 * 1.9, -3.0, 3.0), Vector3(1.4, 0.08, 1.2), k_hull, Vector3(0, 0, sx2 * 30.0))
		Props.obox(g, Vector3(sx2 * 1.4, -2.4, length - 3.2), Vector3(2.0, 0.08, 1.4), k_hull)
		var shaft: Vector3 = Vector3(sx2 * 1.05, -2.6, length - 4.2)
		Props.cyl(g, shaft, 0.1, 2.6, "brass", Vector3(90, 0, 0))
		for a: float in [0.0, 120.0, 240.0]:
			Props.obox(g, shaft + Vector3(0, 0, 0.9), Vector3(0.22, 1.5, 0.05), "brass", Vector3(0, 0, a + sx2 * 20.0))
		Props.cyl(g, shaft + Vector3(0, 0, 0.9), 0.16, 0.3, "brass", Vector3(90, 0, 0))
	Props.obox(g, Vector3(0, -2.6, length - 1.6), Vector3(0.12, 2.2, 1.6), k_hull)
	# deck slats over the casing (the gameplay deck's own visual is the HullDeck boxes): dark wood strips
	for k2: int in 26:
		var x2: float = -2.6 + k2 * 0.2
		Props.block(g, Vector3(x2, 0.0, 0.3), Vector3(x2 + 0.12, 0.012, length * 0.82), "beam", false)
	# 8.8 cm deck gun forward of the tower (on its pedestal; dressing: the deck's collider is unchanged)
	var gun: Vector3 = Vector3(0, 0, 8.6)
	Props.cyl(g, gun + Vector3(0, 0.35, 0), 0.32, 0.7, k_fit)
	Props.cyl(g, gun + Vector3(0, 0.75, 0), 0.5, 0.12, k_fit)
	Props.block(g, gun + Vector3(-0.28, 0.8, -0.6), gun + Vector3(0.28, 1.3, 0.7), "grey_paint")
	Props.cyl(g, gun + Vector3(0, 1.08, -2.4), 0.07, 3.8, "grey_paint", Vector3(90, 0, 0))
	Props.cyl(g, gun + Vector3(0, 1.08, -0.9), 0.12, 0.8, "grey_paint", Vector3(90, 0, 0))
	for sx3: float in [-0.42, 0.42]:
		Props.block(g, gun + Vector3(sx3 - 0.03, 0.85, 0.3), gun + Vector3(sx3 + 0.03, 1.25, 0.9), k_fit)
	# cleats and a fairlead pair on each deck edge
	for zc: float in [2.0, 30.0, 44.0]:
		for sx4: float in [-2.75, 2.75]:
			Props.block(g, Vector3(sx4 - 0.08, 0.0, zc - 0.25), Vector3(sx4 + 0.08, 0.1, zc + 0.25), k_fit)
			Props.block(g, Vector3(sx4 - 0.05, 0.1, zc - 0.32), Vector3(sx4 + 0.05, 0.16, zc + 0.32), k_fit)


## A flat convex ring (n + 1 points, the last on the first, n even, mirror pairs i and n - i at the same x) filled
## with trapezoids between its mirror pairs, its front facing `out`. Shares the ring's points, so it closes the wall
## it sits on.
static func _ring_disc(ring: PackedVector3Array, n: int, out: Vector3) -> ArrayMesh:
	var lines: Array = []
	for i: int in n / 2 + 1:
		lines.append(PackedVector3Array([ring[i], ring[n - i]]))
	return strip(lines, func(p: Vector3) -> Vector3: return p - out, true)


## How much the hull must hold the interior box at local z (1 up to `hold_to`, easing out over the next 5 m).
static func _hold(z: float, hold_to: float) -> float:
	if hold_to <= 0.0:
		return 0.0
	return 1.0 - smoothstep(hold_to, hold_to + 5.0, z)


## The conning tower over U-1047's CT collider: a streamlined bridge fairing (rounded front, flared lip), the
## wintergarten aft with the 2 cm flak, two tapered periscope standards with their heads, the direction-finder loop,
## the bridge railing, the spray deflector and the hull number. `c` is the collider footprint's centre on the deck
## (boat group space), half sizes `hx`, `hz`; tower stands `h` metres high.
static func vii_tower(g: Node3D, c: Vector3, hx: float, hz: float, h: float, number: String, k_hull: String = "m2_hull") -> void:
	# T-282: a closed solid, a cup: the outer skin up to the flared lip, the lip across the top of the wall, the inner
	# skin down to the bridge floor, the floor, and the base on the deck. It was the outer skin alone, open at the
	# top, so from the bridge's height (the signal tower, the catwalks) you looked through the far wall from inside;
	# and the floor was a rectangle whose corners stood out through the rounded front and the narrower aft end
	var n: int = 14
	var wall: float = 0.1
	var floor_y: float = h - 0.5
	var ring_at: Callable = func(y: float, grow: float) -> PackedVector3Array:
		var ring: PackedVector3Array = []
		for i: int in n + 1:
			var a: float = TAU * float(i) / float(n)
			var sx: float = cos(a)
			var sz: float = sin(a)
			# a stadium: rounded at the front (-z), squarer aft
			var rx: float = hx + 0.12 + grow
			var rz: float = hz + 0.12 + grow
			var px: float = c.x + sx * rx
			var pz: float = c.z + (sz * rz if sz < 0.0 else sz * rz * 0.85)
			ring.append(Vector3(px, c.y + y, pz))
		ring[n] = ring[0]   # the seam closes exactly
		return ring
	var rings: Array = [ring_at.call(0.0, 0.0), ring_at.call(h * 0.55, 0.0), ring_at.call(h * 0.92, 0.0), ring_at.call(h, 0.14),
		ring_at.call(h, -wall), ring_at.call(floor_y, -wall)]
	# the outer skin (the shape the CT collider is fitted to, T-180) faces out; the lip and the inner skin, one strip
	# from the outer top edge in and down, face in (toward the bridge) and up (the lip)
	surface(g, "TowerFairing", strip(rings.slice(0, 4), func(p: Vector3) -> Vector3: return Vector3(c.x, p.y, c.z)), k_hull)
	var inward: Callable = func(p: Vector3) -> Vector3: return Vector3(2.0 * p.x - c.x, p.y, 2.0 * p.z - c.z)
	no_fit(surface(g, "TowerFairingLip", strip(rings.slice(3, 6), inward), k_hull))
	# the bridge floor (grating, up) inside the inner skin and the base on the deck (down: never seen, it closes the solid)
	no_fit(surface(g, "TowerFairingFloor", _ring_disc(rings[5], n, Vector3.UP), "steel_grate", false))
	no_fit(surface(g, "TowerFairingBase", _ring_disc(rings[0], n, Vector3.DOWN), k_hull, false))
	Props.railing(g, c + Vector3(-hx - 0.1, h, hz + 0.1), c + Vector3(hx + 0.1, h, hz + 0.1), 0.85, "iron", 0.8)
	# the wintergarten: a railed platform aft at bridge height with the 2 cm flak on a pedestal
	var wg: Vector3 = c + Vector3(0, h - 0.55, hz + 1.3)
	Props.block(g, wg + Vector3(-hx * 0.8, 0, -1.1), wg + Vector3(hx * 0.8, 0.08, 1.1), "steel_grate")
	for sx2: float in [-hx * 0.8, hx * 0.8]:
		Props.railing(g, wg + Vector3(sx2, 0.08, -1.1), wg + Vector3(sx2, 0.08, 1.1), 0.9, "iron", 0.7)
		Props.strut(g, wg + Vector3(sx2, 0, 1.0), c + Vector3(sx2, 0.0, hz + 2.2), 0.07, "iron", true)
	Props.railing(g, wg + Vector3(-hx * 0.8, 0.08, 1.1), wg + Vector3(hx * 0.8, 0.08, 1.1), 0.9, "iron", 0.7)
	Props.cyl(g, wg + Vector3(0, 0.55, 0.2), 0.12, 1.0, "grey_paint")
	Props.block(g, wg + Vector3(-0.3, 1.0, -0.2), wg + Vector3(0.3, 1.25, 0.5), "grey_paint")
	Props.cyl(g, wg + Vector3(0, 1.12, -0.6), 0.035, 1.3, "grey_paint", Vector3(90, 0, 0))
	# periscope standards: tapered housings on the tower's forward half, the periscopes themselves above
	for ps: Array in [[Vector3(c.x - 0.2, 0, c.z - hz * 0.25), 2.6, 0.3], [Vector3(c.x + 0.25, 0, c.z + hz * 0.15), 3.4, 0.24]]:
		var p0: Vector3 = ps[0] as Vector3
		Props.cone(g, Vector3(p0.x, c.y + h + 0.9, p0.z), float(ps[2]) + 0.12, 1.8, k_hull)
		Props.cyl(g, Vector3(p0.x, c.y + h + 1.8 + float(ps[1]) * 0.5, p0.z), 0.09, float(ps[1]), "grey_paint")
		Props.block(g, Vector3(p0.x - 0.1, c.y + h + 1.8 + float(ps[1]), p0.z - 0.18), Vector3(p0.x + 0.1, c.y + h + 2.0 + float(ps[1]), p0.z + 0.06), "grey_paint")
	# the direction-finder loop and the spray deflector at the front of the bridge
	var df: Vector3 = Vector3(c.x - hx * 0.6, c.y + h + 1.0, c.z + hz * 0.4)
	Props.cyl(g, df, 0.03, 1.0, "iron")
	for k: int in 10:
		var a2: float = TAU * float(k) / 10.0
		var a3: float = TAU * float(k + 1) / 10.0
		Props.strut(g, df + Vector3(0, 0.75 + cos(a2) * 0.28, sin(a2) * 0.28), df + Vector3(0, 0.75 + cos(a3) * 0.28, sin(a3) * 0.28), 0.03, "iron", true)
	Props.obox(g, c + Vector3(0, h + 0.05, -hz - 0.2), Vector3(hx * 2.0 + 0.3, 0.06, 0.5), k_hull, Vector3(-25, 0, 0))
	for sx3: float in [-1.0, 1.0]:
		Props.stencil(g, c + Vector3(sx3 * (hx + 0.15), h * 0.55, 0), -90.0 * sx3, number, 40, Color(0.85, 0.82, 0.7, 0.8))
	# the bridge ladder on the aft face, the attack-periscope's well cap and the hatch rim
	Props.ladder(g, c + Vector3(0.4, 0, hz + 0.14), 180.0, h, "iron")
	Props.ladder_chain(g, c + Vector3(0.4, 0, hz + 0.14), 180.0, 1.1, "GESPERRT")   # (T-229: the bridge is not a floor anyone stands on)


# ================================================================== the cutter

## A beached clinker-built fishing cutter under `g` (local +X runs bow to stern, y 0 = the keel's foot, beam on Z).
## Six overlapping strakes per side (each upper strake laps over the one below: the step is the clinker line),
## a rubbing strake, the deck, the wheelhouse with its windows and open door, the lashed wheel inside, the mast,
## nets and floats. length / beam / depth in metres.
static func cutter(g: Node3D, length: float, beam: float, depth: float, k_planks: String = "planks", k_trim: String = "beam") -> void:
	var secs: int = 22
	var strakes: int = 6
	var half_at: Callable = func(u: float, t: float) -> Vector3:
		# u along (0 bow .. 1 stern), t down the side (0 sheer .. 1 keel); returns (x, y, z) for the starboard side
		var b: float = beam * 0.5 * pow(sin(PI * clampf(u * 0.92 + 0.04, 0.0, 1.0)), 0.55) * (1.0 if u > 0.15 else lerpf(0.25, 1.0, u / 0.15))
		var sheer: float = depth + 0.35 * pow(1.0 - u, 2.0) + 0.15 * u * u
		var y: float = lerpf(sheer, 0.15, pow(t, 1.3))
		var x: float = b * cos(t * PI * 0.48)
		return Vector3(u * length, y, x)
	for side: float in [-1.0, 1.0]:
		for k: int in strakes:
			var t0: float = float(k) / float(strakes)
			var t1: float = float(k + 1) / float(strakes) + 0.035
			var lines: Array = []
			for s: int in secs + 1:
				var u: float = float(s) / float(secs)
				var a: Vector3 = half_at.call(u, t0)
				var b2: Vector3 = half_at.call(u, minf(t1, 1.0))
				var lap: float = 0.03   # the lower edge of each strake stands proud: the clinker step
				lines.append(PackedVector3Array([Vector3(a.x, a.y, a.z * side), Vector3(b2.x, b2.y, (b2.z + lap * signf(b2.z + 0.001)) * side)]))
			surface(g, "Strake%s%d" % ["S" if side > 0.0 else "P", k], strip(lines, func(p: Vector3) -> Vector3: return Vector3(p.x, p.y, 0.0)), k_planks)
			# T-282: the planking's inside, seen over the gunwale from above (one-sided planks vanished from there)
			no_fit(surface(g, "StrakeIn%s%d" % ["S" if side > 0.0 else "P", k], strip(lines, func(p: Vector3) -> Vector3: return Vector3(p.x, p.y, 2.0 * p.z)), k_planks, false))
		# rubbing strake along the sheer
		var rs: Array = []
		for s2: int in secs + 1:
			var u2: float = float(s2) / float(secs)
			var p: Vector3 = half_at.call(u2, 0.0)
			rs.append(PackedVector3Array([Vector3(p.x, p.y + 0.04, (p.z + 0.06) * side), Vector3(p.x, p.y - 0.14, (p.z + 0.06) * side)]))
		surface(g, "Rubbing" + ("S" if side > 0.0 else "P"), strip(rs, func(p: Vector3) -> Vector3: return Vector3(p.x, p.y, 0.0), true), k_trim)
		no_fit(surface(g, "RubbingIn" + ("S" if side > 0.0 else "P"), strip(rs, func(p: Vector3) -> Vector3: return Vector3(p.x, p.y, 2.0 * p.z), true), k_trim, false))
	# keel, stem and sternpost
	Props.block(g, Vector3(0.1, 0.0, -0.08), Vector3(length - 0.1, 0.2, 0.08), k_trim)
	Props.obox(g, Vector3(0.12, depth * 0.55, 0), Vector3(0.14, depth * 1.15, 0.14), k_trim, Vector3(0, 0, 18))
	Props.obox(g, Vector3(length - 0.12, depth * 0.55, 0), Vector3(0.14, depth * 1.05, 0.14), k_trim, Vector3(0, 0, -8))
	# deck planking (slightly below the sheer), hatch coaming with a tarp, the fish hold's open hatch
	Props.block(g, Vector3(0.6, depth - 0.15, -beam * 0.42), Vector3(length - 0.5, depth - 0.08, beam * 0.42), k_planks)
	Props.block(g, Vector3(length * 0.32, depth - 0.08, -0.8), Vector3(length * 0.52, depth + 0.3, 0.8), k_trim)
	Props.block(g, Vector3(length * 0.33, depth + 0.3, -0.75), Vector3(length * 0.45, depth + 0.32, 0.75), "tarp")
	# the wheelhouse aft: planked walls, four windows with frames, an open door, a tar-paper roof
	var wh: Vector3 = Vector3(length * 0.72, depth - 0.08, 0.0)
	var wx: float = 1.3
	var wz: float = 1.1
	var hh: float = 1.9
	Props.block(g, wh + Vector3(-wx, 0, -wz), wh + Vector3(wx, hh, -wz + 0.08), k_planks)
	Props.block(g, wh + Vector3(-wx, 0, wz - 0.08), wh + Vector3(wx, hh, wz), k_planks)
	Props.block(g, wh + Vector3(-wx, 0, -wz), wh + Vector3(-wx + 0.08, hh, wz), k_planks)
	Props.block(g, wh + Vector3(wx - 0.08, 0, -wz), wh + Vector3(wx, hh, -0.2), k_planks)
	Props.block(g, wh + Vector3(wx - 0.08, 1.75, -0.2), wh + Vector3(wx, hh, wz), k_planks)
	Props.block(g, wh + Vector3(-wx - 0.12, hh, -wz - 0.12), wh + Vector3(wx + 0.12, hh + 0.12, wz + 0.12), "m2_tarred")
	for wp: Array in [[Vector3(-wx - 0.01, 1.2, 0), 90.0], [Vector3(0, 1.2, -wz - 0.01), 0.0], [Vector3(0, 1.2, wz + 0.01), 180.0]]:
		var wg: Node3D = Props.group(g, "WheelhouseWindow", wh + (wp[0] as Vector3), float(wp[1]))
		Props.block(wg, Vector3(-0.5, -0.32, -0.01), Vector3(0.5, 0.32, 0.0), "window_dark", false)
		for fy: float in [-0.36, 0.32]:
			Props.block(wg, Vector3(-0.55, fy, -0.04), Vector3(0.55, fy + 0.05, 0.01), k_trim)
		for fx: float in [-0.55, -0.02, 0.5]:
			Props.block(wg, Vector3(fx, -0.32, -0.04), Vector3(fx + 0.05, 0.32, 0.01), k_trim)
	# the door hangs open against the aft wall
	Props.block(g, wh + Vector3(wx, 0.02, wz - 0.02), wh + Vector3(wx + 0.05, 1.72, wz + 0.82), k_planks)
	# the wheel, lashed: a rim of spokes on a binnacle post, two lines from the rim to the walls
	var wc: Vector3 = wh + Vector3(-wx + 0.5, 1.05, 0.0)
	Props.block(g, wc + Vector3(-0.1, -1.05, -0.1), wc + Vector3(0.1, 0.0, 0.1), k_trim)
	for k3: int in 12:
		var a4: float = TAU * float(k3) / 12.0
		var a5: float = TAU * float(k3 + 1) / 12.0
		Props.strut(g, wc + Vector3(0.12, cos(a4) * 0.42, sin(a4) * 0.42), wc + Vector3(0.12, cos(a5) * 0.42, sin(a5) * 0.42), 0.035, k_trim)
		if k3 % 2 == 0:
			Props.strut(g, wc + Vector3(0.12, 0, 0), wc + Vector3(0.12, cos(a4) * 0.55, sin(a4) * 0.55), 0.025, k_trim)
	Props.cable(g, wc + Vector3(0.12, 0.3, -0.3), wh + Vector3(-wx + 0.4, 1.1, -wz + 0.1), -0.05, 0.015, 4, "rope")
	Props.cable(g, wc + Vector3(0.12, -0.3, 0.3), wh + Vector3(-wx + 0.4, 0.8, wz - 0.1), -0.05, 0.015, 4, "rope")
	# mast with its boom lashed down, shrouds, cork floats and nets over the gunwale
	var mast: Vector3 = Vector3(length * 0.25, depth, 0)
	Props.cyl(g, mast + Vector3(0, 3.4, 0), 0.11, 6.8, "pine")
	Props.strut(g, mast + Vector3(0, 1.4, 0), mast + Vector3(length * 0.42, 1.1, 0.2), 0.08, "pine", true)
	for sz: float in [-1.0, 1.0]:
		Props.cable(g, mast + Vector3(0, 6.2, 0), Vector3(length * 0.25, depth + 0.1, sz * beam * 0.45), 0.0, 0.012, 2, "iron")
	Props.cable(g, mast + Vector3(0, 6.2, 0), Vector3(0.3, depth + 0.4, 0), 0.0, 0.012, 2, "iron")
	for k4: int in 9:
		var fz: float = -beam * 0.5 - 0.05
		var fx2: float = length * 0.28 + k4 * 0.55
		Props.ball(g, Vector3(fx2, depth - 0.25 - 0.18 * sin(k4 * 1.7), fz), Vector3(0.14, 0.1, 0.1), "furniture")
	Props.net_pile(g, Vector3(length * 0.58, depth - 0.1, -beam * 0.2), Vector3(1.6, 0.5, 1.4), 21)


# ================================================================== torpedo workshop

## A G7 torpedo on a proper cradle (two steel saddles on a wheeled trestle): body with the warhead section, an
## inspection hatch and its screws, the tail cone with four fins and the contra-rotating screws. Local -Z = nose.
static func torpedo_cradle(parent: Node3D, pos: Vector3, yaw: float, length: float = 7.0, on_cradle: bool = true, hatch_open: bool = false) -> void:
	var g: Node3D = Props.group(parent, "TorpedoCradle", pos, yaw)
	var r: float = 0.267
	var y: float = 0.98 if on_cradle else r
	if on_cradle:
		for tz: float in [-length * 0.28, length * 0.26]:
			# the saddle: a half ring of plates under the body, on two legs and a crossbar with castors
			for k: int in 7:
				var a: float = PI + PI * float(k) / 6.0
				var a2: float = PI + PI * float(k + 1) / 6.0
				Props.strut(g, Vector3(cos(a) * (r + 0.03), y + sin(a) * (r + 0.03), tz), Vector3(cos(a2) * (r + 0.03), y + sin(a2) * (r + 0.03), tz), 0.05, "grey_paint")
			for sx: float in [-0.42, 0.42]:
				Props.strut(g, Vector3(sx, 0.12, tz), Vector3(sx * 0.6, y - r * 0.6, tz), 0.07, "grey_paint")
				Props.cyl(g, Vector3(sx, 0.07, tz), 0.07, 0.06, "rubber", Vector3(0, 0, 90))
			Props.block(g, Vector3(-0.5, 0.12, tz - 0.05), Vector3(0.5, 0.2, tz + 0.05), "grey_paint")
			Props.block(g, Vector3(-0.45, y - r - 0.02, tz - 0.07), Vector3(0.45, y - r + 0.02, tz + 0.07), "rubber")
		Props.block(g, Vector3(-0.04, 0.14, -length * 0.28), Vector3(0.04, 0.2, length * 0.26), "grey_paint")
	Props.cyl(g, Vector3(0, y, 0.15), r, length * 0.66, "grey_paint", Vector3(90, 0, 0))
	Props.cyl(g, Vector3(0, y, -length * 0.25), r + 0.003, length * 0.18, "hull_red", Vector3(90, 0, 0))   # warhead section
	Props.cone(g, Vector3(0, y, -length * 0.34 - 0.25), r, 0.5, "hull_red", Vector3(-90, 0, 0))
	Props.ball(g, Vector3(0, y, -length * 0.34 - 0.5), Vector3(0.12, 0.12, 0.12), "brass")
	Props.cone(g, Vector3(0, y, length * 0.48 + 0.3), r, 0.9, "grey_paint", Vector3(90, 0, 0))
	for k2: int in 4:
		var a3: float = 45.0 + 90.0 * k2
		Props.obox(g, Vector3(0, y, length * 0.48 + 0.55), Vector3(0.04, 0.72, 0.42), "grey_paint", Vector3(0, 0, a3))
	for ring: int in 2:
		var z2: float = length * 0.48 + 0.82 + ring * 0.16
		for k3: int in 4:
			Props.obox(g, Vector3(0, y, z2), Vector3(0.5, 0.05, 0.06), "brass", Vector3(0, 0, k3 * 45.0 + ring * 22.5))
		Props.cyl(g, Vector3(0, y, z2), 0.045, 0.12, "brass", Vector3(90, 0, 0))
	# inspection hatch on top of the after body (open on the one being gutted), seam rings
	var hz: float = length * 0.08
	if hatch_open:
		Props.block(g, Vector3(-0.14, y + r - 0.01, hz - 0.3), Vector3(0.14, y + r + 0.005, hz + 0.3), "black_paint", false)
		Props.obox(g, Vector3(0.3, y + r + 0.12, hz), Vector3(0.02, 0.28, 0.6), "grey_paint", Vector3(0, 0, -60))
	else:
		Props.block(g, Vector3(-0.14, y + r - 0.004, hz - 0.3), Vector3(0.14, y + r + 0.006, hz + 0.3), "iron", false)
	for sz: float in [-length * 0.16, length * 0.3]:
		Props.cyl(g, Vector3(0, y, sz), r + 0.006, 0.02, "iron", Vector3(90, 0, 0))


## The overhead gantry's chain hoist: a trolley on the rail, the hoist body, a looped hand chain and the hook.
static func chain_hoist(parent: Node3D, rail_pos: Vector3, drop: float) -> void:
	var g: Node3D = Props.group(parent, "ChainHoist", rail_pos, 0.0)
	Props.block(g, Vector3(-0.35, -0.12, -0.25), Vector3(0.35, 0.05, 0.25), "machine_grey")
	for sx: float in [-0.25, 0.25]:
		Props.cyl(g, Vector3(sx, 0.08, 0), 0.08, 0.06, "iron", Vector3(0, 0, 90))
	Props.cyl(g, Vector3(0, -0.45, 0), 0.2, 0.5, "red_paint")
	Props.cyl(g, Vector3(0.23, -0.45, 0), 0.24, 0.05, "iron", Vector3(0, 0, 90))
	for k: int in int(drop / 0.12):
		var y: float = -0.7 - k * 0.12
		Props.obox(g, Vector3(0, y, 0), Vector3(0.025, 0.1, 0.06) if k % 2 == 0 else Vector3(0.06, 0.1, 0.025), "iron")
	Props.cable(g, Vector3(0.25, -0.5, 0.05), Vector3(0.25, -0.5 - drop * 0.6, 0.05), 0.0, 0.012, 2, "iron")
	Props.cable(g, Vector3(0.25, -0.5, -0.05), Vector3(0.25, -0.5 - drop * 0.6, -0.05), 0.0, 0.012, 2, "iron")
	hook(g, Vector3(0, -0.75 - drop, 0), 0.6)


## A cargo hook: the block, the shank and the curved bill.
static func hook(parent: Node3D, top: Vector3, s: float = 1.0) -> void:
	Props.block(parent, top + Vector3(-0.12, -0.1, -0.08) * s, top + Vector3(0.12, 0.12, 0.08) * s, "crane_yellow")
	Props.cyl(parent, top + Vector3(0, -0.25, 0) * s, 0.04 * s, 0.3 * s, "iron")
	for k: int in 7:
		var a: float = PI * 0.15 + PI * 1.2 * float(k) / 7.0
		var a2: float = PI * 0.15 + PI * 1.2 * float(k + 1) / 7.0
		var c: Vector3 = top + Vector3(0.0, -0.55, 0) * s
		Props.strut(parent, c + Vector3(cos(a) * 0.15, -sin(a) * 0.15, 0) * s, c + Vector3(cos(a2) * 0.15, -sin(a2) * 0.15, 0) * s, 0.06 * s, "iron", true)


## A tool wall: a pegboard with outlined tools hung on it, a shelf with toolboxes underneath.
static func tool_wall(parent: Node3D, pos: Vector3, yaw: float, w: float = 3.0) -> void:
	var g: Node3D = Props.group(parent, "ToolWall", pos, yaw)
	Props.block(g, Vector3(-w * 0.5, 1.0, -0.03), Vector3(w * 0.5, 2.3, 0.0), "planks")
	for k: int in int(w / 0.28):
		var x: float = -w * 0.5 + 0.2 + k * 0.28
		var kind: int = k % 4
		if kind == 0:   # spanner
			Props.block(g, Vector3(x - 0.02, 1.3, -0.06), Vector3(x + 0.02, 1.8, -0.03), "steel")
			Props.block(g, Vector3(x - 0.05, 1.78, -0.06), Vector3(x + 0.05, 1.86, -0.03), "steel")
		elif kind == 1:   # hammer
			Props.block(g, Vector3(x - 0.015, 1.25, -0.06), Vector3(x + 0.015, 1.7, -0.03), "furniture")
			Props.block(g, Vector3(x - 0.07, 1.7, -0.07), Vector3(x + 0.07, 1.76, -0.03), "iron")
		elif kind == 2:   # saw
			Props.block(g, Vector3(x - 0.09, 1.35, -0.045), Vector3(x + 0.09, 1.8, -0.035), "steel")
		else:             # file / screwdriver
			Props.block(g, Vector3(x - 0.012, 1.4, -0.05), Vector3(x + 0.012, 1.75, -0.03), "iron")
			Props.block(g, Vector3(x - 0.02, 1.75, -0.055), Vector3(x + 0.02, 1.85, -0.03), "red_paint")
	Props.block(g, Vector3(-w * 0.5, 0.9, -0.35), Vector3(w * 0.5, 0.95, 0.0), "furniture")
	for sx: float in [-w * 0.45, w * 0.45]:
		Props.block(g, Vector3(sx - 0.03, 0.0, -0.33), Vector3(sx + 0.03, 0.9, -0.27), "iron")


## A belt-driven lathe on its stand: bed, headstock, tailstock, chuck, the belt guard up to a line shaft.
static func lathe(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var g: Node3D = Props.group(parent, "Lathe", pos, yaw)
	for sx: float in [-1.4, 1.4]:
		Props.block(g, Vector3(sx - 0.2, 0, -0.3), Vector3(sx + 0.2, 0.85, 0.3), "machine_green")
	Props.block(g, Vector3(-1.7, 0.85, -0.25), Vector3(1.7, 1.0, 0.25), "machine_green")
	Props.block(g, Vector3(-1.7, 1.0, -0.3), Vector3(-1.0, 1.45, 0.3), "machine_green")
	Props.cyl(g, Vector3(-0.92, 1.22, 0), 0.16, 0.16, "steel", Vector3(0, 0, 90))
	Props.block(g, Vector3(0.9, 1.0, -0.18), Vector3(1.3, 1.32, 0.18), "machine_green")
	Props.cyl(g, Vector3(0.0, 1.22, 0), 0.05, 1.7, "steel", Vector3(0, 0, 90))
	Props.block(g, Vector3(-0.3, 1.0, -0.32), Vector3(0.1, 1.15, 0.32), "machine_grey")
	Props.block(g, Vector3(-1.62, 1.45, 0.05), Vector3(-1.4, 3.2, 0.2), "machine_grey")
	Props.cyl(g, Vector3(-1.5, 3.3, 0.12), 0.25, 0.1, "iron", Vector3(90, 0, 0))


## The warhead cage's coffins: lead boxes on pallets, each with a violet seam (Props.coffin), stacked two high.
static func coffin_stack(parent: Node3D, pos: Vector3, yaw: float, units: Array) -> void:
	var g: Node3D = Props.group(parent, "CoffinStack", pos, yaw)
	for i: int in units.size():
		var layer: int = i / 2
		var side: float = -0.42 if i % 2 == 0 else 0.42
		Props.coffin(g, Vector3(0, layer * 0.76, side), 0.0, str(units[i]), layer == 0)


# ================================================================== cannery, infirmary

## A belt conveyor with cans riding it: frame, rollers under a rubber belt, a can every 0.3 m, legs.
static func conveyor(parent: Node3D, a: Vector3, b: Vector3, w: float = 1.4, h: float = 1.0, cans: bool = true) -> void:
	var len_: float = a.distance_to(b)
	var dir: Vector3 = (b - a).normalized()
	var yaw: float = rad_to_deg(atan2(dir.x, dir.z))
	var g: Node3D = Props.group(parent, "Conveyor", (a + b) * 0.5, yaw)
	for sx: float in [-w * 0.5, w * 0.5]:
		Props.block(g, Vector3(sx - 0.04, h - 0.18, -len_ * 0.5), Vector3(sx + 0.04, h, len_ * 0.5), "machine_green")
	Props.block(g, Vector3(-w * 0.48, h - 0.04, -len_ * 0.5), Vector3(w * 0.48, h, len_ * 0.5), "rubber")
	for k: int in (int(len_ / 0.3) if cans else 0):   # T-154: the living world's ConveyorCans ride the belt instead
		var z: float = -len_ * 0.5 + 0.15 + k * 0.3
		Props.cyl(g, Vector3(0, h + 0.06, z), 0.05, 0.11, "can_tin")
	for k2: int in int(len_ / 2.0) + 1:
		var z2: float = -len_ * 0.5 + k2 * len_ / float(int(len_ / 2.0))
		for sx2: float in [-w * 0.45, w * 0.45]:
			Props.block(g, Vector3(sx2 - 0.04, 0, z2 - 0.04), Vector3(sx2 + 0.04, h - 0.18, z2 + 0.04), "iron")
	Props.block(g, Vector3(-w * 0.5, h - 0.6, len_ * 0.5 - 0.6), Vector3(w * 0.5, h - 0.18, len_ * 0.5), "machine_grey")


## A riveted brine tank with a hinged lid half open, two hoops, a drain cock.
static func brine_tank(parent: Node3D, pos: Vector3, r: float, h: float, k_zinc: String = "m2_zinc") -> void:
	Props.cyl(parent, pos + Vector3(0, h * 0.5, 0), r, h, k_zinc)
	for y: float in [0.08, h * 0.5, h - 0.06]:
		Props.cyl(parent, pos + Vector3(0, y, 0), r + 0.025, 0.06, "iron")
	Props.cyl(parent, pos + Vector3(0, h + 0.02, 0), r + 0.03, 0.04, "planks")   # the lid
	Props.obox(parent, pos + Vector3(-r * 0.5, h + 0.35, 0), Vector3(r, 0.04, r * 1.6), "planks", Vector3(0, 0, 55))
	Props.cyl(parent, pos + Vector3(r + 0.08, 0.25, 0), 0.04, 0.16, "brass", Vector3(0, 0, 90))
	Props.ball(parent, pos + Vector3(0, h - 0.01, 0), Vector3(r * 1.9, 0.02, r * 1.9), "tide_mark")


## A row of meat hooks on a ceiling rail: the rail on hangers and an S-hook every 0.6 m.
static func hook_rail(parent: Node3D, a: Vector3, b: Vector3, ceil_y: float) -> void:
	Props.block(parent, a + Vector3(-0.03, -0.06, -0.03), b + Vector3(0.03, 0.0, 0.03), "steel")
	var n: int = int(a.distance_to(b) / 0.6)
	for k: int in n + 1:
		var p: Vector3 = a.lerp(b, float(k) / float(maxi(1, n)))
		if k % 4 == 0:
			Props.block(parent, p + Vector3(-0.015, 0, -0.015), Vector3(p.x + 0.015, ceil_y, p.z + 0.015), "iron")
		Props.strut(parent, p + Vector3(0, -0.06, 0), p + Vector3(0, -0.32, 0), 0.015, "steel", true)
		Props.strut(parent, p + Vector3(0, -0.32, 0), p + Vector3(0.06, -0.4, 0), 0.015, "steel", true)


## A three-panel folding screen (infirmary): frames with linen stretched in them, the panels angled.
static func screen(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var g: Node3D = Props.group(parent, "Screen", pos, yaw)
	for k: int in 3:
		var p: Node3D = Props.group(g, "Panel", Vector3((k - 1) * 0.62, 0, 0.12 if k != 1 else 0.0), [-25.0, 0.0, 25.0][k])
		Props.block(p, Vector3(-0.3, 0.0, -0.02), Vector3(-0.27, 1.75, 0.02), "iron")
		Props.block(p, Vector3(0.27, 0.0, -0.02), Vector3(0.3, 1.75, 0.02), "iron")
		Props.block(p, Vector3(-0.3, 1.72, -0.02), Vector3(0.3, 1.75, 0.02), "iron")
		Props.block(p, Vector3(-0.27, 0.2, -0.005), Vector3(0.27, 1.7, 0.005), "linen")


## A skylight row in a roof: frames, glass, and snow lying on the panes (seen from below as dark patches).
static func skylights(parent: Node3D, x0: float, x1: float, z: float, roof_y: float, w: float, n: int) -> void:
	var step: float = (x1 - x0) / float(n)
	for k: int in n:
		var cx: float = x0 + step * (k + 0.5)
		Props.block(parent, Vector3(cx - step * 0.42, roof_y - 0.02, z - w * 0.5), Vector3(cx + step * 0.42, roof_y, z + w * 0.5), "window_dark", false)
		Props.block(parent, Vector3(cx - step * 0.45, roof_y - 0.12, z - w * 0.5 - 0.06), Vector3(cx + step * 0.45, roof_y - 0.02, z - w * 0.5), "iron")
		Props.block(parent, Vector3(cx - step * 0.45, roof_y - 0.12, z + w * 0.5), Vector3(cx + step * 0.45, roof_y - 0.02, z + w * 0.5 + 0.06), "iron")
		Props.block(parent, Vector3(cx - 0.03, roof_y - 0.1, z - w * 0.5), Vector3(cx + 0.03, roof_y - 0.02, z + w * 0.5), "iron")
		# snow drifted on the glass: pale lumps along the lower edge and in patches
		Props.block(parent, Vector3(cx - step * 0.4, roof_y + 0.01, z - w * 0.5), Vector3(cx + step * 0.4, roof_y + 0.08, z - w * 0.15), "snow", false)
		Props.block(parent, Vector3(cx - step * 0.2, roof_y + 0.01, z + w * 0.05), Vector3(cx + step * 0.1, roof_y + 0.05, z + w * 0.3), "snow", false)


# ================================================================== U-boat interior

## A round pressure-hull hatch frame in a bulkhead (the doorway itself is the collider's rectangle; this rings it):
## the coaming in segments, eight dogs, the hatch cover swung open on its hinge. `pos` = floor centre of the door,
## local -Z / +Z are the two faces.
static func round_hatch(parent: Node3D, pos: Vector3, yaw: float, w: float, h: float, open_side: float = 1.0) -> void:
	var g: Node3D = Props.group(parent, "RoundHatch", pos, yaw)
	var cy: float = h * 0.5
	var rx: float = w * 0.5 + 0.12
	var ry: float = h * 0.5 + 0.1
	var n: int = 16
	for k: int in n:
		var a: float = TAU * float(k) / float(n)
		var a2: float = TAU * float(k + 1) / float(n)
		for f: float in [-0.17, 0.17]:
			Props.strut(g, Vector3(cos(a) * rx, cy + sin(a) * ry, f), Vector3(cos(a2) * rx, cy + sin(a2) * ry, f), 0.09, "grey_paint", true)
		if k % 2 == 0:
			Props.obox(g, Vector3(cos(a) * (rx + 0.08), cy + sin(a) * (ry + 0.08), 0.22), Vector3(0.05, 0.16, 0.05), "iron", Vector3(0, 0, rad_to_deg(a)))
	# the cover, open against the bulkhead
	var cov: Node3D = Props.group(g, "Cover", Vector3(open_side * rx, cy, 0.3), open_side * 95.0)
	Props.obox(cov, Vector3(-open_side * rx, 0, 0), Vector3(w * 0.9, h * 0.85, 0.06), "grey_paint")
	Props.obox(cov, Vector3(-open_side * rx, 0, 0), Vector3(w * 0.7, h * 0.95, 0.07), "grey_paint", Vector3(0, 0, 90))
	Props.valve_wheel(cov, Vector3(-open_side * rx, 0, 0.06), 180.0, 0.16, "iron")


# ================================================================== lower pens, tower

## A tide pump as a machine you can read: a horizontal centrifugal casing (volute) on a bedplate, the motor, the
## coupling guard, the flywheel's bearing pedestal, flanged suction and delivery pipes with valves.
static func pump(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var g: Node3D = Props.group(parent, "TidePump", pos, yaw)
	Props.block(g, Vector3(-2.0, 0, -4.0), Vector3(2.0, 0.3, 4.0), "iron")
	# volute casing (a fat drum with a spiral lip) and its delivery outlet
	Props.cyl(g, Vector3(0, 1.2, -2.2), 1.05, 0.9, "machine_green", Vector3(90, 0, 0))
	Props.cyl(g, Vector3(0, 1.2, -2.2), 1.12, 0.12, "iron", Vector3(90, 0, 0))
	for k: int in 10:
		var a: float = TAU * float(k) / 10.0
		Props.ball(g, Vector3(cos(a) * 1.08, 1.2 + sin(a) * 1.08, -1.72), Vector3(0.07, 0.07, 0.05), "steel")
	Props.block(g, Vector3(0.6, 1.2, -2.6), Vector3(1.3, 2.4, -1.8), "machine_green")
	# motor on the bedplate behind it, cooling ribs, the coupling guard between them
	Props.cyl(g, Vector3(0, 1.0, 1.2), 0.8, 2.6, "machine_grey", Vector3(90, 0, 0))
	for k2: int in 9:
		Props.cyl(g, Vector3(0, 1.0, 0.1 + k2 * 0.27), 0.84, 0.05, "iron", Vector3(90, 0, 0))
	# T-154: the motor's end, not a box (U09 captures: "the pump casing reads as a box"): the end bell, the fan
	# cowl with its grille and a domed cap, a small terminal box on top, the feet on the bedplate
	Props.cyl(g, Vector3(0, 1.0, 2.62), 0.84, 0.24, "machine_grey", Vector3(90, 0, 0))
	Props.cyl(g, Vector3(0, 1.0, 2.98), 0.78, 0.5, "machine_grey", Vector3(90, 0, 0))
	for k3: int in 7:
		Props.block(g, Vector3(-0.66 + k3 * 0.22, 0.42, 3.235), Vector3(-0.62 + k3 * 0.22, 1.58, 3.255), "iron")
	Props.ball(g, Vector3(0, 1.0, 3.28), Vector3(1.2, 1.2, 0.36), "machine_grey")
	Props.cyl(g, Vector3(0, 1.0, 3.47), 0.12, 0.05, "iron", Vector3(90, 0, 0))
	Props.block(g, Vector3(-0.24, 1.78, 0.7), Vector3(0.24, 2.12, 1.3), "machine_grey")
	Props.pipe(g, Vector3(0.0, 2.12, 1.0), Vector3(0.0, 2.6, 1.0), 0.03)
	for fx: float in [-0.62, 0.42]:
		Props.block(g, Vector3(fx, 0.3, 0.2), Vector3(fx + 0.2, 0.5, 2.6), "machine_grey")
	Props.block(g, Vector3(-0.35, 0.55, -1.75), Vector3(0.35, 1.45, -0.35), "yellow_paint")
	# flanged pipes: suction down through the deck, delivery up and along the wall
	Props.pipe(g, Vector3(0, 1.2, -3.2), Vector3(0, -0.6, -3.2), 0.24, "rust")
	for fy: float in [0.2, 0.9]:
		Props.cyl(g, Vector3(0, fy, -3.2), 0.32, 0.06, "iron")
	Props.pipe(g, Vector3(0.95, 2.4, -2.2), Vector3(0.95, 3.0, -2.2), 0.2, "rust")
	Props.cyl(g, Vector3(0.95, 2.7, -2.2), 0.28, 0.06, "iron")
	Props.valve_wheel(g, Vector3(1.24, 2.8, -2.2), -90.0, 0.25, "red_paint")
	Props.gauge(g, Vector3(-0.3, 2.0, 1.31), 180.0, 0.1)
	Props.gauge(g, Vector3(0.6, 2.4, -2.2), 180.0, 0.14)
	return g


## The teletype on its table: the machine body, the keyboard, the platen with a paper strip curling out of it and
## down onto the floor, the paper roll behind.
static func teletype(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var g: Node3D = Props.group(parent, "TeletypeMachine", pos, yaw)
	Props.block(g, Vector3(-0.6, 0, -0.75), Vector3(0.6, 0.78, 0.75), "furniture")
	Props.block(g, Vector3(-0.42, 0.78, -0.35), Vector3(0.42, 1.02, 0.45), "black_paint")
	Props.block(g, Vector3(-0.38, 1.02, -0.05), Vector3(0.38, 1.14, 0.42), "black_paint")
	for row: int in 4:
		for k: int in 9:
			Props.block(g, Vector3(-0.32 + k * 0.075, 0.82 + row * 0.018, -0.34 + row * 0.06), Vector3(-0.27 + k * 0.075, 0.84 + row * 0.018, -0.3 + row * 0.06), "paper")
	Props.cyl(g, Vector3(0, 1.08, 0.25), 0.05, 0.62, "rubber", Vector3(0, 0, 90))
	Props.cyl(g, Vector3(0, 1.24, 0.55), 0.09, 0.48, "paper", Vector3(0, 0, 90))
	# the strip: up over the platen, a curl in the air, down the front of the table, a coil on the floor
	var pts: Array = [Vector3(0, 1.14, 0.2), Vector3(0, 1.22, -0.05), Vector3(0, 1.1, -0.42), Vector3(0, 0.8, -0.78), Vector3(0.05, 0.3, -0.85), Vector3(0.12, 0.01, -1.0)]
	for i: int in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var mid: Vector3 = (a + b) * 0.5
		var d: Vector3 = b - a
		Props.obox(g, mid, Vector3(0.025, 0.002, d.length()), "paper", Vector3(rad_to_deg(atan2(-d.y, absf(d.z))) * (1.0 if d.z < 0.0 else -1.0), rad_to_deg(atan2(d.x, d.z)) + 180.0, 0))
	Props.cyl(g, Vector3(0.15, 0.03, -1.1), 0.12, 0.05, "paper")


## The signal lamp with a visible lens: a drum lantern on a yoke, the louvred shutter face, the ring of the lens.
static func signal_lamp_body(parent: Node3D) -> void:
	Props.cyl(parent, Vector3(0, -0.45, 0), 0.3, 0.2, "iron")
	Props.block(parent, Vector3(-0.38, -0.35, -0.04), Vector3(-0.32, 0.3, 0.04), "iron")
	Props.block(parent, Vector3(0.32, -0.35, -0.04), Vector3(0.38, 0.3, 0.04), "iron")
	Props.cyl(parent, Vector3(0, 0.1, 0), 0.3, 0.6, "machine_grey", Vector3(90, 0, 0))
	Props.cyl(parent, Vector3(0, 0.1, -0.31), 0.33, 0.04, "brass", Vector3(90, 0, 0))
	for k: int in 5:
		Props.block(parent, Vector3(-0.27, -0.12 + k * 0.1, -0.345), Vector3(0.27, -0.1 + k * 0.1, -0.335), "black_paint")
	Props.cyl(parent, Vector3(0, 0.45, 0.1), 0.08, 0.15, "iron")


## A window frame with mullions and transoms over an opening (w x h, sill at `sill`), on the face at local z 0:
## outer frame, two mullions, a transom, the panes (one broken), a sill board.
static func window_frame(parent: Node3D, pos: Vector3, yaw: float, w: float, h: float, sill: float, k_frame: String = "beam", broken: int = -1) -> void:
	var g: Node3D = Props.group(parent, "WindowFrame", pos, yaw)
	var t: float = 0.06
	Props.block(g, Vector3(-w * 0.5 - t, sill - t, -0.05), Vector3(w * 0.5 + t, sill, 0.05), k_frame)
	Props.block(g, Vector3(-w * 0.5 - t, sill + h, -0.05), Vector3(w * 0.5 + t, sill + h + t, 0.05), k_frame)
	Props.block(g, Vector3(-w * 0.5 - t, sill, -0.05), Vector3(-w * 0.5, sill + h, 0.05), k_frame)
	Props.block(g, Vector3(w * 0.5, sill, -0.05), Vector3(w * 0.5 + t, sill + h, 0.05), k_frame)
	for k: int in 2:
		var x: float = -w * 0.5 + w * float(k + 1) / 3.0
		Props.block(g, Vector3(x - 0.02, sill, -0.03), Vector3(x + 0.02, sill + h, 0.03), k_frame)
	Props.block(g, Vector3(-w * 0.5, sill + h * 0.62, -0.03), Vector3(w * 0.5, sill + h * 0.62 + 0.04, 0.03), k_frame)
	for k2: int in 6:
		if k2 == broken:
			continue
		var cx: float = -w * 0.5 + w * (float(k2 % 3) + 0.5) / 3.0
		var y0: float = sill if k2 < 3 else sill + h * 0.62 + 0.04
		var y1: float = sill + h * 0.62 if k2 < 3 else sill + h
		Props.block(g, Vector3(cx - w / 6.0 + 0.02, y0, -0.006), Vector3(cx + w / 6.0 - 0.02, y1, 0.006), "lantern_glass", false)
	Props.block(g, Vector3(-w * 0.5 - 0.1, sill - 0.04, -0.12), Vector3(w * 0.5 + 0.1, sill, 0.0), k_frame)


## A door leaf hung open beside an opening (w wide, `pos` the floor centre of the opening; the leaf swings `swing`
## degrees from closed about the hinge at local x = +w/2 on the face local z = `face`): planks or steel, a handle.
static func hung_door(parent: Node3D, pos: Vector3, yaw: float, w: float, h: float, swing: float, face: float, key: String = "planks") -> void:
	var g: Node3D = Props.group(parent, "HungDoor", pos, yaw)
	var hinge: Node3D = Props.group(g, "Hinge", Vector3(w * 0.5, 0, face), swing)
	Props.block(hinge, Vector3(-w + 0.04, 0.02, -0.025), Vector3(-0.02, h - 0.04, 0.025), key)
	for y: float in [0.25, h * 0.5, h - 0.35]:
		Props.block(hinge, Vector3(-w + 0.08, y - 0.05, -0.035), Vector3(-0.06, y + 0.05, 0.035), "beam" if key == "planks" else "iron")
	Props.block(hinge, Vector3(-w + 0.12, 1.0, -0.06), Vector3(-w + 0.18, 1.06, 0.06), "iron")
	for y2: float in [0.3, h - 0.3]:
		Props.block(g, Vector3(w * 0.5 - 0.02, y2 - 0.08, face - 0.04), Vector3(w * 0.5 + 0.04, y2 + 0.08, face + 0.04), "iron")


## Skirting and a cornice along a wall face from a to b (both on the face, same height), out towards `normal`.
static func trim_line(parent: Node3D, a: Vector3, b: Vector3, normal: Vector3, wall_h: float, k_skirt: String, k_cornice: String,
		skirt_h: float = 0.22, cornice: bool = true) -> void:
	var lo: Vector3 = Vector3(minf(a.x, b.x), a.y, minf(a.z, b.z))
	var hi: Vector3 = Vector3(maxf(a.x, b.x), a.y, maxf(a.z, b.z))
	var off: Vector3 = normal * 0.06
	var lo2: Vector3 = lo + Vector3(minf(off.x, 0.0), 0, minf(off.z, 0.0))
	var hi2: Vector3 = hi + Vector3(maxf(off.x, 0.0), 0, maxf(off.z, 0.0))
	Props.block(parent, lo2, hi2 + Vector3(0, skirt_h, 0), k_skirt)
	if cornice:
		var off2: Vector3 = normal * 0.14
		var lo3: Vector3 = lo + Vector3(minf(off2.x, 0.0), wall_h - 0.3, minf(off2.z, 0.0))
		var hi3: Vector3 = hi + Vector3(maxf(off2.x, 0.0), wall_h, maxf(off2.z, 0.0))
		Props.block(parent, lo3, hi3, k_cornice)


# ================================================================== life

## Falling drips: a small GPUParticles3D emitter over `box` (world AABB position + size of the ceiling area) that
## drops thin streaks at ~gravity. `amount` drops alive at once.
static func drips(parent: Node3D, center: Vector3, extent: Vector3, fall: float, amount: int = 14) -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.name = "Drips"
	p.position = center
	p.amount = amount
	p.lifetime = sqrt(2.0 * fall / 9.8) + 0.05
	p.preprocess = 2.0
	p.visibility_aabb = AABB(Vector3(-extent.x, -fall - 1.0, -extent.z), Vector3(extent.x * 2.0, fall + 2.0, extent.z * 2.0))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extent
	pm.direction = Vector3.DOWN
	pm.spread = 0.0
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.3
	pm.gravity = Vector3(0, -9.8, 0)
	p.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.012, 0.16)
	if _drip_mat == null:
		var sh: Shader = Shader.new()
		sh.code = DRIP_SHADER
		_drip_mat = ShaderMaterial.new()
		_drip_mat.shader = sh
	q.material = _drip_mat
	p.draw_pass_1 = q
	p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Y_TO_VELOCITY
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	return p


## A herring gull standing on a ledge, facing local -Z (body, head, beak, folded wings, legs).
static func gull(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var g: Node3D = Props.group(parent, "Gull", pos, yaw)
	Props.ball(g, Vector3(0, 0.16, 0.02), Vector3(0.13, 0.12, 0.26), "linen")
	Props.ball(g, Vector3(0, 0.27, -0.12), Vector3(0.08, 0.08, 0.09), "linen")
	Props.cone(g, Vector3(0, 0.26, -0.2), 0.016, 0.07, "yellow_paint", Vector3(-90, 0, 0))
	for sx: float in [-0.065, 0.065]:
		Props.ball(g, Vector3(sx, 0.18, 0.06), Vector3(0.05, 0.08, 0.26), "grey_paint")
		Props.block(g, Vector3(sx * 0.5 - 0.006, 0.0, -0.006), Vector3(sx * 0.5 + 0.006, 0.08, 0.006), "yellow_paint")
	Props.ball(g, Vector3(0, 0.18, 0.2), Vector3(0.06, 0.03, 0.1), "black_paint")


## The storm beyond the pen mouth: a big card with moving cloud bands that brightens with `flash` (the lightning
## node drives it), facing local -Z.
static func storm_card(parent: Node3D, pos: Vector3, size: Vector2, yaw: float = 180.0) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "StormCard"
	var q: QuadMesh = QuadMesh.new()
	q.size = size
	mi.mesh = q
	var sh: Shader = Shader.new()
	sh.code = STORM_SHADER
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = sh
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = deg_to_rad(yaw)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("keep", true)
	parent.add_child(mi)
	return mi


# ================================================================== UPDATE 10 (T-154): the living world's pieces

const RAIN_SHADER: String = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
uniform float intensity = 0.4;
float h11(float x) { return fract(sin(x * 91.7) * 43758.5453); }
void fragment() {
	float col = floor(UV.x * 90.0);
	float speed = 1.6 + h11(col) * 1.4;
	float y = fract(UV.y * 3.0 + TIME * speed + h11(col + 7.0));
	float streak = smoothstep(0.0, 0.08, y) * (1.0 - smoothstep(0.08, 0.35, y));
	float lane = 1.0 - smoothstep(0.0, 0.35, abs(fract(UV.x * 90.0) - 0.5));
	float a = streak * lane * step(0.55, h11(col + 3.1)) * intensity;
	ALBEDO = vec3(0.55, 0.62, 0.72) * a;
	ALPHA = a;
}
"""

static var _rain_mat: ShaderMaterial = null


## Rain streaking down a pane (the signal tower's embrasures): a card whose shader's `intensity` the living world
## raises with the storm (group m2_rain_glass).
static func rain_card(parent: Node3D, pos: Vector3, size: Vector2, yaw: float) -> MeshInstance3D:
	if _rain_mat == null:
		var sh: Shader = Shader.new()
		sh.code = RAIN_SHADER
		_rain_mat = ShaderMaterial.new()
		_rain_mat.shader = sh
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "RainGlass"
	var q: QuadMesh = QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = _rain_mat
	mi.position = pos
	mi.rotation.y = deg_to_rad(yaw)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("keep", true)
	mi.add_to_group(&"m2_rain_glass", true)
	parent.add_child(mi)
	return mi


## One mesh from a list of [mesh, transform] parts with one material (icicle clusters, the conveyor's cans).
static func merged(parts: Array, key: String) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for pr: Array in parts:
		st.append_from(pr[0] as Mesh, 0, pr[1] as Transform3D)
	var m: ArrayMesh = st.commit()
	m.surface_set_material(0, Mats.get_mat(key))
	return m


## A cluster of 2-4 icicles hanging from `pos` (tips down), one mesh, kept so it can fall in the raid. Meta
## floor_y = where it lands.
static func icicle_cluster(parent: Node3D, pos: Vector3, floor_y: float, seed_v: int) -> MeshInstance3D:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	var parts: Array = []
	for k: int in rng.randi_range(2, 4):
		var h: float = rng.randf_range(0.25, 0.85)
		var r: float = rng.randf_range(0.025, 0.06)
		var xf: Transform3D = Transform3D(Basis(Vector3.RIGHT, PI).scaled(Vector3(r * 2.0, h, r * 2.0)), Vector3(rng.randf_range(-0.25, 0.25), -h * 0.5, rng.randf_range(-0.06, 0.06)))
		parts.append([Props.unit_cone(), xf])
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Icicles"
	mi.mesh = merged(parts, "frosted")
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("floor_y", floor_y)
	parent.add_child(mi)
	return mi


## The cliff church: a nave and a square tower with an open belfry; the bell hangs from a kept pivot named
## `pivot_name` (the living world swings it in the wind and tolls it once). Facing local -Z.
static func cliff_church(parent: Node3D, pos: Vector3, yaw: float, pivot_name: String) -> Node3D:
	var g: Node3D = Props.group(parent, "CliffChurch", pos, yaw)
	Props.block(g, Vector3(-4.0, 0, 0), Vector3(4.0, 7.0, 16.0), "stucco")
	Props.prism(g, Vector3(0, 9.0, 8.0), Vector3(8.6, 4.0, 16.4), "roof")
	# the roof half gone at the east end: rafters against the sky
	for k: int in 5:
		Props.obox(g, Vector3(0, 8.4, 10.5 + k * 1.2), Vector3(8.4, 0.18, 0.18), "beam", Vector3(0, 0, 32.0 if k % 2 == 0 else -32.0))
	Props.block(g, Vector3(-2.6, 0, -5.2), Vector3(2.6, 14.0, 0.0), "stucco")
	for sx: float in [-2.6, 2.2]:   # the belfry's four corner piers and the open arches between them
		for sz: float in [-5.2, -0.4]:
			Props.block(g, Vector3(sx, 14.0, sz), Vector3(sx + 0.4, 17.4, sz + 0.4), "stucco")
	Props.block(g, Vector3(-2.7, 17.4, -5.3), Vector3(2.7, 17.9, 0.1), "stucco_trim")
	Props.cone(g, Vector3(0, 21.0, -2.6), 2.4, 6.2, "roof")
	Props.block(g, Vector3(-0.05, 24.1, -2.65), Vector3(0.05, 25.2, -2.55), "iron")
	for wy: float in [3.5, 9.0]:
		Props.block(g, Vector3(-0.5, wy, -5.22), Vector3(0.5, wy + 1.8, -5.2), "window_dark")
	var pv: Node3D = Node3D.new()
	pv.name = pivot_name
	pv.position = Vector3(0, 16.9, -2.6)
	pv.set_meta("keep", true)
	g.add_child(pv)
	Props.block(pv, Vector3(-0.05, -0.5, -0.05), Vector3(0.05, 0.0, 0.05), "iron")
	Props.bell(pv, Vector3(0, -1.75, 0), 1.3, "brass")
	Props.block(g, Vector3(-2.2, 16.85, -2.7), Vector3(2.2, 17.0, -2.5), "beam")
	return g


## A burnt-out house front on the cliff edge: a gable wall with empty windows, a broken top, charred beams.
static func ruined_facade(parent: Node3D, pos: Vector3, yaw: float, w: float, h: float, seed_v: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	var g: Node3D = Props.group(parent, "RuinedFacade", pos, yaw)
	Props.block(g, Vector3(-w * 0.5, 0, -0.3), Vector3(w * 0.5, h, 0.3), "stucco" if rng.randf() < 0.6 else "brick")
	# the gable, broken: a stepped ragged top
	var steps: int = 4
	for k: int in steps:
		var x0: float = -w * 0.5 + k * w / steps
		Props.block(g, Vector3(x0, h, -0.3), Vector3(x0 + w / steps, h + rng.randf_range(0.0, w * 0.35), 0.3), "stucco")
	for row: int in int(h / 3.2):
		for col: int in maxi(1, int(w / 2.6)):
			var x: float = -w * 0.5 + 1.0 + col * 2.6
			if x + 0.9 > w * 0.5:
				continue
			Props.block(g, Vector3(x, 1.2 + row * 3.2, -0.32), Vector3(x + 0.9, 2.6 + row * 3.2, -0.3), "window_dark")
	for k2: int in 2:
		Props.obox(g, Vector3(rng.randf_range(-w * 0.3, w * 0.3), h * 0.6, 1.2), Vector3(0.2, 0.2, rng.randf_range(2.0, 4.0)), "char", Vector3(rng.randf_range(-30, 30), 0, rng.randf_range(-40, 40)))


## The lighthouse at the end of the breakwater: a tapering white tower with red bands, the gallery, the lantern
## room. Returns the kept marker at the lamp's base the living world turns its beam on.
static func lighthouse(parent: Node3D, base: Vector3, height: float) -> Node3D:
	var g: Node3D = Props.group(parent, "LighthouseTower", base, 0.0)
	var segs: int = 6
	for k: int in segs:
		var y0: float = height * float(k) / segs
		var r0: float = lerpf(2.3, 1.5, float(k) / segs)
		var r1: float = lerpf(2.3, 1.5, float(k + 1) / segs)
		Props.cyl(g, Vector3(0, y0 + height / segs * 0.5, 0), (r0 + r1) * 0.5, height / segs, "red_paint" if k % 2 == 1 else "enamel_white")
	Props.cyl(g, Vector3(0, height + 0.1, 0), 2.1, 0.2, "iron")
	Props.railing(g, Vector3(-1.9, height + 0.2, -1.9), Vector3(1.9, height + 0.2, -1.9), 0.9, "iron", 0.6)
	Props.railing(g, Vector3(-1.9, height + 0.2, 1.9), Vector3(1.9, height + 0.2, 1.9), 0.9, "iron", 0.6)
	Props.cyl(g, Vector3(0, height + 1.3, 0), 1.15, 2.2, "glass")
	for k2: int in 6:
		var a: float = TAU * float(k2) / 6.0
		Props.block(g, Vector3(cos(a) * 1.15 - 0.04, height + 0.2, sin(a) * 1.15 - 0.04), Vector3(cos(a) * 1.15 + 0.04, height + 2.4, sin(a) * 1.15 + 0.04), "iron")
	Props.cone(g, Vector3(0, height + 2.9, 0), 1.35, 1.0, "red_paint")
	Props.block(g, Vector3(-0.5, 0.0, -2.35), Vector3(0.5, 2.1, -2.2), "planks")
	var mk: Node3D = Node3D.new()
	mk.name = "Lighthouse"
	mk.position = base
	mk.set_meta("keep", true)
	parent.add_child(mk)
	return mk


## A dockyard gantry crane in silhouette on the breakwater (black: the lightning backlights it).
static func gantry_crane(parent: Node3D, pos: Vector3, yaw: float, h: float, boom: float) -> void:
	var g: Node3D = Props.group(parent, "HarbourCrane", pos, yaw)
	for sx: float in [-2.5, 2.5]:
		for sz: float in [-2.0, 2.0]:
			Props.strut(g, Vector3(sx, 0, sz), Vector3(sx * 0.4, h, sz * 0.4), 0.35, "black_paint")
	for k: int in 4:
		var y: float = h * (0.2 + 0.2 * k)
		var s: float = lerpf(1.0, 0.4, y / h)
		Props.block(g, Vector3(-2.5 * s, y, -2.0 * s), Vector3(2.5 * s, y + 0.25, -2.0 * s + 0.25), "black_paint")
		Props.block(g, Vector3(-2.5 * s, y, 2.0 * s - 0.25), Vector3(2.5 * s, y + 0.25, 2.0 * s), "black_paint")
	Props.block(g, Vector3(-1.6, h, -1.4), Vector3(1.6, h + 2.4, 1.4), "black_paint")
	Props.strut(g, Vector3(0, h + 1.4, -1.0), Vector3(0, h + boom * 0.35, -boom), 0.5, "black_paint")
	Props.strut(g, Vector3(0, h + 2.4, 0.0), Vector3(0, h + 6.0, 1.6), 0.3, "black_paint")
	Props.cable(g, Vector3(0, h + 6.0, 1.6), Vector3(0, h + boom * 0.35, -boom), 0.0, 0.05, 2, "black_paint")
	Props.cable(g, Vector3(0, h + boom * 0.35, -boom), Vector3(0, h * 0.35, -boom), 0.0, 0.05, 2, "black_paint")


## A freighter burning on the horizon: a dark hull, the bridge and funnel, masts; the fire and its light are kept
## children of the returned marker (the living world flickers them).
static func burning_freighter(parent: Node3D, pos: Vector3, yaw: float, length: float) -> Node3D:
	var g: Node3D = Props.group(parent, "Freighter", pos, yaw)
	g.rotation.z = deg_to_rad(-6.0)
	Props.block(g, Vector3(-length * 0.5, -1.5, -4.0), Vector3(length * 0.5, 4.0, 4.0), "black_paint")
	Props.prism(g, Vector3(length * 0.5 + 3.0, 1.2, 0), Vector3(8.0, 5.6, 6.0), "black_paint", Vector3(0, 0, -90))
	Props.block(g, Vector3(length * 0.1, 4.0, -3.2), Vector3(length * 0.28, 9.5, 3.2), "loco_black")
	Props.cyl(g, Vector3(-length * 0.05, 9.0, 0), 1.4, 6.0, "loco_black")
	for mx: float in [length * 0.38, -length * 0.3]:
		Props.cyl(g, Vector3(mx, 10.0, 0), 0.25, 12.0, "loco_black")
	var mk: Node3D = Node3D.new()
	mk.name = "BurningFreighter"
	mk.position = pos
	mk.set_meta("keep", true)
	parent.add_child(mk)
	for fp: Vector3 in [Vector3(-length * 0.2, 4.5, 0), Vector3(length * 0.2, 9.0, 0)]:
		Props.flames(mk, fp.rotated(Vector3.UP, deg_to_rad(yaw)), 5.0, 6.0, 40)
		var l: OmniLight3D = OmniLight3D.new()
		l.name = "FireLight"
		l.position = fp.rotated(Vector3.UP, deg_to_rad(yaw)) + Vector3(0, 3, 0)
		l.light_color = Color(1.0, 0.5, 0.2)
		l.light_energy = 3.5
		l.omni_range = 45.0
		l.shadow_enabled = false
		l.light_volumetric_fog_energy = 2.0
		mk.add_child(l)
	Props.smoke(mk, Vector3(0, 14.0, 0), 6.0, 18.0, 30)
	return mk


## A destroyer's low silhouette with its searchlight marker on the bridge (the living world sweeps a beam).
static func destroyer(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var g: Node3D = Props.group(parent, "Destroyer", pos, yaw)
	Props.block(g, Vector3(-3.0, -1.0, -45.0), Vector3(3.0, 3.0, 45.0), "black_paint")
	Props.prism(g, Vector3(0, 1.5, -48.0), Vector3(6.0, 4.0, 7.0), "black_paint", Vector3(-90, 0, 0))
	Props.block(g, Vector3(-2.2, 3.0, -22.0), Vector3(2.2, 9.0, -12.0), "loco_black")
	for fz: float in [-4.0, 8.0]:
		Props.cyl(g, Vector3(0, 6.0, fz), 1.1, 6.0, "loco_black")
	Props.cyl(g, Vector3(0, 13.0, -16.0), 0.25, 10.0, "loco_black")
	var mk: Node3D = Node3D.new()
	mk.name = "DestroyerLight"
	mk.position = pos + Vector3(0, 10.0, -17.0).rotated(Vector3.UP, deg_to_rad(yaw))
	mk.set_meta("keep", true)
	parent.add_child(mk)
	return mk


## A caged pendant lamp on a long flex from the roof that swings (LampSway, group swing_lamps): the pivot at the
## roof, the shade and bulb as "LanternBody" (the light is paired by distance, so it swings with it).
static func swing_pendant(parent: Node3D, pos: Vector3, ceiling_y: float) -> Node3D:
	var drop: float = ceiling_y - pos.y
	var pivot: Node3D = Node3D.new()
	pivot.name = "PendantSwing"
	pivot.position = Vector3(pos.x, ceiling_y, pos.z)
	pivot.set_meta("keep", true)
	pivot.add_to_group(&"swing_lamps", true)
	parent.add_child(pivot)
	Props.block(pivot, Vector3(-0.012, -drop, -0.012), Vector3(0.012, 0.0, 0.012), "iron", false)
	var body: Node3D = Node3D.new()
	body.name = "LanternBody"
	body.position = Vector3(0, -drop, 0)
	pivot.add_child(body)
	Props.cone(body, Vector3(0, 0.12, 0), 0.36, 0.24, "enamel_green")
	Props.ball(body, Vector3(0, 0.0, 0), Vector3(0.14, 0.17, 0.14), "bulb_warm")
	return pivot


## A hanging chain from the roof with a pulley block and a hook at its foot (LampSway, group swing_chains).
static func hanging_chain(parent: Node3D, pos: Vector3, ceiling_y: float, seed_v: int) -> Node3D:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	var drop: float = ceiling_y - pos.y
	var pivot: Node3D = Node3D.new()
	pivot.name = "ChainSwing"
	pivot.position = Vector3(pos.x, ceiling_y, pos.z)
	pivot.set_meta("keep", true)
	pivot.add_to_group(&"swing_chains", true)
	parent.add_child(pivot)
	var parts: Array = []
	var links: int = int(drop / 0.12)
	for k: int in links:
		var y: float = -0.06 - k * 0.12
		var b: Basis = Basis(Vector3.UP, PI * 0.5 * (k % 2)) * Basis.from_scale(Vector3(0.05, 0.1, 0.015))
		parts.append([Props.unit_box(), Transform3D(b, Vector3(0, y, 0))])
	var chain: MeshInstance3D = MeshInstance3D.new()
	chain.name = "Chain"
	chain.mesh = merged(parts, "iron")
	chain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(chain)
	var blk: Node3D = Node3D.new()
	blk.name = "Block"
	blk.position = Vector3(0, -drop, 0)
	pivot.add_child(blk)
	Props.block(blk, Vector3(-0.14, -0.1, -0.07), Vector3(0.14, 0.32, 0.07), "rust")
	Props.cyl(blk, Vector3(0, 0.14, 0), 0.12, 0.16, "iron", Vector3(90, 0, 0))
	if rng.randf() < 0.7:
		Props.strut(blk, Vector3(0, -0.1, 0), Vector3(0, -0.32, 0), 0.04, "iron", true)
		Props.strut(blk, Vector3(0, -0.32, 0), Vector3(0.12, -0.45, 0), 0.035, "iron", true)
		Props.strut(blk, Vector3(0.12, -0.45, 0), Vector3(0.14, -0.33, 0), 0.03, "iron", true)
	return pivot


## A fish crate that spills (the living world tips "Box" and slides the "Fish*" children out): the crate on a
## kept group in group m2_fish_crates, full of herring and ice.
static func fish_crate(parent: Node3D, pos: Vector3, yaw: float, seed_v: int) -> Node3D:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	var g: Node3D = Node3D.new()
	g.name = "FishCrate"
	g.position = pos
	g.rotation.y = deg_to_rad(yaw)
	g.set_meta("keep", true)
	g.add_to_group(&"m2_fish_crates", true)
	parent.add_child(g)
	var box: Node3D = Node3D.new()
	box.name = "Box"
	box.position = Vector3(0, 0, 0.3)   # its pivot on the bottom edge it tips over
	g.add_child(box)
	Props.block(box, Vector3(-0.4, 0, -0.6), Vector3(0.4, 0.05, 0.0), "planks")
	for sx: float in [-0.4, 0.36]:
		Props.block(box, Vector3(sx, 0.05, -0.6), Vector3(sx + 0.04, 0.32, 0.0), "planks")
	for sz: float in [-0.6, -0.04]:
		Props.block(box, Vector3(-0.4, 0.05, sz), Vector3(0.4, 0.32, sz + 0.04), "planks")
	Props.stencil(box, Vector3(0, 0.2, 0.01), 0.0, "FISCH", 16, Color(0.15, 0.12, 0.1, 0.8))
	for k: int in 6:
		var f: Node3D = Node3D.new()
		f.name = "Fish%d" % k
		f.position = Vector3(rng.randf_range(-0.28, 0.28), 0.28, rng.randf_range(-0.25, 0.25))
		f.rotation.y = rng.randf_range(0, TAU)
		g.add_child(f)
		Props.ball(f, Vector3.ZERO, Vector3(0.07, 0.05, 0.26), "chrome_worn" if k % 3 != 2 else "frosted")
	return g


# ================================================================== T-273: the patrol boat moored off the quay

## T-273 (the map detail pass: "a landmark under open sky for the dive bomber"): a Vorpostenboot, a requisitioned steam
## trawler in navy grey, lying to two buoys off the quay, the thing the round-30 dive bomber comes down on. `pos` is the
## waterline amidships; local -Z is the bow, +X starboard, y 0 the waterline. A lofted steel hull (a raised forecastle
## with a sloped break, a cruiser stern with its transom), inner bulwarks and their cap, the decks; the bridge house,
## the wheelhouse and its wings, the raked funnel, two masts with stays, shrouds and the aerial, an 8.8 cm gun in its
## tub on the forecastle and a 2 cm on the stern, the fish hold's coaming, a winch, depth-charge rails, the ship's boat
## on its davits, the hull number, riding lamps (emissive, no light), the anchor cable and the two buoys with their
## lines, snow on the decks. The hull is one mesh per material (four); the rest are Props primitives the generator
## batches. Returns the fire group (a kept child of `parent`, hidden, its own visibility "ALL" so the view cells leave
## it alone): the ShermanEvent shows it when the bomb lands (map02.json sherman_event.stuka_hit_show).
static func patrol_boat(parent: Node3D, pos: Vector3, yaw: float, length: float = 34.0, beam: float = 7.0) -> Node3D:
	var g: Node3D = Props.group(parent, "PatrolBoat", pos, yaw)
	var hl: float = length * 0.5
	var hb: float = beam * 0.5
	var draft: float = 3.2
	var fc_u: float = 0.27            # the forecastle's break
	var fc_y: float = 2.9             # the forecastle deck
	var md_y: float = 1.3             # the main deck
	var bw: float = 0.12              # the bulwark's thickness
	var deck_y: Callable = func(u: float) -> float: return fc_y if u < fc_u else md_y
	var sheer: Callable = func(u: float) -> float:
		return md_y + 0.9 + (fc_y - md_y) * (1.0 - smoothstep(fc_u, fc_u + 0.04, u)) + 0.3 * (1.0 - smoothstep(0.0, 0.12, u)) + 0.2 * smoothstep(0.8, 1.0, u)
	var half_b: Callable = func(u: float) -> float:
		return maxf(0.04, hb * pow(smoothstep(0.0, 0.32, u), 0.55) * lerpf(1.0, 0.62, smoothstep(0.78, 1.0, u)))
	# a point on the starboard side: u along (0 bow .. 1 stern), t down the side (0 the sheer .. 1 the keel)
	var side_at: Callable = func(u: float, t: float) -> Vector3:
		var s: float = sheer.call(u)
		var y: float = lerpf(s, -draft, t)
		var x: float = (half_b.call(u) as float) * cos(pow(t, 1.8) * PI * 0.5)
		var z: float = -hl + u * length - 1.8 * clampf(1.0 - u / 0.1, 0.0, 1.0) * ((y + draft) / (s + draft))   # the raked stem
		return Vector3(x, y, z)
	var secs: int = 34
	var outward: Callable = func(p: Vector3) -> Vector3: return Vector3(0.0, p.y, p.z)
	var inward: Callable = func(p: Vector3) -> Vector3: return Vector3(p.x * 4.0, p.y, p.z)
	var upward: Callable = func(p: Vector3) -> Vector3: return p - Vector3.UP
	var tops: Array = []
	var reds: Array = []
	var greys: Array = []
	var decks: Array = []
	for side: float in [-1.0, 1.0]:
		var l_top: Array = []
		var l_red: Array = []
		var l_in: Array = []
		var l_cap: Array = []
		for s2: int in secs + 1:
			var u: float = float(s2) / float(secs)
			var sh: float = sheer.call(u)
			var tw: float = (sh + 0.35) / (sh + draft)   # the boot-top just under the waterline
			var a_top: PackedVector3Array = []
			var a_red: PackedVector3Array = []
			for k: int in 6:
				var p: Vector3 = side_at.call(u, tw * float(k) / 5.0)
				a_top.append(Vector3(p.x * side, p.y, p.z))
				var q: Vector3 = side_at.call(u, lerpf(tw, 1.0, float(k) / 5.0))
				a_red.append(Vector3(q.x * side, q.y, q.z))
			l_top.append(a_top)
			l_red.append(a_red)
			var e: Vector3 = side_at.call(u, 0.0)
			var xi: float = maxf(0.0, e.x - bw)
			var dy: float = deck_y.call(u)
			l_in.append(PackedVector3Array([Vector3(xi * side, sh, e.z), Vector3(xi * side, minf(dy, sh - 0.05), e.z)]))
			l_cap.append(PackedVector3Array([Vector3(e.x * side, sh, e.z), Vector3(xi * side, sh, e.z)]))
		tops.append([strip(l_top, outward), Transform3D.IDENTITY])
		reds.append([strip(l_red, outward), Transform3D.IDENTITY])
		greys.append([strip(l_in, inward, true), Transform3D.IDENTITY])
		greys.append([strip(l_cap, upward, true), Transform3D.IDENTITY])
	# the decks: the forecastle's and the main deck's, inside the bulwarks
	for part: Array in [[0.0, fc_u, fc_y], [fc_u - 0.03, 1.0, md_y]]:
		var ld: Array = []
		for s3: int in 13:
			var u3: float = lerpf(float(part[0]), float(part[1]), float(s3) / 12.0)
			var e3: Vector3 = side_at.call(u3, 0.0)
			var xi3: float = maxf(0.02, e3.x - bw)
			ld.append(PackedVector3Array([Vector3(-xi3, float(part[2]), e3.z), Vector3(xi3, float(part[2]), e3.z)]))
		decks.append([strip(ld, upward, true), Transform3D.IDENTITY])
	# the transom and the stem: each end section closed across, the topsides in grey and below the boot-top in red.
	# T-282: the transom was a fan down to the boot-top only (the stern section below it stood open) and the stem's
	# 8 cm between the two sides was never closed
	for end: Array in [[1.0, Vector3.BACK], [0.0, Vector3.FORWARD]]:
		var ue: float = float(end[0])
		var she: float = sheer.call(ue)
		var twe: float = (she + 0.35) / (she + draft)
		var r_top: PackedVector3Array = []
		var r_red: PackedVector3Array = []
		for k2: int in 6:
			r_top.append(side_at.call(ue, twe * float(k2) / 5.0))
			r_red.append(side_at.call(ue, lerpf(twe, 1.0, float(k2) / 5.0)))
		tops.append([section_cap(r_top, end[1] as Vector3), Transform3D.IDENTITY])
		reds.append([section_cap(r_red, end[1] as Vector3), Transform3D.IDENTITY])
	var shs: float = sheer.call(1.0)
	surface(g, "HullTopsides", merged(tops, "m2_hull"), "m2_hull")
	surface(g, "HullBottom", merged(reds, "m2_hull_red"), "m2_hull_red", false)
	surface(g, "HullBulwarks", merged(greys, "grey_paint"), "grey_paint")
	surface(g, "HullDecks", merged(decks, "m2_tread"), "m2_tread", false)
	var zu: Callable = func(u: float) -> float: return -hl + u * length
	# the forecastle's break: the bulkhead across, its door, two ladders up
	var zb: float = zu.call(fc_u)
	var bb: float = (half_b.call(fc_u) as float) - bw
	Props.block(g, Vector3(-bb, md_y, zb - 0.08), Vector3(bb, fc_y, zb + 0.06), "grey_paint")
	Props._noshadow(Props.block(g, Vector3(-0.45, md_y, zb + 0.06), Vector3(0.45, md_y + 1.45, zb + 0.08), "window_dark", false))
	for lx: float in [-1.6, 1.6]:
		Props.ladder(g, Vector3(lx, md_y, zb + 0.08), 180.0, fc_y - md_y + 0.9, "iron")
	# the bridge house, the boat deck over it, the wheelhouse with its windows and wings, the searchlight
	var hz0: float = zu.call(0.42)
	var hz1: float = zu.call(0.58)
	Props.block(g, Vector3(-2.3, md_y, hz0), Vector3(2.3, 3.5, hz1), "grey_paint")
	Props.block(g, Vector3(-2.6, 3.5, hz0 - 0.25), Vector3(2.6, 3.64, hz1 + 0.2), "m2_tread")
	for sx: float in [-1.0, 1.0]:
		for pz: float in [hz0 + 1.0, hz0 + 2.4, hz1 - 1.0]:
			Props._noshadow(Props.cyl(g, Vector3(sx * 2.31, 2.5, pz), 0.17, 0.03, "window_dark", Vector3(0, 0, 90)))
		Props._noshadow(Props.block(g, Vector3(sx * 2.3 - 0.01, md_y, hz0 + 3.3), Vector3(sx * 2.3 + 0.01, md_y + 1.8, hz0 + 4.0), "window_dark", false))
	var wz0: float = hz0 + 0.2
	var wz1: float = hz0 + 3.4
	Props.block(g, Vector3(-1.9, 3.64, wz0), Vector3(1.9, 5.6, wz1), "grey_paint")
	Props.block(g, Vector3(-2.1, 5.6, wz0 - 0.2), Vector3(2.1, 5.74, wz1 + 0.15), "grey_paint")
	for wx: float in [-1.25, 0.0, 1.25]:
		Props._noshadow(Props.block(g, Vector3(wx - 0.5, 4.45, wz0 - 0.02), Vector3(wx + 0.5, 5.25, wz0 - 0.01), "window_dark", false))
	for sx2: float in [-1.0, 1.0]:
		for wz: float in [wz0 + 0.8, wz0 + 2.1]:
			Props._noshadow(Props.block(g, Vector3(sx2 * 1.91 - 0.01, 4.45, wz - 0.45), Vector3(sx2 * 1.91 + 0.01, 5.25, wz + 0.45), "window_dark", false))
		# the wing: a grating out to the side with its rail
		Props.block(g, Vector3(minf(sx2 * 1.9, sx2 * 3.25), 3.6, wz0 - 0.1), Vector3(maxf(sx2 * 1.9, sx2 * 3.25), 3.66, wz0 + 1.3), "m2_tread")
		for ry: float in [4.1, 4.62]:
			Props._noshadow(Props.block(g, Vector3(sx2 * 3.22 - 0.025, ry, wz0 - 0.1), Vector3(sx2 * 3.22 + 0.025, ry + 0.04, wz0 + 1.3), "iron"))
		Props._noshadow(Props.block(g, Vector3(sx2 * 3.22 - 0.03, 3.66, wz0 + 1.25), Vector3(sx2 * 3.22 + 0.03, 4.66, wz0 + 1.3), "iron"))
	Props.cyl(g, Vector3(0, 5.95, wz0 + 0.9), 0.28, 0.4, "iron", Vector3(90, 0, 0))   # the searchlight
	Props._noshadow(Props.cyl(g, Vector3(0, 5.95, wz0 + 0.69), 0.24, 0.02, "bulb_off", Vector3(90, 0, 0)))
	# the funnel, raked aft, its black top and the steam pipe; two vents
	var fz: float = hz1 - 1.2
	Props.cyl(g, Vector3(0, 3.64 + 2.2, fz + 0.3), 0.85, 4.4, "grey_paint", Vector3(8, 0, 0))
	Props.cyl(g, Vector3(0, 3.64 + 4.2, fz + 0.6), 0.88, 0.6, "loco_black", Vector3(8, 0, 0))
	Props._noshadow(Props.cyl(g, Vector3(0.0, 3.64 + 2.6, fz + 1.2), 0.08, 5.0, "iron", Vector3(8, 0, 0)))
	for vx: float in [-1.6, 1.6]:
		Props.cyl(g, Vector3(vx, 4.2, fz + 0.4), 0.22, 1.1, "grey_paint")
		Props.cyl(g, Vector3(vx, 4.85, fz + 0.25), 0.3, 0.35, "grey_paint", Vector3(70, 0, 0))
	# the masts: the foremast on the forecastle with its yard and crow's nest, the mainmast aft with its gaff; stays,
	# shrouds and the aerial between the mastheads
	var fm: Vector3 = Vector3(0, fc_y, zu.call(0.2))
	var mm: Vector3 = Vector3(0, md_y, zu.call(0.82))
	Props.cyl(g, fm + Vector3(0, 5.0, 0), 0.14, 10.0, "grey_paint")
	Props.cyl(g, fm + Vector3(0, 6.6, 0), 0.5, 0.9, "grey_paint")
	Props.obox(g, fm + Vector3(0, 8.2, 0), Vector3(4.2, 0.12, 0.12), "grey_paint")
	Props.cyl(g, mm + Vector3(0, 4.0, 0), 0.11, 8.0, "grey_paint")
	Props.strut(g, mm + Vector3(0, 2.4, 0), mm + Vector3(0, 3.4, 3.2), 0.08, "grey_paint", true)
	var stem: Vector3 = side_at.call(0.0, 0.0)
	Props.cable(g, fm + Vector3(0, 9.9, 0), Vector3(0, stem.y + 0.1, stem.z + 0.2), 0.0, 0.015, 2, "iron")
	Props.cable(g, mm + Vector3(0, 7.9, 0), Vector3(0, shs + 0.05, hl - 0.3), 0.0, 0.015, 2, "iron")
	Props.cable(g, fm + Vector3(0, 9.7, 0), mm + Vector3(0, 7.7, 0), 0.35, 0.01, 10, "iron")
	for sx3: float in [-1.0, 1.0]:
		var e4: Vector3 = side_at.call(0.22, 0.0)
		Props.cable(g, fm + Vector3(0, 8.0, 0), Vector3(sx3 * (e4.x - 0.1), e4.y, e4.z + 0.8), 0.0, 0.012, 2, "iron")
		var e5: Vector3 = side_at.call(0.84, 0.0)
		Props.cable(g, mm + Vector3(0, 6.5, 0), Vector3(sx3 * (e5.x - 0.1), e5.y, e5.z), 0.0, 0.012, 2, "iron")
	# the 8.8 on the forecastle: the tub, the pedestal, the cradle, the shield and the barrel trained ahead
	var gz: float = zu.call(0.12)
	Props.cyl(g, Vector3(0, fc_y + 0.45, gz), 1.25, 0.9, "grey_paint")
	Props._noshadow(Props.cyl(g, Vector3(0, fc_y + 0.905, gz), 1.12, 0.02, "m2_tread"))
	Props.cyl(g, Vector3(0, fc_y + 1.25, gz), 0.32, 0.7, "grey_paint")
	Props.block(g, Vector3(-0.35, fc_y + 1.55, gz - 0.5), Vector3(0.35, fc_y + 1.95, gz + 0.7), "grey_paint")
	Props.obox(g, Vector3(0, fc_y + 1.95, gz - 0.62), Vector3(1.8, 1.2, 0.07), "grey_paint", Vector3(-8, 0, 0))
	var bdir: Vector3 = Vector3(0, sin(deg_to_rad(12.0)), -cos(deg_to_rad(12.0)))
	Props.cyl(g, Vector3(0, fc_y + 1.78, gz - 0.4) + bdir * 2.0, 0.075, 4.0, "grey_paint", Vector3(-78, 0, 0))
	# the 2 cm on the stern, its pedestal and the barrel up at the sky
	var sz: float = zu.call(0.9)
	Props.cyl(g, Vector3(0, md_y + 0.45, sz), 0.2, 0.9, "grey_paint")
	Props.block(g, Vector3(-0.2, md_y + 0.9, sz - 0.25), Vector3(0.2, md_y + 1.15, sz + 0.25), "grey_paint")
	Props.cyl(g, Vector3(0, md_y + 1.6, sz - 0.5), 0.035, 1.6, "iron", Vector3(-40, 0, 0))
	# the fish hold's coaming under its tarp, the winch, the depth-charge rails and their drums
	var cz2: float = zu.call(0.34)
	Props.block(g, Vector3(-1.4, md_y, cz2 - 1.1), Vector3(1.4, md_y + 0.45, cz2 + 1.1), "grey_paint")
	Props.block(g, Vector3(-1.45, md_y + 0.45, cz2 - 1.15), Vector3(1.45, md_y + 0.5, cz2 + 1.15), "tarp")
	Props.cyl(g, Vector3(0, md_y + 0.45, zu.call(0.39)), 0.35, 1.6, "iron", Vector3(0, 0, 90))
	for rx: float in [-1.6, 1.6]:
		Props.block(g, Vector3(rx - 0.05, md_y, zu.call(0.92)), Vector3(rx + 0.05, md_y + 0.1, hl - 0.4), "iron")
		for k4: int in 3:
			Props.cyl(g, Vector3(rx, md_y + 0.4, zu.call(0.93) + 0.75 * k4), 0.3, 0.6, "black_paint", Vector3(90, 0, 0))
	# the ship's boat on its davits over the starboard quarter (out over the sea, away from the quay)
	var bz: float = zu.call(0.7)
	for dz: float in [-1.6, 1.6]:
		Props.strut(g, Vector3(2.9, md_y + 0.9, bz + dz), Vector3(2.9, md_y + 2.9, bz + dz), 0.07, "grey_paint", true)
		Props.strut(g, Vector3(2.9, md_y + 2.9, bz + dz), Vector3(3.6, md_y + 3.1, bz + dz), 0.07, "grey_paint", true)
	Props.ball(g, Vector3(3.6, md_y + 1.9, bz), Vector3(1.3, 0.75, 4.2), "grey_paint")
	Props.block(g, Vector3(3.05, md_y + 2.1, bz - 1.7), Vector3(4.15, md_y + 2.16, bz + 1.7), "tarp")
	# the hull number on both bows, the riding lamps (red to port, green to starboard, white on the foremast)
	for sx4: float in [-1.0, 1.0]:
		var e6: Vector3 = side_at.call(0.1, 0.12)
		Props.stencil(g, Vector3(sx4 * (e6.x + 0.03), e6.y, e6.z), -90.0 * sx4, "V 1507", 90, Color(0.86, 0.86, 0.82, 0.85), 0.006)
	Props._noshadow(Props.block(g, Vector3(-2.75, 4.2, wz0 + 0.3), Vector3(-2.6, 4.4, wz0 + 0.5), "lamp_red_lit", false))
	Props._noshadow(Props.block(g, Vector3(2.6, 4.2, wz0 + 0.3), Vector3(2.75, 4.4, wz0 + 0.5), "lantern_glass", false))
	Props._noshadow(Props.block(g, fm + Vector3(-0.08, 7.3, -0.24), fm + Vector3(0.08, 7.5, -0.12), "lantern_glass", false))
	# snow on the forecastle, the boat deck and the wheelhouse roof, a patch in the waist
	Props._noshadow(Props.block(g, Vector3(-1.2, fc_y + 0.005, zu.call(0.15)), Vector3(1.4, fc_y + 0.05, zu.call(0.25)), "snow", false))
	Props._noshadow(Props.block(g, Vector3(-2.4, 3.64, hz0), Vector3(2.4, 3.69, hz0 + 0.5), "snow", false))
	Props._noshadow(Props.block(g, Vector3(-2.0, 5.74, wz0 - 0.1), Vector3(2.0, 5.8, wz1 + 0.05), "snow", false))
	Props._noshadow(Props.block(g, Vector3(-1.5, md_y + 0.005, zu.call(0.6)), Vector3(-0.4, md_y + 0.04, zu.call(0.68)), "snow", false))
	# the anchor at the port hawse and its cable out ahead; the lines to the two buoys, bow and stern
	var hawse: Vector3 = side_at.call(0.04, 0.15)
	Props.block(g, Vector3(-hawse.x - 0.05, hawse.y - 0.6, hawse.z - 0.1), Vector3(-hawse.x + 0.15, hawse.y + 0.1, hawse.z + 0.3), "iron")
	Props.cable(g, Vector3(-hawse.x + 0.05, hawse.y - 0.2, hawse.z), Vector3(-hawse.x - 2.5, -0.6, hawse.z - 7.0), 0.4, 0.05, 8, "iron")
	for b: Array in [[Vector3(0, 0, -hl - 9.0), Vector3(0, stem.y - 0.3, stem.z + 0.3)], [Vector3(-1.0, 0, hl + 8.0), Vector3(-0.8, shs - 0.2, hl - 0.2)]]:
		var buoy: Vector3 = b[0]
		Props.cyl(g, buoy + Vector3(0, 0.1, 0), 0.75, 1.3, "red_paint")
		Props._noshadow(Props.cyl(g, buoy + Vector3(0, 0.8, 0), 0.3, 0.1, "iron"))
		Props._noshadow(Props.block(g, buoy + Vector3(-0.04, 0.85, -0.04), buoy + Vector3(0.04, 1.15, 0.04), "iron"))
		Props.cable(g, b[1] as Vector3, buoy + Vector3(0, 0.95, 0), 0.9, 0.04, 10, "rope")
	# the fire the bomb starts: on the bridge, on the forecastle and in the waist; smoke; one light without a shadow
	var fire: Node3D = Node3D.new()
	fire.name = "MooredHullFire"
	fire.position = pos
	fire.rotation.y = deg_to_rad(yaw)
	fire.visible = false
	fire.set_meta("keep", true)
	fire.set_meta("vis", "ALL")
	parent.add_child(fire)
	Props.flames(fire, Vector3(0, 3.7, hz0 + 1.6), 3.0, 4.0, 40)
	Props.flames(fire, Vector3(0.4, fc_y + 0.3, zu.call(0.2)), 2.0, 2.4, 24)
	Props.flames(fire, Vector3(-0.8, md_y + 0.3, zu.call(0.62)), 1.6, 1.8, 18)
	Props.smoke(fire, Vector3(0, 9.0, hz0 + 1.0), 3.0, 16.0, 30)
	var fl: OmniLight3D = OmniLight3D.new()
	fl.name = "FireLight"
	fl.position = Vector3(0, 6.0, hz0 + 1.6)
	fl.light_color = Color(1.0, 0.5, 0.2)
	fl.light_energy = 3.0
	fl.omni_range = 30.0
	fl.shadow_enabled = false
	fl.light_volumetric_fog_energy = 1.5
	fire.add_child(fl)
	return fire
