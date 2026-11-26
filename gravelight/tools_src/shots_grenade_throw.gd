extends Node3D
## T-288 (the owner: "MAKE A THROWING ANIMATION FOR GRENADES"): the throw in frame sequences, in vm_shots' lit studio.
##   fp_NN.png     first person: the press, the pin, the draw back, the cook, the release, the follow-through
##   cook_NN.png   first person: holding a cooked grenade as the fuse runs down (the tremor)
##   tp_NN.png     third person: a body cooking (PF_COOK), then the release and the swing back to the gun
##   tools/wsl_godot.sh --res=1280x720 --path . res://gravelight/tools_src/shots_grenade_throw.tscn -- --out=<dir>
## Rendered runs only under WSL + Xvfb (never a window on the owner's PC).

const DT: float = 1.0 / 60.0
var _out: String = "user://t288"
var _p: Player
var _cam: Camera3D
var _saved: int = 0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.045, 0.04)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.4, 0.38, 0.45)
	e.ambient_light_energy = 0.35
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 20, 0)
	sun.light_energy = 0.4
	add_child(sun)
	var lantern: OmniLight3D = OmniLight3D.new()
	lantern.light_color = Color(1.0, 0.72, 0.42)
	lantern.light_energy = 2.4
	lantern.omni_range = 7.0
	lantern.position = Vector3(0.9, 0.6, -1.2)
	add_child(lantern)
	var floor_mi: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(30, 30)
	floor_mi.mesh = pm
	var fm: StandardMaterial3D = StandardMaterial3D.new()
	fm.albedo_color = Color(0.3, 0.26, 0.22)
	floor_mi.material_override = fm
	add_child(floor_mi)
	var floor_body: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(30, 0.2, 30)
	cs.shape = bs
	cs.position = Vector3(0, -0.1, 0)
	floor_body.add_child(cs)
	add_child(floor_body)
	var wall: MeshInstance3D = MeshInstance3D.new()
	var wm: PlaneMesh = PlaneMesh.new()
	wm.size = Vector2(16, 8)
	wall.mesh = wm
	wall.rotation_degrees = Vector3(90, 0, 0)
	wall.position = Vector3(0, 2, -9)
	wall.material_override = fm
	add_child(wall)
	_p = Player.new()
	add_child(_p)
	_p.set_physics_process(false)
	_p.set_process_unhandled_input(false)
	_p.global_position = Vector3(0, 0.05, 0)
	_cam = _p.camera
	_cam.make_current()
	_run.call_deferred()


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("[t288] (headless: no picture) ", name)
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(name + ".png"))
	_saved += 1


func _tick(intent: Dictionary) -> void:
	_p.weapons.tick(DT, intent)
	await get_tree().process_frame


func _run() -> void:
	for i: int in 30:
		await get_tree().process_frame
	var h: WeaponHolder = _p.weapons
	h.give_weapon(&"thompson")
	h.current_index = h.slots.find(h.find_weapon(&"thompson"))
	h.call("_rebuild_gun")
	h.set("_swap_t", 0.0)
	for i0: int in 40:
		await _tick({})
	# first person: press, hold 0.9 s, release, follow through; a frame every 3 ticks (0.05 s)
	h.grenades = 3
	var n: int = 0
	for i1: int in 54:
		await _tick({"lethal_held": true})
		if i1 % 3 == 0:
			await _shot("fp_%02d" % n)
			n += 1
	for i2: int in 24:
		await _tick({"lethal_held": false})
		if i2 % 2 == 0:
			await _shot("fp_%02d" % n)
			n += 1
	for i3: int in 30:
		await _tick({})
	# cook to the last second of the fuse: the tremor (frames every 0.1 s over the last 1.2 s), then let go
	h.grenades = 3
	var fuse: float = float(GLData.table("weapons")["lethal"]["frag"]["fuse"])
	var ticks: int = int((fuse - 0.3) / DT)
	var m: int = 0
	for i4: int in ticks:
		await _tick({"lethal_held": true})
		if i4 > ticks - 72 and i4 % 6 == 0:
			await _shot("cook_%02d" % m)
			m += 1
	await _tick({"lethal_held": false})
	for i5: int in 40:
		await _tick({})
	# third person: a body 3 m in front, side-on; 0.6 s cooking (PF_COOK), then the release and the swing
	h.slots.clear()
	h.call("_rebuild_gun")
	var b: RemoteBody = RemoteBody.new()
	add_child(b)
	b.setup(&"dutch", 41)
	b.global_position = Vector3(0.0, 0.0, -2.2)
	b.rotation.y = deg_to_rad(60.0)
	_cam.global_position = Vector3(0, 1.45, 0.0)
	_cam.fov = 38.0
	_cam.look_at(b.global_position + Vector3(0, 1.3, 0))
	var k: int = 0
	for i6: int in 60:
		b.update_pose(DT, 0.0, 0.0, NetMatch.PF_FLOOR | (NetMatch.PF_COOK if i6 > 12 else 0))
		await get_tree().process_frame
		if i6 % 6 == 0:
			await _shot("tp_%02d" % k)
			k += 1
	var fwd: Vector3 = -b.global_basis.z
	var rel: Vector3 = b.global_position + Vector3.UP * 1.55 + fwd * 0.45
	b.fire(4, &"frag", rel, rel + fwd)
	for i7: int in 30:
		b.update_pose(DT, 0.0, 0.0, NetMatch.PF_FLOOR)
		await get_tree().process_frame
		if i7 % 3 == 0:
			await _shot("tp_%02d" % k)
			k += 1
	print("[t288] %d pictures in %s" % [_saved, _out])
	get_tree().quit()
