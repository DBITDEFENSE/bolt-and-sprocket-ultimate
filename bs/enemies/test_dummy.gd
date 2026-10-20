class_name TestDummy
extends StaticBody3D
## Firing-range / test target implementing the Combat contract. Records every hit it takes.
## Used by the firing range (M6) and by integration tests.

var hp: float = 100.0
var max_hp: float = 100.0
var radius: float = 0.5
var hits: Array = []           # Combat.Hit history
var launched: float = 0.0


func _ready() -> void:
	add_to_group(&"enemies")
	add_to_group(&"damageable")
	collision_layer = 1 << 2
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: CapsuleShape3D = CapsuleShape3D.new()
	sh.radius = radius
	sh.height = 1.8
	cs.shape = sh
	cs.position.y = 0.9
	add_child(cs)
	var st: StatusEffects = StatusEffects.new()
	st.name = "Status"
	add_child(st)


func take_damage(hit: Combat.Hit) -> bool:
	if hp <= 0.0:
		return false
	hits.append(hit)
	hp -= hit.amount
	launched = maxf(launched, hit.launch)
	for id: Variant in hit.status.keys():
		(get_node("Status") as StatusEffects).apply(StringName(str(id)), float(hit.status[id]))
	return hp <= 0.0


func get_center() -> Vector3:
	return global_position + Vector3(0, 0.9, 0)


func is_alive() -> bool:
	return hp > 0.0


func total_damage() -> float:
	var t: float = 0.0
	for h: Variant in hits:
		t += (h as Combat.Hit).amount
	return t
