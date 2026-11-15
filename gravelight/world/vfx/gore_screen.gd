class_name GoreScreen
extends CanvasLayer
## Blood on the lens (GoreFx.screen): when a body is opened up within arm's reach, or the player is hit, a few dark
## drops land near the edges of the view, run a little and fade in a few seconds. Subtle on purpose: nothing is
## drawn inside the middle of the screen (the crosshair, the sights and whatever is being aimed at stay clear), it
## sits under the HUD (layer 5; the HUD is 10), and it only exists with the Gore setting on "full".

const CODE: String = """
shader_type canvas_item;
render_mode blend_mix;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float amount = 0.0;      // 1 fresh -> 0 gone
uniform float seed = 0.0;
uniform float clear_radius = 0.58;
uniform vec3 tint : source_color = vec3(0.24, 0.01, 0.016);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p * vec2(0.82, 1.0));
	float keep = smoothstep(clear_radius, clear_radius + 0.32, r);       // nothing near the middle
	vec2 q = UV * vec2(1.9, 1.3) + vec2(seed, seed * 0.37);
	q.y -= (1.0 - amount) * 0.035;                                       // the drops run down as they age
	float big = smoothstep(0.71, 0.76, texture(noise_tex, q).r);
	float fine = smoothstep(0.7, 0.74, texture(noise_tex, q * 3.3 + 0.31).r) * 0.7;
	float a = max(big, fine) * keep * smoothstep(0.0, 0.55, amount);
	COLOR = vec4(tint * (0.75 + 0.25 * big), a * 0.82);
}
"""

var near_sq: float = 4.0
var _rect: ColorRect
var _mat: ShaderMaterial
var _amount: float = 0.0
var _fade: float = 3.5
var _max: float = 1.0
var _on_hurt: float = 0.3


func setup(c: Dictionary, noise: Texture2D) -> void:
	layer = 5
	var near: float = float(c.get("near_m", 2.0))
	near_sq = near * near
	_fade = maxf(0.2, float(c.get("fade_seconds", 3.5)))
	_max = float(c.get("max", 1.0))
	_on_hurt = float(c.get("on_hurt", 0.3))
	_mat = ShaderMaterial.new()
	var sh: Shader = Shader.new()
	sh.code = CODE
	_mat.shader = sh
	_mat.set_shader_parameter("noise_tex", noise)
	_mat.set_shader_parameter("clear_radius", float(c.get("clear_radius", 0.58)))
	_rect = ColorRect.new()
	_rect.name = "Spatter"
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	_rect.hide()
	add_child(_rect)
	if not GLBus.player_damaged.is_connected(_on_player_damaged):
		GLBus.player_damaged.connect(_on_player_damaged)
	set_process(false)


func amount() -> float:
	return _amount


## More blood on the lens (0..1 of a full spatter). A fresh pattern when the last one had gone.
func add(a: float) -> void:
	if a <= 0.0 or not GoreFx.enabled():
		return
	if _amount <= 0.02:
		_mat.set_shader_parameter("seed", randf() * 13.0)
	_amount = minf(_max, _amount + a)
	_mat.set_shader_parameter("amount", _amount)
	_rect.show()
	set_process(true)


func clear() -> void:
	_amount = 0.0
	_rect.hide()
	set_process(false)


func _process(delta: float) -> void:
	_amount -= delta / _fade
	if _amount <= 0.0:
		clear()
		return
	_mat.set_shader_parameter("amount", _amount)


func _on_player_damaged(player: int, dmg: float) -> void:
	if dmg > 0.0 and player == Net.local_player_id():
		add(_on_hurt)
