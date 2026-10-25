class_name PatronBody
extends Node3D
## One of the inn's patrons in Map 0's round 1 opening (T-072, InnOpening): a plain articulated civilian body in the
## style of the teammates' RemoteBody (boxes, spheres and unit cylinders placed between joints every frame, its limb
## solver and placement helpers), dressed from map00_opening.json "look". Local -Z is forward, the origin is at the
## feet. Presentation only: no collider and no hitboxes (shots pass through, nothing walks into them, bots never
## target them). InnOpening moves the node; the body poses itself from `pose` and how fast it is moving.
##
## Poses: sit (on a chair, hands on the table, now and then a drink), lean (an elbow on the bar), work (behind the
## bar, wiping the counter), stand, panic (hands to the head), run (fleeing: chest down, arms pumping, a look back),
## push (both hands forward: the door bar, the door), struggle (fending something off), clutch (bitten: a slow walk
## holding the arm), fall (backwards to the floor), dead (on the back, as a knocked-down zombie lies, so the risen
## zombie's get-up starts where the patron fell).
## The survivors upstairs (T-077, InnSurvivor) add: cower (on the floor against a wall, knees drawn up, arms round
## them, trembling; flinch() ducks the head into the arms) and aim (standing with the rifle shouldered; show_rifle).

const UPPER: float = 0.3
const FORE: float = 0.28
const THIGH: float = 0.44
const SHIN: float = 0.44

var pose: StringName = &"stand"
var patron_id: String = ""
## Set false once they are down or gone: zombies stop going for them (Zombie.prey).
var catchable: bool = true
## Hits taken this run (the zombies' swipes, the bite).
var hits: int = 0
var _pivot: Node3D
var _hips: Node3D
var _chest: Node3D
var _head: Node3D
var _limbs: Dictionary = {}
var _joints: Dictionary = {}
var _mats: Dictionary = {}
var _skirt: MeshInstance3D = null
var _phase: float = 0.0
var _t: float = 0.0
var _pose_t: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO
var _speed: float = 0.0
var _jolt: float = 0.0
var _fall_k: float = 0.0
var _fall_len: float = 0.7
var _build: float = 1.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _blend: Dictionary = {}
var _rifle: Node3D = null
var _flinch: float = 0.0


## Builds the body from a patron row (map00_opening.json patrons[]).
func setup(row: Dictionary) -> void:
	patron_id = str(row.get("id", "patron"))
	name = "Patron_" + patron_id
	_rng.seed = hash(patron_id)
	_t = _rng.randf_range(0.0, 10.0)
	var look: Dictionary = row.get("look", {})
	_build = float(look.get("build", 1.0))
	_mats = {
		"jacket": _mat(_col(look, "jacket", Color(0.3, 0.27, 0.22))), "trousers": _mat(_col(look, "trousers", Color(0.22, 0.2, 0.18))),
		"skin": _mat(_col(look, "skin", Color(0.84, 0.68, 0.58))), "head": _mat(_col(look, "head", Color(0.2, 0.18, 0.15))),
		"scarf": _mat(_col(look, "scarf", Color(0.4, 0.2, 0.16))), "boot": _mat(Color(0.12, 0.09, 0.07)),
		"apron": _mat(Color(0.86, 0.84, 0.78)), "hair": _mat(_col(look, "head", Color(0.25, 0.18, 0.12))),
	}
	_build_body(str(look.get("headgear", "none")), bool(look.get("skirt", false)), bool(look.get("apron", false)), look.has("scarf"))
	pose = StringName(str(row.get("pose", "stand")))
	_last_pos = global_position if is_inside_tree() else position


static func _col(look: Dictionary, key: String, fallback: Color) -> Color:
	var a: Array = look.get(key, [])
	return Color(float(a[0]), float(a[1]), float(a[2])) if a.size() >= 3 else fallback


static func _mat(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: String, scl: Vector3 = Vector3.ONE, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mats[mat]
	mi.position = pos
	mi.scale = scl
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: String, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	return _mesh(parent, bm, pos, mat, Vector3.ONE, rot)


func _sphere(parent: Node3D, r: float, pos: Vector3, mat: String, squash: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 10
	sm.rings = 5
	return _mesh(parent, sm, pos, mat, squash)


func _limb(limb_name: String, r: float, mat: String) -> void:
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r * 0.88
	cm.height = 1.0
	cm.radial_segments = 8
	cm.rings = 1
	_limbs[limb_name] = _mesh(_pivot, cm, Vector3.ZERO, mat)


func _build_body(headgear: String, skirt: bool, apron: bool, scarf: bool) -> void:
	var wd: float = _build
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	_hips = Node3D.new()
	_hips.position = Vector3(0, 0.95, 0)
	_pivot.add_child(_hips)
	_box(_hips, Vector3(0.36 * wd, 0.2, 0.22), Vector3(0, 0.02, 0), "trousers")
	_chest = Node3D.new()
	_chest.position = Vector3(0, 0.12, 0)
	_hips.add_child(_chest)
	_box(_chest, Vector3(0.42 * wd, 0.5, 0.24), Vector3(0, 0.27, 0), "jacket")
	_box(_chest, Vector3(0.44 * wd, 0.08, 0.26), Vector3(0, 0.5, 0), "jacket")
	if apron:
		_box(_chest, Vector3(0.34 * wd, 0.42, 0.02), Vector3(0, 0.2, -0.13), "apron")
	if scarf:
		_box(_chest, Vector3(0.3, 0.07, 0.28), Vector3(0, 0.55, 0), "scarf")
	_head = Node3D.new()
	_head.position = Vector3(0, 0.6, 0)
	_chest.add_child(_head)
	_sphere(_head, 0.06, Vector3(0, 0.02, 0), "skin", Vector3(1, 1.4, 1))
	_sphere(_head, 0.11, Vector3(0, 0.14, -0.01), "skin", Vector3(0.95, 1.1, 1.0))
	_sphere(_head, 0.018, Vector3(0.0, 0.13, -0.115), "skin")
	match headgear:
		"cap":   # a carter's flat cloth cap
			_sphere(_head, 0.122, Vector3(0, 0.235, -0.012), "head", Vector3(1.06, 0.34, 1.12))
			_box(_head, Vector3(0.17, 0.016, 0.085), Vector3(0, 0.215, -0.135), "head", Vector3(-0.18, 0, 0))
		"fieldcap":   # the soldier's side cap (Feldmütze), worn on leave
			_box(_head, Vector3(0.11, 0.07, 0.24), Vector3(0, 0.25, 0.0), "head")
			_sphere(_head, 0.11, Vector3(0, 0.19, 0.0), "hair", Vector3(1.0, 0.55, 1.0))
		"kerchief":   # a headscarf tied under the chin
			_sphere(_head, 0.125, Vector3(0, 0.18, 0.01), "head", Vector3(1.04, 0.95, 1.05))
		"bun":   # hair pinned up
			_sphere(_head, 0.115, Vector3(0, 0.19, 0.015), "hair", Vector3(1.0, 0.75, 1.0))
			_sphere(_head, 0.055, Vector3(0, 0.22, 0.1), "hair")
		_:   # bare-headed, short hair
			_sphere(_head, 0.114, Vector3(0, 0.18, 0.01), "hair", Vector3(1.0, 0.62, 1.0))
	for side: String in ["l", "r"]:
		_limb("upper_" + side, 0.055 * wd, "jacket")
		_limb("fore_" + side, 0.048 * wd, "jacket")
		_limb("thigh_" + side, 0.075, "trousers")
		_limb("shin_" + side, 0.062, "trousers")
		_joints["hand_" + side] = _sphere(_pivot, 0.045, Vector3.ZERO, "skin")
		_joints["foot_" + side] = _box(_pivot, Vector3(0.11, 0.09, 0.26), Vector3.ZERO, "boot")
	if skirt:
		# a wool skirt to below the knee over the thighs: a short cone hung from the hips, posed with them
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.2 * wd
		cm.bottom_radius = 0.27 * wd
		cm.height = 0.6
		cm.radial_segments = 10
		_skirt = _mesh(_hips, cm, Vector3(0, -0.28, 0), "jacket")


# ================================================================== API for InnOpening

func is_catchable() -> bool:
	return catchable and visible


## A zombie's swipe landed (Zombie._update_prey_attack): a jolt; the script decides the rest.
func struck(_by: Node) -> void:
	hits += 1
	_jolt = 1.0
	if pose != &"fall" and pose != &"dead":
		set_pose(&"struggle")


func set_pose(p: StringName) -> void:
	if p == pose:
		return
	pose = p
	_pose_t = 0.0
	if p == &"fall":
		_fall_k = 0.0
		catchable = false
	elif p == &"dead":
		catchable = false
		_fall_k = 1.0
	else:
		_fall_k = 0.0   # back on their feet (a survivor helped up, T-077)


func set_fall_seconds(s: float) -> void:
	_fall_len = maxf(0.2, s)


## A shot close by (T-077): the cowering survivor ducks, arms over the head, for a moment.
func flinch() -> void:
	_flinch = 1.0
	_jolt = maxf(_jolt, 0.5)


## The rifle a survivor was handed (T-077): a plain Kar98k shape along the chest's -Z, shouldered in the aim pose.
func show_rifle(on: bool) -> void:
	if on and _rifle == null:
		_rifle = Node3D.new()
		_rifle.name = "Rifle"
		_rifle.position = Vector3(0.11, 0.36, -0.08)
		_chest.add_child(_rifle)
		var wood: StandardMaterial3D = _mat(Color(0.32, 0.2, 0.11))
		var steel: StandardMaterial3D = _mat(Color(0.12, 0.12, 0.13))
		_mats["rifle_wood"] = wood
		_mats["rifle_steel"] = steel
		_box(_rifle, Vector3(0.05, 0.1, 0.34), Vector3(0, -0.03, 0.08), "rifle_wood")     # the butt at the shoulder
		_box(_rifle, Vector3(0.045, 0.06, 0.62), Vector3(0, 0.0, -0.4), "rifle_wood")     # the stock to the band
		_box(_rifle, Vector3(0.022, 0.022, 0.5), Vector3(0, 0.035, -0.86), "rifle_steel")  # the barrel
		_box(_rifle, Vector3(0.03, 0.04, 0.12), Vector3(0, 0.05, -0.22), "rifle_steel")   # the receiver and bolt
	if _rifle != null:
		_rifle.visible = on


# ================================================================== posing

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_pose_t += delta
	var p_now: Vector3 = global_position
	var v: float = Vector2(p_now.x - _last_pos.x, p_now.z - _last_pos.z).length() / maxf(delta, 0.0001)
	_last_pos = p_now
	_speed = lerpf(_speed, minf(v, 8.0), clampf(delta * 8.0, 0.0, 1.0))
	_jolt = move_toward(_jolt, 0.0, delta * 3.0)
	if pose == &"fall":
		_fall_k = minf(1.0, _fall_k + delta / _fall_len)
		if _fall_k >= 1.0:
			pose = &"dead"
	_flinch = move_toward(_flinch, 0.0, delta * 1.2)
	for k: StringName in [&"sit", &"lean", &"work", &"panic", &"run", &"push", &"struggle", &"clutch", &"cower", &"aim"]:
		var want: float = 1.0 if pose == k else 0.0
		_blend[k] = move_toward(float(_blend.get(k, 1.0 if pose == k else 0.0)), want, delta * 5.0)
	_pose_body(delta)


func _pose_body(delta: float) -> void:
	var moving: bool = _speed > 0.25
	var running: bool = _speed > 1.8
	var stride: float = 1.05 if running else 0.7
	if moving:
		_phase += delta * PI * _speed / stride
	var ph: float = _phase
	var b_sit: float = float(_blend[&"sit"])
	var b_lean: float = float(_blend[&"lean"])
	var b_work: float = float(_blend[&"work"])
	var b_panic: float = float(_blend[&"panic"])
	var b_run: float = float(_blend[&"run"]) * clampf(_speed / 2.5, 0.0, 1.0)
	var b_push: float = float(_blend[&"push"])
	var b_strug: float = float(_blend[&"struggle"])
	var b_clutch: float = float(_blend[&"clutch"])
	var b_cower: float = float(_blend[&"cower"])
	var b_aim: float = float(_blend[&"aim"])
	var tremble: float = sin(_t * 31.0) * 0.012 * b_cower
	var swing: float = (0.5 + 0.35 * b_run) * clampf(_speed / 3.0, 0.0, 1.0) if moving else 0.0
	# --- the fall: backwards about the feet, onto the back (as a knocked-down zombie lies)
	var fk: float = _fall_k * _fall_k * (3.0 - 2.0 * _fall_k)
	_pivot.rotation.x = 1.5 * fk
	_pivot.rotation.z = 0.0
	var twitch: float = 0.0
	if pose == &"dead":
		twitch = sin(_t * 23.0) * 0.04 * clampf(2.5 - _pose_t, 0.0, 1.0)
	# --- hips and chest
	var hip_y: float = 0.95 - (absf(sin(ph)) * 0.04 if moving else 0.0)
	hip_y = lerpf(hip_y, 0.5, b_sit)
	hip_y = lerpf(hip_y, 0.86, b_strug * 0.6)
	hip_y = lerpf(hip_y, 0.17, b_cower)
	_hips.position = Vector3(0, hip_y, lerpf(0.0, 0.08, b_sit) + 0.12 * b_cower)
	var chest_x: float = -0.32 * b_run - 0.12 * b_sit - 0.17 * b_lean - 0.2 * b_work + 0.25 * b_strug - 0.3 * b_clutch - 0.15 * b_push
	chest_x += -0.42 * b_cower - 0.25 * _flinch * b_cower + tremble - 0.04 * b_aim
	chest_x += 0.35 * _jolt + twitch
	_chest.rotation.x = chest_x
	_chest.rotation.y = sin(ph) * 0.1 * swing + 0.25 * b_strug * sin(_t * 9.0) + 0.22 * b_aim
	_chest.rotation.z = 0.12 * b_lean + 0.08 * b_clutch
	# head: looking back over the shoulder now and then while running; down while clutching; shaking in a panic
	var look_back: float = b_run * clampf(sin(_t * 0.9 + 1.0) * 2.0 - 1.2, 0.0, 1.0)
	_head.rotation = Vector3(-0.1 * b_sit - 0.4 * b_clutch - 0.35 * b_cower * (1.0 + _flinch) + 0.05 * b_aim,
		1.4 * look_back + 0.25 * b_panic * sin(_t * 7.0) + 0.3 * b_cower * sin(_t * 0.7) * (1.0 - _flinch) - 0.2 * b_aim, 0.0)
	# --- legs (hip -> knee -> ankle in pivot space)
	var stance: float = 0.1 * _build
	for side: int in [0, 1]:
		var s: String = "l" if side == 0 else "r"
		var sx: float = -stance if side == 0 else stance
		var lph: float = ph + (0.0 if side == 0 else PI)
		var hip: Vector3 = _pivot.to_local(_hips.global_position) + Vector3(sx, -0.06, 0)
		var thigh_a: float = sin(lph) * swing
		var knee_a: float = -maxf(0.0, cos(lph)) * swing * 1.5
		thigh_a = lerpf(thigh_a, 1.55, b_sit)
		knee_a = lerpf(knee_a, -1.55, b_sit)
		thigh_a = lerpf(thigh_a, 0.35 if side == 0 else -0.1, b_strug * 0.7)
		knee_a = lerpf(knee_a, -0.5, b_strug * 0.7)
		thigh_a = lerpf(thigh_a, 2.15 + (0.05 if side == 0 else -0.05), b_cower)   # knees drawn up
		knee_a = lerpf(knee_a, -2.4, b_cower)
		thigh_a = lerpf(thigh_a, 0.12 if side == 0 else -0.08, b_aim)          # a braced stance
		if pose == &"dead" or pose == &"fall":
			thigh_a = lerpf(thigh_a, (-0.3 if side == 0 else 0.5), fk)
			knee_a = lerpf(knee_a, (-0.6 if side == 0 else -0.3), fk)
		var knee: Vector3 = hip + Vector3(0, -cos(thigh_a) * THIGH, -sin(thigh_a) * THIGH)
		var shin_dir: float = thigh_a + knee_a
		var ankle: Vector3 = knee + Vector3(0, -cos(shin_dir) * SHIN, -sin(shin_dir) * SHIN)
		RemoteBody._place(_limbs["thigh_" + s] as MeshInstance3D, hip, knee)
		RemoteBody._place(_limbs["shin_" + s] as MeshInstance3D, knee, ankle)
		var foot: MeshInstance3D = _joints["foot_" + s]
		foot.position = ankle + Vector3(0, -0.02, -0.06)
		foot.rotation = Vector3.ZERO
	if _skirt != null:
		_skirt.rotation.x = -0.5 * b_sit
		_skirt.scale = Vector3(1.0, lerpf(1.0, 0.75, b_sit), 1.0)
	# --- arms: hand targets in chest space, blended per pose
	var cp: Transform3D = _chest.global_transform
	var rest_l: Vector3 = Vector3(-0.26, -0.05, -0.02)
	var rest_r: Vector3 = Vector3(0.26, -0.05, -0.02)
	var pump: float = sin(ph) * 0.28
	var tl: Vector3 = rest_l + Vector3(0, 0.0, -pump * 0.4) * clampf(swing * 2.0, 0.0, 1.0)
	var tr: Vector3 = rest_r + Vector3(0, 0.0, pump * 0.4) * clampf(swing * 2.0, 0.0, 1.0)
	var run_l: Vector3 = Vector3(-0.2, 0.18 + 0.1 * maxf(0.0, -sin(ph)), -0.1 - pump)
	var run_r: Vector3 = Vector3(0.2, 0.18 + 0.1 * maxf(0.0, sin(ph)), -0.1 + pump)
	tl = tl.lerp(run_l, b_run)
	tr = tr.lerp(run_r, b_run)
	var drink: float = clampf(sin(_t * 0.45) * 3.0 - 2.2, 0.0, 1.0)   # now and then the right hand goes to the mouth
	tl = tl.lerp(Vector3(-0.16, 0.2, -0.38), b_sit)
	tr = tr.lerp(Vector3(0.16, 0.2, -0.38).lerp(Vector3(0.05, 0.62, -0.18), drink), b_sit)
	tl = tl.lerp(Vector3(-0.18, 0.22, -0.36), b_lean)
	tr = tr.lerp(Vector3(0.2, 0.05, -0.1).lerp(Vector3(0.05, 0.62, -0.18), drink), b_lean)
	var wipe: Vector2 = Vector2(cos(_t * 4.0), sin(_t * 4.0)) * 0.08
	tl = tl.lerp(Vector3(-0.2, 0.15, -0.3), b_work)
	tr = tr.lerp(Vector3(0.18 + wipe.x, 0.12, -0.45 + wipe.y), b_work)
	var shake: float = sin(_t * 17.0) * 0.02
	tl = tl.lerp(Vector3(-0.11, 0.62 + shake, -0.1), b_panic)
	tr = tr.lerp(Vector3(0.11, 0.62 - shake, -0.1), b_panic)
	var heave: float = 0.05 * sin(_t * 6.0)
	tl = tl.lerp(Vector3(-0.18, 0.42, -0.5 - heave), b_push)
	tr = tr.lerp(Vector3(0.18, 0.42, -0.5 + heave), b_push)
	var fend: float = sin(_t * 11.0) * 0.1
	tl = tl.lerp(Vector3(-0.2, 0.55 + fend, -0.42), b_strug)
	tr = tr.lerp(Vector3(0.22, 0.48 - fend, -0.38), b_strug)
	tl = tl.lerp(Vector3(-0.24, 0.12, -0.1), b_clutch)
	tr = tr.lerp(Vector3(-0.12, 0.3, -0.16), b_clutch)   # the right hand clamped on the bitten left forearm
	# cowering: arms round the knees, trembling; a flinch throws them over the head
	var hug_l: Vector3 = Vector3(-0.13, 0.02 + tremble, -0.36).lerp(Vector3(-0.12, 0.66, -0.12), _flinch)
	var hug_r: Vector3 = Vector3(0.13, 0.04 - tremble, -0.36).lerp(Vector3(0.12, 0.66, -0.12), _flinch)
	tl = tl.lerp(hug_l, b_cower)
	tr = tr.lerp(hug_r, b_cower)
	# aiming: the right hand at the grip, the left under the fore-end (the rifle hangs off the chest)
	tl = tl.lerp(Vector3(0.09, 0.3, -0.52), b_aim)
	tr = tr.lerp(Vector3(0.13, 0.3, -0.2), b_aim)
	if pose == &"dead" or pose == &"fall":
		tl = tl.lerp(Vector3(-0.55, 0.35, 0.1), fk)
		tr = tr.lerp(Vector3(0.5, 0.45, -0.05), fk)
	for side2: int in [0, 1]:
		var s2: String = "l" if side2 == 0 else "r"
		var sh: Vector3 = _pivot.to_local(cp * Vector3((-0.24 if side2 == 0 else 0.24) * _build, 0.5, 0))
		var hand: Vector3 = _pivot.to_local(cp * (tl if side2 == 0 else tr))
		var pole: Vector3 = Vector3(-0.6 if side2 == 0 else 0.6, -1.0, 0.3)
		var elbow: Vector3 = WeaponHolder._solve_elbow(sh, hand, UPPER, FORE, pole)
		RemoteBody._place(_limbs["upper_" + s2] as MeshInstance3D, sh, elbow)
		RemoteBody._place(_limbs["fore_" + s2] as MeshInstance3D, elbow, hand)
		(_joints["hand_" + s2] as MeshInstance3D).position = hand
