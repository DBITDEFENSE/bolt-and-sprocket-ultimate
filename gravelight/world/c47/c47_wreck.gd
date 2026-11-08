class_name C47Wreck
extends Node3D
## UPDATE 12 section 5 (T-211): GRAVELIGHT ONE on Map 0. gen_map00 places this node at the wreck's SITE frame (its
## position and yaw; the model rolls itself) and nothing else: at load it draws whichever C-47 is built (C47Art: the
## real model once the owner's download is built, else our stand-in), and the life round it from
## data/gravelight/c47_wreck.json `fx`: the fuel fire (Props.flames), its heat haze, sparks, the smoke drifting east
## on the map's wind (Props.smoke), and the hull's metal groaning as it cools (`wreck_c47_creak`, at random points,
## every creak_gap_s). Visual and sound only: the colliders are gen_map00's.

const HAZE: Shader = preload("res://gravelight/world/c47/heat_haze.gdshader")

var model: Node3D
var _creak_t: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _creaks: Array = []
var _gap: Vector2 = Vector2(5.0, 13.0)


func _ready() -> void:
	_rng.seed = 2312
	model = C47Art.instance("crashed")
	if model != null:
		add_child(model)
	var fx: Dictionary = C47Art.layout().get("fx", {})
	for f: Variant in fx.get("fires", []):
		var a: Array = f
		Props.flames(self, _v(a[0]), float(a[1]), float(a[2]), int(a[3]))
	for s: Variant in fx.get("sparks", []):
		var a2: Array = s
		Props.embers(self, _v(a2[0]), float(a2[1]), 28)
	for k: Variant in fx.get("smoke", []):
		var a3: Array = k
		Props.smoke(self, _v(a3[0]), float(a3[1]), float(a3[2]), int(a3[3]))
	for h: Variant in fx.get("haze", []):
		var a4: Array = h
		add_child(haze_card(_v(a4[0]), Vector2(float(a4[1][0]), float(a4[1][1]))))
	_creaks = fx.get("creaks", [])
	var g: Array = fx.get("creak_gap_s", [5.0, 13.0])
	_gap = Vector2(float(g[0]), float(g[1]))
	_creak_t = _rng.randf_range(_gap.x, _gap.y)


static func _v(a: Variant) -> Vector3:
	var arr: Array = a
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))


## A camera-facing card that ripples what is behind it over the fire.
static func haze_card(pos: Vector3, size: Vector2) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "HeatHaze"
	var q: QuadMesh = QuadMesh.new()
	q.size = size
	mi.mesh = q
	var sm: ShaderMaterial = ShaderMaterial.new()
	sm.shader = HAZE
	mi.material_override = sm
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 45.0
	return mi


func _process(delta: float) -> void:
	if _creaks.is_empty():
		return
	_creak_t -= delta
	if _creak_t > 0.0:
		return
	_creak_t = _rng.randf_range(_gap.x, _gap.y)
	var p: Vector3 = global_transform * _v(_creaks[_rng.randi() % _creaks.size()])
	var ad: Node = get_node_or_null("/root/AudioDirector")
	if ad != null and ad.has_method("play_3d"):
		ad.call("play_3d", "wreck_c47_creak", p, -3.0)
