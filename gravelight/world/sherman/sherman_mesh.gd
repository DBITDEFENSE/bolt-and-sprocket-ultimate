class_name ShermanMesh
extends RefCounted
## The Sherman (T-249, detailed in T-253; our own work, built in code): an American M4 medium tank of the winter of
## 1944, a welded hull with the sloped one-piece glacis, a cast turret with the 75 mm gun, vertical-volute bogies, a
## plain white star on the sponsons and the turret. Model space: the bow toward -Z, +X the tank's right, the ground at
## y 0. 5.9 m long over the hull (6.9 m to the muzzle), 2.62 m wide over the tracks, 2.74 m to the turret roof.
## Parts (each an ArrayMesh with a surface per material key, `material(key)`):
##   hull      the lower hull, the bolted three-piece final drive housing, the welded upper hull with its chamfered
##             plate edges and weld beads, applique plates, the glacis with its hatches, periscopes, bow machine gun,
##             headlights in their brush guards, the siren, the travel lock, spare track links, the engine deck with
##             its grilles and filler caps, the rear plate with the air cleaners, the doors and the exhaust deflector,
##             the stowage (a tarp roll, jerrycans, a crate, ammunition boxes, the pioneer tools, the tow cable), the
##             stars, snow lying in the corners; the bogie brackets, volute spring housings, arms and skids
##   turret    the cast turret (lofted), the rotor shield, the commander's cupola with its doors open, the loader's
##             hatch, periscopes, the vent, lifting rings, the antenna base and whip, the .50 calibre on its post,
##             spare links on the cheeks, bedrolls and a pack on the bustle, the stars
##   gun       the mantlet, the 75 mm barrel and the coaxial machine gun, about the trunnion (the gun pivot's origin)
##   wheel     a road wheel (a rubber tyre on a dished, ribbed steel disc), about its axle (X)
##   sprocket  the drive sprocket (two toothed rings on a drum, the hub), about its axle
##   idler     the idler wheel, about its axle
##   roller    a return roller, about its axle
##   link      one track link (+Z along the run, +Y outward from the wheels): the shoe, the end connectors with their
##             guide horns, the steel chevron
## Levels of detail (T-253): `<part>_detail` holds the small things (bolts, weld beads, handles, guards, clamps, the
## cable) and is drawn only near (DETAIL_RANGE); `wheel_far`, `link_far` ... are the plain shapes drawn beyond
## FAR_RANGE. `instance()` wires them as children with visibility ranges; `burn()` turns a built tank into the wreck.
## The running gear's places are constants (WHEELS, SPROCKET, IDLER, ROLLERS) and the track's path is `track_path()`.

const TRACK_X: float = 1.10
const TRACK_W: float = 0.42
const WHEEL_R: float = 0.254
const WHEEL_Y: float = 0.29
const BOGIES: Array[float] = [-1.62, -0.06, 1.50]
const WHEEL_DZ: float = 0.355
const SPROCKET: Vector3 = Vector3(0, 0.66, -2.62)   # (x per side)
const SPROCKET_R: float = 0.34
const IDLER: Vector3 = Vector3(0, 0.44, 2.66)
const IDLER_R: float = 0.29
const ROLLER_Y: float = 0.87
const ROLLER_R: float = 0.11
const ROLLER_DZ: float = 0.10
const LINK_PITCH: float = 0.152
const LINK_T: float = 0.045
const TURRET_AT: Vector3 = Vector3(0, 1.90, -0.30)   # the turret ring's centre on the hull roof
const GUN_AT: Vector3 = Vector3(0, 0.38, -0.92)      # the trunnion in the turret's frame
const GUN_LEN: float = 3.05
const MG50_AT: Vector3 = Vector3(0.40, 0.98, 0.70)   # the .50's muzzle base (turret frame)
const COAX_AT: Vector3 = Vector3(0.24, 0.02, -0.30)  # the coax's muzzle, gun frame
const BOW_MG_AT: Vector3 = Vector3(0.52, 1.62, -2.27)
const HEADLAMPS: Array[Vector3] = [Vector3(-0.98, 1.47, -2.70), Vector3(0.98, 1.47, -2.70)]   # the lenses (hull frame)

## T-253: how much of its own colour the paint gives back in the dark (the shader's night_lift; 0 = none: the tank
## is then only what the map's lamps and its own make of it). One number to turn by eye in a real window.
const NIGHT_LIFT: float = 3.2
const DETAIL_RANGE: float = 38.0   # the small parts are drawn within this
const FAR_RANGE: float = 48.0      # the wheels and links go plain beyond this

const OD: Color = Color(1, 1, 1)
const MUD: Color = Color(0.55, 0.46, 0.36)
const SNOW: Color = Color(0.92, 0.94, 0.98)
const RUST: Color = Color(0.9, 0.68, 0.55)

const PARTS: Array[String] = ["hull", "turret", "gun", "wheel", "sprocket", "idler", "roller", "link"]

static var _cache: Dictionary = {}
static var _mats: Dictionary = {}


## Road wheel centres on one side (x = 0; the caller puts them at ±TRACK_X).
static func wheel_centres() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for b: float in BOGIES:
		out.append(Vector3(0, WHEEL_Y, b - WHEEL_DZ))
		out.append(Vector3(0, WHEEL_Y, b + WHEEL_DZ))
	return out


static func roller_centres() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for b: float in BOGIES:
		out.append(Vector3(0, ROLLER_Y, b + ROLLER_DZ))
	return out


## The track's centre line in the side plane, as (z, y) points round the loop in order (going forward along the
## bottom run, up round the sprocket, back along the top, down round the idler), sampled every ~2 cm: the convex hull
## of the wheels' rims (a track hangs straight between them).
static func track_path() -> PackedVector2Array:
	if _cache.has("path"):
		return _cache["path"]
	var pts: PackedVector2Array = PackedVector2Array()
	var off: float = LINK_T * 0.5
	var circles: Array = [[Vector2(SPROCKET.z, SPROCKET.y), SPROCKET_R + 0.02 + off], [Vector2(IDLER.z, IDLER.y), IDLER_R + off]]
	for c: Vector3 in wheel_centres():
		circles.append([Vector2(c.z, c.y), WHEEL_R + off])
	for c2: Vector3 in roller_centres():
		circles.append([Vector2(c2.z, c2.y), ROLLER_R + off])
	for cc: Array in circles:
		for i: int in 72:
			var a: float = TAU * float(i) / 72.0
			pts.append(cc[0] + Vector2(cos(a), sin(a)) * float(cc[1]))
	var hull: PackedVector2Array = Geometry2D.convex_hull(pts)
	# resample evenly
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in hull.size() - 1:
		var a2: Vector2 = hull[i]
		var b2: Vector2 = hull[i + 1]
		var n: int = maxi(1, int(ceil(a2.distance_to(b2) / 0.02)))
		for k: int in n:
			out.append(a2.lerp(b2, float(k) / float(n)))
	_cache["path"] = out
	return out


static func path_length(path: PackedVector2Array) -> float:
	var l: float = 0.0
	for i: int in path.size():
		l += path[i].distance_to(path[(i + 1) % path.size()])
	return l


# ================================================================== materials

## The tank's materials (T-253: the vehicle paint shader, its weathering fixed to the part so nothing slides over a
## moving hull): olive drab with grime, rain streaks, chipped edges, frozen mud up from the tracks and snow on what
## faces the sky; a darker olive; the running gear's mud-caked olive; bare steel; the track; rubber; the white of the
## stars (worn through to the hull); wood, canvas, the periscopes' glass, brass, the lamps' lenses, lying snow; and
## the burnt versions for the wreck (`burnt` true).
static func material(key: String, burnt: bool = false) -> Material:
	var ck: String = key + ("#b" if burnt else "")
	if _mats.has(ck):
		return _mats[ck]
	var m: Material = null
	var p: Dictionary = {}
	match key:
		"od":
			p = {"tint": Color(0.235, 0.25, 0.145), "rough": 0.74, "metal": 0.12, "chips": 0.3, "grime": 0.55, "streaks": 0.4,
				"snow": 0.46, "mud": 0.85, "mud_y": Vector2(0.5, 1.3)}
		"od_dark":
			p = {"tint": Color(0.18, 0.19, 0.115), "rough": 0.7, "metal": 0.15, "chips": 0.38, "grime": 0.6, "streaks": 0.3,
				"snow": 0.46, "mud": 0.85, "mud_y": Vector2(0.5, 1.3)}
		"gear":
			p = {"tint": Color(0.225, 0.235, 0.14), "rough": 0.8, "metal": 0.12, "chips": 0.45, "grime": 0.7, "streaks": 0.0,
				"snow": 0.25, "mud": 0.5, "mud_y": Vector2(50.0, 51.0)}
		"gear_dark":
			p = {"tint": Color(0.16, 0.165, 0.105), "rough": 0.8, "metal": 0.15, "chips": 0.45, "grime": 0.7, "streaks": 0.0,
				"snow": 0.25, "mud": 0.62, "mud_y": Vector2(50.0, 51.0)}
		"steel":
			p = {"tint": Color(0.3, 0.285, 0.27), "rough": 0.48, "metal": 0.7, "chips": 0.35, "chip_color": Color(0.22, 0.13, 0.08),
				"grime": 0.6, "streaks": 0.2, "snow": 0.5, "bump": 0.45}
		"track":
			p = {"tint": Color(0.27, 0.25, 0.23), "rough": 0.55, "metal": 0.6, "chips": 0.5, "chip_color": Color(0.24, 0.12, 0.06),
				"grime": 0.7, "streaks": 0.0, "snow": 0.55, "mud": 0.7, "mud_y": Vector2(50.0, 51.0), "bump": 0.45, "tex_scale": 2.2}
		"rubber":
			p = {"tint": Color(0.055, 0.055, 0.055), "rough": 0.9, "metal": 0.0, "chips": 0.0, "grime": 0.3, "streaks": 0.0,
				"snow": 0.2, "mud": 0.38, "mud_y": Vector2(50.0, 51.0), "bump": 0.2}
		"white":
			p = {"tint": Color(0.8, 0.8, 0.76), "rough": 0.8, "metal": 0.0, "chips": 0.75, "chip_cut": 1.0, "grime": 0.75,
				"streaks": 0.5, "snow": 0.4, "bump": 0.2}
		"wood":
			p = {"tint": Color(0.36, 0.25, 0.14), "rough": 0.9, "metal": 0.0, "chips": 0.0, "grime": 0.7, "streaks": 0.3,
				"snow": 0.7, "bump": 0.6}
		"canvas":
			p = {"tint": Color(0.36, 0.34, 0.24), "rough": 0.95, "metal": 0.0, "chips": 0.0, "grime": 0.6, "streaks": 0.2,
				"snow": 0.75, "bump": 0.7, "tex_scale": 1.6}
		"glass":
			var g: StandardMaterial3D = StandardMaterial3D.new()
			g.albedo_color = Color(0.05, 0.07, 0.07)
			g.roughness = 0.08
			g.metallic = 0.4
			g.vertex_color_use_as_albedo = true
			m = g
		"brass":
			var b: StandardMaterial3D = StandardMaterial3D.new()
			b.albedo_color = Color(0.55, 0.42, 0.2)
			b.roughness = 0.4
			b.metallic = 0.8
			b.vertex_color_use_as_albedo = true
			m = b
		"lamp":
			var l: StandardMaterial3D = StandardMaterial3D.new()
			l.albedo_color = Color(0.9, 0.85, 0.7) if not burnt else Color(0.03, 0.03, 0.03)
			l.roughness = 0.15
			if not burnt:
				l.emission_enabled = true
				l.emission = Color(1.0, 0.86, 0.6)
				l.emission_energy_multiplier = 2.2
			m = l
		"snow":
			if burnt:
				# the snow is gone from a burning hull: nothing is drawn
				var gone: ShaderMaterial = ShaderMaterial.new()
				var sh: Shader = Shader.new()
				sh.code = "shader_type spatial;\nrender_mode unshaded;\nvoid vertex() { VERTEX = vec3(0.0); }\nvoid fragment() { discard; }\n"
				gone.shader = sh
				m = gone
			else:
				var s: StandardMaterial3D = StandardMaterial3D.new()
				s.albedo_color = Color(0.86, 0.9, 0.96)
				s.roughness = 0.82
				s.vertex_color_use_as_albedo = true
				m = s
		_:
			p = {"tint": Color(0.3, 0.3, 0.3)}
	if m == null:
		p["night_lift"] = NIGHT_LIFT * (0.5 if burnt else 1.0)
		if burnt:
			p["burnt"] = 1.0
			p["snow"] = 0.0
			p["mud"] = 0.0
			if key == "white":
				p["chips"] = 1.0
			if key == "rubber":
				p["tint"] = Color(0.02, 0.02, 0.02)
		m = ProcKit.paint_material(p)
	elif burnt and m is StandardMaterial3D and key != "glass" and key != "lamp":
		(m as StandardMaterial3D).albedo_color = Color(0.1, 0.09, 0.08)
		(m as StandardMaterial3D).roughness = 0.95
		(m as StandardMaterial3D).metallic = 0.1
	_mats[ck] = m
	return m


static func _dress(mi: MeshInstance3D, mk: Array, burnt: bool) -> void:
	mi.mesh = mk[0]
	var ks: Array = mk[1]
	for i: int in ks.size():
		mi.set_surface_override_material(i, material(str(ks[i]), burnt))


## A MeshInstance3D of part `name` with its materials, its near detail and its far shape as children (T-253).
static func instance(name: String, burnt: bool = false) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = name.capitalize().replace(" ", "")
	mi.set_meta("sherman_part", name)
	_dress(mi, part(name), burnt)
	if has_part(name + "_detail"):
		var d: MeshInstance3D = MeshInstance3D.new()
		d.name = "Detail"
		d.set_meta("sherman_part", name + "_detail")
		_dress(d, part(name + "_detail"), burnt)
		d.visibility_range_end = DETAIL_RANGE
		d.visibility_range_end_margin = 4.0
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(d)
	if has_part(name + "_far"):
		var f: MeshInstance3D = MeshInstance3D.new()
		f.name = "Far"
		f.set_meta("sherman_part", name + "_far")
		_dress(f, part(name + "_far"), burnt)
		f.visibility_range_begin = FAR_RANGE
		f.visibility_range_begin_margin = 4.0
		mi.visibility_range_end = FAR_RANGE
		mi.visibility_range_end_margin = 4.0
		mi.add_child(f)
	return mi


## Turns every part under `root` (built by `instance`) into the wreck's burnt materials.
static func burn(root: Node) -> void:
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		if not n.has_meta("sherman_part"):
			continue
		var mi: MeshInstance3D = n as MeshInstance3D
		var ks: Array = part(str(n.get_meta("sherman_part")))[1]
		for i: int in ks.size():
			mi.set_surface_override_material(i, material(str(ks[i]), true))


## Whether `name` is a part with something in it (a detail or far level that exists).
static func has_part(name: String) -> bool:
	var base: String = name.trim_suffix("_detail").trim_suffix("_far")
	if not PARTS.has(base):
		return false
	part(base)
	return _cache.has(name) and (_cache[name][0] as ArrayMesh).get_surface_count() > 0


static func part(name: String) -> Array:
	if not _cache.has(name):
		var base: String = name.trim_suffix("_detail").trim_suffix("_far")
		var k: ProcKit = ProcKit.new()
		var d: ProcKit = ProcKit.new()
		var f: ProcKit = ProcKit.new()
		match base:
			"hull":
				_hull(k, d)
			"turret":
				_turret(k, d)
			"gun":
				_gun(k, d)
			"wheel":
				_wheel(k, f)
			"sprocket":
				_sprocket(k, f)
			"idler":
				_idler(k, f)
			"roller":
				_roller(k, f)
			"link":
				_link(k, f)
		_cache[base] = k.commit()
		_cache[base + "_detail"] = d.commit()
		_cache[base + "_far"] = f.commit()
	return _cache[name]


# ================================================================== helpers

static func _wedge(k: ProcKit, key: String, t0: Vector3, t1: Vector3, b0: Vector3, b1: Vector3, c0: Vector3, c1: Vector3) -> void:
	## A sloped plate from the top edge t0-t1 down to b0-b1, closed by its sides down to c0-c1 (under the top edge).
	var mid: Vector3 = (t0 + t1 + b0 + b1 + c0 + c1) / 6.0
	var faces: Array = [[t0, t1, b1, b0], [b0, b1, c1, c0], [t0, b0, c0], [t1, c1, b1], [t0, c0, c1, t1]]
	for f: Array in faces:
		var c: Vector3 = Vector3.ZERO
		for p: Vector3 in f:
			c += p
		c /= float(f.size())
		var out: Vector3 = c - mid
		k.tri_facing(key, f[0], f[1], f[2], out)
		if f.size() == 4:
			k.tri_facing(key, f[0], f[2], f[3], out)


## The frame that lays a (z, y) side profile across the hull: the polygon's x is the hull's z, its y the hull's y,
## and it is pushed along the hull's x from `x`.
static func _side(x: float) -> Transform3D:
	return Transform3D(Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(1, 0, 0)), Vector3(x, 0, 0))


## A periscope: its housing, the glass toward `fwd`, the rain guard; its wire guard goes to the detail.
static func _periscope(k: ProcKit, d: ProcKit, at: Vector3, yaw: float = 0.0) -> void:
	var bs: Basis = Basis(Vector3.UP, yaw)
	k.bbox("od_dark", at + Vector3(0, 0.05, 0), Vector3(0.20, 0.10, 0.12), bs, 0.012)
	k.box("glass", at + bs * Vector3(0, 0.068, -0.062), Vector3(0.16, 0.05, 0.005), bs)
	k.bbox("od_dark", at + bs * Vector3(0, 0.112, 0.01), Vector3(0.22, 0.02, 0.16), bs, 0.006)
	d.uring("od_dark", at + bs * Vector3(-0.12, 0.0, -0.09), at + bs * Vector3(0.12, 0.0, -0.09), Vector3(0, 1, -0.25), 0.17, 0.008, 4)
	d.uring("od_dark", at + bs * Vector3(-0.12, 0.0, 0.08), at + bs * Vector3(0.12, 0.0, 0.08), Vector3(0, 1, 0.1), 0.16, 0.008, 4)


## A jerrycan standing at `at` (its base centre), turned `yaw`.
static func _jerrycan(k: ProcKit, d: ProcKit, at: Vector3, yaw: float) -> void:
	var bs: Basis = Basis(Vector3.UP, yaw)
	k.bbox("od", at + Vector3(0, 0.21, 0), Vector3(0.16, 0.42, 0.34), bs, 0.03)
	k.bbox("od", at + Vector3(0, 0.435, 0) + bs * Vector3(0, 0, 0.02), Vector3(0.14, 0.05, 0.24), bs, 0.02)
	k.cyl("od_dark", at + bs * Vector3(0, 0.44, -0.13), at + bs * Vector3(0, 0.50, -0.15), 0.028, 0.03, 8)
	for hx: float in [-0.045, 0.0, 0.045]:
		d.uring("od_dark", at + bs * Vector3(hx, 0.455, -0.04), at + bs * Vector3(hx, 0.455, 0.13), Vector3.UP, 0.045, 0.008, 4)
	# the pressed cross on each flank
	for sx: float in [-1.0, 1.0]:
		d.beam("od_dark", at + bs * Vector3(sx * 0.081, 0.08, -0.11), at + bs * Vector3(sx * 0.081, 0.34, 0.11), 0.006, 0.02)
		d.beam("od_dark", at + bs * Vector3(sx * 0.081, 0.34, -0.11), at + bs * Vector3(sx * 0.081, 0.08, 0.11), 0.006, 0.02)


## A spare track link lying flat in `bs` at `c` (its width along the frame's x, its pitch along z, the chevron up y).
static func _spare_link(k: ProcKit, c: Vector3, bs: Basis) -> void:
	var t0: Color = k.tint
	k.tint = RUST.lerp(Color.WHITE, 0.35)
	k.bbox("steel", c, Vector3(0.34, 0.034, 0.13), bs, 0.006)
	for s: float in [-1.0, 1.0]:
		k.box("steel", c + bs * Vector3(s * 0.185, 0, 0), Vector3(0.05, 0.045, 0.148), bs)
		k.box("steel", c + bs * Vector3(s * 0.08, 0.025, 0), Vector3(0.16, 0.02, 0.034), bs * Basis(Vector3.UP, s * 0.42))
	k.tint = t0


# ================================================================== the hull

static func _hull(k: ProcKit, d: ProcKit) -> void:
	for kk: ProcKit in [k, d]:
		kk.shade_y = Vector2(0.35, 1.25)
		kk.shade_k = Color(0.8, 0.77, 0.72)
	# the lower hull between the tracks, its belly
	k.block("od", Vector3(-0.86, 0.40, -2.45), Vector3(0.86, 1.03, 2.62))
	# the final drive housing: the rounded cast nose, across the bow, its ends drawn in
	var prof: Array[Vector2] = [Vector2(-2.80, 1.20), Vector2(-2.88, 1.13), Vector2(-2.94, 1.02), Vector2(-2.97, 0.90), Vector2(-2.96, 0.78),
		Vector2(-2.90, 0.64), Vector2(-2.80, 0.54), Vector2(-2.66, 0.46), Vector2(-2.45, 0.41), Vector2(-2.40, 1.20)]
	var pc: Vector2 = Vector2(-2.62, 0.84)
	var rings: Array = []
	for xs: Array in [[-0.985, 0.90], [-0.94, 0.985], [-0.88, 1.0], [0.88, 1.0], [0.94, 0.985], [0.985, 0.90]]:
		var r: PackedVector3Array = PackedVector3Array()
		for p: Vector2 in prof:
			var q: Vector2 = pc + (p - pc) * float(xs[1])
			r.append(Vector3(float(xs[0]), q.y, q.x))
		rings.append(r)
	k.loft("od", rings, true, true, true)
	# its bolted seams (three-piece housing): two raised flanges, a bolt through each stretch
	for x2: float in [-0.36, 0.36]:
		var fl: Array = []
		for dx: float in [-0.032, 0.032]:
			var r2: PackedVector3Array = PackedVector3Array()
			for i: int in 9:
				var q2: Vector2 = pc + (prof[i] - pc) * 1.035
				r2.append(Vector3(x2 + dx, q2.y, q2.x))
			fl.append(r2)
		k.loft("od_dark", fl, false, false, false)
		for i2: int in 8:
			var mid: Vector2 = (prof[i2] + prof[i2 + 1]) * 0.5
			var q3: Vector2 = pc + (mid - pc) * 1.035
			for sx: float in [-1.0, 1.0]:
				d.bolt("od_dark", Vector3(x2 + sx * 0.032, q3.y, q3.x), Vector3(sx, 0, 0), 0.016, 0.014)
	# the bolt strip that joins the housing to the glacis
	k.bbox("od_dark", Vector3(0, 1.205, -2.80), Vector3(1.96, 0.035, 0.09), Basis(Vector3.RIGHT, deg_to_rad(35.0)), 0.008)
	d.bolts("od_dark", Vector3(-0.92, 1.225, -2.815), Vector3(0.92, 1.225, -2.815), 17, Vector3(0, 0.82, -0.57), 0.016, 0.012)
	# the welded upper hull: the side profile (the glacis, the roof, the rear plate sloping out, the sponson floor)
	# pushed across, its side plates' rims chamfered
	var up: PackedVector2Array = PackedVector2Array([Vector2(-2.80, 1.20), Vector2(-1.80, 1.90), Vector2(2.62, 1.90), Vector2(2.78, 1.03), Vector2(-1.80, 1.03)])
	k.prism("od", up, _side(0.0), 1.31, 0.02)
	# weld beads where the plates meet
	var gn: Vector3 = Vector3(0, 1.0, -0.7).normalized()   # the glacis' outward normal
	d.tint = Color(0.8, 0.8, 0.78)
	d.weld("od_dark", Vector3(-1.29, 1.90, -1.80), Vector3(1.29, 1.90, -1.80), 0.014)
	d.weld("od_dark", Vector3(-1.29, 1.90, 2.62), Vector3(1.29, 1.90, 2.62), 0.014)
	for s: float in [-1.0, 1.0]:
		d.weld("od_dark", Vector3(s * 1.295, 1.895, -1.80), Vector3(s * 1.295, 1.20, -2.79), 0.013)
		d.weld("od_dark", Vector3(s * 1.295, 1.895, -1.78), Vector3(s * 1.295, 1.895, 2.60), 0.013)
		d.weld("od_dark", Vector3(s * 1.295, 1.89, 2.625), Vector3(s * 1.295, 1.05, 2.775), 0.013)
		d.weld("od_dark", Vector3(s * 1.31, 1.05, -1.80), Vector3(s * 1.31, 1.88, -1.80), 0.012)   # the glacis' side plate joint
	d.tint = Color.WHITE
	# the rear of the lower hull
	k.block("od", Vector3(-0.86, 0.55, 2.55), Vector3(0.86, 1.03, 2.78))
	for s0: float in [-1.0, 1.0]:
		# the sponson's lower strip (where the sand shields bolt on)
		k.bbox("od_dark", Vector3(s0 * 1.318, 1.055, 0.42), Vector3(0.02, 0.05, 4.36), Basis.IDENTITY, 0.005)
		d.bolts("od_dark", Vector3(s0 * 1.328, 1.055, -1.66), Vector3(s0 * 1.328, 1.055, 2.50), 19, Vector3(s0, 0, 0), 0.013, 0.01)
		# applique plates welded over the ammunition racks
		for az: float in [-1.15, 1.32]:
			k.bbox("od", Vector3(s0 * 1.322, 1.52, az), Vector3(0.026, 0.50, 0.74 if az < 0.0 else 0.62), Basis.IDENTITY, 0.008)
		# the fenders: a bent sheet over the sprocket, a flap behind the idler
		var fx: float = s0 * (TRACK_X + 0.005)
		var fh: float = TRACK_W * 0.5 + 0.025
		var sheet: PackedVector2Array = PackedVector2Array([Vector2(-2.40, 1.222), Vector2(-2.86, 1.222), Vector2(-3.05, 1.11), Vector2(-3.11, 0.98),
			Vector2(-3.095, 0.975), Vector2(-3.038, 1.10), Vector2(-2.855, 1.206), Vector2(-2.40, 1.206)])
		k.prism("od", sheet, _side(fx), fh, 0.0)
		k.beam("od_dark", Vector3(fx, 1.20, -2.84), Vector3(s0 * 0.99, 1.02, -2.9), 0.02, 0.03)   # its stay
		k.bbox("od", Vector3(fx, 1.015, 2.80), Vector3(fh * 2.0, 0.016, 0.38), Basis.IDENTITY, 0.004)
		k.bbox("od", Vector3(fx, 0.90, 3.0), Vector3(fh * 2.0, 0.24, 0.014), Basis(Vector3.RIGHT, deg_to_rad(-10.0)), 0.004)
	# the hull roof: the driver's and the co-driver's hatches (raised rings, doors, a periscope in each door and one ahead)
	for s2: float in [-1.0, 1.0]:
		var hc: Vector3 = Vector3(s2 * 0.55, 1.90, -1.30)
		k.lathe("od_dark", hc, Vector3.UP, PackedVector2Array([Vector2(0.345, 0.0), Vector2(0.345, 0.045), Vector2(0.32, 0.062), Vector2(0.0, 0.062)]), 22)
		k.lathe("od", hc, Vector3.UP, PackedVector2Array([Vector2(0.30, 0.062), Vector2(0.30, 0.088), Vector2(0.275, 0.102), Vector2(0.0, 0.102)]), 22)
		k.bbox("od_dark", hc + Vector3(s2 * 0.12, 0.13, 0.05), Vector3(0.15, 0.06, 0.10), Basis.IDENTITY, 0.01)   # the door's own periscope
		k.box("glass", hc + Vector3(s2 * 0.12, 0.135, -0.002), Vector3(0.11, 0.03, 0.005))
		for hz: float in [-0.09, 0.09]:
			k.bbox("od_dark", hc + Vector3(-s2 * 0.30, 0.075, hz), Vector3(0.10, 0.045, 0.05), Basis.IDENTITY, 0.008)   # the hinges
		d.uring("od_dark", hc + Vector3(-s2 * 0.05, 0.10, -0.16), hc + Vector3(-s2 * 0.05, 0.10, -0.02), Vector3.UP, 0.04, 0.008, 4)
		d.cyl("od_dark", hc + Vector3(-s2 * 0.36, 0.05, -0.2), hc + Vector3(-s2 * 0.36, 0.05, 0.2), 0.02, 0.02, 6)   # the lift spring's tube
		_periscope(k, d, Vector3(s2 * 0.55, 1.90, -1.72))
	# the ventilator dome between them, lifting eyes at the corners
	k.lathe("od_dark", Vector3(0, 1.90, -1.45), Vector3.UP, PackedVector2Array([Vector2(0.13, 0.0), Vector2(0.13, 0.03), Vector2(0.10, 0.07), Vector2(0.04, 0.085), Vector2(0.0, 0.085)]), 14)
	for c: Vector3 in [Vector3(-1.18, 1.90, -1.70), Vector3(1.18, 1.90, -1.70), Vector3(-1.18, 1.90, 2.50), Vector3(1.18, 1.90, 2.50)]:
		d.uring("od_dark", c + Vector3(0, 0, -0.07), c + Vector3(0, 0, 0.07), Vector3.UP, 0.085, 0.016, 5)
	# the glacis' fittings: the bow machine gun in its ball mount, the headlights and their brush guards, the siren, the
	# travel lock, the spare track links, the towing shackles on the nose
	var ball: Vector3 = BOW_MG_AT
	k.lathe("od_dark", ball - gn * 0.02, gn, PackedVector2Array([Vector2(0.17, 0.0), Vector2(0.17, 0.05), Vector2(0.15, 0.08), Vector2(0.0, 0.08)]), 16)
	k.lathe("od", ball + gn * 0.06, gn, PackedVector2Array([Vector2(0.125, 0.0), Vector2(0.11, 0.05), Vector2(0.07, 0.085), Vector2(0.0, 0.095)]), 14)
	k.cyl("steel", ball + gn * 0.10, ball + Vector3(0, -0.02, -0.34), 0.027, 0.025, 8)
	k.cyl("steel", ball + Vector3(0, -0.02, -0.34), ball + Vector3(0, -0.023, -0.44), 0.016, 0.016, 6)
	d.bolts("od_dark", ball + Vector3(-0.2, 0.0, 0.0) + gn * 0.0, ball + Vector3(0.2, 0.0, 0.0), 2, gn, 0.016, 0.012)
	for s3: float in [-1.0, 1.0]:
		var hl: Vector3 = Vector3(s3 * 0.98, 1.36, -2.62)
		k.cyl("od_dark", hl, hl + gn * 0.10, 0.03, 0.03, 6)
		var lens: Vector3 = Vector3(s3 * 0.98, 1.47, -2.70)
		k.lathe("od_dark", lens + Vector3(0, 0, 0.19), Vector3(0, 0, -1), PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.05, 0.02), Vector2(0.082, 0.08),
			Vector2(0.09, 0.17), Vector2(0.095, 0.19), Vector2(0.08, 0.19)]), 14)
		k.cyl("lamp", lens + Vector3(0, 0, 0.004), lens + Vector3(0, 0, -0.002), 0.08, 0.075, 14)
		# the guard: a U of flat bar round the lamp, a cross bar
		var g0: Vector3 = hl + Vector3(-0.14, -0.04, 0.08)
		var g1: Vector3 = hl + Vector3(0.14, -0.04, 0.08)
		var top: float = 0.30
		k.beam("od", g0, g0 + Vector3(0, top, -0.22), 0.012, 0.03)
		k.beam("od", g1, g1 + Vector3(0, top, -0.22), 0.012, 0.03)
		k.beam("od", g0 + Vector3(0, top, -0.22), g1 + Vector3(0, top, -0.22), 0.03, 0.012)
		k.beam("od", g0 + Vector3(0, top * 0.5, -0.11), g1 + Vector3(0, top * 0.5, -0.11), 0.03, 0.012)
		# the towing shackles on the nose
		var sh: Vector3 = Vector3(s3 * 0.62, 0.66, -2.95)
		k.ring("steel", sh + Vector3(-0.03, 0, 0), sh + Vector3(0.03, 0, 0), 0.085, 0.045, 12)
		k.bblock("od_dark", sh + Vector3(-0.06, 0.06, 0.02), sh + Vector3(0.06, 0.16, 0.12), 0.012)
	# the siren on the left of the glacis, in its guard
	var si: Vector3 = Vector3(-0.60, 1.50, -2.40) + gn * 0.07
	k.lathe("od_dark", si + Vector3(0, 0, 0.09), Vector3(0, 0, -1), PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.06, 0.01), Vector2(0.07, 0.10), Vector2(0.085, 0.17), Vector2(0.06, 0.17)]), 12)
	k.cyl("od_dark", si - gn * 0.07, si, 0.025, 0.025, 6)
	d.uring("od_dark", si + Vector3(-0.1, -0.05, -0.02), si + Vector3(0.1, -0.05, -0.02), Vector3(0, 0.6, -0.5), 0.2, 0.008, 4)
	# the gun's travel lock, folded down on the glacis
	var tl: Vector3 = Vector3(0, 1.76, -2.0)
	for s4: float in [-1.0, 1.0]:
		k.beam("od_dark", tl + Vector3(s4 * 0.2, 0, 0) + gn * 0.025, tl + Vector3(s4 * 0.07, -0.30, -0.43) + gn * 0.03, 0.03, 0.02)
		k.bbox("od_dark", tl + Vector3(s4 * 0.2, 0, 0) + gn * 0.02, Vector3(0.06, 0.05, 0.07), Basis(Vector3.RIGHT, deg_to_rad(35.0)), 0.008)
	k.bbox("od_dark", tl + Vector3(0, -0.31, -0.445) + gn * 0.04, Vector3(0.2, 0.05, 0.06), Basis(Vector3.RIGHT, deg_to_rad(35.0)), 0.01)
	# spare track links hung across the lower glacis (three, on their bar)
	var lb: Vector3 = Vector3(0, 1.36, -2.56)
	k.beam("steel", lb + Vector3(-0.74, 0.115, -0.085), lb + Vector3(0.74, 0.115, -0.085), 0.025)
	var lbas: Basis = Basis(Vector3.RIGHT, -deg_to_rad(55.0))
	for i3: int in 3:
		_spare_link(k, lb + Vector3(-0.52 + 0.52 * float(i3), 0.0, 0.0) + gn * 0.012, lbas)
	# the engine deck: two grille doors with their slats and handles, the centre plate, the filler caps
	for s5: float in [-1.0, 1.0]:
		var ga: float = s5 * 0.10
		var gb: float = s5 * 1.05
		k.bblock("od_dark", Vector3(minf(ga, gb), 1.90, 0.95), Vector3(maxf(ga, gb), 1.925, 2.35), 0.008)
		for j: int in 11:
			var gz: float = 1.01 + 0.122 * float(j)
			k.box("od", Vector3((ga + gb) * 0.5, 1.94, gz + 0.03), Vector3(absf(gb - ga) - 0.14, 0.035, 0.012), Basis(Vector3.RIGHT, deg_to_rad(-35.0)))
		d.uring("od_dark", Vector3(s5 * 0.30, 1.925, 0.99), Vector3(s5 * 0.46, 1.925, 0.99), Vector3.UP, 0.04, 0.008, 4)
		d.bolts("od_dark", Vector3(s5 * 0.14, 1.925, 0.975), Vector3(s5 * 0.14, 1.925, 2.32), 6, Vector3.UP, 0.012, 0.008)
		for fc: Vector3 in [Vector3(s5 * 1.0, 1.90, 0.55), Vector3(s5 * 0.42, 1.90, 0.70)]:
			k.lathe("od_dark", fc, Vector3.UP, PackedVector2Array([Vector2(0.075, 0.0), Vector2(0.075, 0.03), Vector2(0.06, 0.045), Vector2(0.0, 0.045)]), 10)
	k.bblock("od", Vector3(-0.10, 1.90, 0.95), Vector3(0.10, 1.915, 2.35), 0.004)
	d.bolts("od_dark", Vector3(0, 1.915, 1.0), Vector3(0, 1.915, 2.3), 8, Vector3.UP, 0.012, 0.008)
	# the rear plate: the two air cleaners, the tail lights, the engine doors, the towing pintle and shackles, the
	# exhaust deflector's slats
	for s6: float in [-1.0, 1.0]:
		var ac: Vector3 = Vector3(s6 * 0.62, 1.28, 2.76)
		var av: Vector3 = Vector3(0, 0.56, -0.05).normalized()
		k.lathe("od_dark", ac, av, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.12, 0.0), Vector2(0.135, 0.02), Vector2(0.135, 0.46), Vector2(0.145, 0.47),
			Vector2(0.145, 0.50), Vector2(0.10, 0.56), Vector2(0.0, 0.57)]), 14)
		d.lathe("steel", ac + av * 0.16, av, PackedVector2Array([Vector2(0.138, 0.0), Vector2(0.142, 0.0), Vector2(0.142, 0.03), Vector2(0.138, 0.03)]), 12)
		d.lathe("steel", ac + av * 0.36, av, PackedVector2Array([Vector2(0.138, 0.0), Vector2(0.142, 0.0), Vector2(0.142, 0.03), Vector2(0.138, 0.03)]), 12)
		k.cyl("od_dark", ac + av * 0.3 + Vector3(-s6 * 0.12, 0, 0), ac + av * 0.3 + Vector3(-s6 * 0.3, 0.02, -0.08), 0.045, 0.045, 8)
		k.bbox("od_dark", Vector3(s6 * 1.10, 1.70, 2.665), Vector3(0.12, 0.10, 0.07), Basis.IDENTITY, 0.012)
		k.box("glass", Vector3(s6 * 1.10, 1.70, 2.703), Vector3(0.07, 0.05, 0.005))
		d.uring("od_dark", Vector3(s6 * 1.10 - 0.08, 1.64, 2.66), Vector3(s6 * 1.10 + 0.08, 1.64, 2.66), Vector3(0, 0.75, 0.6), 0.16, 0.008, 4)
		# an engine door, its hinge and handle
		k.bbox("od", Vector3(s6 * 0.36, 0.80, 2.785), Vector3(0.66, 0.40, 0.02), Basis.IDENTITY, 0.008)
		d.uring("od_dark", Vector3(s6 * 0.14, 0.76, 2.795), Vector3(s6 * 0.14, 0.86, 2.795), Vector3(0, 0, 1), 0.04, 0.008, 4)
		for hy: float in [0.68, 0.92]:
			k.bbox("od_dark", Vector3(s6 * 0.70, hy, 2.79), Vector3(0.07, 0.04, 0.03), Basis.IDENTITY, 0.006)
		var rs: Vector3 = Vector3(s6 * 0.62, 0.50, 2.80)
		k.ring("steel", rs + Vector3(-0.03, -0.04, 0.06), rs + Vector3(0.03, -0.04, 0.06), 0.08, 0.042, 10)
		k.bblock("od_dark", rs + Vector3(-0.05, -0.02, -0.03), rs + Vector3(0.05, 0.07, 0.05), 0.01)
	k.bblock("od_dark", Vector3(-0.9, 0.985, 2.78), Vector3(0.9, 1.01, 3.06), 0.006)
	for j2: int in 5:
		var dz: float = 2.82 + 0.052 * float(j2)
		k.box("od_dark", Vector3(0, 0.90 - 0.055 * float(j2), dz + 0.02), Vector3(1.78, 0.012, 0.085), Basis(Vector3.RIGHT, deg_to_rad(38.0)))
	for sx2: float in [-0.9, 0.9]:
		k.prism("od_dark", PackedVector2Array([Vector2(2.78, 1.0), Vector2(3.06, 1.0), Vector2(3.06, 0.9), Vector2(2.78, 0.62)]), _side(sx2), 0.012, 0.0)
	k.cyl("steel", Vector3(0, 0.56, 2.78), Vector3(0, 0.56, 2.92), 0.05, 0.05, 10)
	k.ring("steel", Vector3(0, 0.50, 2.90), Vector3(0, 0.62, 2.90), 0.08, 0.045, 12)
	# the stowage: a tarp roll on the deck's back edge, jerrycans, a crate, ammunition boxes, the pioneer tools, the cable
	k.tint = Color(1, 1, 1)
	k.blob("canvas", Vector3(0, 2.06, 2.47), Vector3(0.15, 1.04, 0.165), Basis(Vector3.BACK, PI * 0.5), 0.07, 7, 10, 9, 0.25, 6.0, 0.72)
	k.tint = Color(0.6, 0.55, 0.45)
	for sx3: float in [-0.75, 0.0, 0.75]:
		k.bbox("canvas", Vector3(sx3, 2.045, 2.47), Vector3(0.045, 0.30, 0.335), Basis.IDENTITY, 0.03)   # its straps
	k.tint = Color.WHITE
	_jerrycan(k, d, Vector3(-0.86, 1.945, 1.88), 0.06)
	_jerrycan(k, d, Vector3(-0.67, 1.945, 1.89), -0.04)
	_jerrycan(k, d, Vector3(-0.48, 1.945, 1.87), 0.1)
	k.beam("od_dark", Vector3(-0.97, 2.20, 1.70), Vector3(-0.37, 2.20, 1.70), 0.012, 0.03)   # the rack's strap
	# a wooden crate, lashed down
	var cb: Basis = Basis(Vector3.UP, 0.12)
	k.bbox("wood", Vector3(0.62, 2.075, 1.86), Vector3(0.58, 0.26, 0.38), cb, 0.008)
	for cy: float in [2.01, 2.10]:
		d.bbox("wood", Vector3(0.62, cy, 1.86), Vector3(0.59, 0.006, 0.39), cb, 0.0)
	d.tint = Color(0.55, 0.5, 0.42)
	for cx: float in [-0.2, 0.2]:
		d.bbox("canvas", Vector3(0.62, 2.08, 1.86) + cb * Vector3(cx, 0, 0), Vector3(0.035, 0.275, 0.395), cb, 0.004)
	d.tint = Color.WHITE
	for ab: Array in [[Vector3(0.36, 2.03, 1.36), 0.3], [Vector3(0.70, 2.03, 1.33), -0.1]]:
		var abs_: Basis = Basis(Vector3.UP, float(ab[1]))
		k.bbox("od_dark", ab[0], Vector3(0.28, 0.17, 0.15), abs_, 0.008)
		k.bbox("od_dark", (ab[0] as Vector3) + Vector3(0, 0.09, 0), Vector3(0.29, 0.02, 0.16), abs_, 0.005)
		d.uring("od_dark", (ab[0] as Vector3) + abs_ * Vector3(-0.06, 0.1, 0), (ab[0] as Vector3) + abs_ * Vector3(0.06, 0.1, 0), Vector3.UP, 0.025, 0.006, 4)
	for s7: float in [-1.0, 1.0]:
		var bx: float = s7 * 1.22
		k.cyl("wood", Vector3(bx, 1.925, -0.9), Vector3(bx, 1.925, 0.45), 0.02, 0.022, 6)               # the axe's helve
		k.prism("steel", PackedVector2Array([Vector2(-1.03, 1.91), Vector2(-0.86, 1.91), Vector2(-0.88, 1.945), Vector2(-1.03, 1.93)]), _side(bx - s7 * 0.02), 0.07, 0.004)
		k.cyl("wood", Vector3(bx - s7 * 0.09, 1.922, 0.55), Vector3(bx - s7 * 0.09, 1.922, 1.52), 0.018, 0.018, 6)   # the shovel
		k.bbox("steel", Vector3(bx - s7 * 0.09, 1.915, 1.67), Vector3(0.19, 0.012, 0.28), Basis.IDENTITY, 0.004)
		for cz: float in [-0.55, 0.2, 0.8, 1.35]:
			d.bbox("od_dark", Vector3(bx - (s7 * 0.09 if cz > 0.5 else 0.0), 1.925, cz), Vector3(0.06, 0.055, 0.03), Basis.IDENTITY, 0.004)   # the clamps
	k.cyl("steel", Vector3(1.06, 1.925, -1.2), Vector3(1.06, 1.925, 0.2), 0.014, 0.014, 5)   # the crowbar
	k.cyl("wood", Vector3(-1.06, 1.925, -1.15), Vector3(-1.06, 1.925, -0.35), 0.018, 0.018, 6)   # the sledge
	k.bbox("steel", Vector3(-1.06, 1.94, -1.2), Vector3(0.16, 0.06, 0.07), Basis.IDENTITY, 0.008)
	# the tow cable in its clips along the left side, an eye at each end
	var cable: PackedVector3Array = PackedVector3Array()
	cable.append(Vector3(-1.06, 1.42, -2.50) + gn * 0.03)
	cable.append(Vector3(-1.18, 1.62, -2.21) + gn * 0.03)
	cable.append(Vector3(-1.27, 1.80, -1.94) + gn * 0.025)
	cable.append(Vector3(-1.332, 1.86, -1.74))
	for ci: int in 13:
		var cz2: float = -1.5 + 0.33 * float(ci)
		cable.append(Vector3(-1.332, 1.86 - (0.022 if ci % 3 != 0 else 0.0), cz2))
	cable.append(Vector3(-1.325, 1.82, 2.58))
	cable.append(Vector3(-1.2, 1.70, 2.70))
	d.tube("steel", cable, 0.013, 5, false, true)
	d.ring("steel", cable[0] - gn * 0.012 + Vector3(0.0, -0.05, -0.07), cable[0] + gn * 0.012 + Vector3(0.0, -0.05, -0.07), 0.05, 0.028, 8)
	for ci2: int in 5:
		d.bbox("od_dark", Vector3(-1.325, 1.86, -1.5 + 0.99 * float(ci2)), Vector3(0.04, 0.06, 0.035), Basis.IDENTITY, 0.004)
	# the stars: on each sponson's side and the glacis, worn
	for s8: float in [-1.0, 1.0]:
		k.star("white", Vector3(s8 * 1.3125, 1.46, 0.35), Vector3(s8, 0, 0), Vector3.UP, 0.34)
	k.star("white", Vector3(-0.62, 1.58, -2.23) + gn * 0.004, gn, Vector3(0, 0.7, 1.0).normalized(), 0.22)
	# the running gear's fixed parts: the bogie brackets bolted to the hull side, the volute spring housings, the arms,
	# the skids, the return rollers' arms; the final drives' housings and the idlers' brackets
	for s9: float in [-1.0, 1.0]:
		var tx: float = s9 * TRACK_X
		for b: float in BOGIES:
			k.bblock("od", Vector3(minf(s9 * 0.86, tx - s9 * 0.14), 0.52, b - 0.22), Vector3(maxf(s9 * 0.86, tx - s9 * 0.14), 0.86, b + 0.22), 0.012)
			# the cast bracket, inboard of the wheels, and its outer cap
			k.prism("od_dark", PackedVector2Array([Vector2(b - 0.20, 0.42), Vector2(b + 0.20, 0.42), Vector2(b + 0.14, 0.88), Vector2(b - 0.14, 0.88)]),
				_side(tx - s9 * 0.155), 0.03, 0.01)
			k.prism("od_dark", PackedVector2Array([Vector2(b - 0.13, 0.46), Vector2(b + 0.13, 0.46), Vector2(b + 0.10, 0.82), Vector2(b - 0.10, 0.82)]),
				_side(tx + s9 * 0.15), 0.022, 0.01)
			d.bolts("od_dark", Vector3(tx + s9 * 0.172, 0.52, b - 0.07), Vector3(tx + s9 * 0.172, 0.52, b + 0.07), 2, Vector3(s9, 0, 0), 0.016, 0.012)
			d.bolts("od_dark", Vector3(tx + s9 * 0.172, 0.76, b - 0.06), Vector3(tx + s9 * 0.172, 0.76, b + 0.06), 2, Vector3(s9, 0, 0), 0.016, 0.012)
			k.cyl("od_dark", Vector3(tx - s9 * 0.16, 0.62, b - 0.07), Vector3(tx + s9 * 0.16, 0.62, b - 0.07), 0.07, 0.07, 10)   # the volute springs' housing
			k.cyl("od_dark", Vector3(tx - s9 * 0.16, 0.62, b + 0.07), Vector3(tx + s9 * 0.16, 0.62, b + 0.07), 0.07, 0.07, 10)
			for dz2: float in [-WHEEL_DZ, WHEEL_DZ]:
				for ax: float in [-0.15, 0.15]:
					k.beam("od", Vector3(tx + ax, 0.56, b + dz2 * 0.22), Vector3(tx + ax, WHEEL_Y, b + dz2), 0.03, 0.10)
				k.cyl("od_dark", Vector3(tx - 0.17, WHEEL_Y, b + dz2), Vector3(tx + 0.17, WHEEL_Y, b + dz2), 0.035, 0.035, 8)   # the axle
			# the skid on top, its ends turned down
			k.prism("od_dark", PackedVector2Array([Vector2(b - 0.27, 0.885), Vector2(b - 0.21, 0.925), Vector2(b - 0.01, 0.925), Vector2(b + 0.03, 0.885),
				Vector2(b + 0.02, 0.875), Vector2(b - 0.26, 0.875)]), _side(tx), 0.13, 0.0)
			k.beam("od", Vector3(tx - s9 * 0.15, 0.82, b + ROLLER_DZ - 0.04), Vector3(tx - s9 * 0.15, ROLLER_Y, b + ROLLER_DZ), 0.03, 0.07)
			k.cyl("od_dark", Vector3(tx - s9 * 0.17, ROLLER_Y, b + ROLLER_DZ), Vector3(tx + s9 * 0.12, ROLLER_Y, b + ROLLER_DZ), 0.025, 0.025, 6)
		# the final drive: the housing the sprocket turns on, its bolt circle
		k.lathe("od_dark", Vector3(s9 * 0.90, SPROCKET.y, SPROCKET.z), Vector3(s9, 0, 0), PackedVector2Array([Vector2(0.27, 0.0), Vector2(0.27, 0.05), Vector2(0.22, 0.09),
			Vector2(0.20, 0.17)]), 16)
		for bi: int in 10:
			var ba: float = TAU * float(bi) / 10.0
			d.bolt("od_dark", Vector3(s9 * 0.95, SPROCKET.y + cos(ba) * 0.245, SPROCKET.z + sin(ba) * 0.245), Vector3(s9, 0, 0), 0.014, 0.012)
		# the idler's bracket and its adjuster
		k.bblock("od", Vector3(minf(s9 * 0.86, tx - s9 * 0.14), IDLER.y - 0.08, IDLER.z - 0.32), Vector3(maxf(s9 * 0.86, tx - s9 * 0.14), IDLER.y + 0.08, IDLER.z - 0.02), 0.012)
		k.cyl("od_dark", Vector3(tx - s9 * 0.16, IDLER.y, IDLER.z), Vector3(tx + s9 * 0.16, IDLER.y, IDLER.z), 0.045, 0.045, 8)
		k.cyl("steel", Vector3(tx - s9 * 0.17, IDLER.y + 0.02, IDLER.z - 0.30), Vector3(tx - s9 * 0.17, IDLER.y + 0.02, IDLER.z - 0.55), 0.022, 0.022, 6)
	# snow lying where the wind leaves it: behind the fittings, on the fenders, on the tarp
	k.shade_y = Vector2(-1000.0, -999.0)
	var drifts: Array = [
		[Vector3(-1.10, 1.225, -2.62), Vector3(0.20, 0.03, 0.20), 3], [Vector3(1.10, 1.225, -2.60), Vector3(0.19, 0.028, 0.22), 4],
		[Vector3(-1.10, 1.03, 2.80), Vector3(0.20, 0.035, 0.17), 5], [Vector3(1.10, 1.03, 2.80), Vector3(0.20, 0.03, 0.16), 6],
		[Vector3(0.0, 2.215, 2.46), Vector3(0.85, 0.03, 0.11), 7], [Vector3(-1.08, 1.90, 0.72), Vector3(0.2, 0.03, 0.2), 8],
		[Vector3(0.95, 1.90, -1.58), Vector3(0.26, 0.03, 0.16), 9], [Vector3(-0.2, 1.90, -1.66), Vector3(0.22, 0.025, 0.1), 10],
		[Vector3(0.62, 2.21, 1.86), Vector3(0.25, 0.025, 0.16), 11], [Vector3(1.12, 1.90, 2.38), Vector3(0.16, 0.03, 0.2), 12],
		[Vector3(-0.67, 2.415, 1.88), Vector3(0.26, 0.02, 0.13), 13],
	]
	for dr: Array in drifts:
		k.blob("snow", dr[0], dr[1], Basis.IDENTITY, 0.12, int(dr[2]), 9, 4, 0.9, 2.2)


# ================================================================== the turret

## The turret's sections along its length (turret frame: the ring's centre at the origin): [z, half width, roof height,
## floor of the section].
const TURRET: Array = [[-0.92, 0.60, 0.62, 0.10], [-0.78, 0.78, 0.74, 0.02], [-0.45, 0.92, 0.80, 0.0], [0.05, 0.96, 0.82, 0.0],
	[0.50, 0.90, 0.78, 0.0], [0.86, 0.74, 0.68, 0.04], [1.08, 0.50, 0.54, 0.10], [1.16, 0.26, 0.40, 0.16]]


## The turret's section at `z` (between the table's rows, eased): [half width, roof height, floor].
static func turret_section(z: float) -> Array:
	var n: int = TURRET.size()
	if z <= float(TURRET[0][0]):
		return [TURRET[0][1], TURRET[0][2], TURRET[0][3]]
	for i: int in n - 1:
		var z0: float = float(TURRET[i][0])
		var z1: float = float(TURRET[i + 1][0])
		if z <= z1:
			var u: float = (z - z0) / (z1 - z0)
			var a: Array = TURRET[maxi(i - 1, 0)]
			var b: Array = TURRET[i]
			var c: Array = TURRET[i + 1]
			var e: Array = TURRET[mini(i + 2, n - 1)]
			var out: Array = []
			for j: int in [1, 2, 3]:
				var v: float = cubic_interpolate(float(b[j]), float(c[j]), float(a[j]), float(e[j]), u)
				out.append(clampf(v, minf(float(b[j]), float(c[j])) - 0.02, maxf(float(b[j]), float(c[j])) + 0.02))
			return out
	return [TURRET[n - 1][1], TURRET[n - 1][2], TURRET[n - 1][3]]


static func _turret(k: ProcKit, d: ProcKit) -> void:
	for kk: ProcKit in [k, d]:
		kk.shade_y = Vector2(-0.1, 0.25)
		kk.shade_k = Color(0.82, 0.8, 0.76)
	# the ring's collar
	k.lathe("od_dark", Vector3(0, -0.02, 0), Vector3.UP, PackedVector2Array([Vector2(0.99, 0.0), Vector2(0.99, 0.05), Vector2(0.96, 0.085)]), 36)
	# the cast body: rounded sections, sides falling in toward the roof
	var rings: Array = []
	var zs: Array[float] = []
	for i: int in TURRET.size():
		zs.append(float(TURRET[i][0]))
		if i < TURRET.size() - 1:
			zs.append((float(TURRET[i][0]) + float(TURRET[i + 1][0])) * 0.5)
	for z: float in zs:
		var s: Array = turret_section(z)
		var hw: float = float(s[0])
		var h: float = float(s[1])
		var f: float = float(s[2])
		var c: Vector3 = Vector3(0, f + (h - f) * 0.5, z)
		rings.append(ProcKit.superellipse(c, Vector3.RIGHT, Vector3.UP, hw, (h - f) * 0.5, 3.0, 32, 0.2))
	k.loft("od", rings, true, true, true)
	# the rotor shield's flat face round the mantlet, bolted
	k.bbox("od", Vector3(0, 0.38, -0.96), Vector3(1.10, 0.58, 0.08), Basis.IDENTITY, 0.02)
	k.bbox("od_dark", Vector3(0, 0.38, -1.005), Vector3(1.04, 0.52, 0.02), Basis.IDENTITY, 0.006)
	for sx: float in [-1.0, 1.0]:
		d.bolts("od_dark", Vector3(sx * 0.49, 0.16, -1.016), Vector3(sx * 0.49, 0.60, -1.016), 4, Vector3(0, 0, -1), 0.018, 0.014)
	d.bolts("od_dark", Vector3(-0.3, 0.615, -1.016), Vector3(0.3, 0.615, -1.016), 4, Vector3(0, 0, -1), 0.018, 0.014)
	# the commander's cupola: the ring, six vision blocks, the two doors standing open, the dark of the opening
	var cu: Vector3 = Vector3(0.40, 0.81, 0.32)
	k.lathe("od", cu - Vector3(0, 0.02, 0), Vector3.UP, PackedVector2Array([Vector2(0.38, 0.0), Vector2(0.37, 0.10), Vector2(0.355, 0.16), Vector2(0.34, 0.19),
		Vector2(0.27, 0.19), Vector2(0.27, 0.10)]), 24)
	k.tint = Color(0.12, 0.12, 0.12)
	k.cyl("od_dark", cu + Vector3(0, 0.07, 0), cu + Vector3(0, 0.08, 0), 0.27, 0.27, 16)
	k.tint = Color.WHITE
	for i2: int in 6:
		var a: float = TAU * float(i2) / 6.0 + 0.3
		var dir: Vector3 = Vector3(cos(a), 0, sin(a))
		var vb: Basis = Basis(Vector3.UP, -a + PI * 0.5)
		k.bbox("od_dark", cu + dir * 0.345 + Vector3(0, 0.105, 0), Vector3(0.15, 0.075, 0.07), vb, 0.01)
		k.box("glass", cu + dir * 0.383 + Vector3(0, 0.105, 0), Vector3(0.11, 0.04, 0.006), vb)
	for sgn: float in [-1.0, 1.0]:
		var hinge: Vector3 = cu + Vector3(sgn * 0.33, 0.17, 0)
		var db: Basis = Basis(Vector3.BACK, sgn * deg_to_rad(28.0))
		k.prism("od", PackedVector2Array([Vector2(-0.26, 0.0), Vector2(0.26, 0.0), Vector2(0.22, 0.20), Vector2(0.12, 0.30), Vector2(-0.12, 0.30), Vector2(-0.22, 0.20)]),
			Transform3D(db * Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(1, 0, 0)), hinge + db * Vector3(sgn * 0.08, 0.0, 0)), 0.018, 0.006)
		k.tint = Color(0.5, 0.36, 0.24)
		k.bbox("canvas", hinge + db * Vector3(sgn * 0.055, 0.14, 0), Vector3(0.02, 0.18, 0.32), db, 0.008)   # the pad inside the door
		k.tint = Color.WHITE
		k.bbox("od_dark", hinge + Vector3(sgn * 0.03, -0.01, 0), Vector3(0.07, 0.04, 0.2), Basis.IDENTITY, 0.008)
		d.uring("od_dark", hinge + db * Vector3(sgn * 0.10, 0.10, -0.06), hinge + db * Vector3(sgn * 0.10, 0.10, 0.06), db * Vector3(sgn, 0, 0), 0.03, 0.007, 4)
	# the loader's hatch, closed
	var lh: Vector3 = Vector3(-0.40, 0.80, 0.10)
	k.lathe("od_dark", lh, Vector3.UP, PackedVector2Array([Vector2(0.30, 0.0), Vector2(0.30, 0.04), Vector2(0.28, 0.055), Vector2(0.0, 0.055)]), 20)
	k.lathe("od", lh, Vector3.UP, PackedVector2Array([Vector2(0.26, 0.055), Vector2(0.26, 0.075), Vector2(0.24, 0.088), Vector2(0.0, 0.088)]), 20)
	k.bbox("od_dark", lh + Vector3(0.25, 0.065, 0), Vector3(0.09, 0.04, 0.2), Basis.IDENTITY, 0.008)
	d.uring("od_dark", lh + Vector3(-0.12, 0.085, -0.06), lh + Vector3(-0.12, 0.085, 0.06), Vector3.UP, 0.035, 0.008, 4)
	_periscope(k, d, Vector3(-0.40, 0.795, -0.38))
	_periscope(k, d, Vector3(0.12, 0.80, -0.52))
	# the vent, the lifting rings, the pistol port on the left, the antenna base and its whip
	k.lathe("od_dark", Vector3(-0.05, 0.79, 0.72), Vector3.UP, PackedVector2Array([Vector2(0.14, 0.0), Vector2(0.14, 0.03), Vector2(0.11, 0.07), Vector2(0.04, 0.085), Vector2(0.0, 0.085)]), 14)
	for sg: float in [-1.0, 1.0]:
		k.uring("od_dark", Vector3(sg * 0.86, 0.60, -0.28), Vector3(sg * 0.86, 0.60, -0.12), Vector3(sg * 0.5, 1, 0), 0.085, 0.016, 5)
		k.uring("od_dark", Vector3(sg * 0.60, 0.60, 0.84), Vector3(sg * 0.66, 0.60, 0.96), Vector3(sg * 0.3, 1, 0.3), 0.085, 0.016, 5)
	k.lathe("od_dark", Vector3(-0.93, 0.42, 0.62), Vector3(-1, 0.12, 0), PackedVector2Array([Vector2(0.11, 0.0), Vector2(0.11, 0.03), Vector2(0.09, 0.05), Vector2(0.0, 0.055)]), 12)
	k.bbox("od_dark", Vector3(-0.955, 0.54, 0.62), Vector3(0.04, 0.05, 0.12), Basis.IDENTITY, 0.008)
	k.lathe("od_dark", Vector3(-0.55, 0.66, 0.95), Vector3.UP, PackedVector2Array([Vector2(0.07, 0.0), Vector2(0.07, 0.05), Vector2(0.045, 0.07), Vector2(0.03, 0.16), Vector2(0.012, 0.18)]), 10)
	k.cyl("steel", Vector3(-0.55, 0.84, 0.95), Vector3(-0.62, 2.70, 1.20), 0.009, 0.004, 5, false)
	# the .50 on its post behind the cupola: the post and cradle, the receiver and its cover, the barrel in its
	# support, the spade grips, the ammunition can with the belt up to the feed
	var post: Vector3 = Vector3(0.40, 0.81, 0.78)
	k.lathe("od_dark", post, Vector3.UP, PackedVector2Array([Vector2(0.07, 0.0), Vector2(0.07, 0.03), Vector2(0.04, 0.05), Vector2(0.035, 0.38), Vector2(0.05, 0.40)]), 10)
	var g0: Vector3 = post + Vector3(0, 0.46, 0.10)
	k.bbox("od_dark", g0 + Vector3(0, -0.055, 0.02), Vector3(0.17, 0.03, 0.26), Basis.IDENTITY, 0.008)   # the cradle
	k.bbox("steel", g0, Vector3(0.105, 0.115, 0.56), Basis.IDENTITY, 0.01)
	k.bbox("steel", g0 + Vector3(0, 0.062, -0.10), Vector3(0.10, 0.02, 0.30), Basis.IDENTITY, 0.006)    # the top cover
	k.bbox("steel", g0 + Vector3(0, 0.0, 0.30), Vector3(0.09, 0.13, 0.05), Basis.IDENTITY, 0.008)     # the back plate
	for gx: float in [-0.045, 0.045]:
		d.uring("steel", g0 + Vector3(gx, 0.045, 0.325), g0 + Vector3(gx, -0.045, 0.325), Vector3(0, 0, 1), 0.10, 0.011, 4)   # the spade grips
	d.bbox("steel", g0 + Vector3(0.065, 0.0, 0.08), Vector3(0.03, 0.03, 0.10), Basis.IDENTITY, 0.004)   # the charging handle
	k.lathe("steel", g0 + Vector3(0, 0.012, -0.28), Vector3(0, 0, -1), PackedVector2Array([Vector2(0.036, 0.0), Vector2(0.036, 0.30), Vector2(0.028, 0.32), Vector2(0.02, 0.32),
		Vector2(0.019, 1.02), Vector2(0.027, 1.03), Vector2(0.027, 1.10), Vector2(0.012, 1.10)]), 8)
	k.bbox("od_dark", g0 + Vector3(-0.15, -0.035, 0.0), Vector3(0.11, 0.18, 0.27), Basis.IDENTITY, 0.008)
	k.bbox("brass", g0 + Vector3(-0.075, 0.045, -0.02), Vector3(0.06, 0.02, 0.05), Basis(Vector3.BACK, 0.5), 0.0)
	# spare links on the cheeks, forward of the stars
	for s2: float in [-1.0, 1.0]:
		for li: int in 3:
			var lz: float = -0.58 + 0.16 * float(li)
			var hw2: float = float(turret_section(lz)[0])
			var slope: float = (float(turret_section(lz + 0.05)[0]) - float(turret_section(lz - 0.05)[0])) / 0.1
			var lbs: Basis = Basis(Vector3.UP, -s2 * atan(slope)) * Basis(Vector3(0, 1, 0), Vector3(s2, 0, 0), Vector3(0, 0, -s2))
			_spare_link(k, Vector3(s2 * (hw2 + 0.022), 0.30, lz), lbs)
		k.star("white", Vector3(s2 * 0.957, 0.43, 0.25), Vector3(s2, 0.0, 0.0), Vector3.UP, 0.22)
	# the stowage on the bustle: two bedrolls strapped to a rail, a pack on the right
	k.shade_y = Vector2(-1000.0, -999.0)
	d.tube("od_dark", PackedVector3Array([Vector3(-0.62, 0.30, 1.02), Vector3(-0.5, 0.30, 1.22), Vector3(0.5, 0.30, 1.22), Vector3(0.62, 0.30, 1.02)]), 0.012, 4, false, false)
	k.tint = Color(0.9, 0.88, 0.8)
	k.blob("canvas", Vector3(-0.02, 0.33, 1.33), Vector3(0.115, 0.50, 0.115), Basis(Vector3.BACK, PI * 0.5), 0.07, 21, 9, 7, 0.0, 6.0, 0.72)
	k.tint = Color(0.72, 0.78, 0.6)
	k.blob("canvas", Vector3(0.05, 0.535, 1.27), Vector3(0.095, 0.40, 0.095), Basis(Vector3.BACK, PI * 0.5), 0.08, 22, 9, 6, 0.0, 6.0, 0.72)
	k.tint = Color(0.5, 0.42, 0.3)
	for sx2: float in [-0.3, 0.28]:
		k.bbox("canvas", Vector3(sx2, 0.42, 1.31), Vector3(0.035, 0.44, 0.27), Basis(Vector3.RIGHT, 0.25), 0.012)
	k.tint = Color(0.85, 0.82, 0.68)
	k.blob("canvas", Vector3(0.80, 0.36, 0.78), Vector3(0.13, 0.15, 0.07), Basis(Vector3.UP, -0.75), 0.06, 23, 8, 4, 0.0, 3.4)
	k.tint = Color.WHITE
	# snow on the roof's lee side
	k.blob("snow", Vector3(-0.42, 0.775, 0.55), Vector3(0.22, 0.03, 0.2), Basis.IDENTITY, 0.12, 31, 9, 4, 0.9, 2.2)
	k.blob("snow", Vector3(0.0, 0.79, -0.2), Vector3(0.2, 0.025, 0.16), Basis.IDENTITY, 0.12, 32, 9, 4, 0.9, 2.2)
	k.blob("snow", Vector3(0.0, 0.66, 1.3), Vector3(0.4, 0.025, 0.09), Basis.IDENTITY, 0.12, 33, 9, 4, 0.9, 2.2)


# ================================================================== the gun (about the trunnion)

static func _gun(k: ProcKit, d: ProcKit) -> void:
	# the mantlet: a thick curved shield (lofted), its lifting hooks and bolts, the sight's and the coax's ports
	var rings: Array = []
	for z: float in [0.04, -0.02, -0.08, -0.14, -0.19, -0.22]:
		var w: float = 0.46 - 0.07 * absf(z + 0.06) * 3.0
		var h: float = 0.27 - 0.05 * absf(z + 0.06) * 3.0
		rings.append(ProcKit.superellipse(Vector3(0, 0, z), Vector3.RIGHT, Vector3.UP, w, h, 3.4, 28))
	k.loft("od", rings, true, true, true)
	k.bbox("od_dark", Vector3(0.25, 0.10, -0.225), Vector3(0.07, 0.055, 0.03), Basis.IDENTITY, 0.008)   # the sight
	for sx: float in [-1.0, 1.0]:
		d.uring("od_dark", Vector3(sx * 0.30, 0.20, -0.20), Vector3(sx * 0.36, 0.20, -0.14), Vector3(0, 1, -0.3), 0.05, 0.012, 4)
		d.bolts("od_dark", Vector3(sx * 0.38, -0.15, -0.205), Vector3(sx * 0.38, 0.12, -0.205), 3, Vector3(0, 0, -1), 0.018, 0.014)
	# the barrel: the collar, the recoil sleeve, the tube with its taper, the muzzle's swell, the bore
	k.lathe("od_dark", Vector3(0, 0, -0.18), Vector3(0, 0, -1), PackedVector2Array([Vector2(0.13, 0.0), Vector2(0.13, 0.05), Vector2(0.105, 0.07)]), 18)
	for bi: int in 8:
		var a: float = TAU * float(bi) / 8.0
		d.bolt("od_dark", Vector3(cos(a) * 0.115, sin(a) * 0.115, -0.232), Vector3(0, 0, -1), 0.012, 0.012)
	k.lathe("od", Vector3(0, 0, -0.20), Vector3(0, 0, -1), PackedVector2Array([Vector2(0.098, 0.0), Vector2(0.098, 0.05), Vector2(0.090, 0.42), Vector2(0.066, 0.44),
		Vector2(0.058, 2.72), Vector2(0.058, 2.74), Vector2(0.068, 2.76), Vector2(0.068, 2.85), Vector2(0.044, 2.85)]), 20)
	k.tint = Color(0.1, 0.1, 0.1)
	k.lathe("steel", Vector3(0, 0, -GUN_LEN), Vector3(0, 0, 1), PackedVector2Array([Vector2(0.0, 0.25), Vector2(0.044, 0.25), Vector2(0.044, 0.0)]), 14)
	k.tint = Color.WHITE
	# the coax
	k.cyl("steel", Vector3(COAX_AT.x, COAX_AT.y, -0.18), COAX_AT, 0.02, 0.018, 8)


# ================================================================== the running gear (about the axle, X)

## A wheel's shape turned round the axle: the tyre, the dished disc outboard with `ribs` pressed ribs, the plain
## inboard face, the hub cap. `R` the tyre's radius, `w` its width, `tyre` whether it has a rubber tyre.
static func _wheel_shape(k: ProcKit, R: float, w: float, ribs: int, tyre: bool, seg: int) -> void:
	var o: Vector3 = Vector3(-w * 0.5, 0, 0)
	var ax: Vector3 = Vector3(1, 0, 0)
	var rim: float = R - (0.036 if tyre else 0.02)
	var key_t: String = "rubber" if tyre else "gear"
	k.lathe(key_t, o, ax, PackedVector2Array([Vector2(rim, 0.0), Vector2(R - 0.008, 0.0), Vector2(R, 0.012), Vector2(R, w - 0.012), Vector2(R - 0.008, w), Vector2(rim, w)]), seg)
	# outboard: the rim's lip, the dish in to the hub, the cap
	k.lathe("gear", o, ax, PackedVector2Array([Vector2(rim, w - 0.012), Vector2(rim - 0.02, w - 0.02), Vector2(R * 0.5, w - 0.055), Vector2(R * 0.3, w - 0.035),
		Vector2(R * 0.27, w + 0.005)]), seg)
	k.lathe("gear_dark", o, ax, PackedVector2Array([Vector2(R * 0.27, w + 0.005), Vector2(R * 0.2, w + 0.02), Vector2(0.0, w + 0.022)]), 10)
	# inboard: plain
	k.lathe("gear_dark", o, ax, PackedVector2Array([Vector2(0.0, 0.03), Vector2(R * 0.3, 0.03), Vector2(rim, 0.012)]), seg)
	for i: int in ribs:
		var a: float = TAU * float(i) / float(ribs)
		var dv: Vector3 = Vector3(0, cos(a), sin(a))
		k.box("gear_dark", Vector3(w * 0.5 - 0.044, 0, 0) + dv * R * 0.55, Vector3(0.016, R * 0.34, 0.03), Basis(Vector3.RIGHT, a))


static func _wheel(k: ProcKit, f: ProcKit) -> void:
	k.tint = MUD.lerp(Color.WHITE, 0.6)
	_wheel_shape(k, WHEEL_R, 0.23, 6, true, 18)
	f.tint = k.tint
	f.cyl("rubber", Vector3(-0.115, 0, 0), Vector3(0.115, 0, 0), WHEEL_R, WHEEL_R, 10, false)
	f.cyl("gear", Vector3(0.10, 0, 0), Vector3(0.115, 0, 0), WHEEL_R * 0.86, WHEEL_R * 0.86, 10)


static func _sprocket(k: ProcKit, f: ProcKit) -> void:
	k.tint = MUD.lerp(Color.WHITE, 0.65)
	# two toothed rings (13 teeth) on a drum, the hub outboard with its bolts
	var teeth: int = 13
	var poly: PackedVector2Array = PackedVector2Array()
	for i: int in teeth:
		var a0: float = TAU * float(i) / float(teeth)
		var st: float = TAU / float(teeth)
		for q: Array in [[0.0, SPROCKET_R - 0.03], [0.28, SPROCKET_R - 0.03], [0.42, SPROCKET_R + 0.022], [0.58, SPROCKET_R + 0.022], [0.72, SPROCKET_R - 0.03]]:
			var a: float = a0 + st * float(q[0])
			poly.append(Vector2(cos(a), sin(a)) * float(q[1]))
	var fr: Basis = Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0))
	for side: float in [-1.0, 1.0]:
		k.edge = 0.3
		k.prism("gear", poly, Transform3D(fr, Vector3(side * 0.185, 0, 0)), 0.016, 0.0)
		k.edge = 0.0
		k.tint = Color(0.12, 0.12, 0.12)
		for j: int in 6:   # the lightening holes, the dark of them
			var a2: float = TAU * float(j) / 6.0
			var d2: Vector3 = Vector3(0, cos(a2), sin(a2))
			k.cyl("gear_dark", Vector3(side * 0.199, 0, 0) + d2 * 0.215, Vector3(side * 0.203, 0, 0) + d2 * 0.215, 0.042, 0.042, 8)
		k.tint = MUD.lerp(Color.WHITE, 0.65)
	k.lathe("gear_dark", Vector3(-0.17, 0, 0), Vector3(1, 0, 0), PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.24, 0.0), Vector2(0.24, 0.34)]), 18)
	k.lathe("gear", Vector3(0.17, 0, 0), Vector3(1, 0, 0), PackedVector2Array([Vector2(0.24, 0.0), Vector2(0.17, 0.035), Vector2(0.15, 0.07), Vector2(0.10, 0.09), Vector2(0.0, 0.095)]), 16)
	for b: int in 8:
		var a3: float = TAU * float(b) / 8.0
		k.bolt("steel", Vector3(0.20, cos(a3) * 0.20, sin(a3) * 0.20), Vector3(1, 0.3, 0), 0.014, 0.014)
	k.tint = Color.WHITE
	f.tint = MUD.lerp(Color.WHITE, 0.65)
	f.cyl("steel", Vector3(-0.2, 0, 0), Vector3(0.2, 0, 0), SPROCKET_R, SPROCKET_R, 12)


static func _idler(k: ProcKit, f: ProcKit) -> void:
	k.tint = MUD.lerp(Color.WHITE, 0.6)
	_wheel_shape(k, IDLER_R, 0.23, 6, false, 20)
	k.tint = Color.WHITE
	f.tint = MUD.lerp(Color.WHITE, 0.6)
	f.cyl("gear", Vector3(-0.115, 0, 0), Vector3(0.115, 0, 0), IDLER_R, IDLER_R, 10)


static func _roller(k: ProcKit, f: ProcKit) -> void:
	k.tint = MUD.lerp(Color.WHITE, 0.6)
	k.lathe("rubber", Vector3(-0.10, 0, 0), Vector3(1, 0, 0), PackedVector2Array([Vector2(0.06, 0.0), Vector2(ROLLER_R - 0.006, 0.0), Vector2(ROLLER_R, 0.01),
		Vector2(ROLLER_R, 0.19), Vector2(ROLLER_R - 0.006, 0.20), Vector2(0.06, 0.20), Vector2(0.045, 0.225), Vector2(0.0, 0.225)]), 12)
	k.tint = Color.WHITE
	f.tint = MUD.lerp(Color.WHITE, 0.6)
	f.cyl("rubber", Vector3(-0.10, 0, 0), Vector3(0.10, 0, 0), ROLLER_R, ROLLER_R, 8)


static func _link(k: ProcKit, f: ProcKit) -> void:
	var hw: float = TRACK_W * 0.5
	# the shoe, the chevron's two bars outward, the end connectors with their guide horns inward
	k.tint = MUD.lerp(Color.WHITE, 0.5)
	k.box("track", Vector3(0, 0, 0), Vector3(TRACK_W - 0.085, LINK_T * 0.72, LINK_PITCH * 0.86))
	k.tint = Color(1.15, 1.12, 1.1)
	k.edge = 0.6
	for s: float in [-1.0, 1.0]:
		k.box("track", Vector3(s * 0.082, LINK_T * 0.5, 0), Vector3(0.175, LINK_T * 0.5, 0.034), Basis(Vector3.UP, s * 0.40))
	k.edge = 0.3
	k.tint = MUD.lerp(Color.WHITE, 0.7)
	for s2: float in [-1.0, 1.0]:
		k.box("track", Vector3(s2 * (hw - 0.022), 0, 0), Vector3(0.044, LINK_T, LINK_PITCH * 0.98))
		var x: float = s2 * (hw - 0.058)
		k.prism("track", PackedVector2Array([Vector2(-0.045, -LINK_T * 0.4), Vector2(0.045, -LINK_T * 0.4), Vector2(0.012, -LINK_T * 0.5 - 0.062), Vector2(-0.012, -LINK_T * 0.5 - 0.062)]),
			_side(x), 0.014, 0.0)
	k.edge = 0.0
	k.tint = Color.WHITE
	f.tint = MUD.lerp(Color.WHITE, 0.55)
	f.box("track", Vector3(0, 0, 0), Vector3(TRACK_W, LINK_T, LINK_PITCH * 0.97))
