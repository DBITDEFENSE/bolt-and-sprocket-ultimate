class_name MapIcons
extends RefCounted
## The map's icon set (Update 04 section 2, DECISIONS T-065), drawn with canvas primitives so they stay crisp at any
## size. Every kind has its own silhouette (never colour alone): doors are bars, perks bottles, wall-buys chalk
## diamonds, ammo boxes crates, the Crucible an anvil, traps warning triangles, the power a lightning bolt,
## objectives stars, power-ups four-point sparks, the boss a skull, zombies small blips, teammates discs with their
## initial, bots rounded squares, Jakub a shield, the downed a red cross with their bleed-out ring, marks pins.
## With the colourblind-safe setting a letter is added to the buyable shapes as well.

const LETTERS: Dictionary = {
	"perk": "P", "wall_buy": "W", "ammo_box": "A", "crate_spot": "?", "crucible": "C", "workbench": "B", "trap": "T",
	"power_switch": "E", "lift": "L", "objective": "!", "powerup": "+", "vendor": "$", "save": "S", "checkpoint": "R",
	"exit": "X", "npc": "!", "ship": "H",
}
const MARK_LETTERS: Dictionary = {"go": "G", "defend": "D", "danger": "!", "regroup": "R", "note": "N", "buy": "$", "collect": "C"}


static func font() -> Font:
	return ThemeDB.fallback_font


## Draws one icon of `kind` centred at `p`, `s` px across. opts: open, locked, dim (bool), initial (String),
## bleed (0..1), cb (colourblind letters), outline (Color), t (seconds, for pulses), up / down (an off-floor chevron).
static func draw(ci: CanvasItem, kind: String, p: Vector2, s: float, col: Color, opts: Dictionary = {}) -> void:
	var r: float = s * 0.5
	var ol: Color = opts.get("outline", Color(0, 0, 0, 0.75 * col.a))
	var t: float = float(opts.get("t", 0.0))
	match kind:
		"door", "gate":
			var sz: Vector2 = Vector2(s * 1.1, s * 0.42)
			var rr: Rect2 = Rect2(p - sz * 0.5, sz)
			if bool(opts.get("open", false)):
				ci.draw_rect(rr, col, false, maxf(1.5, s * 0.12))
			else:
				ci.draw_rect(rr.grow(1.0), ol)
				ci.draw_rect(rr, col)
				if bool(opts.get("locked", false)):
					ci.draw_line(rr.position, rr.end, Color(1, 1, 1, col.a * 0.9), maxf(1.2, s * 0.08))
					ci.draw_line(Vector2(rr.position.x, rr.end.y), Vector2(rr.end.x, rr.position.y), Color(1, 1, 1, col.a * 0.9), maxf(1.2, s * 0.08))
		"perk":
			ci.draw_circle(p + Vector2(0, r * 0.25), r * 0.72 + 1.0, ol)
			ci.draw_circle(p + Vector2(0, r * 0.25), r * 0.72, col)
			ci.draw_rect(Rect2(p + Vector2(-r * 0.22, -r * 0.95), Vector2(r * 0.44, r * 0.7)), col)
		"wall_buy":
			var d: PackedVector2Array = PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0), p + Vector2(0, -r)])
			ci.draw_polyline(d, ol, maxf(3.0, s * 0.24))
			ci.draw_polyline(d, col, maxf(1.6, s * 0.14))
		"ammo_box":
			var rb: Rect2 = Rect2(p - Vector2(r, r * 0.7), Vector2(s, r * 1.4))
			ci.draw_rect(rb.grow(1.0), ol)
			ci.draw_rect(rb, col)
			for i: int in 3:
				var x: float = p.x - r * 0.5 + i * r * 0.5
				ci.draw_line(Vector2(x, p.y - r * 0.45), Vector2(x, p.y + r * 0.45), Color(0, 0, 0, 0.55 * col.a), maxf(1.0, s * 0.08))
		"crate_spot":
			var rc: Rect2 = Rect2(p - Vector2(r, r), Vector2(s, s))
			ci.draw_rect(rc.grow(1.0), ol)
			ci.draw_rect(rc, col)
			_letter(ci, "?", p, s * 0.9, Color(1, 1, 1, col.a))
		"crucible":
			var a: PackedVector2Array = PackedVector2Array([p + Vector2(-r, -r * 0.6), p + Vector2(r, -r * 0.6), p + Vector2(r * 0.3, r * 0.2),
				p + Vector2(r * 0.55, r * 0.8), p + Vector2(-r * 0.55, r * 0.8), p + Vector2(-r * 0.3, r * 0.2)])
			ci.draw_colored_polygon(_grow(a, p, 1.15), ol)
			ci.draw_colored_polygon(a, col)
		"workbench":
			var hx: PackedVector2Array = []
			for i: int in 6:
				hx.append(p + Vector2.from_angle(TAU * i / 6.0) * r)
			ci.draw_colored_polygon(_grow(hx, p, 1.15), ol)
			ci.draw_colored_polygon(hx, col)
		"trap":
			var tr: PackedVector2Array = PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, r * 0.8), p + Vector2(-r, r * 0.8)])
			ci.draw_colored_polygon(_grow(tr, p, 1.18), ol)
			ci.draw_colored_polygon(tr, col)
			_letter(ci, "!", p + Vector2(0, r * 0.2), s * 0.7, Color(0, 0, 0, col.a))
		"power_switch":
			var bolt: PackedVector2Array = PackedVector2Array([p + Vector2(r * 0.2, -r), p + Vector2(-r * 0.6, r * 0.15), p + Vector2(-r * 0.05, r * 0.15),
				p + Vector2(-r * 0.25, r), p + Vector2(r * 0.6, -r * 0.2), p + Vector2(r * 0.05, -r * 0.2)])
			ci.draw_colored_polygon(_grow(bolt, p, 1.2), ol)
			ci.draw_colored_polygon(bolt, col)
		"lift":
			var rl: Rect2 = Rect2(p - Vector2(r, r), Vector2(s, s))
			ci.draw_rect(rl, col, false, maxf(1.5, s * 0.1))
			chevron(ci, p + Vector2(0, -r * 0.3), s * 0.55, true, col)
			chevron(ci, p + Vector2(0, r * 0.35), s * 0.55, false, col)
		"objective":
			ci.draw_colored_polygon(_grow(_star(p, r, r * 0.45, 5), p, 1.15), ol)
			ci.draw_colored_polygon(_star(p, r, r * 0.45, 5), col)
		"powerup":
			ci.draw_colored_polygon(_grow(_star(p, r, r * 0.3, 4), p, 1.2), ol)
			ci.draw_colored_polygon(_star(p, r, r * 0.3, 4), col)
		"boss":
			ci.draw_circle(p, r + 1.5, ol)
			ci.draw_circle(p + Vector2(0, -r * 0.1), r * 0.85, col)
			ci.draw_rect(Rect2(p + Vector2(-r * 0.45, r * 0.45), Vector2(r * 0.9, r * 0.45)), col)
			ci.draw_circle(p + Vector2(-r * 0.32, -r * 0.1), r * 0.22, Color(0, 0, 0, col.a))
			ci.draw_circle(p + Vector2(r * 0.32, -r * 0.1), r * 0.22, Color(0, 0, 0, col.a))
		"zombie":
			var pulse: float = 0.5 + 0.5 * sin(t * 12.0)
			ci.draw_circle(p, r * (0.9 + 0.5 * pulse), Color(col.r, col.g, col.b, 0.25 * col.a))
			ci.draw_circle(p, r * 0.55, col)
		"ally", "bot", "jakub":
			_person(ci, kind, p, s, col, ol, str(opts.get("initial", "")))
		"downed":
			var pul: float = 0.75 + 0.25 * sin(t * 8.0)
			var red: Color = Color(0.86, 0.12, 0.1, col.a)
			var bleed: float = clampf(float(opts.get("bleed", 1.0)), 0.0, 1.0)
			ci.draw_arc(p, r * 1.15, -PI * 0.5, -PI * 0.5 + TAU, 32, Color(0, 0, 0, 0.5 * col.a), maxf(2.0, s * 0.16))
			ci.draw_arc(p, r * 1.15, -PI * 0.5, -PI * 0.5 + TAU * bleed, 32, red, maxf(2.0, s * 0.14))
			var w: float = r * 0.32 * pul
			ci.draw_rect(Rect2(p - Vector2(w, r * 0.8 * pul), Vector2(w * 2.0, r * 1.6 * pul)), red)
			ci.draw_rect(Rect2(p - Vector2(r * 0.8 * pul, w), Vector2(r * 1.6 * pul, w * 2.0)), red)
		"marker":
			var head: Vector2 = p + Vector2(0, -r * 0.6)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, r * 0.7), head + Vector2(-r * 0.62, r * 0.2), head + Vector2(r * 0.62, r * 0.2)]), col)
			ci.draw_circle(head, r * 0.7 + 1.0, ol)
			ci.draw_circle(head, r * 0.7, col)
			_letter(ci, str(MARK_LETTERS.get(str(opts.get("mark", "")), "")), head, s * 0.62, Color(1, 1, 1, col.a))
		"vendor", "npc", "save", "checkpoint", "exit", "ship":
			match kind:
				"checkpoint":
					var dd: PackedVector2Array = PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)])
					ci.draw_colored_polygon(dd, col)
				"exit":
					ci.draw_arc(p, r, 0, TAU, 24, col, maxf(2.0, s * 0.18))
					ci.draw_circle(p, r * 0.35, col)
				"save":
					ci.draw_rect(Rect2(p - Vector2(r, r), Vector2(s, s)), col)
					ci.draw_rect(Rect2(p + Vector2(-r * 0.5, -r), Vector2(r, r * 0.6)), Color(0, 0, 0, 0.5 * col.a))
				"ship":
					ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r * 0.8, r), p + Vector2(-r * 0.8, r)]), col)
				_:
					ci.draw_circle(p, r + 1.0, ol)
					ci.draw_circle(p, r, col)
					_letter(ci, str(LETTERS.get(kind, "")), p, s * 0.8, Color(0, 0, 0, col.a))
		_:
			ci.draw_circle(p, r * 0.6, col)
	if bool(opts.get("cb", false)) and LETTERS.has(kind) and not kind in ["crate_spot", "trap", "vendor", "npc", "objective"]:
		_letter(ci, str(LETTERS[kind]), p + Vector2(r * 1.05, -r * 0.85), s * 0.62, Color(1, 1, 1, col.a), true)
	if bool(opts.get("up", false)) or bool(opts.get("down", false)):
		chevron(ci, p + Vector2(r * 0.9, r * 0.75), s * 0.5, bool(opts.get("up", false)), Color(col.r, col.g, col.b, maxf(0.6, col.a)))


## The player's own arrow, pointing along `dir` (canvas space).
static func draw_player(ci: CanvasItem, p: Vector2, dir: Vector2, s: float, col: Color) -> void:
	var f: Vector2 = dir.normalized() if dir.length() > 0.001 else Vector2.UP
	var side: Vector2 = Vector2(-f.y, f.x)
	var tip: Vector2 = p + f * s * 0.62
	var a: PackedVector2Array = PackedVector2Array([tip, p - f * s * 0.42 + side * s * 0.42, p - f * s * 0.18, p - f * s * 0.42 - side * s * 0.42])
	ci.draw_colored_polygon(_grow(a, p, 1.22), Color(0, 0, 0, 0.8))
	ci.draw_colored_polygon(a, col)


## A filled chevron (stairs / ladder / lift arrows; up or down).
static func chevron(ci: CanvasItem, p: Vector2, s: float, up: bool, col: Color) -> void:
	var k: float = -1.0 if up else 1.0
	var h: float = s * 0.5
	var pts: PackedVector2Array = PackedVector2Array([p + Vector2(0, k * h * 0.8), p + Vector2(h, -k * h * 0.4), p + Vector2(h * 0.45, -k * h * 0.4),
		p + Vector2(0, k * h * 0.1), p + Vector2(-h * 0.45, -k * h * 0.4), p + Vector2(-h, -k * h * 0.4)])
	ci.draw_colored_polygon(_grow(pts, p, 1.25), Color(0, 0, 0, 0.55 * col.a))
	ci.draw_colored_polygon(pts, col)


static func _person(ci: CanvasItem, kind: String, p: Vector2, s: float, col: Color, ol: Color, initial: String) -> void:
	var r: float = s * 0.5
	match kind:
		"bot":
			var rr: Rect2 = Rect2(p - Vector2(r, r), Vector2(s, s))
			ci.draw_rect(rr.grow(1.5), ol)
			ci.draw_rect(rr, col)
		"jakub":
			var sh: PackedVector2Array = PackedVector2Array([p + Vector2(-r, -r), p + Vector2(r, -r), p + Vector2(r, r * 0.2), p + Vector2(0, r * 1.1), p + Vector2(-r, r * 0.2)])
			ci.draw_colored_polygon(_grow(sh, p, 1.18), ol)
			ci.draw_colored_polygon(sh, col)
		_:
			ci.draw_circle(p, r + 1.5, ol)
			ci.draw_circle(p, r, col)
	var lum: float = col.r * 0.3 + col.g * 0.59 + col.b * 0.11
	_letter(ci, initial, p, s * 0.82, Color(0, 0, 0, col.a) if lum > 0.55 else Color(1, 1, 1, col.a))


static func _letter(ci: CanvasItem, text: String, p: Vector2, s: float, col: Color, outline: bool = false) -> void:
	if text == "":
		return
	var f: Font = font()
	var fs: int = maxi(8, int(s))
	var w: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at: Vector2 = p + Vector2(-w * 0.5, f.get_ascent(fs) * 0.5 - f.get_descent(fs) * 0.35)
	if outline:
		ci.draw_string_outline(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, col.a))
	ci.draw_string(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


static func _star(c: Vector2, r_out: float, r_in: float, n: int) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	for i: int in n * 2:
		var a: float = -PI * 0.5 + PI * i / n
		pts.append(c + Vector2.from_angle(a) * (r_out if i % 2 == 0 else r_in))
	return pts


static func _grow(pts: PackedVector2Array, c: Vector2, k: float) -> PackedVector2Array:
	var out: PackedVector2Array = []
	for q: Vector2 in pts:
		out.append(c + (q - c) * k)
	return out
