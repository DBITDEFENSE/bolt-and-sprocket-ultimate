class_name HomageArm
extends Node3D
## A stretchable arm segment for the homage bosses (HB1): a sleeve-and-skin cylinder from an anchor (a bone
## attachment on the boss) to a tip point in the world, with a hand at the tip and an optional weak-point Hitbox
## there. The Reach's Long Reach (the telescoped forearm shooting out to 12 m, the wrist weak point), her
## Through-the-Wall punch, and Alix's Third Hand (the small hand from the breastbone, the palm weak point) are all
## one of these. Presentation + the hitbox only; the boss owns the gameplay.

var anchor: Node3D
var tip: Vector3 = Vector3.ZERO
var hitbox: Hitbox
var glow: OmniLight3D
var hand_mi: MeshInstance3D
var reach_on: bool = false      # the weak point is live (hitbox on the hitbox layer)
var follow_anchor: bool = true  # the arm starts at the anchor (false: a free column, e.g. through the floor)
var from_point: Vector3 = Vector3.ZERO

var _seg: MeshInstance3D
var _radius: float = 0.05


## owner_boss: the Zombie the hitbox reports to. limb: the hitbox limb (&"wrist", &"palm"). Colours: sleeve / skin.
func setup(owner_boss: Zombie, anchor_node: Node3D, limb: StringName, sleeve: Color, skin: Color, radius: float = 0.05,
		hand_size: float = 0.07, glow_color: Color = Color(0.7, 0.35, 1.0)) -> void:
	anchor = anchor_node
	_radius = radius
	top_level = true
	var seg_mesh: CylinderMesh = CylinderMesh.new()
	seg_mesh.top_radius = radius
	seg_mesh.bottom_radius = radius * 0.85
	seg_mesh.height = 1.0
	seg_mesh.radial_segments = 8
	seg_mesh.rings = 1
	_seg = MeshInstance3D.new()
	_seg.mesh = seg_mesh
	_seg.material_override = HomageBoss.mat(sleeve)
	_seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_seg)
	hand_mi = MeshInstance3D.new()
	var hs: SphereMesh = SphereMesh.new()
	hs.radius = hand_size
	hs.height = hand_size * 2.0
	hs.radial_segments = 8
	hs.rings = 4
	hand_mi.mesh = hs
	hand_mi.material_override = HomageBoss.mat(skin)
	add_child(hand_mi)
	hitbox = Hitbox.new()
	hitbox.setup(owner_boss, limb, Vector3.ONE * maxf(0.28, hand_size * 4.0))
	hitbox.collision_layer = 0
	hand_mi.add_child(hitbox)
	glow = OmniLight3D.new()
	glow.light_color = glow_color
	glow.omni_range = 2.5
	glow.light_energy = 0.0
	glow.shadow_enabled = false
	hand_mi.add_child(glow)


func set_reach_on(on: bool) -> void:
	reach_on = on
	if hitbox != null:
		hitbox.collision_layer = Hitbox.LAYER_HITBOX if on and visible else 0


func start_point() -> Vector3:
	if follow_anchor and anchor != null and anchor.is_inside_tree():
		return anchor.global_position
	return from_point


func length() -> float:
	return start_point().distance_to(tip)


func _process(_delta: float) -> void:
	if not visible:
		return
	refresh()


## Lays the segment between the start and the tip (called every frame while visible).
func refresh() -> void:
	var a: Vector3 = start_point()
	var d: Vector3 = tip - a
	var ln: float = d.length()
	global_transform = Transform3D(Basis.IDENTITY, a)
	if ln < 0.01:
		_seg.visible = false
		hand_mi.position = Vector3.ZERO
		return
	_seg.visible = true
	var y: Vector3 = d / ln
	var x: Vector3 = y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
	var z: Vector3 = x.cross(y).normalized()
	_seg.transform = Transform3D(Basis(x, y * ln, z), d * 0.5)
	hand_mi.position = d
