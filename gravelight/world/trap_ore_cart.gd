class_name OreCartTrap
extends Node3D
## Runaway Ore Cart (Map 1, Rail Yard). After a bell warning, a loaded cart shuttles between track_start
## and track_end (local) for 25 s (~4 s per pass), killing zombies and downing players in its strip.
## Bought from a TrapLever (1000, 90 s cooldown).

const KEY: String = "ore_cart"

@export var track_start: Vector3 = Vector3(-20, 0, 0)
@export var track_end: Vector3 = Vector3(20, 0, 0)
@export var width: float = 1.5

var active: bool = false
var cooldown_left: float = 0.0
var _t: float = 0.0
var _warn_left: float = 0.0
var _by: int = 0
var _cart: Node3D
var _rumble: AudioStreamPlayer3D   # looping, rides on the cart: plays while it shuttles


func _ready() -> void:
	add_to_group(&"traps")
	var dir: Vector3 = track_end - track_start
	var length: float = dir.length()
	var basis: Basis = Basis.looking_at(dir.normalized(), Vector3.UP) if length > 0.01 else Basis()
	# sleepers, rails, buffer stops and warning-bell posts along the run (cached per length)
	var track: Node3D = Node3D.new()
	track.name = "Track"
	track.transform = Transform3D(basis, track_start)
	add_child(track)
	var w: float = width
	InteractableArt.place(track, "cart_track_%d_%d" % [int(length * 10.0), int(w * 10.0)], func(r: Node3D) -> void: InteractableArt.cart_track(r, length, w))
	_cart = Node3D.new()
	add_child(_cart)
	_cart.position = track_start
	_cart.basis = basis
	InteractableArt.place(_cart, "cart_body_%d" % int(w * 10.0), func(r: Node3D) -> void: InteractableArt.cart_body(r, w))
	_rumble = AudioDirector.make_loop_3d("ore_cart_rumble", _cart)
	if _rumble != null:
		_rumble.position = Vector3.UP * 0.6


func trap_name() -> String:
	return "Runaway Ore Cart"


func cost() -> int:
	return int(TrapLever.cfg_for(KEY)["cost"])


func can_activate() -> bool:
	return not active and cooldown_left <= 0.0


func status_text() -> String:
	if active:
		return "The ore cart is running"
	return "Ore cart cooling down... %d" % int(ceil(cooldown_left))


func activate(by_player: int) -> bool:
	if not can_activate():
		return false
	active = true
	_by = by_player
	_t = 0.0
	_warn_left = float(TrapLever.cfg_for(KEY)["warn_seconds"])
	AudioDirector.play_3d("cart_bell", to_global(track_start) + Vector3.UP, 4.0, 0.0)   # the warning bell
	AudioDirector.play_3d("cart_bell", to_global(track_end) + Vector3.UP, 4.0, 0.0)
	return true


## Pure: position along the track (0..1) after t seconds, shuttling end to end.
static func shuttle(t: float, pass_seconds: float) -> float:
	var cycle: float = fmod(t / pass_seconds, 2.0)
	return cycle if cycle <= 1.0 else 2.0 - cycle


func _physics_process(delta: float) -> void:
	if cooldown_left > 0.0 and not active:
		cooldown_left = maxf(0.0, cooldown_left - delta)
	if not active:
		return
	if _warn_left > 0.0:
		_warn_left -= delta
		return
	var c: Dictionary = TrapLever.cfg_for(KEY)
	if _rumble != null and not _rumble.playing:
		_rumble.play()
	_t += delta
	_cart.position = track_start.lerp(track_end, shuttle(_t, float(c["pass_seconds"])))
	var hit_pos: Vector3 = _cart.global_position
	var axis: Vector3 = (to_global(track_end) - to_global(track_start)).normalized()
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	if dir != null:
		for z: Zombie in dir.active_zombies():
			if _in_cart(z.global_position, hit_pos, axis):
				TrapLever.trap_kill(z, float(c["zombie_damage"]), KEY, _by)
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if Net.is_authority() and p != null and p.is_alive() and _in_cart(p.global_position, hit_pos, axis):
			p.take_hit(float(c["player_damage"]), self)
	if _t >= float(c["duration"]):
		active = false
		cooldown_left = TrapLever.cooldown_for(KEY)
		_cart.position = track_start
		if _rumble != null:
			_rumble.stop()


func _in_cart(p: Vector3, cart: Vector3, axis: Vector3) -> bool:
	var d: Vector3 = p - cart
	if absf(d.y) > 2.0:
		return false
	var along: float = absf(d.dot(axis))
	var side: float = (d - axis * d.dot(axis)).length()
	return along <= 1.3 and side <= width * 0.5 + 0.3
