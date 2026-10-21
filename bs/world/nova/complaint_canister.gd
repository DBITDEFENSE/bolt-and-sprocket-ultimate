class_name ComplaintCanister
extends RigidBody3D
## A "Formal Complaint" canister printed by a FineTree Plaza complaint kiosk (BS_LEVELS §4.10). Bolt punts it
## (any melee or shot: take_damage applies an impulse along the hit) or mallet-throws it into one of the
## Algorithm's intake slots; the slot's Area3D reports it (FineTreeArena.notice_delivered). Group
## "complaint_canisters" and "damageable" (not "enemies": aim assist and quests ignore it). It despawns
## after `life` seconds or when it falls off the plaza.

var notice_value: float = 1.0
var life: float = 30.0
var radius: float = 0.35
var punts: int = 0
var source_kiosk: Node = null
var kick: float = 9.0
var lift: float = 5.0
var _t: float = 0.0
var _gone: bool = false


func _ready() -> void:
	add_to_group(&"complaint_canisters")
	add_to_group(&"damageable")
	collision_layer = 1 << 5
	collision_mask = 1 | (1 << 5)
	mass = 1.0
	contact_monitor = false
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: CylinderShape3D = CylinderShape3D.new()
	sh.radius = radius
	sh.height = 0.8
	cs.shape = sh
	add_child(cs)
	LevelKit.cylinder(self, Vector3.ZERO, radius, 0.8, "#f2f2e8")
	LevelKit.cylinder(self, Vector3(0, 0.43, 0), radius * 0.9, 0.08, "#ff4d9d", false, "y", -1.0, 1.4)
	LevelKit.box(self, Vector3(0, 0, radius + 0.01), Vector3(0.4, 0.3, 0.02), "#c9302a", false)
	var st: StatusEffects = StatusEffects.new()
	st.name = "Status"
	add_child(st)


func take_damage(hit: Combat.Hit) -> bool:
	if _gone:
		return false
	punts += 1
	var d: Vector3 = hit.dir if hit.dir.length() > 0.1 else (global_position - (hit.point if hit.point != Vector3.ZERO else global_position + Vector3.BACK)).normalized()
	d.y = 0.0
	apply_central_impulse(d.normalized() * kick * mass + Vector3.UP * lift * mass)
	return false


## Thrown mallets and slots call this.
func consume() -> void:
	if _gone:
		return
	_gone = true
	queue_free()


func get_center() -> Vector3:
	return global_position


func is_alive() -> bool:
	return not _gone


func _physics_process(delta: float) -> void:
	_t += delta
	if _t > life or global_position.y < -5.0:
		consume()
