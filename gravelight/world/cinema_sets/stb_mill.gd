extends CinemaSet
## T-194, STAUB set M (§6.3): Staubmühle II, a mill hall off Kaltenbrunn's Generator Hall, 21:50 on 20 December 1944.
## A ball mill (a riveted drum turning on its rollers, the motor and its belt), the glass-fronted sifter with the
## violet dust sliding down inside it, lit from within, a hopper and the canister filling under it; the bank of three
## dials (fineness, resonance, temperature) and a clock; a lot-number board; the Wiederkehr mark stencilled once (the
## project's own mark, ART_FACTIONS: no eagle, no flag, no runes). The mill crew in rubber masks and gauntlets;
## Dr. Reinholt in a white coat at the gauges, a pencil. Markers: Sifter, Gauges, Reinholt. Effects: resonance_up.

var drum: Node3D
var needles: Array[Node3D] = []
var reinholt: CinemaPerson
var _t: float = 0.0
var _res: float = 0.6


func _build() -> void:
	env({"bg": [0.0, 0.0, 0.0], "ambient": [0.36, 0.33, 0.38], "ambient_e": 0.32, "fog": [0.16, 0.13, 0.2], "fog_d": 0.03, "glow_t": 1.0, "glow_i": 0.85, "bloom": 0.08})
	box(self, Vector3(0, -0.05, -8), Vector3(20, 0.1, 22), "concrete_floor")
	box(self, Vector3(0, 4.0, -19), Vector3(20, 8.0, 0.4), "fl_brick")
	box(self, Vector3(-10, 4.0, -8), Vector3(0.4, 8.0, 22), "fl_brick")
	box(self, Vector3(10, 4.0, -8), Vector3(0.4, 8.0, 22), "fl_brick")
	box(self, Vector3(0, 4.0, 3.0), Vector3(20, 8.0, 0.4), "fl_brick")
	box(self, Vector3(0, 8.0, -8), Vector3(20, 0.3, 22), "concrete")
	for bz: float in [-16.0, -10.0, -4.0, 2.0]:
		box(self, Vector3(0, 7.6, bz), Vector3(20, 0.5, 0.3), "steel")
	for lz: float in [-14.0, -7.0, -1.0]:
		var lamp: Node3D = prop(self, "lamp_industrial_hanging", Vector3(-3.0, 6.2, lz), 0.0)
		if lamp == null:
			cone(self, Vector3(-3.0, 6.2, lz), 0.35, 0.1, 0.3, "machine_grey", 12)
		omni(self, Vector3(-3.0, 5.6, lz), [1.0, 0.86, 0.66], 1.6, 9.0)
	_mill(Vector3(-5.0, 0, -10.0))
	_sifter(Vector3(1.5, 0, -6.0))
	_gauges(Vector3(5.2, 0, -4.0))
	var board: Node3D = group(self, "LotBoard", Vector3(-0.8, 2.4, -18.75))
	box(board, Vector3.ZERO, Vector3(1.4, 0.8, 0.04), "black_paint")
	words(board, "STAUB II\nLOS 1244-12", Vector3(0, 0, 0.025), 0.0032, Color(0.86, 0.84, 0.78))
	var mark: StandardMaterial3D = StandardMaterial3D.new()
	mark.albedo_texture = load("res://assets/ours/characters/zombie_base/tex_armband_wiederkehr.png") as Texture2D
	mark.roughness = 0.95
	card(self, Vector3(4.0, 3.2, -18.77), Vector2(2.0, 1.25), mark, 0.0, "WiederkehrMark")
	_crew()


func _mill(at: Vector3) -> void:
	var g: Node3D = group(self, "BallMill", at)
	for rx: float in [-1.6, 1.6]:
		box(g, Vector3(rx, 0.4, 0), Vector3(0.5, 0.8, 2.2), "machine_grey")
	drum = group(g, "Drum", Vector3(0, 1.65, 0))
	cyl(drum, Vector3.ZERO, 1.25, 4.0, "machine_green", Vector3(0, 0, 90))
	for k: int in 8:   # the rivet bands
		cyl(drum, Vector3(-1.8 + float(k) * 0.52, 0, 0), 1.28, 0.06, "steel", Vector3(0, 0, 90))
	box(g, Vector3(3.2, 0.6, 0.8), Vector3(1.0, 1.2, 0.9), "machine_grey")   # the motor
	box(g, Vector3(2.6, 1.3, 0.8), Vector3(1.4, 0.08, 0.12), "rubber", Vector3(0, 0, 42))   # the belt
	Props.smoke(g, Vector3(0, 2.4, 0), 1.6, 0.4, 14)


func _sifter(at: Vector3) -> void:
	var g: Node3D = group(self, "SifterFrame", at)
	for sx: float in [-0.85, 0.85]:
		box(g, Vector3(sx, 2.6, 0), Vector3(0.12, 3.6, 0.9), "machine_grey")
	box(g, Vector3(0, 4.45, 0), Vector3(1.8, 0.3, 0.9), "machine_grey")
	box(g, Vector3(0, 2.6, -0.42), Vector3(1.6, 3.6, 0.06), "machine_grey")
	var glass: StandardMaterial3D = flat(Color(0.7, 0.75, 0.8, 0.18), 0.05)
	box(g, Vector3(0, 2.6, 0.43), Vector3(1.6, 3.6, 0.02), glass, Vector3.ZERO, "SifterGlass")
	for k: int in 5:   # the shaking screens inside
		box(g, Vector3(0, 1.4 + 0.65 * float(k), 0), Vector3(1.55, 0.03, 0.78), "steel_grate", Vector3(0, 0, 6.0 if k % 2 == 0 else -6.0))
	# the dust: fine violet motes sliding down, lit from inside the machine
	var p: GPUParticles3D = GPUParticles3D.new()
	p.name = "VioletDust"
	p.amount = 420
	p.lifetime = 3.0
	p.preprocess = 3.0
	p.position = Vector3(0, 4.2, 0)
	p.visibility_aabb = AABB(Vector3(-1, -4, -1), Vector3(2, 5, 2))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.7, 0.05, 0.3)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 10.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.2
	pm.gravity = Vector3(0, -0.15, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	p.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.03, 0.03)
	var m: StandardMaterial3D = glow(Color(0.7, 0.4, 1.0), 2.6)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = m
	p.draw_pass_1 = q
	g.add_child(p)
	var vl: OmniLight3D = omni(g, Vector3(0, 2.6, 0.1), [0.62, 0.38, 1.0], 2.2, 6.0)
	vl.set_meta("flicker", 2.2)
	vl.add_to_group(&"cinema_flicker")
	cone(g, Vector3(0, 0.95, 0), 0.75, 0.15, 0.7, "machine_grey", 4)   # the hopper
	cyl(g, Vector3(0, 0.3, 0), 0.22, 0.55, "steel", Vector3.ZERO, "Canister")
	marker("Sifter", at + Vector3(0, 2.4, 0.4))


func _gauges(at: Vector3) -> void:
	var g: Node3D = group(self, "GaugeBank", at, -30.0)
	box(g, Vector3(0, 1.6, 0), Vector3(1.6, 1.4, 0.2), "machine_green")
	box(g, Vector3(0, 0.45, 0), Vector3(0.2, 0.9, 0.2), "machine_grey")
	for k: int in 4:
		var c: Vector3 = Vector3(-0.55 + 0.37 * float(k), 1.75, 0.11)
		cyl(g, c, 0.15, 0.02, "gauge_lit" if k < 3 else "gauge_face", Vector3(90, 0, 0))
		var nd: Node3D = group(g, "Needle_%d" % k, c + Vector3(0, 0, 0.015))
		box(nd, Vector3(0, 0.06, 0), Vector3(0.008, 0.12, 0.004), "black_paint")
		nd.rotation.z = -0.9 + 0.5 * float(k)
		needles.append(nd)
	words(g, "FEINHEIT    RESONANZ    TEMP.", Vector3(-0.2, 1.48, 0.105), 0.0011, Color(0.85, 0.82, 0.72))
	omni(g, Vector3(0, 2.0, 0.6), [0.9, 0.85, 0.7], 0.7, 3.0)
	marker("Gauges", at + Vector3(0, 1.7, 0))


func _crew() -> void:
	# T-206: yaw 0 faces -z; Reinholt faces her gauges (she stood with her back to them) and the crew face the hopper
	var r: CinemaPerson = person(self, "reinholt", look_of("reinholt"), Vector3(5.0, 0, -3.1), -12.0, "writing")
	r.name = "Reinholt"
	r.head_down = 0.1
	reinholt = r
	for k: int in 3:
		var p: CinemaPerson = person(self, "mill_%d" % k, look_of("mill_worker"), Vector3(0.6 + 0.9 * float(k), 0, -4.9 + 0.3 * float(k % 2)), rng.randf_range(-20, 20), "hold")
		p.hold_lift = 0.5
	for k2: int in 2:
		person(self, "mill_far_%d" % k2, look_of("mill_worker"), Vector3(-6.0 + 2.5 * float(k2), 0, -7.6), rng.randf_range(0, 360), "stand")


## Shot 3: the resonance needle climbs; she writes it down (T-206: she watches the dials, then bows to the board on
## her second line and looks back up).
func fx_resonance_up(secs: float) -> void:
	var tw: Tween = create_tween()
	tw.tween_property(self, "_res", 1.3, secs * 0.8).set_trans(Tween.TRANS_SINE)
	if reinholt != null:
		reinholt.look_toward(Vector3(5.2, 1.75, -4.0))
		later(5.8, func() -> void:
			reinholt.head_yaw = 0.0
			reinholt.head_down = 0.5)
		later(8.6, func() -> void: reinholt.look_toward(Vector3(5.2, 1.75, -4.0)))


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	if drum != null:
		drum.rotation.x += delta * 0.9
	if needles.size() >= 4:
		needles[1].rotation.z = -_res + sin(_t * 13.0) * 0.03
		needles[0].rotation.z = -0.4 + sin(_t * 2.0) * 0.02
		needles[3].rotation.z = -_t * 0.02
