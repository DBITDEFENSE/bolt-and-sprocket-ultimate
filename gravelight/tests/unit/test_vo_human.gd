extends GutTest
## T-101 (UPDATE 06 Part B): recorded takes from the cast replace the TTS line by line; everything else keeps the
## computer voice. The manifests say where each line's audio comes from, the files they name exist, and the game's
## hooks for recorded audio (the Cousins' boss lines, Bolt & Sprocket's recorded-length subtitles, the voice test log)
## work without any recording present.

const GL_MANIFEST: String = "res://data/gravelight/vo/audio_manifest.json"
const BS_MANIFEST: String = "res://data/bs/vo/audio_manifest.json"


func after_each() -> void:
	GLVO.voice_test = false
	GLVO.voice_log.clear()


func test_every_gravelight_row_names_its_source_and_its_file_exists() -> void:
	var files: Dictionary = GLData.load_json(GL_MANIFEST).get("files", {})
	assert_gt(files.size(), 1000)
	var bad: Array[String] = []
	for fid: Variant in files.keys():
		var row: Dictionary = files[fid]
		var src: String = str(row.get("source", ""))
		if not (src in ["tts", "human"] or src.begins_with("ai_")):
			bad.append("%s: source '%s'" % [fid, src])
			continue
		if not (ResourceLoader.exists(str(row["path"])) or FileAccess.file_exists(str(row["path"]))):
			bad.append("%s: missing %s" % [fid, row["path"]])
		if src != "tts":
			assert_true(row.has("actor") and row.has("take") and row.has("hash"), "%s: a recorded row has actor, take, hash" % fid)
	assert_eq(bad, [] as Array[String], "every line's audio is where the manifest says (no missing-audio lines)")


func test_bs_manifest_lists_every_voiced_line() -> void:
	var files: Dictionary = GLData.load_json(BS_MANIFEST).get("files", {})
	assert_gt(files.size(), 500, "data/bs/vo/audio_manifest.json lists the B&S voiced lines")
	for fid: Variant in files.keys():
		var row: Dictionary = files[fid]
		if str(row.get("source", "")) == "tts":
			continue
		assert_true(ResourceLoader.exists(str(row["path"])) or FileAccess.file_exists(str(row["path"])), str(fid))


func test_tts_fallback_for_lines_without_a_take() -> void:
	# a line nobody recorded still resolves to its baked TTS file
	assert_ne(GLVO.audio_path(&"DUT_RELOAD_01"), "", "DUT_RELOAD_01 has audio")
	var row: Dictionary = (GLData.load_json(GL_MANIFEST).get("files", {}) as Dictionary).get("DUT_RELOAD_01", {})
	assert_true(str(row.get("source", "")) in ["tts", "human"])


func test_play_external_without_a_file_is_silent() -> void:
	assert_eq(GLVO.play_external("HAM_THROW_01_NOPE", "HAM"), 0.0, "no recorded take: no audio, the subtitle shows as before")


func test_voice_test_logs_the_source() -> void:
	GLVO.voice_test = true
	GLVO.play_external("HAM_THROW_01_NOPE", "HAM")
	assert_eq(GLVO.voice_log.size(), 1)
	assert_eq(str(GLVO.voice_log[0]["source"]), "none")
	assert_true(GLVO.source_of("DUT_RELOAD_01").begins_with("tts") or GLVO.source_of("DUT_RELOAD_01").begins_with("human"))
	assert_string_contains(GLVO.voice_test_report(), "Voice test: 1 lines")


func test_bs_recorded_length_is_zero_without_a_take() -> void:
	assert_eq(VOManager.recorded_length("cs.lrSignal.01_nope"), 0.0)
