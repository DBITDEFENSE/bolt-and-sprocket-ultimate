extends GutTest
## The squad's voices (T-073): the neural cast in voice_cast.json, the baked loudness, the squad anti-echo, the
## shuffle-bag seam and the positional voices' occlusion.

const MANIFEST: String = "res://data/gravelight/vo/audio_manifest.json"
const CAST: String = "res://data/gravelight/vo/voice_cast.json"
const SQUAD: Array[String] = ["DUT", "PEG", "DEA", "WRN", "JAK"]


func before_each() -> void:
	GLVO.always_pass_chance = true
	GLVO.reset_match()


func after_each() -> void:
	GLVO.always_pass_chance = false
	GLVO.reset_match()


func test_cast_gives_every_survivor_a_distinct_voice() -> void:
	var cast: Dictionary = GLData.load_json(CAST).get("cast", {})
	var voices: Dictionary = {}
	for spk: String in SQUAD:
		assert_true(cast.has(spk), "voice_cast.json casts " + spk)
		var v: String = str((cast.get(spk, {}) as Dictionary).get("voice", ""))
		assert_ne(v, "", spk + " has a voice")
		assert_false(voices.has(v), spk + " does not share a voice with " + str(voices.get(v, "")))
		voices[v] = spk


func test_neural_lines_are_loudness_normalised() -> void:
	var cast: Dictionary = GLData.load_json(CAST)
	var target: float = float(cast["loudness"]["target_lufs"])
	var emotions: Dictionary = cast["emotions"]
	var files: Dictionary = GLData.load_json(MANIFEST).get("files", {})
	var n: int = 0
	for fid: Variant in files.keys():
		var row: Dictionary = files[fid]
		if str(row.get("engine", "")) != "kokoro":
			continue
		n += 1
		var emo: Dictionary = emotions.get(str(row.get("delivery", "calm")), {})
		var want: float = target + float(emo.get("lufs", 0.0)) * float((cast["cast"][row["speaker"]] as Dictionary).get("emotion_scale", 1.0))
		assert_almost_eq(float(row.get("lufs", 0.0)), want, 1.0, "%s at its delivery's loudness" % fid)
	gut.p("%d neural lines checked" % n)


func test_squad_echo_keeps_a_second_bot_quiet() -> void:
	assert_true(GLVO.play_category(&"DUT", "RELOAD"), "Dutch calls his reload")
	assert_true(GLVO.echo_blocked(&"PEG", "RELOAD"), "Peg doesn't echo it straight away")
	assert_true(GLVO.echo_blocked(&"JAK", "RELOAD"), "nor does Jakub")
	assert_false(GLVO.echo_blocked(&"DUT", "RELOAD"), "his own repeats are the cooldown's business")
	assert_false(GLVO.echo_blocked(&"PEG", "DOWN"), "downs are never echo-limited")
	assert_false(GLVO.echo_blocked(&"OPR", "RELOAD"), "only the squad")
	GLVO.advance(6.0)
	assert_false(GLVO.echo_blocked(&"PEG", "RELOAD"), "after the window anyone may")


func test_refilled_bag_never_repeats_at_the_seam() -> void:
	var key: String = "DUT:HEADSHOT"
	assert_gt((GLVO._index.get(key, []) as Array).size(), 1)
	var last: StringName = &""
	for i: int in 300:
		var id: StringName = GLVO._draw(key)
		assert_ne(id, last, "no back-to-back repeat (draw %d)" % i)
		last = id


func test_occlusion_muffles_and_restores_a_positional_voice() -> void:
	var p3: AudioStreamPlayer3D = GLVO._squad_3d
	var au: Dictionary = GLVO.rules.get("audio", {})
	GLVO.set_occlusion(p3, 1.0)
	assert_almost_eq(p3.attenuation_filter_cutoff_hz, float(au.get("occlusion_cutoff_hz", 1100.0)), 1.0)
	assert_almost_eq(p3.volume_db, float(au.get("squad_volume_db", 0.0)) + float(au.get("occlusion_db", -5.0)), 0.01)
	GLVO.set_occlusion(p3, 0.0)
	assert_almost_eq(p3.attenuation_filter_cutoff_hz, float(au.get("occlusion_open_hz", 5000.0)), 1.0)
	assert_almost_eq(p3.volume_db, float(au.get("squad_volume_db", 0.0)), 0.01)
	assert_eq(GLVO.occlusion_of(p3), 0.0)
