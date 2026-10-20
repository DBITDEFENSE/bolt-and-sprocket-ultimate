class_name RemoteBody
extends Node3D
## A teammate seen in third person (co-op, M7). Original, procedural: a simple articulated soldier in the
## survivor's colours (CHARACTERS.md outfits: Dutch's Ranger olive and M1 helmet, Peg's battledress and
## beret, Deacon's tanker jacket and knit cap, Wren's snow smock and armband), holding the weapon they
## currently hold (WeaponModels) in both hands, aimed with the replicated pitch.
## Poses: walk/run cycle from speed, crouch, sprint (gun low), last-stand crawl (prone, pistol forward),
## hidden while bled out. Shots: muzzle flash + light, 3D gunfire, a tracer. Local -Z is forward.

const UPPER: float = 0.3
const FORE: float = 0.28
const THIGH: float = 0.44
const SHIN: float = 0.44

## character -> [jacket, trousers, headgear, skin, accent, headgear kind]
const OUTFITS: Dictionary = {
	&"dutch": [Color(0.33, 0.33, 0.21), Color(0.42, 0.37, 0.27), Color(0.28, 0.3, 0.19), Color(0.84, 0.66, 0.53), Color(0.55, 0.48, 0.3), "helmet"],
	&"peg": [Color(0.45, 0.38, 0.25), Color(0.4, 0.34, 0.23), Color(0.45, 0.12, 0.13), Color(0.92, 0.76, 0.66), Color(0.55, 0.36, 0.22), "beret"],
	&"deacon": [Color(0.3, 0.27, 0.2), Color(0.25, 0.27, 0.2), Color(0.16, 0.16, 0.17), Color(0.36, 0.24, 0.17), Color(0.5, 0.42, 0.3), "knit"],
	&"wren": [Color(0.86, 0.86, 0.82), Color(0.33, 0.3, 0.27), Color(0.4, 0.38, 0.36), Color(0.9, 0.75, 0.65), Color(0.85, 0.1, 0.12), "knit"],
}

var pid: int = 0
var character: StringName = &"dutch"
var _pivot: Node3D
var _hips: Node3D
var _chest: Node3D
var _head: Node3D
var _gun_pivot: Node3D
var _gun: Node3D = null
var _muzzle: Node3D = null
var _flash: MeshInstance3D
var _flash_light: OmniLight3D
var _flash_t: float = 0.0
var _limbs: Dictionary = {}       # name -> MeshInstance3D (unit cylinders placed between two points)
var _joints: Dictionary = {}      # name -> MeshInstance3D (hands, feet)
var _tag: Label3D
var _phase: float = 0.0
var _weapon_id: StringName = &""
var _recoil: float = 0.0
var _melee_t: float = 0.0
var _throw_t: float = 0.0
var _step_t: float = 0.0
var _mats: Dictionary = {}
var _down_b: float = 0.0
var _crouch_b: float = 0.0
var _sprint_b: float = 0.0
static var _fire_keys: Dictionary = {}


func setup(character_id: StringName, player_id: int) -> void:
	character = character_id if OUTFITS.has(character_id) else &"dutch"
	pid = player_id
	var o: Array = OUTFITS[character]
	_mats = {
		"jacket": _mat(o[0]), "trousers": _mat(o[1]), "head": _mat(o[2]), "skin": _mat(o[3]),
		"accent": _mat(o[4]), "boot": _mat(Color(0.12, 0.09, 0.07)), "strap": _mat(Color(0.3, 0.26, 0.17)),
		"glove": _mat(Color(0.22, 0.17, 0.12)),
	}
	_build(str(o[5]))
	set_weapon(&"m1911")


static func _mat(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: String) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mats[mat]
	mi.position = pos
	parent.add_child(mi)
	return mi


func _sphere(parent: Node3D, r: float, pos: Vector3, mat: String, squash: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = _mats[mat]
	mi.position = pos
	mi.scale = squash
	parent.add_child(mi)
	return mi


func _limb(limb_name: String, r: float, mat: String) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r * 0.88
	cm.height = 1.0
	cm.radial_segments = 8
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = _mats[mat]
	_pivot.add_child(mi)
	_limbs[limb_name] = mi


func _build(headgear: String) -> void:
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	_hips = Node3D.new()
	_hips.position = Vector3(0, 0.95, 0)
	_pivot.add_child(_hips)
	_box(_hips, Vector3(0.36, 0.2, 0.22), Vector3(0, 0.02, 0), "trousers")
	_box(_hips, Vector3(0.38, 0.06, 0.24), Vector3(0, 0.11, 0), "strap")              # belt
	_chest = Node3D.new()
	_chest.position = Vector3(0, 0.12, 0)
	_hips.add_child(_chest)
	_box(_chest, Vector3(0.42, 0.5, 0.24), Vector3(0, 0.27, 0), "jacket")
	_box(_chest, Vector3(0.44, 0.08, 0.26), Vector3(0, 0.5, 0), "jacket")              # collar / shoulders
	_box(_chest, Vector3(0.05, 0.5, 0.26), Vector3(0.11, 0.27, 0), "strap")            # webbing
	_box(_chest, Vector3(0.05, 0.5, 0.26), Vector3(-0.11, 0.27, 0), "strap")
	_box(_chest, Vector3(0.3, 0.32, 0.14), Vector3(0, 0.3, 0.18), "strap")             # pack
	_box(_chest, Vector3(0.1, 0.07, 0.02), Vector3(-0.2, 0.36, -0.125), "accent")      # armband / patch
	_head = Node3D.new()
	_head.position = Vector3(0, 0.6, 0)
	_chest.add_child(_head)
	_sphere(_head, 0.06, Vector3(0, 0.02, 0), "skin", Vector3(1, 1.4, 1))              # neck
	_sphere(_head, 0.11, Vector3(0, 0.14, -0.01), "skin", Vector3(0.95, 1.1, 1.0))
	match headgear:
		"helmet":
			_sphere(_head, 0.15, Vector3(0, 0.2, 0), "head", Vector3(1.0, 0.62, 1.05))
			_box(_head, Vector3(0.26, 0.01, 0.02), Vector3(0, 0.11, -0.08), "strap")
		"beret":
			_sphere(_head, 0.125, Vector3(0.03, 0.25, 0.0), "head", Vector3(1.05, 0.32, 1.0))
		_:
			_sphere(_head, 0.12, Vector3(0, 0.22, 0.0), "head", Vector3(1.0, 0.7, 1.0))
	_gun_pivot = Node3D.new()
	_gun_pivot.name = "GunPivot"
	_gun_pivot.position = Vector3(0.0, 0.43, -0.05)
	_chest.add_child(_gun_pivot)
	for side: String in ["l", "r"]:
		_limb("upper_" + side, 0.055, "jacket")
		_limb("fore_" + side, 0.048, "jacket")
		_limb("thigh_" + side, 0.075, "trousers")
		_limb("shin_" + side, 0.062, "trousers")
		_joints["hand_" + side] = _sphere(_pivot, 0.045, Vector3.ZERO, "glove")
		var boot: MeshInstance3D = _box(_pivot, Vector3(0.11, 0.09, 0.26), Vector3.ZERO, "boot")
		_joints["foot_" + side] = boot
	_flash = MeshInstance3D.new()
	_flash.mesh = WeaponModels.muzzle_flash_mesh()
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.scale = Vector3.ONE * 2.2
	_flash.hide()
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.75, 0.4)
	_flash_light.omni_range = 6.0
	_flash_light.light_energy = 0.0
	_flash_light.shadow_enabled = false
	add_child(_flash_light)
	_tag = Label3D.new()
	_tag.text = Net.display_name(pid)
	_tag.modulate = Net.player_color(pid)
	_tag.outline_size = 8
	_tag.font_size = 40
	_tag.pixel_size = 0.004
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.fixed_size = false
	_tag.position = Vector3(0, 2.15, 0)
	add_child(_tag)
	for n: Node in find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = n as MeshInstance3D
		if m != _flash:
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if m.get_parent() == _chest else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The weapon in their hands (from the replicated inventory). &"" = empty hands.
func set_weapon(weapon_id: StringName) -> void:
	if weapon_id == _weapon_id and _gun != null:
		return
	_weapon_id = weapon_id
	if _gun != null and is_instance_valid(_gun):
		if _flash.get_parent() != null:
			_flash.get_parent().remove_child(_flash)
		_gun.queue_free()
	_gun = null
	_muzzle = null
	if weapon_id == &"":
		return
	var base: StringName = StringName(String(weapon_id).trim_suffix("_up"))
	_gun = WeaponModels.build(base, String(weapon_id).ends_with("_up"))
	_gun_pivot.add_child(_gun)
	_gun.position = Vector3(0.12, -0.02, -0.28)
	for n: Node in _gun.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for n2: Node in _gun.find_children("*", "OmniLight3D", true, false):
		(n2 as OmniLight3D).omni_range = 0.6
	_muzzle = _gun.get_node_or_null("Muzzle") as Node3D
	if _muzzle != null:
		_muzzle.add_child(_flash)


## kind: 0 bullet, 1 projectile, 2 stream, 3 melee, 4 throw.
func fire(kind: int, weapon_id: StringName, origin: Vector3, end: Vector3) -> void:
	if not visible:
		return
	match kind:
		3:
			_melee_t = 0.35
			AudioDirector.play_3d("knife_swing", global_position + Vector3.UP * 1.3, -4.0)
			return
		4:
			_throw_t = 0.4
			AudioDirector.play_3d("grenade_pin", global_position + Vector3.UP * 1.3, -6.0)
			return
	if weapon_id != &"" and weapon_id != _weapon_id:
		set_weapon(weapon_id)
	var mz: Vector3 = _muzzle.global_position if _muzzle != null else global_position + Vector3.UP * 1.4
	_recoil = 1.0
	_flash_t = 0.05
	_flash.show()
	_flash.rotation.z = randf() * TAU
	_flash_light.global_position = mz
	_flash_light.light_energy = 2.4
	AudioDirector.play_3d(fire_key(weapon_id, kind), mz, 0.0, 0.08)
	if kind == 0 and origin.distance_squared_to(end) > 1.0:
		Effects.tracer(mz, end)


## Same choice the shooter's WeaponHolder makes: the weapon's own recording, else its class sound.
static func fire_key(weapon_id: StringName, kind: int) -> String:
	var base: StringName = StringName(String(weapon_id).trim_suffix("_up"))
	var k: Variant = _fire_keys.get(base)
	if k == null:
		var own: String = "fire_" + String(base)
		var row: Dictionary = (GLData.table("weapons")["weapons"] as Dictionary).get(String(base), {})
		var fallback: String = "gun_launcher" if row.has("projectile") or kind == 1 else str(WeaponHolder.SOUND.get(StringName(str(row.get("class", "rifle"))), "gun_rifle"))
		k = own if AudioDirector.has_sound(own) else fallback
		_fire_keys[base] = k
	return str(k)


## Called every physics frame by the puppet with its replicated state.
func update_pose(delta: float, speed: float, pitch: float, flags: int) -> void:
	var spectate: bool = (flags & NetMatch.PF_SPECTATE) != 0
	visible = not spectate
	if spectate:
		return
	var downed: bool = (flags & NetMatch.PF_DOWNED) != 0
	var crouch: bool = (flags & NetMatch.PF_CROUCH) != 0 and not downed
	var sprint: bool = (flags & NetMatch.PF_SPRINT) != 0 and not downed
	_down_b = move_toward(_down_b, 1.0 if downed else 0.0, delta * 3.0)
	_crouch_b = move_toward(_crouch_b, 1.0 if crouch else 0.0, delta * 6.0)
	_sprint_b = move_toward(_sprint_b, 1.0 if sprint else 0.0, delta * 5.0)
	_recoil = move_toward(_recoil, 0.0, delta * 9.0)
	_melee_t = maxf(0.0, _melee_t - delta)
	_throw_t = maxf(0.0, _throw_t - delta)
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_flash.hide()
			_flash_light.light_energy = 0.0
	var moving: bool = speed > 0.3
	var stride: float = 0.75 if not sprint else 1.05
	if moving:
		_phase += delta * PI * speed / stride
	var p: float = _phase
	var swing: float = (0.55 + 0.25 * _sprint_b) * clampf(speed / 3.0, 0.0, 1.0) if moving else 0.0
	# --- body
	_pivot.rotation.x = lerpf(0.0, -1.47, _down_b)
	_tag.position.y = lerpf(2.15, 1.0, _down_b)
	_pivot.position = Vector3(0, lerpf(0.0, 0.08, _down_b), lerpf(0.0, 0.7, _down_b))
	_hips.position.y = 0.95 - 0.32 * _crouch_b - (absf(sin(p)) * 0.03 if moving else 0.0)
	_chest.rotation.x = -0.12 * _crouch_b - 0.18 * _sprint_b + lerpf(0.0, 0.62, _down_b)
	_chest.rotation.y = sin(p) * 0.08 * swing
	var aim: float = clampf(pitch, -1.2, 1.2)
	_head.rotation.x = lerpf(aim * 0.6, 0.6, _down_b) - _chest.rotation.x * 0.4
	_gun_pivot.rotation.x = lerpf(aim, -0.75, _sprint_b) - _chest.rotation.x + _recoil * 0.12
	if _down_b > 0.5:
		_gun_pivot.rotation.x = aim + 1.15 - _chest.rotation.x
	_gun_pivot.rotation.z = 0.0
	if _melee_t > 0.0:
		_gun_pivot.rotation.y = sin(_melee_t / 0.35 * PI) * 0.8
	else:
		_gun_pivot.rotation.y = 0.0
	# --- legs (hip -> knee -> ankle in pivot space)
	for side: int in [0, 1]:
		var s: String = "l" if side == 0 else "r"
		var sx: float = -0.1 if side == 0 else 0.1
		var ph: float = p + (0.0 if side == 0 else PI)
		var hip: Vector3 = _pivot.to_local(_hips.global_position) + Vector3(sx, -0.06, 0)
		var thigh_a: float = sin(ph) * swing + 1.0 * _crouch_b
		var knee_a: float = -maxf(0.0, cos(ph)) * swing * 1.4 - 2.0 * _crouch_b
		if _down_b > 0.5:
			thigh_a = sin(ph) * 0.25 * clampf(speed, 0.0, 1.0)
			knee_a = -0.4 - maxf(0.0, cos(ph)) * 0.6 * clampf(speed, 0.0, 1.0)
		var knee: Vector3 = hip + Vector3(0, -cos(thigh_a) * THIGH, -sin(thigh_a) * THIGH)
		var shin_dir: float = thigh_a + knee_a
		var ankle: Vector3 = knee + Vector3(0, -cos(shin_dir) * SHIN, -sin(shin_dir) * SHIN)
		_place(_limbs["thigh_" + s] as MeshInstance3D, hip, knee)
		_place(_limbs["shin_" + s] as MeshInstance3D, knee, ankle)
		var foot: MeshInstance3D = _joints["foot_" + s]
		foot.position = ankle + Vector3(0, -0.02, -0.06)
		foot.rotation = Vector3(0, 0, 0)
	# --- arms: both hands on the gun (right on the grip, left on the support point)
	var grip: Vector3 = _gun_pivot.global_transform * Vector3(0.12, -0.05, -0.24)
	var support: Vector3 = _gun_pivot.global_transform * Vector3(0.1, -0.03, -0.5)
	if _gun != null:
		var lh: Node3D = _gun.get_node_or_null("LeftHand") as Node3D
		if lh != null:
			support = lh.global_position
		grip = _gun.global_position
	if _throw_t > 0.0:
		var k: float = sin(_throw_t / 0.4 * PI)
		support = _chest.global_transform * Vector3(-0.25, 0.55 + 0.3 * k, -0.2 - 0.3 * k)
	for side2: int in [0, 1]:
		var s2: String = "l" if side2 == 0 else "r"
		var sh: Vector3 = _pivot.to_local(_chest.global_transform * Vector3(-0.24 if side2 == 0 else 0.24, 0.5, 0))
		var hand: Vector3 = _pivot.to_local(support if side2 == 0 else grip)
		var elbow: Vector3 = WeaponHolder._solve_elbow(sh, hand, UPPER, FORE, Vector3(-0.6 if side2 == 0 else 0.6, -1.0, 0.3))
		_place(_limbs["upper_" + s2] as MeshInstance3D, sh, elbow)
		_place(_limbs["fore_" + s2] as MeshInstance3D, elbow, hand)
		(_joints["hand_" + s2] as MeshInstance3D).position = hand
	# footsteps for nearby teammates
	if moving and _down_b < 0.5:
		_step_t -= delta * speed / stride
		if _step_t <= 0.0:
			_step_t = 1.0
			var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
			if cam != null and cam.global_position.distance_squared_to(global_position) < 400.0:
				AudioDirector.play_3d("footstep_stone", global_position, -10.0, 0.1)


## Places a unit cylinder (height 1 along +Y) between two points in pivot space.
static func _place(m: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var v: Vector3 = b - a
	var seg_len: float = maxf(0.01, v.length())
	var y: Vector3 = v / seg_len
	var x: Vector3 = y.cross(Vector3.FORWARD)
	if x.length_squared() < 0.001:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z: Vector3 = x.cross(y).normalized()
	m.transform = Transform3D(Basis(x, y * seg_len, z), (a + b) * 0.5)
