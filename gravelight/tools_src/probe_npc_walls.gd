class_name NpcWallProbe
extends Node
## T-143 probe: NPCs and bots pressed against a wall. Loads a map, runs it N game minutes at a time scale with the
## human on player bot mode (god mode), N squad bots and every map companion in the match, and watches every body
## that walks on its own (squad bots, the bot-driven human, Jakub, the map companions) once a game second:
##   pressed = it WANTS to move (the move intent was above 0.3 for 80% of the last 3 s), it went less than 0.05 m in
##   those 3 s, and a wall (physics layer 1) is within 0.4 m of its edge in the intent direction (a sphere cast at
##   knee and chest height).
## Each offender prints once with its position, zone, locomotion mode, goal and stuck ladder; the report keeps the
## longest pressed run per body. Also checks the walkers that have no collider (the Inn survivors upstairs): the
## walk from the hiding place to the post must keep 0.3 m of air around the walker, and every idle spot (survivor
## hide/post, companion and extra-people spots) must sit on the navmesh with 0.3 m of clearance.
## Headless: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/probe_npc_walls.tscn \
##   [-- --map=map01 --minutes=4 --speed=4 --bots=3 --no-companions]
## Prints "[npc-walls] ..." lines and "[npc-walls] RESULT: PASS/FAIL (n pressed)"; exit code = number of offenders > 0.

const SCENES: Dictionary = {
	"map00": "res://gravelight/maps/map00_crossroads/map00.tscn",
	"map01": "res://gravelight/maps/map01_kaltenbrunn/map01.tscn",
	"map02": "res://gravelight/maps/map02_totenhafen/map02.tscn",
	"map04a": "res://gravelight/maps/map04_fernflug/map04a.tscn",
	"map04b": "res://gravelight/maps/map04_fernflug/map04b.tscn",
	"map04c": "res://gravelight/maps/map04_fernflug/map04c.tscn",
	"map04d": "res://gravelight/maps/map04_fernflug/map04d.tscn",
}
const WINDOW_S: float = 3.0
const SAMPLE_S: float = 0.25
const MOVE_EPS_M: float = 0.05
const WALL_M: float = 0.4
const BODY_R: float = 0.4
const INTENT_MIN: float = 0.3
const INTENT_FRAC: float = 0.8
const CLEAR_R: float = 0.3

var map_name: String = "map00"
var minutes: float = 4.0
var speed: float = 4.0
var bots: int = 3
var companions: bool = true
var spots_arg: String = ""   # --spots=x,y,z;x,y,z : print the navmesh answer for each point and stop
var scan_arg: String = ""    # --scan=x0,z0,x1,z1,step,y : print the walkable grid (clearance-checked) and stop
var standalone: bool = false
var map: MapRoot = null
var offenders: Array[Dictionary] = []   # the pressed bodies (first detection each)
var longest: Dictionary = {}             # body name -> longest pressed run in seconds
var static_issues: PackedStringArray = []
var watched: Dictionary = {}             # body name -> true
var finished: bool = false
var _hist: Dictionary = {}               # body name -> Array of [pos, intent_len, wish dir]
var _t: float = 0.0
var _acc: float = 0.0
var _run_s: Dictionary = {}              # body name -> current pressed run (s)
var _flagged: Dictionary = {}


static func scene_for(name: String) -> String:
	return str(SCENES.get(name, ""))


func _ready() -> void:
	if get_parent() == get_tree().root and get_tree().current_scene == self:
		standalone = true
	if standalone:
		for a: String in OS.get_cmdline_user_args():
			if a.begins_with("--map="):
				map_name = a.substr(6)
			elif a.begins_with("--minutes="):
				minutes = float(a.substr(10))
			elif a.begins_with("--speed="):
				speed = float(a.substr(8))
			elif a.begins_with("--bots="):
				bots = int(a.substr(7))
			elif a == "--no-companions":
				companions = false
			elif a.begins_with("--spots="):
				spots_arg = a.substr(8)
			elif a.begins_with("--scan="):
				scan_arg = a.substr(7)
		run.call_deferred()


## Runs one map to the end; fills `offenders` / `static_issues`; quits the tree when standalone.
func run() -> void:
	ProfileSave.path = "user://_qa_npcwalls_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_npcwalls_settings.cfg"
	GLSettings.values["bot_local_ai"] = false
	GLSettings.values["homage_bosses"] = false
	GameState.bot_count = bots
	GameState.bot_ai_mode = "off" if bots <= 0 else "squad"
	GameState.character_id = &"peg"
	GameState.god_mode = true
	Campaign.reset()
	GLVO.always_pass_chance = true
	var path: String = scene_for(map_name)
	if path == "":
		print("[npc-walls] unknown map %s" % map_name)
		_end(2)
		return
	map = (load(path) as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child(map)
	get_tree().current_scene = map
	var guard: float = 0.0
	while (map.player == null or not map.player.is_inside_tree()) and guard < 40.0:
		await get_tree().process_frame
		guard += 0.016
	for i: int in 90:
		await get_tree().physics_frame
	GameState.god_mode = true
	var pb: PlayerBot = PlayerBot.of(get_tree())
	if pb != null and not pb.is_on():
		pb.set_on(true, "npc_wall_probe")
	_static_checks()
	if spots_arg != "" or scan_arg != "":
		_query_tools()
		_end(0)
		return
	Engine.time_scale = speed
	var end_t: float = minutes * 60.0
	var joined: bool = false
	while _t < end_t and is_instance_valid(map):
		await get_tree().physics_frame
		var dt: float = get_physics_process_delta_time()
		_t += dt
		_acc += dt
		GameState.god_mode = true
		if companions and not joined and _t > 6.0:
			joined = true
			_join_companions()
		if _acc >= SAMPLE_S:
			_acc = 0.0
			_sample()
	Engine.time_scale = 1.0
	_report()
	_end(offenders.size())


func _end(code: int) -> void:
	finished = true
	if standalone:
		get_tree().quit(code)


## The companions join where the human stands (a recruit happens beside you: their zone may be shut to the walk).
func _join_companions() -> void:
	var h: Player = map.player
	for c: MapCompanion in MapCompanion.instances(get_tree()):
		if c.state == MapCompanion.State.WAITING and c.player != null:
			c._join(1, false)
			c._cmd(PackedStringArray(["tp"]))
			print("[npc-walls] %s joins the match" % c.id)
	var jk: JakubCompanion = JakubCompanion.instance(get_tree())
	if jk != null:
		jk._cmd(PackedStringArray(["join"]))
		if jk.player != null and h != null and jk.state == JakubCompanion.State.JOINED:
			jk.player.global_position = h.global_position + h.global_basis.z * 2.0
		print("[npc-walls] Jakub: %s" % jk.state_name())


## --spots / --scan: the navmesh answer for chosen points (how the people's places are picked).
func _query_tools() -> void:
	var nm: RID = map.get_world_3d().navigation_map
	if spots_arg != "":
		for part: String in spots_arg.split(";"):
			var f: PackedStringArray = part.split(",")
			if f.size() < 3:
				continue
			var p: Vector3 = Vector3(float(f[0]), float(f[1]), float(f[2]))
			var c: Vector3 = NavigationServer3D.map_get_closest_point(nm, p)
			print("[npc-walls] SPOTQ raw point hits: %s" % str(clearance_hits(p)))
			var rq: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(c + Vector3.UP * 1.0, c + Vector3.DOWN * 3.0, 1)
			var rh: Dictionary = map.get_world_3d().direct_space_state.intersect_ray(rq)
			print("[npc-walls] SPOTQ %s -> nav %s floor_y=%s (off %.2f up %.2f) clearance_hit=%s zone=%s" % [str(p), str(c.snapped(Vector3.ONE * 0.01)),
				("%.2f" % (rh["position"] as Vector3).y) if not rh.is_empty() else "none",
				Vector2(c.x - p.x, c.z - p.z).length(), c.y - p.y, str(_clearance_hit(c)) + (" " + str(clearance_hits(c)) if _clearance_hit(c) else ""), String(ZoneVolume.zone_at(get_tree(), c))])
	if scan_arg != "":
		var g: PackedStringArray = scan_arg.split(",")
		var x0: float = float(g[0])
		var z0: float = float(g[1])
		var x1: float = float(g[2])
		var z1: float = float(g[3])
		var st: float = float(g[4])
		var y: float = float(g[5])
		var z: float = z0
		while z <= z1:
			var row: String = ""
			var x: float = x0
			while x <= x1:
				var c2: Vector3 = NavigationServer3D.map_get_closest_point(nm, Vector3(x, y, z))
				var ok: bool = Vector2(c2.x - x, c2.z - z).length() < 0.15 and absf(c2.y - y) < 1.2
				row += ("o" if not _clearance_hit(c2) else "+") if ok else "."
				x += st
			print("[npc-walls] SCAN z=%6.1f %s" % [z, row])
			z += st


# ================================================================== the bodies

func _walkers() -> Array[Player]:
	var out: Array[Player] = []
	for g: StringName in [&"players", &"bots", &"companions"]:
		for n: Node in get_tree().get_nodes_in_group(g):
			var p: Player = n as Player
			if p != null and not out.has(p):
				out.append(p)
	return out


func _intent(p: Player) -> Vector3:
	var mi: Variant = p.get("_mi")
	if mi == null:
		return Vector3.ZERO
	var m: Vector2 = (mi as MoveIntent).move
	var w: Vector3 = p.global_basis * Vector3(m.x, 0, m.y)
	w.y = 0.0
	return w


func _sample() -> void:
	for p: Player in _walkers():
		if not is_instance_valid(p) or p.downed or p.spectating:
			continue
		var key: String = String(p.name) + "#" + str(p.player_id)
		watched[key] = true
		var h: Array = _hist.get(key, [])
		var w: Vector3 = _intent(p)
		h.append([p.global_position, w.length(), w])
		var n_keep: int = int(WINDOW_S / SAMPLE_S) + 1
		while h.size() > n_keep:
			h.pop_front()
		_hist[key] = h
		if h.size() < n_keep:
			continue
		var wanting: int = 0
		var dir: Vector3 = Vector3.ZERO
		for s: Array in h:
			if float(s[1]) >= INTENT_MIN:
				wanting += 1
				dir += (s[2] as Vector3)
		var moved: float = Vector2(p.global_position.x - (h[0][0] as Vector3).x, p.global_position.z - (h[0][0] as Vector3).z).length()
		var pressed: bool = float(wanting) / float(h.size()) >= INTENT_FRAC and moved < MOVE_EPS_M and _wall_ahead(p, dir)
		if pressed:
			_run_s[key] = float(_run_s.get(key, 0.0)) + SAMPLE_S
			longest[key] = maxf(float(longest.get(key, 0.0)), WINDOW_S + float(_run_s[key]))
			if not _flagged.has(key):
				_flagged[key] = true
				var o: Dictionary = _describe(p, key, dir)
				offenders.append(o)
				print("[npc-walls] PRESSED %s" % str(o["text"]))
		else:
			_run_s[key] = 0.0


func _wall_ahead(p: Player, dir: Vector3) -> bool:
	if dir.length() < 0.01:
		return false
	var d: Vector3 = dir.normalized()
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	for hgt: float in [0.45, 1.1]:
		var sh: SphereShape3D = SphereShape3D.new()
		sh.radius = 0.1
		var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		q.shape = sh
		q.transform = Transform3D(Basis.IDENTITY, p.global_position + Vector3.UP * hgt)
		q.motion = d * (BODY_R + WALL_M)
		q.collision_mask = 1
		q.exclude = [p.get_rid()]
		var r: PackedFloat32Array = space.cast_motion(q)
		if r.size() >= 2 and r[0] < 1.0:
			return true
	return false


func _describe(p: Player, key: String, dir: Vector3) -> Dictionary:
	var pos: Vector3 = p.global_position
	var zone: String = String(ZoneVolume.zone_at(get_tree(), pos))
	var mode: String = "-"
	var goal: String = "-"
	var ladder: String = "-"
	var action: String = "-"
	var brain: BotBrain = _brain_of(p)
	if brain != null:
		action = brain.action
		var lo: Variant = brain.loco
		if lo != null:
			mode = str(lo.get("mode"))
			var g: Variant = lo.get("_goal")
			goal = str((g as Vector3).snapped(Vector3.ONE * 0.1)) if g is Vector3 and g != Vector3.INF else "none"
			ladder = "no_prog %.1fs stage %s" % [float(lo.get("_no_prog_t")), str(lo.get("_stage_done"))]
	var nav: String = "off"
	var nm: RID = p.get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(nm) > 0:
		var c: Vector3 = NavigationServer3D.map_get_closest_point(nm, pos)
		nav = "%.2fm from the navmesh" % pos.distance_to(c)
	var txt: String = "%s at %s zone=%s action=%s loco=%s goal=%s %s heading=%s nav=%s t=%.0fs" % [key, str(pos.snapped(Vector3.ONE * 0.1)),
		zone, action, mode, goal, ladder, str(dir.normalized().snapped(Vector3.ONE * 0.1)), nav, _t]
	return {"key": key, "pos": pos, "zone": zone, "text": txt}


func _brain_of(p: Player) -> BotBrain:
	if map == null or map.squad == null:
		return null
	if map.squad.player_bot != null and map.squad.player_bot.player == p:
		return map.squad.player_bot
	for b: BotBrain in map.squad.brains:
		if b.player == p:
			return b
	return null


# ================================================================== the bodies with no collider and the idle spots

## A spot's navmesh distance and wall clearance, as a text when it is bad ("" when fine).
func spot_issue(label: String, p: Vector3) -> String:
	var nm: RID = map.get_world_3d().navigation_map
	var c: Vector3 = NavigationServer3D.map_get_closest_point(nm, p)
	var off: float = Vector2(c.x - p.x, c.z - p.z).length()
	var up: float = absf(c.y - p.y)
	var msg: String = ""
	if off > 0.6 or up > 1.0:
		msg = "%s at %s is %.2fm (up %.2f) from the navmesh" % [label, str(p), off, up]
	elif _clearance_hit(c):
		msg = "%s at %s has a wall within %.1fm" % [label, str(p), CLEAR_R]
	return msg


## The floor under a point (a ray down from 0.8 above to 1.2 below; the point's own y when there is none).
func _floor_y(at: Vector3) -> float:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.8, at + Vector3.DOWN * 1.2, 1)
	var hit: Dictionary = map.get_world_3d().direct_space_state.intersect_ray(q)
	return (hit["position"] as Vector3).y if not hit.is_empty() else at.y


## What a walker standing at `at` (a floor point or a navmesh point) would be in: collider paths, with a 0.3 m body at
## knee and chest height over the floor (the --spots tool prints them).
func clearance_hits(at: Vector3) -> PackedStringArray:
	var out: PackedStringArray = []
	var space: PhysicsDirectSpaceState3D = map.get_world_3d().direct_space_state
	var fy: float = _floor_y(at)
	for hgt: float in [0.5, 1.1]:
		var sh: SphereShape3D = SphereShape3D.new()
		sh.radius = CLEAR_R
		var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		q.shape = sh
		q.transform = Transform3D(Basis.IDENTITY, Vector3(at.x, fy + hgt, at.z))
		q.collision_mask = 1
		for r: Dictionary in space.intersect_shape(q, 4):
			var c: Object = r.get("collider")
			out.append("%.1f:%s" % [hgt, str((c as Node).get_path()) if c is Node else str(c)])
	return out


func _clearance_hit(at: Vector3) -> bool:
	return not clearance_hits(at).is_empty()


## Samples a nav path every 0.25 m and returns the first point where the walker (0.3 m round) would be in a wall.
func path_clip(from: Vector3, to: Vector3) -> String:
	var nm: RID = map.get_world_3d().navigation_map
	var path: PackedVector3Array = NavigationServer3D.map_get_path(nm, from, to, true)
	if path.size() < 2:
		return ""
	path.append(to)
	var raw_path: PackedVector3Array = path
	path = InnSurvivor.shape_path(map.get_world_3d().direct_space_state, path)   # (the walk the survivors really take)
	if OS.get_cmdline_user_args().has("--debug-paths"):
		print("[npc-walls] PATH raw %s" % str(Array(raw_path).map(func(v: Vector3) -> Vector3: return v.snapped(Vector3.ONE * 0.01))))
		print("[npc-walls] PATH shaped %s" % str(Array(path).map(func(v: Vector3) -> Vector3: return v.snapped(Vector3.ONE * 0.01))))
	for i: int in path.size() - 1:
		var a: Vector3 = path[i]
		var b: Vector3 = path[i + 1]
		var n: int = maxi(1, int(a.distance_to(b) / 0.25))
		for k: int in n + 1:
			var at: Vector3 = a.lerp(b, float(k) / float(n))
			if _clearance_hit(at):
				return "the walk clips a wall near %s" % str(at.snapped(Vector3.ONE * 0.1))
	return ""


func _static_checks() -> void:
	var ss: Node = map.find_child("InnSurvivors", true, false)
	if ss != null:
		var cfg: Dictionary = InnSurvivors.load_cfg()
		for row: Variant in cfg.get("survivors", []):
			var r: Dictionary = row
			var hide: Array = r.get("hide", [0, 0, 0])
			var post: Array = r.get("post", [0, 0, 0])
			var h: Vector3 = Vector3(float(hide[0]), float(hide[1]), float(hide[2]))
			var po: Vector3 = Vector3(float(post[0]), float(post[1]), float(post[2]))
			for pair: Array in [["survivor %s hide" % r["id"], h], ["survivor %s post" % r["id"], po]]:
				var m: String = spot_issue(str(pair[0]), pair[1])
				if m != "":
					static_issues.append(m)
			var clip: String = path_clip(h, po)
			if clip != "":
				static_issues.append("survivor %s %s" % [r["id"], clip])
	_stand_checks()
	for c: MapCompanion in MapCompanion.instances(get_tree()):
		var a: Array = c.cfg.get("spot", [0, 0, 0])
		var m2: String = spot_issue("companion %s spot" % c.id, Vector3(float(a[0]), float(a[1]), float(a[2])))
		if m2 != "":
			static_issues.append(m2)
	for sp: Vector3 in ExtraPeople.spots_for(String(map.map_id)):
		var m3: String = spot_issue("extra person spot", sp)
		if m3 != "":
			static_issues.append(m3)


## Where a bot stands to use each thing (BotBrain.stand_point): there must be a place, on the floor, with a clear line
## to the thing's use box (a wall-buy behind a bench, a spot behind a post: the bot walks up to the wall and waits).
func _stand_checks() -> void:
	if map.squad == null or map.squad.brains.is_empty():
		return
	var brain: BotBrain = map.squad.brains[0]
	var space: PhysicsDirectSpaceState3D = map.get_world_3d().direct_space_state
	for n: Node in map.find_children("*", "Interactable", true, false):
		var it: Interactable = n as Interactable
		if it == null or it.area == null or it.area.collision_layer == 0 or it is ExtraPerson.ExtraTalk or it is ExtraPerson.FavourItem:
			continue
		if not (it is WallBuy or it is BuyDoor or it is AmmoBox or it is MysteryCrate):
			continue
		var st: Vector3 = brain.stand_point(it)
		if st == Vector3.INF:
			continue   # (no stand point from where the bot is now: a shut door, not a fault)
		var target: Vector3 = it.global_position + it.interact_offset
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(st + Vector3.UP * 1.4, target, 1)
		q.exclude = []
		for b: Node in it.find_children("*", "CollisionObject3D", true, false):
			q.exclude.append((b as CollisionObject3D).get_rid())
		var hit: Dictionary = space.intersect_ray(q)
		var d: float = Vector2(st.x - target.x, st.z - target.z).length()
		if not hit.is_empty() and hit["collider"] is Node and it.is_ancestor_of(hit["collider"] as Node):
			hit = {}   # (its own body is what we are looking at)
		if not hit.is_empty() and (it is WallBuy or it is AmmoBox):
			static_issues.append("%s at %s: its stand point %s is walled off from it by %s" % [it.name, str(it.global_position.snapped(Vector3.ONE * 0.1)),
				str(st.snapped(Vector3.ONE * 0.1)), str((hit["collider"] as Node).get_path()) if hit["collider"] is Node else "?"])
		elif _clearance_hit(st) and d < 1.6 and (it is WallBuy or it is AmmoBox):
			static_issues.append("%s at %s: its stand point %s is against %s" % [it.name, str(it.global_position.snapped(Vector3.ONE * 0.1)),
				str(st.snapped(Vector3.ONE * 0.1)), str(clearance_hits(st))])


func _report() -> void:
	print("[npc-walls] %s: %.0f game s at x%.0f, %d bots, %d bodies watched" % [map_name, _t, speed, bots, watched.size()])
	for k: String in longest.keys():
		print("[npc-walls] longest pressed run %s: %.1fs" % [k, float(longest[k])])
	for m: String in static_issues:
		print("[npc-walls] SPOT %s" % m)
	var n: int = offenders.size() + static_issues.size()
	print("[npc-walls] RESULT: %s (%s: %d pressed, %d spot issues)" % ["PASS" if n == 0 else "FAIL", map_name, offenders.size(), static_issues.size()])
