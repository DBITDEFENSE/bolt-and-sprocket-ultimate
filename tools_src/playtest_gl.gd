extends Node
## Gravelight playtest bot. Plays a real solo match (no god mode) on a map through the real Player: it presses
## the same input actions a person would (move, fire, reload, interact, melee) and aims with Player._apply_look
## at a capped human turn rate with aim noise. Shoots heads, reloads, retreats from crowds along the navmesh,
## repairs barricades, buys wall guns / ammo / doors / power / perks. Watches for bugs while it plays:
## stuck or fallen zombies, stalled rounds, a stuck player, failed purchases, and reports every round.
##   godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools_src/playtest_gl.tscn -- --rounds=10 [--map=map00] [--god] [--seed=1] [--bots=3] [--bot-skill=regular]
##        [--perks] [--crucible=3] [--gun=thompson]
## Prints "[bot] ..." lines and a final "[bot] REPORT" block. Own save profile (deleted afterwards).
## --bots=N (T-031) plays with N AI teammates: the report then adds the squad's kills, downs and revives.
## --perks gives every perk to the player and every bot at the start; --crucible=N hands everyone the --gun
## (default thompson) forged to Crucible tier N (1 = the V variant, 2 = VV, 3 = VVV). The bot also slides
## (sprint + crouch, T-040) when it retreats or crosses open ground, and reports slides, slide-jumps and any
## slide that ended inside geometry or below the floor.

const MAPS: Dictionary = {
	"map00": "res://gravelight/maps/map00_crossroads/map00.tscn",
	"map01": "res://gravelight/maps/map01_kaltenbrunn/map01.tscn",
	"map02": "res://gravelight/maps/map02_totenhafen/map02.tscn",
}
const PROFILE: String = "user://_bot_profile.json"
const TURN_RATE: float = 7.0          # rad/s, a quick but human flick
const AIM_NOISE: float = 0.012        # rad
const REACTION: float = 0.18          # s before engaging a newly chosen target
const DANGER_R: float = 4.2           # retreat when a zombie is this close
const MAX_MINUTES: float = 75.0       # game-time safety cap

var target_rounds: int = 10
var god: bool = false
var give_perks: bool = false
var crucible_tier: int = 0
var gun_id: String = "thompson"
var _kitted: bool = false
var _slide_cd: float = 0.0
var _slide_watch: bool = false
var _slide_from: Vector3 = Vector3.ZERO
var slide_issues: int = 0
var map_key: String = "map00"
var bots: int = 0
var bot_kills: int = 0
var bot_downs: int = 0
var revived_by_bot: int = 0
var bot_revives: int = 0
var map: Node3D
var player: Player
var director: ZombieDirector
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _t: float = 0.0
var _target: Zombie = null
var _engage_t: float = 0.0
var _fire_toggle: bool = false
var _goal: Dictionary = {}            # current shopping/repair errand: {node, kind, until}
var _path: PackedVector3Array = []
var _path_i: int = 0
var _path_goal: Vector3 = Vector3.INF
var _repath_t: float = 0.0
var _waypoints: PackedVector3Array = []
var _open_n: Dictionary = {}
var _last_pos: Vector3 = Vector3.ZERO
var _stuck_t: float = 0.0
var _round_t0: float = 0.0
var _done: bool = false
var _settle: int = 0
var _errand_aiming: bool = false
var _shots_dir: String = ""
var _shot_t: float = 8.0
var _shot_n: int = 0
var _errand_cd: float = 0.0

# --- telemetry ---
var rounds: Array[Dictionary] = []
var issues: Dictionary = {}           # message -> count (deduplicated)
var kills: int = 0
var heads: int = 0
var shots: int = 0
var downs: int = 0
var damage_taken: float = 0.0
var purchases: PackedStringArray = []
var denied: PackedStringArray = []
var powerups: PackedStringArray = []
var _z_track: Dictionary = {}
var _z_hist: Dictionary = {}     # zombie id -> Array of [t, pos, state] at 1 Hz
var _z_hist_t: float = 0.0
var _z_origin: Dictionary = {}   # zombie id -> [first position, round, state]         # zombie id -> {pos, t, state}
var _round_kills: int = 0
var _round_dmg: float = 0.0
var _phys_us: Array[float] = []
var _game_over: bool = false
var _max_alive: int = 0
var _last_us: int = 0
var _prev_w: WeaponInstance = null
var _prev_mag: int = 0
var fired: int = 0
var hits: int = 0
var _last_event: String = ""


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--rounds="):
			target_rounds = int(a.substr(9))
		elif a == "--god":
			god = true
		elif a.begins_with("--map="):
			map_key = a.substr(6)
		elif a.begins_with("--shots="):
			_shots_dir = a.substr(8)   # rendered runs only: a screenshot every 12 s of game time
		elif a.begins_with("--seed="):
			rng.seed = int(a.substr(7))
		elif a.begins_with("--bots="):
			bots = int(a.substr(7))
		elif a.begins_with("--bot-skill="):
			GameState.bot_skill = a.substr(12)
		elif a == "--perks":
			give_perks = true
		elif a.begins_with("--crucible="):
			crucible_tier = clampi(int(a.substr(11)), 0, 3)
		elif a.begins_with("--gun="):
			gun_id = a.substr(6)
	ProfileSave.path = PROFILE
	ProfileSave.profile = ProfileSave.new_profile()
	GameState.bot_count = bots
	map = (load(MAPS[map_key]) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(map)
	get_tree().set_deferred("current_scene", map)
	GLBus.enemy_killed.connect(func(_e: StringName, limb: StringName, _w: StringName, by: int) -> void:
		if by == 1:
			kills += 1
			_round_kills += 1
			if limb == &"head":
				heads += 1
		elif GameState.is_bot(by):
			bot_kills += 1)
	GLBus.player_revived.connect(func(p: int, by: int) -> void:
		if p == 1 and GameState.is_bot(by):
			revived_by_bot += 1
			print("[bot] revived by %s in round %d" % [Net.display_name(by), RoundManager.current_round])
		elif GameState.is_bot(p) and GameState.is_bot(by):
			bot_revives += 1)
	GLBus.enemy_damaged.connect(func(_e: StringName, _l: StringName, _a: float, by: int) -> void:
		if by == 1:
			hits += 1)
	GLBus.player_damaged.connect(func(_p: int, a: float) -> void:
		damage_taken += a
		_round_dmg += a
		if OS.get_cmdline_user_args().has("--debug") and director != null:
			var nz: Zombie = _nearest(director.active_zombies(), false)
			var w: WeaponInstance = player.weapons.current()
			print("[bot]     HIT %.0f hp %.0f | nearest %s d=%.1f state %s | path %d/%d | target %s | %s mag %d busy %s | goal %s" % [a, player.hp,
				str(nz.enemy_id) if nz else "-", nz.global_position.distance_to(player.global_position) if nz else -1.0,
				Zombie.State.keys()[nz.state] if nz else "-", _path_i, _path.size(), _target != null, w.id if w else &"-", w.mag if w else -1,
				player.weapons.is_busy(), str(_goal.get("kind", "-")) + " reserve %d" % (w.reserve if w else -1)]))
	GLBus.player_downed.connect(func(p: int) -> void:
		if GameState.is_bot(p):
			bot_downs += 1
			print("[bot] teammate %s DOWNED in round %d" % [Net.display_name(p), RoundManager.current_round])
			return
		downs += 1
		print("[bot] DOWNED in round %d at %s (hp events this round %.0f)" % [RoundManager.current_round, _v(player.global_position), _round_dmg]))
	GLBus.round_started.connect(_on_round_started)
	for sig: String in ["enemy_spawned", "enemy_killed", "door_opened", "purchase_made", "powerup_spawned", "round_started", "round_ended", "explosion"]:
		GLBus.connect(sig, func(a: Variant = null, _b: Variant = null, _c: Variant = null, _d: Variant = null) -> void: _last_event = "%s %s @%.1f" % [sig, str(a), _t])
	GLBus.game_over.connect(func(_s: Dictionary) -> void:
		_game_over = true
		print("[bot] GAME OVER at round %d" % RoundManager.current_round))
	GLBus.purchase_made.connect(func(_p: int, item: StringName, cost: int) -> void:
		purchases.append("r%d %s (%d)" % [RoundManager.current_round, item, cost])
		print("[bot]   bought %s for %d" % [item, cost]))
	GLBus.purchase_denied.connect(func(_p: int, item: StringName, why: StringName) -> void:
		denied.append("r%d %s: %s" % [RoundManager.current_round, item, why]))
	GLBus.powerup_spawned.connect(func(id: StringName, _pos: Vector3) -> void: powerups.append("r%d spawned %s" % [RoundManager.current_round, id]))
	GLBus.powerup_collected.connect(func(id: StringName, _b: int) -> void: powerups.append("r%d took %s" % [RoundManager.current_round, id]))


func _issue(msg: String) -> void:
	if not issues.has(msg):
		print("[bot] ISSUE: ", msg)
	issues[msg] = int(issues.get(msg, 0)) + 1


static func _v(p: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [p.x, p.y, p.z]


func _on_round_started(r: int, special: bool) -> void:
	if r > 1:
		var prev: Dictionary = {"round": r - 1, "secs": _t - _round_t0, "kills": _round_kills, "dmg": _round_dmg,
			"scrip": Economy.get_scrip(1), "weapon": str(player.weapons.current().id) if player.weapons.current() else "-",
			"hp": player.hp, "max_alive": _max_alive}
		rounds.append(prev)
		print("[bot] round %d done in %.0fs: kills %d, dmg taken %.0f, scrip %d, weapon %s, max alive %d" % [
			r - 1, prev["secs"], _round_kills, _round_dmg, prev["scrip"], prev["weapon"], _max_alive])
		if _t - _round_t0 > 300.0:
			_issue("round %d took over 5 minutes" % (r - 1))
	_round_t0 = _t
	_round_kills = 0
	_round_dmg = 0.0
	_max_alive = 0
	print("[bot] ROUND %d start%s  t=%.0fs" % [r, " (special)" if special else "", _t])
	if r > target_rounds:
		_finish("reached round %d" % r)


# ------------------------------------------------------------------------------------------------ main loop

func _physics_process(delta: float) -> void:
	if _done or map == null or not map.is_inside_tree():
		return
	if player == null:
		player = map.get("player") as Player
		director = map.get("director") as ZombieDirector
		if player == null or director == null:
			return
		GameState.god_mode = god
		return
	if _waypoints.is_empty():
		var nav: RID = player.get_world_3d().navigation_map
		if NavigationServer3D.map_get_iteration_id(nav) == 0:
			return
		_build_waypoints()
		_openness()
		if _waypoints.size() < 10:
			_waypoints = PackedVector3Array()
			_settle += 1
			if _settle > 300:
				_issue("navmesh never became queryable for the player")
				_finish("no navmesh")
			return
		print("[bot] map %s, %d waypoints, god=%s, target round %d" % [map_key, _waypoints.size(), god, target_rounds])
		_dump_buyables()
		_last_pos = player.global_position
		return
	if not _kitted and RoundManager.current_round >= 1:
		_kit_out()
	_t += delta
	_slide_cd -= delta
	_watch_slide()
	var now: int = Time.get_ticks_usec()
	var pms: float = (now - _last_us) / 1000.0
	_last_us = now
	if _t > 5.0:
		_phys_us.append(pms)
		if pms > 100.0:
			_issue("frame over 100 ms (real time)")
			print("[bot]     SPIKE %.0f ms at t=%.1f round %d alive %d (last event: %s)" % [pms, _t, RoundManager.current_round, director.active_zombies().size(), _last_event])
	# rounds actually fired = magazine drops
	var cw: WeaponInstance = player.weapons.current()
	if cw != null:
		if cw == _prev_w and cw.mag < _prev_mag:
			fired += _prev_mag - cw.mag
		_prev_w = cw
		_prev_mag = cw.mag
	if _t > MAX_MINUTES * 60.0:
		_issue("safety cap: %d game minutes without reaching round %d" % [int(MAX_MINUTES), target_rounds + 1])
		_finish("timeout")
		return
	if _game_over:
		_finish("game over")
		return
	if OS.get_cmdline_user_args().has("--trace"):
		var w0: WeaponInstance = player.weapons.current()
		print("[trace] t=%.2f r%d pos %s goal %s w %s %d/%d busy %s" % [_t, RoundManager.current_round, _v(player.global_position),
			str(_goal.get("kind", "-")) + ":" + str(_goal.get("label", "")), w0.id if w0 else &"-", w0.mag if w0 else 0, w0.reserve if w0 else 0, player.weapons.is_busy()])
	if _shots_dir != "" and DisplayServer.get_name() != "headless":
		_shot_t -= delta
		if _shot_t <= 0.0:
			_shot_t = 12.0
			_snap_shot()
	_release_all()
	_watch_zombies(delta)
	if GameState.phase != GameState.Phase.PLAYING or player.downed:
		return
	var zs: Array[Zombie] = director.active_zombies()
	_max_alive = maxi(_max_alive, zs.size())
	var near: Zombie = _nearest(zs, false)
	var near_d: float = INF if near == null else near.global_position.distance_to(player.global_position)
	# --- target selection and aim ---
	var tgt: Zombie = _nearest(zs, true)
	if tgt != _target:
		_target = tgt
		_engage_t = REACTION
	_engage_t -= delta
	var w: WeaponInstance = player.weapons.current()
	var aim_at: Vector3 = Vector3.INF
	if _target != null:
		aim_at = _aim_point(_target)
	elif not _goal.is_empty() and is_instance_valid(_goal["node"]):
		var gn: Interactable = _goal["node"] as Interactable
		aim_at = gn.area.global_position if gn.area != null else gn.global_position
	var on_target: bool = false
	if _errand_aiming:
		aim_at = Vector3.INF   # the errand is lining up its own look this frame (it turns in _run_errand)
		_errand_aiming = false
	if aim_at != Vector3.INF:
		on_target = _turn_toward(aim_at, delta) < 0.045
	# --- weapon handling, in priority order ---
	if w != null:
		var busy: bool = player.weapons.is_busy()
		var reloading: bool = player.weapons.is_reloading()
		var other_mag: bool = false
		var other_any: bool = false
		for inst: WeaponInstance in player.weapons.slots:
			if inst != w:
				other_mag = other_mag or inst.mag > 0
				other_any = other_any or inst.mag > 0 or inst.reserve > 0
		if god and w.mag == 0 and w.reserve == 0:
			w.refill()   # god-mode runs test systems, not ammo management
		if w.mag == 0 and w.reserve == 0 and near_d < 1.8 and not other_mag:
			Input.action_press(&"melee")                       # 1. empty everything and something is on us
		elif w.mag == 0 and not busy and ((other_mag and near_d < 4.5) or (w.reserve == 0 and other_any)):
			Input.action_press(&"swap_weapon")                 # 2. a loaded gun beats a reload up close
		elif w.mag == 0 and w.reserve > 0 and not reloading:
			Input.action_press(&"reload")                      # 3. reload
		elif _target != null and on_target and _engage_t <= 0.0 and w.mag > 0 and not busy:
			_fire_toggle = not _fire_toggle                    # 4. shoot
			if w.fire_mode == "auto" or _fire_toggle:
				Input.action_press(&"fire")
				shots += 1
		elif _target == null and w.mag < w.mag_size() * 0.5 and w.reserve > 0 and not reloading:
			Input.action_press(&"reload")                      # 5. top up when it's quiet
	# --- movement ---
	if god and _ammo_low():
		_errands()   # can't die: walk through them for ammo rather than stalemate in a corner
	elif near != null and near_d < DANGER_R:
		_goal = {}
		Input.action_release(&"interact")
		if _repath_t <= 0.0 or _path.is_empty() or _path_i >= _path.size():
			_retreat(zs)
		var dry: bool = true
		for inst: WeaponInstance in player.weapons.slots:
			if inst.mag > 0 or inst.reserve > 0:
				dry = false
		var loaded: bool = w != null and w.mag > 0 and not player.weapons.is_reloading()
		if (dry and near_d < 2.6) or (loaded and near_d < 3.2 and not player.crouching):
			Input.action_press(&"sprint")   # sprinting cancels reloads, so only with nothing to load or a loaded gun
		_maybe_slide(near_d)
	elif (zs.is_empty() or (near_d > 12.0 and zs.size() <= 3) or (_ammo_low() and near_d > 5.5)) and _target == null or zs.is_empty():
		_errands()   # shop like a person: between rounds, or with the last stragglers far away
		if _path.size() - _path_i > 4 and not player.weapons.is_reloading() and not player.crouching:
			Input.action_press(&"sprint")
			_maybe_slide(near_d)
	else:
		_hold_position()
	_follow_path(delta)
	_check_player_stuck(delta)


func _release_all() -> void:
	for a: StringName in [&"fire", &"reload", &"melee", &"interact", &"swap_weapon", &"move_forward", &"move_back",
			&"move_left", &"move_right", &"sprint", &"crouch", &"jump"]:
		if a == &"interact" and not _goal.is_empty() and bool(_goal.get("holding", false)):
			continue
		Input.action_release(a)


## --perks / --crucible: every perk for everyone, and the chosen gun forged to the tier, like a late-round kit.
func _kit_out() -> void:
	_kitted = true
	var sq: BotSquad = get_tree().get_first_node_in_group(&"bot_squad") as BotSquad
	var everyone: Array[Player] = [player]
	if sq != null:
		for p: Player in sq.all_players():
			if p != player and not everyone.has(p):
				everyone.append(p)
	if give_perks:
		for p: Player in everyone:
			PerkManager.grant_all(p.player_id)
		print("[bot] kit: every perk for %d players: %s" % [everyone.size(), str(PerkManager.owned(1))])
	if crucible_tier > 0:
		var up: StringName = StringName(gun_id + "_up")
		var tbl: Dictionary = GLData.table("weapons")
		if not (tbl.get("upgraded", {}) as Dictionary).has(String(up)):
			_issue("--crucible: no upgraded row for %s" % gun_id)
			return
		for p: Player in everyone:
			p.weapons.give_weapon(up)
			var got: WeaponInstance = p.weapons.find_weapon(up)
			if got == null:
				_issue("--crucible: %s did not take %s" % [Net.display_name(p.player_id), up])
				continue
			got.tier = crucible_tier
			got.refill()
			p.weapons.call("_rebuild_gun")
		var mine: WeaponInstance = player.weapons.find_weapon(up)
		print("[bot] kit: %s tier %d for everyone (%s, dmg %.0f, mag %d/%d)" % [up, crucible_tier, mine.display_name() if mine else "?",
			mine.f("damage", 0.0) if mine else 0.0, mine.mag if mine else 0, mine.reserve if mine else 0])


## Slide like a player would: when something is on us and we're sprinting away, or crossing open ground.
func _maybe_slide(near_d: float) -> void:
	if _slide_cd > 0.0 or player.sliding or not player.is_on_floor() or player.crouching:
		return
	if not (player.sprinting or player.horizontal_speed() > 5.5):
		return
	if near_d < 3.2 or rng.randf() < 0.03:
		Input.action_press(&"sprint")
		Input.action_press(&"crouch")
		_slide_cd = rng.randf_range(1.5, 3.5)
		_slide_from = player.global_position
		_slide_watch = true
		if rng.randf() < 0.35:
			_jump_after = 0.35 + rng.randf() * 0.3


var _jump_after: float = -1.0


## Checks every slide: it must end upright on the floor, not inside a wall and not below where it started.
func _watch_slide() -> void:
	if _jump_after > 0.0:
		_jump_after -= get_physics_process_delta_time()
		if _jump_after <= 0.0 and player.sliding:
			Input.action_press(&"jump")
	if not _slide_watch:
		return
	if player.sliding:
		return
	_slide_watch = false
	var p: Vector3 = player.global_position
	if p.y < _slide_from.y - 3.0:
		_issue("slide ended far below where it started (%.1f m): fell through something?" % (_slide_from.y - p.y))
		slide_issues += 1
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var q: PhysicsPointQueryParameters3D = PhysicsPointQueryParameters3D.new()
	q.position = p + Vector3.UP * 0.9
	q.collision_mask = 1
	q.exclude = [player.get_rid()]
	if not space.intersect_point(q, 1).is_empty():
		_issue("slide ended inside world geometry at %s" % _v(p.snapped(Vector3.ONE * 0.5)))
		slide_issues += 1


# ------------------------------------------------------------------------------------------------ aiming

func _nearest(zs: Array[Zombie], need_los: bool) -> Zombie:
	var best: Zombie = null
	var bd: float = INF
	for z: Zombie in zs:
		if z.state == Zombie.State.DEAD or z.state == Zombie.State.INACTIVE or z.state == Zombie.State.EMERGE:
			continue
		var d: float = z.global_position.distance_to(player.global_position)
		if d >= bd:
			continue
		if need_los and (d > 40.0 or not _los(_aim_point(z))):
			continue
		bd = d
		best = z
	return best


func _aim_point(z: Zombie) -> Vector3:
	var hbs: Variant = z.get("_hitboxes")
	if hbs is Array:
		for hb: Variant in hbs:
			if hb is Hitbox and (hb as Hitbox).limb == &"head":
				return (hb as Hitbox).global_position
	return z.global_position + Vector3(0, 1.4, 0)


func _los(p: Vector3) -> bool:
	var from: Vector3 = player.camera.global_position
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, p, 1)
	q.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Turns the view toward p at a capped rate (+ noise). Returns the remaining angular error (rad).
func _turn_toward(p: Vector3, dt: float) -> float:
	var cam: Camera3D = player.camera
	var to: Vector3 = (p - cam.global_position)
	if to.length() < 0.01:
		return 0.0
	to = to.normalized()
	var fwd: Vector3 = -cam.global_basis.z
	var yaw_err: float = wrapf(atan2(-to.x, -to.z) - atan2(-fwd.x, -fwd.z), -PI, PI)
	var pitch_err: float = asin(clampf(to.y, -1, 1)) - asin(clampf(fwd.y, -1, 1))
	var step: float = TURN_RATE * dt
	var dy: float = clampf(yaw_err, -step, step) + rng.randfn(0.0, AIM_NOISE * 0.3)
	var dp: float = clampf(pitch_err, -step, step) + rng.randfn(0.0, AIM_NOISE * 0.3)
	player._apply_look(Vector2(-dy, -dp))
	return Vector2(yaw_err, pitch_err).length()


# ------------------------------------------------------------------------------------------------ movement

func _build_waypoints() -> void:
	var nav: RID = player.get_world_3d().navigation_map
	var c: Vector3 = player.global_position
	for x: int in range(-30, 31, 2):
		for z: int in range(-30, 31, 2):
			for y: float in [c.y, c.y + 3.5, c.y - 3.2]:   # the floors above and the cellars below (T-051)
				var p: Vector3 = NavigationServer3D.map_get_closest_point(nav, c + Vector3(x, y - c.y, z))
				if p.distance_to(c + Vector3(x, y - c.y, z)) < 1.2:
					var dup: bool = false
					for q: Vector3 in _waypoints:
						if q.distance_squared_to(p) < 1.0:
							dup = true
							break
					if not dup:
						_waypoints.append(p)


## A nav path that doesn't cross a closed BuyDoor (doors aren't baked into the navmesh; they're colliders that
## move away when bought). Empty when the only route is through a closed door.
func _open_path(from: Vector3, dest: Vector3) -> PackedVector3Array:
	var path: PackedVector3Array = NavigationServer3D.map_get_path(player.get_world_3d().navigation_map, from, dest, true)
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		var d: BuyDoor = n as BuyDoor
		if d == null or d.is_open:
			continue
		if ZombieDirector.door_crossed(d, path):
			return PackedVector3Array()
	return path


## Waypoint -> number of neighbours within 3 m (open floor scores high; corners and dead ends low).
func _openness() -> void:
	# counts only neighbours in plain sight (a machine, a crate or a wall in between doesn't count), so the
	# pockets behind the perk machines score as the dead ends they are
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	for a: Vector3 in _waypoints:
		var n: int = 0
		for b: Vector3 in _waypoints:
			if a.distance_squared_to(b) < 9.0 and absf(a.y - b.y) < 1.0:
				var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(a + Vector3.UP * 0.6, b + Vector3.UP * 0.6, 1)
				if space.intersect_ray(q).is_empty():
					n += 1
		_open_n[a] = n


func _path_to(dest: Vector3) -> void:
	if _path_goal.distance_to(dest) < 0.5 and _repath_t > 0.0:
		return
	_path = _open_path(player.global_position, dest)
	_path_i = 1 if _path.size() > 1 else 0
	_path_goal = dest
	_repath_t = 0.5


func _follow_path(delta: float) -> void:
	_repath_t -= delta
	if _path.is_empty() or _path_i >= _path.size():
		return
	var p: Vector3 = _path[_path_i]
	var flat: Vector3 = Vector3(p.x - player.global_position.x, 0, p.z - player.global_position.z)
	if flat.length() < 0.45:
		_path_i += 1
		return
	# world direction -> the player's local stick
	var local: Vector3 = player.global_basis.inverse() * flat.normalized()
	var fwd: float = -local.z
	var right: float = local.x
	if fwd > 0.05:
		Input.action_press(&"move_forward", clampf(fwd, 0, 1))
	elif fwd < -0.05:
		Input.action_press(&"move_back", clampf(-fwd, 0, 1))
	if right > 0.05:
		Input.action_press(&"move_right", clampf(right, 0, 1))
	elif right < -0.05:
		Input.action_press(&"move_left", clampf(-right, 0, 1))


func _retreat(zs: Array[Zombie]) -> void:
	# Kiting, v2: go somewhere open (not a corner), well clear of every zombie, by a route that doesn't brush
	# past one. Prefers moving away from the crowd but will circle round it when "away" is a wall.
	var me: Vector3 = player.global_position
	var centroid: Vector3 = Vector3.ZERO
	var n: int = 0
	for z: Zombie in zs:
		if z.global_position.distance_to(me) < 8.0:
			centroid += z.global_position
			n += 1
	if n == 0:
		return
	centroid /= n
	var away: Vector3 = (me - centroid)
	away.y = 0
	away = away.normalized()
	var max_open: int = 1
	for v: Variant in _open_n.values():
		max_open = maxi(max_open, int(v))
	# strict first, then progressively relaxed (cornered players take whatever opening there is)
	for tier: Array in [[0.6, 3.0, 1.6], [0.35, 2.0, 1.2], [0.0, 1.2, 0.8]]:
		var cands: Array = []
		for w: Vector3 in _waypoints:
			var d: float = w.distance_to(me)
			if d < 2.5 or d > 12.0 or absf(w.y - me.y) > 2.5 or _in_closed_doorway(w):
				continue
			var openness: float = float(_open_n.get(w, 0)) / float(max_open)
			if openness < float(tier[0]):
				continue
			var dir: Vector3 = Vector3(w.x - me.x, 0, w.z - me.z).normalized()
			var clear: float = INF
			for z: Zombie in zs:
				clear = minf(clear, z.global_position.distance_to(w))
			if clear < float(tier[1]):
				continue
			var s: float = minf(clear, 9.0) * 1.5 + dir.dot(away) * 3.0 - d * 0.2 + openness * 6.0
			cands.append([s, w])
		cands.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
		for c: Array in cands.slice(0, 10):
			var path: PackedVector3Array = _open_path(me, c[1])
			if path.is_empty() or _path_brushes_zombie(path, zs, float(tier[2])):
				continue
			_path_to(c[1])
			return
	# truly boxed in: back away from the crowd in the first direction with 2 m of clear floor (straight away, then
	# turning further and further off it), never into a wall (T-051: the corner at Door 1 swallowed this)
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var nav: RID = player.get_world_3d().navigation_map
	for ang: float in [0.0, 50.0, -50.0, 100.0, -100.0, 150.0, -150.0]:
		var d: Vector3 = away.rotated(Vector3.UP, deg_to_rad(ang))
		var from: Vector3 = me + Vector3.UP * 0.6
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + d * 2.4, 1 | (1 << 8), [player.get_rid()])).is_empty():
			continue
		var back: Vector3 = NavigationServer3D.map_get_closest_point(nav, me + d * 2.0)
		if Vector2(back.x - me.x - d.x * 2.0, back.z - me.z - d.z * 2.0).length() < 0.7:
			_path = PackedVector3Array([me, back])
			_path_i = 1
			_repath_t = 0.3
			return
	_path = PackedVector3Array()   # nowhere to go: stand and fight


## A waypoint standing in a shut door's opening (the navmesh runs through doors: they aren't baked), where a
## retreat would walk into the door (T-051: the stair vestibule's Door 1 stuck reports).
func _in_closed_doorway(w: Vector3) -> bool:
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		var d: BuyDoor = n as BuyDoor
		if d == null or d.is_open:
			continue
		var local: Vector3 = d.global_transform.affine_inverse() * w
		if absf(local.x) < d.size.x * 0.5 + 0.6 and absf(local.z) < 1.2 and absf(local.y) < 2.0:
			return true
	return false


func _path_brushes_zombie(path: PackedVector3Array, zs: Array[Zombie], radius: float) -> bool:
	for z: Zombie in zs:
		var zp: Vector2 = Vector2(z.global_position.x, z.global_position.z)
		for i: int in range(1, path.size()):
			var a: Vector2 = Vector2(path[i - 1].x, path[i - 1].z)
			var b: Vector2 = Vector2(path[i].x, path[i].z)
			if Geometry2D.get_closest_point_to_segment(zp, a, b).distance_to(zp) < radius:
				return true
	return false


func _hold_position() -> void:
	_path = PackedVector3Array()


func _check_player_stuck(delta: float) -> void:
	var moving_wanted: bool = not _path.is_empty() and _path_i < _path.size()
	if moving_wanted and player.global_position.distance_to(_last_pos) < 0.02:
		_stuck_t += delta
		if _stuck_t > 2.5:
			var msg: String = "player stuck while walking a nav path near %s" % _v(player.global_position.snapped(Vector3.ONE))
			if not issues.has(msg):   # the first time: what it was walking to and what is in the way (T-051)
				var nxt: Vector3 = _path[mini(_path_i, _path.size() - 1)]
				var from: Vector3 = player.global_position + Vector3.UP * 0.5
				var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + (Vector3(nxt.x, from.y, nxt.z) - from).normalized() * 0.8, 0xFFFFFFFF, [player.get_rid()])
				var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(q)
				print("[bot]     at %s next %s (point %d/%d, goal %s), in the way: %s, errand %s, zombies near %d" % [_v(player.global_position), _v(nxt), _path_i, _path.size(),
					_v(_path[_path.size() - 1]), str((hit["collider"] as Node).name) if not hit.is_empty() else "nothing", str(_goal.get("kind", "-")),
					director.active_zombies().filter(func(z: Zombie) -> bool: return z.global_position.distance_to(player.global_position) < 4.0).size()])
			_issue(msg)
			_path = PackedVector3Array()
			_goal = {}
			_stuck_t = 0.0
	else:
		_stuck_t = 0.0
	_last_pos = player.global_position


# ------------------------------------------------------------------------------------------------ errands

func _dump_buyables() -> void:
	for n: Node in map.find_children("*", "Interactable", true, false):
		var it: Interactable = n as Interactable
		var cost: String = ""
		if it is WallBuy:
			cost = "%s %d" % [(it as WallBuy).weapon_id, (it as WallBuy).price()]
		elif it is BuyDoor:
			cost = "door %s %d%s" % [(it as BuyDoor).label, (it as BuyDoor).cost, " (power)" if (it as BuyDoor).requires_power else ""]
		elif it is PerkMachine:
			cost = "perk %s" % (it as PerkMachine).perk_id
		elif it is PowerSwitch:
			cost = "POWER"
		elif it is Barricade:
			continue
		else:
			cost = it.get_class() if it.get_script() == null else str((it.get_script() as Script).get_global_name())
		print("[bot]   buyable %-28s at %s" % [cost, _v(it.global_position)])


## Picks something useful to do between fights: repair a broken barricade, buy ammo, a better gun, a perk,
## the power, or a door. Walks there, looks at it, holds Use.
func _errands() -> void:
	if not _goal.is_empty():
		if not is_instance_valid(_goal["node"]):
			_goal = {}   # its target was freed (a retired Second Wind machine, a used pickup)
			return
		var node: Interactable = _goal["node"] as Interactable
		if _t > float(_goal["until"]):
			if is_instance_valid(node) and str(_goal["kind"]) != "repair":
				_issue("errand timed out: %s %s at %s" % [_goal["kind"], _goal["label"], _v(node.global_position)])
				print("[bot]     (me %s, target %s, prompt '%s', scrip %d)" % [_v(player.global_position), str(player.interact_target), player.prompt_text, Economy.get_scrip(1)])
			_goal = {}
			return
		_run_errand(node)
		return
	_errand_cd -= get_physics_process_delta_time()
	if _errand_cd > 0.0:
		return
	_errand_cd = 0.5
	var g: Dictionary = _choose_errand()
	if not g.is_empty():
		_goal = g
		_goal["until"] = _t + 25.0
		print("[bot]   errand: %s %s (scrip %d)" % [g["kind"], g["label"], Economy.get_scrip(1)])


func _run_errand(node: Interactable) -> void:
	var me: Vector3 = player.global_position
	var at: Vector3 = node.global_position
	var flat_d: float = Vector2(at.x - me.x, at.z - me.z).length()
	var front: Vector3 = _front_of(node)
	var at_front: bool = Vector2(front.x - me.x, front.z - me.z).length() < 0.8 or (front == node.global_position and flat_d <= 1.6)
	if not at_front or absf(at.y - me.y) > 1.8:
		var approach: Vector3 = _front_of(node)
		if node is BuyDoor:
			# stand on our side of a closed door (the closest navmesh point may be behind it)
			var side: Vector3 = node.global_basis.z
			side.y = 0
			if side.dot(me - at) < 0.0:
				side = -side
			approach = at + side.normalized() * 1.1
		_path_to(NavigationServer3D.map_get_closest_point(player.get_world_3d().navigation_map, approach))
		_goal["holding"] = false
		return
	_path = PackedVector3Array()
	# a wall buy replaces the gun in your hands: hold the weakest one first
	if str(_goal["kind"]) == "gun" and player.weapons.slots.size() >= player.weapons.max_slots():
		var cur: WeaponInstance = player.weapons.current()
		if cur != null and _wall_price(cur.base_id()) > _worst_held_price() and not player.weapons.is_busy():
			Input.action_press(&"swap_weapon")
			return
	_errand_aiming = true
	var aim: Vector3 = node.area.global_position if node.area != null else node.global_position + node.interact_offset
	var err: float = _turn_toward(aim, get_physics_process_delta_time())
	if player.interact_target == node or err < 0.15:
		Input.action_press(&"interact")
		_goal["holding"] = true
	var kind: String = str(_goal["kind"])
	if OS.get_cmdline_user_args().has("--debug") and fmod(_t, 1.0) < get_physics_process_delta_time():
		print("[bot]     dbg %s: me %s at %s flat %.2f err %.2f target %s prompt '%s' hold %.2f" % [kind, _v(me), _v(at), flat_d, err, str(player.interact_target), player.prompt_text, player.interact_progress])
	var done: bool = false
	match kind:
		"repair":
			done = not _barricade_damaged(node)
		"door":
			done = (node as BuyDoor).is_open
		_:
			done = bool(_goal.get("start_scrip", -1) != Economy.get_scrip(1)) and _goal.has("start_scrip")
	if not _goal.has("start_scrip"):
		_goal["start_scrip"] = Economy.get_scrip(1)
	if done:
		Input.action_release(&"interact")
		_goal = {}


func _wall_price(base: StringName) -> int:
	for n: Node in map.find_children("*", "WallBuy", true, false):
		if (n as WallBuy).weapon_id == base:
			return (n as WallBuy).price()
	return 0


func _cellar_closed() -> bool:
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		if n is BuyDoor and (n as BuyDoor).door_id == &"door_cellar":
			return not (n as BuyDoor).is_open
	return false


func _ammo_low() -> bool:
	var total: int = 0
	var cap: int = 0
	for inst: WeaponInstance in player.weapons.slots:
		total += inst.mag + inst.reserve
		cap += inst.mag_size() + inst.reserve_max()
	return cap > 0 and total < cap * 0.3


## What the cheapest gun we'd give up is worth (its wall price; the start pistol counts as 0). With a free slot, 0.
func _worst_held_price() -> int:
	if player.weapons.slots.size() < player.weapons.max_slots():
		return 0
	var worst: int = 1 << 30
	for inst: WeaponInstance in player.weapons.slots:
		if inst.tier > 0:
			continue                      # a forged gun is never the one to give up for a wall buy
		var price: int = 0
		for n: Node in map.find_children("*", "WallBuy", true, false):
			if (n as WallBuy).weapon_id == inst.base_id():
				price = (n as WallBuy).price()
		worst = mini(worst, price)
	return worst


## Where to stand to use something: 1 m out from its use area, on the side the area sticks out (a perk
## machine's front, a wall-buy's chalk); the node itself when the area is centred.
## The direction an interactable faces: its prompt area's offset from its origin, else (a wall-buy keeps its
## area on its origin and offsets only the shape) its local -Z, which the generators point into the room.
func _facing(node: Interactable) -> Vector3:
	var off: Vector3 = Vector3.ZERO
	if node.area != null:
		off = node.area.global_position - node.global_position
		off.y = 0.0
	if off.length() < 0.05:
		if node is WallBuy:
			off = node.global_basis * Vector3(0, 0, -1)
			off.y = 0.0
		else:
			return Vector3.ZERO
	return off.normalized()


## True when `p` lies on the side the interactable faces. A wall-buy chalked on the Cannery's face of the quay
## wall is 1.3 m from the quay's navmesh, within the path tolerance, but the wall is in the way: the errand walked
## to the wrong face and timed out, round after round (UPDATE 07 QA, Map 2).
func _in_front(node: Interactable, p: Vector3) -> bool:
	var f: Vector3 = _facing(node)
	if f == Vector3.ZERO:
		return true
	var to: Vector3 = p - node.global_position
	to.y = 0.0
	return to.dot(f) > -0.2


func _front_of(node: Interactable) -> Vector3:
	var f: Vector3 = _facing(node)
	if f == Vector3.ZERO:
		return node.global_position
	var base: Vector3 = node.area.global_position if node.area != null else node.global_position
	var p: Vector3 = base + f * 1.0
	p.y = node.global_position.y
	return p


func _barricade_damaged(n: Node) -> bool:
	for k: String in ["boards", "board_count", "_boards"]:
		var v: Variant = n.get(k)
		if v is int:
			var mx: Variant = n.get("max_boards")
			return int(v) < (int(mx) if mx is int else 6)
		if v is Array:
			var mx2: Variant = n.get("max_boards")
			return (v as Array).size() < (int(mx2) if mx2 is int else 6)
	return false


func _choose_errand() -> Dictionary:
	var scrip: int = Economy.get_scrip(1)
	var me: Vector3 = player.global_position
	var best: Dictionary = {}
	var best_s: float = -INF
	var held: Array[StringName] = []
	for s: WeaponInstance in player.weapons.slots:
		held.append(s.base_id())
	var cur: WeaponInstance = player.weapons.current()
	for n: Node in map.find_children("*", "Interactable", true, false):
		var it: Interactable = n as Interactable
		if not it.is_visible_in_tree():
			continue
		var d: float = it.global_position.distance_to(me)
		if d > 60.0:
			continue
		var path: PackedVector3Array = _open_path(me,
			NavigationServer3D.map_get_closest_point(player.get_world_3d().navigation_map, _front_of(it)))
		if it is BuyDoor:
			path = NavigationServer3D.map_get_path(player.get_world_3d().navigation_map, me,
				NavigationServer3D.map_get_closest_point(player.get_world_3d().navigation_map, it.global_position), true)
		if path.is_empty() or path[path.size() - 1].distance_to(_front_of(it)) > 2.5:
			continue
		if it is WallBuy and not _in_front(it, path[path.size() - 1]):
			continue   # the path ends behind the board (a wall-buy on the far face of a wall we stand beside)
		var s: float = -INF
		var kind: String = ""
		var label: String = ""
		if it is Barricade and _barricade_damaged(it):
			kind = "repair"
			label = str((it as Barricade).window_id)
			s = 30.0 - d
		elif it is WallBuy:
			var wb: WallBuy = it as WallBuy
			label = str(wb.weapon_id)
			if wb.weapon_id in held:
				var inst: WeaponInstance = player.weapons.find_weapon_base(wb.weapon_id)
				if inst != null and inst.reserve < inst.reserve_max() * 0.35 and scrip >= wb.ammo_price(player):
					kind = "ammo"
					s = (120.0 if _ammo_low() else 60.0) - d
			elif scrip >= wb.price() + (250 if RoundManager.current_round > 2 else 0) and wb.price() > _worst_held_price():
				kind = "gun"
				s = 20.0 + wb.price() / 50.0 - d
		elif it is PerkMachine and it.can_interact(player) and it.get_prompt(player) != "":
			kind = "perk"
			label = str((it as PerkMachine).perk_id)
			var cost: int = int((it as PerkMachine)._data().get("cost", 99999))
			if scrip >= cost:
				s = 45.0 - d + (10.0 if label == "ironhide_stout" else 0.0)
		elif it is PowerSwitch and it.can_interact(player) and it.get_prompt(player) != "":
			kind = "power"
			label = "switch"
			s = 50.0 - d
		elif it is BuyDoor and not (it as BuyDoor).is_open and it.can_interact(player):
			var door: BuyDoor = it as BuyDoor
			var cellar_first: bool = door.door_id != &"door_cellar" and _cellar_closed() and scrip < door.cost + 2500
			if scrip >= door.cost + 400 and not cellar_first:
				kind = "door"
				label = door.label
				s = (55.0 if door.door_id == &"door_cellar" else 10.0) - d   # the cellar = perks
		if kind != "" and s > best_s:
			best_s = s
			best = {"node": it, "kind": kind, "label": label}
	return best


# ------------------------------------------------------------------------------------------------ bug watch

func _watch_zombies(delta: float) -> void:
	var seen: Dictionary = {}
	_z_hist_t -= delta
	var sample: bool = _z_hist_t <= 0.0
	if sample:
		_z_hist_t = 1.0
	for z: Zombie in director.active_zombies():
		var id: int = z.get_instance_id()
		seen[id] = true
		if z.global_position.y < -15.0:
			_issue("zombie fell out of the world near %s" % _v(Vector3(z.global_position.x, 0, z.global_position.z).snapped(Vector3.ONE * 2)))
			continue
		if sample:
			var h: Array = _z_hist.get(id, [])
			h.append("%.0f:%s%s" % [_t, _v(z.global_position.snapped(Vector3.ONE * 0.1)), str(Zombie.State.keys()[z.state]).substr(0, 2)])
			if h.size() > 40:
				h.pop_front()
			_z_hist[id] = h
		if not _z_origin.has(id):
			_z_origin[id] = [z.global_position, RoundManager.current_round, Zombie.State.keys()[z.state]]
		var tr: Dictionary = _z_track.get(id, {})
		if tr.is_empty() or z.global_position.distance_to(tr["pos"]) > 1.0 or z.state != tr["state"]:
			_z_track[id] = {"pos": z.global_position, "t": 0.0, "state": z.state}
			continue
		tr["t"] = float(tr["t"]) + delta
		var limit: float = 30.0 if z.state in [Zombie.State.WAIT_WINDOW, Zombie.State.TEAR] else 20.0
		if float(tr["t"]) > limit and not bool(tr.get("flag", false)):
			tr["flag"] = true
			var org: Array = _z_origin.get(id, [Vector3.ZERO, 0, "?"])
			print("[bot]     idle zombie %s: clear_to_player=%s zone=%s hp %.0f | first seen r%d at %s in %s | window %s" % [z.enemy_id, z.call("_clear_to", player),
				ZoneVolume.zone_at(get_tree(), z.global_position), z.hp, org[1], _v(org[0]), org[2], z.window.window_id if z.window != null else "-"])
			print("[bot]     trail: ", " ".join(PackedStringArray(_z_hist.get(id, []))))
			var dq: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(z.global_position + Vector3.UP * 0.3, z.global_position + Vector3.DOWN * 3.0, 0xFFFFFFFF, [z.get_rid()])
			var dh: Dictionary = z.get_world_3d().direct_space_state.intersect_ray(dq)
			var cq: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
			var cap: CapsuleShape3D = CapsuleShape3D.new()
			cap.radius = 0.5
			cap.height = 2.6
			cq.shape = cap
			cq.transform = Transform3D(Basis(), z.global_position + Vector3(0, 0.2, 0))
			cq.exclude = [z.get_rid()]
			var near_bodies: Array = z.get_world_3d().direct_space_state.intersect_shape(cq, 8).map(func(h: Dictionary) -> String: return str((h["collider"] as Node).get_path()).get_file())
			var slides: Array = []
			for si: int in z.get_slide_collision_count():
				slides.append("%s n%s" % [str((z.get_slide_collision(si).get_collider() as Node).name), z.get_slide_collision(si).get_normal().snapped(Vector3.ONE * 0.1)])
			print("[bot]     overlaps %s | slides %s" % [near_bodies, slides])
			print("[bot]     standing on: %s at y %.2f (on_floor %s, crawler %s, vel %s)" % [(dh["collider"] as Node).get_path() if dh else "nothing", (dh["position"] as Vector3).y if dh else 0.0,
				z.is_on_floor(), z.is_crawler, z.velocity.snapped(Vector3.ONE * 0.1)])
			_issue("zombie idle >%ds in %s at %s (player at %s)" % [int(limit), Zombie.State.keys()[z.state],
				_v(z.global_position.snapped(Vector3.ONE)), _v(player.global_position.snapped(Vector3.ONE))])
	for id: int in _z_track.keys():
		if not seen.has(id):
			_z_track.erase(id)
	for id: int in _z_origin.keys():
		if not seen.has(id):
			_z_origin.erase(id)
			_z_hist.erase(id)


func _snap_shot() -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(_shots_dir.path_join("pt_%03d_r%02d.png" % [_shot_n, RoundManager.current_round]))
	_shot_n += 1


func _finish(why: String) -> void:
	if _done:
		return
	_done = true
	_release_all()
	Input.action_release(&"interact")
	_phys_us.sort()
	var p50: float = _phys_us[_phys_us.size() / 2] if not _phys_us.is_empty() else 0.0
	var p99: float = _phys_us[int(_phys_us.size() * 0.99)] if not _phys_us.is_empty() else 0.0
	print("[bot] REPORT ----------------------------------------------------")
	print("[bot] end: %s | round %d | game time %.1f min | god=%s | bots=%d" % [why, RoundManager.current_round, _t / 60.0, god, bots])
	if bots > 0:
		print("[bot] squad: bot kills %d (vs mine %d), bot downs %d, bots revived me %d times, bots revived each other %d times" % [bot_kills, kills, bot_downs, revived_by_bot, bot_revives])
		var sq: BotSquad = get_tree().get_first_node_in_group(&"bot_squad") as BotSquad
		if sq != null:
			for line: String in sq.report():
				print("[bot]   ", line)

	print("[bot] kills %d (headshots %d, %.0f%%) | trigger pulls %d | downs %d | damage taken %.0f" % [
		kills, heads, 100.0 * heads / maxf(1, kills), shots, downs, damage_taken])
	print("[bot] movement: slides %d, slide-jumps %d, slide issues %d | kit: perks=%s crucible=%d %s" % [player.slides, player.slide_jumps, slide_issues, give_perks, crucible_tier, gun_id])
	print("[bot] rounds fired %d, hit events %d (%.0f%% hit rate), %.1f rounds per kill" % [fired, hits, 100.0 * hits / maxf(1, fired), fired / maxf(1, kills)])
	print("[bot] frame ms (real, incl. bot) p50 %.2f p99 %.2f max %.0f" % [p50, p99, _phys_us.back() if not _phys_us.is_empty() else 0.0])
	for r: Dictionary in rounds:
		print("[bot]   r%-2d %4.0fs kills %3d dmg %4.0f scrip %5d %s maxalive %d" % [r["round"], r["secs"], r["kills"], r["dmg"], r["scrip"], r["weapon"], r["max_alive"]])
	print("[bot] purchases: ", ", ".join(purchases))
	print("[bot] denied: ", ", ".join(denied.slice(0, 12)))
	print("[bot] powerups: ", ", ".join(powerups))
	print("[bot] perks: ", PerkManager.get("_owned"))
	print("[bot] issues (%d kinds):" % issues.size())
	for k: String in issues.keys():
		print("[bot]   x%d  %s" % [issues[k], k])
	print("[bot] RESULT ", "REACHED" if RoundManager.current_round > target_rounds else "DID NOT REACH", " round ", target_rounds)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE))
	get_tree().quit()
