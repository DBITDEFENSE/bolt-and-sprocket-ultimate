extends Node
## Ladders and the zip line (T-229): on Map 0 the sniper tower's ladder carries the player up to the deck and back, the
## zip line runs them from the roof post down to the landing by the stable wall, the cellar hatch behind the bar is
## bolted until the Old Cellar opens and then climbs both ways; on Map 2 the U-boat's engine-room escape hatch climbs
## both ways. Every climb must end on the baked navmesh (where a zombie can reach you), and the zombies' climb links for
## the same ladders must be in the scene. Headless, silent.
##   godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_ladders.tscn

var _fails: PackedStringArray = []
var _map: Node3D
var _p: Player


func _ready() -> void:
	ProfileSave.path = "user://_qa_ladders_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _check(cond: bool, what: String) -> void:
	print("[ladders] %-60s %s" % [what, "ok" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _load(path: String) -> void:
	if _map != null and is_instance_valid(_map):
		_map.free()
	Campaign.reset()
	_map = (load(path) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(_map)
	await _frames(12)
	_p = _map.get_node("Player1") as Player
	RoundManager.stop()
	GameState.god_mode = true


func _on_nav(pos: Vector3, tol: float = 0.6) -> bool:
	var nav_map: RID = _p.get_world_3d().navigation_map
	var near: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, pos)
	return near.distance_to(pos) < tol


func _ladder(name_: String) -> LadderClimb:
	for n: Node in get_tree().get_nodes_in_group(&"ladders"):
		if n.name == name_:
			return n as LadderClimb
	return null


func _climb_and_check(l: LadderClimb, label: String) -> void:
	_p.global_position = l.global_position + Vector3(0, 0.05, 0)
	_p.velocity = Vector3.ZERO
	await _frames(3)
	_check(l.can_interact(_p), label + ": usable (" + l.get_prompt(_p) + ")")
	l.climb(_p)
	await _secs(l.ride_seconds(_p.global_position.y) + 0.9)
	_check(_p.global_position.distance_to(l.to_pos) < 0.3, label + ": the climb ended at to_pos (at %s, wanted %s)" % [str(_p.global_position), str(l.to_pos)])
	_check(_on_nav(_p.global_position, 0.7), label + ": the climb's end is on the navmesh")
	_check(_p.is_physics_processing(), label + ": the player moves again after it")
	if _p.global_position.distance_to(l.to_pos) >= 0.3:
		for c: Node in _p.get_children():   # what overlaps the body at to_pos
			if c is CollisionShape3D:
				var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
				q.shape = (c as CollisionShape3D).shape
				q.transform = Transform3D(Basis.IDENTITY, l.to_pos + (c as CollisionShape3D).position)
				q.collision_mask = 0xFFFFFFFF
				for hit: Dictionary in _p.get_world_3d().direct_space_state.intersect_shape(q, 8):
					var col: Node = hit.get("collider")
					print("[ladders]   overlaps at to_pos: %s (%s)" % [str(col.get_path()) if col != null else "?", str(col.get("collision_layer")) if col != null else ""])


func _run() -> void:
	await _load("res://gravelight/maps/map00_crossroads/map00.tscn")
	# the sniper tower
	var up: LadderClimb = _ladder("TowerLadder_Foot")
	var down: LadderClimb = _ladder("TowerLadder_Top")
	_check(up != null and down != null, "map00: the tower's two LadderClimbs are in the scene")
	if up != null and down != null:
		await _climb_and_check(up, "tower up")
		var zip: ZipLine = null
		for n: Node in get_tree().get_nodes_in_group(&"ziplines"):
			zip = n as ZipLine
		_check(zip != null, "map00: the yard zip line is in the scene")
		if zip != null:
			_check(_on_nav(zip.to_pos, 0.7), "zip: the landing is on the navmesh")
			_check(zip.can_interact(_p), "zip: usable from the deck (" + zip.get_prompt(_p) + ")")
			zip.ride(_p)
			await _secs(zip.ride_seconds() + 0.9)
			_check(_p.global_position.distance_to(zip.to_pos) < 0.3, "zip: the ride ended at the landing")
			_check(_p.is_physics_processing(), "zip: the player moves again after it")
		await _climb_and_check(down, "tower down")
	var links: Node = _map.get_node_or_null("ClimbLinks")
	_check(links != null and links.has_node("Climb_Tower") and links.has_node("Climb_CellarHatch"), "map00: the zombies' climb links (tower, hatch) exist")
	# the cellar hatch: bolted until the Old Cellar opens
	var hup: LadderClimb = _ladder("CellarHatch_Up")
	var hdown: LadderClimb = _ladder("CellarHatch_Down")
	_check(hup != null and hdown != null, "map00: the cellar hatch's two LadderClimbs are in the scene")
	if hup != null and hdown != null:
		_check(not hdown.can_interact(_p) and hdown.get_prompt(_p).contains("bolted"), "hatch: bolted before the Old Cellar opens (" + hdown.get_prompt(_p) + ")")
		var td: Node = _map.get_node_or_null("Gameplay/CellarTrapdoor")
		if td == null:
			td = _map.find_child("CellarTrapdoor", true, false)
		_check(td != null and not bool(td.get("is_open")), "hatch: the trapdoor leaf is shut")
		GameState.open_zone(&"OLD_CELLAR")
		await _frames(3)
		_check(td != null and bool(td.get("is_open")), "hatch: the leaf opens with the Old Cellar")
		await _climb_and_check(hdown, "hatch down")
		await _climb_and_check(hup, "hatch up")
	# Totenhafen: the engine room's escape hatch
	await _load("res://gravelight/maps/map02_totenhafen/map02.tscn")
	GameState.open_zone(&"D_PENHALL")
	GameState.open_zone(&"E_UBOAT")
	await _frames(3)
	var eup: LadderClimb = _ladder("EngineHatch_Up")
	var edown: LadderClimb = _ladder("EngineHatch_Down")
	_check(eup != null and edown != null, "map02: the escape hatch's two LadderClimbs are in the scene")
	if eup != null and edown != null:
		await _climb_and_check(eup, "escape hatch up")
		await _climb_and_check(edown, "escape hatch down")
	var links2: Node = _map.get_node_or_null("ClimbLinks")
	_check(links2 != null and links2.has_node("Ladder_EngineHatch"), "map02: the zombies' climb link for the hatch exists")
	print("[ladders] RESULT %s (%d failed)" % ["PASS" if _fails.is_empty() else "FAIL", _fails.size()])
	for f: String in _fails:
		print("[ladders]   - " + f)
	get_tree().quit(0 if _fails.is_empty() else 1)
