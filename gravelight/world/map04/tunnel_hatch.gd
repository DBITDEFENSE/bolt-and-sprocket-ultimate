class_name TunnelHatch
extends Node3D
## The wind tunnel's plenum hatch in the wall between the Windkanal (F) and Montage 2 (E) (UPDATE 10 Act I,
## contract C6 `wind_tunnel`, DECISIONS T-155): a steel pressure hatch that the fan's draft sucks open while the
## tunnel runs, a shortcut between F and E for 20 s. The generator leaves a gap in the wall with a plug collider
## (`plug_name`, on the world layer, so the navmesh was baked shut) and a disabled NavigationLink (`link_path`);
## opening drops the plug's collider and enables the link (the bots path through it), closing restores both. The
## WindTunnel drives it (set_open / rattle); the host mirrors it. Flag `tunnel_hatch_open` while open.
## The same node is the Siedlung cellar's side door (hinge "side", flag a1_cellar_side_open, opened for good by Erich
## Wendel's favour): any wall passage that a plug and a NavigationLink stand for.

@export var plug_name: String = "TunnelHatchPlug"
@export var link_path: NodePath = NodePath("../../Navigation/Link_TunnelHatch")
@export var width: float = 1.6
@export var height: float = 2.0
## "top": a pressure hatch that swings up into the plenum (+X); "side": a door hung on its -Z edge, swinging into +X.
@export var hinge: String = "top"
@export var plate_text: String = "DRUCKKLAPPE\nNICHT ÖFFNEN"
@export var flag_name: StringName = &"tunnel_hatch_open"
@export var leaf_key: String = "machine_grey"

var is_open: bool = false
var _leaf: Node3D
var _plug: CollisionObject3D


func _ready() -> void:
	add_to_group(&"a1_tunnel_hatch" if hinge == "top" else &"a1_passages")
	_build()
	(func() -> void:
		var root: Node = get_parent().get_parent() if get_parent() != null else null
		if root != null:
			_plug = root.find_child(plug_name, true, false) as CollisionObject3D
		_apply(false, true)).call_deferred()


func _build() -> void:
	# the frame on both faces and the hatch leaf (a riveted plate that hinges up into the plenum, +X side)
	for side: float in [-0.2, 0.2]:
		Props.obox(self, Vector3(side, height + 0.08, 0), Vector3(0.12, 0.16, width + 0.3), "steel")
		for e: float in [-1.0, 1.0]:
			Props.obox(self, Vector3(side, height * 0.5, e * (width * 0.5 + 0.07)), Vector3(0.12, height, 0.14), "steel")
	var pivot: Node3D = Node3D.new()
	pivot.name = "Leaf"
	add_child(pivot)
	# the leaf's centre relative to its hinge line
	var c: Vector3 = Vector3(0, -height * 0.5, 0)
	if hinge == "side":
		pivot.position = Vector3(0.0, 0.0, -width * 0.5)
		c = Vector3(0, height * 0.5, width * 0.5)
	else:
		pivot.position = Vector3(0.0, height, 0)
	Props.obox(pivot, c, Vector3(0.06, height - 0.04, width - 0.04), leaf_key)
	for r: int in 5:
		Props.obox(pivot, c + Vector3(0.04, height * 0.5 - 0.15 - float(r) * (height - 0.3) / 4.0, 0), Vector3(0.03, 0.03, width - 0.2), "iron")
	Props.obox(pivot, c + Vector3(-0.06, -height * 0.05, width * 0.3), Vector3(0.05, 0.25, 0.08), "brass")
	var plate: Label3D = Label3D.new()
	plate.text = plate_text
	plate.font_size = 22
	plate.pixel_size = 0.004
	plate.modulate = Color(0.9, 0.85, 0.7)
	plate.position = c + Vector3(-0.05, height * 0.5 - 0.55, 0)
	plate.rotation.y = -PI * 0.5
	pivot.add_child(plate)
	_leaf = pivot
	for gi: Node in find_children("*", "GeometryInstance3D", true, false):
		(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ThalbachLife.merge(pivot)


func set_open(v: bool) -> void:
	if v == is_open:
		return
	_apply(v, false)
	if Net.is_authority():
		Net.mirror(self, &"_net_set", [v])


func _net_set(v: bool) -> void:
	_apply(v, false)


func rattle() -> void:
	if _leaf == null:
		return
	var tw: Tween = create_tween()
	for i: int in 4:
		tw.tween_property(_leaf, "rotation:z", deg_to_rad(6.0), 0.06)
		tw.tween_property(_leaf, "rotation:z", 0.0, 0.06)
	AudioDirector.play_3d("lamp_knock", global_position + Vector3.UP * 1.2, 2.0, 0.1)


func _apply(v: bool, instant: bool) -> void:
	is_open = v
	if _plug != null:
		_plug.collision_layer = 0 if v else 1
	var link: NavigationLink3D = get_node_or_null(link_path) as NavigationLink3D
	if link != null:
		link.enabled = v
	if Net.is_authority():
		GameState.set_flag(flag_name, v)
	if _leaf != null:
		# the hatch swings up into the plenum (+X), the way the draft pulls it; a side door swings into +X too
		var prop: String = "rotation:z" if hinge == "top" else "rotation:y"
		var target: float = (deg_to_rad(100.0) if hinge == "top" else deg_to_rad(95.0)) if v else 0.0
		if instant:
			_leaf.rotation = Vector3(0, 0, target) if hinge == "top" else Vector3(0, target, 0)
		else:
			var tw: Tween = create_tween()
			tw.tween_property(_leaf, prop, target, 0.5 if v else 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			AudioDirector.play_3d("door_open" if v else "board_slam", global_position + Vector3.UP * 1.2, 2.0, 0.05)
