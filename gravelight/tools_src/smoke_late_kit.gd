extends Node
## Headless smoke for UPDATE 08 section 3 (T-130): the bots' late kit on Map 0 with three bots.
## 1. Round 24: a bot (re)spawning gets no late kit.
## 2. Round 25 starts: every live bot gets a tier III tonic (no two the same, none it held) and the Chicago Lament II.
## 3. A bot that bled out and respawns at round 25+ gears up again (its tonics were lost, its kit comes back).
## 4. The Bot Bonus Perk toggle off: nothing.
## T-186, the round-30 kit (bots.json r30_kit), on top of it:
## 5. Round 29 starts: nothing new (no bot holds every tonic).
## 6. Round 30 starts: every live bot holds every tonic in perks.json and a main gun taught to weapon_tier, its late
##    tonic still at tier III (the two kits stack).
## 7. A bot that bleeds out and respawns at round 31 (start pistol only) comes back with all of it.
## 8. A down and a revive at round 31: the tonics wait for the next round start, which brings them back.
## 9. The Bot Bonus Perk toggle off at round 33: nothing.
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
	_r30(bots)
	_end()


func _taught(p: Player) -> String:
	var out: PackedStringArray = []
	for w: WeaponInstance in p.weapons.slots:
		out.append("%s%s" % [w.id, (" t%d" % w.tier) if w.upgraded else ""])
	return ", ".join(out)


func _r30(bots: Array[Player]) -> void:
	var all_n: int = (GLData.table("perks")["perks"] as Dictionary).size()
	var tier: int = int((GLData.table("bots")["r30_kit"] as Dictionary)["weapon_tier"])
	# 5. round 29: nothing new
	RoundManager.current_round = 29
	GLBus.round_started.emit(29, false)
	for p: Player in bots:
		print("[r30] round 29 %s: %d tonics, guns %s" % [p.name, PerkManager.owned(p.player_id).size(), _taught(p)])
		if PerkManager.owned(p.player_id).size() >= all_n or _map.squad.r30_kit_held(p):
			_fail("%s has the round-30 kit at round 29" % p.name)
	# 6. round 30 starts: every live bot
	RoundManager.current_round = 30
	GLBus.round_started.emit(30, false)
	for p: Player in bots:
		var cw: WeaponInstance = p.weapons.current()
		var late: Array = _late(p)
		print("[r30] round 30 %s: %d/%d tonics, guns %s, in hand %s, late tonic %s at %d" % [p.name, PerkManager.owned(p.player_id).size(), all_n,
			_taught(p), str(cw.id) if cw != null else "-", late[0], late[1]])
		if PerkManager.owned(p.player_id).size() != all_n or not _map.squad.r30_kit_held(p):
			_fail("%s lacks the round-30 kit at round 30" % p.name)
		if cw == null or not cw.upgraded or cw.tier < tier:
			_fail("%s isn't holding a gun taught to %d" % [p.name, tier])
		if int(late[1]) != 3:
			_fail("%s's late tonic lost its tier III (the kits should stack)" % p.name)
	if _map.squad.apply_r30_kit(bots[0]):
		_fail("the round-30 kit isn't idempotent")
	# 6b. a better gun the bot taught once itself (an MG42 at the Crucible) is its main gun: taught to the tier in place
	bots[0].weapons.give_weapon(&"mg42_up")
	_map.squad.apply_r30_kit(bots[0])
	var mg: WeaponInstance = bots[0].weapons.find_weapon(&"mg42_up")
	print("[r30] main gun taught once: %s, in hand %s" % [_taught(bots[0]), str(bots[0].weapons.current().id)])
	if mg == null or mg.tier < tier or bots[0].weapons.current() != mg:
		_fail("the main gun (an MG42 taught once) wasn't taught to %d in hand" % tier)
	# 7. a bleed-out and a respawn at round 31: the start loadout, then the kits
	RoundManager.current_round = 31
	var b1: Player = bots[1]
	PerkManager.on_player_downed(b1.player_id)
	b1.weapons.reset_loadout()
	_map.squad.apply_kit(b1, true)
	print("[r30] respawn at 31: %d tonics, guns %s" % [PerkManager.owned(b1.player_id).size(), _taught(b1)])
	if PerkManager.owned(b1.player_id).size() != all_n or not _map.squad.r30_kit_held(b1):
		_fail("a bot respawning at round 31 didn't come back with the round-30 kit")
	# 7b. nothing but the start pistol (the kit's own guns missing): the fallback gun, taught
	b1.weapons.reset_loadout()
	_map.squad.apply_r30_kit(b1)
	var fb: WeaponInstance = b1.weapons.find_weapon(StringName(str((GLData.table("bots")["r30_kit"] as Dictionary)["fallback_weapon"])))
	print("[r30] pistol only: %s" % _taught(b1))
	if fb == null or fb.tier < tier or b1.weapons.slots.size() < 2:
		_fail("a bot with only a pistol didn't get the fallback gun taught to %d next to it" % tier)
	# 8. a down and a revive at round 31: not until the next round start
	var b2: Player = bots[2]
	PerkManager.on_player_downed(b2.player_id)
	_map.squad.apply_kit(b2, false)
	var after_rev: int = PerkManager.owned(b2.player_id).size()
	print("[r30] revived at 31: %d tonics" % after_rev)
	if after_rev >= all_n:
		_fail("a revive gave every tonic back mid-round (on_revive is false)")
	RoundManager.current_round = 32
	GLBus.round_started.emit(32, false)
	print("[r30] round 32 after the revive: %d tonics" % PerkManager.owned(b2.player_id).size())
	if PerkManager.owned(b2.player_id).size() != all_n:
		_fail("the next round start didn't bring the revived bot's tonics back")
	# 9. the toggle off
	GLSettings.values["bot_bonus_perk"] = false
	PerkManager.on_player_downed(b2.player_id)
	RoundManager.current_round = 33
	GLBus.round_started.emit(33, false)
	if _map.squad.apply_r30_kit(b2) or PerkManager.owned(b2.player_id).size() >= all_n:
		_fail("the round-30 kit ignored the Bot Bonus Perk toggle")
	GLSettings.values["bot_bonus_perk"] = true


func _fail(msg: String) -> void:
	_fails.append(msg)
	print("[latekit] FAIL: ", msg)


func _end() -> void:
	print("[latekit] RESULT %s" % ("PASS" if _fails.is_empty() else "FAIL (%d)" % _fails.size()))
	get_tree().quit(0 if _fails.is_empty() else 1)
