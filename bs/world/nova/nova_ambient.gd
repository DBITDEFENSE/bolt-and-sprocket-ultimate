class_name NovaAmbient
extends Node3D
## Nova Plaza's life (populateLife i === 5, novaDress): neon silhouette traffic on the elevated highway, pigeon
## drones pecking around the plazas, moth swarms circling the lamps and cleaning bots polishing floors that
## nobody walks on. All decoration: no colliders, no gameplay. Data: "nova.ambient".

var data: Dictionary = {}
var _cars: Array[Dictionary] = []          # {node, s}
var _path: PackedVector3Array = []
var _path_len: float = 0.0
var _pigeons: Array[Dictionary] = []
var _moths: Array[Dictionary] = []
var _bots: Array[Dictionary] = []
var _t: float = 0.0


func _ready() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(data.get("seed", 55))
	var hw: Dictionary = data.get("traffic", {})
	for p: Variant in hw.get("points", []):
		_path.append(LevelKit.v3(p))
	for i: int in _path.size() - 1:
		_path_len += _path[i].distance_to(_path[i + 1])
	var neon: Array = hw.get("colors", ["#ffd23e", "#3ee6ff", "#ff4d9d", "#9dff5a"])
	for i: int in int(hw.get("cars", 8)):
		var n: Node3D = Node3D.new()
		add_child(n)
		LevelKit.box(n, Vector3(0, 0.4, 0), Vector3(0.9, 0.8, 1.8), neon[i % neon.size()], false, Vector3.ZERO, 1, 0.7)
		LevelKit.box(n, Vector3(0, 0.45, -0.92), Vector3(0.7, 0.15, 0.04), "#ffffff", false, Vector3.ZERO, 1, 2.5)
		_cars.append({"node": n, "s": _path_len * float(i) / float(maxi(1, int(hw.get("cars", 8)))),
			"lane": 1.2 if i % 2 == 0 else -1.2, "speed": float(hw.get("speed", 14.0)) * (1.0 if i % 2 == 0 else -0.8)})
	for pd: Variant in data.get("pigeons", []):
		var p: Vector3 = LevelKit.v3(pd)
		var n2: Node3D = Node3D.new()
		n2.position = p
		add_child(n2)
		LevelKit.box(n2, Vector3(0, 0.15, 0), Vector3(0.22, 0.18, 0.34), "#8a93a8", false)
		LevelKit.box(n2, Vector3(0, 0.28, -0.16), Vector3(0.12, 0.12, 0.12), "#5a6377", false)
		LevelKit.box(n2, Vector3(0, 0.3, -0.23), Vector3(0.04, 0.04, 0.04), "#ff3a4a", false, Vector3.ZERO, 1, 2.0)
		_pigeons.append({"node": n2, "home": p, "phase": rng.randf() * TAU})
	for md: Variant in data.get("moths", []):
		var c: Vector3 = LevelKit.v3(md)
		for k: int in 5:
			var m: MeshInstance3D = LevelKit.box(self, c, Vector3(0.06, 0.06, 0.06), "#fff2b0", false, Vector3.ZERO, 1, 3.0) as MeshInstance3D
			_moths.append({"node": m, "c": c, "r": rng.randf_range(0.4, 1.0), "w": rng.randf_range(2.0, 4.0), "ph": rng.randf() * TAU})
	for bd: Variant in data.get("cleaning_bots", []):
		var b: Dictionary = bd
		var n3: Node3D = Node3D.new()
		add_child(n3)
		LevelKit.cylinder(n3, Vector3(0, 0.12, 0), 0.35, 0.24, "#d8dee9", false)
		LevelKit.box(n3, Vector3(0, 0.3, 0), Vector3(0.3, 0.12, 0.3), "#3ee6ff", false, Vector3.ZERO, 1, 1.5)
		LevelKit.cylinder(n3, Vector3(0, 0.02, 0), 0.42, 0.03, "#9fecff", false, "y", -1.0, 0.6)
		_bots.append({"node": n3, "a": LevelKit.v3(b["a"]), "b": LevelKit.v3(b["b"]), "ph": rng.randf() * TAU})


func _path_point(s: float) -> Array:
	s = fposmod(s, _path_len)
	for i: int in _path.size() - 1:
		var l: float = _path[i].distance_to(_path[i + 1])
		if s <= l:
			var d: Vector3 = (_path[i + 1] - _path[i]).normalized()
			return [_path[i].lerp(_path[i + 1], s / maxf(0.01, l)), d]
		s -= l
	return [_path[_path.size() - 1], Vector3.FORWARD]


func _process(delta: float) -> void:
	_t += delta
	if _path_len > 0.0:
		for c: Dictionary in _cars:
			c["s"] = float(c["s"]) + float(c["speed"]) * delta
			var pd: Array = _path_point(float(c["s"]))
			var d: Vector3 = pd[1]
			var side: Vector3 = Vector3(-d.z, 0, d.x)
			var n: Node3D = c["node"]
			n.position = (pd[0] as Vector3) + side * float(c["lane"])
			n.rotation.y = atan2(-d.x, -d.z) + (PI if float(c["speed"]) < 0.0 else 0.0)
	for p: Dictionary in _pigeons:
		var n2: Node3D = p["node"]
		var ph: float = float(p["phase"]) + _t
		n2.position = (p["home"] as Vector3) + Vector3(sin(ph * 0.4) * 1.2, absf(sin(ph * 3.0)) * 0.05, cos(ph * 0.3) * 1.2)
		n2.rotation.y = ph * 0.4
	for m: Dictionary in _moths:
		var a: float = float(m["ph"]) + _t * float(m["w"])
		(m["node"] as Node3D).position = (m["c"] as Vector3) + Vector3(cos(a), sin(a * 1.7) * 0.4, sin(a)) * float(m["r"])
	for b: Dictionary in _bots:
		var k: float = (sin(_t * 0.5 + float(b["ph"])) + 1.0) * 0.5
		var n3: Node3D = b["node"]
		n3.position = (b["a"] as Vector3).lerp(b["b"], k)
		n3.rotation.y = _t * 2.0
