class_name ChainWeapon
extends BSWeapon
## Arc weapons (fireZap 4783): pick a first target close and roughly in front, then hop to the nearest unhit
## enemy within hop range, damage falling down the chain. Fizzles with no ammo cost if nothing is in range.
## Params: first_range, first_close, first_min_dot, hop_range, targets, chain_dmg[].


func _fire() -> void:
	cooldown = interval()
	if not has_ammo(1):
		empty_feedback()
		return
	var targets: Array[Node3D] = find_chain(arc_origin(), aim(), target_count(), P("first_range", 11.0), P("hop_range", 6.5))
	if targets.is_empty():
		fizzle()
		return
	use_ammo(1)
	zap(targets, 1.0)
	recoil(float(d.get("recoil", 0.006)))
	fired.emit(id)
	mgr.weapon_fired.emit(id)


func fizzle() -> void:
	WeaponFX.flash(mgr.world(), arc_origin(), WeaponData.color(id), 0.1)


## Where arcs start from (Sprocket for the Zap).
func arc_origin() -> Vector3:
	return mgr.muzzle_pos()


func target_count() -> int:
	return int(P("targets", 3))


func hop_reach(_e: Node3D, base: float) -> float:
	return base


func first_target(from: Vector3, dir: Vector3, rng_m: float) -> Node3D:
	var best: Node3D = null
	var bs: float = -INF
	var body: Vector3 = mgr.bolt.global_position
	for n: Node in get_tree().get_nodes_in_group(&"enemies"):
		var e: Node3D = n as Node3D
		if e == null or not bool(e.call("is_alive")):
			continue
		var c: Vector3 = e.call("get_center")
		var to: Vector3 = c - body
		var dd: float = to.length()
		if dd > rng_m:
			continue
		var a: float = to.normalized().dot(dir) if dd > 0.01 else 1.0
		if a < P("first_min_dot", 0.35) and dd > P("first_close", 4.5):
			continue
		var score: float = a * 2.0 - dd * 0.08
		if score <= bs:
			continue
		if not mgr.ray_world(from, c).is_empty():
			continue
		bs = score
		best = e
	return best


func find_chain(from: Vector3, dir: Vector3, count: int, first_range: float, hop: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var first: Node3D = first_target(from, dir, first_range)
	if first == null:
		return out
	out.append(first)
	var cur: Node3D = first
	while out.size() < count:
		var nxt: Node3D = null
		var nd: float = INF
		for n: Node in get_tree().get_nodes_in_group(&"enemies"):
			var e: Node3D = n as Node3D
			if e == null or out.has(e) or not bool(e.call("is_alive")):
				continue
			var dd: float = e.global_position.distance_to(cur.global_position)
			if dd < hop_reach(e, hop) and dd < nd:
				nd = dd
				nxt = e
		if nxt == null:
			break
		out.append(nxt)
		cur = nxt
	return out


func chain_damage(i: int) -> float:
	var arr: Array = p.get("chain_dmg", [float(d.get("damage", 10))])
	return float(arr[mini(i, arr.size() - 1)])


## Damages the chain in order, drawing the arcs.
func zap(targets: Array[Node3D], mul: float) -> void:
	var from: Vector3 = arc_origin()
	for i: int in targets.size():
		var e: Node3D = targets[i]
		var c: Vector3 = e.call("get_center")
		for s: int in strands():
			WeaponFX.lightning(mgr.world(), from, c, WeaponData.color(id), mgr.rng)
		on_arc_hit(e, i, roundf(dmg(chain_damage(i)) * mul), c)
		from = c


func strands() -> int:
	return int(P("strands", 2))


func on_arc_hit(e: Node3D, _i: int, amount: float, point: Vector3) -> void:
	deal(e, amount, point)
