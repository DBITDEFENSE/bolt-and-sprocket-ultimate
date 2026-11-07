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
## T-133: the graphics presets. Each preset is a full set of the individual gfx_* settings (Settings > Video): picking
## a preset writes them all; changing one afterwards keeps the rest (the preset reads "Custom").
const PRESET_ORDER: PackedStringArray = ["low", "medium", "high", "ultra"]
const PRESETS: Dictionary = {
	"low": {"gfx_aa": "fxaa", "gfx_scale": 0.75, "gfx_upscaler": "fsr1", "gfx_shadows": "low", "gfx_ao": "low", "gfx_gi": false,
		"gfx_ssil": false, "gfx_ssr": false, "gfx_fog": "off", "gfx_lod": "low"},
	"medium": {"gfx_aa": "msaa2", "gfx_scale": 0.9, "gfx_upscaler": "fsr1", "gfx_shadows": "medium", "gfx_ao": "medium", "gfx_gi": false,
		"gfx_ssil": true, "gfx_ssr": false, "gfx_fog": "low", "gfx_lod": "medium"},
	"high": {"gfx_aa": "msaa2", "gfx_scale": 1.0, "gfx_upscaler": "bilinear", "gfx_shadows": "high", "gfx_ao": "high", "gfx_gi": true,
		"gfx_ssil": true, "gfx_ssr": true, "gfx_fog": "high", "gfx_lod": "high"},
	"ultra": {"gfx_aa": "msaa4_taa", "gfx_scale": 1.0, "gfx_upscaler": "bilinear", "gfx_shadows": "ultra", "gfx_ao": "ultra", "gfx_gi": true,
		"gfx_ssil": true, "gfx_ssr": true, "gfx_fog": "ultra", "gfx_lod": "ultra"},
	# T-139 (UPDATE 09 section 2c): the browser / Compatibility renderer. No anti-aliasing (no MSAA by the work order;
	# the Compatibility renderer has no FXAA / SMAA / TAA), bilinear 85% scale
	# (FSR needs Forward+), low shadows, none of SSAO / SDFGI / SSIL / SSR / volumetric fog (the Compatibility
	# renderer has none of them; WebProfile turns the maps' volumetric fog into depth fog), coarse LODs.
	"web": {"gfx_aa": "off", "gfx_scale": 0.85, "gfx_upscaler": "bilinear", "gfx_shadows": "low", "gfx_ao": "off", "gfx_gi": false,
		"gfx_ssil": false, "gfx_ssr": false, "gfx_fog": "off", "gfx_lod": "low"},
}
const WEB_PRESET: String = "web"
## The quality tiers behind the individual settings (RenderingServer's global quality, per tier).
const SHADOW_Q: Dictionary = {   # [directional atlas, positional atlas, soft filter quality 0..5]
	"low": [1024, 1024, 1], "medium": [2048, 2048, 2], "high": [4096, 4096, 3], "ultra": [8192, 8192, 4]}
const AO_Q: Dictionary = {"low": 0, "medium": 1, "high": 2, "ultra": 3}            # SSAO / SSIL quality (VERY_LOW..HIGH / ULTRA)
const FOG_Q: Dictionary = {"low": [64, 64], "high": [96, 96], "ultra": [160, 128]}   # volumetric fog [volume size, depth]
const LOD_Q: Dictionary = {"low": 2.0, "medium": 1.4, "high": 1.0, "ultra": 0.5}  # mesh LOD threshold (px): lower = more detail
const SDFGI_RAYS: Dictionary = {"low": 0, "medium": 1, "high": 2, "ultra": 4}     # RenderingServer.ENV_SDFGI_RAY_COUNT_*
const AA_MODES: PackedStringArray = ["off", "fxaa", "smaa", "msaa2", "msaa4", "msaa8", "taa", "msaa4_taa"]
const UPSCALERS: PackedStringArray = ["bilinear", "fsr1", "fsr2"]

var values: Dictionary = {
	"fov": 80.0,
	"sensitivity": 1.0,
	"ads_sensitivity": 0.8,
	"pad_sensitivity": 1.0,
	"invert_y": false,
	"subtitles": true,
	"vol_master": 1.0, "vol_music": 0.8, "vol_sfx": 1.0, "vol_vo": 1.0, "vol_jingles": 0.8, "vol_ambience": 1.0,
	"classic_rules": false,
	"egg_mode": "off",             # T-181 Easter Egg Mode: off / sparse (a few crawlers) / none (no zombies); practice, no profile progress (EggMode)
	"hint_mode": false,
	"colorblind": "off",
	"film_grain": true,
	"graphics_preset": "high",
	"zombie_smooth": true,         # T-162: the zombies' meshes interpolated between physics ticks (above 60 Hz), within the full-rate animation distance
	"smooth_motion": true,         # T-133: camera + viewmodel at the render rate, the eye interpolated (high-refresh screens)
	"brightness": 1.0,             # T-133: scales each map's own adjustment brightness (0.7..1.4)
	"gfx_sharpness": 0.4,          # T-133: the FSR sharpening (0 = sharpest, 2 = softest)
	"lean_enabled": true,
	"sprint_mode": "hold",     # hold / toggle (Update 02 §1)
	"prone_enabled": false,    # hold crouch to go prone (Update 02 §1)
	"screen_shake": 1.0,       # 0..1.5: camera shake + recoil FOV punch (weapons, explosions)
	"last_join_ip": "127.0.0.1",   # co-op: the address typed in the lobby's Join field last time
	"bots": 0,                     # AI teammates in a solo match (0-3, T-031)
	"bot_skill": "veteran",        # Bot Skill: recruit / veteran / elite (Update 03 section 7; bots.json skills + ai/skills.json)
	"bot_local_ai": true,          # one bot runs on a local LLM (Ollama) and does the map's tasks and easter egg
	"bot_bonus_perk": true,        # each bot gets one random bonus perk at match start (U02 section 5, bots.json bonus_perk)
	"bot_ee_help": "full",         # Bot Easter-Egg Help: off / ask (When Asked) / full (Full Partner, the default since T-086) (Update 04 section 5, T-067)
	"bot_ee_help_rev": 2,          # T-086: a settings file saved before this revision gets the new Full Partner default once
	"gore": "full",                # off / low / full: dismemberment and blood (MZ, T-041); the shatter VFX always shows
	"vfx_quality": "high",         # low / medium / high: particle counts, flash lights, casings, near snow, motes (U05 section 6, T-095; Effects.quality())
	"homage_bosses": true,         # the homage bosses (the Cousins on Map 0 round 10, PAUL on Kaltenbrunn round 15, THE SLENDER on Totenhafen round 25 / 45); Off = those rounds play normally
	"homage_names": "real",        # real / world: real first names on the title cards, bars and subtitles, or the in-world names only
	"objective_spoilers": "hints", # hidden / hints / full: the pause OBJECTIVES tab (Update 04 section 4, ObjectiveLog)
	"classic_hud": false,          # Update 04 section 2: true = no minimap (the v1 classic HUD)
	"minimap_rotate": true,        # the minimap turns with the player (false = north up)
	"minimap_zoom": 1,             # 0..2 (data/maps/minimap.json view_radius_m); the minimap_zoom key cycles it
	"minimap_size": 1.0,           # x the 250 px diameter
	"minimap_opacity": 0.92,
	"minimap_position": "tl",      # tl / tr
	"minimap_icon_scale": 1.0,
	"minimap_shape": "circle",     # circle / square (rounded)
	"minimap_cb_shapes": false,    # colourblind-safe: letters on the buyable shapes too
	"minimap_zombies": "firing",   # off / firing (shots reveal nearby zombies for 1 s) / always (nearby zombies)
	"minimap_fog": "visit",        # visit (areas reveal as you go) / always (the whole map)
	"aspect": "fill",              # T-100: fill (the window's content stretches to any aspect: 21:9, 32:9) / keep (16:9, letterboxed)

}
## User binding overrides: action -> {"kb": spec, "pad": spec}. A spec is a plain Dictionary (see event_to_spec).
var overrides: Dictionary = {}
var path: String = PATH   # tests point this elsewhere
## True when the last input came from a controller (prompts switch to pad glyphs).
var using_pad: bool = false

var _overlay: CanvasLayer
var _had_preset: bool = false   # T-139: a saved graphics_preset was found (else auto_detect_preset runs once)
var _cb_rect: ColorRect
var _grain_rect: ColorRect


func _ready() -> void:
	load_settings()
	if not _had_preset and DisplayServer.get_name() != "headless":
		var picked: String = auto_detect_preset()   # T-139: first launch picks low / medium / high / web from the GPU
		print("[GLSettings] first launch: graphics preset %s (%s)" % [picked, RenderingServer.get_video_adapter_name()])
		set_preset(picked)
	if OS.get_cmdline_user_args().has("--frame-log") and ResourceLoader.exists("res://gravelight/tools_src/frame_log.gd"):
		add_child((load("res://gravelight/tools_src/frame_log.gd") as GDScript).new())   # dev: a played session's frame times (not in the web build)
	_build_overlays()
	_overlay.visible = false   # Gravelight only: see activate() (T-024)
	get_tree().node_added.connect(_on_node_added)


func load_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	_had_preset = false
	if cfg.load(path) != OK:
		return
	_had_preset = cfg.has_section_key("settings", "graphics_preset")
	for key: String in values.keys():
		values[key] = cfg.get_value("settings", key, values[key])
	overrides = cfg.get_value("bindings", "overrides", {})
	if not cfg.has_section_key("settings", "bot_ee_help_rev"):
		values["bot_ee_help"] = "full"   # T-086: the default became Full Partner; an older file took "ask" as the default
		values["bot_ee_help_rev"] = 2


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
	if key == "graphics_preset" and PRESETS.has(str(v)):
		set_preset(str(v))   # T-133: a preset writes its individual settings
		return
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


## T-133: an individual graphics setting: the player's own choice, else the current preset's.
func gfx(key: String) -> Variant:
	if values.has(key):
		return values[key]
	return preset().get(key, PRESETS["high"].get(key))


## T-133: picks a preset and writes its individual settings (one save, one apply).
func set_preset(name_: String) -> void:
	if not PRESETS.has(name_):
		return
	values["graphics_preset"] = name_
	for k: Variant in (PRESETS[name_] as Dictionary).keys():
		values[str(k)] = PRESETS[name_][k]
	save_settings()
	apply_visuals()


## T-139: the presets the Settings menu offers: the desktop four, plus "web" on the Compatibility renderer.
static func preset_order(compat: bool) -> PackedStringArray:
	var out: PackedStringArray = PRESET_ORDER.duplicate()
	if compat:
		out.append(WEB_PRESET)
	return out


## T-139 (UPDATE 09 section 2c): the browser build (an HTML5 export).
static func is_web() -> bool:
	return OS.has_feature("web")


## T-139: the Compatibility (OpenGL / WebGL 2) renderer: always on the web, and on a desktop started with
## --rendering-method gl_compatibility or --rendering-driver opengl3. Tests may force it with `compat_override`.
static var compat_override: int = -1   # -1 = ask the renderer, 0 = no, 1 = yes


static func is_compat() -> bool:
	if compat_override >= 0:
		return compat_override == 1
	return is_web() or RenderingServer.get_current_rendering_method() == "gl_compatibility"


## T-139: the first-launch preset from the GPU's name, its type (RenderingDevice.DeviceType) and the renderer:
## Compatibility -> web; integrated (Intel UHD / Iris, AMD's "Radeon Graphics" / 680M / 780M) or software -> low;
## a discrete NVIDIA or AMD card -> high; anything else (unknown, Intel Arc, Apple) -> medium. Never ultra. Pure.
static func detect_preset(adapter: String, adapter_type: int, rendering_method: String) -> String:
	if rendering_method == "gl_compatibility":
		return WEB_PRESET
	var a: String = adapter.to_lower()
	if adapter_type == RenderingDevice.DEVICE_TYPE_CPU or adapter_type == RenderingDevice.DEVICE_TYPE_VIRTUAL_GPU:
		return "low"
	for sw: String in ["llvmpipe", "lavapipe", "swiftshader", "software", "microsoft basic"]:
		if a.contains(sw):
			return "low"
	if adapter_type == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU:
		return "low"
	for ig: String in ["uhd graphics", "hd graphics", "iris", "radeon(tm) graphics", "radeon graphics", "radeon vega", "vega 8",
			"vega 7", "vega 6", "610m", "660m", "680m", "740m", "760m", "780m", "880m", "890m"]:
		if a.contains(ig):
			return "low"
	var nv_amd: bool = a.contains("nvidia") or a.contains("geforce") or a.contains("quadro") or a.contains("rtx") or a.contains("amd") or a.contains("radeon")
	if adapter_type == RenderingDevice.DEVICE_TYPE_DISCRETE_GPU and nv_amd:
		return "high"
	if a.contains("geforce") or a.contains("rtx") or a.contains("radeon rx") or a.contains("radeon pro"):
		return "high"   # the type is unknown (some drivers) but the name is a discrete card's
	return "medium"


## T-139: the preset for this machine (GLSettings._ready calls it on first launch, when no preset was saved).
func auto_detect_preset() -> String:
	var method: String = "gl_compatibility" if is_compat() else str(RenderingServer.get_current_rendering_method())
	return detect_preset(RenderingServer.get_video_adapter_name(), int(RenderingServer.get_video_adapter_type()), method)


## T-133: the preset the individual settings match ("custom" when any differs). Pure over `vals`.
static func matching_preset(vals: Dictionary) -> String:
	var order: PackedStringArray = PRESET_ORDER.duplicate()
	order.append(WEB_PRESET)
	for pn: String in order:
		var ok: bool = true
		for k: Variant in (PRESETS[pn] as Dictionary).keys():
			if vals.has(str(k)) and vals[str(k)] != PRESETS[pn][k]:
				ok = false
				break
		if ok:
			return pn
	return "custom"


## T-133: the anti-aliasing mode on a viewport (MSAA, the screen-space filter, TAA).
static func apply_aa(vp: Viewport, mode: String) -> void:
	vp.msaa_3d = Viewport.MSAA_DISABLED
	if is_compat():   # T-139: screen-space AA and TAA don't exist on the Compatibility renderer (setting them warns)
		var ms: Dictionary = {"msaa2": Viewport.MSAA_2X, "msaa4": Viewport.MSAA_4X, "msaa8": Viewport.MSAA_8X}
		if mode.begins_with("msaa"):
			vp.msaa_3d = ms.get(mode.substr(0, 5), Viewport.MSAA_4X)
		return
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = false
	match mode:
		"fxaa":
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		"smaa":
			vp.screen_space_aa = ClassDB.class_get_integer_constant(&"Viewport", &"SCREEN_SPACE_AA_SMAA") as Viewport.ScreenSpaceAA \
				if ClassDB.class_has_integer_constant(&"Viewport", &"SCREEN_SPACE_AA_SMAA") else Viewport.SCREEN_SPACE_AA_FXAA
		"msaa2":
			vp.msaa_3d = Viewport.MSAA_2X
		"msaa4":
			vp.msaa_3d = Viewport.MSAA_4X
		"msaa8":
			vp.msaa_3d = Viewport.MSAA_8X
		"taa":
			vp.use_taa = true
		"msaa4_taa":
			vp.msaa_3d = Viewport.MSAA_4X
			vp.use_taa = true


func apply_visuals() -> void:
	if _cb_rect != null:
		var mode: int = maxi(0, COLORBLIND_MODES.find(str(values.get("colorblind", "off"))))
		_cb_rect.visible = mode > 0
		(_cb_rect.material as ShaderMaterial).set_shader_parameter("mode", mode)
		_grain_rect.visible = bool(values.get("film_grain", true))
	var vp: Viewport = get_tree().root
	apply_aa(vp, str(gfx("gfx_aa")))
	vp.use_debanding = true   # T-133: no banding in the dark gradients (fog, the cellar's lamplight)
	var scale: float = clampf(float(gfx("gfx_scale")), 0.5, 1.0)
	vp.scaling_3d_scale = scale
	match str(gfx("gfx_upscaler")):
		"fsr1":
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if scale < 0.999 else Viewport.SCALING_3D_MODE_BILINEAR
		"fsr2":
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2   # also a temporal AA at 100%
		_:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.fsr_sharpness = clampf(float(values.get("gfx_sharpness", 0.4)), 0.0, 2.0)
	vp.mesh_lod_threshold = float(LOD_Q.get(str(gfx("gfx_lod")), 1.0))
	var sq: Array = SHADOW_Q.get(str(gfx("gfx_shadows")), SHADOW_Q["high"])
	vp.positional_shadow_atlas_size = int(sq[1])
	RenderingServer.directional_shadow_atlas_set_size(int(sq[0]), true)
	RenderingServer.directional_soft_shadow_filter_set_quality(int(sq[2]) as RenderingServer.ShadowQuality)
	RenderingServer.positional_soft_shadow_filter_set_quality(int(sq[2]) as RenderingServer.ShadowQuality)
	var aq: int = int(AO_Q.get(str(gfx("gfx_ao")), 2))
	if not is_compat():   # T-139: the Compatibility renderer has no SSAO / SSIL / SDFGI / SSR / volumetric fog to tune
		RenderingServer.environment_set_ssao_quality(aq as RenderingServer.EnvironmentSSAOQuality, aq <= 1, 0.5, 2, 50.0, 300.0)
		RenderingServer.environment_set_ssil_quality(aq as RenderingServer.EnvironmentSSILQuality, aq <= 1, 0.5, 4, 50.0, 300.0)
		RenderingServer.environment_set_sdfgi_ray_count(int(SDFGI_RAYS.get(str(gfx("gfx_shadows")), 2)) as RenderingServer.EnvironmentSDFGIRayCount)
		RenderingServer.environment_set_ssr_roughness_quality(mini(aq, 3) as RenderingServer.EnvironmentSSRRoughnessQuality)
		var fq: Array = FOG_Q.get(str(gfx("gfx_fog")), FOG_Q["high"])
		RenderingServer.environment_set_volumetric_fog_volume_size(int(fq[0]), int(fq[1]))
		RenderingServer.environment_set_volumetric_fog_filter_active(true)
	for n: Node in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		_apply_env(n as WorldEnvironment)
	for pn: Node in get_tree().get_nodes_in_group(&"players"):
		var pl: Player = pn as Player
		if pl != null and pl.is_local and pl.camera != null and pl.camera.current:
			pl.set_smooth_view(bool(values.get("smooth_motion", true)) and DisplayServer.get_name() != "headless")
	Zombie.smooth_motion = bool(values.get("zombie_smooth", true)) and DisplayServer.get_name() != "headless"
	if active:
		apply_aspect()


## T-100 (ultrawide): the root window's content-scale aspect. The project stretches canvas_items from a 1920x1080
## base; "keep" letterboxes anything wider (a 3440x1440 monitor showed bars), "fill" uses `expand`, so the 3D view
## and the canvas grow to the screen's real width and the HUD grid (MenuKit.hud_margin) pins to its true edges.
static func aspect_mode(v: String) -> Window.ContentScaleAspect:
	return Window.CONTENT_SCALE_ASPECT_KEEP if v == "keep" else Window.CONTENT_SCALE_ASPECT_EXPAND


func apply_aspect() -> void:
	var w: Window = get_tree().root if get_tree() != null else null
	if w == null:
		return
	var want: Window.ContentScaleAspect = aspect_mode(str(values.get("aspect", "fill")))
	if w.content_scale_aspect != want:
		w.content_scale_aspect = want


## The preset gates the costly lighting a map asks for: a map's generator turns an effect on in its Environment
## (SDFGI bounce light, SSIL, SSR) and the preset can only take it away, never add it to a map that didn't want it.
## The map's own choice is remembered in the Environment's metadata ("gl_want_<effect>") the first time it is seen.
func _apply_env(we: WorldEnvironment) -> void:
	if we == null or we.environment == null:
		return
	var env: Environment = we.environment
	var allow: Dictionary = {"volumetric_fog": str(gfx("gfx_fog")) != "off", "sdfgi": bool(gfx("gfx_gi")), "ssil": bool(gfx("gfx_ssil")),
		"ssr": bool(gfx("gfx_ssr")), "ssao": str(gfx("gfx_ao")) != "off"}
	for fx: String in allow.keys():
		var key: String = "gl_want_" + fx
		if not env.has_meta(key):
			env.set_meta(key, bool(env.get(fx + "_enabled")))
		env.set(fx + "_enabled", bool(env.get_meta(key)) and bool(allow[fx]))
	# T-133: brightness scales the map's own grade (its adjustment brightness, remembered the first time)
	if not env.has_meta("gl_base_brightness"):
		env.set_meta("gl_base_brightness", env.adjustment_brightness if env.adjustment_enabled else 1.0)
	var b: float = clampf(float(values.get("brightness", 1.0)), 0.6, 1.5)
	if not is_equal_approx(b, 1.0) or env.adjustment_enabled:
		env.adjustment_enabled = true
		env.adjustment_brightness = float(env.get_meta("gl_base_brightness")) * b


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
	if get_tree() != null:   # T-100: the other modes keep the project's own aspect
		get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	if _overlay != null:
		_overlay.visible = false


func _on_node_added(n: Node) -> void:
	if n is WorldEnvironment and active:
		_apply_env.call_deferred(n as WorldEnvironment)
