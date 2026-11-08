class_name MenuSettings
extends MenuScreen
## Settings with tabs: Gameplay, Controls (keyboard + controller remap), Audio, Video, Accessibility.
## LB/RB (or Q/E) switch tabs. Everything saves immediately.

const TABS: PackedStringArray = ["Gameplay", "Controls", "Audio", "Video", "Accessibility"]
const ACTION_NAMES: Dictionary = {
	"move_forward": "Move forward", "move_back": "Move back", "move_left": "Move left", "move_right": "Move right",
	"jump": "Jump", "crouch": "Crouch / slide", "sprint": "Sprint", "fire": "Fire", "ads": "Aim", "alt_fire": "Alt-fire",
	"reload": "Reload", "interact": "Use / buy", "melee": "Knife", "lethal": "Grenade", "tactical": "Tactical",
	"swap_weapon": "Swap weapon", "weapon_1": "Weapon 1", "weapon_2": "Weapon 2", "weapon_3": "Weapon 3",
	"lean_left": "Lean left", "lean_right": "Lean right", "pause": "Pause", "ui_scoreboard": "Scoreboard",
	"bot_command": "Squad orders (hold)",
	"look_left": "Look left", "look_right": "Look right", "look_up": "Look up", "look_down": "Look down",
	"dev_console": "Dev console",
	"minimap_zoom": "Minimap zoom",
	"ping": "Ping / mark (double-tap: danger)",
	"bot_mode": "Bot mode (an AI plays you)",
	"visor": "Suit visor (the Moon)",
}

var _tab: int = 0
var _waiting_action: StringName = &""
var _waiting_pad: bool = false
var _wait_label: Label


func _init() -> void:
	super._init("Settings")


func build() -> void:
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	content.add_child(tabs)
	for i: int in TABS.size():
		var b: Button = MenuKit.button(("> " if i == _tab else "") + TABS[i], _set_tab.bind(i), 20)
		b.custom_minimum_size = Vector2(190, 42)
		tabs.add_child(b)
	content.add_child(MenuKit.label("LB / RB switch tabs", 14, MenuKit.DIM))
	match _tab:
		0: _gameplay()
		1: _controls()
		2: _audio()
		3: _video()
		4: _access()


func _set_tab(i: int) -> void:
	_tab = posmod(i, TABS.size())
	_waiting_action = &""
	rebuild()


func _setter(key: String) -> Callable:
	return func(v: Variant) -> void: GLSettings.set_value(key, v)


func _gameplay() -> void:
	var v: Dictionary = GLSettings.values
	content.add_child(MenuKit.row("Field of view", MenuKit.slider(65, 110, 1, float(v["fov"]), _setter("fov"))))
	content.add_child(MenuKit.row("Screen shake", MenuKit.slider(0.0, 1.5, 0.05, float(v.get("screen_shake", 1.0)), _setter("screen_shake"))))
	content.add_child(MenuKit.row("Mouse sensitivity", MenuKit.slider(0.1, 4.0, 0.05, float(v["sensitivity"]), _setter("sensitivity"))))
	content.add_child(MenuKit.row("Aiming sensitivity (x)", MenuKit.slider(0.2, 1.5, 0.05, float(v["ads_sensitivity"]), _setter("ads_sensitivity"))))
	content.add_child(MenuKit.row("Controller look speed", MenuKit.slider(0.2, 3.0, 0.05, float(v["pad_sensitivity"]), _setter("pad_sensitivity"))))
	content.add_child(MenuKit.check("Invert look (Y)", bool(v["invert_y"]), _setter("invert_y")))
	content.add_child(MenuKit.check("Lean (Z / E)", bool(v.get("lean_enabled", true)), _setter("lean_enabled")))
	content.add_child(MenuKit.check("Classic Rules (no character traits)", bool(v["classic_rules"]), _setter("classic_rules")))
	var ht_cur: int = maxi(0, HardTruth.MODES.find(HardTruth.mode_of(v)))
	content.add_child(MenuKit.row("Hard Truth (the fourth-day rule)", MenuKit.options(HardTruth.MODE_LABELS, ht_cur,
		func(i: int) -> void: GLSettings.set_value(HardTruth.SETTING, HardTruth.MODES[i]))))
	content.add_child(MenuKit.para("A teammate who bleeds out rises as one of them four seconds later. Put them down: their kit drops where they fall. They still come back next round. In co-op the host's setting decides.", 16, MenuKit.DIM))
	var egg_cur: int = maxi(0, EggMode.MODES.find(EggMode.mode_of(v)))
	content.add_child(MenuKit.row("Easter Egg Mode (practice)", MenuKit.options(EggMode.MODE_LABELS, egg_cur,
		func(i: int) -> void: GLSettings.set_value(EggMode.SETTING, EggMode.MODES[i]))))
	content.add_child(MenuKit.para("Few Crawlers: a couple of slow crawlers a round. No Zombies: rounds pass on a short clock with none. The egg's own enemies (its bosses, holds and kill counts) still come. Practice only: no XP, challenges, stats, best rounds, unlocks, egg rewards or bank. From the next match.", 16, MenuKit.DIM))
	content.add_child(MenuKit.check("Hint mode (show the next objective)", bool(v["hint_mode"]), _setter("hint_mode")))
	var spoil: int = maxi(0, ObjectiveLog.LEVELS.find(ObjectiveLog.level(v.get("objective_spoilers", "hints"))))
	content.add_child(MenuKit.row("Objective spoilers (pause OBJECTIVES tab)", MenuKit.options(ObjectiveLog.LEVEL_NAMES, spoil,
		func(i: int) -> void: GLSettings.set_value("objective_spoilers", ObjectiveLog.LEVELS[i]))))
	content.add_child(MenuKit.check("Homage Bosses (the Cousins, PAUL, THE SLENDER)", bool(v.get("homage_bosses", true)), _setter("homage_bosses")))
	content.add_child(MenuKit.check("Bot Bonus Perk (each AI teammate gets one random perk)", bool(v.get("bot_bonus_perk", true)), _setter("bot_bonus_perk")))
	var bc: Dictionary = BotConfig.cfg()
	var skill_ids: Array = bc.get("skill_order", ["recruit", "veteran", "elite"])
	var skill_cur: int = maxi(0, skill_ids.find(BotConfig.skill_key(bc, str(v.get("bot_skill", "veteran")))))
	var skill_labels: PackedStringArray = PackedStringArray(skill_ids.map(func(k: Variant) -> String: return str(k).capitalize()))
	content.add_child(MenuKit.row("Bot Skill (AI teammates)", MenuKit.options(skill_labels, skill_cur,
		func(i: int) -> void: GLSettings.set_value("bot_skill", str(skill_ids[i])))))
	var ee_cur: int = maxi(0, BotEECatalog.MODES.find(BotEECatalog.mode_of(v)))
	content.add_child(MenuKit.row("Bot Easter-Egg Help", MenuKit.options(BotEECatalog.MODE_LABELS, ee_cur,
		func(i: int) -> void: GLSettings.set_value(BotEECatalog.SETTING, BotEECatalog.MODES[i]))))
	content.add_child(MenuKit.para("Off: bots never touch easter-egg objects. When Asked: only steps you give them (Objectives tab, a map mark, the ping key). Full Partner: they work open steps alongside you and say what they're doing; the last steps wait for you.", 16, MenuKit.DIM))
	var name_modes: PackedStringArray = ["real", "world"]
	var ncur: int = maxi(0, name_modes.find(str(v.get("homage_names", "real"))))
	content.add_child(MenuKit.row("Homage Names", MenuKit.options(PackedStringArray(["Real", "In-World"]), ncur,
		func(i: int) -> void: GLSettings.set_value("homage_names", name_modes[i]))))
	content.add_child(MenuKit.para("Homage Bosses are tributes to real people. Real shows their first names on the title cards and boss bars; In-World shows only the in-world names. In co-op the host's settings decide.", 16, MenuKit.DIM))
	m1911_rows(content)
	_minimap_rows()


## The starting pistol's cosmetic finish and Loadout Pick (UPDATE_04 section 6, M1911Kit): unlocked by lifetime
## M1911 kills. Static so the pause menu's LOADOUT tab can build the same rows into its own container.
static func m1911_rows(into: Control) -> void:
	var kills: int = ProfileSave.weapon_kills(&"m1911")
	into.add_child(MenuKit.label("M1911  (%d kills)" % kills, 22, MenuKit.GOLD))
	var rows: Array = M1911Kit.finish_rows(kills)
	var names: PackedStringArray = []
	var cur: int = 0
	for i: int in rows.size():
		var r: Dictionary = rows[i]
		names.append(str(r["name"]) if bool(r["unlocked"]) else "%s  (%d kills)" % [str(r["name"]), int(r["kills"])])
		if StringName(str(r["id"])) == M1911Kit.equipped_finish():
			cur = i
	var fin: OptionButton = MenuKit.options(names, cur, func(i: int) -> void: M1911Kit.set_finish(StringName(str(rows[i]["id"]))))
	for i2: int in rows.size():
		fin.set_item_disabled(i2, not bool(rows[i2]["unlocked"]))
	into.add_child(MenuKit.row("Finish", fin))
	var picks: Array = [""] + M1911Kit.pick_choices()
	var pick_names: PackedStringArray = ["None"]
	for c: Variant in M1911Kit.pick_choices():
		var parts: PackedStringArray = str(c).split(":")
		pick_names.append(M1911Kit.option_name(parts[0], parts[1]))
	var pick: OptionButton = MenuKit.options(pick_names, maxi(0, picks.find(M1911Kit.equipped_pick())),
		func(i: int) -> void: M1911Kit.set_loadout_pick(str(picks[i])))
	pick.disabled = not M1911Kit.pick_unlocked(kills)
	into.add_child(MenuKit.row("Loadout Pick" if not pick.disabled else "Loadout Pick  (%d kills)" % M1911Kit.pick_kills(), pick))
	into.add_child(MenuKit.para("Your starting M1911 wears the finish, and the Loadout Pick comes fitted every match. Buy the rest at an Armorer's Bench.", 16, MenuKit.DIM))


func _controls() -> void:
	var sprint_modes: PackedStringArray = ["hold", "toggle"]
	var scur: int = maxi(0, sprint_modes.find(str(GLSettings.values.get("sprint_mode", "hold"))))
	content.add_child(MenuKit.row("Sprint", MenuKit.options(PackedStringArray(["Hold", "Toggle"]), scur,
		func(i: int) -> void: GLSettings.set_value("sprint_mode", sprint_modes[i]))))
	content.add_child(MenuKit.check("Prone (hold Crouch)", bool(GLSettings.values.get("prone_enabled", false)), _setter("prone_enabled")))
	content.add_child(MenuKit.para("Select a binding, then press the new key / button. Esc cancels.", 18, MenuKit.DIM))
	_wait_label = MenuKit.label("", 20, MenuKit.GOLD)
	content.add_child(_wait_label)
	var g: GridContainer = GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 24)
	content.add_child(g)
	for a: Variant in GLData.table("input_defaults").keys():
		var action: String = str(a)
		if action.begins_with("_"):
			continue
		g.add_child(MenuKit.label(str(ACTION_NAMES.get(action, action)), 19))
		var kb: Button = MenuKit.button(GLSettings.binding_label(StringName(action), false), _capture.bind(StringName(action), false), 18)
		kb.custom_minimum_size = Vector2(200, 34)
		g.add_child(kb)
		var pad: Button = MenuKit.button(GLSettings.binding_label(StringName(action), true), _capture.bind(StringName(action), true), 18)
		pad.custom_minimum_size = Vector2(200, 34)
		g.add_child(pad)
	content.add_child(MenuKit.button("Reset all bindings to default", _reset_bindings, 20))


func _capture(action: StringName, pad: bool) -> void:
	_waiting_action = action
	_waiting_pad = pad
	_wait_label.text = "Press a %s for \"%s\"..." % ["controller button" if pad else "key or mouse button", ACTION_NAMES.get(String(action), action)]


func _reset_bindings() -> void:
	GLSettings.reset_bindings()
	rebuild()


func _input(event: InputEvent) -> void:
	if _waiting_action == &"":
		return
	if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_ESCAPE and event.is_pressed():
		_waiting_action = &""
		_wait_label.text = "Cancelled."
		get_viewport().set_input_as_handled()
		return
	if not event.is_pressed() or event.is_echo():
		return
	var is_pad: bool = event is InputEventJoypadButton or event is InputEventJoypadMotion
	var is_kb: bool = event is InputEventKey or event is InputEventMouseButton
	if (_waiting_pad and not is_pad) or (not _waiting_pad and not is_kb):
		return
	if event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) < 0.6:
		return
	get_viewport().set_input_as_handled()
	GLSettings.rebind(_waiting_action, event)
	_waiting_action = &""
	rebuild.call_deferred()


func _audio() -> void:
	var v: Dictionary = GLSettings.values
	for pair: Array in [["Master", "vol_master"], ["Music", "vol_music"], ["Sound effects", "vol_sfx"], ["Voices", "vol_vo"], ["Perk jingles", "vol_jingles"], ["Ambience", "vol_ambience"]]:
		content.add_child(MenuKit.row(str(pair[0]), MenuKit.slider(0.0, 1.0, 0.05, float(v[pair[1]]), _setter(str(pair[1])))))
	content.add_child(MenuKit.check("Room acoustics", bool(v.get("vo_room_acoustics", true)), _setter("vo_room_acoustics")))   # T-205
	content.add_child(MenuKit.para("Voices carry a little of the room they are spoken in: the inn, a cellar, a mine, a plane. Off: every voice dry.", 16, MenuKit.DIM))


func _video() -> void:
	_graphics()
	content.add_child(MenuKit.check("Film grain", bool(GLSettings.values.get("film_grain", true)), _setter("film_grain")))
	# T-208: the rest of the post stack, piece by piece (LookPost); Volumetric fog is the quality row above
	content.add_child(MenuKit.check("Vignette", bool(GLSettings.values.get("post_vignette", true)), _setter("post_vignette")))
	content.add_child(MenuKit.check("Lens softness at the edges", bool(GLSettings.values.get("post_edge_soft", true)), _setter("post_edge_soft")))
	content.add_child(MenuKit.check("Chromatic aberration (frame edge)", bool(GLSettings.values.get("post_ca", true)), _setter("post_ca")))
	var gore_levels: PackedStringArray = ["off", "low", "full"]
	var gcur: int = maxi(0, gore_levels.find(str(GLSettings.values.get("gore", "full"))))
	content.add_child(MenuKit.row("Gore", MenuKit.options(PackedStringArray(["Off", "Low", "Full"]), gcur,
		func(i: int) -> void: GLSettings.set_value("gore", gore_levels[i]))))
	content.add_child(MenuKit.para("Off: no dismemberment or blood (the Nachtglas shatter stays). Low: limbs come off, no spray. Full: everything.", 16, MenuKit.DIM))
	var vfx_levels: PackedStringArray = ["low", "medium", "high"]
	var vcur: int = maxi(0, vfx_levels.find(str(GLSettings.values.get("vfx_quality", "high"))))
	content.add_child(MenuKit.row("VFX quality", MenuKit.options(PackedStringArray(["Low", "Medium", "High"]), vcur,
		func(i: int) -> void: GLSettings.set_value("vfx_quality", vfx_levels[i]))))
	content.add_child(MenuKit.para("Muzzle flashes, casings, impact debris, snow and dust: how many at once. Low keeps the flashes and the Nachtglas sparks.", 16, MenuKit.DIM))
	var aspects: PackedStringArray = ["keep", "fill"]   # T-100: ultrawide
	var acur: int = maxi(0, aspects.find(str(GLSettings.values.get("aspect", "fill"))))
	content.add_child(MenuKit.row("Aspect", MenuKit.options(PackedStringArray(["Keep 16:9", "Fill screen"]), acur,
		func(i: int) -> void: GLSettings.set_value("aspect", aspects[i]))))
	content.add_child(MenuKit.para("Fill screen uses the whole of a 21:9 or 32:9 monitor (the HUD keeps to its edges); Keep 16:9 shows black bars at the sides.", 16, MenuKit.DIM))
	var fs: bool = DisplayServer.get_name() != "headless" and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	content.add_child(MenuKit.check("Fullscreen", fs, func(on: bool) -> void:
		if DisplayServer.get_name() != "headless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)))


## T-133: the graphics block. A preset fills in every setting below it; change any one and the preset reads Custom.
func _graphics() -> void:
	var g: Node = GLSettings
	var order: PackedStringArray = GLSettings.preset_order(GLSettings.is_compat())   # T-139: + "Browser" on the web
	var names: PackedStringArray = ["Low", "Medium", "High", "Ultra"]
	if order.size() > 4:
		names.append("Browser")
	names.append("Custom")
	var now: String = GLSettings.matching_preset(_gfx_values())
	var pi: int = order.find(now)
	content.add_child(MenuKit.row("Graphics preset", MenuKit.options(names, pi if pi >= 0 else order.size(), func(i: int) -> void:
		if i < order.size():
			GLSettings.set_preset(order[i])
			rebuild())))
	content.add_child(MenuKit.para(detected_line(), 16, MenuKit.VIOLET.lightened(0.25)))
	content.add_child(MenuKit.para("Low and Medium render below full resolution and upscale it; High is full quality; Ultra adds 4x MSAA with TAA, 8K shadows, the best AO, fog and level of detail (a fast GPU: RTX 3080 and up).", 16, MenuKit.DIM))
	_choice("Anti-aliasing", "gfx_aa", GLSettings.AA_MODES, ["Off", "FXAA (cheap, soft)", "SMAA (sharp)", "MSAA 2x", "MSAA 4x", "MSAA 8x", "TAA (smoothest, softer in motion)", "MSAA 4x + TAA (best)"])
	content.add_child(MenuKit.row("Render scale", MenuKit.slider(50, 100, 5, float(g.call("gfx", "gfx_scale")) * 100.0, func(v: float) -> void:
		GLSettings.set_value("gfx_scale", v / 100.0))))
	_choice("Upscaler", "gfx_upscaler", GLSettings.UPSCALERS, ["Bilinear", "AMD FSR 1", "AMD FSR 2 (also anti-aliases)"])
	content.add_child(MenuKit.row("Sharpening (FSR)", MenuKit.slider(0.0, 2.0, 0.1, 2.0 - float(GLSettings.values.get("gfx_sharpness", 0.4)), func(v: float) -> void:
		GLSettings.set_value("gfx_sharpness", 2.0 - v))))
	_choice("Shadows", "gfx_shadows", PackedStringArray(["low", "medium", "high", "ultra"]), ["Low", "Medium", "High", "Ultra"])
	_choice("Ambient occlusion", "gfx_ao", PackedStringArray(["off", "low", "medium", "high", "ultra"]), ["Off", "Low", "Medium", "High", "Ultra"])
	content.add_child(MenuKit.check("Global illumination (bounce light)", bool(g.call("gfx", "gfx_gi")), _setter("gfx_gi")))
	content.add_child(MenuKit.check("Indirect light (SSIL)", bool(g.call("gfx", "gfx_ssil")), _setter("gfx_ssil")))
	content.add_child(MenuKit.check("Reflections (SSR)", bool(g.call("gfx", "gfx_ssr")), _setter("gfx_ssr")))
	_choice("Volumetric fog", "gfx_fog", PackedStringArray(["off", "low", "high", "ultra"]), ["Off", "Low", "High", "Ultra"])
	_choice("Level of detail", "gfx_lod", PackedStringArray(["low", "medium", "high", "ultra"]), ["Low", "Medium", "High", "Ultra"])
	content.add_child(MenuKit.row("Brightness", MenuKit.slider(0.7, 1.4, 0.05, float(GLSettings.values.get("brightness", 1.0)), _setter("brightness"))))
	content.add_child(MenuKit.check("Smooth motion (high-refresh screens)", bool(GLSettings.values.get("smooth_motion", true)), _setter("smooth_motion")))
	content.add_child(MenuKit.para("The camera and the gun move every frame instead of 60 times a second: on a 144 or 240 Hz screen aiming and strafing stop looking steppy. On by default.", 16, MenuKit.DIM))
	content.add_child(MenuKit.check("Smooth zombies (high-refresh screens)", bool(GLSettings.values.get("zombie_smooth", true)), _setter("zombie_smooth")))
	content.add_child(MenuKit.para("Nearby zombies are drawn between their 60 Hz steps. Costs a little CPU with many on screen; turn it off on a slow laptop.", 16, MenuKit.DIM))
	# vsync and the frame cap live in the shared Settings (core/settings.gd): every mode of the game uses them
	content.add_child(MenuKit.check("V-Sync", bool(Settings.values.get("vsync", true)), func(on: bool) -> void: Settings.set_value("vsync", on)))
	var caps: Array = [0, 60, 120, 144, 165, 240, 360]
	var ccur: int = maxi(0, caps.find(int(Settings.values.get("maxFps", 0))))
	content.add_child(MenuKit.row("Frame cap", MenuKit.options(PackedStringArray(["Off", "60", "120", "144", "165", "240", "360"]), ccur,
		func(i: int) -> void: Settings.set_value("maxFps", caps[i]))))
	content.add_child(MenuKit.para("With V-Sync on the game runs at your screen's refresh rate. V-Sync off with a frame cap at your refresh rate gives the least input lag.", 16, MenuKit.DIM))


## T-144: what the first-launch auto-detect picked for this machine (GLSettings.auto_detect_preset, contract C4),
## or the renderer and adapter when that is not in this build.
static func detected_line() -> String:
	var gs: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("GLSettings")
	var adapter: String = RenderingServer.get_video_adapter_name()
	var renderer: String = RenderingServer.get_current_rendering_method()   # what is running (a --rendering-driver flag can differ from the project)
	if gs != null and gs.has_method("auto_detect_preset"):
		var pick: String = str(gs.call("auto_detect_preset"))
		return "Auto-detect suggests %s for this machine (%s, %s)." % [pick.capitalize(), adapter if adapter != "" else "unknown GPU", renderer]
	return "Detected: %s on the %s renderer%s." % [adapter if adapter != "" else "an unknown GPU", renderer,
		" (browser: the web profile applies)" if OS.has_feature("web") else ""]


func _gfx_values() -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in (GLSettings.PRESETS["high"] as Dictionary).keys():
		out[str(k)] = GLSettings.gfx(str(k))
	return out


## One individual graphics option (ids from GLSettings, labels shown); changing it makes the preset Custom.
func _choice(label: String, key: String, ids: PackedStringArray, labels: Array) -> void:
	var cur: int = maxi(0, ids.find(str(GLSettings.gfx(key))))
	content.add_child(MenuKit.row(label, MenuKit.options(PackedStringArray(labels), cur, func(i: int) -> void:
		GLSettings.set_value(key, ids[i])
		rebuild())))


func _access() -> void:
	var modes: PackedStringArray = GLSettings.COLORBLIND_MODES
	var cur: int = maxi(0, modes.find(str(GLSettings.values.get("colorblind", "off"))))
	content.add_child(MenuKit.row("Colorblind mode", MenuKit.options(PackedStringArray(["Off", "Protanopia", "Deuteranopia", "Tritanopia"]), cur,
		func(i: int) -> void: GLSettings.set_value("colorblind", modes[i]))))
	content.add_child(MenuKit.check("Subtitles", bool(GLSettings.values.get("subtitles", true)), _setter("subtitles")))


func _unhandled_input(event: InputEvent) -> void:
	if _waiting_action != &"":
		return
	if event is InputEventJoypadButton and event.is_pressed():
		var jb: InputEventJoypadButton = event as InputEventJoypadButton
		if jb.button_index == JOY_BUTTON_LEFT_SHOULDER:
			_set_tab(_tab - 1)
			return
		if jb.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			_set_tab(_tab + 1)
			return
	super._unhandled_input(event)


## The minimap (Update 04 section 2, DECISIONS T-065): Classic HUD turns it off; the rest shapes it.
func _minimap_rows() -> void:
	var v: Dictionary = GLSettings.values
	content.add_child(MenuKit.label("Minimap", 22, MenuKit.GOLD))
	content.add_child(MenuKit.check("Classic HUD (no minimap)", bool(v.get("classic_hud", false)), _setter("classic_hud")))
	content.add_child(MenuKit.check("Minimap turns with you (off: north up)", bool(v.get("minimap_rotate", true)), _setter("minimap_rotate")))
	content.add_child(MenuKit.row("Minimap zoom", MenuKit.options(PackedStringArray(["Close", "Medium", "Far"]), clampi(int(v.get("minimap_zoom", 1)), 0, 2),
		func(i: int) -> void: GLSettings.set_value("minimap_zoom", i))))
	content.add_child(MenuKit.row("Minimap size", MenuKit.slider(0.7, 1.5, 0.05, float(v.get("minimap_size", 1.0)), _setter("minimap_size"))))
	content.add_child(MenuKit.row("Minimap opacity", MenuKit.slider(0.3, 1.0, 0.05, float(v.get("minimap_opacity", 0.92)), _setter("minimap_opacity"))))
	content.add_child(MenuKit.row("Minimap icon size", MenuKit.slider(0.7, 1.8, 0.05, float(v.get("minimap_icon_scale", 1.0)), _setter("minimap_icon_scale"))))
	var corners: PackedStringArray = ["tl", "tr"]
	content.add_child(MenuKit.row("Minimap corner", MenuKit.options(PackedStringArray(["Top left", "Top right"]), maxi(0, corners.find(str(v.get("minimap_position", "tl")))),
		func(i: int) -> void: GLSettings.set_value("minimap_position", corners[i]))))
	var shapes: PackedStringArray = ["circle", "square"]
	content.add_child(MenuKit.row("Minimap shape", MenuKit.options(PackedStringArray(["Circle", "Rounded square"]), maxi(0, shapes.find(str(v.get("minimap_shape", "circle")))),
		func(i: int) -> void: GLSettings.set_value("minimap_shape", shapes[i]))))
	var zmodes: PackedStringArray = ["off", "firing", "always"]
	content.add_child(MenuKit.row("Show nearby zombies", MenuKit.options(PackedStringArray(["Off", "Firing only", "Always"]), maxi(0, zmodes.find(str(v.get("minimap_zombies", "firing")))),
		func(i: int) -> void: GLSettings.set_value("minimap_zombies", zmodes[i]))))
	var fmodes: PackedStringArray = ["visit", "always"]
	content.add_child(MenuKit.row("Map areas", MenuKit.options(PackedStringArray(["Reveal as you go", "Always visible"]), maxi(0, fmodes.find(str(v.get("minimap_fog", "visit")))),
		func(i: int) -> void: GLSettings.set_value("minimap_fog", fmodes[i]))))
	content.add_child(MenuKit.check("Colourblind-safe map icons (letters on the shapes)", bool(v.get("minimap_cb_shapes", false)), _setter("minimap_cb_shapes")))
	content.add_child(MenuKit.para("Firing only: an unsuppressed shot shows the zombies near the shooter for a second. Always: zombies near you are always on the minimap. The minimap zoom key (N / D-pad left) cycles the zoom in a match.", 16, MenuKit.DIM))
