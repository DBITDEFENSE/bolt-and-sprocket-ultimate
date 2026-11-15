class_name PerkLayout
extends Node
## T-251 (UPDATE 19; the owner: "spread perks randomly around the map"): deals a map's tonic machines onto its perk
## spots at match start. MapRoot attaches it (a map without PerkSpot nodes gets none). The deal is PerkShuffle's:
## pure, from one seed, so every peer builds the same layout from the match seed it already shares
## (QuestManager.match_seed; a rejoining client is sent the same seed again). The host is the authority all the same:
## its seed rides in the state snapshot (NetMatch "pl") and a re-deal (`perks shuffle`) is mirrored, so a client that
## started from another seed (a pinned one on the host) is put right as soon as it hears the host.
##
## A machine is moved as a whole node (its body, its interact area, its plaque, its hum are children), a spot left
## without one shows its filler crate (PerkSpot), and the map's POIs are re-read (MapState.refresh_live_pois), so the
## minimap, the pause map, the intel ping and the loadout tab show where the machines stand this match. Bots and
## companions find machines through the "perk_machines" group and their live positions.
##
## Fixed seed: perk_layout.json "fixed_seed"; --perk-seed=<n> on the command line; PerkLayout.forced_seed (tests, the
## dev console's `perks seed <n>`: the next match). Dev console: perks list | shuffle [seed] | seed <n>.

signal applied(seed_value: int)

## The next match's deal seed (consumed by it); -1: none.
static var forced_seed: int = -1

var seed_value: int = -1
var deal: Dictionary = {}          # perk id (String) -> spot id (String)
var _spots: Dictionary = {}        # spot id -> PerkSpot
var _machines: Dictionary = {}     # perk id -> PerkMachine
var _map: Node = null


static func rules() -> Dictionary:
	return GLData.load_json(PerkShuffle.RULES_PATH)


## The layout of the running map (null: this map deals nothing).
static func current(tree: SceneTree) -> PerkLayout:
	return tree.get_first_node_in_group(&"perk_layout") as PerkLayout if tree != null else null


## Called by MapRoot once the match has its seed (after GLBus.match_started).
static func attach(map: Node) -> PerkLayout:
	if map == null or map.get_tree().get_nodes_in_group(&"perk_spots").is_empty():
		return null
	var pl: PerkLayout = PerkLayout.new()
	pl.name = "PerkLayout"
	pl._map = map
	map.add_child(pl)
	pl.begin()
	return pl


func _ready() -> void:
	add_to_group(&"perk_layout")


## The seed this match deals from: a pinned one (host / solo only), else the match seed every peer shares.
static func pick_seed() -> int:
	if Net.is_client():
		return QuestManager.match_seed
	if forced_seed >= 0:
		var f: int = forced_seed
		forced_seed = -1
		return f
	for a: String in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--perk-seed="):
			return maxi(0, int(a.get_slice("=", 1)))
	var fixed: Variant = rules().get("fixed_seed", null)
	if fixed != null and (fixed is float or fixed is int):
		return maxi(0, int(fixed))
	return QuestManager.match_seed


func begin() -> void:
	_collect()
	apply(pick_seed())


func _collect() -> void:
	_spots.clear()
	_machines.clear()
	for n: Node in get_tree().get_nodes_in_group(&"perk_spots"):
		var s: PerkSpot = n as PerkSpot
		if s != null and (_map == null or _map.is_ancestor_of(s)):
			_spots[String(s.spot_id)] = s
	var key: String = str(_map.get("map_id")).get_slice("_", 0) if _map != null else ""
	var ids: Array = ((rules().get("maps", {}) as Dictionary).get(key, {}) as Dictionary).get("perks", [])
	for n2: Node in get_tree().get_nodes_in_group(&"perk_machines"):
		var m: PerkMachine = n2 as PerkMachine
		if m != null and ids.has(String(m.perk_id)) and (_map == null or _map.is_ancestor_of(m)):
			_machines[String(m.perk_id)] = m


func spot_rows() -> Array:
	var out: Array = []
	for id: String in _spots.keys():
		out.append((_spots[id] as PerkSpot).row())
	return out


func perk_rows() -> Array:
	var out: Array = []
	var table: Dictionary = GLData.table("perks")["perks"]
	for id: String in _machines.keys():
		var d: Dictionary = table.get(id, {})
		out.append({"id": id, "cost": int(d.get("cost", 0)), "shape": str(d.get("shape", "cabinet"))})
	return out


## Deal from `seed_now` and stand every machine on its spot. Safe to call again (a re-deal moves them).
func apply(seed_now: int) -> void:
	if _spots.is_empty():
		_collect()
	seed_value = seed_now
	deal = PerkShuffle.assign(seed_now, spot_rows(), perk_rows(), rules())
	for sid: String in _spots.keys():
		(_spots[sid] as PerkSpot).set_machine(null)
	for pid: String in deal.keys():
		var m: PerkMachine = _machines.get(pid) as PerkMachine
		var s: PerkSpot = _spots.get(str(deal[pid])) as PerkSpot
		if m == null or s == null or not is_instance_valid(m):
			continue
		m.global_transform = s.stand_transform(m.depth())   # (T-255: a flush spot stands it back on its wall)
		m.set_panel_side(s.flush)
		m.reset_physics_interpolation()
		s.set_machine(m)
	var ms: MapState = MapState.current()
	if ms != null:
		ms.refresh_live_pois(["perk"])
	for sq: Node in get_tree().get_nodes_in_group(&"bot_squad"):   # where a bot stands to use a machine is cached for a few seconds
		for b: Variant in (sq.get("brains") as Array):
			if b is Object and (b as Object).has_method("invalidate_stand_cache"):
				(b as Object).call("invalidate_stand_cache")
	print("[PerkLayout] seed %d: %s" % [seed_value, describe()])
	applied.emit(seed_value)


## Host / solo: a new deal now (the dev console), mirrored to every client.
func reshuffle(seed_now: int) -> void:
	if not Net.is_authority():
		return
	apply(seed_now)
	Net.mirror(self, &"_net_apply", [seed_now])


## Client: the host dealt again, or its snapshot names another seed than ours.
func _net_apply(seed_now: int) -> void:
	if seed_now != seed_value:
		apply(seed_now)


## The spot a tonic stands on this match ("" when it is not on the map).
func spot_of(perk_id: StringName) -> String:
	return str(deal.get(String(perk_id), ""))


## "second_wind@guest_hall (UPSTAIRS), ..." in perk-id order.
func describe() -> String:
	var parts: PackedStringArray = []
	var ids: Array = deal.keys()
	ids.sort()
	for pid: String in ids:
		var s: PerkSpot = _spots.get(str(deal[pid])) as PerkSpot
		parts.append("%s@%s (%s)" % [pid, str(deal[pid]), String(s.zone_id) if s != null else "?"])
	return ", ".join(parts)


# ================================================================== tools (tests, smokes, captures)

## The spot rows of a map scene read from its packed state, without loading it: [{id, zone, outdoor, start, near}].
static func scene_spot_rows(scene_path: String) -> Array:
	var out: Array = []
	var ps: PackedScene = load(scene_path) as PackedScene
	if ps == null:
		return out
	var st: SceneState = ps.get_state()
	for i: int in st.get_node_count():
		var props: Dictionary = {}
		for j: int in st.get_node_property_count(i):
			props[String(st.get_node_property_name(i, j))] = st.get_node_property_value(i, j)
		if props.has("spot_id"):
			out.append({"id": str(props["spot_id"]), "zone": str(props.get("zone_id", "")), "outdoor": bool(props.get("outdoor", false)),
				"start": bool(props.get("start", false)), "near": bool(props.get("near", false))})
	return out


## The perk rows of a map key ("map00") from perk_layout.json and perks.json: [{id, cost, shape}].
static func map_perk_rows(map_key: String) -> Array:
	var out: Array = []
	var table: Dictionary = GLData.table("perks")["perks"]
	for id: String in ((rules().get("maps", {}) as Dictionary).get(map_key, {}) as Dictionary).get("perks", []):
		var d: Dictionary = table.get(id, {})
		out.append({"id": id, "cost": int(d.get("cost", 0)), "shape": str(d.get("shape", "cabinet"))})
	return out


## The first seed from `from` whose deal on `scene_path` suits `want` (a smoke that needs a machine where its story
## has it pins that seed: PerkLayout.forced_seed = PerkLayout.seed_where(...)). `want` gets {perk id -> zone id} and
## {perk id -> spot id}. -1 when none of `tries` seeds does.
static func seed_where(scene_path: String, want: Callable, from: int = 0, tries: int = 3000) -> int:
	var spots: Array = scene_spot_rows(scene_path)
	var zone_of: Dictionary = {}
	for s: Dictionary in spots:
		zone_of[s["id"]] = s["zone"]
	var perks: Array = map_perk_rows(scene_path.get_file().get_basename().get_slice("_", 0))
	var r: Dictionary = rules()
	for seed_now: int in range(from, from + tries):
		var d: Dictionary = PerkShuffle.assign(seed_now, spots, perks, r)
		var zones: Dictionary = {}
		for pid: String in d.keys():
			zones[pid] = str(zone_of.get(str(d[pid]), ""))
		if bool(want.call(zones, d)):
			return seed_now
	return -1


## Every zone that holds a machine this match (a smoke opens the doors to them).
func machine_zones() -> Array:
	var out: Array = []
	for pid: String in deal.keys():
		var s: PerkSpot = _spots.get(str(deal[pid])) as PerkSpot
		if s != null and not out.has(String(s.zone_id)):
			out.append(String(s.zone_id))
	return out
