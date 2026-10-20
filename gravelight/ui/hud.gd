class_name Hud
extends CanvasLayer
## Minimal classic HUD. Bottom-left: the round as a red ink stamp. Bottom-right: Scrip (with floating
## +numbers) and ammo. Center: crosshair, hit marker, context prompt with a hold bar. Red vignette when hurt.

const INK: Color = Color(0.62, 0.09, 0.08)
const PAPER: Color = Color(0.93, 0.89, 0.8)
const SCRIP_COL: Color = Color(0.95, 0.86, 0.55)

var player: Player
var _stamp_panel: PanelContainer
var _stamp_label: Label
var _scrip_label: Label
var _scrip_anchor: Control
var _ammo_label: Label
var _weapon_label: Label
var _nade_label: Label
var _prompt: Label
var _hold_bar: ProgressBar
var _crosshair: Crosshair
var _hitmarker: HitMarker
var _scope: ScopeOverlay
var _vignette: TextureRect
var _banner: Label
var _debug_label: Label
var _show_fps: bool = false
var _show_zombies: bool = false
var _denied_t: float = 0.0
var _stamp_font: SystemFont
var _type_font: SystemFont


func _init() -> void:
	layer = 10
	add_to_group(&"hud")


func setup(p: Player) -> void:
	player = p
	player.prompt_denied.connect(func() -> void: _denied_t = 0.5)


func _ready() -> void:
	_stamp_font = SystemFont.new()
	_stamp_font.font_names = PackedStringArray(["Stencil", "Impact", "Arial Black"])
	_type_font = SystemFont.new()
	_type_font.font_names = PackedStringArray(["Courier New", "Consolas", "Monospace"])
	_type_font.font_weight = 700
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# vignette
	_vignette = TextureRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(0.5, 0.0, 0.0, 0.0))
	grad.set_color(1, Color(0.45, 0.0, 0.0, 0.95))
	grad.add_point(0.55, Color(0.5, 0.0, 0.0, 0.0))
	var gt: GradientTexture2D = GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 1.05)
	gt.width = 256
	gt.height = 256
	_vignette.texture = gt
	_vignette.modulate.a = 0.0
	root.add_child(_vignette)
	# round stamp (bottom-left)
	_stamp_panel = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = INK
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	_stamp_panel.add_theme_stylebox_override("panel", sb)
	_stamp_panel.position = Vector2(48, 0)
	_stamp_panel.rotation = deg_to_rad(-5.0)
	_stamp_label = Label.new()
	_stamp_label.add_theme_font_override("font", _stamp_font)
	_stamp_label.add_theme_font_size_override("font_size", 96)
	_stamp_label.add_theme_color_override("font_color", INK)
	_stamp_label.text = ""
	_stamp_panel.add_child(_stamp_label)
	_stamp_panel.visible = false
	root.add_child(_stamp_panel)
	# bottom-right column
	var br: VBoxContainer = VBoxContainer.new()
	br.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	br.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	br.grow_vertical = Control.GROW_DIRECTION_BEGIN
	br.position = Vector2(-40, -40)
	br.alignment = BoxContainer.ALIGNMENT_END
	br.add_theme_constant_override("separation", 0)
	root.add_child(br)
	_scrip_anchor = Control.new()
	_scrip_anchor.custom_minimum_size = Vector2(0, 0)
	br.add_child(_scrip_anchor)
	_scrip_label = _label(br, "ǂ 500", 40, SCRIP_COL, _type_font)
	_weapon_label = _label(br, "", 20, PAPER, _type_font)
	_ammo_label = _label(br, "", 46, PAPER, _type_font)
	_nade_label = _label(br, "", 22, PAPER, _type_font)
	for l: Label in [_scrip_label, _weapon_label, _ammo_label, _nade_label]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# center
	_scope = ScopeOverlay.new()
	_scope.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scope.visible = false
	root.add_child(_scope)
	_crosshair = Crosshair.new()
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	root.add_child(_crosshair)
	_hitmarker = HitMarker.new()
	_hitmarker.set_anchors_preset(Control.PRESET_CENTER)
	root.add_child(_hitmarker)
	_prompt = _label(root, "", 26, PAPER, _type_font)
	_anchor_wide(_prompt, 0.5, 110.0, 40.0)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_hold_bar = ProgressBar.new()
	_hold_bar.show_percentage = false
	_hold_bar.anchor_left = 0.5
	_hold_bar.anchor_right = 0.5
	_hold_bar.anchor_top = 0.5
	_hold_bar.anchor_bottom = 0.5
	_hold_bar.offset_left = -110.0
	_hold_bar.offset_right = 110.0
	_hold_bar.offset_top = 150.0
	_hold_bar.offset_bottom = 156.0
	_hold_bar.max_value = 1.0
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = PAPER
	_hold_bar.add_theme_stylebox_override("fill", fill)
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	_hold_bar.add_theme_stylebox_override("background", bg)
	root.add_child(_hold_bar)
	# banner (map intro / round messages)
	_banner = _label(root, "", 34, PAPER, _type_font)
	_anchor_wide(_banner, 0.0, 140.0, 120.0)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_banner.modulate.a = 0.0
	# debug overlay
	_debug_label = _label(root, "", 18, Color(0.7, 1.0, 0.7), _type_font)
	_debug_label.position = Vector2(16, 12)
	GLBus.round_started.connect(_on_round_started)
	GLBus.scrip_changed.connect(_on_scrip_changed)
	GLBus.enemy_hit_feedback.connect(_on_hit_feedback)
	GLBus.dev_overlay_toggled.connect(_on_overlay)


## Full-width strip at a vertical anchor (0 = top, 0.5 = middle) with a pixel offset and height.
static func _anchor_wide(c: Control, anchor_y: float, offset_y: float, height: float) -> void:
	c.anchor_left = 0.0
	c.anchor_right = 1.0
	c.anchor_top = anchor_y
	c.anchor_bottom = anchor_y
	c.offset_left = 40.0
	c.offset_right = -40.0
	c.offset_top = offset_y
	c.offset_bottom = offset_y + height


func _label(parent: Control, text: String, size: int, color: Color, font: Font) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _process(delta: float) -> void:
	if player == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_stamp_panel.position = Vector2(56, vp.y - _stamp_panel.size.y - 52)
	var w: WeaponInstance = player.weapons.current()
	if w != null:
		_weapon_label.text = w.display_name()
		_ammo_label.text = "%d | %d" % [w.mag, w.reserve]
		var low: bool = w.mag <= int(ceil(w.mag_size() * 0.25))
		_ammo_label.add_theme_color_override("font_color", INK.lightened(0.25) if low else PAPER)
	var cook: float = player.weapons.cook_left()
	var nades: String = "◆ ".repeat(player.weapons.grenades).strip_edges()
	if player.weapons.tactical_id != &"":
		nades = "♫x%d   %s" % [player.weapons.tactical_count, nades]
	if cook >= 0.0 and GameState.has_trait(&"peg"):
		nades = "COOK %.1f   %s" % [cook, nades]
	_nade_label.text = nades
	# prompt
	_denied_t = maxf(0.0, _denied_t - delta)
	_prompt.text = player.prompt_text
	_prompt.add_theme_color_override("font_color", INK.lightened(0.3) if _denied_t > 0.0 else PAPER)
	_hold_bar.visible = player.interact_progress > 0.02 and player.prompt_text != ""
	_hold_bar.value = player.interact_progress
	# crosshair
	_crosshair.spread = player.weapons.spread_deg()
	_crosshair.visible = player.weapons.ads_t < 0.5 and not player.sprinting and not player.downed
	_scope.visible = player.weapons.scoped() and not player.downed
	# vignette: hurt + low health pulse
	var hurt: float = 1.0 - player.health_fraction()
	var pulse: float = 0.0
	if player.health_fraction() < 0.55:
		pulse = (sin(Time.get_ticks_msec() * 0.008) * 0.5 + 0.5) * 0.25
	_vignette.modulate.a = lerpf(_vignette.modulate.a, clampf(hurt * 1.1 + pulse, 0.0, 1.0), clampf(delta * 8.0, 0.0, 1.0))
	# debug
	var lines: PackedStringArray = []
	if _show_fps:
		lines.append("FPS %d" % Engine.get_frames_per_second())
	if _show_zombies:
		lines.append("Zombies alive %d  queued %d  round %d" % [RoundManager.alive, RoundManager.to_spawn, RoundManager.current_round])
	if GameState.god_mode:
		lines.append("GOD MODE")
	_debug_label.text = "\n".join(lines)


func show_banner(text: String, hold: float = 3.0) -> void:
	_banner.text = text
	var tw: Tween = create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.8)
	tw.tween_interval(hold)
	tw.tween_property(_banner, "modulate:a", 0.0, 1.2)


func _on_round_started(round_number: int, special: bool) -> void:
	_stamp_panel.visible = true
	_stamp_label.text = str(round_number)
	_stamp_panel.pivot_offset = _stamp_panel.size * 0.5
	_stamp_panel.scale = Vector2(1.9, 1.9)
	_stamp_panel.modulate.a = 0.0
	var tw: Tween = create_tween()
	# The stamp hits (0.22 s slam) on the stinger's downbeat.
	var beat: float = AudioDirector.stinger_downbeat(AudioDirector.round_stinger_key(round_number, special))
	if beat > 0.22:
		tw.tween_interval(beat - 0.22)
	tw.tween_property(_stamp_panel, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_property(_stamp_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: player.camera.v_offset = 0.0)


func _on_scrip_changed(p: int, total: int, delta: int) -> void:
	if player == null or p != player.player_id:
		return
	_scrip_label.text = "ǂ %d" % total
	if delta == 0:
		return
	var pop: Label = _label(_scrip_anchor, ("+%d" % delta) if delta > 0 else str(delta), 28,
		SCRIP_COL if delta > 0 else INK.lightened(0.3), _type_font)
	pop.position = Vector2(-160 - randf_range(0, 60), -10)
	var tw: Tween = pop.create_tween()
	tw.tween_property(pop, "position:y", pop.position.y - 70.0, 0.9).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(pop, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.tween_callback(pop.queue_free)


func _on_hit_feedback(p: int, killed: bool, headshot: bool) -> void:
	if player != null and p == player.player_id:
		_hitmarker.flash(killed, headshot)


func _on_overlay(overlay: StringName, enabled: bool) -> void:
	match overlay:
		&"fps":
			_show_fps = enabled
		&"zombies":
			_show_zombies = enabled


class Crosshair extends Control:
	var spread: float = 2.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var gap: float = 6.0 + spread * 5.0
		var c: Color = Color(0.95, 0.92, 0.85, 0.85)
		for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_line(d * gap, d * (gap + 9.0), c, 2.0)


## Hit confirmation: a white tick for a hit, larger amber ticks for a headshot, and a thick red X that pops
## out for a kill (amber-edged when the kill was a headshot). Multiple hits in quick succession re-pop it.
class HitMarker extends Control:
	const HIT: Color = Color(1.0, 1.0, 1.0, 0.92)
	const HEAD: Color = Color(1.0, 0.72, 0.2, 0.97)
	const KILL: Color = Color(0.9, 0.12, 0.1, 0.97)
	var _t: float = 0.0
	var _dur: float = 0.2
	var _kill: bool = false
	var _head: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func flash(killed: bool, headshot: bool) -> void:
		# a kill or headshot is never downgraded by a plain hit arriving in the same burst
		if _t > 0.0 and (_kill and not killed or _head and not headshot and not killed):
			_t = maxf(_t, 0.12)
			return
		_dur = 0.34 if killed else (0.26 if headshot else 0.18)
		_t = _dur
		_kill = killed
		_head = headshot

	func _process(delta: float) -> void:
		if _t > 0.0:
			_t -= delta
			queue_redraw()

	func _draw() -> void:
		if _t <= 0.0:
			return
		var age: float = 1.0 - _t / _dur                     # 0 -> 1
		var fade: float = clampf(_t / (_dur * 0.45), 0.0, 1.0)
		var pop: float = 1.0 + 0.45 * (1.0 - clampf(age / 0.18, 0.0, 1.0))   # starts big, settles fast
		var gap: float = (8.0 if not _head else 10.0) * pop
		var length: float = (8.0 if not _kill else 12.0) * pop
		var width: float = 2.0 if not _kill else 3.5
		var c: Color = KILL if _kill else (HEAD if _head else HIT)
		c.a *= fade
		for d: Vector2 in [Vector2(0.7071, 0.7071), Vector2(-0.7071, 0.7071), Vector2(0.7071, -0.7071), Vector2(-0.7071, -0.7071)]:
			var a: Vector2 = d * gap
			var b: Vector2 = d * (gap + length)
			draw_line(a + Vector2(1, 1), b + Vector2(1, 1), Color(0, 0, 0, 0.45 * fade), width + 1.0)
			if _kill and _head:
				draw_line(a, b, Color(HEAD.r, HEAD.g, HEAD.b, fade), width + 2.0)
			draw_line(a, b, c, width)


## Scoped ADS (rifles with a "scope" model meta): a round field of view with an original post-and-wire
## reticle, everything outside the eyepiece blacked out. The viewmodel hides while this shows.
class ScopeOverlay extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var sz: Vector2 = size
		var c: Vector2 = sz * 0.5
		var r: float = sz.y * 0.46
		var black: Color = Color(0.0, 0.0, 0.0, 1.0)
		# mask: four bars plus a ring of quads around the circle
		draw_rect(Rect2(0, 0, c.x - r, sz.y), black)
		draw_rect(Rect2(c.x + r, 0, sz.x - c.x - r, sz.y), black)
		var n: int = 64
		for i: int in n:
			var a0: float = TAU * float(i) / n
			var a1: float = TAU * float(i + 1) / n
			var p0: Vector2 = c + Vector2(cos(a0), sin(a0)) * r
			var p1: Vector2 = c + Vector2(cos(a1), sin(a1)) * r
			var q0: Vector2 = c + Vector2(cos(a0), sin(a0)) * r * 1.5
			var q1: Vector2 = c + Vector2(cos(a1), sin(a1)) * r * 1.5
			draw_colored_polygon(PackedVector2Array([p0, p1, q1, q0]), black)
		# soft inner edge
		for k: int in 6:
			draw_arc(c, r - k * 3.0, 0.0, TAU, 96, Color(0, 0, 0, 0.32 - k * 0.05), 3.0)
		# reticle: thick posts from left, right and bottom ending short of center, thin crosswires
		var ink: Color = Color(0.03, 0.03, 0.03, 0.95)
		var gap: float = r * 0.12
		draw_rect(Rect2(c.x - r, c.y - 3.0, r - gap, 6.0), ink)
		draw_rect(Rect2(c.x + gap, c.y - 3.0, r - gap, 6.0), ink)
		var post: PackedVector2Array = PackedVector2Array([Vector2(c.x - 6.0, c.y + r), Vector2(c.x + 6.0, c.y + r),
			Vector2(c.x + 1.5, c.y + 2.0), Vector2(c.x - 1.5, c.y + 2.0)])
		draw_colored_polygon(post, ink)
		draw_line(Vector2(c.x - gap, c.y), Vector2(c.x + gap, c.y), ink, 1.2)
		draw_line(Vector2(c.x, c.y - r), Vector2(c.x, c.y), ink, 1.2)
