extends Node
## Speaks every line through one place. A line id (e.g. "cs.intro.03") is looked up in the line indexes,
## a subtitle is always shown, and the voice is: a recorded file at res://audio/vo/<id>.ogg if one exists,
## otherwise placeholder text-to-speech with the original web build's per-character voice profile
## (pitch / rate / preferred-voice keywords from VOICE_PROFILES). Voice never replaces text.

## Every source of voiced lines: [data table, key inside it ("" = the table itself)]. New per-system line
## files (UI, bosses, Fine Print, Gravelight) register here; keys starting with "_" are docs.
const LINE_SOURCES: Array = [["bs/story/lines_index", ""], ["bs/ui_lines", ""], ["bs/bosses", "lines"],
	["bs/weapons", "lines"], ["bs/levels/scrapheap_lines", "lines"], ["bs/levels/rustvane_lines", "lines"],
	["bs/levels/nova_plaza_lines", "lines"], ["bs/levels/verdant_lines", "lines"], ["bs/gadgets", "lines"], ["bs/forge", "lines"], ["bs/enemies", "lines"]]
const VO_DIR: String = "res://audio/vo/"

var _lines: Dictionary = {}
var _profiles: Dictionary = {}
var _npc_voice: Dictionary = {}
var _speakers: Dictionary = {}
var _voice_cache: Dictionary = {}   # speaker -> tts voice id
var _player: AudioStreamPlayer


func _ready() -> void:
	for src: Array in LINE_SOURCES:
		if not Data.has_table(str(src[0])):
			continue
		var t: Variant = Data.table(str(src[0]))
		if t is Dictionary and str(src[1]) != "":
			t = (t as Dictionary).get(str(src[1]), {})
		if t is Dictionary:
			for id: String in (t as Dictionary).keys():
				if not id.begins_with("_") and (t as Dictionary)[id] is Dictionary:
					_lines[id] = (t as Dictionary)[id]
	var sp: Variant = Data.table("bs/story/speakers")
	if sp is Dictionary:
		_profiles = (sp as Dictionary).get("voice_profiles", {})
		_npc_voice = (sp as Dictionary).get("npc_voice", {})
		_speakers = (sp as Dictionary).get("speakers", {})
	_player = AudioStreamPlayer.new()
	_player.bus = &"Master"
	add_child(_player)


func has_line(line_id: String) -> bool:
	return _lines.has(line_id)


func line(line_id: String) -> Dictionary:
	return _lines.get(line_id, {})


## Plays a line: subtitle + recorded audio or TTS. Returns false if the id is unknown.
func play(line_id: String) -> bool:
	if not _lines.has(line_id):
		push_warning("Unknown VO line: %s" % line_id)
		return false
	var l: Dictionary = _lines[line_id]
	var who: String = str(l.get("who", ""))
	var text: String = str(l.get("text", ""))
	var spk: Dictionary = _speakers.get(who, {})
	var col: Color = Color.from_string(str(spk.get("color", "#ffffff")), Color.WHITE)
	EventBus.vo_line_started.emit(line_id, who, text)
	EventBus.subtitle.emit(str(spk.get("name", who.to_upper())), text, col, 1.2 + text.length() * 0.055)
	if not _voice_allowed():
		return true
	var rec: String = VO_DIR + line_id + ".ogg"
	if ResourceLoader.exists(rec):
		_player.stream = load(rec)
		_player.play()
	elif bool(Settings.get_value("tts_voices", true)):
		_speak_tts(who, text)
	return true


## Never makes a sound in headless runs (tests, CI) or when the voice setting is off.
func _voice_allowed() -> bool:
	return DisplayServer.get_name() != "headless" and bool(Settings.get_value("voiceOn", true)) and float(Settings.get_value("voiceVol", 1.0)) > 0.0


func _speak_tts(who: String, text: String) -> void:
	var prof: Dictionary = profile_for(who)
	var voice: String = _pick_voice(who, prof)
	if voice == "":
		return
	DisplayServer.tts_speak(strip_markup(text), voice, int(100.0 * float(Settings.get_value("voiceVol", 1.0)) * float(Settings.get_value("master", 1.0))),
		clampf(float(prof.get("pitch", 1.0)), 0.0, 2.0), clampf(float(prof.get("rate", 1.0)), 0.1, 10.0), 0, true)


## Speaker profile; NPCs share the generic npc0..npc3 profiles as in the original (NPC_VOICE).
func profile_for(who: String) -> Dictionary:
	if _profiles.has(who):
		return _profiles[who]
	var alias: String = str(_npc_voice.get(who, ""))
	return _profiles.get(alias, {"pitch": 1.0, "rate": 1.0, "kw": []})


func _pick_voice(who: String, prof: Dictionary) -> String:
	if _voice_cache.has(who):
		return _voice_cache[who]
	var voices: Array[Dictionary] = DisplayServer.tts_get_voices()
	var best: String = ""
	for kw: Variant in prof.get("kw", []):
		for v: Dictionary in voices:
			if str(v.get("name", "")).to_lower().contains(str(kw)) or str(v.get("language", "")).to_lower() == str(kw):
				best = str(v["id"])
				break
		if best != "":
			break
	if best == "" and not voices.is_empty():
		best = str(voices[0]["id"])
	_voice_cache[who] = best
	return best


## TTS reads "OmniScrap™" badly: strip trademark marks and stage directions in *asterisks*.
static func strip_markup(text: String) -> String:
	var t: String = text.replace("™", "").replace("®", "")
	var rx: RegEx = RegEx.create_from_string("[*][^*]*[*]")
	return rx.sub(t, "", true).strip_edges()
