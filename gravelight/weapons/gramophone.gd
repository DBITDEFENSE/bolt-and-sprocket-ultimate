class_name Gramophone
extends RigidBody3D
## Siren Gramophone (tactical): thrown, lands, plays its record, lures zombies for 8 s, then detonates.
## Zombies find active lures through the "lures" group (see Zombie._update_chase).

var cfg: Dictionary = {}
var by_player: int = 1
## Co-op client: the thrower's own copy is only for show; the host's twin lures and detonates.
var visual_only: bool = false
var _t: float = 0.0
var _playing: bool = false
var _disc: MeshInstance3D
var _record: AudioStreamPlayer3D     # the looping record; a child, so it stops and frees with the gramophone
var _record_delay: float = -1.0


func _ready() -> void:
	collision_layer = 1 << 6
	collision_mask = 1 | (1 << 8)
	mass = 2.0
	var pm: PhysicsMaterial = PhysicsMaterial.new()
	pm.bounce = 0.05
	pm.friction = 1.0
	physics_material_override = pm
	angular_damp = 6.0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.3, 0.18, 0.3)
	cs.shape = box
	add_child(cs)
	var wood: StandardMaterial3D = Interactable.greybox_mat(Color(0.35, 0.2, 0.1))
	Interactable.add_box(self, Vector3(0.3, 0.16, 0.3), Vector3.ZERO, wood)
	_disc = Interactable.add_box(self, Vector3(0.26, 0.015, 0.26), Vector3(0, 0.09, 0), Interactable.greybox_mat(Color(0.05, 0.05, 0.05)))
	var horn: MeshInstance3D = Interactable.add_box(self, Vector3(0.16, 0.16, 0.3), Vector3(0.05, 0.25, -0.1), Interactable.greybox_mat(Color(0.75, 0.6, 0.25), 0.6))
	horn.rotation.x = -0.6


func _physics_process(delta: float) -> void:
	_t += delta
	if not _playing and (_t > 0.6 and linear_velocity.length() < 0.3 or _t > 2.5):
		_playing = true
		_t = 0.0
		freeze = true
		if not visual_only:
			add_to_group(&"lures")
		_start_record()
	if not _playing:
		return
	_disc.rotation.y += delta * 4.0
	if _record_delay > 0.0:
		_record_delay -= delta
		if _record_delay <= 0.0 and _record != null:
			_record.play()
	if _t >= float(cfg.get("lure_seconds", 8.0)):
		remove_from_group(&"lures")
		if _record != null:
			_record.stop()
		if not visual_only:
			var blast: Dictionary = {"damage": cfg.get("damage", 1500), "radius": cfg.get("radius", 7.0), "edge_mult": 0.6,
				"self_damage_near": 0, "self_damage_far": 0}
			Explosion.detonate(self, global_position + Vector3.UP * 0.3, blast, by_player, &"gramophone")
		queue_free()


## Needle drop, then the record loops until detonation.
func _start_record() -> void:
	AudioDirector.play_3d("gramophone_needle", global_position, 0.0, 0.0)
	_record = AudioDirector.make_loop_3d("gramophone_record", self)
	if _record != null:
		_record.position = Vector3.UP * 0.25
		_record_delay = 0.35


func lure_radius() -> float:
	return float(cfg.get("lure_radius", 25.0))
