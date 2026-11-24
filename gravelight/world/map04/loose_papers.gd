class_name LoosePapers
extends Node3D
## T-274 (the map detail pass on the Fernflug acts): loose sheets of paper lying on a floor or a desk top (the node's
## local y = 0 is the surface). They lie still, drawn as one MultiMesh (one draw call), until something disturbs
## them: a body moving through them (players and zombies: physics layers 2 and 3), a blast close by (GLBus.explosion)
## or a call to blow() (Der Kranich's decompression pulls them out through the breach). Then the sheets near it lift,
## tumble and drift down again, and lie where they land; a sheet pulled into `blow`'s sink is gone for the match.
## `gravity` sets the fall (the Moon's 1.62: they float down slowly). Presentation only, every peer runs its own;
## nothing collides. Idle (no processing) while nothing moves and nobody is in its box.

const BODY_MASK: int = (1 << 1) | (1 << 2)
const SHEET: Vector3 = Vector3(0.21, 0.003, 0.297)
const FAR_M: float = 35.0
const SOUND: String = "amb_m2_paper"

@export var count: int = 8
## Where the sheets lie: a box in the node's frame (y is ignored: they lie at y = 0), and how far beyond it they may
## drift before they stop (a desk's sheets fall to the floor `floor_drop` m below).
@export var size: Vector3 = Vector3(2.0, 0.0, 1.5)
@export var floor_drop: float = 0.0
@export var seed_value: int = 1
@export var gravity: float = 9.8
@export var mat_key: String = "paper_old"

var pos: PackedVector3Array = PackedVector3Array()
var vel: PackedVector3Array = PackedVector3Array()
var rot: PackedVector3Array = PackedVector3Array()    # yaw, pitch, roll (radians)
var spin: PackedVector3Array = PackedVector3Array()
var gone: PackedByteArray = PackedByteArray()
var flying: int = 0
## How many times a sheet has been lifted (tests).
var lifts: int = 0
var _mm: MultiMesh = null
var _bodies: Array[Node3D] = []
var _poll: float = 0.0
var _sound_cd: float = 0.0
var _sink: Vector3 = Vector3.INF


func _ready() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	for i: int in count:
		pos.append(Vector3(rng.randf_range(-0.5, 0.5) * size.x, 0.002 + 0.001 * i, rng.randf_range(-0.5, 0.5) * size.z))
		vel.append(Vector3.ZERO)
		rot.append(Vector3(rng.randf() * TAU, 0.0, 0.0))
		spin.append(Vector3.ZERO)
		gone.append(0)
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.mesh = Props.unit_box()
	_mm.instance_count = count
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.name = "Sheets"
	mmi.multimesh = _mm
	mmi.material_override = Mats.get_mat(mat_key)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	for i2: int in count:
		_draw(i2)
	var zone: Area3D = Area3D.new()
	zone.name = "Stir"
	zone.collision_layer = 0
	zone.collision_mask = BODY_MASK
	zone.monitorable = false
	var cs: CollisionShape3D = CollisionShape3D.new()
	var b: BoxShape3D = BoxShape3D.new()
	b.size = Vector3(size.x + 1.2, 2.0, size.z + 1.2)
	cs.shape = b
	cs.position = Vector3(0, 1.0 - floor_drop, 0)
	zone.add_child(cs)
	add_child(zone)
	zone.body_entered.connect(func(n: Node3D) -> void:
		_bodies.append(n)
		set_process(true))
	zone.body_exited.connect(func(n: Node3D) -> void: _bodies.erase(n))
	if not GLBus.explosion.is_connected(_on_explosion):
		GLBus.explosion.connect(_on_explosion)
	set_process(false)


func _draw(i: int) -> void:
	if gone[i] != 0:
		_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), pos[i]))
		return
	var r: Vector3 = rot[i]
	var bs: Basis = Basis.from_euler(Vector3(r.y, r.x, r.z)) * Basis.from_scale(SHEET)
	_mm.set_instance_transform(i, Transform3D(bs, pos[i]))


## Lift sheet `i` with velocity `v` (local).
func lift(i: int, v: Vector3) -> void:
	if i < 0 or i >= count or gone[i] != 0:
		return
	if vel[i] == Vector3.ZERO and pos[i].y <= 0.01:
		flying += 1
		lifts += 1
	vel[i] = v
	spin[i] = Vector3(randf_range(-6.0, 6.0), randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
	set_process(true)
	if _sound_cd <= 0.0 and AudioDirector.has_sound(SOUND):
		_sound_cd = 1.2
		AudioDirector.play_3d(SOUND, to_global(pos[i]), -8.0, 0.15)


## A gust from (or, with `sink`, toward and out through) a global point: every sheet within `radius` m is thrown.
## Sheets that reach the sink are gone.
func blow(at: Vector3, strength: float = 6.0, radius: float = 12.0, sink: bool = false) -> void:
	var local: Vector3 = to_local(at)
	if sink:
		_sink = local
	for i: int in count:
		var d: Vector3 = local - pos[i]
		if d.length() > radius or gone[i] != 0:
			continue
		var dir: Vector3 = (d if sink else -d).normalized()
		lift(i, dir * strength * randf_range(0.7, 1.2) + Vector3.UP * randf_range(0.6, 1.6))


func _on_explosion(at: Vector3, radius: float) -> void:
	if is_inside_tree() and to_local(at).length() < radius * 1.5 + maxf(size.x, size.z):
		blow(at, 5.0, radius * 1.5)


func _process(delta: float) -> void:
	_sound_cd -= delta
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	var far: bool = cam != null and cam.global_position.distance_squared_to(global_position) > FAR_M * FAR_M
	_poll -= delta
	if _poll <= 0.0 and not _bodies.is_empty():
		_poll = 0.15
		for n: Node3D in _bodies:
			if not is_instance_valid(n):
				continue
			var bv: Vector3 = n.get("velocity") if n.get("velocity") is Vector3 else Vector3.ZERO
			if Vector2(bv.x, bv.z).length() < 1.2:
				continue
			var lp: Vector3 = to_local(n.global_position)
			for i: int in count:
				var dd: Vector3 = pos[i] - lp
				if Vector2(dd.x, dd.z).length() < 0.9 and vel[i] == Vector3.ZERO:
					var push: Vector3 = (global_transform.basis.inverse() * bv) * 0.35
					lift(i, Vector3(push.x, randf_range(1.0, 2.2), push.z))
	if flying == 0:
		if _bodies.is_empty():
			set_process(false)
		return
	var term: float = -clampf(gravity * 0.12, 0.25, 1.4)   # a sheet falls at its own slow speed
	for i: int in count:
		if vel[i] == Vector3.ZERO or gone[i] != 0:
			continue
		var v: Vector3 = vel[i]
		v.y = maxf(v.y - gravity * delta, term)
		var drag: float = clampf(1.0 - 1.6 * delta, 0.0, 1.0)
		v.x *= drag
		v.z *= drag
		pos[i] += v * delta + Vector3(sin(Time.get_ticks_msec() * 0.004 + i) * 0.15, 0, cos(Time.get_ticks_msec() * 0.003 + i) * 0.15) * delta
		rot[i] += spin[i] * delta
		spin[i] *= clampf(1.0 - 0.8 * delta, 0.0, 1.0)
		var floor_y: float = 0.002 if absf(pos[i].x) <= size.x * 0.5 + 0.1 and absf(pos[i].z) <= size.z * 0.5 + 0.1 else -floor_drop + 0.002
		if _sink != Vector3.INF and pos[i].distance_to(_sink) < 1.0:
			gone[i] = 1
			vel[i] = Vector3.ZERO
			flying -= 1
		elif pos[i].y <= floor_y and v.y <= 0.0:
			pos[i].y = floor_y + 0.001 * i
			rot[i] = Vector3(rot[i].x, 0.0, 0.0)
			vel[i] = Vector3.ZERO
			flying -= 1
		else:
			vel[i] = v
		if not far:
			_draw(i)
	if far:
		for j: int in count:
			_draw(j)
