class_name ViewCells
extends Node
## Portal-lite visibility (UPDATE 09 section 5, DECISIONS T-145): which parts of a map can be seen from where the
## camera stands. A map generator splits its static batches into visibility groups (StaticBatches/VisGroup_<g>,
## meta "vis_group") and tags the loose visuals it keeps (lights, labels, decals, particles, spinners) with the
## meta "vis_group" and the persistent node group "view_cell_member"; it then writes `cells`: boxes in the order
## they are tested, each naming the groups visible from inside it. Every frame the first cell holding the active
## camera wins and only its groups are shown; a camera in no cell shows everything (the safe default: a free
## camera, a cutscene, a tool). Group "ALL" (anything outside the generator's group boxes) is never hidden.
## `moon` per cell: false zeroes the map's directional light and its shadow (a roofed room: the moon reaches nothing
## there but its cascades still cost a pass; moon_switch.gd keeps toggling `visible` on its own).
## Presentation only: physics, navigation, AI sight lines and gameplay nodes are never touched.
## Frustum culling cannot do this on Totenhafen: from inside U-1047 looking forward, the frustum covers the north
## hall, the quay, the cannery and the workshop (7242 draw calls in the U09 census, 2.9x the C4 budget).

## [{"name": String, "aabb": AABB, "show": PackedStringArray, "moon": bool}], tested in order.
@export var cells: Array = []
@export var moon_path: NodePath = NodePath("../Moon")

var current_cell: String = "?"
var _members: Dictionary = {}   # group -> Array[Node3D]
var _shown: Dictionary = {}     # group -> bool (what is applied now)
var _moon: DirectionalLight3D = null
var _moon_energy: float = -1.0
var _moon_shadow: bool = false
var _forced: Variant = null     # tests / tools: a fixed position instead of the camera


func _ready() -> void:
	collect.call_deferred()


## Gathers the members (batch holders + tagged loose visuals). Called once after the map is in the tree.
func collect() -> void:
	_members.clear()
	_shown.clear()
	var root: Node = get_parent()
	if root == null:
		return
	var batches: Node = root.get_node_or_null("StaticBatches")
	if batches != null:
		for c: Node in batches.get_children():
			if c.has_meta("vis_group") and c is Node3D:
				_add(str(c.get_meta("vis_group")), c as Node3D)
	for n: Node in get_tree().get_nodes_in_group(&"view_cell_member"):
		if n is Node3D and n.has_meta("vis_group") and root.is_ancestor_of(n):
			_add(str(n.get_meta("vis_group")), n as Node3D)
	for g: String in _members.keys():
		_shown[g] = true
	_moon = root.get_node_or_null(moon_path) as DirectionalLight3D
	if _moon != null:
		_moon_energy = _moon.light_energy
		_moon_shadow = _moon.shadow_enabled
	current_cell = "?"


func _add(g: String, n: Node3D) -> void:
	if g == "ALL" or g == "":
		return
	if not _members.has(g):
		_members[g] = []
	(_members[g] as Array).append(n)


func groups() -> Array:
	return _members.keys()


func members(g: String) -> Array:
	return _members.get(g, [])


## Pins the test position (null: follow the active camera again).
func force_position(p: Variant) -> void:
	_forced = p
	update_now()


func _process(_delta: float) -> void:
	update_now()


func update_now() -> void:
	var p: Variant = _forced
	if p == null:
		var vp: Viewport = get_viewport()
		var cam: Camera3D = vp.get_camera_3d() if vp != null else null
		if cam == null:
			return
		p = cam.global_position
	var cell: Dictionary = cell_at(p as Vector3)
	var name_: String = str(cell.get("name", ""))
	if name_ == current_cell:
		return
	current_cell = name_
	apply(cell)


## The first cell whose box holds `p` ({} when none).
func cell_at(p: Vector3) -> Dictionary:
	for c: Variant in cells:
		var d: Dictionary = c as Dictionary
		var box: AABB = d.get("aabb", AABB())
		if box.has_point(p):
			return d
	return {}


## Shows the cell's groups and hides the rest ({} shows everything and restores the moon).
func apply(cell: Dictionary) -> void:
	var show_all: bool = cell.is_empty()
	var show: PackedStringArray = PackedStringArray(cell.get("show", []))
	for g: String in _members.keys():
		var want: bool = show_all or show.has(g)
		if bool(_shown.get(g, true)) == want:
			continue
		_shown[g] = want
		for n: Variant in _members[g]:
			if is_instance_valid(n):
				(n as Node3D).visible = want
	if _moon != null and _moon_energy >= 0.0:
		var lit: bool = show_all or bool(cell.get("moon", true))
		_moon.light_energy = _moon_energy if lit else 0.0
		_moon.shadow_enabled = _moon_shadow if lit else false


func is_shown(g: String) -> bool:
	return g == "ALL" or bool(_shown.get(g, true))
