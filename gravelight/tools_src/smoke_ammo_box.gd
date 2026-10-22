extends Node
## Smoke for the ammo boxes (Update 02 section 4, T-049): drives the real Player with simulated input on Map 0
## (both boxes) and Kaltenbrunn (the Rail Yard box): the prompt's price for a normal, a Crucible-upgraded and a
## wonder weapon (upgraded too), buying refills and charges, the cooldown, "Ammo full" costs nothing, grenades
## refilled but not tacticals. Then checks every box on Maps 0-2 is reachable on the navmesh from the spawn.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_ammo_box.tscn

const MAPS: Array = [
	["map00", "res://gravelight/maps/map00_crossroads/map00.tscn", 2],
	["map01", "res://gravelight/maps/map01_kaltenbrunn/map01.tscn", 4],
	["map02", "res://gravelight/maps/map02_totenhafen/map02.tscn", 4],
]

var _map: Node3D
var _p: Player
var _fails: PackedStringArray = []


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _check(cond: bool, what: String) -> void:
	print("[qa] %-60s %s" % [what, "ok" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _load(path: String) -> void:
	if _map != null:
		_map.queue_free()
		await _frames(5)
	_map = (load(path) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(_map)
	await _frames(10)
	_p = _map.get_node("Player1") as Player
	RoundManager.stop()
	GameState.god_mode = true
	var dir: ZombieDirector = _map.get_node_or_null("ZombieDirector") as ZombieDirector
	if dir != null:
		dir.kill_all(true)


func _box(n: String) -> AmmoBox:
	return _map.get_node("Gameplay/" + n) as AmmoBox


## Stands the player in front of `box`, looking at it.
func _face(box: AmmoBox) -> void:
	var f: Vector3 = box.global_basis * Vector3(0, 0, -1)
	_p.global_position = box.global_position + f * 1.6
	_p.velocity = Vector3.ZERO
	_p.rotation.y = box.global_rotation.y + PI
	_p.set("_pitch", deg_to_rad(-32.0))
	await _frames(4)


func _buy(box: AmmoBox) -> void:
	Input.action_press(&"interact")
	await _secs(box.hold_time(_p) + 0.25)
	Input.action_release(&"interact")
	await _frames(3)


## Holds `wid` in hand with an empty reserve.
func _hold_dry(wid: StringName) -> WeaponInstance:
	_p.weapons.give_weapon(wid)
	var w: WeaponInstance = _p.weapons.current()
	w.reserve = 0
	await _secs(0.5)
	return w


func _cool(box: AmmoBox) -> void:
	box._used_at.clear()
	await _frames(2)


func _run() -> void:
	# ---------------------------------------------------------------- Map 0: the taproom box, every price
	await _load(str(MAPS[0][1]))
	Economy.grant(1, 20000)
	var tap: AmmoBox = _box("AmmoBox_Taproom")
	_check(tap != null, "map00 has the taproom box")
	await _face(tap)
	var w: WeaponInstance = _p.weapons.current()
	w.reserve = 2
	await _frames(2)
	_check(_p.prompt_text.contains("[250]"), "normal price in the prompt: " + _p.prompt_text)
	var before: int = Economy.get_scrip(1)
	await _buy(tap)
	_check(w.reserve == w.reserve_max(), "bought: reserve full (%d/%d)" % [w.reserve, w.reserve_max()])
	_check(Economy.get_scrip(1) == before - 250, "charged 250")
	# the cooldown
	w.reserve = 0
	await _frames(2)
	_check(_p.prompt_text.begins_with("Restocking"), "cooldown shows: " + _p.prompt_text)
	before = Economy.get_scrip(1)
	await _buy(tap)
	_check(Economy.get_scrip(1) == before and w.reserve == 0, "no sale during the cooldown")
	await _secs(3.1)
	await _frames(2)
	_check(_p.prompt_text.contains("[250]"), "ready again after 3 s: " + _p.prompt_text)
	await _buy(tap)
	# full: nothing to sell
	await _cool(tap)
	_check(_p.prompt_text == "Ammo full", "full shows: " + _p.prompt_text)
	before = Economy.get_scrip(1)
	await _buy(tap)
	_check(Economy.get_scrip(1) == before, "full costs nothing")
	# Crucible-upgraded
	w = await _hold_dry(&"thompson_up")
	await _face(tap)
	_check(_p.prompt_text.contains("[2500]"), "upgraded price: " + _p.prompt_text)
	before = Economy.get_scrip(1)
	await _buy(tap)
	_check(w.reserve == w.reserve_max() and Economy.get_scrip(1) == before - 2500, "upgraded refill charged 2500")
	# the prompt follows the weapon in hand (swap back to the pistol)
	await _cool(tap)
	_p.weapons.slots[0].reserve = 0
	Input.action_press(&"weapon_1")
	await _frames(3)
	Input.action_release(&"weapon_1")
	await _secs(0.6)
	_check(_p.prompt_text.contains("[250]"), "swapping changes the price: " + _p.prompt_text)
	# wonder weapons
	w = await _hold_dry(&"ashlight")
	await _cool(tap)
	_check(_p.prompt_text.contains("[1000]"), "wonder price: " + _p.prompt_text)
	before = Economy.get_scrip(1)
	await _buy(tap)
	_check(w.reserve == w.reserve_max() and Economy.get_scrip(1) == before - 1000, "wonder refill charged 1000")
	w = await _hold_dry(&"totenglocke_up")
	await _cool(tap)
	_check(_p.prompt_text.contains("[4000]"), "upgraded wonder price: " + _p.prompt_text)
	before = Economy.get_scrip(1)
	await _buy(tap)
	_check(w.reserve == w.reserve_max() and Economy.get_scrip(1) == before - 4000, "upgraded wonder refill charged 4000")
	# grenades yes, tacticals no
	await _cool(tap)
	w.reserve = 0
	_p.weapons.grenades = 0
	_p.weapons.give_tactical(&"gramophone")
	_p.weapons.tactical_count = 0
	await _buy(tap)
	_check(_p.weapons.grenades == _p.weapons.grenade_max(), "grenades refilled (%d)" % _p.weapons.grenades)
	_check(_p.weapons.tactical_count == 0, "tacticals not refilled")
	# the stable box works too
	var stb: AmmoBox = _box("AmmoBox_Stable")
	_check(stb != null, "map00 has the stable box")
	await _face(stb)
	w.reserve = 0
	await _frames(2)
	before = Economy.get_scrip(1)
	await _buy(stb)
	_check(w.reserve == w.reserve_max() and Economy.get_scrip(1) == before - 4000, "bought at the stable box: " + _p.prompt_text)
	await _nav_ready()
	_check_reach("map00", int(MAPS[0][2]))

	# ---------------------------------------------------------------- Kaltenbrunn: the Rail Yard box
	await _load(str(MAPS[1][1]))
	Economy.grant(1, 5000)
	var ry: AmmoBox = _box("AmmoBox_RailYard")
	_check(ry != null, "map01 has the Rail Yard box")
	await _face(ry)
	w = _p.weapons.current()
	w.reserve = 0
	await _frames(2)
	_check(_p.prompt_text.contains("[250]"), "map01 prompt: " + _p.prompt_text)
	before = Economy.get_scrip(1)
	await _buy(ry)
	_check(w.reserve == w.reserve_max() and Economy.get_scrip(1) == before - 250, "bought on map01")
	await _nav_ready()
	_check_reach("map01", int(MAPS[1][2]))

	# ---------------------------------------------------------------- Totenhafen: placement only
	await _load(str(MAPS[2][1]))
	await _nav_ready()
	_check_reach("map02", int(MAPS[2][2]))

	print("[qa] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d)" % _fails.size()))
	get_tree().quit(0 if _fails.is_empty() else 1)


## Waits (up to ~4 s) until the navigation map has synced the freshly loaded map's regions.
func _nav_ready() -> void:
	var nav: RID = _map.get_world_3d().navigation_map
	var spawn: Vector3 = (_map.get_node("Gameplay/PlayerSpawn1") as Node3D).global_position
	for i: int in 240:
		if NavigationServer3D.map_get_closest_point(nav, spawn).distance_to(spawn) < 2.0:
			return
		await get_tree().physics_frame


## Every box on the loaded map: the expected count, 4 m+ from perk machines and the Crucible, and a navmesh path
## from the first player spawn to the spot in front of it (all zone layers open).
func _check_reach(tag: String, expect: int) -> void:
	var boxes: Array[Node] = get_tree().get_nodes_in_group(&"ammo_boxes")
	_check(boxes.size() == expect, "%s has %d ammo boxes (got %d)" % [tag, expect, boxes.size()])
	var nav: RID = _map.get_world_3d().navigation_map
	var spawn: Vector3 = (_map.get_node("Gameplay/PlayerSpawn1") as Node3D).global_position
	for n: Node in boxes:
		var box: AmmoBox = n as AmmoBox
		var near: float = INF
		for m: Node in get_tree().get_nodes_in_group(&"perk_machines") + get_tree().get_nodes_in_group(&"crucible"):
			near = minf(near, (m as Node3D).global_position.distance_to(box.global_position))
		_check(near >= 4.0, "%s %s: 4 m+ from perks/Crucible (%.1f m)" % [tag, box.name, near])
		var front: Vector3 = box.global_position + box.global_basis * Vector3(0, 0, -1.2)
		var path: PackedVector3Array = NavigationServer3D.map_get_path(nav, spawn, front, true, 0xFFFFFFFF)
		var ok: bool = not path.is_empty() and path[path.size() - 1].distance_to(front) < 1.0
		_check(ok, "%s %s: reachable on the navmesh" % [tag, box.name])
		if not ok:
			print("    path %d points, ends at %s, wanted %s (closest navmesh point %s, spawn's %s)" % [path.size(),
				str(path[path.size() - 1]) if not path.is_empty() else "-", str(front), str(NavigationServer3D.map_get_closest_point(nav, front)),
				str(NavigationServer3D.map_get_closest_point(nav, spawn))])
