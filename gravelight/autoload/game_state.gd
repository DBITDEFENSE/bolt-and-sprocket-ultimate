extends Node
## Match state that must be identical on every peer: players, map, zones, power, flags, stats.
## Presentation code reads this; only authority code writes it.

enum Phase { MENU, PLAYING, GAME_OVER }

var phase: Phase = Phase.MENU
var map_id: StringName = &""
var map_display_name: String = ""
var player_ids: Array[int] = [1]
var character_id: StringName = &"dutch"     # the local player's survivor
var characters: Dictionary = {}           # co-op: player id -> survivor (empty in solo: everyone is character_id)
## AI teammates (T-031): how many the menu asked for and their skill preset; the ids they got this match.
var bot_count: int = 0
var bot_skill: String = "veteran"
var bot_ids: Array[int] = []
## The objective planner on one bot (data/gravelight/bots.json "local_ai"): "off", "scripted" (its own scores)
## or "local" (a local LLM through Ollama picks, the scores are the fallback).
var bot_ai_mode: String = "off"
var power_on: bool = false
var open_zones: Dictionary = {}    # zone_id -> true
var flags: Dictionary = {}         # e.g. {&"crate_has_moved": true}
var stats: Dictionary = {}
var god_mode: bool = false
var input_blocked: bool = false   # dev console / text entry open
var _start_msec: int = 0
## UPDATE 07 Map 4 Act IV (T-112): the map's gravity as a fraction of 1 g (the act json's `gravity_scale`; MapRoot
## sets it, 1.0 elsewhere), what a slide's distance is multiplied by, the act's vacuum rules (`vacuum` block: air
## seconds, refill seconds, damage per second, the air posts' radius; {} = no vacuum anywhere) and the Retained
## state of the renewal ending (T-113: the match goes on under the Plan).
var gravity_scale: float = 1.0
var slide_distance_mult: float = 1.0
var vacuum_cfg: Dictionary = {}
var retained: bool = false
var _g_base: Dictionary = {}


func _ready() -> void:
	GLBus.enemy_killed.connect(_on_enemy_killed)
	GLBus.marke_kill.connect(_on_marke_kill)
	GLBus.scrip_changed.connect(_on_scrip_changed)
	GLBus.door_opened.connect(_on_door_opened)
	GLBus.player_downed.connect(_on_player_downed)
	GLBus.board_repaired.connect(_on_board_repaired)


func reset_match(new_map_id: StringName, display_name: String, start_zone: StringName) -> void:
	map_id = new_map_id
	map_display_name = display_name
	phase = Phase.PLAYING
	power_on = false
	flags.clear()
	open_zones = {start_zone: true}
	gravity_scale = 1.0
	slide_distance_mult = 1.0
	vacuum_cfg = {}
	retained = false
	stats = {&"kills": 0, &"headshots": 0, &"melee_kills": 0, &"scrip_earned": 0, &"doors": 0,
		&"downs": 0, &"boards": 0, &"round": 0, &"marke_kills": 0}
	_start_msec = Time.get_ticks_msec()


func is_solo() -> bool:
	return player_ids.size() == 1


## The act's map-wide rules from its json block (MapRoot, after reset_match): gravity_scale, slide_distance_mult, vacuum.
func apply_act_physics(act: Dictionary) -> void:
	gravity_scale = clampf(float(act.get("gravity_scale", 1.0)), 0.05, 4.0)
	slide_distance_mult = maxf(0.1, float(act.get("slide_distance_mult", 1.0)))
	var v: Variant = act.get("vacuum", {})
	vacuum_cfg = (v as Dictionary).duplicate(true) if v is Dictionary else {}


func _gravity_table() -> Dictionary:
	if _g_base.is_empty():
		var w: Variant = GLData.table("world").get("gravity", {})
		_g_base = (w as Dictionary).duplicate() if w is Dictionary else {}
		if not _g_base.has("player"):
			_g_base["player"] = 14.0
		if not _g_base.has("zombie"):
			_g_base["zombie"] = 18.0
	return _g_base


## The survivors' (and bots') fall rate now, m/s^2: world.json gravity.player x gravity_scale.
func g_player() -> float:
	return float(_gravity_table().get("player", 14.0)) * gravity_scale


## The dead's fall rate now: world.json gravity.zombie x gravity_scale.
func g_zombie() -> float:
	return float(_gravity_table().get("zombie", 18.0)) * gravity_scale


## What a jump's take-off velocity is multiplied by here: gravity_scale ^ jump_velocity_exponent (world.json).
func jump_mult() -> float:
	var e: float = float(_gravity_table().get("jump_velocity_exponent", 0.0))
	return 1.0 if is_equal_approx(e, 0.0) or gravity_scale <= 0.0 else pow(gravity_scale, e)


## Pure: the jump height at `scale` g relative to 1 g (a test helper for the Moon's 2.6x).
static func jump_height_ratio(scale: float, exponent: float) -> float:
	var v: float = pow(scale, exponent)
	return v * v / maxf(0.001, scale)


func is_bot(pid: int) -> bool:
	return bot_ids.has(pid)


## The humans in the match (bots excluded).
func human_ids() -> Array[int]:
	var out: Array[int] = []
	for pid: int in player_ids:
		if not bot_ids.has(pid):
			out.append(pid)
	return out



## Character traits apply unless Classic Rules is on.
func traits_enabled() -> bool:
	return not bool(GLSettings.values.get("classic_rules", false))


func has_trait(character: StringName) -> bool:
	return traits_enabled() and character_id == character


## The survivor a player id plays (solo: the local character).
func character_of(pid: int) -> StringName:
	return StringName(characters.get(pid, character_id))


## Trait check for any player (host-side rules for remote players, e.g. Wren's headshot bonus).
func player_has_trait(pid: int, character: StringName) -> bool:
	return traits_enabled() and character_of(pid) == character


func is_zone_open(zone_id: StringName) -> bool:
	return open_zones.has(zone_id)


func open_zone(zone_id: StringName) -> void:
	if open_zones.has(zone_id):
		return
	open_zones[zone_id] = true
	GLBus.zone_opened.emit(zone_id)


func set_flag(flag: StringName, value: Variant = true) -> void:
	flags[flag] = value
	GLBus.flag_changed.emit(flag, value)
	if bool(value) and Net.is_authority():
		QuestManager.on_flag(flag)


func has_flag(flag: StringName) -> bool:
	return bool(flags.get(flag, false))


func elapsed_seconds() -> float:
	return float(Time.get_ticks_msec() - _start_msec) / 1000.0


## Campaign (T-033): the time played on the maps before this one counts toward the run's clock.
func credit_elapsed(seconds: float) -> void:
	_start_msec -= int(maxf(0.0, seconds) * 1000.0)


func _bump(key: StringName, amount: int = 1) -> void:
	if phase == Phase.PLAYING:
		stats[key] = int(stats.get(key, 0)) + amount


func _on_enemy_killed(_enemy_id: StringName, limb: StringName, weapon_id: StringName, _by: int) -> void:
	_bump(&"kills")
	if limb == &"head":
		_bump(&"headshots")
	if weapon_id == &"trench_knife" or weapon_id == &"etool":
		_bump(&"melee_kills")


## T-137: kills from a hit on the Marke (every mode; the bonus is the zombie's business and skips Classic Rules).
func _on_marke_kill(_by_player: int, _enemy_id: StringName) -> void:
	_bump(&"marke_kills")


func _on_scrip_changed(_player: int, _total: int, delta: int) -> void:
	if delta > 0 and not Economy.moving:   # (a bank withdrawal is no earning, T-136)
		_bump(&"scrip_earned", delta)


func _on_door_opened(_door: StringName, _player: int) -> void:
	_bump(&"doors")


func _on_player_downed(_player: int) -> void:
	_bump(&"downs")


func _on_board_repaired(_window: StringName, _player: int) -> void:
	_bump(&"boards")
