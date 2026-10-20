extends GutTest
## data/audio.json integrity (M6 audio pass): every referenced file exists and imports, every key the code
## calls resolves, buses/profiles/tiers/event keys point at real entries, loops loop, voice limits hold.

## Keys called by existing gameplay code (grep "AudioDirector\." --include=*.gd). Must keep resolving.
const LEGACY_KEYS: PackedStringArray = [
	"gun_pistol", "gun_rifle", "gun_smg", "gun_shotgun", "gun_dry", "reload_start", "reload_end", "bolt_cycle",
	"knife_swing", "knife_hit", "grenade_explode", "grenade_pin", "hitmarker", "headshot", "buy", "deny",
	"scrip_tick", "door_open", "player_hurt", "heartbeat", "board_break", "board_place", "board_slam",
	"zombie_groan", "zombie_attack", "zombie_death", "zombie_sprint", "round_start", "round_end", "game_over",
	"ambient_wind",
]

var bank: Dictionary


func before_all() -> void:
	bank = GLData.load_json(AudioDirector.BANK_PATH)


func test_bank_loads() -> void:
	assert_true(bank.has("sounds"), "audio.json has a sounds table")
	assert_gt((bank["sounds"] as Dictionary).size(), 100)


func test_every_file_exists_and_imports() -> void:
	var missing: Array[String] = []
	var count: int = 0
	for key: String in (bank["sounds"] as Dictionary).keys():
		var e: Dictionary = bank["sounds"][key]
		assert_false((e.get("files", []) as Array).is_empty(), "%s lists files" % key)
		for f: Variant in e.get("files", []):
			count += 1
			var path: String = str(f)
			if not FileAccess.file_exists(path) or not ResourceLoader.exists(path):
				missing.append("%s -> %s" % [key, path])
	assert_eq(missing.size(), 0, "missing/unimported files: %s" % [missing])
	assert_gt(count, 300)


func test_entries_use_known_buses_and_profiles() -> void:
	var profiles: Dictionary = bank.get("attenuation", {})
	for key: String in (bank["sounds"] as Dictionary).keys():
		var e: Dictionary = bank["sounds"][key]
		var bus_name: String = str(e.get("bus", "SFX"))
		assert_true(AudioServer.get_bus_index(bus_name) >= 0, "%s: bus %s exists" % [key, bus_name])
		assert_true(profiles.has(str(e.get("attenuation", "world"))), "%s: attenuation profile exists" % key)
		var pitch: Array = e.get("pitch", [1.0, 1.0])
		assert_eq(pitch.size(), 2, "%s: pitch is a [min, max] range" % key)
		assert_true(float(pitch[0]) > 0.0 and float(pitch[0]) <= float(pitch[1]), "%s: pitch range sane" % key)
		assert_gt(int(e.get("max_voices", 1)), 0, "%s: max_voices > 0" % key)


func test_buses_exist() -> void:
	for bus_name: String in ["Master", "Music", "SFX", "VO", "Jingles", "Ambience"]:
		assert_true(AudioServer.get_bus_index(bus_name) >= 0, "bus " + bus_name)


func test_legacy_keys_resolve() -> void:
	for key: String in LEGACY_KEYS:
		assert_true((bank["sounds"] as Dictionary).has(key), "bank has legacy key " + key)
		assert_true(AudioDirector.has_sound(key), "legacy key resolves: " + key)


func test_music_and_event_keys_exist() -> void:
	var sounds: Dictionary = bank["sounds"]
	var music: Dictionary = bank["music"]
	for field: String in ["round_start_tiers", "round_end_tiers"]:
		for pair: Variant in music[field]:
			assert_true(sounds.has(str((pair as Array)[1])), "%s key %s" % [field, (pair as Array)[1]])
	for field: String in ["special_start", "special_end", "game_over", "score"]:
		assert_true(sounds.has(str(music[field])), "music.%s" % field)
	for map_key: String in (music["ambient"] as Dictionary).keys():
		assert_true(sounds.has(str(music["ambient"][map_key])), "ambient for " + map_key)
	for ev: String in (bank["events"] as Dictionary).keys():
		var v: Variant = bank["events"][ev]
		if v is Dictionary:
			for k: String in (v as Dictionary).keys():
				assert_true(sounds.has(str((v as Dictionary)[k])), "event %s.%s" % [ev, k])
		elif not ev.ends_with("_prefix"):
			assert_true(sounds.has(str(v)), "event " + ev)


func test_every_perk_has_a_hum_and_every_powerup_a_grab() -> void:
	var sounds: Dictionary = bank["sounds"]
	var prefix: String = str(bank["perk_hum"]["prefix"])
	for perk_id: String in (GLData.table("perks")["perks"] as Dictionary).keys():
		assert_true(sounds.has(prefix + perk_id), "hum for " + perk_id)
	var grab: String = str(bank["events"]["powerup_collected_prefix"])
	for pu: String in (GLData.table("powerups")["names"] as Dictionary).keys():
		assert_true(sounds.has(grab + pu), "grab sound for " + pu)


func test_loop_keys_loop() -> void:
	for key: String in (bank["sounds"] as Dictionary).keys():
		if not bool(bank["sounds"][key].get("loop", false)):
			continue
		var list: Array = AudioDirector._streams(key)
		assert_false(list.is_empty(), key)
		for s: Variant in list:
			if s is AudioStreamWAV:
				assert_ne((s as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_DISABLED, "%s loops" % key)


func test_voice_limit_per_key() -> void:
	var limit: int = int(bank["sounds"]["zombie_attack"]["max_voices"])
	for i: int in limit + 4:
		AudioDirector.play_3d("zombie_attack", Vector3(i, 0, 0))
		AudioDirector.play_2d("zombie_attack")
	assert_lte(AudioDirector._voice_list("zombie_attack|3d").size(), limit)
	assert_lte(AudioDirector._voice_list("zombie_attack|2d").size(), limit)
	for p: AudioStreamPlayer3D in AudioDirector._pool3d:
		p.stop()
	for q: AudioStreamPlayer in AudioDirector._pool2d:
		q.stop()


func test_unknown_key_is_silent() -> void:
	assert_null(AudioDirector.play_2d("no_such_sound_key"))
	assert_null(AudioDirector.play_3d("no_such_sound_key", Vector3.ZERO))
	assert_false(AudioDirector.has_sound("no_such_sound_key"))


func test_stinger_tiers_by_round() -> void:
	assert_eq(AudioDirector._tier_key("round_start_tiers", 1, ""), "stinger_round_start_r01")
	assert_eq(AudioDirector._tier_key("round_start_tiers", 9, ""), "stinger_round_start")
	assert_eq(AudioDirector._tier_key("round_start_tiers", 31, ""), "stinger_round_start_r30")
	assert_eq(AudioDirector._tier_key("round_end_tiers", 26, ""), "stinger_round_end_late")
	assert_almost_eq(AudioDirector.stinger_downbeat("stinger_round_start"), 2.4, 0.001)
