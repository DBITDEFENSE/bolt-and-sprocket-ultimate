extends Node
## T-206 dev tool: plays a LAZARUS cutscene headless (CinemaReel, as the Archive does) and logs, at a few moments of
## every shot, where the camera is and what every person on the stage is doing: distance and off-axis angle to the
## lens (in frame or not at the shot's lens), speed over the ground (a walk reads only above 0.25 m/s; above 2 m/s
## it is a run), the head's and hands' heights, props in hands, and anything of a body within 0.4 m of the lens
## (the camera inside a shoulder). Pure numbers: the director's eye without a GPU. The shot list's blocking can be
## checked against them (docs/CUTSCENE_POLISH.md).
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/probe_cinema_pose.tscn -- \
##        --cut=lazarus_saturday [--speed=2] [--near=40] [--only=3,4,5]
## Prints "[probe] ..." lines and "[probe] RESULT: DONE".

var cut: String = "lazarus_saturday"
var speed: float = 2.0
var near_m: float = 40.0
var only: Array = []
var _reel: CinemaReel = null
var _shot_i: int = -1
var _shot_t0: float = 0.0
var _marks: Array = []
var _done: bool = false


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--cut="):
			cut = a.substr(6)
		elif a.begins_with("--speed="):
			speed = maxf(0.25, float(a.substr(8)))
		elif a.begins_with("--near="):
			near_m = float(a.substr(7))
		elif a.begins_with("--only="):
			for s: String in a.substr(7).split(","):
				only.append(int(s))
	ProfileSave.path = "user://_qa_probe_cinema_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_probe_cinema_settings.cfg"
	GLSettings.values["bot_local_ai"] = false
	GLSettings.values["screen_shake"] = 0.0
	if not CinemaLibrary.has_cut(cut):
		print("[probe] RESULT: FAIL unknown cut %s" % cut)
		get_tree().quit(1)
		return
	Campaign.cutscene_speed = speed
	_reel = CinemaReel.play(self, [cut], {"speed": speed, "roster": ["dutch", "peg", "deacon", "wren"]})
	_reel.finished.connect(func() -> void:
		_done = true
		print("[probe] RESULT: DONE")
		get_tree().quit(0))
	await get_tree().process_frame
	if _reel.director != null:
		_reel.director.shot_started.connect(_on_shot)
	print("[probe] %s at speed %.1f" % [cut, speed])


func _on_shot(i: int, s: CinemaShot) -> void:
	_shot_i = i
	_shot_t0 = s.t
	var d: float = s.dur
	_marks = [0.4, d * 0.5, maxf(0.5, d - 0.4)]
	print("[probe] ---- shot %d  t=%.1f  dur=%.1f  set=%s  fx=%s  move=%s  %s" % [i, s.t, d, str(s.raw.get("_set", "")),
		str(s.raw.get("fx", "")), s.move, str(s.raw.get("_what", "")).left(90)])


func _process(_delta: float) -> void:
	if _done or _reel == null or _reel.director == null or _shot_i < 0:
		return
	var d: CinemaDirector = _reel.director
	var lt: float = d.t - _shot_t0
	if _marks.is_empty() or lt < float(_marks[0]):
		return
	var mark: float = float(_marks.pop_front())
	if not only.is_empty() and not only.has(_shot_i):
		return
	var s: CinemaShot = d.shots[_shot_i]
	if bool(s.raw.get("black", false)):
		return
	_dump(d, s, mark)


func _dump(d: CinemaDirector, s: CinemaShot, mark: float) -> void:
	var cam: CinemaCamera = d.cam
	var xf: Transform3D = cam.global_transform
	var eye: Vector3 = xf.origin
	var fwd: Vector3 = -xf.basis.z
	var fov_v: float = deg_to_rad(cam.fov)
	var half_v: float = fov_v * 0.5
	var half_h: float = atan(tan(half_v) * 16.0 / 9.0)
	print("[probe] shot %d +%.1fs  cam (%.2f, %.2f, %.2f) fwd (%.2f, %.2f, %.2f) fov %.0f" % [_shot_i, mark, eye.x, eye.y, eye.z, fwd.x, fwd.y, fwd.z, cam.fov])
	var stage: Node = _reel.stage
	if stage == null:
		return
	var people: Array = stage.find_children("*", "CinemaPerson", true, false)
	for n: Node in people:
		var p: CinemaPerson = n as CinemaPerson
		if not p.visible or not p.is_visible_in_tree():
			continue
		var base: Vector3 = p.global_position
		var dist: float = eye.distance_to(base + Vector3(0, 1.0, 0))
		if dist > near_m:
			continue
		var head: Vector3 = p.person.bone_world("Head") if p.person != null else base + Vector3(0, 1.6, 0)
		var rh: Vector3 = p.person.bone_world("RightHand") if p.person != null else base
		var lh: Vector3 = p.person.bone_world("LeftHand") if p.person != null else base
		var lf: Vector3 = p.person.bone_world("LeftFoot") if p.person != null else base
		var rf: Vector3 = p.person.bone_world("RightFoot") if p.person != null else base
		var to_head: Vector3 = head - eye
		var local: Vector3 = xf.basis.inverse() * to_head
		var in_frame: bool = local.z < 0.0 and absf(atan2(local.x, -local.z)) < half_h and absf(atan2(local.y, -local.z)) < half_v
		var off: float = rad_to_deg(fwd.angle_to(to_head.normalized()))
		var facing: Vector3 = -p.global_basis.z
		var face_cam: float = rad_to_deg(facing.angle_to((eye - head).normalized()))
		var closest: float = INF
		for b: Vector3 in [head, rh, lh, lf, rf, base + Vector3(0, 0.95, 0), base + Vector3(0, 1.3, 0)]:
			closest = minf(closest, eye.distance_to(b))
		var held: String = ""
		if p.person != null:
			for at: Node in p.person.skeleton.get_children():
				if at is BoneAttachment3D and at.get_child_count() > 0 and String(at.name).contains("Hand"):
					held += at.name.replace("Attach", "") + ":" + at.get_child(0).name + " "
		print("[probe]   %-14s pose=%-11s d=%5.2f off=%5.1f%s face=%4.0f v=%.2f head.y=%.2f feet.y=%.2f/%.2f rh=(%.2f,%.2f,%.2f) lh=(%.2f,%.2f,%.2f)%s%s" % [
			p.name, String(p.cine_pose), dist, off, " IN " if in_frame else " out", face_cam, p._speed, head.y, lf.y, rf.y,
			rh.x, rh.y, rh.z, lh.x, lh.y, lh.z, (" held " + held) if held != "" else "",
			"  CLOSE %.2f" % closest if closest < 0.4 else ""])
	for n2: Node in stage.find_children("*", "CinemaRisen", true, false):
		var r: Node3D = n2 as Node3D
		var dd: float = eye.distance_to(r.global_position)
		if dd < near_m and dd < 12.0:
			print("[probe]   risen %s d=%.1f" % [r.name, dd])
