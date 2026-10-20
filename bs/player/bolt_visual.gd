class_name BoltVisual
extends Node3D
## Greybox Bolt (replaced in the M10 art pass; gameplay never references the meshes). Poses follow the web
## build's updatePlayerMesh (index.html:3647): facing from motor.yaw, slam front-flip, dash lean, slide
## lay-back, run cycle whose frequency keeps the planted foot at ground speed, hover dangle, wall slide,
## superhero landing out of a slam, mallet swing arcs and the thrown boomerang.

const ORANGE: Color = Color(1.0, 0.62, 0.22)
const NAVY: Color = Color(0.13, 0.17, 0.27)

var bolt: Bolt
var _root: Node3D
var _torso: Node3D
var _head: Node3D
var _hip_l: Node3D
var _hip_r: Node3D
var _knee_l: Node3D
var _knee_r: Node3D
var _sh_l: Node3D
var _sh_r: Node3D
var _mallet: Node3D
var _thrown: Node3D
var _jet: GPUParticles3D
var _bob: float = 0.0
var _pose: Dictionary = {}


func _ready() -> void:
	bolt = get_parent() as Bolt
	_root = Node3D.new()
	add_child(_root)
	var suit: StandardMaterial3D = _mat(ORANGE)
	var dark: StandardMaterial3D = _mat(NAVY)
	var skin: StandardMaterial3D = _mat(Color(0.86, 0.66, 0.5))
	var metal: StandardMaterial3D = _mat(Color(0.55, 0.57, 0.6), 0.7)
	_torso = Node3D.new()
	_torso.position = Vector3(0, -0.95 + 1.0, 0)
	_root.add_child(_torso)
	_box(_torso, Vector3(0.5, 0.55, 0.3), Vector3(0, 0.2, 0), suit)
	_box(_torso, Vector3(0.52, 0.1, 0.32), Vector3(0, -0.05, 0), dark)                       # belt
	_box(_torso, Vector3(0.34, 0.4, 0.18), Vector3(0, 0.22, -0.24), metal)                  # jetpack
	for x: float in [-0.1, 0.1]:
		_cyl(_torso, 0.05, 0.12, Vector3(x, 0.0, -0.26), dark)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.6, 0)
	_torso.add_child(_head)
	_sphere(_head, 0.2, Vector3.ZERO, skin)
	_box(_head, Vector3(0.34, 0.08, 0.1), Vector3(0, 0.05, 0.16), dark)                     # goggles
	_box(_head, Vector3(0.36, 0.12, 0.36), Vector3(0, 0.17, 0), _mat(Color(0.35, 0.22, 0.12)))   # hair
	_sh_l = _limb(_torso, Vector3(0.32, 0.4, 0), 0.5, suit, skin)
	_sh_r = _limb(_torso, Vector3(-0.32, 0.4, 0), 0.5, suit, skin)
	_hip_l = Node3D.new()
	_hip_l.position = Vector3(0.13, -0.1, 0)
	_torso.add_child(_hip_l)
	_hip_r = Node3D.new()
	_hip_r.position = Vector3(-0.13, -0.1, 0)
	_torso.add_child(_hip_r)
	_knee_l = _leg(_hip_l, dark)
	_knee_r = _leg(_hip_r, dark)
	_mallet = _make_mallet(metal, _mat(Color(0.45, 0.3, 0.16)))
	_sh_r.get_child(1).add_child(_mallet)
	_mallet.position = Vector3(0, -0.25, 0.08)
	_thrown = _make_mallet(metal, _mat(Color(0.45, 0.3, 0.16)))
	_thrown.top_level = true
	_thrown.visible = false
	add_child(_thrown)
	_jet = GPUParticles3D.new()
	_jet.amount = 24
	_jet.lifetime = 0.35
	_jet.emitting = false
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 3.0
	pm.gravity = Vector3(0, 2, 0)
	pm.scale_min = 0.5
	pm.color = Color(1.0, 0.65, 0.16)
	_jet.process_material = pm
	var qm: QuadMesh = QuadMesh.new()
	qm.size = Vector2(0.14, 0.14)
	var jm: StandardMaterial3D = StandardMaterial3D.new()
	jm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	jm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	jm.vertex_color_use_as_albedo = true
	jm.albedo_color = Color(1, 0.7, 0.3)
	qm.material = jm
	_jet.draw_pass_1 = qm
	_jet.position = Vector3(0, -0.15, -0.26)
	_torso.add_child(_jet)


func _process(delta: float) -> void:
	if bolt == null or bolt.motor == null:
		return
	var m: BoltMotor = bolt.motor
	var T: Dictionary = bolt.T
	var dt: float = delta
	_root.rotation.y = m.yaw
	_root.position.y = -m.hy + (0.95 if not m.slide_low else 0.55)
	var h: float = Vector2(m.vel.x, m.vel.z).length()
	# whole-body ability poses
	if m.slam == &"flip":
		_root.rotation.x = (1.0 - m.slam_flip_t / float(T["slam"]["flipTime"])) * TAU
	elif m.slam == &"hang":
		_root.rotation.x = TAU - 0.35 - sin(Time.get_ticks_msec() / 60.0) * 0.04
	elif m.dash_t > 0.0:
		_root.rotation.x = 0.32
	elif m.slide_low:
		_root.rotation.x = -1.15
	else:
		_root.rotation.x = 0.0
	# joint targets per movement state
	var walk: float = float(T["move"]["walk"])
	var sprint: float = float(T["move"]["sprint"])
	var run_k: float = clampf((h - 3.2) / (sprint - 3.2), 0.0, 1.0)
	_bob += dt * h / lerpf(0.3, 0.68, run_k)
	var run: float = clampf(h / 3.2, 0.0, 1.0) * (1.0 if m.on_ground else 0.3)
	var sw: float = sin(_bob)
	var p: Dictionary = {"hipL": 0.0, "hipR": 0.0, "kneeL": 0.0, "kneeR": 0.0, "shL": 0.08, "shR": 0.08, "torso": 0.0}
	var rate: float = 14.0
	if m.land_t > 0.0:
		p = {"hipL": -1.5, "kneeL": 1.9, "hipR": -0.4, "kneeR": 1.2, "torso": 0.55, "shL": 0.8, "shR": -0.4}
		rate = 40.0 if m.land_t > 0.2 else 8.0
	elif m.slide_low:
		p = {"hipL": -1.25, "kneeL": 0.25, "hipR": -1.05, "kneeR": 0.45, "shL": 0.95, "shR": 0.95, "torso": 0.15}
	elif m.slam != &"":
		p = {"hipL": 0.12, "hipR": -0.12, "kneeL": 0.15, "kneeR": 0.15, "shL": -2.7, "shR": -2.7, "torso": 0.1}
		rate = 20.0
	elif m.dash_t > 0.0:
		p = {"shL": 1.15, "shR": 1.15, "hipL": 0.5, "hipR": -0.3, "kneeL": 0.6, "kneeR": 0.9, "torso": 0.35}
		rate = 26.0
	elif not m.on_ground:
		if m.wall_sliding:
			p = {"hipL": -0.9, "hipR": -0.6, "kneeL": 1.3, "kneeR": 1.0, "shL": -1.9, "shR": 0.5, "torso": -0.18}
			rate = 24.0
		elif m.hovering:
			p = {"hipL": 0.35, "hipR": 0.35, "kneeL": 0.55, "kneeR": 0.55, "shL": 0.55 + sin(_bob * 3.0 + 1.0) * 0.08, "shR": 0.55, "torso": 0.12}
		else:
			p = {"hipL": -0.7, "hipR": 0.3, "kneeL": 1.1, "kneeR": 0.4, "shL": -0.6, "shR": 0.4, "torso": 0.05}
	else:
		var amp: float = lerpf(0.55, 0.95, run_k) * run
		p = {"hipL": sw * amp, "hipR": -sw * amp, "kneeL": maxf(0.0, -sw) * amp * 1.3, "kneeR": maxf(0.0, sw) * amp * 1.3,
			"shL": -sw * amp * 0.9, "shR": sw * amp * 0.9, "torso": 0.15 * run_k}
	# mallet swing overrides the right arm
	var mel: BoltMelee = bolt.melee
	if mel != null and mel.attack_t > 0.0:
		var k: float = 1.0 - mel.attack_t / float(mel.attack_def["dur"])
		var vertical: bool = mel.attack_tag in ["ground2", "launcher", "air1"]
		p["shR"] = lerpf(-2.6, 1.1, k) if vertical else lerpf(-1.4, 0.4, k)
		_sh_r.rotation.z = 0.0 if vertical else lerpf(-1.2, 1.4, k)
		rate = 40.0
	else:
		_sh_r.rotation.z = lerpf(_sh_r.rotation.z, 0.0, 1.0 - exp(-12.0 * dt))
	var a: float = 1.0 - exp(-rate * dt)
	_hip_l.rotation.x = lerpf(_hip_l.rotation.x, float(p.get("hipL", 0.0)), a)
	_hip_r.rotation.x = lerpf(_hip_r.rotation.x, float(p.get("hipR", 0.0)), a)
	_knee_l.rotation.x = lerpf(_knee_l.rotation.x, float(p.get("kneeL", 0.0)), a)
	_knee_r.rotation.x = lerpf(_knee_r.rotation.x, float(p.get("kneeR", 0.0)), a)
	_sh_l.rotation.x = lerpf(_sh_l.rotation.x, float(p.get("shL", 0.08)), a)
	_sh_r.rotation.x = lerpf(_sh_r.rotation.x, float(p.get("shR", 0.08)), a)
	_torso.rotation.x = lerpf(_torso.rotation.x, float(p.get("torso", 0.0)), a)
	_jet.emitting = m.hovering
	# thrown boomerang mallet
	if mel != null and mel.throw_active:
		_mallet.visible = false
		_thrown.visible = true
		_thrown.global_position = mel.throw_pos
		_thrown.rotation.y += dt * 3.0
		_thrown.rotation.z += dt * 24.0
	else:
		_mallet.visible = true
		_thrown.visible = false


# ------------------------------------------------------------------ builders

static func _mat(c: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = 0.6
	m.rim_enabled = true          # B&S art direction: rim light
	m.rim = 0.35
	return m


static func _box(p: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var b: BoxMesh = BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	p.add_child(mi)
	return mi


static func _sphere(p: Node3D, r: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var s: SphereMesh = SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	mi.mesh = s
	mi.material_override = mat
	mi.position = pos
	p.add_child(mi)
	return mi


static func _cyl(p: Node3D, r: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var c: CylinderMesh = CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	mi.mesh = c
	mi.material_override = mat
	mi.position = pos
	p.add_child(mi)
	return mi


## Shoulder pivot -> upper arm, elbow pivot (child 1) -> forearm + hand.
func _limb(parent: Node3D, at: Vector3, length: float, sleeve: Material, hand: Material) -> Node3D:
	var sh: Node3D = Node3D.new()
	sh.position = at
	parent.add_child(sh)
	_box(sh, Vector3(0.13, length * 0.5, 0.13), Vector3(0, -length * 0.25, 0), sleeve)
	var el: Node3D = Node3D.new()
	el.position = Vector3(0, -length * 0.5, 0)
	sh.add_child(el)
	_box(el, Vector3(0.12, length * 0.45, 0.12), Vector3(0, -length * 0.22, 0), sleeve)
	_sphere(el, 0.08, Vector3(0, -length * 0.48, 0), hand)
	return sh


func _leg(hip: Node3D, mat: Material) -> Node3D:
	_box(hip, Vector3(0.17, 0.42, 0.17), Vector3(0, -0.21, 0), mat)
	var kn: Node3D = Node3D.new()
	kn.position = Vector3(0, -0.42, 0)
	hip.add_child(kn)
	_box(kn, Vector3(0.16, 0.4, 0.16), Vector3(0, -0.2, 0), mat)
	_box(kn, Vector3(0.18, 0.1, 0.28), Vector3(0, -0.42, 0.05), _mat(Color(0.2, 0.14, 0.1)))
	return kn


func _make_mallet(metal: Material, wood: Material) -> Node3D:
	var m: Node3D = Node3D.new()
	_cyl(m, 0.035, 0.6, Vector3(0, -0.2, 0), wood)
	var head: MeshInstance3D = _box(m, Vector3(0.36, 0.2, 0.22), Vector3(0, -0.5, 0), metal)
	head.rotation.z = 0.0
	return m
