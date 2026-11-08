class_name LipSyncBones
extends SkeletonModifier3D
## T-210: the lip sync on a head with no blend shapes (the relief squads' and the cutscenes' dressed bodies, built by
## ZombieBody.build_dressed): FaceDriver sets `jaw` and `brow` (0..1) each frame and this opens the Jaw bone (a -X
## turn about its hinge: the way the people's jaw_open shape moves the jaw, test_mocap checks it on Dutch's mesh) and
## lifts the chin a touch on the open vowels (the brow beat, +X on Head). It runs after the pose solver, so the jaw
## adds to whatever the body is doing and the head lift adds to its look.

const JAW_MAX: float = 0.42     # radians at jaw = 1 (a wide AA)
const BROW_MAX: float = 0.07    # radians of head lift at brow = 1
const JAW_SIGN: float = -1.0    # the opening direction about +X

var jaw: float = 0.0
var brow: float = 0.0
var _jaw_i: int = -2
var _head_i: int = -2


func _process_modification_with_delta(_delta: float) -> void:
	apply()


func apply() -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null:
		sk = get_parent() as Skeleton3D
	if sk == null:
		return
	if _jaw_i == -2:
		_jaw_i = sk.find_bone("Jaw")
		_head_i = sk.find_bone("Head")
	if _jaw_i >= 0:
		sk.set_bone_pose_rotation(_jaw_i, sk.get_bone_pose_rotation(_jaw_i) * Quaternion(Vector3.RIGHT, JAW_SIGN * clampf(jaw, 0.0, 1.0) * JAW_MAX))
	if _head_i >= 0 and brow > 0.001:
		sk.set_bone_pose_rotation(_head_i, sk.get_bone_pose_rotation(_head_i) * Quaternion(Vector3.RIGHT, clampf(brow, 0.0, 1.0) * BROW_MAX))
