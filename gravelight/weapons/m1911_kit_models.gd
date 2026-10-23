class_name M1911KitModels
extends RefCounted
## The M1911's attachments on the gun model (UPDATE_04 section 6, DECISIONS T-068), built with the WeaponModels
## primitives in the pistol's own frame (barrel along -Z, +Y up, origin at the firing hand; slide top y 0.051, bore
## y 0.0385, muzzle z -0.1725). The same model serves the first-person viewmodel, the third-person RemoteBody gun
## and the bench's close-up, so every part shows everywhere:
##   magazine  the extended box sticks out of the grip; the drum hangs under it (both ride the "Mag" part, so they
##             drop out in the reload);
##   barrel    a protruding match barrel, a ported compensator (its own flash: "KitFlash" jets out of the ports)
##             or the OSS can; the Muzzle marker moves to the new muzzle;
##   sights    radium dots on the standard sights, or a tall adjustable target rear and a high blade. Both are
##             built with the sight helpers, so SightPoint / FrontSight stay on the sight line and the ADS pose
##             (WeaponHolder._compute_ads_pose) stays centred: tools/ads_check.sh checks every combination;
##   grip      a walnut board stock clipped to the heel of the grip, or checkered black grips;
##   ammo      a painted band on the magazine base and the nose of the top round (dark hollow-point cavity, violet
##             Nachtglas glass).
## Finishes (blued, battle-worn, nickel, engraved, Nachtglas inlay) re-colour the metal (finish_mat).

static var _mats: Dictionary = {}


## The look a WeaponInstance asks the model builder for ({} = the plain gun, the shared template).
static func look_of(w: WeaponInstance) -> Dictionary:
	if w == null or not M1911Kit.applies_to(w) or (w.kit.is_empty() and w.finish == &""):
		return {}
	return {"kit": w.kit.duplicate(), "finish": String(w.finish), "sig": w.kit_sig()}


## Flash-size multiplier for the fitted barrel (the can all but hides it; the comp spreads it).
static func flash_scale(w: WeaponInstance) -> float:
	if w == null or w.kit.is_empty():
		return 1.0
	return float((M1911Kit.cfg().get("flash_scale", {}) as Dictionary).get(str(w.kit_mods().get("flash", "")), 1.0))


static func _kit(b: WeaponModels) -> Dictionary:
	return b.look.get("kit", {}) if not b.look.is_empty() else {}


static func _opt(b: WeaponModels, slot: String) -> String:
	return str(_kit(b).get(slot, ""))


# ================================================================== materials

## An emissive material (radium paint, Nachtglas glass, the comp flare).
static func glow_mat(c: Color, energy: float = 2.0, unshaded: bool = false) -> StandardMaterial3D:
	var key: String = "glow_%s_%.2f_%s" % [c.to_html(false), energy, unshaded]
	if not _mats.has(key):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = energy
		if unshaded:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[key] = m
	return _mats[key]


## A finished-steel kind re-coloured for a finish (M1911Kit finishes data): colour, metal and gloss, an engraving
## pattern for "engraved".
static func finish_mat(kind: String, finish: StringName) -> Material:
	var key: String = "%s|%s" % [kind, finish]
	if _mats.has(key):
		return _mats[key]
	var d: Dictionary = M1911Kit.finish_def(finish)
	var base: StandardMaterial3D = WeaponModels.base_mat(kind)
	if d.is_empty() or not d.has("color"):
		_mats[key] = base
		return base
	var m: StandardMaterial3D = base.duplicate() as StandardMaterial3D
	var c: Array = d["color"]
	var tint: Color = Color(float(c[0]), float(c[1]), float(c[2]))
	if kind == "black":
		tint = tint.darkened(0.6)
	elif kind == "steel":
		tint = tint.lightened(0.15)
	m.albedo_color = tint
	m.metallic = float(d.get("metallic", m.metallic))
	m.roughness = float(d.get("roughness", m.roughness))
	if kind == "park_slide" or kind == "park_frame":
		m.albedo_texture = null   # no phosphate mottle under a polished finish
	if bool(d.get("engraved", false)):
		m.albedo_texture = _engrave_tex()
		m.uv1_scale = Vector3(28, 28, 28)
	_mats[key] = m
	return m


## Scrollwork-ish engraving: cellular noise ridges, bright metal with dark cut lines.
static func _engrave_tex() -> Texture2D:
	if _mats.has("engrave_tex"):
		return _mats["engrave_tex"]
	var n: FastNoiseLite = FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_DIV
	n.frequency = 0.06
	n.seed = 1911
	var t: NoiseTexture2D = NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.noise = n
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(0.35, 0.34, 0.32))
	g.set_color(1, Color(1.0, 1.0, 1.0))
	g.add_point(0.55, Color(0.95, 0.94, 0.92))
	t.color_ramp = g
	_mats["engrave_tex"] = t
	return t


static func _glow_color(b: WeaponModels, fallback: Color) -> Color:
	var v: Dictionary = M1911Kit.variant("sights", _opt(b, "sights"), b.upgraded)
	var g: Array = v.get("glow", [])
	return Color(float(g[0]), float(g[1]), float(g[2])) if g.size() >= 3 else fallback


# ================================================================== sights (called from WeaponModels._w_m1911)

## Builds the fitted sights on the slide group `sl` (slide top `top`). Returns false when no sight attachment is
## fitted (the model then builds its standard sights).
static func build_sights(b: WeaponModels, sl: Node3D, top: float) -> bool:
	var opt: String = _opt(b, "sights")
	if opt == "":
		return false
	if opt == "raised_target":
		# a tall adjustable target rear: a base block on the dovetail, a wide notched blade, wings and the
		# elevation screw; and a high front blade on its ramp
		b.box(Vector3(0.0215, 0.0016, 0.0085), Vector3(0, top - 0.0002, 0.0392), "park_slide", Vector3.ZERO, sl)
		b.box(Vector3(0.019, 0.0062, 0.013), Vector3(0, top + 0.0028, 0.039), "blued", Vector3.ZERO, sl)
		for s: float in [-1.0, 1.0]:
			b.box(Vector3(0.0022, 0.0085, 0.011), Vector3(s * 0.0105, top + 0.0055, 0.039), "blued", Vector3.ZERO, sl)
		b.rear_notch(0.0362, top + 0.0058, 0.0088, "blued", 0.0205, 0.0044, sl)
		b.tube(0.0019, 0.0019, 0.0035, Vector3(0, top + 0.0072, 0.0455), "steel", "z", sl, 10)   # elevation screw
		b.prof(WeaponModels.P([[-0.1625, top - 0.0004], [-0.1492, top - 0.0004], [-0.1528, 0.0648], [-0.1582, 0.0648]]), 0.0032, "blued", 0.0, sl)
		b.sight_mark("FrontSight", Vector3(0, 0.0648, (-0.1528 - 0.1582) * 0.5), sl)
		return true
	# radium: the standard sights with three hand-painted dots
	b.prof(WeaponModels.P([[-0.1612, top - 0.0004], [-0.1502, top - 0.0004], [-0.1528, 0.0566], [-0.1585, 0.0566]]), 0.0032, "park_slide", 0.0, sl)
	b.sight_mark("FrontSight", Vector3(0, 0.0566, (-0.1528 - 0.1585) * 0.5), sl)
	b.rear_notch(0.0392, top - 0.0004, 0.0072, "park_slide", 0.0158, 0.0036, sl)
	b.box(Vector3(0.0215, 0.0016, 0.0085), Vector3(0, top - 0.0002, 0.0392), "park_slide", Vector3.ZERO, sl)
	var gm: StandardMaterial3D = glow_mat(_glow_color(b, Color(0.55, 1.0, 0.45)), 3.0)
	for s: float in [-1.0, 1.0]:
		var d: MeshInstance3D = b.box(Vector3(0.0024, 0.0024, 0.0008), Vector3(s * 0.00485, top + 0.0045, 0.0429), "white", Vector3.ZERO, sl)
		d.material_override = gm
	var f: MeshInstance3D = b.box(Vector3(0.0024, 0.0024, 0.0008), Vector3(0, 0.0544, -0.1514), "white", Vector3(-25, 0, 0), sl)
	f.material_override = gm
	return true


# ================================================================== everything else (after the gun is built)

static func dress(b: WeaponModels) -> void:
	if b.root.name != "Model_m1911":
		return
	match _opt(b, "mag"):
		"extended":
			_mag_extended(b, 0.068 if b.upgraded else 0.045)
		"drum":
			_mag_drum(b)
	match _opt(b, "barrel"):
		"match":
			_barrel_match(b)
		"compensator":
			_barrel_comp(b)
		"suppressor":
			_barrel_can(b)
	match _opt(b, "grip"):
		"stock":
			_stock(b)
		"checkered":
			_grips(b)
	if _opt(b, "ammo") != "":
		_ammo(b)
	if str(b.look.get("finish", "")) == "nachtglas_inlay" and not b.upgraded:
		_inlay(b)


static func _mag(b: WeaponModels) -> Node3D:
	return b.root.get_node("Mag") as Node3D


## The magazine body continued below the grip by `ext` m, at the grip's rake, with its own baseplate.
static func _mag_extended(b: WeaponModels, ext: float) -> void:
	var mag: Node3D = _mag(b)
	var k: float = 0.3368   # the magazine's rake: z grows 0.3368 m per m it goes down
	var y0: float = -0.0965
	var y1: float = -0.1015 - ext
	var zf0: float = 0.0535 + (-0.0985 - y0) * k
	var zb0: float = 0.0855 + (-0.0985 - y0) * k
	var zf1: float = 0.0535 + (-0.0985 - y1) * k
	var zb1: float = 0.0855 + (-0.0985 - y1) * k
	b.prof(WeaponModels.P([[zf0, y0], [zb0, y0], [zb1, y1], [zf1, y1]]), 0.0176, "blued", 0.0, mag)
	# witness ribs down the side, and the new baseplate
	for s: float in [-1.0, 1.0]:
		b.box(Vector3(0.0006, ext * 0.8, 0.003), Vector3(s * 0.0089, (y0 + y1) * 0.5, (zf0 + zb0 + zf1 + zb1) * 0.25), "black", Vector3(-18.6, 0, 0), mag)
	var bz0: float = zf1 - 0.004
	var bz1: float = zb1 + 0.004
	b.prof(WeaponModels.P([[bz0 + 0.001, y1], [bz1, y1], [bz1 + 0.0013, y1 - 0.0035], [bz1 - 0.0025, y1 - 0.0052], [bz0 + 0.0015, y1 - 0.0052],
		[bz0 - 0.001, y1 - 0.003]]), 0.0214, "steel", 0.0, mag)
	mag.set_meta("bottom", y1 - 0.0052)


## A drum hung under the grip on a feed tower: the body, its covers, the winding key, two ribs. The Rosary Drum
## is bigger and wears a string of brass beads round its rim.
static func _mag_drum(b: WeaponModels) -> void:
	var mag: Node3D = _mag(b)
	var r: float = 0.05 if b.upgraded else 0.043
	var wdt: float = 0.04 if b.upgraded else 0.036
	var c: Vector3 = Vector3(0, -0.112 - r, 0.072)
	b.prof(WeaponModels.P([[0.0505, -0.1], [0.0915, -0.1], [0.098, -0.118], [0.058, -0.118]]), 0.0185, "blued", 0.0, mag)   # feed tower
	b.tube(r, r, wdt, c, "blued", "x", mag, 28)
	for s: float in [-1.0, 1.0]:
		b.tube(r * 0.93, r * 0.93, 0.003, c + Vector3(s * (wdt * 0.5 + 0.0012), 0, 0), "steel", "x", mag, 28)   # covers
		b.ring(r * 0.86, r * 0.98, c + Vector3(s * (wdt * 0.5 + 0.0028), 0, 0), "black", "x", mag)
	b.ring(r - 0.002, r + 0.0018, c + Vector3(-wdt * 0.22, 0, 0), "black", "x", mag)
	b.ring(r - 0.002, r + 0.0018, c + Vector3(wdt * 0.22, 0, 0), "black", "x", mag)
	# the winding key on the left cover (the side the viewmodel shows)
	var kx: float = -(wdt * 0.5 + 0.006)
	b.tube(0.0055, 0.0055, 0.008, c + Vector3(kx, 0, 0), "steel", "x", mag, 12)
	b.box(Vector3(0.003, 0.026, 0.006), c + Vector3(kx - 0.004, 0.006, 0), "steel", Vector3.ZERO, mag)
	b.ball(0.004, c + Vector3(kx - 0.004, 0.019, 0), "brass", Vector3.ONE, mag)
	if b.upgraded:
		for i: int in 14:
			var a: float = TAU * float(i) / 14.0
			b.ball(0.0034, c + Vector3(wdt * 0.5 + 0.004, cos(a) * (r + 0.001), sin(a) * (r + 0.001)), "brass", Vector3.ONE, mag)
	mag.set_meta("bottom", c.y - r)


## Moves the Muzzle marker to the new crown (the flash and tracers start there).
static func _muzzle_to(b: WeaponModels, z: float) -> void:
	var mz: Node3D = b.root.get_node_or_null("Muzzle") as Node3D
	if mz != null:
		mz.position = Vector3(0, 0.0385, z)
	b.root.set_meta("length", absf(z) + 0.05)


## A hand-fitted target barrel standing proud of the slide, in a match bushing (Vesper Match: brass bands).
static func _barrel_match(b: WeaponModels) -> void:
	var by: float = 0.0385
	b.tube(0.0072, 0.0072, 0.036, Vector3(0, by, -0.1885), "steel", "z", null, 18)
	b.tube(0.0076, 0.0072, 0.003, Vector3(0, by, -0.2055), "steel", "z", null, 18)   # crown
	b.tube(0.0045, 0.0045, 0.002, Vector3(0, by, -0.2072), "black", "z", null, 12)
	b.tube(0.0095, 0.0095, 0.0045, Vector3(0, by, -0.1705), "blued", "z", null, 20)   # match bushing
	if b.upgraded:
		for z: float in [-0.181, -0.197]:
			b.tube(0.0076, 0.0076, 0.0018, Vector3(0, by, z), "brass", "z", null, 18)
	_muzzle_to(b, -0.2085)


## A ported compensator the width of the slide: three top ports, a dark bore. Its flash ("KitFlash") jets up out
## of the ports; the Censer's is violet.
static func _barrel_comp(b: WeaponModels) -> void:
	var kind: String = "brass" if b.upgraded else "park_frame"
	var sec: Array = [Vector2(-0.0115, 0.017), Vector2(0.0115, 0.017), Vector2(0.0117, 0.044), Vector2(0.0097, 0.0493),
		Vector2(0.0066, 0.0505), Vector2(-0.0066, 0.0505), Vector2(-0.0097, 0.0493), Vector2(-0.0117, 0.044)]
	b.xsec(sec, -0.2135, -0.1695, kind, null, 0.0012, 0.0)
	for i: int in 3:
		var z: float = -0.1795 - i * 0.0105
		b.box(Vector3(0.0105, 0.0012, 0.0045), Vector3(0, 0.0506, z), "black")
		for s: float in [-1.0, 1.0]:
			b.box(Vector3(0.0006, 0.007, 0.004), Vector3(s * 0.0118, 0.0415, z), "black")
	b.tube(0.0058, 0.0058, 0.002, Vector3(0, 0.0385, -0.2142), "black", "z", null, 14)
	if b.upgraded:
		for i2: int in 3:
			var g: MeshInstance3D = b.box(Vector3(0.0095, 0.0008, 0.0038), Vector3(0, 0.0507, -0.1795 - i2 * 0.0105), "white")
			g.material_override = glow_mat(Color(0.75, 0.4, 1.0), 2.5)
	_muzzle_to(b, -0.2145)
	# a mesh-less MeshInstance3D holder: WeaponModels.merge_static leaves visual nodes with children alone (the
	# jets need their UVs, which a merge drops)
	var fx: MeshInstance3D = MeshInstance3D.new()
	fx.name = "KitFlash"
	b.root.add_child(fx)
	var flare: Color = Color(0.85, 0.5, 1.6) if b.upgraded else Color(2.0, 1.4, 0.75)
	for i3: int in 3:
		var jet: MeshInstance3D = MeshInstance3D.new()
		jet.mesh = WeaponModels.muzzle_flash_mesh()
		var mat: StandardMaterial3D = (jet.mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
		mat.albedo_color = flare
		jet.material_override = mat
		jet.position = Vector3(0, 0.052, -0.1795 - i3 * 0.0105)
		jet.rotation_degrees = Vector3(90, 0, 0)   # the flash's -Z (forward) turned straight up
		jet.scale = Vector3.ONE * (0.32 if b.upgraded else 0.26)
		jet.set_meta("k", jet.scale.x)
		jet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fx.add_child(jet)


## The OSS trials can: an olive-drab tube with blued end caps, a yellow EXPERIMENTAL band and a brass data plate.
static func _barrel_can(b: WeaponModels) -> void:
	var by: float = 0.0385
	var r: float = 0.0152
	b.tube(0.0095, 0.0095, 0.006, Vector3(0, by, -0.1715), "blued", "z", null, 18)   # the thread adaptor
	b.tube(r, r, 0.15, Vector3(0, by, -0.25), "olive", "z", null, 24)
	for z: float in [-0.1752, -0.3245]:
		b.tube(r + 0.0006, r + 0.0006, 0.005, Vector3(0, by, z), "blued", "z", null, 24)
	b.tube(0.0048, 0.0048, 0.002, Vector3(0, by, -0.3272), "black", "z", null, 12)
	b.tube(r + 0.0003, r + 0.0003, 0.011, Vector3(0, by, -0.212), "cream", "z", null, 24)    # stencil band
	b.box(Vector3(0.0005, 0.008, 0.022), Vector3(-(r + 0.0002), by, -0.262), "brass")    # data plate (left side)
	for i: int in 3:
		b.box(Vector3(0.0006, 0.0009, 0.014 - i * 0.003), Vector3(-(r + 0.0005), by + 0.002 - i * 0.002, -0.262), "black")
	_muzzle_to(b, -0.3275)


## A walnut board stock clipped to the heel of the grip: the board, its steel clip and lug, the buttplate.
static func _stock(b: WeaponModels) -> void:
	b.prof(WeaponModels.P([[0.084, -0.042], [0.25, -0.05], [0.402, -0.058], [0.416, -0.072], [0.42, -0.18], [0.408, -0.193],
		[0.3, -0.168], [0.17, -0.128], [0.112, -0.112], [0.097, -0.1065], [0.091, -0.08]]), 0.03, "wood")
	b.prof(WeaponModels.P([[0.15, -0.075], [0.33, -0.084], [0.33, -0.142], [0.15, -0.105]]), 0.0312, "wood_light")   # a lighter panel inlet
	for s: float in [-1.0, 1.0]:
		b.box(Vector3(0.0022, 0.05, 0.016), Vector3(s * 0.0125, -0.075, 0.091), "blued", Vector3(-21, 0, 0))   # the clip's cheeks
	b.box(Vector3(0.026, 0.008, 0.02), Vector3(0, -0.1035, 0.0985), "blued")      # the heel lug
	b.tube(0.0026, 0.0026, 0.028, Vector3(0, -0.066, 0.09), "steel", "x", null, 10)  # its cross pin
	b.box(Vector3(0.033, 0.14, 0.006), Vector3(0, -0.126, 0.421), "blued", Vector3(-2, 0, 0))   # buttplate
	b.box(Vector3(0.008, 0.012, 0.03), Vector3(0, -0.16, 0.35), "steel")          # sling swivel


## Checkered black grip panels over the walnut, with raised diamonds, and a stippled front strap.
static func _grips(b: WeaponModels) -> void:
	var pts: Array = b.root.get_meta("grip_panel", [])
	if pts.is_empty():
		return
	var fw: float = 0.0111
	var kind: String = "wood_check" if b.upgraded else "bakelite"
	for s: float in [-1.0, 1.0]:
		var px: float = s * (fw + 0.0023)
		b.prof(WeaponModels.P(pts), 0.0036, kind, px)
		# raised diamonds in a 4 x 8 field, turned 45 degrees in the panel plane
		for row: int in 8:
			for col: int in 4:
				var y: float = -0.0135 - row * 0.0095
				var z: float = 0.034 + col * 0.0075 + (-0.0135 - y) * 0.353
				b.box(Vector3(0.0008, 0.0038, 0.0038), Vector3(px + s * 0.0021, y, z), kind, Vector3(45, 0, 0))
		if b.upgraded:
			b.ball(0.0036, Vector3(px + s * 0.0022, -0.05, 0.05), "brass", Vector3(0.35, 1, 1))   # Confessor's medallions
	for i: int in 9:
		var gy: float = lerpf(-0.012, -0.09, float(i) / 8.0)
		b.box(Vector3(0.017, 0.0009, 0.0012), Vector3(0, gy, 0.016 + (-0.004 - gy) * 0.363 - 0.0004), "black", Vector3(20, 0, 0))


## The ammo: a painted band on the magazine's base, and the visible top round's nose (a dark hollow-point
## cavity, or violet Nachtglas glass that glows).
static func _ammo(b: WeaponModels) -> void:
	var mag: Node3D = _mag(b)
	var tip: String = str(M1911Kit.variant("ammo", _opt(b, "ammo"), b.upgraded).get("tip", ""))
	var nacht: bool = tip == "nachtglas"
	var band: Material = glow_mat(Color(0.7, 0.35, 1.0), 2.2) if nacht else WeaponModels.base_mat("red_paint")
	var bottom: float = float(mag.get_meta("bottom", -0.1078))
	var bz: float = 0.0705 + (-0.1028 - bottom) * 0.3368
	if _opt(b, "mag") == "drum":
		var d: MeshInstance3D = b.box(Vector3(0.042 if b.upgraded else 0.038, 0.004, 0.012), Vector3(0, bottom + 0.0015, 0.072), "white", Vector3.ZERO, mag)
		d.material_override = band
	else:
		var p: MeshInstance3D = b.box(Vector3(0.0222, 0.002, 0.03), Vector3(0, bottom + 0.0012, bz), "white", Vector3.ZERO, mag)
		p.material_override = band
	if nacht:
		var n: MeshInstance3D = b.ball(0.0058, Vector3(0, -0.0008, 0.0298), "white", Vector3(1, 1, 1.3), mag)
		n.material_override = glow_mat(Color(0.62, 0.3, 1.0), 3.0)
	else:
		b.tube(0.0024, 0.0024, 0.0012, Vector3(0, -0.0008, 0.0228), "black", "z", mag, 10)


## The Nachtglas Inlay finish: violet glass lines let into both slide flats.
static func _inlay(b: WeaponModels) -> void:
	var sl: Node3D = b.root.get_node_or_null("Slide") as Node3D
	if sl == null:
		return
	var d: Dictionary = M1911Kit.finish_def(&"nachtglas_inlay")
	var c: Array = d.get("inlay", [0.62, 0.3, 1.0])
	var gm: StandardMaterial3D = glow_mat(Color(float(c[0]), float(c[1]), float(c[2])), 2.4)
	for s: float in [-1.0, 1.0]:
		for y: float in [0.0335, 0.0425]:
			var l: MeshInstance3D = b.box(Vector3(0.0004, 0.0009, 0.082), Vector3(s * 0.0119, y, -0.081), "white", Vector3.ZERO, sl)
			l.material_override = gm
		var dmd: MeshInstance3D = b.box(Vector3(0.0004, 0.006, 0.006), Vector3(s * 0.0119, 0.038, -0.034), "white", Vector3(45, 0, 0), sl)
		dmd.material_override = gm


# ================================================================== the flash

## Shows the compensator's port jets for one shot.
static func pulse_flash(fx: Node3D, seconds: float) -> void:
	if fx == null or not fx.is_inside_tree():
		return
	for c: Node in fx.get_children():
		if c is Node3D:
			var k: float = randf_range(0.8, 1.2) * float(c.get_meta("k", 0.28))
			(c as Node3D).scale = Vector3(k, k, k * randf_range(0.8, 1.3))
	fx.show()
	fx.get_tree().create_timer(maxf(0.03, seconds)).timeout.connect(fx.hide)
