extends GutTest
## T-191 (UPDATE 11 contract C3): foreign-language lines carry what is said in `speech` and the English subtitle in
## `text`; the subtitle the player reads is always `text` (gravelight/ui/subtitles.gd shows the VOManager's text, which
## never reads `speech`), so no subtitle may hold Cyrillic. The subtitle face (IBM Plex Sans) does have Cyrillic glyphs,
## the stamp and typewriter faces of the title cards do not: the cutscene cards stay in Latin letters.

const LINES: String = "res://data/gravelight/vo/lines.json"
const CYRILLIC_LO: int = 0x0400
const CYRILLIC_HI: int = 0x04FF


static func has_cyrillic(s: String) -> bool:
	for i: int in s.length():
		var c: int = s.unicode_at(i)
		if c >= CYRILLIC_LO and c <= CYRILLIC_HI:
			return true
	return false


func test_no_subtitle_shows_cyrillic() -> void:
	var lines: Dictionary = GLData.load_json(LINES)
	assert_gt(lines.size(), 2500, "the LAZARUS lines are in")
	var bad: PackedStringArray = []
	for id: String in lines.keys():
		var rec: Dictionary = lines[id]
		if has_cyrillic(str(rec.get("text", ""))):
			bad.append(id)
		if rec.has("exchange"):
			for part: Variant in rec["exchange"] as Array:
				if part is Array and (part as Array).size() > 1 and has_cyrillic(str(part[1])):
					bad.append(id)
	assert_eq(bad.size(), 0, "Cyrillic in a subtitle: " + ", ".join(bad))


func test_speech_lines_have_an_english_subtitle() -> void:
	var lines: Dictionary = GLData.load_json(LINES)
	var n: int = 0
	for id: String in lines.keys():
		var rec: Dictionary = lines[id]
		if not rec.has("speech"):
			continue
		n += 1
		assert_ne(str(rec["speech"]).strip_edges(), "", id + " says something")
		assert_ne(str(rec["text"]).strip_edges(), "", id + " has a subtitle")
		assert_false(str(rec["text"]).contains("<speech>"), id + ": the tag was extracted")
	assert_gte(n, 18, "the German lines of UPDATE 11 carry a spoken form")
	for id: String in ["REI_STB_01", "PA_STB_04", "RADIO_UBOAT_01"]:
		assert_true(lines.has(id) and (lines[id] as Dictionary).has("speech"), id + " is a speech line")
	# T-204: the Russian-speaking cast speaks English (with a Russian accent); the Russian lives in the language store
	for id: String in ["SEL_GL1_01", "DUT_GL1_01", "PEG_GL1_01", "DEA_GL1_01", "WRN_GL1_01",
			"SER_LZS_01", "VOL_LZS_07", "BRG_LZS_03", "SVR_FTD_01", "SVR_M0_01", "SVR_M1_01", "RTN_CLOSE_01"]:
		assert_true(lines.has(id) and not (lines[id] as Dictionary).has("speech"), id + " is English")


## T-204: every line of the Russian store keeps its Russian text and its baked Russian take, and the game plays the
## English take unless VOManager.voice_language asks for the Russian one.
func test_russian_store_keeps_the_russian_and_the_english_plays() -> void:
	var lines: Dictionary = GLData.load_json(LINES)
	var store: Dictionary = GLData.load_json("res://data/gravelight/vo/lang/ru.json")
	assert_eq(str(store.get("language", "")), "ru")
	var rows: Dictionary = store.get("lines", {})
	assert_gte(rows.size(), 85, "every Russian line is kept")
	var bad: PackedStringArray = []
	for id: String in rows.keys():
		var row: Dictionary = rows[id]
		var path: String = str((row.get("audio", {}) as Dictionary).get("path", ""))
		if not has_cyrillic(str(row.get("speech", ""))) or not path.begins_with("res://gravelight/audio/vo_lang/ru/") \
				or not ResourceLoader.exists(path) or not lines.has(id) or (lines[id] as Dictionary).has("speech"):
			bad.append(id)
	assert_eq(bad.size(), 0, "Russian store rows without their Russian text, take or English line: " + ", ".join(bad))
	var keep: String = GLVO.voice_language
	GLVO.voice_language = ""
	assert_eq(GLVO.audio_path(&"SER_LZS_01"), "res://gravelight/audio/vo/ser/SER_LZS_01.ogg", "the English take plays")
	GLVO.voice_language = "ru"
	assert_eq(GLVO.audio_path(&"SER_LZS_01"), "res://gravelight/audio/vo_lang/ru/ser/SER_LZS_01.ogg", "the Russian take on request")
	assert_eq(GLVO.audio_path(&"DUT_GL1_01"), "res://gravelight/audio/vo/dut/DUT_GL1_01.ogg", "a line with no Russian keeps its take")
	GLVO.voice_language = keep


func test_subtitle_strips_tags_and_keeps_the_english() -> void:
	var lines: Dictionary = GLData.load_json(LINES)
	var shown: String = GLVO.strip_tags(str((lines["VOL_LZS_07"] as Dictionary)["text"]))
	assert_eq(shown, "It's wet.")
	assert_false(has_cyrillic(shown))


func test_new_speakers_are_story_voices_at_cutscene_priority() -> void:
	var rules: Dictionary = GLData.load_json("res://data/gravelight/vo/rules.json")
	var prio: Dictionary = rules.get("speaker_default_priority", {})
	for spk: String in ["SER", "VOL", "BRG", "SVR", "RTN"]:
		assert_true((rules.get("story_speakers", []) as Array).has(spk), spk + " is a story speaker")
		assert_true(prio.has(spk), spk + " has a default priority")
	for spk: String in ["SER", "VOL", "BRG"]:
		assert_eq(int(prio[spk]), 4, spk + " is tier 4 (cutscene lines are never cut)")


func test_subtitle_face_has_cyrillic() -> void:
	# IBM Plex Sans carries Cyrillic, so even a slip in `text` would render; the stamp and typewriter faces of the title
	# cards do not (checked with fontTools: 0 glyphs in U+0400..U+04FF), which Godot hides behind its system-font
	# fallback (has_char says true), so the cards stay in Latin letters by rule (CUTSCENES_LAZARUS.md), not by test.
	var body: Font = MenuKit.font("body_bold")
	assert_not_null(body)
	if body != null:
		assert_true(body.has_char(0x0416), "the subtitle face has Cyrillic")
