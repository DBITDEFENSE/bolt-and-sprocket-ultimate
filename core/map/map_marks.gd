class_name MapMarks
extends Node
## The match's map marks (Update 04 section 3, DECISIONS T-069): what the pause map, the ping key and the bots
## agree on. A child of the MapState (MapMarks.attach, from MapState._ready); the marks themselves live in the
## MapState's marker list (MapState.add_marker), so the minimap and the full map draw them with no extra code, and
## WorldMarks puts them in the world (a chalk X on GRAVELIGHT floors, a holo pin on B&S planets).
##
## Kinds: go, defend, danger, regroup, note, buy, collect. Who a mark is for (spec.target):
##   "me"     a personal waypoint (go / note / buy it yourself): up to limits.personal (3) per player, the oldest
##            goes when a new one would pass the cap;
##   "squad"  danger (every bot paths around it for 60 s) and regroup (every bot comes), handled by the order
##            handler; up to limits.danger danger marks per player, one regroup;
##   "any" / a player id / "jakub"   an order for a bot: the order handler (the GRAVELIGHT BotMarkOrders, a node in
##            group "map_mark_orders") picks the bot and says whether it took it. One order per bot: the
##            handler replaces the bot's last order and tells us (order_finished) so its mark goes.
## Tuning: data/maps/marks.json. B&S has no bots: only personal marks there.
##
## The order handler (duck typed, all optional but place_order): place_order(spec, mark_id) -> {ok, pid, reason,
## label?}, cancel_order(mark_id), on_danger(mark), on_regroup(mark) -> {reason}, mark_removed(mark, why) (a
## danger / regroup mark went), bots() -> [{pid, name, color, jakub}], status_of(pid) -> String.

signal placed(mark: Dictionary)
signal removed(mark: Dictionary, why: String)

const CONFIG: String = "res://data/maps/marks.json"
const KINDS: PackedStringArray = ["go", "defend", "danger", "regroup", "note", "buy", "collect"]
const HANDLER_GROUP: StringName = &"map_mark_orders"

static var _cfg_cache: Dictionary = {}

var state: MapState = null
## Node a mark points at (mark id -> Node): a machine, a door, a quest object. Kept here, not in the marker
## dictionary the map draws.
var _nodes: Dictionary = {}
var _world: WorldMarks = null
## The ping key's handler (GRAVELIGHT "ping", B&S "bs_ping").
var ping: MarkPing = null


static func cfg() -> Dictionary:
	if _cfg_cache.is_empty():
		_cfg_cache = MapScan._json(CONFIG)
	return _cfg_cache


## The marks of the running match (null without a MapState).
static func current() -> MapMarks:
	return of(MapState.current())


## The MapMarks of a MapState (made on first use).
static func of(ms: MapState) -> MapMarks:
	if ms == null or not is_instance_valid(ms):
		return null
	var m: MapMarks = ms.get_node_or_null(^"MapMarks") as MapMarks
	if m == null:
		m = attach(ms)
	return m


## Adds the marks under a MapState (MapState._ready does this), with the in-world markers under the level.
static func attach(ms: MapState) -> MapMarks:
	var m: MapMarks = MapMarks.new()
	m.name = "MapMarks"
	m.state = ms
	ms.add_child(m)
	return m


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if state == null:
		state = get_parent() as MapState
	if state != null and state.level_root is Node3D and (state.level_root as Node3D).is_inside_tree():
		_world = WorldMarks.new()
		_world.name = "WorldMarks"
		_world.setup(self)
		_add_world.call_deferred()
	ping = MarkPing.new()
	ping.name = "MarkPing"
	ping.setup(self)
	add_child(ping)


func _add_world() -> void:
	if _world != null and is_instance_valid(_world) and not _world.is_inside_tree() and state != null and is_instance_valid(state.level_root):
		state.level_root.add_child(_world)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _world != null and is_instance_valid(_world) and not _world.is_inside_tree():
		_world.free()   # never added (the level went first)


func _process(_delta: float) -> void:
	if state == null:
		return
	var now: int = Time.get_ticks_msec()
	for m: Dictionary in state.markers().duplicate():
		var until: int = int(m.get("until", 0))
		if until > 0 and now >= until:
			remove(int(m["id"]), "expired")


# ================================================================== queries

func handler() -> Node:
	return get_tree().get_first_node_in_group(HANDLER_GROUP) if is_inside_tree() else null


## Bots that can take orders: [{pid, name, color, jakub}] ([] without a handler, e.g. B&S or solo without bots).
func bots() -> Array:
	var h: Node = handler()
	return h.call("bots") if h != null and h.has_method("bots") else []


func has_bots() -> bool:
	return not bots().is_empty()


func mark(id: int) -> Dictionary:
	for m: Dictionary in state.markers():
		if int(m["id"]) == id:
			return m
	return {}


func marks() -> Array[Dictionary]:
	return state.markers() if state != null else ([] as Array[Dictionary])


## The node a mark points at (null when none or freed).
func node_of(id: int) -> Node:
	var n: Variant = _nodes.get(id)
	return n if n != null and is_instance_valid(n) else null


## A player's personal waypoints, oldest first.
func personal(owner: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m: Dictionary in marks():
		if int(m.get("owner", -1)) == owner and str(m.get("target", "")) == "me":
			out.append(m)
	return out


## The order mark a bot is working ({} none).
func order_mark_of(pid: int) -> Dictionary:
	for m: Dictionary in marks():
		if bool(m.get("order", false)) and int(m.get("pid", -1)) == pid:
			return m
	return {}


## The mark nearest `pos` (flat) within `radius` metres ({} none).
func nearest(pos: Vector3, radius: float) -> Dictionary:
	var best: Dictionary = {}
	var bd: float = radius
	for m: Dictionary in marks():
		var p: Vector3 = m["pos"]
		var d: float = Vector2(p.x - pos.x, p.z - pos.z).length()
		if d <= bd and absf(p.y - pos.y) < 3.0:
			bd = d
			best = m
	return best


# ================================================================== the pure rules (unit-tested)

## Ids to remove so that adding one more leaves at most `max_n` of `group` (oldest first). `group` holds the
## owner's marks of one limit class in creation order.
static func drop_for_limit(group: Array, max_n: int) -> Array[int]:
	var out: Array[int] = []
	var over: int = group.size() + 1 - max_n
	for i: int in clampi(over, 0, group.size()):
		out.append(int((group[i] as Dictionary)["id"]))
	return out


## Which limit class a mark falls in: "personal", "danger", "regroup", or "order".
static func limit_class(kind: String, target: Variant) -> String:
	if kind == "danger":
		return "danger"
	if kind == "regroup":
		return "regroup"
	if str(target) == "me":
		return "personal"
	return "order"


## Who a mark is for when the player doesn't pick: "me" for Go here and notes, "squad" for Danger / Regroup, "any"
## (the best bot) for BUY / COLLECT / DEFEND. Without bots everything is personal.
static func default_target(kind: String, has_bots: bool) -> String:
	if kind == "danger" or kind == "regroup":
		return "squad" if has_bots else "me"
	if not has_bots or kind == "go" or kind == "note":
		return "me"
	return "any"


static func kind_color(kind: String) -> Color:
	return Color(str((cfg().get("colors", {}) as Dictionary).get(kind, "#1f5fa8")))


static func kind_name(kind: String) -> String:
	return str((cfg().get("names", {}) as Dictionary).get(kind, kind.capitalize()))


static func limit(name: String, fallback: int) -> int:
	return int((cfg().get("limits", {}) as Dictionary).get(name, fallback))


# ================================================================== placing and removing

## Places a mark. spec: kind (required), pos (Vector3, required), label, owner (player id; the local player),
## target ("me" / "squad" / "any" / "jakub" / a pid; default by kind), node (what it points at), poi_id, and
## anything the order handler reads (slot / option for the Armorer's Bench, for_pid for "buy it for me",
## confirmed for doors). Returns {ok, id, reason, pid, replaced: [ids], label}.
func place(spec: Dictionary) -> Dictionary:
	var kind: String = str(spec.get("kind", "go"))
	var res: Dictionary = {"ok": false, "id": -1, "reason": "", "pid": -1, "replaced": [], "label": ""}
	if state == null or not spec.has("pos"):
		res["reason"] = "No map."
		return res
	var owner: int = int(spec.get("owner", Net.local_player_id()))
	var target: Variant = spec.get("target", default_target(kind, has_bots()))
	if (target is String or target is StringName) and str(target) == "":
		target = default_target(kind, has_bots())
	var cls: String = limit_class(kind, target)
	if cls == "order" and handler() == null:
		res["reason"] = "No bots in this match."
		return res
	var label: String = str(spec.get("label", kind_name(kind)))
	var col: Color = kind_color(kind)
	var mk: Dictionary = {"pos": spec["pos"], "kind": kind, "label": label, "color": col, "owner": owner, "target": target,
		"poi_id": str(spec.get("poi_id", "")), "created": Time.get_ticks_msec(), "order": cls == "order"}
	var life: float = float((cfg().get("lifetime_s", {}) as Dictionary).get(kind, 0.0))
	if life > 0.0:
		mk["until"] = Time.get_ticks_msec() + int(life * 1000.0)
	# limits (personal waypoints, danger, regroup): the oldest goes
	var replaced: Array = []
	if cls != "order":
		var group: Array = []
		for m: Dictionary in marks():
			if limit_class(str(m["kind"]), m.get("target", "")) == cls and (cls == "regroup" or int(m.get("owner", -1)) == owner):
				group.append(m)
		for rid: int in drop_for_limit(group, limit(cls, 3 if cls != "regroup" else 1)):
			remove(rid, "replaced")
			replaced.append(rid)
	var id: int = state.add_marker(mk)
	if spec.get("node") is Node:
		_nodes[id] = spec["node"]
	res["id"] = id
	res["replaced"] = replaced
	res["label"] = label
	var h: Node = handler()
	if cls == "order":
		var o: Dictionary = h.call("place_order", spec, id)
		if not bool(o.get("ok", false)):
			_drop(id)
			res["reason"] = str(o.get("reason", "No bot can take that."))
			res["pid"] = int(o.get("pid", -1))
			return res
		var pid: int = int(o.get("pid", -1))
		var changes: Dictionary = {"pid": pid, "target": pid}
		if o.has("label"):
			changes["label"] = str(o["label"])
			res["label"] = str(o["label"])
		if pid > 0:
			changes["color"] = Net.player_color(pid) if pid != 9 else Color("#8a6a3a")
		state.update_marker(id, changes)
		res["pid"] = pid
		res["reason"] = str(o.get("reason", ""))
	elif kind == "danger" and h != null and h.has_method("on_danger"):
		h.call("on_danger", mark(id))
	elif kind == "regroup" and h != null and h.has_method("on_regroup"):
		var r2: Dictionary = h.call("on_regroup", mark(id))
		res["reason"] = str(r2.get("reason", ""))
	res["ok"] = true
	placed.emit(mark(id))
	return res


## Removes a mark (an order mark cancels the bot's order). `why`: "removed" (the player), "replaced", "expired",
## "done" (the order handler finished it).
func remove(id: int, why: String = "removed") -> bool:
	var m: Dictionary = mark(id)
	if m.is_empty():
		return false
	var h: Node = handler()
	if why != "done" and h != null:
		if bool(m.get("order", false)) and h.has_method("cancel_order"):
			h.call("cancel_order", id)
		elif h.has_method("mark_removed"):
			h.call("mark_removed", m, why)   # a danger mark's zone, a regroup's bots
	_drop(id)
	removed.emit(m, why)
	return true


func _drop(id: int) -> void:
	_nodes.erase(id)
	state.remove_marker(id)


## The order handler is done with a mark (the bot bought it, gave up, got a new order): it goes.
func order_finished(id: int) -> void:
	remove(id, "done")


## Removes the mark nearest `pos` within `radius` m (the ping key on a mark). True when one went.
func remove_near(pos: Vector3, radius: float, owner: int = -1) -> bool:
	var m: Dictionary = nearest(pos, radius)
	if m.is_empty() or (owner >= 0 and int(m.get("owner", -1)) != owner and not bool(m.get("order", false))):
		return false
	return remove(int(m["id"]))


## Every mark goes (a new match, the dev console).
func clear() -> void:
	for m: Dictionary in marks().duplicate():
		remove(int(m["id"]), "removed")


## A bot's order line for the map ("Going to buy Ironhide (1,200 short)", "Idle"); "" without a handler.
func status_of(pid: int) -> String:
	var h: Node = handler()
	return str(h.call("status_of", pid)) if h != null and h.has_method("status_of") else ""
