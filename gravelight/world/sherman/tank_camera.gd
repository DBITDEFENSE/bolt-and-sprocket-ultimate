class_name TankCamera
extends Camera3D
## T-278 (the owner, 2026-11-25: "the view on the tank sucks, make it more third person wot style"): the driven
## Sherman's own camera, on the driver's machine only. It replaces the first-person view from the hatch while a
## player is seated (ShermanTank makes it, blends to it and back, and frees it).
##
##   orbit    behind and above the tank on a boom round a pivot over the turret, turned by the player's own look
##            input (Player.look_angles: the mouse and the right stick with their sensitivity and invert-Y), so it is
##            independent of the hull; the boom is cast against the world (a spring arm) and never ends in a wall or
##            the ground; the wheel sets its length (drive "cam_dist_min" .. "cam_dist_max").
##   aim      the screen centre: a ray from the camera to the first thing it meets (the world, or one of the dead
##            near the line). ShermanTank lays the turret and the gun on it at their own rates, so the gun lags.
##   sniper   the wheel past the shortest boom (or the sprint key) puts the view in the gunner's sight at the mantlet,
##            narrowed by "sniper_zoom"; the wheel out (or the key again) leaves it.
##   blend    in and out of the player's first-person camera over the climb's time (mount_s / dismount_s).
## The viewmodel and the hands are on their own render layer (WeaponHolder.VM_LAYER); this camera leaves it out.

const MASK_ARM: int = 1 | (1 << 5) | (1 << 8)   # the world, barricades, doors: what the boom may not pass through
const SIGHT_AT: Vector3 = Vector3(-0.36, 0.17, -0.62)   # the gunner's sight, gun frame: left of the barrel, at the mantlet's face

var tank: ShermanTank = null
var player: Player = null
var cfg: Dictionary = {}               # sherman.json "drive"
var dist: float = 9.0                  # the boom's length asked for (the wheel's)
var dist_shown: float = 9.0            # the boom's length now (shortened by the spring arm, eased back out)
var sniper: bool = false
var blend: float = 0.0                 # 0 = the player's own camera, 1 = this one
var leaving: bool = false
var aim_point: Vector3 = Vector3.ZERO  # where the screen centre meets the world
var gun_point: Vector3 = Vector3.INF   # where the gun is laid (ShermanTank.gun_line_point), for the marker
var _blend_s: float = 0.9
var _dist_before: float = 9.0          # the boom's length when the sight was entered (the sight key gives it back)
var _piv_prev: Vector3 = Vector3.INF
var _piv_cur: Vector3 = Vector3.INF


# ================================================================== the math (pure; test_tank_camera)

## The boom's length kept in its range.
static func clamp_dist(d: float, c: Dictionary) -> float:
	return clampf(d, float(c.get("cam_dist_min", 5.0)), float(c.get("cam_dist_max", 16.0)))


## One notch of the wheel (`notch` +1 in, -1 out) from (`d`, `in_sight`): [boom length, in the sight]. In past the
## shortest boom enters the sight; out of the sight comes back to the shortest boom.
static func zoom(d: float, in_sight: bool, notch: int, c: Dictionary) -> Array:
	var lo: float = float(c.get("cam_dist_min", 5.0))
	var step: float = float(c.get("cam_zoom_step", 1.5))
	if notch > 0:
		if in_sight:
			return [lo, true]
		if d <= lo + 0.01:
			return [lo, true]
		return [clamp_dist(d - step, c), false]
	if notch < 0:
		if in_sight:
			return [lo, false]
		return [clamp_dist(d + step, c), false]
	return [clamp_dist(d, c), in_sight]


## The pad's zoom key (swap_weapon): the next of the boom's preset lengths, round again after the longest.
static func next_preset(d: float, c: Dictionary) -> float:
	var presets: Array = c.get("cam_presets", [6.0, 9.0, 14.0])
	for v: Variant in presets:
		if float(v) > d + 0.25:
			return clamp_dist(float(v), c)
	return clamp_dist(float(presets[0]) if not presets.is_empty() else d, c)


## The view's pitch range in the orbit or the sight (radians, min / max).
static func pitch_range(in_sight: bool, c: Dictionary) -> Vector2:
	if in_sight:
		return Vector2(deg_to_rad(float(c.get("sniper_pitch_min_deg", -20.0))), deg_to_rad(float(c.get("sniper_pitch_max_deg", 25.0))))
	return Vector2(deg_to_rad(float(c.get("cam_pitch_min_deg", -55.0))), deg_to_rad(float(c.get("cam_pitch_max_deg", 18.0))))


## The camera's place on a boom of `d` metres round `pivot`, looking along (`pitch`, `yaw`) through the pivot.
static func orbit_transform(pivot: Vector3, pitch: float, yaw: float, d: float) -> Transform3D:
	var b: Basis = Basis.from_euler(Vector3(pitch, yaw, 0.0))
	return Transform3D(b, pivot + b.z * d)


## The pivot over the turret (world): the turret ring's centre on the hull, raised by cam_pivot_up. It follows the
## hull's place, never its heading (the orbit is the player's).
static func pivot_of(hull_pos: Vector3, hull_yaw: float, c: Dictionary) -> Vector3:
	var ring: Vector3 = Basis(Vector3.UP, hull_yaw) * ShermanMesh.TURRET_AT
	return hull_pos + Vector3(ring.x, ShermanMesh.TURRET_AT.y + float(c.get("cam_pivot_up", 1.9)), ring.z)


## The sight's field of view for a base field of view (the player's FOV setting).
static func sight_fov(base_fov: float, c: Dictionary) -> float:
	var z: float = maxf(1.0, float(c.get("sniper_zoom", 4.0)))
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(base_fov) * 0.5) / z))


## How much slower the look turns in the sight: the ratio of the two views' widths, times the ADS sensitivity.
static func sight_look_mult(base_fov: float, c: Dictionary, ads_sens: float) -> float:
	return clampf(tan(deg_to_rad(sight_fov(base_fov, c)) * 0.5) / tan(deg_to_rad(base_fov) * 0.5) * ads_sens, 0.02, 1.0)


## The boom's length after the spring arm: shortened to `hit` at once, eased back out toward `want` (m/s).
static func arm_step(shown: float, want: float, hit: float, rate: float, delta: float) -> float:
	var target: float = minf(want, hit)
	if target < shown:
		return target
	return move_toward(shown, target, rate * delta)


# ================================================================== life

func _init() -> void:
	name = "TankCamera"
	top_level = true
	near = 0.05
	far = 400.0
	cull_mask = 0xFFFFF & ~WeaponHolder.VM_LAYER


## Starts on `p`'s machine: from their own camera, into the orbit over `seconds`.
func begin(t: ShermanTank, p: Player, c: Dictionary, seconds: float) -> void:
	tank = t
	player = p
	cfg = c
	dist = clamp_dist(float(c.get("cam_dist_start", 9.0)), c)
	dist_shown = dist
	sniper = false
	blend = 0.0
	leaving = false
	_blend_s = maxf(0.05, seconds)
	_piv_prev = Vector3.INF
	_piv_cur = Vector3.INF
	if p.camera != null:
		global_transform = p.camera.global_transform
		fov = p.camera.fov
	_apply_limits()
	# the view starts level-ish behind where they were looking
	p.set_look_pitch(clampf(p.look_angles().x, deg_to_rad(-20.0), deg_to_rad(5.0)))
	make_current()


## Back to the player's camera over `seconds` (0: at once, e.g. down in the hatch).
func end(seconds: float) -> void:
	leaving = true
	if sniper:
		set_sniper(false)
	_blend_s = maxf(0.05, seconds)
	if player != null and is_instance_valid(player):
		player.carry_look_mult = 1.0
		player.carry_sight = false
	if seconds <= 0.0:
		blend = 0.0
		release()


## The player's own view again, everything as it was: their camera current, the look's scale and range, the HUD's
## crosshair (their FOV and the viewmodel were never touched). Frees this camera.
func release() -> void:
	if player != null and is_instance_valid(player):
		player.carry_look_mult = 1.0
		player.carry_pitch_lim = Vector2(deg_to_rad(-88.0), deg_to_rad(88.0))
		player.carry_sight = false
		player.set_look_pitch(clampf(player.look_angles().x, deg_to_rad(-30.0), deg_to_rad(20.0)))
		if player.camera != null and player.is_inside_tree():
			player.camera.make_current()
	if tank != null and is_instance_valid(tank):
		tank.show_gun(true)
	current = false
	player = null
	tank = null
	queue_free()


## The gunner's sight on or off. `back`: leaving it gives the boom its length from before (the sight key); the
## wheel leaves it at the shortest boom instead.
func set_sniper(on: bool, back: bool = false) -> void:
	if on == sniper:
		return
	sniper = on
	if on:
		_dist_before = dist
		dist = clamp_dist(float(cfg.get("cam_dist_min", 5.0)), cfg)
	elif back:
		dist = clamp_dist(_dist_before, cfg)
	if tank != null and is_instance_valid(tank):
		tank.show_gun(not on)   # (this machine only: the barrel would fill the sight)
	_apply_limits()


func wheel(notch: int) -> void:
	if leaving:
		return
	var r: Array = zoom(dist, sniper, notch, cfg)
	dist = float(r[0])
	set_sniper(bool(r[1]))


func _apply_limits() -> void:
	if player == null or not is_instance_valid(player):
		return
	player.carry_pitch_lim = pitch_range(sniper, cfg)
	player.carry_sight = true
	player.carry_look_mult = sight_look_mult(_base_fov(), cfg, GLSettings.get_f("ads_sensitivity")) if sniper else 1.0
	player.set_look_pitch(player.look_angles().x)


func _base_fov() -> float:
	return GLSettings.get_f("fov")


## The physics tick (ShermanTank calls it after the hull moved): the pivot's two last places, for the rendered
## frames between ticks.
func tick_physics() -> void:
	if tank == null or not is_instance_valid(tank):
		return
	var pv: Vector3 = pivot_of(tank.global_position, tank.rotation.y, cfg)
	_piv_prev = _piv_cur if _piv_cur.is_finite() else pv
	_piv_cur = pv
	if _piv_prev.distance_to(_piv_cur) > 2.0:
		_piv_prev = _piv_cur


func _pivot() -> Vector3:
	if not _piv_cur.is_finite():
		return pivot_of(tank.global_position, tank.rotation.y, cfg)
	return _piv_prev.lerp(_piv_cur, Engine.get_physics_interpolation_fraction())


func _process(delta: float) -> void:
	update_view(delta)


## Places the camera for this frame and finds the aim point. Smokes call it directly (a headless run has frames,
## but the order against the physics tick is theirs).
func update_view(delta: float) -> void:
	if tank == null or not is_instance_valid(tank) or player == null or not is_instance_valid(player):
		if is_inside_tree() and not is_queued_for_deletion():
			release()
		return
	if not leaving and GameState.phase == GameState.Phase.PLAYING and not GameState.input_blocked:
		if Input.is_action_just_pressed(&"sprint"):
			set_sniper(not sniper, true)
		if Input.is_action_just_pressed(&"swap_weapon"):
			set_sniper(false)
			dist = next_preset(dist, cfg)
	var la: Vector2 = player.look_angles()
	var pivot: Vector3 = _pivot()
	var xf: Transform3D
	var want_fov: float = _base_fov()
	if sniper:
		xf = Transform3D(Basis.from_euler(Vector3(la.x, la.y, 0.0)), tank.gun.global_transform * SIGHT_AT)
		want_fov = sight_fov(want_fov, cfg)
		dist_shown = clamp_dist(float(cfg.get("cam_dist_min", 5.0)), cfg)
	else:
		var hit: float = _arm_reach(pivot, la)
		dist_shown = arm_step(dist_shown, dist, hit, float(cfg.get("cam_arm_out_mps", 12.0)), delta)
		xf = orbit_transform(pivot, la.x, la.y, dist_shown)
	# the blend with the player's own camera
	blend = move_toward(blend, 0.0 if leaving else 1.0, delta / _blend_s)
	var k: float = smoothstep(0.0, 1.0, blend)
	if k < 1.0 and player.camera != null:
		var own: Transform3D = player.camera.global_transform
		global_transform = Transform3D(own.basis.slerp(xf.basis.orthonormalized(), k).orthonormalized(), own.origin.lerp(xf.origin, k))
		fov = lerpf(player.camera.fov, want_fov, k)
	else:
		global_transform = xf
		fov = want_fov
	aim_point = _aim_ray(xf)
	if leaving and blend <= 0.0:
		release()


## How long the boom may be: a sphere cast from the pivot back along the boom (the world, barricades, doors).
func _arm_reach(pivot: Vector3, la: Vector2) -> float:
	var far_xf: Transform3D = orbit_transform(pivot, la.x, la.y, float(cfg.get("cam_dist_max", 16.0)) + 0.5)
	var sph: SphereShape3D = SphereShape3D.new()
	sph.radius = float(cfg.get("cam_radius", 0.3))
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = sph
	q.transform = Transform3D(Basis.IDENTITY, pivot)
	q.motion = far_xf.origin - pivot
	q.collision_mask = MASK_ARM
	var ex: Array[RID] = []
	if player != null and is_instance_valid(player):
		ex.append(player.get_rid())
	q.exclude = ex
	var r: PackedFloat32Array = get_world_3d().direct_space_state.cast_motion(q)
	var frac: float = r[0] if r.size() > 0 else 1.0
	return maxf(0.6, q.motion.length() * frac - 0.05)


## The screen centre's point: the first of the world or of the dead (within 0.6 m of the line) along the view.
func _aim_ray(xf: Transform3D) -> Vector3:
	var from: Vector3 = xf.origin
	var dirv: Vector3 = -xf.basis.z.normalized()
	var reach: float = float(cfg.get("gun_range", 60.0)) + (0.0 if sniper else dist_shown)
	var ex: Array[RID] = []
	if player != null and is_instance_valid(player):
		ex.append(player.get_rid())
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + dirv * reach, ShermanTank.MASK_LOS, ex)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		reach = from.distance_to(hit["position"])
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector if is_inside_tree() else null
	if dir != null:
		reach = float(tank._first_on_line(dir, from, dirv, reach, 0.6)[1])
	return from + dirv * reach


## True when the barrel points within `tol_deg` of the aim point (whatever its line meets first).
func gun_on_aim(tol_deg: float) -> bool:
	if tank == null or not is_instance_valid(tank):
		return false
	return tank.aimed_at(aim_point, tol_deg)


## The gun marker's place on screen, or Vector2.INF when it is behind the camera or unknown.
func marker_screen() -> Vector2:
	if not gun_point.is_finite() or is_position_behind(gun_point):
		return Vector2.INF
	return unproject_position(gun_point)
