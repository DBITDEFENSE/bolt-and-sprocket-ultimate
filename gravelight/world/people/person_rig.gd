class_name PersonRig
extends Node3D
## A named person's modelled body on the shared ZombieRig skeleton, driven by a procedural puppet (T-092, UPDATE_05
## section 4). RemoteBody (the squad, Jakub) and PatronBody (the patrons, the survivors) keep their own pose
## solvers (hips, chest and head nodes, leg angles, hand targets with IK poles: every action, fidget and timing stays
## theirs); each frame they hand that pose to `drive()`, which turns it into bone rotations:
##   - Hips at the puppet's hip node (then lowered / raised so the lower foot meets the floor when `plant`);
##   - the puppet's chest rotation split over Spine and Chest, the head's over Neck and Head;
##   - legs from the puppet's thigh / knee angles (the same sagittal angles its cylinders used), feet flat;
##   - arms by two-bone IK from the rig's own shoulders to the puppet's hand targets, the elbow toward the pole.
## The node sits at the puppet's pivot origin (local -Z forward, feet at y = 0) and is scaled by the person's
## height (people.json, visual only: the capsule, hitboxes and every gameplay shape stay where they were).
## `person_id` "" = nothing built (no GLB: the owner keeps its primitives).

var person_id: String = ""
var skeleton: Skeleton3D = null
var body: MeshInstance3D = null
var face: FaceDriver = null
var scale_k: float = 1.0
var _idx: Dictionary = {}
var _rest: Dictionary = {}          # bone -> rest offset (Vector3)
var _attach: Dictionary = {}        # bone -> BoneAttachment3D


## Builds the body for person `id`; false when the person has no built GLB (the owner keeps its old body).
func setup(id: String, risen: bool = false) -> bool:
	if not PeopleBodies.available(id):
		return false
	var m: ArrayMesh = PeopleBodies.mesh(id, risen)
	if m == null:
		return false
	person_id = id
	name = "Person"
	scale_k = PeopleBodies.height_of(id)
	skeleton = ZombieRig.build_skeleton()
	skeleton.scale = Vector3.ONE * scale_k
	add_child(skeleton)
	body = MeshInstance3D.new()
	body.name = "Body"
	body.mesh = m
	skeleton.add_child(body)
	body.skeleton = NodePath("..")
	body.skin = skeleton.create_skin_from_rest_transforms()
	for b: String in ZombieRig.bone_names():
		_idx[b] = skeleton.find_bone(b)
		_rest[b] = ZombieRig.rest_offset(b)
	face = FaceDriver.attach(body, id)
	return true


## A node that follows a bone (props, the bandage).
func attachment(bone: String) -> BoneAttachment3D:
	if _attach.has(bone):
		return _attach[bone]
	var at: BoneAttachment3D = BoneAttachment3D.new()
	at.name = bone + "Attach"
	at.bone_name = bone
	skeleton.add_child(at)
	_attach[bone] = at
	return at


## One frame of pose, everything in this node's parent space (the puppet pivot):
##   hips: Vector3, the hip node's position; chest: Basis, the chest relative to the hips; head: Basis, the head
##   relative to the chest; legs: [[thigh_a, knee_a, foot_x], [...]] left, right (radians, the puppet's angles about
##   X: + swings the knee forward); hands: [Vector3, Vector3] targets or null (hang); poles: [Vector3, Vector3]
##   elbow directions; plant: keep the lower foot on the floor (standing, walking, sitting, kneeling).
func drive(d: Dictionary) -> void:
	if skeleton == null:
		return
	var s: float = scale_k
	var hips_p: Vector3 = (d.get("hips", Vector3(0, 0.95, 0)) as Vector3) / s
	var chest: Basis = d.get("chest", Basis.IDENTITY)
	var head: Basis = d.get("head", Basis.IDENTITY)
	var q_chest: Quaternion = chest.get_rotation_quaternion()
	var q_spine: Quaternion = Quaternion.IDENTITY.slerp(q_chest, 0.45)
	var q_chest_l: Quaternion = q_spine.inverse() * q_chest
	var q_head: Quaternion = head.get_rotation_quaternion()
	var q_neck: Quaternion = Quaternion.IDENTITY.slerp(q_head, 0.35)
	var q_head_l: Quaternion = q_neck.inverse() * q_head
	_rot("Spine", q_spine)
	_rot("Chest", q_chest_l)
	_rot("Neck", q_neck)
	_rot("Head", q_head_l)
	# legs from the puppet's angles; feet flat unless the puppet tilts them
	var legs: Array = d.get("legs", [])
	var soles: Array[float] = []
	for side: int in 2:
		var pre: String = "Left" if side == 0 else "Right"
		var la: Array = legs[side] if side < legs.size() else [0.0, 0.0, 0.0]
		var ta: float = float(la[0])
		var ka: float = float(la[1])
		var fx: float = float(la[2]) if la.size() > 2 else 0.0
		_rot(pre + "UpperLeg", Quaternion(Vector3.RIGHT, ta))
		_rot(pre + "LowerLeg", Quaternion(Vector3.RIGHT, ka))
		_rot(pre + "Foot", Quaternion(Vector3.RIGHT, fx - ta - ka))
		# the ankle and toe height relative to the hips (sagittal plane, rest offsets)
		var hip_o: Vector3 = _rest[pre + "UpperLeg"]
		var knee: Vector3 = hip_o + Basis(Vector3.RIGHT, ta) * (_rest[pre + "LowerLeg"] as Vector3)
		var ankle: Vector3 = knee + Basis(Vector3.RIGHT, ta + ka) * (_rest[pre + "Foot"] as Vector3)
		var foot_b: Basis = Basis(Vector3.RIGHT, fx)
		var heel: Vector3 = ankle + foot_b * Vector3(0, -0.07, 0.03)
		var toe: Vector3 = ankle + foot_b * Vector3(0, -0.06, -0.15)
		soles.append(minf(heel.y, toe.y))
	if bool(d.get("plant", false)) and not soles.is_empty():
		var low: float = minf(soles[0], soles[1])
		hips_p.y = -low   # the lower sole on the floor
	skeleton.set_bone_pose_position(int(_idx["Hips"]), hips_p)
	skeleton.set_bone_pose_rotation(int(_idx["Hips"]), Quaternion.IDENTITY)
	# arms: two-bone IK from the rig's shoulder (forward kinematics of the trunk) to the hand targets
	var hands: Array = d.get("hands", [])
	var poles: Array = d.get("poles", [])
	var g_hips: Transform3D = Transform3D(Basis.IDENTITY, hips_p)
	var g_spine: Transform3D = g_hips * Transform3D(Basis(q_spine), _rest["Spine"])
	var g_chest: Transform3D = g_spine * Transform3D(Basis(q_chest_l), _rest["Chest"])
	for side2: int in 2:
		var pre2: String = "Left" if side2 == 0 else "Right"
		var target: Variant = hands[side2] if side2 < hands.size() else null
		if target == null:
			_rot(pre2 + "UpperArm", Quaternion.IDENTITY)
			_rot(pre2 + "LowerArm", Quaternion(Vector3.RIGHT, 0.15))
			_rot(pre2 + "Hand", Quaternion.IDENTITY)
			continue
		var hand: Vector3 = (target as Vector3) / s
		var pole: Vector3 = poles[side2] if side2 < poles.size() else Vector3(-0.6 if side2 == 0 else 0.6, -1.0, 0.3)
		var sh: Vector3 = g_chest * (_rest[pre2 + "UpperArm"] as Vector3)
		var l1: float = (_rest[pre2 + "LowerArm"] as Vector3).length()
		var l2: float = (_rest[pre2 + "Hand"] as Vector3).length()
		var el: Vector3 = WeaponHolder._solve_elbow(sh, hand, l1, l2, pole)
		var reach: Vector3 = hand - el
		if reach.length() > l2:
			hand = el + reach.normalized() * l2
		var hinge: Vector3 = (el - sh).cross(hand - el)
		if hinge.length_squared() < 1e-8:
			hinge = g_chest.basis.x
		hinge = hinge.normalized()
		var b_up: Basis = _limb_basis(sh - el, hinge)
		var b_fo: Basis = _limb_basis(el - hand, hinge)
		var up_l: Basis = g_chest.basis.inverse() * b_up
		var fo_l: Basis = b_up.inverse() * b_fo
		_rot(pre2 + "UpperArm", up_l.get_rotation_quaternion())
		_rot(pre2 + "LowerArm", fo_l.get_rotation_quaternion())
		_rot(pre2 + "Hand", Quaternion(Vector3.RIGHT, -0.15))


## A bone basis whose +Y points along `up` (toward the parent: the bone hangs along -Y at rest) and +X along the hinge.
static func _limb_basis(up: Vector3, hinge: Vector3) -> Basis:
	var y: Vector3 = up.normalized()
	var x: Vector3 = (hinge - y * hinge.dot(y))
	if x.length_squared() < 1e-8:
		x = Vector3.RIGHT
	x = x.normalized()
	var z: Vector3 = x.cross(y).normalized()
	return Basis(x, y, z)


func _rot(bone: String, q: Quaternion) -> void:
	skeleton.set_bone_pose_rotation(int(_idx[bone]), q.normalized())


## Global (world) position of a bone, for tools and tests.
func bone_world(bone: String) -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(int(_idx[bone])).origin
