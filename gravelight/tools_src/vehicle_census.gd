extends SceneTree
## T-253 (UPDATE 19): triangle counts of the vehicles and aircraft, for the note's before / after table.
##   godot --headless --audio-driver Dummy --path . --script res://gravelight/tools_src/vehicle_census.gd [-- --maps]
## Without --maps: the models built in code (the Sherman with its running gear and tracks, the dive bomber, the bombs)
## and the model files (the C-47s, the Kranich's parts). With --maps: also the vehicles standing in the map scenes,
## found by node name (slow: it loads every map).

const GLBS: Array[String] = [
	"res://assets/ours/world/c47_crashed", "res://assets/ours/world/c47_intact", "res://assets/ours/world/kranich_body",
	"res://assets/ours/world/kranich_wing_l", "res://assets/ours/world/kranich_wing_r", "res://assets/ours/world/kranich_nacelle",
	"res://assets/ours/world/kranich_cockpit", "res://assets/ours/world/kranich_kanzel", "res://assets/ours/world/kranich_bay",
]
const STUKA: String = "res://gravelight/world/sherman/stuka_plane.gd"
const MAPS: Array[String] = [
	"res://gravelight/maps/map00_crossroads/map00.tscn",
]
## Node name fragments that mark a vehicle in a map scene (case-insensitive).
const NAMES: Array[String] = ["wagon", "cart", "truck", "lorry", "c47", "wreck", "kranich", "uboat", "u1047", "u_1047", "crane",
	"boat", "barge", "loco", "tram", "sled", "kubel", "halftrack", "tank", "plane", "aircraft", "glider", "tower", "well"]


func _initialize() -> void:
	var with_maps: bool = OS.get_cmdline_user_args().has("--maps")
	print("== built in code")
	var total: int = 0
	var far: int = 0
	var sm: GDScript = load("res://gravelight/world/sherman/sherman_mesh.gd") as GDScript
	var has_parts: bool = false
	for md: Dictionary in sm.get_script_method_list():
		if str(md.get("name", "")) == "has_part":
			has_parts = true
	var counts: Dictionary = {"hull": 1, "turret": 1, "gun": 1, "wheel": 12, "roller": 6, "sprocket": 2, "idler": 2}
	for p: String in counts:
		var t: int = ProcKit.mesh_tris(ShermanMesh.part(p)[0])
		var td: int = 0
		var tf: int = 0
		if has_parts:
			if bool(sm.call("has_part", p + "_detail")):
				td = ProcKit.mesh_tris(ShermanMesh.part(p + "_detail")[0])
			if bool(sm.call("has_part", p + "_far")):
				tf = ProcKit.mesh_tris(ShermanMesh.part(p + "_far")[0])
		print("  sherman %-9s x%-2d  %6d tris (+%d detail, far %d)" % [p, counts[p], t, td, tf])
		total += (t + td) * int(counts[p])
		far += (tf if tf > 0 else t) * int(counts[p])
	var n_links: int = int(floor(ShermanMesh.path_length(ShermanMesh.track_path()) / ShermanMesh.LINK_PITCH))
	var lt: int = ProcKit.mesh_tris(ShermanMesh.part("link")[0])
	var lf: int = lt
	if has_parts and bool(sm.call("has_part", "link_far")):
		lf = ProcKit.mesh_tris(ShermanMesh.part("link_far")[0])
	print("  sherman link      x%d  %6d tris (far %d)" % [n_links * 2, lt, lf])
	total += lt * n_links * 2
	far += lf * n_links * 2
	print("  SHERMAN total near %d tris, far %d tris" % [total, far])
	var st: int = 0
	var sp: GDScript = load(STUKA) as GDScript   # loaded here, not named: it needs the autoloads
	for p2: String in ["body", "prop", "bomb"]:
		var t2: int = ProcKit.mesh_tris((sp.call("part", p2) as Array)[0])
		print("  stuka %-9s %6d tris" % [p2, t2])
		st += t2
	print("  STUKA total %d tris" % st)
	print("  bomb_small %d tris" % ProcKit.mesh_tris((sp.call("part", "bomb_small") as Array)[0]))
	print("== model files")
	for dir: String in GLBS:
		var da: DirAccess = DirAccess.open(dir)
		if da == null:
			continue
		for f: String in da.get_files():
			if not f.ends_with(".glb"):
				continue
			var ps: PackedScene = load(dir.path_join(f)) as PackedScene
			if ps == null:
				print("  %s: not loadable" % dir.path_join(f))
				continue
			var n: Node = ps.instantiate()
			print("  %-60s %7d tris" % [dir.path_join(f).trim_prefix("res://assets/ours/world/"), node_tris(n)])
			n.free()
	if with_maps:
		print("== in the map scenes (by node name)")
		for mp: String in MAPS:
			var ps2: PackedScene = load(mp) as PackedScene
			if ps2 == null:
				continue
			var root: Node = ps2.instantiate()
			print("  ", mp)
			_walk(root, root)
			root.free()
	quit(0)


func _walk(n: Node, root: Node) -> void:
	var nm: String = str(n.name).to_lower()
	for frag: String in NAMES:
		if nm.contains(frag):
			var t: int = node_tris(n)
			if t > 0:
				print("    %-70s %7d tris" % [str(root.get_path_to(n)), t])
			return
	for c: Node in n.get_children():
		_walk(c, root)


static func node_tris(n: Node) -> int:
	var t: int = 0
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		t += ProcKit.mesh_tris((n as MeshInstance3D).mesh)
	elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh != null:
		var mm: MultiMesh = (n as MultiMeshInstance3D).multimesh
		t += ProcKit.mesh_tris(mm.mesh) * mm.instance_count
	for c: Node in n.get_children():
		t += node_tris(c)
	return t
