extends "res://gravelight/tools_src/shots_zombie_anim.gd"
## Terrain and body matrix for the live zombie (handoff item 2). Five lanes of real collision, each 16 m:
##   flat (the control), ramp20 (a 20 degree slope up, a landing, down), ramp31 (the slope of a 0.18 / 0.30 stair:
##   the maps build their stairs as ramps under stair art), steps (the same flight as real 0.18 m step boxes: the
##   stress case for Zombie._step_up), rubble (forty low boxes, 5-20 cm, some tilted).
## Each case of the matrix (a kind, kit, build, sex, height and tier) puts one live zombie on every lane with the
## real AI, navigation, physics, foot rays and animation; it walks at a target at the lane's far end, which moves to
## the other end when it arrives. Sampled from each skeleton's `skeleton_updated` signal, in steady locomotion only.
## (That signal is the only place the final pose can be read: a SkeletonModifier3D's result, here the foot IK and
## the foot tilt, is rolled back before the next _process, so reading bones there shows the pose WITHOUT them.)
##   - the toe's height over the ground under it during the recording's own contact windows (a ray on the world
##     layer), and its horizontal speed there (planted-foot slip);
##   - the largest bone rotation step in one frame (pose continuity), the foot IK weight, time off the floor;
##   - lane traversals, seconds stuck, the states it passed through, root-motion against body speed.
## Nothing is tuned here and nothing but a lost actor or a script error fails the run: the report is the diagnosis.
## Usage (fixed timestep, headless): godot --headless --audio-driver Dummy --fixed-fps 60 --path .
##   res://tools/zombie_terrain_check.tscn -- [--out=res://.mocap_work/zombies/terrain] [--seconds=24] [--cases=bodies,tiers,kinds]
##   [--only=<case name>] [--no-tilt] [--lod] (--lod keeps the game's animation LOD distances instead of full rate)

const LANES: Array[String] = ["flat", "ramp20", "ramp31", "steps", "rubble"]
const LANE_GAP: float = 26.0
const LANE_LEN: float = 16.0
const NAV_HALF: float = 1.2
const STEP_RISE: float = 0.18
const STEP_RUN: float = 0.30
const STEPS: int = 8
const ARRIVE_M: float = 3.0

var seconds: float = 24.0
var groups: PackedStringArray = ["bodies", "tiers", "kinds"]
var only: String = ""
var keep_lod: bool = false
var no_tilt: bool = false                # --no-tilt: the feet stay level (the pose before the foot tilt), for a baseline
var _cases: Array[Dictionary] = []
var _case_i: int = -1
var _case_t: float = 0.0
var _actors: Array[Dictionary] = []      # per lane: {z, target, at_far, stats...}
var _targets: Array[Player] = []
var _report: Array[Dictionary] = []
var _ready_ok: bool = false
var _done: bool = false
var _failures: Array[String] = []


func _ready() -> void:
	seed(74120)
	process_priority = 10   # sample after the zombies' own animation callbacks
	for autoload: Node in get_tree().root.get_children():
		if autoload.get_script() != null and str(autoload.get_script().resource_path).ends_with("/dev_console.gd"):
			autoload.set_process_unhandled_input(false)
	_out = "res://.mocap_work/zombies/terrain"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): _out = arg.get_slice("=", 1)
		elif arg.begins_with("--seconds="): seconds = float(arg.get_slice("=", 1))
		elif arg.begins_with("--cases="): groups = arg.get_slice("=", 1).split(",")
		elif arg.begins_with("--only="): only = arg.get_slice("=", 1)
		elif arg == "--lod": keep_lod = true
		elif arg == "--no-tilt": no_tilt = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	GameState.map_id = &"map01_kaltenbrunn"
	if not keep_lod: Zombie.anim_lod_scale = 100.0
	_build_studio()
	await get_tree().process_frame
	_build_terrain()
	await get_tree().physics_frame
	while NavigationServer3D.map_get_iteration_id(_studio.get_world_3d().navigation_map) < 2:
		await get_tree().physics_frame
	_player.set_physics_process(false)
	_player.position = Vector3(0, 0.1, -200)   # the studio's own target: far away, never the nearest
	_build_cases()
	_ready_ok = true
	_next_case()


func _lane_x(i: int) -> float:
	return (float(i) - float(LANES.size() - 1) * 0.5) * LANE_GAP


func _box(parent: Node3D, size: Vector3, at: Transform3D, color: Color) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	body.transform = at
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	mi.material_override = m
	body.add_child(mi)
	parent.add_child(body)


## A slab whose top face runs from (z0, y0) to (z1, y1) across the lane.
func _slope(parent: Node3D, x: float, z0: float, y0: float, z1: float, y1: float) -> void:
	var dz: float = z1 - z0
	var dy: float = y1 - y0
	var length: float = sqrt(dz * dz + dy * dy)
	var a: float = atan2(dy, dz)
	var normal: Vector3 = Vector3(0, cos(a), -sin(a))
	var mid: Vector3 = Vector3(x, (y0 + y1) * 0.5, (z0 + z1) * 0.5) - normal * 0.1
	_box(parent, Vector3(3.0, 0.2, length), Transform3D(Basis(Vector3.RIGHT, -a), mid), Color(0.22, 0.21, 0.2))


func _build_terrain() -> void:
	# the studio's own floor is 60 m wide: a wider one under it, and its divider wall and navmesh go
	for n: Node in _studio.get_children():
		if n is NavigationRegion3D or (n is MeshInstance3D and (n as MeshInstance3D).mesh is BoxMesh):
			n.queue_free()
	_box(_studio, Vector3(LANE_GAP * float(LANES.size()) + 20.0, 1.0, LANE_LEN + 20.0), Transform3D(Basis(), Vector3(0, -0.5, LANE_LEN * 0.5)), Color(0.16, 0.16, 0.17))
	var verts: PackedVector3Array = []
	var nm: NavigationMesh = NavigationMesh.new()
	var polys: Array[PackedInt32Array] = []
	for i: int in LANES.size():
		var x: float = _lane_x(i)
		var rows: Array = [[0.0, 0.0], [LANE_LEN, 0.0]]   # [z, y] breakpoints of the walking surface
		match LANES[i]:
			"ramp20":
				var h: float = 1.2
				var run: float = h / tan(deg_to_rad(20.0))
				rows = [[0.0, 0.0], [4.0, 0.0], [4.0 + run, h], [6.0 + run, h], [6.0 + run * 2.0, 0.0], [LANE_LEN, 0.0]]
			"ramp31", "steps":
				var h2: float = STEP_RISE * float(STEPS)
				var run2: float = STEP_RUN * float(STEPS)
				rows = [[0.0, 0.0], [4.0, 0.0], [4.0 + run2, h2], [6.0 + run2, h2], [6.0 + run2 * 2.0, 0.0], [LANE_LEN, 0.0]]
		if LANES[i] == "steps":
			for s: int in STEPS:
				var top: float = STEP_RISE * float(s + 1)
				# each step is a full-height block from the ground, up the flight and mirrored down it
				_box(_studio, Vector3(3.0, top, STEP_RUN), Transform3D(Basis(), Vector3(x, top * 0.5, 4.0 + STEP_RUN * (float(s) + 0.5))), Color(0.25, 0.23, 0.2))
				_box(_studio, Vector3(3.0, top, STEP_RUN), Transform3D(Basis(), Vector3(x, top * 0.5, float(rows[4][0]) - STEP_RUN * (float(s) + 0.5))), Color(0.25, 0.23, 0.2))
			var h3: float = STEP_RISE * float(STEPS)
			_box(_studio, Vector3(3.0, h3, 2.0), Transform3D(Basis(), Vector3(x, h3 * 0.5, (float(rows[2][0]) + float(rows[3][0])) * 0.5)), Color(0.25, 0.23, 0.2))
		elif rows.size() > 2:
			_slope(_studio, x, float(rows[1][0]), 0.0, float(rows[2][0]), float(rows[2][1]))
			_box(_studio, Vector3(3.0, 0.2, 2.0), Transform3D(Basis(), Vector3(x, float(rows[2][1]) - 0.1, (float(rows[2][0]) + float(rows[3][0])) * 0.5)), Color(0.22, 0.21, 0.2))
			_slope(_studio, x, float(rows[3][0]), float(rows[3][1]), float(rows[4][0]), 0.0)
		if LANES[i] == "rubble":
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = 5150
			for k: int in 40:
				var size: Vector3 = Vector3(rng.randf_range(0.3, 0.9), rng.randf_range(0.05, 0.2), rng.randf_range(0.3, 0.9))
				var b: Basis = Basis(Vector3.UP, rng.randf_range(0.0, TAU))
				if k % 4 == 0:
					b = b * Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(-10.0, 10.0)))
				_box(_studio, size, Transform3D(b, Vector3(x + rng.randf_range(-1.2, 1.2), size.y * 0.5 - 0.01, rng.randf_range(3.0, 13.0))), Color(0.3, 0.27, 0.24))
		var base: int = verts.size()
		for r: Array in rows:
			verts.append(Vector3(x - NAV_HALF, float(r[1]), float(r[0])))
			verts.append(Vector3(x + NAV_HALF, float(r[1]), float(r[0])))
		for r_i: int in rows.size() - 1:
			var a0: int = base + r_i * 2
			polys.append(PackedInt32Array([a0, a0 + 1, a0 + 3, a0 + 2]))
		var target: Player = Player.new()
		target.player_id = 10 + i
		target.is_local = false
		target.name = "LaneTarget%d" % i
		_studio.add_child(target)
		target.set_physics_process(false)
		target.position = Vector3(x, 0.1, LANE_LEN - 0.5)
		_targets.append(target)
	nm.vertices = verts
	for p: PackedInt32Array in polys:
		nm.add_polygon(p)
	var region: NavigationRegion3D = NavigationRegion3D.new()
	region.navigation_mesh = nm
	_studio.add_child(region)


func _build_cases() -> void:
	var enemies: Dictionary = GLData.table("enemies")["enemies"]
	var heights: Array = GLData.table("anim")["builds"].get("heights", [0.95, 1.04])
	var lo: float = float(heights[0])
	var hi: float = float(heights[1])
	if groups.has("bodies"):
		# every build and sex, at both ends of the height range, at a walk
		for b: Array in [["thin", true, lo], ["thin", false, hi], ["medium", false, 1.0], ["medium", true, hi], ["heavy", false, hi], ["heavy", true, lo]]:
			_cases.append({"name": "body_%s_%s_%.2f" % [b[0], "f" if b[1] else "m", b[2]], "group": "bodies", "kind": "ganger", "kit": "villager", "tier": "walk",
				"build": b[0], "female": b[1], "height": b[2]})
	if groups.has("tiers"):
		for t: String in ["shamble", "jog", "run", "sprint"]:
			_cases.append({"name": "tier_" + t, "group": "tiers", "kind": "ganger", "kit": "soldier", "tier": t, "build": "medium", "female": false, "height": 1.0})
		_cases.append({"name": "crawler", "group": "tiers", "kind": "ganger", "kit": "soldier", "tier": "walk", "crawler": true, "build": "medium", "female": false, "height": 1.0})
	if groups.has("kinds"):
		for k: Variant in enemies.keys():
			var kind: String = str(k)
			if kind == "ganger" or kind in ["foreman", "screamer"]:
				continue   # the Foreman and the Screamer have bespoke bodies: not the shared rig, not this tool
			var e: Dictionary = enemies[kind]
			# the tier the director would give it (ZombieDirector._spec_for): the Bellringer always runs
			var tier_name: String = "run" if kind == "bellringer" else str(e.get("tier", "walk"))
			_cases.append({"name": "kind_" + kind, "group": "kinds", "kind": kind, "kit": str(e.get("kit", "soldier")), "tier": tier_name})
	if only != "":
		_cases = _cases.filter(func(c: Dictionary) -> bool: return str(c["name"]) == only)


func _next_case() -> void:
	for a: Dictionary in _actors:
		var z: Zombie = a["z"]
		if is_instance_valid(z):
			if z.is_active():
				z.deactivate()
			z.queue_free()
	_actors.clear()
	_case_i += 1
	_case_t = 0.0
	if _case_i >= _cases.size():
		_finish()
		return
	var c: Dictionary = _cases[_case_i]
	for i: int in LANES.size():
		var z: Zombie = Zombie.new()
		_studio.add_child(z)
		var at: Vector3 = Vector3(_lane_x(i), 0.0, 1.0)
		_spawn.global_position = at
		_spawn.window_path = NodePath("")
		_spawn.kind = &"ground"
		_targets[i].position = Vector3(_lane_x(i), 0.1, LANE_LEN - 0.5)
		var spec: Dictionary = {"enemy_id": str(c["kind"]), "variant": str(c["kit"]), "tier": str(c["tier"]), "crawler": bool(c.get("crawler", false)), "health": 100000}
		z.activate(spec, _spawn, _targets[i])
		z.global_position = at
		z.forced_target = _targets[i]
		(z.get("_agent") as NavigationAgent3D).avoidance_enabled = false
		if c.has("build"):
			z.debug_set_body(str(c["kit"]), str(c["build"]), bool(c["female"]))
			z.set("_height", float(c["height"]))
			(z.get("_pivot") as Node3D).scale = Vector3.ONE * float(c["height"])
		z.call("_enter", Zombie.State.CHASE)
		if no_tilt and z.get("_modifier") != null:
			z.get("_modifier").set("max_foot_tilt", 0.0)
		var sk: Skeleton3D = z.get("_skel")
		var snap: Dictionary = {}
		if sk != null:
			var lf: int = sk.find_bone("LeftFoot")
			var rf: int = sk.find_bone("RightFoot")
			sk.skeleton_updated.connect(func() -> void:
				snap["Left"] = sk.global_transform * (sk.get_bone_global_pose(lf) * Vector3(0, -0.06, -0.15))
				snap["Right"] = sk.global_transform * (sk.get_bone_global_pose(rf) * Vector3(0, -0.06, -0.15))
				var rots: Array = []
				for b: int in sk.get_bone_count():
					rots.append(sk.get_bone_pose_rotation(b))
				snap["rots"] = rots
				# the cycle time this pose belongs to (read here: by the next _process the tree has not moved, but a
				# sample taken there against "now" would pair this pose with the wrong side of a contact window's edge)
				var clip_now: String = str(z.get("_loco_clip"))
				snap["clip"] = clip_now
				snap["time"] = fposmod((z.get("_playback") as AnimationNodeStateMachinePlayback).get_current_play_position(), maxf(0.001, ZombieClips.length_of(clip_now)))
				snap["serial"] = int(snap.get("serial", 0)) + 1)
		_actors.append({"z": z, "snap": snap, "lane": i, "far": true, "trips": 0, "stuck": 0.0, "air": 0, "ticks": 0, "states": {}, "toe_err": [], "slip": [],
			"pose_step": [], "pops": {}, "rate": [], "ik": [], "root_err": [], "prev": {}, "feet": {}, "lost": "", "y_err": [], "clips": {}})


func _physics_process(delta: float) -> void:
	if not _ready_ok or _done:
		return
	Zombie.repath_budget = 6
	for a: Dictionary in _actors:
		var z: Zombie = a["z"]
		if not is_instance_valid(z) or not z.is_active():
			if str(a["lost"]) == "":
				a["lost"] = "inactive at %.1f s" % _case_t
			continue
		var t: Player = _targets[int(a["lane"])]
		var flat: float = Vector2(z.global_position.x - t.global_position.x, z.global_position.z - t.global_position.z).length()
		if flat < ARRIVE_M:
			a["far"] = not bool(a["far"])
			a["trips"] = int(a["trips"]) + 1
			t.position = Vector3(_lane_x(int(a["lane"])), 0.1, LANE_LEN - 0.5 if bool(a["far"]) else 0.5)
		if _case_t < 2.0:
			continue
		a["ticks"] = int(a["ticks"]) + 1
		if not z.is_on_floor():
			a["air"] = int(a["air"]) + 1
		var st: String = Zombie.State.keys()[z.state]
		(a["states"] as Dictionary)[st] = int((a["states"] as Dictionary).get(st, 0)) + 1
		if z.state == Zombie.State.CHASE and Vector2(z.velocity.x, z.velocity.z).length() < 0.15 and flat > ARRIVE_M + 0.5:
			a["stuck"] = float(a["stuck"]) + delta


func _process(delta: float) -> void:
	if not _ready_ok or _done:
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_case_t += delta
	if _case_t >= 2.0:
		for a: Dictionary in _actors:
			_sample(a, delta)
	if _case_t >= seconds:
		_close_case()
		_next_case()


func _ground_y(z: Zombie, at: Vector3) -> float:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.7, at - Vector3.UP * 1.5, 1, [z.get_rid()])
	var hit: Dictionary = z.get_world_3d().direct_space_state.intersect_ray(q)
	return float((hit["position"] as Vector3).y) if not hit.is_empty() else NAN


func _sample(a: Dictionary, delta: float) -> void:
	var z: Zombie = a["z"]
	if not is_instance_valid(z) or not z.is_active():
		return
	var sk: Skeleton3D = z.get("_skel")
	if sk == null:
		return
	var steady: bool = z.state == Zombie.State.CHASE and z.current_clip_state() == "Locomotion" and Vector2(z.velocity.x, z.velocity.z).length() > 0.4
	var prev: Dictionary = a["prev"]
	# pose continuity: the largest local rotation step of any bone since the last frame, in steady locomotion
	var snap: Dictionary = a["snap"]
	if not snap.has("rots"):
		return
	var rots: Array = (snap["rots"] as Array).duplicate()
	var worst: float = 0.0
	var worst_bone: String = ""
	for b: int in rots.size():
		var q: Quaternion = rots[b]
		if steady and bool(prev.get("steady", false)) and (prev.get("rots", []) as Array).size() == sk.get_bone_count():
			var step: float = rad_to_deg(q.angle_to((prev["rots"] as Array)[b] as Quaternion))
			if step > worst:
				worst = step
				worst_bone = sk.get_bone_name(b)
	if steady and bool(prev.get("steady", false)):
		(a["pose_step"] as Array).append(worst)
		if worst > 30.0:
			# which bone, and where in the cycle: a step at the loop's wrap is the clip's seam, one inside it is not
			var pb: AnimationNodeStateMachinePlayback = z.get("_playback")
			var len_s: float = maxf(0.001, ZombieClips.length_of(str(z.get("_loco_clip"))))
			var key: String = "%s@%.2f" % [worst_bone, snappedf(fposmod(pb.get_current_play_position(), len_s) / len_s, 0.05)]
			(a["pops"] as Dictionary)[key] = int((a["pops"] as Dictionary).get(key, 0)) + 1
	a["prev"] = {"steady": steady, "rots": rots}
	if not steady:
		a["feet"] = {}
		return
	var modifier: Object = z.get("_modifier")
	if modifier != null:
		(a["ik"] as Array).append(float(modifier.get("ik_weight")))
	var body_speed: float = float(z.get("_body_speed"))
	if body_speed > 0.4:
		(a["root_err"] as Array).append(absf(float(z.get("_rm_speed")) - body_speed) / body_speed)
	var gy: float = _ground_y(z, z.global_position)
	if not is_nan(gy):
		(a["y_err"] as Array).append(z.global_position.y - gy)
	var clip: String = str(snap.get("clip", ""))
	# how far from its recorded cadence the gait is played to match the body's speed
	(a["rate"] as Array).append(float((z.get("_tree") as AnimationTree).get("parameters/SM/Locomotion/TimeScale/scale")))
	(a["clips"] as Dictionary)[clip] = int((a["clips"] as Dictionary).get(clip, 0)) + 1
	var windows: Dictionary = ZombieClips.contact_windows(clip)
	if windows.is_empty() or float(z.get("_loco_x")) < 0.99:
		a["feet"] = {}
		return
	var time: float = float(snap.get("time", 0.0))
	var now: Dictionary = {"time": time, "clip": clip, "serial": int(snap.get("serial", 0))}
	var old: Dictionary = a["feet"]
	for side: String in windows:
		var toe: Vector3 = snap[side]
		now[side] = toe
		for interval: Array in windows[side]:
			if time >= float(interval[0]) and time <= float(interval[1]):
				var g: float = _ground_y(z, toe)
				if not is_nan(g):
					(a["toe_err"] as Array).append(toe.y - g)
				if old.has(side) and old.get("clip") == clip and int(old.get("serial", -9)) == int(now["serial"]) - 1 and float(old["time"]) >= float(interval[0]) and float(old["time"]) <= float(interval[1]) and time >= float(old["time"]):
					var v: Vector3 = (toe - (old[side] as Vector3)) / maxf(delta, 0.00001)
					(a["slip"] as Array).append(Vector2(v.x, v.z).length())
				break
	a["feet"] = now


func _pct(values: Array, fraction: float) -> Variant:
	if values.is_empty():
		return null
	var v: Array = values.duplicate()
	v.sort()
	return snappedf(float(v[mini(v.size() - 1, int(float(v.size()) * fraction))]), 0.0001)


func _close_case() -> void:
	var c: Dictionary = _cases[_case_i]
	for a: Dictionary in _actors:
		var z: Zombie = a["z"]
		var pops: int = 0
		for s: Variant in a["pose_step"]:
			if float(s) > 30.0:
				pops += 1
		var row: Dictionary = {"case": c["name"], "group": c["group"], "lane": LANES[int(a["lane"])], "kind": c["kind"], "tier": c["tier"],
			"trips": a["trips"], "stuck_s": snappedf(float(a["stuck"]), 0.01), "air_fraction": snappedf(float(a["air"]) / maxf(1.0, float(a["ticks"])), 0.001),
			"states": a["states"], "clips": a["clips"], "lost": a["lost"],
			"toe_samples": (a["toe_err"] as Array).size(), "toe_height_p05_m": _pct(a["toe_err"], 0.05), "toe_height_p50_m": _pct(a["toe_err"], 0.5), "toe_height_p95_m": _pct(a["toe_err"], 0.95),
			"slip_samples": (a["slip"] as Array).size(), "slip_p50_mps": _pct(a["slip"], 0.5), "slip_p95_mps": _pct(a["slip"], 0.95),
			"pose_step_p99_deg": _pct(a["pose_step"], 0.99), "pose_step_max_deg": _pct(a["pose_step"], 1.0), "pose_steps_over_30_deg": pops, "pose_samples": (a["pose_step"] as Array).size(), "pose_steps_over_30_by_bone_and_phase": a["pops"],
			"playback_rate_p50": _pct(a["rate"], 0.5), "ik_weight_p50": _pct(a["ik"], 0.5), "root_mismatch_p50": _pct(a["root_err"], 0.5), "body_over_ground_p95_m": _pct(a["y_err"], 0.95),
			"speed_mps": snappedf(z.speed, 0.01) if is_instance_valid(z) else -1.0}
		if str(a["lost"]) != "":
			_failures.append("%s on %s: %s" % [c["name"], row["lane"], a["lost"]])
		_report.append(row)
		print("[terrain] %-22s %-7s trips %2d stuck %5.2f s air %.3f | toe p05/p50/p95 %s/%s/%s m (n %d) | slip p95 %s m/s | pose p99/max %s/%s deg (>30: %d) | rate x%s | ik %s | %s" % [
			c["name"], row["lane"], int(row["trips"]), float(row["stuck_s"]), float(row["air_fraction"]), str(row["toe_height_p05_m"]), str(row["toe_height_p50_m"]),
			str(row["toe_height_p95_m"]), int(row["toe_samples"]), str(row["slip_p95_mps"]), str(row["pose_step_p99_deg"]), str(row["pose_step_max_deg"]), pops,
			str(row["playback_rate_p50"]), str(row["ik_weight_p50"]), JSON.stringify(row["states"])])


func _finish() -> void:
	_done = true
	var out: Dictionary = {"sampled_at": "Skeleton3D.skeleton_updated (the final pose, after the SkeletonModifier3D foot IK and tilt)", "foot_tilt": not no_tilt, "lanes": LANES, "seconds_per_case": seconds, "full_rate": not keep_lod, "step": [STEP_RISE, STEP_RUN, STEPS], "rows": _report, "failures": _failures,
		"method": "Live AI on real collision. Toe = foot bone * (0, -0.06, -0.15); height over a world-layer ray under it, inside the clip's recorded contact windows; slip = its horizontal speed there. Steady locomotion only (CHASE, Locomotion tree state, over 0.4 m/s). The flat lane is the control: read the others against it.",
		"scope": "Diagnosis, not acceptance: no tolerance is applied. A lost actor is the only failure."}
	var f: FileAccess = FileAccess.open(_out + "/terrain.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(out, "  "))
		f.close()
	print("ZOMBIE_TERRAIN_CHECK cases=%d rows=%d failures=%s" % [_cases.size(), _report.size(), JSON.stringify(_failures)])
	get_tree().quit(0 if _failures.is_empty() else 1)
