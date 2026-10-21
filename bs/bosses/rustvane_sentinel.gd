class_name RustvaneSentinel
extends PatternBoss
## RUSTVANE SENTINEL — Rustvane Canyon mini-boss, the Strip Mine quarry floor (BS_ENEMIES §4.2).
## The resort's security tank: the original `miniboss` tank chassis (makeMiniBoss index.html:2505,
## updateMiniBoss :7337-7420) split off from the Content Creator. 300 HP, 30 bolts. Weak point: the reactor
## core under the turret (always a crit). Trophy "Wristband Optional".
##
## Phase 1 SECURITY CHECK (100-66%):
##   CHARGE BEAM: the turret tracks slowly (rate 0.6 while telegraphing); a thin red guide line shows the exact
##   lane for 1.25 s; then the beam fires for 0.9 s (14 dmg per 0.3 s tick, r0.45, 30 m; cover clips it).
##   MORTAR LOB (parallel): 2 shells every 3.6 s (14 each), lobbed with spread; each landing spot gets a ring
##   for the whole flight (>= 0.6 s).
## Phase 2 LOCKDOWN (66-33%): the plates blow off. TWIN BEAM: a second beam 35 degrees off (12 dmg); telegraph
##   0.95 s. SEARCHLIGHT (parallel): a cone sweeps the quarry; if it catches Bolt (in the cone, in sight) a
##   0.5 s "SPOTTED" chime plays and the next mortar pair homes on him (no spread, leading his motion).
## Phase 3 RESORT POLICY (33-0%): faster cycles (1.1-1.8 s idle); treads engage and it RAMS across the quarry
##   between beam cycles (0.7 s lane decal, 16 m/s, 18 dmg); 2 Ambassadog adds at the phase start.
## BREAK feeders: a shot down the barrel (the muzzle) during a beam telegraph cancels that beam and adds 25%
##   of the threshold; a ram into a quarry pillar stuns it for 1.5 s and adds 40%.
##
## ARENA CONTRACT (opts["arena"], built by Rustvane's Strip Mine builder; every anchor is optional):
##   Center        Node3D   the quarry floor centre (else the arena node's origin)
##   size          meta or property, Vector2/Vector3 x/z extent (else bosses.json arena_size 36 x 36)
##   Pillar*       Node3D   quarry pillars (world-layer bodies); a ram that reaches one (pillar meta "radius",
##                          default 1.6 m, plus the tank's radius) self-stuns the Sentinel
##   AddSpawn*     Marker3D where the phase-3 Ambassadogs appear (else beside the tank)
##   Mound*        world-layer gravel mounds: cover against beams (beams clip on world geometry), not mortars
##   Searchlight   Node3D   optional mount for the phase-2 searchlight (e.g. up on a terrace); the lamp moves there
##                          and sweeps across the arena centre. Without it the lamp rides the turret.
## Without an arena it builds its own: 4 pillars, 3 mounds and 2 add markers around its spawn point.

var muzzle_shots: int = 0
var ram_stuns: int = 0
var spotted: bool = false
var spots: int = 0
var plates_blown: bool = false
var _turret: Node3D
var _muzzle: MeshInstance3D
var _muzzle_mat: StandardMaterial3D
var _core: MeshInstance3D
var _core_mat: StandardMaterial3D
var _plates: Array[MeshInstance3D] = []
var _search_pivot: Node3D
var _search_cone: MeshInstance3D
var _search_mat: StandardMaterial3D
var _guide: MeshInstance3D
var _guide2: MeshInstance3D
var _mortar_t: float = 3.0
var _search_t: float = 0.0
var _spot_cd: float = 0.0
var _search_bark_done: bool = false
var _ram_dir: Vector3 = Vector3.FORWARD
var _last: StringName = &""
var _hit_in_beam_tele: bool = false
var _search_mounted: bool = false


func _init() -> void:
	boss_id = &"rustvane_sentinel"
	id = &"rustvane_sentinel"


# ------------------------------------------------------------------ visual (greybox tank)

func _build_visual() -> void:
	var hull: StandardMaterial3D = EnemyFx.mat(Color("#7a3b2a"))
	flash_mats.append(hull)
	var tread: StandardMaterial3D = EnemyFx.mat(Color("#2c2018"))
	EnemyFx.box(visual, Vector3(3.4, 1.4, 4.2), Vector3(0, 1.0, 0), hull)
	for sx: float in [-1.85, 1.85]:
		EnemyFx.box(visual, Vector3(0.7, 1.1, 4.6), Vector3(sx, 0.55, 0), tread)
		for k: int in range(-2, 3):
			EnemyFx.cyl(visual, 0.45, 0.75, Vector3(sx, 0.5, k * 0.95), EnemyFx.mat(Color("#1c140e"))).rotation.z = PI / 2
	for sx: float in [-1.55, 1.55]:                                      # bolt-on armour plates (blow off at phase 2)
		var pl: MeshInstance3D = EnemyFx.box(visual, Vector3(0.25, 0.9, 3.4), Vector3(sx * 1.08, 1.15, 0), EnemyFx.mat(Color("#9c5a3a")))
		_plates.append(pl)
	EnemyFx.box(visual, Vector3(1.6, 0.4, 0.2), Vector3(0, 1.5, 2.12), EnemyFx.mat(Color("#ffd23e"), Color("#ffaa00"), 0.8))  # SECURITY bar
	var lbl: Label3D = Label3D.new()
	lbl.text = "RESORT SECURITY"
	lbl.font_size = 48
	lbl.pixel_size = 0.005
	lbl.modulate = Color("#1c2333")
	lbl.position = Vector3(0, 1.5, 2.24)
	visual.add_child(lbl)
	_turret = Node3D.new()
	_turret.position.y = 2.1
	visual.add_child(_turret)
	EnemyFx.box(_turret, Vector3(1.9, 0.9, 1.9), Vector3.ZERO, hull)
	EnemyFx.cyl(_turret, 0.22, 2.6, Vector3(0, 0.05, 1.6), EnemyFx.mat(Color("#232838"))).rotation.x = PI / 2
	_muzzle_mat = EnemyFx.mat(Color("#ff5d2e"), Color("#ff3300"), 0.0)
	_muzzle_mat.emission_enabled = true
	_muzzle = EnemyFx.cyl(_turret, 0.26, 0.2, Vector3(0, 0.05, 2.95), _muzzle_mat)
	_muzzle.rotation.x = PI / 2
	_core_mat = EnemyFx.mat(Color("#ffb02e"), Color("#ff8800"), 2.0)
	_core = EnemyFx.sphere(_turret, 0.42, Vector3(0, -0.5, -0.95), _core_mat)                                 # reactor core under the turret
	_search_pivot = Node3D.new()
	_search_pivot.position = Vector3(0.7, 0.6, 0.4)
	_turret.add_child(_search_pivot)
	EnemyFx.cyl(_search_pivot, 0.2, 0.3, Vector3.ZERO, EnemyFx.mat(Color("#dfe6ee"), Color("#ffffff"), 1.0)).rotation.x = PI / 2
	_search_mat = EnemyFx.glow(Color("#fff6c8"), 0.16)
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 0.1
	cm.height = 1.0
	cm.radial_segments = 16
	_search_cone = MeshInstance3D.new()
	_search_cone.mesh = cm
	_search_cone.material_override = _search_mat
	_search_cone.set_meta(&"no_rim", true)
	_search_pivot.add_child(_search_cone)
	_search_cone.visible = false


func _build_body() -> void:
	super._build_body()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(4.0, 2.6, 4.6)
	_shape.shape = bs
	_shape.position.y = 1.3


func get_center() -> Vector3:
	return global_position + Vector3(0, 1.8, 0)


func muzzle_pos() -> Vector3:
	return _muzzle.global_position


func core_pos() -> Vector3:
	return _core.global_position


func _build_default_arena() -> Node3D:
	var a: Node3D = Node3D.new()
	var A: Dictionary = R["default_arena"]
	var rr: float = float(A["pillar_ring"])
	for i: int in 4:
		var ang: float = PI / 4.0 + TAU * i / 4.0
		var p: StaticBody3D = PatternBoss.arena_box(a, "Pillar%d" % i, Vector3(2.4, 7.0, 2.4), Vector3(cos(ang) * rr, 3.5, sin(ang) * rr), Color("#8a5a3a"))
		p.set_meta(&"radius", 1.6)
	for i: int in 3:
		var ang2: float = PI * 0.5 * i                                    # between the pillar diagonals: rams to pillars stay clear
		PatternBoss.arena_box(a, "Mound%d" % i, Vector3(3.0, 1.4, 2.0), Vector3(cos(ang2) * rr * 0.6, 0.7, sin(ang2) * rr * 0.6), Color("#7a6a58"))
	PatternBoss.arena_marker(a, "AddSpawn0", Vector3(-6, 0.3, 6))
	PatternBoss.arena_marker(a, "AddSpawn1", Vector3(6, 0.3, 6))
	if _needs_floor():
		PatternBoss.arena_box(a, "Floor", Vector3(60, 1, 60), Vector3(0, -0.5, 0), Color("#5e4a38"))
	_attach_arena(a)
	return a


# ------------------------------------------------------------------ setup

func _pattern_activate() -> void:
	muzzle_shots = 0
	ram_stuns = 0
	spotted = false
	spots = 0
	plates_blown = false
	_mortar_t = float(R["mortar"]["first"])
	_search_t = 0.0
	_spot_cd = 0.0
	_search_bark_done = false
	_last = &""
	for p: MeshInstance3D in _plates:
		p.visible = true
	var mount: Node3D = anchor(&"Searchlight")
	if mount != null and not arena_owned and mount.is_inside_tree() and not _search_mounted:
		_search_pivot.reparent(mount, false)
		_search_pivot.position = Vector3.ZERO
		_search_mounted = true


# ------------------------------------------------------------------ fight

func _turret_yaw_rate() -> float:
	return float(R["turret"]["track_busy"]) if state == State.TELEGRAPH else float(R["turret"]["track_idle"])


func _turret_dir() -> Vector3:
	var b: Basis = _turret.global_basis
	var f: Vector3 = b.z
	f.y = 0.0
	return f.normalized() if f.length_squared() > 0.0001 else forward()


func _track(dt: float) -> void:
	if target == null:
		return
	var to: Vector3 = target_pos() - global_position
	var want: float = atan2(to.x, to.z) - rotation.y
	_turret.rotation.y = lerp_angle(_turret.rotation.y, want, 1.0 - exp(-_turret_yaw_rate() * dt))


func _fight_tick(dt: float) -> void:
	if state != State.ATTACK or attack_kind != &"beam":
		_track(dt)
	_mortar_t -= dt
	if _mortar_t <= 0.0:
		_mortar_t = ph(R["mortar"]["every"])
		_fire_mortars()
	_spot_cd -= dt
	if phase >= 2:
		_searchlight(dt)
	else:
		_search_cone.visible = false


func _fire_mortars() -> void:
	var M: Dictionary = R["mortar"]
	var from: Vector3 = muzzle_pos() + Vector3(0, 0.4, 0)
	var flight: float = float(M["flight"])
	var homing: bool = spotted
	spotted = false
	for i: int in int(M["count"]):
		var land: Vector3 = target_pos()
		if homing:
			if "motor" in target and target.get("motor") != null:
				var v: Vector3 = target.get("motor").get("vel")
				land += Vector3(v.x, 0, v.z) * flight * float(M["lead"])
		else:
			var sp: float = float(M["spread"])
			land += Vector3(randf_range(-sp, sp), 0, randf_range(-sp, sp))
		lob_shell(from, land, flight + i * 0.12, float(M["dmg"]), Color("#ffb02e"), float(M["blast_r"]), {"kind": &"mortar"})
	log_parallel(&"mortar_homing" if homing else &"mortar", flight, &"mortar_thump")


func _searchlight(dt: float) -> void:
	var S_: Dictionary = R["searchlight"]
	_search_t += dt
	_search_cone.visible = true
	var sweep: float = sin(_search_t * TAU / float(S_["period"])) * deg_to_rad(float(S_["sweep_deg"]))
	if _search_mounted:
		var to_mid: Vector3 = arena_mid - _search_pivot.global_position
		_search_pivot.global_rotation = Vector3(0, atan2(to_mid.x, to_mid.z) + sweep, 0)
	else:
		_search_pivot.rotation.y = sweep
	var reach: float = float(S_["range"])
	var half: float = deg_to_rad(float(S_["cone_deg"]))
	_search_cone.rotation.x = PI / 2
	_search_cone.scale = Vector3(tan(half) * reach, reach, tan(half) * reach)
	_search_cone.position = Vector3(0, 0, reach * 0.5)
	if not _search_bark_done and _search_t > 1.0:
		_search_bark_done = true
		VOManager.play(str(R["lines"]["first_searchlight"]))
	if _spot_cd > 0.0 or target == null or spotted:
		return
	var origin: Vector3 = _search_pivot.global_position
	var axis: Vector3 = _search_pivot.global_basis.z
	axis.y = 0.0
	var to: Vector3 = target_center() - origin
	var flat: Vector3 = Vector3(to.x, 0, to.z)
	if flat.length() < reach and axis.length_squared() > 0.0 and flat.angle_to(axis) < half and EnemyFx.los_clear(self, origin, target_center()):
		spotted = true
		spots += 1
		_spot_cd = float(S_["cooldown"])
		log_parallel(&"searchlight", float(S_["spot_chime"]), &"spotted_chime")
		EventBus.hint.emit(line_text(str(R["lines"]["spotted_hint"])), "sentinel_spotted")


## The current sweep direction (tests point Bolt into it).
func searchlight_dir() -> Vector3:
	var a: Vector3 = _search_pivot.global_basis.z
	a.y = 0.0
	return a.normalized()


func _idle_tick(dt: float) -> void:
	face(target_pos() - global_position, dt, float(R["turn_idle"]))
	var to: Vector3 = target_pos() - global_position
	to.y = 0.0
	if to.length() > float(R["hold_distance"]) and can_move():
		desired_vel = to.normalized() * ph(R["move_speed"]) * move_mult()
	else:
		desired_vel = Vector3.ZERO


func _allowed(kind: StringName) -> bool:
	return kind != &"ram" or phase >= 3


func _pick() -> StringName:
	if phase >= 3 and _last == &"beam":
		return &"ram"
	return &"beam"


func _start(kind: StringName) -> void:
	_last = kind
	match kind:
		&"ram":
			var f: Vector3 = target_pos() - global_position
			f.y = 0.0
			_ram_dir = f.normalized() if f.length_squared() > 0.01 else forward()
			begin_telegraph(&"ram", float(R["ram"]["tele"]))
			EnemyFx.lane(get_parent(), global_position, _ram_dir, float(R["ram"]["lane_len"]), float(R["ram"]["lane_w"]), tele_dur, Color("#ff5d5d"))
			tele_light.light_color = Color("#ff5d5d")
		_:
			begin_telegraph(&"beam", ph(R["beam"]["tele"]))
			tele_light.light_color = Color("#ff5d2e")


func _tele_tick(kind: StringName, dt: float) -> void:
	if kind == &"beam":
		var k: float = 1.0 - clampf(tele_t / maxf(tele_dur, 0.01), 0.0, 1.0)
		_muzzle_mat.emission_energy_multiplier = k * 3.0
		var a: Vector3 = muzzle_pos()
		var d: Vector3 = _turret_dir()
		var L: float = float(R["beam"]["length"])
		_guide = EnemyFx.segment(get_parent() as Node3D if get_parent() is Node3D else self, _guide, a, _beam_end(a, d, L), 0.06, Color("#ff5d2e"))
		_guide.visible = true
		if phase >= 2:
			var d2: Vector3 = d.rotated(Vector3.UP, deg_to_rad(float(R["beam"]["twin_deg"])))
			_guide2 = EnemyFx.segment(get_parent() as Node3D if get_parent() is Node3D else self, _guide2, a, _beam_end(a, d2, L), 0.06, Color("#c06aff"))
			_guide2.visible = true
	elif kind == &"ram":
		face(_ram_dir, dt, 4.0)


func _beam_end(a: Vector3, d: Vector3, L: float) -> Vector3:
	var to: Vector3 = a + d * L
	if not is_inside_tree():
		return to
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(a, to, 1 | (1 << 5))
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else to


func _hide_guides() -> void:
	if _guide != null and is_instance_valid(_guide):
		_guide.visible = false
	if _guide2 != null and is_instance_valid(_guide2):
		_guide2.visible = false


func _attack_start(kind: StringName) -> void:
	match kind:
		&"beam":
			_hide_guides()
			_muzzle_mat.emission_energy_multiplier = 4.0
			var B: Dictionary = R["beam"]
			var a: Vector3 = muzzle_pos()
			var d: Vector3 = _turret_dir()
			EnemyBeam.fire(get_parent(), a, d, float(B["length"]), float(B["r"]), float(B["dmg"]) * out_mult(), float(B["life"]), Color("#ff5d2e"), self)
			if phase >= 2:
				EnemyBeam.fire(get_parent(), a, d.rotated(Vector3.UP, deg_to_rad(float(B["twin_deg"]))), float(B["length"]), float(B["twin_r"]),
					float(B["twin_dmg"]) * out_mult(), float(B["life"]), Color("#c06aff"), self)
				_record(&"twin_beam", tele_dur)
		&"ram":
			contact_cd = 0.0


func _attack_tick(kind: StringName, dt: float) -> bool:
	match kind:
		&"beam":
			return state_t >= float(R["beam"]["life"])
		&"ram":
			var RM: Dictionary = R["ram"]
			desired_vel = _ram_dir * float(RM["speed"])
			face(_ram_dir, dt, 6.0)
			if contact_cd <= 0.0 and target_alive() and flat_dist_to_target() < radius + 1.2:
				contact_cd = 1.2
				hurt_target(float(RM["dmg"]), float(RM["knock"]))
			var pil: Node3D = _pillar_hit()
			if pil != null:
				desired_vel = Vector3.ZERO
				ram_stuns += 1
				self_stun(float(RM["stun"]), float(RM["stun_break_frac"]), &"ram_stun")
				return false
			if (state_t > 0.15 and is_on_wall()) or _out_of_arena() or state_t >= float(RM["time"]):
				return true
			return false
	return true


func _pillar_hit() -> Node3D:
	for p: Node3D in anchors("Pillar"):
		if not p.is_inside_tree():
			continue
		var pr: float = float(p.get_meta(&"radius", 1.6))
		var d: Vector2 = Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z)
		if d.length() < pr + radius + 0.4:
			return p
	return null


func _out_of_arena() -> bool:
	var dx: float = absf(global_position.x - arena_mid.x)
	var dz: float = absf(global_position.z - arena_mid.z)
	return dx > arena_size.x * 0.5 - radius or dz > arena_size.y * 0.5 - radius


func _idle_after(kind: StringName) -> float:
	var r: Array = R["idle"][clampi(phase - 1, 0, 2)]
	if kind == &"ram":
		return float(R["ram"]["idle_after"])
	return randf_range(float(r[0]), float(r[1]))


func _pattern_cancelled() -> void:
	_hide_guides()
	_muzzle_mat.emission_energy_multiplier = 0.0


# ------------------------------------------------------------------ weak points / feeders

func weak_point_exposed() -> bool:
	return true


func _weak_point_pos() -> Vector3:
	return core_pos() if _core != null else get_center()


func is_weak_point(point: Vector3) -> bool:
	if super.is_weak_point(point):
		return true
	return _in_beam_tele() and point != Vector3.ZERO and point.distance_to(muzzle_pos()) < float(R["beam"]["muzzle_r"])


func _in_beam_tele() -> bool:
	return state == State.TELEGRAPH and attack_kind == &"beam"


func _accepts_hit(hit: Combat.Hit) -> bool:
	_hit_in_beam_tele = _in_beam_tele() and hit.point != Vector3.ZERO and hit.point.distance_to(muzzle_pos()) < float(R["beam"]["muzzle_r"])
	return true


func _boss_on_hurt(_hit: Combat.Hit, _amount: float, _crit: bool) -> void:
	if _hit_in_beam_tele:
		_hit_in_beam_tele = false
		muzzle_shots += 1
		if state == State.TELEGRAPH:
			cancel_attack()
			idle_t = maxf(idle_t, 1.0)
		add_break(break_threshold() * float(R["beam"]["muzzle_break_frac"]))
		telegraphed.emit(&"muzzle_shot", &"boss_clank", 0.0)


func _on_phase(p: int) -> void:
	var L: Dictionary = R["lines"]
	if p == 2:
		plates_blown = true
		for pl: MeshInstance3D in _plates:
			if pl.visible:
				pl.visible = false
				EnemyFx.chunks(get_parent(), pl.global_position, Color("#9c5a3a"), 1.0, 3, 4)
		banner_lines(L["phase2_banner"], 2.0)
		VOManager.play(str(L["phase2"]))
		_search_t = 0.0
	elif p == 3:
		banner_lines(L["phase3_banner"], 2.0)
		VOManager.play(str(L["phase3"]))
		var spots_: Array[Node3D] = anchors("AddSpawn")
		var A: Dictionary = R["adds"]
		for i: int in int(A["count"]):
			var at: Vector3 = _gpos(spots_[i % spots_.size()]) if not spots_.is_empty() else global_position + Vector3((i * 2 - 1) * 5.0, 0.3, 4.0)
			spawn_add(StringName(str(A["id"])), at)
		_last = &"beam"                         # treads engage: the next pick is a ram


func _pattern_died(_hit: Combat.Hit) -> void:
	_hide_guides()
	_search_cone.visible = false


func _anim(_delta: float) -> void:
	_core_mat.emission_energy_multiplier = 2.0 + sin(t * 5.0) * 0.8
	if state != State.TELEGRAPH and state != State.ATTACK:
		_muzzle_mat.emission_energy_multiplier = 0.0
