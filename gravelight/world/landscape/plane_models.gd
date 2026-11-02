class_name PlaneModels
extends RefCounted
## Code-built aircraft silhouettes for Map 0's sky (Update 02 section 7, T-052): a four-engined night bomber with
## a twin tail and a single-engined fighter, each one ArrayMesh (airframe + the exhausts' glow as a second surface),
## built once and shared. Wingspan 1 m along X, nose toward -Z; flights scale them. They ignore the fog (the
## sky's haze is painted by the dome) and are lit by the moon and the war's flashes.

static var _bomber: ArrayMesh
static var _fighter: ArrayMesh
static var _mosquito: ArrayMesh
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
