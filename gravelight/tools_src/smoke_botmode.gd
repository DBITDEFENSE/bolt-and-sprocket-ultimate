extends Node
## Headless smoke test for player bot mode (T-071, PlayerBot + BotTrainer). Map 0, solo, no god mode:
##   1. the toggle: F6 (the bot_mode action) switches it on: the Player is bot_driven, a brain plays it, the HUD tag
##      shows; the dev console's `botmode off` / `botmode on` switch it
##   2. the agent trains a round: from round 4 with a Thompson and Ironhide, it trains the horde round the taproom loop until the
##      round is over (time training, a train of 2+ following it, kills), and takes damage rarely (it isn't downed;
##      at most a few hits)
##   3. hand-back: a move key pressed takes control back at once (bot_driven false, the brain gone, the view kept);
##      a key held at the switch-on doesn't count until it is let go
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_botmode.tscn [-- --timeout=300]
## Prints "[botmode] ..." lines and RESULT PASS/FAIL (exit code 0/1).

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"

var _map: MapRoot
var _t: float = 0.0
var _phase: int = 0
var _phase_t: float = 0.0
var _fails: PackedStringArray = []
var _timeout: float = 300.0
var _done: bool = false
var _hits: int = 0
var _downs: int = 0
var _start_round: int = 4
var _moved: float = 0.0
var _last_p: Vector3 = Vector3.INF
var _kills0: int = 0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--timeout="):
			_timeout = float(a.substr(10))
	ProfileSave.path = "user://_qa_botmode_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_botmode_settings.cfg"
	GLSettings.values["bot_local_ai"] = false   # the scripted planner: no Ollama
	GLSettings.values["homage_bosses"] = false
	GameState.character_id = &"peg"
	GameState.bot_count = 0
	GameState.bot_ai_mode = "off"
	GameState.god_mode = false
	_map = (load(MAP) as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GLBus.player_damaged.connect(func(pid: int, amount: float) -> void:
		if pid == 1 and amount > 0.0 and _phase == 3:
			_hits += 1
			print("[botmode] hit %d (%.0f) at t=%.0fs, hp %.0f" % [_hits, amount, _t, _map.player.hp]))
	GLBus.player_downed.connect(func(pid: int) -> void:
		if pid == 1:
			_downs += 1)


func _check(cond: bool, what: String) -> void:
	print("[botmode] %-74s %s" % [what, "PASS" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _pb() -> PlayerBot:
	return PlayerBot.of(get_tree())


func _press(action: StringName, on: bool) -> void:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = action
	ev.pressed = on
	Input.parse_input_event(ev)
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _physics_process(delta: float) -> void:
	if _done or _map == null or not _map.is_inside_tree():
		return
	_t += delta
	_phase_t += delta
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _t > _timeout:
		_check(false, "finished within %.0f s (stuck in phase %d)" % [_timeout, _phase])
		_finish()
		return
	var p: Player = _map.player
	match _phase:
		0:
			if p != null and p.is_inside_tree() and GameState.phase == GameState.Phase.PLAYING and _pb() != null and _phase_t > 1.5 \
					and NavigationServer3D.map_get_iteration_id(p.get_world_3d().navigation_map) > 0:
				_check(not _pb().is_on() and not p.bot_driven, "off by default")
				_press(PlayerBot.ACTION, true)
				_phase = 1
				_phase_t = 0.0
		1:
			_press(PlayerBot.ACTION, false)
			var pb: PlayerBot = _pb()
			_check(pb.is_on() and p.bot_driven, "F6 (bot_mode) switches it on: the Player is bot_driven")
			_check(pb.brain != null and pb.brain.is_player_bot and _map.squad != null and _map.squad.player_bot == pb.brain, "a player brain plays it (BotSquad.player_bot, solo squad made)")
			_check(pb.brain != null and not _map.squad.brains.has(pb.brain), "it isn't one of the squad's bots")
			_check(pb.trainer != null and pb.brain.trainer == pb.trainer, "with the trainer")
			_check(pb.tag_text().contains("BOT MODE") and pb.tag_text().contains("F6"), "the HUD tag: '%s'" % pb.tag_text())
			var con: Node = get_node_or_null("/root/GLConsole")
			if con != null and con.has_method("run"):
				con.call("run", "botmode off")
				_check(not pb.is_on() and not p.bot_driven, "console: botmode off")
				con.call("run", "botmode on")
				_check(pb.is_on() and p.bot_driven, "console: botmode on")
			else:
				pb.set_on(false, "smoke")
				pb.set_on(true, "smoke")
				print("[botmode] (no console run(): switched through PlayerBot.set_on)")
			# (a round-4 horde is small: the smoke trains from 2 followers so the trainer runs, not only the fight)
			pb.trainer.c = pb.trainer.c.duplicate()
			pb.trainer.c["train_min"] = 2
			pb.trainer.c["train_keep"] = 1
			pb.trainer.c["own_force_round"] = 1   # (pass 2: the trainer owns the round here, as it does once the plan's loop is open)
			# round 4 with a Thompson
			p.weapons.give_weapon(&"thompson")
			for k: int in p.weapons.slots.size():
				if String(p.weapons.slots[k].base_id()) == "thompson":
					p.weapons.current_index = k
			PerkManager.grant(1, &"ironhide_stout")   # (the smoke's setup: a round-4 survivor's health, so one unlucky hit is no game over)
			RoundManager.debug_set_round(_start_round)
			_map.director.kill_all(true)
			_phase = 2
			_phase_t = 0.0
		2:
			if RoundManager.state == RoundManager.State.ROUND and RoundManager.current_round == _start_round:
				_kills0 = int(_pb().trainer.stats.get("kills", 0)) if _pb().trainer != null else 0
				_last_p = p.global_position
				_phase = 3
				_phase_t = 0.0
				print("[botmode] round %d on: the agent trains it" % _start_round)
			elif _phase_t > 40.0:
				_check(false, "round %d started" % _start_round)
				_finish()
		3:
			if _last_p != Vector3.INF:
				_moved += Vector2(p.global_position.x - _last_p.x, p.global_position.z - _last_p.z).length()
			_last_p = p.global_position
			var pb3: PlayerBot = _pb()
			if not pb3.is_on():
				_check(false, "bot mode stayed on through the round (it went off: %s)" % pb3.last_reason)
				_finish()
				return
			if RoundManager.current_round > _start_round or (RoundManager.state != RoundManager.State.ROUND and _phase_t > 5.0):
				var s: Dictionary = pb3.trainer.summary()
				print("[botmode] round over after %.0f s: %s" % [_phase_t, str(s)])
				_check(_downs == 0 and not p.downed, "not downed")
				_check(_hits <= 4, "takes damage rarely: %d hits in the round (<= 4)" % _hits)
				_check(float(s["training_s"]) >= 5.0, "trained: %.0f s with a train behind it" % float(s["training_s"]))
				_check(int(s["train_max"]) >= 2, "a train of %d at its longest (>= 2)" % int(s["train_max"]))
				_check(int(s["kills"]) - _kills0 >= 6, "killed the round: %d kills" % (int(s["kills"]) - _kills0))
				_check(_moved > 25.0, "kept moving: %.0f m" % _moved)
				_check(float(s["stuck_s"]) < 3.0, "not stuck (%.1f s)" % float(s["stuck_s"]))
				# a key held at a switch-on must be let go first: turn off, hold W, turn on, still on next frames
				pb3.set_on(false, "smoke")
				_press(&"move_forward", true)
				pb3.set_on(true, "smoke")
				_phase = 4
				_phase_t = 0.0
			elif _phase_t > 240.0:
				_check(false, "round %d over within 240 s (alive %d, to spawn %d)" % [_start_round, RoundManager.alive, RoundManager.to_spawn])
				_finish()
		4:
			if _phase_t > 0.6:
				_check(_pb().is_on(), "a key held at the switch-on doesn't take over")
				_press(&"move_forward", false)
				_phase = 5
				_phase_t = 0.0
		5:
			if _phase_t > 0.7:
				var view_y: float = p.rotation.y
				_press(&"move_forward", true)
				_phase = 6
				_phase_t = 0.0
				set_meta("view_y", view_y)
		6:
			if _phase_t > 0.1:
				_press(&"move_forward", false)
				var pb6: PlayerBot = _pb()
				_check(not pb6.is_on() and not p.bot_driven, "a move key pressed takes control back at once")
				_check(pb6.last_reason == "takeover" and pb6.handbacks >= 1, "reason: takeover")
				_check(_map.squad.player_bot == null, "the player brain is gone")
				_check(absf(wrapf(p.rotation.y - float(get_meta("view_y")), -PI, PI)) < 0.5, "the view stays where the agent left it")
				_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	_press(&"move_forward", false)
	print("[botmode] RESULT %s%s" % ["PASS" if _fails.is_empty() else "FAIL", "" if _fails.is_empty() else " (" + "; ".join(_fails) + ")"])
	get_tree().quit(0 if _fails.is_empty() else 1)
