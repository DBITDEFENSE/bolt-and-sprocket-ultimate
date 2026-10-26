class_name Hud
extends CanvasLayer
## Minimal classic HUD. Bottom-left: the round as a red ink stamp over the perk caps. Bottom-right: Scrip (with
## floating +numbers), the gun and its ammo. Center: crosshair, hit marker, context prompt with a hold bar. Red
## vignette when hurt. T-096: everything hangs on the grid in data/gravelight/ui.json ("hud": margins with a safe
## area, offsets), uses the kit's bundled fonts and scale (MenuKit) and a dark outline + drop shadow so it reads on
## snow and in the dark; the theme is applied at the root.

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
var _br: VBoxContainer
var _show_fps: bool = false
var _show_zombies: bool = false
var _denied_t: float = 0.0
var _minimap: Minimap   # Update 04 section 2 (T-065): top-left, the zone stamped under it
var _toasts: int = 0     # T-078: bonus toasts on screen (they stack above the Scrip)
var _layout_vp: Vector2 = Vector2(-1, -1)


func _init() -> void:
	layer = 10
	add_to_group(&"hud")


func setup(p: Player) -> void:
	player = p
	player.prompt_denied.connect(func() -> void: _denied_t = 0.5)


## The round stamp's screen rect (tests, the perk row sits over it).
func stamp_rect() -> Rect2:
	return _stamp_panel.get_rect() if _stamp_panel != null else Rect2()


func _ready() -> void:
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	MenuKit.apply_theme(root)
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
	_minimap = Minimap.new()
	_minimap.game = "gravelight"
	root.add_child(_minimap)
	# round stamp (bottom-left): the red rubber stamp, a hair off square
	_stamp_panel = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = INK
	sb.set_border_width_all(int(MenuKit.hud("stamp_border", 5)))
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 0
	sb.content_margin_bottom = 2
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(1, 2)
	_stamp_panel.add_theme_stylebox_override("panel", sb)
	_stamp_panel.rotation = deg_to_rad(-5.0)
	_stamp_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamp_label = Label.new()
	_stamp_label.add_theme_font_override("font", MenuKit.stamp_font())
	_stamp_label.add_theme_font_size_override("font_size", MenuKit.size("hud_stamp"))
	_stamp_label.add_theme_color_override("font_color", INK)
	MenuKit.outline(_stamp_label, "stamp")
	_stamp_label.text = ""
	_stamp_panel.add_child(_stamp_label)
	_stamp_panel.visible = false
	root.add_child(_stamp_panel)
	# bottom-right column: Scrip, the gun, ammo, grenades (counters in the mono face so digits line up)
	_br = VBoxContainer.new()
	_br.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_br.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_br.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_br.alignment = BoxContainer.ALIGNMENT_END
	_br.add_theme_constant_override("separation", 0)
	_br.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_br)
	_scrip_anchor = Control.new()
	_scrip_anchor.custom_minimum_size = Vector2(0, 0)
	_scrip_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_br.add_child(_scrip_anchor)
	_scrip_label = _label(_br, "ǂ 500", MenuKit.size("hud_scrip"), SCRIP_COL, MenuKit.font("mono_bold"))
	_weapon_label = _label(_br, "", MenuKit.size("hud_weapon"), PAPER, MenuKit.type_font())
	_ammo_label = _label(_br, "", MenuKit.size("hud_ammo"), PAPER, MenuKit.font("mono_bold"))
	_nade_label = _label(_br, "", MenuKit.size("hud_nade"), PAPER, MenuKit.mono_font())
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
	_prompt = _label(root, "", MenuKit.size("hud_prompt"), PAPER, MenuKit.type_font())
	_anchor_wide(_prompt, 0.5, float(MenuKit.hud("prompt_y", 110.0)), 40.0)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	MenuKit.outline(_prompt, "prompt")
	_hold_bar = ProgressBar.new()
	_hold_bar.show_percentage = false
	_hold_bar.anchor_left = 0.5
	_hold_bar.anchor_right = 0.5
	_hold_bar.anchor_top = 0.5
	_hold_bar.anchor_bottom = 0.5
	var hbw: float = float(MenuKit.hud("hold_bar_w", 220.0)) * 0.5
	var hby: float = float(MenuKit.hud("hold_bar_y", 150.0))
	_hold_bar.offset_left = -hbw
	_hold_bar.offset_right = hbw
	_hold_bar.offset_top = hby
	_hold_bar.offset_bottom = hby + 6.0
	_hold_bar.max_value = 1.0
	_hold_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = PAPER
	_hold_bar.add_theme_stylebox_override("fill", fill)
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	_hold_bar.add_theme_stylebox_override("background", bg)
	root.add_child(_hold_bar)
	# banner (map intro / round messages)
	_banner = _label(root, "", MenuKit.size("hud_banner"), PAPER, MenuKit.type_font())
	_anchor_wide(_banner, 0.0, float(MenuKit.hud("banner_y", 140.0)), 120.0)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	MenuKit.outline(_banner, "banner")
	_banner.modulate.a = 0.0
	# debug overlay
	_debug_label = _label(root, "", MenuKit.size("hud_debug"), Color(0.7, 1.0, 0.7), MenuKit.mono_font())
	_debug_label.position = Vector2(16, 12)
	GLBus.round_started.connect(_on_round_started)
	GLBus.scrip_changed.connect(_on_scrip_changed)
	GLBus.bonus_awarded.connect(_on_bonus_awarded)
	GLBus.enemy_hit_feedback.connect(_on_hit_feedback)
	GLBus.dev_overlay_toggled.connect(_on_overlay)
	_layout()


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
	MenuKit.outline(l, "hud")
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## A label's font colour, set only when it changes: every add_theme_color_override re-themes the label, which
## the HUD did twice a frame (T-070).
static func _font_color(l: Label, c: Color) -> void:
	if not l.has_theme_color_override("font_color") or l.get_theme_color("font_color") != c:
		l.add_theme_color_override("font_color", c)


## The grid: margins (with the safe area) from ui.json; the stamp sits in the bottom-left corner, the counters in
## the bottom-right one, the prompt strip inside the side margins.
func _layout() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var m: Vector2 = MenuKit.hud_margin(vp)
	_layout_vp = vp
	_br.position = Vector2(-m.x, -m.y)
	_prompt.offset_left = m.x
	_prompt.offset_right = -m.x
	_banner.offset_left = m.x
	_banner.offset_right = -m.x
	_stamp_panel.position = Vector2(m.x, vp.y - _stamp_panel.size.y - m.y - 8.0)


func _process(delta: float) -> void:
	if player == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if vp != _layout_vp:
		_layout()
	var m: Vector2 = MenuKit.hud_margin(vp)
	_stamp_panel.position = Vector2(m.x, vp.y - _stamp_panel.size.y - m.y - 8.0)
	var w: WeaponInstance = player.weapons.current()
	if w != null:
		_weapon_label.text = w.display_name()
		_ammo_label.text = "%d | %d" % [w.mag, w.reserve]
		var low: bool = w.mag <= int(ceil(w.mag_size() * 0.25))
		_font_color(_ammo_label, INK.lightened(0.25) if low else PAPER)
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
	_font_color(_prompt, INK.lightened(0.3) if _denied_t > 0.0 else PAPER)
	_hold_bar.visible = player.interact_progress > 0.02 and player.prompt_text != ""
	_hold_bar.value = player.interact_progress
	# crosshair
	_crosshair.spread = player.weapons.spread_deg()
	_crosshair.fov = player.camera.fov if player.camera != null else 80.0
	_crosshair.speed = Vector2(player.velocity.x, player.velocity.z).length()
	_crosshair.target_alpha = 0.0 if (player.weapons.ads_t >= 0.5 or player.sprinting or player.mantling) else 1.0
	_crosshair.visible = not player.downed
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
	_debug_label.position = Vector2(m.x, 12) if Minimap.layout_bottom <= 0.0 else Vector2(m.x, Minimap.layout_bottom + 10.0)   # under the minimap


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
	tw.tween_callback(func() -> void:
		if player != null and player.camera != null:
			player.camera.v_offset = 0.0)


func _on_scrip_changed(p: int, total: int, delta: int) -> void:
	if player == null or p != player.player_id:
		return
	_scrip_label.text = "ǂ %d" % total
	if delta == 0:
		return
	var pop: Label = _label(_scrip_anchor, ("+%d" % delta) if delta > 0 else str(delta), MenuKit.size("hud_pop"),
		SCRIP_COL if delta > 0 else INK.lightened(0.3), MenuKit.font("mono_bold"))
	pop.position = Vector2(-160 - randf_range(0, 60), -10)
	var tw: Tween = pop.create_tween()
	tw.tween_property(pop, "position:y", pop.position.y - 70.0, 0.9).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(pop, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.tween_callback(pop.queue_free)


## T-078: a named bonus. Scrip bonuses stack as typed slips above the Scrip ("+175  ROUND 5 PAY"); a tonic bottle's
## gift is the banner.
func _on_bonus_awarded(p: int, kind: StringName, amount: int, text: String) -> void:
	if player == null or p != player.player_id:
		return
	if kind == &"tonic_bottle":
		show_banner(text, 3.0)
		if amount <= 0:
			return
	var slot: int = _toasts
	_toasts += 1
	var tw_w: float = float(MenuKit.hud("toast_width", 420.0))
	var row_h: float = float(MenuKit.hud("toast_row", 28.0))
	var t: Label = _label(_scrip_anchor, ("+%d  %s" % [amount, text]) if amount > 0 else text, MenuKit.size("hud_toast"), SCRIP_COL, MenuKit.type_font())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	t.size = Vector2(tw_w, row_h)
	t.position = Vector2(-tw_w - 10.0, -46 - row_h * float(slot % 5))
	var tw: Tween = t.create_tween()
	tw.tween_property(t, "position:y", t.position.y - 24.0, 2.2).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(t, "modulate:a", 0.0, 0.8).set_delay(1.6)
	tw.tween_callback(func() -> void:
		_toasts = maxi(0, _toasts - 1)
		t.queue_free())


func _on_hit_feedback(p: int, killed: bool, headshot: bool) -> void:
	if player != null and p == player.player_id:
		_hitmarker.flash(killed, headshot)


func _on_overlay(overlay: StringName, enabled: bool) -> void:
	match overlay:
		&"fps":
			_show_fps = enabled
		&"zombies":
			_show_zombies = enabled


## The scale of canvas px to physical px under a CanvasItem (window/stretch canvas_items), for pixel-crisp lines.
static func canvas_scale(ci: CanvasItem) -> float:
	var s: Vector2 = ci.get_global_transform_with_canvas().get_scale()
	var vs: Vector2 = ci.get_viewport().get_final_transform().get_scale()
	return maxf(0.25, s.x * vs.x)


## Snaps a canvas point to the physical pixel grid and draws a line `w` physical pixels thick along an axis, so
## 1-2 px ticks never land between pixels (no blur under the stretch).
static func crisp_line(ci: CanvasItem, a: Vector2, b: Vector2, w: float, col: Color, s: float) -> void:
	var pw: float = maxf(1.0, roundf(w * s))   # thickness in physical px
	var pa: Vector2 = (a * s).round()
	var pb: Vector2 = (b * s).round()
	var vertical: bool = absf(pb.x - pa.x) < absf(pb.y - pa.y)
	var r: Rect2
	if vertical:
		r = Rect2(Vector2(pa.x - floorf(pw * 0.5), minf(pa.y, pb.y)), Vector2(pw, absf(pb.y - pa.y)))
	else:
		r = Rect2(Vector2(minf(pa.x, pb.x), pa.y - floorf(pw * 0.5)), Vector2(absf(pb.x - pa.x), pw))
	ci.draw_rect(Rect2(r.position / s, r.size / s), col)


## Hip crosshair: four 2 px ticks on the edge of the real shot cone (spread_deg projected through the camera FOV),
## so bloom, walking and jumping visibly open it, plus a small spread with movement speed (ui.json "crosshair");
## it eases between sizes and fades out while sprinting / aiming. Lines are snapped to physical pixels (crisp under
## the canvas stretch) with a 1 px dark edge for snow.
class Crosshair extends Control:
	var spread: float = 2.0
	var fov: float = 80.0
	var speed: float = 0.0
	var target_alpha: float = 1.0
	var _gap: float = 12.0
	var _alpha: float = 1.0
	var _cfg: Dictionary = {}

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cfg = MenuKit.cfg().get("crosshair", {})

	func _process(d: float) -> void:
		var half_h: float = get_viewport_rect().size.y * 0.5
		var px: float = half_h * tan(deg_to_rad(clampf(spread, 0.0, 40.0))) / tan(deg_to_rad(clampf(fov, 20.0, 150.0)) * 0.5)
		var move: float = float(_cfg.get("move_spread_px", 5.0)) * clampf(speed / maxf(0.1, float(_cfg.get("move_speed_ref", 5.2))), 0.0, 1.0)
		var want: float = clampf(px + move, float(_cfg.get("gap_min_px", 5.0)), half_h * 0.6)
		_gap = lerpf(_gap, want, 1.0 - exp(-(22.0 if want > _gap else 10.0) * d))
		_alpha = move_toward(_alpha, target_alpha, d * 8.0)
		queue_redraw()

	func _draw() -> void:
		if _alpha <= 0.01:
			return
		var s: float = Hud.canvas_scale(self)
		var c: Color = Color(0.95, 0.92, 0.85, float(_cfg.get("alpha", 0.9)) * _alpha)
		var edge: Color = Color(0, 0, 0, 0.5 * _alpha)
		var len_px: float = float(_cfg.get("len_px", 9.0))
		var w: float = float(_cfg.get("thickness_px", 2.0))
		var gap: float = roundf(_gap)
		for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			var a: Vector2 = d * gap
			var b: Vector2 = d * (gap + len_px)
			var side: Vector2 = Vector2(d.y, d.x).abs()   # the across direction
			# the dark edge: the same tick one physical px wider each side, under the light one
			Hud.crisp_line(self, a - d * (1.0 / s) - side * (1.0 / s), b + d * (1.0 / s) - side * (1.0 / s), w + 2.0 / s, edge, s)
			Hud.crisp_line(self, a, b, w, c, s)


## Hit confirmation, three states that read apart at a glance (sizes in ui.json "hitmarker"):
##   hit      four short white ticks;
##   headshot longer amber ticks with a dot at the centre;
##   kill     a thick red X that pops out (amber-edged when the kill was a headshot).
## Multiple hits in quick succession re-pop it; a kill or headshot is never downgraded by a plain hit in the burst.
class HitMarker extends Control:
	const HIT: Color = Color(1.0, 1.0, 1.0, 0.92)
	const HEAD: Color = Color(1.0, 0.72, 0.2, 0.97)
	const KILL: Color = Color(0.9, 0.12, 0.1, 0.97)
	var _t: float = 0.0
	var _dur: float = 0.2
	var _kill: bool = false
	var _head: bool = false
	var _cfg: Dictionary = {}

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cfg = MenuKit.cfg().get("hitmarker", {})

	func _state(key: String) -> Dictionary:
		return _cfg.get(key, {"gap": 8.0, "len": 8.0, "width": 2.0, "seconds": 0.2})

	func flash(killed: bool, headshot: bool) -> void:
		# a kill or headshot is never downgraded by a plain hit arriving in the same burst
		if _t > 0.0 and (_kill and not killed or _head and not headshot and not killed):
			_t = maxf(_t, 0.12)
			return
		var st: Dictionary = _state("kill" if killed else ("head" if headshot else "hit"))
		_dur = float(st.get("seconds", 0.2))
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
		var s: float = Hud.canvas_scale(self)
		var st: Dictionary = _state("kill" if _kill else ("head" if _head else "hit"))
		var age: float = 1.0 - _t / _dur                     # 0 -> 1
		var fade: float = clampf(_t / (_dur * 0.45), 0.0, 1.0)
		var pop: float = 1.0 + 0.45 * (1.0 - clampf(age / 0.18, 0.0, 1.0))   # starts big, settles fast
		var gap: float = float(st.get("gap", 8.0)) * pop
		var length: float = float(st.get("len", 8.0)) * pop
		var width: float = float(st.get("width", 2.0))
		var c: Color = KILL if _kill else (HEAD if _head else HIT)
		c.a *= fade
		for d: Vector2 in [Vector2(0.7071, 0.7071), Vector2(-0.7071, 0.7071), Vector2(0.7071, -0.7071), Vector2(-0.7071, -0.7071)]:
			var a: Vector2 = d * gap
			var b: Vector2 = d * (gap + length)
			draw_line(a + Vector2(1, 1), b + Vector2(1, 1), Color(0, 0, 0, 0.5 * fade), width + 1.5 / s, true)
			if _kill and _head:
				draw_line(a, b, Color(HEAD.r, HEAD.g, HEAD.b, fade), width + 2.0, true)
			draw_line(a, b, c, width, true)
		if _head and not _kill:
			draw_circle(Vector2.ZERO, maxf(1.5, 2.0 * pop), c)


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
