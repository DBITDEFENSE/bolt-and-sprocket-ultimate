class_name GunVisual
extends Node
## Greybox gun in Bolt's right hand (models: GunModels.build, all 16 guns). Finds BoltVisual's right-arm elbow pivot through the
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
	var root: Node3D = Node3D.new()
	root.name = "BoltGun"
	var g: Node3D = Node3D.new()           # model space: barrel along -Z
	g.rotation.x = -PI / 2.0                # -Z -> the forearm's -Y (out of the hand)
	root.add_child(g)
	var barrel_len: float = GunModels.build(g, id, lv, om)
	_muzzle = Node3D.new()
	_muzzle.name = "Muzzle"
	_muzzle.position = Vector3(0, 0.04, -0.2 - barrel_len)
	g.add_child(_muzzle)
	_hand.add_child(root)
	_gun = root
