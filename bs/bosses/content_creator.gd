class_name ContentCreator
extends PatternBoss
## THE CONTENT CREATOR — Rustvane Canyon boss, the Sunset Stage / Infinity Lava Pool deck (BS_ENEMIES §4.3;
## the original `miniboss` fight: updateMiniBoss index.html:7337, which now belongs to the Sentinel's tank kit;
## this is the remake's streamer). 420 HP, 45 bolts (kept). A lanky chrome influencer in a ring-light halo on a
## hover-gimbal over the pool deck. Weak point: the ring-light core (its face). Trophy "Unsubscribed".
##
## SPOTLIGHT SHIELD: 3 camera drones (25 HP). While any drone films, the CC takes 25% damage everywhere (even
##   the weak point). Each drone kill adds 20% of the BREAK threshold; all three down = a guaranteed BREAK
##   ("DEMONETIZED!") and the shield is off. Drones respawn (one per 6 s, up to 3) at the start of each phase.
## Phase 1 UNBOXING (100-66%): UNBOXING: a giant box drops on the deck (0.8 s shadow decal); 1.5 s later it
##   opens on 2 Selfie Sentries, a Lifeguard Bot or a SPONSORED bomb (r4, 20 dmg, 1.0 s fuse). Shooting the
##   falling SPONSORED box detonates it on the CC (+25% BREAK). CHARGE BEAM (1.25 s guide line; 14/tick, 0.9 s).
## Phase 2 COLLAB (66-33%): a hologram "collab partner" appears. TWIN BEAM (the second beam from the hologram,
##   35 degrees off; 0.95 s). 3 Ambassadog "fans" rush in. DUET MORTAR: the CC and its hologram lob 2 shells
##   each (14), landing rings 0.6 s.
## Phase 3 GOING LIVE (33-0%): LIVE CHAT: 1.0 s "chat is typing..." lane warning, then comment bubbles fall in
##   those lanes for 4 s (6 dmg, fragile/shootable). LIKE FLOOR: deck tiles light gold for 0.8 s, then blast
##   upward (16 dmg); dark tiles are safe. POOL SWEEP: the charge beam sweeps across the pool; standing in the
##   pool water during the sweep doubles its damage.
## Defeat: boss_defeated; the planet plays st.l2_glambot (the GLAMBOT defection belongs to Rustvane, builder B).
##
## ARENA CONTRACT (opts["arena"], built by Rustvane's Sunset Stage builder; all anchors optional):
##   Center      Node3D   the pool centre (else the arena node's origin)
##   Pool        Node3D   the Infinity Lava Pool; meta "radius" (default bosses.json pool_r 7) and optional
##                        meta "surface_y"; Bolt within the radius and below surface_y + 1.2 is "in the water"
##   Deck        Node3D   optional; meta "outer_radius" = the deck ring's outer edge (default pool_r + 9)
##               optional meta "aabb" (AABB of the water, world space) wins over the radius for in_water()
##   Cabana*     Marker3D ammo orbs spawn here at each phase start (as in the source); Ammo_* wins if present
##   DroneSpawn* Marker3D where camera drones appear; drones then DOCK there (orbiting 1.5 m, filming the CC)
##                        instead of orbiting the CC, so a mast swing can reach them (else above the CC, orbiting)
##   HoverStage  Node3D   optional hover-gimbal stage; its "Mount" child is where the CC floats (the planet's
##                        director drives the stage modes); without it the CC orbits the pool on the deck ring
##   Tile_*      Marker3D optional LIKE-floor tiles (2 m grid, metas "row"/"col"); else a 2 m grid around Bolt
##   BoxDrop     Marker3D optional unboxing zone (meta "radius"): drop points are clamped into it
##   AddSpawn*   Marker3D optional: where the phase-2 fans come in (else around the deck ring)
## Without an arena it builds its own: a pool disc, 2 cabanas with markers, 2 parasols, and a floor if needed.

var hologram: Node3D = null
var drones: Array[CameraDrone] = []
var drone_kills: int = 0
var drones_broken: int = 0
var sponsored_shots: int = 0
var boxes: int = 0
var force_box: StringName = &""
var _drone_queue: int = 0
var _drone_t: float = 0.0
var _drone_every: float = 6.0
var _demonetized_once: bool = false
var _twin_bark_done: bool = false
var _orbit_a: float = 0.0
var _aim_dir: Vector3 = Vector3.FORWARD
var _guide: MeshInstance3D
var _guide2: MeshInstance3D
var _sweep_rate: float = 0.0
var _chat_t: float = 0.0
var _chat_lanes: Array[Vector3] = []
var _chat_spawn_t: float = 0.0
var _halo_mat: StandardMaterial3D
var _face: MeshInstance3D
var _face_mat: StandardMaterial3D
var _halo: MeshInstance3D
var _arm_l: Node3D
var _arm_r: Node3D


func _init() -> void:
	boss_id = &"content_creator"
	id = &"content_creator"


# ------------------------------------------------------------------ visual

func _build_visual() -> void:
	var chrome: StandardMaterial3D = EnemyFx.mat(Color("#c8d0dc"))
	chrome.metallic = 0.8
	chrome.roughness = 0.25
	flash_mats.append(chrome)
	var dark: StandardMaterial3D = EnemyFx.mat(Color("#232838"))
	EnemyFx.cyl(visual, 1.1, 0.25, Vector3(0, 0.2, 0), dark)                                               # hover gimbal
	EnemyFx.torus(visual, 1.0, 1.2, Vector3(0, 0.2, 0), EnemyFx.mat(Color("#ff4d9d"), Color("#ff4d9d"), 1.5))
	for sx: float in [-0.22, 0.22]:
		EnemyFx.cyl(visual, 0.09, 1.5, Vector3(sx, 1.05, 0), chrome)                                       # lanky legs
	EnemyFx.cyl(visual, 0.28, 1.4, Vector3(0, 2.4, 0), chrome, 0.38)                                         # torso
	EnemyFx.box(visual, Vector3(0.62, 0.3, 0.3), Vector3(0, 2.6, 0.12), EnemyFx.mat(Color("#ff4d9d")))      # merch hoodie
	for sx: float in [-1.0, 1.0]:
		var arm: Node3D = Node3D.new()
		arm.position = Vector3(0.45 * sx, 2.95, 0)
		visual.add_child(arm)
		EnemyFx.cyl(arm, 0.07, 1.3, Vector3(0, -0.6, 0), chrome)
		if sx < 0.0:
			_arm_l = arm
		else:
			_arm_r = arm
	EnemyFx.box(_arm_r, Vector3(0.18, 0.32, 0.05), Vector3(0, -1.3, 0.1), EnemyFx.mat(Color("#1c2333"), Color("#3ee6ff"), 1.0))   # phone
	EnemyFx.cyl(visual, 0.07, 0.4, Vector3(0, 3.3, 0), chrome)                                                # neck
	_halo_mat = EnemyFx.mat(Color.WHITE, Color("#ffeedd"), 1.8)
	_halo = EnemyFx.torus(visual, 0.62, 0.82, Vector3(0, 3.95, 0), _halo_mat)                                  # ring-light halo
	_halo.rotation.x = PI / 2
	_face_mat = EnemyFx.mat(Color("#ffb02e"), Color("#ff8800"), 2.2)
	_face = EnemyFx.sphere(visual, 0.38, Vector3(0, 3.95, 0.05), _face_mat)                                   # the ring-light core (weak point)
	var lbl: Label3D = Label3D.new()
	lbl.text = "● LIVE"
	lbl.font_size = 40
	lbl.pixel_size = 0.005
	lbl.modulate = Color("#ff2222")
	lbl.position = Vector3(0, 4.95, 0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	visual.add_child(lbl)


func _build_body() -> void:
	super._build_body()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 1.0
	cap.height = 4.4
	_shape.shape = cap
	_shape.position.y = 2.3


func get_center() -> Vector3:
	return global_position + Vector3(0, 2.8, 0)


func face_pos() -> Vector3:
	return _face.global_position


func _build_default_arena() -> Node3D:
	var a: Node3D = Node3D.new()
	var pr: float = float(R["pool_r"])
	var pool: Node3D = PatternBoss.arena_marker(a, "Pool", Vector3.ZERO)
	pool.set_meta(&"radius", pr)
	var water: MeshInstance3D = EnemyFx.cyl(pool, pr, 0.05, Vector3(0, 0.03, 0), EnemyFx.glow(Color("#ff7a2e"), 0.45))
	water.set_meta(&"no_rim", true)
	var deck: Node3D = PatternBoss.arena_marker(a, "Deck", Vector3.ZERO)
	deck.set_meta(&"outer_radius", pr + float(R["deck_w"]))
	for i: int in 2:
		var sx: float = -1.0 if i == 0 else 1.0
		PatternBoss.arena_box(a, "CabanaBody%d" % i, Vector3(3, 2.6, 2.4), Vector3(sx * (pr + 7.5), 1.3, -4.0), Color("#f2ebe0"))
		PatternBoss.arena_marker(a, "Cabana%d" % i, Vector3(sx * (pr + 5.5), 0.6, -4.0))
		PatternBoss.arena_box(a, "Parasol%d" % i, Vector3(0.3, 2.4, 0.3), Vector3(sx * (pr + 3.5), 1.2, 5.0), Color("#ff4d9d"))
	if _needs_floor():
		PatternBoss.arena_box(a, "Floor", Vector3(70, 1, 70), Vector3(0, -0.5, 0), Color("#d8c8a8"))
	_attach_arena(a)
	return a


func pool_center() -> Vector3:
	var p: Node3D = anchor(&"Pool")
	return _gpos(p) if p != null else arena_mid


func pool_radius() -> float:
	var p: Node3D = anchor(&"Pool")
	return float(p.get_meta(&"radius", R["pool_r"])) if p != null else float(R["pool_r"])


func deck_outer() -> float:
	var d: Node3D = anchor(&"Deck")
	return float(d.get_meta(&"outer_radius", pool_radius() + float(R["deck_w"]))) if d != null else pool_radius() + float(R["deck_w"])


## Bolt (or any point) standing in the pool water.
func in_water(p: Vector3) -> bool:
	var c: Vector3 = pool_center()
	var pool: Node3D = anchor(&"Pool")
	var sy: float = float(pool.get_meta(&"surface_y", c.y)) if pool != null else c.y
	if pool != null and pool.has_meta(&"aabb"):
		var bb: AABB = pool.get_meta(&"aabb")
		return p.x >= bb.position.x and p.x <= bb.end.x and p.z >= bb.position.z and p.z <= bb.end.z and p.y < sy + 1.2
	return Vector2(p.x - c.x, p.z - c.z).length() < pool_radius() and p.y < sy + 1.2


# ------------------------------------------------------------------ setup

func _pattern_activate() -> void:
	gravity_on = false
	hologram = null
	drones.clear()
	drone_kills = 0
	drones_broken = 0
	sponsored_shots = 0
	boxes = 0
	_drone_queue = 0
	_drone_t = 0.0
	_demonetized_once = false
	_twin_bark_done = false
	_orbit_a = 0.0
	_chat_t = 0.0


func start_fight() -> void:
	var was: bool = started
	super.start_fight()
	if not was and started:
		_queue_drones(int(R["drones"]["count"]), 0.0, float(R["drones"]["opening_every"]))


## Queues `n` drones: the first after `first_delay`, then one per `every` (the opening crew arrives together;
## phase respawns come one per 6 s).
func _queue_drones(n: int, first_delay: float, every: float = -1.0) -> void:
	_drone_queue = n
	_drone_t = first_delay
	_drone_every = every if every >= 0.0 else float(R["drones"]["respawn_every"])


func drones_alive() -> int:
	var n: int = 0
	for d: CameraDrone in drones:
		if is_instance_valid(d) and d.is_alive() and d.boss == self:
			n += 1
	return n


func shielded() -> bool:
	return drones_alive() > 0


func _spawn_drone() -> void:
	var spots: Array[Node3D] = anchors("DroneSpawn")
	var at: Vector3 = _gpos(spots[drones.size() % spots.size()]) if not spots.is_empty() else global_position + Vector3(0, 4.5, 0)
	var d: CameraDrone = spawn_add(&"cc_camera_drone", at, {"spawn_time": 0.1}) as CameraDrone
	if d == null:
		return
	d.boss = self
	d.slot = drones_alive() % 3
	d.dock = at if not spots.is_empty() else Vector3.INF
	if not d.died.is_connected(_on_drone_died):
		d.died.connect(_on_drone_died)
	drones = drones.filter(func(x: CameraDrone) -> bool: return is_instance_valid(x) and x.is_alive() and x.boss == self)
	drones.append(d)


func _on_drone_died(d: EnemyBase) -> void:
	if d is CameraDrone and (d as CameraDrone).boss != self:
		return
	(d as CameraDrone).boss = null
	drone_kills += 1
	if defeated:
		return
	add_break(break_threshold() * float(R["drones"]["kill_break_frac"]))
	if drones_alive() == 0 and _drone_queue <= 0:
		drones_broken += 1
		break_cd = 0.0
		if break_t <= 0.0:
			do_break()                                       # all three down: a guaranteed BREAK
		VOManager.play(str(R["lines"]["drones_down"]))
		if not _demonetized_once:
			_demonetized_once = true
			banner_lines(R["lines"]["demonetized_banner"], 1.8)
			queue_line(str(R["lines"]["drones_down_first"]), 2.5)


# ------------------------------------------------------------------ fight

func _fight_tick(dt: float) -> void:
	if _drone_queue > 0:
		_drone_t -= dt
		if _drone_t <= 0.0:
			_drone_t = _drone_every
			_drone_queue -= 1
			_spawn_drone()
			if drones_alive() == 1:
				VOManager.play(str(R["lines"]["drones_spawn"]))
	if hologram != null and is_instance_valid(hologram):
		hologram.global_position = _holo_pos()
		hologram.rotation.y = rotation.y
	_chat_tick(dt)


func _hover_goal(dt: float) -> Vector3:
	var c: Vector3 = pool_center()
	var rr: float = (pool_radius() + deck_outer()) * 0.5
	_orbit_a += dt * float(R["hover"]["orbit_rate"])
	var gy: float = EnemyFx.floor_y(self, Vector3(c.x + cos(_orbit_a) * rr, c.y, c.z + sin(_orbit_a) * rr), c.y, 3.0, 20.0)
	return Vector3(c.x + cos(_orbit_a) * rr, gy + float(R["hover"]["height"]), c.z + sin(_orbit_a) * rr)


func _idle_tick(dt: float) -> void:
	var goal: Vector3 = _hover_goal(dt)
	var stage: Node3D = anchor(&"HoverStage")
	if stage != null and stage.is_inside_tree():
		var mount: Node3D = stage.get_node_or_null(^"Mount") as Node3D
		goal = mount.global_position if mount != null else stage.global_position + Vector3(0, 0.5, 0)
	desired_vel = (goal - global_position) * float(R["hover"]["follow"]) * move_mult()
	face(target_pos() - global_position, dt, 3.0)


func _stagger_tick(_dt: float) -> void:
	desired_vel = Vector3(0, -0.6, 0) if global_position.y > pool_center().y + 1.0 else Vector3.ZERO     # sags on its gimbal


func _pick() -> StringName:
	var roll: float = randf()
	match phase:
		1:
			return &"unbox" if roll < float(R["unbox"]["roll"]) else &"beam"
		2:
			return &"twin_beam" if roll < 0.55 else &"duet_mortar"
		_:
			if roll < 0.34:
				return &"live_chat"
			elif roll < 0.67:
				return &"like_floor"
			return &"pool_sweep"


func _allowed(kind: StringName) -> bool:
	match kind:
		&"twin_beam", &"duet_mortar":
			return phase >= 2
		&"live_chat", &"like_floor", &"pool_sweep":
			return phase >= 3
	return true


func _start(kind: StringName) -> void:
	_aim_dir = _to_target_dir()
	match kind:
		&"unbox":
			var at: Vector3 = target_pos() + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
			var zone: Node3D = anchor(&"BoxDrop")
			if zone != null:
				var zc: Vector3 = _gpos(zone)
				var off: Vector3 = Vector3(at.x - zc.x, 0, at.z - zc.z)
				at = zc + off.limit_length(float(zone.get_meta(&"radius", 6.0)))
			var U: Dictionary = R["unbox"]
			begin_telegraph(&"unbox", float(U["fall_time"]))
			var contents: StringName = force_box
			force_box = &""
			if contents == &"":
				var opts_: Array = U["contents"]
				contents = StringName(str(opts_[randi() % opts_.size()]))
			boxes += 1
			MysteryBox.drop(get_parent(), self, at, contents, U)
			VOManager.play(str(R["lines"]["unbox"]))
			if contents == &"bomb":
				queue_line(str(R["lines"]["unbox_bomb"]), float(U["fall_time"]) + 0.3)
			tele_light.light_color = Color("#c8a040")
		&"beam":
			begin_telegraph(&"beam", float(R["beam"]["tele"][0]))
		&"twin_beam":
			begin_telegraph(&"twin_beam", float(R["beam"]["tele"][1]))
		&"duet_mortar":
			begin_telegraph(&"duet_mortar", float(R["mortar"]["tele"]))
			_plan_duet()
		&"live_chat":
			begin_telegraph(&"live_chat", float(R["chat"]["warn"]))
			_plan_chat()
			EventBus.hint.emit(line_text(str(R["lines"]["chat_typing"])), "cc_chat")
		&"like_floor":
			begin_telegraph(&"like_floor", float(R["likes"]["tele"]))
			_plan_likes()
		&"pool_sweep":
			begin_telegraph(&"pool_sweep", float(R["beam"]["tele"][0]))
			var c: Vector3 = pool_center() - face_pos()
			c.y = 0.0
			var sw: float = deg_to_rad(float(R["sweep"]["arc_deg"])) * 0.5
			_aim_dir = c.normalized().rotated(Vector3.UP, -sw) if c.length_squared() > 0.01 else _aim_dir
			_sweep_rate = deg_to_rad(float(R["sweep"]["arc_deg"])) / float(R["sweep"]["time"])
			VOManager.play(str(R["lines"]["pool_sweep"]))


func _to_target_dir() -> Vector3:
	var d: Vector3 = target_center() - face_pos()
	d.y = 0.0
	return d.normalized() if d.length_squared() > 0.001 else forward()


func _holo_pos() -> Vector3:
	var c: Vector3 = pool_center()
	var me: Vector3 = global_position - c
	me.y = 0.0
	var other: Vector3 = c - me.normalized() * me.length() if me.length_squared() > 0.01 else c + Vector3(6, 0, 0)
	return Vector3(other.x, global_position.y, other.z)


func _tele_tick(kind: StringName, dt: float) -> void:
	face(target_pos() - global_position, dt, 1.2)
	var par: Node3D = get_parent() as Node3D if get_parent() is Node3D else self
	var L: float = float(R["beam"]["length"])
	match kind:
		&"beam", &"twin_beam":
			_aim_dir = _aim_dir.slerp(_to_target_dir(), 1.0 - exp(-float(R["beam"]["track_busy"]) * dt)).normalized()
			var a: Vector3 = face_pos()
			_guide = EnemyFx.segment(par, _guide, a, a + _aim_dir * L, 0.06, Color("#ff5d2e"))
			_guide.visible = true
			if kind == &"twin_beam" and hologram != null:
				var ha: Vector3 = hologram.global_position + Vector3(0, 3.95, 0)
				var hd: Vector3 = _holo_dir()
				_guide2 = EnemyFx.segment(par, _guide2, ha, ha + hd * L, 0.06, Color("#c06aff"))
				_guide2.visible = true
		&"pool_sweep":
			var a2: Vector3 = face_pos()
			_guide = EnemyFx.segment(par, _guide, a2, a2 + _aim_dir * L, 0.06, Color("#ff5d2e"))
			_guide.visible = true
	_halo_mat.emission_energy_multiplier = 1.8 + (1.0 - clampf(tele_t / maxf(tele_dur, 0.01), 0.0, 1.0)) * 4.0


func _holo_dir() -> Vector3:
	if hologram == null:
		return _aim_dir
	var d: Vector3 = target_center() - hologram.global_position
	d.y = 0.0
	d = d.normalized() if d.length_squared() > 0.001 else _aim_dir
	return d.rotated(Vector3.UP, deg_to_rad(float(R["beam"]["twin_deg"])))


func _hide_guides() -> void:
	for g: MeshInstance3D in [_guide, _guide2]:
		if g != null and is_instance_valid(g):
			g.visible = false


func _attack_start(kind: StringName) -> void:
	_hide_guides()
	var B: Dictionary = R["beam"]
	match kind:
		&"beam":
			EnemyBeam.fire(get_parent(), face_pos(), _aim_dir, float(B["length"]), float(B["r"]), float(B["dmg"]) * out_mult(), float(B["life"]), Color("#ff5d2e"), self)
		&"twin_beam":
			EnemyBeam.fire(get_parent(), face_pos(), _aim_dir, float(B["length"]), float(B["r"]), float(B["dmg"]) * out_mult(), float(B["life"]), Color("#ff5d2e"), self)
			if hologram != null:
				EnemyBeam.fire(get_parent(), hologram.global_position + Vector3(0, 3.95, 0), _holo_dir(), float(B["length"]), float(B["r"]),
					float(B["twin_dmg"]) * out_mult(), float(B["life"]), Color("#c06aff"), self)
			if not _twin_bark_done:
				_twin_bark_done = true
				VOManager.play(str(R["lines"]["first_twin"]))
		&"duet_mortar":
			_fire_duet()
		&"live_chat":
			_chat_t = float(R["chat"]["time"])
			_chat_spawn_t = 0.0
		&"like_floor":
			pass
		&"pool_sweep":
			var mult: Callable = func(p: Vector3) -> float: return float(R["sweep"]["water_mult"]) if in_water(p) else 1.0
			EnemyBeam.fire(get_parent(), face_pos(), _aim_dir, float(B["length"]), float(B["r"]), float(B["dmg"]) * out_mult(),
				float(R["sweep"]["time"]), Color("#ff5d2e"), self, {"sweep_rate": _sweep_rate, "mult_at": mult})
		&"unbox":
			pass


func _attack_tick(kind: StringName, _dt: float) -> bool:
	match kind:
		&"beam", &"twin_beam":
			return state_t >= float(R["beam"]["life"])
		&"pool_sweep":
			return state_t >= float(R["sweep"]["time"])
		&"live_chat":
			return state_t >= 0.3
	return true


func _idle_after(kind: StringName) -> float:
	var r: Array = R["idle"][clampi(phase - 1, 0, 2)]
	if kind == &"live_chat":
		return float(R["chat"]["time"]) * 0.6
	return randf_range(float(r[0]), float(r[1]))


# --- duet mortar

var _duet_lands: Array[Vector3] = []


func _plan_duet() -> void:
	_duet_lands.clear()
	var M: Dictionary = R["mortar"]
	var sp: float = float(M["spread"])
	for i: int in int(M["per_caster"]) * (2 if hologram != null else 1):
		_duet_lands.append(target_pos() + Vector3(randf_range(-sp, sp), 0, randf_range(-sp, sp)))


func _fire_duet() -> void:
	var M: Dictionary = R["mortar"]
	var per: int = int(M["per_caster"])
	for i: int in _duet_lands.size():
		var from: Vector3 = face_pos() if i < per or hologram == null else hologram.global_position + Vector3(0, 3.95, 0)
		lob_shell(from, _duet_lands[i], float(M["flight"]), float(M["dmg"]), Color("#ffb02e"), float(M["blast_r"]), {"kind": &"mortar"})


# --- live chat (phase 3)

func _plan_chat() -> void:
	_chat_lanes.clear()
	var C: Dictionary = R["chat"]
	var f: Vector3 = _to_target_dir()
	var side: Vector3 = Vector3(-f.z, 0, f.x)
	var n: int = int(C["lanes"])
	for i: int in n:
		var off: float = (i - (n - 1) * 0.5) * float(C["lane_gap"])
		var start: Vector3 = target_pos() + side * off - f * float(C["lane_len"]) * 0.5
		_chat_lanes.append(start)
		EnemyFx.lane(get_parent(), start, f, float(C["lane_len"]), float(C["lane_w"]), float(C["warn"]) + float(C["time"]), Color("#3ee6ff"))
	_chat_lanes.append(f)                                                # last entry: lane direction


func _chat_tick(dt: float) -> void:
	if _chat_t <= 0.0 or _chat_lanes.size() < 2:
		return
	_chat_t -= dt
	_chat_spawn_t -= dt
	if _chat_spawn_t > 0.0:
		return
	var C: Dictionary = R["chat"]
	_chat_spawn_t = float(C["every"])
	var f: Vector3 = _chat_lanes[_chat_lanes.size() - 1]
	var li: int = randi() % (_chat_lanes.size() - 1)
	var at: Vector3 = _chat_lanes[li] + f * randf_range(0.0, float(C["lane_len"]))
	EnemyProjectile.fire(get_parent(), at + Vector3(0, float(C["height"]), 0), Vector3(0, -float(C["fall_speed"]), 0), float(C["dmg"]) * out_mult(),
		Color("#f2ebe0"), 0.35, 4.0, {"fragile": true, "hittable": true, "kind": &"chat", "source": self, "scale": Vector3(1.6, 0.8, 0.5)})


# --- LIKE floor (phase 3)

var like_tiles: int = 0


func _plan_likes() -> void:
	var Lk: Dictionary = R["likes"]
	var s: float = float(Lk["tile"])
	var tiles: Array[Node3D] = anchors("Tile_")
	if not tiles.is_empty():
		like_tiles = 0
		var parity: int = randi() % 2
		var reach: float = float(Lk["arena_reach"])
		for tl: Node3D in tiles:
			var tp: Vector3 = _gpos(tl)
			if Vector2(tp.x - target_pos().x, tp.z - target_pos().z).length() > reach:
				continue
			if (int(tl.get_meta(&"row", 0)) + int(tl.get_meta(&"col", 0)) + parity) % 2 != 0:
				continue                                          # the dark tiles are safe
			like_tiles += 1
			DelayedBlast.spawn(get_parent(), tp, s * 0.5, float(Lk["tele"]), float(Lk["dmg"]) * out_mult(), Color("#ffd23e"), self,
				{"square": true, "kind": &"like_tile", "knock": 4.0})
		return
	var half: int = int(Lk["grid_half"])
	var c: Vector3 = target_pos()
	var cx: float = roundf(c.x / s) * s
	var cz: float = roundf(c.z / s) * s
	like_tiles = 0
	for ix: int in range(-half, half + 1):
		for iz: int in range(-half, half + 1):
			if (ix + iz) % 2 != 0 and not (ix == 0 and iz == 0):
				continue                                          # a checkerboard: the dark tiles are safe
			var p: Vector3 = Vector3(cx + ix * s, c.y, cz + iz * s)
			if in_water(p):
				continue
			like_tiles += 1
			DelayedBlast.spawn(get_parent(), p, s * 0.5, float(Lk["tele"]), float(Lk["dmg"]) * out_mult(), Color("#ffd23e"), self,
				{"square": true, "kind": &"like_tile", "knock": 4.0})


# ------------------------------------------------------------------ feeders, armour

func _armor_override(_hit: Combat.Hit, _crit: bool) -> float:
	return float(R["drones"]["shield_mult"]) if shielded() else -1.0


## A falling SPONSORED box was shot: it blows up on the CC.
func sponsored_shot(_box: Node) -> void:
	sponsored_shots += 1
	add_break(break_threshold() * float(R["unbox"]["shot_break_frac"]))
	EnemyFx.ring(get_parent(), global_position, float(R["unbox"]["bomb_r"]), 0.3, Color("#ff4d9d"))
	telegraphed.emit(&"sponsored_backfire", &"boom", 0.0)


func weak_point_exposed() -> bool:
	return true


func _weak_point_pos() -> Vector3:
	return face_pos() if _face != null else get_center()


func _on_phase(p: int) -> void:
	var L: Dictionary = R["lines"]
	_queue_drones(int(R["drones"]["count"]) - drones_alive(), 0.5)
	var ammo_spots: Array[Node3D] = anchors("Ammo_")
	if ammo_spots.is_empty():
		ammo_spots = anchors("Cabana")
	for cab: Node3D in ammo_spots:
		if cab.is_inside_tree() and get_parent() != null:
			Pickup.spawn(get_parent(), &"ammo_r" if randf() < 0.5 else &"ammo_z", _gpos(cab) + Vector3(0, 0.8, 0))
	if p == 2:
		banner_lines(L["phase2_banner"], 2.0)
		VOManager.play(str(L["phase2"]))
		_make_hologram()
		var F: Dictionary = R["fans"]
		var pts: Array[Node3D] = anchors("AddSpawn")
		for i: int in int(F["count"]):
			var a: float = TAU * i / float(F["count"])
			var at: Vector3 = pool_center() + Vector3(cos(a), 0, sin(a)) * (deck_outer() - 1.0) + Vector3(0, 0.3, 0)
			if not pts.is_empty():
				at = _gpos(pts[i % pts.size()]) + Vector3(0, 0.3, 0)
			spawn_add(StringName(str(F["id"])), at)
	elif p == 3:
		banner_lines(L["phase3_banner"], 2.0)
		VOManager.play(str(L["phase3"]))
		if hologram != null and is_instance_valid(hologram):
			hologram.queue_free()
		hologram = null


func _make_hologram() -> void:
	if hologram != null or get_parent() == null:
		return
	hologram = Node3D.new()
	hologram.name = "CollabHologram"
	var m: StandardMaterial3D = EnemyFx.glow(Color("#c06aff"), 0.35)
	EnemyFx.cyl(hologram, 0.28, 1.4, Vector3(0, 2.4, 0), m, 0.38)
	EnemyFx.cyl(hologram, 0.09, 1.5, Vector3(0, 1.05, 0), m)
	EnemyFx.torus(hologram, 0.62, 0.82, Vector3(0, 3.95, 0), m).rotation.x = PI / 2
	EnemyFx.sphere(hologram, 0.36, Vector3(0, 3.95, 0.05), m)
	get_parent().add_child(hologram)
	hologram.global_position = _holo_pos()


func _pattern_cancelled() -> void:
	_hide_guides()
	_chat_t = 0.0


func _pattern_died(_hit: Combat.Hit) -> void:
	_hide_guides()
	_chat_t = 0.0
	if hologram != null and is_instance_valid(hologram):
		hologram.queue_free()
	hologram = null
	for d: CameraDrone in drones:
		if is_instance_valid(d) and d.is_alive():
			var h: Combat.Hit = Combat.Hit.make(1.0e6)
			h.weapon_id = &"boss_down"
			d.take_damage(h)


## The story beat the planet plays on defeat (bosses.json lines.defeat_beat: "l2_glambot").
func defeat_beat() -> String:
	return str(R["lines"].get("defeat_beat", ""))


func _anim(_delta: float) -> void:
	_face_mat.emission_energy_multiplier = 2.2 + sin(t * 5.0) * 0.8
	if state != State.TELEGRAPH:
		_halo_mat.emission_energy_multiplier = 1.8 if shielded() else 0.8
	_arm_r.rotation.x = -1.2 + sin(t * 2.0) * 0.1                         # always filming itself
	_arm_l.rotation.z = 0.3 + sin(t * 3.0) * 0.2
