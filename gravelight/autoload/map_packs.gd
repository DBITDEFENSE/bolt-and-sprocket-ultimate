extends Node
## UPDATE 09 section 2c (DECISIONS T-139, contract C4): map packs for the browser build. tools/build_web.sh leaves
## each map's own scene and files (and the match-only "game" pack: VO, the material / prop libraries, the guns'
## textures, in chunks "game1".."gameN") out of the main .pck and writes packs/<name>-<hash>.pck plus packs/manifest.json, which says which packs
## a map needs ({"maps": {map_id: ["game1", "game2", "map04", "map04a"]}, "packs": {name: {file, bytes}}}).
## `await MapPacks.ensure(map_id_or_scene)` before changing to a map: on the desktop (and in a single-pack web
## export) the scene is already loadable and it returns true at once, without waiting a frame; on the web it fetches
## the missing packs over HTTP (a progress overlay, `progress` signal) and mounts them with
## ProjectSettings.load_resource_pack. The "game" pack starts downloading in the background as soon as the menu is up.
## `--packs-from=<dir>` (a user arg) mounts packs from a local folder instead: the desktop test of a web build
## (tools/serve_web.sh prints how), with the same manifest.

signal progress(pack: String, fraction: float, bytes: int, total: int)
signal pack_ready(pack: String, ok: bool)

const MANIFEST: String = "packs/manifest.json"
## map id -> scene path, for callers that hold a scene (the map select, Net, Campaign.travel)
const SCENE_MAP: Dictionary = {
	"res://gravelight/maps/map00_crossroads/map00.tscn": "map00_crossroads",
	"res://gravelight/maps/map01_kaltenbrunn/map01.tscn": "map01_kaltenbrunn",
	"res://gravelight/maps/map02_totenhafen/map02.tscn": "map02_totenhafen",
	"res://gravelight/maps/map04_fernflug/map04a.tscn": "map04a_thalbach",
	"res://gravelight/maps/map04_fernflug/map04b.tscn": "map04b_kranich",
	"res://gravelight/maps/map04_fernflug/map04c.tscn": "map04c_groomlake",
	"res://gravelight/maps/map04_fernflug/map04d.tscn": "map04d_mondlicht",
}

var manifest: Dictionary = {}
var mounted: Dictionary = {}     # pack -> true
var _busy: Dictionary = {}       # pack -> true while it downloads
var _local_dir: String = ""
var _overlay: CanvasLayer
var _label: Label
var _bar: ProgressBar


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--packs-from="):
			_local_dir = a.substr(13)
	if "--packs-selftest" in OS.get_cmdline_user_args():
		_selftest.call_deferred()
	elif _split_build():
		_start_background.call_deferred()


## `--packs-selftest` (with --main-pack <web main pck> and --packs-from=<dir>): mounts each map's packs, loads and
## instantiates its scene (not added to the tree), prints one line per map and quits with the number of failures.
func _selftest() -> void:
	var fails: int = 0
	print("[packs-selftest] split build %s, map00 loadable before: %s" % [str(_split_build()), str(ResourceLoader.exists(scene_of("map00_crossroads")))])
	for s: String in SCENE_MAP:
		var t0: int = Time.get_ticks_msec()
		var ok: bool = await ensure(s)
		var ps: PackedScene = load(s) as PackedScene if ok else null
		var n: int = 0
		if ps != null:
			var inst: Node = ps.instantiate()
			if inst != null:
				n = inst.find_children("*", "", true, false).size()
				inst.free()
		var good: bool = ps != null and n > 0
		fails += 0 if good else 1
		print("[packs-selftest] %s %s: %d nodes, packs %s, %d ms" % ["OK  " if good else "FAIL", SCENE_MAP[s], n, str(mounted.keys()), Time.get_ticks_msec() - t0])
	print("[packs-selftest] RESULT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(fails)


## True when this build's maps live in packs (the web build from tools/build_web.sh, or --packs-from).
func _split_build() -> bool:
	return _local_dir != "" or (GLSettings.is_web() and not ResourceLoader.exists("res://gravelight/maps/map00_crossroads/map00.tscn"))


## True when the map is not loadable yet but this build has it in a pack (Campaign.scene_exists asks).
func knows(map_id: StringName) -> bool:
	return _split_build() and SCENE_MAP.values().has(String(map_id))


## The map id a scene path or map id stands for.
static func map_id_of(map_or_scene: String) -> String:
	if map_or_scene.begins_with("res://"):
		return str(SCENE_MAP.get(map_or_scene, ""))
	return map_or_scene


static func scene_of(map_or_scene: String) -> String:
	if map_or_scene.begins_with("res://"):
		return map_or_scene
	for s: String in SCENE_MAP:
		if SCENE_MAP[s] == map_or_scene:
			return s
	return Campaign.scene_for(StringName(map_or_scene))


## Makes the map loadable. Desktop / single-pack build: true at once. Split web build: fetches and mounts what the
## manifest says the map needs; false (and a message on the overlay) when that fails.
func ensure(map_or_scene: String) -> bool:
	var scene: String = scene_of(map_or_scene)
	if not _split_build():
		return ResourceLoader.exists(scene) or scene == ""
	if not await _load_manifest():
		return ResourceLoader.exists(scene)
	var need: Array = (manifest.get("maps", {}) as Dictionary).get(map_id_of(map_or_scene), [])
	for pack: Variant in need:
		if not await _mount(str(pack), true):
			_show("Couldn't load %s. Check the connection and try again." % str(pack), -1.0)
			await get_tree().create_timer(2.5).timeout
			_hide()
			return false
	_hide()
	return ResourceLoader.exists(scene)


## The "game1".."gameN" packs in the background, one after the other (the menu stays usable; ensure() waits for
## them if a match starts first).
func _start_background() -> void:
	if not await _load_manifest():
		return
	var names: Array = (manifest.get("packs", {}) as Dictionary).keys().filter(func(k: Variant) -> bool: return str(k).begins_with("game"))
	names.sort()
	for pack: Variant in names:
		await _mount(str(pack), false)


func _load_manifest() -> bool:
	if not manifest.is_empty():
		return true
	var text: String = ""
	if _local_dir != "":
		text = FileAccess.get_file_as_string(_local_dir.path_join(MANIFEST.get_file()))
		if text == "":
			text = FileAccess.get_file_as_string(_local_dir.path_join(MANIFEST))
	else:
		var r: Array = await _http_get(_base_url() + MANIFEST, "")
		if int(r[0]) == OK:
			text = (r[1] as PackedByteArray).get_string_from_utf8()
	var v: Variant = JSON.parse_string(text) if text != "" else null
	if not (v is Dictionary):
		push_warning("MapPacks: no manifest (%s)" % (_local_dir if _local_dir != "" else _base_url() + MANIFEST))
		return false
	manifest = v
	return true


func _mount(pack: String, visible: bool) -> bool:
	if mounted.has(pack):
		return true
	while _busy.has(pack):   # already downloading (the background fetch): wait for it, showing its progress
		if visible:
			_show_progress_of(pack)
		await pack_ready
	if mounted.has(pack):
		return true
	var entry: Dictionary = (manifest.get("packs", {}) as Dictionary).get(pack, {})
	if entry.is_empty():
		return false
	_busy[pack] = true
	var path: String = ""
	if _local_dir != "":
		path = _local_dir.path_join(str(entry["file"]))
		if not FileAccess.file_exists(path):
			path = _local_dir.path_join("packs").path_join(str(entry["file"]))
	else:
		path = "/tmp/cz_packs/" + str(entry["file"])   # the browser's in-memory file system (not persisted)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var r: Array = await _http_get(_base_url() + "packs/" + str(entry["file"]), path, pack, int(entry.get("bytes", 0)), visible)
		if int(r[0]) != OK:
			_busy.erase(pack)
			pack_ready.emit(pack, false)
			return false
	var ok: bool = ProjectSettings.load_resource_pack(path, true)
	_busy.erase(pack)
	if ok:
		mounted[pack] = true
	else:
		push_warning("MapPacks: couldn't mount " + path)
	pack_ready.emit(pack, ok)
	return ok


## [error, body bytes]. With `to_file` the body streams into that file instead.
func _http_get(url: String, to_file: String, pack: String = "", total: int = 0, visible: bool = false) -> Array:
	var req: HTTPRequest = HTTPRequest.new()
	req.use_threads = false
	req.download_chunk_size = 1 << 20
	if to_file != "":
		req.download_file = to_file
	add_child(req)
	if req.request(url) != OK:
		req.queue_free()
		return [FAILED, PackedByteArray()]
	var done: Array = []
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		done.append([OK if result == HTTPRequest.RESULT_SUCCESS and code == 200 else FAILED, body]))
	while done.is_empty():
		await get_tree().process_frame
		if pack != "":
			var got: int = req.get_downloaded_bytes()
			var all: int = maxi(total, req.get_body_size())
			progress.emit(pack, float(got) / float(maxi(1, all)), got, all)
			if visible:
				_show("Loading %s… %d / %d MB" % [_pack_title(pack), got >> 20, all >> 20], float(got) / float(maxi(1, all)))
	req.queue_free()
	return done[0]


func _base_url() -> String:
	if not GLSettings.is_web():
		return ""
	var href: String = str(JavaScriptBridge.eval("window.location.href", true))
	href = href.get_slice("#", 0).get_slice("?", 0)
	return href.substr(0, href.rfind("/") + 1)


func _pack_title(pack: String) -> String:
	if pack.begins_with("game"):
		return "the game's sounds and textures (%s)" % pack.trim_prefix("game")
	for s: String in SCENE_MAP:
		var mid: String = str(SCENE_MAP[s])
		if mid.begins_with(pack):
			return Campaign.display_name(StringName(mid))
	return pack


func _show_progress_of(pack: String) -> void:
	_show("Loading %s…" % _pack_title(pack), -1.0)


func _show(text: String, fraction: float) -> void:
	if _overlay == null:
		_overlay = CanvasLayer.new()
		_overlay.layer = 125
		var bg: ColorRect = ColorRect.new()
		bg.color = Color(0.03, 0.027, 0.047, 0.92)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		_overlay.add_child(bg)
		var box: VBoxContainer = VBoxContainer.new()
		box.set_anchors_preset(Control.PRESET_CENTER)
		box.custom_minimum_size = Vector2(560, 80)
		box.position = Vector2(-280, -40)
		_overlay.add_child(box)
		_label = Label.new()
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.add_theme_font_size_override("font_size", 22)
		box.add_child(_label)
		_bar = ProgressBar.new()
		_bar.custom_minimum_size = Vector2(560, 10)
		_bar.show_percentage = false
		var fill: StyleBoxFlat = StyleBoxFlat.new()
		fill.bg_color = Color(0.56, 0.36, 1.0)
		_bar.add_theme_stylebox_override("fill", fill)
		box.add_child(_bar)
		add_child(_overlay)
	_overlay.visible = true
	_label.text = text
	_bar.visible = fraction >= 0.0
	_bar.value = clampf(fraction, 0.0, 1.0) * 100.0


func _hide() -> void:
	if _overlay != null:
		_overlay.visible = false
