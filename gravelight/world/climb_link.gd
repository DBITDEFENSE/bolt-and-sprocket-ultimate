class_name ClimbLink
extends RefCounted
## Authored climb volumes (ZOMBIE_ANIM_SPEC §3, T-041): NavigationLink3Ds with the "climb" meta that a zombie's
## NavigationAgent3D reaches like any link; Zombie._on_link_reached then plays the Climb state (loop + mantle)
## from the link's start to its end instead of walking it. Data-driven per map: data/gravelight/<mapNN>.json
## "climb_links": [{"zone": "D_PENHALL", "from": [x, y, z], "to": [x, y, z], "name": "..."}]. The link's
## navigation layer is the zone's bit (MapRoot.nav_zone_bits) so closed zones keep their ladders closed.
## T-268 (the owner: "zombies need to be able to crawl up the watchtower ... if you go on the ladder, have the zombies
## be able to chase you"): a row may be a LADDER. `"line": [x, z]` is the ladder's line (where a body hangs on the
## rungs, the LadderClimb's own `line`): the zombie steps onto it, goes straight up it and swings over the edge onto
## `to`, instead of the straight diagonal from `from` to `to`. A ladder is climbed ONE AT A TIME with room between
## (`"space"`, metres between two climbers, default SPACE): the others wait at the foot (try_enter), so a queue goes
## up one after another and never stacks. `"drop": true` with `"bidirectional": true` lets the dead come back down
## it: they swing out over the edge and drop down the line (a fall, a stagger on landing), so nobody is left standing
## on a platform the players have left. Rows without `line` behave as before (every other map's links).

const META: StringName = &"climb"
## T-153: a zone's ladders live on its climb layer (the zone's bit + CLIMB_OFFSET), not on its walk layer: the
## ZombieDirector opens both together (zombies are unchanged), and the bots' mask (WALK_MASK) leaves the climb layers
## out, because a bot cannot climb: on Totenhafen its route to the north catwalk ran up Ladder_CatwalkN and it stood
## at the foot of the ladder for good instead of taking a stair.
const CLIMB_OFFSET: int = 16
const WALK_MASK: int = 0xFFFF
const LINE: StringName = &"climb_line"       # meta: Vector2, the ladder's line (x, z)
const DROP: StringName = &"climb_drop"       # meta: bool, the dead may drop down it
const SPACE_META: StringName = &"climb_space"
const QUEUE: StringName = &"climb_queue"     # meta: Array, the bodies on the rungs now
const SPACE: float = 1.9                     # metres between two climbers on one ladder (a body is 1.8 m)


## True when `body` may start up the ladder `link` now: nobody on its rungs is within the link's spacing of the foot
## (`foot_y`). The body is then counted as on the rungs until it leaves them (on_rungs(body) false: it got over the
## edge, died, fell or was freed). A link without a line never queues.
static func try_enter(link: NavigationLink3D, body: Node3D, foot_y: float) -> bool:
	if link == null or not link.has_meta(LINE):
		return true
	var q: Array = link.get_meta(QUEUE, [])
	var keep: Array = []
	var space: float = float(link.get_meta(SPACE_META, SPACE))
	var free: bool = true
	for b: Variant in q:
		if not is_instance_valid(b) or b == body or not (b as Node).has_method("on_rungs") or not bool((b as Node).call("on_rungs", link)):
			continue
		keep.append(b)
		if (b as Node3D).global_position.y - foot_y < space:
			free = false
	if free:
		keep.append(body)
	link.set_meta(QUEUE, keep)
	return free


## True when `pos` is on a platform a ladder serves: within `reach` m (flat) and 1.5 m (height) of the head of a
## ladder link under `map`'s ClimbLinks, the head at least 3 m over its foot. The horse boss's siege asks (T-268).
static func on_perch(map: Node, pos: Vector3, reach: float = 4.5) -> bool:
	var holder: Node = map.get_node_or_null("ClimbLinks") if map != null else null
	if holder == null:
		return false
	for n: Node in holder.get_children():
		var link: NavigationLink3D = n as NavigationLink3D
		if link == null or not link.has_meta(LINE):
			continue
		var head: Vector3 = link.end_position
		if head.y - link.start_position.y >= 3.0 and absf(pos.y - head.y) < 1.5 and Vector2(pos.x - head.x, pos.z - head.z).length() <= reach:
			return true
	return false


## How many bodies are on the ladder's rungs now (the smokes and the notes' soak read it).
static func on_ladder(link: NavigationLink3D) -> int:
	var n: int = 0
	for b: Variant in (link.get_meta(QUEUE, []) as Array):
		if is_instance_valid(b) and (b as Node).has_method("on_rungs") and bool((b as Node).call("on_rungs", link)):
			n += 1
	return n


## The climb layer bit (a mask value) for a zone's 1-based layer bit.
static func climb_bit(zone_bit: int) -> int:
	return 1 << (zone_bit - 1 + CLIMB_OFFSET)


static func json_path_for(map_id: StringName) -> String:
	var s: String = String(map_id)
	if s.begins_with("map") and s.length() >= 5:
		return "res://data/gravelight/%s.json" % s.get_slice("_", 0)   # map04a_thalbach -> map04a (UPDATE 07)
	return ""


## Spawns every climb link the map's json lists under `root`. Returns the links.
static func spawn_all(root: Node3D, map_id: StringName, zone_bits: Dictionary) -> Array[NavigationLink3D]:
	var out: Array[NavigationLink3D] = []
	var path: String = json_path_for(map_id)
	if path == "" or not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return out
	var data: Dictionary = GLData.load_json(path)
	var rows: Array = data.get("climb_links", [])
	if rows.is_empty():
		return out
	var holder: Node3D = Node3D.new()
	holder.name = "ClimbLinks"
	root.add_child(holder)
	var i: int = 0
	for row: Dictionary in rows:
		var link: NavigationLink3D = NavigationLink3D.new()
		link.name = str(row.get("name", "Climb_%d" % i))
		link.start_position = _v3(row.get("from", [0, 0, 0]))
		link.end_position = _v3(row.get("to", [0, 0, 0]))
		link.bidirectional = bool(row.get("bidirectional", false))
		link.travel_cost = float(row.get("travel_cost", 1.0))
		var zone: String = str(row.get("zone", ""))
		if zone != "" and zone_bits.has(zone):
			link.navigation_layers = climb_bit(int(zone_bits[zone]))
		else:
			link.navigation_layers = 1
		link.set_meta(META, true)
		if row.has("line"):   # T-268: a ladder (see the header)
			var ln: Array = row["line"]
			link.set_meta(LINE, Vector2(float(ln[0]), float(ln[1])))
			link.set_meta(DROP, bool(row.get("drop", false)))
			link.set_meta(SPACE_META, float(row.get("space", SPACE)))
		holder.add_child(link)
		out.append(link)
		i += 1
	return out


static func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
