extends Node
## Headless smoke test for the voice pass (T-035): a solo match on Map 0 with 3 bots, chance rolls forced, rounds 1-3.
## Logs which VO categories fired for the Operator and each survivor, and asserts:
##   - the Operator announced the match, round starts and round ends
##   - the squad spoke SPAWN / ROUND_START / ROUND_END / DOOR / BUY / HEADSHOT / DOWN / TEAM_DOWN / REVIVE / REVIVED
##   - a round-break banter exchange played (naturally in the break, or forced at the end as a fallback)
##   - audio streams were actually started, 2D and positional (3D), on the Dummy audio driver
## Some triggers are nudged so the run stays short and deterministic: a bot is downed on purpose (a bot revives
## it), a human headshot kill, a wall buy, an ammo buy, a perk refusal and an intel pickup are emitted on GLBus
## as the gameplay systems would, and a door is opened by a bot through BuyDoor.open().
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_vo.tscn [-- --rounds=3]
## Prints "[vo] ..." lines and RESULT PASS/FAIL (exit code 0/1).

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const TIMEOUT: float = 480.0
const REQUIRED_OPR: Array[String] = ["MATCH_START", "ROUND_START", "ROUND_END"]
const REQUIRED_SQUAD: Array[String] = ["SPAWN", "ROUND_START", "ROUND_END", "DOOR", "BUY_", "HEADSHOT", "DOWN", "TEAM_DOWN",
	"REVIVE", "REVIVED"]

var _map: Node3D
var _t: float = 0.0
var _phase: int = 0
var _phase_t: float = 0.0
var _round_t: float = 0.0
var _fails: PackedStringArray = []
var _rounds_seen: Array[int] = []
var _fight_rounds: int = 3
var _done: bool = false
var _nudged: bool = false
var _downed_bot: Player = null
var _revives: Array = []
var _lines: Array = []          # [t, id, speaker]
var _banter_natural: bool = false
var _game_over: bool = false


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--rounds="):
			_fight_rounds = int(a.substr(9))
	ProfileSave.path = "user://_qa_vo_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GameState.character_id = &"peg"
	GameState.bot_count = 3
	GLVO.always_pass_chance = true
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GameState.god_mode = true
	GLBus.round_started.connect(func(r: int, _s: bool) -> void:
		_rounds_seen.append(r)
		_round_t = 0.0
		print("[vo] round %d at t=%.0fs" % [r, _t])
		if r == 2:
			for pid: int in GameState.bot_ids:
				Economy.grant(pid, 1200))
	GLBus.round_ended.connect(func(r: int) -> void: print("[vo] round %d ended at t=%.0fs (break %.1fs)" % [r, _t, RoundManager.break_left]))
	GLBus.vo_line_started.connect(func(id: StringName, spk: StringName, text: String, dur: float) -> void:
		_lines.append([_t, id, spk])
		if String(id).begins_with("BNT_") and RoundManager.state == RoundManager.State.BREAK:
			_banter_natural = true
		print("[vo]   %6.1fs %-4s %-28s %4.1fs  %s" % [_t, spk, id, dur, text.left(60)]))
	GLBus.player_revived.connect(func(p: int, by: int) -> void: _revives.append([p, by]))
	GLBus.game_over.connect(func(_s: Dictionary) -> void: _game_over = true)


func _fail(msg: String) -> void:
	_fails.append(msg)
	print("[vo] FAIL: ", msg)


func _root() -> MapRoot:
	return _map as MapRoot


func _bots() -> Array[Player]:
	var out: Array[Player] = []
	for n: Node in get_tree().get_nodes_in_group(&"bots"):
		out.append(n as Player)
	return out


func _physics_process(delta: float) -> void:
	if _done or _map == null or not _map.is_inside_tree():
		return
	_t += delta
	_phase_t += delta
	_round_t += delta
	if _t > TIMEOUT:
		_fail("timeout in phase %d" % _phase)
		_finish()
		return
	if _game_over:
		_fail("game over in phase %d" % _phase)
		_finish()
		return
	var root: MapRoot = _root()
	match _phase:
		0:
			if _phase_t < 2.0:
				return
			var bots: Array[Player] = _bots()
			if bots.size() != 3:
				_fail("expected 3 bots, found %d" % bots.size())
			if root.squad == null:
				_fail("no squad")
			else:
				# Force the bots' own REVIVE callout (rolled in BotSquad, not VOManager) for the smoke.
				var cc: Dictionary = root.squad._cfg.get("callouts", {})
				(cc.get("chance", {}) as Dictionary)["REVIVE"] = 1.0
			print("[vo] setup: %d bots, human plays %s" % [bots.size(), GameState.character_id])
			_phase = 1
			_phase_t = 0.0
		1:
			# Keep rounds short: clear the field every 25 s of a round.
			if RoundManager.state == RoundManager.State.ROUND and _round_t > 25.0:
				root.director.kill_all(false)
				_round_t = 10.0
			if not _nudged and RoundManager.current_round >= 1 and _round_t > 8.0:
				_nudged = true
				_nudge(root)
			if RoundManager.current_round >= 2 and _downed_bot == null and _round_t > 12.0:
				_downed_bot = _bots()[0]
				_downed_bot.take_hit(9999.0, null)
				print("[vo] downed %s (P%d) on purpose at t=%.0fs" % [Net.display_name(_downed_bot.player_id), _downed_bot.player_id, _t])
			if RoundManager.current_round > _fight_rounds or _phase_t > 400.0:
				_phase = 2
				_phase_t = 0.0
		2:
			# Let the last queued lines play, then force a banter exchange if none came naturally.
			if _phase_t < 6.0:
				return
			if not _has_fired("BNT:"):
				print("[vo] no natural banter in the breaks: forcing one")
				if not GLVO.try_banter(true):
					_fail("try_banter(true) found no pair to talk")
			_phase = 3
			_phase_t = 0.0
		3:
			if _phase_t < 12.0:
				return
			_finish()


## The nudged triggers (see the header).
func _nudge(root: MapRoot) -> void:
	var bots: Array[Player] = _bots()
	var b1: int = bots[0].player_id
	var b2: int = bots[1].player_id
	print("[vo] nudging triggers at t=%.0fs" % _t)
	GLBus.enemy_killed.emit(&"ganger", &"head", &"m1911", 1)
	_later(4.0, func() -> void: GLBus.weapon_acquired.emit(b1, &"m1_garand", &"wall"))
	_later(9.0, func() -> void: GLBus.ammo_bought.emit(b2, &"m1911"))
	_later(14.0, func() -> void:
		var door: BuyDoor = null
		for n: Node in get_tree().get_nodes_in_group(&"doors"):
			if n is BuyDoor and not (n as BuyDoor).is_open:
				door = n as BuyDoor
				break
		if door != null:
			door.open(b2)
			print("[vo] door %s opened by P%d" % [door.door_id, b2])
		else:
			_fail("no closed door to open"))
	_later(19.0, func() -> void: GLBus.perk_denied.emit(1, &"ironhide_stout", &"no_scrip"))
	_later(24.0, func() -> void: GLBus.intel_found.emit(&"qa_note"))
	_later(29.0, func() -> void: GLBus.trap_activated.emit(&"qa_trap", b1))


func _later(seconds: float, f: Callable) -> void:
	get_tree().create_timer(seconds).timeout.connect(f)


func _has_fired(prefix: String) -> bool:
	for k: Variant in GLVO.fired.keys():
		if str(k).begins_with(prefix):
			return true
	return false


func _squad_fired(cat_prefix: String) -> Array[String]:
	var out: Array[String] = []
	for k: Variant in GLVO.fired.keys():
		var ks: String = str(k)
		var spk: String = ks.get_slice(":", 0)
		var cat: String = ks.get_slice(":", 1)
		if spk in ["DUT", "PEG", "DEA", "WRN"] and cat.begins_with(cat_prefix):
			out.append(ks)
	return out


func _finish() -> void:
	if _done:
		return
	_done = true
	GLVO.always_pass_chance = false
	print("[vo] categories fired this match:")
	var by_spk: Dictionary = {}
	for k: Variant in GLVO.fired.keys():
		var ks: String = str(k)
		var spk: String = ks.get_slice(":", 0)
		if not by_spk.has(spk):
			by_spk[spk] = []
		(by_spk[spk] as Array).append("%s x%d" % [ks.get_slice(":", 1), int(GLVO.fired[k])])
	for spk: Variant in by_spk.keys():
		var arr: Array = by_spk[spk]
		arr.sort()
		print("[vo]   %s: %s" % [spk, ", ".join(PackedStringArray(arr))])
	for cat: String in REQUIRED_OPR:
		if not (_has_fired("OPR:" + cat)):
			_fail("the Operator never announced %s" % cat)
	for cat: String in REQUIRED_SQUAD:
		if _squad_fired(cat).is_empty():
			_fail("no survivor said a %s line" % cat)
	if not _has_fired("BNT:"):
		_fail("no banter exchange played")
	else:
		print("[vo] banter: %s" % ("natural, in a round break" if _banter_natural else "forced at the end"))
	if _rounds_seen.size() < _fight_rounds:
		_fail("rounds didn't advance (seen %s)" % str(_rounds_seen))
	# The down sequence is deterministic: DOWN by the downed, TEAM_DOWN by someone else (not the reviver),
	# REVIVE by the reviver, REVIVED by the downed; all four for the deliberate down.
	if _downed_bot != null:
		var downed_spk: String = String(GLVO.speaker_of(_downed_bot.player_id))
		var reviver_spk: String = ""
		for r: Variant in _revives:
			if int((r as Array)[0]) == _downed_bot.player_id:
				reviver_spk = String(GLVO.speaker_of(int((r as Array)[1])))
		var said: Dictionary = {}
		for l: Variant in _lines:
			var id: String = String((l as Array)[1])
			var spk: String = String((l as Array)[2])
			for cat: String in ["DOWN", "TEAM_DOWN", "REVIVE", "REVIVED"]:
				if id.begins_with("%s_%s_" % [spk, cat]):
					said[cat] = said.get(cat, []) + [spk]
		print("[vo] down sequence for %s (reviver %s): %s" % [downed_spk, reviver_spk, str(said)])
		for cat: String in ["DOWN", "TEAM_DOWN", "REVIVE", "REVIVED"]:
			if not said.has(cat):
				_fail("down sequence: no %s line" % cat)
		for spk: Variant in said.get("TEAM_DOWN", []):
			if str(spk) == downed_spk or str(spk) == reviver_spk:
				_fail("TEAM_DOWN spoken by the downed player or the reviver (%s)" % str(spk))
		if said.has("DOWN") and not (said["DOWN"] as Array).has(downed_spk):
			_fail("DOWN not spoken by the downed player")
		if said.has("REVIVED") and not (said["REVIVED"] as Array).has(downed_spk):
			_fail("REVIVED not spoken by the downed player")
		if reviver_spk != "" and said.has("REVIVE") and not (said["REVIVE"] as Array).has(reviver_spk):
			_fail("REVIVE not spoken by the reviver (%s)" % reviver_spk)
	if _revives.is_empty():
		_fail("the downed bot was never revived")
	print("[vo] audio streams started: %d (positional %d); lines started %d" % [GLVO.audio_plays, GLVO.audio_plays_3d, _lines.size()])
	if GLVO.audio_plays == 0:
		_fail("no audio stream was started")
	if GLVO.audio_plays_3d == 0:
		_fail("no positional (3D) squad line was started")
	if _fails.is_empty():
		print("[vo] RESULT PASS")
	else:
		for f: String in _fails:
			print("[vo] FAIL: ", f)
		print("[vo] RESULT FAIL")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_qa_vo_profile.json"))
	get_tree().quit(0 if _fails.is_empty() else 1)
