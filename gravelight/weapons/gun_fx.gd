class_name GunFx
extends Node3D
## Pooled world-space gun effects: ejected casings (one MultiMesh per casing type, so a full LMG belt of
## brass is one draw call), muzzle smoke puffs, bullet-impact dust / sparks / chips, and blood mist.
## Presentation only; everything is preallocated and recycled round-robin. One instance per scene,
## created on first use by GunFx.get_for().

const CASINGS: int = 20                 # per casing type
const CASING_LIFE: float = 1.3
const SMOKE: int = 6
const DUST: int = 10
const SPARKS: int = 8
const MIST: int = 8
## Collider-name hints for surfaces that throw sparks (stone and metal) instead of only dust.
const SPARK_HINTS: PackedStringArray = ["lift", "cage", "grate", "catwalk", "deck", "boxcar", "locomotive", "rail",
	"metal", "iron", "steel", "pipe", "turbine", "stone", "rock", "wall_stone", "brick", "core", "vault", "machine"]

var _cas_mm: Dictionary = {}            # kind -> MultiMeshInstance3D
var _cas: Dictionary = {}               # kind -> Array of state dictionaries
var _cas_next: Dictionary = {}
var _smoke: Array[CPUParticles3D] = []
var _dust: Array[CPUParticles3D] = []
var _sparks: Array[CPUParticles3D] = []
var _mist: Array[CPUParticles3D] = []
var _ns: int = 0
var _nd: int = 0
var _nk: int = 0
var _nm: int = 0
var _live: int = 0                      # casings in flight (skips the update loop when 0)


static func get_for(n: Node) -> GunFx:
	if n == null or not n.is_inside_tree():
		return null
	var tree: SceneTree = n.get_tree()
	var host: Node = tree.current_scene if tree.current_scene != null else tree.root
	var fx: GunFx = host.get_node_or_null("GunFx") as GunFx
	if fx == null:
		fx = GunFx.new()
		fx.name = "GunFx"
		host.add_child(fx)
	return fx


func _ready() -> void:
	top_level = true
	for kind: String in ["pistol", "rifle", "shell"]:
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _casing_mesh(kind)
		mm.instance_count = CASINGS
		for i: int in CASINGS:
			mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.custom_aabb = AABB(Vector3(-4000, -4000, -4000), Vector3(8000, 8000, 8000))
		add_child(mmi)
		_cas_mm[kind] = mmi
		var states: Array = []
		for i: int in CASINGS:
			states.append({"t": 0.0, "p": Vector3.ZERO, "v": Vector3.ZERO, "b": Basis(), "spin": Vector3.ZERO, "floor": -1000.0})
		_cas[kind] = states
		_cas_next[kind] = 0
	var soft: Texture2D = _soft_tex()
	for i: int in SMOKE:
		_smoke.append(_make_particles(_puff_mat(soft, Color(0.62, 0.6, 0.57, 0.55)), 0.14, 6, 1.1, 0.2, 0.7, 40.0, Vector3(0, 0.35, 0),
			_ramp(Color(0.7, 0.68, 0.64, 0.42), Color(0.55, 0.54, 0.52, 0.0)), 0.6, 2.4))
	for i: int in DUST:
		_dust.append(_make_particles(_puff_mat(soft, Color(0.5, 0.46, 0.4, 0.7)), 0.09, 9, 0.55, 0.6, 2.6, 28.0, Vector3(0, -3.0, 0),
			_ramp(Color(0.55, 0.5, 0.43, 0.75), Color(0.45, 0.42, 0.38, 0.0)), 0.6, 2.0))
	var spark_mat: StandardMaterial3D = StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.albedo_color = Color(3.0, 1.8, 0.7)
	spark_mat.vertex_color_use_as_albedo = true
	spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	for i: int in SPARKS:
		var sp: CPUParticles3D = _make_particles(spark_mat, 0.012, 7, 0.22, 3.0, 7.0, 35.0, Vector3(0, -9.8, 0),
			_ramp(Color(1.0, 0.85, 0.5, 1.0), Color(1.0, 0.4, 0.1, 0.0)), 0.6, 1.0)
		_sparks.append(sp)
	for i: int in MIST:
		_mist.append(_make_particles(_puff_mat(soft, Color(0.45, 0.02, 0.03, 0.8)), 0.11, 7, 0.4, 0.4, 1.6, 30.0, Vector3(0, -1.5, 0),
			_ramp(Color(0.5, 0.03, 0.04, 0.85), Color(0.3, 0.0, 0.01, 0.0)), 0.7, 2.6))


func _process(delta: float) -> void:
	if _live <= 0:
		return
	_live = 0
	for kind: String in _cas.keys():
		var mm: MultiMesh = (_cas_mm[kind] as MultiMeshInstance3D).multimesh
		var states: Array = _cas[kind]
		for i: int in states.size():
			var c: Dictionary = states[i]
			var t: float = float(c["t"])
			if t <= 0.0:
				continue
			t -= delta
			c["t"] = t
			if t <= 0.0:
				mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
				continue
			_live += 1
			var v: Vector3 = c["v"]
			var p: Vector3 = c["p"]
			var floor_y: float = float(c["floor"])
			if p.y > floor_y + 0.004 or v.y > 0.0:
				v.y -= 9.8 * delta
				v *= 1.0 - 0.6 * delta
				p += v * delta
				var spin: Vector3 = c["spin"]
				if spin.length_squared() > 0.0001:
					c["b"] = ((c["b"] as Basis) * Basis(spin.normalized(), spin.length() * delta)).orthonormalized()
				if p.y < floor_y:
					p.y = floor_y + 0.004
					if v.y < -0.8:
						v = Vector3(v.x * 0.45, -v.y * 0.3, v.z * 0.45)
						c["spin"] = (c["spin"] as Vector3) * 0.5
					else:
						v = Vector3.ZERO
						c["spin"] = Vector3.ZERO
				c["v"] = v
				c["p"] = p
			mm.set_instance_transform(i, Transform3D(c["b"] as Basis, p))


## Throws one casing from `from` with world velocity `vel`, oriented by `basis` (casing axis = basis Z).
func eject(kind: String, from: Vector3, vel: Vector3, basis: Basis) -> void:
	if not _cas.has(kind):
		kind = "rifle"
	var i: int = int(_cas_next[kind])
	_cas_next[kind] = (i + 1) % CASINGS
	var c: Dictionary = (_cas[kind] as Array)[i]
	c["t"] = CASING_LIFE
	c["p"] = from
	c["v"] = vel
	c["b"] = basis.orthonormalized()
	c["spin"] = Vector3(randf_range(-18, 18), randf_range(-6, 6), randf_range(-25, 25))
	c["floor"] = _floor_below(from)
	_live += 1


func smoke(at: Vector3, dir: Vector3, strength: float = 1.0) -> void:
	var p: CPUParticles3D = _smoke[_ns]
	_ns = (_ns + 1) % SMOKE
	_fire_at(p, at, dir)
	p.amount = clampi(int(4.0 + 4.0 * strength), 3, 8)
	p.initial_velocity_max = 0.7 + 0.8 * strength


## Bullet strike on world geometry: a dust puff along the normal, plus sparks on stone / metal.
func impact(at: Vector3, normal: Vector3, collider: Object) -> void:
	var d: CPUParticles3D = _dust[_nd]
	_nd = (_nd + 1) % DUST
	_fire_at(d, at + normal * 0.02, normal)
	if _sparky(collider):
		var s: CPUParticles3D = _sparks[_nk]
		_nk = (_nk + 1) % SPARKS
		_fire_at(s, at + normal * 0.01, normal)


func blood_mist(at: Vector3, toward: Vector3) -> void:
	var m: CPUParticles3D = _mist[_nm]
	_nm = (_nm + 1) % MIST
	_fire_at(m, at, toward)


# ---------------------------------------------------------------- internals

static func _sparky(collider: Object) -> bool:
	var n: Node = collider as Node
	if n == null:
		return false
	for k: Node in [n, n.get_parent()]:
		if k == null:
			continue
		if k.has_meta("surface"):
			return str(k.get_meta("surface")) in ["metal", "stone"]
		var nm: String = String(k.name).to_lower()
		for h: String in SPARK_HINTS:
			if nm.contains(h):
				return true
	return false


func _fire_at(p: CPUParticles3D, at: Vector3, dir: Vector3) -> void:
	p.global_position = at
	if dir.length_squared() > 0.0001:
		var f: Vector3 = dir.normalized()
		var up: Vector3 = Vector3.UP if absf(f.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
		p.global_basis = Basis.looking_at(-f, up)   # local +Z = dir
	p.restart()
	p.emitting = true


func _floor_below(at: Vector3) -> float:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 3.5, 1)
	var res: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	return float((res["position"] as Vector3).y) if not res.is_empty() else at.y - 3.5


func _make_particles(mat: Material, size: float, amount: int, life: float, v_min: float, v_max: float, spread: float,
		gravity: Vector3, ramp: Gradient, scale_min: float, grow: float) -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = mat
	p.mesh = q
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.92
	p.direction = Vector3(0, 0, 1)
	p.spread = spread
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.gravity = gravity
	p.damping_min = v_max * 0.6
	p.damping_max = v_max * 1.2
	p.scale_amount_min = scale_min
	p.scale_amount_max = 1.0
	var c: Curve = Curve.new()
	c.add_point(Vector2(0.0, 1.0 / grow))
	c.add_point(Vector2(1.0, 1.0))
	p.scale_amount_curve = c
	p.color_ramp = ramp
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


static func _ramp(a: Color, b: Color) -> Gradient:
	var g: Gradient = Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	return g


static func _puff_mat(tex: Texture2D, tint: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = tex
	m.albedo_color = Color(1, 1, 1, 1)
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if tint.r > 0.4 and tint.g < 0.1 else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.roughness = 1.0
	m.disable_receive_shadows = true
	return m


static func _soft_tex() -> Texture2D:
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.55))
	var t: GradientTexture2D = GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


## Casing mesh along +Z: pistol / rifle brass (rifle bottlenecked), or a red paper shotshell with a brass head.
static func _casing_mesh(kind: String) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	var brass: StandardMaterial3D = WeaponModels.base_mat("brass")
	var parts: Array = []
	match kind:
		"pistol":
			parts = [[brass, 0.0058, 0.0058, 0.022, 0.0]]
		"shell":
			parts = [[WeaponModels.base_mat("red_paint"), 0.0102, 0.0102, 0.05, -0.006], [brass, 0.0108, 0.0108, 0.014, 0.024]]
		_:
			parts = [[brass, 0.0062, 0.0062, 0.04, 0.006], [brass, 0.0035, 0.0055, 0.012, -0.019]]
	for p: Array in parts:
		var cm: CylinderMesh = CylinderMesh.new()
		cm.bottom_radius = float(p[1])
		cm.top_radius = float(p[2])
		cm.height = float(p[3])
		cm.radial_segments = 8
		cm.rings = 1
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.append_from(cm, 0, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, float(p[4]))))
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, p[0] as Material)
	return mesh
