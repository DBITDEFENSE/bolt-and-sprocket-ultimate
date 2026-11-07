class_name CinemaPerson
extends PatronBody
## T-194: a person in the LAZARUS cutscenes (docs/CUTSCENES_LAZARUS.md §7): the relief squads' way of dressing a
## body (ZombieBody.build_dressed: a human_base body in a kit's clothes, recoloured by a palette, the living skin;
## no Blender work, no insignia), or a people.json person (Selwyn, the squad), driven by PatronBody's pose solver
## (stand, sit, walk by moving the node, cower...). Added here:
##   kneel   on both knees, upright, hands at the sides (the villagers in the road)
##   pray    kneeling, head bowed, the hands together at the chest (Serafim at the bell tower)
##   palm    standing, the right hand raised, palm down (get up, go home)
##   hold    standing or sitting, both hands forward at the waist (the keys, the lantern, the lead case)
## A look (cutscenes_lazarus.json "cast"): base (a ZombieBody kit), build, female, height, tone [sRGB], palette
## {cloth, cloth2, hair, leather, ...: sRGB}, headgear (a ZombieBody.gear_mesh piece) and headgear_color, extras
## (our own small pieces hung on the rig: beard, skufia, peaked_cap, budenovka, ushanka, kerchief, cassock, coat_long,
## armband_red, cape, mask, white_coat), or person (a people.json id). Presentation only: no collider, no hitboxes.

const EXTRAS: PackedStringArray = ["beard", "skufia", "peaked_cap", "budenovka", "ushanka", "kerchief", "cassock", "coat_long",
	"armband_red", "cape", "mask", "white_coat", "leather_cap"]

var look_row: Dictionary = {}
var gear: Array[MeshInstance3D] = []
var hold_lift: float = 0.0   # the hold pose's hands: 0 at the waist, 1 at the chest


## Builds the person from a look (see the class doc) in a pose.
func setup_look(id: String, look: Dictionary, pose_name: String = "stand") -> void:
	look_row = look
	var prims: Dictionary = {"jacket": look.get("prim_jacket", [0.3, 0.27, 0.22]), "trousers": look.get("prim_trousers", [0.22, 0.2, 0.18]),
		"build": float(look.get("width", 1.0))}
	setup({"id": id, "look": prims, "pose": "stand", "person": str(look.get("person", ""))})
	set_pose(StringName(pose_name))
	head_down = float(look.get("head_down", 0.0))


## Forgets the motion so far (after a teleport: the walk cycle does not read the jump as speed).
func reset_motion() -> void:
	_last_pos = global_position if is_inside_tree() else position
	_speed = 0.0


static func _srgb(a: Variant, fallback: Color) -> Color:
	if a is Array and (a as Array).size() >= 3:
		return Color(float(a[0]), float(a[1]), float(a[2])).srgb_to_linear()
	return fallback


func _build_person(person_id: String = "") -> void:
	if look_row.has("base"):
		var palette: Dictionary = {}
		for k: Variant in (look_row.get("palette", {}) as Dictionary).keys():
			palette[str(k)] = _srgb(look_row["palette"][k], Color.GRAY)
		var tone: Color = _srgb(look_row.get("tone", [0.86, 0.72, 0.62]), Color(0.62, 0.5, 0.44))
		var m: ArrayMesh = ZombieBody.build_dressed(str(look_row["base"]), str(look_row.get("build", "medium")), bool(look_row.get("female", false)),
			tone, palette, true)
		var p: PersonRig = PersonRig.new()
		if m == null or not p.setup_mesh(m, float(look_row.get("height", 1.0)), "cin_" + patron_id):
			p.free()
			return
		person = p
		_pivot.add_child(p)
		_head.position = Vector3(0, 0.5, 0)
		for n: Node in _pivot.find_children("*", "MeshInstance3D", true, false):
			if not p.is_ancestor_of(n):
				(n as MeshInstance3D).visible = false
		_dress()
		return
	if person_id != "":
		super._build_person(person_id)
		if person != null:
			_dress()


## The headgear and our own extras on the rig's bones.
func _dress() -> void:
	var female: bool = bool(look_row.get("female", false))
	var hg: String = str(look_row.get("headgear", ""))
	if hg != "":
		var spec: Array = ZombieBody.gear_mesh(hg, female)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Headgear"
		mi.mesh = spec[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if look_row.has("headgear_color"):
			mi.material_override = CinemaSet.flat(_srgb(look_row["headgear_color"], Color.GRAY).linear_to_srgb(), 0.85)
		person.attachment(str(spec[0])).add_child(mi)
		gear.append(mi)
	var pal: Dictionary = look_row.get("palette", {})
	var cloth: Color = Color(_c3(pal.get("cloth", [0.3, 0.28, 0.24])))
	for x: Variant in look_row.get("extras", []):
		_extra(str(x), cloth)


static func _c3(a: Variant) -> Color:
	if a is Array and (a as Array).size() >= 3:
		return Color(float(a[0]), float(a[1]), float(a[2]))
	return Color.GRAY


func _piece(bone: String, mesh: Mesh, pos: Vector3, scl: Vector3, color: Color, rot: Vector3 = Vector3.ZERO, rough: float = 0.9) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.scale = scl
	mi.rotation = rot
	mi.material_override = CinemaSet.flat(color, rough)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	person.attachment(bone).add_child(mi)
	gear.append(mi)
	return mi


func _extra(x: String, cloth: Color) -> void:
	var col: Color = (_c3(look_row.get(x + "_color", [])) if look_row.has(x + "_color") else cloth).darkened(0.3)   # (the kit's own cloth reads darker than a flat colour)
	var sph: SphereMesh = Props.unit_sphere()
	var cy: CylinderMesh = Props.unit_cyl()
	var bx: BoxMesh = Props.unit_box()
	match x:
		"beard":   # a full grey beard to the chest, the moustache over it
			var bc: Color = _c3(look_row.get("beard_color", [0.55, 0.53, 0.5]))
			_piece("Head", sph, Vector3(0, 0.0, -0.075), Vector3(0.15, 0.2, 0.11), bc)
			_piece("Head", sph, Vector3(0, -0.09, -0.07), Vector3(0.12, 0.2, 0.09), bc)
			_piece("Head", sph, Vector3(0, 0.045, -0.105), Vector3(0.09, 0.03, 0.04), bc)
		"skufia":   # the priest's soft black cap
			_piece("Head", cy, Vector3(0, 0.2, 0.0), Vector3(0.235, 0.09, 0.25), col)
			_piece("Head", sph, Vector3(0, 0.245, 0.0), Vector3(0.235, 0.05, 0.25), col)
		"peaked_cap":   # a service cap: the crown, the band (its own colour), the peak; no badge
			var band: Color = _c3(look_row.get("band_color", [0.4, 0.08, 0.1]))
			_piece("Head", cy, Vector3(0, 0.205, 0.0), Vector3(0.255, 0.05, 0.27), band)
			_piece("Head", cy, Vector3(0, 0.25, 0.005), Vector3(0.3, 0.045, 0.31), col, Vector3(0.08, 0, 0))
			_piece("Head", bx, Vector3(0, 0.19, -0.14), Vector3(0.17, 0.012, 0.08), Color(0.08, 0.07, 0.06), Vector3(-0.25, 0, 0), 0.5)
		"budenovka":   # the cloth winter helmet with the point (1930), no star
			_piece("Head", sph, Vector3(0, 0.15, 0.0), Vector3(0.27, 0.26, 0.28), col)
			_piece("Head", cy, Vector3(0, 0.3, 0.0), Vector3(0.05, 0.12, 0.05), col)
			_piece("Head", bx, Vector3(0, 0.06, 0.03), Vector3(0.27, 0.12, 0.24), col)
		"ushanka":   # the fur cap, the flaps tied up
			var fur: Color = _c3(look_row.get("fur_color", [0.3, 0.26, 0.2]))
			_piece("Head", cy, Vector3(0, 0.2, 0.0), Vector3(0.28, 0.12, 0.29), fur)
			_piece("Head", sph, Vector3(0, 0.26, 0.0), Vector3(0.26, 0.06, 0.27), col)
			_piece("Head", bx, Vector3(0, 0.19, -0.135), Vector3(0.22, 0.07, 0.03), fur)
		"leather_cap":   # the brigade head's leather cap
			_piece("Head", cy, Vector3(0, 0.205, 0.0), Vector3(0.255, 0.06, 0.27), col, Vector3.ZERO, 0.55)
			_piece("Head", bx, Vector3(0, 0.185, -0.14), Vector3(0.16, 0.012, 0.07), col, Vector3(-0.2, 0, 0), 0.55)
		"kerchief":   # a headscarf tied under the chin (the villagers' women, the nurse in white)
			_piece("Head", sph, Vector3(0, 0.15, 0.015), Vector3(0.27, 0.27, 0.28), col)
			_piece("Head", bx, Vector3(0, 0.02, 0.1), Vector3(0.12, 0.1, 0.05), col, Vector3(0.4, 0, 0))
		"cassock", "coat_long", "white_coat":   # a long garment from the waist to the ankles
			var len_m: float = 0.86 if x != "white_coat" else 0.62
			var c2: CylinderMesh = CylinderMesh.new()
			c2.top_radius = 0.19
			c2.bottom_radius = 0.27 if x == "cassock" else 0.24
			c2.height = len_m
			c2.radial_segments = 12
			c2.rings = 1
			_piece("Hips", c2, Vector3(0, -len_m * 0.5 + 0.06, 0.0), Vector3(1.0, 1.0, 0.8), col).name = "Skirt"
		"armband_red":   # plain red cloth, no lettering (the 1930 brigade)
			var spec: Array = ZombieBody.gear_mesh("armband", bool(look_row.get("female", false)))
			var mi: MeshInstance3D = MeshInstance3D.new()
			mi.mesh = spec[1]
			mi.material_override = CinemaSet.flat(Color(0.55, 0.06, 0.05), 0.95)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			person.attachment(str(spec[0])).add_child(mi)
			gear.append(mi)
		"cape":   # the plash-palatka rain cape over the shoulders
			var c3: CylinderMesh = CylinderMesh.new()
			c3.top_radius = 0.17
			c3.bottom_radius = 0.42
			c3.height = 0.95
			c3.radial_segments = 12
			c3.rings = 1
			_piece("Chest", c3, Vector3(0, -0.12, 0.01), Vector3(1.0, 1.0, 0.82), col).name = "Cape"
		"mask":   # a rubber mask and its filter (the mill crew)
			_piece("Head", sph, Vector3(0, 0.07, -0.09), Vector3(0.2, 0.2, 0.13), Color(0.12, 0.12, 0.11), Vector3.ZERO, 0.4)
			_piece("Head", cy, Vector3(0, 0.0, -0.17), Vector3(0.08, 0.09, 0.08), Color(0.2, 0.2, 0.19), Vector3(PI * 0.5, 0, 0), 0.4)
			_piece("Head", cy, Vector3(-0.045, 0.12, -0.155), Vector3(0.05, 0.015, 0.05), Color(0.5, 0.55, 0.55), Vector3(PI * 0.5, 0, 0), 0.2)
			_piece("Head", cy, Vector3(0.045, 0.12, -0.155), Vector3(0.05, 0.015, 0.05), Color(0.5, 0.55, 0.55), Vector3(PI * 0.5, 0, 0), 0.2)


# ================================================================== the poses

## The cutscene's poses on top of PatronBody's: the body (stand / sit / kneel) and what the hands do.
##   kneel, pray, kneel_reach (both hands forward and low, at the vessel), palm, hold, sit_hold, writing (a board held
##   at the chest, the right hand on it), plus every PatronBody pose (stand, sit, panic, cower, ...).
const ALIASES: Dictionary = {
	&"kneel": [&"stand", &"kneel", &""], &"pray": [&"stand", &"kneel", &"pray"], &"kneel_reach": [&"stand", &"kneel", &"reach"],
	&"palm": [&"stand", &"", &"palm"], &"hold": [&"stand", &"", &"hold"], &"sit_hold": [&"sit", &"", &"hold"],
	&"writing": [&"stand", &"", &"writing"], &"sit_brace": [&"sit", &"", &"brace"],
}
var cine_pose: StringName = &"stand"
var _body_mode: StringName = &""
var _hands_mode: StringName = &""
var head_down: float = 0.0   # extra bow of the head (radians), e.g. a sleeper, a man reading


func set_pose(p: StringName) -> void:
	cine_pose = p
	if ALIASES.has(p):
		var a: Array = ALIASES[p]
		_body_mode = a[1]
		_hands_mode = a[2]
		super.set_pose(a[0])
	else:
		_body_mode = &""
		_hands_mode = &""
		super.set_pose(p)


func _pose_body(delta: float) -> void:
	super._pose_body(delta)
	if person == null or (_body_mode == &"" and _hands_mode == &"" and head_down == 0.0):
		return
	var legs: Array = _legs_d
	var plant: bool = pose != &"sit"
	if _body_mode == &"kneel":
		_hips.position = Vector3(0, 0.58 + sin(_t * 1.3) * 0.01, 0.06)
		_chest.rotation = Vector3(-0.1 - (0.12 if _hands_mode == &"pray" else 0.0) - (0.25 if _hands_mode == &"reach" else 0.0), 0.0, 0.0)
		_head.rotation = Vector3(-0.42 if _hands_mode == &"pray" else -0.1, 0.0, 0.0)
		legs = [[0.05, -1.62, 0.0], [-0.03, -1.55, 0.0]]
		plant = true
	if head_down != 0.0:
		_head.rotation.x -= head_down
	var hl: Variant = null
	var hr: Variant = null
	match _hands_mode:
		&"pray":
			hl = Vector3(-0.035, 0.34, -0.2)
			hr = Vector3(0.035, 0.34, -0.2)
		&"reach":
			hl = Vector3(-0.1, 0.0, -0.5)
			hr = Vector3(0.1, 0.02, -0.5)
		&"palm":
			hl = Vector3(-0.23, -0.2, -0.02)
			hr = Vector3(0.2, 0.38, -0.42)
		&"hold":
			var y: float = lerpf(0.02, 0.24, hold_lift)
			hl = Vector3(-0.11, y, -0.32)
			hr = Vector3(0.11, y, -0.32)
		&"writing":
			hl = Vector3(-0.08, 0.2, -0.3)
			hr = Vector3(0.06, 0.24 + sin(_t * 5.0) * 0.01, -0.3)
		&"brace":
			hl = Vector3(-0.3, -0.05, -0.15)
			hr = Vector3(0.3, -0.05, -0.15)
		_:
			if _body_mode == &"kneel":
				hl = Vector3(-0.2, -0.12, -0.08)
				hr = Vector3(0.2, -0.12, -0.08)
	var hands: Array = _hand_t.duplicate()
	if hl != null:
		hands = [_hand_world(hl as Vector3), _hand_world(hr as Vector3)]
	person.drive({"hips": _hips.position, "chest": _chest.basis, "head": _head.basis, "legs": legs, "hands": hands,
		"poles": [Vector3(-0.6, -1.0, 0.3), Vector3(0.6, -1.0, 0.3)], "plant": plant})


func _hand_world(chest_local: Vector3) -> Vector3:
	return _pivot.to_local(_chest.global_transform * chest_local)


## Something in a hand (the keys, a lantern, the board): parented to the hand bone.
func in_hand(node: Node3D, right: bool = true, offset: Vector3 = Vector3(0, -0.06, -0.02)) -> void:
	if person == null:
		add_child(node)
		return
	person.attachment("RightHand" if right else "LeftHand").add_child(node)
	node.position = offset
