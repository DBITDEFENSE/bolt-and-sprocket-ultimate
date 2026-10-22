class_name Hitbox
extends Area3D
## One limb hitbox on an enemy. Hitscan rays query areas on the "zombie_hitbox" layer.

const LAYER_HITBOX: int = 1 << 3

var enemy: Node3D
var limb: StringName = &"torso"
## The rig bone this box rides (profile name, e.g. "LeftLowerArm"); weapons hand it to Zombie.last_hit_bone so
## arm / leg hits know their side (dismemberment, directional flinches).
var bone: String = ""


func setup(owner_enemy: Node3D, limb_name: StringName, size: Vector3) -> void:
	enemy = owner_enemy
	limb = limb_name
	collision_layer = LAYER_HITBOX
	collision_mask = 0
	monitoring = false
	monitorable = true
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	cs.shape = box
	add_child(cs)
