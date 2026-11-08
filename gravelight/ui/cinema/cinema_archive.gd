class_name CinemaArchive
extends RefCounted
## T-209 (UPDATE 12 s3): the archive-reel versions of the three history cutscenes (LAZARUS SATURDAY, FOURTH DAY,
## STAUB). Data: data/gravelight/cinema_reels.json (the reel shots, each covering a span of the in-engine timeline of
## data/gravelight/cutscenes_lazarus.json; their prompts are docs/cutscenes/SHOT_PROMPTS.md). A reel is the in-engine
## definition with three additions (`reel_def`):
##   videos   a cinema_video track ({t0, t1, path, offset, id, graded}) for every reel shot whose built clip exists
##            (built_root/<scene>/shot_NN.ogv, the _720 variant on the web, the _gore variant with Gore full; made
##            by tools/cinema/archive_reel.py build from the owner's assets/user_supplied/cutscenes/<scene>/shot_NN.mp4);
##   archive  the film treatment (CinemaFilm: black-and-white or sepia, grain, scratches, dust, gate weave, flicker,
##            vignette, the Academy-ratio gate) over the in-engine stand-ins and the clips alike, with each reel
##            shot's seed;
##   cards    every in-engine `card` becomes an `archive_card` (the native Russian or German lines over the English).
## Everything else (the timeline, the lines and their subtitles, the beds, hold to skip, the host-driven online sync,
## the Gore setting on the stages) is the in-engine scene's, so a reel with no clips at all plays exactly like the
## in-engine scene through the film, and each clip that arrives replaces its span with no code change.
## Ids: "reel:<id>" always plays the reel, "engine:<id>" always the in-engine scene; a plain id plays the reel when
## the data's `in_game` is on (the campaign, the Archive, the U11 buttons) and the scene has a reel.

const PATH: String = "res://data/gravelight/cinema_reels.json"
const LOOK_PATH: String = "res://data/look/cinema_reel.json"
const REEL: String = "reel:"
const ENGINE: String = "engine:"

static var _data: Dictionary = {}
## Tests and smokes: built clips from this folder instead of the data's built_root ("" = the data's).
static var root_override: String = ""
## Tools: null = the data's in_game; true / false send plain ids to the reel / the in-engine scene.
static var in_game_override: Variant = null
## Tests: "web" / "desktop" instead of the platform ("" = the platform).
static var platform_override: String = ""


static func data() -> Dictionary:
	if _data.is_empty():
		_data = GLData.load_json(PATH)
	return _data


static func reload() -> void:
	_data = {}


static func scenes() -> Dictionary:
	return data().get("scenes", {})


static func has_scene(scene: String) -> bool:
	return scenes().has(scene)


## The library id under a reel / engine prefix.
static func base_id(id: String) -> String:
	if id.begins_with(REEL):
		return id.substr(REEL.length())
	if id.begins_with(ENGINE):
		return id.substr(ENGINE.length())
	return id


## A cut id CinemaReel can play (a library id, with or without a prefix).
static func is_known(id: String) -> bool:
	return CinemaLibrary.has_cut(base_id(id))


static func in_game() -> bool:
	if in_game_override != null:
		return bool(in_game_override)
	return bool(data().get("in_game", false))


static func plays_as_reel(id: String) -> bool:
	if id.begins_with(ENGINE):
		return false
	var b: String = base_id(id)
	if not has_scene(b):
		return false
	return id.begins_with(REEL) or in_game()


## What CinemaReel plays for `id`: the library's definition for this roster, as a reel when it plays as one.
static func resolved(id: String, roster: Array = []) -> Dictionary:
	var b: String = base_id(id)
	var d: Dictionary = CinemaLibrary.resolved(b, roster)
	if d.is_empty() or not plays_as_reel(id):
		return d
	return reel_def(b, d)


## The treatment values (cinema_reels.json `treatment`, tuned by the art bible's data/look/cinema_reel.json `post` /
## `adjust` when §1 has written it, UPDATE 12 C2), the same knobs archive_reel.py reads.
static func treatment() -> Dictionary:
	var t: Dictionary = (data().get("treatment", {}) as Dictionary).duplicate(true)
	if FileAccess.file_exists(LOOK_PATH):
		var lk: Dictionary = GLData.load_json(LOOK_PATH)
		var post: Dictionary = lk.get("post", {}) if lk.get("post", {}) is Dictionary else {}
		if post.get("grain", null) is float or post.get("grain", null) is int:
			t["grain"] = float(post["grain"]) * 1.5
		if post.get("vignette", null) is float or post.get("vignette", null) is int:
			t["vignette"] = float(post["vignette"])
		var adj: Dictionary = lk.get("adjust", {}) if lk.get("adjust", {}) is Dictionary else {}
		if adj.get("contrast", null) is float or adj.get("contrast", null) is int:
			t["contrast"] = float(adj["contrast"])
	return t


static func built_root() -> String:
	return root_override if root_override != "" else str(data().get("built_root", "res://assets/cutscene_reels"))


static func raw_root() -> String:
	return str(data().get("raw_root", "res://assets/user_supplied/cutscenes"))


static func shot_name(n: int) -> String:
	return "shot_%02d" % n


## The film's seed for a reel shot: sha1("<scene>/shot_NN"), as archive_reel.py's seed_of.
static func seed_of(scene: String, n: int) -> int:
	return ("%s/%s" % [scene, shot_name(n)]).sha1_text().substr(0, 8).hex_to_int()


static func is_web() -> bool:
	if platform_override != "":
		return platform_override == "web"
	return OS.has_feature("web")


static func file_exists(path: String) -> bool:
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)


## The built clip for a reel shot ("" = none: the shot plays as a stand-in). The web takes the 720p variant first,
## the desktop the 1080p one (each falls back to the other); Gore full takes a _gore variant first when one exists.
static func clip_path(scene: String, n: int, gore: String = "", web: bool = false) -> String:
	var g: String = gore if gore != "" else str(GLSettings.values.get("gore", "full"))
	var base: String = built_root().path_join(scene).path_join(shot_name(n))
	var sizes: Array[String] = ["", "_720"]
	if web:
		sizes = ["_720", ""]
	var variants: Array[String] = [""]
	if g == "full":
		variants = ["_gore", ""]
	for v: String in variants:
		for s: String in sizes:
			var p: String = base + v + s + ".ogv"
			if file_exists(p):
				return p
	return ""


## The reel version of an in-engine definition `d` (already resolved for its roster).
static func reel_def(scene: String, d: Dictionary) -> Dictionary:
	var sc: Dictionary = scenes().get(scene, {})
	var r: Dictionary = d.duplicate(true)
	var t: Dictionary = treatment()
	var tone: String = str(sc.get("tone", "bw"))
	var rgb: Array = (t.get("tones", {}) as Dictionary).get(tone, [1.0, 1.0, 1.0])
	var spans: Array = []
	var videos: Array = []
	var web: bool = is_web()
	for s: Variant in sc.get("shots", []):
		var sh: Dictionary = s
		var n: int = int(sh.get("n", 0))
		var sp: Array = sh.get("span", [0.0, 0.0])
		spans.append([float(sp[0]), float(sp[1]), seed_of(scene, n), n])
		var p: String = clip_path(scene, n, "", web)
		if p != "":
			videos.append({"t0": float(sp[0]), "t1": float(sp[1]), "path": p, "offset": 0.0, "id": "%s/%s" % [scene, shot_name(n)], "graded": true})
	var archive: Dictionary = t.duplicate(true)
	archive["scene"] = scene
	archive["tone"] = tone
	archive["tone_rgb"] = rgb
	archive["spans"] = spans
	r["archive"] = archive
	r["videos"] = videos
	r["bars"] = false
	r["reel"] = scene
	var cards: Dictionary = sc.get("cards", {})
	var shots: Array = r.get("shots", [])
	for i: int in shots.size():
		var shd: Dictionary = shots[i]
		var c: Variant = shd.get("card", null)
		if not (c is Dictionary):
			continue
		var cd: Dictionary = c
		var native: Array = ((cards.get(str(i), {}) as Dictionary).get("native", []) as Array).duplicate()
		var en: Array = []
		for k: String in ["title", "subtitle", "time"]:
			var line: String = str(cd.get(k, "")).strip_edges()
			if line != "" and not native.has(line):   # (a German title that reads the same in English is said once)
				en.append(line)
		shd["archive_card"] = {"native": native, "english": en, "at": float(cd.get("at", 0.5)), "hold": float(cd.get("hold", 5.0))}
		shd.erase("card")
	return r


## The dry run (the dev launcher, the tests): per scene, every reel shot in priority order with its state.
static func report() -> Array:
	var out: Array = []
	for scene: Variant in scenes().keys():
		var sc: Dictionary = scenes()[scene]
		var rows: Array = []
		for s: Variant in sc.get("shots", []):
			var sh: Dictionary = s
			var n: int = int(sh.get("n", 0))
			var built: String = clip_path(str(scene), n, "none", false)
			var raw: bool = false
			for ext: String in ["mp4", "mov", "webm", "mkv", "m4v"]:
				if FileAccess.file_exists(raw_root().path_join(str(scene)).path_join("%s.%s" % [shot_name(n), ext])):
					raw = true
			rows.append({"n": n, "priority": int(sh.get("priority", 99)), "span": sh.get("span", []), "built": built, "raw": raw})
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["priority"]) < int(b["priority"]))
		out.append({"scene": str(scene), "shots": rows})
	return out


## One line per scene for the launcher's hint: "Lazarus Saturday: 3 of 21 shots filmed (the rest in-engine)".
static func summary() -> String:
	var parts: PackedStringArray = []
	for e: Variant in report():
		var rows: Array = (e as Dictionary)["shots"]
		var got: int = 0
		for r: Variant in rows:
			if str((r as Dictionary)["built"]) != "":
				got += 1
		parts.append("%s %d/%d" % [str((scenes()[(e as Dictionary)["scene"]] as Dictionary).get("title", "")), got, rows.size()])
	return "filmed shots: " + ", ".join(parts)
