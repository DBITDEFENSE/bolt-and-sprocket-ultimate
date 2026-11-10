class_name TestPilot
extends HomageBoss
## THE TEST PILOT, Map 4 Act III's boss (UPDATE 07, docs/MAP4_FERNFLUG.md §5.7): Maj. Calvin "Cal" Rourke, the
## range's chief test pilot and its first casualty, fused with his jump rig, visor down. Phases (bosses/map04.json
## "testpilot"): (1) THE PATTERN: he crouches (the rig's whine), LEAPS an arc at a player and lands with a
## shockwave (`leap.shock_radius` / `shock_damage`; zombies stagger), then is VULNERABLE on the ground for
## `vuln_seconds` (he walks at you); in the air and between landings he takes `air_mult` / `idle_mult` damage.
## (2) at `lake_at`: he takes the fight up to the lakebed (the next leap goes to the lake anchor; the Burrowers
## follow, flag `pilot_on_lake`), his leaps are `range_lake` m and he DRAGS a player he lands on (the grab
## helper) toward his next anchor for `drag.seconds`. (3) at `stall_at`: THE STALL: the rig misfires on the next
## landing, he crawls `stall.seconds` (x`stall.vuln_mult` damage), then gets up at x`stall.speed_mult` speed.
## The Lodestone's lift (any stagger) catches him MID-LEAP: he drops where he is, takes `catch_mult` x the slam
## damage of the round, flag `slammed_once` (the egg's step 13), and is vulnerable. Reward: Scrip per player, a
## Resupply, the `ignition_key` flag. `failsafe_seconds` after the spawn he retreats. Pure rules are static.
## T-234 (docs/BOSS_REWORK.md, docs/boss_rework/w4_fernflug.md): the jump rig's two nozzles breathe heat (embers)
## from the crouch to the landing, the visor is a glossy plate that catches light with a faint amber lamp behind it,
## the rig's straps hang and sway, violet cracks run where the program kept him; the rig is a loop
## (`pilot_rig_whine`) that climbs through the crouch and the arc, a landing stomps (`dread.land_sound`,
## `land_shake` through fx.stomp) and cracks the floor (a dark decal), the Stall misfires (`pilot_rig_misfire`,
## sparks and smoke from the nozzles). The new beat: the Stall is the one window and it is dark: the lights within
## `stall.dark_radius` die to `stall.dark_level` while he crawls (his rig the only light) and, on the lakebed,
## `stall.burrowers` (+`burrowers_per_extra` per extra player) come up round the squad. The squad rule: with
## `leap.prefer_unwatching` he leaps at the nearest player whose camera does not face him when there is one (the
## whine is the tell from behind; nobody is hit without it).

enum P { IDLE, CROUCH, AIR, LAND, VULN, DRAG, STALL }

const VIOLET: Color = Color(0.62, 0.3, 1.0)
const RIG_AMBER: Color = Color(1.0, 0.7, 0.35)

var tcfg: Dictionary = {}
var pstate: P = P.IDLE
var phase: int = 1
var anchor_hall: Vector3 = Vector3.ZERO
var anchor_lake: Vector3 = Vector3.ZERO
var anchor_lake2: Vector3 = Vector3.ZERO
var _pt: float = 0.0
var _spawn_t: float = 0.0
var _a: Vector3 = Vector3.ZERO
var _b: Vector3 = Vector3.ZERO
var _air_total: float = 1.4
var _air_t: float = 0.0
var leaps_done: int = 0
var landings: int = 0
var catches: int = 0
var drags_done: int = 0
var stalled: bool = false
var stall_done: bool = false
var on_lake: bool = false
var _lake_pending: bool = false
var _grab: Dictionary = {}
var _drag_to: Vector3 = Vector3.ZERO
var _title_done: bool = false
var _stall_speed: float = 1.0
# T-234
var cracks_made: int = 0
var burrowers_raised: int = 0
var unwatching_picks: int = 0
var stall_dark: bool = false
var _nozzles: Array[GPUParticles3D] = []
var _smoke: GPUParticles3D = null
var _whine: AudioStreamPlayer3D = null
var _rig_light: OmniLight3D = null
var _breath_t: float = 3.0


static func table() -> Dictionary:
	return GLData.table("bosses/map04")


func boss_cfg() -> Dictionary:
	return (table().get("bosses", {}) as Dictionary).get("testpilot", {})


## Phase by HP fraction: 1 the pattern, 2 the lakebed, 3 the stall.
static func phase_of(hp_fraction: float, phases: Dictionary) -> int:
	if hp_fraction <= float(phases.get("stall_at", 0.3)):
		return 3
	if hp_fraction <= float(phases.get("lake_at", 0.6)):
		return 2
	return 1


## Damage taken by state: vulnerable x1 (x stall.vuln_mult while stalled), in the air x air_mult, else x idle_mult.
static func damage_mult(state: int, is_stalled: bool, leap: Dictionary, stall: Dictionary) -> float:
	if is_stalled:
		return float(stall.get("vuln_mult", 2.0))
	if state == P.VULN or state == P.LAND or state == P.DRAG:
		return 1.0
	if state == P.AIR:
		return float(leap.get("air_mult", 0.5))
	return float(leap.get("idle_mult", 0.25))


## The leap's end: `to`, clamped to `range_m` from `from` (flat).
static func leap_target(from: Vector3, to: Vector3, range_m: float) -> Vector3:
	var d: Vector3 = to - from
	d.y = 0.0
	if d.length() <= range_m:
		return to
	return from + d.normalized() * range_m + Vector3(0, to.y - from.y, 0)


## A point on the arc from `a` to `b` at k (0..1), `height` m over the straight line at its middle.
static func arc_point(a: Vector3, b: Vector3, k: float, height: float) -> Vector3:
	var kk: float = clampf(k, 0.0, 1.0)
	return a.lerp(b, kk) + Vector3(0, 4.0 * height * kk * (1.0 - kk), 0)


## T-234: true when a viewer at `from` looking along `fwd` has `to` in front (within acos(cos_min) of the view).
static func watching(fwd: Vector3, from: Vector3, to: Vector3, cos_min: float = 0.1) -> bool:
	var d: Vector3 = to - from
	d.y = 0.0
	var f: Vector3 = Vector3(fwd.x, 0, fwd.z)
	if d.length() < 0.01 or f.length() < 0.01:
		return true
	return d.normalized().dot(f.normalized()) >= cos_min


## T-234: how many Burrowers the Stall raises for `players`.
static func stall_burrowers(players: int, base: int, per_extra: int) -> int:
	return maxi(0, base + per_extra * maxi(0, players - 1))


func _ready() -> void:
	super._ready()
	boss_key = "testpilot"
	ecfg = table()
	tcfg = boss_cfg()
	bcfg = tcfg


func modelled() -> bool:
	return false


func person_id() -> String:
	return "testpilot"


func rcfg() -> Dictionary:
	return tcfg.get("rework", {})


func _anchor(n: String, fallback: Vector3) -> Vector3:
	var m: Node = _map()
	var a: Node3D = m.find_child(n, true, false) as Node3D if m != null else null
	return a.global_position if a != null else fallback


func _map() -> Node:
	var n: Node = get_parent()
	while n != null and not (n is MapRoot):
		n = n.get_parent()
	return n if n != null else get_parent()


func spawn_testpilot(_at: Vector3, health: float) -> void:
	anchor_hall = _anchor("PilotAnchor_Hall", _v3(tcfg.get("anchor_hall", [-40.0, -6.0, 130.0])))
	anchor_lake = _anchor("PilotAnchor_Lake", _v3(tcfg.get("anchor_lake", [0.0, 0.0, 30.0])))
	anchor_lake2 = _anchor("PilotAnchor_Lake2", _v3(tcfg.get("anchor_lake2", [-30.0, 0.0, 20.0])))
	spawn_homage(anchor_hall, health)
	enemy_id = &"testpilot"
	pstate = P.IDLE
	_pt = 2.0
	_spawn_t = 0.0
	phase = 1
	leaps_done = 0
	landings = 0
	catches = 0
	stalled = false
	stall_done = false
	stall_dark = false
	on_lake = false
	_lake_pending = false
	_stall_speed = 1.0
	_set_inst("inst_dirt", 0.5)   # salt dust
	_set_nozzles(false)
	RoundManager.reserve_alive(1)
	if not _title_done:
		_title_done = true
		var hud: BossHud = BossHud.new()
		_map().add_child(hud)
		hud.title_card(str(tcfg.get("title", "THE TEST PILOT")), str(tcfg.get("subtitle", "Maj. C. Rourke, USAAF (fictional)")), "9 MAY 1945  ·  GROOM LAKE")
		hud.add_bar("testpilot", self, str(tcfg.get("title", "THE TEST PILOT")), str(tcfg.get("subtitle", "")))
		if str(tcfg.get("spawn_vo", "")) != "":
			GLVO.play(StringName(str(tcfg["spawn_vo"])))
	say("RRK_BARK_01")


static func _v3(a: Variant) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2])) if a is Array and (a as Array).size() >= 3 else Vector3.ZERO


## His barks go straight to the VO manager (no encounter owns him).
func say(line_id: String) -> void:
	if line_id != "":
		GLVO.play(StringName(line_id))


# ================================================================== the model (T-234)

## The helmet with its glossy visor and the lamp behind it, the jump rig with two nozzles that breathe heat, the
## straps that hang from the harness, the cracks where the program kept him, sweat under the salt.
func _build_costume() -> void:
	costume("Head", [HomageBoss.sph(0.17, Vector3(0, 0.05, 0), Color(0.25, 0.22, 0.2))], 0.0)   # the helmet
	var head: Node3D = bone_attachment("Head")
	if head != null:
		var visor: MeshInstance3D = MeshInstance3D.new()
		var vb: BoxMesh = BoxMesh.new()
		vb.size = Vector3(0.23, 0.09, 0.09)
		vb.material = HomageBoss.mat_ex(Color(0.06, 0.05, 0.1), 0.06, 0.75)
		visor.mesh = vb
		visor.position = Vector3(0, 0.03, -0.125)
		head.add_child(visor)
		var rim: MeshInstance3D = MeshInstance3D.new()
		var rb: BoxMesh = BoxMesh.new()
		rb.size = Vector3(0.25, 0.015, 0.1)
		rb.material = HomageBoss.mat_ex(Color(0.5, 0.48, 0.45), 0.4, 0.8)
		rim.mesh = rb
		rim.position = Vector3(0, 0.08, -0.125)
		head.add_child(rim)
	eye_glow(RIG_AMBER, 0.55, 0.0, [Vector3(-0.045, 0.035, -0.165), Vector3(0.045, 0.035, -0.165)])
	# the rig: the pack, the two nozzles and their heat, a lamp on the pack
	costume("Spine", [HomageBoss.boxp(Vector3(0.4, 0.55, 0.24), Vector3(0, 0.1, 0.2), Color(0.35, 0.33, 0.3)),
		HomageBoss.boxp(Vector3(0.34, 0.08, 0.26), Vector3(0, 0.4, 0.2), Color(0.28, 0.27, 0.25)),
		HomageBoss.cyl(0.06, 0.08, 0.3, Vector3(-0.12, -0.25, 0.28), Color(0.3, 0.29, 0.28), Vector3.ZERO, Vector3.ONE, 10),
		HomageBoss.cyl(0.06, 0.08, 0.3, Vector3(0.12, -0.25, 0.28), Color(0.3, 0.29, 0.28), Vector3.ZERO, Vector3.ONE, 10)], 0.0)
	var spine: Node3D = bone_attachment("Spine")
	if spine != null:
		for x: float in [-0.12, 0.12]:
			var ring: MeshInstance3D = MeshInstance3D.new()
			var cm: CylinderMesh = CylinderMesh.new()
			cm.top_radius = 0.085
			cm.bottom_radius = 0.085
			cm.height = 0.03
			cm.radial_segments = 12
			cm.material = HomageBoss.mat_ex(Color(0.5, 0.25, 0.8), 0.3, 0.3, 1.6, VIOLET)
			ring.mesh = cm
			ring.position = Vector3(x, -0.41, 0.28)
			spine.add_child(ring)
			var e: GPUParticles3D = BossFx.emitter("embers", spine, Vector3(x, -0.44, 0.28), 0.7)
			(e.process_material as ParticleProcessMaterial).direction = Vector3(0, -1, 0)
			(e.process_material as ParticleProcessMaterial).gravity = Vector3(0, 2.5, 0)
			_nozzles.append(e)
		_smoke = BossFx.emitter("smoke", spine, Vector3(0, -0.3, 0.3), 0.7)
		_rig_light = OmniLight3D.new()
		_rig_light.light_color = RIG_AMBER
		_rig_light.light_energy = 0.0
		_rig_light.omni_range = 5.0
		_rig_light.shadow_enabled = false
		_rig_light.position = Vector3(0, -0.4, 0.4)
		spine.add_child(_rig_light)
		cable("Spine", [Vector3(-0.16, 0.3, 0.3), Vector3(-0.2, 0.42, 0.1), Vector3(-0.1, 0.5, -0.05)], 0.014, Color(0.2, 0.19, 0.17), 0.0)
		cable("Spine", [Vector3(0.16, 0.3, 0.3), Vector3(0.2, 0.42, 0.1), Vector3(0.1, 0.5, -0.05)], 0.014, Color(0.2, 0.19, 0.17), 0.0)
	strips("Chest", Vector3(0, -0.05, -0.17), 4, 0.26, 0.05, Color(0.33, 0.3, 0.2), 0.3, 5)
	cracks("LeftUpperArm", 5, 0.06, -0.3, 0.0, VIOLET, 1.4, 13)
	cracks("RightLowerArm", 4, 0.05, -0.28, -0.02, VIOLET, 1.4, 17)
	cracks("Neck", 3, 0.07, -0.02, 0.08, VIOLET, 1.2, 19)
	wet(0.3)
	_whine = AudioDirector.make_loop_3d("pilot_rig_whine", self, float(rcfg().get("whine_db", -6.0)))


func _set_nozzles(on: bool) -> void:
	for e: GPUParticles3D in _nozzles:
		e.emitting = on
	if _rig_light != null:
		_rig_light.light_energy = 2.2 if on else 0.0


## A dark cracked patch under a landing (a quad and a few radiating splits), gone after `crack_seconds`.
func _floor_crack(at: Vector3) -> void:
	var root: Node = _map()
	if root == null or not (root is Node3D):
		return
	cracks_made += 1
	var holder: Node3D = Node3D.new()
	holder.name = "PilotCrack"
	(root as Node3D).add_child(holder)
	holder.global_position = at + Vector3(0, 0.03, 0)
	holder.rotation.y = randf_range(0.0, TAU)
	var size: float = float(rcfg().get("crack_size", 2.6))
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.045, 0.04, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(size, size * 0.8)
	q.material = m
	var quad: MeshInstance3D = MeshInstance3D.new()
	quad.mesh = q
	quad.rotation.x = -PI * 0.5
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(quad)
	var dark: StandardMaterial3D = StandardMaterial3D.new()
	dark.albedo_color = Color(0.03, 0.03, 0.03, 0.9)
	dark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i: int in 6:
		var a: float = TAU * float(i) / 6.0 + randf_range(-0.3, 0.3)
		var len_: float = size * randf_range(0.3, 0.6)
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(0.035, 0.01, len_)
		bm.material = dark
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = bm
		mi.position = Vector3(sin(a) * len_ * 0.5, 0.005, cos(a) * len_ * 0.5)
		mi.rotation.y = a
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mi)
	var life: float = float(rcfg().get("crack_seconds", 40.0))
	var tw: Tween = holder.create_tween()
	tw.tween_interval(maxf(1.0, life - 5.0))
	tw.tween_property(m, "albedo_color:a", 0.0, 5.0)
	tw.parallel().tween_property(dark, "albedo_color:a", 0.0, 5.0)
	tw.tween_callback(holder.queue_free)


func _leap_cfg() -> Dictionary:
	return tcfg.get("leap", {})


func _range() -> float:
	return float(_leap_cfg().get("range_lake", 40.0)) if phase >= 2 else float(_leap_cfg().get("range", 22.0))


## A player's view direction (the camera's when it has one, else the body's).
static func _view_fwd(p: Player) -> Vector3:
	var cam: Variant = p.get("camera")
	if cam is Camera3D:
		return -(cam as Camera3D).global_basis.z
	return -p.global_basis.z


## T-234: who he leaps at: the nearest living player whose view does not hold him, else the nearest.
func _pick_leap_target() -> Player:
	if not bool(_leap_cfg().get("prefer_unwatching", false)):
		return target
	var best: Player = null
	var best_d: float = INF
	for p: Player in alive_players():
		if watching(_view_fwd(p), p.global_position, global_position):
			continue
		var d: float = dist_to(p)
		if d < best_d:
			best_d = d
			best = p
	if best != null and best != target:
		unwatching_picks += 1
	return best if best != null else target


func _tick(delta: float) -> void:
	_spawn_t += delta
	_pt -= delta
	if _spawn_t > float(ecfg.get("failsafe_seconds", 360.0)) and not retreating:
		retreat()
		return
	var new_phase: int = phase_of(hp_fraction(), tcfg.get("phases", {}))
	if new_phase > phase:
		phase = new_phase
		if phase == 2:
			_lake_pending = true
			say("RRK_PHASE_01")
		elif phase == 3:
			say("RRK_PHASE_02")
	if _whine != null and _whine.playing:
		var want: float = 1.3 if pstate == P.AIR else (0.8 + 0.4 * (1.0 - clampf(_pt / maxf(0.1, tele_len(float(_leap_cfg().get("telegraph", 1.1)))), 0.0, 1.0)) if pstate == P.CROUCH else 0.9)
		_whine.pitch_scale = move_toward(_whine.pitch_scale, want, delta * 1.5)
	match pstate:
		P.IDLE:
			stand(delta)
			if _pt <= 0.0 and cd_ready("leap") and target != null:
				_crouch()
		P.CROUCH:
			stand(delta)
			if _pt <= 0.0:
				_launch()
		P.AIR:
			_air_t += delta
			var k: float = clampf(_air_t / maxf(0.05, _air_total), 0.0, 1.0)
			global_position = arc_point(_a, _b, k, float(_leap_cfg().get("arc_height", 6.0)))
			var fwd: Vector3 = _b - _a
			if fwd.length() > 0.1:
				_face(global_position + Vector3(fwd.x, 0, fwd.z))
			if k >= 1.0:
				_land()
		P.LAND:
			stand(delta)
			if _pt <= 0.0:
				_after_land()
		P.VULN:
			if target != null:
				walk_to(target.global_position, delta, float(_leap_cfg().get("ground_speed", 2.6)) * _stall_speed * squad_speed_mult)
			if _pt <= 0.0:
				pstate = P.IDLE
				bstate = B.MOVE
				_pt = 0.3
		P.DRAG:
			var p: Player = _grab.get("p", null) as Player
			if p == null or not is_instance_valid(p) or not grabs().has(_grab) or _pt <= 0.0:
				_end_drag()
			else:
				drag_player(p, _drag_to, float((tcfg.get("drag", {}) as Dictionary).get("speed", 4.0)), delta, 1.2)
				walk_to(_drag_to, delta, float((tcfg.get("drag", {}) as Dictionary).get("speed", 4.0)))
		P.STALL:
			_halt(delta)
			if fmod(_pt, 0.9) < delta:
				var at: Vector3 = global_position + Vector3(0, 0.6, 0.3)
				BossFx.burst("sparks", at, get_tree(), 0.8, 0.9)
				AudioDirector.play_3d("pilot_rig_misfire", at, -4.0, 0.1)
			if _pt <= 0.0:
				_rise_from_stall()
		_:
			pass


func _crouch() -> void:
	pstate = P.CROUCH
	bstate = B.TELEGRAPH
	move_id = "leap"
	moves_used["leap"] = int(moves_used.get("leap", 0)) + 1
	_pt = tele_len(float(_leap_cfg().get("telegraph", 1.1)))
	var aim: Player = _pick_leap_target()
	if aim != null:
		target = aim
	if _whine != null:
		_whine.pitch_scale = 0.8
		_whine.play()
	_set_nozzles(true)
	fx.tele(RIG_AMBER, 4.0, _pt)
	if target != null:
		_face(target.global_position)
		if target.is_local and not target.is_bot:
			fx.extra_dread = maxf(fx.extra_dread, 0.3)


## The arc: at the lake anchor when the phase 2 move is pending, else at the target's lead.
func _launch() -> void:
	var dir: ZombieDirector = director as ZombieDirector
	var to: Vector3 = anchor_lake if _lake_pending else (target.global_position + Vector3(target.velocity.x, 0, target.velocity.z) * float(_leap_cfg().get("lead", 0.5)) if target != null else anchor_hall)
	if dir != null:
		to = dir._snap(to)
	_a = global_position
	_b = leap_target(_a, to, _range() if not _lake_pending else 400.0)
	_air_total = float(_leap_cfg().get("air_seconds", 1.4))
	_air_t = 0.0
	_pt = 0.0
	pstate = P.AIR
	bstate = B.ACTIVE
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	leaps_done += 1
	if _lake_pending:
		_lake_pending = false
		on_lake = true
		GameState.set_flag(&"pilot_on_lake")
	say("RRK_BARK_02" if leaps_done % 3 == 2 else "")
	BossFx.burst("dust", _a, get_tree(), 1.5, 1.4)
	BossFx.burst("embers", _a + Vector3.UP * 0.6, get_tree(), 1.5, 1.0)
	sfx("boss_roar_low", -8.0, 1.3)


func _land() -> void:
	global_position = _b
	collision_layer = LAYER_ZBODY
	collision_mask = LAYER_WORLD | LAYER_PLAYER | LAYER_DOOR
	velocity = Vector3.ZERO
	landings += 1
	var lc: Dictionary = _leap_cfg()
	var r: float = float(lc.get("shock_radius", 3.0))
	var dc: Dictionary = bcfg.get("dread", {})
	fx.stomp(global_position, float(dc.get("land_shake", 0.5)), str(dc.get("land_sound", "boss_stomp")), float(dc.get("land_radius", 22.0)))
	BossFx.burst("dust", global_position + Vector3.UP * 0.2, get_tree(), 2.5, 2.0)
	BossFx.burst("chips", global_position + Vector3.UP * 0.2, get_tree(), 1.0, 1.2)
	Effects.dust_puff(global_position, "earth", 24)
	_floor_crack(global_position)
	if _whine != null:
		_whine.stop()
	_set_nozzles(false)
	var grabbed: Player = null
	for p: Player in alive_players():
		var d: Vector3 = p.global_position - global_position
		if Vector2(d.x, d.z).length() <= r and absf(d.y) < 2.5:
			hit_player(p, float(lc.get("shock_damage", 100)))
			if phase >= 2 and grabbed == null and can_grab(p) and Vector2(d.x, d.z).length() <= float((tcfg.get("drag", {}) as Dictionary).get("reach", 2.5)):
				grabbed = p
	var dir: ZombieDirector = director as ZombieDirector
	if dir != null:
		for z: Zombie in dir.active_zombies():
			if z != self and z.is_active() and z.global_position.distance_to(global_position) <= r + 1.0:
				z.take_damage(float(lc.get("zombie_damage", 2500)), &"torso", &"testpilot", 0, &"explosive", true)
	set_cd("leap", cd_for(float(lc.get("cooldown", 3.0))))
	pstate = P.LAND
	bstate = B.RECOVER
	_pt = 0.5
	_hit_done = false
	if phase >= 3 and not stall_done:
		_begin_stall()
		return
	if grabbed != null:
		var dcfg: Dictionary = tcfg.get("drag", {})
		_grab = grab_start(grabbed, "drag", {"mash": int(dcfg.get("mash", 5)), "team": float(dcfg.get("team", 300.0)), "max": float(dcfg.get("seconds", 3.0))}, [&"torso", &"head"])
		hit_player(grabbed, float(dcfg.get("damage", 60)))
		_drag_to = anchor_lake2 if global_position.distance_to(anchor_lake2) > global_position.distance_to(anchor_lake) else anchor_lake
		drags_done += 1
		pstate = P.DRAG
		_pt = float(dcfg.get("seconds", 3.0))
		bstate = B.ACTIVE
		say("RRK_BARK_03")


## T-234: the Stall: the rig misfires, the lights near him die, the Burrowers come up on the lakebed.
func _begin_stall() -> void:
	var sc: Dictionary = tcfg.get("stall", {})
	stall_done = true
	stalled = true
	set_posture("hunch", 1.0)
	pstate = P.STALL
	_pt = float(sc.get("seconds", 6.0))
	say("RRK_PHASE_02")
	AudioDirector.play_3d("pilot_rig_misfire", global_position + Vector3.UP, 4.0, 0.05)
	BossFx.burst("sparks", global_position + Vector3(0, 0.7, 0.3), get_tree(), 2.0, 1.4)
	if _smoke != null:
		_smoke.emitting = true
	_set_nozzles(true)
	stall_dark = true
	fx.lights_dim(global_position, float(sc.get("dark_radius", 40.0)), float(sc.get("dark_level", 0.12)), 1.6)
	fx.lights_flicker(1.4, 0.85)
	fx.extra_dread = 0.4
	if on_lake:
		_raise_burrowers(stall_burrowers(RoundManager.players, int(sc.get("burrowers", 3)), int(sc.get("burrowers_per_extra", 1))))


func _rise_from_stall() -> void:
	stalled = false
	set_posture("none", 0.0)
	_stall_speed = float((tcfg.get("stall", {}) as Dictionary).get("speed_mult", 1.3))
	say("RRK_PHASE_03")
	if _smoke != null:
		_smoke.emitting = false
	_set_nozzles(false)
	if stall_dark:
		stall_dark = false
		fx.lights_restore(4.0)
	pstate = P.VULN
	_pt = 1.5


## The lakebed's dead come up round the squad while he crawls: Gängers in the Burrowers' kit, tagged for the
## GroomController when it is there, a burst of salt at each rise.
func _raise_burrowers(n: int) -> void:
	var dir: ZombieDirector = director as ZombieDirector
	if dir == null or n <= 0:
		return
	var groom: Node = get_tree().get_first_node_in_group(&"groom_controller")
	var players: Array[Player] = alive_players()
	if players.is_empty():
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = landings * 131 + leaps_done
	for i: int in n:
		var pp: Vector3 = players[i % players.size()].global_position
		var a: float = rng.randf_range(0.0, TAU)
		var at: Vector3 = dir._snap(pp + Vector3(cos(a), 0, sin(a)) * rng.randf_range(6.0, 11.0))
		var spec: Dictionary = dir._spec_for(&"ganger", RoundManager.take_extra_spawn())
		spec["variant"] = "technician"
		var z: Zombie = dir._activate_at(spec, at)
		if z == null:
			RoundManager.alive = maxi(0, RoundManager.alive - 1)
			continue
		burrowers_raised += 1
		if groom != null and groom.has_method("_tag"):
			groom.call("_tag", z, "burrower")
		Effects.dirt_burst(at, "earth", 1.2, Vector3.UP, 20)
		BossFx.burst("dust", at + Vector3.UP * 0.3, get_tree(), 1.2, 1.2)


func _after_land() -> void:
	pstate = P.VULN
	bstate = B.MOVE
	_pt = float(_leap_cfg().get("vuln_seconds", 4.0))


func _end_drag() -> void:
	if not _grab.is_empty() and grabs().has(_grab):
		grab_release(_grab, "done")
	_grab = {}
	_after_land()


## The Lodestone's lift (any stagger) in the air: he is caught, dropped where he is, slammed.
func force_stagger() -> void:
	if pstate == P.AIR:
		_catch()
		return
	super.force_stagger()


func _catch() -> void:
	catches += 1
	var dir: ZombieDirector = director as ZombieDirector
	var at: Vector3 = global_position
	at.y = _a.y if absf(_a.y - _b.y) < 0.5 else _b.y
	if dir != null:
		at = dir._snap(Vector3(global_position.x, at.y, global_position.z))
	global_position = at
	collision_layer = LAYER_ZBODY
	collision_mask = LAYER_WORLD | LAYER_PLAYER | LAYER_DOOR
	velocity = Vector3.ZERO
	var g: Dictionary = (GLData.load_json("res://data/gravelight/weapons.json")["weapons"]["lodestone"] as Dictionary).get("gravity", {})
	var dmg: float = Lodestone.slam_damage(Lodestone.round_health(), g) * float(tcfg.get("catch_mult", 3.0))
	GameState.set_flag(&"slammed_once")
	pstate = P.VULN
	bstate = B.STAGGER
	_pt = float(_leap_cfg().get("vuln_seconds", 4.0)) + 1.0
	var dc: Dictionary = bcfg.get("dread", {})
	fx.stomp(global_position, float(dc.get("land_shake", 0.5)) * 1.2, str(dc.get("land_sound", "boss_stomp")), float(dc.get("land_radius", 22.0)))
	AudioDirector.play_3d("pilot_rig_misfire", global_position + Vector3.UP, 2.0, 0.1)
	BossFx.burst("dust", global_position + Vector3.UP * 0.2, get_tree(), 3.0, 2.2)
	BossFx.burst("sparks", global_position + Vector3.UP * 0.8, get_tree(), 1.5, 1.2)
	Effects.dust_puff(global_position, "earth", 30)
	_floor_crack(global_position)
	if _whine != null:
		_whine.stop()
	_set_nozzles(false)
	say("RRK_PHASE_02")
	super.take_damage(dmg, &"torso", &"lodestone", 0, &"explosive", true)


func take_damage(amount: float, limb: StringName, weapon_id: StringName, by_player: int, kind: StringName = &"bullet", armor_piercing: bool = false) -> bool:
	var m: float = damage_mult(pstate, stalled, _leap_cfg(), tcfg.get("stall", {})) if kind != &"world" else 1.0   # the console and the clean-ups never scale
	return super.take_damage(amount * m, limb, weapon_id, by_player, kind, armor_piercing)


func _tele_glow() -> float:
	return 4.0 if pstate == P.CROUCH else (2.0 if pstate == P.AIR else 0.0)


## No Cousins' hum: his breath through the dead radio between leaps.
func _update_audio(delta: float) -> void:
	_breath_t -= delta
	if _breath_t <= 0.0 and pstate in [P.IDLE, P.VULN, P.STALL]:
		_breath_t = float(rcfg().get("breath_every", 5.0)) * randf_range(0.7, 1.3)
		sfx("boss_breath", -10.0, 1.05)


func _stop_rig() -> void:
	if _whine != null:
		_whine.stop()
	_set_nozzles(false)
	if _smoke != null:
		_smoke.emitting = false
	if stall_dark:
		stall_dark = false
		fx.lights_restore(3.0)


func _boss_die(limb: StringName, weapon_id: StringName, by_player: int, kind: StringName) -> void:
	collision_layer = LAYER_ZBODY
	collision_mask = LAYER_WORLD | LAYER_PLAYER | LAYER_DOOR
	_release_all_grabs("death")
	super._boss_die(limb, weapon_id, by_player, kind)
	RoundManager.release_alive(1)
	_stop_rig()
	AudioDirector.play_3d("pilot_rig_misfire", global_position + Vector3.UP, 0.0, 0.1)
	BossFx.burst("smoke", global_position + Vector3.UP * 0.8, get_tree(), 2.0, 1.6)
	say("RRK_DEATH_01")
	for d: Variant in tcfg.get("drops", []):
		PowerupManager.spawn(StringName(str(d)), global_position + Vector3(1.5, 0.3, 0))
	if str(tcfg.get("flag", "")) != "":
		GameState.set_flag(StringName(str(tcfg["flag"])))
	if str(tcfg.get("death_vo", "")) != "":
		GLVO.play(StringName(str(tcfg["death_vo"])))


func _on_retreat() -> void:
	collision_layer = LAYER_ZBODY
	collision_mask = LAYER_WORLD | LAYER_PLAYER | LAYER_DOOR
	# the reserve_alive of the spawn and the take_extra_spawn count: a retreat has no death (T-109)
	RoundManager.release_alive(2)
	_stop_rig()


func _start_authored_death() -> void:
	_tree_play("Death", "death_knee", 1.0)
