extends Node
## Exports the shared ZombieRig skeleton (gravelight/enemies/zombie_rig.gd, data/gravelight/anim.json "skeleton")
## to JSON so the Blender character scripts (tools_src/blender/characters/make_body.py, make_kits.py) build their
## armature on exactly our bones: same names, same parents, same rest positions (model space, metres, Godot's
## frame: +Y up, the face toward -Z, left side at -X). Rest rotations are identity, so "rest_global" is a plain
## position per bone and a child bone's head is the parent's head plus its offset (T-091).
##
##   godot --headless --audio-driver Dummy --path . res://tools/export_rig.tscn [-- out=<path>]
## (a scene, not --script: the rig and body read GLData, an autoload a --script run does not have)
##
## Default output: tools_src/blender/characters/rig.json (committed; regenerate when anim.json's skeleton changes).

const DEFAULT_OUT: String = "res://tools_src/blender/characters/rig.json"


func _ready() -> void:
	var out: String = DEFAULT_OUT
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	var data: Dictionary = export_dict()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out).get_base_dir())
	var f: FileAccess = FileAccess.open(out, FileAccess.WRITE)
	if f == null:
		push_error("export_rig: cannot write " + out)
		get_tree().quit(1)
		return
	f.store_string(JSON.stringify(data, "  ") + "\n")
	f.close()
	print("[export_rig] %d bones -> %s" % [(data["bones"] as Array).size(), ProjectSettings.globalize_path(out)])
	get_tree().quit(0)


## The rig as plain data: bones in skeleton order with parent, local offset, rest head (model space) and the
## limb / hitbox tables the body script fits its geometry to.
static func export_dict() -> Dictionary:
	var bones: Array = []
	for name: String in ZombieRig.bone_names():
		var parent: String = ZombieRig.parent_of(name)
		var off: Vector3 = ZombieRig.rest_offset(name)
		var head: Vector3 = ZombieRig.rest_global(name).origin
		var children: PackedStringArray = ZombieRig.children_of(name)
		bones.append({
			"name": name,
			"parent": parent,
			"offset": [off.x, off.y, off.z],
			"head": [head.x, head.y, head.z],
			"children": Array(children),
			"index": ZombieRig.bone_index(name),
		})
	var hitboxes: Array = []
	for h: Array in ZombieBody.HITBOXES:
		var bone: String = ZombieRig.legacy_name(str(h[0]))
		var size: Vector3 = h[2]
		var pos: Vector3 = h[3]
		var centre: Vector3 = ZombieRig.rest_global(bone).origin + pos
		hitboxes.append({"name": str(h[0]), "bone": bone, "limb": String(h[1]), "size": [size.x, size.y, size.z],
			"offset": [pos.x, pos.y, pos.z], "centre": [centre.x, centre.y, centre.z]})
	var builds: Dictionary = GLData.table("anim")["builds"]
	return {
		"_doc": "ZombieRig export (tools/export_rig.gd, T-091). Godot frame: +Y up, face -Z, left -X, metres. Rest rotations identity.",
		"frame": {"up": "+Y", "forward": "-Z", "left": "-X", "units": "m"},
		"joint_blend_m": float(GLData.table("anim")["skeleton"].get("joint_blend_m", 0.05)),
		"bones": bones,
		"limb_bones": Array(ZombieBody.LIMB_BONES),
		"hitboxes": hitboxes,
		"builds": {"thin": builds["thin"], "medium": builds["medium"], "heavy": builds["heavy"], "female": builds["female"], "heights": builds["heights"]},
	}
