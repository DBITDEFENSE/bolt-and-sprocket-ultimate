class_name TheAlgorithm
extends PatternBoss
## THE ALGORITHM — Nova Plaza boss, at the foot of the FineTree (BS_ENEMIES §4.4; makeAlgorithm
## index.html:6821, updateAlgorithm :6840-6880). 520 HP, 45 bolts (kept). A smiley-faced wall of 3 x 4 server
## racks; the weak point is the core between the racks. Trophy "Shadowbanned". It never moves.
##
## Phase 1 FOR YOU (100-66%):
##   VIOLATION ZONE (from the source): every 3.4 s a pink ring (r3.4) stamps under Bolt, shrinks over a 1.2 s
##   telegraph, then fires for 18 ("UNPAID FINE!"). RECOMMENDED FOR YOU: every 8 s a holo-card hangs over a
##   spawn pad for 1.0 s ("Because you killed a Meter Maid..."), then that pair spawns (Meter Maid + HOA
##   Enforcer), at most 3 adds.
## Phase 2 TRENDING (66-33%): the face goes red and every timer runs x0.62 (zones every 2 s, summons every 5 s,
##   adds cap 5). FINE RAIN: paper fines fall from the FineTree in 3 lanes (0.8 s lane glow, 10 dmg, fragile).
##   The walkways reverse every 6 s (a 0.8 s HOA chime first).
## Phase 3 VIRAL (33-0%): DOOMSCROLL: the plaza floor scrolls toward the wall at 3 m/s (the walkways stop);
##   platforms are the escape. ENGAGEMENT BAIT: homing LIKE orbs (9 dmg, homing 1.4, fragile; 0.6 s pre-glow).
##   MEGA-FINE: one huge zone (r7) with a 1.6 s telegraph; get up on a platform.
## OVERLOAD (BREAK feeders): a Cease & Desist hit on it adds 4% of max HP to the BREAK meter (a Class Action
##   adds 10%); RETURN TO SENDER: a mallet hit or throw on a falling fine bats it into the wall for 4%; a fine
##   shot down within 8 m of the wall adds 1%; a SERVED add that dies within 6 m of the wall "files a
##   complaint" for 2%. A BREAK plays as OVERLOAD: error text fills the screens and the smiley becomes a
##   spinning loading wheel for 3.2 s.
##
## ARENA CONTRACT (opts["arena"], built by Nova Plaza's FineTree plaza builder; all anchors optional):
##   Center     Node3D    the plaza centre the wall faces (else 14 m in front of the wall)
##   size       meta/property Vector2/Vector3: plaza x/z extent (else bosses.json arena_size 40 x 40)
##   SpawnPad*  Marker3D  recommendation pads (else 3 pads 8 m in front of the wall)
##   FineTree   Node3D    where Fine Rain falls from (else 8 m above, 6 m in front of the wall)
##   Platform*  Node3D    escape platforms (real geometry); Bolt more than 1.2 m above the plaza floor is
##                        "off the feed": Doomscroll doesn't push him and the Mega-Fine misses him
##   Walkways   group "nova_walkways" (Nova's reversing walkways): reverse() is called on each one every 6 s
##              in phase 2; set_stopped(true) in phase 3 (set_stopped(false) on defeat), when the methods exist
##   ServerWall Node3D    optional: the planet's own server wall. The boss then hides its racks and face and
##                        moves its core, OVERLOAD wheel and error text onto that wall's face; FaceEyes /
##                        FaceMouth (its children) turn red for TRENDING and hide during OVERLOAD
##   Lane_*     Marker3D  optional Fine Rain lanes (meta "half_length"); each runs along the arena's z axis
##   notice_delivered(slot, by)  optional arena signal: each delivered complaint notice is a Cease & Desist
##                        on the core (+4% max HP BREAK)
##   arena methods (used when present): reverse_walkways(seconds), set_doomscroll(on), smash_cover_near(p, r)
##                        (VIOLATION zones and the Mega-Fine smash the cover they land on). Without
##                        reverse_walkways, the boss reverses the "nova_walkways" inside the arena (all of
##                        them when it built its own arena).
## Without an arena it builds its own: 3 spawn pads, a FineTree marker and 2 platforms.

var overloads: int = 0
var fines_batted: int = 0
var fines_shot_near: int = 0
var complaints: int = 0
var walkway_reversals: int = 0
var doomscroll_on: bool = false
var doomscroll_pushed: float = 0.0
var _zone_t: float = 2.5
var _summon_t: float = 3.0
var _rain_t: float = 3.0
var _walk_t: float = 6.0
var _cd_bark_done: bool = false
var _feed_i: int = 0
var _card: Label3D
var _card_t: float = 0.0
var _card_pad: Vector3 = Vector3.ZERO
var _walk_pending: float = -1.0
var _orb_t: float = -1.0
var _face_mats: Array[StandardMaterial3D] = []
var _face_nodes: Array[Node3D] = []
var _core: MeshInstance3D
var _core_mat: StandardMaterial3D
var _wheel: MeshInstance3D
var _errors: Label3D
var _leds: Array[StandardMaterial3D] = []
var _arena_wall: Node3D = null
var notices: int = 0


func _init() -> void:
	boss_id = &"the_algorithm"
	id = &"the_algorithm"


# ------------------------------------------------------------------ visual (server wall)

func _build_visual() -> void:
	var rack: StandardMaterial3D = EnemyFx.mat(Color("#14203a"))
	flash_mats.append(rack)
	var led_cols: Array[Color] = [Color("#3ee6ff"), Color("#9dff5a"), Color("#ffd23e")]
	for cx: int in range(-1, 2):
		for cy: int in 4:
			EnemyFx.box(visual, Vector3(1.9, 1.55, 1.2), Vector3(cx * 2.1, 1.2 + cy * 1.7, 0), rack)
			for l: int in 3:
				var m: StandardMaterial3D = EnemyFx.mat(led_cols[(cx + cy + l + 3) % 3], led_cols[(cx + cy + l + 3) % 3], 1.4)
				_leds.append(m)
				EnemyFx.box(visual, Vector3(0.16, 0.5, 0.05), Vector3(cx * 2.1 - 0.6 + l * 0.6, 1.2 + cy * 1.7, 0.62), m)
	var fm: StandardMaterial3D = EnemyFx.mat(Color("#ffd23e"), Color("#ffaa00"), 1.6)
	_face_mats.append(fm)
	_face_nodes.append(EnemyFx.box(visual, Vector3(0.7, 0.9, 0.1), Vector3(-1.2, 5.4, 0.7), fm))
	_face_nodes.append(EnemyFx.box(visual, Vector3(0.7, 0.9, 0.1), Vector3(1.2, 5.4, 0.7), fm))
	for m: int in 7:
		var a: float = PI * (0.15 + m / 6.0 * 0.7)
		_face_nodes.append(EnemyFx.box(visual, Vector3(0.4, 0.4, 0.1), Vector3(cos(a) * -2.4, 4.4 - sin(a) * 1.3, 0.7), fm))
	_core_mat = EnemyFx.mat(Color("#ff4d9d"), Color("#ff2277"), 2.0)
	_core = EnemyFx.sphere(visual, 0.5, Vector3(0, 4.5, 0.9), _core_mat)                                     # the exposed weak node
	EnemyFx.cyl(visual, 0.06, 1.2, Vector3(0, 8.0, 0), EnemyFx.mat(Color("#39404f")))                        # antenna
	_wheel = EnemyFx.torus(visual, 0.9, 1.2, Vector3(0, 5.0, 0.8), EnemyFx.glow(Color("#3ee6ff"), 0.9))     # OVERLOAD loading wheel
	_wheel.rotation.x = PI / 2
	_wheel.visible = false
	_errors = Label3D.new()
	_errors.text = "ERR 0x451: CONTENT POLICY VIOLATES CONTENT POLICY\nERR 0x000: FEED NOT FOUND\nERR 0x404: ENGAGEMENT NOT FOUND"
	_errors.font_size = 40
	_errors.pixel_size = 0.006
	_errors.modulate = Color("#ff3b3b")
	_errors.position = Vector3(0, 2.6, 0.75)
	_errors.visible = false
	visual.add_child(_errors)


func _build_body() -> void:
	super._build_body()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(6.6, 7.4, 1.4)
	_shape.shape = bs
	_shape.position.y = 3.7


func get_center() -> Vector3:
	return global_position + Vector3(0, 4.0, 0)


func core_pos() -> Vector3:
	return _core.global_position


func _build_default_arena() -> Node3D:
	var a: Node3D = Node3D.new()
	var f: Vector3 = forward()
	var side: Vector3 = Vector3(-f.z, 0, f.x)
	for i: int in 3:
		PatternBoss.arena_marker(a, "SpawnPad%d" % i, f * 8.0 + side * ((i - 1) * 7.0) + Vector3(0, 0.3, 0))
	PatternBoss.arena_marker(a, "FineTree", f * 6.0 + Vector3(0, 8.0, 0))
	for i: int in 2:
		var sx: float = -1.0 if i == 0 else 1.0
		PatternBoss.arena_box(a, "Platform%d" % i, Vector3(4, 1.6, 4), f * 13.0 + side * sx * 9.0 + Vector3(0, 0.8, 0), Color("#9fb3c8"))
	if _needs_floor():
		PatternBoss.arena_box(a, "Floor", Vector3(60, 1, 60), f * 12.0 + Vector3(0, -0.5, 0), Color("#c8ccd8"))
	_attach_arena(a)
	return a


func _pattern_activate() -> void:
	gravity_on = true
	overloads = 0
	fines_batted = 0
	fines_shot_near = 0
	complaints = 0
	walkway_reversals = 0
	doomscroll_on = false
	doomscroll_pushed = 0.0
	_zone_t = float(R["zones"]["first"])
	_summon_t = float(R["summon"]["first"])
	_rain_t = float(R["rain"]["first"])
	_walk_t = float(R["walkways"]["every"])
	_cd_bark_done = false
	_feed_i = 0
	_card_t = 0.0
	_walk_pending = -1.0
	_orb_t = -1.0
	if arena_owned or anchor(&"Center") == null:
		arena_mid = global_position + forward() * float(R["center_ahead"])
	notices = 0
	if not arena_owned and arena_node != null:
		var to: Vector3 = arena_mid - global_position
		to.y = 0.0
		if to.length() > 0.1:
			rotation.y = atan2(to.x, to.z)                    # the wall faces the plaza
	_arena_wall = anchor(&"ServerWall") if not arena_owned else null
	if _arena_wall != null:
		_use_arena_wall()
	if not arena_owned and arena_node != null and arena_node.has_signal(&"notice_delivered") 			and not arena_node.is_connected(&"notice_delivered", _on_notice):
		arena_node.connect(&"notice_delivered", _on_notice)


## The planet built the wall: keep only the core, the OVERLOAD wheel and the error text, on its face.
func _use_arena_wall() -> void:
	for c: Node in visual.get_children():
		if c != _core and c != _wheel and c != _errors and c is Node3D:
			(c as Node3D).visible = false
	_face_nodes.clear()
	var face: Vector3 = _arena_wall.global_position + forward() * float(R["arena_wall"]["face_out"])
	var fy: float = plaza_floor_y()
	_core.global_position = Vector3(face.x, fy + float(R["arena_wall"]["core_h"]), face.z)
	_wheel.global_position = Vector3(face.x, fy + float(R["arena_wall"]["wheel_h"]), face.z)
	_errors.global_position = Vector3(face.x, fy + float(R["arena_wall"]["errors_h"]), face.z) + forward() * 0.1
	for nm: String in ["FaceEyes", "FaceMouth"]:
		var f: Node3D = _arena_wall.get_node_or_null(NodePath(nm)) as Node3D
		if f != null:
			_face_nodes.append(f)
			for mi: MeshInstance3D in _meshes_under(f):
				if mi.material_override is StandardMaterial3D:
					mi.material_override = (mi.material_override as StandardMaterial3D).duplicate()
					_face_mats.append(mi.material_override as StandardMaterial3D)


func _meshes_under(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n as MeshInstance3D)
	for c: Node in n.get_children():
		out.append_array(_meshes_under(c))
	return out


## A complaint notice went into one of the wall's intake slots: a Cease & Desist on the core.
func _on_notice(_slot: StringName, _by: Node) -> void:
	if defeated or not started:
		return
	notices += 1
	add_break(max_hp * float(R["overload"]["cd_frac"]))
	if not _cd_bark_done:
		_cd_bark_done = true
		VOManager.play(str(R["lines"]["first_cd"]))


## Timer multiplier: x0.62 while TRENDING (phase 2+, from the source).
func spd() -> float:
	return float(R["trending_mult"]) if phase >= 2 else 1.0


func plaza_floor_y() -> float:
	return EnemyFx.floor_y(self, arena_mid, global_position.y, 2.0, 10.0)


## Bolt standing on the plaza floor (not up on a platform).
func on_feed(p: Vector3) -> bool:
	return p.y - plaza_floor_y() < float(R["platform_clear"]) + 0.95


# ------------------------------------------------------------------ fight

func _fight_tick(dt: float) -> void:
	_zone_t -= dt
	if _zone_t <= 0.0:
		_zone_t = ph(R["zones"]["every"]) * spd()
		_violation_zone()
	_summon_t -= dt
	adds = adds.filter(func(a: Node3D) -> bool: return is_instance_valid(a) and a.is_inside_tree() and bool(a.call("is_alive")))
	if _summon_t <= 0.0 and adds.size() < int(ph(R["summon"]["cap"])) and _card_t <= 0.0:
		_summon_t = ph(R["summon"]["every"]) * spd()
		_recommend()
	if _card_t > 0.0:
		_card_t -= dt
		if _card_t <= 0.0:
			_summon_pair()
	if phase >= 2:
		_rain_t -= dt
		if _rain_t <= 0.0:
			_rain_t = float(R["rain"]["every"]) * spd()
			_fine_rain()
	if phase == 2:
		_walk_t -= dt
		if _walk_t <= 0.0:
			_walk_t = float(R["walkways"]["every"])
			_walk_pending = float(R["walkways"]["chime"])
			log_parallel(&"walkway_reverse", float(R["walkways"]["chime"]), &"hoa_chime")
	if _walk_pending > 0.0:
		_walk_pending -= dt
		if _walk_pending <= 0.0:
			walkway_reversals += 1
			if not arena_call(&"reverse_walkways", [float(R["walkways"]["every"])]):
				for w: Node in _my_walkways():
					if w.has_method("reverse"):
						w.call("reverse")
	if doomscroll_on:
		_doomscroll(dt)
	if _orb_t > 0.0:
		_orb_t -= dt


func _violation_zone() -> void:
	var Z: Dictionary = R["zones"]
	var at: Vector3 = target_pos()
	DelayedBlast.spawn(get_parent(), at, float(Z["r"]), float(Z["tele"]), float(Z["dmg"]) * out_mult(), Color("#ff4d9d"), self,
		{"shrink": true, "kind": &"violation_zone", "on_blast": func(hit: bool) -> void:
			arena_call(&"smash_cover_near", [at, float(Z["r"])])
			if hit:
				VOManager.play(str(R["lines"]["zone_hit"]))})
	log_parallel(&"violation_zone", float(Z["tele"]), &"zone_stamp")


func _pads() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p: Node3D in anchors("SpawnPad"):
		out.append(_gpos(p))
	if out.is_empty():
		var f: Vector3 = forward()
		var side: Vector3 = Vector3(-f.z, 0, f.x)
		for i: int in 3:
			out.append(global_position + f * 8.0 + side * ((i - 1) * 7.0) + Vector3(0, 0.3, 0))
	return out


func _recommend() -> void:
	var pads: Array[Vector3] = _pads()
	_card_pad = pads[randi() % pads.size()]
	_card_t = float(R["summon"]["card_time"])
	if _card == null or not is_instance_valid(_card):
		_card = Label3D.new()
		_card.font_size = 56
		_card.pixel_size = 0.006
		_card.modulate = Color("#3ee6ff")
		_card.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_card.outline_size = 10
		if get_parent() != null:
			get_parent().add_child(_card)
	var cards: Array = R["lines"]["cards"]
	_card.text = line_text(str(cards[randi() % cards.size()]))
	_card.visible = true
	_card.global_position = _card_pad + Vector3(0, 2.6, 0)
	EnemyFx.ring(get_parent(), _card_pad, 2.0, _card_t, Color("#3ee6ff"))
	log_parallel(&"recommend", _card_t, &"feed_ping")
	var feed: Array = R["lines"]["feed"]
	VOManager.play(str(feed[_feed_i % feed.size()]))
	_feed_i += 1


func _summon_pair() -> void:
	if _card != null and is_instance_valid(_card):
		_card.visible = false
	var kinds: Array = R["summon"]["ids"]
	var cap: int = int(ph(R["summon"]["cap"]))
	for i: int in kinds.size():
		if adds.size() >= cap:
			break
		var a: Node3D = spawn_add(StringName(str(kinds[i])), _card_pad + Vector3((i * 2 - 1) * 1.6, 0.2, 0), {"revealed": true})
		if a is EnemyBase and not (a as EnemyBase).died.is_connected(_on_add_died):
			(a as EnemyBase).died.connect(_on_add_died)
	VOManager.play(str(R["lines"]["summon"]))


func _on_add_died(e: EnemyBase) -> void:
	if defeated or not is_instance_valid(e):
		return
	if e.status.has(&"served") and e.global_position.distance_to(global_position) < float(R["overload"]["complaint_r"]):
		complaints += 1
		add_break(max_hp * float(R["overload"]["complaint_frac"]))


func _fine_tree() -> Vector3:
	var ft: Node3D = anchor(&"FineTree")
	return _gpos(ft) if ft != null else global_position + forward() * 6.0 + Vector3(0, 8.0, 0)


func _fine_rain() -> void:
	var F: Dictionary = R["rain"]
	var src: Vector3 = _fine_tree()
	var to: Vector3 = target_pos() - src
	to.y = 0.0
	var f: Vector3 = to.normalized() if to.length_squared() > 0.01 else forward()
	var side: Vector3 = Vector3(-f.z, 0, f.x)
	var lanes: Array[Vector3] = []
	var lane_len: float = float(F["lane_len"])
	var marks: Array[Node3D] = anchors("Lane_")
	if not marks.is_empty():
		f = arena_node.global_basis.z.normalized()
		for m: Node3D in marks:
			var half: float = float(m.get_meta(&"half_length", lane_len * 0.5))
			lane_len = half * 2.0
			var start2: Vector3 = _gpos(m) - f * half
			lanes.append(start2)
			EnemyFx.lane(get_parent(), start2, f, lane_len, float(m.get_meta(&"width", F["lane_w"])), float(F["tele"]), Color("#f2f6ff"))
	else:
		for i: int in int(F["lanes"]):
			var off: float = (i - (int(F["lanes"]) - 1) * 0.5) * float(F["lane_gap"])
			var start: Vector3 = Vector3(src.x, target_pos().y, src.z) + side * off
			lanes.append(start)
			EnemyFx.lane(get_parent(), start, f, lane_len, float(F["lane_w"]), float(F["tele"]), Color("#f2f6ff"))
	log_parallel(&"fine_rain", float(F["tele"]), &"paper_flutter")
	VOManager.play(str(R["lines"]["rain"]))
	get_tree().create_timer(float(F["tele"]), false, true).timeout.connect(func() -> void:
		if not is_alive():
			return
		for st: Vector3 in lanes:
			for k: int in int(F["per_lane"]):
				var at: Vector3 = st + f * (lane_len * (k + 0.5) / float(F["per_lane"]))
				_drop_fine(at + Vector3(0, float(F["height"]), 0)))


func _drop_fine(at: Vector3) -> void:
	var F: Dictionary = R["rain"]
	EnemyProjectile.fire(get_parent(), at, Vector3(0, -float(F["fall_speed"]), 0), float(F["dmg"]) * out_mult(), Color("#f2f6ff"), 0.3, 5.0,
		{"fragile": true, "hittable": true, "kind": &"fine", "source": self, "scale": Vector3(1.4, 0.15, 1.0),
		"on_struck": _fine_struck, "on_deny": _fine_denied})


## RETURN TO SENDER: the mallet bats a falling fine into the wall (+4% max HP BREAK); a gun just pops it.
func _fine_struck(shot: EnemyProjectile, hit: Combat.Hit) -> void:
	if hit.is_melee:
		fines_batted += 1
		var from: Vector3 = shot.global_position
		shot.retire()
		EnemyFx.ring(get_parent(), core_pos(), 1.2, 0.3, Color("#f2f6ff"))
		var streak: MeshInstance3D = EnemyFx.segment(get_parent() as Node3D if get_parent() is Node3D else self, null, from, core_pos(), 0.08, Color("#f2f6ff"), 0.8)
		get_tree().create_timer(0.25).timeout.connect(streak.queue_free)
		add_break(max_hp * float(R["overload"]["bat_frac"]))
		telegraphed.emit(&"return_to_sender", &"paper_thwack", 0.0)


func _fine_denied(shot: EnemyProjectile) -> void:
	if not is_instance_valid(shot) or defeated:
		return
	if shot.global_position.distance_to(global_position) < float(R["overload"]["shot_near_r"]):
		fines_shot_near += 1
		add_break(max_hp * float(R["overload"]["shot_near_frac"]))


func _doomscroll(dt: float) -> void:
	var bolt: Node3D = target
	if bolt == null or not is_instance_valid(bolt) or not bolt.is_in_group(&"player"):
		return
	if not on_feed(bolt.global_position):
		return
	var to: Vector3 = global_position - bolt.global_position
	to.y = 0.0
	if to.length() < radius + 2.0:
		return
	var step: Vector3 = to.normalized() * float(R["doomscroll"]["speed"]) * dt
	bolt.global_position += step
	doomscroll_pushed += step.length()


# --- sequenced attacks (phase 3)

func _pick() -> StringName:
	if phase < 3:
		return &""
	return &"like_orbs" if randf() < 0.55 else &"mega_fine"


func _allowed(kind: StringName) -> bool:
	return phase >= 3 or not (kind in [&"like_orbs", &"mega_fine"])


func _start(kind: StringName) -> void:
	match kind:
		&"mega_fine":
			var M: Dictionary = R["mega_fine"]
			begin_telegraph(&"mega_fine", float(M["tele"]))
			DelayedBlast.spawn(get_parent(), target_pos(), float(M["r"]), float(M["tele"]), float(M["dmg"]) * out_mult(), Color("#ff2277"), self,
				{"shrink": false, "kind": &"mega_fine", "max_height": float(R["platform_clear"]) + 0.95,
				"on_blast": func(_hit: bool) -> void: arena_call(&"smash_cover_near", [target_pos(), float(M["r"])])})
			EventBus.hint.emit(line_text(str(R["lines"]["mega_hint"])), "algo_mega")
		&"like_orbs":
			begin_telegraph(&"like_orbs", float(R["orbs"]["tele"]))
			_core_mat.emission_energy_multiplier = 6.0
		_:
			begin_telegraph(kind)


func _attack_start(kind: StringName) -> void:
	if kind == &"like_orbs":
		var O: Dictionary = R["orbs"]
		for i: int in int(O["count"]):
			var a: float = (i - (int(O["count"]) - 1) * 0.5) * 0.6
			var v: Vector3 = (forward().rotated(Vector3.UP, a) * float(O["speed"])) + Vector3(0, 2.0, 0)
			EnemyProjectile.fire(get_parent(), core_pos() + forward() * 0.8, v, float(O["dmg"]) * out_mult(), Color("#ff4d9d"), 0.3, float(O["life"]),
				{"homing": float(O["homing"]), "speed": float(O["speed"]), "fragile": true, "hittable": true, "kind": &"like_orb", "source": self})


func _attack_tick(_kind: StringName, _dt: float) -> bool:
	return state_t >= 0.3


func _idle_after(_kind: StringName) -> float:
	var r: Array = R["idle3"]
	return randf_range(float(r[0]), float(r[1]))


func _idle_tick(_dt: float) -> void:
	desired_vel = Vector3.ZERO


# ------------------------------------------------------------------ feeders / phases / overload

func _boss_on_hurt(hit: Combat.Hit, _amount: float, _crit: bool) -> void:
	var O: Dictionary = R["overload"]
	if hit.weapon_id == &"cease_desist":
		add_break(max_hp * float(O["cd_frac"]))
		if not _cd_bark_done:
			_cd_bark_done = true
			VOManager.play(str(R["lines"]["first_cd"]))
	elif hit.weapon_id == &"class_action":
		add_break(max_hp * float(O["class_action_frac"]))


func _on_break() -> void:
	overloads += 1
	VOManager.play(str(R["lines"]["overload"]))
	_errors.visible = true
	_wheel.visible = true
	for n: Node3D in _face_nodes:
		n.visible = false


func weak_point_exposed() -> bool:
	return true


func _weak_point_pos() -> Vector3:
	return core_pos() if _core != null else get_center()


## The walkways this fight owns: the arena's (when the planet passed one), else every "nova_walkways" node.
func _my_walkways() -> Array[Node]:
	var out: Array[Node] = []
	for w: Node in get_tree().get_nodes_in_group(&"nova_walkways"):
		if arena_owned or arena_node == null or arena_node.is_ancestor_of(w):
			out.append(w)
	return out


func _set_walkways_stopped(stop: bool) -> void:
	if arena_call(&"set_doomscroll", [stop]):
		return
	for w: Node in _my_walkways():
		if w.has_method("set_stopped"):
			w.call("set_stopped", stop)


func _on_phase(p: int) -> void:
	var L: Dictionary = R["lines"]
	if p == 2:
		for m: StandardMaterial3D in _face_mats:
			m.albedo_color = Color("#ff4d3a")
			m.emission = Color("#ff2222")
		banner_lines(L["phase2_banner"], 1.8)
		_zone_t = minf(_zone_t, 1.0)
		_rain_t = minf(_rain_t, 2.0)
	elif p == 3:
		banner_lines(L["phase3_banner"], 2.0)
		VOManager.play(str(L["phase3"]))
		doomscroll_on = true
		_set_walkways_stopped(true)
		queue_line(str(L["doomscroll"]), 2.5)
		log_parallel(&"doomscroll", 1.2, &"feed_scroll")


func _pattern_died(_hit: Combat.Hit) -> void:
	doomscroll_on = false
	_set_walkways_stopped(false)
	if _card != null and is_instance_valid(_card):
		_card.queue_free()


func _anim(delta: float) -> void:
	var broken: bool = break_t > 0.0
	if not broken and _wheel.visible:
		_wheel.visible = false
		_errors.visible = false
		for n: Node3D in _face_nodes:
			n.visible = true
	if _wheel.visible:
		_wheel.rotation.z += delta * 6.0
	_core_mat.emission_energy_multiplier = (5.0 if state == State.TELEGRAPH else 2.0) + sin(t * 5.0) * 0.8
	for i: int in _leds.size():
		_leds[i].emission_energy_multiplier = 0.6 + absf(sin(t * (2.0 + i * 0.37)))
