class_name DecompReactive
extends Node3D
## T-274 (the map detail pass, Der Kranich): what a decompression breach (DecompressionBreach, decompression.gd) does
## to the loose things near it. When the breach's pull begins, every LoosePapers set in `papers` is pulled toward the
## hole and out (the sheets that reach it are gone), every ShatterSet in `glass` loses the pieces within `radius` m
## (nearest first, a few tenths of a second apart, flung toward the hole), and the panes at `panes` (map points)
## burst in a spray of glass. Presentation only: the breach's phases are mirrored to every peer and each runs its own.

const PANE_TINT: Color = Color(0.78, 0.86, 0.9, 0.7)

@export var breach: NodePath = NodePath("")
@export var papers: Array[NodePath] = []
@export var glass: Array[NodePath] = []
@export var panes: PackedVector3Array = PackedVector3Array()
@export var radius: float = 14.0

var fired: int = 0
var _b: Node3D = null
var _last: int = 0
var _poll: float = 0.0


func _ready() -> void:
	_b = get_node_or_null(breach) as Node3D


func _process(delta: float) -> void:
	_poll -= delta
	if _poll > 0.0 or _b == null or not is_instance_valid(_b):
		return
	_poll = 0.1
	var ph: int = int(_b.get("phase"))
	if ph == 2 and _last != 2:   # DecompressionBreach.Phase.PULL
		burst()
	_last = ph


## The pull begins: papers out, glass broken, panes burst.
func burst() -> void:
	fired += 1
	var hole: Vector3 = _b.call("hole") if _b != null and _b.has_method("hole") else Vector3.ZERO
	for p: NodePath in papers:
		var lp: Node = get_node_or_null(p)
		if lp != null and lp.has_method("blow"):
			lp.call("blow", hole, 9.0, radius + 30.0, true)
	for g: NodePath in glass:
		var ss: Node3D = get_node_or_null(g) as Node3D
		if ss == null or not ss.has_method("break_item"):
			continue
		var items: Array = ss.get("items")
		var order: Array = []
		for i: int in items.size():
			var at: Vector3 = ss.to_global((items[i] as Array)[0] as Vector3)
			if at.distance_to(hole) <= radius:
				order.append([at.distance_to(hole), i, at])
		order.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		for k: int in order.size():
			var row: Array = order[k]
			get_tree().create_timer(0.05 + 0.12 * float(k)).timeout.connect(func() -> void:
				if is_instance_valid(ss):
					ss.call("break_item", int(row[1]), (hole - (row[2] as Vector3)).normalized()))
	for pp: Vector3 in panes:
		Effects.shatter(pp, PANE_TINT, 14, 3.0)
		if AudioDirector.has_sound("glass_break"):
			AudioDirector.play_3d("glass_break", pp, 0.0, 0.1)
