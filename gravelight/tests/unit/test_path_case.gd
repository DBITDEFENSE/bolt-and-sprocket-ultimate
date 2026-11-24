extends GutTest
## T-264 (macOS / SteamOS): a path inside an exported PCK is case-sensitive on every platform, and Linux file systems
## are too; Windows forgives "res://Assets/x.png" for "res://assets/x.png" in the editor, so a wrong case only shows
## in a build. This test reads every script, scene, resource, shader and JSON data file and fails on each `res://`
## path (and each repo-relative path that starts with a top-level folder) whose letters match a file or folder on
## disk except for their case. Paths that do not exist at all are not this test's business (many are built at run
## time: "res://data/%s.json"); for those the static folder part is still checked.

const SKIP_DIRS: PackedStringArray = ["build", "export", "logs", "voice_work", "voice_review", "node_modules", "venv", "tts",
	"dl_godot", "dl_blender", "dl_rhubarb", "__pycache__", "_downloads"]
const TEXT_EXT: PackedStringArray = ["gd", "tscn", "tres", "json", "gdshader", "gdshaderinc", "cfg", "godot"]
## A relative path is only checked when it ends in one of these (else every "a/b" in a sentence would be one).
const REL_EXT: String = "glb|gltf|fbx|ogg|wav|mp3|ogv|png|jpg|jpeg|svg|webp|exr|hdr|tscn|tres|res|gd|json|gdshader|ttf|otf|csv|txt|cfg|obj|mesh|anim"

var _dirs: Dictionary = {}    # lower-case "res://a/b" -> the folder's real spelling
var _files: Dictionary = {}   # lower-case "res://a/b.png" -> the file's real spelling
var _texts: PackedStringArray = []
var _top: PackedStringArray = []


func _walk(dir: String) -> void:
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return
	d.include_hidden = false
	var base: String = dir if dir.ends_with("/") else dir + "/"
	for sub: String in d.get_directories():
		if sub.begins_with(".") or SKIP_DIRS.has(sub):
			continue
		_dirs[(base + sub).to_lower()] = base + sub
		_walk(base + sub)
	for f: String in d.get_files():
		_files[(base + f).to_lower()] = base + f
		if TEXT_EXT.has(f.get_extension().to_lower()):
			_texts.append(base + f)


func before_all() -> void:
	_walk("res://")
	for k: String in _dirs.keys():
		if k.count("/") == 2:   # "res://name"
			_top.append(str(_dirs[k]).trim_prefix("res://"))


## "" when `p` (a full res:// path, maybe with a run-time part) is spelled as on disk; else what is wrong.
func _wrong(p: String) -> String:
	var cut: int = p.length()
	for stop: String in ["%", "{", "*", "<", "$", "::"]:
		var at: int = p.find(stop)
		if at >= 0:
			cut = mini(cut, at)
	var dynamic: bool = cut < p.length()
	var s: String = p.substr(0, cut)
	if dynamic:   # only the folders before the run-time part can be judged
		s = s.substr(0, s.rfind("/"))
	s = s.trim_suffix("/")
	if s.length() <= "res://".length():
		return ""
	var low: String = s.to_lower()
	if _files.has(low):
		return "" if str(_files[low]) == s else "file is %s" % _files[low]
	if _dirs.has(low):
		return "" if str(_dirs[low]) == s else "folder is %s" % _dirs[low]
	# the file itself is not there (generated, optional or run-time): its nearest existing folder still has a case
	var parent: String = s
	while parent.length() > "res://".length():
		parent = parent.substr(0, parent.rfind("/"))
		if _dirs.has(parent.to_lower()):
			return "" if str(_dirs[parent.to_lower()]) == parent else "folder is %s" % _dirs[parent.to_lower()]
	return ""


func test_the_walk_found_the_project() -> void:
	assert_gt(_files.size(), 5000, "the repository's files were listed")
	assert_gt(_texts.size(), 2000, "scripts, scenes and data files were found")
	assert_true(_files.has("res://project.godot"), "project.godot is in the listing")
	# the checker itself: a wrong case is reported, the right one and a missing file are not
	assert_eq(_wrong("res://project.godot"), "")
	assert_ne(_wrong("res://Project.godot"), "", "a wrong-case file is caught")
	assert_ne(_wrong("res://Gravelight/autoload/settings.gd"), "", "a wrong-case folder is caught")
	assert_ne(_wrong("res://Gravelight/autoload/%s.gd"), "", "a wrong-case folder before a run-time part is caught")
	assert_eq(_wrong("res://gravelight/autoload/no_such_file.gd"), "", "a missing file is not a case error")


func test_every_path_matches_the_case_on_disk() -> void:
	var abs_re: RegEx = RegEx.create_from_string("res://[^\"'\\s\\)\\]\\[,;<>|`\\\\]+")
	var rel_ci: RegEx = RegEx.create_from_string("(?i)[\"']((?:%s)/[A-Za-z0-9_ ./%%{}\\-]+\\.(?:%s))[\"']" % ["|".join(_top), REL_EXT])
	var bad: PackedStringArray = []
	var checked: int = 0
	for path: String in _texts:
		var text: String = FileAccess.get_file_as_string(path)
		if text.is_empty():
			continue
		if path.ends_with("test_path_case.gd"):
			continue   # this file's own wrong-case examples
		for m: RegExMatch in abs_re.search_all(text):
			var p: String = m.get_string().trim_suffix(".").trim_suffix(":")
			checked += 1
			var why: String = _wrong(p)
			if why != "":
				bad.append("%s: %s (%s)" % [path, p, why])
		if text.find("/") < 0:
			continue
		for m: RegExMatch in rel_ci.search_all(text):
			var p: String = "res://" + m.get_string(1)
			checked += 1
			var why: String = _wrong(p)
			if why != "":
				bad.append("%s: %s (%s)" % [path, m.get_string(1), why])
	assert_gt(checked, 10000, "paths were found and checked (%d)" % checked)
	assert_eq(bad.size(), 0, "paths whose case differs from the disk (they load on Windows, not in a build or on Linux):\n  " + "\n  ".join(bad.slice(0, 60)))
