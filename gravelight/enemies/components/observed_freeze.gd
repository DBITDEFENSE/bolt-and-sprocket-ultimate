class_name ObservedFreeze
extends RefCounted
## "It only moves while nobody is looking" (docs/HOMAGE_BOSSES.md section 3.3; HB1 Alix beyond 8 m, later the
## Slender's teleport and the Grand Galleria mannequins). A subject is OBSERVED when it is inside a living
## player's camera frustum (the camera's field of view widened by `widen_deg`) AND a line-of-sight ray from that
## camera reaches the subject's head or chest. Checked at `hz`; going observed is immediate (at the next check,
## so under 1/hz s), going unobserved waits `hysteresis` s so the freeze never flickers.
##
## Bots: `include_bots` (cousins.json observers_include_bots, default true as the design doc says) makes bot
## teammates observers too. Their "camera" is the same Camera3D every Player carries (aimed where the bot looks),
## with the default 16:9 aspect. Judged fair: a bot squad pins her, but she still moves the moment every one of
## them turns to fight something else, and a human who keeps her in view is never punished for a bot glancing off.
##
## Usage: var f := ObservedFreeze.new(); each physics tick: frozen = f.update(delta, subject, [head, chest] points).

var hz: float = 20.0
var widen_deg: float = 5.0
var hysteresis: float = 0.1
var include_bots: bool = true
var observed: bool = false
var observers: int = 0          # how many players saw it at the last check (debug / tests)

var _t: float = 0.0
var _unseen_for: float = 0.0


## Pure: is `point` inside a camera's view cone (perspective frustum), widened by `widen_deg`?
## vfov_deg is the camera's vertical field of view (Camera3D.fov with KEEP_HEIGHT), aspect = width / height.
static func point_in_view(cam: Transform3D, vfov_deg: float, aspect: float, widen_deg: float, point: Vector3, far: float = 200.0) -> bool:
	var local: Vector3 = cam.affine_inverse() * point
	var depth: float = -local.z
	if depth <= 0.05 or depth > far:
		return false
	var half_v: float = deg_to_rad(vfov_deg * 0.5 + widen_deg)
	var half_h: float = atan(tan(deg_to_rad(vfov_deg * 0.5)) * maxf(0.1, aspect)) + deg_to_rad(widen_deg)
	return atan2(absf(local.y), depth) <= half_v and atan2(absf(local.x), depth) <= half_h


## Advances the check; returns true while the subject is observed (frozen).
func update(delta: float, subject: Node3D, points: Array) -> bool:
	_t -= delta
	if not observed:
		_unseen_for = 0.0
	if _t > 0.0:
		if observed:
			_unseen_for += delta
		return observed
	_t = 1.0 / maxf(1.0, hz)
	var seen: bool = check_now(subject, points)
	if seen:
		observed = true
		_unseen_for = 0.0
	elif observed:
		_unseen_for += 1.0 / maxf(1.0, hz)
		if _unseen_for >= hysteresis:
			observed = false
	return observed


## One full check against every living player (no hysteresis).
func check_now(subject: Node3D, points: Array) -> bool:
	observers = 0
	if subject == null or not subject.is_inside_tree():
		return false
	var space: PhysicsDirectSpaceState3D = subject.get_world_3d().direct_space_state
	for n: Node in subject.get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not p.is_alive() or p.camera == null:
			continue
		if p.is_bot and not include_bots:
			continue
		if _sees(p, space, points):
			observers += 1
	return observers > 0


func _sees(p: Player, space: PhysicsDirectSpaceState3D, points: Array) -> bool:
	var cam: Camera3D = p.camera
	var xf: Transform3D = cam.global_transform
	var aspect: float = 16.0 / 9.0
	if p.is_local and cam.get_viewport() != null:
		var vs: Vector2 = cam.get_viewport().get_visible_rect().size
		if vs.y > 1.0:
			aspect = vs.x / vs.y
	for pt: Variant in points:
		var q: Vector3 = pt as Vector3
		if not point_in_view(xf, cam.fov, aspect, widen_deg, q):
			continue
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(xf.origin, q, 1 | (1 << 8), [p.get_rid()])
		if space.intersect_ray(ray).is_empty():
			return true
	return false
