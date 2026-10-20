class_name TriggerVolume
extends Area3D
## An axis-aligned box that fires when the player enters it (addTrigger). once = fire a single time;
## otherwise it fires again after `cooldown` (used by out-of-bounds quips). `requires` lists director flags
## that must all be set, `forbids` flags that must all be clear; the director evaluates them through
## `gate_check` (a Callable(flags_all, flags_none) -> bool).

signal fired(trigger: TriggerVolume, bolt: Node)

var trigger_id: String = ""
var size: Vector3 = Vector3(4, 4, 4)
var once: bool = true
var cooldown: float = 0.0
var requires: PackedStringArray = []
var forbids: PackedStringArray = []
var actions: Array = []
var gate_check: Callable = Callable()
var fired_count: int = 0
var _cd: float = 0.0
var _inside: Node3D = null


func _ready() -> void:
	collision_layer = 1 << 4
	collision_mask = 1 << 1
	monitoring = true
	add_to_group(&"triggers")
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	add_child(cs)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func aabb() -> AABB:
	return AABB(global_position - size * 0.5, size)


func contains(p: Vector3) -> bool:
	return aabb().has_point(p)


func _on_enter(b: Node) -> void:
	if b.is_in_group(&"player"):
		_inside = b as Node3D
		try_fire(b)


func _on_exit(b: Node) -> void:
	if b == _inside:
		_inside = null


func _physics_process(delta: float) -> void:
	_cd -= delta
	# a player standing inside when the gate flags become true (or the cooldown ends) also fires
	if _inside != null and is_instance_valid(_inside):
		try_fire(_inside)


func armed() -> bool:
	if once and fired_count > 0:
		return false
	if _cd > 0.0:
		return false
	if gate_check.is_valid() and not bool(gate_check.call(requires, forbids)):
		return false
	return true


func try_fire(b: Node) -> bool:
	if not armed():
		return false
	fired_count += 1
	_cd = cooldown
	fired.emit(self, b)
	return true
