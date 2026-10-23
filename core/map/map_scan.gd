class_name MapScan
extends RefCounted
## Reads a level for its map data (Update 04 section 1, DECISIONS T-065): points of interest, zone boxes,
## stairs / ladders / lifts and the walkable bounds. The bake (tools_src/bake_minimap.gd) writes what this finds;
## the check (MapCheck) runs it again and compares, so the POIs in data/maps can never drift from the scene.
##
## GRAVELIGHT maps are scanned as a packed scene that is instantiated but never added to the tree (no _ready runs:
## no players, no rounds), so positions come from composing the local transforms up to the root (global_xform).
## B&S planets build their geometry at runtime from data/bs/levels/<id>.json, so their POIs and zones are read
## from that file: the same rows the LevelDirector turns into nodes.

## Stairs and ramps that join floors are StaticBody3D nodes whose name ends in "Stair", "Stairs", "Ramp" or
## "Ramp" + one letter ("Stairs", "CellarStairs", "AdminStairs", "RampF", "TowerRamp", "PumpStair").
const STAIR_RE: String = "(?i)(stairs?|ramp[A-Z]?)$"


# ================================================================== GRAVELIGHT

## Every POI, zone box, connector and the walkable XZ bounds of a GRAVELIGHT scene root (in the tree or not).
## {pois: Array[Dictionary] (floor not yet assigned), zone_boxes: [{id, aabb}], stairs: [AABB], lifts: [...],
##  bounds: Rect2}
static func scan_gl(root: Node) -> Dictionary:
	var pois: Array[Dictionary] = []
	var boxes: Array[Dictionary] = []
	var stairs: Array[AABB] = []
	var lifts: Array[Dictionary] = []
	var bounds: Rect2 = Rect2()
	var have_bounds: bool = false
	var weapons: Dictionary = _json("res://data/gravelight/weapons.json")
	var perks: Dictionary = (_json("res://data/gravelight/perks.json").get("perks", {}) as Dictionary)
	var traps: Dictionary = _json("res://data/gravelight/traps.json")
	var econ: Dictionary = _json("res://data/gravelight/economy.json")
	var crate_cost: int = int(_json("res://data/gravelight/crate.json").get("cost", 950))
	var stair_re: RegEx = RegEx.create_from_string(STAIR_RE)
	for n: Node in _walk(root):
		var path: String = String(root.get_path_to(n)) if n != root else "."
		var key: String = path
		if n is ZoneVolume:
			var zv: ZoneVolume = n as ZoneVolume
			var c: Vector3 = global_xform(n).origin
			boxes.append({"id": String(zv.zone_id), "aabb": AABB(Vector3(c.x - zv.size.x * 0.5, c.y - 0.5, c.z - zv.size.z * 0.5),
				Vector3(zv.size.x, zv.size.y + 0.5, zv.size.z))})
			var r2: Rect2 = Rect2(c.x - zv.size.x * 0.5, c.z - zv.size.z * 0.5, zv.size.x, zv.size.z)
			bounds = r2 if not have_bounds else bounds.merge(r2)
			have_bounds = true
			continue
		if n is StaticBody3D and stair_re.search(String(n.name)) != null:
			var ab: AABB = _body_aabb(n as StaticBody3D)
			if ab.size.y >= 1.5:
				stairs.append(ab)
			continue
		if n is NavigationRegion3D:
			var nm: NavigationMesh = (n as NavigationRegion3D).navigation_mesh
			if nm != null and nm.vertices.size() > 0:
				var xf: Transform3D = global_xform(n)
				for v: Vector3 in nm.vertices:
					var w: Vector3 = xf * v
					var pr: Rect2 = Rect2(w.x, w.z, 0, 0)
					bounds = pr if not have_bounds else bounds.expand(Vector2(w.x, w.z))
					have_bounds = true
			continue
		var p: Dictionary = _gl_poi(n, path, key, root, weapons, perks, traps, econ, crate_cost)
		if not p.is_empty():
			pois.append(p)
		if n is Lift:
			var lf: Lift = n as Lift
			var lo: Vector3 = global_xform(n).origin
			lifts.append({"a": Vector3(lo.x, lf.bottom_y, lo.z), "b": Vector3(lo.x, lf.top_y, lo.z), "path": path})
	pois.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["id"]) < str(b["id"]))
	# the map's extent: its zones (the play space) and every POI; the navmesh only when there are no zones (it
	# also covers fields outside the play space)
	if not boxes.is_empty():
		bounds = Rect2()
		var first: bool = true
		for b: Dictionary in boxes:
			var ab: AABB = b["aabb"]
			var r: Rect2 = Rect2(ab.position.x, ab.position.z, ab.size.x, ab.size.z)
			bounds = r if first else bounds.merge(r)
			first = false
		for p2: Dictionary in pois:
			var pp: Vector3 = p2["pos"]
			bounds = bounds.expand(Vector2(pp.x, pp.z))
	return {"pois": pois, "zone_boxes": boxes, "stairs": stairs, "lifts": lifts, "bounds": bounds}


## One GRAVELIGHT node as a POI ({} when it is none). Prices come from the same tables the nodes read.
static func _gl_poi(n: Node, path: String, key: String, root: Node, weapons: Dictionary, perks: Dictionary, traps: Dictionary,
		econ: Dictionary, crate_cost: int) -> Dictionary:
	var t: String = ""
	var label: String = ""
	var price: int = 0
	var extra: Dictionary = {}
	if n is BuyDoor:
		var d: BuyDoor = n as BuyDoor
		t = "door"
		label = d.label
		price = d.cost
		extra = {"door_id": String(d.door_id), "opens_zone": String(d.opens_zone), "requires_power": d.requires_power}
	elif n is BlastDoor:
		t = "door"
		label = "Blast door"
		extra = {"flag": String((n as BlastDoor).open_flag), "locked": true}
	elif n is WallBuy:
		var wid: String = String((n as WallBuy).weapon_id)
		t = "wall_buy"
		var row: Dictionary = {}
		for table: String in ["weapons", "melee", "lethal"]:
			if (weapons.get(table, {}) as Dictionary).has(wid):
				row = weapons[table][wid]
		label = str(row.get("name", wid.capitalize()))
		price = int(row.get("wall_price", 0))
		extra = {"weapon_id": wid}
	elif n is PerkMachine:
		var pid: String = String((n as PerkMachine).perk_id)
		t = "perk"
		var pr: Dictionary = perks.get(pid, {})
		label = str(pr.get("name", pid.capitalize()))
		price = int(pr.get("cost", 0))
		extra = {"perk_id": pid}
	elif n is MysteryCrate:
		var mc: MysteryCrate = n as MysteryCrate
		t = "crate_spot"
		label = "Requisition Crate" + ((" (%s)" % mc.spot_name) if mc.spot_name != "" else "")
		price = crate_cost
		extra = {"spot_index": mc.spot_index, "can_start": mc.can_start}
	elif n is AmmoBox:
		t = "ammo_box"
		label = "Ammo box"
		price = int((econ.get("ammo_box", {}) as Dictionary).get("normal", 250))
	elif n is Crucible:
		t = "crucible"
		label = "The Crucible"
		price = int(econ.get("crucible_upgrade", 5000))
		extra = {"needs_power": (n as Crucible).needs_power}
	elif n is PowerSwitch:
		t = "power_switch"
		label = "Power: %s" % (n as PowerSwitch).label
	elif n is Workbench:
		t = "workbench"
		label = "Workbench (%s)" % String((n as Workbench).buildable_id).capitalize()
		extra = {"buildable_id": String((n as Workbench).buildable_id)}
	elif n is TrapLever:
		var tl: TrapLever = n as TrapLever
		t = "trap"
		var trap: Node = n.get_node_or_null(tl.trap_path) if not tl.trap_path.is_empty() else null
		var kind: String = "chandelier" if trap is ChandelierTrap else ("live_wire" if trap is LiveWireTrap else ("ore_cart" if trap is OreCartTrap else ""))
		label = {"chandelier": "Chandelier Drop", "live_wire": "Live Wire Fence", "ore_cart": "Runaway Ore Cart"}.get(kind, "Trap")
		price = int((traps.get(kind, {}) as Dictionary).get("cost", 1000))
		extra = {"trap_id": String(tl.trap_id), "kind": kind}
	elif n is Lift:
		t = "lift"
		label = "Lift"
	if t == "":
		return {}
	var pos: Vector3 = global_xform(n).origin
	if n is Lift:
		pos.y = (n as Lift).top_y
	var out: Dictionary = {"id": "%s:%s" % [t, key], "type": t, "pos": pos, "floor": 0, "label": label, "price": price,
		"node_path": path, "key": key}
	if not extra.is_empty():
		out["data"] = extra
	return out


## A node's transform in its scene root's frame, without needing the tree (parents multiplied in).
static func global_xform(n: Node) -> Transform3D:
	if n is Node3D and (n as Node3D).is_inside_tree():
		return (n as Node3D).global_transform
	var xf: Transform3D = (n as Node3D).transform if n is Node3D else Transform3D.IDENTITY
	var p: Node = n.get_parent()
	while p != null:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


static func _body_aabb(b: StaticBody3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	var bx: Transform3D = global_xform(b)
	for c: Node in b.get_children():
		var cs: CollisionShape3D = c as CollisionShape3D
		if cs == null or cs.shape == null:
			continue
		var local: AABB = _shape_aabb(cs.shape)
		var ab: AABB = (bx * cs.transform) * local
		out = ab if first else out.merge(ab)
		first = false
	return out


static func _shape_aabb(s: Shape3D) -> AABB:
	if s is BoxShape3D:
		var sz: Vector3 = (s as BoxShape3D).size
		return AABB(-sz * 0.5, sz)
	if s is ConvexPolygonShape3D or s is ConcavePolygonShape3D:
		var pts: PackedVector3Array = (s as ConvexPolygonShape3D).points if s is ConvexPolygonShape3D else (s as ConcavePolygonShape3D).get_faces()
		if pts.is_empty():
			return AABB()
		var ab: AABB = AABB(pts[0], Vector3.ZERO)
		for p: Vector3 in pts:
			ab = ab.expand(p)
		return ab
	if s is SphereShape3D:
		var r: float = (s as SphereShape3D).radius
		return AABB(Vector3(-r, -r, -r), Vector3(r, r, r) * 2.0)
	if s is CapsuleShape3D or s is CylinderShape3D:
		var r2: float = float(s.get("radius"))
		var h: float = float(s.get("height"))
		return AABB(Vector3(-r2, -h * 0.5, -r2), Vector3(r2 * 2.0, h, r2 * 2.0))
	return AABB()


static func _walk(root: Node) -> Array[Node]:
	var out: Array[Node] = [root]
	var i: int = 0
	while i < out.size():
		for c: Node in out[i].get_children():
			out.append(c)
		i += 1
	return out


## The climb links (ladders) a GRAVELIGHT map's json lists (data/gravelight/<map>.json "climb_links").
static func climb_links(map_id: StringName) -> Array[Dictionary]:
	var key: String = String(map_id).substr(0, 5)   # map00_crossroads -> map00
	var d: Dictionary = _json("res://data/gravelight/%s.json" % key)
	var out: Array[Dictionary] = []
	for c: Variant in d.get("climb_links", []):
		var cd: Dictionary = c as Dictionary
		var a: Vector3 = _v3(cd.get("from", [0, 0, 0]))
		var b: Vector3 = _v3(cd.get("to", [0, 0, 0]))
		out.append({"a": a if a.y <= b.y else b, "b": b if a.y <= b.y else a, "name": str(cd.get("name", ""))})
	return out


## Zone labels from a GRAVELIGHT map's json ("zones": {id: {name}}), for maps that keep them there.
static func gl_zone_names(map_id: StringName) -> Dictionary:
	var key: String = String(map_id).substr(0, 5)
	var d: Dictionary = _json("res://data/gravelight/%s.json" % key)
	var out: Dictionary = {}
	var z: Variant = d.get("zones", {})
	if z is Dictionary:
		for id: Variant in (z as Dictionary).keys():
			var row: Variant = z[id]
			if row is Dictionary and (row as Dictionary).has("name"):
				out[str(id)] = str(row["name"])
	return out


# ================================================================== Bolt & Sprocket

## POIs, zones and bounds of a B&S planet from its level data (data/bs/levels/<id>.json).
static func scan_bs(level_id: String) -> Dictionary:
	var d: Dictionary = _json("res://data/bs/levels/%s.json" % level_id)
	var pois: Array[Dictionary] = []
	var zones: Array[Dictionary] = []
	var bounds: Rect2 = Rect2()
	var have: bool = false
	for z: Variant in d.get("zones", []):
		var zd: Dictionary = z as Dictionary
		var c: Array = zd.get("center", [0, 0])
		var s: Array = zd.get("size", [10, 10])
		var r: Rect2 = Rect2(float(c[0]) - float(s[0]) * 0.5, float(c[1]) - float(s[1]) * 0.5, float(s[0]), float(s[1]))
		zones.append({"id": str(zd.get("id", "")), "name": str(zd.get("name", zd.get("id", ""))), "rect": r,
			"floor_y": float(zd.get("floor", 0.0))})
		bounds = r if not have else bounds.merge(r)
		have = true
	var add: Callable = func(t: String, key: String, p: Variant, label: String, path: String = "") -> void:
		if p == null:
			return
		var pos: Vector3 = _v3(p)
		pois.append({"id": "%s:%s" % [t, key], "type": t, "pos": pos, "floor": 0, "label": label, "price": 0, "node_path": path, "key": key})
	var kiosk: Variant = d.get("kiosk")
	if kiosk is Dictionary:
		add.call("vendor", "kiosk", (kiosk as Dictionary).get("p"), "Gadgetron Vendor")
	var tele: Variant = d.get("teleporter")
	if tele is Dictionary:
		add.call("exit", "teleporter", (tele as Dictionary).get("p"), "Teleporter")
	var beacon: Variant = d.get("beacon")
	if beacon is Dictionary:
		add.call("save", "beacon", (beacon as Dictionary).get("p"), "Save beacon")
	for r2: Variant in d.get("relays", []):
		var rd: Dictionary = r2 as Dictionary
		add.call("checkpoint", str(rd.get("id", "")), rd.get("p"), "Relay: %s" % str(rd.get("id", "")).capitalize())
	for n: Variant in d.get("npcs", []):
		var nd: Dictionary = n as Dictionary
		if (nd.get("quests", []) as Array).is_empty():
			continue
		add.call("npc", str(nd.get("id", "")), nd.get("p"), str(nd.get("name", nd.get("id", ""))))
	for it: Variant in d.get("interacts", []):
		var id: Dictionary = it as Dictionary
		if str(id.get("id", "")) == "ship":
			add.call("ship", "ship", id.get("p"), "Your ship")
	for g: Variant in d.get("gates", []):
		var gd: Dictionary = g as Dictionary
		add.call("gate", str(gd.get("id", "")), gd.get("p"), str(gd.get("id", "")).capitalize())
	var lifts: Array[Dictionary] = []
	for l: Variant in (d.get("lifts") if d.get("lifts") is Array else []):
		var ld: Dictionary = l as Dictionary
		add.call("lift", str(ld.get("id", "")), ld.get("top"), "Lift")
		lifts.append({"a": _v3(ld.get("bottom", [0, 0, 0])), "b": _v3(ld.get("top", [0, 0, 0])), "path": ""})
	for p2: Dictionary in pois:
		var pp: Vector3 = p2["pos"]
		bounds = bounds.expand(Vector2(pp.x, pp.z)) if have else Rect2(pp.x, pp.z, 0, 0)
		have = true
	pois.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["id"]) < str(b["id"]))
	return {"pois": pois, "zones": zones, "lifts": lifts, "bounds": bounds, "name": str(d.get("name", level_id))}


# ================================================================== shared

## Merges zone boxes per zone id into map zones {id, name, y_min, y_max, polys, ys} (one rectangle polygon per box;
## ys[i] = [bottom, top] of box i, so a cellar box under the taproom never claims the taproom).
static func zones_from_boxes(boxes: Array, names: Dictionary) -> Array[Dictionary]:
	var by_id: Dictionary = {}
	var order: Array[String] = []
	for b: Dictionary in boxes:
		var id: String = str(b["id"])
		var ab: AABB = b["aabb"]
		if not by_id.has(id):
			by_id[id] = {"id": id, "name": str(names.get(id, id.capitalize())), "y_min": ab.position.y, "y_max": ab.end.y, "polys": [], "ys": []}
			order.append(id)
		var z: Dictionary = by_id[id]
		z["y_min"] = minf(float(z["y_min"]), ab.position.y)
		z["y_max"] = maxf(float(z["y_max"]), ab.end.y)
		(z["polys"] as Array).append(_rect_poly(Rect2(ab.position.x, ab.position.z, ab.size.x, ab.size.z)))
		(z["ys"] as Array).append([snappedf(ab.position.y, 0.01), snappedf(ab.end.y, 0.01)])   # each box keeps its own heights
	var out: Array[Dictionary] = []
	for id2: String in order:
		var zz: Dictionary = by_id[id2]
		var typed: Array[PackedVector2Array] = []
		for p: PackedVector2Array in zz["polys"]:
			typed.append(p)
		zz["polys"] = typed
		out.append(zz)
	return out


static func _rect_poly(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


## A stable fingerprint of a POI list (ids, types, positions to 10 cm, prices, labels), stored at bake time.
static func poi_signature(pois: Array) -> String:
	var rows: PackedStringArray = []
	for p: Dictionary in pois:
		var v: Vector3 = p["pos"]
		rows.append("%s|%s|%.1f|%.1f|%.1f|%d|%s" % [p["id"], p["type"], v.x, v.y, v.z, int(p.get("price", 0)), p.get("label", "")])
	rows.sort()
	return "\n".join(rows).md5_text()


static func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary else {}


static func _v3(v: Variant) -> Vector3:
	if v is Vector3:
		return v
	var a: Array = v as Array
	if a == null or a.size() < 3:
		return Vector3.ZERO
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
