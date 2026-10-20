class_name Combat
extends RefCounted
## Shared damage contract for every mode.
##
## A damageable thing (enemy, boss part, crate, prop) is a Node3D that:
##   - is in group "damageable" (enemies also in "enemies"; bosses also in "bosses")
##   - implements  take_damage(hit: Combat.Hit) -> bool   (returns true if this hit killed it)
##   - implements  get_center() -> Vector3                 (aim/assist/hit point)
##   - has         radius: float                           (for melee/slam/AoE reach)
##   - implements  is_alive() -> bool
##   - optionally  has a StatusEffects child named "Status" (core/status_effects.gd)
## Players implement take_damage too (group "player").
##
## Damage types (brief §1): kinetic, energy, fire, frost, shock, legal, void.

enum Type { KINETIC, ENERGY, FIRE, FROST, SHOCK, LEGAL, VOID }


class Hit extends RefCounted:
	var amount: float = 0.0
	var type: int = Combat.Type.KINETIC
	var source: Node = null              # who dealt it (player, enemy, hazard)
	var weapon_id: StringName = &""      # "mallet", "omni_blaster", ...
	var point: Vector3 = Vector3.ZERO
	var dir: Vector3 = Vector3.ZERO      # knockback direction (horizontal)
	var knock: float = 0.0               # knockback speed
	var launch: float = 0.0              # upward launch speed
	var is_melee: bool = false
	var is_slam: bool = false
	var weak_point: bool = false         # hit a weak point (crit)
	var status: Dictionary = {}          # status id -> seconds (e.g. {"served": 6.0})

	static func make(amount_: float, type_: int = Combat.Type.KINETIC, source_: Node = null) -> Combat.Hit:
		var h: Combat.Hit = Combat.Hit.new()
		h.amount = amount_
		h.type = type_
		h.source = source_
		return h


## Living damageables in a sphere (center distance minus their radius), nearest first.
static func in_radius(tree: SceneTree, center: Vector3, r: float, group: StringName = &"enemies") -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n: Node in tree.get_nodes_in_group(group):
		var d: Node3D = n as Node3D
		if d == null or not d.call("is_alive"):
			continue
		if (d.call("get_center") as Vector3).distance_to(center) < r + float(d.get("radius")):
			out.append(d)
	out.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return (a.call("get_center") as Vector3).distance_squared_to(center) < (b.call("get_center") as Vector3).distance_squared_to(center))
	return out
