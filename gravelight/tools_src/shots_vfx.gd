extends Node
## T-095 VFX close-ups on Map 0 (rendered, off-screen, silent): deterministic calls into Effects with a camera a
## metre or two away, so every piece can be looked at without waiting for luck in a clip:
##   flash_<class>   one muzzle flash per class (plus a taught Thompson and the Totenglocke's violet) against the
##                   taproom's east wall, caught on the frame it is born
##   casings         twenty cases of four kinds on the floorboards after they settled
##   impacts         one strike per surface on the wall / floor / snow / the cage, debris and decal
##   toll_ring       the Great Toll's refraction ring mid-flight in the taproom
##   shatter         a Glasshide burst
##   yard_snow       the near snow layer from the yard, looking across the field
##   stable_motes    the stable's moon shafts with their dust
##   squad_firing    3 bots firing at a burst of zombies in front of the bar (3 frames in a row)
## Usage: godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://gravelight/tools_src/shots_vfx.tscn
##        [-- --out=<abs dir>]   (default morning/screenshots/u05/vfx)

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"

var _out: String = ""
var _map: MapRoot
var _cam: Camera3D
var _saved: int = 0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	if _out == "":
		_out = ProjectSettings.globalize_path("res://").path_join("morning/screenshots/u05/vfx")
	DirAccess.make_dir_recursive_absolute(_out)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	ProfileSave.path = "user://_qa_shots_vfx_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_shots_vfx_settings.cfg"
	GLSettings.values["vfx_quality"] = "high"
	GLSettings.values["gore"] = "full"
	GLSettings.values["homage_bosses"] = false
	Campaign.reset()
	GameState.character_id = &"dutch"
	GameState.bot_count = 3
	GameState.bot_ai_mode = "off"
	GameState.god_mode = true
	_map = (load(MAP) as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	_run.call_deferred()


func _process(_d: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = _out.path_join(name + ".png")
	img.save_png(path)
	_saved += 1
	print("[shots_vfx] ", path)


func _look(from: Vector3, at: Vector3, fov: float = 60.0) -> void:
	_cam.fov = fov
	_cam.global_position = from
	_cam.look_at(at, Vector3.UP)
	_cam.make_current()


func _run() -> void:
	await _secs(4.0)
	RoundManager.stop()
	_cam = Camera3D.new()
	_map.add_child(_cam)
	# ---- flashes: a muzzle point in the taproom, 0.9 m in front of the east wall, camera off to the side
	var mz: Vector3 = Vector3(20.0, 1.45, 8.0)
	var fwd: Vector3 = Vector3.RIGHT
	for cls: Array in [["pistol", &"m1911", false], ["smg", &"thompson", false], ["smg_up", &"thompson_up", true], ["rifle", &"m1_garand", false],
			["bolt", &"kar98k", false], ["shotgun", &"trench_gun", false], ["lmg", &"mg42", false], ["launcher", &"panzerschreck", false], ["wonder", &"totenglocke", false]]:
		_look(mz + Vector3(-0.9, 0.15, 1.1), mz + fwd * 0.15, 50.0)
		await _frames(2)
		Effects.muzzle_flash(mz, fwd, cls[1], bool(cls[2]), 1.0, true)
		await _shot("flash_%s" % cls[0])
		await _secs(0.3)
	# ---- casings on the floorboards
	var floor_p: Vector3 = Vector3(16.0, 0.0, 8.0)
	for i: int in 20:
		var kinds: Array = [&"m1911", &"kar98k", &"trench_gun", &"mg42"]
		Effects.casing("rifle", floor_p + Vector3(0.3 * (i % 5) - 0.6, 1.0, 0.2 * (i / 5) - 0.3), Vector3(randf_range(-0.6, 0.6), 1.0, randf_range(-0.6, 0.6)), Basis(Vector3.UP, randf() * TAU), kinds[i % 4])
	_look(floor_p + Vector3(0.0, 0.7, 1.2), floor_p + Vector3(0, 0.02, 0), 45.0)
	await _secs(1.2)
	await _shot("casings")
	# ---- impacts: wall (plaster), floor (wood), the hearth (stone), snow outside, the cage (metal)
	var space: PhysicsDirectSpaceState3D = _map.get_world_3d().direct_space_state
	var strikes: Array = [["plaster", Vector3(20.0, 1.5, 8.0), Vector3.RIGHT, Vector3(22.0, 1.5, 8.0)], ["wood", Vector3(16.0, 1.2, 10.0), Vector3.DOWN, Vector3(16.0, -0.5, 10.0)],
		["stone", Vector3(12.0, 1.0, 1.6), Vector3.FORWARD, Vector3(12.0, 1.0, -0.5)], ["snow", Vector3(21.0, 1.2, -4.0), Vector3.DOWN, Vector3(21.0, -1.0, -4.0)]]
	for s: Array in strikes:
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(s[1], s[3], 1)
		var res: Dictionary = space.intersect_ray(q)
		if res.is_empty():
			print("[shots_vfx] no hit for ", s[0])
			continue
		var pos: Vector3 = res["position"]
		var nrm: Vector3 = res["normal"]
		var surf: String = Effects.surface_of(res["collider"], pos, nrm, space)
		print("[shots_vfx] %s strike resolves as '%s' on %s" % [s[0], surf, (res["collider"] as Node).name])
		_look(pos + nrm * 0.9 + Vector3(0.25, 0.3, 0.0), pos, 45.0)
		await _frames(2)
		for k: int in 5:
			var off: Vector3 = Vector3(randf_range(-0.12, 0.12), randf_range(-0.12, 0.12), randf_range(-0.12, 0.12))
			off -= nrm * off.dot(nrm)
			Effects.impact(pos + off, nrm, surf, res["collider"])
		await _frames(4)
		await _shot("impact_%s" % s[0])
		await _secs(0.6)
		await _shot("impact_%s_decal" % s[0])
	# ---- the Great Toll ring
	var tp: Vector3 = Vector3(14.0, 0.0, 8.0)
	_look(tp + Vector3(-3.0, 2.2, 4.0), tp + Vector3(0, 1.0, 0), 65.0)
	await _frames(2)
	Effects.toll_ring(tp, 8.0)
	await _secs(0.18)
	await _shot("toll_ring")
	# ---- a shatter
	var sp: Vector3 = Vector3(10.0, 0.0, 8.0)
	_look(sp + Vector3(-1.5, 1.6, 2.2), sp + Vector3(0, 1.1, 0), 55.0)
	await _frames(2)
	Effects.shatter(sp + Vector3.UP * 1.1, Color(0.6, 0.3, 1.0), 40, 6.0)
	await _frames(3)
	await _shot("shatter")
	# ---- the yard and the near snow: the camera out in the yard looking south-east across the field
	_look(Vector3(18.0, 1.7, 40.0), Vector3(40.0, 1.0, 58.0), 70.0)
	await _secs(2.5)
	await _shot("yard_snow")
	print("[shots_vfx] near snow emitting: ", str(Effects.atmosphere() != null and Effects.atmosphere().call("near_snow_emitting")))
	# ---- the stable's moon shafts
	_look(Vector3(10.5, 1.7, 25.0), Vector3(16.0, 2.5, 32.5), 70.0)
	await _secs(1.0)
	await _shot("stable_motes")
	# ---- the squad firing at a burst
	var p: Player = _map.player
	var nav: RID = p.get_world_3d().navigation_map
	var pts: Array = []
	for i: int in 6:
		pts.append(NavigationServer3D.map_get_closest_point(nav, Vector3(8.0 + float(i % 3) * 1.2, 0.0, 4.0 + float(i / 3) * 1.5)))
	_map.director.spawn_burst(pts, 6)
	for z: Zombie in _map.director.active_zombies():
		z.hp = 1.0e9
	await _secs(2.5)
	var b0: Player = _map.squad.brains[0].player
	for k: int in 3:
		var back: Vector3 = b0.global_basis.z
		_look(b0.global_position + back * 1.6 + Vector3(0.7, 1.75, 0.0), b0.global_position + Vector3(0, 1.4, 0) - back * 3.0, 65.0)
		await _frames(1)
		await _shot("squad_firing_%d" % k)
		await _secs(0.4)
	print("[shots_vfx] stats ", str(Effects.stats))
	print("[shots_vfx] %d screenshots in %s" % [_saved, _out])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit()
