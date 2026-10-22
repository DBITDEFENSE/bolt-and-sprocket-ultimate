class_name CrowFlock
extends Node3D
## Crows on the telephone wires by the crossroads (Update 02 section 7, T-052). They sit hunched on the wire;
## the first shots nearby scatter them cawing into the sky, they wheel over the field and leave for the woods,
## and once it has been quiet for a while they drift back to the wire one by one. Presentation only.

enum S { PERCHED, FLEEING, AWAY, RETURNING }

var cfg: Dictionary = {}
var crows: Array = []        # each: {node, wing_l, wing_r, state, perch, pos, vel, t, phase, wait}
var quiet: float = 999.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _caw_cd: float = 0.0
static var _body_mesh: ArrayMesh
static var _mat: StandardMaterial3D


## Perches along the wires between the inn's six telephone poles (gen_map00: x -30..40 every 14 m, z -15.5,
## crossarm 6.5 m), the sag of the span included.
static func wire_perches(count: int, seed_v: int) -> Array[Vector3]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	var out: Array[Vector3] = []
	while out.size() < count:
		var span: int = rng.randi_range(0, 4)
		var x0: float = -30.0 + span * 14.0
		var u: float = rng.randf_range(0.15, 0.85)
		var wire_x: float = [-0.75, -0.3, 0.3, 0.75][rng.randi_range(0, 3)]
		var sag: float = (14.0 * 0.035 + 0.15) * 4.0 * u * (1.0 - u)
		out.append(Vector3(x0 + u * 14.0 + wire_x, 6.6 - sag + 0.02, -15.5))
	return out


func setup(c: Dictionary, seed_v: int) -> void:
	cfg = c
	_rng.seed = seed_v
	for p: Vector3 in wire_perches(int(c.get("count", 11)), seed_v):
		var n: Node3D = Node3D.new()
		n.name = "Crow"
		add_child(n)
		var body: MeshInstance3D = MeshInstance3D.new()
		body.mesh = _body()
		body.material_override = _material()
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(body)
		var wings: Array[Node3D] = []
		for side: float in [-1.0, 1.0]:
			var w: Node3D = Node3D.new()
			w.position = Vector3(side * 0.05, 0.12, 0.0)
			n.add_child(w)
			var wm: MeshInstance3D = MeshInstance3D.new()
			wm.mesh = Props.unit_box()
			wm.material_override = _material()
			wm.scale = Vector3(0.34, 0.012, 0.16)
			wm.position = Vector3(side * 0.17, 0, 0.02)
			wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			w.add_child(wm)
			wings.append(w)
		n.position = p
		n.rotation.y = _rng.randf_range(-0.4, 0.4) + (PI if _rng.randf() < 0.5 else 0.0)
		crows.append({"node": n, "wings": wings, "state": S.PERCHED, "perch": p, "vel": Vector3.ZERO, "t": 0.0,
			"phase": _rng.randf() * TAU, "wait": 0.0})
		_fold(crows.back())


static func _body() -> ArrayMesh:
	if _body_mesh != null:
		return _body_mesh
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(Props.unit_sphere(), 0, Transform3D(Basis.from_scale(Vector3(0.13, 0.15, 0.3)), Vector3(0, 0.12, 0)))
	st.append_from(Props.unit_sphere(), 0, Transform3D(Basis.from_scale(Vector3(0.09, 0.09, 0.1)), Vector3(0, 0.2, -0.15)))
	st.append_from(Props.unit_box(), 0, Transform3D(Basis.from_scale(Vector3(0.025, 0.02, 0.07)), Vector3(0, 0.19, -0.23)))
	st.append_from(Props.unit_box(), 0, Transform3D(Basis(Vector3.RIGHT, 0.4) * Basis.from_scale(Vector3(0.09, 0.015, 0.16)), Vector3(0, 0.09, 0.2)))
	_body_mesh = st.commit()
	return _body_mesh


static func _material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.albedo_color = Color(0.02, 0.02, 0.025)
		_mat.roughness = 0.6
		_mat.metallic_specular = 0.6
	return _mat


func _fold(c: Dictionary) -> void:
	for w: Node3D in c["wings"]:
		w.rotation = Vector3(0, 0, 0)
		w.scale = Vector3(0.35, 1, 1)


## Gunfire at `at`: everything perched within the scatter radius takes off.
func gunfire(at: Vector3) -> void:
	quiet = 0.0
	var r: float = float(cfg.get("scatter_radius", 85.0))
	var any: bool = false
	for c: Dictionary in crows:
		if c["state"] == S.PERCHED or c["state"] == S.RETURNING:
			var n: Node3D = c["node"]
			if n.global_position.distance_to(at) > r:
				continue
			c["state"] = S.FLEEING
			c["t"] = 0.0
			c["vel"] = Vector3(_rng.randf_range(-3, 3), _rng.randf_range(4, 6), _rng.randf_range(-3, 1))
			c["wait"] = _rng.randf_range(0.0, 0.5)
			any = true
	if any and _caw_cd <= 0.0:
		_caw_cd = 4.0
		var mid: Vector3 = (crows[0]["node"] as Node3D).global_position if not crows.is_empty() else Vector3.ZERO
		AudioDirector.play_3d(str(cfg.get("flap_sound", "")), mid, 0.0)
		get_tree().create_timer(0.3).timeout.connect(func() -> void: AudioDirector.play_3d(str(cfg.get("sound", "")), mid + Vector3(0, 6, 0), 0.0))
		get_tree().create_timer(1.4).timeout.connect(func() -> void: AudioDirector.play_3d(str(cfg.get("sound", "")), mid + Vector3(4, 10, -6), -3.0))


func perched_count() -> int:
	var n: int = 0
	for c: Dictionary in crows:
		if c["state"] == S.PERCHED:
			n += 1
	return n


func _process(delta: float) -> void:
	quiet += delta
	_caw_cd -= delta
	var woods: Vector3 = Vector3(-90, 30, -150)
	for c: Dictionary in crows:
		var n: Node3D = c["node"]
		c["t"] = float(c["t"]) + delta
		match c["state"]:
			S.PERCHED:
				# the odd shuffle and wing-shrug
				if _rng.randf() < delta * 0.05:
					n.rotation.y += _rng.randf_range(-0.6, 0.6)
			S.FLEEING:
				if float(c["t"]) < float(c["wait"]):
					continue
				# climb, wheel once over the field, then head for the woods
				var tt: float = float(c["t"]) - float(c["wait"])
				var target: Vector3 = Vector3(10, 26, -30) + Vector3(cos(tt * 0.7 + float(c["phase"])), 0.2 * sin(tt), sin(tt * 0.7 + float(c["phase"]))) * 22.0
				if tt > 7.0:
					target = woods
				var v: Vector3 = c["vel"]
				v = v.lerp((target - n.global_position).normalized() * 9.0, delta * 1.2)
				c["vel"] = v
				n.global_position += v * delta
				n.look_at(n.global_position + v, Vector3.UP)
				_flap(c, 9.0)
				if n.global_position.distance_to(woods) < 15.0 or tt > 30.0:
					c["state"] = S.AWAY
					n.visible = false
			S.AWAY:
				if quiet > float(cfg.get("return_after_quiet", 28.0)) and _rng.randf() < delta * 0.25:
					c["state"] = S.RETURNING
					c["t"] = 0.0
					n.visible = true
					n.global_position = woods
			S.RETURNING:
				var to: Vector3 = (c["perch"] as Vector3) + Vector3(0, 1.2, 0)
				var d: Vector3 = to - n.global_position
				if d.length() < 0.6:
					n.global_position = c["perch"]
					n.rotation = Vector3(0, _rng.randf_range(-0.4, 0.4) + (PI if _rng.randf() < 0.5 else 0.0), 0)
					c["state"] = S.PERCHED
					_fold(c)
					continue
				var v2: Vector3 = (c["vel"] as Vector3).lerp(d.normalized() * minf(8.0, d.length() * 1.5 + 1.0), delta * 1.5)
				c["vel"] = v2
				n.global_position += v2 * delta
				if v2.length() > 0.1:
					n.look_at(n.global_position + Vector3(v2.x, 0.0, v2.z) + Vector3(0, v2.y * 0.3, 0), Vector3.UP)
				_flap(c, 7.0 if d.length() > 4.0 else 3.0)


func _flap(c: Dictionary, rate: float) -> void:
	var a: float = sin(float(c["t"]) * rate + float(c["phase"])) * 0.9
	var ws: Array = c["wings"]
	(ws[0] as Node3D).scale = Vector3.ONE
	(ws[1] as Node3D).scale = Vector3.ONE
	(ws[0] as Node3D).rotation.z = -a
	(ws[1] as Node3D).rotation.z = a
