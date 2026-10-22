class_name SnowFootprints
extends Node3D
## Footprints in the snow (Update 02 section 8, T-053): players leave boot prints and zombies leave dragged,
## shuffling prints wherever they walk on open snow (`areas`, minus `holes`, at about `ground_y`), and the falling
## snow fills them in over `life` seconds. One MultiMesh of flat quads with a ring buffer of `max_prints` (the oldest
## is reused), faded by a shader from each print's birth time (instance custom data), so ageing costs one shader
## parameter a frame. Walkers are checked ten times a second. Every peer makes its own prints from the bodies it
## sees move, so it works the same for co-op clients.

const SCAN_SECONDS: float = 0.1
const KIND_BOOT: float = 0.0
const KIND_DRAG: float = 1.0
const SHADER: String = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_disabled;
uniform sampler2D atlas : source_color, filter_linear, repeat_disable;
uniform float now = 0.0;
uniform float life = 90.0;
varying float v_alpha;
varying float v_kind;
void vertex() {
	float age = now - INSTANCE_CUSTOM.x;
	v_alpha = clamp(1.0 - age / life, 0.0, 1.0) * clamp(age * 5.0 + 0.4, 0.0, 1.0);
	v_kind = INSTANCE_CUSTOM.y;
}
void fragment() {
	vec4 t = texture(atlas, vec2(UV.x * 0.5 + v_kind * 0.5, UV.y));
	ALBEDO = t.rgb;
	ALPHA = t.a * v_alpha;
	ROUGHNESS = 0.95;
}
"""

@export var areas: Array[AABB] = []
@export var holes: Array[AABB] = []
@export var ground_y: float = 0.0
@export var tolerance: float = 0.35
@export var max_prints: int = 384
@export var life: float = 90.0
@export var stride: float = 0.72

## Prints made this match (tests and the dev overlay).
var made: int = 0
var _mm: MultiMesh
var _mat: ShaderMaterial
var _next: int = 0
var _t: float = 0.0
var _scan: float = 0.0
var _last: Dictionary = {}   # walker instance id -> [last print position, next foot is left]

static var _atlas: ImageTexture


func _ready() -> void:
	var q: QuadMesh = QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2.ONE
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_custom_data = true
	_mm.mesh = q
	_mm.instance_count = max_prints
	for i: int in max_prints:
		_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
		_mm.set_instance_custom_data(i, Color(-1000.0, 0, 0, 0))
	var sh: Shader = Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("atlas", atlas())
	_mat.set_shader_parameter("life", life)
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.name = "Prints"
	mmi.multimesh = _mm
	mmi.material_override = _mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-500, -50, -500), Vector3(1000, 100, 1000))
	add_child(mmi)


## True when a foot at `p` is on open snow.
func on_snow(p: Vector3) -> bool:
	if absf(p.y - ground_y) > tolerance:
		return false
	var flat: Vector3 = Vector3(p.x, ground_y + 0.01, p.z)
	for h: AABB in holes:
		if h.has_point(flat):
			return false
	for a: AABB in areas:
		if a.has_point(flat):
			return true
	return false


func _process(delta: float) -> void:
	_t += delta
	_mat.set_shader_parameter("now", _t)
	_scan -= delta
	if _scan > 0.0:
		return
	_scan = SCAN_SECONDS
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Node3D = n as Node3D
		if p != null and p.visible:
			step(p.get_instance_id(), p.global_position, KIND_BOOT)
	var d: Object = get_parent().get("director") if get_parent() != null else null
	if d != null and d.has_method("active_zombies"):
		for z: Node3D in d.call("active_zombies"):
			step(z.get_instance_id(), z.global_position, KIND_DRAG)


## One walker's position this scan: a print every `stride` metres on snow.
func step(id: int, at: Vector3, kind: float) -> void:
	if not on_snow(at):
		_last.erase(id)
		return
	var e: Array = _last.get(id, [])
	if e.is_empty():
		_last[id] = [at, true]
		return
	var from: Vector3 = e[0]
	var mv: Vector3 = Vector3(at.x - from.x, 0, at.z - from.z)
	if mv.length() < stride:
		return
	var left: bool = e[1]
	_last[id] = [at, not left]
	var fwd: Vector3 = mv.normalized()
	var side: Vector3 = Vector3(-fwd.z, 0, fwd.x) * (0.11 if left else -0.11)
	place(Vector3(at.x, ground_y, at.z) + side, atan2(fwd.x, fwd.z), kind, left)


## A print at `at` (on the ground) facing `yaw` (radians, 0 = +Z).
func place(at: Vector3, yaw: float, kind: float, left: bool = true) -> void:
	var i: int = _next
	_next = (_next + 1) % max_prints
	var sz: Vector3 = Vector3(0.15, 1.0, 0.31) if kind == KIND_BOOT else Vector3(0.2, 1.0, 0.5)
	if not left:
		sz.x = -sz.x   # the right foot: the same print mirrored
	var b: Basis = Basis(Vector3.UP, yaw + randf_range(-0.12, 0.12)) * Basis.from_scale(sz)
	_mm.set_instance_transform(i, Transform3D(b, Vector3(at.x, ground_y + 0.021 + 0.00001 * float(i), at.z)))
	_mm.set_instance_custom_data(i, Color(_t, kind, 0, 0))
	made += 1


## Two prints side by side in a 128 x 64 atlas: a hobnailed boot (left) and a dragged, shuffling foot (right).
## Pressed snow: a cold blue-grey hollow with a bright crushed rim.
static func atlas() -> ImageTexture:
	if _atlas != null:
		return _atlas
	var img: Image = Image.create(128, 64, false, Image.FORMAT_RGBA8)
	var hollow: Color = Color(0.26, 0.31, 0.43)   # pressed snow in shadow: it reads at night
	var rim: Color = Color(0.93, 0.95, 1.0)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 1944
	noise.frequency = 0.15
	for y: int in 64:
		for x: int in 128:
			var c: Color = Color(0, 0, 0, 0)
			var u: float = (float(x % 64) + 0.5) / 64.0 * 2.0 - 1.0    # -1..1 across
			var v: float = (float(y) + 0.5) / 64.0 * 2.0 - 1.0         # -1..1 along (heel at -1)
			var d: float = 0.0
			if x < 64:
				# sole (front, wider) and heel, joined at the waist
				var sole: float = Vector2(u / 0.62, (v - 0.32) / 0.62).length()
				var heel: float = Vector2(u / 0.5, (v + 0.6) / 0.36).length()
				d = minf(sole, heel)
			else:
				# a drag: a long smeared trough, scuffed at the toe
				d = Vector2(u / (0.55 - 0.15 * v), v / 0.95).length()
			var n: float = noise.get_noise_2d(float(x), float(y)) * 0.12
			d += n
			if d < 0.82:
				var k: float = clampf(1.0 - d / 0.82, 0.0, 1.0)
				c = Color(hollow.r, hollow.g, hollow.b, 0.7 + 0.25 * k)
				if x < 64 and int(float(y) * 0.5) % 3 == 0 and d < 0.6:   # the tread
					c = c.darkened(0.1)
			elif d < 1.0:
				c = Color(rim.r, rim.g, rim.b, (1.0 - (d - 0.82) / 0.18) * 0.8)
			img.set_pixel(x, y, c)
	_atlas = ImageTexture.create_from_image(img)
	return _atlas
