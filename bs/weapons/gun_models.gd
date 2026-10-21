class_name GunModels
extends RefCounted
## Procedural greybox models for all 16 B&S guns (BS_WEAPONS "Model by level"). build() fills `g` (model space:
## barrel along -Z, origin at the grip) and returns the barrel length used to place the muzzle at z = -0.2 - len.
## Each V-level adds its listed detail (V2..V5); Ω swaps the trim for gold and adds a small gold Ω ring.
## Used by GunVisual (in Bolt's hand) and tools_src/smoke_arsenal (contact sheet). All shapes are primitive meshes.

const GOLD: Color = Color(1.0, 0.8, 0.25)


static func _rot_x(mi: MeshInstance3D) -> MeshInstance3D:
	mi.rotation.x = PI / 2.0
	return mi


static func _torus(g: Node3D, r_in: float, r_out: float, pos: Vector3, mat: Material, axis_z: bool = true) -> MeshInstance3D:
	var t: MeshInstance3D = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = r_in
	tm.outer_radius = r_out
	t.mesh = tm
	t.material_override = mat
	t.position = pos
	if axis_z:
		t.rotation.x = PI / 2.0
	g.add_child(t)
	return t


static func build(g: Node3D, id: StringName, lv: int, om: bool) -> float:
	var col: Color = WeaponData.color(id)
	var trim: Color = GOLD if om else Color(0.3, 0.32, 0.36)
	var body: StandardMaterial3D = BoltVisual._mat(col.darkened(0.15), 0.3)
	var dark: StandardMaterial3D = BoltVisual._mat(trim, 0.7 if om else 0.4)
	var glow: StandardMaterial3D = WeaponFX.glow_mat(col)
	var white: StandardMaterial3D = BoltVisual._mat(Color(0.92, 0.92, 0.88), 0.1)
	var gold: StandardMaterial3D = BoltVisual._mat(GOLD, 0.9)
	var bl: float = 0.4
	match String(id):
		"omni_blaster":
			BoltVisual._box(g, Vector3(0.12, 0.16, 0.34), Vector3(0, 0.02, -0.05), body)
			BoltVisual._box(g, Vector3(0.08, 0.14, 0.08), Vector3(0, -0.1, 0.06), dark)          # grip
			_rot_x(BoltVisual._cyl(g, 0.035, bl, Vector3(0, 0.04, -0.36), dark))
			if lv >= 2:
				for z: float in [-0.25, -0.32, -0.39]:
					BoltVisual._box(g, Vector3(0.14, 0.02, 0.02), Vector3(0, 0.04, z), gold if om else BoltVisual._mat(Color(0.75, 0.45, 0.25), 0.8))
			if lv >= 3:
				BoltVisual._box(g, Vector3(0.06, 0.03, 0.1), Vector3(0, 0.11, -0.02), glow)
			if lv >= 4:
				BoltVisual._box(g, Vector3(0.02, 0.05, 0.08), Vector3(-0.07, 0.05, 0.02), dark)   # second ejection port
			if lv >= 5:
				_rot_x(BoltVisual._cyl(g, 0.05, 0.03, Vector3(0, 0.04, -0.56), WeaponFX.glow_mat(Color("#ff8a2e"))))
		"void_ripper":
			BoltVisual._box(g, Vector3(0.14, 0.14, 0.3), Vector3(0, 0, 0), body)
			BoltVisual._sphere(g, 0.1, Vector3(0, 0.02, -0.25), glow)
			for i: int in (2 if lv >= 2 else 1):
				_torus(g, 0.11, 0.14, Vector3(0, 0.02, -0.2 - i * 0.1), dark)
			if lv >= 3:
				BoltVisual._box(g, Vector3(0.02, 0.02, 0.28), Vector3(0.08, 0.06, -0.05), WeaponFX.glow_mat(Color("#c07dff")))
			if lv >= 4:
				for a: float in [0.0, 2.1, 4.2]:
					BoltVisual._box(g, Vector3(0.05, 0.05, 0.02), Vector3(cos(a) * 0.17, sin(a) * 0.17, -0.12), glow)
			if lv >= 5:
				_torus(g, 0.16, 0.19, Vector3(0, 0.02, -0.42), WeaponFX.glow_mat(Color("#3a0a66")))
			bl = 0.42
		"sprocket_zap":
			# Sprocket does the shooting; Bolt holds the uplink remote
			BoltVisual._box(g, Vector3(0.1, 0.05, 0.18), Vector3(0, 0, -0.02), body)
			BoltVisual._cyl(g, 0.01, 0.16, Vector3(0.03, 0.1, -0.08), dark)
			BoltVisual._sphere(g, 0.025, Vector3(0.03, 0.18, -0.08), glow)
			if lv >= 2:
				_torus(g, 0.012, 0.022, Vector3(0.03, 0.12, -0.08), BoltVisual._mat(Color(0.75, 0.45, 0.25), 0.8), false)
			if lv >= 3:
				for x: float in [-0.03, 0.0]:
					BoltVisual._cyl(g, 0.006, 0.06, Vector3(x, 0.05, -0.08), glow)
			bl = 0.15
		"boom_box":
			BoltVisual._box(g, Vector3(0.3, 0.2, 0.14), Vector3(0, 0.05, -0.1), body)
			for x: float in [-0.08, 0.08]:
				_rot_x(BoltVisual._cyl(g, 0.055, 0.02, Vector3(x, 0.05, -0.18), BoltVisual._mat(Color(0.75, 0.75, 0.8), 0.8) if lv >= 2 else dark))
			BoltVisual._box(g, Vector3(0.24, 0.02, 0.02), Vector3(0, 0.17, -0.1), dark)          # handle
			if lv >= 3:
				BoltVisual._box(g, Vector3(0.3, 0.015, 0.015), Vector3(0, -0.05, -0.18), glow)  # LED strip
			if lv >= 4:
				_rot_x(BoltVisual._cyl(g, 0.03, 0.02, Vector3(0, 0.12, -0.18), dark))
			if lv >= 5:
				BoltVisual._sphere(g, 0.035, Vector3(0, 0.21, -0.1), BoltVisual._mat(Color(0.9, 0.9, 0.95), 1.0))
			bl = 0.2
		"lawn_dart":
			BoltVisual._box(g, Vector3(0.12, 0.14, 0.26), Vector3(0, 0, 0), body)
			_rot_x(BoltVisual._cyl(g, 0.055, 0.42, Vector3(0, 0.05, -0.3), dark))               # launch tube
			BoltVisual._box(g, Vector3(0.08, 0.13, 0.08), Vector3(0, -0.1, 0.06), dark)
			var tip: MeshInstance3D = BoltVisual._cyl(g, 0.03, 0.08, Vector3(0, 0.05, -0.53), glow)
			tip.rotation.x = PI / 2.0
			if lv >= 2:
				for s: float in [-1.0, 1.0]:
					BoltVisual._box(g, Vector3(0.02, 0.08, 0.1), Vector3(s * 0.07, 0.05, -0.12), white)  # striped fins
			if lv >= 3:
				BoltVisual._sphere(g, 0.03, Vector3(0, 0.13, -0.42), BoltVisual._mat(Color("#ff7ab0")))  # flamingo
				BoltVisual._cyl(g, 0.006, 0.06, Vector3(0, 0.1, -0.42), BoltVisual._mat(Color("#ff7ab0")))
			if lv >= 4:
				_rot_x(BoltVisual._cyl(g, 0.04, 0.34, Vector3(0.09, -0.02, -0.26), dark))        # second tube
			if lv >= 5:
				BoltVisual._box(g, Vector3(0.1, 0.06, 0.01), Vector3(0, 0.16, -0.05), BoltVisual._mat(Color("#7dff9a")))  # KEEP OFF sign
			bl = 0.38
		"patent_pending":
			BoltVisual._box(g, Vector3(0.2, 0.2, 0.34), Vector3(0, 0.03, -0.05), body)
			BoltVisual._sphere(g, 0.11, Vector3(0, 0.05, -0.28), glow)
			_rot_x(BoltVisual._cyl(g, 0.07, 0.03, Vector3(0.11, 0.05, 0.0), dark))               # the cooling fan
			BoltVisual._box(g, Vector3(0.06, 0.12, 0.06), Vector3(0, -0.12, 0.08), dark)
			BoltVisual._box(g, Vector3(0.21, 0.04, 0.05), Vector3(0, 0.1, 0.05), BoltVisual._mat(Color("#ffd23e")))  # taped warning
			if lv >= 2:
				BoltVisual._box(g, Vector3(0.21, 0.04, 0.05), Vector3(0, -0.04, -0.12), BoltVisual._mat(Color("#ffd23e")))
			if lv >= 3:
				_rot_x(BoltVisual._cyl(g, 0.06, 0.03, Vector3(-0.11, 0.05, -0.05), dark))       # a second fan
			if lv >= 4:
				_torus(g, 0.13, 0.15, Vector3(0, 0.05, -0.2), glow)
			if lv >= 5:
				BoltVisual._cyl(g, 0.04, 0.05, Vector3(0, 0.17, -0.08), gold if om else dark)  # stamp turret
			if om:
				BoltVisual._box(g, Vector3(0.01, 0.1, 0.14), Vector3(0.105, 0.03, -0.1), gold)  # framed certificate
			bl = 0.3
		"cease_desist":
			BoltVisual._box(g, Vector3(0.14, 0.12, 0.3), Vector3(0, 0.02, -0.05), body)
			BoltVisual._box(g, Vector3(0.12, 0.02, 0.2), Vector3(0, 0.1, -0.1), white)          # paper feed
			BoltVisual._box(g, Vector3(0.07, 0.13, 0.07), Vector3(0, -0.1, 0.06), dark)
			BoltVisual._box(g, Vector3(0.1, 0.04, 0.12), Vector3(0, 0.03, -0.27), dark)        # document slot
			if lv >= 2:
				BoltVisual._box(g, Vector3(0.03, 0.08, 0.03), Vector3(0.09, 0.06, 0.0), dark)  # stamp hammer
			if lv >= 3:
				BoltVisual._box(g, Vector3(0.16, 0.02, 0.06), Vector3(0, 0.12, 0.04), dark)
			if lv >= 4:
				BoltVisual._cyl(g, 0.03, 0.02, Vector3(-0.08, 0.02, -0.15), BoltVisual._mat(Color("#c0392b")))  # wax seal
			if lv >= 5:
				BoltVisual._box(g, Vector3(0.06, 0.025, 0.025), Vector3(0, 0.15, -0.2), BoltVisual._mat(Color("#8b5a2b")))  # gavel
			if om:
				BoltVisual._cyl(g, 0.04, 0.01, Vector3(0.075, 0.02, -0.08), gold)
			bl = 0.12
		"buzzkill":
			BoltVisual._box(g, Vector3(0.12, 0.12, 0.28), Vector3(0, 0, 0), body)
			BoltVisual._cyl(g, 0.16, 0.025, Vector3(0, 0.05, -0.24), BoltVisual._mat(Color("#cfd8e4"), 0.9))  # the blade
			BoltVisual._box(g, Vector3(0.07, 0.13, 0.07), Vector3(0, -0.1, 0.06), dark)
			if lv >= 2:
				_torus(g, 0.16, 0.18, Vector3(0, 0.05, -0.24), dark, false)                      # serrated guard
			if lv >= 3:
				BoltVisual._cyl(g, 0.09, 0.015, Vector3(0, 0.1, -0.02), BoltVisual._mat(Color("#cfd8e4"), 0.9))  # spare blade
			if lv >= 4:
				_rot_x(BoltVisual._cyl(g, 0.07, 0.06, Vector3(0.08, 0.0, 0.0), dark))           # magazine wheel
			if lv >= 5:
				_rot_x(BoltVisual._cyl(g, 0.05, 0.03, Vector3(-0.08, 0.02, -0.1), WeaponFX.glow_mat(Color("#ffe08a"))))
			bl = 0.2
		"grav_grenade":
			BoltVisual._box(g, Vector3(0.12, 0.12, 0.24), Vector3(0, 0, 0), body)
			BoltVisual._sphere(g, 0.09, Vector3(0, 0.05, -0.22), WeaponFX.glow_mat(Color("#1a0833")))
			BoltVisual._box(g, Vector3(0.07, 0.13, 0.07), Vector3(0, -0.1, 0.06), dark)
			if lv >= 2:
				_torus(g, 0.11, 0.125, Vector3(0, 0.05, -0.22), dark, false)                    # gyroscope cage
				_torus(g, 0.11, 0.125, Vector3(0, 0.05, -0.22), dark)
			if lv >= 3:
				for a2: float in [0.5, 2.6, 4.7]:
					BoltVisual._sphere(g, 0.015, Vector3(cos(a2) * 0.16, 0.05 + sin(a2) * 0.16, -0.22), glow)
			if lv >= 4:
				BoltVisual._sphere(g, 0.13, Vector3(0, 0.05, -0.22), WeaponFX.glow_mat(Color("#c07dff"), 0.25))
			if lv >= 5:
				_torus(g, 0.03, 0.08, Vector3(0, 0.05, -0.22), WeaponFX.glow_mat(Color("#ffb44d")), false)
			bl = 0.12
		"middleman":
			BoltVisual._box(g, Vector3(0.18, 0.1, 0.2), Vector3(0, 0, -0.05), body)              # the remote
			BoltVisual._box(g, Vector3(0.22, 0.03, 0.22), Vector3(0, 0.07, -0.05), dark)         # mini rotor deck
			BoltVisual._box(g, Vector3(0.03, 0.08, 0.01), Vector3(0, -0.02, -0.16), BoltVisual._mat(Color("#c0392b")))  # tie
			if lv >= 2:
				BoltVisual._box(g, Vector3(0.04, 0.06, 0.005), Vector3(0.06, -0.02, -0.16), white)  # ID badge
			if lv >= 3:
				BoltVisual._box(g, Vector3(0.08, 0.1, 0.01), Vector3(-0.1, 0.03, -0.1), BoltVisual._mat(Color("#c9a26b")))  # clipboard
			if lv >= 4:
				BoltVisual._box(g, Vector3(0.2, 0.01, 0.03), Vector3(0, 0.1, -0.05), dark)
			if lv >= 5:
				BoltVisual._cyl(g, 0.02, 0.03, Vector3(0.07, 0.1, 0.0), white)                  # the mug
			bl = 0.1
		"frostbyte":
			BoltVisual._box(g, Vector3(0.12, 0.14, 0.3), Vector3(0, 0, -0.03), body)
			BoltVisual._cyl(g, 0.05, 0.2, Vector3(0, 0.12, 0.0), WeaponFX.glow_mat(Color("#cdeeff"), 0.6))  # coolant tank
			_rot_x(BoltVisual._cyl(g, 0.03, 0.3, Vector3(0, 0.03, -0.32), dark))
			BoltVisual._box(g, Vector3(0.07, 0.13, 0.07), Vector3(0, -0.1, 0.06), dark)
			if lv >= 2:
				BoltVisual._cyl(g, 0.055, 0.04, Vector3(0, 0.2, 0.0), white)
			if lv >= 3:
				for z2: float in [-0.25, -0.35, -0.42]:
					var ic: MeshInstance3D = BoltVisual._cyl(g, 0.012, 0.05, Vector3(0, -0.01, z2), WeaponFX.glow_mat(Color("#eaf8ff")))
					ic.rotation.x = PI
			if lv >= 4:
				BoltVisual._cyl(g, 0.04, 0.16, Vector3(0.08, 0.1, 0.0), WeaponFX.glow_mat(Color("#cdeeff"), 0.6))
			if lv >= 5:
				BoltVisual._sphere(g, 0.035, Vector3(0, 0.12, -0.15), WeaponFX.glow_mat(Color("#eaf8ff"), 0.5))  # snow globe
			bl = 0.32
		"root_canal":
			BoltVisual._box(g, Vector3(0.12, 0.12, 0.28), Vector3(0, 0, 0), body)
			_rot_x(BoltVisual._cyl(g, 0.04, 0.26, Vector3(0, 0.03, -0.26), BoltVisual._mat(Color("#3a8a2a"))))
			BoltVisual._box(g, Vector3(0.07, 0.13, 0.07), Vector3(0, -0.1, 0.06), dark)
			BoltVisual._sphere(g, 0.035, Vector3(0, 0.03, -0.4), glow)
			if lv >= 2:
				BoltVisual._cyl(g, 0.06, 0.08, Vector3(0, 0.1, 0.02), BoltVisual._mat(Color("#b5562b")))  # terracotta pot
			if lv >= 3:
				_rot_x(BoltVisual._cyl(g, 0.06, 0.04, Vector3(0, 0.03, -0.42), dark))            # watering-can rose
			if lv >= 4:
				BoltVisual._box(g, Vector3(0.08, 0.08, 0.08), Vector3(-0.08, 0.08, -0.05), BoltVisual._mat(Color("#c9a26b")))
			if lv >= 5:
				BoltVisual._cyl(g, 0.0, 0.06, Vector3(0, 0.15, -0.15), BoltVisual._mat(Color("#c0392b")))  # gnome hat
			if om:
				BoltVisual._cyl(g, 0.03, 0.005, Vector3(0.05, 0.08, -0.3), gold)               # dental mirror
			bl = 0.26
		"late_fee":
			BoltVisual._box(g, Vector3(0.12, 0.14, 0.3), Vector3(0, 0, 0), body)
			_rot_x(BoltVisual._cyl(g, 0.045, 0.42, Vector3(0, 0.05, -0.33), dark))
			BoltVisual._box(g, Vector3(0.1, 0.06, 0.12), Vector3(0, -0.02, -0.28), BoltVisual._mat(Color("#8b5a2b")))  # pump
			BoltVisual._box(g, Vector3(0.07, 0.13, 0.07), Vector3(0, -0.1, 0.08), dark)
			if lv >= 2:
				BoltVisual._box(g, Vector3(0.04, 0.005, 0.01), Vector3(0, 0.075, 0.05), gold)    # coin slot
			if lv >= 3:
				BoltVisual._box(g, Vector3(0.02, 0.05, 0.1), Vector3(0.07, 0.04, -0.02), white)  # interest ticker
			if lv >= 4:
				_rot_x(BoltVisual._cyl(g, 0.04, 0.3, Vector3(0, -0.03, -0.3), BoltVisual._mat(Color("#ff9ab0"))))  # piggy snout
			if lv >= 5:
				BoltVisual._box(g, Vector3(0.11, 0.02, 0.06), Vector3(0, 0.02, -0.28), WeaponFX.glow_mat(Color("#ff3b3b")))  # PAST DUE
			bl = 0.4
		"fine_print":
			BoltVisual._box(g, Vector3(0.1, 0.12, 0.42), Vector3(0, 0, -0.05), body)
			_rot_x(BoltVisual._cyl(g, 0.025, 0.55, Vector3(0, 0.03, -0.5), dark))
			_rot_x(BoltVisual._cyl(g, 0.035, 0.2, Vector3(0, 0.12, -0.08), dark))               # scope
			BoltVisual._box(g, Vector3(0.07, 0.13, 0.07), Vector3(0, -0.1, 0.1), dark)
			if lv >= 2:
				_rot_x(BoltVisual._cyl(g, 0.045, 0.02, Vector3(0, 0.12, -0.19), WeaponFX.glow_mat(Color("#eaf8ff"), 0.6)))  # magnifier
			if lv >= 3:
				BoltVisual._box(g, Vector3(0.005, 0.02, 0.4), Vector3(0.026, 0.03, -0.5), gold if om else WeaponFX.glow_mat(Color("#1a1a1a")))  # microtext
			if lv >= 4:
				_rot_x(BoltVisual._cyl(g, 0.02, 0.06, Vector3(0, -0.04, -0.3), WeaponFX.glow_mat(Color("#ffd23e"))))  # reading lamp
			if lv >= 5:
				BoltVisual._box(g, Vector3(0.01, 0.01, 0.12), Vector3(0.08, 0.05, 0.02), white)  # quill bolt handle
			bl = 0.62
		"hostile_takeover":
			BoltVisual._box(g, Vector3(0.22, 0.16, 0.1), Vector3(0, 0, -0.08), BoltVisual._mat(Color("#3a2a1a")))  # briefcase
			BoltVisual._box(g, Vector3(0.08, 0.03, 0.02), Vector3(0, 0.1, -0.08), gold)       # handle
			_rot_x(BoltVisual._cyl(g, 0.03, 0.2, Vector3(0, 0.0, -0.22), dark))
			BoltVisual._sphere(g, 0.03, Vector3(0, 0, -0.33), glow)
			if lv >= 2:
				BoltVisual._box(g, Vector3(0.23, 0.01, 0.11), Vector3(0, 0.0, -0.08), gold)
			if lv >= 3:
				BoltVisual._box(g, Vector3(0.025, 0.1, 0.01), Vector3(0.06, 0.13, -0.08), gold)  # gold-tie antenna
			if lv >= 4:
				_rot_x(BoltVisual._cyl(g, 0.008, 0.18, Vector3(-0.08, -0.06, -0.2), WeaponFX.glow_mat(Color("#ff3b3b"))))  # pen laser
			if lv >= 5:
				BoltVisual._box(g, Vector3(0.005, 0.03, 0.09), Vector3(0.112, 0.0, -0.08), WeaponFX.glow_mat(Color("#7dff9a")))  # ticker
			bl = 0.15
		"clearance_rack":
			BoltVisual._box(g, Vector3(0.18, 0.16, 0.24), Vector3(0, 0, 0.02), body)
			for k: int in 6:
				var a3: float = TAU * k / 6.0
				_rot_x(BoltVisual._cyl(g, 0.018, 0.42, Vector3(cos(a3) * 0.05, 0.03 + sin(a3) * 0.05, -0.3), dark))
			BoltVisual._box(g, Vector3(0.07, 0.13, 0.07), Vector3(0, -0.12, 0.08), dark)
			if lv >= 2:
				_torus(g, 0.05, 0.065, Vector3(0, -0.1, 0.02), dark)                            # trigger guard
			if lv >= 3:
				BoltVisual._box(g, Vector3(0.12, 0.06, 0.005), Vector3(0, 0.13, -0.05), BoltVisual._mat(Color("#ff3b3b")))  # SALE placard
			if lv >= 4:
				_torus(g, 0.085, 0.1, Vector3(0, 0.03, -0.36), dark)                            # coat-hanger shroud
			if lv >= 5:
				BoltVisual._box(g, Vector3(0.16, 0.025, 0.04), Vector3(0, 0.1, 0.06), WeaponFX.glow_mat(Color("#ffd23e")))  # light bar
			bl = 0.4
		_:
			BoltVisual._box(g, Vector3(0.12, 0.15, 0.32), Vector3(0, 0.02, -0.04), body)
			_rot_x(BoltVisual._cyl(g, 0.04, bl, Vector3(0, 0.04, -0.36), dark))
			BoltVisual._box(g, Vector3(0.05, 0.05, 0.05), Vector3(0, 0.13, -0.05), glow)
	if om:
		_torus(g, 0.035, 0.05, Vector3(0.08, 0.1, 0.02), gold, false)          # the Ω stamp
	return bl
