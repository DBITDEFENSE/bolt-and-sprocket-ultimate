class_name CoolantValve
extends StaticBody3D
## A coolant leak and its valve wheel in the Coolant Lagoon (BS_LEVELS §6.10, BS_ENEMIES §4.6). While the leak
## is `open` a glowing coolant jet sprays onto the arena floor at `jet` (standing in it: `jet_dmg` every
## `jet_every` s) and the Compost King heals from it. Sealing = three mallet hits on the wheel (a thrown mallet
## counts: group "mallet_switches", on_mallet) or an interact at the wheel (the InteractPoint child; the brief's
## 2 s hold is a press here). A sealed valve can be cracked open again by the boss (set_open(true)) with a
## 1.0 s hiss telegraph. Signals sealed / reopened; the arena relays them to the boss and drains a murk third.

signal sealed(valve: CoolantValve)
signal reopened(valve: CoolantValve)

var valve_id: String = ""
var open: bool = true
var hits: int = 0
var hits_to_seal: int = 3
var jet: Vector3 = Vector3.ZERO
var jet_r: float = 1.8
var jet_dmg: float = 4.0
var jet_every: float = 0.5
var seals: int = 0
var jet_hits: int = 0
var _jet_t: float = 0.0
var _crack_t: float = 0.0
var _wheel: Node3D
var _jet_mesh: MeshInstance3D
var _jet_mat: StandardMaterial3D
var _puddle: MeshInstance3D
var _light: OmniLight3D
var _interact: InteractPoint
var _t: float = 0.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group(&"mallet_switches")
	add_to_group(&"coolant_valves")
	add_to_group(&"damageable")
	add_to_group(&"enemies")
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = Vector3(1.6, 1.6, 1.0)
	cs.shape = sh
	cs.position.y = 0.6
	add_child(cs)
	# the pipe and the wheel
	LevelKit.cylinder(self, Vector3(0, 0.6, -0.4), 0.35, 1.4, "#8a95a8", false, "z")
	_wheel = Node3D.new()
	_wheel.position = Vector3(0, 0.7, 0.2)
	add_child(_wheel)
	var ring: MeshInstance3D = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = 0.52
	tm.outer_radius = 0.7
	ring.mesh = tm
	ring.material_override = LevelKit.mat("#d42f2f", 0.4)
	ring.rotation_degrees.x = 90.0
	_wheel.add_child(ring)
	for i: int in 4:
		LevelKit.box(_wheel, Vector3.ZERO, Vector3(1.2, 0.08, 0.08), "#d8dee9", false, Vector3(0, 0, 45.0 + 90.0 * i))
	var lbl: Label3D = Label3D.new()
	lbl.text = "LEAK " + valve_id
	lbl.font_size = 40
	lbl.pixel_size = 0.008
	lbl.position = Vector3(0, 1.75, 0.2)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = Color("#39ff88")
	add_child(lbl)
	# the jet: a glowing cone from the pipe to the floor spot, plus a puddle there
	_jet_mesh = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = jet_r * 0.8
	cm.height = 1.0
	cm.cap_top = false
	cm.cap_bottom = false
	_jet_mesh.mesh = cm
	_jet_mat = NovaArt.glow("#39ff88", 0.35, 1.6)
	_jet_mesh.material_override = _jet_mat
	add_child(_jet_mesh)
	_puddle = MeshInstance3D.new()
	var pm: CylinderMesh = CylinderMesh.new()
	pm.top_radius = jet_r
	pm.bottom_radius = jet_r
	pm.height = 0.08
	_puddle.mesh = pm
	_puddle.material_override = LevelKit.mat("#39ff88", 1.4)
	add_child(_puddle)
	_light = OmniLight3D.new()
	_light.light_color = Color("#39ff88")
	_light.light_energy = 1.6
	_light.omni_range = 7.0
	add_child(_light)
	_interact = InteractPoint.new()
	_interact.name = "Interact"
	_interact.prompt = "Seal the valve"
	_interact.radius = 2.4
	_interact.position = Vector3(0, 0.2, 1.2)
	_interact.interacted.connect(func(_p: InteractPoint, _b: Node) -> void: seal())
	add_child(_interact)
	_layout_jet()
	_apply_state()


func _layout_jet() -> void:
	if not is_inside_tree():
		return
	var foot: Vector3 = to_local(jet)
	var top: Vector3 = Vector3(0, 0.6, 0.3)
	var d: Vector3 = foot - top
	_jet_mesh.position = (top + foot) * 0.5
	var cm: CylinderMesh = _jet_mesh.mesh as CylinderMesh
	cm.height = maxf(0.5, d.length())
	if d.length() > 0.01:
		_jet_mesh.look_at_from_position(_jet_mesh.position, _jet_mesh.position + d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.FORWARD)
		_jet_mesh.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	_puddle.position = foot + Vector3(0, 0.05, 0)
	_light.position = foot + Vector3(0, 0.8, 0)


func _apply_state() -> void:
	if _jet_mesh == null:
		return                                   # before _ready: _ready applies the state after building
	_jet_mesh.visible = open
	_puddle.visible = open
	_light.visible = open
	if _interact != null:
		_interact.enabled = open
		_interact.prompt = "Seal the valve" if open else ""


func is_open() -> bool:
	return open


## Damageable contract for the mallet strike (BoltMelee hits "enemies" in reach): a melee hit is a wheel hit;
## guns do nothing to it. Never "dies": sealing just closes it.
func is_alive() -> bool:
	return open


func get_center() -> Vector3:
	return global_position + Vector3(0, 0.7, 0.2)


var radius: float = 0.8


func take_damage(hit: Combat.Hit) -> bool:
	if not open or not hit.is_melee:
		return false
	on_mallet(hit.source)
	return false


## A mallet hit on the wheel (BoltMelee calls on_mallet for the throw; the planet calls it for the strike).
func on_mallet(_bolt: Node) -> void:
	if not open:
		return
	hits += 1
	_wheel.rotation.z += 0.6
	if hits >= hits_to_seal:
		seal()


func seal() -> void:
	if not open:
		return
	open = false
	hits = 0
	seals += 1
	_apply_state()
	sealed.emit(self)


## The boss cracks a sealed valve open again (after its 1 s hiss telegraph).
func set_open(on: bool) -> void:
	if open == on:
		return
	open = on
	hits = 0
	_apply_state()
	if on:
		reopened.emit(self)


func _physics_process(delta: float) -> void:
	_t += delta
	_jet_t -= delta
	if not open:
		return
	if _jet_mat != null:
		_jet_mat.albedo_color.a = 0.28 + 0.1 * sin(_t * 9.0)
	_wheel.rotation.z += delta * 0.4
	var b: Bolt = LevelKit.player(get_tree()) as Bolt
	if b == null or b.dead:
		return
	var p: Vector3 = b.global_position
	if Vector2(p.x - jet.x, p.z - jet.z).length() < jet_r and absf((p.y - b.motor.hy) - jet.y) < 1.6 and _jet_t <= 0.0:
		_jet_t = jet_every
		jet_hits += 1
		var h: Combat.Hit = Combat.Hit.make(jet_dmg, Combat.Type.ENERGY, self)
		h.weapon_id = &"coolant_jet"
		b.take_damage(h, true)
