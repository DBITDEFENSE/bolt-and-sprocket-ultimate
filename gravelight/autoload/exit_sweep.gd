class_name ExitSweep
extends RefCounted
## T-264: empties the scripts' static caches, and frees the nodes kept outside the tree, when the game quits.
##
## Many scripts keep meshes, materials, shaders and whole instantiated models in `static var` caches (the zombie
## bodies, the arms, the weapon models), and pools keep spare nodes outside the tree in their own variables.
## Statics outlive the scene tree, and a node outside the tree is never freed by it: the engine dropped them after
## the rendering server had shut down, and in an exported (release) build that ended every run with "Pages in use
## exist at exit", "double free or corruption" and a crash on the way out: exit code 134 / 139 on Linux, which macOS
## shows as "quit unexpectedly" and a handheld's launcher may count as a failed run. GLSettings calls run() as the
## tree goes down, while the servers still live.

## Every loaded `class_name` script and the script of every node still in the tree: their static variables are
## emptied; the nodes outside the tree that the tree's nodes still hold in their variables are freed.
## Returns [scripts, variables, nodes freed].
static func run(root: Node = null) -> Array:
	var seen: Dictionary = {}
	var out: Array = [0, 0, 0]
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	_tree_root = loop.root if loop != null else null
	for c: Dictionary in ProjectSettings.get_global_class_list():
		var path: String = str(c.get("path", ""))
		if path == "" or not ResourceLoader.has_cached(path):
			continue
		_statics(ResourceLoader.load(path) as GDScript, seen, out)
	if root != null:
		var stack: Array[Node] = [root]
		var held: Array = []
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			stack.append_array(n.get_children())
			var s: GDScript = n.get_script() as GDScript
			if s == null:
				continue
			_statics(s, seen, out)
			if not _ours(s.resource_path):
				continue
			for p: Dictionary in s.get_script_property_list():
				if int(p.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
					continue
				var t: int = int(p.get("type", TYPE_NIL))
				if t == TYPE_OBJECT or t == TYPE_ARRAY or t == TYPE_DICTIONARY or t == TYPE_NIL:
					held.append(n.get(str(p.get("name", ""))))
		for v: Variant in held:   # after the walk: freeing while walking could free a node still on the stack
			out[2] += _drop(v, 0, false)
	return out


## The tree's root while run() works: a node whose topmost ancestor is the root belongs to the tree (the engine
## frees it, even if it has already left the tree in this shutdown); any other branch is loose.
static var _tree_root: Node = null


static func _ours(path: String) -> bool:
	# the game's own scripts only (the test framework's statics have getters that load things)
	return path != "" and not path.begins_with("res://addons/") and not path.contains("/tests/") and not path.ends_with("exit_sweep.gd")


static func _statics(s: GDScript, seen: Dictionary, out: Array) -> void:
	while s != null:
		if seen.has(s) or not _ours(s.resource_path):
			return
		seen[s] = true
		out[0] += 1
		for p: Dictionary in s.get_property_list():
			if int(p.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
				continue
			var pname: String = str(p.get("name", ""))
			var v: Variant = s.get(pname)
			var t: int = typeof(v)
			if t == TYPE_OBJECT:
				if v != null:
					out[2] += _drop(v)
					s.set(pname, null)
					out[1] += 1
			elif t == TYPE_DICTIONARY or t == TYPE_ARRAY:
				out[2] += _drop(v)
				out[1] += 1
		s = s.get_base_script() as GDScript


## Frees the nodes outside the tree in `v` (a node, or an Array / Dictionary of anything, nested) and, with `empty`,
## empties the containers. Returns how many nodes were freed.
static func _drop(v: Variant, depth: int = 0, empty: bool = true) -> int:
	var n: int = 0
	match typeof(v):
		TYPE_OBJECT:
			if is_instance_valid(v) and v is Node and not (v as Node).is_queued_for_deletion():
				var top: Node = v as Node
				while top.get_parent() != null:   # a child of a node outside the tree: the whole loose branch goes
					top = top.get_parent()
				if top != _tree_root and not top.is_queued_for_deletion() and not (top is Window):
					top.free()
					n += 1
		TYPE_ARRAY:
			var a: Array = v
			if depth < 6:
				for e: Variant in a:
					n += _drop(e, depth + 1, empty)
			if empty and not a.is_read_only():
				a.clear()
		TYPE_DICTIONARY:
			var d: Dictionary = v
			if depth < 6:
				for k: Variant in d.keys():
					n += _drop(d[k], depth + 1, empty)
					n += _drop(k, depth + 1, empty)
			if empty and not d.is_read_only():
				d.clear()
	return n
