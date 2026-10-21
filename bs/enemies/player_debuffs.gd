class_name PlayerDebuffs
extends Node
## Player debuffs applied by enemies (BS_ENEMIES §6) as a self-contained adapter: Bolt's motor (lead-owned)
## doesn't read these, so this node, a child of Bolt named "EnemyDebuffs", enforces them after Bolt moves.
##   SLOWED   (Lifeguard puddle, Zoning Board zone): keyed sources; the strongest wins. Each frame the part of
##            Bolt's horizontal step above the allowed speed is pulled back (teleports > 3 m are ignored).
##   CLAMPED  (Meter Maid boot clamp): Bolt's x/z are pinned for 1.0 s; he can still aim, shoot and jump in
##            place. Mashing (move/jump/dash presses) frees him after 0.6 s of mashing.
##   BLINDED  (Selfie Sentry flash): a 1.2 s white-out with a vignette on a CanvasLayer (silent).
##   sticker  cosmetic on-screen card for ~1 s (the Ambassadog's "loyalty card").
## Every debuff is also mirrored onto Bolt's "Status" node (slowed / clamped / blinded) so the HUD can show
## stamps, and Sprocket barks the first time each one lands (enemies.json lines.debuff_barks).
##
## Usage: PlayerDebuffs.of(bolt).slow(&"zoning", 0.8, 0.6)   PlayerDebuffs.of(bolt).clamp_for(1.0)

signal debuff_applied(kind: StringName)

const TELEPORT_SKIP: float = 3.0

var bolt: Node3D = null
var _slows: Dictionary = {}         # key -> [mult, seconds_left]
var clamp_t: float = 0.0
var clamp_mash_left: float = 0.0
var clamp_at: Vector3 = Vector3.ZERO
var blind_t: float = 0.0
var blind_max: float = 1.2
var sticker_t: float = 0.0
var _last_pos: Vector3 = Vector3.INF
var _layer: CanvasLayer
var _white: ColorRect
var _vignette: ColorRect
var _sticker: Label
static var _barked: Dictionary = {}


static func of(player: Node) -> PlayerDebuffs:
	if player == null or not is_instance_valid(player):
		return null
	var d: PlayerDebuffs = player.get_node_or_null("EnemyDebuffs") as PlayerDebuffs
	if d == null:
		d = PlayerDebuffs.new()
		d.name = "EnemyDebuffs"
		d.bolt = player as Node3D
		player.add_child(d)
	return d


static func reset_barks() -> void:
	_barked.clear()


func _ready() -> void:
	process_physics_priority = 10           # after Bolt's own physics step
	if bolt == null:
		bolt = get_parent() as Node3D


# ------------------------------------------------------------------ API

## Slows Bolt to `mult` of his speed while any keyed source is active (a zone refreshes it each tick).
func slow(key: StringName, mult: float, seconds: float) -> void:
	var had: bool = not _slows.is_empty()
	_slows[key] = [mult, maxf(seconds, float((_slows.get(key, [1.0, 0.0]) as Array)[1]))]
	_status(&"slowed", seconds)
	if not had:
		_bark(&"slowed")
		debuff_applied.emit(&"slowed")


func slow_mult() -> float:
	var m: float = 1.0
	for k: Variant in _slows.keys():
		m = minf(m, float((_slows[k] as Array)[0]))
	return m


func is_slowed() -> bool:
	return not _slows.is_empty()


func clamp_for(seconds: float, mash: float = 0.6) -> void:
	if bolt == null:
		return
	clamp_t = maxf(clamp_t, seconds)
	clamp_mash_left = mash
	clamp_at = bolt.global_position
	_status(&"clamped", seconds)
	_bark(&"clamped")
	debuff_applied.emit(&"clamped")


func is_clamped() -> bool:
	return clamp_t > 0.0


## A mash input while clamped (Bolt's input presses call this through _physics_process polling; tests call it).
func mash(amount: float = 0.15) -> void:
	if clamp_t <= 0.0:
		return
	clamp_mash_left -= amount
	if clamp_mash_left <= 0.0:
		clamp_t = 0.0
		_clear_status(&"clamped")


func blind(seconds: float) -> void:
	blind_t = maxf(blind_t, seconds)
	blind_max = maxf(seconds, 0.01)
	_status(&"blinded", seconds)
	_ensure_overlay()
	_bark(&"blinded")
	debuff_applied.emit(&"blinded")


func is_blinded() -> bool:
	return blind_t > 0.0


func sticker(text: String, seconds: float = 1.0) -> void:
	_ensure_overlay()
	_sticker.text = text
	sticker_t = seconds


func clear_all() -> void:
	_slows.clear()
	clamp_t = 0.0
	blind_t = 0.0
	sticker_t = 0.0
	for s: StringName in [&"slowed", &"clamped", &"blinded"]:
		_clear_status(s)
	_update_overlay()


# ------------------------------------------------------------------ loop

func _physics_process(delta: float) -> void:
	if bolt == null or not is_instance_valid(bolt):
		return
	for k: Variant in _slows.keys():
		var e: Array = _slows[k]
		e[1] = float(e[1]) - delta
		if float(e[1]) <= 0.0:
			_slows.erase(k)
	var p: Vector3 = bolt.global_position
	if clamp_t > 0.0:
		clamp_t -= delta
		_poll_mash()
		bolt.global_position = Vector3(clamp_at.x, p.y, clamp_at.z)
		_zero_motor_xz()
	elif not _slows.is_empty() and _last_pos != Vector3.INF:
		var step: Vector3 = p - _last_pos
		step.y = 0.0
		if step.length() < TELEPORT_SKIP:
			bolt.global_position = p - step * (1.0 - slow_mult())
	_last_pos = bolt.global_position
	blind_t -= delta
	sticker_t -= delta
	_update_overlay()


func _poll_mash() -> void:
	if not "scripted" in bolt:
		return
	if not (bolt.get("scripted") as Dictionary).is_empty():
		return
	for a: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back", &"jump", &"dash"]:
		if InputMap.has_action(a) and Input.is_action_just_pressed(a):
			mash()


func _zero_motor_xz() -> void:
	if not "motor" in bolt:
		return
	var m: Object = bolt.get("motor")
	if m == null:
		return
	var v: Vector3 = m.get("vel")
	m.set("vel", Vector3(0.0, v.y, 0.0))


func _status(id: StringName, seconds: float) -> void:
	var st: StatusEffects = bolt.get_node_or_null("Status") as StatusEffects if bolt != null else null
	if st != null:
		st.apply(id, seconds)


func _clear_status(id: StringName) -> void:
	var st: StatusEffects = bolt.get_node_or_null("Status") as StatusEffects if bolt != null else null
	if st != null:
		st.clear(id)


func _bark(kind: StringName) -> void:
	if _barked.has(kind):
		return
	_barked[kind] = true
	var t: Dictionary = Data.table("bs/enemies")
	var b: Dictionary = (t.get("lines_cfg", {}) as Dictionary).get("debuff_barks", {})
	if b.has(String(kind)):
		EnemyBase.register_lines()
		VOManager.play(str(b[String(kind)]))


# ------------------------------------------------------------------ overlay (white-out, sticker)

func _ensure_overlay() -> void:
	if _layer != null:
		return
	_layer = CanvasLayer.new()
	_layer.name = "DebuffOverlay"
	_layer.layer = 60
	add_child(_layer)
	_white = ColorRect.new()
	_white.color = Color(1, 1, 1, 0)
	_white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_white.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_white)
	_vignette = ColorRect.new()
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sh: Shader = Shader.new()
	sh.code = "shader_type canvas_item;\nuniform float k = 0.0;\nvoid fragment() {\n\tfloat d = distance(UV, vec2(0.5));\n\tCOLOR = vec4(0.95, 0.92, 0.85, smoothstep(0.25, 0.75, d) * k);\n}\n"
	var sm: ShaderMaterial = ShaderMaterial.new()
	sm.shader = sh
	_vignette.material = sm
	_layer.add_child(_vignette)
	_sticker = Label.new()
	_sticker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sticker.add_theme_font_size_override("font_size", 28)
	_sticker.add_theme_color_override("font_color", Color("#ff4d9d"))
	_sticker.add_theme_color_override("font_outline_color", Color.WHITE)
	_sticker.add_theme_constant_override("outline_size", 8)
	_sticker.position = Vector2(60, 140)
	_sticker.rotation = -0.12
	_sticker.visible = false
	_layer.add_child(_sticker)


func _update_overlay() -> void:
	if _layer == null:
		return
	var k: float = clampf(blind_t / blind_max, 0.0, 1.0)
	_white.color.a = k * k * 0.95
	(_vignette.material as ShaderMaterial).set_shader_parameter("k", k)
	_sticker.visible = sticker_t > 0.0
