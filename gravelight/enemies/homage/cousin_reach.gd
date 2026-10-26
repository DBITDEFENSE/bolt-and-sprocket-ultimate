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

const HAIR: Color = Color(0.32, 0.2, 0.12)
const FLANNEL: Color = Color(0.8, 0.76, 0.7)
const KNIT: Color = Color(0.5, 0.42, 0.33)
const SKIN: Color = Color(0.78, 0.76, 0.78)
const VIOLET: Color = Color(0.7, 0.35, 1.0)

var arms: Array[HomageArm] = []
var grabs_landed: int = 0
var crushes: int = 0
var wall_hits: int = 0
var _arm_state: Array[String] = ["", ""]     # per arm: "" / "shoot" / "hold" / "retract"
var _arm_target: Array = [null, null]        # Player per arm
var _arm_grab: Array = [{}, {}]              # the grab Dictionary per arm
var _crush_t: Array[float] = [0.0, 0.0]
var _wall_at: Vector3 = Vector3.ZERO
var _wall_arm: HomageArm
var _dust: CPUParticles3D
var _wall_t: float = -1.0


func _init() -> void:
	boss_key = "reach"


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


# ---------------------------------------------------------------- brain

func _tick(delta: float) -> void:
	_tick_arms(delta)
	_tick_wall(delta)
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
	if d <= float(c["swipe"]["range"]) and dy < 1.4 and cd_ready("swipe") and los:
		_begin("swipe", float(c["swipe"]["telegraph"]))
	elif d >= float(c["grab"]["min_range"]) and d <= float(c["grab"]["range"]) and los and cd_ready("grab") and can_grab(target):
		_begin("grab", float(c["grab"]["telegraph"]))
	elif d >= float(c["wall"]["min_range"]) and d <= float(c["wall"]["max_range"]) and cd_ready("wall") and (not los or randf() < 0.012):
		_begin("wall", float(c["wall"]["telegraph"]))
	else:
		walk_to(target.global_position, delta)


var _tele_total: float = 0.5


func _begin(id: String, telegraph: float) -> void:
	_tele_total = tele_len(telegraph)
	_go(B.TELEGRAPH, id)
	match id:
		"swipe":
			attack_anim("swipe_double", _tele_total)
		"grab":
			pose_anim()
			# the arm coils back over her shoulder; the counting fingers stop; the wet stretching creak
			_pose.set_bone("RightUpperArm", Vector3(2.6, 0, -0.5), Vector3(0, 0, 0))
			if enrage_steps >= 1:
				_pose.set_bone("LeftUpperArm", Vector3(2.6, 0, 0.5))
			sfx("zombie_gib", -6.0, 0.55)
			sfx("board_break", -8.0, 1.4)
		"wall":
			stand(0.0)
			_wall_at = target.global_position
			_wall_t = 0.0
			_start_dust(_wall_at)
			sfx("board_break", 0.0, 0.5, _wall_at + Vector3.UP * 0.4)   # the boards creak at the spot
			if randf() < 0.5:
				say("RCH_WALL_01")


func _telegraph(delta: float) -> void:
	stand(delta, move_id != "wall")
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
			set_cd("wall", float(c["wall"]["cooldown"]))
			_wall_burst()
			_go(B.RECOVER)


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
	sfx("zombie_sprint", -2.0, 0.6)


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
						var need: Dictionary = {"mash": int(c["break_mash"]), "team": float(c["break_team_damage"]),
							"weak": max_hp * float(c["break_wrist_fraction"]), "max": float(c["max_hold"])}
						var g: Dictionary = grab_start(p, "reach", need, [&"wrist", &"arms"])
						g["arm"] = i
						g["lock"] = float(c["regrab_lock"])
						_arm_grab[i] = g
						_arm_state[i] = "hold"
						_crush_t[i] = 0.0
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
	return _arm_state[0] == "" and _arm_state[1] == ""


func _on_grab_released(g: Dictionary, _reason: String) -> void:
	var i: int = int(g.get("arm", -1))
	if i >= 0 and i < 2 and _arm_state[i] == "hold":
		_arm_state[i] = "retract"
		sfx("zombie_gib", -8.0, 0.7)


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
	sfx("board_break", 4.0, 0.8, _wall_at + Vector3.UP * 0.5)
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


func _tele_glow() -> float:
	return 3.0 if bstate == B.TELEGRAPH and move_id == "grab" else 0.0


func _on_retreat() -> void:
	for i: int in 2:
		if _arm_state[i] != "":
			_arm_state[i] = "retract"
	if _dust != null:
		_dust.emitting = false


func _hum_pitch() -> float:
	return 1.12


func _start_authored_death() -> void:
	for i: int in 2:
		arms[i].hide()
		arms[i].set_reach_on(false)
		_arm_state[i] = ""
	if _wall_arm != null:
		_wall_arm.hide()
	if _dust != null:
		_dust.emitting = false
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
