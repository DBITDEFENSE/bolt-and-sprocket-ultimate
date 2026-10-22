class_name ShatterSet
extends Node3D
## Bottles, steins, glasses and jars that break when shot (Update 02 section 8, T-053): a shelf's or a table's worth
## of glassware drawn as one MultiMesh per material, each piece with its own little "decor" hit volume (DecorHit).
## A shot (or a blast close by) hides that piece, throws shards and a splash of whatever was in it (ReactiveFx) and
## plays the break. Broken stays broken for the match. Built at load time from `items`, so the .tscn holds only the
## list. Local presentation (see DecorHit); nothing here collides with players, zombies or the navmesh.
##
## items: [[local base position (Vector3), kind (String), height scale (float)], ...]; kinds are KINDS' keys.

## kind -> [radius, height, material key, shard tint, liquid tint (alpha 0 = empty)]
const KINDS: Dictionary = {
	"bottle_green": [0.04, 0.29, "bottle_green", Color(0.35, 0.6, 0.35, 0.7), Color(0.35, 0.05, 0.08, 0.8)],
	"bottle_amber": [0.04, 0.3, "bottle_amber", Color(0.7, 0.45, 0.15, 0.7), Color(0.75, 0.5, 0.15, 0.7)],
	"stein": [0.06, 0.17, "stein", Color(0.6, 0.58, 0.52, 1.0), Color(0.8, 0.6, 0.2, 0.6)],
	"glass": [0.033, 0.1, "glass", Color(0.85, 0.9, 0.9, 0.5), Color(0.9, 0.85, 0.7, 0.3)],
	"jar": [0.05, 0.13, "jar_red", Color(0.8, 0.8, 0.75, 0.6), Color(0.5, 0.06, 0.05, 0.85)],
}
const SOUND: String = "glass_break"
const SOUND_FALLBACK: String = "glasshide_shatter"

@export var items: Array = []

var broken: PackedByteArray = PackedByteArray()
var _mm: Dictionary = {}          # material key -> MultiMesh
var _slot: PackedInt32Array = PackedInt32Array()   # item -> its instance index in its material's MultiMesh
var _xf: Array[Transform3D] = []
var _areas: Array[Area3D] = []
var _sound_cd: float = 0.0


func _ready() -> void:
	var by_mat: Dictionary = {}
	broken.resize(items.size())
	_slot.resize(items.size())
	for i: int in items.size():
		var it: Array = items[i]
		var k: Array = KINDS.get(str(it[1]), KINDS["glass"])
		var r: float = float(k[0])
		var h: float = float(k[1]) * (float(it[2]) if it.size() > 2 else 1.0)
		var base: Vector3 = it[0]
		var xf: Transform3D = Transform3D(Basis.from_scale(Vector3(r * 2.0, h, r * 2.0)), base + Vector3(0, h * 0.5, 0))
		_xf.append(xf)
		var mk: String = str(k[2])
		var list: Array = by_mat.get_or_add(mk, [])
		_slot[i] = list.size()
		list.append(i)
		var a: Area3D = DecorHit.make_area(self, base + Vector3(0, h * 0.5, 0), 0.0, Vector3(r * 2.4, h, r * 2.4))
		a.set_meta("i", i)
		_areas.append(a)
	for mk: String in by_mat.keys():
		var list2: Array = by_mat[mk]
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = Props.unit_cyl()
		mm.instance_count = list2.size()
		for j: int in list2.size():
			mm.set_instance_transform(j, _xf[int(list2[j])])
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.name = "Glass_" + mk
		mmi.multimesh = mm
		mmi.material_override = Mats.get_mat(mk)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_mm[mk] = mm
	if not GLBus.explosion.is_connected(_on_explosion):
		GLBus.explosion.connect(_on_explosion)
	set_process(false)


func _process(delta: float) -> void:
	_sound_cd -= delta
	if _sound_cd <= 0.0:
		set_process(false)


func on_decor_shot(col: Area3D, at: Vector3, dir: Vector3) -> void:
	if col != null and col.has_meta("i"):
		break_item(int(col.get_meta("i")), dir, at)


## Breaks piece `i` (no-op if it already is). `dir` is the way the force came from; `at` where (default: the piece).
func break_item(i: int, dir: Vector3 = Vector3.ZERO, at: Vector3 = Vector3.INF) -> bool:
	if i < 0 or i >= items.size() or broken[i] != 0:
		return false
	broken[i] = 1
	var it: Array = items[i]
	var k: Array = KINDS.get(str(it[1]), KINDS["glass"])
	var mm: MultiMesh = _mm[str(k[2])]
	mm.set_instance_transform(_slot[i], Transform3D(Basis.from_scale(Vector3.ZERO), _xf[i].origin))
	_areas[i].collision_layer = 0
	var where: Vector3 = to_global(_xf[i].origin) if at == Vector3.INF else at
	var fx: ReactiveFx = ReactiveFx.get_for(self)
	if fx != null:
		fx.glass(where, dir, k[3], k[4])
	if _sound_cd <= 0.0:
		_sound_cd = 0.06
		set_process(true)
		AudioDirector.play_3d(SOUND if AudioDirector.has_sound(SOUND) else SOUND_FALLBACK, where, -3.0, 0.12)
	return true


func broken_count() -> int:
	var n: int = 0
	for b: int in broken:
		n += b
	return n


## A blast close by breaks what is in reach (three quarters of its radius).
func _on_explosion(at: Vector3, radius: float) -> void:
	if not is_inside_tree():
		return
	var reach: float = radius * 0.75
	for i: int in items.size():
		if broken[i] == 0:
			var p: Vector3 = to_global(_xf[i].origin)
			if p.distance_to(at) < reach:
				break_item(i, p - at)
