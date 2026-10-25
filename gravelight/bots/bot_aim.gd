class_name BotAim
extends RefCounted
## The aim and combat layer (Update 03 section 4): target choice, a human-like aim, fire discipline, reloads,
## weapon choice, the knife, grenades and the Totenglocke. The brain owns one; executors (bot_actions.gd) say
## whether it may fire this frame. Tuning: data/gravelight/ai/combat.json aim / weapons / reload / grenades /
## melee / totenglocke, the skill (skills.json) and the personality's aim / combat blocks.
##
## Aim: a new target is acquired after the skill's reaction delay; the aim then converges on it like a damped
## spring with the skill's overshoot (a little past it, back) while a tracking error shrinks from aim_error_deg
## to settle_error_deg over track_tau_s on a steady target. The body turns at the skill's turn rate (the
## locomotion layer); shots go where the body really points, so the error makes real misses.
## The pistol trap (docs/BOT_AI.md baseline): weapon choice is re-scored every think, and a bot goes back to its
## best gun (and reloads it) as soon as nothing is within swap_back_safe_m, so the start pistol is only for the
## moment something is in its face with the main gun dry.

const MASK_SHOT: int = 1 | (1 << 3) | (1 << 8)   # world | zombie hitbox | door (WeaponHolder.MASK_SHOT)
const MASK_LOS: int = 1 | (1 << 8)
const SHOT_RANGE: float = 220.0
const SWAP_TIME: float = 0.42

var brain: BotBrain
var player: Player
var target: Zombie = null
var target_score: float = 0.0
## The point it aims at when not the body: a weak point node (the Reach's wrist), else null.
var aim_node: Node3D = null
var aim_head: bool = false
var shots: int = 0
## Shots that hit a zombie (hits_landed), and what the misses hit first (soak diagnostics: collider class -> count).
var hits_landed: int = 0
var miss_on: Dictionary = {}
var _clear_for: Object = null
var _clear_t: float = -1.0
var _clear_ok: bool = true
var grenades_thrown: int = 0
var great_tolls: int = 0
var domes: int = 0
## Set by the brain / objectives each think: a slot that must be in hand (-1 none).
var force_slot: int = -1
## Set by the Cover action every frame: zombies near this point (a downed teammate) come first.
var cover_point: Vector3 = Vector3.INF
## T-071: a zombie the executor wants shot first (the trainer's cutter on the loop ahead); null = the usual pick.
var focus_target: Zombie = null

var _a: Dictionary = {}
var _w: Dictionary = {}
var _r: Dictionary = {}
var _g: Dictionary = {}
var _m: Dictionary = {}
var _tg: Dictionary = {}
var _sk: Dictionary = {}
var _pers: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _target_t: float = 0.0
var _react_t: float = 0.0
var _lost_t: float = 0.0
var _err0: Vector2 = Vector2.ZERO
var _noise: Vector2 = Vector2.ZERO
var _noise_next: Vector2 = Vector2.ZERO
var _noise_t: float = 0.0
var _noise_len: float = 0.25
var _zeta: float = 0.4
var _omega: float = 25.0
var fire_cd: float = 0.0
var _bloom: float = 0.0
var reloading: bool = false
var _reload_per_round: bool = false
var _reload_t: float = 0.0
var swap_t: float = 0.0
var _swap_cd: float = 0.0
var _burst_t: float = 0.0
var _pause_t: float = 0.0
var melee_cd: float = 0.0
var _grenade_cd: float = 3.0
var _dome: Node = null
var _low_ammo_said: bool = false


func setup(b: BotBrain) -> void:
	brain = b
	player = b.player
	_a = BotAIData.combat("aim")
	_w = BotAIData.combat("weapons")
	_r = BotAIData.combat("reload")
	_g = BotAIData.combat("grenades")
	_m = BotAIData.combat("melee")
	_tg = BotAIData.combat("totenglocke")
	_sk = b.skill
	_pers = b.personality
	_rng.randomize()
	var o: float = clampf(float(_sk.get("overshoot", 0.25)), 0.02, 0.9)
	var lo: float = log(o)
	_zeta = -lo / sqrt(PI * PI + lo * lo)
	_omega = 4.0 / maxf(0.05, _zeta * float(_sk.get("track_tau_s", 0.4)))


func tick_timers(delta: float) -> void:
	fire_cd = maxf(-0.05, fire_cd - delta)
	swap_t = maxf(0.0, swap_t - delta)
	_swap_cd -= delta
	melee_cd = maxf(0.0, melee_cd - delta)
	_grenade_cd -= delta
	_bloom = move_toward(_bloom, 0.0, delta * (9.0 if player.horizontal_speed() < 1.0 else 4.5))
	_target_t += delta
	_react_t -= delta
	_tick_reload(delta)


func eye() -> Vector3:
	return player.head.global_position


func cur() -> WeaponInstance:
	return player.weapons.current() if player.weapons != null else null


# ================================================================== think (5 Hz)

## Target choice, weapon choice, reload decisions and grenades.
func think(now: float) -> void:
	_pick_target(now)
	_weapon_logic()
	_maybe_grenade()
	var w: WeaponInstance = cur()
	if w != null and not _low_ammo_said and w.weapon_class() != &"pistol" and w.reserve_max() > 0 \
			and w.mag + w.reserve < int(float(w.mag_size() + w.reserve_max()) * 0.2):
		_low_ammo_said = brain.squad.callout(brain, "AMMO_LOW")


func on_round_started() -> void:
	_low_ammo_said = false


## Keeps a visible target unless a much better one shows; otherwise the best visible one (score, see the class doc).
func _pick_target(now: float) -> void:
	var per: BotPerception = brain.perception
	var engage: float = 45.0
	if target != null:
		if not BotPerception.targetable(target) or target.global_position.distance_to(player.global_position) > engage * 1.25:
			target = null
		elif per.is_visible(target) or _los(eye(), aim_point(target), target):
			_lost_t = 0.0
		else:
			_lost_t += 1.0 / maxf(1.0, brain.think_hz)
			if _lost_t > float(_a.get("reacquire_lost_s", 0.8)):
				target = null
	if focus_target != null and BotPerception.targetable(focus_target) and (per.is_visible(focus_target) or _los(eye(), aim_point(focus_target), focus_target)):
		if target != focus_target:
			_acquire(focus_target, target_value(focus_target))
		return
	var best: Zombie = null
	var best_s: float = 0.0
	for e: Variant in per.known:
		var z: Zombie = (e as Dictionary)["node"]
		if not per.is_visible(z) and z != target:
			continue
		var s: float = target_value(z)
		if s > best_s:
			best_s = s
			best = z
	if best == null:
		if target != null:
			target_score = target_value(target)
		return
	if target == null or not BotPerception.targetable(target):
		_acquire(best, best_s)
	elif best != target:
		var cur_s: float = target_value(target)
		if best_s > cur_s * 1.4 + 0.05:
			_acquire(best, best_s)
		else:
			target_score = cur_s
	else:
		target_score = best_s
	_update_weak_point()


## How much this bot wants to shoot `z` now (0 = leave it).
func target_value(z: Zombie) -> float:
	var per: BotPerception = brain.perception
	var c: Dictionary = BotAIData.counter(z.enemy_id)
	var th: float = float(per.threat.get(z.get_instance_id(), 0.0))
	var d: float = _flat(z.global_position, player.global_position)
	var w: WeaponInstance = cur()
	var max_r: float = max_range(w)
	if d > max_r * 1.3 and th <= 0.0:
		return 0.0
	var s: float = 0.08 + th + maxf(0.0, 1.0 - d / maxf(10.0, max_r)) * 0.25
	s *= float(c.get("priority", 1.0))
	if BotPerception.is_boss(z) or z.enemy_id != &"ganger":
		s *= 1.0 + float((_pers.get("aim", {}) as Dictionary).get("specials_first", 0.0))
	if bool(c.get("focus_when_vulnerable", false)) and z is HomageBoss and (z as HomageBoss).damage_taken_mult() > 1.01:
		s *= float(c.get("vulnerable_priority", 2.0))
	if bool(c.get("break_grab", false)) and z is HomageBoss and _holds_teammate(z as HomageBoss):
		s *= float(c.get("grab_priority", 3.0))
	elif float(c.get("adds_first_m", 0.0)) > 0.0 and not (z is HomageBoss and (z as HomageBoss).damage_taken_mult() > 1.01) 			and per.nearest != null and per.nearest != z and not BotPerception.is_boss(per.nearest) and per.nearest_d < float(c.get("adds_first_m", 0.0)):
		s *= float(c.get("adds_first_mult", 0.35))   # T-058: a runner at our heels first; the boss when it's clear (or vulnerable)
	if z.state == Zombie.State.TEAR or z.state == Zombie.State.CLIMB or z.state == Zombie.State.WAIT_WINDOW:
		s += 0.3
	if cover_point != Vector3.INF and _flat(z.global_position, cover_point) < 7.0:
		s *= 2.0
	var esc: Player = brain.escort_target()
	if esc != null and z.target == esc:
		s *= float(_a.get("escort_bonus", 1.5))
	# kill-steal etiquette: early on, a weak zombie the human is shooting is theirs unless it threatens someone
	if RoundManager.current_round <= int(_a.get("kill_steal_until_round", 6)) and z.max_hp > 0.0 and z.hp / z.max_hp < float(_a.get("kill_steal_hp_frac", 0.4)):
		var h: Player = brain.squad.human()
		if h != null and h.is_alive() and not h.spectating and h.camera != null and th < 0.5:
			var near_anyone: bool = false
			for p: Player in brain.squad.standing():
				if _flat(z.global_position, p.global_position) < 4.0:
					near_anyone = true
			if not near_anyone and BotConfig.in_fire_cone(h.head.global_position, -h.camera.global_basis.z, z.global_position, 22.0, 40.0):
				return 0.0
	return s


func _holds_teammate(b: HomageBoss) -> bool:
	for g: Dictionary in b.grabs():
		var p: Player = g.get("p") as Player
		if p != null and p != player:
			return true
	return false


func _acquire(z: Zombie, s: float) -> void:
	var prev: Zombie = target
	target = z
	target_score = s
	_target_t = 0.0
	_lost_t = 0.0
	_react_t = BotConfig.range_roll(_sk.get("reaction_s"), _rng, 0.22)
	# T-058: switching to a zombie right next to the one it was already shooting (within quick_switch_deg of the
	# aim) is a flick, not a new reaction: a bot whose cover / revive actions re-weighted its targets every think
	# used to re-roll the full reaction delay each time and never fired
	if prev != null and is_instance_valid(prev) and _react_t > 0.0:
		var to: Vector3 = z.global_position + Vector3.UP * 1.2 - eye()
		if to.length() > 0.1 and brain.facing().angle_to(to.normalized()) < deg_to_rad(float(_a.get("quick_switch_deg", 20.0))):
			_react_t = float(_a.get("quick_switch_s", 0.06))
	var w: WeaponInstance = cur()
	var cls: String = String(w.weapon_class()) if w != null else "smg"
	var c: Dictionary = BotAIData.counter(z.enemy_id)
	var p_head: float = float((_a.get("base_head", {}) as Dictionary).get(cls, 0.3)) * float(_sk.get("head_aim_mult", 1.0))
	p_head += float((_pers.get("aim", {}) as Dictionary).get("head_bias", 0.0)) + float(c.get("head_bias", 0.0))
	if z.tier == &"shamble" or z.tier == &"walk" or _flat(z.global_position, player.global_position) < 6.0:
		p_head += float(_a.get("slow_or_close_head", 0.15))
	aim_head = str(c.get("aim", "head")) == "head" and _rng.randf() < clampf(p_head, 0.0, 0.95)
	var e: float = deg_to_rad(float(_sk.get("aim_error_deg", 5.0))) * float(brain.options.get("accuracy_mult", 1.0))
	var a: float = _rng.randf() * TAU
	_err0 = Vector2(cos(a), sin(a) * 0.6) * e * _rng.randf_range(0.6, 1.2)
	_noise = Vector2.ZERO
	_noise_next = Vector2.ZERO
	_noise_t = 0.0
	_update_weak_point()


## The Reach holding a teammate: aim at a live wrist (her weak point) instead of the body.
func _update_weak_point() -> void:
	aim_node = null
	if target is CousinReach and _holds_teammate(target as CousinReach):
		var best_d: float = INF
		for arm: HomageArm in (target as CousinReach).arms:
			if arm != null and arm.reach_on and arm.hitbox != null and arm.is_visible_in_tree():
				var d: float = arm.hitbox.global_position.distance_to(eye())
				if d < best_d and _los(eye(), arm.hitbox.global_position, target):
					best_d = d
					aim_node = arm.hitbox


## Head when going for it (and the head hitbox is there), a weak point when set, else the chest.
func aim_point(z: Zombie) -> Vector3:
	if z == target and aim_node != null and is_instance_valid(aim_node):
		return aim_node.global_position
	if brain.crawler != null and brain.crawler.making(z):
		var lhb: Variant = z.get("_hitboxes")
		if lhb is Array:
			for hb0: Variant in lhb:
				if hb0 is Hitbox and (hb0 as Hitbox).limb == &"legs":
					return (hb0 as Hitbox).global_position   # T-071 pass 3: its legs, for a crawler
		return z.global_position + Vector3.UP * 0.45
	if aim_head and z == target and not (brain.is_player_bot and RoundManager.current_round <= int((BotAIData.table("player_bot").get("points", {}) as Dictionary).get("knife_until_round", 0))):
		var hbs: Variant = z.get("_hitboxes")
		if hbs is Array:
			for hb: Variant in hbs:
				if hb is Hitbox and (hb as Hitbox).limb == &"head":
					return (hb as Hitbox).global_position
	if z.is_crawler:
		return z.global_position + Vector3.UP * _crawler_aim_h(z)
	return z.global_position + Vector3.UP * 1.15


## T-071 pass 3: a crawler's aim height, the first of crawler_aim_heights with a clear line from the eye (cached
## 0.25 s). The fixed 0.5 m was below a low lip on Map 0's yard (the ground's edging, a kerb): the line of sight
## failed every frame and the agent circled the round's last crawler for the soak's whole time cap.
var _crawl_h_for: Zombie = null
var _crawl_h_t: float = -1.0
var _crawl_h: float = 0.5


func _crawler_aim_h(z: Zombie) -> float:
	var now: float = brain.squad.time() if brain.squad != null else 0.0
	if z == _crawl_h_for and now - _crawl_h_t < 0.25:
		return _crawl_h
	_crawl_h_for = z
	_crawl_h_t = now
	_crawl_h = 0.5
	for h: Variant in _a.get("crawler_aim_heights", [0.5]):
		if _los(eye(), z.global_position + Vector3.UP * float(h), z):
			_crawl_h = float(h)
			break
	return _crawl_h


func max_range(w: WeaponInstance) -> float:
	if w == null:
		return 2.0
	if w.data.has("bell"):
		return float((w.data["bell"] as Dictionary).get("range", 8.0))
	return float((_a.get("max_range_m", {}) as Dictionary).get(String(w.weapon_class()), 30.0))


# ================================================================== per frame

## Aims at the target and fires when allowed. Returns true while it is aiming at a target (the executor
## leaves the look alone then).
func update(delta: float, may_fire: bool) -> bool:
	if target == null or not BotPerception.targetable(target):
		target = null
		return false
	var p: Vector3 = aim_point(target)
	var aim_dir: Vector3 = _perceived_dir(p, delta)
	brain.loco.look_at_dir(aim_dir)
	if not may_fire:
		return true
	_try_melee_target()
	if knife_for_points() != null:
		return true   # T-071 pass 3: the early rounds' knife for the Scrip: this one is knifed, not shot
	_fire_if_on(aim_dir, p, delta)
	return true


## T-071 pass 3 (the player bot only, player_bot.json "points"): in the first rounds a skilled solo player knifes
## for the Scrip (a knife kill pays 130 against 50-100 for a shot one): a lone zombie the knife kills (its health
## within the knife's damage) is let come and knifed; one the knife can't kill yet is shot in the body (10 Scrip a
## hit) until it can. The zombie this applies to now, or null (shoot as usual): only with nothing else within
## crowd_m, never one still outside a window, never a boss.
func knife_for_points() -> Zombie:
	if not brain.is_player_bot or target == null or not is_instance_valid(target):
		return null
	var pc: Dictionary = BotAIData.table("player_bot").get("points", {}) as Dictionary
	if RoundManager.current_round > int(pc.get("knife_until_round", 0)) or RoundManager.is_special_round:
		return null
	var z: Zombie = target
	if BotPerception.is_boss(z) or z.is_crawler or z.state == Zombie.State.TEAR or z.state == Zombie.State.WAIT_WINDOW or z.state == Zombie.State.TO_WINDOW 			or z.state == Zombie.State.CLIMB:
		return null
	if brain.perception.count_near(player.global_position, float(pc.get("crowd_m", 5.0))) > 1 or player.hp < player.max_hp * 0.99:
		return null
	return z if knife_kills(z) else null


## The direction the bot believes the aim point is in: the true one plus the converging error and the
## tracking noise (radians, yaw / pitch).
func _perceived_dir(p: Vector3, delta: float) -> Vector3:
	var to: Vector3 = p - eye()
	if to.length_squared() < 0.0001:
		return brain.facing()
	to = to.normalized()
	var t: float = _target_t
	var wd: float = _omega * sqrt(maxf(0.01, 1.0 - _zeta * _zeta))
	var conv: float = exp(-_zeta * _omega * t) * (cos(wd * t) + _zeta / sqrt(maxf(0.01, 1.0 - _zeta * _zeta)) * sin(wd * t))
	var err: Vector2 = _err0 * conv
	_noise_t -= delta
	if _noise_t <= 0.0:
		_noise_len = _rng.randf_range(0.2, 0.35)
		_noise_t = _noise_len
		_noise = _noise_next
		var s0: float = float(_sk.get("aim_error_deg", 5.0)) * 0.45
		var s1: float = float(_sk.get("settle_error_deg", 1.0))
		var sig: float = deg_to_rad(s1 + (s0 - s1) * exp(-t / maxf(0.05, float(_sk.get("track_tau_s", 0.4))))) * float(brain.options.get("accuracy_mult", 1.0))
		if player.horizontal_speed() > 1.0:
			sig *= 1.25
		if player.downed:
			sig *= 1.6
		_noise_next = Vector2(_rng.randfn(0.0, sig), _rng.randfn(0.0, sig))
	var k: float = 1.0 - clampf(_noise_t / maxf(0.01, _noise_len), 0.0, 1.0)
	err += _noise.lerp(_noise_next, k)
	var yaw_axis: Vector3 = Vector3.UP
	var right: Vector3 = to.cross(Vector3.UP).normalized() if absf(to.y) < 0.98 else Vector3.RIGHT
	return to.rotated(yaw_axis, err.x).rotated(right, err.y).normalized()


func _fire_if_on(aim_dir: Vector3, aim_p: Vector3, delta: float) -> void:
	var w: WeaponInstance = cur()
	if w == null or reloading or swap_t > 0.0 or _react_t > 0.0 or w.mag <= 0 or not brain.loco.fire_ready() or brain.loco.sprint_out_left() > 0.0:
		_blk("dry" if w == null or w.mag <= 0 or reloading else ("react" if _react_t > 0.0 else "not_ready"))
		return
	var tol: float = deg_to_rad(float(_sk.get("fire_tolerance_deg", 3.0)))
	var d: float = eye().distance_to(aim_p)
	# T-058: up close the body fills the view: anything within the target's own width (body_half_width_m at this
	# range) is a hit, as for a person hip-firing. The fixed 1.8 degree tolerance kept a bot with a zombie at
	# 0.7 m (its aim point swinging across 20+ degrees) from firing at all.
	tol = maxf(tol, atan2(float(_a.get("body_half_width_m", 0.22)), maxf(0.3, d)))
	if brain.facing().angle_to(aim_dir) > tol:
		_blk("turning")
		return
	# T-058: and the sights are on the target, the way a person sees their own crosshair: the tracking error still
	# delays the shot (and it misses inside this window), but it doesn't empty the magazine into the wall beside a
	# window at 15 m (the soak's shot audit: 60-90% of shots hit masonry, fences and the ground before this)
	var true_dir: Vector3 = (aim_p - eye()).normalized()
	if brain.facing().angle_to(true_dir) > maxf(tol, atan2(float(_a.get("body_half_width_m", 0.22)) * float(_a.get("sights_on_mult", 1.6)), maxf(0.3, d))):
		_blk("sights")
		return
	# no spraying what the cone can't hold: hip fire on the run at range scatters wider than the target (Map 1's
	# yard: 90% of the shots hit the ground and the walls); a person stops to aim or waits until it's closer
	var spray_w: float = float(_a.get("spray_width_mult", 3.0))
	if brain.trainer != null and brain.trainer.training() and brain.trainer.followers >= 3:
		spray_w *= float(BotAIData.table("player_bot").get("trainer", {}).get("train_spray_mult", 1.0))   # T-071 pass 3: a bunched train behind the target catches the misses
	if not w.data.has("bell") and current_spread_deg(w) > rad_to_deg(atan2(float(_a.get("body_half_width_m", 0.22)) * spray_w, maxf(0.3, d))):
		_blk("spread")
		return
	if d > max_range(w):
		_blk("range")
		return   # no spraying what it can't hit
	var c: Dictionary = BotAIData.counter(target.enemy_id)
	var fire_near: float = float(c.get("no_fire_near_teammates_m", 0.0))
	if fire_near > 0.0 and (w.weapon_class() == &"special" or bool(w.property("incendiary", false))):
		for p: Player in brain.squad.standing():
			if p != player and _flat(p.global_position, target.global_position) < fire_near:
				return
	if teammate_in_the_way(aim_p):
		_blk("teammate")
		return
	if not _clear_shot(aim_p):
		_blk("los")
		return   # T-058: the target went behind a wall / window frame since the think: no shot into the masonry
	if w.data.has("bell") and _bell_logic(w):
		return
	if w.fire_mode == "auto":
		if d > float(_a.get("burst_range_m", 9.0)):
			if _burst_t <= 0.0:
				if _pause_t > 0.0:
					_pause_t -= delta
					return
				_burst_t = BotConfig.range_roll(_a.get("burst_s"), _rng, 0.4)
				var conserve: float = float((_pers.get("combat", {}) as Dictionary).get("ammo_conserve", 0.0))
				_pause_t = BotConfig.range_roll(_a.get("pause_s"), _rng, 0.25) * (1.0 + conserve * (float(_a.get("conserve_pause_mult", 1.8)) - 1.0))
			_burst_t -= delta
		else:
			_burst_t = 0.0
	if fire_cd <= 0.0:
		fire(w)
		_blk("FIRED")
	else:
		_blk("cooldown")


## (T-071 pass 3, the soak's numbers) why a shot it was aiming for didn't go: reason -> frames.
var fire_blocks: Dictionary = {}


func _blk(why: String) -> void:
	if brain.is_player_bot:
		fire_blocks[why] = int(fire_blocks.get(why, 0)) + 1


## Totenglocke choices: the Great Toll on a bunched crowd. True when it handled this frame.
func _bell_logic(w: WeaponInstance) -> bool:
	var b: Dictionary = w.data["bell"]
	if fire_cd > 0.0:
		return true
	if eye().distance_to(target.global_position) > float(b.get("range", 8.0)) * 0.95:
		return true   # the toll only rings at what its cone reaches
	if Totenglocke.can_great(b, w.mag) and _bunched_in_cone(b) >= int(_tg.get("great_min", 6)):
		w.mag = maxi(0, w.mag - Totenglocke.great_cost(b))
		shots += 1
		great_tolls += 1
		fire_cd = float(b.get("toll_cooldown", 0.45)) * 2.0
		Totenglocke.bot_toll(player, w, eye(), brain.facing(), true)
		if w.mag <= 0 and w.reserve > 0:
			start_reload()
		return true
	return false


func _bunched_in_cone(b: Dictionary) -> int:
	var cone: Vector2 = Totenglocke.cone_for(b, true)
	var pts: Array[Vector3] = []
	for e: Variant in brain.perception.known:
		var z: Zombie = (e as Dictionary)["node"]
		if Totenglocke.in_cone(eye(), brain.facing(), z.global_position + Vector3.UP, cone.x, cone.y, 1.5):
			pts.append(z.global_position)
	if pts.size() < int(_tg.get("great_min", 6)):
		return pts.size()
	var c: Vector3 = Vector3.ZERO
	for p: Vector3 in pts:
		c += p
	c /= float(pts.size())
	var n: int = 0
	for p2: Vector3 in pts:
		if _flat(p2, c) <= float(_tg.get("great_bunch_m", 3.5)):
			n += 1
	return n


## Plants the Totenglocke's Bell Dome at its feet (revives, covering): needs the bell in hand and the charges.
func plant_dome() -> bool:
	var w: WeaponInstance = cur()
	if w == null or not w.data.has("bell") or (_dome != null and is_instance_valid(_dome)) or reloading or swap_t > 0.0:
		return false
	var b: Dictionary = w.data["bell"]
	if w.mag < int(b.get("dome_cost", 2)):
		return false
	_dome = Totenglocke.bot_dome(player, w)
	if _dome != null:
		domes += 1
	return _dome != null


## Throws its Siren Gramophone (if it carries one) at `at`.
func throw_gramophone(at: Vector3) -> bool:
	var h: WeaponHolder = player.weapons
	if h == null or h.tactical_id == &"" or h.tactical_count <= 0:
		return false
	var t: Dictionary = (GLData.table("weapons")["tactical"] as Dictionary).get(String(h.tactical_id), {})
	if t.is_empty():
		return false
	h.tactical_count -= 1
	var g: Gramophone = Gramophone.new()
	g.cfg = t
	g.by_player = player.player_id
	player.get_parent().add_child(g)
	g.global_position = eye() + brain.facing() * 0.6
	g.linear_velocity = _ballistic(g.global_position, at, float(t.get("throw_speed", 11.0)))
	g.add_collision_exception_with(player)
	if h.tactical_count <= 0:
		h.tactical_id = &""
	return true


## Fires one shot (or one toll) from the eye along the body's real facing.
func fire(w: WeaponInstance) -> void:
	if not PerkManager.round_saved(player.player_id, w):   # Twin Barrel III (T-075)
		w.mag -= 1
	shots += 1
	var rpm: float = maxf(1.0, w.f("rpm", 300.0) * float(PerkManager.stat(player.player_id, "fire_rate_mult", 1.0)))
	if w.fire_mode != "auto":
		rpm = minf(rpm, float(_sk.get("semi_max_rpm", 240.0)))
	fire_cd = minf(fire_cd, 0.0) + 60.0 / rpm
	var origin: Vector3 = eye()
	var fwd: Vector3 = brain.facing()
	var basis: Basis = Basis.looking_at(fwd, Vector3.UP) if absf(fwd.y) < 0.99 else Basis.from_euler(Vector3(player.head.rotation.x, player.rotation.y, 0.0))
	if w.data.has("bell"):
		Totenglocke.bot_toll(player, w, origin, fwd)
		if w.mag <= 0 and w.reserve > 0:
			start_reload()
		return
	# aimed like a player: down the sights when standing (or walking slowly) at anything not in its face, from the
	# hip on the run or point-blank; bloom counts x (1 - 0.7 x ads), as WeaponHolder.spread_deg does
	var ads: float = ads_amount()
	var spread: float = (lerpf(w.f("spread_hip", 3.0), w.f("spread_ads", 0.5), ads) + _bloom * (1.0 - 0.7 * ads)) * float(_sk.get("spread_mult", 1.0))
	if player.horizontal_speed() > 1.0:
		spread *= float(_a.get("moving_spread_mult", 1.6))
	var pellets: int = maxi(1, int(w.data.get("pellets", 1)))
	var hits: Dictionary = {}
	var last_hit: Vector3 = origin + fwd * SHOT_RANGE
	for i: int in pellets:
		last_hit = _trace(origin, _spread_dir(basis, spread), w, hits)
	var pid: int = player.player_id
	if not hits.is_empty():
		hits_landed += 1
	var piercing: bool = bool(w.property("armor_piercing", false)) or bool(w.property("armor_ignore", false))
	var tier_mult: float = PerkManager.shot_mult(pid, ads >= 0.95)   # Trigger Tonic III / Hawkeye III (T-075)
	for z: Variant in hits.keys():
		var zz: Zombie = z as Zombie
		var h: Dictionary = hits[z]
		var limb: StringName = StringName(h["limb"])
		zz.last_hit_bone = str(h.get("bone", ""))
		var killed: bool = zz.take_damage(float(h["dmg"]) * tier_mult, limb, w.id, pid, &"bullet", piercing)
		if killed:
			PerkManager.on_bullet_kill(pid, w, limb == &"head")
		if killed and limb == &"head":
			brain.squad.callout(brain, "HEADSHOT")
			brain.bonus_event("headshot")
	_bloom = minf(_bloom + (1.0 if pellets == 1 else 0.35), 6.0)
	player.remote_fire(0, w.id, origin, last_hit)
	if player.is_local and player.weapons != null:
		player.weapons.bot_shot_fx(w, origin, last_hit, not hits.is_empty())   # T-071: the player bot's own viewmodel, sound and the co-op relay
	GLBus.mark_shot(pid, w.is_suppressed())   # a bot's suppressed M1911 stays off the minimap too
	GLBus.weapon_fired.emit(pid, w.id, w.upgraded, origin, fwd)
	if target != null:
		brain.bonus_event("fire")
	var danger: bool = brain.perception.sprinter_close or brain.perception.nearest_d < float(_r.get("near_block_m", 2.6))
	if w.mag <= 0 and w.reserve > 0 and not (danger and _other_loaded() >= 0):
		start_reload()


## The spread a shot would have now (degrees), as fire() computes it (without the random part).
func current_spread_deg(w: WeaponInstance) -> float:
	var ads: float = ads_amount()
	var spread: float = (lerpf(w.f("spread_hip", 3.0), w.f("spread_ads", 0.5), ads) + _bloom * (1.0 - 0.7 * ads)) * float(_sk.get("spread_mult", 1.0))
	if player.horizontal_speed() > 1.0:
		spread *= float(_a.get("moving_spread_mult", 1.6))
	return spread


## How far down the sights it is (0 hip .. 1 aimed): aimed standing or walking slowly at a target beyond ads_min_m.
func ads_amount() -> float:
	if player.downed or player.horizontal_speed() > float(_a.get("ads_max_speed", 2.6)):
		return 0.0
	if target != null and _flat(target.global_position, player.global_position) < float(_a.get("ads_min_m", 3.0)):
		return 0.3
	return 1.0


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
			var cur_h: Dictionary = hits.get(z, {"dmg": 0.0, "limb": "torso", "mult": 0.0})
			cur_h["dmg"] = float(cur_h["dmg"]) + dmg
			if mult > float(cur_h["mult"]):
				cur_h["mult"] = mult
				cur_h["limb"] = String(hb.limb)
				cur_h["bone"] = hb.bone
			hits[z] = cur_h
			Effects.blood(pos, -dir)
			for rid: RID in z.hitbox_rids():
				exclude.append(rid)
			if hb.limb == &"wrist" or hb.limb == &"palm":
				exclude.append(hb.get_rid())
			from = pos + dir * 0.05
		else:
			if hits.is_empty() and miss_on.size() < 24:
				var cn: String = (col as Node).name if col is Node else "?"
				miss_on[cn] = int(miss_on.get(cn, 0)) + 1
			var shootable: Node = WeaponHolder.shootable_of(col)
			if shootable != null and brain.may_touch_quest(shootable):
				# quest shootables (bells, the drummer) are egg steps: only the one this bot's egg task aims at (T-067)
				WeaponHolder.notify_shot(shootable, w.id, w.upgraded, player.player_id)
			Effects.impact(pos, res["normal"], "", col)
			break
	return last_hit


## Shooting at `to` would pass a teammate (a 0.6 m line-of-fire check).
func teammate_in_the_way(to: Vector3) -> bool:
	var from: Vector3 = eye()
	var r: float = float(_a.get("line_of_fire_radius_m", 0.6))
	for p: Player in brain.squad.all_players():
		if p == player or p.spectating or not is_instance_valid(p):
			continue
		if BotConfig.blocks_shot(from, to, p.global_position + Vector3.UP * (0.4 if p.downed else 1.0), r):
			return true
	return false


## A line of sight from the eye to the aim point right now (cached 0.1 s per target): the think's visibility is up
## to 0.2 s old and the target memory keeps a lost target 0.8 s, and the soak found 60-80% of shots hitting walls
## beside the windows (and Map 1's fences) before this check.
func _clear_shot(p: Vector3) -> bool:
	var now: float = brain.squad.time()
	if target == _clear_for and now - _clear_t < 0.1:
		return _clear_ok
	_clear_for = target
	_clear_t = now
	_clear_ok = _los(eye(), p, target)
	return _clear_ok


func _los(from: Vector3, to: Vector3, z: Object) -> bool:
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var ex: Array[RID] = [player.get_rid()]
	if z is CollisionObject3D:
		ex.append((z as CollisionObject3D).get_rid())
	for _i: int in 3:
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, MASK_LOS, ex)
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			return true
		# T-071 pass 3: a body that belongs to the target itself (a crawler's pieces) doesn't block the shot at it:
		# the soak's last-crawler stalls (the line of sight failed on every frame at every height)
		var col: Object = hit.get("collider")
		if z is Node and col is CollisionObject3D and ((z as Node) == col or (z as Node).is_ancestor_of(col as Node)):
			ex.append((col as CollisionObject3D).get_rid())
			los_self_hits += 1
			continue
		if brain.is_player_bot and z is Zombie and (z as Zombie).is_crawler and col is Node:
			los_crawler_blockers[str((col as Node).name)] = int(los_crawler_blockers.get(str((col as Node).name), 0)) + 1
		return false
	return false


## (the soak's numbers) target-owned bodies skipped by _los, and what blocked the line to a crawler (name -> rays).
var los_self_hits: int = 0
var los_crawler_blockers: Dictionary = {}


## Turns onto `p` and fires one aimed shot when on it (single shots, any fire mode). True on a shot. For the
## objectives (bells, the drummer).
func shoot_at(p: Vector3, tol_deg: float) -> bool:
	var dir: Vector3 = (p - eye()).normalized()
	brain.loco.look_at_dir(dir)
	var w: WeaponInstance = cur()
	if w == null or reloading or swap_t > 0.0:
		return false
	if w.mag <= 0:
		if w.reserve > 0:
			start_reload()
		return false
	if brain.facing().angle_to(dir) > deg_to_rad(tol_deg) or fire_cd > 0.0 or teammate_in_the_way(p):
		return false
	fire(w)
	fire_cd = maxf(fire_cd, 0.3)
	return true


# ================================================================== weapons: choice, swap, reload

## The value of holding slot `i` now (combat.json weapons, the personality's class_pref, the situation).
func slot_value(i: int) -> float:
	var w: WeaponInstance = player.weapons.slots[i]
	return weapon_value(String(w.weapon_class()), w.mag, w.reserve, w.mag_size(), situation(), _w, (_pers.get("aim", {}) as Dictionary).get("class_pref", {}), w.upgraded)


## The situation for weapon_value: {crowd: zombies within 10 m, boss: a boss near, close: nearest within close_m,
## danger: something too close to reload (a sprinter within 4 m or anything within 2.6 m)}.
func situation() -> Dictionary:
	var per: BotPerception = brain.perception
	return {"crowd": per.n10, "boss": per.boss_near != null, "close": per.nearest_d < float(_w.get("close_m", 6.0)),
		"danger": per.sprinter_close or per.nearest_d < float(_r.get("near_block_m", 2.6)),
		"near": per.nearest_d < float(_w.get("empty_swap_m", 6.0)), "weak_pistol": _weak_pistol_round()}


## T-058: from combat.json weapons.weak_pistol_after_round on, a plain pistol's magazine no longer kills one zombie
## (8 x 40 against 650+ health): swapping to it with the main gun dry only trades a reload for a pistol nobody
## needs. It is then worth weak_pistol_mult, and it doesn't count as "another loaded gun" for the swap-instead-of-
## reload rule (the bot reloads the main gun, backing off, or knifes).
func _weak_pistol_round() -> bool:
	return RoundManager.current_round > int(_w.get("weak_pistol_after_round", 99))


func _weak(w: WeaponInstance) -> bool:
	return w.weapon_class() == &"pistol" and not w.upgraded and _weak_pistol_round()


## Pure: a weapon's value for a situation. Empty magazine: x empty_mag_mult, or almost nothing while in danger
## (it can't reload now); no ammo at all: 0.
static func weapon_value(cls: String, mag: int, reserve: int, mag_size: int, sit: Dictionary, wcfg: Dictionary, class_pref: Dictionary, upgraded: bool = false) -> float:
	if mag <= 0 and reserve <= 0:
		return 0.0
	var v: float = float((wcfg.get("class_value", {}) as Dictionary).get(cls, 0.6)) * float(class_pref.get(cls, 1.0))
	if upgraded:
		v *= 1.35
	elif cls == "pistol" and bool(sit.get("weak_pistol", false)):
		v *= float(wcfg.get("weak_pistol_mult", 0.1))
	if int(sit.get("crowd", 0)) >= int(wcfg.get("crowd_n", 5)) and (wcfg.get("crowd_classes", []) as Array).has(cls):
		v *= float(wcfg.get("crowd_bonus", 1.3))
	if bool(sit.get("boss", false)) and (wcfg.get("single_classes", []) as Array).has(cls):
		v *= float(wcfg.get("single_bonus", 1.25))
	if bool(sit.get("close", false)) and (wcfg.get("close_classes", []) as Array).has(cls):
		v *= float(wcfg.get("close_bonus", 1.2))
	if mag <= 0:
		if bool(sit.get("danger", false)):
			v *= 0.05   # it can't reload now
		elif bool(sit.get("near", false)):
			v *= float(wcfg.get("empty_near_mult", 0.3))   # something within 6 m: a loaded gun beats a 3 s reload
		else:
			v *= float(wcfg.get("empty_mag_mult", 0.55))
	elif mag_size > 0 and float(mag) / float(mag_size) < 0.2 and reserve > 0 and not bool(sit.get("danger", false)):
		v *= 0.9
	return v


## The slot it should hold (the best value), and whether swapping to it now is safe: nothing within
## swap_back_safe_m, or the gun in hand is dry.
static func preferred_slot(values: Array, current: int, cur_mag: int, nearest_d: float, wcfg: Dictionary) -> int:
	var best: int = current
	var best_v: float = float(values[current]) if current >= 0 and current < values.size() else -1.0
	for i: int in values.size():
		if float(values[i]) > best_v + float(wcfg.get("swap_margin", 0.12)):
			best_v = float(values[i])
			best = i
	if best == current:
		return current
	if cur_mag <= 0 or nearest_d > float(wcfg.get("swap_back_safe_m", 3.5)) or float(values[current]) <= 0.06:
		return best
	return current


func _other_loaded() -> int:
	for i: int in player.weapons.slots.size():
		if i != player.weapons.current_index and player.weapons.slots[i].mag > 0 and not _weak(player.weapons.slots[i]):
			return i
	return -1


func _weapon_logic() -> void:
	var w: WeaponInstance = cur()
	if w == null or swap_t > 0.0:
		return
	if force_slot >= 0 and force_slot < player.weapons.slots.size():
		if force_slot != player.weapons.current_index:
			select(force_slot)
		elif w.mag == 0 and w.reserve > 0 and not reloading:
			start_reload()
		return
	var per: BotPerception = brain.perception
	var danger: bool = per.sprinter_close or per.nearest_d < float(_r.get("near_block_m", 2.6))
	# never finish a reload with a sprinter in its face when another gun is loaded: swap instead
	if reloading and danger and w.mag == 0 and _other_loaded() >= 0:
		cancel_reload()
	# the break: top every gun up
	var quiet: bool = per.known.is_empty() and brain.in_break()
	if quiet and bool(_r.get("top_up_in_break", true)):
		if w.mag < w.mag_size() and w.reserve > 0:
			if not reloading:
				start_reload()
			return
		if not reloading:
			for i: int in player.weapons.slots.size():
				var o: WeaponInstance = player.weapons.slots[i]
				if i != player.weapons.current_index and o.mag < o.mag_size() and o.reserve > 0 and _swap_cd <= 0.0:
					select(i)
					return
	if reloading:
		return
	# nothing loaded anywhere: the best gun with a reserve goes into the hands and gets reloaded, danger or not
	# (the swap-instead rule only holds while another gun is loaded; standing there dry helps nobody)
	if w.mag == 0 and _other_loaded() < 0:
		var best_i: int = -1
		var best_v: float = 0.0
		for i3: int in player.weapons.slots.size():
			var o3: WeaponInstance = player.weapons.slots[i3]
			if o3.reserve <= 0:
				continue
			var v3: float = float((_w.get("class_value", {}) as Dictionary).get(String(o3.weapon_class()), 0.6)) 				* float(((_pers.get("aim", {}) as Dictionary).get("class_pref", {}) as Dictionary).get(String(o3.weapon_class()), 1.0))
			if v3 > best_v:
				best_v = v3
				best_i = i3
		if best_i >= 0 and best_i != player.weapons.current_index:
			select(best_i)
		elif best_i >= 0:
			start_reload()
		return
	var vals: Array = []
	for i2: int in player.weapons.slots.size():
		vals.append(slot_value(i2))
	var pref: int = preferred_slot(vals, player.weapons.current_index, w.mag, per.nearest_d, _w)
	if pref != player.weapons.current_index and (_swap_cd <= 0.0 or w.mag <= 0):
		select(pref)
		return
	if w.mag == 0 and w.reserve > 0 and not danger:
		start_reload()
	elif w.reserve > 0 and float(w.mag) / float(maxi(1, w.mag_size())) < float(_r.get("low_frac", 0.3)) 			and per.pressure < float(_r.get("low_pressure", 0.25)) and per.nearest_d > float(_r.get("near_block_m", 2.6)) * 2.5:
		start_reload()   # reload intelligence: under 30% with low pressure and nothing close
	elif w.mag == 0 and w.reserve == 0:
		brain.squad.callout(brain, "AMMO_NONE")


func select(i: int) -> void:
	if i < 0 or i >= player.weapons.slots.size() or i == player.weapons.current_index:
		return
	cancel_reload()
	player.weapons.current_index = i
	brain.bonus_event("swap")
	swap_t = SWAP_TIME
	_swap_cd = float(_w.get("swap_cooldown_s", 1.2))
	_burst_t = 0.0
	AudioDirector.play_3d("weapon_raise", eye(), -10.0)
	if player.remote_body != null:
		var w: WeaponInstance = player.weapons.current()
		player.remote_body.set_weapon(w.id if w != null else &"")


## A reload the "Reload safely" action asks for (the mag isn't empty).
func reload_now() -> void:
	start_reload()


func needs_reload() -> bool:
	var w: WeaponInstance = cur()
	return w != null and w.reserve > 0 and w.mag < w.mag_size()


func _reload_mult(w: WeaponInstance) -> float:
	return float(PerkManager.stat(player.player_id, "reload_time_mult", 1.0)) * float(w.property("reload_mult", 1.0))


func start_reload() -> void:
	var w: WeaponInstance = cur()
	if w == null or reloading or w.reserve <= 0 or w.mag >= w.mag_size():
		return
	reloading = true
	_burst_t = 0.0
	PerkManager.overclock_reload(player, PerkManager.overclock_spent(w.mag, w.mag_size()))
	var mult: float = _reload_mult(w)
	if bool(w.data.get("per_round_reload", false)) and not (w.mag == 0 and w.weapon_class() == &"bolt"):
		_reload_per_round = true
		_reload_t = w.f("reload_partial", 0.5) * mult
	else:
		_reload_per_round = false
		_reload_t = (w.f("reload_empty", 2.5) if w.mag == 0 else w.f("reload_partial", 2.0)) * mult
	AudioDirector.play_3d("reload_start", eye(), -9.0)
	if brain.perception.nearest_d < 12.0 and w.weapon_class() != &"pistol":
		brain.squad.callout(brain, "RELOAD")
	brain.bonus_event("reload")


func cancel_reload() -> void:
	reloading = false
	_reload_per_round = false


func _tick_reload(delta: float) -> void:
	if not reloading:
		return
	var w: WeaponInstance = cur()
	if w == null:
		cancel_reload()
		return
	_reload_t -= delta
	if _reload_t > 0.0:
		return
	if _reload_per_round:
		var add: int = mini(1, w.reserve)
		w.mag += add
		w.reserve -= add
		if w.mag < w.mag_size() and w.reserve > 0 and not (brain.perception.nearest_d < 2.5 and w.mag > 0):
			_reload_t = w.f("reload_partial", 0.5) * _reload_mult(w)
			return
	else:
		var take: int = mini(w.mag_size() - w.mag, w.reserve)
		w.mag += take
		w.reserve -= take
	reloading = false
	_reload_per_round = false
	PerkManager.reload_finished(player.player_id)
	AudioDirector.play_3d("reload_end", eye(), -9.0)



# ================================================================== the knife

## Knife rules (combat.json melee): crawlers in reach; a lone zombie early on; anything in reach when dry.
## Never a boss.
func _try_melee_target() -> void:
	var per: BotPerception = brain.perception
	var z: Zombie = per.nearest
	if z == null or melee_cd > 0.0:
		return
	var reach: float = float(_m.get("range_m", 1.7))
	if per.nearest_d > reach:
		return
	if bool(BotAIData.counter(z.enemy_id).get("never_melee", false)) or BotPerception.is_boss(z):
		return
	if brain.crawler != null and brain.crawler.target == z:
		return   # (the crawler break's zombie: legs, not the knife)
	var w: WeaponInstance = cur()
	var dry: bool = w == null or w.mag <= 0 or reloading
	var lone: bool = RoundManager.current_round <= int(_m.get("early_round_max", 5)) and per.count_near(player.global_position, float(_m.get("lone_radius_m", 6.0))) <= 1
	var pc: Dictionary = _pers.get("combat", {})
	# T-058: a swing cancels the reload. Dry with something in reach, it only knifes what the knife kills (a
	# 150-damage stab doesn't stop a 650-health zombie, and a bot that knifed and restarted its reload every swing
	# never reloaded at all); otherwise it finishes the reload while the executor backs it off.
	if dry and not knife_kills(z) and not z.is_crawler:
		return
	if z.is_crawler or dry or lone or (bool(pc.get("melee_lone", false)) and per.n5 <= 1) or (z == target and knife_for_points() == z):
		melee(z)


## True when one knife swing kills `z` (its health left against the knife's damage, Dutch's trait included).
func knife_kills(z: Zombie) -> bool:
	var md: Dictionary = (GLData.table("weapons")["melee"] as Dictionary).get(String(player.weapons.melee_id), {})
	var dmg: float = float(md.get("damage", 150.0))
	if GameState.player_has_trait(player.player_id, &"dutch"):
		dmg *= float(GLData.table("player")["traits"]["dutch_melee_mult"])
	return z != null and z.hp <= dmg


## Melee with no firearm (Jakub's coal shovel): any non-boss in reach.
func melee_unarmed() -> void:
	var per: BotPerception = brain.perception
	var z: Zombie = per.nearest
	if z == null or melee_cd > 0.0 or per.nearest_d > float(_m.get("range_m", 1.7)) + 0.2:
		return
	if BotPerception.is_boss(z):
		return
	melee(z)


## A knife swing at `z` (the same rules as WeaponHolder._melee_strike, no lunge).
func melee(z: Zombie) -> bool:
	var md: Dictionary = (GLData.table("weapons")["melee"] as Dictionary).get(String(player.weapons.melee_id), {})
	if md.is_empty():
		return false
	melee_cd = float(md.get("swing", 0.55)) + 0.25
	cancel_reload()
	var dmg: float = float(md.get("damage", 150.0))
	if GameState.player_has_trait(player.player_id, &"dutch"):
		dmg *= float(GLData.table("player")["traits"]["dutch_melee_mult"])
	var fwd: Vector3 = (z.global_position - player.global_position)
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else -player.global_basis.z
	brain.loco.look_at_dir(fwd)
	player.remote_fire(3, player.weapons.melee_id, eye(), eye() + fwd)
	var hit: int = 0
	for zz: Zombie in brain.perception.known_nodes():
		if _flat(zz.global_position, player.global_position) <= float(md.get("reach", 2.0)) + 0.4 and absf(zz.global_position.y - player.global_position.y) < 1.6:
			if BotPerception.is_boss(zz):
				continue
			zz.take_damage(dmg, &"torso", player.weapons.melee_id, player.player_id, &"melee")
			Effects.blood(zz.global_position + Vector3.UP * 1.2, fwd)
			hit += 1
			if hit >= int(md.get("targets", 1)):
				break
	if hit > 0:
		AudioDirector.play_3d("knife_hit", eye(), -4.0)
	return true


# ================================================================== grenades

## Frags only into a group (min_group, scaled by the personality's grenade_bias) clear of teammates, or on a boss.
func _maybe_grenade() -> void:
	if _grenade_cd > 0.0 or player.weapons == null or player.weapons.grenades <= int(_g.get("keep", 1)) - 1 or player.downed:
		return
	if brain.personality_combat("grenade_bias", 1.0) <= 0.0:
		return
	var per: BotPerception = brain.perception
	var spot: Vector3 = grenade_spot(per.known, player.global_position, _teammate_positions(), _g, brain.personality_combat("grenade_bias", 1.0))
	if spot == Vector3.INF:
		return
	if not _los(eye(), spot + Vector3.UP * 0.6, null):
		return
	_grenade_cd = float(_g.get("cooldown_s", 6.0))
	throw_grenade(spot)


func _teammate_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p: Player in brain.squad.all_players():
		if p != player and not p.spectating and is_instance_valid(p):
			out.append(p.global_position)
	return out


## Pure: where to throw a frag ({} known entries {node, pos}), or INF. A point min..max away with min_group known
## zombies within group_radius (fewer with a high grenade_bias), no teammate within teammate_clear_m; a boss
## counts as a group on its own.
static func grenade_spot(known: Array, me: Vector3, mates: Array[Vector3], g: Dictionary, bias: float) -> Vector3:
	var need: int = maxi(3, int(round(float(g.get("min_group", 4)) / maxf(0.5, bias))))
	var r: float = float(g.get("group_radius_m", 3.0))
	var best: Vector3 = Vector3.INF
	var best_n: int = 0
	for e: Variant in known:
		var ed: Dictionary = e
		var p: Vector3 = ed["pos"]
		var d: float = Vector2(p.x - me.x, p.z - me.z).length()
		if d < float(g.get("min_dist_m", 7.0)) or d > float(g.get("max_dist_m", 20.0)):
			continue
		var n: int = 0
		var c: Vector3 = Vector3.ZERO
		for e2: Variant in known:
			var p2: Vector3 = (e2 as Dictionary)["pos"]
			if p2.distance_to(p) <= r:
				n += 1
				c += p2
		c /= float(maxi(1, n))
		var z: Object = ed.get("node")
		var boss: bool = bool(ed.get("boss", false)) and z is Zombie and bool(BotAIData.counter((z as Zombie).enemy_id).get("explosives", false))
		if n < need and not boss:
			continue
		var clear: bool = true
		for m: Vector3 in mates:
			if Vector2(m.x - c.x, m.z - c.z).length() < float(g.get("teammate_clear_m", 6.0)):
				clear = false
		if not clear:
			continue
		var score: int = n + (10 if boss else 0)
		if score > best_n:
			best_n = score
			best = c
	return best


func throw_grenade(at: Vector3) -> void:
	var h: WeaponHolder = player.weapons
	var cfg: Dictionary = GLData.table("weapons")["lethal"]["frag"]
	h.grenades -= 1
	grenades_thrown += 1
	var skill: float = float(_sk.get("grenade_skill", 0.75))
	var miss: float = (1.0 - skill) * 3.0
	var aim: Vector3 = at + Vector3(_rng.randfn(0.0, miss), 0.0, _rng.randfn(0.0, miss))
	var g: Grenade = Grenade.new()
	var from: Vector3 = eye() + brain.facing() * 0.5
	var v: Vector3 = _ballistic(from, aim, 13.0)
	var flat_v: float = Vector2(v.x, v.z).length()
	var t_flight: float = Vector2(aim.x - from.x, aim.z - from.z).length() / maxf(1.0, flat_v)
	g.fuse = clampf(t_flight + 0.35, 0.6, float(cfg["fuse"]))
	g.cfg = cfg
	g.by_player = player.player_id
	player.get_parent().add_child(g)
	g.global_position = from
	g.linear_velocity = v
	g.add_collision_exception_with(player)
	player.remote_fire(4, &"frag", from, from + v.normalized())
	AudioDirector.play_3d("grenade_pin", eye(), -6.0)


## A launch velocity that lands at `to` from `from` with a flat speed of about `speed` (project gravity).
static func _ballistic(from: Vector3, to: Vector3, speed: float) -> Vector3:
	var g: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var flat: Vector3 = Vector3(to.x - from.x, 0.0, to.z - from.z)
	var d: float = flat.length()
	if d < 0.1:
		return Vector3.UP * 2.0
	var t: float = clampf(d / speed, 0.35, 2.0)
	var vy: float = ((to.y - from.y) + 0.5 * g * t * t) / t
	return flat / t + Vector3.UP * vy


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
