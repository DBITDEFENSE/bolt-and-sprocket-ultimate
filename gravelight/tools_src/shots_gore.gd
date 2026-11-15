extends Node
## Gore close-ups on Map 0 (docs/gore/gore_rework_2026-11.md): the same six scenes before and after the rework,
## driven through the calls the game makes (Effects.zombie_hit per bullet, Zombie.take_damage), with a fixed camera:
##   wall      a Ganger a metre in front of the taproom's east wall, three rifle hits then the kill
##   headshot  a bolt-rifle head kill
##   shotgun   a trench-gun kill at two metres (eight pellets)
##   pile      ten Gangers cut down in front of the bar, the room after them
##   snow      a kill out in the snow
##   lamp      a kill in the cellar vault (dark, lamp light)
## Each scene saves frames at fixed times after the first shot (<scene>_<nn>.png). Run it with --write-movie and
## --fixed-fps so game time is the same on every run (software rendering is far slower than real time):
##   tools/wsl_godot.sh --write-movie <dir>/gore.avi --fixed-fps 30 --path . res://gravelight/tools_src/shots_gore.tscn -- --out=<abs dir> [--only=wall,snow] [--gore=full]

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"

var _out: String = ""
var _only: PackedStringArray = PackedStringArray()
var _gore: String = "full"
var _scale: float = 0.67
var _hide_ui: bool = false
var _map: MapRoot
var _cam: Camera3D
var _saved: int = 0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--only="):
			_only = a.substr(7).split(",")
		elif a.begins_with("--gore="):
			_gore = a.substr(7)
		elif a.begins_with("--scale="):
			_scale = float(a.substr(8))
	if _out == "":
		_out = ProjectSettings.globalize_path("res://").path_join("docs/captures/gore_rework/after")
	DirAccess.make_dir_recursive_absolute(_out)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	ProfileSave.path = "user://_qa_shots_gore_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_shots_gore_settings.cfg"
	GLSettings.values["vfx_quality"] = "high"
	GLSettings.values["gore"] = _gore
	GLSettings.values["homage_bosses"] = false
	Campaign.reset()
	GameState.character_id = &"dutch"
	GameState.bot_count = 0
	GameState.bot_ai_mode = "off"
	GameState.god_mode = true
	seed(4711)
	# the movie is written at the project's 1920x1080 whatever --resolution says: draw the 3D at two thirds of it
	# (1280x720's worth of pixels; software rendering is slow) unless --scale= says otherwise
	get_viewport().scaling_3d_scale = _scale
	_map = (load(MAP) as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	_run.call_deferred()


func _process(_d: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


## `s` seconds of game time without drawing them (software rendering takes about a second a frame): the long
## waits between the moments worth a frame. The movie repeats its last picture meanwhile.
func _skip(s: float) -> void:
	if s <= 0.0:
		return
	RenderingServer.render_loop_enabled = false
	await get_tree().create_timer(s).timeout
	RenderingServer.render_loop_enabled = true
	await _frames(2)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("[shots_gore] (headless: no picture) ", name, _stats())
		return
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = _out.path_join(name + ".png")
	img.save_png(path)
	_saved += 1
	print("[shots_gore] ", path)


## What GoreFx holds right now (nothing on a build without it: the "before" run).
func _stats() -> String:
	var g: Variant = Effects.get("gore")
	if g == null:
		return ""
	var fx: GoreFx = g as GoreFx
	return "  marks: spatter %d, pools %d, drips %d, prints %d, smears %d  %s" % [fx.live(GoreFx.SPLAT), fx.live(GoreFx.POOL),
		fx.live(GoreFx.DRIP), fx.live(GoreFx.PRINT), fx.live(GoreFx.SMEAR), str(fx.stats)]


func _look(from: Vector3, at: Vector3, fov: float = 60.0) -> void:
	_cam.fov = fov
	_cam.global_position = from
	_cam.look_at(at, Vector3.UP)
	_cam.make_current()


func _wants(scene: String) -> bool:
	if _hide_ui:
		_hide_layers()
	return _only.is_empty() or _only.has(scene)


## The HUD, subtitles and toasts off; the look (LookPost) and the lens spatter (GoreFx's "Screen") stay.
func _hide_layers() -> void:
	for cl: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if not (cl is LookPost) and str(cl.name) != "Screen":
			(cl as CanvasLayer).visible = false


## `n` Gangers standing at `spots` (risen, awake), facing `face`.
func _stand(spots: Array, face: Vector3) -> Array[Zombie]:
	var before: Dictionary = {}
	for z: Zombie in _map.director.active_zombies():
		before[z] = true
	_map.director.spawn_burst(spots, spots.size())
	var mine: Array[Zombie] = []
	for z: Zombie in _map.director.active_zombies():
		if not before.has(z):
			mine.append(z)
	var t: float = 0.0
	while t < 9.0:
		var up: bool = true
		for z: Zombie in mine:
			if z.state == Zombie.State.EMERGE:
				up = false
		if up:
			break
		await _skip(0.25)
		t += 0.25
	for i: int in mine.size():
		var z: Zombie = mine[i]
		z.global_position = spots[i] as Vector3
		var d: Vector3 = face - z.global_position
		z.rotation.y = atan2(-d.x, -d.z)
		z.velocity = Vector3.ZERO
		z.set_physics_process(false)   # it stands where it was put until the shot that kills it
	await get_tree().physics_frame
	return mine


func _bone(z: Zombie, limb: StringName) -> Vector3:
	var at: Node3D = z.bone_attachment("Head" if limb == &"head" else "Chest")
	return at.global_position if at != null else z.global_position + Vector3.UP * (1.6 if limb == &"head" else 1.2)


## One trigger pull from `from` into `z`'s `limb`: `pellets` hits, each as the weapon's trace reports it.
func _fire(z: Zombie, from: Vector3, limb: StringName, weapon: StringName, pellets: int, kill: bool) -> void:
	if not z.is_active():
		return
	GLBus.weapon_fired.emit(1, weapon, false, from, (_bone(z, limb) - from).normalized())
	for i: int in pellets:
		var pos: Vector3 = _bone(z, limb) + Vector3(randf_range(-0.08, 0.08), randf_range(-0.1, 0.1), randf_range(-0.08, 0.08)) * (1.0 if pellets > 1 else 0.3)
		var dir: Vector3 = (pos - from).normalized()
		Effects.zombie_hit(pos, -dir, weapon, false)
		var last: bool = kill and i == pellets - 1
		if last:
			z.set_physics_process(true)
		z.take_damage(z.hp + 1.0 if last else minf(20.0, z.hp * 0.2), limb, weapon, 1, &"bullet")


## Frames at `times` (seconds after the call) named <scene>_<nn>.
func _sequence(scene: String, times: Array, first: int = 0) -> void:
	var t: float = 0.0
	for i: int in times.size():
		var wait: float = float(times[i]) - t
		if wait > 0.6:
			await _skip(wait - 0.1)
			await _secs(0.03)
		elif wait > 0.0:
			await _secs(wait)
		t = float(times[i])
		await _shot("%s_%02d" % [scene, first + i])


func _clear() -> void:
	print("[shots_gore] scene done", _stats())
	for z: Zombie in _map.director.active_zombies():
		z.deactivate()
	await _skip(0.3)


func _run() -> void:
	await _skip(14.0)     # the map's opening plays out
	RoundManager.stop()
	_map.director.kill_all(true)
	_hide_ui = true
	_cam = Camera3D.new()
	_map.add_child(_cam)
	var p: Player = _map.player
	if p != null:
		p.global_position = Vector3(8.0, 0.2, 3.0)   # out of every frame
	# The taproom: floor y = 0, the east wall's face x = 23.85, clear floor along z = 3, 7 and 13.
	# ---- wall: a Ganger a metre in front of the east wall, shot from the west
	if _wants("wall"):
		var spot: Vector3 = Vector3(18.6, 0.0, 1.15)      # the north wall's face is z = 0.15
		var from: Vector3 = Vector3(18.6, 1.5, 4.8)
		_look(Vector3(16.2, 1.6, 3.1), Vector3(18.9, 1.2, 0.4), 62.0)
		var zs: Array[Zombie] = await _stand([spot], from)
		await _shot("wall_00")
		for k: int in 3:
			_fire(zs[0], from, &"torso", &"m1_garand", 1, false)
			await _frames(3)
			await _shot("wall_%02d" % (1 + k))
			await _secs(0.25)
		_fire(zs[0], from, &"torso", &"m1_garand", 1, true)
		await _sequence("wall", [0.07, 0.2, 0.5, 1.2, 3.0, 7.0, 16.0], 4)
		await _clear()
	# ---- headshot
	if _wants("headshot"):
		var spot2: Vector3 = Vector3(22.6, 0.0, 3.0)
		var from2: Vector3 = Vector3(19.2, 1.6, 3.0)
		_look(Vector3(20.9, 1.75, 5.2), Vector3(23.2, 1.45, 2.7), 58.0)
		var zs2: Array[Zombie] = await _stand([spot2], from2)
		await _shot("headshot_00")
		_fire(zs2[0], from2, &"head", &"kar98k", 1, true)
		await _sequence("headshot", [0.04, 0.12, 0.25, 0.5, 0.9, 1.6, 3.0, 7.0], 1)
		await _clear()
	# ---- shotgun
	if _wants("shotgun"):
		var spot3: Vector3 = Vector3(16.6, 0.0, 1.15)
		var from3: Vector3 = Vector3(16.6, 1.45, 3.2)
		_look(Vector3(18.7, 1.6, 3.2), Vector3(16.4, 1.0, 0.4), 62.0)
		var zs3: Array[Zombie] = await _stand([spot3], from3)
		await _shot("shotgun_00")
		_fire(zs3[0], from3, &"torso", &"trench_gun", 8, true)
		await _sequence("shotgun", [0.04, 0.12, 0.25, 0.5, 1.2, 3.0, 7.0], 1)
		await _clear()
	# ---- pile: ten cut down between the tables and the east wall
	if _wants("pile"):
		var c: Vector3 = Vector3(20.6, 0.0, 7.0)
		var spots: Array = []
		for i: int in 10:
			spots.append(c + Vector3(float(i % 4) * 0.85 - 1.3, 0.0, float(i / 4) * 0.9 - 0.9))
		var from4: Vector3 = Vector3(15.6, 1.5, 7.0)
		_look(Vector3(17.3, 2.5, 10.4), c + Vector3(0.4, 0.4, 0), 68.0)
		var zs4: Array[Zombie] = await _stand(spots, from4)
		await _shot("pile_00")
		for i: int in zs4.size():
			var w: StringName = [&"thompson", &"trench_gun", &"m1_garand", &"mg42"][i % 4]
			_fire(zs4[i], from4, &"head" if i % 3 == 0 else &"torso", w, 8 if w == &"trench_gun" else 2, true)
			await _secs(0.18)
			if i == 4:
				await _shot("pile_01")
		await _sequence("pile", [0.3, 1.5, 4.0, 9.0, 18.0, 30.0], 2)
		_look(c + Vector3(-1.4, 1.5, 2.4), c + Vector3(0.6, 0.0, 0), 60.0)
		await _frames(2)
		await _shot("pile_08_floor")
		_look(Vector3(21.6, 1.5, 7.0), Vector3(23.85, 1.2, 7.0), 70.0)
		await _frames(2)
		await _shot("pile_09_wall")
		await _clear()
	# ---- snow: open ground north of the inn
	if _wants("snow"):
		var spot5: Vector3 = Vector3(15.0, 0.0, -8.0)
		var from5: Vector3 = spot5 + Vector3(-3.4, 1.5, 0.0)
		_look(spot5 + Vector3(-1.0, 2.3, -2.9), spot5 + Vector3(0.9, 0.3, 0.0), 62.0)
		var zs5: Array[Zombie] = await _stand([spot5], from5)
		await _shot("snow_00")
		for k: int in 2:
			_fire(zs5[0], from5, &"torso", &"thompson", 1, false)
			await _secs(0.12)
		_fire(zs5[0], from5, &"torso", &"m1_garand", 1, true)
		await _sequence("snow", [0.07, 0.3, 1.2, 3.0, 7.0, 16.0], 1)
		await _clear()
	# ---- lamp: the cellar vault (floor y = -3.2, the west wall's face x = 24.15, the lantern at 28.2, -1.1, 25)
	if _wants("lamp"):
		var spot6: Vector3 = Vector3(25.15, -3.2, 24.5)
		var from6: Vector3 = Vector3(28.4, -1.7, 24.5)
		_look(Vector3(26.9, -1.6, 21.9), Vector3(24.4, -2.3, 24.9), 62.0)
		var zs6: Array[Zombie] = await _stand([spot6], from6)
		await _shot("lamp_00")
		_fire(zs6[0], from6, &"torso", &"trench_gun", 8, false)
		await _secs(0.2)
		_fire(zs6[0], from6, &"head", &"kar98k", 1, true)
		await _sequence("lamp", [0.07, 0.3, 1.2, 3.0, 7.0, 16.0], 1)
		await _clear()
	# ---- lens: the player's own view after a kill at arm's length
	if _wants("lens") and p != null and Effects.get("gore") != null:
		_hide_ui = false
		for cl: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
			(cl as CanvasLayer).visible = true
		p.global_position = Vector3(19.0, 0.1, 9.5)
		p.rotation.y = -PI * 0.5      # facing east
		var pc: Array[Node] = p.find_children("*", "Camera3D", true, false)
		if not pc.is_empty():
			(pc[0] as Camera3D).make_current()
		await _skip(0.6)
		await _shot("lens_00")
		(Effects.get("gore") as GoreFx).screen.add(1.0)
		(Effects.get("gore") as GoreFx).hands(1.0)
		await _frames(3)
		await _shot("lens_01")
		await _sequence("lens", [1.2, 2.6], 2)
	print("[shots_gore] stats ", str(Effects.stats))
	print("[shots_gore] %d screenshots in %s" % [_saved, _out])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit()
