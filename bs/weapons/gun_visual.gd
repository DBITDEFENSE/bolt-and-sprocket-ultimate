class_name GunVisual
extends Node
## Greybox gun in Bolt's right hand (replaced in the art pass). Finds BoltVisual's right-arm elbow pivot through the
## "Visual" child (BoltVisual._sh_r -> child 1 = elbow/forearm) without editing it, parents a model there, raises
## the arm while aiming or firing (applied after BoltVisual's own pose each frame), and shows the per-level model
## details (V2..V5) and a gold finish at Ω. Exposes the muzzle for tracers and spawns.

var mgr: WeaponManager
var _shoulder: Node3D = null
var _hand: Node3D = null
var _gun: Node3D = null
var _muzzle: Node3D = null
var _built_for: String = ""
var _kick: float = 0.0
var _raise_t: float = 0.0


func _process(delta: float) -> void:
	if mgr == null or mgr.bolt == null:
		return
	if _hand == null or not is_instance_valid(_hand):
		_find_hand()
		if _hand == null:
			return
	var key: String = "%s:%d:%s" % [mgr.current, mgr.weapon().level() if mgr.weapon() != null else 0, mgr.weapon().omega() if mgr.weapon() != null else false]
	if key != _built_for:
		_build(mgr.current)
		_built_for = key
	var b: Bolt = mgr.bolt
	var meleeing: bool = b.melee != null and float(b.melee.get("attack_t")) > 0.0
	var show: bool = not mgr.holstered and not meleeing and mgr.current != &""
	if _gun != null:
		_gun.visible = show
		_kick = maxf(0.0, _kick - delta * 6.0)
		_gun.position = Vector3(0, -0.24 + _kick * 0.6, 0.02)
	_raise_t = maxf(0.0, _raise_t - delta)
	if show and _shoulder != null and (b.is_aiming() or _raise_t > 0.0 or not mgr.scripted.is_empty() and bool(mgr.scripted.get("fire", false))):
		var pitch: float = b.camera.pitch if b.camera != null else 0.0
		_shoulder.rotation.x = -1.5 + clampf(pitch, -0.6, 0.9) * 0.6
		_shoulder.rotation.z = 0.0


func kick(rad: float) -> void:
	_kick = minf(0.15, _kick + rad * 3.0 + 0.02)
	_raise_t = 0.6


func swap_to(_id: StringName) -> void:
	_built_for = ""
	_raise_t = 0.3


func has_muzzle() -> bool:
	return _muzzle != null and is_instance_valid(_muzzle) and _muzzle.is_inside_tree() and _gun.visible


func muzzle_global() -> Vector3:
	return _muzzle.global_position


func _find_hand() -> void:
	var vis: Node = mgr.bolt.get_node_or_null("Visual")
	if vis == null:
		return
	var sh: Variant = vis.get("_sh_r")
	if sh is Node3D and (sh as Node3D).get_child_count() > 1:
		_shoulder = sh
		_hand = (sh as Node3D).get_child(1) as Node3D


func _build(id: StringName) -> void:
	if _gun != null and is_instance_valid(_gun):
		_gun.queue_free()
	_gun = null
	_muzzle = null
	if id == &"" or _hand == null:
		return
	var w: BSWeapon = mgr.weapon(id)
	var lv: int = w.level() if w != null else 1
	var om: bool = w.omega() if w != null else false
	var col: Color = WeaponData.color(id)
	var trim: Color = Color(1.0, 0.8, 0.25) if om else Color(0.3, 0.32, 0.36)
	var root: Node3D = Node3D.new()
	root.name = "BoltGun"
	var g: Node3D = Node3D.new()           # model space: barrel along -Z
	g.rotation.x = -PI / 2.0                # -Z -> the forearm's -Y (out of the hand)
	root.add_child(g)
	var body: StandardMaterial3D = BoltVisual._mat(col.darkened(0.15), 0.3)
	var dark: StandardMaterial3D = BoltVisual._mat(trim, 0.7 if om else 0.4)
	var glow: StandardMaterial3D = WeaponFX.glow_mat(col)
	var barrel_len: float = 0.4
	match String(id):
		"omni_blaster":
			BoltVisual._box(g, Vector3(0.12, 0.16, 0.34), Vector3(0, 0.02, -0.05), body)
			BoltVisual._box(g, Vector3(0.08, 0.14, 0.08), Vector3(0, -0.1, 0.06), dark)          # grip
			var bar: MeshInstance3D = BoltVisual._cyl(g, 0.035, barrel_len, Vector3(0, 0.04, -0.36), dark)
			bar.rotation.x = PI / 2.0
			if lv >= 2:
				for z: float in [-0.25, -0.32, -0.39]:
					BoltVisual._box(g, Vector3(0.14, 0.02, 0.02), Vector3(0, 0.04, z), BoltVisual._mat(Color(0.75, 0.45, 0.25), 0.8))
			if lv >= 3:
				BoltVisual._box(g, Vector3(0.06, 0.03, 0.1), Vector3(0, 0.11, -0.02), glow)
			if lv >= 5:
				var ring: MeshInstance3D = BoltVisual._cyl(g, 0.05, 0.03, Vector3(0, 0.04, -0.56), WeaponFX.glow_mat(Color("#ff8a2e")))
				ring.rotation.x = PI / 2.0
		"void_ripper":
			BoltVisual._box(g, Vector3(0.14, 0.14, 0.3), Vector3(0, 0, 0), body)
			BoltVisual._sphere(g, 0.1, Vector3(0, 0.02, -0.25), glow)
			for i: int in (2 if lv >= 2 else 1):
				var t: MeshInstance3D = MeshInstance3D.new()
				var tm: TorusMesh = TorusMesh.new()
				tm.inner_radius = 0.11
				tm.outer_radius = 0.14
				t.mesh = tm
				t.material_override = dark
				t.position = Vector3(0, 0.02, -0.2 - i * 0.1)
				t.rotation.x = PI / 2.0
				g.add_child(t)
			barrel_len = 0.42
		"sprocket_zap":
			# Sprocket does the shooting; Bolt holds the uplink remote
			BoltVisual._box(g, Vector3(0.1, 0.05, 0.18), Vector3(0, 0, -0.02), body)
			BoltVisual._cyl(g, 0.01, 0.16, Vector3(0.03, 0.1, -0.08), dark)
			BoltVisual._sphere(g, 0.025, Vector3(0.03, 0.18, -0.08), glow)
			barrel_len = 0.15
		"boom_box":
			BoltVisual._box(g, Vector3(0.3, 0.2, 0.14), Vector3(0, 0.05, -0.1), body)
			for x: float in [-0.08, 0.08]:
				var wf: MeshInstance3D = BoltVisual._cyl(g, 0.055, 0.02, Vector3(x, 0.05, -0.18), BoltVisual._mat(Color(0.75, 0.75, 0.8), 0.8) if lv >= 2 else dark)
				wf.rotation.x = PI / 2.0
			BoltVisual._box(g, Vector3(0.24, 0.02, 0.02), Vector3(0, 0.17, -0.1), dark)          # handle
			if lv >= 5:
				BoltVisual._sphere(g, 0.035, Vector3(0, 0.21, -0.1), BoltVisual._mat(Color(0.9, 0.9, 0.95), 1.0))
			barrel_len = 0.2
		_:
			BoltVisual._box(g, Vector3(0.12, 0.15, 0.32), Vector3(0, 0.02, -0.04), body)
			var bar2: MeshInstance3D = BoltVisual._cyl(g, 0.04, barrel_len, Vector3(0, 0.04, -0.36), dark)
			bar2.rotation.x = PI / 2.0
			BoltVisual._box(g, Vector3(0.05, 0.05, 0.05), Vector3(0, 0.13, -0.05), glow)
	_muzzle = Node3D.new()
	_muzzle.name = "Muzzle"
	_muzzle.position = Vector3(0, 0.04, -0.2 - barrel_len)
	g.add_child(_muzzle)
	_hand.add_child(root)
	_gun = root
