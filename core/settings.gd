extends Node
## User settings (user://settings.cfg). The full set (original SETTINGS_DEF + Gravelight and shared additions)
## is defined in data/settings_defaults.json; every mode reads it through get_value().
## set_value() applies a change immediately (audio buses, display, quality) and mirrors the settings that
## Gravelight keeps in its own GLSettings (GL_MAP), so the hub's Settings page drives both games.
## pull_from_gravelight() goes the other way, for edits made in Gravelight's own settings screen.

signal changed(key: String, value: Variant)

const PATH: String = "user://settings.cfg"
## core key -> Gravelight GLSettings key.
const GL_MAP: Dictionary = {
	"fp_fov": "fov", "mouseSens": "sensitivity", "padSens": "pad_sensitivity", "invertY": "invert_y",
	"subtitles": "subtitles", "master": "vol_master", "musicV": "vol_music", "sfxV": "vol_sfx", "voiceVol": "vol_vo",
	"hint_mode": "hint_mode", "colorblind": "colorblind", "film_grain": "film_grain", "quality": "graphics_preset",
	"shakeMul": "screen_shake", "ads_sensitivity": "ads_sensitivity", "lean_enabled": "lean_enabled",
	"classic_rules": "classic_rules",
}
## Quality presets for the non-Gravelight modes (Gravelight applies its own PRESETS).
const QUALITY: Dictionary = {
	"low": {"msaa": Viewport.MSAA_DISABLED, "scale": 0.75},
	"handheld": {"msaa": Viewport.MSAA_DISABLED, "scale": 1.0},   # T-264: Gravelight's Handheld preset, mirrored here
	"medium": {"msaa": Viewport.MSAA_DISABLED, "scale": 1.0},
	"high": {"msaa": Viewport.MSAA_2X, "scale": 1.0},
	"ultra": {"msaa": Viewport.MSAA_4X, "scale": 1.0},
}

var values: Dictionary = {}
var defaults: Dictionary = {}
var path: String = PATH   # tests point this elsewhere


func _ready() -> void:
	load_settings()
	apply_all.call_deferred()


func load_settings() -> void:
	var d: Variant = Data.table("settings_defaults")
	defaults = {}
	if d is Dictionary:
		for k: String in (d as Dictionary).keys():
			if not k.begins_with("_"):
				defaults[k] = (d as Dictionary)[k]
	values = defaults.duplicate(true)
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(path) != OK:
		return
	for key: String in values.keys():
		values[key] = cfg.get_value("settings", key, values[key])


func save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	for key: String in values.keys():
		cfg.set_value("settings", key, values[key])
	cfg.save(path)


func get_value(key: String, fallback: Variant = null) -> Variant:
	return values.get(key, fallback)


## Changes one setting, applies it now and mirrors it to Gravelight. save=false defers the disk write
## (the settings screen saves once when it closes).
func set_value(key: String, v: Variant, save: bool = true) -> void:
	values[key] = v
	_apply_key(key)
	_push_gravelight(key)
	changed.emit(key, v)
	if save:
		save_settings()


func reset_to_defaults() -> void:
	for k: String in defaults.keys():
		if k.begins_with("seen"):
			continue   # tutorial flags are progress, not preferences
		set_value(k, defaults[k], false)
	save_settings()


func apply_all() -> void:
	apply_audio()
	apply_display()
	apply_quality()


func apply_audio() -> void:
	_bus("Master", float(values.get("master", 1.0)))
	_bus("Music", float(values.get("musicV", 0.5)))
	_bus("SFX", float(values.get("sfxV", 1.0)))
	_bus("VO", float(values.get("voiceVol", 1.0)) if bool(values.get("voiceOn", true)) else 0.0)


## Window mode / vsync / frame cap. Skipped headless and for off-screen tool runs (--position), so test and
## screenshot runs never go fullscreen over whatever the user is doing.
func apply_display() -> void:
	Engine.max_fps = int(values.get("maxFps", 0))
	if not _display_allowed():
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(values.get("vsync", true)) else DisplayServer.VSYNC_DISABLED)
	var want: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_WINDOWED
	match str(values.get("windowMode", "windowed")):
		"borderless":
			want = DisplayServer.WINDOW_MODE_FULLSCREEN
		"fullscreen":
			want = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)


func apply_quality() -> void:
	if Game.mode == Game.Mode.GRAVELIGHT:
		return   # GLSettings.apply_visuals owns the viewport in Gravelight
	var p: Dictionary = QUALITY.get(str(values.get("quality", "high")), QUALITY["high"])
	var vp: Viewport = get_tree().root
	vp.msaa_3d = int(p["msaa"]) as Viewport.MSAA
	vp.scaling_3d_scale = float(p["scale"])


## Reads the mirrored keys back from Gravelight (its own settings screen writes only GLSettings).
func pull_from_gravelight() -> void:
	var gl: Node = get_node_or_null(^"/root/GLSettings")
	if gl == null:
		return
	var glv: Dictionary = gl.get("values")
	for k: String in GL_MAP.keys():
		var gk: String = GL_MAP[k]
		if not glv.has(gk):
			continue
		var v: Variant = glv[gk]
		if k == "quality" and str(v) == "custom":
			continue   # T-133: a custom Gravelight mix has no core equivalent; keep ours
		values[k] = v
	apply_all()


func _apply_key(key: String) -> void:
	match key:
		"master", "musicV", "sfxV", "voiceVol", "voiceOn":
			apply_audio()
		"windowMode", "vsync", "maxFps":
			apply_display()
		"quality":
			apply_quality()


func _push_gravelight(key: String) -> void:
	if not GL_MAP.has(key):
		return
	var gl: Node = get_node_or_null(^"/root/GLSettings")
	if gl == null:
		return
	var v: Variant = values[key]
	if key == "quality":
		v = "high" if str(v) == "ultra" else str(v)
	var glv: Dictionary = gl.get("values")
	glv[GL_MAP[key]] = v
	gl.call("save_settings")
	if bool(gl.get("active")):
		gl.call("apply_visuals")
		var ad: Node = get_node_or_null(^"/root/AudioDirector")
		if ad != null and str(GL_MAP[key]).begins_with("vol_"):
			ad.call("apply_volumes")


func _bus(bus_name: String, v: float) -> void:
	var i: int = AudioServer.get_bus_index(bus_name)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(0.0001, v)))


func _display_allowed() -> bool:
	return DisplayServer.get_name() != "headless" and not ("--position" in OS.get_cmdline_args())
