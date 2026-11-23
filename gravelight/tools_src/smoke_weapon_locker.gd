extends Node
## T-263 headless smoke: the arms locker (WeaponLocker). Silent, solo, a god-mode human, a scratch profile.
##   Map 0 (the stable's north-east corner), the whole story:
##     the locker stands on its row; the live map (everything built at load: people, story props, the bank, intel)
##     leaves its wall, its body and the standing room free (locker_spot.gd on the running scene); the navmesh
##     brings a player from the spawn to its doors; standing there and looking at it, the player's own use ray
##     finds it and the prompt offers to lock the gun away; a Crucible tier II Thompson with an extended magazine,
##     5 in the magazine and 40 spare goes in for the rent; the player bleeds out and respawns with the starting
##     pistol; the locker still has the gun; it comes out free as it went in; a second store and a wall buy fill the
##     slots and the next hold swaps; a round start changes nothing; a new match (the map loaded again) starts empty.
##   Every other map with a row in weapon_locker.json: the locker, the live spot check, the navmesh, the use ray
##     and prompt, one store and one take.
## Prints "[locker-smoke] ..." and "[locker-smoke] RESULT: PASS/FAIL"; exit code 0/1.

const Spot: GDScript = preload("res://gravelight/tools_src/locker_spot.gd")
const SCENES: Dictionary = {
	"map00": "res://gravelight/maps/map00_crossroads/map00.tscn",
	"map01": "res://gravelight/maps/map01_kaltenbrunn/map01.tscn",
	"map02": "res://gravelight/maps/map02_totenhafen/map02.tscn",
	"map04a": "res://gravelight/maps/map04_fernflug/map04a.tscn",
	"map04b": "res://gravelight/maps/map04_fernflug/map04b.tscn",
	"map04c": "res://gravelight/maps/map04_fernflug/map04c.tscn",
	"map04d": "res://gravelight/maps/map04_fernflug/map04d.tscn",
}
const TIMEOUT: float = 900.0

var _map: Node3D
var _fails: PackedStringArray = []
var _t: float = 0.0


func _ready() -> void:
	ProfileSave.path = "user://_qa_locker_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	ProfileSave.save_profile()
	GLSettings.path = "user://_qa_locker_settings.cfg"
	GLSettings.values["classic_rules"] = false
	GameState.bot_count = 0
	Campaign.reset()
	_run.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if _t > TIMEOUT:
		_fail("timeout")
		_finish()


func _note(m: String) -> void:
	print("[locker-smoke] " + m)


func _fail(m: String) -> void:
	_fails.append(m)
	print("[locker-smoke] FAIL " + m)


func _check(c: bool, what: String) -> void:
	if c:
		_note("ok   " + what)
	else:
		_fail(what)


func _finish() -> void:
	print("[locker-smoke] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d)" % _fails.size()))
	get_tree().quit(0 if _fails.is_empty() else 1)


func _secs(s: float) -> void:
	var end: float = _t + s
	while _t < end:
		await get_tree().physics_frame


func _until(pred: Callable, seconds: float) -> bool:
	var end: float = _t + seconds
	while _t < end:
		if pred.call():
			return true
		await get_tree().physics_frame
	return bool(pred.call())


func _root() -> MapRoot:
	return _map as MapRoot


func _load(scene: String) -> void:
	if _map != null and is_instance_valid(_map):
		_map.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	GameState.character_id = &"dutch"
	GameState.god_mode = true
	_map = (load(scene) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(_map)
	get_tree().current_scene = _map
	await _until(func() -> bool: return _root().player != null and _root().player.is_inside_tree(), 30.0)
	await _secs(1.5)
	GameState.god_mode = true
	_root().player.set_process_unhandled_input(false)
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		if n is BuyDoor and not (n as BuyDoor).is_open:
			(n as BuyDoor).open(1)


func _locker() -> WeaponLocker:
	return get_tree().get_first_node_in_group(&"weapon_lockers") as WeaponLocker


func _ids(p: Player) -> Array:
	var out: Array = []
	for w: WeaponInstance in p.weapons.slots:
		out.append(String(w.id))
	return out


## The running map measured as the probe measures the scene file, without the locker's own parts.
func _live_spot(tag: String, l: WeaponLocker, row: Dictionary) -> void:
	for n: Node in l.find_children("*", "GeometryInstance3D", true, false):
		n.set_meta("locker_own", true)
	var geo: Dictionary = Spot.index(_map)
	var boxes: Array = []
	for bb: Array in geo["boxes"]:
		if str(bb[3]) == "Body" and (bb[2] as AABB).get_center().distance_to(l.global_position + Vector3(0, 0.95, 0)) < 0.6:
			continue   # its own collider
		boxes.append(bb)
	geo["boxes"] = boxes
	var a: Array = row["at"]
	var r: Dictionary = Spot.check(geo, Vector3(float(a[0]), float(a[1]), float(a[2])), float(row.get("yaw", 0.0)))
	_check((r["problems"] as PackedStringArray).is_empty(), "%s: the live map leaves the spot free (%s)" % [tag, Spot.line(r)])


## Stands the player at the doors, looking at them; true when their own use ray finds the locker.
func _walk_up(h: Player, l: WeaponLocker) -> bool:
	h.global_position = l.stand_point(0.6)
	h.velocity = Vector3.ZERO
	h.rotation.y = l.global_rotation.y + PI
	h.head.rotation.x = 0.0
	return await _until(func() -> bool: return h.interact_target == l, 2.0)


func _run() -> void:
	var rows: Dictionary = WeaponLocker.cfg().get("lockers", {})
	_check(rows.has("map00"), "weapon_locker.json has Map 0's row")
	if rows.has("map00"):
		await _map0(rows["map00"])
	for key: Variant in rows.keys():
		if str(key) != "map00" and SCENES.has(str(key)):
			await _other(str(key), rows[key])
	_finish()


func _map0(row: Dictionary) -> void:
	await _load(SCENES["map00"])
	var l: WeaponLocker = _locker()
	_check(l != null, "map00: the locker is there")
	if l == null:
		return
	var a: Array = row["at"]
	_check(l.global_position.distance_to(Vector3(float(a[0]), float(a[1]), float(a[2]))) < 0.01, "map00: on its row, %s" % str(l.global_position.snapped(Vector3.ONE * 0.01)))
	_check(get_tree().get_nodes_in_group(&"weapon_lockers").size() == 1, "map00: one locker")
	_live_spot("map00", l, row)
	var h: Player = _root().player
	var nav: RID = h.get_world_3d().navigation_map
	var stand: Vector3 = l.stand_point(0.6)
	var path: PackedVector3Array = NavigationServer3D.map_get_path(nav, _root().spawn_transform(1).origin, stand, true, 0xFFFFFFFF)
	_check(not path.is_empty() and path[path.size() - 1].distance_to(stand) < 0.8, "map00: the navmesh reaches the doors (%d points, ends %s, wanted %s)" % [path.size(),
		str(path[path.size() - 1].snapped(Vector3.ONE * 0.1)) if not path.is_empty() else "-", str(stand.snapped(Vector3.ONE * 0.1))])
	# the gun: a Crucible tier II Thompson, an extended magazine, 5 in it and 40 spare
	var gun: WeaponInstance = WeaponInstance.create(&"thompson_up")
	gun.tier = 2
	WeaponKit.install(gun, "mag", "extended")
	gun.mag = 5
	gun.reserve = 40
	h.weapons.give_instance(gun)
	var label: String = WeaponLocker.label_of(gun)
	var start_ids: Array = _ids(h)
	_check(start_ids.size() == 2 and h.weapons.current() == gun, "map00: the pistol and %s on you (%s)" % [label, str(start_ids)])
	Economy.grant_raw(1, 3000)
	var cost: int = int(WeaponLocker.cfg().get("store_cost", 0))
	var found: bool = await _walk_up(h, l)
	_check(found, "map00: standing at the doors the use ray finds the locker (target %s)" % (str(h.interact_target.name) if h.interact_target != null else "none"))
	_check(h.global_position.distance_to(stand) < 0.35, "map00: you stand where you walked to (the collider leaves the spot free; moved %.2f m)" % h.global_position.distance_to(stand))
	_check(h.prompt_text.contains("lock away " + label), "map00: the prompt: \"%s\"" % h.prompt_text)
	var pocket: int = Economy.get_scrip(1)
	h.use_interactable(l)
	await _secs(0.3)
	_check(WeaponLocker.has_stored(1) and _ids(h) == [start_ids[0]], "map00: locked away, the pistol left on you (%s)" % str(_ids(h)))
	_check(Economy.get_scrip(1) == pocket - cost, "map00: the rent, %d Scrip" % cost)
	_check(l._card.text == label.to_upper(), "map00: the card on the door reads \"%s\"" % l._card.text)
	# bled out, back at the next round with the starting loadout
	h.bleed_out()
	await _secs(0.2)
	_check(h.weapons.slots.is_empty() and h.spectating, "map00: bled out: nothing on you")
	h.respawn_at(_root().spawn_transform(1))
	await _secs(0.3)
	_check(_ids(h).size() == 1 and not _ids(h).has("thompson_up"), "map00: respawned with the starting pistol (%s)" % str(_ids(h)))
	_check(WeaponLocker.has_stored(1), "map00: the locker still has the gun")
	RoundManager.advance_round()
	await _secs(0.2)
	_check(WeaponLocker.has_stored(1), "map00: a round start changes nothing")
	found = await _walk_up(h, l)
	_check(found and h.prompt_text.contains("take " + label), "map00: back at the doors: \"%s\"" % h.prompt_text)
	pocket = Economy.get_scrip(1)
	h.use_interactable(l)
	await _secs(0.3)
	var w: WeaponInstance = h.weapons.current()
	_check(w != null and w.id == &"thompson_up" and w.tier == 2 and w.kit == {"mag": "extended"} and w.mag == 5 and w.reserve == 40,
		"map00: it comes back as it went in (tier %d, kit %s, %d + %d)" % [w.tier if w != null else -1, str(w.kit) if w != null else "-", w.mag if w != null else -1, w.reserve if w != null else -1])
	_check(Economy.get_scrip(1) == pocket - int(WeaponLocker.cfg().get("withdraw_cost", 0)) and not WeaponLocker.has_stored(1), "map00: taking it back is free, the compartment empty")
	# the swap: in again, a wall buy fills the slot, the next hold trades them
	h.use_interactable(l)
	await _secs(0.2)
	h.weapons.give_weapon(&"kar98k")
	await _secs(0.6)
	_check(_ids(h).size() == 2 and h.weapons.current().id == &"kar98k", "map00: stored again, a Kar98k bought: slots full (%s)" % str(_ids(h)))
	_check(h.prompt_text.contains("lock away Kar98k and take " + label), "map00: the swap prompt: \"%s\"" % h.prompt_text)
	h.use_interactable(l)
	await _secs(0.3)
	_check(h.weapons.current().id == &"thompson_up" and WeaponLocker.instance_of(WeaponLocker.stored(1)).id == &"kar98k", "map00: swapped: %s in hand, the Kar98k inside" % label)
	ProfileSave.save_profile()
	_check(not FileAccess.get_file_as_string(ProfileSave.path).contains("kar98k"), "map00: nothing of it in the saved profile")
	# a new match
	await _load(SCENES["map00"])
	_check(not WeaponLocker.has_stored(1), "map00: a new match starts with the locker empty")
	l = _locker()
	_check(l != null and l._card.text == str(WeaponLocker.cfg()["text"]["card_empty"]), "map00: and its card reads EMPTY")


func _other(tag: String, row: Dictionary) -> void:
	await _load(SCENES[tag])
	var l: WeaponLocker = _locker()
	_check(l != null, "%s: the locker is there" % tag)
	if l == null:
		return
	_live_spot(tag, l, row)
	var h: Player = _root().player
	var stand: Vector3 = l.stand_point(0.6)
	var path: PackedVector3Array = NavigationServer3D.map_get_path(h.get_world_3d().navigation_map, _root().spawn_transform(1).origin, stand, true, 0xFFFFFFFF)
	_check(not path.is_empty() and path[path.size() - 1].distance_to(stand) < 0.8, "%s: the navmesh reaches the doors (%d points, ends %s, wanted %s)" % [tag, path.size(),
		str(path[path.size() - 1].snapped(Vector3.ONE * 0.1)) if not path.is_empty() else "-", str(stand.snapped(Vector3.ONE * 0.1))])
	h.weapons.give_weapon(&"mp40")
	Economy.grant_raw(1, 3000)
	var found: bool = await _walk_up(h, l)
	_check(found and h.prompt_text.contains("lock away MP40"), "%s: the use ray finds it, the prompt: \"%s\"" % [tag, h.prompt_text])
	_check(h.global_position.distance_to(stand) < 0.35, "%s: you stand where you walked to (moved %.2f m)" % [tag, h.global_position.distance_to(stand)])
	h.use_interactable(l)
	await _secs(0.3)
	_check(WeaponLocker.has_stored(1) and not _ids(h).has("mp40"), "%s: the MP40 locked away" % tag)
	h.use_interactable(l)
	await _secs(0.3)
	_check(not WeaponLocker.has_stored(1) and _ids(h).has("mp40"), "%s: and taken back" % tag)
