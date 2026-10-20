extends SceneTree
## Loads every .gd under the project dirs and reports scripts that fail to compile.
## Usage: godot --headless --path . --script res://gravelight/tools_src/check_scripts.gd

const DIRS: PackedStringArray = ["res://autoload", "res://player", "res://weapons", "res://enemies",
	"res://world", "res://ui", "res://maps", "res://tests", "res://net"]


func _initialize() -> void:
	var bad: int = 0
	var total: int = 0
	for d: String in DIRS:
		for path: String in _walk(d):
			total += 1
			var s: Script = load(path) as Script
			if s == null or not s.can_instantiate():
				bad += 1
				print("FAIL ", path)
	print("checked %d scripts, %d failed" % [total, bad])
	quit(1 if bad > 0 else 0)


func _walk(dir: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var da: DirAccess = DirAccess.open(dir)
	if da == null:
		return out
	for f: String in da.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub: String in da.get_directories():
		out.append_array(_walk(dir.path_join(sub)))
	return out
