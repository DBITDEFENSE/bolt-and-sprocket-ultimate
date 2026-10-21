class_name PatternBoss
extends BossBase
## Shared fight loop for the M3 bosses (Rustvane Sentinel, The Content Creator, The Algorithm), on top of
## BossBase's BREAK / phases / armour / lines. RepoTron keeps its own loop.
##
## Loop: wait for aggro -> start_fight(); then CHASE (idle: _idle_tick moves/faces; idle_t counts down) ->
## pick an attack (force_next for tests and cutscenes, else _pick()) -> _start(kind) begins a TELEGRAPH
## (>= 0.4 s, every boss attack) -> _attack_start(kind) -> ATTACK ticks _attack_tick(kind) until it returns
## true -> back to CHASE with idle_t = _idle_after(kind). STAGGER (BREAK, self-stun) counts stun_t down.
## Parallel attacks (mortars, zones, rain) run from _fight_tick() and call log_parallel(kind, tele) so every
## attack, sequenced or not, lands in attacks_done / tele_log (tests and the smoke check those).
##
## Arena: opts["arena"] (a Node3D from the planet builder) or, when absent, a minimal arena the boss builds
## itself (_build_default_arena). anchor(name) / anchors(prefix) find named children (recursive).
## arena_mid is the arena centre ("Center" child if present, else the arena node's origin); arena_size its
## x/z extent (meta or property "size", Vector2 or Vector3; else the boss's bosses.json "arena_size").

signal attack_logged(kind: StringName, tele: float)

var R: Dictionary = {}
var idle_t: float = 1.5
var force_next: StringName = &""
var attacks_done: Dictionary = {}       # kind -> count
var tele_log: Dictionary = {}           # kind -> shortest telegraph seen (s)
var adds: Array[Node3D] = []
var arena_node: Node3D = null
var arena_owned: bool = false
var arena_mid: Vector3 = Vector3.ZERO
var arena_size: Vector2 = Vector2(30, 30)
var phase_log: Array[int] = []


func _load_tables() -> void:
	super._load_tables()
	R = bdef


## Per-phase value: arrays are indexed by phase, scalars returned as-is.
func ph(v: Variant) -> float:
	if v is Array:
		var a: Array = v
		return float(a[clampi(phase - 1, 0, a.size() - 1)])
	return float(v)


func _boss_activate() -> void:
	idle_t = float(R.get("first_idle", 1.5))
	force_next = &""
	attacks_done.clear()
	tele_log.clear()
	adds.clear()
	phase_log = [1]
	_resolve_arena()
	_pattern_activate()


func _pattern_activate() -> void:
	pass


# ------------------------------------------------------------------ arena

func _resolve_arena() -> void:
	var a: Variant = opts.get("arena", null)
	if a is Node3D and is_instance_valid(a):
		arena_node = a as Node3D
		arena_owned = false
	elif arena_node == null or not is_instance_valid(arena_node) or not arena_owned:
		arena_node = _build_default_arena()
		arena_owned = arena_node != null
	if arena_node == null:
		arena_mid = global_position
		return
	var c: Node3D = anchor(&"Center")
	if c != null:
		arena_mid = _gpos(c)
	elif arena_owned:
		arena_mid = global_position
	else:
		arena_mid = _gpos(arena_node)
	var sz: Variant = arena_node.get_meta(&"size", null) if arena_node.has_meta(&"size") else arena_node.get(&"size")
	if sz == null and c != null and c.has_meta(&"size"):
		sz = c.get_meta(&"size")
	if sz is Vector2:
		arena_size = sz
	elif sz is Vector3:
		arena_size = Vector2((sz as Vector3).x, (sz as Vector3).z)
	else:
		var d: Array = R.get("arena_size", [30, 30])
		arena_size = Vector2(float(d[0]), float(d[1]))


## Global position of a node that may still be waiting for a deferred add_child.
func _gpos(n: Node3D) -> Vector3:
	if n.is_inside_tree():
		return n.global_position
	var p: Vector3 = n.position
	var par: Node = n.get_parent()
	while par != null and par is Node3D and not (par as Node3D).is_inside_tree():
		p = (par as Node3D).transform * p
		par = par.get_parent()
	if par is Node3D:
		return (par as Node3D).global_transform * p
	return p


## Builds the boss's own arena (markers and props) when the planet doesn't pass one. Subclasses override and
## return a Node3D whose children carry the documented anchor names. Default: none.
func _build_default_arena() -> Node3D:
	return null


## Adds an arena built by the boss next to it (deferred: the parent may be busy) at the boss's spawn spot.
func _attach_arena(a: Node3D) -> void:
	a.name = "%sArena" % String(boss_id).capitalize().replace(" ", "")
	a.set_meta(&"built_by_boss", String(boss_id))
	var p: Node = get_parent()
	if p == null:
		return
	a.position = position
	p.add_child.call_deferred(a)


func anchor(nm: StringName) -> Node3D:
	if arena_node == null or not is_instance_valid(arena_node):
		return null
	return arena_node.find_child(String(nm), true, false) as Node3D


## The arena's own method, when the planet's arena node has it (e.g. FineTreeArena.set_doomscroll).
func arena_call(method: StringName, args: Array = []) -> bool:
	if arena_node == null or not is_instance_valid(arena_node) or arena_owned or not arena_node.has_method(method):
		return false
	arena_node.callv(method, args)
	return true


func anchors(prefix: String) -> Array[Node3D]:
	var out: Array[Node3D] = []
	if arena_node == null or not is_instance_valid(arena_node):
		return out
	_collect(arena_node, prefix, out)
	return out


func _collect(n: Node, prefix: String, out: Array[Node3D]) -> void:
	for c: Node in n.get_children():
		if c is Node3D and String(c.name).begins_with(prefix):
			out.append(c as Node3D)
		_collect(c, prefix, out)


## A static box for a built arena (world layer), centred at local `pos` in `a`.
static func arena_box(a: Node3D, nm: String, size: Vector3, pos: Vector3, c: Color) -> StaticBody3D:
	var b: StaticBody3D = StaticBody3D.new()
	b.name = nm
	b.collision_layer = 1
	b.position = pos
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	EnemyFx.box(b, size, Vector3.ZERO, EnemyFx.mat(c))
	a.add_child(b)
	return b


static func arena_marker(a: Node3D, nm: String, pos: Vector3) -> Marker3D:
	var m: Marker3D = Marker3D.new()
	m.name = nm
	m.position = pos
	a.add_child(m)
	return m


## True when nothing solid is under the boss (it then builds a floor for a standalone fight).
func _needs_floor() -> bool:
	if not is_inside_tree():
		return false
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, global_position + Vector3.DOWN * 4.0, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


# ------------------------------------------------------------------ fight loop

func _ai(dt: float) -> void:
	if not started:
		desired_vel = Vector3.ZERO
		_perceive(dt)
		if target_alive() and (dist_to_target() < aggro_radius or aggro):
			start_fight()
		return
	if not target_alive():
		desired_vel = Vector3.ZERO
		return
	adds = adds.filter(func(a: Node3D) -> bool: return is_instance_valid(a) and a.is_inside_tree() and bool(a.call("is_alive")))
	_fight_tick(dt)
	match state:
		State.STAGGER:
			stun_t -= dt
			desired_vel = Vector3.ZERO
			visual.rotation.z = sin(t * 18.0) * 0.04
			_stagger_tick(dt)
			if stun_t <= 0.0:
				visual.rotation.z = 0.0
				idle_t = maxf(idle_t, 0.8)
				_set_state(State.CHASE)
		State.TELEGRAPH:
			tele_t -= dt * attack_rate()
			desired_vel = Vector3.ZERO
			_tick_light()
			_tele_tick(attack_kind, dt)
			if tele_t <= 0.0 and state == State.TELEGRAPH:
				_end_telegraph_fx()
				var k: StringName = attack_kind
				_set_state(State.ATTACK)
				_record(k, tele_dur)
				attacked.emit(k)
				_attack_start(k)
		State.ATTACK:
			if _attack_tick(attack_kind, dt) and state == State.ATTACK:
				idle_t = _idle_after(attack_kind)
				desired_vel = Vector3.ZERO
				_set_state(State.CHASE)
		_:
			if state != State.CHASE:
				_set_state(State.CHASE)
			_idle_tick(dt)
			idle_t -= dt
			if idle_t <= 0.0 and can_attack():
				var kind: StringName = force_next
				force_next = &""
				if kind == &"" or not _allowed(kind):
					kind = _pick()
				if kind != &"":
					_start(kind)
				else:
					idle_t = 0.5


func _record(kind: StringName, tele: float) -> void:
	attacks_done[kind] = int(attacks_done.get(kind, 0)) + 1
	tele_log[kind] = minf(float(tele_log.get(kind, INF)), tele)
	attack_logged.emit(kind, tele)


## A parallel attack (not part of the sequenced loop) telegraphed for `tele` seconds: logs it and emits
## telegraphed + attacked so it shows up exactly like a sequenced one.
func log_parallel(kind: StringName, tele: float, sfx: StringName = &"") -> void:
	telegraphed.emit(kind, sfx, tele)
	_record(kind, tele)
	attacked.emit(kind)


## Ends the current attack early (from inside _attack_tick paths that bail).
func end_attack(idle: float) -> void:
	idle_t = idle
	desired_vel = Vector3.ZERO
	_set_state(State.CHASE)


func self_stun(seconds: float, break_frac_of_threshold: float, kind: StringName = &"self_stun") -> void:
	cancel_attack()
	stun_t = maxf(stun_t, seconds)
	_set_state(State.STAGGER)
	add_break(break_threshold() * break_frac_of_threshold)
	telegraphed.emit(kind, &"boss_clank", seconds)


func spawn_add(add_id: StringName, pos: Vector3, extra: Dictionary = {}) -> Node3D:
	if get_parent() == null:
		return null
	var o: Dictionary = {"is_add": true, "aggro": true, "leash": float(G.get("arena_leash", 30.0))}
	o.merge(extra, true)
	var a: Node3D = EnemySpawner.spawn(add_id, pos, get_parent(), o)
	if a != null:
		adds.append(a)
	return a


## Lobs a mortar shell that lands at `land` after `flight` s (>= 0.6), with a landing ring for the whole flight.
func lob_shell(from: Vector3, land: Vector3, flight: float, dmg: float, c: Color, ring_r: float, extra: Dictionary = {}) -> EnemyProjectile:
	flight = maxf(flight, float(R.get("min_landing_ring", 0.6)))
	var g: float = float(extra.get("grav", 14.0))
	var gy: float = EnemyFx.floor_y(self, land, land.y)
	var to: Vector3 = Vector3(land.x, gy + 0.25, land.z)
	EnemyFx.ring(get_parent(), to, ring_r, flight, c)
	var d: Vector3 = to - from
	var v: Vector3 = Vector3(d.x / flight, (d.y + 0.5 * g * flight * flight) / flight, d.z / flight)
	var o: Dictionary = {"grav": g, "boom_r": ring_r, "source": self}
	o.merge(extra, true)
	return EnemyProjectile.fire(get_parent(), from, v, dmg * out_mult(), c, float(extra.get("size", 0.3)), flight + 1.5, o)


func _enter_phase(p: int) -> void:
	super._enter_phase(p)
	phase_log.append(p)
	idle_t = maxf(idle_t, float(R.get("phase_idle", 1.0)))


func _on_attack_cancelled() -> void:
	desired_vel = Vector3.ZERO
	idle_t = maxf(idle_t, 0.8)
	_pattern_cancelled()


func _boss_died(hit: Combat.Hit) -> void:
	for a: Node3D in adds:
		if is_instance_valid(a) and a.has_method("is_alive") and bool(a.call("is_alive")) and bool(R.get("adds_die_with_boss", false)):
			var h: Combat.Hit = Combat.Hit.make(1.0e6)
			h.weapon_id = &"boss_down"
			a.call("take_damage", h)
	_pattern_died(hit)


## Everything the smoke test and tests want to know about the fight so far.
func fight_report() -> Dictionary:
	return {"phase": phase, "phases_seen": phase_log.duplicate(), "attacks": attacks_done.duplicate(), "tele": tele_log.duplicate(),
		"breaks": breaks, "defeated": defeated}


# ------------------------------------------------------------------ hooks for subclasses

func _fight_tick(_dt: float) -> void:
	pass


func _idle_tick(_dt: float) -> void:
	desired_vel = Vector3.ZERO
	if target != null:
		face(target_pos() - global_position, _dt, 2.0)


func _stagger_tick(_dt: float) -> void:
	pass


func _allowed(_kind: StringName) -> bool:
	return true


func _pick() -> StringName:
	return &""


func _start(kind: StringName) -> void:
	begin_telegraph(kind)


func _tele_tick(_kind: StringName, _dt: float) -> void:
	pass


func _attack_start(_kind: StringName) -> void:
	pass


func _attack_tick(_kind: StringName, _dt: float) -> bool:
	return true


func _idle_after(_kind: StringName) -> float:
	return 1.5


func _pattern_cancelled() -> void:
	pass


func _pattern_died(_hit: Combat.Hit) -> void:
	pass
