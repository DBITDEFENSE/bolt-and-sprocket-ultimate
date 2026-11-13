class_name HorseRig
extends Node3D
## The horse's body in motion (T-240): the skinned mesh from HorseMesh on a flat skeleton this node poses every frame
## from HorseGait. Nothing here is a clip: the legs are solved from where each hoof is in its stride (a hoof on the
## ground stays where it landed while the body travels over it), the body rides the gait (the walk's sway, the trot's
## bounce, the gallop's rock and suspension), the head nods with the stride, the neck bends into a turn, the ears and
## the tail have a life of their own, and a standing horse shifts its weight and rests a hind foot.
## The owner (Horse, HorseBoss) sets `speed` (m/s along -Z, signed), `turn` (-1..1, right positive) and the poses
## below, and calls tick(delta). Local space: nose toward -Z, the ground at y 0.
##   poses (0..1 unless said): head_low (the head down to the knees: a charge's wind-up, a graze), alert (the head
##   up, the ears forward), ears_back (pinned), rear (up on the hind legs), kick (both hind feet out behind), paw
##   (a foreleg scraping the ground), jaw (radians, the dead horse's), wrong (the dead horse's neck carried
##   crooked), shy (a flinch: the body drawn back, the head up and away), collapse (down onto the knees, then over
##   on its side), stagger (legs splayed, the head hanging).

signal hoof(leg: int, at: Vector3, gait: int)

var look: String = "noriker"
var speed: float = 0.0
var turn: float = 0.0
var head_low: float = 0.0
var alert: float = 0.0
var ears_back: float = 0.0
var rear: float = 0.0
var kick: float = 0.0
var paw: float = 0.0
var jaw: float = 0.0
var wrong: float = 0.0
var shy: float = 0.0
var collapse: float = 0.0
var stagger: float = 0.0
var look_yaw: float = 0.0            # radians the head turns toward something (clamped by the neck)
var gait: int = HorseGait.Gait.STAND
var phase: float = 0.0
var t: float = 0.0

var skel: Skeleton3D
var body: MeshInstance3D
var _ix: Dictionary = {}
var _rest: Array[Vector3] = []
var _prev_gait: int = HorseGait.Gait.STAND
var _blend: float = 1.0              # 0 = the previous gait's feet, 1 = this gait's
var _bend: float = 0.0               # the smoothed turn
var _lat: float = 0.0                # the smoothed sideways pull (the tail and the mane lag it)
var _tail_ang: float = 0.0
var _tail_vel: float = 0.0
var _swish: float = 0.0
var _swish_t: float = 3.0
var _ear_flick: Array[float] = [0.0, 0.0]
var _ear_t: float = 2.0
var _rest_leg: int = HorseGait.LH    # the hind foot a standing horse rests
var _rest_k: float = 0.0
var _rest_t: float = 6.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _a: Dictionary = {}              # bone name -> its deformation transform this frame (model space)
var _joints: Array = []


func _init(p_look: String = "noriker") -> void:
	look = p_look


func _ready() -> void:
	_rng.seed = hash(get_instance_id())
	skel = Skeleton3D.new()
	skel.name = "Skel"
	add_child(skel)
	var bl: Array = HorseMesh.bones()
	for i: int in bl.size():
		skel.add_bone(str(bl[i][0]))
		skel.set_bone_rest(i, Transform3D(Basis.IDENTITY, bl[i][1] as Vector3))
		_ix[str(bl[i][0])] = i
		_rest.append(bl[i][1] as Vector3)
	skel.reset_bone_poses()
	body = MeshInstance3D.new()
	body.name = "Body"
	body.mesh = HorseMesh.mesh(look)
	skel.add_child(body)
	body.skeleton = NodePath("..")
	body.skin = skel.create_skin_from_rest_transforms()
	body.extra_cull_margin = 2.0
	for leg: int in 4:
		_joints.append(HorseMesh.leg_joints(leg))
	phase = _rng.randf()
	pose()


## One frame: the stride advances with the speed, the hooves that land are announced, the bones are placed.
func tick(delta: float) -> void:
	t += delta
	var anim_speed: float = speed
	if absf(speed) < 0.15 and absf(turn) > 0.25:
		anim_speed = 0.7   # turning on the spot: it steps round
	var g: int = HorseGait.gait_for(anim_speed, gait)
	if collapse > 0.0 or rear > 0.3:
		g = HorseGait.Gait.STAND
	if g != gait:
		_prev_gait = gait
		gait = g
		_blend = 0.0
	_blend = minf(1.0, _blend + delta / 0.3)
	var before: float = phase
	phase = fposmod(phase + HorseGait.stride_hz(gait, anim_speed) * delta, 1.0)
	if gait != HorseGait.Gait.STAND and phase != before:
		for leg: int in HorseGait.landings(gait, before, phase):
			hoof.emit(leg, to_global(_joints[leg][5] as Vector3), gait)
	_bend = lerpf(_bend, clampf(turn, -1.0, 1.0), 1.0 - exp(-delta * 5.0))
	_lat = lerpf(_lat, turn * clampf(absf(speed) / 6.0, 0.0, 1.5), 1.0 - exp(-delta * 3.0))
	# the tail: a spring that lags the turn, and a swish now and then
	_swish_t -= delta
	if _swish_t <= 0.0:
		_swish_t = _rng.randf_range(2.5, 7.0) if gait <= HorseGait.Gait.WALK else _rng.randf_range(1.0, 3.0)
		_tail_vel += _rng.randf_range(2.5, 5.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
	_tail_vel += (-(_tail_ang + _lat * 0.5) * 30.0 - _tail_vel * 3.2) * delta
	_tail_ang += _tail_vel * delta
	# the ears: a flick each, at their own times
	_ear_t -= delta
	if _ear_t <= 0.0:
		_ear_t = _rng.randf_range(0.8, 4.0)
		_ear_flick[_rng.randi() % 2] = 1.0
	for i: int in 2:
		_ear_flick[i] = maxf(0.0, _ear_flick[i] - delta * 4.5)
	# a standing horse rests a hind foot, and changes feet after a while
	_rest_t -= delta
	if _rest_t <= 0.0:
		_rest_t = _rng.randf_range(7.0, 15.0)
		_rest_leg = HorseGait.RH if _rest_leg == HorseGait.LH else HorseGait.LH
		_rest_k = 0.0
	var resting: bool = gait == HorseGait.Gait.STAND and absf(turn) < 0.2 and rear <= 0.0 and kick <= 0.0 and paw <= 0.0 and collapse <= 0.0 and look != "dead"
	_rest_k = move_toward(_rest_k, 1.0 if resting else 0.0, delta * (0.6 if resting else 4.0))
	pose()


static func _about(pivot: Vector3, b: Basis) -> Transform3D:
	return Transform3D(b, pivot - b * pivot)


static func _rx(a: float) -> Basis:
	return Basis(Vector3.RIGHT, a)


func _put(name: String, a: Transform3D) -> void:
	_a[name] = a
	var i: int = _ix[name]
	var xf: Transform3D = a * Transform3D(Basis.IDENTITY, _rest[i])
	skel.set_bone_pose_position(i, xf.origin)
	skel.set_bone_pose_rotation(i, xf.basis.get_rotation_quaternion())


func _set_seg(name: String, at: Vector3, b: Basis) -> void:
	var i: int = _ix[name]
	skel.set_bone_pose_position(i, at)
	skel.set_bone_pose_rotation(i, b.get_rotation_quaternion())


## The middle joint of a two-bone chain from `root` to `tip` (lengths a, b), bent toward `hint`.
static func _two_bone(root: Vector3, tip: Vector3, a: float, b: float, hint: Vector3) -> Vector3:
	var d: Vector3 = tip - root
	var len_: float = clampf(d.length(), absf(a - b) + 0.005, a + b - 0.002)
	var dir: Vector3 = d.normalized() if d.length() > 0.0001 else Vector3.DOWN
	var x: float = (a * a - b * b + len_ * len_) / (2.0 * len_)
	var y: float = sqrt(maxf(0.0, a * a - x * x))
	var perp: Vector3 = hint - dir * hint.dot(dir)
	perp = perp.normalized() if perp.length() > 0.001 else Vector3.FORWARD
	return root + dir * x + perp * y


static func _arc(from: Vector3, to: Vector3) -> Basis:
	var f: Vector3 = from.normalized()
	var tt: Vector3 = to.normalized()
	if f.dot(tt) > 0.99999:
		return Basis.IDENTITY
	if f.dot(tt) < -0.9999:
		return Basis(Vector3.RIGHT, PI)
	return Basis(Quaternion(f, tt))


## The hoof's place for a leg in a gait: [offset (lift, reach), swing 0..1 (0 in stance), stance 0..1 (0 in swing)].
func _hoof(g: int, leg: int, spd: float) -> Array:
	var off: Vector3 = HorseGait.hoof_offset(g, leg, phase, spd)
	var lp: float = HorseGait.leg_phase(g, leg, phase)
	var d: float = HorseGait.duty(g)
	if g == HorseGait.Gait.STAND:
		return [off, 0.0, 0.5]
	if lp < d:
		return [off, 0.0, lp / d]
	return [off, (lp - d) / (1.0 - d), 0.0]


## Places every bone for this instant.
func pose() -> void:
	var anim_speed: float = speed
	if absf(speed) < 0.15 and absf(turn) > 0.25:
		anim_speed = 0.7
	var k: float = _blend * _blend * (3.0 - 2.0 * _blend)
	var sm: Vector3 = HorseGait.saddle_motion(_prev_gait, phase).lerp(HorseGait.saddle_motion(gait, phase), k)
	var nod: float = lerpf(HorseGait.head_nod(_prev_gait, phase), HorseGait.head_nod(gait, phase), k)
	var gallop: float = (k if gait == HorseGait.Gait.GALLOP else 0.0) + ((1.0 - k) if _prev_gait == HorseGait.Gait.GALLOP else 0.0)
	var standing: float = (k if gait == HorseGait.Gait.STAND else 0.0) + ((1.0 - k) if _prev_gait == HorseGait.Gait.STAND else 0.0)
	var dead: bool = look == "dead"
	# ---- the body: the gait's rise, pitch and roll; a lean into the turn; the poses
	var breath: float = sin(t * (1.4 if not dead else 0.9))
	var sway: float = 0.012 * sin(t * 0.37) * standing
	var c1: float = clampf(collapse * 2.0, 0.0, 1.0)            # onto the knees
	var c2: float = clampf(collapse * 2.0 - 1.0, 0.0, 1.0)      # over onto the side
	c1 = c1 * c1 * (3.0 - 2.0 * c1)
	c2 = c2 * c2 * (3.0 - 2.0 * c2)
	var rise: float = sm.x + 0.004 * breath * standing - 0.05 * stagger - 0.42 * c1 - 0.42 * c2 - 0.01 * _rest_k
	var pitch: float = sm.y - 0.1 * shy - 0.12 * kick - 0.3 * c1 * (1.0 - c2)
	var roll: float = sm.z - _bend * 0.07 * clampf(absf(speed) / 5.0, 0.0, 1.0) + 0.035 * _rest_k * (1.0 if _rest_leg == HorseGait.RH else -1.0) + 1.45 * c2
	var b_body: Basis = Basis(Vector3.BACK, roll) * _rx(pitch)
	var a_body: Transform3D = Transform3D(Basis.IDENTITY, Vector3(sway, rise, 0.1 * shy)) * _about(HorseMesh.BODY_PIVOT, b_body)
	if rear > 0.0:
		# up on the hind legs: the body turns about the hips, which sink a little under it
		var rk: float = rear * rear * (3.0 - 2.0 * rear)
		a_body = Transform3D(Basis.IDENTITY, Vector3(0, -0.1 * rk, 0.12 * rk)) * _about(Vector3(0, 1.05, 0.62), _rx(0.95 * rk)) * a_body
	_put("Body", a_body)
	var hip_flex: float = 0.06 * gallop * sin(TAU * (phase + 0.25))
	var a_hips: Transform3D = a_body * _about(HorseMesh.HIPS_PIVOT, Basis(Vector3.BACK, 0.03 * sin(TAU * phase) * (1.0 - standing) * (1.0 - gallop)) * _rx(hip_flex))
	_put("Hips", a_hips)
	# ---- the neck and the head
	var low: float = clampf(head_low, 0.0, 1.0)
	var neck_pitch: float = -nod - 1.05 * low + 0.22 * alert + 0.3 * shy - 0.5 * stagger + 0.55 * rear - 0.16 * gallop - 0.9 * c1 + 0.02 * breath * standing
	if dead:
		neck_pitch -= 0.28 * (1.0 - low) * wrong   # carried low and crooked
	var yaw_total: float = clampf(-_bend * 0.5 + look_yaw - 0.5 * shy, -1.1, 1.1) + (0.3 * wrong + 0.12 * wrong * sin(t * 0.7) if dead else 0.0)
	var twist: float = (0.42 * wrong + 0.1 * wrong * sin(t * 1.9 + 1.0)) if dead else 0.0
	var a_prev: Transform3D = a_body
	var shares: Array = [0.4, 0.35, 0.25]
	for i: int in 3:
		var rot: Basis = Basis(Vector3.UP, yaw_total * float(shares[i]) * 0.8) * _rx(neck_pitch * float(shares[i])) * Basis(Vector3.BACK, twist * float(shares[i]))
		a_prev = a_prev * _about(HorseMesh.NECK[i], rot)
		_put("Neck%d" % (i + 1), a_prev)
		var mane_sw: float = clampf(_lat * 0.5 + 0.05 * sin(t * 1.3 + float(i)), -0.5, 0.5) + 0.06 * sin(TAU * phase * 2.0 + float(i)) * (1.0 - standing)
		var crest: Vector3 = (HorseMesh.NECK[i] as Vector3) + Vector3(0, 0.3, -0.05)
		_put("Mane%d" % (i + 1), a_prev * _about(crest, Basis(Vector3.BACK, mane_sw) * _rx(-clampf(absf(speed) * 0.035, 0.0, 0.4))))
	# the head keeps its face while the neck moves under it (half the neck's pitch is given back), and tucks low
	var head_pitch: float = -neck_pitch * 0.45 - 0.35 * low + 0.25 * shy + 0.25 * stagger - 0.3 * rear + (0.18 * sin(t * 2.3) * wrong * 0.3 if dead else 0.0)
	var a_head: Transform3D = a_prev * _about(HorseMesh.NECK[3], Basis(Vector3.UP, yaw_total * 0.2) * _rx(head_pitch) * Basis(Vector3.BACK, twist * 0.5))
	_put("Head", a_head)
	_put("Jaw", a_head * _about(HorseMesh.head_point(0.1, 0.0, -0.1), _rx(-(jaw + (0.24 if dead else 0.0)))))
	_put("Forelock", a_head * _about(HorseMesh.head_point(-0.02, 0.0, 0.1), _rx(0.12 * sin(TAU * phase * 2.0) * (1.0 - standing)) * Basis(Vector3.BACK, _lat * 0.3)))
	for i: int in 2:
		var sx: float = -1.0 if i == 0 else 1.0
		var back: float = clampf(ears_back + 0.5 * gallop * 0.6 + 0.8 * shy, 0.0, 1.0)
		var e_pitch: float = lerpf(-0.25 * alert + 0.08 * sin(t * 0.9 + float(i) * 2.0), 1.15, back)
		var e_twist: float = _ear_flick[i] * 0.7 * sx * (1.0 - back)
		_put("EarL" if i == 0 else "EarR", a_head * _about(HorseMesh.ear_base(sx), Basis(Vector3.UP, e_twist) * _rx(e_pitch) * Basis(Vector3.BACK, -0.25 * back * sx)))
	# ---- the tail: lifted and streaming with the speed, swinging on its spring
	var lift: float = clampf(absf(speed) * 0.05, 0.0, 0.55) + 0.35 * rear + 0.2 * kick
	var a_tail: Transform3D = a_hips
	for i: int in 5:
		var seg_lift: float = -lift * (0.55 if i == 0 else 0.22) + (0.06 * sin(TAU * phase * 2.0 - float(i) * 0.7) * (1.0 - standing))
		var seg_swing: float = _tail_ang * (0.25 + 0.2 * float(i))
		a_tail = a_tail * _about(HorseMesh.TAIL[i], Basis(Vector3.BACK, seg_swing) * _rx(seg_lift))
		_put("Tail%d" % (i + 1), a_tail)
	# ---- the legs
	for leg: int in 4:
		_pose_leg(leg, anim_speed, k, a_body, a_hips, c1, c2)


func _pose_leg(leg: int, anim_speed: float, k: float, a_body: Transform3D, a_hips: Transform3D, c1: float, c2: float) -> void:
	var hind: bool = leg == HorseGait.LH or leg == HorseGait.RH
	var j: Array = _joints[leg]
	var nm: String = HorseGait.LEG_NAMES[leg]
	var a_root: Transform3D = a_hips if hind else a_body
	var bb: Basis = a_root.basis
	var p0: Vector3 = a_root * (j[0] as Vector3)
	var h0: Array = _hoof(_prev_gait, leg, anim_speed)
	var h1: Array = _hoof(gait, leg, anim_speed)
	var off: Vector3 = (h0[0] as Vector3).lerp(h1[0] as Vector3, k)
	var swing: float = lerpf(float(h0[1]), float(h1[1]), k)
	var stance: float = lerpf(float(h0[2]), float(h1[2]), k)
	# the pastern: sunk under the weight in stance, the hoof trailing in the swing
	var beta: float = 0.1 * sin(PI * stance) - (1.25 if not hind else 1.0) * sin(PI * pow(swing, 0.7)) * clampf(off.y * 6.0 + 0.2, 0.0, 1.0)
	var air: float = 0.0            # 1 = the foot hangs from the body (rearing, kicking, down)
	var fold: float = 0.0           # how far an airborne leg is drawn up
	var extra: Vector3 = Vector3.ZERO
	if hind:
		if kick > 0.0:
			air = clampf(kick * 1.5, 0.0, 1.0)
			extra = Vector3(0, 0.55, 0.95) * kick
			beta = lerpf(beta, 0.5, kick)
		if _rest_k > 0.0 and leg == _rest_leg:
			beta = lerpf(beta, -0.85, _rest_k)      # the toe tipped on the ground
			extra.y += 0.02 * _rest_k
		if stagger > 0.0:
			extra.x += 0.1 * stagger * signf((j[0] as Vector3).x)
	else:
		if rear > 0.0:
			air = clampf(rear * 1.6, 0.0, 1.0)
			fold = 0.55 * rear + 0.12 * sin(t * 9.0 + float(leg)) * rear   # the forelegs strike at the air
		if paw > 0.0 and leg == HorseGait.LF:
			var pk: float = fposmod(t * 1.6, 1.0)
			extra += Vector3(0, 0.2 * sin(PI * minf(pk * 1.6, 1.0)), -0.25 + 0.5 * pk) * paw
			beta = lerpf(beta, -0.9 * sin(PI * minf(pk * 1.6, 1.0)), paw)
		if stagger > 0.0:
			extra.x += 0.14 * stagger * signf((j[0] as Vector3).x)
			extra.z -= 0.08 * stagger
	if c1 > 0.0:
		air = maxf(air, c1 if not hind else c2)
		fold = maxf(fold, 0.75 * (c1 if not hind else c2))
	var foot_dir: Vector3 = _rx(beta) * ((j[5] as Vector3) - (j[3] as Vector3))    # fetlock -> the ground point of the hoof
	var f_ground: Vector3 = Vector3((j[3] as Vector3).x, -foot_dir.y + off.y, (j[3] as Vector3).z + off.z) + extra
	var f_air: Vector3 = a_root * ((j[3] as Vector3) + Vector3(0, 0.0, 0.0)) + bb * Vector3(0, 0.62 * fold, (-0.16 if not hind else -0.1) * fold) + bb * extra
	var f: Vector3 = f_ground.lerp(f_air, air)
	var basis_d: Basis = bb.slerp(Basis.IDENTITY, 1.0 - air) * _rx(beta - 0.6 * fold)
	var p1: Vector3
	var p2: Vector3
	if hind:
		# the cannon folds forward under the hock in the swing; the stifle is solved between the hip and the hock
		var gamma: float = -0.75 * sin(PI * swing) * clampf(off.y * 6.0, 0.0, 1.0) - 1.1 * fold + 0.25 * kick
		p2 = f + (bb.slerp(Basis.IDENTITY, 1.0 - air) * _rx(gamma)) * ((j[2] as Vector3) - (j[3] as Vector3))
		var la: float = ((j[1] as Vector3) - (j[0] as Vector3)).length()
		var lb: float = ((j[2] as Vector3) - (j[1] as Vector3)).length()
		var reach: Vector3 = p2 - p0
		if reach.length() > la + lb - 0.004:
			p2 = p0 + reach.normalized() * (la + lb - 0.004)
			f = p2 - (bb.slerp(Basis.IDENTITY, 1.0 - air) * _rx(gamma)) * ((j[2] as Vector3) - (j[3] as Vector3))
		p1 = _two_bone(p0, p2, la, lb, bb * Vector3.FORWARD)
	else:
		# the upper arm swings with the reach; the knee is solved between the elbow and the fetlock
		var alpha: float = clampf(((j[3] as Vector3).z - f.z) * 0.45, -0.3, 0.45) + off.y * 0.9 + 0.5 * fold
		p1 = p0 + bb * _rx(alpha) * ((j[1] as Vector3) - (j[0] as Vector3))
		var la2: float = ((j[2] as Vector3) - (j[1] as Vector3)).length()
		var lb2: float = ((j[3] as Vector3) - (j[2] as Vector3)).length()
		var reach2: Vector3 = f - p1
		if reach2.length() > la2 + lb2 - 0.004:
			f = p1 + reach2.normalized() * (la2 + lb2 - 0.004)
		p2 = _two_bone(p1, f, la2, lb2, bb * Vector3.FORWARD)
	_set_seg(nm + "_A", p0, _arc(bb * ((j[1] as Vector3) - (j[0] as Vector3)), p1 - p0) * bb)
	_set_seg(nm + "_B", p1, _arc(bb * ((j[2] as Vector3) - (j[1] as Vector3)), p2 - p1) * bb)
	_set_seg(nm + "_C", p2, _arc(bb * ((j[3] as Vector3) - (j[2] as Vector3)), f - p2) * bb)
	_set_seg(nm + "_D", f, basis_d)


## A rest point carried by a bone this frame, in this node's space (the seat, the pommel, the muzzle, an eye).
func point(bone: String, rest_point: Vector3) -> Vector3:
	return (_a.get(bone, Transform3D.IDENTITY) as Transform3D) * rest_point


func point_global(bone: String, rest_point: Vector3) -> Vector3:
	return to_global(point(bone, rest_point))


func bone_basis(bone: String) -> Basis:
	return (_a.get(bone, Transform3D.IDENTITY) as Transform3D).basis


## The world transform of the saddle's seat (the rider sits here; -Z is the horse's nose).
func seat_global() -> Transform3D:
	var a: Transform3D = _a.get("Body", Transform3D.IDENTITY)
	return global_transform * Transform3D(a.basis, a * HorseMesh.SEAT)


## Where the rein hands rest (world): [right, left], either side of the pommel.
func rein_grips() -> Array:
	var a: Transform3D = _a.get("Body", Transform3D.IDENTITY)
	return [to_global(a * (HorseMesh.POMMEL + Vector3(0.07, 0.03, -0.02))), to_global(a * (HorseMesh.POMMEL + Vector3(-0.07, 0.03, -0.02)))]


func muzzle_global() -> Vector3:
	return point_global("Head", HorseMesh.muzzle())


## A node that rides a bone (a light in the ribcage, a breath emitter at the nostrils, a hitbox).
func attach(bone: String, node: Node3D, rest_point: Vector3 = Vector3.INF) -> BoneAttachment3D:
	var at: BoneAttachment3D = BoneAttachment3D.new()
	at.name = "At_" + bone + "_" + str(get_child_count())
	skel.add_child(at)
	at.bone_name = bone
	at.add_child(node)
	if rest_point.is_finite():
		node.position = rest_point - _rest[_ix[bone]]
	return at
