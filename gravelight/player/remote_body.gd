class_name RemoteBody
extends Node3D
## A teammate seen in third person (co-op, M7; AI teammates, T-031). Original, procedural: an articulated soldier
## in the survivor's outfit, holding the weapon they currently hold (WeaponModels) in both hands, aimed with the
## replicated pitch. Local -Z is forward.
##
## Silhouettes (U02 section 5, T-050; CHARACTERS.md): Dutch's netted M1 helmet, broad build, BAR belt and the BAR
## man's low, wide stance; Peg's tilted beret, satchel charges on a cross strap and her wristwatch; Deacon's
## grease-stained mechanic's coveralls, knit cap and the wrench on his belt; Wren's white snow smock, wool scarf,
## AK armband, the notebook at her belt and her scoped rifle slung across her back.
## Poses: walk/run cycle from speed, crouch, sprint (gun low), last-stand crawl (prone, pistol forward), hidden
## while bled out; reload (the gun tips, the support hand fetches a magazine); actions: drink (a perk), buy (a
## wall gun, ammo, a door), repair (a plank to the window), revive (kneeling, both hands on the downed teammate);
## idle fidgets while calm (Wren writes in her notebook, Deacon taps the nearest machine, Dutch stretches his
## back, Peg checks her watch). Bots drive the actions from their brain (hold_action / play_action, `calm`);
## for co-op teammates they come from the replicated events (perk_bought, weapon_acquired, ammo_bought,
## board_repaired, the reviver state) and the flags, so remote players animate the same way.
## Shots: muzzle flash + light, 3D gunfire, a tracer. Bots wear a BotPlates nameplate instead of the 3D name tag.
## T-092 (UPDATE_05 section 4): the survivor is drawn as their modelled body (PersonRig: the person's GLB on the
## ZombieRig skeleton, people.json) driven by this puppet's pose every frame, with a FaceDriver (blink, the
## expression by state: downed = pain, low health = fear, shooting = determined; lip flap on their VO lines). The
## primitive boxes stay built (hidden) as the fallback when a person has no GLB and for `-- --legacy-people`.

const UPPER: float = 0.3
const FORE: float = 0.28
const THIGH: float = 0.44
const SHIN: float = 0.44

## character -> [jacket, trousers, headgear, skin, accent, headgear kind] (kept for tools that read it)
const OUTFITS: Dictionary = {
	&"dutch": [Color(0.33, 0.33, 0.21), Color(0.42, 0.37, 0.27), Color(0.28, 0.3, 0.19), Color(0.84, 0.66, 0.53), Color(0.55, 0.48, 0.3), "helmet"],
	&"peg": [Color(0.45, 0.38, 0.25), Color(0.4, 0.34, 0.23), Color(0.45, 0.12, 0.13), Color(0.92, 0.76, 0.66), Color(0.55, 0.36, 0.22), "beret"],
	&"deacon": [Color(0.24, 0.27, 0.24), Color(0.24, 0.27, 0.24), Color(0.13, 0.13, 0.14), Color(0.36, 0.24, 0.17), Color(0.5, 0.42, 0.3), "knit"],
	&"wren": [Color(0.86, 0.86, 0.82), Color(0.33, 0.3, 0.27), Color(0.4, 0.38, 0.36), Color(0.9, 0.75, 0.65), Color(0.85, 0.1, 0.12), "knit"],
	# Jakub Ostrowski (U02 section 6.2): a field-grey army greatcoat two sizes too big over brown work clothes,
	# a tweed cloth cap, the miner's lamp hook on his belt
	&"jakub": [Color(0.36, 0.38, 0.32), Color(0.33, 0.26, 0.19), Color(0.23, 0.21, 0.19), Color(0.78, 0.65, 0.56), Color(0.52, 0.4, 0.22), "cap"],
}
## character -> build: chest width scale, stance half-width, gun drop (BAR posture), lean, fidget kind
const BUILDS: Dictionary = {
	&"dutch": {"width": 1.12, "stance": 0.135, "gun_drop": 0.06, "lean": -0.05, "fidget": "stretch"},
	&"peg": {"width": 0.92, "stance": 0.095, "gun_drop": 0.0, "lean": 0.0, "fidget": "watch"},
	&"deacon": {"width": 1.04, "stance": 0.11, "gun_drop": 0.02, "lean": 0.03, "fidget": "tap"},
	&"wren": {"width": 0.88, "stance": 0.09, "gun_drop": 0.0, "lean": 0.04, "fidget": "write"},
	&"jakub": {"width": 0.86, "stance": 0.1, "gun_drop": 0.03, "lean": 0.07, "fidget": "warm"},
}
## Timed actions (seconds).
const ACTION_SECONDS: Dictionary = {&"drink": 1.7, &"buy": 0.9, &"repair": 0.75, &"revive": 0.5}

var pid: int = 0
var character: StringName = &"dutch"
## Set by the owner each frame: nothing to shoot, nowhere to go (idle fidgets may play). Remote co-op players:
## the body decides from speed and recent shots.
var calm: bool = false
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
var _props: Dictionary = {}       # name -> Node3D (bottle, notebook, pencil, plank, watch)
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
var _build: Dictionary = {}
# actions and fidgets
var _act: StringName = &""        # the timed action playing
var _act_t: float = 0.0           # its time left
var _act_len: float = 1.0
var _hold: Dictionary = {}        # held action -> seconds left before it lets go
var _blend: Dictionary = {}       # pose name -> 0..1
var _reload_b: float = 0.0
var _ads_b: float = 0.0     # aimed down the sights (PF_ADS): stock in the shoulder, cheek on the stock
var _reload_ph: float = 0.0
var _still_t: float = 0.0         # seconds standing still and calm
var _fidget_t: float = 0.0        # seconds into the current fidget (< 0: waiting)
var _since_shot: float = 99.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
static var _fire_keys: Dictionary = {}
## T-092: the modelled body (null: the primitives are drawn) and the pose handed to it each frame.
var person: PersonRig = null
var _legs_d: Array = [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
var _hand_t: Array = [null, null]
var _poles: Array = [Vector3(-0.6, -1.0, 0.3), Vector3(0.6, -1.0, 0.3)]
## T-099: how the held gun sits (set_weapon, hold_of): "long" (the butt in the shoulder) or "pistol" (two hands, arms
## out), the hold point and sight height in the gun's frame, the support grip's axis and radius, the firing grip.
var _gun_hold: Dictionary = {}
var _hand_b: Array = [null, null]   # the hands' bases on the gun (pivot space) for PersonRig; null = follow the forearm
var _hand_w: Array = [0.0, 0.0]     # how much each hand is on the gun (the actions take them off)
var _blade: float = 0.0             # T-099: the body turned side-on behind a long gun (radians, left shoulder forward)


func setup(character_id: StringName, player_id: int) -> void:
	character = character_id if OUTFITS.has(character_id) else &"dutch"
	pid = player_id
	_rng.seed = hash(String(character)) + player_id
	_build = BUILDS.get(character, BUILDS[&"dutch"])
	var o: Array = OUTFITS[character]
	_mats = {
		"jacket": _mat(o[0]), "trousers": _mat(o[1]), "head": _mat(o[2]), "skin": _mat(o[3]),
		"accent": _mat(o[4]), "boot": _mat(Color(0.12, 0.09, 0.07)), "strap": _mat(Color(0.3, 0.26, 0.17)),
		"glove": _mat(Color(0.22, 0.17, 0.12)), "metal": _mat(Color(0.32, 0.33, 0.34), 0.45, 0.7),
		"canvas": _mat(Color(0.38, 0.35, 0.24)), "white": _mat(Color(0.93, 0.92, 0.88)), "glass": _mat(Color(0.25, 0.15, 0.08), 0.3),
		"paper": _mat(Color(0.85, 0.8, 0.66)), "wood": _mat(Color(0.48, 0.34, 0.2)), "scarf": _mat(Color(0.42, 0.16, 0.14)),
		"grease": _mat(Color(0.12, 0.11, 0.1)), "net": _mat(Color(0.2, 0.22, 0.14)),
		"stubble": _mat(Color(0.3, 0.27, 0.25)), "shirt": _mat(Color(0.42, 0.37, 0.3)), "bandage": _mat(Color(0.86, 0.83, 0.76)),
	}
	_build_body(str(o[5]))
	_build_person()
	set_weapon(&"m1911")
	if _ai():
		_tag.visible = false   # bots (and Jakub) wear the screen-space nameplate (BotPlates)
	GLBus.perk_bought.connect(func(p: int, _perk: StringName) -> void:
		if p == pid:
			play_action(&"drink"))
	GLBus.weapon_acquired.connect(func(p: int, _w: StringName, source: StringName) -> void:
		if p == pid and source == &"wall":
			play_action(&"buy"))
	GLBus.ammo_bought.connect(func(p: int, _w: StringName) -> void:
		if p == pid:
			play_action(&"buy"))
	GLBus.board_repaired.connect(func(_win: StringName, p: int) -> void:
		if p == pid:
			play_action(&"repair"))


static func _mat(c: Color, rough: float = 0.9, metal: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: String, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mats[mat]
	mi.position = pos
	mi.rotation = rot
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


func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, mat: String, rot: Vector3 = Vector3.ZERO, r_bottom: float = -1.0) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r if r_bottom < 0.0 else r_bottom
	cm.height = h
	cm.radial_segments = 10
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = _mats[mat]
	mi.position = pos
	mi.rotation = rot
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


func _build_body(headgear: String) -> void:
	var wd: float = float(_build.get("width", 1.0))
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	_hips = Node3D.new()
	_hips.position = Vector3(0, 0.95, 0)
	_pivot.add_child(_hips)
	_box(_hips, Vector3(0.36 * wd, 0.2, 0.22), Vector3(0, 0.02, 0), "trousers")
	_box(_hips, Vector3(0.38 * wd, 0.06, 0.24), Vector3(0, 0.11, 0), "strap")              # belt
	_chest = Node3D.new()
	_chest.position = Vector3(0, 0.12, 0)
	_hips.add_child(_chest)
	_box(_chest, Vector3(0.42 * wd, 0.5, 0.24), Vector3(0, 0.27, 0), "jacket")
	_box(_chest, Vector3(0.44 * wd, 0.08, 0.26), Vector3(0, 0.5, 0), "jacket")              # collar / shoulders
	_head = Node3D.new()
	_head.position = Vector3(0, 0.6, 0)
	_chest.add_child(_head)
	_sphere(_head, 0.06, Vector3(0, 0.02, 0), "skin", Vector3(1, 1.4, 1))              # neck
	_sphere(_head, 0.11, Vector3(0, 0.14, -0.01), "skin", Vector3(0.95, 1.1, 1.0))
	_sphere(_head, 0.018, Vector3(0.0, 0.13, -0.115), "skin")                          # nose
	match headgear:
		"cap":
			# a flat cloth cap: the crown pulled forward over a short peak
			_sphere(_head, 0.122, Vector3(0, 0.235, -0.012), "head", Vector3(1.06, 0.34, 1.12))
			_box(_head, Vector3(0.17, 0.016, 0.085), Vector3(0, 0.215, -0.135), "head", Vector3(-0.18, 0, 0))
		"helmet":
			_sphere(_head, 0.15, Vector3(0, 0.2, 0), "head", Vector3(1.0, 0.62, 1.05))
			_cyl(_head, 0.165, 0.012, Vector3(0, 0.165, 0), "head")                         # brim
			_box(_head, Vector3(0.26, 0.01, 0.02), Vector3(0, 0.11, -0.08), "strap")
		"beret":
			var beret: MeshInstance3D = _sphere(_head, 0.125, Vector3(0.035, 0.25, 0.0), "head", Vector3(1.08, 0.3, 1.02))
			beret.rotation.z = -0.32   # pulled down over the right ear
			_box(_head, Vector3(0.03, 0.03, 0.01), Vector3(-0.07, 0.25, -0.1), "metal")   # cap badge
		_:
			_sphere(_head, 0.12, Vector3(0, 0.22, 0.0), "head", Vector3(1.0, 0.7, 1.0))
			_cyl(_head, 0.118, 0.04, Vector3(0, 0.185, 0.0), "head")                         # turned-up rim
	_gun_pivot = Node3D.new()
	_gun_pivot.name = "GunPivot"
	_gun_pivot.position = Vector3(0.0, 0.43 - float(_build.get("gun_drop", 0.0)), -0.05)
	_chest.add_child(_gun_pivot)
	for side: String in ["l", "r"]:
		_limb("upper_" + side, 0.055 * wd, "jacket")
		_limb("fore_" + side, 0.048 * wd, "jacket")
		_limb("thigh_" + side, 0.075, "trousers")
		_limb("shin_" + side, 0.062, "trousers")
		_joints["hand_" + side] = _sphere(_pivot, 0.045, Vector3.ZERO, "skin" if character == &"deacon" else "glove")
		var boot: MeshInstance3D = _box(_pivot, Vector3(0.11, 0.09, 0.26), Vector3.ZERO, "boot")
		_joints["foot_" + side] = boot
	match character:
		&"dutch": _gear_dutch(wd)
		&"peg": _gear_peg(wd)
		&"deacon": _gear_deacon(wd)
		&"wren": _gear_wren(wd)
		&"jakub": _gear_jakub(wd)
	_build_props()
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


## T-092: the modelled body in place of the primitives (when the person has a GLB). The props, the held gun, Wren's
## slung rifle and Jakub's bandage stay (the bandage moves onto the head bone); the hand spheres keep carrying the
## props but draw nothing; the head node drops to the rig's head pivot so head-relative targets (the drink) meet the
## modelled mouth.
func _build_person() -> void:
	var p: PersonRig = PersonRig.new()
	if not p.setup(String(character)):
		p.free()
		return
	person = p
	_pivot.add_child(p)
	_head.position = Vector3(0, 0.5, 0)
	p.body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var keep: Array[Node] = [_gun_pivot, p]
	for k: String in _props.keys():
		keep.append(_props[k] as Node)
	var sling: Node = _chest.get_node_or_null("SlungRifle")
	if sling != null:
		keep.append(sling)
	var band: Node3D = find_child("Bandage", true, false) as Node3D
	if band != null:
		var vis: bool = band.visible
		band.get_parent().remove_child(band)
		p.attachment("Head").add_child(band)
		band.position = Vector3(0, -0.035, 0.0)
		band.scale = Vector3(0.82, 1.0, 0.86)
		band.visible = vis
		keep.append(band)
	for n: Node in _pivot.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		var kept: bool = false
		for k2: Node in keep:
			if k2 == mi or k2.is_ancestor_of(mi):
				kept = true
				break
		if kept:
			continue
		if mi == _joints.get("hand_l") or mi == _joints.get("hand_r"):
			mi.mesh = null   # still carries the props
		else:
			mi.visible = false


## Dutch: the BAR man. Netting over the helmet, a BAR belt of magazine pouches, a canteen, a pack, the diamond
## Ranger patch on the shoulder.
func _gear_dutch(wd: float) -> void:
	for i: int in 5:
		var a: float = -0.9 + 0.45 * float(i)
		_box(_head, Vector3(0.012, 0.008, 0.3), Vector3(0, 0.27, 0), "net", Vector3(0, a, 0))   # helmet netting
	for k: int in 6:
		var x: float = (-0.15 + 0.06 * float(k)) * wd
		_box(_hips, Vector3(0.055, 0.075, 0.05), Vector3(x, 0.08, -0.135), "canvas")             # BAR belt pouches
	_cyl(_hips, 0.045, 0.14, Vector3(0.2 * wd, 0.02, 0.06), "canvas")                         # canteen
	_box(_chest, Vector3(0.05, 0.5, 0.26), Vector3(0.11, 0.27, 0), "strap")                   # webbing
	_box(_chest, Vector3(0.05, 0.5, 0.26), Vector3(-0.11, 0.27, 0), "strap")
	_box(_chest, Vector3(0.32, 0.34, 0.15), Vector3(0, 0.3, 0.18), "canvas")                  # pack
	_box(_chest, Vector3(0.06, 0.06, 0.02), Vector3(-0.22 * wd, 0.42, -0.1), "accent", Vector3(0, 0, PI * 0.25))   # diamond patch


## Peg: SOE in battledress. The beret, a cross strap with two satchel charges at her left hip (canvas, a fuse
## cord), a holster at the right, her wristwatch.
func _gear_peg(wd: float) -> void:
	_box(_chest, Vector3(0.04, 0.62, 0.02), Vector3(0.0, 0.27, -0.13), "strap", Vector3(0, 0, 0.62))   # cross strap
	_box(_chest, Vector3(0.04, 0.62, 0.02), Vector3(0.0, 0.27, 0.13), "strap", Vector3(0, 0, -0.62))
	for k: int in 2:
		_box(_hips, Vector3(0.12, 0.13, 0.09), Vector3(-0.22 * wd - 0.02, -0.04 + 0.14 * float(k), -0.02 + 0.06 * float(k)), "canvas")   # satchel charges
	_box(_hips, Vector3(0.01, 0.12, 0.01), Vector3(-0.27 * wd, 0.12, -0.05), "accent", Vector3(0.4, 0, 0.3))   # fuse cord
	_box(_hips, Vector3(0.06, 0.12, 0.08), Vector3(0.2 * wd, -0.02, 0.02), "strap")             # holster
	_box(_chest, Vector3(0.28, 0.3, 0.12), Vector3(0, 0.3, 0.17), "canvas")                    # small pack
	_box(_chest, Vector3(0.1, 0.05, 0.02), Vector3(-0.2 * wd, 0.4, -0.125), "accent")           # rank slip


## Deacon: a tank mechanic in coveralls (one colour top to bottom, grease stains, an open collar), the knit cap,
## the big adjustable wrench hanging off his belt, a rag in his back pocket.
func _gear_deacon(wd: float) -> void:
	_box(_chest, Vector3(0.02, 0.44, 0.005), Vector3(0, 0.25, -0.123), "strap")               # zip line
	_box(_chest, Vector3(0.12, 0.08, 0.005), Vector3(0.07, 0.15, -0.123), "grease", Vector3(0, 0, 0.4))   # grease stains
	_box(_hips, Vector3(0.1, 0.12, 0.005), Vector3(-0.09, -0.02, -0.113), "grease")
	_box(_chest, Vector3(0.14, 0.12, 0.012), Vector3(-0.1 * wd, 0.36, -0.127), "jacket")       # chest pocket
	var wrench: Node3D = Node3D.new()
	wrench.position = Vector3(0.21 * wd, 0.02, -0.04)
	wrench.rotation = Vector3(0.0, 0.0, 0.12)
	_hips.add_child(wrench)
	_box(wrench, Vector3(0.03, 0.3, 0.014), Vector3(0, -0.1, 0), "metal")                     # the wrench's handle
	_box(wrench, Vector3(0.075, 0.05, 0.016), Vector3(0, -0.27, 0), "metal")                   # its jaw
	_box(wrench, Vector3(0.025, 0.035, 0.018), Vector3(0.018, -0.3, 0), "metal")
	_box(_hips, Vector3(0.07, 0.12, 0.02), Vector3(-0.1, -0.05, 0.12), "scarf")               # rag in the back pocket
	_box(_hips, Vector3(0.1, 0.09, 0.07), Vector3(-0.2 * wd, 0.0, 0.0), "canvas")             # tool pouch


## Wren: a white snow smock, a wool scarf with a hanging tail, the red-and-white AK armband, the notebook tied to
## her belt, and the scoped Springfield slung across her back (she carries it everywhere).
func _gear_wren(wd: float) -> void:
	_cyl(_chest, 0.105, 0.08, Vector3(0, 0.52, 0.0), "scarf", Vector3.ZERO, 0.12)            # scarf round the neck
	_box(_chest, Vector3(0.07, 0.26, 0.02), Vector3(-0.07, 0.38, -0.13), "scarf", Vector3(0.1, 0, 0.12))   # its tail
	_box(_chest, Vector3(0.1, 0.035, 0.02), Vector3(-0.2 * wd, 0.4, -0.125), "white")          # armband: white
	_box(_chest, Vector3(0.1, 0.035, 0.02), Vector3(-0.2 * wd, 0.365, -0.125), "accent")       # and red
	_box(_hips, Vector3(0.08, 0.11, 0.025), Vector3(-0.2 * wd, -0.02, -0.08), "grease")         # the stained notebook
	_box(_hips, Vector3(0.005, 0.11, 0.03), Vector3(-0.2 * wd, -0.02, -0.1), "paper")
	_box(_chest, Vector3(0.38 * wd, 0.06, 0.04), Vector3(0, 0.08, -0.12), "jacket")             # smock drawstring hem
	var sling: Node3D = Node3D.new()
	sling.name = "SlungRifle"
	sling.position = Vector3(-0.04, 0.34, 0.165)
	_chest.add_child(sling)
	sling.basis = Basis.looking_at(Vector3(-0.55, 0.83, 0.0), Vector3.BACK)   # barrel up over the left shoulder
	var rifle: Node3D = WeaponModels.build(&"springfield")
	sling.add_child(rifle)
	rifle.position = Vector3(0, 0, 0.38)
	for n: Node in rifle.find_children("*", "OmniLight3D", true, false):
		(n as Node3D).queue_free()
	_box(_chest, Vector3(0.03, 0.62, 0.015), Vector3(0.02, 0.3, -0.125), "strap", Vector3(0, 0, -0.85))   # the sling across the chest


## Jakub: gaunt in a greatcoat two sizes too big. The skirt hangs open to the knees over his work shirt, the
## shoulders sit wide of his own, the collar is turned up; two rows of buttons; stubble on hollow cheeks; the
## empty miner's lamp hook clipped to his belt; a bandage round his head when he comes back wounded.
func _gear_jakub(wd: float) -> void:
	_box(_chest, Vector3(0.5 * wd, 0.1, 0.29), Vector3(0, 0.49, 0), "jacket")                    # wide, slumped shoulders
	_box(_chest, Vector3(0.3, 0.1, 0.05), Vector3(0, 0.55, 0.1), "jacket", Vector3(0.3, 0, 0))     # turned-up collar
	_box(_chest, Vector3(0.14, 0.4, 0.01), Vector3(0, 0.26, -0.124), "shirt")                     # the work shirt in the gap
	for side: float in [-1.0, 1.0]:
		for k: int in 3:
			_box(_chest, Vector3(0.018, 0.018, 0.01), Vector3(side * 0.1, 0.4 - 0.11 * float(k), -0.126), "metal")   # buttons
		var skirt: MeshInstance3D = _box(_hips, Vector3(0.22 * wd, 0.52, 0.03), Vector3(side * 0.12 * wd, -0.25, -0.12), "jacket")
		skirt.rotation = Vector3(-0.08, side * 0.18, side * 0.05)                                  # front panels, open
		_box(_hips, Vector3(0.03, 0.52, 0.24), Vector3(side * 0.22 * wd, -0.25, 0.0), "jacket", Vector3(0, 0, side * 0.06))
	_box(_hips, Vector3(0.44 * wd, 0.54, 0.03), Vector3(0, -0.26, 0.125), "jacket", Vector3(0.06, 0, 0))   # back of the coat
	_box(_head, Vector3(0.15, 0.07, 0.04), Vector3(0, 0.075, -0.085), "stubble")                 # stubble
	_box(_head, Vector3(0.025, 0.06, 0.1), Vector3(-0.1, 0.1, -0.03), "stubble")
	_box(_head, Vector3(0.025, 0.06, 0.1), Vector3(0.1, 0.1, -0.03), "stubble")
	var hook: Node3D = Node3D.new()
	hook.name = "LampHook"
	hook.position = Vector3(0.21 * wd, 0.06, -0.08)
	_hips.add_child(hook)
	_box(hook, Vector3(0.012, 0.1, 0.012), Vector3(0, -0.05, 0), "metal")                        # the lamp hook
	_box(hook, Vector3(0.04, 0.012, 0.012), Vector3(0.014, -0.1, 0), "metal")
	_box(hook, Vector3(0.012, 0.03, 0.012), Vector3(0.03, -0.088, 0), "metal")
	var band: Node3D = Node3D.new()
	band.name = "Bandage"
	_head.add_child(band)
	_cyl(band, 0.118, 0.045, Vector3(0, 0.18, 0), "bandage")
	_box(band, Vector3(0.05, 0.04, 0.02), Vector3(0.06, 0.18, -0.11), "grease")                 # dried blood
	band.visible = false


## Jakub back on the next map after a bleed-out: the bandage round his head (U02 section 6.2).
func set_wounded(on: bool) -> void:
	var band: Node3D = find_child("Bandage", true, false) as Node3D
	if band != null:
		band.visible = on


## An AI-driven body (bots, the companion): screen-space nameplate, calm from the brain.
func _ai() -> bool:
	return GameState.is_bot(pid) or character == &"jakub"


## Jakub's coal shovel in both hands (his melee while he has no gun): a long wooden shaft with a D-grip, the
## iron blade low and forward. Built like a gun model (origin at the right hand, "LeftHand" on the shaft).
static func build_shovel(mats: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "CoalShovel"
	var shaft: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.016
	cm.bottom_radius = 0.018
	cm.height = 1.0
	shaft.mesh = cm
	shaft.material_override = mats["wood"]
	shaft.rotation.x = -PI * 0.5
	shaft.position = Vector3(0, 0, -0.3)
	root.add_child(shaft)
	var grip: MeshInstance3D = MeshInstance3D.new()
	var gb: BoxMesh = BoxMesh.new()
	gb.size = Vector3(0.1, 0.02, 0.03)
	grip.mesh = gb
	grip.material_override = mats["wood"]
	grip.position = Vector3(0, 0, 0.2)
	root.add_child(grip)
	var blade: MeshInstance3D = MeshInstance3D.new()
	var bb: BoxMesh = BoxMesh.new()
	bb.size = Vector3(0.24, 0.02, 0.28)
	blade.mesh = bb
	blade.material_override = mats["metal"]
	blade.position = Vector3(0, -0.02, -0.92)
	blade.rotation.x = 0.18
	root.add_child(blade)
	var lh: Node3D = Node3D.new()
	lh.name = "LeftHand"
	lh.position = Vector3(0, 0, -0.42)
	root.add_child(lh)
	return root


## Hand-held props for actions and fidgets (hidden until used).
func _build_props() -> void:
	var rh: Node3D = _joints["hand_r"]
	var lh: Node3D = _joints["hand_l"]
	var bottle: Node3D = Node3D.new()
	rh.add_child(bottle)
	_cyl(bottle, 0.032, 0.15, Vector3(0, 0.06, 0), "glass")
	_cyl(bottle, 0.012, 0.05, Vector3(0, 0.155, 0), "glass")
	_cyl(bottle, 0.034, 0.05, Vector3(0, 0.05, 0), "paper")   # label
	_props["bottle"] = bottle
	var book: Node3D = Node3D.new()
	lh.add_child(book)
	_box(book, Vector3(0.11, 0.015, 0.15), Vector3(0, 0.02, -0.03), "grease")
	_box(book, Vector3(0.105, 0.02, 0.145), Vector3(0, 0.035, -0.03), "paper")
	_props["notebook"] = book
	var pencil: Node3D = Node3D.new()
	rh.add_child(pencil)
	_box(pencil, Vector3(0.008, 0.008, 0.11), Vector3(0, 0.0, -0.05), "wood", Vector3(0.6, 0, 0))
	_props["pencil"] = pencil
	var plank: Node3D = Node3D.new()
	_pivot.add_child(plank)
	_box(plank, Vector3(0.7, 0.12, 0.03), Vector3.ZERO, "wood")
	_props["plank"] = plank
	var tap: Node3D = Node3D.new()   # Deacon's wrench in hand while he taps a machine
	rh.add_child(tap)
	_box(tap, Vector3(0.025, 0.24, 0.014), Vector3(0, 0.1, 0), "metal")
	_box(tap, Vector3(0.06, 0.045, 0.016), Vector3(0, 0.23, 0), "metal")
	_props["wrench"] = tap
	if character == &"peg":
		var watch: Node3D = Node3D.new()
		lh.add_child(watch)
		_box(watch, Vector3(0.05, 0.02, 0.04), Vector3(0, 0.035, 0.03), "strap")
		_cyl(watch, 0.016, 0.012, Vector3(0, 0.048, 0.03), "white")
		_props["watch"] = watch
	for k: String in _props.keys():
		if k != "watch":
			(_props[k] as Node3D).visible = false


## The weapon in their hands (from the replicated inventory). &"" = empty hands.
func set_weapon(weapon_id: StringName) -> void:
	var look: Dictionary = _owner_look(weapon_id)
	if weapon_id == _weapon_id and _gun != null and str(look.get("sig", "")) == _look_sig:
		return
	_weapon_id = weapon_id
	_look_sig = str(look.get("sig", ""))
	if _gun != null and is_instance_valid(_gun):
		if _flash.get_parent() != null:
			_flash.get_parent().remove_child(_flash)
		_gun.queue_free()
	_gun = null
	_muzzle = null
	if weapon_id == &"":
		return
	if weapon_id == &"coal_shovel":
		_gun = build_shovel(_mats)
		_gun_pivot.add_child(_gun)
		_gun.position = Vector3(0.12, -0.02, -0.18)
		_gun.add_child(_flash)   # never shown (melee only), but kept in the tree with the model
		for n0: Node in _gun.find_children("*", "MeshInstance3D", true, false):
			(n0 as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_gun_hold = hold_of(_gun, &"coal_shovel")
		return
	var base: StringName = StringName(String(weapon_id).trim_suffix("_up"))
	_gun = WeaponModels.build(base, String(weapon_id).ends_with("_up"), &"", look)
	_gun_pivot.add_child(_gun)
	_gun.position = Vector3(0.12, -0.02, -0.28)
	for n: Node in _gun.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for n2: Node in _gun.find_children("*", "OmniLight3D", true, false):
		(n2 as OmniLight3D).omni_range = 0.6
	_muzzle = _gun.get_node_or_null("Muzzle") as Node3D
	if _muzzle != null:
		_muzzle.add_child(_flash)
	_gun_hold = hold_of(_gun, base)


var _look_sig: String = ""


## The attachments on the gun in the owner's hands (their WeaponHolder, a mirror for bots and remote players),
## when it is this weapon: {} otherwise (UPDATE_04 section 6).
func _owner_look(weapon_id: StringName) -> Dictionary:
	var p: Player = get_parent() as Player
	if p == null or p.weapons == null:
		return {}
	var w: WeaponInstance = p.weapons.current()
	return WeaponKitModels.look_of(w) if w != null and w.id == weapon_id else {}


## Rebuilds the held gun after its attachments changed (the Armorer's Bench).
func refresh_weapon() -> void:
	var id: StringName = _weapon_id
	_weapon_id = &""
	set_weapon(id)


## kind: 0 bullet, 1 projectile, 2 stream, 3 melee, 4 throw.
func fire(kind: int, weapon_id: StringName, origin: Vector3, end: Vector3) -> void:
	if not visible:
		return
	_since_shot = 0.0
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
	var p: Player = get_parent() as Player
	var cw: WeaponInstance = p.weapons.current() if p != null and p.weapons != null else null
	var key: String = fire_key(weapon_id, kind)
	if cw != null and cw.id == weapon_id and cw.is_suppressed():
		var sk: String = WeaponKit.suppressed_sound(cw)
		if sk != "":
			key = sk
		_flash_light.light_energy = 0.3
		_flash.scale = Vector3.ONE * 0.6
	else:
		_flash.scale = Vector3.ONE * 2.2
	AudioDirector.play_3d(key, mz, 0.0, 0.08)
	if kind == 0 and origin.distance_squared_to(end) > 1.0:
		var wd: Dictionary = GLData.table("weapons")["weapons"].get(String(weapon_id).trim_suffix("_up"), {})
		Effects.tracer(mz, end, String(weapon_id).ends_with("_up"), StringName(str(wd.get("class", ""))))


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


## A one-shot action: &"drink" (a perk), &"buy" (a wall gun, ammo, a door), &"repair" (one board).
func play_action(kind: StringName) -> void:
	_act = kind
	_act_len = float(ACTION_SECONDS.get(kind, 1.0))
	_act_t = _act_len
	_fidget_t = -_rng.randf_range(4.0, 8.0)


## A continuous action, called every frame while it lasts: &"revive", &"repair", &"buy" (a hold-to-use).
func hold_action(kind: StringName) -> void:
	_hold[kind] = 0.25
	_fidget_t = -_rng.randf_range(4.0, 8.0)


## The pose that wins right now: downed > revive > repair > drink > buy > fidget > none.
func _active_pose(downed: bool, moving: bool) -> StringName:
	if downed:
		return &""
	for k: StringName in [&"revive", &"repair"]:
		if float(_hold.get(k, 0.0)) > 0.0 or (_act == k and _act_t > 0.0):
			return k
	if _act == &"drink" and _act_t > 0.0:
		return &"drink"
	if float(_hold.get(&"buy", 0.0)) > 0.0 or (_act == &"buy" and _act_t > 0.0):
		return &"buy"
	if not moving and _fidget_t > 0.0:
		return StringName(str(_build.get("fidget", "")))
	return &""


## Called every physics frame by the puppet with its replicated state.
func update_pose(delta: float, speed: float, pitch: float, flags: int) -> void:
	var spectate: bool = (flags & NetMatch.PF_SPECTATE) != 0
	visible = not spectate
	if spectate:
		return
	var downed: bool = (flags & NetMatch.PF_DOWNED) != 0
	var crouch: bool = (flags & NetMatch.PF_CROUCH) != 0 and not downed
	var sprint: bool = (flags & NetMatch.PF_SPRINT) != 0 and not downed
	var reloading: bool = (flags & NetMatch.PF_RELOAD) != 0 and not downed
	var ads_on: bool = (flags & NetMatch.PF_ADS) != 0 and not downed and not sprint and not reloading
	var moving: bool = speed > 0.3
	_since_shot += delta
	_act_t = maxf(0.0, _act_t - delta)
	for k: Variant in _hold.keys():
		_hold[k] = maxf(0.0, float(_hold[k]) - delta)
	_co_op_revive_hint()
	# idle fidgets: calm (or, for a remote human, still and not shooting) for a while
	var calm_now: bool = (calm if _ai() else _since_shot > 5.0) and not moving and not downed and not reloading
	if calm_now:
		_still_t += delta
		if _still_t > 2.5:
			_fidget_t += delta
			if _fidget_t > 4.2:
				_fidget_t = -_rng.randf_range(5.0, 10.0)   # a pause, then the next one
	else:
		_still_t = 0.0
		if _fidget_t > 0.0:
			_fidget_t = -_rng.randf_range(1.0, 2.0)
	var pose: StringName = _active_pose(downed, moving)
	for name_k: StringName in [&"revive", &"repair", &"drink", &"buy", &"stretch", &"watch", &"tap", &"write", &"warm"]:
		_blend[name_k] = move_toward(float(_blend.get(name_k, 0.0)), 1.0 if pose == name_k else 0.0, delta * 5.0)
	_down_b = move_toward(_down_b, 1.0 if downed else 0.0, delta * 3.0)
	_crouch_b = move_toward(_crouch_b, 1.0 if crouch else 0.0, delta * 6.0)
	_sprint_b = move_toward(_sprint_b, 1.0 if sprint else 0.0, delta * 5.0)
	_reload_b = move_toward(_reload_b, 1.0 if reloading and pose == &"" else 0.0, delta * 6.0)
	_ads_b = move_toward(_ads_b, 1.0 if ads_on and pose == &"" else 0.0, delta * 5.0)
	if reloading:
		_reload_ph += delta
	else:
		_reload_ph = 0.0
	_recoil = move_toward(_recoil, 0.0, delta * 9.0)
	_melee_t = maxf(0.0, _melee_t - delta)
	_throw_t = maxf(0.0, _throw_t - delta)
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_flash.hide()
			_flash_light.light_energy = 0.0
	var stride: float = 0.75 if not sprint else 1.05
	if moving:
		_phase += delta * PI * speed / stride
	var p: float = _phase
	var swing: float = (0.55 + 0.25 * _sprint_b) * clampf(speed / 3.0, 0.0, 1.0) if moving else 0.0
	var kneel: float = float(_blend[&"revive"])
	var b_rep: float = float(_blend[&"repair"])
	var b_drink: float = float(_blend[&"drink"])
	var b_buy: float = float(_blend[&"buy"])
	var b_stretch: float = float(_blend[&"stretch"])
	var b_watch: float = float(_blend[&"watch"])
	var b_tap: float = float(_blend[&"tap"])
	var b_write: float = float(_blend[&"write"])
	var b_warm: float = float(_blend[&"warm"])   # Jakub blows into his cupped hands
	# both hands busy: the gun goes on the sling across the back; one hand busy: held low in the other
	var sling: float = maxf(maxf(kneel, b_rep), maxf(maxf(b_write, b_stretch), b_warm))
	var low: float = maxf(maxf(b_drink, b_buy), maxf(b_watch, b_tap))
	# --- body
	_pivot.rotation.x = lerpf(0.0, -1.47, _down_b)
	_tag.position.y = lerpf(2.15, 1.0, _down_b)
	_pivot.position = Vector3(0, lerpf(0.0, 0.08, _down_b), lerpf(0.0, 0.7, _down_b))
	var hip_y: float = 0.95 - 0.32 * _crouch_b - (absf(sin(p)) * 0.03 if moving else 0.0)
	hip_y = lerpf(hip_y, 0.63, kneel)
	_hips.position.y = hip_y
	var lean: float = float(_build.get("lean", 0.0))
	var t_now: float = Time.get_ticks_msec() * 0.001
	var chest_x: float = -0.12 * _crouch_b - 0.18 * _sprint_b + lean * (1.0 - _sprint_b) + lerpf(0.0, 0.62, _down_b)
	chest_x += -0.45 * kneel - 0.18 * b_rep + 0.38 * b_stretch * (0.8 + 0.2 * sin(t_now * 2.0)) - 0.12 * b_write - 0.08 * b_tap
	_chest.rotation.x = chest_x
	_chest.rotation.y = sin(p) * 0.08 * swing + 0.25 * b_stretch * sin(t_now * 1.3)
	var aim: float = clampf(pitch, -1.2, 1.2)
	var head_x: float = lerpf(aim * 0.6, 0.6, _down_b) - _chest.rotation.x * 0.4
	head_x += 0.35 * b_drink * clampf((1.7 - _act_t) * 2.0, 0.0, 1.0) - 0.55 * b_watch - 0.5 * b_write - 0.25 * kneel + 0.3 * b_stretch - 0.12 * b_warm
	var long_gun: bool = str(_gun_hold.get("kind", "long")) == "long"
	head_x += (0.3 if long_gun else 0.12) * _ads_b   # cheek down onto the stock (behind a pistol the head stays up)
	_head.rotation.x = head_x
	# T-099: behind a long gun the body turns side-on (the feet and hips with it), left shoulder forward, so the
	# support hand reaches the handguard; the head and the gun turn back to the front
	var blade_to: float = (0.55 + 0.2 * _ads_b) * (1.0 - low) * (1.0 - sling) * (1.0 - _down_b) * (1.0 - 0.6 * _sprint_b)
	_blade = move_toward(_blade, blade_to if long_gun and _gun != null else 0.0, delta * 3.0)
	_pivot.rotation.y = -_blade
	_head.rotation.y = 0.35 * b_tap * sin(t_now * 0.7) + 0.9 * _blade
	_head.rotation.z = (-0.16 if long_gun else 0.0) * _ads_b   # T-099: the head leans onto the stock
	# gun: aimed in both hands -> held low -> slung on the back
	var aim_xf: Transform3D = Transform3D(Basis(Vector3.UP, _blade) * Basis.from_euler(Vector3(lerpf(aim, -0.75, _sprint_b) - _chest.rotation.x + _recoil * 0.12, 0.0, 0.0)),
		Vector3.ZERO)
	if _down_b > 0.5:
		aim_xf.basis = Basis.from_euler(Vector3(aim + 1.15 - _chest.rotation.x, 0.0, 0.0))
	if _reload_b > 0.0:
		var tip: Basis = Basis.from_euler(Vector3(-0.45 * _reload_b, 0.15 * _reload_b, 0.55 * _reload_b))
		aim_xf.basis = aim_xf.basis * tip
	if _melee_t > 0.0:
		aim_xf.basis = aim_xf.basis * Basis(Vector3.UP, sin(_melee_t / 0.35 * PI) * 0.8)
	# T-099: the gun turns about its hold point, placed on the body actually drawn (_hold_anchor): a long gun's butt
	# tucked under the shoulder at the hip and in the shoulder pocket aimed; a pistol's grip out in both hands
	var gun_at: Vector3 = _gun.position if _gun != null else Vector3(0.12, -0.02, -0.28)
	var hold_pt: Vector3 = gun_at + (_gun_hold.get("pivot", Vector3.ZERO) as Vector3)
	var old_o: Vector3 = Vector3(0.0, 0.43 - float(_build.get("gun_drop", 0.0)), -0.05)
	aim_xf.origin = (_hold_anchor(_ads_b) - aim_xf.basis * hold_pt).lerp(old_o, _down_b)
	var low_xf: Transform3D = Transform3D(Basis.from_euler(Vector3(-1.05, 0.35, 0.0)), Vector3(-0.08, 0.22, -0.12))
	var sling_xf: Transform3D = Transform3D(Basis.looking_at(Vector3(0.55, 0.83, 0.0), Vector3.BACK), Vector3(-0.2, 0.05, 0.24))
	var gxf: Transform3D = aim_xf.interpolate_with(low_xf, low)
	_gun_pivot.transform = gxf.interpolate_with(sling_xf, sling)
	# --- legs (hip -> knee -> ankle in pivot space)
	var stance: float = float(_build.get("stance", 0.1))
	for side: int in [0, 1]:
		var s: String = "l" if side == 0 else "r"
		var sx: float = -stance if side == 0 else stance
		var ph: float = p + (0.0 if side == 0 else PI)
		var hip: Vector3 = _pivot.to_local(_hips.global_position) + Vector3(sx, -0.06, 0)
		var thigh_a: float = sin(ph) * swing + 1.0 * _crouch_b
		var knee_a: float = -maxf(0.0, cos(ph)) * swing * 1.4 - 2.0 * _crouch_b
		if kneel > 0.0:
			# revive: left foot planted forward, right knee on the ground
			thigh_a = lerpf(thigh_a, 1.4 if side == 0 else 0.15, kneel)
			knee_a = lerpf(knee_a, -1.4 if side == 0 else -1.6, kneel)
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
		foot.rotation = Vector3(-shin_dir if (kneel > 0.5 and side == 1) else 0.0, 0, 0)
		_legs_d[side] = [thigh_a, knee_a, foot.rotation.x]
	# --- arms: both hands on the gun (right on the grip, left on the support point) unless an action takes them
	var grip: Vector3 = _gun_pivot.global_transform * Vector3(0.12, -0.05, -0.24)
	var support: Vector3 = _gun_pivot.global_transform * Vector3(0.1, -0.03, -0.5)
	var hb: Array = [null, null]
	if _gun != null:
		var lh: Node3D = _gun.get_node_or_null("LeftHand") as Node3D
		if lh != null:
			support = lh.global_position
		grip = _gun.global_position
		# T-099: the wrists sit back from the grips so the palms close on them (PersonRig turns the hands to fit)
		var on_gun: Array = hand_on_gun(_gun_hold, _gun.global_transform.basis.orthonormalized(), grip, support, s_k())
		grip = on_gun[0]
		support = on_gun[2]
		if long_gun:
			# a long gun's support hand slides back along the handguard (at most 20 cm) when the arm can't reach
			var k2: float = s_k()
			var sh_l: Vector3 = _chest.global_transform * (Vector3(-0.2 * k2, (0.95 + 0.51 * k2 - 1.07) if person != null else 0.5, 0.0))
			var reach: float = (UPPER + FORE) * k2 * 0.9   # a little bend left in the elbow
			var back_dir: Vector3 = _gun.global_transform.basis.orthonormalized().z
			var slide: float = 0.0
			while slide < 0.2 and (support + back_dir * slide).distance_to(sh_l) > reach:
				slide += 0.01
			support += back_dir * slide
		hb = [on_gun[3], on_gun[1]]
	# how much each hand is on the gun (the actions below take them off it)
	var on_l: float = (1.0 - low) * (1.0 - sling) * (1.0 - _reload_b) * (1.0 if _throw_t <= 0.0 and _down_b < 0.5 else 0.0)
	var on_r: float = (1.0 - low * (1.0 - b_watch)) * (1.0 - sling) * (1.0 if _down_b < 0.5 else 0.0)
	if _throw_t > 0.0:
		var k: float = sin(_throw_t / 0.4 * PI)
		support = _chest.global_transform * Vector3(-0.25, 0.55 + 0.3 * k, -0.2 - 0.3 * k)
	var right: Vector3 = grip
	var left: Vector3 = support
	if _reload_b > 0.0:
		# the support hand drops to the belt for a magazine and back up to the gun
		var cyc: float = 0.5 - 0.5 * cos(_reload_ph * TAU / 0.9)
		left = left.lerp(_hips.global_transform * Vector3(-0.12, 0.08, -0.16), cyc * _reload_b)
	# one hand busy: the left keeps the lowered gun, the right does the job
	if low > 0.0:
		left = left.lerp(_gun.global_position if _gun != null else left, low)
		var r_job: Vector3 = right
		var cp: Transform3D = _chest.global_transform
		if b_drink > 0.0:
			var lift: float = clampf((_act_len - _act_t) / 0.45, 0.0, 1.0) * clampf(_act_t / 0.3, 0.0, 1.0)
			r_job = (cp * Vector3(0.18, 0.2, -0.22)).lerp(_head.global_transform * Vector3(0.02, 0.1, -0.16), lift)
		elif b_buy > 0.0:
			var reach: float = 0.5 + 0.5 * sin(t_now * 7.0)
			r_job = cp * Vector3(0.14, 0.42 + 0.03 * reach, -0.5 - 0.06 * reach)
		elif b_watch > 0.0:
			r_job = right   # the gun hand stays put
			left = left.lerp(cp * Vector3(-0.02, 0.42, -0.3), b_watch)
		elif b_tap > 0.0:
			var knock: float = maxf(0.0, sin(t_now * 9.0))
			r_job = cp * Vector3(0.16, 0.34, -0.48 - 0.06 * knock)
		if b_watch <= 0.0:
			right = right.lerp(r_job, low)
		else:
			right = right.lerp(_gun.global_position if _gun != null else right, b_watch)
	if sling > 0.0:
		var cp2: Transform3D = _chest.global_transform
		var l_job: Vector3 = left
		var r_job2: Vector3 = right
		if kneel > 0.0:
			var pump: float = 0.03 * sin(t_now * 6.0)
			l_job = cp2 * Vector3(-0.12, 0.02 + pump, -0.5)
			r_job2 = cp2 * Vector3(0.12, 0.02 - pump, -0.5)
		elif b_rep > 0.0:
			var hammer: float = 0.06 * maxf(0.0, sin(t_now * 8.0))
			l_job = cp2 * Vector3(-0.22, 0.38, -0.46 - hammer)
			r_job2 = cp2 * Vector3(0.22, 0.38, -0.46 - hammer)
		elif b_write > 0.0:
			l_job = cp2 * Vector3(-0.05, 0.3, -0.3)
			r_job2 = cp2 * Vector3(0.05 + 0.02 * sin(t_now * 5.0), 0.33, -0.3 + 0.015 * sin(t_now * 11.0))
		elif b_stretch > 0.0:
			l_job = _hips.global_transform * Vector3(-0.12, 0.12, 0.16)
			r_job2 = _hips.global_transform * Vector3(0.12, 0.12, 0.16)
		elif b_warm > 0.0:
			var rub: float = 0.012 * sin(t_now * 9.0)
			l_job = cp2 * Vector3(-0.035 + rub, 0.6, -0.2)
			r_job2 = cp2 * Vector3(0.035 - rub, 0.6, -0.2)
		left = left.lerp(l_job, sling)
		right = right.lerp(r_job2, sling)
	for side2: int in [0, 1]:
		var s2: String = "l" if side2 == 0 else "r"
		var sh: Vector3 = _pivot.to_local(_chest.global_transform * Vector3(-0.24 if side2 == 0 else 0.24, 0.5, 0))
		var hand: Vector3 = _pivot.to_local(left if side2 == 0 else right)
		var pole: Vector3 = Vector3(-0.6 if side2 == 0 else 0.6, -1.0, 0.3)
		# T-099: on the gun the elbows hang down and a little out (the support elbow under the handguard)
		var on: float = on_l if side2 == 0 else on_r
		if on > 0.0:
			var gp: Vector3 = Vector3(-0.3, -1.0, 0.0) if side2 == 0 else Vector3(0.75, -0.7, 0.25)
			if not long_gun:
				gp = Vector3(-0.5 if side2 == 0 else 0.5, -1.0, 0.1)
			pole = pole.lerp(_pivot.global_transform.basis.inverse() * (_chest.global_transform.basis * gp), on)
		if b_stretch > 0.5:
			pole = Vector3(-1.0 if side2 == 0 else 1.0, 0.2, 0.3)
		var elbow: Vector3 = WeaponHolder._solve_elbow(sh, hand, UPPER, FORE, pole)
		_hand_t[side2] = hand
		_poles[side2] = pole
		_hand_w[side2] = on_l if side2 == 0 else on_r
		_hand_b[side2] = null if hb[side2] == null else _pivot.global_transform.basis.orthonormalized().inverse() * (hb[side2] as Basis)
		_place(_limbs["upper_" + s2] as MeshInstance3D, sh, elbow)
		_place(_limbs["fore_" + s2] as MeshInstance3D, elbow, hand)
		(_joints["hand_" + s2] as MeshInstance3D).position = hand
	_update_props(b_drink, b_write, b_rep, b_tap)
	if person != null:
		person.drive({"hips": _hips.position, "chest": _chest.basis, "head": _head.basis, "legs": _legs_d,
			"hands": _hand_t, "poles": _poles, "plant": _down_b < 0.05, "hand_basis": _hand_b, "hand_w": _hand_w})
		person.face.set_expression(_face_state(downed, pose))
	# footsteps for nearby teammates
	if moving and _down_b < 0.5:
		_step_t -= delta * speed / stride
		if _step_t <= 0.0:
			_step_t = 1.0
			var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
			if cam != null and cam.global_position.distance_squared_to(global_position) < 400.0:
				AudioDirector.play_3d("footstep_stone", global_position, -10.0, 0.1)


## T-099: the drawn person's height scale (1.0 for the primitives).
func s_k() -> float:
	return person.scale_k if person != null else 1.0


## T-099: where the gun's hold point goes in the gun pivot's parent space (the puppet's chest node), from the hip
## hold (ads 0) to the aimed one (ads 1), on the body actually drawn: the modelled person's rig shoulder and eye
## (rig.json rest heads times the person's height, relative to the puppet chest at hips + 0.12) or the primitives'.
func _hold_anchor(ads: float) -> Vector3:
	var k: float = s_k()
	var drop: float = float(_build.get("gun_drop", 0.0))
	var sh_y: float = (0.95 + 0.51 * k - 1.07) if person != null else 0.5
	var eye_y: float = (0.95 + 0.765 * k - 1.07) if person != null else 0.74
	var sight_y: float = float(_gun_hold.get("sight_y", 0.07))
	if str(_gun_hold.get("kind", "long")) == "pistol":
		var hip_p: Vector3 = Vector3(0.05, sh_y - 0.14 - drop, -0.36 * k)
		var ads_p: Vector3 = Vector3(0.035, eye_y - 0.05 - sight_y, -0.47 * k)
		return hip_p.lerp(ads_p, ads)
	var hip_l: Vector3 = Vector3(0.14 * k, sh_y - 0.07 - drop, -0.09 * k)
	var ads_y: float = clampf(eye_y - 0.075 - sight_y, sh_y - 0.02, sh_y + 0.1)
	var ads_l: Vector3 = Vector3(0.085 * k, ads_y - drop * 0.5, -0.12 * k)
	return hip_l.lerp(ads_l, ads)


## T-099: how a gun is held, measured from its model: "pistol" (class pistol, or nothing behind the grip) or
## "long"; "pivot" = the hold point in the gun's frame (a long gun's butt: the back of its meshes at the grip's
## height; a pistol: its grip, the origin); "sight_y" = the sight line (SightPoint) over that point; the support
## grip's axis / radius (WeaponModels lhand metas) and the firing grip (grip_r, grip_r_radius).
static func hold_of(gun: Node3D, weapon_id: StringName) -> Dictionary:
	var out: Dictionary = {"kind": "long", "pivot": Vector3.ZERO, "sight_y": 0.07, "lh_axis": "z", "lh_r": 0.024,
		"grip_r": Transform3D.IDENTITY, "grip_rr": 0.016}
	if gun == null:
		return out
	var row: Dictionary = (GLData.table("weapons").get("weapons", {}) as Dictionary).get(String(weapon_id), {})
	var cls: String = str(row.get("class", ""))
	var back: float = 0.0
	for n: Node in gun.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null or not mi.visible:
			continue
		var bb: AABB = _rel_xf(gun, mi) * mi.get_aabb()
		back = maxf(back, bb.end.z)
	var pistol: bool = cls == "pistol" or back < 0.1 or weapon_id == &"coal_shovel"
	out["kind"] = "pistol" if pistol else "long"
	out["pivot"] = Vector3.ZERO if pistol else Vector3(0.0, 0.01, back - 0.015)
	var sp: Node3D = gun.get_node_or_null("SightPoint") as Node3D
	if sp != null:
		out["sight_y"] = (_rel_xf(gun, sp).origin - (out["pivot"] as Vector3)).y
	out["lh_axis"] = str(gun.get_meta("lh_axis", "y" if pistol else "z"))
	out["lh_r"] = float(gun.get_meta("lh_radius", 0.024))
	if gun.has_meta("grip_r"):
		out["grip_r"] = gun.get_meta("grip_r")
		out["grip_rr"] = float(gun.get_meta("grip_r_radius", 0.016))
	return out


## A node's transform relative to an ancestor (works outside the tree).
static func _rel_xf(root: Node3D, n: Node3D) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


## T-099: the hands on a gun, global space: [right wrist, right hand basis, left wrist, left hand basis]. `gb` is the
## gun's basis, `grip` its origin (the firing grip), `lh` its LeftHand marker. A hand basis is the rig's Hand bone
## frame (+Y from the fingers back to the wrist; +X the left palm's normal, the back of the right hand), so the
## fingers, which curl toward the palm, close round the grip. The wrist sits back from the grip by the palm.
static func hand_on_gun(hold: Dictionary, gb: Basis, grip: Vector3, lh: Vector3, k: float) -> Array:
	var g: Transform3D = hold.get("grip_r", Transform3D.IDENTITY)
	var grip_c: Vector3 = grip + gb * g.origin
	# the firing hand: the palm on the grip's right side, knuckles forward and down, fingers round its front
	var f_r: Vector3 = (gb * (g.basis * Vector3(0.0, -0.32, -0.95))).normalized()
	var n_r: Vector3 = (gb * Vector3(-1.0, 0.0, 0.0)).normalized()   # from the palm toward the grip
	var wr: Vector3 = grip_c - f_r * 0.05 * k - n_r * (float(hold.get("grip_rr", 0.016)) + 0.012) * k
	var r: float = float(hold.get("lh_r", 0.024))
	var c: Vector3 = lh
	var f: Vector3
	var n: Vector3
	if str(hold.get("kind", "long")) == "pistol":
		# cupping the gun hand from the left and below
		c = grip + gb * Vector3(-0.015, -0.04, -0.005)
		f = (gb * Vector3(0.3, -0.3, -0.9)).normalized()
		n = (gb * Vector3(1.0, 0.3, 0.0)).normalized()
		r = 0.02
	elif str(hold.get("lh_axis", "z")) == "y":
		# round an upright foregrip / magazine: palm on its left, fingers round the front
		f = (gb * Vector3(0.15, -0.25, -0.96)).normalized()
		n = (gb * Vector3(1.0, 0.0, 0.0)).normalized()
	else:
		# under the handguard: palm up and a little right, thumb along the left side, fingers over the right
		f = (gb * Vector3(0.3, 0.12, -0.95)).normalized()
		n = (gb * Vector3(0.4, 0.92, 0.0)).normalized()
	var wl: Vector3 = c - f * 0.05 * k - n * (r + 0.012) * k
	return [wr, _hand_basis(f_r, -n_r), wl, _hand_basis(f, n)]


## The Hand bone basis for fingers along `fingers` and the bone's +X along `x_dir`.
static func _hand_basis(fingers: Vector3, x_dir: Vector3) -> Basis:
	var y: Vector3 = -fingers.normalized()
	var x: Vector3 = x_dir - y * x_dir.dot(y)
	x = x.normalized() if x.length_squared() > 1e-6 else Vector3.RIGHT
	return Basis(x, y, x.cross(y).normalized())


## The face for the moment (T-092): downed = pain, low health = fear, shooting = determined, else the rest face
## (a smile now and then while calm and fidgeting).
func _face_state(downed: bool, pose: StringName) -> StringName:
	if downed:
		return &"pain"
	var p: Player = get_parent() as Player
	if p != null and p.max_hp > 0.0 and p.hp / p.max_hp < 0.35:
		return &"fear"
	if _since_shot < 2.0 or _reload_b > 0.5:
		return &"determined"
	if pose != &"" and _fidget_t > 1.5 and _fidget_t < 3.5 and pose == StringName(str(_build.get("fidget", ""))):
		return &"smile"
	return &"neutral"


## The props follow the hands: the perk bottle, Wren's notebook and pencil, the plank, Deacon's wrench.
func _update_props(b_drink: float, b_write: float, b_rep: float, b_tap: float) -> void:
	(_props["bottle"] as Node3D).visible = b_drink > 0.3
	(_props["notebook"] as Node3D).visible = b_write > 0.3
	(_props["pencil"] as Node3D).visible = b_write > 0.3
	(_props["wrench"] as Node3D).visible = b_tap > 0.3
	var plank: Node3D = _props["plank"]
	plank.visible = b_rep > 0.3
	if plank.visible:
		var a: Vector3 = (_joints["hand_l"] as Node3D).position
		var b: Vector3 = (_joints["hand_r"] as Node3D).position
		var mid: Vector3 = (a + b) * 0.5
		var x: Vector3 = b - a
		if x.length() > 0.01 and absf(x.normalized().dot(Vector3.UP)) < 0.95:
			var xn: Vector3 = x.normalized()
			var z: Vector3 = xn.cross(Vector3.UP).normalized()
			plank.transform = Transform3D(Basis(xn, z.cross(xn), z), mid + Vector3(0, 0.02, 0))


## Co-op: a remote teammate holding a revive on someone (the host's reviver state) kneels like a bot does.
func _co_op_revive_hint() -> void:
	if _ai():
		return
	var s: NetMatch = Net.session
	if s == null or s.coop == null:
		return
	for k: Variant in s.coop.players.keys():
		if s.coop.reviver_of(int(k)) == pid:
			_hold[&"revive"] = 0.25
			return


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
