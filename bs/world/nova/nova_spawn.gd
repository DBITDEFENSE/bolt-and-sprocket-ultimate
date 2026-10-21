class_name NovaSpawn
extends RefCounted
## How Nova Plaza spawns enemies and bosses: through EnemySpawner.spawn(id, pos, parent, opts) (builder D),
## found at runtime so the level never hard-requires the enemy code. Ids the spawner doesn't list yet return
## null without calling it (so no "unknown enemy id" errors while D's work lands); with `stub_ok`, a
## StubEnemy (the level kit's damageable stand-in) takes the place of a missing enemy so encounters and
## quests still run. Every node gets meta "enemy_id" so QuestBook counts kills by type.

static var stubbed: Dictionary = {}       # id -> times a stub stood in (the smoke reports it)


## True when the spawner is present and (as far as it says) knows this id.
static func known(id: StringName) -> bool:
	var sp: Object = EnemyBridge.spawner()
	if sp == null:
		return false
	var consts: Dictionary = {}
	if sp is Script:
		consts = (sp as Script).get_script_constant_map()
	elif sp.get_script() != null:
		consts = (sp.get_script() as Script).get_script_constant_map()
	var scripts: Variant = consts.get("SCRIPTS", null)
	if not (scripts is Dictionary):
		return true          # a spawner without a SCRIPTS table: just ask it
	var rid: String = String(id)
	if sp.has_method("resolve_id"):
		rid = str(sp.call("resolve_id", id))
	return (scripts as Dictionary).has(rid)


static func spawn(id: StringName, pos: Vector3, parent: Node, opts: Dictionary = {}, stub_ok: bool = true) -> Node3D:
	var n: Node3D = null
	if not EnemyBridge.force_stub and known(id):
		var sp: Object = EnemyBridge.spawner()
		var r: Variant = sp.call("spawn", id, pos, parent, opts)
		n = r as Node3D
	if n == null:
		if not stub_ok:
			return null
		stubbed[String(id)] = int(stubbed.get(String(id), 0)) + 1
		EnemyBridge.used_stub = true
		var st: StubEnemy = StubEnemy.new()
		st.enemy_id = id
		n = st
	if n.get_parent() == null:
		parent.add_child(n)
		n.global_position = pos
	n.set_meta(&"enemy_id", String(id))
	return n
