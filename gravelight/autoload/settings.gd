extends Node
## User settings (user://gravelight_settings.cfg), input bindings (data/input_defaults.json + saved user overrides),
## graphics presets, and the colorblind / film-grain screen overlays.

const PATH: String = "user://gravelight_settings.cfg"
const MOUSE_BUTTONS: Dictionary = {"LEFT": MOUSE_BUTTON_LEFT, "RIGHT": MOUSE_BUTTON_RIGHT, "MIDDLE": MOUSE_BUTTON_MIDDLE}
const PAD_BUTTONS: Dictionary = {
	"A": JOY_BUTTON_A, "B": JOY_BUTTON_B, "X": JOY_BUTTON_X, "Y": JOY_BUTTON_Y,
	"LEFT_SHOULDER": JOY_BUTTON_LEFT_SHOULDER, "RIGHT_SHOULDER": JOY_BUTTON_RIGHT_SHOULDER,
	"LEFT_STICK": JOY_BUTTON_LEFT_STICK, "RIGHT_STICK": JOY_BUTTON_RIGHT_STICK,
	"START": JOY_BUTTON_START, "BACK": JOY_BUTTON_BACK,
	"DPAD_UP": JOY_BUTTON_DPAD_UP, "DPAD_DOWN": JOY_BUTTON_DPAD_DOWN, "DPAD_LEFT": JOY_BUTTON_DPAD_LEFT, "DPAD_RIGHT": JOY_BUTTON_DPAD_RIGHT,
}
const PAD_AXES: Dictionary = {
	"LEFT_X": JOY_AXIS_LEFT_X, "LEFT_Y": JOY_AXIS_LEFT_Y, "RIGHT_X": JOY_AXIS_RIGHT_X, "RIGHT_Y": JOY_AXIS_RIGHT_Y,
	"TRIGGER_LEFT": JOY_AXIS_TRIGGER_LEFT, "TRIGGER_RIGHT": JOY_AXIS_TRIGGER_RIGHT,
}
const COLORBLIND_MODES: PackedStringArray = ["off", "protanopia", "deuteranopia", "tritanopia"]
const PRESETS: Dictionary = {
	"low": {"msaa": Viewport.MSAA_DISABLED, "scale": 0.75, "dir_shadow": 1024, "pos_shadow": 1024, "vol_fog": false},
	"medium": {"msaa": Viewport.MSAA_2X, "scale": 0.9, "dir_shadow": 2048, "pos_shadow": 2048, "vol_fog": true},
	"high": {"msaa": Viewport.MSAA_2X, "scale": 1.0, "dir_shadow": 4096, "pos_shadow": 4096, "vol_fog": true},
}

var values: Dictionary = {
	"fov": 80.0,
	"sensitivity": 1.0,
	"ads_sensitivity": 0.8,
	"pad_sensitivity": 1.0,
	"invert_y": false,
	"subtitles": true,
	"vol_master": 1.0, "vol_music": 0.8, "vol_sfx": 1.0, "vol_vo": 1.0, "vol_jingles": 0.8, "vol_ambience": 1.0,
	"classic_rules": false,
	"hint_mode": false,
	"colorblind": "off",
	"film_grain": true,
	"graphics_preset": "high",
	"lean_enabled": true,
	"sprint_mode": "hold",     # hold / toggle (Update 02 §1)
	"prone_enabled": false,    # hold crouch to go prone (Update 02 §1)
	"screen_shake": 1.0,       # 0..1.5: camera shake + recoil FOV punch (weapons, explosions)
	"last_join_ip": "127.0.0.1",   # co-op: the address typed in the lobby's Join field last time
	"bots": 0,                     # AI teammates in a solo match (0-3, T-031)
	"bot_skill": "regular",        # their skill preset (data/gravelight/bots.json "skills")
	"bot_local_ai": true,          # one bot runs on a local LLM (Ollama) and does the map's tasks and easter egg
	"gore": "full",                # off / low / full: dismemberment and blood (MZ, T-041); the shatter VFX always shows
	"homage_bosses": true,         # the homage bosses (HB1: the Cousins on Map 0 round 10); Off = those rounds play normally
	"homage_names": "real",        # real / world: real first names on the title cards, bars and subtitles, or the in-world names only

}
## User binding overrides: action -> {"kb": spec, "pad": spec}. A spec is a plain Dictionary (see event_to_spec).
var overrides: Dictionary = {}
var path: String = PATH   # tests point this elsewhere
## True when the last input came from a controller (prompts switch to pad glyphs).
var using_pad: bool = false

var _overlay: CanvasLayer
var _cb_rect: ColorRect
var _grain_rect: ColorRect


func _ready() -> void:
	load_settings()
	_build_overlays()
	_overlay.visible = false   # Gravelight only: see activate() (T-024)
	get_tree().node_added.connect(_on_node_added)


func load_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(path) != OK:
		return
	for key: String in values.keys():
		values[key] = cfg.get_value("settings", key, values[key])
	overrides = cfg.get_value("bindings", "overrides", {})


func save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	for key: String in values.keys():
		cfg.set_value("settings", key, values[key])
	cfg.set_value("bindings", "overrides", overrides)
	cfg.save(path)


func get_f(key: String) -> float:
	return float(values.get(key, 0.0))


## Sets a value, saves, and re-applies anything visual or audible.
func set_value(key: String, v: Variant) -> void:
	values[key] = v
	save_settings()
	apply_visuals()
	if key.begins_with("vol_") and has_node("/root/AudioDirector"):
		AudioDirector.apply_volumes()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.4):
		using_pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		using_pad = false


# ================================================================== bindings

## Short label for the key/button bound to an action, for "Hold [F]" prompts.
func action_label(action: StringName) -> String:
	return binding_label(action, using_pad)


func binding_label(action: StringName, pad: bool) -> String:
	if not InputMap.has_action(action):
		return "?"
	for ev: InputEvent in InputMap.action_get_events(action):
		if pad and ev is InputEventJoypadButton:
			var jb: InputEventJoypadButton = ev as InputEventJoypadButton
			for pad_name: String in PAD_BUTTONS.keys():
				if PAD_BUTTONS[pad_name] == jb.button_index:
					return pad_name.replace("_", " ")
		elif pad and ev is InputEventJoypadMotion:
			var jm: InputEventJoypadMotion = ev as InputEventJoypadMotion
			for axis_name: String in PAD_AXES.keys():
				if PAD_AXES[axis_name] == jm.axis:
					return axis_name.replace("_", " ") + ("+" if jm.axis_value > 0.0 else "-")
		elif not pad and ev is InputEventKey:
			var k: InputEventKey = ev as InputEventKey
			if DisplayServer.get_name() == "headless":
				return OS.get_keycode_string(k.physical_keycode)
			return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(k.physical_keycode))
		elif not pad and ev is InputEventMouseButton:
			var mb: InputEventMouseButton = ev as InputEventMouseButton
			match mb.button_index:
				MOUSE_BUTTON_LEFT: return "LMB"
				MOUSE_BUTTON_RIGHT: return "RMB"
				MOUSE_BUTTON_MIDDLE: return "MMB"
			return "Mouse %d" % mb.button_index
	return "-"


## Defaults from data, then the user's overrides on top.
func apply_bindings() -> void:
	apply_input_defaults(GLData.table("input_defaults"))
	for action: Variant in overrides.keys():
		var o: Dictionary = overrides[action]
		for slot: String in ["kb", "pad"]:
			if o.has(slot):
				_replace_slot(StringName(str(action)), slot, spec_to_event(o[slot]))


## Rebinds the keyboard/mouse or controller slot of an action (picked from the event type) and saves.
func rebind(action: StringName, ev: InputEvent) -> bool:
	var spec: Dictionary = event_to_spec(ev)
	if spec.is_empty() or not InputMap.has_action(action):
		return false
	var slot: String = "pad" if str(spec["t"]) in ["pad", "axis"] else "kb"
	var o: Dictionary = overrides.get(String(action), {})
	o[slot] = spec
	overrides[String(action)] = o
	_replace_slot(action, slot, spec_to_event(spec))
	save_settings()
	return true


func reset_bindings() -> void:
	overrides = {}
	apply_bindings()
	save_settings()


static func _is_slot(ev: InputEvent, slot: String) -> bool:
	if slot == "pad":
		return ev is InputEventJoypadButton or ev is InputEventJoypadMotion
	return ev is InputEventKey or ev is InputEventMouseButton


static func _replace_slot(action: StringName, slot: String, ev: InputEvent) -> void:
	if ev == null or not InputMap.has_action(action):
		return
	for old: InputEvent in InputMap.action_get_events(action):
		if _is_slot(old, slot):
			InputMap.action_erase_event(action, old)
	InputMap.action_add_event(action, ev)


static func event_to_spec(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		var k: InputEventKey = ev as InputEventKey
		return {"t": "key", "code": int(k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode)}
	if ev is InputEventMouseButton:
		return {"t": "mouse", "button": int((ev as InputEventMouseButton).button_index)}
	if ev is InputEventJoypadButton:
		return {"t": "pad", "button": int((ev as InputEventJoypadButton).button_index)}
	if ev is InputEventJoypadMotion:
		var jm: InputEventJoypadMotion = ev as InputEventJoypadMotion
		if absf(jm.axis_value) < 0.5:
			return {}
		return {"t": "axis", "axis": int(jm.axis), "value": signf(jm.axis_value)}
	return {}


static func spec_to_event(spec: Dictionary) -> InputEvent:
	match str(spec.get("t", "")):
		"key":
			var k: InputEventKey = InputEventKey.new()
			k.physical_keycode = int(spec["code"]) as Key
			return k
		"mouse":
			var mb: InputEventMouseButton = InputEventMouseButton.new()
			mb.button_index = int(spec["button"]) as MouseButton
			return mb
		"pad":
			var jb: InputEventJoypadButton = InputEventJoypadButton.new()
			jb.button_index = int(spec["button"]) as JoyButton
			return jb
		"axis":
			var jm: InputEventJoypadMotion = InputEventJoypadMotion.new()
			jm.axis = int(spec["axis"]) as JoyAxis
			jm.axis_value = float(spec["value"])
			return jm
	return null


## Builds the InputMap from the bindings table.
static func apply_input_defaults(bindings: Dictionary) -> void:
	for action_name: String in bindings.keys():
		if action_name.begins_with("_"):
			continue
		var b: Dictionary = bindings[action_name]
		var action: StringName = StringName(action_name)
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, 0.2)
		if b.has("key"):
			var ev: InputEventKey = InputEventKey.new()
			ev.physical_keycode = _keycode(str(b["key"]))
			InputMap.action_add_event(action, ev)
		if b.has("mouse"):
			var mb: InputEventMouseButton = InputEventMouseButton.new()
			mb.button_index = MOUSE_BUTTONS[str(b["mouse"])]
			InputMap.action_add_event(action, mb)
		if b.has("pad"):
			var jb: InputEventJoypadButton = InputEventJoypadButton.new()
			jb.button_index = PAD_BUTTONS[str(b["pad"])]
			InputMap.action_add_event(action, jb)
		if b.has("pad_axis"):
			var spec: String = str(b["pad_axis"])
			var jm: InputEventJoypadMotion = InputEventJoypadMotion.new()
			var sign_str: String = spec.right(1)
			var axis_name: String = spec.trim_suffix("+").trim_suffix("-")
			jm.axis = PAD_AXES[axis_name]
			jm.axis_value = -1.0 if sign_str == "-" else 1.0
			InputMap.action_add_event(action, jm)


static func _keycode(key_name: String) -> Key:
	match key_name:
		"Shift": return KEY_SHIFT
		"Ctrl": return KEY_CTRL
		"Space": return KEY_SPACE
		"Escape": return KEY_ESCAPE
		"Tab": return KEY_TAB
		"QuoteLeft": return KEY_QUOTELEFT
	return OS.find_keycode_from_string(key_name)


# ================================================================== graphics & overlays

const CB_SHADER: String = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform int mode = 0;
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	mat3 rgb2lms = mat3(vec3(17.8824, 3.45565, 0.0299566), vec3(43.5161, 27.1554, 0.184309), vec3(4.11935, 3.86714, 1.46709));
	mat3 lms2rgb = mat3(vec3(0.0809444479, -0.0102485335, -0.000365296938), vec3(-0.130504409, 0.0540193266, -0.00412161469), vec3(0.116721066, -0.113614708, 0.693511405));
	vec3 lms = rgb2lms * c;
	vec3 sim = lms;
	if (mode == 1) { sim.x = 2.02344 * lms.y - 2.52581 * lms.z; }
	else if (mode == 2) { sim.y = 0.494207 * lms.x + 1.24827 * lms.z; }
	else if (mode == 3) { sim.z = -0.395913 * lms.x + 0.801109 * lms.y; }
	vec3 err = c - lms2rgb * sim;
	vec3 shift = vec3(0.0, err.r * 0.7 + err.g, err.r * 0.7 + err.b);
	COLOR = vec4(clamp(c + shift, 0.0, 1.0), 1.0);
}
"""
const GRAIN_SHADER: String = """
shader_type canvas_item;
uniform float strength = 0.045;
float rnd(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	float n = rnd(SCREEN_UV * 1000.0 + vec2(TIME * 37.0, TIME * 13.0));
	COLOR = vec4(vec3(n), strength);
}
"""


func _build_overlays() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 120
	add_child(_overlay)
	_cb_rect = ColorRect.new()
	_cb_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cb_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cbm: ShaderMaterial = ShaderMaterial.new()
	var cbs: Shader = Shader.new()
	cbs.code = CB_SHADER
	cbm.shader = cbs
	_cb_rect.material = cbm
	_overlay.add_child(_cb_rect)
	_grain_rect = ColorRect.new()
	_grain_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grain_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gm: ShaderMaterial = ShaderMaterial.new()
	var gs: Shader = Shader.new()
	gs.code = GRAIN_SHADER
	gm.shader = gs
	_grain_rect.material = gm
	_overlay.add_child(_grain_rect)


func preset() -> Dictionary:
	return PRESETS.get(str(values.get("graphics_preset", "high")), PRESETS["high"])


func apply_visuals() -> void:
	if _cb_rect != null:
		var mode: int = maxi(0, COLORBLIND_MODES.find(str(values.get("colorblind", "off"))))
		_cb_rect.visible = mode > 0
		(_cb_rect.material as ShaderMaterial).set_shader_parameter("mode", mode)
		_grain_rect.visible = bool(values.get("film_grain", true))
	var p: Dictionary = preset()
	var vp: Viewport = get_tree().root
	vp.msaa_3d = int(p["msaa"]) as Viewport.MSAA
	vp.scaling_3d_scale = float(p["scale"])
	vp.positional_shadow_atlas_size = int(p["pos_shadow"])
	RenderingServer.directional_shadow_atlas_set_size(int(p["dir_shadow"]), true)
	for n: Node in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		_apply_env(n as WorldEnvironment)


func _apply_env(we: WorldEnvironment) -> void:
	if we != null and we.environment != null:
		we.environment.volumetric_fog_enabled = bool(preset()["vol_fog"])


## The shared game hosts several modes: Gravelight's bindings, screen overlays (colorblind, film grain) and
## environment presets apply only while Gravelight is active.
var active: bool = false


func activate() -> void:
	active = true
	apply_bindings()
	_overlay.visible = true
	apply_visuals()


func deactivate() -> void:
	active = false
	if _overlay != null:
		_overlay.visible = false


func _on_node_added(n: Node) -> void:
	if n is WorldEnvironment and active:
		_apply_env.call_deferred(n as WorldEnvironment)
