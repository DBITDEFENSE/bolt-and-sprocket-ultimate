extends Node
## Headless smoke run of the M3 bosses: the Rustvane Sentinel, The Content Creator and The Algorithm, each in
## its own standalone arena (no planet needed: each boss builds a minimal arena when opts["arena"] is absent).
## For every boss it forces every attack of every phase and checks it fired with a telegraph >= 0.4 s, drives
## the BREAK feeders, pushes the phases with scripted damage (checking 1 -> 2 -> 3, no skips), then kills it
## and checks boss_defeated, the defeat line, drops and the music cues. Bolt is real (scripted, healed every
## frame) so the attacks really land; the run also checks that each boss hurt him at least once.
## Prints "[bosses] RESULT PASS" or "[bosses] RESULT FAIL" with the reasons.
##
## Run (no window, no audio):
##   Godot_v4.7.2-stable_win64_console.exe --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools_src/smoke_bosses.tscn
## Contact sheet of the M3 enemies and bosses instead (rendered, off-screen, every audio bus muted):
##   Godot_v4.7.2-stable_win64_console.exe --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://tools_src/smoke_bosses.tscn -- --shots=C:/dir
##   -> <dir>/m3_enemies.png (4 columns, 480x270 cells; the order is printed)

const PROFILE: String = "user://smoke_bosses_profile.json"

var world: Node3D
var bolt: Bolt
var cam: BoltCamera
var fails: PackedStringArray = []
var hurt: int = 0
var music: PackedStringArray = []
var defeated_ids: Array = []
var _t0: int = 0
var _shots_dir: String = ""


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			_shots_dir = a.substr(8)
	if _shots_dir != "":
		for i: int in AudioServer.bus_count:
			AudioServer.set_bus_mute(i, true)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_shots.call_deferred()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_t0 = Time.get_ticks_msec()
	SaveProfile.path = PROFILE
	SaveProfile.doc = SaveProfile.blank()
	BS.load_from_profile()
	BS.flags.clear()
	BS.bolts = 0
	BS.god_mode = false
	EventBus.player_damaged.connect(func(_a: float, _h: float) -> void: hurt += 1)
	EventBus.story_beat.connect(func(b: String) -> void:
		if b.begins_with("music:"):
			music.append(b))
	EventBus.boss_defeated.connect(func(id: StringName) -> void: defeated_ids.append(id))
	_run.call_deferred()


func check(ok: bool, msg: String) -> bool:
	if not ok:
		fails.append(msg)
		print("[bosses]   FAIL: ", msg)
	return ok


func step(title: String) -> void:
	print("[bosses] -- %s (%.1fs)" % [title, (Time.get_ticks_msec() - _t0) / 1000.0])


func frames(n: int) -> void:
	for i: int in n:
		_keep_bolt()
		await get_tree().physics_frame


func _keep_bolt() -> void:
	if bolt == null:
		return
	bolt.hp = bolt.max_hp
	bolt.dead = false
	bolt.invuln = 0.0
	Game.slowmo_t = 0.0          # BREAK slow-mo is timed in real seconds; --fixed-fps runs far faster than that
	Game.hitstop_t = 0.0
	Engine.time_scale = 1.0


func until(cond: Callable, max_frames: int) -> bool:
	for i: int in max_frames:
		if bool(cond.call()):
			return true
		await frames(1)
	return bool(cond.call())


func _build_world() -> void:
	if world != null:
		world.queue_free()
		await frames(2)
	EnemySpawner.clear_pool()
	AttackTokens.reset()
	world = Node3D.new()
	world.name = "SmokeWorld"
	add_child(world)
	var floor_: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = Vector3(160, 1, 160)
	cs.shape = sh
	floor_.add_child(cs)
	floor_.position = Vector3(0, -0.5, 0)
	world.add_child(floor_)
	bolt = Bolt.new()
	bolt.position = Vector3(0, 0.95, 6)
	world.add_child(bolt)
	cam = BoltCamera.new()
	cam.target = bolt
	world.add_child(cam)
	bolt.camera = cam
	bolt.scripted = {"dir": Vector3.ZERO}
	await frames(3)


func tp(p: Vector3) -> void:
	bolt.global_position = p
	bolt.motor.vel = Vector3.ZERO
	bolt.last_safe = p


## Forces `kind` as the boss's next attack and waits for it to fire. Returns true when it did.
func force(b: PatternBoss, kind: StringName, max_frames: int = 600) -> bool:
	var before: int = int(b.attacks_done.get(kind, 0))
	for i: int in max_frames:
		if int(b.attacks_done.get(kind, 0)) > before:
			return true
		if b.state == EnemyBase.State.CHASE and b.idle_t > 0.05 and b.force_next == &"":
			b.force_next = kind
			b.idle_t = 0.0
		await frames(1)
	return check(int(b.attacks_done.get(kind, 0)) > before, "%s: forced attack %s never fired (state %s, kind %s, idle %.2f, stun %.2f, phase %d, tele_t %.2f)" % [
		b.boss_id, kind, b.state_name(), b.attack_kind, b.idle_t, b.stun_t, b.phase, b.tele_t])


## Scripted damage that pushes the boss just past the next phase threshold.
func push_phase(b: PatternBoss, to_phase: int) -> void:
	await until(func() -> bool: return b.phase_invuln <= 0.0, 120)
	var th: Array = b.bdef["phases"]
	var target_hp: float = float(th[to_phase - 2]) * b.max_hp - 2.0
	for i: int in 40:
		if b.phase >= to_phase:
			break
		b.phase_invuln = 0.0
		var need: float = b.hp - target_hp
		var h: Combat.Hit = Combat.Hit.make(maxf(need / 0.2, 10.0), Combat.Type.KINETIC, bolt)
		h.weapon_id = &"smoke"
		h.weak_point = true
		b.take_damage(h)
		await frames(2)
	check(b.phase == to_phase, "%s: reached phase %d (is %d)" % [b.boss_id, to_phase, b.phase])
	await frames(80)          # phase invuln + banner


func expect_attacks(b: PatternBoss, kinds: Array, label: String) -> void:
	for k: Variant in kinds:
		var kk: StringName = StringName(str(k))
		if not check(int(b.attacks_done.get(kk, 0)) > 0, "%s %s: attack %s fired" % [b.boss_id, label, kk]):
			continue
		check(float(b.tele_log.get(kk, 0.0)) >= 0.4 - 0.001, "%s: %s telegraph %.2f s >= 0.4 s" % [b.boss_id, kk, float(b.tele_log.get(kk, 0.0))])


func wait_parallel(b: PatternBoss, kind: StringName, max_frames: int = 900) -> bool:
	return check(await until(func() -> bool: return int(b.attacks_done.get(kind, 0)) > 0, max_frames),
		"%s: parallel attack %s fired" % [b.boss_id, kind])


func finish(b: PatternBoss) -> void:
	await until(func() -> bool: return b.phase_invuln <= 0.0, 120)
	var pk0: int = get_tree().get_nodes_in_group(&"pickups").size()
	var n0: int = defeated_ids.size()
	for i: int in 30:
		if not b.is_alive():
			break
		b.phase_invuln = 0.0
		var h: Combat.Hit = Combat.Hit.make(99999.0, Combat.Type.KINETIC, bolt)
		h.weapon_id = &"smoke"
		h.weak_point = true
		b.take_damage(h)
		await frames(1)
	check(not b.is_alive() and b.defeated, "%s: defeated" % b.boss_id)
	check(defeated_ids.size() > n0 and defeated_ids[defeated_ids.size() - 1] == b.boss_id, "%s: EventBus.boss_defeated" % b.boss_id)
	check(get_tree().get_nodes_in_group(&"pickups").size() - pk0 >= int(b.bdef["drops"]), "%s: dropped %d bolts" % [b.boss_id, int(b.bdef["drops"])])
	check(music.has("music:push:%s" % b.music_id()) and music.has("music:pop:%s" % b.music_id()), "%s: music cues pushed and popped" % b.boss_id)
	check(b.phase_log == [1, 2, 3], "%s: phases 1 -> 2 -> 3 in order (%s)" % [b.boss_id, str(b.phase_log)])
	print("[bosses]   %s report: %s" % [b.boss_id, JSON.stringify(b.fight_report())])


## Forces UNBOXING with `contents` until a box holding it is falling (a natural unbox already in its
## telegraph would otherwise take the forced slot). Returns the box, or null.
func drop_box(b: ContentCreator, contents: StringName, max_frames: int = 900) -> MysteryBox:
	for i: int in max_frames:
		for n: Node in world.get_children():
			if n is MysteryBox and (n as MysteryBox).contents == contents and not (n as MysteryBox).landed:
				return n as MysteryBox
		if b.state == EnemyBase.State.CHASE and b.force_next == &"":
			b.force_box = contents
			b.force_next = &"unbox"
			b.idle_t = 0.0
		await frames(1)
	return null


# ================================================================== run

func _run() -> void:
	await _sentinel()
	await _content_creator()
	await _algorithm()
	var ok: bool = fails.is_empty()
	print("[bosses] RESULT %s%s" % ["PASS" if ok else "FAIL", "" if ok else (" (%d): %s" % [fails.size(), "; ".join(fails)])])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE))
	get_tree().quit(0 if ok else 1)


func _spawn_boss(id: StringName, pos: Vector3) -> PatternBoss:
	var b: PatternBoss = EnemySpawner.spawn(id, pos, world) as PatternBoss
	check(b != null, "%s spawned" % id)
	await frames(3)
	check(b.arena_node != null and b.arena_owned, "%s built its own arena" % id)
	return b


func _sentinel() -> void:
	step("RUSTVANE SENTINEL")
	await _build_world()
	hurt = 0
	var b: RustvaneSentinel = await _spawn_boss(&"rustvane_sentinel", Vector3(0, 0.1, -8)) as RustvaneSentinel
	if OS.get_environment("SMOKE_DEBUG") == "1":
		b.state_changed.connect(func(f: int, t_: int) -> void:
			print("  [dbg] %s -> %s  kind %s phase %d tele_t %.2f" % [EnemyBase.STATE_NAMES[f], EnemyBase.STATE_NAMES[t_], b.attack_kind, b.phase, b.tele_t]))
	tp(Vector3(0, 0.95, 4))
	check(await until(func() -> bool: return b.started, 120), "sentinel: fight starts on aggro")
	check(b.anchors("Pillar").size() == 4, "sentinel: default arena has 4 pillars")
	# phase 1: beam (+ a muzzle shot on a second beam), mortars
	check(await force(b, &"beam"), "sentinel: charge beam")
	await wait_parallel(b, &"mortar")
	b.force_next = &"beam"
	b.idle_t = 0.0
	await until(func() -> bool: return b.state == EnemyBase.State.TELEGRAPH and b.attack_kind == &"beam", 300)
	var acc0: float = b.break_acc
	var mh: Combat.Hit = Combat.Hit.make(4.0, Combat.Type.KINETIC, bolt)
	mh.point = b.muzzle_pos()
	b.take_damage(mh)
	check(b.muzzle_shots == 1, "sentinel: a shot down the barrel during the telegraph counts")
	check(b.state != EnemyBase.State.TELEGRAPH, "sentinel: the muzzle shot cancels the beam")
	check(b.break_acc > acc0 or b.breaks > 0, "sentinel: the muzzle shot feeds BREAK")
	expect_attacks(b, [&"beam", &"mortar"], "P1")
	# phase 2
	await push_phase(b, 2)
	check(b.plates_blown, "sentinel: plates blew off in phase 2")
	check(await force(b, &"beam"), "sentinel: twin beam")
	check(int(b.attacks_done.get(&"twin_beam", 0)) > 0, "sentinel: phase 2 beams are twin beams")
	# walk Bolt into the searchlight
	var spotted: bool = false
	for i: int in 600:
		tp(b._search_pivot.global_position + b.searchlight_dir() * 12.0 + Vector3(0, -2.0, 0))
		await frames(1)
		if b.spots > 0:
			spotted = true
			break
	check(spotted, "sentinel: the searchlight spots Bolt")
	tp(Vector3(0, 0.95, 4))
	b._mortar_t = 0.05
	await wait_parallel(b, &"mortar_homing", 200)
	expect_attacks(b, [&"twin_beam", &"searchlight", &"mortar_homing"], "P2")
	# phase 3: adds, ram, pillar self-stun
	await push_phase(b, 3)
	await frames(10)
	var dogs: int = 0
	for a: Node3D in b.adds:
		if a is Ambassadog:
			dogs += 1
	check(dogs == 2, "sentinel: 2 Ambassadog adds in phase 3 (%d)" % dogs)
	check(await force(b, &"ram"), "sentinel: ram")
	await until(func() -> bool: return b.state == EnemyBase.State.CHASE, 200)
	# line a ram up with a pillar: put Bolt behind pillar 0
	var pil: Node3D = b.anchors("Pillar")[0]
	b.global_position = b.arena_mid + Vector3(0, 0.1, 0)
	var dir: Vector3 = (pil.global_position - b.global_position)
	dir.y = 0.0
	tp(pil.global_position + dir.normalized() * 4.0 + Vector3(0, -2.55, 0))
	var stuns0: int = b.ram_stuns
	for k: int in 3:
		if b.ram_stuns > stuns0:
			break
		await force(b, &"ram")
		await until(func() -> bool: return b.state != EnemyBase.State.ATTACK, 200)
		if OS.get_environment("SMOKE_DEBUG") == "1":
			print("  [dbg] ram ended at %s, pillar %s, bolt %s, state %s" % [b.global_position, pil.global_position, bolt.global_position, b.state_name()])
		b.global_position = b.arena_mid + Vector3(0, 0.1, 0)
	check(b.ram_stuns > stuns0, "sentinel: a ram into a quarry pillar self-stuns")
	tp(Vector3(0, 0.95, 4))
	expect_attacks(b, [&"ram", &"beam"], "P3")
	check(b.breaks > 0, "sentinel: BREAK happened")
	check(hurt > 0, "sentinel: its attacks hurt Bolt")
	await finish(b)


func _content_creator() -> void:
	step("THE CONTENT CREATOR")
	await _build_world()
	hurt = 0
	var b: ContentCreator = await _spawn_boss(&"content_creator", Vector3(0, 0.1, 0)) as ContentCreator
	tp(Vector3(0, 0.95, 12))
	check(await until(func() -> bool: return b.started, 120), "cc: fight starts on aggro")
	check(await until(func() -> bool: return b.drones_alive() == 3, 900), "cc: 3 camera drones film it")
	check(b.shielded(), "cc: SPOTLIGHT SHIELD up")
	var hp0: float = b.hp
	var h: Combat.Hit = Combat.Hit.make(20.0, Combat.Type.KINETIC, bolt)
	h.weak_point = true
	b.take_damage(h)
	check(absf((hp0 - b.hp) - roundf(20.0 * 2.5 * 0.25)) <= 1.0, "cc: shield cuts even a crit to 25%% (%.1f)" % (hp0 - b.hp))
	# phase 1: every box, the sponsored backfire, the beam
	for c: StringName in [&"sentries", &"lifeguard", &"bomb"]:
		check((await drop_box(b, c)) != null, "cc: unbox %s" % c)
		await frames(150)
	var sentries: int = 0
	var guards: int = 0
	for a: Node3D in b.adds:
		if a is SelfieSentry:
			sentries += 1
		elif a is LifeguardBot:
			guards += 1
	check(sentries >= 2 and guards >= 1, "cc: boxes opened on 2 sentries and a lifeguard (%d, %d)" % [sentries, guards])
	var box: MysteryBox = await drop_box(b, &"bomb")
	for i: int in 300:
		if box == null or box.is_alive():
			break
		box = await drop_box(b, &"bomb")                  # that one had landed already: drop another
	check(box != null and box.is_alive() and box.is_in_group(&"enemies"), "cc: a falling SPONSORED box is targetable")
	if box != null:
		box.take_damage(Combat.Hit.make(5.0))
	check(b.sponsored_shots == 1, "cc: shooting the falling bomb detonates it on the CC")
	check(await force(b, &"beam"), "cc: charge beam")
	expect_attacks(b, [&"unbox", &"beam"], "P1")
	# kill the drones: guaranteed BREAK
	await until(func() -> bool: return b.phase_invuln <= 0.0 and b.state != EnemyBase.State.STAGGER, 300)
	b.break_cd = 0.0
	var br0: int = b.breaks
	for d: CameraDrone in b.drones.duplicate():
		if is_instance_valid(d) and d.is_alive():
			d.take_damage(Combat.Hit.make(999.0))
	await frames(2)
	check(b.drones_broken == 1, "cc: all 3 drones down")
	check(b.breaks > br0, "cc: drones down = a guaranteed BREAK")
	check(not b.shielded(), "cc: the shield is down")
	# phase 2
	await push_phase(b, 2)
	check(b.hologram != null, "cc: the collab hologram appears")
	await frames(10)
	var fans: int = 0
	for a: Node3D in b.adds:
		if a is Ambassadog:
			fans += 1
	check(fans >= 3, "cc: 3 Ambassadog fans rush in (%d)" % fans)
	check(await force(b, &"twin_beam"), "cc: twin beam")
	check(await force(b, &"duet_mortar"), "cc: duet mortar")
	check(await until(func() -> bool: return b.drones_alive() >= 1, 600), "cc: drones respawn at the phase start")
	expect_attacks(b, [&"twin_beam", &"duet_mortar"], "P2")
	# phase 3
	await push_phase(b, 3)
	check(await force(b, &"live_chat"), "cc: live chat")
	var chat: bool = await until(func() -> bool:
		for n: Node in get_tree().get_nodes_in_group(&"enemy_projectiles"):
			if n is EnemyProjectile and (n as EnemyProjectile).kind == &"chat":
				return true
		return false, 200)
	check(chat, "cc: chat bubbles fall")
	await frames(240)
	tp(b.pool_center() + Vector3(10, 0.95, 0))
	check(await force(b, &"like_floor"), "cc: LIKE floor")
	check(b.like_tiles > 0, "cc: gold tiles lit (%d)" % b.like_tiles)
	await frames(60)
	tp(b.pool_center() + Vector3(1, 0.95, 1))
	check(b.in_water(bolt.global_position), "cc: Bolt is in the pool water")
	check(await force(b, &"pool_sweep"), "cc: pool sweep")
	expect_attacks(b, [&"live_chat", &"like_floor", &"pool_sweep"], "P3")
	check(hurt > 0, "cc: its attacks hurt Bolt")
	await finish(b)
	check(b.drones_alive() == 0, "cc: drones go down with it")


func _algorithm() -> void:
	step("THE ALGORITHM")
	await _build_world()
	hurt = 0
	# a stand-in Nova walkway so the reversal / stop hooks are exercised
	var walk: Node3D = Node3D.new()
	var ws: GDScript = GDScript.new()
	ws.source_code = "extends Node3D\nvar reversed: int = 0\nvar stopped: bool = false\nfunc reverse() -> void:\n\treversed += 1\nfunc set_stopped(s: bool) -> void:\n\tstopped = s\n"
	ws.reload()
	walk.set_script(ws)
	walk.add_to_group(&"nova_walkways")
	world.add_child(walk)
	walk.global_position = Vector3(4, 0, 4)
	var b: TheAlgorithm = await _spawn_boss(&"the_algorithm", Vector3(0, 0.1, -10)) as TheAlgorithm
	tp(Vector3(0, 0.95, 4))
	check(await until(func() -> bool: return b.started, 120), "algorithm: fight starts on aggro")
	await wait_parallel(b, &"violation_zone")
	await wait_parallel(b, &"recommend")
	check(await until(func() -> bool: return b.adds.size() >= 2, 200), "algorithm: the recommendation summons a pair")
	var maid: bool = false
	var hoa: bool = false
	for a: Node3D in b.adds:
		maid = maid or a is MeterMaid
		hoa = hoa or a is HOAEnforcer
	check(maid and hoa, "algorithm: Meter Maid + HOA Enforcer")
	expect_attacks(b, [&"violation_zone", &"recommend"], "P1")
	# C&D feeds OVERLOAD
	await until(func() -> bool: return b.phase_invuln <= 0.0 and b.break_t <= 0.0 and b.break_cd <= 0.0, 60)
	var acc0: float = b.break_acc
	var cd: Combat.Hit = Combat.Hit.make(1.0, Combat.Type.LEGAL, bolt)
	cd.weapon_id = &"cease_desist"
	b.take_damage(cd)
	check(b.break_acc >= acc0 + b.max_hp * 0.04 - 0.5 or b.breaks > 0, "algorithm: a Cease & Desist hit adds 4% BREAK")
	# phase 2
	await push_phase(b, 2)
	check(absf(b.spd() - 0.62) < 0.001, "algorithm: TRENDING timers x0.62")
	await wait_parallel(b, &"fine_rain")
	var holder: Array = []
	await until(func() -> bool:
		for n: Node in get_tree().get_nodes_in_group(&"enemy_projectiles"):
			if n is EnemyProjectile and (n as EnemyProjectile).kind == &"fine" and (n as EnemyProjectile).is_active():
				holder.append(n)
				return true
		return false, 400)
	var fine: EnemyProjectile = holder[0] if not holder.is_empty() else null
	check(fine != null and fine.is_in_group(&"enemies"), "algorithm: falling fines are mallet-hittable")
	if fine != null:
		b.break_t = 0.0
		b.break_cd = 0.0
		var mal: Combat.Hit = Combat.Hit.make(10.0, Combat.Type.KINETIC, bolt)
		mal.is_melee = true
		mal.weapon_id = &"mallet"
		var bat0: int = b.fines_batted
		fine.take_damage(mal)
		check(b.fines_batted == bat0 + 1, "algorithm: RETURN TO SENDER bats a fine into the wall")
	await wait_parallel(b, &"walkway_reverse", 600)
	check(await until(func() -> bool: return int(walk.get("reversed")) > 0, 120), "algorithm: the walkways reverse")
	expect_attacks(b, [&"fine_rain", &"walkway_reverse"], "P2")
	# phase 3
	await push_phase(b, 3)
	check(b.doomscroll_on and bool(walk.get("stopped")), "algorithm: DOOMSCROLL on, walkways stopped")
	var z0: float = bolt.global_position.z
	await frames(30)
	check(bolt.global_position.z < z0 - 0.5 or b.doomscroll_pushed > 0.5, "algorithm: the feed scrolls Bolt toward the wall")
	tp(Vector3(0, 0.95, 4))
	check(await force(b, &"like_orbs"), "algorithm: engagement bait")
	check(await force(b, &"mega_fine"), "algorithm: mega-fine")
	expect_attacks(b, [&"doomscroll", &"like_orbs", &"mega_fine"], "P3")
	check(b.breaks > 0 and b.overloads == b.breaks, "algorithm: OVERLOAD played on BREAK")
	check(hurt > 0, "algorithm: its attacks hurt Bolt")
	await finish(b)
	check(not bool(walk.get("stopped")), "algorithm: walkways restart on defeat")


# ================================================================== contact sheet (rendered)

const CW: int = 480
const CH: int = 270
const COLS: int = 4


func _shots() -> void:
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	world = Node3D.new()
	add_child(world)
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#2a3346")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.78, 0.85)
	e.ambient_light_energy = 0.7
	env.environment = e
	world.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0)
	sun.light_energy = 1.3
	world.add_child(sun)
	var fl: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = Vector3(200, 1, 200)
	cs.shape = sh
	fl.add_child(cs)
	EnemyFx.box(fl, sh.size, Vector3.ZERO, EnemyFx.mat(Color("#8a7f6e")))
	fl.position = Vector3(0, -0.5, 0)
	world.add_child(fl)
	var cam3: Camera3D = Camera3D.new()
	world.add_child(cam3)
	cam3.current = true
	# [id, opts, camera distance, look height]
	var subjects: Array = [
		[&"ambassadog", {}, 3.2, 0.5], [&"ambassadog", {"elite": true}, 3.2, 0.5],
		[&"selfie_sentry", {}, 3.0, 0.2], [&"lifeguard_bot", {}, 5.0, 1.1],
		[&"review_bomber", {}, 4.0, 0.0], [&"meter_maid", {}, 4.0, 0.8],
		[&"hoa_enforcer", {}, 5.0, 1.0], [&"hoa_enforcer", {"elite": true}, 5.0, 1.0],
		[&"surge_drone", {}, 2.6, 0.0], [&"zoning_board", {}, 16.0, 0.6],
		[&"cc_camera_drone", {}, 2.4, 0.0], [&"rustvane_sentinel", {}, 11.0, 1.6],
		[&"content_creator", {}, 10.0, 2.6], [&"the_algorithm", {}, 15.0, 3.8],
	]
	var rows: int = int(ceil(subjects.size() / float(COLS)))
	var sheet: Image = Image.create(CW * COLS, CH * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.BLACK)
	for i: int in subjects.size():
		var sj: Array = subjects[i]
		var n: Node3D = EnemySpawner.spawn(StringName(sj[0]), Vector3(0, 0.1, 0), world, sj[1])
		for k: int in 20:
			await get_tree().process_frame
		var focus: Vector3 = Vector3(0, float(sj[3]), 0)
		if n is EnemyBase and (n as EnemyBase).arch == &"flyer":
			focus = (n as EnemyBase).global_position + Vector3(0, float(sj[3]), 0)
			(n as EnemyBase).set_physics_process(false)
		elif n is ZoningBoard:
			focus = n.global_position + Vector3(0, float(sj[3]), 0)
		var d: float = float(sj[2])
		cam3.global_position = focus + Vector3(d * 0.55, d * 0.35, d * 0.8)
		cam3.look_at(focus)
		for k: int in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(CW, CH)
		sheet.blit_rect(img, Rect2i(0, 0, CW, CH), Vector2i((i % COLS) * CW, (i / COLS) * CH))
		print("[bosses] shot %d: %s %s" % [i, sj[0], "(elite)" if bool((sj[1] as Dictionary).get("elite", false)) else ""])
		for c: Node in world.get_children():
			if c != env and c != sun and c != fl and c != cam3:
				c.queue_free()
		EnemySpawner.clear_pool()
		await get_tree().process_frame
	var path: String = _shots_dir.path_join("m3_enemies.png")
	sheet.save_png(path)
	print("[bosses] wrote ", path)
	get_tree().quit()
