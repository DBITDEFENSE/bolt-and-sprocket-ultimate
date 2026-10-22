class_name ZombieRig
extends RefCounted
## The shared humanoid zombie skeleton (ZOMBIE_ANIM_SPEC §1, T-041): one Skeleton3D layout for every zombie
## type, bone names from Godot's SkeletonProfileHumanoid with a BoneMap so any humanoid animation source can be
## retargeted onto it. Layout and rest offsets come from data/gravelight/anim.json "skeleton"; rest rotations are
## identity (limbs hang along -Y, the spine stacks along +Y), so poses are plain local rotations and additive
## layers are plain deltas. The old 16-node hand hierarchy is gone; `legacy_name()` maps its names for callers
## (Screamer's throat, kind parts, the wound decals).

static var _bones: Array = []            # [name, parent, Vector3] in order
static var _index: Dictionary = {}       # name -> index
static var _legacy: Dictionary = {}
static var _bone_map: BoneMap = null
static var _rest_global: Dictionary = {} # name -> Transform3D (rest, model space)


static func _load() -> void:
	if not _bones.is_empty():
		return
	var sk: Dictionary = GLData.table("anim")["skeleton"]
	for b: Array in sk["bones"]:
		var off: Array = b[2]
		_bones.append([str(b[0]), str(b[1]), Vector3(float(off[0]), float(off[1]), float(off[2]))])
	for i: int in _bones.size():
		_index[str(_bones[i][0])] = i
	_legacy = (sk["legacy_names"] as Dictionary).duplicate()
	for i: int in _bones.size():
		var name: String = str(_bones[i][0])
		var parent: String = str(_bones[i][1])
		var local: Transform3D = Transform3D(Basis.IDENTITY, _bones[i][2] as Vector3)
		_rest_global[name] = (_rest_global[parent] as Transform3D) * local if parent != "" else local


static func bone_names() -> PackedStringArray:
	_load()
	var out: PackedStringArray = []
	for b: Array in _bones:
		out.append(str(b[0]))
	return out


static func parent_of(bone: String) -> String:
	_load()
	return str(_bones[int(_index[bone])][1])


static func rest_offset(bone: String) -> Vector3:
	_load()
	return _bones[int(_index[bone])][2]


## Rest transform of a bone in model (skeleton) space.
static func rest_global(bone: String) -> Transform3D:
	_load()
	return _rest_global[bone]


static func bone_index(bone: String) -> int:
	_load()
	return int(_index.get(bone, -1))


## Old hand-hierarchy name ("sh_l") -> profile name ("LeftUpperArm"); profile names pass through.
static func legacy_name(n: String) -> String:
	_load()
	return str(_legacy.get(n, n))


## Children of a bone (direct).
static func children_of(bone: String) -> PackedStringArray:
	_load()
	var out: PackedStringArray = []
	for b: Array in _bones:
		if str(b[1]) == bone:
			out.append(str(b[0]))
	return out


## The bone and everything hanging off it.
static func chain_of(bone: String) -> PackedStringArray:
	var out: PackedStringArray = [bone]
	var i: int = 0
	while i < out.size():
		for c: String in children_of(out[i]):
			out.append(c)
		i += 1
	return out


## Builds the Skeleton3D with the profile's bone names and identity rest rotations.
static func build_skeleton() -> Skeleton3D:
	_load()
	var sk: Skeleton3D = Skeleton3D.new()
	sk.name = "Skel"
	for b: Array in _bones:
		var idx: int = sk.add_bone(str(b[0]))
		if str(b[1]) != "":
			sk.set_bone_parent(idx, int(_index[str(b[1])]))
		sk.set_bone_rest(idx, Transform3D(Basis.IDENTITY, b[2] as Vector3))
	sk.reset_bone_poses()
	sk.set_meta("bone_map", bone_map())
	return sk


## The BoneMap against SkeletonProfileHumanoid (profile bone -> our bone; the names match where the profile has
## them). Retargeting an imported humanoid clip is: set this map on the import, bake, drop the Animation in
## ZombieClips.library().
static func bone_map() -> BoneMap:
	if _bone_map != null:
		return _bone_map
	_load()
	var bm: BoneMap = BoneMap.new()
	bm.profile = SkeletonProfileHumanoid.new()
	for i: int in bm.profile.bone_size:
		var pname: StringName = bm.profile.get_bone_name(i)
		if _index.has(String(pname)):
			bm.set_skeleton_bone_name(pname, pname)
	_bone_map = bm
	return bm


## Number of profile bones this rig covers (the test asserts the core humanoid set is mapped).
static func mapped_profile_bones() -> int:
	var bm: BoneMap = bone_map()
	var n: int = 0
	for i: int in bm.profile.bone_size:
		if bm.get_skeleton_bone_name(bm.profile.get_bone_name(i)) != &"":
			n += 1
	return n
