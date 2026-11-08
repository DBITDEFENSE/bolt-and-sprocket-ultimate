class_name MocapModifier
extends SkeletonModifier3D
## T-210: plays one mocap clip (MocapLibrary) on a stand-in's PersonRig skeleton for a cutscene shot. A modifier runs
## after the pose solver (PatronBody / RemoteBody hand PersonRig.drive() their procedural pose every frame), so the
## clip simply wins while it plays and the stand-in animation is back the moment the modifier goes: nothing in the
## bodies changes. The clock is the director's (cutscene seconds since the shot began), so a skip, a fast-forward or
## Campaign.cutscene_speed keep it in step; past its end the clip holds its last frame.
##   root "mocap"  the take's own walking places the body: the body stays where it stood when the shot began
##                 (`start_xf`, the skeleton's global transform then, turned to the shot's facing) plus the clip's
##                 hips path, whatever the cast does with the node meanwhile;
##   root "cast"   the clip plays in place (hips x / z dropped) and loops, and the node moves along the cast's path.
## `blend_in` eases the clip in over that many seconds (a blend cut); 0 = at once (a cut hides the change).

var anim: Animation = null
var key: String = ""
var in_place: bool = false
var blend_in: float = 0.0
var start_xf: Transform3D = Transform3D.IDENTITY
var t0: float = 0.0
var hidden: Array[Node3D] = []
var _dir: WeakRef = null
var _manual_t: float = -1.0
var _bones: Dictionary = {}     # track -> bone index
var _hips_pos: int = -1
var _hips_rot: int = -1


## A modifier for clip `a` under `sk`, timed by `director` from its time `t_start`.
static func attach(sk: Skeleton3D, a: Animation, k: String, director: Object, t_start: float, blend: float = 0.0) -> MocapModifier:
	var m: MocapModifier = MocapModifier.new()
	m.name = "Mocap"
	m.anim = a
	m.key = k
	m.t0 = t_start
	m.blend_in = blend
	m.in_place = str(a.get_meta(&"root", "mocap")) == "cast"
	m._dir = weakref(director) if director != null else null
	sk.add_child(m)
	m.start_xf = sk.global_transform if sk.is_inside_tree() else sk.transform
	m._bind()
	return m


func _bind() -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null:
		sk = get_parent() as Skeleton3D
	if sk == null or anim == null:
		return
	for i: int in anim.get_track_count():
		var b: String = str(anim.track_get_path(i).get_concatenated_subnames())
		var bi: int = sk.find_bone(b)
		if bi < 0:
			continue
		match anim.track_get_type(i):
			Animation.TYPE_POSITION_3D:
				if b == "Hips":
					_hips_pos = i
			Animation.TYPE_ROTATION_3D:
				_bones[i] = bi
				if b == "Hips":
					_hips_rot = i


## Turns the start frame's facing to `yaw` (radians, Godot's: 0 = -Z) about its own origin.
func face(yaw: float) -> void:
	var fwd: Vector3 = -start_xf.basis.z
	var cur: float = atan2(-fwd.x, -fwd.z)
	start_xf.basis = Basis(Vector3.UP, yaw - cur) * start_xf.basis


## Seconds into the clip now (the director's clock; a test can set it by hand with `at()`).
func clip_time() -> float:
	if _manual_t >= 0.0:
		return _manual_t
	if _dir == null:
		return 0.0
	var d: Object = _dir.get_ref()
	if d == null:
		return -1.0
	return float(d.get("t")) - t0


func at(t: float) -> void:
	_manual_t = maxf(0.0, t)


func _process_modification_with_delta(_delta: float) -> void:
	var t: float = clip_time()
	if t < 0.0:   # the director is gone: so is the clip
		queue_free()
		return
	apply(t)


## Writes the clip's pose at `t` onto the skeleton (public: tests call it without the render loop).
func apply(t: float) -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null:
		sk = get_parent() as Skeleton3D
	if sk == null or anim == null:
		return
	var len_s: float = anim.length
	var tt: float = fposmod(t, len_s) if in_place and len_s > 0.0 else clampf(t, 0.0, len_s)
	influence = clampf(t / blend_in, 0.0, 1.0) if blend_in > 0.0 else 1.0
	for tr: Variant in _bones.keys():
		sk.set_bone_pose_rotation(int(_bones[tr]), anim.rotation_track_interpolate(int(tr), tt))
	if _hips_pos < 0:
		return
	var hb: int = sk.find_bone("Hips")
	var p: Vector3 = anim.position_track_interpolate(_hips_pos, tt)
	if in_place:
		var p0: Vector3 = anim.position_track_interpolate(_hips_pos, 0.0)
		sk.set_bone_pose_position(hb, Vector3(p0.x, p.y, p0.z))
		return
	# root motion: the body stays where it began, whatever moves the node; the correction is rigid (same scale)
	var now: Transform3D = sk.global_transform if sk.is_inside_tree() else sk.transform
	var c: Transform3D = now.affine_inverse() * start_xf
	var cb: Basis = c.basis.orthonormalized()
	sk.set_bone_pose_position(hb, c.origin + cb * p * _scale_ratio(now))
	if _hips_rot >= 0:
		sk.set_bone_pose_rotation(hb, (cb.get_rotation_quaternion() * anim.rotation_track_interpolate(_hips_rot, tt)).normalized())


func _scale_ratio(now: Transform3D) -> float:
	var a: float = start_xf.basis.get_scale().x
	var b: float = now.basis.get_scale().x
	return 1.0 if b < 1e-6 else a / b


func _exit_tree() -> void:
	for h: Node3D in hidden:
		if is_instance_valid(h):
			h.visible = true
	hidden.clear()
