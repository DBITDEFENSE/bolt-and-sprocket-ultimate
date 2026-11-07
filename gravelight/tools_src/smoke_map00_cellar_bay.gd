extends Node
## T-179 smoke: the Helvetia cellar's late-delivery bay on Map 0 (gen_map00 BAY_*). Skyhook Sekt and Magpie Mead stand
## in it, in zone CELLAR; they refuse before the cellar lever and sell after it (thrown through the real
## Kellerschalter, whose sweep lights the bay's bulb); the player walks through the arch, gets each machine's prompt by
## looking at it and buys both by holding interact; the navmesh reaches both fronts from the stair foot, the coal chute
## and the Old Cellar's breach side, and the bay's floor is one piece with the vault's.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_map00_cellar_bay.tscn

const BAY_PERKS: Array[StringName] = [&"skyhook_sekt", &"magpie_mead"]
const CY: float = -3.2

var _map: Node3D
var _p: Player
var _fails: PackedStringArray = []


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile_bay.json"
	ProfileSave.profile = ProfileSave.new_profile()
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
	print("[bay] %-66s %s" % [what, "ok" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _face(target: Vector3) -> void:
	var d: Vector3 = target - _p.global_position
	_p.rotation.y = atan2(-d.x, -d.z)
	_p.set("_pitch", atan2(target.y - (_p.global_position.y + 1.62), Vector2(d.x, d.z).length()))
	await _frames(3)


func _machine(id: StringName) -> PerkMachine:
	return _map.get_node_or_null(NodePath("Gameplay/Perk_" + String(id))) as PerkMachine


## A navmesh path from a to b on the live map: [ok, length, end]. ok = it ends within 0.6 m of b (flat) and 0.8 m in y
## (the baked surface floats up to half a metre over the flagstones).
func _path(a: Vector3, b: Vector3) -> Array:
	var m: RID = _p.get_world_3d().navigation_map
	var pts: PackedVector3Array = NavigationServer3D.map_get_path(m, a, b, true)
	if pts.is_empty():
		return [false, 0.0]
	var last: Vector3 = pts[pts.size() - 1]
	var length: float = 0.0
	for i: int in range(1, pts.size()):
		length += pts[i - 1].distance_to(pts[i])
	return [Vector2(last.x - b.x, last.z - b.z).length() < 0.6 and absf(last.y - b.y) < 0.8, length, last]


func _run() -> void:
	await _frames(12)
	_p = _map.get_node("Player1") as Player
	RoundManager.stop()
	GameState.god_mode = true
	GameState.open_zone(&"CELLAR")
	Economy.grant(1, 20000)

	# ---- both machines exist, in the bay, in zone CELLAR, needing the power like the others
	for id: StringName in BAY_PERKS:
		var pm: PerkMachine = _machine(id)
		_check(pm != null, "%s machine on Map 0" % id)
		if pm == null:
			continue
		var gp: Vector3 = pm.global_position
		_check(gp.x > 36.2 and gp.x < 42.0 and gp.z > 22.7 and gp.z < 29.5 and absf(gp.y - CY) < 0.05, "%s stands in the late-delivery bay (%.1f, %.1f, %.1f)" % [id, gp.x, gp.y, gp.z])
		_check(ZoneVolume.zone_at(get_tree(), BotBrain._front_of(pm) + Vector3.UP * 0.5) == &"CELLAR", "%s: the floor in front of it is zone CELLAR" % id)
		_check(PerkManager.needs_power(id) and not pm.is_powered(), "%s waits for the cellar lever" % id)
		_check(not pm.can_interact(_p) and pm.get_prompt(_p).begins_with("Power must be activated"), "%s refuses before the lever (%s)" % [id, pm.get_prompt(_p).get_slice("\n", 0)])

	# ---- the navmesh: both fronts from the stair foot, the coal chute and the breach side of the vault
	var starts: Dictionary = {"the stair foot": Vector3(26.0, CY, 20.6), "the coal chute": Vector3(34.6, CY, 29.0),
		"the breach": Vector3(24.9, CY, 20.3), "the vault's middle": Vector3(30.0, CY, 25.0)}
	for id2: StringName in BAY_PERKS:
		var pm2: PerkMachine = _machine(id2)
		if pm2 == null:
			continue
		var front: Vector3 = BotBrain._front_of(pm2)
		for sk: String in starts.keys():
			var r: Array = _path(starts[sk], front)
			var dy: float = ((r[2] as Vector3).y - front.y) if r.size() > 2 else 99.0
			_check(bool(r[0]) and float(r[1]) < 30.0, "navmesh: %s -> %s's front (%.1f m, ends %.2f m up)" % [sk, id2, float(r[1]), dy])
	var bay_mid: Vector3 = Vector3(38.2, CY, 25.95)
	var closest: Vector3 = NavigationServer3D.map_get_closest_point(_p.get_world_3d().navigation_map, bay_mid)
	var off: float = Vector2(closest.x - bay_mid.x, closest.z - bay_mid.z).length()
	_check(off < 0.3 and absf(closest.y - bay_mid.y) < 0.8, "navmesh covers the bay's floor (%.2f m off, %.2f m up: the bake's surface)" % [off, closest.y - bay_mid.y])

	# ---- walk through the arch from the vault into the bay
	_p.global_position = Vector3(32.4, CY, 25.95)
	await _face(Vector3(40.0, CY + 1.6, 25.95))
	_p.set("_pitch", 0.0)
	Input.action_press(&"move_forward")
	await _secs(2.2)
	Input.action_release(&"move_forward")
	await _frames(4)
	_check(_p.global_position.x > 37.0 and absf(_p.global_position.y - CY) < 0.3, "walked through the arch into the bay (x %.1f)" % _p.global_position.x)

	# ---- the real lever: thrown, its sweep lights the bay's bulb, the machines wake
	var sw: Node = _map.get_node_or_null("Gameplay/Kellerschalter")
	_check(sw != null, "the cellar lever exists")
	if sw != null:
		sw.call("interact", _p)
	await _secs(6.0)
	var bay_bulb: OmniLight3D = null
	for n: Node in get_tree().get_nodes_in_group(&"power_lights"):
		var l: OmniLight3D = n as OmniLight3D
		if l != null and l.global_position.x > 36.2 and l.global_position.y < -0.2:
			bay_bulb = l
	_check(bay_bulb != null and bay_bulb.visible and bay_bulb.light_energy > 0.5, "the lever's sweep lit the bay's bulb")
	for id3: StringName in BAY_PERKS:
		var pm3: PerkMachine = _machine(id3)
		if pm3 != null:
			_check(pm3.is_powered(), "%s powered by the cellar lever" % id3)

	# ---- look at each machine, read its prompt, hold interact to drink; the price is unchanged
	for id4: StringName in BAY_PERKS:
		var pm4: PerkMachine = _machine(id4)
		if pm4 == null:
			continue
		var front2: Vector3 = BotBrain._front_of(pm4)
		_p.global_position = pm4.global_position + (front2 - pm4.global_position).normalized() * 1.25
		await _face(pm4.global_position + Vector3.UP * 1.2)
		await _frames(4)
		var price: int = PerkManager.price(id4)
		var prompt: String = _p.prompt_text
		_check(_p.interact_target == pm4 and prompt.contains(PerkManager.display_name(id4)) and prompt.contains(str(price)), "%s: the player's prompt (%s)" % [id4, prompt.get_slice("\n", 0)])
		var s0: int = Economy.get_scrip(1)
		Input.action_press(&"interact")
		var got: bool = false
		for _w: int in 30:
			await _secs(0.2)
			if PerkManager.has_perk(1, id4):
				got = true
				break
		Input.action_release(&"interact")
		await _secs(0.3)
		_check(got and Economy.get_scrip(1) == s0 - price, "%s bought for %d Scrip (paid %d)" % [id4, price, s0 - Economy.get_scrip(1)])
	# Skyhook's hop and Magpie's drop chance are live on this map
	_check(int(PerkManager.stat(1, "air_hops", 0)) == 1 and bool(PerkManager.stat(1, "safe_landing", false)), "Skyhook Sekt: the mid-air hop and soft landings")
	_check(float(PerkManager.stat(1, "magpie_chance", 0.0)) > 0.0, "Magpie Mead: kills may drop salvage")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	print("[bay] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)]))
	get_tree().quit(0 if _fails.is_empty() else 1)
