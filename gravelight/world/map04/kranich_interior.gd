class_name KranichInterior
extends Node3D
## Der Kranich's interior made readable (T-221; the owner: "too many dark areas"; data/gravelight/map04b_plane.json
## "interior"). Presentation only. Every added light is a practical with a reason and a fixture you can see, none casts
## a shadow (the zones' shadowed-light budget is untouched):
##   emergency   the battery lamps: a dim amber cage lamp low on the bulkheads, on from the start (the unpowered cabin is
##               dark, not black), a little brighter once the aux bus is thrown
##   bulkhead    the ship's own ceiling lamps the aux bus wakes: off (a faint filament) before power, then warm and bright
##   instrument  green dial glow (the flight deck)
##   impeller    the violet of the impeller core through the engine room's lead glass (Nachtglas: the one violet light)
## Plus zone_scale (the generator's power lights and lamps per zone scaled up, energy and range) and the dark plates
## under the walkway gratings (the sky showed through them as a white grid since the outer hull culls from inside).
## Pure rule: lamp_energy (the energy of a kind before / after the power) for the tests.

const DATA: String = "res://data/gravelight/map04b_plane.json"

static var disabled: bool = false

var cfg: Dictionary = {}
var powered: bool = false
var lamps: Array = []         # [OmniLight3D, kind, lens material]
var scaled: int = 0
var _power_k: float = 0.0


## A lamp kind's energy at power `k` (0 unpowered .. 1 the aux bus on).
static func lamp_energy(kind: Dictionary, k: float) -> float:
	return lerpf(float(kind.get("off", 0.0)), float(kind.get("on", 1.0)), clampf(k, 0.0, 1.0))


func _ready() -> void:
	add_to_group(&"kranich_interior")
	if disabled:
		set_process(false)
		return
	cfg = (GLData.load_json(DATA) as Dictionary).get("interior", {})
	_build_lamps()
	_build_subfloors()
	_scale_zone_lights.call_deferred()
	if not GLBus.power_activated.is_connected(_on_power):
		GLBus.power_activated.connect(_on_power)
	powered = GameState.power_on


func _on_power() -> void:
	powered = true


func _build_lamps() -> void:
	var kinds: Dictionary = cfg.get("kinds", {})
	var housing: BoxMesh = BoxMesh.new()
	housing.size = Vector3(0.26, 0.16, 0.2)
	var lens: SphereMesh = SphereMesh.new()
	lens.radius = 0.07
	lens.height = 0.14
	lens.radial_segments = 10
	lens.rings = 5
	var cage_mat: StandardMaterial3D = StandardMaterial3D.new()
	cage_mat.albedo_color = Color(0.12, 0.12, 0.11)
	cage_mat.metallic = 0.6
	cage_mat.roughness = 0.5
	for l: Variant in cfg.get("lamps", []):
		var a: Array = l
		var kind: String = str(a[3])
		var kd: Dictionary = kinds.get(kind, {})
		var p: Vector3 = Vector3(float(a[0]), float(a[1]), float(a[2]))
		var lt: OmniLight3D = OmniLight3D.new()
		lt.name = "Lamp_%s" % kind
		lt.light_color = Color(str(kd.get("color", "#ffb070")))
		lt.omni_range = float(kd.get("range", 6.0))
		lt.omni_attenuation = float(kd.get("attenuation", 1.2))
		lt.light_energy = lamp_energy(kd, 1.0 if powered else 0.0)
		lt.light_volumetric_fog_energy = float(kd.get("fog", 0.4))
		lt.shadow_enabled = false
		lt.light_specular = float(kd.get("specular", 0.6))
		lt.position = p
		lt.set_meta("zone", StringName(str(a[4])) if a.size() > 4 else &"")
		add_child(lt)
		var lm: StandardMaterial3D = StandardMaterial3D.new()
		lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lm.albedo_color = lt.light_color
		if not bool(kd.get("bare", false)):
			var h: MeshInstance3D = MeshInstance3D.new()
			h.mesh = housing
			h.material_override = cage_mat
			h.position = p + Vector3(0, 0.1, 0)
			h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(h)
			var ln: MeshInstance3D = MeshInstance3D.new()
			ln.mesh = lens
			ln.material_override = lm
			ln.position = p
			ln.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(ln)
		lamps.append([lt, kd, lm])


## The generator's own lights per zone, scaled (the power lights keep their meta "energy" for the aux bus's sweep).
func _scale_zone_lights() -> void:
	var zs: Dictionary = cfg.get("zone_scale", {})
	if zs.is_empty():
		return
	var root: Node = get_parent()
	if root == null:
		return
	for n: Node in root.find_children("*", "OmniLight3D", true, false):
		if is_ancestor_of(n):
			continue
		var l: OmniLight3D = n as OmniLight3D
		var z: String = str(l.get_meta("zone", ""))
		if not zs.has(z):
			continue
		var s: Array = zs[z]
		if l.has_meta("energy"):
			l.set_meta("energy", float(l.get_meta("energy")) * float(s[0]))
		l.light_energy *= float(s[0])
		l.omni_range *= float(s[1])
		scaled += 1
	print("[interior] %d lamps added, %d of the map's lights scaled" % [lamps.size(), scaled])


func _build_subfloors() -> void:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.03, 0.032, 0.03)
	m.roughness = 0.95
	for r: Variant in cfg.get("subfloors", []):
		var a: Array = r
		var mi: MeshInstance3D = MeshInstance3D.new()
		var pm: PlaneMesh = PlaneMesh.new()
		pm.size = Vector2(absf(float(a[2]) - float(a[0])), absf(float(a[3]) - float(a[1])))
		mi.mesh = pm
		mi.material_override = m
		mi.position = Vector3((float(a[0]) + float(a[2])) * 0.5, float(a[4]), (float(a[1]) + float(a[3])) * 0.5)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _process(delta: float) -> void:
	if GameState.power_on:
		powered = true
	_power_k = move_toward(_power_k, 1.0 if powered else 0.0, delta / 1.5)
	for e: Array in lamps:
		var lt: OmniLight3D = e[0] as OmniLight3D
		var kd: Dictionary = e[1]
		var en: float = lamp_energy(kd, _power_k)
		if bool(kd.get("flicker", false)):
			en *= 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.003 + lt.position.x)
		lt.light_energy = en
		lt.visible = en > 0.01
		(e[2] as StandardMaterial3D).albedo_color = lt.light_color * clampf(0.25 + en, 0.25, 3.0)
