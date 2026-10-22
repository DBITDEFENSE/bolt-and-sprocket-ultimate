class_name HayPuffZone
extends Area3D
## Loose hay or straw that puffs up when anything walks through it (Update 02 section 8, T-053): a box zone that
## watches players and zombies (physics layers 2 and 3); while one moves faster than MIN_SPEED inside it, a puff of
## chaff (ReactiveFx) rises at its feet every STEP_SECONDS. Idle (no processing) while the zone is empty. (Shots
## into hay already throw chaff: GunFx's "hay" surface.) Local presentation: every peer sees the bodies move, so
## every peer gets the puffs.

const MIN_SPEED: float = 1.0
const STEP_SECONDS: float = 0.32
const BODY_MASK: int = (1 << 1) | (1 << 2)   # player, zombie body

@export var size: Vector3 = Vector3(2, 0.6, 2)
@export var tint: Color = Color(0.82, 0.7, 0.4)

var puffs: int = 0
var _inside: Dictionary = {}   # body -> seconds to its next puff


func _ready() -> void:
	collision_layer = 0
	collision_mask = BODY_MASK
	monitorable = false
	monitoring = true
	if get_child_count() == 0:
		var cs: CollisionShape3D = CollisionShape3D.new()
		var b: BoxShape3D = BoxShape3D.new()
		b.size = size
		cs.shape = b
		cs.position = Vector3(0, size.y * 0.5, 0)
		add_child(cs)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	set_physics_process(false)


func _on_enter(b: Node3D) -> void:
	_inside[b] = 0.0
	set_physics_process(true)


func _on_exit(b: Node3D) -> void:
	_inside.erase(b)
	if _inside.is_empty():
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	for b: Variant in _inside.keys():
		if not is_instance_valid(b):
			_inside.erase(b)
			continue
		var body: CharacterBody3D = b as CharacterBody3D
		var cd: float = float(_inside[b]) - delta
		if body != null and body.visible and Vector2(body.velocity.x, body.velocity.z).length() > MIN_SPEED and cd <= 0.0:
			cd = STEP_SECONDS * randf_range(0.8, 1.25)
			var fx: ReactiveFx = ReactiveFx.get_for(self)
			if fx != null:
				fx.chaff(body.global_position + Vector3(0, 0.12, 0), tint)
				puffs += 1
		_inside[b] = cd
	if _inside.is_empty():
		set_physics_process(false)
