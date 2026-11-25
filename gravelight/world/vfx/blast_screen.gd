class_name BlastScreen
extends CanvasLayer
## T-280: a near blast on the eye: a short warm flash over the view and a radial blur toward the blast for a few
## tenths of a second (assets/ours/vfx/blast/blast_screen.gdshader). Owned by BlastFx; pulse() starts one.
## Under the HUD (layer 4; GoreScreen is 5, the HUD 10). Hidden, and not processed, when nothing is on, so it costs
## nothing between blasts. Accessibility: Reduce Motion (GLSettings "reduce_motion") turns the blur off and halves
## the flash; the blur also follows the Screen Shake setting (0 = no blur).

const FLASH_MAX: float = 0.32
const FLASH_S: float = 0.16
const BLUR_S: float = 0.38

var _rect: ColorRect
var _mat: ShaderMaterial
var _flash: float = 0.0
var _blur: float = 0.0
var _flash0: float = 0.0
var _blur0: float = 0.0
var _t: float = 0.0
var _warm: int = 0
## The strongest flash / blur started (tests).
var last_flash: float = 0.0
var last_blur: float = 0.0


func setup(shader: Shader) -> void:
	layer = 4
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_rect = ColorRect.new()
	_rect.name = "BlastPulse"
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	_rect.hide()
	add_child(_rect)
	set_process(false)


## The settings' say: [flash scale, blur scale].
static func accessibility_k() -> Vector2:
	var reduce: bool = bool(GLSettings.values.get("reduce_motion", false))
	var shake: float = clampf(float(GLSettings.values.get("screen_shake", 1.0)), 0.0, 1.5)
	return Vector2(0.5 if reduce else 1.0, 0.0 if reduce else minf(1.0, shake))


## A pulse of strength `k` (0..1, 1 = standing at the blast) centred on `uv` (the blast on the screen).
## `warm` shows the pass for two frames with nothing in it (BlastFx.warm: the shader compiles at load).
func pulse(k: float, uv: Vector2, warm: bool = false) -> void:
	if _mat == null:
		return
	if warm:
		_warm = 2
		_mat.set_shader_parameter("flash", 0.0)
		_mat.set_shader_parameter("blur", 0.0)
		_rect.show()
		set_process(true)
		return
	var acc: Vector2 = accessibility_k()
	var f: float = FLASH_MAX * clampf(k, 0.0, 1.0) * acc.x
	var b: float = clampf(k, 0.0, 1.0) * acc.y
	if f <= 0.002 and b <= 0.002:
		return
	_flash0 = maxf(_flash, f)
	_blur0 = maxf(_blur, b)
	last_flash = f
	last_blur = b
	_t = 0.0
	_mat.set_shader_parameter("centre", uv.clamp(Vector2.ZERO, Vector2.ONE))
	_apply()
	_rect.show()
	set_process(true)


func _apply() -> void:
	_flash = _flash0 * exp(-_t / (FLASH_S * 0.45))
	_blur = _blur0 * clampf(1.0 - _t / BLUR_S, 0.0, 1.0)
	_mat.set_shader_parameter("flash", _flash)
	_mat.set_shader_parameter("blur", _blur * _blur)


func _process(delta: float) -> void:
	if _warm > 0:
		_warm -= 1
		if _warm == 0 and _flash0 <= 0.0:
			_rect.hide()
			set_process(false)
		return
	_t += delta
	_apply()
	if _t >= maxf(FLASH_S * 2.0, BLUR_S):
		clear()


func active() -> bool:
	return _rect != null and _rect.visible


func clear() -> void:
	_flash = 0.0
	_blur = 0.0
	_flash0 = 0.0
	_blur0 = 0.0
	_warm = 0
	if _rect != null:
		_rect.hide()
	set_process(false)
