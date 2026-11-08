class_name CinemaFilm
extends Node
## T-209 (UPDATE 12 s3): the archive-reel treatment as a shader over the cinema camera's picture, so a reel shot with no
## clip yet (a stand-in: the in-engine shots under its span) reads as the same film as a generated clip. A definition
## with an `archive` dictionary (CinemaArchive.reel_def) gets one from CinemaDirector. Three canvas layers in the
## director's viewport:
##   8   the film's black: the overlay's fades and dips are drawn here instead of over everything (the overlay's own
##       black is made invisible; its alpha still drives this one), so black frames get grain and dust like leader;
##   9   the archive cards: the native lines (Russian or German, Old Standard TT) over the in-engine card's English
##       (Special Elite), in and out at the card's `at` / `hold` (a shot's `archive_card`);
##   29  the treatment: black-and-white or sepia through the archival curve, grain per film frame, scratches, dust,
##       gate weave, flicker, the vignette and the Academy-ratio gate (pillarbox). Under the frame (30: hold to skip).
## Deterministic per reel shot: the shader's seed is the shot's (CinemaArchive.seed_of, as archive_reel.py), its clock
## the director's. Over a built clip (CinemaVideo, already graded and gated by archive_reel.py) only the damage is
## added, so a clip and a stand-in carry the same live grain. Settings: film_grain off takes the grain out.

const SHADER: String = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float time_s = 0.0;
uniform float seed = 0.0;
uniform float film_fps = 18.0;
uniform vec3 tone = vec3(1.0);
uniform float contrast = 1.14;
uniform float lift = 0.055;
uniform float gain = 0.93;
uniform float grain = 0.075;
uniform float scratches = 0.35;
uniform float dust = 0.55;
uniform float weave = 1.4;
uniform float flicker = 0.045;
uniform float vignette = 0.42;
uniform float aspect = 1.375;
uniform float graded = 0.0;
uniform vec2 view_px = vec2(1920.0, 1080.0);

float h11(float p) { p = fract(p * 0.1031); p *= p + 33.33; p *= p + p; return fract(p); }
float h21(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }

void fragment() {
	float f = floor(time_s * film_fps);
	float fk = mod(f, 997.0);
	float va = view_px.x / max(1.0, view_px.y);
	float pw = min(1.0, aspect / va);
	float x0 = (1.0 - pw) * 0.5;
	vec2 uv = SCREEN_UV;
	if (uv.x < x0 || uv.x > 1.0 - x0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec2 pu = vec2((uv.x - x0) / pw, uv.y);
		vec2 wpx = (vec2(h11(fk * 1.37 + seed), h11(fk * 2.11 + seed * 1.7)) - 0.5) * 2.0 * weave;
		wpx += (vec2(h11(floor(f / 12.0) + seed * 0.3), h11(floor(f / 9.0) + seed * 0.9)) - 0.5) * weave;
		vec3 c = texture(screen_tex, uv + wpx / view_px).rgb;
		float l0 = dot(c, vec3(0.299, 0.587, 0.114));
		float l = l0;
		if (graded < 0.5) {
			l = clamp((l - 0.5) * contrast + 0.5, 0.0, 1.0);
			l = lift + (gain - lift) * l;
		}
		l *= 1.0 + (h11(fk * 0.71 + seed * 2.3) - 0.5) * 2.0 * flicker;
		vec2 gp = floor(FRAGCOORD.xy / 1.5);
		float g = h21(gp + vec2(fk * 17.0, fk * 29.0)) - 0.5;
		l += g * grain * 2.0 * (0.55 + 0.45 * (1.0 - abs(l - 0.5) * 2.0));
		for (int k = 0; k < 2; k++) {
			float blk = floor(f / 5.0) + float(k) * 31.0;
			if (h11(mod(blk, 997.0) * 1.7 + seed) < scratches * 0.5) {
				float sx = 0.05 + 0.9 * h11(mod(blk, 997.0) * 3.3 + seed + 0.5);
				float w = 1.0 + floor(h11(mod(blk, 997.0) * 5.1 + seed) * 2.0);
				float d = abs(pu.x - sx) * view_px.y * aspect;
				l = mix(l, l + 0.3, (1.0 - smoothstep(0.0, w, d)) * 0.8);
			}
		}
		for (int k = 0; k < 4; k++) {
			float key = fk * 4.0 + float(k);
			if (h11(key * 0.37 + seed) < dust * 0.45) {
				vec2 dp = vec2(h11(key * 1.9 + 0.3 + seed), h11(key * 2.7 + 0.9));
				float r = (1.5 + 4.0 * h11(key * 4.1)) / view_px.y;
				float a = 1.0 - smoothstep(r * 0.6, r, length((pu - dp) * vec2(aspect, 1.0)));
				l = mix(l, h11(key * 6.3) < 0.75 ? 0.04 : 0.92, a * 0.85);
			}
		}
		vec3 col;
		if (graded < 0.5) {
			vec2 d2 = pu - 0.5;
			l *= mix(1.0 - vignette, 1.0, smoothstep(0.85, 0.25, length(d2 * vec2(1.0, 0.9))));
			col = vec3(l) * tone;
		} else {
			col = c + vec3(l - l0);
		}
		COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
	}
}
"""

var cfg: Dictionary = {}
var director: CinemaDirector = null
var speed: float = 1.0
var mat: ShaderMaterial = null
var cards_shown: Array = []   # [shot index, native title] of every card shown (tests, smokes)
var seed_now: int = 0
var _dim: ColorRect = null
var _film_rect: ColorRect = null
var _card_box: Control = null
var _card_tween: Tween = null
var _fired: Dictionary = {}
var _rows: Array[Label] = []
var _rule: ColorRect = null


static func make(d: CinemaDirector, archive: Dictionary) -> CinemaFilm:
	var f: CinemaFilm = CinemaFilm.new()
	f.name = "CinemaFilm"
	f.cfg = archive
	f.director = d
	f.speed = d.speed
	d.add_child(f)
	return f


## The reel shot's seed at `t` (the shot's own between its span, the in-engine shot's index otherwise).
static func seed_at(spans: Array, t: float, shot_i: int) -> int:
	for s: Variant in spans:
		var a: Array = s
		if t >= float(a[0]) and t < float(a[1]):
			return int(a[2])
	return 7919 * (shot_i + 3)


func _ready() -> void:
	var dim_layer: CanvasLayer = CanvasLayer.new()
	dim_layer.name = "FilmBlack"
	dim_layer.layer = 8
	add_child(dim_layer)
	_dim = _full_rect(dim_layer, Color.BLACK)
	_dim.modulate.a = 0.0
	var card_layer: CanvasLayer = CanvasLayer.new()
	card_layer.name = "FilmCards"
	card_layer.layer = 9
	add_child(card_layer)
	_build_card(card_layer)
	var film_layer: CanvasLayer = CanvasLayer.new()
	film_layer.name = "Film"
	film_layer.layer = 29
	add_child(film_layer)
	_film_rect = _full_rect(film_layer, Color.WHITE)
	var sh: Shader = Shader.new()
	sh.code = SHADER
	mat = ShaderMaterial.new()
	mat.shader = sh
	_film_rect.material = mat
	var rgb: Array = cfg.get("tone_rgb", [1.0, 1.0, 1.0])
	mat.set_shader_parameter("tone", Vector3(float(rgb[0]), float(rgb[1]), float(rgb[2])))
	for k: String in ["contrast", "lift", "gain", "scratches", "dust", "weave", "flicker", "vignette", "aspect", "film_fps"]:
		if cfg.has(k):
			mat.set_shader_parameter(k, float(cfg[k]))
	var grain_on: bool = bool(GLSettings.values.get("film_grain", true))
	mat.set_shader_parameter("grain", float(cfg.get("grain", 0.075)) if grain_on else 0.0)
	if director != null and director.overlay != null:
		director.overlay._black.self_modulate.a = 0.0   # its alpha still runs the fades; this layer draws them


func _full_rect(parent: Node, c: Color) -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.color = c
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return r


func _build_card(layer: CanvasLayer) -> void:
	_card_box = Control.new()
	_card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_box.modulate.a = 0.0
	layer.add_child(_card_box)
	_card_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rule = ColorRect.new()
	_rule.color = Color(0.54, 0.5, 0.42, 0.8)
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_box.add_child(_rule)


static func native_font(italic: bool) -> Font:
	var p: String = "res://assets/third_party/google_fonts/old-standard-tt/OldStandard-%s.ttf" % ("Italic" if italic else "Bold")
	if ResourceLoader.exists(p):
		return load(p) as Font
	return MenuKit.stamp_font()


func _label(text: String, font: Font, size: int, color: Color, top: float) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.anchor_left = 0.5 - 0.5 * _gate_w() * 0.86
	l.anchor_right = 0.5 + 0.5 * _gate_w() * 0.86
	l.anchor_top = top
	l.anchor_bottom = top + 0.2
	_card_box.add_child(l)
	_rows.append(l)
	return l


## The gate's width as a fraction of the screen (the Academy picture inside a wide window).
func _gate_w() -> float:
	var vp: Vector2 = director.get_viewport().get_visible_rect().size if director != null and director.is_inside_tree() else Vector2(1920, 1080)
	return minf(1.0, float(cfg.get("aspect", 1.375)) / maxf(0.1, vp.x / maxf(1.0, vp.y)))


## An archive card: the native lines, a rule, the English under it; in, held, out.
func show_card(shot_i: int, card: Dictionary) -> void:
	for l: Label in _rows:
		l.queue_free()
	_rows.clear()
	var native: Array = card.get("native", [])
	var en: Array = card.get("english", [])
	var top: float = 0.3 if native.size() > 1 else 0.4
	for i: int in native.size():
		var size: int = MenuKit.px(88 if i == 0 else 38)
		var line: String = str(native[i])
		if i == 0 and line.length() > 22:
			size = int(float(size) * 22.0 / float(line.length()))
		_label(line, native_font(i > 0), size, Color(0.91, 0.88, 0.8), top)
		top += (0.11 if i == 0 else 0.055)
	top += 0.025
	_rule.anchor_left = 0.42
	_rule.anchor_right = 0.58
	_rule.anchor_top = top
	_rule.anchor_bottom = top
	_rule.offset_bottom = maxf(1.0, MenuKit.px(2))
	top += 0.03
	for i: int in en.size():
		_label(str(en[i]), MenuKit.type_font(), MenuKit.px(30 if i == 0 else 25), Color(0.66, 0.62, 0.55), top)
		top += 0.045
	cards_shown.append([shot_i, str(native[0]) if not native.is_empty() else (str(en[0]) if not en.is_empty() else "")])
	var k: float = 1.0 / maxf(0.01, speed)
	var hold: float = float(card.get("hold", 5.0))
	if _card_tween != null and _card_tween.is_valid():
		_card_tween.kill()
	_card_box.modulate.a = 0.0
	_card_tween = create_tween()
	_card_tween.tween_property(_card_box, "modulate:a", 1.0, 0.6 * k).set_trans(Tween.TRANS_SINE)
	_card_tween.tween_interval(maxf(0.2, hold - 1.3) * k)
	_card_tween.tween_property(_card_box, "modulate:a", 0.0, 0.7 * k).set_trans(Tween.TRANS_SINE)


func card_alpha() -> float:
	return _card_box.modulate.a


## The director's clock (CinemaDirector.step): the shader's frame, seed and grade state, the film black, the cards.
func at(t: float, shot_i: int) -> void:
	if mat == null:
		return
	seed_now = seed_at(cfg.get("spans", []), t, shot_i)
	mat.set_shader_parameter("time_s", t)
	mat.set_shader_parameter("seed", float(seed_now % 9973) / 7.0)
	var vp: Viewport = get_viewport()
	if vp != null:
		mat.set_shader_parameter("view_px", vp.get_visible_rect().size)
	var graded: bool = director != null and director.video != null and director.video.showing_graded()
	mat.set_shader_parameter("graded", 1.0 if graded else 0.0)
	if director != null and director.overlay != null:
		_dim.modulate.a = director.overlay.black()
	if director == null or shot_i < 0 or shot_i >= director.shots.size():
		return
	var s: CinemaShot = director.shots[shot_i]
	var ac: Variant = s.raw.get("archive_card", null)
	if ac is Dictionary and not _fired.has(shot_i) and t - s.t >= float((ac as Dictionary).get("at", 0.5)):
		_fired[shot_i] = true
		show_card(shot_i, ac as Dictionary)


func _exit_tree() -> void:
	if director != null and is_instance_valid(director) and director.overlay != null and is_instance_valid(director.overlay):
		director.overlay._black.self_modulate.a = 1.0
