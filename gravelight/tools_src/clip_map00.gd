extends Node
## UPDATE 05 section 6 acceptance clip (T-095): 60 seconds of Map 0 at round 8+ with 3 bots, seen through the
## player's own eyes while the F6 agent (player bot mode) plays the survivor: real combat, reloads, a Crucible-taught
## Thompson in hand, the squad placed in the Carters' Yard at the start so the yard, the snow and the field are in
## the shot. Silent, off-screen, never holds the mouse:
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --write-movie <abs>/map00_vfx.avi
##         --fixed-fps 30 --path . res://gravelight/tools_src/clip_map00.tscn [-- --secs=60 --round=8 --weapon=thompson_up --no-yard]
## tools/clip_map00.sh runs it and encodes the mp4 + a 12-frame contact sheet with ffmpeg. Prints "[clip] ..." lines
## and RESULT PASS/FAIL (a reload seen, an upgraded weapon fired, the yard visited, flashes and casings drawn).
## Also runs headless as a check (--headless --audio-driver Dummy --fixed-fps 60).

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const YARD: Vector3 = Vector3(18.0, 0.0, 40.5)

var _secs_total: float = 60.0
var _round: int = 8
var _weapon: StringName = &"thompson_up"
var _yard: bool = true
var _map: MapRoot
var _t: float = 0.0
var _settle: float = 0.0
var _live: bool = false
var _reloads: int = 0
var _was_reloading: bool = false
var _upgraded_shots: int = 0
var _yard_secs: float = 0.0
var _flashes0: int = 0
var _casings0: int = 0
var _impacts0: int = 0
var _kills: int = 0
var _fails: PackedStringArray = []


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--secs="):
			_secs_total = float(a.substr(7))
		elif a.begins_with("--round="):
			_round = maxi(1, int(a.substr(8)))
		elif a.begins_with("--weapon="):
			_weapon = StringName(a.substr(9))
		elif a == "--no-yard":
			_yard = false
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	ProfileSave.path = "user://_qa_clip_map00_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_clip_map00_settings.cfg"
	GLSettings.values["homage_bosses"] = false
	GLSettings.values["vfx_quality"] = "high"
	GLSettings.values["gore"] = "full"
	Campaign.reset()
	GameState.character_id = &"dutch"
	GameState.bot_count = 3
	GameState.bot_skill = "veteran"
	GameState.bot_ai_mode = "off"
	GameState.god_mode = false
	PlayerBot.pending_on = true   # the F6 agent drives the survivor from the first frame
	GLBus.enemy_killed.connect(func(_e: StringName, _l: StringName, _w: StringName, by: int) -> void:
		if by == 1:
			_kills += 1)
	GLBus.weapon_fired.connect(func(pid: int, _w: StringName, up: bool, _o: Vector3, _d: Vector3) -> void:
		if pid == 1 and up:
			_upgraded_shots += 1)
	_map = (load(MAP) as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)


func _process(_d: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # never hold the mouse


func _physics_process(delta: float) -> void:
	if _map == null or not _map.is_inside_tree():
		return
	if not _live:
		_settle += delta
		if _settle > 2.0:
			_try_live()
		return
	_t += delta
	var p: Player = _map.player
	if p != null and is_instance_valid(p):
		var rel: bool = bool(p.weapons.get("_reloading"))
		if rel and not _was_reloading:
			_reloads += 1
			print("[clip] t=%.1f reload %d" % [_t, _reloads])
		_was_reloading = rel
		if ZoneVolume.zone_at(get_tree(), p.global_position) == &"YARD" or (p.global_position.z > 34.0 and p.global_position.x > 2.0 and p.global_position.x < 34.0):
			_yard_secs += delta
	if _t >= _secs_total:
		_finish()


func _try_live() -> void:
	if _map.player == null or not _map.player.is_inside_tree() or _map.squad == null:
		return
	if NavigationServer3D.map_get_iteration_id(_map.player.get_world_3d().navigation_map) == 0:
		return
	_live = true
	var p: Player = _map.player
	RoundManager.debug_set_round(_round)
	for pid: int in GameState.player_ids:
		Economy.award(pid, 3000)
	GLConsole.call("run", "open_doors")
	p.weapons.give_weapon(_weapon)
	var idx: int = p.weapons.slots.find(p.weapons.find_weapon(_weapon))
	if idx >= 0:
		p.weapons.current_index = idx
		p.weapons.call("_rebuild_gun")
		var w: WeaponInstance = p.weapons.current()
		if w != null:
			w.mag = mini(w.mag, 10)   # a short first magazine, so the first reload lands inside the clip
	if _yard:
		var nav: RID = p.get_world_3d().navigation_map
		p.global_position = NavigationServer3D.map_get_closest_point(nav, YARD)
		p.velocity = Vector3.ZERO
		var i: int = 0
		for b: BotBrain in _map.squad.brains:
			i += 1
			b.player.global_position = NavigationServer3D.map_get_closest_point(nav, YARD + Vector3(-2.0 + 1.5 * float(i), 0, -1.5 + 0.8 * float(i % 2)))
			b.player.velocity = Vector3.ZERO
	var pb: PlayerBot = PlayerBot.of(get_tree())
	if pb != null and not pb.is_on():
		pb.set_on(true, "clip")
	_flashes0 = int(Effects.stats["flashes"])
	_casings0 = int(Effects.stats["casings"])
	_impacts0 = int(Effects.stats["impacts"])
	print("[clip] live: round %d, bots %d, weapon %s, bot-driven %s, yard %s" % [RoundManager.current_round + 1, GameState.bot_ids.size(), _weapon, str(p.bot_driven), str(_yard)])


func _check(ok: bool, what: String) -> void:
	print("[clip] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails.append(what)


func _finish() -> void:
	_live = false
	set_physics_process(false)
	var flashes: int = int(Effects.stats["flashes"]) - _flashes0
	var cas: int = int(Effects.stats["casings"]) - _casings0
	var imp: int = int(Effects.stats["impacts"]) - _impacts0
	print("[clip] %.0f s: flashes %d, casings %d, impacts %d, reloads %d, upgraded shots %d, kills by P1 %d, yard %.1f s, atmosphere %s" % [
		_t, flashes, cas, imp, _reloads, _upgraded_shots, _kills, _yard_secs, str(Effects.atmosphere() != null)])
	_check(flashes > 10, "muzzle flashes drawn (%d)" % flashes)
	_check(cas > 10, "casings thrown (%d)" % cas)
	_check(_reloads >= 1, "a reload was seen (%d)" % _reloads)
	_check(_upgraded_shots >= 1, "the Crucible weapon fired (%d shots)" % _upgraded_shots)
	_check(not _yard or _yard_secs > 5.0, "the yard was in the shot (%.1f s)" % _yard_secs)
	_check(Effects.atmosphere() != null, "the atmosphere pass is attached")
	print("RESULT %s" % ("PASS" if _fails.is_empty() else "FAIL: " + ", ".join(_fails)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit(0 if _fails.is_empty() else 1)
