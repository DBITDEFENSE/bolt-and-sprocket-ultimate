class_name RenderWarm
extends Node3D
## First-use stall warm-up (Update 04 performance pass, DECISIONS T-070). The first time a material the map never
## drew is drawn, the renderer compiles its shader and pipelines on the spot: Map 0's 100-150 ms hitches mid-fight
## were the first wound decal on a zombie (~95 ms), the first severed limb (~110 ms: its piece mesh is built and its
## un-skinned body material compiled) and the first glass bottle shot (~300 ms: ReactiveFx made on first use, then
## its particles' first draw). At map load this draws one of each, a thousandth of its size in front of the camera
## (sub-pixel: nothing shows) for a few frames, then removes them, so the cost lands in the load instead.
##
## Data-driven enough for new maps: the zombie parts come from the map's kit table (ZombieDirector.map_kits), and
## any system can add its own first-use visuals with RenderWarm.add_provider(callable) (called with this node; it
## adds MeshInstance3D / GeometryInstance3D children or fires its own invisible effect).

const FRAMES: int = 4
const SCALE: float = 0.001

static var _providers: Array[Callable] = []

var _frames: int = 0
var _items: Array[Node3D] = []


## Registers a warm-up step for every map from now on: f(warm: RenderWarm) -> void.
static func add_provider(f: Callable) -> void:
	if not _providers.has(f):
		_providers.append(f)


## Adds the warm-up under `map_root` (MapRoot calls it once the players are in).
static func run(map_root: Node) -> RenderWarm:
	var w: RenderWarm = RenderWarm.new()
	w.name = "RenderWarm"
	map_root.add_child(w)
	return w


## Draws `mesh` (with `mat` over it when given) for the warm-up frames.
func add_mesh(mesh: Mesh, mat: Material = null, shadow: bool = false) -> void:
	if mesh == null:
		return
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.scale = Vector3.ONE * SCALE
	add_child(mi)
	_items.append(mi)


## Where the warm-up draws: just in front of the current camera (world space).
func spot() -> Vector3:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	return cam.global_transform * Vector3(0.0, 0.0, -0.8) if cam != null else global_position


func _ready() -> void:
	top_level = true
	global_position = spot()
	_zombie_parts()
	var fx: ReactiveFx = ReactiveFx.get_for(self)   # made now, not at the first bottle shot
	if fx != null:
		fx.warm(spot())
	for f: Callable in _providers:
		if f.is_valid():
			f.call(self)


## A severed piece (the un-skinned body material) and its stump cap, and the wound decal.
func _zombie_parts() -> void:
	var kits: PackedStringArray = ZombieDirector.map_kits()
	var kit: String = kits[0] if not kits.is_empty() else "soldier"
	add_mesh(ZombieBody.piece_mesh(kit, "medium", false, "LeftLowerArm"))
	add_mesh(ZombieBody.stump_mesh(), null, true)
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2.ONE
	add_mesh(q, ZombieBody.blood_material())


func _process(_delta: float) -> void:
	global_position = spot()
	_frames += 1
	if _frames > FRAMES:
		queue_free()
