extends GutTest
## T-203: while a LAZARUS cutscene plays over a match, only its own lines play (GLVO.cinema_hold / cinema_pass), and
## DevLauncher.bat's quick map buttons skip the intro (LazarusCinema.skip_next; force_ids wins).


func after_each() -> void:
	GLVO.cinema_hold = 0
	GLVO.cinema_pass = false
	GLVO.stop_all()
	LazarusCinema.skip_next = false
	LazarusCinema.force_ids = []


func _a_line() -> StringName:
	for k: Variant in GLVO.lines.keys():
		if str(k).begins_with("OPR_ROUND_START"):
			return StringName(str(k))
	return &""


func test_the_hold_keeps_the_match_quiet_and_lets_the_reel_speak() -> void:
	var id: StringName = _a_line()
	assert_ne(id, &"", "an Operator line to try")
	GLVO.cinema_hold = 1
	assert_false(GLVO.play_local(id), "held: a match line does not play under the cutscene")
	GLVO.cinema_pass = true
	assert_true(GLVO.play_local(id), "the reel's own line passes")
	GLVO.cinema_pass = false
	GLVO.stop_all()
	GLVO.cinema_hold = 0
	assert_true(GLVO.play_local(id), "released: lines play again")


func test_the_reel_holds_and_releases() -> void:
	var host: Node = autofree(Node.new())
	add_child(host)
	var r: CinemaReel = CinemaReel.play(host, [], {})
	assert_eq(GLVO.cinema_hold, 0, "a reel over nothing (the theatre, the Archive) holds nothing")
	r.map = host
	r._vo_held = true
	GLVO.cinema_hold += 1
	r._release_vo()
	assert_eq(GLVO.cinema_hold, 0, "released once")
	r._release_vo()
	assert_eq(GLVO.cinema_hold, 0, "never below zero")
