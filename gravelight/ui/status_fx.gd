extends CanvasLayer
## Screen distortion for status effects (the Screamer's scream): chromatic split + radial smear + a
## low-pass on the SFX bus, fading over the effect's duration. Created on demand by the Player.

const SHADER: String = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float strength = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 dir = uv - vec2(0.5);
	float k = strength * 0.012;
	vec3 col;
	col.r = texture(screen_tex, uv + dir * k).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - dir * k).b;
	vec3 blur = vec3(0.0);
	for (int i = 1; i <= 4; i++) {
		blur += texture(screen_tex, uv - dir * k * float(i) * 1.5).rgb;
	}
	col = mix(col, blur * 0.25, strength * 0.45);
	col += vec3(0.25, 0.05, 0.35) * strength * length(dir) * 0.6;
	COLOR = vec4(col, 1.0);
}
"""

var _rect: ColorRect
var _mat: ShaderMaterial
var _t: float = 0.0
var _dur: float = 1.0
var _lp_idx: int = -1


func _init() -> void:
	layer = 12


func _ready() -> void:
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh: Shader = Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)


func pulse(_effect: StringName, seconds: float) -> void:
	_t = seconds
	_dur = maxf(0.1, seconds)
	_rect.visible = true
	_set_lowpass(true)


func _process(delta: float) -> void:
	if _t <= 0.0:
		return
	_t -= delta
	var s: float = clampf(_t / _dur, 0.0, 1.0)
	_mat.set_shader_parameter("strength", s * (0.85 + sin(Time.get_ticks_msec() * 0.02) * 0.15))
	if _t <= 0.0:
		_rect.visible = false
		_set_lowpass(false)


func _exit_tree() -> void:
	_set_lowpass(false)


## Muffles game sound while screamed at (an AudioEffectLowPassFilter on the SFX bus, added once).
func _set_lowpass(on: bool) -> void:
	var bus: int = AudioServer.get_bus_index(&"SFX")
	if bus < 0:
		return
	if _lp_idx < 0:
		for i: int in AudioServer.get_bus_effect_count(bus):
			if AudioServer.get_bus_effect(bus, i) is AudioEffectLowPassFilter:
				_lp_idx = i
		if _lp_idx < 0:
			if not on:
				return
			var lp: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
			lp.cutoff_hz = 700.0
			AudioServer.add_bus_effect(bus, lp)
			_lp_idx = AudioServer.get_bus_effect_count(bus) - 1
	AudioServer.set_bus_effect_enabled(bus, _lp_idx, on)
