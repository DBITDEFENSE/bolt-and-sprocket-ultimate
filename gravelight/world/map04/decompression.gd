class_name DecompressionBreach
extends Node3D
## UPDATE 10 §3 (contract C6 `decompression`, DECISIONS T-156): a breach event on the Kranich's flight clock, two
## per act (map04b.json flight.decompression: the bay's aft ramp seam at act round 2, the starboard crawlway's
## leading edge at act round 5). FlightController calls start() on the host:
##   WARN  warn_s: the Bordfunk (PA_M4B_DECOMP_01), the hull groans, the seam's lamp flashes red
##   PULL  seconds: a suction volume (radius, pull_mps toward the breach): every unanchored zombie is pulled; one
##         that reaches the edge (edge_m) is pulled out into the night with a scream (a kill, no Scrip); a player
##         in the volume who is not holding a rail (RailGrip, next to the breach) slides to the edge and goes down
##         there (never out: co-op a normal down; solo the scripted down WingWalk uses); the bay's stowage net
##         bursts: ammo_out AmmoDrop pickups land at ammo_at
##   DONE  the seam holds again (the hull's own patch), the event never repeats
## Host-owned: the host pulls the zombies and decides the kills; every peer pulls its own local player (anchored if
## their current hold is a RailGrip) and runs the presentation from the mirrored phase. Group "decompressions".
## Pure rules are static for the tests (`pull_for`, `at_edge`, `anchored`).

enum Phase { IDLE, WARN, PULL, DONE }

const DATA: String = "res://data/gravelight/map04b.json"

## The hole's centre, local to this node (the node sits on the floor at the wall; its front, local -Z, faces into the room).
@export var hole_local: Vector3 = Vector3(0, 1.0, 0)

var cfg: Dictionary = {}
var phase: int = Phase.IDLE
var phase_t: float = 0.0
var sucked_out: int = 0
var downs: int = 0
var drops: int = 0
var _tick_t: float = 0.0
var _downed: Dictionary = {}     # pid -> true (once per event)
var _lamp: OmniLight3D = null
var _plate: MeshInstance3D = null
var _wind: CPUParticles3D = null


# ---------------------------------------------------------------- pure rules

## The pull (m/s, flat) toward `hole` on a body at `p`: zero outside `radius`, stronger near the hole.
static func pull_for(hole: Vector3, p: Vector3, radius: float, mps: float) -> Vector3:
	var d: Vector3 = hole - p
	d.y = 0.0
	var dist: float = d.length()
	if dist > radius or dist < 0.01:
		return Vector3.ZERO
	return d / dist * mps * (0.5 + 0.5 * (1.0 - dist / radius))


## Has a body at `p` reached the breach's edge (flat distance)?
static func at_edge(hole: Vector3, p: Vector3, edge_m: float) -> bool:
	return Vector2(hole.x - p.x, hole.z - p.z).length() <= edge_m


## Is this player holding on? (a RailGrip counts them among its holders)
static func anchored(p: Player) -> bool:
	if p == null or not p.is_inside_tree():
		return false
	for n: Node in p.get_tree().get_nodes_in_group(&"rail_grips"):
		var g: RailGrip = n as RailGrip
		if g != null and g.holds(p.player_id):
			return true
	return false


# ---------------------------------------------------------------- setup

func _ready() -> void:
	add_to_group(&"decompressions")
	cfg = (GLData.load_json(DATA).get("flight", {}) as Dictionary).get("decompression", {})
	_plate = Props.block(self, Vector3(-1.2, 0.1, -0.12), Vector3(1.2, 2.0, 0.08), "lead")
	_lamp = OmniLight3D.new()
	_lamp.position = Vector3(0, 2.3, -0.5)
	_lamp.light_color = Color(1.0, 0.18, 0.1)
	_lamp.light_energy = 0.0
	_lamp.omni_range = 6.0
	_lamp.shadow_enabled = false
	add_child(_lamp)
	_wind = CPUParticles3D.new()
	_wind.position = Vector3(0, 1.0, -2.5)
	_wind.amount = 80
	_wind.lifetime = 0.6
	_wind.emitting = false
	_wind.direction = Vector3(0, 0, 1)
	_wind.spread = 30.0
	_wind.gravity = Vector3.ZERO
	_wind.initial_velocity_min = 8.0
	_wind.initial_velocity_max = 14.0
	_wind.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_wind.emission_box_extents = Vector3(3, 1, 2)
	_wind.mesh = BoxMesh.new()
	_wind.mesh.set("size", Vector3(0.04, 0.04, 0.4))
	_wind.material_override = Mats.get_mat("lead")
	add_child(_wind)
	var l: Label3D = Interactable.add_label(self, "DRUCKSPANT · NICHT ANLEHNEN", Vector3(0, 2.15, -0.14), 14, Color(0.95, 0.4, 0.3))
	l.outline_size = 3


func hole() -> Vector3:
	return to_global(hole_local)


# ---------------------------------------------------------------- the event

## Host: the event begins (the warning first).
func start() -> void:
	if phase != Phase.IDLE:
		return
	_enter(Phase.WARN)
	if Net.is_authority():
		GLVO.play(StringName(str(cfg.get("vo_warn", "PA_M4B_DECOMP_01"))))
		Net.mirror(self, &"_enter", [Phase.WARN])


func _enter(ph: int) -> void:
	phase = ph
	phase_t = 0.0
	match ph:
		Phase.WARN:
			AudioDirector.play_3d("kranich_creak", hole(), 6.0, 0.1)
			_downed.clear()
		Phase.PULL:
			if _plate != null:
				_plate.visible = false
			_wind.emitting = true
			_lamp.light_energy = 2.5
			AudioDirector.play_3d("grenade_explode", hole(), 6.0, 0.3)
			AudioDirector.play_3d("kranich_wind_gust", hole(), 6.0, 0.1)
			for n: Node in get_tree().get_nodes_in_group(&"players"):
				if (n as Node3D).global_position.distance_to(hole()) < 16.0:
					n.set("_shake", 0.6)
		Phase.DONE:
			if _plate != null:
				_plate.visible = true
			_wind.emitting = false
			_lamp.light_energy = 0.0
			AudioDirector.play_3d("board_repair", hole(), 2.0, 0.0)
	print("[decomp] %s -> %s" % [name, ["idle", "warn", "pull", "done"][ph]])


func _process(delta: float) -> void:
	if phase == Phase.IDLE or phase == Phase.DONE:
		return
	phase_t += delta
	if phase == Phase.WARN:
		_lamp.light_energy = 2.0 if fmod(phase_t, 0.5) < 0.25 else 0.2
		if Net.is_authority() and phase_t >= float(cfg.get("warn_s", 3.0)):
			_enter(Phase.PULL)
			Net.mirror(self, &"_enter", [Phase.PULL])
			_drop_ammo()
		return
	# PULL
	_tick_t -= delta
	if _tick_t <= 0.0:
		_tick_t = 0.15
		_pull_players()
		if Net.is_authority():
			_pull_zombies()
	if Net.is_authority() and phase_t >= float(cfg.get("seconds", 4.0)):
		_enter(Phase.DONE)
		Net.mirror(self, &"_enter", [Phase.DONE])


## Every peer pulls its own player (the host also its bots); a player who reaches the edge goes down there.
func _pull_players() -> void:
	var radius: float = float(cfg.get("radius", 9.0))
	var mps: float = float(cfg.get("pull_mps", 6.0))
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not p.is_alive() or p.spectating:
			continue
		if not (p.is_local or (p.is_bot and Net.is_authority())):
			continue
		if anchored(p):
			continue
		if at_edge(hole(), p.global_position, float(cfg.get("edge_m", 1.4))):
			if bool(cfg.get("player_down", true)) and not _downed.has(p.player_id):
				_downed[p.player_id] = true
				downs += 1
				down_at_edge(p)
			continue
		var v: Vector3 = pull_for(hole(), p.global_position, radius, mps)
		if v != Vector3.ZERO:
			p.external_push(v, 0.2, &"pull")


## A player at the breach's edge goes down there, never out (solo: the scripted down; the match goes on).
func down_at_edge(p: Player) -> void:
	p.velocity = Vector3.ZERO
	if GameState.god_mode and not p.is_bot:
		return   # god mode (the dev launcher, smokes, captures): held at the edge, not downed
	if p.is_local:
		var hud: Node = get_tree().get_first_node_in_group(&"hud")
		if hud != null:
			hud.call("show_banner", "PULLED TO THE BREACH\nhold a rail next time", 2.5)
	if GameState.is_solo() and not p.is_bot:
		var ww: WingWalk = get_tree().get_first_node_in_group(&"wing_walks") as WingWalk
		if ww != null:
			ww.solo_down(p)
			return
		p.downed = true
		get_tree().create_timer(4.0).timeout.connect(func() -> void:
			if is_instance_valid(p) and p.downed:
				p.revive(p.player_id))
	else:
		p.down()


## Host: the dead are pulled; at the edge they go out into the night.
func _pull_zombies() -> void:
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	if dir == null:
		return
	var radius: float = float(cfg.get("radius", 9.0))
	var mps: float = float(cfg.get("pull_mps", 6.0))
	for z: Zombie in dir.active_zombies():
		if not z.is_active() or z.puppet or z is HomageBoss:
			continue
		if at_edge(hole(), z.global_position, float(cfg.get("edge_m", 1.4)) + 0.3):
			_suck_out(z)
			continue
		var v: Vector3 = pull_for(hole(), z.global_position, radius, mps)
		if v != Vector3.ZERO:
			z.external_push(v, 0.2)


func _suck_out(z: Zombie) -> void:
	var at: Vector3 = z.global_position
	z.take_damage(z.hp + 1.0, &"torso", &"decompression", 0, &"world")
	sucked_out += 1
	_scream(at)
	Net.mirror(self, &"_scream", [at])


func _scream(at: Vector3) -> void:
	AudioDirector.play_3d("screamer_scream" if AudioDirector.has_sound("screamer_scream") else "impact_flesh", at, -4.0, 0.2)


## Host: the stowage net bursts in the bay: two ammo boxes' worth of walk-over refills.
func _drop_ammo() -> void:
	var pts: Array = cfg.get("ammo_at", [])
	var n: int = mini(int(cfg.get("ammo_out", 2)), pts.size())
	var parent: Node = get_parent()
	for i: int in n:
		var a: Array = pts[i]
		var d: AmmoDrop = AmmoDrop.new()
		d.name = "AmmoOut_%s_%d" % [name, i]
		parent.add_child(d)
		d.global_position = Vector3(float(a[0]), float(a[1]), float(a[2]))
		drops += 1
	Net.mirror(self, &"_drop_mirror", [n])


func _drop_mirror(n: int) -> void:
	if Net.is_authority():
		return
	var pts: Array = cfg.get("ammo_at", [])
	for i: int in mini(n, pts.size()):
		var a: Array = pts[i]
		var d: AmmoDrop = AmmoDrop.new()
		d.name = "AmmoOut_%s_%d" % [name, i]
		get_parent().add_child(d)
		d.global_position = Vector3(float(a[0]), float(a[1]), float(a[2]))
