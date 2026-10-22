class_name LiveWireTrap
extends Node3D
## Live Wire Fence (Map 1, Generator Hall). A 1 s buzz tell, then the gate is live for 25 s: zombies
## crossing it die, and a player who touches it goes down. Bought from a TrapLever (1000, 90 s cooldown).
## Origin: floor center of the gate; size = width (x) × height (y) × depth (z).

const KEY: String = "live_wire"

@export var size: Vector3 = Vector3(4.0, 3.0, 0.6)

var active: bool = false
var cooldown_left: float = 0.0
var _t: float = 0.0
var _warn_left: float = 0.0
var _by: int = 0
var _arc_mat: StandardMaterial3D
var _arcs: Array[MeshInstance3D] = []
var _light: OmniLight3D


func _ready() -> void:
	add_to_group(&"traps")
	# steel posts with porcelain insulators and danger plates, a junction box and its feed cable (cached)
	var heights: Array = []
	for i: int in 5:
		heights.append(0.4 + i * (size.y - 0.6) / 4.0)
	var h: float = size.y
	for sx: float in [-0.5, 0.5]:
		InteractableArt.place(self, "wire_post_%d" % int(h * 10.0), func(r: Node3D) -> void: InteractableArt.wire_post(r, h, heights),
			Vector3(sx * size.x, 0, 0))
	InteractableArt.place(self, "wire_feed_%d" % int(h * 10.0), func(r: Node3D) -> void: InteractableArt.wire_feed(r, h), Vector3(-0.5 * size.x - 0.35, 0, 0))
	# the wires: copper, glowing blue-white when live
	_arc_mat = Interactable.greybox_mat(Color(0.5, 0.3, 0.16), 0.0)
	_arc_mat.metallic = 0.8
	_arc_mat.roughness = 0.4
	for i2: int in 5:
		var wire: MeshInstance3D = Interactable.add_box(self, Vector3(size.x, 0.022, 0.022), Vector3(0, float(heights[i2]), 0), _arc_mat)
		wire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_arcs.append(wire)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.6, 0.8, 1.0)
	_light.omni_range = 7.0
	_light.light_energy = 0.0
	_light.position = Vector3(0, size.y * 0.5, 0)
	add_child(_light)


func trap_name() -> String:
	return "Live Wire Fence"


func cost() -> int:
	return int(TrapLever.cfg_for(KEY)["cost"])


func can_activate() -> bool:
	return not active and cooldown_left <= 0.0


func status_text() -> String:
	if active:
		return "The fence is live"
	return "Fence recharging... %d" % int(ceil(cooldown_left))


func activate(by_player: int) -> bool:
	if not can_activate():
		return false
	active = true
	_by = by_player
	_t = 0.0
	_warn_left = float(TrapLever.cfg_for(KEY)["warn_seconds"])
	AudioDirector.play_3d("wire_buzz", global_position + Vector3.UP, 4.0, 0.0)   # buzz tell
	return true


func is_live() -> bool:
	return active and _warn_left <= 0.0


func _contains(p: Vector3) -> bool:
	var l: Vector3 = to_local(p)
	return absf(l.x) <= size.x * 0.5 and absf(l.z) <= size.z * 0.5 + 0.35 and l.y > -0.5 and l.y < size.y


## Bots keep out (BotBrain._in_trap): true from the buzz tell until the fence goes dead, near the wires.
func danger_contains(p: Vector3) -> bool:
	if not active:
		return false
	var l: Vector3 = to_local(p)
	return absf(l.x) <= size.x * 0.5 + 0.4 and absf(l.z) <= size.z * 0.5 + 0.9 and l.y > -1.0 and l.y < size.y


func _physics_process(delta: float) -> void:
	if cooldown_left > 0.0 and not active:
		cooldown_left = maxf(0.0, cooldown_left - delta)
	if not active:
		return
	if _warn_left > 0.0:
		_warn_left -= delta
		_arc_mat.emission_enabled = true
		_arc_mat.emission = Color(0.6, 0.8, 1.0)
		_arc_mat.emission_energy_multiplier = 1.0 if fmod(_warn_left, 0.2) < 0.1 else 0.0
		return
	var c: Dictionary = TrapLever.cfg_for(KEY)
	_t += delta
	_arc_mat.emission_energy_multiplier = randf_range(2.0, 7.0)
	_light.light_energy = randf_range(1.0, 3.5)
	for w: MeshInstance3D in _arcs:
		w.position.z = randf_range(-0.05, 0.05)
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	if dir != null:
		for z: Zombie in dir.active_zombies():
			if _contains(z.global_position + Vector3.UP):
				TrapLever.trap_kill(z, float(c["zombie_damage"]), KEY, _by)
				if not z.is_active():
					AudioDirector.play_3d("wire_zap", z.global_position + Vector3.UP)
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if Net.is_authority() and p != null and p.is_alive() and _contains(p.global_position + Vector3.UP):
			p.take_hit(float(c["player_damage"]), self)
	if _t >= float(c["duration"]):
		active = false
		cooldown_left = TrapLever.cooldown_for(KEY)
		_arc_mat.emission_energy_multiplier = 0.0
		_light.light_energy = 0.0
