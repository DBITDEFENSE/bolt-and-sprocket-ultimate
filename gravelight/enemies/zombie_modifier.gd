class_name ZombieBodyModifier
extends SkeletonModifier3D
## Post-animation skeleton pass for one zombie (ZOMBIE_ANIM_SPEC §2 and §4, T-041):
##   - foot IK: the zombie feeds the ground height under each foot (two raycasts in its physics step, within
##     anim.json foot_ik.range_m); this drops the hips to the lower foot and bends each leg (analytic two-bone IK)
##     so both feet meet the ground on stairs, slopes and rubble; the feet keep their animated orientation.
##   - hit springs: the partial-ragdoll feel on flinches without physical bones: each arm chain and the head
##     carry a damped angular spring the zombie kicks on every hit (anim.json flinch.spring), applied on top of
##     the animated pose and settling in ~0.3 s.
## Off beyond foot_ik.off_m (the zombie sets `active`).

var foot_ground_y: PackedFloat32Array = [NAN, NAN]   # skeleton-space ground y under L / R foot, NAN = no hit
var ik_weight: float = 0.0
var max_hip_drop: float = 0.32
var blend_rate: float = 12.0
var spring_k: float = 70.0
var spring_c: float = 9.0
var springs_on: bool = true
var ticks: int = 0

var _hip_drop: float = 0.0
var _foot_lift: PackedFloat32Array = [0.0, 0.0]
var _off: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]   # arm L, arm R, head
var _vel: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _idx: Dictionary = {}
var _len_thigh: float = 0.44
var _len_shin: float = 0.4


func setup(cfg: Dictionary, spring: Dictionary) -> void:
	max_hip_drop = float(cfg.get("max_hip_drop", 0.32))
	blend_rate = float(cfg.get("blend", 12.0))
	spring_k = float(spring.get("stiffness", 70.0))
	spring_c = float(spring.get("damping", 9.0))
	_len_thigh = absf(ZombieRig.rest_offset("LeftLowerLeg").y)
	_len_shin = absf(ZombieRig.rest_offset("LeftFoot").y)


## Kicks a chain's spring: 0 arm L, 1 arm R, 2 head.
func kick(chain: int, impulse: Vector3) -> void:
	if chain >= 0 and chain < 3:
		_vel[chain] += impulse


func springs_active() -> bool:
	for i: int in 3:
		if _off[i].length_squared() > 1e-6 or _vel[i].length_squared() > 1e-5:
			return true
	return false


func _resolve(sk: Skeleton3D) -> void:
	if not _idx.is_empty():
		return
	for b: String in ["Hips", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
			"LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm", "Head"]:
		_idx[b] = sk.find_bone(b)


func _process_modification_with_delta(delta: float) -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null:
		return
	ticks += 1
	_resolve(sk)
	var dt: float = clampf(delta, 0.0, 0.1)
	if springs_on and springs_active():
		_apply_springs(sk, dt)
	_apply_foot_ik(sk, dt)


func _apply_springs(sk: Skeleton3D, dt: float) -> void:
	for i: int in 3:
		var acc: Vector3 = -spring_k * _off[i] - spring_c * _vel[i]
		_vel[i] += acc * dt
		_off[i] += _vel[i] * dt
		if _off[i].length_squared() < 1e-7 and _vel[i].length_squared() < 1e-6:
			_off[i] = Vector3.ZERO
			_vel[i] = Vector3.ZERO
			continue
		var o: Vector3 = _off[i].limit_length(1.2)
		match i:
			0:
				_add_rot(sk, "LeftUpperArm", o)
				_add_rot(sk, "LeftLowerArm", o * 0.5)
			1:
				_add_rot(sk, "RightUpperArm", o)
				_add_rot(sk, "RightLowerArm", o * 0.5)
			2:
				_add_rot(sk, "Head", o)


func _add_rot(sk: Skeleton3D, bone: String, euler: Vector3) -> void:
	var bi: int = int(_idx[bone])
	if bi < 0:
		return
	sk.set_bone_pose_rotation(bi, sk.get_bone_pose_rotation(bi) * Quaternion.from_euler(euler))


func _apply_foot_ik(sk: Skeleton3D, dt: float) -> void:
	var a: float = clampf(dt * blend_rate, 0.0, 1.0)
	var want_drop: float = 0.0
	var lifts: PackedFloat32Array = [0.0, 0.0]
	if ik_weight > 0.001:
		var lo: float = 0.0
		for i: int in 2:
			var gy: float = foot_ground_y[i]
			if is_nan(gy):
				continue
			lo = minf(lo, gy)
		want_drop = maxf(lo, -max_hip_drop) * ik_weight
		for i: int in 2:
			var gy2: float = foot_ground_y[i]
			lifts[i] = (clampf(gy2 - want_drop, 0.0, 0.5) if not is_nan(gy2) else 0.0) * ik_weight
	_hip_drop = lerpf(_hip_drop, want_drop, a)
	for i: int in 2:
		_foot_lift[i] = lerpf(_foot_lift[i], lifts[i], a)
	if absf(_hip_drop) < 0.001 and _foot_lift[0] < 0.001 and _foot_lift[1] < 0.001:
		return
	var hips: int = int(_idx["Hips"])
	sk.set_bone_pose_position(hips, sk.get_bone_pose_position(hips) + Vector3(0, _hip_drop, 0))
	_solve_leg(sk, "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", _foot_lift[0])
	_solve_leg(sk, "RightUpperLeg", "RightLowerLeg", "RightFoot", _foot_lift[1])


## Two-bone IK: raises the ankle by `lift` (skeleton space) keeping the knee in its animated bend plane and the
## foot's animated orientation.
func _solve_leg(sk: Skeleton3D, thigh: String, shin: String, foot: String, lift: float) -> void:
	if lift < 0.0005:
		return
	var fi: int = int(_idx[foot])
	if fi < 0: return
	_solve_leg_target(sk, thigh, shin, foot, sk.get_bone_global_pose(fi).origin + Vector3(0, lift, 0))


## Contact correction uses the same analytic solve as terrain IK, after the additive pose blend.
func solve_foot_target(sk: Skeleton3D, side: String, target: Vector3) -> void:
	_resolve(sk)
	_solve_leg_target(sk, side + "UpperLeg", side + "LowerLeg", side + "Foot", target)


func _solve_leg_target(sk: Skeleton3D, thigh: String, shin: String, foot: String, target: Vector3) -> void:
	var ti: int = int(_idx[thigh])
	var si: int = int(_idx[shin])
	var fi: int = int(_idx[foot])
	if ti < 0 or si < 0 or fi < 0:
		return
	var h: Transform3D = sk.get_bone_global_pose(ti)
	var k: Transform3D = sk.get_bone_global_pose(si)
	var f: Transform3D = sk.get_bone_global_pose(fi)
	var to_t: Vector3 = target - h.origin
	var d: float = clampf(to_t.length(), absf(_len_thigh - _len_shin) + 0.01, _len_thigh + _len_shin - 0.005)
	if to_t.length_squared() < 1e-6:
		return
	var u: Vector3 = to_t.normalized()
	# bend plane from the animated knee; knees bend forward (-Z) if the leg is straight
	var kn: Vector3 = k.origin - h.origin
	var pole: Vector3 = kn - u * kn.dot(u)
	if pole.length_squared() < 1e-5:
		pole = (-h.basis.z) - u * (-h.basis.z).dot(u)
	if pole.length_squared() < 1e-6:
		return
	pole = pole.normalized()
	var cos_h: float = clampf((_len_thigh * _len_thigh + d * d - _len_shin * _len_shin) / (2.0 * _len_thigh * d), -1.0, 1.0)
	var ang_h: float = acos(cos_h)
	var thigh_dir: Vector3 = (u * cos(ang_h) + pole * sin(ang_h)).normalized()
	var knee_new: Vector3 = h.origin + thigh_dir * _len_thigh
	var shin_dir: Vector3 = (target - knee_new).normalized()
	# thigh: rotate its current down axis onto the new direction
	var cur_thigh: Vector3 = (k.origin - h.origin).normalized()
	var rot_t: Quaternion = _arc(cur_thigh, thigh_dir)
	var nh: Transform3D = Transform3D(Basis(rot_t) * h.basis, h.origin)
	sk.set_bone_global_pose(ti, nh)
	var k2: Transform3D = sk.get_bone_global_pose(si)
	var f2: Transform3D = sk.get_bone_global_pose(fi)
	var cur_shin: Vector3 = (f2.origin - k2.origin).normalized()
	var rot_s: Quaternion = _arc(cur_shin, shin_dir)
	sk.set_bone_global_pose(si, Transform3D(Basis(rot_s) * k2.basis, k2.origin))
	var f3: Transform3D = sk.get_bone_global_pose(fi)
	sk.set_bone_global_pose(fi, Transform3D(f.basis, f3.origin))


static func _arc(from: Vector3, to: Vector3) -> Quaternion:
	var d: float = clampf(from.dot(to), -1.0, 1.0)
	if d > 0.99999999:
		return Quaternion.IDENTITY
	var axis: Vector3 = from.cross(to)
	if axis.length_squared() < 1e-9:
		axis = from.cross(Vector3.RIGHT)
		if axis.length_squared() < 1e-9:
			axis = from.cross(Vector3.FORWARD)
	return Quaternion(axis.normalized(), acos(d))
