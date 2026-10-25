class_name PlayerBot
extends Node
## Player bot mode (T-071): a local agent plays the human's own survivor while they watch in first person.
## One per match (MapRoot child, PlayerBot.attach), off by default. While on, the local Player is `bot_driven`: it
## reads no input, and a BotBrain (the Update 03 stack: perception without wallhacks, the utility actions, the aim
## layer, the economy, revives, BotLocomotion on the player's own MoveIntent) moves, aims and fires it. Its fight
## is BotTrainer (the lead_train action): training the round's horde round the map's loop. The view follows the
## brain's look on a damped turn (player_bot.json "turn"). The optional strategy layer is a BotPlanner on the same
## brain (the local LLM through LocalAI / Ollama when the Bot Local AI setting is on; the scripted planner
## otherwise and whenever Ollama isn't running). The bots (and Jakub) follow it as their leader, as they follow
## the human; with nobody human leading, the T-058 self-led rules apply (it opens the way, throws the power,
## drinks, upgrades, pulls the crate, buys ammo).
##
## Toggle: the bot_mode action (F6, Settings > Controls), the pause menu (Settings page), the dev console
## (`botmode on|off|toggle|status`), `--botmode` on the command line or PlayerBot.pending_on (the launcher scene
## gravelight/tools_src/play_botmode.tscn). Any real movement / fire / aim input hands control back at once
## (takeover(); the inputs held at the moment it was switched on must be let go first). Solo with or without bots;
## online co-op on the host only (a client's world is the host's: its shots, buys and revives would need relaying).
## The HUD tag "BOT MODE — press F6 to take over" shows while it is on. Tuning: data/gravelight/ai/player_bot.json.

signal changed(on: bool, reason: String)

const ACTION: StringName = &"bot_mode"

## Switch on as soon as the match runs (the launcher scene, tests). Cleared when used.
static var pending_on: bool = false

var map: MapRoot = null
var on: bool = false
var brain: BotBrain = null
var trainer: BotTrainer = null
var planner: BotPlanner = null
## Counters (tests, the soak): switch-ons, hand-backs by input, the reason of the last change.
var enables: int = 0
var handbacks: int = 0
var last_reason: String = ""
## The trainer's numbers kept when bot mode goes off (BotTrainer.summary()).
var last_summary: Dictionary = {}

var _cfg: Dictionary = {}
var _tcfg: Dictionary = {}
var _grace: float = 0.0
var _held: Dictionary = {}   # actions still held since the switch-on (they don't count until let go)
var _mouse_px: float = 0.0
var _want_on: bool = false
var _tag: CanvasLayer = null
var _label: Label = null
var _sub: Label = null
var _tag_t: float = 0.0


## The match's bot mode node (made once per map).
static func attach(m: MapRoot) -> PlayerBot:
	var pb: PlayerBot = PlayerBot.new()
	pb.name = "PlayerBot"
	pb.map = m
	m.add_child(pb)
	return pb


static func of(tree: SceneTree) -> PlayerBot:
	return tree.get_first_node_in_group(&"player_bot") as PlayerBot if tree != null else null


## Pure: may bot mode be switched on? {ok, reason}.
static func can_enable(online: bool, is_host: bool, has_player: bool, spectating: bool) -> Dictionary:
	if not has_player:
		return {"ok": false, "reason": "No survivor to play."}
	if online and not is_host:
		return {"ok": false, "reason": "Bot mode: in co-op only the host can hand their survivor to the agent."}
	if spectating:
		return {"ok": false, "reason": "Bot mode: you are out until the next round."}
	return {"ok": true, "reason": ""}


## Pure: does this frame's real input take control back? `move_len` the move stick, `pressed` the takeover
## actions pressed (not the ones still held since the switch-on), `mouse_px` the largest mouse move this frame,
## `look_len` the pad's look stick, `grace_left` seconds since the switch-on still to wait.
static func takeover(move_len: float, pressed: Array, mouse_px: float, look_len: float, grace_left: float, cfg: Dictionary) -> bool:
	if grace_left > 0.0:
		return false
	if move_len > float(cfg.get("move_dead", 0.3)):
		return true
	if not pressed.is_empty():
		return true
	if mouse_px > float(cfg.get("mouse_px", 4.0)):
		return true
	return look_len > float(cfg.get("pad_look_dead", 0.35))


func _ready() -> void:
	add_to_group(&"player_bot")
	process_physics_priority = -20   # the hand-back poll runs before the Player's own frame
	_cfg = BotAIData.table("player_bot")
	_tcfg = _cfg.get("takeover", {}) as Dictionary
	_build_tag()
	var con: Node = get_node_or_null("/root/GLConsole")
	if con != null and con.has_method("register"):
		con.call("register", "botmode", _cmd, "botmode on|off|toggle|status: an AI agent plays your survivor (trains the horde); any move / fire takes over")
	_want_on = pending_on or OS.get_cmdline_user_args().has("--botmode")
	pending_on = false


func _exit_tree() -> void:
	if on and map != null and is_instance_valid(map) and map.player != null and is_instance_valid(map.player):
		map.player.bot_driven = false


func is_on() -> bool:
	return on


## Switches bot mode; returns whether it is now in the state asked for. `reason` goes to the log / signal.
func set_on(v: bool, reason: String = "") -> bool:
	if v == on:
		return true
	if v:
		return _enable(reason)
	_disable(reason)
	return true


func toggle(reason: String = "toggle") -> bool:
	return set_on(not on, reason)


func _enable(reason: String) -> bool:
	var p: Player = map.player if map != null else null
	var chk: Dictionary = can_enable(Net.is_online() and Net.in_match, Net.is_host(), p != null and is_instance_valid(p), p != null and p.spectating)
	if not bool(chk["ok"]):
		last_reason = str(chk["reason"])
		_banner(last_reason)
		return false
	var squad: BotSquad = map.squad
	if squad == null:
		squad = BotSquad.new()   # solo without bots: a squad for the agent's brain (no co-op session: the solo rules stay)
		squad.name = "BotSquad"
		map.add_child(squad)
		squad.setup(map)
		map.squad = squad
	var opts: Dictionary = (_cfg.get("brain", {}) as Dictionary).duplicate()
	opts.erase("_doc")
	opts["skill"] = str(_cfg.get("skill", ""))
	opts["personality"] = str(_cfg.get("personality", "player_agent"))
	p.bot_driven = true
	brain = squad.add_player_brain(p, opts)
	trainer = BotTrainer.new()
	trainer.setup(brain)
	brain.trainer = trainer
	brain.crawler = AgentCrawler.new()   # T-071 pass 3: the crawler break
	brain.crawler.setup(brain)
	if squad.ee != null:
		squad.ee.attach(brain)   # T-086: the agent works the easter egg through the squad's hub (AgentPlan.tick_egg)
	if brain.loco is BotLocomotion:
		(brain.loco as BotLocomotion).skill_override = str(_cfg.get("skill", ""))
		var turn: Dictionary = (_cfg.get("turn", {}) as Dictionary).duplicate()
		turn.erase("_doc")
		(brain.loco as BotLocomotion).smooth_turn = turn
	var pc: Dictionary = _cfg.get("planner", {}) as Dictionary
	if bool(pc.get("enabled", true)):
		planner = BotPlanner.new()
		planner.name = "Planner"
		brain.add_child(planner)
		planner.setup(brain, squad, bool(pc.get("local_ai", true)) and wants_local_ai())
		brain.planner = planner
	p.sprinting = false
	p.interact_progress = 0.0
	on = true
	enables += 1
	last_reason = reason
	_grace = float(_tcfg.get("grace_s", 0.35))
	_held.clear()
	for a: Variant in _tcfg.get("actions", []):
		if InputMap.has_action(StringName(str(a))) and Input.is_action_pressed(StringName(str(a))):
			_held[str(a)] = true
	if _tag != null:
		_tag.visible = true
	_refresh_tag()
	print("[botmode] on (%s): the agent plays %s" % [reason, Net.display_name(p.player_id)])
	changed.emit(true, reason)
	return true


## Bot mode is LLM-planned when the Bot Local AI setting (or the match's bot AI mode) asks for it.
static func wants_local_ai() -> bool:
	return GameState.bot_ai_mode == "local" or bool(GLSettings.values.get("bot_local_ai", false))


func _disable(reason: String) -> void:
	var p: Player = map.player if map != null else null
	if trainer != null:
		last_summary = trainer.summary()
	if p != null and is_instance_valid(p):
		p.bot_driven = false
		p.set("_mi", MoveIntent.new())
		p.set("_pitch", clampf(p.head.rotation.x - float((p.get("_rk") as Vector2).x), deg_to_rad(-88.0), deg_to_rad(88.0)))
		if p.weapons != null:
			p.weapons.bot_view_release()
	if map != null and map.squad != null:
		map.squad.remove_player_brain()
	brain = null
	trainer = null
	planner = null
	on = false
	last_reason = reason
	if reason == "takeover":
		handbacks += 1
	if _tag != null:
		_tag.visible = false
	print("[botmode] off (%s)" % reason)
	changed.emit(false, reason)


func _physics_process(delta: float) -> void:
	if _want_on and map != null and map.player != null and map.player.is_inside_tree() and GameState.phase == GameState.Phase.PLAYING:
		_want_on = false
		set_on(true, "launch")
	if not on:
		return
	var p: Player = map.player
	if p == null or not is_instance_valid(p) or brain == null or not is_instance_valid(brain):
		_disable("lost the player")
		return
	AgentPlan.tick_egg(brain)   # T-086: the easter egg between the fights
	_grace = maxf(0.0, _grace - delta)
	var pressed: Array = []
	var move_held: bool = false
	for a: Variant in _tcfg.get("actions", []):
		var an: StringName = StringName(str(a))
		if not InputMap.has_action(an):
			continue
		if Input.is_action_pressed(an):
			if _held.has(str(a)):
				if str(a).begins_with("move_"):
					move_held = true
				continue
			pressed.append(str(a))
		else:
			_held.erase(str(a))
	var mv: float = 0.0 if move_held or GameState.input_blocked else Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back", 0.2).length()
	var look: float = 0.0
	if InputMap.has_action(&"look_left"):
		look = Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down", 0.15).length()
	if GameState.input_blocked or BotCommandWheel.capturing:
		pressed.clear()
		look = 0.0
	if takeover(mv, pressed, _mouse_px, look, _grace, _tcfg):
		_disable("takeover")
	_mouse_px = 0.0
	_tag_t -= delta
	if _tag_t <= 0.0:
		_tag_t = 0.25
		_refresh_tag()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION) and not event.is_echo():
		toggle("key")
		get_viewport().set_input_as_handled()
		return
	if on and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_px = maxf(_mouse_px, (event as InputEventMouseMotion).relative.length())


# ================================================================== the HUD tag

func _build_tag() -> void:
	_tag = CanvasLayer.new()
	_tag.name = "BotModeTag"
	_tag.layer = 40
	_tag.visible = false
	add_child(_tag)
	var box: VBoxContainer = VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.offset_left = -330.0
	box.offset_right = 330.0
	box.offset_top = 64.0
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag.add_child(box)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	_label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 0.9))
	_label.add_theme_constant_override("outline_size", 6)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_label)
	_sub = Label.new()
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_font_size_override("font_size", 15)
	_sub.add_theme_color_override("font_color", Color(0.9, 0.86, 0.78, 0.85))
	_sub.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 0.9))
	_sub.add_theme_constant_override("outline_size", 4)
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_sub)


func key_label() -> String:
	if InputMap.has_action(ACTION):
		var l: String = GLSettings.binding_label(ACTION, false)
		if l != "":
			return l
	return "F6"


func tag_text() -> String:
	var hc: Dictionary = _cfg.get("hud", {}) as Dictionary
	return str(hc.get("text", "BOT MODE — press %s to take over")) % key_label()


func status_text() -> String:
	if not on or brain == null:
		return "off"
	var s: String = brain.action
	if brain.action == "lead_train" and trainer != null:
		s = "training: %s" % trainer.phase_name()
		if trainer.followers > 0:
			s += ", %d following" % trainer.followers
		if trainer.route != null:
			s += " (%s)" % trainer.route.label
	elif not brain.task.is_empty():
		s = str(brain.task.get("label", brain.action))
	if planner != null and not planner.directive.is_empty() and str(planner.directive.get("kind", "")) != "follow":
		s += " | plan: %s" % str(planner.directive.get("label", ""))
	if brain.ee != null and brain.ee.active():
		s += " | egg: %s" % str(brain.ee.describe().get("label", ""))   # T-086
	return s


func _refresh_tag() -> void:
	if _label == null or not on:
		return
	_label.text = tag_text()
	_sub.text = status_text()


func _banner(text: String) -> void:
	var hud: Node = get_tree().get_first_node_in_group(&"hud")
	if hud != null and hud.has_method("show_banner"):
		hud.call("show_banner", text, 2.2)
	print("[botmode] ", text)


# ================================================================== the dev console

func _cmd(a: PackedStringArray) -> String:
	var arg: String = a[0].to_lower() if a.size() > 0 else "toggle"
	match arg:
		"on", "1":
			return "bot mode on" if set_on(true, "console") else last_reason
		"off", "0":
			set_on(false, "console")
			return "bot mode off"
		"toggle":
			toggle("console")
			return "bot mode %s" % ("on" if on else "off")
		"status", "stats":
			var line: String = "bot mode %s: %s" % ["on" if on else "off", status_text()]
			var s: Dictionary = trainer.summary() if trainer != null else last_summary
			if not s.is_empty():
				line += "\n" + str(s)
			return line
	return "usage: botmode on|off|toggle|status"
