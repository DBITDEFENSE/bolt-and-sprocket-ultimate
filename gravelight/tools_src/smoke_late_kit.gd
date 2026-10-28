extends Node
## Headless smoke for UPDATE 08 section 3 (T-130): the bots' late kit on Map 0 with three bots.
## 1. Round 24: a bot (re)spawning gets no late kit.
## 2. Round 25 starts: every live bot gets a tier III tonic (no two the same, none it held) and the Chicago Lament II.
## 3. A bot that bled out and respawns at round 25+ gears up again (its tonics were lost, its kit comes back).
## 4. The Bot Bonus Perk toggle off: nothing.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_late_kit.tscn

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"

var _map: MapRoot
var _frames: int = 0
var _fails: PackedStringArray = []


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GameState.bot_count = 3
	GameState.god_mode = true
	GLSettings.values["bot_bonus_perk"] = true
	GLSettings.values["classic_rules"] = false
	_map = (load(MAP) as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)


func _bots() -> Array[Player]:
	var out: Array[Player] = []
	if _map.squad == null:
		return out
	for b: BotBrain in _map.squad.brains:
		if b.player != null and b.player.is_bot and not b.player.is_companion:
			out.append(b.player)
	return out


func _late(p: Player) -> Array:
	var lcfg: Dictionary = GLData.table("bots")["late_kit"]
	var w: WeaponInstance = p.weapons.find_weapon(StringName(str(lcfg["weapon"])))
	var perk: String = str(_map.squad.late_perk.get(p.player_id, ""))
	return [perk, PerkManager.tier_of(p.player_id, StringName(perk)) if perk != "" else 0, w.tier if w != null else 0]


func _physics_process(_delta: float) -> void:
	if not _map.is_inside_tree():
		return
	_frames += 1
	if _frames != 90:
		return
	var bots: Array[Player] = _bots()
	if bots.size() < 3:
		_fail("only %d bots" % bots.size())
		_end()
		return
	# 1. round 24: a respawn kit, no late kit
	RoundManager.current_round = 24
	_map.squad.apply_kit(bots[0], true)
	var l0: Array = _late(bots[0])
	print("[latekit] round 24 respawn: %s" % str(l0))
	if str(l0[0]) != "" or int(l0[2]) != 0:
		_fail("a bot got the late kit at round 24: %s" % str(l0))
	# 2. round 25 starts: everyone gears up
	RoundManager.current_round = 25
	GLBus.round_started.emit(25, false)
	var seen: Array = []
	for p: Player in bots:
		var l: Array = _late(p)
		print("[latekit] round 25 %s: tonic %s at %d, Thompson tier %d, holding %s" % [p.name, l[0], l[1], l[2], str(p.weapons.current().id)])
		if str(l[0]) == "" or int(l[1]) != 3:
			_fail("%s has no tier III late tonic" % p.name)
		if int(l[2]) != 2:
			_fail("%s has no Chicago Lament II" % p.name)
		if seen.has(str(l[0])):
			_fail("two bots share the late tonic %s" % l[0])
		seen.append(str(l[0]))
		if PerkManager.is_bonus(p.player_id, StringName(str(l[0]))):
			_fail("%s's late tonic is its bonus perk" % p.name)
	# 3. a bleed-out and respawn at round 25+: its tonics go (the down), the kit comes back with the respawn
	var b1: Player = bots[1]
	var had: String = str(_late(b1)[0])
	PerkManager.on_player_downed(b1.player_id)
	if PerkManager.has_perk(b1.player_id, StringName(had)):
		_fail("the late tonic survived a down (it isn't permanent)")
	_map.squad.apply_kit(b1, true)
	var l1: Array = _late(b1)
	print("[latekit] respawn at 25: %s" % str(l1))
	if int(l1[1]) != 3:
		_fail("a bot respawning at round 25 didn't gear up again")
	# 4. the toggle off
	GLSettings.values["bot_bonus_perk"] = false
	var b2: Player = bots[2]
	PerkManager.on_player_downed(b2.player_id)
	if _map.squad.apply_late_kit(b2):
		_fail("the late kit ignored the Bot Bonus Perk toggle")
	GLSettings.values["bot_bonus_perk"] = true
	_end()


func _fail(msg: String) -> void:
	_fails.append(msg)
	print("[latekit] FAIL: ", msg)


func _end() -> void:
	print("[latekit] RESULT %s" % ("PASS" if _fails.is_empty() else "FAIL (%d)" % _fails.size()))
	get_tree().quit(0 if _fails.is_empty() else 1)
