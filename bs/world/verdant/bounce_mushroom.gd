class_name BounceMushroom
extends Node3D
## A bounce mushroom (Verdant Sink, BS_LEVELS §6.5): the same rule as Rustvane's BounceUmbrella (addBouncePad,
## index.html:8931, 9024-9036) on a swamp cap. Falling onto the cap (vel.y < -1, within the cap radius, feet
## within 0.8 m of its top) launches Bolt at `power` m/s (22-24 for the express lifts, 16 for puffballs), gives
## back the double jump and the air dash, cancels a slam and adds 0.4 hover. position = the stalk's foot.
## Group "bouncers".

signal bounced(power: float)

var bouncer_id: String = ""
var power: float = 22.0
var radius: float = 1.7
var top: float = 1.4
var color: Variant = "#4fc3ff"
var bounces: int = 0
var _cap: Node3D
var _squash: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	process_physics_priority = 10
	add_to_group(&"bouncers")
	set_meta(&"power", power)
	LevelKit.cylinder(self, Vector3(0, top * 0.45, 0), radius * 0.28, top * 0.9, "#c9b89a", true)
	_cap = Node3D.new()
	_cap.position.y = top - 0.25
	add_child(_cap)
	LevelKit.cylinder(_cap, Vector3.ZERO, radius, 0.5, color, false, "y", radius * 0.45, 0.9)
	LevelKit.cylinder(_cap, Vector3(0, -0.2, 0), radius * 1.02, 0.1, "#ffffff", false, "y", -1.0, 0.3)
	for i: int in 6:
		var a: float = TAU * float(i) / 6.0
		LevelKit.cylinder(_cap, Vector3(cos(a) * radius * 0.5, 0.26, sin(a) * radius * 0.5), 0.14, 0.06, "#ffffff", false, "y", -1.0, 1.4)
	var l: OmniLight3D = OmniLight3D.new()
	l.light_color = LevelKit.color(color)
	l.light_energy = 0.8
	l.omni_range = radius * 3.0
	l.position.y = top + 0.6
	add_child(l)


func _physics_process(delta: float) -> void:
	_t += delta
	_squash = maxf(0.0, _squash - delta * 4.0)
	if _cap != null:
		_cap.scale.y = 1.0 - _squash * 0.55
		_cap.scale.x = 1.0 + _squash * 0.15
		_cap.scale.z = _cap.scale.x
	var b: Bolt = LevelKit.player(get_tree()) as Bolt
	if b == null or b.dead or not Gadget.body_free(b) or b.motor.vel.y >= -1.0:
		return
	var g: Vector3 = global_position
	var p: Vector3 = b.global_position
	if Vector2(p.x - g.x, p.z - g.z).length() >= radius:
		return
	if absf((p.y - b.motor.hy) - (g.y + top)) >= 0.8:
		return
	bounce(b)


func bounce(b: Bolt) -> void:
	b.motor.vel.y = power
	b.motor.jumps = 1
	b.motor.air_dash_used = false
	b.motor.slam = &""
	b.motor.on_ground = false
	b.motor.hover = minf(1.0, b.motor.hover + 0.4)
	_squash = 1.0
	bounces += 1
	bounced.emit(power)
