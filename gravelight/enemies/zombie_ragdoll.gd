class_name ZombieRagdoll
extends RefCounted
## Full-body ragdoll for zombie deaths (ZOMBIE_ANIM_SPEC §4, T-041): a PhysicalBoneSimulator3D with one
## PhysicalBone3D per major bone (anim.json ragdoll.bones), built on the skeleton the moment a death clip reaches
## its key pose and freed when the corpse dissolves. Caps: ragdoll.max_live simultaneous simulations (the oldest
## freezes in place, settle_freeze_seconds after it started). Explosive deaths launch every bone.

static var _live: Array = []   # [PhysicalBoneSimulator3D, start msec]
## Below this global bone scale a bone counts as severed (ZombieGore collapses chains to 0.001).
const SEVERED_SCALE: float = 0.01


static func cfg() -> Dictionary:
	return GLData.table("anim")["ragdoll"]


static func enabled() -> bool:
	return bool(cfg().get("enabled", true))


static func live_count() -> int:
	_prune()
	return _live.size()


static func _prune() -> void:
	var keep: Array = []
	for e: Array in _live:
		if is_instance_valid(e[0]) and (e[0] as Node).is_inside_tree() and (e[0] as PhysicalBoneSimulator3D).is_simulating_physics():
			keep.append(e)
	_live = keep


## Builds the physical bones under `skel` and starts simulating, launched by `impulse` (m/s on every bone).
## Returns the simulator (null when ragdolls are off).
static func start(skel: Skeleton3D, impulse: Vector3 = Vector3.ZERO) -> PhysicalBoneSimulator3D:
	if not enabled() or skel == null:
		return null
	_prune()
	var c: Dictionary = cfg()
	tick()
	var live_cap: int = int(c.get("max_live", 6))
	if live_cap <= 0:
		return null
	while _live.size() >= live_cap:
		# Preserve the settled pose, but spend the simulation budget on the newest death.
		var oldest: Array = _live.pop_front()
		freeze(oldest[0] as PhysicalBoneSimulator3D)
	var sim: PhysicalBoneSimulator3D = PhysicalBoneSimulator3D.new()
	sim.name = "Ragdoll"
	var joint: Dictionary = c.get("joint", {})
	var bones: Dictionary = c.get("bones", {})
	for bone: String in bones.keys():
		if skel.find_bone(bone) < 0:
			continue
		var spec: Dictionary = bones[bone]
		var pb: PhysicalBone3D = PhysicalBone3D.new()
		pb.name = "PB_" + bone
		pb.bone_name = bone
		pb.mass = float(spec.get("mass", 2.0))
		pb.collision_layer = 0
		pb.collision_mask = 1
		pb.angular_damp = float(joint.get("damping", 0.8))
		pb.linear_damp = float(joint.get("linear_damp", 0.5))
		pb.can_sleep = true
		var cs: CollisionShape3D = CollisionShape3D.new()
		var size: Array = spec.get("size", [0.1, 0.1, 0.1])
		var off: Array = spec.get("offset", [0, 0, 0])
		var offset: Vector3 = Vector3(float(off[0]), float(off[1]), float(off[2]))
		match str(spec.get("shape", "capsule")):
			"box":
				var b: BoxShape3D = BoxShape3D.new()
				b.size = Vector3(float(size[0]), float(size[1]), float(size[2]))
				cs.shape = b
			"sphere":
				var s: SphereShape3D = SphereShape3D.new()
				s.radius = float(size[0])
				cs.shape = s
			_:
				var cap: CapsuleShape3D = CapsuleShape3D.new()
				cap.radius = float(size[0])
				cap.height = maxf(float(size[1]), cap.radius * 2.0 + 0.01)
				cs.shape = cap
				offset = Vector3(0, -float(size[1]) * 0.5, 0)
		pb.add_child(cs)
		pb.body_offset = Transform3D(Basis.IDENTITY, offset)
		if bone == "Hips":
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_NONE
		elif str(joint.get("type", "pin")) == "cone":
			# cone limits snap violently when the death's key pose already exceeds them (bent knees, raised arms)
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
			pb.set("joint_constraints/swing_span", float(joint.get("swing_deg", 35.0)))
			pb.set("joint_constraints/twist_span", float(joint.get("twist_deg", 20.0)))
			pb.set("joint_constraints/relaxation", 1.0)
		else:
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_PIN
		sim.add_child(pb)
	# the bones must be under the simulator before it enters the skeleton: its bone cache is built on entry
	skel.add_child(sim)
	sim.physical_bones_start_simulation()
	# the simulator's own modifier pass is switched off: it writes the rest pose over the skeleton once the
	# AnimationTree is inactive; sync() copies the bodies into the bones instead (Zombie._update_dead)
	sim.active = false
	if impulse.length_squared() > 0.01:
		# the blast throws the trunk; the limbs follow through the joints (an impulse on every bone tears the
		# joints apart and launches the rig)
		for bone_name: String in ["Hips", "Chest"]:
			var pb2: PhysicalBone3D = sim.get_node_or_null("PB_" + bone_name) as PhysicalBone3D
			if pb2 != null:
				pb2.apply_central_impulse(impulse * pb2.mass)
	_live.append([sim, Time.get_ticks_msec()])
	return sim


## Writes the simulated bodies back into the skeleton (bone global pose = body transform less its offset). The
## simulator's own modifier pass does not reach a skeleton whose AnimationTree was switched off, so the corpse
## owner calls this every physics step while the rig is live.
static func sync(sim: PhysicalBoneSimulator3D, skel: Skeleton3D) -> void:
	if sim == null or skel == null or not is_instance_valid(sim):
		return
	var inv: Transform3D = skel.global_transform.affine_inverse()
	for ch: Node in sim.get_children():
		var pb: PhysicalBone3D = ch as PhysicalBone3D
		if pb == null:
			continue
		var bi: int = pb.get_bone_id()
		if bi < 0:
			continue
		var t: Transform3D = inv * pb.global_transform * pb.body_offset.affine_inverse()
		var b: Basis = t.basis.orthonormalized()
		# A severed chain (ZombieGore.sever) is collapsed to ~0 scale: keep it collapsed, or the head / arm the
		# player shot off reappears on the corpse. Checked on the bone's current global scale, which covers the
		# chain root (its own pose scale) and the bones under it (a collapsed parent).
		if skel.get_bone_global_pose(bi).basis.get_scale().x < SEVERED_SCALE:
			b = b.scaled(Vector3.ONE * 0.001)
		skel.set_bone_global_pose(bi, Transform3D(b, t.origin))


## Stops simulating: the pose the bones are in stays (the simulator keeps the skeleton at the last physics pose).
static func freeze(sim: PhysicalBoneSimulator3D) -> void:
	if sim == null or not is_instance_valid(sim):
		return
	if sim.is_simulating_physics():
		sim.physical_bones_stop_simulation()
	for ch: Node in sim.get_children():
		var pb: PhysicalBone3D = ch as PhysicalBone3D
		if pb != null:
			pb.collision_mask = 0


## Frees the rig. The skeleton falls back to its animated pose.
static func stop(sim: PhysicalBoneSimulator3D) -> void:
	if sim == null or not is_instance_valid(sim):
		return
	for i: int in range(_live.size() - 1, -1, -1):
		if _live[i][0] == sim:
			_live.remove_at(i)
	if sim.is_simulating_physics():
		sim.physical_bones_stop_simulation()
	sim.active = false
	if sim.get_parent() != null:
		sim.get_parent().remove_child(sim)
	sim.queue_free()


## Simulations older than settle_freeze_seconds freeze (their pose is final; cheaper than a sleeping rig).
static func tick() -> void:
	_prune()
	var now: int = Time.get_ticks_msec()
	var settle: int = int(float(cfg().get("settle_freeze_seconds", 3.0)) * 1000.0)
	for e: Array in _live:
		if now - int(e[1]) > settle:
			var sim: PhysicalBoneSimulator3D = e[0]
			if sim.is_simulating_physics():
				freeze(sim)
