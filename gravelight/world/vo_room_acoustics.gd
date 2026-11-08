class_name VORoomAcoustics
extends Node
## T-205 (the owner: "it shouldn't sound like they're speaking to us out of a rap studio"): the spoken lines sit in the
## space they are spoken in. GLVO owns one of these (GLVO.rooms). The VO bus gets two effects of its own, a gentle EQ
## (AudioEffectEQ6) and a low-wet reverb, and their settings come from one preset of data/gravelight/vo_rooms.json at
## a time, chosen in this order:
##   1. a LAZARUS cutscene playing (CinemaReel calls set_cinema): the shot's own `vo_room`, else its set's preset
##      (cinema_sets), else dry;
##   2. the map zone the local player stands in (ZoneVolume.zone_at, the boxes ZoneAmbience and the HUD use; between
##      boxes the last zone holds), from maps.<map_id>.zones;
##   3. the map's default (maps.<map_id>.default);
##   4. dry (menus, a map without an entry, the setting off).
## Presets crossfade over `fade_s`; a dry preset disables both effects (no cost). Positional lines keep their 3D
## attenuation: the room is applied on the bus, after it.
## Lines that already carry their channel from the bake (data/voice/fx.json: the tannoy, radios, PA, phonograph, the
## Cousins' room) and lines cued [radio] / [intercom] / [static] ... play on the VODry bus instead (bus_for): it has the
## same volume setting (vol_vo) and no room, so a radio voice is not put in a second room. The setting
## `vo_room_acoustics` (Settings > Audio > Room acoustics, default on) forces dry.

const DATA_PATH: String = "res://data/gravelight/vo_rooms.json"
const ROOM_BUS: StringName = &"VO"
const DRY_BUS: StringName = &"VODry"
const EQ_NAME: String = "VORoomEQ"
const REVERB_NAME: String = "VORoomReverb"
const SETTING: String = "vo_room_acoustics"
const POLL_S: float = 0.25
const DRY: StringName = &"dry"
## The numeric reverb fields a preset may set, with the values a preset that leaves one out gets.
const REVERB_DEFAULTS: Dictionary = {"wet": 0.0, "room_size": 0.3, "damping": 0.5, "spread": 0.6, "hipass": 0.3,
	"predelay_ms": 20.0, "predelay_feedback": 0.05}

var data: Dictionary = {}
var fade_s: float = 0.8
## The preset being applied (the target of the current crossfade).
var preset_id: StringName = DRY
## The map whose presets apply ("" = none: dry). Tracked from the current scene (a MapRoot); tests set map_override.
var map_id: StringName = &""
var map_override: StringName = &""
## The zone the listener was last inside ("" = none yet).
var zone: StringName = &""
## The preset a playing cutscene asked for ("" = no cutscene).
var cinema_preset: StringName = &""
## The node whose position picks the zone. Null: the map's `player`, else the viewport camera.
var listener: Node3D = null

var _eq: AudioEffectEQ6 = null
var _reverb: AudioEffectReverb = null
var _cur: Dictionary = {}      # the values on the effects now
var _from: Dictionary = {}     # the values the crossfade started from
var _to: Dictionary = {}       # the values it goes to
var _t: float = 1.0            # crossfade progress 0..1
var _poll: float = 0.0
var _map_ref: WeakRef = null
var _warned: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_data()
	ensure_buses()
	_cur = values_of(DRY)
	_to = _cur.duplicate()
	_apply_values(_cur)


func load_data() -> void:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
	data = d if d is Dictionary else {}
	fade_s = maxf(0.0, float(data.get("fade_s", 0.8)))


func presets() -> Dictionary:
	return data.get("presets", {})


func has_preset(id: StringName) -> bool:
	return presets().has(String(id))


# ================================================================== the buses

## The VODry bus (sends to Master) and the VO bus's EQ + reverb, added once (found again by resource_name).
func ensure_buses() -> void:
	if AudioServer.get_bus_index(DRY_BUS) == -1:
		AudioServer.add_bus()
		var di: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(di, DRY_BUS)
		AudioServer.set_bus_send(di, &"Master")
	var bus: int = AudioServer.get_bus_index(ROOM_BUS)
	if bus < 0:
		return
	for i: int in AudioServer.get_bus_effect_count(bus):
		var fx: AudioEffect = AudioServer.get_bus_effect(bus, i)
		if fx is AudioEffectEQ6 and fx.resource_name == EQ_NAME:
			_eq = fx as AudioEffectEQ6
		elif fx is AudioEffectReverb and fx.resource_name == REVERB_NAME:
			_reverb = fx as AudioEffectReverb
	if _eq == null:
		_eq = AudioEffectEQ6.new()
		_eq.resource_name = EQ_NAME
		AudioServer.add_bus_effect(bus, _eq)
	if _reverb == null:
		_reverb = AudioEffectReverb.new()
		_reverb.resource_name = REVERB_NAME
		_reverb.dry = 1.0
		AudioServer.add_bus_effect(bus, _reverb)


## The bus effect index of the EQ / reverb on the VO bus (-1 when missing).
func effect_index(fx_name: String) -> int:
	var bus: int = AudioServer.get_bus_index(ROOM_BUS)
	if bus < 0:
		return -1
	for i: int in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i).resource_name == fx_name:
			return i
	return -1


func effects_enabled() -> bool:
	var bus: int = AudioServer.get_bus_index(ROOM_BUS)
	var ri: int = effect_index(REVERB_NAME)
	var ei: int = effect_index(EQ_NAME)
	return bus >= 0 and ((ri >= 0 and AudioServer.is_bus_effect_enabled(bus, ri)) or (ei >= 0 and AudioServer.is_bus_effect_enabled(bus, ei)))


func reverb() -> AudioEffectReverb:
	return _reverb


func eq() -> AudioEffectEQ6:
	return _eq


# ================================================================== choosing

func enabled() -> bool:
	var s: Node = get_node_or_null("/root/GLSettings")
	return s == null or bool((s.get("values") as Dictionary).get(SETTING, true))


## The preset id for a map and zone ("" zone = the map's default); dry when the map has no entry.
func preset_for_map(map: StringName, zone_id: StringName = &"") -> StringName:
	var m: Dictionary = (data.get("maps", {}) as Dictionary).get(String(map), {})
	if m.is_empty():
		return DRY
	if zone_id != &"":
		var zs: Dictionary = m.get("zones", {})
		if zs.has(String(zone_id)):
			return _valid(StringName(str(zs[String(zone_id)])))
	return _valid(StringName(str(m.get("default", "dry"))))


## The preset for a cutscene shot: its own `vo_room` field, else its set's (cinema_sets), else dry.
func preset_for_shot(set_id: String, shot: Dictionary = {}) -> StringName:
	if str(shot.get("vo_room", "")) != "":
		return _valid(StringName(str(shot["vo_room"])))
	var cs: Dictionary = data.get("cinema_sets", {})
	return _valid(StringName(str(cs.get(set_id, "dry"))))


func _valid(id: StringName) -> StringName:
	if has_preset(id):
		return id
	if not _warned.has(id):
		_warned[id] = true
		push_warning("[vo_rooms] unknown preset %s: dry" % id)
	return DRY


## What should apply right now (the order in the header).
func resolve() -> StringName:
	if not enabled():
		return DRY
	if cinema_preset != &"":
		return _valid(cinema_preset)
	if map_id == &"":
		return DRY
	return preset_for_map(map_id, zone)


## A cutscene shot started on `set_id` (CinemaReel); "" clears it (the reel ended): back to the map's room.
func set_cinema(preset: StringName) -> void:
	cinema_preset = preset
	refresh()


func clear_cinema() -> void:
	set_cinema(&"")


## Re-picks the preset now and starts the crossfade to it (also called by the poll).
func refresh(instant: bool = false) -> void:
	var want: StringName = resolve()
	if want == preset_id and not instant:
		return
	if want != preset_id:
		print("[vo_rooms] %s -> %s (map %s, zone %s%s)" % [preset_id, want, map_id if map_id != &"" else &"-",
			zone if zone != &"" else &"-", ", cutscene" if cinema_preset != &"" else ""])
	preset_id = want
	_from = _cur.duplicate()
	_to = values_of(want)
	_t = 0.0
	if instant or fade_s <= 0.0:
		_t = 1.0
		_cur = _to.duplicate()
		_apply_values(_cur)


## The values a preset puts on the effects ({wet, room_size, ..., eq: [6 dB]}).
func values_of(id: StringName) -> Dictionary:
	var p: Dictionary = presets().get(String(id), {})
	var out: Dictionary = {}
	for k: String in REVERB_DEFAULTS.keys():
		out[k] = float(p.get(k, REVERB_DEFAULTS[k]))
	var eqv: Array = []
	var src: Array = p.get("eq", [])
	for i: int in 6:
		eqv.append(float(src[i]) if i < src.size() else 0.0)
	out["eq"] = eqv
	return out


# ================================================================== where the listener is

func _process(delta: float) -> void:
	_poll -= delta
	if _poll <= 0.0:
		_poll = POLL_S
		_track_map()
		_track_zone()
		refresh()
	if _t < 1.0:
		_t = minf(1.0, _t + delta / maxf(0.01, fade_s))
		_cur = _lerp_values(_from, _to, _t)
		_apply_values(_cur)


func _track_map() -> void:
	if map_override != &"":
		map_id = map_override
		return
	var m: Node = _map_ref.get_ref() as Node if _map_ref != null else null
	if m == null or not m.is_inside_tree():
		m = null
		_map_ref = null
		var cs: Node = get_tree().current_scene if is_inside_tree() else null
		if cs is MapRoot:
			m = cs
			_map_ref = weakref(cs)
	var id: StringName = StringName(str(m.get("map_id"))) if m != null else &""
	if id != map_id:
		map_id = id
		zone = &""


func _track_zone() -> void:
	if map_id == &"" or not is_inside_tree():
		return
	var l: Node3D = _listener()
	if l == null or not l.is_inside_tree():
		return
	var z: StringName = ZoneVolume.zone_at(get_tree(), l.global_position)
	if z != &"":
		zone = z


func _listener() -> Node3D:
	if listener != null and is_instance_valid(listener):
		return listener
	var m: Node = _map_ref.get_ref() as Node if _map_ref != null else null
	if m != null:
		var p: Variant = m.get("player")
		if p is Node3D and is_instance_valid(p):
			return p as Node3D
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	return cam


# ================================================================== applying

static func _lerp_values(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out: Dictionary = {}
	for k: String in REVERB_DEFAULTS.keys():
		out[k] = lerpf(float(a.get(k, REVERB_DEFAULTS[k])), float(b.get(k, REVERB_DEFAULTS[k])), t)
	var ea: Array = a.get("eq", [0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	var eb: Array = b.get("eq", [0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	var e: Array = []
	for i: int in 6:
		e.append(lerpf(float(ea[i]), float(eb[i]), t))
	out["eq"] = e
	return out


func _apply_values(v: Dictionary) -> void:
	if _reverb == null or _eq == null:
		return
	_reverb.wet = clampf(float(v["wet"]), 0.0, 1.0)
	_reverb.dry = 1.0
	_reverb.room_size = clampf(float(v["room_size"]), 0.0, 1.0)
	_reverb.damping = clampf(float(v["damping"]), 0.0, 1.0)
	_reverb.spread = clampf(float(v["spread"]), 0.0, 1.0)
	_reverb.hipass = clampf(float(v["hipass"]), 0.0, 1.0)
	_reverb.predelay_msec = clampf(float(v["predelay_ms"]), 20.0, 500.0)
	_reverb.predelay_feedback = clampf(float(v["predelay_feedback"]), 0.0, 0.98)
	var eq_on: bool = false
	for i: int in 6:
		var g: float = float((v["eq"] as Array)[i])
		_eq.set_band_gain_db(i, g)
		eq_on = eq_on or absf(g) > 0.01
	var bus: int = AudioServer.get_bus_index(ROOM_BUS)
	var ri: int = effect_index(REVERB_NAME)
	var ei: int = effect_index(EQ_NAME)
	if bus >= 0 and ri >= 0:
		AudioServer.set_bus_effect_enabled(bus, ri, _reverb.wet > 0.001)
	if bus >= 0 and ei >= 0:
		AudioServer.set_bus_effect_enabled(bus, ei, eq_on)


# ================================================================== which bus a line plays on

## VODry for a line that already carries its channel (fx.json speakers, dry_categories, a [radio]-like cue), else VO.
func bus_for(speaker: StringName, category: String = "", text: String = "") -> StringName:
	return DRY_BUS if is_dry_line(speaker, category, text) else ROOM_BUS


func is_dry_line(speaker: StringName, category: String = "", text: String = "") -> bool:
	if (data.get("dry_speakers", []) as Array).has(String(speaker)):
		return true
	var dc: Dictionary = data.get("dry_categories", {})
	if dc.has(String(speaker)) and (dc[String(speaker)] as Array).has(category):
		return true
	return has_dry_cue(text)


## True when a `[cue]` in the text names a channel (radio, intercom, static, tannoy, phonograph, PA ...).
func has_dry_cue(text: String) -> bool:
	if text.find("[") < 0:
		return false
	var cues: Array = data.get("dry_cues", [])
	var words: Array = data.get("dry_cue_words", [])
	var re: RegEx = RegEx.create_from_string("\\[([^\\]]*)\\]")
	for m: RegExMatch in re.search_all(text):
		var c: String = m.get_string(1).to_lower()
		for s: Variant in cues:
			if c.contains(str(s)):
				return true
		for w: String in c.replace(",", " ").replace(";", " ").replace(":", " ").split(" ", false):
			if words.has(w):
				return true
	return false
