extends Node
## Headless smoke for the new main menu (UPDATE 09 section 7, DECISIONS T-144): the CLAUDE ZOMBIES menu over its live
## MenuScene runs for RUN_S seconds with the dummy renderer. Checks: the scene builds (zombies, squad), the walkers
## loop round the lane, the camera drifts, and every column and screen opens and closes by simulated input only
## (ui_down / ui_up / ui_accept / ui_cancel events, the keyboard's and the pad's actions): PLAY > SOLO / ONLINE /
## CAMPAIGN, MUSTER, ARCHIVE, EXTRAS > DOSSIERS / SERVICE RECORD / CHALLENGES / CREDITS, SETTINGS, QUIT's column.
## Prints one RESULT line.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_menus.tscn

const RUN_S: float = 20.0
const MENU: String = "res://gravelight/ui/main_menu.tscn"

var _fails: PackedStringArray = []
var _menu: Control
var _done: bool = false
var _t0: int = 0
var _opened: PackedStringArray = []


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile_smoke_menus.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_smoke_menus_settings.cfg"
	Lobbies.use_mock(0)   # ONLINE opens on the in-process mock table: nothing leaves the machine
	get_tree().create_timer(240.0).timeout.connect(func() -> void:
		_fails.append("timeout")
		_finish())
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	print("[menus] %-72s %s" % [what, "PASS" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _press(action: StringName) -> void:
	var e: InputEventAction = InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(2)
	var r: InputEventAction = InputEventAction.new()
	r.action = action
	r.pressed = false
	Input.parse_input_event(r)
	await _frames(3)


func _focused() -> String:
	var f: Control = get_viewport().gui_get_focus_owner()
	return (f as Button).text if f is Button else (str(f.name) if f != null else "")


## Moves the focus down the column to `label` (wrapping), by ui_down presses only.
func _focus(label: String) -> bool:
	for i: int in 10:
		if _focused() == label.to_upper():
			return true
		await _press(&"ui_down")
	return _focused() == label.to_upper()


func _screen() -> MenuScreen:
	var s: Variant = _menu.get("_screen")
	return s as MenuScreen if s != null and is_instance_valid(s) else null


## From the current column: focus `label`, accept, expect a screen of `kind`, then ui_cancel closes it.
func _open_close(label: String, kind: GDScript) -> void:
	var ok: bool = await _focus(label)
	_check(ok, "focus reaches %s by ui_down" % label)
	await _press(&"ui_accept")
	await _frames(4)
	var s: MenuScreen = _screen()
	_check(s != null and s.get_script() == kind, "%s opens its screen" % label)
	if s != null:
		_opened.append(label)
		await _secs(0.4)
		await _press(&"ui_cancel")
		await _secs(0.4)
		_check(_screen() == null, "%s closes on ui_cancel" % label)


func _run() -> void:
	_t0 = Time.get_ticks_msec()
	_menu = (load(MENU) as PackedScene).instantiate() as Control
	get_tree().root.add_child(_menu)
	get_tree().current_scene = _menu
	await _secs(0.6)
	var sc: MenuScene = _menu.get("scene") as MenuScene
	_check(sc != null and sc.walkers.size() >= 3, "the menu scene's zombies walk (%d)" % (sc.walkers.size() if sc != null else 0))
	_check(sc != null and sc.squad.size() == 4, "the squad by the fire (%d)" % (sc.squad.size() if sc != null else 0))
	_check(sc != null and sc.load_ms > 0, "the scene posed its zombies (%d ms)" % (sc.load_ms if sc != null else -1))
	var cam0: Vector3 = sc.camera.global_position if sc != null else Vector3.ZERO
	_check(_focused() == "PLAY", "PLAY has the focus at start (%s)" % _focused())
	# PLAY > SOLO / ONLINE / CAMPAIGN
	await _press(&"ui_accept")
	await _secs(0.3)
	_check(str(_menu.get("column")) == "play", "ui_accept on PLAY opens its column")
	await _open_close("Solo", MenuCharacter)
	await _open_close("Online", MenuLobby)
	await _open_close("Campaign", MenuCharacter)
	await _press(&"ui_cancel")
	await _secs(0.3)
	_check(str(_menu.get("column")) == "main", "ui_cancel goes back to the main column")
	await _open_close("Muster", MenuMuster)
	await _open_close("Archive", MenuArchive)
	await _open_close("Settings", MenuSettings)
	# EXTRAS > DOSSIERS / SERVICE RECORD / CHALLENGES / CREDITS (TEST RANGE leaves the menu: not pressed)
	var ok: bool = await _focus("Extras")
	_check(ok, "focus reaches EXTRAS")
	await _press(&"ui_accept")
	await _secs(0.3)
	_check(str(_menu.get("column")) == "extras", "EXTRAS opens its column")
	await _open_close("Dossiers", MenuDossiers)
	await _open_close("Service Record", MenuStats)
	await _open_close("Challenges", MenuChallenges)
	await _open_close("Credits", MenuCredits)
	await _press(&"ui_cancel")
	await _secs(0.3)
	# Esc on the main column offers the way out; Esc again comes back
	await _press(&"ui_cancel")
	await _secs(0.3)
	_check(str(_menu.get("column")) == "quit", "Esc on the main column opens QUIT's column")
	await _press(&"ui_cancel")
	await _secs(0.3)
	_check(str(_menu.get("column")) == "main", "and Esc comes back")
	# the rest of the RUN_S seconds: the scene keeps living
	while float(Time.get_ticks_msec() - _t0) / 1000.0 < RUN_S:
		await _frames(10)
	if sc != null:
		_check(sc.loops > 0, "the walkers looped round the lane (%d loops)" % sc.loops)
		_check(sc.camera.global_position.distance_to(cam0) > 0.2, "the camera drifted (%.2f m)" % sc.camera.global_position.distance_to(cam0))
		_check(sc.shadowed_lights() <= MenuScene.SHADOWED_MAX_DESKTOP, "the light budget (%d shadowed)" % sc.shadowed_lights())
	_check(_opened.size() == 10, "every screen opened and closed (%d: %s)" % [_opened.size(), ", ".join(_opened)])
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	var secs: float = float(Time.get_ticks_msec() - _t0) / 1000.0
	print("[menus] RESULT: %s (%.0f s, %d screens)" % ["PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)], secs, _opened.size()))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit(0 if _fails.is_empty() else 1)
