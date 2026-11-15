extends Node
## Smoke for T-254 (UPDATE 19: the Requisition Crate's and the Crucible's presentation pass) on Map 0: nothing that
## is gameplay moved. Calls the real interact() with the real Player:
##   the crate   the prompt and the 950 price, the roll takes cycle_seconds (4.5 s) and offers a pool weapon, the take
##               gives it and shuts the lid; the locator stands only where the crate is, from the roof up indoors and
##               from the floor at the Well (the sky probe), the snow lies on the Well's lid and slides off; Herr
##               Tamtam refunds, the crate goes down in 3.6 s and comes up at another spot, the old spot shows what it
##               left behind; the blocker and the use box are where they were
##   the Crucible  cold without the lever (no prompt to feed), the 5 s forge and the 15 s offer, the weapon comes back
##               taught; the room found its wall and ceiling with rays, built its housing off the navmesh with a
##               collider only where it is drawn, and the Crucible's own collider and use box are untouched
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_u19_box.tscn

var _map: MapRoot
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
	print("[qa] %-78s %s" % [what, "ok" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _spot(index: int) -> MysteryCrate:
	for n: Node in get_tree().get_nodes_in_group(&"crate_spots"):
		if (n as MysteryCrate).spot_index == index:
			return n as MysteryCrate
	return null


func _go(index: int) -> void:
	CrateManager.location_index = index
	for n: Node in get_tree().get_nodes_in_group(&"crate_spots"):
		(n as MysteryCrate).refresh()


func _run() -> void:
	GameState.character_id = &"dutch"
	GameState.bot_count = 0
	GameState.bot_ai_mode = "off"
	Campaign.reset()
	_map = (load("res://gravelight/maps/map00_crossroads/map00.tscn") as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child(_map)
	await _frames(20)
	_p = _map.get_node("Player1") as Player
	RoundManager.stop()
	GameState.god_mode = true
	if _map.director != null:
		_map.director.kill_all(true)
	await _crate()
	await _crucible()
	print("[qa] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)]))
	get_tree().quit(0 if _fails.is_empty() else 1)


func _crate() -> void:
	var cfg: Dictionary = GLData.table("crate")
	var hearth: MysteryCrate = _spot(0)
	var well: MysteryCrate = _spot(3)
	_check(hearth != null and well != null, "Map 0 has its crate spots")
	if hearth == null or well == null:
		return
	_go(0)
	await _frames(6)
	# the contract
	_check(hearth.interact_size == Vector3(1.6, 1.1, 0.3) and hearth.interact_offset == Vector3(0, 0.55, -0.45), "the crate's use box is where it was")
	var blk: StaticBody3D = hearth.get("_blocker") as StaticBody3D
	var shape: BoxShape3D = (blk.get_child(0) as CollisionShape3D).shape as BoxShape3D
	_check(shape.size == Vector3(1.4, 0.75, 0.7) and blk.collision_layer == (1 | (1 << 8)), "the blocker is the 1.4 x 0.75 x 0.7 box, solid where the crate stands")
	_check(int((well.get("_blocker") as StaticBody3D).collision_layer) == 0, "an empty spot blocks nothing")
	_check(int(cfg["cost"]) == 950 and is_equal_approx(float(cfg["cycle_seconds"]), 4.5) and is_equal_approx(float(cfg["pickup_window_seconds"]), 12.0), "crate.json: 950, 4.5 s, 12 s")
	_check(hearth.get_prompt(_p).contains("Requisition Crate") and hearth.get_prompt(_p).contains("950"), "the prompt names the crate and its price")
	# the locator: only where the crate is; from the roof indoors, from the floor outdoors
	var beam_h: MeshInstance3D = hearth.get("_beam") as MeshInstance3D
	var beam_w: MeshInstance3D = well.get("_beam") as MeshInstance3D
	await _secs(1.0)
	_check(beam_h.visible and not beam_w.visible, "the locator stands over the Hearth spot and not over the Well")
	var base_h: float = beam_h.position.y - MysteryCrate.BEACON_H * 0.5
	_check(not bool(hearth.get("_under_sky")) and base_h > 2.0, "the Hearth is under a roof: its locator starts above it (%.1f m up)" % base_h)
	_check(bool(well.get("_under_sky")) and is_zero_approx(beam_w.position.y - MysteryCrate.BEACON_H * 0.5), "the Well is under the sky: its locator starts at the crate")
	_check((well.get("_snow_lid") as Node3D) != null and (hearth.get("_snow_lid") as Node3D) == null, "snow lies on the Well's crate and not on the Hearth's")
	_check((well.get("_away") as Node3D).visible and not (hearth.get("_away") as Node3D).visible, "the empty Well spot shows what the crate left; the Hearth does not")
	# the roll
	Economy.grant_raw(_p.player_id, 5000)
	var before: int = Economy.get_scrip(_p.player_id)
	CrateManager.reset_match()
	CrateManager.location_index = 0
	hearth.interact(_p)
	_check(Economy.get_scrip(_p.player_id) == before - 950, "opening it costs 950")
	_check(hearth.phase == MysteryCrate.Phase.CYCLING, "the roll starts")
	await _secs(1.0)
	_check((hearth.get("_lid") as Node3D).rotation.x > 1.3, "the lid stands open")
	_check((hearth.get("_spill") as MeshInstance3D).visible and float(hearth.get("_open_k")) > 0.9, "light stands out of the box")
	_check((hearth.get("_float_model") as Node3D) != null, "a weapon model hangs in it")
	var t0: int = Time.get_ticks_msec()
	while hearth.phase == MysteryCrate.Phase.CYCLING and Time.get_ticks_msec() - t0 < 8000:
		await _frames(1)
	var took: float = 1.0 + float(Time.get_ticks_msec() - t0) / 1000.0
	_check(hearth.phase == MysteryCrate.Phase.OFFERED and absf(took - 4.5) < 0.5, "the offer comes after the 4.5 s cycle (%.2f s)" % took)
	var result: StringName = hearth.get("_result")
	var in_pool: bool = false
	for e: Dictionary in cfg["pool"]:
		if StringName(e["id"]) == result:
			in_pool = true
	_check(in_pool, "the result (%s) is from the pool" % result)
	_check(hearth.get_prompt(_p).begins_with("Hold") and hearth.get_prompt(_p).contains("take"), "the offer's prompt")
	hearth.interact(_p)
	_check(_p.weapons.find_weapon(result) != null or (GLData.table("weapons")["tactical"] as Dictionary).has(String(result)), "taking it gives the weapon")
	_check(hearth.phase == MysteryCrate.Phase.CLOSED, "the crate shuts")
	await _secs(0.6)
	_check((hearth.get("_lid") as Node3D).rotation.x < 0.05 and float(hearth.get("_open_k")) < 0.05, "the lid is down and the light is back in the box")
	# Herr Tamtam: refund, 3.6 s, the crate is somewhere else
	var held: int = Economy.get_scrip(_p.player_id)
	CrateManager.debug_next = CrateManager.DRUMMER
	hearth.interact(_p)
	_check(hearth.phase == MysteryCrate.Phase.DRUMMER, "the drummer's scene starts")
	_check(Economy.get_scrip(_p.player_id) == held, "the pull is refunded")
	var t1: int = Time.get_ticks_msec()
	while hearth.phase == MysteryCrate.Phase.DRUMMER and Time.get_ticks_msec() - t1 < 8000:
		await _frames(1)
	var gone: float = float(Time.get_ticks_msec() - t1) / 1000.0
	_check(absf(gone - 3.6) < 0.5, "the crate is gone after 3.6 s (%.2f s)" % gone)
	_check(CrateManager.location_index != 0 and hearth.phase == MysteryCrate.Phase.HIDDEN, "it moved to another spot (%d)" % CrateManager.location_index)
	var now: MysteryCrate = _spot(CrateManager.location_index)
	_check(now != null and now.phase == MysteryCrate.Phase.CLOSED and now.can_interact(_p), "the new spot can be used at once")
	await _secs(2.0)
	_check(now != null and is_zero_approx((now.get("_body") as Node3D).position.y), "the crate has come up through the floor there")
	_check((hearth.get("_away") as Node3D).visible and not (hearth.get("_beam") as MeshInstance3D).visible, "the Hearth spot is empty now: the marks, no locator")
	_check(now != null and (now.get("_beam") as MeshInstance3D).visible, "the locator stands over the new spot")


func _crucible() -> void:
	var cr: Crucible = get_tree().get_first_node_in_group(&"crucible") as Crucible
	var room: CrucibleRoom = _map.get_node_or_null("CrucibleRoom") as CrucibleRoom
	_check(cr != null and room != null, "the Crucible and its room")
	if cr == null or room == null:
		return
	_check(cr.interact_size == Vector3(2.2, 2.0, 0.3) and cr.interact_offset == Vector3(0, 1.0, -0.95), "the Crucible's use box is where it was")
	_check(is_equal_approx(cr.forge_seconds, 5.0) and is_equal_approx(cr.offer_seconds, 15.0), "5 s forge, 15 s offer")
	# the probe and the housing
	print("[qa] probe %s  housing %s" % [room.probe, room.sur])
	_check(float(room.probe["back"]) > 0.3 and float(room.probe["back"]) < 3.0, "the room found the wall behind the machine (%.2f m)" % float(room.probe["back"]))
	_check(float(room.probe["ceil"]) > 2.2 and float(room.probe["ceil"]) < 6.0, "the room found the ceiling (%.2f m)" % float(room.probe["ceil"]))
	_check(bool(room.sur.get("housed", false)), "the machine is housed against that wall")
	_check(absf(float(room.sur["z1"]) - float(room.probe["back"])) < 0.08, "the housing meets the wall")
	_check(float(room.sur["top"]) >= float(room.probe["ceil"]), "the housing meets the ceiling")
	var body: StaticBody3D = room.get_node_or_null("SurroundBody") as StaticBody3D
	_check(body != null and body.get_child_count() >= 1, "the housing is solid where it is drawn")
	var on_nav: int = 0
	var map_rid: RID = _map.get_world_3d().navigation_map
	for e: Array in room.piece_boxes:
		if str((e[1] as Dictionary).get("kind")) != "surround":
			continue
		for ab: AABB in e[2]:
			if not CrucibleRoom.is_standing(ab):
				continue
			for sx: float in [0.1, 0.5, 0.9]:
				for sz: float in [0.1, 0.5, 0.9]:
					var lp: Vector3 = Vector3(ab.position.x + ab.size.x * sx, 0.0, ab.position.z + ab.size.z * sz)
					var wp: Vector3 = room.global_transform * lp
					var cp: Vector3 = NavigationServer3D.map_get_closest_point(map_rid, wp)
					if Vector2(cp.x - wp.x, cp.z - wp.z).length() < 0.02 and absf(cp.y - wp.y) < 0.8:
						on_nav += 1
	_check(on_nav == 0, "no standing part of the housing is on the navmesh (%d samples on it)" % on_nav)
	var stand: Vector3 = cr.global_transform * Vector3(0, 0, -1.95)
	var sp: Vector3 = NavigationServer3D.map_get_closest_point(map_rid, stand)
	_check(Vector2(sp.x - stand.x, sp.z - stand.z).length() < 0.3, "the bots' stand point in front of the machine is still on the navmesh")
	# cold
	GameState.power_on = false
	cr.call("_refresh_power")
	_p.weapons.give_weapon(&"kar98k")
	Economy.grant_raw(_p.player_id, 20000)
	if cr.needs_power:
		_check(cr.get_prompt(_p) == "Power must be activated" and not cr.can_interact(_p), "cold: it wants the power")
		_check(not (cr.get("_fire") as OmniLight3D).visible, "cold: no fire in the mouth")
	GameState.power_on = true
	GLBus.power_activated.emit()
	await _frames(4)
	_check((cr.get("_fire") as OmniLight3D).visible, "powered: the fire is in")
	var price: int = Crucible.price_for(&"upgrade", GLData.table("economy"))
	_check(cr.get_prompt(_p).contains("feed the Crucible") and cr.get_prompt(_p).contains(str(price)), "the prompt and the price (%d)" % price)
	var before: int = Economy.get_scrip(_p.player_id)
	cr.interact(_p)
	_check(Economy.get_scrip(_p.player_id) == before - price, "feeding it costs %d" % price)
	_check(cr.phase == Crucible.Phase.FORGING and _p.weapons.find_weapon(&"kar98k") == null, "the weapon is in the forge")
	_check((cr.get("_fed") as Node3D) != null, "the fed weapon's own model slides into the mouth")
	var t0: int = Time.get_ticks_msec()
	while cr.phase == Crucible.Phase.FORGING and Time.get_ticks_msec() - t0 < 9000:
		await _frames(1)
	var took: float = float(Time.get_ticks_msec() - t0) / 1000.0
	_check(cr.phase == Crucible.Phase.OFFERED and absf(took - 5.0) < 0.5, "it comes out after the 5 s forge (%.2f s)" % took)
	_check((cr.get("_out") as Node3D) != null, "what hangs there is the upgraded weapon's model")
	_check(cr.get_prompt(_p).contains("take"), "the offer's prompt")
	cr.interact(_p)
	var got: WeaponInstance = _p.weapons.find_weapon(&"kar98k_up")
	_check(got != null and got.upgraded, "taking it gives the taught weapon")
	_check(cr.phase == Crucible.Phase.IDLE, "the Crucible is idle again")
	var cb: StaticBody3D = null
	for c: Node in cr.get_children():
		if c is StaticBody3D:
			cb = c as StaticBody3D
	_check(cb != null and cb.collision_layer == 1 << 8, "the Crucible's own body keeps its layer")
