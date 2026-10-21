class_name NovaLampPost
extends Node3D
## A Nova smart lamp post (BS_LEVELS §4.5): a pole, an arm and a lamp head that flashes red for the HOA
## warning before a district's walkways reverse. Posts with `tether` carry an orange cable-anchor ring
## `(T)` at `ring_h` metres: a plain Marker3D in group "tether_points" (meta kind "swing", ring_radius) that
## the Tether-Hook (builder B's gadget framework) acquires. Nothing here needs the gadget code to exist.

var post_id: String = ""
var district: String = ""
var height: float = 6.5
var ring_h: float = 7.0
var tether: bool = true
var light_color: Variant = "#cfe8ff"
var with_light: bool = true
var anchor: Marker3D = null
var _head: MeshInstance3D
var _light: OmniLight3D
var _flash_t: float = 0.0
var _t: float = 0.0
var _red: bool = false


func _ready() -> void:
	add_to_group(&"nova_lamp_posts")
	LevelKit.cylinder(self, Vector3(0, 0.15, 0), 0.32, 0.3, "#232838", true)
	LevelKit.cylinder(self, Vector3(0, height * 0.5, 0), 0.11, height, "#39404f", true)
	LevelKit.box(self, Vector3(0.55, height - 0.1, 0), Vector3(1.2, 0.12, 0.16), "#39404f", false)
	_head = LevelKit.box(self, Vector3(1.05, height - 0.28, 0), Vector3(0.6, 0.22, 0.4), light_color, false, Vector3.ZERO, 1, 2.2) as MeshInstance3D
	if with_light:
		_light = OmniLight3D.new()
		_light.position = Vector3(1.05, height - 0.6, 0)
		_light.light_color = LevelKit.color(light_color)
		_light.light_energy = 1.4
		_light.omni_range = 9.0
		add_child(_light)
	if tether:
		anchor = Marker3D.new()
		anchor.name = "TetherPoint"
		anchor.position = Vector3(0, ring_h, 0)
		anchor.add_to_group(&"tether_points")
		anchor.set_meta(&"kind", "swing")
		anchor.set_meta(&"ring_radius", 0.5)
		anchor.set_meta(&"post_id", post_id)
		add_child(anchor)
		NovaArt.ring(anchor, Vector3.ZERO, 0.5, 0.07, "#ff9d2e", 1.4, Vector3(90, 0, 0))
		LevelKit.box(self, Vector3(0, (height + ring_h) * 0.5, 0), Vector3(0.08, maxf(0.1, ring_h - height), 0.08), "#39404f", false)


## The HOA warning: the head blinks red for `seconds`.
func flash(seconds: float) -> void:
	_flash_t = maxf(_flash_t, seconds)


func flashing() -> bool:
	return _flash_t > 0.0


func _process(delta: float) -> void:
	_t += delta
	_flash_t = maxf(0.0, _flash_t - delta)
	var red: bool = _flash_t > 0.0 and fmod(_t, 0.25) < 0.16
	if red == _red:
		return
	_red = red
	_head.material_override = LevelKit.mat("#ff2a3a" if red else light_color, 3.0 if red else 2.2)
	if _light != null:
		_light.light_color = LevelKit.color("#ff2a3a" if red else light_color)
