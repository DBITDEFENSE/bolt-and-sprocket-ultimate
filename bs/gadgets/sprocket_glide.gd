class_name SprocketGlide
extends Gadget
## The Sprocket Glide (BS_LEVELS §0.5, §6.2): Local 404's husk-silk solidarity sail. Sprocket is the sail.
##   Engages when JUMP is held while falling after the hover meter is empty (airborne, not slamming or dashing,
##            body free). Fall speed capped at `fall_cap` (3 m/s), forward speed `forward_speed` (9 m/s, accel
##            6 m/s²) along the glide heading, which turns toward the move input at `turn_rate` (120°/s).
##   Updrafts lift a glide: inside any "updrafts" node that contains Bolt (NovaUpdraft, CanyonUpdraft while it
##            blows) vertical speed gains the column's force up to `updraft_cap` (11 m/s).
##   Ends on landing, when JUMP is released, on a dash / slam (crouch) press, in water, or when cancelled.
##   Rule of thumb for builders: 3 m of horizontal distance per 1 m of drop.
## Every number comes from data/bs/gadgets.json "sprocket_glide". Owns Bolt's body while gliding
## (Gadget.claim_body); release hands it back with the glide velocity and the double jump ready.

signal glide_started
signal glide_ended(seconds: float, distance: float)

var gliding: bool = false
var heading: Vector3 = Vector3.FORWARD
var vel: Vector3 = Vector3.ZERO
var glide_t: float = 0.0
var glides: int = 0
var last_glide_time: float = 0.0
var last_glide_distance: float = 0.0
var lifted_t: float = 0.0            # seconds an updraft lifted a glide (tests)
var _start: Vector3 = Vector3.ZERO
var _sail: Node3D
var _sail_mat: StandardMaterial3D
var _hint_shown: bool = false


func _on_setup() -> void:
	_sail = Node3D.new()
	_sail.name = "SolidaritySail"
	_sail_mat = LevelKit.mat(def.get("colors", {}).get("sail", "#dfe6b0"), 0.35)
	var canopy: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(2.6, 0.06, 1.3)
	canopy.mesh = bm
	canopy.material_override = _sail_mat
	canopy.position = Vector3(0, 1.75, 0)
	_sail.add_child(canopy)
	for sx: float in [-1.1, 1.1]:
		var rib: MeshInstance3D = MeshInstance3D.new()
		var rm: BoxMesh = BoxMesh.new()
		rm.size = Vector3(0.06, 0.06, 1.3)
		rib.mesh = rm
		rib.material_override = LevelKit.mat(def.get("colors", {}).get("rib", "#7a4a2a"))
		rib.position = Vector3(sx, 1.74, 0)
		_sail.add_child(rib)
	for sx: float in [-0.9, 0.9]:
		var line: MeshInstance3D = MeshInstance3D.new()
		var lm: BoxMesh = BoxMesh.new()
		lm.size = Vector3(0.03, 0.9, 0.03)
		line.mesh = lm
		line.material_override = LevelKit.mat(def.get("colors", {}).get("line", "#ffd23e"), 0.6)
		line.position = Vector3(sx * 0.6, 1.3, 0)
		_sail.add_child(line)
	_sail.visible = false
	if bolt != null:
		bolt.add_child(_sail)


func busy() -> bool:
	return gliding


## The "gadget" input does nothing for the Glide (it engages from the jump hold); a press while gliding lets go.
func press() -> bool:
	if gliding:
		release()
		return true
	return false


static func jump_held(b: Bolt) -> bool:
	if not b.scripted.is_empty():
		return bool(b.scripted.get("jump_held", false))
	return b.input_enabled and not BS.blocked() and Input.is_action_pressed(&"jump")


static func dash_or_slam_pressed(b: Bolt) -> bool:
	if not b.scripted.is_empty():
		var d: bool = bool(b.scripted.get("dash_pressed", false)) or bool(b.scripted.get("crouch_pressed", false))
		if d:
			b.scripted.erase("dash_pressed")
			b.scripted.erase("crouch_pressed")
		return d
	return b.input_enabled and not BS.blocked() and (Input.is_action_just_pressed(&"dash") or Input.is_action_just_pressed(&"crouch"))


## True when the glide may engage this frame (BS_LEVELS §0.5: jump held after the hover meter is empty).
func can_engage() -> bool:
	if not can_use() or gliding or not Gadget.body_free(bolt):
		return false
	var m: BoltMotor = bolt.motor
	if m.on_ground or m.slam != &"" or m.dash_t > 0.0 or m.hovering:
		return false
	if m.hover > num("hover_empty_below", 0.02):
		return false
	if m.vel.y > -num("engage_below_vy", 0.5):
		return false
	if m.air_t < num("min_air_time", 0.15):
		return false
	return jump_held(bolt)


func _physics_process(delta: float) -> void:
	var dt: float = minf(delta, 0.05)
	if bolt == null or not is_instance_valid(bolt):
		return
	if not gliding:
		if can_engage():
			_begin()
		return
	_glide(dt)


func _begin() -> void:
	if not Gadget.claim_body(bolt, self):
		return
	gliding = true
	glides += 1
	glide_t = 0.0
	lifted_t = 0.0
	_start = bolt.global_position
	vel = bolt.motor.vel
	var flat: Vector3 = Vector3(vel.x, 0, vel.z)
	if flat.length() > 0.5:
		heading = flat.normalized()
	else:
		heading = Vector3(sin(bolt.motor.yaw), 0, cos(bolt.motor.yaw)).normalized()
	vel.y = maxf(vel.y, -num("fall_cap", 3.0))
	if _sail != null:
		_sail.visible = true
	if not _hint_shown:
		_hint_shown = true
		EventBus.bark.emit("bs.gadget.glide.first.01")
	glide_started.emit()
	used.emit(self)


func _in_water() -> bool:
	var p: Vector3 = bolt.global_position
	for wz: AABB in bolt.water_zones:
		if wz.has_point(Vector3(p.x, p.y - bolt.motor.hy + 0.01, p.z)):
			return true
	return false


func _updraft_force(p: Vector3) -> float:
	var f: float = 0.0
	for u: Node in get_tree().get_nodes_in_group(&"updrafts"):
		if not (u is Node3D) or not u.has_method("contains"):
			continue
		if u.has_method("is_blowing") and not bool(u.call("is_blowing")):
			continue
		if bool(u.call("contains", p)):
			var force: float = float(u.get("force")) if u.get("force") != null else float(u.get_meta(&"force", 30.0))
			f = maxf(f, force)
	return f


func _glide(dt: float) -> void:
	glide_t += dt
	var m: BoltMotor = bolt.motor
	# steering: turn the heading toward the move input at turn_rate
	var want: Vector3 = Gadget.move_dir(bolt)
	if want.length() > 0.1:
		var cur: float = atan2(heading.x, heading.z)
		var goal: float = atan2(want.x, want.z)
		var step: float = deg_to_rad(num("turn_rate", 120.0)) * dt
		var a: float = cur + clampf(wrapf(goal - cur, -PI, PI), -step, step)
		heading = Vector3(sin(a), 0, cos(a))
	# forward speed eases to forward_speed along the heading
	var fwd: float = Vector3(vel.x, 0, vel.z).dot(heading)
	fwd = move_toward(fwd, num("forward_speed", 9.0), num("forward_accel", 6.0) * dt)
	var side: Vector3 = Vector3(vel.x, 0, vel.z) - heading * Vector3(vel.x, 0, vel.z).dot(heading)
	side *= maxf(0.0, 1.0 - dt * num("side_damp", 4.0))
	# fall: ease to the cap; updrafts lift
	var up: float = _updraft_force(bolt.global_position)
	if up > 0.0:
		vel.y = minf(vel.y + up * dt, num("updraft_cap", 11.0))
		lifted_t += dt
	else:
		vel.y = move_toward(vel.y, -num("fall_cap", 3.0), num("fall_ease", 12.0) * dt)
	vel = heading * fwd + side + Vector3(0, vel.y, 0)
	var r: Dictionary = Gadget.move_body(bolt, vel * dt)
	m.yaw = atan2(heading.x, heading.z)
	m.update_facing(dt, m.yaw, false)
	if bool(r["floor"]) and vel.y <= 0.0:
		_finish(Vector3(vel.x, 0.0, vel.z) * 0.5, true)
		return
	if bool(r["ceiling"]):
		vel.y = minf(vel.y, 0.0)
	if bool(r["wall"]) and glide_t > 0.2:
		var n: Vector3 = r["normal"]
		var flat: Vector3 = Vector3(n.x, 0, n.z)
		if flat.length() > 0.3 and heading.dot(flat.normalized()) < -0.7:
			_finish(Vector3(0, vel.y, 0), false)
			return
	if _in_water():
		_finish(vel, false)
		return
	if not jump_held(bolt) or dash_or_slam_pressed(bolt) or bolt.dead or BS.blocked():
		release()
		return
	if glide_t > num("max_glide_time", 20.0):
		release()


## Lets go: Bolt keeps the glide velocity (the double jump is ready again by the release rule).
func release() -> void:
	if not gliding:
		return
	_finish(vel, false)


func _finish(v: Vector3, landed: bool) -> void:
	gliding = false
	last_glide_time = glide_t
	last_glide_distance = Vector2(bolt.global_position.x - _start.x, bolt.global_position.z - _start.z).length()
	Gadget.release_body(bolt, self, v, false)
	if landed:
		bolt.motor.on_ground = true
		bolt.motor.vel.y = 0.0
	if _sail != null:
		_sail.visible = false
	glide_ended.emit(last_glide_time, last_glide_distance)
	ended.emit(self)


func cancel() -> void:
	if gliding:
		_finish(Vector3.ZERO, false)


func _process(delta: float) -> void:
	if _sail == null or not gliding:
		return
	_sail.rotation.y = 0.0
	_sail.rotation.z = sin(glide_t * 3.0) * 0.06
	_sail.rotation.x = -0.12
	_sail_mat.emission_energy_multiplier = 0.35 + 0.15 * sin(glide_t * 6.0)
	var _u: float = delta
