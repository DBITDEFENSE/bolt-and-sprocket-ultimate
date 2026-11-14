class_name ShermanTank
extends Node3D
## The Sherman itself (T-249): the model (ShermanMesh) on a rig that drives, steers, turns its turret, lays its gun,
## runs its tracks and wheels, fires (the 75 mm and the machine gun, with flash, tracers, smoke, sound and impacts),
## takes the dead's blows and a fire zombie's burst, and burns as a wreck. ShermanEvent owns it and decides; on a
## co-op client it is a puppet that follows the host's mirrored state (net_*).
## Its hull collider is on the map-edge layer (bit 11): players and bots are stopped by it, zombies, shots and blasts
## pass, so nothing baked or any zombie's path changes (the horse rail's rule, T-240).

signal wrecked

enum Mode { DRIVE, PARKED, WRECK }

const LAYER_EDGE: int = 1 << 10
const MASK_LOS: int = 1

var cfg: Dictionary = {}               # sherman.json "tank"
var acfg: Dictionary = {}              # sherman.json "assist"
var puppet: bool = false
var mode: Mode = Mode.PARKED
var max_hp: float = 8000.0
var hp: float = 8000.0
var attackable: bool = false           # the round-30 assault is on
var assisting: bool = false            # rounds 31..39 (and the rest of round 30 once it holds)
var speed: float = 0.0
var route: PackedVector3Array = PackedVector3Array()
var route_i: int = 0
var swipes_taken: int = 0
var damage_taken: float = 0.0
var shots_main: int = 0
var shots_mg: int = 0
var mg_hits: int = 0
var kills: int = 0

var body: Node3D
var turret: Node3D
var gun: Node3D
var _gun_mesh: Node3D
var _wheels: Array[Node3D] = []
var _spin: Array = []                  # [node, radius]
var _links: Array[MultiMesh] = []
var _path: PackedVector2Array
var _path_cum: PackedFloat32Array
var _path_len: float = 1.0
var _track_s: float = 0.0
var _n_links: int = 0
var _collider: AnimatableBody3D
var points: Array[ShermanAttackPoint] = []
var _engine: AudioStreamPlayer3D
var _tracks_snd: AudioStreamPlayer3D
var _fire_snd: AudioStreamPlayer3D
var _exhaust: Node3D
var _turret_yaw_target: float = 0.0
var _gun_pitch_target: float = 0.0
var _recoil: float = 0.0
var _rock: float = 0.0
var _rock_v: float = 0.0
var _mg_t: float = 0.0
var _mg_left: int = 0
var _mg_shot_t: float = 0.0
var _mg_target: Zombie = null
var _gun_t: float = 4.0
var _gun_target: Vector3 = Vector3.INF
var _scan_t: float = 0.0
var _net_t: float = 0.0
var _net_from: Transform3D
var _net_to: Transform3D
var _net_lerp: float = 1.0
var _wreck_light: OmniLight3D
var _flick_t: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	name = "Sherman"
	_rng.randomize()


func _ready() -> void:
	add_to_group(&"sherman")
	if body == null:
		build()


# ================================================================== the model

func build() -> void:
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	body.add_child(ShermanMesh.instance("hull"))
	turret = Node3D.new()
	turret.name = "Turret"
	turret.position = ShermanMesh.TURRET_AT
	body.add_child(turret)
	turret.add_child(ShermanMesh.instance("turret"))
	gun = Node3D.new()
	gun.name = "Gun"
	gun.position = ShermanMesh.GUN_AT
	turret.add_child(gun)
	_gun_mesh = ShermanMesh.instance("gun")
	gun.add_child(_gun_mesh)
	for s: float in [-1.0, 1.0]:
		var x: float = s * ShermanMesh.TRACK_X
		for c: Vector3 in ShermanMesh.wheel_centres():
			_spun("wheel", Vector3(x, c.y, c.z), ShermanMesh.WHEEL_R, s)
		for c2: Vector3 in ShermanMesh.roller_centres():
			_spun("roller", Vector3(x, c2.y, c2.z), ShermanMesh.ROLLER_R, s)
		_spun("sprocket", Vector3(x, ShermanMesh.SPROCKET.y, ShermanMesh.SPROCKET.z), ShermanMesh.SPROCKET_R, s)
		_spun("idler", Vector3(x, ShermanMesh.IDLER.y, ShermanMesh.IDLER.z), ShermanMesh.IDLER_R, s)
	# the tracks: one MultiMesh of links per side, moved along the loop
	_path = ShermanMesh.track_path()
	_path_cum = PackedFloat32Array()
	var acc: float = 0.0
	for i: int in _path.size():
		_path_cum.append(acc)
		acc += _path[i].distance_to(_path[(i + 1) % _path.size()])
	_path_len = acc
	_n_links = int(floor(_path_len / ShermanMesh.LINK_PITCH))
	var lm: Array = ShermanMesh.part("link")
	for s2: float in [-1.0, 1.0]:
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = lm[0]
		mm.instance_count = _n_links
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.name = "TrackL" if s2 < 0.0 else "TrackR"
		mmi.multimesh = mm
		mmi.material_override = ShermanMesh.material("steel")
		mmi.position = Vector3(s2 * ShermanMesh.TRACK_X, 0, 0)
		body.add_child(mmi)
		_links.append(mm)
	_lay_links()
	# the hull's collider: the map-edge layer only (players and bots stop, zombies and shots pass)
	_collider = AnimatableBody3D.new()
	_collider.name = "HullBody"
	_collider.sync_to_physics = false
	_collider.collision_layer = LAYER_EDGE
	_collider.collision_mask = 0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bx: BoxShape3D = BoxShape3D.new()
	bx.size = Vector3(2.62, 1.75, 5.9)
	cs.shape = bx
	cs.position = Vector3(0, 1.0, -0.05)
	_collider.add_child(cs)
	var cs2: CollisionShape3D = CollisionShape3D.new()
	var bx2: BoxShape3D = BoxShape3D.new()
	bx2.size = Vector3(1.9, 0.85, 2.1)
	cs2.shape = bx2
	cs2.position = ShermanMesh.TURRET_AT + Vector3(0, 0.42, 0.1)
	_collider.add_child(cs2)
	add_child(_collider)
	# where the dead stand to hit it: along each side, two at the bow, two at the stern, 0.6 m inside the hull's edge
	var n: int = maxi(4, int(cfg.get("attack_points", 10)))
	var spots: Array[Vector3] = []
	var per_side: int = maxi(1, (n - 4) / 2)
	for s3: float in [-1.0, 1.0]:
		for k: int in per_side:
			var z: float = lerpf(-2.0, 2.1, (float(k) + 0.5) / float(per_side))
			spots.append(Vector3(s3 * (1.31 - 0.6), 0, z))
		spots.append(Vector3(s3 * 0.6, 0, -2.9 + 0.6))
		spots.append(Vector3(s3 * 0.6, 0, 2.95 - 0.6))
	for sp: Vector3 in spots:
		var ap: ShermanAttackPoint = ShermanAttackPoint.new()
		ap.name = "AttackPoint%d" % points.size()
		ap.tank = self
		ap.position = sp
		add_child(ap)
		points.append(ap)
	# the engine and the tracks, the exhaust
	_engine = AudioDirector.make_loop_3d("sherman_engine", body, -2.0)
	if _engine != null:
		_engine.position = Vector3(0, 1.5, 2.0)
	_tracks_snd = AudioDirector.make_loop_3d("sherman_tracks", body, -60.0)
	if _tracks_snd != null:
		_tracks_snd.position = Vector3(0, 0.6, 0)
	_exhaust = Node3D.new()
	_exhaust.name = "Exhaust"
	_exhaust.position = Vector3(0, 0.75, 3.05)
	body.add_child(_exhaust)
	# the crew's lamp through the open cupola: a warm glow over the turret roof and the deck, so the tank reads at night
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.name = "CrewLamp"
	lamp.position = Vector3(0.40, 1.05, 0.32)
	lamp.light_color = Color(1.0, 0.78, 0.5)
	lamp.light_energy = 1.4
	lamp.omni_range = 7.0
	lamp.shadow_enabled = false
	turret.add_child(lamp)


func _spun(part_name: String, at: Vector3, radius: float, side: float) -> void:
	var mi: MeshInstance3D = ShermanMesh.instance(part_name)
	var holder: Node3D = Node3D.new()
	holder.name = "%s_%d" % [part_name, _spin.size()]
	holder.position = at
	if side < 0.0:
		holder.rotation.y = PI   # the outboard face out on the left side too
	holder.add_child(mi)
	body.add_child(holder)
	_spin.append([mi, radius, side])


## The link transforms along the loop for the current track offset.
func _lay_links() -> void:
	if _links.is_empty() or _n_links <= 0:
		return
	var j: int = 0
	for i: int in _n_links:
		var s: float = fposmod(float(i) * ShermanMesh.LINK_PITCH + _track_s, _path_len)
		while j > 0 and _path_cum[j] > s:
			j -= 1
		while j < _path.size() - 1 and _path_cum[j + 1] <= s:
			j += 1
		var a: Vector2 = _path[j]
		var b: Vector2 = _path[(j + 1) % _path.size()]
		var seg: float = maxf(1e-5, a.distance_to(b))
		var p: Vector2 = a.lerp(b, (s - _path_cum[j]) / seg)
		var t2: Vector2 = (b - a) / seg
		var t3: Vector3 = Vector3(0, t2.y, t2.x)
		var n3: Vector3 = Vector3(0, -t2.x, t2.y)
		var xf: Transform3D = Transform3D(Basis(n3.cross(t3), n3, t3), Vector3(0, p.y, p.x))
		for mm: MultiMesh in _links:
			mm.set_instance_transform(i, xf)


# ================================================================== state

func setup(tank_cfg: Dictionary, assist_cfg: Dictionary, health: float) -> void:
	cfg = tank_cfg
	acfg = assist_cfg
	max_hp = maxf(1.0, health)
	hp = max_hp


func hp_fraction() -> float:
	return clampf(hp / max_hp, 0.0, 1.0)


func can_be_attacked() -> bool:
	return attackable and mode != Mode.WRECK and hp > 0.0


func is_wreck() -> bool:
	return mode == Mode.WRECK


## The hull's flat footprint test: is `p` within `m` of the hull (a fire zombie's fuse, the tank's own blind zone)?
func near_hull(p: Vector3, m: float) -> bool:
	var l: Vector3 = global_transform.affine_inverse() * p
	return absf(l.x) <= 1.31 + m and l.z >= -2.97 - m and l.z <= 3.05 + m


func yaw() -> float:
	return rotation.y


## Drives along `pts` (world points on the ground), then parks facing the last leg.
func drive(pts: PackedVector3Array) -> void:
	route = pts
	route_i = 1
	if pts.size() >= 2:
		global_position = pts[0]
		var d: Vector3 = pts[1] - pts[0]
		rotation.y = atan2(-d.x, -d.z)
	mode = Mode.DRIVE
	speed = 0.0
	if _engine != null and not _engine.playing:
		_engine.play()
	if _tracks_snd != null and not _tracks_snd.playing:
		_tracks_snd.play()
	_set_exhaust(true)


func park_at(p: Vector3, yaw_rad: float) -> void:
	global_position = p
	rotation.y = yaw_rad
	mode = Mode.PARKED
	speed = 0.0
	if _engine != null and not _engine.playing:
		_engine.play()
	_set_exhaust(true)


func parked() -> bool:
	return mode == Mode.PARKED


func _set_exhaust(on: bool) -> void:
	if _exhaust == null:
		return
	for c: Node in _exhaust.get_children():
		c.queue_free()
	if on and not puppet_headless():
		Props.smoke(_exhaust, Vector3.ZERO, 0.25, 0.6, 10)


static func puppet_headless() -> bool:
	return DisplayServer.get_name() == "headless"


# ================================================================== the frame

func _physics_process(delta: float) -> void:
	if mode == Mode.WRECK:
		_flicker(delta)
		return
	if puppet:
		_puppet_step(delta)
	elif mode == Mode.DRIVE:
		_drive_step(delta)
	if assisting and not puppet and mode == Mode.PARKED:
		_assist_step(delta)
	_aim_step(delta)
	_running_gear(delta)


func _drive_step(delta: float) -> void:
	if route_i >= route.size():
		mode = Mode.PARKED
		speed = 0.0
		return
	var target: Vector3 = route[route_i]
	var to: Vector3 = target - global_position
	to.y = 0.0
	var last: bool = route_i == route.size() - 1
	var dist: float = to.length()
	if dist < (0.25 if last else 2.2):
		route_i += 1
		if route_i >= route.size():
			global_position = Vector3(target.x, global_position.y, target.z)
			mode = Mode.PARKED
			speed = 0.0
			_rock_v -= 0.6   # the nose dips as it stops
		return
	var want_yaw: float = atan2(-to.x, -to.z)
	var dy: float = wrapf(want_yaw - rotation.y, -PI, PI)
	var turn: float = deg_to_rad(float(cfg.get("turn_rate_deg", 40.0)))
	rotation.y += clampf(dy, -turn * delta, turn * delta)
	var top: float = float(cfg.get("drive_speed", 3.2))
	var want: float = top * clampf(1.0 - absf(dy) / 1.2, 0.25, 1.0)
	if last:
		want = minf(want, maxf(0.6, dist * 0.8))
	var accel: float = 1.6 if want > speed else 2.4
	var before: float = speed
	speed = move_toward(speed, want, accel * delta)
	_rock_v += (before - speed) * 0.4
	var fwd: Vector3 = -global_transform.basis.z
	global_position += fwd * speed * delta
	global_position.y = target.y


func _running_gear(delta: float) -> void:
	var v: float = speed
	if absf(v) > 0.01:
		_track_s += v * delta
		_lay_links()
		for e: Array in _spin:
			var mi: Node3D = e[0]
			mi.rotation.x -= v * delta / float(e[1]) * float(e[2])
		if Engine.get_physics_frames() % 15 == 0:
			for s: float in [-1.0, 1.0]:
				Effects.dust_puff(global_transform * Vector3(s * ShermanMesh.TRACK_X, 0.1, 2.7), "snow", 8)
	if _tracks_snd != null:
		_tracks_snd.volume_db = lerpf(-40.0, -3.0, clampf(absf(v) / 2.5, 0.0, 1.0))
	if _engine != null:
		_engine.pitch_scale = 1.0 + 0.25 * clampf(absf(v) / 3.0, 0.0, 1.0)
	# the hull rocks on its springs when it starts, stops or fires; idles with a shiver
	_rock_v += -_rock * 40.0 * delta - _rock_v * 6.0 * delta
	_rock += _rock_v * delta
	body.rotation.x = _rock * 0.05
	body.position.y = 0.004 * sin(float(Engine.get_physics_frames()) * 0.9) if mode != Mode.WRECK else 0.0
	if _recoil > 0.0:
		_recoil = maxf(0.0, _recoil - delta * 0.9)
		_gun_mesh.position.z = 0.32 * smoothstep(0.0, 0.35, _recoil)


func _aim_step(delta: float) -> void:
	var tr: float = deg_to_rad(float(cfg.get("turret_rate_deg", 28.0)))
	var gr: float = deg_to_rad(float(cfg.get("gun_rate_deg", 12.0)))
	var dy: float = wrapf(_turret_yaw_target - turret.rotation.y, -PI, PI)
	turret.rotation.y += clampf(dy, -tr * delta, tr * delta)
	gun.rotation.x = move_toward(gun.rotation.x, _gun_pitch_target, gr * delta)


## Lays the turret and the gun on a world point.
func aim_world(p: Vector3) -> void:
	var o: Vector3 = gun.global_position
	var d: Vector3 = p - o
	var world_yaw: float = atan2(-d.x, -d.z)
	_turret_yaw_target = wrapf(world_yaw - global_rotation.y, -PI, PI)
	var flat: float = Vector2(d.x, d.z).length()
	_gun_pitch_target = clampf(atan2(d.y, maxf(0.1, flat)), deg_to_rad(-10.0), deg_to_rad(25.0))


func aim_home() -> void:
	_turret_yaw_target = 0.0
	_gun_pitch_target = 0.0


## True when the gun points within `tol_deg` of `p`.
func aimed_at(p: Vector3, tol_deg: float) -> bool:
	var fwd: Vector3 = -gun.global_transform.basis.z
	var d: Vector3 = (p - gun.global_position).normalized()
	return rad_to_deg(fwd.angle_to(d)) <= tol_deg


func muzzle() -> Vector3:
	return gun.global_transform * Vector3(0, 0, -ShermanMesh.GUN_LEN - 0.05)


func coax() -> Vector3:
	return gun.global_transform * ShermanMesh.COAX_AT


# ================================================================== damage

## A zombie's swipe (ShermanAttackPoint.struck).
func take_swipe(by: Node, at: Vector3) -> void:
	if not can_be_attacked():
		return
	swipes_taken += 1
	var dmg: float = float(cfg.get("swipe_damage", 30))
	var z: Zombie = by as Zombie
	if z != null and z.tier == &"sprint":
		dmg *= float(cfg.get("sprint_swipe_mult", 1.0))
	if Engine.get_physics_frames() % 3 == 0 or swipes_taken % 3 == 0:
		AudioDirector.play_3d("sherman_clang", at + Vector3.UP * 1.1, -2.0)
	take_damage(dmg)


func take_damage(amount: float) -> void:
	if puppet or mode == Mode.WRECK or amount <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	damage_taken += amount
	if hp <= 0.0:
		wreck(true)


# ================================================================== the assist (host)

## Rounds 31..39: the machine gun on the nearest of the dead it can see, the 75 mm on a pack of them or one far off.
## Damage is a fraction of the round's zombie health; it never fires at or near a player and pays no Scrip.
func _assist_step(delta: float) -> void:
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	if dir == null:
		return
	_scan_t -= delta
	_gun_t -= delta
	_mg_t -= delta
	var rh: float = float(RoundManager.current_health())
	if _scan_t <= 0.0:
		_scan_t = 0.35
		_choose_targets(dir)
	# the machine gun: a burst, then a gap
	if _mg_left > 0:
		_mg_shot_t -= delta
		if _mg_shot_t <= 0.0:
			_mg_shot_t = 1.0 / maxf(1.0, float(acfg.get("mg_rate", 9.0)))
			_mg_left -= 1
			_mg_shot(rh)
	elif _mg_t <= 0.0 and _mg_target != null and is_instance_valid(_mg_target) and _mg_target.is_active():
		_mg_left = int(acfg.get("mg_burst", 7))
		_mg_t = float(acfg.get("mg_gap", 2.2)) + float(_mg_left) / maxf(1.0, float(acfg.get("mg_rate", 9.0)))
	# the main gun
	if _gun_target != Vector3.INF:
		aim_world(_gun_target)
		if _gun_t <= 0.0 and aimed_at(_gun_target, float(acfg.get("aim_tolerance_deg", 3.0))):
			_gun_t = float(acfg.get("gun_interval", 11.0))
			fire_main(_gun_target, rh)
			_gun_target = Vector3.INF
	elif _mg_target != null and is_instance_valid(_mg_target):
		aim_world(_mg_target.global_position + Vector3.UP * 1.0)


func _visible(from: Vector3, to: Vector3) -> bool:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, MASK_LOS)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _near_player(p: Vector3, m: float) -> bool:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var pl: Player = n as Player
		if pl != null and pl.is_alive() and pl.global_position.distance_to(p) < m:
			return true
	return false


func _choose_targets(dir: ZombieDirector) -> void:
	var rng_m: float = float(acfg.get("range", 45.0))
	var eye: Vector3 = global_transform * Vector3(0, 2.4, -0.3)
	var seen: Array[Zombie] = []
	for z: Zombie in dir.active_zombies():
		if not z.is_active() or z.state == Zombie.State.EMERGE or z.state == Zombie.State.DEAD:
			continue
		var d: float = z.global_position.distance_to(global_position)
		if d > rng_m or near_hull(z.global_position, float(acfg.get("mg_min_m", 3.5)) - 1.3):   # (hugging the hull: under the guns)
			continue
		if not _visible(eye, z.global_position + Vector3.UP * 1.1):
			continue
		seen.append(z)
	_mg_target = null
	var best: float = INF
	for z2: Zombie in seen:
		var d2: float = z2.global_position.distance_to(global_position)
		if d2 < best:
			best = d2
			_mg_target = z2
	if _gun_target != Vector3.INF or _gun_t > 1.5:
		return
	# the 75 mm: a pack (gun_cluster within gun_cluster_m) or one far off, never within gun_player_clear_m of a player
	var cm: float = float(acfg.get("gun_cluster_m", 4.0))
	var best_n: int = 0
	var pick: Vector3 = Vector3.INF
	for z3: Zombie in seen:
		var c: int = 0
		for z4: Zombie in seen:
			if z4.global_position.distance_to(z3.global_position) <= cm:
				c += 1
		var far: bool = z3.global_position.distance_to(global_position) >= float(acfg.get("gun_lone_m", 18.0))
		if (c >= int(acfg.get("gun_cluster", 2)) or far) and c > best_n and not _near_player(z3.global_position, float(acfg.get("gun_player_clear_m", 5.0))):
			best_n = c
			pick = z3.global_position + Vector3.UP * 0.6
	_gun_target = pick


func _mg_shot(round_health: float) -> void:
	if _mg_target == null or not is_instance_valid(_mg_target) or not _mg_target.is_active():
		_mg_left = 0
		return
	var from: Vector3 = coax()
	var aim: Vector3 = _mg_target.global_position + Vector3.UP * _rng.randf_range(0.8, 1.5)
	var hit: bool = _rng.randf() < float(acfg.get("mg_hit_chance", 0.8))
	var to: Vector3 = aim if hit else aim + Vector3(_rng.randf_range(-1.2, 1.2), _rng.randf_range(-1.0, 0.2), _rng.randf_range(-1.2, 1.2))
	shots_mg += 1
	fire_mg_fx(from, to, hit)
	if Net.replicating():
		Net.mirror(self, &"fire_mg_fx", [from, to, hit])
	if hit:
		mg_hits += 1
		if _mg_target.take_damage(round_health * float(acfg.get("mg_damage_frac", 0.03)), &"torso", &"sherman_mg", 0, &"bullet"):
			kills += 1


func fire_mg_fx(from: Vector3, to: Vector3, hit: bool) -> void:
	Effects.tracer(from, to, false, &"lmg")
	if shots_mg % 2 == 0 or puppet:
		Effects.muzzle_flash(from, (to - from).normalized(), &"m1919", false, 1.0, shots_mg % 4 == 0)
	AudioDirector.play_3d("fire_m1919", from, -3.0)
	if hit:
		Effects.zombie_hit(to, (to - from).normalized(), &"m1919", false)
	else:
		Effects.dust_puff(Vector3(to.x, maxf(0.05, to.y - 1.0), to.z), "snow", 6)


## The 75 mm: one HE shell at `at` (host): the flash, the recoil, the shell, the burst; damage to the dead only.
func fire_main(at: Vector3, round_health: float) -> void:
	shots_main += 1
	var from: Vector3 = muzzle()
	var to: Vector3 = at
	# the shell bursts where it first meets the world or the target
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, at + (at - from).normalized() * 3.0, MASK_LOS)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and (hit["position"] as Vector3).distance_to(from) < from.distance_to(at):
		to = hit["position"]
	fire_main_fx(from, to)
	if Net.replicating():
		Net.mirror(self, &"fire_main_fx", [from, to])
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	if dir == null:
		return
	var r: float = float(acfg.get("gun_radius", 6.0))
	var inner: float = float(acfg.get("gun_inner_m", 2.0))
	for z: Zombie in dir.active_zombies():
		if not z.is_active():
			continue
		var d: float = z.global_position.distance_to(to)
		if d > r:
			continue
		var k: float = 1.0 if d <= inner else clampf(1.0 - (d - inner) / maxf(0.01, r - inner), 0.0, 1.0)
		var dmg: float = round_health * lerpf(float(acfg.get("gun_damage_edge_frac", 0.15)), float(acfg.get("gun_damage_frac", 0.7)), k)
		if z.take_damage(dmg, &"torso", &"sherman_75", 0, &"explosive"):
			kills += 1


func fire_main_fx(from: Vector3, to: Vector3) -> void:
	_recoil = 0.35
	_rock_v += 1.6
	var dirv: Vector3 = (to - from).normalized()
	Effects.muzzle_flash(from, dirv, &"m1_garand", false, 6.0, true)
	BossFx.burst("smoke", from + dirv * 0.6, get_tree(), 1.6, 2.2)
	BossFx.burst("sparks", from, get_tree(), 0.8, 1.2)
	Effects.dust_puff(global_transform * Vector3(0, 0.1, -3.4), "snow", 30)
	AudioDirector.play_3d("sherman_gun", from, 2.0)
	Effects.tracer(from, to, false, &"launcher")
	var tree: SceneTree = get_tree()
	var travel: float = clampf(from.distance_to(to) / 600.0, 0.02, 0.2)
	tree.create_timer(travel).timeout.connect(func() -> void:
		Effects.explosion(to, 4.5)
		Effects.dirt_burst(to, "snow", 2.0, Vector3.UP, 30)
		Effects.dirt_burst(to, "earth", 1.6, Vector3.UP, 18)
		BossFx.burst("smoke", to + Vector3.UP * 0.5, tree, 1.2, 2.0)
		AudioDirector.play_3d("war_artillery_near", to, 2.0)
		ShermanEvent.shake_players(tree, to, 0.45, 22.0))


# ================================================================== the wreck

## It brews up: the blast, the turret knocked askew on its ring, the paint burnt off, fire out of the hatches and
## the engine deck, a column of smoke, the ammunition cooking off. It stays where it is.
func wreck(explode: bool) -> void:
	if mode == Mode.WRECK:
		return
	mode = Mode.WRECK
	attackable = false
	assisting = false
	speed = 0.0
	hp = 0.0
	if _engine != null:
		_engine.stop()
	if _tracks_snd != null:
		_tracks_snd.stop()
	var lamp: Node = turret.get_node_or_null("CrewLamp")
	if lamp != null:
		lamp.queue_free()
	_set_exhaust(false)
	for mi: Node in find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		var mk: Array = []
		for part_name: String in ["hull", "turret", "gun", "wheel", "sprocket", "idler", "roller"]:
			if m.mesh == (ShermanMesh.part(part_name)[0] as Mesh):
				mk = ShermanMesh.part(part_name)
		if mk.is_empty():
			continue
		for i: int in (mk[1] as Array).size():
			m.set_surface_override_material(i, ShermanMesh.material(str((mk[1] as Array)[i]), true))
	for mmi: Node in find_children("Track*", "MultiMeshInstance3D", true, false):
		(mmi as MultiMeshInstance3D).material_override = ShermanMesh.material("steel", true)
	turret.rotation = Vector3(deg_to_rad(-6.0), turret.rotation.y + deg_to_rad(28.0), deg_to_rad(7.0))
	turret.position = ShermanMesh.TURRET_AT + Vector3(0.12, 0.14, 0.05)
	gun.rotation.x = deg_to_rad(-9.0)
	body.rotation.x = 0.0
	if explode:
		var at: Vector3 = global_transform * Vector3(0, 1.6, 0)
		Effects.explosion(at, 7.0)
		Effects.scorch(global_position + Vector3.UP * 0.05, 5.0)
		BossFx.burst("sparks", at, get_tree(), 3.0, 2.0)
		BossFx.burst("embers", at, get_tree(), 3.0, 2.0)
		BossFx.burst("smoke", at + Vector3.UP, get_tree(), 3.0, 3.0)
		AudioDirector.play_3d("explosion_large", at, 6.0)
		get_tree().create_timer(0.8).timeout.connect(func() -> void:
			if is_inside_tree():
				AudioDirector.play_3d("sherman_cookoff", at, 2.0))
		ShermanEvent.shake_players(get_tree(), at, 0.9, 40.0)
	# the fire that stays
	var fire: Node3D = Node3D.new()
	fire.name = "WreckFire"
	body.add_child(fire)
	if not puppet_headless():
		Props.flames(fire, ShermanMesh.TURRET_AT + Vector3(0.3, 0.9, 0.3), 0.9, 1.6, 36)
		Props.flames(fire, Vector3(0.4, 1.95, 1.6), 1.2, 1.2, 30)
		Props.flames(fire, Vector3(-0.5, 1.95, 1.2), 0.8, 0.9, 20)
		Props.smoke(fire, Vector3(0, 2.6, 0.8), 0.6, 2.4, 26)
		Props.embers(fire, Vector3(0, 2.2, 0.8), 1.0, 24)
	_wreck_light = OmniLight3D.new()
	_wreck_light.name = "WreckLight"
	_wreck_light.position = Vector3(0, 2.8, 0.6)
	_wreck_light.light_color = Color(1.0, 0.5, 0.18)
	_wreck_light.light_energy = 3.2
	_wreck_light.omni_range = 11.0
	_wreck_light.shadow_enabled = false
	fire.add_child(_wreck_light)
	_fire_snd = AudioDirector.make_loop_3d("fire_crackle", fire, 2.0)
	if _fire_snd != null:
		_fire_snd.position = Vector3(0, 2.0, 0.8)
		_fire_snd.play()
	wrecked.emit()


func _flicker(delta: float) -> void:
	if _wreck_light == null:
		return
	_flick_t -= delta
	if _flick_t <= 0.0:
		_flick_t = _rng.randf_range(0.05, 0.14)
		_wreck_light.light_energy = _rng.randf_range(2.2, 3.8)


# ================================================================== co-op (the client's puppet)

## Host: the state a client needs, mirrored a few times a second.
func net_state_args() -> Array:
	return [global_position, rotation.y, _turret_yaw_target, _gun_pitch_target, hp_fraction(), int(mode), speed]


func net_state(pos: Vector3, yaw_rad: float, tyaw: float, gpitch: float, frac: float, m: int, spd: float) -> void:
	if not puppet:
		return
	_net_from = global_transform
	_net_to = Transform3D(Basis(Vector3.UP, yaw_rad), pos)
	_net_lerp = 0.0
	_turret_yaw_target = tyaw
	_gun_pitch_target = gpitch
	hp = frac * max_hp
	speed = spd
	if m == int(Mode.WRECK) and mode != Mode.WRECK:
		wreck(true)
	elif m != int(Mode.WRECK):
		mode = m as Mode


func _puppet_step(delta: float) -> void:
	if _net_lerp >= 1.0:
		return
	_net_lerp = minf(1.0, _net_lerp + delta / 0.2)
	global_transform = _net_from.interpolate_with(_net_to, _net_lerp)
