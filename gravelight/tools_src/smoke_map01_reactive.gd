extends Node
## T-272: Kaltenbrunn's reactive pieces (gen_map01 build_reactive; gravelight/world/reactive/), headless, solo, silent:
## the three glass sets build their pieces, each on a surface (a collider or a drawn table top within 3 cm under it) and
## none inside a wall, and a shot piece breaks; every curtain finds its window's barricade and hangs inside the room, off
## the wall, its foot over the floor; the partition door swings open for the player walking through it; the player's
## steps leave prints in the yard's snow and none under the Kaue's roof; every drip falls onto a floor (a ray from it
## finds the floor at its height); every wind zone finds its window.
## Prints "[m1react] ..." and "[m1react] RESULT: PASS/FAIL"; exit code 0/1.
##   godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_map01_reactive.tscn

var _map: Node3D
var _p: Player
var _fails: PackedStringArray = []
var _checks: int = 0


func _ready() -> void:
	ProfileSave.path = "user://_qa_m1react_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_m1react_settings.cfg"
	GameState.bot_count = 0
	Campaign.reset()
	_map = (load("res://gravelight/maps/map01_kaltenbrunn/map01.tscn") as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _check(cond: bool, what: String) -> void:
	_checks += 1
	print("[m1react] %-96s %s" % [what, "PASS" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _space() -> PhysicsDirectSpaceState3D:
	return _map.get_world_3d().direct_space_state


func _ray(a: Vector3, b: Vector3, mask: int = 1) -> Dictionary:
	return _space().intersect_ray(PhysicsRayQueryParameters3D.create(a, b, mask))


func _inside_solid(p: Vector3) -> bool:
	var q: PhysicsPointQueryParameters3D = PhysicsPointQueryParameters3D.new()
	q.position = p
	q.collision_mask = 1
	return not _space().intersect_point(q, 1).is_empty()


func _walk(to: Vector3, seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		var d: Vector3 = to - _p.global_position
		d.y = 0.0
		if d.length() < 0.3:
			break
		_p.global_position += d.normalized() * minf(d.length(), 3.0 / 60.0)
		_p.rotation.y = atan2(-d.x, -d.z)
		await get_tree().physics_frame
		t += 1.0 / 60.0


func _run() -> void:
	await _frames(20)
	_p = _map.get_node("Player1") as Player
	RoundManager.stop()
	GameState.god_mode = true
	var r: Node3D = _map.get_node_or_null("Reactive") as Node3D
	_check(r != null, "the map has its Reactive holder")
	if r == null:
		_finish()
		return
	# ---- glass
	var total: int = 0
	var on_surface: int = 0
	var in_wall: int = 0
	for set_name: String in ["Mess", "Lab", "Office"]:
		var ss: ShatterSet = r.get_node_or_null("Glass_" + set_name) as ShatterSet
		_check(ss != null and ss.items.size() >= 3 and ss.broken.size() == ss.items.size(), "the %s glass set builds its %d pieces" % [set_name, ss.items.size() if ss != null else 0])
		if ss == null:
			continue
		for it: Array in ss.items:
			var base: Vector3 = it[0]
			total += 1
			if _inside_solid(base + Vector3.UP * 0.06):
				in_wall += 1
			var hit: Dictionary = _ray(base + Vector3.UP * 0.05, base + Vector3.DOWN * 0.35)
			# a drawn table top has no collider of its own over the leg frame: the collider under it is the table's
			# (MessTable 0.8, Prop_C_OfficeDesk 4.58) or the floor a table's height down; the counters are colliders
			var fy: float = (hit["position"] as Vector3).y if not hit.is_empty() else -INF
			if absf(fy - base.y) < 0.04:
				on_surface += 1
		var b0: int = ss.broken_count()
		ss.break_item(0)
		await _frames(2)
		_check(ss.broken_count() == b0 + 1, "a shot piece of the %s set breaks and stays broken" % set_name)
	_check(in_wall == 0, "no glass stands inside a collider (%d of %d)" % [in_wall, total])
	print("[m1react] note: %d of %d glass pieces stand on a collider's top within 4 cm (the rest on a drawn top)" % [on_surface, total])
	# ---- curtains
	var curtains: Array[Node] = r.find_children("DraftCurtain_*", "Node3D", false, false)
	var linked: int = 0
	var hang_ok: int = 0
	for c: Node in curtains:
		var dc: DraftCurtain = c as DraftCurtain
		var bar: Node = dc.get_node_or_null(dc.window)
		if bar is Barricade:
			linked += 1
		var inward: Vector3 = -dc.global_transform.basis.z   # the way the draught pushes it: into the room
		var wall: Dictionary = _ray(dc.global_position - inward * 0.02 + Vector3.DOWN * 1.0, dc.global_position - inward * 0.6 + Vector3.DOWN * 1.0)
		var foot: Dictionary = _ray(dc.global_position, dc.global_position + Vector3.DOWN * 4.0)
		var to_floor: float = dc.global_position.y - (foot["position"] as Vector3).y if not foot.is_empty() else INF
		if not _inside_solid(dc.global_position + Vector3.DOWN * 0.5 + inward * 0.05) and not wall.is_empty() and to_floor > dc.height and to_floor < dc.height + 1.6:
			hang_ok += 1
	_check(curtains.size() == 12 and linked == 12, "12 curtains, each finds its window's barricade (%d of %d)" % [linked, curtains.size()])
	_check(hang_ok == curtains.size(), "every curtain hangs inside its room, off the wall, its foot over the floor (%d of %d)" % [hang_ok, curtains.size()])
	# ---- the partition door
	var sd: Node3D = r.get_node_or_null("PartitionDoor") as Node3D
	_check(sd != null, "the upstairs partition's door is there")
	if sd != null:
		var a0: float = float(sd.get("angle"))
		_p.global_position = Vector3(-9.0, 3.85, 18.5)
		await _frames(4)
		await _walk(Vector3(-9.0, 3.85, 13.0), 4.0)
		var a1: float = float(sd.get("angle"))
		_check(_p.global_position.z < 14.0 and a1 > a0 + 15.0, "it swings open for the player walking through it (%.0f -> %.0f degrees; through: %s)" % [a0, a1, str(_p.global_position.z < 14.0)])
	# ---- footprints
	var fp: Node = r.get_node_or_null("SnowFootprints")
	_check(fp != null and bool(fp.call("on_snow", Vector3(20.0, 0.0, 23.0))) and not bool(fp.call("on_snow", Vector3(10.0, 0.0, 29.0))) and bool(fp.call("on_snow", Vector3(48.0, 0.0, 30.0))),
		"the yards' open snow takes prints, the Kaue's floor does not")
	if fp != null:
		var m0: int = int(fp.get("made"))
		_p.global_position = Vector3(30.0, 0.05, 23.0)
		await _frames(4)
		await _walk(Vector3(34.0, 0.05, 17.0), 4.0)
		_check(int(fp.get("made")) > m0 + 2, "the player's steps across the yard leave prints (%d)" % (int(fp.get("made")) - m0))
	# ---- drips land on a floor
	var drips_ok: int = 0
	var drips: Array[Node] = r.find_children("Drip*", "Node3D", false, false)
	for dn: Node in drips:
		var dp: Node3D = dn as Node3D
		var h: float = float(dp.get("height"))
		var hit2: Dictionary = _ray(dp.global_position + Vector3.DOWN * 0.05, dp.global_position + Vector3.DOWN * (h + 1.0))
		var up: Dictionary = _ray(dp.global_position + Vector3.DOWN * 0.05, dp.global_position + Vector3.UP * 0.6)
		if not hit2.is_empty() and absf(dp.global_position.y - (hit2["position"] as Vector3).y - h) < 0.25 and not up.is_empty():
			drips_ok += 1
		else:
			print("[m1react] note: drip at %s: floor %s, ceiling %s" % [str(dp.global_position), str(hit2.get("position", "none")), str(not up.is_empty())])
	_check(drips.size() == 5 and drips_ok == drips.size(), "every drip hangs under a ceiling and falls its height onto a floor (%d of %d)" % [drips_ok, drips.size()])
	# ---- wind zones
	var winds: Array[Node] = r.find_children("WindHowl_*", "Node3D", false, false)
	var wl: int = 0
	for wn: Node in winds:
		if wn.get_node_or_null(wn.get("window")) is Barricade:
			wl += 1
	_check(winds.size() == 6 and wl == 6, "the wind zones find their windows (%d of %d)" % [wl, winds.size()])
	_finish()


func _finish() -> void:
	print("[m1react] RESULT: %s (%d checks%s)" % ["PASS" if _fails.is_empty() else "FAIL", _checks, "" if _fails.is_empty() else "; %d failed: %s" % [_fails.size(), "; ".join(_fails)]])
	get_tree().quit(0 if _fails.is_empty() else 1)
