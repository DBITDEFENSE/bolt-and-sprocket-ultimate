extends Node
## The Update 02 section 6.2 clip (Jakub Ostrowski, DECISIONS T-051): Map 0 with Door 5 open, round 5, the human
## (god mode, Wren) and one bot. Four beats, each from its own camera:
##   1. the breakout: the zombie through the coal window, the burst hinge, the Polish shout, the coal shovel (0-20 s)
##   2. "Talk to Jakub": the choice card, GIVE HIM A GUN (the human's Kar98k) (20-28 s)
##   3. fighting beside the player in the Old Cellar, over Jakub's shoulder (28-56 s)
##   4. he goes down; the squad's bot picks him up (56-72 s)
## Silent, off-screen, never holds the mouse:
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --write-movie <abs>/s6_jakub.avi
##         --fixed-fps 30 --quit-after 2200 --path . res://gravelight/tools_src/clip_jakub.tscn
## Prints "[clip-jakub] ..." beats and RESULT PASS/FAIL.

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const COAL_CAM: Vector3 = Vector3(4.55, -1.45, 6.9)
const COAL_LOOK: Vector3 = Vector3(1.7, -2.15, 4.3)

var _map: MapRoot
var _cam: Camera3D
var _t: float = 0.0
var _beat: int = 0
var _beat_t: float = 0.0
var _live: bool = false
var _fails: PackedStringArray = []
var _first_seen: Dictionary = {}
var _downed_at: float = -1.0
var _revived: bool = false
var _revived_t: float = 0.0
var _cam_pick: Vector3 = Vector3.INF
var _talked: bool = false
var _gave: bool = false


func _ready() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	ProfileSave.path = "user://_qa_clip_jakub_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_clip_jakub_settings.cfg"
	Campaign.reset()
	GameState.character_id = &"wren"
	GameState.bot_count = 1
	GameState.bot_skill = "veteran"
	GameState.bot_ai_mode = "off"
	_map = (load(MAP) as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GLBus.vo_line_started.connect(func(id: StringName, _s: StringName, text: String, _d: float) -> void:
		print("[clip-jakub] t=%.1f %s: %s" % [_t, id, text]))
	GLBus.player_revived.connect(func(p: int, by: int) -> void:
		if p == JakubCompanion.pid():
			_revived = true
			_revived_t = _t
			print("[clip-jakub] t=%.1f Jakub revived by P%d" % [_t, by]))


func _process(_delta: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # never hold the mouse


func _jc() -> JakubCompanion:
	return JakubCompanion.instance(get_tree())


func _physics_process(delta: float) -> void:
	if _map == null or not _map.is_inside_tree():
		return
	if not _live:
		if _map.player != null and _map.player.is_inside_tree() and _jc() != null and _jc().player != null:
			_go_live()
		return
	_t += delta
	_beat_t += delta
	_cull()
	var jc: JakubCompanion = _jc()
	var jp: Player = jc.player
	var h: Player = _map.player
	match _beat:
		0:
			_look(COAL_CAM, COAL_LOOK, delta, 1.0)
			if jc.state == JakubCompanion.State.WAITING and _beat_t > 4.0 or _beat_t > 26.0:
				_next("talk")
				h.weapons.give_weapon(&"kar98k")
				h.global_position = jp.global_position + Vector3(-0.9, 0.0, 1.5)
				h.rotation.y = atan2(-(jp.global_position.x - h.global_position.x), -(jp.global_position.z - h.global_position.z))
		1:
			if _beat_t < 0.1 or _cam_pick == Vector3.INF:
				_cam_pick = _best_cam(jp.global_position + Vector3.UP * 1.5, 2.6, 0.2)
			_look(_cam_pick, jp.global_position + Vector3.UP * 1.35, delta, 1.0)
			if not _talked and _beat_t > 1.0:
				_talked = true
				jc.on_talk(h)
			if _talked and not _gave and _beat_t > 5.5:
				_gave = true
				var card: JakubChoice = _map.find_child("*JakubChoice*", true, false) as JakubChoice
				if card == null:
					for c: Node in _map.get_children():
						if c is JakubChoice:
							card = c
				if card != null:
					card._close(true)
				else:
					jc.choose(h, true)
			if _gave and _beat_t > 9.0:
				_next("fight")
				h.global_position = Vector3(9.5, -3.2, 3.6)
		2:
			var back: Vector3 = jp.global_basis.z
			back.y = 0.0
			var head: Vector3 = jp.global_position + Vector3.UP * 1.6
			_look(_clear_from(head, head + back.normalized() * 2.6 + Vector3.UP * 0.7 + jp.global_basis.x * 0.8),
				jp.global_position - jp.global_basis.z * 6.0 + Vector3.UP * 1.0, delta, 0.25)
			if _beat_t > 22.0:
				_next("revive")
				if not jp.downed:
					jp.take_hit(jp.hp + 1.0, null)
				_downed_at = _t
		3:
			var c2: Vector3 = jp.global_position
			if _beat_t < 0.1 or _cam_pick == Vector3.INF:
				_cam_pick = _best_cam(c2 + Vector3.UP * 1.0, 3.2, 0.6)
			_look(_cam_pick, c2 + Vector3.UP * 0.4, delta, 0.3)
			if not _revived and _beat_t > 13.0 and jp.downed:
				# the bot didn't make it in time: the human (off camera) picks him up
				var rp: RevivePoint = jp.get_node_or_null("Revive") as RevivePoint
				h.global_position = jp.global_position + Vector3(0.9, 0.0, 0.0)
				if rp != null:
					rp.interact(h)
			if (_revived and _t - _revived_t > 4.0) or _beat_t > 24.0:
				_finish()
	if jp.downed and _beat == 2:
		jp.revive(1)   # the fight beat keeps him up; the revive beat is next


func _go_live() -> void:
	_live = true
	GameState.god_mode = true
	_map.player.set_process_unhandled_input(false)
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		var d: BuyDoor = n as BuyDoor
		if d != null and d.door_id == &"door_old_cellar":
			d.open(1)
	_map.director.kill_all(true)
	GameState.power_on = true   # the cellar bulbs (the clip only: they light the beats)
	GLBus.power_activated.emit()
	RoundManager.debug_set_round(5)
	_map.player.global_position = Vector3(14, 0, 8)
	_cam = Camera3D.new()
	_cam.name = "ClipCam"
	_cam.fov = 70.0
	_cam.far = 300.0
	_map.add_child(_cam)
	_cam.global_position = COAL_CAM
	_cam.look_at(COAL_LOOK, Vector3.UP)
	_cam.make_current()
	print("[clip-jakub] live: beat breakout")


## The roomiest of eight directions round `at` (`dist` m out, `up` m higher), pulled in short of walls.
func _best_cam(at: Vector3, dist: float, up: float) -> Vector3:
	var best: Vector3 = at + Vector3(dist, up, 0.0)
	var best_d: float = -1.0
	for k: int in 8:
		var a: float = TAU * float(k) / 8.0
		var p: Vector3 = _clear_from(at, at + Vector3(cos(a) * dist, up, sin(a) * dist))
		var d: float = p.distance_to(at)
		if d > best_d + 0.05:
			best_d = d
			best = p
	return best


## A camera spot from `from` toward `want`, pulled in short of any wall (the cellar is cramped).
func _clear_from(from: Vector3, want: Vector3) -> Vector3:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, want, 1 | (1 << 8))
	var r: Dictionary = _map.get_world_3d().direct_space_state.intersect_ray(q)
	return want if r.is_empty() else from.lerp(r["position"], 0.8)


func _next(name_s: String) -> void:
	_cam_pick = Vector3.INF
	_beat += 1
	_beat_t = 0.0
	print("[clip-jakub] t=%.1f beat %s" % [_t, name_s])


func _look(pos: Vector3, at: Vector3, delta: float, follow: float) -> void:
	_cam.make_current()
	var k: float = clampf(delta * 3.0 / maxf(0.05, follow), 0.0, 1.0)
	if _beat_t < 0.1:
		k = 1.0
	_cam.global_position = _cam.global_position.lerp(pos, k)
	if _cam.global_position.distance_to(at) > 0.2:
		_cam.look_at(at, Vector3.UP)


## Old zombies go (the horde stays small and the beats stay readable); never the breakout zombie or anything
## that still has business with Jakub in the first beat.
func _cull() -> void:
	var jc: JakubCompanion = _jc()
	for z: Zombie in _map.director.active_zombies():
		if jc != null and z == jc.breakout_zombie:
			continue
		var id: int = z.get_instance_id()
		if not _first_seen.has(id):
			_first_seen[id] = _t
		var limit: float = 6.0 if _beat <= 1 else (22.0 if _beat == 2 else 9.0)
		if _t - float(_first_seen[id]) > limit:
			z.take_damage(z.hp + 1.0, &"head", &"m1911", 0, &"world")
			_first_seen.erase(id)


func _finish() -> void:
	var jc: JakubCompanion = _jc()
	var ok_breakout: bool = jc.events.has("burst")
	var ok_join: bool = jc.state == JakubCompanion.State.JOINED and jc.player.weapons.current() != null
	if not ok_breakout:
		_fails.append("no breakout")
	if not ok_join:
		_fails.append("no join with a gun")
	if not _revived:
		_fails.append("nobody revived him")
	print("[clip-jakub] RESULT: %s %s" % ["PASS" if _fails.is_empty() else "FAIL", ", ".join(_fails)])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit(0 if _fails.is_empty() else 1)
	set_physics_process(false)
