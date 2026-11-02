class_name ClimbLink
extends RefCounted
## Authored climb volumes (ZOMBIE_ANIM_SPEC §3, T-041): NavigationLink3Ds with the "climb" meta that a zombie's
## NavigationAgent3D reaches like any link; Zombie._on_link_reached then plays the Climb state (loop + mantle)
## from the link's start to its end instead of walking it. Data-driven per map: data/gravelight/<mapNN>.json
## "climb_links": [{"zone": "D_PENHALL", "from": [x, y, z], "to": [x, y, z], "name": "..."}]. The link's
## navigation layer is the zone's bit (MapRoot.nav_zone_bits) so closed zones keep their ladders closed.

const META: StringName = &"climb"
## T-153: a zone's ladders live on its climb layer (the zone's bit + CLIMB_OFFSET), not on its walk layer: the
## ZombieDirector opens both together (zombies are unchanged), and the bots' mask (WALK_MASK) leaves the climb layers
## out, because a bot cannot climb: on Totenhafen its route to the north catwalk ran up Ladder_CatwalkN and it stood
## at the foot of the ladder for good instead of taking a stair.
const CLIMB_OFFSET: int = 16
const WALK_MASK: int = 0xFFFF


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
		holder.add_child(link)
		out.append(link)
		i += 1
	return out


static func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
