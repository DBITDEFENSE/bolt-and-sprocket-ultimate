extends CinemaSet
## T-194, FOURTH DAY sets K-L (§6.2): four days later, a morning of low cloud and no rain. Behind an aid station's
## tents a row of eight fresh mounds (z 0, x -9 to 9), each with a wooden pyramid marker, a small tin star on top and a
## pencilled name under a scrap of glass (a period grave marker, shown with respect, never framed as a symbol), a
## shovel in the heap; a field kitchen (a towed boiler) and a cart with a radio set; Red Army soldiers at the kitchen
## with their backs to the graves. Mound 4 (x 1.5) is the one that moves. Then the road west at z -200 running along x:
## a battery of four field guns beside it (silhouettes, placard level), their crews standing off, and the risen in
## greatcoats walking west (-x) along it past them (CinemaRisen: T-192's skins when they land).
## Markers: Mound, Kitchen, Soldiers, Road. Effects: mound_rise, soldiers_turn, walk.

var mound: Node3D
var ridge: MeshInstance3D
var post: Node3D
var soldiers: Array[CinemaPerson] = []
var walkers: Array[Node3D] = []
var _walking: bool = false
const CRAFT = preload("res://gravelight/world/cinema_sets/cinema_craft.gd")


func _build() -> void:
	env({"sky_top": [0.5, 0.52, 0.55], "sky_horizon": [0.62, 0.63, 0.64], "ground": [0.2, 0.18, 0.15], "ambient": [0.6, 0.62, 0.66], "ambient_e": 0.7,
		"fog": [0.6, 0.61, 0.62], "fog_d": 0.0065, "glow_t": 1.5})
	sun(Vector3(-28, -110, 0), [0.88, 0.88, 0.9], 0.5)
	var mud: Material = MaterialLibrary.build("dirt", {"tint": [0.5, 0.45, 0.38], "tile_m": 1.4, "wetness": 0.3})
	plane(self, Vector3(0, 0, -100), Vector2(800, 800), mud)
	var frost: StandardMaterial3D = noisy(Color(0.5, 0.5, 0.48), Color(0.72, 0.72, 0.7), 0.4, 2.0, 0.9)
	var patches: Array = []
	for i: int in 80:
		patches.append(xf(Vector3(rng.randf_range(-60, 60), 0.0, rng.randf_range(-240, 40)), Vector3(rng.randf_range(2, 5), 0.12, rng.randf_range(2, 5))))
	multi(self, Props.unit_sphere(), patches, frost, "FrostPatches")
	_graves()
	_kitchen()
	_road()


func _graves() -> void:
	var earth: Material = MaterialLibrary.build("dirt", {"tint": [0.4, 0.32, 0.25], "tile_m": 0.65, "wetness": 0.24})
	var tin: StandardMaterial3D = flat(Color(0.55, 0.56, 0.56), 0.45, 0.0, 0.7)
	for k: int in 8:
		var x: float = -9.0 + 2.5 * float(k)
		var g: Node3D = group(self, "Grave_%d" % k, Vector3(x, 0, 0))
		var m: MeshInstance3D = CRAFT.mesh(g, CRAFT.earth(1.35, 2.5, 0.35, 700 + k), earth, "Earth")
		for clod: int in 15:
			var a: float = rng.randf_range(0.0, TAU)
			var sz: float = rng.randf_range(0.035, 0.085)
			ball(g, Vector3(cos(a) * 0.63, 0.018, sin(a) * 1.12), Vector3(sz * 1.4, sz, sz), earth)
		var marker_post: Node3D = group(g, "Marker", Vector3(0, 0.15, -1.25))
		cone(marker_post, Vector3(0, 0.5, 0), 0.16, 0.03, 1.0, "planks", 4)
		_star(marker_post, Vector3(0, 1.05, 0), 0.06, tin)
		box(marker_post, Vector3(0, 0.45, 0.09), Vector3(0.12, 0.08, 0.01), "paper_old")
		if k == 4:
			mound = g
			mound.name = "Mound"
			post = marker_post
			ridge = CRAFT.mesh(g, CRAFT.earth(1.0, 1.0, 0.5, 1204), earth, "Ridge")
			ridge.position = Vector3(0, 0.05, 0.15)
			ridge.scale = Vector3(0.4, 0.2, 1.4)
			ridge.name = "Ridge"
			var holder: Node3D = group(g, "MoundStain", Vector3.ZERO)
			var stain: MeshInstance3D = plane(holder, Vector3(0, 0.37, 0.3), Vector2(0.5, 1.0), flat(Color(0.1, 0.02, 0.015, 0.8), 0.4), Vector3(0, 0, 0), "Stain")
			stain.add_to_group(&"gore_full")
			holder.visible = false   # (shown when the earth moves; the stain itself draws only on gore full)
			m.name = "Earth"
	ball(self, Vector3(11.5, 0.2, 0.5), Vector3(1.6, 0.6, 1.6), earth)   # the heap, the shovel in it
	var sp: Node3D = prop(self, "spade_rusted", Vector3(11.5, 0.4, 0.5), 30.0)
	if sp != null:
		sp.rotation_degrees = Vector3(18, 30, 6)
	else:
		box(self, Vector3(11.5, 0.8, 0.5), Vector3(0.04, 1.2, 0.04), "beam", Vector3(18, 30, 6))
	for t: int in 3:   # the aid station's tents (no markings)
		var tg: Node3D = group(self, "Tent", Vector3(-12.0 + 10.0 * float(t), 0, -14.0), rng.randf_range(-6, 6))
		var pr: PrismMesh = PrismMesh.new()
		pr.size = Vector3(4.4, 2.6, 6.0)
		var tm: MeshInstance3D = MeshInstance3D.new()
		tm.mesh = pr
		tm.material_override = mat("tarp")
		tm.position = Vector3(0, 1.3, 0)
		tg.add_child(tm)


## A small flat five-pointed star of tin, upright (a period grave marker).
func _star(parent: Node3D, at: Vector3, r: float, m: Material) -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = []
	for i: int in 10:
		var a: float = PI * 0.5 + TAU * float(i) / 10.0
		var rr: float = r if i % 2 == 0 else r * 0.42
		pts.append(Vector3(cos(a) * rr, sin(a) * rr, 0))
	for i2: int in 10:
		for face: int in 2:
			st.set_normal(Vector3(0, 0, 1 if face == 0 else -1))
			st.add_vertex(Vector3.ZERO)
			st.add_vertex(pts[i2] if face == 0 else pts[(i2 + 1) % 10])
			st.add_vertex(pts[(i2 + 1) % 10] if face == 0 else pts[i2])
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	mi.position = at
	parent.add_child(mi)


func _kitchen() -> void:
	var k: Node3D = group(self, "Kitchen", Vector3(2.0, 0, 12.0), 8.0)
	cyl(k, Vector3(0, 1.0, 0), 0.6, 1.2, "olive_steel", Vector3(0, 0, 90))
	cyl(k, Vector3(0.2, 2.0, 0), 0.08, 1.0, "rust")
	for wx: float in [-0.7, 0.7]:
		cyl(k, Vector3(wx, 0.45, 0.6), 0.45, 0.1, "rubber", Vector3(0, 0, 90))
	box(k, Vector3(0, 0.5, -1.6), Vector3(0.06, 0.06, 1.6), "beam")
	Props.smoke(k, Vector3(0.2, 2.6, 0), 0.2, 1.4, 12)
	cyl(k, Vector3(-0.6, 1.66, 0.0), 0.12, 0.2, "tin")   # the kettle
	var cart: Node3D = group(self, "RadioCart", Vector3(7.5, 0, 13.0), -20.0)
	box(cart, Vector3(0, 0.75, 0), Vector3(1.2, 0.1, 1.8), "planks")
	for cz: float in [-0.6, 0.6]:
		cyl(cart, Vector3(0.65, 0.5, cz), 0.5, 0.06, "beam", Vector3(0, 0, 90))
		cyl(cart, Vector3(-0.65, 0.5, cz), 0.5, 0.06, "beam", Vector3(0, 0, 90))
	box(cart, Vector3(0, 1.05, 0.2), Vector3(0.5, 0.45, 0.35), "walnut")
	cyl(cart, Vector3(0.15, 2.3, 0.2), 0.008, 2.6, "steel", Vector3(0, 0, 6))
	marker("Kitchen", Vector3(2.0, 1.4, 12.0))
	var looks: Array = ["rkka_soldier_a", "rkka_soldier_b", "rkka_soldier_c", "rkka_soldier_d"]
	for s: int in 8:   # (T-206: yaw 180 faces +z, the kitchen: their backs to the graves until the earth moves)
		var p: CinemaPerson = person(self, "soldier_%d" % s, look_of(looks[s % 4]), Vector3(-2.5 + 1.15 * float(s) + rng.randf_range(-0.2, 0.2), 0, 10.0 + rng.randf_range(-0.6, 0.6)),
			180.0 + rng.randf_range(-20, 20), "stand" if s % 3 != 1 else "hold")
		soldiers.append(p)
	marker("Soldiers", Vector3(1.5, 1.5, 10.0))


func _road() -> void:
	var road: StandardMaterial3D = noisy(Color(0.14, 0.11, 0.08), Color(0.27, 0.22, 0.16), 0.3, 2.0, 0.7, 0.4)
	plane(self, Vector3(0, 0.015, -200), Vector2(400, 7.0), road)
	marker("Road", Vector3(0, 1.4, -200))
	var green: StandardMaterial3D = noisy(Color(0.2, 0.21, 0.16), Color(0.28, 0.29, 0.22), 1.0, 1.0, 0.7)
	for g: int in 4:   # the battery of field guns beside the road (silhouettes, no markings)
		var gn: Node3D = group(self, "Gun_%d" % g, Vector3(-27.0 + 18.0 * float(g), 0, -208.5), 90.0 + rng.randf_range(-6, 6))
		box(gn, Vector3(0, 0.95, 0), Vector3(1.6, 1.1, 0.06), green)               # the shield
		cyl(gn, Vector3(0, 1.0, -1.7), 0.05, 3.2, green, Vector3(90, 0, 0))       # the barrel, pointing west and up
		gn.get_child(gn.get_child_count() - 1).rotation_degrees = Vector3(80, 0, 0)
		for wx: float in [-0.75, 0.75]:
			cyl(gn, Vector3(wx, 0.6, 0.1), 0.6, 0.12, "rubber", Vector3(0, 0, 90))
		box(gn, Vector3(-0.45, 0.35, 2.0), Vector3(0.12, 0.12, 3.0), green, Vector3(0, -10, 0))   # the trails
		box(gn, Vector3(0.45, 0.35, 2.0), Vector3(0.12, 0.12, 3.0), green, Vector3(0, 10, 0))
		for c: int in 2:   # their crews standing off, letting them pass
			var cp: CinemaPerson = person(self, "gunner_%d_%d" % [g, c], look_of(["rkka_soldier_a", "rkka_soldier_c"][c]),
				Vector3(-28.0 + 18.0 * float(g) + 1.4 * float(c), 0, -214.0 + rng.randf_range(-1.0, 0.5)), rng.randf_range(-15, 15),
				"palm" if g == 2 and c == 0 else "stand")
			cp.name = "Gunner_%d_%d" % [g, c]
	var kind: String = str(CinemaLibrary.data().get("risen_kind", "soviet_greatcoat"))
	for w: int in 44:   # the risen, walking west in a long loose line
		var r: CinemaRisen = CinemaRisen.make(kind, 1000 + w)
		add_child(r)
		r.position = Vector3(-20.0 + float(w) * 2.4 + rng.randf_range(-1.0, 1.0), 0, -200.0 + rng.randf_range(-3.0, 3.0))
		r.rotation.y = deg_to_rad(90.0 + rng.randf_range(-8, 8))   # facing -x: west
		walkers.append(r)


## Shot 9: the earth moves on mound 4: a clod rolls, a ridge rises along its spine and the marker leans.
func fx_mound_rise(secs: float) -> void:
	if ridge == null:
		return
	ridge.scale = Vector3(0.4, 0.2, 1.4)
	ridge.position = Vector3(0, 0.05, 0.15)
	tween_to(ridge, "scale", Vector3(0.62, 0.62, 1.6), secs * 0.7, Tween.TRANS_SINE, Tween.EASE_IN, secs * 0.15)
	tween_to(ridge, "position:y", 0.2, secs * 0.7, Tween.TRANS_SINE, Tween.EASE_IN, secs * 0.15)
	tween_to(post, "rotation:x", deg_to_rad(-16.0), secs * 0.5, Tween.TRANS_SINE, Tween.EASE_OUT, secs * 0.45)
	tween_to(post, "rotation:z", deg_to_rad(9.0), secs * 0.5, Tween.TRANS_SINE, Tween.EASE_OUT, secs * 0.45)
	var clod: MeshInstance3D = ball(mound, Vector3(0.25, 0.55, 0.4), Vector3(0.14, 0.12, 0.14), "dirt")
	tween_to(clod, "position", Vector3(0.75, 0.08, 0.6), secs * 0.25, Tween.TRANS_QUAD, Tween.EASE_IN, secs * 0.2)
	later(secs * 0.8, func() -> void:
		dust(mound, Vector3(0, 0.5, 0.2), Color(0.2, 0.16, 0.12, 0.9), 0.4, 1.6, 1.2, 16, 0.4).emitting = true
		var st: Node3D = mound.get_node_or_null("MoundStain") as Node3D
		if st != null and gore() == "full":
			st.visible = true)


## Shot 9-10: the soldiers at the kitchen, one by one, turn to look at it (T-206: the head first, then the body, the
## short way round).
func fx_soldiers_turn(secs: float) -> void:
	for k: int in soldiers.size():
		var p: CinemaPerson = soldiers[k]
		var yaw: float = CinemaPerson.yaw_to(Vector3(1.5, 0, 0) - p.position)
		later(secs * 0.3 + 0.35 * float(k), func() -> void:
			p.look_toward(Vector3(1.5, 0.4, 0))
			p.turn_to(yaw, 0.9, 0.3)
			later(1.2, func() -> void: p.look_toward(Vector3(1.5, 0.4, 0))))


## Shot 10: their faces. One takes off his cap (his hand to it and down), one crosses himself and looks round to see
## who saw (T-206: the shot list's beats, on the hands).
func fx_faces(_secs: float) -> void:
	if soldiers.size() < 6:
		return
	var cap: CinemaPerson = soldiers[2]
	cap.hand_r = Vector3(0.12, 0.1, -0.25)
	tween_to(cap, "hand_r", Vector3(0.1, 0.64, -0.1), 0.6, Tween.TRANS_SINE, Tween.EASE_IN_OUT, 1.0)
	tween_to(cap, "hand_r", Vector3(0.14, 0.05, -0.2), 0.8, Tween.TRANS_SINE, Tween.EASE_IN_OUT, 2.4)
	later(3.3, func() -> void: cap.hand_r = null)
	var cross: CinemaPerson = soldiers[5]
	cross.hand_r = Vector3(0.12, 0.1, -0.25)
	var tw: Tween = create_tween()
	tw.tween_interval(2.0)
	for p: Vector3 in [Vector3(0.04, 0.56, -0.22), Vector3(0.04, 0.18, -0.24), Vector3(0.2, 0.42, -0.2), Vector3(-0.18, 0.42, -0.2), Vector3(0.14, 0.05, -0.2)]:
		tw.tween_property(cross, "hand_r", p, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void: cross.hand_r = null)
	later(4.1, func() -> void: cross.look_toward(soldiers[4].position + Vector3(0, 1.55, 0)))
	later(5.4, func() -> void: cross.look_toward(Vector3(1.5, 0.4, 0)))


## Shot 11: they walk west.
func fx_walk(_secs: float) -> void:
	_walking = true


func _process(delta: float) -> void:
	super._process(delta)
	if not _walking:
		return
	for w: Node3D in walkers:
		var r: CinemaRisen = w as CinemaRisen
		w.position += -w.global_basis.z * delta * (r.walk_speed if r != null else 1.0)
