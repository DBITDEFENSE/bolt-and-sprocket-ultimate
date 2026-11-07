class_name CinemaOverlay
extends Node
## T-184: everything a cutscene draws over the picture, in the game's look (MenuKit fonts and colours):
##   - the letterbox (2.39:1, at least BAR_MIN of the height), sliding in and out;
##   - the film fade from and to black (`fade`), and a dip through black between two shots (`dip`);
##   - the grade: exposure, contrast, saturation, tint, lift and vignette per shot (`grade`, presets in PRESETS),
##     a canvas shader over the 3D picture under the frame, so it reads the same on Forward+ and on the Compatibility
##     / browser renderer (WebProfile) and costs one screen copy;
##   - the title card for an arrival: the place in the stamp face, a rule, then the place / date / time line typed
##     out in the typewriter face (`title_card`);
##   - narration captions just above the bottom bar (`caption`; the VO subtitles move into the bar, Subtitles.cinema);
##   - "hold [key] to skip": holding [interact] (keyboard or pad) fills a bar; at full it emits `skip`. The prompt
##     shows after `skip_after` seconds and whenever the key goes down; `skip_note` carries the co-op tally;
##   - the HUD hidden for the length of the cutscene (the map's CanvasLayers moved off screen, the PostFx film look
##     kept; `restore_hud` puts them back).
## Presentation only. Speed-aware: every tween length is divided by `speed` (Campaign.cutscene_speed in tests).

signal skip

const BAR_MIN: float = 0.085
const ASPECT: float = 2.39
const BONE: Color = Color(0.93, 0.89, 0.8)
const VIOLET: Color = Color(0.62, 0.45, 0.85)
const PRESETS: Dictionary = {
	"neutral": {},
	"night": {"exposure": 0.96, "contrast": 1.08, "saturation": 0.82, "tint": [0.92, 0.97, 1.08], "lift": [0.0, 0.006, 0.02], "vignette": 0.34},
	"dawn": {"exposure": 1.05, "contrast": 1.05, "saturation": 1.02, "tint": [1.07, 0.99, 0.9], "lift": [0.018, 0.008, 0.0], "vignette": 0.28},
	"warm": {"exposure": 1.02, "contrast": 1.06, "saturation": 0.95, "tint": [1.08, 0.97, 0.86], "lift": [0.01, 0.004, 0.0], "vignette": 0.36},
	"cold": {"exposure": 1.0, "contrast": 1.1, "saturation": 0.72, "tint": [0.9, 0.96, 1.08], "lift": [0.0, 0.004, 0.016], "vignette": 0.34},
	"storm": {"exposure": 0.94, "contrast": 1.12, "saturation": 0.62, "tint": [0.88, 0.97, 1.04], "lift": [0.0, 0.01, 0.02], "vignette": 0.42},
	"salt": {"exposure": 1.0, "contrast": 1.08, "saturation": 0.78, "tint": [1.0, 0.97, 1.02], "lift": [0.01, 0.006, 0.014], "vignette": 0.4},
	"violet": {"exposure": 1.0, "contrast": 1.1, "saturation": 0.86, "tint": [1.0, 0.9, 1.1], "lift": [0.02, 0.0, 0.035], "vignette": 0.4},
	"desert": {"exposure": 1.04, "contrast": 1.06, "saturation": 0.9, "tint": [1.07, 1.0, 0.88], "lift": [0.012, 0.008, 0.0], "vignette": 0.26},
	"space": {"exposure": 1.0, "contrast": 1.14, "saturation": 0.8, "tint": [0.96, 0.97, 1.05], "lift": [0.0, 0.0, 0.01], "vignette": 0.46},
	"memory": {"exposure": 1.02, "contrast": 1.04, "saturation": 0.32, "tint": [1.06, 0.98, 0.86], "lift": [0.03, 0.02, 0.01], "vignette": 0.52},
}

const GRADE_SHADER: String = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform float exposure = 1.0;
uniform float contrast = 1.0;
uniform float saturation = 1.0;
uniform vec3 tint = vec3(1.0);
uniform vec3 lift = vec3(0.0);
uniform float vignette = 0.0;
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb * exposure;
	c = (c - 0.5) * contrast + 0.5;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation) * tint;
	c = c + lift * (1.0 - clamp(c, 0.0, 1.0));
	vec2 d = SCREEN_UV - 0.5;
	float v = smoothstep(0.92, 0.28, length(d * vec2(1.2, 1.0)));
	c *= mix(1.0 - vignette, 1.0, v);
	COLOR = vec4(max(c, vec3(0.0)), 1.0);
}
"""

var speed: float = 1.0
var skip_after: float = 3.0
var skip_hold: float = 1.0
var skip_enabled: bool = true
var skip_note: String = ""
var skip_progress: float = 0.0
var skipped: bool = false
var bar_px: float = 0.0
var grade_now: Dictionary = {}
var frame_layer: int = 30   # the bars, the black, the words and the skip prompt (a card over the frame takes 41)

var _grade_layer: CanvasLayer
var _frame_layer: CanvasLayer
var _grade_rect: ColorRect
var _grade_mat: ShaderMaterial
var _top: ColorRect
var _bottom: ColorRect
var _black: ColorRect
var _title_box: Control
var _title: Label
var _rule: ColorRect
var _sub: Label
var _time: Label
var _caption: Label
var _skip_box: Control
var _skip_label: Label
var _skip_fill: ColorRect
var _t: float = 0.0
var _show_skip_until: float = 0.0
var _hidden_hud: Dictionary = {}
var _hidden_world: Array[Node] = []
var _grade_tween: Tween = null
var _subs_cinema: bool = false
var _armed: bool = false   # a fresh press: a key still held from the beacon's vote does not count


func _ready() -> void:
	_grade_layer = CanvasLayer.new()
	_grade_layer.layer = 6   # over the 3D picture and the PostFx film look (5), under every HUD and the frame
	add_child(_grade_layer)
	_grade_rect = ColorRect.new()
	_grade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh: Shader = Shader.new()
	sh.code = GRADE_SHADER
	_grade_mat = ShaderMaterial.new()
	_grade_mat.shader = sh
	_grade_rect.material = _grade_mat
	_grade_rect.visible = false
	_grade_layer.add_child(_grade_rect)
	_frame_layer = CanvasLayer.new()
	_frame_layer.layer = frame_layer
	add_child(_frame_layer)
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	MenuKit.apply_theme(root)
	_frame_layer.add_child(root)
	_top = _rect(root, Color.BLACK)
	_top.anchor_right = 1.0
	_top.offset_bottom = 0.0
	_bottom = _rect(root, Color.BLACK)
	_bottom.anchor_top = 1.0
	_bottom.anchor_right = 1.0
	_bottom.anchor_bottom = 1.0
	_bottom.offset_top = 0.0
	_black = _rect(root, Color.BLACK)   # always opaque; its modulate fades (a colour alpha tween did not draw on the Compatibility renderer)
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # (after add_child: set_anchors_preset alone kept it 0 x 0)
	_black.modulate.a = 0.0
	_build_title(root)
	_caption = Label.new()
	_caption.add_theme_font_override("font", MenuKit.body_font())
	_caption.add_theme_font_size_override("font_size", MenuKit.size("body_large"))
	_caption.add_theme_color_override("font_color", Color(0.9, 0.86, 0.78))
	MenuKit.outline(_caption, "menu")
	_caption.anchor_left = 0.12
	_caption.anchor_right = 0.88
	_caption.anchor_top = 1.0
	_caption.anchor_bottom = 1.0
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.modulate.a = 0.0
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_caption)
	_build_skip(root)
	bar_px = bar_height(_view_size())
	_layout()


func _rect(parent: Control, c: Color) -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.color = c
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


func _view_size() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1920, 1080)


## The bar height for a view: what 2.39:1 leaves, never under BAR_MIN of the height (an ultra-wide screen still
## gets a frame). Pure.
static func bar_height(view: Vector2) -> float:
	if view.y <= 0.0:
		return 0.0
	var want: float = maxf(0.0, (view.y - view.x / ASPECT) * 0.5)
	return clampf(maxf(want, view.y * BAR_MIN), 0.0, view.y * 0.2)


func _layout() -> void:
	_caption.offset_bottom = -bar_px - MenuKit.px(10)
	_caption.offset_top = _caption.offset_bottom - MenuKit.px(90)
	_skip_box.offset_bottom = -maxf(8.0, bar_px * 0.5 - MenuKit.px(14))
	_skip_box.offset_top = _skip_box.offset_bottom - MenuKit.px(32)


func _build_title(root: Control) -> void:
	_title_box = Control.new()
	_title_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_box.modulate.a = 0.0
	root.add_child(_title_box)
	# a soft band of shadow behind the card, so the lines read over a bright frame (the salt flat, the snow at dawn)
	var scrim: TextureRect = TextureRect.new()
	var grad: Gradient = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.35, 0.65, 1.0])
	grad.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.42), Color(0, 0, 0, 0.42), Color(0, 0, 0, 0)])
	var gt: GradientTexture2D = GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 128
	scrim.texture = gt
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.anchor_right = 1.0
	scrim.anchor_top = 0.27
	scrim.anchor_bottom = 0.68
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_box.add_child(scrim)
	_title = Label.new()
	_title.add_theme_font_override("font", MenuKit.stamp_font())
	_title.add_theme_font_size_override("font_size", MenuKit.px(104))
	_title.add_theme_color_override("font_color", BONE)
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	_title.add_theme_constant_override("shadow_offset_y", 4)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_title.anchor_left = 0.05
	_title.anchor_right = 0.95
	_title.anchor_top = 0.3
	_title.anchor_bottom = 0.47
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_box.add_child(_title)
	_rule = ColorRect.new()
	_rule.color = Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.9)
	_rule.anchor_left = 0.5
	_rule.anchor_right = 0.5
	_rule.anchor_top = 0.49
	_rule.anchor_bottom = 0.49
	_rule.offset_bottom = MenuKit.px(3)
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_box.add_child(_rule)
	_sub = _typed_label(0.51, MenuKit.size("heading"), BONE)
	_time = _typed_label(0.575, MenuKit.size("subheading"), Color(VIOLET.r + 0.2, VIOLET.g + 0.2, VIOLET.b + 0.12))


func _typed_label(top: float, size: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.add_theme_font_override("font", MenuKit.type_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	MenuKit.outline(l, "banner")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.anchor_left = 0.12
	l.anchor_right = 0.88
	l.anchor_top = top
	l.anchor_bottom = top + 0.06
	l.visible_ratio = 0.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_box.add_child(l)
	return l


func _build_skip(root: Control) -> void:
	_skip_box = Control.new()
	_skip_box.anchor_left = 1.0
	_skip_box.anchor_right = 1.0
	_skip_box.anchor_top = 1.0
	_skip_box.anchor_bottom = 1.0
	_skip_box.offset_left = -MenuKit.px(720)
	_skip_box.offset_right = -MenuKit.px(36)
	_skip_box.modulate.a = 0.0
	_skip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_skip_box)
	_skip_label = Label.new()
	_skip_label.add_theme_font_override("font", MenuKit.type_font())
	_skip_label.add_theme_font_size_override("font_size", MenuKit.size("body"))
	_skip_label.add_theme_color_override("font_color", Color(BONE.r, BONE.g, BONE.b, 0.8))
	_skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_skip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip_box.add_child(_skip_label)
	var track: ColorRect = ColorRect.new()
	track.color = Color(BONE.r, BONE.g, BONE.b, 0.18)
	track.anchor_left = 0.35
	track.anchor_right = 1.0
	track.anchor_top = 1.0
	track.anchor_bottom = 1.0
	track.offset_top = MenuKit.px(2)
	track.offset_bottom = MenuKit.px(4)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip_box.add_child(track)
	_skip_fill = ColorRect.new()
	_skip_fill.color = VIOLET
	_skip_fill.anchor_bottom = 1.0
	_skip_fill.anchor_right = 0.0
	_skip_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(_skip_fill)


func _k() -> float:
	return 1.0 / maxf(0.01, speed)


# ---------------------------------------------------------------- the frame

func bars(on: bool, seconds: float = 0.7) -> void:
	bar_px = bar_height(_view_size())
	_layout()
	var h: float = bar_px if on else 0.0
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(_top, "offset_bottom", h, maxf(0.01, seconds * _k())).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if on else Tween.EASE_IN)
	tw.tween_property(_bottom, "offset_top", -h, maxf(0.01, seconds * _k())).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if on else Tween.EASE_IN)
	_cinema_subtitles(on)


func bars_shown() -> float:
	return _top.offset_bottom


func fade(alpha: float, seconds: float) -> void:
	var tw: Tween = create_tween()
	tw.tween_property(_black, "modulate:a", clampf(alpha, 0.0, 1.0), maxf(0.01, seconds * _k())).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func set_black(alpha: float) -> void:
	_black.modulate.a = clampf(alpha, 0.0, 1.0)


func black() -> float:
	return _black.modulate.a


## A dip through black between two shots: down in half, up in half.
func dip(seconds: float) -> void:
	var half: float = maxf(0.01, seconds * 0.5 * _k())
	var tw: Tween = create_tween()
	tw.tween_property(_black, "modulate:a", 1.0, half).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_black, "modulate:a", 0.0, half).set_trans(Tween.TRANS_SINE)


# ---------------------------------------------------------------- the grade

## A grade by preset name or as a dictionary; blends from the current one over `seconds` (0 = at once).
static func grade_values(g: Variant) -> Dictionary:
	var d: Dictionary = {}
	if g is String:
		d = PRESETS.get(g, {})
	elif g is Dictionary:
		d = g
	return {
		"exposure": float(d.get("exposure", 1.0)), "contrast": float(d.get("contrast", 1.0)),
		"saturation": float(d.get("saturation", 1.0)), "vignette": float(d.get("vignette", 0.0)),
		"tint": CinemaShot.v3(d.get("tint", [1, 1, 1]), Vector3.ONE), "lift": CinemaShot.v3(d.get("lift", [0, 0, 0])),
	}


func grade(g: Variant, seconds: float = 0.0) -> void:
	if g == null:
		return
	var to: Dictionary = grade_values(g)
	var from: Dictionary = grade_now if not grade_now.is_empty() else grade_values("neutral")
	grade_now = to
	_grade_rect.visible = true
	if _grade_tween != null and _grade_tween.is_valid():
		_grade_tween.kill()
	if seconds <= 0.0:
		_apply_grade(from, to, 1.0)
		return
	_grade_tween = create_tween()
	_grade_tween.tween_method(func(k: float) -> void: _apply_grade(from, to, k), 0.0, 1.0, maxf(0.01, seconds * _k())).set_trans(Tween.TRANS_SINE)


func _apply_grade(a: Dictionary, b: Dictionary, k: float) -> void:
	for key: String in ["exposure", "contrast", "saturation", "vignette"]:
		_grade_mat.set_shader_parameter(key, lerpf(float(a[key]), float(b[key]), k))
	for key2: String in ["tint", "lift"]:
		_grade_mat.set_shader_parameter(key2, (a[key2] as Vector3).lerp(b[key2] as Vector3, k))


# ---------------------------------------------------------------- the words

## The arrival card: the place in the stamp face, the rule drawn out from the middle, the line(s) typed.
func title_card(title: String, sub: String, time_line: String = "", hold: float = 5.0) -> void:
	_title.text = title
	_sub.text = sub
	_time.text = time_line
	_sub.visible_ratio = 0.0
	_time.visible_ratio = 0.0
	_rule.offset_left = 0.0
	_rule.offset_right = 0.0
	var k: float = _k()
	var vp: Vector2 = _view_size()
	var fs: int = MenuKit.px(104)   # a long place name ("GROOM LAKE, NEVADA · 9 MAY 1945") shrinks to fit the frame
	var tw_px: float = MenuKit.stamp_font().get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if tw_px > vp.x * 0.86:
		fs = maxi(24, int(float(fs) * vp.x * 0.86 / tw_px))
	_title.add_theme_font_size_override("font_size", fs)
	_title.pivot_offset = Vector2(vp.x * 0.45, vp.y * 0.08)
	_title.scale = Vector2(1.06, 1.06)
	var tw: Tween = create_tween()
	tw.tween_property(_title_box, "modulate:a", 1.0, 0.45 * k)
	tw.parallel().tween_property(_title, "scale", Vector2.ONE, 0.9 * k).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_callback(func() -> void: AudioDirector.play_2d("ui_stamp", -2.0, 0.0)).set_delay(0.18 * k)
	var half: float = MenuKit.px(260)
	tw.tween_property(_rule, "offset_left", -half, 0.6 * k).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_rule, "offset_right", half, 0.6 * k).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if sub != "":
		tw.tween_callback(func() -> void: AudioDirector.play_2d("teletype_print", -14.0, 0.0))
		tw.tween_property(_sub, "visible_ratio", 1.0, clampf(0.035 * float(sub.length()), 0.6, 2.2) * k)
	if time_line != "":
		tw.tween_property(_time, "visible_ratio", 1.0, clampf(0.04 * float(time_line.length()), 0.4, 1.2) * k)
	tw.tween_interval(maxf(0.2, hold - 3.0) * k)
	tw.tween_property(_title_box, "modulate:a", 0.0, 0.9 * k)


func title_alpha() -> float:
	return _title_box.modulate.a


func caption(text: String, hold: float) -> void:
	_caption.text = text
	var k: float = _k()
	var tw: Tween = create_tween()
	tw.tween_property(_caption, "modulate:a", 1.0, 0.6 * k)
	tw.tween_interval(maxf(0.1, hold - 1.2) * k)
	tw.tween_property(_caption, "modulate:a", 0.0, 0.6 * k)


# ---------------------------------------------------------------- skip

func _process(delta: float) -> void:
	_t += delta * maxf(0.01, speed)
	if not skip_enabled or skipped:
		_skip_box.modulate.a = move_toward(_skip_box.modulate.a, 0.0, delta * 3.0)
		return
	var held: bool = Input.is_action_pressed(&"interact")
	if not held:
		_armed = true
	held = held and _armed
	if held:
		_show_skip_until = _t + 2.5
	feed_skip(held and _t >= skip_after, delta)
	var want: float = 1.0 if (_t >= skip_after and _t < skip_after + 4.0) or _t < _show_skip_until else 0.0
	_skip_box.modulate.a = move_toward(_skip_box.modulate.a, want, delta * 3.0)
	_refresh_skip_text()


## The hold: fills while held (real seconds), drains when let go; full = skip once.
func feed_skip(held: bool, delta: float) -> void:
	if skipped:
		return
	skip_progress = clampf(skip_progress + (delta / maxf(0.05, skip_hold) if held else -delta * 2.0), 0.0, 1.0)
	_skip_fill.anchor_right = skip_progress
	if skip_progress >= 1.0:
		skipped = true
		skip.emit()


func _refresh_skip_text() -> void:
	var key: String = GLSettings.action_label(&"interact")
	_skip_label.text = ("HOLD [%s] TO SKIP" % key) + ("   " + skip_note if skip_note != "" else "")


# ---------------------------------------------------------------- the HUD and the subtitles

## Moves every HUD layer under the map off screen (the HUD, the bots' nameplates, the minimap; not the PostFx film
## look, not this overlay), hides the marks' labels in the world (WorldMarks: "N  Courier at the gate · 25 m") and the
## perk row; restore_hud brings them back.
func hide_hud(map: Node) -> void:
	if map == null:
		return
	for c: Node in map.find_children("*", "CanvasLayer", true, false):
		if not (c is PostFx) and not _hidden_hud.has(c) and not is_ancestor_of(c):
			var cl: CanvasLayer = c as CanvasLayer
			_hidden_hud[cl] = cl.offset
			cl.offset = Vector2(0, -8000)
	for w: Node in map.get_tree().root.find_children("WorldMarks", "", true, false):
		if w is Node3D and (w as Node3D).visible:
			(w as Node3D).visible = false
			_hidden_world.append(w)
	var ph: CanvasLayer = PerkManager.get("_hud") as CanvasLayer
	if ph != null and not _hidden_hud.has(ph):
		_hidden_hud[ph] = ph.offset
		ph.offset = Vector2(0, -8000)


func restore_hud() -> void:
	for c: Variant in _hidden_hud.keys():
		if is_instance_valid(c):
			(c as CanvasLayer).offset = _hidden_hud[c]
	_hidden_hud.clear()
	for w: Node in _hidden_world:
		if is_instance_valid(w):
			(w as Node3D).visible = true
	_hidden_world.clear()


func _cinema_subtitles(on: bool) -> void:
	var subs: Node = GLVO.get("_subtitles") as Node
	if subs != null and subs.has_method("cinema"):
		subs.call("cinema", on, bar_px)
		_subs_cinema = on


func _exit_tree() -> void:
	restore_hud()
	if _subs_cinema:
		_cinema_subtitles(false)
