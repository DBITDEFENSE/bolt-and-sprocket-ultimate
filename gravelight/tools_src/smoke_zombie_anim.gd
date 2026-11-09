extends Node
## Headless smoke for the MZ zombie animation upgrade (T-041) on Map 2: the authored climb links exist and sit on
## the navmesh, a horde of every tier walks without foot-sliding (root-motion speed vs nav speed within 5%),
## (the clip's stride distance against the body's travel over the same half-second windows), foot IK and head
## look-at run within range and switch off beyond it, a climb link is traversed, limbs come off
## (and stay on with Gore off), an explosive knocks a zombie down and it gets up, deaths pick authored clips and
## hand over to a capped ragdoll, corpses dissolve back into the pool.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_zombie_anim.tscn

const MAP: String = "res://gravelight/maps/map02_totenhafen/map02.tscn"
const PLAYER_POS: Vector3 = Vector3(17.5, 0.1, 58.0)
const SPAWN_LINE: Array = [Vector3(12, 0, 38), Vector3(14, 0, 38), Vector3(16, 0, 38), Vector3(18, 0, 38), Vector3(20, 0, 38), Vector3(22, 0, 38)]
const TIERS: Array = [&"shamble", &"walk", &"jog", &"run", &"sprint"]

var _map: Node3D
var _p: Player
var _dir: ZombieDirector
var _t: float = 0.0
var _phase: int = -1
var _fails: PackedStringArray = []
var _samples: Dictionary = {}     # zombie -> Array[float] ratio anim/nav speed
var _done: bool = false
var _climber: Zombie
var _climb_to: Vector3
var _victims: Array[Zombie] = []
var _death_clips: Dictionary = {}
var _ragdoll_peak: int = 0
var _kd: Zombie
var _kd_seen: Dictionary = {}


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.values["gore"] = "full"
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GameState.god_mode = true


func _fail(msg: String) -> void:
	_fails.append(msg)
	print("[za] FAIL: " + msg)


func _ok(msg: String) -> void:
	print("[za] ok: " + msg)


func _physics_process(delta: float) -> void:
	if _done or not _map.is_inside_tree():
		return
	if _p == null:
		_p = _map.get_node_or_null("Player1") as Player
		_dir = _map.get_node_or_null("ZombieDirector") as ZombieDirector
		if _p == null or _dir == null:
			return
		_p.set_process_unhandled_input(false)
		RoundManager.stop()
		for n: Node in get_tree().get_nodes_in_group(&"doors"):
			(n as BuyDoor).open(0)
		RoundManager.debug_set_round(31)
		RoundManager.stop()
		_p.global_position = PLAYER_POS
		_p.rotation.y = 0.0
	_t += delta
	match _phase:
		-1:
			if _t > 6.0:
				_check_links()
				_spawn_horde()
				_phase = 0
				_t = 0.0
		0:
			if _t > 2.5:
				_sample_slide()
			if _t > 7.5:
				_report_slide()
				_phase = 1
				_t = 0.0
		1:
			_check_climb(delta)
		2:
			_check_gore_and_knockdown(delta)
		3:
			_check_deaths(delta)
		4:
			_check_lod_and_finish()


func _check_links() -> void:
	var links: Array[Node] = []
	var holder: Node = _map.get_node_or_null("ClimbLinks")
	if holder != null:
		links = holder.get_children()
	if links.size() < 3:
		_fail("expected 3 climb links on Map 2, found %d" % links.size())
	var rid: RID = _map.get_world_3d().navigation_map
	for l: Node in links:
		var link: NavigationLink3D = l as NavigationLink3D
		if link == null or not link.has_meta(&"climb"):
			_fail("%s is not a climb link" % l.name)
			continue
		var a: Vector3 = link.global_transform * link.start_position
		var b: Vector3 = link.global_transform * link.end_position
		var da: float = NavigationServer3D.map_get_closest_point(rid, a).distance_to(a)
		var db: float = NavigationServer3D.map_get_closest_point(rid, b).distance_to(b)
		print("[za] link %-16s start off-mesh %.2f m, end off-mesh %.2f m, rise %.1f m" % [link.name, da, db, b.y - a.y])
		if da > 0.8 or db > 0.8:
			_fail("%s endpoints are off the navmesh (%.2f / %.2f)" % [link.name, da, db])
		if link.name == "Ladder_CatwalkW":
			_climb_to = b
	_ok("%d climb links" % links.size())


func _spawn_horde() -> void:
	var made: int = _dir.spawn_burst(SPAWN_LINE, 10)
	var zs: Array[Zombie] = _dir.active_zombies()
	for i: int in zs.size():
		zs[i].debug_set_tier(TIERS[i % TIERS.size()])
	print("[za] spawned %d (%d active), kits: %s" % [made, zs.size(), zs.map(func(z: Zombie) -> String: return z.kit_name() + "/" + z.build_name())])
	if made < 10:
		_fail("spawn_burst made %d of 10" % made)


func _sample_slide() -> void:
	for z: Zombie in _dir.active_zombies():
		if z.state != Zombie.State.CHASE or z.current_clip_state() != "Locomotion" or float(z.get("_loco_x")) < 0.95:
			continue
		var nav: float = z.body_speed()
		if nav < 0.4 or z.anim_speed() <= 0.0:
			continue
		if not _samples.has(z):
			_samples[z] = []
		(_samples[z] as Array).append(z.anim_speed() / nav)


func _report_slide() -> void:
	var zs: Array[Zombie] = _dir.active_zombies()
	var ik_ticks: int = 0
	var look_on: int = 0
	var worst: float = 0.0
	var checked: int = 0
	for z: Zombie in zs:
		var mod: ZombieBodyModifier = z.get("_modifier") as ZombieBodyModifier
		var look: LookAtModifier3D = z.get("_look") as LookAtModifier3D
		if mod != null and mod.ticks > 0:
			ik_ticks += 1
		if look != null and look.active:
			look_on += 1
		if not _samples.has(z):
			continue
		var arr: Array = _samples[z]
		if arr.size() < 20:
			continue
		arr.sort()
		var median: float = float(arr[arr.size() / 2])
		var dev: float = absf(median - 1.0)
		worst = maxf(worst, dev)
		checked += 1
		print("[za] foot-slide %-8s %-14s samples=%d median anim/nav=%.3f" % [z.tier, z.kit_name(), arr.size(), median])
		if dev > 0.05:
			_fail("%s %s: root motion off the nav speed by %.1f%%" % [z.tier, z.kit_name(), dev * 100.0])
	if checked < 5:
		_fail("only %d zombies gave enough locomotion samples (need 5)" % checked)
	else:
		_ok("foot-slide: %d zombies checked, worst deviation %.1f%%" % [checked, worst * 100.0])
	if ik_ticks == 0:
		_fail("the body modifier (foot IK / springs) never ran")
	else:
		_ok("body modifier ran on %d zombies, look-at active on %d" % [ik_ticks, look_on])
	if look_on == 0:
		_fail("no zombie had head look-at active within range")


func _check_climb(_delta: float) -> void:
	if _climber == null:
		var zs: Array[Zombie] = _dir.active_zombies()
		if zs.is_empty() or _climb_to == Vector3.ZERO:
			_fail("no zombie / no west ladder to climb")
			_phase = 2
			_t = 0.0
			return
		_climber = zs[0]
		var from: Vector3 = _climb_to + Vector3(2.8, -4.0, 0.0)
		_climber.global_position = from
		_climber.debug_climb(from, _climb_to)
		_t = 0.0
		print("[za] climb: %s on the west ladder from %s to %s" % [_climber.tier, from, _climb_to])
		return
	if _climber.state == Zombie.State.CLIMB_LINK:
		if _climber.current_clip_state() != "Climb":
			_fail("climbing zombie is not in the Climb animation state (%s)" % _climber.current_clip_state())
		if _t > 8.0:
			_fail("climb never finished")
			_phase = 2
			_t = 0.0
		return
	var d: float = _climber.global_position.distance_to(_climb_to)
	if d > 1.2:
		_fail("climber ended %.2f m from the ladder top" % d)
	else:
		_ok("climb link traversed in %.1f s, ended %.2f m from the top (y %.1f)" % [_t, d, _climber.global_position.y])
	_phase = 2
	_t = 0.0


func _check_gore_and_knockdown(_delta: float) -> void:
	if _kd == null:
		var zs: Array[Zombie] = _dir.active_zombies()
		if zs.size() < 3:
			_fail("not enough zombies for the gore checks")
			_phase = 3
			return
		var a: Zombie = zs[1]
		var before: int = ZombieGore.live_pieces()
		a.sever_limb("LeftLowerArm")
		if not a.is_severed("LeftLowerArm") or a.arms_lost() != 1:
			_fail("sever_limb did not take the forearm")
		elif ZombieGore.live_pieces() <= before:
			_fail("no severed piece prop was thrown")
		else:
			_ok("forearm severed: piece thrown (%d live), attack set now %s" % [ZombieGore.live_pieces(), a._pick_attack()])
		var cap: MeshInstance3D = a.stump_cap("LeftLowerArm")
		if not cap.visible or cap.get_parent() == null:
			_fail("no stump cap on the severed joint")
		GLSettings.values["gore"] = "off"
		var b: Zombie = zs[2]
		b.sever_limb("RightLowerArm")
		if b.is_severed("RightLowerArm"):
			_fail("Gore Off still severed a limb")
		elif b.arms_lost() != 1:
			_fail("Gore Off lost the gameplay side of the sever")
		else:
			_ok("Gore Off: limb stays on, attack set still changes")
		GLSettings.values["gore"] = "full"
		# knockdown: a non-lethal blast on a zombie that keeps its legs
		for z: Zombie in zs:
			if z == a or z == b or z.is_crawler or z.state != Zombie.State.CHASE:
				continue
			z.hp = z.max_hp
			z.take_damage(z.max_hp * 0.2, &"torso", &"frag", 1, &"explosive")
			if z.state == Zombie.State.KNOCKDOWN:
				_kd = z
				_kd_seen = {"KNOCKDOWN": true}
				_t = 0.0
				break
			if z.is_crawler:
				continue   # the blast made a crawler instead (explosive_crawler_chance): try another
		if _kd == null:
			_fail("no zombie went into KNOCKDOWN from a non-lethal explosive")
			_phase = 3
			_t = 0.0
		return
	_kd_seen[str(Zombie.State.keys()[_kd.state])] = true
	if _kd.state == Zombie.State.CHASE and _kd_seen.has("GETUP"):
		_ok("knockdown -> get-up -> chase in %.1f s" % _t)
		_phase = 3
		_t = 0.0
	elif _t > 5.0:
		_fail("knockdown never recovered: states %s" % _kd_seen)
		_phase = 3
		_t = 0.0


func _check_deaths(_delta: float) -> void:
	if _victims.is_empty():
		var zs: Array[Zombie] = _dir.active_zombies()
		var causes: Array = [[&"head", &"bullet"], [&"torso", &"bullet"], [&"torso", &"explosive"], [&"torso", &"melee"], [&"head", &"bullet"], [&"legs", &"bullet"], [&"torso", &"explosive"], [&"torso", &"bullet"]]
		var i: int = 0
		for z: Zombie in zs:
			if i >= causes.size():
				break
			var c: Array = causes[i]
			z.take_damage(z.hp + 1.0, c[0], &"kar98k", 1, c[1])
			if z.state != Zombie.State.DEAD:
				_fail("victim %d did not die" % i)
			_victims.append(z)
			_death_clips[str(z.get("_death_clip"))] = true
			i += 1
		print("[za] deaths: %s" % [_death_clips.keys()])
		for k: String in _death_clips.keys():
			if not ZombieClips.has_clip(k):
				_fail("death clip %s is not in the library" % k)
		_t = 0.0
		return
	_ragdoll_peak = maxi(_ragdoll_peak, ZombieRagdoll.live_count())
	if _t > 1.5 and _t < 1.6:
		for z: Zombie in _victims:
			if z.current_clip_state() != "Death":
				_fail("a dead zombie is not in the Death animation state")
				break
	if _t > 2.0 and ZombieRagdoll.enabled() and _ragdoll_peak == 0:
		_fail("no ragdoll started after the key pose")
	if _ragdoll_peak > int(GLData.table("anim")["ragdoll"]["max_live"]):
		_fail("more live ragdolls (%d) than the cap" % _ragdoll_peak)
	if _t > 16.0:
		var still: int = 0
		for z: Zombie in _victims:
			if z.state != Zombie.State.INACTIVE:
				still += 1
				print("[za]   corpse %s state=%s state_t=%.1f corpse_s=%.1f dissolve=%s active_count=%d" % [z.name, Zombie.State.keys()[z.state], float(z.get("_state_t")), float(z.get("_corpse_seconds")), str(z.get("_inst").get("inst_dissolve", "-")), _dir.active_zombies().size()])
		if still > 0:
			_fail("%d corpses never dissolved back into the pool" % still)
		else:
			_ok("8 deaths (%d distinct clips), ragdoll peak %d (cap %d), corpses returned" % [_death_clips.size(), _ragdoll_peak, int(GLData.table("anim")["ragdoll"]["max_live"])])
		_phase = 4
		_t = 0.0


func _check_lod_and_finish() -> void:
	_done = true # Prevent overlapping finish coroutines while the distance check awaits physics.
	# a zombie 40 m from its target: no IK, no look-at
	var zs: Array[Zombie] = _dir.active_zombies()
	if not zs.is_empty():
		var z: Zombie = zs[0]
		z.global_position = _p.global_position + Vector3(40, 0, 0)
		z.target = _p
		await get_tree().physics_frame
		await get_tree().physics_frame
		var mod: ZombieBodyModifier = z.get("_modifier") as ZombieBodyModifier
		var look: LookAtModifier3D = z.get("_look") as LookAtModifier3D
		if look.active or (mod.active and not mod.springs_active()):
			_fail("IK / look-at still active at 40 m")
		else:
			_ok("IK and look-at off at 40 m")
		var surf: String = z._floor_surface()
		print("[za] floor surface under a zombie: %s" % surf)
	print("[za] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)]))
	_map.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	# The map's weapon cache owns unattached template Nodes; release tool-owned instances on exit.
	for template: Node in WeaponModels._templates.values():
		if is_instance_valid(template): template.free()
	WeaponModels._templates.clear()
	for template: Node in Arms._scenes.values():
		if is_instance_valid(template): template.free()
	Arms._scenes.clear()
	get_tree().quit(0 if _fails.is_empty() else 1)
