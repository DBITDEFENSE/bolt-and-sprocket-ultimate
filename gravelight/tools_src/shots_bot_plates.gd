extends Node
## Dev tool (U02 section 5, T-050): the bot nameplates (name, perk caps with the bonus perk ringed, health bar)
## and the squad command wheel, on Map 0, from the human's eyes and from a free camera; prints which plates are
## visible (occlusion) with each shot.
## Silent, off-screen, no mouse capture (D-058):
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://gravelight/tools_src/shots_bot_plates.tscn [-- --out=<dir>]
## -> <dir>/plates_<name>.png (default user://shots)

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"

var _map: MapRoot
var _out: String = "user://shots"
var _cam: Camera3D
var _t: float = 0.0
var _i: int = 0
var _busy: bool = false
## [name, seconds into the match, camera mode]: "front" (zombies' side, looking back at the squad), "behind"
## (over the human's shoulder), "eyes" (the human's camera, turned toward the nearest bot), "ledger" (HUD).
var _shots: Array = [
	["eyes_start", 9.0, "eyes"],
	["behind", 14.0, "behind"],
	["wheel", 18.0, "wheel"],
	["occluded", 26.0, "occluded"],
	["eyes_r1", 34.0, "eyes"],
	["far", 40.0, "far"],
	["downed", 60.0, "eyes_down"],
]


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out if _out.is_absolute_path() else ProjectSettings.globalize_path(_out))
	for b: String in ["Master"]:
		AudioServer.set_bus_mute(AudioServer.get_bus_index(b), true)
	ProfileSave.path = "user://_qa_bots_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GameState.character_id = &"peg"
	GameState.bot_count = 3
	GameState.bot_skill = "regular"
	_map = (load(MAP) as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GameState.god_mode = true
	_cam = Camera3D.new()
	_cam.far = 400.0
	add_child(_cam)


func _process(delta: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # D-058: never hold the mouse
	if _map == null or not _map.is_inside_tree() or _busy:
		return
	_t += delta
	if _i >= _shots.size():
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_qa_bots_profile.json"))
		get_tree().quit()
		return
	var s: Array = _shots[_i]
	if _t < float(s[1]):
		return
	_busy = true
	await _take(str(s[0]), str(s[2]))
	_i += 1
	_busy = false


func _bots() -> Array[Player]:
	var out: Array[Player] = []
	for n: Node in get_tree().get_nodes_in_group(&"bots"):
		out.append(n as Player)
	return out


func _squad_center() -> Vector3:
	var c: Vector3 = _map.player.global_position
	var n: int = 1
	for b: Player in _bots():
		c += b.global_position
		n += 1
	return c / float(n)


## The free camera stays inside the room: pulled in to the first wall between the squad and where it wanted to be.
func _place_cam(center: Vector3, want: Vector3) -> void:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(center, want, 1 | (1 << 8))
	var hit: Dictionary = _map.get_world_3d().direct_space_state.intersect_ray(q)
	_cam.global_position = (hit["position"] as Vector3).lerp(center, 0.2) if not hit.is_empty() else want
	_cam.current = true


func _take(shot_name: String, mode: String) -> void:

	var human: Player = _map.player
	if mode == "eyes_down":
		_bots()[0].take_hit(9999.0, null)   # a bot goes down: its plate drops to the floor with the bleed-out bar
		await get_tree().create_timer(1.0).timeout
		mode = "eyes"
	if mode == "occluded":
		# one bot just behind the wall the human faces: its plate must fade out (the others stay)
		var cam0: Camera3D = human.camera
		var from: Vector3 = cam0.global_position
		var q0: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from - cam0.global_basis.z * 40.0, 1, [human.get_rid()])
		var hit0: Dictionary = _map.get_world_3d().direct_space_state.intersect_ray(q0)
		if not hit0.is_empty():
			var b0: Player = _bots()[2]
			b0.global_position = (hit0["position"] as Vector3) - cam0.global_basis.z * 1.5 + Vector3.DOWN * 1.2
			b0.get_node("Brain").set_physics_process(false)
		human.camera.current = true
		await get_tree().create_timer(1.2).timeout
		mode = "eyes_keep"
	if mode == "wheel":
		var wh: BotCommandWheel = _map.squad.wheel
		wh.open()
		wh.state.look(Vector2(140, 10))   # pointing at "Hold here"
		mode = "eyes"
	var center: Vector3 = _squad_center() + Vector3.UP * 1.0
	match mode:
		"eyes_keep":
			human.camera.current = true
		"eyes":
			var nearest: Player = null
			var bd: float = INF
			for b2: Player in _bots():
				var d: float = b2.global_position.distance_to(human.global_position)
				if d < bd:
					bd = d
					nearest = b2
			if nearest != null:
				var to: Vector3 = nearest.global_position - human.global_position
				human.rotation.y = atan2(-to.x, -to.z)
				human.set("_pitch", -0.08)
			human.camera.current = true
		"far":
			var back2: Vector3 = human.global_basis.z
			_place_cam(center, center + back2 * 16.0 + Vector3(0.0, 4.0, 0))
			_cam.look_at(center, Vector3.UP)
		"front":
			var fwd: Vector3 = -human.global_basis.z
			_place_cam(center, center + fwd * 7.0 + Vector3(1.5, 1.4, 0))
			_cam.look_at(center, Vector3.UP)
		_:
			var back: Vector3 = human.global_basis.z
			_place_cam(center, center + back * 6.5 + Vector3(2.0, 2.6, 0))
			_cam.look_at(center + Vector3(0, 0.2, 0) - back * 3.0, Vector3.UP)
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = _out.path_join("plates_%s.png" % shot_name)
	img.save_png(path)
	var vis: PackedStringArray = []
	for b3: Player in _bots():
		vis.append("%s %s" % [Net.display_name(b3.player_id), "visible" if _map.squad.plates._sees(b3) else "hidden"])
	print("shot %s  (round %d; plates: %s)" % [path, RoundManager.current_round, ", ".join(vis)])
	if _map.squad.wheel.state.is_open:
		_map.squad.wheel.close()
	human.camera.current = true
