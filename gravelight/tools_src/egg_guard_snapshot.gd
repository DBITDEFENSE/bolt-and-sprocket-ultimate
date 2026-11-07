extends SceneTree
## Writes the egg guard snapshot (egg_guard.gd). Only for a deliberate egg change by the owner.


func _init() -> void:
	var G: GDScript = load("res://gravelight/tools_src/egg_guard.gd")
	var d: Dictionary = G.digest_all()
	var fa: FileAccess = FileAccess.open(G.FIXTURE, FileAccess.WRITE)
	fa.store_string(JSON.stringify(d, " ", true) + "\n")
	fa.close()
	print("[egg_guard] wrote %d quest files to %s" % [d.size(), G.FIXTURE])
	quit(0)
