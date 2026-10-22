class_name ThreshingDrum
extends AnimatableBody3D
## A threshing drum inside the Mega-Harvester (BS_LEVELS §6.5): a timed rotating platform (0.5 rad/s, the
## Foundry gear-shaft value) Bolt rides across the guts. World layer, sync_to_physics so his feet follow it.
## Ribs on the top face read the spin; a drum with a negative `rate` turns the other way.

var drum_id: String = ""
var r: float = 2.4
var h: float = 0.6
var rate: float = 0.5
var _t: float = 0.0
var _delta: Vector3 = Vector3.ZERO


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = true
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: CylinderShape3D = CylinderShape3D.new()
	sh.radius = r
	sh.height = h
	cs.shape = sh
	add_child(cs)
	LevelKit.cylinder(self, Vector3.ZERO, r, h, "#5a6377", false)
	LevelKit.cylinder(self, Vector3(0, h * 0.5 + 0.02, 0), r * 0.25, 0.08, "#ffd23e", false, "y", -1.0, 0.8)
	for i: int in 6:
		var a: float = TAU * float(i) / 6.0
		LevelKit.box(self, Vector3(cos(a) * r * 0.55, h * 0.5 + 0.06, sin(a) * r * 0.55), Vector3(r * 0.8, 0.1, 0.18), "#7a4a2a", false,
			Vector3(0, -rad_to_deg(a), 0))


## Bolt rides it through get_platform_delta() (Bolt._move adds the ground collider's frame delta): the delta of
## the point under his feet for this frame's turn.
func get_platform_delta() -> Vector3:
	return _delta


func _physics_process(delta: float) -> void:
	_t += delta
	rotation.y = _t * rate
	_delta = Vector3.ZERO
	var b: Node3D = LevelKit.player(get_tree())
	if b == null:
		return
	var rel: Vector3 = b.global_position - global_position
	rel.y = 0.0
	if rel.length() > r + 0.6:
		return
	_delta = rel.rotated(Vector3.UP, rate * delta) - rel
