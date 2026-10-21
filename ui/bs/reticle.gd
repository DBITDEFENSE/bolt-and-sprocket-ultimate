class_name BSReticle
extends Control
## Centre-screen reticle for the B&S guns: crosshair tinted by the current weapon, a hit marker, the Void Ripper's
## charge ring (chargeRing, updateWeapons 5186), the Omni-Blaster heat bar (OVERHEAT flashes), the ammo count and
## an Amplify tag. Reads WeaponManager.hud_state() every frame; drawn with _draw (no textures).

var mgr: WeaponManager
var _hit_t: float = 0.0
var _kill: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if mgr != null:
		mgr.hit_landed.connect(_on_hit)


func _on_hit(_t: Node3D, _h: Combat.Hit, killed: bool) -> void:
	_hit_t = 0.18
	_kill = killed


func _process(delta: float) -> void:
	_hit_t = maxf(0.0, _hit_t - delta)
	visible = mgr != null and mgr.bolt != null and not mgr.bolt.dead and not mgr.wheel_open and not BS.blocked()
	queue_redraw()


func _draw() -> void:
	if mgr == null:
		return
	var s: Dictionary = mgr.hud_state()
	if s.is_empty():
		return
	var c: Vector2 = size * 0.5
	var col: Color = WeaponData.color(mgr.current)
	var font: Font = ThemeDB.fallback_font
	var k: float = size.y / 1080.0
	# crosshair (AimAssist friction tightens it on target)
	var gap: float = 7.0 * k * (0.7 if AimAssist.target != null else 1.0)
	var arm: float = 9.0 * k
	for v: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(c + v * gap, c + v * (gap + arm), Color(0, 0, 0, 0.6), 4.0 * k)
		draw_line(c + v * gap, c + v * (gap + arm), col, 2.0 * k)
	draw_circle(c, 1.6 * k, Color.WHITE)
	if _hit_t > 0.0:
		var hc: Color = Color(1, 0.35, 0.25) if _kill else Color.WHITE
		for v2: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(c + v2.normalized() * 10.0 * k, c + v2.normalized() * 17.0 * k, hc, 2.5 * k)
	# Void Ripper charge ring
	var ch: float = float(s.get("charge", -1.0))
	if ch >= 0.0:
		draw_arc(c, (16.0 + 22.0 * ch) * k, 0.0, TAU, 40, Color(col, 0.35), 2.0 * k)
		draw_arc(c, (16.0 + 22.0 * ch) * k, -PI / 2.0, -PI / 2.0 + TAU * ch, 40, col, 3.0 * k)
	# Omni-Blaster heat bar
	if s.has("heat"):
		var w: float = 90.0 * k
		var r: Rect2 = Rect2(c + Vector2(-w * 0.5, 34.0 * k), Vector2(w, 6.0 * k))
		draw_rect(r, Color(0, 0, 0, 0.55))
		var f: float = clampf(float(s["heat"]) / maxf(1.0, float(s["heat_max"])), 0.0, 1.0)
		var hot: Color = Color(1.0, 0.82, 0.25).lerp(Color(1.0, 0.25, 0.1), f)
		if bool(s.get("overheated", false)) and int(Time.get_ticks_msec() / 120) % 2 == 0:
			hot = Color.WHITE
		draw_rect(Rect2(r.position, Vector2(w * f, r.size.y)), hot)
		var mark: float = 25.0 / maxf(1.0, float(s["heat_max"]))
		draw_line(r.position + Vector2(w * mark, -2.0 * k), r.position + Vector2(w * mark, r.size.y + 2.0 * k), Color(1, 1, 1, 0.7), 1.0)
		if bool(s.get("overheated", false)):
			_text(font, WeaponText.text("bs.weapon.fx.overheat"), c + Vector2(0, 58.0 * k), 15.0 * k, Color(1, 0.4, 0.2))
	# ammo
	var am: int = int(s.get("ammo", -1))
	if am >= 0:
		var low: bool = am <= maxi(1, int(s.get("max", 1)) / 5)
		_text(font, "%d" % am, c + Vector2(30.0 * k, 22.0 * k), 16.0 * k, Color(1, 0.35, 0.3) if low else Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_LEFT)
	if bool(s.get("amplify", false)):
		_text(font, "AMP", c + Vector2(0, -30.0 * k), 14.0 * k, col)
	_draw_m3(s, c, k, col, font)


## M3 guns: scope, interest ticker, spin-up ring, paint pips, acquisition ring, frost bar, deployable counts and
## the alt-fire cooldown arc. Every key is optional in hud_state().
func _draw_m3(s: Dictionary, c: Vector2, k: float, col: Color, font: Font) -> void:
	var sc: float = float(s.get("scope", 0.0))
	if sc > 0.01:
		var r0: float = size.y * 0.42
		draw_arc(c, r0, 0.0, TAU, 64, Color(0, 0, 0, 0.55 * sc), size.y * 0.25)
		draw_arc(c, r0 * 0.7, 0.0, TAU, 64, Color(col, 0.5 * sc), 2.0 * k)
		draw_line(c + Vector2(-r0 * 0.7, 0), c + Vector2(-14 * k, 0), Color(col, 0.6 * sc), 1.0)
		draw_line(c + Vector2(14 * k, 0), c + Vector2(r0 * 0.7, 0), Color(col, 0.6 * sc), 1.0)
	if s.has("read"):
		var w: float = 70.0 * k
		var rr: Rect2 = Rect2(c + Vector2(-w * 0.5, 46.0 * k), Vector2(w, 4.0 * k))
		draw_rect(rr, Color(0, 0, 0, 0.5))
		draw_rect(Rect2(rr.position, Vector2(w * float(s["read"]), rr.size.y)), Color(1, 0.9, 0.5) if bool(s.get("reading", false)) else Color(col, 0.8))
		if bool(s.get("reading", false)):
			_text(font, WeaponText.text("bs.weapon.fx.read"), c + Vector2(0, 66.0 * k), 13.0 * k, Color(1, 0.9, 0.5))
	if s.has("interest"):
		var it: float = float(s["interest"])
		var hot: Color = Color.WHITE.lerp(Color(1.0, 0.25, 0.2), clampf((it - 1.0) / maxf(0.01, float(s.get("interest_max", 2.0)) - 1.0), 0.0, 1.0))
		_text(font, WeaponText.text("bs.weapon.fx.interest") % roundi((it - 1.0) * 100.0), c + Vector2(0, 40.0 * k), 15.0 * k, hot)
		if bool(s.get("grace", false)):
			_text(font, WeaponText.text("bs.weapon.fx.grace"), c + Vector2(0, 58.0 * k), 12.0 * k, Color(1, 0.85, 0.3))
	if s.has("spin"):
		var sp: float = float(s["spin"])
		draw_arc(c, 22.0 * k, -PI / 2.0, -PI / 2.0 + TAU * sp, 40, col if sp >= 1.0 else Color(col, 0.5), 3.0 * k)
		if bool(s.get("door_ready", false)):
			_text(font, WeaponText.text("bs.weapon.fx.doorbuster"), c + Vector2(0, 44.0 * k), 12.0 * k, col)
	if s.has("painted"):
		for i: int in int(s.get("paint_max", 3)):
			var p: Vector2 = c + Vector2((i - 1) * 12.0 * k, 34.0 * k)
			draw_circle(p, 4.0 * k, col if i < int(s["painted"]) else Color(0.2, 0.2, 0.22, 0.8))
		var pp: float = float(s.get("paint_progress", 0.0))
		if pp > 0.0:
			draw_arc(c, 16.0 * k, -PI / 2.0, -PI / 2.0 + TAU * pp, 32, col, 2.0 * k)
	if float(s.get("acquire", 0.0)) > 0.0:
		draw_arc(c, 26.0 * k, -PI / 2.0, -PI / 2.0 + TAU * float(s["acquire"]), 48, col, 4.0 * k)
	if s.has("frost"):
		draw_arc(c, 19.0 * k, PI * 0.15, PI * 0.15 + PI * 0.7 * float(s["frost"]), 24, Color("#cdeeff"), 3.0 * k)
	for key: Array in [["drones", "drones_max"], ["plants", "plants_max"], ["subs", "subs_max"]]:
		if s.has(key[0]):
			_text(font, "%d/%d" % [int(s[key[0]]), int(s[key[1]])], c + Vector2(-30.0 * k, 22.0 * k), 13.0 * k, col, HORIZONTAL_ALIGNMENT_LEFT)
	var acd: float = float(s.get("alt_cd", 0.0))
	if acd > 0.0:
		draw_arc(c, 12.0 * k, -PI / 2.0, -PI / 2.0 + TAU * minf(1.0, acd / 6.0), 20, Color(1, 1, 1, 0.35), 2.0 * k)


func _text(font: Font, t: String, at: Vector2, fs: float, col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var w: float = 400.0
	var x: float = at.x - w * 0.5 if align == HORIZONTAL_ALIGNMENT_CENTER else at.x
	draw_string_outline(font, Vector2(x, at.y), t, align, w, int(fs), 4, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(x, at.y), t, align, w, int(fs), col)
