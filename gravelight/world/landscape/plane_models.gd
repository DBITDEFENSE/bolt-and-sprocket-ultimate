class_name PlaneModels
extends RefCounted
## Code-built aircraft silhouettes for Map 0's sky (Update 02 section 7, T-052; shaped in T-253: lofted fuselages,
## tapered wings with dihedral, cowlings, spinners and airscrews, where there were boxes and tubes): a four-engined
## night bomber with a twin tail and a single-engined fighter, each one ArrayMesh (airframe + the exhausts' glow as a second surface),
## built once and shared (UPDATE 12, T-212: the Soviet Il-2 and Pe-2 and the German night fighter now fly Map 0's and
## Kaltenbrunn's sky; the old bomber stays as the fallback). Wingspan 1 m along X, nose toward -Z; flights scale them. They ignore the fog (the
## sky's haze is painted by the dome) and are lit by the moon and the war's flashes.

static var _bomber: ArrayMesh
static var _fighter: ArrayMesh
static var _mosquito: ArrayMesh
static var _il2: ArrayMesh
static var _pe2: ArrayMesh
static var _nightfighter: ArrayMesh
static var _tracer_mat: StandardMaterial3D


static func _materials() -> Array[Material]:
	var body: StandardMaterial3D = StandardMaterial3D.new()
	body.albedo_color = Color(0.09, 0.095, 0.1)
	body.roughness = 0.55
	body.metallic = 0.35
	body.disable_fog = true
	var glow: StandardMaterial3D = StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(4.0, 1.7, 0.6)
	glow.disable_fog = true
	return [body, glow]


# ---------------------------------------------------------------- T-253: shaped airframes (they were boxes and tubes)
# Each aircraft is drawn from a short table: the fuselage's sections, the wing's and the tailplane's stations (tapered,
# with dihedral), the fins' outlines, the engines (a cowling, a spinner and the airscrew's three blades), the
# glazing as low blisters, the exhausts' glow. Still a silhouette for the far sky: under 1,200 triangles each.

## A thin wing section at `x`: six points round a lens (leading edge at z `le`, chord `c`, half thickness `t`).
static func _section(x: float, y: float, le: float, c: float, t: float, flip: bool) -> PackedVector3Array:
	var pts: PackedVector3Array = PackedVector3Array([Vector3(x, y, le), Vector3(x, y + t, le + c * 0.28), Vector3(x, y + t * 0.6, le + c * 0.65),
		Vector3(x, y, le + c), Vector3(x, y - t * 0.45, le + c * 0.65), Vector3(x, y - t * 0.7, le + c * 0.28)])
	if flip:
		pts.reverse()
	return pts


## Both halves of a wing or tailplane through `stations` ([x, y, leading edge z, chord, half thickness], root first).
static func _wing(k: ProcKit, stations: Array) -> void:
	for side: float in [-1.0, 1.0]:
		var rings: Array = []
		for s: Array in stations:
			rings.append(_section(side * float(s[0]), float(s[1]), float(s[2]), float(s[3]), float(s[4]), side < 0.0))
		k.loft("body", rings, true, true, true)


## The fuselage through `secs` ([z, half width, half height, centre y], nose first).
static func _fuse(k: ProcKit, secs: Array, n: int = 10) -> void:
	var rings: Array = []
	for s: Array in secs:
		rings.append(ProcKit.superellipse(Vector3(0, float(s[3]), float(s[0])), Vector3.RIGHT, Vector3.UP, float(s[1]), float(s[2]), 2.2, n))
	k.loft("body", rings, true, true, true)


## A fin standing at `x`: its foot from z to z + chord at height y0, `h` tall, raked back.
static func _fin(k: ProcKit, x: float, y0: float, z: float, chord: float, h: float) -> void:
	var poly: PackedVector2Array = PackedVector2Array([Vector2(z, y0), Vector2(z + chord, y0), Vector2(z + chord, y0 + h * 0.75), Vector2(z + chord * 0.72, y0 + h),
		Vector2(z + chord * 0.4, y0 + h * 0.92)])
	k.prism("body", poly, Transform3D(Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(1, 0, 0)), Vector3(x, 0, 0)), 0.004, 0.0)


## An engine at (x, y): the cowling from z0 back to z1, the spinner ahead of it, the airscrew's disc, the glow of its
## exhaust on the side `glow_side` (0: none).
static func _engine(k: ProcKit, x: float, y: float, z0: float, z1: float, r: float, glow_side: float = 1.0, prop_r: float = 0.075) -> void:
	k.lathe("body", Vector3(x, y, z0 - r * 1.1), Vector3(0, 0, 1), PackedVector2Array([Vector2(0.0, 0.0), Vector2(r * 0.55, r * 0.5), Vector2(r * 0.6, r * 1.1),
		Vector2(r, r * 1.15), Vector2(r, r * 1.1 + (z1 - z0) * 0.55), Vector2(r * 0.35, r * 1.1 + (z1 - z0)), Vector2(0.0, r * 1.1 + (z1 - z0))]), 8)
	_airscrew(k, Vector3(x, y, z0 - r * 0.6), prop_r, x * 7.0)
	if glow_side != 0.0:
		k.box("glow", Vector3(x + glow_side * r * 0.95, y + r * 0.2, z0 + (z1 - z0) * 0.3), Vector3(0.008, 0.008, 0.05))


## Three blades of an airscrew at `c`, radius `r`, turned `phase` (a still frame of it: a disc would be a plate
## against the sky).
static func _airscrew(k: ProcKit, c: Vector3, r: float, phase: float) -> void:
	for b: int in 3:
		var a: float = phase + TAU * float(b) / 3.0
		k.box("body", c + Vector3(cos(a), sin(a), 0) * r * 0.5, Vector3(r, 0.014, 0.004), Basis(Vector3.BACK, a) * Basis(Vector3.RIGHT, 0.5))


static func _blister(k: ProcKit, c: Vector3, half: Vector3) -> void:
	k.blob("body", c, half, Basis.IDENTITY, 0.0, 1, 8, 4, 0.5, 2.2)


## Soviet marking: a red star on and under each wing and on each side of the fin(s) (`fin_x` < 0: no fin star, 0: the
## single fin, > 0: twin fins at +-fin_x). A silhouette's colour at range.
static func _stars(k: ProcKit, span_x: float, wing_z: float, wing_y: float, fin_x: float = -1.0, fin_y: float = 0.0, fin_z: float = 0.0) -> void:
	for sx: float in [-1.0, 1.0]:
		k.star("mark", Vector3(sx * span_x, wing_y + 0.012, wing_z), Vector3.UP, Vector3(0, 0, -1), 0.042)
		k.star("mark", Vector3(sx * span_x, wing_y - 0.012, wing_z), Vector3.DOWN, Vector3(0, 0, -1), 0.042)
	var fins: Array[float] = []
	if fin_x == 0.0:
		fins = [0.0]
	elif fin_x > 0.0:
		fins = [-fin_x, fin_x]
	for fx: float in fins:
		for sx2: float in [-1.0, 1.0]:
			k.star("mark", Vector3(fx + sx2 * 0.0052, fin_y, fin_z), Vector3(sx2, 0, 0), Vector3.UP, 0.026)


## The mesh of a kit whose keys are body, glow and (Soviet) mark, with the materials set.
static func _commit(k: ProcKit, marked: bool) -> ArrayMesh:
	var mk: Array = k.commit()
	var m: ArrayMesh = mk[0]
	var ks: Array = mk[1]
	var mats: Array[Material] = _materials()
	for i: int in ks.size():
		match str(ks[i]):
			"body":
				m.surface_set_material(i, mats[0])
			"glow":
				m.surface_set_material(i, mats[1])
			"mark":
				var red: StandardMaterial3D = StandardMaterial3D.new()
				red.albedo_color = Color(0.55, 0.05, 0.04)
				red.roughness = 0.8
				red.disable_fog = true
				m.surface_set_material(i, red)
	assert(ks.size() == (3 if marked else 2))
	return m


static func _kit() -> ProcKit:
	var k: ProcKit = ProcKit.new()
	k._surface("body")
	k._surface("glow")
	return k


## Four engines, a long nose with its turret, a dorsal and a tail turret, twin fins on the tailplane (span 1 along X).
static func bomber() -> ArrayMesh:
	if _bomber != null:
		return _bomber
	var k: ProcKit = _kit()
	_fuse(k, [[-0.33, 0.012, 0.02, -0.004], [-0.30, 0.03, 0.04, 0.0], [-0.2, 0.04, 0.05, 0.004], [0.02, 0.04, 0.05, 0.004], [0.22, 0.03, 0.04, 0.008], [0.36, 0.014, 0.024, 0.012]])
	_wing(k, [[0.0, 0.0, -0.15, 0.2, 0.014], [0.2, 0.006, -0.13, 0.165, 0.011], [0.42, 0.014, -0.095, 0.1, 0.006], [0.5, 0.018, -0.07, 0.05, 0.003]])
	for x: float in [-0.32, -0.15, 0.15, 0.32]:
		_engine(k, x, -0.004, -0.2 + absf(x) * 0.12, -0.03, 0.024, signf(x))
	_wing(k, [[0.0, 0.012, 0.28, 0.085, 0.005], [0.17, 0.014, 0.295, 0.06, 0.003]])
	for x2: float in [-0.17, 0.17]:
		_fin(k, x2, -0.02, 0.285, 0.075, 0.1)
	_blister(k, Vector3(0, 0.05, -0.2), Vector3(0.03, 0.022, 0.07))
	_blister(k, Vector3(0, 0.055, 0.1), Vector3(0.022, 0.02, 0.025))
	_blister(k, Vector3(0, 0.0, -0.325), Vector3(0.022, 0.024, 0.022))
	_bomber = _commit(k, false)
	return _bomber


## A single-engined fighter (span 1 along X).
static func fighter() -> ArrayMesh:
	if _fighter != null:
		return _fighter
	var k: ProcKit = _kit()
	_fuse(k, [[-0.36, 0.03, 0.035, 0.0], [-0.3, 0.052, 0.06, 0.0], [-0.1, 0.056, 0.066, 0.004], [0.1, 0.045, 0.055, 0.008], [0.3, 0.022, 0.03, 0.014], [0.42, 0.006, 0.014, 0.018]])
	_wing(k, [[0.0, -0.03, -0.18, 0.22, 0.016], [0.3, -0.012, -0.14, 0.15, 0.009], [0.47, 0.0, -0.1, 0.085, 0.005], [0.5, 0.002, -0.08, 0.04, 0.003]])
	_wing(k, [[0.0, 0.012, 0.3, 0.1, 0.006], [0.18, 0.014, 0.32, 0.055, 0.003]])
	_fin(k, 0.0, 0.02, 0.3, 0.11, 0.12)
	_blister(k, Vector3(0, 0.07, -0.04), Vector3(0.03, 0.03, 0.08))
	k.lathe("body", Vector3(0, 0, -0.42), Vector3(0, 0, 1), PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.03, 0.06)]), 8)
	_airscrew(k, Vector3(0, 0, -0.37), 0.14, 0.4)
	for s: float in [-1.0, 1.0]:
		k.box("glow", Vector3(s * 0.056, 0.0, -0.26), Vector3(0.008, 0.01, 0.06))
	_fighter = _commit(k, false)
	return _fighter


## A twin-engined fast bomber, the RAF's Mosquito (UPDATE 10, T-154: Totenhafen's round-6 low pass): a slim
## fuselage with the cockpit well forward, two engines close in on a wide wing, a single fin (span 1 along X).
static func mosquito() -> ArrayMesh:
	if _mosquito != null:
		return _mosquito
	var k: ProcKit = _kit()
	_fuse(k, [[-0.36, 0.01, 0.014, 0.0], [-0.32, 0.03, 0.034, 0.0], [-0.2, 0.038, 0.045, 0.002], [0.05, 0.036, 0.042, 0.004], [0.28, 0.02, 0.026, 0.01], [0.42, 0.005, 0.012, 0.014]])
	_wing(k, [[0.0, -0.006, -0.16, 0.2, 0.013], [0.17, -0.002, -0.15, 0.185, 0.011], [0.42, 0.006, -0.1, 0.1, 0.005], [0.5, 0.008, -0.07, 0.045, 0.003]])
	for x: float in [-0.17, 0.17]:
		_engine(k, x, -0.012, -0.27, 0.06, 0.03, signf(x), 0.09)
	_wing(k, [[0.0, 0.01, 0.32, 0.09, 0.005], [0.18, 0.012, 0.335, 0.05, 0.003]])
	_fin(k, 0.0, 0.016, 0.31, 0.1, 0.1)
	_blister(k, Vector3(0, 0.045, -0.22), Vector3(0.028, 0.025, 0.05))
	_mosquito = _commit(k, false)
	return _mosquito


## A model by its json name ("pe2", "il2", "nightfighter", "mosquito", "fighter"; anything else is the old bomber).
static func by_name(key: String) -> ArrayMesh:
	match key:
		"pe2":
			return pe2()
		"il2":
			return il2()
		"nightfighter":
			return nightfighter()
		"mosquito":
			return mosquito()
		"fighter":
			return fighter()
	return bomber()


## UPDATE 12 (T-212): the Soviet ground-attack aircraft (Il-2 class), a single inline engine, thick armoured nose,
## straight centre section and swept outer wing, a long glazed hump behind the pilot, one fin; red stars (span 1
## along X, under 1,200 triangles).
static func il2() -> ArrayMesh:
	if _il2 != null:
		return _il2
	var k: ProcKit = _kit()
	k._surface("mark")
	_fuse(k, [[-0.33, 0.028, 0.034, 0.0], [-0.28, 0.055, 0.06, -0.004], [-0.1, 0.06, 0.066, -0.004], [0.08, 0.046, 0.055, 0.004], [0.3, 0.022, 0.03, 0.012], [0.44, 0.006, 0.014, 0.016]])
	_wing(k, [[0.0, -0.03, -0.17, 0.24, 0.018], [0.16, -0.026, -0.17, 0.23, 0.016], [0.44, -0.008, -0.11, 0.12, 0.007], [0.5, -0.004, -0.085, 0.055, 0.003]])
	_wing(k, [[0.0, 0.014, 0.33, 0.1, 0.006], [0.19, 0.016, 0.35, 0.055, 0.003]])
	_fin(k, 0.0, 0.02, 0.33, 0.11, 0.125)
	_blister(k, Vector3(0, 0.075, 0.0), Vector3(0.03, 0.03, 0.13))
	k.blob("body", Vector3(0, -0.07, -0.08), Vector3(0.035, 0.022, 0.08), Basis.IDENTITY, 0.0, 1, 8, 4, 0.0, 2.4)   # the radiator bath
	k.lathe("body", Vector3(0, 0, -0.39), Vector3(0, 0, 1), PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.028, 0.06)]), 8)
	_airscrew(k, Vector3(0, 0, -0.34), 0.135, 0.9)
	for s: float in [-1.0, 1.0]:
		k.cyl("body", Vector3(s * 0.2, -0.045, -0.02), Vector3(s * 0.2, -0.085, 0.0), 0.006, 0.006, 4, false)   # the gear's fairings under the wing
		k.blob("body", Vector3(s * 0.2, -0.045, -0.04), Vector3(0.018, 0.022, 0.09), Basis.IDENTITY, 0.0, 1, 6, 3, 0.0, 2.2)
		k.box("glow", Vector3(s * 0.061, 0.0, -0.26), Vector3(0.008, 0.012, 0.07))
	_stars(k, 0.38, -0.05, -0.012, 0.0, 0.09, 0.39)
	_il2 = _commit(k, true)
	return _il2


## UPDATE 12 (T-212): the Soviet twin-engined dive bomber (Pe-2 class): slim fuselage, glazed nose, two engines
## well out on the wing, twin fins on a tailplane with marked dihedral; red stars (span 1 along X).
static func pe2() -> ArrayMesh:
	if _pe2 != null:
		return _pe2
	var k: ProcKit = _kit()
	k._surface("mark")
	_fuse(k, [[-0.35, 0.012, 0.018, -0.006], [-0.31, 0.03, 0.036, 0.0], [-0.18, 0.04, 0.048, 0.004], [0.05, 0.036, 0.042, 0.004], [0.26, 0.02, 0.026, 0.01], [0.38, 0.006, 0.012, 0.014]])
	_wing(k, [[0.0, -0.006, -0.14, 0.2, 0.013], [0.2, -0.002, -0.125, 0.175, 0.011], [0.43, 0.012, -0.075, 0.09, 0.005], [0.5, 0.016, -0.055, 0.04, 0.003]])
	for x: float in [-0.2, 0.2]:
		_engine(k, x, -0.012, -0.25, 0.1, 0.03, signf(x), 0.085)
	_wing(k, [[0.0, 0.012, 0.3, 0.085, 0.005], [0.17, 0.032, 0.31, 0.06, 0.003]])
	for x2: float in [-0.17, 0.17]:
		_fin(k, x2, -0.012, 0.295, 0.07, 0.095)
	_blister(k, Vector3(0, 0.045, -0.2), Vector3(0.027, 0.024, 0.06))
	_blister(k, Vector3(0, -0.01, -0.33), Vector3(0.02, 0.022, 0.024))
	_stars(k, 0.4, -0.04, 0.008, 0.17, 0.045, 0.335)
	_pe2 = _commit(k, true)
	return _pe2


## UPDATE 12 (T-212): the German night fighter (Bf 110 / Ju 88 night-fighter class): twin engines, long glazed
## canopy, twin end-plate fins and an antenna array on the nose. No insignia of any kind (ART_FACTIONS: the game shows
## no national emblem; the Wiederkehr sunburst is for kit and crates, not aircraft). Span 1 along X.
static func nightfighter() -> ArrayMesh:
	if _nightfighter != null:
		return _nightfighter
	var k: ProcKit = _kit()
	_fuse(k, [[-0.38, 0.012, 0.016, 0.0], [-0.33, 0.03, 0.034, 0.0], [-0.18, 0.04, 0.046, 0.002], [0.08, 0.036, 0.042, 0.004], [0.3, 0.02, 0.024, 0.01], [0.44, 0.008, 0.012, 0.012]])
	_wing(k, [[0.0, -0.012, -0.11, 0.19, 0.013], [0.15, -0.01, -0.1, 0.17, 0.011], [0.42, 0.0, -0.055, 0.09, 0.005], [0.5, 0.003, -0.035, 0.04, 0.003]])
	for x: float in [-0.15, 0.15]:
		_engine(k, x, -0.016, -0.24, 0.05, 0.031, signf(x), 0.085)
	_wing(k, [[0.0, 0.01, 0.35, 0.075, 0.005], [0.19, 0.012, 0.36, 0.055, 0.003]])
	for x2: float in [-0.19, 0.19]:
		_fin(k, x2, -0.035, 0.35, 0.075, 0.11)
	_blister(k, Vector3(0, 0.05, -0.1), Vector3(0.028, 0.026, 0.13))
	for s: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			k.beam("body", Vector3(s * 0.012, sy * 0.012, -0.37), Vector3(s * 0.05, sy * 0.035, -0.46), 0.005)   # the radar's antenna array
			k.beam("body", Vector3(s * 0.05, sy * 0.035 - 0.022, -0.46), Vector3(s * 0.05, sy * 0.035 + 0.022, -0.46), 0.004)
	_nightfighter = _commit(k, false)
	return _nightfighter


## The glowing streak of a tracer round (unit length along -Z; flights scale it).
static func tracer_material() -> StandardMaterial3D:
	if _tracer_mat != null:
		return _tracer_mat
	_tracer_mat = StandardMaterial3D.new()
	_tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tracer_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_tracer_mat.albedo_color = Color(2.4, 1.1, 0.35)
	_tracer_mat.disable_fog = true
	return _tracer_mat
