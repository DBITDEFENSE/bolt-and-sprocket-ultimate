class_name DecorHit
extends RefCounted
## Reactive set dressing (Update 02 section 8, T-053): the protocol between a bullet and the props that react to
## it (a bottle that shatters, a lantern that swings, a curtain that flutters). Such props carry small Area3D hit
## volumes on physics layer 10 "decor": nothing moves on that layer (players, zombies and the navmesh never see
## it), only WeaponHolder's shot ray does. The ray calls hit() and carries on through the prop without spending a
## penetration, so dressing never shields a zombie. The reaction runs on the shooter's peer only: it is local
## presentation, like the impact dust (co-op peers each see their own shots break things).
##
## A hit volume, or its parent, implements `on_decor_shot(collider: Area3D, at: Vector3, dir: Vector3)`; or the volume
## carries the meta "decor_kind" (a DecorTarget kind: "lamp", "hay", "cloth") and DecorTarget.react() handles it.
## (Map generators run in --script mode, where autoload names don't compile, so this file and Props never name
## DecorTarget, which does: it is loaded by path.)

const LAYER: int = 1 << 9
## The most decor volumes one shot passes through before the rest count as penetrations again.
const MAX_PER_SHOT: int = 4
const TARGET_SCRIPT: String = "res://gravelight/world/reactive/decor_target.gd"


## True for a decor hit volume, and for a world collider tagged with the meta "shot_through" (a box that only
## stands in for open dressing, like the bar's back shelving: shots go between the boards to the bottles).
static func is_decor(col: Object) -> bool:
	var co: CollisionObject3D = col as CollisionObject3D
	return co != null and ((co.collision_layer & LAYER) != 0 or co.has_meta("shot_through"))


## Sends the shot to whoever handles the volume. Returns true if someone did.
static func hit(col: Object, at: Vector3, dir: Vector3) -> bool:
	var n: Node = col as Node
	if n == null or n.has_meta("shot_through"):
		return false
	for k: Node in [n, n.get_parent()]:
		if k != null and k.has_method("on_decor_shot"):
			k.call("on_decor_shot", n, at, dir)
			return true
	if n.has_meta("decor_kind"):
		var t: Script = load(TARGET_SCRIPT) as Script
		if t != null:
			t.call("react", n, StringName(str(n.get_meta("decor_kind"))), at, dir, float(n.get_meta("decor_strength", 1.0)))
			return true
	return false


## A plain hit volume (no script) whose reaction is a DecorTarget kind (see the header).
static func make_target(parent: Node3D, pos: Vector3, r: float, kind: StringName, strength: float = 1.0) -> Area3D:
	var a: Area3D = make_area(parent, pos, r)
	a.set_meta("decor_kind", String(kind))
	if strength != 1.0:
		a.set_meta("decor_strength", strength)
	return a


## A hit volume under `parent` at local `pos` (a sphere of radius r, or a box when `box` is non-zero).
static func make_area(parent: Node3D, pos: Vector3, r: float, box: Vector3 = Vector3.ZERO) -> Area3D:
	var a: Area3D = Area3D.new()
	a.name = "DecorHit"
	a.collision_layer = LAYER
	a.collision_mask = 0
	a.monitoring = false
	a.position = pos
	var cs: CollisionShape3D = CollisionShape3D.new()
	if box != Vector3.ZERO:
		var b: BoxShape3D = BoxShape3D.new()
		b.size = box
		cs.shape = b
	else:
		var s: SphereShape3D = SphereShape3D.new()
		s.radius = r
		cs.shape = s
	a.add_child(cs)
	parent.add_child(a)
	return a
