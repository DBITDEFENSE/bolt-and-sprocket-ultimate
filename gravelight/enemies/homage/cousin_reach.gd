class_name CousinReach
extends HomageBoss
## The Reach (Cousin 2, the youngest; docs/HOMAGE_BOSSES.md section 4.4). A brown bob with straight bangs, an
## ankle-length high-collared flannel nightgown under a buttoned cardigan, bare feet; arms that are too long even
## at rest (the forearm and hand bones sit lower on the chain: HomagePoseMod translation, the stretched skin filled
## between) and telescope out to 12 m when she reaches. She walks hunched, knuckles low.
## Moves:
##   - Swipe (0.5 s, 3 m, 45);
##   - Long Reach Grab (0.7 s: the arm coils back over her shoulder, the wet creak, the wrist glow brightens): the
##     forearm shoots out at 24 m/s up to 12 m; a player it reaches is held and dragged toward her at 2.5 m/s; if she
##     reels them in, the Hug-Crush (120 over 1.5 s). Break: shoot the glowing wrist (x2) for 8% of her max HP,
##     melee-mash 6 times, teammates' 250 damage, or 6 s. Nobody is re-grabbed for 4 s;
##   - Both Hands (enraged, after the first death): two grabs at the two nearest players (one player: dragged twice
##     as fast);
##   - Through-the-Wall (0.6 s: dust falls and the boards creak at the spot): an arm punches up through the floor
##     at the player's position from out of sight, a 1.5 m column, 60 + slowed x0.7 for 0.8 s.
## Death: both arms reach toward the nearest other cousin (alive or fallen), then drop. Drop: Fortify + 500 Scrip
## per player. Stubbed for later (HB1 notes): ceiling crawl, Window Spider, arm sever + regrowth.
## T-232 (the boss rework, docs/BOSS_REWORK.md 4.1, docs/boss_rework/w1_cousins.md): the doll register pushed. The
## porcelain glaze, glass eyes that blink too slowly (7 s), hairline cracks that spread with the damage (crack_tiers),
## dark red veins along the stretched arms (the `cracks` helper in red, widening when she enrages), the flannel
## sleeve torn only at the elbow (strips), frost on her breath in the cold taproom (a `frost` emitter with
## boss_breath every few seconds). The kit: a dread block (porcelain, soft footfalls), fx.tele on every telegraph,
## the pack on every move (boss_bone_crack on the stretch, the giggle stopped short when a grab lands, the hum gone
## flat once enraged, the floor's thud and dust on Through-the-Wall). Battle: Through-the-Window (cousins.json
## "window"): when the target stands near a boarded window of their zone and she has no line or is far off, the
## boards creak and rattle for 1.0 s under a violet glow at the window, then her arm punches through the boards from
## outside (one board torn), takes the player and drags them to the window for the Hug-Crush against the sill; the
## same breaks as the Long Reach (the wrist x2, the mash, teammates' damage, the time limit). The squad rule
## (cousins.json "lone"): a lone player (one on their feet) is held for less and dragged slower, so the solo break
## stays fair, while her walls come alive sooner (the wall cooldown x0.7). As the last cousin standing she hunts in
## the dark with the wrists' glow the only light.

const HAIR: Color = Color(0.32, 0.2, 0.12)
const FLANNEL: Color = Color(0.8, 0.76, 0.7)
const KNIT: Color = Color(0.5, 0.42, 0.33)
const SKIN: Color = Color(0.78, 0.76, 0.78)
const VIOLET: Color = Color(0.7, 0.35, 1.0)
const CRACK: Color = Color(0.42, 0.2, 0.62)
const VEIN: Color = Color(0.46, 0.05, 0.09)
const GLASS_EYE: Color = Color(0.78, 0.84, 1.0)

var arms: Array[HomageArm] = []
var grabs_landed: int = 0
var crushes: int = 0
var wall_hits: int = 0
var window_grabs: int = 0            # Through-the-Window grabs that took a player
var window_boards_torn: int = 0
var crack_tier_now: int = 0
var doll_cracks: int = 0
var breaths: int = 0
var dark_hunt: bool = false
var _arm_state: Array[String] = ["", ""]     # per arm: "" / "shoot" / "hold" / "retract"
var _arm_target: Array = [null, null]        # Player per arm
var _arm_grab: Array = [{}, {}]              # the grab Dictionary per arm
var _crush_t: Array[float] = [0.0, 0.0]
var _wall_at: Vector3 = Vector3.ZERO
var _wall_arm: HomageArm
var _dust: CPUParticles3D
var _wall_t: float = -1.0
var _win: Barricade = null                   # the window the arm comes through
var _win_arm: HomageArm
var _win_state: String = ""                  # "" / "shoot" / "hold" / "retract"
var _win_target: Player = null
var _win_grab: Dictionary = {}
var _win_crush_t: float = 0.0
var _win_light: OmniLight3D = null
var _win_torn: bool = false
var _veins: Array[MeshInstance3D] = []
var _crack_tiers: Array = []
var _breath: GPUParticles3D = null
var _breath_t: float = 2.0
var _breath_on: float = 0.0
var _hum_loop: AudioStreamPlayer3D = null
var _eyes: Node3D = null
var _hand_glow: Array[OmniLight3D] = []


func _init() -> void:
	boss_key = "reach"


# ---------------------------------------------------------------- pure rules (unit-tested)

## A grab's break terms for the squad: the Long Reach's need dictionary (mash / team / weak / max), shortened and
## slowed for a lone player (`lone` = one player on their feet: nobody to shoot the wrist for them).
static func grab_need(c: Dictionary, max_hp_v: float, lone: bool, lone_cfg: Dictionary) -> Dictionary:
	var need: Dictionary = {"mash": int(c["break_mash"]), "team": float(c["break_team_damage"]),
		"weak": max_hp_v * float(c["break_wrist_fraction"]), "max": float(c["max_hold"])}
	if lone:
		need["max"] = float(need["max"]) * float(lone_cfg.get("hold_mult", 1.0))
	return need


## The drag speed for the squad: slower for a lone player.
static func drag_speed(base: float, lone: bool, lone_cfg: Dictionary) -> float:
	return base * (float(lone_cfg.get("drag_mult", 1.0)) if lone else 1.0)


## Through-the-Window applies when the target stands within `near_window` of a boarded window of their zone and she
## either has no line to them or is at least `min_dist` away (the surprise is telegraphed by the boards).
static func window_applies(dist_to_window: float, boards: int, los: bool, dist: float, c: Dictionary) -> bool:
	return boards >= 1 and dist_to_window <= float(c.get("near_window", 4.5)) and (not los or dist >= float(c.get("min_dist", 7.0)))


## One player on their feet (the lone-player rule).
func lone_player() -> bool:
	return alive_players().size() <= 1


func _on_spawned() -> void:
	var e: float = float(bcfg.get("arm_extra", 0.22))
	for side: String in ["Left", "Right"]:
		_pose.set_bone(side + "LowerArm", Vector3(0.12, 0, 0), Vector3(0, -e, 0))
		_pose.set_bone(side + "Hand", Vector3.ZERO, Vector3(0, -e * 0.5, 0))
	_pose.set_bone("Spine", Vector3(0.32, 0, 0))   # hunched
	_pose.set_bone("Neck", Vector3(-0.25, 0, 0))
	_pose.snap()
	for i: int in 2:
		arms[i].hide()
		arms[i].set_reach_on(false)
		_arm_state[i] = ""
	if _wall_arm != null:
		_wall_arm.hide()
	if _win_arm != null:
		_win_arm.hide()
	_win_state = ""
	dark_hunt = false
	crack_tier_now = 0
	_set_crack_tier(0)
	for v: MeshInstance3D in _veins:
		v.scale = Vector3.ONE


# ---------------------------------------------------------------- brain

func _tick(delta: float) -> void:
	_tick_arms(delta)
	_tick_wall(delta)
	_tick_window(delta)
	_tick_breath(delta)
	if fx != null and dark_hunt:
		fx.extra_dread = maxf(fx.extra_dread, 0.25)
	match bstate:
		B.ARRIVE:
			_tick_arrive(delta)
		B.MOVE:
			_think(delta)
		B.TELEGRAPH:
			_telegraph(delta)
		B.ACTIVE:
			# the arm(s) are out: she plants and reels
			stand(delta)
			if _arms_idle() and _bt > 0.2:
				_pose_rest_arms()
				_go(B.RECOVER)
		B.RECOVER:
			stand(delta)
			if _bt >= 0.4:
				_go(B.MOVE)


## The entrance: dropping from the hayloft (two points) or through a taproom window (outside, sill, inside).
var arrive_path: PackedVector3Array = PackedVector3Array()


func _tick_arrive(delta: float) -> void:
	if arrive_path.size() < 2:
		stand(delta)
		if _bt >= 0.4:
			_go(B.MOVE)
		return
	var secs: float = 0.6 if arrive_path.size() == 2 else 1.2
	var k: float = clampf(_bt / secs, 0.0, 1.0)
	var p: Vector3
	if arrive_path.size() == 2:
		p = arrive_path[0].lerp(arrive_path[1], k)
		p.y = lerpf(arrive_path[0].y, arrive_path[1].y, k * k)   # she drops
	else:
		var a: Vector3 = arrive_path[0].lerp(arrive_path[1], k)
		var b: Vector3 = arrive_path[1].lerp(arrive_path[2], k)
		p = a.lerp(b, k)
	collision_mask = 0
	global_position = p
	_face(arrive_path[arrive_path.size() - 1] + (arrive_path[arrive_path.size() - 1] - arrive_path[0]))
	if k >= 1.0:
		collision_mask = LAYER_WORLD | LAYER_PLAYER | LAYER_DOOR
		arrive_path = PackedVector3Array()
		_go(B.MOVE)


func _think(delta: float) -> void:
	if target == null:
		stand(delta, false)
		return
	var c: Dictionary = bcfg
	var d: float = dist_to(target)
	var dy: float = absf(target.global_position.y - global_position.y)
	var los: bool = has_los(target)
	var win: Barricade = _pick_window(target, los, d) if cd_ready("window") and _win_state == "" and can_grab(target) else null
	if d <= float(c["swipe"]["range"]) and dy < 1.4 and cd_ready("swipe") and los:
		_begin("swipe", float(c["swipe"]["telegraph"]))
	elif win != null:
		_win = win
		_begin("window", float(c["window"]["telegraph"]))
	elif d >= float(c["grab"]["min_range"]) and d <= float(c["grab"]["range"]) and los and cd_ready("grab") and can_grab(target):
		_begin("grab", float(c["grab"]["telegraph"]))
	elif d >= float(c["wall"]["min_range"]) and d <= float(c["wall"]["max_range"]) and cd_ready("wall") and (not los or randf() < 0.012):
		_begin("wall", float(c["wall"]["telegraph"]))
	else:
		walk_to(target.global_position, delta)


## The boarded window of the target's zone nearest to them that Through-the-Window applies to (null: none).
func _pick_window(p: Player, los: bool, d: float) -> Barricade:
	var c: Dictionary = bcfg.get("window", {})
	var zone: String = str(c.get("zone", ""))
	var best: Barricade = null
	var bd: float = INF
	for n: Node in get_tree().get_nodes_in_group(&"barricades"):
		var w: Barricade = n as Barricade
		if w == null or (zone != "" and String(w.zone_id) != zone):
			continue
		var dw: float = Vector2(w.inside_point().x - p.global_position.x, w.inside_point().z - p.global_position.z).length()
		if absf(w.global_position.y - p.global_position.y) > 1.5:
			continue
		if window_applies(dw, w.boards, los, d, c) and dw < bd:
			bd = dw
			best = w
	return best


var _tele_total: float = 0.5


func _begin(id: String, telegraph: float) -> void:
	_tele_total = tele_len(telegraph)
	_go(B.TELEGRAPH, id)
	match id:
		"swipe":
			attack_anim("swipe_double", _tele_total)
			fx.tele(VIOLET, 1.5, _tele_total, false)
		"grab":
			pose_anim()
			# the arm coils back over her shoulder; the counting fingers stop; the wet stretching creak
			_pose.set_bone("RightUpperArm", Vector3(2.6, 0, -0.5), Vector3(0, 0, 0))
			if enrage_steps >= 1:
				_pose.set_bone("LeftUpperArm", Vector3(2.6, 0, 0.5))
			sfx("boss_bone_crack", -4.0, 0.9)   # the joints giving as the arm coils
			fx.tele(VIOLET, 3.0, _tele_total)
		"wall":
			stand(0.0)
			_wall_at = target.global_position
			_wall_t = 0.0
			_start_dust(_wall_at)
			sfx("stable_creak", 2.0, 0.8, _wall_at + Vector3.UP * 0.4)   # the boards creak at the spot
			fx.tele(VIOLET, 2.0, _tele_total)
			if randf() < 0.5:
				say("RCH_WALL_01")
		"window":
			stand(0.0)
			_window_telegraph()


func _telegraph(delta: float) -> void:
	stand(delta, move_id != "wall" and move_id != "window")
	if move_id == "window" and _bt >= _tele_total * 0.5 and not _hit_done:
		_hit_done = true
		if _win != null and is_instance_valid(_win):
			sfx("stable_creak", 4.0, 0.7, _win.global_position + Vector3.UP * 1.4)   # the second creak, louder
	if _bt < _tele_total:
		return
	var c: Dictionary = bcfg
	match move_id:
		"swipe":
			set_cd("swipe", float(c["swipe"]["cooldown"]))
			if target != null and dist_to(target) <= float(c["swipe"]["range"]) + 0.5 and _clear_to(target):
				hit_player(target, float(c["swipe"]["damage"]))
			_go(B.RECOVER)
		"grab":
			_shoot_arms()
			_go(B.ACTIVE)
		"wall":
			var wc: float = float(c["wall"]["cooldown"])
			if lone_player():
				wc *= float((bcfg.get("lone", {}) as Dictionary).get("wall_cooldown_mult", 1.0))   # the walls come alive sooner
			set_cd("wall", wc)
			_wall_burst()
			_go(B.RECOVER)
		"window":
			set_cd("window", float(c["window"]["enraged_cooldown"]) if enrage_steps >= 1 else float(c["window"]["cooldown"]))
			_window_shoot()
			_go(B.ACTIVE)


# ---------------------------------------------------------------- Through-the-Window

## 1.0 s: the boards creak twice and rattle in their frame; a violet glow grows outside the glass.
func _window_telegraph() -> void:
	if _win == null or not is_instance_valid(_win):
		return
	var at: Vector3 = _win.global_position + Vector3.UP * 1.4
	sfx("stable_creak", 2.0, 0.85, at)
	AudioDirector.play_3d("boss_telegraph_rise", at, -4.0, 0.03)
	# the boards rattle: each visible board shivers in its frame, then settles home
	var nodes: Variant = _win.get("_board_nodes")
	var homes: Variant = _win.get("_board_home")
	if nodes is Array and homes is Array:
		for i: int in (nodes as Array).size():
			var mi: MeshInstance3D = (nodes as Array)[i] as MeshInstance3D
			if mi == null or not mi.visible or i >= (homes as Array).size():
				continue
			var home: Transform3D = (homes as Array)[i] as Transform3D
			var tw: Tween = mi.create_tween()
			for k: int in 4:
				tw.tween_property(mi, "transform", Transform3D(home.basis.rotated(Vector3.RIGHT, 0.04 * (1.0 if k % 2 == 0 else -1.0)), home.origin + Vector3(0, 0, 0.02 * (1.0 if k % 2 == 0 else -1.0))), _tele_total * 0.2)
			tw.tween_property(mi, "transform", home, _tele_total * 0.15)
	if _win_light == null or not is_instance_valid(_win_light):
		_win_light = OmniLight3D.new()
		_win_light.light_color = VIOLET
		_win_light.omni_range = 3.5
		_win_light.shadow_enabled = false
		_win_light.top_level = true
		add_child(_win_light)
	_win_light.light_energy = 0.0
	_win_light.global_position = _win.outside_point() + Vector3.UP * 1.4
	var lt: Tween = _win_light.create_tween()
	lt.tween_property(_win_light, "light_energy", 3.0, _tele_total * 0.6).set_trans(Tween.TRANS_QUAD)
	lt.tween_interval(_tele_total * 0.35)
	lt.tween_property(_win_light, "light_energy", 0.6, 0.2)


## The arm punches through the boards from outside (one board torn) and shoots for the target.
func _window_shoot() -> void:
	if _win == null or not is_instance_valid(_win) or target == null or not can_grab(target):
		_win_state = ""
		if _win_light != null:
			_win_light.light_energy = 0.0
		return
	var c: Dictionary = bcfg["window"]
	var out: Vector3 = _win.outside_point()
	out.y = _win.global_position.y + 1.3
	_win_arm.from_point = out
	_win_arm.tip = out
	_win_arm.show()
	_win_arm.set_reach_on(true)
	_win_arm.glow.light_energy = 2.0
	_win_arm.refresh()
	_win_target = target
	_win_state = "shoot"
	_win_torn = false
	for i: int in int(c.get("tear_boards", 1)):
		if _win.tear_board():   # the board's own breaking sound
			window_boards_torn += 1
			_win_torn = true
	BossFx.burst("chips", _win.global_position + Vector3.UP * 1.4, get_tree(), 1.4, 1.1)
	sfx("boss_bone_crack", 0.0, 1.1, _win.global_position + Vector3.UP * 1.3)
	if randf() < 0.5:
		say("RCH_GRAB_01")


func _tick_window(delta: float) -> void:
	if _win_state == "" or _win_arm == null:
		return
	var c: Dictionary = bcfg["window"]
	var gc: Dictionary = bcfg["grab"]
	var a: HomageArm = _win_arm
	match _win_state:
		"shoot":
			var p: Player = _win_target
			if p == null or not is_instance_valid(p) or not p.is_alive() or _win == null or not is_instance_valid(_win):
				_win_state = "retract"
				return
			var chest: Vector3 = p.global_position + Vector3.UP * 1.2
			a.tip = a.tip.move_toward(chest, float(c["speed"]) * delta)
			if a.tip.distance_to(chest) < 0.5:
				if can_grab(p):
					window_grabs += 1
					grabs_landed += 1
					var need: Dictionary = grab_need(gc, max_hp, lone_player(), bcfg.get("lone", {}) as Dictionary)
					var g: Dictionary = grab_start(p, "window", need, [&"wrist", &"arms"])
					g["arm"] = 2
					g["lock"] = float(gc["regrab_lock"])
					_win_grab = g
					_win_state = "hold"
					_win_crush_t = 0.0
					giggle_short()
				else:
					_win_state = "retract"
			elif a.length() > float(c.get("near_window", 4.5)) + 3.0:
				_win_state = "retract"
		"hold":
			var p2: Player = _win_grab.get("p", null) as Player
			if not _grabs.has(_win_grab) or p2 == null or not is_instance_valid(p2) or _win == null or not is_instance_valid(_win):
				_win_state = "retract"
				return
			a.tip = p2.global_position + Vector3.UP * 1.2
			var to: Vector3 = _win.inside_point()
			var spd: float = drag_speed(float(c["drag"]), lone_player(), bcfg.get("lone", {}) as Dictionary) * speed_mult()
			drag_player(p2, to, spd, delta, float(c["crush_range"]) * 0.8)
			var dw: float = Vector2(to.x - p2.global_position.x, to.z - p2.global_position.z).length()
			if dw <= float(c["crush_range"]):
				if _win_crush_t == 0.0:
					crushes += 1
					say("RCH_HUG_01")
				var before: float = _win_crush_t
				_win_crush_t += delta
				var per_s: float = float(gc["crush_damage"]) / float(gc["crush_seconds"])
				var ticks: int = int(floor(_win_crush_t / 0.25)) - int(floor(before / 0.25))
				if ticks > 0:
					hit_player(p2, per_s * 0.25 * float(ticks))
				if _win_crush_t >= float(gc["crush_seconds"]):
					grab_release(_win_grab, "crushed")
		"retract":
			a.set_reach_on(false)
			var home: Vector3 = a.from_point
			a.tip = a.tip.move_toward(home, 10.0 * delta)
			if a.tip.distance_to(home) < 0.2:
				a.hide()
				a.glow.light_energy = 0.0
				_win_state = ""
				if _win_light != null and is_instance_valid(_win_light):
					_win_light.light_energy = 0.0


## Long Reach / Both Hands: one arm per target (enraged: the two nearest grabbable players in reach).
func _shoot_arms() -> void:
	var c: Dictionary = bcfg["grab"]
	var targets: Array[Player] = []
	if target != null and can_grab(target):
		targets.append(target)
	if enrage_steps >= 1:
		var best: Player = null
		var bd: float = INF
		for p: Player in alive_players():
			if targets.has(p) or not can_grab(p) or dist_to(p) > float(c["range"]) or not has_los(p):
				continue
			if dist_to(p) < bd:
				bd = dist_to(p)
				best = p
		if best != null:
			targets.append(best)
	set_cd("grab", float(c["both_cooldown"]) if enrage_steps >= 1 else float(c["cooldown"]))
	for i: int in mini(2, targets.size()):
		var a: HomageArm = arms[1 - i]   # right arm first
		a.tip = a.start_point()
		a.show()
		a.set_reach_on(true)
		a.glow.light_energy = 2.0
		_arm_state[1 - i] = "shoot"
		_arm_target[1 - i] = targets[i]
	sfx("boss_bone_crack", 0.0, 1.15)   # the arm shoots: the segments cracking open one after another
	sfx("boss_breath", -6.0, 1.4)


## The doll's giggle, stopped short.
func giggle_short(db: float = -2.0) -> void:
	var p: AudioStreamPlayer3D = sfx("boss_doll_giggle", db, _hum_pitch())
	if p != null:
		get_tree().create_timer(randf_range(0.32, 0.5)).timeout.connect(func() -> void:
			if is_instance_valid(p) and p.playing:
				p.stop())


func _tick_arms(delta: float) -> void:
	var c: Dictionary = bcfg["grab"]
	for i: int in 2:
		var a: HomageArm = arms[i]
		match _arm_state[i]:
			"shoot":
				var p: Player = _arm_target[i] as Player
				if p == null or not is_instance_valid(p) or not p.is_alive():
					_arm_state[i] = "retract"
					continue
				var chest: Vector3 = p.global_position + Vector3.UP * 1.2
				a.tip = a.tip.move_toward(chest, float(c["speed"]) * delta)
				if a.tip.distance_to(chest) < 0.5:
					if can_grab(p):
						grabs_landed += 1
						var need: Dictionary = grab_need(c, max_hp, lone_player(), bcfg.get("lone", {}) as Dictionary)
						var g: Dictionary = grab_start(p, "reach", need, [&"wrist", &"arms"])
						g["arm"] = i
						g["lock"] = float(c["regrab_lock"])
						_arm_grab[i] = g
						_arm_state[i] = "hold"
						_crush_t[i] = 0.0
						giggle_short()
						say("RCH_GRAB_01" if randf() < 0.6 else "RCH_REEL_01")
					else:
						_arm_state[i] = "retract"
				elif a.length() > float(c["range"]) + 0.5:
					_arm_state[i] = "retract"
			"hold":
				var g2: Dictionary = _arm_grab[i]
				var p2: Player = g2.get("p", null) as Player
				if not _grabs.has(g2) or p2 == null or not is_instance_valid(p2):
					_arm_state[i] = "retract"
					continue
				a.tip = p2.global_position + Vector3.UP * 1.2
				var both: bool = _arm_state[0] == "hold" and _arm_state[1] == "hold"
				var drag: float = float(c["drag"]) if (both or enrage_steps < 1) else float(c["enraged_drag"])
				drag = drag_speed(drag, lone_player(), bcfg.get("lone", {}) as Dictionary)
				drag_player(p2, global_position, drag * speed_mult(), delta, float(c["crush_range"]) * 0.8)
				if dist_to(p2) <= float(c["crush_range"]):
					# reeled in: the Hug-Crush
					if _crush_t[i] == 0.0:
						crushes += 1
						say("RCH_HUG_01")
					var before: float = _crush_t[i]
					_crush_t[i] += delta
					var per_s: float = float(c["crush_damage"]) / float(c["crush_seconds"])
					var ticks: int = int(floor(_crush_t[i] / 0.25)) - int(floor(before / 0.25))
					if ticks > 0:
						hit_player(p2, per_s * 0.25 * float(ticks))
					if _crush_t[i] >= float(c["crush_seconds"]):
						grab_release(g2, "crushed")
			"retract":
				a.set_reach_on(false)
				var home: Vector3 = a.start_point()
				a.tip = a.tip.move_toward(home, 10.0 * delta)
				if a.tip.distance_to(home) < 0.2:
					a.hide()
					a.glow.light_energy = 0.0
					_arm_state[i] = ""


func _arms_idle() -> bool:
	return _arm_state[0] == "" and _arm_state[1] == "" and _win_state == ""


func _on_grab_released(g: Dictionary, _reason: String) -> void:
	var i: int = int(g.get("arm", -1))
	if i >= 0 and i < 2 and _arm_state[i] == "hold":
		_arm_state[i] = "retract"
		sfx("boss_bone_crack", -8.0, 0.75)   # the joints fold backward, segment by segment
	elif i == 2 and _win_state == "hold":
		_win_state = "retract"
		sfx("boss_bone_crack", -8.0, 0.75)


func _pose_rest_arms() -> void:
	_pose.set_bone("RightUpperArm", Vector3.ZERO)
	_pose.set_bone("LeftUpperArm", Vector3.ZERO)


func _start_dust(at: Vector3) -> void:
	if _dust == null:
		_dust = CPUParticles3D.new()
		_dust.one_shot = false
		_dust.amount = 40
		_dust.lifetime = 0.7
		_dust.direction = Vector3.DOWN
		_dust.spread = 25.0
		_dust.gravity = Vector3(0, -6.0, 0)
		_dust.initial_velocity_min = 0.5
		_dust.initial_velocity_max = 1.5
		_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		_dust.emission_sphere_radius = 0.6
		var m: BoxMesh = BoxMesh.new()
		m.size = Vector3(0.03, 0.03, 0.03)
		m.material = HomageBoss.mat(Color(0.55, 0.5, 0.42))
		_dust.mesh = m
		_dust.top_level = true
		add_child(_dust)
	_dust.global_position = at + Vector3.UP * 2.6
	_dust.emitting = true


## Through-the-Wall: the arm bursts up through the boards where the player stood when the dust began.
func _wall_burst() -> void:
	var c: Dictionary = bcfg["wall"]
	if _dust != null:
		_dust.emitting = false
	_wall_arm.from_point = _wall_at + Vector3.DOWN * 0.4
	_wall_arm.tip = _wall_at + Vector3.UP * 1.7
	_wall_arm.show()
	_wall_arm.refresh()
	_wall_t = 0.0
	sfx("boss_stomp", 2.0, 0.9, _wall_at + Vector3.UP * 0.3)          # the boards burst upward
	sfx("boss_bone_crack", 0.0, 1.0, _wall_at + Vector3.UP * 0.8)
	BossFx.burst("dust", _wall_at + Vector3.UP * 0.3, get_tree(), 1.6, 1.3)
	BossFx.burst("chips", _wall_at + Vector3.UP * 0.4, get_tree(), 1.2, 1.0)
	fx.shake_all(_wall_at, 0.25, 7.0)
	for p: Player in alive_players():
		var d: Vector3 = p.global_position - _wall_at
		if Vector2(d.x, d.z).length() <= float(c["radius"]) and absf(d.y) < 1.5:
			wall_hits += 1
			hit_player(p, float(c["damage"]))
			p.apply_status(StringName(str((ecfg.get("status", {}) as Dictionary).get("reach_slow", "reach_slow"))), float(c["slow_seconds"]))


func _tick_wall(delta: float) -> void:
	if _wall_arm == null or not _wall_arm.visible:
		return
	_wall_t += delta
	if _wall_t > 0.6:
		_wall_arm.tip = _wall_arm.tip.move_toward(_wall_arm.from_point, delta * 6.0)
		if _wall_t > 1.0:
			_wall_arm.hide()


func _on_enraged() -> void:
	say("RCH_ENRAGE_01")
	# the veins stand out as she enrages; the lamps near her gutter; something in her splits
	var k: float = float((bcfg.get("veins", {}) as Dictionary).get("enrage_scale", 1.5))
	for v: MeshInstance3D in _veins:
		if is_instance_valid(v):
			v.scale = Vector3(k, 1.0, k)
	_flicker_room(1.4, 0.8)
	sfx("boss_doll_crack", -4.0, 1.15)


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
	sfx("boss_bone_crack", -2.0, 0.8)


## fx.tele owns the telegraph light.
func _tele_glow() -> float:
	return _tele_light.light_energy


## The hum: the shared lullaby, then (enraged) the lullaby hummed flat as a loop.
func _update_audio(delta: float) -> void:
	if enrage_steps >= 1 and is_active():
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


## Her breath frosts in the cold taproom: a puff every few seconds with boss_breath.
func _tick_breath(delta: float) -> void:
	if _breath == null:
		return
	if _breath_on > 0.0:
		_breath_on -= delta
		if _breath_on <= 0.0:
			_breath.emitting = false
		return
	_breath_t -= delta
	if _breath_t <= 0.0:
		_breath_t = randf_range(3.0, 5.5)
		_breath_on = 0.6
		_breath.emitting = true
		breaths += 1
		sfx("boss_breath", -12.0, 1.1)


func _on_damaged(amount: float, limb: StringName, by: int, kind: StringName) -> void:
	super._on_damaged(amount, limb, by, kind)
	var tier: int = CousinHammer.crack_tier(hp_fraction(), ecfg.get("crack_tiers", [0.75, 0.5, 0.25]) as Array)
	if tier > crack_tier_now:
		_set_crack_tier(tier)
		doll_cracks += 1
		if is_inside_tree() and fx != null:
			sfx("boss_doll_crack", 0.0, 1.05 + 0.08 * float(tier))
			BossFx.burst("chips", fx.limb_pos(limb), get_tree(), 1.2, 1.0)


func _set_crack_tier(tier: int) -> void:
	crack_tier_now = tier
	for i: int in _crack_tiers.size():
		for mi: MeshInstance3D in _crack_tiers[i]:
			if is_instance_valid(mi):
				mi.visible = i < tier


## The last cousin standing: the lamps are out again; the glow at her wrists is the only light.
func set_dark_hunt(on: bool) -> void:
	dark_hunt = on
	for l: OmniLight3D in _hand_glow:
		if is_instance_valid(l):
			l.light_energy = 0.7 if on else 0.0


func _on_retreat() -> void:
	for i: int in 2:
		if _arm_state[i] != "":
			_arm_state[i] = "retract"
	if _win_state != "":
		_win_state = "retract"
	if _dust != null:
		_dust.emitting = false
	_stop_hum()


func _hum_pitch() -> float:
	return 1.12


func _start_authored_death() -> void:
	_stop_hum()
	for i: int in 2:
		arms[i].hide()
		arms[i].set_reach_on(false)
		_arm_state[i] = ""
	if _wall_arm != null:
		_wall_arm.hide()
	if _win_arm != null:
		_win_arm.hide()
		_win_arm.set_reach_on(false)
	_win_state = ""
	if _win_light != null and is_instance_valid(_win_light):
		_win_light.light_energy = 0.0
	if _dust != null:
		_dust.emitting = false
	if _breath != null:
		_breath.emitting = false
	_set_crack_tier(_crack_tiers.size())
	sfx("boss_doll_crack", 2.0, 1.0)
	# both arms reach for the other cousins, wherever they are (or fell)
	var other: Node3D = event.call("nearest_other_cousin", self) as Node3D if event != null and event.has_method("nearest_other_cousin") else null
	if other != null:
		_face_now(other.global_position)
	_arms_dropped = false
	_tree_play("Death", "death_knee", 0.6)
	_pose.set_bone("LeftUpperArm", Vector3(1.5, 0, 0.1))
	_pose.set_bone("RightUpperArm", Vector3(1.5, 0, -0.1))
	say("RCH_DEATH_01")
	# her drop: Fortify + 500 Scrip per player
	var drop: String = str(bcfg.get("drop", ""))
	if drop != "":
		PowerupManager.spawn(StringName(drop), global_position + global_basis.z * -1.0)
	var extra: int = int(bcfg.get("drop_scrip_per_player", 0))
	for pid: int in GameState.player_ids:
		Economy.grant(pid, extra)


func _face_now(p: Vector3) -> void:
	var d: Vector3 = p - global_position
	d.y = 0.0
	if d.length_squared() > 0.001:
		rotation.y = atan2(-d.x, -d.z)


## After 2 s the arms drop.
func _death_tick(_delta: float) -> void:
	if _death_t > 2.2 and not _arms_dropped:
		_arms_dropped = true
		_pose.set_bone("LeftUpperArm", Vector3(0.15, 0, 0.05))
		_pose.set_bone("RightUpperArm", Vector3(0.15, 0, -0.05))
		_pose.set_bone("Spine", Vector3(0.6, 0, 0))


var _arms_dropped: bool = false


func _hold_after() -> float:
	return 3.4


func _build_costume() -> void:
	# T-092: the modelled doll carries her hair, nightgown and cardigan (the sleeves end torn at the elbow); the
	# primitives stay for the legacy bodies. The stretched-arm fillers below are kept either way.
	if not modelled():
		# the bob with straight bangs (never over the face)
		costume("Head", [
			sph(0.138, Vector3(0, 0.105, 0.012), HAIR, Vector3(1.03, 0.98, 1.05), true),
			boxp(Vector3(0.27, 0.17, 0.05), Vector3(0, 0.045, 0.1), HAIR),
			boxp(Vector3(0.045, 0.16, 0.2), Vector3(0.122, 0.05, 0.0), HAIR),
			boxp(Vector3(0.045, 0.16, 0.2), Vector3(-0.122, 0.05, 0.0), HAIR),
			boxp(Vector3(0.22, 0.045, 0.05), Vector3(0, 0.185, -0.105), HAIR, Vector3(-0.3, 0, 0))])
		# the high-collared flannel nightgown under a buttoned cardigan
		var top: Array = [
			cyl(0.2, 0.215, 0.36, Vector3(0, 0.15, 0.004), KNIT, Vector3.ZERO, Vector3(1.0, 1.0, 0.7)),
			cyl(0.07, 0.085, 0.08, Vector3(0, 0.31, 0), FLANNEL)]
		for k: int in 4:
			top.append(sph(0.012, Vector3(0, 0.25 - 0.075 * float(k), -0.152), FLANNEL.darkened(0.4)))
		costume("Chest", top)
		costume("Spine", [cyl(0.2, 0.21, 0.26, Vector3(0, 0.1, 0.004), KNIT, Vector3.ZERO, Vector3(1.05, 1.0, 0.78))])
		costume("Hips", [cyl(0.21, 0.35, 0.88, Vector3(0, -0.43, 0.0), FLANNEL, Vector3.ZERO, Vector3(1.06, 1.0, 0.94))])   # to the ankle
	var e: float = float(bcfg.get("arm_extra", 0.22))
	for side: String in ["Left", "Right"]:
		if modelled():
			costume(side + "UpperArm", [cyl(0.034, 0.032, e + 0.04, Vector3(0, -0.3 - e * 0.5, 0), SKIN)])   # the stretched arm below the torn elbow
			costume(side + "LowerArm", [cyl(0.032, 0.03, e * 0.5 + 0.03, Vector3(0, -0.29 - e * 0.25, 0), SKIN)])
			continue
		costume(side + "UpperArm", [cyl(0.062, 0.058, 0.3, Vector3(0, -0.14, 0), KNIT),
			cyl(0.042, 0.04, e + 0.04, Vector3(0, -0.3 - e * 0.5, 0), SKIN)])   # the stretched arm below the torn elbow
		costume(side + "LowerArm", [cyl(0.05, 0.045, 0.27, Vector3(0, -0.13, 0), SKIN),
			cyl(0.04, 0.038, e * 0.5 + 0.03, Vector3(0, -0.29 - e * 0.25, 0), SKIN)])
		costume(side + "Hand", [sph(0.05, Vector3(0, -0.06, 0), SKIN, Vector3(0.8, 1.3, 0.6))])
	# the telescoping forearms (shown while she reaches) and the through-the-floor arm
	for side: String in ["Left", "Right"]:
		var a: HomageArm = HomageArm.new()
		a.name = side + "Reach"
		add_child(a)
		a.setup(self, bone_attachment(side + "Hand"), &"wrist", SKIN, SKIN.lightened(0.1), 0.045, 0.07, VIOLET)
		a.hide()
		_hitboxes.append(a.hitbox)
		arms.append(a)
	_wall_arm = HomageArm.new()
	_wall_arm.name = "WallArm"
	add_child(_wall_arm)
	_wall_arm.setup(self, null, &"wrist", SKIN, SKIN, 0.07, 0.11, VIOLET)
	_wall_arm.follow_anchor = false
	_wall_arm.hide()
	# T-232: the arm that comes through a boarded window (its wrist is a weak point like the others)
	_win_arm = HomageArm.new()
	_win_arm.name = "WindowArm"
	add_child(_win_arm)
	_win_arm.setup(self, null, &"wrist", SKIN, SKIN.lightened(0.1), 0.045, 0.07, VIOLET)
	_win_arm.follow_anchor = false
	_win_arm.hide()
	_hitboxes.append(_win_arm.hitbox)
	_doll_pass(e)


## T-232: the doll register on top of the modelled body: the glaze, the glass eyes (a slow blink), the veins along
## the stretched arms, the torn sleeve ends at the elbow, the frost on her breath, the crack tiers.
func _doll_pass(e: float) -> void:
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
		mi.scale = Vector3(1.0, 1.06, 1.03)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		head.add_child(mi)
		_breath = BossFx.emitter("frost", head, Vector3(0, 0.03, -0.14), 0.5)
	_eyes = eye_glow(GLASS_EYE, 0.55, 7.0)
	var vc: int = int((bcfg.get("veins", {}) as Dictionary).get("count", 10))
	for side: String in ["Left", "Right"]:
		var s: int = 1 if side == "Left" else 2
		var hand: Node3D = bone_attachment(side + "Hand")
		if hand != null:
			var hl: OmniLight3D = OmniLight3D.new()   # the wrist glow for the dark hunt
			hl.light_color = VIOLET
			hl.omni_range = 2.2
			hl.light_energy = 0.0
			hl.shadow_enabled = false
			hl.position = Vector3(0, -e * 0.5, 0)
			hand.add_child(hl)
			_hand_glow.append(hl)
		# dark red veins down the stretched arm below the torn elbow (they widen when she enrages)
		var v: MeshInstance3D = cracks(side + "UpperArm", vc, 0.037, -0.32 - e, -0.3, VEIN, 0.5, 61 + s)
		if v != null:
			_veins.append(v)
		var v2: MeshInstance3D = cracks(side + "LowerArm", vc / 2, 0.035, -0.31 - e * 0.5, -0.27, VEIN, 0.5, 71 + s)
		if v2 != null:
			_veins.append(v2)
		# the sleeve, torn at the elbow only: short flannel strips hanging from the tear
		strips(side + "UpperArm", Vector3(0, -0.3, 0), 3, 0.07, 0.025, FLANNEL, 0.09, 81 + s)
	var tiers: Array = ecfg.get("crack_tiers", [0.75, 0.5, 0.25]) as Array
	for i: int in tiers.size():
		var set_i: Array = []
		var emit: float = 0.9 + 0.6 * float(i)
		var c1: MeshInstance3D = cracks("Head", 4 + 3 * i, 0.128, 0.0, 0.2, CRACK, emit, 91 + i)
		if c1 != null:
			set_i.append(c1)
		for side: String in ["Left", "Right"]:
			var c2: MeshInstance3D = cracks(side + "UpperArm", 2 + i, 0.062, -0.27, -0.02, CRACK, emit, 101 + i + (7 if side == "Left" else 0))
			if c2 != null:
				set_i.append(c2)
		for mi2: MeshInstance3D in set_i:
			mi2.visible = false
		_crack_tiers.append(set_i)
