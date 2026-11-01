extends GutTest
## T-144: the loading screens' tips and lore lines (data/gravelight/tips.json) are there, short and clean; every
## playable map has lore lines; LoadingScreen picks from them; the game-over ledger rows.

const BANNED: Array = ["call of duty", "treyarch", "activision", "nazi zombies", "wunderwaffe", "pack-a-punch",
	"juggernog", "quick revive", "mystery box", "gravelight zombies"]


func test_thirty_tips() -> void:
	var tips: Array = LoadingScreen.tips()
	assert_eq(tips.size(), 30, "30 tips")
	var seen: Dictionary = {}
	for t: Variant in tips:
		var s: String = str(t)
		assert_between(s.length(), 20, 140, "tip length: %s" % s)
		assert_false(seen.has(s), "no duplicate tip: %s" % s)
		seen[s] = true
		for b: String in BANNED:
			assert_false(s.to_lower().contains(b), "no borrowed names in '%s'" % s)
		assert_true(s.ends_with(".") or s.ends_with("!") or s.ends_with("?"), "a full sentence: %s" % s)


func test_every_map_has_lore_lines() -> void:
	for id: String in MapCards.ids():
		var lines: Array = LoadingScreen.lore_lines(id)
		assert_gte(lines.size(), 2, "%s has lore lines" % id)
		for l: Variant in lines:
			assert_between(str(l).length(), 20, 160, "%s lore length" % id)
			assert_false(str(l).to_lower().contains("zombie"), "lore is in-world (no 'zombie'): %s" % l)


func test_picks() -> void:
	assert_eq(LoadingScreen.pick_tip(0), str(LoadingScreen.tips()[0]))
	assert_eq(LoadingScreen.pick_tip(30), str(LoadingScreen.tips()[0]), "the pick wraps")
	assert_ne(LoadingScreen.pick_tip(), "")
	assert_ne(LoadingScreen.lore_line("map00_crossroads"), "")
	assert_eq(LoadingScreen.lore_line("no_such_map"), "")


func test_loading_screen_builds_for_each_map() -> void:
	for id: String in MapCards.ids():
		var ls: LoadingScreen = LoadingScreen.new()
		ls.demo_map = id
		add_child_autofree(ls)
		await wait_frames(1)
		assert_ne(ls.tip, "", "%s: a tip" % id)
		assert_ne(ls.lore, "", "%s: a lore line" % id)
		var name_l: Label = ls.find_child("MapName", true, false) as Label
		assert_not_null(name_l)
		assert_eq(name_l.text, str(MapCards.row(id)["name"]).to_upper())


func test_game_over_ledger_rows() -> void:
	var st: Dictionary = {&"kills": 9, &"headshots": 2, &"marke_kills": 1, &"scrip_earned": 900, &"downs": 1,
		&"players": {2: {&"kills": 4, &"headshots": 1, &"marke_kills": 0, &"scrip": 400, &"downs": 1, &"revives": 0},
			1: {&"kills": 5, &"headshots": 1, &"marke_kills": 1, &"scrip": 500, &"downs": 0, &"revives": 1}}}
	var rows: Array = GameOverScreen.ledger(st)
	assert_eq(rows.size(), 2, "one line per player")
	assert_eq((rows[0][1] as Array), [5, 1, 1, 500, 0, 1], "player 1 first: kills, headshots, Marke, Scrip, downs, revives")
	var team: Array = GameOverScreen.ledger({&"kills": 3, &"headshots": 1, &"scrip_earned": 120})
	assert_eq(team.size(), 1, "no per-player block: the squad's totals")
	assert_eq((team[0][1] as Array)[0], 3)
	assert_eq(GameOverScreen._thousands(18450), "18,450")
