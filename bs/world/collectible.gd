class_name Collectible
extends Area3D
## Base for things Bolt picks up by touching them (gold bolts, memos, quest items, level items).
## Area3D on the pickups layer (8) that watches the player layer (2). In group "pickups" so the boomerang
## mallet collects it too (BoltMelee calls collect(bolt) on pickups within 1.2 m of its path).

signal collected(item: Collectible, bolt: Node)

var radius: float = 0.9
var spin_speed: float = 2.2
var bob_height: float = 0.12
var visual: Node3D
var taken: bool = false
var _t: float = 0.0
var _base_y: float = 0.0


func _ready() -> void:
	collision_layer = 1 << 7
	collision_mask = 1 << 1
	monitoring = true
	monitorable = true
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: SphereShape3D = SphereShape3D.new()
	sh.radius = radius
	cs.shape = sh
	add_child(cs)
	add_to_group(&"pickups")
	visual = _make_visual()
	if visual != null:
		add_child(visual)
		_base_y = visual.position.y
	body_entered.connect(_on_body_entered)
	_t = randf() * TAU


func _process(delta: float) -> void:
	if visual == null or not is_visible_in_tree():
		return
	_t += delta
	visual.rotation.y += spin_speed * delta
	visual.position.y = _base_y + sin(_t * 2.0) * bob_height


func _on_body_entered(b: Node) -> void:
	if b.is_in_group(&"player"):
		collect(b)


## True when it was taken by this call.
func collect(bolt: Node) -> bool:
	if taken or not visible or not can_collect():
		return false
	taken = true
	_on_collect(bolt)
	collected.emit(self, bolt)
	queue_free()
	return true


## Hidden collectibles (e.g. a memo that appears after a cutscene) cannot be taken until shown.
func reveal(on: bool = true) -> void:
	visible = on
	set_deferred(&"monitoring", on)


# ---- overrides
func can_collect() -> bool:
	return true


func _on_collect(_bolt: Node) -> void:
	pass


func _make_visual() -> Node3D:
	return null
