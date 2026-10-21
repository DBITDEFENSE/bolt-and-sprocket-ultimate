extends Node
## Dev tool: a close-up and a room-context view of every Map 0 fixed story item (LORE.md section 13.1) from a
## free camera, power on so the cellar is lit. No Player input, the mouse is never captured, the buses are muted.
## Silent, off-screen:
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://gravelight/tools_src/shots_story_props.tscn -- --out=<dir>
## -> <dir>/story_NN_<id>_<close|room>.png
var _out: String = "user://shots"
var map: Node3D
var cam: Camera3D
var _n: int = 0


func _process(_d: float) -> void:
	for i: int in AudioServer.bus_count:
		AudioServer.set_bus_mute(i, true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out if _out.is_absolute_path() else ProjectSettings.globalize_path(_out))
	ProfileSave.path = "user://_shots_story_profile.json"
	map = (load("res://gravelight/maps/map00_crossroads/map00.tscn") as PackedScene).instantiate() as Node3D
	map.set("auto_rounds", false)
	get_tree().root.add_child.call_deferred(map)
	_run.call_deferred()


func _run() -> void:
	await get_tree().create_timer(1.5).timeout
	var p: Player = map.get("player") as Player
	if p != null:
		p.process_mode = Node.PROCESS_MODE_DISABLED
		p.visible = false
	cam = Camera3D.new()
	cam.fov = 60
	map.add_child(cam)
	cam.make_current()
	for d: Node in get_tree().get_nodes_in_group(&"doors"):
		(d as BuyDoor).open(1)
	var sw: Node = get_tree().get_first_node_in_group(&"power_switch")
	if sw != null:
		sw.call("run_sequence", 1)
	await get_tree().create_timer(4.0).timeout
	var props: Array[Node] = get_tree().get_nodes_in_group(&"story_props")
	props.sort_custom(func(a: Node, b: Node) -> bool: return a.name < b.name)
	for n: Node in props:
		var sp: StoryProp = n as StoryProp
		var o: Vector3 = sp.global_position
		var front: Vector3 = -sp.global_basis.z
		if StoryProp.is_wall_style(sp.style):
			await _shot("%s_close" % sp.intel_id, o + front * 0.8 + Vector3(0, 0.05, 0), o)
			await _shot("%s_room" % sp.intel_id, o + front * 2.6 + Vector3(0, 0.3, 0) + front.cross(Vector3.UP) * 0.8, o)
		else:
			await _shot("%s_close" % sp.intel_id, o + front * 0.55 + Vector3(0, 0.5, 0), o)
			await _shot("%s_room" % sp.intel_id, o + front * 2.2 + Vector3(0, 1.1, 0) + front.cross(Vector3.UP) * 0.6, o)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shots_story_profile.json"))
	get_tree().quit()


func _shot(label: String, at: Vector3, look: Vector3) -> void:
	cam.global_position = at
	cam.look_at(look)
	await get_tree().create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join("story_%02d_%s.png" % [_n, label]))
	_n += 1
	print("[story] shot ", label)
