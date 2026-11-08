extends CinemaSet
## T-194, LAZARUS SATURDAY set G (§6.1): a late snow at night over the thaw. The OGPU cordon (greatcoats, winter
## helmets, rifles slung, 40 m apart, their backs to the camera) across the snowfield at z -30; a field telephone on a
## post, a fire in a drum, a sledge. 300 m off at z -330 Chetverodnevo burns, the church's stump black against it;
## figures walk in the firelight far off (CinemaRisen's stand-ins in the dark: we cannot tell whose). Off to the side at
## x -200 the church door with its painted board ТИФ · КАРАНТИН · ВХОД ВОСПРЕЩЁН (paint on a prop, not a UI font)
## and, on its nail, the key ring. Markers: Village, Door, Board, KeyRing. Effects: hammer, walkers.

const BOARD: String = "ТИФ · КАРАНТИН\nВХОД ВОСПРЕЩЁН"

var walkers: Array[Node3D] = []


func _build() -> void:
	env({"bg": [0.015, 0.02, 0.035], "ambient": [0.3, 0.34, 0.45], "ambient_e": 0.35, "fog": [0.12, 0.1, 0.1], "fog_d": 0.0035, "glow_t": 0.9, "glow_i": 0.9, "bloom": 0.08})
	sun(Vector3(-30, 40, 0), [0.55, 0.62, 0.8], 0.18)
	var snow: StandardMaterial3D = noisy(Color(0.62, 0.64, 0.7), Color(0.82, 0.84, 0.9), 0.15, 4.0, 0.85)
	plane(self, Vector3(0, 0, -150), Vector2(900, 900), snow)
	precipitation(self, Vector3(0, 0, -6), Vector3(18, 6, 18), true, 900)
	# the cordon
	var gc: Array = ["ogpu_a", "ogpu_b"]
	for i: int in 7:
		var x: float = -120.0 + 40.0 * float(i)
		# (T-206: yaw 0 faces -z, toward the burning village: their backs to us, as the shot list says; they stood facing the lens)
		var p: CinemaPerson = person(self, "cordon_%d" % i, look_of(gc[i % 2]), Vector3(x + rng.randf_range(-3, 3), 0, -30.0 + rng.randf_range(-4, 4)), rng.randf_range(-6, 6), "stand")
		var rifle: MeshInstance3D = MeshInstance3D.new()
		rifle.mesh = Props.unit_box()
		rifle.scale = Vector3(0.05, 1.15, 0.05)
		rifle.material_override = flat(Color(0.2, 0.15, 0.1), 0.6)
		rifle.rotation_degrees = Vector3(0, 0, 18)
		if p.person != null:
			p.person.attachment("Chest").add_child(rifle)
			rifle.position = Vector3(0.05, 0.05, 0.17)
	# the field telephone on its post, the fire drum, a sledge
	box(self, Vector3(4.0, 0.8, -8.0), Vector3(0.14, 1.6, 0.14), "beam")
	box(self, Vector3(4.0, 1.3, -7.88), Vector3(0.28, 0.22, 0.12), "walnut")
	Props.cable(self, Vector3(4.0, 1.4, -8.0), Vector3(40.0, 1.4, -30.0), 0.8, 0.008, 6, "rubber")
	var drum: Node3D = prop(self, "stove_barrel", Vector3(-7.0, 0, -14.0), 0.0)
	if drum == null:
		cyl(self, Vector3(-7.0, 0.45, -14.0), 0.3, 0.9, "rust")
	fire(self, Vector3(-7.0, 0.95, -14.0), 0.5, 0.8, 2.6, 26)
	var sl: Node3D = group(self, "Sledge", Vector3(9.0, 0, -18.0), 30.0)
	for sx: float in [-0.45, 0.45]:
		box(sl, Vector3(sx, 0.08, 0), Vector3(0.06, 0.08, 2.2), "beam")
	box(sl, Vector3(0, 0.3, 0), Vector3(1.0, 0.06, 1.8), "planks")
	_village()
	_door()


func _village() -> void:
	var v: Node3D = group(self, "Village", Vector3(0, 0, -330))
	for k: int in 16:
		var x: float = rng.randf_range(-90, 90)
		var z: float = rng.randf_range(-40, 40)
		izba(v, Vector3(x, 0, z), rng.randf_range(0, 360), 6.0, 5.0, 3.0, true)
		if k % 2 == 0:
			fire(v, Vector3(x, 1.6, z), 5.0, 6.0, 8.0, 34)
			glow_dot(v, Vector3(x, 4.0, z + 3.0), 18.0, Color(1.0, 0.45, 0.15), 1.1)
	box(v, Vector3(10, 1.5, -10), Vector3(8.0, 3.0, 16.0), "char")        # the church, its stump black against the fire
	box(v, Vector3(18.5, 0.8, -6), Vector3(3.4, 1.6, 3.4), "char")
	fire(v, Vector3(10, 3.6, -10), 7.0, 8.0, 10.0, 40)
	glow_dot(v, Vector3(0, 12.0, 10.0), 140.0, Color(0.9, 0.32, 0.1), 0.45)
	Props.smoke(v, Vector3(0, 10, 0), 40.0, 4.0, 40)
	for w: int in 6:   # figures walking in the fire's light, far off; whose, we cannot tell
		var r: CinemaRisen = CinemaRisen.make(str(CinemaLibrary.data().get("risen_kind", "soviet_greatcoat")), 300 + w)
		v.add_child(r)
		r.position = Vector3(-30.0 + 9.0 * float(w), 0, 46.0 + rng.randf_range(-3, 3))
		r.rotation.y = deg_to_rad(90.0 + rng.randf_range(-15, 15))
		walkers.append(r)


func _door() -> void:
	var d: Node3D = group(self, "Door", Vector3(-200, 0, 0))
	box(d, Vector3(0, 2.2, -0.3), Vector3(5.0, 4.6, 0.5), _log_mat())
	box(d, Vector3(0, 1.25, 0.0), Vector3(1.8, 2.5, 0.1), "planks")
	box(d, Vector3(0, 0.08, 0.6), Vector3(3.0, 0.16, 1.4), "planks")
	var board: Node3D = group(d, "Board", Vector3(0, 1.55, 0.12))
	box(board, Vector3.ZERO, Vector3(1.6, 0.7, 0.04), "#c8c0a8")
	for nx: float in [-0.72, 0.72]:
		cyl(board, Vector3(nx, 0.28, 0.03), 0.012, 0.02, "iron", Vector3(90, 0, 0))
	words(board, BOARD, Vector3(0, 0.0, 0.024), 0.0042, Color(0.08, 0.07, 0.06), 0.0)
	var keys: Node3D = group(d, "KeyRing", Vector3(0.55, 1.15, 0.1))
	cyl(keys, Vector3(0, 0.06, 0), 0.006, 0.05, "iron", Vector3(90, 0, 0))
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 0.035
	ring.outer_radius = 0.045
	var rm: MeshInstance3D = MeshInstance3D.new()
	rm.mesh = ring
	rm.material_override = flat(Color(0.2, 0.19, 0.18), 0.5, 0.0, 0.8)
	rm.rotation_degrees = Vector3(90, 0, 0)
	keys.add_child(rm)
	for j: int in 4:
		box(keys, Vector3(-0.03 + 0.02 * float(j), -0.07, 0.01), Vector3(0.012, 0.1, 0.006), flat(Color(0.18, 0.17, 0.16), 0.5, 0.0, 0.8))
	var lan: Node3D = prop(d, "lantern_oil", Vector3(-1.2, 1.9, 0.25), 0.0)
	var l: OmniLight3D = omni(d, Vector3(-1.1, 2.1, 0.6), [1.0, 0.7, 0.4], 1.5, 6.0)
	l.set_meta("flicker", 1.5)
	l.add_to_group(&"cinema_flicker")
	if lan == null:
		ball(d, Vector3(-1.2, 1.9, 0.25), Vector3(0.12, 0.18, 0.12), glow(Color(1.0, 0.75, 0.4), 2.0))
	omni(d, Vector3(3.0, 3.0, -4.0), [1.0, 0.45, 0.15], 2.0, 14.0)   # the fire behind, off frame
	var snow: StandardMaterial3D = noisy(Color(0.62, 0.64, 0.7), Color(0.82, 0.84, 0.9), 0.3, 2.0, 0.85)
	plane(d, Vector3(0, 0.02, 2), Vector2(12, 8), snow)


## Shot 30: a hammer's last blows on the board: it jumps a little with each.
func fx_hammer(secs: float) -> void:
	var b: Node3D = get_node("Door/Board") as Node3D
	for k: int in 3:
		later(0.4 + float(k) * minf(0.7, secs * 0.12), func() -> void:
			b.position.z = 0.135
			tween_to(b, "position:z", 0.12, 0.12, Tween.TRANS_QUAD, Tween.EASE_OUT))


func _process(delta: float) -> void:
	super._process(delta)
	for w: Node3D in walkers:
		var r: CinemaRisen = w as CinemaRisen
		w.position += -w.global_basis.z * delta * (r.walk_speed if r != null else 1.0)
