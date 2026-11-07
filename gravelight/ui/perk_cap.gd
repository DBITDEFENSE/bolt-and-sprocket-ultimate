class_name PerkCap
extends Control
## A perk tonic's bottle cap, drawn at any size: the single source for every cap in the game (T-082). The HUD perk
## row, the bot nameplates, the squad panel, the scoreboard, the pause menu's LOADOUT list and the cabinet signs all
## call `draw_cap`.
##
## A cap is a crimped cap in the tonic's enamel with a bevelled face, and on it the tonic's glyph (one drawn symbol
## per tonic, embossed on the bigger caps), the tier mark and, for a bot's bonus perk, a gold ring and a star at the
## rim. `dim` draws a tonic the player does not hold: desaturated, faded, grey glyph (the pause list).
##
## T-183 (the owner: "make those icons just a little bit better"; they now also show at 16 px on the squad panel):
##  - every tonic has its own enamel (ENAMEL; the cabinets keep perks.json "color"): the three pale blues (Second
##    Wind, Marathon, Skyhook) and the two olives (Packmule, Magpie) and the two golds (Twin Barrel, Ledger) read as
##    one cap at small sizes, so Marathon went cobalt, Skyhook rosé (a Sekt), Magpie charcoal, Ledger the ledger's
##    paper with red ink. The glyph's tone is set per tonic (cream on the dark enamels, ink on the pale ones).
##  - the glyphs were redrawn as bolder silhouettes that tell apart at 16 px: the swallow seen from below (a V of
##    wings and a forked tail) against the crane in side flight (long neck, trailing legs) and the magpie perched (a
##    long tail, a gold coin in its beak); the mule faces you (ears out sideways) so it is no longer the hare's twin;
##    the boot has a real heel and toe. Every piece is still a convex polygon, a circle, an arc or a line.
##  - a small cap (r < 11) draws fewer, deeper crimp teeth, a larger glyph and no fine detail, and shows its tier as a
##    brass badge at the lower right of the rim with one stroke per tier (II, III, IIII); the crimp is brass at II and gold at III,
##    and a permanent tier IV adds the thick gold rim at every size (T-129). Bigger caps keep the brass band with the
##    Roman numeral.
## A tonic without a glyph case (a future cabinet) falls back to its "abbr" letters.

var perk_id: StringName = &""
var bonus: bool = false
var tier: int = 1
var dim: bool = false
var font: Font = null

const CREAM: Color = Color(0.96, 0.93, 0.86)
const INK: Color = Color(0.08, 0.06, 0.05)
const RED_INK: Color = Color(0.62, 0.09, 0.08)
const GREY_INK: Color = Color(0.72, 0.72, 0.7)
const GREY_INK2: Color = Color(0.3, 0.3, 0.3)
const COPPER: Color = Color(0.86, 0.52, 0.22)
const GOLD: Color = Color(1.0, 0.82, 0.3)
const BRASS: Color = Color(0.78, 0.62, 0.26)
const GLYPHS: PackedStringArray = ["ironhide_stout", "second_wind", "trigger_tonic", "twin_barrel", "marathon_malt",
	"hawkeye_brandy", "packmule_porter", "blastproof_bock", "overclock_cordial", "skyhook_sekt", "magpie_mead", "ledger_lager"]
## T-183: the cap's enamel and the glyph's tone per tonic ("cream", "ink" or "red": the silhouette's colour; the other
## tone is the second colour of the two-tone glyphs). A tonic missing here uses perks.json "color" and picks its tone
## by luminance.
const ENAMEL: Dictionary = {
	"ironhide_stout": ["#9e2a1e", "cream"],
	"second_wind": ["#a9d0ea", "ink"],
	"trigger_tonic": ["#bccb1f", "ink"],
	"twin_barrel": ["#e8a317", "ink"],
	"marathon_malt": ["#2f6cc4", "cream"],
	"hawkeye_brandy": ["#1e6a3e", "cream"],
	"packmule_porter": ["#6e5a2b", "cream"],
	"blastproof_bock": ["#e0541b", "cream"],
	"overclock_cordial": ["#2aa79f", "ink"],
	"skyhook_sekt": ["#dc8ba3", "ink"],
	"magpie_mead": ["#262833", "cream"],
	"ledger_lager": ["#ece2c4", "red"],
}

static var _fallback_font: SystemFont = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_cap(self, size * 0.5, minf(size.x, size.y) * 0.5, perk_id, bonus, font, 1.0, tier, dim)


## Whether `perk` has a drawn glyph (else the cap shows its abbreviation letters).
static func has_glyph(perk: StringName) -> bool:
	return GLYPHS.has(String(perk))


## The cap's enamel (T-183: ENAMEL, else perks.json "color").
static func enamel(perk: StringName) -> Color:
	var e: Array = ENAMEL.get(String(perk), []) as Array
	if not e.is_empty():
		return Color(str(e[0]))
	var d: Dictionary = (GLData.table("perks")["perks"] as Dictionary).get(String(perk), {})
	return Color(str(d.get("color", "#c0a040")))


## The glyph's tone: "cream", "ink" or "red" (by luminance for a tonic missing from ENAMEL).
static func tone(perk: StringName) -> String:
	var e: Array = ENAMEL.get(String(perk), []) as Array
	if e.size() > 1:
		return str(e[1])
	return "ink" if enamel(perk).get_luminance() > 0.45 else "cream"


static func _font_or_default(f: Font) -> Font:
	if f != null:
		return f
	if _fallback_font == null:
		_fallback_font = SystemFont.new()
		_fallback_font.font_names = PackedStringArray(["Stencil", "Impact", "Arial Black"])
	return _fallback_font


## Draws one cap centred at `c` with radius `r` onto `ci`. `alpha` fades it (occluded / far nameplates), `tier`
## adds the tier mark (2 / 3 / the permanent tier), `dim` greys an unowned tonic. `f` may be null (a stencil system
## font is used).
static func draw_cap(ci: CanvasItem, c: Vector2, r: float, perk: StringName, is_bonus: bool, f: Font, alpha: float,
		tier: int = 1, dim: bool = false) -> void:
	if r < 3.0 or perk == &"" or alpha <= 0.0:
		return
	var d: Dictionary = (GLData.table("perks")["perks"] as Dictionary).get(String(perk), {})
	var col: Color = enamel(perk)
	if dim:
		col = Color.from_hsv(col.h, col.s * 0.18, col.v * 0.5)
		alpha *= 0.8
	col.a = alpha
	var small: bool = r < 11.0
	var tn: String = tone(perk)
	# ink: the silhouette's tone; ink2: the other tone, for the two-tone glyphs
	var ink: Color = CREAM if tn == "cream" else (RED_INK if tn == "red" else INK)
	var ink2: Color = INK if tn == "cream" else CREAM
	if tn == "red":
		ink2 = INK
	if dim:
		ink = GREY_INK
		ink2 = GREY_INK2
	ink.a = alpha
	ink2.a = alpha
	if is_bonus:
		ci.draw_circle(c, r + maxf(2.0, r * 0.14), Color(GOLD, 0.95 * alpha))
	var perma: bool = tier >= PerkManager.permanent_tier() and not dim
	if perma:   # U08 (T-129): a permanent tonic: a thick gold rim with a bright inner line round the crimp
		ci.draw_circle(c, r + maxf(2.0, r * 0.16), Color(0.55, 0.38, 0.08, alpha))
		ci.draw_circle(c, r + maxf(1.2, r * 0.1), Color(GOLD, alpha))
	# the crimped edge: brass at tier II, gold at III and up (fewer, deeper teeth on a small cap so they show)
	var teeth: PackedVector2Array = []
	var n: int = 16 if small else (24 if r < 20.0 else 36)
	var depth: float = maxf(1.0, r * (0.13 if small else 0.1))
	for i: int in n:
		var a: float = TAU * float(i) / float(n)
		var rr: float = r if i % 2 == 0 else r - depth
		teeth.append(c + Vector2(cos(a), sin(a)) * rr)
	var crimp: Color = Color(col.darkened(0.45), alpha) if col.get_luminance() > 0.12 else Color(col.lightened(0.38), alpha)
	if not dim and tier >= 3:
		crimp = Color(0.88, 0.7, 0.28, alpha)
	elif not dim and tier == 2:
		crimp = Color(0.62, 0.5, 0.26, alpha)
	ci.draw_colored_polygon(teeth, crimp)
	# the face, with a bevel: light on the upper left, shade on the lower right, and a dark keyline at its edge so a
	# pale cap holds on snow
	var fr: float = r * (0.8 if small else 0.82)
	ci.draw_circle(c, fr, Color(col.darkened(0.55), alpha))
	ci.draw_circle(c, fr - maxf(0.6, r * 0.04), col)
	if r >= 7.0:
		var bw: float = maxf(1.0, r * 0.08)
		ci.draw_arc(c, fr - bw * 0.9, PI * 1.02, PI * 1.62, 14, Color(col.lightened(0.45), 0.85 * alpha), bw)
		ci.draw_arc(c, fr - bw * 0.9, PI * 0.02, PI * 0.62, 14, Color(col.darkened(0.4), 0.75 * alpha), bw)
	if r >= 14.0:
		_rim(ci, c, r, perk, col, alpha, dim)
	# the glyph, raised a little when the tier band shows under it (a small cap's tier is a badge at the rim instead)
	var marked: bool = tier >= 2 and not small
	var gc: Vector2 = c + Vector2(0.0, -r * (0.09 if marked else 0.0))
	var g: float = r * (0.6 if small else (0.42 if marked else 0.5))
	if has_glyph(perk):
		var detail: bool = r >= 12.0
		if r >= 12.0:   # the emboss: a shadow pass under the silhouette
			var emboss: Color = Color(col.darkened(0.6), 0.7 * alpha) if tn != "ink" else Color(col.lightened(0.55), 0.7 * alpha)
			if dim:
				emboss = Color(0.0, 0.0, 0.0, 0.35 * alpha)
			var off: Vector2 = (Vector2(1.0, 1.0) if tn != "ink" or dim else Vector2(-1.0, -1.0)) * maxf(0.7, r * 0.05)
			_glyph(ci, gc + off, g, perk, emboss, emboss, emboss, emboss, emboss, detail)
		var copper: Color = Color(0.55, 0.52, 0.48, alpha) if dim else Color(COPPER, alpha)
		var gold: Color = Color(0.6, 0.58, 0.5, alpha) if dim else Color(GOLD, alpha)
		if perk == &"overclock_cordial":
			gold = copper
		_glyph(ci, gc, g, perk, ink, ink2, col, gold, gold, detail)
	else:
		var fnt: Font = _font_or_default(f)
		var abbr: String = str(d.get("abbr", "?"))
		var fs: int = maxi(7, int(r * 0.85))
		var w: float = fnt.get_string_size(abbr, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		ci.draw_string(fnt, gc + Vector2(-w * 0.5, fs * 0.36), abbr, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	if tier >= 2:
		_tier_mark(ci, c, r, tier, perma, dim, alpha, f)
	if is_bonus:
		_star(ci, c + Vector2(r * 0.78, -r * 0.78), maxf(3.0, r * 0.42), Color(1.0, 0.9, 0.45, alpha))


## The tier: on a big cap a brass band under the glyph with the Roman numeral (pale gold at the permanent tier); on a
## small cap a brass badge at the lower right of the rim with one dark stroke per tier, so the glyph keeps its size.
static func _tier_mark(ci: CanvasItem, c: Vector2, r: float, tier: int, perma: bool, dim: bool, alpha: float, f: Font) -> void:
	var brass: Color = BRASS if tier < 3 else Color(1.0, 0.84, 0.36)
	if perma:
		brass = Color(1.0, 0.93, 0.62)
	if dim:
		brass = Color(0.5, 0.47, 0.4)
	brass.a = alpha
	var edge: Color = Color(0.22, 0.14, 0.04, alpha)
	if r >= 11.0:
		var bh: float = r * 0.44
		var rect: Rect2 = Rect2(c + Vector2(-r * 0.62, r * 0.26), Vector2(r * 1.24, bh))
		ci.draw_rect(rect, brass)
		ci.draw_rect(rect, edge, false, 1.0)
		var mark: String = PerkManager.tier_mark(tier)
		if mark != "" and r >= 15.0:
			var fnt2: Font = _font_or_default(f)
			var ms: int = maxi(7, int(r * 0.4))
			var mw: float = fnt2.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, ms).x
			ci.draw_string(fnt2, Vector2(c.x - mw * 0.5, rect.position.y + bh * 0.82), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, ms,
				Color(0.12, 0.08, 0.03, alpha))
		elif r < 15.0:
			_strokes(ci, rect, tier, edge)
		return
	if r < 7.0:
		ci.draw_arc(c, r * 0.66, PI * 0.25, PI * 0.75, 8, brass, maxf(1.5, r * 0.18))
		return
	var k: int = clampi(tier, 2, 4)
	var bw: float = float(k) * 2.0 + 3.0
	var bh: float = maxf(5.0, roundf(r * 0.62))
	var tab: Rect2 = Rect2(Vector2(roundf(c.x + r + 1.0 - bw), roundf(c.y + r + 1.0 - bh)), Vector2(bw, bh))
	ci.draw_rect(tab.grow(1.0), edge)
	ci.draw_rect(tab, brass)
	for i: int in k:
		var x: float = tab.position.x + 2.5 + 2.0 * float(i)
		ci.draw_line(Vector2(x, tab.position.y + 1.0), Vector2(x, tab.end.y - 1.0), edge, 1.0)


## One upright stroke per tier inside `rect` (II = 2, III = 3, IV = 4), whole pixels wide so they stay apart.
static func _strokes(ci: CanvasItem, rect: Rect2, tier: int, col: Color) -> void:
	var k: int = clampi(tier, 2, 4)
	var w: float = 1.0
	var step: float = rect.size.x / float(k + 1)
	for i: int in k:
		var x: float = roundf(rect.position.x + step * float(i + 1)) - 0.5
		ci.draw_line(Vector2(x, rect.position.y + 1.0), Vector2(x, rect.end.y - 1.0), col, w)


## The per-tonic rim inside the face (big caps): Ironhide's riveted ring, Second Wind's thin red rim, Marathon's
## chrome rim, Hawkeye's crosshair ticks are part of its glyph; a plain light ring for the rest.
static func _rim(ci: CanvasItem, c: Vector2, r: float, perk: StringName, col: Color, alpha: float, dim: bool) -> void:
	var ring_r: float = r * 0.68
	match perk:
		&"ironhide_stout":
			ci.draw_arc(c, ring_r, 0.0, TAU, 28, Color(col.darkened(0.55), 0.9 * alpha), maxf(1.0, r * 0.05))
			var rivet: Color = Color(0.5, 0.5, 0.5, alpha) if dim else Color(0.25, 0.1, 0.07, alpha)
			for i: int in 10:
				var a: float = TAU * float(i) / 10.0 + PI * 0.1
				ci.draw_circle(c + Vector2(cos(a), sin(a)) * ring_r, maxf(1.0, r * 0.055), rivet)
		&"second_wind":
			var red: Color = Color(0.45, 0.4, 0.4, alpha) if dim else Color(0.78, 0.14, 0.1, alpha)
			ci.draw_arc(c, r * 0.74, 0.0, TAU, 32, red, maxf(1.0, r * 0.06))
		&"marathon_malt":
			var chrome: Color = Color(0.6, 0.6, 0.6, alpha) if dim else Color(0.88, 0.9, 0.94, alpha)
			ci.draw_arc(c, r * 0.74, 0.0, TAU, 32, chrome, maxf(1.0, r * 0.065))
			ci.draw_arc(c, r * 0.74, PI * 1.1, PI * 1.5, 8, Color(1, 1, 1, alpha), maxf(1.0, r * 0.065))
		&"ledger_lager":
			ci.draw_arc(c, r * 0.72, 0.0, TAU, 32, Color(RED_INK, 0.55 * alpha) if not dim else Color(0.4, 0.4, 0.4, alpha), maxf(1.0, r * 0.03))
		_:
			ci.draw_arc(c, ring_r + r * 0.06, 0.0, TAU, 28, Color(col.lightened(0.3), 0.6 * alpha), 1.0)


# ---------------------------------------------------------------- glyphs

## One tonic's symbol, centred at `c`, fitting a disc of radius `g`. `ink` is the silhouette, `ink2` the other tone
## (the moustache, the starburst, the belly), `face` the cap colour for cut-outs (an eye, a bore), `gold` the accent
## (the magpie's coin), `copper` Overclock's bolt. `detail` adds the fine parts (off on small caps).
static func _glyph(ci: CanvasItem, c: Vector2, g: float, perk: StringName, ink: Color, ink2: Color, face: Color, gold: Color,
		copper: Color, detail: bool) -> void:
	match perk:
		&"ironhide_stout":
			_flexed_arm(ci, c, g, ink, face, detail)
		&"second_wind":
			_swallow(ci, c, g, ink, face, detail)
		&"trigger_tonic":
			_hare(ci, c, g, ink, face, detail)
		&"twin_barrel":
			_crossed_barrels(ci, c, g, ink, ink2, face, detail)
		&"marathon_malt":
			_winged_boot(ci, c, g, ink, face, detail)
		&"hawkeye_brandy":
			_eye(ci, c, g, ink, face, detail)
		&"packmule_porter":
			_mule(ci, c, g, ink, face, detail)
		&"blastproof_bock":
			_ram_burst(ci, c, g, ink, ink2, detail)
		&"overclock_cordial":
			_cog_bolt(ci, c, g, ink, face, copper, detail)
		&"skyhook_sekt":
			_crane(ci, c, g, ink, face, detail)
		&"magpie_mead":
			_magpie(ci, c, g, ink, ink2, face, gold, detail)
		&"ledger_lager":
			_tally_marks(ci, c, g, ink, ink2, detail)


static func _pts(c: Vector2, g: float, unit: Array) -> PackedVector2Array:
	var out: PackedVector2Array = []
	for p: Vector2 in unit:
		out.append(c + p * g)
	return out


static func _tri(ci: CanvasItem, c: Vector2, g: float, a: Vector2, b: Vector2, d: Vector2, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + a * g, c + b * g, c + d * g]), col)


## A filled ellipse (a convex polygon), centre `o`, radii `rx` / `ry`, turned by `rot`.
static func _ellipse(ci: CanvasItem, c: Vector2, g: float, o: Vector2, rx: float, ry: float, rot: float, col: Color) -> void:
	var pts: PackedVector2Array = []
	var k: int = 14
	for i: int in k:
		var a: float = TAU * float(i) / float(k)
		pts.append(c + (o + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot)) * g)
	ci.draw_colored_polygon(pts, col)


## A thick stroke with round ends (a quad and two circles), in unit coordinates.
static func _capsule(ci: CanvasItem, c: Vector2, g: float, a: Vector2, b: Vector2, hw: float, col: Color) -> void:
	var pa: Vector2 = c + a * g
	var pb: Vector2 = c + b * g
	var dir: Vector2 = (pb - pa).normalized()
	var perp: Vector2 = Vector2(-dir.y, dir.x) * hw * g
	ci.draw_colored_polygon(PackedVector2Array([pa + perp, pb + perp, pb - perp, pa - perp]), col)
	ci.draw_circle(pa, hw * g, col)
	ci.draw_circle(pb, hw * g, col)


## Ironhide: Fassl's flexed arm (upper arm level, the bicep high, the forearm up, the fist).
static func _flexed_arm(ci: CanvasItem, c: Vector2, g: float, ink: Color, face: Color, detail: bool) -> void:
	_capsule(ci, c, g, Vector2(-0.82, 0.5), Vector2(0.22, 0.5), 0.25, ink)
	_ellipse(ci, c, g, Vector2(-0.28, 0.16), 0.46, 0.36, -0.15, ink)
	_capsule(ci, c, g, Vector2(0.22, 0.5), Vector2(0.44, -0.42), 0.22, ink)
	ci.draw_circle(c + Vector2(0.48, -0.62) * g, g * 0.33, ink)
	if detail:   # the fold of the elbow and the knuckles
		ci.draw_line(c + Vector2(0.05, 0.42) * g, c + Vector2(0.2, 0.26) * g, face, maxf(1.0, g * 0.06))
		ci.draw_line(c + Vector2(0.3, -0.72) * g, c + Vector2(0.62, -0.78) * g, face, maxf(1.0, g * 0.05))


## Second Wind: a swallow seen from below: a V of swept wings, a round head, a long forked tail.
static func _swallow(ci: CanvasItem, c: Vector2, g: float, ink: Color, face: Color, detail: bool) -> void:
	_ellipse(ci, c, g, Vector2(0.0, 0.02), 0.2, 0.4, 0.0, ink)
	ci.draw_circle(c + Vector2(0.0, -0.42) * g, g * 0.2, ink)
	for s: float in [-1.0, 1.0]:
		# the wing: two triangles swept back to a sharp tip
		_tri(ci, c, g, Vector2(0.0, -0.28), Vector2(s * 1.0, -0.42), Vector2(s * 0.12, 0.08), ink)
		_tri(ci, c, g, Vector2(s * 0.12, 0.08), Vector2(s * 1.0, -0.42), Vector2(s * 0.62, -0.06), ink)
		# the tail streamer
		_tri(ci, c, g, Vector2(0.0, 0.3), Vector2(s * 0.42, 0.98), Vector2(s * 0.14, 0.32), ink)
	if detail:   # the throat patch
		ci.draw_circle(c + Vector2(0.0, -0.32) * g, g * 0.08, face)


## Trigger Tonic: Pauli's hare, head in profile with both ears up and motion lines behind it.
static func _hare(ci: CanvasItem, c: Vector2, g: float, ink: Color, face: Color, detail: bool) -> void:
	ci.draw_circle(c + Vector2(0.2, 0.32) * g, g * 0.4, ink)
	ci.draw_circle(c + Vector2(0.58, 0.42) * g, g * 0.24, ink)
	_tri(ci, c, g, Vector2(-0.25, 0.88), Vector2(0.58, 0.88), Vector2(0.2, 0.3), ink)
	_capsule(ci, c, g, Vector2(0.02, 0.0), Vector2(-0.36, -0.88), 0.15, ink)
	_capsule(ci, c, g, Vector2(0.26, -0.04), Vector2(0.2, -0.96), 0.14, ink)
	var w: float = maxf(1.0, g * 0.11)
	ci.draw_line(c + Vector2(-0.42, 0.2) * g, c + Vector2(-0.96, 0.2) * g, ink, w)
	ci.draw_line(c + Vector2(-0.4, 0.62) * g, c + Vector2(-0.9, 0.62) * g, ink, w)
	if detail:
		ci.draw_circle(c + Vector2(0.32, 0.22) * g, g * 0.075, face)
		ci.draw_line(c + Vector2(-0.48, 0.41) * g, c + Vector2(-0.82, 0.41) * g, ink, w)


## Twin Barrel: two crossed barrels with their bores, the Major's moustache beneath them.
static func _crossed_barrels(ci: CanvasItem, c: Vector2, g: float, ink: Color, ink2: Color, face: Color, detail: bool) -> void:
	_capsule(ci, c, g, Vector2(-0.7, -0.78), Vector2(0.62, 0.3), 0.16, ink)
	_capsule(ci, c, g, Vector2(0.7, -0.78), Vector2(-0.62, 0.3), 0.16, ink)
	ci.draw_circle(c + Vector2(-0.7, -0.78) * g, g * 0.24, ink)
	ci.draw_circle(c + Vector2(0.7, -0.78) * g, g * 0.24, ink)
	ci.draw_circle(c + Vector2(-0.7, -0.78) * g, g * 0.1, face)
	ci.draw_circle(c + Vector2(0.7, -0.78) * g, g * 0.1, face)
	# the moustache: two curled halves, thick at the middle
	for s: float in [-1.0, 1.0]:
		_capsule(ci, c, g, Vector2(0.0, 0.58), Vector2(s * 0.42, 0.5), 0.13, ink)
		_capsule(ci, c, g, Vector2(s * 0.42, 0.5), Vector2(s * 0.74, 0.74), 0.09, ink)
	if detail:   # the moustache's white wax (the bible's white moustache, as a highlight: ink reads on amber)
		ci.draw_line(c + Vector2(-0.4, 0.5) * g, c + Vector2(0.4, 0.5) * g, ink2, maxf(1.0, g * 0.05))


## Marathon: a laced boot (shaft, heel, toe) with a wing of three feathers at the heel.
static func _winged_boot(ci: CanvasItem, c: Vector2, g: float, ink: Color, face: Color, detail: bool) -> void:
	ci.draw_colored_polygon(_pts(c, g, [Vector2(-0.12, -0.82), Vector2(0.36, -0.82), Vector2(0.4, 0.3), Vector2(-0.14, 0.3)]), ink)
	ci.draw_colored_polygon(_pts(c, g, [Vector2(-0.14, 0.2), Vector2(0.4, 0.12), Vector2(0.86, 0.36), Vector2(0.92, 0.62),
		Vector2(-0.14, 0.62)]), ink)
	ci.draw_rect(Rect2(c + Vector2(-0.18, 0.62) * g, Vector2(1.12, 0.14) * g), ink)   # the sole
	for k: int in 3:
		var y0: float = -0.5 + k * 0.28
		_capsule(ci, c, g, Vector2(-0.16, y0), Vector2(-0.92 + k * 0.08, y0 - 0.42 + k * 0.1), 0.085 - k * 0.01, ink)
	if detail:   # the laces
		for k2: int in 3:
			var y: float = -0.55 + k2 * 0.25
			ci.draw_line(c + Vector2(0.05, y) * g, c + Vector2(0.3, y + 0.08) * g, face, maxf(1.0, g * 0.05))


## Hawkeye: a hawk's eye inside a crosshair, four ticks round it.
static func _eye(ci: CanvasItem, c: Vector2, g: float, ink: Color, face: Color, detail: bool) -> void:
	var w: float = maxf(1.0, g * 0.12)
	ci.draw_arc(c, g * 0.9, 0.0, TAU, 28 if detail else 16, ink, w)
	for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		ci.draw_line(c + d * g * 0.74, c + d * g * 1.08, ink, w)
	var lens: PackedVector2Array = []
	var steps: int = 7
	for i: int in steps + 1:
		var t: float = float(i) / float(steps)
		lens.append(c + Vector2(lerpf(-0.64, 0.64, t), -0.4 * sin(PI * t)) * g)
	for i2: int in steps - 1:
		var t2: float = 1.0 - float(i2 + 1) / float(steps)
		lens.append(c + Vector2(lerpf(-0.64, 0.64, t2), 0.4 * sin(PI * t2)) * g)
	ci.draw_colored_polygon(lens, ink)
	ci.draw_circle(c, g * 0.24, face)
	ci.draw_circle(c, g * 0.11, ink)
	if detail:
		ci.draw_circle(c + Vector2(0.08, -0.08) * g, g * 0.04, face)


## Packmule: Ammer's mule facing you (a long face, the ears out sideways, the muzzle), three rifle lines fanning
## behind its head.
static func _mule(ci: CanvasItem, c: Vector2, g: float, ink: Color, face: Color, detail: bool) -> void:
	if detail:
		var w: float = maxf(1.0, g * 0.08)
		for x: float in [-0.62, 0.0, 0.62]:
			ci.draw_line(c + Vector2(0.0, 0.2) * g, c + Vector2(x, -1.0) * g, ink, w)
	ci.draw_colored_polygon(_pts(c, g, [Vector2(-0.34, -0.42), Vector2(0.34, -0.42), Vector2(0.27, 0.5), Vector2(-0.27, 0.5)]), ink)
	ci.draw_circle(c + Vector2(0.0, -0.42) * g, g * 0.34, ink)
	_ellipse(ci, c, g, Vector2(0.0, 0.58), 0.32, 0.26, 0.0, ink)
	# the long ears, up and out like a V (leaf-shaped, so they never read as horns)
	_ellipse(ci, c, g, Vector2(-0.4, -0.78), 0.14, 0.34, -0.5, ink)
	_ellipse(ci, c, g, Vector2(0.4, -0.78), 0.14, 0.34, 0.5, ink)
	ci.draw_circle(c + Vector2(-0.16, -0.24) * g, g * 0.075, face)
	ci.draw_circle(c + Vector2(0.16, -0.24) * g, g * 0.075, face)
	if detail:
		ci.draw_circle(c + Vector2(-0.12, 0.62) * g, g * 0.06, face)
		ci.draw_circle(c + Vector2(0.12, 0.62) * g, g * 0.06, face)


## Blastproof: the Pionierschule's ram's head over a starburst.
static func _ram_burst(ci: CanvasItem, c: Vector2, g: float, ink: Color, ink2: Color, detail: bool) -> void:
	ci.draw_circle(c, g * 0.48, ink2)
	for i: int in 8:
		var a: float = TAU * float(i) / 8.0 + PI / 8.0
		var dir: Vector2 = Vector2(cos(a), sin(a))
		var perp: Vector2 = Vector2(-dir.y, dir.x) * 0.17
		ci.draw_colored_polygon(PackedVector2Array([c + (dir * 0.3 + perp) * g, c + dir * g * 1.02, c + (dir * 0.3 - perp) * g]), ink2)
	ci.draw_colored_polygon(_pts(c, g, [Vector2(-0.3, -0.32), Vector2(0.3, -0.32), Vector2(0.24, 0.3), Vector2(0.0, 0.58), Vector2(-0.24, 0.3)]), ink)
	var w: float = maxf(1.4, g * 0.17)
	ci.draw_arc(c + Vector2(-0.42, -0.2) * g, g * 0.3, PI * 1.55, PI * 2.95, 10, ink, w)
	ci.draw_arc(c + Vector2(0.42, -0.2) * g, g * 0.3, PI * 0.05, PI * 1.45, 10, ink, w)
	if detail:
		ci.draw_circle(c + Vector2(-0.12, -0.06) * g, g * 0.065, ink2)
		ci.draw_circle(c + Vector2(0.12, -0.06) * g, g * 0.065, ink2)


## Overclock: a cog with a copper lightning bolt through it and the robot's two round eyes. The cog is a disc plus
## eight convex tooth quads (one concave outline can fail to triangulate at nameplate size).
static func _cog_bolt(ci: CanvasItem, c: Vector2, g: float, ink: Color, face: Color, copper: Color, detail: bool) -> void:
	var teeth: int = 8
	ci.draw_circle(c, g * 0.74, ink)
	for i: int in teeth:
		var a: float = TAU * float(i) / float(teeth)
		var half: float = TAU / float(teeth) * 0.2
		var wide: float = half * 1.35
		ci.draw_colored_polygon(PackedVector2Array([
			c + Vector2(cos(a - half), sin(a - half)) * g * 1.0,
			c + Vector2(cos(a + half), sin(a + half)) * g * 1.0,
			c + Vector2(cos(a + wide), sin(a + wide)) * g * 0.7,
			c + Vector2(cos(a - wide), sin(a - wide)) * g * 0.7]), ink)
	ci.draw_circle(c, g * 0.52, face)
	ci.draw_colored_polygon(_pts(c, g, [Vector2(0.12, -0.84), Vector2(0.42, -0.84), Vector2(0.08, -0.02), Vector2(-0.3, -0.02)]), copper)
	ci.draw_colored_polygon(_pts(c, g, [Vector2(-0.06, -0.12), Vector2(0.3, -0.12), Vector2(-0.12, 0.84), Vector2(-0.42, 0.84)]), copper)
	if detail:
		for x: float in [-0.5, 0.5]:
			ci.draw_circle(c + Vector2(x, 0.38) * g, g * 0.13, ink)
			ci.draw_circle(c + Vector2(x, 0.38) * g, g * 0.06, face)


## Skyhook Sekt (T-105): Fräulein Kranich, a crane in side flight: a long neck and bill forward, the wings up and
## down, the legs trailing straight behind.
static func _crane(ci: CanvasItem, c: Vector2, g: float, ink: Color, face: Color, detail: bool) -> void:
	_ellipse(ci, c, g, Vector2(-0.08, 0.12), 0.42, 0.17, -0.12, ink)
	# the upper wing, raised high and back; the lower wing, down
	_tri(ci, c, g, Vector2(-0.3, 0.06), Vector2(0.18, 0.02), Vector2(-0.52, -0.92), ink)
	_tri(ci, c, g, Vector2(-0.3, 0.06), Vector2(-0.52, -0.92), Vector2(-0.82, -0.72), ink)
	_tri(ci, c, g, Vector2(-0.2, 0.2), Vector2(0.14, 0.18), Vector2(-0.12, 0.72), ink)
	# the neck, the head, the bill
	_capsule(ci, c, g, Vector2(0.26, 0.04), Vector2(0.66, -0.2), 0.08, ink)
	ci.draw_circle(c + Vector2(0.7, -0.22) * g, g * 0.12, ink)
	_tri(ci, c, g, Vector2(0.76, -0.28), Vector2(1.02, -0.16), Vector2(0.76, -0.15), ink)
	# the legs, trailing
	var w: float = maxf(1.0, g * 0.07)
	ci.draw_line(c + Vector2(-0.46, 0.18) * g, c + Vector2(-1.0, 0.36) * g, ink, w)
	ci.draw_line(c + Vector2(-0.42, 0.24) * g, c + Vector2(-0.95, 0.48) * g, ink, w)
	if detail:
		ci.draw_circle(c + Vector2(0.72, -0.25) * g, g * 0.035, face)


## Magpie Mead (T-105): the magpie in profile, a long tail down behind it and a gold coin in its beak; the wing
## patch and its perch on a big cap.
static func _magpie(ci: CanvasItem, c: Vector2, g: float, ink: Color, ink2: Color, face: Color, gold: Color, detail: bool) -> void:
	_ellipse(ci, c, g, Vector2(-0.04, 0.08), 0.5, 0.31, -0.5, ink)
	ci.draw_circle(c + Vector2(0.32, -0.36) * g, g * 0.26, ink)
	_tri(ci, c, g, Vector2(0.5, -0.47), Vector2(0.8, -0.36), Vector2(0.52, -0.26), ink)
	# the tail: a long wedge down and back
	ci.draw_colored_polygon(_pts(c, g, [Vector2(-0.3, 0.26), Vector2(-0.1, 0.4), Vector2(-0.72, 1.0), Vector2(-0.96, 0.84)]), ink)
	# the coin in its beak
	ci.draw_circle(c + Vector2(0.84, -0.3) * g, g * 0.18, gold)
	if detail:
		_ellipse(ci, c, g, Vector2(-0.12, 0.1), 0.24, 0.12, -0.5, ink2)   # the wing patch (the other tone)
		ci.draw_circle(c + Vector2(0.38, -0.42) * g, g * 0.05, face)
		ci.draw_circle(c + Vector2(0.84, -0.3) * g, g * 0.08, Color(face.darkened(0.2), gold.a))
		var w: float = maxf(1.0, g * 0.07)
		ci.draw_line(c + Vector2(0.04, 0.36) * g, c + Vector2(0.1, 0.66) * g, ink, w)
		ci.draw_line(c + Vector2(-0.3, 0.66) * g, c + Vector2(0.5, 0.66) * g, ink, w)


## Ledger Lager (T-141): the tally mark, four strokes and a fifth across, over the register's ruled line.
static func _tally_marks(ci: CanvasItem, c: Vector2, g: float, ink: Color, ink2: Color, detail: bool) -> void:
	var w: float = maxf(1.2, g * 0.15)
	for i: int in 4:
		var x: float = -0.5 + i * 0.33
		ci.draw_line(c + Vector2(x, -0.62) * g, c + Vector2(x, 0.4) * g, ink, w)
	ci.draw_line(c + Vector2(-0.74, 0.28) * g, c + Vector2(0.74, -0.5) * g, ink, w)
	ci.draw_line(c + Vector2(-0.84, 0.66) * g, c + Vector2(0.84, 0.66) * g, ink2, maxf(1.0, g * (0.07 if detail else 0.1)))


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
