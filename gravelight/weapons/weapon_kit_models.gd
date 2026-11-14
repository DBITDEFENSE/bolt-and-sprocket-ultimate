class_name WeaponKitModels
extends RefCounted
## Attachments on every gun model (UPDATE_04 section 6 generalised, DECISIONS T-074). The M1911 keeps its own
## hand-fitted parts (M1911KitModels); every other gun is dressed here from the option's "model" key, built with
## the WeaponModels primitives against the model's own markers and shape, so the same code fits a Thompson and a
## Kar98k: the Muzzle marker (and meta "bore") for muzzle parts, the "Mag" part's meshes for magazines, SightPoint
## / FrontSight for sights, LeftHand and the gun's outline (a vertex scan) for grips, stocks and slings. Runs
## inside WeaponModels._build_new before the static merge, so the parts show in first person, on the
## third-person RemoteBody gun and in the bench close-up alike.
##
## Parts ("model"):
##   muzzle  can (suppressor: olive tube, end caps, stencil band), comp (ported), hider (slotted cone), choke,
##           brake, barrel_ext (a longer barrel), barrel_band (a crown ring), nozzle (flamethrower); each moves the
##           Muzzle marker to its new crown;
##   mag     mag_ext (the magazine continued down), drum (a round drum; hide_mag swaps it for the stick), twin_mag
##           (a second magazine clamped alongside), trench_mag (a box under the action), belt_box (the drum
##           replaced by a belt box), tube_ext (a longer shotgun tube), shell_belt (shells on the stock);
##   sights  scope (tube, bells, rings; SightPoint / FrontSight move to the eyepiece / objective centres, so the
##           ADS pose (WeaponHolder._compute_ads_pose) aims through it, and meta "scope" turns on the HUD scope
##           picture), radium (glowing dots beside the rear and on the front sight, off the sight line), bead
##           (an ivory bead under the existing aim point and a low rib), aa_ring (a spider-web ring round the
##           front sight, the line through its open centre);
##   grip    bipod (legs half-down; replace_legs frees the model's own "BipodLeg" nodes), foregrip, sling,
##           cheek_pad, recoil_pad;
##   ammo    band (a painted band on the magazine's base: black AP, red, blue incendiary, violet Nachtglas).

const BAND_KINDS: Dictionary = {"black": "black", "red": "red_paint", "blue": "navy"}


## The look a WeaponInstance asks the model builder for ({} = the plain gun, the shared template).
static func look_of(w: WeaponInstance) -> Dictionary:
	if w == null or (w.kit.is_empty() and w.finish == &"") or not WeaponKit.accepts(w):
		return {}
	return {"kit": w.kit.duplicate(), "finish": String(w.finish), "sig": w.kit_sig(), "id": String(w.base_id())}


## Flash-size multiplier for the fitted barrel (a can all but hides it; a comp spreads it, a hider damps it).
static func flash_scale(w: WeaponInstance) -> float:
	if w == null or w.kit.is_empty():
		return 1.0
	return float((WeaponKit.cfg().get("flash_scale", {}) as Dictionary).get(str(w.kit_mods().get("flash", "")), 1.0))


static func _base(b: WeaponModels) -> String:
	return str(b.look.get("id", String(b.root.name).trim_prefix("Model_")))


## The fitted option of `slot` as built for this model (its upgraded version on an upgraded gun).
static func _part(b: WeaponModels, slot: String) -> Dictionary:
	var opt: String = str((b.look.get("kit", {}) as Dictionary).get(slot, ""))
	if opt == "":
		return {}
	return WeaponKit.variant(_base(b), slot, opt, b.upgraded)


## Dresses a built gun (every gun but the M1911, which M1911KitModels dresses).
static func dress(b: WeaponModels) -> void:
	if b.look.is_empty() or b.root.name == "Model_m1911":
		return
	b.root.set_meta("kit_muzzle0", _muzzle(b))   # where the barrel ended before a muzzle part moved the marker
	for slot: String in ["mag", "barrel", "sights", "grip", "ammo"]:
		var v: Dictionary = _part(b, slot)
		var model: String = str(v.get("model", ""))
		if model == "":
			continue
		match model:
			"can":
				_can(b, v)
			"comp":
				_comp(b, v)
			"hider":
				_hider(b, v)
			"choke":
				_choke(b, v)
			"brake":
				_brake(b, v)
			"barrel_ext":
				_barrel_ext(b, v)
			"barrel_band":
				_barrel_band(b, v)
			"nozzle":
				_nozzle(b, v)
			"mag_ext":
				_mag_ext(b, v)
			"drum":
				_drum(b, v)
			"twin_mag":
				_twin_mag(b, v)
			"trench_mag":
				_trench_mag(b, v)
			"belt_box":
				_belt_box(b, v)
			"tube_ext":
				_tube_ext(b, v)
			"shell_belt":
				_shell_belt(b, v)
			"scope":
				_scope(b, v)
			"radium":
				_radium(b, v)
			"bead":
				_bead(b, v)
			"aa_ring":
				_aa_ring(b, v)
			"bipod":
				_bipod(b, v)
			"foregrip":
				_foregrip(b, v)
			"sling":
				_sling(b, v)
			"cheek_pad":
				_cheek_pad(b, v)
			"recoil_pad":
				_recoil_pad(b, v)
			"band":
				_band(b, v)


# ================================================================== measuring the model

## Root-space transform of a node inside the model.
static func _xf(b: WeaponModels, n: Node3D) -> Transform3D:
	var xf: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p != null and p != b.root:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


static func _muzzle(b: WeaponModels) -> Vector3:
	var mz: Node3D = b.root.get_node_or_null("Muzzle") as Node3D
	return _xf(b, mz).origin if mz != null else Vector3(0, 0.04, -float(b.root.get_meta("length", 0.6)))


static func _bore(b: WeaponModels) -> float:
	return float(b.root.get_meta("bore", 0.005))


## Moves the Muzzle marker forward to `z` (the flash and tracers start there).
static func _muzzle_to(b: WeaponModels, z: float) -> void:
	var mz: Node3D = b.root.get_node_or_null("Muzzle") as Node3D
	if mz == null:
		return
	var p: Vector3 = _xf(b, mz).origin
	if z >= p.z:
		return
	var d: Vector3 = Vector3(0, 0, z - p.z)
	var par: Node3D = mz.get_parent() as Node3D
	if par != b.root:
		d = _xf(b, par).basis.inverse() * d
	mz.position += d
	b.root.set_meta("length", maxf(float(b.root.get_meta("length", 0.6)), absf(z) + 0.02))


## Root-space position of a sight marker, and the marker (null when the model has none).
static func _mark(b: WeaponModels, n: String) -> Node3D:
	return b.root.find_child(n, true, false) as Node3D


## False when `mi` or a group between it and `top` is hidden (the spare rocket, the M1911's KitFlash).
static func _shown(mi: Node3D, top: Node) -> bool:
	var n: Node = mi
	while n != null and n != top:
		if n is Node3D and not (n as Node3D).visible:
			return false
		n = n.get_parent()
	return true


## The bounds of every mesh under `n`, in `n`'s own space (empty AABB when it holds none).
static func _bounds(n: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for c: Node in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c as MeshInstance3D
		if mi.mesh == null or not _shown(mi, n):
			continue
		var xf: Transform3D = mi.transform
		var p: Node = mi.get_parent()
		while p != null and p != n:
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var a: AABB = xf * mi.mesh.get_aabb()
		out = a if first else out.merge(a)
		first = false
	return out


## Bounds (root space) of the gun's surface between z0 and z1 (z0 < z1), from a vertex scan of every mesh except
## the moving parts and the magazine; empty when nothing is there. Used to fit parts to stocks and receivers.
static func _slice(b: WeaponModels, z0: float, z1: float, skip: Array = ["Mag", "Bolt", "Pump", "Rocket", "Valve", "Handle"]) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for c: Node in b.root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c as MeshInstance3D
		if mi.mesh == null or not _shown(mi, b.root):
			continue
		var bad: bool = false
		var p: Node = mi.get_parent()
		while p != null and p != b.root:
			if skip.has(String(p.name)):
				bad = true
			p = p.get_parent()
		if bad:
			continue
		var xf: Transform3D = _xf(b, mi)
		for si: int in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(si)
			for v: Vector3 in (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				var g: Vector3 = xf * v
				if g.z < z0 or g.z > z1:
					continue
				if first:
					out = AABB(g, Vector3.ZERO)
					first = false
				else:
					out = out.expand(g)
	return out


## The bounds of a built gun model (its own space): the bench close-up frames with it.
static func bounds(model: Node3D) -> AABB:
	return _bounds(model)


## The lowest point of a built gun model between z0 and z1 (its own space; INF when nothing is there): where the
## bench's rests reach up to.
static func underside(model: Node3D, z0: float, z1: float) -> float:
	var lo: float = INF
	for c: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c as MeshInstance3D
		if mi.mesh == null or not _shown(mi, model):
			continue
		var xf: Transform3D = mi.transform
		var p: Node = mi.get_parent()
		while p != null and p != model:
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		for si: int in mi.mesh.get_surface_count():
			for v: Vector3 in (mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				var g: Vector3 = xf * v
				if g.z >= z0 and g.z <= z1:
					lo = minf(lo, g.y)
	return lo


## The whole gun's bounds (root space).
static func _gun_bounds(b: WeaponModels) -> AABB:
	return _bounds(b.root)


## A cylinder from `a` to `c` (root space unless `parent`), radius `r`.
static func _rod(b: WeaponModels, a: Vector3, c: Vector3, r: float, kind: String, parent: Node3D = null) -> MeshInstance3D:
	var d: Vector3 = c - a
	var mi: MeshInstance3D = b.tube(r, r, d.length(), (a + c) * 0.5, kind, "y", parent, 10)
	if d.length() > 0.0001:
		var up: Vector3 = d.normalized()
		mi.basis = Basis(Quaternion(Vector3.UP, up))
	return mi


static func _glow(c: Color, e: float = 3.0) -> StandardMaterial3D:
	return M1911KitModels.glow_mat(c, e)


# ================================================================== muzzle parts

## The trials can: an olive tube with blued end caps, a cream stencil band and a brass data plate on the left.
static func _can(b: WeaponModels, v: Dictionary) -> void:
	var mz: Vector3 = _muzzle(b)
	var r: float = maxf(0.0155, _bore(b) * 2.9)
	var ln: float = float(v.get("len", 0.17))
	b.tube(_bore(b) * 2.0, _bore(b) * 2.0, 0.012, mz + Vector3(0, 0, -0.004), "blued", "z", null, 16)   # thread adaptor
	var c: Vector3 = mz + Vector3(0, 0, -0.01 - ln * 0.5)
	b.tube(r, r, ln, c, "olive", "z", null, 24)
	for z: float in [-0.01, -0.01 - ln]:
		b.tube(r + 0.0007, r + 0.0007, 0.006, mz + Vector3(0, 0, z), "blued", "z", null, 24)
	b.tube(_bore(b) * 0.9, _bore(b) * 0.9, 0.002, mz + Vector3(0, 0, -0.014 - ln), "black", "z", null, 12)
	b.tube(r + 0.0003, r + 0.0003, 0.012, mz + Vector3(0, 0, -0.01 - ln * 0.3), "cream", "z", null, 24)
	b.box(Vector3(0.0006, r * 0.6, ln * 0.18), mz + Vector3(-(r + 0.0003), 0, -0.01 - ln * 0.62), "brass")
	_muzzle_to(b, mz.z - 0.015 - ln)


## A ported compensator: a stubby tube with three slots cut in its top.
static func _comp(b: WeaponModels, _v: Dictionary) -> void:
	var mz: Vector3 = _muzzle(b)
	var r: float = maxf(0.0105, _bore(b) * 2.4)
	var ln: float = 0.05
	b.tube(r, r, ln, mz + Vector3(0, 0, -ln * 0.5), "blued", "z", null, 18)
	for i: int in 3:
		b.box(Vector3(r * 1.3, 0.0016, 0.0045), mz + Vector3(0, r - 0.0004, -0.012 - i * 0.012), "black")
	b.tube(_bore(b), _bore(b), 0.002, mz + Vector3(0, 0, -ln - 0.0005), "black", "z", null, 12)
	_muzzle_to(b, mz.z - ln - 0.001)


## A slotted flash-hider cone flaring forward.
static func _hider(b: WeaponModels, _v: Dictionary) -> void:
	var mz: Vector3 = _muzzle(b)
	var r0: float = maxf(0.008, _bore(b) * 2.0)
	var ln: float = 0.05
	var cone: MeshInstance3D = b.tube(r0 * 1.45, r0, ln, mz + Vector3(0, 0, -ln * 0.5), "blued", "z", null, 16)
	(cone.mesh as CylinderMesh).cap_top = false
	(cone.mesh as CylinderMesh).cap_bottom = false
	cone.material_override = b.two_sided("blued")
	for i: int in 4:
		var a: float = TAU * (float(i) + 0.5) / 4.0
		var s: MeshInstance3D = b.box(Vector3(0.0018, 0.0018, ln * 0.7), mz + Vector3(cos(a) * r0 * 1.25, sin(a) * r0 * 1.25, -ln * 0.6), "black")
		s.rotation = Vector3(0, 0, a)
	_muzzle_to(b, mz.z - ln)


## A choke tube with knurled rings.
static func _choke(b: WeaponModels, _v: Dictionary) -> void:
	var mz: Vector3 = _muzzle(b)
	var r: float = maxf(0.011, _bore(b) * 1.45)
	b.tube(r, r, 0.04, mz + Vector3(0, 0, -0.02), "steel", "z", null, 18)
	for i: int in 4:
		b.ring(r - 0.0012, r + 0.0012, mz + Vector3(0, 0, -0.008 - i * 0.008), "blued")
	b.tube(_bore(b) * 0.8, _bore(b) * 0.8, 0.002, mz + Vector3(0, 0, -0.0405), "black", "z", null, 12)
	_muzzle_to(b, mz.z - 0.041)


## A big many-ported muzzle brake (anti-tank rifles).
static func _brake(b: WeaponModels, _v: Dictionary) -> void:
	var mz: Vector3 = _muzzle(b)
	var r: float = maxf(0.016, _bore(b) * 2.6)
	b.box(Vector3(r * 2.2, r * 1.8, 0.09), mz + Vector3(0, 0, -0.045), "blued")
	for i: int in 4:
		for s: float in [-1.0, 1.0]:
			b.box(Vector3(0.002, r * 1.2, 0.009), mz + Vector3(s * r * 1.1, 0, -0.014 - i * 0.02), "black")
	_muzzle_to(b, mz.z - 0.09)


## A longer (heavier) barrel: the bore carried forward, with a crown.
static func _barrel_ext(b: WeaponModels, _v: Dictionary) -> void:
	var mz: Vector3 = _muzzle(b)
	var r: float = maxf(0.0075, _bore(b) * 1.9)
	b.tube(r, r * 1.05, 0.07, mz + Vector3(0, 0, -0.035), "blued", "z", null, 16)
	b.tube(r * 1.08, r * 1.08, 0.006, mz + Vector3(0, 0, -0.068), "steel", "z", null, 16)
	_muzzle_to(b, mz.z - 0.071)


## A match crown: a bright steel ring at the muzzle (the barrel itself is the same length).
static func _barrel_band(b: WeaponModels, _v: Dictionary) -> void:
	var mz: Vector3 = _muzzle(b)
	var r: float = maxf(0.008, _bore(b) * 2.1)
	if b.root.name == "Model_panzerschreck":
		r = 0.05
	b.tube(r, r, 0.014, mz + Vector3(0, 0, -0.007), "steel" if not b.upgraded else "brass", "z", null, 20)
	b.ring(r - 0.001, r + 0.0015, mz + Vector3(0, 0, -0.0145), "brass")
	_muzzle_to(b, mz.z - 0.015)


## A long-reach flamethrower nozzle with a brass tip and its igniter.
static func _nozzle(b: WeaponModels, _v: Dictionary) -> void:
	var mz: Vector3 = _muzzle(b)
	b.tube(0.011, 0.014, 0.16, mz + Vector3(0, 0, -0.08), "olive", "z", null, 16)
	b.tube(0.013, 0.011, 0.02, mz + Vector3(0, 0, -0.17), "brass", "z", null, 16)
	b.ball(0.007, mz + Vector3(0, -0.016, -0.15), "glow_amber")
	_muzzle_to(b, mz.z - 0.18)


# ================================================================== magazines

static func _mag(b: WeaponModels) -> Node3D:
	return b.root.get_node_or_null("Mag") as Node3D


## The magazine continued below its base by `ext` of its own length, with a new baseplate.
static func _mag_ext(b: WeaponModels, v: Dictionary) -> void:
	var mag: Node3D = _mag(b)
	if mag == null:
		return
	var a: AABB = _bounds(mag)
	var dir: Vector3 = (b.root.get_meta("mag_dir", Vector3.DOWN) as Vector3).normalized()
	if absf(dir.x) > 0.7 or dir.y > 0.7:
		# T-248: a side magazine (Type 100, Sten, FG 42) grows out to the side, a top one (Bren) upward: the box
		# continues the magazine the way it points, never down out of its flank
		var ax: int = 0 if absf(dir.x) > 0.7 else 1
		var sgn: float = signf(dir[ax])
		var len_ax: float = a.size[ax] * float(v.get("ext", 0.4))
		var edge: float = a.end[ax] if sgn > 0.0 else a.position[ax]
		var c2: Vector3 = a.get_center()
		c2[ax] = edge + sgn * (len_ax * 0.5 - 0.002)
		var sz: Vector3 = a.size * 0.96
		sz.z = minf(a.size.z, 0.06) * 0.96
		sz[ax] = len_ax
		b.box(sz, c2, "blued", Vector3.ZERO, mag)
		var cap: Vector3 = sz * 1.09
		cap[ax] = 0.005
		var cc: Vector3 = c2
		cc[ax] = edge + sgn * (len_ax + 0.0005)
		b.box(cap, cc, "steel", Vector3.ZERO, mag)
		return
	if a.size.y < 0.01:
		_trench_mag(b, v)
		return
	var h: float = a.size.y * float(v.get("ext", 0.4))
	var c: Vector3 = Vector3(a.get_center().x, a.position.y - h * 0.5 + 0.002, a.get_center().z)
	b.box(Vector3(a.size.x * 0.96, h, minf(a.size.z, 0.06) * 0.96), c, "blued", Vector3.ZERO, mag)
	b.box(Vector3(a.size.x * 1.05, 0.005, minf(a.size.z, 0.06) * 1.05), Vector3(c.x, a.position.y - h - 0.0005, c.z), "steel", Vector3.ZERO, mag)
	mag.set_meta("bottom", a.position.y - h - 0.003)


## A round drum under the magazine well (hide_mag: in place of the stick magazine), with covers and a winding key.
static func _drum(b: WeaponModels, v: Dictionary) -> void:
	var mag: Node3D = _mag(b)
	if mag == null:
		return
	var a: AABB = _bounds(mag)
	if a.size.y < 0.01:
		return
	var r: float = float(v.get("r", 0.06)) * (1.12 if b.upgraded else 1.0)
	var wd: float = float(v.get("w", 0.05))
	var top: float = a.end.y
	if bool(v.get("hide_mag", false)):
		for c0: Node in mag.find_children("*", "MeshInstance3D", true, false):
			(c0 as MeshInstance3D).visible = false
	else:
		top = a.position.y + 0.02
	var c: Vector3 = Vector3(a.get_center().x, top - r - 0.004, a.get_center().z)
	b.box(Vector3(wd * 0.5, 0.012, minf(a.size.z, 0.04)), Vector3(c.x, top - 0.004, c.z), "blued", Vector3.ZERO, mag)   # feed neck
	b.tube(r, r, wd, c, "blued", "x", mag, 28)
	for s: float in [-1.0, 1.0]:
		b.tube(r * 0.93, r * 0.93, 0.003, c + Vector3(s * (wd * 0.5 + 0.0012), 0, 0), "steel", "x", mag, 28)
		b.ring(r * 0.86, r * 0.98, c + Vector3(s * (wd * 0.5 + 0.0028), 0, 0), "black", "x", mag)
	var kx: float = -(wd * 0.5 + 0.006)
	b.tube(0.0065, 0.0065, 0.008, c + Vector3(kx, 0, 0), "steel", "x", mag, 12)
	b.box(Vector3(0.003, 0.03, 0.007), c + Vector3(kx - 0.004, 0.007, 0), "steel", Vector3.ZERO, mag)
	if b.upgraded:
		for i: int in 16:
			var an: float = TAU * float(i) / 16.0
			b.ball(0.004, c + Vector3(wd * 0.5 + 0.004, cos(an) * (r + 0.001), sin(an) * (r + 0.001)), "brass", Vector3.ONE, mag)
	mag.set_meta("bottom", c.y - r)


## A second magazine clamped alongside the first on a sliding plate (MP40/II, the twin-pack).
static func _twin_mag(b: WeaponModels, _v: Dictionary) -> void:
	var mag: Node3D = _mag(b)
	if mag == null:
		return
	var a: AABB = _bounds(mag)
	if a.size.y < 0.01:
		return
	var dx: float = a.size.x + 0.003
	b.box(Vector3(a.size.x * 0.95, a.size.y * 0.92, minf(a.size.z, 0.05) * 0.95), Vector3(a.get_center().x + dx, a.get_center().y - a.size.y * 0.04, a.get_center().z), "blued", Vector3.ZERO, mag)
	b.box(Vector3(dx + a.size.x, 0.012, minf(a.size.z, 0.05) * 1.1), Vector3(a.get_center().x + dx * 0.5, a.end.y - 0.02, a.get_center().z), "steel", Vector3.ZERO, mag)   # the slide
	b.box(Vector3(dx + a.size.x, 0.006, minf(a.size.z, 0.05) * 1.05), Vector3(a.get_center().x + dx * 0.5, a.position.y + a.size.y * 0.35, a.get_center().z), "steel", Vector3.ZERO, mag)   # clamp


## A detachable box magazine under the action (the trench magazine; the T20 conversion), fitted to the stock's
## underside at the magazine's z.
static func _trench_mag(b: WeaponModels, _v: Dictionary) -> void:
	var mk: Node3D = _mag(b)
	var z: float = (_xf(b, mk).origin.z if mk != null else -0.03) - 0.03
	var s: AABB = _slice(b, z - 0.03, z + 0.03)
	var y0: float = s.position.y + 0.004 if s.size != Vector3.ZERO else -0.03
	var h: float = 0.13
	b.prof(WeaponModels.P([[z - 0.034, y0], [z + 0.034, y0], [z + 0.04, y0 - h * 0.6], [z + 0.048, y0 - h], [z - 0.03, y0 - h], [z - 0.036, y0 - h * 0.55]]), 0.024, "blued")
	b.box(Vector3(0.028, 0.006, 0.084), Vector3(0, y0 - h - 0.002, z + 0.009), "steel")
	for i: int in 3:
		b.box(Vector3(0.0255, 0.003, 0.064), Vector3(0, y0 - 0.03 - i * 0.03, z + 0.004 + i * 0.003), "black")


## The drum swapped for a square belt box with a lid and a carrying handle; the belt still feeds from its top.
static func _belt_box(b: WeaponModels, _v: Dictionary) -> void:
	var mag: Node3D = _mag(b)
	if mag == null:
		return
	var a: AABB = _bounds(mag)
	if a.size.y < 0.01:
		return
	var biggest: MeshInstance3D = null
	var vol: float = 0.0
	for c0: Node in mag.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c0 as MeshInstance3D
		var v: float = mi.mesh.get_aabb().get_volume() if mi.mesh != null else 0.0
		if v > vol:
			vol = v
			biggest = mi
	if biggest != null:
		biggest.visible = false
	var sz: Vector3 = Vector3(maxf(0.08, a.size.x * 1.15), 0.14, 0.11)
	var c: Vector3 = Vector3(a.get_center().x, a.end.y - 0.02 - sz.y * 0.5, a.get_center().z)
	b.box(sz, c, "olive", Vector3.ZERO, mag)
	b.box(Vector3(sz.x + 0.004, 0.012, sz.z + 0.004), c + Vector3(0, sz.y * 0.5, 0), "olive", Vector3.ZERO, mag)   # lid
	b.box(Vector3(0.012, 0.006, 0.06), c + Vector3(0, sz.y * 0.5 + 0.012, 0), "black", Vector3.ZERO, mag)       # handle
	b.box(Vector3(sz.x * 0.8, 0.02, 0.003), c + Vector3(0, 0.02, -sz.z * 0.5 - 0.0015), "cream", Vector3.ZERO, mag)  # stencil


## A longer shotgun magazine tube under the barrel.
static func _tube_ext(b: WeaponModels, _v: Dictionary) -> void:
	var mz: Vector3 = _muzzle(b)
	var y: float = mz.y - 0.03
	b.tube(0.011, 0.011, 0.055, Vector3(0, y, mz.z + 0.07), "blued")
	b.tube(0.0125, 0.0125, 0.012, Vector3(0, y, mz.z + 0.04), "steel")   # end cap
	b.box(Vector3(0.008, 0.026, 0.01), Vector3(0, y + 0.015, mz.z + 0.05), "blued")   # barrel clamp


## A leather shell carrier on the stock's left side, five shells.
static func _shell_belt(b: WeaponModels, _v: Dictionary) -> void:
	var g: AABB = _gun_bounds(b)
	var z: float = g.end.z - 0.17
	var s: AABB = _slice(b, z - 0.04, z + 0.04)
	if s.size == Vector3.ZERO:
		return
	var x: float = s.position.x - 0.004
	var yc: float = s.get_center().y
	b.box(Vector3(0.004, minf(0.075, s.size.y * 0.9), 0.085), Vector3(x + 0.002, yc, z), "leather")
	for i: int in 5:
		var y: float = yc - 0.028 + i * 0.014
		b.tube(0.0058, 0.0058, 0.06, Vector3(x - 0.004, y, z), "red_paint")
		b.tube(0.0062, 0.0062, 0.012, Vector3(x - 0.004, y, z + 0.034), "brass")


# ================================================================== sights

## A telescopic sight on rings over the action. SightPoint goes to the eyepiece centre and FrontSight to the
## objective centre (the tube axis is the sight line, level with the bore), so the ADS pose aims through it;
## meta "scope" makes the HUD draw the scope picture when fully aimed.
static func _scope(b: WeaponModels, v: Dictionary) -> void:
	var sp: Node3D = _mark(b, "SightPoint")
	var fs: Node3D = _mark(b, "FrontSight")
	var spp: Vector3 = _xf(b, sp).origin if sp != null else Vector3(0, 0.05, 0)
	var fsp: Vector3 = _xf(b, fs).origin if fs != null else Vector3(0, 0.05, -0.5)
	var r: float = float(v.get("r", 0.0115))
	var ln: float = float(v.get("len", 0.3))
	var y: float = maxf(spp.y, fsp.y) + float(v.get("h", 0.022)) + r
	var zc: float = spp.z + float(v.get("z", -0.03))
	var eye: float = zc + ln * 0.5
	var obj: float = zc - ln * 0.5
	var kind: String = "black"
	b.tube(r, r, ln * 0.62, Vector3(0, y, zc), kind, "z", null, 20)
	b.tube(r * 1.65, r, ln * 0.22, Vector3(0, y, obj + ln * 0.11), kind, "z", null, 20)      # objective bell
	b.tube(r * 1.35, r, ln * 0.16, Vector3(0, y, eye - ln * 0.08), kind, "z", null, 20)      # eyepiece
	b.tube(r * 0.95, r * 0.95, ln * 0.06, Vector3(0, y + r, zc), kind, "y", null, 12)        # elevation turret
	b.tube(r * 0.8, r * 0.8, ln * 0.06, Vector3(r, y, zc), kind, "x", null, 12)              # windage turret
	for k: float in [-0.28, 0.22]:
		var rz: float = zc + ln * k
		var s: AABB = _slice(b, rz - 0.01, rz + 0.01)
		var base: float = s.end.y if s.size != Vector3.ZERO and s.end.y < y - r else maxf(spp.y, fsp.y) - 0.004
		b.tube(r + 0.0025, r + 0.0025, 0.012, Vector3(0, y, rz), "blued", "z", null, 20)
		b.box(Vector3(0.012, maxf(0.004, y - r - base), 0.012), Vector3(0, (y - r + base) * 0.5, rz), "blued")
		b.box(Vector3(0.02, 0.005, 0.016), Vector3(0, base + 0.0025, rz), "blued")
	b.tube(r * 1.3, r * 1.3, 0.002, Vector3(0, y, eye + 0.0005), "glass", "z", null, 20)
	b.tube(r * 1.6, r * 1.6, 0.002, Vector3(0, y, obj - 0.0005), "glass", "z", null, 20)
	b.sight_mark("SightPoint", Vector3(0, y, eye + 0.001))
	b.sight_mark("FrontSight", Vector3(0, y, obj - 0.001))
	b.root.set_meta("scope", float(v.get("scope", 3.0)))


## Radium dots beside the rear sight and on the front sight's face, a little below the aim points so they never
## sit on the sight line.
static func _radium(b: WeaponModels, v: Dictionary) -> void:
	var g: Array = v.get("glow", [0.55, 1.0, 0.45])
	var gm: StandardMaterial3D = _glow(Color(float(g[0]), float(g[1]), float(g[2])) if g.size() >= 3 else Color(0.55, 1.0, 0.45))
	var sp: Node3D = _mark(b, "SightPoint")
	var fs: Node3D = _mark(b, "FrontSight")
	if sp != null and not b.root.has_meta("scope"):
		for s: float in [-1.0, 1.0]:
			var d: MeshInstance3D = b.box(Vector3(0.0024, 0.0024, 0.0008), sp.position + Vector3(s * 0.0062, -0.0032, 0.0035), "white", Vector3.ZERO, sp.get_parent() as Node3D)
			d.material_override = gm
	if fs != null:
		var f: MeshInstance3D = b.box(Vector3(0.0022, 0.0022, 0.0008), fs.position + Vector3(0, -0.0034, 0.0026), "white", Vector3.ZERO, fs.get_parent() as Node3D)
		f.material_override = gm


## An ivory bead whose top is the existing aim point, on a low matted rib.
static func _bead(b: WeaponModels, _v: Dictionary) -> void:
	var fs: Node3D = _mark(b, "FrontSight")
	var sp: Node3D = _mark(b, "SightPoint")
	if fs == null:
		return
	var r: float = 0.0034
	b.ball(r, fs.position - Vector3(0, r, 0), "cream", Vector3.ONE, fs.get_parent() as Node3D)
	if sp != null and sp.get_parent() == fs.get_parent():
		var y: float = minf(sp.position.y, fs.position.y) - 0.0045
		var z0: float = fs.position.z + 0.012
		var z1: float = sp.position.z - 0.02
		if z1 > z0:
			b.box(Vector3(0.007, 0.002, z1 - z0), Vector3(0, y, (z0 + z1) * 0.5), "blued", Vector3.ZERO, fs.get_parent() as Node3D)


## A spider-web anti-aircraft ring round the front sight: two rings and spokes, the centre left open.
static func _aa_ring(b: WeaponModels, _v: Dictionary) -> void:
	var fs: Node3D = _mark(b, "FrontSight")
	if fs == null:
		return
	var p: Node3D = fs.get_parent() as Node3D
	var c: Vector3 = fs.position + Vector3(0, 0, 0.02)
	b.ring(0.044, 0.0465, c, "steel", "z", p)
	b.ring(0.02, 0.0222, c, "steel", "z", p)
	for i: int in 6:
		var a: float = TAU * float(i) / 6.0 + PI / 6.0
		var d: Vector3 = Vector3(cos(a), sin(a), 0)
		_rod(b, c + d * 0.0215, c + d * 0.0455, 0.0009, "steel", p)
	_rod(b, c + Vector3(0, -0.0455, 0), c + Vector3(0, -0.075, 0), 0.0016, "steel", p)   # its post


# ================================================================== grips, stocks, slings, bipods

## Bipod legs, half-down and splayed, on a clamp under the barrel; replace_legs takes off the model's own legs.
static func _bipod(b: WeaponModels, v: Dictionary) -> void:
	if bool(v.get("replace_legs", false)):
		for n: Node in b.root.find_children("BipodLeg*", "", true, false):
			n.get_parent().remove_child(n)
			n.free()
	var mz: Vector3 = b.root.get_meta("kit_muzzle0", _muzzle(b))
	var z: float = mz.z * 0.72
	var y: float = mz.y
	var kind: String = "fieldgray" if b.root.name == "Model_mg42" else "park"
	b.tube(0.016, 0.016, 0.03, Vector3(0, y, z), kind, "z", null, 16)       # clamp collar
	b.box(Vector3(0.05, 0.012, 0.024), Vector3(0, y - 0.018, z), kind)        # yoke
	for s: float in [-1.0, 1.0]:
		var top: Vector3 = Vector3(s * 0.02, y - 0.022, z)
		var foot: Vector3 = Vector3(s * 0.075, y - 0.22, z - 0.11)
		_rod(b, top, foot, 0.0055, kind)
		_rod(b, top.lerp(foot, 0.45), top.lerp(foot, 0.45) + Vector3(-s * 0.012, -0.004, 0.02), 0.0035, "steel")   # leg lock
		b.box(Vector3(0.03, 0.006, 0.02), foot + Vector3(0, -0.003, 0), "blued")   # foot
		b.wedge(Vector3(0.006, 0.014, 0.006), foot + Vector3(0, -0.012, 0), "steel", Vector3(180, 0, 0))   # spike


## A wooden vertical foregrip ahead of the support hand.
static func _foregrip(b: WeaponModels, _v: Dictionary) -> void:
	var lh: Node3D = b.root.get_node_or_null("LeftHand") as Node3D
	if lh == null or str(b.root.get_meta("lh_axis", "z")) == "y":
		return
	var z: float = lh.position.z - 0.07
	var s: AABB = _slice(b, z - 0.01, z + 0.01)
	var top: float = s.position.y + 0.003 if s.size != Vector3.ZERO else lh.position.y - 0.02
	b.box(Vector3(0.026, 0.012, 0.036), Vector3(0, top - 0.004, z), "blued")
	b.tube(0.0165, 0.0185, 0.09, Vector3(0, top - 0.055, z), "wood", "y")
	for i: int in 4:
		b.ring(0.0175, 0.0192, Vector3(0, top - 0.03 - i * 0.017, z), "wood_light", "y")


## A leather sling from a swivel under the fore-end to one under the butt, with a little sag.
static func _sling(b: WeaponModels, _v: Dictionary) -> void:
	var g: AABB = _gun_bounds(b)
	var mz: Vector3 = b.root.get_meta("kit_muzzle0", _muzzle(b))
	var zf: float = lerpf(mz.z, 0.0, 0.42)
	var zb: float = g.end.z - 0.07
	var sf: AABB = _slice(b, zf - 0.015, zf + 0.015)
	var sbk: AABB = _slice(b, zb - 0.015, zb + 0.015)
	if sf.size == Vector3.ZERO or sbk.size == Vector3.ZERO:
		return
	var a: Vector3 = Vector3(-0.004, sf.position.y - 0.008, zf)
	var c: Vector3 = Vector3(-0.004, sbk.position.y - 0.008, zb)
	var mid: Vector3 = (a + c) * 0.5 + Vector3(0, -0.06, 0)
	for pair: Array in [[a, a.lerp(mid, 0.5) + Vector3(0, -0.012, 0)], [a.lerp(mid, 0.5) + Vector3(0, -0.012, 0), mid],
			[mid, mid.lerp(c, 0.5) + Vector3(0, -0.012, 0)], [mid.lerp(c, 0.5) + Vector3(0, -0.012, 0), c]]:
		var p0: Vector3 = pair[0]
		var p1: Vector3 = pair[1]
		var mi: MeshInstance3D = b.box(Vector3(0.018, 0.003, p0.distance_to(p1) + 0.004), (p0 + p1) * 0.5, "leather")
		mi.basis = Basis.looking_at((p1 - p0).normalized(), Vector3.UP)
	for e: Vector3 in [a, c]:
		b.ring(0.004, 0.0062, e + Vector3(0, 0.004, 0), "steel", "x")   # swivels


## A laced leather cheek pad on the left of the stock's comb.
static func _cheek_pad(b: WeaponModels, _v: Dictionary) -> void:
	var g: AABB = _gun_bounds(b)
	var z1: float = g.end.z - 0.1
	var z0: float = z1 - 0.13
	var s: AABB = _slice(b, z0, z1)
	if s.size == Vector3.ZERO:
		return
	var h: float = minf(0.05, s.size.y * 0.55)
	var y: float = s.end.y - h * 0.5 - 0.004
	b.box(Vector3(0.006, h, z1 - z0), Vector3(s.position.x - 0.002, y, (z0 + z1) * 0.5), "leather")
	for i: int in 6:
		b.box(Vector3(0.0012, h * 0.8, 0.0018), Vector3(s.position.x - 0.0052, y, z0 + 0.012 + i * (z1 - z0 - 0.024) / 5.0), "cream")


## A thick rubber recoil pad on the butt.
static func _recoil_pad(b: WeaponModels, _v: Dictionary) -> void:
	var g: AABB = _gun_bounds(b)
	var s: AABB = _slice(b, g.end.z - 0.03, g.end.z + 0.001)
	if s.size == Vector3.ZERO:
		return
	b.box(Vector3(maxf(0.03, s.size.x), maxf(0.06, s.size.y), 0.02), Vector3(s.get_center().x, s.get_center().y, g.end.z + 0.009), "rubber")
	for i: int in 3:
		b.box(Vector3(maxf(0.03, s.size.x) + 0.001, 0.003, 0.004), Vector3(s.get_center().x, s.get_center().y - s.size.y * 0.25 + i * s.size.y * 0.25, g.end.z + 0.016), "black")


# ================================================================== ammo

## A painted band on the magazine's base (AP black, red, incendiary blue, Nachtglas glowing violet).
static func _band(b: WeaponModels, v: Dictionary) -> void:
	var mag: Node3D = _mag(b)
	if mag == null:
		return
	var a: AABB = _bounds(mag)
	if a.size.y < 0.01:
		return
	var bottom: float = float(mag.get_meta("bottom", a.position.y))
	var kind: String = str(v.get("band", "red"))
	var mi: MeshInstance3D = b.box(Vector3(a.size.x * 1.04, 0.004, minf(a.size.z, 0.07) * 0.9), Vector3(a.get_center().x, bottom + 0.004, a.get_center().z), BAND_KINDS.get(kind, "red_paint"), Vector3.ZERO, mag)
	if kind == "nachtglas":
		mi.material_override = _glow(Color(0.7, 0.35, 1.0), 2.2)
