extends CinemaSet
## T-194, FOURTH DAY sets I-J (§6.2): the East Prussian line in the October rain. The German line runs along x at z 0:
## a trench of brown water (floor y -1.8, water at -1.45), sandbags on its east (+z) parapet, duckboards, an MG under a
## tarpaulin, the field telephone's wire on stakes behind, wire in front, shell holes full of water, a roofless spire
## far off and an assault gun's silhouette (placard level: no markings). The Soviet observation post is a log dugout
## 250 m east at z +250 (the shot list's 600 m brought in so the long lens still reads the soft bursts; logged), its
## slit facing the line: a trench periscope, a field telephone, a map under oilcloth, a candle in a tin, two officers of
## the division in rain capes with binoculars and Volkov between them. Rain over both.
## Markers: Trench, OPSlit, Handset. Effects: shells_soft (three salvoes: a thud and a low brown puff, no flash).

var _t: float = 0.0


func _build() -> void:
	env({"sky_top": [0.3, 0.32, 0.34], "sky_horizon": [0.42, 0.43, 0.44], "ground": [0.12, 0.11, 0.1], "ambient": [0.45, 0.47, 0.5], "ambient_e": 0.6,
		"fog": [0.4, 0.41, 0.42], "fog_d": 0.0028, "glow_t": 1.5})
	sun(Vector3(-60, -30, 0), [0.75, 0.78, 0.82], 0.35)
	var mud: StandardMaterial3D = noisy(Color(0.17, 0.14, 0.1), Color(0.3, 0.25, 0.18), 0.1, 5.0, 0.7, 0.4)
	plane(self, Vector3(0, 0, 226.0), Vector2(900, 450), mud)     # (the trench at z -1..1 is left open)
	plane(self, Vector3(0, 0, -226.0), Vector2(900, 450), mud)
	plane(self, Vector3(275, 0, 0), Vector2(450, 2.2), mud)
	plane(self, Vector3(-275, 0, 0), Vector2(450, 2.2), mud)
	_trench()
	_op()
	precipitation(self, Vector3(0, 0, 0), Vector3(16, 6, 12), false, 1600)
	precipitation(self, Vector3(0, 0, 250), Vector3(12, 5, 10), false, 1100)
	marker("Trench", Vector3(0, -0.6, 0))


func _trench() -> void:
	var t: Node3D = group(self, "GermanLine", Vector3.ZERO)
	var mud_wall: StandardMaterial3D = noisy(Color(0.15, 0.12, 0.09), Color(0.26, 0.21, 0.15), 0.6, 1.0, 0.75, 0.3)
	# the cut: the ground on both sides stands proud of the trench (boxes down to its floor), water in the bottom
	box(t, Vector3(0, -1.0, -3.2), Vector3(90, 2.0, 4.4), mud_wall)
	box(t, Vector3(0, -1.0, 3.2), Vector3(90, 2.0, 4.4), mud_wall)
	box(t, Vector3(0, -1.9, 0), Vector3(90, 0.2, 2.2), mud_wall)
	var water: StandardMaterial3D = flat(Color(0.2, 0.15, 0.09), 0.05)
	water.metallic_specular = 1.0
	plane(t, Vector3(0, -1.45, 0), Vector2(90, 2.0), water)
	var duck: Array = []
	for i: int in 70:
		duck.append(xf(Vector3(-40.0 + 1.15 * float(i), -1.42, rng.randf_range(-0.1, 0.1)), Vector3(0.95, 0.06, 0.7), Vector3(0, rng.randf_range(-4, 4), rng.randf_range(-3, 3))))
	multi(t, Props.unit_box(), duck, "planks", "Duckboards")
	var bags: Array = []
	for i2: int in 240:
		var row: int = i2 % 3
		bags.append(xf(Vector3(-44.0 + 0.55 * float(i2 / 3) + (0.27 if row == 1 else 0.0), 0.12 + 0.22 * float(row), 1.25 + rng.randf_range(-0.05, 0.05)),
			Vector3(0.55, 0.22, 0.34), Vector3(0, rng.randf_range(-6, 6), 0)))
	multi(t, Props.unit_sphere(), bags, "sandbag", "Sandbags")
	# the MG position under its tarpaulin
	var mg: Node3D = group(t, "MG", Vector3(8.0, 0, 0.6))
	box(mg, Vector3(0, 0.9, 0), Vector3(2.4, 0.06, 1.8), "tarp", Vector3(8, 0, 0))
	for px: float in [-1.1, 1.1]:
		box(mg, Vector3(px, 0.4, -0.7), Vector3(0.08, 1.0, 0.08), "beam")
	cyl(mg, Vector3(0, 0.55, 0.9), 0.025, 1.2, "steel", Vector3(90, 0, 0))
	# the telephone wire on its stakes behind the line; the wire in front
	for s: int in 14:
		box(t, Vector3(-36.0 + 5.5 * float(s), 0.5, -5.0), Vector3(0.06, 1.0, 0.06), "beam")
		if s < 13:
			Props.cable(t, Vector3(-36.0 + 5.5 * float(s), 0.95, -5.0), Vector3(-30.5 + 5.5 * float(s), 0.95, -5.0), 0.25, 0.006, 4, "rubber")
	for w: int in 18:
		var wx: float = -40.0 + 4.6 * float(w)
		box(t, Vector3(wx, 0.55, 9.5), Vector3(0.06, 1.1, 0.06), "beam", Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12)))
		if w < 17:
			for wy: float in [0.35, 0.75]:
				Props.cable(t, Vector3(wx, wy, 9.5), Vector3(wx + 4.6, wy, 9.5), 0.15, 0.005, 4, "rust")
	for h: int in 9:   # shell holes full of water
		var hp: Vector3 = Vector3(rng.randf_range(-40, 40), 0.02, rng.randf_range(5, 40))
		cyl(t, hp, rng.randf_range(1.2, 2.6), 0.04, water)
	# the dead horse in the wire, far, never close
	ball(t, Vector3(28.0, 0.35, 12.0), Vector3(2.2, 0.7, 0.9), "#2e2620")
	# a roofless spire far off in the rain, a wrecked assault gun's silhouette
	box(self, Vector3(-260, 14, -700), Vector3(8, 28, 8), "#3c3a38")
	box(self, Vector3(-260, 30, -700), Vector3(5, 6, 5), "#34322f")
	var gun: Node3D = group(self, "WreckedGun", Vector3(55, 0, -35), 25.0)
	box(gun, Vector3(0, 1.0, 0), Vector3(3.0, 1.6, 6.0), "#2c2b28", Vector3(0, 0, 9))
	cyl(gun, Vector3(0, 1.4, -3.6), 0.1, 2.0, "#262522", Vector3(90, 0, 0))
	# helmets moving under the parapet: the German soldiers in the trench (no faces close)
	for k: int in 6:
		var p: CinemaPerson = person(t, "landser_%d" % k, look_of("wehrmacht_a" if k % 2 == 0 else "wehrmacht_b"), Vector3(-9.0 + 3.2 * float(k), -1.45, 0.25), 180.0 if k % 3 != 0 else 0.0,
			"stand" if k % 3 != 1 else "cower")
		p.name = "Landser_%d" % k


func _op() -> void:
	var op: Node3D = group(self, "OP", Vector3(0, 1.25, 250))   # (its floor on the field; the earth banked up round it)
	var logs: Material = _log_mat()
	for bx: float in [-3.6, 3.6]:
		box(op, Vector3(bx, -0.9, 0), Vector3(2.0, 1.2, 6.0), "dirt", Vector3(0, 0, -30.0 * signf(bx)))
	box(op, Vector3(0, -1.0, -3.3), Vector3(7.0, 1.0, 2.4), "dirt", Vector3(-22, 0, 0))
	box(op, Vector3(0, -1.25, 0), Vector3(5.0, 0.1, 4.0), "planks")                 # the floor, a metre down
	box(op, Vector3(0, 0.62, -0.2), Vector3(5.6, 0.36, 5.0), logs)                 # the log roof with earth on it
	box(op, Vector3(0, 0.9, -0.2), Vector3(6.2, 0.22, 5.6), "dirt")
	box(op, Vector3(-2.55, -0.3, 0), Vector3(0.3, 1.9, 4.2), logs)
	box(op, Vector3(2.55, -0.3, 0), Vector3(0.3, 1.9, 4.2), logs)
	box(op, Vector3(0, -0.3, 2.05), Vector3(5.4, 1.9, 0.3), logs)
	box(op, Vector3(0, -0.55, -2.05), Vector3(5.4, 1.3, 0.3), logs)                 # the front wall under the slit
	box(op, Vector3(-1.9, 0.27, -2.05), Vector3(1.6, 0.34, 0.3), logs)              # the slit: 2.2 m wide, 0.3 m high
	box(op, Vector3(1.9, 0.27, -2.05), Vector3(1.6, 0.34, 0.3), logs)
	marker("OPSlit", Vector3(0, 1.5, 248.0))
	box(op, Vector3(1.6, -0.6, 1.0), Vector3(1.2, 0.06, 0.8), "planks")            # the table, the map under oilcloth
	box(op, Vector3(1.6, -0.56, 1.0), Vector3(0.9, 0.01, 0.6), flat(Color(0.32, 0.36, 0.3), 0.3))
	box(op, Vector3(1.6, -0.95, 1.0), Vector3(0.06, 0.7, 0.06), "beam")
	cyl(op, Vector3(1.9, -0.52, 0.8), 0.04, 0.06, "tin")                             # the candle in its tin
	var cl: OmniLight3D = omni(op, Vector3(1.9, -0.35, 0.8), [1.0, 0.7, 0.4], 0.9, 4.0)
	cl.set_meta("flicker", 0.9)
	cl.add_to_group(&"cinema_flicker")
	ball(op, Vector3(1.9, -0.42, 0.8), Vector3(0.015, 0.035, 0.015), glow(Color(1.0, 0.8, 0.45), 3.0))
	var phone: Node3D = group(op, "Handset", Vector3(-1.5, -0.55, -1.6))
	box(phone, Vector3.ZERO, Vector3(0.28, 0.22, 0.18), "walnut")                   # the field telephone's box
	box(phone, Vector3(0, 0.15, 0), Vector3(0.22, 0.05, 0.06), "bakelite")
	cyl(op, Vector3(0.8, -0.1, -1.85), 0.05, 1.3, "olive_steel")                     # the trench periscope
	box(op, Vector3(0.8, 0.55, -1.95), Vector3(0.08, 0.14, 0.18), "olive_steel")
	omni(op, Vector3(0, 0.0, -1.0), [0.6, 0.65, 0.72], 0.6, 6.0)                      # the grey day through the slit
	var cap: Array = ["rkka_officer_a", "volkov_1944", "rkka_officer_b"]
	for k: int in 3:
		var p: CinemaPerson = person(op, ["Officer_A", "Volkov", "Officer_B"][k], look_of(cap[k]), Vector3(-1.0 + 1.0 * float(k), -1.2, -1.35), 0.0,
			"hold" if k != 1 else "stand")
		p.name = ["OfficerA", "Volkov", "OfficerB"][k]
		if k != 1:
			p.hold_lift = 1.0


## Shot 4: the handset in Volkov's hand (he gives it to the colonel without a word).
func fx_handset(_secs: float) -> void:
	var v: CinemaPerson = find_child("Volkov", true, false) as CinemaPerson
	if v == null or v.has_meta("handset"):
		return
	v.set_meta("handset", true)
	v.set_pose(&"hold")
	v.hold_lift = 0.9
	var hs: Node3D = Node3D.new()
	box(hs, Vector3(0, 0, 0), Vector3(0.05, 0.2, 0.05), "bakelite")
	v.in_hand(hs, true, Vector3(0, -0.04, -0.03))


## Shot 5: three salvoes land in the line and do not explode properly: a thud and a low dirty brown puff that lies
## down in the rain instead of rising.
func fx_shells_soft(_secs: float) -> void:
	var times: Array = [2.0, 2.7, 3.3]
	for s: int in times.size():
		later(float(times[s]) - 0.1, func() -> void:
			for k: int in 4:
				var p: Vector3 = Vector3(-22.0 + 14.0 * float(k) + rng.randf_range(-4, 4), 0.2, rng.randf_range(-6.0, 6.0))
				var d: GPUParticles3D = dust(self, p, Color(0.3, 0.23, 0.14, 0.95), 9.0, 0.45, 7.0, 26, 3.5)
				var pm: ParticleProcessMaterial = d.process_material as ParticleProcessMaterial
				pm.direction = Vector3(1, 0.15, 0)
				pm.spread = 180.0
				pm.gravity = Vector3(0, -0.05, 0)
				d.emitting = true
				dust(self, p, Color(0.2, 0.16, 0.11, 0.9), 0.8, 3.0, 1.0, 10, 0.4).emitting = true)
