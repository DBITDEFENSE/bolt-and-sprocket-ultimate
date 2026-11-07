extends CinemaSet
## T-194, GRAVELIGHT ONE set S (§6.4): outside for one shot. The C-47, dark, its props turning slowly, no lights,
## gliding down over a snowfield with the violet column behind it; ahead and below the crossroads, the stable and the
## inn's lit windows, the only lamplight for miles. The shot list suggests Map 0 itself as the stage; it is built here
## small instead (the inn, the stable and the crossroads as night silhouettes with their lit windows: the shot is a
## dark glide 30 m off the wing, and loading the whole map for 8 s would cost more than it shows; logged in T-194).
## The aircraft is ours: a Dakota from the wreck's parts made whole (fuselage, nose, wings, two radials, the tail).
## Markers: Plane, Inn. Effects: glide.

var plane_n: Node3D
var props: Array[Node3D] = []


func _build() -> void:
	env({"sky_top": [0.01, 0.012, 0.03], "sky_horizon": [0.05, 0.05, 0.09], "ground": [0.03, 0.03, 0.04], "ambient": [0.28, 0.3, 0.42], "ambient_e": 0.3,
		"fog": [0.05, 0.05, 0.08], "fog_d": 0.0022, "glow_t": 0.8, "glow_i": 1.0, "bloom": 0.1})
	sun(Vector3(-28, 140, 0), [0.55, 0.6, 0.78], 0.22)
	var snow: StandardMaterial3D = noisy(Color(0.55, 0.57, 0.66), Color(0.76, 0.78, 0.86), 0.03, 8.0, 0.85)
	plane(self, Vector3(0, 0, 0), Vector2(3000, 3000), snow)
	var woods: Array = []
	for i: int in 120:
		var p: Vector3 = Vector3(rng.randf_range(-900, 900), 0, rng.randf_range(-900, 900))
		if p.length() < 140.0:
			continue
		woods.append(xf(p + Vector3(0, 6, 0), Vector3(rng.randf_range(8, 30), rng.randf_range(10, 18), rng.randf_range(8, 30))))
	multi(self, Props.unit_sphere(), woods, flat(Color(0.03, 0.04, 0.04)), "Woods")
	_inn()
	_plane()
	var vm: StandardMaterial3D = glow(Color(0.62, 0.35, 1.0), 3.0)
	cyl(self, Vector3(900, 600, 1400), 60.0, 2400.0, vm, Vector3.ZERO, "VioletColumn")
	glow_dot(self, Vector3(900, 40, 1380), 900.0, Color(0.5, 0.25, 0.9), 0.5)
	precipitation(self, Vector3(-120, 20, 130), Vector3(40, 20, 40), true, 500)


func _inn() -> void:
	var inn: Node3D = group(self, "Inn", Vector3(0, 0, 0), 20.0)
	box(inn, Vector3(0, 4.0, 0), Vector3(16.0, 8.0, 11.0), "plaster")
	_roof(inn, Vector3(0, 8.0, 0), 16.4, 11.6, 4.0)
	var warm: StandardMaterial3D = glow(Color(1.0, 0.72, 0.4), 2.2)
	for row: int in 2:
		for k: int in 5:
			card(inn, Vector3(-6.0 + 3.0 * float(k), 2.0 + 3.2 * float(row), 5.52), Vector2(1.0, 1.3), warm)
			card(inn, Vector3(-6.0 + 3.0 * float(k), 2.0 + 3.2 * float(row), -5.52), Vector2(1.0, 1.3), warm, 180.0)
	omni(inn, Vector3(0, 3.0, 8.0), [1.0, 0.7, 0.4], 3.0, 18.0)
	glow_dot(inn, Vector3(0, 4.0, 6.0), 22.0, Color(1.0, 0.65, 0.35), 0.5)
	marker("Inn", Vector3(0, 4.0, 0))
	var st: Node3D = group(self, "Stable", Vector3(-26, 0, 14), 20.0)
	box(st, Vector3(0, 3.0, 0), Vector3(14.0, 6.0, 9.0), "planks")
	_roof(st, Vector3(0, 6.0, 0), 14.4, 9.6, 3.5)
	card(st, Vector3(3.0, 2.0, 4.55), Vector2(0.8, 0.8), warm)
	var road: StandardMaterial3D = noisy(Color(0.4, 0.41, 0.47), Color(0.5, 0.51, 0.58), 0.2, 4.0, 0.9)
	plane(self, Vector3(0, 0.03, 40), Vector2(7.0, 600), road, Vector3(0, 20, 0))
	plane(self, Vector3(20, 0.03, 25), Vector2(600, 6.0), road, Vector3(0, 20, 0))


func _roof(parent: Node3D, base: Vector3, w: float, d: float, rise: float) -> void:
	var half: float = d * 0.5
	var ang: float = rad_to_deg(atan2(rise, half))
	var sl: float = sqrt(half * half + rise * rise)
	box(parent, base + Vector3(0, rise * 0.5, half * 0.5), Vector3(w, 0.2, sl), "roof", Vector3(ang, 0, 0))
	box(parent, base + Vector3(0, rise * 0.5, -half * 0.5), Vector3(w, 0.2, sl), "roof", Vector3(-ang, 0, 0))


func _plane() -> void:
	plane_n = group(self, "Plane", Vector3(-300, 120, 500))
	var body: Node3D = group(plane_n, "Airframe")
	var olive: StandardMaterial3D = flat(Color(0.12, 0.13, 0.11), 0.6)
	cyl(body, Vector3(0, 0, 0), 1.25, 13.0, olive, Vector3(90, 0, 0))                  # the fuselage, nose to -z
	ball(body, Vector3(0, 0.1, -6.6), Vector3(2.4, 2.4, 3.2), olive)                   # the nose
	cone(body, Vector3(0, 0.35, 8.4), 1.2, 0.35, 4.0, olive, 12, Vector3(-86, 0, 0))   # the tail cone
	box(body, Vector3(0, 0.2, -3.6), Vector3(1.6, 0.5, 1.0), flat(Color(0.1, 0.12, 0.14), 0.2))   # the cockpit glazing, dark
	box(body, Vector3(0, -0.55, -1.5), Vector3(29.0, 0.32, 3.4), olive)                # the wing
	box(body, Vector3(0, 0.6, 9.6), Vector3(9.0, 0.18, 2.2), olive)                    # the tailplane
	box(body, Vector3(0, 2.4, 9.8), Vector3(0.22, 3.6, 2.6), olive, Vector3(-14, 0, 0))   # the fin
	for sx: float in [-5.6, 5.6]:
		cyl(body, Vector3(sx, -0.45, -3.4), 0.75, 3.4, olive, Vector3(90, 0, 0))     # the nacelles
		var pr: Node3D = group(body, "Prop", Vector3(sx, -0.45, -5.25))
		for b: int in 3:
			box(pr, Vector3(0, 0.0, 0), Vector3(0.22, 3.4, 0.06), flat(Color(0.06, 0.06, 0.06), 0.5), Vector3(0, 0, 120.0 * float(b)))
		props.append(pr)


## Shot 8: gliding down toward the field beside the inn, the props windmilling.
func fx_glide(secs: float) -> void:
	plane_n.position = Vector3(-300, 120, 500)
	plane_n.rotation_degrees = Vector3(-8, -29, -3)
	tween_to(plane_n, "position", Vector3(-120, 34, 170), secs * 1.15, Tween.TRANS_LINEAR)


func _process(delta: float) -> void:
	super._process(delta)
	for p: Node3D in props:
		p.rotation.z += delta * 2.2
