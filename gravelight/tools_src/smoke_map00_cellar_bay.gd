extends Node
## Smoke: Map 0's cellar past the Helvetia vault and the perk machines' per-match deal.
## T-179: the late-delivery bay (gen_map00 BAY_*): zone CELLAR, one piece of navmesh with the vault, its bulb lit by
## the lever's sweep.
## T-251 (UPDATE 19): the Lagering Vault and the Dynamo Room behind Door_Lager (750) and Door_Dynamo (1000); the cellar
## lever and the Crucible in the Dynamo Room, three doors from the taproom; the twelve tonic machines dealt onto the
## map's perk spots from a seed (PerkLayout): pinned here (251), the same seed deals the same, another seed another,
## every machine stands on a spot in that spot's zone with a navmesh path to its front, the spots left over show
## their crate, the map's POIs follow, and nothing sells before the real Kellerschalter is thrown. The player buys
## the three doors, walks through the two new ones, throws the lever (its sweep lights both rooms, the vault and the
## bay), then buys two tonics at dealt machines by looking at them and holding interact, and the Crucible answers.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_map00_cellar_bay.tscn

const CY: float = -3.2
const SEED: int = 251

var _map: Node3D
var _p: Player
var _fails: PackedStringArray = []


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile_bay.json"
	ProfileSave.profile = ProfileSave.new_profile()
	PerkLayout.forced_seed = SEED
	_map = (load("res://gravelight/maps/map00_crossroads/map00.tscn") as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _check(cond: bool, what: String) -> void:
	print("[cellar] %-70s %s" % [what, "ok" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _face(target: Vector3) -> void:
	var d: Vector3 = target - _p.global_position
	_p.rotation.y = atan2(-d.x, -d.z)
	_p.set("_pitch", atan2(target.y - (_p.global_position.y + 1.62), Vector2(d.x, d.z).length()))
	await _frames(3)


func _door(id: StringName) -> BuyDoor:
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		if n is BuyDoor and (n as BuyDoor).door_id == id:
			return n as BuyDoor
	return null


## A navmesh path from a to b on the live map: [ok, length, end]. ok = it ends within 0.6 m of b (flat) and 0.8 m in y
## (the baked surface floats up to half a metre over the flagstones).
func _path(a: Vector3, b: Vector3) -> Array:
	var m: RID = _p.get_world_3d().navigation_map
	var pts: PackedVector3Array = NavigationServer3D.map_get_path(m, a, b, true)
	if pts.is_empty():
		return [false, 0.0, Vector3.ZERO, pts]
	var last: Vector3 = pts[pts.size() - 1]
	var length: float = 0.0
	for i: int in range(1, pts.size()):
		length += pts[i - 1].distance_to(pts[i])
	return [Vector2(last.x - b.x, last.z - b.z).length() < 0.6 and absf(last.y - b.y) < 0.8, length, last, pts]


func _where() -> Dictionary:
	var out: Dictionary = {}
	for n: Node in get_tree().get_nodes_in_group(&"perk_machines"):
		out[String((n as PerkMachine).perk_id)] = (n as Node3D).global_position
	return out


## Stand in front of `it`, look at it, hold interact until `done` says so. Returns true when it did.
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

	# ---- the deal: pinned to SEED, every machine on a spot in the spot's zone, the rest of the spots show a crate
	var pl: PerkLayout = PerkLayout.current(tree)
	_check(pl != null and pl.seed_value == SEED, "the map dealt its machines from the pinned seed (%s)" % (str(pl.seed_value) if pl != null else "no layout"))
	if pl == null:
		_finish()
		return
	print("[cellar] deal %d: %s" % [pl.seed_value, pl.describe()])
	var spots: Array[Node] = tree.get_nodes_in_group(&"perk_spots")
	var machines: Array[Node] = tree.get_nodes_in_group(&"perk_machines")
	_check(spots.size() >= 14 and machines.size() == 12, "%d perk spots, %d machines" % [spots.size(), machines.size()])
	_check(pl.deal.size() == 12 and PerkShuffle.valid(pl.deal, pl.spot_rows(), pl.perk_rows(), PerkLayout.rules()), "the deal keeps perk_layout.json's rules")
	var on_spot: int = 0
	var zone_ok: int = 0
	var zones_used: Dictionary = {}
	for n: Node in machines:
		var pm: PerkMachine = n as PerkMachine
		var sp: PerkSpot = _map.get_node_or_null("Gameplay/PerkSpot_" + pl.spot_of(pm.perk_id)) as PerkSpot
		if sp != null and pm.global_position.distance_to(sp.stand_transform(pm.depth()).origin) < 0.01 and absf(angle_difference(pm.global_rotation.y, sp.global_rotation.y)) < 0.01 and sp.machine == pm:
			on_spot += 1
		if sp != null and ZoneVolume.zone_at(tree, BotBrain._front_of(pm) + Vector3.UP * 0.5) == sp.zone_id:
			zone_ok += 1
			zones_used[String(sp.zone_id)] = true
	_check(on_spot == 12, "every machine stands on the spot it was dealt (%d / 12)" % on_spot)
	_check(zone_ok == 12, "the floor in front of each is its spot's zone (%d / 12)" % zone_ok)
	_check(zones_used.size() >= 6, "the machines are spread over %d zones (%s)" % [zones_used.size(), ", ".join(PackedStringArray(zones_used.keys()))])
	var free_n: int = 0
	var crates_ok: int = 0
	for s: Node in spots:
		var ps: PerkSpot = s as PerkSpot
		if not ps.is_free():
			var f0: Node3D = ps.get_node_or_null("Filler") as Node3D
			if f0 != null and f0.visible:
				_check(false, "%s shows a crate under its machine" % ps.name)
			continue
		free_n += 1
		var filler: Node3D = ps.get_node_or_null("Filler") as Node3D
		var body: StaticBody3D = ps.get_node_or_null("FillerBody") as StaticBody3D
		if filler != null and filler.visible and body != null and body.collision_layer == 1:
			crates_ok += 1
	_check(free_n == spots.size() - 12 and crates_ok == free_n, "the %d spots left over show a solid crate (%d)" % [free_n, crates_ok])
	var blocks_off: int = 0
	var blocks: Array = _map.find_children("NavBlock_PerkSpot_*", "StaticBody3D", true, false)
	for b: Node in blocks:
		if (b as StaticBody3D).collision_layer == 0:
			blocks_off += 1
	_check(blocks.size() == spots.size() and blocks_off == blocks.size(), "the spots' bake boxes stop nobody at runtime (%d / %d off)" % [blocks_off, blocks.size()])

	# ---- the same seed deals the same, another seed another; the map's POIs follow the machines
	var at_seed: Dictionary = _where()
	pl.apply(SEED + 1)
	await _frames(2)
	var other: Dictionary = _where()
	var moved: int = 0
	for k: String in at_seed.keys():
		if (at_seed[k] as Vector3).distance_to(other[k] as Vector3) > 0.5:
			moved += 1
	_check(moved >= 6, "seed %d is another layout (%d of 12 machines stand elsewhere)" % [SEED + 1, moved])
	var ms: MapState = MapState.current()
	var poi_ok: int = 0
	if ms != null:
		for poi: Dictionary in ms.data.pois_of_type("perk"):
			var pid: String = str((poi.get("data", {}) as Dictionary).get("perk_id", ""))
			if other.has(pid) and (poi["pos"] as Vector3).distance_to(other[pid] as Vector3) < 0.05 and int(poi["floor"]) == ms.data.floor_at((other[pid] as Vector3) + Vector3.UP * 0.3):
				poi_ok += 1
	_check(ms != null and poi_ok == 12, "the map's perk POIs stand where the machines do, on their floors (%d / 12)" % poi_ok)
	pl.apply(SEED)
	await _frames(2)
	var again: Dictionary = _where()
	var same: int = 0
	for k2: String in at_seed.keys():
		if (at_seed[k2] as Vector3).distance_to(again[k2] as Vector3) < 0.001:
			same += 1
	_check(same == 12, "seed %d again is the same layout (%d / 12)" % [SEED, same])
	_check(MapData.for_map(&"map00_crossroads") != ms.data if ms != null else false, "the baked map data keeps its own rows (the match reads a copy)")

	# ---- the navmesh reaches every spot's front from the taproom (paths run through shut doors)
	var start: Vector3 = Vector3(14.5, 0.0, 13.4)
	var reach: int = 0
	for s2: Node in spots:
		var ps2: PerkSpot = s2 as PerkSpot
		var front: Vector3 = ps2.global_position + ps2.global_basis * Vector3(0, 0, -1.4)
		var r: Array = _path(start, front)
		if bool(r[0]):
			reach += 1
		else:
			_check(false, "navmesh: the taproom -> %s's front" % ps2.name)
	_check(reach == spots.size(), "the navmesh reaches the front of every perk spot (%d / %d)" % [reach, spots.size()])

	# ---- three doors deep: the way from the taproom to the lever crosses Door_Cellar, Door_Lager, Door_Dynamo
	var sw: PowerSwitch = _map.get_node_or_null("Gameplay/Kellerschalter") as PowerSwitch
	var cru: Crucible = _map.get_node_or_null("Gameplay/Crucible") as Crucible
	_check(sw != null and cru != null, "the cellar lever and the Crucible are on the map")
	if sw == null or cru == null:
		_finish()
		return
	_check(ZoneVolume.zone_at(tree, sw.global_position) == &"MASCHINENRAUM" and ZoneVolume.zone_at(tree, cru.global_position + Vector3.UP * 0.3) == &"MASCHINENRAUM",
		"both stand in the Dynamo Room")
	var way: Array = _path(start, BotBrain._front_of(sw))
	var crossed: PackedStringArray = []
	if bool(way[0]):
		for id: StringName in [&"door_cellar", &"door_lager", &"door_dynamo", &"door_old_cellar", &"door_stable", &"door_upstairs", &"door_yard", &"door_front", &"door_gate"]:
			var d: BuyDoor = _door(id)
			if d != null and ZombieDirector.door_crossed(d, way[3] as PackedVector3Array):
				crossed.append(String(id))
	_check(bool(way[0]) and crossed == PackedStringArray(["door_cellar", "door_lager", "door_dynamo"]), "the way to the lever crosses the three doors and no other (%s; %.0f m)" % [", ".join(crossed), float(way[1])])
	_check(not GameState.is_zone_open(&"LAGERKELLER") and not GameState.is_zone_open(&"MASCHINENRAUM"), "both new rooms start shut")
	for sid: String in ["Spawn_LagerDrain", "Spawn_DynamoSump"]:
		var zs: ZombieSpawn = _map.get_node_or_null("Gameplay/" + sid) as ZombieSpawn
		_check(zs != null and not zs.is_active(9), "%s feeds nothing while its room is shut" % sid)

	# ---- before the lever: nothing sells
	var refuse: int = 0
	for n2: Node in machines:
		var pm2: PerkMachine = n2 as PerkMachine
		if not pm2.is_powered() and not pm2.can_interact(_p) and pm2.get_prompt(_p).begins_with("Power must be activated"):
			refuse += 1
		elif not PerkManager.needs_power(pm2.perk_id):
			refuse += 1   # (Second Wind pours without the power solo)
	_check(refuse == 12, "every machine waits for the cellar lever (%d / 12)" % refuse)
	_check(not cru.is_powered(), "the Crucible waits for it too")

	# ---- buy the three doors (each from the side you reach it), walk through the two new ones
	var paid: int = Economy.get_scrip(1)
	for row: Array in [[&"door_cellar", Vector3(22.7, 0.0, 11.5), 1500], [&"door_lager", Vector3(26.0, CY, 29.7), 750]]:
		var d2: BuyDoor = _door(row[0])
		_p.global_position = row[1]
		await _face(d2.global_position + Vector3.UP * 1.2)
		await _frames(4)
		var prompt: String = _p.prompt_text
		_check(_p.interact_target == d2 and prompt.contains(str(int(row[2])).substr(0, 1)), "%s: the player's prompt (%s)" % [row[0], prompt.get_slice("\n", 0)])
		d2.interact(_p)
		await _frames(3)
		_check(d2.is_open and d2.cost == int(row[2]), "%s opened for %d Scrip" % [row[0], int(row[2])])
	_check(GameState.is_zone_open(&"CELLAR") and GameState.is_zone_open(&"LAGERKELLER") and not GameState.is_zone_open(&"MASCHINENRAUM"), "the Lagering Vault is open, the Dynamo Room not yet")
	_p.global_position = Vector3(26.0, CY, 29.4)
	await _face(Vector3(26.0, CY + 1.6, 34.0))
	_p.set("_pitch", 0.0)
	Input.action_press(&"move_forward")
	await _secs(1.6)
	Input.action_release(&"move_forward")
	await _frames(4)
	_check(_p.global_position.z > 31.6 and absf(_p.global_position.y - CY) < 0.3 and ZoneVolume.zone_at(tree, _p.global_position) == &"LAGERKELLER",
		"walked through Door_Lager into the Lagering Vault (z %.1f)" % _p.global_position.z)
	var d3: BuyDoor = _door(&"door_dynamo")
	_p.global_position = Vector3(32.7, CY, 35.4)
	await _face(d3.global_position + Vector3.UP * 1.2)
	await _frames(4)
	_check(_p.interact_target == d3, "door_dynamo: the player's prompt (%s)" % _p.prompt_text.get_slice("\n", 0))
	# the shut door stops a walk
	_p.set("_pitch", 0.0)
	Input.action_press(&"move_forward")
	await _secs(1.2)
	Input.action_release(&"move_forward")
	await _frames(3)
	_check(_p.global_position.x < 34.0, "the shut Door_Dynamo stops you (x %.1f)" % _p.global_position.x)
	d3.interact(_p)
	await _frames(3)
	_check(d3.is_open and GameState.is_zone_open(&"MASCHINENRAUM"), "door_dynamo opened for 1000 Scrip")
	_check(paid - Economy.get_scrip(1) == 3250, "the three doors cost 3250 Scrip together (paid %d)" % (paid - Economy.get_scrip(1)))
	_p.global_position = Vector3(32.7, CY, 35.4)
	await _face(Vector3(38.0, CY + 1.6, 35.4))
	_p.set("_pitch", 0.0)
	Input.action_press(&"move_forward")
	await _secs(1.6)
	Input.action_release(&"move_forward")
	await _frames(4)
	_check(_p.global_position.x > 34.6 and ZoneVolume.zone_at(tree, _p.global_position) == &"MASCHINENRAUM", "walked through Door_Dynamo into the Dynamo Room (x %.1f)" % _p.global_position.x)
	for sid2: String in ["Spawn_LagerDrain", "Spawn_DynamoSump"]:
		var zs2: ZombieSpawn = _map.get_node_or_null("Gameplay/" + sid2) as ZombieSpawn
		_check(zs2 != null and zs2.is_active(4) and not zs2.is_active(3), "%s feeds its room from round 4" % sid2)
	# the navmesh joins the rooms, the vault and the bay
	for row2: Array in [["the stair foot", Vector3(26.0, CY, 20.6), "the lever", BotBrain._front_of(sw)], ["the bay", Vector3(38.2, CY, 25.95), "the Crucible", BotBrain._front_of(cru)],
			["the dynamo sump", Vector3(35.2, CY, 37.9), "the breach", Vector3(24.9, CY, 20.3)], ["the tuns' south side", Vector3(30.0, CY, 35.8), "the coal chute", Vector3(34.2, CY, 29.4)]]:
		var r2: Array = _path(row2[1], row2[3])
		_check(bool(r2[0]) and float(r2[1]) < 70.0, "navmesh: %s -> %s (%.1f m)" % [row2[0], row2[2], float(r2[1])])

	# ---- the real lever: looked at, held, thrown; its sweep lights both rooms, the vault and the bay
	var thrown: bool = await _use(sw, 1.2, func() -> bool: return GameState.power_on)
	_check(thrown, "the lever is thrown by looking at it and holding interact")
	await _secs(6.5)
	var lit: Dictionary = {}
	var bay_lit: bool = false
	for n3: Node in tree.get_nodes_in_group(&"power_lights"):
		var l: OmniLight3D = n3 as OmniLight3D
		if l == null or not l.visible or l.light_energy < 0.5:
			continue
		lit[str(l.get_meta("zone", ""))] = int(lit.get(str(l.get_meta("zone", "")), 0)) + 1
		if l.global_position.x > 36.2 and l.global_position.z < 29.6 and l.global_position.y < -0.2:
			bay_lit = true
	_check(int(lit.get("MASCHINENRAUM", 0)) >= 2 and int(lit.get("LAGERKELLER", 0)) >= 2, "the sweep lit the Dynamo Room and the Lagering Vault (%s)" % str(lit))
	_check(int(lit.get("CELLAR", 0)) >= 5 and bay_lit and int(lit.get("OLD_CELLAR", 0)) >= 1, "and the vault, the bay and the Old Cellar")
	var powered: int = 0
	for n4: Node in machines:
		if (n4 as PerkMachine).is_powered():
			powered += 1
	_check(powered == 12 and cru.is_powered(), "every machine and the Crucible are powered (%d / 12)" % powered)

	# ---- drink at two dealt machines: the one deepest in the cellar and one above ground
	var picks: Array[PerkMachine] = []
	for want: Array in [["MASCHINENRAUM", "LAGERKELLER", "CELLAR", "OLD_CELLAR"], ["YARD", "GROUNDS", "STABLE", "UPSTAIRS", "TAPROOM"]]:
		for z: String in want:
			var hit: PerkMachine = null
			for n5: Node in machines:
				var pm5: PerkMachine = n5 as PerkMachine
				var sp5: PerkSpot = _map.get_node_or_null("Gameplay/PerkSpot_" + pl.spot_of(pm5.perk_id)) as PerkSpot
				if sp5 != null and String(sp5.zone_id) == z and not picks.has(pm5):
					hit = pm5
					break
			if hit != null:
				picks.append(hit)
				break
	_check(picks.size() == 2, "a machine below ground and one above to drink at")
	for pm6: PerkMachine in picks:
		var id6: StringName = pm6.perk_id
		var price: int = PerkManager.price(id6)
		var s0: int = Economy.get_scrip(1)
		var front6: Vector3 = BotBrain._front_of(pm6)
		_p.global_position = pm6.global_position + (front6 - pm6.global_position).normalized() * 1.25
		await _face(pm6.global_position + Vector3.UP * 1.2)
		await _frames(4)
		var prompt6: String = _p.prompt_text
		_check(_p.interact_target == pm6 and prompt6.contains(PerkManager.display_name(id6)) and prompt6.contains(str(price)),
			"%s on %s: the player's prompt (%s)" % [id6, pl.spot_of(id6), prompt6.get_slice("\n", 0)])
		var got: bool = await _use(pm6, 1.2, func() -> bool: return PerkManager.has_perk(1, id6))
		_check(got and Economy.get_scrip(1) == s0 - price, "%s bought for %d Scrip where the deal stood it (paid %d)" % [id6, price, s0 - Economy.get_scrip(1)])

	# ---- the Crucible answers where it stands now
	_p.global_position = cru.global_position + Vector3(0, 0, 1.9)
	await _face(cru.global_position + Vector3.UP * 1.1)
	await _frames(4)
	_check(_p.interact_target == cru and _p.prompt_text != "", "the Crucible's prompt in the Dynamo Room (%s)" % _p.prompt_text.get_slice("\n", 0))
	_finish()


func _finish() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	print("[cellar] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)]))
	get_tree().quit(0 if _fails.is_empty() else 1)
