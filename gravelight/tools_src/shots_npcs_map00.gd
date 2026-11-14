extends Node
## Dev tool (T-246): the owner's two screenshots again, in the real Map 0 at night: Trudi Hanke waiting at the
## stable (round 2, when she turns up; her knife, then a rifle as if handed one), seen from a survivor's eye 3-4 m
## off, and the courier and the deserter (the extra people) with their life on. Rendered only through WSL:
##   sh tools/wsl_godot.sh --res=1920x1080 --path . res://gravelight/tools_src/shots_npcs_map00.tscn -- --out=res://docs/captures/u18_npcs/map00
## -> <out>/map00_<shot>.png

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"

var _out: String = "user://shots/npcs_map00"
var _map: MapRoot = null
var _cam: Camera3D = null
var _t: float = 0.0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out) if _out.begins_with("res://") or _out.begins_with("user://") else _out)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	ProfileSave.path = "user://_qa_npcs_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_npcs_settings.cfg"
	GameState.bot_count = 0
	Campaign.reset()
	RemoteBody.pose_lod = false
	_run.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _t > 1400.0:
		get_tree().quit(1)


func _secs(s: float) -> void:
	var end: float = _t + s
	while _t < end:
		await get_tree().process_frame


## An empty yard for the portraits: the round's dead are put down the way a shot would (the director keeps count).
func _clear() -> void:
	if _map.director == null:
		return
	for z: Variant in _map.director.active_zombies():
		if is_instance_valid(z) and (z as Zombie).is_active():
			(z as Zombie).take_damage(99999.0, &"head", &"m1911", 1, &"bullet")


func _shot(name: String) -> void:
	_clear()
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = _out.path_join("map00_%s.png" % name)
	img.save_png(ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path)
	print("[npcs_map00] ", path)


## The survivor stands `dist` m from `at` on the side `side` radians round from +Z, looking at it; the camera at their eye.
func _stand_by(at: Vector3, dist: float, side: float, look_h: float = 1.2) -> void:
	var h: Player = _map.player
	var off: Vector3 = Vector3(0, 0, dist).rotated(Vector3.UP, side)
	h.global_position = at + off + Vector3(0, 0.1, 0)
	h.velocity = Vector3.ZERO
	var d: Vector3 = at - h.global_position
	h.rotation.y = atan2(-d.x, -d.z)
	if _cam == null:
		_cam = Camera3D.new()
		_cam.fov = 60.0
		get_tree().root.add_child(_cam)
	_cam.global_position = h.global_position + Vector3(0, 1.62, 0)
	_cam.look_at(at + Vector3(0, look_h, 0), Vector3.UP)
	_cam.current = true


func _run() -> void:
	GameState.character_id = &"dutch"
	GameState.god_mode = true
	_map = (load(MAP) as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child(_map)
	get_tree().current_scene = _map
	while _map.player == null or not _map.player.is_inside_tree():
		await get_tree().process_frame
	await _secs(2.0)
	_map.player.set_process_unhandled_input(false)
	while RoundManager.current_round < 2:
		RoundManager.advance_round()
	await _secs(3.0)
	_clear()
	var trudi: MapCompanion = null
	for c: MapCompanion in MapCompanion.instances(get_tree()):
		if c.id == "trudi":
			trudi = c
	if trudi != null and trudi.player != null:
		var at: Vector3 = trudi.player.global_position
		_stand_by(at, 3.6, 0.5)
		await _secs(9.0)   # her calm idles start after a few still seconds
		await _shot("trudi_knife_a")
		await _secs(4.0)
		await _shot("trudi_knife_b")
		_stand_by(at, 4.5, -0.9)
		await _secs(3.0)
		await _shot("trudi_side")
		trudi.player.remote_body.set_weapon(&"kar98k")
		_stand_by(at, 3.6, 0.2)
		await _secs(8.0)
		await _shot("trudi_rifle")
		_stand_by(at, 1.0, 0.2, 1.4)
		await _secs(2.5)
		await _shot("trudi_close")
	for pid: String in ["courier", "deserter", "widow"]:
		var p: ExtraPerson = _map.get_node_or_null("Person_" + pid) as ExtraPerson
		if p == null or p.bodies.is_empty():
			continue
		var b: PatronBody = p.bodies[0]
		_stand_by(b.global_position, 3.2, b.rotation.y + 0.35)
		await _secs(7.0)
		await _shot(pid)
	get_tree().quit()
