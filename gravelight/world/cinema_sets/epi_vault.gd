extends CinemaSet
## T-194, the Moscow 1953 epilogue, set T (§6.5): a concrete vault 3 x 3 m, one bulb in a cage, a steel shelf, and on
## it the grey lead case from the train, its paint worn to the metal at the corners. An old man's hand rests on it
## (liver spots, a signet ring, the cuff of a good dark suit, no uniform); the fingers tighten once, as if the case
## had moved. Nothing else moves. Markers: Case, Hand. Effects: tighten.

var fingers: Array[Node3D] = []
var bulb_light: OmniLight3D
var _t: float = 0.0


func _build() -> void:
	env({"bg": [0.0, 0.0, 0.0], "ambient": [0.3, 0.3, 0.28], "ambient_e": 0.16, "glow_t": 1.0, "glow_i": 0.7})
	box(self, Vector3(0, -0.05, 0), Vector3(3.2, 0.1, 3.2), "bunker_concrete")
	box(self, Vector3(0, 2.6, 0), Vector3(3.2, 0.1, 3.2), "bunker_concrete")
	for s: Array in [[Vector3(-1.6, 1.3, 0), Vector3(0.1, 2.6, 3.2)], [Vector3(1.6, 1.3, 0), Vector3(0.1, 2.6, 3.2)], [Vector3(0, 1.3, -1.6), Vector3(3.2, 2.6, 0.1)], [Vector3(0, 1.3, 1.6), Vector3(3.2, 2.6, 0.1)]]:
		box(self, s[0], s[1], "bunker_concrete")
	# the bulb in its cage
	cyl(self, Vector3(0.2, 2.45, 0.2), 0.008, 0.3, "iron")
	ball(self, Vector3(0.2, 2.27, 0.2), Vector3(0.07, 0.09, 0.07), glow(Color(1.0, 0.82, 0.55), 3.0))
	for k: int in 6:
		box(self, Vector3(0.2 + cos(TAU * float(k) / 6.0) * 0.07, 2.27, 0.2 + sin(TAU * float(k) / 6.0) * 0.07), Vector3(0.006, 0.2, 0.006), "iron")
	bulb_light = omni(self, Vector3(0.2, 2.2, 0.2), [1.0, 0.8, 0.55], 1.4, 5.0)
	# the steel shelf
	var steel: Variant = "steel"
	for sx: float in [-0.9, 0.9]:
		for sz: float in [-1.5, -1.0]:
			box(self, Vector3(sx, 0.75, sz), Vector3(0.04, 1.5, 0.04), steel)
	for sy: float in [0.3, 0.9, 1.45]:
		box(self, Vector3(0, sy, -1.25), Vector3(1.85, 0.03, 0.55), steel)
	var case: Node3D = group(self, "Case", Vector3(0.05, 1.04, -1.22))
	lead_case(case, true)
	_hand(Vector3(0.12, 1.175, -1.18))


## The hand: palm on the case's lid, the fingers over its edge, the thumb along its side; a signet ring; the
## shirt cuff and the dark suit cuff over the wrist, the forearm running off to the right of the frame.
func _hand(at: Vector3) -> void:
	var h: Node3D = group(self, "HandRig", at, 70.0)
	var skin: StandardMaterial3D = noisy(Color(0.62, 0.48, 0.4), Color(0.78, 0.63, 0.53), 18.0, 0.04, 0.6)
	var spots: StandardMaterial3D = flat(Color(0.45, 0.32, 0.24), 0.7)
	box(h, Vector3(0, 0.0, 0), Vector3(0.085, 0.028, 0.1), skin)                      # the back of the hand
	for k: int in 4:
		var f: Node3D = group(h, "Finger_%d" % k, Vector3(-0.032 + 0.021 * float(k), 0.0, -0.05))
		var ln: float = [0.075, 0.085, 0.082, 0.066][k]
		cyl(f, Vector3(0, 0, -ln * 0.5), 0.0085, ln, skin, Vector3(90, 0, 0))
		f.rotation_degrees = Vector3(-8, 0, 0)
		fingers.append(f)
	var th: Node3D = group(h, "Thumb", Vector3(-0.05, -0.005, 0.0))
	cyl(th, Vector3(-0.02, 0, -0.025), 0.009, 0.06, skin, Vector3(90, 40, 0))
	for s: int in 5:   # liver spots
		ball(h, Vector3(rng.randf_range(-0.035, 0.035), 0.0145, rng.randf_range(-0.04, 0.04)), Vector3(0.012, 0.002, 0.01), spots)
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 0.009
	ring.outer_radius = 0.0125
	var rm: MeshInstance3D = MeshInstance3D.new()
	rm.mesh = ring
	rm.material_override = flat(Color(0.72, 0.55, 0.22), 0.3, 0.0, 1.0)
	rm.position = Vector3(0.031, 0.0, -0.07)
	rm.rotation_degrees = Vector3(90, 0, 0)
	h.add_child(rm)
	box(h, Vector3(0.031, 0.011, -0.07), Vector3(0.012, 0.006, 0.01), rm.material_override)
	cyl(h, Vector3(0, 0.005, 0.085), 0.042, 0.04, "#e6e2d6", Vector3(90, 0, 0))     # the shirt cuff
	cyl(h, Vector3(0, -0.12, 0.45), 0.05, 0.75, "#1d1e24", Vector3(110, 0, 0))        # the suit's sleeve, down off the frame
	marker("Hand", at)


## Shot 2, at its end: the fingers tighten once, as if the case had moved.
func fx_tighten(secs: float) -> void:
	for f: Node3D in fingers:
		var tw: Tween = create_tween()
		tw.tween_interval(secs * 0.72)
		tw.tween_property(f, "rotation_degrees:x", -32.0, 0.35).set_trans(Tween.TRANS_SINE)
		tw.tween_interval(0.6)
		tw.tween_property(f, "rotation_degrees:x", -14.0, 1.2).set_trans(Tween.TRANS_SINE)


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	if bulb_light != null:   # the room's one electric lamp flickers (MAP4_FERNFLUG §12.11)
		var f: float = 1.0 if fmod(_t, 3.7) > 0.12 else 0.35
		bulb_light.light_energy = 1.4 * f * (0.96 + 0.04 * sin(_t * 50.0))
