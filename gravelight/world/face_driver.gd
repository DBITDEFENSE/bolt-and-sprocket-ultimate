class_name FaceDriver
extends Node
## Drives a person's face blend shapes (T-092, UPDATE_05 section 4; PeopleBodies' meshes carry people.json
## "shapes": blink, jaw_open, fear, determined, pain, smile):
##   - blinks on a random timer (people.json face_driver.blink [min, max] seconds; 0 = never, Alix);
##   - holds an expression (`set_expression`: the owner maps its state: downed = pain, low health = fear, firing =
##     determined, calm = the rest expression), eased in and out, from people.json "expressions";
##   - lip flap: while a VO line by one of `speakers` plays (GLBus.vo_line_started: the speaker code, the text, the
##     duration), the jaw opens and closes on a syllable rhythm (vowel groups in the line over its duration) with a
##     little noise, on top of the expression.
## Presentation only. Owners: RemoteBody (the squad, Jakub), PatronBody (patrons, survivors), the Cousins.

const EASE: float = 5.0
const BLINK_S: float = 0.16

var mesh: MeshInstance3D = null
var speakers: PackedStringArray = []
var blink_range: Vector2 = Vector2(2.5, 6.0)
var expression: StringName = &"neutral"
## A tool / cutscene override: when set, this expression wins over the owner's set_expression().
var hold: StringName = &""
## 0..1 how much of the expression shows (the owner may fade it, e.g. far away).
var strength: float = 1.0
var talking: bool = false

var _idx: Dictionary = {}          # shape name -> blend shape index
var _w: Dictionary = {}            # shape name -> current weight
var _blink_t: float = 3.0
var _blink_k: float = -1.0
var _talk_t: float = 0.0
var _talk_len: float = 0.0
var _talk_rate: float = 4.0
var _jaw: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _forced_blink: float = -1.0


## A driver for `mi` (a PeopleBodies mesh) dressed as person `id`; added as a child of `mi`.
static func attach(mi: MeshInstance3D, id: String) -> FaceDriver:
	var fd: FaceDriver = FaceDriver.new()
	fd.name = "FaceDriver"
	fd.mesh = mi
	var r: Dictionary = PeopleBodies.row(id)
	var fdc: Dictionary = r.get("face_driver", {})
	var br: Array = fdc.get("blink", [2.5, 6.0])
	fd.blink_range = Vector2(float(br[0]), float(br[1]))
	fd.expression = StringName(str(fdc.get("rest", "neutral")))
	var spk: String = str(r.get("speaker", ""))
	if spk != "":
		fd.speakers.append(spk)
	fd._rng.seed = hash(id) + Time.get_ticks_usec()
	mi.add_child(fd)
	return fd


func _ready() -> void:
	_blink_t = _rng.randf_range(0.5, maxf(0.6, blink_range.y))
	if not GLBus.vo_line_started.is_connected(_on_line):
		GLBus.vo_line_started.connect(_on_line)
	_bind()


func _bind() -> void:
	_idx.clear()
	if mesh == null or mesh.mesh == null:
		return
	for s: String in PeopleBodies.shape_names():
		var i: int = mesh.find_blend_shape_by_name(StringName(s))
		if i >= 0:
			_idx[s] = i
			_w[s] = 0.0


## The mesh was swapped (a risen patron's zombie mesh, a rebuild).
func rebind(mi: MeshInstance3D) -> void:
	mesh = mi
	_bind()


func has_shapes() -> bool:
	return not _idx.is_empty()


func set_expression(e: StringName) -> void:
	expression = e


## Closes the eyes for `seconds` (a test / shot helper; also the dead).
func force_blink(seconds: float) -> void:
	_forced_blink = seconds


## Weight of one shape right now (tests).
func weight(shape: String) -> float:
	return float(_w.get(shape, 0.0))


func _on_line(_id: StringName, speaker: StringName, text: String, duration: float) -> void:
	if not speakers.has(String(speaker)):
		return
	talking = true
	_talk_t = 0.0
	_talk_len = maxf(0.4, duration)
	_talk_rate = clampf(float(syllables(text)) / _talk_len, 2.0, 6.5)


## Vowel groups in a line (the lip flap's rhythm).
static func syllables(text: String) -> int:
	var n: int = 0
	var prev: bool = false
	for ch: String in text.to_lower():
		var v: bool = "aeiouyäöü".contains(ch)
		if v and not prev:
			n += 1
		prev = v
	return maxi(1, n)


func _process(delta: float) -> void:
	if _idx.is_empty() or mesh == null or not mesh.is_visible_in_tree():
		return
	step(delta)


## One frame of the face (public so tools and tests can drive it without the tree's clock).
func step(delta: float) -> void:
	var target: Dictionary = {}
	var ex: Dictionary = (PeopleBodies.cfg().get("expressions", {}) as Dictionary).get(String(hold if hold != &"" else expression), {})
	for k: Variant in ex.keys():
		if String(k).begins_with("_"):
			continue
		target[String(k)] = float(ex[k]) * strength
	# blink
	var blink: float = 0.0
	if _forced_blink > 0.0:
		_forced_blink -= delta
		blink = 1.0
	elif blink_range.y > 0.0:
		if _blink_k >= 0.0:
			_blink_k += delta / BLINK_S
			blink = 1.0 - absf(_blink_k * 2.0 - 1.0)
			if _blink_k >= 1.0:
				_blink_k = -1.0
				_blink_t = _rng.randf_range(blink_range.x, blink_range.y)
		else:
			_blink_t -= delta
			if _blink_t <= 0.0:
				_blink_k = 0.0
	# lip flap
	var jaw_target: float = 0.0
	if talking:
		_talk_t += delta
		if _talk_t >= _talk_len:
			talking = false
		else:
			var syl: float = absf(sin(PI * _talk_rate * _talk_t))
			jaw_target = 0.08 + 0.42 * syl * (0.75 + 0.25 * sin(_talk_t * 7.3))
	_jaw = move_toward(_jaw, jaw_target, delta * 9.0)
	for s: String in _idx.keys():
		var want: float = float(target.get(s, 0.0))
		var cur: float = move_toward(float(_w.get(s, 0.0)), want, delta * EASE)
		_w[s] = cur
		var v: float = cur
		if s == "blink":
			v = maxf(cur, blink)
		elif s == "jaw_open":
			v = clampf(cur + _jaw, 0.0, 1.0)
		mesh.set_blend_shape_value(int(_idx[s]), v)


## The value a shape has on the mesh right now (expression + blink / lip flap).
func applied(shape: String) -> float:
	if mesh == null or not _idx.has(shape):
		return 0.0
	return mesh.get_blend_shape_value(int(_idx[shape]))
