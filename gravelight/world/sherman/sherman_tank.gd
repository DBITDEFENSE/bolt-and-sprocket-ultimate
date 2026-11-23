class_name ShermanTank
extends Node3D
## The Sherman itself (T-249): the model (ShermanMesh) on a rig that drives, steers, turns its turret, lays its gun,
## runs its tracks and wheels, fires (the 75 mm and the machine gun, with flash, tracers, smoke, sound and impacts),
## takes the dead's blows and a fire zombie's burst, and burns as a wreck. ShermanEvent owns it and decides; on a
## co-op client it is a puppet that follows the host's mirrored state (net_*).
## Its hull collider is on the map-edge layer (bit 11): players and bots are stopped by it, zombies, shots and blasts
## pass, so nothing baked or any zombie's path changes (the horse rail's rule, T-240).
##
## T-261 (the owner, 2026-11-22: "make the tank on round 30 smarter and make it use its cannon. I want the player to
## be able to drive the tank around if needed"; docs/u18/t261_tank.md):
##   the gunner   fights in the assault too (`defending`), not only once it holds; picks by ShermanRules: the 75 mm on
##                a pack, a burning one still far from everyone, the boss; the machine gun on what is nearest, hurt,
##                burning or closing on a player, only once the turret is laid on it; never at or near a player or
##                across one; with nothing to shoot the turret watches the side the dead are thickest on.
##   the driver   a player climbs in at the hull (Use), drives with the move keys (tank steering), lays the turret
##                with the view, fires the 75 mm (fire) and the machine gun (aim), climbs out with Use or jump. One at
##                a time; the gunner stands down while a player has the guns. The host decides who is in and what a
##                shell does; the driver's own machine moves the hull (the horse's pattern, T-240) and tells the host.

signal wrecked
signal bailed                          # the dead drove the driver out (outside the assault): the crew repairs

enum Mode { DRIVE, PARKED, WRECK }
enum Seat { NONE, IN, SEATED, OUT }

const LAYER_EDGE: int = 1 << 10
const MASK_LOS: int = 1
const MASK_HULL: int = 1 | (1 << 1) | (1 << 5) | (1 << 8) | (1 << 10)   # world, players, barricades, doors, the map's edge
const CUPOLA: Vector3 = Vector3(0.40, 0.81, 0.32)   # the commander's hatch, turret frame (ShermanMesh)

var cfg: Dictionary = {}               # sherman.json "tank"
var acfg: Dictionary = {}              # sherman.json "assist"
var dcfg: Dictionary = {}              # sherman.json "drive"
var ground: Dictionary = {}            # the map's "sherman_event" block: drive_zones, drive_boxes, drive_no_go
var puppet: bool = false
var mode: Mode = Mode.PARKED
var max_hp: float = 8000.0
var hp: float = 8000.0
var attackable: bool = false           # the round-30 assault is on
var assisting: bool = false            # rounds 31..39 (and the rest of round 30 once it holds)
var defending: bool = false            # T-261: the assault: it fights for itself
var drivable: bool = false             # T-261: parked and running: a player may climb in
var driver: Player = null
var seat: Seat = Seat.NONE
var lock_t: float = 0.0                # seconds the hatch stays shut after the dead drove the driver out
var use: ShermanUse = null
var hud: ShermanHud = null
var input_override: Variant = null     # smokes: Vector3(steer, throttle, 0) instead of the driver's keys
var aim_override: Variant = null       # smokes: the world point the driver looks at
var fire_wanted: bool = false          # smokes: the driver's trigger (the 75 mm)
var mg_wanted: bool = false            # smokes: the driver's machine gun held
var dismount_wanted: bool = false      # smokes: climb out now
var speed: float = 0.0
var route: PackedVector3Array = PackedVector3Array()
var route_i: int = 0
var swipes_taken: int = 0
var damage_taken: float = 0.0
var shots_main: int = 0
var shots_mg: int = 0
var mg_hits: int = 0
var kills: int = 0
var shots_held: int = 0                # shells the gunner did not fire because a player had come too near
var drives: int = 0
var driver_shells: int = 0
var crushed: int = 0
var refusals: int = 0
var forced_off: int = 0
var bails: int = 0

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
var _dead: Array = []                  # what the gunner knows of the dead (ShermanRules' dictionaries, plus "z")
var _watch_clock: float = 0.0
var _seat_t: float = 0.0
var _from: Vector3 = Vector3.ZERO      # the driver's place when the climb in / out began
var _to: Vector3 = Vector3.ZERO        # where the climb out sets them down
var _use_released: bool = false
var _hold_t: float = 0.0
var _mg_on: bool = false               # host: the driver holds the machine gun
var _mg_sent: bool = false             # the driver's machine: what the host was last told
var _crush_cd: float = 0.0
var _mob_t: float = 0.0
var _send_t: float = 0.0
var _last_state_ms: int = 0
var _bump_t: float = 0.0
var _has_zones: bool = false


func _init() -> void:
	name = "Sherman"
	_rng.randomize()


func _ready() -> void:
	add_to_group(&"sherman")
	if body == null:
		build()
	_has_zones = not get_tree().get_nodes_in_group(&"zone_volumes").is_empty()


func _exit_tree() -> void:
	# towed off or replaced with a player still in it: they are set down where they are, free to move
	if driver != null and is_instance_valid(driver):
		var p: Player = driver
		driver = null
		seat = Seat.NONE
		if p.is_local and p.carry == self:
			p.prompt_text = ""
			p.end_carry(self)
			if p.weapons != null:
				p.weapons.set_hands(&"")
		if hud != null and is_instance_valid(hud):
			hud.set_drive("")


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
	# (T-253) the full link near, a plain slab beyond FAR_RANGE: two MultiMeshes a side, laid together
	for s2: float in [-1.0, 1.0]:
		for far: bool in [false, true]:
			var mm: MultiMesh = MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = ShermanMesh.part("link_far" if far else "link")[0]
			mm.instance_count = _n_links
			var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
			mmi.name = ("TrackL" if s2 < 0.0 else "TrackR") + ("Far" if far else "")
			mmi.multimesh = mm
			mmi.material_override = ShermanMesh.material("track")
			mmi.position = Vector3(s2 * ShermanMesh.TRACK_X, 0, 0)
			if far:
				mmi.visibility_range_begin = ShermanMesh.FAR_RANGE
				mmi.visibility_range_begin_margin = 4.0
			else:
				mmi.visibility_range_end = ShermanMesh.FAR_RANGE
				mmi.visibility_range_end_margin = 4.0
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
	# (T-261) the Use point: the hull itself (a player climbs in from anywhere against it)
	use = ShermanUse.new()
	use.name = "Use"
	use.tank = self
	use.interact_size = Vector3(2.82, 2.6, 6.2)
	use.interact_offset = Vector3(0, 1.3, 0.04)
	add_child(use)
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
	# (T-253) the headlamps: a low pool of light on the road ahead of the bow, so the hull's front and the snow under
	# it read at night (no shadows; a look, nothing in the fight reads it)
	var head: SpotLight3D = SpotLight3D.new()
	head.name = "HeadLamp"
	head.position = Vector3(0, 1.47, -2.75)
	head.rotation_degrees = Vector3(-14.0, 0, 0)
	head.light_color = Color(1.0, 0.86, 0.62)
	head.light_energy = 2.6
	head.spot_range = 16.0
	head.spot_angle = 42.0
	head.spot_attenuation = 1.4
	head.shadow_enabled = false
	body.add_child(head)


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

func setup(tank_cfg: Dictionary, assist_cfg: Dictionary, health: float, drive_cfg: Dictionary = {}, ground_cfg: Dictionary = {}) -> void:
	cfg = tank_cfg
	acfg = assist_cfg
	dcfg = drive_cfg
	ground = ground_cfg
	max_hp = maxf(1.0, health)
	hp = max_hp


func hp_fraction() -> float:
	return clampf(hp / max_hp, 0.0, 1.0)


## The dead can beat on it in the assault, and whenever a player drives it (they go for the hull, not the hatch).
func can_be_attacked() -> bool:
	return (attackable or driver != null) and mode != Mode.WRECK and hp > 0.0


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
	_gun_t = maxf(0.0, _gun_t - delta)   # the 75 mm's reload, the gunner's and the driver's alike
	lock_t = maxf(0.0, lock_t - delta)
	if not puppet:
		_upkeep(delta)
	if driver != null:
		_driver_step(delta)
	if not simulates():
		_puppet_step(delta)
	elif mode == Mode.DRIVE:
		_drive_step(delta)
	if not puppet and mode == Mode.PARKED:
		if driver != null:
			_driver_host_step(delta)
		elif assisting or defending:
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
		if absf(v) > 0.05 and not _tracks_snd.playing:
			_tracks_snd.play()   # (a parked tank that a player drives off: the arrival started them, a dev park did not)
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


## True when the turret points within `tol_deg` of `p` on the flat (the machine gun's lay: it is swung by hand
## inside the mantlet, so what stands close under the gun's lowest lay can still be hit).
func laid_on(p: Vector3, tol_deg: float) -> bool:
	var f: Vector3 = -gun.global_transform.basis.z
	var d: Vector3 = p - gun.global_position
	var a: Vector2 = Vector2(f.x, f.z)
	var b: Vector2 = Vector2(d.x, d.z)
	if a.length() < 0.001 or b.length() < 0.001:
		return true
	return rad_to_deg(absf(a.angle_to(b))) <= tol_deg


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


## In the assault its health is the boss bar and it burns at 0. Driven outside the assault the dead cannot wreck
## it (rounds 31..39 need it, and round 40's bomber): its health stops at 1, the driver is put out and the hatch
## stays shut while the crew makes it good (ShermanRules.driven_out).
func take_damage(amount: float) -> void:
	if puppet or mode == Mode.WRECK or amount <= 0.0:
		return
	damage_taken += amount
	hp = maxf(0.0 if attackable else 1.0, hp - amount)
	if attackable:
		if hp <= 0.0:
			wreck(true)
	elif driver != null and ShermanRules.driven_out(hp, false):
		_bail()


func _bail() -> void:
	bails += 1
	lock_t = float(dcfg.get("lockout_s", 30.0))
	put_out()
	Net.mirror(self, &"net_lock", [lock_t])
	bailed.emit()


func net_lock(seconds: float) -> void:
	lock_t = seconds


## Host: outside the assault, with nobody driving, the crew repairs what the dead did.
func _upkeep(delta: float) -> void:
	if not attackable and driver == null and hp < max_hp:
		hp = minf(max_hp, hp + max_hp / maxf(1.0, float(dcfg.get("repair_s", 60.0))) * delta)


# ================================================================== the gunner (host)

## The assault and rounds 31..39: the machine gun and the 75 mm on the dead it can see, by ShermanRules (what is worth
## a shell, what the machine gun takes first, where to watch). Damage is a fraction of the round's zombie health
## (less in the assault: the team still has to hold it); it never fires at, near or across a player, pays no Scrip.
func _assist_step(delta: float) -> void:
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	if dir == null:
		return
	_scan_t -= delta
	_mg_t -= delta
	_watch_clock += delta
	var rh: float = float(RoundManager.current_health()) * (float(acfg.get("assault_damage_mult", 1.0)) if defending else 1.0)
	if _scan_t <= 0.0:
		_scan_t = float(acfg.get("scan_s", 0.3))
		_choose_targets(dir)
	var mg_ok: bool = _mg_target != null and is_instance_valid(_mg_target) and _mg_target.is_active()
	# the turret: the 75 mm's target once it is nearly loaded, else the machine gun's, else the watch
	if _gun_target != Vector3.INF:
		aim_world(_gun_target)
		if _gun_t <= 0.0 and aimed_at(_gun_target, float(acfg.get("aim_tolerance_deg", 3.0))):
			# the last look before the lanyard: where the shell will really burst, and who is near that now
			var burst: Vector3 = burst_point(muzzle(), _gun_target)
			if ShermanRules.shell_allowed(burst, _dead, _player_points(), global_transform, muzzle(), acfg):
				_gun_t = float(acfg.get("gun_reload_s", acfg.get("gun_interval", 6.5)))
				fire_main(_gun_target, rh)
			else:
				shots_held += 1
				_gun_t = float(acfg.get("gun_hold_s", 1.0))
			_gun_target = Vector3.INF
	elif mg_ok:
		aim_world(_mg_target.global_position + Vector3.UP * 1.0)
	else:
		var wy: float = ShermanRules.watch_yaw(_dead, global_transform, acfg)
		_turret_yaw_target = wy if not is_nan(wy) else ShermanRules.scan_yaw(_watch_clock, acfg)
		_gun_pitch_target = 0.0
	# the machine gun: a burst, then a gap; only with the turret laid on its target (no rounds thrown wide of it)
	var laid: bool = mg_ok and laid_on(_mg_target.global_position, float(acfg.get("mg_aim_tolerance_deg", 5.0)))
	if _mg_left > 0:
		if not mg_ok:
			_mg_left = 0
		elif laid:
			_mg_shot_t -= delta
			if _mg_shot_t <= 0.0:
				_mg_shot_t = 1.0 / maxf(1.0, float(acfg.get("mg_rate", 9.0)))
				_mg_left -= 1
				_mg_shot(rh)
	elif _mg_t <= 0.0 and laid:
		_mg_left = int(acfg.get("mg_burst", 7))
		_mg_t = float(acfg.get("mg_gap", 2.2)) + float(_mg_left) / maxf(1.0, float(acfg.get("mg_rate", 9.0)))


func _visible(from: Vector3, to: Vector3) -> bool:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, MASK_LOS)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Where every player stands (the downed too: nothing bursts by a man on the ground). Not the driver: the guns are
## theirs.
func _player_points() -> Array:
	var out: Array = []
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var pl: Player = n as Player
		if pl != null and pl != driver and not pl.spectating:
			out.append(pl.global_position)
	return out


static func is_boss(z: Node) -> bool:
	return z is HomageBoss or z is Foreman or z is Screamer


## The gunner's picture of the dead (every scan_s): the ones it may shoot (in range, in sight, up out of the ground,
## not under the guns) and the ones it only knows of (rising, behind a wall, out to watch_m), then its two targets.
func _choose_targets(dir: ZombieDirector) -> void:
	var rng_m: float = float(acfg.get("range", 45.0))
	var know_m: float = maxf(rng_m, float(acfg.get("watch_m", 60.0)))
	var under_m: float = float(acfg.get("mg_min_m", 3.5)) - 1.3   # (hugging the hull: under the guns)
	var xf: Transform3D = global_transform
	var eye: Vector3 = xf * Vector3(0, 2.4, -0.3)
	var was: Zombie = _mg_target
	var cur: int = -1
	_dead.clear()
	for z: Zombie in dir.active_zombies():
		if not z.is_active() or z.state == Zombie.State.DEAD:
			continue
		var pos: Vector3 = z.global_position
		var d: float = ShermanRules.flat(pos, xf.origin)
		if d > know_m:
			continue
		var under: bool = ShermanRules.hull_dist(xf, pos) < under_m
		var ok: bool = z.state != Zombie.State.EMERGE and d <= rng_m and not under and _visible(eye, pos + Vector3.UP * 1.1)
		if z == was:
			cur = _dead.size()
		_dead.append({"pos": pos, "z": z, "ok": ok, "under": under, "fire": FireZombie.is_fire(z), "boss": is_boss(z),
			"on_hull": z.prey is ShermanAttackPoint, "hp": z.hp / maxf(1.0, z.max_hp)})
	var players: Array = _player_points()
	var i: int = ShermanRules.pick_mg(_dead, players, xf, coax(), acfg, cur)
	_mg_target = (_dead[i] as Dictionary)["z"] if i >= 0 else null
	# the 75 mm: chosen while the last seconds of the reload run (the machine gun has the turret until then); a
	# target once taken is followed (the pack moves), and dropped when it is no longer worth a shell or safe
	if _gun_t > float(acfg.get("gun_lay_lead_s", 2.5)):
		_gun_target = Vector3.INF
		return
	var pick: Dictionary = {}
	if _gun_target != Vector3.INF:
		pick = ShermanRules.pick_shell(_dead, players, xf, muzzle(), acfg, _gun_target, float(acfg.get("gun_follow_m", 5.0)))
	if pick.is_empty():
		pick = ShermanRules.pick_shell(_dead, players, xf, muzzle(), acfg)
	_gun_target = (pick["at"] as Vector3) + Vector3.UP * 0.6 if not pick.is_empty() else Vector3.INF


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
	var to: Vector3 = burst_point(from, at)
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


## Where a shell laid on `at` bursts: where it first meets the world, or the target.
func burst_point(from: Vector3, at: Vector3) -> Vector3:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, at + (at - from).normalized() * 3.0, MASK_LOS)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and (hit["position"] as Vector3).distance_to(from) < from.distance_to(at):
		return hit["position"]
	return at


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
	# whoever drives is out and clear before it goes up (the host says where; a puppet that has not heard yet puts
	# its own driver down too)
	if not puppet:
		put_out()
	elif driver != null:
		_leave(exit_spot(), true)
	mode = Mode.WRECK
	attackable = false
	assisting = false
	defending = false
	drivable = false
	_mg_on = false
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
	ShermanMesh.burn(self)
	for mmi: Node in find_children("Track*", "MultiMeshInstance3D", true, false):
		(mmi as MultiMeshInstance3D).material_override = ShermanMesh.material("track", true)
	var hl: Node = body.get_node_or_null("HeadLamp")
	if hl != null:
		hl.queue_free()
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
	hp = frac * max_hp
	if driver != null and driver.is_local:
		# this machine drives it: the hull, the turret and the speed are its own; the host's place is taken only
		# when the two have come apart (the host refused a move)
		if ShermanRules.flat(pos, global_position) > float(dcfg.get("net_snap_m", 4.0)):
			global_position = pos
			rotation.y = yaw_rad
			speed = 0.0
	else:
		_net_from = global_transform
		_net_to = Transform3D(Basis(Vector3.UP, yaw_rad), pos)
		_net_lerp = 0.0
		_turret_yaw_target = tyaw
		_gun_pitch_target = gpitch
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


# ================================================================== the driver (T-261)
# A player in the commander's hatch: the hull by the move keys, the turret by the view, the 75 mm and the machine gun
# by fire and aim. The host decides who is in (ShermanUse.interact runs there) and what the guns do; the driver's own
# machine moves the hull and tells the host (net_by_drive_state), which mirrors it on (net_state).

func prompt_for(p: Player) -> String:
	if p == null or driver != null or is_wreck() or not drivable or mode != Mode.PARKED:
		return ""
	if lock_t > 0.0:
		return "The crew is making repairs: %d s" % int(ceil(lock_t))
	return "Hold [%s] to climb into the Sherman" % Interactable.prompt_key(&"interact")


func can_use(p: Player) -> bool:
	if p == null:
		return false
	if driver == p:
		return seat == Seat.SEATED
	return ShermanRules.may_mount(drivable and mode == Mode.PARKED, is_wreck(), driver != null, lock_t > 0.0,
		p.is_alive(), p.downed, p.is_bot or p.bot_driven or p.is_companion, p.carry != null)


## The host's (or solo's) decision: in, or the driver climbs out. Mirrored to every client.
func on_use(p: Player) -> void:
	if not can_use(p):
		return
	if driver == null:
		_board(p)
		Net.mirror(self, &"net_board", [p.player_id])
	else:
		var to: Vector3 = exit_spot()
		Net.mirror(self, &"net_leave", [to, false])
		_leave(to, false)


## Client: the host let player `pid` in.
func net_board(pid: int) -> void:
	var p: Player = _player(pid)
	if p != null:
		_board(p)


## Client: the driver climbs out (or is put out: `forced`) at `to`.
func net_leave(to: Vector3, forced: bool) -> void:
	_leave(to, forced)


func _player(pid: int) -> Player:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		if n is Player and (n as Player).player_id == pid:
			return n as Player
	return null


## True when this machine moves the hull: its driver is this machine's human, or nobody drives and it is the host's.
func simulates() -> bool:
	if driver != null and is_instance_valid(driver):
		return driver.is_local
	return not puppet


func is_driven() -> bool:
	return driver != null and is_instance_valid(driver)


func _board(p: Player) -> void:
	driver = p
	seat = Seat.IN
	_seat_t = 0.0
	_from = p.global_position
	_use_released = false
	_hold_t = 0.0
	dismount_wanted = false
	fire_wanted = false
	mg_wanted = false
	_mg_on = false
	_mg_sent = false
	_mg_left = 0
	_gun_target = Vector3.INF
	speed = 0.0
	drives += 1
	_collider.add_collision_exception_with(p)
	p.add_collision_exception_with(_collider)
	if p.is_local:
		p.begin_carry(self)
		p.carry_fire = false
		if p.weapons != null:
			# their own gun is put away: both hands on the hatch's rim, below the view
			p.weapons.set_hands(&"climb")
			p.weapons.hands_shoulder = 0.0
			p.weapons.hand_r = Transform3D(Horse.HAND_R_BASIS, LadderClimb.HANDS_DOWN_R + Vector3.DOWN * 0.6)
			p.weapons.hand_l = Transform3D(Horse.HAND_L_BASIS, LadderClimb.HANDS_DOWN_L + Vector3.DOWN * 0.6)
	AudioDirector.play_3d("sherman_clang", global_transform * Vector3(0.4, 2.7, 0.0), -8.0)


func _leave(to: Vector3, forced: bool) -> void:
	if driver == null or not is_instance_valid(driver):
		driver = null
		seat = Seat.NONE
		return
	_to = to
	speed = 0.0
	_mg_on = false
	if forced:
		forced_off += 1
		_finish_exit()
	elif seat != Seat.OUT:
		seat = Seat.OUT
		_seat_t = 0.0
		_from = driver.global_position


func _finish_exit() -> void:
	var p: Player = driver
	driver = null
	seat = Seat.NONE
	speed = 0.0
	_mg_on = false
	if p == null or not is_instance_valid(p):
		return
	if p.is_local:
		if hud != null and is_instance_valid(hud):
			hud.set_drive("")
		if p.carry == self:
			p.prompt_text = ""
			p.global_position = _to
			p.velocity = Vector3.ZERO
			p.end_carry(self)
			if p.weapons != null:
				p.weapons.set_hands(&"")
			if p.is_alive():
				p.land_dip(2.0)
	if is_inside_tree():
		get_tree().create_timer(0.6).timeout.connect(_solid_again.bind(p.get_instance_id()))


func _solid_again(player_iid: int) -> void:
	var p: Player = instance_from_id(player_iid) as Player
	if p != null and is_instance_valid(p) and driver != p and _collider != null:
		_collider.remove_collision_exception_with(p)
		p.remove_collision_exception_with(_collider)


## Host: the driver is out now, set down beside the hull: the wreck, the dive bomber, the dead on the hull, the
## driver down in the hatch.
func put_out() -> void:
	if driver == null or not is_instance_valid(driver):
		driver = null
		seat = Seat.NONE
		return
	var to: Vector3 = exit_spot()
	Net.mirror(self, &"net_leave", [to, true])
	_leave(to, true)


## Where the driver's feet are in the hatch (the commander's cupola, the eye a little over its rim).
func seat_feet() -> Vector3:
	return turret.global_transform * (CUPOLA + Vector3(0, float(dcfg.get("eye_over_hatch", 0.5)), 0)) - Vector3.UP * Player.EYE_STAND


## The first free place beside the hull: floor under it at the hull's height, room for a body (the hull itself
## counts as in the way), a clear line from the hull's side, in a zone that is open, on ground a player can walk
## away from (the navmesh within a metre). Beside the hatch first, then round the hull, then a ring farther out.
func exit_spot() -> Vector3:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var ex: Array[RID] = []
	if driver != null and is_instance_valid(driver):
		ex.append(driver.get_rid())
	var offs: Array[Vector3] = [Vector3(2.15, 0, 0.3), Vector3(-2.15, 0, 0.3), Vector3(2.15, 0, -1.7), Vector3(-2.15, 0, -1.7),
		Vector3(2.15, 0, 2.2), Vector3(-2.15, 0, 2.2), Vector3(0, 0, 4.0), Vector3(0, 0, -3.9)]
	for k: int in 12:
		var a: float = TAU * float(k) / 12.0
		offs.append(Vector3(cos(a) * 5.0, 0, sin(a) * 5.5))
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.6
	var nav: RID = get_world_3d().navigation_map
	for off: Vector3 in offs:
		var w: Vector3 = global_transform * off
		var rq: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(w + Vector3.UP * 1.4, w + Vector3.DOWN * 1.0, 1, ex)
		var hit: Dictionary = space.intersect_ray(rq)
		if hit.is_empty() or absf((hit["position"] as Vector3).y - global_position.y) > 0.6:
			continue
		var spot: Vector3 = hit["position"]
		var sq: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		sq.shape = cap
		sq.transform = Transform3D(Basis.IDENTITY, spot + Vector3.UP * 0.92)
		sq.collision_mask = MASK_HULL
		sq.exclude = ex
		if not space.intersect_shape(sq, 1).is_empty():
			continue
		var side: Vector3 = global_transform * Vector3(clampf(off.x, -1.0, 1.0), 0, clampf(off.z, -2.5, 2.5))
		var clear: bool = true
		for h: float in [0.35, 1.1]:
			var lq: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(side + Vector3.UP * h, spot + Vector3.UP * h, 1 | (1 << 5) | (1 << 8), ex)
			if not space.intersect_ray(lq).is_empty():
				clear = false
		if not clear:
			continue
		if _has_zones:
			var z: StringName = ZoneVolume.zone_at(get_tree(), spot + Vector3.UP * 0.6)
			if z == &"" or not GameState.is_zone_open(z):
				continue
		var np: Vector3 = NavigationServer3D.map_get_closest_point(nav, spot)
		if np != Vector3.ZERO and np.distance_to(spot) > 1.0:
			continue
		return spot
	# nothing free round it (it should not happen on open ground): the nearest walkable ground to its side
	var side_w: Vector3 = global_transform * Vector3(2.4, 0, 0)
	var np2: Vector3 = NavigationServer3D.map_get_closest_point(nav, side_w)
	return np2 if np2 != Vector3.ZERO else side_w


func _driver_step(delta: float) -> void:
	var p: Player = driver
	if p == null or not is_instance_valid(p) or not p.is_inside_tree():
		driver = null
		seat = Seat.NONE
		speed = 0.0
		_mg_on = false
		return
	_seat_t += delta
	_bump_t = maxf(0.0, _bump_t - delta)
	if not puppet and (p.downed or p.spectating):
		put_out()   # down in the hatch (a burst, a bomb): out beside the hull, where a teammate can reach them
		return
	if p.is_local and p.carry != self:
		# something else took the body (a respawn): the hatch is free again
		if puppet and Net.session != null:
			Net.session.request_interact(use)
			_leave(exit_spot(), true)
		else:
			put_out()
		return
	match seat:
		Seat.IN:
			var k: float = clampf(_seat_t / maxf(0.05, float(dcfg.get("mount_s", 0.9))), 0.0, 1.0)
			if p.is_local:
				var a: float = smoothstep(0.0, 1.0, k)
				p.global_position = _from.lerp(seat_feet(), a) + Vector3.UP * (0.45 * sin(a * PI))
				p.velocity = Vector3.ZERO
				p.carry_roll = 0.08 * sin(a * PI)
			if k >= 1.0:
				seat = Seat.SEATED
				_seat_t = 0.0
				if p.is_local:
					p.carry_roll = 0.0
		Seat.SEATED:
			if p.is_local:
				_drive_local(p, delta)
		Seat.OUT:
			var k2: float = clampf(_seat_t / maxf(0.05, float(dcfg.get("dismount_s", 0.6))), 0.0, 1.0)
			if p.is_local and p.carry == self:
				var a2: float = smoothstep(0.0, 1.0, k2)
				p.global_position = _from.lerp(_to, a2) + Vector3.UP * (0.35 * sin(a2 * PI))
				p.velocity = Vector3.ZERO
				p.carry_roll = -0.08 * sin(a2 * PI)
			if k2 >= 1.0:
				_finish_exit()


## The driver's own machine, seated: the keys (or a smoke's override) drive the hull, the view lays the turret, fire
## asks for a shell, aim holds the machine gun; Use held again or jump climbs out.
func _drive_local(p: Player, delta: float) -> void:
	var throttle: float = 0.0
	var st: float = 0.0
	var want_fire: bool = fire_wanted
	var want_mg: bool = mg_wanted
	var want_off: bool = dismount_wanted
	if input_override is Vector3:
		st = (input_override as Vector3).x
		throttle = (input_override as Vector3).y
	elif GameState.phase == GameState.Phase.PLAYING and not GameState.input_blocked and not p.bot_driven:
		var v: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back", 0.2)
		st = v.x
		throttle = -v.y
		want_fire = want_fire or Input.is_action_pressed(&"fire")
		want_mg = want_mg or Input.is_action_pressed(&"ads")
		# Use held again (after the press that climbed in is let go), or jump: out
		if not Input.is_action_pressed(&"interact"):
			_use_released = true
			_hold_t = 0.0
		elif _use_released:
			_hold_t += delta
			if _hold_t >= float(dcfg.get("hold_s", 0.4)):
				want_off = true
		if Input.is_action_just_pressed(&"jump"):
			want_off = true
	_step_drive(throttle, st, delta)
	aim_world(aim_override if aim_override is Vector3 else _view_point(p))
	p.global_position = seat_feet()
	p.velocity = Vector3.ZERO
	p.carry_pitch = body.rotation.x * 0.6   # the hull's rock when it starts, stops and fires
	var reload: float = float(acfg.get("gun_reload_s", acfg.get("gun_interval", 6.5)))
	if want_fire and _gun_t <= 0.0:
		fire_wanted = false
		var at: Vector3 = gun_line_point()
		if puppet and Net.session != null:
			_gun_t = reload   # (its own clock, for the HUD; the host's decides)
			Net.session.request_call(self, &"net_by_fire_main", [at])
		else:
			_driver_fire(at)
	if want_mg != _mg_sent:
		_mg_sent = want_mg
		if puppet and Net.session != null:
			Net.session.request_call(self, &"net_by_mg", [want_mg])
		else:
			_mg_on = want_mg
	if puppet and Net.session != null:
		_send_t -= delta
		if _send_t <= 0.0:
			_send_t = float(dcfg.get("net_send_s", 0.1))
			Net.session.request_call(self, &"net_by_drive_state", [global_position, rotation.y, _turret_yaw_target, _gun_pitch_target, speed])
	# what the keys do is said for the first seconds of the first few drives; the gun's state all the time
	p.prompt_text = "[%s] drive   [%s] 75 mm   [%s] machine gun   hold [%s] or [%s] to climb out" % [
		"move", Interactable.prompt_key(&"fire"), Interactable.prompt_key(&"ads"), Interactable.prompt_key(&"interact"),
		Interactable.prompt_key(&"jump")] if _seat_t < float(dcfg.get("help_s", 8.0)) and drives <= 3 else ""
	if hud != null and is_instance_valid(hud):
		hud.set_drive("75 MM READY" if _gun_t <= 0.0 else "75 MM LOADING %.1f" % _gun_t, ShermanRules.reload_frac(_gun_t, reload))
	if want_off:
		dismount_wanted = false
		_use_released = false   # one request: a client waits a round trip for the host's answer
		_hold_t = 0.0
		p.use_interactable(use)   # the host decides (and mirrors it); solo runs it here


## The point the driver looks at: where the view first meets the world, out to gun_range.
func _view_point(p: Player) -> Vector3:
	var from: Vector3 = p.camera.global_position
	var to: Vector3 = from - p.camera.global_basis.z * float(dcfg.get("gun_range", 60.0))
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, MASK_LOS)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else to


## Where the barrel points: the first thing on its line, out to gun_range (the driver's shell goes where the gun is
## laid, not where the view is: a turret still swinging fires wide).
func gun_line_point() -> Vector3:
	var from: Vector3 = muzzle()
	var to: Vector3 = from - gun.global_transform.basis.z.normalized() * float(dcfg.get("gun_range", 60.0))
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, MASK_LOS)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else to


## One step of the tracks under the driver: ShermanRules.drive_step, then the place it would stand is tried: the
## whole move, the turn alone, the run alone; what it cannot do it does not (it stops with a clank).
func _step_drive(throttle: float, st: float, delta: float) -> void:
	var before: float = speed
	var r: Dictionary = ShermanRules.drive_step(speed, throttle, st, delta, dcfg)
	var v: float = r["speed"]
	var yr: float = r["yaw_rate"]
	if absf(v) > 0.001 or absf(yr) > 0.0001:
		var yaw: float = rotation.y + yr * delta
		var pos: Vector3 = global_position + Vector3(-sin(yaw), 0, -cos(yaw)) * v * delta
		var straight: Vector3 = global_position + Vector3(-sin(rotation.y), 0, -cos(rotation.y)) * v * delta
		if may_be_at(pos, yaw):
			global_position = pos
			rotation.y = yaw
		elif absf(v) > 0.001 and absf(yr) > 0.0001 and may_be_at(straight, rotation.y):
			global_position = straight
		elif absf(yr) > 0.0001 and may_be_at(global_position, yaw):
			rotation.y = yaw
			_refuse(before)
			v = 0.0
		else:
			_refuse(before)
			v = 0.0
	speed = v
	_rock_v += (before - speed) * 0.4


func _refuse(was: float) -> void:
	if absf(was) > 0.5 and _bump_t <= 0.0:
		refusals += 1
		_bump_t = 1.0
		AudioDirector.play_3d("sherman_clang", global_transform * Vector3(0, 1.0, -2.6 if was > 0.0 else 2.8), -6.0)


## May the hull be at `pos`, heading `yaw`? The ground rule (ShermanRules.may_stand: the driving zones and boxes,
## the kept-clear discs), nothing solid in the hull's way (the world, a door, a barricade, the map's edge, a player
## or a bot: it stops for them), flat ground under all of it.
func may_be_at(pos: Vector3, yaw: float) -> bool:
	var xf: Transform3D = Transform3D(Basis(Vector3.UP, yaw), pos)
	return _may_stand(xf) and _hull_free(xf) and _ground_ok(xf)


func _may_stand(xf: Transform3D) -> bool:
	var zones: Array = []
	if _has_zones and not (ground.get("drive_zones", []) as Array).is_empty():
		for pt: Vector3 in ShermanRules.footprint(xf):
			zones.append(ZoneVolume.zone_at(get_tree(), pt + Vector3.UP * 0.6))
	return ShermanRules.may_stand(xf, zones, ground)


func _hull_free(xf: Transform3D) -> bool:
	var bx: BoxShape3D = BoxShape3D.new()
	bx.size = Vector3(2.62 + 0.16, 1.3, 5.9 + 0.16)
	var sq: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	sq.shape = bx
	sq.transform = xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.6 + 0.65, -0.05))   # from 0.6 m up: it rolls over what is lower
	sq.collision_mask = MASK_HULL
	var ex: Array[RID] = [_collider.get_rid()]
	if driver != null and is_instance_valid(driver):
		ex.append(driver.get_rid())
	sq.exclude = ex
	return get_world_3d().direct_space_state.intersect_shape(sq, 1).is_empty()


func _ground_ok(xf: Transform3D) -> bool:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var tol: float = float(dcfg.get("ground_tol_m", 0.45))
	var ex: Array[RID] = [_collider.get_rid()]
	for l: Vector3 in [Vector3(0, 0, 0), Vector3(1.1, 0, -2.6), Vector3(-1.1, 0, -2.6), Vector3(1.1, 0, 2.7), Vector3(-1.1, 0, 2.7)]:
		var w: Vector3 = xf * l
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(w + Vector3.UP * 0.55, w + Vector3.DOWN * 1.5, 1, ex)
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty() or absf((hit["position"] as Vector3).y - xf.origin.y) > tol:
			return false
	return true


## Host: a shell for the driver, along the barrel. The round's own health scale; the dead only; no Scrip.
func _driver_fire(at: Vector3) -> void:
	_gun_t = float(acfg.get("gun_reload_s", acfg.get("gun_interval", 6.5)))
	driver_shells += 1
	fire_main(at, float(RoundManager.current_health()))


## Client driver -> host (NetMatch.on_quest_request passes who asked): a shell, if it is their tank and it is loaded.
func net_by_fire_main(pid: int, at: Vector3) -> void:
	if puppet or driver == null or not is_instance_valid(driver) or driver.player_id != pid or seat != Seat.SEATED:
		return
	if _gun_t > float(dcfg.get("net_reload_slack_s", 0.4)) or at.distance_to(muzzle()) > float(dcfg.get("gun_range", 60.0)) + 10.0:
		return
	_driver_fire(at)


func net_by_mg(pid: int, on: bool) -> void:
	if not puppet and driver != null and is_instance_valid(driver) and driver.player_id == pid:
		_mg_on = on


## Client driver -> host: where the hull and the guns are. Taken when it is their tank, the step is one the tracks
## could have made (ShermanRules.plausible_move) and the place is one it may stand in; else the host's stands and
## the driver's machine is pulled back to it (net_state).
func net_by_drive_state(pid: int, pos: Vector3, yaw_rad: float, tyaw: float, gpitch: float, spd: float) -> void:
	if puppet or driver == null or not is_instance_valid(driver) or driver.player_id != pid or driver.is_local:
		return
	var now: int = Time.get_ticks_msec()
	var dt: float = clampf(float(now - _last_state_ms) / 1000.0, 0.05, 1.0) if _last_state_ms > 0 else 0.1
	_last_state_ms = now
	_turret_yaw_target = wrapf(tyaw, -PI, PI)
	_gun_pitch_target = clampf(gpitch, deg_to_rad(-10.0), deg_to_rad(25.0))
	var xf: Transform3D = Transform3D(Basis(Vector3.UP, yaw_rad), Vector3(pos.x, global_position.y, pos.z))
	if not ShermanRules.plausible_move(global_position, xf.origin, dt, dcfg) or not _may_stand(xf):
		speed = 0.0
		return
	_net_from = global_transform
	_net_to = xf
	_net_lerp = 0.0
	speed = clampf(spd, -float(dcfg.get("reverse_speed", 1.6)), float(dcfg.get("speed", 3.2)))


## What a client may ask of the host on this node (NetMatch.on_quest_request "call").
func net_callable() -> Array:
	return ["net_by_fire_main", "net_by_mg", "net_by_drive_state"]


## Host, while a player drives: their machine gun, the dead under the tracks, the dead that come for the driver.
func _driver_host_step(delta: float) -> void:
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	if dir == null:
		return
	var rh: float = float(RoundManager.current_health())
	if _mg_on and seat == Seat.SEATED:
		_mg_shot_t -= delta
		if _mg_shot_t <= 0.0:
			_mg_shot_t = 1.0 / maxf(1.0, float(acfg.get("mg_rate", 9.0)))
			_mg_line_shot(dir, rh)
	_crush_step(dir, rh, delta)
	_mob_t -= delta
	if _mob_t <= 0.0:
		_mob_t = float(dcfg.get("mob_scan_s", 0.5))
		_mob_step(dir)


## One round from the coax along the barrel: the first of the dead on its line (within mg_hit_m of it) before the
## world is hit.
func _mg_line_shot(dir: ZombieDirector, round_health: float) -> void:
	var from: Vector3 = coax()
	var dirv: Vector3 = -gun.global_transform.basis.z.normalized()
	var reach: float = float(acfg.get("range", 45.0))
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + dirv * reach, MASK_LOS)
	var wall: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if not wall.is_empty():
		reach = from.distance_to(wall["position"])
	var best: Zombie = null
	var best_t: float = reach
	var wide: float = float(dcfg.get("mg_hit_m", 0.5))
	for z: Zombie in dir.active_zombies():
		if not z.is_active() or z.state == Zombie.State.EMERGE or z.state == Zombie.State.DEAD:
			continue
		var t: float = (z.global_position + Vector3.UP * 1.0 - from).dot(dirv)
		if t < 0.5 or t > best_t:
			continue
		var on_line: Vector3 = from + dirv * t
		if ShermanRules.flat(on_line, z.global_position) <= wide and on_line.y >= z.global_position.y - 0.1 and on_line.y <= z.global_position.y + 1.9:
			best = z
			best_t = t
	var to: Vector3 = from + dirv * best_t
	shots_mg += 1
	fire_mg_fx(from, to, best != null)
	if Net.replicating():
		Net.mirror(self, &"fire_mg_fx", [from, to, best != null])
	if best != null:
		mg_hits += 1
		if best.take_damage(round_health * float(acfg.get("mg_damage_frac", 0.03)), &"torso", &"sherman_mg", 0, &"bullet"):
			kills += 1


## The dead under the tracks (ShermanRules.crush / under_tracks): one at a time, each costs the hull speed. The
## bosses are not run down (they are not stopped by it either: nothing of theirs changes). No Scrip.
func _crush_step(dir: ZombieDirector, round_health: float, delta: float) -> void:
	_crush_cd = maxf(0.0, _crush_cd - delta)
	var hit: Dictionary = ShermanRules.crush(speed, _crush_cd, dcfg)
	if hit.is_empty():
		return
	var inv: Transform3D = global_transform.affine_inverse()
	for z: Zombie in dir.active_zombies():
		if not z.is_active() or is_boss(z) or z.state == Zombie.State.EMERGE or z.state == Zombie.State.DEAD:
			continue
		if not ShermanRules.under_tracks(inv * z.global_position, speed, dcfg):
			continue
		crushed += 1
		_crush_cd = float(dcfg.get("crush_cooldown", 0.35))
		speed *= 1.0 - float(hit["slow"])
		_rock_v += 0.5
		AudioDirector.play_3d("impact_flesh", z.global_position + Vector3.UP * 0.4, 2.0)
		if z.take_damage(round_health * float(hit["damage_frac"]), &"torso", &"sherman_tracks", 0, &"world"):
			kills += 1
		return


## The dead that come for the driver cannot reach the hatch: within mob_m of the hull they go for the hull instead
## (an attack point as their prey, the assault's own hook), and the hull pays (take_swipe). When the driver is out
## the points stop being catchable and they turn on the players again by themselves.
func _mob_step(dir: ZombieDirector) -> void:
	var reach: float = float(dcfg.get("mob_m", 6.0))
	for z: Zombie in dir.active_zombies():
		if z.prey != null or not z.is_active() or is_boss(z) or z.state == Zombie.State.EMERGE or z.state == Zombie.State.DEAD:
			continue
		if ShermanRules.hull_dist(global_transform, z.global_position) > reach or z.call(&"_nearest_player") != driver:
			continue
		var best: ShermanAttackPoint = null
		var best_s: float = INF
		for ap: ShermanAttackPoint in points:
			var s: float = float(ap.holders_now(dir)) * 100.0 + ap.global_position.distance_to(z.global_position)
			if s < best_s:
				best_s = s
				best = ap
		z.prey = best


## The Use point on the hull (the Player's interaction ray finds its area; a co-op client's use runs on the host).
class ShermanUse extends Interactable:
	var tank: ShermanTank = null

	func build_greybox() -> void:
		pass

	func get_prompt(player: Player) -> String:
		return tank.prompt_for(player) if tank != null else ""

	func can_interact(player: Player) -> bool:
		return tank != null and tank.can_use(player)

	func hold_time(_player: Player) -> float:
		return float(tank.dcfg.get("hold_s", 0.4)) if tank != null else 0.4

	func interact(player: Player) -> void:
		if tank != null:
			tank.on_use(player)
