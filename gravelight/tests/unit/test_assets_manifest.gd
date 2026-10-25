extends GutTest
## The generated asset manifest is current (T-087): docs/ASSETS.md's block between `<!-- assets:begin -->` and
## `<!-- assets:end -->` and data/credits_art.json are what `python -I tools/assets_manifest.py` would write for the
## SOURCE.txt files on disk. The rows are rebuilt here in GDScript (same format as the script) so the test needs no
## Python. Also covers the Credits screen's "Art credits" section, which reads the same JSON at runtime.

const THIRD: String = "res://assets/third_party"
const ASSETS_MD: String = "res://docs/ASSETS.md"
const CREDITS_JSON: String = "res://data/credits_art.json"
const BEGIN: String = "<!-- assets:begin -->"
const END: String = "<!-- assets:end -->"
const KEY_ALIASES: Dictionary = {"authors": "author", "source url": "source", "url": "source", "credit": "credit line", "licence": "license"}
const Gate: GDScript = preload("res://gravelight/tests/unit/test_license_gate.gd")   # canonical_license()
const SKIP_NAMES: PackedStringArray = ["SOURCE.txt", "LICENSE.txt", ".gdignore"]


static func parse_source(path: String) -> Dictionary:
	var fields: Dictionary = {}
	for raw: String in FileAccess.get_file_as_string(path).split("\n"):
		var line: String = raw.trim_suffix("\r")
		if line.strip_edges().is_empty() or line.strip_edges().begins_with("#") or line.find(":") < 0:
			continue
		var colon: int = line.find(":")
		var k: String = line.substr(0, colon).strip_edges().to_lower()
		k = KEY_ALIASES.get(k, k)
		if not fields.has(k):
			fields[k] = line.substr(colon + 1).strip_edges()
	return fields


## Files of an asset folder (recursive, sorted like Python's os.walk with sorted names), with sizes.
static func folder_files(folder: String) -> Array:
	var out: Array = []
	var da: DirAccess = DirAccess.open(folder)
	if da == null:
		return out
	var files: PackedStringArray = da.get_files()
	files.sort()
	for f: String in files:
		if f in SKIP_NAMES or f.ends_with(".import") or f.ends_with(".uid"):
			continue
		var fa: FileAccess = FileAccess.open(folder.path_join(f), FileAccess.READ)
		out.append([f, fa.get_length() if fa != null else 0])
	var dirs: PackedStringArray = da.get_directories()
	dirs.sort()
	for d: String in dirs:
		for sub: Array in folder_files(folder.path_join(d)):
			out.append([d + "/" + sub[0], sub[1]])
	return out


## Every asset folder (holding a SOURCE.txt) under assets/third_party, as the script's entry dictionaries, sorted by folder.
static func collect() -> Array:
	var entries: Array = []
	_walk(THIRD, entries)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["folder"] < b["folder"])
	return entries


static func _walk(dir: String, entries: Array) -> void:
	var da: DirAccess = DirAccess.open(dir)
	if da == null:
		return
	if FileAccess.file_exists(dir.path_join("SOURCE.txt")):
		var fields: Dictionary = parse_source(dir.path_join("SOURCE.txt"))
		var rel: String = dir.trim_prefix(THIRD + "/")
		var parts: PackedStringArray = rel.split("/")
		var files: Array = folder_files(dir)
		var names: PackedStringArray = []
		var bytes: int = 0
		for f: Array in files:
			names.append(f[0])
			bytes += f[1]
		entries.append({
			"folder": "assets/third_party/" + rel, "source": parts[0],
			"id": "/".join(parts.slice(1)) if parts.size() > 1 else "",
			"title": fields.get("title", ""), "author": fields.get("author", ""), "url": fields.get("source", ""),
			"license": Gate.canonical_license(fields.get("license", "")),
			"credit": fields.get("credit line", ""), "files": names, "bytes": bytes,
		})
	var dirs: PackedStringArray = da.get_directories()
	dirs.sort()
	for d: String in dirs:
		_walk(dir.path_join(d), entries)


static func md_cell(s: String) -> String:
	return s.replace("|", "\\|").replace("\n", " ")


static func expected_rows(entries: Array) -> PackedStringArray:
	var rows: PackedStringArray = []
	for e: Dictionary in entries:
		@warning_ignore("integer_division")
		var kb: int = (int(e["bytes"]) + 512) / 1024
		rows.append("| `%s` | %s | %s | %s | %s | %d files, %d KB |" % [e["folder"], md_cell(e["title"]), md_cell(e["author"]),
			md_cell(e["license"]), md_cell(e["credit"]), (e["files"] as PackedStringArray).size(), kb])
	return rows


func test_assets_md_block_is_current() -> void:
	var md: String = FileAccess.get_file_as_string(ASSETS_MD)
	var a: int = md.find(BEGIN)
	var b: int = md.find(END)
	assert_true(a >= 0 and b > a, "docs/ASSETS.md has the assets:begin / assets:end markers")
	if a < 0 or b < a:
		return
	var block: String = md.substr(a, b - a)
	var entries: Array = collect()
	var want: PackedStringArray = expected_rows(entries)
	var got: PackedStringArray = []
	for line: String in block.split("\n"):
		if line.begins_with("| `assets/third_party/"):
			got.append(line)
	assert_eq(got.size(), want.size(), "one generated row per asset folder (run: python -I tools/assets_manifest.py)")
	for i: int in range(mini(got.size(), want.size())):
		assert_eq(got[i], want[i], "row %d is current" % i)
	gut.p("manifest: %d asset folders" % entries.size())


func test_credits_json_is_current() -> void:
	var entries: Array = collect()
	var doc: Dictionary = MenuCredits.art_credits_doc()
	if entries.is_empty():
		assert_true((doc.get("entries", []) as Array).is_empty(), "no third-party assets: credits_art.json empty or absent")
		return
	assert_true(doc.has("entries"), "data/credits_art.json exists with entries (run: python -I tools/assets_manifest.py)")
	var got: Array = doc.get("entries", [])
	assert_eq(got.size(), entries.size(), "one credits entry per asset folder")
	for i: int in range(mini(got.size(), entries.size())):
		var g: Dictionary = got[i]
		var e: Dictionary = entries[i]
		for k: String in ["folder", "source", "id", "title", "author", "url", "license", "credit"]:
			assert_eq(String(g.get(k, "")), String(e[k]), "%s.%s" % [e["folder"], k])
		var gf: PackedStringArray = PackedStringArray(g.get("files", []))
		assert_eq(gf, e["files"] as PackedStringArray, e["folder"] + " files")
	# the grouped credit lines name every distinct credit once, in first-seen order
	var want_lines: PackedStringArray = []
	for e: Dictionary in entries:
		if not want_lines.has(e["credit"]):
			want_lines.append(e["credit"])
	var got_lines: PackedStringArray = []
	for g: Variant in doc.get("credit_lines", []):
		got_lines.append(String((g as Dictionary).get("credit", "")))
	assert_eq(got_lines, want_lines, "credit_lines grouped per distinct credit line")


func test_art_credits_reach_the_credits_screen() -> void:
	var lines: PackedStringArray = MenuCredits.art_credit_lines()
	var entries: Array = collect()
	if entries.is_empty():
		assert_true(lines.is_empty())
		return
	assert_gt(lines.size(), 0, "the Credits screen has art credit lines")
	for e: Dictionary in entries:
		var found: bool = false
		for l: String in lines:
			if l.begins_with(String(e["credit"])):
				found = true
		assert_true(found, "credit line reaches the screen: " + String(e["credit"]))
	for l: String in lines:
		assert_false(l.containsn("Perk-a-Cola") or l.containsn("Call of Duty"), "no brand names in credits")
	# the screen builds without a script error and shows the heading after the hand-written TEXT
	var screen: MenuCredits = MenuCredits.new()
	add_child_autofree(screen)
	await get_tree().process_frame
	var heading: bool = false
	for c: Node in screen.content.get_children():
		if c is Label and (c as Label).text == MenuCredits.ART_HEADING:
			heading = true
	assert_true(heading, "the 'Art credits' heading is on the Credits screen")
