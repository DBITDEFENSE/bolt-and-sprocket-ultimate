extends Node
## Screenshots of the in-match pause menu (T-040): the page itself, the Settings screen inside it (every tab)
## and the quit confirmation. Rendered off-screen, every audio bus muted, the mouse never captured.
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1600x900 --path . res://gravelight/tools_src/shots_pause.tscn -- --out=C:/dir
## Writes pause_00_menu.png, pause_01_settings_<tab>.png ..., pause_06_confirm.png to --out.

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"

var _out: String = "user://shots"
var _map: Node3D
var _n: int = 0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	for i: int in AudioServer.bus_count:
		AudioServer.set_bus_mute(i, true)
	DirAccess.make_dir_recursive_absolute(_out)
	ProfileSave.path = "user://_shots_pause_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _shot(label: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(_out.path_join("pause_%02d_%s.png" % [_n, label]))
	print("[shots] %02d %s" % [_n, label])
	_n += 1


func _run() -> void:
	await _frames(90)
	var pm: PauseMenu = _map.get("pause_menu") as PauseMenu
	if pm == null:
		print("[shots] no pause menu")
		get_tree().quit(1)
		return
	pm.toggle()
	await _frames(10)
	await _shot("menu")
	pm.call("_open_settings")
	await _frames(10)
	var screen: MenuSettings = pm.get("_settings") as MenuSettings
	for t: int in MenuSettings.TABS.size():
		screen.call("_set_tab", t)
		await _frames(6)
		await _shot("settings_" + MenuSettings.TABS[t].to_lower())
	screen.close()
	await _frames(6)
	pm.call("_confirm_then", "Quit to the menu? The match is lost.", func() -> void: pass)
	await _frames(6)
	await _shot("confirm")
	print("[shots] done -> ", _out)
	get_tree().paused = false
	get_tree().quit()
