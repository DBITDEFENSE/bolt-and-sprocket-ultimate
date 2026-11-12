extends Node3D
## T-240: a turntable for the horse model (the living Noriker and the dead one) with no map round it: a snow floor, a
## moon and a lamp, the rig posed at fixed stride phases and poses, one PNG each. Seconds to run, so the model can be
## looked at many times (the in-map frames come from tools_src/capture.gd, set u15_horse).
##   sh tools/wsl_godot.sh --path . res://gravelight/tools_src/horse_shots.tscn -- --label=<label> [--looks=noriker,dead] [--only=name,...] [--night]
## Looks "boss" and "boss_rider" stand a real HorseBoss (the Totenross, the Fuhrmann) on the floor instead of the bare
## rig: its light, breath, shaft and rider, in the poses of BOSS_SHOTS (HorseBoss.debug_pose).
## PNGs: morning/screenshots/t240_horse/<label>/<look>_<shot>.png. Never run with a window on the owner's PC.

## [name, gait speed m/s, stride phase, camera yaw deg (0 = from the front), camera height, distance, poses {..}]
const SHOTS: Array = [
	["side_stand", 0.0, 0.0, 90.0, 1.3, 4.4, {}],
	["front_stand", 0.0, 0.0, 8.0, 1.5, 4.2, {}],
	["quarter_stand", 0.0, 0.0, 40.0, 1.6, 4.4, {}],
	["rear_quarter", 0.0, 0.0, 140.0, 1.6, 4.4, {}],
	["off_side", 0.0, 0.0, -75.0, 1.2, 4.4, {}],
	["head", 0.0, 0.0, 55.0, 1.9, 2.0, {"aim": Vector3(0, 1.75, -1.3)}],
	["walk_a", 1.9, 0.1, 90.0, 1.2, 4.6, {}],
	["walk_b", 1.9, 0.45, 60.0, 1.4, 4.6, {}],
	["trot_a", 4.6, 0.2, 90.0, 1.2, 4.8, {}],
	["trot_b", 4.6, 0.46, 50.0, 1.4, 4.8, {}],
	["gallop_a", 9.5, 0.1, 90.0, 1.2, 5.0, {}],
	["gallop_b", 9.5, 0.45, 90.0, 1.2, 5.0, {}],
	["gallop_c", 9.5, 0.85, 90.0, 1.2, 5.0, {}],
	["gallop_q", 9.5, 0.6, 35.0, 1.5, 5.0, {}],
	["rider_view", 4.6, 0.3, 180.0, 2.47, 0.12, {"aim": Vector3(0, 2.2, -3.0), "fov": 78.0}],
	["turn", 4.6, 0.3, 30.0, 2.4, 4.6, {"turn": 1.0}],
	["low_head", 0.0, 0.0, 60.0, 1.2, 4.4, {"head_low": 1.0, "paw": 1.0, "ears_back": 1.0}],
	["rear", 0.0, 0.0, 70.0, 1.4, 5.4, {"rear": 1.0, "ears_back": 1.0, "jaw": 0.5}],
	["kick", 0.0, 0.0, 110.0, 1.3, 5.0, {"kick": 1.0, "ears_back": 1.0}],
	["shy", 0.0, 0.0, 60.0, 1.4, 4.4, {"shy": 1.0}],
	["stagger", 0.0, 0.0, 50.0, 1.4, 4.4, {"stagger": 1.0}],
	["down_a", 0.0, 0.0, 70.0, 1.4, 4.8, {"collapse": 0.5}],
	["down_b", 0.0, 0.0, 70.0, 1.6, 4.8, {"collapse": 1.0}],
]

## [name, pose (HorseBoss.debug_pose), camera yaw deg (0 = from the front), camera height, distance]
const BOSS_SHOTS: Array = [
	["stand_quarter", "none", 40.0, 1.6, 5.0], ["stand_side", "none", 90.0, 1.4, 5.2], ["stand_front", "none", 6.0, 1.6, 4.6],
	["stand_off_quarter", "none", -50.0, 1.6, 5.0], ["stand_rear", "none", 150.0, 1.6, 5.2], ["head", "none", 50.0, 1.9, 2.4],
	["rear", "rear", 45.0, 1.5, 6.0], ["low", "low", 20.0, 1.3, 5.0], ["kick", "kick", 120.0, 1.4, 5.4], ["stagger", "stagger", 50.0, 1.5, 5.0],
]

var _out: String = ""
var _looks: PackedStringArray = ["noriker", "dead"]
var _only: PackedStringArray = []
var _night: bool = false


func _ready() -> void:
	var label: String = "look"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--label="):
			label = a.substr(8)
		elif a.begins_with("--looks="):
			_looks = a.substr(8).split(",", false)
		elif a.begins_with("--only="):
			_only = a.substr(7).split(",", false)
		elif a == "--night":
			_night = true
	_out = ProjectSettings.globalize_path("res://").path_join("morning/screenshots/t240_horse").path_join(label)
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.06, 0.09) if _night else Color(0.36, 0.4, 0.46)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.55, 0.7)
	e.ambient_light_energy = 0.1 if _night else 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.6
	env.environment = e
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 0.25 if _night else 1.05
	sun.light_color = Color(0.7, 0.8, 1.0) if _night else Color(1.0, 0.96, 0.9)
	sun.shadow_enabled = true
	add_child(sun)
	var floor_mi: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(60, 60)
	floor_mi.mesh = pm
	var fm: StandardMaterial3D = StandardMaterial3D.new()
	fm.albedo_color = Color(0.34, 0.36, 0.4) if not _night else Color(0.2, 0.22, 0.26)
	fm.roughness = 0.95
	floor_mi.material_override = fm
	add_child(floor_mi)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.current = true
	# a floor to stand on (the bosses are bodies)
	var fb: StaticBody3D = StaticBody3D.new()
	var fcs: CollisionShape3D = CollisionShape3D.new()
	var fbs: BoxShape3D = BoxShape3D.new()
	fbs.size = Vector3(60, 1, 60)
	fcs.shape = fbs
	fcs.position = Vector3(0, -0.5, 0)
	fb.add_child(fcs)
	add_child(fb)
	for look: String in _looks:
		if look.begins_with("boss"):
			await _boss(look, cam)
			continue
		var rig: HorseRig = HorseRig.new(look)
		add_child(rig)
		if look == "dead":
			rig.wrong = 1.0
			var glow: OmniLight3D = OmniLight3D.new()
			glow.light_color = HorseMesh.GLOW
			glow.light_energy = 2.2
			glow.omni_range = 2.6
			glow.shadow_enabled = false
			rig.attach("Body", glow, Vector3(0, 1.2, 0.0))
		for sh: Array in SHOTS:
			if not _only.is_empty() and not _only.has(str(sh[0])):
				continue
			var poses: Dictionary = sh[6]
			for k: String in ["head_low", "alert", "ears_back", "rear", "kick", "paw", "jaw", "shy", "collapse", "stagger", "turn"]:
				rig.set(k, float(poses.get(k, 0.0)))
			rig.speed = float(sh[1])
			# settle the gait blend and the smoothed turn, then put the stride where the shot wants it
			for i: int in 40:
				rig.tick(0.05)
			rig.phase = float(sh[2])
			rig.t = 1.0
			rig.pose()
			var yaw: float = deg_to_rad(float(sh[3]))
			var aim: Vector3 = poses.get("aim", Vector3(0, 1.15, -0.2))
			var dist: float = float(sh[5])
			cam.fov = float(poses.get("fov", 40.0))
			if str(sh[0]) == "rider_view":
				cam.global_position = Vector3(0, float(sh[4]) + HorseGait.body_bob(rig.gait, rig.phase), -0.14)
			else:
				cam.global_position = Vector3(-sin(yaw) * dist, float(sh[4]), -cos(yaw) * dist + aim.z)
			cam.look_at(aim, Vector3.UP)
			await get_tree().process_frame
			await get_tree().process_frame
			var path: String = _out.path_join("%s_%s.png" % [look, str(sh[0])])
			if DisplayServer.get_name() == "headless":
				print("[horse_shots] (headless: no frame) ", path)   # a dry run: the rig and the mesh are still built and posed
				continue
			await RenderingServer.frame_post_draw
			var img: Image = get_viewport().get_texture().get_image()
			img.save_png(path)
			print("[horse_shots] ", path)
		rig.queue_free()
		await get_tree().process_frame
	print("RESULT horse_shots: done")
	get_tree().quit()


## A real HorseBoss in each pose of BOSS_SHOTS.
func _boss(look: String, cam: Camera3D) -> void:
	get_tree().current_scene = self
	var b: HorseBoss = HorseBoss.new()
	b.boss_key = "totenross_fuhrmann" if look == "boss_rider" else "totenross"
	add_child(b)
	b.spawn_horse(Vector3(0, 0.02, 0), 1000.0)
	for sh: Array in BOSS_SHOTS:
		if not _only.is_empty() and not _only.has(str(sh[0])):
			continue
		b.debug_pose(0.0, str(sh[1]))
		for i: int in 45:
			await get_tree().physics_frame
		var yaw: float = deg_to_rad(float(sh[2]))
		var aim: Vector3 = Vector3(0, 1.75, -1.4) if str(sh[0]) == "head" else Vector3(0, 1.3, -0.2)
		cam.fov = 40.0
		cam.global_position = Vector3(-sin(yaw) * float(sh[4]), float(sh[3]), -cos(yaw) * float(sh[4]) + aim.z)
		cam.look_at(aim, Vector3.UP)
		await get_tree().process_frame
		var path: String = _out.path_join("%s_%s.png" % [look, str(sh[0])])
		if DisplayServer.get_name() == "headless":
			print("[horse_shots] (headless: no frame) ", path)
			continue
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(path)
		print("[horse_shots] ", path)
	b.queue_free()
	await get_tree().process_frame
