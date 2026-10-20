extends Node
## Dev tool: renders the hub and the Settings screen (every tab). Silent (all buses muted), off-screen:
##   godot --position -4000,-4000 --resolution 1600x900 --path . res://tools_src/shots_menus.tscn -- --out=C:/dir
var _out: String = "user://shots"


func _process(_d: float) -> void:
	for i: int in AudioServer.bus_count:
		AudioServer.set_bus_mute(i, true)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_process(0)
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	_run.call_deferred()


func _run() -> void:
	var hub: Node = (load("res://ui/main_menu.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(hub)
	get_tree().current_scene = hub
	await _wait(0.6)
	await _shot("hub_bs")
	(hub.get("_buttons")[1] as Button).grab_focus()
	await _wait(0.5)
	await _shot("hub_gl")
	(hub.get("_buttons")[2] as Button).grab_focus()
	await _wait(0.5)
	await _shot("hub_fp_locked")
	hub.call("open_settings")
	await _wait(0.4)
	var sm: Node = hub.get("_settings")
	for t: int in 4:
		sm.call("show_tab", t)
		await _wait(0.3)
		await _shot("settings_%d" % t)
	sm.call("close")
	await _wait(0.2)
	(hub.get("_buttons")[1] as Button).grab_focus()
	hub.set("_born", -10.0)
	hub.call("_activate", 1)
	await _wait(0.25)
	await _shot("hub_stamp")
	await _wait(2.0)
	await _shot("gl_menu")
	get_tree().quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(_out.path_join("menu_%s.png" % label))
	print("[menus] ", label)
