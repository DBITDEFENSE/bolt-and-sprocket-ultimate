class_name FuelDumpTrap
extends Node3D
## The motor pool's fuel dump (UPDATE 10 §3 Act III, row 14 "a trap with a show"; DECISIONS T-157; traps.json
## fuel_dump). The lever opens the dump's drain cock and lights it: a 1 s hiss of fuel on the ground, then a deep
## WHUMP, a wall of fire across the lane in front of the tank for `duration` (20 s) and a black smoke column into
## the sky; zombies in the wall burn to death, a player in it takes `player_dps`. Then the flames die and the smoke
## hangs on a while. Bought from a TrapLever (the lib's trap row). Origin: the wall's floor centre; size = the wall's
## length (x) × height (y) × depth (z).

const KEY: String = "fuel_dump"

@export var size: Vector3 = Vector3(8.0, 2.4, 1.6)

var active: bool = false
var cooldown_left: float = 0.0
var shows: int = 0                  # the smoke / tests
var _t: float = 0.0
var _warn_left: float = 0.0
var _by: int = 0
var _flames: Array[GPUParticles3D] = []
var _smoke: Node3D = null
var _light: OmniLight3D = null
var _pool: MeshInstance3D = null
var _smoke_left: float = 0.0


func _ready() -> void:
	add_to_group(&"traps")
	# the fuel on the ground: a dark sheen that catches the light while it burns
	_pool = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(size.x, size.z + 0.6)
	_pool.mesh = pm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.06, 0.05, 0.04, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic = 0.6
	m.roughness = 0.1
	_pool.material_override = m
	_pool.position = Vector3(0, 0.02, 0)
	_pool.visible = false
	_pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_pool)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.2)
	_light.light_energy = 0.0
	_light.omni_range = 14.0
	_light.shadow_enabled = false
	_light.position = Vector3(0, 1.8, 0)
	_light.set_meta("zone", &"D_MOTORPOOL")
	add_child(_light)


func trap_name() -> String:
	return "Fuel Dump"


func cost() -> int:
	return int(TrapLever.cfg_for(KEY)["cost"])


func can_activate() -> bool:
	return not active and cooldown_left <= 0.0


func status_text() -> String:
	if active:
		return "The dump is burning"
	return "The dump is refilling... %d" % int(ceil(cooldown_left))


func activate(by_player: int) -> bool:
	if not can_activate():
		return false
	active = true
	_by = by_player
	_t = 0.0
	_warn_left = float(TrapLever.cfg_for(KEY).get("warn_seconds", 1.0))
	_pool.visible = true
	AudioDirector.play_3d("wire_buzz", global_position + Vector3.UP * 0.3, -6.0, 0.0)   # the hiss of the drain cock
	return true


func is_live() -> bool:
	return active and _warn_left <= 0.0


func _contains(p: Vector3) -> bool:
	var l: Vector3 = to_local(p)
	return absf(l.x) <= size.x * 0.5 and absf(l.z) <= size.z * 0.5 + 0.3 and l.y > -0.5 and l.y < size.y


## Bots keep out (BotBrain._in_trap) from the hiss until the flames die, with a margin for the heat.
func danger_contains(p: Vector3) -> bool:
	if not active:
		return false
	var l: Vector3 = to_local(p)
	return absf(l.x) <= size.x * 0.5 + 0.8 and absf(l.z) <= size.z * 0.5 + 1.2 and l.y > -1.0 and l.y < size.y + 1.0


## The ignition: the whump, the wall of fire, the smoke column, a shake for anyone close.
func _ignite() -> void:
	shows += 1
	AudioDirector.play_3d("fuel_whump" if AudioDirector.has_sound("fuel_whump") else "war_crash_boom", global_position + Vector3.UP, 4.0, 0.0)
	var n: int = maxi(2, int(size.x / 1.6))
	for i: int in n:
		var x: float = -size.x * 0.5 + size.x * (float(i) + 0.5) / float(n)
		var f: GPUParticles3D = Props.flames(self, Vector3(x, 0.0, 0.0), 1.9, size.y + 0.8, 34)
		_flames.append(f)
	_smoke = Node3D.new()
	_smoke.name = "SmokeColumn"
	add_child(_smoke)
	Props.smoke(_smoke, Vector3(0, size.y, 0), 2.0, 24.0, 40)
	Props.embers(self, Vector3(0, 0.6, 0), size.x * 0.5, 20)
	Effects.dust_puff(global_position, "earth", 30)
	for p: Node in get_tree().get_nodes_in_group(&"players"):
		var pl: Player = p as Player
		if pl != null and bool(pl.get("is_local")) and pl.global_position.distance_to(global_position) < 18.0:
			pl.kick_camera(0.0, 0.0, 0.0, 3.0, 0.5, 0.0)


func _douse() -> void:
	for f: GPUParticles3D in _flames:
		if is_instance_valid(f):
			f.queue_free()
	_flames.clear()
	_pool.visible = false
	_light.light_energy = 0.0
	_smoke_left = float(TrapLever.cfg_for(KEY).get("smoke_linger_s", 10.0))


func _physics_process(delta: float) -> void:
	if _smoke_left > 0.0:
		_smoke_left -= delta
		if _smoke_left <= 0.0 and _smoke != null and is_instance_valid(_smoke):
			_smoke.queue_free()
			_smoke = null
	if cooldown_left > 0.0 and not active:
		cooldown_left = maxf(0.0, cooldown_left - delta)
	if not active:
		return
	var c: Dictionary = TrapLever.cfg_for(KEY)
	if _warn_left > 0.0:
		_warn_left -= delta
		if _warn_left <= 0.0:
			_ignite()
		return
	_t += delta
	_light.light_energy = randf_range(3.0, 5.5)
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	if dir != null and Net.is_authority():
		for z: Zombie in dir.active_zombies():
			if z.state != Zombie.State.DEAD and _contains(z.global_position + Vector3.UP * 0.5):
				z.ignite(float(c.get("burn_dps", 60.0)), 3.0, _by)
				TrapLever.trap_kill(z, float(c["zombie_damage"]), KEY, _by)
	if Net.is_authority():
		for n: Node in get_tree().get_nodes_in_group(&"players"):
			var p: Player = n as Player
			if p != null and p.is_alive() and _contains(p.global_position + Vector3.UP * 0.5):
				p.take_hit(float(c.get("player_dps", 25.0)) * delta, self)
	if _t >= float(c["duration"]):
		active = false
		cooldown_left = TrapLever.cooldown_for(KEY)
		_douse()
