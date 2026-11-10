class_name DreadFx
extends CanvasLayer
## The dread layer (T-231, docs/BOSS_REWORK.md section 2.2): one per local human player, created on demand
## (`DreadFx.of(player)`), under the HUD (layer 9) and over the post stack. Bosses report a 0..1 presence level and
## whether they are looking at you (`report`); the max over reporters (each forgotten 0.6 s after its last report)
## drives an oval vignette that darkens, a desaturation, a slow pulse whose rate rises with the level, a faint violet
## bloom at the frame's edge while a boss is looking at you, and two loops: the dread bed (boss_dread_bed) rising
## from silence and the pulse (boss_pulse) whose pitch follows the rate. `punch(k)` splits the colours for a moment
## (a heavy hit). Presentation only: nothing reads it back. The Camera Sway / Turbulence setting scales the picture
## (reduced = half, off = none); the sound stays, quieter.

const LAYER: int = 9
const FORGET_S: float = 0.6
const BED_DB: Vector2 = Vector2(-40.0, -12.0)
const PULSE_DB: Vector2 = Vector2(-40.0, -16.0)

var level: float = 0.0            # the eased level the picture shows
var seen: float = 0.0             # 0..1, a boss is looking at you
var _reports: Dictionary = {}     # id -> [level, seen, age]
var _rect: ColorRect
var _mat: ShaderMaterial
var _bed: AudioStreamPlayer = null
var _pulse: AudioStreamPlayer = null
var _pulse_t: float = 0.0
var _punch: float = 0.0
var _owner_player: Player = null

static var _shader: Shader = null


## The local human's dread layer (made on first use). null for bots, puppets and headless players without a camera.
static func of(p: Player) -> DreadFx:
	if p == null or not is_instance_valid(p) or not p.is_local or p.is_bot or p.bot_driven:
		return null
	var ex: Node = p.get_node_or_null("DreadFx")
	if ex is DreadFx:
		return ex as DreadFx
	var d: DreadFx = DreadFx.new()
	d.name = "DreadFx"
	d._owner_player = p
	p.add_child(d)
	return d


static func shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float level = 0.0;
uniform float pulse = 0.0;
uniform float seen = 0.0;
uniform float punch = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - vec2(0.5);
	float r = length(d * vec2(1.0, 0.82));
	vec3 col = texture(screen_tex, uv).rgb;
	if (punch > 0.001) {
		vec2 off = d * punch * 0.018;
		col.r = texture(screen_tex, uv + off).r;
		col.b = texture(screen_tex, uv - off).b;
	}
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(col, vec3(lum), level * 0.35);
	float vig = smoothstep(0.3, 0.95, r) * (0.55 * level + 0.14 * pulse * level);
	col *= 1.0 - vig;
	col += vec3(0.42, 0.2, 0.65) * smoothstep(0.5, 1.0, r) * seen * level * 0.4;
	COLOR = vec4(col, 1.0);
}
"""
	return _shader


func _init() -> void:
	layer = LAYER


func _ready() -> void:
	_rect = ColorRect.new()
	_rect.name = "Dread"
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = shader()
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)
	_bed = AudioDirector.make_loop_2d("boss_dread_bed", self, BED_DB.x)
	_pulse = AudioDirector.make_loop_2d("boss_pulse", self, PULSE_DB.x)


## A boss (or anything) reports its presence: `lvl` 0..1, `looking` when it faces the player.
func report(id: StringName, lvl: float, looking: bool) -> void:
	_reports[id] = [clampf(lvl, 0.0, 1.0), 1.0 if looking else 0.0, 0.0]


func release(id: StringName) -> void:
	_reports.erase(id)


## A heavy hit: a short colour split.
func punch(k: float = 1.0) -> void:
	_punch = maxf(_punch, clampf(k, 0.0, 1.0))


## The picture's share by the Camera Sway / Turbulence setting (full 1, reduced 0.5, off 0).
static func picture_k() -> float:
	match str(GLSettings.values.get("camera_sway", "full")):
		"off":
			return 0.0
		"reduced":
			return 0.5
	return 1.0


## The target level this frame: the max over live reports.
func target_level() -> Array:
	var lvl: float = 0.0
	var lk: float = 0.0
	for k: Variant in _reports.keys():
		var r: Array = _reports[k]
		lvl = maxf(lvl, float(r[0]))
		lk = maxf(lk, float(r[1]) * float(r[0]))
	return [lvl, lk]


func _process(delta: float) -> void:
	for k: Variant in _reports.keys():
		var r: Array = _reports[k]
		r[2] = float(r[2]) + delta
		if float(r[2]) > FORGET_S:
			_reports.erase(k)
	var tg: Array = target_level()
	var up: bool = float(tg[0]) > level
	level = lerpf(level, float(tg[0]), 1.0 - exp(-(3.0 if up else 1.2) * delta))
	seen = lerpf(seen, float(tg[1]), 1.0 - exp(-4.0 * delta))
	if level < 0.003 and _reports.is_empty():
		level = 0.0
		seen = 0.0
	_punch = maxf(0.0, _punch - delta * 4.0)
	var rate: float = lerpf(0.9, 2.3, level)   # beats per second
	_pulse_t = fmod(_pulse_t + delta * rate, 1.0)
	var pulse: float = pow(maxf(0.0, sin(_pulse_t * TAU)), 6.0)
	var pk: float = picture_k()
	_rect.visible = level * pk > 0.004 or _punch > 0.004
	_mat.set_shader_parameter("level", level * pk)
	_mat.set_shader_parameter("pulse", pulse)
	_mat.set_shader_parameter("seen", seen)
	_mat.set_shader_parameter("punch", _punch * pk)
	if _bed != null:
		_bed.volume_db = lerpf(BED_DB.x, BED_DB.y, level)
		if level > 0.01 and not _bed.playing:
			_bed.play()
		elif level <= 0.0 and _bed.playing:
			_bed.stop()
	if _pulse != null:
		_pulse.volume_db = lerpf(PULSE_DB.x, PULSE_DB.y, level)
		_pulse.pitch_scale = clampf(rate / 1.0, 0.6, 2.4)
		if level > 0.05 and not _pulse.playing:
			_pulse.play()
		elif level <= 0.0 and _pulse.playing:
			_pulse.stop()
