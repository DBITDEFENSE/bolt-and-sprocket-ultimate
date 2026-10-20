extends Node
## Plays VO lines by ID with priority tiers, channel groups, interrupts, an expiring FIFO queue,
## per-category cooldowns and chances, shuffle-bag no-repeat, once-per-match lines, and chatter limiters
## (docs/VO_SCRIPT.md §1). Lines live in data/vo/lines.json (built by tools_src/extract_vo.py), rules in
## data/vo/rules.json. Lines with no recorded audio hold a timed silence marker and still drive subtitles.
##
## API: play(line_id), play_category(speaker, category), say_player(category), stop_all(), reset_match().

enum Priority { AMBIENT = 0, CHATTER = 1, EVENT = 2, ANNOUNCE = 3, CRITICAL = 4 }

const GROUP_STORY: StringName = &"story"
const GROUP_PLAYER: StringName = &"player"
const LINES_PATH: String = "res://data/gravelight/vo/lines.json"
const RULES_PATH: String = "res://data/gravelight/vo/rules.json"
const CHARACTER_SPEAKERS: Dictionary = {&"dutch": &"DUT", &"peg": &"PEG", &"deacon": &"DEA", &"wren": &"WRN"}
const POWERUP_TOKENS: Dictionary = {&"resupply": "RESUPPLY", &"deaths_door": "DEATHSDOOR", &"double_scrip": "DOUBLESCRIP",
	&"blackout": "BLACKOUT", &"fortify": "FORTIFY", &"clearance": "CLEARANCE"}
const PERK_TOKENS: Dictionary = {&"ironhide_stout": "IRONHIDE", &"second_wind": "SECONDWIND", &"trigger_tonic": "TRIGGER",
	&"twin_barrel": "TWINBARREL", &"marathon_malt": "MARATHON", &"hawkeye_brandy": "HAWKEYE",
	&"packmule_porter": "PACKMULE", &"blastproof_bock": "BLASTPROOF"}
const CLASS_TOKENS: Dictionary = {&"pistol": "PISTOL", &"bolt": "RIFLE", &"rifle": "RIFLE", &"sniper": "RIFLE",
	&"smg": "SMG", &"assault": "SMG", &"shotgun": "SHOTGUN", &"lmg": "LMG", &"launcher": "LAUNCHER",
	&"wonder": "WONDER", &"special": "LAUNCHER", &"melee": "MELEE"}

## Tests set this so chance rolls always pass.
var always_pass_chance: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var lines: Dictionary = {}
var rules: Dictionary = {}
var _index: Dictionary = {}          # "SPK:CAT" -> Array[StringName]
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
var _audio: AudioStreamPlayer
var _subtitles: CanvasLayer
var _duck_on: bool = false


func _ready() -> void:
	rng.randomize()
	load_data()
	_current = {GROUP_STORY: {}, GROUP_PLAYER: {}}
	_queue = {GROUP_STORY: [], GROUP_PLAYER: []}
	_audio = AudioStreamPlayer.new()
	_audio.bus = &"VO"
	add_child(_audio)
	_subtitles = (load("res://gravelight/ui/subtitles.gd") as GDScript).new() as CanvasLayer
	add_child(_subtitles)
	_connect_triggers()


func load_data() -> void:
	lines = GLData.load_json(LINES_PATH)
	rules = GLData.load_json(RULES_PATH)
	_index.clear()
	for id: Variant in lines.keys():
		var rec: Dictionary = lines[id]
		var key: String = "%s:%s" % [rec["speaker"], rec["category"]]
		if not _index.has(key):
			_index[key] = []
		(_index[key] as Array).append(StringName(str(id)))


# ================================================================== public API

func reset_match() -> void:
	stop_all()
	_bags.clear()
	_cooldown_until.clear()
	_played_once.clear()
	_last_chatter = -999.0
	_last_ambient = -999.0
	_idle_t = 0.0
	_streak_times.clear()


func stop_all() -> void:
	for g: Variant in _current.keys():
		_current[g] = {}
		_queue[g] = []
	if _audio != null:
		_audio.stop()
	_set_duck(false)


## Plays one specific line (no chance/cooldown roll). Returns true if it started or was queued.
## Story lines that world/quest code plays on the host are sent to every co-op client too (VO stays local:
## each peer runs its own VOManager; lines picked from relayed events are rolled per peer).
func play(line_id: StringName) -> bool:
	if Net.replicating():
		Net._rpc_vo.rpc(line_id)
	return play_local(line_id)


## Plays a line on this peer only.
func play_local(line_id: StringName) -> bool:
	if not lines.has(String(line_id)):
		return false
	var rec: Dictionary = lines[String(line_id)]
	return _submit(line_id, _priority_for(StringName(rec["speaker"]), str(rec["category"])))


## Picks a variant of a category for a speaker, applying cooldown, chance and the no-repeat bag.
func play_category(speaker: StringName, category: String, chance_override: float = -1.0) -> bool:
	var key: String = "%s:%s" % [speaker, category]
	if not _index.has(key):
		return false
	var rk: String = _rule_key(speaker, category)
	if _now < float(_cooldown_until.get(rk, -1.0)):
		return false
	var cd: Array = _cooldown_rule(rk)
	var chance: float = chance_override if chance_override >= 0.0 else float(cd[1])
	if not always_pass_chance and rng.randf() > chance:
		return false
	var id: StringName = _draw(key)
	if id == &"":
		return false
	var prio: int = _priority_for(speaker, category)
	if not _submit(id, prio):
		return false
	_cooldown_until[rk] = _now + float(cd[0])
	return true


## A line from the local player's character (DUT/PEG/DEA/WRN).
func say_player(category: String, chance_override: float = -1.0) -> bool:
	var spk: StringName = CHARACTER_SPEAKERS.get(GameState.character_id, &"DUT")
	return play_category(spk, category, chance_override)


func current_line(group: StringName) -> StringName:
	var cur: Dictionary = _current.get(group, {})
	return StringName(cur.get("id", ""))


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


# ================================================================== core

func _group_for(speaker: StringName) -> StringName:
	if (rules.get("player_speakers", []) as Array).has(String(speaker)):
		return GROUP_PLAYER
	return GROUP_STORY


func _priority_for(speaker: StringName, category: String) -> int:
	var best_len: int = -1
	var prio: int = int((rules.get("speaker_default_priority", {}) as Dictionary).get(String(speaker), 1))
	var cp: Dictionary = rules.get("category_priority", {})
	var is_player: bool = _group_for(speaker) == GROUP_PLAYER
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


func _cooldown_rule(rule_key: String) -> Array:
	var cat: String = rule_key.substr(rule_key.find(":") + 1) if rule_key.contains(":") else rule_key
	var cc: Dictionary = rules.get("category_cooldown", {})
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
	var id_out: Variant = bag.pop_back()
	_bags[key] = bag
	return StringName(str(id_out))


## Conditions written in the docs: "round 5", "round 8+", "Map 1, power on". Triggers like
## "round 2 start" are matched by their own handlers, so they're ignored here.
func _condition_ok(id: StringName) -> bool:
	var cond: String = str((lines.get(String(id), {}) as Dictionary).get("condition", "")).to_lower()
	if cond == "":
		return true
	if cond.contains("map 1") and not String(GameState.map_id).begins_with("map01"):
		return false
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


func _submit(id: StringName, prio: int) -> bool:
	var rec: Dictionary = lines.get(String(id), {})
	if rec.is_empty():
		return false
	var speaker: StringName = StringName(rec["speaker"])
	var group: StringName = _group_for(speaker)
	# Chatter limiters.
	if group == GROUP_PLAYER and prio <= Priority.CHATTER:
		if _now - _last_chatter < float(rules.get("player_chatter_gap", 3.5)):
			return false
		var story: Dictionary = _current[GROUP_STORY]
		if not story.is_empty():
			return false   # ducked: story line playing
	if prio == Priority.AMBIENT and _now - _last_ambient < float(rules.get("ambient_gap", 45.0)):
		return false
	var item: Dictionary = {"id": id, "priority": prio, "speaker": speaker}
	var cur: Dictionary = _current[group]
	if cur.is_empty():
		_start(group, item)
		return true
	if _can_interrupt(prio, int(cur["priority"])):
		if int(cur["priority"]) >= Priority.ANNOUNCE:
			_enqueue(group, {"id": cur["id"], "priority": cur["priority"], "speaker": cur["speaker"]}, true)
		_start(group, item)
		return true
	_enqueue(group, item, false)
	return true


func _can_interrupt(new_prio: int, cur_prio: int) -> bool:
	match new_prio:
		Priority.CRITICAL:
			return cur_prio < Priority.CRITICAL
		Priority.ANNOUNCE:
			return cur_prio <= Priority.CHATTER
		Priority.EVENT:
			return cur_prio <= Priority.AMBIENT
	return false


func _enqueue(group: StringName, item: Dictionary, front: bool) -> void:
	var expiry: float = float((rules.get("queue_expiry", {}) as Dictionary).get(str(item["priority"]), 4.0))
	item["expires"] = INF if expiry < 0.0 else _now + expiry
	if front:
		(_queue[group] as Array).push_front(item)
	else:
		(_queue[group] as Array).push_back(item)


func _start(group: StringName, item: Dictionary) -> void:
	var id: StringName = item["id"]
	var rec: Dictionary = lines[String(id)]
	var parts: Array = []
	if rec.has("exchange"):
		for p: Variant in rec["exchange"]:
			parts.append([StringName(str((p as Array)[0])), str((p as Array)[1])])
	else:
		parts.append([StringName(rec["speaker"]), str(rec["text"])])
	item["parts"] = parts
	item["part"] = -1
	item["end"] = _now
	_current[group] = item
	if bool((lines.get(String(id), {}) as Dictionary).get("once_per_match", false)) or StringName(rec["speaker"]) in [&"BNT", &"TAG"]:
		_played_once[String(id)] = true
	if group == GROUP_PLAYER and int(item["priority"]) <= Priority.CHATTER:
		_last_chatter = _now
	if int(item["priority"]) == Priority.AMBIENT:
		_last_ambient = _now
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
	var path: String = "res://gravelight/audio/vo/%s/%s.ogg" % [String(item["speaker"]).to_lower(), item["id"]]
	if parts.size() == 1 and ResourceLoader.exists(path):
		var stream: AudioStream = load(path) as AudioStream
		if stream != null:
			_audio.stream = stream
			_audio.play()
			dur = maxf(dur * 0.5, stream.get_length())
	var gap: float = float(rules.get("exchange_gap", 0.4)) if int(item["part"]) < parts.size() - 1 else 0.0
	item["end"] = _now + dur + gap
	GLBus.vo_line_started.emit(item["id"], speaker, text, dur)


func _finish(group: StringName) -> void:
	_current[group] = {}
	var q: Array = _queue[group]
	while not q.is_empty():
		var nxt: Dictionary = q.pop_front()
		if float(nxt["expires"]) >= _now:
			_start(group, nxt)
			return
	if group == GROUP_STORY:
		_set_duck(false)


func _audio_stop_player_chatter() -> void:
	var cur: Dictionary = _current[GROUP_PLAYER]
	if not cur.is_empty() and int(cur["priority"]) <= Priority.CHATTER:
		_current[GROUP_PLAYER] = {}


func _set_duck(on: bool) -> void:
	if on == _duck_on:
		return
	_duck_on = on
	var idx: int = AudioServer.get_bus_index(&"Music")
	if idx < 0:
		return
	var base: float = linear_to_db(maxf(0.0001, GLSettings.get_f("vol_music")))
	AudioServer.set_bus_volume_db(idx, base - (6.0 if on else 0.0))
	var j: int = AudioServer.get_bus_index(&"Jingles")
	if j >= 0:
		var jb: float = linear_to_db(maxf(0.0001, GLSettings.get_f("vol_jingles")))
		AudioServer.set_bus_volume_db(j, jb - (9.0 if on else 0.0))


## Advances the clock; tests call this directly.
func advance(delta: float) -> void:
	_now += delta
	for g: Variant in _current.keys():
		var cur: Dictionary = _current[g]
		if not cur.is_empty() and _now >= float(cur["end"]):
			_next_part(StringName(g))
	_tick_idle(delta)


func _process(delta: float) -> void:
	advance(delta)


# ================================================================== triggers (VO_SCRIPT §2)

func _connect_triggers() -> void:
	GLBus.match_started.connect(_on_match_started)
	GLBus.round_started.connect(_on_round_started)
	GLBus.round_ended.connect(_on_round_ended)
	GLBus.game_over.connect(_on_game_over)
	GLBus.powerup_collected.connect(_on_powerup_collected)
	GLBus.special_round_warning.connect(func(_k: StringName) -> void: play_category(&"OPR", "SPECIAL_WARN", 1.0))
	GLBus.boss_spawned.connect(func(id: StringName) -> void: play_category(&"OPR", "BOSS_" + String(id).to_upper(), 1.0))
	GLBus.enemy_killed.connect(func(id: StringName, _l: StringName, _w: StringName, _b: int) -> void:
		if id == &"foreman":
			play_category(&"OPR", "BOSS_FOREMAN_DEAD", 1.0))
	GLBus.powerup_expired.connect(_on_powerup_expired)
	GLBus.crate_drummer.connect(_on_crate_drummer)
	GLBus.crate_moved.connect(_on_crate_moved)
	GLBus.crate_result.connect(_on_crate_result)
	GLBus.perk_bought.connect(_on_perk_bought)
	GLBus.perk_denied.connect(_on_perk_denied)
	GLBus.weapon_acquired.connect(_on_weapon_acquired)
	GLBus.enemy_killed.connect(_on_enemy_killed)
	GLBus.low_ammo.connect(_on_low_ammo)
	GLBus.no_ammo.connect(_on_no_ammo)
	GLBus.player_downed.connect(_on_player_downed)
	GLBus.player_revived.connect(_on_player_revived)
	GLBus.self_revive.connect(_on_self_revive)
	GLBus.door_opened.connect(_on_door_opened)
	GLBus.power_activated.connect(_on_power_activated)
	GLBus.radio_tuned.connect(_on_radio_tuned)


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


func _on_round_started(round_number: int, is_special: bool) -> void:
	_idle_t = 0.0
	if is_special:
		_opr("SPECIAL_START", 1.0)
		return
	var always: Array = rules.get("round_start_always", [])
	var chance: float = 1.0 if always.has(round_number) else -1.0
	# A line written for exactly this round wins when it exists.
	if not _play_conditioned(&"OPR", "ROUND_START", round_number, chance):
		_opr("ROUND_START", chance)
	if _on_map0():
		_play_radio_round(round_number, "start")
	if round_number >= 50:
		say_player("EXHAUST", 0.3)


func _on_round_ended(round_number: int) -> void:
	if not _play_conditioned(&"OPR", "ROUND_END", round_number, 1.0):
		_opr("ROUND_END")
	if _on_map0():
		_play_radio_round(round_number, "end")


func _play_conditioned(speaker: StringName, category: String, round_number: int, chance: float) -> bool:
	for id: Variant in _index.get("%s:%s" % [speaker, category], []):
		var cond: String = str((lines[String(id)] as Dictionary).get("condition", "")).to_lower().strip_edges()
		if cond == "round %d" % round_number:
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
	_opr("GAME_OVER", 1.0)


func _on_powerup_collected(powerup_id: StringName, by_player: int) -> void:
	var token: String = str(POWERUP_TOKENS.get(powerup_id, String(powerup_id).to_upper().replace("_", "")))
	_opr("PWR_" + token, 1.0)
	if by_player == _local_player():
		say_player("PWR_" + token)


func _on_powerup_expired(powerup_id: StringName) -> void:
	if powerup_id == &"deaths_door" or powerup_id == &"double_scrip":
		_opr("PWR_EXPIRE")


func _on_crate_drummer(_location: int) -> void:
	_opr("CRATE_MOVE", 1.0)
	say_player("CRATE_DRUMMER")


func _on_crate_moved(_location: int) -> void:
	_opr("CRATE_MOVE_ARRIVE", 0.25)


func _on_crate_result(player: int, _weapon_id: StringName, quality: StringName) -> void:
	if player != _local_player():
		return
	match quality:
		&"good":
			say_player("CRATE_GOOD")
		&"bad":
			say_player("CRATE_BAD")
		&"wonder":
			if not say_player("CRATE_WONDER", 1.0):
				say_player("BUY_WONDER", 1.0)


func _on_perk_bought(player: int, perk_id: StringName) -> void:
	if player == _local_player() and PERK_TOKENS.has(perk_id):
		say_player("PERK_" + str(PERK_TOKENS[perk_id]), 1.0)


func _on_perk_denied(player: int, _perk_id: StringName, reason: StringName) -> void:
	if player == _local_player():
		say_player("DENY_" + String(reason).to_upper())


func _on_weapon_acquired(player: int, weapon_id: StringName, source: StringName) -> void:
	if player != _local_player() or source != &"wall":
		return
	var w: Dictionary = GLData.table("weapons")
	var row: Dictionary = (w.get("weapons", {}) as Dictionary).get(String(weapon_id), {})
	if row.is_empty():
		row = (w.get("melee", {}) as Dictionary).get(String(weapon_id), {})
		if not row.is_empty():
			row = {"class": "melee"}
	var cls: StringName = StringName(str(row.get("class", "rifle")))
	say_player("BUY_" + str(CLASS_TOKENS.get(cls, "RIFLE")))


func _on_enemy_killed(_enemy_id: StringName, limb: StringName, _weapon_id: StringName, by_player: int) -> void:
	if by_player != _local_player():
		return
	_streak_times.append(_now)
	while not _streak_times.is_empty() and _now - _streak_times[0] > 3.0:
		_streak_times.pop_front()
	if _streak_times.size() >= 5:
		_streak_times.clear()
		if say_player("STREAK"):
			return
	if limb == &"head":
		say_player("HEADSHOT")


func _on_low_ammo(player: int, _weapon_id: StringName) -> void:
	if player == _local_player():
		say_player("AMMO_LOW")


func _on_no_ammo(player: int, _weapon_id: StringName) -> void:
	if player == _local_player():
		say_player("AMMO_NONE")


func _on_player_downed(player: int) -> void:
	if player == _local_player():
		say_player("DOWN", 1.0)


func _on_player_revived(player: int, by_player: int) -> void:
	if player == _local_player() and by_player != player:
		say_player("REVIVED")
	elif by_player == _local_player() and by_player != player:
		say_player("REVIVE")


func _on_self_revive(_player: int, uses_left: int) -> void:
	play_category(&"OPR", "SECOND_WIND_%d" % uses_left, 1.0)


func _on_door_opened(_door_id: StringName, by_player: int) -> void:
	if by_player == _local_player():
		say_player("DOOR")


func _on_power_activated() -> void:
	if not _on_map0():
		_opr("POWER_ON", 1.0)
		say_player("POWER", 1.0)


func _on_radio_tuned(freq_index: int) -> void:
	# freq_index: 1..3 = correct frequency in order; 0 = wrong frequency.
	if freq_index <= 0:
		play_category(&"OPR", "M0_WRONG", 1.0)
		return
	play_category(&"FAS", "M0_FREQ%d" % freq_index, 1.0)
	if freq_index == 3 and GameState.character_id == &"peg":
		play_local(&"FAS_M0_FREQ_DONE_PEG")


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
	# Highest unlocked tier first (each tier's lines carry a "round N+" condition).
	for t: int in range(5, 0, -1):
		if play_category(&"OPR", "SELFAWARE_T%d" % t, 1.0):
			return
