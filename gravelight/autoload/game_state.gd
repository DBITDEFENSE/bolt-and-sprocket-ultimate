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
var bot_skill: String = "regular"
var bot_ids: Array[int] = []
var power_on: bool = false
var open_zones: Dictionary = {}    # zone_id -> true
var flags: Dictionary = {}         # e.g. {&"crate_has_moved": true}
var stats: Dictionary = {}
var god_mode: bool = false
var input_blocked: bool = false   # dev console / text entry open
var _start_msec: int = 0


func _ready() -> void:
	GLBus.enemy_killed.connect(_on_enemy_killed)
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
	stats = {&"kills": 0, &"headshots": 0, &"melee_kills": 0, &"scrip_earned": 0, &"doors": 0,
		&"downs": 0, &"boards": 0, &"round": 0}
	_start_msec = Time.get_ticks_msec()


func is_solo() -> bool:
	return player_ids.size() == 1


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


func _bump(key: StringName, amount: int = 1) -> void:
	if phase == Phase.PLAYING:
		stats[key] = int(stats.get(key, 0)) + amount


func _on_enemy_killed(_enemy_id: StringName, limb: StringName, weapon_id: StringName, _by: int) -> void:
	_bump(&"kills")
	if limb == &"head":
		_bump(&"headshots")
	if weapon_id == &"trench_knife" or weapon_id == &"etool":
		_bump(&"melee_kills")


func _on_scrip_changed(_player: int, _total: int, delta: int) -> void:
	if delta > 0:
		_bump(&"scrip_earned", delta)


func _on_door_opened(_door: StringName, _player: int) -> void:
	_bump(&"doors")


func _on_player_downed(_player: int) -> void:
	_bump(&"downs")


func _on_board_repaired(_window: StringName, _player: int) -> void:
	_bump(&"boards")
