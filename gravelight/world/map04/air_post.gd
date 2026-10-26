class_name AirPost
extends Node3D
## An air post in a vacuum zone (UPDATE 07 Map 4 Act IV, docs/MAP4_FERNFLUG.md §6.2, T-112): a survivor within
## `radius` of one breathes from it (Player._update_air refills the AIR gauge as if in pressure). The Solar Flare
## special round fails every post for the round (`set_active(false)`); the Retained state (the renewal ending)
## kills them for good. Greybox: a post with a valve wheel and a blue lamp that goes red when it fails.

@export var radius: float = 2.0
@export var active: bool = true

var _lamp: OmniLight3D
var _wheel: MeshInstance3D


func _ready() -> void:
	add_to_group(&"air_posts")
	_build()


func _build() -> void:
	var post: MeshInstance3D = Interactable.add_box(self, Vector3(0.3, 1.6, 0.3), Vector3(0, 0.8, 0), Mats.get_mat("steel"))
	post.name = "Post"
	var tank: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.22
	cm.bottom_radius = 0.22
	cm.height = 0.9
	tank.mesh = cm
	tank.position = Vector3(0.32, 0.45, 0)
	tank.material_override = Mats.get_mat("brass")
	add_child(tank)
	_wheel = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = 0.12
	tm.outer_radius = 0.18
	_wheel.mesh = tm
	_wheel.position = Vector3(0, 1.72, 0)
	_wheel.material_override = Mats.get_mat("red_paint")
	add_child(_wheel)
	_lamp = OmniLight3D.new()
	_lamp.position = Vector3(0, 1.95, 0)
	_lamp.omni_range = radius * 3.0
	_lamp.shadow_enabled = false
	_lamp.light_volumetric_fog_energy = 0.4
	add_child(_lamp)
	var glass: MeshInstance3D = Interactable.add_box(self, Vector3(0.16, 0.16, 0.16), Vector3(0, 1.95, 0), Interactable.greybox_mat(Color(0.5, 0.8, 1.0), 4.0))
	glass.name = "Glass"
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring: MeshInstance3D = MeshInstance3D.new()
	var rm: CylinderMesh = CylinderMesh.new()
	rm.top_radius = radius
	rm.bottom_radius = radius
	rm.height = 0.03
	ring.mesh = rm
	ring.position.y = 0.02
	ring.material_override = Mats.get_mat("lumi_paint")
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.name = "Ring"
	add_child(ring)
	_refresh()


func _refresh() -> void:
	if _lamp == null:
		return
	_lamp.light_color = Color(0.45, 0.75, 1.0) if active else Color(1.0, 0.2, 0.1)
	_lamp.light_energy = 2.2 if active else 1.2
	var glass: MeshInstance3D = get_node_or_null("Glass") as MeshInstance3D
	if glass != null:
		glass.material_override = Interactable.greybox_mat(Color(0.5, 0.8, 1.0) if active else Color(1.0, 0.25, 0.15), 4.0)
	var ring: Node3D = get_node_or_null("Ring") as Node3D
	if ring != null:
		ring.visible = active


func set_active(on: bool) -> void:
	if active == on:
		return
	active = on
	_refresh()
	if on:
		AudioDirector.play_3d("door_open", global_position + Vector3.UP, -8.0, 0.1)
	else:
		AudioDirector.play_3d("board_slam", global_position + Vector3.UP, -6.0, 0.3)


## True when `p` stands within `r` (or the post's own radius) of a working post.
static func near(tree: SceneTree, p: Vector3, r: float = -1.0) -> bool:
	for n: Node in tree.get_nodes_in_group(&"air_posts"):
		var a: AirPost = n as AirPost
		if a == null or not a.active:
			continue
		var rr: float = r if r > 0.0 else a.radius
		var d: Vector3 = p - a.global_position
		if Vector2(d.x, d.z).length() <= rr and absf(d.y) < 2.5:
			return true
	return false


static func set_all(tree: SceneTree, on: bool) -> void:
	for n: Node in tree.get_nodes_in_group(&"air_posts"):
		var a: AirPost = n as AirPost
		if a != null:
			a.set_active(on)


static func count_active(tree: SceneTree) -> int:
	var c: int = 0
	for n: Node in tree.get_nodes_in_group(&"air_posts"):
		var a: AirPost = n as AirPost
		if a != null and a.active:
			c += 1
	return c
