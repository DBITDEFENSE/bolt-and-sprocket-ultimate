extends SceneTree
## Writes Godot `.import` files for the assets under res://assets/ from the presets in assets/import_presets/*.cfg
## (UPDATE_05 section 1, T-088). `*.import` is git-ignored in this repo, so the presets are the source of truth:
## run this, then the editor import (`godot --headless --editor --quit-after 300 --path .`), and every checkout
## imports the same way (VRAM-compressed mipmapped textures, normal-map flag by file name, mesh compression off
## for weapons, LODs for props and characters).
##
##   godot --headless --audio-driver Dummy --path . --script res://tools_src/apply_import_presets.gd [-- --force] [--root=res://assets/third_party] [--dry-run]
##   (tools/apply_import_presets.sh)
##
## A preset .cfg has a [preset] section (importer, type, extensions, match globs, priority) and a [params] section
## copied verbatim into the .import. Matching: the file's extension must be listed; then the highest-priority preset
## whose glob matches the file's lower-case res:// path or name wins. A folder can force a preset with a file
## `import_preset.txt` holding the preset's name (e.g. "weapon"); it applies to that folder and its children.
## Existing .import files are left alone unless --force, and --force keeps their uid= line so scene references
## stay valid.

const PRESET_DIR: String = "res://assets/import_presets"
const DEFAULT_ROOT: String = "res://assets"
const MARKER: String = "import_preset.txt"

var _presets: Array = []   # [{name, importer, type, extensions, match, priority, params: ConfigFile}]
var _force: bool = false
var _dry: bool = false
var _root: String = DEFAULT_ROOT
var _written: int = 0
var _kept: int = 0
var _by_preset: Dictionary = {}


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a == "--force":
			_force = true
		elif a == "--dry-run":
			_dry = true
		elif a.begins_with("--root="):
			_root = a.substr(7)
	_load_presets()
	if _presets.is_empty():
		push_error("[presets] no presets in %s" % PRESET_DIR)
		quit(1)
		return
	_walk(_root, "")
	var parts: PackedStringArray = []
	for k: String in _by_preset:
		parts.append("%s %d" % [k, _by_preset[k]])
	print("[presets] %s: wrote %d .import files, kept %d (%s)%s" % [_root, _written, _kept, ", ".join(parts), " [dry run]" if _dry else ""])
	quit(0)


func _load_presets() -> void:
	var d: DirAccess = DirAccess.open(PRESET_DIR)
	if d == null:
		return
	for f: String in d.get_files():
		if not f.ends_with(".cfg"):
			continue
		var cf: ConfigFile = ConfigFile.new()
		if cf.load(PRESET_DIR.path_join(f)) != OK:
			push_warning("[presets] bad preset %s" % f)
			continue
		var exts: Array = []
		for e: Variant in cf.get_value("preset", "extensions", []):
			exts.append(str(e).to_lower())
		var globs: Array = []
		for g: Variant in cf.get_value("preset", "match", ["*"]):
			globs.append(str(g).to_lower())
		_presets.append({
			"name": f.get_basename(),
			"importer": str(cf.get_value("preset", "importer", "texture")),
			"type": str(cf.get_value("preset", "type", "CompressedTexture2D")),
			"extensions": exts,
			"match": globs,
			"priority": int(cf.get_value("preset", "priority", 0)),
			"cfg": cf,
		})
	_presets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["priority"]) > int(b["priority"]))


static func preset_names(presets: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	for p: Dictionary in presets:
		out.append(str(p["name"]))
	return out


## The preset for a file: a folder marker wins, then the highest-priority glob match among presets that take the
## extension. Null when nothing applies (the file is not an asset we import).
func pick(path: String, forced: String) -> Dictionary:
	var ext: String = path.get_extension().to_lower()
	var low: String = path.to_lower()
	var fallback: Dictionary = {}
	# a folder's forced preset only claims the extensions it imports (T-090: a weapon folder's textures still get
	# the normal-map / data presets by name)
	var forced_here: bool = false
	for q: Dictionary in _presets:
		if str(q["name"]) == forced and (q["extensions"] as Array).has(ext):
			forced_here = true
	if not forced_here:
		forced = ""
	for p: Dictionary in _presets:
		if not (p["extensions"] as Array).has(ext):
			continue
		if forced != "" and str(p["name"]) == forced:
			return p
		for g: String in p["match"]:
			if g == "*":
				if fallback.is_empty() or int(p["priority"]) > int(fallback["priority"]):
					fallback = p
			elif low.match(g) or low.get_file().match(g):
				if forced == "":
					return p
	return fallback


func _walk(dir: String, forced: String) -> void:
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return
	d.include_hidden = false
	var here: String = forced
	if d.file_exists(MARKER):
		var f: FileAccess = FileAccess.open(dir.path_join(MARKER), FileAccess.READ)
		if f != null:
			here = f.get_as_text().strip_edges().to_lower()
	for sub: String in d.get_directories():
		if sub == "import_presets" or sub.begins_with("."):
			continue
		_walk(dir.path_join(sub), here)
	for f: String in d.get_files():
		if f.ends_with(".import") or f == MARKER:
			continue
		var path: String = dir.path_join(f)
		var p: Dictionary = pick(path, here)
		if p.is_empty():
			continue
		_apply(path, p)


func _apply(path: String, p: Dictionary) -> void:
	var imp: String = path + ".import"
	var uid: String = ""
	if FileAccess.file_exists(imp):
		if not _force:
			_kept += 1
			return
		var old: ConfigFile = ConfigFile.new()
		if old.load(imp) == OK:
			uid = str(old.get_value("remap", "uid", ""))
	_by_preset[p["name"]] = int(_by_preset.get(p["name"], 0)) + 1
	_written += 1
	if _dry:
		print("[presets] %s <- %s" % [path, p["name"]])
		return
	var out: ConfigFile = ConfigFile.new()
	out.set_value("remap", "importer", p["importer"])
	if str(p["importer"]) == "scene":
		out.set_value("remap", "importer_version", 1)
	out.set_value("remap", "type", p["type"])
	if uid != "":
		out.set_value("remap", "uid", uid)
	out.set_value("deps", "source_file", path)
	var cfg: ConfigFile = p["cfg"]
	for key: String in cfg.get_section_keys("params"):
		out.set_value("params", key, cfg.get_value("params", key))
	var err: int = out.save(imp)
	if err != OK:
		push_error("[presets] could not write %s (%d)" % [imp, err])
