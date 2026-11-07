extends CinemaSet
## T-194, STAUB sets N-O (§6.3): the night of 20 December 1944 above Kaltenbrunn. The north ramp at the origin under
## its floods: a rail frame with six squat rockets aimed east (+x) over the hills, each with a steel canister clamped
## under its nose (placard level: a lot number, no other marking), a crew in winter whites, the control hut's open
## lit door. On the hill to the west (x -120, 24 m up) the weather station: a plank hut with a lit window, the
## instrument screen, a 6 m mast with the anemometer's cups and the wind vane. Below, the valley's lights (lit cards,
## each switchable): Kaltenbrunn village, Wilcza Góra across it, a dozen farms, the lamp at the Kreuzweg far
## north-west. The eastern ridge at x +600. Markers: Ramp, Hut, Vane, Valley. Effects: launch, wind_turn, haze,
## lights_out.

var rockets: Array[Node3D] = []
var cups: Node3D
var vane: Node3D
var lights: Array = []        # [node, x] the valley's lamps, east first when they go out
var haze: Array[MeshInstance3D] = []
var _t: float = 0.0
var _cup_speed: float = 6.0


func _build() -> void:
	env({"bg": [0.02, 0.02, 0.04], "ambient": [0.28, 0.3, 0.42], "ambient_e": 0.32, "fog": [0.06, 0.06, 0.1], "fog_d": 0.0016, "glow_t": 0.8, "glow_i": 1.0, "bloom": 0.1})
	sun(Vector3(-25, 60, 0), [0.5, 0.56, 0.75], 0.16)
	var snow: StandardMaterial3D = noisy(Color(0.6, 0.62, 0.7), Color(0.8, 0.82, 0.9), 0.04, 6.0, 0.85)
	plane(self, Vector3(200, 0, 0), Vector2(2400, 2400), snow)
	# the hill under the weather station and the eastern ridge
	ball(self, Vector3(-130, -30, 60), Vector3(160, 110, 140), snow)
	for k: int in 7:
		ball(self, Vector3(640, -20, -600 + 200.0 * float(k)), Vector3(260, 170 + rng.randf_range(-30, 40), 260), noisy(Color(0.05, 0.05, 0.07), Color(0.12, 0.12, 0.15), 0.05, 20.0, 0.9))
	_ramp()
	_station(Vector3(-120, 24.5, 60))
	_valley()
	_haze()
	marker("Valley", Vector3(260, 4, -40))


func _ramp() -> void:
	var r: Node3D = group(self, "RampFrame", Vector3.ZERO)
	var steel: Variant = "olive_steel"
	for k: int in 6:
		var z: float = -5.0 + 2.0 * float(k)
		var rail: Node3D = group(r, "Rail_%d" % k, Vector3(0, 0, z))
		box(rail, Vector3(0, 1.6, 0), Vector3(7.0, 0.12, 0.25), steel, Vector3(0, 0, 32))
		box(rail, Vector3(-2.6, 0.5, 0), Vector3(0.18, 1.0, 0.18), steel)
		box(rail, Vector3(1.4, 2.0, 0), Vector3(0.18, 4.0, 0.18), steel)
		var rk: Node3D = group(rail, "Rocket_%d" % k, Vector3(0.4, 1.95, 0))
		rk.rotation_degrees = Vector3(0, 0, 32)
		cyl(rk, Vector3.ZERO, 0.3, 2.4, "grey_paint", Vector3(0, 0, -90))
		for f: int in 4:
			box(rk, Vector3(-1.3, 0, 0), Vector3(0.6, 0.02, 0.7), "grey_paint", Vector3(45.0 * float(f), 0, 0))
		cyl(rk, Vector3(1.5, -0.1, 0), 0.24, 0.7, "steel", Vector3(0, 0, -90))   # the canister clamped under the nose
		cone(rk, Vector3(1.95, 0, 0), 0.3, 0.05, 0.6, "grey_paint", 12, Vector3(0, 0, -90))
		words(rk, "4-%02d" % (12 + k), Vector3(0, 0, 0.31), 0.004, Color(0.9, 0.88, 0.8))
		var ex: MeshInstance3D = cone(rk, Vector3(-1.6, 0, 0), 0.05, 0.4, 1.8, glow(Color(1.0, 0.6, 0.25), 4.0), 10, Vector3(0, 0, -90))
		ex.name = "Exhaust"
		ex.visible = false
		rockets.append(rk)
	marker("Ramp", Vector3(0.5, 2.0, 0))
	for fx2: float in [-14.0, 14.0]:   # the floods on their poles
		box(r, Vector3(fx2, 4.0, -9.0), Vector3(0.2, 8.0, 0.2), "beam")
		box(r, Vector3(fx2, 8.0, -9.0), Vector3(0.6, 0.4, 0.4), "machine_grey")
		glow_dot(r, Vector3(fx2, 8.0, -8.7), 3.0, Color(1.0, 0.95, 0.8), 1.4)
		spot(r, Vector3(fx2, 8.0, -8.6), Vector3(0, 0, 0), [1.0, 0.95, 0.82], 5.0, 40.0, 40.0)
	var hut: Node3D = group(r, "ControlHut", Vector3(-10, 0, 9))
	box(hut, Vector3(0, 1.4, 0), Vector3(4.0, 2.8, 3.0), "planks")
	box(hut, Vector3(0.9, 1.0, -1.52), Vector3(0.9, 2.0, 0.02), glow(Color(1.0, 0.85, 0.6), 1.6))
	omni(hut, Vector3(0.9, 1.2, -2.2), [1.0, 0.85, 0.6], 1.2, 6.0)
	for c: int in 3:   # the crew in winter whites
		person(r, "ramp_crew_%d" % c, look_of("ramp_crew"), Vector3(-4.0 + 2.6 * float(c), 0, 8.0 + 1.2 * float(c % 2)), 90.0 + rng.randf_range(-40, 40), "stand")
	for s: int in 4:   # sheds and pipework behind
		box(self, Vector3(-30.0 + 15.0 * float(s), 2.5, -26.0), Vector3(10.0, 5.0, 7.0), "fl_corrugated")
	precipitation(self, Vector3(0, 0, 0), Vector3(18, 6, 18), true, 600)


func _station(at: Vector3) -> void:
	var h: Node3D = group(self, "Station", at)
	box(h, Vector3(0, 1.3, 0), Vector3(3.0, 2.6, 2.6), "planks")
	box(h, Vector3(0, 2.75, 0), Vector3(3.4, 0.15, 3.0), "tarp")
	var win: MeshInstance3D = box(h, Vector3(1.51, 1.4, 0.3), Vector3(0.02, 0.7, 0.9), glow(Color(1.0, 0.82, 0.55), 1.8), Vector3.ZERO, "Window")
	omni(h, Vector3(2.2, 1.4, 0.3), [1.0, 0.8, 0.55], 1.0, 8.0)
	marker("Hut", at + Vector3(1.6, 1.4, 0.3))
	var screen: Node3D = group(h, "Screen", Vector3(3.0, 0, -2.4))   # the instrument screen
	box(screen, Vector3(0, 1.4, 0), Vector3(0.7, 0.6, 0.5), "paint_cream")
	for lx: float in [-0.3, 0.3]:
		box(screen, Vector3(lx, 0.55, 0), Vector3(0.05, 1.1, 0.05), "paint_cream")
	var mast: Node3D = group(h, "Mast", Vector3(2.6, 0, 2.0))
	cyl(mast, Vector3(0, 3.0, 0), 0.05, 6.0, "steel")
	Props.cable(h, Vector3(2.6, 5.8, 2.0), Vector3(5.6, 0.0, 3.5), 0.1, 0.006, 4, "steel")
	cups = group(mast, "Cups", Vector3(0, 6.05, 0))
	for k: int in 3:
		var a: float = TAU * float(k) / 3.0
		box(cups, Vector3(cos(a) * 0.25, 0, sin(a) * 0.25), Vector3(0.5, 0.015, 0.015), "steel", Vector3(0, -rad_to_deg(a), 0))
		ball(cups, Vector3(cos(a) * 0.5, 0, sin(a) * 0.5), Vector3(0.12, 0.12, 0.12), "steel")
	vane = group(mast, "Vane", Vector3(0, 6.45, 0))
	box(vane, Vector3(0.0, 0, 0), Vector3(1.1, 0.03, 0.03), "steel")
	cone(vane, Vector3(0.6, 0, 0), 0.06, 0.0, 0.18, "steel", 4, Vector3(0, 0, -90))
	box(vane, Vector3(-0.5, 0.05, 0), Vector3(0.3, 0.22, 0.01), "steel")
	marker("Vane", at + Vector3(2.6, 6.4, 2.0))


func _valley() -> void:
	var v: Node3D = group(self, "Lights", Vector3.ZERO)
	var warm: Color = Color(1.0, 0.72, 0.38)
	var spots: Array = []
	for i: int in 22:   # Kaltenbrunn village in the valley
		spots.append(Vector3(220 + rng.randf_range(-40, 40), 1.5, -140 + rng.randf_range(-35, 35)))
	for j: int in 14:   # Wilcza Góra across it
		spots.append(Vector3(360 + rng.randf_range(-30, 30), 2.0, 110 + rng.randf_range(-25, 25)))
	for f: int in 12:   # the farms
		spots.append(Vector3(rng.randf_range(120, 520), 1.5, rng.randf_range(-320, 320)))
	spots.append(Vector3(-420, 3.0, -430))   # the lamp at the Kreuzweg, far north-west
	for p: Variant in spots:
		var d: MeshInstance3D = glow_dot(v, p as Vector3, 3.2, warm, 1.7)
		lights.append([d, (p as Vector3).x])
	lights.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]))   # east first


func _haze() -> void:
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	var gt: GradientTexture2D = GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 1.0)
	gt.fill_to = Vector2(0.5, 0.0)
	for k: int in 4:
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_texture = gt
		m.albedo_color = Color(0.5, 0.26, 0.75, 0.0)
		var q: MeshInstance3D = card(self, Vector3(640 + 30.0 * float(k), 60.0, -200.0 + 130.0 * float(k)), Vector2(1100, 170), m, 90.0 + rng.randf_range(-10, 10), "Haze_%d" % k)
		haze.append(q)


## Shot 6: six streaks going east over the hills, low, their exhaust lighting the snow.
func fx_launch(secs: float) -> void:
	for k: int in rockets.size():
		var rk: Node3D = rockets[k]
		later(0.25 + 0.42 * float(k), func() -> void:
			(rk.get_node("Exhaust") as Node3D).visible = true
			var l: OmniLight3D = omni(rk, Vector3(-1.6, 0, 0), [1.0, 0.6, 0.3], 6.0, 22.0)
			dust(self, rk.global_position if rk.is_inside_tree() else Vector3.ZERO, Color(0.7, 0.68, 0.66, 0.8), 3.0, 1.5, 3.0, 18, 1.0).emitting = true
			var to: Vector3 = rk.position + Vector3(cos(deg_to_rad(32.0)), sin(deg_to_rad(32.0)), 0) * 700.0
			tween_to(rk, "position", to, maxf(1.5, secs * 0.6), Tween.TRANS_QUAD, Tween.EASE_IN)
			tween_to(l, "light_energy", 0.0, maxf(1.5, secs * 0.6), Tween.TRANS_LINEAR))


## Shot 7: the cups slow, stop and start the other way; the vane swings a quarter, hesitates, then round to the west.
func fx_wind_turn(secs: float) -> void:
	vane.rotation.y = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(self, "_cup_speed", 0.0, secs * 0.3).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "_cup_speed", -9.0, secs * 0.35).set_trans(Tween.TRANS_SINE)
	var tv: Tween = create_tween()
	tv.tween_interval(secs * 0.2)
	tv.tween_property(vane, "rotation:y", PI * 0.5, secs * 0.18).set_trans(Tween.TRANS_SINE)
	tv.tween_property(vane, "rotation:y", PI * 0.42, secs * 0.12).set_trans(Tween.TRANS_SINE)
	tv.tween_property(vane, "rotation:y", PI, secs * 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Shot 8: the dust comes back over the eastern ridge, a violet haze lit from inside by nothing, rolling down the
## valley; the lights go out one by one as it reaches them, the plant's floods last.
func fx_haze(secs: float) -> void:
	vane.rotation.y = PI
	_cup_speed = -10.0
	for k: int in haze.size():
		var q: MeshInstance3D = haze[k]
		var m: StandardMaterial3D = q.material_override as StandardMaterial3D
		m.albedo_color.a = 0.0
		tween_to(m, "albedo_color:a", 0.75, secs * 0.4, Tween.TRANS_SINE, Tween.EASE_IN_OUT, 0.2 * float(k))
		tween_to(q, "position:x", 120.0 + 40.0 * float(k), secs * 1.1, Tween.TRANS_LINEAR)
		tween_to(q, "position:y", 40.0, secs * 1.1, Tween.TRANS_LINEAR)
	fx_lights_out(secs)


func fx_lights_out(secs: float) -> void:
	for i: int in lights.size():
		var d: MeshInstance3D = lights[i][0]
		var x: float = float(lights[i][1])
		var when: float = clampf((620.0 - x) / 620.0, 0.0, 1.0) * secs * 0.92 + 0.6
		later(when, func() -> void:
			if is_instance_valid(d):
				d.visible = false)


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	if cups != null:
		cups.rotation.y += delta * _cup_speed
	if vane != null and absf(_cup_speed) > 1.0:
		vane.rotation.y += sin(_t * 3.0) * 0.002
