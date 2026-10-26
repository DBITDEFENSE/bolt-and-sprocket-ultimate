class_name Lodestone
extends RefCounted
## THE LODESTONE (UPDATE 07, T-105; docs/MAP4_FERNFLUG.md section 8): the Groom Lake gravity caster, a Nachtglas lens
## in a brass gyro cradle on a yoke. One instance per WeaponHolder (made on first use); WeaponHolder._tick_gravity /
## _alt_fire delegate here, as the Totenglocke's do.
##
##   Tap fire   = LIFT: a well `lift_ahead` m ahead, `lift_radius` m: up to `max_targets` non-boss zombies are
##                lifted `lift_height` m and held `hold_seconds` (Zombie.lift; limb x `limb_mult_lifted`).
##   Tap again  = SLAM: the held zombies are slammed down (slam_health_mult x health(r): lethal to a Gänger of its
##                round) with a shockwave of `wave_radius` m round each impact. The hold running out = DROP
##                (drop_health_mult x health(r), a stagger). The slam is free: the lift paid.
##   Alt-fire   = FLING: a `fling_hold_s` wind-up, then every zombie in a cone ahead is thrown `fling_distance` m
##                (x fling_lowg_mult in low gravity) along the aim: fling_health_mult x health(r) on landing,
##                x1.5 into a wall, and a zombie that goes off a drop or into vacuum is gone (a "returned" kill).
##   Bosses     = never lifted: a `boss_stagger_s` stagger (and `boss_slam_damage` on Escape Velocity's slam).
##   Ballast    = the holder is immune to pulls and to its own slam wave (Player.lodestone_ballast).
##   Charges    = `lift_cost` a lift, `fling_cost` a fling; the Crucible refills (1000), Max Ammo, Magpie drops.
## Escape Velocity (`lodestone_up`): `pull_from_m` draws zombies into the well before the lift (pull_speed),
## 12 targets, a longer hold, a 3 m wave, an 18 m fling that bounces `fling_chain` times.
## The pure rules are static (tests: gravelight/tests/unit/test_lodestone.gd). Bots: bot_lift / bot_slam / bot_fling.

const MASK_LOS: int = 1 | (1 << 8)          # world | doors
const FLIGHT_S: float = 0.9                  # a fling's time in the air at 1 g
const FLING_UP: float = 3.5

static var last_result: Dictionary = {}

var holder: WeaponHolder
var _lifted: Array = []          # the Zombies held by this well
var _hold_t: float = 0.0
var _cd: float = 0.0
var _fling_t: float = -1.0       # the alt-fire wind-up, < 0 = none
var _pull_pass_t: float = -1.0   # Escape Velocity: the second lift pass after the pull
var _pull_origin: Vector3 = Vector3.ZERO
var _pull_fwd: Vector3 = Vector3.FORWARD
var _pull_ads: bool = false
var _spin: float = 0.0           # the sphere's spin (rad), for the viewmodel
var _spin_v: float = 2.0
var _ring_open: float = 0.0      # 0..1 the cradle rings open while a lift holds
var _coil_glow: float = 0.0      # 0..1 the fling charge


func _init(h: WeaponHolder) -> void:
	holder = h


# ================================================================== pure rules (static, tested)

static func is_boss(z: Zombie) -> bool:
	return z is Foreman or z is Screamer or z is HomageBoss


static func cfg(w: WeaponInstance) -> Dictionary:
	return w.data.get("gravity", {})


## Where the well sits for this aim: `lift_ahead` (or `_ads`) metres down the look.
static func well_center(origin: Vector3, fwd: Vector3, g: Dictionary, ads: bool) -> Vector3:
	return origin + fwd.normalized() * float(g.get("lift_ahead_ads", 7.0) if ads else g.get("lift_ahead", 5.0))


static func well_radius(g: Dictionary, ads: bool) -> float:
	return float(g.get("lift_radius_ads", 2.5) if ads else g.get("lift_radius", 4.0))


static func slam_damage(round_health: float, g: Dictionary) -> float:
	return float(g.get("slam_health_mult", 2.2)) * round_health


static func drop_damage(round_health: float, g: Dictionary) -> float:
	return float(g.get("drop_health_mult", 0.8)) * round_health


static func fling_damage(round_health: float, g: Dictionary) -> float:
	return float(g.get("fling_health_mult", 1.0)) * round_health


## How far a fling throws under this gravity (low gravity: x fling_lowg_mult).
static func fling_distance(g: Dictionary, gravity_scale: float) -> float:
	var d: float = float(g.get("fling_distance", 12.0))
	if gravity_scale < 0.7:
		d *= float(g.get("fling_lowg_mult", 2.5))
	return d


## The velocity that carries a body `distance` m along `fwd` in FLIGHT_S seconds, with a lift to clear the floor.
static func fling_velocity(fwd: Vector3, distance: float, gravity_scale: float = 1.0) -> Vector3:
	var flat: Vector3 = Vector3(fwd.x, 0.0, fwd.z)
	flat = flat.normalized() if flat.length_squared() > 0.0001 else Vector3.FORWARD
	var t: float = FLIGHT_S / sqrt(maxf(0.2, gravity_scale))
	return flat * (distance / t) + Vector3.UP * FLING_UP


## The seconds a fling's push lasts (its flight).
static func fling_seconds(gravity_scale: float = 1.0) -> float:
	return FLIGHT_S / sqrt(maxf(0.2, gravity_scale))


## The current gravity (GameState.gravity_scale when the Moon act sets it; else 1).
static func gravity_scale() -> float:
	var gs: Variant = GameState.get("gravity_scale")
	return float(gs) if gs != null else 1.0


## The nearest `n` active, un-lifted, non-boss zombies within `radius` of `center`.
static func pick_targets(zs: Array, center: Vector3, radius: float, n: int) -> Array:
	var cands: Array = []
	for z: Zombie in zs:
		if not z.is_active() or z.is_lifted() or is_boss(z):
			continue
		var d: float = Vector2(z.global_position.x - center.x, z.global_position.z - center.z).length()
		if d <= radius and absf(z.global_position.y - center.y) < 4.0:
			cands.append([d, z])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var out: Array = []
	for i: int in mini(n, cands.size()):
		out.append(cands[i][1])
	return out


## The bosses within the well (they take a stagger, never a lift).
static func bosses_in(zs: Array, center: Vector3, radius: float) -> Array:
	var out: Array = []
	for z: Zombie in zs:
		if z.is_active() and is_boss(z) and Vector2(z.global_position.x - center.x, z.global_position.z - center.z).length() <= radius:
			out.append(z)
	return out


static func round_health() -> float:
	return float(RoundManager.zombie_health(maxi(1, RoundManager.current_round), GLData.table("rounds")))


## One lift from `origin` along `fwd`: lifts what the well holds, staggers the bosses in it, pulls the outer ring
## in (Escape Velocity). Returns {lifted: [...], bosses: n, pulled: n, center}.
static func resolve_lift(ctx: Node3D, origin: Vector3, fwd: Vector3, w: WeaponInstance, pid: int, ads: bool) -> Dictionary:
	var g: Dictionary = cfg(w)
	var center: Vector3 = well_center(origin, fwd, g, ads)
	var out: Dictionary = {"lifted": [], "bosses": 0, "pulled": 0, "center": center}
	if ctx == null or not ctx.is_inside_tree():
		return out
	var dir: Node = ctx.get_tree().get_first_node_in_group(&"director")
	if dir == null or not dir.has_method("active_zombies"):
		return out
	var zs: Array = dir.call("active_zombies")
	var hr: float = round_health()
	var radius: float = well_radius(g, ads)
	var hold: float = float(g.get("hold_seconds", 2.5))
	for z: Zombie in pick_targets(zs, center, radius, int(g.get("max_targets", 8))):
		z.lift(float(g.get("lift_height", 3.0)), hold, pid, w.id, drop_damage(hr, g), slam_damage(hr, g),
			float(g.get("wave_radius", 2.0)), float(g.get("wave_damage", 60.0)))
		z.set_vulnerable(float(g.get("limb_mult_lifted", 1.5)), hold + 0.5)
		(out["lifted"] as Array).append(z)
	for b: Zombie in bosses_in(zs, center, radius):
		b.force_stagger()
		out["bosses"] = int(out["bosses"]) + 1
	var pull: float = float(g.get("pull_from_m", 0.0))
	if pull > radius:
		for z2: Zombie in zs:
			if not z2.is_active() or z2.is_lifted() or is_boss(z2):
				continue
			var to_c: Vector3 = center - z2.global_position
			to_c.y = 0.0
			var d: float = to_c.length()
			if d > radius and d <= pull:
				z2.external_push(to_c.normalized() * float(g.get("pull_speed", 6.0)), 0.45)
				out["pulled"] = int(out["pulled"]) + 1
	last_result = out
	return out


## One fling from `origin` along `fwd`. Returns {flung: n, chained: n}.
static func resolve_fling(ctx: Node3D, origin: Vector3, fwd: Vector3, w: WeaponInstance, pid: int) -> Dictionary:
	var g: Dictionary = cfg(w)
	var out: Dictionary = {"flung": 0, "chained": 0}
	if ctx == null or not ctx.is_inside_tree():
		return out
	var dir: Node = ctx.get_tree().get_first_node_in_group(&"director")
	if dir == null or not dir.has_method("active_zombies"):
		return out
	var zs: Array = dir.call("active_zombies")
	var gs: float = gravity_scale()
	var dist: float = fling_distance(g, gs)
	var vel: Vector3 = fling_velocity(fwd, dist, gs)
	var secs: float = fling_seconds(gs)
	var dmg: float = fling_damage(round_health(), g)
	var reach: float = float(g.get("fling_cone_m", 6.0))
	var cone: float = float(g.get("fling_cone_deg", 50.0))
	var flung: Array = []
	for z: Zombie in zs:
		if not z.is_active() or is_boss(z):
			continue
		var chest: Vector3 = z.global_position + Vector3.UP
		if not Totenglocke.in_cone(origin, fwd, chest, reach, cone, 1.2):
			continue
		if z.is_lifted():
			z.drop()
		z.external_push(vel, secs, pid, w.id, dmg)
		flung.append(z)
	out["flung"] = flung.size()
	# Escape Velocity: a flung body that passes another knocks it along too (fling_chain hops, weaker each time)
	var chain: int = int(g.get("fling_chain", 0))
	if chain > 0 and not flung.is_empty():
		var hit: Dictionary = {}
		for f: Zombie in flung:
			hit[f] = true
		var frontier: Array = flung.duplicate()
		for hop: int in chain:
			var next: Array = []
			var k: float = pow(0.6, hop + 1)
			for f2: Zombie in frontier:
				var mid: Vector3 = f2.global_position + Vector3(vel.x, 0, vel.z).normalized() * dist * 0.5
				for z3: Zombie in zs:
					if hit.has(z3) or not z3.is_active() or is_boss(z3):
						continue
					var p: Vector3 = z3.global_position
					var seg_d: float = _dist_to_segment(p, f2.global_position, mid)
					if seg_d <= 2.5:
						hit[z3] = true
						z3.external_push(vel * k, secs, pid, w.id, dmg * k)
						next.append(z3)
						out["chained"] = int(out["chained"]) + 1
			frontier = next
			if frontier.is_empty():
				break
	last_result = out
	return out


static func _dist_to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab: Vector3 = b - a
	var t: float = clampf((p - a).dot(ab) / maxf(0.001, ab.length_squared()), 0.0, 1.0)
	return (a + ab * t).distance_to(p)


# ================================================================== bots

## A bot lifts the clump ahead (then slams at once, the way the brain uses it). Returns the lift result.
static func bot_lift(p: Player, w: WeaponInstance, origin: Vector3, fwd: Vector3) -> Dictionary:
	var g: Dictionary = cfg(w)
	if w.mag < int(g.get("lift_cost", 1)):
		return {"lifted": []}
	w.mag -= int(g.get("lift_cost", 1))
	var res: Dictionary = resolve_lift(p, origin, fwd, w, p.player_id, false)
	AudioDirector.play_3d(str(g.get("lift_sound", "lodestone_lift")), origin, 0.0, 0.0)
	GLBus.weapon_fired.emit(p.player_id, w.id, w.upgraded, origin, fwd)
	return res


## Slams what `res` lifted (the same charge).
static func bot_slam(p: Player, w: WeaponInstance, res: Dictionary) -> int:
	var n: int = 0
	for z: Zombie in res.get("lifted", []):
		if is_instance_valid(z) and z.is_lifted():
			z.slam()
			n += 1
	if n > 0:
		AudioDirector.play_3d(str(cfg(w).get("slam_sound", "lodestone_slam")), p.global_position, 0.0, 0.0)
	return n


static func bot_fling(p: Player, w: WeaponInstance, origin: Vector3, fwd: Vector3) -> Dictionary:
	var g: Dictionary = cfg(w)
	if w.mag < int(g.get("fling_cost", 2)):
		return {"flung": 0}
	w.mag -= int(g.get("fling_cost", 2))
	var res: Dictionary = resolve_fling(p, origin, fwd, w, p.player_id)
	AudioDirector.play_3d(str(g.get("fling_sound", "lodestone_fling")), origin, 0.0, 0.0)
	GLBus.weapon_fired.emit(p.player_id, w.id, w.upgraded, origin, fwd)
	return res


## Is a lift worth a charge here: `min_clump` zombies within the well.
static func bot_clump(p: Player, w: WeaponInstance, origin: Vector3, fwd: Vector3, known: Array) -> int:
	var g: Dictionary = cfg(w)
	var c: Vector3 = well_center(origin, fwd, g, false)
	var r: float = well_radius(g, false)
	var n: int = 0
	for z: Zombie in known:
		if z != null and z.is_active() and not is_boss(z) and Vector2(z.global_position.x - c.x, z.global_position.z - c.z).length() <= r:
			n += 1
	return n


# ================================================================== per-frame (the holder's player)

func tick(w: WeaponInstance, delta: float, held: bool, pressed: bool) -> void:
	var g: Dictionary = cfg(w)
	_cd = maxf(0.0, _cd - delta)
	_spin += _spin_v * delta
	_spin_v = move_toward(_spin_v, 2.0 + 6.0 * (1.0 if not _lifted.is_empty() else 0.0) + 10.0 * maxf(0.0, _coil_glow), delta * 8.0)
	_ring_open = move_toward(_ring_open, 1.0 if not _lifted.is_empty() else 0.0, delta * 5.0)
	_prune()
	if holder.is_reloading() and not _lifted.is_empty():
		_release(false)
	if _fling_t >= 0.0:
		_fling_t += delta
		_coil_glow = clampf(_fling_t / maxf(0.05, float(g.get("fling_hold_s", 0.6))), 0.0, 1.0)
		if _fling_t >= float(g.get("fling_hold_s", 0.6)):
			_fling_t = -1.0
			_fling(w)
		return
	_coil_glow = move_toward(_coil_glow, 0.0, delta * 3.0)
	if _pull_pass_t >= 0.0:
		_pull_pass_t -= delta
		if _pull_pass_t <= 0.0:
			_pull_pass_t = -1.0
			_second_pass(w)
	if not _lifted.is_empty():
		_hold_t -= delta
		if pressed:
			slam(w)
		elif _hold_t <= 0.0:
			_release(false)
		return
	if pressed:
		if w.mag < int(g.get("lift_cost", 1)):
			AudioDirector.play_2d("gun_dry", -4.0)
			holder.start_reload()
			return
		if _cd <= 0.0:
			lift(w)


func _prune() -> void:
	var keep: Array = []
	for z: Variant in _lifted:
		if is_instance_valid(z) and (z as Zombie).is_lifted():
			keep.append(z)
	_lifted = keep


func lift(w: WeaponInstance) -> void:
	var g: Dictionary = cfg(w)
	var p: Player = holder.player
	var cam: Camera3D = p.camera
	if cam == null:
		return
	w.mag = maxi(0, w.mag - int(g.get("lift_cost", 1)))
	holder._fired_this_frame = true
	var origin: Vector3 = cam.global_position
	var fwd: Vector3 = -cam.global_basis.z
	var ads: bool = holder.ads_t >= 0.9
	GLBus.weapon_fired.emit(p.player_id, w.id, w.upgraded, origin, fwd)
	var res: Dictionary = resolve_lift(holder, origin, fwd, w, p.player_id, ads)
	_lifted = (res["lifted"] as Array).duplicate()
	_hold_t = float(g.get("hold_seconds", 2.5))
	_cd = float(g.get("lift_cooldown", 0.5))
	if int(res.get("pulled", 0)) > 0:
		_pull_pass_t = 0.5
		_pull_origin = origin
		_pull_fwd = fwd
		_pull_ads = ads
	AudioDirector.play_2d(str(g.get("lift_sound", "lodestone_lift")), 0.0, 0.05)
	holder._vm_kick(1.8)
	holder._on_shot_fx(0.08)
	p.kick_camera(2.0, 0.6, 0.15, 8.0, 0.3, 2.5)
	Totenglocke.rumble(p, 0.4, 0.3, 0.2)
	Totenglocke.shock_ring(holder, res["center"] as Vector3, Vector3.UP, well_radius(g, ads), color_of(g), false)
	for z: Zombie in _lifted:
		GLBus.enemy_hit_feedback.emit(p.player_id, false, false)
	if w.mag <= 0 and w.reserve > 0 and _lifted.is_empty():
		holder.get_tree().create_timer(0.5).timeout.connect(holder.start_reload)
	holder._ammo_warnings(w)


## Escape Velocity: half a second after the pull, whoever the well now holds is lifted too (no extra charge).
func _second_pass(w: WeaponInstance) -> void:
	if _lifted.is_empty():
		return
	var g: Dictionary = cfg(w)
	var p: Player = holder.player
	var room: int = int(g.get("max_targets", 8)) - _lifted.size()
	if room <= 0 or not holder.is_inside_tree():
		return
	var dir: Node = holder.get_tree().get_first_node_in_group(&"director")
	if dir == null:
		return
	var center: Vector3 = well_center(_pull_origin, _pull_fwd, g, _pull_ads)
	var hr: float = round_health()
	for z: Zombie in pick_targets(dir.call("active_zombies"), center, well_radius(g, _pull_ads), room):
		z.lift(float(g.get("lift_height", 3.0)), maxf(0.3, _hold_t), p.player_id, w.id, drop_damage(hr, g), slam_damage(hr, g),
			float(g.get("wave_radius", 2.0)), float(g.get("wave_damage", 60.0)))
		z.set_vulnerable(float(g.get("limb_mult_lifted", 1.5)), _hold_t + 0.5)
		_lifted.append(z)


func slam(w: WeaponInstance) -> void:
	var g: Dictionary = cfg(w)
	var p: Player = holder.player
	_prune()
	var n: int = 0
	var at: Vector3 = p.global_position
	for z: Zombie in _lifted:
		at = z.global_position
		z.slam()
		n += 1
	_lifted.clear()
	_pull_pass_t = -1.0
	holder._fired_this_frame = true
	_cd = float(g.get("lift_cooldown", 0.5))
	if n > 0:
		AudioDirector.play_2d(str(g.get("slam_sound", "lodestone_slam")), 1.0, 0.0)
		holder._vm_kick(3.2)
		p.kick_camera(4.0, 1.4, 0.2, 7.0, 0.5, 4.0)
		Totenglocke.rumble(p, 0.8, 0.9, 0.3)
		Effects.explosion(at + Vector3.UP * 0.2, float(g.get("wave_radius", 2.0)) * 0.7)
		if n >= 6:
			Totenglocke.hitstop(holder.get_tree(), 0.25, 0.12)
	if w.mag <= 0 and w.reserve > 0:
		holder.get_tree().create_timer(0.4).timeout.connect(holder.start_reload)


## The hold ends (time, a reload, a swap): the dead drop.
func _release(_slam_them: bool) -> void:
	for z: Variant in _lifted:
		if is_instance_valid(z) and (z as Zombie).is_lifted():
			(z as Zombie).drop()
	_lifted.clear()
	_pull_pass_t = -1.0


## Alt-fire: the fling's wind-up starts; the throw goes off by itself at fling_hold_s.
func alt_fire(w: WeaponInstance) -> void:
	var g: Dictionary = cfg(w)
	if _fling_t >= 0.0 or holder.is_reloading():
		return
	if w.mag < int(g.get("fling_cost", 2)):
		AudioDirector.play_2d("gun_dry", -4.0)
		return
	_fling_t = 0.0
	AudioDirector.play_2d(str(g.get("hum_sound", "lodestone_hum")), -6.0, 0.1)


func _fling(w: WeaponInstance) -> void:
	var g: Dictionary = cfg(w)
	var p: Player = holder.player
	var cam: Camera3D = p.camera
	if cam == null:
		return
	w.mag = maxi(0, w.mag - int(g.get("fling_cost", 2)))
	holder._fired_this_frame = true
	var origin: Vector3 = cam.global_position
	var fwd: Vector3 = -cam.global_basis.z
	GLBus.weapon_fired.emit(p.player_id, w.id, w.upgraded, origin, fwd)
	if not _lifted.is_empty():
		_release(false)
	var res: Dictionary = resolve_fling(holder, origin, fwd, w, p.player_id)
	_coil_glow = 0.0
	_cd = float(g.get("lift_cooldown", 0.5))
	AudioDirector.play_2d(str(g.get("fling_sound", "lodestone_fling")), 0.0, 0.0)
	holder._vm_kick(4.0)
	holder._on_shot_fx(0.1)
	p.kick_camera(5.0, 1.0, 0.2, 7.0, 0.5, 5.0)
	Totenglocke.rumble(p, 0.6, 0.8, 0.3)
	Totenglocke.shock_ring(holder, origin + fwd * 0.6, fwd, float(g.get("fling_cone_m", 6.0)), color_of(g), int(res["flung"]) >= 4)
	if w.mag <= 0 and w.reserve > 0:
		holder.get_tree().create_timer(0.5).timeout.connect(holder.start_reload)
	holder._ammo_warnings(w)


func is_holding() -> bool:
	return not _lifted.is_empty()


func held_count() -> int:
	_prune()
	return _lifted.size()


func charge() -> float:
	return _coil_glow


func ring_open() -> float:
	return _ring_open


func spin() -> float:
	return _spin


static func color_of(g: Dictionary) -> Color:
	var c: Array = g.get("color", [0.75, 0.45, 1.0])
	return Color(float(c[0]), float(c[1]), float(c[2]))


## The viewmodel's moving parts (greybox and GLB alike): the sphere spins in its cradle, the rings open on a
## lift, the coil glows with the fling charge. Called from WeaponHolder._animate every frame.
func pose_parts(model: Node3D) -> void:
	if model == null:
		return
	var sphere: Node3D = model.get_node_or_null("Sphere") as Node3D
	if sphere != null:
		sphere.rotation = Vector3(_spin * 0.3, _spin, _spin * 0.17)
	var cradle: Node3D = model.get_node_or_null("Cradle") as Node3D
	if cradle != null:
		cradle.rotation.z = deg_to_rad(28.0) * _ring_open
		cradle.rotation.x = sin(_spin * 0.5) * 0.08
	var coil: Node3D = model.get_node_or_null("Coil") as Node3D
	if coil != null:
		var mi: MeshInstance3D = coil as MeshInstance3D if coil is MeshInstance3D else null
		if mi == null and coil.get_child_count() > 0 and coil.get_child(0) is MeshInstance3D:
			mi = coil.get_child(0) as MeshInstance3D
		if mi != null and mi.material_override is StandardMaterial3D:
			(mi.material_override as StandardMaterial3D).emission_energy_multiplier = 0.2 + 4.0 * _coil_glow


## The reload: the yoke swings down, the sphere gets a quarter turn in the cradle, the yoke swings up. The left
## hand goes to the cradle's rim for the turn.
func reload_hand(p: float, model: Node3D, lh_home: Vector3) -> Variant:
	var cradle: Node3D = model.get_node_or_null("Cradle") as Node3D if model != null else null
	var k: float = clampf((p - 0.2) / 0.6, 0.0, 1.0)
	if cradle != null:
		cradle.rotation.y = -TAU * 0.25 * (k * k * (3.0 - 2.0 * k))
	_spin_v = 14.0 if k > 0.0 and k < 1.0 else _spin_v
	var rim: Vector3 = (cradle.position + Vector3(-0.06, 0.02, 0.0)) if cradle != null else lh_home + Vector3(-0.05, 0.04, 0.0)
	if p < 0.2:
		return lh_home.lerp(rim, smoothstep(0.0, 1.0, p / 0.2))
	if p > 0.85:
		return rim.lerp(lh_home, smoothstep(0.0, 1.0, (p - 0.85) / 0.15))
	return rim
