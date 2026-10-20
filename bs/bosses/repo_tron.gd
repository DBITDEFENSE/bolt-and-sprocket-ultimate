class_name RepoTron
extends BossBase
## REPO-TRON — Scrapheap Junction boss, the Exit Yard compactor arena (BS_ENEMIES §4.1;
## makeRepoTron index.html:7039, updateRepoTron :7072-7194). 380 HP, 40 bolts, PAST DUE stamp core.
##
## Kit (original): holds mid-range (closes at 2.4 m/s beyond 7 m) and picks
##   PRESS SWIPE (<7.5 m, 0.62 s ring in front, 18 dmg frontal arc), MAGNET (>6 m, 0.75 s, 1.5 s tractor
##   pull of 26 m/s^2 that a dash breaks, crushed cars every 0.5 s: 14 dmg r2.2, 0.55 s rings) and
##   COMPACT (0.95 s r9 ring, a jumpable 16-dmg shockwave, +3% max HP to BREAK).
## Phase 1 FORECLOSURE (100-66%): the original kit.
## Phase 2 REPOSSESSION MODE (66-33%): faster; TREAD CHARGE (0.6 s lane, 14 m/s ram, 20 dmg);
##   Scrap Mutt adds (2 every 11 s, max 3); a magnet that pulls Bolt within 4 m REPOSSESSES his gun,
##   which hangs from the crane hook (60 HP weak point). Smash the hook: the gun returns, +30% BREAK threshold.
## Phase 3 COMPACTION (33-0%): side walls advance 1 m every 10 s (to a 14 m gap); faster swipe (0.5 s);
##   magnets chain into a compact; a charge into a wall stuns it 1.5 s (+40% BREAK threshold); hitting the
##   stamp in the 1.2 s after a compact pushes the walls back 2 m (+3% max HP BREAK).
##
## Arena API (the level calls it): setup_arena(center, half_size, depth) — the boss builds and drives the two
## side wall bodies itself (StaticBody3D, world layer) at center.x +/- half_size spanning +/- depth in z.
## Signals walls_moved(gap) so the level can crush car stacks; arena_bounds() -> AABB.

signal walls_moved(gap: float)
signal weapon_stolen(weapon_id: StringName)
signal weapon_returned(weapon_id: StringName)

var R: Dictionary = {}
var idle_t: float = 1.6
var force_next: StringName = &""      # tests/cutscenes: the next attack to pick
var attacks_done: Dictionary = {}     # kind -> count
var stolen_weapon: StringName = &""
var steals: int = 0
var hook: CraneHook
var adds: Array[Node3D] = []
var arena_set: bool = false
var arena_center: Vector3 = Vector3.ZERO
var wall_start: float = 15.0
var wall_half: float = 15.0
var wall_target: float = 15.0
var arena_depth: float = 15.0
var walls: Array[StaticBody3D] = []
var _add_t: float = 6.0
var _wall_t: float = 10.0
var _first_wall_done: bool = false
var _press_window: float = 0.0
var _pushed_in_window: bool = false
var _car_t: float = 0.0
var _charge_dir: Vector3 = Vector3.FORWARD
var _steal_hint_t: float = -1.0
var _chain_compact: bool = false
var _jaw_t: MeshInstance3D
var _jaw_b: MeshInstance3D
var _arm: Node3D
var _forearm: Node3D
var _magnet_mat: StandardMaterial3D
var _stamp_mat: StandardMaterial3D
var _eye_mat: StandardMaterial3D
var _stamp: MeshInstance3D


func _init() -> void:
	boss_id = &"repo_tron"
	id = &"repo_tron"


func _load_tables() -> void:
	super._load_tables()
	R = bdef


func ph(arr: Variant) -> float:
	if arr is Array:
		var a: Array = arr
		return float(a[clampi(phase - 1, 0, a.size() - 1)])
	return float(arr)


# ------------------------------------------------------------------ visual (greybox, makeRepoTron)

func _build_visual() -> void:
	var hull: StandardMaterial3D = EnemyFx.mat(Color("#8a5a30"))
	var steel: StandardMaterial3D = EnemyFx.mat(Color("#39404f"))
	flash_mats.append(hull)
	flash_mats.append(steel)
	var tread: StandardMaterial3D = EnemyFx.mat(Color("#232323"))
	for sx: float in [-2.1, 2.1]:
		EnemyFx.box(visual, Vector3(1.0, 1.4, 5.2), Vector3(sx, 0.7, 0), tread)
		for k: int in range(-2, 3):
			EnemyFx.cyl(visual, 0.55, 1.05, Vector3(sx, 0.7, k * 1.1), EnemyFx.mat(Color("#2c2018"))).rotation.z = PI / 2
	EnemyFx.box(visual, Vector3(3.6, 1.6, 4.4), Vector3(0, 1.9, 0), hull)
	EnemyFx.box(visual, Vector3(3.0, 1.4, 3.0), Vector3(0, 3.3, -0.4), steel)
	_eye_mat = EnemyFx.mat(Color("#ffd23e"), Color("#ffaa00"), 1.6)
	for sx: float in [-0.7, 0.7]:
		EnemyFx.box(visual, Vector3(0.5, 0.3, 0.1), Vector3(sx, 3.5, 1.15), _eye_mat)
	_jaw_t = EnemyFx.box(visual, Vector3(2.6, 0.5, 1.4), Vector3(0, 3.0, 2.2), steel)
	_jaw_b = EnemyFx.box(visual, Vector3(2.6, 0.5, 1.4), Vector3(0, 1.6, 2.2), steel)
	var tooth: StandardMaterial3D = EnemyFx.mat(Color("#9fb3c8"))
	for k: int in 4:
		EnemyFx.cyl(_jaw_t, 0.14, 0.4, Vector3(-0.9 + k * 0.6, -0.4, 0.3), tooth, 0.0).rotation.x = PI
		EnemyFx.cyl(_jaw_b, 0.14, 0.4, Vector3(-0.9 + k * 0.6, 0.4, 0.3), tooth, 0.0)
	_arm = Node3D.new()
	_arm.position = Vector3(2.2, 3.4, -0.6)
	visual.add_child(_arm)
	EnemyFx.box(_arm, Vector3(0.5, 2.8, 0.5), Vector3(0, 1.4, 0), hull)
	_forearm = Node3D.new()
	_forearm.position = Vector3(0, 2.8, 0)
	_arm.add_child(_forearm)
	EnemyFx.box(_forearm, Vector3(0.4, 0.4, 2.8), Vector3(0, 0, 1.4), hull)
	_magnet_mat = EnemyFx.mat(Color("#3ee6ff"), Color("#18a9cc"), 0.6)
	EnemyFx.cyl(_forearm, 0.7, 0.5, Vector3(0, -0.5, 2.8), _magnet_mat)
	_arm.rotation.x = -0.4
	_forearm.rotation.x = 0.9
	_stamp_mat = EnemyFx.mat(Color("#ff3b3b"), Color("#ff2222"), 2.0)
	_stamp = EnemyFx.box(visual, Vector3(1.2, 0.7, 0.14), Vector3(0, 2.2, 2.25), _stamp_mat)
	var lbl: Label3D = Label3D.new()
	lbl.text = "PAST DUE"
	lbl.font_size = 64
	lbl.pixel_size = 0.004
	lbl.modulate = Color.WHITE
	lbl.position = Vector3(0, 0, 0.09)
	_stamp.add_child(lbl)
	EnemyFx.cyl(visual, 0.18, 1.4, Vector3(-1.2, 4.4, -1.0), steel)
	EnemyFx.box(visual, Vector3(2.4, 0.3, 0.2), Vector3(0, 4.15, -0.4), EnemyFx.mat(Color("#ffd23e"), Color("#ffaa00"), 0.8))
	hook = CraneHook.new()
	hook.name = "CraneHook"
	hook.boss = self
	hook.position = Vector3(2.4, 2.6, 3.6)
	add_child(hook)
	hook.smashed.connect(_on_hook_smashed)


func _build_body() -> void:
	super._build_body()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(4.6, 2.6, 5.2)
	_shape.shape = bs
	_shape.position.y = 1.4


func get_center() -> Vector3:
	return global_position + Vector3(0, 2.2, 0)


func _boss_activate() -> void:
	idle_t = float(R.get("first_idle", 1.6))
	force_next = &""
	attacks_done.clear()
	stolen_weapon = &""
	steals = 0
	adds.clear()
	_add_t = float(R["adds"]["first"])
	_wall_t = float(R["walls"]["every"])
	_first_wall_done = false
	_press_window = 0.0
	_steal_hint_t = -1.0
	_chain_compact = false
	if hook != null:
		hook.disarm()


# ------------------------------------------------------------------ arena API

## Called by the level builder. center = arena floor centre; half_size = half the distance between the side
## walls (15 for the 30 m Exit Yard); depth = half the wall length along z.
func setup_arena(center: Vector3, half_size: float = 15.0, depth: float = 15.0) -> void:
	arena_set = true
	arena_center = center
	wall_start = half_size
	wall_half = half_size
	wall_target = half_size
	arena_depth = depth
	home = Vector3(center.x, home.y, center.z)
	if walls.is_empty():
		var W: Dictionary = R["walls"]
		for i: int in 2:
			var b: StaticBody3D = StaticBody3D.new()
			b.name = "CompactorWall%d" % i
			b.collision_layer = 1
			var cs: CollisionShape3D = CollisionShape3D.new()
			var sh: BoxShape3D = BoxShape3D.new()
			sh.size = Vector3(float(W["thickness"]), float(W["height"]), depth * 2.0)
			cs.shape = sh
			b.add_child(cs)
			var m: StandardMaterial3D = EnemyFx.mat(Color("#4a4f5a"))
			EnemyFx.box(b, sh.size, Vector3.ZERO, m)
			var inner: float = (0.5 if i == 0 else -0.5) * float(W["thickness"])
			EnemyFx.box(b, Vector3(0.05, 0.4, depth * 2.0), Vector3(inner, float(W["height"]) * 0.3, 0),
				EnemyFx.mat(Color("#ffd23e"), Color("#ffaa00"), 1.0))                     # hazard stripe
			walls.append(b)
			var p: Node = get_parent() if get_parent() != null else self
			if p.is_inside_tree():
				p.add_child(b)
			else:
				p.add_child.call_deferred(b)
	_place_walls()


func arena_bounds() -> AABB:
	return AABB(arena_center - Vector3(wall_half, 0, arena_depth), Vector3(wall_half * 2.0, float(R["walls"]["height"]), arena_depth * 2.0))


func wall_gap() -> float:
	return wall_half * 2.0


func _place_walls() -> void:
	var th: float = float(R["walls"]["thickness"])
	var hgt: float = float(R["walls"]["height"])
	for i: int in walls.size():
		var sgn: float = -1.0 if i == 0 else 1.0
		var pos: Vector3 = arena_center + Vector3(sgn * (wall_half + th * 0.5), hgt * 0.5, 0)
		if walls[i].is_inside_tree():
			walls[i].global_position = pos
		else:
			walls[i].position = pos


## Advance (positive) or push back (negative) each wall by `m` metres, within [min_gap/2, start].
func move_walls(m: float) -> void:
	var lo: float = float(R["walls"]["min_gap"]) * 0.5
	wall_target = clampf(wall_target - m, lo, wall_start)


func _update_walls(dt: float) -> void:
	if not arena_set:
		return
	var spd: float = float(R["walls"]["advance"]) / maxf(0.05, float(R["walls"]["move_time"]))
	if absf(wall_half - wall_target) > 0.001:
		wall_half = move_toward(wall_half, wall_target, spd * 2.0 * dt)
		_place_walls()
		walls_moved.emit(wall_gap())
	# keep Bolt and the adds inside the shrinking pit
	var lim: float = wall_half - 0.6
	for n: Node3D in [target] + adds:
		if n == null or not is_instance_valid(n):
			continue
		var dx: float = n.global_position.x - arena_center.x
		if absf(dx) > lim and absf(n.global_position.z - arena_center.z) < arena_depth:
			n.global_position.x = arena_center.x + signf(dx) * lim


func _hits_wall() -> bool:
	if not arena_set:
		return false
	return absf(global_position.x - arena_center.x) > wall_half - 2.4


func release_arena() -> void:
	wall_target = wall_start


# ------------------------------------------------------------------ AI

func _ai(dt: float) -> void:
	if not started:
		desired_vel = Vector3.ZERO
		_perceive(dt)
		if target_alive() and (dist_to_target() < aggro_radius or aggro):
			start_fight()
		return
	if not target_alive():
		desired_vel = Vector3.ZERO
		return
	_update_walls(dt)
	_update_adds(dt)
	_press_window -= dt
	if _steal_hint_t > 0.0:
		_steal_hint_t -= dt
		if _steal_hint_t <= 0.0 and stolen_weapon != &"":
			VOManager.play(str(R["lines"]["steal_hint"]))
	if phase >= 3 and arena_set:
		_wall_t -= dt
		if _wall_t <= 0.0:
			_wall_t = float(R["walls"]["every"])
			if wall_target > float(R["walls"]["min_gap"]) * 0.5:
				move_walls(float(R["walls"]["advance"]))
				if not _first_wall_done:
					_first_wall_done = true
					VOManager.play(str(R["lines"]["first_wall"]))
	_jaw_t.position.y = 3.0 + absf(sin(t * 3.0)) * 0.15
	_jaw_b.position.y = 1.6 - absf(sin(t * 3.0)) * 0.15
	match state:
		State.STAGGER:
			stun_t -= dt
			desired_vel = Vector3.ZERO
			visual.rotation.z = sin(t * 18.0) * 0.04
			if stun_t <= 0.0:
				visual.rotation.z = 0.0
				idle_t = maxf(idle_t, 0.8)
				_set_state(State.CHASE)
		State.TELEGRAPH:
			tele_t -= dt * attack_rate()
			desired_vel = Vector3.ZERO
			_tick_light()
			if attack_kind == &"magnet":
				_magnet_mat.emission_energy_multiplier = 3.0
			if attack_kind == &"swipe":
				face(target_pos() - global_position, dt, float(R["turn_busy"]))
			if tele_t <= 0.0:
				_end_telegraph_fx()
				_set_state(State.ATTACK)
				attacked.emit(attack_kind)
				attacks_done[attack_kind] = int(attacks_done.get(attack_kind, 0)) + 1
				_attack_start(attack_kind)
		State.ATTACK:
			_attack_tick(dt)
		_:
			if state != State.CHASE:
				_set_state(State.CHASE)
			_idle(dt)


func _idle(dt: float) -> void:
	var to: Vector3 = target_pos() - global_position
	to.y = 0.0
	face(to, dt, float(R["turn_idle"]))
	var d: float = to.length()
	if d > float(R["hold_distance"]) and can_move():
		desired_vel = to.normalized() * ph(R["move_speed"]) * move_mult()
	else:
		desired_vel = Vector3.ZERO
	idle_t -= dt
	if idle_t <= 0.0 and can_attack():
		_pick(d)


func _pick(d: float) -> void:
	var roll: float = randf()
	var kind: StringName = force_next
	force_next = &""
	if kind == &"":
		if d < float(R["swipe"]["range"]) and roll < float(R["swipe"]["roll"]):
			kind = &"swipe"
		elif d > float(R["magnet"]["min_range"]) and roll < ph(R["magnet"]["roll"]):
			kind = &"magnet"
		elif phase >= 2 and roll < float(R["charge"]["roll"]):
			kind = &"charge"
		else:
			kind = &"press"
	if kind == &"charge" and phase < 2:
		kind = &"press"
	_telegraph(kind)


func _telegraph(kind: StringName) -> void:
	var f: Vector3 = (target_pos() - global_position)
	f.y = 0.0
	f = f.normalized() if f.length_squared() > 0.001 else forward()
	match kind:
		&"swipe":
			_jaw_t.position.y = 3.6
			_jaw_b.position.y = 1.0
			begin_telegraph(&"swipe", ph(R["swipe"]["tele"]), float(R["swipe"]["ring_r"]), global_position + forward() * float(R["swipe"]["ring_offset"]))
			tele_light.light_color = Color("#ffd23e")
		&"magnet":
			_arm.rotation.x = -1.3
			_forearm.rotation.x = 0.2
			begin_telegraph(&"magnet", float(R["magnet"]["tele"]), 0.0)
			tele_light.light_color = Color("#3ee6ff")
			if randf() < float(R["magnet"]["bark_chance"]):
				var ml: Array = R["lines"]["magnet"]
				VOManager.play(str(ml[randi() % ml.size()]))
		&"charge":
			_charge_dir = f
			begin_telegraph(&"charge", float(R["charge"]["tele"]), 0.0)
			EnemyFx.lane(get_parent(), global_position, f, float(R["charge"]["lane_len"]), float(R["charge"]["lane_w"]), tele_dur, Color("#ff5d5d"))
			tele_light.light_color = Color("#ff5d5d")
		_:
			begin_telegraph(&"press", float(R["compact"]["tele"]), float(R["compact"]["ring_r"]), global_position)
			tele_light.light_color = Color("#ff8a2e")


func _attack_start(kind: StringName) -> void:
	match kind:
		&"swipe":
			_jaw_t.position.y = 2.5
			_jaw_b.position.y = 2.1
			var f: Vector3 = forward()
			var to: Vector3 = target_pos() - global_position
			to.y = 0.0
			if to.length() < float(R["swipe"]["range"]) and to.normalized().dot(f) > float(R["swipe"]["arc_dot"]):
				hurt_target(float(R["swipe"]["dmg"]), float(R["swipe"]["knock"]))
			EnemyFx.ring(get_parent(), global_position + f * 3.2, 3.5, 0.2, Color("#ffd23e"))
			_end_attack(ph(R["swipe"]["idle_after"]))
		&"magnet":
			_car_t = float(R["magnet"]["car_first"])
			EventBus.hint.emit(line_text(str(R["lines"]["magnet_hint"])), "repomag")
		&"charge":
			pass
		_:
			_do_compact()


func _attack_tick(dt: float) -> void:
	match attack_kind:
		&"magnet":
			_magnet_mat.emission_energy_multiplier = 3.0 + sin(t * 30.0)
			desired_vel = Vector3.ZERO
			if not target_dodging() and "motor" in target:
				var m: Object = target.get("motor")
				var pull: Vector3 = global_position - target_pos()
				pull.y = 0.0
				pull = pull.normalized()
				m.set("vel", (m.get("vel") as Vector3) + pull * float(R["magnet"]["pull_accel"]) * dt)
			_car_t -= dt
			if _car_t <= 0.0:
				_car_t = ph(R["magnet"]["car_every"])
				_drop_car()
			if phase >= 2 and stolen_weapon == &"" and flat_dist_to_target() < float(R["magnet"]["steal_radius"]):
				steal_weapon()
			if state_t >= float(R["magnet"]["pull_time"]):
				_arm.rotation.x = -0.4
				_forearm.rotation.x = 0.9
				_magnet_mat.emission_energy_multiplier = 0.6
				if phase >= 3:
					_set_state(State.CHASE)
					_telegraph(&"press")     # magnet chains into a compact
				else:
					_end_attack(float(R["magnet"]["idle_after"]))
		&"charge":
			desired_vel = _charge_dir * ph(R["charge"]["speed"])
			face(_charge_dir, dt, 6.0)
			if contact_cd <= 0.0 and target_alive() and flat_dist_to_target() < radius + 1.2:
				contact_cd = 1.2
				hurt_target(float(R["charge"]["dmg"]), float(R["charge"]["knock"]))
			var hit_wall: bool = _hits_wall() or (state_t > 0.1 and is_on_wall())
			if hit_wall or global_position.distance_to(home) > float(R["charge"]["home_leash"]):
				desired_vel = Vector3.ZERO
				if hit_wall and phase >= 3:
					wall_self_stun()
				else:
					_end_attack(1.4)
				return
			if state_t >= float(R["charge"]["time"]):
				desired_vel = Vector3.ZERO
				_end_attack(ph(R["charge"]["idle_after"]))
		_:
			_end_attack(1.0)


func _end_attack(idle: float) -> void:
	idle_t = idle
	desired_vel = Vector3.ZERO
	_set_state(State.CHASE)


func _do_compact() -> void:
	var C: Dictionary = R["compact"]
	EnemyShockwave.spawn(get_parent(), global_position, ph(C["wave_speed"]), float(C["wave_dmg"]), self)
	EnemyFx.ring(get_parent(), global_position, 12.0, 0.6, Color("#ff8a2e"))
	add_break(max_hp * float(C["break_frac_max_hp"]))
	_press_window = float(C["recovery_window"])
	_pushed_in_window = false
	EventBus.hint.emit(line_text(str(R["lines"]["press_hint"])), "repopress")
	if state == State.ATTACK:
		_end_attack(ph(C["idle_after"]))


func _drop_car() -> void:
	var M: Dictionary = R["magnet"]
	var tp: Vector3 = target_pos()
	var c: Vector3 = Vector3(tp.x + randf_range(-1.5, 1.5), tp.y, tp.z + randf_range(-1.5, 1.5))
	var h: float = float(M["car_height"])
	var g: float = float(M["car_gravity"])
	var fall: float = (-2.0 + sqrt(4.0 + 2.0 * g * h)) / g
	EnemyFx.ring(get_parent(), c, float(M["car_r"]), maxf(float(M["car_ring"]), fall), Color("#ff8a2e"))
	EnemyProjectile.fire(get_parent(), c + Vector3(0, h, 0), Vector3(0, -2, 0), float(M["car_dmg"]) * dmg_mult, Color("#b04a3a"), 0.5, 3.0,
		{"grav": g, "boom_r": float(M["car_r"]), "source": self, "scale": Vector3(1.8, 1.0, 1.2)})


func wall_self_stun() -> void:
	cancel_attack()
	stun_t = float(R["charge"]["wall_stun"])
	_set_state(State.STAGGER)
	add_break(break_threshold() * float(R["charge"]["wall_break_frac"]))
	telegraphed.emit(&"wall_stun", &"repo_clank", stun_t)


# ------------------------------------------------------------------ repossession

## The magnet connected in phase 2+: take Bolt's equipped gun and hang it on the hook.
func steal_weapon() -> void:
	if target == null or stolen_weapon != &"":
		return
	var w: Node = target.get_node_or_null("Weapons")
	var wid: StringName = &""
	if w != null and w.has_method("steal_current"):
		var r: Variant = w.call("steal_current")
		wid = StringName(str(r)) if r != null and str(r) != "" and str(r) != "false" else &"current"
	elif w != null and w.has_method("repossess") and "current" in w and StringName(str(w.get("current"))) != &"":
		wid = StringName(str(w.get("current")))
		w.call("repossess", wid)
	else:
		wid = &"__fire_blocked"
		target.set_meta(&"fire_blocked", true)        # no weapons node: firing is blocked by this flag
	stolen_weapon = wid
	steals += 1
	hook.arm(float(R["hook"]["hp"]))
	VOManager.play(str(R["lines"]["steal"]))
	if steals == 1:
		queue_line(str(R["lines"]["steal_first"]), 2.5)
	_steal_hint_t = float(R["hook"]["steal_bark_delay"])
	weapon_stolen.emit(wid)


func return_weapon() -> void:
	if stolen_weapon == &"":
		return
	var wid: StringName = stolen_weapon
	stolen_weapon = &""
	if target != null and is_instance_valid(target):
		var w: Node = target.get_node_or_null("Weapons")
		if w != null and w.has_method("return_stolen"):
			w.call("return_stolen")
		elif w != null and w.has_method("return_weapon") and wid != &"__fire_blocked":
			w.call("return_weapon", wid)
		if target.has_meta(&"fire_blocked"):
			target.remove_meta(&"fire_blocked")
	hook.disarm()
	weapon_returned.emit(wid)


func _on_hook_smashed() -> void:
	return_weapon()
	add_break(break_threshold() * float(R["hook"]["break_frac"]))


# ------------------------------------------------------------------ boss hooks

func weak_point_exposed() -> bool:
	return true


func _weak_point_pos() -> Vector3:
	return _stamp.global_position if _stamp != null else get_center()


func weak_radius() -> float:
	var wp: Dictionary = R["weak_point"]
	return float(wp["exposed_radius"]) if core_exposed() else float(wp["radius"])


## Most exposed after a compact slam, during a BREAK and during a wall self-stun.
func core_exposed() -> bool:
	return _press_window > 0.0 or state == State.STAGGER


## While exposed, a hit from Bolt standing in front of the stamp counts as a weak-point hit.
func _extra_crit(hit: Combat.Hit) -> bool:
	if not core_exposed() or hit.source == null or not (hit.source is Node3D):
		return false
	var to: Vector3 = (hit.source as Node3D).global_position - global_position
	to.y = 0.0
	return to.normalized().dot(forward()) > 0.6


func _boss_on_hurt(_hit: Combat.Hit, _amount: float, crit: bool) -> void:
	if crit and _press_window > 0.0 and phase >= 3 and arena_set and not _pushed_in_window:
		_pushed_in_window = true
		move_walls(-float(R["compact"]["push_back"]))
		add_break(max_hp * float(R["compact"]["push_break_frac_max_hp"]))
		VOManager.play(str(R["lines"]["walls_back"]))


func _on_phase(p: int) -> void:
	idle_t = 1.0
	if p == 2:
		_eye_mat.albedo_color = Color("#ff5d5d")
		_eye_mat.emission = Color("#ff2222")
		banner_lines(R["lines"]["phase2_banner"], 2.0)
		VOManager.play(str(R["lines"]["phase2"]))
		_add_t = minf(_add_t, 2.0)
	elif p == 3:
		banner_lines(R["lines"]["phase3_banner"], 2.0)
		VOManager.play(str(R["lines"]["phase3"]))
		_wall_t = float(R["walls"]["every"])


func _on_attack_cancelled() -> void:
	_arm.rotation.x = -0.4
	_forearm.rotation.x = 0.9
	_magnet_mat.emission_energy_multiplier = 0.6
	_jaw_t.position.y = 3.0
	_jaw_b.position.y = 1.6
	desired_vel = Vector3.ZERO
	idle_t = maxf(idle_t, 0.8)


func _update_adds(dt: float) -> void:
	if phase < 2:
		return
	var A: Dictionary = R["adds"]
	adds = adds.filter(func(a: Node3D) -> bool: return is_instance_valid(a) and a.is_inside_tree() and bool(a.call("is_alive")))
	_add_t -= dt
	if _add_t <= 0.0 and adds.size() < int(A["max_alive"]) and get_parent() != null:
		_add_t = float(A["every"])
		var n: int = mini(int(A["count"]), int(A["max_alive"]) - adds.size())
		for i: int in n:
			var sp: float = float(A["spread"])
			var p: Vector3 = global_position + Vector3(randf_range(-sp, sp), 0.3, randf_range(-sp, sp))
			var a: Node3D = EnemySpawner.spawn(StringName(str(A["id"])), p, get_parent(),
				{"is_add": true, "aggro": true, "leash": float(A["leash"])})
			if a != null:
				adds.append(a)
		VOManager.play(str(R["lines"]["adds"]))


func _boss_died(_hit: Combat.Hit) -> void:
	return_weapon()
	release_arena()
	wall_half = wall_start
	if arena_set:
		_place_walls()
		walls_moved.emit(wall_gap())


func _anim(_delta: float) -> void:
	if _stamp_mat != null:
		_stamp_mat.emission_energy_multiplier = (5.0 + sin(t * 25.0) * 2.0) if core_exposed() else (2.0 + sin(t * 6.0) * 0.8)

