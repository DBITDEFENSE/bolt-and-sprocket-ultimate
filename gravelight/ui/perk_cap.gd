class_name PerkCap
extends Control
## A small perk bottle cap (the perk HUD's crimped cap, drawn at any size) for the bot nameplates and the squad
## ledger (U02 section 5). `bonus` adds the bot's bonus-perk mark: a gold ring and a star at the rim.

var perk_id: StringName = &""
var bonus: bool = false
var font: Font = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_cap(self, size * 0.5, size.x * 0.5, perk_id, bonus, font, 1.0)


## Draws one cap centred at `c` with radius `r` onto `ci`. `alpha` fades it (occluded / far nameplates).
static func draw_cap(ci: CanvasItem, c: Vector2, r: float, perk: StringName, is_bonus: bool, f: Font, alpha: float) -> void:
	if r < 3.0 or perk == &"" or alpha <= 0.0:
		return
	var d: Dictionary = (GLData.table("perks")["perks"] as Dictionary).get(String(perk), {})
	var col: Color = Color(str(d.get("color", "#c0a040")))
	col.a = alpha
	if is_bonus:
		ci.draw_circle(c, r + 2.5, Color(1.0, 0.82, 0.3, 0.95 * alpha))
	var teeth: PackedVector2Array = []
	var n: int = 24
	for i: int in n:
		var a: float = TAU * float(i) / float(n)
		var rr: float = r if i % 2 == 0 else r - maxf(1.0, r * 0.12)
		teeth.append(c + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(teeth, Color(col.darkened(0.35), alpha))
	ci.draw_circle(c, r * 0.82, col)
	if r >= 9.0:
		ci.draw_arc(c, r * 0.62, 0.0, TAU, 20, Color(col.lightened(0.35), alpha), 1.0)
	if f != null:
		var abbr: String = str(d.get("abbr", "?"))
		var fs: int = maxi(7, int(r * 0.85))
		var w: float = f.get_string_size(abbr, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var ink: Color = Color(0.08, 0.06, 0.05, alpha) if col.get_luminance() > 0.45 else Color(0.95, 0.92, 0.85, alpha)
		ci.draw_string(f, c + Vector2(-w * 0.5, fs * 0.36), abbr, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	if is_bonus:
		_star(ci, c + Vector2(r * 0.78, -r * 0.78), maxf(3.0, r * 0.42), Color(1.0, 0.9, 0.45, alpha))


## A five-point star from convex pieces (an inner pentagon and five tip triangles: a concave outline can fail to
## triangulate at small sizes).
static func _star(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var outer: PackedVector2Array = []
	var inner: PackedVector2Array = []
	for i: int in 5:
		var a: float = -PI * 0.5 + TAU * float(i) / 5.0
		outer.append(c + Vector2(cos(a), sin(a)) * r)
		var a2: float = a + TAU / 10.0
		inner.append(c + Vector2(cos(a2), sin(a2)) * r * 0.45)
	var edge: Color = Color(0.15, 0.1, 0.02, col.a)
	ci.draw_colored_polygon(inner, col)
	for k: int in 5:
		var tri: PackedVector2Array = [outer[k], inner[k], inner[(k + 4) % 5]]
		ci.draw_colored_polygon(tri, col)
		ci.draw_polyline(PackedVector2Array([inner[(k + 4) % 5], outer[k], inner[k]]), edge, 1.0)
