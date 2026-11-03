extends "res://gravelight/tools_src/smoke_m4c_base.gd"
## UPDATE 10 §3 Act III's living world and people (T-157): map04c_ambience.json attached (the Milky Way fading
## with the dawn, the heat shimmer from act round 6, jackrabbits and coyotes that bolt, four B-29s on approach,
## tumbleweeds, the searchlight towers dark until the power, sand off the roofs, the Quonset huts), the act's own base
## bed, the "future Area 51" card line, the jukebox playing with the power; and (_people) Dee's cage egg, Hale and
## Dee's Talk cards and Dee's favour, the arrival beat, the traps with a show, the radar tower's perch, the power-on
## spectacle.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_map04c_world.tscn


func _init() -> void:
	tag = "world"


func _body() -> void:
	await _living_world()
	await _people()


func _living_world() -> void:
	var amb: MapAmbience = _map.get_node_or_null("MapAmbience") as MapAmbience
	_check(amb != null and amb.config_path.ends_with("map04c_ambience.json"), "MapRoot attached the act's MapAmbience (map04c_ambience.json)")
	if amb == null:
		return
	await _frames(5)
	_check(amb._setup_done, "it runs without a Landscape (needs_landscape false)")
	# the arrival beat: the card, then a quiet before the first spawns
	_check(_gc.arrival_quiet and RoundManager.state == RoundManager.State.BREAK and RoundManager.break_left > 9.0, "the arrival: a quiet before act round 1 (%.1f s left)" % RoundManager.break_left)
	_check(_dir.active_zombies().is_empty(), "nothing has spawned during the quiet")
	_check(str(GLData.load_json("res://data/gravelight/audio.json")["music"]["ambient"].get("map04c_groomlake", "")) == "ambient_map04c", "the act's own base bed (not the Inn's wind)")
	_check(str(_map.get("intro_text")).contains("Area 51"), "the arrival card names the future Area 51")
	# the Milky Way at act round 1, gone by 6
	_check(is_equal_approx(amb.mw_now, 1.0), "act round 1: the Milky Way at full (%.2f)" % amb.mw_now)
	_check(is_equal_approx(MapAmbience.milky_way_at(6, amb.cfg["milky_way"]), 0.0) and MapAmbience.milky_way_at(3, amb.cfg["milky_way"]) > 0.4, "the dawn takes it by act round 6")
	var sky: ShaderMaterial = amb._sky_sm
	_check(sky != null and float(sky.get_shader_parameter("milky_way")) > 0.9, "the desert sky's band is lit")
	_check(amb.shimmer_now == 0.0 and MapAmbience.shimmer_at(8, amb.cfg["heat_shimmer"]) == 1.0, "no heat shimmer before the sun; full at act round 8")
	(amb.debug_kinds["heat_shimmer"] as Callable).call()
	_check(amb.shimmer_now == 1.0 and amb._shim_cards.size() == 3 and amb._shim_cards[0].visible, "the shimmer cards over the salt")
	# wildlife
	_check(amb.rabbits.size() == 4 and amb.coyotes.size() == 3, "four jackrabbits on the salt, three coyotes on the berms")
	RoundManager.stop()
	await _open_doors()
	await _clear_zombies()
	var r0: Dictionary = amb.rabbits[0]
	var rn: Node3D = r0["node"]
	await _tp(rn.global_position + Vector3(3.0, 0, 0))
	await _frames(4)
	_check(str(r0["state"]) == "bolt", "a jackrabbit bolts from a player 3 m off")
	var away: Vector3 = rn.global_position
	await _secs(0.6)
	_check(rn.global_position.distance_to(_p.global_position) > away.distance_to(_p.global_position), "it runs away from them")
	var c0: Dictionary = amb.coyotes[0]
	amb._ev_wildlife_shot((c0["node"] as Node3D).global_position + Vector3(10, 0, 0))
	_check(str(c0["state"]) == "bolt", "a shot 10 m from a coyote sends it off")
	_check(int(amb.counts.get("wildlife_bolt", 0)) >= 2, "bolts counted (%d)" % int(amb.counts.get("wildlife_bolt", 0)))
	# B-29s
	amb._ev_low_pass()
	await _frames(2)
	var b29: int = amb._b29.size()
	print("[world] the formation: %s" % str(amb._b29.map(func(d: Dictionary) -> String: return str((d["node"] as Node).name))))
	_check(b29 == 4, "a formation of four B-29s with landing lights (%d)" % b29)
	_check((amb.cfg["low_pass_b29"]["rounds"] as Array) == [2.0, 7.0], "on act rounds 2 and 7 (match 22 / 27)")
	# tumbleweeds
	amb._ev_tumbleweeds()
	var tw: Node3D = (amb.tumble[0] as Dictionary)["node"] if not amb.tumble.is_empty() else null
	var x0: float = tw.global_position.x if tw != null else 0.0
	await _secs(1.0)
	_check(tw != null and tw.global_position.x > x0 + 1.0, "a tumbleweed rolls across the salt with the wind")
	# sand off the roofs, the Quonset huts
	amb._ev_sand_roofs()
	_check(int(amb.counts.get("sand_roofs", 0)) == 1 and not amb._sand_pool.is_empty(), "sand blows off the roof edges")
	var huts: int = 0
	for c2: Node in amb.get_children():
		if String(c2.name).contains("Quonset"):
			huts += 1
	_check(huts == 2, "two Quonset huts past the west berm (%d)" % huts)
	# the searchlights and the jukebox wait for the power
	var jb: Jukebox = _g("Jukebox") as Jukebox
	_check(jb != null and not jb.powered and not jb.playing, "the jukebox in the hangar's break corner is dark without power")
	_check(amb.towers_lit == 0 and amb._towers.size() == 4, "four searchlight towers, dark")


func _people() -> void:
	# --- Dee's cage side egg: findable, its lines baked
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	var baked: bool = true
	for id: String in ["DEE_M4C_CAGE_01", "DEE_M4C_CAGE_02", "DEE_M4C_CAGE_03", "DEE_M4C_LAST_01", "DEE_M4C_LAST_02"]:
		baked = baked and lines.has(id) and FileAccess.file_exists("res://gravelight/audio/vo/dee/%s.ogg" % id)
	_check(baked, "Dee's cage lines exist with their audio")
	var heard: Array[StringName] = []
	GLBus.vo_line_started.connect(func(id: StringName, _s: StringName, _t: String, _d: float) -> void: heard.append(id))
	_check(not _gc.cage_noted, "the cage is not on the map before anyone sees it")
	await _tp(Vector3(58.0, 0, 94.0), -90.0)
	await _secs(1.2)
	var ms: MapState = MapState.current()
	var noted: bool = false
	for m: Dictionary in ms.markers() if ms != null else []:
		if str(m.get("label", "")).begins_with("Dee's yard rule"):
			noted = true
	_check(_gc.cage_noted and noted, "first sight of the cage: a minimap note")
	var casing: Node = _g("CageItem_casing")
	if casing != null and casing.has_method("interact"):
		casing.call("interact", _p)
		await _secs(0.6)
	_check(GameState.has_flag(&"cage_casing"), "a cage item taken for Dee's pile")

	# --- Dee and Hale: Talk cards (ExtraPeople)
	var dee: ExtraPerson = _map.get_node_or_null("Person_dee") as ExtraPerson
	var hale: ExtraPerson = _map.get_node_or_null("Person_hale") as ExtraPerson
	_check(dee != null and hale != null, "Dee and Hale are on the map as ExtraPeople")
	if dee != null:
		_check(dee.spot().distance_to(Vector3(61.2, 0, 94.0)) < 0.1, "Dee is talked to at her counter")
		dee.accept_favour(_p)
		await _frames(3)
		var valve: Node3D = null
		for c: Node in dee.get_children():
			if c.name.to_lower().contains("item") or c.get_class() == "FavourItem" or (c.get_script() != null and str(c.get_script().resource_path).contains("favour")):
				valve = c as Node3D
		_check(dee.favour == ExtraPerson.Favour.ASKED, "her favour: the radio valve in the motor pool")
		dee.item_taken(_p)
		dee.give_item(_p)
		await _frames(3)
		_check(dee.favour == ExtraPerson.Favour.DONE and _map.find_child("SupplyDrop", true, false) != null, "the valve given: she calls in a supply drop at the hangar")
	if hale != null:
		_check(hale.cfg.get("favour", {}).is_empty() and str(hale.cfg.get("said", "")) != "", "Hale: a Talk card only")
		_check(hale.reaction_now().is_empty(), "no reaction before Peg's choice")
		GameState.set_flag(&"peg_resigned")
		_check(str(hale.reaction_now().get("line", "")) == "HAL_M4C_RESIGN_01", "he reacts to Peg keeping the engine")
		GameState.flags.erase(&"peg_resigned")

	# --- the traps with a show
	var fd: FuelDumpTrap = _g("Trap_FuelDump") as FuelDumpTrap
	_check(fd != null and fd.trap_name() == "Fuel Dump" and fd.cost() == 1000, "the fuel dump trap (1000)")
	if fd != null:
		await _tp(Vector3(-27.0, 0, 84.0))
		var z: Zombie = await _chaser_at(fd.global_position + Vector3(1.0, 0, 0))
		if z != null:
			z.set_physics_process(false)
		fd.activate(1)
		await _secs(1.6)
		_check(fd.shows == 1 and fd.is_live() and fd._flames.size() >= 4, "the lever lights the dump: the whump and a wall of fire (%d flames)" % fd._flames.size())
		_check(z == null or not z.is_active() or z.state == Zombie.State.DEAD, "a zombie in the wall burns")
		_check(_map.find_child("SmokeColumn", true, false) != null, "a smoke column")
	var dd: DoorDropTrap = _g("Trap_HangarDoor") as DoorDropTrap
	_check(dd != null and dd.cost() == 750 and is_equal_approx(TrapLever.cooldown_for("door_drop"), 60.0), "the hangar door drop (750, 60 s)")
	if dd != null:
		await _tp(dd.global_position + Vector3(0, 0, 0.3))
		var z2: Zombie = await _chaser_at(dd.global_position + Vector3(0.6, 0, -0.4))
		if z2 != null:
			z2.set_physics_process(false)
		dd.activate(1)
		await _secs(1.8)
		_check(dd.drops == 1 and dd.crushed >= 1, "the door comes down and crushes the doorway (%d)" % dd.crushed)
		_check(not dd._contains(_p.global_position + Vector3.UP * 0.5) and _p.is_alive(), "the player in the doorway was shoved clear")
		await _until(func() -> bool: return not dd.active, 8.0)
		_check(not dd.active and dd.cooldown_left > 55.0, "it winches up; 60 s to the next drop (%s, %s, %.1f)" % [str(dd.active), dd._phase, dd.cooldown_left])

	# --- room story (T-171, THE_BAR row 6): the act's six fixed story props stand in the scene
	var want_props: PackedStringArray = ["INT_M4_MANIFEST", "INT_M4_PROGRAM", "INT_M4C_RANGELOG", "INT_M4C_FUELCARD", "INT_M4C_SPECIMENTAG", "INT_M4C_WATCHLOG"]
	var found_props: int = 0
	for sp: Node in get_tree().get_nodes_in_group(&"story_props"):
		if want_props.has(String(sp.get("intel_id"))):
			found_props += 1
	_check(found_props == want_props.size(), "the six Groom Lake story props are in the act (%d)" % found_props)

	# --- the radar tower's perch
	var foot: TowerLadder = _g("TowerLadder_Foot") as TowerLadder
	_check(foot != null and _g("TowerLadder_Top") != null, "the tower's ladder, foot and top")
	if foot != null:
		await _tp(Vector3(45.0, 0, 115.6))
		foot.climb(_p)
		await _secs(4.2)
		_check(_p.global_position.y > 15.5 and absf(_p.global_position.x - 45.0) < 3.5, "up the ladder onto the 16 m deck (%s)" % str(_p.global_position))
		await _frames(10)
		_check(_p.global_position.y > 15.5, "standing on the deck (it holds)")
		var rid: RID = _map.get_world_3d().navigation_map
		# T-171: the zombies' mask is the zone's walk bit plus its climb bit (T-153 moved every ladder onto the climb
		# layer; this query kept the walk bit alone, so the path stayed on the ground and the check failed on master)
		var zmask: int = (1 << 4) | ClimbLink.climb_bit(5)
		var path: PackedVector3Array = NavigationServer3D.map_get_path(rid, Vector3(45, 0, 108), Vector3(46.5, 16.0, 121.5), true, zmask)
		var walk_only: PackedVector3Array = NavigationServer3D.map_get_path(rid, Vector3(45, 0, 108), Vector3(46.5, 16.0, 121.5), true, 1 << 4)
		_check(not path.is_empty() and path[path.size() - 1].y > 15.0, "the zombies' climb link reaches the deck (navmesh up there)")
		_check(walk_only.is_empty() or walk_only[walk_only.size() - 1].y < 15.0, "without the climb layer the deck is out of reach (the bots never climb)")
		var top: TowerLadder = _g("TowerLadder_Top") as TowerLadder
		top.climb(_p)
		await _secs(4.2)
		_check(_p.global_position.y < 1.5, "and back down")

	# --- the power-on spectacle
	var amb: MapAmbience = _map.get_node_or_null("MapAmbience") as MapAmbience
	var rd: RadarDish = _g("RadarController") as RadarDish
	var jb: Jukebox = _g("Jukebox") as Jukebox
	var sw: PowerSwitch = _g("Generator") as PowerSwitch
	_check(sw != null, "the generator's switch")
	if sw != null:
		sw.run_sequence(1)
		await _secs(6.5)
		_check(GameState.power_on, "power on")
		_check(amb != null and amb.towers_lit == 4, "the floods come up tower by tower (%d)" % (amb.towers_lit if amb != null else -1))
		_check(rd != null and rd.powered and rd.turned_deg > 1.0, "the radar begins to turn")
		_check(jb != null and jb.powered and jb.playing, "the jukebox starts")
		_check(_gc.perks_woken >= 9, "the perks wake with stings (%d)" % _gc.perks_woken)
	# Dee's cage line, queued behind the arrival's lines, has played by now (the VO queue starts it)
	var played: bool = await _until(func() -> bool: return heard.has(&"DEE_M4C_CAGE_01"), 20.0)
	_check(played, "Dee's cage line plays (DEE_M4C_CAGE_01; heard %d lines)" % heard.size())
	_check(heard.has(&"DEE_M4C_FAVOUR_ASK_01") or heard.has(&"DEE_M4C_FAVOUR_THANKS_01") or heard.has(&"DEE_M4C_DROP_01"), "Dee's new favour lines play")
