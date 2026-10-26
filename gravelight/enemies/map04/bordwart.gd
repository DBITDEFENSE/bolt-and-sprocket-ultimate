class_name Bordwart
extends HomageBoss
## DER BORDWART, Map 4 Act II's boss (UPDATE 07, docs/MAP4_FERNFLUG.md §4.7): Bordmechaniker Anselm Riedl, fused
## into the port impeller's engineer's station, tethered to it by a bundle of violet cable that is also his spine.
## He never leaves the engine room (he stands at the station and turns to face you). Phases (bosses/map04.json
## "bordwart"): (1) THE THROTTLE: he spins the impeller up: a pull toward the core window on everyone in `pull.radius`
## with a line of sight (the rib frames block it), then a VENT burst that hurts everyone within `vent.radius` and
## staggers zombies; (2) at `cable_at` THE CABLE: a 180° lash in front of him (telegraphed by the taut cable's
## sound), damage + a knockdown push; the cable is a ×`cable.weak_mult` weak point while extended; (3) at
## `overspeed_at` OVERSPEED: the room's lights die, the deck banks every `overspeed.bank_every` s (the
## FlightController), Bordschützen come through the shaft, and only the station's GAUGES (his torso) take damage
## between vents. Reward: Scrip per player, a Resupply, the `autopilot_key` flag. `failsafe_seconds` after the
## spawn he retreats. Pure rules are static for the tests (`phase_of`, `in_arc`, `damage_mult`).

enum W { IDLE, PULL, VENT_TELEGRAPH, VENT, CABLE_TELEGRAPH, CABLE, RECOVER }

var wcfg: Dictionary = {}
var wstate: W = W.IDLE
var phase: int = 1
var station: Vector3 = Vector3.ZERO
var core_point: Vector3 = Vector3.ZERO
var _wt: float = 0.0
var _spawn_t: float = 0.0
var _bank_t: float = 0.0
var _climb_t: float = 0.0
var vents_done: int = 0
var lashes_done: int = 0
var pulls_done: int = 0
var cable_out: bool = false
var _cable: Node3D = null
var _title_done: bool = false
var _lights_cut: bool = false


static func table() -> Dictionary:
	return GLData.table("bosses/map04")


func boss_cfg() -> Dictionary:
	return (table().get("bosses", {}) as Dictionary).get("bordwart", {})


## Phase by HP fraction: 1 the throttle, 2 the cable, 3 overspeed.
static func phase_of(hp_fraction: float, phases: Dictionary) -> int:
	if hp_fraction <= float(phases.get("overspeed_at", 0.3)):
		return 3
	if hp_fraction <= float(phases.get("cable_at", 0.6)):
		return 2
	return 1


## True when `p` lies in the half-plane the boss faces (`forward`), within `reach` (flat).
static func in_arc(origin: Vector3, forward: Vector3, p: Vector3, reach: float) -> bool:
	var d: Vector3 = p - origin
	d.y = 0.0
	if d.length() > reach:
		return false
	var f: Vector3 = Vector3(forward.x, 0, forward.z).normalized()
	return d.normalized().dot(f) >= 0.0


## Damage taken: ×weak while the cable is out; phase 3 only the gauges (torso) count between vents (others ×low).
static func damage_mult(phase: int, cable_out: bool, limb: StringName, venting: bool, weak: float, low: float) -> float:
	var m: float = 1.0
	if cable_out:
		m *= weak
	if phase == 3 and not venting and limb != &"torso":
		m *= low
	return m


func _ready() -> void:
	super._ready()
	boss_key = "bordwart"
	ecfg = table()
	wcfg = boss_cfg()
	bcfg = wcfg
	station = _v3(wcfg.get("station", [-72.0, 0.0, 38.0]))
	core_point = _v3(wcfg.get("core_point", [-76.6, 1.0, 38.0]))


static func _v3(a: Variant) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2])) if a is Array and (a as Array).size() >= 3 else Vector3.ZERO


func modelled() -> bool:
	return false


func person_id() -> String:
	return "bordwart"


func spawn_bordwart(_at: Vector3, health: float) -> void:
	spawn_homage(station, health)
	enemy_id = &"bordwart"
	wstate = W.IDLE
	_wt = 1.5
	_spawn_t = 0.0
	phase = 1
	_build_tether()
	RoundManager.reserve_alive(1)
	if not _title_done:
		_title_done = true
		var hud: BossHud = BossHud.new()
		_map().add_child(hud)
		hud.title_card(str(wcfg.get("title", "DER BORDWART")), str(wcfg.get("subtitle", "the flight engineer")), "ÜBER DEM ATLANTIK")
		hud.add_bar("bordwart", self, str(wcfg.get("title", "DER BORDWART")), str(wcfg.get("subtitle", "")))
		if str(wcfg.get("spawn_vo", "")) != "":
			GLVO.play(StringName(str(wcfg["spawn_vo"])))
		say("BWT_BARK_01")


func _map() -> Node:
	var n: Node = get_parent()
	while n != null and not (n is MapRoot):
		n = n.get_parent()
	return n if n != null else get_parent()


func _build_costume() -> void:
	costume("Spine", [HomageBoss.cyl(0.06, 0.06, 0.9, Vector3(0, 0.2, -0.15), Color(0.5, 0.25, 0.8), Vector3.ZERO, Vector3.ONE, 8)], 1.2)


## The tether from his back to the station (dressing; the cable lash scales it out).
func _build_tether() -> void:
	if _cable != null:
		return
	_cable = Node3D.new()
	_cable.name = "Cable"
	add_child(_cable)
	Props.cable(_cable, Vector3(0, 1.2, -0.3), Vector3(core_point.x - station.x, 1.4, core_point.z - station.z), 0.25, 0.05, 6, "nachtglas")
	var glow: OmniLight3D = OmniLight3D.new()
	glow.light_color = Color(0.62, 0.3, 1.0)
	glow.light_energy = 1.4
	glow.omni_range = 8.0
	glow.position = Vector3(0, 1.4, 0)
	_cable.add_child(glow)


func _flight() -> Node:
	return get_tree().get_first_node_in_group(&"flight_controller")


func _tick(delta: float) -> void:
	_spawn_t += delta
	_wt -= delta
	if _spawn_t > float(ecfg.get("failsafe_seconds", 360.0)) and not retreating:
		retreat()
		return
	phase = phase_of(hp_fraction(), wcfg.get("phases", {}))
	global_position = station   # tethered: he never leaves the station
	velocity = Vector3.ZERO
	if target != null:
		_face(Vector3(target.global_position.x, global_position.y, target.global_position.z))
	if phase == 3:
		_overspeed_tick(delta)
	match wstate:
		W.IDLE:
			if _wt > 0.0:
				return
			if phase >= 2 and cd_ready("cable") and target != null and dist_to(target) <= float(wcfg.get("cable", {}).get("reach", 5.0)) + 1.0:
				wstate = W.CABLE_TELEGRAPH
				_wt = float(wcfg.get("cable", {}).get("telegraph", 1.1))
				bstate = B.TELEGRAPH
				sfx("chain", 0.0, 1.3)
				say("BWT_PHASE_02" if lashes_done == 0 else "BWT_BARK_02")
			elif cd_ready("pull"):
				wstate = W.PULL
				_wt = float(wcfg.get("pull", {}).get("seconds", 5.0))
				bstate = B.ACTIVE
				pulls_done += 1
				sfx("hum", 0.0, 0.7)
				say("BWT_PHASE_01" if pulls_done == 1 else "BWT_BARK_03")
			else:
				_wt = 0.4
		W.PULL:
			var pc: Dictionary = wcfg.get("pull", {})
			for p: Player in alive_players():
				if dist_to(p) <= float(pc.get("radius", 8.0)) and has_los(p):
					var d: Vector3 = core_point - p.global_position
					d.y = 0.0
					if d.length() > 0.5:
						p.external_push(d.normalized() * float(pc.get("mps", 2.5)) * squad_speed_mult, 0.15, &"pull")
			if _wt <= 0.0:
				wstate = W.VENT_TELEGRAPH
				_wt = float(wcfg.get("vent", {}).get("telegraph", 0.9))
				bstate = B.TELEGRAPH
				sfx("chain", 0.0, 0.6)
		W.VENT_TELEGRAPH:
			if _wt <= 0.0:
				_vent()
				wstate = W.RECOVER
				_wt = 1.2
				bstate = B.RECOVER
		W.CABLE_TELEGRAPH:
			if _wt <= 0.0:
				wstate = W.CABLE
				cable_out = true
				if _cable != null:
					_cable.scale = Vector3(1, 1, 2.2)
				_wt = float(wcfg.get("cable", {}).get("active", 0.5))
				bstate = B.ACTIVE
				_lash()
		W.CABLE:
			if _wt <= 0.0:
				cable_out = false
				if _cable != null:
					_cable.scale = Vector3.ONE
				lashes_done += 1
				set_cd("cable", cd_for(float(wcfg.get("cable", {}).get("cooldown", 6.0))))
				wstate = W.RECOVER
				_wt = 0.8
				bstate = B.RECOVER
		W.RECOVER:
			if _wt <= 0.0:
				wstate = W.IDLE
				bstate = B.MOVE
				_wt = 0.3
		_:
			pass


## The vent: the core bursts: everyone within radius takes damage, zombies stagger; the pull's cooldown starts.
func _vent() -> void:
	var vc: Dictionary = wcfg.get("vent", {})
	vents_done += 1
	moves_used["vent"] = int(moves_used.get("vent", 0)) + 1
	AudioDirector.play_3d("grenade_explode", core_point, 6.0, 0.5)
	for p: Player in alive_players():
		if p.global_position.distance_to(core_point) <= float(vc.get("radius", 4.0)) and has_los(p):
			hit_player(p, float(vc.get("damage", 120)))
		if p.global_position.distance_to(core_point) < 16.0:
			p.set("_shake", 0.5)
	var dir: ZombieDirector = director as ZombieDirector
	if dir != null:
		for z: Zombie in dir.active_zombies():
			if z != self and z.is_active() and z.global_position.distance_to(core_point) <= float(vc.get("radius", 4.0)) + 2.0:
				z.force_stagger()
	set_cd("pull", cd_for(float(wcfg.get("pull", {}).get("cooldown", 7.0))))
	_hit_done = false


## The cable lash: a 180° arc in front within reach: damage and a knockdown push away.
func _lash() -> void:
	var cc: Dictionary = wcfg.get("cable", {})
	moves_used["cable"] = int(moves_used.get("cable", 0)) + 1
	sfx("chain", 2.0, 1.6)
	var fwd: Vector3 = -global_basis.z
	for p: Player in alive_players():
		if in_arc(global_position, fwd, p.global_position, float(cc.get("reach", 5.0))):
			hit_player(p, float(cc.get("damage", 90)))
			var away: Vector3 = p.global_position - global_position
			away.y = 0.0
			p.external_push(away.normalized() * 6.0 + Vector3(0, 2.0, 0), 0.35, &"push")


## Phase 3: the lights go, the deck banks on a clock, the Bordschützen come through the shaft.
func _overspeed_tick(delta: float) -> void:
	var oc: Dictionary = wcfg.get("overspeed", {})
	if not _lights_cut:
		_lights_cut = true
		say("BWT_PHASE_03")
		for l: Node in get_tree().get_nodes_in_group(&"power_lights"):
			if String(l.get_meta("zone", "")) == "D_TRIEBWERK":
				(l as OmniLight3D).light_energy = 0.0
	_bank_t -= delta
	if _bank_t <= 0.0:
		_bank_t = float(oc.get("bank_every", 15.0))
		var fc: Node = _flight()
		if fc != null:
			fc.call("bank_now")
	_climb_t -= delta
	if _climb_t <= 0.0:
		_climb_t = float(oc.get("climber_every", 10.0))
		var fc2: Node = _flight()
		if fc2 != null:
			fc2.call("spawn_climber", _v3(wcfg.get("shaft", [-77.0, 0.0, 30.0])))


func take_damage(amount: float, limb: StringName, weapon_id: StringName, by_player: int, kind: StringName = &"bullet", armor_piercing: bool = false) -> bool:
	var m: float = damage_mult(phase, cable_out, limb, wstate == W.VENT_TELEGRAPH or wstate == W.RECOVER, float(wcfg.get("cable", {}).get("weak_mult", 2.5)), float(wcfg.get("overspeed", {}).get("off_gauge_mult", 0.15)))
	return super.take_damage(amount * m, limb, weapon_id, by_player, kind, armor_piercing)


func _tele_glow() -> float:
	return 4.0 if wstate in [W.VENT_TELEGRAPH, W.CABLE_TELEGRAPH] else (1.5 if wstate == W.PULL else 0.0)


func _boss_die(limb: StringName, weapon_id: StringName, by_player: int, kind: StringName) -> void:
	super._boss_die(limb, weapon_id, by_player, kind)
	RoundManager.release_alive(1)
	cable_out = false
	say("BWT_DEATH_01")
	for d: Variant in wcfg.get("drops", []):
		PowerupManager.spawn(StringName(str(d)), station + Vector3(2.0, 0.3, 0))
	if str(wcfg.get("flag", "")) != "":
		GameState.set_flag(StringName(str(wcfg["flag"])))
	if str(wcfg.get("death_vo", "")) != "":
		GLVO.play(StringName(str(wcfg["death_vo"])))
	for l: Node in get_tree().get_nodes_in_group(&"power_lights"):
		if String(l.get_meta("zone", "")) == "D_TRIEBWERK" and GameState.power_on:
			(l as OmniLight3D).light_energy = float(l.get_meta("energy", 1.0))


func _on_retreat() -> void:
	# the reserve_alive of the spawn and the take_extra_spawn count: a death pays the latter in HomageBoss._boss_die,
	# a retreat has no death, and the round could never end on it (T-109)
	RoundManager.release_alive(2)


func _start_authored_death() -> void:
	_tree_play("Death", "death_knee", 1.0)
