class_name TollMark
extends Node3D
## The Totenglocke's resonance mark (T-048): a zombie that survived a toll is "tolled" for `seconds`. A faint,
## ringing bronze halo sits around its chest; the next toll always shatters it. A small component node added as
## a child of the zombie (no state on Zombie itself). It frees itself when the mark runs out, when the zombie
## dies, and when the pool hides the zombie (deactivate() -> hide(): visibility_changed), so a recycled
## zombie never comes back marked.

const NODE_NAME: String = "TollMark"

var seconds: float = 20.0
var color: Color = Color(1.0, 0.62, 0.25)
var _t: float = 0.0
var _z: Zombie = null
var _mats: Array[StandardMaterial3D] = []
var _rings: Array[MeshInstance3D] = []


## Marks `z` (or refreshes its mark).
static func apply(z: Zombie, col: Color, secs: float) -> TollMark:
	var m: TollMark = z.get_node_or_null(NODE_NAME) as TollMark
	if m == null or m.is_queued_for_deletion():
		m = TollMark.new()
		m.name = NODE_NAME
		m.color = col
		z.add_child(m)
	m.color = col
	m.seconds = secs
	m._t = 0.0
	return m


## Is `z` tolled right now?
static func is_on(z: Zombie) -> bool:
	if z == null:
		return false
	var m: TollMark = z.get_node_or_null(NODE_NAME) as TollMark
	return m != null and not m.is_queued_for_deletion() and m._t < m.seconds and z.is_active() and z.visible


func _ready() -> void:
	_z = get_parent() as Zombie
	if _z != null:
		_z.visibility_changed.connect(_on_vis)
	for i: int in 2:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var tm: TorusMesh = TorusMesh.new()
		tm.inner_radius = 0.34 + 0.08 * i
		tm.outer_radius = 0.37 + 0.08 * i
		tm.rings = 32
		tm.ring_segments = 4
		mi.mesh = tm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.no_depth_test = false
		m.albedo_color = Color(color, 0.0)
		mi.material_override = m
		add_child(mi)
		_mats.append(m)
		_rings.append(mi)
	_place()


func _place() -> void:
	position = Vector3(0, 0.45 if _z != null and _z.is_crawler else 1.12, 0)


func _on_vis() -> void:
	if _z != null and not _z.visible:
		queue_free()


func _process(delta: float) -> void:
	_t += delta
	if _z == null or not _z.is_active() or _t >= seconds:
		queue_free()
		return
	_place()
	var fade_in: float = clampf(_t / 0.25, 0.0, 1.0)
	var fade_out: float = clampf((seconds - _t) / 1.5, 0.0, 1.0)
	for i: int in _rings.size():
		var ring: MeshInstance3D = _rings[i]
		var ph: float = _t * (7.0 + 3.0 * i) + i * 1.7
		ring.rotation = Vector3(sin(ph * 0.5) * 0.25, _t * (1.5 - 3.0 * i), cos(ph * 0.4) * 0.25)
		var pulse: float = 0.5 + 0.5 * sin(ph)
		_mats[i].albedo_color = Color(color, (0.22 + 0.33 * pulse) * fade_in * fade_out)
		ring.scale = Vector3.ONE * (1.0 + 0.06 * sin(ph * 1.3))
