class_name MenuKit
extends RefCounted
## Shared look for GRAVELIGHT's menus and HUD (T-096): ledger-paper colours, the bundled period fonts, the type
## scale and the text outlines from data/gravelight/ui.json, the Theme resource (gravelight_theme.tres) applied at
## every HUD / menu root, and widget builders. Every builder returns a focusable control so menus work with a
## controller.
##
## Fonts by role (ui.json "fonts" / "roles"): stamp = Stardos Stencil (the round stamp, zone stamp, boss names,
## titles), type = Special Elite (headings, buttons, prompts, the Ledger's typed lines), body = IBM Plex Sans
## (paragraphs, descriptions, captions), mono = IBM Plex Mono (Scrip / ammo counters, stat grids, the dev console).
## Each is a bundled file under assets/third_party/google_fonts; the system font named in ui.json is the declared
## fallback, used only when the file fails to load (test_ui_theme checks the files load).

const INK: Color = Color(0.62, 0.09, 0.08)
const PAPER: Color = Color(0.93, 0.89, 0.8)
const DIM: Color = Color(0.62, 0.6, 0.56)
const VIOLET: Color = Color(0.62, 0.45, 0.85)
const GOLD: Color = Color(0.95, 0.86, 0.55)
const BRASS: Color = Color(0.72, 0.55, 0.25)
const BRASS_DARK: Color = Color(0.4, 0.33, 0.25)

const UI_PATH: String = "res://data/gravelight/ui.json"
const THEME_PATH: String = "res://gravelight/ui/gravelight_theme.tres"
## The scale keys every build must define (test_ui_theme).
const SIZE_KEYS: PackedStringArray = ["fine", "caption", "body", "body_large", "button", "subheading", "heading", "title_small",
	"title", "display", "wordmark", "hud_stamp", "hud_scrip", "hud_ammo", "hud_weapon", "hud_nade", "hud_prompt", "hud_banner",
	"hud_toast", "hud_pop", "hud_debug", "hud_subtitle", "hud_powerup", "hud_zone_stamp", "hud_floor", "boss_name", "boss_card",
	"boss_card_small", "boss_card_date", "coop_row", "coop_banner"]
const FONT_KEYS: PackedStringArray = ["stamp", "stamp_light", "type", "body", "body_bold", "mono", "mono_bold"]
## 'wght' as an OpenType tag (FontVariation.variation_opentype key).
const WGHT: int = 2003265652

static var _cfg: Dictionary = {}
static var _fonts: Dictionary = {}       # font key -> Font
static var _fallback_used: Dictionary = {}   # font key -> true when the system fallback stood in
static var _theme: Theme = null


# ================================================================== data

## The UI table (data/gravelight/ui.json), loaded once.
static func cfg() -> Dictionary:
	if _cfg.is_empty():
		_cfg = GLData.load_json(UI_PATH)
		if _cfg.is_empty():
			_cfg = {"_missing": true}
	return _cfg


## Drops the caches (tests, the dev console's `ui reload`).
static func reset() -> void:
	_cfg = {}
	_fonts = {}
	_fallback_used = {}
	_theme = null


## A size of the type scale by key (ui.json "scale"); an unknown key is an error and gives the body size.
static func size(key: String) -> int:
	var scale: Dictionary = cfg().get("scale", {})
	if scale.has(key):
		return int(scale[key])
	push_error("MenuKit.size: no scale key '%s' in ui.json" % key)
	return int(scale.get("body", 18))


## Snaps a free pixel size onto the scale's steps (nearest; ties go up), so every label lands on the same few sizes.
static func px(n: int) -> int:
	var steps: Array = cfg().get("scale", {}).get("steps", [])
	if steps.is_empty():
		return n
	var best: int = int(steps[0])
	for s: Variant in steps:
		var v: int = int(s)
		if absi(v - n) < absi(best - n) or (absi(v - n) == absi(best - n) and v > best):
			best = v
	return best


## A HUD layout number (ui.json "hud"), with a default.
static func hud(key: String, default: Variant = 0.0) -> Variant:
	return cfg().get("hud", {}).get(key, default)


## T-100 (ultrawide): how far a 16:9 frame centred in the viewport sits from its left edge (0 at 16:9 or narrower).
static func frame_inset(vp: Vector2) -> float:
	return maxf(0.0, (vp.x - vp.y * 16.0 / 9.0) * 0.5)


## T-100: keeps a full-rect MarginContainer's page inside a centred 16:9 frame on a wider screen (side margins =
## `base` + the inset), following the viewport as it resizes. Menus centre on 21:9 / 32:9 instead of stretching.
static func keep_centred(margin: MarginContainer, base: float) -> void:
	var fit: Callable = func() -> void:
		var inset: float = frame_inset(margin.size)
		var want: int = int(base + inset)
		# T-144: only on a change; an unsized parent made this feed back (margins -> min size -> resized -> margins)
		if margin.get_theme_constant("margin_left") == want and margin.get_theme_constant("margin_right") == want:
			return
		margin.add_theme_constant_override("margin_left", want)
		margin.add_theme_constant_override("margin_right", want)
	margin.resized.connect(fit)
	fit.call()


## The HUD margin for a viewport: ui.json hud.margin, never under safe_frac of the viewport (the TV safe area).
## T-100: on a screen wider than hud.max_aspect (21:9 = 2.4; a 32:9 monitor) the side margins grow so the HUD keeps
## to a centred 21:9 frame instead of the far corners of the player's peripheral vision.
static func hud_margin(vp: Vector2) -> Vector2:
	var m: Array = hud("margin", [56.0, 44.0])
	var f: float = float(hud("safe_frac", 0.03))
	var mx: float = maxf(float(m[0]), vp.x * f)
	var ma: float = float(hud("max_aspect", 0.0))
	if ma > 0.0 and vp.y > 0.0 and vp.x > vp.y * ma:
		mx = (vp.x - vp.y * ma) * 0.5 + maxf(float(m[0]), vp.y * ma * f)
	return Vector2(mx, maxf(float(m[1]), vp.y * f))


# ================================================================== fonts

## The font for a key of ui.json "fonts" (stamp, stamp_light, type, body, body_bold, mono, mono_bold): the bundled
## file (a FontVariation at the given weight on a variable file) with the system fallback behind it.
static func font(key: String) -> Font:
	if _fonts.has(key):
		return _fonts[key]
	var fonts: Dictionary = cfg().get("fonts", {})
	var d: Dictionary = fonts.get(key, {})
	var names: PackedStringArray = PackedStringArray(d.get("fallback", ["Courier New", "Consolas"]))
	var sys: SystemFont = SystemFont.new()   # the declared fallback (the only SystemFont left in gravelight/ui)
	sys.font_names = names
	if key.begins_with("mono") or key == "type":
		sys.font_weight = 700
	var out: Font = sys
	var path: String = str(d.get("file", ""))
	var file: Font = (load(path) as Font) if path != "" and ResourceLoader.exists(path) else null
	if file != null:
		var fv: FontVariation = FontVariation.new()
		fv.base_font = file
		fv.fallbacks = [sys]
		if d.has("weight"):
			fv.variation_opentype = {WGHT: int(d["weight"])}
		out = fv
	else:
		_fallback_used[key] = true
		if path != "":
			push_warning("MenuKit: font file missing, using the system fallback for '%s' (%s)" % [key, path])
	_fonts[key] = out
	return out


## Whether the bundled file loaded for every font key (false when any system fallback stood in).
static func fonts_bundled() -> bool:
	for k: String in FONT_KEYS:
		font(k)
	return _fallback_used.is_empty()


static func stamp_font() -> Font:
	return font("stamp")


static func type_font() -> Font:
	return font("type")


static func body_font() -> Font:
	return font("body")


static func mono_font() -> Font:
	return font("mono")


## The font for a role (ui.json "roles": display, stamp, title, heading, subheading, button, body, caption, mono,
## counter...).
static func role_font(role: String) -> Font:
	return font(str(cfg().get("roles", {}).get(role, "type")))


# ================================================================== theme

## The shared Theme (gravelight_theme.tres): default body font and size, the typewriter on buttons, a visible
## gold focus outline, the ledger panels, sliders, popups and tooltips.
static func theme() -> Theme:
	if _theme == null:
		_theme = load(THEME_PATH) as Theme
		if _theme == null:
			push_error("MenuKit: theme missing at " + THEME_PATH)
			_theme = Theme.new()
	return _theme


## Applies the theme at a HUD / menu root (every Control under it inherits it).
static func apply_theme(root: Control) -> void:
	if root != null and root.theme != theme():
		root.theme = theme()


## The dark outline + drop shadow of a kind from ui.json "outline" (menu, hud, prompt, banner, subtitle, stamp;
## paper = none) on a Label, Button or RichTextLabel.
static func outline(c: Control, kind: String = "menu") -> void:
	var o: Dictionary = cfg().get("outline", {}).get(kind, {"size": 3, "color": [0, 0, 0, 0.7], "shadow": [1, 1, 0.35]})
	var col: Array = o.get("color", [0, 0, 0, 0.7])
	var oc: Color = Color(float(col[0]), float(col[1]), float(col[2]), float(col[3]) if col.size() > 3 else 1.0)
	var sh: Array = o.get("shadow", [0, 0, 0])
	var sc: Color = Color(0, 0, 0, float(sh[2]) if sh.size() > 2 else 0.0)
	c.add_theme_constant_override("outline_size", int(o.get("size", 0)))
	c.add_theme_color_override("font_outline_color", oc)
	if c is Label:
		c.add_theme_color_override("font_shadow_color", sc)
		c.add_theme_constant_override("shadow_offset_x", int(sh[0]) if sh.size() > 0 else 0)
		c.add_theme_constant_override("shadow_offset_y", int(sh[1]) if sh.size() > 1 else 0)
	elif c is RichTextLabel:
		c.add_theme_color_override("font_shadow_color", sc)
		c.add_theme_constant_override("shadow_offset_x", int(sh[0]) if sh.size() > 0 else 0)
		c.add_theme_constant_override("shadow_offset_y", int(sh[1]) if sh.size() > 1 else 0)


# ================================================================== builders

## A label in the typewriter (or the stencil with `stamp`); `size` is snapped onto the scale, -1 = body.
static func label(text: String, size: int = -1, color: Color = PAPER, stamp: bool = false) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", stamp_font() if stamp else type_font())
	l.add_theme_font_size_override("font_size", px(size) if size > 0 else MenuKit.size("body"))
	l.add_theme_color_override("font_color", color)
	outline(l, "menu")
	return l


## A label by role: display / stamp / title (stencil), heading / subheading / button (typewriter), body / body_large
## / caption / fine (sans), mono / counter (mono). The size is the role's scale entry.
static func text(role: String, text_str: String, color: Color = PAPER, outline_kind: String = "menu") -> Label:
	var l: Label = Label.new()
	l.text = text_str
	l.add_theme_font_override("font", role_font(role))
	l.add_theme_font_size_override("font_size", MenuKit.size(role))
	l.add_theme_color_override("font_color", color)
	outline(l, outline_kind)
	return l


const WORDMARK_PATH: String = "res://gravelight/ui/wordmark/claude_zombies.png"


## The CLAUDE ZOMBIES wordmark (T-140) as a TextureRect, height_px tall, aspect kept (the png is 2048 x 940).
static func wordmark(height_px: float) -> Control:
	var tr: TextureRect = TextureRect.new()
	tr.name = "Wordmark"
	if ResourceLoader.exists(WORDMARK_PATH):
		tr.texture = load(WORDMARK_PATH) as Texture2D
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(height_px * 2048.0 / 940.0, height_px)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## T-144: a letter-spaced copy of a font (the menu's caps: "P L A Y"), cached per (font, spacing).
static var _spaced: Dictionary = {}


static func spaced(base: Font, spacing: int) -> Font:
	var key: String = "%d|%d" % [base.get_instance_id(), spacing]
	if _spaced.has(key):
		return _spaced[key]
	var fv: FontVariation = FontVariation.new()
	fv.base_font = base
	fv.spacing_glyph = spacing
	_spaced[key] = fv
	return fv


## T-144: programmatic focus (a menu building its column) stays silent until this tick time.
static var _quiet_until: int = 0


static func quiet(msec: int = 250) -> void:
	_quiet_until = Time.get_ticks_msec() + msec


static func is_quiet() -> bool:
	return Time.get_ticks_msec() < _quiet_until


## T-144: the main menu's large column button (Special Elite, letter-spaced caps). Hover and focus are one state:
## the label slides LINK_SLIDE px right, a violet glow comes up behind it and the typewriter ticks; a press stamps.
const LINK_SLIDE: float = 12.0
const LINK_MARGIN: float = 16.0


static func menu_link(text_str: String, cb: Callable, size_px: int = 38) -> Button:
	var b: Button = Button.new()
	b.name = "Link_" + text_str.to_upper().replace(" ", "_").replace("&", "AND")
	b.text = text_str.to_upper()
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", spaced(type_font(), 5))
	b.add_theme_font_size_override("font_size", size_px)
	b.add_theme_color_override("font_color", PAPER.darkened(0.12))
	b.add_theme_color_override("font_hover_color", PAPER)
	b.add_theme_color_override("font_focus_color", PAPER)
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_color_override("font_hover_pressed_color", GOLD)
	b.add_theme_color_override("font_disabled_color", DIM.darkened(0.3))
	b.add_theme_constant_override("outline_size", 6)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.0)
	sb.shadow_color = Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.0)
	sb.shadow_size = 18
	sb.border_color = Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.0)
	sb.border_width_left = 3
	sb.set_corner_radius_all(2)
	sb.content_margin_left = LINK_MARGIN
	sb.content_margin_right = 24
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	for state: String in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		b.add_theme_stylebox_override(state, sb)
	b.custom_minimum_size = Vector2(0, size_px * 1.55)
	b.set_meta("link_box", sb)
	var lit: Callable = func(on: bool) -> void:
		if not b.is_inside_tree():
			return
		var tw: Tween = b.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(sb, "content_margin_left", LINK_MARGIN + (LINK_SLIDE if on and not MenuMotion.reduced() else 0.0), 0.16)
		tw.tween_property(sb, "bg_color:a", 0.07 if on else 0.0, 0.16)
		tw.tween_property(sb, "shadow_color:a", 0.12 if on else 0.0, 0.16)
		tw.tween_property(sb, "border_color:a", 1.0 if on else 0.0, 0.16)
	b.focus_entered.connect(func() -> void:
		lit.call(true)
		if not is_quiet():
			AudioDirector.play_2d("ui_tick", 0.0, 0.06))
	b.focus_exited.connect(lit.bind(false))
	b.mouse_entered.connect(func() -> void:
		if not b.disabled and b.focus_mode != Control.FOCUS_NONE:
			b.grab_focus())
	b.pressed.connect(func() -> void: AudioDirector.play_2d("ui_stamp", 0.0, 0.03))
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


## T-144: a thin vertical violet rule (left of the main menu's column).
static func rule(height: float, width: float = 2.0, color: Color = VIOLET) -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.name = "Rule"
	r.color = Color(color.r, color.g, color.b, 0.85)
	r.custom_minimum_size = Vector2(width, height)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## T-144: a screen comes in: 0.25 s cross-fade with a 20 px slide (from the right; dir -1 from the left). The control
## must not sit in a container (the container would put it back).
static func transition_in(c: Control, dir: float = 1.0, secs: float = MenuMotion.SCREEN_S, px_off: float = MenuMotion.SLIDE_PX) -> void:
	MenuMotion.slide_in(c, dir, secs, px_off)   # T-267: every menu tween lives in MenuMotion (and obeys "Reduce motion")


## T-144: the reverse; `done` runs when it has faded.
static func transition_out(c: Control, done: Callable = Callable(), dir: float = -1.0, secs: float = MenuMotion.OUT_S, px_off: float = MenuMotion.SLIDE_PX) -> void:
	MenuMotion.slide_out(c, done, dir, secs, px_off)


## A readable paragraph in the body face, word-wrapped.
static func para(text_str: String, size: int = -1, color: Color = PAPER) -> Label:
	var l: Label = Label.new()
	l.text = text_str
	l.add_theme_font_override("font", body_font())
	l.add_theme_font_size_override("font_size", px(size) if size > 0 else MenuKit.size("body"))
	l.add_theme_color_override("font_color", color)
	outline(l, "menu")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## `sound`: the bank key played on press ("ui_click", "ui_confirm", "ui_back"; "" for none).
static func button(text_str: String, cb: Callable, size: int = 24, sound: String = "ui_click") -> Button:
	var b: Button = Button.new()
	b.text = text_str
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", type_font())
	b.add_theme_font_size_override("font_size", px(size))
	b.custom_minimum_size = Vector2(0, px(size) * 1.9)
	b.focus_mode = Control.FOCUS_ALL
	if sound != "":
		b.pressed.connect(func() -> void: AudioDirector.play_2d(sound, 0.0, 0.0))
	if cb.is_valid():
		b.pressed.connect(cb)
	MenuMotion.feedback(b)   # T-267: hover / focus / press feedback on every menu button
	return b


static func panel(min_size: Vector2 = Vector2.ZERO) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.07, 0.86)
	sb.border_color = BRASS_DARK
	sb.set_border_width_all(2)
	sb.set_content_margin_all(18)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = min_size
	return p


## The ledger page: cream paper with a dark brown rule, for the pause tabs and tooltips.
static func paper_box(alpha: float = 0.96) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.86, 0.81, 0.69, alpha)
	sb.border_color = Color(0.36, 0.25, 0.16)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(8)
	return sb


static func bar(value: float, width: float = 320.0, color: Color = INK) -> ProgressBar:
	var pb: ProgressBar = ProgressBar.new()
	pb.max_value = 1.0
	pb.value = value
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(width, 10)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = color
	pb.add_theme_stylebox_override("fill", fill)
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	pb.add_theme_stylebox_override("background", bg)
	return pb


## The left inset that puts a row's label under a button's text (the theme's 3 px rule + 14 px margin; T-218).
const ROW_INSET: float = 17.0
## How much of a row's width the control may take (the rest stays empty, so a slider is not 1,400 px long).
const ROW_CONTROL_SHARE: float = 0.72


## A label and its control on one line. A slider gets its value printed after it (slider_text, T-218). The label
## lines up with the text of the buttons and switches above and below it.
static func row(label_text: String, control: Control, label_width: float = 300.0) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var l: Label = label(label_text, 20)
	l.custom_minimum_size = Vector2(label_width, 0)
	var inset: StyleBoxEmpty = StyleBoxEmpty.new()
	inset.content_margin_left = ROW_INSET
	l.add_theme_stylebox_override("normal", inset)
	h.add_child(l)
	var body: Control = control
	if control is HSlider:
		var s: HSlider = control as HSlider
		var hb: HBoxContainer = HBoxContainer.new()
		hb.add_theme_constant_override("separation", 14)
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(s)
		var v: Label = label(slider_text(s.value, s.min_value, s.max_value, s.step, str(s.get_meta("fmt", ""))), 19, GOLD)
		v.add_theme_font_override("font", mono_font())
		v.custom_minimum_size = Vector2(px(19) * 4.2, 0)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.name = "Value"
		hb.add_child(v)
		s.value_changed.connect(func(x: float) -> void: v.text = slider_text(x, s.min_value, s.max_value, s.step, str(s.get_meta("fmt", ""))))
		body = hb
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_stretch_ratio = ROW_CONTROL_SHARE
	h.add_child(body)
	var rest: Control = Control.new()
	rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rest.size_flags_stretch_ratio = 1.0 - ROW_CONTROL_SHARE
	rest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(rest)
	return h


## `fmt`: how row() prints the value: "pct" (0..1 as a percent), "x" (a multiplier, 1.25x), "deg" (degrees), or
## a format string with one placeholder ("%d%%"); "" picks one from the range (T-218).
static func slider(lo: float, hi: float, step: float, value: float, cb: Callable, fmt: String = "") -> HSlider:
	var s: HSlider = HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(280, 28)
	s.focus_mode = Control.FOCUS_ALL
	s.set_meta("fmt", fmt)
	s.value_changed.connect(cb)
	return s


## A slider's value as row() prints it (pure, unit-tested). With no fmt: 0..1 -> a percent, whole steps -> an
## integer, anything else -> two decimals.
static func slider_text(v: float, lo: float, hi: float, step: float, fmt: String = "") -> String:
	match fmt:
		"pct":
			return "%d%%" % roundi(v * 100.0)
		"x":
			return "%.2fx" % v
		"deg":
			return "%d°" % roundi(v)
		"":
			if lo >= 0.0 and hi <= 1.0:
				return "%d%%" % roundi(v * 100.0)
			if step >= 1.0:
				return "%d" % roundi(v)
			return "%.2f" % v
	return fmt % (roundi(v) if fmt.contains("%d") else v)


static func check(text_str: String, value: bool, cb: Callable) -> CheckButton:
	var c: CheckButton = CheckButton.new()
	c.text = text_str
	c.button_pressed = value
	c.add_theme_font_override("font", type_font())
	c.add_theme_font_size_override("font_size", MenuKit.size("body_large"))
	c.focus_mode = Control.FOCUS_ALL
	# T-218: a switch that reads at a glance: off was a lone dot on the dark panel
	c.add_theme_icon_override("checked", switch_icon(true, false))
	c.add_theme_icon_override("unchecked", switch_icon(false, false))
	c.add_theme_icon_override("checked_disabled", switch_icon(true, true))
	c.add_theme_icon_override("unchecked_disabled", switch_icon(false, true))
	c.toggled.connect(cb)
	MenuMotion.feedback(c)
	return c


## An on/off setting laid out like row(): the label in the label column, the switch at the end of the control
## column, so it lines up with the sliders' values and the dropdowns' arrows (T-218).
static func switch_row(text_str: String, value: bool, cb: Callable) -> HBoxContainer:
	var c: CheckButton = check("", value, cb)
	c.name = "Switch"
	c.tooltip_text = text_str
	var r: HBoxContainer = row(text_str, c)
	var l: Label = r.get_child(0) as Label
	l.mouse_filter = Control.MOUSE_FILTER_STOP   # the label toggles it too
	l.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			c.button_pressed = not c.button_pressed)
	return r


static var _switch_icons: Dictionary = {}


## A 52 x 26 px switch drawn once (T-218): on = a red pill with a paper knob on the right; off = an outlined pill
## with a dim knob on the left. Disabled ones are faded.
static func switch_icon(on: bool, disabled: bool) -> Texture2D:
	var key: String = "%s%s" % [on, disabled]
	if _switch_icons.has(key):
		return _switch_icons[key]
	var w: int = 52
	var h: int = 26
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var r: float = h * 0.5 - 1.0
	var track: Color = INK.lightened(0.1) if on else Color(0.1, 0.09, 0.1, 0.9)
	var edge: Color = INK.lightened(0.35) if on else DIM
	var knob: Color = PAPER if on else DIM.darkened(0.15)
	var kx: float = (w - r - 1.0) if on else (r + 1.0)
	for y: int in h:
		for x: int in w:
			var px_c: Vector2 = Vector2(x + 0.5, y + 0.5)
			var cx: float = clampf(px_c.x, r + 1.0, w - r - 1.0)
			var d: float = px_c.distance_to(Vector2(cx, h * 0.5))   # distance to the pill's spine
			var col: Color = Color(0, 0, 0, 0)
			var a_pill: float = clampf(r + 0.5 - d, 0.0, 1.0)
			if a_pill > 0.0:
				col = track
				col.a *= a_pill
				var a_edge: float = clampf(1.5 - absf(d - (r - 0.75)), 0.0, 1.0)
				col = col.lerp(Color(edge, col.a), a_edge)
			var dk: float = px_c.distance_to(Vector2(kx, h * 0.5))
			var a_knob: float = clampf(r - 3.5 + 0.5 - dk, 0.0, 1.0)
			if a_knob > 0.0:
				col = col.lerp(Color(knob, maxf(col.a, a_knob)), a_knob)
			if disabled:
				col.a *= 0.4
			img.set_pixel(x, y, col)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_switch_icons[key] = tex
	return tex


## A heading that opens a group of settings rows: some air above, the title in gold, a short rule (T-218).
static func section(title: String) -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	v.add_child(gap)
	var l: Label = label(title.to_upper(), 19, GOLD)
	l.add_theme_font_override("font", spaced(type_font(), 3))
	var inset: StyleBoxEmpty = StyleBoxEmpty.new()
	inset.content_margin_left = ROW_INSET
	l.add_theme_stylebox_override("normal", inset)
	v.add_child(l)
	var r: ColorRect = rule(1.0, 1.0, BRASS_DARK)
	r.custom_minimum_size = Vector2(0, 1)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(r)
	return v


## The explanation under a setting: readable size, indented under the row it explains (T-218).
static func help(text_str: String) -> MarginContainer:
	var m: MarginContainer = MarginContainer.new()
	m.add_theme_constant_override("margin_left", int(ROW_INSET))
	m.add_theme_constant_override("margin_right", 40)
	m.add_theme_constant_override("margin_bottom", 4)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_child(para(text_str, 17, DIM.lightened(0.12)))
	return m


static func options(items: PackedStringArray, selected: int, cb: Callable) -> OptionButton:
	var o: OptionButton = OptionButton.new()
	for it: String in items:
		o.add_item(it)
	o.selected = clampi(selected, 0, items.size() - 1)
	o.add_theme_font_override("font", type_font())
	o.add_theme_font_size_override("font_size", MenuKit.size("body_large"))
	o.focus_mode = Control.FOCUS_ALL
	o.item_selected.connect(cb)
	MenuMotion.feedback(o)
	return o


## Grabs focus on the first focusable control under `root` (for controller users).
static func focus_first(root: Node) -> void:
	var c: Control = _first_focusable(root)
	if c != null:
		c.grab_focus()


## Depth-first in tree (= on-screen) order. find_children would list a direct child (the Muster's bottom spacer)
## before the buttons nested in an earlier row, and the page opened scrolled to the end.
static func _first_focusable(n: Node) -> Control:
	for ch: Node in n.get_children():
		var c: Control = ch as Control
		if c != null and c.focus_mode == Control.FOCUS_ALL and c.is_visible_in_tree():
			return c
		var deeper: Control = _first_focusable(ch)
		if deeper != null:
			return deeper
	return null
