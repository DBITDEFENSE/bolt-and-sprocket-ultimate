class_name KaltenLandscape
extends Landscape
## The world beyond Kaltenbrunn's Minehead Yard (UPDATE 10 section 5, DECISIONS T-161): the shelf the mine stands on
## breaks away into a snow valley; across it the forested foothills and two Alpine ridge bands; the night-sky dome
## (Map 0's, so MapAmbience's flashes, beams and flights work unchanged); a snow-buried rail line running off down
## the valley's flank with its telegraph poles; the dead cable car hanging over the valley on its two towers; the
## minehead siren on the headframe. Built at load time from code (deterministic), nothing here collides and the
## navmesh never sees it. MapAmbience (data/gravelight/map01_ambience.json) animates it: the gondola swings, the
## siren wails, the avalanche rumbles off a ridge.
##
## It extends Landscape so MapAmbience finds it with Landscape.find() and reads sky_mat and the pointers below; the
## Map 0 members (farm, church, town, wreck...) simply stay empty. Terrain, ridges and the tree scatter come from
## KaltenTerrain through LandscapeTerrain.use_profile(), so Map 0's bearing/height functions serve this map too.

const CABLE_SAG: float = 7.0
const GONDOLA_T: float = 0.3
const SIREN_POS: Vector3 = Vector3(20.0, 29.6, 15.0)

## The gondola's swing pivot (MapAmbience rotates it) and where the cable meets it.
var cable_pivot: Node3D
var cable_pos: Vector3 = Vector3.ZERO
var cable_tower_a: Vector3 = Vector3.ZERO
var cable_tower_b: Vector3 = Vector3.ZERO
## The siren horn on the headframe and its lamp (MapAmbience pulses the lamp during the wail).
var siren_node: Node3D
var siren_lamp: OmniLight3D
var tree_counts: Dictionary = {}


func build() -> void:
	if built:
		return
	built = true
	LandscapeTerrain.use_profile(KaltenTerrain.CENTER, KaltenTerrain.height, KaltenTerrain.ridge_crest)
	LandscapeTerrain._noises()
	var t0: int = Time.get_ticks_msec()
	_static = Node3D.new()
	_static.name = "Static"
	add_child(_static)
	_build_sky()
	sky_mat.set_shader_parameter("town_dir", LandscapeTerrain.dir_of(232.0))
	_build_terrain_k()
	_build_forests_k()
	_build_mist()
	_build_rail()
	_build_cable_car()
	_build_siren()
	var merged: int = _batch(_static)
	_sync_env(true)
	print("[kalten] landscape built in %d ms (%d static meshes batched; %d mesh trees, %d impostor cards)" % [Time.get_ticks_msec() - t0, merged,
		int(tree_counts.get("mesh", 0)), int(tree_counts.get("cards", 0))])


# ================================================================== terrain, ridges, forest

func _build_terrain_k() -> void:
	var mesh: ArrayMesh = KaltenTerrain.build_grid()
	var near: ShaderMaterial = ShaderMaterial.new()
	near.shader = _shader("near_land.gdshader")
	_near_land_textures(near)
	mesh.surface_set_material(0, near)
	if mesh.get_surface_count() > 1:
		mesh.surface_set_material(1, _far_mat("far_land.gdshader", {"fog_max": 0.84, "fog_k": 0.02}))
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	for band: int in 2:
		var r: MeshInstance3D = MeshInstance3D.new()
		r.name = "RidgeBand%d" % band
		r.mesh = LandscapeTerrain.build_ridge(band, 240)
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		r.material_override = _far_mat("far_land.gdshader", {"ridge": 1.0, "fog_max": 0.84, "fog_k": 0.02, "fog_bias": 0.04 if band == 1 else 0.0,
			"noise_scale": 0.03})
		add_child(r)


func _build_forests_k() -> void:
	var tr: Dictionary = KaltenTerrain.forest_transforms(8.0, 17)
	var sectors: int = 8
	var mesh_by: Array = []
	var card_by: Array = []
	for s: int in sectors:
		mesh_by.append([] as Array[Transform3D])
		card_by.append([] as Array[Transform3D])
	for xf: Transform3D in tr["mesh"]:
		(mesh_by[_sector(xf.origin, sectors)] as Array[Transform3D]).append(uniform_tree_xform(xf))
	for xf2: Transform3D in tr["cards"]:
		var hgt: float = xf2.basis.get_scale().y
		(card_by[_sector(xf2.origin, sectors)] as Array[Transform3D]).append(Transform3D(Basis.from_scale(Vector3(hgt * 0.42, hgt, 1.0)), xf2.origin))
	for xf3: Transform3D in LandscapeTerrain.ridge_tree_transforms(1700, 23):
		(card_by[_sector(xf3.origin, sectors)] as Array[Transform3D]).append(xf3)
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(1, 1)
	var card_mat: ShaderMaterial = _far_mat("impostor_pine.gdshader")
	var spruce: Mesh = tree_mesh("Spruce_LOD1", false)
	if spruce != null:
		for m: String in ["needles", "bark", "twigs", "birch_bark"]:
			far_mats.append(tree_material(m, false))
	var n_mesh: int = 0
	var n_card: int = 0
	for s2: int in sectors:
		var ml: Array = mesh_by[s2]
		var cl: Array = card_by[s2]
		if not ml.is_empty():
			if spruce != null:
				_multimesh("SpruceMid%d" % s2, spruce, ml, null)
			else:
				cl.append_array(ml)
		if not cl.is_empty():
			_multimesh("PineCards%d" % s2, quad, cl, card_mat, 30.0)
		n_mesh += ml.size() if spruce != null else 0
		n_card += cl.size()
	tree_counts = {"mesh": n_mesh, "cards": n_card}


static func _sector(p: Vector3, sectors: int) -> int:
	return int(LandscapeTerrain.bearing(p.x, p.z) / (360.0 / sectors)) % sectors


# ================================================================== the snow-buried rail line

func _ground_k(x: float, z: float, lift: float = 0.0) -> Vector3:
	return Vector3(x, KaltenTerrain.height(x, z) + lift, z)


func _build_rail() -> void:
	var g: Node3D = Props.group(_static, "RailLine", Vector3.ZERO)
	var iron: Material = Mats.get_mat("iron")
	var bed: Material = Mats.get_mat("snow")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1947
	# walk the polyline in 3 m steps; rails show where the wind has scoured the drifts (about half the length)
	var pts: Array[Vector3] = []
	var total: float = 0.0
	for i: int in KaltenTerrain.RAIL.size() - 1:
		var a: Vector3 = KaltenTerrain.RAIL[i]
		var b: Vector3 = KaltenTerrain.RAIL[i + 1]
		var a2: Vector2 = Vector2(a.x, a.y)
		var b2: Vector2 = Vector2(b.x, b.y)
		var len: float = a2.distance_to(b2)
		var steps: int = maxi(1, int(len / 3.0))
		for k: int in steps:
			var p: Vector2 = a2.lerp(b2, float(k) / float(steps))
			pts.append(Vector3(p.x, 0.0, p.y))
		total += len
	var last: Vector3 = KaltenTerrain.RAIL[KaltenTerrain.RAIL.size() - 1]
	pts.append(Vector3(last.x, 0.0, last.y))
	var st_rail: SurfaceTool = SurfaceTool.new()
	st_rail.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_bed: SurfaceTool = SurfaceTool.new()
	st_bed.begin(Mesh.PRIMITIVE_TRIANGLES)
	var box: BoxMesh = Props.unit_box()
	var shown: bool = true
	for i2: int in pts.size() - 1:
		var p0: Vector3 = _ground_k(pts[i2].x, pts[i2].z, 0.06)
		var p1: Vector3 = _ground_k(pts[i2 + 1].x, pts[i2 + 1].z, 0.06)
		var d: Vector3 = p1 - p0
		if d.length() < 0.01:
			continue
		var fwd: Vector3 = d.normalized()
		var side: Vector3 = fwd.cross(Vector3.UP).normalized()
		var basis_f: Basis = Basis(side, side.cross(fwd).normalized(), -fwd)
		# the embankment as one long low box with snow on it
		st_bed.append_from(box, 0, Transform3D(basis_f * Basis.from_scale(Vector3(3.4, 0.28, d.length() + 0.1)), (p0 + p1) * 0.5 - Vector3(0, 0.05, 0)))
		if rng.randf() < 0.18:
			shown = not shown
		if shown:
			for s: float in [-0.72, 0.72]:
				st_rail.append_from(box, 0, Transform3D(basis_f * Basis.from_scale(Vector3(0.1, 0.12, d.length() + 0.05)), (p0 + p1) * 0.5 + side * s + Vector3(0, 0.1, 0)))
			if i2 % 2 == 0:   # sleeper ends
				st_rail.append_from(box, 0, Transform3D(basis_f * Basis.from_scale(Vector3(2.3, 0.09, 0.28)), (p0 + p1) * 0.5 + Vector3(0, 0.03, 0)))
	var bed_mi: MeshInstance3D = MeshInstance3D.new()
	bed_mi.name = "RailBed"
	bed_mi.mesh = st_bed.commit()
	bed_mi.material_override = bed
	bed_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(bed_mi)
	var rail_mi: MeshInstance3D = MeshInstance3D.new()
	rail_mi.name = "Rails"
	rail_mi.mesh = st_rail.commit()
	rail_mi.material_override = iron
	rail_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(rail_mi)
	# telegraph poles along the line, the wires sagging between them; one down in the snow
	var poles: Array[Vector3] = []
	var run: float = 0.0
	var idx: int = 0
	while idx < pts.size() and poles.size() < 11:
		poles.append(_ground_k(pts[idx].x + 4.0, pts[idx].z + 2.0))
		idx += 9
		run += 27.0
	var prev: Array[Vector3] = []
	for pi: int in poles.size():
		var lean: Vector2 = Vector2.ZERO
		var tips: Array[Vector3] = LandscapeProps.pole(g, poles[pi], 90.0, lean, 6.0)
		if pi == 6:   # the one that came down
			tips = []
			Props.cyl(g, poles[pi] + Vector3(1.2, 0.2, 0.8), 0.1, 5.0, "beam", Vector3(88, 20, 0))
		if prev.size() == tips.size() and tips.size() > 0:
			for k2: int in mini(2, tips.size()):
				LandscapeProps.wire(g, prev[k2], tips[k2], 0.5, 5)
		prev = tips
	# a freight wagon half under a drift, a signal post leaning beside the line
	var wp: Vector3 = _ground_k(112.0, -62.0)
	var wg: Node3D = Props.group(g, "BuriedWagon", wp - Vector3(0, 0.5, 0), 42.0)
	Props.block(wg, Vector3(-1.4, 0.5, -3.2), Vector3(1.4, 3.0, 3.2), "rust")
	Props.block(wg, Vector3(-1.5, 3.0, -3.3), Vector3(1.5, 3.2, 3.3), "iron")
	Props.ball(wg, Vector3(0, 1.4, 0.0), Vector3(3.6, 2.2, 8.0), "snow")
	LandscapeProps.pole(g, _ground_k(122.0, -63.5), 10.0, Vector2(8.0, 3.0), 4.5)


# ================================================================== the dead cable car

func _strut(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material) -> void:
	var d: Vector3 = b - a
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = d.length()
	cm.radial_segments = 6
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var y: Vector3 = d.normalized()
	var x: Vector3 = y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	mi.transform = Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)
	parent.add_child(mi)


## A lattice tower: four leaning legs, three braced stages, a crossarm carrying the sheaves.
func _lattice_tower(parent: Node3D, base: Vector3, h: float, yaw_deg: float) -> Vector3:
	var iron: Material = Mats.get_mat("iron")
	var g: Node3D = Props.group(parent, "CableTower", base, yaw_deg)
	var foot: float = 2.3
	var top: float = 0.55
	var stages: Array[float] = [0.0, 0.34, 0.68, 1.0]
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_strut(g, Vector3(sx * foot, 0, sz * foot), Vector3(sx * top, h, sz * top), 0.11, iron)
	for k: int in 3:
		var y0: float = h * stages[k]
		var y1: float = h * stages[k + 1]
		var w0: float = lerpf(foot, top, stages[k])
		var w1: float = lerpf(foot, top, stages[k + 1])
		for s: float in [-1.0, 1.0]:
			_strut(g, Vector3(s * w0, y0, -w0), Vector3(-s * w1, y1, -w1), 0.05, iron)
			_strut(g, Vector3(s * w0, y0, w0), Vector3(-s * w1, y1, w1), 0.05, iron)
			_strut(g, Vector3(-w0, y0, s * w0), Vector3(-w1, y1, -s * w1), 0.05, iron)
			_strut(g, Vector3(w0, y0, s * w0), Vector3(w1, y1, -s * w1), 0.05, iron)
	Props.block(g, Vector3(-1.9, h, -0.25), Vector3(1.9, h + 0.35, 0.25), "iron")
	Props.cyl(g, Vector3(-1.1, h + 0.55, 0), 0.5, 0.3, "iron", Vector3(90, 0, 0))
	Props.cyl(g, Vector3(1.1, h + 0.55, 0), 0.5, 0.3, "iron", Vector3(90, 0, 0))
	Props.ball(g, Vector3(0, h + 0.35, 0), Vector3(3.2, 0.5, 1.2), "snow")
	return base + Vector3(0, h + 0.9, 0)


func _cable_mesh(a: Vector3, b: Vector3, sag: float, radius: float, segs: int) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var box: BoxMesh = Props.unit_box()
	var prev: Vector3 = a
	for i: int in segs:
		var p: Vector3 = KaltenTerrain.cable_point(a, b, float(i + 1) / float(segs), sag)
		var d: Vector3 = p - prev
		var y: Vector3 = d.normalized()
		var x: Vector3 = y.cross(Vector3.FORWARD).normalized()
		st.append_from(box, 0, Transform3D(Basis(x * radius, y * (d.length() + 0.05), x.cross(y).normalized() * radius), (prev + p) * 0.5))
		prev = p
	return st.commit()


func _build_cable_car() -> void:
	var g: Node3D = Node3D.new()
	g.name = "CableCar"
	add_child(g)
	var ha: float = KaltenTerrain.height(KaltenTerrain.CABLE_A.x, KaltenTerrain.CABLE_A.z)
	var hb: float = KaltenTerrain.height(KaltenTerrain.CABLE_B.x, KaltenTerrain.CABLE_B.z)
	cable_tower_a = _lattice_tower(g, Vector3(KaltenTerrain.CABLE_A.x, ha, KaltenTerrain.CABLE_A.z), KaltenTerrain.TOWER_H, 0.0)
	cable_tower_b = _lattice_tower(g, Vector3(KaltenTerrain.CABLE_B.x, hb, KaltenTerrain.CABLE_B.z), KaltenTerrain.TOWER_H, 0.0)
	var iron: Material = Mats.get_mat("iron")
	for off: float in [-1.1, 1.1]:   # the two ropes (the sheaves sit at x = +-1.1 on the crossarm; the span runs oblique, so offset along x)
		var a: Vector3 = cable_tower_a + Vector3(off, -0.3, 0)
		var b: Vector3 = cable_tower_b + Vector3(off, -0.3, 0)
		var cm: MeshInstance3D = MeshInstance3D.new()
		cm.name = "Cable"
		cm.mesh = _cable_mesh(a, b, CABLE_SAG, 0.07, 28)
		cm.material_override = iron
		cm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(cm)
	# the gondola hangs from the near rope, a third of the way across
	cable_pos = KaltenTerrain.cable_point(cable_tower_a + Vector3(-1.1, -0.3, 0), cable_tower_b + Vector3(-1.1, -0.3, 0), GONDOLA_T, CABLE_SAG)
	cable_pivot = Node3D.new()
	cable_pivot.name = "GondolaPivot"
	cable_pivot.position = cable_pos
	g.add_child(cable_pivot)
	Props.block(cable_pivot, Vector3(-0.25, -0.3, -0.35), Vector3(0.25, 0.25, 0.35), "iron")          # the grip on the rope
	Props.block(cable_pivot, Vector3(-0.05, -3.3, -0.05), Vector3(0.05, -0.3, 0.05), "iron")          # the hanger
	Props.block(cable_pivot, Vector3(-1.5, -5.7, -1.9), Vector3(1.5, -3.3, 1.9), "rust")              # the cabin
	Props.block(cable_pivot, Vector3(-1.6, -3.3, -2.0), Vector3(1.6, -3.15, 2.0), "iron")             # the roof
	Props.block(cable_pivot, Vector3(-1.45, -3.15, -1.8), Vector3(1.45, -2.9, 1.8), "snow", false)   # snow on the roof
	for z: float in [-1.0, 0.3]:
		Props.block(cable_pivot, Vector3(1.49, -4.8, z - 0.45), Vector3(1.53, -4.0, z + 0.45), "iron", false)   # dark windows
		Props.block(cable_pivot, Vector3(-1.53, -4.8, z - 0.45), Vector3(-1.49, -4.0, z + 0.45), "iron", false)
	Props.block(cable_pivot, Vector3(1.47, -5.6, 0.95), Vector3(1.6, -4.0, 1.85), "iron", false)      # the door, ajar
	Props.block(cable_pivot, Vector3(-1.6, -5.9, -2.1), Vector3(1.6, -5.7, 2.1), "iron")              # the floor


# ================================================================== the minehead siren

func _build_siren() -> void:
	siren_node = Props.group(self, "MineheadSiren", SIREN_POS, 0.0)
	var iron: Material = Mats.get_mat("iron")
	var post: MeshInstance3D = MeshInstance3D.new()
	var pm: CylinderMesh = CylinderMesh.new()
	pm.top_radius = 0.08
	pm.bottom_radius = 0.08
	pm.height = 1.2
	post.mesh = pm
	post.material_override = iron
	post.position = Vector3(0, 0.6, 0)
	siren_node.add_child(post)
	var horns: Node3D = Node3D.new()
	horns.name = "Horns"
	horns.position = Vector3(0, 1.3, 0)
	siren_node.add_child(horns)
	for k: int in 4:   # four horns on a ring, bells outward
		var a: float = float(k) * PI * 0.5
		var h: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.34
		cm.bottom_radius = 0.07
		cm.height = 0.8
		h.mesh = cm
		h.material_override = iron
		h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		h.transform = Transform3D(Basis(Vector3(0, 0, 1), -PI * 0.5 + 0.0).rotated(Vector3.UP, a), Vector3(cos(a), 0, -sin(a)) * 0.45)
		horns.add_child(h)
	siren_lamp = OmniLight3D.new()
	siren_lamp.name = "SirenLamp"
	siren_lamp.light_color = Color(1.0, 0.25, 0.12)
	siren_lamp.omni_range = 26.0
	siren_lamp.light_energy = 0.0
	siren_lamp.shadow_enabled = false
	siren_lamp.visible = false
	siren_lamp.position = Vector3(0, 1.9, 0)
	siren_lamp.set_meta("zone", "A_MINEHEAD")
	siren_node.add_child(siren_lamp)
