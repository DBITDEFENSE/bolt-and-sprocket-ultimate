extends Node
## Dev tool (rendered, needs the user's OK): screenshots of the Muster screen (T-079) and of Map 0's round-1 opening
## (T-076) exactly as the dev launcher's Map 0 button starts it, with no bots, the player untouched.
## Usage (off-screen, silent, no mouse capture):
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://gravelight/tools_src/shots_muster_opening.tscn -- --out=<dir> [--muster-only]
## -> <dir>/muster_<who>.png, <dir>/opening_NN_<t>s.png. The profile is read, never written (temp path).

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const OPENING_AT: Array = [0.5, 5.0, 10.0, 15.0, 20.0, 23.0, 25.0, 27.0, 29.0, 31.0, 33.0, 35.0, 38.0, 41.0, 45.0, 50.0]

var _out: String = "user://shots"
var _muster_only: bool = false


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a == "--muster-only":
			_muster_only = true
	DirAccess.make_dir_recursive_absolute(_out if _out.is_absolute_path() else ProjectSettings.globalize_path(_out))
	ProfileSave.path = "user://_shots_muster_profile.json"   # whatever is clicked, the user's profile is never written
	GLSettings.path = "user://_shots_muster_settings.cfg"
	GLSettings.values["bot_local_ai"] = false
	_run.call_deferred()


func _process(_d: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(name + ".png"))
	print("[shots] ", name)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _run() -> void:
	get_tree().current_scene = null
	for who: String in ["dutch", "wren"]:
		var m: Control = MenuMuster.new(who)
		get_tree().root.add_child(m)
		await _wait(1.0)
		await _shot("muster_" + who)
		m.queue_free()
		await _wait(0.2)
	if _muster_only:
		get_tree().quit()
		return
	# Map 0 the way the launcher's button starts it
	var dl: Node = (load("res://ui/dev_launcher.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(dl)
	get_tree().current_scene = dl
	(dl.get("_bots") as OptionButton).select(0)
	(dl.get("_god") as CheckBox).button_pressed = true
	var ai: CheckBox = dl.get("_ai") as CheckBox
	if ai != null:
		ai.button_pressed = false
	(dl.get("_round") as SpinBox).value = 1
	dl.call("_start_gl", MAP, 1)
	var t0: float = -1.0
	var guard: float = 0.0
	while t0 < 0.0 and guard < 60.0:
		await _wait(0.1)
		guard += 0.1
		if get_tree().current_scene is MapRoot:
			t0 = Time.get_ticks_msec() / 1000.0
	if t0 < 0.0:
		print("[shots] map never appeared")
		get_tree().quit(1)
		return
	for i: int in OPENING_AT.size():
		var at: float = float(OPENING_AT[i])
		var now: float = Time.get_ticks_msec() / 1000.0 - t0
		if at > now:
			await _wait(at - now)
		await _shot("opening_%02d_%0.1fs" % [i, at])
	print("[shots] done")
	get_tree().quit()
