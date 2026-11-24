extends Node
## T-272: the perk deal on Kaltenbrunn (gen_map01 PERK_SPOTS / PERK_DEALT, perk_layout.json "map01"; PerkLayout,
## PerkShuffle, PerkSpot), headless, solo, silent. The map deals its eight dealt machines from a pinned seed onto its
## fourteen spots: every one on the spot it was dealt, in that spot's zone; the six spots left over show a solid crate;
## the bake boxes stop nobody; the three machines that belong where they stand (Ledger Lager, Overclock Cordial,
## Skyhook Sekt) did not move; another seed is another layout and the map's POIs follow the machines; nothing stands in
## front of a dealt machine (the navmesh reaches its front from the Minehead yard with every door open); with the power
## on the player buys two tonics at dealt machines (one above ground, one below) by looking at them and holding interact.
## Prints "[m1perks] ..." and "[m1perks] RESULT: PASS/FAIL"; exit code 0/1.
##   godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_map01_perks.tscn

const SEED: int = 272
const FIXED: Dictionary = {"ledger_lager": Vector3(-15.2, 0, 11.0), "overclock_cordial": Vector3(60.25, -12.0, 60.45), "skyhook_sekt": Vector3(34.5, -18.0, 101.6)}

var _map: Node3D
var _p: Player
var _fails: PackedStringArray = []
var _checks: int = 0


func _ready() -> void:
	ProfileSave.path = "user://_qa_m1perks_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_m1perks_settings.cfg"
	GameState.bot_count = 0
	Campaign.reset()
	PerkLayout.forced_seed = SEED
	_map = (load("res://gravelight/maps/map01_kaltenbrunn/map01.tscn") as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _check(cond: bool, what: String) -> void:
	_checks += 1
	print("[m1perks] %-96s %s" % [what, "PASS" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _face(target: Vector3) -> void:
	var d: Vector3 = target - _p.global_position
	_p.rotation.y = atan2(-d.x, -d.z)
	_p.set("_pitch", atan2(target.y - (_p.global_position.y + 1.62), Vector2(d.x, d.z).length()))
	await _frames(3)


func _where() -> Dictionary:
	var out: Dictionary = {}
	for n: Node in get_tree().get_nodes_in_group(&"perk_machines"):
		out[String((n as PerkMachine).perk_id)] = (n as Node3D).global_position
	return out


func _use(it: Interactable, look_y: float, done: Callable) -> bool:
	var front: Vector3 = BotBrain._front_of(it)
	_p.global_position = it.global_position + (front - it.global_position).normalized() * 1.25
	_p.velocity = Vector3.ZERO
	await _face(it.global_position + Vector3.UP * look_y)
	await _frames(4)
	if _p.interact_target != it:
		return false
	Input.action_press(&"interact")
	var got: bool = false
	for _w: int in 30:
		await _secs(0.2)
		if bool(done.call()):
			got = true
			break
	Input.action_release(&"interact")
	await _secs(0.3)
	return got


func _run() -> void:
	await _frames(12)
	_p = _map.get_node("Player1") as Player
	RoundManager.stop()
	GameState.god_mode = true
	Economy.grant(1, 30000)
	var tree: SceneTree = get_tree()
	var pl: PerkLayout = PerkLayout.current(tree)
	_check(pl != null and pl.seed_value == SEED, "the map dealt its machines from the pinned seed (%s)" % (str(pl.seed_value) if pl != null else "no layout"))
	if pl == null:
		_finish()
		return
	print("[m1perks] deal %d: %s" % [pl.seed_value, pl.describe()])
	var spots: Array[Node] = tree.get_nodes_in_group(&"perk_spots")
	var machines: Array[Node] = tree.get_nodes_in_group(&"perk_machines")
	_check(spots.size() == 14 and machines.size() == 11 and pl.deal.size() == 8, "14 perk spots, 11 machines, 8 of them dealt (%d, %d, %d)" % [spots.size(), machines.size(), pl.deal.size()])
	_check(PerkShuffle.valid(pl.deal, pl.spot_rows(), pl.perk_rows(), PerkLayout.rules()), "the deal keeps perk_layout.json's rules")
	var on_spot: int = 0
	var zone_ok: int = 0
	for pid: String in pl.deal.keys():
		var pm: PerkMachine = null
		for n: Node in machines:
			if String((n as PerkMachine).perk_id) == pid:
				pm = n as PerkMachine
		var sp: PerkSpot = _map.get_node_or_null("Gameplay/PerkSpot_" + pl.spot_of(StringName(pid))) as PerkSpot
		if pm != null and sp != null and pm.global_position.distance_to(sp.stand_transform(pm.depth()).origin) < 0.01 and sp.machine == pm:
			on_spot += 1
		if pm != null and sp != null and ZoneVolume.zone_at(tree, BotBrain._front_of(pm) + Vector3.UP * 0.5) == sp.zone_id:
			zone_ok += 1
	_check(on_spot == 8 and zone_ok == 8, "every dealt machine stands on its spot, its front in the spot's zone (%d, %d of 8)" % [on_spot, zone_ok])
	var fixed_ok: int = 0
	for fid: String in FIXED.keys():
		for n2: Node in machines:
			if String((n2 as PerkMachine).perk_id) == fid and (n2 as Node3D).global_position.distance_to(FIXED[fid]) < 0.01:
				fixed_ok += 1
	_check(fixed_ok == 3 and not pl.deal.has("ledger_lager") and not pl.deal.has("overclock_cordial") and not pl.deal.has("skyhook_sekt"), "Ledger Lager, Overclock Cordial and Skyhook Sekt stand where they belong (%d of 3)" % fixed_ok)
	var free_n: int = 0
	var crates_ok: int = 0
	for s: Node in spots:
		var ps: PerkSpot = s as PerkSpot
		if not ps.is_free():
			continue
		free_n += 1
		var filler: Node3D = ps.get_node_or_null("Filler") as Node3D
		var body: StaticBody3D = ps.get_node_or_null("FillerBody") as StaticBody3D
		if filler != null and filler.visible and body != null and body.collision_layer == 1:
			crates_ok += 1
	_check(free_n == 6 and crates_ok == 6, "the 6 spots left over show a solid crate (%d of %d)" % [crates_ok, free_n])
	var blocks: Array = _map.find_children("NavBlock_PerkSpot_*", "StaticBody3D", true, false)
	var off: int = 0
	for b: Node in blocks:
		if (b as StaticBody3D).collision_layer == 0:
			off += 1
	_check(blocks.size() == 14 and off == 14, "the spots' bake boxes stop nobody at runtime (%d of %d off)" % [off, blocks.size()])
	# the navmesh reaches every spot's front from the yard, every door open
	for n3: Node in tree.get_nodes_in_group(&"doors"):
		if n3 is BuyDoor and not (n3 as BuyDoor).is_open:
			(n3 as BuyDoor).open(1)
	await _secs(3.5)
	var nav: RID = _map.get_world_3d().navigation_map
	var reach: int = 0
	var far_ones: PackedStringArray = []
	for s2: Node in spots:
		var ps2: PerkSpot = s2 as PerkSpot
		var front: Vector3 = ps2.global_transform * Vector3(0, 0, -1.3)
		var path: PackedVector3Array = NavigationServer3D.map_get_path(nav, Vector3(10.0, 0.0, 22.0), front, true, 0xFFFF)
		if not path.is_empty() and path[path.size() - 1].distance_to(front) < 0.7:
			reach += 1
		else:
			far_ones.append(String(ps2.spot_id))
	_check(reach == 14, "the navmesh reaches every spot's front from the yard (%d of 14%s)" % [reach, "" if far_ones.is_empty() else "; not: " + ", ".join(far_ones)])
	# another seed, another layout; the POIs follow
	var at_seed: Dictionary = _where()
	pl.apply(SEED + 1)
	await _frames(2)
	var other: Dictionary = _where()
	var moved: int = 0
	for k: String in at_seed.keys():
		if (at_seed[k] as Vector3).distance_to(other[k] as Vector3) > 0.5:
			moved += 1
	_check(moved >= 3 and moved <= 8, "seed %d is another layout (%d of the 8 dealt stand elsewhere)" % [SEED + 1, moved])
	var ms: MapState = MapState.current()
	var poi_ok: int = 0
	if ms != null:
		for poi: Dictionary in ms.data.pois_of_type("perk"):
			var pid2: String = str((poi.get("data", {}) as Dictionary).get("perk_id", ""))
			if other.has(pid2) and (poi["pos"] as Vector3).distance_to(other[pid2] as Vector3) < 0.05:
				poi_ok += 1
	_check(ms != null and poi_ok == 11, "the map's perk POIs stand where the machines do (%d of 11)" % poi_ok)
	# with the power on: drink at a dealt machine above ground and at one below
	GameState.power_on = true
	GameState.set_flag(&"power_on", true)
	GLBus.power_activated.emit()
	await _secs(1.0)
	var picks: Array[PerkMachine] = []
	for want: Array in [["C_ADMIN", "D_BARRACKS", "B_RAILYARD", "E_LIFT"], ["F_CHAPEL", "G_GENERATOR", "H_LAB", "M_STAIRS"]]:
		for n5: Node in machines:
			var pm5: PerkMachine = n5 as PerkMachine
			if not pl.deal.has(String(pm5.perk_id)):
				continue
			var sp5: PerkSpot = _map.get_node_or_null("Gameplay/PerkSpot_" + pl.spot_of(pm5.perk_id)) as PerkSpot
			if sp5 != null and want.has(String(sp5.zone_id)) and pm5.perk_id != &"second_wind":
				picks.append(pm5)
				break
	_check(picks.size() == 2, "a dealt machine above ground and one below to drink at")
	for pm6: PerkMachine in picks:
		var id6: StringName = pm6.perk_id
		var price: int = PerkManager.price(id6)
		var s0: int = Economy.get_scrip(1)
		var got: bool = await _use(pm6, 1.2, func() -> bool: return PerkManager.has_perk(1, id6))
		_check(got and Economy.get_scrip(1) == s0 - price, "%s bought for %d Scrip on %s (paid %d)" % [id6, price, pl.spot_of(id6), s0 - Economy.get_scrip(1)])
	_finish()


func _finish() -> void:
	print("[m1perks] RESULT: %s (%d checks%s)" % ["PASS" if _fails.is_empty() else "FAIL", _checks, "" if _fails.is_empty() else "; %d failed: %s" % [_fails.size(), "; ".join(_fails)]])
	get_tree().quit(0 if _fails.is_empty() else 1)
