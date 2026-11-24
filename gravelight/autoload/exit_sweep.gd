class_name ExitSweep
extends RefCounted
## T-264: empties the scripts' static caches when the game quits.
##
## Many scripts keep meshes, materials, shaders and whole instantiated models in `static var` caches (the zombie
## bodies, the arms, the weapon models). Statics outlive the scene tree: the engine drops them after the rendering
## server has shut down, and in an exported (release) build that ended every run with "Pages in use exist at exit",
## "double free or corruption" and a crash on the way out: exit code 134 / 139 on Linux, which macOS shows as "quit
## unexpectedly" and a handheld's launcher may count as a failed run. GLSettings calls run() as the tree goes down, while
## the servers still live: nodes held outside the tree are freed, containers are emptied, resources are let go.

## Every `class_name` script that was loaded: its static variables are emptied. Returns [scripts, variables, nodes freed].
static func run() -> Array:
	var scripts: int = 0
	var vars: int = 0
	var nodes: int = 0
	for c: Dictionary in ProjectSettings.get_global_class_list():
		var path: String = str(c.get("path", ""))
		if path == "" or not ResourceLoader.has_cached(path) or path.ends_with("exit_sweep.gd"):
			continue
		if path.begins_with("res://addons/") or path.contains("/tests/"):
			continue   # the game's own scripts only (the test framework's statics have getters that load things)
		var s: GDScript = ResourceLoader.load(path) as GDScript
		if s == null:
			continue
		scripts += 1
		for p: Dictionary in s.get_property_list():
			if int(p.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
				continue
			var pname: String = str(p.get("name", ""))
			var v: Variant = s.get(pname)
			var t: int = typeof(v)
			if t == TYPE_OBJECT:
				if v != null:
					nodes += _drop(v)
					s.set(pname, null)
					vars += 1
			elif t == TYPE_DICTIONARY or t == TYPE_ARRAY:
				nodes += _drop(v)
				vars += 1
	return [scripts, vars, nodes]


## Frees the nodes outside the tree in `v` (a node, or an Array / Dictionary of anything, nested) and empties the
## containers. Returns how many nodes were freed.
static func _drop(v: Variant, depth: int = 0) -> int:
	var n: int = 0
	match typeof(v):
		TYPE_OBJECT:
			if is_instance_valid(v) and v is Node and not (v as Node).is_inside_tree() and not (v as Node).is_queued_for_deletion():
				(v as Node).free()
				n += 1
		TYPE_ARRAY:
			var a: Array = v
			if depth < 6:
				for e: Variant in a:
					n += _drop(e, depth + 1)
			if not a.is_read_only():
				a.clear()
		TYPE_DICTIONARY:
			var d: Dictionary = v
			if depth < 6:
				for k: Variant in d.keys():
					n += _drop(d[k], depth + 1)
					n += _drop(k, depth + 1)
			if not d.is_read_only():
				d.clear()
	return n
