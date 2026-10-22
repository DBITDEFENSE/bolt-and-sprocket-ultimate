class_name SealedPassage
extends Node3D
## A bricked-up opening that falls in on a cue (Map 0's Old Cellar, DECISIONS T-051: the old ice chute between the
## coal room and the cousins' ice cellar under the bar). The bricks are a runtime collider on the "door" layer, so
## the navmesh already runs through the opening and paths open the moment the bricks go, like a BuyDoor.
## Frame: the origin is the middle of the opening on the floor, local X along the wall, local Z through it.
## Cue: open() directly, GLBus.intel_found with `open_on_intel` (HB1 files the aunt's letter, INT_HB_01, when the
## Cousins round is cleared), or every zone in `open_when_zones` open (the Old Cellar's breach to the Helvetia
## cellar: both cellar doors bought). A gap two bricks wide is left at eye height, so you can look in before that.
## `nav_swap_off` / `nav_swap_on`: two NavigationRegion3D (the map baked with the passage shut, and open); opening
## disables the first and enables the second, for a passage no path may run through while it is shut (unlike a door).

signal opened

const LAYER_DOOR: int = 1 << 8
const BRICK: Vector3 = Vector3(0.25, 0.075, 0.12)   # a brick and its mortar joint

@export var passage_id: StringName = &""
@export var size: Vector3 = Vector3(1.6, 2.0, 0.3)
@export var open_on_intel: StringName = &""
@export var open_when_zones: PackedStringArray = []
@export var nav_swap_off: NodePath
@export var nav_swap_on: NodePath

var is_open: bool = false
var _body: StaticBody3D
var _bricks: MultiMeshInstance3D


func _ready() -> void:
	add_to_group(&"sealed_passages")
	_body = StaticBody3D.new()
	_body.name = "SealBody"
	_body.collision_layer = LAYER_DOOR
	_body.collision_mask = 0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = Vector3(0, size.y * 0.5, 0)
	_body.add_child(cs)
	add_child(_body)
	_build_bricks()
	if open_on_intel != &"":
		GLBus.intel_found.connect(_on_intel)
	if not open_when_zones.is_empty():
		GLBus.zone_opened.connect(func(_z: StringName) -> void: _check_zones())
		_check_zones.call_deferred()


func _check_zones() -> void:
	if is_open or open_when_zones.is_empty():
		return
	for z: String in open_when_zones:
		if not GameState.is_zone_open(StringName(z)):
			return
	open()


## Swaps the shut navmesh for the open one (when the passage has them).
func _swap_nav() -> void:
	var off: NavigationRegion3D = get_node_or_null(nav_swap_off) as NavigationRegion3D if not nav_swap_off.is_empty() else null
	var on: NavigationRegion3D = get_node_or_null(nav_swap_on) as NavigationRegion3D if not nav_swap_on.is_empty() else null
	if off != null and on != null:
		on.enabled = true
		off.enabled = false


## True once the open navmesh is the live one (or the passage has none to swap).
func nav_open() -> bool:
	var on: NavigationRegion3D = get_node_or_null(nav_swap_on) as NavigationRegion3D if not nav_swap_on.is_empty() else null
	return on == null or on.enabled


func _on_intel(id: StringName) -> void:
	if id == open_on_intel:
		open()


## Two skins of running-bond brick filling the opening (one MultiMesh), with a peep gap at 1.5 m.
func _build_bricks() -> void:
	var xf: Array[Transform3D] = []
	var rows: int = int(size.y / BRICK.y)
	var cols: int = int(ceil(size.x / BRICK.x)) + 1
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(passage_id)
	for r: int in rows:
		var y: float = (float(r) + 0.5) * BRICK.y
		var shift: float = BRICK.x * 0.5 if r % 2 == 1 else 0.0
		for c: int in cols:
			var x: float = -size.x * 0.5 + float(c) * BRICK.x + shift
			if x < -size.x * 0.5 or x > size.x * 0.5:
				continue
			for skin: float in [-0.07, 0.07]:
				if skin < 0.0 and absf(y - 1.5) < 0.1 and absf(x - 0.1) < 0.26:
					continue   # the peep gap (room side only: the far skin shows through it, dark)
				xf.append(Transform3D(Basis(Vector3.BACK, rng.randf_range(-0.03, 0.03)), Vector3(x, y, skin)))
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = BRICK - Vector3(0.012, 0.012, 0.0)
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i: int in xf.size():
		mm.set_instance_transform(i, xf[i])
	_bricks = MultiMeshInstance3D.new()
	_bricks.name = "Bricks"
	_bricks.multimesh = mm
	_bricks.material_override = Mats.get_mat("brick_cellar")
	add_child(_bricks)


## Falls in: the collider goes, the bricks tumble through to the far side and settle in a heap, dust.
func open() -> void:
	if is_open:
		return
	is_open = true
	_body.collision_layer = 0
	_swap_nav()
	_open_visual()
	Net.mirror(self, &"_net_open")
	if passage_id != &"":
		GameState.set_flag(StringName("passage_%s_open" % passage_id), true)
	opened.emit()


func _open_visual() -> void:
	AudioDirector.play_3d("board_break", global_position + Vector3.UP * 1.0, 3.0)
	AudioDirector.play_3d("board_slam", global_position + Vector3.UP * 0.4, 0.0)
	if _bricks == null:
		return
	var mm: MultiMesh = _bricks.multimesh
	var from: Array[Transform3D] = []
	var to: Array[Transform3D] = []
	var delay: PackedFloat32Array = PackedFloat32Array()
	for i: int in mm.instance_count:
		var a: Transform3D = mm.get_instance_transform(i)
		from.append(a)
		var land: Vector3 = Vector3(a.origin.x * 0.8 + randf_range(-0.4, 0.4), randf_range(0.04, 0.3), randf_range(0.25, 1.0))
		var rot: Basis = Basis.from_euler(Vector3(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5), randf_range(-1.5, 1.5)))
		to.append(Transform3D(rot, land))
		delay.append(randf_range(0.0, 0.35) + (1.0 - a.origin.y / size.y) * 0.15)
	var step: Callable = func(t: float) -> void:
		for i: int in mm.instance_count:
			var k: float = clampf((t - delay[i]) / 0.5, 0.0, 1.0)
			k = k * k
			mm.set_instance_transform(i, Transform3D(from[i].basis.slerp(to[i].basis, k), from[i].origin.lerp(to[i].origin, k)))
	var tw: Tween = create_tween()
	tw.tween_method(step, 0.0, 1.05, 1.05)
	var dust: CPUParticles3D = CPUParticles3D.new()
	dust.one_shot = true
	dust.amount = 48
	dust.lifetime = 1.6
	dust.explosiveness = 0.6
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(size.x * 0.5, size.y * 0.5, 0.2)
	dust.position = Vector3(0, size.y * 0.5, 0)
	dust.direction = Vector3(0, 0.3, 1)
	dust.spread = 50.0
	dust.initial_velocity_min = 0.3
	dust.initial_velocity_max = 1.2
	dust.gravity = Vector3(0, -0.6, 0)
	var dm: BoxMesh = BoxMesh.new()
	dm.size = Vector3(0.04, 0.04, 0.04)
	dm.material = Mats.get_mat("plaster_cellar")
	dust.mesh = dm
	add_child(dust)
	dust.emitting = true


## Co-op client: the host's seal fell in.
func _net_open() -> void:
	if is_open:
		return
	is_open = true
	_body.collision_layer = 0
	_swap_nav()
	_open_visual()
