class_name ExtraPeople
extends RefCounted
## T-143: the table of the extra people (data/gravelight/people_extra.json) and the pure rules around it. The people
## themselves are ExtraPerson nodes (attach() makes the ones for a map); the Talk card is PersonCard.

const PATH: String = "res://data/gravelight/people_extra.json"
static var _cfg: Dictionary = {}


static func cfg() -> Dictionary:
	if _cfg.is_empty():
		_cfg = GLData.load_json(PATH)
	return _cfg


static func people() -> Dictionary:
	return cfg().get("people", {})


## The person ids that appear on a map (pure over the table): `map_id` begins with one of their `maps`.
static func ids_for_map(map_id: String, tbl: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var all: Dictionary = tbl.get("people", {})
	for pid: Variant in all.keys():
		for m: Variant in (all[pid] as Dictionary).get("maps", []):
			if map_id.begins_with(str(m)):
				out.append(str(pid))
				break
	return out


## Every spot a person or their item stands on, on a map: the checked points (NpcWallProbe, test_people_extra).
static func spots_for(map_id: String) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for pid: String in ids_for_map(map_id, cfg()):
		var row: Dictionary = people()[pid]
		for b: Variant in row.get("bodies", []):
			# U10 §3: a body that never walks (behind a counter, behind glass) is checked at its talk spot instead
			if not bool((b as Dictionary).get("fixed", false)):
				out.append(vec(b.get("at", [0, 0, 0])))
		if row.has("talk_at"):
			out.append(vec(row["talk_at"]))
		var fav: Dictionary = row.get("favour", {})
		if fav.has("item_at"):
			out.append(vec(fav["item_at"]))
	return out


static func vec(a: Variant) -> Vector3:
	var arr: Array = a as Array
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2])) if arr != null and arr.size() >= 3 else Vector3.ZERO


## The favour's next state after an event (pure): "accept" while NONE -> ASKED, "item" while ASKED -> HAVE,
## "give" while HAVE -> DONE. Anything else leaves it. States: 0 none, 1 asked, 2 have, 3 done.
static func favour_next(state: int, event: String) -> int:
	match [state, event]:
		[0, "accept"]:
			return 1
		[1, "item"]:
			return 2
		[2, "give"]:
			return 3
	return state


## A timed reward's rounds left after a round starts (pure): it was granted `in_round` (the rest of that round
## counts as the first) or in a break (the next round is the first).
static func rounds_after_grant(n: int, in_round: bool) -> int:
	return n if in_round else n + 1


static func rounds_after_start(left: int) -> int:
	return maxi(0, left - 1)


## The trade is open when it has not been used this round (pure).
static func trade_open(last_round: int, round_now: int, once_per_round: bool) -> bool:
	return not once_per_round or last_round != round_now


## A random ammo refill or a grenade pack (the quartermaster): `roll` 0..1, outcomes from the table.
static func trade_outcome(roll: float, outcomes: Array) -> String:
	if outcomes.is_empty():
		return ""
	return str(outcomes[clampi(int(roll * float(outcomes.size())), 0, outcomes.size() - 1)])


static func attach(m: MapRoot) -> void:
	if Net.is_online() or m == null:
		return
	for pid: String in ids_for_map(String(m.map_id), cfg()):
		var p: ExtraPerson = ExtraPerson.new()
		p.name = "Person_" + pid
		m.add_child(p)
		p.setup(m, pid)
