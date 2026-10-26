class_name PerkCap
extends Control
## A perk tonic's bottle cap, drawn at any size: the single source for every cap in the game (T-082). The HUD perk
## row, the bot nameplates, the co-op squad ledger and the pause menu's LOADOUT list all call `draw_cap`.
##
## A cap is a crimped cap in the tonic's enamel colour with a bevelled face, and on it the tonic's glyph (one drawn
## symbol per tonic, embossed: a shadow pass under cream on dark enamel, ink on pale), the tier band (a brass strip
## with II / III under the glyph; the crimp turns gold at III) and, for a bot's bonus perk, a gold ring and a star at
## the rim. `dim` draws a tonic the player does not hold: desaturated, faded, grey glyph (the pause list).
##
## The glyphs follow the cabinets' art bible (docs/gravelight/JINGLES.md, "Bottle cap" per tonic): Ironhide a flexed
## arm inside a riveted ring; Second Wind a swallow with a thin red rim; Trigger Tonic a hare's head with motion
## lines; Twin Barrel two crossed barrels over a moustache; Marathon a winged boot with a chrome rim; Hawkeye a hawk's
## eye with crosshair ticks; Packmule a mule's head with three rifle lines fanning behind it; Blastproof a ram's head
## over a black starburst; Overclock a copper lightning bolt with two small round eyes, over a cog. Every piece is a
## convex polygon, a circle, an arc or a line, so the glyphs draw at 18 px as well as 54 px. A tonic without a glyph
## case (a future cabinet) falls back to its "abbr" letters.

var perk_id: StringName = &""
var bonus: bool = false
var tier: int = 1
var dim: bool = false
var font: Font = null

const CREAM: Color = Color(0.95, 0.92, 0.85)
const INK: Color = Color(0.08, 0.06, 0.05)
const GREY_INK: Color = Color(0.72, 0.72, 0.7)
const GREY_INK2: Color = Color(0.3, 0.3, 0.3)
const COPPER: Color = Color(0.82, 0.5, 0.24)
const GLYPHS: PackedStringArray = ["ironhide_stout", "second_wind", "trigger_tonic", "twin_barrel", "marathon_malt",
	"hawkeye_brandy", "packmule_porter", "blastproof_bock", "overclock_cordial", "skyhook_sekt", "magpie_mead"]

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
	# ink: the silhouette's tone (cream on dark enamel, ink on pale); ink2: the other tone, for the two-tone glyphs
	var ink: Color = GREY_INK if dim else (INK if light_face else CREAM)
	var ink2: Color = GREY_INK2 if dim else (CREAM if light_face else INK)
	ink.a = alpha
	ink2.a = alpha
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
		_rim(ci, c, r, perk, col, alpha, dim)
	# the glyph, raised a little when the band shows under it
	var band: bool = tier >= 2 and r >= 11.0
	var gc: Vector2 = c + Vector2(0.0, -r * 0.09 if band else 0.0)
	var g: float = r * (0.42 if band else 0.48)
	if has_glyph(perk):
		var emboss: Color = Color(col.lightened(0.55), 0.7 * alpha) if light_face else Color(col.darkened(0.6), 0.75 * alpha)
		if dim:
			emboss = Color(0.0, 0.0, 0.0, 0.35 * alpha)
		var off: Vector2 = Vector2(-1.0, -1.0) * maxf(0.7, r * 0.05) if light_face and not dim else Vector2(1.0, 1.0) * maxf(0.7, r * 0.05)
		var detail: bool = r >= 12.0
		if r >= 8.0:
			_glyph(ci, gc + off, g, perk, emboss, emboss, emboss, emboss, detail)
		var copper: Color = Color(0.55, 0.52, 0.48, alpha) if dim else Color(COPPER, alpha)
		_glyph(ci, gc, g, perk, ink, ink2, col, copper, detail)
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


## The per-tonic rim inside the face: Ironhide's riveted ring, Second Wind's thin red rim, Marathon's chrome rim,
## a plain light ring for the rest.
static func _rim(ci: CanvasItem, c: Vector2, r: float, perk: StringName, col: Color, alpha: float, dim: bool) -> void:
	var ring_r: float = r * 0.66
	match perk:
		&"ironhide_stout":
			ci.draw_arc(c, ring_r, 0.0, TAU, 24, Color(col.darkened(0.55), 0.9 * alpha), maxf(1.0, r * 0.05))
			if r >= 12.0:
				var rivet: Color = Color(0.5, 0.5, 0.5, alpha) if dim else Color(0.2, 0.08, 0.06, alpha)
				for i: int in 10:
					var a: float = TAU * float(i) / 10.0 + PI * 0.1
					ci.draw_circle(c + Vector2(cos(a), sin(a)) * ring_r, maxf(1.0, r * 0.055), rivet)
		&"second_wind":
			var red: Color = Color(0.45, 0.4, 0.4, alpha) if dim else Color(0.78, 0.14, 0.1, alpha)
			ci.draw_arc(c, r * 0.74, 0.0, TAU, 28, red, maxf(1.0, r * 0.055))
		&"marathon_malt":
			var chrome: Color = Color(0.6, 0.6, 0.6, alpha) if dim else Color(0.9, 0.92, 0.95, alpha)
			ci.draw_arc(c, r * 0.74, 0.0, TAU, 28, chrome, maxf(1.0, r * 0.06))
			ci.draw_arc(c, r * 0.74, PI * 1.1, PI * 1.5, 8, Color(1, 1, 1, alpha), maxf(1.0, r * 0.06))
		_:
			ci.draw_arc(c, ring_r, 0.0, TAU, 24, Color(col.lightened(0.3), 0.8 * alpha), 1.0)


# ---------------------------------------------------------------- glyphs

## One tonic's symbol, centred at `c`, fitting a disc of radius `g`. `ink` is the silhouette, `ink2` the other
## tone (the moustache, the starburst, the rifle lines), `face` the cap colour for cut-outs (an eye, a bore), `copper`
## the Overclock bolt. `detail` adds the fine parts (off on tiny caps).
static func _glyph(ci: CanvasItem, c: Vector2, g: float, perk: StringName, ink: Color, ink2: Color, face: Color, copper: Color, detail: bool) -> void:
	match perk:
		&"ironhide_stout":
			_flexed_arm(ci, c, g, ink)
		&"second_wind":
			_swallow(ci, c, g, ink, face, detail)
		&"trigger_tonic":
			_hare(ci, c, g, ink, face, detail)
		&"twin_barrel":
			_crossed_barrels(ci, c, g, ink, ink2, face, detail)
		&"marathon_malt":
			_winged_boot(ci, c, g, ink)
		&"hawkeye_brandy":
			_eye(ci, c, g, ink, face, detail)
		&"packmule_porter":
			_mule(ci, c, g, ink, face, detail)
		&"blastproof_bock":
			_ram_burst(ci, c, g, ink, ink2, detail)
		&"overclock_cordial":
			_cog_bolt(ci, c, g, ink, ink2, face, copper, detail)
		&"skyhook_sekt":
			_crane(ci, c, g, ink, face, detail)
		&"magpie_mead":
			_magpie_eye(ci, c, g, ink, ink2, face, detail)


## Skyhook Sekt (T-105): Fräulein Kranich, a crane in flight: a long neck and bill, two spread wings, trailing legs.
static func _crane(ci: CanvasItem, c: Vector2, g: float, ink: Color, face: Color, detail: bool) -> void:
	# body
	ci.draw_colored_polygon(_pts(c, g, [Vector2(-0.35, 0.05), Vector2(0.2, -0.05), Vector2(0.4, 0.12), Vector2(0.05, 0.3), Vector2(-0.4, 0.25)]), ink)
	# wings, spread
	ci.draw_colored_polygon(_pts(c, g, [Vector2(-0.1, 0.0), Vector2(-0.95, -0.55), Vector2(-0.75, -0.7), Vector2(0.15, -0.1)]), ink)
	ci.draw_colored_polygon(_pts(c, g, [Vector2(0.0, 0.1), Vector2(0.85, -0.6), Vector2(0.98, -0.42), Vector2(0.25, 0.2)]), ink)
	# neck and head, bill forward
	_capsule(ci, c, g, Vector2(0.3, 0.02), Vector2(0.62, -0.3), 0.09, ink)
	ci.draw_circle(c + Vector2(0.64, -0.34) * g, g * 0.12, ink)
	ci.draw_colored_polygon(_pts(c, g, [Vector2(0.7, -0.38), Vector2(1.0, -0.3), Vector2(0.72, -0.26)]), ink)
	# legs trailing
	var w: float = maxf(1.0, g * 0.07)
	ci.draw_line(c + Vector2(-0.3, 0.25) * g, c + Vector2(-0.8, 0.6) * g, ink, w)
	ci.draw_line(c + Vector2(-0.2, 0.28) * g, c + Vector2(-0.65, 0.68) * g, ink, w)
	if detail:
		ci.draw_circle(c + Vector2(0.66, -0.37) * g, g * 0.035, face)
		# the flying scarf, out straight behind the head
		ci.draw_line(c + Vector2(0.55, -0.3) * g, c + Vector2(0.1, -0.5) * g, face, maxf(1.0, g * 0.06))


## Magpie Mead (T-105): the magpie's eye in a sergeant's chevron.
static func _magpie_eye(ci: CanvasItem, c: Vector2, g: float, ink: Color, ink2: Color, face: Color, detail: bool) -> void:
	# the chevron (three stripes) under the eye
	var w: float = maxf(1.0, g * 0.1)
	for i: int in 3:
		var y: float = 0.35 + i * 0.2
		ci.draw_line(c + Vector2(-0.6, y - 0.2) * g, c + Vector2(0.0, y) * g, ink2, w)
		ci.draw_line(c + Vector2(0.0, y) * g, c + Vector2(0.6, y - 0.2) * g, ink2, w)
	# the eye: a lens, a dark iris, a bright glint
	var lens: PackedVector2Array = []
	var steps: int = 8
	for i: int in steps + 1:
		var t: float = float(i) / float(steps)
		lens.append(c + Vector2(lerpf(-0.75, 0.75, t), -0.25 - 0.4 * sin(PI * t)) * g)
	for i2: int in steps - 1:
		var t2: float = 1.0 - float(i2 + 1) / float(steps)
		lens.append(c + Vector2(lerpf(-0.75, 0.75, t2), -0.25 + 0.4 * sin(PI * t2)) * g)
	ci.draw_colored_polygon(lens, face)
	ci.draw_circle(c + Vector2(0.0, -0.25) * g, g * 0.3, ink)
	if detail:
		ci.draw_circle(c + Vector2(0.1, -0.35) * g, g * 0.09, face)


static func _pts(c: Vector2, g: float, unit: Array) -> PackedVector2Array:
	var out: PackedVector2Array = []
	for p: Vector2 in unit:
		out.append(c + p * g)
	return out


## A thick stroke with round ends (a rect and two circles), in unit coordinates.
static func _capsule(ci: CanvasItem, c: Vector2, g: float, a: Vector2, b: Vector2, hw: float, col: Color) -> void:
	var pa: Vector2 = c + a * g
	var pb: Vector2 = c + b * g
	var dir: Vector2 = (pb - pa).normalized()
	var perp: Vector2 = Vector2(-dir.y, dir.x) * hw * g
	ci.draw_colored_polygon(PackedVector2Array([pa + perp, pb + perp, pb - perp, pa - perp]), col)
	ci.draw_circle(pa, hw * g, col)
	ci.draw_circle(pb, hw * g, col)


## Ironhide: Fassl's flexed arm (upper arm, bicep, forearm up, fist).
static func _flexed_arm(ci: CanvasItem, c: Vector2, g: float, ink: Color) -> void:
	_capsule(ci, c, g, Vector2(-0.8, 0.45), Vector2(0.2, 0.45), 0.24, ink)
	ci.draw_circle(c + Vector2(-0.3, 0.12) * g, g * 0.4, ink)
	_capsule(ci, c, g, Vector2(0.2, 0.45), Vector2(0.42, -0.45), 0.22, ink)
	ci.draw_circle(c + Vector2(0.46, -0.6) * g, g * 0.32, ink)


## Second Wind: a swallow in flight (body, head and beak, a swept wing, a forked tail).
static func _swallow(ci: CanvasItem, c: Vector2, g: float, ink: Color, face: Color, detail: bool) -> void:
	var body: PackedVector2Array = []
	for i: int in 12:
		var a: float = TAU * float(i) / 12.0
		body.append(c + Vector2(cos(a) * 0.55, 0.08 + sin(a) * 0.26) * g)
	ci.draw_colored_polygon(body, ink)
	ci.draw_circle(c + Vector2(0.55, -0.02) * g, g * 0.21, ink)
	ci.draw_colored_polygon(_pts(c, g, [Vector2(0.68, -0.1), Vector2(0.95, 0.0), Vector2(0.68, 0.08)]), ink)
	ci.draw_colored_polygon(_pts(c, g, [Vector2(-0.15, -0.05), Vector2(0.3, -0.12), Vector2(-0.4, -0.95)]), ink)
	ci.draw_colored_polygon(_pts(c, g, [Vector2(-0.45, 0.0), Vector2(-0.95, -0.35), Vector2(-0.5, 0.18)]), ink)
	ci.draw_colored_polygon(_pts(c, g, [Vector2(-0.45, 0.05), Vector2(-0.95, 0.5), Vector2(-0.5, 0.2)]), ink)
	if detail:
		ci.draw_circle(c + Vector2(0.6, -0.07) * g, g * 0.06, face)


## Trigger Tonic: Pauli's hare, head in profile with both ears up and motion lines behind it.
static func _hare(ci: CanvasItem, c: Vector2, g: float, ink: Color, face: Color, detail: bool) -> void:
	ci.draw_circle(c + Vector2(0.18, 0.3) * g, g * 0.38, ink)
	ci.draw_circle(c + Vector2(0.55, 0.38) * g, g * 0.22, ink)
	ci.draw_colored_polygon(_pts(c, g, [Vector2(-0.3, 0.85), Vector2(0.55, 0.85), Vector2(0.2, 0.3)]), ink)
	_capsule(ci, c, g, Vector2(0.02, -0.02), Vector2(-0.3, -0.9), 0.14, ink)
	_capsule(ci, c, g, Vector2(0.22, -0.05), Vector2(0.14, -0.95), 0.13, ink)
	if detail:
		ci.draw_circle(c + Vector2(0.28, 0.2) * g, g * 0.07, face)
		var w: float = maxf(1.0, g * 0.1)
		ci.draw_line(c + Vector2(-0.45, 0.15) * g, c + Vector2(-0.95, 0.15) * g, ink, w)
		ci.draw_line(c + Vector2(-0.5, 0.42) * g, c + Vector2(-0.9, 0.42) * g, ink, w)
		ci.draw_line(c + Vector2(-0.45, 0.68) * g, c + Vector2(-0.95, 0.68) * g, ink, w)


## Twin Barrel: two crossed barrels, the Major's moustache beneath them.
static func _crossed_barrels(ci: CanvasItem, c: Vector2, g: float, ink: Color, ink2: Color, face: Color, detail: bool) -> void:
	_capsule(ci, c, g, Vector2(-0.72, -0.8), Vector2(0.62, 0.3), 0.14, ink)
	_capsule(ci, c, g, Vector2(0.72, -0.8), Vector2(-0.62, 0.3), 0.14, ink)
	ci.draw_circle(c + Vector2(-0.72, -0.8) * g, g * 0.22, ink)
	ci.draw_circle(c + Vector2(0.72, -0.8) * g, g * 0.22, ink)
	if detail:
		ci.draw_circle(c + Vector2(-0.72, -0.8) * g, g * 0.09, face)
		ci.draw_circle(c + Vector2(0.72, -0.8) * g, g * 0.09, face)
	var w: float = maxf(1.2, g * 0.16)
	ci.draw_polyline(_pts(c, g, [Vector2(0.0, 0.55), Vector2(-0.28, 0.45), Vector2(-0.55, 0.52), Vector2(-0.72, 0.75)]), ink2, w)
	ci.draw_polyline(_pts(c, g, [Vector2(0.0, 0.55), Vector2(0.28, 0.45), Vector2(0.55, 0.52), Vector2(0.72, 0.75)]), ink2, w)


## Marathon: a boot with a wing of three feathers at the heel.
static func _winged_boot(ci: CanvasItem, c: Vector2, g: float, ink: Color) -> void:
	ci.draw_rect(Rect2(c + Vector2(-0.1, -0.85) * g, Vector2(0.5, 1.2) * g), ink)
	ci.draw_rect(Rect2(c + Vector2(-0.1, 0.35) * g, Vector2(1.0, 0.5) * g), ink)
	ci.draw_circle(c + Vector2(0.9, 0.6) * g, g * 0.25, ink)
	var w: float = maxf(1.0, g * 0.15)
	ci.draw_line(c + Vector2(-0.15, -0.35) * g, c + Vector2(-0.95, -0.85) * g, ink, w)
	ci.draw_line(c + Vector2(-0.15, -0.1) * g, c + Vector2(-0.95, -0.4) * g, ink, w)
	ci.draw_line(c + Vector2(-0.15, 0.15) * g, c + Vector2(-0.85, 0.05) * g, ink, w)


## Hawkeye: a hawk's eye inside a crosshair, ticks round it.
static func _eye(ci: CanvasItem, c: Vector2, g: float, ink: Color, face: Color, detail: bool) -> void:
	var w: float = maxf(1.0, g * 0.12)
	if detail:
		ci.draw_arc(c, g * 0.92, 0.0, TAU, 28, ink, w)
		for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			ci.draw_line(c + d * g * 0.78, c + d * g * 1.1, ink, w)
	var lens: PackedVector2Array = []
	var steps: int = 7
	for i: int in steps + 1:
		var t: float = float(i) / float(steps)
		lens.append(c + Vector2(lerpf(-0.68, 0.68, t), -0.42 * sin(PI * t)) * g)
	for i2: int in steps - 1:
		var t2: float = 1.0 - float(i2 + 1) / float(steps)
		lens.append(c + Vector2(lerpf(-0.68, 0.68, t2), 0.42 * sin(PI * t2)) * g)
	ci.draw_colored_polygon(lens, ink)
	ci.draw_circle(c, g * 0.22, face)
	ci.draw_circle(c, g * 0.09, ink)


## Packmule: Ammer's mule, head in profile, three rifle lines fanning behind it.
static func _mule(ci: CanvasItem, c: Vector2, g: float, ink: Color, face: Color, detail: bool) -> void:
	var w: float = maxf(1.0, g * 0.09)
	ci.draw_line(c + Vector2(-0.15, 0.35) * g, c + Vector2(-0.95, -0.75) * g, ink, w)
	ci.draw_line(c + Vector2(-0.15, 0.35) * g, c + Vector2(-1.0, -0.2) * g, ink, w)
	ci.draw_line(c + Vector2(-0.15, 0.35) * g, c + Vector2(-0.95, 0.35) * g, ink, w)
	ci.draw_colored_polygon(_pts(c, g, [Vector2(-0.22, 0.1), Vector2(0.25, 0.15), Vector2(0.1, 0.9), Vector2(-0.45, 0.85)]), ink)
	ci.draw_circle(c + Vector2(0.1, -0.08) * g, g * 0.36, ink)
	_capsule(ci, c, g, Vector2(0.15, 0.0), Vector2(0.68, 0.32), 0.24, ink)
	_capsule(ci, c, g, Vector2(0.0, -0.3), Vector2(-0.28, -0.95), 0.12, ink)
	_capsule(ci, c, g, Vector2(0.2, -0.32), Vector2(0.12, -1.0), 0.12, ink)
	if detail:
		ci.draw_circle(c + Vector2(0.22, -0.14) * g, g * 0.07, face)
		ci.draw_circle(c + Vector2(0.72, 0.3) * g, g * 0.05, face)


## Blastproof: the Pionierschule's ram's head over a starburst.
static func _ram_burst(ci: CanvasItem, c: Vector2, g: float, ink: Color, ink2: Color, detail: bool) -> void:
	# the burst (the other tone): a disc and eight spikes
	ci.draw_circle(c, g * 0.46, ink2)
	for i: int in 8:
		var a: float = TAU * float(i) / 8.0 + PI / 8.0
		var dir: Vector2 = Vector2(cos(a), sin(a))
		var perp: Vector2 = Vector2(-dir.y, dir.x) * 0.15
		ci.draw_colored_polygon(PackedVector2Array([c + (dir * 0.3 + perp) * g, c + dir * g * 1.0, c + (dir * 0.3 - perp) * g]), ink2)
	# the ram: a face with two curled horns
	ci.draw_colored_polygon(_pts(c, g, [Vector2(-0.3, -0.3), Vector2(0.3, -0.3), Vector2(0.24, 0.3), Vector2(0.0, 0.55), Vector2(-0.24, 0.3)]), ink)
	var w: float = maxf(1.2, g * 0.15)
	ci.draw_arc(c + Vector2(-0.4, -0.22) * g, g * 0.3, PI * 1.55, PI * 2.95, 10, ink, w)
	ci.draw_arc(c + Vector2(0.4, -0.22) * g, g * 0.3, PI * 0.05, PI * 1.45, 10, ink, w)
	if detail:
		ci.draw_circle(c + Vector2(-0.12, -0.05) * g, g * 0.06, ink2)
		ci.draw_circle(c + Vector2(0.12, -0.05) * g, g * 0.06, ink2)


## Overclock: the friend's robot: a copper lightning bolt and two round eyes, over a cog. The cog is a disc plus
## eight convex tooth quads (one concave outline can fail to triangulate at nameplate size).
static func _cog_bolt(ci: CanvasItem, c: Vector2, g: float, ink: Color, ink2: Color, face: Color, copper: Color, detail: bool) -> void:
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
	ci.draw_circle(c, g * 0.52, face)
	ci.draw_colored_polygon(_pts(c, g, [Vector2(0.12, -0.82), Vector2(0.4, -0.82), Vector2(0.06, -0.02), Vector2(-0.3, -0.02)]), copper)
	ci.draw_colored_polygon(_pts(c, g, [Vector2(-0.04, -0.12), Vector2(0.3, -0.12), Vector2(-0.12, 0.82), Vector2(-0.4, 0.82)]), copper)
	if detail:
		for x: float in [-0.5, 0.5]:
			ci.draw_circle(c + Vector2(x, 0.4) * g, g * 0.14, ink2)
			ci.draw_circle(c + Vector2(x, 0.4) * g, g * 0.07, ink)


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
