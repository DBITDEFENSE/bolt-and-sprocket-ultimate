class_name MenuDread
extends ColorRect
## T-243 (the owner: "make the menu better and more scary"): the main menu's dread overlay, over the 3D scene and
## under the menu's text. A heavier oval vignette with a dried-blood rim that swells on a slow heartbeat (two thumps
## about 52 times a minute), and the dread beats' dim: MenuScene.dread_dark takes the frame nearly to black while the
## inn's lights stutter out (and the Watcher steps closer). No screen read-back: one cheap pass, fine in a browser.
## The Camera Sway comfort setting scales the moving parts (DreadFx.picture_k: reduced = half, off = a still vignette);
## the dim itself is already gentle at off (MenuScene.flicker_profile).

const BPM: float = 52.0
const DIM_MAX: float = 0.8

var scene: MenuScene = null
var pulse: float = 0.0
var _t: float = 0.0
static var _shader: Shader = null


static func shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """
shader_type canvas_item;
uniform float dark = 0.0;
uniform float pulse = 0.0;
uniform float amount = 1.0;

void fragment() {
	vec2 d = UV - vec2(0.5);
	float r = length(d * vec2(1.0, 0.72));
	float vig = smoothstep(0.38, 0.92, r);
	float rim = smoothstep(0.5, 0.98, r) * (0.55 + 0.45 * pulse * amount);
	vec3 col = vec3(0.3, 0.015, 0.012) * rim;
	float a = vig * (0.42 + 0.14 * pulse * amount);
	col = mix(col, vec3(0.0), dark);
	a = max(a, dark);
	COLOR = vec4(col, clamp(a, 0.0, 1.0));
}
"""
	return _shader


func _init() -> void:
	name = "MenuDread"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	color = Color.WHITE
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = shader()
	material = m


## The heartbeat at `t` s: a thump, a softer one 0.3 s later, 0..1 (pure, tested).
static func heartbeat(t: float) -> float:
	var period: float = 60.0 / BPM
	var p: float = fmod(t, period)
	var one: float = exp(-p * 9.0)
	var two: float = exp(-maxf(0.0, p - 0.3) * 9.0) * (0.6 if p >= 0.3 else 0.0)
	return clampf(maxf(one, two), 0.0, 1.0)


func _process(delta: float) -> void:
	_t += delta
	pulse = heartbeat(_t)
	var dark: float = 0.0
	if scene != null and is_instance_valid(scene):
		dark = scene.dread_dark * DIM_MAX
	var m: ShaderMaterial = material as ShaderMaterial
	m.set_shader_parameter("pulse", pulse)
	m.set_shader_parameter("dark", dark)
	m.set_shader_parameter("amount", DreadFx.picture_k())
