extends Node
## Screenshots of the tabbed pause menu and its OBJECTIVES tab (Update 04 section 4, T-066). Off-screen and silent,
## every audio bus muted, the mouse never captured; its own throwaway profiles.
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://gravelight/tools_src/shots_objectives.tscn -- --out=C:/dir --map=map00|map01|bs
## map00: the Inn mid radio quest (notes found, one frequency locked): every tab, then OBJECTIVES at Hidden /
## Hints / Full Guide. map01: Kaltenbrunn mid-egg (power, vault, two radios heard, a cylinder found): OBJECTIVES at
## the three levels and a Full Guide entry shown on the MAP tab. bs: Scrapheap Junction with a side quest running
## and a gold bolt found: the holo OBJECTIVES at Hints and Full Guide.

const MAPS: Dictionary = {"map00": "res://gravelight/maps/map00_crossroads/map00.tscn", "map01": "res://gravelight/maps/map01_kaltenbrunn/map01.tscn"}
const BS_LEVEL: String = "res://bs/planets/scrapheap/scrapheap.tscn"

var _out: String = "user://shots"
var _which: String = "map00"
var _map: Node = null
var _spoiler_saved: String = "hints"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--map="):
			_which = a.substr(6)
	for i: int in AudioServer.bus_count:
		AudioServer.set_bus_mute(i, true)
	DirAccess.make_dir_recursive_absolute(_out)
	ProfileSave.path = "user://_shots_objectives_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	_spoiler_saved = str(GLSettings.values.get("objective_spoilers", "hints"))
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _shot(label: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(_out.path_join("%s_%s.png" % [_which, label]))
	print("[shots] ", _which, " ", label)


func _spoiler(lv: String) -> void:
	GLSettings.values["objective_spoilers"] = lv   # no save: the user's settings file stays as it was


func _run() -> void:
	if _which == "bs":
		await _run_bs()
	else:
		await _run_gl()
	GLSettings.values["objective_spoilers"] = _spoiler_saved
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	print("[shots] done -> ", _out)
	get_tree().paused = false
	get_tree().quit()


func _run_gl() -> void:
	_map = (load(MAPS[_which]) as PackedScene).instantiate()
	get_tree().root.add_child(_map)
	get_tree().current_scene = _map
	await _frames(90)
	RoundManager.stop()
	if _which == "map00":
		for n: String in ["note_a", "note_b", "note_c"]:
			QuestManager.collect(&"radio_note", StringName(n))
		QuestManager.submit(&"radio_m0", "3.120")
		GameState.open_zone(&"CELLAR")
		Economy.grant(1, 2350)
	else:
		GameState.open_zone(&"E_LIFT")
		GameState.open_zone(&"F_CHAPEL")
		GameState.open_zone(&"G_GENERATOR")
		GameState.power_on = true
		GameState.set_flag(&"power_on", true)
		GameState.set_flag(&"pylons_attuned", 3)
		GameState.set_flag(&"core_vault_open", true)
		await _frames(5)
		QuestManager.collect(&"quest_radio", &"fragment_1")
		QuestManager.collect(&"quest_radio", &"fragment_2")
		QuestManager.collect(&"cylinder", &"cylinder_1")
	await _frames(10)
	var pm: PauseMenu = _map.get("pause_menu") as PauseMenu
	pm.toggle()
	await _frames(12)
	if _which == "map00":
		for t: int in PauseMenu.TABS.size():
			if t == PauseMenu.TAB_OBJECTIVES:
				continue
			pm.set_tab(t)
			await _frames(8)
			await _shot("tab_%d_%s" % [t, PauseMenu.TABS[t].to_lower()])
	for lv: String in ObjectiveLog.LEVELS:
		_spoiler(lv)
		pm.set_tab(PauseMenu.TAB_OBJECTIVES)
		await _frames(10)
		_select_current_step(pm.get("_objectives") as ObjectivesView, pm.build_objectives())
		await _frames(4)
		await _shot("objectives_%s" % lv)
	if _which == "map01":
		_spoiler("full")
		pm.set_tab(PauseMenu.TAB_OBJECTIVES)
		await _frames(6)
		var log: Dictionary = pm.build_objectives()
		for e: Variant in log["sections"][0]["entries"]:
			if bool((e as Dictionary).get("locatable", false)):
				pm.locate_entry(e, true)
				break
		await _frames(8)
		await _shot("map_marked")
	pm.toggle()


## The detail pane on the first running easter-egg step (else the first running side-quest step).
func _select_current_step(view: ObjectivesView, log: Dictionary) -> void:
	if view == null:
		return
	for sec: Variant in log["sections"]:
		for e: Variant in (sec as Dictionary)["entries"]:
			if str(e["kind"]) == "step" and str(e["status"]) == "current" and view.select_id(str(e["id"])):
				return


func _run_bs() -> void:
	SaveProfile.path = "user://_shots_objectives_bs.json"
	SaveProfile.doc = SaveProfile.blank()
	BS.load_from_profile()
	BS.flags.clear()
	BSLevel.pending_cutscene = ""
	_map = (load(BS_LEVEL) as PackedScene).instantiate()
	_map.set("play_arrival", false)
	get_tree().root.add_child(_map)
	await _frames(40)
	var qb: QuestBook = QuestBook.current
	if qb != null and not qb.defs.is_empty():
		var ids: Array = qb.defs.keys()
		qb.start(str(ids[0]))
		qb.add_progress(str(ids[0]), 2)
	var D: Dictionary = Data.table("bs/levels/scrapheap")
	if not (D.get("gold_bolts", []) as Array).is_empty():
		BS.set_flag("gold." + str(D["gold_bolts"][0]["id"]))
	var pm: BSPauseMenu = _map.get("pause_menu") as BSPauseMenu
	pm.open()
	await _frames(6)
	for lv: String in ["hints", "full"]:
		_spoiler(lv)
		pm.close_objectives()
		pm.open_objectives()
		await _frames(10)
		var view: ObjectivesView = pm.get("_obj_view") as ObjectivesView
		if view != null:
			view.select_id("side/" + str(QuestBook.current.defs.keys()[0]) if QuestBook.current != null and not QuestBook.current.defs.is_empty() else "")
		await _frames(4)
		await _shot("objectives_%s" % lv)
	pm.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveProfile.path))
