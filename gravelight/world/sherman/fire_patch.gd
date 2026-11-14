class_name FirePatch
extends Node3D
## A patch of burning ground left by a fire zombie's burst (T-249; sherman.json "fire_zombie": patch_radius,
## patch_seconds, patch_player_dps, patch_zombie_burn_frac). Low flames, a scorch, a light. On the host it hurts a player
## standing in it (twice a second) and sets the dead walking through it alight (Zombie.ignite). It dies down at the end.

var radius: float = 2.2
var seconds: float = 7.0
var player_dps: float = 16.0
var burn_frac: float = 0.02
var host: bool = true
var _t: float = 0.0
var _tick: float = 0.0
var _light: OmniLight3D
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

static var live: int = 0
static var player_ticks: int = 0


static func spawn(tree: SceneTree, at: Vector3, c: Dictionary, is_host: bool) -> FirePatch:
	if tree == null or tree.current_scene == null:
		return null
	var f: FirePatch = FirePatch.new()
	f.name = "FirePatch"
	f.radius = float(c.get("patch_radius", 2.2))
	f.seconds = float(c.get("patch_seconds", 7.0))
	f.player_dps = float(c.get("patch_player_dps", 16.0))
	f.burn_frac = float(c.get("patch_zombie_burn_frac", 0.02))
	f.host = is_host
	tree.current_scene.add_child(f)
	f.global_position = Vector3(at.x, at.y - 0.35, at.z)
	return f


func _ready() -> void:
	live += 1
	_rng.randomize()
	Effects.scorch(global_position + Vector3.UP * 0.05, radius)
	if DisplayServer.get_name() != "headless":
		for i: int in 3:
			var a: float = TAU * float(i) / 3.0 + _rng.randf()
			Props.flames(self, Vector3(cos(a), 0.0, sin(a)) * radius * 0.45, radius * 0.5, 0.55, 14)
		Props.flames(self, Vector3.ZERO, radius * 0.6, 0.7, 18)
		Props.smoke(self, Vector3(0, 0.6, 0), radius * 0.3, 1.0, 8)
	_light = OmniLight3D.new()
	_light.position = Vector3(0, 0.8, 0)
	_light.light_color = Color(1.0, 0.5, 0.16)
	_light.light_energy = 2.0
	_light.omni_range = radius * 3.0
	_light.shadow_enabled = false
	add_child(_light)


func _exit_tree() -> void:
	live = maxi(0, live - 1)


## True when `p` stands in a patch of radius `r` at `c` (flat, within 1.5 m of its height).
static func inside(c: Vector3, p: Vector3, r: float) -> bool:
	return Vector2(p.x - c.x, p.z - c.z).length() <= r and absf(p.y - c.y) <= 1.5


func _physics_process(delta: float) -> void:
	_t += delta
	var fade: float = clampf((seconds - _t) / 1.5, 0.0, 1.0)
	if _light != null:
		_light.light_energy = _rng.randf_range(1.5, 2.4) * fade
	if _t >= seconds:
		queue_free()
		return
	if not host:
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.is_alive() and inside(global_position, p.global_position, radius):
			p.take_hit(player_dps * 0.5, null)
			player_ticks += 1
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	if dir == null:
		return
	var dps: float = float(RoundManager.current_health()) * burn_frac
	for z: Zombie in dir.active_zombies():
		if z.is_active() and not z.is_burning() and inside(global_position, z.global_position, radius):
			z.ignite(dps, 3.0, 0)
