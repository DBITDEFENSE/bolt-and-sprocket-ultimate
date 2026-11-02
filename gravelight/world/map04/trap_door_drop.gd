class_name DoorDropTrap
extends Node3D
## The hangar's door drop (UPDATE 10 §3 Act III, row 14; DECISIONS T-157; traps.json door_drop). The big sliding
## door hangs on its track over the south doorway; the lever trips the brake: a 1 s scream of the rollers, then the
## door comes down on the opening and crushes every zombie in the doorway box; a player in the box is shoved clear
## during the warning (nobody is crushed). It stays down `duration` s (a wall for that moment), then winches back up.
## 60 s cooldown. The navmesh is not touched (the door is only down for a breath). Origin: the doorway's floor
## centre; size = the opening (x) × its height (y) × the crush depth (z, both sides of the wall).

const KEY: String = "door_drop"

@export var size: Vector3 = Vector3(3.4, 3.2, 2.0)
@export var hang_y: float = 3.4

var active: bool = false
var cooldown_left: float = 0.0
var drops: int = 0                  # the smoke / tests
var crushed: int = 0
var _t: float = 0.0
var _warn_left: float = 0.0
var _by: int = 0
var _door: Node3D = null
var _body: StaticBody3D = null
var _phase: String = "up"           # up | falling | down | rising


func _ready() -> void:
	add_to_group(&"traps")
	_door = Node3D.new()
	_door.name = "Door"
	add_child(_door)
	var steel: StandardMaterial3D = StandardMaterial3D.new()
	steel.albedo_color = Color(0.42, 0.44, 0.4)
	steel.metallic = 0.7
	steel.roughness = 0.55
	var rust: StandardMaterial3D = StandardMaterial3D.new()
	rust.albedo_color = Color(0.45, 0.27, 0.16)
	rust.roughness = 0.9
	# the panel with its corrugations and the bottom rail (a bumper of rusted iron)
	Interactable.add_box(_door, Vector3(size.x, size.y, 0.1), Vector3(0, size.y * 0.5, 0), steel)
	for i: int in int(size.x / 0.3):
		var x: float = -size.x * 0.5 + 0.15 + 0.3 * float(i)
		var rib: MeshInstance3D = Interactable.add_box(_door, Vector3(0.06, size.y, 0.05), Vector3(x, size.y * 0.5, -0.07), steel)
		rib.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Interactable.add_box(_door, Vector3(size.x + 0.1, 0.2, 0.2), Vector3(0, 0.1, 0), rust)
	var warn: StandardMaterial3D = StandardMaterial3D.new()
	warn.albedo_color = Color(0.85, 0.7, 0.15)
	Interactable.add_box(_door, Vector3(size.x, 0.12, 0.02), Vector3(0, 0.32, -0.11), warn)
	# the track over the opening
	Interactable.add_box(self, Vector3(size.x + 0.8, 0.18, 0.25), Vector3(0, hang_y + size.y + 0.15, 0), rust)
	_door.position = Vector3(0, hang_y, 0)
	_body = StaticBody3D.new()
	_body.collision_layer = 0
	_body.collision_mask = 0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = Vector3(size.x, size.y, 0.3)
	cs.shape = sh
	cs.position = Vector3(0, size.y * 0.5, 0)
	_body.add_child(cs)
	add_child(_body)


func trap_name() -> String:
	return "Door Drop"


func cost() -> int:
	return int(TrapLever.cfg_for(KEY)["cost"])


func can_activate() -> bool:
	return not active and cooldown_left <= 0.0


func status_text() -> String:
	if active:
		return "The door is down"
	return "Winching the door up... %d" % int(ceil(cooldown_left))


func activate(by_player: int) -> bool:
	if not can_activate():
		return false
	active = true
	_by = by_player
	_t = 0.0
	_phase = "up"
	_warn_left = float(TrapLever.cfg_for(KEY).get("warn_seconds", 1.0))
	AudioDirector.play_3d("door_drop" if AudioDirector.has_sound("door_drop") else "door_creak", global_position + Vector3.UP * 3.0, 4.0, 0.0)
	_shove_players()
	return true


func is_live() -> bool:
	return active and _phase == "falling"


func _contains(p: Vector3) -> bool:
	var l: Vector3 = to_local(p)
	return absf(l.x) <= size.x * 0.5 + 0.2 and absf(l.z) <= size.z * 0.5 and l.y > -0.5 and l.y < size.y


func danger_contains(p: Vector3) -> bool:
	return active and _contains(p)


## Nobody is crushed: a player in the doorway is shoved out the way they were facing the door from.
func _shove_players() -> void:
	if not Net.is_authority():
		return
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not p.is_alive() or not _contains(p.global_position + Vector3.UP * 0.5):
			continue
		var l: Vector3 = to_local(p.global_position)
		var out: Vector3 = global_basis.z * (1.0 if l.z >= 0.0 else -1.0)
		p.external_push(out * 6.0 + Vector3(0, 1.5, 0), 0.3, &"push")
		get_tree().create_timer(0.5).timeout.connect(func() -> void:
			if is_instance_valid(p) and _contains(p.global_position + Vector3.UP * 0.5):
				p.global_position = global_position + out * (size.z * 0.5 + 0.8))


func _physics_process(delta: float) -> void:
	if cooldown_left > 0.0 and not active:
		cooldown_left = maxf(0.0, cooldown_left - delta)
	if not active:
		return
	var c: Dictionary = TrapLever.cfg_for(KEY)
	if _warn_left > 0.0:
		_warn_left -= delta
		_door.position.y = hang_y + sin(_warn_left * 40.0) * 0.03   # the door shudders on its brake
		if _warn_left <= 0.0:
			_phase = "falling"
			drops += 1
		return
	_t += delta
	match _phase:
		"falling":
			_door.position.y = maxf(0.0, _door.position.y - delta * hang_y / 0.35)
			if _door.position.y <= 0.0:
				_phase = "down"
				_t = 0.0
				_body.collision_layer = 1
				_crush(c)
				Effects.dust_puff(global_position, "earth", 30)
		"down":
			if _t >= float(c.get("duration", 1.5)):
				_phase = "rising"
				_body.collision_layer = 0
		"rising":
			_door.position.y = minf(hang_y, _door.position.y + delta * hang_y / 1.5)
			if _door.position.y >= hang_y - 0.001:   # position.y is a float32: 2.6 reads back as 2.5999999
				_phase = "up"
				active = false
				cooldown_left = TrapLever.cooldown_for(KEY)


func _crush(c: Dictionary) -> void:
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	if dir == null or not Net.is_authority():
		return
	for z: Zombie in dir.active_zombies():
		if z.state != Zombie.State.DEAD and not (z is HomageBoss) and _contains(z.global_position + Vector3.UP * 0.5):
			TrapLever.trap_kill(z, float(c.get("zombie_damage", 999999.0)), KEY, _by)
			crushed += 1
