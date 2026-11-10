class_name ZipLine
extends Interactable
## A zip line (T-229, the owner: "a sniper tower with a zipline"): a cable from a high anchor down to a post. The node
## stands at the anchor, the trolley hangs from it; holding Use there hangs the player from the trolley's bar and runs
## them down the sagging line (the trolley with them), dropping them at `to_pos`. Bots and zombies never take it. The
## cable and its posts are the generator's dressing; the trolley is drawn here so it can travel.
## T-230 (the owner: "zip line needs actual animation"): the ride is a ride. The player steps under the anchor, turns
## down the line, the gun goes away and both hands come up to the bar (ZipLine sets the hands' places every frame);
## they step off and drop into the hang (the arms take the weight on a stiff spring), then the trolley rolls: it starts
## slow and gains speed under gravity down the cable's slope (drag, a cap at `speed`, a bumper over the last BUMPER
## metres), the body hangs as a pendulum that lags the trolley's pull and sways, the trolley's wheels spin, the view
## rolls with the swing, the FOV opens and the wind rises with the speed; at the post the hands let go and the body
## drops to `to_pos` with a landing. The Player is "carried" meanwhile (Player.begin_carry): no movement, fire or ADS.
## Data-driven per map: data/gravelight/<map>.json "ziplines": [{"name": "...", "pos": [x, y, z] (the anchor, the
## cable's top), "end": [x, y, z] (the cable's low end on its post), "to": [x, y, z] (the landing, feet), "yaw":
## degrees (local -Z toward the rider), "speed": 7.5 (the cap, m/s), "hang": 2.7 (the rider's feet this far under
## the cable: the bar is BAR_DROP under it, the arms up), "sag": 0.3, "target": "down to the yard"}]

const MOUNT_S: float = 0.4        # to the bar, turning down the line
const LAND_S: float = 0.3         # the drop off the bar at the post
const G: float = 9.8
const DRAG: float = 0.012         # air and the wheels: a = G * slope - DRAG * v^2
const BUMPER: float = 1.8         # the trolley slows over the last metres to the post
const BRAKE: float = 5.0          # the most the cap or the bumper may slow it by (m/s^2): the swing stays a swing
const BAR_DROP: float = 0.56      # the bar this far under the cable (the trolley's hanger, _build_trolley)
const WHEEL_R: float = 0.09
const SAMPLES: int = 48           # the cable's arc-length table
const YAW_FREE: float = 1.4       # radians either side of the line the rider may look
# the hands in viewmodel space (rig space, like the hip pose): fists on a bar across the view
const HAND_R_BASIS: Basis = Basis(Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0))
const HAND_L_BASIS: Basis = Basis(Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, -1, 0))
const HANDS_DOWN_R: Vector3 = Vector3(0.2, -0.3, -0.26)
const HANDS_DOWN_L: Vector3 = Vector3(-0.2, -0.32, -0.26)
const BAR_X: float = 0.17         # the hands this far either side of the bar's middle

@export var end_pos: Vector3 = Vector3.ZERO     # the cable's low end (world)
@export var to_pos: Vector3 = Vector3.ZERO      # where the rider is set down (feet)
@export var speed: float = 7.5                  # m/s along the line at most
@export var hang: float = 2.7                   # the rider's feet this far under the cable while hanging
@export var sag: float = 0.3                    # the cable's dip at mid-span
@export var target: String = "down the line"

var rides: int = 0                              # the smokes count these
var _busy: Dictionary = {}                      # player id -> the ride's state (see ride)
var _trolley: Node3D = null
var _wheels: Array[Node3D] = []
var _tab: PackedFloat32Array = []               # cumulative cable length at i / SAMPLES
var _length: float = 1.0


func _ready() -> void:
	interact_size = Vector3(1.4, 1.8, 1.4)
	interact_offset = Vector3(0, -0.9, 0)        # the bar hangs under the anchor, where a standing rider's hands are
	super._ready()
	add_to_group(&"ziplines")
	_build_trolley()
	_build_table()
	set_physics_process(false)


func get_prompt(_player: Player) -> String:
	return "Hold [%s] to ride the zip line %s" % [prompt_key(&"interact"), target]


func can_interact(player: Player) -> bool:
	return player != null and player.is_alive() and not bool(player.get("downed")) and not _busy.has(player.player_id) and player.carry == null


func hold_time(_player: Player) -> float:
	return 0.35


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	ride(player)


func net_local() -> bool:
	return true


## A point on the cable, t 0 at the anchor .. 1 at the low end, with the sag.
func cable_point(t: float) -> Vector3:
	return global_position.lerp(end_pos, t) - Vector3.UP * (sag * 4.0 * t * (1.0 - t))


## The cable's tangent at t, pointing down the line.
func cable_tangent(t: float) -> Vector3:
	var d: Vector3 = cable_point(minf(t + 0.01, 1.0)) - cable_point(maxf(t - 0.01, 0.0))
	return d.normalized() if d.length() > 0.0001 else Vector3.FORWARD


func cable_length() -> float:
	return _length


## The horizontal direction down the line, and the yaw facing it.
func line_dir() -> Vector3:
	var d: Vector3 = end_pos - global_position
	d.y = 0.0
	return d.normalized() if d.length() > 0.01 else Vector3.FORWARD


func face_yaw() -> float:
	var d: Vector3 = line_dir()
	return atan2(-d.x, -d.z)


## Where a rider stands to take the bar: under the anchor, half a metre back up the line (on the deck).
func mount_pos(from_y: float) -> Vector3:
	var u: Vector3 = global_position - line_dir() * 0.45
	return Vector3(u.x, from_y, u.z)


## Where the hands grip the trolley's bar (world): [right, left].
func bar_grips() -> Array:
	if _trolley == null:
		return [global_position, global_position]
	var mid: Vector3 = _trolley.global_position - Vector3.UP * BAR_DROP
	var across: Vector3 = _trolley.global_basis.x.normalized()
	return [mid + across * BAR_X, mid - across * BAR_X]


func _build_table() -> void:
	_tab = PackedFloat32Array([0.0])
	var acc: float = 0.0
	for i: int in range(1, SAMPLES + 1):
		acc += cable_point(float(i) / SAMPLES).distance_to(cable_point(float(i - 1) / SAMPLES))
		_tab.append(acc)
	_length = maxf(acc, 0.01)


## The cable parameter t at arc length s from the anchor.
func _t_at(s: float) -> float:
	if _tab.size() < 2:
		return clampf(s / _length, 0.0, 1.0)
	s = clampf(s, 0.0, _length)
	for i: int in range(1, _tab.size()):
		if s <= _tab[i]:
			var a: float = _tab[i - 1]
			var b: float = _tab[i]
			return (float(i - 1) + (s - a) / maxf(b - a, 0.0001)) / SAMPLES
	return 1.0


## One step of the trolley: gravity down the slope, drag, the cap, the bumper (a brake of at most BRAKE, so the
## rider's swing never sees a jolt). Returns [s, v, a] with a the acceleration the body feels, within +-BRAKE.
func _roll_step(s: float, v: float, dt: float) -> Array:
	var tan_v: Vector3 = cable_tangent(_t_at(s))
	var a: float = G * (-tan_v.y) - DRAG * v * v
	var remaining: float = _length - s
	var cap: float = speed if remaining > BUMPER else lerpf(1.2, speed, clampf(remaining / BUMPER, 0.0, 1.0))
	var v2: float = v + a * dt
	if v2 > cap:
		v2 = maxf(cap, v - BRAKE * dt)
	v2 = maxf(v2, 0.8)
	var felt: float = clampf((v2 - v) / maxf(dt, 0.0001), -BRAKE, BRAKE)
	return [s + v2 * dt, v2, felt]


## Seconds of rolling from the anchor to the post (the same step the ride takes).
func roll_seconds() -> float:
	var s: float = 0.0
	var v: float = 0.6
	var t: float = 0.0
	while s < _length and t < 60.0:
		var r: Array = _roll_step(s, v, 1.0 / 60.0)
		s = r[0]
		v = r[1]
		t += 1.0 / 60.0
	return t


## The whole ride: to the bar, the roll, the drop at the post.
func ride_seconds() -> float:
	return MOUNT_S + roll_seconds() + LAND_S


## True while `player` hangs from this line.
func is_riding(player: Player) -> bool:
	return player != null and _busy.has(player.player_id)


## Starts the ride: the Player is carried (begin_carry) and this node moves them every physics frame (_tick).
func ride(player: Player) -> void:
	rides += 1
	var from: Vector3 = player.global_position
	var wind: AudioStreamPlayer = AudioDirector.make_loop_2d("wind_howl", player, -40.0)
	if wind != null:
		wind.play()
	_busy[player.player_id] = {
		"p": player, "t": 0.0, "from": from, "phase": 0, "s": 0.0, "v": 0.6, "a": 0.0,
		"ell": global_position.y - from.y, "ell_v": 0.0, "alpha": 0.0, "alpha_v": 0.0,
		"beta": 0.0, "beta_v": 0.35 * (1.0 if randf() < 0.5 else -1.0),
		"yaw0": player.rotation.y, "wind": wind, "land_t": 0.0, "land_from": from}
	player.begin_carry(self)
	if player.weapons != null:
		player.weapons.set_hands(&"hang")
		player.weapons.hands_shoulder = 0.0
	set_physics_process(true)
	AudioDirector.play_3d("amb_m1_cable_creak", global_position, 2.0)


func _physics_process(delta: float) -> void:
	for pid: Variant in _busy.keys():
		_tick(pid, _busy[pid], delta)
	if _busy.is_empty():
		set_physics_process(false)


func _stop_wind(st: Dictionary) -> void:
	var w: Node = st.get("wind")
	if w != null and is_instance_valid(w):
		w.queue_free()
	st["wind"] = null


func _finish(pid: Variant, st: Dictionary, p: Player) -> void:
	_stop_wind(st)
	if p != null and is_instance_valid(p) and p.carry == self:
		p.end_carry(self)
	_busy.erase(pid)
	_park_trolley()


func _tick(pid: Variant, st: Dictionary, delta: float) -> void:
	var p: Player = st["p"] as Player
	if p == null or not is_instance_valid(p) or not p.is_alive() or p.carry != self:
		_finish(pid, st, p)   # downed on the line: the body is left where it is, physics takes it
		return
	st["t"] = float(st["t"]) + delta
	var t: float = st["t"]
	var dir_h: Vector3 = line_dir()
	var side: Vector3 = dir_h.cross(Vector3.UP)
	var face: float = face_yaw()
	var from: Vector3 = st["from"]
	var pos: Vector3
	var head: Vector3 = Vector3.ZERO
	var roll: float = 0.0
	var pitch: float = 0.0
	var fov: float = 0.0
	var hr: Vector3 = HANDS_DOWN_R
	var hl: Vector3 = HANDS_DOWN_L
	var shoulder: float = 0.0
	if t < MOUNT_S:
		# under the anchor, turning down the line, the hands up to the bar
		var a: float = smoothstep(0.0, 1.0, t / MOUNT_S)
		pos = from.lerp(mount_pos(from.y), a)
		p.rotation.y = lerp_angle(float(st["yaw0"]), face, a)
		head.y = -0.02 * sin(a * PI)
		p.global_position = pos   # (the hands are aimed from where the eye is now)
		if p.weapons != null:
			var g0: Array = bar_grips()
			hr = HANDS_DOWN_R.lerp(p.weapons.vm_target(g0[0]), a)
			hl = HANDS_DOWN_L.lerp(p.weapons.vm_target(g0[1]), a)
		shoulder = 0.1 * a
	elif int(st["phase"]) == 0:
		# off the deck: the hang settles from the standing reach to `hang` on a stiff spring (the arms take the
		# weight); the trolley rolls; the body is a pendulum lagging the pull, with a side sway that dies down
		var ell: float = st["ell"]
		var ell_v: float = st["ell_v"]
		var w: float = 11.0
		ell_v += (-w * w * (ell - hang) - 2.0 * 0.45 * w * ell_v) * delta
		ell += ell_v * delta
		st["ell"] = ell
		st["ell_v"] = ell_v
		var r: Array = _roll_step(st["s"], st["v"], delta)
		var s: float = r[0]
		var v: float = r[1]
		var acc: float = r[2]
		st["s"] = s
		st["v"] = v
		var rod: float = maxf(ell - BAR_DROP, 0.6)   # the body swings from the bar (the hands), not from the cable
		var w0: float = sqrt(G / rod)
		var alpha: float = st["alpha"]
		var alpha_v: float = st["alpha_v"]
		alpha_v += (-w0 * w0 * (alpha - atan2(acc, G)) - 2.0 * 0.35 * w0 * alpha_v) * delta
		alpha += alpha_v * delta
		var beta: float = st["beta"]
		var beta_v: float = st["beta_v"]
		beta_v += (-w0 * w0 * beta - 2.0 * 0.12 * w0 * beta_v) * delta
		beta += beta_v * delta
		st["alpha"] = alpha
		st["alpha_v"] = alpha_v
		st["beta"] = beta
		st["beta_v"] = beta_v
		var tc: float = _t_at(s)
		var cp: Vector3 = cable_point(tc)
		pos = (cp - Vector3.UP * BAR_DROP) + (-Vector3.UP * cos(alpha) * cos(beta) - dir_h * sin(alpha) + side * sin(beta)) * rod
		if _trolley != null:
			_trolley.global_position = cp
			var tan_v: Vector3 = cable_tangent(tc)
			if tan_v.cross(Vector3.UP).length() > 0.01:
				_trolley.look_at(cp + tan_v, Vector3.UP)
			for wh: Node3D in _wheels:
				wh.rotation.x += v * delta / WHEEL_R
		var k: float = clampf(v / maxf(speed, 0.5), 0.0, 1.0)
		pitch = alpha * 0.45
		roll = beta * 0.9
		head.y = 0.012 * sin(t * 31.0) * k
		fov = 5.0 * k
		var wind: Node = st.get("wind")
		if wind != null and is_instance_valid(wind):
			(wind as AudioStreamPlayer).volume_db = lerpf(-32.0, -12.0, k)
		var d: float = wrapf(p.rotation.y - face, -PI, PI)
		if absf(d) > YAW_FREE:
			p.rotation.y = face + clampf(d, -YAW_FREE, YAW_FREE)
		# the hands on the real bar: over the head, ahead when the body lags, aside with the sway
		p.global_position = pos
		shoulder = 0.25 * clampf((ell - (global_position.y - from.y)) / maxf(hang - (global_position.y - from.y), 0.1), 0.0, 1.0)
		if p.weapons != null:
			var g1: Array = bar_grips()
			hr = p.weapons.vm_target(g1[0])
			hl = p.weapons.vm_target(g1[1])
		if s >= _length:
			st["phase"] = 1
			st["land_t"] = 0.0
			st["land_from"] = pos
			if p.weapons != null:
				p.weapons.set_hands(&"")
	else:
		# the drop at the post
		st["land_t"] = float(st["land_t"]) + delta
		var c: float = smoothstep(0.0, 1.0, float(st["land_t"]) / LAND_S)
		pos = (st["land_from"] as Vector3).lerp(to_pos, c)
		head.y = -0.04 * sin(c * PI)
		fov = 5.0 * (1.0 - c)
		var wind2: Node = st.get("wind")
		if wind2 != null and is_instance_valid(wind2):
			(wind2 as AudioStreamPlayer).volume_db = lerpf(-14.0, -40.0, c)
		if float(st["land_t"]) >= LAND_S:
			p.global_position = to_pos
			p.velocity = Vector3.ZERO
			_finish(pid, st, p)
			p.land_dip(minf(float(st["v"]), 5.0))
			return
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.carry_head = head
	p.carry_roll = roll
	p.carry_pitch = pitch
	p.carry_fov = fov
	if p.weapons != null:
		p.weapons.hands_shoulder = shoulder
		p.weapons.hand_r = Transform3D(HAND_R_BASIS, hr)
		p.weapons.hand_l = Transform3D(HAND_L_BASIS, hl)


func _park_trolley() -> void:
	if _trolley != null:
		var tw: Tween = create_tween()
		tw.tween_property(_trolley, "global_position", global_position, 0.6).set_delay(1.5)


## The trolley: two wheels astride the cable, a hanger, the bar. Oriented along the cable.
func _build_trolley() -> void:
	_trolley = Node3D.new()
	_trolley.name = "Trolley"
	add_child(_trolley)
	var dir: Vector3 = (end_pos - global_position)
	dir.y = 0.0
	if dir.length() > 0.01:
		_trolley.rotation.y = atan2(-dir.x, -dir.z)
	_wheels.clear()
	for sx: float in [-0.06, 0.06]:
		_wheels.append(Props.cyl(_trolley, Vector3(sx, 0.0, 0.0), WHEEL_R, 0.03, "steel", Vector3(0, 0, 90)))
	Props.block(_trolley, Vector3(-0.08, -0.14, -0.05), Vector3(0.08, -0.06, 0.05), "iron")
	Props.block(_trolley, Vector3(-0.02, -BAR_DROP, -0.02), Vector3(0.02, -0.12, 0.02), "iron")   # the hanger
	Props.cyl(_trolley, Vector3(0, -BAR_DROP, 0), 0.02, 0.64, "beam", Vector3(0, 0, 90))          # the bar
	for sx2: float in [-0.3, 0.3]:
		Props.cyl(_trolley, Vector3(sx2, -BAR_DROP, 0), 0.03, 0.08, "iron", Vector3(0, 0, 90))


## Spawns every zip line the map's json lists under `root` (a "ZipLines" holder). Returns them.
static func spawn_all(root: Node3D, map_id: StringName) -> Array[ZipLine]:
	var out: Array[ZipLine] = []
	var path: String = ClimbLink.json_path_for(map_id)
	if path == "" or not (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
		return out
	var rows: Array = GLData.load_json(path).get("ziplines", [])
	if rows.is_empty():
		return out
	var holder: Node3D = Node3D.new()
	holder.name = "ZipLines"
	root.add_child(holder)
	var i: int = 0
	for row: Dictionary in rows:
		var z: ZipLine = ZipLine.new()
		z.name = str(row.get("name", "ZipLine_%d" % i))
		z.end_pos = ClimbLink._v3(row.get("end", [0, 0, 0]))
		z.to_pos = ClimbLink._v3(row.get("to", [0, 0, 0]))
		z.speed = float(row.get("speed", 7.5))
		z.hang = float(row.get("hang", 2.7))
		z.sag = float(row.get("sag", 0.3))
		z.target = str(row.get("target", "down the line"))
		z.position = ClimbLink._v3(row.get("pos", [0, 0, 0]))
		z.rotation.y = deg_to_rad(float(row.get("yaw", 0.0)))
		holder.add_child(z)
		out.append(z)
		i += 1
	return out
