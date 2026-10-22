extends Node
## Dev tool (T-057): Map 0's lamps with the lights on, then guttered as in the Cousins round, from a few views.
## `--before` freezes LampGlow first, which is how the map looked before the fix (the glass kept glowing in the
## dark). Silent (buses muted), off-screen:
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://tools_src/shots_lamps_out.tscn -- --out=<dir> [--before]
## -> <dir>/<view>_<lit|out>_<before|after>.png
var _out: String = "user://shots"
var _before: bool = false
var map: Node3D
var cam: Camera3D

const VIEWS: Array = [
	["taproom", Vector3(15.0, 1.65, 9.5), Vector3(8.0, 2.2, 10.5)],
	["bar_lamp", Vector3(9.0, 1.7, 6.5), Vector3(4.8, 2.3, 4.6)],
	["stairs", Vector3(5.0, 1.65, 15.2), Vector3(1.5, 3.2, 10.0)],
	["upstairs_hall", Vector3(2.0, 5.45, 8.2), Vector3(22.0, 5.2, 8.0)],
	["stable", Vector3(20.5, 1.65, 23.2), Vector3(14.0, 2.6, 29.0)],
]


func _process(_d: float) -> void:
	for i: int in AudioServer.bus_count:
		AudioServer.set_bus_mute(i, true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a == "--before":
			_before = true
	DirAccess.make_dir_recursive_absolute(_out)
	ProfileSave.path = "user://_shots_lamps_profile.json"
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
	for d: Node in get_tree().get_nodes_in_group(&"doors"):
		if d is BuyDoor:
			(d as BuyDoor).open(1)
	var glow: Node = map.get_node_or_null("LampGlow")
	if _before and glow != null:
		glow.process_mode = Node.PROCESS_MODE_DISABLED
	cam = Camera3D.new()
	cam.fov = 75
	map.add_child(cam)
	cam.make_current()
	await get_tree().create_timer(2.0).timeout
	for n: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if String(n.name) != "PostFx":
			(n as CanvasLayer).visible = false
	var tag: String = "before" if _before else "after"
	for v: Array in VIEWS:
		await _shot("%s_lit_%s" % [v[0], tag], v[1], v[2])
	# gutter every Cousins lamp (data/gravelight/bosses/cousins.json setup.lamp_groups) as the round does
	var cfg: Dictionary = GLData.load_json("res://data/gravelight/bosses/cousins.json")
	for g: Variant in (cfg["setup"]["lamp_groups"] as Dictionary).values():
		for lname: Variant in g as Array:
			var l: Light3D = map.find_child(str(lname), true, false) as Light3D
			if l != null:
				l.set("base_energy" if l.get("base_energy") != null else "light_energy", 0.0)
	var fire: Light3D = map.find_child(str(cfg["setup"]["fire"]), true, false) as Light3D
	if fire != null:
		fire.set("base_energy", float(cfg["setup"]["fire_ember_energy"]))
	await get_tree().create_timer(1.0).timeout
	for v: Array in VIEWS:
		await _shot("%s_out_%s" % [v[0], tag], v[1], v[2])
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shots_lamps_profile.json"))
	get_tree().quit()


func _shot(label: String, at: Vector3, look: Vector3) -> void:
	cam.global_position = at
	cam.look_at(look)
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join("%s.png" % label))
	print("[lamps] shot ", label)
