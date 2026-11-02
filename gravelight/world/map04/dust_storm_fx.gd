extends Node3D
## DUST STORM made visible (UPDATE 09 §5.4, DECISIONS T-148). The GroomController owns the special round (its
## timing, the burrow packs and the environment fog tween); this node follows it: while `dust_active()` is true
## the sweep cards (tall sheets of blowing sand, dust_sheet.gdshader) fade in and roll across the lake bed with
## the wind, a cloud of grit particles follows the camera, and the sky goes under the fog (fog_sky_affect up);
## when the round clears everything fades back. The cards are hidden while the air is clear (no draw calls).
## Headless (no camera) it only tracks the state.

@export var wind: Vector3 = Vector3(7.0, 0.0, 1.5)
@export var span_x: Vector2 = Vector2(-110.0, 110.0)
@export var fade_s: float = 4.0
@export var sky_affect_storm: float = 0.85

var amount: float = 0.0
var _ctrl: Node = null
var _poll_t: float = 0.0
var _on: bool = false
var _sheets: Array[Node3D] = []
var _mat: ShaderMaterial = null
var _grit: GPUParticles3D = null
var _env: Environment = null
var _sky_base: float = -1.0


func _ready() -> void:
	for c: Node in get_children():
		if c is MeshInstance3D:
			_sheets.append(c as Node3D)
			if _mat == null:
				_mat = (c as MeshInstance3D).material_override as ShaderMaterial
		elif c is GPUParticles3D:
			_grit = c as GPUParticles3D
	_apply()


func dust_on() -> bool:
	return _on


func _process(delta: float) -> void:
	_poll_t -= delta
	if _poll_t <= 0.0:
		_poll_t = 0.25
		_poll()
	var goal: float = 1.0 if _on else 0.0
	if not is_equal_approx(amount, goal):
		amount = move_toward(amount, goal, delta / maxf(fade_s, 0.1))
		_apply()
	if amount <= 0.0:
		return
	for s: Node3D in _sheets:
		s.position += wind * delta
		if s.position.x > span_x.y:
			s.position.x = span_x.x
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	if cam != null and _grit != null:
		_grit.global_position = cam.global_position + Vector3(-wind.x, 2.0, -wind.z) * 0.6


func _poll() -> void:
	if _ctrl == null or not is_instance_valid(_ctrl):
		var root: Node = get_parent()
		_ctrl = root.find_child("GroomController", true, false) if root != null else null
	_on = _ctrl != null and _ctrl.has_method("dust_active") and bool(_ctrl.call("dust_active"))


func _apply() -> void:
	if _mat != null:
		_mat.set_shader_parameter("amount", amount)
	for s: Node3D in _sheets:
		s.visible = amount > 0.01
	if _grit != null:
		_grit.emitting = amount > 0.2
	if _env == null:
		var root: Node = get_parent()
		var we: WorldEnvironment = root.find_child("WorldEnvironment", false, false) as WorldEnvironment if root != null else null
		if we != null:
			_env = we.environment
			_sky_base = _env.fog_sky_affect
	if _env != null and _sky_base >= 0.0:
		_env.fog_sky_affect = lerpf(_sky_base, sky_affect_storm, amount)
