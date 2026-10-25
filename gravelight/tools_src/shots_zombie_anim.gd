extends Node
## The MZ acceptance capture (ZOMBIE_ANIM_SPEC §7, T-041): a studio with the OLD zombies on the left (the pre-MZ
## per-bone bodies and plain-rotation poses, tools_src/legacy_zombie_dummy.gd) and the NEW ones on the right (the
## skinned rig, AnimationTree, IK, kits, infection shader), captured side by side:
##   za_01_walking      ten of every tier walking toward the camera
##   za_02_tearing      a barricade being torn (the queue pawing behind)
##   za_03_hits         shot in each limb: head / torso / each arm / each leg flinches, a severed forearm and arm, a crawler
##   za_04_dying        the authored deaths at their key pose
##   za_05_ragdoll      the same corpses two seconds later (ragdoll settled, pieces on the floor), za_05b a close-up
##   za_06_kits         every outfit kit, a Glasshide and a Bellringer, standing (new only)
##   za_08_emerge_<v>   T-085: each ground-rise variant (fast / standard / slow / roll / crawler) frozen at eight
##                      normalized times across a row, on snow, the last stage's spray live (new only)
##   za_09_emerge_surfaces  the standard rise at head-out on snow / earth / stone
##   za_10_emerge_live  eight standard rises started 0.25 s apart, caught mid-flight (the real timing)
## Usage (silent, off-screen, no mouse capture):
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1600x900 --path . res://gravelight/tools_src/shots_zombie_anim.tscn -- --out=<dir> [--only=emerge]

const LegacyDummy: GDScript = preload("res://gravelight/tools_src/legacy_zombie_dummy.gd")
const TIERS: Array = [&"shamble", &"walk", &"jog", &"run", &"sprint", &"shamble", &"walk", &"jog", &"run", &"sprint"]
const OLD_VARIANTS: Array = ["soldier", "miner", "labstaff", "soldier", "miner", "soldier", "labstaff", "miner", "soldier", "soldier"]
const NEW_KITS: Array = ["soldier", "villager", "miner", "labstaff", "technician", "sailor", "dockworker", "villager", "soldier", "miner"]
## the camera looks down +Z, so world +X is screen-left
const LEFT_X: float = 5.6
const RIGHT_X: float = -5.6

var _out: String = "user://shots"
var _only: String = ""
var _studio: Node3D
var _cam: Camera3D
var _player: Player
var _old: Array[Node3D] = []
var _new: Array[Zombie] = []
var _spawn: ZombieSpawn
var _bar_new: Barricade
var _bar_old: Barricade
var _step: int = 0
var _t: float = 0.0
var _busy: bool = false
var _label: Label


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--only="):
			_only = a.substr(7)
	DirAccess.make_dir_recursive_absolute(_out if _out.is_absolute_path() else ProjectSettings.globalize_path(_out))
	GLSettings.values["gore"] = "full"
	GameState.map_id = &"map01_kaltenbrunn"
	ZombieBody.warm_up(ZombieBody.KITS)
	_build_studio()
	ZombieBody.update_cracks(15, 2.6)
	var ui: CanvasLayer = CanvasLayer.new()
	add_child(ui)
	_label = Label.new()
	_label.position = Vector2(24, 16)
	_label.add_theme_font_size_override("font_size", 28)
	ui.add_child(_label)
	var l2: Label = Label.new()
	l2.text = "BEFORE (pre-MZ)                                                                                         AFTER (MZ)"
	l2.position = Vector2(24, 56)
	l2.add_theme_font_size_override("font_size", 22)
	ui.add_child(l2)


func _build_studio() -> void:
	_studio = Node3D.new()
	_studio.name = "Studio"
	get_tree().root.add_child.call_deferred(_studio)
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.name = "Floor_stone"
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(60, 1, 90)
	cs.shape = box
	cs.position = Vector3(0, -0.5, 0)
	floor_body.add_child(cs)
	var fm: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(60, 90)
	fm.mesh = pm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.16, 0.17)
	mat.roughness = 0.9
	fm.material_override = mat
	floor_body.add_child(fm)
	_studio.add_child(floor_body)
	var region: NavigationRegion3D = NavigationRegion3D.new()
	var nm: NavigationMesh = NavigationMesh.new()
	nm.vertices = PackedVector3Array([Vector3(-30, 0, -45), Vector3(30, 0, -45), Vector3(30, 0, 45), Vector3(-30, 0, 45)])
	nm.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_mesh = nm
	_studio.add_child(region)
	# a low wall splitting the halves
	var wall: MeshInstance3D = MeshInstance3D.new()
	var wb: BoxMesh = BoxMesh.new()
	wb.size = Vector3(0.2, 0.3, 80)
	wall.mesh = wb
	wall.position = Vector3(0, 0.15, 0)
	wall.material_override = mat
	_studio.add_child(wall)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 25, 0)
	sun.light_energy = 1.2
	sun.light_color = Color(0.85, 0.88, 1.0)
	sun.shadow_enabled = true
	_studio.add_child(sun)
	var fill: OmniLight3D = OmniLight3D.new()
	fill.position = Vector3(0, 4, -6)
	fill.omni_range = 40.0
	fill.light_energy = 0.3
	fill.light_color = Color(0.7, 0.6, 0.9)
	_studio.add_child(fill)
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.03, 0.03, 0.05)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.35, 0.42)
	e.ambient_light_energy = 0.5
	e.glow_enabled = true
	e.glow_intensity = 0.6
	e.glow_bloom = 0.1
	env.environment = e
	_studio.add_child(env)
	_cam = Camera3D.new()
	_cam.position = Vector3(0, 2.2, -7.5)
	_cam.rotation_degrees = Vector3(-9, 180, 0)
	_cam.fov = 70
	_cam.current = true
	_studio.add_child(_cam)
	# the target the new zombies walk at (a non-local Player: no camera, no HUD)
	_player = Player.new()
	_player.player_id = 1
	_player.is_local = false
	_player.name = "Player1"
	_studio.add_child(_player)
	_player.position = Vector3(RIGHT_X, 0.1, -30)
	_spawn = ZombieSpawn.new()
	_spawn.kind = &"ground"
	_studio.add_child(_spawn)


func _shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var path: String = "%s/za_%s.png" % [_out, name]
	get_viewport().get_texture().get_image().save_png(path)
	print("[shots_za] wrote ", path)


func _place_old(_i: int, pos: Vector3, variant: String, tier: StringName) -> Node3D:
	var d: Node3D = LegacyDummy.new()
	_studio.add_child(d)
	d.call("build", variant)
	d.set("tier", tier)
	d.set("speed", float(GLData.table("enemies")["tiers"][String(tier)]))
	d.global_position = pos
	d.rotation.y = PI   # the old bodies faced -Z; the camera looks +Z
	_old.append(d)
	return d


func _place_new(spec: Dictionary, pos: Vector3, window: Barricade = null) -> Zombie:
	var z: Zombie = Zombie.new()
	_studio.add_child(z)
	_spawn.global_position = pos
	if window != null:
		_spawn.window_path = _spawn.get_path_to(window)
		_spawn.kind = &"window"
	else:
		_spawn.window_path = NodePath("")
		_spawn.kind = &"ground"
	z.activate(spec, _spawn, _player)
	z.global_position = pos
	# no ZombieDirector in the studio: no avoidance callback, no repath budget reset (see _process)
	(z.get("_agent") as NavigationAgent3D).avoidance_enabled = false
	_new.append(z)
	return z


func _clear() -> void:
	for d: Node3D in _old:
		d.queue_free()
	_old.clear()
	for z: Zombie in _new:
		z.queue_free()
	_new.clear()
	if _bar_new != null:
		_bar_new.queue_free()
		_bar_new = null
	if _bar_old != null:
		_bar_old.queue_free()
		_bar_old = null


func _process(delta: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Zombie.repath_budget = 6
	if not _studio.is_inside_tree() or _busy:
		return
	_t += delta
	if _t < 1.5:
		return
	_busy = true
	var names: Array = ["walking", "tearing", "hits", "dying", "kits", "closeup", "emerge"]
	if _only != "" and _step < names.size() and str(names[_step]) != _only:
		_step += 1
		_busy = false
		return
	match _step:
		0:
			await _scene_walking()
		1:
			await _scene_tearing()
		2:
			await _scene_hits()
		3:
			await _scene_dying()
		4:
			await _scene_kits()
		5:
			await _scene_closeup()
		6:
			await _scene_emerge()
		_:
			get_tree().quit()
			return
	_step += 1
	_busy = false


func _scene_walking() -> void:
	_label.text = "01 walking: ten of every tier"
	for i: int in 10:
		var x: float = LEFT_X - 4.3 + 0.95 * float(i)
		_place_old(i, Vector3(x, 0, 5.0 + 1.5 * float(i % 2)), OLD_VARIANTS[i], TIERS[i])
	for i: int in 10:
		var x: float = RIGHT_X - 4.3 + 0.95 * float(i)
		var z: Zombie = _place_new({"enemy_id": "ganger", "tier": String(TIERS[i]), "health": 300, "variant": NEW_KITS[i]}, Vector3(x, 0, 5.0 + 1.5 * float(i % 2)))
		z.set("state", Zombie.State.CHASE)   # skip the emerge for the walk shot
		z.call("_enter", Zombie.State.CHASE)
	await get_tree().create_timer(1.0).timeout
	await _shot("01_walking")
	_clear()


func _scene_tearing() -> void:
	_label.text = "02 tearing a barricade"
	_bar_old = Barricade.new()
	_studio.add_child(_bar_old)
	_bar_old.position = Vector3(3.3, 0, -3.0)
	_bar_old.rotation.y = PI   # local +Z (into the room) toward the camera: the player's view through the boards
	_bar_old.build_greybox()
	_bar_new = Barricade.new()
	_studio.add_child(_bar_new)
	_bar_new.position = Vector3(-3.3, 0, -3.0)
	_bar_new.rotation.y = PI
	_bar_new.build_greybox()
	# old: one tearing at the boards, the others waiting in the queue
	for i: int in 5:
		var pos: Vector3 = Vector3(3.3, 0, -2.1) if i == 0 else Vector3(3.3 + (-1.3 if i % 2 == 0 else 1.3), 0, -0.6 + 0.9 * float(i / 2))
		var d: Node3D = _place_old(i, pos, OLD_VARIANTS[i], &"walk")
		d.call("set_mode", "tear" if i == 0 else "idle")
	for i: int in 5:
		_place_new({"enemy_id": "ganger", "tier": "walk", "health": 300, "variant": NEW_KITS[i]}, Vector3(-3.3 + randf_range(-2.0, 2.0), 0, 1.0 + 0.8 * float(i)), _bar_new)
	await get_tree().create_timer(5.5).timeout
	print("[shots_za] barricade boards=%d children=%d; zombie states: %s" % [_bar_new.boards, _bar_new.get_child_count(), _new.map(func(z: Zombie) -> String: return str(Zombie.State.keys()[z.state]) + "/" + z.current_clip_state())])
	await _shot("02_tearing")
	_clear()


func _scene_hits() -> void:
	_label.text = "03 shot in each limb (head, torso, arm L/R, leg L/R), a severed forearm and arm, a crawler"
	var zones: Array = [[&"head", "l"], [&"torso", "l"], [&"arms", "l"], [&"arms", "r"], [&"legs", "l"], [&"legs", "r"]]
	for i: int in 9:
		var x: float = LEFT_X - 3.8 + 0.95 * float(i)
		var d: Node3D = _place_old(i, Vector3(x, 0, 1.0), OLD_VARIANTS[i], &"walk")
		d.call("set_mode", "idle")
	for i: int in 9:
		var x: float = RIGHT_X - 3.8 + 0.95 * float(i)
		var z: Zombie = _place_new({"enemy_id": "ganger", "tier": "walk", "health": 400, "variant": NEW_KITS[i]}, Vector3(x, 0, 1.0))
		z.set("state", Zombie.State.CHASE)
		z.call("_enter", Zombie.State.CHASE)
	await get_tree().create_timer(1.2).timeout
	for i: int in 6:
		var z: Zombie = _new[i]
		z.last_hit_bone = ("Left" if zones[i][1] == "l" else "Right") + ("UpperArm" if zones[i][0] == &"arms" else "UpperLeg")
		z.take_damage(30.0, zones[i][0], &"kar98k", 1, &"bullet")
		(_old[i] as Node).call("start_flinch")
	_new[6].sever_limb("LeftLowerArm")
	_new[7].sever_limb("RightUpperArm")
	_new[8].become_crawler()
	await get_tree().create_timer(0.09).timeout
	await _shot("03_hits")
	_clear()


func _scene_dying() -> void:
	_label.text = "04 dying: the authored deaths at their key pose"
	var causes: Array = [[&"head", &"bullet"], [&"torso", &"bullet"], [&"torso", &"explosive"], [&"torso", &"melee"], [&"head", &"bullet"], [&"torso", &"bullet"], [&"torso", &"explosive"], [&"torso", &"bullet"], [&"head", &"bullet"], [&"torso", &"bullet"]]
	for i: int in 10:
		var x: float = LEFT_X - 4.3 + 0.95 * float(i)
		var d: Node3D = _place_old(i, Vector3(x, 0, 1.0 + 1.5 * float(i % 2)), OLD_VARIANTS[i], &"walk")
		d.call("set_mode", "idle")
		d.set("death_kind", i)
	var tiers: Array = [&"walk", &"walk", &"run", &"walk", &"sprint", &"jog", &"walk", &"sprint", &"walk", &"walk"]
	for i: int in 10:
		var x: float = RIGHT_X - 4.3 + 0.95 * float(i)
		var z: Zombie = _place_new({"enemy_id": "ganger", "tier": String(tiers[i]), "health": 100, "variant": NEW_KITS[i]}, Vector3(x, 0, 1.0 + 1.5 * float(i % 2)))
		z.set("state", Zombie.State.CHASE)
		z.call("_enter", Zombie.State.CHASE)
	await get_tree().create_timer(1.0).timeout
	for i: int in 10:
		var z: Zombie = _new[i]
		z.take_damage(z.hp + 1.0, causes[i][0], &"kar98k", 1, causes[i][1])
		(_old[i] as Node).call("set_mode", "dead")
	await get_tree().create_timer(0.5).timeout
	await _shot("04_dying")
	await get_tree().create_timer(2.0).timeout
	for z: Zombie in _new:
		var sim: PhysicalBoneSimulator3D = z.get("_ragdoll") as PhysicalBoneSimulator3D
		var sk: Skeleton3D = z.skeleton()
		print("[shots_za] corpse %s clip=%s ragdoll=%s hips_y=%.2f" % [z.name, z.get("_death_clip"), str(sim != null and sim.is_simulating_physics()), sk.get_bone_global_pose(sk.find_bone("Hips")).origin.y])
	# a close look at the first corpse
	var c0: Zombie = _new[0]
	_cam.position = c0.global_position + Vector3(0, 1.4, -2.6)
	_cam.look_at(c0.global_position + Vector3(0, 0.3, 0), Vector3.UP)
	await _shot("05b_corpse_close")
	_cam.position = Vector3(0, 2.2, -7.5)
	_cam.rotation_degrees = Vector3(-9, 180, 0)
	_label.text = "05 two seconds later: ragdolls settled, pieces on the floor"
	await _shot("05_ragdoll")
	_clear()


func _scene_kits() -> void:
	_label.text = "06 outfit kits (after only): soldier, villager, miner, labstaff, technician, sailor, dockworker, nurse, Glasshide, Bellringer"
	var kits: Array = ["soldier", "villager", "miner", "labstaff", "technician", "sailor", "dockworker", "nurse"]
	_cam.position = Vector3(0, 1.6, -5.0)
	_cam.rotation_degrees = Vector3(-3, 180, 0)
	_cam.fov = 62
	for i: int in kits.size():
		var x: float = 6.0 - 1.3 * float(i)
		var z: Zombie = _place_new({"enemy_id": "ganger", "tier": "walk", "health": 300, "variant": kits[i]}, Vector3(x, 0, 1.5))
		z.set("state", Zombie.State.CHASE)
		z.call("_enter", Zombie.State.CHASE)
		z.speed = 0.0
		z.rotation.y = 0.0
	var g: Zombie = _place_new({"enemy_id": "glasshide", "tier": "walk", "health": 300, "variant": "miner"}, Vector3(-4.8, 0, 1.5))
	g.set("state", Zombie.State.CHASE)
	g.call("_enter", Zombie.State.CHASE)
	g.speed = 0.0
	g.rotation.y = 0.0
	var b: Zombie = _place_new({"enemy_id": "bellringer", "tier": "run", "health": 300, "variant": "bellringer"}, Vector3(-6.2, 0, 1.5))
	b.set("state", Zombie.State.CHASE)
	b.call("_enter", Zombie.State.CHASE)
	b.speed = 0.0
	b.rotation.y = 0.0
	await get_tree().create_timer(1.5).timeout
	await _shot("06_kits")
	_clear()


func _scene_closeup() -> void:
	_label.text = "07 close-up: the infection shader (veins, cracks at round 15, eyes), a soldier and a villager"
	_cam.position = Vector3(0.3, 1.45, -1.9)
	_cam.rotation_degrees = Vector3(2, 180, 0)
	_cam.fov = 50
	for i: int in 2:
		var z: Zombie = _place_new({"enemy_id": "ganger", "tier": "walk", "health": 300, "variant": "soldier" if i == 0 else "villager"}, Vector3(0.75 - 0.9 * float(i), 0, 0.0))
		z.set("state", Zombie.State.CHASE)
		z.call("_enter", Zombie.State.CHASE)
		z.speed = 0.0
		z.rotation.y = 0.0
	await get_tree().create_timer(1.5).timeout
	await _shot("07_closeup")
	_clear()


## T-085: the rise from the ground. One row per variant, each zombie parked at one of eight normalized times
## (the stage times, so every stage of the table is in the frame), low camera so the mound and the hole read;
## then the three surfaces, then a live row for the real timing.
func _scene_emerge() -> void:
	_cam.position = Vector3(0, 1.35, -4.6)
	_cam.rotation_degrees = Vector3(-11, 180, 0)
	_cam.fov = 64
	var l2: Label = _label.get_parent().get_child(1) as Label
	if l2 != null:
		l2.text = ""
	for v: String in ZombieEmerge.variants():
		var list: Array = ZombieEmerge.stage_list(v)
		var ks: PackedFloat32Array = []
		var names: PackedStringArray = []
		for i: int in 8:
			var idx: int = int(round(float(i) * float(list.size() - 1) / 7.0))
			var k: float = float((list[idx] as Array)[1])
			# just past the stage time so the burst has broken the surface; the last column is the end
			ks.append(minf(1.0, k + 0.02) if i < 7 else 1.0)
			names.append(str((list[idx] as Array)[0]))
		_label.text = "08 rise '%s' (%.1f s) on snow: %s" % [v, ZombieEmerge.variant_seconds(v), " / ".join(names)]
		_spawn.set_meta("surface", "snow")
		for i: int in 8:
			var x: float = 3.85 - 1.1 * float(i)
			var z: Zombie = _place_new({"enemy_id": "ganger", "tier": "walk", "health": 300, "variant": NEW_KITS[i], "crawler": v == "crawler"}, Vector3(x, 0, 1.4))
			z.rotation.y = 0.0
			z.debug_emerge_seek(v, ks[i], true)
			z.set_physics_process(false)
			z.set_process(false)
		print("[shots_za] emerge %s at %s" % [v, str(ks)])
		await get_tree().create_timer(0.22).timeout
		await _shot("08_emerge_" + v)
		_clear()
	_label.text = "09 the standard rise at head-out: snow / earth / stone"
	var surfaces: Array = ["snow", "earth", "stone"]
	for i: int in 3:
		_spawn.set_meta("surface", surfaces[i])
		var z: Zombie = _place_new({"enemy_id": "ganger", "tier": "walk", "health": 300, "variant": NEW_KITS[i]}, Vector3(1.6 - 1.6 * float(i), 0, 1.0))
		z.rotation.y = 0.0
		z.debug_emerge_seek("standard", ZombieEmerge.stage("standard", "head_out", 0.4) + 0.02, true)
		z.set_physics_process(false)
		z.set_process(false)
	await get_tree().create_timer(0.22).timeout
	await _shot("09_emerge_surfaces")
	_clear()
	_spawn.set_meta("surface", "snow")
	_label.text = "10 eight standard rises started 0.25 s apart (live)"
	for i: int in 8:
		var x: float = 3.85 - 1.1 * float(i)
		var z: Zombie = _place_new({"enemy_id": "ganger", "tier": "walk", "health": 300, "variant": NEW_KITS[i]}, Vector3(x, 0, 1.4))
		z.rotation.y = 0.0
		z.debug_emerge_seek("standard", 0.0)
		z.set_physics_process(false)
		z.set_process(false)
	for i: int in 8:
		var z: Zombie = _new[7 - i]
		z.set_physics_process(true)
		z.set_process(true)
		await get_tree().create_timer(0.25).timeout
	await _shot("10_emerge_live")
	_clear()
	_spawn.remove_meta("surface")
