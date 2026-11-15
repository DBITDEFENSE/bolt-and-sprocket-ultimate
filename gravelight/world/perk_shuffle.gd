class_name PerkShuffle
extends RefCounted
## T-251 (UPDATE 19; the owner: "spread perks randomly around the map"): which tonic machine stands on which perk
## spot this match. Pure and seeded: the same seed, spots, perks and rules give the same deal on every peer and in
## the map generator (gen_map00 saves the scene with the seed-0 deal), so nothing but the seed ever travels.
## No autoloads in here: a --script run (the generator) loads this file before they exist.
##
## spots: [{id, zone, outdoor, start, near}]   perks: [{id, cost, shape}]   rules: data/gravelight/perk_layout.json
## The rules (all optional):
##   max_per_zone      at most this many machines in one zone (the rest of its spots show their filler)
##   outdoor_shapes    the cabinet shapes that may stand under the snow; an outdoor spot takes no other
##   start_max_cost    a spot in the start room takes only tonics up to this price
##   not_in_start      tonics that never stand in the start room (Second Wind pours without the power solo)
##   near_start        tonics that only stand on a spot one bought door from the start (so a solo player gets to it)

const RULES_PATH: String = "res://data/gravelight/perk_layout.json"


## The seeded generator of a deal. Its own mix of the seed, so the deal shares no draws with the quests' rolls.
static func rng_for(seed_value: int) -> RandomNumberGenerator:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = (int(seed_value) & 0xFFFFFFFF) * 40503 + 0x51EDC0DE   # (under 2^48: no overflow)
	return r


## May `perk` stand on `spot` under `rules`?
static func allowed(perk: Dictionary, spot: Dictionary, rules: Dictionary) -> bool:
	var id: String = str(perk.get("id", ""))
	if bool(spot.get("outdoor", false)) and rules.has("outdoor_shapes") and not (rules["outdoor_shapes"] as Array).has(str(perk.get("shape", ""))):
		return false
	if bool(spot.get("start", false)):
		if int(perk.get("cost", 0)) > int(rules.get("start_max_cost", 1 << 30)):
			return false
		if (rules.get("not_in_start", []) as Array).has(id):
			return false
	if (rules.get("near_start", []) as Array).has(id) and not bool(spot.get("near", false)):
		return false
	return true


static func _shuffled(a: Array, rng: RandomNumberGenerator) -> Array:
	var out: Array = a.duplicate()
	for i: int in range(out.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: Variant = out[i]
		out[i] = out[j]
		out[j] = t
	return out


## The deal: {perk id -> spot id}. Every perk gets a spot when the rules can be met at all (the most restricted
## tonics are placed first, each on a random spot it may take, backing up when a later one is left without); when
## they cannot, max_per_zone is dropped, and then the other rules, rather than leave a machine out of the map.
static func assign(seed_value: int, spots: Array, perks: Array, rules: Dictionary) -> Dictionary:
	var sp: Array = spots.duplicate()
	sp.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["id"]) < str(b["id"]))
	var pk: Array = perks.duplicate()
	pk.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["id"]) < str(b["id"]))
	for relax: int in 3:
		var rng: RandomNumberGenerator = rng_for(seed_value)
		var order: Array = _shuffled(pk, rng)
		var cands: Dictionary = {}
		for p: Dictionary in order:
			var c: Array = []
			for s: Dictionary in _shuffled(sp, rng):
				if relax >= 2 or allowed(p, s, rules):
					c.append(s)
			cands[str(p["id"])] = c
		# the fewest places first; the shuffle's order breaks the ties (a stable insertion sort: sort_custom is not)
		var sorted: Array = []
		for p2: Dictionary in order:
			var at: int = sorted.size()
			for i: int in sorted.size():
				if (cands[str(p2["id"])] as Array).size() < (cands[str((sorted[i] as Dictionary)["id"])] as Array).size():
					at = i
					break
			sorted.insert(at, p2)
		var cap: int = int(rules.get("max_per_zone", 1 << 30)) if relax == 0 else (1 << 30)
		var out: Dictionary = {}
		if _place(0, sorted, cands, cap, {}, {}, out):
			return out
	return {}


static func _place(i: int, order: Array, cands: Dictionary, cap: int, used: Dictionary, zone_n: Dictionary, out: Dictionary) -> bool:
	if i >= order.size():
		return true
	var pid: String = str((order[i] as Dictionary)["id"])
	for s: Dictionary in cands[pid]:
		var sid: String = str(s["id"])
		var zone: String = str(s.get("zone", ""))
		if used.has(sid) or int(zone_n.get(zone, 0)) >= cap:
			continue
		used[sid] = true
		zone_n[zone] = int(zone_n.get(zone, 0)) + 1
		out[pid] = sid
		if _place(i + 1, order, cands, cap, used, zone_n, out):
			return true
		used.erase(sid)
		zone_n[zone] = int(zone_n[zone]) - 1
		out.erase(pid)
	return false


## Does `deal` keep every rule? (tests, and the layout's own check before it moves anything)
static func valid(deal: Dictionary, spots: Array, perks: Array, rules: Dictionary) -> bool:
	var by_id: Dictionary = {}
	for s: Dictionary in spots:
		by_id[str(s["id"])] = s
	var used: Dictionary = {}
	var zone_n: Dictionary = {}
	for p: Dictionary in perks:
		var sid: String = str(deal.get(str(p["id"]), ""))
		if not by_id.has(sid) or used.has(sid) or not allowed(p, by_id[sid], rules):
			return false
		used[sid] = true
		var z: String = str((by_id[sid] as Dictionary).get("zone", ""))
		zone_n[z] = int(zone_n.get(z, 0)) + 1
		if int(zone_n[z]) > int(rules.get("max_per_zone", 1 << 30)):
			return false
	return true
