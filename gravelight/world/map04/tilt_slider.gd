class_name TiltSlider
extends Node3D
## UPDATE 10 §3 (contract C6 `turbulence_tilt`, DECISIONS T-156): a loose thing on the Kranich's deck that slides
## when the floor tilts: a Nachtglas bomb casing on its cradle dolly (kind "bomb"), a stowage crate ("crate") or a
## fuel drum ("drum"). It reads the FlightController's tilt each physics frame, slides along X with KranichTilt's
## friction model, stops at the first collider in its way (a wall, a rack base: a ray on the world layer) with a
## clang, and stays where it stopped (loose cargo). A moving bomb casing kills the zombie it runs into (host only:
## the kill is a host decision; every peer slides its own copy from the same start, so they agree to a few cm).
## Visual only otherwise: no collider, nothing a zombie or a player can snag on (the navmesh is baked without it).
## Group "tilt_sliders"; data map04b.json flight.turbulence_tilt.sliders.

@export var kind: String = "crate"
@export var stick: float = 0.7        # m/s² of slope before it starts to move
@export var friction: float = 0.45    # m/s² of braking once it moves
@export var half_x: float = 0.45      # half its length along X (where its ends meet a wall)

var v: float = 0.0
var travelled: float = 0.0
var kills: int = 0
var stops: int = 0
var _fc: Node = null
var _cd_kill: float = 0.0


func _ready() -> void:
	add_to_group(&"tilt_sliders")
	match kind:
		"bomb":
			stick = 0.35
			friction = 0.2
			half_x = 0.9
		"drum":
			stick = 0.5
			friction = 0.3
			half_x = 0.35
	_build()


func _build() -> void:
	match kind:
		"bomb":
			# a casing on a four-wheel cradle dolly, lying athwartships so it rolls along X (the tilt's fall line)
			Props.block(self, Vector3(-0.7, 0.0, -0.35), Vector3(0.7, 0.12, 0.35), "iron")
			for wx: float in [-0.55, 0.55]:
				for wz: float in [-0.38, 0.38]:
					Props.cyl(self, Vector3(wx, 0.08, wz), 0.08, 0.05, "iron", Vector3(90, 0, 0))
			Props.cyl(self, Vector3(0, 0.42, 0), 0.28, 1.5, "feldgrau", Vector3(0, 0, 90))
			Props.cyl(self, Vector3(0.82, 0.42, 0), 0.2, 0.18, "iron", Vector3(0, 0, 90))   # the nose ring
			var mark: Label3D = Label3D.new()
			mark.text = "III ∫"   # the chalk: three strokes and a hook (Wren reads them in the bomb run)
			mark.font_size = 28
			mark.pixel_size = 0.004
			mark.modulate = Color(0.9, 0.9, 0.85, 0.85)
			mark.position = Vector3(0, 0.72, 0)
			mark.rotation.x = -PI * 0.5
			add_child(mark)
		"drum":
			Props.cyl(self, Vector3(0, 0.45, 0), 0.3, 0.9, "rust")
		_:
			Props.block(self, Vector3(-0.45, 0.0, -0.4), Vector3(0.45, 0.7, 0.4), "planks")
			Props.block(self, Vector3(-0.46, 0.3, -0.41), Vector3(0.46, 0.36, 0.41), "iron")


func _flight() -> Node:
	if _fc == null or not is_instance_valid(_fc):
		_fc = get_tree().get_first_node_in_group(&"flight_controller")
	return _fc


func _physics_process(delta: float) -> void:
	_cd_kill = maxf(0.0, _cd_kill - delta)
	var fc: Node = _flight()
	var angle: float = float(fc.call("tilt_angle_now")) if fc != null and fc.has_method("tilt_angle_now") else 0.0
	var side: float = float(fc.get("bank_side")) if fc != null else 1.0
	if angle <= 0.0 and absf(v) <= 0.0:
		return
	v = KranichTilt.slide_step(v, side, angle, stick, friction, delta)
	if absf(v) <= 0.0:
		return
	step(v * delta)


## Moves `dx` along X unless a collider is in the way; a stop at speed rings the hull.
func step(dx: float) -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state if is_inside_tree() else null
	var from: Vector3 = global_position + Vector3(0, 0.35, 0)
	var dir: float = signf(dx)
	var reach: float = half_x + absf(dx)
	if space != null:
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + Vector3(dir * reach, 0, 0), 1)
		var hit: Dictionary = space.intersect_ray(q)
		if not hit.is_empty():
			var free: float = maxf(0.0, absf((hit["position"] as Vector3).x - from.x) - half_x)
			global_position.x += dir * free
			travelled += free
			_stop()
			return
	global_position.x += dx
	travelled += absf(dx)
	if Net.is_authority() and kind == "bomb":
		_run_over()


func _stop() -> void:
	if absf(v) > 1.2:
		AudioDirector.play_3d("kranich_rattle", global_position + Vector3.UP * 0.4, -2.0 + minf(6.0, absf(v)), 0.15)
	v = 0.0
	stops += 1


## A rolling casing kills the first zombie in its path (bosses only stagger).
func _run_over() -> void:
	if _cd_kill > 0.0:
		return
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	if dir == null:
		return
	var tc: Dictionary = {}
	var fc: Node = _flight()
	if fc != null:
		tc = (fc.get("cfg") as Dictionary).get("turbulence_tilt", {})
	var radius: float = float(tc.get("bomb_kill_radius", 1.0))
	for z: Zombie in dir.active_zombies():
		if not z.is_active() or z.puppet:
			continue
		if not KranichTilt.bomb_hits(global_position, v, z.global_position, radius, float(tc.get("bomb_min_mps", 1.0))):
			continue
		if z is HomageBoss:
			z.force_stagger()
			continue
		z.take_damage(z.hp + 1.0, &"torso", &"tilt_bomb", 0, &"world")
		kills += 1
		_cd_kill = 0.1
		AudioDirector.play_3d("impact_flesh", z.global_position + Vector3.UP, 2.0, 0.1)
		if fc != null:
			fc.set("tilt_bomb_kills", int(fc.get("tilt_bomb_kills")) + 1)
