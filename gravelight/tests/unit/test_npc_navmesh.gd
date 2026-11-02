extends GutTest
## UPDATE 10 s6 item 3 (T-162): every NPC's authored spot lies on its map's navmesh within 0.3 m and clear of walls:
## the Inn survivors' hiding places and posts, the map companions' spots, the extra people and their items, the
## player's start and the squad's start positions, on all seven maps (map00, map01, map02, map04a-d). The same
## checks smoke_npc_walls runs (NpcWallProbe), on the loaded maps, with a tighter 0.3 m navmesh distance.

const MAPS: PackedStringArray = ["map00", "map01", "map02", "map04a", "map04b", "map04c", "map04d"]


var _char: StringName
var _bots: int
var _mode: String
var _characters: Variant
var _pids: Array[int]
var _bot_ids: Array[int]


func before_all() -> void:
	_char = GameState.character_id   # (the probe picks Peg and 3 bots: put them back so later tests see what they expect)
	_bots = GameState.bot_count
	_mode = GameState.bot_ai_mode
	_characters = GameState.characters.duplicate()
	_pids = GameState.player_ids.duplicate()
	_bot_ids = GameState.bot_ids.duplicate()
	ProfileSave.path = "user://_test_profile_npcnav_%d.json" % OS.get_process_id()
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.values["homage_bosses"] = false


func after_all() -> void:
	GameState.character_id = _char
	GameState.bot_count = _bots
	GameState.bot_ai_mode = _mode
	GameState.characters = _characters
	GameState.player_ids = _pids
	GameState.bot_ids = _bot_ids
	Campaign.reset()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))


func _check(map_name: String) -> void:
	var probe: NpcWallProbe = NpcWallProbe.new()
	add_child(probe)
	var issues: PackedStringArray = await probe.static_only(map_name)
	for line: String in issues:
		fail_test("%s: %s" % [map_name, line])
	assert_eq(issues.size(), 0, "%s: spots on the navmesh" % map_name)
	assert_gt(probe.spots_checked, 0, "%s: the check looked at something (the player start at least)" % map_name)
	gut.p("%s: %d spots checked" % [map_name, probe.spots_checked])
	probe.queue_free()


func test_map00() -> void:
	await _check("map00")


func test_map01() -> void:
	await _check("map01")


func test_map02() -> void:
	await _check("map02")


func test_map04a() -> void:
	await _check("map04a")


func test_map04b() -> void:
	await _check("map04b")


func test_map04c() -> void:
	await _check("map04c")


func test_map04d() -> void:
	await _check("map04d")
