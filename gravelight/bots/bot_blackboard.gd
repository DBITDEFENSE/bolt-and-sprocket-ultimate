class_name BotBlackboard
extends RefCounted
## The squad blackboard (Update 03 section 1): what the bots share, on BotSquad as `blackboard`. Pure data with
## a clock passed in (`now`, BotSquad.time()), so it is unit-tested (test_bot_brain.gd).
##   zombies       what a bot (or a teammate) perceived: instance id -> {node, pos, t, by, tier, boss}; entries
##                 older than memory_s are gone (no wallhacks: nothing else is known)
##   claims        tasks one bot does at a time: key -> {pid, kind, target, until}. Keys: "revive:<pid>",
##                 "cover:<pid>", "repair:<instance id>", "hold:<instance id>" (up to `cap` holders), "use:<id>"
##   route         the current training route (a TrainingRoute or null) and route_leader (its leader's pid)
##   danger_zones  [{pos, radius, cost, until, key}]: traps, fire, a Bell Dome's edge, a boss's keep-away ring.
##                 The locomotion layer reads this exact shape
##   powerups      instance id -> {id, pos, t, node}
##   pings         [{pos, kind, text, t, by}] (the callout markers, newest last)
##   roles         pid -> "anchor" / "runner" / "medic" / "builder"
##   ee_known      what the squad has discovered about the easter egg (BotEEKnowledge, Update 04 section 5)

var memory_s: float = 4.0
var zombies: Dictionary = {}
var claims: Dictionary = {}
var route: Variant = null
var route_leader: int = 0
var danger_zones: Array = []
var powerups: Dictionary = {}
var pings: Array = []
var roles: Dictionary = {}
var ee_known: BotEEKnowledge = null


# ---------------------------------------------------------------- zombie memory

## `by` perceived the zombie `node` at `pos` (now). tier / boss ride along for the threat rules.
func sight(node: Object, pos: Vector3, now: float, by: int, tier: StringName = &"", boss: bool = false) -> void:
	if node == null:
		return
	var id: int = node.get_instance_id()
	var e: Dictionary = zombies.get(id, {})
	e["node"] = node
	e["pos"] = pos
	e["t"] = now
	e["by"] = by
	e["tier"] = tier
	e["boss"] = boss
	zombies[id] = e


## Forgets what is older than memory_s, and the dead.
func forget(now: float) -> void:
	for id: Variant in zombies.keys():
		var e: Dictionary = zombies[id]
		var n: Variant = e.get("node")
		if now - float(e["t"]) > memory_s or (typeof(n) == TYPE_OBJECT and not is_instance_valid(n)):
			zombies.erase(id)   # (a freed node, e.g. a Homage boss that left, compares equal to null: test it first)
		elif n is Object and (n as Object).has_method("is_active") and not bool((n as Object).call("is_active")):
			zombies.erase(id)


## The remembered entries still within memory (newest knowledge of each zombie).
func known(now: float) -> Array:
	var out: Array = []
	for e: Variant in zombies.values():
		if now - float((e as Dictionary)["t"]) <= memory_s:
			var n: Variant = (e as Dictionary).get("node")
			if typeof(n) == TYPE_OBJECT and not is_instance_valid(n):
				continue   # freed since it was seen (not pooled: a boss that retreated): never handed out
			out.append(e)
	return out


func knows(node: Object, now: float) -> bool:
	if node == null:
		return false
	var e: Dictionary = zombies.get(node.get_instance_id(), {})
	return not e.is_empty() and now - float(e["t"]) <= memory_s


# ---------------------------------------------------------------- claims

## Claims `key` for `pid` until `until` (INF = until released). `cap` holders may share a key (window pairs);
## a single-holder key (cap 1) fails while someone else holds it. True when `pid` holds it after the call.
func claim(key: String, pid: int, kind: String, now: float, until: float = INF, target: Variant = null, cap: int = 1) -> bool:
	_expire(key, now)
	var c: Dictionary = claims.get(key, {})
	if c.is_empty():
		claims[key] = {"pid": pid, "pids": [pid], "kind": kind, "target": target, "until": until, "cap": cap}
		return true
	var pids: Array = c["pids"]
	if pids.has(pid):
		c["until"] = until
		return true
	if pids.size() >= int(c.get("cap", 1)):
		return false
	pids.append(pid)
	return true


## May `pid` claim `key` right now?
func can_claim(key: String, pid: int, now: float) -> bool:
	_expire(key, now)
	var c: Dictionary = claims.get(key, {})
	return c.is_empty() or (c["pids"] as Array).has(pid) or (c["pids"] as Array).size() < int(c.get("cap", 1))


## The first holder of `key` (0 = free).
func claimer(key: String, now: float) -> int:
	_expire(key, now)
	var c: Dictionary = claims.get(key, {})
	return 0 if c.is_empty() else int((c["pids"] as Array)[0]) if not (c["pids"] as Array).is_empty() else 0


func holders(key: String, now: float) -> Array:
	_expire(key, now)
	return (claims.get(key, {}) as Dictionary).get("pids", [])


func holds(key: String, pid: int, now: float) -> bool:
	return holders(key, now).has(pid)


func release(key: String, pid: int) -> void:
	var c: Dictionary = claims.get(key, {})
	if c.is_empty():
		return
	(c["pids"] as Array).erase(pid)
	if (c["pids"] as Array).is_empty():
		claims.erase(key)
	else:
		c["pid"] = int((c["pids"] as Array)[0])


## Everything `pid` holds goes (it went down, bled out, left).
func release_all(pid: int) -> void:
	for k: Variant in claims.keys():
		release(str(k), pid)


## The keys `pid` holds whose key starts with `prefix` ("revive:", "cover:").
func held_by(pid: int, prefix: String = "") -> Array[String]:
	var out: Array[String] = []
	for k: Variant in claims.keys():
		if (prefix == "" or str(k).begins_with(prefix)) and ((claims[k] as Dictionary)["pids"] as Array).has(pid):
			out.append(str(k))
	return out


func _expire(key: String, now: float) -> void:
	var c: Dictionary = claims.get(key, {})
	if not c.is_empty() and now > float(c.get("until", INF)):
		claims.erase(key)


## Clears the per-round task claims (repairs, holds, uses) but keeps revives and covers.
func clear_round_claims() -> void:
	for k: Variant in claims.keys():
		var s: String = str(k)
		if not (s.begins_with("revive:") or s.begins_with("cover:")):
			claims.erase(k)


# ---------------------------------------------------------------- danger zones

## Adds (or refreshes, by `key`) a danger zone: {pos, radius, cost, until, key}.
func add_danger(pos: Vector3, radius: float, cost: float, until: float, key: String = "") -> void:
	if key != "":
		for z: Variant in danger_zones:
			if str((z as Dictionary).get("key", "")) == key:
				(z as Dictionary)["pos"] = pos
				(z as Dictionary)["radius"] = radius
				(z as Dictionary)["cost"] = cost
				(z as Dictionary)["until"] = until
				return
	danger_zones.append({"pos": pos, "radius": radius, "cost": cost, "until": until, "key": key})


func prune_danger(now: float) -> void:
	var keep: Array = []
	for z: Variant in danger_zones:
		if float((z as Dictionary)["until"]) >= now:
			keep.append(z)
	danger_zones = keep


## The cost of standing at `p` (the sum of the zones it is in; 0 outside them all).
func danger_at(p: Vector3, now: float) -> float:
	var c: float = 0.0
	for z: Variant in danger_zones:
		var d: Dictionary = z
		if float(d["until"]) < now:
			continue
		var zp: Vector3 = d["pos"]
		if Vector2(p.x - zp.x, p.z - zp.z).length() <= float(d["radius"]) and absf(p.y - zp.y) < 2.5:
			c += float(d["cost"])
	return c


# ---------------------------------------------------------------- power-ups and pings

func add_powerup(node: Object, id: StringName, pos: Vector3, now: float) -> void:
	var key: int = node.get_instance_id() if node != null else hash([id, pos])
	powerups[key] = {"id": id, "pos": pos, "t": now, "node": node}


func remove_powerup_at(id: StringName, pos: Vector3) -> void:
	for k: Variant in powerups.keys():
		var e: Dictionary = powerups[k]
		if StringName(e["id"]) == id and (pos == Vector3.INF or (e["pos"] as Vector3).distance_to(pos) < 2.0):
			powerups.erase(k)
			return


func prune_powerups() -> void:
	for k: Variant in powerups.keys():
		var n: Variant = (powerups[k] as Dictionary).get("node")
		if n != null and not is_instance_valid(n):
			powerups.erase(k)


func ping(pos: Vector3, kind: String, text: String, now: float, by: int) -> void:
	pings.append({"pos": pos, "kind": kind, "text": text, "t": now, "by": by})
	while pings.size() > 24:
		pings.pop_front()


## Text lines for the debug overlay's blackboard panel.
func describe(now: float) -> PackedStringArray:
	var out: PackedStringArray = []
	for k: Variant in claims.keys():
		var c: Dictionary = claims[k]
		var left: String = "" if float(c.get("until", INF)) == INF else " (%.0fs)" % maxf(0.0, float(c["until"]) - now)
		out.append("%s <- %s%s" % [str(k), ", ".join(PackedStringArray((c["pids"] as Array).map(func(p: Variant) -> String: return "P%d" % int(p)))), left])
	out.append("known zombies %d, danger zones %d, power-ups %d, route %s (leader P%d)" % [zombies.size(), danger_zones.size(), powerups.size(),
		"free loop" if route == null else str(route.get("id") if route is Object else route), route_leader])
	for pid: Variant in roles.keys():
		out.append("P%d %s" % [int(pid), str(roles[pid])])
	return out
