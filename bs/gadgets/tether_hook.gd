class_name TetherHook
extends Gadget
## The Tether-Hook (BS_LEVELS §0.5, §3.5): Sprocket flies a cable to a ring and becomes the anchor.
##   press(): fire at the best ring (acquire range 16 m, inside a 30° cone of the camera, line of sight), or let
##            go if already attached. Jump also lets go.
##   Orange rings swing: rope = attach distance clamped to 5..14 m (a farther ring reels in to 14 m),
##            swing gravity 38 m/s², pumping adds 6 m/s² along the swing toward the move input, speed capped at
##            18 m/s. Release keeps the velocity and adds 4 m/s up; the double jump and hover are then ready.
##   Green rings pull: reel at 20 m/s to the ring's landing point (ring + land_offset, on the approach side
##            of the lip), then mantle over the lip (up mantle_up above the ring, in mantle_in past it) and step
##            off; a ring with no lip offset ends in a 6 m/s hop instead.
##   0.25 s re-fire. Touching the floor mid-swing (after 0.3 s) ends the swing as a landing.
## Every number comes from data/bs/gadgets.json "tether_hook". Rings are nodes in group "tether_points"
## (TetherPoint, or any Marker3D / Area3D with meta "kind"); Scrapheap's "gadget_points" markers with
## kind "tether" work too. While attached the hook owns Bolt's body (Gadget.claim_body).

signal attached(point: Node3D, kind: StringName)
signal released(vel: Vector3)

enum State { IDLE, FLY, SWING, PULL, MANTLE }

var state: State = State.IDLE
var target: Node3D = null
var target_kind: StringName = TetherPoint.SWING
var anchor: Vector3 = Vector3.ZERO
var rope: float = 0.0
var rope_target: float = 0.0
var vel: Vector3 = Vector3.ZERO
var state_t: float = 0.0
var cd: float = 0.0
var swings: int = 0
var pulls: int = 0
var last_release_vel: Vector3 = Vector3.ZERO
var _pull_from: Vector3 = Vector3.ZERO
var _pull_goal: Vector3 = Vector3.ZERO
var _stuck_t: float = 0.0
var _mantle: Array[Vector3] = []
var _mantle_dir: Vector3 = Vector3.ZERO
var _bark_cd: float = 0.0
var _cable: MeshInstance3D
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _on_setup() -> void:
	_rng.randomize()
	_cable = MeshInstance3D.new()
	_cable.name = "Cable"
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.05, 0.05, 1.0)
	_cable.mesh = bm
	var col: String = str((def.get("colors", {}) as Dictionary).get("cable", "#ffd23e"))
	_cable.material_override = LevelKit.mat(col, 0.8)
	_cable.visible = false
	add_child(_cable)


func busy() -> bool:
	return state != State.IDLE


func attached_now() -> bool:
	return state == State.SWING or state == State.PULL or state == State.MANTLE


func press() -> bool:
	if state != State.IDLE:
		release()
		return true
	if cd > 0.0 or not can_use():
		return false
	if not Gadget.body_free(bolt):
		return false
	var p: Node3D = acquire()
	if p == null:
		var line: Dictionary = VOManager.line("bs.gadget.tether.no_target")
		EventBus.hint.emit(str(line.get("text", "")), "tether_no_target")
		return false
	attach(p)
	return true


# ------------------------------------------------------------------ targeting

## Every ring node the hook could use (enabled or not).
func candidates() -> Array[Node3D]:
	var out: Array[Node3D] = []
	var tree: SceneTree = get_tree()
	for n: Node in tree.get_nodes_in_group(&"tether_points"):
		if n is Node3D:
			out.append(n as Node3D)
	for n2: Node in tree.get_nodes_in_group(&"gadget_points"):
		if n2 is Node3D and str(n2.get_meta(&"kind", "")) == "tether" and not out.has(n2 as Node3D):
			out.append(n2 as Node3D)
	return out


## The best ring: in range, inside the camera cone, in line of sight; smallest angle wins.
func acquire() -> Node3D:
	if bolt == null:
		return null
	var origin: Vector3 = bolt.aim_origin()
	if bolt.camera != null and bolt.camera.cam != null and bolt.camera.cam.is_inside_tree():
		origin = bolt.camera.cam.global_position
	var view: Vector3 = bolt.aim_dir()
	var rng_m: float = num("acquire_range", 16.0)
	var cone: float = num("acquire_cone_deg", 30.0)
	var best: Node3D = null
	var best_score: float = INF
	for p: Node3D in candidates():
		if not TetherPoint.is_enabled(p):
			continue
		var at: Vector3 = p.global_position
		var d: float = bolt.global_position.distance_to(at)
		if d > rng_m or d < 0.8:
			continue
		var ang: float = rad_to_deg(view.angle_to(at - origin))
		if ang > cone:
			continue
		if not has_los(at):
			continue
		var score: float = ang + d * 0.25
		if score < best_score:
			best_score = score
			best = p
	return best


func has_los(at: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = bolt.get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(bolt.aim_origin(), at, 1)
	q.exclude = [bolt.get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	return hit.is_empty() or (hit["position"] as Vector3).distance_to(at) < 0.9


## Fire at a specific ring (no cone check; tests and scripted runs use it).
func attach(p: Node3D) -> void:
	target = p
	target_kind = TetherPoint.kind_of(p)
	anchor = p.global_position
	state = State.FLY
	state_t = 0.0
	used.emit(self)


# ------------------------------------------------------------------ per frame

func _physics_process(delta: float) -> void:
	var dt: float = minf(delta, 0.05)
	cd -= dt
	_bark_cd -= dt
	if bolt == null or not is_instance_valid(bolt):
		return
	match state:
		State.FLY:
			state_t += dt
			if target == null or not is_instance_valid(target):
				state = State.IDLE
			elif state_t >= num("fly_time", 0.12):
				_begin()
		State.SWING:
			_swing(dt)
		State.PULL:
			_pull(dt)
		State.MANTLE:
			_do_mantle(dt)


func _begin() -> void:
	if not Gadget.claim_body(bolt, self):
		state = State.IDLE
		return
	anchor = target.global_position
	vel = bolt.motor.vel
	state_t = 0.0
	var dist: float = bolt.global_position.distance_to(anchor)
	if target_kind == TetherPoint.PULL:
		state = State.PULL
		pulls += 1
		_pull_from = bolt.global_position
		_pull_goal = anchor + TetherPoint.land_offset_of(target, LevelKit.v3(def.get("pull_land_offset"), Vector3(0, 1.4, 0)))
		_stuck_t = 0.0
		if pulls == 1:
			EventBus.bark.emit("bs.gadget.tether.pull.01")
	else:
		state = State.SWING
		swings += 1
		rope_target = clampf(dist, num("rope_min", 5.0), num("rope_max", 14.0))
		rope = maxf(dist, rope_target) if dist > rope_target else rope_target
		_weight_bark()
	attached.emit(target, target_kind)


func _weight_bark() -> void:
	var every: int = maxi(1, int(num("weight_bark_every", 4)))
	if _bark_cd > 0.0 or not (swings == 1 or swings % every == 0):
		return
	_bark_cd = num("weight_bark_cd", 20.0)
	var ids: PackedStringArray = []
	for k: Variant in (GadgetManager.table().get("lines", {}) as Dictionary).keys():
		if str(k).begins_with("bs.gadget.tether.weight."):
			ids.append(str(k))
	if not ids.is_empty():
		EventBus.bark.emit(ids[0] if swings == 1 else ids[_rng.randi_range(0, ids.size() - 1)])


func _swing(dt: float) -> void:
	state_t += dt
	if Gadget.jump_pressed(bolt):
		release()
		return
	rope = move_toward(rope, rope_target, num("reel_rate", 10.0) * dt)
	vel.y -= num("swing_gravity", 38.0) * dt
	var pos: Vector3 = bolt.global_position
	var r: Vector3 = pos - anchor
	var rn: Vector3 = r.normalized() if r.length_squared() > 1e-6 else Vector3.DOWN
	var dir: Vector3 = Gadget.move_dir(bolt)
	if dir.length_squared() > 0.0025:
		var tdir: Vector3 = dir - rn * dir.dot(rn)
		vel += tdir * num("pump_accel", 6.0) * dt
	var vmax: float = num("max_swing_speed", 18.0)
	if vel.length() > vmax:
		vel = vel.normalized() * vmax
	var want: Vector3 = pos + vel * dt
	var wr: Vector3 = want - anchor
	if wr.length() > rope:
		var n: Vector3 = wr.normalized()
		want = anchor + n * rope
		var outward: float = vel.dot(n)
		if outward > 0.0:
			vel -= n * outward
	var res: Dictionary = Gadget.move_body(bolt, want - pos)
	if bool(res["ceiling"]) and vel.y > 0.0:
		vel.y = 0.0
	if bool(res["wall"]):
		var wn: Vector3 = res["normal"]
		var into: float = vel.dot(-wn)
		if into > 0.0:
			vel += wn * into
	bolt.motor.vel = vel
	bolt.motor.update_facing(dt, bolt.motor.yaw, false)
	if bool(res["floor"]) and vel.y <= 0.0 and state_t >= num("land_release_after", 0.3):
		vel.y = 0.0
		release(false)
		return
	if bolt.global_position.y < bolt.kill_y or state_t > num("max_swing_time", 12.0) or _in_water():
		release(false)


func _pull(dt: float) -> void:
	state_t += dt
	var to: Vector3 = _pull_goal - bolt.global_position
	if to.length() <= num("pull_arrive", 1.2) or state_t > num("pull_max_time", 2.5):
		_end_pull()
		return
	vel = to.normalized() * num("pull_speed", 20.0)
	var step: Vector3 = vel * dt
	if step.length() > to.length():
		step = to
	var res: Dictionary = Gadget.move_body(bolt, step)
	bolt.motor.vel = vel
	if (res["moved"] as Vector3).length() < step.length() * 0.2:
		_stuck_t += dt
		if _stuck_t > 0.25:
			_end_pull()
	else:
		_stuck_t = 0.0


func _end_pull() -> void:
	# over the lip: toward the ring from the landing point (the landing point sits on the approach side)
	var h: Vector3 = anchor - _pull_goal
	h.y = 0.0
	if h.length_squared() > 0.04:
		_mantle_dir = h.normalized()
		var p: Vector3 = bolt.global_position
		var top: float = anchor.y + num("mantle_up", 1.2)
		_mantle = [Vector3(p.x, maxf(p.y, top), p.z), Vector3(anchor.x, top, anchor.z) + _mantle_dir * num("mantle_in", 1.4)]
		state = State.MANTLE
		state_t = 0.0
		_stuck_t = 0.0
		return
	h = _pull_goal - _pull_from
	h.y = 0.0
	h = h.normalized() * num("pull_hop_forward", 3.5) if h.length_squared() > 1e-4 else Vector3.ZERO
	_finish(Vector3(h.x, num("pull_hop", 6.0), h.z))


func _do_mantle(dt: float) -> void:
	state_t += dt
	if _mantle.is_empty() or state_t > 1.5:
		_finish(_mantle_dir * num("mantle_exit_speed", 2.0))
		return
	var goal: Vector3 = _mantle[0]
	var to: Vector3 = goal - bolt.global_position
	var step: Vector3 = to.normalized() * num("mantle_speed", 8.0) * dt if to.length() > 1e-4 else Vector3.ZERO
	if step.length() > to.length():
		step = to
	var res: Dictionary = Gadget.move_body(bolt, step)
	vel = step / maxf(dt, 1e-4)
	bolt.motor.vel = vel
	var close: bool = bolt.global_position.distance_to(goal) < 0.05
	if not close and (res["moved"] as Vector3).length() < step.length() * 0.2:
		_stuck_t += dt
	if close or _stuck_t > 0.2:
		_mantle.remove_at(0)
		_stuck_t = 0.0


## Let go. `boost` adds the release lift (4 m/s up); a landing lets go without it.
func release(boost: bool = true) -> void:
	if state == State.FLY:
		state = State.IDLE
		target = null
		cd = num("refire", 0.25)
		return
	if state == State.IDLE:
		return
	var v: Vector3 = vel
	if boost and state == State.SWING:
		v.y += num("release_up", 4.0)
	_finish(v)


func _finish(v: Vector3) -> void:
	last_release_vel = v
	Gadget.release_body(bolt, self, v)
	state = State.IDLE
	target = null
	cd = num("refire", 0.25)
	if _cable != null:
		_cable.visible = false
	released.emit(v)
	ended.emit(self)


func cancel() -> void:
	if state == State.SWING or state == State.PULL or state == State.MANTLE:
		_finish(Vector3.ZERO)
	state = State.IDLE
	target = null


func _in_water() -> bool:
	var p: Vector3 = bolt.global_position
	for wz: AABB in bolt.water_zones:
		if wz.has_point(Vector3(p.x, p.y - bolt.motor.hy + 0.01, p.z)):
			return true
	return false


# ------------------------------------------------------------------ cable + Sprocket as the anchor

func _process(_delta: float) -> void:
	if _cable == null:
		return
	if state == State.IDLE or bolt == null or not is_instance_valid(bolt) or target == null or not is_instance_valid(target):
		_cable.visible = false
		return
	if target is TetherPoint:
		(target as TetherPoint).highlight(true)
	var hand: Vector3 = bolt.global_position + Vector3(0, 0.45, 0)
	var ring: Vector3 = target.global_position
	var tip: Vector3 = ring
	if state == State.FLY:
		tip = hand.lerp(ring, clampf(state_t / maxf(0.01, num("fly_time", 0.12)), 0.0, 1.0))
	var length: float = hand.distance_to(tip)
	_cable.visible = length > 0.05
	if _cable.visible:
		var mid: Vector3 = (hand + tip) * 0.5
		var d: Vector3 = (tip - hand) / length
		var up: Vector3 = Vector3.UP if absf(d.y) < 0.98 else Vector3.FORWARD
		_cable.transform = Transform3D(Basis.looking_at(d, up), mid)
		_cable.scale = Vector3(1, 1, length)
	var s: Node3D = get_tree().get_first_node_in_group(&"sprocket") as Node3D
	if s != null:
		s.global_position = tip + LevelKit.v3(def.get("sprocket_anchor_offset"), Vector3(0, 0.45, 0))
		if "vel" in s:
			s.set("vel", Vector3.ZERO)
