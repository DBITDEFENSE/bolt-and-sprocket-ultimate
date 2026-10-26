class_name WindTunnel
extends Interactable
## The Werk's wind tunnel as a trap and an egg step (UPDATE 07, docs/MAP4_FERNFLUG.md §3.3, §9.1 s4; T-114): with the
## power on, hold [interact] on the fan control and the fan runs for `run_seconds`: everyone in the test section is
## pushed along the tunnel (`push_mps` m/s through Player/Zombie.external_push; Skyhook's push_resist applies), the
## dead tumble (a stagger at the onset and every `stagger_every` s), and the flag `tunnel_running` holds for the
## egg's kill count. `cooldown_seconds` between runs; `tunnel_ran` stays set after the first run (Jette's models
## glint). The tunnel box is `lo..hi` in map space, the wind blows along +X.

@export var lo: Vector3 = Vector3(6, 0, 112)
@export var hi: Vector3 = Vector3(38, 2.4, 118)
@export var run_seconds: float = 20.0
@export var cooldown_seconds: float = 30.0
@export var push_mps: float = 6.0
@export var stagger_every: float = 4.0
@export var needs_power: bool = true

var running: float = 0.0
var cooldown: float = 0.0
var _stagger_t: float = 0.0


static func inside(p: Vector3, a: Vector3, b: Vector3) -> bool:
	return p.x >= a.x and p.x <= b.x and p.z >= a.z and p.z <= b.z and p.y >= a.y - 0.5 and p.y <= b.y + 0.5


## Pure: may the fan start? (power on when needed, not running, cooled down)
static func can_start(power: bool, needs: bool, run_left: float, cool_left: float) -> bool:
	return (power or not needs) and run_left <= 0.0 and cool_left <= 0.0


func _ready() -> void:
	interact_size = Vector3(1.0, 1.6, 0.8)
	interact_offset = Vector3(0, 0.8, 0)
	super._ready()
	add_to_group(&"wind_tunnels")


func build_greybox() -> void:
	InteractableArt.place(self, "lever_box", func(r: Node3D) -> void: InteractableArt.lever_box(r))
	add_label(self, "WINDKANAL · GEBLÄSE", Vector3(0, 2.0, 0), 18, Color(0.9, 0.82, 0.6))


func get_prompt(_player: Player) -> String:
	if running > 0.0:
		return "The tunnel is running (%ds)" % int(ceil(running))
	if needs_power and not GameState.power_on:
		return "The fan needs the works' power"
	if cooldown > 0.0:
		return "The fan is spinning down (%ds)" % int(ceil(cooldown))
	return "Hold [%s] to run the wind tunnel" % prompt_key(&"interact")


func can_interact(_player: Player) -> bool:
	return can_start(GameState.power_on, needs_power, running, cooldown)


func interact(player: Player) -> void:
	if not Net.is_authority() or not can_interact(player):
		return
	start_run()
	Net.mirror(self, &"start_run")


func start_run() -> void:
	running = run_seconds
	_stagger_t = 0.0
	GameState.set_flag(&"tunnel_running")
	GameState.set_flag(&"tunnel_ran")
	AudioDirector.play_3d("power_on", global_position, -2.0)
	var hud: Node = get_tree().get_first_node_in_group(&"hud")
	if hud != null:
		hud.call("show_banner", "THE WIND TUNNEL RUNS", 2.0)


func _physics_process(delta: float) -> void:
	if running <= 0.0:
		if cooldown > 0.0:
			cooldown = maxf(0.0, cooldown - delta)
		return
	running -= delta
	_stagger_t -= delta
	var stagger: bool = _stagger_t <= 0.0
	if stagger:
		_stagger_t = stagger_every
	var wind: Vector3 = Vector3(push_mps, 0, 0)
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and inside(p.global_position, lo, hi):
			p.external_push(wind, 0.25)
	for d: Node in get_tree().get_nodes_in_group(&"director"):
		var dir: ZombieDirector = d as ZombieDirector
		if dir == null:
			continue
		for z: Zombie in dir.active_zombies():
			if z == null or not is_instance_valid(z) or not inside(z.global_position, lo, hi):
				continue
			z.external_push(wind * 1.5, 0.25)
			if stagger:
				z.force_stagger()
	if running <= 0.0:
		running = 0.0
		cooldown = cooldown_seconds
		GameState.set_flag(&"tunnel_running", false)
