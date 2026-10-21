extends Node
## Dev tool: screenshot any scene. Silent (every bus muted) and off-screen; never captures the mouse.
##   godot --position -4000,-4000 --resolution 1600x900 --path . res://tools_src/shot_scene.tscn -- --scene=res://x.tscn --out=C:/dir/name.png [--wait=1.5] [--flags=cleared.scrapheap,core.x]
var _scene: String = ""
var _out: String = "user://shot.png"
var _wait: float = 1.5


func _process(_d: float) -> void:
	for i: int in AudioServer.bus_count:
		AudioServer.set_bus_mute(i, true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_process(0)
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			_scene = a.substr(8)
		elif a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--wait="):
			_wait = float(a.substr(7))
		elif a.begins_with("--flags="):
			for f: String in a.substr(8).split(",", false):
				BS.set_flag(f)
	_run.call_deferred()


func _run() -> void:
	var n: Node = (load(_scene) as PackedScene).instantiate()
	get_tree().root.add_child(n)
	get_tree().current_scene = n
	await get_tree().create_timer(_wait).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out)
	print("[shot] wrote ", _out)
	get_tree().quit()
