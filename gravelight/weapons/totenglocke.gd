class_name Totenglocke
extends RefCounted
## The Totenglocke's "wind and toll" (Update 02 section 3, T-048; docs/gravelight/WEAPONS.md section 8).
## One instance per WeaponHolder (created on first use); WeaponHolder._tick_bell / _alt_fire delegate here.
##
##   Tap   = a quick toll: released before the wind completes (`wind_seconds`). Mid-range cone, kills any zombie
##           whose max HP is at most `kill_cap_hp` (round ~20), else `pct_max_hp` of max HP. Fires on release, so a
##           tap is never eaten; a tap during the toll cooldown is buffered and fires when the bell is ready.
##   Hold  = wind up: after `tap_max_s` the crank speeds up and the bell hums, rising in pitch; at `wind_seconds`
##           (with `great_cost` charges in the bell) it locks and the release is the GREAT TOLL, which shatters
##           every non-boss in a wider, longer cone.
##   Marks = a toll's survivors are "tolled" (TollMark); a second toll always shatters them.
##   Alt   = the Bell Dome (BellDome): a resonance field at your feet. One at a time.
##   Ammo  = charges; the crank is the reload (the holder's "bell" reload animation, winding sound here).
##           Every `shard_every`-th Totenglocke kill drops a BronzeShard (+1 charge).
## Bosses (Foreman, Screamer, homage bosses) are never shattered or marked: they take a % of max HP per toll.
## The pure rules are static (tests: gravelight/tests/unit/test_totenglocke.gd). Bots toll through bot_toll().

const MASK_LOS: int = 1 | (1 << 8)          # world | doors
const SHARD_META: StringName = &"tg_shard_kills"
const MAX_PIECES_PER_TOLL: int = 5           # zombies whose severed parts fly as props (ZombieGore caps live pieces)

static var _hitstop_on: bool = false
static var hitstops: int = 0                 # how many hitstops ran (tests / the clip harness)
static var last_result: Dictionary = {}      # the last toll's tally (resolve), for the clip harness

var holder: WeaponHolder
var _hold_t: float = 0.0
var _holding: bool = false
var _great_ready: bool = false
var _short_warned: bool = false
var _buffered: bool = false
var _cd: float = 0.0
var _hum: AudioStreamPlayer = null
var _vibe_t: float = 0.0
var _vibe_total: float = 1.0
var _vibe_amp: float = 0.0
var _clock: float = 0.0
var _crank_a: float = 0.0
var _crank_v: float = 0.0
var _was_reloading: bool = false
var _wind_snd: AudioStreamPlayer = null
var _wind_stream: AudioStream = null
var _dome: Node3D = null
var _bell_node: Node3D = null
var _bell_rest: Transform3D = Transform3D.IDENTITY


func _init(h: WeaponHolder) -> void:
	holder = h


# ================================================================== pure rules (static, tested)

## True for the enemies a toll must never shatter or mark.
static func is_boss(z: Zombie) -> bool:
	return z is Foreman or z is Screamer or z is HomageBoss


## [range m, cone degrees] of a quick toll or the Great Toll from the weapon's `bell` block.
static func cone_for(b: Dictionary, great: bool) -> Vector2:
	if great:
		return Vector2(float(b.get("great_range", 14.0)), float(b.get("great_cone_deg", 70.0)))
	return Vector2(float(b.get("range", 8.0)), float(b.get("cone_deg", 50.0)))


static func great_cost(b: Dictionary) -> int:
	return int(b.get("great_cost", 3))


## Can a full wind become a Great Toll with `mag` charges in the bell?
static func can_great(b: Dictionary, mag: int) -> bool:
	return mag >= great_cost(b)


## What a release does after holding `hold_t` seconds: &"great" only when the wind completed and locked.
static func release_kind(b: Dictionary, hold_t: float, mag: int) -> StringName:
	if hold_t >= float(b.get("wind_seconds", 1.5)) and can_great(b, mag):
		return &"great"
	return &"tap"


## Is `point` inside the toll's cone from `origin` looking along `fwd`? Anything within `close_r` counts
## whatever the direction (the bell's mouth is wide).
static func in_cone(origin: Vector3, fwd: Vector3, point: Vector3, max_range: float, cone_deg: float, close_r: float) -> bool:
	var to_p: Vector3 = point - origin
	var d: float = to_p.length()
	if d > max_range:
		return false
	if d <= close_r:
		return true
	return fwd.normalized().dot(to_p / maxf(d, 0.001)) >= cos(deg_to_rad(cone_deg * 0.5))


## One zombie's result from one toll: {damage, shatter, mark, kill}.
##   boss                 -> boss_tap_pct / boss_great_pct of max HP, never shatter, never mark
##   Great Toll or tolled -> shatter (lethal)
##   max HP <= kill_cap   -> killed outright
##   else                 -> pct_max_hp of max HP; a survivor is marked (tolled)
## `dmg_mult` is the damage the zombie will really take per point (a Bell Dome's +25%), so a hit that the
## dome makes lethal isn't counted as a mark.
static func outcome(max_hp: float, hp: float, tolled: bool, boss: bool, great: bool, b: Dictionary, dmg_mult: float = 1.0) -> Dictionary:
	if boss:
		var pct: float = float(b.get("boss_great_pct", 0.1)) if great else float(b.get("boss_tap_pct", 0.03))
		return {"damage": max_hp * pct, "shatter": false, "mark": false, "kill": max_hp * pct * dmg_mult >= hp}
	if great or tolled:
		return {"damage": hp + 1.0, "shatter": true, "mark": false, "kill": true}
	if max_hp <= float(b.get("kill_cap_hp", 2750.0)):
		return {"damage": hp + 1.0, "shatter": false, "mark": false, "kill": true}
	var dmg: float = max_hp * float(b.get("pct_max_hp", 0.35))
	var lethal: bool = dmg * dmg_mult >= hp
	return {"damage": dmg, "shatter": false, "mark": not lethal, "kill": lethal}


## Bronze-shard rate limit: [shards to drop, new counter] after `kills` more Totenglocke kills.
static func shard_step(counter: int, kills: int, every: int) -> Array:
	var total: int = counter + maxi(0, kills)
	var n: int = maxi(1, every)
	return [total / n, total % n]


## Puts one charge back: into the bell first, then the reserve. False when both are full.
static func add_charge(w: WeaponInstance) -> bool:
	if w.mag < w.mag_size():
		w.mag += 1
		return true
	if w.reserve < w.reserve_max():
		w.reserve += 1
		return true
	return false


## Crank angle (radians, about the crank's x axis) during the winding reload, 0..1 progress: six turns that
## start slow, run, and ratchet home.
static func reload_crank_angle(p: float) -> float:
	var k: float = clampf((p - 0.12) / 0.76, 0.0, 1.0)
	return TAU * 6.0 * (k * k * (3.0 - 2.0 * k))


# ================================================================== the toll itself (holder + bots)

## Resolves one toll from `origin` along `fwd` against every active zombie (cone + line of sight), then the
## Mitternacht chain-ring. Returns {hit, kills, shattered, marked, kill_pos: Array[Vector3], chains: Array}.
static func resolve(ctx: Node3D, origin: Vector3, fwd: Vector3, w: WeaponInstance, pid: int, great: bool) -> Dictionary:
	var b: Dictionary = w.data["bell"]
	var cone: Vector2 = cone_for(b, great)
	var out: Dictionary = {"hit": 0, "kills": 0, "shattered": 0, "marked": 0, "kill_pos": [], "chains": [],
		"pieces": 0, "sounds": 0, "color": color_of(b)}
	if ctx == null or not ctx.is_inside_tree():
		return out
	var dir: ZombieDirector = ctx.get_tree().get_first_node_in_group(&"director") as ZombieDirector
	if dir == null:
		return out
	var zs: Array[Zombie] = dir.active_zombies()
	var space: PhysicsDirectSpaceState3D = ctx.get_world_3d().direct_space_state
	var close_r: float = float(b.get("close_radius", 2.5))
	var hit_set: Dictionary = {}
	var shatter_from: Array[Vector3] = []
	for z: Zombie in zs:
		if not z.is_active():
			continue
		var chest: Vector3 = z.global_position + Vector3.UP * (0.5 if z.is_crawler else 1.0)
		if not in_cone(origin, fwd, chest, cone.x, cone.y, close_r):
			continue
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, chest, MASK_LOS)
		if not space.intersect_ray(q).is_empty():
			continue
		hit_set[z] = true
		if _strike(z, origin, w, pid, great, b, out):
			shatter_from.append(chest)
	# Mitternacht: every shattered zombie rings the nearest few (a quick toll each; one hop, no cascade)
	var chain_n: int = int(b.get("chain", 0))
	if chain_n > 0:
		var cr: float = float(b.get("chain_radius", 5.0))
		for src: Vector3 in shatter_from:
			for z: Zombie in _nearest(zs, src, chain_n, cr, hit_set):
				hit_set[z] = true
				var to: Vector3 = z.global_position + Vector3.UP * 1.0
				(out["chains"] as Array).append([src, to])
				_strike(z, src, w, pid, false, b, out)
	return out


## Applies one toll to one zombie and updates the tally. Returns true if it shattered.
static func _strike(z: Zombie, from: Vector3, w: WeaponInstance, pid: int, great: bool, b: Dictionary, out: Dictionary) -> bool:
	var boss: bool = is_boss(z)
	var o: Dictionary = outcome(z.max_hp, z.hp, TollMark.is_on(z), boss, great, b, z.vulnerability())
	out["hit"] = int(out["hit"]) + 1
	var pos: Vector3 = z.global_position
	var killed: bool = false
	if bool(o["shatter"]):
		killed = shatter(z, from, w.id, pid, int(out["pieces"]) < MAX_PIECES_PER_TOLL, out["color"] as Color)
		if killed:
			out["pieces"] = int(out["pieces"]) + 1
			out["shattered"] = int(out["shattered"]) + 1
			if int(out["sounds"]) < 4:
				out["sounds"] = int(out["sounds"]) + 1
				AudioDirector.play_3d("totenglocke_shatter", pos + Vector3.UP * 1.1, -2.0, 0.08)
	else:
		killed = z.take_damage(float(o["damage"]), &"torso", w.id, pid, &"explosive", true)
		if not killed:
			if boss:
				if float(b.get("stagger_bosses", 0.0)) > 0.0:
					z.force_stagger()
			else:
				z.force_stagger()
				if bool(o["mark"]):
					TollMark.apply(z, out["color"] as Color, float(b.get("mark_seconds", 20.0)))
					out["marked"] = int(out["marked"]) + 1
	if killed:
		out["kills"] = int(out["kills"]) + 1
		(out["kill_pos"] as Array).append(pos)
	GLBus.enemy_hit_feedback.emit(pid, killed, false)
	return killed and bool(o["shatter"])


## The most dramatic death the zombies have: a lethal explosive-kind hit (the ragdoll launch), then the head and
## three limbs blown off (ZombieGore) away from the bell, and a burst of bronze/frost shards. `pieces` = the
## severed parts fly as physics props (else they simply vanish into the shard burst). Returns true if it died.
static func shatter(z: Zombie, from: Vector3, weapon_id: StringName, pid: int, pieces: bool, color: Color) -> bool:
	var pos: Vector3 = z.global_position
	var killed: bool = z.take_damage(maxf(z.hp, 1.0) + 1.0, &"torso", weapon_id, pid, &"explosive", true)
	if not killed:
		return false
	var away: Vector3 = pos - from
	away.y = 0.0
	away = away.normalized() if away.length_squared() > 0.001 else Vector3.FORWARD
	if z.has_rig() and ZombieGore.severs_allowed():
		var limbs: Array[String] = ["Head", "LeftUpperArm" if randf() < 0.5 else "LeftLowerArm",
			"RightLowerArm" if randf() < 0.5 else "RightUpperArm", "LeftLowerLeg" if randf() < 0.5 else "RightLowerLeg"]
		for i: int in limbs.size():
			var imp: Vector3 = away * randf_range(5.0, 8.0) + Vector3.UP * randf_range(3.0, 5.5) \
				+ Vector3(randf_range(-2.0, 2.0), 0.0, randf_range(-2.0, 2.0))
			ZombieGore.sever(z, limbs[i], imp, pieces and i < 2)
	var host: Node = z.get_parent()
	if host != null:
		burst(host, pos + Vector3.UP * 1.1, color, 34, 7.0, away)
		burst(host, pos + Vector3.UP * 0.9, Color(0.85, 0.92, 1.0), 20, 4.0, away)
	return true


static func _nearest(zs: Array[Zombie], at: Vector3, n: int, radius: float, skip: Dictionary) -> Array[Zombie]:
	var cands: Array = []
	for z: Zombie in zs:
		if skip.has(z) or not z.is_active() or is_boss(z):
			continue
		var d: float = z.global_position.distance_to(at)
		if d <= radius:
			cands.append([d, z])
	cands.sort_custom(func(a: Array, c: Array) -> bool: return float(a[0]) < float(c[0]))
	var outz: Array[Zombie] = []
	for i: int in mini(n, cands.size()):
		outz.append(cands[i][1] as Zombie)
	return outz


static func color_of(b: Dictionary) -> Color:
	var c: Array = b.get("color", [1.0, 0.62, 0.25])
	return Color(float(c[0]), float(c[1]), float(c[2]))


## Bronze shards from Totenglocke kills (rate-limited per player, `shard_every`).
static func drop_shards(p: Player, b: Dictionary, kill_pos: Array) -> void:
	if p == null or kill_pos.is_empty() or not p.is_inside_tree():
		return
	var st: Array = shard_step(int(p.get_meta(SHARD_META, 0)), kill_pos.size(), int(b.get("shard_every", 5)))
	p.set_meta(SHARD_META, int(st[1]))
	var host: Node = p.get_parent()
	for i: int in int(st[0]):
		var s: BronzeShard = BronzeShard.new()
		s.life = float(b.get("shard_seconds", 25.0))
		host.add_child(s)
		s.global_position = (kill_pos[kill_pos.size() - 1 - (i % kill_pos.size())] as Vector3) + Vector3.UP * 0.35


## A bot's toll (bots press no buttons: BotAim.fire calls this; the caller spends the charge). `great` = the
## Great Toll (U03: the bot's aim layer decides it on a bunched crowd; the caller spends great_cost charges).
static func bot_toll(p: Player, w: WeaponInstance, origin: Vector3, fwd: Vector3, great: bool = false) -> Dictionary:
	var b: Dictionary = w.data["bell"]
	var res: Dictionary = resolve(p, origin, fwd, w, p.player_id, great)
	AudioDirector.play_3d(str(b.get("ring_sound", "totenglocke_toll")), origin, 4.0 if great else 0.0, 0.0)
	var chime: String = str(b.get("chime_sound", ""))
	if chime != "":
		AudioDirector.play_3d(chime, origin, -4.0, 0.0)
	shock_ring(p, origin, fwd, cone_for(b, great).x, color_of(b), great)
	drop_shards(p, b, res["kill_pos"])
	_chain_fx(p, res)
	GLBus.weapon_fired.emit(p.player_id, w.id, w.upgraded, origin, fwd)
	return res


## A bot plants the Bell Dome at its feet (U03: revives and covering), the same field as alt_fire. Spends
## dome_cost charges; returns the dome, or null without the charges.
static func bot_dome(p: Player, w: WeaponInstance) -> BellDome:
	var b: Dictionary = w.data["bell"]
	var cost: int = int(b.get("dome_cost", 2))
	if w.mag < cost or p == null or not p.is_inside_tree():
		return null
	w.mag -= cost
	var d: BellDome = BellDome.new()
	d.radius = float(b.get("dome_radius", 6.0))
	d.seconds = float(b.get("dome_seconds", 8.0))
	d.slow = float(b.get("dome_slow", 0.6))
	d.damage_mult = float(b.get("dome_damage_mult", 1.25))
	d.pull = float(b.get("dome_pull", 0.0))
	d.color = color_of(b)
	d.upgraded = w.upgraded
	d.by_player = p.player_id
	p.get_parent().add_child(d)
	d.global_position = p.global_position
	return d


# ================================================================== per-frame (the holder's player)

## Called every frame while the Totenglocke is in hand. `held` already folds in "can shoot" (sprint, swap...).
func tick(w: WeaponInstance, delta: float, held: bool, pressed: bool) -> void:
	var b: Dictionary = w.data["bell"]
	_clock += delta
	_cd = maxf(0.0, _cd - delta)
	_vibe_t = maxf(0.0, _vibe_t - delta)
	_tick_reload_sound()
	if pressed and _cd > 0.0:
		_buffered = true
	if w.mag <= 0:
		_stop_wind()
		_buffered = false
		if pressed:
			AudioDirector.play_2d("gun_dry", -4.0)
			holder.start_reload()
		_spin_crank(delta, 0.0)
		return
	if holder.is_reloading():
		if pressed:
			holder._cancel_reload()   # a toll stops the winding; charges only move when a wind completes
		else:
			_stop_wind()
			_spin_crank(delta, 0.0)
			return
	if not _holding and _cd <= 0.0:
		if held:
			_holding = true
			_buffered = false
			_hold_t = 0.0
			_great_ready = false
			_short_warned = false
		elif _buffered:
			_buffered = false
			toll(w, false)
			return
	if _holding:
		if held:
			_hold_t += delta
			_tick_wind(w, b, delta)
			return
		_holding = false
		var kind: StringName = release_kind(b, _hold_t, w.mag) if _great_ready else &"tap"
		_stop_wind()
		toll(w, kind == &"great")
		return
	_spin_crank(delta, 0.0)


func _tick_wind(w: WeaponInstance, b: Dictionary, delta: float) -> void:
	var tap_max: float = float(b.get("tap_max_s", 0.25))
	var wind: float = float(b.get("wind_seconds", 1.5))
	var k: float = clampf((_hold_t - tap_max) / maxf(0.05, wind - tap_max), 0.0, 1.0)
	if _hold_t < tap_max:
		_spin_crank(delta, 4.0)
		return
	_spin_crank(delta, lerpf(7.0, 36.0, k))
	if _hum == null or not is_instance_valid(_hum):
		_hum = AudioDirector.make_loop_2d("totenglocke_hum", holder, -18.0)
	if _hum != null:
		if not _hum.playing:
			_hum.play()
		var flutter: float = 0.012 * sin(_clock * 31.0) if _great_ready else 0.0
		_hum.pitch_scale = lerpf(0.62, 1.45, k) + flutter
		_hum.volume_db = lerpf(-20.0, -5.0, k)
	if _hold_t >= wind and not _great_ready:
		if can_great(b, w.mag):
			_great_ready = true
			AudioDirector.play_2d("totenglocke_crank", 0.0, 0.0)
			holder._vm_kick(0.6)
			rumble(holder.player, 0.25, 0.1, 0.12)
		elif not _short_warned:
			_short_warned = true
			AudioDirector.play_2d("gun_dry", -2.0)
	if _great_ready:
		# the locked wind: the bell trembles in your hands, waiting
		_vibe_amp = maxf(_vibe_amp * (_vibe_t / maxf(0.01, _vibe_total)), 0.25)
		_vibe_total = 0.3
		_vibe_t = 0.3


func _stop_wind() -> void:
	_holding = false
	_great_ready = false
	if _hum != null and is_instance_valid(_hum) and _hum.playing:
		_hum.stop()


func _spin_crank(delta: float, target: float) -> void:
	_crank_v = move_toward(_crank_v, target, delta * (60.0 if target > _crank_v else 25.0))
	_crank_a = fmod(_crank_a + _crank_v * delta, TAU)


func _tick_reload_sound() -> void:
	var rl: bool = holder.is_reloading()
	if rl and not _was_reloading:
		_wind_snd = AudioDirector.play_2d("totenglocke_wind", -3.0, 0.0)
		_wind_stream = _wind_snd.stream if _wind_snd != null else null
	elif not rl and _was_reloading:
		var w: WeaponInstance = holder.current()
		var done: bool = w != null and w.data.has("bell") and (w.mag >= w.mag_size() or w.reserve <= 0)
		if not done and _wind_snd != null and is_instance_valid(_wind_snd) and _wind_snd.playing and _wind_snd.stream == _wind_stream:
			_wind_snd.stop()   # a cancelled wind stops its ratchet
	_was_reloading = rl


## The viewmodel pose: called by the holder right after its part reset, before the reload animation.
func pose_parts(crank: Node3D, model: Node3D) -> void:
	var w: WeaponInstance = holder.current()
	if w == null or not w.data.has("bell") or model == null:
		if _holding or (_hum != null and is_instance_valid(_hum) and _hum.playing):
			_stop_wind()   # swapped away (or went down) mid-wind: the hum stops, nothing rings
		_buffered = false
		return
	if crank != null and not holder.is_reloading():
		crank.rotation.x += _crank_a
	var bell: Node3D = model.get_node_or_null("Bell") as Node3D
	if bell == null:
		return
	if bell != _bell_node:
		_bell_node = bell
		_bell_rest = bell.transform
	var a: float = _vibe_amp * pow(_vibe_t / maxf(0.01, _vibe_total), 1.5)
	_glow(bell, w, a)
	if a <= 0.0005:
		bell.transform = _bell_rest
		return
	var t: float = _clock
	var off: Vector3 = Vector3(sin(t * TAU * 37.0), sin(t * TAU * 43.0 + 1.3) * 0.7, sin(t * TAU * 23.0 + 0.4) * 0.4) * 0.0055 * a
	var rot: Basis = Basis.from_euler(Vector3(sin(t * TAU * 31.0) * 0.03, 0.0, sin(t * TAU * 29.0 + 0.8) * 0.05) * a)
	bell.transform = Transform3D(_bell_rest.basis * rot, _bell_rest.origin + off)


## The bell glows from inside while it rings and while the wind hums (so it reads in a dark map), in the
## viewmodel's compressed space (the same falloff rule as the holder's Nachtglas glow).
func _glow(bell: Node3D, w: WeaponInstance, amp: float) -> void:
	var l: OmniLight3D = bell.get_node_or_null("BellGlow") as OmniLight3D
	if l == null:
		l = OmniLight3D.new()
		l.name = "BellGlow"
		l.shadow_enabled = false
		l.position = Vector3(0, 0.06, -0.3)
		bell.add_child(l)
	var k: float = holder._vm_compress
	l.light_color = color_of(w.data["bell"])
	l.omni_range = 0.9 * k
	var wind: float = 0.0
	if _holding:
		wind = 0.35 + (0.5 if _great_ready else 0.25 * clampf(_hold_t / 1.5, 0.0, 1.0))
	l.light_energy = (0.12 + wind + 1.6 * minf(amp, 1.6)) * k * k * 6.0


## Left-hand target during the winding reload: it reaches for the crank handle and turns it.
func reload_hand(p: float, crank: Node3D, lh_home: Vector3) -> Variant:
	if crank == null:
		return null
	var ang: float = reload_crank_angle(p)
	crank.rotation.x = ang
	var handle: Vector3 = crank.position + Basis(Vector3.RIGHT, ang) * Vector3(0.03, 0.11, 0.0)
	if p < 0.12:
		return lh_home.lerp(handle, p / 0.12)
	if p > 0.88:
		return handle.lerp(lh_home, (p - 0.88) / 0.12)
	return handle


# ================================================================== firing (the holder's player)

## Rings the bell: a quick toll (1 charge) or the Great Toll (`great_cost`).
func toll(w: WeaponInstance, great: bool) -> void:
	var b: Dictionary = w.data["bell"]
	var p: Player = holder.player
	var cam: Camera3D = p.camera
	if cam == null:
		return
	w.mag = maxi(0, w.mag - (great_cost(b) if great else 1))
	holder._fired_this_frame = true
	_cd = float(b.get("toll_cooldown", 0.45)) * (2.0 if great else 1.0)
	var origin: Vector3 = cam.global_position
	var fwd: Vector3 = -cam.global_basis.z
	GLBus.weapon_fired.emit(p.player_id, w.id, w.upgraded, origin, fwd)
	var res: Dictionary = resolve(holder, origin, fwd, w, p.player_id, great)
	last_result = res
	_feedback(w, b, great, res, origin, fwd)
	drop_shards(p, b, res["kill_pos"])
	if w.mag <= 0 and w.reserve > 0:
		holder.get_tree().create_timer(0.5).timeout.connect(holder.start_reload)
	holder._ammo_warnings(w)


func _feedback(w: WeaponInstance, b: Dictionary, great: bool, res: Dictionary, origin: Vector3, fwd: Vector3) -> void:
	var p: Player = holder.player
	var col: Color = color_of(b)
	var cone: Vector2 = cone_for(b, great)
	var ring_key: String = str(b.get("great_sound" if great else "ring_sound", "totenglocke_toll"))
	AudioDirector.play_2d(ring_key, 2.0 if great else 0.0, 0.0)
	var chime: String = str(b.get("chime_sound", ""))
	if chime != "":
		holder.get_tree().create_timer(0.05).timeout.connect(func() -> void: AudioDirector.play_2d(chime, -2.0 if great else -5.0, 0.0))
	# the bell rings on in your hands
	_vibe_amp = 1.6 if great else 1.0
	_vibe_total = 2.6 if great else 1.6
	_vibe_t = _vibe_total
	holder._vm_kick(4.5 if great else 2.4)
	holder._on_shot_fx(0.1)
	if great:
		p.kick_camera(9.0, 2.5, 0.25, 6.0, 1.0, 9.0)
	else:
		p.kick_camera(4.0, 1.2, 0.2, 8.0, 0.45, 4.5)
	rumble(p, 0.9 if great else 0.5, 1.0 if great else 0.55, 0.45 if great else 0.18)
	shock_ring(holder, origin + fwd * 0.6, fwd, cone.x, col, great)
	var wall_d: float = blow_dust(holder, origin, fwd, cone.x, cone.y, 16 if great else 6, great)
	if great:
		screen_ring(holder, 0.055, 0.85, col)
		# the delayed echo off the walls: there and back at the speed of sound, plus the bell's own swell
		var delay: float = clampf(2.0 * wall_d / 343.0, 0.08, 0.5) + 0.22
		holder.get_tree().create_timer(delay).timeout.connect(func() -> void: AudioDirector.play_2d("totenglocke_echo", -3.0, 0.0))
		if int(res["shattered"]) >= int(b.get("hitstop_min", 6)):
			hitstop(holder.get_tree(), float(b.get("hitstop_scale", 0.2)), float(b.get("hitstop_seconds", 0.16)))
	else:
		screen_ring(holder, 0.02, 0.5, col)
	_chain_fx(holder, res)


static func _chain_fx(ctx: Node3D, res: Dictionary) -> void:
	var chains: Array = res.get("chains", [])
	for i: int in chains.size():
		var pair: Array = chains[i]
		arc(ctx, pair[0] as Vector3, pair[1] as Vector3, res.get("color", Color(0.65, 0.35, 1.0)) as Color)
		if i < 3:
			ctx.get_tree().create_timer(0.08 + 0.07 * i).timeout.connect(
				func() -> void: AudioDirector.play_3d("totenglocke_midnight", pair[1] as Vector3, -8.0, 0.1))


## A chain-ring arc: a jagged, glowing line from one zombie to the next that fades in a third of a second.
static func arc(ctx: Node3D, from: Vector3, to: Vector3, color: Color) -> void:
	if ctx == null or not ctx.is_inside_tree():
		return
	var host: Node = ctx.get_tree().current_scene if ctx.get_tree().current_scene != null else ctx.get_tree().root
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.lightened(0.25), 1.0)
	var root: Node3D = Node3D.new()
	host.add_child(root)
	var pts: Array[Vector3] = [from]
	for k: int in 3:
		var u: float = float(k + 1) / 4.0
		pts.append(from.lerp(to, u) + Vector3(randf_range(-0.35, 0.35), randf_range(-0.25, 0.45), randf_range(-0.35, 0.35)))
	pts.append(to)
	for k: int in pts.size() - 1:
		var a: Vector3 = pts[k]
		var c: Vector3 = pts[k + 1]
		var seg_len: float = a.distance_to(c)
		if seg_len < 0.01:
			continue
		var mi: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(0.045, 0.045, seg_len)
		mi.mesh = bm
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		var up: Vector3 = Vector3.UP if absf((c - a).normalized().dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
		mi.global_transform = Transform3D(Basis.looking_at(c - a, up), a.lerp(c, 0.5))
	var tw: Tween = root.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.38).set_ease(Tween.EASE_IN)
	tw.tween_callback(root.queue_free)


## Alt-fire: plant the Bell Dome at your feet (one at a time; costs `dome_cost` charges).
func alt_fire(w: WeaponInstance) -> void:
	var b: Dictionary = w.data["bell"]
	var cost: int = int(b.get("dome_cost", 2))
	if (_dome != null and is_instance_valid(_dome)) or w.mag < cost or _cd > 0.0 or holder.is_reloading():
		AudioDirector.play_2d("gun_dry", -4.0)
		return
	var p: Player = holder.player
	w.mag -= cost
	_cd = 0.6
	_stop_wind()
	var d: BellDome = BellDome.new()
	d.radius = float(b.get("dome_radius", 6.0))
	d.seconds = float(b.get("dome_seconds", 8.0))
	d.slow = float(b.get("dome_slow", 0.6))
	d.damage_mult = float(b.get("dome_damage_mult", 1.25))
	d.pull = float(b.get("dome_pull", 0.0))
	d.color = color_of(b)
	d.upgraded = w.upgraded
	d.by_player = p.player_id
	p.get_parent().add_child(d)
	d.global_position = p.global_position
	_dome = d
	_vibe_amp = 0.8
	_vibe_total = 1.2
	_vibe_t = 1.2
	holder._vm_kick(1.4)
	p.kick_camera(2.0, 0.5, 0.1, 8.0, 0.3, 2.0)
	rumble(p, 0.4, 0.6, 0.25)
	if w.mag <= 0 and w.reserve > 0:
		holder.get_tree().create_timer(0.6).timeout.connect(holder.start_reload)
	holder._ammo_warnings(w)


func active_dome() -> BellDome:
	return _dome as BellDome if _dome != null and is_instance_valid(_dome) else null


## Seconds held so far (tests / the HUD).
func wind_progress(b: Dictionary) -> float:
	if not _holding:
		return 0.0
	return clampf(_hold_t / maxf(0.05, float(b.get("wind_seconds", 1.5))), 0.0, 1.0)


func is_winding() -> bool:
	return _holding


# ================================================================== presentation helpers (static)

## Controller rumble for a local human (a no-op without a pad).
static func rumble(p: Player, weak: float, strong: float, seconds: float) -> void:
	if p == null or p.is_bot:
		return
	var pads: Array[int] = Input.get_connected_joypads()
	if pads.is_empty():
		return
	Input.start_joy_vibration(pads[0], clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), seconds)


## A brief hitstop: Engine.time_scale dips to `scale` for `seconds` of real time, then goes back to 1. Only on
## a single machine (co-op peers would desync) and only when nothing else (a smoke, the dev console) has changed
## the time scale; it never stacks, and the restore runs even while paused.
static func hitstop(tree: SceneTree, scale: float, seconds: float) -> bool:
	if tree == null or _hitstop_on or Net.is_online() or absf(Engine.time_scale - 1.0) > 0.0001:
		return false
	_hitstop_on = true
	hitstops += 1
	Engine.time_scale = scale
	tree.create_timer(seconds, true, false, true).timeout.connect(func() -> void:
		if absf(Engine.time_scale - scale) < 0.0001:
			Engine.time_scale = 1.0
		_hitstop_on = false)
	return true


## A one-shot particle burst (shatter shards, blown snow). Freed after it finishes.
static func burst(host: Node, pos: Vector3, color: Color, amount: int, speed: float, along: Vector3 = Vector3.ZERO) -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.one_shot = true
	p.amount = maxi(1, amount)
	p.lifetime = 1.1
	p.explosiveness = 0.95
	p.direction = (along * 0.8 + Vector3.UP * 0.6).normalized() if along.length_squared() > 0.01 else Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -12.0, 0)
	p.angular_velocity_min = -720.0
	p.angular_velocity_max = 720.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	var m: BoxMesh = BoxMesh.new()
	m.size = Vector3(0.06, 0.09, 0.025)
	m.material = Interactable.greybox_mat(color, 2.5)
	p.mesh = m
	host.add_child(p)
	p.global_position = pos
	p.emitting = true
	host.get_tree().create_timer(1.8).timeout.connect(p.queue_free)
	return p


static var _dust_mat: StandardMaterial3D = null


static func _dust_material() -> StandardMaterial3D:
	if _dust_mat == null:
		var g: Gradient = Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0.8))
		g.set_color(1, Color(1, 1, 1, 0.0))
		var tex: GradientTexture2D = GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 32
		tex.height = 32
		_dust_mat = StandardMaterial3D.new()
		_dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_dust_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_dust_mat.albedo_texture = tex
		_dust_mat.vertex_color_use_as_albedo = true
		_dust_mat.albedo_color = Color(0.92, 0.94, 0.97, 0.75)
	return _dust_mat


## Snow and dust blown off every surface the cone touches: `rays` random rays inside the cone; where one hits,
## a puff races away from the bell along the surface. Returns the mean distance to what was hit (the echo).
static func blow_dust(ctx: Node3D, origin: Vector3, fwd: Vector3, max_range: float, cone_deg: float, rays: int, big: bool) -> float:
	if ctx == null or not ctx.is_inside_tree():
		return max_range
	var host: Node = ctx.get_tree().current_scene if ctx.get_tree().current_scene != null else ctx.get_tree().root
	var space: PhysicsDirectSpaceState3D = ctx.get_world_3d().direct_space_state
	var basis: Basis = Basis.looking_at(fwd, Vector3.UP if absf(fwd.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT)
	var sum: float = 0.0
	var n: int = 0
	for i: int in rays:
		var a: float = randf() * TAU
		var r: float = sqrt(randf()) * deg_to_rad(cone_deg * 0.5)
		var dir: Vector3 = (basis * Vector3(sin(a) * sin(r), cos(a) * sin(r) * 0.6 - 0.12, -cos(r))).normalized()
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + dir * max_range, 1)
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			continue
		var pos: Vector3 = hit["position"]
		var nrm: Vector3 = hit["normal"]
		sum += origin.distance_to(pos)
		n += 1
		var p: CPUParticles3D = CPUParticles3D.new()
		p.one_shot = true
		p.amount = 26 if big else 12
		p.lifetime = 1.6 if big else 1.0
		p.explosiveness = 0.85
		var along: Vector3 = (dir - nrm * dir.dot(nrm)).normalized()
		p.direction = (along + nrm * 0.7).normalized()
		p.spread = 35.0
		p.initial_velocity_min = 1.5
		p.initial_velocity_max = 6.0 if big else 3.5
		p.gravity = Vector3(0, -1.6, 0)
		p.damping_min = 1.5
		p.damping_max = 3.0
		p.scale_amount_min = 0.6
		p.scale_amount_max = 2.2 if big else 1.4
		var qm: QuadMesh = QuadMesh.new()
		qm.size = Vector2(0.35, 0.35)
		qm.material = _dust_material()
		p.mesh = qm
		var sc: Curve = Curve.new()
		sc.add_point(Vector2(0.0, 0.4))
		sc.add_point(Vector2(0.3, 1.0))
		sc.add_point(Vector2(1.0, 1.3))
		p.scale_amount_curve = sc
		var cr: Gradient = Gradient.new()
		cr.set_color(0, Color(1, 1, 1, 0.9))
		cr.set_color(1, Color(1, 1, 1, 0.0))
		p.color_ramp = cr
		host.add_child(p)
		p.global_position = pos + nrm * 0.08
		p.emitting = true
		host.get_tree().create_timer(p.lifetime + 0.4).timeout.connect(p.queue_free)
	return sum / float(n) if n > 0 else max_range


## The visible shockwave: a bronze ring that races out of the bell's mouth to the cone's range and fades.
static func shock_ring(ctx: Node3D, origin: Vector3, fwd: Vector3, max_range: float, color: Color, great: bool) -> void:
	if ctx == null or not ctx.is_inside_tree():
		return
	var host: Node = ctx.get_tree().current_scene if ctx.get_tree().current_scene != null else ctx.get_tree().root
	var mi: MeshInstance3D = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	tm.rings = 48
	tm.ring_segments = 6
	mi.mesh = tm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(color, 0.85 if great else 0.6)
	mi.material_override = m
	host.add_child(mi)
	var up: Vector3 = Vector3.UP if absf(fwd.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	mi.global_transform = Transform3D(Basis.looking_at(fwd, up) * Basis(Vector3.RIGHT, PI * 0.5), origin)
	mi.scale = Vector3.ONE * 0.15
	var dur: float = 0.42 if great else 0.28
	var spread: float = max_range * (0.7 if great else 0.5)
	var tw: Tween = mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "global_position", origin + fwd * max_range * 0.85, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(mi, "scale", Vector3(spread, 1.0, spread), dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(m, "albedo_color:a", 0.0, dur).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)


const RING_SHADER: String = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float t = 0.0;
uniform float strength = 0.04;
uniform vec4 tint : source_color = vec4(1.0, 0.65, 0.3, 1.0);
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 asp = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	vec2 d = (uv - 0.5) * asp;
	float r = length(d);
	float fade = 1.0 - t;
	float band = 0.0;
	for (int i = 0; i < 2; i++) {
		float rad = t * 1.15 - float(i) * 0.22;
		band += smoothstep(0.13, 0.0, abs(r - rad)) * (rad > 0.0 ? 1.0 : 0.0) * (1.0 - float(i) * 0.45);
	}
	vec2 dir = r > 0.0001 ? d / r : vec2(0.0);
	vec2 off = dir * band * strength * fade / asp;
	off += vec2(sin(uv.y * 60.0 + t * 40.0), cos(uv.x * 50.0 - t * 35.0)) * 0.0025 * fade * strength * 25.0;
	vec3 c;
	c.r = texture(screen_tex, uv - off * 1.2).r;
	c.g = texture(screen_tex, uv - off).g;
	c.b = texture(screen_tex, uv - off * 0.8).b;
	c += tint.rgb * band * 0.09 * fade;
	COLOR = vec4(c, 1.0);
}
"""
static var _ring_shader: Shader = null


## The big screen-ring distortion (a full-screen refraction ring racing outward), for the local human only.
static func screen_ring(h: WeaponHolder, strength: float, seconds: float, color: Color) -> void:
	if h == null or h.player == null or h.player.is_bot or not h.is_inside_tree():
		return
	if _ring_shader == null:
		_ring_shader = Shader.new()
		_ring_shader.code = RING_SHADER
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 6
	var rect: ColorRect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _ring_shader
	mat.set_shader_parameter("strength", strength)
	mat.set_shader_parameter("tint", color)
	mat.set_shader_parameter("t", 0.0)
	rect.material = mat
	layer.add_child(rect)
	h.get_viewport().add_child.call_deferred(layer)
	var tw: Tween = layer.create_tween()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("t", v), 0.0, 1.0, seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(layer.queue_free)
