class_name CinemaLibrary
extends RefCounted
## T-194 (UPDATE 11 "LAZARUS"): the data side of the four LAZARUS cutscenes and the Moscow 1953 card
## (data/gravelight/cutscenes_lazarus.json; shot lists docs/CUTSCENES_LAZARUS.md). Each definition is in the
## campaign.json `cutscenes` shape (seconds, shots[] with CinemaShot keys, fade_at, end, music, grade), so
## CinemaDirector.validate and the clip tool read it unchanged; a shot adds `_set` (its stage, `sets` in the data),
## `fx` / `fx_at` (the stage's effects), `squad_lines` ([[t, seat, suffix]]: a GL1 line from whoever sits in that seat)
## and `sfx_opt` (sounds another branch provides, T-192's chant and whispers: played when they exist). The
## definition's `beds` ([[t, key, db, out_t]]) are the scene's ambience loops, `beds_opt` the optional ones.
## Pure apart from the sound table: CinemaReel plays what `resolved()` returns.

const PATH: String = "res://data/gravelight/cutscenes_lazarus.json"
const SQUAD: Array[String] = ["dutch", "peg", "deacon", "wren"]

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = GLData.load_json(PATH)
	return _data


static func reload() -> void:
	_data = {}


static func ids() -> Array[String]:
	var out: Array[String] = []
	for k: Variant in (data().get("cutscenes", {}) as Dictionary).keys():
		out.append(str(k))
	return out


static func has_cut(id: String) -> bool:
	return (data().get("cutscenes", {}) as Dictionary).has(id)


static func def(id: String) -> Dictionary:
	return (data().get("cutscenes", {}) as Dictionary).get(id, {})


## The Archive's gallery rows: [{id, title, kind ("lazarus" | "exfil"), year}] in order.
static func gallery() -> Array:
	return data().get("gallery", [])


## The stage scene for a set id ("" = none: the black stage).
static func stage_path(set_id: String) -> String:
	return str((data().get("sets", {}) as Dictionary).get(set_id, ""))


## Every stage a definition needs, in order of first use.
static func sets_in(d: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for s: Variant in d.get("shots", []):
		var sid: String = str((s as Dictionary).get("_set", "black"))
		if not out.has(sid):
			out.append(sid)
	return out


## The four seats of the C-47 (GL1), window first: the humans in player-id order, then the bots, then whoever of the
## four is left (so there are always four passengers; the stand-ins of anyone not in the match are built like theirs).
static func seat_roster(chars_in_match: Array) -> Array[String]:
	var out: Array[String] = []
	for c: Variant in chars_in_match:
		var s: String = str(c)
		if SQUAD.has(s) and not out.has(s):
			out.append(s)
	for c2: String in SQUAD:
		if out.size() >= 4:
			break
		if not out.has(c2):
			out.append(c2)
	return out


static func speaker_for(character: String) -> String:
	return str(GLVO.CHARACTER_SPEAKERS.get(StringName(character), "DUT")) if Engine.get_main_loop() != null else "DUT"


## A definition ready to play: the seat lines turned into line ids for this roster, the optional sounds that exist
## merged in (`has_sound` is AudioDirector.has_sound unless a test passes its own).
static func resolved(id: String, roster: Array = [], has_sound: Callable = Callable()) -> Dictionary:
	var d: Dictionary = def(id).duplicate(true)
	if d.is_empty():
		return d
	var seats: Array[String] = seat_roster(roster)
	var hs: Callable = has_sound if has_sound.is_valid() else func(k: String) -> bool: return AudioDirector.has_sound(k)
	var prev_set: String = ""
	for s: Variant in d.get("shots", []):
		var sh: Dictionary = s
		var sid: String = str(sh.get("_set", prev_set))
		if prev_set != "" and sid != prev_set and str(sh.get("cut", "cut")) == "blend":
			sh["cut"] = "dip"   # a camera blend across two stages means nothing: it dips through black instead
		prev_set = sid
		var lines: Array = sh.get("lines", []).duplicate()
		for sl: Variant in sh.get("squad_lines", []):
			var e: Array = sl
			var seat: int = clampi(int(e[1]), 0, 3)
			lines.append([float(e[0]), "%s_%s" % [speaker_for(seats[seat]), str(e[2])]])
		if not lines.is_empty():
			sh["lines"] = lines
		var sfx: Array = sh.get("sfx", []).duplicate()
		for so: Variant in sh.get("sfx_opt", []):
			if so is Array and (so as Array).size() >= 2 and bool(hs.call(str(so[1]))):
				sfx.append(so)
		if not sfx.is_empty():
			sh["sfx"] = sfx
	var beds: Array = d.get("beds", []).duplicate()
	for bo: Variant in d.get("beds_opt", []):
		if bo is Array and (bo as Array).size() >= 2 and bool(hs.call(str(bo[1]))):
			beds.append(bo)
	d["beds"] = beds
	return d


## Every line id a definition can say (its vo / vo2 / lines, and every seat line for every character).
static func line_ids(d: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for s: Variant in d.get("shots", []):
		var sh: Dictionary = s
		for k: String in ["vo", "vo2"]:
			if str(sh.get(k, "")) != "":
				out.append(str(sh[k]))
		for le: Variant in sh.get("lines", []):
			out.append(str((le as Array)[1]))
		for sl: Variant in sh.get("squad_lines", []):
			for c: String in SQUAD:
				out.append("%s_%s" % [speaker_for(c), str((sl as Array)[2])])
	return out


## Every card a definition shows: [title, subtitle, time] (the definition's own and the shots' `card`s, in order).
static func cards(d: Dictionary) -> Array:
	var out: Array = []
	if d.has("title"):
		out.append([str(d["title"]), str(d.get("subtitle", "")), str(d.get("time", ""))])
	for s: Variant in d.get("shots", []):
		var c: Variant = (s as Dictionary).get("card", null)
		if c is Dictionary:
			out.append([str(c.get("title", "")), str(c.get("subtitle", "")), str(c.get("time", ""))])
	return out
