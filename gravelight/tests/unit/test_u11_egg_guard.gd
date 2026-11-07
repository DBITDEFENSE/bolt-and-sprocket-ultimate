extends GutTest
## U11 §2 (T-189): every Easter egg keeps its step graph, items, puzzles, codes, melodies, bells, radios, rewards and
## bot tasks. The snapshot was taken before Update 11 changed anything; egg VO may be re-toned in lines.json, but the
## quest files themselves stay as they are.

const G: GDScript = preload("res://gravelight/tools_src/egg_guard.gd")


func test_every_quest_file_matches_the_snapshot() -> void:
	assert_true(FileAccess.file_exists(G.FIXTURE), "the U11 egg snapshot exists")
	var want: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(G.FIXTURE))
	var have: Dictionary = G.digest_all()
	assert_eq(have.keys().size(), want.keys().size(), "no quest file added or removed")
	for f: String in want:
		assert_true(have.has(f), "%s still exists" % f)
		if not have.has(f):
			continue
		var w: Dictionary = want[f]
		var h: Dictionary = have[f]
		for part: String in w:
			assert_eq(h.get(part, "<missing>"), w[part], "%s %s is unchanged" % [f, part])
		for part: String in h:
			assert_true(w.has(part), "%s gained no new part %s" % [f, part])
