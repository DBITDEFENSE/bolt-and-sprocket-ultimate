extends Node
## Headless QA for the Map 0 fixed story items (LORE.md section 13.1): the six StoryProps spawn, none of them
## is also in the random intel pool, each sits on its surface / hangs on its wall (physics raycasts against the
## collision shell), the real Player can read the guest book from the bar stool through simulated input, and
## reading files each item in the Intel Archive exactly once (always readable afterwards).
## Usage: godot --headless --path . res://gravelight/tools_src/smoke_story_props.tscn

const FIXED_IDS: PackedStringArray = ["INT_M0_09", "INT_M0_10", "INT_M0_11", "INT_M0_12", "INT_M0_13", "INT_M0_14"]

var _map: Node3D
var _p: Player
var _fails: PackedStringArray = []


func _ready() -> void:
	ProfileSave.path = "user://_qa_story_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	_map = (load("res://gravelight/maps/map00_crossroads/map00.tscn") as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _hold(action: StringName, seconds: float) -> void:
	Input.action_press(action)
	await _secs(seconds)
	Input.action_release(action)
	await _frames(2)


func _tap(action: StringName) -> void:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(2)
	ev = InputEventAction.new()
	ev.action = action
	ev.pressed = false
	Input.parse_input_event(ev)
	await _frames(2)


func _place(pos: Vector3, yaw_deg: float, pitch_deg: float = 0.0) -> void:
	_p.global_position = pos
	_p.velocity = Vector3.ZERO
	_p.rotation.y = deg_to_rad(yaw_deg)
	_p.set("_pitch", deg_to_rad(pitch_deg))
	await _frames(3)


func _check(cond: bool, what: String) -> void:
	print("[qa] %-64s %s" % [what, "ok" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)   # world layer only
	return _map.get_world_3d().direct_space_state.intersect_ray(q)


func _run() -> void:
	await _frames(12)
	_p = _map.get_node("Player1") as Player
	RoundManager.stop()
	GameState.god_mode = true

	# 1. the six props exist, by id, and none of them is in the random pool
	var props: Dictionary = {}
	for n: Node in get_tree().get_nodes_in_group(&"story_props"):
		props[String((n as StoryProp).intel_id)] = n
	var want_props: int = 0   # T-137 added the Marke poster: count from story_props.json
	for row: Dictionary in (GLData.load_json(StoryProp.DATA_PATH).get("props", []) as Array):
		if str(row.get("map", "")) == "0":
			want_props += 1
	_check(props.size() == want_props, "story props spawned (%d, data says %d)" % [props.size(), want_props])
	for id: String in FIXED_IDS:
		_check(props.has(id), "story prop %s present" % id)
		_check(_map.get_node_or_null("Intel_" + id) == null, "%s not spawned as random intel" % id)

	# 2. each sits on its surface (flat) or hangs on its wall (wall styles): raycast against the collision shell
	for id: String in FIXED_IDS:
		if not props.has(id):
			continue
		var sp: StoryProp = props[id] as StoryProp
		var o: Vector3 = sp.global_position
		if StoryProp.is_wall_style(sp.style):
			var back: Vector3 = sp.global_basis.z   # local +Z = into the wall
			var hit: Dictionary = _ray(o - back * 0.25, o + back * 0.4)
			var d: float = (hit["position"] as Vector3).distance_to(o - back * 0.25) if not hit.is_empty() else -1.0
			_check(not hit.is_empty() and absf(d - 0.25) < 0.03, "%s (%s) back is on the wall (gap %.3f)" % [id, sp.style, d - 0.25])
		else:
			var hit2: Dictionary = _ray(o + Vector3(0, 0.5, 0), o - Vector3(0, 0.6, 0))
			var dy: float = (hit2["position"] as Vector3).y - o.y if not hit2.is_empty() else -9.0
			_check(not hit2.is_empty() and dy > -0.012 and dy < 0.03, "%s (%s) sits on its surface (dy %.3f)" % [id, sp.style, dy])

	# 3. the guest book, read by the real Player from the stool east of the bar's side counter
	for d: Node in get_tree().get_nodes_in_group(&"doors"):
		(d as BuyDoor).open(1)
	await _frames(2)
	await _place(Vector3(9.75, 0, 6.9), 90.0, -26.0)
	_check(_p.prompt_text.contains("Guest Book"), "guest book prompt: " + _p.prompt_text)
	_check(not ProfileSave.has_intel("INT_M0_09"), "guest book not yet in the Archive")
	var xp0: int = int(ProfileSave.profile.get("xp", 0)) + int(ProfileSave.cur_match.get("xp", 0))
	await _hold(&"interact", 0.6)
	_check(StoryReader.is_open(), "reader opened")
	_check(ProfileSave.has_intel("INT_M0_09"), "first read filed INT_M0_09 in the Archive")
	var xp1: int = int(ProfileSave.profile.get("xp", 0)) + int(ProfileSave.cur_match.get("xp", 0))
	_check(xp1 > xp0, "first read awarded intel XP (%d -> %d)" % [xp0, xp1])
	await _secs(0.3)
	await _tap(&"interact")
	_check(not StoryReader.is_open(), "reader closed on Use")
	_check(not GameState.input_blocked, "input unblocked after closing")
	await _frames(3)
	_check(_p.prompt_text.contains("Guest Book"), "still readable after filing")
	await _hold(&"interact", 0.6)
	_check(StoryReader.is_open(), "reader reopened")
	var xp2: int = int(ProfileSave.profile.get("xp", 0)) + int(ProfileSave.cur_match.get("xp", 0))
	_check(xp2 == xp1, "second read awards nothing more")
	await _secs(0.3)
	await _tap(&"ui_cancel")
	_check(not StoryReader.is_open(), "reader closed on Esc")

	# 4. the other five, read directly: each files once and shows in the Archive rows
	var archive: Dictionary = {}
	for r: Dictionary in ProfileSave.intel_rows():
		archive[str(r["id"])] = r
	for id: String in FIXED_IDS.slice(1):
		if not props.has(id):
			continue
		(props[id] as StoryProp).interact(_p)
		await _frames(2)
		_check(StoryReader.is_open() and ProfileSave.has_intel(id), "reading %s filed it" % id)
		_check(archive.has(id) and str((archive.get(id, {}) as Dictionary).get("placement", "")) == "fixed", "%s is an Archive row (fixed)" % id)
		await _secs(0.3)
		(StoryReader._open as StoryReader).close()
		await _frames(2)
	_check((ProfileSave.profile.get("intel", []) as Array).size() == 6, "profile holds exactly the 6 ids (%d)" % (ProfileSave.profile.get("intel", []) as Array).size())

	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	print("[qa] story props: %d failures" % _fails.size())
	for f: String in _fails:
		print("[qa]   FAIL ", f)
	get_tree().quit(1 if _fails.size() > 0 else 0)
