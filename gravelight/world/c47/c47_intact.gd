class_name C47Intact
extends Node3D
## UPDATE 12 section 5 (T-211): GRAVELIGHT ONE whole, for the in-flight cutscene (UPDATE 11 section 5.4) or any set
## that wants the aircraft: res://gravelight/world/c47/c47_intact.tscn. The model is C47Art's "intact" (the real one
## once built, else our stand-in), in the wreck frame: the nose toward -Z, the cabin floor at y 0.2, the wings at the
## keel; Selwyn's seat at (-0.35, 0.2, -5.75) (Anchor_cockpit_eye over it).
## Live: the propellers spin (`prop_rpm`, slowing to a windmill when `engines_on` is false), the exhausts glow, the
## navigation lights (red port, green starboard, white tail) and the formation lights burn (`lights_on`; a raid
## flies them dark). Everything is plain properties, so a CinemaSet can tween them.

@export var engines_on: bool = true:
	set(v):
		engines_on = v
		_apply()
@export var lights_on: bool = true:
	set(v):
		lights_on = v
		_apply()
@export var prop_rpm: float = 1300.0
@export var windmill_rpm: float = 60.0
@export var exhaust_energy: float = 1.6

var model: Node3D
var props: Array[Node3D] = []
var exhaust_lights: Array[OmniLight3D] = []
var nav_lights: Array[OmniLight3D] = []
var _rpm: float = 0.0
var _light_mats: Array[StandardMaterial3D] = []


func _ready() -> void:
	model = C47Art.instance("intact")
	if model == null:
		return
	add_child(model)
	for side: String in ["L", "R"]:
		# every LOD of a prop spins about its own node origin (the hub)
		for n: Node in model.find_children("Prop_%s_LOD*" % side, "", true, false):
			props.append(n as Node3D)
	for k: String in ["exhaust_L", "exhaust_R"]:
		var a: Node3D = model.find_child("Anchor_" + k, true, false) as Node3D
		if a != null:
			var l: OmniLight3D = OmniLight3D.new()
			l.name = "ExhaustGlow"
			l.light_color = Color(1.0, 0.45, 0.18)
			l.omni_range = 2.2
			l.shadow_enabled = false
			a.add_child(l)
			exhaust_lights.append(l)
	for spec: Array in [["light_L", Color(1.0, 0.1, 0.05)], ["light_R", Color(0.15, 1.0, 0.3)], ["light_tail", Color(1.0, 0.95, 0.85)],
			["light_top", Color(0.85, 0.9, 1.0)], ["light_belly", Color(0.85, 0.9, 1.0)]]:
		var a2: Node3D = model.find_child("Anchor_" + str(spec[0]), true, false) as Node3D
		if a2 != null:
			var nl: OmniLight3D = OmniLight3D.new()
			nl.name = "NavLight"
			nl.light_color = spec[1]
			nl.omni_range = 3.0
			nl.shadow_enabled = false
			a2.add_child(nl)
			nav_lights.append(nl)
	# the lamps' glass: this aircraft's own copies (the shared ones stay dark on the wreck)
	for mi: MeshInstance3D in WorldArt.meshes(model):
		for si: int in (mi.mesh.get_surface_count() if mi.mesh != null else 0):
			var m: Material = mi.mesh.surface_get_material(si)
			if m is StandardMaterial3D and str(m.resource_name).begins_with("c47_light"):
				var own: StandardMaterial3D = (m as StandardMaterial3D).duplicate() as StandardMaterial3D
				mi.set_surface_override_material(si, own)
				_light_mats.append(own)
	_rpm = prop_rpm if engines_on else windmill_rpm
	_apply()


func _apply() -> void:
	if not is_inside_tree():
		return
	for l: OmniLight3D in exhaust_lights:
		l.light_energy = exhaust_energy if engines_on else 0.0
	for nl: OmniLight3D in nav_lights:
		nl.light_energy = 0.8 if lights_on else 0.0
	for m: StandardMaterial3D in _light_mats:
		m.emission_energy_multiplier = 3.0 if lights_on else 0.0


func _process(delta: float) -> void:
	var target: float = prop_rpm if engines_on else windmill_rpm
	_rpm = move_toward(_rpm, target, delta * 600.0)
	var w: float = _rpm / 60.0 * TAU * delta
	for i: int in props.size():
		props[i].rotate_object_local(Vector3(0, 0, 1), w)   # both turn the same way (clockwise from behind)
