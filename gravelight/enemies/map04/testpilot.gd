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

enum P { IDLE, CROUCH, AIR, LAND, VULN, DRAG, STALL }

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
	on_lake = false
	_lake_pending = false
	_stall_speed = 1.0
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


func _build_costume() -> void:
	costume("Head", [HomageBoss.sph(0.17, Vector3(0, 0.05, 0), Color(0.25, 0.22, 0.2)),
		HomageBoss.boxp(Vector3(0.22, 0.08, 0.1), Vector3(0, 0.03, -0.12), Color(0.1, 0.08, 0.14))], 0.6)   # the helmet, the visor down
	costume("Spine", [HomageBoss.boxp(Vector3(0.4, 0.55, 0.24), Vector3(0, 0.1, 0.2), Color(0.35, 0.33, 0.3)),
		HomageBoss.cyl(0.06, 0.08, 0.3, Vector3(-0.12, -0.25, 0.28), Color(0.5, 0.25, 0.8), Vector3.ZERO, Vector3.ONE, 8),
		HomageBoss.cyl(0.06, 0.08, 0.3, Vector3(0.12, -0.25, 0.28), Color(0.5, 0.25, 0.8), Vector3.ZERO, Vector3.ONE, 8)], 1.6)   # the jump rig


func _leap_cfg() -> Dictionary:
	return tcfg.get("leap", {})


func _range() -> float:
	return float(_leap_cfg().get("range_lake", 40.0)) if phase >= 2 else float(_leap_cfg().get("range", 22.0))


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
			if _pt <= 0.0:
				stalled = false
				set_posture("none", 0.0)
				_stall_speed = float((tcfg.get("stall", {}) as Dictionary).get("speed_mult", 1.3))
				say("RRK_PHASE_03")
				pstate = P.VULN
				_pt = 1.5
		_:
			pass


func _crouch() -> void:
	pstate = P.CROUCH
	bstate = B.TELEGRAPH
	move_id = "leap"
	moves_used["leap"] = int(moves_used.get("leap", 0)) + 1
	_pt = tele_len(float(_leap_cfg().get("telegraph", 1.1)))
	sfx("hum", 2.0, 1.6)
	if target != null:
		_face(target.global_position)


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
	sfx("chain", -2.0, 1.4)


func _land() -> void:
	global_position = _b
	collision_layer = LAYER_ZBODY
	collision_mask = LAYER_WORLD | LAYER_PLAYER | LAYER_DOOR
	velocity = Vector3.ZERO
	landings += 1
	var lc: Dictionary = _leap_cfg()
	var r: float = float(lc.get("shock_radius", 3.0))
	AudioDirector.play_3d("grenade_explode", global_position, 2.0, 0.3)
	Effects.dust_puff(global_position, "earth", 24)
	var grabbed: Player = null
	for p: Player in alive_players():
		var d: Vector3 = p.global_position - global_position
		if p.global_position.distance_to(global_position) < 20.0:
			p.set("_shake", 0.5)
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
		stall_done = true
		stalled = true
		set_posture("hunch", 1.0)
		pstate = P.STALL
		_pt = float((tcfg.get("stall", {}) as Dictionary).get("seconds", 6.0))
		say("RRK_PHASE_02")
		return
	if grabbed != null:
		var dc: Dictionary = tcfg.get("drag", {})
		_grab = grab_start(grabbed, "drag", {"mash": int(dc.get("mash", 5)), "team": float(dc.get("team", 300.0)), "max": float(dc.get("seconds", 3.0))}, [&"torso", &"head"])
		hit_player(grabbed, float(dc.get("damage", 60)))
		_drag_to = anchor_lake2 if global_position.distance_to(anchor_lake2) > global_position.distance_to(anchor_lake) else anchor_lake
		drags_done += 1
		pstate = P.DRAG
		_pt = float(dc.get("seconds", 3.0))
		bstate = B.ACTIVE
		say("RRK_BARK_03")


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
	AudioDirector.play_3d("grenade_explode", global_position, 0.0, 0.3)
	Effects.dust_puff(global_position, "earth", 30)
	say("RRK_PHASE_02")
	super.take_damage(dmg, &"torso", &"lodestone", 0, &"explosive", true)


func take_damage(amount: float, limb: StringName, weapon_id: StringName, by_player: int, kind: StringName = &"bullet", armor_piercing: bool = false) -> bool:
	var m: float = damage_mult(pstate, stalled, _leap_cfg(), tcfg.get("stall", {})) if kind != &"world" else 1.0   # the console and the clean-ups never scale
	return super.take_damage(amount * m, limb, weapon_id, by_player, kind, armor_piercing)


func _tele_glow() -> float:
	return 4.0 if pstate == P.CROUCH else (2.0 if pstate == P.AIR else 0.0)


func _boss_die(limb: StringName, weapon_id: StringName, by_player: int, kind: StringName) -> void:
	collision_layer = LAYER_ZBODY
	collision_mask = LAYER_WORLD | LAYER_PLAYER | LAYER_DOOR
	_release_all_grabs("death")
	super._boss_die(limb, weapon_id, by_player, kind)
	RoundManager.release_alive(1)
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


func _start_authored_death() -> void:
	_tree_play("Death", "death_knee", 1.0)
