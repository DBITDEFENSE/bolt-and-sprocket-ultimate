class_name Pickup
extends Node3D
## A world pickup (spawnPickup / updatePickups / collectPickup, index.html:7698-7800). Group "pickups".
## Bolts are flung with a velocity, fall under gravity 20, settle 0.25 m above the floor, are pulled
## toward Bolt inside 4.5 m (lerp, damp 9) and collected inside 1.3 m. Flung bolts expire after 25 s.
## Kinds: &"bolt", &"ammo_r", &"ammo_z" (ammo orbs go to Bolt's "Weapons" node if it has add_ammo_orb()).
##
## LIEN garnish (BS_ENEMIES §3.1): while Bolt carries LIEN, every Nth collected bolt flies to the
## crawler that placed it instead and is added to that crawler's drops.

const GRAVITY: float = 20.0
const MAGNET_R: float = 4.5
const COLLECT_R: float = 1.3
const FLUNG_LIFE: float = 25.0

static var _garnish_count: int = 0

var kind: StringName = &"bolt"
var value: int = 1
var vel: Vector3 = Vector3.ZERO
var flying: bool = false
var life: float = INF
var t: float = 0.0
var settle_y: float = -INF
var kill_y: float = -60.0
var _garnish_to: Node3D = null
var _mesh: Node3D


static func spawn(parent: Node, kind_: StringName, pos: Vector3, vel_: Vector3 = Vector3.ZERO) -> Pickup:
	var p: Pickup = Pickup.new()
	p.kind = kind_
	p.vel = vel_
	p.flying = vel_ != Vector3.ZERO
	if p.flying and kind_ == &"bolt":
		p.life = FLUNG_LIFE
	parent.add_child(p)
	p.global_position = pos
	return p


## The kill fountain: n bolts flung up and out (killEnemy, index.html:5324).
static func fountain(parent: Node, center: Vector3, n: int) -> Array[Pickup]:
	var out: Array[Pickup] = []
	if parent == null:
		return out
	for i: int in n:
		out.append(spawn(parent, &"bolt", center, Vector3(randf_range(-3, 3), randf_range(4, 7), randf_range(-3, 3))))
	return out


func _ready() -> void:
	add_to_group(&"pickups")
	_mesh = Node3D.new()
	add_child(_mesh)
	if kind == &"bolt":
		var m: StandardMaterial3D = EnemyFx.mat(Color(1.0, 0.82, 0.24), Color(1.0, 0.7, 0.1), 0.8)
		m.metallic = 0.8
		var nut: MeshInstance3D = EnemyFx.cyl(_mesh, 0.16, 0.1, Vector3.ZERO, m)
		(nut.mesh as CylinderMesh).radial_segments = 6
		nut.rotation.x = PI / 2
		EnemyFx.cyl(_mesh, 0.06, 0.12, Vector3.ZERO, EnemyFx.mat(Color(0.25, 0.22, 0.15))).rotation.x = PI / 2
	else:
		var c: Color = Color(0.65, 0.3, 1.0) if kind == &"ammo_r" else Color(0.24, 0.9, 1.0)
		EnemyFx.sphere(_mesh, 0.22, Vector3.ZERO, EnemyFx.glow(c))
	t = randf() * 10.0
	if settle_y == -INF:
		settle_y = EnemyFx.floor_y(self, global_position, global_position.y - 0.25, 0.3, 40.0)


func _physics_process(delta: float) -> void:
	t += delta
	life -= delta
	_mesh.rotation.y += delta * 3.0
	if _garnish_to != null:
		_fly_to_garnish(delta)
		return
	if flying:
		vel.y -= GRAVITY * delta
		global_position += vel * delta
		if global_position.y <= settle_y + 0.25 and vel.y < 0.0:
			flying = false
			vel = Vector3.ZERO
			global_position.y = settle_y + 0.25
	else:
		global_position.y += sin(t * 2.5) * delta * 0.12
	var bolt: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if bolt != null and bool(bolt.call("is_alive")):
		var bp: Vector3 = bolt.global_position
		var d: float = global_position.distance_to(bp)
		if kind == &"bolt" and d < MAGNET_R:
			global_position = global_position.lerp(bp, 1.0 - exp(-9.0 * delta))
			d = global_position.distance_to(bp)
		if d < COLLECT_R:
			collect(bolt)
			return
	if global_position.y < kill_y or life <= 0.0:
		queue_free()


## Gives the pickup to Bolt (or garnishes it to the LIEN crawler). Returns true when Bolt got it.
func collect(bolt: Node) -> bool:
	if is_queued_for_deletion():
		return false
	if kind == &"bolt":
		var owner_: Node3D = LienCrawler.lien_owner_of(bolt)
		if owner_ != null:
			_garnish_count += 1
			var every: int = int((Data.table("bs/statuses") as Dictionary)["lien"]["garnish_every"])
			if _garnish_count % maxi(1, every) == 0:
				_garnish_to = owner_
				flying = false
				return false
		BS.add_bolts(value)
	else:
		var w: Node = bolt.get_node_or_null("Weapons")
		if w != null and w.has_method("add_ammo_orb"):
			w.call("add_ammo_orb", kind)
	queue_free()
	return true


func _fly_to_garnish(delta: float) -> void:
	if not is_instance_valid(_garnish_to) or not bool(_garnish_to.call("is_alive")):
		_garnish_to = null
		return
	var to: Vector3 = (_garnish_to.call("get_center") as Vector3) - global_position
	if to.length() < 0.8:
		_garnish_to.call("add_garnished", value)
		queue_free()
		return
	global_position += to.normalized() * minf(to.length(), 14.0 * delta)
