class_name MalletSwitch
extends StaticBody3D
## A yellow-black bullseye plate `(B)` hit by the boomerang mallet throw. In group "mallet_switches";
## BoltMelee calls on_mallet(bolt) when the thrown mallet passes within 1.4 m (either leg). The plate is a
## world-layer collider so the throw stops on it and turns back right at the switch.
## gadget "" = any throw; "magma" needs mallet_tier >= 1, "thunder" >= 2 (Magma / Thunder throw targets).
## one_shot switches stay down; others re-arm after `cooldown`.

signal switched(sw: MalletSwitch, bolt: Node)

var switch_id: String = ""
var actions: Array = []
var one_shot: bool = true
var cooldown: float = 1.0
var gadget: String = ""
var size: Vector2 = Vector2(1.0, 1.0)
var is_down: bool = false
var hits: int = 0
var _cd: float = 0.0
var _face: MeshInstance3D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group(&"mallet_switches")
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = Vector3(size.x, size.y, 0.2)
	cs.shape = sh
	add_child(cs)
	LevelKit.box(self, Vector3.ZERO, Vector3(size.x, size.y, 0.2), "#232838", false)
	var ring_col: String = "#ffd23e" if gadget == "" else ("#ff7a1e" if gadget == "magma" else "#3ea8ff")
	_face = LevelKit.box(self, Vector3(0, 0, 0.11), Vector3(size.x * 0.7, size.y * 0.7, 0.02), ring_col, false, Vector3.ZERO, 1, 0.8) as MeshInstance3D
	LevelKit.box(self, Vector3(0, 0, 0.125), Vector3(size.x * 0.3, size.y * 0.3, 0.02), "#111111", false)


func _physics_process(delta: float) -> void:
	_cd -= delta


func can_trigger() -> bool:
	if one_shot and is_down:
		return false
	if _cd > 0.0:
		return false
	if gadget == "magma" and BS.mallet_tier < 1:
		return false
	if gadget == "thunder" and BS.mallet_tier < 2:
		return false
	return true


func on_mallet(bolt: Node) -> void:
	if not can_trigger():
		return
	hits += 1
	_cd = cooldown
	is_down = true
	if _face != null:
		_face.material_override = LevelKit.mat("#3ee66a", 1.0)
	switched.emit(self, bolt)
	if not one_shot:
		_rearm.call_deferred()


func _rearm() -> void:
	await get_tree().create_timer(cooldown).timeout
	if is_instance_valid(self):
		is_down = false
		if _face != null:
			_face.material_override = LevelKit.mat("#ffd23e", 0.8)
