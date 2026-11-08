extends CinemaSet
## T-194, LAZARUS SATURDAY sets D-E (§6.1): the stair down from the nave into the undercroft (12 steps along -Z from
## y 0 to -2.4), the low door at its foot with the lamp (a lampada, red glass, a small flame, never out) on its chain
## and the line cut over it in Church Slavonic, then the crypt: a vaulted room 4 x 5 m, a stone step before a bare
## altar slab, and on the step the vessel (dark metal, a grey wax seal over a cord, nothing on it). Its open state:
## dark and wet inside. Gore (§8.6): "full" the inside is red and a drop runs down the lip; "low" red, no drop; "off"
## only dark and wet. The faith is shot the way a church is shot: the lamp and the inscription are lit and still.
## Markers: Lamp, Inscription, Vessel, VesselMouth, Volkov, Serafim. Effects: descend, at_inscription, enter,
## vessel_open, drop_run, stand_up, men_out.

## The bible's wording (docs/LAZARUS.md; the respect review R-02): no "не", this word order.
const INSCRIPTION: String = "Є́же затвори́ся въ де́нь четве́ртый,\nникто́же да отве́рзетъ."

var vessel: Node3D
var lid: Node3D
var seal: Node3D
var drop: Node3D
var volkov: CinemaPerson
var serafim: CinemaPerson
var bearers: Array[CinemaPerson] = []
var guards: Array[CinemaPerson] = []
var lamp_light: OmniLight3D
var volkov_lantern: Node3D
var step_lantern: Node3D


func _build() -> void:
	env({"bg": [0.0, 0.0, 0.0], "ambient": [0.3, 0.22, 0.16], "ambient_e": 0.12, "fog": [0.08, 0.06, 0.05], "fog_d": 0.02, "glow_t": 1.0, "glow_i": 0.8})
	var stone: Variant = "cellar_stone"
	# the stair: treads and the walls down to the landing
	for s: int in 12:
		box(self, Vector3(0, -0.2 * float(s) - 0.1, -0.3 * float(s) - 0.15), Vector3(1.5, 0.2, 0.3), stone)
	for sx: float in [-0.85, 0.85]:
		box(self, Vector3(sx, -1.0, -2.2), Vector3(0.2, 4.4, 5.2), stone)
	box(self, Vector3(0, 0.95, -1.2), Vector3(1.9, 0.2, 3.0), "beam")
	box(self, Vector3(0, -2.5, -4.0), Vector3(1.9, 0.2, 1.2), stone)        # the landing
	box(self, Vector3(0, 0.45, -3.85), Vector3(1.9, 0.2, 1.1), stone)   # the ceiling over the landing (high: the lintel stays clear)
	var stair_l: OmniLight3D = omni(self, Vector3(0, -0.6, -2.2), [1.0, 0.7, 0.42], 0.7, 5.0)   # the lanterns' spill on the steps
	stair_l.set_meta("flicker", 0.7)
	stair_l.add_to_group(&"cinema_flicker")
	# the wall with the low door (1.0 x 1.7)
	var wz: float = -4.5
	box(self, Vector3(-1.05, -1.0, wz), Vector3(1.1, 3.2, 0.4), stone)
	box(self, Vector3(1.05, -1.0, wz), Vector3(1.1, 3.2, 0.4), stone)
	box(self, Vector3(0, -0.15, wz), Vector3(1.0, 1.5, 0.4), stone)
	box(self, Vector3(0, -0.72, wz + 0.21), Vector3(1.3, 0.16, 0.04), "stone")   # the lintel's face
	var bar: Node3D = group(self, "DoorBar", Vector3(0.62, -1.6, wz + 0.25))
	box(bar, Vector3.ZERO, Vector3(0.08, 0.08, 0.08), "iron")
	var ins: Label3D = words(self, INSCRIPTION, Vector3(0, -0.36, wz + 0.23), 0.0022, Color(0.14, 0.11, 0.09), 0.0, "Inscription")
	ins.font_size = 48
	ins.line_spacing = -4.0
	# the lamp on its chain over the door
	var lamp: Node3D = group(self, "Lamp", Vector3(0, -0.98, wz + 0.45))
	cyl(lamp, Vector3(0, 0.5, 0), 0.006, 1.0, "brass")
	cone(lamp, Vector3(0, 0.0, 0), 0.05, 0.075, 0.1, "brass", 12)
	var glass: StandardMaterial3D = glow(Color(0.85, 0.12, 0.08), 1.6)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.85, 0.12, 0.08, 0.85)
	cone(lamp, Vector3(0, 0.09, 0), 0.075, 0.06, 0.08, glass, 12)
	var flame: MeshInstance3D = ball(lamp, Vector3(0, 0.15, 0), Vector3(0.018, 0.04, 0.018), glow(Color(1.0, 0.75, 0.35), 4.0))
	flame.add_to_group(&"cinema_flicker_mesh")
	lamp_light = omni(lamp, Vector3(0, 0.15, 0.05), [1.0, 0.42, 0.22], 1.4, 5.0)
	lamp_light.set_meta("flicker", 1.4)
	lamp_light.add_to_group(&"cinema_flicker")
	marker("VesselMouth", Vector3(0, -2.08, -8.4))
	_room()
	_people()


func _room() -> void:
	var stone: Variant = "cellar_stone"
	var z0: float = -4.7
	var z1: float = -9.7
	box(self, Vector3(0, -2.5, (z0 + z1) * 0.5), Vector3(4.2, 0.2, 5.2), "cellar_floor")
	for sx: float in [-2.1, 2.1]:
		box(self, Vector3(sx, -1.4, (z0 + z1) * 0.5), Vector3(0.3, 2.2, 5.2), stone)
	box(self, Vector3(0, -1.0, z1), Vector3(4.4, 3.4, 0.3), stone)
	# the barrel vault: a half cylinder along the room
	var vault: CylinderMesh = CylinderMesh.new()
	vault.top_radius = 2.15
	vault.bottom_radius = 2.15
	vault.height = 5.2
	vault.radial_segments = 20
	vault.rings = 1
	vault.cap_top = false
	vault.cap_bottom = false
	var vm: MeshInstance3D = MeshInstance3D.new()
	vm.mesh = vault
	var vmat: Material = (mat(stone) as Material).duplicate() if mat(stone) != null else flat(Color(0.3, 0.28, 0.25))
	if vmat is BaseMaterial3D:
		(vmat as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	vm.material_override = vmat
	vm.position = Vector3(0, -0.3, (z0 + z1) * 0.5)
	vm.rotation_degrees = Vector3(90, 0, 0)
	vm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(vm)
	box(self, Vector3(0, -1.9, z1 + 0.5), Vector3(1.5, 1.0, 0.75), "stone")        # the bare altar slab
	box(self, Vector3(0, -2.3, z1 + 1.3), Vector3(2.0, 0.2, 0.65), "stone")        # the step before it
	_vessel(Vector3(0, -2.2, z1 + 1.3))


func _vessel(at: Vector3) -> void:
	vessel = group(self, "Vessel", at)
	var metal: StandardMaterial3D = flat(Color(0.12, 0.1, 0.08), 0.42, 0.0, 0.7)
	cyl(vessel, Vector3(0, 0.14, 0), 0.06, 0.28, metal)
	cone(vessel, Vector3(0, 0.29, 0), 0.062, 0.05, 0.03, metal, 16)
	lid = group(vessel, "VesselLid", Vector3(0, 0.3, 0))
	ball(lid, Vector3(0, 0.02, 0), Vector3(0.13, 0.08, 0.13), metal)
	seal = group(vessel, "VesselSeal", Vector3(0, 0.3, 0))
	cyl(seal, Vector3(0, 0.0, 0.0), 0.068, 0.02, flat(Color(0.45, 0.44, 0.4), 0.7))   # grey wax gone over the lid's join
	for a: int in 4:   # the cord
		box(seal, Vector3(0, -0.06, 0), Vector3(0.134, 0.006, 0.006), flat(Color(0.3, 0.26, 0.2)), Vector3(0, 45.0 * a, 0))
	# the inside, shown when it is opened: dark and wet (gore off), red (low and full), a drop down the lip (full)
	var dark: StandardMaterial3D = flat(Color(0.03, 0.02, 0.02), 0.04)
	dark.metallic_specular = 1.0
	var red: StandardMaterial3D = flat(Color(0.24, 0.015, 0.01), 0.03)
	red.metallic_specular = 1.0
	var inside: Node3D = group(vessel, "VesselInside", Vector3(0, 0.27, 0))
	var d1: MeshInstance3D = cyl(inside, Vector3.ZERO, 0.05, 0.01, dark, Vector3.ZERO, "Dark")
	d1.add_to_group(&"gore_off")
	var r1: MeshInstance3D = cyl(inside, Vector3.ZERO, 0.05, 0.01, red, Vector3.ZERO, "Red")
	r1.add_to_group(&"gore_low")
	drop = group(vessel, "Drop", Vector3(0.058, 0.29, 0.0))
	ball(drop, Vector3.ZERO, Vector3(0.008, 0.014, 0.008), red, "DropBead").add_to_group(&"gore_full")
	inside.visible = false
	drop.visible = false


func _people() -> void:
	volkov = person(self, "volkov", look_of("volkov_1930"), Vector3(0.1, 0.0, 0.5), 0.0, "hold")
	volkov.name = "Volkov"
	volkov.hold_lift = 0.2
	# T-206: Volkov carries his own lantern (the shot list has his lantern come up to the letters); he sets it on the
	# step beside the vessel to open it
	volkov_lantern = PropLibrary.instance("lantern_oil") if PropLibrary.has_key("lantern_oil") else null
	if volkov_lantern == null:
		volkov_lantern = Node3D.new()
		ball(volkov_lantern, Vector3.ZERO, Vector3(0.08, 0.12, 0.08), glow(Color(1.0, 0.75, 0.4), 2.0))
	volkov.in_hand(volkov_lantern, true, Vector3(0, -0.12, -0.02))
	var vl: OmniLight3D = omni(volkov_lantern, Vector3(0, 0.08, 0), [1.0, 0.72, 0.42], 1.5, 6.0)
	vl.set_meta("flicker", 1.5)
	vl.add_to_group(&"cinema_flicker")
	step_lantern = group(self, "StepLantern", Vector3(0.45, -2.2, -8.35))
	var sl: Node3D = PropLibrary.instance("lantern_oil") if PropLibrary.has_key("lantern_oil") else null
	if sl != null:
		step_lantern.add_child(sl)
	else:
		ball(step_lantern, Vector3(0, 0.1, 0), Vector3(0.08, 0.12, 0.08), glow(Color(1.0, 0.75, 0.4), 2.0))
	var sll: OmniLight3D = omni(step_lantern, Vector3(0, 0.2, 0), [1.0, 0.72, 0.42], 1.5, 5.0)
	sll.set_meta("flicker", 1.5)
	sll.add_to_group(&"cinema_flicker")
	step_lantern.visible = false
	for k: int in 2:
		var b: CinemaPerson = person(self, "bearer_%d" % k, look_of(["brigade_a", "brigade_c"][k]), Vector3(-0.3 + 0.6 * float(k), 0.0, -0.2), 0.0, "hold")
		var lan: Node3D = PropLibrary.instance("lantern_oil") if PropLibrary.has_key("lantern_oil") else null
		if lan != null:
			b.in_hand(lan, true, Vector3(0, -0.12, -0.02))
		var l: OmniLight3D = omni(b, Vector3(0.2, 1.0, -0.35), [1.0, 0.72, 0.42], 1.6, 7.0)
		l.set_meta("flicker", 1.6)
		l.add_to_group(&"cinema_flicker")
		bearers.append(b)
	serafim = person(self, "serafim", look_of("serafim"), Vector3(0, -2.4, -4.0), 0.0, "stand")
	serafim.name = "Serafim"
	serafim.visible = false
	for g: int in 2:
		var gp: CinemaPerson = person(self, "guard_%d" % g, look_of(["brigade_b", "brigade_d"][g]), Vector3(-0.55 + 1.1 * float(g), -2.4, -4.2), 0.0, "stand")
		gp.visible = false
		guards.append(gp)


## Shot 18: down the steps behind two lanterns. T-206: the two lanterns stand at the foot of the steps (their old
## 10 cm/s creep read as a slide); Volkov comes down ahead of the lens at a stair's pace (0.4 m/s, a step a tread),
## watching his feet, his lantern low.
func fx_descend(secs: float) -> void:
	for k: int in bearers.size():
		var b: CinemaPerson = bearers[k]
		b.position = Vector3(-0.62 + 1.24 * float(k), -2.4, -3.75 - 0.2 * float(k))
		b.rotation.y = 0.0
		b.reset_motion()
	volkov.position = Vector3(0.6, -0.6, -1.05)
	volkov.rotation.y = 0.0
	volkov.set_pose(&"hold")
	volkov.hold_lift = 0.2
	volkov.head_down = 0.35
	volkov.walk_stride = 0.3
	volkov.reset_motion()
	var tw: Tween = volkov.walk_to(Vector3(0.6, -2.4, -3.6), 2.6 / maxf(1.0, secs * 0.92), 0.3, false)
	if tw != null:
		tw.finished.connect(func() -> void:
			volkov.walk_stride = 0.0
			volkov.look_toward(Vector3(0, -0.36, -4.27)))


## Shot 19: Volkov's lantern up to the letters; Serafim on the stair behind him. T-206: Volkov stands to the lens's
## left with the lantern raised to the stone (the old spot put the back of his head 0.45 m in front of the lens).
func fx_at_inscription(_secs: float) -> void:
	volkov.position = Vector3(-0.55, -2.4, -3.7)
	volkov.rotation.y = 0.0
	volkov.walk_stride = 0.0
	volkov.set_pose(&"raise")
	volkov.reset_motion()
	volkov.look_toward(Vector3(0, -0.36, -4.27))
	for k: int in bearers.size():
		bearers[k].position = Vector3(-1.2 + 2.4 * float(k), -2.4, -3.5)
		bearers[k].rotation.y = 0.0
		bearers[k].reset_motion()
	serafim.visible = true
	serafim.position = Vector3(0.2, -1.6, -2.4)
	serafim.rotation.y = 0.0
	serafim.look_toward(Vector3(0, -0.36, -4.27))
	serafim.reset_motion()


## Shot 20-21: in the crypt: the brigade fill the door; Serafim in the doorway between two of them.
func fx_enter(_secs: float) -> void:
	volkov.position = Vector3(1.25, -2.4, -6.9)
	volkov.rotation.y = 0.0
	volkov.set_pose(&"hold")
	volkov.hold_lift = 0.45
	volkov.look_toward(Vector3(0, -2.0, -8.4))
	volkov.reset_motion()
	for k: int in bearers.size():   # (the left one back by the door, clear of the lens of shot 24 at (-1.25, -5.7))
		bearers[k].position = Vector3(-1.55, -2.4, -5.0) if k == 0 else Vector3(1.3, -2.4, -5.6)
		bearers[k].rotation.y = 0.0
		bearers[k].look_toward(Vector3(0, -2.0, -8.4))
		bearers[k].reset_motion()
	serafim.visible = true
	serafim.position = Vector3(-0.28, -2.4, -4.6)   # in the doorway, by its left jamb (the men pass on his right)
	serafim.rotation.y = 0.0
	serafim.set_pose(&"stand")
	serafim.look_toward(Vector3(1.25, -0.8, -6.9))
	serafim.reset_motion()
	for g: int in guards.size():
		guards[g].visible = true
		guards[g].position = Vector3(-0.85 if g == 0 else 0.78, -2.4, -5.05)
		guards[g].rotation.y = deg_to_rad(-40.0 if g == 0 else 40.0)
		guards[g].look_toward(Vector3(0, -2.0, -8.4))
		guards[g].reset_motion()


## Shot 22: his hands at the step: the knife under the wax, the curl of wax, the cord, the lid. T-206: he kneels
## close enough to reach it, his lantern set on the step beside it; the right hand works at the wax, then follows
## the lid as it comes off.
func fx_vessel_open(secs: float) -> void:
	volkov_lantern.visible = false
	step_lantern.visible = true
	volkov.position = Vector3(0.05, -2.4, -7.92)
	volkov.rotation.y = 0.0
	volkov.set_pose(&"kneel_reach")
	volkov.look_ahead()
	volkov.head_down = 0.5
	volkov.reset_motion()
	lid.position = Vector3(0, 0.3, 0)
	lid.rotation = Vector3.ZERO
	seal.visible = true
	volkov.hand_r = Vector3(0.1, 0.02, -0.5)
	var work: Tween = create_tween().set_loops(3)
	work.tween_property(volkov, "hand_r", Vector3(0.07, -0.02, -0.52), secs * 0.08).set_trans(Tween.TRANS_SINE)
	work.tween_property(volkov, "hand_r", Vector3(0.12, 0.03, -0.49), secs * 0.08).set_trans(Tween.TRANS_SINE)
	tween_to(seal, "position", Vector3(0.09, 0.33, 0.05), secs * 0.3, Tween.TRANS_SINE, Tween.EASE_OUT, secs * 0.25)
	tween_to(seal, "rotation:z", 1.2, secs * 0.3, Tween.TRANS_SINE, Tween.EASE_OUT, secs * 0.25)
	later(secs * 0.62, func() -> void:
		(vessel.get_node("VesselInside") as Node3D).visible = true
		tween_to(lid, "position", Vector3(-0.14, 0.05, 0.06), secs * 0.3, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
		tween_to(lid, "rotation:z", -1.4, secs * 0.3)
		volkov.hand_r = Vector3(0.0, 0.08, -0.5)
		tween_to(volkov, "hand_r", Vector3(-0.24, -0.12, -0.46), secs * 0.3, Tween.TRANS_SINE, Tween.EASE_IN_OUT))   # the lid set down on the step, left of the vessel


## Shot 23: close on the mouth: wet, the light moving on it. Gore full: a drop runs down the lip onto the stone.
func fx_drop_run(secs: float) -> void:
	(vessel.get_node("VesselInside") as Node3D).visible = true
	seal.visible = false
	lid.position = Vector3(-0.14, 0.05, 0.06)
	lid.rotation.z = -1.4
	volkov.hand_l = Vector3(-0.14, -0.2, -0.3)   # his hands drawn back onto his knees: nothing over the mouth the lens is on
	volkov.hand_r = Vector3(0.14, -0.2, -0.3)
	if gore() != "full":
		return
	drop.visible = true
	drop.position = Vector3(0.058, 0.29, 0.0)
	tween_to(drop, "position", Vector3(0.062, 0.02, 0.0), secs * 0.6, Tween.TRANS_QUAD, Tween.EASE_IN, secs * 0.25)


## Shot 24: he stands up too fast in front of the brigade. T-206: the rise is seen (the kneel blends up over about
## 0.4 s on the cut), the hands drop from the vessel; he turns his face to the men on the clever answer.
func fx_stand_up(_secs: float) -> void:
	volkov.position = Vector3(0.1, -2.4, -7.6)
	volkov.rotation.y = PI
	volkov.hand_r = null
	volkov.hand_l = null
	volkov.set_pose(&"kneel_reach")
	volkov.head_down = 0.5
	volkov.reset_motion()   # (the first frame snaps to the kneel; the rise starts a frame later and blends)
	later(0.06, func() -> void:
		volkov.set_pose(&"stand")
		volkov.head_down = 0.0)
	later(0.5, func() -> void: volkov.look_toward(Vector3(-0.28, -0.85, -4.6)))
	for k: int in bearers.size():
		bearers[k].look_toward(Vector3(0.1, -0.8, -7.6))
	for g: int in guards.size():
		guards[g].look_toward(Vector3(0.1, -0.8, -7.6))
	serafim.look_toward(Vector3(0.1, -0.8, -7.6))


## Shot 25: the men move past Serafim in the door, out, with the vessel. T-206: single file through the door on his
## right (a waypoint inside the room first, so nobody walks through a jamb or through him), Volkov last.
func fx_men_out(_secs: float) -> void:
	vessel.visible = false
	step_lantern.visible = false
	serafim.look_ahead()
	var order: Array = [[bearers[1], 0.2], [bearers[0], 1.7], [volkov, 3.0]]
	for e: Array in order:
		var p: CinemaPerson = e[0]
		var delay: float = float(e[1])
		if p == volkov:
			p.set_pose(&"hold")
			p.hold_lift = 0.4
			p.hand_r = null
			volkov_lantern.visible = true
		p.look_ahead()
		var leg1: Tween = p.walk_to(Vector3(0.25, -2.4, -5.15), 1.1, delay)
		if leg1 != null:
			leg1.finished.connect(func() -> void: p.walk_to(Vector3(0.25, -2.4, -3.5), 1.0))


func _process(delta: float) -> void:
	super._process(delta)
	for n: Node in get_tree().get_nodes_in_group(&"cinema_flicker_mesh"):
		if is_ancestor_of(n):
			(n as Node3D).scale = Vector3(0.018, 0.04 + sin(_flick_t * 11.0) * 0.004, 0.018)
