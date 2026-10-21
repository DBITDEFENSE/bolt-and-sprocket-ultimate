class_name NovaUpdraft
extends Node3D
## A ventilation updraft (addUpdraft / updateUpdrafts L8939, L9038): while Bolt is inside the column
## (radius r, from the grate up to `height`) his vertical speed gains `force` m/s² (source 30), capped at
## `cap` m/s (source 11); his hover refills (+1.5/s) and his air dash comes back. The remake also cancels
## `gravity_comp` m/s² of gravity inside the column (Bolt's rising gravity without jump held is 58, his fall
## gravity 38, both stronger than the source's push, so the shaft would otherwise only slow a fall) and lifts
## a grounded Bolt off the grate at `liftoff` m/s (the ground-stick probe holds anything slower than 0.5).
## Group "updrafts" (meta radius/height/force) for the later Sprocket Glide, which lifts a glide in any updraft.

var updraft_id: String = ""
var radius: float = 3.0
var height: float = 12.0
var force: float = 30.0
var cap: float = 11.0
var gravity_comp: float = 58.0
var liftoff: float = 3.0
var inside: bool = false
var lifted_time: float = 0.0
var _motes: Array[MeshInstance3D] = []
var _t: float = 0.0


func _ready() -> void:
	add_to_group(&"updrafts")
	set_meta(&"radius", radius)
	set_meta(&"height", height)
	set_meta(&"force", force)
	LevelKit.box(self, Vector3(0, 0.08, 0), Vector3(radius * 1.8, 0.16, radius * 1.8), "#39404f", true)
	for i: int in 5:
		LevelKit.box(self, Vector3(-radius * 0.7 + i * radius * 0.35, 0.18, 0), Vector3(0.12, 0.05, radius * 1.6), "#141a30", false)
	var col: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.cap_top = false
	cm.cap_bottom = false
	col.mesh = cm
	col.material_override = NovaArt.glow("#9fecff", 0.08)
	col.position.y = height * 0.5
	add_child(col)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(updraft_id)
	for i: int in 10:
		var m: MeshInstance3D = LevelKit.box(self, Vector3(rng.randf_range(-0.7, 0.7) * radius, rng.randf() * height,
			rng.randf_range(-0.7, 0.7) * radius), Vector3(0.12, 0.35, 0.12), "#cff6ff", false, Vector3.ZERO, 1, 1.6) as MeshInstance3D
		_motes.append(m)


func contains(p: Vector3) -> bool:
	var l: Vector3 = p - global_position
	return Vector2(l.x, l.z).length() < radius and l.y > -0.5 and l.y < height


func _physics_process(delta: float) -> void:
	var p: Node3D = LevelKit.player(get_tree())
	inside = p != null and contains(p.global_position)
	if not inside:
		return
	lifted_time += delta
	var m: Object = p.get("motor")
	if m == null:
		return
	var v: Vector3 = m.get("vel")
	if bool(m.get("on_ground")):
		v.y = maxf(v.y, liftoff)
	v.y = minf(v.y + (force + gravity_comp) * delta, cap)
	m.set("vel", v)
	m.set("hover", minf(1.0, float(m.get("hover")) + delta * 1.5))
	m.set("air_dash_used", false)


func _process(delta: float) -> void:
	_t += delta
	for i: int in _motes.size():
		var mm: MeshInstance3D = _motes[i]
		mm.position.y = fposmod(mm.position.y + delta * (4.0 + float(i % 3) * 2.0), height)
