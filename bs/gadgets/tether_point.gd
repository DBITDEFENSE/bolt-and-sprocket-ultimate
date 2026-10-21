class_name TetherPoint
extends Marker3D
## A Tether-Hook ring (BS_LEVELS §0.5): orange cable-anchor rings are swing points, green rings are pull
## points. In group "tether_points". Any Marker3D / Area3D in that group works too (meta "kind" = "swing" or
## "pull", optional meta "land_offset" [x,y,z] for pull points, meta "enabled" false to switch it off);
## this class just adds the ring visual and a glow while the hook is aimed at it.

const SWING: StringName = &"swing"
const PULL: StringName = &"pull"

@export var kind: StringName = SWING
@export var enabled: bool = true
## Pull points: where the reel ends, relative to the ring (the hop then lifts Bolt over the lip).
@export var land_offset: Vector3 = Vector3(0, 1.4, 0)
@export var ring_radius: float = 0.55
## Rotation of the ring's face (degrees about Y); the ring always faces sideways so it reads from the ground.
@export var face_deg: float = 0.0

var point_id: String = ""
var _ring: MeshInstance3D
var _mat: StandardMaterial3D
var _glow: float = 0.0


func _ready() -> void:
	add_to_group(&"tether_points")
	set_meta(&"kind", String(kind))
	set_meta(&"enabled", enabled)
	set_meta(&"land_offset", [land_offset.x, land_offset.y, land_offset.z])
	_build()


func _build() -> void:
	var col: Color = Color("#ff9d2e") if kind == SWING else Color("#7ad04a")
	var t: Variant = Data.table("bs/gadgets")
	if t is Dictionary:
		var cols: Dictionary = (((t as Dictionary).get("gadgets", {}) as Dictionary).get("tether_hook", {}) as Dictionary).get("colors", {})
		col = Color.html(str(cols.get(String(kind), col.to_html())))
	_ring = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = ring_radius * 0.72
	tm.outer_radius = ring_radius
	tm.rings = 24
	tm.ring_segments = 10
	_ring.mesh = tm
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = col
	_mat.emission_enabled = true
	_mat.emission = col
	_mat.emission_energy_multiplier = 0.9
	_mat.metallic = 0.4
	_mat.roughness = 0.4
	_ring.material_override = _mat
	_ring.rotation_degrees = Vector3(90, face_deg, 0)
	add_child(_ring)
	# the bolt plate the ring hangs from
	LevelKit.box(self, Vector3(0, ring_radius + 0.12, 0), Vector3(0.36, 0.24, 0.36), "#39404f", false)
	if kind == PULL:
		# a green chevron under pull rings ("you get reeled here")
		LevelKit.box(self, Vector3(0, -ring_radius - 0.2, 0), Vector3(0.5, 0.08, 0.08), col, false, Vector3(0, face_deg, 45), 1, 1.0)


## The hook calls this every frame it is aimed / attached here.
func highlight(on: bool) -> void:
	_glow = 1.0 if on else _glow


func _process(delta: float) -> void:
	if _mat == null:
		return
	_glow = maxf(0.0, _glow - delta * 3.0)
	_mat.emission_energy_multiplier = 0.9 + _glow * 2.2 if enabled else 0.15
	if _ring != null:
		_ring.rotation_degrees.y = face_deg + sin(Time.get_ticks_msec() * 0.002) * 6.0


## Kind of any node in the tether_points / gadget_points groups.
static func kind_of(n: Node) -> StringName:
	if n is TetherPoint:
		return (n as TetherPoint).kind
	var k: String = str(n.get_meta(&"kind", "swing"))
	if k == "pull" or bool(n.get_meta(&"pull", false)):
		return PULL
	return SWING


static func is_enabled(n: Node) -> bool:
	if n is TetherPoint:
		return (n as TetherPoint).enabled and (n as Node3D).is_visible_in_tree()
	return bool(n.get_meta(&"enabled", true)) and (not (n is Node3D) or (n as Node3D).is_visible_in_tree())


static func land_offset_of(n: Node, fallback: Vector3) -> Vector3:
	if n is TetherPoint:
		return (n as TetherPoint).land_offset
	return LevelKit.v3(n.get_meta(&"land_offset", null), fallback)
