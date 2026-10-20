class_name EnemySpawner
extends RefCounted
## Spawns B&S enemies by id, with per-type pools (BS_ENEMIES §2.5).
##
##   EnemySpawner.spawn(&"scrap_mutt", pos, parent)            -> Node3D (an EnemyBase / BoltCrate / boss)
##   EnemySpawner.spawn(&"vulture_drone", pos, parent, {"elite": true})
##   opts: elite (bool), aggro (bool), leash (float), is_add (bool), ng_plus (bool), spawn_time (float)
##   EnemySpawner.prewarm(&"scrap_mutt", 12)                     pre-instantiate into the pool
##   EnemySpawner.clear_pool()                                   free pooled instances (level exit, tests)
## `parent` defaults to the current scene. Original ids ("scrapmutt", "vulture", "crate") are aliases.

const SCRIPTS: Dictionary = {
	"scrap_mutt": "res://bs/enemies/scrap_mutt.gd",
	"tinker_turret": "res://bs/enemies/tinker_turret.gd",
	"vulture_drone": "res://bs/enemies/vulture_drone.gd",
	"lien_crawler": "res://bs/enemies/lien_crawler.gd",
	"bolt_crate": "res://bs/enemies/bolt_crate.gd",
	"repo_tron": "res://bs/bosses/repo_tron.gd",
}

static var _pool: Dictionary = {}   # id -> Array of inactive EnemyBase


static func resolve_id(id: StringName) -> StringName:
	var t: Dictionary = Data.table("bs/enemies")
	var al: Dictionary = t.get("aliases", {})
	return StringName(str(al.get(String(id), String(id))))


static func def_for(id: StringName) -> Dictionary:
	var t: Dictionary = Data.table("bs/enemies")
	return ((t["enemies"] as Dictionary).get(String(resolve_id(id)), {}) as Dictionary)


static func spawn(id: StringName, pos: Vector3, parent: Node = null, opts: Dictionary = {}) -> Node3D:
	id = resolve_id(id)
	if not SCRIPTS.has(String(id)):
		push_error("EnemySpawner: unknown enemy id %s" % id)
		return null
	if parent == null:
		var ml: SceneTree = Engine.get_main_loop() as SceneTree
		parent = ml.current_scene if ml != null and ml.current_scene != null else ml.root
	var n: Node3D = _take(id)
	var e: EnemyBase = n as EnemyBase
	if e != null:
		e.configure(id, def_for(id), opts)
	n.position = pos
	parent.add_child(n)
	n.global_position = pos
	if e != null:
		e.activate()
	return n


static func _take(id: StringName) -> Node3D:
	var arr: Array = _pool.get(String(id), [])
	while not arr.is_empty():
		var n: Variant = arr.pop_back()
		if is_instance_valid(n):
			return n as Node3D
	var s: GDScript = load(SCRIPTS[String(id)]) as GDScript
	var inst: Node3D = s.new() as Node3D
	if inst is EnemyBase:
		(inst as EnemyBase).pooled = (Data.table("bs/enemies")["enemies"] as Dictionary).has(String(id))
		(inst as EnemyBase).id = id
	return inst


## Returns a finished enemy to its pool (EnemyBase calls this after its death fade).
static func release(e: EnemyBase) -> void:
	if e.get_parent() != null:
		e.get_parent().remove_child(e)
	var arr: Array = _pool.get(String(e.id), [])
	arr.append(e)
	_pool[String(e.id)] = arr


static func prewarm(id: StringName, n: int) -> void:
	id = resolve_id(id)
	var arr: Array = _pool.get(String(id), [])
	while arr.size() < n:
		var inst: Node3D = _take(id)
		var e: EnemyBase = inst as EnemyBase
		if e == null:
			inst.free()
			return
		e.configure(id, def_for(id))
		arr.append(e)
	_pool[String(id)] = arr


static func pooled_count(id: StringName) -> int:
	return (_pool.get(String(resolve_id(id)), []) as Array).size()


static func clear_pool() -> void:
	for k: Variant in _pool.keys():
		for n: Variant in _pool[k]:
			if is_instance_valid(n):
				(n as Node).free()
	_pool.clear()
	EnemyProjectile.clear_pool()
	AttackTokens.reset()
