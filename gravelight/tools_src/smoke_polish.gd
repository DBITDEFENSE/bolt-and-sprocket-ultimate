extends Node
## Headless smoke for Update 02 section 8 (T-053), Map 0's small-detail polish: the reactive pieces are on the map
## and react. A shot ray (WeaponHolder's mask, areas on) at a bar bottle breaks it and passes on through; one at a
## lantern swings it; one at a curtain flutters it; a hole shot into a wall persists past the old 8 s and a blast
## leaves a scorch; the player walking across the stable straw kicks up chaff, through a guest-room doorway swings
## the door, and across the snow outside leaves footprints; the hearth's crackle and the window wind are playing; the
## horse is heard only in the first rounds; a bought door creaks; the paper dressing has its art.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_polish.tscn

var map: Node3D
var player: Player
var _fails: PackedStringArray = []


func _ready() -> void:
	ProfileSave.path = "user://_qa_polish_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GameState.god_mode = true
	map = (load("res://gravelight/maps/map00_crossroads/map00.tscn") as PackedScene).instantiate() as Node3D
	map.set("auto_rounds", false)
	get_tree().root.add_child.call_deferred(map)
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print("[polish-smoke] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails.append(what)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


## The player's shot ray from `from` toward `to`: returns the first collider (areas included), or null.
## Like WeaponHolder._trace, colliders tagged "shot_through" (open shelving) are passed.
func _ray(from: Vector3, to: Vector3, exclude: Array[RID] = []) -> Dictionary:
	for i: int in 6:
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, WeaponHolder.MASK_SHOT, exclude)
		q.collide_with_areas = true
		var res: Dictionary = map.get_world_3d().direct_space_state.intersect_ray(q)
		if res.is_empty() or not (res["collider"] as Node).has_meta("shot_through"):
			return res
		exclude.append((res["collider"] as CollisionObject3D).get_rid())
	return {}


func _run() -> void:
	await _wait(1.5)
	player = map.get("player") as Player
	var r: Node3D = map.get_node_or_null("Reactive") as Node3D
	_check(r != null, "the Reactive node is on the map")
	if r == null or player == null:
		_finish()
		return
	var bar: ShatterSet = r.get_node_or_null("Glass_Bar") as ShatterSet
	var tap: ShatterSet = r.get_node_or_null("Glass_Taproom") as ShatterSet
	_check(bar != null and bar.items.size() >= 60, "bar glassware: %d pieces" % (bar.items.size() if bar else 0))
	_check(tap != null and tap.items.size() >= 9, "taproom glassware: %d pieces" % (tap.items.size() if tap else 0))
	# ---- a shot at a bottle on the back shelf (from the room side of the counter)
	if bar != null:
		var it: Array = bar.items[30]
		var target: Vector3 = bar.to_global(it[0]) + Vector3(0, 0.12, 0)
		var from: Vector3 = target + Vector3(4.0, 0.3, 0.0)
		var hit: Dictionary = _ray(from, target + (target - from).normalized() * 2.0)
		var col: Object = hit.get("collider")
		_check(col != null and DecorHit.is_decor(col), "the shot ray meets the bottle's decor volume")
		if col != null and DecorHit.is_decor(col):
			DecorHit.hit(col, hit["position"], (target - from).normalized())
		_check(bar.broken_count() >= 1, "the bottle broke")
		var fx: ReactiveFx = get_tree().get_first_node_in_group(&"reactive_fx") as ReactiveFx
		_check(fx != null and int(fx.counts.get("glass", 0)) >= 1, "glass shards flew")
		# the ray passes on through the broken bottle's slot to the shelf's back board
		var again: Dictionary = _ray(from, target + (target - from).normalized() * 2.0)
		_check(again.is_empty() or again.get("collider") != col, "a broken bottle no longer stops shots")
	# ---- a lantern swings when shot
	var sway: LampSway = LampSway.find(get_tree())
	var lamp_area: Area3D = null
	for a: Node in map.find_children("DecorHit", "Area3D", true, false):
		if a.has_meta("decor_kind") and str(a.get_meta("decor_kind")) == "lamp":
			lamp_area = a as Area3D
			break
	_check(sway != null and lamp_area != null, "lanterns carry a decor hit volume")
	if sway != null and lamp_area != null:
		var piv: Node3D = lamp_area.get_parent() as Node3D
		DecorHit.hit(lamp_area, lamp_area.global_position, Vector3.RIGHT)
		await _wait(0.25)
		_check(piv.rotation.length() > 0.02, "the shot lantern swings (%.3f rad)" % piv.rotation.length())
	# ---- a curtain flutters when shot
	var curtain: DraftCurtain = map.find_child("DraftCurtainL", true, false) as DraftCurtain
	var curtains: int = 0
	for n0: Node in map.find_children("DraftCurtain*", "", true, false):
		if n0 is DraftCurtain:
			curtains += 1
	_check(curtain != null and curtains == 12, "12 draught curtains (%d)" % curtains)
	if curtain != null:
		var ca: Area3D = curtain.get_node_or_null("DecorHit") as Area3D
		var cam: Camera3D = player.camera
		cam.global_position = curtain.global_position + Vector3(0, -0.8, 1.5)
		if ca != null:
			DecorHit.hit(ca, ca.global_position, Vector3.FORWARD)
		await _wait(0.4)
		_check(curtain.max_swing > 0.05, "the curtain moves (%.3f rad)" % curtain.max_swing)
	# ---- persistent holes and scorch marks
	Effects.clear_marks()
	var wall_hit: Dictionary = _ray(Vector3(12, 1.6, 8), Vector3(12, 1.6, 30))   # the taproom's south wall
	var wcol: Object = wall_hit.get("collider")
	_check(wcol != null and Effects.persists_on(wcol), "the taproom's south wall keeps bullet holes")
	if wcol != null:
		Effects.impact(wall_hit["position"], wall_hit["normal"], "stone", wcol)
	var rail_hit: Dictionary = _ray(Vector3(4.5, 0.47, 13.0), Vector3(2.0, 1.6, 13.0))
	var rcol: Object = rail_hit.get("collider")
	_check(rcol == null or not Effects.persists_on(rcol) or not str((rcol as Node).name).contains("Panel"), "invisible rail panels don't keep floating holes")
	Effects.explosion(Vector3(14, 0.3, 8), 3.0)
	await _wait(9.0)
	_check(Effects.persistent_hole_count() >= 1, "the bullet hole is still there after 9 s")
	_check(Effects.scorch_count() == 1, "the blast left a scorch mark")
	_check(tap != null and tap.broken_count() == 0, "a blast in the middle of the room breaks no glass out of reach")
	# ---- hay puffs underfoot
	var hay: HayPuffZone = null
	for z: Node in r.get_children():
		if z is HayPuffZone and (z as HayPuffZone).global_position.distance_to(Vector3(12.5, 0, 23.6)) < 0.1:
			hay = z
	_check(hay != null and r.find_children("HayPuff*", "Area3D", false, false).size() >= 7, "hay zones in the stable and the loft")
	if hay != null:
		for d: Node in get_tree().get_nodes_in_group(&"doors"):
			(d as BuyDoor).open(1)
		await _wait(0.5)
		await _walk(Vector3(11.8, 0.05, 23.6), Vector3(13.3, 0.05, 23.6), 1.4)
		_check(hay.puffs >= 1, "walking through the straw kicks up chaff (%d puffs)" % hay.puffs)
	# ---- a guest-room door swings out of the way
	var door: SwingDoor = null
	for n: Node in r.get_children():
		if n is SwingDoor and absf((n as SwingDoor).global_position.x - 11.0) < 0.1:
			door = n
	_check(door != null and r.find_children("RoomDoor*", "", false, false).size() == 3, "three guest-room doors ajar")
	if door != null:
		var rest: float = door.angle
		await _walk(Vector3(11.75, 3.85, 8.0), Vector3(11.75, 3.85, 4.5), 2.0)
		_check(door.angle > rest + 15.0, "Room 2's door swung open as the player came through (%.0f -> %.0f deg)" % [rest, door.angle])
	# ---- footprints in the snow
	var fp: SnowFootprints = map.get_node_or_null("SnowFootprints") as SnowFootprints
	_check(fp != null, "SnowFootprints on the map")
	if fp != null:
		var before: int = fp.made
		await _walk(Vector3(-8.0, 0.05, -6.0), Vector3(-8.0, 0.05, -14.0), 3.0)
		_check(fp.made >= before + 6, "walking 8 m of snow leaves prints (%d)" % (fp.made - before))
		var inside: int = fp.made
		await _walk(Vector3(12.0, 0.05, 8.0), Vector3(16.0, 0.05, 8.0), 1.5)
		_check(fp.made == inside, "none on the taproom floor")
	# ---- sound
	var hearth: AudioZone = r.get_node_or_null("HearthCrackle") as AudioZone
	_check(hearth != null and hearth.player != null and hearth.player.playing, "the hearth crackles")
	var winds: int = 0
	for n2: Node in r.get_children():
		if n2 is AudioZone and String(n2.name).begins_with("WindHowl") and (n2 as AudioZone).player != null and (n2 as AudioZone).player.playing:
			winds += 1
	_check(winds == 10, "wind howls at the 10 broken windows (%d)" % winds)
	var horse: AudioZone = r.get_node_or_null("HorseInTheStall") as AudioZone
	_check(horse != null and horse.round_ok(1) and not horse.round_ok(3), "the horse is heard in rounds 1-2 only")
	_check(r.get_node_or_null("StableCreaks") != null, "the stable creaks")
	_check(AudioDirector.has_sound("door_creak"), "doors creak (door_creak)")
	# ---- the paper
	var papers: int = r.find_children("Paper*", "", false, false).size()
	_check(papers == 7, "paper dressing: calendar, two notes, the map, three drawings (%d)" % papers)
	_finish()


## Drives the player from a to b over `secs` (positions and velocity, as the movement would).
func _walk(a: Vector3, b: Vector3, secs: float) -> void:
	player.set_physics_process(false)   # the movement code would overwrite the velocity we fake
	player.global_position = a
	var t: float = 0.0
	while t < secs:
		await get_tree().physics_frame
		var dt: float = get_physics_process_delta_time()
		t += dt
		player.velocity = (b - a) / secs
		player.global_position = a.lerp(b, clampf(t / secs, 0.0, 1.0))
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)


func _finish() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_qa_polish_profile.json"))
	print("RESULT %s (%d failed)" % ["PASS" if _fails.is_empty() else "FAIL: " + ", ".join(_fails), _fails.size()])
	get_tree().quit(0 if _fails.is_empty() else 1)
