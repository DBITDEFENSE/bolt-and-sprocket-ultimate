class_name Undertow
extends RefCounted
## THE UNDERTOW (UPDATE 10 contract C4, design section 5, docs/gravelight/WEAPONS.md section 11, DECISIONS T-153):
## Totenhafen's buildable wonder, a pressurised Nachtglas harpoon gun on a diver's pump. One instance per
## WeaponHolder (made on first use); WeaponHolder._tick_harpoon / _animate_reload delegate here, as the Lodestone's do.
##
##   Fire       = the harpoon flies `range` m and skewers up to `pierce` zombies in a `corridor_m` line
##                (skewer_health_mult x health(r) each); the chain reels them in over `reel_s` and they arrive
##                stunned (`stun_s`) in a heap `arrive_m` from the shooter. Bosses take `boss_damage`, never reeled.
##   Water      = fired into a flooded box (TideController.wet_box_index), the harpoon opens a whirlpool
##                (`whirl_radius` m, `whirl_seconds`): non-boss zombies in it are dragged under (a kill), bosses
##                take `whirl_dps`.
##   Reload     = three pump strokes (`reload_partial` 2.1 s): mag 1, reserve 12.
## MAELSTROM (`undertow_maelstrom`, the Crucible): the whirl opens on land too (`land_radius`, `land_seconds`, a violet
## vortex), the harpoon chains to the next target within `chain_radius` m up to `chain` times, reserve 18.
## The pure rules are static (tests: gravelight/tests/unit/test_undertow.gd). Bots: bot_fire.

const MASK_LOS: int = 1 | (1 << 8)          # world | doors

static var last_result: Dictionary = {}

var holder: WeaponHolder
var _cd: float = 0.0
var _pressure: float = 1.0       # 0..1 the gauge (drops on a shot, the pump strokes refill it)
var _shiver: float = 0.0
var _pump_k: float = 0.0         # 0..1 the pump handle's travel (the reload's strokes)


func _init(h: WeaponHolder) -> void:
	holder = h


# ================================================================== pure rules (static, tested)

static func is_boss(z: Zombie) -> bool:
	return z is Foreman or z is Screamer or z is HomageBoss


static func cfg(w: WeaponInstance) -> Dictionary:
	return w.data.get("harpoon", {})


## Which of `points` (chest positions) the harpoon skewers from `origin` along `fwd`: inside the `corridor` (m from
## the ray), ahead of the muzzle, closer than `max_dist` (the range or the first wall), nearest first, at most `n`.
## Returns the indices into `points`.
static func pierce_line(origin: Vector3, fwd: Vector3, points: Array, max_dist: float, corridor: float, n: int) -> Array:
	var f: Vector3 = fwd.normalized()
	var cands: Array = []
	for i: int in points.size():
		var p: Vector3 = points[i]
		var rel: Vector3 = p - origin
		var along: float = rel.dot(f)
		if along <= 0.3 or along > max_dist:
			continue
		var perp: float = (rel - f * along).length()
		if perp <= corridor:
			cands.append([along, i])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var out: Array = []
	for k: int in mini(n, cands.size()):
		out.append(int(cands[k][1]))
	return out


## Where a skewered body is `t` seconds into the reel: from `start` toward the shooter, ending `arrive_m` short.
static func reel_position(start: Vector3, shooter: Vector3, t: float, reel_s: float, arrive_m: float) -> Vector3:
	var to: Vector3 = shooter - start
	to.y = 0.0
	var d: float = to.length()
	if d <= arrive_m:
		return start
	var goal: Vector3 = start + to.normalized() * (d - arrive_m)
	var k: float = clampf(t / maxf(0.05, reel_s), 0.0, 1.0)
	return start.lerp(goal, k)


## The constant speed that carries a body from `start` to `arrive_m` short of `shooter` in `reel_s` (m/s, flat).
static func reel_velocity(start: Vector3, shooter: Vector3, reel_s: float, arrive_m: float) -> Vector3:
	var to: Vector3 = shooter - start
	to.y = 0.0
	var d: float = to.length()
	if d <= arrive_m + 0.05:
		return Vector3.ZERO
	return to.normalized() * ((d - arrive_m) / maxf(0.05, reel_s))


## The whirl this impact opens: {radius, seconds, land} or {} for none (dry ground without Maelstrom).
static func whirl_for(h: Dictionary, wet: bool) -> Dictionary:
	if wet:
		return {"radius": float(h.get("whirl_radius", 4.0)), "seconds": float(h.get("whirl_seconds", 6.0)), "land": false}
	if bool(h.get("whirl_land", false)):
		return {"radius": float(h.get("land_radius", 3.0)), "seconds": float(h.get("land_seconds", 5.0)), "land": true}
	return {}


## Is `p` inside a whirl at `center` of `radius` (flat distance, within 3 m of height)?
static func in_whirl(p: Vector3, center: Vector3, radius: float) -> bool:
	return Vector2(p.x - center.x, p.z - center.z).length() <= radius and absf(p.y - center.y) < 3.0


## Maelstrom's chain: the nearest of `points` within `radius` of `from` whose index is not in `taken` (-1 = none).
static func chain_pick(from: Vector3, points: Array, taken: Dictionary, radius: float) -> int:
	var best: int = -1
	var bd: float = radius
	for i: int in points.size():
		if taken.has(i):
			continue
		var d: float = (points[i] as Vector3).distance_to(from)
		if d <= bd:
			bd = d
			best = i
	return best


static func round_health() -> float:
	return float(RoundManager.zombie_health(maxi(1, RoundManager.current_round), GLData.table("rounds")))


static func skewer_damage(round_hp: float, h: Dictionary) -> float:
	return float(h.get("skewer_health_mult", 0.6)) * round_hp


## Is this point in a flooded box (the tide's water)?
static func is_wet(ctx: Node, p: Vector3) -> bool:
	if ctx == null or not ctx.is_inside_tree():
		return false
	var t: Node = ctx.get_tree().get_first_node_in_group(&"tide")
	if t == null or not t.has_method("wet_box_index"):
		return false
	return int(t.call("wet_box_index", p + Vector3.UP * 0.2)) >= 0


## One harpoon from `origin` along `fwd`: skewers the line (and Maelstrom's chain), reels them, opens the whirl at
## the impact if it is wet (or on land with Maelstrom). Returns {skewered: [Zombie], bosses: n, chained: n,
## impact: Vector3, whirl: Node3D or null, killed: n}.
static func resolve_shot(ctx: Node3D, origin: Vector3, fwd: Vector3, w: WeaponInstance, pid: int, shooter_pos: Vector3) -> Dictionary:
	var h: Dictionary = cfg(w)
	var f: Vector3 = fwd.normalized()
	var rng: float = float(h.get("range", 25.0))
	var out: Dictionary = {"skewered": [], "bosses": 0, "chained": 0, "impact": origin + f * rng, "whirl": null, "killed": 0}
	if ctx == null or not ctx.is_inside_tree():
		return out
	# the first wall along the line
	var wall_d: float = rng
	var space: PhysicsDirectSpaceState3D = ctx.get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + f * rng, MASK_LOS)
	var hit: Dictionary = space.intersect_ray(q)
	if not hit.is_empty():
		wall_d = origin.distance_to(hit["position"])
		out["impact"] = hit["position"]
	else:
		# nothing hit: the harpoon comes down at the end of its flight; find the floor under it
		var end: Vector3 = origin + f * rng
		var down: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(end, end + Vector3.DOWN * 12.0, MASK_LOS))
		if not down.is_empty():
			out["impact"] = down["position"]
	var dir: Node = ctx.get_tree().get_first_node_in_group(&"director")
	var zs: Array = []
	if dir != null and dir.has_method("active_zombies"):
		zs = dir.call("active_zombies")
	var chests: Array = []
	for z: Zombie in zs:
		chests.append(z.global_position + Vector3.UP * 1.1)
	var picks: Array = pierce_line(origin, f, chests, wall_d, float(h.get("corridor_m", 0.9)), int(h.get("pierce", 5)))
	var taken: Dictionary = {}
	for i: int in picks:
		taken[i] = true
	# Maelstrom: the chain jumps on from the last body in the line (or the impact)
	var chain_n: int = int(h.get("chain", 0))
	if chain_n > 0:
		var from: Vector3 = chests[picks[-1]] if not picks.is_empty() else (out["impact"] as Vector3)
		for c: int in chain_n:
			var j: int = chain_pick(from, chests, taken, float(h.get("chain_radius", 6.0)))
			if j < 0:
				break
			taken[j] = true
			picks.append(j)
			from = chests[j]
			out["chained"] = int(out["chained"]) + 1
	var hr: float = round_health()
	var dmg: float = skewer_damage(hr, h)
	var reel_s: float = float(h.get("reel_s", 1.2))
	var arrive: float = float(h.get("arrive_m", 2.0))
	var stun: float = float(h.get("stun_s", 2.0))
	for i2: int in picks:
		var z2: Zombie = zs[i2]
		if is_boss(z2):
			z2.take_damage(float(h.get("boss_damage", 900.0)), &"torso", w.id, pid, &"wonder", true)
			out["bosses"] = int(out["bosses"]) + 1
			continue
		var killed: bool = z2.take_damage(dmg, &"torso", w.id, pid, &"wonder", true)
		if killed:
			out["killed"] = int(out["killed"]) + 1
			continue
		(out["skewered"] as Array).append(z2)
		var v: Vector3 = reel_velocity(z2.global_position, shooter_pos, reel_s, arrive)
		if v.length_squared() > 0.0001:
			z2.external_push(v, reel_s, pid, w.id, 0.0)
		_stun_after(ctx, z2, reel_s, stun)
	# the whirl at the impact
	var impact: Vector3 = out["impact"]
	var wh: Dictionary = whirl_for(h, is_wet(ctx, impact))
	if not wh.is_empty():
		var whirl: UndertowWhirl = UndertowWhirl.new()
		whirl.setup(w.id, pid, float(wh["radius"]), float(wh["seconds"]), bool(wh["land"]), h)
		var host: Node = ctx.get_tree().current_scene if ctx.get_tree().current_scene != null else ctx.get_tree().root
		host.add_child(whirl)
		whirl.global_position = impact
		out["whirl"] = whirl
	last_result = out
	return out


## The reeled body arrives stunned (a full frost + a stagger) when the chain has pulled it in.
static func _stun_after(ctx: Node, z: Zombie, delay: float, stun: float) -> void:
	ctx.get_tree().create_timer(delay).timeout.connect(func() -> void:
		if is_instance_valid(z) and z.is_active():
			z.apply_frost(1.0, stun)
			z.force_stagger())


# ================================================================== bots

## A bot fires the harpoon along its facing (the brain aims at the nearest; the line takes the rest).
static func bot_fire(p: Player, w: WeaponInstance, origin: Vector3, fwd: Vector3, pay: bool = true) -> Dictionary:
	var h: Dictionary = cfg(w)
	if pay:
		if w.mag <= 0:
			return {"skewered": []}
		w.mag -= 1
	var res: Dictionary = resolve_shot(p, origin, fwd, w, p.player_id, p.global_position)
	AudioDirector.play_3d(str(h.get("fire_sound", "undertow_fire")), origin, 0.0, 0.0)
	GLBus.weapon_fired.emit(p.player_id, w.id, w.upgraded, origin, fwd)
	for _z: Variant in res.get("skewered", []):
		GLBus.enemy_hit_feedback.emit(p.player_id, false, false)
	return res


# ================================================================== per-frame (the holder's player)

func tick(w: WeaponInstance, delta: float, _held: bool, pressed: bool) -> void:
	_cd = maxf(0.0, _cd - delta)
	_shiver += delta * 23.0
	if not holder.is_reloading():
		_pressure = move_toward(_pressure, 1.0 if w.mag > 0 else 0.08, delta * 0.8)
		_pump_k = move_toward(_pump_k, 0.0, delta * 4.0)
	if not pressed:
		return
	if w.mag <= 0:
		AudioDirector.play_2d("gun_dry", -4.0)
		holder.start_reload()
		return
	if _cd <= 0.0:
		fire(w)


func fire(w: WeaponInstance) -> void:
	var h: Dictionary = cfg(w)
	var p: Player = holder.player
	var cam: Camera3D = p.camera
	if cam == null:
		return
	w.mag = maxi(0, w.mag - 1)
	holder._fired_this_frame = true
	var origin: Vector3 = cam.global_position
	var fwd: Vector3 = -cam.global_basis.z
	GLBus.weapon_fired.emit(p.player_id, w.id, w.upgraded, origin, fwd)
	var res: Dictionary = resolve_shot(holder, origin, fwd, w, p.player_id, p.global_position)
	_cd = float(h.get("cooldown", 0.35))
	_pressure = 0.1
	AudioDirector.play_2d(str(h.get("fire_sound", "undertow_fire")), 0.0, 0.04)
	if not (res["skewered"] as Array).is_empty():
		AudioDirector.play_2d(str(h.get("reel_sound", "undertow_reel")), -3.0, 0.05)
	holder._vm_kick(2.6)
	holder._on_shot_fx(0.08)
	p.kick_camera(3.2, 0.8, 0.15, 6.5, 0.4, 2.5)
	Totenglocke.rumble(p, 0.5, 0.6, 0.25)
	var head_to: Vector3 = res["impact"]
	if not (res["skewered"] as Array).is_empty():
		head_to = ((res["skewered"] as Array)[0] as Zombie).global_position + Vector3.UP * 1.1
	var muzzle: Vector3 = origin + fwd * 0.6 + Vector3.DOWN * 0.12
	UndertowChain.draw(holder, muzzle, head_to, float(h.get("reel_s", 1.2)), color_of(h), res["skewered"])
	for _z: Variant in res["skewered"]:
		GLBus.enemy_hit_feedback.emit(p.player_id, false, false)
	for _k: int in int(res["killed"]):
		GLBus.enemy_hit_feedback.emit(p.player_id, true, false)
	if res["whirl"] != null:
		AudioDirector.play_3d(str(h.get("whirl_sound", "undertow_whirl")), head_to, 0.0, 0.0)
	if (res["skewered"] as Array).size() >= 4:
		Totenglocke.hitstop(holder.get_tree(), 0.3, 0.1)
	if w.mag <= 0 and w.reserve > 0:
		holder.get_tree().create_timer(float(h.get("reel_s", 1.2)) * 0.6).timeout.connect(holder.start_reload)
	holder._ammo_warnings(w)


func pressure() -> float:
	return _pressure


static func color_of(h: Dictionary) -> Color:
	var c: Array = h.get("color", [0.55, 0.35, 0.95])
	return Color(float(c[0]), float(c[1]), float(c[2]))


## The viewmodel's moving parts: the gauge needle (pressure, shivering with the hum), the harpoon shown while
## loaded, the pump handle's travel. Called from WeaponHolder._animate every frame.
func pose_parts(model: Node3D, w: WeaponInstance) -> void:
	if model == null:
		return
	var needle: Node3D = model.get_node_or_null("Gauge/Needle") as Node3D
	if needle != null:
		needle.rotation.x = deg_to_rad(-120.0 + 240.0 * _pressure + sin(_shiver) * 3.0)
	var harpoon: Node3D = model.get_node_or_null("Harpoon") as Node3D
	if harpoon != null and w != null:
		harpoon.visible = w.mag > 0 or (holder.is_reloading() and _pump_k > 0.5)
	var pump: Node3D = model.get_node_or_null("Pump") as Node3D
	if pump != null:
		pump.position.z = float(pump.get_meta("z0", pump.position.z)) + 0.07 * _pump_k
		if not pump.has_meta("z0"):
			pump.set_meta("z0", pump.position.z)


## The reload: three pump strokes; the left hand rides the pump handle. Returns the left hand's target.
func reload_hand(p: float, model: Node3D, lh_home: Vector3) -> Variant:
	var stroke: float = clampf(p / 0.9, 0.0, 1.0) * 3.0
	var k: float = 1.0 - absf(fmod(stroke, 1.0) * 2.0 - 1.0)   # 0 -> 1 -> 0 per stroke
	_pump_k = k if p < 0.9 else 0.0
	_pressure = clampf(p, 0.0, 1.0)
	var pump: Node3D = model.get_node_or_null("Pump") as Node3D if model != null else null
	if pump == null:
		return null
	var z0: float = float(pump.get_meta("z0", pump.position.z))
	return Vector3(pump.position.x, pump.position.y - 0.005, z0 + 0.07 * _pump_k)
