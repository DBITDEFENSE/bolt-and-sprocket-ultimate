class_name BreathFog
extends Node
## Breath fog in the cold (Update 02 section 7, T-052): a faint puff every few seconds in front of each survivor's
## face whenever they are somewhere unheated (the stable, the cellar, the yard), and everywhere once the hearth has
## died (the Cousins Round). The local player sees it just under the camera; other players and bots show it at
## their mouth. One small one-shot GPUParticles3D per survivor; zombies don't breathe.

var cfg: Dictionary = {}
var fire_out: bool = false
var _puffs: Dictionary = {}      # player instance id -> [GPUParticles3D, seconds to the next breath]
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _scan: float = 0.0
static var _pm: ParticleProcessMaterial
static var _quad: QuadMesh


static func _process_mat() -> ParticleProcessMaterial:
	if _pm != null:
		return _pm
	_pm = ParticleProcessMaterial.new()
	_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_pm.emission_sphere_radius = 0.03
	_pm.direction = Vector3(0, 0.25, -1)
	_pm.spread = 18.0
	_pm.initial_velocity_min = 0.35
	_pm.initial_velocity_max = 0.6
	_pm.gravity = Vector3(0, 0.08, 0)
	_pm.damping_min = 0.4
	_pm.damping_max = 0.7
	_pm.scale_min = 0.6
	_pm.scale_max = 1.0
	_pm.scale_curve = Props._curve_tex([[0.0, 0.25], [1.0, 1.0]])
	_pm.color_ramp = Props._ramp_tex([[0.0, Color(0.85, 0.88, 0.95, 0.0)], [0.15, Color(0.85, 0.88, 0.95, 0.16)], [1.0, Color(0.85, 0.88, 0.95, 0.0)]])
	return _pm


static func _mesh() -> QuadMesh:
	if _quad != null:
		return _quad
	_quad = QuadMesh.new()
	_quad.size = Vector2(0.22, 0.22)
	_quad.material = Props._particle_mat(Color(1, 1, 1), Color(1, 1, 1), 0.0, false)
	return _quad


## True where breath shows: outside the heated rooms, or anywhere once the fire is out.
static func is_cold(zone: StringName, warm_zones: Array, hearth_out: bool) -> bool:
	return hearth_out or not warm_zones.has(String(zone))


func _process(delta: float) -> void:
	_scan -= delta
	if _scan <= 0.0:
		_scan = 1.0
		_attach_new()
	var warm: Array = cfg.get("warm_zones", ["TAPROOM", "UPSTAIRS"])
	var iv: Array = cfg.get("interval", [2.8, 4.4])
	for id: int in _puffs.keys():
		var e: Array = _puffs[id]
		var pl: Node3D = instance_from_id(id) as Node3D
		if pl == null or not is_instance_valid(pl) or not is_instance_valid(e[0]):
			_puffs.erase(id)
			continue
		e[1] = float(e[1]) - delta
		if float(e[1]) > 0.0:
			continue
		# T-095: a sprinter breathes hard: the next breath comes sooner and leaves faster (data: vfx.json
		# atmosphere.breath sprint_interval_mult / sprint_speed_scale)
		var sprinting: bool = bool(pl.get("sprinting"))
		var br: Dictionary = (Effects.vfx.get("atmosphere", {}) as Dictionary).get("breath", {}) if Effects.vfx != null else {}
		var im: float = float(br.get("sprint_interval_mult", 0.5)) if sprinting else 1.0
		e[1] = _rng.randf_range(float(iv[0]), float(iv[1])) * im
		if bool(pl.get("downed")) or bool(pl.get("spectating")) or not pl.visible:
			continue
		if is_cold(ZoneVolume.zone_at(get_tree(), pl.global_position), warm, fire_out):
			var puff: GPUParticles3D = e[0] as GPUParticles3D
			puff.speed_scale = float(br.get("sprint_speed_scale", 1.35)) if sprinting else 1.0
			puff.restart()


func _attach_new() -> void:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var pl: Node3D = n as Node3D
		if pl == null or _puffs.has(pl.get_instance_id()):
			continue
		var p: GPUParticles3D = GPUParticles3D.new()
		p.name = "BreathFog"
		p.amount = 8
		p.lifetime = 1.8
		p.one_shot = true
		p.explosiveness = 0.75
		p.emitting = false
		p.local_coords = false
		p.process_material = _process_mat()
		p.draw_pass_1 = _mesh()
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.visibility_aabb = AABB(Vector3(-2, -2, -3), Vector3(4, 4, 5))
		var cam: Camera3D = pl.get("camera") as Camera3D
		if cam != null and bool(pl.get("is_local")) and not bool(pl.get("is_bot")):
			p.position = Vector3(0.0, -0.16, -0.3)
			cam.add_child(p)
		else:
			p.position = Vector3(0.0, 1.55, -0.28)
			pl.add_child(p)
		_puffs[pl.get_instance_id()] = [p, _rng.randf_range(0.5, 3.0)]
