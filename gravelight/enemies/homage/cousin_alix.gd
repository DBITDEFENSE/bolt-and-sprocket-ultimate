class_name CousinAlix
extends HomageBoss
## Alix, the Third Hand (Cousin 3; docs/HOMAGE_BOSSES.md section 4.5). Dark hair in two buns, a too-big navy
## Sunday dress (long-sleeved, below the knee, a white collar), dark stockings, and a wide red ribbon bow at the
## breastbone that hides the root of the third arm: a small hand that comes out from under the bow, palm up,
## waiting to be held. Held perfectly upright. She never blinks; her steps make no sound, only the dress rustles.
## All her hits do 2x a normal zombie's (bcfg damage_mult).
## Movement: within 8 m she walks, slow and upright, as if led by the hand. Beyond 8 m she is on ObservedFreeze:
## frozen mid-step while any player sees her (frustum + line of sight; bots count, see ObservedFreeze), 6 m/s
## while nobody does. +20% per enrage.
## Moves:
##   - Swipe (0.55 s, the arm lifts stiffly, no sound but the dress; 2.2 m, 100);
##   - Holding Hand (0.5 s: the Third Hand turns palm up, the hum drops out): within 2 m it takes the player's
##     hand: the screen vignettes and the audio ducks (the held_hand status FX), 30 / s for up to 6 s while she
##     drags them slowly toward the trapdoor (1 m/s). Break: the held player's melee x3, teammates' 300 damage to
##     her (x0.5 if not on the palm), or the 6 s;
##   - Lash (0.9 s: both normal hands rise slowly to her ears): the third arm whips out to 5 m in a flat arc at
##     chest height, 90; crouch or slide under it;
##   - Double Lash (enraged): two lashes, the second 0.4 s later, mirrored.
## Weak point: the Third Hand's palm x2 while it is extended (almost always; it folds during the Lash wind-up).
## When a cousin dies she walks to the body and holds its hand for 3 s, kneeling (x2 damage taken; 20% of her max
## HP in the window ends it early), then rises enraged: the third arm drips Nachtglas light and Lash becomes Double
## Lash. Death: the third arm reaches up toward the inn upstairs and closes slowly into a fist; she sinks to her
## knees, still upright.
## T-232 (the boss rework, docs/BOSS_REWORK.md 4.1, docs/boss_rework/w1_cousins.md): the doll register pushed. The
## porcelain glaze, glass eyes that never blink, hairline cracks that spread with the damage (crack_tiers), the red
## ribbon's tails swinging from the bow, Nachtglas motes rising off the Third Hand whenever it opens for someone (the
## hold's telegraph, the hold, and always once she drips). The kit: a dread block (porcelain; her steps stay silent),
## fx.tele on every telegraph, the pack on every move (the breath she holds for the Lash, the bone crack of the whip,
## porcelain splitting as she rises enraged), dust and old ice from the hatch and the lamps guttering as she rises.
## Battle: the grief window lengthens with each dead cousin (grieve.seconds + seconds_step per dead cousin beyond
## the first: 3.0 s, then 4.5 s) and she hits harder after each rise (grieve.damage_step: +15 % per grief, on top of
## her double damage). The squad rule (cousins.json "step"): within her walking band, a player who turns their back
## on her for away_seconds hears the dress rustle and she takes a step: a short glide at her unseen speed that stops
## stop_at metres short (no damage: the consequence of looking away is that she is closer). As the last cousin
## standing she hunts in the dark with only the hearth relit (CousinsRound.dark_hunt); her drip is the readability
## light.

const HAIR: Color = Color(0.1, 0.08, 0.08)
const NAVY: Color = Color(0.13, 0.15, 0.26)
const WHITE: Color = Color(0.88, 0.86, 0.82)
const RIBBON: Color = Color(0.74, 0.07, 0.1)
const STOCKING: Color = Color(0.09, 0.08, 0.09)
const SKIN: Color = Color(0.82, 0.8, 0.82)
const VIOLET: Color = Color(0.7, 0.35, 1.0)
const CRACK: Color = Color(0.42, 0.2, 0.62)
const GLASS_EYE: Color = Color(0.78, 0.84, 1.0)

var third: HomageArm
var freeze: ObservedFreeze = ObservedFreeze.new()
var frozen: bool = false
var frozen_frames: int = 0           # physics frames spent frozen (tests / the smoke)
var unseen_moves: float = 0.0        # metres moved while unobserved beyond 8 m
var holds_landed: int = 0
var lashes: int = 0
var lash_dodged: int = 0
var griefs: int = 0
var grief_rises: int = 0             # griefs she rose from (each makes her hit harder)
var steps_taken: int = 0             # look-away steps (the squad rule)
var crack_tier_now: int = 0
var doll_cracks: int = 0
var dripping: bool = false
var dark_hunt: bool = false
var trapdoor: Vector3 = Vector3.INF  # where a held player is led
var _grief_body: Node3D = null
var _grief_queue: Array[Node3D] = []
var _grief_dmg: float = 0.0
var _lash_i: int = 0
var _lash_hit: Dictionary = {}
var _hold_g: Dictionary = {}
var _drip: OmniLight3D
var _anchor: Node3D
var _death_fist: float = 0.0
var _away_t: float = 0.0
var _step_t: float = 0.0
var _motes: GPUParticles3D = null
var _crack_tiers: Array = []
var _hum_loop: AudioStreamPlayer3D = null
var _eyes: Node3D = null
var _emerged_fx: bool = false


func _init() -> void:
	boss_key = "alix"


# ---------------------------------------------------------------- pure rules (unit-tested)

## The grief window's length after `dead` cousins have fallen: base + step per dead cousin beyond the first
## (3.0 s for the first, 4.5 s for the second). She hesitates longer each time.
static func grief_seconds(base: float, step: float, dead: int) -> float:
	return base + step * float(maxi(0, dead - 1))


## Her hits after `rises` griefs: x(1 + step x rises) on top of her double damage.
static func grief_damage_mult(step: float, rises: int) -> float:
	return 1.0 + step * float(maxi(0, rises))


## The look-away rule: true when the player's view (`cam_fwd`) points more than `away_deg` from the boss (`to_boss`
## from the player). Flat (the y is ignored).
static func looking_away(cam_fwd: Vector3, to_boss: Vector3, away_deg: float) -> bool:
	var f: Vector3 = Vector3(cam_fwd.x, 0.0, cam_fwd.z)
	var t: Vector3 = Vector3(to_boss.x, 0.0, to_boss.z)
	if f.length_squared() < 1e-6 or t.length_squared() < 1e-6:
		return false
	return rad_to_deg(f.normalized().angle_to(t.normalized())) > away_deg


func grief_seconds_now() -> float:
	var g: Dictionary = bcfg["grieve"]
	var dead: int = int(event.call("dead_count")) if event != null and event.has_method("dead_count") else griefs
	return grief_seconds(float(g["seconds"]), float(g.get("seconds_step", 0.0)), dead)


## Her hits grow with each grief she rose from.
func hit_player(p: Player, amount: float) -> void:
	super.hit_player(p, amount * grief_damage_mult(float((bcfg.get("grieve", {}) as Dictionary).get("damage_step", 0.0)), grief_rises))


func _on_spawned() -> void:
	freeze.include_bots = bool(ecfg.get("observers_include_bots", true))
	frozen = false
	dripping = false
	dark_hunt = false
	grief_rises = 0
	crack_tier_now = 0
	_set_crack_tier(0)
	_drip.light_energy = 0.0
	_grief_body = null
	_set_third_rest(true)
	third.show()
	third.set_reach_on(true)
	_look.primary_limit_angle = deg_to_rad(80.0)
	_away_t = 0.0
	_emerged_fx = false


# ---------------------------------------------------------------- brain

func _tick(delta: float) -> void:
	_update_third(delta)
	if _motes != null:
		_motes.emitting = third.visible and (dripping or (move_id == "hold" and (bstate == B.TELEGRAPH or bstate == B.ACTIVE)))
	if fx != null and dark_hunt:
		fx.extra_dread = maxf(fx.extra_dread, 0.3)
	match bstate:
		B.ARRIVE:
			_tick_emerge(delta)
		B.MOVE:
			_think(delta)
		B.TELEGRAPH:
			_telegraph(delta)
		B.ACTIVE:
			_active(delta)
		B.RECOVER:
			stand(delta)
			if _bt >= 0.45:
				_go(B.MOVE)
		B.SPECIAL:
			if move_id == "step":
				_tick_step(delta)
			else:
				_tick_grief(delta)


## Rising from the trapdoor: a small hand first, then she rises perfectly upright, as if lifted. Dust and old ice
## fall from the hatch; the lamps near it gutter.
func _tick_emerge(delta: float) -> void:
	_halt(delta)
	if not _emerged_fx and is_inside_tree():
		_emerged_fx = true
		BossFx.burst("dust", global_position + Vector3.UP * 0.3, get_tree(), 1.6, 1.4)
		BossFx.burst("frost", global_position + Vector3.UP * 0.5, get_tree(), 1.4, 1.2)
		# the lamps near the hatch gutter (only when no relight can be running: before any death)
		var dead: int = int(event.call("dead_count")) if event != null and event.has_method("dead_count") else 0
		if dead == 0:
			_flicker_room(1.8, 0.7, 14.0)
		sfx("boss_breath", -4.0, 0.7)
	var secs: float = float(bcfg.get("emerge_seconds", 1.6))
	_pivot.position.y = lerpf(-1.75, 0.0, clampf(_bt / secs, 0.0, 1.0))
	if _bt >= secs:
		_pivot.position.y = 0.0
		_go(B.MOVE)


func _think(delta: float) -> void:
	if not _grief_queue.is_empty():
		_start_grief_walk()
		return
	if target == null:
		stand(delta, false)
		return
	var c: Dictionary = bcfg
	var d: float = dist_to(target)
	var dy: float = absf(target.global_position.y - global_position.y)
	var near: bool = d <= float(c["freeze_beyond"])
	if not near:
		_away_t = 0.0
		# beyond 8 m: only while unobserved
		frozen = freeze.update(get_physics_process_delta_time(), self, look_points())
		if frozen:
			frozen_frames += 1
			_halt(delta)
			return
		var before: Vector3 = global_position
		walk_to(target.global_position, delta, float(c["unseen_speed"]) * speed_mult() * squad_speed_mult)
		unseen_moves += before.distance_to(global_position)
		return
	frozen = false
	freeze.observed = false
	if _tick_away(delta, d):
		return
	if dy < 1.4 and d <= float(c["hold"]["range"]) and cd_ready("hold") and can_grab(target) and _clear_to(target):
		_begin("hold", float(c["hold"]["telegraph"]))
	elif dy < 1.4 and d <= float(c["swipe"]["range"]) and cd_ready("swipe") and _clear_to(target):
		_begin("swipe", float(c["swipe"]["telegraph"]))
	elif dy < 1.6 and d <= float(c["lash"]["range"]) and cd_ready("lash") and has_los(target):
		_begin("lash", float(c["lash"]["telegraph"]))
	else:
		walk_to(target.global_position, delta)


## The squad rule: within her walking band, a player who stops looking at her for away_seconds hears the dress and
## she takes a step (a short glide at her unseen speed, stopping short). Returns true when the step began.
func _tick_away(delta: float, d: float) -> bool:
	var sc: Dictionary = bcfg.get("step", {})
	if sc.is_empty() or not cd_ready("step") or d <= float(sc.get("stop_at", 2.6)) or not has_los(target):
		_away_t = 0.0
		return false
	var fwd: Vector3 = -target.camera.global_basis.z if target.camera != null else -target.global_basis.z
	if looking_away(fwd, global_position - target.global_position, float(sc.get("away_deg", 100.0))):
		_away_t += delta
	else:
		_away_t = 0.0
	if _away_t < float(sc.get("away_seconds", 0.6)):
		return false
	_away_t = 0.0
	steps_taken += 1
	set_cd("step", float(sc.get("cooldown", 5.0)))
	_step_t = 0.0
	sfx("boss_breath", -6.0, 1.5)   # only the dress, behind you
	_go(B.SPECIAL, "step")
	return true


func _tick_step(delta: float) -> void:
	var sc: Dictionary = bcfg.get("step", {})
	_step_t += delta
	if target == null or _step_t >= float(sc.get("glide_seconds", 0.45)) or dist_to(target) <= float(sc.get("stop_at", 2.6)):
		_go(B.MOVE)
		return
	walk_to(target.global_position, delta, float(bcfg["unseen_speed"]) * speed_mult() * squad_speed_mult)


var _tele_total: float = 0.5


func _begin(id: String, telegraph: float) -> void:
	_tele_total = tele_len(telegraph)
	_go(B.TELEGRAPH, id)
	match id:
		"swipe":
			attack_anim("swipe_over", _tele_total)
			sfx("boss_breath", -16.0, 1.4)   # only the dress rustling (no wind-up sound)
			fx.tele(VIOLET, 1.0, _tele_total, false)
		"hold":
			pose_anim()
			_hum_mute = _tele_total + 0.6   # the hum drops out
			fx.tele(VIOLET, 2.5, _tele_total)
		"lash":
			pose_anim()
			# her two normal hands rise slowly to her ears, as if she can't bear a sound
			_pose.set_bone("LeftUpperArm", Vector3(2.1, 0, 0.9))
			_pose.set_bone("RightUpperArm", Vector3(2.1, 0, -0.9))
			_pose.set_bone("LeftLowerArm", Vector3(1.6, 0, 0))
			_pose.set_bone("RightLowerArm", Vector3(1.6, 0, 0))
			sfx("boss_breath", -4.0, 0.7)   # the breath she holds
			fx.tele(VIOLET, 3.0, _tele_total)


func _telegraph(delta: float) -> void:
	stand(delta)
	if _bt < _tele_total:
		return
	var c: Dictionary = bcfg
	match move_id:
		"swipe":
			set_cd("swipe", float(c["swipe"]["cooldown"]))
			if target != null and dist_to(target) <= float(c["swipe"]["range"]) + 0.5 and _clear_to(target):
				hit_player(target, float(c["swipe"]["damage"]))
			_go(B.RECOVER)
		"hold":
			set_cd("hold", float(c["hold"]["cooldown"]))
			if target != null and dist_to(target) <= float(c["hold"]["range"]) + 0.4 and can_grab(target):
				holds_landed += 1
				var hc: Dictionary = c["hold"]
				_hold_g = grab_start(target, "hold", {"mash": int(hc["break_melee"]), "team": float(hc["break_team_damage"]), "max": float(hc["max_hold"])},
					[&"palm"], "held")
				_hold_g["lock"] = float(hc["regrab_lock"])
				say("ALX_HOLD_01" if randf() < 0.5 else "ALX_HOLD_02")
				_go(B.ACTIVE, "hold")
			else:
				_go(B.RECOVER)
		"lash":
			set_cd("lash", float(c["lash"]["double_cooldown"]) if dripping else float(c["lash"]["cooldown"]))
			_lash_i = 0
			_lash_hit.clear()
			_pose.clear()
			sfx("boss_bone_crack", 2.0, 1.3)   # the third arm unfolds like a lock-knife
			_go(B.ACTIVE, "lash")


func _active(delta: float) -> void:
	var c: Dictionary = bcfg
	if move_id == "hold":
		stand(delta)
		if not _grabs.has(_hold_g):
			_hum_mute = 0.0
			_go(B.RECOVER)
			return
		var p: Player = _hold_g["p"]
		var to: Vector3 = trapdoor if trapdoor != Vector3.INF else global_position
		drag_player(p, to, float(c["hold"]["drag"]), delta, 0.6)
		# she walks with them, slowly, toward the trapdoor
		if trapdoor != Vector3.INF and dist_to(p) > 1.2:
			walk_to(p.global_position, delta, float(c["speed"]) * 0.6)
		var before: float = float(_hold_g["t"]) - delta
		var dps: float = float(c["hold"]["dps"])
		var ticks: int = int(floor(float(_hold_g["t"]) / 0.25)) - int(floor(maxf(0.0, before) / 0.25))
		if ticks > 0:
			hit_player(p, dps * 0.25 * float(ticks))
		_hum_mute = 0.5
		return
	# the lash: a flat arc at chest height, out to 5 m (Double Lash when dripping: the second one mirrored)
	stand(delta)
	var swing: float = 0.25
	var gap: float = float(c["lash"]["double_gap"])
	var count: int = 2 if dripping else 1
	var local_t: float = _bt - float(_lash_i) * (swing + gap)
	if local_t >= 0.0 and local_t <= swing:
		var k: float = local_t / swing
		var side: float = 1.0 if _lash_i % 2 == 0 else -1.0
		var half: float = deg_to_rad(float(c["lash"]["arc_deg"]) * 0.5)
		var ang: float = lerpf(-half, half, k) * side
		var fwd: Vector3 = (-global_basis.z).rotated(Vector3.UP, ang)
		fwd.y = 0.0
		third.tip = _anchor.global_position + fwd.normalized() * float(c["lash"]["range"])
		_lash_sweep(fwd.normalized(), float(c["lash"]["range"]))
	elif local_t > swing:
		if _lash_i + 1 < count:
			_lash_i += 1
			_lash_hit.clear()
			sfx("boss_bone_crack", 2.0, 1.2)   # the second lash, mirrored
		else:
			_go(B.RECOVER)


func _lash_sweep(dir: Vector3, reach: float) -> void:
	for p: Player in alive_players():
		if _lash_hit.has(p.player_id):
			continue
		var to: Vector3 = p.global_position - global_position
		to.y = 0.0
		if to.length() > reach + 0.3 or to.length() < 0.05:
			continue
		if absf(p.global_position.y - global_position.y) > 1.6:
			continue
		if dir.angle_to(to.normalized()) > deg_to_rad(14.0):
			continue
		_lash_hit[p.player_id] = true
		if p.crouching or p.sliding:
			lash_dodged += 1
			continue   # under it
		lashes += 1
		hit_player(p, float(bcfg["lash"]["damage"]))


## The third arm: extended palm-up (rest), folded during the Lash wind-up, out to the held hand while holding.
func _update_third(_delta: float) -> void:
	if third == null:
		return
	if bstate == B.ACTIVE and move_id == "lash":
		third.set_reach_on(true)
		return   # the lash drives the tip
	if bstate == B.ACTIVE and move_id == "hold" and _grabs.has(_hold_g):
		var p: Player = _hold_g["p"]
		third.tip = p.global_position + Vector3.UP * 1.05
		third.set_reach_on(true)
		return
	var folded: bool = bstate == B.TELEGRAPH and move_id == "lash"
	_set_third_rest(not folded)


func _set_third_rest(extended: bool) -> void:
	if _anchor == null:
		return
	var fwd: Vector3 = -global_basis.z
	third.tip = _anchor.global_position + (fwd * 0.48 + Vector3.DOWN * 0.04 if extended else fwd * 0.06 + Vector3.DOWN * 0.05)
	third.set_reach_on(extended)


func damage_taken_mult() -> float:
	return float(bcfg["grieve"]["mult"]) if bstate == B.SPECIAL and _grief_body != null and _grief_kneeling else 1.0


func _on_damaged(amount: float, _limb: StringName, _by: int, _kind: StringName) -> void:
	super._on_damaged(amount, _limb, _by, _kind)
	var tier: int = CousinHammer.crack_tier(hp_fraction(), ecfg.get("crack_tiers", [0.75, 0.5, 0.25]) as Array)
	if tier > crack_tier_now:
		_set_crack_tier(tier)
		doll_cracks += 1
		if is_inside_tree() and fx != null:
			sfx("boss_doll_crack", 0.0, 0.95 + 0.08 * float(tier))
			BossFx.burst("chips", fx.limb_pos(_limb), get_tree(), 1.2, 1.0)
	if bstate == B.SPECIAL and _grief_kneeling:
		_grief_dmg += amount
		if _grief_dmg >= max_hp * float(bcfg["grieve"]["break_fraction"]):
			_end_grief()


func _set_crack_tier(tier: int) -> void:
	crack_tier_now = tier
	for i: int in _crack_tiers.size():
		for mi: MeshInstance3D in _crack_tiers[i]:
			if is_instance_valid(mi):
				mi.visible = i < tier


## The last cousin standing: the lamps are out again, only the hearth burns; her drip is the light that moves.
func set_dark_hunt(on: bool) -> void:
	dark_hunt = on
	if on and _drip != null and not dripping:
		_drip.light_energy = 1.0


# ---------------------------------------------------------------- grief: holding a fallen cousin's hand

## The event: a cousin fell at `body`'s spot. She goes there first (also if she arrives after the death).
func on_cousin_fell(body: Node3D) -> void:
	if body != null and not _grief_queue.has(body):
		_grief_queue.append(body)


var _grief_kneeling: bool = false


func _start_grief_walk() -> void:
	_grief_body = _grief_queue.pop_front()
	_grief_kneeling = false
	_grief_dmg = 0.0
	_release_all_grabs("grief")
	_pose.clear()
	_go(B.SPECIAL, "grief")


func _tick_grief(delta: float) -> void:
	if _grief_body == null or not is_instance_valid(_grief_body):
		_end_grief()
		return
	var spot: Vector3 = (_grief_body as HomageBoss).death_pos if _grief_body is HomageBoss else _grief_body.global_position
	if not _grief_kneeling:
		if dist_to_point(spot) > float(bcfg["grieve"]["reach"]) and _bt < 20.0:
			walk_to(spot, delta, move_speed() * 1.4)
			return
		_grief_kneeling = true
		_bt = 0.0
		griefs += 1
		_halt(delta)
		_face(spot)
		_tree_play("Death", "death_knee", 0.7)   # kneeling (the knee clip, held), the Third Hand folded over both
		state = State.ATTACK
		_dead_name = HomageBoss.speaker_name(str((_grief_body as HomageBoss).bcfg.get("slot", "")), true) if _grief_body is HomageBoss else ""
		say("ALX_COUSIN_01")
		sfx("boss_breath", -2.0, 0.6)
		_hum_mute = 1.5   # the hum stops while she kneels
		return
	_halt(delta)
	third.tip = spot + Vector3.UP * 0.35
	if _bt >= grief_seconds_now():
		_end_grief()


var _dead_name: String = ""


func dead_name() -> String:
	return _dead_name


func dist_to_point(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


## She rises enraged: the third arm drips Nachtglas light, and the Lash becomes the Double Lash.
func _end_grief() -> void:
	var was: bool = _grief_kneeling
	_grief_kneeling = false
	_grief_body = null
	state = State.CHASE
	_tree_locomotion(true)
	if was:
		dripping = true
		grief_rises += 1
		_drip.light_energy = 2.2
		say("ALX_ENRAGE_01")
		# she rises: something in her splits, the lamps near her gutter, the hum goes flat from here
		sfx("boss_doll_crack", 2.0, 0.9)
		_flicker_room(1.6, 0.85)
		if is_inside_tree():
			BossFx.burst("motes", _anchor.global_position if _anchor != null else global_position + Vector3.UP, get_tree(), 1.5, 1.2)
	_go(B.MOVE)


func _on_enraged() -> void:
	pass   # her step comes with the grief window (on_cousin_fell); the speed step is already applied


## A beat on the room's lights through the kit: the lamps within `radius` gutter for `seconds`, then the kit lets
## them go (lights_restore right after, so a later relight by the CousinsRound is never undone at cleanup).
func _flicker_room(seconds: float, depth: float, radius: float = 16.0) -> void:
	if fx == null or not is_inside_tree():
		return
	fx.lights_dim(global_position, radius, 1.0, 0.05)
	fx.lights_flicker(seconds, depth)
	var k: BossFx = fx
	get_tree().create_timer(seconds + 0.1).timeout.connect(func() -> void:
		if is_instance_valid(k):
			k.lights_restore(0.2))


## fx.tele owns the telegraph light.
func _tele_glow() -> float:
	return _tele_light.light_energy


## The hum: the shared lullaby; once enraged (she has risen from a grief), the lullaby hummed flat as a loop.
func _update_audio(delta: float) -> void:
	if (enrage_steps >= 1 or dripping) and is_active():
		if _hum_loop == null:
			_hum_loop = AudioDirector.make_loop_3d("boss_hum_wrong", self, -9.0)
			if _hum_loop != null:
				_hum_loop.pitch_scale = _hum_pitch()
		if _hum_loop != null:
			var want: bool = _hum_mute <= 0.0
			if want and not _hum_loop.playing:
				_hum_loop.play()
			elif not want and _hum_loop.playing:
				_hum_loop.stop()
		return
	super._update_audio(delta)


func _stop_hum() -> void:
	if _hum_loop != null and is_instance_valid(_hum_loop) and _hum_loop.playing:
		_hum_loop.stop()


func _vanish() -> void:
	_stop_hum()
	super._vanish()


## Her steps make no sound.
func _footstep(_left: bool) -> void:
	pass


func _hum_pitch() -> float:
	return 0.8


func _process(delta: float) -> void:
	if frozen and state != State.DEAD:
		return   # the freeze: the tree is not advanced, the pose holds mid-step
	super._process(delta)


func _on_retreat() -> void:
	_grief_queue.clear()
	_grief_body = null
	_stop_hum()
	if _motes != null:
		_motes.emitting = false


## Down into the trapdoor without bending.
func _tick_retreat(delta: float) -> void:
	_halt(delta)
	_pivot.position.y = lerpf(0.0, -1.9, clampf((_bt - 0.4) / 1.4, 0.0, 1.0))
	if _bt >= 2.0:
		_vanish()


func _start_authored_death() -> void:
	_stop_hum()
	if _motes != null:
		_motes.emitting = false
	_tree_play("Death", "death_knee", 0.45)
	_pose.clear()
	_death_fist = 0.0
	say("ALX_DEATH_01")
	if dripping:
		_drip.light_energy = 0.6
	_set_crack_tier(_crack_tiers.size())
	sfx("boss_doll_crack", 2.0, 0.85)


## The third arm reaches up toward the ceiling, toward the inn upstairs, toward her aunt, and closes into a fist.
func _death_tick(delta: float) -> void:
	_death_fist = minf(1.0, _death_fist + delta / 2.5)
	if _anchor != null:
		third.tip = _anchor.global_position + Vector3.UP * lerpf(0.4, 0.75, _death_fist) + (-global_basis.z) * 0.15
		third.hand_mi.scale = Vector3.ONE * lerpf(1.0, 0.65, _death_fist)
	third.set_reach_on(false)


func _hold_after() -> float:
	return 2.9


func _build_costume() -> void:
	# T-092: the modelled doll carries her hair and clothes; the primitives stay for the legacy bodies
	if not modelled():
		# dark hair in two buns (never over the face)
		costume("Head", [
			sph(0.136, Vector3(0, 0.105, 0.012), HAIR, Vector3(1.0, 0.97, 1.04), true),
			boxp(Vector3(0.25, 0.12, 0.05), Vector3(0, 0.08, 0.1), HAIR),
			sph(0.058, Vector3(-0.095, 0.21, 0.03), HAIR),
			sph(0.058, Vector3(0.095, 0.21, 0.03), HAIR)])
		# the too-big navy Sunday dress, white collar, the red ribbon bow at the breastbone
		costume("Chest", [
			cyl(0.2, 0.218, 0.37, Vector3(0, 0.15, 0.004), NAVY, Vector3.ZERO, Vector3(1.0, 1.0, 0.72)),
			cyl(0.08, 0.1, 0.045, Vector3(0, 0.3, 0), WHITE),
			boxp(Vector3(0.16, 0.012, 0.06), Vector3(0, 0.29, -0.09), WHITE, Vector3(0.5, 0, 0)),
			boxp(Vector3(0.09, 0.07, 0.02), Vector3(-0.05, 0.1, -0.165), RIBBON, Vector3(0, 0, 0.5)),
			boxp(Vector3(0.09, 0.07, 0.02), Vector3(0.05, 0.1, -0.165), RIBBON, Vector3(0, 0, -0.5)),
			sph(0.025, Vector3(0, 0.1, -0.17), RIBBON),
			boxp(Vector3(0.025, 0.08, 0.012), Vector3(-0.02, 0.04, -0.165), RIBBON, Vector3(0, 0, 0.25)),
			boxp(Vector3(0.025, 0.08, 0.012), Vector3(0.02, 0.04, -0.165), RIBBON, Vector3(0, 0, -0.25))])
		costume("Spine", [cyl(0.2, 0.21, 0.26, Vector3(0, 0.1, 0.004), NAVY, Vector3.ZERO, Vector3(1.05, 1.0, 0.78))])
		costume("Hips", [cyl(0.21, 0.355, 0.8, Vector3(0, -0.39, 0.0), NAVY, Vector3.ZERO, Vector3(1.06, 1.0, 0.94))])   # well below the knee
		for side: String in ["Left", "Right"]:
			costume(side + "UpperArm", [cyl(0.064, 0.058, 0.31, Vector3(0, -0.14, 0), NAVY)])
			costume(side + "LowerArm", [cyl(0.056, 0.05, 0.27, Vector3(0, -0.12, 0), NAVY), cyl(0.06, 0.06, 0.03, Vector3(0, -0.25, 0), WHITE)])
			costume(side + "LowerLeg", [cyl(0.058, 0.048, 0.36, Vector3(0, -0.19, 0), STOCKING)])
			costume(side + "Foot", [boxp(Vector3(0.09, 0.07, 0.19), Vector3(0, -0.03, -0.035), STOCKING), boxp(Vector3(0.03, 0.02, 0.03), Vector3(0.0, 0.0, -0.06), Color(0.6, 0.55, 0.4))])
	# the third arm: from under the bow, a child's small hand, palm up
	_anchor = Node3D.new()
	_anchor.name = "ThirdRoot"
	_anchor.position = Vector3(0, 0.08, -0.15)
	bone_attachment("Chest").add_child(_anchor)
	third = HomageArm.new()
	third.name = "ThirdHand"
	add_child(third)
	third.setup(self, _anchor, &"palm", SKIN, SKIN.lightened(0.08), 0.03, 0.05, VIOLET)
	_hitboxes.append(third.hitbox)
	_drip = OmniLight3D.new()
	_drip.light_color = VIOLET
	_drip.omni_range = 3.0
	_drip.light_energy = 0.0
	_drip.shadow_enabled = false
	third.hand_mi.add_child(_drip)
	# T-232: Nachtglas motes rise off the Third Hand whenever it opens for someone
	_motes = BossFx.emitter("motes", third.hand_mi, Vector3.ZERO, 0.6)
	_doll_pass()


## T-232: the doll register on top of the modelled body: the glaze, the glass eyes that never blink, the ribbon's
## tails, the crack tiers.
func _doll_pass() -> void:
	var glaze: StandardMaterial3D = StandardMaterial3D.new()
	glaze.albedo_color = Color(0.92, 0.9, 0.9, 0.16)
	glaze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glaze.roughness = 0.05
	glaze.metallic = 0.15
	glaze.metallic_specular = 0.9
	var head: Node3D = bone_attachment("Head")
	if head != null:
		var sp: SphereMesh = SphereMesh.new()
		sp.radius = 0.132
		sp.height = 0.264
		sp.material = glaze
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = sp
		mi.position = Vector3(0, 0.1, -0.005)
		mi.scale = Vector3(0.98, 1.06, 1.02)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		head.add_child(mi)
	_eyes = eye_glow(GLASS_EYE, 0.6, 0.0)   # she never blinks
	# the red ribbon's two tails from the bow, swinging as she walks (the bow and the dress stay intact)
	strips("Chest", Vector3(0, 0.06, -0.175), 2, 0.2, 0.035, RIBBON, 0.07, 121)
	var tiers: Array = ecfg.get("crack_tiers", [0.75, 0.5, 0.25]) as Array
	for i: int in tiers.size():
		var set_i: Array = []
		var emit: float = 0.9 + 0.6 * float(i)
		var c1: MeshInstance3D = cracks("Head", 4 + 3 * i, 0.128, 0.0, 0.2, CRACK, emit, 131 + i)
		if c1 != null:
			set_i.append(c1)
		for side: String in ["Left", "Right"]:
			var c2: MeshInstance3D = cracks(side + "UpperArm", 2 + 2 * i, 0.066, -0.28, -0.02, CRACK, emit, 141 + i + (7 if side == "Left" else 0))
			if c2 != null:
				set_i.append(c2)
			var c3: MeshInstance3D = cracks(side + "LowerArm", 2 + i, 0.058, -0.25, -0.02, CRACK, emit, 151 + i + (7 if side == "Left" else 0))
			if c3 != null:
				set_i.append(c3)
		for mi2: MeshInstance3D in set_i:
			mi2.visible = false
		_crack_tiers.append(set_i)
