extends Node
## UPDATE 10 section 2 (T-154): Totenhafen's living world, headless. Loads map02, checks MapRoot attached the
## MapAmbience with map02_ambience.json and every kind found its pieces, then forces the beats: the gulls at a shot,
## rounds 6 (Mosquitoes + flak), 10 (the lighthouse goes dark), 12 (the raid: bombs, the hall shakes, lamps and
## chains swing, dust, icicles, the Operator), 15 (the cutter slips: the hull moves, the remnant shows, the flag, the
## letter), the power-on sequence (pumps, drain, the dock-by-dock sweep, perk stings, U-1047 red to white, the
## conveyor jolt), the egg's bell (once), the storm on a spring tide, footprints, radio, spills, waves, ships.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_map02_world.tscn

const MAP: String = "res://gravelight/maps/map02_totenhafen/map02.tscn"

var _map: Node3D
var _amb: MapAmbience
var _p: Player
var _fails: PackedStringArray = []
var _vo: Array[StringName] = []


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile_m2world.json"
	ProfileSave.profile = ProfileSave.new_profile()
	ProfileSave.profile[JakubCompanion.PROFILE_KEY] = "joined"   # T-170: the profile's Jakub arrives with you (his M2 beats)
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GLBus.vo_line_started.connect(func(i: StringName, _s: StringName, _t: String, _d: float) -> void: _vo.append(i))
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _check(cond: bool, what: String) -> void:
	print("[m2world] %-66s %s" % [what, "ok" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _n(kind: String) -> int:
	return int(_amb.counts.get(kind, 0))


func _run() -> void:
	await _frames(20)
	_p = _map.get_node_or_null("Player1") as Player
	RoundManager.stop()
	GameState.god_mode = true
	_amb = _map.get_node_or_null("MapAmbience") as MapAmbience
	_check(_amb != null, "MapRoot attached a MapAmbience")
	if _amb == null:
		_finish()
		return
	_check(_amb.config_path.ends_with("map02_ambience.json"), "it reads map02_ambience.json")
	await _frames(10)
	_amb.delay_scale = 0.05
	_check(_amb.gulls != null and _amb.gulls.crows.size() >= 8, "gulls on the parapet (%d)" % (_amb.gulls.crows.size() if _amb.gulls != null else 0))
	_check(_amb._lh_pivot != null, "the lighthouse's beam built on the Lighthouse marker")
	_check(_amb._bell != null, "the cliff church's bell pivot found")
	_check(_amb.sway != null and _amb.sway.lamps.size() >= 6, "swinging pendants in the hall (%d)" % _amb.sway.lamps.size())
	_check(_amb.chain_sway != null and _amb.chain_sway.lamps.size() >= 5, "chains and pulley blocks (%d)" % (_amb.chain_sway.lamps.size() if _amb.chain_sway != null else 0))
	_check(_amb._dust_points.size() >= 20, "dust points under the roof (%d)" % _amb._dust_points.size())
	_check(_amb._icicles.size() >= 10, "icicles (%d)" % _amb._icicles.size())
	_check(_amb._crates.size() >= 4, "fish crates (%d)" % _amb._crates.size())
	_check(_amb._cans != null, "the conveyor's cans")
	_check(_amb._lightnings.size() >= 2, "lightning over the mouth and the north storm (%d)" % _amb._lightnings.size())
	_check(_amb._rain_mats.size() >= 1, "rain on the tower glass")
	_check(_amb._fire_lights.size() >= 2 and _amb._dbeam != null, "the burning freighter and the destroyer's searchlight")
	var letter: Node3D = _map.find_child("Story_INT_M2_SAILOR_LETTER", true, false) as Node3D
	_check(letter != null and not letter.visible, "the sailor's letter hidden under the cutter")
	for id: String in ["INT_M2_HALE_TELEGRAM", "INT_M2_PAYSLIP", "INT_M2_DRAWING", "INT_M2_RATION_BOOK"]:
		_check(_map.find_child("Story_" + id, true, false) != null, "story prop %s spawned" % id)

	# gulls scatter at the first shot
	var shot_at: Vector3 = (_amb.gulls.crows[0]["node"] as Node3D).global_position + Vector3(4, 0, 6)
	GLBus.weapon_fired.emit(1, &"m1911", false, shot_at, Vector3.FORWARD)
	await _frames(5)
	_check(_n("gulls_scatter") >= 1 and _amb.gulls.perched_count() < _amb.gulls.crows.size(), "the gulls scatter at the first shot")

	# round 6: the Mosquitoes' low pass with flak from the cliff
	GLBus.round_started.emit(6, false)
	await _secs(7.0)
	_check(_n("low_pass") == 1, "round 6: the Mosquitoes' low pass")
	_check(_n("flak") >= 4, "round 6: flak bursts round them (%d)" % _n("flak"))

	# round 10: the lighthouse goes dark
	_check(_amb.lighthouse_lit, "the lighthouse lit before round 10")
	GLBus.round_started.emit(10, false)
	await _secs(2.5)
	_check(not _amb.lighthouse_lit and _n("lighthouse_dark") == 1 and not _amb._lh_pivot.visible, "round 10: the lighthouse goes dark")

	# round 12: the raid
	var pend: Node3D = _amb.sway.lamps[0][0] as Node3D
	GLBus.round_started.emit(12, false)
	var swung: bool = false
	var chain_swung: bool = false
	for k: int in 40:
		await _secs(0.1)
		swung = swung or absf(pend.rotation.x) + absf(pend.rotation.z) > 0.01
		var cp: Node3D = _amb.chain_sway.lamps[0][0] as Node3D
		chain_swung = chain_swung or absf(cp.rotation.x) + absf(cp.rotation.z) > 0.01
	await _secs(2.0)
	_check(_n("raid") == 1, "round 12: the raid")
	_check(_n("raid_bomb") == int(_amb.cfg["raid"]["bombs"]["count"]), "the bomb walk across the pens (%d bombs)" % _n("raid_bomb"))
	_check(_n("hall_shake") >= 5, "the hall shakes (%d)" % _n("hall_shake"))
	_check(_n("lamp_sway") >= 1 and swung, "the lamps swing")
	_check(_n("chain_swing") >= 1 and chain_swung, "the chains swing")
	_check(_n("dust_burst") >= 3, "dust bursts from the ceiling points (%d)" % _n("dust_burst"))
	_check(_n("icicle_fall") >= 2, "icicles fall (%d)" % _n("icicle_fall"))
	_check(_n("raid_vo") == 1 or _vo.has(&"OPR_RAID_M2_01"), "the Operator complains about the schedule")

	# round 15: the cutter slips into the sea
	var hull: Node3D = _map.find_child("CutterHull", true, false) as Node3D
	var h0: Vector3 = hull.position if hull != null else Vector3.ZERO
	var rem: Node3D = _map.find_child("CutterRemnantPieces", true, false) as Node3D
	_check(rem != null and not rem.visible, "the cutter's remnant hidden before")
	GLBus.round_started.emit(15, false)
	await _secs(9.0)
	_check(_n("cutter_slip") == 1, "round 15: the cutter slips")
	_check(hull != null and hull.position.distance_to(h0) > 10.0 and hull.position.z < h0.z - 10.0, "the hull slid off into the sea (%.1f m)" % (hull.position.distance_to(h0) if hull != null else 0.0))
	_check(rem != null and rem.visible, "the cradle and wreckage show where it lay")
	_check(GameState.has_flag(&"cutter_slipped"), "the host sets cutter_slipped (the Surf_Cutter spawn's flag)")
	_check(letter != null and letter.visible and (letter as StoryProp).revealed(), "the sailor's letter is there now")

	# the power-on spectacle
	var dl: Array = []
	for n: Node in get_tree().get_nodes_in_group(&"power_lights"):
		if str(n.get_meta("zone", "")) == "D_PENHALL":
			dl.append(n)
	var delays: Array = []
	for l: Light3D in dl:
		delays.append(float(l.get_meta("sweep_delay", 0.0)))
	delays.sort()
	_check(dl.size() >= 6 and float(delays[0]) < float(delays[-1]) - 1.0, "the pen lamps carry a dock-by-dock sweep (%.1f..%.1f s)" % [delays[0], delays[-1]])
	var sw: PowerSwitch = _map.find_child("Pumpenschalter", true, false) as PowerSwitch
	var red0: float = _red_energy()
	sw.run_sequence(1)
	await _secs(3.0)
	var lit_early: int = 0
	for l2: Light3D in dl:
		if l2.visible and l2.light_energy > 0.01:
			lit_early += 1
	await _secs(6.0)
	var lit_late: int = 0
	for l3: Light3D in dl:
		if l3.visible and l3.light_energy > 0.01:
			lit_late += 1
	_check(_n("power_spectacle") == 1 and _n("pumps_thunder") == 1, "power: the pumps thunder")
	_check(lit_early < lit_late and lit_late == dl.size(), "power: the hall's lamps come on in a run (%d then %d of %d)" % [lit_early, lit_late, dl.size()])
	_check(_n("perk_sting") >= 5, "power: the perks wake with stings (%d)" % _n("perk_sting"))
	_check(_n("uboat_white") == 1 and _red_energy() < red0 * 0.5, "power: U-1047's battle lanterns give way (%.2f -> %.2f)" % [red0, _red_energy()])
	_check(_n("conveyor_jolt") == 1 and _amb.conveyor_running, "power: the conveyor jolts and runs")
	_check(_amb.drain_now > 0.2, "power: the docks drain (%.2f m)" % _amb.drain_now)

	# the egg's bell: one toll on egg_lf_started
	GameState.set_flag(&"egg_lf_started", true)
	await _frames(5)
	GameState.set_flag(&"egg_lf_started", true)
	await _secs(1.0)
	_check(_n("bell_toll") == 1, "the cliff bell tolls once on egg_lf_started")

	# the storm on a spring tide
	var sea: ShaderMaterial = _amb._sea_mat
	var amp0: float = float(sea.get_shader_parameter("amp")) if sea != null else 0.0
	if GLBus.has_signal(&"tide_stage"):
		GLBus.emit_signal(&"tide_stage", &"spring")
	else:
		_amb.debug_trigger("storm_spring")
	await _secs(5.0)
	_check(_amb.storm_k > 0.25 and sea != null and float(sea.get_shader_parameter("amp")) > amp0, "the storm rises with the spring tide (k %.2f)" % _amb.storm_k)

	# reactive details
	for kind: String in ["radio", "spill", "big_wave", "ship_guns", "star_shell"]:
		_amb.debug_trigger(kind)
	await _secs(1.0)
	_check(_n("radio_line") >= 1, "the radio crackles U-boat traffic")
	_check(_n("crate_spill") >= 1, "a fish crate spills")
	_check(_n("big_wave") >= 1, "spray bursts over the parapet")
	_check(_n("ship_guns") >= 1, "the ships' guns far out")
	_check(_n("star_shell") >= 1, "a star shell over the bay")
	if _p != null:
		_p.global_position = Vector3(16.0, 0.2, 20.0)
		await _frames(10)
		var p0: Vector3 = _p.global_position
		Input.action_press(&"move_forward")
		await _secs(2.5)
		Input.action_release(&"move_forward")
		await _frames(3)
		print("[m2world] walked %s -> %s, on floor %s, in players %s" % [p0, _p.global_position, _p.is_on_floor(), _p.is_in_group(&"players")])
		_check(_amb.footprints_showing() >= 2, "wet footprints behind the player (%d)" % _amb.footprints_showing())
	await _sendbacks()
	_finish()


func _until(pred: Callable, s: float) -> bool:
	var t: float = 0.0
	while t < s:
		if pred.call():
			return true
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	return pred.call()


func _said(id: StringName) -> bool:
	return _vo.has(id)


## UPDATE 10 section 9 send-backs (T-170), shown in a run: THE_BAR row 20 / 15 (Jessen at the Marinekasse's window with
## his favour and his reactions at the bank, Harms of the night shift with hers), row 5 (Hinnerk's stair scene on the
## first flood) and row 21 (Jakub's Totenhafen beats: the arrival, the first flood, the sail).
func _sendbacks() -> void:
	var people: Dictionary = {}
	for n: Node in get_tree().get_nodes_in_group(&"extra_people"):
		people[str(n.get("id"))] = n
	_check(people.has("jessen") and people.has("harms"), "two extra people on Totenhafen (%s)" % ", ".join(people.keys()))
	var j: ExtraPerson = people.get("jessen") as ExtraPerson
	var h: ExtraPerson = people.get("harms") as ExtraPerson
	if j != null and _p != null:
		_check(j.bodies.is_empty() and get_tree().get_first_node_in_group(&"bank_branch") != null, "Jessen is the Marinekasse's teller (BankBranch's body, no second one)")
		_p.global_position = j.spot() + Vector3(0, 0.1, 0.8)
		await _frames(3)
		j.on_talk(_p)
		await _frames(3)
		_check(j._card != null, "Jessen's Talk card opens at the pay window")
		_check(await _until(func() -> bool: return _said(&"JES_PEOPLE_TALK_01") or _said(&"JES_PEOPLE_TALK_02"), 4.0), "and he speaks")
		j.accept_favour(_p)
		_check(j.item != null and j.item.visible, "the ledger page appears in the Hafenmeister's hut (%s)" % (str(j.item.global_position) if j.item != null else "-"))
		if j._card != null:
			j._card.queue_free()
		await _frames(3)
		var scrip0: int = Economy.get_scrip(_p.player_id)
		j.item_taken(_p)
		j.give_item(_p)
		await _frames(3)
		_check(j.favour == ExtraPerson.Favour.DONE and Economy.get_scrip(_p.player_id) == scrip0 + 1000, "the page handed through the grille: the week closed, 1000 Scrip paid out")
		# row 15: a reaction at the bank: the ballast dump, then the boat's key
		GameState.set_flag(&"lf_ballast_done", true)
		await _frames(2)
		j.on_talk(_p)
		await _frames(3)
		_check(j._card != null and j._card.said.begins_with("Jessen has entered the three coffins"), "the dump is on his card")
		_check(await _until(func() -> bool: return _said(&"JES_PEOPLE_REACT_BALLAST_01"), 4.0), "and he enters it as lost at sea")
		if j._card != null:
			j._card.queue_free()
		await _frames(3)
		GameState.set_flag(&"boat_key", true)
		await _frames(2)
		j.on_talk(_p)
		await _frames(3)
		_check(await _until(func() -> bool: return _said(&"JES_PEOPLE_REACT_KEY_01"), 4.0), "the boat's key: he signs her out")
		if j._card != null:
			j._card.queue_free()
		await _frames(3)
	if h != null and _p != null:
		_check(h.bodies.size() == 1 and h.bodies[0].global_position.distance_to(Vector3(-3.2, 0, 9.0)) < 2.5, "Harms hides by the cannery office's desk")
		_p.global_position = h.spot() + Vector3(-1.0, 0.1, 0.0)
		await _frames(3)
		h.on_talk(_p)
		await _frames(3)
		_check(h._card != null, "Harms' Talk card opens")
		h.accept_favour(_p)
		_check(h.item != null and h.item.global_position.x < -20.0, "the storm lantern lies in the infirmary")
		if h._card != null:
			h._card.queue_free()
		await _frames(3)
		h.item_taken(_p)
		h.give_item(_p)
		_check(h.favour == ExtraPerson.Favour.DONE, "the lantern given: she listens to the hall (intel ping)")
		_check(await _until(func() -> bool: return _said(&"HRM_PEOPLE_PING_01") or _said(&"HRM_PEOPLE_THANKS_01"), 6.0), "and says where they are")
	# row 5: Hinnerk on the tower stair; the first flood plays his scene
	var hp: MapCompanion = _map.get_node_or_null("Companion_petersen") as MapCompanion
	_check(hp != null and hp.state == MapCompanion.State.WAITING and hp.player != null, "Hinnerk waits on the signal tower stair")
	var jk: JakubCompanion = _map.get_node_or_null("JakubCompanion") as JakubCompanion
	_check(jk != null and jk.state == JakubCompanion.State.JOINED, "the profile's Jakub arrived with the squad")
	_check(await _until(func() -> bool: return _said(&"JAK_M2_ARRIVE_01") or _said(&"JAK_M2_ARRIVE_02"), 12.0), "Jakub: the sea (JAK_M2_ARRIVE)")
	GLBus.tide_flood_begin.emit()
	_check(await _until(func() -> bool: return _said(&"PET_LF_TRAPPED_01"), 8.0), "the first flood: Hinnerk's stair scene (PET_LF_TRAPPED_01)")
	_check(hp != null and hp.events.has("scene") and not hp.play_scene(), "played once")
	_check(await _until(func() -> bool: return _said(&"JAK_M2_FLOOD_01"), 12.0), "Jakub: the water is coming in (JAK_M2_FLOOD_01)")
	GLBus.sail_started.emit()
	_check(await _until(func() -> bool: return _said(&"JAK_M2_SAIL_01"), 14.0), "Jakub: the sail (JAK_M2_SAIL_01)")


## The red battle lanterns' summed energy inside U-1047.
func _red_energy() -> float:
	var e: float = 0.0
	for n: Node in _map.find_children("*", "OmniLight3D", true, false):
		var l: OmniLight3D = n as OmniLight3D
		if l.light_color.r > 0.8 and l.light_color.g < 0.4 and MapAmbience._inside(l.global_position, [[4, -2.6, 38], [10, 1.5, 86]]):
			e += MapAmbience._light_e(l)
	return e


func _finish() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	print("[m2world] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)]))
	get_tree().quit(0 if _fails.is_empty() else 1)
