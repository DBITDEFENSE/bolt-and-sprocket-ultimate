class_name ZoneAmbience
extends Node
## Per-zone ambience (UPDATE 09 section 5, DECISIONS T-145): a looping bed per zone that crossfades when the local
## player walks from one zone into the next, plus one-shots at random intervals (a gull, a drip, the teletype).
## MapRoot attaches one when `data/gravelight/ambience/<map_id>.json` (or `<map prefix>.json`, e.g. `map02.json`)
## exists. Schema (validate() checks it; the unit test runs it over every file in the folder):
##   {"crossfade_s": 1.5,
##    "zones": {"<ZONE_ID>": {"bed": "<AudioDirector key or res:// path>", "db": -8.0,
##                            "oneshots": [{"key": "<key or res://>", "every_s": [8, 20], "db": -6,
##                                          "spatial": false}]}}}
## The zone comes from the ZoneVolume boxes under the listener (the local player; ZoneVolume.zone_at, the same
## boxes the director and the HUD's zone stamp use); a position between boxes keeps the zone it had (no flapping at
## a seam). Beds play on the Ambience bus and sit on top of AudioDirector's map bed (audio.json music.ambient).
## Presentation only: never networked, silent when the map's player is a puppet (not local). The fade logic works
## without a stream (a bed entry whose key does not resolve still fades its "db"), so the tests drive it headless.

const DIR: String = "res://data/gravelight/ambience/"
const SILENT_DB: float = -60.0
const POLL_S: float = 0.25

var config: Dictionary = {}
var crossfade_s: float = 1.5
var current_zone: StringName = &""
## The node whose position picks the zone. Null: the parent map's `player`, else the viewport camera.
var listener: Node3D = null
var enabled: bool = true
var oneshots_played: int = 0
var _beds: Array[Dictionary] = []   # {key, zone, player (Node or null), db, from_db, to_db, t, dur, out}
var _timers: Array[float] = []      # seconds to the next one-shot of the current zone, per entry
var _poll: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## The ambience file for a map id: `<map_id>.json`, else `<prefix before the first underscore>.json`; "" if none.
static func config_path(map_id: StringName) -> String:
	var full: String = DIR + String(map_id) + ".json"
	if FileAccess.file_exists(full):
		return full
	var short: String = DIR + String(map_id).get_slice("_", 0) + ".json"
	if FileAccess.file_exists(short):
		return short
	return ""


static func load_config(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


## Schema problems in a config (empty when it is valid). Keys are not resolved here (resolvable() does that).
static func validate(cfg: Dictionary) -> PackedStringArray:
	var errs: PackedStringArray = []
	if not cfg.has("zones") or not (cfg["zones"] is Dictionary):
		errs.append("no 'zones' dictionary")
		return errs
	if cfg.has("crossfade_s") and not (cfg["crossfade_s"] is float or cfg["crossfade_s"] is int):
		errs.append("crossfade_s is not a number")
	for z: String in (cfg["zones"] as Dictionary).keys():
		var zc: Variant = cfg["zones"][z]
		if not (zc is Dictionary):
			errs.append("%s: not a dictionary" % z)
			continue
		if not (zc as Dictionary).has("bed") or str(zc["bed"]) == "":
			errs.append("%s: no bed" % z)
		if (zc as Dictionary).has("db") and not (zc["db"] is float or zc["db"] is int):
			errs.append("%s: db is not a number" % z)
		for os: Variant in (zc as Dictionary).get("oneshots", []):
			if not (os is Dictionary) or str((os as Dictionary).get("key", "")) == "":
				errs.append("%s: a one-shot without a key" % z)
				continue
			var ev: Variant = (os as Dictionary).get("every_s", [])
			if not (ev is Array) or (ev as Array).size() != 2 or float(ev[0]) <= 0.0 or float(ev[1]) < float(ev[0]):
				errs.append("%s: one-shot %s needs every_s [min, max] with 0 < min <= max" % [z, str(os["key"])])
	return errs


## A zone marked `vacuum: true` (Mondlicht's yard, T-149): its bed is the suit and the map's bed goes silent.
static func is_vacuum(cfg: Dictionary, zone: StringName) -> bool:
	return bool(((cfg.get("zones", {}) as Dictionary).get(String(zone), {}) as Dictionary).get("vacuum", false))


func _exit_tree() -> void:
	AudioDirector.set_vacuum_bed(false)


## Whether a bed / one-shot key plays: a res:// stream that exists, or an AudioDirector key with files.
static func resolvable(key: String) -> bool:
	if key.begins_with("res://"):
		return ResourceLoader.exists(key)
	var ad: Node = Engine.get_main_loop().root.get_node_or_null("AudioDirector") if Engine.get_main_loop() is SceneTree else null
	return ad != null and bool(ad.call("has_sound", key))


## Adds the node under a MapRoot when the map has an ambience file; returns it (null when there is none).
static func attach(map_root: Node) -> ZoneAmbience:
	var path: String = config_path(StringName(str(map_root.get("map_id"))))
	if path == "":
		return null
	var cfg: Dictionary = load_config(path)
	if not validate(cfg).is_empty():
		push_warning("ZoneAmbience: %s is invalid: %s" % [path, ", ".join(validate(cfg))])
		return null
	var za: ZoneAmbience = ZoneAmbience.new()
	za.name = "ZoneAmbience"
	za.setup(cfg)
	map_root.add_child(za)
	return za


func setup(cfg: Dictionary) -> void:
	config = cfg
	crossfade_s = maxf(0.0, float(cfg.get("crossfade_s", 1.5)))
	_rng.randomize()


func zones() -> Dictionary:
	return config.get("zones", {})


func _process(delta: float) -> void:
	if not enabled:
		return
	_poll -= delta
	if _poll <= 0.0:
		_poll = POLL_S
		var who: Node3D = _listener()
		if who == null:
			if not _beds.is_empty():
				set_zone(&"")   # a puppet or no player: fade out and stay silent
		else:
			var z: StringName = ZoneVolume.zone_at(get_tree(), who.global_position + Vector3.UP * 0.2)
			if z != &"" and z != current_zone:
				set_zone(z)
	advance(delta)


## The local listener: `listener`, else the map's player when it is local (puppets get silence), else the camera.
func _listener() -> Node3D:
	if listener != null and is_instance_valid(listener):
		return listener
	var p: Node3D = get_parent().get("player") as Node3D if get_parent() != null else null
	if p != null and is_instance_valid(p):
		return p if bool(p.get("is_local")) else null
	var vp: Viewport = get_viewport()
	return vp.get_camera_3d() if vp != null else null


## Switches to a zone: every bed playing fades out over crossfade_s and the zone's bed fades in from silence.
## A zone with no entry (or &"") fades to silence. The one-shot timers restart for the new zone.
func set_zone(z: StringName) -> void:
	if z == current_zone:
		return
	current_zone = z
	for b: Dictionary in _beds:
		if not bool(b["out"]):
			_fade(b, SILENT_DB, true)
	_timers.clear()
	var zc: Dictionary = zones().get(String(z), {})
	if is_inside_tree():
		AudioDirector.set_vacuum_bed(is_vacuum(config, z))   # T-149: a vacuum zone hears only the suit
	var key: String = str(zc.get("bed", ""))
	if key != "":
		var b2: Dictionary = {"key": key, "zone": z, "player": _make_player(key), "db": SILENT_DB, "out": false}
		_fade(b2, float(zc.get("db", -8.0)), false)
		_beds.append(b2)
		var pl: Node = b2["player"]
		if pl != null:
			pl.set("volume_db", SILENT_DB)
			add_child(pl)
			pl.call("play")
	for os: Variant in zc.get("oneshots", []):
		_timers.append(_interval(os as Dictionary))


func _fade(b: Dictionary, to_db: float, out: bool) -> void:
	b["from_db"] = float(b["db"])
	b["to_db"] = to_db
	b["t"] = 0.0
	b["dur"] = crossfade_s
	b["out"] = out


## Steps the fades and the one-shot timers by `delta` seconds (called from _process; tests call it directly).
func advance(delta: float) -> void:
	var done: Array[Dictionary] = []
	for b: Dictionary in _beds:
		var dur: float = float(b["dur"])
		b["t"] = minf(float(b["t"]) + delta, dur)
		var k: float = 1.0 if dur <= 0.0 else float(b["t"]) / dur
		# amplitude crossfade (linear in gain, not in dB, so the two beds sum to a steady loudness)
		var g: float = lerpf(db_to_linear(float(b["from_db"])), db_to_linear(float(b["to_db"])), k)
		b["db"] = maxf(SILENT_DB, linear_to_db(maxf(g, 0.000001)))
		var pl: Node = b["player"]
		if pl != null and is_instance_valid(pl):
			pl.set("volume_db", float(b["db"]))
		if bool(b["out"]) and k >= 1.0:
			done.append(b)
	for b2: Dictionary in done:
		var pl2: Node = b2["player"]
		if pl2 != null and is_instance_valid(pl2):
			pl2.queue_free()
		_beds.erase(b2)
	var list: Array = zones().get(String(current_zone), {}).get("oneshots", [])
	for i: int in mini(_timers.size(), list.size()):
		_timers[i] -= delta
		if _timers[i] <= 0.0:
			_timers[i] = _interval(list[i] as Dictionary)
			_play_oneshot(list[i] as Dictionary)


## True while any bed is still moving towards its target level.
func fading() -> bool:
	for b: Dictionary in _beds:
		if float(b["t"]) < float(b["dur"]):
			return true
	return false


## The beds still sounding (fading in, playing, or fading out): [{key, zone, db, out}].
func beds() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b: Dictionary in _beds:
		out.append({"key": b["key"], "zone": b["zone"], "db": b["db"], "out": b["out"]})
	return out


func _interval(os: Dictionary) -> float:
	var ev: Array = os.get("every_s", [10.0, 20.0])
	return _rng.randf_range(float(ev[0]), float(ev[1]))


func _make_player(key: String) -> Node:
	if key.begins_with("res://"):
		if not ResourceLoader.exists(key):
			return null
		var s: AudioStream = load(key) as AudioStream
		if s == null:
			return null
		if s is AudioStreamWAV and (s as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED:
			var w: AudioStreamWAV = s as AudioStreamWAV
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(w.get_length() * float(w.mix_rate))
		elif s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.name = "Bed"
		p.stream = s
		p.bus = &"Ambience" if AudioServer.get_bus_index("Ambience") >= 0 else &"Master"
		return p
	var ad: Node = get_node_or_null("/root/AudioDirector")
	if ad == null or not bool(ad.call("has_sound", key)):
		return null
	# make_loop_2d parents the player itself; take it back so set_zone owns when it enters the tree
	var holder: Node = Node.new()
	var lp: Node = ad.call("make_loop_2d", key, holder, 0.0)
	if lp != null:
		holder.remove_child(lp)
		lp.name = "Bed_" + key
	holder.free()
	return lp


func _play_oneshot(os: Dictionary) -> void:
	var key: String = str(os.get("key", ""))
	var db: float = float(os.get("db", 0.0))
	oneshots_played += 1
	if key.begins_with("res://"):
		if not ResourceLoader.exists(key):
			return
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.stream = load(key) as AudioStream
		p.volume_db = db
		p.bus = &"Ambience" if AudioServer.get_bus_index("Ambience") >= 0 else &"Master"
		add_child(p)
		p.finished.connect(p.queue_free)
		p.play()
		return
	var ad: Node = get_node_or_null("/root/AudioDirector")
	if ad == null:
		return
	var who: Node3D = _listener()
	if bool(os.get("spatial", false)) and who != null and is_inside_tree():
		var a: float = _rng.randf() * TAU
		var r: float = _rng.randf_range(5.0, 14.0)
		ad.call("play_3d", key, who.global_position + Vector3(cos(a) * r, _rng.randf_range(1.0, 4.0), sin(a) * r), db)
	else:
		ad.call("play_2d", key, db)
