class_name WindTunnel
extends Interactable
## The Werk's wind tunnel: an egg step (UPDATE 07, docs/MAP4_FERNFLUG.md §3.3, §9.1 s4; T-114) and, since UPDATE 10
## (contract C6 `wind_tunnel`, DECISIONS T-155), a trap, a shortcut and a toy. With the power on, hold [interact] on
## the fan control and the fan runs for `run_seconds`: the wind blows along +X down the test section (`lo..hi` in map
## space); zombies inside are blown back at `zombie_push_mps` and tumble (a stagger at the onset and every
## `stagger_every` s) until they hit the outlet screen at the far end, where they are shredded (a kill credited to
## whoever started the fan, with a burst); players drift at `player_push_mps` (moved through move_and_collide;
## Skyhook's push_resist applies) and are never hurt. While the fan runs, the draft sucks the plenum hatch in the Montage wall open
## (`hatch_path`, a TunnelHatch: a shortcut between F and E, and a navmesh link the bots use). The flag
## `tunnel_running` holds for the egg's kill count; `tunnel_ran` stays set after the first run. Tuning in
## traps.json "wind_tunnel" (the exports are the fallbacks). The power-on spectacle spins the fan up once
## (spin_up_once). Pure rules are static for the tests.

@export var lo: Vector3 = Vector3(6, 0, 112)
@export var hi: Vector3 = Vector3(38, 2.4, 118)
@export var run_seconds: float = 20.0
@export var cooldown_seconds: float = 30.0
## Zombies (contract C6: 6 m/s). Kept under its old name for old scenes.
@export var push_mps: float = 6.0
@export var player_push_mps: float = 3.0
## How deep the outlet screen's kill band is (m, measured back from hi.x).
@export var screen_depth: float = 1.4
@export var stagger_every: float = 4.0
@export var needs_power: bool = true
@export var hatch_path: NodePath = NodePath("../TunnelHatch")
## The model's sting (a 0.8 m post mid-lane, NavBlock_Sting): the wind parts round it so nothing jams behind it.
@export var sting: Vector3 = Vector3(31.0, 0, 115.0)
@export var sting_radius: float = 1.1

var running: float = 0.0
var cooldown: float = 0.0
var shredded: int = 0
var by_player: int = 0
var _stagger_t: float = 0.0
var _fan: Node3D
var _fan_speed: float = 0.0     # rad/s now
var _spin_burst: float = 0.0    # seconds left of a show spin (power on)
var _hum: AudioStreamPlayer3D
var _lamp: OmniLight3D           # the work lamp on the outlet screen (bright while the fan runs)


static func inside(p: Vector3, a: Vector3, b: Vector3) -> bool:
	return p.x >= a.x and p.x <= b.x and p.z >= a.z and p.z <= b.z and p.y >= a.y - 0.5 and p.y <= b.y + 0.5


## Pure: may the fan start? (power on when needed, not running, cooled down)
static func can_start(power: bool, needs: bool, run_left: float, cool_left: float) -> bool:
	return (power or not needs) and run_left <= 0.0 and cool_left <= 0.0


## Pure: the push on a body in the tunnel (+X wind): zombies at `zombie_mps`, players at `player_mps`.
static func push_for(is_player: bool, zombie_mps: float, player_mps: float) -> Vector3:
	return Vector3(player_mps if is_player else zombie_mps, 0.0, 0.0)


## Pure: is a body at `p` in the outlet screen's kill band (the last `depth` m of the tunnel, or just past it)?
static func at_screen(p: Vector3, a: Vector3, b: Vector3, depth: float) -> bool:
	return p.x >= b.x - depth and p.x <= b.x + 1.0 and p.z >= a.z and p.z <= b.z and p.y >= a.y - 0.5 and p.y <= b.y + 0.5


## Pure: seconds a zombie entering at `x` takes to reach the screen (the trap's reach, for the tests).
static func seconds_to_screen(x: float, a: Vector3, b: Vector3, depth: float, zombie_mps: float) -> float:
	return maxf(0.0, (b.x - depth) - x) / maxf(0.01, zombie_mps)


## Pure: the sideways part of the wind just upstream of the sting (it parts round the post): zero elsewhere.
static func part_round(p: Vector3, post: Vector3, radius: float, mps: float) -> Vector3:
	var dx: float = post.x - p.x
	var dz: float = p.z - post.z
	if dx < -0.2 or dx > 3.0 or absf(dz) > radius:
		return Vector3.ZERO
	return Vector3(0, 0, (1.0 if dz >= 0.0 else -1.0) * mps * 0.6)


## Pure: may the plenum hatch open (both rooms it joins are bought)?
static func hatch_allowed(f_open: bool, e_open: bool) -> bool:
	return f_open and e_open


func _ready() -> void:
	interact_size = Vector3(1.0, 1.6, 0.8)
	interact_offset = Vector3(0, 0.8, 0)
	super._ready()
	add_to_group(&"wind_tunnels")
	add_to_group(&"traps")
	_load_cfg()
	(func() -> void:
		var root: Node = get_parent().get_parent() if get_parent() != null else null
		if root != null:
			_fan = root.find_child("FanRing", true, false) as Node3D
		_build_screen()).call_deferred()
	GLBus.power_activated.connect(spin_up_once)


func _load_cfg() -> void:
	var t: Dictionary = GLData.load_json("res://data/gravelight/traps.json")
	var c: Dictionary = t.get("wind_tunnel", {})
	if c.is_empty():
		return
	run_seconds = float(c.get("duration", run_seconds))
	cooldown_seconds = float(c.get("cooldown", cooldown_seconds))
	push_mps = float(c.get("zombie_push_mps", push_mps))
	player_push_mps = float(c.get("player_push_mps", player_push_mps))
	screen_depth = float(c.get("screen_depth", screen_depth))
	stagger_every = float(c.get("stagger_every", stagger_every))


func build_greybox() -> void:
	InteractableArt.place(self, "lever_box", func(r: Node3D) -> void: InteractableArt.lever_box(r))
	add_label(self, "WINDKANAL · GEBLÄSE", Vector3(0, 2.0, 0), 18, Color(0.9, 0.82, 0.6))


## The outlet screen: a steel honeycomb grille across the tunnel's far end (no collider: the dead go through it in
## pieces, the living get blown out past it).
func _build_screen() -> void:
	if get_parent() == null or get_parent().get_node_or_null("TunnelScreen") != null:
		return
	var g: Node3D = Node3D.new()
	g.name = "TunnelScreen"
	get_parent().add_child(g)
	g.global_position = Vector3(hi.x - 0.2, lo.y, (lo.z + hi.z) * 0.5)
	var w: float = hi.z - lo.z
	var h: float = hi.y - lo.y + 1.2
	var n: int = 9
	for i: int in n + 1:
		var z: float = -w * 0.5 + w * float(i) / float(n)
		Props.obox(g, Vector3(0, h * 0.5, z), Vector3(0.06, h, 0.04), "steel")
	for j: int in 7:
		Props.obox(g, Vector3(0, h * float(j) / 6.0, 0), Vector3(0.06, 0.04, w), "steel")
	Props.obox(g, Vector3(0, h + 0.1, 0), Vector3(0.3, 0.2, w + 0.4), "machine_grey")
	_lamp = OmniLight3D.new()
	_lamp.light_color = Color(0.8, 0.88, 1.0)
	_lamp.light_energy = 0.0
	_lamp.omni_range = 14.0
	_lamp.shadow_enabled = false
	_lamp.position = Vector3(-1.0, h + 0.4, 0)
	g.add_child(_lamp)
	for c: Node in g.find_children("*", "GeometryInstance3D", true, false):
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ThalbachLife.merge(g)


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


## Trap protocol (the bots' trap use, TrapLever-style callers): the fan is free.
func trap_name() -> String:
	return "Wind Tunnel"


func cost() -> int:
	return 0


func can_activate() -> bool:
	return can_start(GameState.power_on, needs_power, running, cooldown)


func status_text() -> String:
	return get_prompt(null)


func activate(pid: int) -> bool:
	if not can_activate():
		return false
	by_player = pid
	start_run()
	return true


func interact(player: Player) -> void:
	if not Net.is_authority() or not can_interact(player):
		return
	by_player = player.player_id
	start_run()
	Net.mirror(self, &"start_run")
	GLBus.trap_activated.emit(&"wind_tunnel", player.player_id)


func start_run() -> void:
	running = run_seconds
	_stagger_t = 0.0
	GameState.set_flag(&"tunnel_running")
	GameState.set_flag(&"tunnel_ran")
	AudioDirector.play_3d("power_on", global_position, -2.0)
	AudioDirector.play_3d("a1_fan_spinup" if AudioDirector.has_sound("a1_fan_spinup") else "kranich_wind_gust", Vector3(2.0, 3.5, 115.0), 6.0, 0.0)
	if _hum == null and AudioDirector.has_sound("ambient_map04a_tunnel"):
		_hum = AudioDirector.make_loop_3d("ambient_map04a_tunnel", self, 4.0)
	var hud: Node = get_tree().get_first_node_in_group(&"hud")
	if hud != null:
		hud.call("show_banner", "THE WIND TUNNEL RUNS", 2.0)
	_set_hatch(true)


## The power-on spectacle: the fan turns over once on its own for a few seconds (no wind, no trap).
func spin_up_once() -> void:
	if GameState.has_flag(&"tunnel_spun"):
		return
	GameState.set_flag(&"tunnel_spun")
	_spin_burst = 6.0
	AudioDirector.play_3d("a1_fan_spinup" if AudioDirector.has_sound("a1_fan_spinup") else "kranich_wind_gust", Vector3(2.0, 3.5, 115.0), 2.0, 0.0)


func _process(delta: float) -> void:
	# the fan's blades: up to speed while it runs, a slow show spin on power, coasting down otherwise
	var target: float = 0.0
	if running > 0.0:
		target = 14.0
	elif _spin_burst > 0.0:
		_spin_burst -= delta
		target = 5.0
	_fan_speed = move_toward(_fan_speed, target, delta * (3.0 if target > _fan_speed else 1.2))
	if _lamp != null:
		_lamp.light_energy = 2.4 if running > 0.0 else (0.5 if GameState.power_on else 0.0)
	if _fan != null and _fan_speed > 0.001:
		_fan.rotate_object_local(Vector3.RIGHT, _fan_speed * delta)
	if _hum != null and running <= 0.0 and _fan_speed < 0.5:
		_hum.queue_free()
		_hum = null


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
	# players drift at a true player_push_mps: Player.external_push ADDS its vector to the velocity every frame (a
	# shove, not a speed), so the wind moves the body itself, through move_and_collide (walls still stop it). Only the
	# bodies this peer simulates: the local human, and the bots on the host. Skyhook's push_resist applies.
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or p.downed or not inside(p.global_position, lo, hi):
			continue
		if not (p.is_local or (p.is_bot and Net.is_authority())):
			continue
		var resist: float = clampf(float(PerkManager.stat(p.player_id, "push_resist", 0.0)), 0.0, 1.0)
		p.move_and_collide(push_for(true, push_mps, player_push_mps) * (1.0 - resist) * delta)
	for d: Node in get_tree().get_nodes_in_group(&"director"):
		var dir: ZombieDirector = d as ZombieDirector
		if dir == null:
			continue
		for z: Zombie in dir.active_zombies():
			if z == null or not is_instance_valid(z) or not z.is_active():
				continue
			if Net.is_authority() and at_screen(z.global_position, lo, hi, screen_depth):
				_shred(z)
				continue
			if not inside(z.global_position, lo, hi):
				continue
			z.external_push(push_for(false, push_mps, player_push_mps) + part_round(z.global_position, sting, sting_radius, push_mps), 0.25)
			if stagger:
				z.force_stagger()
	if running <= 0.0:
		running = 0.0
		cooldown = cooldown_seconds
		GameState.set_flag(&"tunnel_running", false)
		_set_hatch(false)


func _shred(z: Zombie) -> void:
	var at: Vector3 = z.global_position + Vector3(0, 1.0, 0)
	TrapLever.trap_kill(z, 999999.0, "wind_tunnel", by_player)
	shredded += 1
	_shred_fx(at)
	Net.mirror(self, &"_shred_fx", [at])


func _shred_fx(at: Vector3) -> void:
	Effects.blood(at, Vector3(1, 0, 0))
	Effects.dirt_burst(at, "earth", 1.6, Vector3(1, 0.3, 0), 18)
	AudioDirector.play_3d("zombie_gib", at, 2.0, 0.1)


func _set_hatch(open: bool) -> void:
	var h: Node = get_node_or_null(hatch_path)
	if h == null or not h.has_method("set_open"):
		return
	if open and not hatch_allowed(GameState.is_zone_open(&"F_WINDKANAL"), GameState.is_zone_open(&"E_MONTAGE")):
		h.call("rattle")
		return
	h.call("set_open", open)
