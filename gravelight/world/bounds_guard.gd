class_name BoundsGuard
extends Node
## The safety net on every map (T-185; the owner: "on all maps if a user gets too far away it respawns them back
## down"). A few times a second (check_s) the host / solo looks at every body in the "players" group (the human,
## squad bots, companions, online co-op's remote humans) and brings back down anyone who is far outside the playable
## space:
##   below    under the floor: below the navmesh's lowest point by below_m
##   above    over the ceiling: above the navmesh's highest point plus a jump at the map's gravity, a launch plate's
##            arc and ceiling_m
##   outside  beyond the navmesh's footprint (x, z) grown by edge_m
##   falling  falling (not on a floor, moving down) longer than any real fall on the map can last (ceiling to
##            kill height at the map's gravity, plus fall_extra_s)
##   off_nav  standing on something that is no part of the map: off_nav_m from the navmesh and outside every zone
##            volume (a map with zone volumes only) for off_nav_s (an invisible deck plane outside a hull)
## The way back: the last safe floor the body stood on (on the navmesh, in bounds, on a still floor), else the
## nearest navmesh point in its zone, else its spawn; velocity and pushes zeroed, a short fade for the local human,
## no damage, no down. The bounds come from the map's navmesh (every NavigationRegion3D, enabled or not: the
## Kranich's wing walk counts) and world.json "play_bounds"; a map's json "play_bounds" block overrides any number
## (or sets "enabled": false). Never while: the match is not PLAYING, a cutscene runs (flag "cutscene"), the dev
## console is open, the body spectates, flies noclip, mantles, rides a launch plate's arc (Player.air_grace_t), stands
## on a moving floor (a lift, a platform), or is held by a "play_space" node (group; play_space_has(p): the Slender's
## Watch Room below Totenhafen). A downed body is only brought back from below / outside (never for its fall or its
## crawl). Every rescue prints "[bounds] ..." and counts in `rescues` / `by_reason` and the static `rescues_total`
## (the smokes read them). Online: the host decides; a remote human's rescue runs on its owner (_net_rescue).
## BotLocomotion's free-fall rescue (T-131) stands down for this when a guard is on the map.

const NAME: String = "BoundsGuard"

static var rescues_total: int = 0

var enabled: bool = true
var rescues: int = 0
var by_reason: Dictionary = {}          # reason -> count
var history: Array[Dictionary] = []     # {pid, reason, from, to, how}
var ready_done: bool = false

# the bounds (derived once the map is in the tree)
var has_nav: bool = false
var nav_lo: Vector3 = Vector3.ZERO
var nav_hi: Vector3 = Vector3.ZERO
var kill_y: float = -INF
var ceiling_y: float = INF
var rect: Rect2 = Rect2()
var max_fall_s: float = INF
var off_nav_m: float = 5.0
var off_nav_s: float = 2.0
var check_s: float = 0.25
var cfg: Dictionary = {}

var _root: Node = null
var _t: float = 0.0
var _st: Dictionary = {}                # pid -> {"safe": Vector3, "fall": float, "off": float}
var _fade: ColorRect = null


## Adds the guard to a map (MapRoot._ready). One per map; its name is fixed so online peers share its node path.
static func attach(root: Node) -> BoundsGuard:
	var old: Node = root.get_node_or_null(NAME)
	if old is BoundsGuard:
		return old as BoundsGuard
	var g: BoundsGuard = BoundsGuard.new()
	g.name = NAME
	root.add_child(g)
	return g


## True when a ready, enabled guard watches the map in `tree` (BotLocomotion's own fall rescue stands down).
static func active(tree: SceneTree) -> bool:
	if tree == null:
		return false
	var g: BoundsGuard = tree.get_first_node_in_group(&"bounds_guard") as BoundsGuard
	return g != null and g.ready_done and g.enabled


## The tuning: world.json "play_bounds", then the map's own json block on top (`map_cfg`).
static func merged_cfg(base: Dictionary, map_cfg: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate()
	for k: Variant in map_cfg:
		out[k] = map_cfg[k]
	return out


## The bounds from the navmesh's extents (`lo`, `hi`), the highest legit apex over the floor (`apex_m`: a jump at the
## map's gravity; `pad_top`: the highest launch plate arc, -INF when none), gravity `g` and the tuning `c`.
## Returns {kill_y, ceiling_y, rect, max_fall_s}. Overrides: kill_y / ceiling_y / max_fall_s / rect [x0, z0, x1, z1].
static func derive(lo: Vector3, hi: Vector3, apex_m: float, pad_top: float, g: float, c: Dictionary) -> Dictionary:
	var kill: float = lo.y - float(c.get("below_m", 8.0))
	var top: float = maxf(hi.y + apex_m, pad_top) + float(c.get("ceiling_m", 8.0))
	var edge: float = float(c.get("edge_m", 15.0))
	var r: Rect2 = Rect2(lo.x - edge, lo.z - edge, (hi.x - lo.x) + 2.0 * edge, (hi.z - lo.z) + 2.0 * edge)
	if c.has("kill_y"):
		kill = float(c["kill_y"])
	if c.has("ceiling_y"):
		top = float(c["ceiling_y"])
	if c.has("rect"):
		var a: Array = c["rect"]
		r = Rect2(float(a[0]), float(a[1]), float(a[2]) - float(a[0]), float(a[3]) - float(a[1]))
	var fall: float = sqrt(2.0 * maxf(1.0, top - kill) / maxf(0.5, g)) + float(c.get("fall_extra_s", 1.5))
	if c.has("max_fall_s"):
		fall = float(c["max_fall_s"])
	return {"kill_y": kill, "ceiling_y": top, "rect": r, "max_fall_s": fall}


## The rule (pure, for the tests): why a body at `pos` must come back, or &"" when it is fine. `fall_s` / `off_s`
## are how long it has been falling / standing off the map; `downed` bodies only come back from below / outside.
static func verdict(pos: Vector3, fall_s: float, off_s: float, downed: bool, b: Dictionary) -> StringName:
	if pos.y < float(b.get("kill_y", -INF)):
		return &"below"
	var r: Rect2 = b.get("rect", Rect2())
	if r.size.x > 0.0 and r.size.y > 0.0 and not r.has_point(Vector2(pos.x, pos.z)):
		return &"outside"
	if downed:
		return &""
	if pos.y > float(b.get("ceiling_y", INF)):
		return &"above"
	if fall_s > float(b.get("max_fall_s", INF)):
		return &"falling"
	if off_s > float(b.get("off_nav_s", INF)):
		return &"off_nav"
	return &""


## The longest a body has to stand off the navmesh before off_nav applies, with the nav flat distance `d` this check.
static func off_nav_now(d: float, limit_m: float, in_zone: bool, has_zones: bool) -> bool:
	return d > limit_m and (not has_zones or not in_zone)


func _ready() -> void:
	add_to_group(&"bounds_guard")
	_root = get_parent()
	_setup.call_deferred()
	var con: Node = get_node_or_null("/root/GLConsole")
	if con != null and con.has_method("register"):
		con.call("register", "bounds", _cmd, "bounds [up|out|down]: the safety net's numbers and rescues; up/out/down throws you out to test it (T-185)")


func _cmd(a: PackedStringArray) -> String:
	var p: Player = null
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		if (n as Player) != null and (n as Player).is_local:
			p = n as Player
	if p != null and a.size() > 0:
		match a[0]:
			"up":
				p.global_position.y = ceiling_y + 20.0
			"out":
				p.global_position.x = rect.end.x + 30.0
			"down":
				p.global_position.y = kill_y - 20.0
	return "bounds %s: kill %.1f, ceiling %.1f, rect %s, longest fall %.1f s; rescues %d %s" % ["on" if enabled else "off",
		kill_y, ceiling_y, str(rect), max_fall_s, rescues, str(by_reason)]


func _setup() -> void:
	await get_tree().physics_frame   # the navigation map syncs on the first physics frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	var base: Dictionary = (GLData.table("world") as Dictionary).get("play_bounds", {})
	var mcfg: Dictionary = {}
	var mid: Variant = _root.get("map_id") if _root != null else null
	if mid != null:
		var path: String = "res://data/gravelight/%s.json" % String(mid).get_slice("_", 0)
		if FileAccess.file_exists(path):
			mcfg = (GLData.load_json(path) as Dictionary).get("play_bounds", {})
	cfg = merged_cfg(base, mcfg)
	enabled = bool(cfg.get("enabled", true))
	check_s = maxf(0.05, float(cfg.get("check_s", 0.25)))
	off_nav_m = float(cfg.get("off_nav_m", 5.0))
	off_nav_s = float(cfg.get("off_nav_s", 2.0))
	_measure_nav()
	if not has_nav:
		# no navmesh (a test range): the spawn's height is the only floor we know
		var sp: Node3D = get_tree().get_first_node_in_group(&"player_spawns") as Node3D
		if sp == null:
			enabled = false
		else:
			nav_lo = sp.global_position
			nav_hi = sp.global_position
	var g: float = GameState.g_player()
	var jv: float = float((GLData.table("player") as Dictionary).get("jump_velocity", 4.2)) * GameState.jump_mult()
	var apex: float = jv * jv / (2.0 * maxf(0.5, g)) * 1.6 + 1.8   # a jump and a Skyhook hop, plus the body's height
	var d: Dictionary = derive(nav_lo, nav_hi, apex, _pad_top(g), g, cfg)
	kill_y = float(d["kill_y"])
	ceiling_y = float(d["ceiling_y"])
	rect = d["rect"] if has_nav or cfg.has("rect") else Rect2()
	max_fall_s = float(d["max_fall_s"])
	ready_done = true
	print("[bounds] %s: kill %.1f, ceiling %.1f, rect %s, longest fall %.1f s%s" % [str(mid), kill_y, ceiling_y,
		str(rect), max_fall_s, "" if enabled else " (off)"])


## The navmesh's extents over every region in the map (enabled or not), in world space.
func _measure_nav() -> void:
	has_nav = false
	var lo: Vector3 = Vector3(INF, INF, INF)
	var hi: Vector3 = Vector3(-INF, -INF, -INF)
	for n: Node in _root.find_children("*", "NavigationRegion3D", true, false):
		var r: NavigationRegion3D = n as NavigationRegion3D
		if r.navigation_mesh == null:
			continue
		var xf: Transform3D = r.global_transform
		for v: Vector3 in r.navigation_mesh.get_vertices():
			var w: Vector3 = xf * v
			lo = lo.min(w)
			hi = hi.max(w)
			has_nav = true
	if has_nav:
		nav_lo = lo
		nav_hi = hi


## The highest point a launch plate's arc reaches (JumpPad, map04d), -INF when the map has none.
func _pad_top(g: float) -> float:
	var top: float = -INF
	for n: Node in get_tree().get_nodes_in_group(&"jump_pads"):
		var pad: Node3D = n as Node3D
		if pad == null:
			continue
		var tgt: Vector3 = pad.get("target")
		var v: Vector3 = JumpPad.launch_velocity(pad.global_position, tgt, float(pad.get("flight_s")), g)
		top = maxf(top, pad.global_position.y + JumpPad.apex_height(v, g) + 1.8)
	return top


func bounds() -> Dictionary:
	return {"kill_y": kill_y, "ceiling_y": ceiling_y, "rect": rect, "max_fall_s": max_fall_s, "off_nav_s": off_nav_s}


func _physics_process(delta: float) -> void:
	if not ready_done or not enabled or not Net.is_authority():
		return
	_t -= delta
	if _t > 0.0:
		return
	var dt: float = check_s - _t
	_t = check_s
	if GameState.phase != GameState.Phase.PLAYING or GameState.has_flag(&"cutscene"):
		_st.clear()   # (a cutscene moves bodies where it likes: start fresh after it)
		return
	var has_zones: bool = not get_tree().get_nodes_in_group(&"zone_volumes").is_empty()
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and is_instance_valid(p) and p.is_inside_tree():
			check(p, dt, has_zones)


## One check of one body (host / solo). Returns the reason it was brought back, or &"".
func check(p: Player, dt: float, has_zones: bool = true) -> StringName:
	var pid: int = p.player_id
	var st: Dictionary = _st.get(pid, {})
	if _exempt(p):
		st["fall"] = 0.0
		st["off"] = 0.0
		_st[pid] = st
		return &""
	var owned: bool = p.is_local or p.is_bot   # a remote human's puppet: its floor and velocity are not simulated here
	var pos: Vector3 = p.global_position
	var on_floor: bool = owned and p.is_on_floor()
	var still_floor: bool = on_floor and p.get_platform_velocity().length() < 0.05
	# falling: off the floor and moving down
	if owned and not on_floor and p.velocity.y < -1.0 and p.air_grace_t <= 0.0:
		st["fall"] = float(st.get("fall", 0.0)) + dt
	else:
		st["fall"] = 0.0
	# the navmesh under the body (one query a check): the last safe floor, standing off the map
	var map_rid: RID = p.get_world_3d().navigation_map
	var near: Vector3 = NavigationServer3D.map_get_closest_point(map_rid, pos) if has_nav else pos
	var flat: float = Vector2(near.x - pos.x, near.z - pos.z).length()
	if still_floor and has_nav and off_nav_now(flat, off_nav_m, ZoneVolume.zone_at(get_tree(), pos + Vector3.UP * 0.2) != &"", has_zones):
		st["off"] = float(st.get("off", 0.0)) + dt
	else:
		st["off"] = 0.0
	if still_floor and has_nav and flat < 0.8 and absf(near.y - pos.y) < 1.2 and verdict(near, 0.0, 0.0, false, bounds()) == &"":
		st["safe"] = near
	elif still_floor and not has_nav and verdict(pos, 0.0, 0.0, false, bounds()) == &"":
		st["safe"] = pos
	_st[pid] = st
	var why: StringName = verdict(pos, float(st["fall"]), float(st["off"]) if owned else 0.0, p.downed or p.last_stand, bounds())
	if why == &"":
		return &""
	rescue(p, why)
	return why


## Never while the body is somewhere a set piece or a state put it on purpose.
func _exempt(p: Player) -> bool:
	if p.spectating or p.noclip or p.mantling or GameState.input_blocked:
		return true
	if (p.is_local or p.is_bot) and p.is_on_floor() and p.get_platform_velocity().length() >= 0.05:
		return true   # riding something that moves (a lift, a platform)
	for n: Node in get_tree().get_nodes_in_group(&"play_space"):
		if n.has_method("play_space_has") and bool(n.call("play_space_has", p)):
			return true
	return false


## Where `p` goes back to: the last safe floor, else the nearest navmesh point in its zone, else its spawn.
func target_for(p: Player) -> Dictionary:
	var st: Dictionary = _st.get(p.player_id, {})
	if st.has("safe"):
		return {"at": st["safe"] as Vector3, "how": "last_floor"}
	if has_nav:
		var map_rid: RID = p.get_world_3d().navigation_map
		var probe: Vector3 = p.global_position.clamp(nav_lo, nav_hi)
		var near: Vector3 = NavigationServer3D.map_get_closest_point(map_rid, probe)
		if near.is_finite() and verdict(near, 0.0, 0.0, false, bounds()) == &"":
			var zone: StringName = ZoneVolume.zone_at(get_tree(), near + Vector3.UP * 0.2)
			if zone == &"" or GameState.is_zone_open(zone):
				return {"at": near, "how": "navmesh"}
	if _root != null and _root.has_method("spawn_transform"):
		var xf: Transform3D = _root.call("spawn_transform", p.player_id)
		return {"at": xf.origin, "how": "spawn"}
	return {"at": p.global_position, "how": "none"}


## Brings `p` back down (host / solo decides; a remote human's owner moves its own body).
func rescue(p: Player, why: StringName) -> void:
	var tgt: Dictionary = target_for(p)
	var at: Vector3 = tgt["at"]
	var from: Vector3 = p.global_position
	rescues += 1
	rescues_total += 1
	by_reason[why] = int(by_reason.get(why, 0)) + 1
	history.append({"pid": p.player_id, "reason": String(why), "from": from, "to": at, "how": str(tgt["how"])})
	print("[bounds] P%d %s at %s: back down at %s (%s)" % [p.player_id, String(why), str(from.snapped(Vector3.ONE * 0.1)),
		str(at.snapped(Vector3.ONE * 0.1)), str(tgt["how"])])
	var st: Dictionary = _st.get(p.player_id, {})
	st["fall"] = 0.0
	st["off"] = 0.0
	_st[p.player_id] = st
	if p.is_local or p.is_bot:
		place(p, at)
	else:
		Net.mirror(self, &"_net_rescue", [p.player_id, at])


## On the body's owner: put it down at `at`, still, with a short fade for the local human.
func place(p: Player, at: Vector3) -> void:
	p.global_position = at + Vector3.UP * 0.05
	p.velocity = Vector3.ZERO
	p.set("_push_t", 0.0)
	p.set("_push_v", Vector3.ZERO)
	p.set("_lunge_t", 0.0)
	p.air_grace_t = 0.0
	if p.is_local and not p.is_bot:
		_flash()


## A client: the host brought this peer's player back.
func _net_rescue(pid: int, at: Vector3) -> void:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.player_id == pid and p.is_local:
			place(p, at)


## A quick dip to black and back (0.1 s in, 0.45 s out): the body is put down, not teleported in front of you.
func _flash() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _fade == null:
		var layer: CanvasLayer = CanvasLayer.new()
		layer.layer = 90
		add_child(layer)
		_fade = ColorRect.new()
		_fade.color = Color(0, 0, 0, 0)
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(_fade)
	var tw: Tween = _fade.create_tween()
	tw.tween_property(_fade, "color:a", 0.9, 0.1)
	tw.tween_interval(0.12)
	tw.tween_property(_fade, "color:a", 0.0, 0.45)
