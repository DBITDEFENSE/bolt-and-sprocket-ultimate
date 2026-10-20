class_name PostFx
extends CanvasLayer
## Full-screen film look under the HUD: a vignette and a faint cold lift in the shadows (late-war grade).
## Film grain itself is drawn globally by the Settings overlay (respects "film_grain"). Presentation only.

const SHADER: String = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float vignette = 0.42;
uniform vec3 shadow_tint = vec3(0.86, 0.92, 1.08);
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c * shadow_tint, c, smoothstep(0.0, 0.35, lum));
	vec2 d = SCREEN_UV - 0.5;
	float v = smoothstep(0.85, 0.25, length(d * vec2(1.15, 1.0)));
	c *= mix(1.0 - vignette, 1.0, v);
	COLOR = vec4(c, 1.0);
}
"""

var _rect: ColorRect
var _mat: ShaderMaterial


func _init() -> void:
	layer = 5


func _ready() -> void:
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh: Shader = Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_rect.material = _mat
	add_child(_rect)
