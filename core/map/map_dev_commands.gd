class_name MapDevCommands
extends RefCounted
## Dev console commands for the map (Update 04 sections 1-2, DECISIONS T-065), registered on the GRAVELIGHT console:
##   bake_minimap <map_id|all>   re-bakes map data in a background, off-screen Godot run (tools_src/bake_minimap);
##                               `minimap reload` picks the new data up in a running match
##   minimap reveal | perf | reload | zombies   discover everything / the minimap's CPU cost / reload the baked
##                               data / blip every zombie for 5 s


static func register_all(console: Node) -> void:
	console.call("register", "bake_minimap", func(a: PackedStringArray) -> String: return bake(a),
		"bake_minimap <map_id|all>: re-bake the minimap data (off-screen, in the background)")
	console.call("register", "minimap", func(a: PackedStringArray) -> String: return minimap(a),
		"minimap reveal|perf|reload|zombies: map debug (discover all / cost per frame / reload baked data / show zombies)")


static func bake(a: PackedStringArray) -> String:
	var id: String = a[0] if not a.is_empty() else ""
	if id == "":
		return "bake_minimap <map_id|all>: %s" % ", ".join(MapCatalog.ids().map(func(i: StringName) -> String: return String(i)))
	if id != "all" and MapCatalog.level(StringName(id)).is_empty():
		return "Not a playable level: %s" % id
	if not ResourceLoader.exists("res://tools_src/bake_minimap.tscn") or not OS.has_feature("editor") and not OS.is_debug_build():
		return "The bake needs the project (tools_src); run tools/bake_minimap.sh %s" % id
	var ids: PackedStringArray = PackedStringArray([id]) if id != "all" else PackedStringArray(MapCatalog.ids().map(func(i: StringName) -> String: return String(i)))
	var pids: PackedStringArray = []
	for m: String in ids:
		var args: PackedStringArray = ["--audio-driver", "Dummy", "--position", "-4000,-4000", "--resolution", "1280x720",
			"--path", ProjectSettings.globalize_path("res://"), "res://tools_src/bake_minimap.tscn", "--", "--map=" + m]
		pids.append(str(OS.create_process(OS.get_executable_path(), args)))
	return "Baking %s off-screen (pid %s). Then `minimap reload`." % [", ".join(ids), ", ".join(pids)]


static func minimap(a: PackedStringArray) -> String:
	var ms: MapState = MapState.current()
	var sub: String = a[0] if not a.is_empty() else "perf"
	if sub == "reload":
		MapData.clear_cache()
		if ms != null:
			var md: MapData = MapData.for_map(ms.data.map_id)
			if md != null:
				ms.data = md
				ms._node_cache.clear()
		return "Map data reloaded"
	if ms == null:
		return "No map state in this level (no baked map data?)"
	match sub:
		"reveal":
			ms.discover_all()
			return "Every POI discovered, every area revealed"
		"zombies":
			var body: Node3D = ms.local_body()
			var n: int = ms.reveal_zombies(body.global_position if body != null else Vector3.ZERO, 9999.0, 5.0)
			return "%d zombies on the map for 5 s" % n
		"perf":
			var mm: Minimap = null
			for n2: Node in ms.get_tree().root.find_children("Minimap", "Control", true, false):
				mm = n2 as Minimap
			if mm == null:
				return "No minimap shown"
			return "Minimap: %.0f us per frame (process + draw, rolling average; budget 300 us)" % mm.perf_usec()
	return "minimap reveal|perf|reload|zombies"
