extends "res://gravelight/tools_src/smoke_m4c_base.gd"
## UPDATE 10 §3 Act III `radar_ping` (T-157): the dish is dead without power; with the generator on it turns, and
## every 60 s a ping shows every zombie (a lab zombie a floor down and 100 m off included) on the minimap and the
## pause map (MapState's live icons) for 10 s; the minimap draws the sweep; then the dots go.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_radar_ping.tscn


func _init() -> void:
	tag = "radar"


func _zombie_dots() -> int:
	var ms: MapState = MapState.current()
	if ms == null:
		return -1
	var n: int = 0
	for l: Dictionary in ms.live_icons():
		if str(l.get("kind", "")) == "zombie":
			n += 1
	return n


func _body() -> void:
	var rd: RadarDish = _g("RadarController") as RadarDish
	_check(rd != null and not rd.cfg.is_empty(), "the radar's controller is on the tower, map04c.json radar loaded")
	if rd == null:
		return
	_check(rd._dish != null and rd._dish.name == "RadarDish", "the dish is a live node (kept out of the bake)")
	RoundManager.stop()
	await _open_doors(true)
	await _clear_zombies()
	await _tp(Vector3(0, 0, 30))
	await _secs(1.0)
	_check(not rd.powered and rd.turned_deg == 0.0 and rd.pings == 0, "no power: the dish is still, no pings")
	var basis0: Basis = rd._dish.basis
	# a zombie in the lab: a floor down, ~100 m off; with the default minimap setting it does not show
	var z: Zombie = await _chaser_at(Vector3(-40, -6, 130))
	if z != null:
		z.set_physics_process(false)
	await _frames(4)
	_check(_zombie_dots() == 0, "before the ping: the lab zombie is not on the map (%d dots)" % _zombie_dots())
	GameState.power_on = true
	GLBus.power_activated.emit()
	await _secs(2.0)
	_check(rd.powered and rd.turned_deg > 5.0 and not rd._dish.basis.is_equal_approx(basis0), "power: the dish turns (%.0f deg)" % rd.turned_deg)
	_check(absf(rd._next_at - float(rd.cfg.get("first_after_s", 8.0))) < 0.01, "the first ping is due 8 s after the power")
	rd.debug_next_ping_in(0.5)
	var pinged: bool = await _until(func() -> bool: return rd.pings == 1, 3.0)
	_check(pinged, "the ping went out")
	await _frames(3)
	var ms: MapState = MapState.current()
	_check(ms != null and ms.radar_active() and ms.radar_left > 9.0, "GLBus.radar_ping(10): the map's radar runs (%.1f s)" % (ms.radar_left if ms != null else -1.0))
	_check(_zombie_dots() >= 1, "during the ping every zombie shows, the lab one too (%d dots)" % _zombie_dots())
	var sweep: Node = _map.find_child("Minimap", true, false)
	_check(_hud_banner() == str(rd.cfg.get("first_banner", "")), "the first ping names the radar on the HUD ('%s')" % _hud_banner())
	_check(absf((rd._next_at - rd._since) - 60.0) < 1.0, "the next ping is 60 s away (%.1f)" % (rd._next_at - rd._since))
	await _secs(10.5)
	_check(not ms.radar_active() and _zombie_dots() == 0, "10 s later the dots are gone (%d)" % _zombie_dots())
	print("[radar] minimap node present: %s" % str(sweep != null))
