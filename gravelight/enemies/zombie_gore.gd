class_name ZombieGore
extends RefCounted
## Dismemberment (ZOMBIE_ANIM_SPEC §5, T-041): forearms, upper arms, lower legs, the head and the jaw come off.
## A severed chain collapses on the skinned body (its bones scale to zero), a stump cap mesh sits on the joint, and
## the chain's geometry flies off as a physics prop with a short lifetime (anim.json gore.piece_seconds, at most
## gore.max_pieces live). The Gore setting (GLSettings "gore": off / low / full) gates it: Off keeps every limb on
## and no blood; Low severs without the spray.

static var _pieces: Array[RigidBody3D] = []
const STUMP_FLIP: PackedStringArray = ["Head", "Jaw"]


static func level() -> String:
	if not Engine.is_editor_hint() and Engine.get_main_loop() != null and (Engine.get_main_loop() as SceneTree).root.has_node("GLSettings"):
		return str(GLSettings.values.get("gore", "full"))
	return "full"


static func severs_allowed() -> bool:
	return level() != "off"


static func blood_allowed() -> bool:
	return level() == "full"


static func cfg() -> Dictionary:
	return GLData.table("anim")["gore"]


## Hides the chain under `bone` on the skinned body and caps the joint. Returns false when gore is off.
static func sever(z: Zombie, bone: String, impulse: Vector3, with_piece: bool = true) -> bool:
	if not severs_allowed():
		return false
	var skel: Skeleton3D = z.skeleton()
	if skel == null or skel.find_bone(bone) < 0:
		return false
	if z.is_severed(bone):
		return false
	if with_piece:
		_throw_piece(z, bone, impulse)
	for b: String in ZombieRig.chain_of(bone):
		var bi: int = skel.find_bone(b)
		if bi >= 0:
			skel.set_bone_pose_scale(bi, Vector3.ONE * 0.001)
	z.mark_severed(bone)
	_cap(z, bone)
	if blood_allowed():
		var at: Node3D = z.bone_attachment(ZombieRig.parent_of(bone))
		var p: Vector3 = at.to_global(ZombieRig.rest_offset(bone)) if at != null else z.global_position + Vector3.UP
		for i: int in 2:
			Effects.blood(p, impulse.normalized() if impulse.length_squared() > 0.01 else Vector3.UP)
	return true


static func _cap(z: Zombie, bone: String) -> void:
	var parent: String = ZombieRig.parent_of(bone)
	var at: Node3D = z.bone_attachment(parent)
	if at == null:
		return
	var cap: MeshInstance3D = z.stump_cap(bone)
	if cap.get_parent() != at:
		if cap.get_parent() != null:
			cap.get_parent().remove_child(cap)
		at.add_child(cap)
	cap.position = ZombieRig.rest_offset(bone)
	cap.rotation = Vector3(PI, 0, 0) if STUMP_FLIP.has(bone) else Vector3.ZERO
	cap.show()


static func _throw_piece(z: Zombie, bone: String, impulse: Vector3) -> void:
	var host: Node = z.get_parent()
	var at: Node3D = z.bone_attachment(bone)
	if host == null or at == null:
		return
	var c: Dictionary = cfg()
	_pieces.assign(_pieces.filter(func(p: Variant) -> bool: return is_instance_valid(p)))   # keeps the typed array; freed bodies drop out
	while _pieces.size() >= int(c.get("max_pieces", 12)):
		var old: RigidBody3D = _pieces.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var body: RigidBody3D = RigidBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 1
	body.mass = 2.0 if bone != "Head" else 3.0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: SphereShape3D = SphereShape3D.new()
	sh.radius = 0.08
	cs.shape = sh
	body.add_child(cs)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = ZombieBody.piece_mesh(z.kit_name(), z.build_name(), z.is_female(), bone)
	mi.scale = z.pivot_scale()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)
	var stump: MeshInstance3D = MeshInstance3D.new()
	stump.mesh = ZombieBody.stump_mesh()
	stump.rotation = Vector3.ZERO if STUMP_FLIP.has(bone) else Vector3(PI, 0, 0)
	stump.scale = z.pivot_scale()
	body.add_child(stump)
	host.add_child(body)
	body.global_transform = at.global_transform
	body.linear_velocity = impulse
	body.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	_pieces.append(body)
	host.get_tree().create_timer(float(c.get("piece_seconds", 4.0))).timeout.connect(func() -> void:
		if is_instance_valid(body):
			body.queue_free())


static func live_pieces() -> int:
	_pieces.assign(_pieces.filter(func(p: Variant) -> bool: return is_instance_valid(p)))
	return _pieces.size()


## Restores every bone's scale and hides the caps (pool reuse).
static func restore(z: Zombie) -> void:
	var skel: Skeleton3D = z.skeleton()
	if skel == null:
		return
	for i: int in skel.get_bone_count():
		skel.set_bone_pose_scale(i, Vector3.ONE)
	z.clear_severed()
