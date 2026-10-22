class_name BotBrain
extends Node
## An AI teammate's brain (T-031): a child of a bot Player (`is_bot`), which it moves, aims and fires like a
## person would, with the tuning in data/gravelight/bots.json and the pure rules in BotConfig.
##
## Loop: perception runs at `think_hz` (staggered between bots), movement and aiming every physics frame.
##   FOLLOW   stay loosely in a formation slot behind the leader (the human; the first standing bot when the
##            human is spectating), out of their line of fire, never parked in a doorway. Sprints to catch up;
##            teleports to the leader when it has been cut off for a while.
##   FIGHT    a visible target in range: turn at a human rate, aim settles from aim_error_deg to
##            settle_error_deg, fire when the perceived aim is within fire_tolerance_deg (bursts for autos),
##            reload, swap to a loaded gun up close, knife what reaches it. Never shoots through walls (every
##            target needs a line of sight from the eye), never through a teammate.
##   FLEE     surrounded, hurt or dry with something close: kites to open ground away from the crowd, still
##            shooting the nearest threat on the move.
##   REVIVE   a downed teammate (the human first): walk up, hold, bring them back; pauses to fight if zombies
##            close in while there is bleed-out time to spare.
##   ERRAND   between fights: rebuild boards near it, buy a better wall gun / ammo / a cheap perk with its own
##            Scrip, open a door (the one the human looks at or stands nearest, keeping a reserve, at most one a
##            round, after a delay into the round; switchable off), feed the Crucible when the map has one; all
##            within shopping range of the leader. It never flips the power.
##   DOWNED   last stand: lies where it fell and keeps the pistol working until revived or bled out.
## One bot may carry a BotPlanner (bots.json local_ai): its directive (an easter egg step, the power, a door, a
## purchase, or "follow") becomes this bot's errand when no fight needs it; the objective kinds run in
## _tick_objective (walk, use, enter a code, shoot a bell, chase the drummer, hold a spot, pull the crate).
## Every bot gets the spawn kit (BotSquad.apply_kit) at the start and again when it gets up.
## Weapons are the bot Player's mirrored WeaponHolder (inventory only); shots are traced here with the same
## damage rules as WeaponHolder._trace, and shown through the RemoteBody (flash, sound, tracer).

enum Mode { FOLLOW, FIGHT, FLEE, REVIVE, ERRAND, DOWNED, OUT }

const MASK_SHOT: int = 1 | (1 << 3) | (1 << 8)   # world | zombie hitbox | door (WeaponHolder.MASK_SHOT)
const MASK_LOS: int = 1 | (1 << 8)               # world | door
const SHOT_RANGE: float = 220.0
const SWAP_TIME: float = 0.42
const GRAVITY: float = 14.0
const BURST_RPM_CAP: float = 900.0
## Errand kinds that come from the shopping rules (claimed so two bots don't queue at one machine).
## Errand kinds only the objective planner hands out (executed by _tick_objective).
const OBJECTIVE_KINDS: PackedStringArray = ["use", "radio", "switchboard", "shoot", "shoot_seq", "shoot_moving", "hold", "crate"]
const SHOP_KINDS: PackedStringArray = ["repair", "gun", "ammo", "perk", "door", "crucible", "crucible_ammo"]

var player: Player
var squad: BotSquad
var index: int = 0
var mode: Mode = Mode.FOLLOW
var target: Zombie = null
var kills: int = 0
var shots: int = 0
var teleports: int = 0

var _cfg: Dictionary = {}
var _sk: Dictionary = {}
var _follow: Dictionary = {}
var _combat: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _pcfg: Dictionary = {}
# perception
var _think_t: float = 0.0
var _zs: Array[Zombie] = []
var _near_z: Zombie = null
var _near_d: float = INF
var _crowd: int = 0
var _target_t: float = 0.0        # seconds since the target was picked (the aim settles with it)
var _react_t: float = 0.0         # reaction time left before the first shot at a new target
var _lost_t: float = 0.0          # seconds the target has been out of sight
var _aim_head: bool = false
var _aim_err: Vector2 = Vector2.ZERO   # perceived-aim error (yaw, pitch) in radians, re-rolled now and then
var _aim_err_t: float = 0.0
# aim
var _yaw: float = 0.0
var _pitch: float = 0.0
# weapon
var _fire_cd: float = 0.0
var _bloom: float = 0.0
var _reloading: bool = false
var _reload_per_round: bool = false
var _reload_t: float = 0.0
var _swap_t: float = 0.0
var _burst_t: float = 0.0         # auto fire: time left in the current burst...
var _pause_t: float = 0.0         # ...and in the pause after it
var _melee_cd: float = 0.0
# movement
var _goal: Vector3 = Vector3.INF
var _path: PackedVector3Array = PackedVector3Array()
var _path_i: int = 0
var _path_goal: Vector3 = Vector3.INF
var _repath_t: float = 0.0
var _sprint: bool = false
var _stuck_t: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO
var _away_t: float = 0.0
var _cone_t: float = 0.0
var _flee_t: float = 0.0
var _nav_ready: bool = false
var _doors: Array[BuyDoor] = []
# revive / errands
var _revive_pid: int = 0
var _revive_hold: float = 0.0
var _reviving: bool = false
var _errand: Dictionary = {}      # {node, kind, until, hold, fed}
var _errand_cd: float = 0.0
var _doors_bought: int = 0        # this round (shopping.doors.max_per_round_per_bot)
var doors_bought_total: int = 0
var upgrades: int = 0             # Crucible upgrades taken
# the objective planner (bots.json local_ai), on one bot only: its directive becomes this bot's errand
var planner: BotPlanner = null
var objectives_done: int = 0
var _was_down: bool = false
var _was_out: bool = false
var _stand_cache: Dictionary = {}  # node instance id -> [time, stand point]



func setup(bot_player: Player, bot_squad: BotSquad, i: int) -> void:
	player = bot_player
	squad = bot_squad
	index = i
	_cfg = BotConfig.cfg()
	_sk = BotConfig.skill(_cfg, GameState.bot_skill)
	_follow = _cfg.get("follow", {})
	_combat = _cfg.get("combat", {})
	_pcfg = GLData.table("player")
	_rng.randomize()
	_think_t = 0.05 * float(i)   # stagger the squad's thinking across frames
	player.bot_damage_mult = float(_sk.get("damage_taken_mult", 1.0))
	_yaw = player.rotation.y
	_last_pos = player.global_position


func skill_name() -> String:
	return GameState.bot_skill


func _ready() -> void:
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		if n is BuyDoor:
			_doors.append(n as BuyDoor)


## New round: the start pistol is topped up (bots have no ammo HUD; this keeps them useful without carrying).
func on_round_started() -> void:
	if bool(_combat.get("round_start_pistol_refill", true)) and player.weapons != null:
		for w: WeaponInstance in player.weapons.slots:
			if w.weapon_class() == &"pistol":
				w.refill()
	_errand = {}
	_errand_cd = 0.0
	_doors_bought = 0


# ================================================================== per-frame

func _physics_process(delta: float) -> void:
	if player == null or not player.is_inside_tree() or GameState.phase != GameState.Phase.PLAYING:
		return
	if not _nav_ready:
		_nav_ready = NavigationServer3D.map_get_iteration_id(player.get_world_3d().navigation_map) > 0
		if not _nav_ready:
			return
	_think_t -= delta
	if _think_t <= 0.0:
		_think_t = 1.0 / maxf(1.0, float((_cfg.get("perception", {}) as Dictionary).get("think_hz", 8.0)))
		_think()
	_fire_cd = maxf(-0.05, _fire_cd - delta)
	_swap_t = maxf(0.0, _swap_t - delta)
	_melee_cd = maxf(0.0, _melee_cd - delta)
	_bloom = move_toward(_bloom, 0.0, delta * 8.0)
	_target_t += delta
	_react_t -= delta
	_aim_err_t -= delta
	_repath_t -= delta
	_errand_cd -= delta
	_tick_reload(delta)
	if player.spectating:
		mode = Mode.OUT
		_was_out = true
		_cancel_reload()
		_drop_errand()
		_pose(delta)
		return

	if player.downed:
		mode = Mode.DOWNED
		_was_down = true
		_tick_downed(delta)
		_pose(delta)
		return
	if _was_down or _was_out:
		# back up (revived, or respawned after a bleed-out): the spawn kit's perks again, its guns after a respawn
		if bool((_cfg.get("spawn_kit", {}) as Dictionary).get("restore_after_down", true)):
			squad.apply_kit(player, _was_out)
		_was_down = false
		_was_out = false
	player._update_health(delta)   # regen (and status timers), the same as a local player's
	match mode:
		Mode.FIGHT:
			_tick_fight(delta)
		Mode.FLEE:
			_tick_flee(delta)
		Mode.REVIVE:
			_tick_revive(delta)
		Mode.ERRAND:
			_tick_errand(delta)
		_:
			_tick_follow(delta)
	_move(delta)
	_pose(delta)


# ================================================================== perception (throttled)

func _think() -> void:
	_zs = _live_zombies()
	var me: Vector3 = player.global_position
	_near_z = null
	_near_d = INF
	_crowd = 0
	var danger: float = float(_combat.get("danger_radius_m", 3.0))
	for z: Zombie in _zs:
		var d: float = _flat(z.global_position, me)
		if d < _near_d:
			_near_d = d
			_near_z = z
		if d < danger * 2.0:
			_crowd += 1
	if player.remote_body != null:
		var cw: WeaponInstance = player.weapons.current()
		player.remote_body.set_weapon(cw.id if cw != null else &"")
	if player.spectating or player.downed:
		_pick_target(float((_cfg.get("perception", {}) as Dictionary).get("engage_range_m", 26.0)) * 0.5)
		return
	_pick_target(float((_cfg.get("perception", {}) as Dictionary).get("engage_range_m", 26.0)))
	_weapon_logic()
	_decide_mode()


func _live_zombies() -> Array[Zombie]:
	var out: Array[Zombie] = []
	var dir: ZombieDirector = squad.director()
	if dir == null:
		return out
	for z: Zombie in dir.active_zombies():
		if _targetable(z):
			out.append(z)
	return out


static func _targetable(z: Zombie) -> bool:
	return z != null and is_instance_valid(z) and z.is_active() and z.state != Zombie.State.DEAD and z.state != Zombie.State.EMERGE \
		and z.state != Zombie.State.INACTIVE


## Keeps a visible target; otherwise scores the candidates and takes the first with a line of sight (a few rays).
func _pick_target(engage: float) -> void:
	var eye: Vector3 = _eye()
	if target != null:
		if not _targetable(target) or target.global_position.distance_to(player.global_position) > engage * 1.25:
			target = null
		elif _los(eye, _aim_point(target), target):
			_lost_t = 0.0
		else:
			_lost_t += _think_t_len()
			if _lost_t > 0.8:
				target = null
	if target != null:
		return
	var cands: Array = []
	var share_ok: bool = squad.kill_share_ok()
	var human: Player = squad.human()
	var ks: Dictionary = _combat.get("kill_share", {})
	var threat_r: float = float(ks.get("threat_radius_m", 4.0))
	for z: Zombie in _zs:
		var d: float = z.global_position.distance_to(player.global_position)
		if d > engage:
			continue
		var s: float = d
		var threat: bool = false
		for p: Player in squad.standing():
			if _flat(z.global_position, p.global_position) < threat_r:
				threat = true
				s -= 8.0 if p == player else 5.0
		if z.state == Zombie.State.ATTACK:
			s -= 4.0
		if (z.state == Zombie.State.TEAR or z.state == Zombie.State.WAIT_WINDOW or z.state == Zombie.State.CLIMB):
			s -= float(_combat.get("window_target_priority", 0.35)) * 10.0
		if not share_ok and not threat and human != null and human.is_alive() and not human.spectating:
			if BotConfig.in_fire_cone(human.head.global_position, -human.camera.global_basis.z, z.global_position, float(ks.get("human_cone_deg", 22.0)), 40.0):
				continue   # the human has it: leave them the kill
		cands.append([s, z])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var checks: int = int((_cfg.get("perception", {}) as Dictionary).get("los_checks_per_think", 3))
	for c: Array in cands.slice(0, checks):
		var z2: Zombie = c[1]
		if _los(eye, _aim_point(z2), z2):
			_acquire(z2)
			return


func _acquire(z: Zombie) -> void:
	target = z
	_target_t = 0.0
	_lost_t = 0.0
	_react_t = BotConfig.range_roll(_sk.get("reaction_s"), _rng, 0.4)
	_aim_head = _rng.randf() < float(_sk.get("head_aim_chance", 0.3))
	_aim_err_t = 0.0


func _think_t_len() -> float:
	return 1.0 / maxf(1.0, float((_cfg.get("perception", {}) as Dictionary).get("think_hz", 8.0)))


func _decide_mode() -> void:
	var w: WeaponInstance = player.weapons.current()
	var loaded: bool = w != null and w.mag > 0 and not _reloading
	var hurt: bool = player.hp < player.max_hp * float(_combat.get("flee_hp_frac", 0.4))
	var danger: float = float(_combat.get("danger_radius_m", 3.0))
	var swarmed: bool = _near_d < danger and (hurt or _crowd >= int(_combat.get("crowd_count", 3)))
	var rt: Player = squad.revive_target_for(self)
	if rt != null:
		# a swarmed or hurt reviver helps nobody: kite first, unless the clock is nearly out
		var urgent: bool = Net.session != null and Net.session.coop.bleed_left(rt.player_id) <= float((_cfg.get("revive", {}) as Dictionary).get("risk_bleed_s", 15.0))
		if not swarmed or urgent:
			if mode != Mode.REVIVE or _revive_pid != rt.player_id:
				_reviving = false
				_revive_hold = 0.0
			_revive_pid = rt.player_id
			mode = Mode.REVIVE
			return
	if _reviving:
		_stop_revive()
	_revive_pid = 0
	if _near_d < danger and (hurt or _crowd >= int(_combat.get("crowd_count", 3)) or not loaded):

		if mode != Mode.FLEE:
			_flee_t = 0.0
		mode = Mode.FLEE
		return
	if mode == Mode.FLEE and (_near_d < danger * 1.6 or _flee_t < 1.2):
		return   # keep kiting a moment past the last close one
	if target != null:
		if _crucible_sticky() or _objective_sticky():
			mode = Mode.ERRAND   # the gun is in the forge / holding an objective: stay and shoot from there
			return
		mode = Mode.FIGHT
		_drop_errand()
		return
	if planner != null and _planner_errand():
		mode = Mode.ERRAND
		return
	var quiet: bool = _zs.is_empty() or RoundManager.state != RoundManager.State.ROUND \
		or (_near_d > float((_cfg.get("repair", {}) as Dictionary).get("quiet_radius_m", 7.0)) and _zs.size() <= 3)
	if quiet:
		if _errand.is_empty() and _errand_cd <= 0.0:
			_errand_cd = 0.7
			_errand = _choose_errand()
		if not _errand.is_empty():
			mode = Mode.ERRAND
			return
	else:
		_drop_errand()
	mode = Mode.FOLLOW


func _drop_errand() -> void:
	if not _errand.is_empty() and is_instance_valid(_errand.get("node")):
		squad.release(_errand["node"] as Node, player.player_id)
	_errand = {}


## The errand is over (done, or given up when `ok` is false): the claim goes, the planner hears of it.
func _finish_errand(ok: bool) -> void:
	var id: String = str(_errand.get("id", ""))
	_drop_errand()
	_errand_cd = 1.0
	mode = Mode.FOLLOW
	if ok and id != "":
		objectives_done += 1
	if planner != null and id != "":
		planner.on_errand_finished(id, ok)


## The planner's directive as this bot's errand (built once per directive; rebuilt after a fight dropped it).
## False for "follow" (then this bot behaves like any other) or when the directive can't be started.
func _planner_errand() -> bool:
	var dv: Dictionary = planner.directive
	if dv.is_empty() or str(dv.get("kind", "")) == "follow":
		return false
	if not _errand.is_empty() and str(_errand.get("id", "")) == str(dv.get("id", "")):
		return true
	if _errand_cd > 0.0:
		return false
	_drop_errand()
	_errand = _errand_from_directive(dv)
	if _errand.is_empty():
		planner.on_errand_finished(str(dv.get("id", "")), false)
		return false
	return true


func _errand_from_directive(dv: Dictionary) -> Dictionary:
	var node: Variant = dv.get("node")
	if node == null or not is_instance_valid(node):
		return {}
	var kind: String = str(dv.get("kind", ""))
	var pid: int = player.player_id
	if SHOP_KINDS.has(kind):
		if not squad.can_claim(node as Node, pid):
			return {}
		squad.claim(node as Node, pid)
	var e: Dictionary = dv.duplicate()
	e["hold"] = 0.0
	e["t0"] = squad.time()
	var timeout: float = float((_cfg.get("local_ai", {}) as Dictionary).get("errand_timeout_s", 60.0))
	if kind == "crucible" and node is Crucible:
		timeout += (node as Crucible).forge_seconds + (node as Crucible).offer_seconds
	e["until"] = squad.time() + timeout + float(dv.get("extra_s", 0.0))
	return e


## Objective errands that keep the bot where it is through a fight: holding a spot (a pylon ring, the Chapel,
## the heart, the Heartstorm), chasing the drummer, waiting on a crate it paid for.
func _objective_sticky() -> bool:
	if _errand.is_empty() or not _errand.has("id"):
		return false
	var kind: String = str(_errand.get("kind", ""))
	if kind == "hold" or kind == "shoot_moving":
		return true
	return kind == "crate" and bool(_errand.get("paid", false))


## On an objective of its own (not "follow"): the planner bot then fights where it stands instead of following.
func roaming() -> bool:
	return planner != null and not planner.directive.is_empty() and str(planner.directive.get("kind", "")) != "follow"


# ================================================================== aiming and shooting

func _eye() -> Vector3:
	return player.head.global_position


func _facing() -> Vector3:
	return Vector3(-sin(_yaw) * cos(_pitch), sin(_pitch), -cos(_yaw) * cos(_pitch))


## Head when going for it (and the head hitbox is there), else the chest.
func _aim_point(z: Zombie) -> Vector3:
	if _aim_head:
		var hbs: Variant = z.get("_hitboxes")
		if hbs is Array:
			for hb: Variant in hbs:
				if hb is Hitbox and (hb as Hitbox).limb == &"head":
					return (hb as Hitbox).global_position
	return z.global_position + Vector3.UP * (0.5 if z.is_crawler else 1.15)


## Line of sight from the eye to a point on a zombie: nothing solid in between (walls, closed doors).
func _los(from: Vector3, to: Vector3, z: Zombie) -> bool:
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, MASK_LOS, [player.get_rid(), z.get_rid()])
	return space.intersect_ray(q).is_empty()


## Turns toward `p` at the skill's turn rate. Returns the remaining angle (radians) to it.
func _turn_toward(p: Vector3, delta: float, rate_mult: float = 1.0) -> float:
	var to: Vector3 = p - _eye()
	if to.length_squared() < 0.0001:
		return 0.0
	to = to.normalized()
	var want_yaw: float = atan2(-to.x, -to.z)
	var want_pitch: float = asin(clampf(to.y, -1.0, 1.0))
	var step: float = float(_sk.get("turn_rate", 6.0)) * rate_mult * delta
	var dy: float = wrapf(want_yaw - _yaw, -PI, PI)
	var dp: float = want_pitch - _pitch
	_yaw = wrapf(_yaw + clampf(dy, -step, step), -PI, PI)
	_pitch = clampf(_pitch + clampf(dp, -step, step), deg_to_rad(-80.0), deg_to_rad(80.0))
	return Vector2(wrapf(want_yaw - _yaw, -PI, PI), want_pitch - _pitch).length()


## Where the bot thinks the target is: the true aim point plus its current aim error.
func _perceived(z: Zombie) -> Vector3:
	var p: Vector3 = _aim_point(z)
	if _aim_err_t <= 0.0:
		_aim_err_t = _rng.randf_range(0.2, 0.4)
		var e: float = deg_to_rad(BotConfig.aim_error_deg(_sk, _target_t))
		if player.horizontal_speed() > 1.0:
			e *= 1.25
		if player.downed:
			e *= 1.6
		_aim_err = Vector2(_rng.randfn(0.0, e), _rng.randfn(0.0, e))
	var d: float = maxf(0.5, p.distance_to(_eye()))
	var right: Vector3 = Vector3(cos(_yaw), 0.0, -sin(_yaw))
	return p + right * tan(_aim_err.x) * d + Vector3.UP * tan(_aim_err.y) * d


func _teammate_in_the_way(to: Vector3) -> bool:
	var from: Vector3 = _eye()
	for p: Player in squad.all_players():
		if p == player or p.spectating:
			continue
		if BotConfig.blocks_shot(from, to, p.global_position + Vector3.UP * 1.0, 0.6):
			return true
	return false


## Aims at the target and pulls the trigger when the perceived aim is on it. `rate_mult` slows the turn (fleeing).
func _aim_and_fire(delta: float, rate_mult: float = 1.0) -> void:
	if target == null:
		return
	var aim: Vector3 = _perceived(target)
	var err: float = _turn_toward(aim, delta, rate_mult)
	var w: WeaponInstance = player.weapons.current()
	if w == null or _reloading or _swap_t > 0.0 or _react_t > 0.0:
		return
	if err > deg_to_rad(float(_sk.get("fire_tolerance_deg", 3.0))):
		return
	if w.mag <= 0:
		return
	if w.data.has("bell") and _eye().distance_to(aim) > float((w.data["bell"] as Dictionary).get("range", 8.0)) * 0.95:
		return   # the Totenglocke only rings at what its cone reaches
	if _teammate_in_the_way(aim):
		return
	var auto: bool = w.fire_mode == "auto"
	if auto:
		if _burst_t <= 0.0:
			if _pause_t > 0.0:
				_pause_t -= delta
				return
			_burst_t = BotConfig.range_roll(_sk.get("burst_s"), _rng, 0.4)
			_pause_t = BotConfig.range_roll(_sk.get("burst_pause_s"), _rng, 0.3)
		_burst_t -= delta
	if _fire_cd <= 0.0:
		_fire(w)


func _fire(w: WeaponInstance) -> void:
	w.mag -= 1
	shots += 1
	var rpm: float = maxf(1.0, w.f("rpm", 300.0) * float(PerkManager.stat(player.player_id, "fire_rate_mult", 1.0)))
	if w.fire_mode != "auto":
		rpm = minf(rpm, float(_sk.get("semi_max_rpm", 240.0)))
	_fire_cd = minf(_fire_cd, 0.0) + 60.0 / rpm
	var origin: Vector3 = _eye()
	var basis: Basis = Basis.from_euler(Vector3(_pitch, _yaw, 0.0))
	if w.data.has("bell"):
		# the Totenglocke: a quick toll down the bot's aim (T-048), not a bullet
		Totenglocke.bot_toll(player, w, origin, -basis.z)
		if w.mag <= 0 and w.reserve > 0:
			_start_reload()
		return
	var spread: float = (lerpf(w.f("spread_hip", 3.0), w.f("spread_ads", 0.5), 0.6) + _bloom) * float(_sk.get("spread_mult", 1.0))
	if player.horizontal_speed() > 1.0:
		spread *= float(_combat.get("moving_spread_mult", 1.7))
	var pellets: int = maxi(1, int(w.data.get("pellets", 1)))
	var hits: Dictionary = {}
	var last_hit: Vector3 = origin - basis.z * SHOT_RANGE
	for i: int in pellets:
		last_hit = _trace(origin, _spread_dir(basis, spread), w, hits)
	var pid: int = player.player_id
	var piercing: bool = bool(w.property("armor_piercing", false)) or bool(w.property("armor_ignore", false))
	for z: Variant in hits.keys():
		var zz: Zombie = z as Zombie
		var h: Dictionary = hits[z]
		var limb: StringName = StringName(h["limb"])
		zz.last_hit_bone = str(h.get("bone", ""))
		var killed: bool = zz.take_damage(float(h["dmg"]) * float(_combat.get("damage_mult", 1.0)), limb, w.id, pid, &"bullet", piercing)
		if killed and limb == &"head":
			squad.callout(self, "HEADSHOT")
	_bloom = minf(_bloom + (1.2 if pellets == 1 else 0.0), 6.0)
	player.remote_fire(0, w.id, origin, last_hit)
	GLBus.weapon_fired.emit(pid, w.id, w.upgraded, origin, -basis.z)
	if w.mag <= 0 and w.reserve > 0:
		_start_reload()


func _spread_dir(basis: Basis, spread: float) -> Vector3:
	var fwd: Vector3 = -basis.z
	if spread <= 0.001:
		return fwd
	var r: float = sqrt(_rng.randf()) * deg_to_rad(spread)
	var a: float = _rng.randf() * TAU
	return (fwd + basis.x * sin(a) * tan(r) + basis.y * cos(a) * tan(r)).normalized()


## One ray with penetration, the same damage rules as WeaponHolder._trace. Returns the end point.
func _trace(origin: Vector3, dir: Vector3, w: WeaponInstance, hits: Dictionary) -> Vector3:
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var exclude: Array[RID] = [player.get_rid()]
	var pierce: int = int(w.data.get("penetration", 0))
	var from: Vector3 = origin
	var end_point: Vector3 = origin + dir * SHOT_RANGE
	var last_hit: Vector3 = end_point
	for i: int in pierce + 1:
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, end_point, MASK_SHOT, exclude)
		q.collide_with_areas = true
		var res: Dictionary = space.intersect_ray(q)
		if res.is_empty():
			break
		var pos: Vector3 = res["position"]
		last_hit = pos
		var col: Object = res["collider"]
		if col is Hitbox:
			var hb: Hitbox = col as Hitbox
			var z: Zombie = hb.enemy as Zombie
			if z == null or not z.is_active():
				exclude.append(hb.get_rid())
				continue
			var mult: float = w.limb_mult(hb.limb)
			if hb.limb == &"head":
				mult *= float(PerkManager.stat(player.player_id, "head_damage_mult", 1.0))
			var dmg: float = w.f("damage", 50.0) * w.falloff(origin.distance_to(pos)) * mult
			var cur: Dictionary = hits.get(z, {"dmg": 0.0, "limb": "torso", "mult": 0.0})
			cur["dmg"] = float(cur["dmg"]) + dmg
			if mult > float(cur["mult"]):
				cur["mult"] = mult
				cur["limb"] = String(hb.limb)
				cur["bone"] = hb.bone
			hits[z] = cur
			Effects.blood(pos, -dir)
			for rid: RID in z.hitbox_rids():
				exclude.append(rid)
			from = pos + dir * 0.05
		else:
			var shootable: Node = WeaponHolder.shootable_of(col)
			if shootable != null:
				WeaponHolder.notify_shot(shootable, w.id, w.upgraded, player.player_id)
			Effects.impact(pos, res["normal"])
			break
	return last_hit


# ---------------------------------------------------------------- reload / swap / melee

func _weapon_logic() -> void:
	var w: WeaponInstance = player.weapons.current()
	if w == null or _swap_t > 0.0:
		return
	# an objective that needs a particular gun in hand (the Totenglocke at the heart, an upgraded gun for the bell)
	var forced: int = _forced_slot()
	if forced >= 0:
		if forced != player.weapons.current_index:
			_select(forced)
			return
		if w.mag > 0 or w.reserve > 0 or str(_errand.get("kind", "")) == "crucible_ammo":
			if w.mag == 0 and w.reserve > 0 and not _reloading:
				_start_reload()
			return
	var other_loaded: int = -1
	var other_any: int = -1
	for i: int in player.weapons.slots.size():
		var inst: WeaponInstance = player.weapons.slots[i]
		if inst == w:
			continue
		if inst.mag > 0 and other_loaded < 0:
			other_loaded = i
		if (inst.mag > 0 or inst.reserve > 0) and other_any < 0:
			other_any = i
	if w.mag == 0 and ((other_loaded >= 0 and _near_d < 6.0) or (w.reserve == 0 and other_any >= 0)):
		_select(other_loaded if other_loaded >= 0 else other_any)
	elif w.mag == 0 and w.reserve > 0 and not _reloading:
		_start_reload()
	elif target == null and w.mag < int(float(w.mag_size()) * 0.6) and w.reserve > 0 and not _reloading:
		_start_reload()
	if w.mag == 0 and w.reserve == 0 and other_any < 0:
		squad.callout(self, "AMMO_NONE")


func _select(i: int) -> void:
	if i < 0 or i >= player.weapons.slots.size() or i == player.weapons.current_index:
		return
	_cancel_reload()
	player.weapons.current_index = i
	_swap_t = SWAP_TIME
	_burst_t = 0.0
	AudioDirector.play_3d("weapon_raise", _eye(), -10.0)
	if player.remote_body != null:
		var w: WeaponInstance = player.weapons.current()
		player.remote_body.set_weapon(w.id if w != null else &"")


func _reload_mult(w: WeaponInstance) -> float:
	return float(PerkManager.stat(player.player_id, "reload_time_mult", 1.0)) * float(w.property("reload_mult", 1.0))


func _start_reload() -> void:
	var w: WeaponInstance = player.weapons.current()
	if w == null or _reloading or w.reserve <= 0 or w.mag >= w.mag_size():
		return
	_reloading = true
	_burst_t = 0.0
	# Overclock Cordial: the static burst at reload start (a no-op without the perk; PerkManager checks)
	PerkManager.overclock_reload(player, PerkManager.overclock_spent(w.mag, w.mag_size()))
	var mult: float = _reload_mult(w)

	if bool(w.data.get("per_round_reload", false)) and not (w.mag == 0 and w.weapon_class() == &"bolt"):
		_reload_per_round = true
		_reload_t = w.f("reload_partial", 0.5) * mult
	else:
		_reload_per_round = false
		_reload_t = (w.f("reload_empty", 2.5) if w.mag == 0 else w.f("reload_partial", 2.0)) * mult
	AudioDirector.play_3d("reload_start", _eye(), -9.0)


func _cancel_reload() -> void:
	_reloading = false
	_reload_per_round = false


func _tick_reload(delta: float) -> void:
	if not _reloading:
		return
	var w: WeaponInstance = player.weapons.current()
	if w == null:
		_cancel_reload()
		return
	_reload_t -= delta
	if _reload_t > 0.0:
		return
	if _reload_per_round:
		var add: int = mini(1, w.reserve)
		w.mag += add
		w.reserve -= add
		if w.mag < w.mag_size() and w.reserve > 0 and not (_near_d < 2.5 and w.mag > 0):
			_reload_t = w.f("reload_partial", 0.5) * _reload_mult(w)
			return
	else:
		var take: int = mini(w.mag_size() - w.mag, w.reserve)
		w.mag += take
		w.reserve -= take
	_reloading = false
	_reload_per_round = false
	AudioDirector.play_3d("reload_end", _eye(), -9.0)


## A knife swing at whatever is in reach (the same rules as WeaponHolder._melee_strike, no lunge).
func _try_melee() -> bool:
	if _melee_cd > 0.0 or _near_z == null or _near_d > float(_combat.get("melee_range_m", 1.7)):
		return false
	var md: Dictionary = (GLData.table("weapons")["melee"] as Dictionary).get(String(player.weapons.melee_id), {})
	if md.is_empty():
		return false
	_melee_cd = float(md.get("swing", 0.55)) + 0.25
	_cancel_reload()
	var dmg: float = float(md.get("damage", 150.0))
	if GameState.player_has_trait(player.player_id, &"dutch"):
		dmg *= float(_pcfg["traits"]["dutch_melee_mult"])
	var fwd: Vector3 = -player.global_basis.z
	player.remote_fire(3, player.weapons.melee_id, _eye(), _eye() + fwd)
	_turn_toward(_near_z.global_position + Vector3.UP, 0.5, 3.0)
	var hit: int = 0
	for z: Zombie in _zs:
		if _flat(z.global_position, player.global_position) <= float(md.get("reach", 2.0)) + 0.4 and absf(z.global_position.y - player.global_position.y) < 1.6:
			z.take_damage(dmg, &"torso", player.weapons.melee_id, player.player_id, &"melee")
			Effects.blood(z.global_position + Vector3.UP * 1.2, fwd)
			hit += 1
			if hit >= int(md.get("targets", 1)):
				break
	if hit > 0:
		AudioDirector.play_3d("knife_hit", _eye(), -4.0)
	return true


# ================================================================== modes

func _tick_fight(delta: float) -> void:
	_sprint = false
	var w: WeaponInstance = player.weapons.current()
	var dry: bool = w == null or w.mag <= 0 or _reloading
	if _near_d < float(_combat.get("melee_range_m", 1.7)) and (dry or _near_z == target):
		if _try_melee():
			return
	_aim_and_fire(delta)
	# hold the ground unless the leader is getting away or something is closing in (then back off while firing)
	var leader: Player = squad.leader_for(self)
	if _near_z != null and _near_d < float(_combat.get("backpedal_radius_m", 2.6)) and not (_near_d < float(_combat.get("melee_range_m", 1.7)) and _melee_cd <= 0.0 and dry):
		var away: Vector3 = player.global_position - _near_z.global_position
		away.y = 0.0
		if away.length() > 0.01 and (_goal == Vector3.INF or _reached() or _repath_t <= 0.0):
			_set_goal(_snap(player.global_position + away.normalized() * 2.5), true)
	elif not roaming() and leader != null and leader != player and _flat(leader.global_position, player.global_position) > float(_follow.get("far_m", 6.5)) * 1.6:
		_set_goal(_slot_point(leader), false)
	else:
		_clear_goal()


func _tick_flee(delta: float) -> void:
	_flee_t += delta
	_sprint = false
	if target == null and _near_z != null:
		target = _near_z
	if _near_d < float(_combat.get("melee_range_m", 1.7)) and _try_melee():
		return
	_aim_and_fire(delta, 0.8)
	if _repath_t <= 0.0 or _goal == Vector3.INF or _reached():
		_retreat()


## Open ground away from the crowd, toward the leader when possible, by a route that doesn't brush a zombie.
func _retreat() -> void:
	var me: Vector3 = player.global_position
	var centroid: Vector3 = Vector3.ZERO
	var n: int = 0
	for z: Zombie in _zs:
		if _flat(z.global_position, me) < 8.0:
			centroid += z.global_position
			n += 1
	if n == 0:
		_clear_goal()
		return
	centroid /= float(n)
	var away: Vector3 = me - centroid
	away.y = 0.0
	away = away.normalized() if away.length() > 0.05 else Vector3.FORWARD
	var leader: Player = squad.leader_for(self)
	var nav: RID = player.get_world_3d().navigation_map
	var best: Vector3 = Vector3.INF
	var best_s: float = -INF
	for k: int in 12:
		var a: float = float(k) / 12.0 * TAU + _rng.randf() * 0.3
		var dir: Vector3 = Vector3(cos(a), 0.0, sin(a))
		var want: Vector3 = me + dir * _rng.randf_range(4.0, 6.5)
		var p: Vector3 = NavigationServer3D.map_get_closest_point(nav, want)
		if p.distance_to(want) > 1.5 or absf(p.y - me.y) > 1.6:
			continue
		var clear: float = INF
		for z: Zombie in _zs:
			clear = minf(clear, _flat(z.global_position, p))
		if clear < 2.0:
			continue
		var s: float = minf(clear, 9.0) * 1.5 + dir.dot(away) * 3.0
		if leader != null and leader != player:
			s -= _flat(leader.global_position, p) * 0.15
		if s > best_s:
			best_s = s
			best = p
	if best == Vector3.INF:
		# nowhere open nearby (a cellar, a corridor): fall back toward the leader if they're clear of it, else
		# just back away from the nearest one
		if leader != null and leader != player and _flat(leader.global_position, me) > 4.0:
			var lp: PackedVector3Array = _open_path(me, _snap(leader.global_position))
			if not lp.is_empty() and not _path_brushes_zombie(lp, 0.9):
				_path = lp
				_path_i = 1 if lp.size() > 1 else 0
				_goal = lp[lp.size() - 1]
				_path_goal = _goal
				_repath_t = float(_follow.get("repath_s", 0.6))
				return
		var fallback: Vector3 = _snap(me + away * 2.5)
		_path = PackedVector3Array([me, fallback])
		_path_i = 1
		_goal = fallback
		_repath_t = 0.3
		return

	var path: PackedVector3Array = _open_path(me, best)
	if path.is_empty() or _path_brushes_zombie(path, 1.1):
		path = PackedVector3Array([me, best])
	_path = path
	_path_i = 1 if path.size() > 1 else 0
	_goal = best
	_path_goal = best
	_repath_t = float(_follow.get("repath_s", 0.6))


func _path_brushes_zombie(path: PackedVector3Array, radius: float) -> bool:
	for z: Zombie in _zs:
		var zp: Vector2 = Vector2(z.global_position.x, z.global_position.z)
		for i: int in range(1, path.size()):
			var a: Vector2 = Vector2(path[i - 1].x, path[i - 1].z)
			var b: Vector2 = Vector2(path[i].x, path[i].z)
			if Geometry2D.get_closest_point_to_segment(zp, a, b).distance_to(zp) < radius:
				return true
	return false


func _tick_revive(delta: float) -> void:
	var t: Player = squad.player_by_id(_revive_pid)
	var session: NetMatch = Net.session
	if t == null or session == null or not session.coop.is_downed(_revive_pid):
		_stop_revive()
		mode = Mode.FOLLOW
		return
	var rcfg: Dictionary = _cfg.get("revive", {})
	var d: float = _flat(t.global_position, player.global_position)
	var reach: float = float(rcfg.get("reach_m", 1.4))
	# zombies on top of us with time to spare: fight first (the bleed-out clock keeps running, so not for long)
	var risky: bool = _near_d < float(rcfg.get("safe_radius_m", 3.0)) and session.coop.bleed_left(_revive_pid) > float(rcfg.get("risk_bleed_s", 15.0))
	if risky and target != null:
		if _reviving:
			_stop_revive()
		_aim_and_fire(delta)
		_clear_goal()
		return
	if d > reach or absf(t.global_position.y - player.global_position.y) > 1.5:
		if _reviving:
			_stop_revive()
		_sprint = d > 8.0
		_set_goal(_snap(t.global_position), false)
		return
	_clear_goal()
	_sprint = false
	_turn_toward(t.global_position + Vector3.UP * 0.6, delta)
	if not _reviving:
		_reviving = true
		_revive_hold = 0.0
		session.coop.set_reviver(_revive_pid, player.player_id, true)
		squad.callout(self, "REVIVE")
	var need: float = CoopState.revive_seconds(float(_pcfg["revive_seconds"]), float(PerkManager.stat(player.player_id, "revive_speed_mult", 1.0)))
	_revive_hold += delta
	if _revive_hold >= need:
		_reviving = false
		_revive_hold = 0.0
		session.coop_revive(_revive_pid, player.player_id)
		mode = Mode.FOLLOW


func _stop_revive() -> void:
	if _reviving and Net.session != null and _revive_pid != 0:
		Net.session.coop.set_reviver(_revive_pid, player.player_id, false)
	_reviving = false
	_revive_hold = 0.0


func _tick_follow(delta: float) -> void:
	var leader: Player = squad.leader_for(self)
	if leader == null or leader == player:
		_clear_goal()
		_idle_look(delta)
		return
	var me: Vector3 = player.global_position
	var d_leader: float = _flat(leader.global_position, me)
	var slot: Vector3 = _slot_point(leader)
	var d_slot: float = _flat(slot, me)
	_sprint = d_leader > float(_follow.get("catchup_sprint_m", 11.0))
	if d_leader > float(_follow.get("far_m", 6.5)) or d_slot > float(_follow.get("near_m", 2.5)) + 1.0:
		_set_goal(slot, false)
	elif _goal != Vector3.INF and _reached():
		_clear_goal()
	if _goal == Vector3.INF:
		_keep_out_of_the_way(leader, delta)
	_idle_look(delta, leader)
	# cut off for a while (a door the human bought while we were elsewhere, a ledge): catch up by teleport
	var lost: bool = d_leader > float(_follow.get("teleport_min_dist_m", 14.0)) and (_path.is_empty() or _path_i >= _path.size())
	_away_t = _away_t + delta if lost else 0.0
	if _away_t > float(_follow.get("teleport_after_s", 8.0)) or me.y < -20.0:
		_teleport_to(leader)
		_away_t = 0.0


## Out of the leader's line of fire; never parked in a doorway.
func _keep_out_of_the_way(leader: Player, delta: float) -> void:
	var me: Vector3 = player.global_position
	var fwd: Vector3 = -leader.camera.global_basis.z if leader.camera != null else -leader.global_basis.z
	if leader.is_alive() and BotConfig.in_fire_cone(leader.global_position, fwd, me, float(_follow.get("line_of_fire_cone_deg", 20.0)), float(_follow.get("line_of_fire_range_m", 16.0))):
		_cone_t += delta
		if _cone_t > 0.35:
			var to_me: Vector3 = me - leader.global_position
			to_me.y = 0.0
			var side: Vector3 = Vector3(fwd.z, 0.0, -fwd.x).normalized()
			if side.dot(to_me) < 0.0:
				side = -side
			_set_goal(_snap(me + side * 1.8), true)
			_cone_t = 0.0
			return
	else:
		_cone_t = 0.0
	var keep: float = float(_follow.get("door_keepout_m", 1.3))
	for d: BuyDoor in _doors:
		if not is_instance_valid(d):
			continue
		var dd: float = _flat(d.global_position, me)
		if dd < keep and absf(d.global_position.y - me.y) < 2.0:
			var out: Vector3 = me - d.global_position
			out.y = 0.0
			if out.length() < 0.05:
				out = d.global_basis.z
			_set_goal(_snap(me + out.normalized() * (keep + 0.6)), true)
			return


## Looks around while nothing is happening: at the leader's facing, at the nearest zombie if one is near.
func _idle_look(delta: float, leader: Player = null) -> void:
	if _near_z != null and _near_d < 14.0:
		_turn_toward(_near_z.global_position + Vector3.UP * 1.2, delta, 0.7)
	elif leader != null:
		var fwd: Vector3 = -leader.global_basis.z
		_turn_toward(_eye() + fwd * 10.0, delta, 0.4)


## The formation slot on the navmesh; off it (a wall behind the leader) the same slot closer in, then mirrored,
## then straight behind, so two bots don't end up on one fallback point.
func _slot_point(leader: Player) -> Vector3:
	var off: Vector3 = BotConfig.slot_offset(_follow, index)
	var nav: RID = player.get_world_3d().navigation_map
	var mirrored: Vector3 = Vector3(-off.x, off.y, off.z)
	for cand: Vector3 in [off, off * 0.6, mirrored, mirrored * 0.6, Vector3(0.0, 0.0, 1.5 + 0.8 * float(index))]:
		var want: Vector3 = leader.global_position + leader.global_basis * cand
		var p: Vector3 = NavigationServer3D.map_get_closest_point(nav, want)
		if p.distance_to(want) < 1.0 and absf(p.y - leader.global_position.y) < 1.5:
			return p
	return NavigationServer3D.map_get_closest_point(nav, leader.global_position + leader.global_basis.z * 1.5)


func _teleport_to(leader: Player) -> void:
	var nav: RID = player.get_world_3d().navigation_map
	var back: Vector3 = leader.global_basis.z
	for k: int in 6:
		var a: float = float(k) * 1.05 - 2.6
		var dir: Vector3 = back.rotated(Vector3.UP, a)
		var want: Vector3 = leader.global_position + dir * 2.2
		var p: Vector3 = NavigationServer3D.map_get_closest_point(nav, want)
		if p.distance_to(want) > 1.2 or absf(p.y - leader.global_position.y) > 1.0:
			continue
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(leader.global_position + Vector3.UP * 0.9, p + Vector3.UP * 0.9, MASK_LOS)
		if not player.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			continue
		player.global_position = p + Vector3.UP * 0.05
		player.velocity = Vector3.ZERO
		_clear_goal()
		teleports += 1
		return


func _tick_downed(delta: float) -> void:
	# last stand: lie where we fell, keep the pistol working on whatever comes close and is in sight
	player.velocity.x = 0.0
	player.velocity.z = 0.0
	player.velocity.y = -0.5 if player.is_on_floor() else player.velocity.y - GRAVITY * delta
	player.move_and_slide()
	player._set_crouch_shape(true)
	player._eye = move_toward(player._eye, float((_pcfg.get("downed", {}) as Dictionary).get("eye_height", 0.45)), delta * 2.0)
	player.head.position.y = player._eye
	_sprint = false
	if _reviving:
		_stop_revive()
	_clear_goal()
	if target != null and _near_d < 14.0:
		_aim_and_fire(delta, 0.6)
	var w: WeaponInstance = player.weapons.current()
	if w != null and w.mag == 0 and w.reserve > 0 and not _reloading:
		_start_reload()


# ---------------------------------------------------------------- errands (between fights)

func _tick_errand(delta: float) -> void:
	if _errand.is_empty() or not is_instance_valid(_errand.get("node")):
		_finish_errand(str(_errand.get("kind", "")) == "shoot_moving")   # a shot drummer is gone: that was the point
		return
	if squad.time() > float(_errand["until"]):
		_finish_errand(false)
		return
	if OBJECTIVE_KINDS.has(str(_errand.get("kind", ""))):
		_tick_objective(delta)
		return
	var node: Interactable = _errand["node"] as Interactable
	_sprint = false
	var me: Vector3 = player.global_position
	var kind: String = str(_errand["kind"])
	var front: Vector3 = _door_side(node as BuyDoor, me) if node is BuyDoor else _front_of(node)
	var d: float = _flat(front, me)
	if d > 0.9 or absf(front.y - me.y) > 1.8:
		_set_goal(_snap(front), false)
		_errand["hold"] = 0.0
		_idle_look(delta)
		return
	_clear_goal()
	var aim: Vector3 = node.area.global_position if node.area != null else node.global_position + Vector3.UP
	if _crucible_sticky() and target != null:
		_aim_and_fire(delta)   # waiting on the forge with zombies about: shoot from the alcove
	else:
		_turn_toward(aim, delta)
	_errand["hold"] = float(_errand["hold"]) + delta
	if float(_errand["hold"]) < maxf(0.05, node.hold_time(player)):
		return
	_errand["hold"] = 0.0
	var done: bool = true
	if kind == "crucible" or kind == "crucible_ammo":
		done = _tick_crucible(node as Crucible, kind)
	else:
		if kind == "gun" and player.weapons.slots.size() >= player.weapons.max_slots():
			# a wall gun replaces the gun in hand: hold the worst non-upgraded one first; never trade an upgraded gun
			var give: int = _slot_to_give_up()
			if give < 0:
				_finish_errand(false)
				return
			if give != player.weapons.current_index:
				_select(give)
				return
		if node.can_interact(player):
			node.interact(player)
		if kind == "repair":
			done = not (node is Barricade and (node as Barricade).boards < (node as Barricade).max_boards)
		elif kind == "door" and (node as BuyDoor).is_open:
			_doors_bought += 1
			doors_bought_total += 1
	if done:
		_finish_errand(true)


## One hold at the Crucible. "crucible": feed the gun in hand (5000), wait out the forge in front of it, take the
## upgraded gun when it is offered; only our own forge is taken (never a teammate's: the co-op steal rule).
## "crucible_ammo": upgraded ammo (2500) for the upgraded gun in hand. Returns true when the errand is over.
func _tick_crucible(cr: Crucible, kind: String) -> bool:
	if not cr.is_powered():
		return true
	if kind == "crucible_ammo":
		var slot: int = int(_errand.get("slot", -1))
		if slot >= 0 and slot < player.weapons.slots.size() and slot != player.weapons.current_index:
			_select(slot)   # the upgraded gun that wants the ammo goes into the hands first
			return false
		if cr.phase == Crucible.Phase.IDLE and cr.can_interact(player):
			cr.interact(player)
		return true
	var fed: bool = bool(_errand.get("fed", false))
	match cr.phase:
		Crucible.Phase.IDLE:
			if fed:
				return true   # the offer ran out, or someone else took it
			if Crucible.action_for(player.weapons.current()) != &"upgrade":
				_select(_upgradeable_slot())   # hold the gun that can learn something
				return _upgradeable_slot() < 0
			if cr.can_interact(player):
				cr.interact(player)
			_errand["fed"] = cr.phase == Crucible.Phase.FORGING and cr._fed_by == player.player_id
			return not bool(_errand["fed"])
		Crucible.Phase.FORGING:
			return not fed   # ours: wait in front of it; someone else's: come back later
		Crucible.Phase.OFFERED:
			if cr._fed_by != player.player_id:
				return not fed   # not ours to take
			cr.interact(player)   # the upgraded gun comes into the hands: raise it like a swap
			_cancel_reload()
			_swap_t = SWAP_TIME
			_burst_t = 0.0
			if player.remote_body != null:
				var w: WeaponInstance = player.weapons.current()
				player.remote_body.set_weapon(w.id if w != null else &"")
			upgrades += 1
			return true
	return true


## The slot a new wall gun may replace: the worst non-upgraded gun by the wishlist (unlisted = worst), or -1 when
## every slot holds an upgraded gun (then nothing is bought).
func _slot_to_give_up() -> int:
	var wish: Array = (_cfg.get("shopping", {}) as Dictionary).get("weapon_wishlist", [])
	var worst: int = -1
	var worst_rank: int = -1
	for i: int in player.weapons.slots.size():
		var w: WeaponInstance = player.weapons.slots[i]
		if w.upgraded:
			continue
		var r: int = wish.find(String(w.base_id()))
		var rank: int = wish.size() + 1 if r < 0 else r
		if rank > worst_rank:
			worst_rank = rank
			worst = i
	return worst


## The slot holding a gun the Crucible can upgrade: a wall gun before the start pistol, the one in hand first

## among equals, or -1.
func _upgradeable_slot() -> int:
	var best: int = -1
	var best_s: int = -1
	for i: int in player.weapons.slots.size():
		var w: WeaponInstance = player.weapons.slots[i]
		if Crucible.action_for(w) != &"upgrade":
			continue
		var s: int = (0 if w.weapon_class() == &"pistol" else 2) + (1 if i == player.weapons.current_index else 0)
		if s > best_s:
			best_s = s
			best = i
	return best



## A Crucible errand whose gun is already in the forge (or offered): not dropped for a fight.
func _crucible_sticky() -> bool:
	return not _errand.is_empty() and str(_errand.get("kind", "")) == "crucible" and bool(_errand.get("fed", false))


## Where to stand to open a door: 1.1 m out from its plane on our side (the closest navmesh point may be behind it).
static func _door_side(door: BuyDoor, me: Vector3) -> Vector3:
	var side: Vector3 = door.global_basis.z
	side.y = 0.0
	if side.dot(me - door.global_position) < 0.0:
		side = -side
	return door.global_position + side.normalized() * 1.1


## Rebuild boards close by, then shop: a better wall gun, ammo for the gun in hand, a cheap perk.
func _choose_errand() -> Dictionary:
	var leader: Player = squad.leader_for(self)
	var anchor: Vector3 = leader.global_position if leader != null else player.global_position
	var best: Dictionary = {}
	var best_s: float = -INF
	for c: Dictionary in errand_candidates(anchor, 1.0):
		if float(c["score"]) > best_s:
			best_s = float(c["score"])
			best = c
	if best.is_empty():
		return {}
	squad.claim(best["node"], player.player_id)
	var extra: float = 0.0
	if str(best["kind"]) == "crucible":
		extra = (best["node"] as Crucible).forge_seconds + (best["node"] as Crucible).offer_seconds
	best["until"] = squad.time() + float((_cfg.get("shopping", {}) as Dictionary).get("errand_timeout_s", 20.0)) + extra
	best["hold"] = 0.0
	return best


## Every errand the shopping rules allow right now, scored: [{node, kind, score, label}]. Ranges are measured
## from `anchor` (the leader for a follower) and scaled by `range_mult` (the planner bot roams: a big one).
## Nothing is claimed here.
func errand_candidates(anchor: Vector3, range_mult: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var me: Vector3 = player.global_position
	var rcfg: Dictionary = _cfg.get("repair", {})
	var scfg: Dictionary = _cfg.get("shopping", {})
	var pid: int = player.player_id
	# boards
	var best_board: Dictionary = {}
	for n: Node in get_tree().get_nodes_in_group(&"barricades"):
		var b: Barricade = n as Barricade
		if b == null or b.boards >= b.max_boards:
			continue
		var d: float = _flat(b.global_position, me)
		if d > float(rcfg.get("radius_m", 9.0)) * minf(range_mult, 2.0) or _flat(b.global_position, anchor) > float(rcfg.get("max_from_leader_m", 14.0)) * range_mult:
			continue
		if not squad.can_claim(b, pid) or not _reachable(_front_of(b)):
			continue
		var s: float = 30.0 - d
		if best_board.is_empty() or s > float(best_board["score"]):
			best_board = {"node": b, "kind": "repair", "score": s, "label": "rebuild the boards at a window %d m away" % int(d)}
	if not best_board.is_empty():
		out.append(best_board)
	# shopping (only inside shopping range of the anchor, so a follower does not wander off across the map)
	var scrip: int = Economy.get_scrip(pid)
	var range_m: float = float(scfg.get("max_from_leader_m", 24.0)) * range_mult
	var prices: Dictionary = {}
	var walls: Dictionary = {}
	for wb: WallBuy in squad.wall_buys():
		if not is_instance_valid(wb) or not wb.is_visible_in_tree() or _flat(wb.global_position, anchor) > range_m:
			continue
		if not _reachable(_front_of(wb)):
			continue
		prices[String(wb.weapon_id)] = wb.price()
		walls[String(wb.weapon_id)] = wb
	var held: Array = []
	for w: WeaponInstance in player.weapons.slots:
		held.append(String(w.base_id()))
	var want: StringName = BotConfig.pick_weapon(scfg.get("weapon_wishlist", []), held, scrip, prices, int(scfg.get("weapon_buffer_scrip", 150)))
	if want != &"" and walls.has(String(want)):
		var wb2: WallBuy = walls[String(want)]
		out.append({"node": wb2, "kind": "gun", "score": 20.0 + float(wb2.price()) / 50.0 - _flat(wb2.global_position, me) * 0.5,
			"label": "buy the %s wall gun (%d Scrip)" % [weapon_name(want), wb2.price()]})
	for w2: WeaponInstance in player.weapons.slots:
		var wid: String = String(w2.base_id())
		if walls.has(wid) and w2.reserve < int(float(w2.reserve_max()) * float(scfg.get("ammo_below_frac", 0.35))):
			var wb3: WallBuy = walls[wid]
			if scrip >= wb3.ammo_price(player):
				out.append({"node": wb3, "kind": "ammo", "score": 60.0 - _flat(wb3.global_position, me) * 0.5,
					"label": "buy ammo for the %s (%d Scrip)" % [w2.display_name(), wb3.ammo_price(player)]})
	if RoundManager.current_round >= int(scfg.get("perk_min_round", 3)):
		var pprices: Dictionary = {}
		var machines: Dictionary = {}
		for n3: Node in get_tree().get_nodes_in_group(&"perk_machines"):
			var pm: PerkMachine = n3 as PerkMachine
			if pm == null or not pm.can_interact(player) or _flat(pm.global_position, anchor) > range_m or not _reachable(_front_of(pm)):
				continue
			pprices[String(pm.perk_id)] = PerkManager.price(pm.perk_id)
			machines[String(pm.perk_id)] = pm
		var perk: StringName = BotConfig.pick_perk(scfg.get("perk_wishlist", []), PerkManager.owned(pid), scrip, pprices, int(scfg.get("max_perks", 2)), int(scfg.get("perk_buffer_scrip", 400)))
		if perk != &"":
			var pm2: PerkMachine = machines[String(perk)]
			out.append({"node": pm2, "kind": "perk", "score": 45.0 - _flat(pm2.global_position, me) * 0.5,
				"label": "drink %s (%d Scrip)" % [PerkManager.display_name(perk), int(pprices[String(perk)])]})
	# doors: the one the human looks at or stands nearest, with a reserve left, after the delay into the round
	var dcfg: Dictionary = scfg.get("doors", {})
	if BotConfig.door_allowed(dcfg, squad.round_time(), _doors_bought):
		var infos: Array = []
		var nodes: Array[BuyDoor] = []
		for dn: BuyDoor in _doors:
			if not is_instance_valid(dn) or dn.is_open or _flat(dn.global_position, anchor) > float(dcfg.get("max_from_leader_m", 30.0)) * range_mult:
				continue
			var ok: bool = dn.can_interact(player) and squad.can_claim(dn, pid) and _reachable(_door_side(dn, me))
			infos.append({"cost": dn.cost, "pos": dn.global_position, "ok": ok})
			nodes.append(dn)
		var human: Player = squad.human()
		var hpos: Vector3 = human.global_position if human != null else me
		var hfwd: Vector3 = -human.camera.global_basis.z if human != null and human.camera != null else -player.global_basis.z
		var di: int = BotConfig.pick_door(dcfg, infos, scrip, hpos, hfwd)
		if di >= 0:
			out.append({"node": nodes[di], "kind": "door", "score": 25.0 - _flat(nodes[di].global_position, me) * 0.3,
				"label": "open the %s (%d Scrip)" % [door_label(nodes[di]), nodes[di].cost]})
	# the Crucible, when the map has one and a held gun can learn something: in the round break, first of all,
	# never while the human is down. Upgraded ammo for an upgraded gun in hand that is running low.
	var ccfg: Dictionary = scfg.get("crucible", {})
	var econ: Dictionary = GLData.table("economy")
	var human_down: bool = Net.session != null and squad.human() != null and Net.session.coop.is_downed(squad.human().player_id)
	var in_break: bool = RoundManager.state != RoundManager.State.ROUND or (_zs.is_empty() and RoundManager.to_spawn <= 0)
	var cur: WeaponInstance = player.weapons.current()
	var up_slot: int = _upgradeable_slot()
	var up_tier: int = player.weapons.slots[up_slot].tier if up_slot >= 0 else 0
	var up_cost: int = Crucible.price_for(&"upgrade", econ, up_tier)
	var want_up: bool = BotConfig.crucible_wanted(ccfg, up_slot >= 0, scrip, up_cost, RoundManager.current_round)
	# upgraded ammo: the upgraded gun in hand first, else any upgraded gun carried (a dry one gets swapped away)
	var ammo_slot: int = -1
	for ai: int in player.weapons.slots.size():
		var aw: WeaponInstance = player.weapons.slots[ai]
		if BotConfig.crucible_ammo_wanted(ccfg, aw.upgraded, aw.reserve, aw.reserve_max(), scrip, Crucible.price_for(&"ammo", econ)):
			if ammo_slot < 0 or aw == cur:
				ammo_slot = ai
	var want_ammo: bool = ammo_slot >= 0
	if (want_up or want_ammo) and not human_down and (in_break or not bool(ccfg.get("only_in_break", true))):
		var cr: Crucible = crucible_for_me(float(ccfg.get("max_from_leader_m", 30.0)) * range_mult, anchor)
		if cr != null:
			# a dry upgraded gun first (cheaper, and it is the gun that matters), then the next teaching
			out.append({"node": cr, "kind": "crucible_ammo" if want_ammo else "crucible", "slot": ammo_slot,
				"score": float(ccfg.get("priority", 80.0)) - _flat(cr.global_position, me) * 0.3,
				"label": "buy upgraded ammo at the Crucible" if want_ammo else ("feed the %s to the Crucible (%d Scrip)" % [player.weapons.slots[up_slot].display_name(), up_cost])})
	return out


## A powered, idle Crucible within `range_m` of `anchor` that this bot may claim and reach, or null.
func crucible_for_me(range_m: float, anchor: Vector3) -> Crucible:
	for cn: Node in get_tree().get_nodes_in_group(&"crucible"):
		var cr: Crucible = cn as Crucible
		if cr == null or not cr.is_powered() or cr.phase != Crucible.Phase.IDLE or _flat(cr.global_position, anchor) > range_m:
			continue
		if not squad.can_claim(cr, player.player_id) or not _reachable(_front_of(cr)):
			continue
		return cr
	return null


static func weapon_name(wid: StringName) -> String:
	var row: Dictionary = (GLData.table("weapons")["weapons"] as Dictionary).get(String(wid), {})
	return str(row.get("name", wid))


## A door's name for people: its id without the "door_" prefix ("the stable door").
static func door_label(d: BuyDoor) -> String:
	return "%s door" % String(d.door_id).trim_prefix("door_").replace("_", " ")



## Where to stand to use something: 1 m out from its use box on the side the box sticks out (the box offset is
## on the Area's shape, `interact_offset`, in the node's frame: a perk machine's front, a wall-buy's chalk, the
## Crucible's mouth, a barricade's room side).
static func _front_of(node: Interactable) -> Vector3:
	var off: Vector3 = node.global_basis * node.interact_offset
	off.y = 0.0
	if off.length() < 0.05:
		return node.global_position
	var p: Vector3 = node.global_position + off + off.normalized() * 1.0
	p.y = node.global_position.y
	return p



func _reachable(p: Vector3) -> bool:
	var dest: Vector3 = _snap(p)
	if dest.distance_to(p) > 2.0:
		return false
	var path: PackedVector3Array = _open_path(player.global_position, dest)
	return not path.is_empty() and path[path.size() - 1].distance_to(dest) < 1.5


# ================================================================== movement

func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _snap(p: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(player.get_world_3d().navigation_map, p)


## A nav path that doesn't cross a closed BuyDoor (doors aren't baked into the navmesh). Empty when the only
## route is through one: bots never open doors, the human buys them.
func _open_path(from: Vector3, dest: Vector3) -> PackedVector3Array:
	var path: PackedVector3Array = NavigationServer3D.map_get_path(player.get_world_3d().navigation_map, from, dest, true, squad.nav_mask())
	for d: BuyDoor in _doors:
		if is_instance_valid(d) and not d.is_open and ZombieDirector.door_crossed(d, path):
			return PackedVector3Array()
	return path


func _set_goal(dest: Vector3, urgent: bool) -> void:
	if _goal != Vector3.INF and _goal.distance_to(dest) < 0.5 and _repath_t > 0.0 and not _path.is_empty():
		return
	if not urgent and _path_goal != Vector3.INF and _path_goal.distance_to(dest) < 0.5 and _repath_t > 0.0:
		return
	_goal = dest
	_path = _open_path(player.global_position, dest)
	_path_i = 1 if _path.size() > 1 else 0
	_path_goal = dest
	_repath_t = float(_follow.get("repath_s", 0.6))


func _clear_goal() -> void:
	_goal = Vector3.INF
	_path = PackedVector3Array()
	_path_i = 0


func _reached() -> bool:
	return _goal == Vector3.INF or _flat(_goal, player.global_position) < 0.6 or _path_i >= _path.size()


func _move(delta: float) -> void:
	var wish: Vector3 = Vector3.ZERO
	if not _path.is_empty() and _path_i < _path.size():
		var p: Vector3 = _path[_path_i]
		var flat: Vector3 = Vector3(p.x - player.global_position.x, 0.0, p.z - player.global_position.z)
		if flat.length() < 0.45:
			_path_i += 1
		else:
			wish = flat.normalized()
	# personal space: bots don't collide with each other, so they step apart on their own
	for p: Player in squad.all_players():
		if p == player or p.spectating:
			continue
		var apart: Vector3 = player.global_position - p.global_position
		apart.y = 0.0
		var ad: float = apart.length()
		if ad < 1.0 and ad > 0.01:
			wish += apart / ad * (1.0 - ad) * 1.5
		elif ad <= 0.01:
			wish += Vector3(cos(float(index) * 2.1), 0.0, sin(float(index) * 2.1))
	if wish.length_squared() > 1.0:
		wish = wish.normalized()
	var speed: float = float(_pcfg["walk_speed"])
	if _sprint and wish != Vector3.ZERO and target == null:
		speed = float(_pcfg["sprint_speed"])

	speed *= player.weapons.move_mult() * float(PerkManager.stat(player.player_id, "move_speed_mult", 1.0)) * player.status_move_mult()
	var on_floor: bool = player.is_on_floor()
	var horizontal: Vector3 = Vector3(player.velocity.x, 0.0, player.velocity.z)
	horizontal = horizontal.move_toward(wish * speed, (45.0 if on_floor else 8.0) * delta)
	player.velocity.x = horizontal.x
	player.velocity.z = horizontal.z
	player.velocity.y = -0.5 if on_floor and player.velocity.y < 0.0 else player.velocity.y - GRAVITY * delta
	player.sprinting = _sprint and wish != Vector3.ZERO and target == null
	player.crouching = false
	player._set_crouch_shape(false)
	player.head.position.y = player._eye
	player.move_and_slide()
	# stuck while walking: hop the path forward, then give up on this goal
	if wish != Vector3.ZERO:
		if player.global_position.distance_to(_last_pos) < 0.015:
			_stuck_t += delta
			if _stuck_t > 1.2 and on_floor:
				player.velocity.y = float(_pcfg["jump_velocity"]) * 0.8
			if _stuck_t > 3.0:
				_stuck_t = 0.0
				_clear_goal()
				_repath_t = 0.0
		else:
			_stuck_t = 0.0
	_last_pos = player.global_position


## The body: yaw and pitch go to the Player (head) and the third-person pose follows the state flags.
func _pose(delta: float) -> void:
	player.rotation.y = _yaw
	player.head.rotation.x = _pitch
	var flags: int = 0
	if player.spectating:
		flags |= NetMatch.PF_SPECTATE
	elif player.downed:
		flags |= NetMatch.PF_DOWNED
	if player.sprinting:
		flags |= NetMatch.PF_SPRINT
	if player.crouching:
		flags |= NetMatch.PF_CROUCH
	if player.is_on_floor():
		flags |= NetMatch.PF_FLOOR
	if _reloading:
		flags |= NetMatch.PF_RELOAD
	player.net_flags = flags
	if player.remote_body != null:
		player.remote_body.update_pose(delta, player.horizontal_speed(), _pitch, flags)



# ================================================================== objectives (the planner's errands)
# The errand dictionary a BotPlanner directive turns into (see BotPlanner._options): {id, kind, node, label,
# stand / vantage / pos / radius, qid, sid, cond, weapon, need_upgraded, ...}. Movement is the same nav-path
# walking as everything else; the use itself is the object's own method (interact, lock_frequency, plug,
# a real traced shot), the same calls a person's hold or shot makes.

func _tick_objective(delta: float) -> void:
	var e: Dictionary = _errand
	var node: Node3D = e.get("node") as Node3D
	if node == null or not is_instance_valid(node):
		_finish_errand(str(e.get("kind", "")) == "shoot_moving")
		return
	_sprint = false
	match str(e["kind"]):
		"use":
			_obj_use(delta, e, node)
		"radio", "switchboard":
			_obj_inputs(delta, e, node)
		"shoot":
			_obj_shoot(delta, e, node)
		"shoot_seq":
			_obj_bells(delta, e)
		"shoot_moving":
			_obj_moving(delta, e, node)
		"hold":
			_obj_hold(delta, e, node)
		"crate":
			_obj_crate(delta, e, node as MysteryCrate)
		_:
			_finish_errand(false)


## Walks toward `p`; true once within `tol` (flat) on the same floor. Gives up on the errand after 4 s without a
## route (a door closed in the way, a ledge).
func _walk_to(p: Vector3, tol: float, e: Dictionary) -> bool:
	var me: Vector3 = player.global_position
	if _flat(p, me) <= tol and absf(p.y - me.y) < 1.8:
		_clear_goal()
		e["nopath_t"] = 0.0
		return true
	_sprint = _flat(p, me) > 9.0 and target == null
	_set_goal(p, false)
	if _path.is_empty():
		e["nopath_t"] = float(e.get("nopath_t", 0.0)) + get_physics_process_delta_time()
		if float(e["nopath_t"]) > 4.0:
			_finish_errand(false)
	else:
		e["nopath_t"] = 0.0
	if target != null:
		_aim_and_fire(get_physics_process_delta_time(), 0.8)   # shoot on the way
	else:
		_idle_look(get_physics_process_delta_time())
	return false


## Walk to it, hold use for its hold time, use it. A pylon then becomes a hold inside its ring until attuned.
func _obj_use(delta: float, e: Dictionary, node: Node3D) -> void:
	var it: Interactable = node as Interactable
	if it == null or not it.can_interact(player):
		_finish_errand(false)
		return
	if not _walk_to(e.get("stand", node.global_position), 0.6, e):
		e["hold"] = 0.0
		return
	_turn_toward(it.area.global_position if it.area != null else node.global_position, delta)
	e["hold"] = float(e["hold"]) + delta
	if float(e["hold"]) < maxf(0.3, it.hold_time(player)):
		return
	it.interact(player)
	if it is Pylon and (it as Pylon).state == Pylon.State.CHARGING:
		e["kind"] = "hold"
		e["cond"] = "pylon"
		e["pos"] = _snap(it.global_position)
		e["radius"] = (it as Pylon).radius * 0.45
		e["until"] = squad.time() + 120.0
		return
	_finish_errand(true)


## The radio's frequencies / the switchboard's digits, one every 0.6 s from where the step stands.
func _obj_inputs(delta: float, e: Dictionary, node: Node3D) -> void:
	var qid: StringName = StringName(str(e.get("qid", "")))
	var sid: StringName = StringName(str(e.get("sid", "")))
	if QuestManager.is_step_done(qid, sid):
		_finish_errand(true)
		return
	if not QuestManager.is_active(qid, sid):
		_finish_errand(false)
		return
	if not _walk_to(e.get("stand", node.global_position), 0.6, e):
		e["hold"] = 0.0
		return
	_turn_toward(node.global_position + Vector3.UP * 0.3, delta)
	e["hold"] = float(e["hold"]) + delta
	if float(e["hold"]) < 0.9:
		return
	e["hold"] = 0.3
	var inputs: Array = QuestManager.sequence_inputs(qid, sid)
	var prog: Variant = QuestManager.progress(qid, sid)
	var idx: int = int(prog) if prog != null else 0
	if idx >= inputs.size():
		_finish_errand(true)
		return
	var res: String = ""
	if node is FieldRadio:
		res = (node as FieldRadio).lock_frequency(str(inputs[idx]))
	elif node is Switchboard:
		res = (node as Switchboard).plug(int(str(inputs[idx])))
	if res == "done":
		_finish_errand(true)
	elif res != "ok":
		e["tries"] = int(e.get("tries", 0)) + 1
		if int(e["tries"]) > 3:
			_finish_errand(false)


## One aimed shot at a thing (the Chapel bell needs an upgraded gun in hand) from a spot that sees it.
func _obj_shoot(delta: float, e: Dictionary, node: Node3D) -> void:
	if bool(e.get("need_upgraded", false)) and _forced_slot() < 0:
		_finish_errand(false)
		return
	if str(e.get("cond", "")) != "" and _cond_met(e, node):
		_finish_errand(true)
		return
	if not _walk_to(e.get("vantage", node.global_position), 0.8, e):
		return
	var aim: Vector3 = node.global_position + (e.get("aim_offset", Vector3.ZERO) as Vector3)
	if _shoot_at(aim, delta, 1.2):
		e["shots"] = int(e.get("shots", 0)) + 1
		if int(e["shots"]) > 14:
			_finish_errand(false)


## The Four Bells in melody order (the step's inputs from its progress): walk to a spot that sees the next bell,
## shoot it, move on. A wrong ring resets the melody (the quest's own rule); the walk starts again at bell one.
func _obj_bells(delta: float, e: Dictionary) -> void:
	var qid: StringName = StringName(str(e.get("qid", "")))
	var sid: StringName = StringName(str(e.get("sid", "")))
	if QuestManager.is_step_done(qid, sid):
		_finish_errand(true)
		return
	var inputs: Array = QuestManager.sequence_inputs(qid, sid)
	var prog: Variant = QuestManager.progress(qid, sid)
	var idx: int = int(prog) if prog != null else 0
	if idx >= inputs.size():
		_finish_errand(true)
		return
	var note: String = str(inputs[idx])
	var bells: Dictionary = e.get("bells", {})
	var bell: Node3D = bells.get(note) as Node3D
	if bell == null or not is_instance_valid(bell):
		_finish_errand(false)
		return
	var vps: Dictionary = e.get("vantages", {})
	if not vps.has(note):
		vps[note] = vantage_for(bell.global_position)
		e["vantages"] = vps
	var vp: Vector3 = vps[note]
	if vp == Vector3.INF:
		_finish_errand(false)
		return
	if not _walk_to(vp, 0.8, e):
		return
	if int(e.get("at_idx", -1)) != idx:
		e["at_idx"] = idx
		e["shots"] = 0
	if _shoot_at(bell.global_position, delta, 1.0):
		e["shots"] = int(e["shots"]) + 1
		_fire_cd = maxf(_fire_cd, 0.6)   # let the ring register before the next one
		if int(e["shots"]) > 10:
			_finish_errand(false)


## Herr Tamtam on the march: shoot him when he is in sight, otherwise run after him.
func _obj_moving(delta: float, e: Dictionary, node: Node3D) -> void:
	var aim: Vector3 = node.global_position + Vector3.UP * 0.35
	var d: float = _eye().distance_to(aim)
	if d < 32.0 and los_point(_eye(), aim):
		_clear_goal()
		_shoot_at(aim, delta, 2.0)
		return
	_sprint = true
	if _repath_t <= 0.0 or _goal == Vector3.INF:
		_set_goal(_snap(node.global_position), true)
	_turn_toward(aim, delta, 0.8)


## Stand inside a spot and fight from there until the condition ends it (a pylon attuned, the Chapel bell out,
## a kill count done, the Heartstorm over). Leaves the spot only to come straight back.
func _obj_hold(delta: float, e: Dictionary, node: Node3D) -> void:
	if _cond_met(e, node):
		_finish_errand(true)
		return
	var p: Vector3 = e.get("pos", node.global_position)
	var r: float = float(e.get("radius", 2.0))
	if _flat(p, player.global_position) > r or absf(p.y - player.global_position.y) > 1.8:
		_set_goal(p, false)
		if target != null:
			_aim_and_fire(delta, 0.8)
		return
	_clear_goal()
	if target != null:
		_aim_and_fire(delta)
	else:
		_idle_look(delta)


## The Requisition Crate (the drummer chase needs pulls): pay, wait out the cycle, take the gun when it beats the
## worst held one (never trading an upgraded gun), and end the errand on the drummer or an empty-handed close.
func _obj_crate(delta: float, e: Dictionary, crate: MysteryCrate) -> void:
	if crate == null:
		_finish_errand(false)
		return
	var paid: bool = bool(e.get("paid", false))
	match crate.phase:
		MysteryCrate.Phase.CLOSED:
			if paid:
				_finish_errand(true)
				return
			if not _walk_to(e.get("stand", crate.global_position), 0.6, e):
				e["hold"] = 0.0
				return
			_turn_toward(crate.global_position + Vector3.UP * 0.6, delta)
			e["hold"] = float(e["hold"]) + delta
			if float(e["hold"]) < 0.5:
				return
			if Economy.get_scrip(player.player_id) < CrateManager.cost():
				_finish_errand(false)
				return
			crate.interact(player)
			e["paid"] = crate.phase != MysteryCrate.Phase.CLOSED
			e["until"] = squad.time() + 25.0
			if not bool(e["paid"]):
				_finish_errand(false)
		MysteryCrate.Phase.CYCLING:
			_turn_toward(crate.global_position + Vector3.UP * 0.8, delta)
		MysteryCrate.Phase.OFFERED:
			if not paid or int(crate.get("_owner_player")) != player.player_id:
				_finish_errand(false)
				return
			var got: StringName = StringName(str(crate.get("_result")))
			if _wants_crate_weapon(got):
				if player.weapons.slots.size() >= player.weapons.max_slots():
					var give: int = _slot_to_give_up()
					if give < 0:
						_finish_errand(true)
						return
					if give != player.weapons.current_index:
						_select(give)
						return
				crate.interact(player)
				if player.remote_body != null:
					var w: WeaponInstance = player.weapons.current()
					player.remote_body.set_weapon(w.id if w != null else &"")
			_finish_errand(true)
		_:
			_finish_errand(paid)   # the drummer (the planner sends us after him next) or hidden


## A crate gun worth taking: a free slot, a wonder weapon, or better than the worst held non-upgraded gun.
func _wants_crate_weapon(wid: StringName) -> bool:
	if not (GLData.table("weapons")["weapons"] as Dictionary).has(String(wid)):
		return false   # a tactical (grenades): leave it
	if wid == &"ashlight" or player.weapons.slots.size() < player.weapons.max_slots():
		return true
	var wish: Array = (_cfg.get("shopping", {}) as Dictionary).get("weapon_wishlist", [])
	var r: int = wish.find(String(wid))
	if r < 0:
		return false
	var give: int = _slot_to_give_up()
	if give < 0:
		return false
	var worst: int = wish.find(String(player.weapons.slots[give].base_id()))
	return worst < 0 or r < worst


## Hold / shoot end conditions.
func _cond_met(e: Dictionary, node: Node3D) -> bool:
	var qid: StringName = StringName(str(e.get("qid", "")))
	var sid: StringName = StringName(str(e.get("sid", "")))
	match str(e.get("cond", "")):
		"pylon":
			return not (node is Pylon) or (node as Pylon).state != Pylon.State.CHARGING
		"bell_lit":
			return GameState.has_flag(&"chapel_bell_lit") or QuestManager.is_step_done(qid, sid)
		"chapel":
			return QuestManager.is_step_done(qid, sid) or not GameState.has_flag(&"chapel_bell_lit")
		"step":
			return QuestManager.is_step_done(qid, sid) or not QuestManager.is_active(qid, sid)
		"holdout":
			return QuestManager.is_step_done(qid, sid) or QuestManager.holdout_state(qid, sid).is_empty()
	return false


## The slot an objective needs in hand: its `weapon` (base id), or any upgraded gun when `need_upgraded`; -1.
func _forced_slot() -> int:
	if str(_errand.get("kind", "")) == "crucible_ammo":
		var cs: int = int(_errand.get("slot", -1))
		return cs if cs >= 0 and cs < player.weapons.slots.size() else -1
	if _errand.is_empty() or not _errand.has("id"):
		return -1
	var want: String = str(_errand.get("weapon", ""))
	var need_up: bool = bool(_errand.get("need_upgraded", false))
	if want == "" and not need_up:
		return -1
	for i: int in player.weapons.slots.size():
		var w: WeaponInstance = player.weapons.slots[i]
		if want != "" and String(w.base_id()) == want:
			return i
		if need_up and w.upgraded:
			return i
	return -1


## Turns onto `p` and fires one aimed shot when on it (single shots, whatever the gun's fire mode). True on a shot.
func _shoot_at(p: Vector3, delta: float, tol_deg: float) -> bool:
	var err: float = _turn_toward(p, delta)
	var w: WeaponInstance = player.weapons.current()
	if w == null or _reloading or _swap_t > 0.0:
		return false
	if w.mag <= 0:
		if w.reserve > 0:
			_start_reload()
		return false
	if err > deg_to_rad(tol_deg) or _fire_cd > 0.0 or _teammate_in_the_way(p):
		return false
	_fire(w)
	_fire_cd = maxf(_fire_cd, 0.3)
	return true


# ---------------------------------------------------------------- spatial helpers for the planner

## Nothing solid between two points (walls, closed doors).
func los_point(from: Vector3, to: Vector3) -> bool:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, MASK_LOS, [player.get_rid()])
	return player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func reachable(p: Vector3) -> bool:
	return _reachable(p)


func flat_distance(p: Vector3) -> float:
	return _flat(p, player.global_position)


## Where to stand to use `node`: its use box's front, its own spot, or a ring around it, on the navmesh and
## reachable without crossing a closed door; Vector3.INF when there is none. Cached for a few seconds.
func stand_point(node: Node3D) -> Vector3:
	var key: int = node.get_instance_id()
	var c: Variant = _stand_cache.get(key)
	if c is Array and squad.time() - float((c as Array)[0]) < 4.0:
		return (c as Array)[1]
	var base: Vector3 = node.global_position
	var cands: Array[Vector3] = []
	if node is Interactable:
		cands.append(_front_of(node as Interactable))
	cands.append(base)
	for r: float in [0.9, 1.5]:
		for k: int in 8:
			var a: float = float(k) / 8.0 * TAU
			cands.append(base + Vector3(cos(a) * r, 0.0, sin(a) * r))
	var out: Vector3 = Vector3.INF
	for cand: Vector3 in cands:
		for dy: float in [0.0, -1.5, -3.0]:
			var s: Vector3 = _snap(cand + Vector3(0.0, dy, 0.0))
			if _flat(s, base) < 1.8 and base.y - s.y < 3.2 and s.y - base.y < 1.2 and _reachable(s):
				out = s
				break
		if out != Vector3.INF:
			break
	_stand_cache[key] = [squad.time(), out]
	return out


## A reachable navmesh spot that sees `target` (a bell overhead, a bell on a rafter), nearest rings first;
## Vector3.INF when nothing within 12 m sees it.
func vantage_for(target: Vector3) -> Vector3:
	var eye_h: float = float((_cfg.get("perception", {}) as Dictionary).get("eye_height", 1.55))
	for r: float in [2.5, 4.5, 7.0, 10.0, 12.0]:
		for k: int in 12:
			var a: float = float(k) / 12.0 * TAU
			for dy: float in [-1.5, -4.0, -7.0, -11.0]:
				var want: Vector3 = target + Vector3(cos(a) * r, dy, sin(a) * r)
				var s: Vector3 = _snap(want)
				if s.distance_to(want) > 1.6 or s.y > target.y:
					continue
				if not los_point(s + Vector3.UP * eye_h, target):
					continue
				if _reachable(s):
					return s
	return Vector3.INF
