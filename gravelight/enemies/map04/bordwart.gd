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
## spawn he retreats. Pure rules are static for the tests (`phase_of`, `in_arc`, `damage_mult`, `pull_mps`).
## T-234 (docs/BOSS_REWORK.md, docs/boss_rework/w4_fernflug.md): he stands half in the station (the cabinet he has
## grown into, its gauges lit, steam from its vents), the violet cable spine runs up his back into the boom and on to
## the core, cracks glow where the metal meets him, his eyes catch the gauges; the impeller is a loop
## (`bordwart_impeller_loop`) that climbs with the pull and the Overspeed, the lash's tell is the cable singing
## (`bordwart_cable_sing`) with the whip shown taut, every telegraph lights through the kit, the vent bursts steam
## and motes and flares the core. The new beat: Overspeed banks the deck into darkness (every light within
## `overspeed.dark_radius` gutters out through the kit) with only the core's white (`overspeed.core_energy`) and the
## vents' flashes at each vent and each bank. The squad rule: the pull takes a player under `pull.hurt_below`
## health at `pull.hurt_mult` (the impeller takes the weak first; the pull itself is the tell).

enum W { IDLE, PULL, VENT_TELEGRAPH, VENT, CABLE_TELEGRAPH, CABLE, RECOVER }

const VIOLET: Color = Color(0.62, 0.3, 1.0)
const CORE_WHITE: Color = Color(0.92, 0.9, 1.0)

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
var _whip: MeshInstance3D = null
var _title_done: bool = false
var _lights_cut: bool = false
# T-234
var overspeed_on: bool = false
var vent_flashes: int = 0
var banks_called: int = 0
var hurt_pulls: int = 0               # pull ticks that took a hurt player harder (the smoke, the tests)
var _core_light: OmniLight3D = null
var _impeller: AudioStreamPlayer3D = null
var _vent_steam: Array[GPUParticles3D] = []
var _gauge_mats: Array[StandardMaterial3D] = []
var _breath_t: float = 4.0
var _flash_tw: Tween = null


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


## T-234: the pull's speed on a player at `health_fraction`: `hurt_mult` x under `hurt_below`.
static func pull_mps(base: float, health_fraction: float, hurt_below: float, hurt_mult: float) -> float:
	return base * (hurt_mult if health_fraction < hurt_below else 1.0)


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


func rcfg() -> Dictionary:
	return wcfg.get("rework", {})


func spawn_bordwart(_at: Vector3, health: float) -> void:
	spawn_homage(station, health)
	enemy_id = &"bordwart"
	wstate = W.IDLE
	_wt = 1.5
	_spawn_t = 0.0
	phase = 1
	overspeed_on = false
	_lights_cut = false
	_set_inst("inst_dirt", 0.45)
	_build_tether()
	RoundManager.reserve_alive(1)
	if _impeller != null:
		_impeller.pitch_scale = 1.0
		_impeller.play()
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


# ================================================================== the model (T-234)

## The man: the violet cable spine up his back into the boom, cracks where it enters, the engineer's cap, his eyes
## catching the gauges, sweat on the skin; the whip (the lash's cable) built once and shown when it is out.
func _build_costume() -> void:
	cable("Spine", [Vector3(0, -0.2, 0.1), Vector3(0, 0.05, 0.15), Vector3(0, 0.3, 0.14), Vector3(0.05, 0.55, 0.2), Vector3(0.1, 0.8, 0.45)], 0.03, Color(0.5, 0.25, 0.8), 1.6, VIOLET)
	cable("Spine", [Vector3(-0.07, 0.1, 0.13), Vector3(-0.1, 0.4, 0.16), Vector3(-0.08, 0.75, 0.42)], 0.016, Color(0.4, 0.2, 0.7), 1.2, VIOLET)
	cable("Spine", [Vector3(0.07, 0.0, 0.13), Vector3(0.12, 0.35, 0.17), Vector3(0.14, 0.72, 0.4)], 0.016, Color(0.4, 0.2, 0.7), 1.2, VIOLET)
	cracks("Spine", 10, 0.17, -0.1, 0.4, VIOLET, 1.5, 7)
	cracks("Neck", 4, 0.07, -0.02, 0.08, VIOLET, 1.3, 9)
	wet(0.28)
	eye_glow(Color(0.9, 0.8, 1.0), 0.9, 5.0)
	costume("Head", [HomageBoss.cyl(0.17, 0.17, 0.08, Vector3(0, 0.17, 0), Color(0.18, 0.2, 0.22), Vector3.ZERO, Vector3.ONE, 12),
		HomageBoss.boxp(Vector3(0.14, 0.02, 0.1), Vector3(0, 0.13, -0.17), Color(0.1, 0.1, 0.1))], 0.0)
	# the gauges he has grown into: a panel at his hips with two lit dials (his torso is the weak point in Overspeed)
	var dial: StandardMaterial3D = StandardMaterial3D.new()
	dial.albedo_color = Color(0.1, 0.12, 0.1)
	dial.emission_enabled = true
	dial.emission = Color(0.6, 1.0, 0.7)
	dial.emission_energy_multiplier = 0.5
	_gauge_mats.append(dial)
	var hips: Node3D = bone_attachment("Hips")
	if hips != null:
		var panel: MeshInstance3D = MeshInstance3D.new()
		var pb: BoxMesh = BoxMesh.new()
		pb.size = Vector3(0.46, 0.3, 0.1)
		pb.material = HomageBoss.mat_ex(Color(0.3, 0.32, 0.3), 0.55, 0.7)
		panel.mesh = pb
		panel.position = Vector3(0, -0.05, -0.16)
		hips.add_child(panel)
		for x: float in [-0.12, 0.12]:
			var cm: CylinderMesh = CylinderMesh.new()
			cm.top_radius = 0.05
			cm.bottom_radius = 0.05
			cm.height = 0.02
			cm.radial_segments = 14
			cm.material = dial
			var g: MeshInstance3D = MeshInstance3D.new()
			g.mesh = cm
			g.position = Vector3(x, -0.03, -0.22)
			g.rotation.x = PI * 0.5
			hips.add_child(g)
	_whip = cable("Spine", [Vector3(0.1, 0.3, 0.0), Vector3(0.5, 0.45, -0.9), Vector3(1.3, 0.55, -2.2), Vector3(2.3, 0.35, -3.6), Vector3(3.1, 0.1, -4.8)], 0.028, Color(0.5, 0.25, 0.8), 2.0, VIOLET)
	if _whip != null:
		_whip.visible = false


## The station he is half inside: the cabinet (gauges lit, two vents breathing steam), the boom over his head, the
## violet trunk cable from the boom to the core; the core's own white light (dark until Overspeed).
func _build_tether() -> void:
	if _cable != null:
		return
	_cable = Node3D.new()
	_cable.name = "Station"
	_cable.top_level = true
	add_child(_cable)
	_cable.global_position = station
	_cable.rotation = Vector3.ZERO
	var to_core: Vector3 = core_point - station
	var side: Vector3 = Vector3(to_core.x, 0, to_core.z).normalized()   # toward the core (the room is the other way)
	var cab_c: Vector3 = side * 1.3
	var cab: Node3D = Props.group(_cable, "Cabinet", cab_c, rad_to_deg(atan2(-side.x, -side.z)))
	Props.block(cab, Vector3(-0.9, 0.0, -0.45), Vector3(0.9, 1.35, 0.45), "machine_grey")
	Props.block(cab, Vector3(-0.95, 1.35, -0.5), Vector3(0.95, 1.45, 0.5), "steel")
	Props.block(cab, Vector3(-0.3, 1.45, -0.3), Vector3(0.3, 2.6, 0.3), "machine_grey")   # the boom's post
	Props.block(cab, Vector3(-0.35, 2.6, -0.35), Vector3(0.35, 2.75, 1.9), "steel")        # the boom over his head
	for e: Array in [[Vector3(-0.6, 0.2, 0.46), Vector3(0.5, 0.35, 0.02)], [Vector3(0.7, 1.0, 0.46), Vector3(0.3, 0.6, 0.02)]]:
		var r: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = e[1]
		bm.material = HomageBoss.mat_ex(Color(0.42, 0.2, 0.1), 0.95, 0.1)
		r.mesh = bm
		r.position = e[0]
		cab.add_child(r)
	for i: int in 4:
		var dial: StandardMaterial3D = StandardMaterial3D.new()
		dial.albedo_color = Color(0.1, 0.12, 0.1)
		dial.emission_enabled = true
		dial.emission = Color(1.0, 0.75, 0.35) if i % 2 == 0 else Color(0.6, 1.0, 0.7)
		dial.emission_energy_multiplier = 0.45   # the render showed them as headlights at 1.2: dim dials, not lamps
		_gauge_mats.append(dial)
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.08
		cm.bottom_radius = 0.08
		cm.height = 0.03
		cm.radial_segments = 14
		cm.material = dial
		var g: MeshInstance3D = MeshInstance3D.new()
		g.mesh = cm
		g.position = Vector3(-0.55 + 0.37 * float(i), 0.95, 0.47)
		g.rotation.x = PI * 0.5
		cab.add_child(g)
	for x: float in [-0.55, 0.55]:
		Props.cyl(cab, Vector3(x, 1.6, 0.0), 0.08, 0.3, "steel")
		var st: GPUParticles3D = BossFx.emitter("steam", cab, Vector3(x, 1.78, 0.0), 0.6)
		st.emitting = true
		_vent_steam.append(st)
	var boom_tip: Vector3 = cab_c - side * 1.6 + Vector3(0, 2.7, 0)
	Props.cable(_cable, boom_tip, Vector3(0, 1.75, 0), 0.08, 0.04, 4, "nachtglas_dim")
	Props.cable(_cable, boom_tip + Vector3(0, -0.1, 0.12), Vector3(0.1, 1.7, 0.1), 0.1, 0.025, 4, "nachtglas_dim")
	Props.cable(_cable, cab_c + Vector3(0, 2.7, 0), to_core + Vector3(0, 1.4, 0), 0.3, 0.05, 6, "nachtglas")
	var glow: OmniLight3D = OmniLight3D.new()
	glow.light_color = VIOLET
	glow.light_energy = 1.4
	glow.omni_range = 8.0
	glow.position = Vector3(0, 1.8, 0)
	_cable.add_child(glow)
	_core_light = OmniLight3D.new()
	_core_light.light_color = CORE_WHITE
	_core_light.light_energy = 0.0
	_core_light.omni_range = 16.0
	_core_light.omni_attenuation = 1.2
	_core_light.shadow_enabled = false
	_core_light.position = to_core + Vector3(0, 0.6, 0)
	_cable.add_child(_core_light)
	var imp: Node3D = Node3D.new()
	imp.position = to_core
	_cable.add_child(imp)
	_impeller = AudioDirector.make_loop_3d("bordwart_impeller_loop", imp, float(rcfg().get("impeller_db", -8.0)))


func _flight() -> Node:
	return get_tree().get_first_node_in_group(&"flight_controller")


func _process(_delta: float) -> void:
	if not is_active():
		return
	var k: float = 0.5 + 0.5 * sin(_clock * 2.3)
	var boost: float = 1.0 + (0.6 if wstate == W.PULL else 0.0) + (0.8 if overspeed_on else 0.0)
	for m: StandardMaterial3D in _gauge_mats:
		m.emission_energy_multiplier = (0.35 + 0.25 * k) * boost
	if _core_light != null and overspeed_on and (_flash_tw == null or not _flash_tw.is_valid()):
		_core_light.light_energy = float(wcfg.get("overspeed", {}).get("core_energy", 3.0)) * (0.9 + 0.1 * sin(_clock * 9.0))


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
	if _impeller != null:
		var want_pitch: float = 1.0 + (0.15 if wstate == W.PULL else 0.0) + ((float(rcfg().get("overspeed_pitch", 1.35)) - 1.0) if overspeed_on else 0.0)
		_impeller.pitch_scale = move_toward(_impeller.pitch_scale, want_pitch, delta * 0.4)
	match wstate:
		W.IDLE:
			if _wt > 0.0:
				return
			if phase >= 2 and cd_ready("cable") and target != null and dist_to(target) <= float(wcfg.get("cable", {}).get("reach", 5.0)) + 1.0:
				wstate = W.CABLE_TELEGRAPH
				_wt = float(wcfg.get("cable", {}).get("telegraph", 1.1))
				bstate = B.TELEGRAPH
				AudioDirector.play_3d("bordwart_cable_sing", global_position + Vector3.UP * 1.6, 2.0, 0.03)
				fx.tele(VIOLET, 4.5, _wt)
				if _whip != null:
					_whip.visible = true
					_whip.scale = Vector3(1.0, 0.3, 1.0)   # taut and low: the tell
				say("BWT_PHASE_02" if lashes_done == 0 else "BWT_BARK_02")
			elif cd_ready("pull"):
				wstate = W.PULL
				_wt = float(wcfg.get("pull", {}).get("seconds", 5.0))
				bstate = B.ACTIVE
				pulls_done += 1
				fx.tele(Color(0.8, 0.7, 1.0), 2.0, 0.8)
				for st: GPUParticles3D in _vent_steam:
					st.amount_ratio = 1.0
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
						var mps: float = pull_mps(float(pc.get("mps", 2.5)), p.health_fraction(), float(pc.get("hurt_below", 0.5)), float(pc.get("hurt_mult", 1.4)))
						if mps > float(pc.get("mps", 2.5)):
							hurt_pulls += 1
						p.external_push(d.normalized() * mps * squad_speed_mult, 0.15, &"pull")
						if p.is_local and not p.is_bot:
							fx.extra_dread = maxf(fx.extra_dread, 0.25)
			if _wt <= 0.0:
				wstate = W.VENT_TELEGRAPH
				_wt = float(wcfg.get("vent", {}).get("telegraph", 0.9))
				bstate = B.TELEGRAPH
				sfx("chain", -2.0, 0.6)
				fx.tele(CORE_WHITE, 5.0, _wt)
				_core_flash(float(wcfg.get("overspeed", {}).get("vent_flash", 9.0)) * 0.4, _wt)
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
				if _whip != null:
					_whip.visible = true
					_whip.scale = Vector3.ONE
				_wt = float(wcfg.get("cable", {}).get("active", 0.5))
				bstate = B.ACTIVE
				_lash()
		W.CABLE:
			if _wt <= 0.0:
				cable_out = false
				if _whip != null:
					_whip.visible = false
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


## The core flares to `energy` and settles back over `seconds` (a vent, a bank).
func _core_flash(energy: float, seconds: float) -> void:
	if _core_light == null:
		return
	vent_flashes += 1
	if _flash_tw != null and _flash_tw.is_valid():
		_flash_tw.kill()
	var rest: float = float(wcfg.get("overspeed", {}).get("core_energy", 3.0)) if overspeed_on else 0.0
	_flash_tw = create_tween()
	_flash_tw.tween_property(_core_light, "light_energy", energy, maxf(0.05, seconds * 0.3)).set_trans(Tween.TRANS_QUAD)
	_flash_tw.tween_property(_core_light, "light_energy", rest, maxf(0.1, seconds * 0.7))


## The vent: the core bursts: everyone within radius takes damage, zombies stagger; the pull's cooldown starts.
func _vent() -> void:
	var vc: Dictionary = wcfg.get("vent", {})
	vents_done += 1
	moves_used["vent"] = int(moves_used.get("vent", 0)) + 1
	AudioDirector.play_3d("boss_stomp", core_point, 6.0, 0.1)
	AudioDirector.play_3d("boss_roar_low", core_point + Vector3.UP, 0.0, 0.1)
	BossFx.burst("steam", core_point + Vector3.UP * 0.5, get_tree(), 3.0, 2.2)
	BossFx.burst("motes", core_point + Vector3.UP * 0.8, get_tree(), 2.0, 1.6)
	BossFx.burst("sparks", core_point + Vector3.UP * 1.0, get_tree(), 1.0, 1.2)
	_core_flash(float(wcfg.get("overspeed", {}).get("vent_flash", 9.0)), 1.2)
	for st: GPUParticles3D in _vent_steam:
		st.amount_ratio = 0.35
	for p: Player in alive_players():
		if p.global_position.distance_to(core_point) <= float(vc.get("radius", 4.0)) and has_los(p):
			hit_player(p, float(vc.get("damage", 120)))
	fx.shake_all(core_point, 0.5, 16.0)
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
	AudioDirector.play_3d("bordwart_cable_sing", global_position + Vector3.UP * 1.4, 4.0, 0.06)
	var fwd: Vector3 = -global_basis.z
	BossFx.burst("sparks", global_position + fwd * 2.5 + Vector3.UP * 0.4, get_tree(), 1.2, 1.2)
	for p: Player in alive_players():
		if in_arc(global_position, fwd, p.global_position, float(cc.get("reach", 5.0))):
			hit_player(p, float(cc.get("damage", 90)))
			AudioDirector.play_3d("boss_hit_iron", p.global_position + Vector3.UP, 2.0)
			var away: Vector3 = p.global_position - global_position
			away.y = 0.0
			p.external_push(away.normalized() * 6.0 + Vector3(0, 2.0, 0), 0.35, &"push")


## Phase 3: the lights go, the deck banks on a clock, the Bordschützen come through the shaft.
## T-234: the darkness is the kit's (every light within dark_radius gutters out), the core's white comes up, each
## bank flares it and flickers what is left.
func _overspeed_tick(delta: float) -> void:
	var oc: Dictionary = wcfg.get("overspeed", {})
	if not _lights_cut:
		_lights_cut = true
		overspeed_on = true
		say("BWT_PHASE_03")
		fx.lights_dim(station, float(oc.get("dark_radius", 28.0)), float(oc.get("dark_level", 0.0)), 3.2)
		fx.lights_flicker(2.2, 0.9)
		for l: Node in get_tree().get_nodes_in_group(&"power_lights"):
			if String(l.get_meta("zone", "")) == "D_TRIEBWERK":
				var tw: Tween = create_tween()
				tw.tween_property(l, "light_energy", 0.0, 3.0)
		_core_flash(float(oc.get("vent_flash", 9.0)), 2.5)
		AudioDirector.play_3d("boss_roar_low", core_point + Vector3.UP, 2.0, 0.05)
		for st: GPUParticles3D in _vent_steam:
			st.amount_ratio = 1.0
	_bank_t -= delta
	if _bank_t <= 0.0:
		_bank_t = float(oc.get("bank_every", 15.0))
		var fc: Node = _flight()
		if fc != null:
			fc.call("bank_now")
		banks_called += 1
		_core_flash(float(oc.get("vent_flash", 9.0)), 1.6)
		fx.lights_flicker(1.2, 0.6)
		BossFx.burst("steam", core_point + Vector3.UP * 0.5, get_tree(), 1.5, 1.6)
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


## No Cousins' hum: his breath over the intercom between moves (he thinks the flight is a test).
func _update_audio(delta: float) -> void:
	_breath_t -= delta
	if _breath_t <= 0.0 and wstate in [W.IDLE, W.RECOVER]:
		_breath_t = float(rcfg().get("breath_every", 6.0)) * randf_range(0.8, 1.3)
		sfx("boss_breath", -10.0, 0.95)


func _stop_machine() -> void:
	if _impeller != null:
		var tw: Tween = create_tween()
		tw.tween_property(_impeller, "pitch_scale", 0.5, 2.5)
		tw.tween_callback(_impeller.stop)
	for st: GPUParticles3D in _vent_steam:
		st.emitting = false
	if _whip != null:
		_whip.visible = false
	if _core_light != null and (_flash_tw == null or not _flash_tw.is_valid()):
		var tw2: Tween = create_tween()
		tw2.tween_property(_core_light, "light_energy", 0.0, 2.0)
	overspeed_on = false


func _boss_die(limb: StringName, weapon_id: StringName, by_player: int, kind: StringName) -> void:
	super._boss_die(limb, weapon_id, by_player, kind)
	RoundManager.release_alive(1)
	cable_out = false
	_stop_machine()
	BossFx.burst("steam", core_point + Vector3.UP * 0.5, get_tree(), 2.5, 2.0)
	BossFx.burst("sparks", global_position + Vector3.UP * 1.2, get_tree(), 2.0, 1.4)
	for m: StandardMaterial3D in _gauge_mats:
		m.emission_energy_multiplier = 0.0
	say("BWT_DEATH_01")
	for d: Variant in wcfg.get("drops", []):
		PowerupManager.spawn(StringName(str(d)), station + Vector3(2.0, 0.3, 0))
	if str(wcfg.get("flag", "")) != "":
		GameState.set_flag(StringName(str(wcfg["flag"])))
	if str(wcfg.get("death_vo", "")) != "":
		GLVO.play(StringName(str(wcfg["death_vo"])))
	fx.lights_restore(3.0)
	for l: Node in get_tree().get_nodes_in_group(&"power_lights"):
		if String(l.get_meta("zone", "")) == "D_TRIEBWERK" and GameState.power_on:
			(l as OmniLight3D).light_energy = float(l.get_meta("energy", 1.0))


func _on_retreat() -> void:
	# the reserve_alive of the spawn and the take_extra_spawn count: a death pays the latter in HomageBoss._boss_die,
	# a retreat has no death, and the round could never end on it (T-109)
	RoundManager.release_alive(2)
	_stop_machine()


func _start_authored_death() -> void:
	_tree_play("Death", "death_knee", 1.0)
