extends Node3D
## The pre-MZ zombie for the before/after acceptance capture only (shots_zombie_anim): the old per-bone body
## (legacy_zombie_body.gd) on the old 16-node hand hierarchy, posed by the old plain-rotation gait, tear, flinch
## and death code lifted from the pre-T-041 zombie.gd. Presentation only; no gameplay, no hitboxes.

const LegacyBody: GDScript = preload("res://gravelight/tools_src/legacy_zombie_body.gd")
const TIER_GAIT: Dictionary = {
	&"shamble": [0.42, 0.3, 0.38, 0.14, 0.022, 0],
	&"walk": [0.58, 0.42, 0.55, 0.18, 0.03, 1],
	&"jog": [0.85, 0.62, 0.95, 0.32, 0.05, 2],
	&"run": [1.15, 0.8, 1.25, 0.46, 0.065, 3],
	&"sprint": [1.3, 0.95, 1.45, 0.6, 0.075, 4],
}

var tier: StringName = &"walk"
var mode: String = "walk"      # walk | tear | flinch | dead | idle
var flinch_zone: String = "torso"
var death_kind: int = 0
var speed: float = 2.0
var _pivot: Node3D
var _bones: Dictionary = {}
var _phase: float = 0.0
var _t: float = 0.0
var _asym: Dictionary = {}
var _flinch: float = 0.0
var _flinch_dir: float = 1.0


func build(variant: String) -> void:
	_pivot = Node3D.new()
	add_child(_pivot)
	for b: Array in LegacyBody.SKELETON:
		var n: Node3D = Node3D.new()
		n.name = str(b[0])
		n.position = b[2]
		var parent: Node3D = _pivot if str(b[1]) == "" else _bones[str(b[1])]
		parent.add_child(n)
		_bones[str(b[0])] = n
	for bone: String in LegacyBody.MESH_BONES:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = LegacyBody.mesh_for(variant, bone)
		(_bones[bone] as Node3D).add_child(mi)
	_asym = {"tilt": randf_range(-0.28, 0.28), "yaw": randf_range(-0.2, 0.2), "hang_l": randf_range(-0.25, 0.3), "hang_r": randf_range(-0.25, 0.3),
		"limp": randf_range(0.0, 1.0) if randf() < 0.45 else 0.0, "limp_side": -1.0 if randf() < 0.5 else 1.0,
		"hunch": randf_range(0.0, 0.28), "jaw": randf_range(0.05, 0.45), "phase": randf() * TAU, "spine_roll": randf_range(-0.08, 0.08)}
	_phase = float(_asym["phase"])
	_pivot.scale = Vector3.ONE * (1.0 + randf_range(-0.06, 0.06))


func start_flinch() -> void:
	_flinch = 0.18
	_flinch_dir = -1.0 if randf() < 0.5 else 1.0


func _process(delta: float) -> void:
	if _pivot == null:
		return
	_t += delta
	var g: Array = TIER_GAIT.get(tier, TIER_GAIT[&"walk"])
	var moving: bool = mode == "walk"
	if moving:
		_phase += delta * PI * speed / float(g[0])
		global_position += Vector3(0, 0, -speed * delta)
	var t: float = _t
	var p: float = _phase
	var hip_a: float = float(g[1])
	var knee_a: float = float(g[2])
	var lean: float = float(g[3]) + float(_asym.get("hunch", 0.0))
	var bob: float = float(g[4])
	var arm_mode: int = int(g[5])
	var limp: float = float(_asym.get("limp", 0.0))
	var limp_side: float = float(_asym.get("limp_side", 1.0))
	var hips_y: float = 0.95
	var hips_roll: float = 0.0
	var ab_x: float = -lean * 0.35
	var ch_x: float = -lean * 0.65
	var ch_y: float = 0.0
	var ch_z: float = float(_asym.get("spine_roll", 0.0))
	var nk_x: float = lean * 0.55
	var hd_x: float = 0.15
	var hd_z: float = float(_asym.get("tilt", 0.0))
	var hd_y: float = float(_asym.get("yaw", 0.0))
	var jaw: float = float(_asym.get("jaw", 0.2))
	var tl: float = 0.0
	var tr: float = 0.0
	var kl: float = -0.06
	var kr: float = -0.06
	var sl: Vector3 = Vector3(1.0 + float(_asym.get("hang_l", 0.0)), 0, -0.08)
	var sr: Vector3 = Vector3(1.0 + float(_asym.get("hang_r", 0.0)), 0, 0.08)
	var el: float = 0.3
	var er: float = 0.3
	if moving:
		var amp_l: float = hip_a * (1.0 - limp * 0.6 * (1.0 if limp_side < 0.0 else 0.0))
		var amp_r: float = hip_a * (1.0 - limp * 0.6 * (1.0 if limp_side > 0.0 else 0.0))
		tl = sin(p) * amp_l
		tr = sin(p + PI) * amp_r
		kl = -knee_a * maxf(0.0, cos(p)) - 0.08
		kr = -knee_a * maxf(0.0, cos(p + PI)) - 0.08
		if tier == &"shamble":
			if limp_side < 0.0:
				kl *= 0.25
			else:
				kr *= 0.25
			hips_roll = sin(p) * 0.12
			ch_z += -sin(p) * 0.1
		hips_y -= bob * (0.5 + 0.5 * cos(2.0 * p)) + limp * 0.04 * maxf(0.0, sin(p) * limp_side)
		ch_y = sin(p) * 0.12
		match arm_mode:
			0:
				sl.x = 0.55 + float(_asym.get("hang_l", 0.0)) + sin(p) * 0.12
				sr.x = 0.45 + float(_asym.get("hang_r", 0.0)) - sin(p) * 0.12
				el = 0.35
				er = 0.25
			1:
				sl.x = 1.25 + sin(p * 0.5 + 1.0) * 0.12
				sr.x = 1.2 - sin(p * 0.5) * 0.12
				el = 0.3
				er = 0.4
			2:
				sl.x = 1.3 + sin(p) * 0.35
				sr.x = 1.3 - sin(p) * 0.35
				el = 0.75
				er = 0.75
			3:
				sl.x = 1.5 + sin(p) * 0.5
				sr.x = 1.5 - sin(p) * 0.5
				el = 0.95
				er = 0.95
				hd_x -= 0.15
			4:
				sl.x = 1.4 + sin(p * 1.7) * 0.8
				sr.x = 1.4 + sin(p * 1.7 + 2.1) * 0.8
				sl.z = -0.3 + sin(p * 2.3) * 0.3
				sr.z = 0.3 + sin(p * 2.1) * 0.3
				el = 1.0 + sin(p * 3.1) * 0.4
				er = 1.0 + cos(p * 2.7) * 0.4
				hd_z += sin(t * 17.0) * 0.12
				jaw = 0.55
	else:
		hips_roll = sin(t * 1.3 + _phase) * 0.04
		ch_x += sin(t * 0.9 + _phase) * 0.04
		hd_z += sin(t * 0.7 + _phase) * 0.08
		sl.x = 0.95 + sin(t * 1.1) * 0.06 + float(_asym.get("hang_l", 0.0))
		sr.x = 0.9 + sin(t * 1.2 + 1.0) * 0.06 + float(_asym.get("hang_r", 0.0))
	match mode:
		"tear":
			var k3: float = sin(_t * 6.5)
			sl = Vector3(1.6 + k3 * 0.18, 0, -0.15)
			sr = Vector3(1.6 - k3 * 0.18, 0, 0.15)
			el = 0.5 - k3 * 0.3
			er = 0.5 + k3 * 0.3
			ch_x = -0.25 + k3 * 0.12
			ab_x = -0.1
			jaw = 0.5
		"dead":
			_pose_dead(delta)
			return
	if _flinch > 0.0:
		_flinch = maxf(0.0, _flinch - delta)
		var fk: float = _flinch / 0.18
		ch_x += 0.3 * fk
		ch_y += 0.35 * fk * _flinch_dir
		hd_x -= 0.4 * fk
	var a: float = clampf(delta * 14.0, 0.0, 1.0)
	var hips: Node3D = _bones["hips"]
	hips.position.y = lerpf(hips.position.y, hips_y, a)
	hips.rotation = hips.rotation.lerp(Vector3(0, 0, hips_roll), a)
	_lerp_rot("abdomen", Vector3(ab_x, ch_y * 0.4, ch_z * 0.5), a)
	_lerp_rot("chest", Vector3(ch_x, ch_y, ch_z), a)
	_lerp_rot("neck", Vector3(nk_x, 0, 0), a)
	_lerp_rot("head", Vector3(hd_x, hd_y, hd_z), a)
	_lerp_rot("jaw", Vector3(jaw * 0.6, 0, 0), a)
	_lerp_rot("thigh_l", Vector3(tl, 0, 0.03), a)
	_lerp_rot("thigh_r", Vector3(tr, 0, -0.03), a)
	_lerp_rot("shin_l", Vector3(kl, 0, 0), a)
	_lerp_rot("shin_r", Vector3(kr, 0, 0), a)
	_lerp_rot("sh_l", sl, a)
	_lerp_rot("sh_r", sr, a)
	_lerp_rot("el_l", Vector3(el, 0, 0), a)
	_lerp_rot("el_r", Vector3(er, 0, 0), a)


func _lerp_rot(n: String, r: Vector3, a: float) -> void:
	var b: Node3D = _bones[n]
	b.rotation = b.rotation.lerp(r, a)


func _pose_dead(dt: float) -> void:
	var t: float = _t
	var a: float = clampf(dt * 10.0, 0.0, 1.0)
	var k: float = clampf(t / 0.75, 0.0, 1.0)
	var e: float = k * k
	match death_kind % 4:
		0:
			_pivot.rotation.x = lerpf(0.0, 1.5, e)
			_lerp_rot("thigh_l", Vector3(0.6, 0, 0.1), a)
			_lerp_rot("thigh_r", Vector3(0.2, 0, -0.15), a)
			_lerp_rot("shin_l", Vector3(-0.9, 0, 0), a)
			_lerp_rot("sh_l", Vector3(2.4, 0, -0.9), a)
			_lerp_rot("sh_r", Vector3(2.0, 0, 1.0), a)
			_lerp_rot("head", Vector3(-0.5, 0.3, 0), a)
		1:
			_pivot.rotation.x = lerpf(0.0, -1.45, e)
			_lerp_rot("sh_l", Vector3(0.3, 0, -0.3), a)
			_lerp_rot("sh_r", Vector3(2.6, 0, 0.4), a)
			_lerp_rot("head", Vector3(0.3, -0.5, 0.2), a)
		2:
			var kneel: float = clampf(t / 0.35, 0.0, 1.0)
			_pivot.position.y = lerpf(0.0, -0.42, kneel)
			_lerp_rot("thigh_l", Vector3(1.4, 0, 0.1), a)
			_lerp_rot("thigh_r", Vector3(1.3, 0, -0.1), a)
			_lerp_rot("shin_l", Vector3(-2.3, 0, 0), a)
			_lerp_rot("shin_r", Vector3(-2.2, 0, 0), a)
			_lerp_rot("sh_l", Vector3(0.2, 0, -0.2), a)
			_lerp_rot("sh_r", Vector3(0.1, 0, 0.2), a)
			if t > 0.45:
				_pivot.rotation.x = lerpf(_pivot.rotation.x, -1.25, clampf(dt * 5.0, 0.0, 1.0))
				_pivot.position.y = lerpf(_pivot.position.y, -0.62, clampf(dt * 5.0, 0.0, 1.0))
			_lerp_rot("head", Vector3(0.6, 0, 0.3), a)
		_:
			_pivot.rotation.z = lerpf(0.0, 1.45, e)
			_pivot.rotation.y = lerpf(0.0, 0.6, k)
			_lerp_rot("chest", Vector3(-0.2, 0.5, 0), a)
			_lerp_rot("sh_l", Vector3(1.6, 0, -1.2), a)
			_lerp_rot("sh_r", Vector3(0.6, 0, 0.6), a)
	_lerp_rot("jaw", Vector3(0.5, 0, 0), a)


## Switches to a mode and resets its clock.
func set_mode(m: String) -> void:
	mode = m
	_t = 0.0
