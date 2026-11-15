class_name BotActions
extends RefCounted
## The utility actions' executors (Update 03 section 1): what a bot does each physics frame for the action the
## utility AI picked (bot_utility.gd, data/gravelight/ai/actions.json). Each executor tells the locomotion layer
## where to go (move_to / follow / hold / train / stop) and the aim layer whether it may fire; task actions (Buy,
## Repair, Crate, Trap, Order, Objective) hand their errand to BotTasks; the easter-egg task (ee_task, T-067) runs in BotEE. Movement HOW is the locomotion layer's;
## this decides WHAT.

var brain: BotBrain
var player: Player
var _c: Dictionary = {}
var _retreat_t: float = 0.0
var _retreat_p: Vector3 = Vector3.INF
var _retreat_since: float = 0.0
var _cornered_t: float = 0.0
var _back_p: Vector3 = Vector3.INF
var _no_hold_until: float = -1.0
var _back_until: float = -1.0
var _flank_p: Vector3 = Vector3.INF
var _flank_t: float = 0.0
var _hg_p: Vector3 = Vector3.INF
var _hg_t: float = 0.0
## Soak counters: flank spots taken (Peg), high-ground moves (Wren).
var flanks: int = 0
var high_ground_moves: int = 0
var _fight_back_t: float = 0.0
var _revive_hold: float = 0.0
var _reviving_pid: int = 0
var _prep_done: bool = false
var _cover_said: bool = false
var _chatter_done: bool = false
var _powerup_t: float = 0.0
var _task_retry: float = 0.0


func setup(b: BotBrain) -> void:
	brain = b
	player = b.player
	_c = BotAIData.table("combat")


func cfg(section: String) -> Dictionary:
	return _c.get(section, {})


## Entering an action: set up its task, claims and lines.
func enter(id: String) -> void:
	match id:
		"retreat":
			_retreat_t = 0.0
			_retreat_since = brain.squad.time()
		"revive":
			_prep_done = false
		"cover":
			_cover_said = false
		"chatter":
			_chatter_done = false
		"powerup":
			_powerup_t = 0.0
		"buy", "repair", "crate", "resupply", "trap", "order", "objective":
			brain.start_task(id)
		"ee_task", "mark_order":
			if not brain.task.is_empty():
				brain.drop_task()
		"lead_train":
			if brain.trainer != null:
				brain.trainer.enter()


## Leaving an action: let go of what it held.
func exit(id: String) -> void:
	match id:
		"revive":
			stop_revive()
		"hold":
			brain.release_hold_claim()
		"buy", "repair", "crate", "resupply", "trap", "order", "objective":
			if not brain.task.is_empty():
				brain.drop_task()
		"ee_task":
			if brain.ee != null:
				brain.ee.on_exit()
		"mark_order":
			if brain.mark != null:
				brain.mark.on_exit()
		"lead_train":
			if brain.trainer != null:
				brain.trainer.exit()
		"setpiece":
			if brain.setpieces != null:
				brain.setpieces.on_exit()


func run(id: String, delta: float) -> void:
	match id:
		"fight":
			_fight(delta)
		"train":
			_train(delta)
		"lead_train":
			if brain.trainer != null:
				brain.trainer.run(delta)   # T-071: the player bot trains the horde round the map's loop
			else:
				_idle(delta)
		"hold":
			_hold(delta)
		"retreat":
			_retreat(delta)
		"reload":
			_reload(delta)
		"revive":
			_revive(delta)
		"cover":
			_cover(delta)
		"buy", "repair", "crate", "resupply", "trap", "order", "objective":
			_task(id, delta)
		"powerup":
			_powerup(delta)
		"ee_task":
			if brain.ee != null:
				brain.ee.run(delta)
			else:
				_idle(delta)
		"mark_order":
			if brain.mark != null:
				brain.mark.run(delta)
			else:
				_idle(delta)
		"follow":
			_follow(delta)
		"regroup":
			_regroup(delta)
		"escort":
			_escort(delta)
		"chatter":
			_chatter(delta)
		"setpiece":
			if brain.setpieces != null:
				brain.setpieces.run(delta)   # U10 (T-163): Fernflug's set-pieces
			else:
				_idle(delta)
		_:
			_idle(delta)


# ================================================================== combat

## Stands its ground and shoots: keeps up with a leader on the move (shooting on the move), backs off what gets
## inside the backpedal radius (unless it means to knife it), keeps its personality's distance.
func _fight(delta: float) -> void:
	var per: BotPerception = brain.perception
	if not brain.armed():
		_unarmed(delta)
		return
	if not brain.aim.update(delta, true):
		brain.idle_look(delta)
	var leader: Player = brain.squad.leader_for(brain)
	var back_r: float = backpedal_radius(per.nearest.speed if per.nearest != null else 0.0, cfg("fight"), float(BotConfig.cfg().get("combat", {}).get("backpedal_radius_m", 2.6)))
	var keep: float = brain.personality_combat("keep_distance_m", 4.0)
	var stand: bool = brain.stand_fast() or brain.nearest_holds_ground()
	if stand:
		back_r = 0.0   # T-058: backing away from a Bellringer only turns its lunge into a chase
	if per.nearest != null and BotPerception.is_boss(per.nearest):
		# T-058: a boss's keep-away ring (ai_counters keep_distance_m: Alix's Holding Hand reaches 2 m) is backed out
		# of with a margin even on foot, not only avoided by paths
		back_r = maxf(back_r, float(BotAIData.counter(per.nearest.enemy_id).get("keep_distance_m", 0.0)) + float(cfg("fight").get("boss_margin_m", 0.8)))
	var mate: Player = brain.squad.nearest_standing(player, player.global_position) if stand else null
	var kp: Zombie = brain.aim.knife_for_points() if brain.is_player_bot else null
	if kp != null:
		# T-071 pass 3: knifing for the Scrip: step up to it (the knife reaches 1.7 m, its swing 1.5 m)
		if per.nearest_d > 1.45:
			brain.loco.move_to(kp.global_position, 0.45, 1.3)
		else:
			brain.loco.stop()
		return
	if per.nearest != null and per.nearest_d < back_r and not (per.nearest.is_crawler and brain.personality_combat("melee_crawlers", false)):
		_back_off(per.nearest, 2.6, 0.6)
	elif mate != null and _flat(mate.global_position, player.global_position) > float(cfg("fight").get("stack_m", 3.0)) and per.nearest_d > 2.5:
		brain.loco.move_to(mate.global_position, 0.55, float(cfg("fight").get("stack_m", 3.0)) * 0.6)   # back to back with a teammate
	elif brain.order_id() == &"hold" and brain.squad.hold_point != Vector3.INF:
		brain.loco.hold(brain.squad.hold_spot(brain))
	elif _flank():
		pass
	elif _spread_from_boss():
		pass
	elif not brain.roaming() and leader != null and leader != player and (brain.leader_moving(leader) or _flat(leader.global_position, player.global_position) > 8.0):
		brain.loco.follow(leader, brain.index)
	elif not stand and per.nearest != null and per.nearest_d < keep * 0.6 and brain.aim.target != null:
		_back_off(per.nearest, 1.8, 0.4)
	elif _high_ground():
		pass
	else:
		brain.loco.stop()


## Peg (personality combat.flank, T-058): on a boss or a special she doesn't stand behind the squad's guns but
## moves round to its flank: keep_distance_m from it, 60-90 degrees off the line from the squad to it, on her
## side, a reachable spot with a line of sight and no danger zone. Re-planned every 1.5 s. True while it moves.
func _flank() -> bool:
	if not bool(brain.personality_combat("flank", false)):
		return false
	var z: Zombie = brain.aim.target
	if z == null or not is_instance_valid(z) or not (BotPerception.is_boss(z) or float(BotAIData.counter(z.enemy_id).get("priority", 1.0)) >= 1.3):
		_flank_p = Vector3.INF
		return false
	var now: float = brain.squad.time()
	if now >= _flank_t:
		_flank_t = now + 1.5
		_flank_p = flank_point(z.global_position, _squad_ref(), player.global_position, float(brain.personality_combat("keep_distance_m", 7.0)))
		if _flank_p != Vector3.INF:
			var s2: Vector3 = brain.snap(_flank_p)
			if s2.distance_to(_flank_p) > 1.5 or absf(s2.y - player.global_position.y) > 1.5 or brain.in_danger(s2) 					or not brain.los_point(s2 + Vector3.UP * 1.5, z.global_position + Vector3.UP * 1.2) or brain.loco.path_length_to(s2) > 18.0:
				_flank_p = Vector3.INF
			else:
				_flank_p = s2
				flanks += 1
	if _flank_p == Vector3.INF or _flat(_flank_p, player.global_position) < 0.8:
		return false
	brain.loco.move_to(_flank_p, 0.5, 0.6)
	return true


## Pure: the flank spot on a target at `t` for a shooter at `me`, seen from the squad at `ref`: `dist` from the
## target, 70 degrees round from the squad's line toward the shooter's side. INF when the squad stands on it.
static func flank_point(t: Vector3, ref: Vector3, me: Vector3, dist: float) -> Vector3:
	var line: Vector3 = Vector3(ref.x - t.x, 0.0, ref.z - t.z)
	if line.length() < 0.5:
		return Vector3.INF
	line = line.normalized()
	var side: float = 1.0 if line.cross(Vector3.UP).dot(Vector3(me.x - t.x, 0.0, me.z - t.z)) >= 0.0 else -1.0
	var dir: Vector3 = line.rotated(Vector3.UP, -side * deg_to_rad(70.0))
	return t + dir * dist


## Where the squad's guns stand: the leader (if not itself), else the nearest standing teammate, else itself.
func _squad_ref() -> Vector3:
	var leader: Player = brain.squad.leader_for(brain)
	if leader != null and leader != player:
		return leader.global_position
	var mate: Player = brain.squad.nearest_standing(player, player.global_position)
	return mate.global_position if mate != null else player.global_position


## Wren (personality combat.high_ground, T-058): with the fight within a map high-ground spot's watch range
## (routes_<map>.json high_ground) and the squad near it, she fights from up there. Checked every 2 s. True while
## it moves there.
func _high_ground() -> bool:
	if not bool(brain.personality_combat("high_ground", false)) or brain.squad.map == null:
		return false
	var now: float = brain.squad.time()
	if now >= _hg_t:
		_hg_t = now + 2.0
		_hg_p = Vector3.INF
		var z: Zombie = brain.aim.target
		var focus: Vector3 = z.global_position if z != null and is_instance_valid(z) else player.global_position
		var ref: Vector3 = _squad_ref()
		var best_d: float = 14.0
		for h: Dictionary in TrainingRoute.high_ground_for(String(brain.squad.map.map_id)):
			var hp: Vector3 = h["pos"]
			var d: float = _flat(hp, player.global_position)
			if d > best_d or _flat(hp, focus) > float(h["watch_m"]) or _flat(hp, ref) > 14.0:
				continue
			if brain.perception.count_near(hp, 4.0) > 0 or brain.in_danger(hp):
				continue
			if brain.perception.boss_near != null and _flat(brain.perception.boss_near.global_position, hp) < 20.0:
				continue   # (a boss about: the Reach drops into the hayloft; no perch near a boss)
			var sp: Vector3 = brain.snap(hp)
			if sp.distance_to(hp) > 1.0 or brain.loco.path_length_to(sp) > 24.0:
				continue
			best_d = d
			_hg_p = sp
		if _hg_p != Vector3.INF:
			high_ground_moves += 1
	if _hg_p == Vector3.INF or (_flat(_hg_p, player.global_position) < 0.8 and absf(_hg_p.y - player.global_position.y) < 1.0):
		return false
	brain.loco.move_to(_hg_p, 0.5, 0.6)
	return true


## Bosses in general (ai_counters spread_out): never all in one cone. With a boss in sight and a teammate within
## spread_m, it sidesteps across the boss's line, away from that teammate.
func _spread_from_boss() -> bool:
	var per: BotPerception = brain.perception
	var boss: Zombie = per.boss_near
	if boss == null or not per.is_visible(boss):
		return false
	var c: Dictionary = BotAIData.counter(boss.enemy_id)
	var spread: float = float(c.get("spread_m", 0.0))
	if not bool(c.get("spread_out", false)) or spread <= 0.0:
		return false
	var mate: Player = brain.squad.nearest_standing(player, player.global_position)
	if mate == null or _flat(mate.global_position, player.global_position) >= spread:
		return false
	var to_boss: Vector3 = boss.global_position - player.global_position
	to_boss.y = 0.0
	var side: Vector3 = Vector3(-to_boss.z, 0.0, to_boss.x).normalized()
	if side.dot(player.global_position - mate.global_position) < 0.0:
		side = -side
	var p: Vector3 = brain.step_spot(player.global_position + side * 2.5)
	if p == Vector3.INF or brain.in_danger(p) or p.distance_to(player.global_position) < 0.8:
		return false
	brain.loco.move_to(p, 0.5, 0.5)
	return true


## No firearm (Jakub with the coal shovel): stay with the escort, swing at what reaches it.
func _unarmed(delta: float) -> void:
	brain.aim.melee_unarmed()
	var esc: Player = brain.escort_target()
	if esc != null and _flat(esc.global_position, player.global_position) > 3.0:
		brain.loco.follow(esc, 0)
	else:
		var per: BotPerception = brain.perception
		if per.nearest != null and per.nearest_d < 3.0 and not per.nearest.is_crawler:
			_back_off(per.nearest, 2.0, 0.5)
		else:
			brain.loco.stop()
	brain.idle_look(delta)


## T-058: how close a zombie may come before the bot backs off while it shoots: a zombie's reach (1.5 m) plus
## what it closes in the bot's reaction, so a runner is backed away from earlier than a walker (combat.json fight).
static func backpedal_radius(speed: float, fc: Dictionary, fallback: float) -> float:
	if fc.is_empty():
		return fallback
	return clampf(float(fc.get("backpedal_base_m", 1.7)) + speed * float(fc.get("backpedal_per_speed_s", 0.55)),
		float(fc.get("backpedal_min_m", 2.6)), float(fc.get("backpedal_max_m", 4.4)))


## Backs away from `z` by `dist` while it shoots: straight away, else (a wall, a trap behind it) the clearest of a
## few angles off that line, never toward another known zombie (T-058: the straight-back spot used to snap into
## the wall it stood against, so a bot in a corner "backed off" on the spot).
func _back_off(z: Zombie, dist: float, urgency: float) -> void:
	var me: Vector3 = player.global_position
	var now: float = brain.squad.time()
	if now < _back_until and _back_p != Vector3.INF and _flat(_back_p, me) > 0.5:
		brain.loco.move_to(_back_p, urgency, 0.4)   # re-planned 4x a second (navmesh snaps aren't free)
		return
	_back_until = now + 0.25
	var away: Vector3 = me - z.global_position
	away.y = 0.0
	if away.length() < 0.01:
		away = -player.global_basis.z
	away = away.normalized()
	var best: Vector3 = Vector3.INF
	var best_s: float = -INF
	for a: float in [0.0, 0.6, -0.6, 1.2, -1.2, 1.8, -1.8]:
		var dir: Vector3 = away.rotated(Vector3.UP, a)
		var p: Vector3 = brain.snap(me + dir * dist)
		var got: float = _flat(p, me)
		if got < dist * 0.45 or absf(p.y - me.y) > 1.2 or brain.in_danger(p):
			continue
		if not brain.walkable_from(me, p):
			continue   # (the far side of a wall or a fence: see BotBrain.walkable_from)
		var clear: float = 9.0
		for e: Variant in brain.perception.known:
			clear = minf(clear, _flat((e as Dictionary)["pos"], p))
		var sc: float = got + clear * 0.8 - absf(a) * 0.6
		if sc > best_s:
			best_s = sc
			best = p
		if a == 0.0 and got >= dist * 0.8 and clear > 2.0:
			break   # straight back is open: take it
	if best == Vector3.INF:
		# nowhere to step back to (a corner, a fence behind): stand and shoot rather than walk at a wall
		_back_p = Vector3.INF
		brain.loco.stop()
		return
	_back_p = best
	brain.loco.move_to(best, urgency, 0.4)


## Trains the horde: with the human leading on the move, the moving formation beside them (training with the
## player); otherwise the squad's route (the locomotion layer's TrainingRoute, or the free loop round the
## leader). Turns to fire at the train's head.
func _train(delta: float) -> void:
	var leader: Player = brain.squad.leader_for(brain)
	var human: Player = brain.squad.human()
	if leader == human and leader != null and leader != player and brain.leader_moving(leader):
		brain.loco.follow(leader, brain.index)
	else:
		brain.loco.train(brain.squad.blackboard.route)
	var urg: Variant = brain.loco.get("_t_urg")
	if urg != null and float(urg) >= 0.6 and ((player.sprinting and player.horizontal_speed() > 2.5) or brain.perception.nearest_d > 2.2):
		return   # the layer is sprinting ahead of the train's head: no look, so it can run
	# (T-058: out of stamina or boxed in with the head in reach, it turns and shoots instead of standing there)
	var per: BotPerception = brain.perception
	if urg == null and per.nearest != null and per.nearest_d < 2.2 and per.nearest.speed >= 3.0 and not per.nearest.is_crawler and player.hp < player.max_hp * 0.6:
		return   # (the v1 adapter) hurt with the train's head on its heels: just run
	if not brain.aim.update(delta, true):
		var f: Vector3 = brain.loco.train_face_dir()
		if f != Vector3.ZERO:
			brain.loco.look_at_dir(f)


## Holds a spot: the Hold order's ring, or its window pair in the early rounds (shoots from there; Repair takes
## over between kills).
func _hold(delta: float) -> void:
	var spot: Dictionary = brain.hold_spot()
	if spot.is_empty():
		brain.loco.stop()
	else:
		brain.loco.hold(spot["pos"], spot.get("facing", Vector3.ZERO))
	var per: BotPerception = brain.perception
	if per.nearest != null and per.nearest_d < 2.2 and not per.nearest.is_crawler:
		_back_off(per.nearest, 2.0, 0.5)
	if not brain.aim.update(delta, true):
		if not spot.is_empty() and spot.get("facing", Vector3.ZERO) != Vector3.ZERO:
			brain.loco.look_at_dir(spot["facing"])
		else:
			brain.idle_look(delta)


## Kites to open ground away from the crowd (toward the squad when it can), shooting on the move.
func _retreat(delta: float) -> void:
	_retreat_t -= delta
	if _retreat_t <= 0.0 or _retreat_p == Vector3.INF or brain.loco.arrived() or brain.loco.no_way():
		_retreat_t = 0.5
		_retreat_p = retreat_point()
	var per: BotPerception = brain.perception
	var rc: Dictionary = cfg("retreat")
	# something faster than a walk on its heels: sprint clear first (no shooting at a run). Slower ones (joggers,
	# walkers) are out-walked while shooting (T-058: joggers used to trigger the sprint, so a bot kiting a crowd of
	# joggers never fired). Cornered (still in reach after sprint_cornered_s of sprinting): turn and shoot.
	var close: bool = per.nearest != null and per.nearest_d < float(rc.get("sprint_within_m", 3.2)) and per.nearest.speed >= float(rc.get("sprint_from_speed", 4.2)) 		and not brain.nearest_holds_ground()   # (nobody outruns a Bellringer: walk and shoot)
	_fight_back_t -= delta
	if close and (per.nearest_d < float(rc.get("cornered_m", 1.6)) or player.horizontal_speed() < 1.5):
		_cornered_t += delta   # (in reach, or not getting anywhere: boxed in)
		if _cornered_t > float(rc.get("sprint_cornered_s", 0.8)):
			_fight_back_t = float(rc.get("fight_back_s", 1.5))
			_cornered_t = 0.0
	else:
		_cornered_t = 0.0
	if _fight_back_t > 0.0:
		close = false
	if _retreat_p == Vector3.INF:
		brain.loco.stop()
	else:
		brain.loco.move_to(_retreat_p, 1.0 if close else 0.6, 0.5)
	if close and _retreat_p != Vector3.INF:
		return
	if not brain.aim.update(delta, true):
		brain.idle_look(delta)
	var w: WeaponInstance = brain.aim.cur()
	if w != null and w.mag == 0 and brain.perception.nearest_d > 3.5 and not brain.aim.reloading:
		brain.aim.start_reload()


## Open ground away from the known zombies' centroid, toward the leader, by a spot nothing stands near
## (combat.json retreat); INF when there's nowhere.
func retreat_point() -> Vector3:
	var rc: Dictionary = cfg("retreat")
	var me: Vector3 = player.global_position
	var per: BotPerception = brain.perception
	var centroid: Vector3 = Vector3.ZERO
	var n: int = 0
	var zs: Array[Vector3] = []
	for e: Variant in per.known:
		var zp: Vector3 = (e as Dictionary)["pos"]
		zs.append(zp)
		if _flat(zp, me) < 9.0:
			centroid += zp
			n += 1
	if n == 0:
		return Vector3.INF
	centroid /= float(n)
	var away: Vector3 = me - centroid
	away.y = 0.0
	away = away.normalized() if away.length() > 0.05 else Vector3.FORWARD
	var leader: Player = brain.squad.leader_for(brain)
	var best: Vector3 = Vector3.INF
	var ranked: Array = []
	var k_n: int = int(rc.get("samples", 12))
	for k: int in k_n:
		var a: float = float(k) / float(k_n) * TAU + randf() * 0.3
		var dir: Vector3 = Vector3(cos(a), 0.0, sin(a))
		var want: Vector3 = me + dir * randf_range(float(rc.get("min_m", 4.0)), float(rc.get("max_m", 7.0)))
		var p: Vector3 = brain.snap(want)
		if p.distance_to(want) > 1.5 or absf(p.y - me.y) > 1.6 or brain.in_danger(p):
			continue
		var clear: float = INF
		for zp2: Vector3 in zs:
			clear = minf(clear, _flat(zp2, p))
		if clear < float(rc.get("min_clear_m", 2.0)):
			continue
		var s: float = minf(clear, 9.0) * 1.5 + dir.dot(away) * 3.0
		if leader != null and leader != player:
			s -= _flat(leader.global_position, p) * 0.15
		if not brain.squad.choke_at(p).is_empty():
			s -= 2.0
		# U10 (T-163, Q-19): a spot with a wall right behind it is a dead end (the Kranich's hull: the bots backed
		# into the bay's and the galley's walls and went down there): the navmesh must go on past it
		var probe: float = float(rc.get("escape_probe_m", 0.0))
		if probe > 0.0:
			var beyond: Vector3 = p + dir * probe
			var bq: Vector3 = brain.snap(beyond)
			if bq.distance_to(beyond) > 1.2 or absf(bq.y - p.y) > 1.2:
				s -= float(rc.get("dead_end_cost", 4.0))
		ranked.append([s, p])
	# bot AI pass 2026-11: the best-scoring spot the bot can actually step to. The emptiest spot of all is the one
	# behind a wall or the yard fence (no zombie is ever there), and `snap` offered it gladly: the bot stood at the
	# wall with no path, reloading, until it went down
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	for r: Array in ranked:
		if brain.walkable_from(me, r[1]):
			best = r[1]
			break
	if best == Vector3.INF:
		var fb: Vector3 = brain.step_spot(me + away * 2.5)
		return fb if fb != Vector3.INF and fb.distance_to(me) > 0.8 else Vector3.INF
	return best


## Reload safely: steps behind the nearest teammate (or away from the threat), reloads, keeps an eye on it.
func _reload(delta: float) -> void:
	var per: BotPerception = brain.perception
	if not brain.aim.reloading and brain.aim.needs_reload():
		brain.aim.reload_now()
	var mate: Player = brain.squad.nearest_standing(player, player.global_position)
	if per.nearest != null and per.nearest_d < 7.0:
		if mate != null and _flat(mate.global_position, player.global_position) < 10.0:
			var behind: Vector3 = brain.snap(mate.global_position + (mate.global_position - per.pos_of(per.nearest)).normalized() * 1.8)
			if absf(behind.y - mate.global_position.y) < 1.2 and not BotLocomotion.walled(player, mate.global_position, behind):
				brain.loco.move_to(behind, 0.5, 0.8)
			else:
				_back_off(per.nearest, 3.0, 0.5)   # (the spot behind the mate is through a wall: just step back)
		else:
			_back_off(per.nearest, 3.0, 0.5)
	else:
		var leader: Player = brain.squad.leader_for(brain)
		if leader != null and leader != player:
			brain.loco.follow(leader, brain.index)
		else:
			brain.loco.stop()
	if per.nearest != null:
		brain.loco.look_at_dir(per.pos_of(per.nearest) + Vector3.UP * 1.2 - brain.aim.eye())
	else:
		brain.idle_look(delta)


# ================================================================== teamwork

## Goes to its claimed downed teammate and brings them back: a Bell Dome or the gramophone first when it is hot
## there, then the hold (coop.set_reviver), stopping only for something in knife reach while the bleed-out clock
## has time. Second Wind shortens the hold (CoopState.revive_seconds).
func _revive(delta: float) -> void:
	var rc: Dictionary = cfg("revive")
	var t: Player = brain.squad.player_by_id(brain.revive_pid)
	var session: NetMatch = Net.session
	if t == null or session == null or not session.coop.is_downed(brain.revive_pid):
		stop_revive()
		brain.loco.stop()
		return
	var me: Vector3 = player.global_position
	var d: float = _flat(t.global_position, me)
	var per: BotPerception = brain.perception
	var left: float = session.coop.bleed_left(brain.revive_pid)
	var reach: float = float(rc.get("reach_m", 1.4))
	brain.loco.set("exempt_choke", true)
	if d > reach or absf(t.global_position.y - me.y) > 1.5:
		if _reviving_pid != 0:
			stop_revive()
		brain.loco.move_to(t.global_position, 0.85 if d > 8.0 else 0.6, reach * 0.7)
		if not brain.aim.update(delta, d < 12.0):
			brain.loco.look_at_dir(t.global_position + Vector3.UP * 0.5 - brain.aim.eye())
		return
	brain.loco.stop()
	brain.committed = true
	if not _prep_done:
		_prep_done = true
		if per.pressure >= float(cfg("totenglocke").get("dome_min_pressure", 0.3)):
			brain.aim.plant_dome()
		if bool(rc.get("gramophone_first", true)) and per.threat_near(t.global_position, 8.0) > float(rc.get("cover_threat", 0.35)):
			var c: Vector3 = _threat_centroid(t.global_position, 10.0)
			if c != Vector3.INF:
				brain.aim.throw_gramophone(c + (c - t.global_position).normalized() * 4.0)
	# something in knife reach with time to spare: deal with it first
	# something in knife reach with time to spare: a swing, and the hold carries on from where it was
	if per.nearest != null and per.nearest_d < float(cfg("melee").get("range_m", 1.7)) and left > float(rc.get("last_chance_s", 8.0)) 			and not BotPerception.is_boss(per.nearest) and brain.aim.melee_cd <= 0.0 and (brain.aim.knife_kills(per.nearest) or per.nearest.is_crawler):
		brain.aim.melee(per.nearest)
		if _reviving_pid != 0:
			return
	brain.loco.look_at_dir(t.global_position + Vector3.UP * 0.4 - brain.aim.eye())
	# T-058: being torn apart mid-hold with time on the clock: let go and fight (the claim stays; the self-swarm
	# rule blocks the revive until it is clear, or the last-chance rule sends it back in)
	if _reviving_pid != 0 and player.hp < player.max_hp * float(rc.get("abort_hp_frac", 0.4)) and left > float(rc.get("last_chance_s", 8.0)) 			and brain.revive_seconds() - _revive_hold > float(rc.get("abort_min_left_s", 0.6)) and per.nearest_d < 2.0:
		stop_revive()
		_no_hold_until = brain.squad.time() + 1.2
	if _reviving_pid == 0 and brain.squad.time() < _no_hold_until:
		if not brain.aim.update(delta, true):
			brain.idle_look(delta)
		return
	if _reviving_pid == 0:
		_reviving_pid = brain.revive_pid
		_revive_hold = 0.0
		session.coop.set_reviver(brain.revive_pid, player.player_id, true)
		brain.squad.callout(brain, "REVIVE")
	var need: float = brain.revive_seconds()
	_revive_hold += delta
	if player.remote_body != null:
		player.remote_body.hold_action(&"revive")
	if _revive_hold >= need:
		session.coop_revive(brain.revive_pid, player.player_id)
		_reviving_pid = 0
		_revive_hold = 0.0
		brain.revives += 1
		brain.bonus_event("revive")
		brain.squad.revive_done(brain.revive_pid)


func reviving() -> bool:
	return _reviving_pid != 0


func stop_revive() -> void:
	if _reviving_pid != 0 and Net.session != null:
		Net.session.coop.set_reviver(_reviving_pid, player.player_id, false)
	_reviving_pid = 0
	_revive_hold = 0.0
	brain.loco.set("exempt_choke", false)


func _threat_centroid(p: Vector3, r: float) -> Vector3:
	var c: Vector3 = Vector3.ZERO
	var n: int = 0
	for e: Variant in brain.perception.known:
		var zp: Vector3 = (e as Dictionary)["pos"]
		if _flat(zp, p) < r:
			c += zp
			n += 1
	return c / float(n) if n > 0 else Vector3.INF


## Covers a revive (or its own blocked one): stands beside the downed teammate on the threat's side, facing out,
## and kills what comes; a Bell Dome when it is hot.
func _cover(delta: float) -> void:
	var t: Player = brain.squad.player_by_id(brain.cover_pid)
	if t == null:
		brain.loco.stop()
		brain.aim.update(delta, true)
		return
	var c: Vector3 = _threat_centroid(t.global_position, 14.0)
	var out: Vector3 = (c - t.global_position) if c != Vector3.INF else -t.global_basis.z
	out.y = 0.0
	out = out.normalized() if out.length() > 0.01 else Vector3.FORWARD
	# beside the downed one on the far side from the threat, at cover_ring_m, shooting past them; never in the swarm
	var side: Vector3 = Vector3(-out.z, 0.0, out.x) * (1.2 if brain.index % 2 == 0 else -1.2)
	var spot: Vector3 = cover_spot(t.global_position, out, side)
	brain.loco.set("exempt_choke", true)
	var per: BotPerception = brain.perception
	if per.nearest != null and per.nearest_d < 3.0 and not per.nearest.is_crawler:
		_back_off(per.nearest, 3.0, 0.9)
	else:
		brain.loco.hold(spot, out)
	brain.aim.cover_point = t.global_position
	if not _cover_said:
		_cover_said = brain.squad.callout(brain, "COVER", false, t.global_position, "COVERING")
		if brain.perception.pressure >= float(cfg("totenglocke").get("dome_min_pressure", 0.3)) and _flat(player.global_position, t.global_position) < 4.0:
			brain.aim.plant_dome()
	if not brain.aim.update(delta, true):
		brain.loco.look_at_dir(out)


## The spot to cover a downed teammate from: on the far side from the threat at cover_ring_m, else nearer, else on
## the other flank: on their floor with nothing a body can't pass between it and them (bot AI pass 2026-11: the
## plain snap put it outside the wall they lay against, and the coverer stood with no path while they bled out).
## Beside them when nothing else will do.
func cover_spot(at: Vector3, out: Vector3, side: Vector3) -> Vector3:
	var ring: float = float(cfg("revive").get("cover_ring_m", 3.5))
	var base: Vector3 = brain.snap(at)
	for r: float in [ring, ring * 0.6, 1.4]:
		for sd: Vector3 in [side, -side]:
			var p: Vector3 = brain.snap(at - out * r + sd)
			if absf(p.y - base.y) < 1.0 and _flat(p, at) > 0.6 and not BotLocomotion.walled(player, base, p):
				return p
	return base


func _powerup(delta: float) -> void:
	_powerup_t += delta
	var p: Vector3 = brain.powerup_pos()
	if p == Vector3.INF or _powerup_t > 15.0 or brain.loco.is_stuck():
		brain.powerup_done()
		brain.loco.stop()
		return
	brain.loco.move_to(p, 0.7, 0.2)
	if not brain.aim.update(delta, true):
		brain.idle_look(delta)


## T-058: the leader of a squad with no human leading it goes back to the home loop when it has nothing to do,
## so the squad doesn't stay wherever its last errand took it (a dead-end attic, the cellar). True while it walks.
func _go_home() -> bool:
	var hp0: Vector3 = brain.squad.hunt_point()
	if hp0 != Vector3.INF and (_flat(hp0, player.global_position) > 1.6 or absf(hp0.y - player.global_position.y) > 1.5) 			and (brain.aim.target == null or not brain.perception.is_visible(brain.aim.target)):
		brain.loco.move_to(hp0, 0.6, 1.4)   # T-058: the stalled round's last zombie: go and find it, until it is in sight
		return true
	var leader: Player = brain.squad.leader_for(brain)
	if leader != player:
		return false
	var hp: Vector3 = brain.squad.home_point(player.global_position)
	if hp == Vector3.INF or (_flat(hp, player.global_position) < 4.0 and absf(hp.y - player.global_position.y) < 1.5):
		return false
	brain.loco.move_to(hp, 0.45, 2.0)
	return true


func _follow(delta: float) -> void:
	var leader: Player = brain.squad.leader_for(brain)
	if leader == null or leader == player or brain.squad.hunt_point() != Vector3.INF:
		if not _go_home():
			brain.loco.stop()
	else:
		brain.loco.follow(leader, brain.index)
	if not brain.aim.update(delta, true):
		brain.idle_look(delta, leader)


func _regroup(delta: float) -> void:
	var mate: Player = brain.squad.nearest_standing(player, player.global_position)
	if mate == null:
		brain.loco.stop()
	else:
		brain.loco.move_to(mate.global_position, 0.8, 3.0)
	if not brain.aim.update(delta, true):
		brain.idle_look(delta)


## Jakub: stays with the player who freed him, a step behind and to the side, never ahead; covers them first.
func _escort(delta: float) -> void:
	var esc: Player = brain.escort_target()
	if esc == null:
		_follow(delta)
		return
	var hv: Vector3 = Vector3(esc.velocity.x, 0.0, esc.velocity.z)
	var back: Vector3 = -hv.normalized() if hv.length() > 0.6 else esc.global_basis.z
	back.y = 0.0
	back = back.normalized() if back.length() > 0.01 else Vector3.BACK
	var side: Vector3 = Vector3(-back.z, 0.0, back.x)
	var spot: Vector3 = brain.snap(esc.global_position + back * 2.3 + side * 0.9)
	if _flat(spot, player.global_position) > 1.0:
		brain.loco.move_to(spot, 0.75 if _flat(esc.global_position, player.global_position) > 9.0 else 0.35, 0.8)
	else:
		brain.loco.stop()
	if not brain.armed():
		brain.aim.melee_unarmed()
		brain.idle_look(delta, esc)
	elif not brain.aim.update(delta, true):
		brain.idle_look(delta, esc)


func _chatter(delta: float) -> void:
	brain.loco.stop()
	if not _chatter_done:
		_chatter_done = true
		brain.say_chatter()
	var mate: Player = brain.squad.nearest_standing(player, player.global_position)
	if mate != null and _flat(mate.global_position, player.global_position) < 8.0:
		brain.loco.look_at_dir(mate.head.global_position - brain.aim.eye())
	else:
		brain.idle_look(delta)
	if player.remote_body != null:
		player.remote_body.calm = true


func _task(id: String, delta: float) -> void:
	if brain.task.is_empty():
		# the last errand ended and this action won again: the next errand (at most twice a second)
		_task_retry -= delta
		if _task_retry <= 0.0:
			_task_retry = 0.5
			brain.start_task(id)
	if brain.task.is_empty():
		brain.loco.stop()
		if not brain.aim.update(delta, true):
			brain.idle_look(delta)
		return
	var st: String = brain.tasks.run(brain.task, delta)
	if st == "done" or st == "failed":
		brain.finish_task(st == "done")


func _idle(delta: float) -> void:
	var per: BotPerception = brain.perception
	if brain.is_player_bot and per.nearest != null and per.nearest_d < 2.4 and not per.is_visible(per.nearest):
		_back_off(per.nearest, 2.6, 0.6)   # T-071: something in reach it can't shoot (through a window's boards): step out of reach
	elif not _go_home():
		brain.loco.stop()
	if not brain.aim.update(delta, true):
		brain.idle_look(delta)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
