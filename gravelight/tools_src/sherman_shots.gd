extends Node3D
## T-249: frames of the Sherman event for the owner's look (docs/captures/u18_sherman/<label>/).
##   turntable (default): the tank, the wreck, the dive bomber and a bomb on a snow floor, lit; seconds to run.
##   --map: the Inn itself (map00): the Sherman parked on the road outside the gate, close on it, a fire zombie, the
##          air raid (the warning on the HUD, the bombs' shadows and rings, a burst), the dive bomber in its dive over
##          the yard, the wreck burning. One map load (~8 min under WSL's software GL).
##   sh tools/wsl_godot.sh --res=1920x1080 --path . res://gravelight/tools_src/sherman_shots.tscn -- --label=<label> [--map] [--only=a,b]
## Never with a window on the owner's PC (WSL / Xvfb only).

const MAP0: String = "res://gravelight/maps/map00_crossroads/map00.tscn"

## Turntable: [name, what, camera yaw deg (0 = from the front), camera height, distance, aim]
const TURN: Array = [
	["tank_quarter", "tank", 38.0, 2.4, 9.5, Vector3(0, 1.3, -0.3)],
	["tank_side", "tank", 90.0, 1.8, 10.0, Vector3(0, 1.2, 0.0)],
	["tank_front", "tank", 4.0, 1.9, 9.0, Vector3(0, 1.2, -1.0)],
	["tank_rear_quarter", "tank", 145.0, 2.8, 9.5, Vector3(0, 1.3, 0.3)],
	["tank_top", "tank", 60.0, 6.0, 7.0, Vector3(0, 1.6, 0.0)],
	["tank_running_gear", "tank", 80.0, 0.9, 5.2, Vector3(1.1, 0.5, 0.0)],
	["tank_turret", "tank", 25.0, 3.4, 4.6, Vector3(0, 2.3, -0.4)],
	["wreck_quarter", "wreck", 40.0, 2.6, 10.0, Vector3(0, 1.3, 0.0)],
	["stuka_below", "stuka", 30.0, -6.0, 18.0, Vector3(0, 0, 0)],
	["stuka_side", "stuka", 90.0, 1.0, 19.0, Vector3(0, 0, 0)],
	["stuka_quarter", "stuka", 35.0, 4.0, 17.0, Vector3(0, 0, 0)],
	["bomb", "bomb", 70.0, 0.6, 3.2, Vector3(0, 0.6, 0)],
]

var _out: String = ""
var _only: PackedStringArray = []
var _map_mode: bool = false
var _cam: Camera3D


func _ready() -> void:
	var label: String = "look"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--label="):
			label = a.substr(8)
		elif a.begins_with("--only="):
			_only = a.substr(7).split(",", false)
		elif a == "--map":
			_map_mode = true
	_out = ProjectSettings.globalize_path("res://").path_join("docs/captures/u18_sherman").path_join(label)
	DirAccess.make_dir_recursive_absolute(_out)
	if _map_mode:
		_run_map.call_deferred()
	else:
		_run_turn.call_deferred()


func _shoot(name_: String) -> void:
	var path: String = _out.path_join("%s.png" % name_)
	if DisplayServer.get_name() == "headless":
		print("[sherman_shots] (headless: no frame) ", path)
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("[sherman_shots] ", path)


func _want(n: String) -> bool:
	return _only.is_empty() or _only.has(n)


# ================================================================== the turntable

func _run_turn() -> void:
	get_tree().current_scene = self
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.36, 0.4, 0.46)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.6, 0.7)
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	env.environment = e
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -32, 0)
	sun.light_energy = 1.1
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.shadow_enabled = true
	add_child(sun)
	var floor_mi: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(80, 80)
	floor_mi.mesh = pm
	var fm: StandardMaterial3D = StandardMaterial3D.new()
	fm.albedo_color = Color(0.62, 0.64, 0.68)
	fm.roughness = 0.95
	floor_mi.material_override = fm
	add_child(floor_mi)
	_cam = Camera3D.new()
	_cam.fov = 40.0
	add_child(_cam)
	_cam.current = true
	var tank: ShermanTank = ShermanTank.new()
	tank.setup(ShermanEvent.table()["tank"], ShermanEvent.table()["assist"], 8000.0)
	add_child(tank)
	tank.aim_world(Vector3(-6, 1.5, -20))
	for i: int in 120:
		await get_tree().physics_frame
	var wreck: ShermanTank = null
	var plane: StukaPlane = null
	var bomb: MeshInstance3D = null
	for sh: Array in TURN:
		if not _want(str(sh[0])):
			continue
		var what: String = str(sh[1])
		tank.visible = what == "tank"
		if what == "wreck" and wreck == null:
			tank.visible = false
			wreck = ShermanTank.new()
			wreck.setup(ShermanEvent.table()["tank"], ShermanEvent.table()["assist"], 8000.0)
			add_child(wreck)
			wreck.wreck(false)
			for i2: int in 60:
				await get_tree().physics_frame
		if wreck != null:
			wreck.visible = what == "wreck"
		if what == "stuka" and plane == null:
			plane = StukaPlane.new()
			plane.build()
			add_child(plane)
			plane.position = Vector3(0, 5.0, 0)
		if plane != null:
			plane.visible = what == "stuka"
		if what == "bomb" and bomb == null:
			bomb = StukaPlane.instance("bomb")
			add_child(bomb)
			bomb.position = Vector3(0, 0.6, 0)
			bomb.rotation.y = PI * 0.5
		if bomb != null:
			bomb.visible = what == "bomb"
		var yaw: float = deg_to_rad(float(sh[2]))
		var aim: Vector3 = sh[5]
		if what == "stuka":
			aim += Vector3(0, 5.0, 0)
		var dist: float = float(sh[4])
		_cam.global_position = aim + Vector3(-sin(yaw) * dist, float(sh[3]) - (aim.y if what != "stuka" else 0.0), -cos(yaw) * dist)
		_cam.look_at(aim, Vector3.UP)
		await get_tree().process_frame
		await get_tree().process_frame
		await _shoot(str(sh[0]))
	print("RESULT sherman_shots: done")
	get_tree().quit()


# ================================================================== the Inn

func _run_map() -> void:
	GameState.bot_count = 0
	GameState.god_mode = true
	var map: Node3D = (load(MAP0) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(map)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().current_scene = map
	var root: MapRoot = map as MapRoot
	var t: float = 0.0
	while (root.player == null or not root.player.is_inside_tree()) and t < 60.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	for i: int in 30:
		await get_tree().process_frame
	GameState.god_mode = true
	root.player.set_process_unhandled_input(false)
	root.director.kill_all(true)
	RoundManager.stop()
	for z: String in ["YARD", "GROUNDS", "STABLE"]:
		GameState.open_zone(StringName(z))
	var ev: ShermanEvent = map.get_node_or_null("ShermanEvent") as ShermanEvent
	if ev == null:
		print("RESULT sherman_shots: no ShermanEvent on map00")
		get_tree().quit()
		return
	_cam = Camera3D.new()
	_cam.fov = 60.0
	map.add_child(_cam)
	_cam.current = true
	root.player.global_position = Vector3(12.0, 0.05, 8.0)
	ev.force_assist()
	var tk: ShermanTank = ev.tank
	tk.aim_world(Vector3(18, 1.5, 44))
	for i: int in 90:
		await get_tree().physics_frame
	if _want("inn_tank_road"):
		_cam.global_position = Vector3(15.5, 1.7, 44.0)
		_cam.look_at(tk.global_position + Vector3(0, 1.4, 0), Vector3.UP)
		await _frames(4)
		await _shoot("inn_tank_road")
	if _want("inn_tank_close"):
		_cam.global_position = tk.global_transform * Vector3(-4.5, 2.0, -5.5)
		_cam.look_at(tk.global_transform * Vector3(0, 1.3, 0), Vector3.UP)
		await _frames(4)
		await _shoot("inn_tank_close")
	if _want("inn_tank_rear"):
		_cam.global_position = tk.global_transform * Vector3(4.0, 2.4, 7.0)
		_cam.look_at(tk.global_transform * Vector3(0, 1.3, 0), Vector3.UP)
		await _frames(4)
		await _shoot("inn_tank_rear")
	# the tank firing (the 75 mm's flash and smoke)
	if _want("inn_tank_fires"):
		_cam.global_position = tk.global_transform * Vector3(-6.5, 1.8, -3.0)
		_cam.look_at(tk.global_transform * Vector3(0, 2.0, -5.0), Vector3.UP)
		tk.fire_main_fx(tk.muzzle(), tk.global_transform * Vector3(0, 0.5, -30.0))
		await _frames(2)
		await _shoot("inn_tank_fires")
	# a fire zombie
	if _want("inn_fire_zombie"):
		var spec: Dictionary = {"tier": &"shamble", "health": 100000.0, "variant": "villager"}
		var z: Zombie = root.director.activate_reserved(spec, Vector3(12.0, 0, 44.0))
		if z != null:
			FireZombie.make(z, ev.cfg["fire_zombie"], tk, false)
			for i3: int in 150:
				await get_tree().physics_frame
			var zp: Vector3 = z.global_position
			_cam.global_position = zp + Vector3(2.6, 1.5, -2.2)
			_cam.look_at(zp + Vector3(0, 1.1, 0), Vector3.UP)
			await _frames(3)
			await _shoot("inn_fire_zombie")
			z.kill_silently()
	# the wreck
	tk.wreck(true)
	for i4: int in 120:
		await get_tree().physics_frame
	if _want("inn_wreck"):
		_cam.global_position = tk.global_transform * Vector3(-5.0, 2.2, -6.0)
		_cam.look_at(tk.global_transform * Vector3(0, 1.5, 0), Vector3.UP)
		await _frames(4)
		await _shoot("inn_wreck")
	# the dive bomber over the yard
	if _want("inn_stuka"):
		var plane: StukaPlane = StukaPlane.new()
		map.add_child(plane)
		plane.fly(tk.global_position + Vector3.UP, (Vector3(-260, 0, -320) - tk.global_position).normalized(), ev.cfg["stuka"])
		plane.flying = false
		var rd: float = float(plane.get("_release_d"))
		plane.pose_at(rd - 40.0)
		_cam.global_position = Vector3(14.0, 1.6, 41.0)
		_cam.look_at(plane.global_position, Vector3.UP)
		_cam.fov = 50.0
		await _frames(3)
		await _shoot("inn_stuka")
		plane.queue_free()
		_cam.fov = 60.0
	# the air raid: the warning, the shadows and rings, a burst
	if _want("inn_raid"):
		ev.raid.start()
		root.player.global_position = Vector3(14.0, 0.05, 41.0)
		ev.raid.phase = AirRaid.Phase.BOMBING
		ev.raid.t = 0.0
		ev.raid.cfg = (ev.raid.cfg as Dictionary).duplicate()
		ev.raid.cfg["duration"] = 30.0
		for p: Vector3 in [Vector3(9.0, 0, 44.0), Vector3(24.0, 0, 41.0), Vector3(16.0, 0, 37.0)]:
			ev.raid.net_marker(p, 2.2)
		ev.raid.net_marker(Vector3(28.0, 0, 45.0), 0.45)
		_cam.global_position = Vector3(12.0, 3.2, 47.5)
		_cam.look_at(Vector3(19.0, 0.5, 40.0), Vector3.UP)
		var t2: float = 0.0
		while t2 < 0.5:
			await get_tree().process_frame
			t2 += get_process_delta_time()
		await _shoot("inn_raid")
	print("RESULT sherman_shots: done")
	get_tree().quit()


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame
