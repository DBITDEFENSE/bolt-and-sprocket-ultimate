extends Node
## Crash probe (owner: "campaign just crashes when I try to launch it"): starts a campaign exactly like the menu's
## Campaign button (MenuCharacter._start(scene, true)), with the owner's real settings and a COPY of the owner's
## profile, rendered. Prints a heartbeat each second so the last line before a crash shows how far it got.
## Run off-screen and silent: Godot --position -4000,-4000 --audio-driver Dummy --path . res://gravelight/tools_src/probe_campaign_start.tscn

var _t: float = 0.0
var _beat: int = 0
var _tree: SceneTree = null


func _ready() -> void:
	if name != "ProbeDriver":
		var d: Node = (load("res://gravelight/tools_src/probe_campaign_start.gd") as GDScript).new() as Node
		d.name = "ProbeDriver"
		get_tree().root.add_child.call_deferred(d)
		queue_free.call_deferred()
		set_process(false)
		return
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)   # real audio driver, silent
	print("[probe] audio driver: %s, output %s" % [AudioServer.get_driver_name() if AudioServer.has_method("get_driver_name") else "?", AudioServer.output_device])
	process_mode = Node.PROCESS_MODE_ALWAYS   # cutscenes pause the tree; keep the heartbeat going
	# the owner's settings as saved; a copy of the owner's profile so the probe never writes the real one
	var real: String = ProjectSettings.globalize_path("user://gravelight_profile.json")
	var copy: String = ProjectSettings.globalize_path("user://_probe_campaign_profile.json")
	if FileAccess.file_exists(real):
		DirAccess.copy_absolute(real, copy)
	ProfileSave.path = "user://_probe_campaign_profile.json"
	ProfileSave.load_profile()
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--set="):   # --set=gfx_gi:false (bool), --set=gfx_fog:low
			var kv: PackedStringArray = a.substr(6).split(":")
			GLSettings.values[kv[0]] = (kv[1] == "true") if kv[1] in ["true", "false"] else kv[1]
	GLSettings.activate()
	print("[probe] settings: preset=%s gi=%s ssil=%s fog=%s" % [GLSettings.values.get("graphics_preset"), GLSettings.gfx("gfx_gi"), GLSettings.gfx("gfx_ssil"), GLSettings.gfx("gfx_fog")])
	_go.call_deferred()


func _go() -> void:
	await get_tree().create_timer(1.0).timeout
	if OS.get_cmdline_user_args().has("--menu"):
		await _via_menu()
		return
	var scene: String = Campaign.scene_for(&"map00_crossroads")
	print("[probe] campaign start -> %s" % scene)
	GameState.bot_count = BotConfig.clamp_bots(BotConfig.cfg(), int(GLSettings.values.get("bots", 0)))
	GameState.bot_skill = BotConfig.skill_key(BotConfig.cfg(), str(GLSettings.values.get("bot_skill", "veteran")))
	GameState.bot_ai_mode = BotConfig.ai_mode_from_settings(GLSettings.values, GameState.bot_count)
	if OS.get_cmdline_user_args().has("--solo"):
		Campaign.reset()
		print("[probe] SOLO (no campaign, no cutscenes)")
	else:
		Campaign.begin()
	if OS.get_cmdline_user_args().has("--direct"):
		get_tree().change_scene_to_file(scene)   # skip the loading screen
	else:
		LoadingScreen.go(get_tree(), scene)


func _process(_delta: float) -> void:
	_t = Time.get_ticks_msec() / 1000.0
	if int(_t) > _beat:
		_beat = int(_t)
		var cs: Node = get_tree().current_scene
		var lc: Variant = LazarusCinema.of(cs) if cs is MapRoot else null
		var cut: String = ""
		if lc != null and (lc as LazarusCinema).reel != null:
			cut = str((lc as LazarusCinema).playing)
		print("[probe] t=%d scene=%s fps=%d paused=%s cut=%s" % [_beat, cs.name if cs != null else "-", Engine.get_frames_per_second(), get_tree().paused, cut])
		if _beat >= 200:
			print("[probe] RESULT PASS (alive at 200 s)")
			get_tree().quit(0)


## The owner's own clicks: the main menu, PLAY > CAMPAIGN, a survivor, the campaign card.
func _via_menu() -> void:
	_tree = get_tree()
	_tree.process_frame.connect(_beat_tick)
	print("[probe] menu path: loading the main menu")
	_tree.change_scene_to_file("res://gravelight/ui/main_menu.tscn")
	await _tree.create_timer(8.0).timeout
	var menu: Node = _tree.current_scene
	print("[probe] menu up: %s; opening Campaign" % (menu.name if menu != null else "-"))
	menu.call("_open_campaign")
	await _tree.create_timer(3.0).timeout
	var mc: MenuCharacter = null
	for n: Node in menu.find_children("*", "", true, false):
		if n is MenuCharacter:
			mc = n
	print("[probe] campaign screen: %s; picking wren" % str(mc))
	mc.call("_pick", "wren")
	await _tree.create_timer(3.0).timeout
	var card: Button = mc.find_child("Card_Campaign", true, false) as Button
	print("[probe] campaign card: %s; pressing it" % str(card))
	card.pressed.emit()
	print("[probe] pressed")


func _beat_tick() -> void:
	var t: int = int(Time.get_ticks_msec() / 1000)
	if t > _beat:
		_beat = t
		var cs: Node = _tree.current_scene
		print("[probe] t=%d scene=%s fps=%d" % [t, cs.name if cs != null else "-", Engine.get_frames_per_second()])
