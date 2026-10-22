class_name VerdantFireflies
extends Node3D
## Ambient fireflies for Verdant Sink: `count` lit motes drifting slowly inside `radius`, each on its own phase.
## Deco only (no colliders); cheap enough for a dozen fields.

var radius: float = 8.0
var count: int = 12
var seed_val: int = 1
var _motes: Array[MeshInstance3D] = []
var _phase: PackedFloat32Array = []
var _t: float = 0.0


func _ready() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_val
	var mat: StandardMaterial3D = LevelKit.mat("#d8ffb0", 2.2)
	for i: int in count:
		var m: MeshInstance3D = MeshInstance3D.new()
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = 0.07
		sm.height = 0.14
		m.mesh = sm
		m.material_override = mat
		m.position = Vector3(rng.randf_range(-radius, radius), rng.randf_range(0.6, 3.2), rng.randf_range(-radius, radius))
		add_child(m)
		_motes.append(m)
		_phase.append(rng.randf_range(0.0, TAU))


func _process(delta: float) -> void:
	_t += delta
	for i: int in _motes.size():
		var m: MeshInstance3D = _motes[i]
		var ph: float = _phase[i]
		m.position.x += sin(_t * 0.7 + ph) * delta * 0.6
		m.position.z += cos(_t * 0.5 + ph * 1.3) * delta * 0.6
		m.position.y += sin(_t * 1.1 + ph * 0.7) * delta * 0.25
		m.visible = fmod(_t * 0.8 + ph, 3.0) < 2.2
