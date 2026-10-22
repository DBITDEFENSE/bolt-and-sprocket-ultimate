extends GutTest
## Update 02 follow-up fixes (T-057): the lamp-glass binding and the fog-portal window check.


func test_glass_is_told_by_its_look() -> void:
	var ref: Material = Mats.get_mat("lantern_glass")
	var copy: StandardMaterial3D = (ref as StandardMaterial3D).duplicate() as StandardMaterial3D
	assert_true(LampGlow._is_glass(copy, ref), "a saved copy of the glass is glass")
	assert_false(LampGlow._is_glass(Mats.get_mat("fire"), ref), "fire isn't")
	assert_false(LampGlow._is_glass(Mats.get_mat("iron"), ref), "iron isn't")


func test_a_dim_light_beside_the_lamp_is_not_an_owner() -> void:
	var lamp: OmniLight3D = autofree(OmniLight3D.new())
	var dial: OmniLight3D = autofree(OmniLight3D.new())
	var far: OmniLight3D = autofree(OmniLight3D.new())
	add_child(lamp)
	add_child(dial)
	add_child(far)
	lamp.global_position = Vector3(5.0, 2.4, 4.5)
	dial.global_position = Vector3(5.15, 2.25, 4.8)
	far.global_position = Vector3(9.0, 2.4, 4.5)
	var lights: Array = [[lamp, 1.7], [dial, 0.35], [far, 2.0]]
	var owners: Array = LampGlow._owners_near(lights, AABB(Vector3(4.6, 2.4, 4.4), Vector3(0.2, 0.2, 0.2)), LampGlow.RADIUS)
	assert_eq(owners.size(), 1)
	assert_eq(owners[0][0], lamp, "the lamp owns its glass; the radio dial beside it doesn't")


func test_glass_follows_its_light() -> void:
	var root: Node3D = autofree(Node3D.new())
	add_child(root)
	var l: OmniLight3D = OmniLight3D.new()
	l.set_script(load("res://gravelight/world/flicker_light.gd"))
	l.set("base_energy", 2.0)
	root.add_child(l)
	var mi: MeshInstance3D = Props.block(root, Vector3(-0.1, -0.1, -0.1), Vector3(0.1, 0.1, 0.1), "lantern_glass")
	var g: LampGlow = LampGlow.attach(root)
	assert_eq(g.bound_count(), 1)
	var base: float = (mi.material_override as StandardMaterial3D).emission_energy_multiplier
	l.set("base_energy", 0.0)
	g._process(0.016)
	assert_almost_eq((mi.material_override as StandardMaterial3D).emission_energy_multiplier, 0.0, 0.001, "dark with the light")
	l.set("base_energy", 2.0)
	g._process(0.016)
	assert_almost_eq((mi.material_override as StandardMaterial3D).emission_energy_multiplier, base, 0.001, "lit again")
	assert_ne(mi.material_override, Mats.get_mat("lantern_glass"), "its own copy: the shared glass is untouched")


func test_a_path_through_a_window_is_seen() -> void:
	var b: Barricade = autofree(Barricade.new())
	add_child(b)
	b.global_position = Vector3(0, 0, 0)   # facing +z: outside is -z
	var through: PackedVector3Array = [Vector3(0.2, 0, -3), Vector3(0.1, 0, 3)]
	var beside: PackedVector3Array = [Vector3(3, 0, -3), Vector3(3, 0, 3)]
	var along: PackedVector3Array = [Vector3(-2, 0, 1), Vector3(2, 0, 1)]
	assert_true(ZombieDirector.window_crossed(b, through))
	assert_false(ZombieDirector.window_crossed(b, beside), "past the jambs")
	assert_false(ZombieDirector.window_crossed(b, along), "never crosses the plane")
