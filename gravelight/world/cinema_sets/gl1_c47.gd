extends CinemaSet
## T-194, GRAVELIGHT ONE sets Q-R (§6.4): inside the C-47 over the front at night, 23 December 1944. The hull T-126
## built as a wreck on Map 0 (gen_map00's ribs, planked floor, bucket seats, static line, cargo net), built whole:
## both walls' seats, nine round windows a side, a red dome lamp, frost on the inside of the skin, the cargo lashed.
## Nose at -z: the cabin from z +6 to the bulkhead at -4.6, the cockpit beyond it (two seats, the panel with its
## red-lit dials whose needles fall and lamps go out, the columns, the windscreen). Selwyn (people.json `selwyn`) in
## the left seat, the co-pilot in the right (never close). The four passengers on the port seats are the players'
## characters (the stage's `roster` meta: the window seat first; CinemaPerson with their people.json bodies, seated).
## Outside: the sky, and 600 m down a ground card moving at 60 m/s along +z: snow, black woods, a river, gun pits and
## burning vehicles (fire cards), parachute flares drifting down with their light, and the columns walking west
## (a MultiMesh of 240 figures; T-192's distant walkers can replace it through CinemaRisen's seam later).
## Markers: Window, Panel, Faces, Floor, Selwyn. Effects: lean_window, flare_cabin, violet_in, engines_die, crash.

const GROUND_Y: float = -600.0
const AIR_SPEED: float = 60.0

var ground: Node3D
var flares: Array = []          # [node, light, fall speed]
var walkers_mm: MultiMeshInstance3D
var dome: OmniLight3D
var dome_mesh: MeshInstance3D
var violet: OmniLight3D
var cockpit_red: OmniLight3D
var panel_lamps: Array[MeshInstance3D] = []
var needles: Array[Node3D] = []
var cargo: Array[Node3D] = []
var passengers: Array[CinemaPerson] = []
var whiteout: MeshInstance3D
var _t: float = 0.0
var _flare_clock: float = 0.0


func _build() -> void:
	env({"sky_top": [0.006, 0.008, 0.02], "sky_horizon": [0.04, 0.04, 0.07], "ground": [0.02, 0.02, 0.03], "sky_e": 1.0,
		"ambient": [0.2, 0.22, 0.32], "ambient_e": 0.12, "fog": [0.03, 0.03, 0.05], "fog_d": 0.00015, "glow_t": 0.8, "glow_i": 1.0, "bloom": 0.1})
	sun(Vector3(-35, 40, 0), [0.45, 0.5, 0.7], 0.12)
	_hull()
	_cockpit()
	_passengers()
	_outside()


# ---------------------------------------------------------------- the hull

func _hull() -> void:
	var skin: StandardMaterial3D = noisy(Color(0.26, 0.28, 0.25), Color(0.36, 0.38, 0.34), 1.0, 0.6, 0.6)
	var frost: StandardMaterial3D = noisy(Color(0.5, 0.53, 0.56), Color(0.72, 0.74, 0.78), 2.0, 0.4, 0.5)
	box(self, Vector3(0, -0.05, 0.7), Vector3(2.5, 0.1, 10.8), "floorboards")
	var segs: Array = []
	var frosts: Array = []
	var ribs: Array = []
	var z: float = -4.6
	var bay: int = 0
	while z < 6.0:
		var zc: float = z + 0.55
		for side: float in [-1.0, 1.0]:
			var x: float = side * 1.3
			segs.append(xf(Vector3(x, 0.52, zc), Vector3(0.06, 1.04, 1.1)))
			segs.append(xf(Vector3(x, 1.56, zc), Vector3(0.06, 0.12, 1.1)))
			segs.append(xf(Vector3(x, 1.3, zc - 0.36), Vector3(0.06, 0.4, 0.38)))
			segs.append(xf(Vector3(x, 1.3, zc + 0.36), Vector3(0.06, 0.4, 0.38)))
			segs.append(xf(Vector3(side * 1.02, 1.88, zc), Vector3(0.06, 0.72, 1.1), Vector3(0, 0, side * 52.0)))
			frosts.append(xf(Vector3(x - side * 0.035, 0.9, zc), Vector3(0.01, 0.4, 1.0)))
			ribs.append(xf(Vector3(x - side * 0.06, 1.0, z), Vector3(0.05, 2.0, 0.07)))
			ribs.append(xf(Vector3(side * 0.95, 1.95, z), Vector3(0.05, 0.75, 0.07), Vector3(0, 0, side * 52.0)))
			# the window: a round frame, frosted glass at the edges
			var ring: TorusMesh = TorusMesh.new()
			ring.inner_radius = 0.15
			ring.outer_radius = 0.19
			var rm: MeshInstance3D = MeshInstance3D.new()
			rm.mesh = ring
			rm.material_override = mat("iron")
			rm.position = Vector3(x - side * 0.04, 1.3, zc)
			rm.rotation_degrees = Vector3(0, 0, 90)
			add_child(rm)
			var gl: StandardMaterial3D = flat(Color(0.75, 0.8, 0.85, 0.08), 0.05)
			gl.cull_mode = BaseMaterial3D.CULL_DISABLED
			card(self, Vector3(x, 1.3, zc), Vector2(0.36, 0.36), gl, 90.0)
			if side < 0.0 and bay == 4:
				marker("Window", Vector3(x, 1.3, zc))
		ribs.append(xf(Vector3(0, 2.24, z), Vector3(1.4, 0.05, 0.07)))
		z += 1.1
		bay += 1
	multi(self, Props.unit_box(), segs, skin, "Skin")
	multi(self, Props.unit_box(), frosts, frost, "Frost")
	multi(self, Props.unit_box(), ribs, "iron", "Ribs")
	box(self, Vector3(0, 2.25, 0.7), Vector3(1.45, 0.06, 10.8), skin)            # the roof
	box(self, Vector3(0, 1.1, 6.05), Vector3(2.6, 2.4, 0.1), skin)               # the aft bulkhead
	for side2: float in [-1.0, 1.0]:   # bucket seats along both walls
		for sz: int in 8:
			var szz: float = -3.4 + 1.05 * float(sz)
			box(self, Vector3(side2 * 1.08, 0.46, szz), Vector3(0.42, 0.05, 0.5), "iron")
			box(self, Vector3(side2 * 1.26, 0.8, szz), Vector3(0.04, 0.55, 0.5), "#4b5333", Vector3(0, 0, side2 * -4.0))
	cyl(self, Vector3(0.55, 2.05, 0.7), 0.012, 10.5, "iron", Vector3(90, 0, 0))   # the static line
	for c: int in 3:   # the cargo, lashed under its net on the starboard side aft
		var cg: Node3D = group(self, "Cargo_%d" % c, Vector3(0.6, 0.0, 3.6 + 0.75 * float(c)))
		Props.crate(cg, Vector3.ZERO, 0.6, 10.0 * float(c), "")
		cargo.append(cg)
	box(self, Vector3(0.6, 0.66, 4.35), Vector3(0.75, 0.04, 2.3), "net")
	dome = omni(self, Vector3(0, 2.05, 0.6), [1.0, 0.12, 0.08], 1.3, 6.5)
	dome_mesh = ball(self, Vector3(0, 2.18, 0.6), Vector3(0.14, 0.08, 0.14), glow(Color(1.0, 0.15, 0.1), 2.2))
	violet = omni(self, Vector3(1.0, 1.4, 0.3), [0.65, 0.38, 1.0], 0.0, 5.0)
	marker("Faces", Vector3(-0.9, 1.05, 1.0))
	marker("Floor", Vector3(0, 0.1, 1.0))
	whiteout = card(self, Vector3(0, 0.8, -1.2), Vector2(4.0, 3.0), glow(Color(1, 1, 1), 3.0), 0.0, "Whiteout")
	(whiteout.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	(whiteout.material_override as StandardMaterial3D).albedo_color.a = 0.0
	whiteout.visible = false


# ---------------------------------------------------------------- the cockpit

func _cockpit() -> void:
	var skin: StandardMaterial3D = flat(Color(0.18, 0.19, 0.17), 0.6)
	for bx: float in [-0.95, 0.95]:   # the bulkhead and its doorway
		box(self, Vector3(bx, 1.1, -4.6), Vector3(1.0, 2.3, 0.08), skin)
	box(self, Vector3(0, 2.1, -4.6), Vector3(0.9, 0.3, 0.08), skin)
	box(self, Vector3(0, 0.15, -5.8), Vector3(2.0, 0.3, 2.4), "floorboards")
	for sx: float in [-1.0, 1.0]:
		box(self, Vector3(sx * 1.05, 1.0, -5.8), Vector3(0.06, 2.0, 2.4), skin, Vector3(0, 0, sx * 6.0))
	box(self, Vector3(0, 2.05, -5.6), Vector3(2.1, 0.08, 2.0), skin)
	var p: Node3D = group(self, "PanelGroup", Vector3(0, 0, -6.45))
	box(p, Vector3(0, 1.1, 0), Vector3(1.8, 0.5, 0.12), "#1f201d", Vector3(-12, 0, 0))
	for k: int in 14:
		var c: Vector3 = Vector3(-0.78 + 0.12 * float(k), 1.05 + (0.12 if k % 2 == 0 else -0.06), 0.07)
		var dl: MeshInstance3D = cyl(p, c, 0.045, 0.02, glow(Color(0.9, 0.18, 0.1), 1.2), Vector3(78, 0, 0))
		panel_lamps.append(dl)
		var n: Node3D = group(p, "Needle", c + Vector3(0, 0, 0.02))
		box(n, Vector3(0, 0.02, 0), Vector3(0.005, 0.04, 0.004), "#e8e2cc")
		n.rotation.z = rng.randf_range(-0.8, 0.8)
		needles.append(n)
	marker("Panel", Vector3(-0.3, 1.1, -6.35))
	cockpit_red = omni(self, Vector3(0, 1.3, -6.1), [1.0, 0.2, 0.12], 0.9, 3.0)
	for sx2: float in [-0.45, 0.45]:   # the seats, the columns and yokes
		box(self, Vector3(sx2, 0.72, -5.45), Vector3(0.52, 0.08, 0.5), "rust")
		box(self, Vector3(sx2, 1.1, -5.18), Vector3(0.52, 0.75, 0.07), "#3b3a2c", Vector3(-10, 0, 0))
		cyl(self, Vector3(sx2, 0.75, -6.0), 0.03, 0.75, "iron", Vector3(-12, 0, 0))
		box(self, Vector3(sx2, 1.12, -6.08), Vector3(0.36, 0.05, 0.05), "iron")
	var glass: StandardMaterial3D = flat(Color(0.6, 0.66, 0.72, 0.1), 0.02)
	for wx: float in [-0.5, 0.5]:   # the windscreen
		var w: MeshInstance3D = card(self, Vector3(wx, 1.65, -6.7), Vector2(0.9, 0.5), glass, 0.0)
		w.rotation_degrees = Vector3(-22, wx * -20.0, 0)
	for fx2: float in [-0.95, 0.0, 0.95]:
		box(self, Vector3(fx2, 1.65, -6.72), Vector3(0.05, 0.55, 0.05), "iron", Vector3(-22, 0, 0))
	box(self, Vector3(0, 1.4, -6.75), Vector3(2.0, 0.06, 0.1), "iron")
	box(self, Vector3(0, 0.7, -6.85), Vector3(2.0, 1.4, 0.1), skin)
	var sel: CinemaPerson = person(self, "selwyn", {"person": "selwyn"}, Vector3(-0.45, 0.3, -5.5), 0.0, "sit_hold")
	sel.name = "Selwyn"
	sel.hold_lift = 0.4
	var co: CinemaPerson = person(self, "copilot", look_of("copilot"), Vector3(0.45, 0.3, -5.5), 0.0, "sit_hold")
	co.name = "CoPilot"
	co.hold_lift = 0.4


func _passengers() -> void:
	var roster: Array = get_meta("roster", CinemaLibrary.SQUAD) as Array
	for i: int in mini(4, roster.size()):
		var who: String = str(roster[i])
		var z: float = [1.65, -0.45, -1.5, -2.55][i]   # (the seat under the window bay at z 0.35 is left empty for the view)
		var p: CinemaPerson = person(self, "passenger_%d" % i, {"person": who}, Vector3(-0.98, 0.0, z), -90.0, "sit")
		p.name = "Passenger_%d" % i
		box(self, Vector3(-0.45, 0.15, z), Vector3(0.35, 0.3, 0.25), "olive_drab", Vector3(0, rng.randf_range(-20, 20), 0))   # kit between the boots
		passengers.append(p)
	if not passengers.is_empty():
		passengers[min(3, passengers.size() - 1)].head_down = 0.5   # one is asleep, or pretending


# ---------------------------------------------------------------- outside: the front 600 m down

func _outside() -> void:
	ground = group(self, "Ground", Vector3(0, GROUND_Y, -1500))
	var snow: StandardMaterial3D = noisy(Color(0.2, 0.21, 0.26), Color(0.56, 0.58, 0.64), 0.012, 60.0, 0.9)
	plane(ground, Vector3(0, 0, 0), Vector2(5000, 7000), snow)
	var woods: Array = []
	for i: int in 160:
		woods.append(xf(Vector3(rng.randf_range(-2400, 2400), 4.0, rng.randf_range(-3400, 3400)), Vector3(rng.randf_range(60, 260), 12.0, rng.randf_range(60, 300))))
	multi(ground, Props.unit_sphere(), woods, flat(Color(0.03, 0.04, 0.04)), "Woods")
	box(ground, Vector3(-300, 0.5, 0), Vector3(40, 1.0, 7000), flat(Color(0.03, 0.035, 0.05), 0.2), Vector3(0, 8, 0))   # the river
	for f: int in 26:   # gun pits and burning vehicles
		var fp: Vector3 = Vector3(rng.randf_range(-900, 900), 3.0, rng.randf_range(-3200, 3200))
		glow_dot(ground, fp, rng.randf_range(16, 32), Color(1.0, 0.45, 0.15), 1.2)
	# the columns walking west: dark figures in loose files
	var figs: Array = []
	for col: int in 6:
		var cx: float = rng.randf_range(-700, 500)
		var cz: float = rng.randf_range(-2600, 2600)
		for k: int in 40:
			figs.append(xf(Vector3(cx - float(k) * 9.0 + rng.randf_range(-3, 3), 3.0, cz + rng.randf_range(-8, 8)), Vector3(2.4, 6.5, 2.4)))
	walkers_mm = multi(ground, Props.unit_box(), figs, flat(Color(0.05, 0.05, 0.06)), "Columns")
	# the violet column ahead, bearing oh-four-oh
	var vm: StandardMaterial3D = glow(Color(0.62, 0.35, 1.0), 3.0)
	cyl(self, Vector3(1000, 600, -3600), 70.0, 3600.0, vm, Vector3.ZERO, "VioletColumn")
	glow_dot(self, Vector3(1000, -400, -3500), 1100.0, Color(0.5, 0.25, 0.9), 0.6)
	for k2: int in 4:
		_new_flare(k2)


func _new_flare(k: int) -> void:
	var f: Node3D = group(ground, "Flare_%d" % k, Vector3(rng.randf_range(-700, -100), rng.randf_range(160, 260), rng.randf_range(400, 1600)))
	glow_dot(f, Vector3.ZERO, 26.0, Color(1.0, 0.98, 0.9), 3.0)
	var l: OmniLight3D = omni(f, Vector3.ZERO, [1.0, 0.97, 0.88], 6.0, 420.0)
	l.omni_attenuation = 1.0
	flares.append([f, l, rng.randf_range(3.0, 5.0)])


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	if ground != null:
		ground.position.z += AIR_SPEED * delta
		if ground.position.z > 2600.0:
			ground.position.z -= 4200.0
		for fl: Array in flares:
			var f: Node3D = fl[0]
			f.position.y -= float(fl[2]) * delta
			f.position.x += sin(_t * 0.3 + f.position.z) * delta
			if f.position.y < 20.0 or f.global_position.z > 900.0:
				f.position = Vector3(rng.randf_range(-700, -100), rng.randf_range(200, 280), -f.get_parent().position.z - rng.randf_range(800, 1600))
	if dome != null and dome.light_energy > 0.0 and dome.has_meta("flicker_on"):
		dome.light_energy = 1.3 * (0.6 + 0.4 * absf(sin(_t * 17.0)))


# ---------------------------------------------------------------- the effects

## Shot 3-4: the window seat's passenger is up at the glass, looking out.
func fx_lean_window(_secs: float) -> void:
	if passengers.is_empty():
		return
	var p: CinemaPerson = passengers[1] if passengers.size() > 1 else passengers[0]
	p = passengers[0]
	p.position = Vector3(-0.95, 0.0, 0.42)
	p.rotation.y = deg_to_rad(90.0)
	p.set_pose(&"stand")
	p.head_down = 0.25
	p.reset_motion()


## Shot 4: a flare lights the cabin white for a second.
func fx_flare_cabin(secs: float) -> void:
	var l: OmniLight3D = omni(self, Vector3(-1.5, 1.3, 0.5), [1.0, 0.98, 0.92], 2.5, 4.0)
	var tw: Tween = create_tween()
	tw.tween_interval(secs * 0.3)
	tw.tween_property(l, "light_energy", 0.0, 1.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_callback(l.queue_free)


## Shot 6: the violet comes through the starboard windows and lies across their faces; the dome lamp dims.
func fx_violet_in(secs: float) -> void:
	if passengers.size() > 0:
		var p: CinemaPerson = passengers[0]
		p.position = Vector3(-0.98, 0.0, 1.65)
		p.rotation.y = deg_to_rad(-90.0)
		p.set_pose(&"sit")
		p.head_down = 0.0
		p.reset_motion()
	tween_to(violet, "light_energy", 2.6, minf(3.0, secs * 0.6), Tween.TRANS_SINE)
	tween_to(dome, "light_energy", 0.35, minf(3.0, secs * 0.6), Tween.TRANS_SINE)


## Shot 7: both engines at once: the needles fall, the panel's lamps go out.
func fx_engines_die(secs: float) -> void:
	for k: int in panel_lamps.size():
		var lamp: MeshInstance3D = panel_lamps[k]
		later(0.3 + secs * 0.04 * float(k % 5), func() -> void: lamp.visible = false)
	for n: Node3D in needles:
		tween_to(n, "rotation:z", -1.3, secs * 0.4, Tween.TRANS_QUAD, Tween.EASE_IN, 0.3)
	tween_to(cockpit_red, "light_energy", 0.0, secs * 0.4, Tween.TRANS_SINE, Tween.EASE_IN_OUT, 0.3)
	violet.position = Vector3(0, 1.6, -6.0)
	violet.light_energy = 2.0
	violet.omni_range = 4.0


## Shot 9: the crash from the floor: the first touch, the second, the lamp goes, the cargo breaks loose, white.
func fx_crash(secs: float) -> void:
	violet.light_energy = 1.2
	violet.position = Vector3(1.0, 1.4, 0.3)
	violet.omni_range = 5.0
	dome.set_meta("flicker_on", true)
	for c: int in cargo.size():
		var cg: Node3D = cargo[c]
		later(secs * 0.62, func() -> void:
			tween_to(cg, "position", cg.position + Vector3(-1.0 + 0.4 * float(c), 0.25, -2.4 - 0.5 * float(c)), 0.5, Tween.TRANS_QUAD, Tween.EASE_OUT)
			tween_to(cg, "rotation", Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(-1.5, 1.5), rng.randf_range(-0.8, 0.8)), 0.5))
	later(secs * 0.7, func() -> void:
		dome.remove_meta("flicker_on")
		dome.light_energy = 0.0
		dome_mesh.visible = false
		violet.light_energy = 0.4)
	later(secs * 0.74, func() -> void:
		whiteout.visible = true
		var m: StandardMaterial3D = whiteout.material_override as StandardMaterial3D
		tween_to(m, "albedo_color:a", 1.0, secs * 0.12, Tween.TRANS_EXPO, Tween.EASE_IN))
