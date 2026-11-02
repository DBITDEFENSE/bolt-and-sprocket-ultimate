class_name RivetLineTrap
extends Node3D
## Werk Thalbach's rivet line (UPDATE 10 §3 Act I, contract C6 `rivet_line`, DECISIONS T-155; tuning traps.json
## "rivet_line"): a powered trap in Montage 1. The lever (a TrapLever on the Kraftzentrale's east wall, 1000, needs
## the works' power) starts the overhead rivet gantry: after a `warn_seconds` klaxon its carriage runs the hall's
## south aisle on its rail, end to end (`pass_seconds` a pass) for `duration` s, its four pneumatic hammers
## pounding the floor; anything under the carriage (`carriage_len` along the rail × `carriage_width` across) is
## riveted: zombies die (the kill to whoever paid), players go down. Sparks fly off the hammers, the hammer loop
## rides on the carriage. `cooldown` s after it stops (Deacon's trait shortens it). Bots keep out of the strip while
## it runs (danger_contains). Host-authoritative damage; clients run the show (TrapLever mirrors activate).

const KEY: String = "rivet_line"

@export var track_start: Vector3 = Vector3(-21.0, 0, 0)
@export var track_end: Vector3 = Vector3(21.0, 0, 0)
@export var rail_y: float = 6.4
@export var needs_power: bool = true

var active: bool = false
var cooldown_left: float = 0.0
var kills: int = 0
var _t: float = 0.0
var _warn_left: float = 0.0
var _by: int = 0
var _carriage: Node3D
var _hammers: Array[Node3D] = []
var _sparks: GPUParticles3D
var _loop: AudioStreamPlayer3D
var _strike_t: float = 0.0


func _ready() -> void:
	add_to_group(&"traps")
	add_to_group(&"a1_rivet_line")
	_build()


func _cfg() -> Dictionary:
	return TrapLever.cfg_for(KEY)


## Pure: the carriage's position along the rail (0..1) after t seconds, shuttling end to end.
static func shuttle(t: float, pass_seconds: float) -> float:
	var cycle: float = fmod(t / maxf(0.01, pass_seconds), 2.0)
	return cycle if cycle <= 1.0 else 2.0 - cycle


## Pure: is `p` under the carriage at `c` (rail axis `axis`)? The hammers reach the floor; a body on a jig deck
## (more than 2 m up) is above them.
static func under(p: Vector3, c: Vector3, axis: Vector3, length: float, width: float) -> bool:
	var d: Vector3 = Vector3(p.x - c.x, 0.0, p.z - c.z)
	if p.y - c.y > 2.0 or p.y < c.y - 1.0:
		return false
	var along: float = absf(d.dot(axis))
	var side: float = (d - axis * d.dot(axis)).length()
	return along <= length * 0.5 and side <= width * 0.5


## Pure: may it be bought now?
static func can_run(power: bool, needs: bool, running: bool, cool_left: float) -> bool:
	return (power or not needs) and not running and cool_left <= 0.0


func trap_name() -> String:
	return "Rivet Line"


func cost() -> int:
	return int(_cfg().get("cost", 1000))


func can_activate() -> bool:
	return can_run(GameState.power_on, needs_power, active, cooldown_left)


func status_text() -> String:
	if needs_power and not GameState.power_on:
		return "The rivet line needs the works' power"
	if active:
		return "The rivet line is running"
	return "Rivet line cooling down... %d" % int(ceil(cooldown_left))


func activate(by_player: int) -> bool:
	if active:
		return false
	if Net.is_authority() and not can_activate():
		return false
	active = true
	_by = by_player
	_t = 0.0
	_strike_t = 0.0
	_warn_left = float(_cfg().get("warn_seconds", 1.5))
	GameState.set_flag(&"rivet_line_running")
	AudioDirector.play_3d("cart_bell", to_global(track_start) + Vector3.UP * 3.0, 4.0, 0.0)
	AudioDirector.play_3d("cart_bell", to_global(track_end) + Vector3.UP * 3.0, 4.0, 0.0)
	AudioDirector.play_3d("power_on", _carriage.global_position, 0.0, 0.0)
	return true


## The capture tool's and the dev console's way in (no lever, no price): run it now.
func show_run() -> void:
	activate(0)


func _physics_process(delta: float) -> void:
	if not active:
		if cooldown_left > 0.0:
			cooldown_left = maxf(0.0, cooldown_left - delta)
		_settle_hammers(delta)
		return
	if _warn_left > 0.0:
		_warn_left -= delta
		return
	var c: Dictionary = _cfg()
	if _loop != null and not _loop.playing:
		_loop.play()
	_t += delta
	_carriage.position = Vector3(track_start.x, rail_y, track_start.z).lerp(Vector3(track_end.x, rail_y, track_end.z), shuttle(_t, float(c.get("pass_seconds", 5.5))))
	_animate_hammers(delta)
	var foot: Vector3 = Vector3(_carriage.global_position.x, global_position.y, _carriage.global_position.z)
	var axis: Vector3 = (to_global(track_end) - to_global(track_start)).normalized()
	var ln: float = float(c.get("carriage_len", 3.0))
	var wd: float = float(c.get("carriage_width", 3.2))
	if Net.is_authority():
		for d: Node in get_tree().get_nodes_in_group(&"director"):
			var dir: ZombieDirector = d as ZombieDirector
			if dir == null:
				continue
			for z: Zombie in dir.active_zombies():
				if z != null and is_instance_valid(z) and z.is_active() and under(z.global_position, foot, axis, ln, wd):
					TrapLever.trap_kill(z, float(c.get("zombie_damage", 999999)), KEY, _by)
					kills += 1
		for n: Node in get_tree().get_nodes_in_group(&"players"):
			var p: Player = n as Player
			if p != null and p.is_alive() and under(p.global_position, foot, axis, ln, wd):
				p.take_hit(float(c.get("player_damage", 9999)), self)
	if _t >= float(c.get("duration", 25.0)):
		active = false
		GameState.set_flag(&"rivet_line_running", false)
		cooldown_left = TrapLever.cooldown_for(KEY)
		if _loop != null:
			_loop.stop()
		if _sparks != null:
			_sparks.emitting = false


## Bots keep out: the whole strip from the klaxon until the carriage stops.
func danger_contains(p: Vector3) -> bool:
	if not active:
		return false
	var a: Vector3 = to_global(track_start)
	var b: Vector3 = to_global(track_end)
	var ab: Vector3 = b - a
	var t: float = clampf((p - a).dot(ab) / maxf(0.001, ab.length_squared()), -0.05, 1.05)
	var cp: Vector3 = a + ab * t
	return absf(p.y - cp.y) < 2.0 and Vector2(p.x - cp.x, p.z - cp.z).length() <= float(_cfg().get("carriage_width", 3.2)) * 0.5 + 0.8


func _animate_hammers(delta: float) -> void:
	_strike_t += delta
	var period: float = 0.22
	for i: int in _hammers.size():
		var ph: float = fmod(_strike_t / period + float(i) * 0.25, 1.0)
		# a fast stroke down to the floor and a slower return
		var depth: float = (1.0 - ph / 0.25) if ph < 0.25 else (ph - 0.25) / 0.75
		(_hammers[i] as Node3D).position.y = lerpf(-rail_y + 0.5, -2.6, clampf(depth, 0.0, 1.0))
	if _sparks != null and not _sparks.emitting:
		_sparks.emitting = true


func _settle_hammers(delta: float) -> void:
	for h: Node3D in _hammers:
		h.position.y = move_toward(h.position.y, -2.6, delta * 3.0)


func _build() -> void:
	var a: Vector3 = track_start
	var b: Vector3 = track_end
	# the rail: an I-beam on hangers from the roof trusses, end stops with buffers, hazard paint on the stops
	var rail: Node3D = Node3D.new()
	rail.name = "Rail"
	add_child(rail)
	var len_: float = a.distance_to(b) + 3.0
	var mid: Vector3 = (a + b) * 0.5
	Props.obox(rail, Vector3(mid.x, rail_y + 0.55, mid.z), Vector3(len_, 0.08, 0.36), "crane_yellow")
	Props.obox(rail, Vector3(mid.x, rail_y + 0.3, mid.z), Vector3(len_, 0.42, 0.05), "crane_yellow")
	Props.obox(rail, Vector3(mid.x, rail_y + 0.06, mid.z), Vector3(len_, 0.08, 0.36), "crane_yellow")
	var x: float = minf(a.x, b.x) - 1.4
	while x <= maxf(a.x, b.x) + 1.4:
		Props.strut(rail, Vector3(x, rail_y + 0.6, mid.z), Vector3(x, 9.0, mid.z), 0.06, "iron")
		x += 6.0
	for e: Vector3 in [a, b]:
		var s: float = signf(e.x - mid.x)
		Props.obox(rail, Vector3(e.x + s * 1.6, rail_y + 0.0, e.z), Vector3(0.3, 0.6, 0.6), "yellow_paint")
		Props.cyl(rail, Vector3(e.x + s * 1.35, rail_y - 0.05, e.z), 0.14, 0.3, "rubber", Vector3(0, 0, 90))
	# the carriage: a riveted box frame on four wheels, a compressor tank, four hammers on telescoping rams
	_carriage = Node3D.new()
	_carriage.name = "Carriage"
	add_child(_carriage)
	_carriage.position = Vector3(a.x, rail_y, a.z)
	Props.obox(_carriage, Vector3(0, -0.45, 0), Vector3(3.0, 0.7, 3.2), "crane_yellow")
	Props.obox(_carriage, Vector3(0, -0.85, 0), Vector3(3.1, 0.12, 3.3), "steel")
	Props.cyl(_carriage, Vector3(0, -0.2, 0.9), 0.32, 2.2, "machine_green", Vector3(0, 0, 90))
	for wx: float in [-1.1, 1.1]:
		Props.cyl(_carriage, Vector3(wx, 0.25, 0.0), 0.16, 0.5, "steel", Vector3(90, 0, 0))
	var lab: Label3D = Label3D.new()
	lab.text = "NIETSTRASSE 1"
	lab.font_size = 40
	lab.pixel_size = 0.006
	lab.modulate = Color(0.1, 0.1, 0.1)
	lab.position = Vector3(0, -0.45, 1.62)
	_carriage.add_child(lab)
	for hp: Vector3 in [Vector3(-0.9, 0, -0.8), Vector3(0.9, 0, -0.8), Vector3(-0.9, 0, 0.8), Vector3(0.9, 0, 0.8)]:
		var ram: Node3D = Node3D.new()
		ram.position = Vector3(hp.x, -2.6, hp.z)
		_carriage.add_child(ram)
		Props.cyl(ram, Vector3(0, 2.6, 0), 0.07, 5.2, "chrome_worn")   # the ram telescopes through the carriage
		Props.cyl(ram, Vector3(0, 0.0, 0), 0.16, 0.45, "machine_grey")
		Props.cone(ram, Vector3(0, -0.32, 0), 0.08, 0.2, "steel", Vector3(180, 0, 0))
		_hammers.append(ram)
	for c: Node in find_children("*", "GeometryInstance3D", true, false):
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ThalbachLife.merge(rail)
	for h: Node3D in _hammers:
		ThalbachLife.merge(h)
	# sparks at the hammers' feet
	_sparks = GPUParticles3D.new()
	_sparks.name = "Sparks"
	_sparks.amount = 48
	_sparks.lifetime = 0.5
	_sparks.emitting = false
	_sparks.position = Vector3(0, -rail_y + 0.3, 0)
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(1.0, 0.05, 0.9)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 70.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 5.5
	pm.gravity = Vector3(0, -12, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	pm.color = Color(1.0, 0.75, 0.35)
	_sparks.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(1.0, 0.8, 0.4)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.6, 0.2)
	m.emission_energy_multiplier = 4.0
	m.vertex_color_use_as_albedo = true
	q.material = m
	_sparks.draw_pass_1 = q
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_carriage.add_child(_sparks)
	var key: String = "a1_rivet_hammer" if AudioDirector.has_sound("a1_rivet_hammer") else "ore_cart_rumble"
	_loop = AudioDirector.make_loop_3d(key, _carriage, 3.0)
	if _loop != null:
		_loop.position = Vector3(0, -3.0, 0)
		_loop.stop()
