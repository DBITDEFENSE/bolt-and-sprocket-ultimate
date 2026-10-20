class_name ChandelierTrap
extends Node3D
## Chandelier Drop (Map 1, Salt Chapel). Once per round, the salt-crystal chandeliers over drop_points
## (local floor positions) crash down, killing everything within `radius` of each. They're back next round.

const KEY: String = "chandelier"

@export var drop_points: PackedVector3Array = PackedVector3Array([Vector3(0, 0, -6), Vector3.ZERO, Vector3(0, 0, 6)])
@export var radius: float = 4.0
@export var hang_height: float = 9.0

var used_this_round: bool = false
var _falling: bool = false
var _t: float = 0.0
var _by: int = 0
var _chandeliers: Array[Node3D] = []


## Pure: may the trap fire? (once per round)
static func can_fire(used: bool, falling: bool) -> bool:
	return not used and not falling


func _ready() -> void:
	add_to_group(&"traps")
	for p: Vector3 in drop_points:
		var ch: Node3D = Node3D.new()
		add_child(ch)
		ch.position = p + Vector3.UP * hang_height
		Props.crystal_chandelier(ch, 6.0)   # salt-crystal art (world/props.gd); the chain runs up 6 m
		var glow: OmniLight3D = OmniLight3D.new()
		glow.light_color = Color(0.9, 0.85, 1.0)
		glow.omni_range = 6.0
		glow.light_energy = 0.6
		ch.add_child(glow)
		_chandeliers.append(ch)
	GLBus.round_ended.connect(func(_r: int) -> void: reset())


func trap_name() -> String:
	return "Chandelier Drop"


func cost() -> int:
	return int(TrapLever.cfg_for(KEY)["cost"])


func can_activate() -> bool:
	return can_fire(used_this_round, _falling)


func status_text() -> String:
	return "The chandeliers are down until next round"


func activate(by_player: int) -> bool:
	if not can_activate():
		return false
	used_this_round = true
	_falling = true
	_t = 0.0
	_by = by_player
	AudioDirector.play_3d("board_break", global_position + Vector3.UP * hang_height, 6.0, 0.0)
	return true


func _physics_process(delta: float) -> void:
	if not _falling:
		return
	var c: Dictionary = TrapLever.cfg_for(KEY)
	var fall: float = float(c["fall_seconds"])
	_t += delta
	var k: float = clampf(_t / fall, 0.0, 1.0)
	for i: int in _chandeliers.size():
		_chandeliers[i].position.y = drop_points[i].y + hang_height * (1.0 - k * k) + 0.4 * k
	if k < 1.0:
		return
	_falling = false
	AudioDirector.play_3d("chandelier_crash", global_position + Vector3.UP, 4.0, 0.0)   # one crash for the set
	for i: int in _chandeliers.size():
		var at: Vector3 = to_global(drop_points[i])
		Effects.explosion(at + Vector3.UP * 0.5, radius)
		var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
		if dir != null:
			for z: Zombie in dir.active_zombies():
				if _near(z.global_position, at):
					TrapLever.trap_kill(z, float(c["zombie_damage"]), KEY, _by)
		for n: Node in get_tree().get_nodes_in_group(&"players"):
			var p: Player = n as Player
			if Net.is_authority() and p != null and p.is_alive() and _near(p.global_position, at):
				p.take_hit(float(c["player_damage"]), self)
	if Net.is_authority():
		GLBus.explosion.emit(global_position, radius * 2.0)


func _near(p: Vector3, at: Vector3) -> bool:
	return Vector2(p.x - at.x, p.z - at.z).length() <= radius and absf(p.y - at.y) < 3.0


## Next round: the chandeliers are hoisted back up.
func reset() -> void:
	used_this_round = false
	_falling = false
	for i: int in _chandeliers.size():
		_chandeliers[i].position = drop_points[i] + Vector3.UP * hang_height
