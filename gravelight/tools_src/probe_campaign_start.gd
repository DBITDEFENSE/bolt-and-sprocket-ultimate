extends Node
## Crash probe (owner: "campaign just crashes when I try to launch it", T-216): starts a match through the menu's own
## code (MenuCharacter.prepare_match, then LoadingScreen.go), with COPIES of the owner's settings and profile, so the
## probe never writes the real files. A heartbeat each second: the last line before a crash shows how far it got.
##
## Headless (no window, no GPU):
##   Godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/probe_campaign_start.tscn [-- args]
## The exported exe ships gravelight/tools_src but refuses a scene path, so GLSettings starts the probe on a user arg:
##   ClaudeZombies.exe --headless --audio-driver Dummy -- --probe-campaign [args]
## Rendered only with the owner's OK: add --position -4000,-4000 and keep --audio-driver Dummy (CLAUDE.md). A crash in
## the audio driver needs the real driver: leave --audio-driver out only with the owner's OK (Master is muted either way).
##
## User args (after --):
##   --menu          the owner's clicks: the main menu, PLAY > CAMPAIGN, a survivor, the campaign card
##   --solo          one map, no campaign chain and no cutscenes
##   --direct        skip the loading screen
##   --char=wren     the survivor (default wren)
##   --set=key:value a setting for this run only (true/false, numbers and text as the setting's own type;
##                   graphics_preset:low applies that whole preset)
##   --seconds=200   PASS and quit when the match is still alive after this many seconds

const SETTINGS_COPY: String = "user://_probe_campaign_settings.cfg"
const PROFILE_COPY: String = "user://_probe_campaign_profile.json"

var _t0: int = 0
var _beat: int = 0
var _seconds: int = 200
var _char: String = "wren"
var _tree: SceneTree = null


func _ready() -> void:
	if name != "ProbeDriver":
		# the scene is replaced on the first change_scene; a driver under the root outlives it
		var d: Node = (load("res://gravelight/tools_src/probe_campaign_start.gd") as GDScript).new() as Node
		d.name = "ProbeDriver"
		get_tree().root.add_child.call_deferred(d)
		queue_free.call_deferred()
		return
	_tree = get_tree()
	_t0 = Time.get_ticks_msec()
	process_mode = Node.PROCESS_MODE_ALWAYS   # cutscenes pause the tree; keep the heartbeat going
	_tree.process_frame.connect(_beat_tick)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	print("[probe] audio driver: %s, output %s" % [AudioServer.get_driver_name() if AudioServer.has_method("get_driver_name") else "?", AudioServer.output_device])
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--char="):
			_char = a.substr(7)
		elif a.begins_with("--seconds=") and a.substr(10).is_valid_int():
			_seconds = maxi(5, int(a.substr(10)))
	# the owner's settings and profile, copied: whatever the run saves lands in the copies
	GLSettings.path = SETTINGS_COPY
	print("[probe] settings: %s" % _use_copy(GLSettings.PATH, SETTINGS_COPY))
	GLSettings.load_settings()
	ProfileSave.path = PROFILE_COPY
	print("[probe] profile: %s" % _use_copy(ProfileSave.PATH, PROFILE_COPY))
	ProfileSave.load_profile()
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--set="):
			print("[probe] %s" % apply_set(GLSettings.values, a.substr(6)))
	GLSettings.activate()
	print("[probe] settings in use: preset=%s gi=%s ssil=%s fog=%s bots=%s bot_ai=%s/%s" % [GLSettings.values.get("graphics_preset"),
		GLSettings.gfx("gfx_gi"), GLSettings.gfx("gfx_ssil"), GLSettings.gfx("gfx_fog"), GLSettings.values.get("bots"),
		GLSettings.values.get("bot_local_ai"), GLSettings.values.get("bot_ai_brain", "-")])
	_go.call_deferred()


## Copies `real` over `copy` (a stale copy from an earlier run is removed first). Says what happened.
static func _use_copy(real: String, copy: String) -> String:
	var copy_abs: String = ProjectSettings.globalize_path(copy)
	if FileAccess.file_exists(copy):
		DirAccess.remove_absolute(copy_abs)
	if not FileAccess.file_exists(real):
		return "no saved file at %s: the defaults" % real
	var err: int = DirAccess.copy_absolute(ProjectSettings.globalize_path(real), copy_abs)
	if err != OK:
		return "COPY FAILED (error %d) from %s: the defaults" % [err, real]
	return "a copy of %s" % real


## One --set=key:value onto `vals` (pure, unit-tested). The value takes the type the setting already has;
## graphics_preset goes through GLSettings.set_preset so every gfx_* key follows. Returns a line for the log.
static func apply_set(vals: Dictionary, kv: String) -> String:
	var i: int = kv.find(":")
	if i <= 0:
		return "ignored --set=%s (write --set=key:value)" % kv
	var key: String = kv.left(i)
	var raw: String = kv.substr(i + 1)
	if not vals.has(key):
		return "ignored --set=%s (no setting called %s)" % [kv, key]
	if key == "graphics_preset":
		if not GLSettings.PRESETS.has(raw):
			return "ignored --set=%s (presets: %s)" % [kv, ", ".join(PackedStringArray(GLSettings.PRESETS.keys()))]
		GLSettings.set_preset(raw)
		return "set graphics_preset=%s (the whole preset)" % raw
	var v: Variant = coerce(raw, vals[key])
	if v == null:
		return "ignored --set=%s (%s wants a %s)" % [kv, key, type_string(typeof(vals[key]))]
	vals[key] = v
	return "set %s=%s" % [key, str(v)]


## `raw` as the type of `like` (bool, int, float or text), or null when it doesn't parse (pure).
static func coerce(raw: String, like: Variant) -> Variant:
	match typeof(like):
		TYPE_BOOL:
			if raw in ["true", "false", "on", "off", "1", "0"]:
				return raw in ["true", "on", "1"]
			return null
		TYPE_INT:
			return int(raw) if raw.is_valid_int() else null
		TYPE_FLOAT:
			return float(raw) if raw.is_valid_float() else null
	return raw


func _go() -> void:
	await _tree.create_timer(1.0).timeout
	if OS.get_cmdline_user_args().has("--menu"):
		await _via_menu()
		return
	var campaign: bool = not OS.get_cmdline_user_args().has("--solo")
	var scene: String = Campaign.scene_for(Campaign.first_map())   # what the Campaign card starts
	GameState.character_id = StringName(_char)                     # what picking a survivor sets
	MenuCharacter.prepare_match(campaign)
	print("[probe] %s start -> %s as %s" % ["campaign" if campaign else "SOLO (no campaign, no cutscenes)", scene, _char])
	if OS.get_cmdline_user_args().has("--direct"):
		_tree.change_scene_to_file(scene)   # skip the loading screen
	else:
		LoadingScreen.go(_tree, scene)


## The owner's own clicks: the main menu, PLAY > CAMPAIGN, a survivor, the campaign card.
func _via_menu() -> void:
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
	print("[probe] campaign screen: %s; picking %s" % [str(mc), _char])
	mc.call("_pick", _char)
	await _tree.create_timer(3.0).timeout
	var card: Button = mc.find_child("Card_Campaign", true, false) as Button
	print("[probe] campaign card: %s; pressing it" % str(card))
	card.pressed.emit()
	print("[probe] pressed")


## One heartbeat a second in every mode; PASS and quit once the match has been up for `--seconds`.
func _beat_tick() -> void:
	var t: int = (Time.get_ticks_msec() - _t0) / 1000
	if t <= _beat:
		return
	_beat = t
	var cs: Node = _tree.current_scene
	var cut: String = ""
	if cs is MapRoot:
		var lc: LazarusCinema = LazarusCinema.of(cs) as LazarusCinema
		if lc != null and lc.reel != null:
			cut = str(lc.playing)
	print("[probe] t=%d scene=%s fps=%d paused=%s cut=%s" % [t, cs.name if cs != null else "-", Engine.get_frames_per_second(), _tree.paused, cut])
	if t >= _seconds and cs is MapRoot:
		print("[probe] RESULT PASS (alive at %d s)" % t)
		_tree.quit(0)
	elif t >= _seconds + 120:
		print("[probe] RESULT FAIL (no map after %d s)" % t)
		_tree.quit(1)
