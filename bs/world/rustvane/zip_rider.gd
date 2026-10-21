class_name ZipRider
extends Node
## Rides golden ride-rails and cliff zip lines (tryAttachRail / updateRail, index.html:3074-3125; BS_LEVELS
## §0.5 "golden rails stay usable without the Soles", §3.5 zip lines). Reads every node in group "rails" (the
## LevelDirector's rail markers: meta "points" PackedVector3Array, "two_way", "gadget", plus Rustvane's
## optional "end" = "soft" for lines that end on a tower platform and "speed_mul").
##   attach: not already riding, re-attach cooldown over, vel.y <= 2, horizontal distance² to a rail sample
##           < 1.9 (the source compares squared distance) and Bolt's centre 0.4 below .. 1.9 above it
##   ride:   13.5 m/s (17 with sprint) along the line, centre at rail + 1.0; jumps reset, hover regenerates
##   jump:   leaves with the line's velocity + 10.5 m/s up, 0.45 s cooldown, double jump ready
##   end:    launched at speed + 3 and 7.5 up (0.6 s cooldown); "soft" ends step off at 4 m/s + 2 up
## A rail whose meta "gadget" names a gadget (grind_soles) needs BS flag "gadget.<id>".
## Owns Bolt's body while riding (Gadget.claim_body). All numbers: the level data's "zip" table.

signal attached_rail(rail: Node3D)
signal left_rail(rail: Node3D, how: StringName)

var T: Dictionary = {}
var bolt: Bolt = null
var riding: Node3D = null
var s: float = 0.0
var dir: int = 1
var cd: float = 0.0
var rides: int = 0
var last_exit: StringName = &""
var last_exit_vel: Vector3 = Vector3.ZERO
var _cache: Dictionary = {}       # rail -> {"pts": PackedVector3Array, "cum": PackedFloat32Array, "len": float}
var _hinted: bool = false


func _ready() -> void:
	process_physics_priority = 10


func cfg(key: String, fallback: float) -> float:
	return float(T.get(key, fallback))


func _physics_process(delta: float) -> void:
	var dt: float = minf(delta, 0.05)
	if bolt == null or not is_instance_valid(bolt):
		bolt = LevelKit.player(get_tree()) as Bolt
		if bolt == null:
			return
	if riding != null:
		_ride(dt)
		return
	cd -= dt
	if cd <= 0.0:
		try_attach()


func _sampled(rail: Node3D) -> Dictionary:
	if _cache.has(rail):
		return _cache[rail]
	var raw: Variant = rail.get_meta(&"points", PackedVector3Array())
	var src: PackedVector3Array = raw if raw is PackedVector3Array else PackedVector3Array()
	var pts: PackedVector3Array = []
	var step: float = cfg("sample_step", 0.5)
	for i: int in src.size() - 1:
		var a: Vector3 = src[i]
		var b: Vector3 = src[i + 1]
		var n: int = maxi(1, ceili(a.distance_to(b) / step))
		for k: int in n:
			pts.append(a.lerp(b, float(k) / float(n)))
	if src.size() > 0:
		pts.append(src[src.size() - 1])
	var cum: PackedFloat32Array = [0.0]
	for i: int in range(1, pts.size()):
		cum.append(cum[i - 1] + pts[i].distance_to(pts[i - 1]))
	var d: Dictionary = {"pts": pts, "cum": cum, "len": cum[cum.size() - 1] if cum.size() > 0 else 0.0}
	_cache[rail] = d
	return d


func rail_usable(rail: Node3D) -> bool:
	var g: String = str(rail.get_meta(&"gadget", ""))
	return g == "" or BS.flag("gadget." + g)


## Grabs the nearest usable rail sample (the source's rule). Returns true when it attached.
func try_attach() -> bool:
	if riding != null or bolt == null or bolt.dead or not Gadget.body_free(bolt) or BS.blocked():
		return false
	if bolt.motor.vel.y > cfg("max_attach_vy", 2.0):
		return false
	var p: Vector3 = bolt.global_position
	var best_rail: Node3D = null
	var best_i: int = -1
	var best_d: float = cfg("attach_d2", 1.9)
	for n: Node in get_tree().get_nodes_in_group(&"rails"):
		var rail: Node3D = n as Node3D
		if rail == null or not rail.is_visible_in_tree() or not rail_usable(rail):
			continue
		var sd: Dictionary = _sampled(rail)
		var pts: PackedVector3Array = sd["pts"]
		var cum: PackedFloat32Array = sd["cum"]
		var one_way: bool = not bool(rail.get_meta(&"two_way", false))
		for i: int in pts.size():
			if one_way and float(sd["len"]) - cum[i] < cfg("end_dead_zone", 1.5):
				continue      # don't re-grab a one-way line at its own end
			var pt: Vector3 = pts[i]
			var dy: float = p.y - pt.y
			if dy < cfg("dy_min", -0.4) or dy > cfg("dy_max", 1.9):
				continue
			var d2: float = (p.x - pt.x) * (p.x - pt.x) + (p.z - pt.z) * (p.z - pt.z)
			if d2 < best_d:
				best_d = d2
				best_i = i
				best_rail = rail
	if best_rail == null:
		return false
	return attach(best_rail, best_i)


func attach(rail: Node3D, sample: int = 0) -> bool:
	if not Gadget.claim_body(bolt, self):
		return false
	var d: Dictionary = _sampled(rail)
	riding = rail
	s = (d["cum"] as PackedFloat32Array)[clampi(sample, 0, (d["cum"] as PackedFloat32Array).size() - 1)]
	var tan: Vector3 = _tangent(d, s)
	if bool(rail.get_meta(&"two_way", false)):
		var hv: Vector3 = Vector3(bolt.motor.vel.x, 0, bolt.motor.vel.z)
		var along: float = hv.dot(tan) if hv.length() > 1.5 else Vector3(sin(bolt.motor.yaw), 0, cos(bolt.motor.yaw)).dot(tan)
		dir = 1 if along >= 0.0 else -1
	else:
		dir = 1
	rides += 1
	if not _hinted:
		_hinted = true
		EventBus.hint.emit(LevelKit.text("code.tryAttachRail.01"), "rail")
	attached_rail.emit(rail)
	return true


func _point(d: Dictionary, at: float) -> Vector3:
	var pts: PackedVector3Array = d["pts"]
	var cum: PackedFloat32Array = d["cum"]
	if pts.size() == 1:
		return pts[0]
	at = clampf(at, 0.0, float(d["len"]))
	for i: int in range(1, cum.size()):
		if cum[i] >= at:
			var seg: float = cum[i] - cum[i - 1]
			return pts[i - 1].lerp(pts[i], (at - cum[i - 1]) / seg if seg > 0.0 else 0.0)
	return pts[pts.size() - 1]


func _tangent(d: Dictionary, at: float) -> Vector3:
	var a: Vector3 = _point(d, at - 0.6)
	var b: Vector3 = _point(d, at + 0.6)
	return (b - a).normalized() if a.distance_to(b) > 1e-4 else Vector3.FORWARD


func _ride(dt: float) -> void:
	if not is_instance_valid(riding) or bolt.dead:
		_leave(Vector3.ZERO, &"lost", 0.3)
		return
	var d: Dictionary = _sampled(riding)
	var spd: float = (cfg("sprint_speed", 17.0) if Gadget.sprint_held(bolt) else cfg("speed", 13.5)) * float(riding.get_meta(&"speed_mul", 1.0))
	s += float(dir) * spd * dt
	var tan: Vector3 = _tangent(d, s) * float(dir)
	if Gadget.jump_pressed(bolt):
		_leave(tan * spd + Vector3(0, cfg("jump_v", 10.5), 0), &"jump", cfg("jump_cd", 0.45))
		return
	if s <= 0.0 or s >= float(d["len"]):
		bolt.global_position = _point(d, s) + Vector3(0, cfg("ride_height", 1.0), 0)
		if str(riding.get_meta(&"end", "")) == "soft":
			var flat: Vector3 = Vector3(tan.x, 0, tan.z).normalized()
			_leave(flat * cfg("soft_speed", 4.0) + Vector3(0, cfg("soft_up", 2.0), 0), &"soft", cfg("end_cd", 0.6))
		else:
			var lt: Vector3 = Vector3(tan.x, 0, tan.z).normalized() * (spd + cfg("end_boost", 3.0))
			_leave(lt + Vector3(0, cfg("end_v", 7.5), 0), &"end", cfg("end_cd", 0.6))
		return
	bolt.global_position = _point(d, s) + Vector3(0, cfg("ride_height", 1.0), 0)
	bolt.motor.vel = Vector3(tan.x, 0, tan.z) * spd
	bolt.motor.jumps = 0
	bolt.motor.hover = minf(1.0, bolt.motor.hover + dt)
	bolt.motor.update_facing(dt, bolt.motor.yaw, false)


func _leave(v: Vector3, how: StringName, cooldown: float) -> void:
	var r: Node3D = riding
	riding = null
	cd = cooldown
	last_exit = how
	last_exit_vel = v
	Gadget.release_body(bolt, self, v)
	left_rail.emit(r, how)


func cancel() -> void:
	if riding != null:
		_leave(Vector3.ZERO, &"cancel", 0.3)
