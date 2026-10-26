class_name Kranfuehrer
extends HomageBoss
## DER KRANFÜHRER, Map 4 Act I's boss (UPDATE 07, docs/MAP4_FERNFLUG.md §3.8): the Great Hangar's night crane
## driver, fused into the gantry crane's cab 12 m up. He IS the crane: the body (the driver, the weak point) rides a
## trolley along the east crane rail; the bridge spans the hangar under him and the hook hangs from it. Phases
## (data: bosses/map04.json "kranfuehrer"): (1) CASINGS: he runs the rail and drops bomb casings on a player
## (a chain rattle telegraph, then a 2.5 m impact that hurts everyone and kills zombies); (2) at `sweep_at` HP
## he lowers the hook and SWEEPS the floor along the bridge at 3 m/s (duck under the Kranich's belly or get
## off the line); (3) at `park_at` he PARKS over the ramp and drops a RING of casings round it, and the cab is
## best reached from the crane-rail catwalks. Reward: Scrip per player, a Resupply, and the `hangar_key` flag.
## He never leaves the rail; `failsafe_seconds` after spawning he retreats (a round can never softlock on him).
## Pure rules are static for the tests (`phase_of`, `next_trolley_z`, `hook_hits`).

enum K { RUN, TELEGRAPH_DROP, DROP, SWEEP_TELEGRAPH, SWEEP, PARK_TELEGRAPH, RING, RECOVER }

var kcfg: Dictionary = {}
var rail: Dictionary = {}
var kstate: K = K.RUN
var trolley_z: float = 0.0
var dir_z: float = 1.0
var hook_x: float = 0.0
var hook_down: bool = false
var sweep_dir: float = 1.0
var _target_pos: Vector3 = Vector3.ZERO
var _kt: float = 0.0
var _spawn_t: float = 0.0
var phase: int = 1
var drops_done: int = 0
var sweeps_done: int = 0
var rings_done: int = 0
var _crane: Node3D = null
var _bridge: Node3D = null
var _hook: Node3D = null
var _title_done: bool = false


static func table() -> Dictionary:
	return GLData.table("bosses/map04")


func _dir() -> ZombieDirector:
	return director as ZombieDirector


func boss_cfg() -> Dictionary:
	return (table().get("bosses", {}) as Dictionary).get("kranfuehrer", {})


## Phase by HP fraction: 1 casings, 2 the sweep, 3 parked over the ramp.
static func phase_of(hp_fraction: float, phases: Dictionary) -> int:
	if hp_fraction <= float(phases.get("park_at", 0.3)):
		return 3
	if hp_fraction <= float(phases.get("sweep_at", 0.6)):
		return 2
	return 1


## The trolley's next z running toward `want_z` at `speed`, clamped to the rail.
static func next_trolley_z(z: float, want_z: float, speed: float, delta: float, z_min: float, z_max: float) -> float:
	return clampf(move_toward(z, clampf(want_z, z_min, z_max), speed * delta), z_min, z_max)


## True when a body at `p` is hit by the hook sweeping at `hook` (within half_width along z, under `height`, on the bridge's span).
static func hook_hits(hook: Vector3, p: Vector3, half_width: float, height: float, x_min: float, x_max: float) -> bool:
	return absf(p.z - hook.z) <= half_width and p.y < hook.y + height and p.x >= x_min and p.x <= x_max


func _ready() -> void:
	super._ready()
	boss_key = "kranfuehrer"
	ecfg = table()
	kcfg = boss_cfg()
	bcfg = kcfg
	rail = kcfg.get("rail", {})


func modelled() -> bool:
	return false


func person_id() -> String:
	return "kranfuehrer"


## Brings the crane in: the driver on the trolley at the rail's near end.
func spawn_crane(_at: Vector3, health: float) -> void:
	spawn_homage(Vector3(float(rail.get("x", 28.0)), float(rail.get("y", 12.0)), float(rail.get("z_min", 156.0))), health)
	enemy_id = &"kranfuehrer"
	collision_mask = 0
	trolley_z = float(rail.get("z_min", 156.0))
	hook_x = (float(rail.get("bridge_x_min", -68.0)) + float(rail.get("bridge_x_max", 28.0))) * 0.5
	kstate = K.RUN
	_kt = 0.0
	_spawn_t = 0.0
	phase = 1
	_build_crane()
	RoundManager.reserve_alive(1)
	if not _title_done:
		_title_done = true
		var hud: BossHud = BossHud.new()
		_map().add_child(hud)
		hud.title_card(str(kcfg.get("title", "DER KRANFÜHRER")), str(kcfg.get("subtitle", "the crane driver")), "MAI 1945  ·  WERK THALBACH")
		hud.add_bar("kranfuehrer", self, str(kcfg.get("title", "DER KRANFÜHRER")), str(kcfg.get("subtitle", "")))
		if str(kcfg.get("spawn_vo", "")) != "":
			GLVO.play(StringName(str(kcfg["spawn_vo"])))


func _map() -> Node:
	var n: Node = get_parent()
	while n != null and not (n is MapRoot):
		n = n.get_parent()
	return n if n != null else get_parent()


func _build_costume() -> void:
	pass


## The crane itself: the trolley cab round the driver, the bridge under the rail, the hook on its chain.
func _build_crane() -> void:
	if _crane != null:
		return
	_crane = Node3D.new()
	_crane.name = "Crane"
	add_child(_crane)
	var cab: Node3D = Props.group(_crane, "Cab", Vector3(0, 0, 0))
	Props.block(cab, Vector3(-1.4, -0.3, -1.4), Vector3(1.4, -0.1, 1.4), "crane_yellow")
	Props.block(cab, Vector3(-1.4, -0.1, -1.4), Vector3(-1.25, 2.2, 1.4), "crane_yellow")
	Props.block(cab, Vector3(-1.4, 2.2, -1.4), Vector3(1.4, 2.4, 1.4), "crane_yellow")
	Props.block(cab, Vector3(-1.4, -0.1, -1.4), Vector3(1.4, 1.0, -1.25), "crane_yellow")
	Props.block(cab, Vector3(-1.4, -0.1, 1.25), Vector3(1.4, 1.0, 1.4), "crane_yellow")
	_bridge = Props.group(_crane, "Bridge", Vector3(0, -0.4, 0))
	var span: float = float(rail.get("bridge_x_max", 28.0)) - float(rail.get("bridge_x_min", -68.0))
	Props.block(_bridge, Vector3(-span - 1.5, 0.0, -0.5), Vector3(1.5, 0.8, 0.5), "crane_yellow")
	_hook = Props.group(_crane, "Hook", Vector3(hook_x - global_position.x, -0.4, 0))
	Props.cable(_hook, Vector3(0, 0, 0), Vector3(0, -1.0, 0), 0.0, 0.03, 2, "iron")
	Props.block(_hook, Vector3(-0.3, -1.6, -0.3), Vector3(0.3, -1.0, 0.3), "iron")
	var glow: OmniLight3D = OmniLight3D.new()
	glow.light_color = Color(1.0, 0.7, 0.3)
	glow.light_energy = 1.2
	glow.omni_range = 10.0
	glow.position = Vector3(0, 1.5, 0)
	_crane.add_child(glow)


func _hook_world() -> Vector3:
	var hy: float = global_position.y - 0.4 - (float(kcfg.get("sweep", {}).get("height", 2.0)) + 9.0 if hook_down else 1.6)
	return Vector3(hook_x, hy, trolley_z)


func _set_hook_visual() -> void:
	if _hook == null:
		return
	_hook.position.x = hook_x - global_position.x
	var drop: float = (float(kcfg.get("sweep", {}).get("height", 2.0)) + 9.0) if hook_down else 1.6
	_hook.scale.y = maxf(0.2, drop / 1.6)


func _tick(delta: float) -> void:
	_spawn_t += delta
	_kt += delta
	if _spawn_t > float(ecfg.get("failsafe_seconds", 360.0)) and not retreating:
		retreat()
		return
	phase = phase_of(hp_fraction(), kcfg.get("phases", {}))
	var speed: float = float(rail.get("speed", 3.0)) * squad_speed_mult
	var z_min: float = float(rail.get("z_min", 156.0))
	var z_max: float = float(rail.get("z_max", 212.0))
	var want_z: float = trolley_z
	match kstate:
		K.RUN:
			# run the rail toward the nearest player's z (phase 3: toward the ramp); begin a move when its clock is ready
			if phase == 3:
				want_z = float(rail.get("ramp_z", 162.0))
			elif target != null:
				want_z = target.global_position.z
			trolley_z = next_trolley_z(trolley_z, want_z, speed, delta, z_min, z_max)
			if phase == 3 and absf(trolley_z - want_z) < 0.5 and cd_ready("ring"):
				kstate = K.PARK_TELEGRAPH
				_kt = 0.0
				bstate = B.TELEGRAPH
				sfx("chain", 0.0, 0.8)
			elif phase == 2 and cd_ready("sweep") and target != null and absf(trolley_z - want_z) < 2.0:
				kstate = K.SWEEP_TELEGRAPH
				_kt = 0.0
				bstate = B.TELEGRAPH
				sweep_dir = 1.0 if target.global_position.x > hook_x else -1.0
				sfx("chain", 0.0, 0.7)
			elif phase != 3 and cd_ready("casing") and target != null and absf(trolley_z - want_z) < 1.5:
				kstate = K.TELEGRAPH_DROP
				_kt = 0.0
				bstate = B.TELEGRAPH
				var lead: float = float(kcfg.get("casing", {}).get("lead", 0.6))
				_target_pos = target.global_position + Vector3(target.velocity.x, 0, target.velocity.z) * lead
				_target_pos.x = clampf(_target_pos.x, float(rail.get("bridge_x_min", -68.0)), float(rail.get("bridge_x_max", 28.0)))
				_target_pos.z = trolley_z
				hook_x = _target_pos.x
				sfx("chain", 0.0, 1.0)
		K.TELEGRAPH_DROP:
			if _kt >= float(kcfg.get("casing", {}).get("telegraph", 1.6)):
				kstate = K.DROP
				_kt = 0.0
				bstate = B.ACTIVE
		K.DROP:
			if _kt >= float(kcfg.get("casing", {}).get("fall_seconds", 0.9)):
				_impact(Vector3(_target_pos.x, _target_pos.y, _target_pos.z), float(kcfg.get("casing", {}).get("radius", 2.5)),
					float(kcfg.get("casing", {}).get("damage", 150)), float(kcfg.get("casing", {}).get("zombie_damage", 4000)))
				drops_done += 1
				moves_used["casing"] = int(moves_used.get("casing", 0)) + 1
				set_cd("casing", float(kcfg.get("casing", {}).get("cooldown", 5.0)))
				kstate = K.RECOVER
				_kt = 0.0
				bstate = B.RECOVER
		K.SWEEP_TELEGRAPH:
			if _kt >= float(kcfg.get("sweep", {}).get("telegraph", 1.2)):
				kstate = K.SWEEP
				hook_down = true
				hook_x = float(rail.get("bridge_x_min", -68.0)) if sweep_dir > 0.0 else float(rail.get("bridge_x_max", 28.0))
				_kt = 0.0
				bstate = B.ACTIVE
		K.SWEEP:
			var sw: Dictionary = kcfg.get("sweep", {})
			hook_x += sweep_dir * float(sw.get("speed", 3.0)) * squad_speed_mult * delta
			var hk: Vector3 = _hook_world()
			for p: Player in alive_players():
				if hook_hits(hk, p.global_position, float(sw.get("half_width", 1.5)), float(sw.get("height", 2.0)), float(rail.get("bridge_x_min", -68.0)), float(rail.get("bridge_x_max", 28.0))) and not _hit_players.has(p.player_id):
					_hit_players[p.player_id] = true
					hit_player(p, float(sw.get("damage", 90)))
			if _dir() != null:
				for z: Zombie in _dir().active_zombies():
					if z != self and z.is_active() and hook_hits(hk, z.global_position, float(sw.get("half_width", 1.5)), float(sw.get("height", 2.0)), float(rail.get("bridge_x_min", -68.0)), float(rail.get("bridge_x_max", 28.0))):
						z.take_damage(4000.0, &"torso", &"kranfuehrer", 0, &"melee")
			if hook_x <= float(rail.get("bridge_x_min", -68.0)) or hook_x >= float(rail.get("bridge_x_max", 28.0)):
				hook_down = false
				_hit_players.clear()
				sweeps_done += 1
				moves_used["sweep"] = int(moves_used.get("sweep", 0)) + 1
				set_cd("sweep", float(sw.get("cooldown", 7.0)))
				kstate = K.RECOVER
				_kt = 0.0
				bstate = B.RECOVER
		K.PARK_TELEGRAPH:
			if _kt >= float(kcfg.get("ring", {}).get("telegraph", 1.8)):
				kstate = K.RING
				_kt = 0.0
				bstate = B.ACTIVE
		K.RING:
			var rg: Dictionary = kcfg.get("ring", {})
			var center: Vector3 = Vector3(hook_x, 0.0, trolley_z)
			var n: int = int(rg.get("count", 6))
			for i: int in n:
				var a: float = TAU * float(i) / float(n)
				_impact(center + Vector3(cos(a), 0, sin(a)) * float(rg.get("radius", 9.0)), float(rg.get("impact_radius", 2.5)),
					float(rg.get("damage", 150)), float(rg.get("zombie_damage", 4000)))
			rings_done += 1
			moves_used["ring"] = int(moves_used.get("ring", 0)) + 1
			set_cd("ring", float(rg.get("cooldown", 8.0)))
			kstate = K.RECOVER
			_kt = 0.0
			bstate = B.RECOVER
		K.RECOVER:
			if _kt >= 0.8:
				kstate = K.RUN
				bstate = B.MOVE
	global_position = Vector3(float(rail.get("x", 28.0)), float(rail.get("y", 12.0)), trolley_z)
	velocity = Vector3.ZERO
	if target != null:
		_face(Vector3(target.global_position.x, global_position.y, target.global_position.z))
	_set_hook_visual()


var _hit_players: Dictionary = {}


func _impact(at: Vector3, radius: float, damage: float, zombie_damage: float) -> void:
	AudioDirector.play_3d("board_slam", at + Vector3.UP, 8.0, 0.6)
	for p: Player in alive_players():
		if Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length() <= radius and absf(p.global_position.y - at.y) < 3.0:
			hit_player(p, damage)
		if p.global_position.distance_to(at) < 20.0:
			p.set("_shake", 0.5)
	if _dir() != null:
		for z: Zombie in _dir().active_zombies():
			if z != self and z.is_active() and Vector2(z.global_position.x - at.x, z.global_position.z - at.z).length() <= radius and absf(z.global_position.y - at.y) < 3.0:
				z.take_damage(zombie_damage, &"torso", &"kranfuehrer", 0, &"explosive")
	# a casing left on the floor (dressing, cleared with the round)
	var casing: MeshInstance3D = Props.cyl(_map() as Node3D if _map() is Node3D else self, at + Vector3(0, 0.35, 0), 0.35, 2.0, "steel", Vector3(0, 0, 90))
	if casing != null:
		casing.add_to_group(&"map04_casings")
		get_tree().create_timer(40.0).timeout.connect(func() -> void:
			if is_instance_valid(casing):
				casing.queue_free())


func _tele_glow() -> float:
	return 4.0 if kstate in [K.TELEGRAPH_DROP, K.SWEEP_TELEGRAPH, K.PARK_TELEGRAPH] else 0.0


func _boss_die(limb: StringName, weapon_id: StringName, by_player: int, kind: StringName) -> void:
	super._boss_die(limb, weapon_id, by_player, kind)
	RoundManager.release_alive(1)
	hook_down = false
	for d: Variant in kcfg.get("drops", []):
		PowerupManager.spawn(StringName(str(d)), Vector3(hook_x, 0.3, trolley_z))
	if str(kcfg.get("flag", "")) != "":
		GameState.set_flag(StringName(str(kcfg["flag"])))
	if str(kcfg.get("death_vo", "")) != "":
		GLVO.play(StringName(str(kcfg["death_vo"])))
	if is_instance_valid(_crane):
		get_tree().create_timer(6.0).timeout.connect(func() -> void:
			if is_instance_valid(_crane):
				_crane.visible = false)


func _on_retreat() -> void:
	# the reserve_alive of the spawn and the take_extra_spawn count: a death pays the latter in HomageBoss._boss_die,
	# a retreat has no death, and the round could never end on it (T-109)
	RoundManager.release_alive(2)


func _start_authored_death() -> void:
	_tree_play("Death", "death_knee", 1.0)
