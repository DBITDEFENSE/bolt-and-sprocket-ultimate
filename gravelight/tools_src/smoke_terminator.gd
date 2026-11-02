extends "res://gravelight/tools_src/smoke_m4d_u10_base.gd"
## UPDATE 10 §3 Act IV (T-158): the terminator and the heaters, headless. In order: the Terminator is configured
## and starts in full day; the line moves with the act round; at 55 % the yard, the concourse and reception are night
## (flags, the director's spawn boost, the Sun turned, the shadow wall on the line), the store is still day; the
## Operator speaks once per zone crossed; the suit heater's strain drains the gauge faster on the night side; the
## visor kills the glare; the heater switch's spectacle (the flag, the domes' lights up one by one, the mast surge,
## the perks woken, a burst of the dead, the Operator) and the halved strain after it; at 100 % every zone is night.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_terminator.tscn


func _init() -> void:
	TAG = "terminator"


func _body() -> void:
	var t: Terminator = _first(&"terminator") as Terminator
	_check(t != null and not t.cfg.is_empty(), "the Terminator is in the act and configured from map04d.json")
	if t == null:
		return
	_check(t.s <= float(t.cfg["from_s"]) + 0.1 and t.night_zones.values().count(true) == 0, "act round 1: the whole relay in day (s %.1f)" % t.s)
	var r10: float = Terminator.line_s_for(10, 16, float(t.cfg["from_s"]), float(t.cfg["to_s"]))
	_check(r10 > float(t.cfg["from_s"]) and r10 < float(t.cfg["to_s"]), "the line for act round 10 is between its ends (%.1f)" % r10)
	var sun0: Vector3 = t.sun_dir()
	t.debug_progress(0.55)
	await _frames(40)
	var agree: bool = true
	for zn: String in (t.cfg["zone_centres"] as Dictionary).keys():
		var c: Array = t.cfg["zone_centres"][zn]
		if bool(t.night_zones.get(zn, false)) != Terminator.is_night(Vector3(float(c[0]), 0, float(c[2])), t.center(), t.normal(), t.s):
			agree = false
	_check(agree, "every zone's night matches the line (%s)" % str(t.night_zones))
	_check(bool(t.night_zones.get("C_YARD", false)) and bool(t.night_zones.get("B_CONCOURSE", false)), "at 55 %: the yard and the concourse are night")
	_check(not bool(t.night_zones.get("E_HALL", false)) and not bool(t.night_zones.get("F_CORE", false)), "at 55 %: the hall and the Account are still in day")
	_check(GameState.has_flag(&"night_c_yard") and GameState.has_flag(&"night_b_concourse"), "the night flags are set (night_c_yard, night_b_concourse)")
	_check(is_equal_approx(float(_dir._boost.get(&"C_YARD", 1.0)), float(t.cfg["shadow_spawn_mult"])), "the yard's spawns get the shadow boost (x%.2f)" % float(_dir._boost.get(&"C_YARD", 1.0)))
	_check(sun0.angle_to(t.sun_dir()) > deg_to_rad(5.0), "the Sun has swung and sunk (%.1f deg)" % rad_to_deg(sun0.angle_to(t.sun_dir())))
	var sun: DirectionalLight3D = _map.get_node_or_null("Moon") as DirectionalLight3D
	_check(sun != null and (-sun.global_transform.basis.z).dot(-t.sun_dir()) > 0.99, "the scene's Sun (SunGate) follows the terminator")
	var wall: Node3D = t.get_node_or_null("NightWall") as Node3D
	_check(wall != null and absf(Terminator.side_of(wall.global_position, t.center(), t.normal(), t.s)) < 1.5, "the shadow wall stands on the line")
	var heard: bool = await _until(func() -> bool:
		var n: int = 0
		for id: String in _vo:
			if id.begins_with("OPR_M4D_TERM_"):
				n += 1
		return n >= t.crossings_spoken, 25.0)
	var term_lines: int = 0
	for id2: String in _vo:
		if id2.begins_with("OPR_M4D_TERM_"):
			term_lines += 1
	_check(heard and _said("OPR_M4D_TERM_"), "the Operator remarks on the crossings (%s)" % str(_vo.slice(-4)))
	_check(term_lines == t.crossings_spoken and t.crossings_spoken >= 1 and t.crossed.size() >= 2, "once per crossing: zones crossed together share a line (%d lines, %d zones)" % [term_lines, t.crossed.size()])
	# the heater's strain: the gauge falls faster on the night side of the yard
	await _tp(Vector3(-20, 0, 92))
	await _until(func() -> bool: return _p.in_vacuum, 2.0)
	_check(t.night_at(_p.global_position) and _p.in_vacuum, "the player stands in the yard's night, breathing from the suit")
	_p.air = _p.air_max
	var a0: float = _p.air
	await _secs(2.0)
	var lost_night: float = a0 - _p.air
	_check(lost_night > 2.0 * (1.0 + float(t.cfg["cold_air_drain"])) * 0.8, "the cold drains the gauge faster (%.2f s of air in 2 s)" % lost_night)
	var hud: MoonSuitHud = _first(&"moon_suit_hud") as MoonSuitHud
	_check(hud != null and hud.frost > 0.0, "the visor frosts in the cold (frost %.2f)" % (hud.frost if hud != null else -1.0))
	# the visor and the glare (pure: the camera's facing is not driven headless)
	_check(Terminator.glare_for(true, true, 0.95, false, 0.35) > 0.8 and Terminator.glare_for(true, true, 0.95, true, 0.35) == 0.0, "the glare blinds facing the Sun; the visor down removes it")
	hud.set_visor(true)
	_check(hud.visor_down and InputMap.has_action(&"visor"), "the visor toggles (the `visor` action is bound)")
	hud.set_visor(false)
	# the heaters: the act's power-on
	var hs: HeaterSwitch = _first(&"heater_switch") as HeaterSwitch
	_check(hs != null and hs.can_interact(_p), "the heater switch on the concourse wall, usable")
	var zs0: int = _dir.active_zombies().size()
	hs.interact(_p)
	_check(GameState.has_flag(&"heaters_on") and t.heaters_on, "the heaters run (flag heaters_on)")
	await _secs(1.0)
	_check(float(t._econ.get("A_RECEPTION", 0.0)) > float(t._econ.get("F_CORE", 1.0)), "the domes come up one by one (reception ahead of the Account)")
	await _secs(5.0)
	_check(float(t._econ.get("F_CORE", 0.0)) > 0.95, "every dome at full light")
	var mast: RelayMast = _first(&"relay_mast") as RelayMast
	_check(mast != null and mast.heated, "the relay mast pulses violet (heated)")
	_check(_dir.active_zombies().size() >= zs0 + 2, "a burst of the dead (%d -> %d)" % [zs0, _dir.active_zombies().size()])
	var vo_wait: float = 0.0
	while not _said("OPR_M4D_HEATERS_01") and vo_wait < 12.0:   # it may queue behind a crossing line
		await _secs(0.5)
		vo_wait += 0.5
	_check(_said("OPR_M4D_HEATERS_01"), "the Operator on the heaters (%.1f s after the checks)" % vo_wait)
	_p.air = _p.air_max
	a0 = _p.air
	await _secs(2.0)
	var lost_heated: float = a0 - _p.air
	_check(lost_heated < lost_night - 0.4, "with the heaters the strain eases (%.2f < %.2f)" % [lost_heated, lost_night])
	t.debug_progress(1.0)
	await _frames(40)
	_check(t.night_zones.values().count(true) == 6, "at the act's end every zone is night (%s)" % str(t.night_zones))
	await _tp(Vector3(0, 0, 8))
