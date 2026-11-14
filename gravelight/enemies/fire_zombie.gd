class_name FireZombie
extends Node3D
## The burning dead of the Sherman's round (T-249; sherman.json "fire_zombie"): an ordinary pooled zombie with this
## node under it. Charred (the zombie's own burn-char material at 0.9), alight from the knees to the shoulders, a light
## on it and the crackle of it. Near a player (fuse_player_m) or against the tank's hull (fuse_tank_m) it hisses and
## flares for fuse_seconds and bursts; killed, it bursts the same (so the counter is to drop it away from the tank and
## from yourself). The burst hurts the players near it (falling off to the edge; Blastproof shrugs it off), the dead
## near it, the tank if it was against it, and leaves a burning patch on the ground (FirePatch).
## Nothing in Zombie changes: the event spawns the zombie, then `FireZombie.make` dresses it. Host decides; a co-op
## client gets the dressing from the event's mirrored call (visual only, `host` false).

const GROUP: StringName = &"fire_zombies"

var zombie: Zombie = null
var cfg: Dictionary = {}
var tank: ShermanTank = null
var host: bool = true
var fusing: bool = false
var burst_done: bool = false
var _fuse_t: float = 0.0
var _light: OmniLight3D
var _flames: Array[GPUParticles3D] = []
var _snd: AudioStreamPlayer3D
var _flick: float = 0.0
var _check_t: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Bursts so far this match (tests / the smoke).
static var bursts: int = 0
static var fuses: int = 0
static var last_burst_at: Vector3 = Vector3.INF


## Dresses `z` as a fire zombie and returns the node (under the zombie, freed with its death or its recycling).
static func make(z: Zombie, fire_cfg: Dictionary, the_tank: ShermanTank, is_host: bool = true) -> FireZombie:
	if z == null:
		return null
	for c: Node in z.get_children():
		if c is FireZombie:
			return c as FireZombie
	var f: FireZombie = FireZombie.new()
	f.name = "FireZombie"
	f.zombie = z
	f.cfg = fire_cfg
	f.tank = the_tank
	f.host = is_host
	z.add_child(f)
	return f


static func is_fire(z: Node) -> bool:
	if z == null:
		return false
	for c: Node in z.get_children():
		if c is FireZombie and not (c as FireZombie).burst_done:
			return true
	return false


func _ready() -> void:
	add_to_group(GROUP)
	_rng.randomize()
	zombie.set("_char", 0.9)
	var headless: bool = DisplayServer.get_name() == "headless"
	if not headless:
		_flames.append(Props.flames(self, Vector3(0, 0.95, 0), 0.55, 0.9, 28))
		_flames.append(Props.flames(self, Vector3(0, 0.45, 0), 0.45, 0.6, 16))
		Props.embers(self, Vector3(0, 1.4, 0), 0.3, 12)
	_light = OmniLight3D.new()
	_light.position = Vector3(0, 1.3, 0)
	_light.light_color = Color(1.0, 0.52, 0.18)
	_light.light_energy = 1.6
	_light.omni_range = 5.0
	_light.shadow_enabled = false
	add_child(_light)
	_snd = AudioDirector.make_loop_3d("firezed_burn", self, 0.0)
	if _snd != null:
		_snd.position = Vector3(0, 1.2, 0)
		_snd.play()


func _physics_process(delta: float) -> void:
	_flick -= delta
	if _flick <= 0.0 and _light != null:
		_flick = _rng.randf_range(0.05, 0.12)
		_light.light_energy = (_rng.randf_range(1.2, 2.0) if not fusing else lerpf(2.0, 6.0, _fuse_t / maxf(0.1, float(cfg.get("fuse_seconds", 0.8)))))
	if not host:
		if zombie == null or not is_instance_valid(zombie) or zombie.state == Zombie.State.DEAD or zombie.state == Zombie.State.INACTIVE:
			_drop()
		return
	if burst_done:
		return
	if zombie == null or not is_instance_valid(zombie):
		queue_free()
		return
	if zombie.state == Zombie.State.DEAD or zombie.hp <= 0.0:
		burst()
		return
	if zombie.state == Zombie.State.INACTIVE:
		_drop()   # recycled (stuck): it goes back to the pool as an ordinary zombie
		return
	if fusing:
		_fuse_t += delta
		if _fuse_t >= float(cfg.get("fuse_seconds", 0.8)):
			zombie.kill_silently()
			burst()
		return
	_check_t -= delta
	if _check_t > 0.0 or zombie.state == Zombie.State.EMERGE:
		return
	_check_t = 0.1
	var p: Vector3 = zombie.global_position
	var near: bool = tank != null and is_instance_valid(tank) and not tank.is_wreck() and tank.near_hull(p, float(cfg.get("fuse_tank_m", 1.0)))
	if not near:
		for n: Node in get_tree().get_nodes_in_group(&"players"):
			var pl: Player = n as Player
			if pl != null and pl.is_alive() and pl.global_position.distance_to(p) <= float(cfg.get("fuse_player_m", 2.0)) and absf(pl.global_position.y - p.y) < 1.6:
				near = true
				break
	if near:
		start_fuse()


func start_fuse() -> void:
	if fusing or burst_done:
		return
	fusing = true
	fuses += 1
	_fuse_t = 0.0
	AudioDirector.play_3d("firezed_hiss", global_position + Vector3.UP * 1.2, 0.0)
	for f: GPUParticles3D in _flames:
		f.amount_ratio = 1.0
		f.speed_scale = 1.8


## The burst (host): damage, the patch, the effects (mirrored by the event), then the node goes.
func burst() -> void:
	if burst_done:
		return
	burst_done = true
	var at: Vector3 = zombie.global_position if zombie != null and is_instance_valid(zombie) else global_position
	at.y += 0.4
	bursts += 1
	last_burst_at = at
	FireZombie.apply_burst(get_tree(), at, cfg, tank, zombie)
	var ev: Node = get_tree().get_first_node_in_group(&"sherman_event")
	if ev != null:
		ev.call("on_fire_burst", at)
	_drop()


## The burst's damage (host): players by distance (60 at the centre, 20 at the ring), the dead (a share of the round's
## health), the tank if the burst was against its hull; then the patch and the effects.
static func apply_burst(tree: SceneTree, at: Vector3, c: Dictionary, the_tank: ShermanTank, own: Zombie) -> void:
	var r: float = float(c.get("blast_radius", 4.0))
	for n: Node in tree.get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not p.is_alive():
			continue
		var d: float = p.global_position.distance_to(at)
		if d > r:
			continue
		if p.has_explosive_immunity():
			continue
		p.take_hit(burst_damage(d, c), null)
	var dir: ZombieDirector = tree.get_first_node_in_group(&"director") as ZombieDirector
	if dir != null:
		var dmg: float = float(RoundManager.current_health()) * float(c.get("zombie_damage_frac", 0.35))
		for z: Zombie in dir.active_zombies():
			if z == own or not z.is_active():
				continue
			if z.global_position.distance_to(at) <= r:
				z.take_damage(dmg, &"torso", &"fire_zombie", 0, &"explosive")
	if the_tank != null and is_instance_valid(the_tank) and the_tank.can_be_attacked() and the_tank.near_hull(at, float(c.get("fuse_tank_m", 1.0)) + 0.6):
		the_tank.take_damage(float(c.get("tank_damage", 600)))
	FirePatch.spawn(tree, at, c, true)
	burst_fx(tree, at, r)


## A burst's damage at `d` metres (falls off linearly to the ring).
static func burst_damage(d: float, c: Dictionary) -> float:
	var r: float = float(c.get("blast_radius", 4.0))
	return lerpf(float(c.get("player_damage", 60)), float(c.get("player_damage_edge", 20)), clampf(d / maxf(0.01, r), 0.0, 1.0))


static func burst_fx(tree: SceneTree, at: Vector3, r: float) -> void:
	Effects.explosion(at, r)
	BossFx.burst("embers", at + Vector3.UP * 0.5, tree, 2.0, 1.6)
	BossFx.burst("smoke", at + Vector3.UP * 0.8, tree, 1.2, 1.6)
	BossFx.burst("sparks", at + Vector3.UP * 0.5, tree, 1.0, 1.2)
	AudioDirector.play_3d("firezed_burst", at, 2.0)
	ShermanEvent.shake_players(tree, at, 0.4, 14.0)


func _drop() -> void:
	if zombie != null and is_instance_valid(zombie) and not burst_done:
		zombie.set("_char", 0.0)
	queue_free()
