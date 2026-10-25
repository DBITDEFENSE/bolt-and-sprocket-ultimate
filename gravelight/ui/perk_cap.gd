class_name PerkCap
extends Control
## A perk tonic's bottle cap, drawn at any size: the single source for every cap in the game (T-082). The HUD perk
## row, the bot nameplates, the co-op squad ledger and the pause menu's LOADOUT list all call `draw_cap`.
##
## A cap is a crimped cap in the tonic's colour with a bevelled face, and on it the tonic's glyph (one drawn symbol
## per tonic, embossed: a shadow pass under cream or ink), the tier band (a brass strip with II / III under the glyph;
## the crimp turns gold at III) and, for a bot's bonus perk, a gold ring and a star at the rim. `dim` draws a tonic
## the player does not hold: desaturated, faded, grey glyph (the pause list).
##
## Glyphs (perks.json order): Ironhide a riveted shield with a barrel hoop; Second Wind a heart with a pulse; Trigger
## Tonic a fan of three cartridges; Twin Barrel two bores end-on; Marathon a boot with speed lines; Hawkeye an eye in
## a crosshair; Packmule a satchel; Blastproof a cracked bomb in a ring; Overclock a cog with a lightning bolt (the
## cordial's violet neon). A tonic without a glyph case (a future cabinet) falls back to its "abbr" letters.

var perk_id: StringName = &""
var bonus: bool = false
var tier: int = 1
var dim: bool = false
var font: Font = null

const CREAM: Color = Color(0.95, 0.92, 0.85)
const INK: Color = Color(0.08, 0.06, 0.05)
const GREY_INK: Color = Color(0.72, 0.72, 0.7)
const GLYPHS: PackedStringArray = ["ironhide_stout", "second_wind", "trigger_tonic", "twin_barrel", "marathon_malt",
	"hawkeye_brandy", "packmule_porter", "blastproof_bock", "overclock_cordial"]

static var _fallback_font: SystemFont = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_cap(self, size * 0.5, minf(size.x, size.y) * 0.5, perk_id, bonus, font, 1.0, tier, dim)


## Whether `perk` has a drawn glyph (else the cap shows its abbreviation letters).
static func has_glyph(perk: StringName) -> bool:
	return GLYPHS.has(String(perk))


static func _font_or_default(f: Font) -> Font:
	if f != null:
		return f
	if _fallback_font == null:
		_fallback_font = SystemFont.new()
		_fallback_font.font_names = PackedStringArray(["Stencil", "Impact", "Arial Black"])
	return _fallback_font


## Draws one cap centred at `c` with radius `r` onto `ci`. `alpha` fades it (occluded / far nameplates), `tier`
## adds the brass band (2 / 3), `dim` greys an unowned tonic. `f` may be null (a stencil system font is used).
static func draw_cap(ci: CanvasItem, c: Vector2, r: float, perk: StringName, is_bonus: bool, f: Font, alpha: float,
		tier: int = 1, dim: bool = false) -> void:
	if r < 3.0 or perk == &"" or alpha <= 0.0:
		return
	var d: Dictionary = (GLData.table("perks")["perks"] as Dictionary).get(String(perk), {})
	var col: Color = Color(str(d.get("color", "#c0a040")))
	if dim:
		col = Color.from_hsv(col.h, col.s * 0.18, col.v * 0.5)
		alpha *= 0.8
	col.a = alpha
	var light_face: bool = col.get_luminance() > 0.45
	var ink: Color = GREY_INK if dim else (INK if light_face else CREAM)
	ink.a = alpha
	if is_bonus:
		ci.draw_circle(c, r + 2.5, Color(1.0, 0.82, 0.3, 0.95 * alpha))
	# the crimped edge (gold at tier III)
	var teeth: PackedVector2Array = []
	var n: int = 24 if r < 20.0 else 42
	var depth: float = maxf(1.0, r * 0.11)
	for i: int in n:
		var a: float = TAU * float(i) / float(n)
		var rr: float = r if i % 2 == 0 else r - depth
		teeth.append(c + Vector2(cos(a), sin(a)) * rr)
	var crimp: Color = Color(0.86, 0.68, 0.26, alpha) if tier >= 3 and not dim else Color(col.darkened(0.35), alpha)
	ci.draw_colored_polygon(teeth, crimp)
	# the face, with a bevel: light on the upper left, shade on the lower right
	var fr: float = r * 0.82
	ci.draw_circle(c, fr, col)
	if r >= 7.0:
		var bw: float = maxf(1.0, r * 0.09)
		ci.draw_arc(c, fr - bw * 0.5, PI * 1.02, PI * 1.62, 14, Color(col.lightened(0.45), 0.9 * alpha), bw)
		ci.draw_arc(c, fr - bw * 0.5, PI * 0.02, PI * 0.62, 14, Color(col.darkened(0.4), 0.8 * alpha), bw)
	if r >= 9.0:
		ci.draw_arc(c, r * 0.64, 0.0, TAU, 24, Color(col.lightened(0.3), 0.8 * alpha), 1.0)
	# the glyph, raised a little when the band shows under it
	var band: bool = tier >= 2 and r >= 11.0
	var gc: Vector2 = c + Vector2(0.0, -r * 0.09 if band else 0.0)
	var g: float = r * (0.42 if band else 0.48)
	if has_glyph(perk):
		var emboss: Color = Color(col.lightened(0.55), 0.7 * alpha) if light_face else Color(col.darkened(0.6), 0.75 * alpha)
		if dim:
			emboss = Color(0.0, 0.0, 0.0, 0.35 * alpha)
		var off: Vector2 = Vector2(-1.0, -1.0) * maxf(0.7, r * 0.05) if light_face and not dim else Vector2(1.0, 1.0) * maxf(0.7, r * 0.05)
		var accent: Color = col
		var neon: Color = Color(str(d.get("neon", "#c07dff")))
		neon.a = alpha
		if dim:
			neon = Color(0.6, 0.58, 0.62, alpha)
		var detail: bool = r >= 12.0
		if r >= 8.0:
			_glyph(ci, gc + off, g, perk, emboss, emboss, emboss, detail)
		_glyph(ci, gc, g, perk, ink, accent, neon, detail)
	else:
		var fnt: Font = _font_or_default(f)
		var abbr: String = str(d.get("abbr", "?"))
		var fs: int = maxi(7, int(r * 0.85))
		var w: float = fnt.get_string_size(abbr, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		ci.draw_string(fnt, gc + Vector2(-w * 0.5, fs * 0.36), abbr, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	# the tier band: a brass strip across the lower cap with the Roman numeral (a brass arc on tiny caps)
	if tier >= 2:
		var brass: Color = (Color(0.78, 0.62, 0.26) if tier < 3 else Color(1.0, 0.84, 0.36))
		if dim:
			brass = Color(0.5, 0.47, 0.4)
		brass.a = alpha
		if band:
			var bh: float = r * 0.44
			var rect: Rect2 = Rect2(c + Vector2(-r * 0.62, r * 0.26), Vector2(r * 1.24, bh))
			ci.draw_rect(rect, brass)
			ci.draw_rect(rect, Color(0.25, 0.17, 0.06, alpha), false, 1.0)
			var mark: String = PerkManager.tier_mark(tier)
			if mark != "" and r >= 15.0:
				var fnt2: Font = _font_or_default(f)
				var ms: int = maxi(7, int(r * 0.4))
				var mw: float = fnt2.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, ms).x
				ci.draw_string(fnt2, Vector2(c.x - mw * 0.5, rect.position.y + bh * 0.82), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, ms,
					Color(0.12, 0.08, 0.03, alpha))
		else:
			ci.draw_arc(c, r * 0.66, PI * 0.25, PI * 0.75, 8, brass, maxf(1.5, r * 0.18))
	if is_bonus:
		_star(ci, c + Vector2(r * 0.78, -r * 0.78), maxf(3.0, r * 0.42), Color(1.0, 0.9, 0.45, alpha))


# ---------------------------------------------------------------- glyphs

## One tonic's symbol, centred at `c`, fitting a disc of radius `g`. `ink` is the symbol, `accent` the cap colour
## for the cut-outs drawn back over it, `neon` the Overclock bolt. `detail` adds the fine parts (off on tiny caps).
static func _glyph(ci: CanvasItem, c: Vector2, g: float, perk: StringName, ink: Color, accent: Color, neon: Color, detail: bool) -> void:
	match perk:
		&"ironhide_stout":
			_shield(ci, c, g, ink, accent, detail)
		&"second_wind":
			_heart(ci, c, g, ink, accent, detail)
		&"trigger_tonic":
			_bullet_fan(ci, c, g, ink, accent, detail)
		&"twin_barrel":
			_two_bores(ci, c, g, ink, accent)
		&"marathon_malt":
			_boot(ci, c, g, ink)
		&"hawkeye_brandy":
			_eye(ci, c, g, ink, accent, detail)
		&"packmule_porter":
			_satchel(ci, c, g, ink, accent, detail)
		&"blastproof_bock":
			_bomb(ci, c, g, ink, accent, detail)
		&"overclock_cordial":
			_cog_bolt(ci, c, g, ink, accent, neon)


static func _pts(c: Vector2, g: float, unit: Array) -> PackedVector2Array:
	var out: PackedVector2Array = []
	for p: Vector2 in unit:
		out.append(c + p * g)
	return out


## Ironhide: a shield with a hoop across it and a row of rivets.
static func _shield(ci: CanvasItem, c: Vector2, g: float, ink: Color, accent: Color, detail: bool) -> void:
	ci.draw_colored_polygon(_pts(c, g, [Vector2(-0.85, -0.8), Vector2(0.85, -0.8), Vector2(0.85, 0.1), Vector2(0.0, 0.95), Vector2(-0.85, 0.1)]), ink)
	ci.draw_rect(Rect2(c + Vector2(-0.85, -0.18) * g, Vector2(1.7, 0.28) * g), accent)
	if detail:
		for x: float in [-0.55, -0.18, 0.18, 0.55]:
			ci.draw_circle(c + Vector2(x, -0.55) * g, g * 0.09, accent)


## Second Wind: a heart with a pulse line across it.
static func _heart(ci: CanvasItem, c: Vector2, g: float, ink: Color, accent: Color, detail: bool) -> void:
	ci.draw_circle(c + Vector2(-0.4, -0.32) * g, g * 0.48, ink)
	ci.draw_circle(c + Vector2(0.4, -0.32) * g, g * 0.48, ink)
	ci.draw_colored_polygon(_pts(c, g, [Vector2(-0.86, -0.18), Vector2(0.86, -0.18), Vector2(0.0, 0.92)]), ink)
	if detail:
		ci.draw_polyline(_pts(c, g, [Vector2(-0.6, 0.02), Vector2(-0.26, 0.02), Vector2(-0.12, -0.34), Vector2(0.1, 0.4), Vector2(0.26, 0.02), Vector2(0.6, 0.02)]),
			accent, maxf(1.0, g * 0.14))


## Trigger Tonic: three cartridges fanned from a point.
static func _bullet_fan(ci: CanvasItem, c: Vector2, g: float, ink: Color, accent: Color, detail: bool) -> void:
	var pivot: Vector2 = c + Vector2(0.0, 0.85) * g
	var hw: float = g * 0.2
	for a: float in [-0.5, 0.0, 0.5]:
		var dir: Vector2 = Vector2(sin(a), -cos(a))
		var perp: Vector2 = Vector2(dir.y, -dir.x)
		var base: Vector2 = pivot + dir * g * 0.1
		var top: Vector2 = pivot + dir * g * 1.45
		ci.draw_colored_polygon(PackedVector2Array([base + perp * hw, top + perp * hw, top - perp * hw, base - perp * hw]), ink)
		ci.draw_circle(top, hw, ink)
		if detail:
			var band: Vector2 = pivot + dir * g * 0.7
			ci.draw_line(band + perp * hw, band - perp * hw, accent, maxf(1.0, g * 0.1))


## Twin Barrel: two bores end-on in one block.
static func _two_bores(ci: CanvasItem, c: Vector2, g: float, ink: Color, accent: Color) -> void:
	var l: Vector2 = c + Vector2(-0.44, 0.0) * g
	var r2: Vector2 = c + Vector2(0.44, 0.0) * g
	ci.draw_circle(l, g * 0.54, ink)
	ci.draw_circle(r2, g * 0.54, ink)
	ci.draw_rect(Rect2(c + Vector2(-0.44, -0.54) * g, Vector2(0.88, 1.08) * g), ink)
	ci.draw_circle(l, g * 0.3, accent)
	ci.draw_circle(r2, g * 0.3, accent)
	ci.draw_circle(l, g * 0.13, ink)
	ci.draw_circle(r2, g * 0.13, ink)


## Marathon: a boot with speed lines trailing behind it.
static func _boot(ci: CanvasItem, c: Vector2, g: float, ink: Color) -> void:
	ci.draw_rect(Rect2(c + Vector2(-0.1, -0.9) * g, Vector2(0.5, 1.25) * g), ink)
	ci.draw_rect(Rect2(c + Vector2(-0.1, 0.35) * g, Vector2(1.0, 0.5) * g), ink)
	ci.draw_circle(c + Vector2(0.9, 0.6) * g, g * 0.25, ink)
	var w: float = maxf(1.0, g * 0.15)
	ci.draw_line(c + Vector2(-0.35, -0.6) * g, c + Vector2(-0.95, -0.6) * g, ink, w)
	ci.draw_line(c + Vector2(-0.35, -0.25) * g, c + Vector2(-0.8, -0.25) * g, ink, w)
	ci.draw_line(c + Vector2(-0.35, 0.1) * g, c + Vector2(-0.95, 0.1) * g, ink, w)


## Hawkeye: an eye inside a crosshair ring.
static func _eye(ci: CanvasItem, c: Vector2, g: float, ink: Color, accent: Color, detail: bool) -> void:
	var w: float = maxf(1.0, g * 0.12)
	if detail:
		ci.draw_arc(c, g * 0.92, 0.0, TAU, 28, ink, w)
		for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			ci.draw_line(c + d * g * 0.78, c + d * g * 1.08, ink, w)
	var lens: PackedVector2Array = []
	var steps: int = 7
	for i: int in steps + 1:
		var t: float = float(i) / float(steps)
		lens.append(c + Vector2(lerpf(-0.68, 0.68, t), -0.42 * sin(PI * t)) * g)
	for i2: int in steps - 1:
		var t2: float = 1.0 - float(i2 + 1) / float(steps)
		lens.append(c + Vector2(lerpf(-0.68, 0.68, t2), 0.42 * sin(PI * t2)) * g)
	ci.draw_colored_polygon(lens, ink)
	ci.draw_circle(c, g * 0.22, accent)
	ci.draw_circle(c, g * 0.09, ink)


## Packmule: a satchel with a handle, a flap and a buckle.
static func _satchel(ci: CanvasItem, c: Vector2, g: float, ink: Color, accent: Color, detail: bool) -> void:
	ci.draw_arc(c + Vector2(0.0, -0.3) * g, g * 0.5, PI, TAU, 10, ink, maxf(1.0, g * 0.16))
	ci.draw_rect(Rect2(c + Vector2(-0.8, -0.3) * g, Vector2(1.6, 1.15) * g), ink)
	if detail:
		ci.draw_colored_polygon(_pts(c, g, [Vector2(-0.7, -0.12), Vector2(0.7, -0.12), Vector2(0.7, 0.22), Vector2(0.0, 0.36), Vector2(-0.7, 0.22)]), accent)
		ci.draw_circle(c + Vector2(0.0, 0.22) * g, g * 0.1, ink)


## Blastproof: a cracked bomb, inside a ring when there is room.
static func _bomb(ci: CanvasItem, c: Vector2, g: float, ink: Color, accent: Color, detail: bool) -> void:
	var w: float = maxf(1.0, g * 0.12)
	var body: Vector2 = c + Vector2(0.0, 0.18) * g
	var br: float = g * (0.5 if detail else 0.6)
	if detail:
		ci.draw_arc(c, g * 0.95, 0.0, TAU, 28, ink, w * 0.8)
	ci.draw_circle(body, br, ink)
	ci.draw_line(body + Vector2(0.3, -0.42) * br, c + Vector2(0.5, -0.72) * g, ink, w)
	ci.draw_circle(c + Vector2(0.56, -0.78) * g, w * 0.9, ink)
	if detail:
		ci.draw_polyline(_pts(c, g, [Vector2(-0.22, -0.05), Vector2(-0.04, 0.12), Vector2(-0.18, 0.3), Vector2(0.04, 0.5)]), accent, w * 0.7)


## Overclock: a cog with the cordial's lightning bolt over its hub. The cog is a disc plus eight convex tooth quads
## (one concave outline can fail to triangulate at nameplate size).
static func _cog_bolt(ci: CanvasItem, c: Vector2, g: float, ink: Color, accent: Color, neon: Color) -> void:
	var teeth: int = 8
	ci.draw_circle(c, g * 0.74, ink)
	for i: int in teeth:
		var a: float = TAU * float(i) / float(teeth)
		var half: float = TAU / float(teeth) * 0.2
		var wide: float = half * 1.35
		ci.draw_colored_polygon(PackedVector2Array([
			c + Vector2(cos(a - half), sin(a - half)) * g * 0.98,
			c + Vector2(cos(a + half), sin(a + half)) * g * 0.98,
			c + Vector2(cos(a + wide), sin(a + wide)) * g * 0.7,
			c + Vector2(cos(a - wide), sin(a - wide)) * g * 0.7]), ink)
	ci.draw_circle(c, g * 0.5, accent)
	ci.draw_colored_polygon(_pts(c, g, [Vector2(0.14, -0.82), Vector2(0.4, -0.82), Vector2(0.06, -0.02), Vector2(-0.28, -0.02)]), neon)
	ci.draw_colored_polygon(_pts(c, g, [Vector2(-0.02, -0.12), Vector2(0.3, -0.12), Vector2(-0.12, 0.82), Vector2(-0.38, 0.82)]), neon)


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
