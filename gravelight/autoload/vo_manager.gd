extends Node
## Plays VO lines by ID with priority tiers, channel groups, interrupts, an expiring FIFO queue,
## per-category cooldowns and chances, shuffle-bag no-repeat, once-per-match lines, and chatter limiters
## (docs/gravelight/VO_SCRIPT.md §1). Lines live in data/gravelight/vo/lines.json (built by
## tools_src/extract_vo.py), rules in data/gravelight/vo/rules.json, audio in gravelight/audio/vo/<speaker>/<id>.ogg
## (baked by tools_src/gen_vo.py; .wav accepted too; exchange parts are <id>_p<n> under the part's speaker).
## A line with no audio file holds a timed silence and still drives subtitles.
##
## Every survivor speaks (T-035): the local player and the story voices are 2D on the VO bus; lines spoken by
## other players and bots are positional, at their body. Music, jingles and the ambience duck under story lines.
##
## API: play(line_id), play_category(speaker, category, chance, pid), say_player(category), say_as(pid, category),
## squad_say(category), stop_all(), reset_match(). `fired` counts started lines per "SPK:CAT" (smoke tests).

enum Priority { AMBIENT = 0, CHATTER = 1, EVENT = 2, ANNOUNCE = 3, CRITICAL = 4 }

const GROUP_STORY: StringName = &"story"
const GROUP_PLAYER: StringName = &"player"
## Second squad channel: what the *others* say about a down (TEAM_DOWN, REVIVE) so it can overlap the downed
## player's own DOWN / REVIVED instead of racing them (rules.json squad_second_channel, down_sequence).
const GROUP_SQUAD: StringName = &"squad"
## The companion's own channel (Jakub, U02 section 6.2; rules.json companion_speakers): his lines never wait behind the
## squad's chatter (they would come out late and out of place) and never hold the squad up. Positional at his body.
const GROUP_COMPANION: StringName = &"companion"
const LINES_PATH: String = "res://data/gravelight/vo/lines.json"
const RULES_PATH: String = "res://data/gravelight/vo/rules.json"
const AUDIO_DIR: String = "res://gravelight/audio/vo/"
const CHARACTER_SPEAKERS: Dictionary = {&"dutch": &"DUT", &"peg": &"PEG", &"deacon": &"DEA", &"wren": &"WRN", &"jakub": &"JAK",
	&"trudi": &"TRU", &"ammer": &"AMM", &"petersen": &"PET", &"jette": &"JET"}   # T-135: the map companions
const POWERUP_TOKENS: Dictionary = {&"resupply": "RESUPPLY", &"deaths_door": "DEATHSDOOR", &"double_scrip": "DOUBLESCRIP",
	&"blackout": "BLACKOUT", &"fortify": "FORTIFY", &"clearance": "CLEARANCE", &"tonic_bottle": "TONIC"}
const PERK_TOKENS: Dictionary = {&"ironhide_stout": "IRONHIDE", &"second_wind": "SECONDWIND", &"trigger_tonic": "TRIGGER",
	&"twin_barrel": "TWINBARREL", &"marathon_malt": "MARATHON", &"hawkeye_brandy": "HAWKEYE",
	&"packmule_porter": "PACKMULE", &"blastproof_bock": "BLASTPROOF", &"overclock_cordial": "OVERCLOCK",
	&"fine_print_fernet": "FERNET", &"skyhook_sekt": "SKYHOOK", &"magpie_mead": "MAGPIE", &"ledger_lager": "LEDGER"}   # T-105: Fernet's token was missing
const CLASS_TOKENS: Dictionary = {&"pistol": "PISTOL", &"bolt": "RIFLE", &"rifle": "RIFLE", &"sniper": "RIFLE",
	&"smg": "SMG", &"assault": "SMG", &"shotgun": "SHOTGUN", &"lmg": "LMG", &"launcher": "LAUNCHER",
	&"wonder": "WONDER", &"special": "LAUNCHER", &"melee": "MELEE"}
const BOSS_TOKENS: Dictionary = {&"foreman": "FOREMAN", &"screamer": "SCREAMER"}

## Tests set this so chance rolls always pass.
var always_pass_chance: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var lines: Dictionary = {}
var rules: Dictionary = {}
## "SPK:CAT" -> number of lines started this match (smoke tests / dev overlay).
var fired: Dictionary = {}
## Audio streams actually started this match (2D + 3D), for the headless smoke.
var audio_plays: int = 0
var audio_plays_3d: int = 0

var _index: Dictionary = {}          # "SPK:CAT" -> Array[StringName]
var _line_map: Dictionary = {}       # line id -> the map it belongs to ("map00", "map01", ...); absent = any map
var _bags: Dictionary = {}           # "SPK:CAT" -> Array[StringName] (remaining shuffled ids)
var _cooldown_until: Dictionary = {} # rule key -> time
var _played_once: Dictionary = {}    # line id -> true
var _current: Dictionary = {}        # group -> playing record (Dictionary) or {}
var _queue: Dictionary = {}          # group -> Array[Dictionary]
var _now: float = 0.0
var _last_chatter: float = -999.0
var _last_ambient: float = -999.0
var _idle_t: float = 0.0
var _streak_times: Array[float] = []
var _streams: Dictionary = {}        # file path -> AudioStream (or null when missing)
var _story_2d: AudioStreamPlayer
var _player_2d: AudioStreamPlayer
var _player_3d: AudioStreamPlayer3D
var _follow: Node3D = null           # whom the 3D player tracks while it plays
var _squad_2d: AudioStreamPlayer
var _squad_3d: AudioStreamPlayer3D
var _follow_b: Node3D = null
var _comp_2d: AudioStreamPlayer
var _comp_3d: AudioStreamPlayer3D
var _follow_c: Node3D = null
var _revive_line_t: Dictionary = {}  # reviver pid -> time its REVIVE line was submitted (fallback at completion)
var _subtitles: CanvasLayer
var _duck_on: bool = false
var _delayed: Array[Dictionary] = [] # {at, pid, cat, chance} squad lines scheduled a little after an event
var _match_t: float = -INF
var _last_special: bool = false
var _crucible_first: bool = false
## T-137: the first kill from a Marke hit this match has its story beat (the killer names the mark, the Operator
## remarks, Fasbender explains the relay where he has a radio); later ones roll the squad's MARKE_KILL lines.
var _marke_first: bool = false
var _banter_last: float = -INF
var _banter_at: float = INF
# Operator corporate slips (VO_SCRIPT section 10)
var _slip_last: float = -INF
var _slip_round: int = -1
var _slip_round_count: int = 0
var _slip_pending_at: float = INF
var _last_down_at: float = -INF
var _echo: Dictionary = {}           # squad_echo prefix -> [time, speaker] of the last squad line in it (T-073)
var _last_drawn: Dictionary = {}     # "SPK:CAT" -> the id drawn last, so a refilled bag never opens with it
var _occl_t: float = 0.0             # next occlusion check (physics time left)
var _occl: Dictionary = {}           # AudioStreamPlayer3D -> 0..1 occlusion amount (smoothed)
var last_said_pid: int = -1          # the survivor who last got a say_as / squad_say line out (T-086 story beats)
## Voice test (T-101, the dev launcher's "Map 0 — voice test"): every line that starts is logged with where its audio
## comes from (human take / TTS / none) to the console and voice_log; a summary goes to logs/voice_test.txt.
var voice_test: bool = false:
	set(v):
		voice_test = v
		if v and not GLBus.round_ended.is_connected(_voice_test_round_end):
			GLBus.round_ended.connect(_voice_test_round_end)
var voice_log: Array[Dictionary] = []
var _ext_2d: AudioStreamPlayer = null
var _vt_manifest: Dictionary = {}


func _ready() -> void:
	rng.randomize()
	load_data()
	_current = {GROUP_STORY: {}, GROUP_PLAYER: {}, GROUP_SQUAD: {}, GROUP_COMPANION: {}}
	_queue = {GROUP_STORY: [], GROUP_PLAYER: [], GROUP_SQUAD: [], GROUP_COMPANION: []}
	_story_2d = AudioStreamPlayer.new()
	_story_2d.name = "StoryVoice"
	_story_2d.bus = &"VO"
	add_child(_story_2d)
	_player_2d = AudioStreamPlayer.new()
	_player_2d.name = "PlayerVoice"
	_player_2d.bus = &"VO"
	add_child(_player_2d)
	_player_3d = AudioStreamPlayer3D.new()
	_player_3d.name = "SquadVoice"
	_player_3d.bus = &"VO"
	_player_3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	_player_3d.panning_strength = 1.0
	add_child(_player_3d)
	_squad_2d = AudioStreamPlayer.new()
	_squad_2d.name = "SquadVoiceB"
	_squad_2d.bus = &"VO"
	add_child(_squad_2d)
	_squad_3d = AudioStreamPlayer3D.new()
	_squad_3d.name = "SquadVoiceB3D"
	_squad_3d.bus = &"VO"
	_squad_3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	_squad_3d.panning_strength = 1.0
	add_child(_squad_3d)
	_comp_2d = AudioStreamPlayer.new()
	_comp_2d.name = "CompanionVoice"
	_comp_2d.bus = &"VO"
	add_child(_comp_2d)
	_comp_3d = AudioStreamPlayer3D.new()
	_comp_3d.name = "CompanionVoice3D"
	_comp_3d.bus = &"VO"
	_comp_3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	_comp_3d.panning_strength = 1.0
	var au0: Dictionary = rules.get("audio", {})
	_comp_3d.unit_size = float(au0.get("squad_unit_size", 5.0))
	_comp_3d.max_distance = float(au0.get("squad_max_distance", 40.0))
	add_child(_comp_3d)
	_subtitles = (load("res://gravelight/ui/subtitles.gd") as GDScript).new() as CanvasLayer
	add_child(_subtitles)
	_connect_triggers()


func load_data() -> void:
	lines = GLData.load_json(LINES_PATH)
	rules = GLData.load_json(RULES_PATH)
	_index.clear()
	_line_map.clear()
	for id: Variant in lines.keys():
		var rec: Dictionary = lines[id]
		var key: String = "%s:%s" % [rec["speaker"], rec["category"]]
		if not _index.has(key):
			_index[key] = []
		(_index[key] as Array).append(StringName(str(id)))
		var m: String = line_map_of(str(id), rec, rules)
		if m != "":
			_line_map[str(id)] = m
	var au: Dictionary = rules.get("audio", {})
	for p3: AudioStreamPlayer3D in [_player_3d, _squad_3d, _comp_3d]:
		if p3 != null:
			p3.unit_size = float(au.get("squad_unit_size", 5.0))
			p3.max_distance = float(au.get("squad_max_distance", 40.0))


# ================================================================== public API

func reset_match() -> void:
	stop_all()
	_bags.clear()
	_cooldown_until.clear()
	_played_once.clear()
	fired.clear()
	audio_plays = 0
	audio_plays_3d = 0
	_delayed.clear()
	_last_chatter = -999.0
	_last_ambient = -999.0
	_idle_t = 0.0
	_streak_times.clear()
	_match_t = _now
	_last_special = false
	_crucible_first = false
	_marke_first = false
	_banter_last = -INF
	_banter_at = INF
	_slip_last = -INF
	_slip_round = -1
	_slip_round_count = 0
	_slip_pending_at = INF
	_last_down_at = -INF
	_echo.clear()
	_last_drawn.clear()


func stop_all() -> void:
	for g: Variant in _current.keys():
		_current[g] = {}
		_queue[g] = []
	_stop_audio(GROUP_STORY)
	_stop_audio(GROUP_PLAYER)
	_stop_audio(GROUP_SQUAD)
	_stop_audio(GROUP_COMPANION)
	_revive_line_t.clear()
	_set_duck(false)


## Plays one specific line (no chance/cooldown roll). Returns true if it started or was queued.
## Story lines that world/quest code plays on the host are sent to every co-op client too (VO stays local:
## each peer runs its own VOManager; lines picked from relayed events are rolled per peer).
func play(line_id: StringName) -> bool:
	if Net.replicating():
		Net._rpc_vo.rpc(line_id)
	return play_local(line_id)


## Plays a line on this peer only.
func play_local(line_id: StringName, pid: int = -1) -> bool:
	if not lines.has(String(line_id)):
		return false
	var rec: Dictionary = lines[String(line_id)]
	return _submit(line_id, _priority_for(StringName(rec["speaker"]), str(rec["category"])), pid)


## Picks a variant of a category for a speaker, applying cooldown, chance and the no-repeat bag.
## `pid` is the player speaking (positional when it isn't the local player); -1 = non-positional.
func play_category(speaker: StringName, category: String, chance_override: float = -1.0, pid: int = -1) -> bool:
	var key: String = "%s:%s" % [speaker, category]
	if not _index.has(key):
		return false
	var rk: String = _rule_key(speaker, category)
	if _now < float(_cooldown_until.get(rk, -1.0)):
		return false
	var cd: Array = _cooldown_rule(rk, speaker)
	if echo_blocked(speaker, category):
		return false
	var chance: float = chance_override if chance_override >= 0.0 else float(cd[1])
	if not always_pass_chance and rng.randf() > chance:
		return false
	var id: StringName = _draw(key)
	if id == &"":
		return false
	var prio: int = _priority_for(speaker, category)
	if not _submit(id, prio, pid):
		return false
	_cooldown_until[rk] = _now + float(cd[0])
	_note_echo(speaker, category)
	return true


## Squad anti-echo (T-073, rules.json "squad_echo"): true when another survivor (or Jakub) said this category
## within its window, so this speaker keeps quiet instead of repeating the call.
func echo_blocked(speaker: StringName, category: String) -> bool:
	var prefix: String = _echo_prefix(speaker, category)
	if prefix == "" or not _echo.has(prefix):
		return false
	var rec: Array = _echo[prefix]
	var window: float = float((rules.get("squad_echo", {}) as Dictionary).get("categories", {}).get(prefix, 0.0))
	return StringName(rec[1]) != speaker and _now - float(rec[0]) < window


func _note_echo(speaker: StringName, category: String) -> void:
	var prefix: String = _echo_prefix(speaker, category)
	if prefix != "":
		_echo[prefix] = [_now, speaker]


## The squad_echo prefix a squad speaker's category falls under ("" = not echo-limited).
func _echo_prefix(speaker: StringName, category: String) -> String:
	if not CHARACTER_SPEAKERS.values().has(speaker):
		return ""
	var best: String = ""
	for p: Variant in ((rules.get("squad_echo", {}) as Dictionary).get("categories", {}) as Dictionary).keys():
		var ps: String = str(p)
		if category.begins_with(ps) and ps.length() > best.length():
			best = ps
	return best


## Keeps a speaker's category quiet for `seconds` (a scripted line is about to say the same thing better: a bot's
## map-mark confirmation over its automatic perk / buy / door line; Update 04 section 3, T-069).
func hold_category(speaker: StringName, category: String, seconds: float) -> void:
	var rk: String = _rule_key(speaker, category)
	_cooldown_until[rk] = maxf(float(_cooldown_until.get(rk, -1.0)), _now + seconds)


## A line from the local player's character (DUT/PEG/DEA/WRN).
func say_player(category: String, chance_override: float = -1.0) -> bool:
	return say_as(_local_player(), category, chance_override)


## A line from the survivor player `pid` plays (a human, a co-op teammate or a bot), in their own voice,
## positioned at their body unless they are the local player.
func say_as(pid: int, category: String, chance_override: float = -1.0) -> bool:
	var ok: bool = play_category(speaker_of(pid), category, chance_override, pid)
	if ok:
		last_said_pid = pid
	return ok


## A squad line for a story beat (T-086, QuestManager "vo_squad" / "vo_actor"): said by `pid` (0 = one random
## standing survivor other than `exclude_pid`) `seconds` from now, and never over a story line: it waits for the
## radio / the Operator to finish (up to `patience` s, then it is dropped). Tier-2 categories (rules.json
## player_category_priority) still cut a quip and queue behind another squad line instead of being dropped.
func say_story_beat(pid: int, category: String, seconds: float = 0.0, exclude_pid: int = -1, patience: float = 90.0) -> void:
	if pid <= 0:
		# the speaker is chosen now, so a beat's next line can go to someone else (last_said_pid); solo without
		# bots, the same survivor carries the whole beat
		pid = pick_squad_pid(category, exclude_pid)
		if pid < 0 and exclude_pid >= 0:
			pid = pick_squad_pid(category, -1)
		if pid < 0:
			return
	last_said_pid = pid
	_delayed.append({"at": _now + seconds, "pid": pid, "cat": category, "chance": 1.0, "after_story": true, "drop_at": _now + seconds + patience})


## A scheduled line the story has moved past (Fasbender's "find the notes" once the notes are found): it counts
## as played, so a round schedule skips it (QuestManager "vo_retire", T-086).
func retire(line_id: StringName) -> void:
	_played_once[String(line_id)] = true


func is_retired(line_id: StringName) -> bool:
	return _played_once.has(String(line_id))


## The story beats still waiting (tests): [{pid, cat, at}].
func pending_story_beats() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d: Dictionary in _delayed:
		if bool(d.get("after_story", false)):
			out.append({"pid": int(d["pid"]), "cat": str(d["cat"]), "at": float(d["at"])})
	return out


## A line from one random standing survivor other than `exclude_pid` (-1 = anyone).
func squad_say(category: String, chance_override: float = -1.0, exclude_pid: int = -1) -> bool:
	var pid: int = pick_squad_pid(category, exclude_pid)
	if pid < 0:
		return false
	return say_as(pid, category, chance_override)


## One random standing survivor other than `exclude_pid` who has lines for the category (-1 nobody).
func pick_squad_pid(category: String, exclude_pid: int = -1) -> int:
	var pool: Array[int] = []
	for pid: int in standing_pids():
		if pid != exclude_pid:
			if (JakubCompanion.is_companion_pid(pid) or MapCompanion.is_companion_pid(pid)) and not _index.has("%s:%s" % [speaker_of(pid), category]):
				continue   # the companion only takes the turn for a category he has lines for
			pool.append(pid)
	if pool.is_empty():
		return -1
	return pool[rng.randi_range(0, pool.size() - 1)]


## Plays an exchange record (lines.json "exchange" parts) now, each part positional at the player its speaker
## maps to in `pid_by_speaker` ({&"WRN": 3, &"JAK": 9}); a quiet two-person scene (Jakub and Wren, U02 section
## 6.2). Waits behind a story line like banter does. Returns true when it started or was queued.
func play_exchange(line_id: StringName, pid_by_speaker: Dictionary) -> bool:
	var rec: Dictionary = lines.get(String(line_id), {})
	if rec.is_empty() or not rec.has("exchange"):
		return false
	var item: Dictionary = {"id": line_id, "priority": Priority.EVENT, "speaker": StringName(rec["speaker"]), "pid": -1,
		"pid_by_speaker": pid_by_speaker, "sticky": true}
	return _place(GROUP_PLAYER, item)


## The survivor speaker id (DUT/PEG/DEA/WRN) of a player id.
func speaker_of(pid: int) -> StringName:
	var ch: StringName = Net.character_of(pid) if pid > 0 else GameState.character_id
	return CHARACTER_SPEAKERS.get(ch, &"DUT")


## Player ids of everyone on their feet (or at least in the match and not spectating).
func standing_pids() -> Array[int]:
	var out: Array[int] = []
	if not is_inside_tree():
		return out
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		if bool(n.get("spectating")) or bool(n.get("downed")):
			continue
		out.append(int(n.get("player_id")))
	if out.is_empty():
		out.append(_local_player())
	return out


func current_line(group: StringName) -> StringName:
	var cur: Dictionary = _current.get(group, {})
	return StringName(cur.get("id", ""))


## The speaker of the line playing in a group (&"" none).
func current_speaker(group: StringName) -> StringName:
	var cur: Dictionary = _current.get(group, {})
	return StringName(cur.get("speaker", ""))


func queued_count(group: StringName) -> int:
	return (_queue.get(group, []) as Array).size()


## Subtitle text: removes [direction tags], *emphasis* markers and {splice} braces.
static func strip_tags(text: String) -> String:
	var re: RegEx = RegEx.create_from_string("\\[[^\\]]*\\]")
	var out: String = re.sub(text, "", true)
	out = out.replace("{", "").replace("}", "").replace("*", "")
	var ws: RegEx = RegEx.create_from_string("\\s{2,}")
	out = ws.sub(out, " ", true)
	return out.strip_edges()


static func duration_for(text: String, rules_cfg: Dictionary) -> float:
	return maxf(float(rules_cfg.get("min_duration", 1.5)), float(text.length()) * float(rules_cfg.get("chars_per_second_inv", 0.065)))


## The audio file of a line (or of exchange part `part`), or "" when none is baked.
func audio_path(line_id: StringName, part: int = -1) -> String:
	var rec: Dictionary = lines.get(String(line_id), {})
	if rec.is_empty():
		return ""
	var speaker: String = str(rec["speaker"])
	var file_id: String = String(line_id)
	if rec.has("exchange") and part >= 0:
		var ex: Array = rec["exchange"]
		if part >= ex.size():
			return ""
		speaker = str((ex[part] as Array)[0])
		file_id = "%s_p%d" % [line_id, part]
	for ext: String in ["ogg", "wav"]:
		var path: String = "%s%s/%s.%s" % [AUDIO_DIR, speaker.to_lower(), file_id, ext]
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			return path
	return ""


## T-101: plays a recorded file for a line that lives outside lines.json (the Cousins' boss lines, data/gravelight/
## bosses/cousins.json), at gravelight/audio/vo/<speaker code>/<file_id>.ogg. Returns its length in seconds, or 0.0
## when there is no file (the caller then shows the subtitle silently, as before).
func play_external(file_id: String, speaker_code: String) -> float:
	var path: String = "%s%s/%s.ogg" % [AUDIO_DIR, speaker_code.to_lower(), file_id]
	if not (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
		_voice_test_log(file_id, speaker_code, "")
		return 0.0
	var stream: AudioStream = load_stream(path)
	if stream == null:
		return 0.0
	if _ext_2d == null:
		_ext_2d = AudioStreamPlayer.new()
		_ext_2d.name = "ExternalVoice"
		_ext_2d.bus = &"VO"
		add_child(_ext_2d)
	_ext_2d.stream = stream
	_ext_2d.volume_db = float((rules.get("audio", {}) as Dictionary).get("story_volume_db", 0.0))
	if is_inside_tree():
		_ext_2d.play()
	audio_plays += 1
	_voice_test_log(file_id, speaker_code, path)
	return stream.get_length()


## Voice test: where a line's audio comes from, from the manifest ("human <actor>", "tts", "none").
func source_of(file_id: String) -> String:
	if _vt_manifest.is_empty():
		_vt_manifest = (GLData.load_json("res://data/gravelight/vo/audio_manifest.json") as Dictionary).get("files", {})
	var row: Dictionary = _vt_manifest.get(file_id, {})
	if row.is_empty():
		return "none"
	var src: String = str(row.get("source", "tts"))
	return src + (" " + str(row["actor"]) if row.has("actor") else "")


func _voice_test_log(file_id: String, speaker: String, path: String) -> void:
	if not voice_test:
		return
	var src: String = source_of(file_id) if path != "" else "none"
	voice_log.append({"id": file_id, "speaker": speaker, "source": src, "path": path})
	print("[voice test] %-28s %-4s %s" % [file_id, speaker, src])


func _voice_test_round_end(round_number: int) -> void:
	if voice_test and round_number >= 3:
		print(voice_test_report())


## Writes the voice test summary (lines heard per source) to logs/voice_test.txt; returns the text.
func voice_test_report() -> String:
	var counts: Dictionary = {}
	for e: Dictionary in voice_log:
		var k: String = str(e["source"]).split(" ")[0]
		counts[k] = int(counts.get(k, 0)) + 1
	var out: String = "Voice test: %d lines started. By source: %s
" % [voice_log.size(), str(counts)]
	for e: Dictionary in voice_log:
		out += "%s	%s	%s
" % [e["id"], e["speaker"], e["source"]]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://logs"))
	var f: FileAccess = FileAccess.open("res://logs/voice_test.txt", FileAccess.WRITE)
	if f != null:
		f.store_string(out)
		f.close()
	return out


## Loads (and caches) a baked voice file; works with or without the editor import step.
func load_stream(path: String) -> AudioStream:
	if path == "":
		return null
	if _streams.has(path):
		return _streams[path]
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	if stream == null and FileAccess.file_exists(path):
		if path.ends_with(".ogg"):
			stream = AudioStreamOggVorbis.load_from_file(path)
		elif path.ends_with(".wav"):
			stream = AudioStreamWAV.load_from_file(path)
	_streams[path] = stream
	return stream


# ================================================================== core

func _group_for(speaker: StringName) -> StringName:
	if (rules.get("companion_speakers", []) as Array).has(String(speaker)):
		return GROUP_COMPANION
	if (rules.get("player_speakers", []) as Array).has(String(speaker)):
		return GROUP_PLAYER
	return GROUP_STORY


func _priority_for(speaker: StringName, category: String) -> int:
	var best_len: int = -1
	var prio: int = int((rules.get("speaker_default_priority", {}) as Dictionary).get(String(speaker), 1))
	var cp: Dictionary = rules.get("category_priority", {})
	var is_player: bool = _group_for(speaker) == GROUP_PLAYER
	if is_player and CHARACTER_SPEAKERS.values().has(speaker):
		# Downs and revives are tier 2 for the squad: they bypass the chatter gap and queue behind a story line
		# instead of being dropped (rules.json player_category_priority).
		var pp: Dictionary = rules.get("player_category_priority", {})
		if pp.has(category):
			return int(pp[category])
	for prefix: Variant in cp.keys():
		var p: String = str(prefix)
		if category.begins_with(p) and p.length() > best_len:
			# Story categories (power-ups, quests) don't raise player chatter above CHATTER.
			if is_player and int(cp[prefix]) > 1 and speaker != &"TAG":
				continue
			best_len = p.length()
			prio = int(cp[prefix])
	return prio


## Maps a speaker+category to its cooldown/chance rule key (longest matching prefix).
func _rule_key(speaker: StringName, category: String) -> String:
	if _group_for(speaker) == GROUP_PLAYER:
		if category.begins_with("PWR_"):
			return "%s:PWR_GRAB" % speaker
		if speaker == &"BNT":
			return "BNT"
	var best: String = ""
	for prefix: Variant in (rules.get("category_cooldown", {}) as Dictionary).keys():
		var p: String = str(prefix)
		if category.begins_with(p) and p.length() > best.length():
			best = p
	if best == "":
		best = category
	return "%s:%s" % [speaker, best]


## [cooldown, chance] for a rule key; squad / story overrides win over the shared table.
func _cooldown_rule(rule_key: String, speaker: StringName = &"") -> Array:
	var cat: String = rule_key.substr(rule_key.find(":") + 1) if rule_key.contains(":") else rule_key
	var cc: Dictionary = rules.get("category_cooldown", {})
	var over: Dictionary = {}
	if speaker != &"" and CHARACTER_SPEAKERS.values().has(speaker):
		over = rules.get("player_category_cooldown", {})
	elif speaker == &"OPR":
		over = rules.get("story_category_cooldown", {})
	if over.has(cat):
		return over[cat]
	if cc.has(cat):
		return cc[cat]
	return [0.0, 1.0]


## Shuffle-bag draw that skips lines whose conditions don't hold and once-per-match lines already used.
func _draw(key: String) -> StringName:
	var all_ids: Array = _index.get(key, [])
	var valid: Array = []
	for id: Variant in all_ids:
		if _condition_ok(StringName(id)) and not _played_once.has(id):
			valid.append(id)
	if valid.is_empty():
		return &""
	var bag: Array = _bags.get(key, [])
	bag = bag.filter(func(x: Variant) -> bool: return valid.has(x))
	if bag.is_empty():
		bag = valid.duplicate()
		for i: int in range(bag.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var tmp: Variant = bag[i]
			bag[i] = bag[j]
			bag[j] = tmp
		# A fresh bag never opens with the line that closed the last one (no back-to-back repeat at the seam).
		if bag.size() > 1 and bag.back() == _last_drawn.get(key, null):
			var first: Variant = bag[0]
			bag[0] = bag.back()
			bag[bag.size() - 1] = first
	var id_out: Variant = bag.pop_back()
	_bags[key] = bag
	_last_drawn[key] = id_out
	return StringName(str(id_out))


## The map a line belongs to ("map00", "map01", "map02"), or "" when it can play anywhere (T-057). A line is a
## map line when its category has an M0 / M1 / M2 token (POWER_ON_M0, M1_SWITCH, CUT_EXFIL_M0), its condition
## names a map ("Map 1, power on"), or rules.json "map_lines" lists it (lines that name a place, like the
## survivors' "Kaltenbrunn." spawn lines).
static func line_map_of(id: String, rec: Dictionary, rules_cfg: Dictionary) -> String:
	var listed: Dictionary = rules_cfg.get("map_lines", {})
	for m: Variant in listed.keys():
		if (listed[m] as Array).has(id):
			return str(m)
	for tok: String in str(rec.get("category", "")).split("_"):
		if tok.length() == 2 and tok[0] == "M" and tok[1] >= "0" and tok[1] <= "9":
			return "map0" + tok[1]
		if tok.length() == 3 and tok[0] == "M" and tok[1] >= "0" and tok[1] <= "9" and tok[2] >= "A" and tok[2] <= "D":
			return "map0" + tok[1] + tok[2].to_lower()   # Map 4's acts: M4A -> map04a (UPDATE 07)
	var re: RegEx = RegEx.create_from_string("\\bmap (\\d)\\b")
	var mt: RegExMatch = re.search(str(rec.get("condition", "")).to_lower())
	if mt != null:
		return "map0" + mt.get_string(1)
	return ""


## True when a line may play on the current map: an unmapped line anywhere, a map line only on its own map.
## (No map loaded, e.g. a unit test: everything may play.)
func map_ok(id: StringName) -> bool:
	var m: String = str(_line_map.get(String(id), ""))
	var here: String = String(GameState.map_id)
	return m == "" or here == "" or here.begins_with(m)


## Conditions written in the docs: "round 5", "round 8+", "Map 1, power on". Triggers like
## "round 2 start" are matched by their own handlers, so they're ignored here. A line for another map never
## passes (map_ok).
func _condition_ok(id: StringName) -> bool:
	if not map_ok(id):
		return false
	var cond: String = str((lines.get(String(id), {}) as Dictionary).get("condition", "")).to_lower()
	if cond == "":
		return true
	if cond.contains("power on") and not GameState.power_on:
		return false
	var re: RegEx = RegEx.create_from_string("^round (\\d+)(\\+?)$")
	var m: RegExMatch = re.search(cond.strip_edges())
	if m != null:
		var n: int = int(m.get_string(1))
		if m.get_string(2) == "+":
			return RoundManager.current_round >= n
		return RoundManager.current_round == n
	return true


func _submit(id: StringName, prio: int, pid: int = -1) -> bool:
	var rec: Dictionary = lines.get(String(id), {})
	if rec.is_empty():
		return false
	var speaker: StringName = StringName(rec["speaker"])
	var group: StringName = _group_for(speaker)
	var category: String = str(rec["category"])
	if group == GROUP_PLAYER and (rules.get("squad_second_channel", []) as Array).has(category):
		group = GROUP_SQUAD
	# Chatter limiters.
	if group == GROUP_PLAYER and prio <= Priority.CHATTER:
		if _now - _last_chatter < float(rules.get("player_chatter_gap", 3.5)):
			return false
		var story: Dictionary = _current[GROUP_STORY]
		if not story.is_empty():
			return false   # ducked: story line playing
	if prio == Priority.AMBIENT and _now - _last_ambient < float(rules.get("ambient_gap", 45.0)):
		return false
	var item: Dictionary = {"id": id, "priority": prio, "speaker": speaker, "pid": pid}
	# Tier-2 squad lines (downs, revives) are never dropped from a queue: they wait their turn.
	item["sticky"] = group != GROUP_STORY and prio >= Priority.EVENT
	if category == "REVIVE" and pid > 0:
		_revive_line_t[pid] = _now
	return _place(group, item)


## Starts the item now, cuts what plays when it may, or queues it. Returns true if it will be heard.
func _place(group: StringName, item: Dictionary) -> bool:
	var prio: int = int(item["priority"])
	var cur: Dictionary = _current[group]
	if cur.is_empty() and (_queue[group] as Array).is_empty():
		_start(group, item)
		return true
	if not cur.is_empty() and _can_interrupt(prio, int(cur["priority"]), group):
		if int(cur["priority"]) >= Priority.ANNOUNCE:
			_enqueue(group, {"id": cur["id"], "priority": cur["priority"], "speaker": cur["speaker"], "pid": cur.get("pid", -1)}, true)
		_start(group, item)
		return true
	_enqueue(group, item, false)
	if cur.is_empty():
		_pop_start(group)   # the head may be a timed item that isn't due yet
	return true


func _can_interrupt(new_prio: int, cur_prio: int, group: StringName = GROUP_STORY) -> bool:
	match new_prio:
		Priority.CRITICAL:
			return cur_prio < Priority.CRITICAL
		Priority.ANNOUNCE:
			return cur_prio <= Priority.CHATTER
		Priority.EVENT:
			# In the squad channels a down or a revive cuts a quip; story events only cut ambient musings.
			return cur_prio <= (Priority.CHATTER if group != GROUP_STORY else Priority.AMBIENT)
	return false


func _enqueue(group: StringName, item: Dictionary, front: bool) -> void:
	var expiry: float = float((rules.get("queue_expiry", {}) as Dictionary).get(str(item["priority"]), 4.0))
	item["expires"] = INF if expiry < 0.0 or bool(item.get("sticky", false)) else _now + expiry
	if front:
		(_queue[group] as Array).push_front(item)
	else:
		(_queue[group] as Array).push_back(item)


## Starts the next due item of an idle channel (expired ones are dropped; a timed item waits for its moment).
func _pop_start(group: StringName) -> void:
	if not _current[group].is_empty():
		return
	var q: Array = _queue[group]
	while not q.is_empty():
		var nxt: Dictionary = q[0]
		if float(nxt.get("expires", INF)) < _now:
			q.pop_front()
			continue
		if _now < float(nxt.get("not_before", -INF)):
			return
		q.pop_front()
		if nxt.has("resolve") and not _resolve_item(nxt):
			continue
		_start(group, nxt)
		return
	if group == GROUP_STORY:
		_set_duck(false)


## A queued TEAM_DOWN picks its speaker when it actually starts: someone standing, never the downed player,
## never whoever is (or has said they are, or the bot squad has picked to be) reviving them. False when nobody fits.
func _resolve_item(item: Dictionary) -> bool:
	var r: Dictionary = item["resolve"]
	var category: String = str(r["category"])
	var exclude: Array = (r.get("exclude", []) as Array).duplicate()
	var downed: int = int(r.get("downed", -1))
	if downed > 0 and Net.session != null and Net.session.get("coop") != null:
		exclude.append(int(Net.session.coop.reviver_of(downed)))
	# A bot squad names its reviver (blackboard claim "revive:<pid>") within a moment of the down, long before
	# that bot gets there and starts the hold (when coop.reviver_of and its REVIVE line would show it).
	if downed > 0 and is_inside_tree():
		for sq: Node in get_tree().get_nodes_in_group(&"bot_squad"):
			var bb: BotBlackboard = sq.get("blackboard") as BotBlackboard
			if bb != null:
				exclude.append_array((bb.claims.get("revive:%d" % downed, {}) as Dictionary).get("pids", []))
	for g: StringName in [GROUP_SQUAD, GROUP_PLAYER]:
		var cur: Dictionary = _current[g]
		if not cur.is_empty() and _is_category(StringName(cur["id"]), "REVIVE"):
			exclude.append(int(cur.get("pid", -1)))
		for qi: Variant in _queue[g]:
			if (qi as Dictionary).has("id") and _is_category(StringName((qi as Dictionary)["id"]), "REVIVE"):
				exclude.append(int((qi as Dictionary).get("pid", -1)))
	for pid: int in _revive_line_t.keys():
		if _now - float(_revive_line_t[pid]) < 12.0:
			exclude.append(pid)
	var pool: Array[int] = []
	for pid: int in standing_pids():
		# (only someone with lines for it: a companion without TEAM_DOWN lines would drop the whole line)
		if not exclude.has(pid) and _index.has("%s:%s" % [speaker_of(pid), category]):
			pool.append(pid)
	if pool.is_empty():
		return false
	var pid_out: int = pool[rng.randi_range(0, pool.size() - 1)]
	var spk: StringName = speaker_of(pid_out)
	var id: StringName = _draw("%s:%s" % [spk, category])
	if id == &"":
		return false
	item["id"] = id
	item["speaker"] = spk
	item["pid"] = pid_out
	item.erase("resolve")
	return true


func _is_category(id: StringName, category: String) -> bool:
	return str((lines.get(String(id), {}) as Dictionary).get("category", "")) == category


func _start(group: StringName, item: Dictionary) -> void:
	var id: StringName = item["id"]
	var rec: Dictionary = lines[String(id)]
	var parts: Array = []
	var part_pids: Array[int] = []
	if rec.has("exchange"):
		var by_speaker: Dictionary = item.get("pid_by_speaker", {})
		for p: Variant in rec["exchange"]:
			var spk: StringName = StringName(str((p as Array)[0]))
			parts.append([spk, str((p as Array)[1])])
			part_pids.append(int(by_speaker.get(spk, -1)))
	else:
		parts.append([StringName(rec["speaker"]), str(rec["text"])])
		part_pids.append(int(item.get("pid", -1)))
	item["parts"] = parts
	item["part_pids"] = part_pids
	item["part"] = -1
	item["end"] = _now
	_stop_audio(group)
	_current[group] = item
	if bool((lines.get(String(id), {}) as Dictionary).get("once_per_match", false)) or StringName(rec["speaker"]) in [&"BNT", &"TAG"]:
		_played_once[String(id)] = true
	if group == GROUP_PLAYER and int(item["priority"]) <= Priority.CHATTER:
		_last_chatter = _now
	if int(item["priority"]) == Priority.AMBIENT:
		_last_ambient = _now
	var fk: String = "%s:%s" % [rec["speaker"], rec["category"]]
	fired[fk] = int(fired.get(fk, 0)) + 1
	_next_part(group)
	if group == GROUP_STORY:
		_set_duck(true)
		_audio_stop_player_chatter()


func _next_part(group: StringName) -> void:
	var item: Dictionary = _current[group]
	item["part"] = int(item["part"]) + 1
	var parts: Array = item["parts"]
	if int(item["part"]) >= parts.size():
		_finish(group)
		return
	var part: Array = parts[int(item["part"])]
	var speaker: StringName = part[0]
	var text: String = strip_tags(str(part[1]))
	var dur: float = duration_for(text, rules)
	var pid: int = (item["part_pids"] as Array)[int(item["part"])]
	var path: String = audio_path(item["id"], int(item["part"]) if parts.size() > 1 else -1)
	var stream: AudioStream = load_stream(path)
	if voice_test:
		_voice_test_log(String(item["id"]) + ("_p%d" % int(item["part"]) if parts.size() > 1 else ""), String(speaker), path if stream != null else "")
	if stream != null:
		var len_s: float = stream.get_length()
		if len_s > 0.05:
			dur = len_s
		_play_stream(group, stream, pid)
	var gap: float = float(rules.get("exchange_gap", 0.4)) if int(item["part"]) < parts.size() - 1 else 0.0
	item["end"] = _now + dur + gap
	GLBus.vo_line_started.emit(item["id"], speaker, text, dur)


## Story and local-player lines are 2D; another survivor's line plays at their body (3D).
func _play_stream(group: StringName, stream: AudioStream, pid: int) -> void:
	var au: Dictionary = rules.get("audio", {})
	var p2d: AudioStreamPlayer = _story_2d if group == GROUP_STORY else (_squad_2d if group == GROUP_SQUAD else (_comp_2d if group == GROUP_COMPANION else _player_2d))
	var p3d: AudioStreamPlayer3D = null if group == GROUP_STORY else (_squad_3d if group == GROUP_SQUAD else (_comp_3d if group == GROUP_COMPANION else _player_3d))
	var node: Node3D = _player_node(pid) if p3d != null and pid > 0 and pid != _local_player() else null
	if node != null:
		p2d.stop()
		p3d.stop()
		p3d.stream = stream
		p3d.global_position = _voice_pos(node)
		set_occlusion(p3d, _occlusion_target(p3d))   # sets volume_db too (squad_volume_db + the occlusion dip)
		p3d.play()
		if group == GROUP_SQUAD:
			_follow_b = node
		elif group == GROUP_COMPANION:
			_follow_c = node
		else:
			_follow = node
		audio_plays += 1
		audio_plays_3d += 1
		return
	if p3d != null:
		p3d.stop()
		if group == GROUP_SQUAD:
			_follow_b = null
		elif group == GROUP_COMPANION:
			_follow_c = null
		else:
			_follow = null
	p2d.stop()
	p2d.stream = stream
	p2d.volume_db = float(au.get("story_volume_db", 0.0)) if group == GROUP_STORY else float(au.get("squad_volume_db", 0.0))
	p2d.play()
	audio_plays += 1


func _stop_audio(group: StringName) -> void:
	if group == GROUP_STORY:
		if _story_2d != null:
			_story_2d.stop()
	elif group == GROUP_SQUAD:
		if _squad_2d != null:
			_squad_2d.stop()
		if _squad_3d != null:
			_squad_3d.stop()
		_follow_b = null
	elif group == GROUP_COMPANION:
		if _comp_2d != null:
			_comp_2d.stop()
		if _comp_3d != null:
			_comp_3d.stop()
		_follow_c = null
	else:
		if _player_2d != null:
			_player_2d.stop()
		if _player_3d != null:
			_player_3d.stop()
		_follow = null


func _voice_pos(node: Node3D) -> Vector3:
	return node.global_position + Vector3.UP * (1.0 if bool(node.get("downed")) else 1.6)


func _player_node(pid: int) -> Node3D:
	if not is_inside_tree():
		return null
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		if n is Node3D and int(n.get("player_id")) == pid and (n as Node3D).is_inside_tree():
			return n as Node3D
	for c: Node in get_tree().get_nodes_in_group(&"companions"):
		if c is Node3D and int(c.get("player_id")) == pid and (c as Node3D).is_inside_tree():
			return c as Node3D   # Jakub calling from his cage before he joins (positional, U02 section 6.2)
	return null


func _finish(group: StringName) -> void:
	var done: Dictionary = _current[group]
	_current[group] = {}
	_stop_audio(group)
	if not done.is_empty() and StringName(done.get("speaker", &"")) == &"OPR" and not String(done["id"]).begins_with("op.slip") \
			and int(done.get("priority", 0)) in [Priority.EVENT, Priority.ANNOUNCE] and _slip_pending_at == INF:
		if _slip_roll(slip_chance()):
			_slip_pending_at = _now + float(rules.get("slip_tail_delay_s", 0.6))
	_pop_start(group)


func _audio_stop_player_chatter() -> void:
	var cur: Dictionary = _current[GROUP_PLAYER]
	if not cur.is_empty() and int(cur["priority"]) <= Priority.CHATTER:
		_current[GROUP_PLAYER] = {}
		_stop_audio(GROUP_PLAYER)


## Music, jingles and (through the AudioDirector) the ambience bed and score duck under story lines.
func _set_duck(on: bool) -> void:
	if on == _duck_on:
		return
	_duck_on = on
	var au: Dictionary = rules.get("audio", {})
	var idx: int = AudioServer.get_bus_index(&"Music")
	if idx >= 0:
		var base: float = linear_to_db(maxf(0.0001, GLSettings.get_f("vol_music")))
		AudioServer.set_bus_volume_db(idx, base + (float(au.get("duck_music_db", -6.0)) if on else 0.0))
	var j: int = AudioServer.get_bus_index(&"Jingles")
	if j >= 0:
		var jb: float = linear_to_db(maxf(0.0001, GLSettings.get_f("vol_jingles")))
		AudioServer.set_bus_volume_db(j, jb + (float(au.get("duck_jingles_db", -9.0)) if on else 0.0))
	if has_node("/root/AudioDirector") and AudioDirector.has_method("set_vo_duck"):
		AudioDirector.set_vo_duck(on, float(au.get("duck_ambience_db", -5.0)))


## Advances the clock; tests call this directly.
func advance(delta: float) -> void:
	_now += delta
	for g: Variant in _current.keys():
		var cur: Dictionary = _current[g]
		if not cur.is_empty() and _now >= float(cur["end"]):
			_next_part(StringName(g))
	if _follow != null and is_instance_valid(_follow) and _follow.is_inside_tree() and _player_3d.playing:
		_player_3d.global_position = _voice_pos(_follow)
	if _follow_b != null and is_instance_valid(_follow_b) and _follow_b.is_inside_tree() and _squad_3d.playing:
		_squad_3d.global_position = _voice_pos(_follow_b)
	if _follow_c != null and is_instance_valid(_follow_c) and _follow_c.is_inside_tree() and _comp_3d.playing:
		_comp_3d.global_position = _voice_pos(_follow_c)
	for g: Variant in _queue.keys():
		_pop_start(StringName(g))   # timed items (TEAM_DOWN's beat after the DOWN) start when due
	_tick_delayed()
	_tick_banter()
	_tick_idle(delta)
	if _now >= _slip_pending_at:
		_slip_pending_at = INF
		play_slip()


func _process(delta: float) -> void:
	advance(delta)


## Cheap occlusion (T-073, rules.json audio "occlusion_*"): a few times a second, while a bot's (or another
## player's, or Jakub's) line plays at their body, one ray from the camera to their head against the world and
## doors. Blocked: the voice slides to a low-pass and a few dB down, as if heard through the wall; clear: back.
func _physics_process(delta: float) -> void:
	_occl_t -= delta
	if _occl_t > 0.0:
		return
	var au: Dictionary = rules.get("audio", {})
	_occl_t = float(au.get("occlusion_interval_s", 0.12))
	for p3: AudioStreamPlayer3D in [_player_3d, _squad_3d, _comp_3d]:
		if p3 == null or not p3.playing:
			continue
		set_occlusion(p3, lerpf(float(_occl.get(p3, 0.0)), _occlusion_target(p3), float(au.get("occlusion_smooth", 0.5))))


## 1.0 when the world or a door stands between the camera and the voice, else 0.0 (no camera: 0.0).
func _occlusion_target(p3: AudioStreamPlayer3D) -> float:
	if not is_inside_tree() or not p3.is_inside_tree():
		return 0.0
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null or not cam.is_inside_tree():
		return 0.0
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, p3.global_position,
		int((rules.get("audio", {}) as Dictionary).get("occlusion_mask", 257)))
	return 0.0 if cam.get_world_3d().direct_space_state.intersect_ray(q).is_empty() else 1.0


## Applies an occlusion amount (0 clear .. 1 behind a wall) to a positional voice player.
func set_occlusion(p3: AudioStreamPlayer3D, amount: float) -> void:
	var au: Dictionary = rules.get("audio", {})
	_occl[p3] = amount
	var open_hz: float = float(au.get("occlusion_open_hz", 5000.0))
	var shut_hz: float = float(au.get("occlusion_cutoff_hz", 1100.0))
	p3.attenuation_filter_cutoff_hz = lerpf(open_hz, shut_hz, amount)
	p3.volume_db = float(au.get("squad_volume_db", 0.0)) + float(au.get("occlusion_db", -5.0)) * amount


## How occluded a positional voice is right now (0..1; tests / dev overlay).
func occlusion_of(p3: AudioStreamPlayer3D) -> float:
	return float(_occl.get(p3, 0.0))


## Squad reactions a beat after the event (so they don't collide with the Operator's announcement).
func _later(seconds: float, pid: int, category: String, chance: float = -1.0) -> void:
	_delayed.append({"at": _now + seconds, "pid": pid, "cat": category, "chance": chance})


func _tick_delayed() -> void:
	if _delayed.is_empty():
		return
	var keep: Array[Dictionary] = []
	for d: Dictionary in _delayed:
		if _now < float(d["at"]):
			keep.append(d)
			continue
		var pid: int = int(d["pid"])
		# A story beat (say_story_beat) waits for the radio / the Operator however long they talk, then goes.
		if bool(d.get("after_story", false)) and not _current[GROUP_STORY].is_empty():
			if _now < float(d.get("drop_at", INF)):
				keep.append(d)
			continue
		# Chatter waits for the announcer (or the radio), up to 10 s; tier-2 squad lines (TEAM_DOWN...) queue at once.
		var tier2: bool = int((rules.get("player_category_priority", {}) as Dictionary).get(str(d["cat"]), 1)) >= Priority.EVENT
		if not tier2 and not _current[GROUP_STORY].is_empty() and _now < float(d["at"]) + 10.0:
			keep.append(d)
			continue
		if d.has("speaker"):   # a story speaker's line (T-137: the Operator's and Fasbender's Marke remarks)
			play_category(StringName(str(d["speaker"])), str(d["cat"]), float(d["chance"]))
		elif pid == 0:
			squad_say(str(d["cat"]), float(d["chance"]))
		else:
			say_as(pid, str(d["cat"]), float(d["chance"]))
	_delayed = keep


## A story speaker's category line `seconds` from now (the Operator, Fasbender): the same delayed tick as the
## squad's `_later`, so a test's advance() reaches it.
func _later_story(seconds: float, speaker: StringName, category: String, chance: float = -1.0) -> void:
	_delayed.append({"at": _now + seconds, "pid": -1, "speaker": String(speaker), "cat": category, "chance": chance})


# ================================================================== triggers (VO_SCRIPT §2)

func _connect_triggers() -> void:
	GLBus.match_started.connect(_on_match_started)
	GLBus.round_started.connect(_on_round_started)
	GLBus.round_ended.connect(_on_round_ended)
	GLBus.game_over.connect(_on_game_over)
	GLBus.powerup_collected.connect(_on_powerup_collected)
	GLBus.special_round_warning.connect(_on_special_warning)
	GLBus.boss_spawned.connect(_on_boss_spawned)
	GLBus.powerup_expired.connect(_on_powerup_expired)
	GLBus.crate_drummer.connect(_on_crate_drummer)
	GLBus.crate_moved.connect(_on_crate_moved)
	GLBus.crate_result.connect(_on_crate_result)
	GLBus.perk_bought.connect(_on_perk_bought)
	GLBus.perk_denied.connect(_on_perk_denied)
	GLBus.weapon_acquired.connect(_on_weapon_acquired)
	GLBus.ammo_bought.connect(_on_ammo_bought)
	GLBus.enemy_killed.connect(_on_enemy_killed)
	GLBus.low_ammo.connect(_on_low_ammo)
	GLBus.no_ammo.connect(_on_no_ammo)
	GLBus.player_downed.connect(_on_player_downed)
	GLBus.player_revived.connect(_on_player_revived)
	GLBus.self_revive.connect(_on_self_revive)
	GLBus.door_opened.connect(_on_door_opened)
	GLBus.zone_opened.connect(_on_zone_opened)
	GLBus.power_activated.connect(_on_power_activated)
	GLBus.radio_tuned.connect(_on_radio_tuned)
	GLBus.trap_activated.connect(_on_trap_activated)
	GLBus.intel_found.connect(_on_intel_found)
	if GLBus.has_signal(&"marke_kill"):
		GLBus.marke_kill.connect(_on_marke_kill)
	if GLBus.has_signal(&"crucible_started"):
		GLBus.crucible_started.connect(_on_crucible_started)
		GLBus.crucible_ready.connect(func(_w: StringName) -> void: _opr("CRUCIBLE_READY"))
		GLBus.crucible_expired.connect(func(_w: StringName) -> void: _opr("CRUCIBLE_EXPIRE"))


func _local_player() -> int:
	return Net.local_player_id()


func _on_map0() -> bool:
	return String(GameState.map_id).begins_with("map00")


## Prefers a Map 0 variant ("<CAT>_M0") on Map 0 when one exists.
func _opr(category: String, chance: float = -1.0) -> bool:
	if _on_map0() and _index.has("OPR:%s_M0" % category):
		return play_category(&"OPR", category + "_M0", chance)
	return play_category(&"OPR", category, chance)


func _on_match_started(_map_id: StringName) -> void:
	reset_match()
	_opr("MATCH_START", 1.0)
	if GLBus.round_started.is_connected(_spawn_lines_after_opening):
		GLBus.round_started.disconnect(_spawn_lines_after_opening)   # (a match quit before its round 1)
	# Map 0's round 1 opening (T-076): the patrons talk while the player looks round, so the squad's spawn lines
	# wait until round 1 starts instead of talking over them.
	if _map_id == &"map00_crossroads" and not Campaign.arriving(_map_id):
		if not GLBus.round_started.is_connected(_spawn_lines_after_opening):
			GLBus.round_started.connect(_spawn_lines_after_opening, CONNECT_ONE_SHOT)
		return
	_spawn_lines()


func _spawn_lines_after_opening(_r: int, _special: bool) -> void:
	_spawn_lines()


## The squad settles in: the local survivor first, then the others one at a time.
func _spawn_lines() -> void:
	_later(3.0, _local_player(), "SPAWN")
	var i: int = 0
	for pid: int in standing_pids():
		if pid != _local_player():
			i += 1
			_later(3.0 + 5.0 * i, pid, "SPAWN")


func _on_round_started(round_number: int, is_special: bool) -> void:
	_idle_t = 0.0
	_last_special = is_special
	if is_special:
		_opr("SPECIAL_START", 1.0)
		_later(4.0, 0, "BELL")
		return
	var always: Array = rules.get("round_start_always", [])
	var chance: float = 1.0 if always.has(round_number) else -1.0
	# A line written for exactly this round wins when it exists.
	if not _play_conditioned(&"OPR", "ROUND_START", round_number, chance):
		_opr("ROUND_START", chance)
	if _on_map0():
		_play_radio_round(round_number, "start")
	if round_number >= 50:
		_later(4.0, 0, "EXHAUST", 0.3)
	else:
		_later(4.0, 0, "ROUND_START")


func _on_round_ended(round_number: int) -> void:
	if _last_special:
		_opr("SPECIAL_END", 1.0)
	elif not _play_conditioned(&"OPR", "ROUND_END", round_number, 1.0):
		_opr("ROUND_END")
	if _on_map0():
		_play_radio_round(round_number, "end")
	_later(3.0, 0, "ROUND_END")
	var b: Dictionary = rules.get("banter", {})
	if round_number >= int(b.get("min_round", 2)):
		_banter_at = _now + float(b.get("delay_s", 2.5)) + 3.0


func _on_special_warning(_kind: StringName) -> void:
	play_category(&"OPR", "SPECIAL_WARN", 1.0)
	_later(3.5, 0, "BELL")


func _on_boss_spawned(enemy_id: StringName) -> void:
	play_category(&"OPR", "BOSS_" + String(enemy_id).to_upper(), 1.0)
	var token: String = str(BOSS_TOKENS.get(enemy_id, String(enemy_id).to_upper()))
	_later(3.5, 0, token)


func _play_conditioned(speaker: StringName, category: String, round_number: int, chance: float) -> bool:
	for id: Variant in _index.get("%s:%s" % [speaker, category], []):
		var cond: String = str((lines[String(id)] as Dictionary).get("condition", "")).to_lower().strip_edges()
		if cond == "round %d" % round_number and map_ok(StringName(id)):
			if chance < 1.0 and not always_pass_chance and rng.randf() > maxf(chance, 0.35):
				return true
			return play_local(StringName(id))
	return false


## Map 0: Fasbender's radio contact lines fire on their scheduled round start/end, once each.
func _play_radio_round(round_number: int, when: String) -> void:
	var want: String = "round %d %s" % [round_number, when]
	for id: Variant in lines.keys():
		var rec: Dictionary = lines[id]
		if rec["speaker"] == "FAS" and str(rec.get("condition", "")).to_lower().strip_edges() == want and not _played_once.has(str(id)):
			_played_once[str(id)] = true
			play_local(StringName(str(id)))


func _on_game_over(_stats: Dictionary) -> void:
	stop_all()
	_delayed.clear()
	_banter_at = INF
	_opr("GAME_OVER", 1.0)


func _on_powerup_collected(powerup_id: StringName, by_player: int) -> void:
	var token: String = str(POWERUP_TOKENS.get(powerup_id, String(powerup_id).to_upper().replace("_", "")))
	_opr("PWR_" + token, 1.0)
	if by_player > 0:
		_later(2.5, by_player, "PWR_" + token)


func _on_powerup_expired(powerup_id: StringName) -> void:
	if powerup_id == &"deaths_door" or powerup_id == &"double_scrip":
		_opr("PWR_EXPIRE")


func _on_crate_drummer(_location: int) -> void:
	_opr("CRATE_MOVE", 1.0)
	_later(2.0, _local_player(), "CRATE_DRUMMER")


func _on_crate_moved(_location: int) -> void:
	_opr("CRATE_MOVE_ARRIVE", 0.25)


func _on_crate_result(player: int, _weapon_id: StringName, quality: StringName) -> void:
	match quality:
		&"good":
			say_as(player, "CRATE_GOOD")
		&"bad":
			say_as(player, "CRATE_BAD")
		&"wonder":
			if not say_as(player, "CRATE_WONDER", 1.0):
				say_as(player, "BUY_WONDER", 1.0)


func _on_perk_bought(player: int, perk_id: StringName) -> void:
	if PERK_TOKENS.has(perk_id):
		say_as(player, "PERK_" + str(PERK_TOKENS[perk_id]), 1.0)


func _on_perk_denied(player: int, _perk_id: StringName, reason: StringName) -> void:
	say_as(player, "DENY_" + String(reason).to_upper())


func _on_weapon_acquired(player: int, weapon_id: StringName, source: StringName) -> void:
	if source == &"crucible":
		say_as(player, "CRUCIBLE")
		return
	if source != &"wall":
		return
	var w: Dictionary = GLData.table("weapons")
	var row: Dictionary = (w.get("weapons", {}) as Dictionary).get(String(weapon_id), {})
	if row.is_empty():
		row = (w.get("melee", {}) as Dictionary).get(String(weapon_id), {})
		if not row.is_empty():
			row = {"class": "melee"}
	var cls: StringName = StringName(str(row.get("class", "rifle")))
	say_as(player, "BUY_" + str(CLASS_TOKENS.get(cls, "RIFLE")))


func _on_ammo_bought(player: int, _weapon_id: StringName) -> void:
	say_as(player, "BUY_AMMO")


func _on_enemy_killed(enemy_id: StringName, limb: StringName, _weapon_id: StringName, by_player: int) -> void:
	if by_player <= 0:
		return
	if enemy_id == &"foreman":
		play_category(&"OPR", "BOSS_FOREMAN_DEAD", 1.0)
	if enemy_id == &"glasshide":
		say_as(by_player, "GLASSHIDE")
	# Bots call their own rarer headshot lines from BotBrain (bots.json callouts); humans roll here.
	if GameState.is_bot(by_player):
		return
	if by_player != _local_player() and not Net.is_online():
		return
	_streak_times.append(_now)
	while not _streak_times.is_empty() and _now - _streak_times[0] > 3.0:
		_streak_times.pop_front()
	if _streak_times.size() >= 5:
		_streak_times.clear()
		if say_as(by_player, "STREAK"):
			return
	if limb == &"head":
		say_as(by_player, "HEADSHOT")


func _on_low_ammo(player: int, _weapon_id: StringName) -> void:
	say_as(player, "AMMO_LOW")


func _on_no_ammo(player: int, _weapon_id: StringName) -> void:
	say_as(player, "AMMO_NONE")


## The down sequence (deterministic): the downed player's DOWN at once on the player channel; TEAM_DOWN on the
## second squad channel a beat later, its speaker chosen when it starts (never the downed one or the reviver),
## dropped only if nobody else is standing or the moment has passed (down_sequence.team_down_window_s); the
## reviver's REVIVE queues behind it on the same channel, never displacing it, never dropped; REVIVED comes
## back on the player channel when the revive lands, overlapping whatever the others are still saying.
func _on_player_downed(player: int) -> void:
	_last_down_at = _now
	say_as(player, "DOWN", 1.0)
	_opr("DOWNED")
	var ds: Dictionary = rules.get("down_sequence", {})
	var item: Dictionary = {"id": &"", "priority": Priority.EVENT, "speaker": &"", "pid": -1, "sticky": true,
		"not_before": _now + float(ds.get("team_down_delay_s", 1.0)),
		"resolve": {"category": "TEAM_DOWN", "downed": player, "exclude": [player]}}
	_enqueue(GROUP_SQUAD, item, false)
	item["expires"] = _now + float(ds.get("team_down_window_s", 8.0))
	_pop_start(GROUP_SQUAD)


func _on_player_revived(player: int, by_player: int) -> void:
	if by_player == player:
		return
	# The reviver's REVIVE normally plays when the revive starts (BotBrain's callout, or a human's hold); if it
	# never got out (callout cooldown, chance), it goes now, just ahead of the thanks.
	var ds: Dictionary = rules.get("down_sequence", {})
	if by_player > 0 and _now - float(_revive_line_t.get(by_player, -INF)) > float(ds.get("revive_fallback_s", 12.0)):
		say_as(by_player, "REVIVE", 1.0)
	say_as(player, "REVIVED", 1.0)


func _on_self_revive(_player: int, uses_left: int) -> void:
	play_category(&"OPR", "SECOND_WIND_%d" % uses_left, 1.0)


func _on_door_opened(_door_id: StringName, by_player: int) -> void:
	say_as(by_player, "DOOR")


func _on_zone_opened(zone_id: StringName) -> void:
	say_player("ZONE_" + String(zone_id).to_upper())


func _on_power_activated() -> void:
	# A map that starts powered emits this right after match_started: no announcement then.
	if _now - _match_t < 2.0:
		return
	_opr("POWER_ON", 1.0)
	_later(3.5, 0, "POWER", 1.0)


func _on_trap_activated(_trap_id: StringName, by_player: int) -> void:
	_opr("TRAP")
	say_as(by_player, "TRAP")


func _on_intel_found(_intel_id: StringName) -> void:
	say_player("INTEL")


## T-137: a kill from a hit on the Marke. The first of the match is a story beat: the killer (or a survivor who
## has the line) names the mark, the Operator calls it a valued customer retained, and where Fasbender has a radio
## he explains the carrier a little later. After that the squad's MARKE_KILL lines roll on their cooldown, with the
## Operator's rarer remark.
func _on_marke_kill(by_player: int, _enemy_id: StringName) -> void:
	if by_player <= 0:
		return
	if not _marke_first:
		_marke_first = true
		var pid: int = by_player if _index.has("%s:MARKE_FIRST" % speaker_of(by_player)) else -1
		say_story_beat(pid, "MARKE_FIRST", 0.6)
		_later_story(6.0, &"OPR", "MARKE_OPR", 1.0)
		if _index.has("FAS:MARKE_RELAY"):
			_later_story(18.0, &"FAS", "MARKE_RELAY", 1.0)
		return
	if GameState.is_bot(by_player) or (by_player != _local_player() and not Net.is_online()):
		return
	say_as(by_player, "MARKE_KILL")
	_opr("MARKE_OPR")


func _on_crucible_started(_player: int, _weapon_id: StringName) -> void:
	if not _crucible_first:
		_crucible_first = true
		if _opr("CRUCIBLE_FIRST", 1.0):
			return
	_opr("CRUCIBLE_START")


func _on_radio_tuned(freq_index: int) -> void:
	# freq_index: 1..3 = correct frequency in order; 0 = wrong frequency.
	if freq_index <= 0:
		play_category(&"OPR", "M0_WRONG", 1.0)
		return
	play_category(&"FAS", "M0_FREQ%d" % freq_index, 1.0)
	if freq_index == 3 and GameState.character_id == &"peg":
		play_local(&"FAS_M0_FREQ_DONE_PEG")


# ================================================================== round-break banter (CHARACTERS.md Banter)

## The exchange starts once the Operator (and the radio) are quiet; it may run into the first seconds of the next
## round (the zombies are still walking in), but gives up 20 s after it was due.
func _tick_banter() -> void:
	if _now < _banter_at:
		return
	if not _current[GROUP_STORY].is_empty():
		if _now > _banter_at + 20.0:
			_banter_at = INF
		return
	_banter_at = INF
	try_banter()


## Rolls a pair exchange between two standing survivors with different characters, once per exchange per
## match, with the chance / cooldown / distance from rules.json "banter". Returns true when one started.
func try_banter(force: bool = false) -> bool:
	var b: Dictionary = rules.get("banter", {})
	if GameState.phase != GameState.Phase.PLAYING:
		return false
	if not force:
		if _now - _banter_last < float(b.get("cooldown_s", 180.0)):
			return false
		if RoundManager.state == RoundManager.State.BREAK and RoundManager.break_left < 1.5:
			return false   # the round stinger is about to play over it
		if not always_pass_chance and rng.randf() > float(b.get("chance", 0.3)):
			return false
	var pids: Array[int] = standing_pids()
	var nodes: Dictionary = {}
	for pid: int in pids:
		nodes[pid] = _player_node(pid)
	var max_d: float = float(b.get("max_distance_m", 15.0))
	var pairs: Array = []
	for i: int in pids.size():
		for j: int in range(i + 1, pids.size()):
			var a: int = pids[i]
			var c: int = pids[j]
			if speaker_of(a) == speaker_of(c):
				continue
			var na: Node3D = nodes[a]
			var nc: Node3D = nodes[c]
			if max_d > 0.0 and na != null and nc != null and na.global_position.distance_to(nc.global_position) > max_d:
				continue
			pairs.append([a, c])
	pairs.shuffle()
	for pair: Variant in pairs:
		var a: int = (pair as Array)[0]
		var c: int = (pair as Array)[1]
		var sa: StringName = speaker_of(a)
		var sc: StringName = speaker_of(c)
		for cat: String in ["%s_%s" % [sa, sc], "%s_%s" % [sc, sa]]:
			var key: String = "BNT:%s" % cat
			if not _index.has(key):
				continue
			var id: StringName = _draw(key)
			if id == &"":
				continue
			var item: Dictionary = {"id": id, "priority": _priority_for(&"BNT", cat), "speaker": &"BNT", "pid": -1,
				"pid_by_speaker": {sa: a, sc: c}}
			if _now - _last_ambient < float(rules.get("ambient_gap", 45.0)) and not force:
				return false
			var cur: Dictionary = _current[GROUP_PLAYER]
			if not cur.is_empty() and int(cur["priority"]) > Priority.CHATTER:
				return false
			_start(GROUP_PLAYER, item)
			_banter_last = _now
			var rk: String = _rule_key(&"BNT", cat)
			_cooldown_until[rk] = _now + float(_cooldown_rule(rk)[0])
			return true
	return false


# ================================================================== the Operator's musings and slips

## The Operator's self-awareness musings (tier 0): every 240 s of quiet, 50%, tier gated by round.
func _tick_idle(delta: float) -> void:
	if GameState.phase != GameState.Phase.PLAYING:
		return
	_idle_t += delta
	if _idle_t < 240.0:
		return
	_idle_t = 0.0
	if not always_pass_chance and rng.randf() > 0.5:
		return
	# A corporate slip can replace the musing (VO_SCRIPT section 10: min(0.5, 3 x p_map)).
	if _slip_roll(minf(0.5, 3.0 * slip_chance())) and play_slip():
		return
	# Highest unlocked tier first (each tier's lines carry a "round N+" condition).
	for t: int in range(5, 0, -1):
		if play_category(&"OPR", "SELFAWARE_T%d" % t, 1.0):
			return


# ================================================================== corporate slips (VO_SCRIPT section 10, T&C 11.5)

## Chance per eligible Operator line this round on this map: min(0.12, 0.01 + 0.0022 r) x map_mult (cap 0.20).
## Map 0: nothing before round 15, then half rate (the Operator is barely formed there).
func slip_chance(round_number: int = -1, map_id: String = "") -> float:
	var r: int = RoundManager.current_round if round_number < 0 else round_number
	var m: String = String(GameState.map_id) if map_id == "" else map_id
	var key: String = "map00" if m.begins_with("map00") else ("map01" if m.begins_with("map01") else m)
	if key == "map00" and r < int(rules.get("slip_map00_min_round", 15)):
		return 0.0
	var p: float = minf(float(rules.get("slip_cap", 0.12)), float(rules.get("slip_base", 0.01)) + float(rules.get("slip_per_round", 0.0022)) * r)
	var mult: float = float((rules.get("slip_map_mult", {}) as Dictionary).get(key, 1.0))
	return minf(float(rules.get("slip_map_cap", 0.2)), p * mult)


func _slip_roll(p: float) -> bool:
	if p <= 0.0:
		return false
	return always_pass_chance or rng.randf() < p


## Whether a slip may play right now (cooldown, per-round cap, never near a down, a cutscene or a tier-4 line,
## never in the first 3 rounds of a player's first-ever match).
func slip_allowed() -> bool:
	if GameState.phase != GameState.Phase.PLAYING:
		return false
	var cd: float = float(rules.get("slip_cooldown_s", 300.0))
	if String(GameState.map_id).begins_with("map_hw") or String(GameState.map_id).begins_with("map03"):
		cd = float(rules.get("slip_cooldown_hw_map03_s", 240.0))
	if _now - _slip_last < cd:
		return false
	if _now - _last_down_at < float(rules.get("slip_after_down_s", 10.0)):
		return false
	var r: int = RoundManager.current_round
	if _slip_round != r:
		_slip_round = r
		_slip_round_count = 0
	if _slip_round_count >= (2 if r >= 25 else 1):
		return false
	var story: Dictionary = _current[GROUP_STORY]
	if not story.is_empty() and int(story.get("priority", 0)) >= Priority.CRITICAL:
		return false
	if int((ProfileSave.profile.get("stats", {}) as Dictionary).get("matches", 0)) == 0 and r <= 3:
		return false
	return true


## Plays the next slip from the profile-wide shuffle bag (every slip once before any repeats), honoring each
## line's tier round. Returns false when nothing may play.
func play_slip() -> bool:
	if not slip_allowed():
		return false
	var bag: Array = ProfileSave.profile.get("slip_bag", [])
	if bag.is_empty():
		for id: String in lines.keys():
			if id.begins_with("op.slip."):
				bag.append(id)
		bag.shuffle()
	var r: int = RoundManager.current_round
	var hw: bool = String(GameState.map_id).begins_with("map_hw")
	for i: int in bag.size():
		var id: String = str(bag[i])
		var need: int = int((lines.get(id, {}) as Dictionary).get("min_round", 10)) - (5 if hw else 0)
		if r < need or not map_ok(StringName(id)):
			continue
		bag.remove_at(i)
		ProfileSave.profile["slip_bag"] = bag
		_slip_last = _now
		_slip_round_count += 1
		_submit(StringName(id), Priority.ANNOUNCE)
		return true
	ProfileSave.profile["slip_bag"] = bag
	return false
