class_name Gadget
extends Node
## Base of every Bolt & Sprocket gadget (BS_LEVELS §0.5): the Tether-Hook first, then Grind Soles, Sprocket
## Glide and anything later. A gadget is a child of Bolt's GadgetManager ("Gadgets"); the manager creates it
## when BS flag "gadget.<id>" is set, routes the "gadget" input to press(), and ticks nothing itself: each
## gadget runs its own _physics_process (process_physics_priority 10, so after Bolt's own step).
##
## Body takeover: a gadget (or a ride such as a zip line) that moves Bolt itself claims the body with
## claim_body(bolt, owner): Bolt's own _physics_process is paused, the owner moves the CharacterBody3D with
## move_body() and gives it back with release_body(), which restores a clean airborne motor state. Only one
## owner at a time (meta "bs_body_owner"); everything else checks body_free(bolt) first.
##
## Override: press() -> bool, busy() -> bool, cancel(), _on_setup().

signal used(gadget: Gadget)
signal ended(gadget: Gadget)

const OWNER_META: StringName = &"bs_body_owner"

var gadget_id: StringName = &""
var def: Dictionary = {}
var manager: Node = null
var bolt: Bolt = null


func setup(mgr: Node, id: StringName, d: Dictionary, b: Bolt) -> void:
	manager = mgr
	gadget_id = id
	def = d
	bolt = b
	name = String(id).to_pascal_case()
	process_physics_priority = 10
	process_priority = 10
	_on_setup()


func _on_setup() -> void:
	pass


## The gadget input was pressed. Returns true when something happened.
func press() -> bool:
	return false


## True while the gadget is doing something (attached, flying, gliding...).
func busy() -> bool:
	return false


## Stop at once (death, cutscene, respawn).
func cancel() -> void:
	pass


func can_use() -> bool:
	return bolt != null and is_instance_valid(bolt) and not bolt.dead and not BS.blocked()


func num(key: String, fallback: float = 0.0) -> float:
	return float(def.get(key, fallback))


# ------------------------------------------------------------------ body takeover (shared with rides)

static func body_owner(b: Node) -> Node:
	if b == null or not is_instance_valid(b) or not b.has_meta(OWNER_META):
		return null
	var o: Variant = b.get_meta(OWNER_META)
	return o as Node if o is Node and is_instance_valid(o) else null


static func body_free(b: Node) -> bool:
	return body_owner(b) == null


## Pauses Bolt's own movement step; `who` moves him until release_body(). False if someone else has him.
static func claim_body(b: Bolt, who: Node) -> bool:
	var cur: Node = body_owner(b)
	if cur != null and cur != who:
		return false
	b.set_meta(OWNER_META, who)
	b.set_physics_process(false)
	b.motor.slam = &""
	b.motor.dash_t = 0.0
	if b.motor.slide_low:
		b.motor.set_slide_hitbox(false)
		b.call(&"_apply_slide_shift")      # Bolt resizes his box and moves the feet back down
	b.motor.slide_t = 0.0
	return true


## Gives Bolt back his own movement with velocity `vel`, airborne: the next jump press is the double jump
## (jumps = 1), hover is full and the air dash is available (BS_LEVELS §0.5 release rule).
static func release_body(b: Bolt, who: Node, vel: Vector3, refill_hover: bool = true) -> void:
	if b == null or not is_instance_valid(b):
		return
	if body_owner(b) == who:
		b.remove_meta(OWNER_META)
	b.set_physics_process(true)
	b.motor.vel = vel
	b.motor.on_ground = false
	b.motor.jumps = 1
	b.motor.coyote = 0.0
	b.motor.jump_buffer = 0.0
	b.motor.air_dash_used = false
	b.motor.fall_peak = b.global_position.y
	if refill_hover:
		b.motor.hover = 1.0


## Moves the claimed body by `delta` with collision, sliding along what it hits (up to 3 contacts).
## Returns {"floor": bool, "wall": bool, "ceiling": bool, "normal": Vector3 (last), "moved": Vector3}.
static func move_body(b: Bolt, delta: Vector3) -> Dictionary:
	var out: Dictionary = {"floor": false, "wall": false, "ceiling": false, "normal": Vector3.ZERO, "moved": Vector3.ZERO}
	var start: Vector3 = b.global_position
	var rem: Vector3 = delta
	for i: int in 3:
		if rem.length_squared() < 1e-10:
			break
		var c: KinematicCollision3D = b.move_and_collide(rem)
		if c == null:
			break
		var n: Vector3 = c.get_normal()
		out["normal"] = n
		if n.y > 0.5:
			out["floor"] = true
		elif n.y < -0.5:
			out["ceiling"] = true
		else:
			out["wall"] = true
		rem = c.get_remainder().slide(n)
	out["moved"] = b.global_position - start
	return out


# ------------------------------------------------------------------ input helpers (device or scripted)

## Camera-relative move direction (length 0..1). Scripted input (tests, the smoke run) wins.
static func move_dir(b: Bolt) -> Vector3:
	if not b.scripted.is_empty():
		var d: Variant = b.scripted.get("dir", Vector3.ZERO)
		return d if d is Vector3 else Vector3.ZERO
	if not b.input_enabled or BS.blocked():
		return Vector3.ZERO
	var cam_yaw: float = b.camera.yaw if b.camera != null else 0.0
	var f: Vector3 = Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	var r: Vector3 = Vector3(-f.z, 0, f.x)
	var kb: Vector2 = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): kb.y += 1.0
	if Input.is_physical_key_pressed(KEY_S): kb.y -= 1.0
	if Input.is_physical_key_pressed(KEY_D): kb.x += 1.0
	if Input.is_physical_key_pressed(KEY_A): kb.x -= 1.0
	if kb.length_squared() > 0.0:
		return (f * kb.y + r * kb.x).normalized()
	var stick: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_back", &"move_forward", 0.2)
	return f * stick.y + r * stick.x


## A jump press this frame (consumes a scripted "jump_pressed").
static func jump_pressed(b: Bolt) -> bool:
	if not b.scripted.is_empty():
		var j: bool = bool(b.scripted.get("jump_pressed", false))
		b.scripted.erase("jump_pressed")
		return j
	return b.input_enabled and not BS.blocked() and Input.is_action_just_pressed(&"jump")


static func sprint_held(b: Bolt) -> bool:
	if not b.scripted.is_empty():
		return bool(b.scripted.get("sprint", false))
	return b.input_enabled and Input.is_action_pressed(&"sprint")
