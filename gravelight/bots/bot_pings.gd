class_name BotPings
extends Node3D
## World-space callout pings (Update 03 section 5): a bot's callout ("Sprinter, behind you!", "Resupply!",
## "Window's open!") flashes a small marker at the spot: a diamond and a short label that pop in, bob, and fade
## after `seconds`. Pooled Label3D markers (POOL), drawn over walls so a ping behind cover still reads.

const POOL: int = 8
const COLOR: Color = Color(1.0, 0.82, 0.35)

var _items: Array[Dictionary] = []   # {node: Node3D, label: Label3D, mark: Label3D, t: float, life: float, pos: Vector3}
var _next: int = 0


func _ready() -> void:
	for i: int in POOL:
		var root: Node3D = Node3D.new()
		root.name = "Ping%d" % i
		root.visible = false
		add_child(root)
		var mark: Label3D = _label("◆", 44, 0.0)
		root.add_child(mark)
		var lab: Label3D = _label("", 30, 0.18)
		root.add_child(lab)
		_items.append({"node": root, "label": lab, "mark": mark, "t": 0.0, "life": 0.0, "pos": Vector3.ZERO})


func _label(text: String, size: int, y: float) -> Label3D:
	var l: Label3D = Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.0016
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.modulate = COLOR
	l.outline_size = 10
	l.outline_modulate = Color(0.05, 0.04, 0.03, 0.9)
	l.position = Vector3(0, y, 0)
	l.render_priority = 10
	return l


## Shows a ping at `at` labelled `text` for `seconds`.
func ping(at: Vector3, text: String, seconds: float = 3.0) -> void:
	if _items.is_empty():
		return
	var it: Dictionary = _items[_next]
	_next = (_next + 1) % _items.size()
	it["t"] = 0.0
	it["life"] = maxf(0.5, seconds)
	it["pos"] = at
	(it["label"] as Label3D).text = text
	var n: Node3D = it["node"]
	n.visible = true
	n.global_position = at


## The pings showing now (tests, the clip tool).
func active_count() -> int:
	var n: int = 0
	for it: Dictionary in _items:
		if (it["node"] as Node3D).visible:
			n += 1
	return n


func _process(delta: float) -> void:
	for it: Dictionary in _items:
		var n: Node3D = it["node"]
		if not n.visible:
			continue
		it["t"] = float(it["t"]) + delta
		var t: float = float(it["t"])
		var life: float = float(it["life"])
		if t >= life:
			n.visible = false
			continue
		var pop: float = clampf(t / 0.15, 0.0, 1.0)
		var fade: float = clampf((life - t) / 0.6, 0.0, 1.0)
		var a: float = pop * fade
		n.global_position = (it["pos"] as Vector3) + Vector3.UP * (sin(t * 5.0) * 0.06)
		for key: String in ["label", "mark"]:
			var l: Label3D = it[key]
			l.modulate = Color(COLOR.r, COLOR.g, COLOR.b, a)
			l.outline_modulate = Color(0.05, 0.04, 0.03, 0.9 * a)
		(it["mark"] as Label3D).scale = Vector3.ONE * (1.6 - 0.6 * pop)
