class_name EnemyBridge
extends RefCounted
## How the level spawns enemies without depending on the enemy builder's files at compile time.
## Prefers EnemySpawner (an autoload node or a global class with a static spawn(id, pos[, parent])). If it is
## missing, or returns null for an id, a StubEnemy stands in so the level still plays and tests still run.
## Every spawned node gets meta "enemy_id" so quests can count kills by type.

static var force_stub: bool = false
static var used_stub: bool = false        # true once any stub was spawned (reported by the smoke test)


static func spawner() -> Object:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null:
		var n: Node = tree.root.get_node_or_null(^"EnemySpawner")
		if n != null and n.has_method("spawn"):
			return n
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if str(c.get("class", "")) == "EnemySpawner":
			var s: Script = load(str(c["path"])) as Script
			if s != null:
				return s
	return null


static func has_spawner() -> bool:
	return spawner() != null


static func spawn(id: StringName, pos: Vector3, parent: Node) -> Node3D:
	var n: Node3D = null
	if not force_stub:
		var sp: Object = spawner()
		if sp != null:
			var argc: int = _spawn_argc(sp)
			var r: Variant = sp.call("spawn", id, pos, parent) if argc >= 3 else sp.call("spawn", id, pos)
			n = r as Node3D
	if n == null:
		used_stub = true
		var st: StubEnemy = StubEnemy.new()
		st.enemy_id = id
		n = st
	if n.get_parent() == null:
		parent.add_child(n)
		n.global_position = pos
	n.set_meta(&"enemy_id", String(id))
	return n


static func _spawn_argc(sp: Object) -> int:
	var methods: Array[Dictionary] = []
	if sp is Script:
		methods = (sp as Script).get_script_method_list()
	else:
		methods = sp.get_method_list()
	for m: Dictionary in methods:
		if str(m.get("name", "")) == "spawn":
			return (m.get("args", []) as Array).size()
	return 3


## The remake enemy id of a node ("scrap_mutt"), from meta or a property; "" if unknown.
static func enemy_id(enemy: Node) -> String:
	if enemy == null or not is_instance_valid(enemy):
		return ""
	if enemy.has_meta(&"enemy_id"):
		return str(enemy.get_meta(&"enemy_id"))
	for p: String in ["enemy_id", "id", "def_id", "kind"]:
		var v: Variant = enemy.get(p)
		if v is String or v is StringName:
			if str(v) != "":
				return str(v)
	return ""
