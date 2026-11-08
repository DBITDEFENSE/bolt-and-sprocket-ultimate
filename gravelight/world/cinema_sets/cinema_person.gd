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


## Forgets the motion so far (after a teleport: the walk cycle does not read the jump as speed) and snaps the pose
## blends (a teleport is a cut: the new pose is already held on the first frame).
func reset_motion() -> void:
	_last_pos = global_position if is_inside_tree() else position
	_speed = 0.0
	_snap = true
	for tw: Tween in _moves:   # a walk or a turn still running would drag the teleported body back along its old path
		if is_instance_valid(tw) and tw.is_valid():
			tw.kill()
	_moves.clear()


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
##   at the chest, the right hand on it), raise (the right hand up at eye level: a lantern to the letters), binoculars
##   (both hands at the eyes), plus every PatronBody pose (stand, sit, run, cower, ...).
## T-206 (the polish pass): a pose change blends instead of snapping (the hands glide to their new targets over about
## a third of a second, a kneel folds down and a rise comes up over about 0.4 s, the head turns over about 0.3 s);
## `reset_motion()` snaps everything (a teleport is a cut). The walk is the cutscene's own: when the node moves, the
## legs swing so that the feet cover the ground the body does (the stride grows with the speed, 0.45-0.85 m a step
## walking, longer at a run) instead of the puppet's fixed small swing, so nobody skates. `hand_l` / `hand_r` are
## chest-local hand targets a stage can set or tween over a pose (a hand to a cap, a handset passed, a hand on a
## dial); `head_yaw` / `head_down` turn the head (`look_toward(point)` aims it at a point of the world); `hold_width`
## spreads the hold's hands (arms round a case). `walk_to()` and `turn_to()` move a person at a walking speed, facing
## the way they go.
const ALIASES: Dictionary = {
	&"kneel": [&"stand", &"kneel", &""], &"pray": [&"stand", &"kneel", &"pray"], &"kneel_reach": [&"stand", &"kneel", &"reach"],
	&"palm": [&"stand", &"", &"palm"], &"hold": [&"stand", &"", &"hold"], &"sit_hold": [&"sit", &"", &"hold"],
	&"writing": [&"stand", &"", &"writing"], &"sit_brace": [&"sit", &"", &"brace"], &"raise": [&"stand", &"", &"raise"],
	&"binoculars": [&"stand", &"", &"binoculars"],
}
const HAND_RATE: float = 9.0     # the hands' glide (1/s: about 0.3 s to settle)
const KNEEL_RATE: float = 2.6    # a kneel or a rise (1/s)
const HEAD_RATE: float = 6.0     # a head turn (1/s)
const LEG_M: float = 0.86        # hip to sole, for the stride
const KNEEL_LEGS: Array = [[0.05, -1.62, 0.0], [-0.03, -1.55, 0.0]]

var cine_pose: StringName = &"stand"
var _body_mode: StringName = &""
var _hands_mode: StringName = &""
var head_down: float = 0.0   # extra bow of the head (radians; negative looks up), e.g. a sleeper, a man reading
var head_yaw: float = 0.0    # extra turn of the head (radians; positive looks to the body's left)
var hand_l: Variant = null   # chest-local hand targets over the pose's own (Vector3), or null
var hand_r: Variant = null
var hold_width: float = 0.11
var walk_stride: float = 0.0   # metres a step when walking; 0 = from the speed
var _kneel_k: float = 0.0
var _hl_s: Vector3 = Vector3.ZERO
var _hr_s: Vector3 = Vector3.ZERO
var _head_s: Vector2 = Vector2.ZERO   # (down, yaw) smoothed
var _snap: bool = true
var _cphase: float = 0.0
var _moves: Array[Tween] = []   # the walks and turns running (reset_motion kills them)


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


## Aims the head at a point of the world (the speaker, the vessel, the bell), within what a neck does.
func look_toward(world_point: Vector3, pitch: bool = true) -> void:
	var head_w: Vector3 = global_position + global_basis * Vector3(0, 1.55 * (float(look_row.get("height", 1.0)) if not look_row.is_empty() else 1.0), 0)
	var local: Vector3 = global_basis.inverse() * (world_point - head_w)
	head_yaw = clampf(atan2(-local.x, -local.z), -1.25, 1.25)
	if pitch:
		var flat: float = Vector2(local.x, local.z).length()
		head_down = clampf(-atan2(local.y, maxf(0.05, flat)), -0.6, 0.7)


## The head straight again.
func look_ahead() -> void:
	head_yaw = 0.0
	head_down = 0.0


## The yaw (rotation.y) that faces a direction of the world (local -Z is forward).
static func yaw_to(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


## Turns to face `yaw` the short way round, over `secs`.
func turn_to(yaw: float, secs: float = 0.4, delay: float = 0.0) -> Tween:
	var goal: float = rotation.y + wrapf(yaw - rotation.y, -PI, PI)
	if not is_inside_tree():
		rotation.y = goal
		return null
	var tw: Tween = create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(self, "rotation:y", goal, maxf(0.01, secs)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_moves.append(tw)
	return tw


## Walks to `target` at `mps` metres a second (0.6 a shuffle, 1.0-1.4 a walk, 3 a run), turning to face the way first
## (`face`), after `delay`. The move itself is linear: the stride matches the speed, the puppet eases the first steps.
func walk_to(target: Vector3, mps: float = 1.2, delay: float = 0.0, face: bool = true) -> Tween:
	var d: Vector3 = target - position
	var flat: Vector3 = Vector3(d.x, 0.0, d.z)
	var dur: float = flat.length() / maxf(0.1, mps)
	if not is_inside_tree():
		position = target
		if face and flat.length() > 0.01:
			rotation.y = yaw_to(flat)
		return null
	var tw: Tween = create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	if face and flat.length() > 0.05:
		var goal: float = rotation.y + wrapf(yaw_to(flat) - rotation.y, -PI, PI)
		tw.tween_property(self, "rotation:y", goal, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "position", target, maxf(0.05, dur)).set_trans(Tween.TRANS_LINEAR)
	_moves.append(tw)
	return tw


func _pose_body(delta: float) -> void:
	super._pose_body(delta)
	if person == null:
		return
	var k_dt: float = clampf(delta, 0.0, 0.2)
	var want_k: float = 1.0 if _body_mode == &"kneel" else 0.0
	_kneel_k = want_k if _snap else move_toward(_kneel_k, want_k, k_dt * KNEEL_RATE)
	var legs: Array = _legs_d.duplicate(true)
	var hips: Vector3 = _hips.position
	var plant: bool = pose != &"sit"
	var poles: Array = _poles.duplicate()
	# --- the cutscene's walk: standing and moving, the feet cover the ground the body does
	var walking: bool = pose == &"stand" and _speed > 0.25 and _kneel_k < 0.01
	if walking:
		var stride: float = walk_stride if walk_stride > 0.0 else (clampf(0.3 + 0.4 * _speed, 0.45, 0.85) if _speed < 2.0 else clampf(0.9 + 0.2 * (_speed - 2.0), 0.9, 1.3))
		_cphase += k_dt * PI * _speed / stride
		var amp: float = clampf(stride / (2.0 * LEG_M), 0.0, 0.62)
		for side: int in 2:
			var lph: float = _cphase + (0.0 if side == 0 else PI)
			legs[side] = [sin(lph) * amp, -maxf(0.0, cos(lph)) * amp * 1.4, 0.0]
		_phase = _cphase   # the puppet's own bob and arm pump keep step with these legs
	else:
		_cphase = _phase
	# --- a kneel (or the rise out of one) blends over the standing pose
	if _kneel_k > 0.0:
		var kh: Vector3 = Vector3(0, 0.58 + sin(_t * 1.3) * 0.01, 0.06)
		hips = hips.lerp(kh, _kneel_k)
		var cx: float = -0.1 - (0.12 if _hands_mode == &"pray" else 0.0) - (0.25 if _hands_mode == &"reach" else 0.0)
		_chest.rotation.x = lerpf(_chest.rotation.x, cx, _kneel_k)
		_head.rotation.x = lerpf(_head.rotation.x, -0.42 if _hands_mode == &"pray" else -0.1, _kneel_k)
		for side2: int in 2:
			for c: int in 3:
				legs[side2][c] = lerpf(float(legs[side2][c]), float(KNEEL_LEGS[side2][c]), _kneel_k)
		plant = true
	_hips.position = hips   # (the chest and the hand targets hang from the hips node: it must sit where the rig's hips go)
	# --- the head: a bow and a turn, smoothed (the chest follows a little)
	_head_s = Vector2(head_down, head_yaw) if _snap else _head_s.lerp(Vector2(head_down, head_yaw), 1.0 - exp(-k_dt * HEAD_RATE))
	_head.rotation.x -= _head_s.x
	_head.rotation.y += _head_s.y
	_chest.rotation.y += _head_s.y * 0.2
	# --- the hands: the pose's targets (chest-local), the stage's overrides over them, the puppet's own under them
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
			hl = Vector3(-hold_width, y, -0.32)
			hr = Vector3(hold_width, y, -0.32)
		&"writing":
			hl = Vector3(-0.08, 0.2, -0.3)
			hr = Vector3(0.06, 0.24 + sin(_t * 5.0) * 0.01, -0.3)
		&"brace":
			hl = Vector3(-0.3, -0.05, -0.15)
			hr = Vector3(0.3, -0.05, -0.15)
		&"raise":
			hl = Vector3(-0.23, -0.2, -0.02)
			hr = Vector3(0.14, 0.68, -0.28)
		&"binoculars":
			hl = Vector3(-0.07, 0.46, -0.22)
			hr = Vector3(0.07, 0.46, -0.22)
		_:
			if _kneel_k > 0.0:
				hl = Vector3(-0.2, -0.12, -0.08)
				hr = Vector3(0.2, -0.12, -0.08)
	if hand_l != null:
		hl = hand_l
	if hand_r != null:
		hr = hand_r
	var want_l: Vector3 = _hand_world(hl as Vector3) if hl != null else (_hand_t[0] as Vector3)
	var want_r: Vector3 = _hand_world(hr as Vector3) if hr != null else (_hand_t[1] as Vector3)
	if _kneel_k > 0.0 and _kneel_k < 1.0 and hl == null:
		want_l = want_l.lerp(_hand_world(Vector3(-0.2, -0.12, -0.08)), _kneel_k)
		want_r = want_r.lerp(_hand_world(Vector3(0.2, -0.12, -0.08)), _kneel_k)
	if _snap:
		_hl_s = want_l
		_hr_s = want_r
	else:
		var a: float = 1.0 - exp(-k_dt * HAND_RATE)
		_hl_s = _hl_s.lerp(want_l, a)
		_hr_s = _hr_s.lerp(want_r, a)
	_snap = false
	person.drive({"hips": hips, "chest": _chest.basis, "head": _head.basis, "legs": legs, "hands": [_hl_s, _hr_s],
		"poles": poles, "plant": plant})


func _hand_world(chest_local: Vector3) -> Vector3:
	return _pivot.to_local(_chest.global_transform * chest_local)


## Something in a hand (the keys, a lantern, the board): parented to the hand bone.
func in_hand(node: Node3D, right: bool = true, offset: Vector3 = Vector3(0, -0.06, -0.02)) -> void:
	if person == null:
		add_child(node)
		return
	person.attachment("RightHand" if right else "LeftHand").add_child(node)
	node.position = offset
