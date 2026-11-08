extends GutTest
## T-205: the voices sit in their room (VORoomAcoustics, data/gravelight/vo_rooms.json): the VO bus's EQ + reverb,
## the VODry bus for lines with their own channel, the preset per map / zone / cutscene set, the setting that turns it
## off. Headless: the effects' parameters are checked, nothing is listened to.

const FX_PATH: String = "res://data/voice/fx.json"
const MAX_WET: float = 0.18   # "you notice it when it is gone, not when it is on"

var _setting_was: Variant = true


func before_each() -> void:
	_setting_was = GLSettings.values.get("vo_room_acoustics", true)


func after_each() -> void:
	GLSettings.values["vo_room_acoustics"] = _setting_was
	var r: VORoomAcoustics = GLVO.rooms
	r.map_override = &""
	r.map_id = &""
	r.zone = &""
	r.listener = null
	r.cinema_preset = &""
	r.refresh(true)


func _rooms() -> VORoomAcoustics:
	return GLVO.rooms


func test_the_buses_and_effects_exist() -> void:
	var r: VORoomAcoustics = _rooms()
	assert_not_null(r, "GLVO owns the room")
	var vo: int = AudioServer.get_bus_index(&"VO")
	var dry: int = AudioServer.get_bus_index(&"VODry")
	assert_true(vo >= 0 and dry >= 0, "the VO and VODry buses")
	assert_eq(AudioServer.get_bus_send(dry), &"Master", "VODry goes straight to Master (no room)")
	assert_true(r.effect_index(VORoomAcoustics.EQ_NAME) >= 0, "the EQ on the VO bus")
	assert_true(r.effect_index(VORoomAcoustics.REVERB_NAME) >= 0, "the reverb on the VO bus")
	assert_true(AudioServer.get_bus_effect(vo, r.effect_index(VORoomAcoustics.REVERB_NAME)) is AudioEffectReverb)
	assert_true(AudioServer.get_bus_effect(vo, r.effect_index(VORoomAcoustics.EQ_NAME)) is AudioEffectEQ6)
	r.ensure_buses()
	var n: int = 0
	for i: int in AudioServer.get_bus_effect_count(vo):
		if AudioServer.get_bus_effect(vo, i).resource_name == VORoomAcoustics.REVERB_NAME:
			n += 1
	assert_eq(n, 1, "ensure_buses twice adds nothing")
	assert_eq(str(AudioDirector.VOLUME_KEYS.get("VODry", "")), "vol_vo", "VODry follows the Voices volume")


func test_every_preset_is_known_and_gentle() -> void:
	var r: VORoomAcoustics = _rooms()
	var ps: Dictionary = r.presets()
	for id: String in ["dry", "radio", "room_wood", "cellar_stone", "mine_tunnel", "outdoor", "plane_cabin"]:
		assert_true(ps.has(id), "preset %s" % id)
	for id: Variant in ps.keys():
		var w: float = float((ps[id] as Dictionary).get("wet", 0.0))
		assert_true(w >= 0.0 and w <= MAX_WET, "%s: wet %.2f is subtle" % [id, w])
		var eq: Array = (ps[id] as Dictionary).get("eq", [])
		assert_true(eq.size() == 0 or eq.size() == 6, "%s: six EQ bands or none" % id)
		for g: Variant in eq:
			assert_true(absf(float(g)) <= 9.0, "%s: a gentle EQ" % id)
	assert_eq(float(ps["dry"].get("wet", 0.0)), 0.0, "dry is dry")
	for m: Variant in (r.data["maps"] as Dictionary).keys():
		var md: Dictionary = r.data["maps"][m]
		assert_true(ps.has(str(md["default"])), "%s default %s" % [m, md["default"]])
		for z: Variant in (md.get("zones", {}) as Dictionary).keys():
			assert_true(ps.has(str(md["zones"][z])), "%s/%s -> %s" % [m, z, md["zones"][z]])
	for s: Variant in (r.data["cinema_sets"] as Dictionary).keys():
		assert_true(ps.has(str(r.data["cinema_sets"][s])), "set %s" % s)


func test_every_map_and_cutscene_set_has_a_room() -> void:
	var r: VORoomAcoustics = _rooms()
	var maps: Dictionary = r.data.get("maps", {})
	for m: String in ["map00_crossroads", "map01_kaltenbrunn", "map02_totenhafen", "map04a_thalbach", "map04b_kranich",
			"map04c_groomlake", "map04d_mondlicht"]:
		assert_true(maps.has(m), "%s has a room" % m)
	var cut: Dictionary = GLData.load_json("res://data/gravelight/cutscenes_lazarus.json")
	for sid: Variant in (cut.get("sets", {}) as Dictionary).keys():
		assert_true((r.data["cinema_sets"] as Dictionary).has(str(sid)), "cutscene set %s has a room" % sid)
	# every zone named in the table is a real ZoneVolume id in the map scenes
	var ids: Dictionary = {}
	_scan_zone_ids("res://gravelight/maps/", ids)
	for m: Variant in maps.keys():
		for z: Variant in ((maps[m] as Dictionary).get("zones", {}) as Dictionary).keys():
			assert_true(ids.has(str(z)), "%s: zone %s exists in the map scenes" % [m, z])


func _scan_zone_ids(dir: String, into: Dictionary) -> void:
	var re: RegEx = RegEx.create_from_string("zone_id = &\"([A-Za-z0-9_]+)\"")
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".tscn"):
			for mt: RegExMatch in re.search_all(FileAccess.get_file_as_string(dir + f)):
				into[mt.get_string(1)] = true
	for d: String in DirAccess.get_directories_at(dir):
		_scan_zone_ids(dir + d + "/", into)


func test_the_preset_per_map_zone_and_shot() -> void:
	var r: VORoomAcoustics = _rooms()
	assert_eq(r.preset_for_map(&"map00_crossroads", &"TAPROOM"), &"room_wood", "the inn's taproom: a small wooden room")
	assert_eq(r.preset_for_map(&"map00_crossroads", &"CELLAR"), &"cellar_stone", "the cellar: stone")
	assert_eq(r.preset_for_map(&"map00_crossroads", &"GROUNDS"), &"outdoor", "the grounds: outdoors")
	assert_eq(r.preset_for_map(&"map00_crossroads"), &"outdoor", "the map's default")
	assert_eq(r.preset_for_map(&"map01_kaltenbrunn", &"E_LIFT"), &"mine_tunnel", "the mine")
	assert_eq(r.preset_for_map(&"map04b_kranich", &"F_COCKPIT"), &"plane_cabin", "the Kranich: a plane cabin everywhere")
	assert_eq(r.preset_for_map(&"map04d_mondlicht", &"C_YARD"), &"suit_radio", "the vacuum yard: through the suits")
	assert_eq(r.preset_for_map(&"no_such_map", &"TAPROOM"), &"dry", "a map without a room: dry")
	assert_eq(r.preset_for_map(&"map00_crossroads", &"NO_ZONE"), &"outdoor", "an unknown zone: the map's default")
	assert_eq(r.preset_for_shot("crypt"), &"cellar_stone", "the crypt")
	assert_eq(r.preset_for_shot("c47"), &"plane_cabin", "GRAVELIGHT ONE's cabin")
	assert_eq(r.preset_for_shot("front"), &"dugout", "the observation post")
	assert_eq(r.preset_for_shot("village", {"vo_room": "cellar_stone"}), &"cellar_stone", "a shot's own vo_room wins")
	assert_eq(r.preset_for_shot("nowhere"), &"dry", "an unknown set: dry")


func test_resolve_order_zone_cinema_and_the_setting() -> void:
	var r: VORoomAcoustics = _rooms()
	GLSettings.values["vo_room_acoustics"] = true
	var zv: ZoneVolume = ZoneVolume.new()
	zv.zone_id = &"TAPROOM"
	zv.size = Vector3(4, 4, 4)
	add_child_autofree(zv)
	var who: Node3D = Node3D.new()
	add_child_autofree(who)
	who.global_position = Vector3(0, 1, 0)
	r.listener = who
	r.map_override = &"map00_crossroads"
	r._track_map()
	r._track_zone()
	assert_eq(r.zone, &"TAPROOM", "the zone under the listener")
	r.refresh(true)
	assert_eq(r.preset_id, &"room_wood", "in the taproom: the wooden room")
	assert_almost_eq(r.reverb().wet, 0.09, 0.001, "the preset's wet is on the reverb")
	assert_true(r.effects_enabled(), "the room is on")
	who.global_position = Vector3(50, 1, 50)
	r._track_zone()
	assert_eq(r.zone, &"TAPROOM", "between boxes the last zone holds")
	r.set_cinema(r.preset_for_shot("crypt"))
	r.refresh(true)
	assert_eq(r.preset_id, &"cellar_stone", "a cutscene's set wins over the map")
	r.clear_cinema()
	r.refresh(true)
	assert_eq(r.preset_id, &"room_wood", "the reel's end hands the room back")
	GLSettings.values["vo_room_acoustics"] = false
	r.refresh(true)
	assert_eq(r.preset_id, &"dry", "the setting off: dry")
	assert_false(r.effects_enabled(), "off: both effects disabled")
	GLSettings.values["vo_room_acoustics"] = true
	r.map_override = &""
	r.map_id = &""
	r.refresh(true)
	assert_eq(r.preset_id, &"dry", "no map (the menu): dry")


func test_a_crossfade_moves_toward_the_new_room() -> void:
	var r: VORoomAcoustics = _rooms()
	GLSettings.values["vo_room_acoustics"] = true
	r.map_override = &"map01_kaltenbrunn"
	r.zone = &""
	r.map_id = &"map01_kaltenbrunn"
	r.refresh(true)
	assert_eq(r.preset_id, &"outdoor")
	r.zone = &"F_CHAPEL"
	r.refresh()
	r._process(r.fade_s * 0.5 if r.fade_s > 0.0 else 0.1)   # (the poll re-picks the same preset)
	var target: float = float(r.values_of(&"church_stone")["wet"])
	assert_true(r.reverb().wet > float(r.values_of(&"outdoor")["wet"]) and r.reverb().wet <= target + 0.0001, "half way between the rooms")
	r._process(r.fade_s + 0.1)
	assert_almost_eq(r.reverb().wet, target, 0.001, "then the chapel")


func test_lines_with_their_own_channel_play_dry() -> void:
	var r: VORoomAcoustics = _rooms()
	assert_eq(r.bus_for(&"OPR", "ROUND_START", "Good evening!"), &"VODry", "the Operator's tannoy has its channel")
	assert_eq(r.bus_for(&"DUT", "KILL", "Got him."), &"VO", "a survivor in the room")
	assert_eq(r.bus_for(&"SEL", "GL1", "[intercom] Pilot to passengers."), &"VODry", "an [intercom] cue")
	assert_eq(r.bus_for(&"SEL", "GL1", "[faint] [exhausted] ...Is anyone..."), &"VO", "a faint line is in the cabin")
	assert_eq(r.bus_for(&"XYZ", "", "[pa, faint, private] hello"), &"VODry", "a [pa] cue (a whole word)")
	assert_eq(r.bus_for(&"XYZ", "", "[a pause] Paul?"), &"VO", "'pause' is not 'pa'")
	assert_eq(r.bus_for(&"PAU", "PA", "WHERE'S MY SQUAD?!"), &"VODry", "PAUL's PA category")
	assert_eq(r.bus_for(&"PAU", "CALM", "Easy."), &"VO", "PAUL in person")
	assert_eq(GLVO.bus_for_line(&"NO_SUCH_LINE_XYZ"), &"VO", "an unknown line: the room")


func test_the_dry_list_matches_the_bake_channels() -> void:
	var r: VORoomAcoustics = _rooms()
	var fx: Dictionary = GLData.load_json(FX_PATH)
	var gl: Dictionary = (fx.get("characters", {}) as Dictionary).get("gl", {})
	var dry: Array = r.data.get("dry_speakers", [])
	var dcat: Dictionary = r.data.get("dry_categories", {})
	assert_false(gl.is_empty(), "fx.json's Gravelight characters")
	for spk: String in gl.keys():
		if spk.begins_with("_"):
			continue
		var e: Variant = gl[spk]
		var chain: String = str(e) if e is String else str((e as Dictionary).get("chain", "clean"))
		if chain != "clean":
			assert_true(dry.has(spk), "%s (%s) already has its channel: dry" % [spk, chain])
		else:
			assert_false(dry.has(spk), "%s is clean in the bake: it gets the room" % spk)
		if e is Dictionary:
			for cat: String in ((e as Dictionary).get("by_category", {}) as Dictionary).keys():
				if str(e["by_category"][cat]) != "clean" and chain == "clean":
					assert_true(dcat.has(spk) and (dcat[spk] as Array).has(cat), "%s:%s has its channel: dry" % [spk, cat])


func test_glvo_plays_a_line_on_its_bus() -> void:
	var opr: StringName = &""
	var dut: StringName = &""
	for k: Variant in GLVO.lines.keys():
		var sp: String = str((GLVO.lines[k] as Dictionary).get("speaker", ""))
		if sp == "OPR" and opr == &"":
			opr = StringName(str(k))
		elif sp == "DUT" and dut == &"" and not str((GLVO.lines[k] as Dictionary).get("text", "")).contains("["):
			dut = StringName(str(k))
	assert_eq(GLVO.bus_for_line(opr), &"VODry", "an Operator line: VODry")
	assert_eq(GLVO.bus_for_line(dut), &"VO", "a Dutch line: the room")
	GLVO.stop_all()
	var before: int = GLVO.audio_plays
	GLVO.play_local(opr)
	if GLVO.audio_plays > before:
		assert_eq(GLVO._story_2d.bus, &"VODry", "the story player went to VODry for it")
	else:
		pass_test("no baked take for %s here (the subtitle only)" % opr)
	GLVO.stop_all()
