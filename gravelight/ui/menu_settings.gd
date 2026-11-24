class_name MenuSettings
extends MenuScreen
## Settings with tabs: Gameplay, Controls (keyboard + controller remap), Audio, Video, Accessibility.
## LB/RB (or Q/E) switch tabs. Everything saves immediately.
## T-218: the tab bar sits above the scroll (MenuScreen.header) and marks the open tab; every tab is grouped under
## section headings; sliders print their value; the help lines are readable (MenuKit.section / help / row).

const TABS: PackedStringArray = ["Gameplay", "Controls", "Audio", "Video", "Accessibility"]
const SUBTITLE_SIZES: PackedStringArray = ["normal", "large", "largest"]   # T-218
const SUBTITLE_BACKS: PackedStringArray = ["off", "light", "dark"]
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
var _tab_bar: HBoxContainer
var _tab_buttons: Array[Button] = []


func _init() -> void:
	super._init("Settings")


func build_header() -> void:
	_tab_bar = HBoxContainer.new()
	_tab_bar.name = "Tabs"
	_tab_bar.add_theme_constant_override("separation", 8)
	header.add_child(_tab_bar)
	_refresh_tabs()


## The tab bar: the open tab in gold with an underline, the others dimmer, the switch keys at both ends.
func _refresh_tabs() -> void:
	for c: Node in _tab_bar.get_children():
		_tab_bar.remove_child(c)
		c.queue_free()
	_tab_buttons.clear()
	_tab_bar.add_child(_tab_hint("Q / LB  <"))
	for i: int in TABS.size():
		var b: Button = MenuKit.button(TABS[i], _set_tab.bind(i), 20)
		b.name = "Tab_" + TABS[i]
		b.custom_minimum_size = Vector2(176, 44)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		if i == _tab:
			var sb: StyleBoxFlat = StyleBoxFlat.new()
			sb.bg_color = Color(MenuKit.GOLD, 0.13)
			sb.border_color = MenuKit.GOLD
			sb.border_width_bottom = 3
			sb.content_margin_left = 14
			sb.content_margin_right = 14
			for st: String in ["normal", "hover", "pressed"]:
				b.add_theme_stylebox_override(st, sb)
			for cs: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
				b.add_theme_color_override(cs, MenuKit.GOLD)
		else:
			b.add_theme_color_override("font_color", MenuKit.PAPER.darkened(0.3))
		_tab_bar.add_child(b)
		_tab_buttons.append(b)
	_tab_bar.add_child(_tab_hint(">  RB / E"))


static func _tab_hint(text_str: String) -> Label:
	var l: Label = MenuKit.label(text_str, 15, MenuKit.DIM)
	l.add_theme_font_override("font", MenuKit.mono_font())
	l.custom_minimum_size = Vector2(96, 44)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func build() -> void:
	match _tab:
		0: _gameplay()
		1: _controls()
		2: _audio()
		3: _video()
		4: _access()


func _set_tab(i: int) -> void:
	_tab = posmod(i, TABS.size())
	_waiting_action = &""
	_refresh_tabs()
	rebuild()
	var b: Button = _tab_buttons[_tab]
	(func() -> void:   # after rebuild's own focus_first: the open tab keeps the focus (it used to jump to Gameplay)
		if is_instance_valid(b):
			b.grab_focus()).call_deferred()


func _setter(key: String) -> Callable:
	return func(v: Variant) -> void: GLSettings.set_value(key, v)


func _gameplay() -> void:
	var v: Dictionary = GLSettings.values
	content.add_child(MenuKit.section("Camera and aim"))
	content.add_child(MenuKit.row("Field of view", MenuKit.slider(65, 110, 1, float(v["fov"]), _setter("fov"), "deg")))
	content.add_child(MenuKit.row("Screen shake", MenuKit.slider(0.0, 1.5, 0.05, float(v.get("screen_shake", 1.0)), _setter("screen_shake"), "pct")))
	content.add_child(MenuKit.row("Mouse sensitivity", MenuKit.slider(0.1, 4.0, 0.05, float(v["sensitivity"]), _setter("sensitivity"), "x")))
	content.add_child(MenuKit.row("Aiming sensitivity", MenuKit.slider(0.2, 1.5, 0.05, float(v["ads_sensitivity"]), _setter("ads_sensitivity"), "x")))
	content.add_child(MenuKit.row("Controller look speed", MenuKit.slider(0.2, 3.0, 0.05, float(v["pad_sensitivity"]), _setter("pad_sensitivity"), "x")))
	var sway_modes: PackedStringArray = CameraSway.MODES   # T-220: the flight's camera motion (the Kranich)
	var sway_labels: PackedStringArray = PackedStringArray(Array(sway_modes).map(func(k: Variant) -> String: return str(CameraSway.LABELS.get(str(k), k))))
	content.add_child(MenuKit.row("Camera Sway / Turbulence", MenuKit.options(sway_labels, maxi(0, sway_modes.find(CameraSway.normalize(v.get("camera_sway", "full")))),
		func(i: int) -> void: GLSettings.set_value("camera_sway", sway_modes[i]))))
	content.add_child(MenuKit.help("How much the camera rolls and shakes with the aircraft (the Kranich's banks and turbulence). Off keeps the sky, the sound and the wind; only the camera holds still. Weapon and explosion shake follow Screen shake."))
	content.add_child(MenuKit.switch_row("Invert look (Y)", bool(v["invert_y"]), _setter("invert_y")))
	content.add_child(MenuKit.switch_row("Lean (Z / E)", bool(v.get("lean_enabled", true)), _setter("lean_enabled")))
	content.add_child(MenuKit.section("Rules and practice"))
	content.add_child(MenuKit.switch_row("Classic Rules (no character traits)", bool(v["classic_rules"]), _setter("classic_rules")))
	var ht_cur: int = maxi(0, HardTruth.MODES.find(HardTruth.mode_of(v)))
	content.add_child(MenuKit.row("Hard Truth (the fourth-day rule)", MenuKit.options(HardTruth.MODE_LABELS, ht_cur,
		func(i: int) -> void: GLSettings.set_value(HardTruth.SETTING, HardTruth.MODES[i]))))
	content.add_child(MenuKit.help("A teammate who bleeds out rises as one of them four seconds later. Put them down: their kit drops where they fall. They still come back next round. In co-op the host's setting decides."))
	var egg_cur: int = maxi(0, EggMode.MODES.find(EggMode.mode_of(v)))
	content.add_child(MenuKit.row("Easter Egg Mode (practice)", MenuKit.options(EggMode.MODE_LABELS, egg_cur,
		func(i: int) -> void: GLSettings.set_value(EggMode.SETTING, EggMode.MODES[i]))))
	content.add_child(MenuKit.help("Few Crawlers: a couple of slow crawlers a round. No Zombies: rounds pass on a short clock with none. The egg's own enemies (its bosses, holds and kill counts) still come. Practice only: no XP, challenges, stats, best rounds, unlocks, egg rewards or bank. From the next match."))
	content.add_child(MenuKit.switch_row("Hint mode (show the next objective)", bool(v["hint_mode"]), _setter("hint_mode")))
	var spoil: int = maxi(0, ObjectiveLog.LEVELS.find(ObjectiveLog.level(v.get("objective_spoilers", "hints"))))
	content.add_child(MenuKit.row("Objective spoilers (pause OBJECTIVES tab)", MenuKit.options(ObjectiveLog.LEVEL_NAMES, spoil,
		func(i: int) -> void: GLSettings.set_value("objective_spoilers", ObjectiveLog.LEVELS[i]))))
	content.add_child(MenuKit.section("AI teammates"))
	content.add_child(MenuKit.switch_row("Bot Bonus Perk (each AI teammate gets one random perk)", bool(v.get("bot_bonus_perk", true)), _setter("bot_bonus_perk")))
	var bc: Dictionary = BotConfig.cfg()
	var skill_ids: Array = bc.get("skill_order", ["recruit", "veteran", "elite"])
	var skill_cur: int = maxi(0, skill_ids.find(BotConfig.skill_key(bc, str(v.get("bot_skill", "veteran")))))
	var skill_labels: PackedStringArray = PackedStringArray(skill_ids.map(func(k: Variant) -> String: return str(k).capitalize()))
	content.add_child(MenuKit.row("Bot Skill (AI teammates)", MenuKit.options(skill_labels, skill_cur,
		func(i: int) -> void: GLSettings.set_value("bot_skill", str(skill_ids[i])))))
	var brains: PackedStringArray = BotConfig.AI_BRAIN_CYCLE   # T-217
	var brain_labels: PackedStringArray = PackedStringArray(Array(brains).map(func(k: Variant) -> String: return str(BotConfig.AI_BRAIN_LABELS.get(str(k), k))))
	content.add_child(MenuKit.row("Bot AI (the planning bot's brain)", MenuKit.options(brain_labels, maxi(0, brains.find(BotConfig.brain_setting(v))),
		func(i: int) -> void: BotConfig.set_brain(brains[i]))))
	content.add_child(MenuKit.help("Built-in works on any PC with no download. Small and Large run a local model through Ollama (Small ~3 GB of video memory, Large ~17 GB); CPU only uses no video memory but thinks slower. Auto picks Small, or CPU only on a low-end GPU. Without Ollama every choice falls back to Built-in."))
	var ee_cur: int = maxi(0, BotEECatalog.MODES.find(BotEECatalog.mode_of(v)))
	content.add_child(MenuKit.row("Bot Easter-Egg Help", MenuKit.options(BotEECatalog.MODE_LABELS, ee_cur,
		func(i: int) -> void: GLSettings.set_value(BotEECatalog.SETTING, BotEECatalog.MODES[i]))))
	content.add_child(MenuKit.help("Off: bots never touch easter-egg objects. When Asked: only steps you give them (Objectives tab, a map mark, the ping key). Full Partner: they work open steps alongside you and say what they're doing; the last steps wait for you."))
	content.add_child(MenuKit.section("Homage"))
	content.add_child(MenuKit.switch_row("Homage Bosses (the Cousins, PAUL, THE SLENDER)", bool(v.get("homage_bosses", true)), _setter("homage_bosses")))
	var name_modes: PackedStringArray = ["real", "world"]
	var ncur: int = maxi(0, name_modes.find(str(v.get("homage_names", "real"))))
	content.add_child(MenuKit.row("Homage Names", MenuKit.options(PackedStringArray(["Real", "In-World"]), ncur,
		func(i: int) -> void: GLSettings.set_value("homage_names", name_modes[i]))))
	content.add_child(MenuKit.help("Homage Bosses are tributes to real people. Real shows their first names on the title cards and boss bars; In-World shows only the in-world names. In co-op the host's settings decide."))
	m1911_rows(content)
	_minimap_rows()


## The starting pistol's cosmetic finish and Loadout Pick (UPDATE_04 section 6, M1911Kit): unlocked by lifetime
## M1911 kills. Static so the pause menu's LOADOUT tab can build the same rows into its own container.
static func m1911_rows(into: Control) -> void:
	var kills: int = ProfileSave.weapon_kills(&"m1911")
	into.add_child(MenuKit.section("M1911  (%d kills)" % kills))
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
	into.add_child(MenuKit.help("Your starting M1911 wears the finish, and the Loadout Pick comes fitted every match. Buy the rest at an Armorer's Bench."))


func _controls() -> void:
	content.add_child(MenuKit.section("Movement"))
	var sprint_modes: PackedStringArray = ["hold", "toggle"]
	var scur: int = maxi(0, sprint_modes.find(str(GLSettings.values.get("sprint_mode", "hold"))))
	content.add_child(MenuKit.row("Sprint", MenuKit.options(PackedStringArray(["Hold", "Toggle"]), scur,
		func(i: int) -> void: GLSettings.set_value("sprint_mode", sprint_modes[i]))))
	content.add_child(MenuKit.switch_row("Prone (hold Crouch)", bool(GLSettings.values.get("prone_enabled", false)), _setter("prone_enabled")))
	content.add_child(MenuKit.help("Select a binding, then press the new key / button. Esc cancels; so does waiting %d seconds (a controller has no Esc)." % int(REBIND_WAIT_S)))
	content.add_child(MenuKit.section("Bindings"))
	_wait_label = MenuKit.label("", 20, MenuKit.GOLD)
	content.add_child(_wait_label)
	var g: GridContainer = GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 24)
	g.add_theme_constant_override("v_separation", 4)
	content.add_child(g)
	for head: String in ["Action", "Keyboard / mouse", "Controller"]:
		var hl: Label = MenuKit.label(head, 16, MenuKit.DIM)
		hl.add_theme_font_override("font", MenuKit.spaced(MenuKit.type_font(), 2))
		var hs: StyleBoxEmpty = StyleBoxEmpty.new()
		hs.content_margin_left = MenuKit.ROW_INSET
		hl.add_theme_stylebox_override("normal", hs)
		g.add_child(hl)
	for a: Variant in GLData.table("input_defaults").keys():
		var action: String = str(a)
		if action.begins_with("_"):
			continue
		var al: Label = MenuKit.label(str(ACTION_NAMES.get(action, action)), 19)
		var als: StyleBoxEmpty = StyleBoxEmpty.new()
		als.content_margin_left = MenuKit.ROW_INSET
		al.add_theme_stylebox_override("normal", als)
		al.custom_minimum_size = Vector2(300, 0)
		g.add_child(al)
		var kb: Button = MenuKit.button(GLSettings.binding_label(StringName(action), false), _capture.bind(StringName(action), false), 18)
		kb.custom_minimum_size = Vector2(240, 34)
		g.add_child(kb)
		var pad: Button = MenuKit.button(pad_name(GLSettings.binding_label(StringName(action), true)), _capture.bind(StringName(action), true), 18)
		pad.custom_minimum_size = Vector2(240, 34)
		g.add_child(pad)
	content.add_child(MenuKit.button("Reset all bindings to default", _reset_bindings, 20))


## A controller binding the way the pad's own labels read (pure, unit-tested): LEFT SHOULDER -> LB, TRIGGER RIGHT+
## -> RT, LEFT Y- -> Left stick up, DPAD UP -> D-pad up, LEFT STICK -> L3 (stick click).
const PAD_NAMES: Dictionary = {"LEFT SHOULDER": "LB", "RIGHT SHOULDER": "RB", "LEFT STICK": "L3 (left stick click)",
	"RIGHT STICK": "R3 (right stick click)", "START": "Menu", "BACK": "View", "DPAD UP": "D-pad up",
	"DPAD DOWN": "D-pad down", "DPAD LEFT": "D-pad left", "DPAD RIGHT": "D-pad right",
	"TRIGGER RIGHT+": "RT", "TRIGGER LEFT+": "LT", "LEFT Y-": "Left stick up", "LEFT Y+": "Left stick down",
	"LEFT X-": "Left stick left", "LEFT X+": "Left stick right", "RIGHT Y-": "Right stick up",
	"RIGHT Y+": "Right stick down", "RIGHT X-": "Right stick left", "RIGHT X+": "Right stick right"}


static func pad_name(raw: String) -> String:
	return str(PAD_NAMES.get(raw, raw))


func _capture(action: StringName, pad: bool) -> void:
	_waiting_action = action
	_waiting_pad = pad
	_wait_label.text = "Press a %s for \"%s\"..." % ["controller button" if pad else "key or mouse button", ACTION_NAMES.get(String(action), action)]


func _reset_bindings() -> void:
	GLSettings.reset_bindings()
	rebuild()


## T-264: a controller cannot press Esc, and while a controller binding is awaited every button is a candidate:
## the wait ends by itself after REBIND_WAIT_S; while a keyboard binding is awaited, pad B cancels too.
const REBIND_WAIT_S: float = 6.0
var _wait_started_ms: int = 0
var _wait_seen: StringName = &""


func _process(delta: float) -> void:
	super._process(delta)
	if _waiting_action == &"":
		_wait_seen = &""
		return
	if _wait_seen != _waiting_action:
		_wait_seen = _waiting_action
		_wait_started_ms = Time.get_ticks_msec()
	elif Time.get_ticks_msec() - _wait_started_ms > int(REBIND_WAIT_S * 1000.0):
		_waiting_action = &""
		if is_instance_valid(_wait_label):
			_wait_label.text = "Cancelled."


func _input(event: InputEvent) -> void:
	if _waiting_action == &"":
		return
	var pad_b: bool = not _waiting_pad and event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B
	if (event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_ESCAPE and event.is_pressed()) or (pad_b and event.is_pressed()):
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
	content.add_child(MenuKit.section("Volume"))
	for pair: Array in [["Master", "vol_master"], ["Music", "vol_music"], ["Sound effects", "vol_sfx"], ["Voices", "vol_vo"], ["Perk jingles", "vol_jingles"], ["Ambience", "vol_ambience"]]:
		content.add_child(MenuKit.row(str(pair[0]), MenuKit.slider(0.0, 1.0, 0.05, float(v[pair[1]]), _setter(str(pair[1])))))
	content.add_child(MenuKit.section("Voices"))
	content.add_child(MenuKit.switch_row("Room acoustics", bool(v.get("vo_room_acoustics", true)), _setter("vo_room_acoustics")))   # T-205
	content.add_child(MenuKit.help("Voices carry a little of the room they are spoken in: the inn, a cellar, a mine, a plane. Off: every voice dry."))


func _video() -> void:
	_graphics()
	content.add_child(MenuKit.section("The look"))
	content.add_child(MenuKit.switch_row("Film grain", bool(GLSettings.values.get("film_grain", true)), _setter("film_grain")))
	# T-208: the rest of the post stack, piece by piece (LookPost); Volumetric fog is the quality row above
	content.add_child(MenuKit.switch_row("Vignette", bool(GLSettings.values.get("post_vignette", true)), _setter("post_vignette")))
	content.add_child(MenuKit.switch_row("Lens softness at the edges", bool(GLSettings.values.get("post_edge_soft", true)), _setter("post_edge_soft")))
	content.add_child(MenuKit.switch_row("Chromatic aberration (frame edge)", bool(GLSettings.values.get("post_ca", true)), _setter("post_ca")))
	content.add_child(MenuKit.section("Effects"))
	var gore_levels: PackedStringArray = ["off", "low", "full"]
	var gcur: int = maxi(0, gore_levels.find(str(GLSettings.values.get("gore", "full"))))
	content.add_child(MenuKit.row("Gore", MenuKit.options(PackedStringArray(["Off", "Low", "Full"]), gcur,
		func(i: int) -> void: GLSettings.set_value("gore", gore_levels[i]))))
	content.add_child(MenuKit.help("Off: no dismemberment or blood (the Nachtglas shatter stays). Low: limbs come off, no spray. Full: everything."))
	var vfx_levels: PackedStringArray = ["low", "medium", "high"]
	var vcur: int = maxi(0, vfx_levels.find(str(GLSettings.values.get("vfx_quality", "high"))))
	content.add_child(MenuKit.row("VFX quality", MenuKit.options(PackedStringArray(["Low", "Medium", "High"]), vcur,
		func(i: int) -> void: GLSettings.set_value("vfx_quality", vfx_levels[i]))))
	content.add_child(MenuKit.help("Muzzle flashes, casings, impact debris, snow and dust: how many at once. Low keeps the flashes and the Nachtglas sparks."))
	content.add_child(MenuKit.section("Screen"))
	var aspects: PackedStringArray = ["keep", "fill"]   # T-100: ultrawide
	var acur: int = maxi(0, aspects.find(str(GLSettings.values.get("aspect", "fill"))))
	content.add_child(MenuKit.row("Aspect", MenuKit.options(PackedStringArray(["Keep 16:9", "Fill screen"]), acur,
		func(i: int) -> void: GLSettings.set_value("aspect", aspects[i]))))
	content.add_child(MenuKit.help("Fill screen uses the whole of a 21:9 or 32:9 monitor (the HUD keeps to its edges); Keep 16:9 shows black bars at the sides."))
	var fs: bool = DisplayServer.get_name() != "headless" and DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	# T-264: the switch writes the shared window mode (core Settings), so it is kept for the next launch and the
	# hub's own settings page shows the same thing (before, the next start put the window back)
	content.add_child(MenuKit.switch_row("Fullscreen", fs, func(on: bool) -> void:
		Settings.set_value("windowMode", "borderless" if on else "windowed")))


## T-133: the graphics block. A preset fills in every setting below it; change any one and the preset reads Custom.
func _graphics() -> void:
	var g: Node = GLSettings
	content.add_child(MenuKit.section("Graphics"))
	var order: PackedStringArray = GLSettings.preset_order(GLSettings.is_compat())   # T-139: + "Browser" on the web
	var names: PackedStringArray = []
	for pn: String in order:   # T-264: the labels follow the order (Handheld joined the desktop presets)
		names.append(str(GLSettings.PRESET_LABELS.get(pn, pn.capitalize())))
	names.append("Custom")
	var now: String = GLSettings.matching_preset(_gfx_values())
	var pi: int = order.find(now)
	content.add_child(MenuKit.row("Graphics preset", MenuKit.options(names, pi if pi >= 0 else order.size(), func(i: int) -> void:
		if i < order.size():
			GLSettings.set_preset(order[i])
			rebuild())))
	content.add_child(MenuKit.help(detected_line()))
	content.add_child(MenuKit.help("Low and Medium render below full resolution and upscale it; Handheld is for a small 800-line screen (full resolution, light effects); High is full quality; Ultra adds 4x MSAA with TAA, 8K shadows, the best AO, fog and level of detail (a fast GPU: RTX 3080 and up)."))
	_choice("Anti-aliasing", "gfx_aa", GLSettings.AA_MODES, ["Off", "FXAA (cheap, soft)", "SMAA (sharp)", "MSAA 2x", "MSAA 4x", "MSAA 8x", "TAA (smoothest, softer in motion)", "MSAA 4x + TAA (best)"])
	content.add_child(MenuKit.row("Render scale", MenuKit.slider(50, 100, 5, float(g.call("gfx", "gfx_scale")) * 100.0, func(v: float) -> void:
		GLSettings.set_value("gfx_scale", v / 100.0), "%d%%")))
	# T-264: the 3D picture's height limit (Retina, 4K and 5K panels): not part of a preset, so a preset keeps it
	var lines: PackedInt32Array = GLSettings.MAX_LINES_STEPS
	var line_names: PackedStringArray = []
	for ln: int in lines:
		line_names.append("Off" if ln == 0 else "%d lines" % ln)
	content.add_child(MenuKit.row("3D resolution limit", MenuKit.options(line_names, maxi(0, lines.find(int(GLSettings.values.get("gfx_max_lines", 0)))),
		func(i: int) -> void: GLSettings.set_value("gfx_max_lines", lines[i]))))
	content.add_child(MenuKit.help("On a very sharp screen (a Retina laptop, 4K, 5K) the 3D picture is drawn at most this high and upscaled; menus and the HUD stay at full sharpness. Lower it if the frame rate drops in fullscreen."))
	_choice("Upscaler", "gfx_upscaler", GLSettings.UPSCALERS, ["Bilinear", "AMD FSR 1", "AMD FSR 2 (also anti-aliases)"])
	content.add_child(MenuKit.row("Sharpening (FSR)", MenuKit.slider(0.0, 2.0, 0.1, 2.0 - float(GLSettings.values.get("gfx_sharpness", 0.4)), func(v: float) -> void:
		GLSettings.set_value("gfx_sharpness", 2.0 - v))))
	_choice("Shadows", "gfx_shadows", PackedStringArray(["low", "medium", "high", "ultra"]), ["Low", "Medium", "High", "Ultra"])
	_choice("Ambient occlusion", "gfx_ao", PackedStringArray(["off", "low", "medium", "high", "ultra"]), ["Off", "Low", "Medium", "High", "Ultra"])
	content.add_child(MenuKit.switch_row("Global illumination (bounce light)", bool(g.call("gfx", "gfx_gi")), _setter("gfx_gi")))
	content.add_child(MenuKit.switch_row("Indirect light (SSIL)", bool(g.call("gfx", "gfx_ssil")), _setter("gfx_ssil")))
	content.add_child(MenuKit.switch_row("Reflections (SSR)", bool(g.call("gfx", "gfx_ssr")), _setter("gfx_ssr")))
	_choice("Volumetric fog", "gfx_fog", PackedStringArray(["off", "low", "high", "ultra"]), ["Off", "Low", "High", "Ultra"])
	_choice("Level of detail", "gfx_lod", PackedStringArray(["low", "medium", "high", "ultra"]), ["Low", "Medium", "High", "Ultra"])
	content.add_child(MenuKit.row("Brightness", MenuKit.slider(0.7, 1.4, 0.05, float(GLSettings.values.get("brightness", 1.0)), _setter("brightness"), "x")))
	content.add_child(MenuKit.switch_row("Smooth motion (high-refresh screens)", bool(GLSettings.values.get("smooth_motion", true)), _setter("smooth_motion")))
	content.add_child(MenuKit.help("The camera and the gun move every frame instead of 60 times a second: on a 144 or 240 Hz screen aiming and strafing stop looking steppy. On by default."))
	content.add_child(MenuKit.switch_row("Smooth zombies (high-refresh screens)", bool(GLSettings.values.get("zombie_smooth", true)), _setter("zombie_smooth")))
	content.add_child(MenuKit.help("Nearby zombies are drawn between their 60 Hz steps. Costs a little CPU with many on screen; turn it off on a slow laptop."))
	content.add_child(MenuKit.section("Frame rate"))
	# vsync and the frame cap live in the shared Settings (core/settings.gd): every mode of the game uses them
	content.add_child(MenuKit.switch_row("V-Sync", bool(Settings.values.get("vsync", true)), func(on: bool) -> void: Settings.set_value("vsync", on)))
	var caps: Array = [0, 30, 40, 45, 60, 90, 120, 144, 165, 240, 360]   # T-264: 30 / 40 / 45 / 90 for handheld panels
	var ccur: int = maxi(0, caps.find(int(Settings.values.get("maxFps", 0))))
	content.add_child(MenuKit.row("Frame cap", MenuKit.options(PackedStringArray(["Off", "30", "40", "45", "60", "90", "120", "144", "165", "240", "360"]), ccur,
		func(i: int) -> void: Settings.set_value("maxFps", caps[i]))))
	content.add_child(MenuKit.help("With V-Sync on the game runs at your screen's refresh rate. V-Sync off with a frame cap at your refresh rate gives the least input lag."))


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
	content.add_child(MenuKit.section("Colour"))
	var modes: PackedStringArray = GLSettings.COLORBLIND_MODES
	var cur: int = maxi(0, modes.find(str(GLSettings.values.get("colorblind", "off"))))
	content.add_child(MenuKit.row("Colorblind mode", MenuKit.options(PackedStringArray(["Off", "Protanopia", "Deuteranopia", "Tritanopia"]), cur,
		func(i: int) -> void: GLSettings.set_value("colorblind", modes[i]))))
	content.add_child(MenuKit.section("Subtitles"))
	content.add_child(MenuKit.switch_row("Subtitles", bool(GLSettings.values.get("subtitles", true)), _setter("subtitles")))
	var sizes: PackedStringArray = SUBTITLE_SIZES   # T-218 (gravelight/ui/subtitles.gd reads both)
	content.add_child(MenuKit.row("Subtitle size", MenuKit.options(PackedStringArray(["Normal", "Large", "Largest"]),
		maxi(0, sizes.find(str(GLSettings.values.get("subtitle_size", "normal")))), func(i: int) -> void: GLSettings.set_value("subtitle_size", sizes[i]))))
	var backs: PackedStringArray = SUBTITLE_BACKS
	content.add_child(MenuKit.row("Subtitle background", MenuKit.options(PackedStringArray(["Off", "Light", "Dark"]),
		maxi(0, backs.find(str(GLSettings.values.get("subtitle_back", "off")))), func(i: int) -> void: GLSettings.set_value("subtitle_back", backs[i]))))
	content.add_child(MenuKit.help("A dark band behind the words keeps them readable on snow and in bright rooms. Both apply from the next line."))


func _unhandled_input(event: InputEvent) -> void:
	if _waiting_action != &"":
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var kc: Key = (event as InputEventKey).physical_keycode
		if kc == KEY_Q or kc == KEY_E:
			_set_tab(_tab + (1 if kc == KEY_E else -1))
			get_viewport().set_input_as_handled()
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
	content.add_child(MenuKit.section("Minimap"))
	content.add_child(MenuKit.switch_row("Classic HUD (no minimap)", bool(v.get("classic_hud", false)), _setter("classic_hud")))
	content.add_child(MenuKit.switch_row("Minimap turns with you (off: north up)", bool(v.get("minimap_rotate", true)), _setter("minimap_rotate")))
	content.add_child(MenuKit.row("Minimap zoom", MenuKit.options(PackedStringArray(["Close", "Medium", "Far"]), clampi(int(v.get("minimap_zoom", 1)), 0, 2),
		func(i: int) -> void: GLSettings.set_value("minimap_zoom", i))))
	content.add_child(MenuKit.row("Minimap size", MenuKit.slider(0.7, 1.5, 0.05, float(v.get("minimap_size", 1.0)), _setter("minimap_size"), "x")))
	content.add_child(MenuKit.row("Minimap opacity", MenuKit.slider(0.3, 1.0, 0.05, float(v.get("minimap_opacity", 0.92)), _setter("minimap_opacity"), "pct")))
	content.add_child(MenuKit.row("Minimap icon size", MenuKit.slider(0.7, 1.8, 0.05, float(v.get("minimap_icon_scale", 1.0)), _setter("minimap_icon_scale"), "x")))
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
	content.add_child(MenuKit.switch_row("Colourblind-safe map icons (letters on the shapes)", bool(v.get("minimap_cb_shapes", false)), _setter("minimap_cb_shapes")))
	content.add_child(MenuKit.help("Firing only: an unsuppressed shot shows the zombies near the shooter for a second. Always: zombies near you are always on the minimap. The minimap zoom key (N / D-pad left) cycles the zoom in a match."))
