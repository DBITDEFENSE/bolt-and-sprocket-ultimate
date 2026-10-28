extends GutTest
## T-126: GRAVELIGHT ONE's trapped pilot (TrappedPilot) and the hollow wreck. The pure rules (which guns he takes,
## his rate of fire), his data and lines, and the hull's numbers (he sees over the windscreen's sill, nobody jumps
## it, the walk-in openings clear a standing agent). The live run (navmesh into the cabin, his kills, ammo) is
## smoke_wreck_pilot.

const GEN: Script = preload("res://gravelight/tools_src/gen_map00.gd")
const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const CATEGORIES: Array = ["CALL", "GIVEN", "SWAP", "THANKS_AMMO", "DRY", "KILL"]


func _row(id: String) -> Dictionary:
	return GLData.table("weapons")["weapons"][id]


func test_gift_rules() -> void:
	var refused: Array = TrappedPilot.load_cfg().get("refused_classes", [])
	assert_eq(TrappedPilot.gift_rule(1, _row("m1_garand"), refused), "only_gun", "never your only gun")
	assert_eq(TrappedPilot.gift_rule(0, _row("m1_garand"), refused), "empty")
	assert_eq(TrappedPilot.gift_rule(2, _row("m1_garand"), refused), "", "a second rifle: yes")
	assert_eq(TrappedPilot.gift_rule(3, _row("mg42"), refused), "", "a machine gun: yes")
	assert_eq(TrappedPilot.gift_rule(2, _row("ashlight"), refused), "refused", "never a wonder weapon")
	assert_eq(TrappedPilot.gift_rule(2, _row("panzerschreck"), refused), "refused", "no launcher from a pinned seat")
	assert_eq(TrappedPilot.gift_rule(2, _row("flamethrower"), refused), "refused", "no flamethrower in a cockpit")


func test_rate_of_fire() -> void:
	assert_almost_eq(TrappedPilot.rate_for(300.0, 0.7, 550.0), 210.0, 0.01)
	assert_almost_eq(TrappedPilot.rate_for(1200.0, 0.7, 550.0), 550.0, 0.01, "an MG42 is capped")
	assert_gt(TrappedPilot.rate_for(0.0, 0.7, 550.0), 0.0, "never zero")


func test_his_lines_exist_and_are_voiced() -> void:
	for cat: String in CATEGORIES:
		var n: int = 0
		for id: String in GLVO.lines.keys():
			var rec: Dictionary = GLVO.lines[id]
			if str(rec.get("speaker", "")) == "SEL" and str(rec.get("category", "")) == cat:
				n += 1
				assert_ne(GLVO.audio_path(StringName(id)), "", "%s has its baked audio" % id)
		assert_gt(n, 0, "Selwyn has %s lines" % cat)
		assert_true((TrappedPilot.load_cfg().get("line_cooldown_s", {}) as Dictionary).has(cat), "%s has a cooldown" % cat)


## The windscreen's sill is under his eye (he shoots out over it) and over a standing jump (nobody climbs in).
func test_the_windscreen_sill() -> void:
	var eye: float = GEN.WRECK_PILOT_SEAT.y + float(TrappedPilot.load_cfg().get("eye_y", 1.3))
	assert_gt(eye, GEN.WRECK_SCREEN + 0.15, "his eye clears the sill")
	var mv: Dictionary = GLData.table("player")
	var apex: float = pow(float(mv.get("jump_velocity", 4.2)), 2.0) / (2.0 * Player.GRAVITY)   # the capsule's rise
	assert_gt(GEN.WRECK_SCREEN * cos(deg_to_rad(8.0)), apex + 0.3, "a jump from the snow doesn't reach the windscreen's sill")
	for o: Array in GEN.WRECK_OPENINGS:
		if int(o[0]) == 0:
			continue   # the windscreen, across the nose's centre line: checked above
		if float(o[3]) > GEN.WRECK_FLOOR:   # a window: its sill, at the low starboard side, still over a jump
			var world_sill: float = float(o[3]) * cos(deg_to_rad(8.0)) - absf(GEN.WRECK_HALF) * sin(deg_to_rad(8.0))
			assert_gt(world_sill, apex + 0.3, "the window at z %.1f is out of a jump's reach" % float(o[1]))
		else:   # a way in: tall enough for the navmesh agent (1.75 m) on the rolled hull
			assert_gte(float(o[4]) - float(o[3]), 2.0, "the opening at z %.1f clears a standing agent" % float(o[1]))


func test_he_is_in_the_cockpit() -> void:
	var map: Node = (load(MAP) as PackedScene).instantiate()
	var p: Node3D = map.find_child("TrappedPilot", true, false) as Node3D
	assert_not_null(p, "the map has him")
	if p != null:
		var want: Transform3D = GEN.wreck_xf() * Transform3D(Basis.IDENTITY, GEN.WRECK_PILOT_SEAT)
		assert_lt(p.transform.origin.distance_to(want.origin), 0.01, "he sits in the left seat")
		assert_true(p.get_script() == load("res://gravelight/world/trapped_pilot.gd"))
	map.free()
