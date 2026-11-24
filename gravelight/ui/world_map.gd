class_name WorldMap
extends Control
## T-270 (the owner: "somehow make it feel like all the maps are just one for one ultimate map"): the Solo page's
## map step as ONE drawn sheet, a paper war map on which the seven maps are seven places on one route:
##   Crossroads Inn (Silesia) > Kaltenbrunn (the salt mine) > Totenhafen (the Baltic pens) > Werk Thalbach
##   > Der Kranich (in flight over the Atlantic) > Groom Lake (Nevada) > Mondlicht (the Moon, in an inset).
## The seven places are Buttons (children of the node "MapCards", in story order, each with the metas the old cards
## had: map_id, egg, best), so the keyboard, the mouse and a controller use them like any other menu control. A
## locked place takes the focus (its unlock rule shows in the side panel) but cannot be pressed.
## Everything on the sheet is drawn here in code (no texture, nothing downloaded): the coasts are rough shapes, not
## a survey, and the sheet says "not to scale".
## The sheet runs east to west like the story, so LEFT is onward and RIGHT is back; UP / DOWN follow the route where
## it runs up or down (Kaltenbrunn - Totenhafen, Groom Lake - the Moon) and otherwise leave the sheet for the row
## above or below it (`neighbour`). Tab order is story order.
## Table data (names, dates, unlock wording, eggs, previews) is MapCards'; progress is ProfileSave's.

signal place_focused(map_id: String)

## The layout was drawn for this size; `point` scales with the control.
const REF: Vector2 = Vector2(1300.0, 600.0)
## [map id, where on the sheet (0..1), where its name plate sits]. Story order; x falls with every step.
const PLACES: Array = [
	["map00_crossroads", Vector2(0.90, 0.48), "below"],
	["map01_kaltenbrunn", Vector2(0.80, 0.70), "below"],
	["map02_totenhafen", Vector2(0.725, 0.31), "below"],
	["map04a_thalbach", Vector2(0.655, 0.55), "below"],
	["map04b_kranich", Vector2(0.39125, 0.4175), "below"],
	["map04c_groomlake", Vector2(0.13, 0.60), "below"],
	["map04d_mondlicht", Vector2(0.10, 0.13), "right"],
]
## How leg i (place i to place i + 1) is travelled.
const LEGS: PackedStringArray = ["road", "road", "road", "air", "air", "rocket"]
const LEG_WORDS: Dictionary = {"road": "by road and rail", "air": "by air", "rocket": "by rocket"}
## The Atlantic crossing is one curve from Werk Thalbach to Groom Lake; the Kranich sits at its middle.
const FLIGHT_CTRL: Vector2 = Vector2(0.39, 0.26)
const ROCKET_CTRL: Vector2 = Vector2(0.21, 0.40)
const PLATE: Vector2 = Vector2(250.0, 74.0)
const PLATE_GAP: float = 28.0
const NODE_R: float = 15.0
const MOON_R: float = 26.0
## A route neighbour counts as "up" or "down" when it is at least this steep (|dy| / |dx| on the reference sheet).
const VERTICAL_SLOPE: float = 0.6

const PAPER_C: Color = Color(0.86, 0.81, 0.69)
const SEA_C: Color = Color(0.74, 0.76, 0.70)
const LAND_C: Color = Color(0.87, 0.82, 0.68)
const INK_BROWN: Color = Color(0.36, 0.25, 0.16)
const NIGHT_C: Color = Color(0.05, 0.06, 0.11)

## Rough coasts (0..1 of the sheet; points past the edge keep the rounding off the sheet).
const LAND: Array = [
	# the continent
	[Vector2(1.06, 0.13), Vector2(1.06, 1.06), Vector2(0.95, 1.06), Vector2(0.93, 0.93), Vector2(0.885, 0.86), Vector2(0.855, 0.80),
		Vector2(0.835, 0.84), Vector2(0.855, 0.93), Vector2(0.875, 1.06), Vector2(0.82, 1.06), Vector2(0.80, 0.95), Vector2(0.765, 0.865),
		Vector2(0.72, 0.85), Vector2(0.675, 0.885), Vector2(0.655, 0.95), Vector2(0.66, 1.06), Vector2(0.50, 1.06), Vector2(0.505, 0.93),
		Vector2(0.52, 0.86), Vector2(0.575, 0.845), Vector2(0.59, 0.80), Vector2(0.58, 0.70), Vector2(0.545, 0.655), Vector2(0.535, 0.615),
		Vector2(0.575, 0.60), Vector2(0.60, 0.565), Vector2(0.615, 0.50), Vector2(0.64, 0.445), Vector2(0.665, 0.40), Vector2(0.675, 0.345),
		Vector2(0.672, 0.25), Vector2(0.68, 0.17), Vector2(0.70, 0.16), Vector2(0.705, 0.24), Vector2(0.71, 0.30), Vector2(0.74, 0.315),
		Vector2(0.79, 0.30), Vector2(0.84, 0.275), Vector2(0.875, 0.22), Vector2(0.89, 0.15), Vector2(0.92, 0.10), Vector2(0.97, 0.09)],
	# the north
	[Vector2(0.70, -0.06), Vector2(0.705, 0.05), Vector2(0.72, 0.12), Vector2(0.745, 0.19), Vector2(0.765, 0.205), Vector2(0.78, 0.15),
		Vector2(0.80, 0.08), Vector2(0.83, 0.04), Vector2(0.86, -0.06)],
	# the islands
	[Vector2(0.555, 0.475), Vector2(0.585, 0.455), Vector2(0.578, 0.40), Vector2(0.568, 0.33), Vector2(0.58, 0.25), Vector2(0.572, 0.17),
		Vector2(0.555, 0.11), Vector2(0.535, 0.14), Vector2(0.545, 0.22), Vector2(0.53, 0.30), Vector2(0.54, 0.37), Vector2(0.52, 0.43),
		Vector2(0.51, 0.475)],
	[Vector2(0.497, 0.40), Vector2(0.507, 0.33), Vector2(0.492, 0.27), Vector2(0.473, 0.30), Vector2(0.468, 0.37), Vector2(0.48, 0.41)],
	# the far shore
	[Vector2(-0.06, -0.06), Vector2(0.20, -0.06), Vector2(0.235, 0.06), Vector2(0.27, 0.17), Vector2(0.305, 0.245), Vector2(0.295, 0.30),
		Vector2(0.262, 0.33), Vector2(0.255, 0.39), Vector2(0.272, 0.44), Vector2(0.252, 0.50), Vector2(0.238, 0.58), Vector2(0.222, 0.66),
		Vector2(0.215, 0.74), Vector2(0.232, 0.85), Vector2(0.22, 0.90), Vector2(0.205, 0.82), Vector2(0.19, 0.755), Vector2(0.155, 0.765),
		Vector2(0.125, 0.81), Vector2(0.11, 0.90), Vector2(0.10, 1.06), Vector2(-0.06, 1.06)],
]
## Faint names on the sheet: [text, where (0..1), size].
const NAMES: Array = [
	["ATLANTIC  OCEAN", Vector2(0.40, 0.69), 22],
	["BALTIC  SEA", Vector2(0.805, 0.245), 14],
	["SILESIA", Vector2(0.90, 0.405), 15],
	["NEVADA", Vector2(0.058, 0.53), 15],
	["NORTH  SEA", Vector2(0.625, 0.27), 13],
]

var buttons: Array[Button] = []
var selected: int = -1
var _states: Array[Dictionary] = []
var _paper: Control = null
var _marks: Control = null
var _ring: Control = null
var _holder: Control = null
var _above: Control = null
var _below: Control = null
var _ring_placed: bool = false


# ================================================================== the pure parts

static func order() -> PackedStringArray:
	var out: PackedStringArray = []
	for p: Array in PLACES:
		out.append(str(p[0]))
	return out


static func index_of(map_id: String) -> int:
	return order().find(map_id)


## Where place `i` is on a sheet of `size` (pixels).
static func point(i: int, size_px: Vector2 = REF) -> Vector2:
	return (PLACES[i][1] as Vector2) * size_px


## The place the focus goes to from place `i` on a press towards `dir` (LEFT / RIGHT / UP / DOWN as a unit
## Vector2i), or -1: LEFT / RIGHT at an end of the route stay put, UP / DOWN leave the sheet for the row above or
## below. LEFT is always the next place of the story and RIGHT the one before (x falls along the route); UP / DOWN
## take the steeper of the two route neighbours on that side, if either is steep enough.
static func neighbour(i: int, dir: Vector2i) -> int:
	var n: int = PLACES.size()
	if i < 0 or i >= n:
		return -1
	if dir.x != 0:
		var j: int = i + (1 if dir.x < 0 else -1)
		return j if j >= 0 and j < n else -1
	var best: int = -1
	var best_slope: float = VERTICAL_SLOPE
	for j: int in [i - 1, i + 1]:
		if j < 0 or j >= n:
			continue
		var d: Vector2 = point(j) - point(i)
		if signf(d.y) != float(dir.y):
			continue
		var slope: float = absf(d.y) / maxf(absf(d.x), 0.001)
		if slope >= best_slope:
			best_slope = slope
			best = j
	return best


## What a place shows, from the table and the three profile facts (pure).
static func state(map_id: String, unlocked: bool, best: int, egg: String) -> Dictionary:
	var r: Dictionary = MapCards.row(map_id)
	var egg_text: String = "NO EGG"
	if egg == "done":
		egg_text = "EGG  DONE"
	elif egg == "not done":
		egg_text = "EGG  NOT DONE"
	return {"id": map_id, "stop": index_of(map_id) + 1, "name": str(r.get("name", map_id)), "kicker": str(r.get("kicker", "")),
		"date": str(r.get("date", "")), "unlock": str(r.get("unlock", "")), "locked": not unlocked, "best": best, "egg": egg,
		"best_text": "BEST ROUND  " + (str(best) if best > 0 else "—"), "egg_text": egg_text}


## The same from the profile on disk (what the cards read).
static func profile_state(map_id: String) -> Dictionary:
	return state(map_id, ProfileSave.is_map_unlocked(StringName(map_id)), ProfileSave.best_round(StringName(map_id)),
		MapCards.egg_status(map_id))


## Which legs are drawn as travelled: both ends open (pure). `open[i]` = place i is unlocked.
static func legs_travelled(open: Array) -> Array[bool]:
	var out: Array[bool] = []
	for i: int in LEGS.size():
		out.append(i + 1 < open.size() and bool(open[i]) and bool(open[i + 1]))
	return out


## The first open place (the one under the focus when the page opens), 0 if none.
static func first_open(open: Array) -> int:
	for i: int in open.size():
		if bool(open[i]):
			return i
	return 0


static func leg_words(i: int) -> String:
	return str(LEG_WORDS.get(LEGS[i], "")) if i >= 0 and i < LEGS.size() else ""


static func _bezier(a: Vector2, c: Vector2, b: Vector2, t: float) -> Vector2:
	return a.lerp(c, t).lerp(c.lerp(b, t), t)


## Leg `i` as a line of points on a sheet of `size_px`.
static func leg_points(i: int, size_px: Vector2 = REF, steps: int = 24) -> PackedVector2Array:
	var out: PackedVector2Array = []
	var a: Vector2 = PLACES[i][1]
	var b: Vector2 = PLACES[i + 1][1]
	for s: int in steps + 1:
		var t: float = float(s) / float(steps)
		var p: Vector2
		match LEGS[i]:
			"air":   # two halves of one crossing: Werk Thalbach > the Kranich > Groom Lake
				var from: Vector2 = PLACES[3][1]
				var to: Vector2 = PLACES[5][1]
				p = _bezier(from, FLIGHT_CTRL, to, (t if i == 3 else t + 1.0) * 0.5)
			"rocket":
				p = _bezier(a, ROCKET_CTRL, b, t)
			_:
				var mid: Vector2 = (a + b) * 0.5
				var d: Vector2 = b - a
				p = _bezier(a, mid + Vector2(-d.y, d.x) * 0.14, b, t)
		out.append(p * size_px)
	return out


## The name plate of place `i` on a sheet of `size_px`: under the place, or beside it (the Moon), kept on the sheet.
static func plate_rect(i: int, size_px: Vector2 = REF) -> Rect2:
	var p: Vector2 = point(i, size_px)
	var r: Rect2
	if str(PLACES[i][2]) == "right":
		r = Rect2(p.x + MOON_R + 14.0, p.y - PLATE.y * 0.5, PLATE.x, PLATE.y)
	else:
		r = Rect2(p.x - PLATE.x * 0.5, p.y + PLATE_GAP, PLATE.x, PLATE.y)
	r.position.x = clampf(r.position.x, 6.0, maxf(6.0, size_px.x - PLATE.x - 6.0))
	r.position.y = clampf(r.position.y, 6.0, maxf(6.0, size_px.y - PLATE.y - 6.0))
	return r


## What a click or a hover on place `i` covers: its mark and its plate.
static func hit_rect(i: int, size_px: Vector2 = REF) -> Rect2:
	var p: Vector2 = point(i, size_px)
	return Rect2(p - Vector2(NODE_R + 6.0, NODE_R + 6.0), Vector2(NODE_R + 6.0, NODE_R + 6.0) * 2.0).merge(plate_rect(i, size_px))


## The Moon's inset (the night sky box): round its mark and its plate.
static func inset_rect(size_px: Vector2 = REF) -> Rect2:
	var i: int = PLACES.size() - 1
	var p: Vector2 = point(i, size_px)
	var r: Rect2 = Rect2(p - Vector2(MOON_R, MOON_R), Vector2(MOON_R, MOON_R) * 2.0).merge(plate_rect(i, size_px))
	return r.grow_individual(minf(60.0, r.position.x - 8.0), 18.0, 14.0, 22.0)


## A closed outline with its corners cut twice (Chaikin).
static func smooth(poly: PackedVector2Array, rounds: int = 2) -> PackedVector2Array:
	var p: PackedVector2Array = poly
	for _r: int in rounds:
		var q: PackedVector2Array = []
		for k: int in p.size():
			var a: Vector2 = p[k]
			var b: Vector2 = p[(k + 1) % p.size()]
			q.append(a.lerp(b, 0.25))
			q.append(a.lerp(b, 0.75))
		p = q
	return p


## The coasts on a sheet of `size_px`, smoothed.
static func land_shapes(size_px: Vector2 = REF) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for shape: Array in LAND:
		var poly: PackedVector2Array = []
		for v: Vector2 in shape:
			poly.append(v * size_px)
		out.append(smooth(poly))
	return out


## `pts` cut into dashes of `on` pixels with `off` between them.
static func dashes(pts: PackedVector2Array, on: float, off: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var cur: PackedVector2Array = []
	var drawing: bool = true
	var left: float = on
	for k: int in range(1, pts.size()):
		var a: Vector2 = pts[k - 1]
		var b: Vector2 = pts[k]
		var seg: float = a.distance_to(b)
		var at: float = 0.0
		if drawing and cur.is_empty():
			cur.append(a)
		while seg - at > left:
			at += left
			var p: Vector2 = a.lerp(b, at / seg)
			if drawing:
				cur.append(p)
				out.append(cur)
				cur = PackedVector2Array()
			else:
				cur = PackedVector2Array([p])
			drawing = not drawing
			left = on if drawing else off
		left -= seg - at
		if drawing:
			cur.append(b)
	if drawing and cur.size() >= 2:
		out.append(cur)
	return out


# ================================================================== the control

func _init() -> void:
	name = "World"
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(1150.0, REF.y)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paper = _layer("Paper")
	_paper.draw.connect(_draw_paper)
	_marks = _layer("Marks")
	_marks.draw.connect(_draw_marks)
	_ring = Control.new()
	_ring.name = "Ring"
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.size = Vector2(80.0, 80.0)
	_ring.visible = false
	_ring.draw.connect(_draw_ring)
	add_child(_ring)
	_holder = _layer("MapCards")   # the name the old grid of cards had: the smokes and tests find the places by it
	resized.connect(_layout)


func _layer(n: String) -> Control:
	var c: Control = Control.new()
	c.name = n
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	return c


## Makes the seven places from the profile. `on_start` is called with the map id when an open place is pressed.
func build(on_start: Callable) -> void:
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for i: int in PLACES.size():
		var id: String = str(PLACES[i][0])
		var st: Dictionary = profile_state(id)
		_states.append(st)
		var b: Button = Button.new()
		b.name = "Place_" + id
		b.focus_mode = Control.FOCUS_ALL
		b.disabled = bool(st["locked"])
		b.set_meta("map_id", id)
		b.set_meta("egg", str(st["egg"]))
		b.set_meta("best", int(st["best"]))
		b.tooltip_text = str(st["unlock"]) if bool(st["locked"]) else ""
		for sb: String in ["normal", "hover", "focus", "pressed", "hover_pressed", "disabled"]:
			b.add_theme_stylebox_override(sb, empty)
		b.focus_entered.connect(_on_focus.bind(i, true))
		b.focus_exited.connect(_on_focus.bind(i, false))
		b.mouse_entered.connect(b.grab_focus)
		b.pressed.connect(func() -> void: AudioDirector.play_2d("ui_stamp", 0.0, 0.03))
		if on_start.is_valid():
			b.pressed.connect(on_start.bind(id))
		_holder.add_child(b)
		buttons.append(b)
	_select(first_open(open_list()))
	_layout()


func open_list() -> Array:
	var out: Array = []
	for st: Dictionary in _states:
		out.append(not bool(st["locked"]))
	return out


## The place that should have the focus when the page opens.
func first_button() -> Button:
	return buttons[first_open(open_list())] if not buttons.is_empty() else null


## The rows around the sheet: UP from the sheet goes to `above`, DOWN to `below`, and both come back to the place
## last looked at. Call once the page is in the tree.
func link_rows(above: Control, below: Control) -> void:
	_above = above
	_below = below
	_wire()


func _wire() -> void:
	if not is_inside_tree():
		return
	var above_ok: bool = is_instance_valid(_above) and _above.is_inside_tree()
	var below_ok: bool = is_instance_valid(_below) and _below.is_inside_tree()
	for i: int in buttons.size():
		var b: Button = buttons[i]
		var here: NodePath = NodePath(".")
		for pair: Array in [[Vector2i.LEFT, "focus_neighbor_left"], [Vector2i.RIGHT, "focus_neighbor_right"],
				[Vector2i.UP, "focus_neighbor_top"], [Vector2i.DOWN, "focus_neighbor_bottom"]]:
			var j: int = neighbour(i, pair[0] as Vector2i)
			var to: NodePath = here
			if j >= 0:
				to = b.get_path_to(buttons[j])
			elif pair[0] == Vector2i.UP and above_ok:
				to = b.get_path_to(_above)
			elif pair[0] == Vector2i.DOWN and below_ok:
				to = b.get_path_to(_below)
			b.set(str(pair[1]), to)
		if i + 1 < buttons.size():
			b.focus_next = b.get_path_to(buttons[i + 1])
		elif below_ok:
			b.focus_next = b.get_path_to(_below)
		if i > 0:
			b.focus_previous = b.get_path_to(buttons[i - 1])
	var cur: Button = buttons[clampi(selected, 0, buttons.size() - 1)] if not buttons.is_empty() else null
	if cur == null:
		return
	if above_ok:   # every control of the row above comes down onto the sheet
		for c: Control in MenuKit.focusables(_above.get_parent()):
			c.focus_neighbor_bottom = c.get_path_to(cur)
	if below_ok:
		for c: Control in MenuKit.focusables(_below.get_parent()):
			c.focus_neighbor_top = c.get_path_to(cur)
		_below.focus_previous = _below.get_path_to(buttons[buttons.size() - 1])


func _on_focus(i: int, on: bool) -> void:
	if on:
		if not MenuKit.is_quiet():
			AudioDirector.play_2d("ui_tick", 0.0, 0.06)
		_select(i)
	set_process(on and not MenuMotion.reduced())
	_ring.queue_redraw()
	_marks.queue_redraw()


func _select(i: int) -> void:
	var changed: bool = i != selected
	selected = i
	_place_ring()
	_marks.queue_redraw()
	_wire()
	if changed:
		place_focused.emit(str(PLACES[i][0]))


func state_of(map_id: String) -> Dictionary:
	var i: int = index_of(map_id)
	return _states[i] if i >= 0 and i < _states.size() else {}


func _place_ring() -> void:
	if selected < 0:
		return
	var to: Vector2 = point(selected, size) - _ring.size * 0.5
	_ring.visible = true
	if _ring_placed and is_inside_tree():
		MenuMotion.glide(_ring, to)   # the mark travels along to the place
	else:
		_ring.position = to
	_ring_placed = size.x > 1.0


func _layout() -> void:
	for i: int in buttons.size():
		var r: Rect2 = hit_rect(i, size)
		buttons[i].position = r.position
		buttons[i].size = r.size
	_ring_placed = false
	MenuMotion.finish(_ring)
	_place_ring()
	_paper.queue_redraw()
	_marks.queue_redraw()


func _ready() -> void:
	set_process(false)
	_layout()


func _process(_delta: float) -> void:
	_ring.queue_redraw()   # the pulse round the place under the focus (off with Reduce motion: _on_focus)


func _focused_place() -> bool:
	return selected >= 0 and selected < buttons.size() and buttons[selected].has_focus()


# ================================================================== drawing

func _draw_ring() -> void:
	var c: Vector2 = _ring.size * 0.5
	var col: Color = MenuKit.VIOLET.lightened(0.15)
	var base: float = (MOON_R if selected == PLACES.size() - 1 else NODE_R) + 5.0
	_ring.draw_arc(c, base, 0.0, TAU, 48, col, 3.0, true)
	if _focused_place() and not MenuMotion.reduced():
		var k: float = fposmod(float(Time.get_ticks_msec()) / 1000.0, 1.4) / 1.4
		_ring.draw_arc(c, base + 12.0 * k, 0.0, TAU, 48, Color(col.r, col.g, col.b, 0.75 * (1.0 - k)), 2.0, true)


func _draw_paper() -> void:
	var s: Vector2 = size
	if s.x < 2.0 or s.y < 2.0:
		return
	var p: Control = _paper
	p.draw_rect(Rect2(Vector2.ZERO, s), SEA_C)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 270
	var shapes: Array[PackedVector2Array] = land_shapes(s)
	# shallow water along every coast, then the land, then the coast in ink
	for poly: PackedVector2Array in shapes:
		var closed: PackedVector2Array = poly.duplicate()
		closed.append(poly[0])
		p.draw_polyline(closed, Color(0.60, 0.66, 0.66, 0.55), 13.0, true)
	for poly: PackedVector2Array in shapes:
		p.draw_colored_polygon(poly, LAND_C)
	# sea strokes, away from the land
	for _k: int in 150:
		var at: Vector2 = Vector2(rng.randf() * s.x, rng.randf() * s.y)
		var on_land: bool = false
		for poly: PackedVector2Array in shapes:
			if Geometry2D.is_point_in_polygon(at, poly) or Geometry2D.is_point_in_polygon(at + Vector2(16.0, 0.0), poly):
				on_land = true
				break
		if on_land:
			continue
		p.draw_polyline(PackedVector2Array([at, at + Vector2(5.0, -2.0), at + Vector2(10.0, 0.0), at + Vector2(15.0, -2.0)]),
			Color(0.42, 0.50, 0.54, 0.30), 1.2, true)
	for poly: PackedVector2Array in shapes:
		var closed2: PackedVector2Array = poly.duplicate()
		closed2.append(poly[0])
		p.draw_polyline(closed2, Color(INK_BROWN.r, INK_BROWN.g, INK_BROWN.b, 0.85), 2.0, true)
	# the survey grid, the folds, the stains of a sheet that has been carried
	for k: int in range(1, 12):
		var x: float = s.x * float(k) / 12.0
		p.draw_line(Vector2(x, 0.0), Vector2(x, s.y), Color(INK_BROWN.r, INK_BROWN.g, INK_BROWN.b, 0.10), 1.0)
	for k: int in range(1, 6):
		var y: float = s.y * float(k) / 6.0
		p.draw_line(Vector2(0.0, y), Vector2(s.x, y), Color(INK_BROWN.r, INK_BROWN.g, INK_BROWN.b, 0.10), 1.0)
	for fx: float in [1.0 / 3.0, 2.0 / 3.0]:
		p.draw_line(Vector2(s.x * fx - 1.5, 0.0), Vector2(s.x * fx - 1.5, s.y), Color(1.0, 1.0, 0.95, 0.20), 2.0)
		p.draw_line(Vector2(s.x * fx + 1.0, 0.0), Vector2(s.x * fx + 1.0, s.y), Color(0.2, 0.14, 0.08, 0.16), 2.0)
	p.draw_line(Vector2(0.0, s.y * 0.5 - 1.5), Vector2(s.x, s.y * 0.5 - 1.5), Color(1.0, 1.0, 0.95, 0.20), 2.0)
	p.draw_line(Vector2(0.0, s.y * 0.5 + 1.0), Vector2(s.x, s.y * 0.5 + 1.0), Color(0.2, 0.14, 0.08, 0.16), 2.0)
	for _k: int in 26:
		p.draw_circle(Vector2(rng.randf() * s.x, rng.randf() * s.y), rng.randf_range(18.0, 70.0), Color(0.35, 0.24, 0.12, 0.035))
	# names
	var serif: Font = MenuKit.spaced(MenuKit.type_font(), 5)
	for nm: Array in NAMES:
		var fs: int = int(nm[2])
		var w: float = serif.get_string_size(str(nm[0]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
		p.draw_string(serif, (nm[1] as Vector2) * s - Vector2(w * 0.5, 0.0), str(nm[0]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs,
			Color(INK_BROWN.r, INK_BROWN.g, INK_BROWN.b, 0.55))
	_draw_compass(Vector2(0.455, 0.135) * s, 30.0)
	_draw_inset(rng)
	_draw_title(Rect2(Vector2(0.275, 0.785) * s, Vector2(0.225, 0.185) * s))
	# the worn edge and the frame
	for k: int in 5:
		p.draw_rect(Rect2(Vector2.ZERO, s).grow(-float(k) * 5.0), Color(0.22, 0.15, 0.08, 0.05), false, 10.0)
	p.draw_rect(Rect2(Vector2(1.0, 1.0), s - Vector2(2.0, 2.0)), MenuKit.BRASS_DARK, false, 2.0)
	p.draw_rect(Rect2(Vector2(7.0, 7.0), s - Vector2(14.0, 14.0)), Color(INK_BROWN.r, INK_BROWN.g, INK_BROWN.b, 0.6), false, 1.0)


func _draw_compass(c: Vector2, r: float) -> void:
	var p: Control = _paper
	var ink: Color = Color(INK_BROWN.r, INK_BROWN.g, INK_BROWN.b, 0.75)
	p.draw_arc(c, r, 0.0, TAU, 40, ink, 1.2, true)
	p.draw_arc(c, r * 0.62, 0.0, TAU, 32, Color(ink.r, ink.g, ink.b, 0.4), 1.0, true)
	for k: int in 4:
		var a: float = float(k) * PI * 0.5 - PI * 0.5
		var tip: Vector2 = c + Vector2.from_angle(a) * r * (1.3 if k == 0 else 1.05)
		var l: Vector2 = c + Vector2.from_angle(a + PI * 0.5) * r * 0.16
		var rr: Vector2 = c + Vector2.from_angle(a - PI * 0.5) * r * 0.16
		p.draw_colored_polygon(PackedVector2Array([tip, l, c]), ink)
		p.draw_polyline(PackedVector2Array([tip, rr, c]), ink, 1.0, true)
	var f: Font = MenuKit.type_font()
	p.draw_string(f, c + Vector2(-5.0, -r * 1.3 - 5.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, ink)


func _draw_inset(rng: RandomNumberGenerator) -> void:
	var p: Control = _paper
	var r: Rect2 = inset_rect(size)
	p.draw_rect(r.grow(4.0), Color(0.2, 0.14, 0.08, 0.35))
	p.draw_rect(r, NIGHT_C)
	for _k: int in 70:
		var at: Vector2 = r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
		p.draw_circle(at, rng.randf_range(0.6, 1.5), Color(0.9, 0.9, 1.0, rng.randf_range(0.25, 0.85)))
	var m: Vector2 = point(PLACES.size() - 1, size)
	p.draw_circle(m, MOON_R + 5.0, Color(0.75, 0.78, 0.9, 0.10))
	p.draw_circle(m, MOON_R, Color(0.80, 0.79, 0.72))
	for cr: Array in [[Vector2(-10.0, -9.0), 6.0], [Vector2(9.0, -13.0), 3.5], [Vector2(13.0, 6.0), 5.0], [Vector2(-13.0, 9.0), 4.0], [Vector2(-1.0, 17.0), 3.0]]:
		p.draw_circle(m + (cr[0] as Vector2), float(cr[1]), Color(0.62, 0.61, 0.56))
	p.draw_rect(r, MenuKit.BRASS_DARK, false, 2.0)
	p.draw_rect(r.grow(-4.0), Color(MenuKit.BRASS.r, MenuKit.BRASS.g, MenuKit.BRASS.b, 0.45), false, 1.0)
	p.draw_string(MenuKit.spaced(MenuKit.type_font(), 2), r.position + Vector2(10.0, r.size.y - 9.0), "INSET  ·  NOT ON THIS SHEET",
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(MenuKit.DIM.r, MenuKit.DIM.g, MenuKit.DIM.b, 0.9))


func _draw_title(r: Rect2) -> void:
	var p: Control = _paper
	var ink: Color = Color(INK_BROWN.r, INK_BROWN.g, INK_BROWN.b, 0.9)
	p.draw_rect(r, Color(PAPER_C.r, PAPER_C.g, PAPER_C.b, 0.92))
	p.draw_rect(r, ink, false, 2.0)
	p.draw_rect(r.grow(-4.0), Color(ink.r, ink.g, ink.b, 0.5), false, 1.0)
	var x: float = r.position.x + 14.0
	p.draw_string(MenuKit.stamp_font(), Vector2(x, r.position.y + 34.0), "ONE ROAD", HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 28.0, 28,
		Color(MenuKit.INK.r, MenuKit.INK.g, MenuKit.INK.b, 0.95))
	p.draw_string(MenuKit.type_font(), Vector2(x, r.position.y + 55.0), "Silesia to the Moon", HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 28.0, 16, ink)
	p.draw_string(MenuKit.body_font(), Vector2(x, r.position.y + 73.0), "December 1944 – May 1945  ·  not to scale", HORIZONTAL_ALIGNMENT_LEFT,
		r.size.x - 28.0, 13, Color(ink.r, ink.g, ink.b, 0.8))
	# the key
	var y: float = r.position.y + r.size.y - 16.0
	var kx: float = x
	for key: Array in [["road", "road, rail"], ["air", "air"], ["rocket", "rocket"]]:
		var seg: PackedVector2Array = PackedVector2Array([Vector2(kx, y), Vector2(kx + 34.0, y)])
		_draw_leg(p, seg, str(key[0]), Color(MenuKit.INK.r, MenuKit.INK.g, MenuKit.INK.b, 0.95), 3.0)
		p.draw_string(MenuKit.body_font(), Vector2(kx + 40.0, y + 5.0), str(key[1]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, ink)
		kx += 40.0 + MenuKit.body_font().get_string_size(str(key[1]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13).x + 16.0


## A leg in its style: a solid line (road and rail), long dashes (air), short dashes (rocket).
static func _draw_leg(on: CanvasItem, pts: PackedVector2Array, kind: String, col: Color, width: float) -> void:
	match kind:
		"air":
			for d: PackedVector2Array in dashes(pts, 13.0, 8.0):
				on.draw_polyline(d, col, width, true)
		"rocket":
			for d: PackedVector2Array in dashes(pts, 3.5, 7.0):
				on.draw_polyline(d, col, width + 1.0, true)
		_:
			on.draw_polyline(pts, col, width, true)


func _draw_marks() -> void:
	var s: Vector2 = size
	if s.x < 2.0 or _states.size() != PLACES.size():
		return
	var m: Control = _marks
	var open: Array = open_list()
	var travelled: Array[bool] = legs_travelled(open)
	# the route: the legs you have travelled in red ink, the rest in pencil
	for i: int in LEGS.size():
		var pts: PackedVector2Array = leg_points(i, s)
		if travelled[i]:
			_draw_leg(m, pts, LEGS[i], Color(0.95, 0.9, 0.8, 0.55), 7.0)
			_draw_leg(m, pts, LEGS[i], MenuKit.INK, 3.5)
		else:
			_draw_leg(m, pts, LEGS[i], Color(INK_BROWN.r, INK_BROWN.g, INK_BROWN.b, 0.45), 2.5)
	# the Kranich on its line, the rocket on its trail
	var ink: Color = Color(0.16, 0.12, 0.1)
	var fl: PackedVector2Array = leg_points(4, s)
	_glyph(m, _PLANE, fl[5], (fl[6] - fl[4]).angle(), 15.0, ink if bool(open[4]) else Color(ink.r, ink.g, ink.b, 0.5))
	var rk: PackedVector2Array = leg_points(5, s)
	_glyph(m, _ROCKET, rk[9], (rk[10] - rk[8]).angle(), 11.0, ink if bool(open[6]) else Color(ink.r, ink.g, ink.b, 0.5))
	var num: Font = MenuKit.stamp_font()
	for i: int in PLACES.size():
		var st: Dictionary = _states[i]
		var at: Vector2 = point(i, s)
		var locked: bool = bool(st["locked"])
		var sel: bool = i == selected
		# the mark
		m.draw_circle(at, NODE_R + 2.5, Color(0.1, 0.07, 0.05, 0.85))
		m.draw_circle(at, NODE_R, Color(0.36, 0.34, 0.31) if locked else MenuKit.INK)
		m.draw_arc(at, NODE_R - 3.0, 0.0, TAU, 32, Color(MenuKit.PAPER.r, MenuKit.PAPER.g, MenuKit.PAPER.b, 0.35 if locked else 0.6), 1.2, true)
		if locked:
			var pc: Color = Color(0.8, 0.77, 0.7)
			m.draw_arc(at + Vector2(0.0, -2.5), 4.2, PI, TAU, 12, pc, 2.0, true)
			m.draw_rect(Rect2(at + Vector2(-6.0, -2.5), Vector2(12.0, 9.0)), pc)
		else:
			var t: String = str(int(st["stop"]))
			var ts: Vector2 = num.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18)
			m.draw_string(num, at + Vector2(-ts.x * 0.5, num.get_ascent(18) * 0.5 - 2.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, MenuKit.PAPER)
		if str(st["egg"]) == "done":   # a violet lozenge: this place's egg is done
			var e: Vector2 = at + Vector2(NODE_R + 1.0, -NODE_R - 1.0)
			m.draw_colored_polygon(PackedVector2Array([e + Vector2(0.0, -7.0), e + Vector2(6.0, 0.0), e + Vector2(0.0, 7.0), e + Vector2(-6.0, 0.0)]),
				MenuKit.VIOLET.lightened(0.25))
			m.draw_polyline(PackedVector2Array([e + Vector2(0.0, -7.0), e + Vector2(6.0, 0.0), e + Vector2(0.0, 7.0), e + Vector2(-6.0, 0.0), e + Vector2(0.0, -7.0)]),
				Color(0.1, 0.07, 0.12), 1.2, true)
		_draw_plate(i, st, sel)


func _draw_plate(i: int, st: Dictionary, sel: bool) -> void:
	var m: Control = _marks
	var r: Rect2 = plate_rect(i, size)
	var locked: bool = bool(st["locked"])
	if sel:
		m.draw_rect(r.grow(5.0), Color(MenuKit.VIOLET.r, MenuKit.VIOLET.g, MenuKit.VIOLET.b, 0.28))
	else:
		m.draw_rect(Rect2(r.position + Vector2(3.0, 4.0), r.size), Color(0.1, 0.07, 0.04, 0.35))
	m.draw_rect(r, Color(0.08, 0.06, 0.12, 0.96) if sel else Color(0.04, 0.04, 0.06, 0.93))
	m.draw_rect(r, MenuKit.VIOLET if sel else MenuKit.BRASS_DARK, false, 3.0 if sel else 1.5)
	var x: float = r.position.x + 10.0
	var w: float = r.size.x - 20.0
	m.draw_string(MenuKit.type_font(), Vector2(x, r.position.y + 25.0), str(st["name"]), HORIZONTAL_ALIGNMENT_LEFT, w, 21,
		MenuKit.DIM if locked else MenuKit.PAPER)
	m.draw_string(MenuKit.body_font(), Vector2(x, r.position.y + 45.0), str(st["date"]), HORIZONTAL_ALIGNMENT_LEFT, w, 14, MenuKit.DIM)
	var mono: Font = MenuKit.mono_font()
	var y: float = r.position.y + 64.0
	if locked:
		m.draw_string(MenuKit.spaced(mono, 2), Vector2(x, y), "LOCKED", HORIZONTAL_ALIGNMENT_LEFT, w, 14, MenuKit.INK.lightened(0.3))
	else:
		m.draw_string(mono, Vector2(x, y), str(st["best_text"]), HORIZONTAL_ALIGNMENT_LEFT, w, 14, MenuKit.GOLD if int(st["best"]) > 0 else MenuKit.DIM)
		var ec: Color = MenuKit.DIM.darkened(0.2)
		if str(st["egg"]) == "done":
			ec = MenuKit.VIOLET.lightened(0.25)
		elif str(st["egg"]) == "not done":
			ec = MenuKit.DIM
		m.draw_string(mono, Vector2(x, y), str(st["egg_text"]), HORIZONTAL_ALIGNMENT_RIGHT, w, 14, ec)


## Outlines of the two small pictures on the route, nose towards +x, about one unit long each way.
const _PLANE: Array = [
	[Vector2(1.0, 0.0), Vector2(0.55, 0.13), Vector2(-0.8, 0.1), Vector2(-1.0, 0.0), Vector2(-0.8, -0.1), Vector2(0.55, -0.13)],
	[Vector2(0.3, 0.05), Vector2(-0.25, 1.0), Vector2(-0.5, 1.0), Vector2(-0.2, 0.05)],
	[Vector2(0.3, -0.05), Vector2(-0.2, -0.05), Vector2(-0.5, -1.0), Vector2(-0.25, -1.0)],
	[Vector2(-0.7, 0.05), Vector2(-0.95, 0.42), Vector2(-1.08, 0.42), Vector2(-0.92, 0.05)],
	[Vector2(-0.7, -0.05), Vector2(-0.92, -0.05), Vector2(-1.08, -0.42), Vector2(-0.95, -0.42)],
]
const _ROCKET: Array = [
	[Vector2(1.0, 0.0), Vector2(0.45, 0.24), Vector2(-0.6, 0.24), Vector2(-0.6, -0.24), Vector2(0.45, -0.24)],
	[Vector2(-0.3, 0.24), Vector2(-1.0, 0.6), Vector2(-0.8, 0.24)],
	[Vector2(-0.3, -0.24), Vector2(-0.8, -0.24), Vector2(-1.0, -0.6)],
]


static func _glyph(on: CanvasItem, parts: Array, at: Vector2, angle: float, scale_px: float, col: Color) -> void:
	var xf: Transform2D = Transform2D(angle, Vector2(scale_px, scale_px), 0.0, at)
	for part: Array in parts:
		var poly: PackedVector2Array = []
		for v: Vector2 in part:
			poly.append(xf * v)
		on.draw_colored_polygon(poly, col)


# ================================================================== the side panel

## The panel beside the sheet: the place under the focus with its 16:9 preview, its date line, its progress or its
## unlock rule, and how the route reaches it. Fill it with `fill_panel`.
static func make_panel(width: float = 430.0) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.name = "PlacePanel"
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.045, 0.72)
	sb.border_color = MenuKit.BRASS_DARK
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(width, 0.0)
	var inner: float = width - 26.0
	var v: VBoxContainer = VBoxContainer.new()
	v.name = "Body"
	v.add_theme_constant_override("separation", 5)
	p.add_child(v)
	var k: Label = MenuKit.label("", 16, MenuKit.VIOLET.lightened(0.2))
	k.name = "PlaceKicker"
	k.add_theme_font_override("font", MenuKit.spaced(MenuKit.type_font(), 3))
	k.clip_text = true
	v.add_child(k)
	var frame: Control = Control.new()
	frame.name = "PreviewFrame"
	frame.clip_contents = true
	frame.custom_minimum_size = Vector2(inner, inner * 9.0 / 16.0)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(frame)
	var pic: TextureRect = TextureRect.new()
	pic.name = "Preview"
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(pic)
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stamp: Label = MenuKit.label("LOCKED", 40, MenuKit.INK.lightened(0.15), true)
	stamp.name = "LockStamp"
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.rotation = deg_to_rad(-8.0)
	stamp.position = Vector2(inner * 0.5 - 78.0, inner * 9.0 / 32.0 - 14.0)
	frame.add_child(stamp)
	var n: Label = MenuKit.label("", 30, MenuKit.PAPER, true)
	n.name = "PlaceName"
	n.clip_text = true
	v.add_child(n)
	var d: Label = MenuKit.label("", 18, MenuKit.DIM.lightened(0.15))
	d.name = "PlaceDate"
	d.add_theme_font_override("font", MenuKit.body_font())
	d.clip_text = true
	v.add_child(d)
	var rule: ColorRect = MenuKit.rule(1.0)
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	v.add_child(rule)
	var prog: HBoxContainer = HBoxContainer.new()
	prog.name = "Progress"
	prog.add_theme_constant_override("separation", 22)
	v.add_child(prog)
	for nm: String in ["PlaceBest", "PlaceEgg"]:
		var l: Label = MenuKit.label("", 18, MenuKit.GOLD)
		l.name = nm
		l.add_theme_font_override("font", MenuKit.spaced(MenuKit.mono_font(), 1))
		prog.add_child(l)
	var lock: Label = MenuKit.para("", 18, MenuKit.PAPER)
	lock.name = "PlaceLock"
	lock.custom_minimum_size = Vector2(inner, 0.0)
	v.add_child(lock)
	var route: Label = MenuKit.para("", 17, MenuKit.DIM)
	route.name = "PlaceRoute"
	route.custom_minimum_size = Vector2(inner, 0.0)
	v.add_child(route)
	var hint: Label = MenuKit.para("", 17, MenuKit.GOLD)
	hint.name = "PlaceHint"
	hint.custom_minimum_size = Vector2(inner, 0.0)
	v.add_child(hint)
	return p


## The route lines of the panel for stop `i` (pure): where you come from and where the road goes on.
static func route_text(i: int) -> String:
	var lines: PackedStringArray = []
	if i > 0:
		lines.append("From %s, %s." % [str(MapCards.row(str(PLACES[i - 1][0])).get("name", "")), leg_words(i - 1)])
	else:
		lines.append("Where the road begins.")
	if i + 1 < PLACES.size():
		lines.append("Onward to %s, %s." % [str(MapCards.row(str(PLACES[i + 1][0])).get("name", "")), leg_words(i)])
	else:
		lines.append("The end of the road.")
	return "\n".join(lines)


## Shows the place `st` (a `state` dictionary) in a panel made by make_panel.
static func fill_panel(panel: PanelContainer, st: Dictionary) -> void:
	if panel == null or st.is_empty():
		return
	var locked: bool = bool(st["locked"])
	var i: int = int(st["stop"]) - 1
	(panel.find_child("PlaceKicker", true, false) as Label).text = "STOP %d OF %d   ·   %s" % [i + 1, PLACES.size(), str(st["kicker"])]
	var pic: TextureRect = panel.find_child("Preview", true, false) as TextureRect
	pic.texture = MapCards.preview(str(st["id"]))
	pic.modulate = Color(0.32, 0.32, 0.36) if locked else Color.WHITE
	(panel.find_child("LockStamp", true, false) as Label).visible = locked
	var n: Label = panel.find_child("PlaceName", true, false) as Label
	n.text = str(st["name"])
	n.add_theme_color_override("font_color", MenuKit.DIM if locked else MenuKit.PAPER)
	(panel.find_child("PlaceDate", true, false) as Label).text = str(st["date"])
	(panel.find_child("Progress", true, false) as Control).visible = not locked
	var best: Label = panel.find_child("PlaceBest", true, false) as Label
	best.text = str(st["best_text"])
	best.add_theme_color_override("font_color", MenuKit.GOLD if int(st["best"]) > 0 else MenuKit.DIM)
	var egg: Label = panel.find_child("PlaceEgg", true, false) as Label
	egg.text = str(st["egg_text"])
	var ec: Color = MenuKit.DIM.darkened(0.2)
	if str(st["egg"]) == "done":
		ec = MenuKit.VIOLET.lightened(0.25)
	elif str(st["egg"]) == "not done":
		ec = MenuKit.DIM
	egg.add_theme_color_override("font_color", ec)
	var lock: Label = panel.find_child("PlaceLock", true, false) as Label
	lock.visible = locked
	lock.text = "To unlock: " + str(st["unlock"])
	(panel.find_child("PlaceRoute", true, false) as Label).text = route_text(i)
	var hint: Label = panel.find_child("PlaceHint", true, false) as Label
	hint.text = "Locked. You can look, but the road does not reach it yet." if locked else "Press to start the match here."
	hint.add_theme_color_override("font_color", MenuKit.DIM if locked else MenuKit.GOLD)
	var body: Control = panel.find_child("Body", true, false) as Control
	if body != null and body.is_inside_tree():   # the new place fades in (0.06 s with Reduce motion)
		body.modulate.a = 0.35
		MenuMotion.fade(body, 1.0, 0.14)
