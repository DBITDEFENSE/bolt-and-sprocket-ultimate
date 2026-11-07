class_name CinemaRisen
extends Node3D
## T-194: one of the risen walking west in the LAZARUS cutscenes (FOURTH DAY's road, the C-47's window), a body on
## the zombie rig playing a walk in place while the stage moves the node. Presentation only: no AI, no hitboxes, no
## collider, never in the "zombies" group.
##
## THE SEAM FOR T-192 (u11-6-horror builds the Soviet risen skins and a column-walking ambience kind in parallel):
## every risen body in these cutscenes is made by `CinemaRisen.make(kind, seed)` and nothing else, and the kind comes
## from the data (cutscenes_lazarus.json "risen_kind", default "soviet_greatcoat"). Until T-192 merges, `make` builds
## a stand-in: the existing zombie rig in the soldier kit recoloured to a frost-white Red Army greatcoat (some
## bareheaded, a few in pale burial wrappings). When the horror pass lands, `make` hands the kind to its skin builder
## (the one place to change) and every cutscene picks the real skins up.

const STAND_IN_PALETTES: Array = [
	{"cloth": [0.52, 0.5, 0.44], "cloth2": [0.4, 0.38, 0.32]},   # a greatcoat white with frost
	{"cloth": [0.44, 0.42, 0.34], "cloth2": [0.33, 0.31, 0.25]},
	{"cloth": [0.6, 0.59, 0.55], "cloth2": [0.47, 0.46, 0.42]},
	{"cloth": [0.72, 0.7, 0.64], "cloth2": [0.62, 0.6, 0.55]},   # burial wrappings
]

var kind: String = "soviet_greatcoat"
var walk_speed: float = 1.1
var skel: Skeleton3D = null
var body: MeshInstance3D = null
var _ap: AnimationPlayer = null
static var _inplace: Dictionary = {}   # clip -> [Animation without its root motion, its native speed]


## The one function that makes a risen body for a cutscene (the T-192 seam). `seed_v` picks the variation.
static func make(kind_id: String, seed_v: int) -> CinemaRisen:
	var r: CinemaRisen = CinemaRisen.new()
	r.kind = kind_id if kind_id != "" else "soviet_greatcoat"
	r.name = "Risen_%d" % seed_v
	r._build_stand_in(seed_v)
	return r


func _build_stand_in(seed_v: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("risen:%s:%d" % [kind, seed_v])
	var pal_raw: Dictionary = STAND_IN_PALETTES[rng.randi() % STAND_IN_PALETTES.size()]
	var palette: Dictionary = {}
	for k: String in pal_raw.keys():
		var a: Array = pal_raw[k]
		palette[k] = Color(float(a[0]), float(a[1]), float(a[2])).srgb_to_linear()
	var build: String = ["thin", "medium", "medium"][rng.randi() % 3]
	ZombieBody.ensure_globals()
	var pivot: Node3D = Node3D.new()
	pivot.name = "Pivot"
	add_child(pivot)
	skel = ZombieRig.build_skeleton()
	pivot.add_child(skel)
	body = MeshInstance3D.new()
	body.name = "Body"
	body.mesh = ZombieBody.build_dressed("soldier", build, false, Color(0, 0, 0, 0), palette, false)
	skel.add_child(body)
	body.skeleton = NodePath("..")
	body.skin = skel.create_skin_from_rest_transforms()
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.set_instance_shader_parameter("inst_frost", rng.randf_range(0.45, 0.9))
	body.set_instance_shader_parameter("inst_dirt", rng.randf_range(0.3, 0.6))
	if rng.randf() < 0.45:   # a cap on some; the rest bareheaded
		var spec: Array = ZombieBody.gear_mesh("side_cap" if rng.randf() < 0.6 else "cap", false)
		var at: BoneAttachment3D = BoneAttachment3D.new()
		at.bone_name = str(spec[0])
		skel.add_child(at)
		var g: MeshInstance3D = MeshInstance3D.new()
		g.mesh = spec[1]
		g.material_override = CinemaSet.flat(Color(0.36, 0.35, 0.28), 0.9)
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		at.add_child(g)
	_ap = AnimationPlayer.new()
	_ap.name = "AP"
	pivot.add_child(_ap)
	_ap.root_node = NodePath("..")
	var clip: String = ["shamble_a", "shamble_b", "walk_a", "shamble_c"][rng.randi() % 4]
	var lib: AnimationLibrary = AnimationLibrary.new()
	var ip: Array = in_place(clip)
	lib.add_animation(&"walk", ip[0])
	_ap.add_animation_library(&"", lib)
	walk_speed = rng.randf_range(0.95, 1.3)
	_ap.speed_scale = walk_speed / maxf(0.2, float(ip[1]))
	_ap.play(&"walk")
	_ap.seek(rng.randf_range(0.0, (ip[0] as Animation).length), true)


## A locomotion clip with its root motion taken out (the stage moves the node) and its native ground speed.
static func in_place(clip: String) -> Array:
	if _inplace.has(clip):
		return _inplace[clip]
	var src: Animation = ZombieClips.library().get_animation(clip) if ZombieClips.has_clip(clip) else ZombieClips.library().get_animation("walk_a")
	var a: Animation = src.duplicate(true) as Animation
	var speed: float = 1.0
	var ti: int = a.find_track(NodePath("Skel:Root"), Animation.TYPE_POSITION_3D)
	if ti >= 0:
		var n: int = a.track_get_key_count(ti)
		if n >= 2:
			var p0: Vector3 = a.track_get_key_value(ti, 0)
			var p1: Vector3 = a.track_get_key_value(ti, n - 1)
			speed = maxf(0.2, Vector2(p1.x - p0.x, p1.z - p0.z).length() / maxf(0.05, a.length))
		a.remove_track(ti)
	a.loop_mode = Animation.LOOP_LINEAR
	_inplace[clip] = [a, speed]
	return _inplace[clip]
