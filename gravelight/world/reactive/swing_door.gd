class_name SwingDoor
extends Node3D
## An old interior door left ajar (Update 02 section 8, T-053): a plank leaf on a hinge at the node's origin (local
## +X along the shut leaf, or -X when `flip`; it opens toward local -Z), standing at `rest_deg`. Anyone who comes
## through the doorway (players and zombies: a box zone watching physics layers 2 and 3) swings it right back to
## `open_deg`, out of the way; it drifts back toward rest in the draught, and it creaks when it moves. The leaf never collides, so it can't
## snag anyone or change the navmesh. Idle while nobody is near and it hangs still.

const BODY_MASK: int = (1 << 1) | (1 << 2)
const CREAK: String = "door_creak"

@export var width: float = 1.4
@export var height: float = 2.1
@export var rest_deg: float = 55.0
@export var open_deg: float = 100.0
@export var mat_key: String = "planks"
## The leaf runs along -X from the hinge (hinged on the doorway's other jamb).
@export var flip: bool = false
## The doorway zone: its size and its centre in this node's frame.
@export var zone_size: Vector3 = Vector3(1.6, 2.0, 3.2)
@export var zone_center: Vector3 = Vector3(0.75, 1.0, 0.0)

var angle: float = 0.0       # degrees
var creaks: int = 0
var _v: float = 0.0
var _leaf: Node3D
var _near: int = 0
var _creak_cd: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	angle = rest_deg
	_leaf = Node3D.new()
	_leaf.name = "Leaf"
	add_child(_leaf)
	var art: Node3D = Node3D.new()   # the leaf's parts, mirrored for a flipped door
	art.name = "Art"
	art.rotation.y = PI if flip else 0.0
	_leaf.add_child(art)
	var w: float = width - 0.04
	Props.block(art, Vector3(0.02, 0.0, -0.02), Vector3(w, height, 0.02), mat_key).set_meta("keep", true)
	for y: float in [0.25, height - 0.3]:   # ledges
		Props.block(art, Vector3(0.06, y - 0.06, 0.02), Vector3(w - 0.04, y + 0.06, 0.035), "beam").set_meta("keep", true)
	var brace: Vector2 = Vector2(w - 0.2, height - 0.6)   # the Z brace between the ledges
	Props.obox(art, Vector3(w * 0.5, height * 0.5, 0.03), Vector3(0.1, brace.length(), 0.015), "beam", Vector3(0, 0, -rad_to_deg(atan2(brace.x, brace.y)))).set_meta("keep", true)
	Props.cyl(art, Vector3(w - 0.12, 1.0, -0.05), 0.025, 0.05, "brass", Vector3(90, 0, 0)).set_meta("keep", true)
	Props.cyl(art, Vector3(w - 0.12, 1.0, 0.06), 0.025, 0.05, "brass", Vector3(90, 0, 0)).set_meta("keep", true)
	var zone: Area3D = Area3D.new()
	zone.name = "Doorway"
	zone.collision_layer = 0
	zone.collision_mask = BODY_MASK
	zone.monitorable = false
	var cs: CollisionShape3D = CollisionShape3D.new()
	var b: BoxShape3D = BoxShape3D.new()
	b.size = zone_size
	cs.shape = b
	cs.position = Vector3(-zone_center.x, zone_center.y, zone_center.z) if flip else zone_center
	zone.add_child(cs)
	add_child(zone)
	zone.body_entered.connect(func(_b: Node3D) -> void:
		_near += 1
		set_process(true))
	zone.body_exited.connect(func(_b: Node3D) -> void: _near = maxi(0, _near - 1))
	_apply()


func _process(delta: float) -> void:
	_t += delta
	_creak_cd -= delta
	var target: float = open_deg if _near > 0 else rest_deg + sin(_t * 0.7) * 3.0 * ReactiveWind.strength(get_tree())
	var k: float = 14.0 if _near > 0 else 1.6
	_v += ((target - angle) * k - _v * (5.0 if _near > 0 else 2.2)) * delta
	angle += _v * delta
	angle = clampf(angle, 0.0, open_deg + 5.0)
	_apply()
	if absf(_v) > 25.0 and _creak_cd <= 0.0:
		_creak_cd = 1.4
		creaks += 1
		if AudioDirector.has_sound(CREAK):
			AudioDirector.play_3d(CREAK, global_position + Vector3(0, 1.4, 0), -6.0, 0.1)
	if _near == 0 and absf(_v) < 0.05 and absf(angle - rest_deg) < 4.0 and ReactiveWind.strength(get_tree()) < 0.5:
		set_process(false)


func _apply() -> void:
	if _leaf != null:
		_leaf.rotation.y = deg_to_rad(-angle if flip else angle)
