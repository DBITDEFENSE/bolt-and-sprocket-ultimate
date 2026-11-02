extends "res://gravelight/tools_src/smoke_act2_lib.gd"
## UPDATE 10 §3 (T-156): decompression, headless. The flight clock queues the bay's breach on act round 2 and the
## starboard crawlway's on act round 5; the bay breach warns (3 s), then pulls for 4 s: a ganger is pulled out into
## the night (a kill), the ammo drops land in the bay and refill the gun of the player who walks over one; a player
## holding a rail is not moved; a player who does not hold on is pulled to the edge and downed (solo: up again, the
## match goes on); the breach holds again after.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_decompression.tscn


func _init() -> void:
	tag = "decomp"


func _body() -> void:
	var bay: DecompressionBreach = _g("DecompBay") as DecompressionBreach
	var stb: DecompressionBreach = _g("DecompStarboard") as DecompressionBreach
	_check(bay != null and stb != null, "two decompression breaches (the bay's ramp seam, the starboard crawlway)")
	if bay == null:
		return
	_fc._schedule_flight_clock(2)
	_check(_fc.decomp_queue.size() == 1 and (_fc.decomp_queue[0]["node"] as Node) == bay, "act round 2 queues the bay's breach")
	_fc._schedule_flight_clock(5)
	_check(_fc.decomp_queue.size() == 1 and (_fc.decomp_queue[0]["node"] as Node) == stb, "act round 5 queues the starboard crawlway's")
	_fc.decomp_queue.clear()

	# a ganger near the seam, the player holding a rail, the gun half empty
	var z: Zombie = await _zombie_on(Vector3(1.5, 0, 4.5))
	_check(z != null, "a ganger near the ramp seam")
	await _tp(Vector3(-7.9, 0, 3.0), -90.0)
	var grip: RailGrip = _g("GripBay1") as RailGrip
	var w: WeaponInstance = _p.weapons.current()
	w.reserve = 0
	_fc.decomp_queue = [{"t": 0.0, "node": bay}]
	_fc.round_clock = 1.0
	await _frames(3)
	_check(bay.phase == DecompressionBreach.Phase.WARN, "the breach warns first")
	_check(grip.get_prompt(_p).contains("rail"), "the rail offers a hold while it warns")
	grip.hold(_p, true)   # the player holds on (what the hold in progress tells the rail)
	var pos0: Vector3 = _p.global_position
	await _until(func() -> bool: return bay.phase == DecompressionBreach.Phase.PULL, 4.0)
	_check(bay.phase == DecompressionBreach.Phase.PULL, "then it pulls")
	for i: int in 6:
		await _secs(0.25)
		if z != null:
			print("[decomp]   ganger %s hp %.0f state %d pushed %s active %s" % [str(z.global_position.snapped(Vector3.ONE * 0.1)), z.hp, z.state, str(z.is_pushed()), str(z.is_active())])
	_check(_p.global_position.distance_to(pos0) < 0.4 and not _p.downed, "holding the rail, the player is not moved")
	_check(get_tree().get_nodes_in_group(&"ammo_drops").size() == 2, "the stowage net drops two ammo tins in the bay")
	await _until(func() -> bool: return bay.phase == DecompressionBreach.Phase.DONE, 5.0)
	_check(bay.sucked_out >= 1 and z != null and not z.is_active(), "the ganger is pulled out into the night (%d)" % bay.sucked_out)
	grip.hold(_p, false)
	# walk over a tin: the gun is refilled
	var tins: Array = get_tree().get_nodes_in_group(&"ammo_drops")
	if not tins.is_empty():
		await _secs(0.6)
		await _tp((tins[0] as Node3D).global_position, 0.0)
		await _frames(6)
	_check(w.reserve > 0, "walking over a tin refills the gun (%d)" % w.reserve)

	# the starboard breach: nobody holds on, the player is pulled to the edge and downed, then up (solo)
	GameState.open_zone(&"B_MITTELRUMPF")
	GameState.open_zone(&"C_FLUEGEL_R")
	await _tp(Vector3(30.0, 0, 41.5), 0.0)
	stb.start()
	var downed: bool = await _until(func() -> bool: return _p.downed, 10.0)
	_check(downed and stb.downs == 1, "unanchored, the player is pulled to the edge and downed")
	_check(_p.global_position.z < 46.0, "...at the edge, never out (z %.1f)" % _p.global_position.z)
	await _until(func() -> bool: return not _p.downed, 6.0)
	_check(not _p.downed and GameState.phase == GameState.Phase.PLAYING, "solo: up again, the match goes on")
	await _until(func() -> bool: return stb.phase == DecompressionBreach.Phase.DONE, 6.0)
	_check(stb.phase == DecompressionBreach.Phase.DONE, "the breach holds again")
