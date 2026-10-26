extends Node
## Dev tool (T-092, UPDATE_05 section 4): the people in the real Map 0. The opening's patrons at their tables,
## the three bots close up (calm, then shooting a burst of zombies), the risen patron, and the Cousins' round (the
## dev path: round 10, as smoke_cousins and capture --only=cousins use) with the camera on each cousin.
## `-- --legacy-people` gives the before shots. Silent, off-screen, no mouse capture:
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1920x1080 --path . res://gravelight/tools_src/shots_people_ingame.tscn -- --out=<dir>
## -> <dir>/ingame_patrons.png, ingame_squad_close.png, ingame_squad_fight.png, ingame_cousin_<n>.png

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"

var _out: String = "user://shots/people_ingame"
var _map: MapRoot = null


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out if _out.is_absolute_path() else ProjectSettings.globalize_path(_out))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	ProfileSave.path = "user://_qa_people_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	_run.call_deferred()


func _process(_d: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = _out.path_join(name + ".png")
	img.save_png(path)
	print("[people_ingame] ", path)


var _cam: Camera3D = null


## A free camera `dist` metres from `at` (toward `toward`, rotated by `side` radians about Y), aimed at `height`.
func _look(_p: Player, at: Vector3, dist: float, side: float = 0.0, height: float = 1.45, toward: Vector3 = Vector3.INF) -> void:
	if _cam == null:
		_cam = Camera3D.new()
		_cam.fov = 55.0
		get_tree().root.add_child(_cam)
	var ref: Vector3 = toward if toward != Vector3.INF else _p.global_position
	var from_dir: Vector3 = ref - at
	from_dir.y = 0.0
	from_dir = from_dir.normalized() if from_dir.length() > 0.1 else Vector3.BACK
	from_dir = from_dir.rotated(Vector3.UP, side)
	_cam.global_position = at + from_dir * dist + Vector3(0, 1.55, 0)
	_cam.look_at(at + Vector3(0, height, 0), Vector3.UP)
	_cam.current = true


func _run() -> void:
	GameState.character_id = &"dutch"
	GameState.bot_count = 3
	Campaign.reset()
	var n: Node = (load(MAP) as PackedScene).instantiate()
	get_tree().root.add_child(n)
	get_tree().current_scene = n
	_map = n as MapRoot
	GameState.god_mode = true
	await _secs(3.0)
	var p: Player = _map.player
	p.set_process_unhandled_input(false)
	# the opening: patrons at their tables (Rother at the corner table, Kubiak beside him)
	var start: Vector3 = p.global_position
	_look(p, Vector3(18.6, 0.0, 8.6), 2.6, 0.0, 1.0, Vector3(18.7, 0.0, 12.0))
	await _secs(1.5)
	await _shot("ingame_patrons")
	# the squad close up: freeze the bots where they stand, then look at them
	p.global_position = start
	await _secs(1.0)
	var bots: Array[Player] = []
	for b: Node in get_tree().get_nodes_in_group(&"players"):
		if b is Player and b != p:
			bots.append(b as Player)
	if not bots.is_empty():
		var c: Vector3 = Vector3.ZERO
		for b2: Player in bots:
			c += b2.global_position
		c /= float(bots.size())
		if _map.squad != null:
			_map.squad.process_mode = Node.PROCESS_MODE_DISABLED
		var into: Vector3 = -p.global_basis.z   # the spawn faces the room: stand in it and look back at them
		into.y = 0.0
		into = into.normalized() if into.length() > 0.1 else Vector3.FORWARD
		var side: Vector3 = into.cross(Vector3.UP)
		for i: int in bots.size():
			var b3: Player = bots[i]
			b3.set_physics_process(false)
			b3.global_position = c + side * (-0.95 + 0.95 * float(i))
		_look(p, c, 3.4, 0.0, 1.35, c + into * 3.0)
		for b4: Player in bots:
			var d4: Vector3 = _cam.global_position - b4.global_position
			b4.rotation.y = atan2(-d4.x, -d4.z)   # face the camera (forward is -Z)
			if b4.remote_body != null:
				for f: int in 30:
					b4.remote_body.update_pose(1.0 / 60.0, 0.0, 0.0, 0)
		await _secs(0.8)
		await _shot("ingame_squad_close")
		for b5: Player in bots:
			b5.set_physics_process(true)
		if _map.squad != null:
			_map.squad.process_mode = Node.PROCESS_MODE_INHERIT
	# a fight: a burst of zombies in front of the squad, the camera behind their shoulders
	var dir: ZombieDirector = _map.director
	if dir != null and not bots.is_empty():
		var nav: RID = p.get_world_3d().navigation_map
		var fwd: Vector3 = (bots[0].global_position - p.global_position)
		fwd.y = 0.0
		fwd = fwd.normalized()
		var pts: Array = []
		for i2: int in 5:
			pts.append(NavigationServer3D.map_get_closest_point(nav, bots[0].global_position + fwd * (5.0 + float(i2)) + fwd.cross(Vector3.UP) * (float(i2) - 2.0)))
		dir.spawn_burst(pts, 5)
		_look(p, bots[0].global_position + fwd * 2.0, 4.5, 0.9, 1.4)
		await _secs(2.5)
		await _shot("ingame_squad_fight")
		dir.kill_all(true)
	# the Cousins' round (the dev path the Cousins smoke uses)
	if dir != null and dir.cousins != null:
		RoundManager.debug_set_round(10)
		var t: float = 0.0
		var found: Array[Node3D] = []
		while t < 25.0 and found.size() < 3:
			await _secs(0.5)
			t += 0.5
			found.clear()
			for z: Node in dir.find_children("*", "HomageBoss", true, false):
				if (z as Node3D).visible and (z as Node3D).is_inside_tree():
					found.append(z as Node3D)
		print("[people_ingame] cousins on the map: %d after %.1fs" % [found.size(), t])
		for k: int in found.size():
			_look(p, found[k].global_position, 3.4, 0.0, 1.5)
			await _secs(0.6)
			await _shot("ingame_cousin_%d" % (k + 1))
	GameState.god_mode = false
	get_tree().quit()
