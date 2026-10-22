extends Node
## Headless smoke run of the whole B&S arsenal (M3). Builds a flat test range with Bolt, his camera, Sprocket and a
## WeaponManager, then for every one of the 16 guns, at V1..V5 and at Ω, spawns fresh TestDummy targets, fires the
## gun with scripted input (each gun the way it wants: tap, hold, charge, lob, beam, deploy) and checks that it
## damaged a dummy with its own weapon id (Grav Grenade V1-V2 deals no damage by design: it must GRAVITY-CLUMP).
## Then: Signature A and B at V5 for every gun, the Super Sprocket x2, and an Omega Forge evolution.
## Prints "[arsenal] RESULT PASS" or "[arsenal] RESULT FAIL" with the reasons.
##
## Run (no window, no audio):
##   Godot_v4.7.2-stable_win64_console.exe --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools_src/smoke_arsenal.tscn
## Contact sheet of all 16 gun models (V1 row and V5 Ω row) instead; rendered, off-screen, every audio bus muted:
##   Godot_v4.7.2-stable_win64_console.exe --audio-driver Dummy --position -4000,-4000 --windowed --resolution 1600x900 --path . res://tools_src/smoke_arsenal.tscn -- --sheet
##   (writes user://arsenal_sheet.png and prints its absolute path)
## Uses its own save profile (user://smoke_arsenal_profile.json, deleted afterwards).

const PROFILE: String = "user://smoke_arsenal_profile.json"

var world: Node3D
var bolt: Bolt
var wm: WeaponManager
var sprocket: Sprocket
var fails: PackedStringArray = []
var checks: int = 0
var _t0: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i: int in AudioServer.bus_count:
		AudioServer.set_bus_mute(i, true)
	_t0 = Time.get_ticks_msec()
	SaveProfile.path = PROFILE
	SaveProfile.doc = SaveProfile.blank()
	BS.load_from_profile()
	BS.flags.clear()
	BS.weapons = {}
	BS.weapon_order = []
	BS.current_weapon = &""
	BS.bolts = 0
	BS.god_mode = true
	get_tree().create_timer(1200.0, true, false, true).timeout.connect(func() -> void:
		print("[arsenal] RESULT FAIL (watchdog: took over 20 minutes)")
		get_tree().quit(2))
	if "--sheet" in OS.get_cmdline_user_args():
		_sheet.call_deferred()
	else:
		_run.call_deferred()


func check(ok: bool, msg: String) -> bool:
	checks += 1
	if not ok:
		fails.append(msg)
		print("[arsenal]   FAIL: ", msg)
	return ok


func frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _build_range() -> void:
	world = Node3D.new()
	world.name = "ArsenalRange"
	add_child(world)
	var floor_b: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = Vector3(200, 1, 200)
	cs.shape = sh
	floor_b.add_child(cs)
	floor_b.position = Vector3(0, -0.5, 0)
	world.add_child(floor_b)
	bolt = Bolt.new()
	bolt.position = Vector3(0, 0.95, 0)
	world.add_child(bolt)
	var cam: BoltCamera = BoltCamera.new()
	cam.target = bolt
	world.add_child(cam)
	bolt.camera = cam
	bolt.scripted = {"dir": Vector3.ZERO}
	sprocket = Sprocket.new()
	sprocket.bolt = bolt
	world.add_child(sprocket)
	wm = WeaponManager.attach_to(bolt, false)
	wm.ammo_drops_enabled = false
	wm.callouts_enabled = false
	wm.rng.seed = 3


func _clear() -> void:
	wm.scripted = {}
	for g: StringName in [&"enemies", &"subsidiaries", &"middleman_drones", &"root_plants", &"singularities", &"zap_residue",
			&"void_rifts", &"pending_zones", &"ice_walls", &"patent_orbs"]:
		for n: Node in get_tree().get_nodes_in_group(g):
			if n.get_parent() != null:
				n.get_parent().remove_child(n)
			n.queue_free()
	for c: Node in world.get_children():
		if c is BSProjectile or c is BoomBoxDevice or c is PatentFan or c is PaperTrail:
			c.queue_free()


func _dummies() -> Array[TestDummy]:
	var out: Array[TestDummy] = []
	for p: Vector3 in [Vector3(0, 0, -6), Vector3(1.6, 0, -6.5), Vector3(-1.6, 0, -6.5)]:
		var d: TestDummy = TestDummy.new()
		d.hp = 99999.0
		d.max_hp = 99999.0
		d.position = p
		world.add_child(d)
		out.append(d)
	return out


func setup_gun(id: StringName, lv: int, sig: int, om: bool) -> BSWeapon:
	wm.give(id)
	var st: Dictionary = BS.weapons[String(id)]
	st["xp"] = float(WeaponData.thresholds()[lv - 1])
	st["level"] = lv
	st["sig"] = sig
	st["omega"] = om
	if lv >= 3:
		for s: String in WeaponData.MOD_SLOTS:
			(st["mods"] as Dictionary)[s] = mini(3, lv - 2)
	var w: BSWeapon = wm.weapon(id)
	w.refill()
	w.cooldown = 0.0
	if wm.current != id:
		wm.select(id)
	return w


func _aim_at(p: Vector3) -> void:
	wm.aim_override = (p - bolt.aim_origin()).normalized()


func _hold(input: String, n: int) -> void:
	wm.scripted = {input: true}
	await frames(n)
	wm.scripted = {input: false}
	await frames(1)


## --only=<id>[,<id>...] limits the gun trials (debugging).
func only_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			for s: String in a.substr(7).split(","):
				out.append(StringName(s))
	return out if not out.is_empty() else WeaponData.ids()


## Fires `id` the way it's meant to be fired at the dummy cluster.
func drive(id: StringName, ds: Array[TestDummy]) -> void:
	_aim_at(ds[0].get_center())
	match String(id):
		"void_ripper":
			await _hold("fire", 60)
			await frames(60)
		"boom_box", "grav_grenade":
			_aim_at(ds[0].global_position)
			await _hold("fire", 2)
			await frames(180)
		"lawn_dart", "patent_pending":
			await _hold("fire", 2)
			await frames(120)
		"root_canal":
			_aim_at(ds[0].global_position + Vector3(0, 0.1, 0.6))
			await _hold("fire", 2)
			await frames(80)
		"middleman":
			await _hold("fire", 2)
			await frames(60)
		"frostbyte", "hostile_takeover":
			await _hold("fire", 70)
		"clearance_rack":
			await _hold("fire", 90)
		_:
			await _hold("fire", 40)
			await frames(30)
	var w: BSWeapon = wm.weapon(id)
	if w.sig() == &"extended_mix":
		await frames(120)        # 3 s dance
	elif w.sig() == &"hedge_trimmer":
		await frames(60)         # blades orbit Bolt for 1.2 s first


func trial(id: StringName, lv: int, sig: int, om: bool) -> void:
	_clear()
	await frames(2)
	var ds: Array[TestDummy] = _dummies()
	await frames(2)
	setup_gun(id, lv, sig, om)
	await drive(id, ds)
	var total: float = 0.0
	var own: bool = false
	var clumped: bool = false
	for d: TestDummy in ds:
		total += d.total_damage()
		for h: Variant in d.hits:
			if (h as Combat.Hit).weapon_id == id and (h as Combat.Hit).amount > 0.0:
				own = true
		if (d.get_node("Status") as StatusEffects).has(&"gravity_clumped") or d.launched > 0.0:
			clumped = true
	var tag: String = "%s V%d%s%s" % [id, lv, " Ω" if om else "", (" sig " + ("A" if sig == 0 else "B")) if sig >= 0 else ""]
	if id == &"grav_grenade" and ((lv < 3 and not om) or sig == 0):    # V1-2 and Tidy Up: grouping, no crush
		check(clumped, "%s: gravity-clumps the dummies" % tag)
	else:
		check(total > 0.0 and own, "%s: damages a dummy with its own id (total %.0f)" % [tag, total])
	print("[arsenal]   %s -> %.0f damage" % [tag, total])
	if "--verbose" in OS.get_cmdline_user_args():
		print("[arsenal]     plants=%s muzzle=%s hits=%s" % [str(get_tree().get_nodes_in_group(&"root_plants").map(func(n: Node) -> Vector3: return (n as Node3D).global_position)), str(wm.muzzle_pos()), str(ds.map(func(x: TestDummy) -> int: return x.hits.size()))])


func _run() -> void:
	_build_range()
	await frames(5)
	print("[arsenal] -- every gun at V1..V5 and Ω (%.1fs)" % [(Time.get_ticks_msec() - _t0) / 1000.0])
	check(ForgeDebug.give_all() == 13, "ForgeDebug.give_all gives the 13 non-starters")
	check(wm.weapons.size() == 16, "16 guns owned")
	for id: StringName in only_ids():
		check(ResourceLoader.exists(str(WeaponData.def(id).get("script", ""))), "%s has its gun script" % id)
		for lv: int in range(1, 6):
			await trial(id, lv, -1, false)
		await trial(id, 5, 0, true)
	print("[arsenal] -- Signature Mods A and B at V5 (%.1fs)" % [(Time.get_ticks_msec() - _t0) / 1000.0])
	for id2: StringName in only_ids():
		for sg: int in 2:
			await trial(id2, 5, sg, false)
	print("[arsenal] -- Super Sprocket x2 and the Omega Forge (%.1fs)" % [(Time.get_ticks_msec() - _t0) / 1000.0])
	_clear()
	await frames(2)
	var d: TestDummy = _dummies()[0]
	await frames(2)
	var zap: BSWeapon = wm.weapon(&"sprocket_zap")
	zap.deal(d, 10.0, d.get_center())
	sprocket.super_protocol.active = true
	zap.deal(d, 10.0, d.get_center())
	sprocket.super_protocol.active = false
	check(d.hits.size() == 2 and is_equal_approx((d.hits[1] as Combat.Hit).amount, 2.0 * (d.hits[0] as Combat.Hit).amount),
		"Super Sprocket doubles gun damage")
	var f: OmegaForge = OmegaForge.new()
	world.add_child(f)
	f.global_position = Vector3(0, 0, -3)
	await frames(1)
	check(f.interact() == "locked", "the Forge is locked before blartzRescue")
	BS.set_flag("blartzRescue")
	check(f.evolve(&"buzzkill") == "bs.forge.deny.03" or f.evolve(&"buzzkill") != "", "the Forge denies an unready gun")
	ForgeDebug.max_out(&"buzzkill", 0)
	(BS.weapons["buzzkill"] as Dictionary)["omega"] = false
	BS.bolts = 2000
	check(f.evolve(&"buzzkill") == "", "the Forge evolves a ready gun")
	check(BS.bolts == 0 and wm.weapon(&"buzzkill").omega(), "2,000 bolts -> Ω MOOD KILLER")
	# the cutscene runs on wall-clock beats (forge.json "cutscene"), so wait on time, not on a frame count
	var deadline: float = f.cutscene_length() + 3.0
	var waited: float = 0.0
	while f.playing and waited < deadline:
		waited += get_process_delta_time()
		await get_tree().process_frame
	check(not f.playing, "the evolution cutscene finishes (%.1fs of %.1fs)" % [waited, f.cutscene_length()])
	_finish()


func _finish() -> void:
	wm.scripted = {}
	if FileAccess.file_exists(PROFILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE))
	print("[arsenal] %d checks in %.1fs" % [checks, (Time.get_ticks_msec() - _t0) / 1000.0])
	if fails.is_empty():
		print("[arsenal] RESULT PASS")
	else:
		print("[arsenal] RESULT FAIL (%d)" % fails.size())
		for f: String in fails:
			print("[arsenal]   - ", f)
	get_tree().quit(0 if fails.is_empty() else 1)


# ------------------------------------------------------------------ contact sheet (rendered)

func _sheet() -> void:
	var root: Node3D = Node3D.new()
	add_child(root)
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.09, 0.11, 0.15)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.62, 0.7)
	env.environment = e
	root.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	root.add_child(sun)
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 5.4
	cam.position = Vector3(3.5, 0.0, 6.0)
	root.add_child(cam)
	cam.current = true
	var ids: Array[StringName] = WeaponData.ids()
	for i: int in ids.size():
		for row: int in 2:
			var g: Node3D = Node3D.new()
			root.add_child(g)
			var col: int = i % 8
			var band: int = i / 8
			g.position = Vector3(col * 1.0, 1.6 - band * 2.4 - row * 1.1, 0)
			g.rotation = Vector3(0.25, -PI / 2.0 + 0.4, 0)
			g.scale = Vector3.ONE * 2.0
			GunModels.build(g, ids[i], 1 if row == 0 else 5, row == 1)
			if row == 0:
				var l: Label3D = Label3D.new()
				l.text = WeaponData.display_name(ids[i])
				l.font_size = 22
				l.pixel_size = 0.006
				l.position = g.position + Vector3(0, 0.45, 0)
				root.add_child(l)
	for k: int in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "user://arsenal_sheet.png"
	img.save_png(path)
	print("[arsenal] contact sheet: ", ProjectSettings.globalize_path(path))
	get_tree().quit(0)
