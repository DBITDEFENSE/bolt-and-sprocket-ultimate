extends SceneTree
## UPDATE 09 section 2c (DECISIONS T-139): which files leave the browser build's main pack for a map pack.
##   godot --headless --audio-driver Dummy --path . --script res://tools_src/web_pack_lists.gd -- --out=build/web_lists.json
## (tools/build_web.sh runs it.) For every map scene it walks the dependency closure (ResourceLoader.get_dependencies,
## recursively). A file goes into a map's pack only when
##   - that map (or, for the Fernflug acts, only acts of Fernflug) is the only map that needs it,
##   - nothing outside the maps needs it (the closure of every other resource in the project: menus, scripts'
##     preloads, the shared actors and weapons), and
##   - no script, data file or config outside the packs names it by path or uid (things loaded with load("res://...")
##     from code or JSON stay in the main pack even if a map scene also uses them),
##   - it is not a script (class_name scripts must be known at start) or a JSON table.
## Everything else stays in the main pack. Output: {"packs": {pack: [res paths]}, "maps": {map_id: [packs]},
## "bytes": {pack: source bytes}} where a Fernflug act needs the shared "map04" pack plus its own (if it has one).

const MAPS: Dictionary = {
	"map00_crossroads": ["map00", "res://gravelight/maps/map00_crossroads/map00.tscn"],
	"map01_kaltenbrunn": ["map01", "res://gravelight/maps/map01_kaltenbrunn/map01.tscn"],
	"map02_totenhafen": ["map02", "res://gravelight/maps/map02_totenhafen/map02.tscn"],
	"map04a_thalbach": ["map04a", "res://gravelight/maps/map04_fernflug/map04a.tscn"],
	"map04b_kranich": ["map04b", "res://gravelight/maps/map04_fernflug/map04b.tscn"],
	"map04c_groomlake": ["map04c", "res://gravelight/maps/map04_fernflug/map04c.tscn"],
	"map04d_mondlicht": ["map04d", "res://gravelight/maps/map04_fernflug/map04d.tscn"],
}
const SHARED_GROUP: Dictionary = {"map04a": "map04", "map04b": "map04", "map04c": "map04", "map04d": "map04"}
## Folders the web export drops anyway (export_presets.cfg "Web" exclude_filter) and never-exported places.
const SKIP_DIRS: PackedStringArray = ["res://.godot", "res://tools_src", "res://gravelight/tools_src", "res://tests",
	"res://gravelight/tests", "res://reference", "res://docs", "res://morning", "res://logs", "res://voice_inbox",
	"res://voice_scripts", "res://tools", "res://addons", "res://assets/import_presets", "res://assets/user_supplied",
	"res://web", "res://build", "res://export", "res://.smoke_logs", "res://.git", "res://.claude", "res://.wt"]
## The deferred "game" pack (fetched in the background once the menu is up; MapPacks.ensure waits for it before any
## match): match-only content that the menu never shows. Characters (zombies, people) stay in the main pack: the
## 3D menu (UPDATE 09 section 7) builds its squad and zombies from them.
const GAME_DIRS: PackedStringArray = ["res://gravelight/audio/vo", "res://assets/third_party/polyhaven",
	"res://assets/third_party/ambientcg", "res://assets/third_party/sketchfab", "res://assets/third_party/opengameart",
	"res://assets/ours/wonder", "res://assets/ours/world", "res://assets/ours/arms"]
## What the start-up and the menus load as scene dependencies: never deferred (plus every autoload's preloads).
const STARTUP_SCENES: PackedStringArray = ["res://ui/main_menu.tscn", "res://gravelight/ui/main_menu.tscn",
	"res://gravelight/ui/menu_inn.tscn", "res://gravelight/ui/menu_scene.tscn"]
const GAME_CHUNK_BYTES: int = 110 * 1048576
const TEXT_EXT: PackedStringArray = ["gd", "json", "cfg", "tres", "tscn", "gdshader", "gdshaderinc"]
const NEVER_PACK_EXT: PackedStringArray = ["gd", "json", "cfg"]

var _deps_cache: Dictionary = {}


func _initialize() -> void:
	var out: String = "res://build/web_lists.json"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
			if not out.begins_with("res://") and not out.is_absolute_path():
				out = "res://" + out
	var all: PackedStringArray = []
	_walk("res://", all)
	var all_set: Dictionary = {}
	for f: String in all:
		all_set[f] = true
	# 1. per map: the closure of its scene
	var need: Dictionary = {}   # file -> {pack: true}
	var map_files: Dictionary = {}
	for map_id: String in MAPS:
		var pack: String = str(MAPS[map_id][0])
		for f: String in _closure([str(MAPS[map_id][1])]):
			if not need.has(f):
				need[f] = {}
			(need[f] as Dictionary)[pack] = true
			map_files[f] = true
	# 2. the closure of everything else in the project
	var roots: PackedStringArray = []
	for f: String in all:
		if not map_files.has(f):
			roots.append(f)
	var shared: Dictionary = {}
	for f: String in _closure(roots):
		shared[f] = true
	# 3. what code and data name by path or uid (outside the map scenes)
	var hay: PackedStringArray = []
	for f: String in all:
		if TEXT_EXT.has(f.get_extension()) and not map_files.has(f):
			hay.append(FileAccess.get_file_as_string(f))
	var haystack: String = "\n".join(hay)
	var packs: Dictionary = {}
	var bytes: Dictionary = {}
	var kept_named: int = 0
	var kept_shared: int = 0
	var scene_roots: Dictionary = {}
	for map_id: String in MAPS:
		scene_roots[str(MAPS[map_id][1])] = true
	for f: String in need:
		if not all_set.has(f) or NEVER_PACK_EXT.has(f.get_extension()):
			continue
		var root: bool = scene_roots.has(f)   # the map scenes themselves: code names them only to load them after MapPacks.ensure
		if shared.has(f) and not root:
			kept_shared += 1
			continue
		var who: Array = (need[f] as Dictionary).keys()
		var pack: String = ""
		if who.size() == 1:
			pack = str(who[0])
		else:
			var grp: String = ""
			for w: Variant in who:
				var g: String = str(SHARED_GROUP.get(str(w), ""))
				if g == "" or (grp != "" and g != grp):
					grp = ""
					break
				grp = g
			pack = grp
		if pack == "":
			continue
		if not root and (haystack.contains(f) or haystack.contains(f.trim_prefix("res://"))):
			kept_named += 1
			continue
		var uid: int = ResourceLoader.get_resource_uid(f)
		if not root and uid != ResourceUID.INVALID_ID and haystack.contains(ResourceUID.id_to_text(uid)):
			kept_named += 1
			continue
		if not packs.has(pack):
			packs[pack] = []
			bytes[pack] = 0
		(packs[pack] as Array).append(f)
		bytes[pack] = int(bytes[pack]) + _size(f)
	# 4. the deferred game pack: match-only content in GAME_DIRS that the start-up / menu closure doesn't need
	var in_map_pack: Dictionary = {}
	for p: String in packs:
		for f: String in packs[p]:
			in_map_pack[f] = true
	var startup_roots: PackedStringArray = []
	for r: String in STARTUP_SCENES:
		if ResourceLoader.exists(r):
			startup_roots.append(r)
	for prop: Dictionary in ProjectSettings.get_property_list():
		var pn: String = str(prop["name"])
		if pn.begins_with("autoload/"):
			startup_roots.append(str(ProjectSettings.get_setting(pn)).trim_prefix("*"))
	var startup: Dictionary = {}
	for f: String in _closure(startup_roots):
		startup[f] = true
	var game: Array = []
	var game_bytes: int = 0
	var kept_startup: int = 0
	for f: String in all:
		if in_map_pack.has(f) or NEVER_PACK_EXT.has(f.get_extension()):
			continue
		var under: bool = false
		for gd: String in GAME_DIRS:
			if f.begins_with(gd + "/"):
				under = true
				break
		if not under:
			continue
		if startup.has(f):
			kept_startup += 1
			continue
		game.append(f)
		game_bytes += _size(f)
	# split into chunks of at most GAME_CHUNK_BYTES of source (static hosts cap single files near 100 MB; the cap on
	# textures makes an exported chunk about 0.6x its source), in path order so folders stay together
	var game_packs: Array = []
	if not game.is_empty():
		game.sort()
		var cur: Array = []
		var cur_b: int = 0
		for f: String in game:
			var b: int = _size(f)
			if not cur.is_empty() and cur_b + b > GAME_CHUNK_BYTES:
				var nm: String = "game%d" % (game_packs.size() + 1)
				packs[nm] = cur
				bytes[nm] = cur_b
				game_packs.append(nm)
				cur = []
				cur_b = 0
			cur.append(f)
			cur_b += b
		var last: String = "game%d" % (game_packs.size() + 1)
		packs[last] = cur
		bytes[last] = cur_b
		game_packs.append(last)
	var maps: Dictionary = {}
	for map_id: String in MAPS:
		var own: String = str(MAPS[map_id][0])
		var list: Array = game_packs.duplicate()
		var grp2: String = str(SHARED_GROUP.get(own, ""))
		if grp2 != "" and packs.has(grp2):
			list.append(grp2)
		if packs.has(own):
			list.append(own)
		maps[map_id] = list
	for p: String in packs:
		(packs[p] as Array).sort()
	var doc: Dictionary = {"packs": packs, "maps": maps, "bytes": bytes, "files_scanned": all.size(), "kept_named": kept_named, "kept_shared": kept_shared, "kept_startup": kept_startup}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	var fa: FileAccess = FileAccess.open(out, FileAccess.WRITE)
	fa.store_string(JSON.stringify(doc, "\t"))
	fa.close()
	var parts: PackedStringArray = []
	for p: String in packs:
		parts.append("%s %d files %.1f MB" % [p, (packs[p] as Array).size(), int(bytes[p]) / 1048576.0])
	print("[web_pack_lists] %d files scanned; packs: %s; kept in the main pack: %d named by code or data, %d needed outside the maps -> %s" % [
		all.size(), ", ".join(parts), kept_named, kept_shared, out])
	quit(0)


func _walk(dir: String, out: PackedStringArray) -> void:
	for s: String in SKIP_DIRS:
		if dir.trim_suffix("/") == s:
			return
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return
	if d.file_exists(".gdignore"):
		return
	for sub: String in d.get_directories():
		_walk(dir.path_join(sub), out)
	for f: String in d.get_files():
		var p: String = dir.path_join(f)
		var ext: String = f.get_extension()
		if ext in ["import", "uid", "md", "txt", "py", "sh", "ps1", "mjs", "log", "csv", "pdf", "gdignore", "gitkeep", "godot", "html", "js"]:
			continue
		if FileAccess.file_exists(p + ".import") or ResourceLoader.exists(p):
			out.append(p)


func _closure(roots: PackedStringArray) -> PackedStringArray:
	var seen: Dictionary = {}
	var stack: Array[String] = []
	for r: String in roots:
		stack.append(r)
	while not stack.is_empty():
		var f: String = stack.pop_back()
		if seen.has(f):
			continue
		seen[f] = true
		for d: String in _deps(f):
			if not seen.has(d):
				stack.append(d)
	return PackedStringArray(seen.keys())


func _deps(f: String) -> PackedStringArray:
	if _deps_cache.has(f):
		return _deps_cache[f]
	var out: PackedStringArray = []
	if ResourceLoader.exists(f):
		for e: String in ResourceLoader.get_dependencies(f):
			var parts: PackedStringArray = e.split("::")
			var p: String = parts[parts.size() - 1]
			if p.begins_with("uid://"):
				var id: int = ResourceUID.text_to_id(p)
				p = ResourceUID.get_id_path(id) if ResourceUID.has_id(id) else ""
			if p == "" and parts[0].begins_with("uid://"):
				var id2: int = ResourceUID.text_to_id(parts[0])
				p = ResourceUID.get_id_path(id2) if ResourceUID.has_id(id2) else ""
			if p.begins_with("res://"):
				out.append(p)
	_deps_cache[f] = out
	return out


func _size(f: String) -> int:
	var fa: FileAccess = FileAccess.open(f, FileAccess.READ)
	if fa == null:
		return 0
	var n: int = fa.get_length()
	fa.close()
	return n
