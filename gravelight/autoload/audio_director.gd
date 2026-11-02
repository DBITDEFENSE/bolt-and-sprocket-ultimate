extends Node
## Plays SFX (pooled 3D and 2D players), stingers, the ambient bed, the score layer and perk-machine hums.
##
## Sounds are looked up by key in the bank res://data/gravelight/audio.json ("sounds": key -> files, volume_db,
## vol_jitter_db, pitch range, bus, max_voices, attenuation profile, loop). A key with several files picks one
## at random (never the same one twice in a row). Keys missing from the bank, or whose files are absent, fall
## back to res://gravelight/audio/sfx|music/{final,placeholder}/<key>[_1.._5].wav. Missing sounds are silent, so gameplay
## never depends on audio existing.
##
## Voice limiting: each key may sound at most `max_voices` times at once (per 2D / 3D pool); the oldest voice of
## that key is stolen. Buses come from default_bus_layout.tres (Master, Music, SFX, VO, Jingles, Ambience) and
## are re-created here if missing. Round stingers, ambience and a few one-shots are driven by EventBus signals,
## with the key mapping in audio.json "music" / "events" so it stays data-driven.

const BANK_PATH: String = "res://data/gravelight/audio.json"
const BUSES: PackedStringArray = ["Music", "SFX", "VO", "Jingles", "Ambience"]
const VOLUME_KEYS: Dictionary = {"Master": "vol_master", "Music": "vol_music", "SFX": "vol_sfx", "VO": "vol_vo",
	"Jingles": "vol_jingles", "Ambience": "vol_ambience"}
const SFX_DIRS: PackedStringArray = ["res://gravelight/audio/sfx/final/", "res://gravelight/audio/sfx/placeholder/"]
const MUSIC_DIRS: PackedStringArray = ["res://gravelight/audio/music/final/", "res://gravelight/audio/music/placeholder/"]
const SILENT_DB: float = -80.0

var intensity: float = 0.0
## Parsed audio.json (tests read it too).
var bank: Dictionary = {}

var _sounds: Dictionary = {}       # key -> entry Dictionary
var _defaults: Dictionary = {}
var _cache: Dictionary = {}        # key -> Array of AudioStream
var _last_pick: Dictionary = {}    # key -> index of the previous pick
var _pool3d: Array[AudioStreamPlayer3D] = []
var _pool2d: Array[AudioStreamPlayer] = []
var _next3d: int = 0
var _next2d: int = 0
var _voices: Dictionary = {}       # "key|3d" / "key|2d" -> Array of players, oldest first
var _owner: Dictionary = {}        # player instance id -> voice-list id
var _music: AudioStreamPlayer      # stingers
var _music_loop: AudioStreamPlayer # menu theme and other looping cues
var _ambient: AudioStreamPlayer
var _vacuum: bool = false   # T-149: the listener is in a vacuum zone: the map's bed is silent, only the suit
var _score: AudioStreamPlayer
var _duck_tween: Tween
var _vo_duck_tween: Tween
var _vo_duck_on: bool = false
var _vo_duck_db: float = 0.0
var _map_id: StringName = &""
var _match_msec: int = -100000
var _last_round_special: bool = false
var _crate_pos: Vector3 = Vector3.ZERO
var _has_crate_pos: bool = false
var _hums: Dictionary = {}         # machine instance id -> AudioStreamPlayer3D
var _hum_t: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_bank()
	_ensure_buses()
	for i: int in int(bank.get("pool_3d", 48)):
		var p: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		p.bus = &"SFX"
		add_child(p)
		_pool3d.append(p)
	for i: int in int(bank.get("pool_2d", 24)):
		var p2: AudioStreamPlayer = AudioStreamPlayer.new()
		p2.bus = &"SFX"
		add_child(p2)
		_pool2d.append(p2)
	_music = _make_player(&"Music")
	_music_loop = _make_player(&"Music")
	_ambient = _make_player(&"Ambience")
	_score = _make_player(&"Music")
	_connect_events()
	apply_volumes()


func _make_player(bus_name: StringName) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.bus = bus_name
	add_child(p)
	return p


func _load_bank() -> void:
	bank = GLData.load_json(BANK_PATH) if FileAccess.file_exists(BANK_PATH) else {}
	_sounds = bank.get("sounds", {})
	_defaults = bank.get("defaults", {})
	_cache.clear()


func _ensure_buses() -> void:
	for bus_name: String in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, &"Master")


func apply_volumes() -> void:
	for bus_name: String in VOLUME_KEYS.keys():
		var idx: int = AudioServer.get_bus_index(bus_name)
		if idx >= 0:
			var key: String = str(VOLUME_KEYS[bus_name])
			var v: float = GLSettings.get_f(key) if GLSettings.values.has(key) else 1.0
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(0.0001, v)))


# ================================================================== bank lookup

## True when the key resolves to at least one stream (bank or legacy placeholder).
func has_sound(sound_name: String) -> bool:
	return not _streams(sound_name).is_empty()


func _entry(sound_name: String) -> Dictionary:
	return _sounds.get(sound_name, {})


func _opt(e: Dictionary, field: String, fallback: Variant) -> Variant:
	return e.get(field, _defaults.get(field, fallback))


func _streams(sound_name: String) -> Array:
	if _cache.has(sound_name):
		return _cache[sound_name]
	var found: Array = []
	var e: Dictionary = _entry(sound_name)
	for f: Variant in e.get("files", []):
		var path: String = str(f)
		if ResourceLoader.exists(path):
			var s: AudioStream = load(path) as AudioStream
			if s != null:
				found.append(s)
	if found.is_empty():
		var dirs: Array[String] = []
		dirs.append_array(SFX_DIRS)
		dirs.append_array(MUSIC_DIRS)
		for dir: String in dirs:
			var single: String = dir + sound_name + ".wav"
			if ResourceLoader.exists(single):
				found.append(load(single))
			for i: int in range(1, 6):
				var variant: String = dir + sound_name + "_%d.wav" % i
				if ResourceLoader.exists(variant):
					found.append(load(variant))
			if not found.is_empty():
				break
	if bool(_opt(e, "loop", false)):
		for s: Variant in found:
			_make_looping(s as AudioStream)
	_cache[sound_name] = found
	return found


func _make_looping(s: AudioStream) -> void:
	if s is AudioStreamWAV:
		var w: AudioStreamWAV = s as AudioStreamWAV
		if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(w.get_length() * float(w.mix_rate))
	elif s is AudioStreamOggVorbis:   # T-145: Totenhafen's zone beds are OGG
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true


func _pick(sound_name: String) -> AudioStream:
	var list: Array = _streams(sound_name)
	if list.is_empty():
		return null
	var i: int = randi() % list.size()
	if list.size() > 1 and i == int(_last_pick.get(sound_name, -1)):
		i = (i + 1 + randi() % (list.size() - 1)) % list.size()
	_last_pick[sound_name] = i
	return list[i]


func _volume(e: Dictionary, caller_db: float) -> float:
	var jit: float = float(_opt(e, "vol_jitter_db", 0.0))
	return caller_db + float(_opt(e, "volume_db", 0.0)) + randf_range(-jit, jit)


func _pitch(e: Dictionary, caller_jitter: float) -> float:
	var rng: Array = _opt(e, "pitch", [1.0, 1.0])
	var base: float = randf_range(float(rng[0]), float(rng[1])) if rng.size() >= 2 else 1.0
	return maxf(0.05, base * (1.0 + randf_range(-caller_jitter, caller_jitter)))


func _bus(e: Dictionary) -> StringName:
	var b: String = str(_opt(e, "bus", "SFX"))
	return StringName(b) if AudioServer.get_bus_index(b) >= 0 else &"SFX"


## Total length of the longest file of a key (seconds), 0 if unknown.
func sound_length(sound_name: String) -> float:
	var best: float = 0.0
	for s: Variant in _streams(sound_name):
		best = maxf(best, (s as AudioStream).get_length())
	return best


## Downbeat time of a stinger (for HUD sync), from audio.json music.stinger_downbeat.
func stinger_downbeat(sound_name: String) -> float:
	return float((_music_cfg().get("stinger_downbeat", {}) as Dictionary).get(sound_name, 0.0))


func _music_cfg() -> Dictionary:
	return bank.get("music", {})


# ================================================================== voice pools

func _voice_list(vid: String) -> Array:
	var list: Array = _voices.get(vid, [])
	var alive: Array = []
	for n: Variant in list:
		var node: Node = n as Node
		if is_instance_valid(node) and str(_owner.get(node.get_instance_id(), "")) == vid and _is_playing(node):
			alive.append(node)
	_voices[vid] = alive
	return alive


func _is_playing(node: Node) -> bool:
	if node is AudioStreamPlayer3D:
		return (node as AudioStreamPlayer3D).playing
	if node is AudioStreamPlayer:
		return (node as AudioStreamPlayer).playing
	return false


func _claim(sound_name: String, e: Dictionary, three_d: bool) -> Node:
	var vid: String = sound_name + ("|3d" if three_d else "|2d")
	var active: Array = _voice_list(vid)
	var limit: int = maxi(1, int(_opt(e, "max_voices", 6)))
	var p: Node = null
	if active.size() >= limit:
		p = active.pop_front() as Node    # steal the oldest voice of this key
	else:
		var size: int = _pool3d.size() if three_d else _pool2d.size()
		for k: int in size:
			var idx: int = ((_next3d if three_d else _next2d) + k) % size
			var cand: Node = _pool3d[idx] if three_d else _pool2d[idx]
			if not _is_playing(cand):
				p = cand
				break
		if p == null:
			p = _pool3d[_next3d] if three_d else _pool2d[_next2d]
		if three_d:
			_next3d = (_pool3d.find(p as AudioStreamPlayer3D) + 1) % _pool3d.size()
		else:
			_next2d = (_pool2d.find(p as AudioStreamPlayer) + 1) % _pool2d.size()
	active.append(p)
	_voices[vid] = active
	_owner[p.get_instance_id()] = vid
	return p


func _apply_attenuation(p: AudioStreamPlayer3D, e: Dictionary) -> void:
	var profiles: Dictionary = bank.get("attenuation", {})
	var prof: Dictionary = profiles.get(str(_opt(e, "attenuation", "world")), profiles.get("world", {}))
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.unit_size = float(prof.get("unit_size", 6.0))
	p.max_distance = float(prof.get("max_distance", 60.0))
	p.attenuation_filter_cutoff_hz = float(prof.get("filter_hz", 6000.0))
	p.attenuation_filter_db = float(prof.get("filter_db", -24.0))
	p.panning_strength = 1.0


## Positional sound. Returns the player so callers can stop loops or tweak pitch.
func play_3d(sound_name: String, at: Vector3, volume_db: float = 0.0, pitch_jitter: float = 0.06) -> AudioStreamPlayer3D:
	var stream: AudioStream = _pick(sound_name)
	if stream == null or _pool3d.is_empty():
		return null
	var e: Dictionary = _entry(sound_name)
	var p: AudioStreamPlayer3D = _claim(sound_name, e, true) as AudioStreamPlayer3D
	p.stop()
	p.stream = stream
	p.bus = _bus(e)
	_apply_attenuation(p, e)
	p.global_position = at
	p.volume_db = _volume(e, volume_db)
	p.pitch_scale = _pitch(e, pitch_jitter)
	p.play()
	return p


## Non-positional sound (UI, the player's own gun).
func play_2d(sound_name: String, volume_db: float = 0.0, pitch_jitter: float = 0.04) -> AudioStreamPlayer:
	var stream: AudioStream = _pick(sound_name)
	if stream == null or _pool2d.is_empty():
		return null
	var e: Dictionary = _entry(sound_name)
	var p: AudioStreamPlayer = _claim(sound_name, e, false) as AudioStreamPlayer
	p.stop()
	p.stream = stream
	p.bus = _bus(e)
	p.volume_db = _volume(e, volume_db)
	p.pitch_scale = _pitch(e, pitch_jitter)
	p.play()
	return p


## A dedicated looping positional player for `sound_name`, parented to `parent` so it is freed with it (no
## pooled voice to leak or have stolen). Not started: callers play() / stop() it. Null if the key has no sound.
func make_loop_3d(sound_name: String, parent: Node, volume_db: float = 0.0) -> AudioStreamPlayer3D:
	var stream: AudioStream = _pick(sound_name)
	if stream == null or parent == null:
		return null
	_make_looping(stream)
	var e: Dictionary = _entry(sound_name)
	var p: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	p.name = "Loop_" + sound_name
	p.stream = stream
	p.bus = _bus(e)
	_apply_attenuation(p, e)
	p.volume_db = volume_db + float(_opt(e, "volume_db", 0.0))
	parent.add_child(p)
	return p


## Non-positional variant of make_loop_3d (e.g. the low-health heartbeat).
func make_loop_2d(sound_name: String, parent: Node, volume_db: float = 0.0) -> AudioStreamPlayer:
	var stream: AudioStream = _pick(sound_name)
	if stream == null or parent == null:
		return null
	_make_looping(stream)
	var e: Dictionary = _entry(sound_name)
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.name = "Loop_" + sound_name
	p.stream = stream
	p.bus = _bus(e)
	p.volume_db = volume_db + float(_opt(e, "volume_db", 0.0))
	parent.add_child(p)
	return p


# ================================================================== music

func play_stinger(sound_name: String, volume_db: float = -2.0) -> void:
	var stream: AudioStream = _pick(sound_name)
	if stream == null:
		return
	var e: Dictionary = _entry(sound_name)
	_music.stop()
	_music.stream = stream
	_music.bus = &"Music"
	_music.volume_db = volume_db + float(_opt(e, "volume_db", 0.0))
	_music.pitch_scale = 1.0
	_music.play()
	_duck(stream.get_length())


## Looping music cue (e.g. "music_menu"); replaces any previous one.
func play_music(sound_name: String, volume_db: float = 0.0) -> void:
	var stream: AudioStream = _pick(sound_name)
	if stream == null:
		return
	_make_looping(stream)
	var e: Dictionary = _entry(sound_name)
	_music_loop.stream = stream
	_music_loop.volume_db = volume_db + float(_opt(e, "volume_db", 0.0))
	_music_loop.play()


func stop_music() -> void:
	_music_loop.stop()


func start_ambient() -> void:
	var cfg: Dictionary = _music_cfg()
	var amb: Dictionary = cfg.get("ambient", {})
	var key: String = str(amb.get(str(_map_id), amb.get("default", "ambient_wind")))
	var stream: AudioStream = _pick(key)
	if stream == null:
		stream = _pick("ambient_wind")
	if stream == null:
		return
	_make_looping(stream)
	_ambient.stream = stream
	_ambient.volume_db = _ambient_db()
	_ambient.play()
	var score_stream: AudioStream = _pick(str(cfg.get("score", "")))
	if score_stream != null:
		_make_looping(score_stream)
		_score.stream = score_stream
		_score.volume_db = SILENT_DB
		_score.play()


## A vacuum zone (ZoneAmbience, an ambience json zone with `vacuum: true`, DECISIONS T-149): the map's ambient bed
## fades to silence so nothing outside the suit is heard; leaving the zone brings it back.
func set_vacuum_bed(on: bool) -> void:
	if _vacuum == on:
		return
	_vacuum = on
	if _ambient != null and _ambient.is_inside_tree():
		create_tween().tween_property(_ambient, "volume_db", _ambient_db(), 1.2)


func stop_all_music() -> void:
	_vacuum = false
	_music.stop()
	_music_loop.stop()
	_ambient.stop()
	_score.stop()
	_clear_hums()


func _range_db(field: String, fallback: Array, t: float) -> float:
	var r: Array = _music_cfg().get(field, fallback)
	return lerpf(float(r[0]), float(r[1]), t) if r.size() >= 2 else 0.0


func _ambient_db() -> float:
	if _vacuum:
		return SILENT_DB
	return _range_db("ambient_db", [-6.0, -2.0], intensity)


func _score_db() -> float:
	if RoundManager.current_round < int(_music_cfg().get("score_from_round", 2)):
		return SILENT_DB
	return _range_db("score_db", [-30.0, -13.0], intensity)


## Ducks the ambient bed and score under a stinger for `seconds`.
func _duck(seconds: float) -> void:
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	var d: float = float(_music_cfg().get("duck_db", -7.0))
	_duck_tween = create_tween().set_parallel(true)
	_duck_tween.tween_property(_ambient, "volume_db", _ambient_db() + d, 0.3)
	if _score.playing:
		_duck_tween.tween_property(_score, "volume_db", maxf(SILENT_DB, _score_db() + d), 0.3)
	_duck_tween.chain().tween_interval(maxf(0.0, seconds - 1.0))
	_duck_tween.chain().tween_property(_ambient, "volume_db", _ambient_db(), 1.5)
	if _score.playing:
		_duck_tween.parallel().tween_property(_score, "volume_db", _score_db(), 1.5)


## VOManager: the ambience bed and score sit `duck_db` lower while a story voice (the Operator, the radio)
## speaks, and come back over 1.2 s when it stops. Independent of the stinger duck.
func set_vo_duck(on: bool, duck_db: float = -5.0) -> void:
	if _vo_duck_on == on:
		return
	_vo_duck_on = on
	_vo_duck_db = duck_db if on else 0.0
	if _vo_duck_tween != null and _vo_duck_tween.is_valid():
		_vo_duck_tween.kill()
	_vo_duck_tween = create_tween().set_parallel(true)
	_vo_duck_tween.tween_property(_ambient, "volume_db", _ambient_db() + _vo_duck_db, 0.25 if on else 1.2)
	if _score.playing:
		_vo_duck_tween.tween_property(_score, "volume_db", maxf(SILENT_DB, _score_db() + _vo_duck_db), 0.25 if on else 1.2)


## The stinger a round start plays (HUD uses it with stinger_downbeat to time the round stamp).
func round_stinger_key(round_number: int, is_special: bool) -> String:
	if is_special:
		return str(_music_cfg().get("special_start", "round_start"))
	return _tier_key("round_start_tiers", round_number, "round_start")


func _tier_key(field: String, round_number: int, fallback: String) -> String:
	var key: String = fallback
	for pair: Variant in _music_cfg().get(field, []):
		var a: Array = pair as Array
		if a.size() >= 2 and round_number >= int(a[0]):
			key = str(a[1])
	return key


# ================================================================== EventBus hooks

func _connect_events() -> void:
	GLBus.match_started.connect(_on_match_started)
	GLBus.round_started.connect(_on_round_started)
	GLBus.round_ended.connect(_on_round_ended)
	GLBus.enemy_spawned.connect(_on_enemy_spawned)
	GLBus.boss_spawned.connect(_on_boss_spawned)
	GLBus.powerup_spawned.connect(_on_powerup_spawned)
	GLBus.powerup_collected.connect(_on_powerup_collected)
	GLBus.powerup_expired.connect(func(_id: StringName) -> void: _event_2d("powerup_expired"))
	GLBus.purchase_made.connect(_on_purchase_made)
	GLBus.crate_opened.connect(_on_crate_opened)
	GLBus.crate_result.connect(func(_p: int, _w: StringName, _q: StringName) -> void: _event_at_crate("crate_result"))
	GLBus.crate_drummer.connect(func(_i: int) -> void: _event_at_crate("crate_drummer"))
	GLBus.crate_moved.connect(func(_i: int) -> void: _event_at_crate("crate_moved"))
	GLBus.power_activated.connect(_on_power_activated)
	GLBus.player_downed.connect(func(_p: int) -> void: _event_2d("player_downed"))
	GLBus.player_revived.connect(func(_p: int, _b: int) -> void: _event_2d("player_revived"))
	GLBus.perks_lost.connect(func(_p: int) -> void: _event_2d("perks_lost"))
	GLBus.weapon_upgraded.connect(func(_p: int, _w: StringName) -> void: _event_2d("weapon_upgraded", -6.0))


func _event_key(event_name: String) -> String:
	return str((bank.get("events", {}) as Dictionary).get(event_name, ""))


func _event_2d(event_name: String, volume_db: float = 0.0) -> void:
	var key: String = _event_key(event_name)
	if key != "":
		play_2d(key, volume_db, 0.0)


func _on_match_started(map_id: StringName) -> void:
	_map_id = map_id
	_match_msec = Time.get_ticks_msec()
	_has_crate_pos = false
	_last_round_special = false
	intensity = 0.0
	_clear_hums()


func _on_round_started(round_number: int, is_special: bool) -> void:
	intensity = clampf(float(round_number) / 30.0, 0.0, 1.0)
	_last_round_special = is_special
	play_stinger(round_stinger_key(round_number, is_special), -2.0)
	if _score.stream != null and not _score.playing and _ambient.playing:
		_score.play()


func _on_round_ended(round_number: int) -> void:
	var cfg: Dictionary = _music_cfg()
	if _last_round_special:
		play_stinger(str(cfg.get("special_end", "round_end")), -2.0)
	else:
		play_stinger(_tier_key("round_end_tiers", round_number, "round_end"), -2.0)


func _on_enemy_spawned(_enemy_id: StringName, node_id: int) -> void:
	var key: String = _event_key("enemy_spawned")
	var n: Object = instance_from_id(node_id) if node_id != 0 else null
	if key != "" and n is Node3D and (n as Node3D).is_inside_tree():
		play_3d(key, (n as Node3D).global_position + Vector3.UP * 0.5)


func _on_boss_spawned(enemy_id: StringName) -> void:
	var map: Variant = (bank.get("events", {}) as Dictionary).get("boss_spawned", {})
	if map is Dictionary and (map as Dictionary).has(str(enemy_id)):
		play_2d(str((map as Dictionary)[str(enemy_id)]), -4.0, 0.0)


func _on_powerup_spawned(_id: StringName, position: Vector3) -> void:
	var key: String = _event_key("powerup_spawned")
	if key != "":
		play_3d(key, position)


func _on_powerup_collected(powerup_id: StringName, _by_player: int) -> void:
	var prefix: String = _event_key("powerup_collected_prefix")
	if prefix != "":
		play_2d(prefix + str(powerup_id), 0.0, 0.0)


func _on_purchase_made(_player: int, item_id: StringName, _cost: int) -> void:
	var key: String = _event_key("perk_bought")
	if key == "" or not is_inside_tree():
		return
	for n: Node in get_tree().get_nodes_in_group(&"perk_machines"):
		if n is Node3D and StringName(str(n.get("perk_id"))) == item_id:
			play_3d(key, (n as Node3D).global_position + Vector3.UP)
			return


func _on_crate_opened(by_player: int) -> void:
	if not is_inside_tree():
		return
	var who: Node3D = null
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		if n is Node3D and int(n.get("player_id")) == by_player:
			who = n as Node3D
	var best: float = INF
	for n: Node in get_tree().get_nodes_in_group(&"crate_spots"):
		if n is Node3D and who != null:
			var d: float = (n as Node3D).global_position.distance_to(who.global_position)
			if d < best:
				best = d
				_crate_pos = (n as Node3D).global_position
				_has_crate_pos = true
	_event_at_crate("crate_opened")


func _event_at_crate(event_name: String) -> void:
	var key: String = _event_key(event_name)
	if key == "":
		return
	if _has_crate_pos:
		play_3d(key, _crate_pos + Vector3.UP, 0.0, 0.0)
	else:
		play_2d(key, -6.0, 0.0)


func _on_power_activated() -> void:
	_hum_t = 0.0
	# Map 0 starts powered (emitted right after match_started): no turbine spin-up there.
	if Time.get_ticks_msec() - _match_msec > 1500:
		_event_2d("power_activated")


# ================================================================== the map's low hum (shader sync, MZ T-041)

var _hum_phase: float = 0.0
var _hum_level: float = 0.5
var _hum_global_ok: bool = false


## The Nachtglas hum envelope the infection shader's veins pulse with (global shader parameter gl_hum, 0..1):
## a slow breathing LFO at audio.json "hum_hz" (default anim.json infection.hum_hz) while the ambient bed plays,
## flattening to a faint glow when it is silent.
func _update_hum_envelope(delta: float) -> void:
	var hz: float = float(bank.get("hum_hz", 0.42))
	_hum_phase = fmod(_hum_phase + delta * hz * TAU, TAU)
	var playing: bool = _ambient != null and _ambient.playing
	var target: float = (0.5 + 0.5 * sin(_hum_phase)) if playing else 0.25
	_hum_level = lerpf(_hum_level, target, clampf(delta * 6.0, 0.0, 1.0))
	if not _hum_global_ok:
		ZombieBody.ensure_globals()   # registers gl_hum / gl_round_k at runtime
		_hum_global_ok = true
	RenderingServer.global_shader_parameter_set("gl_hum", _hum_level)


## The current hum envelope (0..1).
func hum_level() -> float:
	return _hum_level


# ================================================================== perk-machine hums

func _process(delta: float) -> void:
	_update_hum_envelope(delta)
	_hum_t -= delta
	if _hum_t > 0.0:
		return
	var cfg: Dictionary = bank.get("perk_hum", {})
	_hum_t = float(cfg.get("check_seconds", 1.5))
	if not is_inside_tree() or not _ambient.playing:
		return
	for n: Node in get_tree().get_nodes_in_group(&"perk_machines"):
		if not (n is Node3D) or not n.has_method("is_powered"):
			continue
		var on: bool = bool(n.call("is_powered")) and not bool(n.get("_gone"))
		var id: int = n.get_instance_id()
		var hv: Variant = _hums.get(id, null)
		var hum: AudioStreamPlayer3D = hv as AudioStreamPlayer3D if is_instance_valid(hv) else null
		if on and (hum == null or not is_instance_valid(hum)):
			var key: String = str(cfg.get("prefix", "perk_hum_")) + str(n.get("perk_id"))
			var stream: AudioStream = _pick(key)
			if stream == null:
				continue
			_make_looping(stream)
			var e: Dictionary = _entry(key)
			hum = AudioStreamPlayer3D.new()
			hum.name = "AudioHum"
			hum.stream = stream
			hum.bus = _bus(e)
			_apply_attenuation(hum, e)
			hum.volume_db = float(cfg.get("volume_db", -8.0)) + float(_opt(e, "volume_db", 0.0))
			hum.position = Vector3.UP * 1.4
			n.add_child(hum)
			hum.play()
			_hums[id] = hum
		elif not on and hum != null:
			hum.queue_free()
			_hums.erase(id)


func _clear_hums() -> void:
	for h: Variant in _hums.values():
		if is_instance_valid(h):
			(h as Node).queue_free()
	_hums.clear()
