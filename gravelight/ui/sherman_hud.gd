class_name ShermanHud
extends CanvasLayer
## The Sherman event's own HUD lines (T-249), on every peer: a counter under the boss bars while the dead are on the
## tank ("THE DEAD ON THE SHERMAN: 14"), and the air raid's warning in the middle of the screen (the title, the line
## under it, the countdown, then whether you are under a roof). The tank's health is a boss bar (BossHud, the boss
## kit's bar); the banners are the HUD's own (Hud.show_banner).

const RED: Color = Color(0.95, 0.22, 0.16)
const PAPER: Color = Color(0.93, 0.89, 0.8)
const SAFE: Color = Color(0.6, 0.9, 0.62)

var counter: Label
var title: Label
var small: Label
var count: Label
var status: Label
var drive: Label                       # T-261: the driver's line (the 75 mm loaded or loading), bottom centre
var drive_bar: ProgressBar
var sight: TankSight                   # T-278: the driven tank's reticle, gun marker and gunner's sight
var _box: VBoxContainer
var _pulse: float = 0.0


func _init() -> void:
	layer = 12
	name = "ShermanHud"


func _ready() -> void:
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	MenuKit.apply_theme(root)
	add_child(root)
	counter = MenuKit.label("", 22, PAPER, true)
	counter.anchor_left = 0.5
	counter.anchor_right = 0.5
	counter.offset_left = -300
	counter.offset_right = 300
	counter.offset_top = float(MenuKit.hud("boss_top", 22.0)) + 74.0
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter.hide()
	root.add_child(counter)
	_box = VBoxContainer.new()
	_box.anchor_left = 0.5
	_box.anchor_right = 0.5
	_box.anchor_top = 0.22
	_box.offset_left = -420
	_box.offset_right = 420
	_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_box)
	title = MenuKit.label("", 64, RED, true)
	small = MenuKit.label("", 30, PAPER, true)
	count = MenuKit.label("", 40, PAPER, true)
	status = MenuKit.label("", 26, PAPER, true)
	for l: Label in [title, small, count, status]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		MenuKit.outline(l, "hud")
		_box.add_child(l)
	MenuKit.outline(counter, "hud")
	_box.hide()
	drive = MenuKit.label("", 22, PAPER, true)
	drive.anchor_left = 0.5
	drive.anchor_right = 0.5
	drive.anchor_top = 1.0
	drive.anchor_bottom = 1.0
	drive.offset_left = -220
	drive.offset_right = 220
	drive.offset_top = -168
	drive.offset_bottom = -140
	drive.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	MenuKit.outline(drive, "hud")
	drive.hide()
	root.add_child(drive)
	drive_bar = ProgressBar.new()
	drive_bar.anchor_left = 0.5
	drive_bar.anchor_right = 0.5
	drive_bar.anchor_top = 1.0
	drive_bar.anchor_bottom = 1.0
	drive_bar.offset_left = -110
	drive_bar.offset_right = 110
	drive_bar.offset_top = -138
	drive_bar.offset_bottom = -132
	drive_bar.min_value = 0.0
	drive_bar.max_value = 1.0
	drive_bar.show_percentage = false
	drive_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drive_bar.hide()
	root.add_child(drive_bar)
	sight = TankSight.new()
	sight.set_anchors_preset(Control.PRESET_FULL_RECT)
	sight.hide()
	root.add_child(sight)


func set_counter(text: String) -> void:
	counter.text = text
	counter.visible = text != ""


## The raid's warning: `t_title` big, `t_small` under it, `t_count` (the countdown) and `t_status` (inside or out).
func set_warning(t_title: String, t_small: String, t_count: String, t_status: String, safe: bool) -> void:
	title.text = t_title
	small.text = t_small
	count.text = t_count
	status.text = t_status
	status.add_theme_color_override("font_color", SAFE if safe else RED)
	_box.visible = t_title != "" or t_status != ""


## The driver's line: the gun's state and how far the reload is ("" = not driving).
func set_drive(text: String, loaded: float = 1.0) -> void:
	if drive == null:
		return
	if drive.text != text:
		drive.text = text
	drive.visible = text != ""
	drive.add_theme_color_override("font_color", SAFE if loaded >= 1.0 else PAPER)
	drive_bar.visible = text != "" and loaded < 1.0
	drive_bar.value = loaded


## T-278: the driver's sight on (their orbit camera `c`, the 75 mm's reload done `loaded`, 0..1) or off (null).
func set_sight(c: TankCamera, loaded: float = 1.0) -> void:
	if sight == null:
		return
	sight.cam = c
	sight.loaded = loaded
	sight.visible = c != null


func clear_warning() -> void:
	_box.hide()


func _process(delta: float) -> void:
	if _box.visible and title.text != "":
		_pulse += delta * 3.2
		title.modulate.a = 0.75 + 0.25 * sin(_pulse)


## T-278: the driven Sherman's sight, World of Tanks fashion.
##   reticle  the screen centre, where the camera aims: a ring broken at the top and a dot; round it the 75 mm's
##            reload as an arc (amber while it loads, a full green ring when it is ready); the range under it.
##   marker   where the gun is laid now (TankCamera.gun_point, the barrel's line, where the shell goes): a diamond
##            with side ticks; it closes on the reticle as the turret comes round and turns green within 1 degree.
##   sight    in the gunner's sight a dark round mask, a stadia cross and the zoom.
##   hull     bottom centre, the hull and the turret from above against the view's heading (screen up).
class TankSight extends Control:
	const INK: Color = Color(0.02, 0.02, 0.02, 0.6)
	const LIGHT: Color = Color(0.95, 0.92, 0.85, 0.95)
	const AMBER: Color = Color(1.0, 0.72, 0.25, 0.97)
	const GREEN: Color = Color(0.55, 0.95, 0.5, 0.97)
	var cam: TankCamera = null
	var loaded: float = 1.0
	var marker: Vector2 = Vector2.INF      # the gun marker on screen (Vector2.INF: not on screen)
	var on_aim: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		if not visible:
			return
		marker = Vector2.INF
		on_aim = false
		if cam != null and is_instance_valid(cam) and cam.tank != null and is_instance_valid(cam.tank):
			marker = cam.marker_screen()
			on_aim = cam.gun_on_aim(1.0)
		queue_redraw()

	func _draw() -> void:
		if cam == null or not is_instance_valid(cam) or cam.tank == null or not is_instance_valid(cam.tank):
			return
		var sz: Vector2 = size
		var c: Vector2 = sz * 0.5
		var u: float = maxf(1.0, sz.y / 1080.0)   # the drawing's unit: 1 at 1080 lines
		if cam.sniper:
			_draw_scope(c, sz, u)
		# the reticle
		var r: float = 15.0 * u
		draw_arc(c, r, -PI * 0.5 + 0.35, PI * 1.5 - 0.35, 40, INK, 4.0 * u, true)
		draw_arc(c, r, -PI * 0.5 + 0.35, PI * 1.5 - 0.35, 40, LIGHT, 1.6 * u, true)
		draw_circle(c, 2.6 * u, INK)
		draw_circle(c, 1.5 * u, LIGHT)
		# the reload round it
		var rr: float = r + 9.0 * u
		draw_arc(c, rr, 0.0, TAU, 56, INK, 7.0 * u, true)
		if loaded >= 1.0:
			draw_arc(c, rr, 0.0, TAU, 56, GREEN, 3.6 * u, true)
		else:
			draw_arc(c, rr, 0.0, TAU, 56, Color(LIGHT, 0.22), 3.6 * u, true)   # what is still to load, faint
			if loaded > 0.001:
				draw_arc(c, rr, -PI * 0.5, -PI * 0.5 + TAU * loaded, 56, AMBER, 3.6 * u, true)
		# the range to the aim point, from the gun
		var f: Font = get_theme_default_font()
		if f != null:
			var txt: String = "%d m" % int(round(cam.tank.gun.global_position.distance_to(cam.aim_point)))
			var fs: int = int(15.0 * u)
			var tw: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var at: Vector2 = c + Vector2(-tw * 0.5, rr + 24.0 * u)
			draw_string_outline(f, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(4.0 * u), INK)
			draw_string(f, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, LIGHT)
		# the gun marker
		if marker.is_finite():
			var col: Color = GREEN if on_aim else AMBER
			var mk: Vector2 = marker.clamp(Vector2(12, 12) * u, sz - Vector2(12, 12) * u)
			var h: float = 7.0 * u
			var pts: PackedVector2Array = PackedVector2Array([mk + Vector2(0, -h), mk + Vector2(h, 0), mk + Vector2(0, h), mk + Vector2(-h, 0), mk + Vector2(0, -h)])
			draw_polyline(pts, INK, 4.0 * u, true)
			draw_polyline(pts, col, 1.8 * u, true)
			for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT]:
				draw_line(mk + d * (h + 3.0 * u), mk + d * (h + 11.0 * u), INK, 4.0 * u)
				draw_line(mk + d * (h + 3.0 * u), mk + d * (h + 11.0 * u), col, 1.8 * u)
		_draw_hull(sz, u)

	func _draw_scope(c: Vector2, sz: Vector2, u: float) -> void:
		var rad: float = sz.y * 0.46
		# the mask: a ring thick enough to cover the corners round a clear disc
		var outer: float = sz.length() * 0.6
		var w: float = outer - rad
		draw_arc(c, rad + w * 0.5, 0.0, TAU, 96, Color(0.0, 0.0, 0.0, 0.9), w, true)
		draw_arc(c, rad, 0.0, TAU, 96, Color(0.0, 0.0, 0.0, 0.95), 6.0 * u, true)
		# the stadia: a cross clear of the centre, range ticks under it, mil ticks on the arms
		var dark: Color = Color(0.04, 0.04, 0.03, 0.9)
		for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN]:
			draw_line(c + d * 40.0 * u, c + d * rad * 0.94, dark, 2.0 * u)
		for k: int in range(1, 6):
			var y: float = c.y + float(k) * 24.0 * u + 16.0 * u
			var half: float = (10.0 if k % 2 == 1 else 6.0) * u
			draw_line(Vector2(c.x - half, y), Vector2(c.x + half, y), dark, 1.6 * u)
		for k2: int in range(1, 5):
			for sgn: float in [-1.0, 1.0]:
				var x: float = c.x + sgn * (float(k2) * 36.0 * u + 30.0 * u)
				draw_line(Vector2(x, c.y - 6.0 * u), Vector2(x, c.y + 6.0 * u), dark, 1.6 * u)
		var f: Font = get_theme_default_font()
		if f != null:
			draw_string(f, c + Vector2(rad * 0.6, rad * 0.62), "x%.0f" % float(cam.cfg.get("sniper_zoom", 4.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, int(18.0 * u), LIGHT)

	func _draw_hull(sz: Vector2, u: float) -> void:
		if cam.player == null or not is_instance_valid(cam.player):
			return
		var o: Vector2 = Vector2(sz.x * 0.5 - 300.0 * u, sz.y - 84.0 * u)
		var hull: float = cam.player.look_angles().y - cam.tank.rotation.y   # the hull against the view: screen up = the view's heading
		var xf: Transform2D = Transform2D(hull, o)
		var hw: float = 9.0 * u
		var hl: float = 16.0 * u
		var wbox: PackedVector2Array = PackedVector2Array()
		for v: Vector2 in [Vector2(-hw, -hl), Vector2(hw, -hl), Vector2(hw, hl), Vector2(-hw, hl), Vector2(-hw, -hl)]:
			wbox.append(xf * v)
		draw_polyline(wbox, INK, 4.0 * u, true)
		draw_polyline(wbox, LIGHT, 1.6 * u, true)
		draw_line(xf * Vector2(-hw * 0.6, -hl + 4.0 * u), xf * Vector2(hw * 0.6, -hl + 4.0 * u), LIGHT, 1.6 * u)   # the bow
		var tdir: Vector2 = Vector2(0, -1).rotated(hull - cam.tank.turret.rotation.y)
		var tc: Vector2 = xf * Vector2(0, -2.0 * u)
		draw_circle(tc, 5.5 * u, INK)
		draw_line(tc, tc + tdir * 24.0 * u, INK, 4.5 * u)
		draw_line(tc, tc + tdir * 24.0 * u, GREEN if loaded >= 1.0 else AMBER, 2.0 * u)
		draw_circle(tc, 3.5 * u, LIGHT)
