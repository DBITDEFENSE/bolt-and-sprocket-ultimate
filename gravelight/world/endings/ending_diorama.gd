class_name EndingDiorama
extends Node3D
## A stock shot for the cancel ending (UPDATE 07 Map 4 Act IV, docs/MAP4_FERNFLUG.md §11.5, T-113): a small greybox
## vignette of an earlier map built far below the relay (no scene is loaded): the inn's taproom, the salt chapel,
## Totenhafen's pens, the works' canteen, London's rooftops, a burned city's harbour. Each has a camera post and a
## `settle()` the ending calls when the shot lands (the Gänger sits, the bell stops, the snow stops, the fire goes
## out). `build(parent, id, at)` makes one; ids in data/gravelight/cards_m4.json "dioramas".

var kind: String = "inn"
var cam_pos: Vector3 = Vector3(0, 1.6, 6)
var cam_look: Vector3 = Vector3(0, 1.0, 0)
var _movers: Array[Node3D] = []
var _lights: Array[Light3D] = []
var _snow: CPUParticles3D = null


static func build(parent: Node, id: String, at: Vector3) -> EndingDiorama:
	var d: EndingDiorama = EndingDiorama.new()
	d.kind = id
	d.name = "Diorama_" + id
	parent.add_child(d)
	d.global_position = at
	d._build()
	return d


func _lamp(pos: Vector3, color: Color, energy: float, range_: float) -> OmniLight3D:
	var l: OmniLight3D = OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_
	l.shadow_enabled = false
	add_child(l)
	_lights.append(l)
	return l


func _figure(pos: Vector3, key: String, seated: bool = false) -> Node3D:
	var f: Node3D = Props.group(self, "Figure", pos)
	if seated:
		Props.block(f, Vector3(-0.2, 0.45, -0.15), Vector3(0.2, 1.05, 0.15), key)
		Props.block(f, Vector3(-0.2, 0.45, 0.15), Vector3(0.2, 0.6, 0.6), key)
	else:
		Props.block(f, Vector3(-0.2, 0.0, -0.15), Vector3(0.2, 1.5, 0.15), key)
	Props.ball(f, Vector3(0, 1.2 if seated else 1.65, 0), Vector3(0.28, 0.28, 0.28), key)
	_movers.append(f)
	return f


func _build() -> void:
	Props.block(self, Vector3(-12, -0.5, -12), Vector3(12, 0, 12), "concrete")
	match kind:
		"inn":
			Props.block(self, Vector3(-6, 0, -6), Vector3(6, 0.1, 6), "floorboards")
			for w: Array in [[Vector3(-6, 0, -6.3), Vector3(6, 4, -6)], [Vector3(-6.3, 0, -6), Vector3(-6, 4, 6)], [Vector3(6, 0, -6), Vector3(6.3, 4, 6)]]:
				Props.block(self, w[0], w[1], "plaster")
			Props.block(self, Vector3(-4, 0, -5.5), Vector3(4, 1.1, -4.5), "walnut")   # the bar
			Props.bench(self, Vector3(0, 0, -3.2), 0.0, 3.0)
			_figure(Vector3(0, 0, -3.6), "feldgrau")   # the Gänger, standing at the bar
			Props.block(self, Vector3(4.5, 0, -1), Vector3(5.9, 2.2, 1), "fieldstone")   # the hearth
			_lamp(Vector3(4.8, 0.8, 0), Color(1.0, 0.6, 0.3), 2.5, 9.0)
			_lamp(Vector3(0, 3.2, 0), Color(1.0, 0.8, 0.55), 0.9, 10.0)
			cam_pos = Vector3(-3.5, 1.5, 3.5)
			cam_look = Vector3(0, 1.0, -3.5)
		"chapel":
			Props.block(self, Vector3(-5, 0, -8), Vector3(5, 0.1, 8), "halite_floor")
			for w: Array in [[Vector3(-5.3, 0, -8), Vector3(-5, 7, 8)], [Vector3(5, 0, -8), Vector3(5.3, 7, 8)], [Vector3(-5, 0, -8.3), Vector3(5, 7, -8)]]:
				Props.block(self, w[0], w[1], "halite")
			for pz: float in [-4.0, -1.5, 1.0, 3.5]:
				Props.bench(self, Vector3(-2, 0, pz), 0.0, 2.6)
				Props.bench(self, Vector3(2, 0, pz), 0.0, 2.6)
			Props.strut(self, Vector3(-1.5, 0, -6.5), Vector3(-1.5, 5.0, -6.5), 0.12, "iron")
			Props.strut(self, Vector3(1.5, 0, -6.5), Vector3(1.5, 5.0, -6.5), 0.12, "iron")
			Props.strut(self, Vector3(-1.5, 5.0, -6.5), Vector3(1.5, 5.0, -6.5), 0.1, "iron")
			var bell: Node3D = Props.group(self, "Bell", Vector3(0, 4.2, -6.5))
			Props.bell(bell, Vector3.ZERO, 0.8, "brass")
			_movers.append(bell)
			_lamp(Vector3(0, 5.5, 0), Color(0.6, 0.7, 1.0), 1.2, 14.0)
			_snow = _make_snow(Vector3(0, 7, 0), Vector3(5, 0.5, 8), Color(0.9, 0.93, 1.0))
			cam_pos = Vector3(0, 2.0, 7.0)
			cam_look = Vector3(0, 3.0, -6.5)
		"pens":
			Props.block(self, Vector3(-12, -0.3, -12), Vector3(12, -0.1, 0), "sea_water")
			Props.block(self, Vector3(-12, 0, 0), Vector3(12, 0.3, 12), "pier_concrete")
			for px: float in [-6.0, 0.0, 6.0]:
				Props.block(self, Vector3(px - 1.5, 0.3, 1), Vector3(px + 1.5, 2.6, 6), "wet_concrete")
			Props.strut(self, Vector3(-9, 0.3, 0), Vector3(-9, 0.3, -6), 0.15, "planks")
			_lamp(Vector3(0, 4, 2), Color(0.55, 0.65, 0.9), 0.8, 20.0)
			cam_pos = Vector3(-7, 2.2, 9)
			cam_look = Vector3(0, 0, -4)
		"canteen":
			Props.block(self, Vector3(-8, 0, -8), Vector3(8, 0.1, 8), "tile_floor")
			for w: Array in [[Vector3(-8, 0, -8.3), Vector3(8, 4, -8)], [Vector3(-8.3, 0, -8), Vector3(-8, 4, 8)]]:
				Props.block(self, w[0], w[1], "limewash")
			for tz: float in [-4.0, 0.0, 4.0]:
				Props.table_visual(self, Vector3(-2, 0, tz), 3.0, 1.0)
				Props.table_visual(self, Vector3(3, 0, tz), 3.0, 1.0)
			Props.block(self, Vector3(-7.8, 2.6, -2), Vector3(-7.3, 3.2, -1), "bakelite")   # the PA box
			Props.block(self, Vector3(2, 2.2, -7.95), Vector3(5, 3.6, -7.9), "glass")   # the office window
			_lamp(Vector3(3.5, 2.9, -7.0), Color(1.0, 0.85, 0.6), 1.6, 7.0)
			_lamp(Vector3(0, 3.6, 0), Color(0.9, 0.9, 0.8), 0.6, 12.0)
			cam_pos = Vector3(5, 1.8, 7)
			cam_look = Vector3(-2, 1.4, -4)
		"london":
			for i: int in 14:
				var hx: float = -11.0 + 1.7 * float(i)
				var h: float = 2.0 + float((i * 7) % 5) * 1.1
				Props.block(self, Vector3(hx, 0, -4 + float(i % 4) * 2.0), Vector3(hx + 1.4, h, -2 + float(i % 4) * 2.0), "brick")
				if i % 3 == 0:
					Props.block(self, Vector3(hx + 0.3, h, -3.5 + float(i % 4) * 2.0), Vector3(hx + 0.7, h + 1.0, -3.2 + float(i % 4) * 2.0), "brick")
			_lamp(Vector3(0, 9, -10), Color(0.75, 0.55, 1.0), 1.2, 30.0)
			_lamp(Vector3(12, 6, 4), Color(1.0, 0.75, 0.5), 0.0, 40.0)   # the dawn, lit on settle
			_snow = _make_snow(Vector3(0, 9, -2), Vector3(12, 0.5, 6), Color(0.75, 0.5, 1.0))
			cam_pos = Vector3(0, 7.5, 8)
			cam_look = Vector3(0, 3.0, -4)
		_:
			Props.block(self, Vector3(-12, -0.3, -12), Vector3(12, -0.1, -2), "sea_water")
			Props.block(self, Vector3(-12, 0, -2), Vector3(12, 0.3, 12), "pier_concrete")
			for wx: float in [-7.0, 0.0, 7.0]:
				Props.block(self, Vector3(wx - 2.5, 0.3, 2), Vector3(wx + 2.5, 4.0, 8), "brick")
			Props.block(self, Vector3(-3, 0.3, 0), Vector3(3, 1.2, 1.5), "wreck")
			_lamp(Vector3(0, 2.5, 4), Color(1.0, 0.5, 0.2), 3.0, 18.0)   # the fire, out on settle
			_lamp(Vector3(0, 8, -8), Color(0.5, 0.6, 0.9), 0.6, 30.0)
			cam_pos = Vector3(-6, 3.0, -8)
			cam_look = Vector3(0, 1.5, 4)


func _make_snow(at: Vector3, extents: Vector3, color: Color) -> CPUParticles3D:
	var s: CPUParticles3D = CPUParticles3D.new()
	s.position = at
	s.amount = 160
	s.lifetime = 5.0
	s.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	s.emission_box_extents = extents
	s.direction = Vector3(0, -1, 0)
	s.gravity = Vector3(0, -1.2, 0)
	s.initial_velocity_min = 0.3
	s.initial_velocity_max = 0.8
	s.scale_amount_min = 0.06
	s.scale_amount_max = 0.14
	s.mesh = BoxMesh.new()
	s.mesh.set("size", Vector3(0.12, 0.12, 0.12))
	s.material_override = Interactable.greybox_mat(color, 2.0)
	add_child(s)
	return s


## The shot lands: the moment the relay's silence reaches this place.
func settle(k: float = 1.0) -> void:
	match kind:
		"inn":
			if not _movers.is_empty():
				var g: Node3D = _movers[0]
				var tw: Tween = g.create_tween()
				tw.tween_property(g, "position", Vector3(0, 0, -3.0), 1.6 * k).set_trans(Tween.TRANS_SINE)
				tw.parallel().tween_property(g, "scale:y", 0.72, 1.6 * k)
			if _lights.size() > 0:
				var fire: Tween = create_tween()
				fire.tween_property(_lights[0], "light_energy", 3.4, 0.1 * k)
				fire.tween_property(_lights[0], "light_energy", 2.2, 0.5 * k)
		"chapel":
			if not _movers.is_empty():
				var bell: Node3D = _movers[0]
				var tw2: Tween = bell.create_tween()
				tw2.tween_property(bell, "rotation:z", 0.0, 1.2 * k).set_trans(Tween.TRANS_SINE)
		"london":
			if _snow != null:
				_snow.emitting = false
			if _lights.size() > 1:
				var tw3: Tween = create_tween()
				tw3.tween_property(_lights[1], "light_energy", 1.4, 3.0 * k)
				tw3.parallel().tween_property(_lights[0], "light_energy", 0.0, 3.0 * k)
		"pens", "canteen":
			pass
		_:
			if _lights.size() > 0:
				var tw4: Tween = create_tween()
				tw4.tween_property(_lights[0], "light_energy", 0.0, 2.5 * k)
	if kind == "chapel" and not _movers.is_empty():
		_movers[0].rotation.z = 0.35   # swinging when the shot opens; settles to still
