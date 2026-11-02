extends SceneTree
## UPDATE 10 s6 item 6 (T-162): where the frozen frame of a map transition goes. For each map id given (default map00 and
## map04b): loads the PackedScene (what the loading card's thread does), then times PackedScene.instantiate(), then
## add_child to the tree (the scene's _ready: the generators, the landscape, the navmesh) and the first frame after it.
##   godot --headless --audio-driver Dummy --path . --script res://gravelight/tools_src/time_map_load.gd -- map00_crossroads map04b_kranich

func _initialize() -> void:
	var ids: PackedStringArray = OS.get_cmdline_user_args()
	if ids.is_empty():
		ids = PackedStringArray(["map00_crossroads", "map04b_kranich"])
	_run.call_deferred(ids)


func _run(ids: PackedStringArray) -> void:
	await process_frame
	var campaign: GDScript = load("res://gravelight/world/campaign.gd") as GDScript
	for id: String in ids:
		var path: String = campaign.call("scene_for", StringName(id))
		var t0: int = Time.get_ticks_usec()
		var ps: PackedScene = load(path) as PackedScene
		var t1: int = Time.get_ticks_usec()
		var node: Node = ps.instantiate()
		var t2: int = Time.get_ticks_usec()
		root.add_child(node)
		var t3: int = Time.get_ticks_usec()
		await process_frame
		var t4: int = Time.get_ticks_usec()
		print("[time_map_load] %-18s load %5.0f ms, instantiate %5.0f ms, add_child (_ready) %5.0f ms, first frame %5.0f ms, total %5.0f ms" % [
			id, (t1 - t0) / 1000.0, (t2 - t1) / 1000.0, (t3 - t2) / 1000.0, (t4 - t3) / 1000.0, (t4 - t0) / 1000.0])
		node.queue_free()
		for i: int in 5:
			await process_frame
	quit(0)
