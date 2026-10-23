class_name MapData
extends RefCounted
## One level's map (Update 04 section 1, DECISIONS T-065): its floors, the baked top-down image of each floor, its
## named zones and its points of interest. Stored as JSON + PNGs in data/maps/<map_id>/ (mapdata.json,
## floor_<n>_<id>.png), written by the bake (tools_src/bake_minimap.gd, tools/bake_minimap.sh) and checked by
## MapCheck (tools_src/check_mapdata.gd, the GUT test test_mapdata.gd).
##
## Frame: world XZ, +X east, +Z south. Every floor image covers the same world rectangle `world_rect`
## (position = (min x, min z), size = (width, depth) in metres), north (-Z) at the top, so
## uv = ((x - rect.x) / rect.w, (z - rect.y) / rect.h) maps a world position to the image exactly.
##
## Floors are ordered bottom to top. A floor has a height band [y_min, y_max) for the player's feet, an optional
## list of XZ rectangles ("rects") it is limited to (the Inn's upstairs only exists over the inn), the height the
## bake cut it at ("cut"), and its image.
## POIs: {id, type, pos (Vector3), floor, label, price, node_path, key} (types: door, perk, wall_buy, ammo_box,
## crate_spot, crucible, power_switch, workbench, trap, lift; B&S: vendor, save, checkpoint, exit, npc, ship, gate,
## lift). node_path is relative to the level's root node, for live state lookups (MapState.poi_state).
## Connectors (stairs / ladders / lifts): {kind, a (Vector3, low end), b (high end), floor_a, floor_b}.

const ROOT: String = "res://data/maps"
const FILE: String = "mapdata.json"

static var _cache: Dictionary = {}

var map_id: StringName = &""
var game: String = "gravelight"
var style: String = "ink"
var display_name: String = ""
var world_rect: Rect2 = Rect2(0, 0, 1, 1)
var px_per_m: float = 6.0
var image_size: Vector2i = Vector2i.ONE
var floors: Array[Dictionary] = []
var zones: Array[Dictionary] = []
var pois: Array[Dictionary] = []
var connectors: Array[Dictionary] = []
var poi_signature: String = ""
var baked_at: String = ""
var _textures: Dictionary = {}
var _poi_index: Dictionary = {}


# ================================================================== loading

## The map data of one level, loaded once and cached (null when the level has none).
static func for_map(id: StringName) -> MapData:
	if _cache.has(id):
		return _cache[id]
	var path: String = path_for(id)
	if not FileAccess.file_exists(path):
		return null
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (v is Dictionary):
		push_error("MapData: %s is not a JSON object" % path)
		return null
	var md: MapData = from_dict(v as Dictionary)
	_cache[id] = md
	return md


static func clear_cache() -> void:
	_cache.clear()


static func dir_for(id: StringName) -> String:
	return ROOT.path_join(String(id))


static func path_for(id: StringName) -> String:
	return dir_for(id).path_join(FILE)


static func exists(id: StringName) -> bool:
	return FileAccess.file_exists(path_for(id))


static func from_dict(d: Dictionary) -> MapData:
	var md: MapData = MapData.new()
	md.map_id = StringName(str(d.get("map_id", "")))
	md.game = str(d.get("game", "gravelight"))
	md.style = str(d.get("style", "ink"))
	md.display_name = str(d.get("display_name", md.map_id))
	md.world_rect = _rect(d.get("world_rect", [0, 0, 1, 1]))
	md.px_per_m = float(d.get("px_per_m", 6.0))
	var isz: Array = d.get("image_size", [1, 1])
	md.image_size = Vector2i(int(isz[0]), int(isz[1]))
	md.poi_signature = str(d.get("poi_signature", ""))
	md.baked_at = str(d.get("baked_at", ""))
	var i: int = 0
	for f: Variant in d.get("floors", []):
		var fd: Dictionary = (f as Dictionary).duplicate(true)
		fd["index"] = i
		var rects: Array[Rect2] = []
		for r: Variant in fd.get("rects", []):
			rects.append(_rect(r))
		fd["rects"] = rects
		for k: String in ["y_min", "y_max", "base_y", "cut"]:
			fd[k] = float(fd.get(k, 0.0))
		md.floors.append(fd)
		i += 1
	for z: Variant in d.get("zones", []):
		var zd: Dictionary = (z as Dictionary).duplicate(true)
		var polys: Array[PackedVector2Array] = []
		for poly: Variant in zd.get("polys", []):
			var pv: PackedVector2Array = []
			for pt: Variant in poly:
				pv.append(Vector2(float(pt[0]), float(pt[1])))
			polys.append(pv)
		zd["polys"] = polys
		zd["y_min"] = float(zd.get("y_min", -INF))
		zd["y_max"] = float(zd.get("y_max", INF))
		md.zones.append(zd)
	for p: Variant in d.get("pois", []):
		var pd: Dictionary = (p as Dictionary).duplicate(true)
		pd["pos"] = _v3(pd.get("pos", [0, 0, 0]))
		pd["floor"] = int(pd.get("floor", 0))
		pd["price"] = int(pd.get("price", 0))
		md.pois.append(pd)
		md._poi_index[str(pd.get("id", ""))] = pd
	for c: Variant in d.get("connectors", []):
		var cd: Dictionary = (c as Dictionary).duplicate(true)
		cd["a"] = _v3(cd.get("a", [0, 0, 0]))
		cd["b"] = _v3(cd.get("b", [0, 0, 0]))
		cd["floor_a"] = int(cd.get("floor_a", 0))
		cd["floor_b"] = int(cd.get("floor_b", 0))
		md.connectors.append(cd)
	return md


## The JSON form (what the bake writes).
func to_dict() -> Dictionary:
	var fl: Array = []
	for f: Dictionary in floors:
		var fd: Dictionary = f.duplicate(true)
		fd.erase("index")
		var rs: Array = []
		for r: Rect2 in f.get("rects", []):
			rs.append([snappedf(r.position.x, 0.01), snappedf(r.position.y, 0.01), snappedf(r.size.x, 0.01), snappedf(r.size.y, 0.01)])
		fd["rects"] = rs
		fl.append(fd)
	var zl: Array = []
	for z: Dictionary in zones:
		var zd: Dictionary = z.duplicate(true)
		var ps: Array = []
		for poly: PackedVector2Array in z.get("polys", []):
			var pts: Array = []
			for pt: Vector2 in poly:
				pts.append([snappedf(pt.x, 0.01), snappedf(pt.y, 0.01)])
			ps.append(pts)
		zd["polys"] = ps
		if is_inf(float(zd.get("y_min", 0.0))):
			zd.erase("y_min")
		if is_inf(float(zd.get("y_max", 0.0))):
			zd.erase("y_max")
		zl.append(zd)
	var pl: Array = []
	for p: Dictionary in pois:
		var pd: Dictionary = p.duplicate(true)
		pd["pos"] = _arr3(p["pos"] as Vector3)
		pl.append(pd)
	var cl: Array = []
	for c: Dictionary in connectors:
		var cd: Dictionary = c.duplicate(true)
		cd["a"] = _arr3(c["a"] as Vector3)
		cd["b"] = _arr3(c["b"] as Vector3)
		cl.append(cd)
	return {
		"_doc": "Baked map data (Update 04 section 1, DECISIONS T-065). Written by tools/bake_minimap.sh; do not edit by hand (edit data/maps/bake_config.json and re-bake). world_rect = [min x, min z, width, depth] in metres, every floor image covers it, north (-Z) up.",
		"map_id": String(map_id), "game": game, "style": style, "display_name": display_name,
		"world_rect": [snappedf(world_rect.position.x, 0.001), snappedf(world_rect.position.y, 0.001),
			snappedf(world_rect.size.x, 0.001), snappedf(world_rect.size.y, 0.001)],
		"px_per_m": px_per_m, "image_size": [image_size.x, image_size.y], "baked_at": baked_at,
		"poi_signature": poi_signature, "floors": fl, "zones": zl, "pois": pl, "connectors": cl,
	}


# ================================================================== floors

func floor_count() -> int:
	return floors.size()


## The floor whose height band holds `y` (feet height). Below every band: the bottom floor; above: the top one.
## Ignores the floors' XZ limits; floor_at() is the one to use for a player.
func floor_for_y(y: float) -> int:
	if floors.is_empty():
		return 0
	for f: Dictionary in floors:
		if y >= float(f["y_min"]) and y < float(f["y_max"]):
			return int(f["index"])
	return 0 if y < float(floors[0]["y_min"]) else floors.size() - 1


## The floor a position is on: a band that holds pos.y and (when the floor is limited to rects) a rect that holds
## pos.xz. When none matches (on a roof outside a limited floor's rects), the nearest unlimited floor by height.
func floor_at(pos: Vector3) -> int:
	if floors.is_empty():
		return 0
	var p2: Vector2 = Vector2(pos.x, pos.z)
	for f: Dictionary in floors:
		if pos.y >= float(f["y_min"]) and pos.y < float(f["y_max"]) and _in_rects(f, p2):
			return int(f["index"])
	var best: int = -1
	var best_d: float = INF
	for f2: Dictionary in floors:
		if not (f2["rects"] as Array).is_empty():
			continue
		var d: float = 0.0 if (pos.y >= float(f2["y_min"]) and pos.y < float(f2["y_max"])) else minf(absf(pos.y - float(f2["y_min"])), absf(pos.y - float(f2["y_max"])))
		if d < best_d:
			best_d = d
			best = int(f2["index"])
	return best if best >= 0 else floor_for_y(pos.y)


static func _in_rects(f: Dictionary, p2: Vector2) -> bool:
	var rects: Array = f.get("rects", [])
	if rects.is_empty():
		return true
	for r: Rect2 in rects:
		if r.grow(0.001).has_point(p2):
			return true
	return false


func floor_name(i: int) -> String:
	if i < 0 or i >= floors.size():
		return ""
	return str(floors[i].get("name", floors[i].get("id", "")))


func floor_image_path(i: int) -> String:
	if i < 0 or i >= floors.size():
		return ""
	return dir_for(map_id).path_join(str(floors[i].get("image", "")))


## The floor's baked image (imported texture when the import exists, else read from the PNG directly).
func floor_texture(i: int) -> Texture2D:
	if _textures.has(i):
		return _textures[i]
	var path: String = floor_image_path(i)
	var tex: Texture2D = null
	if path != "" and ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null and path != "" and FileAccess.file_exists(path):
		var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	_textures[i] = tex
	return tex


# ================================================================== world <-> map

## World position -> 0..1 image coordinates (u east, v south). Every floor shares the rect, so `floor` is only
## kept for symmetry with uv_to_world.
func world_to_uv(pos: Vector3, _floor: int = -1) -> Vector2:
	return Vector2((pos.x - world_rect.position.x) / world_rect.size.x, (pos.z - world_rect.position.y) / world_rect.size.y)


## 0..1 image coordinates on a floor -> world position on that floor's base height.
func uv_to_world(uv: Vector2, floor_index: int = 0) -> Vector3:
	var y: float = 0.0
	if floor_index >= 0 and floor_index < floors.size():
		y = float(floors[floor_index].get("base_y", floors[floor_index]["y_min"]))
	return Vector3(world_rect.position.x + uv.x * world_rect.size.x, y, world_rect.position.y + uv.y * world_rect.size.y)


func world_to_pixel(pos: Vector3) -> Vector2:
	return world_to_uv(pos) * Vector2(image_size)


# ================================================================== zones & POIs

## The id of the zone that holds `pos` ("" outside every zone). zone_name() gives its label.
func zone_at(pos: Vector3) -> String:
	var p2: Vector2 = Vector2(pos.x, pos.z)
	for z: Dictionary in zones:
		if pos.y < float(z["y_min"]) or pos.y > float(z["y_max"]):
			continue
		var polys: Array = z["polys"]
		var ys: Array = z.get("ys", [])
		for i: int in polys.size():
			if i < ys.size() and (pos.y < float(ys[i][0]) or pos.y > float(ys[i][1])):
				continue
			if Geometry2D.is_point_in_polygon(p2, polys[i] as PackedVector2Array):
				return str(z["id"])
	return ""


## Whether polygon `i` of zone `z` reaches into floor `f`'s height band.
static func poly_on_floor(z: Dictionary, i: int, f: Dictionary) -> bool:
	var ys: Array = z.get("ys", [])
	var lo: float = float(ys[i][0]) if i < ys.size() else float(z["y_min"])
	var hi: float = float(ys[i][1]) if i < ys.size() else float(z["y_max"])
	return hi >= float(f["y_min"]) and lo < float(f["y_max"])


func zone_name(id: String) -> String:
	for z: Dictionary in zones:
		if str(z["id"]) == id:
			return str(z.get("name", id))
	return id


## "You are here": the zone label at a position ("" outside every zone).
func zone_label_at(pos: Vector3) -> String:
	var id: String = zone_at(pos)
	return zone_name(id) if id != "" else ""


func poi(id: String) -> Dictionary:
	return _poi_index.get(id, {})


func pois_of_type(t: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in pois:
		if str(p["type"]) == t:
			out.append(p)
	return out


# ================================================================== helpers

static func _rect(v: Variant) -> Rect2:
	var a: Array = v as Array
	return Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))


static func _v3(v: Variant) -> Vector3:
	if v is Vector3:
		return v
	var a: Array = v as Array
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


static func _arr3(v: Vector3) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]
