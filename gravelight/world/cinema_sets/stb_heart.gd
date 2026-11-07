extends CinemaSet
## T-194, STAUB set P (§6.3): that same night, Kaltenbrunn's Core Vault: the Heart (a Nachtglas mass in its cage over
## the pit, violet light from below), the console and its resonance dial. Reinholt alone at it, her hand on the dial,
## turning it to its stop; the pencil behind her ear; her face lit from below. Built small here (the vault's look:
## dark rock, the cage, the console) instead of loading Kaltenbrunn for one shot. Markers: Dial, Heart, Reinholt.
## Effects: dial_turn.

var dial: Node3D
var heart_light: OmniLight3D
var crystal: Node3D
var _t: float = 0.0
var _hum: float = 1.0


func _build() -> void:
	env({"bg": [0.0, 0.0, 0.0], "ambient": [0.25, 0.18, 0.35], "ambient_e": 0.2, "fog": [0.2, 0.1, 0.3], "fog_d": 0.03, "glow_t": 0.8, "glow_i": 1.0, "bloom": 0.12})
	var rock: Variant = "rock_dark"
	box(self, Vector3(0, -0.05, 0), Vector3(16, 0.1, 16), "rock_floor")
	cyl(self, Vector3(0, -2.0, -5.0), 2.6, 4.0, flat(Color(0.02, 0.01, 0.03), 1.0))   # the pit
	for k: int in 10:
		var a: float = TAU * float(k) / 10.0
		box(self, Vector3(cos(a) * 8.0, 4.0, sin(a) * 8.0 - 2.0), Vector3(5.2, 8.0, 0.8), rock, Vector3(0, -rad_to_deg(a) + 90.0, 0))
	crystal = group(self, "Heart", Vector3(0, 2.4, -5.0))
	ball(crystal, Vector3.ZERO, Vector3(1.6, 2.1, 1.6), "nachtglas_crystal")
	for p: int in 7:
		var a2: float = TAU * float(p) / 7.0
		cone(crystal, Vector3(cos(a2) * 0.6, rng.randf_range(-0.6, 0.6), sin(a2) * 0.6), 0.22, 0.0, 1.2, "nachtglas_crystal", 6,
			Vector3(rng.randf_range(-50, 50), rad_to_deg(a2), rng.randf_range(40, 80)))
	for b: int in 12:   # the cage
		var a3: float = TAU * float(b) / 12.0
		box(self, Vector3(cos(a3) * 2.2, 2.4, sin(a3) * 2.2 - 5.0), Vector3(0.06, 5.0, 0.06), "iron")
	for ry: float in [0.4, 4.6]:
		var ring: TorusMesh = TorusMesh.new()
		ring.inner_radius = 2.17
		ring.outer_radius = 2.25
		var rm: MeshInstance3D = MeshInstance3D.new()
		rm.mesh = ring
		rm.material_override = mat("iron")
		rm.position = Vector3(0, ry, -5.0)
		add_child(rm)
	heart_light = omni(self, Vector3(0, 0.6, -4.0), [0.66, 0.36, 1.0], 4.0, 14.0)
	omni(self, Vector3(0, 3.2, -5.0), [0.6, 0.32, 1.0], 2.0, 9.0)
	# the console and its dial
	var c: Node3D = group(self, "Console", Vector3(0.4, 0, -1.4), 180.0)
	box(c, Vector3(0, 0.55, 0), Vector3(1.6, 1.1, 0.7), "machine_green", Vector3(-12, 0, 0))
	box(c, Vector3(0, 1.12, -0.05), Vector3(1.5, 0.06, 0.6), "machine_grey", Vector3(-24, 0, 0))
	for g: int in 3:
		cyl(c, Vector3(-0.5 + 0.35 * float(g), 1.15, 0.05), 0.08, 0.02, "gauge_lit", Vector3(66, 0, 0))
	dial = group(c, "Dial", Vector3(0.45, 1.17, -0.02))
	dial.rotation_degrees = Vector3(66, 0, 0)
	cyl(dial, Vector3.ZERO, 0.11, 0.05, "bakelite")
	box(dial, Vector3(0, 0.03, 0.07), Vector3(0.02, 0.012, 0.07), "brass")
	marker("Dial", Vector3(0.4 - 0.45, 1.2, -1.4 + 0.02))
	var r: CinemaPerson = person(self, "reinholt", look_of("reinholt"), Vector3(0.0, 0, -0.75), 180.0, "hold")
	r.name = "Reinholt"
	r.hold_lift = 0.85
	ball(r, Vector3(0.12, 1.66, 0.02), Vector3(0.01, 0.01, 0.14), "#c2a060")   # the pencil behind her ear


## Shot 9: her hand turns the resonance to its stop; the hum climbs.
func fx_dial_turn(secs: float) -> void:
	tween_to(dial, "rotation:y", deg_to_rad(-150.0), secs * 0.7, Tween.TRANS_SINE, Tween.EASE_IN_OUT, secs * 0.1)
	var tw: Tween = create_tween()
	tw.tween_property(self, "_hum", 2.4, secs * 0.9).set_trans(Tween.TRANS_SINE)


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	if heart_light != null:
		heart_light.light_energy = 4.0 * _hum * (0.85 + 0.15 * sin(_t * 6.0 * _hum))
	if crystal != null:
		crystal.rotation.y += delta * 0.1 * _hum
