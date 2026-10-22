class_name PaperDecor
extends Node3D
## Paper set dressing with something drawn on it (Update 02 section 8, T-053): a sheet whose picture is painted
## into a small texture at load time (cached per kind, so the .tscn only stores the kind), plus a line or two of
## text where a hand wrote on it. Decorative, not readable items (those are StoryProp): no prompt, no collision.
##   calendar      the inn's wall calendar on December 1944, the days crossed off to the 22nd, the 24th ringed
##   map           the patrol's map sheet: roads, the rail line, the river, woods, the crossroads marked, and a
##                 red pencil circle round Kaltenbrunn
##   freq_notes    Käthe's slips by the wireless: frequencies and times in pencil
##   drawing_inn   a child's crayon drawing from the cousins' summers: the inn, the sun, three girls and their aunt
##   drawing_horse a child's drawing of the inn's horse in its stall
##   drawing_jam   a child's drawing of a girl on tiptoe reaching for the jam on the top shelf
## Frame: the sheet lies in the node's local XY plane facing -Z (hang it on a wall like a StoryProp wall item), or
## flat when `flat` (lying on a table, face up, its top edge toward +Z).

const KINDS: Dictionary = {
	# kind: [width, height, text, text colour, text position (fraction of the sheet, from the top-left), font size]
	"calendar": [0.34, 0.46, "DEZEMBER 1944", Color(0.12, 0.1, 0.09), Vector2(0.5, 0.12), 34],
	"map": [0.62, 0.46, "Kaltenbrunn", Color(0.6, 0.12, 0.08), Vector2(0.72, 0.3), 26],
	"freq_notes": [0.13, 0.17, "Beromünster 556\nBreslau 950\n\"Das Mädchen\"\n23 Uhr ??", Color(0.2, 0.19, 0.22), Vector2(0.5, 0.45), 15],
	"drawing_inn": [0.3, 0.22, "Sommer 1931 · Tante Lene", Color(0.2, 0.25, 0.55), Vector2(0.5, 0.9), 15],
	"drawing_horse": [0.28, 0.21, "Fanny", Color(0.55, 0.15, 0.12), Vector2(0.24, 0.12), 20],
	"drawing_jam": [0.2, 0.27, "Marmelade!", Color(0.5, 0.12, 0.1), Vector2(0.5, 0.1), 17],
}

@export var kind: String = "calendar"
@export var flat: bool = false
@export var tilt_deg: float = 0.0

static var _tex: Dictionary = {}
static var _hand: SystemFont
static var _print: SystemFont


func _ready() -> void:
	var k: Array = KINDS.get(kind, KINDS["calendar"])
	var w: float = float(k[0])
	var h: float = float(k[1])
	var root: Node3D = Node3D.new()
	root.name = "Sheet"
	root.rotation_degrees = Vector3(90.0 if flat else 0.0, 0.0, tilt_deg)
	root.position = Vector3(0, 0.002, 0) if flat else Vector3(0, 0, -0.004)
	add_child(root)
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(w, h)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Paper"
	mi.mesh = q
	mi.rotation.y = PI   # the quad faces +Z; the sheet's face is -Z
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_texture = texture(kind)
	m.roughness = 0.95
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var text: String = str(k[2])
	if text != "":
		var l: Label3D = Label3D.new()
		l.text = text
		l.font = _font(kind)
		l.font_size = int(k[5])
		l.pixel_size = 0.0011 if kind != "map" else 0.0012
		l.modulate = k[3]
		l.outline_size = 0
		l.double_sided = false
		var tp: Vector2 = k[4]
		l.position = Vector3((tp.x - 0.5) * w, (0.5 - tp.y) * h, -0.002)
		l.rotation.y = PI
		l.shaded = true
		if kind == "map":
			l.rotation.z = deg_to_rad(-4.0)
		root.add_child(l)


static func _font(k: String) -> Font:
	if k == "calendar":
		if _print == null:
			_print = SystemFont.new()
			_print.font_names = PackedStringArray(["Georgia", "Times New Roman", "Serif"])
		return _print
	if _hand == null:
		_hand = SystemFont.new()
		_hand.font_names = PackedStringArray(["Segoe Print", "Segoe Script", "Comic Sans MS", "Bradley Hand", "Cursive"])
	return _hand


## The cached picture for a kind.
static func texture(k: String) -> ImageTexture:
	if _tex.has(k):
		return _tex[k]
	var img: Image
	match k:
		"calendar":
			img = _calendar()
		"map":
			img = _map()
		"freq_notes":
			img = _paper(64, 84, Color(0.86, 0.82, 0.7), 41)
			for y: int in range(14, 84, 9):
				_line(img, Vector2(4, y), Vector2(60, y), Color(0.55, 0.62, 0.75, 0.6), 1.0)
		"drawing_inn":
			img = _drawing_inn()
		"drawing_horse":
			img = _drawing_horse()
		"drawing_jam":
			img = _drawing_jam()
		_:
			img = _paper(64, 64, Color(0.86, 0.82, 0.7), 3)
	img.generate_mipmaps()
	var t: ImageTexture = ImageTexture.create_from_image(img)
	_tex[k] = t
	return t


# ================================================================== the pictures

static func _calendar() -> Image:
	var img: Image = _paper(136, 184, Color(0.88, 0.85, 0.76), 1944)
	_rect(img, Rect2i(0, 0, 136, 9), Color(0.55, 0.13, 0.1))            # the printed header band
	_rect(img, Rect2i(8, 30, 120, 1), Color(0.3, 0.27, 0.24))
	# Mo..So header ticks and the grid: 1 December 1944 was a Friday (column 4, Monday = 0)
	var x0: int = 8
	var y0: int = 40
	var cw: int = 17
	var ch: int = 22
	for c: int in 8:
		_rect(img, Rect2i(x0 + c * cw, y0 - 6, 1, ch * 6 + 6), Color(0.45, 0.42, 0.38, 0.7))
	for r: int in 7:
		_rect(img, Rect2i(x0, y0 - 6 + r * ch, cw * 7 + 1, 1), Color(0.45, 0.42, 0.38, 0.7))
	_rect(img, Rect2i(x0 + 6 * cw + 1, y0 - 5, cw - 1, ch * 6 - 1), Color(0.75, 0.2, 0.15, 0.12))   # Sundays
	for day: int in range(1, 32):
		var cell: int = day + 3   # Friday the 1st
		var col: int = cell % 7
		var row: int = cell / 7
		var px: int = x0 + col * cw + 3
		var py: int = y0 - 3 + row * ch
		_digits(img, str(day), Vector2i(px, py), 2, Color(0.75, 0.15, 0.12) if col == 6 else Color(0.15, 0.13, 0.12))
		if day <= 22:   # crossed off in pencil
			_line(img, Vector2(px - 2, py - 1), Vector2(px + cw - 4, py + ch - 6), Color(0.25, 0.25, 0.3, 0.85), 1.2)
			_line(img, Vector2(px + cw - 4, py - 1), Vector2(px - 2, py + ch - 6), Color(0.25, 0.25, 0.3, 0.85), 1.2)
		if day == 24:   # Christmas Eve ringed
			_ring(img, Vector2(px + 5, py + 6), 9.0, Color(0.7, 0.12, 0.1, 0.9), 1.5)
	# a nail hole and a fold at the top
	_disc(img, Vector2(68, 4), 2.0, Color(0.1, 0.08, 0.06))
	return img


static func _map() -> Image:
	var img: Image = _paper(248, 184, Color(0.84, 0.81, 0.68), 1945)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 23
	# woods: green-grey blots
	for i: int in 26:
		var c: Vector2 = Vector2(rng.randf_range(8, 240), rng.randf_range(8, 176))
		for j: int in 5:
			_disc(img, c + Vector2(rng.randf_range(-9, 9), rng.randf_range(-7, 7)), rng.randf_range(4, 9), Color(0.45, 0.55, 0.38, 0.35))
	# the grid squares of the sheet
	for gx: int in range(0, 248, 40):
		_rect(img, Rect2i(gx, 0, 1, 184), Color(0.4, 0.45, 0.6, 0.35))
	for gy: int in range(0, 184, 40):
		_rect(img, Rect2i(0, gy, 248, 1), Color(0.4, 0.45, 0.6, 0.35))
	# the river and the stream
	var river: PackedVector2Array = [Vector2(0, 150), Vector2(40, 140), Vector2(80, 152), Vector2(130, 138), Vector2(170, 150), Vector2(248, 132)]
	_poly(img, river, Color(0.25, 0.4, 0.7, 0.85), 2.2)
	# roads: the crossroads (Kreuzweg) at about (70, 70); the road on to Kaltenbrunn, south-east
	var kreuz: Vector2 = Vector2(70, 72)
	var kalt: Vector2 = Vector2(182, 112)
	_poly(img, [Vector2(0, 66), kreuz, Vector2(248, 58)], Color(0.55, 0.3, 0.15, 0.9), 2.0)
	_poly(img, [Vector2(64, 0), kreuz, Vector2(76, 184)], Color(0.55, 0.3, 0.15, 0.9), 2.0)
	_poly(img, [kreuz, Vector2(110, 86), Vector2(150, 96), kalt], Color(0.55, 0.3, 0.15, 0.9), 1.6)
	# the rail line to the works: black ticked
	var rail: PackedVector2Array = [Vector2(248, 96), Vector2(210, 104), kalt, Vector2(176, 150), Vector2(160, 184)]
	_poly(img, rail, Color(0.1, 0.1, 0.1, 0.9), 1.4)
	for i: int in range(rail.size() - 1):
		var a: Vector2 = rail[i]
		var b: Vector2 = rail[i + 1]
		var n: Vector2 = (b - a).normalized().orthogonal() * 2.5
		var steps: int = int(a.distance_to(b) / 7.0)
		for s: int in steps:
			var p: Vector2 = a.lerp(b, (float(s) + 0.5) / float(maxi(1, steps)))
			_line(img, p - n, p + n, Color(0.1, 0.1, 0.1, 0.9), 1.0)
	# villages: little black blocks; Kaltenbrunn bigger, with the works' chimneys
	for v: Vector2 in [Vector2(30, 40), Vector2(214, 30), Vector2(120, 160), Vector2(36, 120)]:
		_rect(img, Rect2i(int(v.x), int(v.y), 6, 5), Color(0.12, 0.1, 0.1))
	_rect(img, Rect2i(int(kalt.x) - 7, int(kalt.y) - 5, 14, 10), Color(0.12, 0.1, 0.1))
	_rect(img, Rect2i(int(kalt.x) + 9, int(kalt.y) - 6, 7, 4), Color(0.12, 0.1, 0.1))
	# the inn: a cross at the crossroads, pencilled
	_line(img, kreuz + Vector2(-5, -5), kreuz + Vector2(5, 5), Color(0.2, 0.2, 0.25), 1.3)
	_line(img, kreuz + Vector2(5, -5), kreuz + Vector2(-5, 5), Color(0.2, 0.2, 0.25), 1.3)
	# the red pencil: a hard circle round Kaltenbrunn, gone round twice, and an arrow from the road
	_ring(img, kalt + Vector2(2, 0), 21.0, Color(0.72, 0.1, 0.08, 0.95), 1.8)
	_ring(img, kalt + Vector2(3, 1), 23.0, Color(0.72, 0.1, 0.08, 0.7), 1.2)
	_poly(img, [Vector2(120, 70), Vector2(150, 80), Vector2(162, 92)], Color(0.72, 0.1, 0.08, 0.85), 1.4)
	_line(img, Vector2(162, 92), Vector2(155, 91), Color(0.72, 0.1, 0.08, 0.85), 1.4)
	_line(img, Vector2(162, 92), Vector2(160, 85), Color(0.72, 0.1, 0.08, 0.85), 1.4)
	# fold lines
	_rect(img, Rect2i(124, 0, 1, 184), Color(0.5, 0.46, 0.38, 0.45))
	_rect(img, Rect2i(0, 92, 248, 1), Color(0.5, 0.46, 0.38, 0.45))
	return img


static func _drawing_inn() -> Image:
	var img: Image = _paper(160, 118, Color(0.9, 0.88, 0.8), 1931)
	var crayon: Color = Color(0.5, 0.25, 0.12)
	# the sun with rays
	_disc(img, Vector2(136, 20), 9.0, Color(0.95, 0.75, 0.15, 0.9))
	for i: int in 8:
		var a: float = TAU * float(i) / 8.0
		_line(img, Vector2(136, 20) + Vector2(cos(a), sin(a)) * 12.0, Vector2(136, 20) + Vector2(cos(a), sin(a)) * 18.0, Color(0.95, 0.7, 0.1), 1.6)
	# the inn: walls, a roof, windows, a door, smoke from the chimney
	_box_outline(img, Rect2(22, 46, 64, 44), crayon, 1.8)
	_poly(img, [Vector2(16, 48), Vector2(54, 22), Vector2(92, 48)], Color(0.7, 0.2, 0.12), 2.2)
	_rect(img, Rect2i(66, 24, 7, 14), Color(0.4, 0.38, 0.36))
	for i: int in 4:
		_ring(img, Vector2(72 + i * 5, 18 - i * 5), 3.0 + i, Color(0.55, 0.55, 0.6, 0.8), 1.0)
	_box_outline(img, Rect2(30, 56, 10, 9), Color(0.2, 0.3, 0.6), 1.4)
	_box_outline(img, Rect2(66, 56, 10, 9), Color(0.2, 0.3, 0.6), 1.4)
	_box_outline(img, Rect2(48, 70, 11, 20), crayon, 1.6)
	# the grass
	_line(img, Vector2(2, 92), Vector2(158, 94), Color(0.3, 0.6, 0.2), 2.4)
	# three girls and their aunt beside the inn (stick figures, the aunt tallest, in her apron)
	var figs: Array = [[100.0, 72.0, Color(0.75, 0.2, 0.15)], [112.0, 76.0, Color(0.2, 0.45, 0.7)], [124.0, 74.0, Color(0.35, 0.55, 0.25)], [140.0, 62.0, Color(0.3, 0.3, 0.6)]]
	for f: Array in figs:
		_stick(img, Vector2(float(f[0]), float(f[1])), 92.0 - float(f[1]), f[2])
	_rect(img, Rect2i(137, 74, 7, 10), Color(0.85, 0.85, 0.95, 0.9))   # the apron
	return img


static func _drawing_horse() -> Image:
	var img: Image = _paper(150, 112, Color(0.9, 0.87, 0.78), 1932)
	var brown_: Color = Color(0.45, 0.28, 0.14)
	# the stall's boards
	for y: int in range(30, 100, 14):
		_line(img, Vector2(6, y), Vector2(144, y + 2), Color(0.65, 0.5, 0.3, 0.6), 1.2)
	# a body, a neck, a head, four legs, a mane and a tail
	_ellipse_fill(img, Vector2(70, 58), Vector2(30, 14), Color(0.55, 0.35, 0.18, 0.9))
	_poly(img, [Vector2(94, 52), Vector2(108, 30)], brown_, 6.0)
	_ellipse_fill(img, Vector2(114, 28), Vector2(11, 6), Color(0.55, 0.35, 0.18, 0.95))
	_disc(img, Vector2(117, 25), 1.5, Color(0.05, 0.05, 0.05))
	for lx: float in [50.0, 60.0, 82.0, 92.0]:
		_line(img, Vector2(lx, 66), Vector2(lx + 1, 92), brown_, 2.4)
	for i: int in 6:
		_line(img, Vector2(96 + i * 2, 46 - i * 3), Vector2(90 + i * 2, 44 - i * 3), Color(0.2, 0.12, 0.06), 1.4)
	_poly(img, [Vector2(40, 54), Vector2(30, 66), Vector2(32, 80)], Color(0.2, 0.12, 0.06), 2.0)
	# hay at its feet, a heart over it
	for i: int in 12:
		_line(img, Vector2(36 + i * 7, 96), Vector2(40 + i * 7, 88), Color(0.85, 0.7, 0.25), 1.4)
	_disc(img, Vector2(66, 22), 4.0, Color(0.85, 0.2, 0.2))
	_disc(img, Vector2(73, 22), 4.0, Color(0.85, 0.2, 0.2))
	_poly(img, [Vector2(62, 24), Vector2(69.5, 33), Vector2(77, 24)], Color(0.85, 0.2, 0.2), 3.0)
	return img


static func _drawing_jam() -> Image:
	var img: Image = _paper(108, 146, Color(0.9, 0.87, 0.78), 1933)
	# shelves, jars of jam on the top one
	for y: int in [40, 78, 112]:
		_line(img, Vector2(10, y), Vector2(98, y), Color(0.5, 0.32, 0.16), 2.2)
	for jx: float in [30.0, 46.0, 62.0]:
		_rect(img, Rect2i(int(jx), 26, 10, 13), Color(0.7, 0.12, 0.1, 0.9))
		_rect(img, Rect2i(int(jx) - 1, 24, 12, 3), Color(0.9, 0.9, 0.85))
	# the girl on tiptoe, one arm stretched right up to the jar (a long, long arm: it was the family joke)
	var c: Color = Color(0.25, 0.4, 0.7)
	_ring(img, Vector2(70, 84), 6.0, c, 1.6)
	_line(img, Vector2(70, 90), Vector2(70, 116), c, 1.8)
	_line(img, Vector2(70, 116), Vector2(64, 136), c, 1.6)
	_line(img, Vector2(70, 116), Vector2(76, 136), c, 1.6)
	_line(img, Vector2(70, 96), Vector2(56, 34), c, 1.6)
	_line(img, Vector2(70, 96), Vector2(82, 106), c, 1.6)
	_poly(img, [Vector2(62, 104), Vector2(70, 98), Vector2(78, 104), Vector2(80, 120), Vector2(60, 120), Vector2(62, 104)], Color(0.75, 0.2, 0.2, 0.8), 1.6)
	return img


static func _stick(img: Image, top: Vector2, h: float, c: Color) -> void:
	var r: float = h * 0.13
	_ring(img, top + Vector2(0, r), r, c, 1.4)
	var neck: Vector2 = top + Vector2(0, r * 2.0)
	var hip: Vector2 = neck + Vector2(0, h * 0.4)
	_line(img, neck, hip, c, 1.5)
	_poly(img, [hip + Vector2(-h * 0.14, 0), neck + Vector2(0, h * 0.02), hip + Vector2(h * 0.14, 0), hip + Vector2(-h * 0.14, 0)], c, 1.4)   # a dress
	_line(img, hip, top + Vector2(-h * 0.08, h), c, 1.4)
	_line(img, hip, top + Vector2(h * 0.08, h), c, 1.4)
	_line(img, neck + Vector2(0, h * 0.08), neck + Vector2(-h * 0.22, h * 0.25), c, 1.3)
	_line(img, neck + Vector2(0, h * 0.08), neck + Vector2(h * 0.22, h * 0.25), c, 1.3)


# ================================================================== raster helpers

static func _paper(w: int, h: int, tone: Color, seed_v: int) -> Image:
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var n: FastNoiseLite = FastNoiseLite.new()
	n.seed = seed_v
	n.frequency = 0.05
	for y: int in h:
		for x: int in w:
			var k: float = n.get_noise_2d(x, y) * 0.06
			var edge: float = minf(minf(x, w - 1 - x), minf(y, h - 1 - y))
			var age: float = 0.08 * clampf(1.0 - edge / 6.0, 0.0, 1.0)   # darker, foxed edges
			img.set_pixel(x, y, Color(tone.r + k - age, tone.g + k - age * 1.1, tone.b + k * 0.8 - age * 1.4, 1.0))
	return img


static func _blend(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	var d: Color = img.get_pixel(x, y)
	img.set_pixel(x, y, Color(lerpf(d.r, c.r, c.a), lerpf(d.g, c.g, c.a), lerpf(d.b, c.b, c.a), 1.0))


static func _rect(img: Image, r: Rect2i, c: Color) -> void:
	for y: int in range(r.position.y, r.end.y):
		for x: int in range(r.position.x, r.end.x):
			_blend(img, x, y, c)


static func _disc(img: Image, c0: Vector2, r: float, c: Color) -> void:
	_ellipse_fill(img, c0, Vector2(r, r), c)


static func _ellipse_fill(img: Image, c0: Vector2, r: Vector2, c: Color) -> void:
	for y: int in range(int(c0.y - r.y) - 1, int(c0.y + r.y) + 2):
		for x: int in range(int(c0.x - r.x) - 1, int(c0.x + r.x) + 2):
			var d: float = Vector2((x + 0.5 - c0.x) / r.x, (y + 0.5 - c0.y) / r.y).length()
			if d <= 1.0:
				_blend(img, x, y, c)


static func _line(img: Image, a: Vector2, b: Vector2, c: Color, width: float) -> void:
	var steps: int = maxi(1, int(a.distance_to(b) * 2.0))
	var r: float = width * 0.5
	for i: int in steps + 1:
		var p: Vector2 = a.lerp(b, float(i) / float(steps))
		for y: int in range(int(p.y - r), int(p.y + r) + 1):
			for x: int in range(int(p.x - r), int(p.x + r) + 1):
				if Vector2(x + 0.5, y + 0.5).distance_to(p) <= r + 0.35:
					_blend(img, x, y, Color(c, c.a * 0.35))   # overlapping dabs build up, like pencil or crayon


static func _poly(img: Image, pts: PackedVector2Array, c: Color, width: float) -> void:
	for i: int in range(pts.size() - 1):
		_line(img, pts[i], pts[i + 1], c, width)


static func _ring(img: Image, c0: Vector2, r: float, c: Color, width: float) -> void:
	var steps: int = maxi(12, int(r * 3.0))
	for i: int in steps:
		var a0: float = TAU * float(i) / float(steps)
		var a1: float = TAU * float(i + 1) / float(steps)
		var wob0: float = 1.0 + 0.04 * sin(a0 * 3.0)
		var wob1: float = 1.0 + 0.04 * sin(a1 * 3.0)
		_line(img, c0 + Vector2(cos(a0), sin(a0)) * r * wob0, c0 + Vector2(cos(a1), sin(a1)) * r * wob1, c, width)


static func _box_outline(img: Image, r: Rect2, c: Color, width: float) -> void:
	_poly(img, [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position], c, width)


## 3 x 5 pixel digits, drawn `scale` times, for printed numbers.
const DIGITS: Array = ["111101101101111", "010110010010111", "111001111100111", "111001111001111", "101101111001001",
	"111100111001111", "111100111101111", "111001010010010", "111101111101111", "111101111001111"]


static func _digits(img: Image, s: String, at: Vector2i, scale: int, c: Color) -> void:
	var x: int = at.x
	for ch: String in s:
		var d: int = ch.unicode_at(0) - 48
		if d < 0 or d > 9:
			x += 4 * scale
			continue
		var bits: String = DIGITS[d]
		for row: int in 5:
			for col: int in 3:
				if bits[row * 3 + col] == "1":
					_rect(img, Rect2i(x + col * scale, at.y + row * scale, scale, scale), c)
		x += 4 * scale
