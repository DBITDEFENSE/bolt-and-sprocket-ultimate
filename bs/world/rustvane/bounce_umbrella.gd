class_name BounceUmbrella
extends Node3D
## A resort umbrella bounce pad (addBouncePad and its update, index.html:8931, 9024-9036; BS_LEVELS §3.5):
## falling onto the canopy (vel.y < -1, within the canopy radius, feet within 0.8 m of its top) launches Bolt at
## `power` m/s, gives back the double jump and the air dash, cancels a slam and adds 0.4 hover.
## position = the pole's foot. The canopy top is 1.7 m above it (source).

signal bounced(power: float)

var power: float = 17.0
var radius: float = 1.7
var top: float = 1.7
var color: Variant = "#ff6ac2"
var bounces: int = 0
var _canopy: Node3D
var _squash: float = 0.0


func _ready() -> void:
	process_physics_priority = 10
	add_to_group(&"bouncers")
	LevelKit.cylinder(self, Vector3(0, 0.6, 0), 0.07, 1.2, "#d8dee9")
	_canopy = Node3D.new()
	_canopy.position.y = 1.45
	add_child(_canopy)
	LevelKit.cylinder(_canopy, Vector3.ZERO, radius, 0.7, color, false, "y", 0.12, 0.35)
	# scalloped trim: eight short panels around the rim
	for i: int in 8:
		var a: float = TAU * float(i) / 8.0
		LevelKit.box(_canopy, Vector3(cos(a) * radius * 0.92, -0.38, sin(a) * radius * 0.92), Vector3(0.5, 0.12, 0.08),
			"#f2ebe0", false, Vector3(0, -rad_to_deg(a) + 90.0, 0))


func _physics_process(delta: float) -> void:
	_squash = maxf(0.0, _squash - delta * 4.0)
	if _canopy != null:
		_canopy.scale.y = 1.0 - _squash * 0.55
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
