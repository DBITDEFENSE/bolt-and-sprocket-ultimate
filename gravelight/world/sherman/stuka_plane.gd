class_name StukaPlane
extends Node3D
## The dive bomber of round 40 (T-249; our own work, built in code): a single-engined two-seat dive bomber of the
## German air force, inverted gull wings, fixed trousered gear with the siren on each leg, a long glazed canopy, slatted
## dive brakes under the wings, a 500 kg bomb on the swing crutch under the belly. Dark green over pale blue, a cross
## under each wing and on the fuselage.
## It flies one pass (`fly`): heard high up, level at approach_alt toward the target, the roll into a dive at dive_deg,
## the siren rising with the speed, the bomb let go at release_alt, the pull-out and the climb away; then it frees
## itself. The flight is a pure function of the time since it started (`pose_at`), so a co-op client flies the same
## pass from the same mirrored call. The bomb lands bomb_fall_s after release and calls `on_impact(pos)`.
## Model space: nose toward -Z, +X the right wing, y 0 the fuselage's axis.

signal bomb_released(at: Vector3)
signal impact(at: Vector3)

const SPAN_TIP: float = 6.95

var target: Vector3 = Vector3.ZERO
var back: Vector3 = Vector3(0, 0, 1)   # horizontal: from the target toward where it comes from
var cfg: Dictionary = {}
var t: float = 0.0
var flying: bool = false
var released: bool = false
var landed: bool = false
var _path: PackedVector3Array = PackedVector3Array()
var _cum: PackedFloat32Array = PackedFloat32Array()
var _speed_seg: Array = []               # per phase: [start distance, end distance, start speed, end speed, kind]
var _release_d: float = 0.0
var _dive_d: Vector2 = Vector2.ZERO      # the dive's start and end distance along the path
var _roll_d: Vector2 = Vector2.ZERO
var _prop: Node3D
var _bomb: Node3D
var _bomb_from: Vector3
var _bomb_t: float = -1.0
var _engine: AudioStreamPlayer3D
var _dive_snd: bool = false

static var _cache: Dictionary = {}
static var _mats: Dictionary = {}


func _init() -> void:
	name = "Stuka"


# ================================================================== the model

static func material(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	match key:
		"paint":
			m.albedo_color = Color(0.17, 0.2, 0.15)
			m.roughness = 0.62
			m.metallic = 0.2
		"glass":
			m.albedo_color = Color(0.55, 0.62, 0.66, 0.38)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.05
			m.metallic = 0.3
			m.vertex_color_use_as_albedo = false
		"frame":
			m.albedo_color = Color(0.14, 0.16, 0.12)
			m.roughness = 0.6
		"dark":
			m.albedo_color = Color(0.06, 0.055, 0.05)
			m.roughness = 0.5
			m.metallic = 0.6
		"rubber":
			m.albedo_color = Color(0.04, 0.04, 0.04)
			m.roughness = 0.85
		"black":
			m.albedo_color = Color(0.03, 0.03, 0.03)
			m.roughness = 0.7
		"white":
			m.albedo_color = Color(0.85, 0.85, 0.82)
			m.roughness = 0.7
		"bomb":
			m.albedo_color = Color(0.32, 0.31, 0.24)
			m.roughness = 0.55
			m.metallic = 0.3
		"blade":
			m.albedo_color = Color(0.08, 0.09, 0.07)
			m.roughness = 0.5
	_mats[key] = m
	return m


static func part(name: String) -> Array:
	if not _cache.has(name):
		var k: ProcKit = ProcKit.new()
		match name:
			"body":
				_body(k)
			"prop":
				_propeller(k)
			"bomb":
				bomb_mesh(k, 1.0)
			"bomb_small":
				bomb_mesh(k, 0.72)
		_cache[name] = k.commit()
	return _cache[name]


static func instance(name: String) -> MeshInstance3D:
	var mk: Array = part(name)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mk[0]
	var ks: Array = mk[1]
	for i: int in ks.size():
		mi.set_surface_override_material(i, material(str(ks[i])))
	return mi


## A cambered airfoil ring in the plane at `x` (thickness ratio `th`), leading edge at z `le`, chord `c`, its
## chord line at height `y`, nose turned `twist` rad. 2 x m points, top from the nose back, bottom from the tail forward.
static func airfoil(x: float, y: float, le: float, c: float, th: float, m: int = 9, twist: float = 0.0) -> PackedVector3Array:
	var top: Array[Vector2] = []
	var bot: Array[Vector2] = []
	for i: int in m:
		var u: float = pow(float(i) / float(m - 1), 1.6)
		var tk: float = 5.0 * th * (0.2969 * sqrt(u) - 0.126 * u - 0.3516 * u * u + 0.2843 * u * u * u - 0.1036 * u * u * u * u)
		var camber: float = 0.025 * c * sin(PI * u)
		top.append(Vector2(le + u * c, y + camber + tk * c))
		bot.append(Vector2(le + u * c, y + camber - tk * c * 0.75))
	var out: PackedVector3Array = PackedVector3Array()
	var piv: Vector2 = Vector2(le + c * 0.3, y)
	for p: Vector2 in top:
		var q: Vector2 = piv + (p - piv).rotated(twist)
		out.append(Vector3(x, q.y, q.x))
	for j: int in range(m - 2, 0, -1):
		var q2: Vector2 = piv + (bot[j] - piv).rotated(twist)
		out.append(Vector3(x, q2.y, q2.x))
	return out


## The wing's stations: [x, y of the chord line, leading edge z, chord, thickness ratio].
const WING: Array = [[0.42, -0.40, -1.95, 2.80, 0.16], [1.30, -0.70, -1.90, 2.65, 0.15], [2.40, -0.96, -1.80, 2.45, 0.14],
	[4.20, -0.70, -1.45, 1.95, 0.12], [6.10, -0.42, -1.10, 1.45, 0.10], [6.80, -0.32, -0.96, 1.08, 0.09], [SPAN_TIP, -0.30, -0.80, 0.60, 0.08]]

## The fuselage's sections: [z, half width, half height, centre y].
const FUSE: Array = [[-5.52, 0.30, 0.34, 0.02], [-5.40, 0.44, 0.52, -0.02], [-4.90, 0.52, 0.67, -0.10], [-4.10, 0.55, 0.70, -0.06],
	[-2.80, 0.55, 0.66, 0.02], [-1.20, 0.54, 0.62, 0.0], [0.50, 0.50, 0.56, 0.0], [2.10, 0.39, 0.46, 0.04], [3.70, 0.25, 0.33, 0.12],
	[4.90, 0.13, 0.23, 0.2], [5.55, 0.04, 0.12, 0.24]]


static func _body(k: ProcKit) -> void:
	k.belly = Color(0.52, 0.6, 0.66, 1.0)
	var rings: Array = []
	for s: Array in FUSE:
		rings.append(ProcKit.superellipse(Vector3(0, float(s[3]), float(s[0])), Vector3.RIGHT, Vector3.UP, float(s[1]), float(s[2]), 2.3, 24))
	k.loft("paint", rings, true, true, true)
	# the wings, each side, through their stations (the inverted gull: down to the knee, up to the tip)
	for side: float in [-1.0, 1.0]:
		var wr: Array = []
		for w: Array in WING:
			var ring: PackedVector3Array = airfoil(side * float(w[0]), float(w[1]), float(w[2]), float(w[3]), float(w[4]), 9, deg_to_rad(1.5))
			if side < 0.0:
				ring.reverse()
			wr.append(ring)
		k.loft("paint", wr, true, true, true)
		# the dive brake: slats on two struts under the outer wing, standing out in the dive
		for bx: float in [3.3, 4.4, 5.4]:
			k.beam("frame", Vector3(side * bx, -0.80, -1.05), Vector3(side * bx, -1.05, -1.18), 0.04)
		for sl: float in [0.0, 0.11]:
			k.box("frame", Vector3(side * 4.35, -1.08 - sl, -1.22 - sl * 0.4), Vector3(2.4, 0.035, 0.07))
		# the landing gear: a trousered leg from the knee down to a spatted wheel, the siren on its front
		var top: Vector3 = Vector3(side * 2.45, -1.05, -1.25)
		var gr: Array = []
		for g: Array in [[0.0, 0.30, 0.55], [-0.45, 0.20, 0.42], [-0.9, 0.17, 0.36], [-1.15, 0.22, 0.48], [-1.32, 0.24, 0.55], [-1.45, 0.18, 0.40], [-1.52, 0.06, 0.12]]:
			var c: Vector3 = top + Vector3(0, float(g[0]), 0.10 * float(g[0]))
			gr.append(ProcKit.superellipse(c, Vector3.RIGHT, Vector3.BACK, float(g[1]), float(g[2]), 2.0, 14))
		var gk: ProcKit = k
		gk.loft("paint", gr, true, true, true)
		k.cyl("rubber", top + Vector3(-0.07, -1.37, -0.14), top + Vector3(0.07, -1.37, -0.14), 0.34, 0.34, 18)
		var sir: Vector3 = top + Vector3(0, -0.38, -0.58)
		k.cyl("dark", sir, sir + Vector3(0, 0, 0.22), 0.07, 0.09, 10)
		for b: int in 2:
			var a: float = PI * float(b) + 0.4
			k.box("blade", sir + Vector3(cos(a) * 0.09, sin(a) * 0.09, -0.02), Vector3(0.16, 0.035, 0.012), Basis(Vector3.BACK, a))
		# the exhaust stubs on the cowling's side, a row of six
		for e: int in 6:
			k.box("dark", Vector3(side * 0.53, -0.22, -5.1 + 0.18 * float(e)), Vector3(0.09, 0.06, 0.1))
	# the tailplane on its struts, the fin and rudder
	for side2: float in [-1.0, 1.0]:
		var tp: Array = []
		for w2: Array in [[0.1, 0.36, 4.45, 1.20, 0.09], [1.6, 0.40, 4.70, 0.95, 0.08], [2.65, 0.42, 4.95, 0.62, 0.07]]:
			var r2: PackedVector3Array = airfoil(side2 * float(w2[0]), float(w2[1]), float(w2[2]), float(w2[3]), float(w2[4]), 7)
			if side2 < 0.0:
				r2.reverse()
			tp.append(r2)
		k.loft("paint", tp, true, true, true)
		k.beam("frame", Vector3(side2 * 1.2, 0.36, 5.0), Vector3(side2 * 0.12, -0.05, 4.8), 0.035)
	var fin: Array = []
	for f: Array in [[0.18, 4.10, 1.60], [1.10, 4.45, 1.20], [1.75, 4.80, 0.80], [1.95, 5.05, 0.45]]:
		var rf: PackedVector3Array = PackedVector3Array()
		for p: Vector3 in airfoil(0.0, 0.0, float(f[1]), float(f[2]), 0.09, 7):
			rf.append(Vector3(p.y, float(f[0]), p.z))   # the airfoil stood on edge: thickness across x
		fin.append(rf)
	k.loft("paint", fin, true, true, true)
	# the canopy: a long greenhouse, its frames
	var gl: Array = []
	for c2: Array in [[-2.75, 0.30, 0.18], [-2.40, 0.42, 0.40], [-1.6, 0.45, 0.50], [-0.4, 0.44, 0.50], [0.55, 0.40, 0.42], [1.05, 0.30, 0.20]]:
		var ring2: PackedVector3Array = PackedVector3Array()
		for i: int in 13:
			var a2: float = PI * float(i) / 12.0
			ring2.append(Vector3(cos(a2) * float(c2[1]), 0.48 + sin(a2) * float(c2[2]), float(c2[0])))
		gl.append(ring2)
	k.loft("glass", gl, false, true, true)
	for fz: float in [-2.4, -1.8, -1.2, -0.6, 0.0, 0.55]:
		var fr: Array = []
		for i2: int in 13:
			var a3: float = PI * float(i2) / 12.0
			var rr: float = 0.455 if absf(fz) < 1.7 else 0.43
			fr.append(Vector3(cos(a3) * rr, 0.48 + sin(a3) * 0.51, fz))
		for j: int in fr.size() - 1:
			k.beam("frame", fr[j], fr[j + 1], 0.03)
	k.beam("frame", Vector3(0, 0.99, -2.4), Vector3(0, 0.99, 0.55), 0.035)
	# the rear gunner's twin gun, the radiator's intake, the bomb crutch
	k.cyl("dark", Vector3(0.05, 0.75, 0.9), Vector3(0.05, 0.92, 1.9), 0.02, 0.02, 6)
	k.box("dark", Vector3(0, -0.72, -4.9), Vector3(0.5, 0.08, 0.3))
	k.beam("frame", Vector3(-0.18, -0.55, -1.5), Vector3(-0.18, -0.92, -0.6), 0.04)
	k.beam("frame", Vector3(0.18, -0.55, -1.5), Vector3(0.18, -0.92, -0.6), 0.04)
	# the crosses: under each wing (what the yard sees), and on each side of the fuselage
	k.belly = Color(0, 0, 0, 0)
	for side3: float in [-1.0, 1.0]:
		var cx: float = side3 * 4.9
		var y: float = -0.66 - 0.06
		_cross(k, Vector3(cx, y, -0.55), Vector3.DOWN, Vector3.FORWARD, 0.62)
		_cross(k, Vector3(side3 * 0.405, 0.12, 2.6), Vector3(side3, 0, 0), Vector3.UP, 0.42)


## A straight cross (black on a white border) facing `n` at `c`, arm half length r.
static func _cross(k: ProcKit, c: Vector3, n: Vector3, up: Vector3, r: float) -> void:
	var nz: Vector3 = n.normalized()
	var ux: Vector3 = up.cross(nz).normalized()
	var uy: Vector3 = nz.cross(ux).normalized()
	for layer: Array in [["white", r, r * 0.42, 0.0], ["black", r * 0.86, r * 0.24, 0.006]]:
		var a: float = float(layer[1])
		var w: float = float(layer[2])
		var o: Vector3 = c + nz * float(layer[3])
		for arm: Array in [[ux, uy], [uy, ux]]:
			var u: Vector3 = arm[0]
			var v: Vector3 = arm[1]
			k.quad(str(layer[0]), o - u * a - v * w * 0.5, o + u * a - v * w * 0.5, o + u * a + v * w * 0.5, o - u * a + v * w * 0.5)


static func _propeller(k: ProcKit) -> void:
	k.cyl("dark", Vector3(0, 0, 0.12), Vector3(0, 0, -0.42), 0.30, 0.04, 16)
	for b: int in 3:
		var a: float = TAU * float(b) / 3.0
		var dirb: Vector3 = Vector3(cos(a), sin(a), 0)
		var bs: Basis = Basis(Vector3.BACK, a) * Basis(Vector3.RIGHT, 0.35)
		k.box("blade", dirb * 0.95, Vector3(1.45, 0.22, 0.05), bs)


## A bomb's body (SC 500 at scale 1): the ogive nose, the cylinder, the tail cone, four fins in a ring. Along -Z (nose).
static func bomb_mesh(k: ProcKit, s: float) -> void:
	var r: float = 0.2 * s
	var L: float = 1.3 * s
	k.cyl("bomb", Vector3(0, 0, L * 0.25), Vector3(0, 0, -L * 0.3), r, r, 16, false)
	var nose: Array = []
	for i: int in 6:
		var u: float = float(i) / 5.0
		var rr: float = r * sqrt(maxf(0.0, 1.0 - u * u)) + 0.005
		nose.append(ProcKit.superellipse(Vector3(0, 0, -L * 0.3 - u * r * 1.6), Vector3.RIGHT, Vector3.UP, rr, rr, 2.0, 16))
	k.loft("bomb", nose, true, true, true)
	k.cyl("bomb", Vector3(0, 0, L * 0.25), Vector3(0, 0, L * 0.62), r, r * 0.35, 16)
	for f: int in 4:
		var a: float = TAU * float(f) / 4.0 + PI * 0.25
		var d: Vector3 = Vector3(cos(a), sin(a), 0)
		k.box("bomb", Vector3(0, 0, L * 0.6) + d * r * 0.75, Vector3(0.012, r * 1.5, L * 0.32), Basis(Vector3.BACK, a + PI * 0.5))
	k.ring("bomb", Vector3(0, 0, L * 0.68), Vector3(0, 0, L * 0.8), r * 1.15, r * 1.08, 16)
	k.cyl("dark", Vector3(0, 0, -L * 0.3 - r * 1.62), Vector3(0, 0, -L * 0.3 - r * 1.75), 0.03 * s, 0.025 * s, 8)


func build() -> void:
	add_child(instance("body"))
	_prop = Node3D.new()
	_prop.name = "Prop"
	_prop.position = Vector3(0, 0.0, -5.55)
	add_child(_prop)
	_prop.add_child(instance("prop"))
	_bomb = Node3D.new()
	_bomb.name = "Bomb"
	_bomb.position = Vector3(0, -0.98, -0.9)
	add_child(_bomb)
	_bomb.add_child(instance("bomb"))


# ================================================================== the pass

## Starts the pass on `at` from the bearing `from_dir` (horizontal, from the target toward the aircraft's approach).
func fly(at: Vector3, from_dir: Vector3, flight_cfg: Dictionary) -> void:
	if get_child_count() == 0:
		build()
	target = at
	back = Vector3(from_dir.x, 0, from_dir.z).normalized()
	if back.length_squared() < 0.5:
		back = Vector3(0, 0, -1)
	cfg = flight_cfg
	_plan()
	t = 0.0
	_d = 0.0
	_dive_snd = false
	flying = true
	released = false
	landed = false
	_bomb_t = -1.0
	_engine = AudioDirector.make_loop_3d("stuka_engine", self, 0.0)
	if _engine != null:
		_engine.play()
	_apply(0.0)


## The path as a polyline: level at approach_alt, a curve into the dive, the dive to release_alt, the pull-out, the
## climb away.
func _plan() -> void:
	var th: float = deg_to_rad(float(cfg.get("dive_deg", 72.0)))
	var hi: float = float(cfg.get("approach_alt", 500.0))
	var hr: float = float(cfg.get("release_alt", 110.0))
	var app: float = float(cfg.get("approach_m", 500.0))
	var ddir: Vector3 = (-back * cos(th) + Vector3.DOWN * sin(th)).normalized()   # the dive's direction
	var S: Vector3 = target - ddir * (hi / sin(th))                                    # where the dive starts (on its line)
	var R: Vector3 = target - ddir * (hr / sin(th))                                    # the release point
	var turn: float = 80.0
	var S0: Vector3 = S + back * turn + Vector3.UP * 12.0                              # level flight ends here
	var A: Vector3 = S0 + back * app
	var P: Vector3 = R + ddir * 55.0 + Vector3.UP * 0.0                              # the pull-out's bottom
	P.y = maxf(P.y, target.y + 55.0)
	var E: Vector3 = P - back * 260.0 + Vector3.UP * 180.0
	_path = PackedVector3Array()
	_add_line(A, S0, 20.0)
	_add_bezier(S0, S0 - back * turn * 0.55, S, 24)
	var dive0: int = _path.size() - 1
	_add_line(S, R, 6.0)
	var rel_i: int = _path.size() - 1
	_add_bezier(R, R + ddir * 70.0, P - back * 40.0 + Vector3.UP * 5.0, 24)
	_add_bezier(P - back * 40.0 + Vector3.UP * 5.0, P - back * 120.0 + Vector3.UP * 40.0, E, 24)
	_cum = PackedFloat32Array()
	var acc: float = 0.0
	for i: int in _path.size():
		_cum.append(acc)
		if i < _path.size() - 1:
			acc += _path[i].distance_to(_path[i + 1])
	_release_d = _cum[rel_i]
	_dive_d = Vector2(_cum[dive0], _release_d)
	_roll_d = Vector2(_cum[dive0] - turn * 1.3, _cum[dive0] + 20.0)


func _add_line(a: Vector3, b: Vector3, step: float) -> void:
	var n: int = maxi(1, int(ceil(a.distance_to(b) / step)))
	for i: int in n + 1:
		if i == 0 and not _path.is_empty():
			continue
		_path.append(a.lerp(b, float(i) / float(n)))


func _add_bezier(a: Vector3, c: Vector3, b: Vector3, n: int) -> void:
	for i: int in n + 1:
		if i == 0 and not _path.is_empty():
			continue
		var u: float = float(i) / float(n)
		_path.append(a.lerp(c, u).lerp(c.lerp(b, u), u))


## Speed along the path: cruising, accelerating down the dive to dive_speed, slowing as it climbs away.
func _speed_at(d: float) -> float:
	var cruise: float = 75.0
	var dive: float = float(cfg.get("dive_speed", 95.0))
	if d < _dive_d.x:
		return cruise
	if d < _dive_d.y:
		return lerpf(cruise, dive, clampf((d - _dive_d.x) / maxf(1.0, _dive_d.y - _dive_d.x), 0.0, 1.0))
	return lerpf(dive, 60.0, clampf((d - _dive_d.y) / 200.0, 0.0, 1.0))


## Seconds from the start to the release (for the event's schedule and the tests).
func release_time() -> float:
	return _time_to(_release_d)


func _time_to(d_end: float) -> float:
	var tt: float = 0.0
	var d: float = 0.0
	while d < d_end:
		var step: float = minf(2.0, d_end - d)
		tt += step / _speed_at(d + step * 0.5)
		d += step
	return tt


var _d: float = 0.0


func _process(delta: float) -> void:
	if not flying:
		_bomb_step(delta)
		return
	t += delta
	_d += _speed_at(_d) * delta
	_apply(_d)
	if _prop != null:
		_prop.rotation.z += delta * 60.0
	if not _dive_snd and _d >= _roll_d.x:
		_dive_snd = true
		AudioDirector.play_3d("stuka_dive", global_position, 4.0, 0.0)
	if not released and _d >= _release_d:
		_release()
	_bomb_step(delta)
	if _d >= _cum[_cum.size() - 1]:
		flying = false
		if _engine != null:
			_engine.stop()
		if landed or _bomb_t < 0.0:
			queue_free()


## Places the aircraft `d` metres along its path: along the tangent, rolled over into the dive.
func _apply(d: float) -> void:
	if _path.size() < 2:
		return
	var i: int = _cum.bsearch(d) - 1
	i = clampi(i, 0, _path.size() - 2)
	var seg: float = maxf(0.001, _cum[i + 1] - _cum[i])
	var p: Vector3 = _path[i].lerp(_path[i + 1], clampf((d - _cum[i]) / seg, 0.0, 1.0))
	var fwd: Vector3 = (_path[i + 1] - _path[i]).normalized()
	var up: Vector3 = Vector3.UP if absf(fwd.y) < 0.98 else back
	var bs: Basis = Basis.looking_at(fwd, up)
	var roll: float = 0.0
	if d > _roll_d.x and d < _roll_d.y:
		roll = sin(PI * (d - _roll_d.x) / (_roll_d.y - _roll_d.x)) * PI * 0.85
	bs = bs * Basis(Vector3.BACK, roll)
	global_transform = Transform3D(bs, p)


func pose_at(d: float) -> Transform3D:
	_apply(d)
	return global_transform


func _release() -> void:
	released = true
	_bomb_from = _bomb.global_position
	_bomb.top_level = true
	_bomb.global_transform = Transform3D(Basis.looking_at((target - _bomb_from).normalized(), back), _bomb_from)
	_bomb_t = 0.0
	AudioDirector.play_3d("a1_bomb_whistle", _bomb_from.lerp(target, 0.6), 4.0)
	bomb_released.emit(_bomb_from)


func _bomb_step(delta: float) -> void:
	if _bomb_t < 0.0 or landed:
		return
	_bomb_t += delta
	var fall: float = float(cfg.get("bomb_fall_s", 1.3))
	var u: float = clampf(_bomb_t / fall, 0.0, 1.0)
	var p: Vector3 = _bomb_from.lerp(target, u)
	p.y += sin(PI * u) * 3.0
	if is_instance_valid(_bomb):
		_bomb.global_position = p
	if u >= 1.0:
		landed = true
		if is_instance_valid(_bomb):
			_bomb.queue_free()
		impact.emit(target)
		if not flying:
			queue_free()
