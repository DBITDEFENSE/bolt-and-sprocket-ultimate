class_name NovaCore
extends Collectible
## A Keystone Core (placeCore / updateCore / collectCore L10300-10345): a glowing green sphere in a spinning
## white ring with a faint light beam. Hidden until revealed (the planet's boss falls); touching it runs the
## level data's core actions (the director sets "core.<planet>", plays coreNova, lights the exit).
## Taken state persists in BS flag `core_flag`.

var core_flag: String = "core.nova_plaza"
var actions: Array = []
var director: Node = null
var _ring: MeshInstance3D
var _core: MeshInstance3D


func _init() -> void:
	radius = 2.2
	bob_height = 0.18


func _make_visual() -> Node3D:
	var root: Node3D = Node3D.new()
	_core = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	_core.mesh = sm
	_core.material_override = LevelKit.mat("#9dff5a", 2.4)
	root.add_child(_core)
	_ring = NovaArt.ring(root, Vector3.ZERO, 0.9, 0.06, "#ffffff", 2.0, Vector3(90, 0, 0))
	var beam: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.9
	cm.bottom_radius = 0.9
	cm.height = 12.0
	beam.mesh = cm
	beam.material_override = NovaArt.glow("#9dff5a", 0.2)
	beam.position.y = 6.0
	root.add_child(beam)
	return root


func _process(delta: float) -> void:
	super._process(delta)
	if _ring != null and is_visible_in_tree():
		_ring.rotation.z += delta * 2.0


func can_collect() -> bool:
	return not BS.flag(core_flag)


func _on_collect(bolt: Node) -> void:
	BS.set_flag(core_flag)
	if director != null and is_instance_valid(director):
		director.call("run_actions", actions, self, bolt)
	BS.save_to_profile()
