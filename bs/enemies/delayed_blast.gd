class_name DelayedBlast
extends Node3D
## A ground-targeted attack: a decal glows for `delay` seconds (the telegraph), then the area blasts once and
## hurts Bolt if he is inside it and near the ground (within `max_height` of the decal; jumping/platforms dodge).
## Circle (Algorithm VIOLATION zones, Mega-Fine, SPONSORED bomb) or square (the Content Creator's LIKE tiles).
## Silent: `blasted(hit_player)` is the hook for sound/FX. on_blast: Callable(hit_player: bool) also fires.

signal blasted(hit_player: bool)

var center: Vector3 = Vector3.ZERO
var r: float = 3.0
var square: bool = false
var delay: float = 1.0
var dmg: float = 18.0
var knock: float = 6.0
var max_height: float = 1.9
var kind: StringName = &""
var source: Node = null
var color: Color = Color("#ff4d9d")
var on_blast: Callable = Callable()
var shrink: bool = false
var done: bool = false
var _t: float = 0.0
var _decal: TelegraphDecal


static func spawn(parent: Node, center_: Vector3, r_: float, delay_: float, dmg_: float, color_: Color,
		source_: Node = null, opts: Dictionary = {}) -> DelayedBlast:
	var d: DelayedBlast = DelayedBlast.new()
	d.center = center_
	d.r = r_
	d.delay = maxf(delay_, 0.01)
	d.dmg = dmg_
	d.color = color_
	d.source = source_
	d.square = bool(opts.get("square", false))
	d.shrink = bool(opts.get("shrink", false))
	d.kind = StringName(str(opts.get("kind", "")))
	d.max_height = float(opts.get("max_height", 1.9))
	d.knock = float(opts.get("knock", 6.0))
	d.on_blast = opts.get("on_blast", Callable())
	parent.add_child(d)
	d.global_position = center_
	if d.square:
		d._decal = EnemyFx.lane(parent, center_ + Vector3(0, 0, r_), Vector3.FORWARD, r_ * 2.0, r_ * 2.0, d.delay, color_)
	else:
		d._decal = EnemyFx.ring(parent, center_, r_, d.delay, color_)
	d.center.y = d._decal.global_position.y if d._decal != null and d._decal.is_inside_tree() else center_.y
	return d


func time_left() -> float:
	return delay - _t


func cancel() -> void:
	done = true
	if _decal != null and is_instance_valid(_decal):
		_decal.queue_free()
	queue_free()


func contains(p: Vector3) -> bool:
	if p.y - center.y > max_height:
		return false
	if square:
		return absf(p.x - center.x) <= r and absf(p.z - center.z) <= r
	return Vector2(p.x - center.x, p.z - center.z).length() < r


func _physics_process(delta: float) -> void:
	if done:
		return
	_t += delta
	if shrink and _decal != null and is_instance_valid(_decal):
		var k: float = 0.4 + 0.6 * clampf(1.0 - _t / delay, 0.0, 1.0)
		_decal.scale = Vector3(k, 1, k)
	if _t < delay:
		return
	done = true
	var hit_player: bool = false
	var bolt: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if bolt != null and bool(bolt.call("is_alive")) and contains(bolt.global_position):
		var h: Combat.Hit = Combat.Hit.make(dmg, Combat.Type.KINETIC, source)
		h.point = bolt.global_position
		var dd: Vector3 = bolt.global_position - center
		h.dir = Vector3(dd.x, 0, dd.z).normalized()
		h.knock = knock
		hit_player = EnemyBase.hurt_player(bolt, h, source)
	EnemyFx.ring(get_parent(), center, r, 0.25, Color.WHITE if not square else color)
	blasted.emit(hit_player)
	if on_blast.is_valid():
		on_blast.call(hit_player)
	queue_free()
