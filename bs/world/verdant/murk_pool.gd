class_name MurkPool
extends Node3D
## A murk pool (Verdant Sink, BS_LEVELS §6.5; source updateMurk): while Bolt is grounded inside the radius and
## below the pool's surface + `height`, he is dragged (the source's x0.86 per frame at 60 fps = a drag of ~9/s,
## applied here as a PlayerDebuffs slow so it composes with the other slows) and takes `tick_dmg` every
## `tick_every` s, with the swamp bark ("The swamp is LITIGIOUS...") at `bark_chance` on entry. A pool can be
## `drained` (sealed coolant leaks dry the lagoon's thirds) or flushed clear for a while (the S5 sprinkler
## pump). Group "murk_pools". Picket corn and enemies are not affected (they wade).

signal entered(pool: MurkPool)
signal drained_changed(pool: MurkPool, on: bool)

var pool_id: String = ""
var r: float = 4.0
var height: float = 1.4
var drag: float = 9.0
var slow_mult: float = 0.45
var tick_dmg: float = 5.0
var tick_every: float = 0.7
var bark_id: String = "code.updateMurk.01"
var bark_chance: float = 0.5
var bark_cd: float = 12.0
var drained: bool = false
var flush_t: float = 0.0
var inside: bool = false
var ticks: int = 0
var time_inside: float = 0.0
var _tick_t: float = 0.0
var _bark_t: float = 0.0
var _disc: MeshInstance3D
var _mat: StandardMaterial3D
var _glow: OmniLight3D
var _t: float = 0.0


func _ready() -> void:
	process_physics_priority = 10
	add_to_group(&"murk_pools")
	set_meta(&"radius", r)
	_disc = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r * 0.9
	cm.height = 0.16
	cm.radial_segments = 20
	_disc.mesh = cm
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color("#0a3b2e")
	_mat.emission_enabled = true
	_mat.emission = Color("#1fd39a")
	_mat.emission_energy_multiplier = 0.55
	_mat.roughness = 0.2
	_disc.material_override = _mat
	_disc.position.y = 0.06
	add_child(_disc)
	# a ring of glowing scum at the edge
	for i: int in 10:
		var a: float = TAU * float(i) / 10.0
		LevelKit.box(self, Vector3(cos(a) * r * 0.92, 0.1, sin(a) * r * 0.92), Vector3(0.5, 0.06, 0.25), "#2fe6a6", false,
			Vector3(0, -rad_to_deg(a), 0), 1, 1.2)
	_glow = OmniLight3D.new()
	_glow.light_color = Color("#2fe6a6")
	_glow.light_energy = 0.7
	_glow.omni_range = r * 1.6
	_glow.position.y = 0.8
	add_child(_glow)


func is_active() -> bool:
	return not drained and flush_t <= 0.0


## True when `p` (Bolt's origin) is over the pool and low enough to wade.
func contains(p: Vector3, hy: float = 0.95) -> bool:
	var g: Vector3 = global_position
	if Vector2(p.x - g.x, p.z - g.z).length() >= r:
		return false
	var feet: float = p.y - hy
	return feet < g.y + height and feet > g.y - 2.0


func set_drained(on: bool) -> void:
	if drained == on:
		return
	drained = on
	drained_changed.emit(self, on)


## The sprinkler pump flushes the pool clear for `seconds`.
func flush(seconds: float) -> void:
	flush_t = maxf(flush_t, seconds)


func _physics_process(delta: float) -> void:
	_t += delta
	flush_t -= delta
	_tick_t -= delta
	_bark_t -= delta
	var active: bool = is_active()
	var target_y: float = 0.06 if active else -0.9
	_disc.position.y = lerpf(_disc.position.y, target_y, minf(1.0, delta * 2.5))
	_mat.emission_energy_multiplier = (0.45 + 0.2 * sin(_t * 2.0)) if active else 0.08
	_glow.light_energy = 0.7 if active else 0.1
	var b: Bolt = LevelKit.player(get_tree()) as Bolt
	if b == null or b.dead or not active:
		inside = false
		return
	var was: bool = inside
	inside = contains(b.global_position, b.motor.hy) and (b.motor.on_ground or b.motor.vel.y < 0.5)
	if not inside:
		return
	time_inside += delta
	if not was:
		entered.emit(self)
		_tick_t = minf(_tick_t, tick_every * 0.5)
		if _bark_t <= 0.0 and bark_id != "" and randf() < bark_chance:
			_bark_t = bark_cd
			EventBus.bark.emit(bark_id)
	# the drag: a keyed slow the strongest-slow rule composes with the Lifeguard puddle and the Zoning zone
	PlayerDebuffs.of(b).slow(&"murk", slow_mult, 0.25)
	if _tick_t <= 0.0 and tick_dmg > 0.0:
		_tick_t = tick_every
		ticks += 1
		var h: Combat.Hit = Combat.Hit.make(tick_dmg, Combat.Type.KINETIC, self)
		h.weapon_id = &"murk"
		b.take_damage(h, true)
