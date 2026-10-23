class_name MapState
extends Node
## What the squad knows about the map this match (Update 04 section 2, DECISIONS T-065), shared by the minimap and
## the full pause map (section 3): which POIs have been discovered, which areas are revealed (fog of war), the live
## state of doors and buyables, the live icons (teammates, bots, Jakub, the downed, power-ups, the boss, revealed
## zombies, easter-egg objectives) and the map marks.
##
## One per match: MapState.attach(level_root, map_id) (MapRoot / BSLevel) adds it under the level; current() finds
## it from anywhere. Without baked map data for the level there is none (current() = null) and nothing draws.
##
## Rules (tuning in data/maps/minimap.json):
##   - a buyable (minimap.json discover_types) shows once the local player has seen it in person: within range,
##     inside the view cone, nothing in the way. The Requisition Crate's spot counts only while the crate is there,
##     and is forgotten when the crate moves;
##   - doors, lifts and the rest show once their area is revealed; the fog reveals within a radius of the local
##     player on their floor ("Fog of war: Always visible" in the settings turns it off);
##   - zombies: hidden, except those a shot reveals (any player's weapon that is not suppressed reveals the zombies
##     near the shooter for a second) and, with "Show nearby zombies: Always", the ones near the player
##     (setting minimap_zombies: off / firing / always);
##   - objectives come from providers (add_objective_provider); the built-in one lists the quest objects in the
##     level while a quest is running, filtered by the spoiler setting (GLSettings "objective_spoilers", section 4:
##     hidden / hints / full): hidden shows none, hints the ones seen in person, full all of them.

signal poi_discovered(id: String)
signal markers_changed
signal fog_changed(floor_index: int)

const CONFIG: String = "res://data/maps/minimap.json"
const SPOILER_KEY: String = "objective_spoilers"   # the section 4 setting (ObjectiveLog.LEVELS)

static var _current: MapState = null
## Section 6 (the M1911 suppressor) can plug in here: func(pid: int, weapon_id: StringName) -> bool, true when that
## player's shot is suppressed and must not reveal zombies. Without it, the shooter's current WeaponInstance is asked
## (an is_suppressed() method, a "suppressed" property, or a "suppressed" meta).
static var suppressed_check: Callable = Callable()

var data: MapData
var level_root: Node
var game: String = "gravelight"
var cfg: Dictionary = {}
var discovered: Dictionary = {}        # poi id -> true
var fog_images: Array[Image] = []
var fog_textures: Array[ImageTexture] = []
var fog_cell: float = 1.0
var fog_size: Vector2i = Vector2i.ONE

var _discover_types: Array = []
var _disc_i: int = 0
var _seen_objectives: Dictionary = {}  # node instance id -> true
var _fog_dirty: Dictionary = {}        # floor -> true
var _fog_t: float = 0.0
var _revealed_z: Dictionary = {}       # zombie instance id -> seconds left
var _markers: Array[Dictionary] = []
var _next_marker: int = 1
var _providers: Array[Callable] = []
var _quest_nodes: Array[Node] = []
var _node_cache: Dictionary = {}       # poi id -> Node (or null)
var _live_frame: int = -1
var _live: Array[Dictionary] = []
var _obj_t: float = 0.0
var _obj_cache: Array[Dictionary] = []


# ================================================================== lifetime

## The map state of the running match (null when there is none or the level has no map data).
static func current() -> MapState:
	if _current != null and is_instance_valid(_current) and _current.is_inside_tree():
		return _current
	return null


## Adds the match's map state under `root` (the level). Returns null when the level has no baked map data.
static func attach(root: Node, map_id: StringName, game_id: String = "") -> MapState:
	var md: MapData = MapData.for_map(map_id)
	if md == null:
		push_warning("MapState: no map data for %s (run tools/bake_minimap.sh)" % map_id)
		return null
	var ms: MapState = MapState.new()
	ms.name = "MapState"
	ms.setup(md, root, game_id if game_id != "" else md.game)
	root.add_child(ms)
	return ms


## Without the tree (tests): data, the level root it reads nodes from, and the game.
func setup(md: MapData, root: Node, game_id: String) -> void:
	data = md
	level_root = root
	game = game_id
	cfg = MapScan._json(CONFIG)
	_discover_types = (cfg.get("discover_types", {}) as Dictionary).get(game, [])
	var fc: Dictionary = cfg.get("fog", {})
	fog_cell = float(fc.get("cell_m", 1.0))
	fog_size = Vector2i(maxi(1, int(ceil(md.world_rect.size.x / fog_cell))), maxi(1, int(ceil(md.world_rect.size.y / fog_cell))))
	fog_images.clear()
	fog_textures.clear()
	for i: int in md.floors.size():
		var img: Image = Image.create(fog_size.x, fog_size.y, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 1, 1))
		fog_images.append(img)
		fog_textures.append(ImageTexture.create_from_image(img))
	add_objective_provider(_default_objectives)


func _enter_tree() -> void:
	_current = self


func _exit_tree() -> void:
	if _current == self:
		_current = null


func _ready() -> void:
	if Engine.has_singleton(&"GLBus") or get_node_or_null(^"/root/GLBus") != null:
		GLBus.weapon_fired.connect(_on_weapon_fired)
		GLBus.crate_moved.connect(_on_crate_moved)
	_scan_quest_nodes.call_deferred()
	get_tree().node_added.connect(_on_node_added)


func _process(delta: float) -> void:
	var body: Node3D = local_body()
	if body != null and is_instance_valid(body):
		var n: int = int((cfg.get("discovery", {}) as Dictionary).get("checks_per_frame", 3))
		for i: int in n:
			_discovery_step()
		_fog_t -= delta
		if _fog_t <= 0.0:
			_fog_t = 1.0 / maxf(1.0, float((cfg.get("fog", {}) as Dictionary).get("update_hz", 5.0)))
			reveal(body.global_position)
			_flush_fog()
	for k: Variant in _revealed_z.keys():
		_revealed_z[k] = float(_revealed_z[k]) - delta
		if float(_revealed_z[k]) <= 0.0:
			_revealed_z.erase(k)


# ================================================================== players

## The local player's body (GRAVELIGHT: MapRoot.player; B&S: BSLevel.bolt).
func local_body() -> Node3D:
	if level_root == null or not is_instance_valid(level_root):
		return null
	var p: Variant = level_root.get("player")
	if p is Node3D:
		return p
	var b: Variant = level_root.get("bolt")
	return b if b is Node3D else null


## The local player's eye and view direction: [origin, forward].
func local_view() -> Array:
	var body: Node3D = local_body()
	if body == null:
		return [Vector3.ZERO, Vector3.FORWARD]
	var cam: Camera3D = view_camera()
	if cam != null:
		return [cam.global_position, -cam.global_basis.z]
	return [body.global_position + Vector3.UP * 1.5, -body.global_basis.z]


## The local player's view camera: GRAVELIGHT Player.camera (first person), B&S BoltCamera.cam (third person).
func view_camera() -> Camera3D:
	var body: Node3D = local_body()
	if body == null:
		return null
	var cam: Variant = body.get("camera")
	if cam is Node and not (cam is Camera3D):
		cam = (cam as Node).get("cam")   # B&S: BoltCamera holds its Camera3D in "cam"
	if cam is Camera3D and (cam as Camera3D).is_inside_tree():
		return cam as Camera3D
	return null


## Godot-convention yaw (forward = (-sin y, 0, -cos y); 0 = facing north, -PI/2 = facing east) of a direction.
static func yaw_of(forward: Vector3) -> float:
	return atan2(-forward.x, -forward.z)


## Where the view looks, as a yaw: the minimap turns by this in "turns with you" mode, so what is ahead on screen
## is up on the map (first person: the player's facing; B&S: the chase camera's direction, not Bolt's).
func view_yaw() -> float:
	var cam: Camera3D = view_camera()
	if cam != null:
		var f: Vector3 = -cam.global_basis.z
		if Vector2(f.x, f.z).length() > 0.01:
			return yaw_of(f)
	var body: Node3D = local_body()
	return body.global_rotation.y if body != null else 0.0


## The local player's body facing, as a yaw (the arrow): GRAVELIGHT the body's rotation; B&S Bolt's motor.yaw,
## which uses the web build's atan2(x, z) convention (forward = (sin m, 0, cos m)), so it is turned by PI.
func facing_yaw() -> float:
	var body: Node3D = local_body()
	if body == null:
		return 0.0
	var motor: Variant = body.get("motor")
	if motor is Object and (motor as Object).get("yaw") != null:
		return bs_yaw_to_godot(float((motor as Object).get("yaw")))
	return body.global_rotation.y


## B&S motor yaw (forward = (sin m, 0, cos m)) -> Godot yaw (forward = (-sin y, 0, -cos y)).
static func bs_yaw_to_godot(m: float) -> float:
	return wrapf(m + PI, -PI, PI)


func local_floor() -> int:
	var body: Node3D = local_body()
	return data.floor_at(body.global_position + Vector3.UP * 0.2) if body != null else 0


# ================================================================== discovery

## Pure: is `target` inside the seeing range and view cone of an eye at `eye` looking along `fwd`?
static func in_view(eye: Vector3, fwd: Vector3, target: Vector3, range_m: float, fov_deg: float) -> bool:
	var d: Vector3 = target - eye
	var dist: float = d.length()
	if dist > range_m:
		return false
	if dist < 2.0:
		return true   # standing at it
	return fwd.normalized().dot(d / dist) >= cos(deg_to_rad(fov_deg * 0.5))


func needs_discovery(poi: Dictionary) -> bool:
	return _discover_types.has(str(poi.get("type", "")))


func is_discovered(id: String) -> bool:
	return discovered.has(id)


func discover(id: String) -> void:
	if discovered.has(id) or data.poi(id).is_empty():
		return
	discovered[id] = true
	poi_discovered.emit(id)


## Dev / tests: every POI discovered and the whole map revealed.
func discover_all() -> void:
	for p: Dictionary in data.pois:
		discover(str(p["id"]))
	for i: int in fog_images.size():
		fog_images[i].fill(Color(1, 1, 1, 0))
		_fog_dirty[i] = true
	_flush_fog()


func forget(id: String) -> void:
	discovered.erase(id)


## One round-robin discovery test (POIs, then quest objects).
func _discovery_step() -> void:
	var total: int = data.pois.size() + _quest_nodes.size()
	if total == 0:
		return
	_disc_i = (_disc_i + 1) % total
	var dc: Dictionary = cfg.get("discovery", {})
	var view: Array = local_view()
	if _disc_i < data.pois.size():
		var p: Dictionary = data.pois[_disc_i]
		var id: String = str(p["id"])
		if discovered.has(id) or not needs_discovery(p):
			return
		if str(p["type"]) == "crate_spot" and not _crate_here(p):
			return
		var target: Vector3 = poi_world_pos(p) + Vector3.UP * (0.0 if str(p["type"]) == "wall_buy" else 1.0)   # chalk is at eye height
		if in_view(view[0], view[1], target, float(dc.get("range_m", 16.0)), float(dc.get("fov_deg", 80.0))) \
				and _line_clear(view[0], target, float(dc.get("hit_slack_m", 1.6))):
			discover(id)
		return
	var qn: Node = _quest_nodes[_disc_i - data.pois.size()]
	if not is_instance_valid(qn) or _seen_objectives.has(qn.get_instance_id()) or not (qn is Node3D):
		return
	var t2: Vector3 = (qn as Node3D).global_position + Vector3.UP * 0.5
	if in_view(view[0], view[1], t2, float(dc.get("range_m", 16.0)), float(dc.get("fov_deg", 80.0))) \
			and _line_clear(view[0], t2, float(dc.get("hit_slack_m", 1.6))):
		_seen_objectives[qn.get_instance_id()] = true


func _line_clear(from: Vector3, to: Vector3, slack: float) -> bool:
	if level_root == null or not (level_root is Node3D) or not (level_root as Node3D).is_inside_tree():
		return true
	var space: PhysicsDirectSpaceState3D = (level_root as Node3D).get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	var body: Node3D = local_body()
	if body is CollisionObject3D:
		q.exclude = [(body as CollisionObject3D).get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	return hit.is_empty() or (hit["position"] as Vector3).distance_to(to) <= slack


# ================================================================== POI live state

## The node a POI was baked from (null when it is gone or the level has none, e.g. B&S rows).
func poi_node(p: Dictionary) -> Node:
	var id: String = str(p["id"])
	if _node_cache.has(id):
		var c: Variant = _node_cache[id]
		return c if c != null and is_instance_valid(c) else null
	var n: Node = null
	var path: String = str(p.get("node_path", ""))
	if path != "" and level_root != null and is_instance_valid(level_root):
		n = level_root.get_node_or_null(NodePath(path))
	_node_cache[id] = n
	return n


## Where the POI is now (its node's position when it has one, else the baked one).
func poi_world_pos(p: Dictionary) -> Vector3:
	var n: Node = poi_node(p)
	if n is Node3D and (n as Node3D).is_inside_tree():
		var pos: Vector3 = (n as Node3D).global_position
		if n is Lift:
			pos.y = (n as Lift).top_y
		return pos
	return p["pos"]


## Live state of a POI for icons and the pause map's hover: {open, locked, powered, ready, price, label, here}.
##   door: open / locked (needs the power, or a blast door's flag); perk / Crucible: powered;
##   trap: ready (can be bought now); lift: ready; workbench: built; power_switch: open (= power on);
##   crate_spot: here (the crate is at this spot now). price: the node's live price when it has one.
func poi_state(p: Dictionary) -> Dictionary:
	var s: Dictionary = {"open": false, "locked": false, "powered": true, "ready": true, "price": int(p.get("price", 0)),
		"label": str(p.get("label", "")), "here": true}
	var n: Node = poi_node(p)
	match str(p["type"]):
		"door":
			if n is BuyDoor:
				var d: BuyDoor = n as BuyDoor
				s["open"] = d.is_open
				s["locked"] = d.requires_power and not GameState.power_on and not d.is_open
				s["price"] = d.cost
			elif n is BlastDoor:
				s["open"] = (n as BlastDoor).is_open
				s["locked"] = not (n as BlastDoor).is_open
		"perk", "crucible":
			if n != null and n.has_method("is_powered"):
				s["powered"] = bool(n.call("is_powered"))
		"wall_buy":
			if n is WallBuy:
				s["price"] = (n as WallBuy).price()
		"trap":
			var tp: Node = null
			if n is TrapLever and not (n as TrapLever).trap_path.is_empty():
				tp = n.get_node_or_null((n as TrapLever).trap_path)
			if tp != null and tp.has_method("can_activate"):
				s["ready"] = bool(tp.call("can_activate"))
		"lift":
			if n is Lift:
				s["ready"] = (n as Lift).is_usable()
		"workbench":
			if n is Workbench:
				s["open"] = (n as Workbench).built
		"power_switch":
			s["open"] = GameState.power_on
		"crate_spot":
			s["here"] = _crate_here(p)
	return s


func _crate_here(p: Dictionary) -> bool:
	if game != "gravelight":
		return true
	var idx: int = int((p.get("data", {}) as Dictionary).get("spot_index", -1))
	if idx != CrateManager.location_index:
		return false
	var n: Node = poi_node(p)
	if n is MysteryCrate:
		return (n as MysteryCrate).phase != MysteryCrate.Phase.HIDDEN
	return true


func _on_crate_moved(_new_index: int) -> void:
	for p: Dictionary in data.pois_of_type("crate_spot"):
		forget(str(p["id"]))


## The POIs the map shows on a floor (-1 = every floor) right now: discovered buyables (the crate only at its
## current spot), and the rest once their area is revealed (or with the fog off).
func visible_pois(floor_index: int = -1, fog_on: bool = true) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in data.pois:
		if floor_index >= 0 and int(p["floor"]) != floor_index:
			continue
		if str(p["type"]) == "crate_spot" and not _crate_here(p):
			continue
		if needs_discovery(p):
			if not discovered.has(str(p["id"])):
				continue
		elif fog_on and not is_revealed(p["pos"] as Vector3, int(p["floor"])):
			continue
		out.append(p)
	return out


# ================================================================== fog of war

func _cell_of(pos: Vector3) -> Vector2i:
	var uv: Vector2 = data.world_to_uv(pos)
	return Vector2i(int(floor(uv.x * fog_size.x)), int(floor(uv.y * fog_size.y)))


## Reveals the cells within the reveal radius of `pos` on its floor.
func reveal(pos: Vector3, radius: float = -1.0) -> void:
	if fog_images.is_empty():
		return
	var r: float = radius if radius > 0.0 else float((cfg.get("fog", {}) as Dictionary).get("reveal_radius_m", 9.0))
	var fi: int = data.floor_at(pos + Vector3.UP * 0.2)
	var img: Image = fog_images[fi]
	var c: Vector2i = _cell_of(pos)
	var rc: int = int(ceil(r / fog_cell))
	var changed: bool = false
	for y: int in range(maxi(0, c.y - rc), mini(fog_size.y, c.y + rc + 1)):
		for x: int in range(maxi(0, c.x - rc), mini(fog_size.x, c.x + rc + 1)):
			var d: float = Vector2(x - c.x, y - c.y).length() * fog_cell
			if d > r:
				continue
			var a: float = clampf((d - r * 0.7) / (r * 0.3), 0.0, 1.0)   # soft rim
			var cur: float = img.get_pixel(x, y).a
			if a < cur - 0.01:
				img.set_pixel(x, y, Color(1, 1, 1, a))
				changed = true
	if changed:
		_fog_dirty[fi] = true


func is_revealed(pos: Vector3, floor_index: int = -1) -> bool:
	if fog_images.is_empty():
		return true
	var fi: int = floor_index if floor_index >= 0 else data.floor_at(pos + Vector3.UP * 0.2)
	var c: Vector2i = _cell_of(pos)
	if c.x < 0 or c.y < 0 or c.x >= fog_size.x or c.y >= fog_size.y:
		return false
	return fog_images[fi].get_pixel(c.x, c.y).a < 0.5


## Share of a floor's cells revealed (0..1).
func revealed_fraction(floor_index: int) -> float:
	var img: Image = fog_images[floor_index]
	var n: int = 0
	for y: int in fog_size.y:
		for x: int in fog_size.x:
			if img.get_pixel(x, y).a < 0.5:
				n += 1
	return float(n) / float(fog_size.x * fog_size.y)


func _flush_fog() -> void:
	for fi: Variant in _fog_dirty.keys():
		fog_textures[int(fi)].set_image(fog_images[int(fi)])
		fog_changed.emit(int(fi))
	_fog_dirty.clear()


# ================================================================== zombies

## The minimap's zombie setting: "off" / "firing" / "always".
static func zombie_mode() -> String:
	return str(GLSettings.values.get("minimap_zombies", "firing"))


## Pure: indices of the positions within `radius` of `origin`.
static func within(origin: Vector3, positions: Array, radius: float) -> Array[int]:
	var out: Array[int] = []
	for i: int in positions.size():
		if (positions[i] as Vector3).distance_to(origin) <= radius:
			out.append(i)
	return out


## Whether a player's shot is suppressed (no reveal). See suppressed_check.
static func shot_is_suppressed(pid: int, weapon_id: StringName, tree: SceneTree = null) -> bool:
	if suppressed_check.is_valid():
		return bool(suppressed_check.call(pid, weapon_id))
	if tree == null:
		return false
	for n: Node in tree.get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or p.player_id != pid or p.weapons == null:
			continue
		var w: WeaponInstance = p.weapons.current()
		if w == null:
			return false
		if w.has_method("is_suppressed"):
			return bool(w.call("is_suppressed"))
		if w.get("suppressed") != null:
			return bool(w.get("suppressed"))
		return bool(w.get_meta(&"suppressed", false))
	return false


func _on_weapon_fired(pid: int, weapon_id: StringName, _upgraded: bool, origin: Vector3, _dir: Vector3) -> void:
	if zombie_mode() == "off" or shot_is_suppressed(pid, weapon_id, get_tree()):
		return
	var zc: Dictionary = cfg.get("zombies", {})
	reveal_zombies(origin, float(zc.get("reveal_radius_m", 25.0)), float(zc.get("reveal_seconds", 1.0)))


## Every zombie within `radius` of `origin` blips for `seconds` (a shot; the Overwatch reward can call this too).
func reveal_zombies(origin: Vector3, radius: float, seconds: float) -> int:
	var zs: Array = _zombies()
	var pos: Array = zs.map(func(z: Node3D) -> Vector3: return z.global_position)
	var n: int = 0
	for i: int in within(origin, pos, radius):
		_revealed_z[(zs[i] as Node).get_instance_id()] = maxf(seconds, float(_revealed_z.get((zs[i] as Node).get_instance_id(), 0.0)))
		n += 1
	return n


func is_zombie_revealed(z: Node) -> bool:
	return _revealed_z.has(z.get_instance_id())


func _zombies() -> Array:
	var d: Variant = level_root.get("director") if level_root != null and is_instance_valid(level_root) else null
	if d is ZombieDirector:
		return (d as ZombieDirector).active_zombies()
	return []


# ================================================================== markers (section 3 feeds these)

## Adds a map mark and returns its id. Keys: pos (Vector3, required), kind ("go" / "defend" / "danger" / "regroup"
## / "note" / "buy" / "collect" / anything: the icon), label, color (Color), owner (player id), target ("me" /
## "any" / a player id), poi_id (a POI it points at). floor is filled in from pos. Limits are the caller's job.
func add_marker(m: Dictionary) -> int:
	var mk: Dictionary = m.duplicate()
	mk["id"] = _next_marker
	_next_marker += 1
	if not mk.has("floor"):
		mk["floor"] = data.floor_at((mk.get("pos", Vector3.ZERO) as Vector3) + Vector3.UP * 0.2)
	_markers.append(mk)
	markers_changed.emit()
	return int(mk["id"])


func update_marker(id: int, changes: Dictionary) -> void:
	for m: Dictionary in _markers:
		if int(m["id"]) == id:
			m.merge(changes, true)
			markers_changed.emit()
			return


func remove_marker(id: int) -> void:
	for i: int in _markers.size():
		if int(_markers[i]["id"]) == id:
			_markers.remove_at(i)
			markers_changed.emit()
			return


## Removes every mark (of one owner when owner >= 0).
func clear_markers(owner: int = -1) -> void:
	var keep: Array[Dictionary] = []
	for m: Dictionary in _markers:
		if owner >= 0 and int(m.get("owner", -1)) != owner:
			keep.append(m)
	_markers = keep
	markers_changed.emit()


func markers() -> Array[Dictionary]:
	return _markers


# ================================================================== objectives

## Adds an objective source: func() -> Array[Dictionary] of {id, pos (Vector3), label, kind, quest_id?, step_id?,
## node?}. Sections 4/5 can add theirs (or clear_objective_providers() and replace the built-in one).
func add_objective_provider(c: Callable) -> void:
	_providers.append(c)


func clear_objective_providers() -> void:
	_providers.clear()


static func spoiler_mode() -> String:
	return str(GLSettings.values.get(SPOILER_KEY, "hints"))


## The easter-egg objectives the map shows now, with the spoiler setting applied (cached for objectives.refresh_s).
func objectives() -> Array[Dictionary]:
	var t: float = Time.get_ticks_msec() / 1000.0
	if t < _obj_t:
		return _obj_cache
	_obj_t = t + float((cfg.get("objectives", {}) as Dictionary).get("refresh_s", 1.0))
	_obj_cache = filter_objectives(_gather_objectives(), spoiler_mode(), _seen_objectives)
	return _obj_cache


func _gather_objectives() -> Array[Dictionary]:
	var all: Array[Dictionary] = []
	for c: Callable in _providers:
		if c.is_valid():
			for o: Variant in c.call():
				all.append(o as Dictionary)
	return all


## Pure: hidden = none, hints = only the ones seen (seen: node instance id -> true; rows without a node pass),
## full = all.
static func filter_objectives(all: Array[Dictionary], mode: String, seen: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if mode == "hidden":
		return out
	for o: Dictionary in all:
		var n: Variant = o.get("node")
		if mode != "full" and n is Node and is_instance_valid(n) and not seen.has((n as Node).get_instance_id()):
			continue
		out.append(o)
	return out


## The built-in provider: quest objects in the level (notes, radios, parts, bells, pylons, the altar...) while a
## quest is running and the object is visible.
func _default_objectives() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if game != "gravelight":
		return out
	var running: bool = false
	for qid: StringName in QuestManager.quest_ids():
		running = running or not QuestManager.is_complete(qid)
	if not running:
		return out
	for n: Node in _quest_nodes:
		if not is_instance_valid(n) or not (n is Node3D) or not (n as Node3D).is_visible_in_tree():
			continue
		out.append({"id": "obj:%d" % n.get_instance_id(), "pos": (n as Node3D).global_position, "label": _quest_label(n),
			"kind": "objective", "node": n})
	return out


static func is_quest_node(n: Node) -> bool:
	return n is QuestNote or n is QuestPickup or n is QuestRadio or n is QuestBell or n is Pylon or n is AltarReliquary \
		or n is Phonograph or n is BuildablePart or n is FieldRadio or n is Switchboard


static func _quest_label(n: Node) -> String:
	if n is QuestPickup:
		return (n as QuestPickup).label.capitalize()
	if n is QuestNote:
		return "Radio note"
	if n is QuestRadio or n is FieldRadio:
		return "Radio"
	if n is QuestBell:
		return "Bell"
	if n is Pylon:
		return "Resonance Pylon"
	if n is AltarReliquary:
		return "Altar"
	if n is Phonograph:
		return "Phonograph"
	if n is BuildablePart:
		return "Part"
	if n is Switchboard:
		return "Switchboard"
	return String(n.name).capitalize()


func _scan_quest_nodes() -> void:
	if level_root == null or not is_instance_valid(level_root) or game != "gravelight":
		return
	for n: Node in MapScan._walk(level_root):
		if is_quest_node(n):
			_quest_nodes.append(n)


func _on_node_added(n: Node) -> void:
	if game == "gravelight" and is_quest_node(n) and not _quest_nodes.has(n):
		_quest_nodes.append(n)


# ================================================================== live icons

## Everything that moves, for the minimap and the pause map, computed once per frame:
## {kind: "ally" | "bot" | "jakub" | "downed" | "powerup" | "boss" | "zombie", pos, yaw, color, initial, label,
##  pid?, bleed (0..1 left, downed), blink (bool)}. The local player is not in the list.
func live_icons() -> Array[Dictionary]:
	var f: int = Engine.get_process_frames()
	if f == _live_frame:
		return _live
	_live_frame = f
	_live = []
	if game != "gravelight" or level_root == null or not is_instance_valid(level_root):
		return _live
	var me: Node3D = local_body()
	var session: Variant = Net.session
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or p == me or not p.is_inside_tree() or p.spectating:
			continue
		var kind: String = "jakub" if p.is_companion else ("bot" if p.is_bot else "ally")
		var dn: String = Net.display_name(p.player_id)
		var row: Dictionary = {"kind": kind, "pos": p.global_position, "yaw": p.global_rotation.y, "pid": p.player_id,
			"color": Net.player_color(p.player_id), "initial": dn.substr(0, 1).to_upper(), "label": dn, "bleed": 1.0, "blink": false}
		if p.is_companion:
			row["initial"] = "J"
			row["label"] = "Jakub"
		if p.downed:
			row["kind"] = "downed"
			row["sub"] = kind
			if session is NetMatch:
				var total: float = p.bleedout_seconds if p.bleedout_seconds > 0.0 else float(GLData.table("player").get("bleedout_seconds", 30.0))
				row["bleed"] = clampf((session as NetMatch).coop.bleed_left(p.player_id) / maxf(0.1, total), 0.0, 1.0)
		_live.append(row)
	var pm: Variant = PowerupManager.get("_pickups")
	if pm is Array:
		for pu: Variant in pm:
			if pu is Node3D and is_instance_valid(pu) and (pu as Node3D).is_inside_tree():
				var pid2: StringName = StringName(str((pu as Node).get("powerup_id")))
				_live.append({"kind": "powerup", "pos": (pu as Node3D).global_position, "label": PowerupManager.display_name(pid2),
					"id": String(pid2), "blink": true})
	for b: Node in get_tree().get_nodes_in_group(&"bosses"):
		if b is Node3D and is_instance_valid(b) and (b as Node3D).is_inside_tree() and (not b.has_method("is_active") or bool(b.call("is_active"))):
			_live.append({"kind": "boss", "pos": (b as Node3D).global_position, "label": "Boss", "blink": false})
	var mode: String = zombie_mode()
	if mode != "off" and me != null:
		var zc: Dictionary = cfg.get("zombies", {})
		var near_r: float = float(zc.get("always_radius_m", 24.0))
		var tol: float = float(zc.get("floor_tolerance_m", 2.6))
		for z: Variant in _zombies():
			var zn: Node3D = z as Node3D
			if zn == null or zn.is_in_group(&"bosses"):
				continue
			var show: bool = is_zombie_revealed(zn) or (mode == "always" and zn.global_position.distance_to(me.global_position) <= near_r)
			if show and absf(zn.global_position.y - me.global_position.y) <= tol:
				_live.append({"kind": "zombie", "pos": zn.global_position, "blink": false})
	return _live
