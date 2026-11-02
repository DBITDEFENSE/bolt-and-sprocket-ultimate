extends "res://gravelight/tools_src/m2_smoke_base.gd"
## Tide v2 smoke (UPDATE 10 contract C2, DECISIONS T-153): the stages on the right rounds, a spring tide (the aprons
## go under, the piers stay dry, the flag and the signals), the Pumpenschalter crank (refuses without power and a flood;
## a 30 s holdout under x2 spawns shortens the flood), a power-up floats off the apron and is lost, a sparking cable
## stuns a wading zombie and hurts a wading player.


func _init() -> void:
	tag = "tide2"


func _body() -> void:
	var stages: Array = []
	var springs: Array = []
	var begins: Array = [0]
	GLBus.tide_stage.connect(func(s: StringName) -> void: stages.append(s))
	GLBus.spring_tide.connect(func(r: int) -> void: springs.append(r))
	GLBus.tide_flood_begin.connect(func() -> void: begins[0] += 1)
	var cfg: Dictionary = GLData.load_json("res://data/gravelight/map02.json")["tide"]
	# --- stages
	_tide.on_round(8)
	_check(_tide.stage == &"half", "round 8 plans a half tide")
	await _secs(float(cfg["rise_seconds"]) + 1.0)
	_check(not _tide.flooded, "a half tide floods nothing")
	_tide.on_round(9)
	_check(_tide.stage == &"spring" and springs.has(9), "round 9 is a spring tide (signal spring_tide 9)")
	await _secs(float(cfg["rise_seconds"]) + 1.5)
	_check(absf(_tide.level - TideController.stage_y(&"spring", cfg)) < 0.05, "the water reached spring height (%.2f)" % _tide.level)
	_check(_tide.flooded and GameState.has_flag(&"flooded") and begins[0] >= 1, "flooded: the flag and tide_flood_begin")
	_check(_tide.is_wading(Vector3(10.0, 0.1, 35.5)), "the north apron is under water")
	_check(_tide.is_wading(Vector3(38.0, 0.1, 44.0)), "the east apron's basin edge is under water")
	_check(not _tide.is_wading(Vector3(17.0, 0.1, 62.0)) and not _tide.is_wading(Vector3(-3.0, 0.1, 62.0)), "the piers stand dry")
	_check(stages.has(&"half") and stages.has(&"spring"), "tide_stage signalled half and spring")
	# --- the crank
	var crank: PumpCrank = _g("PumpCrank") as PumpCrank
	_check(crank != null, "the pump crank is placed")
	GameState.power_on = false
	_check(not crank.can_interact(_p), "no crank without power")
	GameState.power_on = true
	_check(crank.can_interact(_p), "with power and a flood the crank takes a hand")
	var hold_before: float = _tide.hold_left
	await _tp(crank.global_position + crank.global_basis * Vector3(0, 0.2, 1.2))
	crank.start(1)
	_check(crank.state == HoldoutStation.State.RUNNING and GameState.has_flag(&"holdout"), "the crank holdout runs (the holdout flag is on)")
	await _secs(float(cfg["pump_crank"]["seconds"]) + 2.0)
	_check(crank.completions == 1, "30 s at the crank completes it")
	_check(_tide.hold_left < hold_before - 30.0 or _tide.target <= float(cfg["low_y"]) + 0.01, "the flood was shortened (hold %.0f -> %.0f s)" % [hold_before, _tide.hold_left])
	_check(not GameState.has_flag(&"holdout"), "the holdout flag is off again")
	# --- a floating power-up
	if _tide.target <= float(cfg["low_y"]) + 0.01:
		_tide.on_round(9)
		await _secs(float(cfg["rise_seconds"]) + 1.5)
	var pu: PowerupPickup = PowerupPickup.new()
	pu.powerup_id = &"resupply"
	pu.lifetime_override = 120.0
	_map.add_child(pu)
	pu.global_position = Vector3(24.0, 0.4, 36.6)
	var lost_before: int = _tide.powerups_lost
	await _secs(1.5)
	_check(is_instance_valid(pu) and pu.global_position.z > 36.6, "a drop on the flooded apron drifts toward the docks")
	await _secs(6.0)
	_check(_tide.powerups_lost > lost_before, "and the sea takes it at the dock edge")
	# --- a sparking cable
	var z: Zombie = await _zombie_at(Vector3(24.5, 0.0, 36.3))
	var sparks: int = _tide.cable_sparks
	await _secs(1.2)
	_check(_tide.cable_sparks > sparks, "the apron cable sparks in the flood")
	_check(z != null and z.frost_speed_mult() < 0.05, "a wading zombie by the cable is stunned (x%.2f)" % (z.frost_speed_mult() if z != null else 1.0))
	var hits: Array = [0]
	GLBus.player_damaged.connect(func(_pid: int, _a: float) -> void: hits[0] += 1)
	await _tp(Vector3(24.0, 0.2, 36.0))
	await _secs(1.5)
	_check(hits[0] > 0, "a wading player by the cable is hurt")
	await _tp(Vector3(24.0, 0.2, 21.0))
	# --- the storm values for the living world
	_check(float(TideController.storm_for(&"spring", cfg)["lightning_interval"]) > 0.0, "the storm data has a spring lightning interval")
