extends RefCounted
## The interactables' facing check (UPDATE 13 Part 3, DECISIONS T-219): does each interactable's front face the open,
## walkable side players walk up from, and can a player standing on the navmesh reach its interaction area?
## Works from the scene file alone (nothing's _ready runs, no physics, no NavigationServer): the baked navmesh
## polygons of every NavigationRegion3D and every BoxShape3D collider (oriented boxes) are read from the
## instantiated scene, like tools_src/crucible_survey.gd. Used by tools/tests/test_interactable_facing.gd (the map
## runner) and gravelight/tests/unit/test_interactable_facing.gd (the pure classification).
## (No class_name: callers preload it, so a fresh checkout works before the editor rebuilds its class cache.)
##
## For each interactable: its world front (basis * the script's front axis; most scripts face local -Z), then for
## the four turns of the node (0 = as placed, 180, +90, -90) the "openness" of that side: the share of 15 sample
## points (3 distances x 5 lateral offsets, 0.8-1.8 m past the body's front face) that lie on the navmesh at the
## object's floor and that a straight line at chest height from the body's face reaches without crossing a collider
## box; plus which sides have a wall within WALL_GAP and how far the wall behind would be after each turn.
## classify() turns them into a verdict:
##   OK          the front side is open (or the back is on its wall and the front is a narrow walkable strip)
##   BACKWARDS   the front is blocked, the back is clearly the open side (or the front is on a wall)
##   SIDEWAYS    the front is blocked and a side is clearly open, or a wall-backed object stands with its flank
##               on a wall and its back in the open
##   UNSURE      no side is clearly right (a niche, a free-standing post with a narrow front)
##   UNREACHABLE no player standing on the navmesh can reach the interaction area
## Objects with no front (doors, carried parts, round consoles, quest props: kind "omni"/"door") are only checked
## for reach; windows (barricades) are layout and only listed. The suggested yaw turns the front to the open side,
## one with a wall behind first, the plain about-turn on a near tie. Also built at load and checked here: the bank
## counter (bank.json) and the campaign exfil beacon (the map json's "exfil").

const INTERACTABLE_SCRIPT: String = "res://gravelight/world/interactable.gd"

## Per script file: kind ("faced" = has a front, "omni" = usable from any side, "door"), the front axis in local
## space, how far the body reaches forward (f) and back (b) from the origin, its half width (w), whether its back is
## meant to sit against a wall (wall), the interaction box (isize, ioff: the script's _ready values; perk machines and
## doors size theirs at runtime, these are the usual), and lock = never suggest a turn (the Crucible: the owner said
## it is right).
const RULES: Dictionary = {
	"perk_machine.gd": {"kind": "faced", "f": 0.5, "b": 0.5, "w": 0.6, "wall": true, "isize": Vector3(1.3, 1.8, 0.25), "ioff": Vector3(0, 1.0, -0.62)},
	"wall_buy.gd": {"kind": "faced", "hang": 1.5, "f": 0.12, "b": 0.0, "w": 0.7, "wall": true, "isize": Vector3(1.4, 0.9, 0.22), "ioff": Vector3(0, 0, -0.12)},
	"ammo_box.gd": {"kind": "faced", "f": 0.3, "b": 0.3, "w": 0.5, "wall": true, "isize": Vector3(1.25, 1.0, 0.95), "ioff": Vector3(0, 0.5, -0.12)},
	"mystery_crate.gd": {"kind": "faced", "f": 0.4, "b": 0.4, "w": 0.75, "wall": true, "isize": Vector3(1.6, 1.1, 0.3), "ioff": Vector3(0, 0.55, -0.45)},
	"crucible.gd": {"kind": "faced", "f": 0.8, "b": 0.8, "w": 1.0, "wall": false, "lock": true, "isize": Vector3(2.2, 2.0, 0.3), "ioff": Vector3(0, 1.0, -0.95)},
	# T-263: the arms locker stands with its back (the origin) on the wall, the doors 0.45 m out at -Z
	"weapon_locker.gd": {"kind": "faced", "f": 0.45, "b": 0.0, "w": 0.46, "wall": true, "isize": Vector3(1.22, 1.8, 0.3), "ioff": Vector3(0, 1.0, -0.55)},
	"armorers_bench.gd": {"kind": "faced", "f": 0.72, "b": 0.0, "w": 0.75, "wall": true, "isize": Vector3(1.6, 1.3, 0.9), "ioff": Vector3(0, 1.0, -0.4)},
	"power_switch.gd": {"kind": "faced", "f": 0.3, "b": 0.05, "w": 0.6, "wall": true, "isize": Vector3(1.8, 1.8, 0.9), "ioff": Vector3(0, 1.0, -0.3)},
	"aux_bus.gd": {"kind": "faced", "f": 0.3, "b": 0.05, "w": 0.6, "wall": true, "isize": Vector3(1.8, 1.8, 0.9), "ioff": Vector3(0, 1.0, -0.3)},
	"trap_lever.gd": {"kind": "faced", "f": 0.2, "b": 0.0, "w": 0.3, "wall": true, "isize": Vector3(0.7, 1.0, 0.3), "ioff": Vector3(0, 1.1, -0.15)},
	"switchboard.gd": {"kind": "faced", "f": 0.3, "b": 0.05, "w": 1.1, "wall": true, "isize": Vector3(2.2, 1.6, 0.3), "ioff": Vector3(0, 1.1, -0.2)},
	# the bench itself is map geometry running from the node toward local +Z (Workbench.build_greybox): the body is
	# the back, the player stands at -Z
	"workbench.gd": {"kind": "faced", "f": 0.05, "b": 0.05, "w": 1.0, "wall": true, "isize": Vector3(2.0, 1.2, 0.3), "ioff": Vector3(0, 0.9, -0.45)},
	"jukebox.gd": {"kind": "faced", "f": 0.35, "b": 0.31, "w": 0.5, "wall": true, "isize": Vector3(1.1, 1.7, 0.9), "ioff": Vector3(0, 0.85, -0.2)},
	# the heater cabinet and the vent lever's plate sit behind their origin (local +Z, on the wall), their lever,
	# lamp and label in front (-Z): the front is -Z, the body is the back
	"heater_switch.gd": {"kind": "faced", "f": 0.08, "b": 0.24, "w": 0.6, "wall": true, "isize": Vector3(1.4, 1.8, 0.8), "ioff": Vector3(0, 1.2, 0.3)},
	"shaft_grate_lever.gd": {"kind": "faced", "f": 0.12, "b": 0.2, "w": 0.4, "wall": true, "isize": Vector3(1.2, 1.8, 0.8), "ioff": Vector3(0, 1.2, 0.3)},
	# the Account console's screen and key face local +Z
	"account_console.gd": {"kind": "faced", "axis": Vector3(0, 0, 1), "f": 0.45, "b": 0.4, "w": 1.0, "wall": false, "isize": Vector3(2.2, 1.8, 1.6), "ioff": Vector3(0, 0.9, 0.4)},
	# the Kranich's hull breach plates sit in the wing wall, the cabin side on local +Z (their light, the wind)
	"breach_panel.gd": {"kind": "faced", "axis": Vector3(0, 0, 1), "f": 0.15, "b": 0.15, "w": 1.1, "wall": false, "isize": Vector3(2.4, 2.2, 0.9), "ioff": Vector3(0, 1.1, 0)},
	"quest_note.gd": {"kind": "omni", "hang": 0.6, "isize": Vector3(0.6, 0.5, 0.5), "ioff": Vector3.ZERO},
	"barricade.gd": {"kind": "window", "isize": Vector3(1.6, 1.3, 0.6), "ioff": Vector3(0, 1.5, 0)},
	"door.gd": {"kind": "door", "isize": Vector3(2.2, 2.4, 0.55), "ioff": Vector3(0, 1.2, 0)},
	"breach_door.gd": {"kind": "door", "isize": Vector3(2.2, 2.4, 0.55), "ioff": Vector3(0, 1.2, 0)},
}
## Every other Interactable: usable from any side (its interact box, the script's defaults when unknown).
const OMNI: Dictionary = {"kind": "omni", "isize": Vector3(1.2, 1.6, 0.6), "ioff": Vector3(0, 0.8, 0)}
## The campaign exfil beacon (ExfilPoint, spawned at load from the map json's "exfil"): a post, local -Z the front.
const EXFIL_RULE: Dictionary = {"kind": "faced", "f": 0.2, "b": 0.2, "w": 0.4, "wall": false, "isize": Vector3(1.1, 2.6, 0.7), "ioff": Vector3(0.3, 1.3, 0)}
## The bank counter (bank.json "branches", built at load by MapRoot): +z is the customers' side.
const BANK_RULE: Dictionary = {"kind": "faced", "axis": Vector3(0, 0, 1), "f": 0.3, "b": 1.9, "w": 2.3, "wall": false, "isize": Vector3(2.0, 1.4, 0.6), "ioff": Vector3(0, 1.1, 0.2)}

const TURNS: Array = [0.0, 180.0, 90.0, -90.0]
## `-- --debug=<name>` on the command line prints every sample of that interactable.
static func debug_name() -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--debug="):
			return a.substr(8)
	return ""
const SAMPLE_D: Array = [0.8, 1.3, 1.8]   # metres past the body's front face
const LATERAL: Array = [-0.6, -0.3, 0.0, 0.3, 0.6]
const OPEN_MIN: float = 0.5                  # a side with at least this share of open samples is "open"
const CLEAR_MIN: float = 0.66                # the side a turn would face must be at least this open...
const CLEAR_MARGIN: float = 0.34             # ...and this much more open than the front
const NAV_DY: float = 0.45                   # a navmesh polygon counts at the object's floor within this height
const FREE_SHUT: float = 0.2                 # a free-standing object's front this open or less counts as shut
const FLIP_TIE: float = 0.3                 # an about-turn this close to the most open choice is preferred
const BACK_MAX: float = 0.9                 # a collider this close behind the back face is the wall it stands on
const WALL_GAP: float = 0.35                # a collider this close to the body's face counts as a wall on that side
const CHEST: float = 1.1                    # line-of-sight height above the floor
const EYE: float = 1.65
const REACH: float = 2.3                     # Player.INTERACT_RANGE
const NEAR: float = 4.5                      # geometry within this many metres (plan) of an object is considered


static func gxf(n: Node) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var cur: Node = n
	while cur != null:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


static func wrap_yaw(y: float) -> float:
	var r: float = fposmod(y + 180.0, 360.0) - 180.0
	if is_equal_approx(r, -180.0):
		r = 180.0
	return snappedf(r, 0.01)


## The verdict from the openness of the four turns ({0.0: front, 180.0: back, 90.0: the side a +90 turn faces,
## -90.0}: the share of open samples a front facing that way would have), `walls` (the same keys: a collider within
## WALL_GAP of the body's face on that side as placed), `behind` (the same keys: metres from the body's back face to
## the nearest collider behind it if the front faced that way; INF = none within 1.5 m), reach (can a player reach the
## interaction area from the front, or from any side for an object without one), the kind, `locked` (never suggest
## a turn: the Crucible) and `wall_backed` (the object belongs with its back on a wall). Pure: the unit test drives it.
## Returns {verdict, turn (the yaw change to suggest, 0 = none), best (the turn the object should have)}.
##   A faced object is OK when its front is open and, if it belongs on a wall, its back is on one or no other open
##   side would put it there. Else the clearly open side (CLEAR_MIN, CLEAR_MARGIN more open than the front) wins,
##   one with a wall behind first: BACKWARDS (180) or SIDEWAYS (+-90). A front face touching a wall with any open
##   side elsewhere is turned the same way. Anything else is UNSURE (or UNREACHABLE without reach).
static func classify(kind: String, open: Dictionary, walls: Dictionary, reachable: bool, locked: bool = false, wall_backed: bool = true,
		behind: Dictionary = {}) -> Dictionary:
	var fo: float = float(open.get(0.0, 0.0))
	var best_t: float = _pick(open, behind, wall_backed, [0.0, 180.0, 90.0, -90.0], 0.0)
	if kind == "window":
		return {"verdict": "LAYOUT", "turn": 0.0, "best": best_t}
	if kind != "faced":
		return {"verdict": "OK" if reachable else "UNREACHABLE", "turn": 0.0, "best": best_t}
	var clear: Array = []
	for t: float in [180.0, 90.0, -90.0]:
		var o: float = float(open.get(t, 0.0))
		# a free-standing object (no wall wanted) is only turned when its front is shut, not merely narrower
		if o >= CLEAR_MIN and o - fo >= CLEAR_MARGIN and (wall_backed or fo < FREE_SHUT):
			clear.append(t)
	if fo >= OPEN_MIN:
		# open in front; a wall-backed object with no wall behind while another clearly open side has one stands
		# along the wall (its flank on it): turn its back to the wall
		if wall_backed and not _backed(behind, 0.0) and not bool(walls.get(0.0, false)):
			for t2: float in [180.0, 90.0, -90.0]:
				if float(open.get(t2, 0.0)) >= CLEAR_MIN and _backed(behind, t2):
					var p: float = _pick(open, behind, wall_backed, [180.0, 90.0, -90.0], -1.0, CLEAR_MIN)
					return {"verdict": "BACKWARDS" if p == 180.0 else "SIDEWAYS", "turn": 0.0 if locked else p, "best": p}
		return {"verdict": "OK" if reachable else "UNREACHABLE", "turn": 0.0, "best": 0.0}
	# back on its wall, front onto a narrow but walkable strip (a bay aisle, a nook) and in reach: right as it is
	if wall_backed and fo > 0.0 and bool(walls.get(180.0, false)) and not bool(walls.get(0.0, false)):
		return {"verdict": "OK" if reachable else "UNREACHABLE", "turn": 0.0, "best": 0.0}
	if not clear.is_empty():
		var p2: float = _pick(open, behind, wall_backed, clear, clear[0])
		return {"verdict": "BACKWARDS" if p2 == 180.0 else "SIDEWAYS", "turn": 0.0 if locked else p2, "best": p2}
	# the front face is against a wall and another side is free and open, if only a little (a narrow aisle between
	# the wall and a rack): it stands the wrong way round
	if bool(walls.get(0.0, false)):
		var free: Array = []
		for t3: float in [180.0, 90.0, -90.0]:
			if float(open.get(t3, 0.0)) > 0.0 and not bool(walls.get(t3, false)):
				free.append(t3)
		if not free.is_empty():
			var p3: float = _pick(open, behind, wall_backed, free, free[0])
			return {"verdict": "BACKWARDS" if p3 == 180.0 else "SIDEWAYS", "turn": 0.0 if locked else p3, "best": p3}
	return {"verdict": "UNSURE" if reachable else "UNREACHABLE", "turn": 0.0, "best": best_t}


## BACK_MAX: a collider this close behind the back face counts as the wall the object stands against.
static func _backed(behind: Dictionary, t: float) -> bool:
	return float(behind.get(t, INF)) <= BACK_MAX


## Of `turns`, the most open one with a wall behind (wall-backed objects), else the most open; ties keep the order.
## Only turns at least `min_open` open count; `fallback` when none does.
static func _pick(open: Dictionary, behind: Dictionary, wall_backed: bool, turns: Array, fallback: float, min_open: float = 0.0) -> float:
	var best: float = fallback
	var best_o: float = -1.0
	if wall_backed:
		for t: float in turns:
			var o: float = float(open.get(t, 0.0))
			if o >= min_open and _backed(behind, t) and o > best_o + 0.001:
				best_o = o
				best = t
		if best_o >= 0.0:
			# the plain about-turn wins a near tie: it is the usual mistake (the yaw sign) and keeps the body's
			# footprint (and its nav block) where it was
			var ob: float = float(open.get(180.0, 0.0))
			if best != 180.0 and 180.0 in turns and _backed(behind, 180.0) and ob >= min_open and ob >= CLEAR_MIN and ob >= best_o - FLIP_TIE:
				return 180.0
			return best
	for t2: float in turns:
		var o2: float = float(open.get(t2, 0.0))
		if o2 >= min_open and o2 > best_o + 0.001:
			best_o = o2
			best = t2
	return best


## True for a script (or one it extends) that is an Interactable.
static func is_interactable(n: Node) -> bool:
	var s: Script = n.get_script() as Script
	while s != null:
		if s.resource_path == INTERACTABLE_SCRIPT:
			return true
		s = s.get_base_script()
	return false


## The RULES row for a node (its script or the nearest base script listed), else OMNI.
static func rule_for(n: Node) -> Dictionary:
	var s: Script = n.get_script() as Script
	while s != null:
		var key: String = s.resource_path.get_file()
		if RULES.has(key):
			var r: Dictionary = (RULES[key] as Dictionary).duplicate()
			r["script"] = key
			# a door sizes its use box from its own `size` (BuyDoor._ready): deep doorways (Totenhafen's pens) too
			if str(r["kind"]) == "door" and n.get("size") is Vector3:
				var dz: Vector3 = n.get("size")
				r["isize"] = Vector3(dz.x + 0.2, dz.y, dz.z + 0.3)
				r["ioff"] = Vector3(0, dz.y * 0.5, 0)
				r["f"] = dz.z * 0.5
			return r
		s = s.get_base_script()
	var o: Dictionary = OMNI.duplicate()
	o["script"] = (n.get_script() as Script).resource_path.get_file() if n.get_script() != null else "?"
	if n.get("interact_size") is Vector3 and (n.get("interact_size") as Vector3) != Vector3(1.2, 1.6, 0.6):
		o["isize"] = n.get("interact_size")
		o["ioff"] = n.get("interact_offset")
	if n.get("size") is Vector3:   # QuestInteract-style boxes sized by `size`
		var sz: Vector3 = n.get("size")
		o["isize"] = sz
		o["ioff"] = Vector3(0, sz.y * 0.5, 0)
	return o


# ================================================================== the geometry index

## {polys: [[PackedVector2Array plan, PackedVector3Array verts, AABB]], boxes: [[Transform3D inverse, half, AABB, name]]}
static func index_geometry(map: Node) -> Dictionary:
	var polys: Array = []
	for r: Node in map.find_children("*", "NavigationRegion3D", true, false):
		var nm: NavigationMesh = (r as NavigationRegion3D).navigation_mesh
		if nm == null:
			continue
		var rx: Transform3D = gxf(r)
		var verts: PackedVector3Array = nm.get_vertices()
		for i: int in nm.get_polygon_count():
			var idx: PackedInt32Array = nm.get_polygon(i)
			var pts: PackedVector2Array = []
			var v3: PackedVector3Array = []
			var ab: AABB = AABB(rx * verts[idx[0]], Vector3.ZERO)
			for j: int in idx:
				var v: Vector3 = rx * verts[j]
				pts.append(Vector2(v.x, v.z))
				v3.append(v)
				ab = ab.expand(v)
			polys.append([pts, v3, ab])
	var boxes: Array = []
	for cs: Node in map.find_children("*", "CollisionShape3D", true, false):
		var sh: Shape3D = (cs as CollisionShape3D).shape
		if not (sh is BoxShape3D) or (cs as CollisionShape3D).disabled:
			continue
		var p: Node = cs.get_parent()
		if p is Area3D:
			continue
		if p is CollisionObject3D and (p as CollisionObject3D).collision_layer & 1 == 0:
			continue   # not on the world layer: players walk through it
		var xf: Transform3D = gxf(cs)
		var half: Vector3 = (sh as BoxShape3D).size * 0.5
		boxes.append([xf.affine_inverse(), half, xf * AABB(-half, half * 2.0), str(p.name)])
	return {"polys": polys, "boxes": boxes}


## The part of the index within NEAR metres (plan) of `at`.
static func local_index(geo: Dictionary, at: Vector3, skip_near: float, rule: Dictionary = {}) -> Dictionary:
	var lp: Array = []
	for pp: Array in geo["polys"]:
		var ab: AABB = pp[2]
		if ab.position.x - NEAR <= at.x and ab.end.x + NEAR >= at.x and ab.position.z - NEAR <= at.z and ab.end.z + NEAR >= at.z \
				and ab.position.y < at.y + 3.0 and ab.end.y > at.y - 3.5:
			lp.append(pp)
	var lb: Array = []
	for bb: Array in geo["boxes"]:
		var ab2: AABB = bb[2]
		if ab2.position.x - NEAR > at.x or ab2.end.x + NEAR < at.x or ab2.position.z - NEAR > at.z or ab2.end.z + NEAR < at.z:
			continue
		# the object's own nav stand-in (NavBlock_Perk_<id>, _Ammo_<name>, _ArmorersBench, _Crucible*, _Bank): not a
		# wall. By name when the generator names it after the node, else a nav block standing on the origin.
		if str(bb[3]).begins_with("NavBlock_"):
			var own: String = str(rule.get("navblock", ""))
			if (own != "" and str(bb[3]).begins_with(own)) or _plan_dist(ab2, at) < minf(skip_near, 0.05):
				continue
		# a door's own leaf or plug (BreachPlug, the gate's body) stands on its origin: not a wall either
		if str(rule.get("kind", "")) == "door" and _plan_dist(ab2, at) < 0.05 and ab2.position.y < at.y + CHEST and ab2.end.y > at.y + CHEST \
				and maxf(ab2.size.x, ab2.size.z) < 6.0:
			continue
		lb.append(bb)
	return {"polys": lp, "boxes": lb}


static func _plan_dist(ab: AABB, p: Vector3) -> float:
	var dx: float = maxf(0.0, maxf(ab.position.x - p.x, p.x - ab.end.x))
	var dz: float = maxf(0.0, maxf(ab.position.z - p.z, p.z - ab.end.z))
	return sqrt(dx * dx + dz * dz)


## The navmesh height under plan point (x, z) closest to `y_ref` within `dy`, or NAN.
static func nav_height(li: Dictionary, x: float, z: float, y_ref: float, dy: float) -> float:
	var best: float = NAN
	var p2: Vector2 = Vector2(x, z)
	for pp: Array in li["polys"]:
		var ab: AABB = pp[2]
		if x < ab.position.x or x > ab.end.x or z < ab.position.z or z > ab.end.z:
			continue
		if ab.position.y > y_ref + dy or ab.end.y < y_ref - dy:
			continue
		if not Geometry2D.is_point_in_polygon(p2, pp[0]):
			continue
		var h: float = _poly_height(pp[1], p2)
		if absf(h - y_ref) <= dy and (is_nan(best) or absf(h - y_ref) < absf(best - y_ref)):
			best = h
	return best


static func _poly_height(v: PackedVector3Array, p: Vector2) -> float:
	for i: int in range(1, v.size() - 1):
		var a: Vector2 = Vector2(v[0].x, v[0].z)
		var b: Vector2 = Vector2(v[i].x, v[i].z)
		var c: Vector2 = Vector2(v[i + 1].x, v[i + 1].z)
		var bc: Vector3 = _bary(a, b, c, p)
		if bc.x >= -0.001 and bc.y >= -0.001 and bc.z >= -0.001:
			return v[0].y * bc.x + v[i].y * bc.y + v[i + 1].y * bc.z
	var s: float = 0.0
	for q: Vector3 in v:
		s += q.y
	return s / maxf(1.0, v.size())


static func _bary(a: Vector2, b: Vector2, c: Vector2, p: Vector2) -> Vector3:
	var v0: Vector2 = b - a
	var v1: Vector2 = c - a
	var v2: Vector2 = p - a
	var den: float = v0.x * v1.y - v1.x * v0.y
	if absf(den) < 1e-9:
		return Vector3(-1, -1, -1)
	var v: float = (v2.x * v1.y - v1.x * v2.y) / den
	var w: float = (v0.x * v2.y - v2.x * v0.y) / den
	return Vector3(1.0 - v - w, v, w)


## True when the segment a-b crosses (or starts inside) a collider box of the local index.
static func seg_blocked(li: Dictionary, a: Vector3, b: Vector3) -> bool:
	for bb: Array in li["boxes"]:
		var inv: Transform3D = bb[0]
		var half: Vector3 = bb[1]
		if _seg_box(inv * a, inv * b, half):
			return true
	return false


## Prints a top-down plan round `o` (world axes: +X to the right, +Z up the page; 0.25 m cells, 4 m each way):
## '.' navmesh at the floor, 'o' navmesh at another height, '#' a collider at chest height, '+' both, 'X' the
## origin, 'F' a point 0.75 m in front.
static func plan(li: Dictionary, o: Vector3, floor_y: float, front: Vector3) -> void:
	var fp: Vector3 = o + front * 0.75
	var z: float = 4.0
	while z >= -4.0:
		var row: String = ""
		var x: float = -4.0
		while x <= 4.0:
			var wx: float = o.x + x
			var wz: float = o.z + z
			var h: float = nav_height(li, wx, wz, floor_y, NAV_DY)
			var h2: float = nav_height(li, wx, wz, floor_y, 3.0)
			var col: bool = false
			var c: Vector3 = Vector3(wx, floor_y + CHEST, wz)
			for bb: Array in li["boxes"]:
				var q: Vector3 = (bb[0] as Transform3D) * c
				var hh: Vector3 = bb[1]
				if absf(q.x) <= hh.x and absf(q.y) <= hh.y and absf(q.z) <= hh.z:
					col = true
					break
			var ch: String = "." if not is_nan(h) else ("o" if not is_nan(h2) else " ")
			if col:
				ch = "+" if ch != " " else "#"
			if absf(wx - o.x) < 0.13 and absf(wz - o.z) < 0.13:
				ch = "X"
			elif absf(wx - fp.x) < 0.13 and absf(wz - fp.z) < 0.13:
				ch = "F"
			row += ch
			x += 0.25
		print("      %+5.1f |%s|" % [o.z + z, row])
		z -= 0.25


## The name of the first collider box the segment a-b crosses, "-" when clear (debugging).
static func blocker(li: Dictionary, a: Vector3, b: Vector3) -> String:
	for bb: Array in li["boxes"]:
		if _seg_box((bb[0] as Transform3D) * a, (bb[0] as Transform3D) * b, bb[1]):
			return "%s %s" % [bb[3], (bb[2] as AABB)]
	return "-"


## Slab test of a local-space segment against the box [-half, half].
static func _seg_box(a: Vector3, b: Vector3, half: Vector3) -> bool:
	var t0: float = 0.0
	var t1: float = 1.0
	var d: Vector3 = b - a
	for k: int in 3:
		if absf(d[k]) < 1e-7:
			if a[k] < -half[k] or a[k] > half[k]:
				return false
		else:
			var ta: float = (-half[k] - a[k]) / d[k]
			var tb: float = (half[k] - a[k]) / d[k]
			if ta > tb:
				var tmp: float = ta
				ta = tb
				tb = tmp
			t0 = maxf(t0, ta)
			t1 = minf(t1, tb)
			if t0 > t1:
				return false
	return true


## True when a box of the local index overlaps the oriented body box (centre c, basis bs, half extents).
static func body_clips(li: Dictionary, c: Vector3, bs: Basis, half: Vector3) -> bool:
	# sample the body volume on a small grid: cheap and exact enough at 5 cm shrink
	var hx: float = maxf(0.0, half.x - 0.05)
	var hy: float = maxf(0.0, half.y - 0.05)
	var hz: float = maxf(0.0, half.z - 0.05)
	for ix: int in 5:
		for iy: int in 3:
			for iz: int in 3:
				var lp: Vector3 = Vector3(lerpf(-hx, hx, ix / 4.0), lerpf(-hy, hy, iy / 2.0), lerpf(-hz, hz, iz / 2.0))
				var wp: Vector3 = c + bs * lp
				for bb: Array in li["boxes"]:
					var q: Vector3 = (bb[0] as Transform3D) * wp
					var h: Vector3 = bb[1]
					if absf(q.x) < h.x and absf(q.y) < h.y and absf(q.z) < h.z:
						return true
	return false


# ================================================================== the survey

## Every interactable of an instantiated (not entered) map scene, checked. `map_key` picks the bank branch row.
static func survey(map: Node, map_key: String = "") -> Array:
	var geo: Dictionary = index_geometry(map)
	var items: Array = []
	for n: Node in map.find_children("*", "Node3D", true, false):
		if not is_interactable(n):
			continue
		# a nested interactable (a plaque, a part of a bigger rig) goes with its parent
		var nested: bool = false
		var p: Node = n.get_parent()
		while p != null and p != map:
			if is_interactable(p):
				nested = true
				break
			p = p.get_parent()
		if nested:
			continue
		var xf: Transform3D = gxf(n)
		var rl: Dictionary = rule_for(n)
		rl["navblock"] = own_navblock(str(n.name))
		if str(rl.get("script", "")) == "perk_machine.gd":
			_perk_footprint(n, rl)
		items.append({"name": str(n.name), "path": str(map.get_path_to(n)), "xf": xf, "rule": rl})
	var bank: Dictionary = bank_row(map_key)
	if not bank.is_empty():
		var at: Array = bank.get("at", [])
		if at.size() == 3:
			var bxf: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(float(bank.get("yaw", 0.0)))), Vector3(float(at[0]), float(at[1]), float(at[2])))
			var br: Dictionary = BANK_RULE.duplicate()
			br["script"] = "bank.json branch"
			br["navblock"] = "NavBlock_Bank"
			items.append({"name": "BankCounter", "path": "(bank.json branches.%s)" % map_key, "xf": bxf, "rule": br})
	# T-263: the arms locker (MapRoot builds it from data/gravelight/weapon_locker.json "lockers": at, yaw = where the doors face)
	var lk: Dictionary = locker_row(map_key)
	if (lk.get("at", []) as Array).size() == 3:
		var la: Array = lk["at"]
		var lr: Dictionary = (RULES["weapon_locker.gd"] as Dictionary).duplicate()
		lr["script"] = "weapon_locker.gd"
		items.append({"name": "WeaponLocker", "path": "(weapon_locker.json lockers.%s)" % map_key, "rule": lr,
			"xf": Transform3D(Basis(Vector3.UP, deg_to_rad(float(lk.get("yaw", 0.0)) + 180.0)), Vector3(float(la[0]), float(la[1]), float(la[2])))})
	# the campaign exfil beacon (MapRoot spawns it from data/gravelight/<map>.json "exfil": position, yaw)
	var ex: Dictionary = exfil_row(map_key)
	if not ex.is_empty() and (ex.get("position", []) as Array).size() == 3:
		var ep: Array = ex["position"]
		var exf: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(float(ex.get("yaw", 0.0)))), Vector3(float(ep[0]), float(ep[1]), float(ep[2])))
		var er: Dictionary = EXFIL_RULE.duplicate()
		er["script"] = "exfil (%s.json)" % map_key
		items.append({"name": "ExfilPoint", "path": "(%s.json exfil)" % map_key, "xf": exf, "rule": er})
	var out: Array = []
	for it: Dictionary in items:
		out.append(check_one(geo, it))
	return out


static var _perk_shapes: Dictionary = {}


## A perk machine's body is its tonic's footprint (perks.json "shape" -> PerkMachine._shape_footprint), and so is
## its use box (PerkMachine._ready).
static func _perk_footprint(n: Node, rl: Dictionary) -> void:
	if _perk_shapes.is_empty() and FileAccess.file_exists("res://data/gravelight/perks.json"):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/gravelight/perks.json"))
		var rows: Variant = (d as Dictionary).get("perks", d) if d is Dictionary else {}
		if rows is Dictionary:
			for k: Variant in (rows as Dictionary).keys():
				if (rows as Dictionary)[k] is Dictionary:
					_perk_shapes[str(k)] = str(((rows as Dictionary)[k] as Dictionary).get("shape", "cabinet"))
	var shape: String = str(_perk_shapes.get(str(n.get("perk_id")), "cabinet"))
	var s: Script = n.get_script() as Script
	if s == null or not s.has_method("_shape_footprint"):
		return
	var fp: Vector3 = s.call("_shape_footprint", shape)
	rl["f"] = fp.z * 0.5
	rl["b"] = fp.z * 0.5
	rl["w"] = fp.x * 0.5
	rl["isize"] = Vector3(fp.x + 0.3, 1.8, 0.25)
	rl["ioff"] = Vector3(0, 1.0, -(fp.z * 0.5 + 0.12))


## The name prefix of the nav block the generators cut round an object of this node name ("" = none known).
static func own_navblock(node_name: String) -> String:
	if node_name.begins_with("Perk_"):
		return "NavBlock_" + node_name
	if node_name.begins_with("AmmoBox_"):
		return "NavBlock_Ammo_" + node_name.trim_prefix("AmmoBox_")
	if node_name in ["ArmorersBench", "Crucible"]:
		return "NavBlock_" + node_name
	if node_name == "BankCounter":
		return "NavBlock_Bank"
	return ""


static func exfil_row(map_key: String) -> Dictionary:
	var path: String = "res://data/gravelight/%s.json" % map_key
	if map_key == "" or not FileAccess.file_exists(path):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (d is Dictionary) or not ((d as Dictionary).get("exfil") is Dictionary):
		return {}
	return (d as Dictionary)["exfil"]


static func locker_row(map_key: String) -> Dictionary:
	if map_key == "" or not FileAccess.file_exists("res://data/gravelight/weapon_locker.json"):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/gravelight/weapon_locker.json"))
	if not (d is Dictionary) or not ((d as Dictionary).get("lockers") is Dictionary):
		return {}
	for k: Variant in ((d as Dictionary)["lockers"] as Dictionary).keys():
		if map_key.begins_with(str(k)):
			return ((d as Dictionary)["lockers"] as Dictionary)[k]
	return {}


static func bank_row(map_key: String) -> Dictionary:
	if map_key == "" or not FileAccess.file_exists("res://data/gravelight/bank.json"):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/gravelight/bank.json"))
	if not (d is Dictionary):
		return {}
	var rows: Dictionary = (d as Dictionary).get("branches", {})
	return rows.get(map_key, {})


static func check_one(geo: Dictionary, it: Dictionary) -> Dictionary:
	var xf: Transform3D = it["xf"]
	var rule: Dictionary = it["rule"]
	var kind: String = str(rule.get("kind", "omni"))
	var o: Vector3 = xf.origin
	var yaw: float = wrap_yaw(rad_to_deg(xf.basis.get_euler().y))
	var axis: Vector3 = rule.get("axis", Vector3(0, 0, -1))
	var f_ext: float = float(rule.get("f", 0.4))
	var b_ext: float = float(rule.get("b", 0.4))
	var li: Dictionary = local_index(geo, o, 0.6, rule)
	var floor_y: float = _floor_at(li, o, float(rule.get("hang", 0.0)))
	var res: Dictionary = {"name": it["name"], "path": it["path"], "script": rule.get("script", "?"), "kind": kind,
		"pos": o, "yaw": yaw, "floor_y": floor_y}
	# the floor surface itself (the navmesh floats 0-0.5 m over it): the origin's floor when it is that close under
	var gy: float = o.y - float(rule.get("hang", 0.0))
	res["ground_y"] = gy if floor_y - gy >= -0.1 and floor_y - gy <= 0.6 else floor_y
	var open: Dictionary = {}
	var samples: Dictionary = {}
	var dn: String = debug_name()
	var dbg: bool = dn != "" and str(it["name"]) in dn.split(",")
	if dbg:
		print("   dbg %s yaw %.1f floor %.2f boxes %d polys %d" % [it["name"], yaw, floor_y, (li["boxes"] as Array).size(), (li["polys"] as Array).size()])
		plan(li, o, floor_y, _dir(yaw, axis))
		for bb: Array in li["boxes"]:
			print("      box %s %s" % [bb[3], bb[2]])
	for t: float in TURNS:
		var dir: Vector3 = _dir(yaw + t, axis)
		# the samples start past the body's front face as it would be after the turn (the body turns with the node)
		var ext: float = f_ext if kind == "faced" else (maxf(0.3, f_ext) if kind == "door" else 0.3)
		var pts: Array = []
		var n_open: int = 0
		for d: float in SAMPLE_D:
			for l: float in LATERAL:
				var side: Vector3 = Vector3(-dir.z, 0, dir.x)
				var sp: Vector3 = Vector3(o.x, floor_y, o.z) + dir * (ext + d) + side * l
				var ok: bool = _open_at(li, o, floor_y, dir, sp, ext, kind == "faced")
				if dbg:
					var hh: float = nav_height(li, sp.x, sp.z, floor_y, NAV_DY)
					var hit: String = "-"
					if not is_nan(hh):
						var a0: Vector3 = Vector3(o.x, floor_y + CHEST, o.z) + dir * (ext + 0.05)
						hit = blocker(li, a0, Vector3(sp.x, hh + CHEST, sp.z))
					print("   dbg %s turn %4.0f d %.2f l %+.2f at (%.2f, %.2f) floor %.2f nav %s block %s" % [it["name"], t, d, l, sp.x, sp.z, floor_y,
						"none" if is_nan(hh) else "%.2f" % hh, hit])
				if ok:
					n_open += 1
					pts.append(sp)
		open[t] = float(n_open) / float(SAMPLE_D.size() * LATERAL.size())
		samples[t] = pts
	res["open"] = open
	# reach: from any open sample round the object (the use ray only needs the eye within reach of the use box)
	var reach_turns: Array = TURNS
	res["reachable"] = _reachable(li, xf, rule, samples, reach_turns, floor_y)
	var walls: Dictionary = {}
	for t2: float in TURNS:
		var dir2: Vector3 = _dir(yaw + t2, axis)
		var ext2: float = f_ext if t2 == 0.0 else (b_ext if t2 == 180.0 else float(rule.get("w", 0.5)))
		var w0: Vector3 = Vector3(o.x, floor_y + CHEST, o.z) + dir2 * maxf(0.0, ext2 - 0.05)
		walls[t2] = kind == "faced" and seg_blocked(li, w0, w0 + dir2 * (WALL_GAP + 0.05))
	res["walls"] = walls
	var behind: Dictionary = {}
	for t3: float in TURNS:
		behind[t3] = back_gap(li, o, floor_y, _dir(yaw + t3, axis), b_ext) if kind == "faced" else INF
	res["behind"] = behind
	var c: Dictionary = classify(kind, open, walls, bool(res["reachable"]), bool(rule.get("lock", false)), bool(rule.get("wall", false)), behind)
	res["verdict"] = c["verdict"]
	res["turn"] = c["turn"]
	res["suggested_yaw"] = wrap_yaw(yaw + float(c["turn"]))
	if c["verdict"] in ["BACKWARDS", "SIDEWAYS"] and bool(rule.get("lock", false)):
		res["note"] = "locked (left as placed)"
	# would the object at the suggested yaw be reachable from its new front?
	if float(c["turn"]) != 0.0:
		var xf2: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(float(res["suggested_yaw"]))), o)
		var samples2: Dictionary = {0.0: samples[float(c["turn"])]}
		res["reachable_after"] = _reachable(li, xf2, rule, samples2, [0.0], floor_y)
	if kind == "faced":
		for key: String in ["now", "after"]:
			var y2: float = yaw if key == "now" else float(res["suggested_yaw"])
			var fwd: Vector3 = _dir(y2, axis)
			# the body box in world: centred between its front and back faces along fwd
			var depth: float = f_ext + b_ext
			var cen: Vector3 = Vector3(o.x, floor_y + 0.75, o.z) + fwd * (f_ext - b_ext) * 0.5
			var bodyb: Basis = Basis(Vector3(-fwd.z, 0, fwd.x), Vector3.UP, fwd)
			res["clips_" + key] = depth > 0.05 and body_clips(li, cen, bodyb, Vector3(float(rule.get("w", 0.5)), 0.7, depth * 0.5))
			# the back against a wall: a chest-high line from the body's back face 0.35 m out hits a collider
			var back0: Vector3 = Vector3(o.x, floor_y + CHEST, o.z) - fwd * maxf(0.0, b_ext - 0.05)
			res["wall_back_" + key] = seg_blocked(li, back0, back0 - fwd * 0.4)
			res["back_gap_" + key] = back_gap(li, o, floor_y, fwd, b_ext)
	res["cam"] = approach_cam(li, res, axis)
	return res


## Metres from the back face of a body (b_ext behind the origin, facing `fwd`) to the nearest collider behind it, on
## a chest-high line, in 5 cm steps up to 1.5 m; INF when there is none.
static func back_gap(li: Dictionary, o: Vector3, floor_y: float, fwd: Vector3, b_ext: float) -> float:
	var back0: Vector3 = Vector3(o.x, floor_y + CHEST, o.z) - fwd * maxf(0.0, b_ext - 0.05)
	for gi: int in 31:
		var gd: float = gi * 0.05
		if seg_blocked(li, back0, back0 - fwd * (0.05 + gd)):
			return gd
	return INF


static func _dir(yaw_deg: float, axis: Vector3) -> Vector3:
	var d: Vector3 = Basis(Vector3.UP, deg_to_rad(yaw_deg)) * axis
	d.y = 0.0
	return d.normalized()


## The floor under an object: its origin height less `hang` (a wall buy hangs 1.5 m up, a note lies on a table), the
## navmesh near it closest to that height within 0.75 m; failing that the closest navmesh from 2.6 m below the origin
## to 0.6 m above; else the origin's own height. A floor within NAV_DY of the expected height is taken as exact.
static func _floor_at(li: Dictionary, o: Vector3, hang: float = 0.0) -> float:
	# the baked polygons sit 0-0.5 m over the floor they cover, so the floor is the polygon nearest the object in
	# plan among those from 0.3 m under the expected floor to 0.75 m over it (a wall buy's floor 1.5 m down; a
	# second, wider pass for an object off its floor), at that polygon's height under the nearest point
	var want: float = o.y - hang
	var p2: Vector2 = Vector2(o.x, o.z)
	for pass_i: int in 2:
		var lo: float = want - (0.3 if pass_i == 0 else 2.6)
		var hi: float = want + 0.75
		var best_d: float = INF
		var best_h: float = NAN
		for pp: Array in li["polys"]:
			var ab: AABB = pp[2]
			if ab.end.y < lo or ab.position.y > hi:
				continue
			var pts: PackedVector2Array = pp[0]
			var d: float = 0.0
			var q: Vector2 = p2
			if not Geometry2D.is_point_in_polygon(p2, pts):
				d = INF
				for i: int in pts.size():
					var c: Vector2 = Geometry2D.get_closest_point_to_segment(p2, pts[i], pts[(i + 1) % pts.size()])
					if c.distance_to(p2) < d:
						d = c.distance_to(p2)
						q = c
			if d > 2.5 or d >= best_d - 0.01:
				continue
			var h: float = _poly_height(pp[1], q.lerp(_centroid(pts), 0.01))
			if h < lo or h > hi:
				continue
			best_d = d
			best_h = h
		if not is_nan(best_h):
			return best_h
	return o.y


static func _centroid(pts: PackedVector2Array) -> Vector2:
	var c: Vector2 = Vector2.ZERO
	for p: Vector2 in pts:
		c += p
	return c / maxf(1.0, pts.size())


static func _open_at(li: Dictionary, o: Vector3, floor_y: float, dir: Vector3, sp: Vector3, face: float = 0.0, los: bool = true) -> bool:
	var h: float = nav_height(li, sp.x, sp.z, floor_y, NAV_DY)
	if is_nan(h):
		return false
	if not los:
		return true
	var a: Vector3 = Vector3(o.x, floor_y + CHEST, o.z) + dir * (face + 0.05)
	var b: Vector3 = Vector3(sp.x, h + CHEST, sp.z)
	return not seg_blocked(li, a, b)


static func _reachable(li: Dictionary, xf: Transform3D, rule: Dictionary, samples: Dictionary, turns: Array, floor_y: float) -> bool:
	var isize: Vector3 = rule.get("isize", Vector3(1.2, 1.6, 0.6))
	var ioff: Vector3 = rule.get("ioff", Vector3(0, 0.8, 0))
	var inv: Transform3D = xf.affine_inverse()
	var centre: Vector3 = xf * ioff
	# objects whose origin hangs above the floor (wall buys) carry their area at the origin's height
	for t: float in turns:
		for sp: Vector3 in samples.get(t, []):
			var eye: Vector3 = Vector3(sp.x, floor_y + EYE, sp.z)
			var le: Vector3 = inv * eye
			var cl: Vector3 = Vector3(clampf(le.x, ioff.x - isize.x * 0.5, ioff.x + isize.x * 0.5),
				clampf(le.y, ioff.y - isize.y * 0.5, ioff.y + isize.y * 0.5), clampf(le.z, ioff.z - isize.z * 0.5, ioff.z + isize.z * 0.5))
			if (xf * cl).distance_to(eye) > REACH - 0.1:
				continue
			# a wall between the eye and the area (the use ray ignores walls, but nobody looks through one)
			if not seg_blocked(li, eye, (xf * cl).lerp(eye, 0.05)) or not seg_blocked(li, eye, centre.lerp(eye, 0.08)):
				return true
			# a part lying in or on a housing (a gimbal on the radar mast): the last 0.35 m is its own housing
			var wc: Vector3 = xf * cl
			if str(rule.get("kind", "")) == "omni" and eye.distance_to(wc) > 0.4 and not seg_blocked(li, eye, wc + (eye - wc).normalized() * 0.35):
				return true
	return false


## A camera 2.5-3 m out on the object's open side at eye height, looking at its centre ~1.1 m up (an object hung
## on a wall: its own height). Uses the suggested facing when the check suggests a turn.
static func approach_cam(li: Dictionary, res: Dictionary, axis: Vector3) -> Dictionary:
	var o: Vector3 = res["pos"]
	var floor_y: float = res["floor_y"]
	var y2: float = float(res.get("suggested_yaw", res["yaw"]))
	var dirs: Array = []
	if str(res["kind"]) == "faced":
		# straight out front first, then a little to either side (a narrow aisle, a rack in the way)
		for off: float in [0.0, 25.0, -25.0, 45.0, -45.0]:
			dirs.append(_dir(y2 + off, axis))
	else:
		var open: Dictionary = res["open"]
		var order: Array = TURNS.duplicate()
		order.sort_custom(func(a: float, b: float) -> bool: return float(open[a]) > float(open[b]))
		for t: float in order:
			dirs.append(_dir(float(res["yaw"]) + t, Vector3(0, 0, -1)))
	var gy: float = float(res.get("ground_y", floor_y))
	var lift: float = floor_y - gy
	var look: Vector3 = Vector3(o.x, maxf(gy + 1.1, o.y if o.y > gy + 0.5 else gy + 1.1), o.z)
	for dir: Vector3 in dirs:
		for d: float in [2.75, 3.0, 2.5, 2.2, 1.8, 1.5]:
			var feet: Vector3 = Vector3(o.x, floor_y, o.z) + dir * d
			var h: float = nav_height(li, feet.x, feet.z, floor_y, NAV_DY)
			if is_nan(h):
				continue
			var eye: Vector3 = Vector3(feet.x, h - lift + EYE, feet.z)
			if seg_blocked(li, eye, look.lerp(eye, 0.15)):
				continue
			return _cam(Vector3(feet.x, h - lift, feet.z), eye, look)
	var dir0: Vector3 = dirs[0]
	var f2: Vector3 = Vector3(o.x, gy, o.z) + dir0 * 2.75
	return _cam(f2, f2 + Vector3(0, EYE, 0), look, false)


static func _cam(feet: Vector3, eye: Vector3, look: Vector3, on_nav: bool = true) -> Dictionary:
	var v: Vector3 = look - eye
	var yaw: float = rad_to_deg(atan2(-v.x, -v.z))
	var pitch: float = rad_to_deg(atan2(v.y, Vector2(v.x, v.z).length()))
	return {"feet": feet, "cam_pos": eye, "look_at": look, "yaw": snappedf(yaw, 0.1), "pitch": snappedf(pitch, 0.1), "on_nav": on_nav}


# ================================================================== reporting

static func failures(rows: Array) -> Array:
	var bad: Array = []
	for r: Dictionary in rows:
		var note: String = str(r.get("note", ""))
		if str(r["verdict"]) in ["BACKWARDS", "SIDEWAYS", "UNREACHABLE"] and not note.begins_with("locked") and not note.begins_with("known"):
			bad.append(r)
	return bad


static func facing_word(yaw: float, axis: Vector3 = Vector3(0, 0, -1)) -> String:
	var d: Vector3 = _dir(yaw, axis)
	# +X east, +Z north on the Fernflug maps (Map 0: +Z south); the word is the axis sign
	if absf(d.x) > absf(d.z):
		return "+X" if d.x > 0 else "-X"
	return "+Z" if d.z > 0 else "-Z"


static func markdown_table(title: String, rows: Array) -> String:
	var s: String = "### %s\n\n| # | Node | Script | Pos (x, y, z) | Yaw | Front faces | Verdict | Open F / B / +90 / -90 | Reach | Suggested yaw | Back gap (m) | Clips |\n|---|---|---|---|---|---|---|---|---|---|---|---|\n" % title
	var i: int = 1
	var win: PackedStringArray = []
	for r: Dictionary in rows:
		if str(r["verdict"]) == "LAYOUT":
			win.append("%s (yaw %.0f)" % [r["name"], float(r["yaw"])])
			continue
		var o: Dictionary = r["open"]
		var p: Vector3 = r["pos"]
		var axis: Vector3 = axis_of(str(r["script"]))
		var front: String = facing_word(float(r["yaw"]), axis) if str(r["kind"]) == "faced" else "(%s)" % r["kind"]
		var sug: String = "-" if float(r["turn"]) == 0.0 else "%.0f" % float(r["suggested_yaw"])
		var gap: String = "-"
		var clips: String = "-"
		if str(r["kind"]) == "faced":
			gap = _gap_str(float(r.get("back_gap_now", INF)))
			clips = "yes" if r.get("clips_now", false) else "no"
			if float(r["turn"]) != 0.0:
				gap += " -> " + _gap_str(float(r.get("back_gap_after", INF)))
				clips += " -> " + ("yes" if r.get("clips_after", false) else "no")
		var verdict: String = str(r["verdict"]) + (" (%s)" % r["note"] if r.has("note") else "")
		s += "| %d | %s | %s | %.2f, %.2f, %.2f | %.0f | %s | %s | %.2f / %.2f / %.2f / %.2f | %s | %s | %s | %s |\n" % [i, r["name"], r["script"],
			p.x, p.y, p.z, float(r["yaw"]), front, verdict, float(o[0.0]), float(o[180.0]), float(o[90.0]), float(o[-90.0]),
			"yes" if r["reachable"] else "NO", sug, gap, clips]
		i += 1
	if not win.is_empty():
		s += "\nWindows (barricades; layout, not checked): " + ", ".join(win) + ".\n"
	return s + "\n"


static func _gap_str(g: float) -> String:
	return "none" if g == INF else "%.2f" % g


## The front axis a script's row uses (local -Z unless its RULES row says otherwise).
static func axis_of(script_key: String) -> Vector3:
	if script_key == "bank.json branch":
		return BANK_RULE["axis"]
	return (RULES.get(script_key, {}) as Dictionary).get("axis", Vector3(0, 0, -1))


static func counts(rows: Array) -> Dictionary:
	var c: Dictionary = {"OK": 0, "BACKWARDS": 0, "SIDEWAYS": 0, "UNSURE": 0, "UNREACHABLE": 0, "LAYOUT": 0}
	for r: Dictionary in rows:
		c[str(r["verdict"])] = int(c.get(str(r["verdict"]), 0)) + 1
	return c
