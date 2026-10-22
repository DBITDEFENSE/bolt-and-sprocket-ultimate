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

const HAIR: Color = Color(0.1, 0.08, 0.08)
const NAVY: Color = Color(0.13, 0.15, 0.26)
const WHITE: Color = Color(0.88, 0.86, 0.82)
const RIBBON: Color = Color(0.74, 0.07, 0.1)
const STOCKING: Color = Color(0.09, 0.08, 0.09)
const SKIN: Color = Color(0.82, 0.8, 0.82)
const VIOLET: Color = Color(0.7, 0.35, 1.0)

var third: HomageArm
var freeze: ObservedFreeze = ObservedFreeze.new()
var frozen: bool = false
var frozen_frames: int = 0           # physics frames spent frozen (tests / the smoke)
var unseen_moves: float = 0.0        # metres moved while unobserved beyond 8 m
var holds_landed: int = 0
var lashes: int = 0
var lash_dodged: int = 0
var griefs: int = 0
var dripping: bool = false
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


func _init() -> void:
	boss_key = "alix"


func _on_spawned() -> void:
	freeze.include_bots = bool(ecfg.get("observers_include_bots", true))
	frozen = false
	dripping = false
	_drip.light_energy = 0.0
	_grief_body = null
	_set_third_rest(true)
	third.show()
	third.set_reach_on(true)
	_look.primary_limit_angle = deg_to_rad(80.0)


# ---------------------------------------------------------------- brain

func _tick(delta: float) -> void:
	_update_third(delta)
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
			_tick_grief(delta)


## Rising from the trapdoor: a small hand first, then she rises perfectly upright, as if lifted.
func _tick_emerge(delta: float) -> void:
	_halt(delta)
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
	if dy < 1.4 and d <= float(c["hold"]["range"]) and cd_ready("hold") and can_grab(target) and _clear_to(target):
		_begin("hold", float(c["hold"]["telegraph"]))
	elif dy < 1.4 and d <= float(c["swipe"]["range"]) and cd_ready("swipe") and _clear_to(target):
		_begin("swipe", float(c["swipe"]["telegraph"]))
	elif dy < 1.6 and d <= float(c["lash"]["range"]) and cd_ready("lash") and has_los(target):
		_begin("lash", float(c["lash"]["telegraph"]))
	else:
		walk_to(target.global_position, delta)


var _tele_total: float = 0.5


func _begin(id: String, telegraph: float) -> void:
	_tele_total = tele_len(telegraph)
	_go(B.TELEGRAPH, id)
	match id:
		"swipe":
			attack_anim("swipe_over", _tele_total)
			sfx("knife_swing", -14.0, 0.5)   # only the dress rustling
		"hold":
			pose_anim()
			_hum_mute = _tele_total + 0.6   # the hum drops out
		"lash":
			pose_anim()
			# her two normal hands rise slowly to her ears, as if she can't bear a sound
			_pose.set_bone("LeftUpperArm", Vector3(2.1, 0, 0.9))
			_pose.set_bone("RightUpperArm", Vector3(2.1, 0, -0.9))
			_pose.set_bone("LeftLowerArm", Vector3(1.6, 0, 0))
			_pose.set_bone("RightLowerArm", Vector3(1.6, 0, 0))
			sfx("screamer_hum", -6.0, 0.6)


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
			sfx("knife_swing", 0.0, 0.7)
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
	if bstate == B.SPECIAL and _grief_kneeling:
		_grief_dmg += amount
		if _grief_dmg >= max_hp * float(bcfg["grieve"]["break_fraction"]):
			_end_grief()


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
		return
	_halt(delta)
	third.tip = spot + Vector3.UP * 0.35
	if _bt >= float(bcfg["grieve"]["seconds"]):
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
		_drip.light_energy = 2.2
		say("ALX_ENRAGE_01")
	_go(B.MOVE)


func _on_enraged() -> void:
	pass   # her step comes with the grief window (on_cousin_fell); the speed step is already applied


func _tele_glow() -> float:
	return 2.5 if bstate == B.TELEGRAPH and move_id != "swipe" else 0.0


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


## Down into the trapdoor without bending.
func _tick_retreat(delta: float) -> void:
	_halt(delta)
	_pivot.position.y = lerpf(0.0, -1.9, clampf((_bt - 0.4) / 1.4, 0.0, 1.0))
	if _bt >= 2.0:
		_vanish()


func _start_authored_death() -> void:
	_tree_play("Death", "death_knee", 0.45)
	_pose.clear()
	_death_fist = 0.0
	say("ALX_DEATH_01")
	if dripping:
		_drip.light_energy = 0.6


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
