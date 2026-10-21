class_name ZoningBoard
extends Node3D
## Zoning Board — NEW support/turret, three linked pylons (BS_ENEMIES §3.3).
## 3 pylons x 40 HP / 6 per 0.5 s zone tick, 10 for touching a beam / 4 bolts per pylon (12).
## EnemySpawner.spawn(&"zoning_board", pos, parent, opts) returns this controller; it spawns three
## `zoning_pylon` enemies on a triangle around `pos` (opts "side", default 10 m, at most 14) and links them
## with humming yellow beams. Bolt inside the triangle is "unpermitted": 6 damage every 0.5 s and SLOWED -20%.
## Touching a beam deals 10 (beams are low: jump them). Every 8 s the board RE-ZONES: the pylons telegraph
## 1.0 s (stamps rise, gavel triple-knock, the new triangle's floor paints with a yellow permit grid), then
## slide up to 5 m along their rails. BREAK THE LINK: once any pylon dies the triangle collapses and each
## remaining pylon projects only an r3 circle until destroyed.
## Elite (Variance Denied, yellow rim): dead pylons rebuild after 10 s unless all three die within 6 s.
## The controller is not itself damageable; is_alive() is true while any pylon lives (or a rebuild is pending),
## so encounters can wait on it. Signals: rezoned, link_broken, cleared.

signal rezoned
signal link_broken
signal cleared
signal telegraphed(kind: StringName, sfx: StringName, duration: float)

var id: StringName = &"zoning_board"
var def: Dictionary = {}
var opts: Dictionary = {}
var elite: bool = false
var pylons: Array[ZoningPylon] = []
var linked: bool = true
var rezones: int = 0
var zone_ticks: int = 0
var beam_hits: int = 0
var radius: float = 1.0
var _verts: Array[Vector3] = []      # rail origins (triangle vertices)
var _rail_dirs: Array[Vector3] = []
var _rezone_t: float = 8.0
var _tick_t: float = 0.0
var _beam_cd: float = 0.0
var _deaths: Dictionary = {}         # vertex index -> clock time of death
var _rebuild: Dictionary = {}        # vertex index -> seconds until rebuild
var _clock: float = 0.0
var _denied: bool = false
var _done: bool = false
var _beams: Array[MeshInstance3D] = []
var _floor: MeshInstance3D
var _floor_mesh: ImmediateMesh
var _paint: MeshInstance3D
var _paint_mesh: ImmediateMesh
var _paint_t: float = 0.0
var _circles: Array[MeshInstance3D] = []


func configure_spawn(id_: StringName, def_: Dictionary, opts_: Dictionary) -> void:
	id = id_
	def = def_
	opts = opts_


func ZB() -> Dictionary:
	return def["board"]


func _ready() -> void:
	if def.is_empty():
		def = EnemySpawner.def_for(&"zoning_board")
	EnemyBase.register_lines()
	elite = bool(opts.get("elite", false))
	add_to_group(&"enemy_groups")
	var side: float = minf(float(opts.get("side", ZB()["side"])), float(ZB()["max_side"]))
	var rr: float = side / sqrt(3.0)
	var a0: float = float(opts.get("yaw", 0.0))
	for i: int in 3:
		var a: float = a0 + TAU * i / 3.0
		var v: Vector3 = global_position + Vector3(cos(a) * rr, 0, sin(a) * rr)
		_verts.append(v)
		_rail_dirs.append(Vector3(-sin(a), 0, cos(a)))               # rails run tangent to the circumcircle
	_floor_mesh = ImmediateMesh.new()
	_floor = MeshInstance3D.new()
	_floor.mesh = _floor_mesh
	_floor.material_override = EnemyFx.glow(Color("#ffe84d"), 0.18)
	add_child(_floor)
	_paint_mesh = ImmediateMesh.new()
	_paint = MeshInstance3D.new()
	_paint.mesh = _paint_mesh
	_paint.material_override = EnemyFx.glow(Color("#ffe84d"), 0.4)
	_paint.visible = false
	add_child(_paint)
	for i: int in 3:
		var bm: MeshInstance3D = EnemyFx.box(self, Vector3(0.08, 0.08, 1.0), Vector3.ZERO, EnemyFx.glow(Color("#ffe84d"), 0.9))
		_beams.append(bm)
		var c: MeshInstance3D = EnemyFx.torus(self, float(ZB()["solo_r"]) - 0.1, float(ZB()["solo_r"]), Vector3.ZERO, EnemyFx.glow(Color("#ffe84d"), 0.6))
		c.scale = Vector3(1, 0.1, 1)
		c.visible = false
		_circles.append(c)
	_rezone_t = float(ZB()["rezone_every"])
	_spawn_pylons.call_deferred()


func _spawn_pylons() -> void:
	for i: int in 3:
		pylons.append(null)
		_spawn_pylon(i)


func _spawn_pylon(i: int) -> void:
	if get_parent() == null:
		return
	var n: Node3D = EnemySpawner.spawn(&"zoning_pylon", _verts[i], get_parent(),
		{"elite": elite, "aggro": bool(opts.get("aggro", true)), "is_add": bool(opts.get("is_add", false)), "spawn_time": 0.2})
	var p: ZoningPylon = n as ZoningPylon
	if p == null:
		return
	p.board = self
	p.rail_origin = _verts[i]
	p.rail_dir = _rail_dirs[i]
	p.set_meta(&"zoning_index", i)
	if not p.telegraphed.is_connected(_relay_tele):
		p.telegraphed.connect(_relay_tele)
	pylons[i] = p


func _relay_tele(kind: StringName, sfx: StringName, dur: float) -> void:
	telegraphed.emit(kind, sfx, dur)


func alive_pylons() -> Array[ZoningPylon]:
	var out: Array[ZoningPylon] = []
	for p: ZoningPylon in pylons:
		if p != null and is_instance_valid(p) and p.is_alive() and p.board == self:
			out.append(p)
	return out


func is_alive() -> bool:
	return not _done and (not alive_pylons().is_empty() or not _rebuild.is_empty() or pylons.is_empty())


func get_center() -> Vector3:
	var ps: Array[ZoningPylon] = alive_pylons()
	if ps.is_empty():
		return global_position
	var c: Vector3 = Vector3.ZERO
	for p: ZoningPylon in ps:
		c += p.get_center()
	return c / ps.size()


func _on_pylon_died(p: ZoningPylon) -> void:
	var i: int = int(p.get_meta(&"zoning_index", -1))
	if i < 0:
		return
	_deaths[i] = _clock
	if linked:
		linked = false
		link_broken.emit()
	if elite:
		if _deaths.size() >= 3:
			var lo: float = INF
			var hi: float = -INF
			for k: Variant in _deaths.keys():
				lo = minf(lo, float(_deaths[k]))
				hi = maxf(hi, float(_deaths[k]))
			if hi - lo <= float(def["elite"]["window"]):
				_denied = true
				_rebuild.clear()
		if not _denied:
			_rebuild[i] = float(def["elite"]["rebuild"])


func _physics_process(delta: float) -> void:
	if _done or pylons.is_empty():
		return
	_clock += delta
	_tick_t -= delta
	_beam_cd -= delta
	for k: Variant in _rebuild.keys():
		_rebuild[k] = float(_rebuild[k]) - delta
		if float(_rebuild[k]) <= 0.0:
			_rebuild.erase(k)
			_deaths.erase(k)
			_spawn_pylon(int(k))
			if alive_pylons().size() == 3:
				linked = true
	var ps: Array[ZoningPylon] = alive_pylons()
	if ps.is_empty() and _rebuild.is_empty():
		_done = true
		_floor.visible = false
		for b: MeshInstance3D in _beams:
			b.visible = false
		for c: MeshInstance3D in _circles:
			c.visible = false
		cleared.emit()
		return
	linked = linked and ps.size() == 3
	_update_visuals(ps)
	_hurt_bolt(ps)
	_paint_t -= delta
	_paint.visible = _paint_t > 0.0
	_rezone_t -= delta
	if _rezone_t <= 0.0:
		_rezone_t = float(ZB()["rezone_every"])
		_rezone(ps)


func _rezone(ps: Array[ZoningPylon]) -> void:
	var dur: float = float(ZB()["rezone_tele"])
	var new_pos: Array[Vector3] = []
	for i: int in 3:
		var p: ZoningPylon = pylons[i]
		var off: float = randf_range(-float(ZB()["rail"]), float(ZB()["rail"]))
		new_pos.append(_verts[i] + _rail_dirs[i] * off)
		if p != null and ps.has(p):
			p.start_rezone(new_pos[i], dur)
	rezones += 1
	if linked:
		_draw_tri(_paint_mesh, new_pos[0], new_pos[1], new_pos[2], 0.05)
		_paint_t = dur
	rezoned.emit()


func _update_visuals(ps: Array[ZoningPylon]) -> void:
	_floor.visible = linked
	for i: int in 3:
		var a: ZoningPylon = pylons[i]
		var b: ZoningPylon = pylons[(i + 1) % 3]
		var on: bool = linked and a != null and b != null
		_beams[i].visible = on
		if on:
			var pa: Vector3 = a.global_position + Vector3(0, float(ZB()["beam_h"]), 0)
			var pb: Vector3 = b.global_position + Vector3(0, float(ZB()["beam_h"]), 0)
			_beams[i].global_position = (pa + pb) * 0.5
			var dv: Vector3 = pb - pa
			_beams[i].global_basis = Basis.looking_at(dv.normalized() if dv.length_squared() > 0.001 else Vector3.FORWARD, Vector3.UP)
			_beams[i].scale = Vector3(1, 1, dv.length())
		_circles[i].visible = not linked and a != null and ps.has(a)
		if _circles[i].visible:
			_circles[i].global_position = a.global_position + Vector3(0, 0.05, 0)
	if linked:
		_draw_tri(_floor_mesh, pylons[0].global_position, pylons[1].global_position, pylons[2].global_position, 0.04)


func _draw_tri(m: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3, lift: float) -> void:
	m.clear_surfaces()
	m.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for v: Vector3 in [a, b, c]:
		m.surface_add_vertex(to_local(v + Vector3(0, lift, 0)))
	m.surface_end()


## Is `p` inside the NO-GO zone (the triangle while linked, else any pylon's r3 circle) and near the floor?
func in_zone(p: Vector3) -> bool:
	var ps: Array[ZoningPylon] = alive_pylons()
	if ps.is_empty():
		return false
	var base_y: float = ps[0].global_position.y
	if p.y - base_y > float(ZB()["zone_height"]):
		return false
	if linked and ps.size() == 3:
		return Geometry2D.point_is_inside_triangle(Vector2(p.x, p.z), _xz(pylons[0]), _xz(pylons[1]), _xz(pylons[2]))
	for q: ZoningPylon in ps:
		if Vector2(p.x - q.global_position.x, p.z - q.global_position.z).length() < float(ZB()["solo_r"]):
			return true
	return false


## Touching a beam: within 0.5 m (x/z) of an edge and low enough that he isn't jumping it.
func on_beam(p: Vector3) -> bool:
	if not linked:
		return false
	for i: int in 3:
		var a: ZoningPylon = pylons[i]
		var b: ZoningPylon = pylons[(i + 1) % 3]
		if a == null or b == null:
			continue
		if p.y - a.global_position.y > float(ZB()["beam_clear"]):
			continue
		var cp: Vector2 = Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.z), _xz(a), _xz(b))
		if cp.distance_to(Vector2(p.x, p.z)) < float(ZB()["beam_touch"]):
			return true
	return false


func _xz(n: Node3D) -> Vector2:
	return Vector2(n.global_position.x, n.global_position.z)


func _hurt_bolt(_ps: Array[ZoningPylon]) -> void:
	var bolt: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if bolt == null or not bool(bolt.call("is_alive")):
		return
	var p: Vector3 = bolt.global_position
	if on_beam(p) and _beam_cd <= 0.0:
		_beam_cd = float(ZB()["beam_cd"])
		beam_hits += 1
		EnemyBase.hurt_player(bolt, Combat.Hit.make(float(ZB()["beam_dmg"]), Combat.Type.ENERGY, self), self)
	if in_zone(p):
		var d: PlayerDebuffs = PlayerDebuffs.of(bolt)
		if d != null:
			d.slow(&"zoning", 1.0 - float(ZB()["slow"]), 0.25)
		if _tick_t <= 0.0:
			_tick_t = float(ZB()["tick_every"])
			zone_ticks += 1
			EnemyBase.hurt_player(bolt, Combat.Hit.make(float(ZB()["tick_dmg"]), Combat.Type.LEGAL, self), self)
