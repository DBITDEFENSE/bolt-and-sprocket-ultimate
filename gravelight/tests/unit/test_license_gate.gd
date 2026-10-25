extends GutTest
## The licence gate (UPDATE_05 section 0.2, UPDATE_05A section 3, T-087): every file under assets/ (except
## assets/user_supplied/, Devin's git-ignored drop box) must sit in a folder, or under one, that holds both
## LICENSE.txt and SOURCE.txt, and that SOURCE.txt's `License:` line must name an allowed licence. Fails with the
## offending path. Nothing ships without paperwork.

const ASSETS_DIR: String = "res://assets"
const EXEMPT_DIRS: PackedStringArray = ["res://assets/user_supplied"]
## Mirrors tools/assets_manifest.py LICENSES (regex on the lowercased License line -> canonical name).
const ALLOWED: Array = [
	["cc0|public domain", "CC0"],
	["cc[- ]?by[- ]?4|attribution 4", "CC-BY 4.0"],
	["cc[- ]?by[- ]?3|attribution 3", "CC-BY 3.0"],
	["\\bofl\\b|open font", "OFL 1.1"],
	["\\bmit\\b", "MIT"],
	["apache", "Apache 2.0"],
	["unity asset store|asset store eula", "Unity Asset Store EULA"],
	["\\bours\\b|original work|in-house", "Ours"],
]
const FORBIDDEN: Array = ["nc\\b", "non-?commercial", "editorial", "noai", "no-ai"]
## Files that are paperwork or engine bookkeeping, not assets.
const SKIP_EXT: PackedStringArray = ["import", "uid", "md"]
const SKIP_NAMES: PackedStringArray = ["SOURCE.txt", "LICENSE.txt", ".gdignore", ".gitkeep"]


static func canonical_license(line: String) -> String:
	var t: String = line.to_lower()
	for pair: Array in ALLOWED:
		var rx: RegEx = RegEx.create_from_string(String(pair[0]))
		if rx.search(t) != null:
			return String(pair[1])
	return ""


## The `License:` value of a SOURCE.txt ("" when absent).
static func source_license(path: String) -> String:
	var text: String = FileAccess.get_file_as_string(path)
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		var colon: int = line.find(":")
		if colon <= 0:
			continue
		var key: String = line.substr(0, colon).strip_edges().to_lower()
		if key == "license" or key == "licence":
			return line.substr(colon + 1).strip_edges()
	return ""


## Every file under `dir` (recursive), res:// paths.
static func walk(dir: String, out: PackedStringArray) -> void:
	var da: DirAccess = DirAccess.open(dir)
	if da == null:
		return
	da.include_hidden = true
	for f: String in da.get_files():
		out.append(dir.path_join(f))
	for sub: String in da.get_directories():
		if sub == "." or sub == "..":
			continue
		walk(dir.path_join(sub), out)


## The nearest ancestor folder (including the file's own) holding both LICENSE.txt and SOURCE.txt, "" if none
## above ASSETS_DIR.
static func paperwork_folder(file: String) -> String:
	var dir: String = file.get_base_dir()
	while dir.begins_with(ASSETS_DIR) and dir.length() > ASSETS_DIR.length():
		if FileAccess.file_exists(dir.path_join("LICENSE.txt")) and FileAccess.file_exists(dir.path_join("SOURCE.txt")):
			return dir
		dir = dir.get_base_dir()
	return ""


static func is_exempt(file: String) -> bool:
	for e: String in EXEMPT_DIRS:
		if file.begins_with(e + "/"):
			return true
	return false


static func is_bookkeeping(file: String) -> bool:
	return file.get_extension() in SKIP_EXT or file.get_file() in SKIP_NAMES


func test_every_asset_file_has_paperwork() -> void:
	var files: PackedStringArray = []
	walk(ASSETS_DIR, files)
	var checked: int = 0
	var offenders: PackedStringArray = []
	var folders: Dictionary = {}
	for f: String in files:
		if is_exempt(f) or is_bookkeeping(f):
			continue
		checked += 1
		var folder: String = paperwork_folder(f)
		if folder.is_empty():
			offenders.append(f + "  (no LICENSE.txt + SOURCE.txt in its folder or above)")
			continue
		folders[folder] = true
	for folder: String in folders.keys():
		var lic_line: String = source_license(folder.path_join("SOURCE.txt"))
		var canon: String = canonical_license(lic_line)
		if canon.is_empty():
			offenders.append(folder + "/SOURCE.txt  (License not allowed or missing: '%s')" % lic_line)
			continue
		for bad: String in FORBIDDEN:
			if RegEx.create_from_string(bad).search(lic_line.to_lower()) != null:
				offenders.append(folder + "/SOURCE.txt  (forbidden licence term in '%s')" % lic_line)
				break
		if FileAccess.get_file_as_string(folder.path_join("LICENSE.txt")).strip_edges().is_empty():
			offenders.append(folder + "/LICENSE.txt is empty")
	for o: String in offenders:
		gut.p("LICENSE GATE: " + o)
	assert_eq(offenders.size(), 0, "every file under assets/ has paperwork with an allowed licence (%d files, %d folders checked)" % [checked, folders.size()])
	gut.p("license gate: %d files in %d paperwork folders" % [checked, folders.size()])


func test_third_party_layout() -> void:
	# assets/third_party/<source>/<asset-id>/: the source is one of the known names, the id is lowercase-kebab,
	# and the paperwork sits in the asset folder itself (not only at a parent).
	var sources: PackedStringArray = ["opengameart", "polyhaven", "ambientcg", "kenney", "quaternius", "sketchfab",
		"unity_asset_store", "mixamo", "google_fonts"]
	var root: String = ASSETS_DIR.path_join("third_party")
	var da: DirAccess = DirAccess.open(root)
	if da == null:
		pass_test("no third_party folder yet")
		return
	var kebab: RegEx = RegEx.create_from_string("^[a-z0-9]+(-[a-z0-9]+)*$")
	var n: int = 0
	for src: String in da.get_directories():
		assert_true(src in sources, "known source folder: " + src)
		var sd: DirAccess = DirAccess.open(root.path_join(src))
		for id: String in sd.get_directories():
			n += 1
			var folder: String = root.path_join(src).path_join(id)
			assert_true(kebab.search(id) != null, "lowercase-kebab asset id: " + folder)
			assert_true(FileAccess.file_exists(folder.path_join("SOURCE.txt")), folder + " has SOURCE.txt")
			assert_true(FileAccess.file_exists(folder.path_join("LICENSE.txt")), folder + " has LICENSE.txt")
	gut.p("third_party: %d asset folders" % n)


func test_known_license_strings() -> void:
	assert_eq(canonical_license("CC-BY 4.0 (https://creativecommons.org/licenses/by/4.0/)"), "CC-BY 4.0")
	assert_eq(canonical_license("Creative Commons Attribution 4.0 (CC-BY 4.0)"), "CC-BY 4.0")
	assert_eq(canonical_license("CC0 1.0 Universal"), "CC0")
	assert_eq(canonical_license("SIL Open Font License 1.1"), "OFL 1.1")
	assert_eq(canonical_license("Standard Unity Asset Store EULA"), "Unity Asset Store EULA")
	assert_eq(canonical_license("Ours (original work)"), "Ours")
	assert_eq(canonical_license("CC-BY-NC 4.0"), "", "NC is never allowed")
	assert_eq(canonical_license("free for personal use"), "")
