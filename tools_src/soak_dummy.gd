extends RefCounted
## The AI soak's scripted "player" (Update 03 section 0): drives the real local Player (pid 1) through the same
## input actions a person presses, so the bots follow it, get out of its way (or don't), revive it, and zombies
## hunt it like a human. Much simpler than tools_src/playtest_gl.gd on purpose: it is the bots' test load, not a
## player under test, and it should behave the same from one bot brain to the next.
##   - runs a fixed training loop on the navmesh, forever, rounds and breaks alike: on Map 0 clockwise around the
##     taproom tables and bar, and, once the stable door (Door 2) is open (the bots buy doors), out through the
##     kitchen door and round the stable before coming back (the taproom-to-stable loop); on another map a ring
##     of reachable points around the spawn. It turns back when the next stretch of the loop is full of zombies.
##   - shoots the nearest zombie in sight within ENGAGE_M (a human reaction delay, a capped turn rate, aim noise,
##     heads), reloads when empty or when nothing is close, knifes what reaches it with an empty gun.
##   - kit "baseline" (the default, the Update 03 baseline's player): buys nothing: it carries the bots' spawn kit
##     (the Thompson, Ironhide Stout, Second Wind; again after a revive / respawn, like the bots) and its reserve is
##     topped up at every round start (it doesn't shop, and running dry would measure the dummy, not the bots).
##   - kit "realistic" (--player-kit=realistic, T-058): plays the economy like a person who knows the map: the
##     Thompson only (the gun a player buys early), no free perks; once it is calm (the break, or nothing within
##     10 m and a few zombies left) and it has the Scrip, it opens the way to the power (Map 0: the cellar door),
##     throws the power switch (by round 3-4), then drinks Ironhide Stout and Second Wind, and buys them again after
##     losing them to a down. The round-start reserve top-up stays (it doesn't buy ammo). It still revives nobody.
##   - can be downed (it then shoots from the ground with whatever it holds), revived and bleed out like anyone.

const TURN_RATE: float = 6.0       # rad/s
const AIM_NOISE: float = 0.02      # rad
const REACTION: float = 0.25       # s
const ENGAGE_M: float = 14.0
const REACH_M: float = 0.9         # a loop point counts as reached this close (flat)
const BLOCKED_SEG_R: float = 1.4   # a zombie this close to the next stretch blocks it...
const BLOCKED_AHEAD_M: float = 7.0 # ...when it is this close to us
## Map 0 loop (clockwise seen from above, north = -z): round the middle tables, east of the bar.
const MAP00_TAPROOM: Array[Vector3] = [Vector3(10.5, 0, 3.0), Vector3(16.5, 0, 2.4), Vector3(22.2, 0, 2.6), Vector3(22.2, 0, 9.0),
	Vector3(19.4, 0, 14.4), Vector3(14.5, 0, 14.2), Vector3(10.2, 0, 13.6), Vector3(10.4, 0, 6.5)]
## Spliced in after the taproom loop's 5th point when the stable door is open: down the yard passage, round the
## east half of the stable (the hay stairs block the middle), and back.
const MAP00_STABLE: Array[Vector3] = [Vector3(20.0, 0, 15.4), Vector3(20.0, 0, 19.0), Vector3(20.2, 0, 23.8), Vector3(22.6, 0, 27.5),
	Vector3(21.8, 0, 32.6), Vector3(18.4, 0, 31.5), Vector3(18.4, 0, 26.8), Vector3(20.0, 0, 23.8), Vector3(20.0, 0, 19.0), Vector3(20.0, 0, 15.4)]

## "baseline" or "realistic" (see the class doc).
var kit: String = "baseline"
## Realistic kit: the perks it drinks, in order, once the power is on.
const REALISTIC_PERKS: Array[StringName] = [&"ironhide_stout", &"second_wind"]
## Realistic kit: from this round it goes for the power as soon as it can afford the way there.
const POWER_FROM_ROUND: int = 2
var power_round: int = 0
var perks_bought: int = 0
var doors_bought: int = 0

var player: Player
var map: MapRoot
var squad: BotSquad
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var laps: int = 0
var reversals: int = 0
var route_name: String = ""

var _route: PackedVector3Array = PackedVector3Array()
var _stable_open: bool = false
var _i: int = 0
var _dir: int = 1
var _path: PackedVector3Array = PackedVector3Array()
var _path_i: int = 0
var _repath_t: float = 0.0
var _rev_cd: float = 0.0
var _target: Zombie = null
var _engage_t: float = 0.0
var _toggle: bool = false
var _was_down: bool = false
var _was_out: bool = false
var _start_i: int = 0
## Realistic kit: the errand under way ({} none): {node, stand, kind}.
var _errand: Dictionary = {}
var _errand_t: float = 0.0
var _errand_cd: float = 0.0
var _stuck_t: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO
## Harness safeguard count: times the scripted player was put back on its loop after 15 s pinned.
var unstuck: int = 0


func setup(p: Player, m: MapRoot, seed_value: int, kit_mode: String = "baseline") -> void:
	player = p
	map = m
	squad = m.squad
	kit = kit_mode
	rng.seed = seed_value
	_give_kit(true)
	GLBus.round_started.connect(_on_round_started)
	GLBus.power_activated.connect(_on_power)
	_build_route()


## The kit: baseline = the bots' spawn kit (guns + free perks); realistic = the Thompson only.
func _give_kit(weapons: bool) -> void:
	if kit != "realistic":
		if squad != null:
			squad.apply_kit(player, weapons)
		return
	if not weapons or player.weapons == null:
		return
	var has: bool = false
	for w: WeaponInstance in player.weapons.slots:
		has = has or w.base_id() == &"thompson"
	if not has:
		player.weapons.give_weapon(&"thompson")
	for k: int in player.weapons.slots.size():
		if player.weapons.slots[k].base_id() == &"thompson":
			player.weapons.current_index = k


func _on_power() -> void:
	if power_round == 0:
		power_round = RoundManager.current_round


func shutdown() -> void:
	if GLBus.round_started.is_connected(_on_round_started):
		GLBus.round_started.disconnect(_on_round_started)
	if GLBus.power_activated.is_connected(_on_power):
		GLBus.power_activated.disconnect(_on_power)
	_release()


func _on_round_started(_r: int, _special: bool) -> void:
	if player == null or not is_instance_valid(player) or player.weapons == null:
		return
	for w: WeaponInstance in player.weapons.slots:
		w.reserve = w.reserve_max()


func _nav() -> RID:
	return player.get_world_3d().navigation_map


func _build_route() -> void:
	var pts: Array[Vector3] = []
	_stable_open = false
	if map.map_id == &"map00_crossroads":
		_stable_open = _door_open(&"door_stable")
		for k: int in MAP00_TAPROOM.size():
			pts.append(MAP00_TAPROOM[k])
			if k == 4 and _stable_open:
				pts.append_array(MAP00_STABLE)
		route_name = "map00 taproom" + (" + stable" if _stable_open else "")
	else:
		var c: Vector3 = player.global_position
		for k2: int in 10:
			var a: float = float(k2) / 10.0 * TAU
			pts.append(c + Vector3(cos(a), 0.0, sin(a)) * 6.5)
		route_name = "ring round the spawn"
	var keep: PackedVector3Array = PackedVector3Array()
	for p: Vector3 in pts:
		var s: Vector3 = NavigationServer3D.map_get_closest_point(_nav(), p + Vector3.UP * 0.5)
		if Vector2(s.x - p.x, s.z - p.z).length() < 1.2:
			keep.append(s)
	_route = keep
	# start at the loop point nearest to us
	var best: float = INF
	for k3: int in _route.size():
		var d: float = _flat(_route[k3], player.global_position)
		if d < best:
			best = d
			_i = k3
	_start_i = _i
	_path = PackedVector3Array()


func _door_open(id: StringName) -> bool:
	for n: Node in player.get_tree().get_nodes_in_group(&"doors"):
		if n is BuyDoor and (n as BuyDoor).door_id == id:
			return (n as BuyDoor).is_open
	return false


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _release() -> void:
	for a: StringName in [&"fire", &"reload", &"melee", &"interact", &"swap_weapon", &"move_forward", &"move_back",
			&"move_left", &"move_right", &"sprint", &"crouch", &"jump", &"aim"]:
		if InputMap.has_action(a):
			Input.action_release(a)


## One physics frame of the dummy.
func tick(delta: float) -> void:
	_release()
	if player == null or not is_instance_valid(player) or GameState.phase != GameState.Phase.PLAYING:
		return
	if player.spectating:
		_was_out = true
		return
	if player.downed:
		_was_down = true
		_shoot(delta, _zombies(), true)
		return
	if _was_down or _was_out:
		_give_kit(_was_out)   # baseline: the kit again, like the bots (perks are lost on going down); realistic: rebuys
		_errand = {}
		_was_down = false
		_was_out = false
		_path = PackedVector3Array()
	if map.map_id == &"map00_crossroads" and _door_open(&"door_stable") != _stable_open:
		_build_route()
	_rev_cd -= delta
	_repath_t -= delta
	var zs: Array[Zombie] = _zombies()
	var aiming: bool = _shoot(delta, zs, false)
	if kit == "realistic":
		_errands(delta, zs)
	_walk(delta, zs, aiming)


# ---------------------------------------------------------------- the realistic kit's shopping

## Picks and runs the next errand: the way to the power, the power switch, then the perks (and their rebuys).
## Only when it is calm; an errand that takes over 40 s is dropped (and the next try waits 10 s).
func _errands(delta: float, zs: Array[Zombie]) -> void:
	_errand_cd -= delta
	var near_d: float = INF
	for z: Zombie in zs:
		near_d = minf(near_d, z.global_position.distance_to(player.global_position))
	var calm: bool = near_d > 10.0 and (RoundManager.state != RoundManager.State.ROUND or zs.size() <= 3)
	if not _errand.is_empty():
		_errand_t += delta
		var n: Node = _errand.get("node")
		if n == null or not is_instance_valid(n) or _errand_t > 40.0 or near_d < 3.0:
			if _errand_t > 40.0:
				print("[dummy] r%d gave up on %s at %s (stand %s)" % [RoundManager.current_round, str(_errand.get("kind", "")), str(player.global_position), str(_errand.get("stand", ""))])
			_errand_cd = 10.0 if _errand_t > 40.0 else 2.0
			_errand = {}
			return
		var st: Vector3 = _errand["stand"]
		if _flat(st, player.global_position) < 1.2 and absf(st.y - player.global_position.y) < 1.6:
			var it: Interactable = n as Interactable
			if it != null and it.can_interact(player):
				var before: int = Economy.get_scrip(player.player_id)
				it.interact(player)
				if Economy.get_scrip(player.player_id) < before or GameState.power_on:
					print("[dummy] r%d %s %s (%d Scrip left)" % [RoundManager.current_round, str(_errand["kind"]), n.name, Economy.get_scrip(player.player_id)])
				if Economy.get_scrip(player.player_id) < before:
					if str(_errand["kind"]) == "perk":
						perks_bought += 1
					elif str(_errand["kind"]) == "door":
						doors_bought += 1
			_errand = {}
			_errand_cd = 1.5
		return
	if not calm or _errand_cd > 0.0:
		return
	_errand = _next_errand()
	_errand_t = 0.0
	_path = PackedVector3Array()


func _next_errand() -> Dictionary:
	var scrip: int = Economy.get_scrip(player.player_id)
	var me: Vector3 = player.global_position
	if not GameState.power_on:
		if RoundManager.current_round < POWER_FROM_ROUND:
			return {}
		for n: Node in player.get_tree().get_nodes_in_group(&"power_switch"):
			var sw: PowerSwitch = n as PowerSwitch
			if sw == null or not sw.can_interact(player):
				continue
			var st: Vector3 = _stand(BotBrain._front_of(sw))
			if _reachable(st):
				return {"node": sw, "stand": st, "kind": "power"}
			# the way to it: the closed door its path crosses that we can reach and afford
			var path: PackedVector3Array = NavigationServer3D.map_get_path(_nav(), me, _stand(sw.global_position), true)
			for d: Node in player.get_tree().get_nodes_in_group(&"doors"):
				var bd: BuyDoor = d as BuyDoor
				if bd == null or bd.is_open or not ZombieDirector.door_crossed(bd, path) or scrip < bd.cost:
					continue
				var ds: Vector3 = _stand(BotBrain._door_side(bd, me))
				if _reachable(ds):
					return {"node": bd, "stand": ds, "kind": "door"}
		return {}
	for perk: StringName in REALISTIC_PERKS:
		if PerkManager.has_perk(player.player_id, perk):
			continue
		for n2: Node in player.get_tree().get_nodes_in_group(&"perk_machines"):
			var pm: PerkMachine = n2 as PerkMachine
			if pm == null or pm.perk_id != perk or not pm.can_interact(player) or scrip < PerkManager.price(perk):
				continue
			var st2: Vector3 = _stand(BotBrain._front_of(pm))
			if _reachable(st2):
				return {"node": pm, "stand": st2, "kind": "perk"}
		return {}   # saving for this one first
	return {}


func _stand(p: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(_nav(), p)


## A path that ends at `p` and crosses no closed door.
func _reachable(p: Vector3) -> bool:
	var path: PackedVector3Array = NavigationServer3D.map_get_path(_nav(), player.global_position, p, true)
	if path.is_empty() or path[path.size() - 1].distance_to(p) > 1.2:
		return false
	for d: Node in player.get_tree().get_nodes_in_group(&"doors"):
		if d is BuyDoor and not (d as BuyDoor).is_open and ZombieDirector.door_crossed(d as BuyDoor, path):
			return false
	return true


func _zombies() -> Array[Zombie]:
	var out: Array[Zombie] = []
	if map.director == null:
		return out
	for z: Zombie in map.director.active_zombies():
		if is_instance_valid(z) and z.state != Zombie.State.DEAD and z.state != Zombie.State.INACTIVE and z.state != Zombie.State.EMERGE:
			out.append(z)
	return out


# ---------------------------------------------------------------- shooting

func _los(p: Vector3) -> bool:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(player.camera.global_position, p, 1 | (1 << 8))
	q.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _aim_point(z: Zombie) -> Vector3:
	var hbs: Variant = z.get("_hitboxes")
	if hbs is Array:
		for hb: Variant in hbs:
			if hb is Hitbox and (hb as Hitbox).limb == &"head":
				return (hb as Hitbox).global_position
	return z.global_position + Vector3(0, 1.3, 0)


func _turn_toward(p: Vector3, dt: float, rate: float = TURN_RATE) -> float:
	var cam: Camera3D = player.camera
	var to: Vector3 = p - cam.global_position
	if to.length() < 0.01:
		return 0.0
	to = to.normalized()
	var fwd: Vector3 = -cam.global_basis.z
	var yaw_err: float = wrapf(atan2(-to.x, -to.z) - atan2(-fwd.x, -fwd.z), -PI, PI)
	var pitch_err: float = asin(clampf(to.y, -1, 1)) - asin(clampf(fwd.y, -1, 1))
	var step: float = rate * dt
	var dy: float = clampf(yaw_err, -step, step) + rng.randfn(0.0, AIM_NOISE * 0.3)
	var dp: float = clampf(pitch_err, -step, step) + rng.randfn(0.0, AIM_NOISE * 0.3)
	player._apply_look(Vector2(-dy, -dp))
	return Vector2(yaw_err, pitch_err).length()


## Aims at and fires on the nearest zombie in sight; reloads, swaps, knifes. True while it has a target.
func _shoot(delta: float, zs: Array[Zombie], downed: bool) -> bool:
	var best: Zombie = null
	var bd: float = INF
	var near_d: float = INF
	for z: Zombie in zs:
		var d: float = z.global_position.distance_to(player.global_position)
		near_d = minf(near_d, d)
		if d < bd and d < ENGAGE_M and _los(_aim_point(z)):
			bd = d
			best = z
	if best != _target:
		_target = best
		_engage_t = REACTION
	_engage_t -= delta
	var w: WeaponInstance = player.weapons.current()
	if w == null:
		return _target != null
	var on: bool = false
	if _target != null:
		on = _turn_toward(_aim_point(_target), delta) < 0.05
	var busy: bool = player.weapons.is_busy()
	var reloading: bool = player.weapons.is_reloading()
	var other_loaded: bool = false
	for inst: WeaponInstance in player.weapons.slots:
		if inst != w and inst.mag > 0:
			other_loaded = true
	if w.mag == 0 and near_d < 1.6 and not downed and not other_loaded:
		Input.action_press(&"melee")
	elif w.mag == 0 and w.reserve == 0 and other_loaded and not busy:
		Input.action_press(&"swap_weapon")
	elif w.mag == 0 and w.reserve > 0 and not reloading:
		Input.action_press(&"reload")
	elif _target != null and on and _engage_t <= 0.0 and w.mag > 0 and not busy:
		_toggle = not _toggle
		if w.fire_mode == "auto" or _toggle:
			Input.action_press(&"fire")
	elif _target == null and near_d > 8.0 and w.mag < int(float(w.mag_size()) * 0.4) and w.reserve > 0 and not reloading:
		Input.action_press(&"reload")
	return _target != null


# ---------------------------------------------------------------- the loop

func _walk(delta: float, zs: Array[Zombie], aiming: bool) -> void:
	if _route.size() < 3:
		return
	var me: Vector3 = player.global_position
	# a harness safeguard (T-058): pinned against something for 6 s (a perk machine's corner after an errand), it
	# heads for another loop point; after 15 s it is put back on the loop (logged)
	_stuck_t = _stuck_t + delta if me.distance_to(_last_pos) < 0.02 else 0.0
	_last_pos = me
	if _stuck_t > 6.0 and fmod(_stuck_t, 3.0) < delta:
		_i = posmod(_i + 2, _route.size())
		_path = PackedVector3Array()
		_errand = {}
	if _stuck_t > 15.0:
		print("[dummy] r%d stuck at %s for 15 s: back on the loop" % [RoundManager.current_round, str(me.snapped(Vector3.ONE * 0.1))])
		player.global_position = _route[_i] + Vector3.UP * 0.2
		_stuck_t = 0.0
		unstuck += 1
		return
	var wp: Vector3 = _route[_i]
	var errand: bool = not _errand.is_empty()
	if errand:
		wp = _errand["stand"]   # the realistic kit's errand: walk there instead of the loop
	elif _flat(wp, me) < REACH_M and absf(wp.y - me.y) < 1.5:
		_advance()
		wp = _route[_i]
	# turn back when the stretch ahead is full of zombies (train them the other way)
	if not errand and _rev_cd <= 0.0 and _blocked(me, wp, zs):
		_dir = -_dir
		reversals += 1
		_rev_cd = 2.5
		_advance()
		wp = _route[_i]
	if _repath_t <= 0.0 or _path.is_empty() or _path_i >= _path.size():
		_path = NavigationServer3D.map_get_path(_nav(), me, wp, true)
		_path_i = 1 if _path.size() > 1 else 0
		_repath_t = 0.5
	if _path.is_empty() or _path_i >= _path.size():
		return
	var p: Vector3 = _path[_path_i]
	var flat: Vector3 = Vector3(p.x - me.x, 0.0, p.z - me.z)
	if flat.length() < 0.4:
		_path_i += 1
		return
	if not aiming:
		_turn_toward(Vector3(p.x, player.camera.global_position.y, p.z) + flat.normalized() * 4.0, delta, TURN_RATE * 0.6)
	var local: Vector3 = player.global_basis.inverse() * flat.normalized()
	var fwd: float = -local.z
	var right: float = local.x
	if fwd > 0.05:
		Input.action_press(&"move_forward", clampf(fwd, 0.0, 1.0))
	elif fwd < -0.05:
		Input.action_press(&"move_back", clampf(-fwd, 0.0, 1.0))
	if right > 0.05:
		Input.action_press(&"move_right", clampf(right, 0.0, 1.0))
	elif right < -0.05:
		Input.action_press(&"move_left", clampf(-right, 0.0, 1.0))


func _advance() -> void:
	_i = posmod(_i + _dir, _route.size())
	_path = PackedVector3Array()
	if _i == _start_i:
		laps += 1


func _blocked(me: Vector3, wp: Vector3, zs: Array[Zombie]) -> bool:
	var a: Vector2 = Vector2(me.x, me.z)
	var b: Vector2 = Vector2(wp.x, wp.z)
	var n: int = 0
	for z: Zombie in zs:
		var zp: Vector2 = Vector2(z.global_position.x, z.global_position.z)
		if absf(z.global_position.y - me.y) > 2.0 or zp.distance_to(a) > BLOCKED_AHEAD_M:
			continue
		if Geometry2D.get_closest_point_to_segment(zp, a, b).distance_to(zp) < BLOCKED_SEG_R and (zp - a).dot(b - a) > 0.0:
			n += 1
	return n >= 2 or (n >= 1 and zs.size() <= 2)
