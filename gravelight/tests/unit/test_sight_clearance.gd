extends GutTest
## No part of a downloaded or wonder-weapon model rises above its sight line near the bore (the user saw the
## M1 Garand's en-bloc clip sticking up over the sights). SightClearance.blocked is the measurement; the sights'
## own ears/posts are left out and scoped guns look through the tube.


func test_no_part_blocks_the_sight_line() -> void:
	var checked: int = 0
	for id: Variant in (GLData.table("weapons")["weapons"] as Dictionary).keys():
		if not WeaponGLB.wants(StringName(str(id))):
			continue
		for up: bool in [false, true]:
			var m: Node3D = WeaponModels.build(StringName(str(id)), up)
			add_child(m)
			var hits: Array = SightClearance.blocked(m)
			assert_eq(hits.size(), 0, "%s%s: %s" % [str(id), "_up" if up else "", ", ".join(hits)])
			checked += 1
			m.free()
	assert_gt(checked, 30, "every GLB weapon checked (%d models)" % checked)


func test_the_measurement_catches_a_raised_part() -> void:
	var m: Node3D = WeaponModels.build(&"m1_garand")
	add_child(m)
	var clip: Node3D = m.find_child("Mag", true, false) as Node3D
	assert_not_null(clip, "the Garand has its clip as Mag")
	clip.position.y += 0.02
	assert_gt(SightClearance.blocked(m).size(), 0, "a clip lifted 2 cm is reported")
	m.free()
