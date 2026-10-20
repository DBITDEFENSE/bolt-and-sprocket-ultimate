class_name BSWeaponWheel
extends Control
## The radial weapon wheel (openWheel / buildWheelDOM / updateWheel, index.html:17779-17836), drawn from
## WeaponManager's wheel model: pages of 8 (slot 0 at the top, clockwise), unowned slots as dark silhouettes with an
## unlock hint, the hub showing the highlighted gun's name, V-level pips, mod pips, Ω and ammo, the page and the
## quick-swap "last" weapon. While it's open the manager sets Game.wheel_open (world ×0.15) and BS.ui_block.
## Mouse picks by direction, pad by the right stick; mouse wheel / Q / E / LB-RB flip pages.

var mgr: WeaponManager


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if mgr != null:
		mgr.wheel_changed.connect(queue_redraw)


func _process(_delta: float) -> void:
	var open: bool = mgr != null and mgr.wheel_open
	if open != visible:
		visible = open
	if open:
		queue_redraw()


func _draw() -> void:
	if mgr == null or not mgr.wheel_open:
		return
	var font: Font = ThemeDB.fallback_font
	var k: float = size.y / 1080.0
	var c: Vector2 = size * 0.5
	var R: float = 230.0 * k
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.06, 0.45))
	draw_circle(c, R + 90.0 * k, Color(0.08, 0.1, 0.16, 0.75))
	var ids: Array[StringName] = mgr.page_ids(mgr.wheel_page)
	var n: int = ids.size()
	for i: int in n:
		var id: StringName = ids[i]
		var ang: float = float(i) / n * TAU - PI / 2.0
		var at: Vector2 = c + Vector2(cos(ang), sin(ang)) * R
		var owned: bool = id != &"" and mgr.owns(id)
		var sel: bool = i == mgr.wheel_sel
		var col: Color = WeaponData.color(id) if id != &"" else Color(0.3, 0.3, 0.3)
		var rad: float = (66.0 if sel else 56.0) * k
		draw_circle(at, rad, Color(col, 0.35) if owned and sel else Color(0.05, 0.06, 0.09, 0.9))
		draw_arc(at, rad, 0, TAU, 32, col if owned else Color(0.25, 0.25, 0.28), (4.0 if sel else 2.0) * k)
		if id == &"":
			continue
		var w: BSWeapon = mgr.weapon(id)
		if not owned:
			_text(font, str(WeaponData.def(id).get("icon", "?")), at + Vector2(0, -6 * k), 30.0 * k, Color(0.12, 0.12, 0.14))
			_text(font, WeaponText.text(WeaponData.unlock_hint_id(id)), at + Vector2(0, 26 * k), 11.0 * k, Color(0.55, 0.55, 0.6), 150.0 * k)
			continue
		var locked: bool = mgr.locked.has(id)
		_text(font, str(WeaponData.def(id).get("icon", "")), at + Vector2(0, -8 * k), 30.0 * k, Color.WHITE if not locked else Color(0.4, 0.4, 0.4))
		_text(font, WeaponData.display_name(id, w.omega()), at + Vector2(0, 22 * k), 12.0 * k, Color(1.0, 0.85, 0.3) if w.omega() else Color.WHITE, 150.0 * k)
		var am: int = w.ammo()
		_text(font, "∞" if am < 0 else str(am), at + Vector2(0, 40 * k), 12.0 * k, Color(0.8, 0.85, 0.9))
		if id == mgr.current:
			draw_arc(at, rad + 6.0 * k, 0, TAU, 32, Color(1, 1, 1, 0.6), 1.5 * k)
	# hub
	draw_circle(c, 92.0 * k, Color(0.04, 0.05, 0.08, 0.95))
	var hid: StringName = ids[mgr.wheel_sel] if mgr.wheel_sel >= 0 and mgr.wheel_sel < n else &""
	if hid != &"" and mgr.owns(hid):
		var hw: BSWeapon = mgr.weapon(hid)
		_text(font, WeaponData.display_name(hid, hw.omega()), c + Vector2(0, -34 * k), 16.0 * k, WeaponData.color(hid), 170.0 * k)
		_pips(c + Vector2(0, -10 * k), 5, hw.level(), Color(0.4, 0.9, 1.0), k)
		var mods: int = 0
		for slot: String in WeaponData.MOD_SLOTS:
			mods += hw.mod_tier(slot)
		_pips(c + Vector2(0, 6 * k), 9, mods, Color(1.0, 0.75, 0.25), k * 0.7)
		var am2: int = hw.ammo()
		_text(font, ("∞" if am2 < 0 else "%d / %d" % [am2, hw.max_ammo()]), c + Vector2(0, 30 * k), 13.0 * k, Color.WHITE)
		if hw.omega():
			_text(font, "Ω", c + Vector2(0, 52 * k), 18.0 * k, Color(1.0, 0.82, 0.25))
	elif hid != &"":
		_text(font, WeaponText.text("bs.weapon.wheel.locked"), c + Vector2(0, -10 * k), 14.0 * k, Color(0.6, 0.6, 0.65))
	else:
		_text(font, WeaponText.text("bs.weapon.wheel.hub"), c + Vector2(0, 0), 15.0 * k, Color.WHITE, 150.0 * k)
	if mgr.pages() > 1:
		_text(font, WeaponText.text("bs.weapon.wheel.page") % [mgr.wheel_page + 1, mgr.pages()], c + Vector2(0, R + 112.0 * k), 13.0 * k, Color(0.8, 0.8, 0.85))
	if mgr.last != &"" and mgr.owns(mgr.last):
		_text(font, "%s: %s" % [WeaponText.text("bs.weapon.wheel.last"), WeaponData.display_name(mgr.last)], c + Vector2(0, -R - 104.0 * k), 13.0 * k, Color(0.75, 0.8, 0.85), 400.0 * k)


func _pips(at: Vector2, total: int, filled: int, col: Color, k: float) -> void:
	var step: float = 14.0 * k
	var x0: float = at.x - step * (total - 1) * 0.5
	for i: int in total:
		var p: Vector2 = Vector2(x0 + step * i, at.y)
		draw_circle(p, 4.0 * k, col if i < filled else Color(0.25, 0.27, 0.3))


func _text(font: Font, t: String, at: Vector2, fs: float, col: Color, w: float = 200.0) -> void:
	draw_string_outline(font, Vector2(at.x - w * 0.5, at.y), t, HORIZONTAL_ALIGNMENT_CENTER, w, int(fs), 3, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(at.x - w * 0.5, at.y), t, HORIZONTAL_ALIGNMENT_CENTER, w, int(fs), col)
