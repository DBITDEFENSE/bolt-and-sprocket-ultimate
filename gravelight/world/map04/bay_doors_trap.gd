class_name BayDoorsTrap
extends Node3D
## UPDATE 10 §3 (THE_BAR row 14, DECISIONS T-156): der Kranich's bomb-bay doors as a lever trap (traps.json
## `bay_doors`). The lever on the bay's forward bulkhead (TrapLever, trap_id bay_doors) buys it: a klaxon and the
## doors' amber lamps for warn_seconds, then the two door leaves in the bay floor swing down for `duration` s: the
## night and the sea (or the coast) under the racks, wind roaring up; every zombie on the grating (`box`, the aisle
## between the racks) drops out into the dark with a scream (the activator's kill); a player standing on the doors
## is thrown to the side (a push, no damage: the trap is for the dead). Then the doors grind shut; cooldown s.
## Needs the aux bus (power). Host decides the kills; TrapLever mirrors activate() so every peer sees the show.
## Bots keep out (danger_contains).

const KEY: String = "bay_doors"

var active: bool = false
var cooldown_left: float = 0.0
var dropped: int = 0
var runs: int = 0
var _t: float = 0.0
var _warn_left: float = 0.0
var _by: int = 0
var _leaves: Array[Node3D] = []
var _lamps: Array[OmniLight3D] = []
var _gust: CPUParticles3D = null
var _void: MeshInstance3D = null


func _cfg() -> Dictionary:
	return TrapLever.cfg_for(KEY)


func _box() -> AABB:
	var b: Array = _cfg().get("box", [[-3.8, -0.5, 3.0], [3.8, 1.8, 21.0]])
	var lo: Vector3 = Vector3(float(b[0][0]), float(b[0][1]), float(b[0][2]))
	var hi: Vector3 = Vector3(float(b[1][0]), float(b[1][1]), float(b[1][2]))
	return AABB(lo, hi - lo)


func _ready() -> void:
	add_to_group(&"traps")
	add_to_group(&"bay_doors")
	var box: AABB = _box()
	var c: Vector3 = to_local(box.get_center())
	# the void under the doors (shown only while they hang open)
	_void = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(box.size.x, box.size.z)
	_void.mesh = pm
	var vm: StandardMaterial3D = StandardMaterial3D.new()
	vm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vm.albedo_color = Color(0.02, 0.03, 0.06)
	_void.material_override = vm
	_void.position = Vector3(c.x, 0.012, c.z)
	_void.visible = false
	add_child(_void)
	# two door leaves hinged along the outer edges of the aisle, lying in the floor
	for s: float in [-1.0, 1.0]:
		var hinge: Node3D = Node3D.new()
		hinge.position = Vector3(c.x + s * box.size.x * 0.5, 0.02, c.z)
		add_child(hinge)
		# each leaf runs from its hinge to the aisle's centre line
		Props.block(hinge, Vector3(minf(0.0, -s * box.size.x * 0.5), -0.04, -box.size.z * 0.5), Vector3(maxf(0.0, -s * box.size.x * 0.5), 0.0, box.size.z * 0.5), "steel_grate")
		_leaves.append(hinge)
	for z: float in [box.position.z + 1.0, box.end.z - 1.0]:
		for x: float in [box.position.x, box.end.x]:
			var l: OmniLight3D = OmniLight3D.new()
			l.light_color = Color(1.0, 0.6, 0.15)
			l.light_energy = 0.0
			l.omni_range = 4.0
			l.shadow_enabled = false
			l.position = to_local(Vector3(x, 0.3, z))
			add_child(l)
			_lamps.append(l)
	_gust = CPUParticles3D.new()
	_gust.position = Vector3(c.x, 0.2, c.z)
	_gust.amount = 120
	_gust.lifetime = 0.9
	_gust.emitting = false
	_gust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_gust.emission_box_extents = Vector3(box.size.x * 0.45, 0.1, box.size.z * 0.45)
	_gust.direction = Vector3(0, 1, 0)
	_gust.spread = 20.0
	_gust.gravity = Vector3.ZERO
	_gust.initial_velocity_min = 6.0
	_gust.initial_velocity_max = 10.0
	_gust.mesh = BoxMesh.new()
	_gust.mesh.set("size", Vector3(0.03, 0.4, 0.03))
	_gust.material_override = Mats.get_mat("lead")
	add_child(_gust)


func trap_name() -> String:
	return "Bomb-Bay Doors"


func cost() -> int:
	return int(_cfg().get("cost", 1000))


func can_activate() -> bool:
	return not active and cooldown_left <= 0.0 and (GameState.power_on or not bool(_cfg().get("needs_power", true)))


func status_text() -> String:
	if active:
		return "The bay doors are open"
	if not GameState.power_on and bool(_cfg().get("needs_power", true)):
		return "The bay doors need the auxiliary bus"
	return "The doors' hydraulics are recharging... %d" % int(ceil(cooldown_left))


## TrapLever (host, then mirrored to every peer for the show).
func activate(by_player: int) -> bool:
	if active:
		return false
	active = true
	runs += 1
	_by = by_player
	_t = 0.0
	_warn_left = float(_cfg().get("warn_seconds", 1.5))
	AudioDirector.play_3d("kranich_bordfunk", global_position + Vector3.UP, 2.0, 0.0)
	if Net.is_authority():
		GLVO.play(StringName(str(_cfg().get("vo", "PA_M4B_BAYDOORS_01"))))
	return true


## Capture / dev hook ("call:Trap_BayDoors:capture_open"): the show with nobody's kill and no price.
func capture_open() -> void:
	cooldown_left = 0.0
	activate(0)


func is_open() -> bool:
	return active and _warn_left <= 0.0


## Bots keep out while it warns and while it is open.
func danger_contains(p: Vector3) -> bool:
	return active and _box().grow(0.5).has_point(Vector3(p.x, clampf(p.y, _box().position.y, _box().end.y - 0.01), p.z))


func _in_box(p: Vector3) -> bool:
	var b: AABB = _box()
	return p.x >= b.position.x and p.x <= b.end.x and p.z >= b.position.z and p.z <= b.end.z and p.y >= b.position.y and p.y <= b.end.y


func _physics_process(delta: float) -> void:
	if not active:
		if cooldown_left > 0.0:
			cooldown_left = maxf(0.0, cooldown_left - delta)
		return
	if _warn_left > 0.0:
		_warn_left -= delta
		for l: OmniLight3D in _lamps:
			l.light_energy = 2.0 if fmod(_warn_left, 0.4) < 0.2 else 0.2
		if _warn_left <= 0.0:
			_open_show()
		return
	_t += delta
	if Net.is_authority():
		_drop_zombies()
		_clear_players()
	if _t >= float(_cfg().get("duration", 8.0)):
		_close_show()
		active = false
		cooldown_left = TrapLever.cooldown_for(KEY)


func _open_show() -> void:
	for i: int in _leaves.size():
		var tw: Tween = _leaves[i].create_tween()
		tw.tween_property(_leaves[i], "rotation:z", (-1.0 if i == 0 else 1.0) * 1.45, 0.6).set_trans(Tween.TRANS_QUAD)
	_void.visible = true
	_gust.emitting = true
	for l: OmniLight3D in _lamps:
		l.light_energy = 1.2
	AudioDirector.play_3d("kranich_wind_gust", global_position + Vector3.UP, 8.0, 0.05)
	AudioDirector.play_3d("door_open", global_position, 6.0, 0.05)


func _close_show() -> void:
	for h: Node3D in _leaves:
		var tw: Tween = h.create_tween()
		tw.tween_property(h, "rotation:z", 0.0, 1.0).set_trans(Tween.TRANS_QUAD)
	_void.visible = false
	_gust.emitting = false
	for l: OmniLight3D in _lamps:
		l.light_energy = 0.0
	AudioDirector.play_3d("door_open", global_position, 2.0, 0.05)


func _drop_zombies() -> void:
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	if dir == null:
		return
	for z: Zombie in dir.active_zombies():
		if not z.is_active() or z.puppet or z is HomageBoss:
			continue
		if _in_box(z.global_position):
			var at: Vector3 = z.global_position
			TrapLever.trap_kill(z, float(_cfg().get("zombie_damage", 999999)), KEY, _by)
			if not z.is_active():
				dropped += 1
				_scream(at)
				Net.mirror(self, &"_scream", [at])


func _scream(at: Vector3) -> void:
	AudioDirector.play_3d("screamer_scream" if AudioDirector.has_sound("screamer_scream") else "impact_flesh", at, -8.0, 0.25)


## A player on the doors is thrown to the nearer side, unhurt.
func _clear_players() -> void:
	var b: AABB = _box()
	var cx: float = b.get_center().x
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not p.is_alive() or not _in_box(p.global_position) or p.is_pushed():
			continue
		var side: float = 1.0 if p.global_position.x >= cx else -1.0
		p.external_push(Vector3(side * float(_cfg().get("push_mps", 5.0)), 0, 0), 0.5, &"push")
