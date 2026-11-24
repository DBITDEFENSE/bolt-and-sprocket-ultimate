extends "res://gravelight/tools_src/smoke_act2_lib.gd"
## UPDATE 10 §3 (T-156): der Kranich's world, headless: the living world (map04b_ambience.json: the formation, one
## bomber shot down, flak, St Elmo's fire, the dawn, frost on the skin, rivets in a tilt, the engine's pitch under
## strain, the cabin hushed for the London window, the swinging cables); the aux bus as a board you find and its
## sweep (breakers, dials, perk stings, the Bordfunk); the four story props; Ruhland's Talk card and favour, Riedl on
## the intercom until his turn; the crew's tags side quest end to end (Archive entry); the bay doors trap drops a
## ganger; two crate spots; the next act preloading behind a transition.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_map04b_world.tscn


func _init() -> void:
	tag = "m4bworld"


func _act(n: int) -> void:
	RoundManager.current_round = RoundManager.act_start + n - 1


func _body() -> void:
	var amb: MapAmbience = _map.get_node_or_null("MapAmbience") as MapAmbience
	_check(amb != null and amb.config_path.ends_with("map04b_ambience.json"), "MapRoot attached the act's MapAmbience")
	if amb == null:
		return
	await _frames(10)
	_check(int(amb.counts.get("formation", 0)) == 4, "four bombers hold station round the Kranich")
	_check(int(amb.counts.get("cables", 0)) >= 6, "cable bundles hung for the swing (%d)" % int(amb.counts.get("cables", 0)))
	var sky: FlightSky = get_tree().get_first_node_in_group(&"flight_sky") as FlightSky
	_act(1)
	await _secs(0.5)
	var s1: float = sky.sunrise if sky != null else -1.0
	_act(5)
	await _secs(0.5)
	_check(sky != null and sky.sunrise > s1 + 0.3, "the night turns to dawn across the act (sunrise %.2f -> %.2f)" % [s1, sky.sunrise if sky != null else -1.0])
	_act(2)
	await _secs(1.0)
	_check(int(amb.counts.get("st_elmo", 0)) >= 2, "St Elmo's fire on the wingtips from act round 2")
	amb._a2_flak_t = 0.0
	await _secs(0.5)
	_check(int(amb.counts.get("flak", 0)) >= 1, "flak bursts out round the formation")
	amb.formation_hit(0)
	await _secs(1.5)
	_check(int(amb.counts.get("formation_down", 0)) == 1, "a bomber of the formation is hit and goes down trailing fire")
	var b0: Node3D = amb._a2_bombers[0]["node"] as Node3D
	var y0: float = b0.global_position.y
	await _secs(2.0)
	_check(is_instance_valid(b0) and b0.global_position.y < y0 - 1.0, "...falling (%.0f -> %.0f)" % [y0, b0.global_position.y if is_instance_valid(b0) else 0.0])
	_act(4)
	await _secs(4.0)
	var skin: ShaderMaterial = null
	for k: Variant in KranichShell._mats.keys():
		skin = KranichShell._mats[k] as ShaderMaterial
		break
	_check(skin != null and float(skin.get_shader_parameter("frost")) > 0.0, "frost creeps over the skin with the altitude (%.3f)" % (float(skin.get_shader_parameter("frost")) if skin != null else -1.0))
	var r0: int = int(amb.counts.get("rivet", 0))
	_fc.bank_now()
	await _secs(5.5)
	_check(int(amb.counts.get("rivet", 0)) >= r0 + 3, "loose rivets pop in the tilt (%d)" % (int(amb.counts.get("rivet", 0)) - r0))
	await _until(func() -> bool: return not _fc.banking, 6.0)
	GLBus.explosion.emit(Vector3(-70, 1.0, 40.0), 4.0)
	GLBus.explosion.emit(Vector3(-66, 1.0, 44.0), 4.0)
	await _secs(0.5)
	var amb_p: Variant = AudioDirector.get("_ambient")
	_check(int(amb.counts.get("engine_strain", 0)) > 30 and (not (amb_p is AudioStreamPlayer) or (amb_p as AudioStreamPlayer).pitch_scale < 0.99), "blasts in the engine room bend the engines' pitch")
	var bus: int = AudioServer.get_bus_index("Ambience")
	var db0: float = AudioServer.get_bus_volume_db(bus)
	_fc.start_london()
	await _secs(3.5)
	_check(int(amb.counts.get("london_hush", 0)) == 1 and AudioServer.get_bus_volume_db(bus) < db0 - 6.0, "the cabin goes quiet for the London window (%.0f -> %.0f dB)" % [db0, AudioServer.get_bus_volume_db(bus)])

	# the aux bus
	var ab: AuxBus = _g("AuxBus") as AuxBus
	_check(ab != null, "the aux bus is its own board (AuxBus)")
	if ab != null:
		var front: Vector3 = -ab.global_basis.z
		_check(front.x < -0.9, "its face looks into the cabin (front %s)" % str(front.snapped(Vector3.ONE * 0.01)))
		_check(not GameState.power_on and ab.get_prompt(_p).contains("auxiliary bus"), "dark until it is thrown: " + ab.get_prompt(_p))
		ab.run_sequence(1)
		await _secs(6.0)
		_check(GameState.power_on and ab.stings >= 3, "the sweep: power on, the perks wake with stings (%d)" % ab.stings)
		_check(ab._breakers.size() == 7 and absf(ab._breakers[6].rotation.x) > 2.0, "each room's breaker flips as its lights come up")
		_check(not ab._dials.is_empty() and ab._dials[0].emission_energy_multiplier > 1.0, "the flight deck's dials come up (%d faces)" % ab._dials.size())

	# the story props
	var props: int = 0
	for id: String in ["INT_M4B_BORDBUCH", "INT_M4B_CREWPHOTO", "INT_M4B_AIMERCARD", "INT_M4B_AUTOPILOT"]:
		if _map.find_child("Story_" + id, true, false) != null:
			props += 1
	_check(props == 4, "four story props aboard (%d)" % props)

	# the people
	var ruh: ExtraPerson = _map.get_node_or_null("Person_ruhland") as ExtraPerson
	var rdl: ExtraPerson = _map.get_node_or_null("Person_riedl") as ExtraPerson
	_check(ruh != null and ruh.bodies.is_empty() and ruh.talk != null, "Ruhland has a Talk card at the Bordkasse (her body is the teller's)")
	_act(2)
	_check(rdl != null and rdl.present(), "Riedl answers the intercom before his turn")
	if ruh != null:
		var before: int = Economy.get_scrip(1)
		ruh.accept_favour(_p)
		_check(ruh.item != null and ruh.item.global_position.z > 60.0, "her favour: the Bordkasse's ledger lies on the flight deck")
		ruh.item_taken(_p)
		ruh.give_item(_p)
		_check(ruh.state_name() == "done" and ruh.events.has("reward:scrip_mark"), "the ledger returned: the Scrip reward and her line")
		_check(Economy.get_scrip(1) >= before + 1500, "...1500 Scrip (%d -> %d)" % [before, Economy.get_scrip(1)])
	if rdl != null:
		_act(4)
		_check(not rdl.present(), "from act round 4 the intercom is dead (he is the Bordwart now)")

	# the crew's tags side quest
	_check(QuestManager.has_quest(&"map04b_crew_tags"), "the side quest is loaded")
	for t: String in ["Tag1", "Tag2", "Tag3"]:
		var qn: QuestNote = _g(t) as QuestNote
		if qn != null:
			qn.interact(_p)
	await _frames(3)
	_check(QuestManager.is_step_done(&"map04b_crew_tags", &"s1_tags"), "three tags found")
	var roster: QuestInteract = _g("CrewRoster") as QuestInteract
	var reel: QuestInteract = _g("BordfunkReel") as QuestInteract
	_check(roster != null and reel != null, "the roster board and the tape deck are placed")
	if roster != null and reel != null:
		roster.interact(_p)
		await _frames(3)
		_check(QuestManager.is_step_done(&"map04b_crew_tags", &"s2_roster"), "read at the roster")
		reel.interact(_p)
		await _frames(3)
		_check(QuestManager.is_complete(&"map04b_crew_tags") and GameState.has_flag(&"kranich_lastcall_heard"), "the Bordfunk plays the crew's last transmission")
		_check(ProfileSave.has_intel("INT_M4B_LASTCALL"), "...an Archive entry")

	# the bay doors
	var trap: BayDoorsTrap = _g("Trap_BayDoors") as BayDoorsTrap
	var lever: TrapLever = _g("Lever_BayDoors") as TrapLever
	_check(trap != null and lever != null and lever.trap() == trap, "the bay doors trap and its lever")
	if trap != null:
		await _tp(Vector3(0.0, 0, 15.0), 0.0)
		var z: Zombie = await _zombie_on(Vector3(-1.0, 0, 10.0))
		lever.interact(_p)
		await _secs(0.4)
		_check(trap.active and not trap.is_open(), "the lever: the klaxon first")
		await _secs(2.0)
		_check(trap.is_open() and z != null and not z.is_active() and trap.dropped >= 1, "the doors open: the ganger on the grating drops out (%d)" % trap.dropped)
		_check(not _p.downed and absf(_p.global_position.x) > 1.0, "the player on the doors is thrown aside, unhurt (x %.1f)" % _p.global_position.x)
		await _until(func() -> bool: return not trap.active, 10.0)
		_check(not trap.active and trap.cooldown_left > 50.0, "the doors shut; a 60 s cooldown (%.0f)" % trap.cooldown_left)

	_check(get_tree().get_nodes_in_group(&"crate_spots").size() == 2, "two crate spots (the galley, the gun blisters)")

	# T-274: the starboard decompression takes the crawlway's papers out through the breach and breaks its stash
	var stb: Node = _g("DecompStarboard")
	var react: DecompReactive = _map.find_child("DecompReactStb", true, false) as DecompReactive
	var papers: LoosePapers = _map.find_child("Papers_Crawlway", true, false) as LoosePapers
	var stash: ShatterSet = _map.find_child("Glass_CrawlStash", true, false) as ShatterSet
	_check(stb != null and react != null and papers != null and stash != null, "the crawlway's papers, its stash and their breach")
	if stb != null and react != null and papers != null and stash != null:
		await _tp(Vector3(0.0, 0, 30.0), 0.0)
		stb.call("start")
		await _until(func() -> bool: return react.fired > 0, 8.0)
		_check(react.fired == 1, "the pull begins: the loose things go")
		await _secs(2.5)
		var gone: int = 0
		for g2: int in papers.gone:
			gone += g2
		_check(gone >= 3, "papers pulled out through the hole (%d of %d)" % [gone, papers.count])
		_check(stash.broken_count() == stash.items.size(), "the stash by the breach broke (%d)" % stash.broken_count())
		await _until(func() -> bool: return int(stb.get("phase")) == 3, 10.0)
	# T-274: a night fighter shot down on the act's own clock (map04b.json flight.sky.fighters.downed)
	sky = get_tree().get_first_node_in_group(&"flight_sky") as FlightSky
	if sky != null:
		var dn0: int = sky.downed
		_act(2)
		sky.round_t = 46.0
		await _secs(0.4)
		_check(sky.downed == dn0 + 1, "act round 2, 45 s in: a night fighter comes up alongside and is shot down")
		await _secs(9.0)   # (hit about 4 s in, then the fall gathers speed)
		var low: float = INF
		var burning: bool = false
		for f: Dictionary in sky._fighters:
			if f.has("mid") and is_instance_valid(f["node"]):
				low = minf(low, (f["node"] as Node3D).global_position.y)
				burning = burning or (f["node"] as Node).get_node_or_null("BurningTrail") != null
		_check(burning and low < -60.0, "it falls away burning (%.0f m below the deck)" % -low)
		sky.round_t = 60.0
		await _secs(0.3)
		_check(sky.downed == dn0 + 1, "one a round")

	# the next act loads behind a transition
	Campaign.preload_next(&"map04c_groomlake")
	var scene: String = Campaign.scene_for(&"map04c_groomlake")
	var started: bool = await _until(func() -> bool: return ResourceLoader.load_threaded_get_status(scene) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE, 3.0)
	_check(Campaign.preloading == scene and started, "the next act starts loading behind the cutscene")
	await _until(func() -> bool: return ResourceLoader.load_threaded_get_status(scene) == ResourceLoader.THREAD_LOAD_LOADED, 60.0)
	_check(ResourceLoader.load_threaded_get_status(scene) == ResourceLoader.THREAD_LOAD_LOADED, "...and is ready before the loading screen asks")
