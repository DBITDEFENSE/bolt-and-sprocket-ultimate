class_name CinemaRisen
extends Node3D
## T-194: one of the risen walking west in the LAZARUS cutscenes (FOURTH DAY's road, the 1930 fire's far figures), a
## body on the zombie rig playing a shamble in place while the stage moves the node. Presentation only: no AI, no
## hitboxes, no collider, never in the "zombies" group.
##
## The seam: every risen body in these cutscenes is made by `CinemaRisen.make(kind, seed)` and nothing else, the kind
## from the data (cutscenes_lazarus.json "risen_kind"). Since T-192 merged it is the horror pass's own body
## (RisenColumn.body: the Soviet kits soviet / soviet_tunic / soviet_burial, the frost skin, the milky eyes, the wound
## that killed them, a hat from the kit) at RisenColumn's kit weights; kind "soviet_burial" (or any one kit name) asks
## for that kit only. The stand-in built before T-192 landed (the soldier kit recoloured to a frost-white greatcoat)
## stays as the fallback for a kind RisenColumn does not know.

const KINDS_ALL: Array[String] = ["soviet_greatcoat", "soviet", ""]
const STAND_IN_PALETTES: Array = [
	{"cloth": [0.52, 0.5, 0.44], "cloth2": [0.4, 0.38, 0.32]},
	{"cloth": [0.44, 0.42, 0.34], "cloth2": [0.33, 0.31, 0.25]},
	{"cloth": [0.72, 0.7, 0.64], "cloth2": [0.62, 0.6, 0.55]},
]

var kind: String = "soviet_greatcoat"
var kit: String = ""
var walk_speed: float = 1.1
var body: MeshInstance3D = null


## The one function that makes a risen body for a cutscene. `seed_v` picks the variation (kit, build, hat, clip).
static func make(kind_id: String, seed_v: int) -> CinemaRisen:
	var r: CinemaRisen = CinemaRisen.new()
	r.kind = kind_id if kind_id != "" else "soviet_greatcoat"
	r.name = "Risen_%d" % seed_v
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("risen:%s:%d" % [r.kind, seed_v])
	r.walk_speed = rng.randf_range(0.9, 1.25)
	if not r._build_returned(seed_v, rng):
		r._build_stand_in(rng)
	return r


## The horror pass's Returned (T-192).
func _build_returned(seed_v: int, rng: RandomNumberGenerator) -> bool:
	var kits: Dictionary = RisenColumn.DEFAULT_KITS if KINDS_ALL.has(kind) else {kind: 1.0}
	var anim_kits: Dictionary = GLData.table("anim").get("kits", {})
	kit = RisenColumn.pick_kit(kits, rng.randf())
	if not anim_kits.has(kit):
		return false
	var kd: Dictionary = anim_kits[kit]
	var builds: Array = kd.get("builds", ["medium"])
	var build_id: String = str(builds[rng.randi() % builds.size()])
	var female: bool = rng.randf() < float(kd.get("female", 0.0))
	var b: Node3D = RisenColumn.body(kit, build_id, female, RisenColumn.CLIPS[rng.randi() % RisenColumn.CLIPS.size()], 9000 + seed_v, rng)
	add_child(b)
	var ap: AnimationPlayer = b.get_node_or_null("AP") as AnimationPlayer
	if ap != null:
		ap.speed_scale = walk_speed / RisenColumn.CLIP_SPEED
	body = b.get_node_or_null("Skel/Body") as MeshInstance3D
	return body != null


## The stand-in from before T-192: the soldier kit in a frost-white greatcoat, walking in place.
func _build_stand_in(rng: RandomNumberGenerator) -> void:
	kit = "soldier"
	var pal_raw: Dictionary = STAND_IN_PALETTES[rng.randi() % STAND_IN_PALETTES.size()]
	var palette: Dictionary = {}
	for k: String in pal_raw.keys():
		var a: Array = pal_raw[k]
		palette[k] = Color(float(a[0]), float(a[1]), float(a[2])).srgb_to_linear()
	ZombieBody.ensure_globals()
	var pivot: Node3D = Node3D.new()
	pivot.name = "Pivot"
	add_child(pivot)
	var skel: Skeleton3D = ZombieRig.build_skeleton()
	pivot.add_child(skel)
	body = MeshInstance3D.new()
	body.name = "Body"
	body.mesh = ZombieBody.build_dressed("soldier", "medium", false, Color(0, 0, 0, 0), palette, false)
	skel.add_child(body)
	body.skeleton = NodePath("..")
	body.skin = skel.create_skin_from_rest_transforms()
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.set_instance_shader_parameter("inst_frost", rng.randf_range(0.45, 0.9))
	var ap: AnimationPlayer = AnimationPlayer.new()
	ap.name = "AP"
	pivot.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library(&"", RisenColumn.clip_library())
	ap.speed_scale = walk_speed / RisenColumn.CLIP_SPEED
	ap.play(&"shamble_a")
