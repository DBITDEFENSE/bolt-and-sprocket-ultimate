extends "res://gravelight/tools_src/smoke_m4d_u10_base.gd"
## UPDATE 10 §3 Act IV (T-158): Mondlicht's living world and its people, headless. In order: MapRoot attached a
## MapAmbience from map04d_ambience.json and its U10 block made the MondlichtLiving node (no Map 0 kinds running);
## a shot into the regolith lifts a slow puff; the field units walk the far rim (three constructs, lamps on, never in
## the yard); the mast and the dish lamp pulse; in the yard the SFX bus is muffled through the suit and clear again
## indoors; the four new story props stand where the table puts them; Obergefreiter Pohl stands in the racks with a
## Talk card, asks his favour, the tag is carried to the console's slot and read in (his line, the Scrip, the flag);
## Jakub's line at the console when he is with the squad; the smile gets its minimap note on first sight.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_map04d_world.tscn


func _init() -> void:
	TAG = "m4d_world"


func _body() -> void:
	var amb: MapAmbience = _first(&"map_ambience") as MapAmbience
	_check(amb != null and amb.config_path.ends_with("map04d_ambience.json"), "MapRoot attached the living world (map04d_ambience.json)")
	await _frames(10)
	var lv: MondlichtLiving = _first(&"mondlicht_living") as MondlichtLiving
	_check(lv != null and lv.cfg.has("field_units") and lv.cfg.has("dust_settle"), "the U10 Act IV block made MondlichtLiving with its kinds")
	_check(amb != null and amb.flights.is_empty() and amb.crows == null, "no Map 0 kinds on the Moon (no bombers, no crows)")
	if lv == null:
		return
	# dust after a shot into the regolith
	await _tp(Vector3(0, 0, 84))
	var d0: int = int(lv.counts.get("dust", 0))
	GLBus.weapon_fired.emit(1, &"thompson", false, Vector3(0, 1.6, 84), Vector3(0, -0.6, 1).normalized())
	await _frames(3)
	_check(int(lv.counts.get("dust", 0)) == d0 + 1, "a shot into the regolith lifts a slow dust puff")
	GLBus.weapon_fired.emit(1, &"thompson", false, Vector3(0, 1.6, 40), Vector3(0, -0.6, 1).normalized())
	await _frames(3)
	_check(int(lv.counts.get("dust", 0)) == d0 + 1, "indoors no regolith dust")
	# the field units on the far rim
	_check(lv.units.size() == 3, "three Darkmatter field units")
	var p0: Vector3 = lv.units[0].global_position
	await _secs(2.0)
	var moved: float = lv.units[0].global_position.distance_to(p0)
	var outside: bool = true
	for u: Node3D in lv.units:
		if u.global_position.z < 112.0:
			outside = false
	_check(moved > 1.0 and outside, "they walk the far rim slowly and never come in (moved %.1f m)" % moved)
	var lamps: int = 0
	for u2: Node3D in lv.units:
		lamps += u2.find_children("*", "SpotLight3D", true, false).size()
	_check(lamps == 3, "each carries its lamp")
	var mast: RelayMast = _first(&"relay_mast") as RelayMast
	_check(mast != null and is_equal_approx(mast.period, 3.2), "the relay mast pulses (period from the file)")
	# silence in vacuum: the suit's muffle on the SFX bus in the yard, gone indoors
	await _tp(Vector3(0, 0, 90))
	var muffled: bool = await _until(func() -> bool: return bool(AudioDirector.get("muffled")), 3.0)
	_check(muffled, "in the yard the world is heard through the suit (SFX muffled)")
	await _tp(Vector3(0, 0, 40))
	var clear: bool = await _until(func() -> bool: return not bool(AudioDirector.get("muffled")), 3.0)
	_check(clear, "indoors the muffle lifts")
	# the four new story props
	var want: PackedStringArray = ["INT_M4D_DELIVERY_LOG", "INT_M4D_HAAS_TAG", "INT_M4D_RELAY_CARD", "INT_M4D_FLIGHT_CARD"]
	var found: int = 0
	for sp: Node in get_tree().get_nodes_in_group(&"story_props"):
		if want.has(String(sp.get("intel_id"))):
			found += 1
	_check(found == 4, "the four new story props are in the act (%d)" % found)
	# Obergefreiter Pohl
	var pohl: ExtraPerson = _map.get_node_or_null("Person_pohl") as ExtraPerson
	_check(pohl != null and pohl.bodies.size() == 1, "Pohl stands in the racks")
	if pohl != null:
		_check(pohl.global_position.distance_to(Vector3(30.4, 0, 39.9)) < 3.0 or pohl.spot().distance_to(Vector3(30.4, 0, 39.9)) < 3.0, "by his bay, rack 2")
		await _tp(pohl.spot() + Vector3(0, 0, -1.6), 180.0)
		pohl.on_talk(_p)
		await _frames(3)
		_check(pohl._card != null and str(pohl._card.title) == "OBERGEFREITER POHL", "his Talk card")
		pohl.accept_favour(_p)
		await _frames(3)
		_check(int(pohl.favour) == int(ExtraPerson.Favour.HAVE), "he asks: you carry his tag at once")
		_check(_said("OGP_PEOPLE_ASK_01") or _said("OGP_PEOPLE_TALK"), "his voice (%s)" % str(_vo.slice(-3)))
		if pohl._card != null:
			pohl._card.queue_free()
		GameState.set_flag(&"account_open")
		GameState.open_zone(&"F_CORE")
		var slot: TagSlot = _first(&"tag_slot") as TagSlot
		_check(slot != null and slot.can_interact(_p), "the console's slot takes the tag")
		if slot != null:
			var jak: Node = Node.new()
			jak.add_to_group(&"jakub")
			add_child(jak)
			await _tp(slot.global_position + Vector3(1.0, 0, 0))
			var s0: int = Economy.get_scrip(1)
			slot.interact(_p)
			await _frames(5)
			_check(int(pohl.favour) == int(ExtraPerson.Favour.DONE) and GameState.has_flag(&"pohl_tag_read"), "his name is read into the record")
			_check(Economy.get_scrip(1) > s0, "the favour pays (%d Scrip)" % (Economy.get_scrip(1) - s0))
			var jk: bool = await _until(func() -> bool: return _said("JAK_M4D_CONSOLE_01"), 3.0)
			_check(jk, "Jakub at the console (when he is with the squad)")
			jak.queue_free()
	# the smile: a note on first sight
	var ctl: Node = _first(&"mondlicht_controller")
	await _tp(Vector3(0, 0, 96))
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam != null:
		cam.look_at(Vector3(0.0, 30.0, 214.0))
	var seen: bool = await _until(func() -> bool: return bool(ctl.get("smile_seen")), 3.0)
	if not seen and ctl != null:
		ctl.call("mark_smile")
	_check(bool(ctl.get("smile_seen")), "the smile gets its minimap note on first sight (by the camera: %s)" % str(seen))
	for spk: String in ["dut", "peg", "dea", "wrn"]:
		_check(FileAccess.file_exists("res://gravelight/audio/vo/%s/%s_M4D_SMILE_01.ogg" % [spk, spk.to_upper()]), "the smile's line is recorded (%s)" % spk.to_upper())
	await _tp(Vector3(0, 0, 8))
