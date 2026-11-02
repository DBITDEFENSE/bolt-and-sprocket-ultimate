extends "res://gravelight/tools_src/smoke_act2_lib.gd"
## UPDATE 10 §3 (T-156): turbulence you can use (`turbulence_tilt`), headless. The flight clock schedules 2-3 tilts
## for an act round and warns 3 s ahead; a tilt rolls the camera up to 8°, pushes the player downhill (less than the
## dead), slides the loose cargo; a ganger slides into the bay's wall and dies of the impact; a rolling bomb casing
## runs a ganger over; the tilt ends level.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_turbulence.tscn


func _init() -> void:
	tag = "turbulence"


func _body() -> void:
	var tilt: Dictionary = _fc.cfg.get("turbulence_tilt", {})
	_check(not tilt.is_empty(), "map04b.json has the turbulence_tilt block")
	# the flight clock
	_fc._schedule_flight_clock(2)
	_check(_fc.tilt_times.size() >= 2 and _fc.tilt_times.size() <= 3, "the flight clock schedules 2-3 tilts this round (%d)" % _fc.tilt_times.size())
	var first: float = _fc.tilt_times[0] if not _fc.tilt_times.is_empty() else 0.0
	_fc.round_clock = first - 3.2
	await _frames(20)
	_check(_fc.turb_warned and not _fc.banking, "the Bordfunk warns ahead of the tilt")
	_fc.tilt_times.clear()

	# a ganger slides into the starboard wall and dies; a casing runs one over
	await _tp(Vector3(-4.0, 0, 2.0), 90.0)
	var hp_low: float = 60.0
	var wall_z: Zombie = await _zombie_on(Vector3(5.5, 0, 9.0), hp_low)
	var bomb_z: Zombie = await _zombie_on(Vector3(4.6, 0, 15.0))
	_check(wall_z != null and bomb_z != null, "two gangers in the bay")
	if bomb_z != null:
		bomb_z.set_physics_process(false)   # it stands in the casing's path
	if wall_z != null:
		wall_z.set_physics_process(false)   # held where it stands until the floor tilts (it would walk to the player)
	var bomb: TiltSlider = _g("Slider3_bomb") as TiltSlider
	var crate: TiltSlider = _g("Slider5_crate") as TiltSlider
	var bomb_x0: float = bomb.global_position.x if bomb != null else 0.0
	var crate_x0: float = crate.global_position.x if crate != null else 0.0
	var p_x0: float = _p.global_position.x
	_fc.bank_side = -1.0   # bank_now flips it: starboard goes down
	_fc.bank_now()
	if wall_z != null:
		wall_z.global_position = Vector3(5.5, 0, 9.0)
		wall_z.set_physics_process(true)
	await _secs(2.0)
	_check(_fc.banking and absf(_p.ext_roll_deg) > 6.0, "the floor tilts: the camera rolls %.1f°" % _p.ext_roll_deg)
	_check(_p.global_position.x > p_x0 + 0.5, "the player is pushed downhill (%.1f -> %.1f)" % [p_x0, _p.global_position.x])
	for i: int in 6:
		await _secs(0.5)
		if wall_z != null:
			print("[turbulence]   wall ganger %s hp %.0f state %d pushed %s" % [str(wall_z.global_position.snapped(Vector3.ONE * 0.1)), wall_z.hp, wall_z.state, str(wall_z.is_pushed())])
	_check(bomb != null and bomb.global_position.x > bomb_x0 + 1.0, "the bomb casing rolls downhill (%.1f -> %.1f)" % [bomb_x0, bomb.global_position.x if bomb != null else 0.0])
	_check(crate != null and crate.global_position.x > crate_x0 + 0.3, "the crate slides (%.1f -> %.1f)" % [crate_x0, crate.global_position.x if crate != null else 0.0])
	_check(_fc.tilt_impacts >= 1 and wall_z != null and not wall_z.is_active(), "a ganger slides into the wall and dies of it (impacts %d)" % _fc.tilt_impacts)
	_check(_fc.tilt_bomb_kills >= 1 and bomb_z != null and not bomb_z.is_active(), "the rolling casing kills the ganger in its path (%d)" % _fc.tilt_bomb_kills)
	await _until(func() -> bool: return not _fc.banking, 6.0)
	await _frames(5)
	_check(not _fc.banking and _p.ext_roll_deg == 0.0 and is_equal_approx(_fc.tilt_angle_now(), 0.0), "the tilt ends level")
	var bx: float = bomb.global_position.x if bomb != null else 0.0
	await _secs(1.0)
	_check(bomb == null or absf(bomb.global_position.x - bx) < 0.05, "level again, the loose cargo stays where it stopped")
	_check(_fc.tilts_done >= 1, "tilts counted (%d)" % _fc.tilts_done)
