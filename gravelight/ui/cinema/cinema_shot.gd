class_name CinemaShot
extends RefCounted
## T-184: one shot of a cutscene, parsed from data (campaign.json "cutscenes" shots, or a runner's own list). Pure:
## `sample(local_t)` says where the camera is, what it looks at, its FOV and roll at that moment of the shot, so the
## unit tests can check a move without a scene. Every key but `t` and `from` is optional; the old shots (from / to /
## look / fov) still read the same, they only move on an eased curve instead of a sine-shaped lerp.
##   t, from, to          start time (s), the camera's path (a dolly from -> to; `to` defaults to `from`)
##   look, look_to        what it looks at, start and end (a pan); `target` = a node's name to keep in frame instead
##   fov, fov_to          the lens, start and end (a slow push of the lens adds weight)
##   move                 "dolly" (default), "crane" (+ `arc` metres of lift in the middle), "orbit" (round `look`
##                        by `sweep` degrees, or from `from` to `to` the short way), "static" (a locked-off frame)
##   ease, look_ease      the curve names (CinemaEase); default "smooth"
##   lead, hold           seconds the camera waits before the move / rests at its end (a hold on a key moment)
##   rel                  a node's name: from / to / look are offsets from where that node is now (a tracking shot)
##   handheld             0..1 subtle hand-held drift (default 0.22); shake = [[t, strength], ...] impact kicks
##   roll, roll_to        degrees of dutch angle
##   focus, blur          depth of field: the focus distance in metres (-1 = the look point), the blur 0..1 (0 = off)
##   grade                a preset name (CinemaGrade.PRESETS) or {exposure, contrast, saturation, tint, lift, vignette}
##   cut                  how the shot comes in: "cut" (default), "blend" (`blend` seconds from the last frame), "dip"
##                        (a dip through black, `blend` seconds)
##   vo, vo_at, fx, sfx, stinger, caption, light, squad   the shot's events (CinemaDirector reads them)

const DEFAULT_HANDHELD: float = 0.22

var t: float = 0.0
var dur: float = 1.0
var move: String = "dolly"
var from: Vector3 = Vector3.ZERO
var to: Vector3 = Vector3.ZERO
var look: Vector3 = Vector3.FORWARD
var look_to: Vector3 = Vector3.FORWARD
var fov: float = 60.0
var fov_to: float = 60.0
var ease: String = "smooth"
var look_ease: String = "smooth"
var lead: float = 0.0
var hold: float = 0.0
var arc: float = 0.0
var sweep: float = 0.0
var rel: String = ""
var target: String = ""
var target_offset: Vector3 = Vector3.ZERO
var handheld: float = DEFAULT_HANDHELD
var roll: float = 0.0
var roll_to: float = 0.0
var focus: float = -1.0
var blur: float = 0.0
var grade: Variant = null
var cut: String = "cut"
var blend: float = 0.0
var shake: Array = []
var raw: Dictionary = {}


static func v3(a: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if a is Array and (a as Array).size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	if a is Vector3:
		return a
	return fallback


## A shot from its data; `end_t` is when the next shot (or the cutscene) begins.
static func from_dict(d: Dictionary, end_t: float) -> CinemaShot:
	var s: CinemaShot = CinemaShot.new()
	s.raw = d
	s.t = float(d.get("t", 0.0))
	s.dur = maxf(0.25, end_t - s.t)
	s.move = str(d.get("move", "dolly"))
	s.from = v3(d.get("from", [0, 2, 0]))
	s.to = v3(d.get("to", null), s.from)
	s.look = v3(d.get("look", null), s.to + Vector3.FORWARD)
	s.look_to = v3(d.get("look_to", null), s.look)
	s.fov = float(d.get("fov", 60.0))
	s.fov_to = float(d.get("fov_to", s.fov))
	s.ease = str(d.get("ease", "smooth"))
	s.look_ease = str(d.get("look_ease", s.ease))
	s.lead = clampf(float(d.get("lead", 0.0)), 0.0, s.dur * 0.9)
	s.hold = clampf(float(d.get("hold", 0.0)), 0.0, maxf(0.0, s.dur - s.lead - 0.1))
	s.arc = float(d.get("arc", 0.0))
	s.sweep = float(d.get("sweep", 0.0))
	s.rel = str(d.get("rel", ""))
	s.target = str(d.get("target", ""))
	s.target_offset = v3(d.get("target_offset", null))
	s.handheld = float(d.get("handheld", DEFAULT_HANDHELD))
	s.roll = float(d.get("roll", 0.0))
	s.roll_to = float(d.get("roll_to", s.roll))
	s.focus = float(d.get("focus", -1.0))
	s.blur = clampf(float(d.get("blur", 0.0)), 0.0, 1.0)
	s.grade = d.get("grade", null)
	s.cut = str(d.get("cut", "cut"))
	s.blend = maxf(0.0, float(d.get("blend", 0.8 if s.cut != "cut" else 0.0)))
	s.shake = d.get("shake", []) as Array if d.get("shake", []) is Array else []
	return s


## Every shot of a cutscene definition ({"seconds", "shots"}), each knowing its length.
static func list_from(def: Dictionary) -> Array[CinemaShot]:
	var out: Array[CinemaShot] = []
	var shots: Array = def.get("shots", [])
	var total: float = float(def.get("seconds", 30.0))
	for i: int in shots.size():
		var end_t: float = float((shots[i + 1] as Dictionary).get("t", total)) if i + 1 < shots.size() else total
		out.append(from_dict(shots[i] as Dictionary, end_t))
	return out


## The shot playing at time `time` (-1 before the first).
static func index_at(shots: Array[CinemaShot], time: float) -> int:
	var i: int = -1
	for j: int in shots.size():
		if time >= shots[j].t:
			i = j
	return i


## The move's raw progress at `local_t` seconds into the shot: 0 during the lead, 1 during the hold.
func progress(local_t: float) -> float:
	var span: float = maxf(0.05, dur - lead - hold)
	return clampf((local_t - lead) / span, 0.0, 1.0)


## Where the camera is and looks at `local_t` seconds into the shot. `origin` is the `rel` node's position (zero
## when the shot is not relative), `target_pos` the `target` node's position (null: use look / look_to).
func sample(local_t: float, origin: Vector3 = Vector3.ZERO, target_pos: Variant = null) -> Dictionary:
	var k: float = progress(local_t)
	var e: float = CinemaEase.apply(ease, k)
	var el: float = CinemaEase.apply(look_ease, k)
	var lk: Vector3 = look.lerp(look_to, el)
	if target_pos is Vector3:
		lk = (target_pos as Vector3) + target_offset
	else:
		lk += origin
	var pos: Vector3
	match move:
		"static":
			pos = from
		"orbit":
			# round the look point: by `sweep` degrees at from's radius and height, or from `from` to `to` the short way
			var pivot: Vector3 = look.lerp(look_to, el)
			var a: Vector3 = from - pivot
			var b: Vector3 = to - pivot
			var a2: Vector2 = Vector2(a.x, a.z)
			var b2: Vector2 = Vector2(b.x, b.z)
			var by_sweep: bool = absf(sweep) > 0.01 or b2.length() < 0.01
			var ang: float = deg_to_rad(sweep) if by_sweep else a2.angle_to(b2)
			var r: float = a2.length() if by_sweep else lerpf(a2.length(), b2.length(), e)
			var h: float = a.y if by_sweep else lerpf(a.y, b.y, e)
			var an: float = atan2(a.z, a.x) + ang * e
			pos = pivot + Vector3(cos(an) * r, h, sin(an) * r)
		_:
			pos = from.lerp(to, e)
			if move == "crane" or absf(arc) > 0.001:
				pos.y += arc * sin(PI * e)
	pos += origin
	return {"pos": pos, "look": lk, "fov": lerpf(fov, fov_to, e), "roll": lerpf(roll, roll_to, e)}


## The shake kicks due in (a, b] seconds of the shot: [[t, strength], ...] entries.
func kicks_between(a: float, b: float) -> Array:
	var out: Array = []
	for kv: Variant in shake:
		if kv is Array and (kv as Array).size() >= 2:
			var kt: float = float(kv[0])
			if kt > a and kt <= b:
				out.append(kv)
	return out
