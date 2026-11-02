extends "res://gravelight/tools_src/smoke_m4c_base.gd"
## UPDATE 10 §3 Act III `dust_storm` (T-157): the storm is the round every 5th act round; the fog closes to 15 m and
## the sky dims; the HUD names the rule once ("DUST STORM: they hunt by sound"); a stalker 12 m from a quiet player
## does not find them; the same player sprinting is heard (×3 radius) and found; a shot is heard too; the storm's end
## lets the stalkers see again.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_dust_storm.tscn


func _init() -> void:
	tag = "dust"


func _body() -> void:
	var dc: Dictionary = _gc.cfg.get("dust_storm", {})
	await _frames(4)
	_check(int(dc.get("every_act_rounds", 0)) == 5, "map04c.json: the storm every 5th act round")
	_check(RoundManager.next_special == 25, "the next special round is act round 5 = match 25 (%d)" % RoundManager.next_special)
	_check(GroomController.next_storm_round(25, 21, 5) == 30 and GroomController.storm_round_due(10, 5) and not GroomController.storm_round_due(6, 5), "the schedule after a storm: act round 10 next")
	RoundManager.stop()
	await _open_doors()
	await _clear_zombies()
	await _tp(Vector3(0, 0, 30))
	var env: Environment = null
	for n: Node in _map.find_children("*", "WorldEnvironment", true, false):
		env = (n as WorldEnvironment).environment
	var fog0: float = env.fog_density if env != null else 0.0
	_gc.debug_storm(true)
	await _frames(2)
	_check(_gc.dust_active() and _gc.storms == 1, "the storm is on")
	_check(_hud_banner() == "DUST STORM: they hunt by sound", "the HUD names the rule the first time ('%s')" % _hud_banner())
	await _secs(4.5)
	_check(env != null and env.fog_density > 0.18 and env.fog_density > fog0, "the fog closes to ~15 m (density %.3f, was %.3f)" % [env.fog_density if env != null else 0.0, fog0])
	var fx: Node = _map.find_child("DustStormFx", true, false)
	_check(fx != null and bool(fx.call("dust_on")), "DustStormFx follows the storm")

	# a stalker 12 m away; the human held still and quiet (the player's own physics off so the flag holds)
	_p.set_physics_process(false)
	_p.sprinting = false
	var z: Zombie = await _chaser_at(Vector3(12, 0, 30))
	_check(z != null, "a Gänger on the salt")
	if z == null:
		return
	_gc._maybe_hunt(z)
	_check(z.hunt_by_sound and _gc.hunters.has(z), "a surface Gänger in the storm hunts by sound")
	var d0: float = _flat(z.global_position, _p.global_position)
	await _secs(5.0)
	var d1: float = _flat(z.global_position, _p.global_position)
	_check(d1 > 9.0, "walking is quiet: the stalker does not find the player 12 m off (%.1f -> %.1f m)" % [d0, d1])
	# sprinting: heard at 3 × 6 = 18 m, it closes in
	_p.sprinting = true
	var found: bool = await _until(func() -> bool: return _flat(z.global_position, _p.global_position) < 3.0, 12.0)
	_check(found, "a sprinting player is heard and found (%.1f m)" % _flat(z.global_position, _p.global_position))
	_p.sprinting = false
	# a shot: a second stalker, the player quiet but firing
	var z2: Zombie = await _chaser_at(Vector3(-12, 0, 36))
	if z2 != null:
		_gc._maybe_hunt(z2)
		await _secs(2.0)
		var e0: float = _flat(z2.global_position, _p.global_position)
		_check(e0 > 10.0, "the second stalker hears nothing yet (%.1f m)" % e0)
		for i: int in 6:
			GLBus.weapon_fired.emit(1, &"m1_garand", false, _p.global_position + Vector3.UP, Vector3.FORWARD)
			await _secs(0.5)
		var e1: float = _flat(z2.global_position, _p.global_position)
		_check(e1 < e0 - 1.5, "a shot is loud: it turns toward the player (%.1f -> %.1f m)" % [e0, e1])
	# the storm ends: the stalkers see again
	_gc.debug_storm(false)
	await _frames(2)
	_check(not _gc.dust_active() and not z.hunt_by_sound and _gc.hunters.is_empty(), "the clear: the stalkers see again")
	_gc.debug_storm(true)
	await _frames(2)
	_check(_gc.storms == 2 and _hud_banner() == str(dc.get("banner", "DUST STORM")), "the second storm shows the short banner ('%s')" % _hud_banner())
	_gc.debug_storm(false)
	_p.set_physics_process(true)
