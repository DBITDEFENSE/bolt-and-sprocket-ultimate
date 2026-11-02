class_name HoldoutStation
extends Interactable
## A Totenhafen holdout (UPDATE 10 contract C2, DECISIONS T-153): the Pumpenschalter crank and the three diesel holds
## of Letzte Fahrt share it. Hold [interact] to start; it then charges over `seconds` while a living player stands
## within `radius` (it pauses when the ring is empty; `abandon_seconds` empty and it fails, and it can be started
## again from the next round). While it runs: ×`spawn_mult` spawns in `zone_id` (ZombieDirector.set_spawn_boost),
## `temp_spawns` ground points round the ring, the round can't end (RoundManager.set_hold), and the GameState event
## flag `holdout` is on (the squads stay out of it, T-142). Subclasses say when it may start (`start_block`), add the
## twist (`_twist_tick`) and act on completion (`_completed`). Pylon's pattern (gravelight/world/pylon.gd).
##
## Co-op: the host runs the charge and mirrors progress at 4 Hz (`_net_progress`), the start and the end.

enum State { IDLE, RUNNING, DONE }

signal holdout_started(holdout_id: StringName)
signal holdout_completed(holdout_id: StringName)
signal holdout_failed(holdout_id: StringName)

@export var holdout_id: StringName = &"holdout"
@export var zone_id: StringName = &"D_PENHALL"
@export var radius: float = 3.5
@export var seconds: float = 30.0
@export var spawn_mult: float = 2.0
@export var temp_spawns: int = 2
@export var abandon_seconds: float = 20.0
@export var label: String = "the holdout"
@export var hud_title: String = "HOLD"
## Can it run more than once (the crank: once per flood)?
@export var repeatable: bool = false
## Explicit temp spawn points (world); empty = a ring round the station.
@export var spawn_points: PackedVector3Array = PackedVector3Array()

var state: State = State.IDLE
var progress: float = 0.0
var occupied: bool = false
var started_by: int = 0
## Locked after a failure until the next round starts.
var locked_until_round: int = 0
var completions: int = 0

var _empty_t: float = 0.0
var _net_t: float = 0.0
var _hud: CanvasLayer
var _hud_label: Label


func _ready() -> void:
	super._ready()
	add_to_group(&"holdout_stations")
	_hud = CanvasLayer.new()
	_hud.layer = 12
	_hud_label = Label.new()
	_hud_label.anchor_left = 0.0
	_hud_label.anchor_right = 1.0
	_hud_label.offset_top = 90.0
	_hud_label.offset_bottom = 130.0
	_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_label.add_theme_font_size_override("font_size", 30)
	_hud_label.add_theme_color_override("font_color", Color(0.75, 0.88, 0.95))
	_hud_label.add_theme_constant_override("outline_size", 6)
	_hud_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_hud.add_child(_hud_label)
	_hud.visible = false
	add_child(_hud)
	GLBus.round_started.connect(_on_round_started)


## Pure: one charge step [progress, empty_time, failed].
static func step(p: float, dt: float, is_occupied: bool, empty_t: float, secs: float, abandon_s: float) -> Array:
	if is_occupied:
		return [minf(1.0, p + dt / maxf(0.1, secs)), 0.0, false]
	empty_t += dt
	return [p, empty_t, empty_t >= abandon_s]


## Why it can't start now ("" = it can). Subclasses add their conditions (power, a flood, the egg's step).
func start_block(_player: Player) -> String:
	if state == State.RUNNING:
		return "running"
	if state == State.DONE and not repeatable:
		return "done"
	if locked_until_round > RoundManager.current_round:
		return "The next round, then try again"
	return ""


func get_prompt(player: Player) -> String:
	var why: String = start_block(player)
	if why == "running" or why == "done":
		return ""
	if why != "":
		return why
	return "Hold [%s] to start %s" % [prompt_key(&"interact"), label]


func can_interact(player: Player) -> bool:
	return start_block(player) == ""


func hold_time(_player: Player) -> float:
	return 1.0


func interact(player: Player) -> void:
	if not can_interact(player) or not Net.is_authority():
		return
	start(player.player_id)


## Start the hold (authority; tools and bots call it too).
func start(by_player: int = 0) -> void:
	if state == State.RUNNING:
		return
	state = State.RUNNING
	progress = 0.0
	_empty_t = 0.0
	started_by = by_player
	var dir: ZombieDirector = _director()
	if dir != null:
		dir.set_spawn_boost(zone_id, spawn_mult)
		var pts: Array = Array(spawn_points)
		for i: int in (temp_spawns if spawn_points.is_empty() else 0):
			var a: float = TAU * float(i) / float(maxi(1, temp_spawns)) + randf() * 0.6
			pts.append(global_position + Vector3(cos(a), 0, sin(a)) * (radius + 2.0))
		if not pts.is_empty():
			dir.add_temp_spawns(_key(), pts, zone_id)
	RoundManager.set_hold(_key(), true)
	GameState.set_flag(&"holdout", true)
	_on_started()
	Net.mirror(self, &"_net_started", [by_player])
	holdout_started.emit(holdout_id)


func _key() -> StringName:
	return StringName("holdout_" + String(holdout_id))


func _director() -> ZombieDirector:
	return get_tree().get_first_node_in_group(&"director") as ZombieDirector


func in_ring(p: Vector3) -> bool:
	var d: Vector3 = p - global_position
	return Vector2(d.x, d.z).length() <= radius and absf(d.y) < 3.0


func _anyone_in_ring() -> bool:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.is_alive() and in_ring(p.global_position):
			return true
	return false


func _process(delta: float) -> void:
	if state != State.RUNNING:
		if _hud != null:
			_hud.visible = false
		return
	_show_hud()
	if Net.is_client():
		return
	occupied = _anyone_in_ring()
	var res: Array = step(progress, delta, occupied, _empty_t, seconds, abandon_seconds)
	progress = float(res[0])
	_empty_t = float(res[1])
	_twist_tick(delta)
	_net_t -= delta
	if _net_t <= 0.0:
		_net_t = 0.25
		Net.mirror(self, &"_net_progress", [progress, occupied])
	if progress >= 1.0:
		_finish(true)
	elif bool(res[2]):
		_finish(false)


func _show_hud() -> void:
	var me: Player = null
	if Net.session != null:
		me = Net.session.local_player
	else:
		for n: Node in get_tree().get_nodes_in_group(&"players"):
			var p: Player = n as Player
			if p != null and p.is_local:
				me = p
				break
	_hud.visible = me != null and me.is_alive() and in_ring(me.global_position)
	_hud_label.text = "%s   %d%%" % [hud_title, int(progress * 100.0)]


func _finish(ok: bool) -> void:
	var dir: ZombieDirector = _director()
	if dir != null:
		dir.set_spawn_boost(zone_id, 1.0)
		dir.remove_temp_spawns(_key())
	RoundManager.set_hold(_key(), false)
	if not _other_holdout_running():
		GameState.set_flag(&"holdout", false)
	if ok:
		state = State.DONE if not repeatable else State.IDLE
		progress = 1.0
		completions += 1
		_completed()
		Net.mirror(self, &"_net_done", [true])
		holdout_completed.emit(holdout_id)
	else:
		state = State.IDLE
		progress = 0.0
		locked_until_round = RoundManager.current_round + 1
		_failed()
		Net.mirror(self, &"_net_done", [false])
		holdout_failed.emit(holdout_id)


func _other_holdout_running() -> bool:
	for n: Node in get_tree().get_nodes_in_group(&"holdout_stations"):
		if n != self and (n as HoldoutStation).state == State.RUNNING:
			return true
	return false


## BotEE's hold_zone anchors read this (charging = hold the ring).
func is_holding() -> bool:
	return state == State.RUNNING


## Abandon it now (a tool, a wipe).
func abort() -> void:
	if state == State.RUNNING and Net.is_authority():
		_finish(false)


## Test/forcing helper: complete it now (authority).
func force_complete() -> void:
	if not Net.is_authority():
		return
	if state != State.RUNNING:
		start(0)
	progress = 1.0
	_finish(true)


func _on_round_started(_r: int, _special: bool) -> void:
	pass


# ---- virtuals
func _on_started() -> void:
	pass


func _twist_tick(_delta: float) -> void:
	pass


func _completed() -> void:
	pass


func _failed() -> void:
	pass


# ---- co-op mirrors (clients)
func _net_started(by_player: int) -> void:
	state = State.RUNNING
	progress = 0.0
	started_by = by_player
	_on_started()


func _net_progress(p: float, occ: bool) -> void:
	if state != State.RUNNING:
		state = State.RUNNING
	progress = p
	occupied = occ


func _net_done(ok: bool) -> void:
	if ok:
		state = State.DONE if not repeatable else State.IDLE
		progress = 1.0
		completions += 1
		_completed()
	else:
		state = State.IDLE
		progress = 0.0
		_failed()
