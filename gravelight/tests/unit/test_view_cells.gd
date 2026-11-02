extends GutTest
## ViewCells (UPDATE 09 section 5, T-145): the first cell holding the camera wins, its groups show and the others
## hide (batch holders and tagged loose visuals alike), "ALL" never hides, outside every cell everything shows, the
## moon goes dark in a roofed cell and comes back; and Totenhafen's generated scene carries the node with cells that
## only name groups the scene has, every light with a zone meta.

const SCENE: String = "res://gravelight/maps/map02_totenhafen/map02.tscn"

var _root: Node3D
var _vc: ViewCells
var _a: Node3D
var _e: Node3D
var _lamp: OmniLight3D
var _moon: DirectionalLight3D


func before_each() -> void:
	_root = Node3D.new()
	add_child_autofree(_root)
	var sb: Node3D = Node3D.new()
	sb.name = "StaticBatches"
	_root.add_child(sb)
	_a = Node3D.new()
	_a.name = "VisGroup_A"
	_a.set_meta("vis_group", "A")
	sb.add_child(_a)
	_e = Node3D.new()
	_e.name = "VisGroup_E"
	_e.set_meta("vis_group", "E")
	sb.add_child(_e)
	var all: Node3D = Node3D.new()
	all.name = "VisGroup_ALL"
	all.set_meta("vis_group", "ALL")
	sb.add_child(all)
	_lamp = OmniLight3D.new()
	_lamp.set_meta("vis_group", "E")
	_lamp.add_to_group(&"view_cell_member")
	_root.add_child(_lamp)
	_moon = DirectionalLight3D.new()
	_moon.name = "Moon"
	_moon.light_energy = 0.75
	_moon.shadow_enabled = true
	_root.add_child(_moon)
	_vc = ViewCells.new()
	_vc.cells = [
		{"name": "inside", "aabb": AABB(Vector3(0, 0, 0), Vector3(10, 4, 10)), "show": PackedStringArray(["E"]), "moon": false},
		{"name": "outside", "aabb": AABB(Vector3(-50, -5, -50), Vector3(100, 20, 100)), "show": PackedStringArray(["A"]), "moon": true},
	]
	_root.add_child(_vc)
	_vc.collect()
	_vc.set_process(false)


func test_collects_holders_and_tagged_visuals_but_never_all() -> void:
	assert_eq(_vc.members("A").size(), 1)
	assert_eq(_vc.members("E").size(), 2, "the E holder and the tagged lamp")
	assert_false(_vc.groups().has("ALL"))


func test_first_cell_wins_and_hides_the_rest() -> void:
	_vc.force_position(Vector3(5, 1, 5))   # inside both boxes: the first one wins
	assert_eq(_vc.current_cell, "inside")
	assert_true(_e.visible and _lamp.visible)
	assert_false(_a.visible)
	assert_almost_eq(_moon.light_energy, 0.0, 0.001, "the moon is dark in a roofed cell")
	assert_false(_moon.shadow_enabled)
	_vc.force_position(Vector3(30, 1, 30))
	assert_eq(_vc.current_cell, "outside")
	assert_true(_a.visible)
	assert_false(_e.visible or _lamp.visible)
	assert_almost_eq(_moon.light_energy, 0.75, 0.001, "the moon is back")
	assert_true(_moon.shadow_enabled)


func test_outside_every_cell_shows_everything() -> void:
	_vc.force_position(Vector3(5, 1, 5))
	_vc.force_position(Vector3(500, 0, 500))
	assert_eq(_vc.current_cell, "")
	assert_true(_a.visible and _e.visible and _lamp.visible)
	assert_true(_vc.is_shown("ALL"))


func test_map02_scene_has_view_cells_naming_real_groups_and_zoned_lights() -> void:
	var map: Node = (load(SCENE) as PackedScene).instantiate()
	var vc: Node = map.get_node_or_null("ViewCells")
	assert_not_null(vc, "Totenhafen has a ViewCells node")
	var have: Dictionary = {"ALL": true}
	var sb: Node = map.get_node("StaticBatches")
	for c: Node in sb.get_children():
		assert_true(c.has_meta("vis_group"), "%s is a visibility group holder" % c.name)
		have[str(c.get_meta("vis_group"))] = true
	for n: Node in map.find_children("*", "Node3D", true, false):
		if n.is_in_group(&"view_cell_member"):
			have[str(n.get_meta("vis_group"))] = true
	for g: String in ["A", "B", "C", "D", "DH", "E", "F", "G"]:
		assert_true(have.has(g), "group %s exists in the scene" % g)
	for cell: Dictionary in vc.get("cells"):
		for g2: String in PackedStringArray(cell["show"]):
			assert_true(have.has(g2), "cell %s names group %s" % [cell["name"], g2])
	# the boat's interior cell sees only the boat and the hatch's column of the hall
	var e_in: Dictionary = (vc.get("cells") as Array)[0]
	assert_eq(str(e_in["name"]), "E_interior")
	assert_false(PackedStringArray(e_in["show"]).has("A"), "the quay is not drawn from inside U-1047")
	var shadowed_by_zone: Dictionary = {}
	for l: Node in map.find_children("*", "Light3D", true, false):
		if l is DirectionalLight3D:
			continue
		assert_true(l.has_meta("zone"), "%s has a zone meta" % l.name)
		if (l as Light3D).shadow_enabled:
			var z: String = str(l.get_meta("zone", ""))
			shadowed_by_zone[z] = int(shadowed_by_zone.get(z, 0)) + 1
	for z2: String in shadowed_by_zone.keys():
		assert_true(int(shadowed_by_zone[z2]) <= 6, "C4: %s has %d shadowed lights (<= 6)" % [z2, shadowed_by_zone[z2]])
	map.free()
