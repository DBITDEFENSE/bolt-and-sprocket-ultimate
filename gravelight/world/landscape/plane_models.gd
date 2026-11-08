class_name PlaneModels
extends RefCounted
## Code-built aircraft silhouettes for Map 0's sky (Update 02 section 7, T-052): a four-engined night bomber with
## a twin tail and a single-engined fighter, each one ArrayMesh (airframe + the exhausts' glow as a second surface),
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


static func _add(st: SurfaceTool, mesh: Mesh, xf: Transform3D) -> void:
	st.append_from(mesh, 0, xf)


static func _box(st: SurfaceTool, c: Vector3, s: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	_add(st, Props.unit_box(), Transform3D(Basis.from_euler(rot * (PI / 180.0)) * Basis.from_scale(s), c))


static func _cyl(st: SurfaceTool, c: Vector3, r: float, h: float, rot: Vector3) -> void:
	_add(st, Props.unit_cyl(), Transform3D(Basis.from_euler(rot * (PI / 180.0)) * Basis.from_scale(Vector3(r * 2.0, h, r * 2.0)), c))


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


static func _finish(airframe: SurfaceTool, glow: SurfaceTool) -> ArrayMesh:
	var m: ArrayMesh = airframe.commit()
	glow.commit(m)
	var mats: Array[Material] = _materials()
	m.surface_set_material(0, mats[0])
	m.surface_set_material(1, mats[1])
	return m


## Four engines, long glasshouse nose, twin fins on the tailplane (span 1 along X).
static func bomber() -> ArrayMesh:
	if _bomber != null:
		return _bomber
	var a: SurfaceTool = SurfaceTool.new()
	a.begin(Mesh.PRIMITIVE_TRIANGLES)
	var g: SurfaceTool = SurfaceTool.new()
	g.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cyl(a, Vector3(0, 0, 0.02), 0.045, 0.7, Vector3(90, 0, 0))                     # fuselage
	_box(a, Vector3(0, 0.0, -0.06), Vector3(1.0, 0.012, 0.15))                       # wing
	_box(a, Vector3(0, 0.0, -0.08), Vector3(0.62, 0.016, 0.17))                      # thicker centre section
	for x: float in [-0.32, -0.15, 0.15, 0.32]:
		_cyl(a, Vector3(x, -0.01, -0.13), 0.025, 0.15, Vector3(90, 0, 0))           # nacelles
		_box(g, Vector3(x + 0.012, 0.014, -0.05), Vector3(0.016, 0.012, 0.05))     # exhaust glow over the wing
	_box(a, Vector3(0, 0.005, 0.33), Vector3(0.34, 0.01, 0.07))                      # tailplane
	for x2: float in [-0.17, 0.17]:
		_box(a, Vector3(x2, 0.04, 0.34), Vector3(0.01, 0.09, 0.07))                  # twin fins
	_box(a, Vector3(0, 0.035, -0.12), Vector3(0.05, 0.03, 0.06))                     # canopy
	_bomber = _finish(a, g)
	return _bomber


## A single-engined fighter (span 1 along X).
static func fighter() -> ArrayMesh:
	if _fighter != null:
		return _fighter
	var a: SurfaceTool = SurfaceTool.new()
	a.begin(Mesh.PRIMITIVE_TRIANGLES)
	var g: SurfaceTool = SurfaceTool.new()
	g.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cyl(a, Vector3(0, 0, 0.0), 0.06, 0.82, Vector3(90, 0, 0))
	_box(a, Vector3(0, -0.02, -0.08), Vector3(1.0, 0.018, 0.18))
	_box(a, Vector3(0, 0.0, 0.36), Vector3(0.36, 0.012, 0.09))
	_box(a, Vector3(0, 0.07, 0.37), Vector3(0.012, 0.13, 0.09))
	_box(a, Vector3(0, 0.06, -0.06), Vector3(0.06, 0.05, 0.12))
	for s: float in [-1.0, 1.0]:
		_box(g, Vector3(s * 0.065, 0.0, -0.28), Vector3(0.01, 0.01, 0.05))
	_fighter = _finish(a, g)
	return _fighter


## A twin-engined fast bomber, the RAF's Mosquito (UPDATE 10, T-154: Totenhafen's round-6 low pass): a slim
## fuselage with the cockpit well forward, two engines close in on a wide wing, a single fin (span 1 along X).
static func mosquito() -> ArrayMesh:
	if _mosquito != null:
		return _mosquito
	var a: SurfaceTool = SurfaceTool.new()
	a.begin(Mesh.PRIMITIVE_TRIANGLES)
	var g: SurfaceTool = SurfaceTool.new()
	g.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cyl(a, Vector3(0, 0, 0.04), 0.04, 0.78, Vector3(90, 0, 0))                     # fuselage
	_box(a, Vector3(0, -0.005, -0.06), Vector3(1.0, 0.014, 0.16))                    # wing
	for x: float in [-0.17, 0.17]:
		_cyl(a, Vector3(x, -0.012, -0.12), 0.034, 0.26, Vector3(90, 0, 0))          # nacelles
		_box(g, Vector3(x + 0.03, 0.0, -0.02), Vector3(0.012, 0.01, 0.05))          # exhaust stubs
	_box(a, Vector3(0, 0.004, 0.36), Vector3(0.36, 0.01, 0.08))                      # tailplane
	_box(a, Vector3(0, 0.05, 0.38), Vector3(0.012, 0.1, 0.08))                       # fin
	_box(a, Vector3(0, 0.04, -0.22), Vector3(0.06, 0.035, 0.08))                     # canopy, well forward
	_mosquito = _finish(a, g)
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


## Soviet marking: the red star seen from above on the wing tips and the fin (flat red slabs; a silhouette at range).
static func _stars(m: SurfaceTool, span_x: float, wing_z: float, wing_y: float, fin_y: float = -1.0, fin_z: float = 0.0) -> void:
	for sx: float in [-1.0, 1.0]:
		_box(m, Vector3(sx * span_x, wing_y + 0.011, wing_z), Vector3(0.07, 0.004, 0.07))
	if fin_y > 0.0:
		_box(m, Vector3(0.0, fin_y, fin_z), Vector3(0.014, 0.05, 0.05))


static func _finish_marked(airframe: SurfaceTool, glow: SurfaceTool, mark: SurfaceTool) -> ArrayMesh:
	var m: ArrayMesh = airframe.commit()
	glow.commit(m)
	mark.commit(m)
	var mats: Array[Material] = _materials()
	m.surface_set_material(0, mats[0])
	m.surface_set_material(1, mats[1])
	var red: StandardMaterial3D = StandardMaterial3D.new()
	red.albedo_color = Color(0.55, 0.05, 0.04)
	red.roughness = 0.8
	red.disable_fog = true
	m.surface_set_material(2, red)
	return m


## UPDATE 12 (T-212): the Soviet ground-attack aircraft (Il-2 class), a single inline engine, thick armoured nose,
## straight wing, a long glazed hump behind the pilot, one fin; red stars (span 1 along X, a few hundred triangles).
static func il2() -> ArrayMesh:
	if _il2 != null:
		return _il2
	var a: SurfaceTool = SurfaceTool.new()
	a.begin(Mesh.PRIMITIVE_TRIANGLES)
	var g: SurfaceTool = SurfaceTool.new()
	g.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r: SurfaceTool = SurfaceTool.new()
	r.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cyl(a, Vector3(0, 0, -0.05), 0.062, 0.5, Vector3(90, 0, 0))                     # armoured nose and cockpit tub
	_cyl(a, Vector3(0, 0.0, 0.26), 0.036, 0.36, Vector3(90, 0, 0))                   # tail boom
	_box(a, Vector3(0, -0.015, -0.06), Vector3(1.0, 0.02, 0.2))                       # wing, broad chord
	_box(a, Vector3(0, 0.0, 0.4), Vector3(0.38, 0.012, 0.09))                         # tailplane
	_box(a, Vector3(0, 0.07, 0.41), Vector3(0.012, 0.13, 0.1))                        # fin
	_box(a, Vector3(0, 0.07, 0.02), Vector3(0.06, 0.04, 0.2))                         # canopy and gunner's hump
	_box(a, Vector3(0, -0.06, -0.1), Vector3(0.08, 0.03, 0.12))                       # radiator belly
	for s: float in [-1.0, 1.0]:
		_box(g, Vector3(s * 0.07, 0.0, -0.3), Vector3(0.012, 0.012, 0.06))            # exhaust stacks
	_stars(r, 0.4, -0.06, -0.015, 0.1, 0.41)
	_il2 = _finish_marked(a, g, r)
	return _il2


## UPDATE 12 (T-212): the Soviet twin-engined dive bomber (Pe-2 class): slim fuselage, glazed nose, two engines
## well out on the wing, twin fins on the tailplane; red stars (span 1 along X).
static func pe2() -> ArrayMesh:
	if _pe2 != null:
		return _pe2
	var a: SurfaceTool = SurfaceTool.new()
	a.begin(Mesh.PRIMITIVE_TRIANGLES)
	var g: SurfaceTool = SurfaceTool.new()
	g.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r: SurfaceTool = SurfaceTool.new()
	r.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cyl(a, Vector3(0, 0, 0.02), 0.042, 0.72, Vector3(90, 0, 0))                     # fuselage
	_box(a, Vector3(0, -0.005, -0.04), Vector3(1.0, 0.014, 0.17))                     # wing
	for x: float in [-0.2, 0.2]:
		_cyl(a, Vector3(x, -0.008, -0.1), 0.032, 0.3, Vector3(90, 0, 0))             # engine nacelles, long behind the wing
		_box(g, Vector3(x + 0.02, 0.01, -0.12), Vector3(0.012, 0.01, 0.05))          # exhaust glow
	_box(a, Vector3(0, 0.004, 0.35), Vector3(0.36, 0.01, 0.08))                       # tailplane
	for x2: float in [-0.17, 0.17]:
		_box(a, Vector3(x2, 0.045, 0.36), Vector3(0.01, 0.1, 0.08))                  # twin fins
	_box(a, Vector3(0, 0.04, -0.17), Vector3(0.05, 0.035, 0.11))                      # glazed nose
	_stars(r, 0.44, -0.04, -0.005)
	_pe2 = _finish_marked(a, g, r)
	return _pe2


## UPDATE 12 (T-212): the German night fighter (Bf 110 / Ju 88 night-fighter class): twin engines, long glazed
## canopy, twin end-plate fins and an antenna array on the nose. No insignia of any kind (ART_FACTIONS: the game shows
## no national emblem; the Wiederkehr sunburst is for kit and crates, not aircraft). Span 1 along X.
static func nightfighter() -> ArrayMesh:
	if _nightfighter != null:
		return _nightfighter
	var a: SurfaceTool = SurfaceTool.new()
	a.begin(Mesh.PRIMITIVE_TRIANGLES)
	var g: SurfaceTool = SurfaceTool.new()
	g.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cyl(a, Vector3(0, 0, 0.02), 0.045, 0.8, Vector3(90, 0, 0))                      # fuselage
	_box(a, Vector3(0, -0.01, -0.02), Vector3(1.0, 0.014, 0.15))                      # wing
	for x: float in [-0.15, 0.15]:
		_cyl(a, Vector3(x, -0.01, -0.09), 0.034, 0.26, Vector3(90, 0, 0))            # engine nacelles
		_box(g, Vector3(x + 0.025, 0.012, -0.05), Vector3(0.014, 0.01, 0.05))        # flame-damped exhaust glow
	_box(a, Vector3(0, 0.004, 0.39), Vector3(0.38, 0.01, 0.07))                       # tailplane
	for x2: float in [-0.19, 0.19]:
		_box(a, Vector3(x2, 0.05, 0.4), Vector3(0.01, 0.11, 0.07))                   # end-plate fins
	_box(a, Vector3(0, 0.05, -0.1), Vector3(0.06, 0.04, 0.2))                         # long canopy
	for s: float in [-1.0, 1.0]:
		_box(a, Vector3(s * 0.045, 0.0, -0.46), Vector3(0.008, 0.008, 0.1), Vector3(0, s * 28.0, 0))   # radar antenna array
	_nightfighter = _finish(a, g)
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
