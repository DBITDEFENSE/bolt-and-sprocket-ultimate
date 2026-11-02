extends Node
## UPDATE 10 §7 (contract C7, DECISIONS T-163): three bots on Fernflug's new set-pieces, headless (BotSetPieces).
##   1. Act III, the dust storm: no bot sprints (a stalker hears it 18 m off), the formation tightens, a stalker 14 m
##      off is let be (no shot that would call the rest), one within 5 m is shot; a warned collapse box becomes a
##      danger zone until it falls.
##   2. Act II, the wing walk (a risky optional task, Full Partner): a bot climbs out, clips in before walking the
##      catwalk, takes the wingtip locker's discount token and climbs back in; a decompression's warning sends a bot
##      near the breach to a rail (RailGrip holders) and it lets go when the event is over.
##   3. Act IV, the meteor shower: from the warning on, the bots in the yard go under the concourse roof; Pohl's
##      favour (Full Partner, the Account open): a bot takes his tag and reads it in at the console's slot.
## The bots worker's searchlight-order case (Totenhafen) is added by the lead's half of T-163.
## Each phase loads its act the launcher's way (Campaign.begin_at with the arrival kit), god mode, rounds stopped.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_bots_u10.tscn

const TIMEOUT: float = 900.0
const ACTS: Dictionary = {
	"map04c": ["res://gravelight/maps/map04_fernflug/map04c.tscn", &"map04c_groomlake", 21],
	"map04b": ["res://gravelight/maps/map04_fernflug/map04b.tscn", &"map04b_kranich", 15],
	"map04d": ["res://gravelight/maps/map04_fernflug/map04d.tscn", &"map04d_mondlicht", 30],
}

var _map: Node3D = null
var _p: Player = null
var _fails: PackedStringArray = []
var _t: float = 0.0
var _done: bool = false


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile_bots_u10.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_bots_u10_settings.cfg"
	GLSettings.values["homage_bosses"] = false
	GameState.character_id = &"peg"
	GameState.bot_count = 3
	Campaign.cutscene_speed = 12.0
	_run.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if not _done and _t > TIMEOUT:
		_fails.append("timeout after %.0f s" % _t)
		_finish()


func _run() -> void:
	await _storm()
	await _wing_and_breach()
	await _meteors()
	await _searchlight()
	_finish()


# ---------------------------------------------------------------- harness

func _load(key: String, ee: String) -> void:
	if _map != null:
		_map.queue_free()
		await _frames(10)
	GLSettings.values["bot_ee_help"] = ee
	var a: Array = ACTS[key]
	Campaign.begin_at(a[1], int(a[2]), Campaign.arrival_kit(a[1]))
	_map = (load(str(a[0])) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(_map)
	get_tree().current_scene = _map
	GameState.god_mode = true
	await _frames(40)
	_p = _map.get_node("Player1") as Player
	RoundManager.stop()
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		var bd: BuyDoor = n as BuyDoor
		if bd != null and not bd.is_open:
			bd.open(0)
	for z: Zombie in _dir().active_zombies():
		if not (z is HomageBoss):
			z.kill_silently()
	await _frames(10)


func _dir() -> ZombieDirector:
	return _map.get_node("ZombieDirector") as ZombieDirector


func _brains() -> Array[BotBrain]:
	var sq: BotSquad = _map.get("squad") as BotSquad
	return sq.brains if sq != null else ([] as Array[BotBrain])


func _bots_to(pos: Vector3) -> void:
	var i: int = 0
	for b: BotBrain in _brains():
		b.player.global_position = pos + Vector3(1.2 * float(i + 1), 0.0, 0.8 * float(i))
		b.player.velocity = Vector3.ZERO
		i += 1
	await _frames(3)


func _tp(pos: Vector3) -> void:
	_p.global_position = pos
	_p.velocity = Vector3.ZERO
	await _frames(3)


func _zombie_at(pos: Vector3) -> Zombie:
	_dir().debug_spawn(1)
	await _frames(2)
	var zs: Array[Zombie] = _dir().active_zombies()
	if zs.is_empty():
		return null
	var z: Zombie = zs[zs.size() - 1]
	z.global_position = pos
	if z.window != null:
		z.window.release(z)
	z.window = null
	z.collision_mask = Zombie.LAYER_WORLD | Zombie.LAYER_PLAYER | Zombie.LAYER_ZBODY | Zombie.LAYER_DOOR
	z._enter(Zombie.State.CHASE)
	await _frames(2)
	return z


func _shots() -> int:
	var n: int = 0
	for b: BotBrain in _brains():
		n += b.aim.shots
	return n


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _until(pred: Callable, seconds: float) -> bool:
	var t: float = 0.0
	while t < seconds:
		if pred.call():
			return true
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	return pred.call()


func _check(cond: bool, what: String) -> void:
	print("[bots_u10] %-84s %s" % [what, "ok" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# ---------------------------------------------------------------- 1. Act III: the dust storm, a collapse

func _storm() -> void:
	await _load("map04c", "off")
	var gc: GroomController = get_tree().get_first_node_in_group(&"groom_controller") as GroomController
	_check(gc != null and _brains().size() == 3, "Act III with three bots")
	if gc == null or _brains().size() < 3:
		return
	await _tp(Vector3(0, 0, 30))
	await _bots_to(Vector3(0, 0, 33))
	gc.debug_storm(true)
	await _secs(1.0)
	var all_storm: bool = true
	for b: BotBrain in _brains():
		all_storm = all_storm and b.setpieces != null and b.setpieces.storm and b.setpieces.no_sprint()
	_check(all_storm, "every bot knows the storm is on (no sprint)")
	_check(is_equal_approx(float(_brains()[1].loco.get("spacing_mult")), float(BotSetPieces.c("storm", "spacing_mult", 0.6))), "the formation tightens (stay close)")
	# the leader walks off 22 m: the bots catch up, but never at a sprint
	await _tp(Vector3(-22, 0, 30))
	var sprinted: bool = false
	for i: int in 240:
		await get_tree().physics_frame
		for b: BotBrain in _brains():
			sprinted = sprinted or b.player.sprinting
	_check(not sprinted, "catching up 22 m in the storm: nobody sprints")
	var close: bool = true
	for b2: BotBrain in _brains():
		close = close and _flat(b2.player.global_position, _p.global_position) < 9.0
	_check(close, "they keep close to the leader")
	# a stalker 14 m off is let be
	await _bots_to(Vector3(-22, 0, 33))
	var z: Zombie = await _zombie_at(Vector3(-22, 0, 48))
	if z == null:
		_check(false, "a stalker spawned")
		return
	gc._maybe_hunt(z)
	_check(z.hunt_by_sound, "a surface Ganger in the storm hunts by sound")
	z.set_physics_process(false)   # held 14 m off (it would walk to the last heard spot)
	var s0: int = _shots()
	var held0: int = 0
	for b3: BotBrain in _brains():
		held0 += b3.setpieces.held_fire
		b3.player.look_at(Vector3(z.global_position.x, b3.player.global_position.y, z.global_position.z))   # facing it: it is seen
	var seen: bool = await _until(func() -> bool:
		for b8: BotBrain in _brains():
			if b8.aim.target == z:
				return true
		return false, 6.0)
	_check(seen, "a bot has the stalker in its sights")
	await _secs(3.0)
	for b9: BotBrain in _brains():
		print("[bots_u10]   %s target %s visible %s known %d nearest %.1f action %s" % [b9.player.character_id, str(b9.aim.target == z), str(b9.perception.is_visible(z)),
			b9.perception.known.size(), b9.perception.nearest_d, b9.action])
	var held1: int = 0
	for b4: BotBrain in _brains():
		held1 += b4.setpieces.held_fire
	_check(_shots() == s0 and z.is_active(), "a stalker 14 m off is let be: no shot calls the rest (shots %d -> %d)" % [s0, _shots()])
	_check(held1 > held0, "the aim layer held fire on purpose (%d)" % (held1 - held0))
	# within 5 m: shot
	z.global_position = Vector3(-22, 0, 37.5)
	z.set_physics_process(true)
	var shot: bool = await _until(func() -> bool: return _shots() > s0 or not z.is_active(), 6.0)
	_check(shot, "a stalker within 5 m is shot (shots %d)" % (_shots() - s0))
	gc.debug_storm(false)
	await _secs(0.5)
	_check(not _brains()[0].setpieces.storm and is_equal_approx(float(_brains()[1].loco.get("spacing_mult")), 1.0), "after the storm: the old spacing and sprinting")
	# a warned collapse: its box is a danger zone until it falls
	var sec: Dictionary = {}
	for s: Variant in (gc.cfg.get("wreck_collapse", {}) as Dictionary).get("sections", []):
		if not gc.collapsed.has(str((s as Dictionary).get("id", ""))):
			sec = s
			break
	if sec.is_empty():
		_check(false, "a section still standing to warn")
		return
	gc._warn_collapse(sec)
	await _secs(1.0)
	var disc: Dictionary = BotSetPieces.box_disc(sec.get("box", []), 0.0)
	_check(_brains()[0].in_danger(disc["pos"]), "the warned section's box (%s) is a danger zone for the bots" % str(sec.get("id", "")))
	var fell: bool = await _until(func() -> bool: return gc.collapsed.has(str(sec.get("id", ""))), 14.0)
	await _secs(1.5)
	_check(fell and not _brains()[0].in_danger(disc["pos"]) or (fell and BotSetPieces.box_disc(sec.get("box", []), 0.0).is_empty()), "fallen: the zone lifts (the debris is navmesh now)")


# ---------------------------------------------------------------- 2. Act II: the wing walk, a breach's rail

func _wing_and_breach() -> void:
	await _load("map04b", "full")
	var ww: WingWalk = get_tree().get_first_node_in_group(&"wing_walks") as WingWalk
	var chest: WingChest = get_tree().get_first_node_in_group(&"wing_chests") as WingChest
	_check(ww != null and chest != null and _brains().size() == 3, "Act II with three bots, the wing walk and its locker")
	if ww == null or chest == null or _brains().size() < 3:
		return
	GameState.open_zone(&"B_MITTELRUMPF")
	GameState.open_zone(&"C_FLUEGEL_L")
	ww.open_now()
	await _frames(5)
	# the squad by the hatch in the port crawlway, nothing about: a quiet spell
	await _tp(Vector3(-36, 0, 44))
	await _bots_to(Vector3(-38, 0, 41))
	var walker: Array = [null]
	var went: bool = await _until(func() -> bool:
		for b: BotBrain in _brains():
			if b.setpieces != null and str(b.setpieces.move.get("kind", "")) == "wing_walk":
				walker[0] = b
				return true
		return false, 12.0)
	_check(went, "Full Partner, a quiet spell: one bot sets out on the wing walk")
	if not went:
		return
	var bw: BotBrain = walker[0]
	var others: int = 0
	for b2: BotBrain in _brains():
		if b2 != bw and str(b2.setpieces.move.get("kind", "")) == "wing_walk":
			others += 1
	_check(others == 0, "only one bot at a time (the blackboard claim)")
	var on_deck: bool = await _until(func() -> bool: return WingWalk.on_deck(ww.cfg["segments"], 3.4, bw.player.global_position), 30.0)
	_check(on_deck, "%s climbs out onto the catwalk" % String(bw.player.character_id))
	var clipped_on_deck: bool = await _until(func() -> bool: return ww.is_clipped(bw.player.player_id), 12.0)
	_check(clipped_on_deck and bw.setpieces.wing_clips >= 1, "...and clips in at a tether post (state %d)" % ww.state_of(bw.player.player_id))
	var got: bool = await _until(func() -> bool: return chest.state == WingChest.State.EMPTY, 90.0)
	_check(got and chest.taken_by == bw.player.player_id, "the wingtip locker opened and emptied by the bot (taken by P%d)" % chest.taken_by)
	_check(PerkManager.has_discount_token(bw.player.player_id) if PerkManager.has_method("has_discount_token") else int(PerkManager.discount_tokens.get(bw.player.player_id, 0)) > 0,
		"the discount token is the bot's (its next tonic tier at half price)")
	var back: bool = await _until(func() -> bool: return bw.setpieces.move.is_empty() and not WingWalk.on_deck(ww.cfg["segments"], 3.4, bw.player.global_position), 60.0)
	_check(back and ww.knocked == 0, "back inside, never thrown off (knocked %d)" % ww.knocked)
	# a decompression: the bots near it hold a rail
	var br: DecompressionBreach = null
	for n: Node in get_tree().get_nodes_in_group(&"decompressions"):
		if br == null or String(n.name) == "DecompBay":
			br = n as DecompressionBreach
	_check(br != null, "a decompression breach on the deck")
	if br == null:
		return
	var hole: Vector3 = br.hole()
	var inside: Vector3 = hole + (br.global_basis * Vector3(0, 0, -5.0))
	inside.y = 0.0
	await _tp(inside + Vector3(0, 0, -1.5))
	await _bots_to(inside)
	br.start()
	var gripped: Array = [null]
	var grip_ok: bool = await _until(func() -> bool:
		for r: Node in get_tree().get_nodes_in_group(&"rail_grips"):
			for b3: BotBrain in _brains():
				if (r as RailGrip).holds(b3.player.player_id):
					gripped[0] = b3
					return true
		return false, 4.0)
	_check(grip_ok, "the warning: a bot near the breach takes a rail (RailGrip holds it)")
	var done: bool = await _until(func() -> bool: return br.phase == DecompressionBreach.Phase.DONE, 20.0)
	await _secs(1.0)
	var still: bool = false
	for r2: Node in get_tree().get_nodes_in_group(&"rail_grips"):
		for b4: BotBrain in _brains():
			still = still or (r2 as RailGrip).holds(b4.player.player_id)
	_check(done and not still, "the event over: every rail let go")
	var down: int = 0
	for b5: BotBrain in _brains():
		if b5.player.downed:
			down += 1
	_check(down == 0, "no bot was pulled to the edge and downed (%d)" % down)


# ---------------------------------------------------------------- 3. Act IV: the meteor shower

func _meteors() -> void:
	await _load("map04d", "off")
	var ms: Node = get_tree().get_first_node_in_group(&"meteor_shower")
	_check(ms != null and _brains().size() == 3, "Act IV with three bots and the meteor shower")
	if ms == null or _brains().size() < 3:
		return
	var box: Array = (ms.get("cfg") as Dictionary).get("yard_box", [])
	await _tp(Vector3(-8, 0, 70))
	await _bots_to(Vector3(-10, 0, 72))
	var in_yard: int = 0
	for b: BotBrain in _brains():
		if BotSetPieces.in_box2(box, b.player.global_position):
			in_yard += 1
	_check(in_yard == 3, "three bots out in the yard")
	ms.call("begin")
	await _frames(3)
	_check(bool(ms.get("warning")), "the warning is on (MeteorShower.warning)")
	var out: bool = await _until(func() -> bool:
		for b2: BotBrain in _brains():
			if BotSetPieces.in_box2(box, b2.player.global_position, 0.5):
				return false
		return true, 20.0)
	_check(out, "from the warning on, every bot goes under the concourse roof")
	var sheltered: int = 0
	for b3: BotBrain in _brains():
		sheltered += b3.setpieces.shelters
	_check(sheltered >= 3, "each took the shelter move (%d)" % sheltered)
	await _until(func() -> bool: return not bool(ms.get("active")) and not bool(ms.get("warning")), 60.0)
	# Pohl's favour: Full Partner, the Account open (the columns' flag), nothing about
	GLSettings.values["bot_ee_help"] = "full"
	GameState.set_flag(&"account_open")
	GameState.open_zone(&"F_CORE")
	for z: Zombie in _dir().active_zombies():
		z.kill_silently()
	await _tp(Vector3(28, 0, 36))
	await _bots_to(Vector3(26, 0, 38))
	var slot: Node = get_tree().get_first_node_in_group(&"tag_slot")
	_check(slot != null, "the Account console's tag slot")
	if slot == null:
		return
	var read: bool = await _until(func() -> bool: return bool(slot.get("done")), 120.0)
	var by: String = ""
	for b4: BotBrain in _brains():
		if b4.setpieces.favours > 0:
			by = String(b4.player.character_id)
	_check(read and GameState.has_flag(&"pohl_tag_read") and by != "", "a bot read Pohl's tag into the record (%s)" % by)


# ---------------------------------------------------------------- 4. Totenhafen: the searchlight by mark order

## T-153's MAN_SEARCHLIGHT: a map mark (any kind but Defend) on the signal tower's light sends a bot up to man it
## (BotMarkOrders.route -> "man"). Powered, every door open, no zombies: a bot is its operator within 150 s.
func _searchlight() -> void:
	if _map != null:
		_map.queue_free()
		await _frames(10)
	Campaign.reset()
	GLSettings.values["bot_ee_help"] = "off"
	_map = (load("res://gravelight/maps/map02_totenhafen/map02.tscn") as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(_map)
	get_tree().current_scene = _map
	GameState.god_mode = true
	await _frames(40)
	_p = _map.get_node("Player1") as Player
	RoundManager.stop()
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		var bd: BuyDoor = n as BuyDoor
		if bd != null and not bd.is_open:
			bd.open(0)
	for n2: Node in _map.find_children("*", "", true, false):
		if n2.has_method("run_sequence") and n2.get_script() != null and str((n2.get_script() as Script).resource_path).ends_with("power_switch.gd"):
			n2.call("run_sequence", 1)
	for z: Zombie in _dir().active_zombies():
		z.kill_silently()
	await _secs(2.0)
	var sl: Searchlight = get_tree().get_first_node_in_group(&"searchlights") as Searchlight
	_check(sl != null, "Totenhafen's tower searchlight")
	if sl == null:
		return
	_check(GameState.power_on, "the power is on (the light needs it)")
	var b0: BotBrain = _brains()[0] if not _brains().is_empty() else null
	if b0 != null:
		var near: Vector3 = b0.snap(sl.global_position + sl.global_basis * Vector3(0, 0, 6.0))
		await _tp(near + Vector3(0, 0, 2))
		await _bots_to(near)
	var mm: MapMarks = MapMarks.current()
	_check(mm != null, "the map marks")
	if mm == null:
		return
	var r: Dictionary = mm.place({"kind": "go", "pos": sl.global_position, "node": sl, "target": "any"})
	_check(bool(r.get("ok", false)), "the mark on the light became an order (%s)" % str(r.get("reason", "")))
	var me: int = _p.player_id
	var manned: bool = await _until(func() -> bool: return sl.operator_id != 0 and sl.operator_id != me, 150.0)
	_check(manned, "a bot mans the searchlight on the mark order (operator %d)" % sl.operator_id)


func _finish() -> void:
	if _done:
		return
	_done = true
	print("[bots_u10] RESULT: %s" % ["PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)]])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit(0 if _fails.is_empty() else 1)
