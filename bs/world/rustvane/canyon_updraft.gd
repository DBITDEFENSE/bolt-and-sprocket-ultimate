class_name CanyonUpdraft
extends Node3D
## A canyon wind updraft (addUpdraft / its update loop, index.html:8939, 9038; BS_LEVELS §3.5). Warm air rising
## off the pit: while it blows and Bolt is inside the column (horizontal distance < r, base < y < base + h) his
## vertical speed gains `force` m/s² up to 11 m/s, hover refills (1.5/s) and the air dash comes back. As in
## the source it boosts the jetpack: hold JUMP to ride it (rising gravity 22 < force 30).
## Rustvane's columns pulse: `on_time` s blowing, `off_time` s still, shown by the dust plume and the column.
## position = the vent's centre on the floor.

var radius: float = 2.4
var height: float = 12.0
var force: float = 30.0
var max_vy: float = 11.0
var hover_regen: float = 1.5
var on_time: float = 3.0
var off_time: float = 1.5
var phase: float = 0.0
var blowing: bool = true
var lifted_t: float = 0.0         # seconds Bolt has spent being lifted (tests)
var _t: float = 0.0
var _col: MeshInstance3D
var _col_mat: StandardMaterial3D
var _motes: Array[MeshInstance3D] = []


func _ready() -> void:
	process_physics_priority = 10
	add_to_group(&"updrafts")
	_t = phase
	LevelKit.box(self, Vector3(0, -0.2, 0), Vector3(radius * 1.8, 0.4, radius * 1.8), "#39404f", false)
	for k: int in 4:
		LevelKit.box(self, Vector3(-radius * 0.6 + k * radius * 0.4, 0.02, 0), Vector3(0.12, 0.06, radius * 1.6), "#232838", false)
	_col = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 20
	cm.cap_top = false
	cm.cap_bottom = false
	_col.mesh = cm
	_col_mat = StandardMaterial3D.new()
	_col_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_col_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_col_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_col_mat.albedo_color = Color(1.0, 0.86, 0.62, 0.12)
	_col.material_override = _col_mat
	_col.position.y = height * 0.5
	_col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_col)
	for i: int in 7:
		var m: MeshInstance3D = MeshInstance3D.new()
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = 0.18
		sm.height = 0.36
		sm.radial_segments = 6
		sm.rings = 3
		m.mesh = sm
		m.material_override = LevelKit.mat("#e8c89a", 0.5)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		_motes.append(m)


func is_blowing() -> bool:
	return blowing


func contains(p: Vector3) -> bool:
	var g: Vector3 = global_position
	return Vector2(p.x - g.x, p.z - g.z).length() < radius and p.y > g.y and p.y < g.y + height


func _physics_process(delta: float) -> void:
	_t += delta
	var cycle: float = on_time + off_time
	blowing = off_time <= 0.0 or fmod(_t, cycle) < on_time
	if not blowing:
		return
	var b: Bolt = LevelKit.player(get_tree()) as Bolt
	if b == null or b.dead or not Gadget.body_free(b) or not contains(b.global_position):
		return
	b.motor.vel.y = minf(b.motor.vel.y + force * delta, max_vy)
	b.motor.hover = minf(1.0, b.motor.hover + delta * hover_regen)
	b.motor.air_dash_used = false
	lifted_t += delta


func _process(_delta: float) -> void:
	if _col_mat == null:
		return
	_col_mat.albedo_color.a = 0.14 if blowing else 0.03
	for i: int in _motes.size():
		var m: MeshInstance3D = _motes[i]
		var k: float = fmod(_t * (0.45 if blowing else 0.08) + float(i) / float(_motes.size()), 1.0)
		var a: float = float(i) * 2.4 + _t * 0.6
		m.position = Vector3(cos(a) * radius * 0.55, k * height, sin(a) * radius * 0.55)
		m.visible = blowing or k < 0.15
