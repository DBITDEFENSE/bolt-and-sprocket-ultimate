class_name HomagePoseMod
extends SkeletonModifier3D
## Post-animation pose layer for the homage bosses (HB1, docs/HOMAGE_BOSSES.md section 3.4): the shared MZ clips
## drive the body, and this adds each boss's own shapes on top of them, per bone:
##   - rot: an extra local rotation (Euler, radians) applied after the animated rotation (raise an arm overhead,
##     coil it over the shoulder, both hands to the ears);
##   - pos: an extra local translation (the Reach's telescoped forearm and hand: the arm chain grows);
##   - scl: a local scale multiplier.
## The boss sets targets (set_bone / clear); the layer eases toward them at `rate`, so poses blend in and out.
## `hold` freezes the whole skeleton on the pose it had (ObservedFreeze, the catch-freeze, the doll topple).

var rate: float = 10.0
var hold: bool = false

var _targets: Dictionary = {}   # bone name -> {rot, pos, scl}
var _current: Dictionary = {}   # bone name -> {rot, pos, scl}
var _idx: Dictionary = {}
var _held: Dictionary = {}      # bone index -> [pos, rot, scl] captured when hold went on


## Sets a bone's target offsets. Unset parts stay neutral.
func set_bone(bone: String, rot: Vector3 = Vector3.ZERO, pos: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> void:
	_targets[bone] = {"rot": rot, "pos": pos, "scl": scl}


## Eases one bone (or every bone, bone = "") back to neutral.
func clear(bone: String = "") -> void:
	if bone == "":
		for b: Variant in _targets.keys():
			_targets[b] = {"rot": Vector3.ZERO, "pos": Vector3.ZERO, "scl": Vector3.ONE}
	elif _targets.has(bone):
		_targets[bone] = {"rot": Vector3.ZERO, "pos": Vector3.ZERO, "scl": Vector3.ONE}


## Snaps the current offsets onto the targets (no easing).
func snap() -> void:
	for b: Variant in _targets.keys():
		_current[b] = (_targets[b] as Dictionary).duplicate()


func target_of(bone: String) -> Dictionary:
	return _targets.get(bone, {})


func current_of(bone: String) -> Dictionary:
	return _current.get(bone, {})


func _process_modification_with_delta(delta: float) -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null:
		return
	if hold:
		if _held.is_empty():
			for i: int in sk.get_bone_count():
				_held[i] = [sk.get_bone_pose_position(i), sk.get_bone_pose_rotation(i), sk.get_bone_pose_scale(i)]
		for i: Variant in _held.keys():
			var h: Array = _held[i]
			sk.set_bone_pose_position(int(i), h[0])
			sk.set_bone_pose_rotation(int(i), h[1])
			sk.set_bone_pose_scale(int(i), h[2])
		return
	_held.clear()
	var k: float = clampf(delta * rate, 0.0, 1.0)
	for b: Variant in _targets.keys():
		var t: Dictionary = _targets[b]
		var c: Dictionary = _current.get(b, {"rot": Vector3.ZERO, "pos": Vector3.ZERO, "scl": Vector3.ONE})
		c["rot"] = (c["rot"] as Vector3).lerp(t["rot"], k)
		c["pos"] = (c["pos"] as Vector3).lerp(t["pos"], k)
		c["scl"] = (c["scl"] as Vector3).lerp(t["scl"], k)
		_current[b] = c
		if not _idx.has(b):
			_idx[b] = sk.find_bone(str(b))
		var i: int = int(_idx[b])
		if i < 0:
			continue
		var r: Vector3 = c["rot"]
		if r.length_squared() > 1e-8:
			sk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i) * Quaternion.from_euler(r))
		var p: Vector3 = c["pos"]
		if p.length_squared() > 1e-8:
			sk.set_bone_pose_position(i, sk.get_bone_pose_position(i) + p)
		var s: Vector3 = c["scl"]
		if (s - Vector3.ONE).length_squared() > 1e-8:
			sk.set_bone_pose_scale(i, sk.get_bone_pose_scale(i) * s)
