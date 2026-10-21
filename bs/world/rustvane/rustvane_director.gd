class_name RustvaneDirector
extends LevelDirector
## Rustvane Canyon's director: the shared LevelDirector (data/bs/levels/rustvane.json) plus what this planet
## adds. Everything is still data:
##   "props"         procedural dressing (RustvaneDressing), built into the navmesh-baked geometry
##   "arenas"        the two boss arenas (RustvaneArena: the Quarry Floor and the Sunset Stage)
##   "zip"           tuning for the ZipRider (golden rails / cliff zip lines; rail rows may add "end": "soft")
##   "updrafts"      CanyonUpdraft columns     "umbrellas"  BounceUmbrella pads
##   "billboards"    the bobbing billboard platforms (MagnetCrane sine movers) with their ad panels
##   "lifts"         ServiceLift cages         "tether_points"  TetherPoint rings (Tether-Hook)
##   "bosses"        {id: {arena, done_flag, stand_in_hp, name, on_start, phases, on_defeat}}; started by the
##                   action {"rv_boss": id}; spawned only through EnemySpawner.spawn(id, pos, parent,
##                   {"arena": arena}); a null spawn falls back to `boss_fallback` (tests) or a stand-in
##   "cutscenes"     level-owned cutscene scripts (same step format as cutscenes.json); the planet's
##                   play_cutscene / story_beat prefer these over the story file's
##   "sky"           the second (ad) sun
## Extra actions (on top of LevelDirector._run): rv_gadget, rv_lift, rv_boss, rv_stage, rv_show_for,
## rv_unlock, rv_ad_sun, rv_popup ("start" / "end"), rv_tether (enable a ring), rv_cc_prop, rv_hide.

signal rv_boss_engaged(id: String, boss: Node3D)
signal rv_boss_down(id: String)
signal popup_finished(bolts: int, seconds: float, dry: bool)

var arenas: Dictionary = {}           # "quarry" / "sunset" -> RustvaneArena
var zip_rider: ZipRider
var updrafts: Dictionary = {}
var umbrellas: Dictionary = {}
var billboards: Dictionary = {}
var lifts: Dictionary = {}
var tethers: Dictionary = {}
var level_cutscenes: Dictionary = {}
var rv_boss: Node3D = null
var rv_boss_id: String = ""
var bosses_down: PackedStringArray = []
var stand_ins_used: PackedStringArray = []
## Tests / the smoke can supply the boss when EnemySpawner has none: func(id: StringName, pos: Vector3,
## arena: RustvaneArena) -> Node3D (added under `dynamic` if it has no parent).
var boss_fallback: Callable = Callable()
var ad_sun_on: bool = true
var popup_running: bool = false
var popup_t: float = 0.0
var popup_last: Dictionary = {}
var _ad_light: DirectionalLight3D
var _ad_disc: Node3D
var _rv_phases: Dictionary = {}


# ================================================================== build hooks

## Runs inside LevelDirector.setup() just before the bake: the dressing and the arenas go into the baked
## geometry so enemies path around cabanas, mounds and pillars.
func _bake_navmesh() -> void:
	var dress: Node3D = Node3D.new()
	dress.name = "Dressing"
	geometry.add_child(dress)
	RustvaneDressing.build_props(dress, D.get("props", []))
	var A: Dictionary = D.get("arenas", {})
	for id: String in A.keys():
		arenas[id] = RustvaneArena.build(geometry, id, A[id], self)
	super._bake_navmesh()


## LevelDirector calls this after triggers and encounters (Scrapheap builds its compactor here); Rustvane
## builds its moving and interactive pieces.
func _build_boss_arena() -> void:
	level_cutscenes = D.get("cutscenes", {})
	_build_rail_extras()
	_build_zip_rider()
	_build_updrafts()
	_build_umbrellas()
	_build_billboards()
	_build_lifts()
	_build_tethers()
	_build_sky()
	for gd: Variant in D.get("gates", []):
		if bool((gd as Dictionary).get("start_open", false)):
			var g: LevelGate = gates.get(str((gd as Dictionary)["id"]))
			if g != null:
				g.open(true)
	for grp: Variant in D.get("hidden_groups", []):
		_set_group_visible(str(grp), false)
	EventBus.boss_health.connect(_on_rv_boss_health)


func _build_rail_extras() -> void:
	for rl: Variant in D.get("rails", []):
		var r: Dictionary = rl
		var n: Node3D = nodes.get(str(r.get("id", ""))) as Node3D
		if n == null:
			continue
		for k: String in ["end", "speed_mul"]:
			if r.has(k):
				n.set_meta(StringName(k), r[k])
		# cable posts under every rail end
		if bool(r.get("posts", false)):
			var pts: Array = r["points"]
			for p: Variant in [pts[0], pts[pts.size() - 1]]:
				var v: Vector3 = LevelKit.v3(p)
				LevelKit.box(n, Vector3(v.x, v.y + 0.9, v.z), Vector3(0.18, 1.8, 0.18), "#8a95a8", false)


func _build_zip_rider() -> void:
	zip_rider = ZipRider.new()
	zip_rider.name = "ZipRider"
	zip_rider.T = D.get("zip", {})
	dynamic.add_child(zip_rider)


func _build_updrafts() -> void:
	for ud: Variant in D.get("updrafts", []):
		var r: Dictionary = ud
		var u: CanyonUpdraft = CanyonUpdraft.new()
		u.name = "Updraft_" + str(r["id"])
		u.radius = float(r.get("r", 2.4))
		u.height = float(r.get("h", 12.0))
		u.force = float(r.get("force", 30.0))
		u.on_time = float(r.get("on", 3.0))
		u.off_time = float(r.get("off", 1.5))
		u.phase = float(r.get("phase", 0.0))
		u.position = LevelKit.v3(r["p"])
		dynamic.add_child(u)
		updrafts[str(r["id"])] = u
		nodes[str(r["id"])] = u


func _build_umbrellas() -> void:
	for ud: Variant in D.get("umbrellas", []):
		var r: Dictionary = ud
		var u: BounceUmbrella = BounceUmbrella.new()
		u.name = "Umbrella_" + str(r["id"])
		u.power = float(r.get("power", 17.0))
		u.color = r.get("color", "#ff6ac2")
		u.position = LevelKit.v3(r["p"])
		dynamic.add_child(u)
		umbrellas[str(r["id"])] = u
		nodes[str(r["id"])] = u


func _build_billboards() -> void:
	var i: int = 0
	for bd: Variant in D.get("billboards", []):
		var r: Dictionary = bd
		var p: Vector3 = LevelKit.v3(r["p"])
		var amp: float = float(r.get("amp", 0.9))
		var c: MagnetCrane = MagnetCrane.new()
		c.name = "Billboard_" + str(r["id"])
		c.base = p - Vector3(0, amp, 0)
		c.end = p + Vector3(0, amp, 0)
		c.speed = float(r.get("speed", 0.8))
		c.phase = float(r.get("phase", float(i) * 1.4))
		c.size = LevelKit.v3(r.get("size", [3.4, 0.4, 3.4]))
		c.tower = false
		c.plate_color = "#f2ebe0"
		dynamic.add_child(c)
		billboards[str(r["id"])] = c
		movers[str(r["id"])] = c
		nodes[str(r["id"])] = c
		# the ad panel on its post (static, as in the source), facing the climb
		var ad: Dictionary = {"p": [p.x, p.y + 2.6, p.z - 1.8], "size": [5, 2.5], "n": int(r.get("ad", i)), "ry": float(r.get("ry", 0.0))}
		RustvaneDressing.ad_board(dynamic, ad)
		LevelKit.box(dynamic, Vector3(p.x, p.y + 1.1, p.z - 1.8), Vector3(0.2, 2.4, 0.2), "#8a95a8", false)
		i += 1


func _build_lifts() -> void:
	for ld: Variant in D.get("lifts", []):
		var r: Dictionary = ld
		var l: ServiceLift = ServiceLift.new()
		l.name = "Lift_" + str(r["id"])
		l.bottom = LevelKit.v3(r["bottom"])
		l.top = LevelKit.v3(r["top"])
		l.speed = float(r.get("speed", 3.0))
		l.dwell = float(r.get("dwell", 1.6))
		l.size = LevelKit.v3(r.get("size", [3.2, 0.4, 3.2]))
		dynamic.add_child(l)
		lifts[str(r["id"])] = l
		nodes[str(r["id"])] = l
		# the shaft rails on the wall behind it
		var shaft_x: float = l.bottom.x + float(r.get("rail_dx", 0.0))
		for dz: float in [-1.4, 1.4]:
			LevelKit.box(dynamic, Vector3(shaft_x, (l.bottom.y + l.top.y) * 0.5 + 1.4, l.bottom.z + dz),
				Vector3(0.2, l.top.y - l.bottom.y + 2.8, 0.2), "#5a6377", false)


func _build_tethers() -> void:
	for td: Variant in D.get("tether_points", []):
		var r: Dictionary = td
		var t: TetherPoint = TetherPoint.new()
		t.name = "Tether_" + str(r["id"])
		t.point_id = str(r["id"])
		t.kind = StringName(str(r.get("kind", "swing")))
		t.enabled = bool(r.get("enabled", true))
		t.face_deg = float(r.get("face", 0.0))
		if r.has("land"):
			t.land_offset = LevelKit.v3(r["land"])
		t.position = LevelKit.v3(r["p"])
		dynamic.add_child(t)
		tethers[str(r["id"])] = t
		nodes["tether." + str(r["id"])] = t


## The second sun, which is an ad (flyover1: "Twin suns, one of which is an ad"). S7 switches it off.
func _build_sky() -> void:
	var S: Dictionary = (D.get("sky", {}) as Dictionary).get("ad_sun", {})
	if S.is_empty():
		return
	_ad_light = DirectionalLight3D.new()
	_ad_light.name = "AdSun"
	_ad_light.light_color = Color.html(str(S.get("color", "#ff6ac2")))
	_ad_light.light_energy = float(S.get("energy", 0.5))
	_ad_light.shadow_enabled = false
	add_child(_ad_light)
	_ad_light.look_at_from_position(LevelKit.v3(S.get("dir"), Vector3(-20, 14, -30)), Vector3.ZERO, Vector3.UP)
	_ad_disc = Node3D.new()
	_ad_disc.name = "AdSunDisc"
	add_child(_ad_disc)
	_ad_disc.position = LevelKit.v3(S.get("disc"), Vector3(-120, 90, -260))
	var r: float = float(S.get("disc_r", 14.0))
	var mi: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color.html(str(S.get("color", "#ff6ac2")))
	m.disable_fog = true
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ad_disc.add_child(mi)
	var lbl: Label3D = Label3D.new()
	lbl.text = LevelKit.text(str(S.get("label", "AD")))
	lbl.font_size = 512
	lbl.pixel_size = r * 0.0016
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = Color.WHITE
	lbl.no_depth_test = false
	lbl.position = Vector3(0, 0, 0)
	lbl.fixed_size = false
	_ad_disc.add_child(lbl)
	var real: Dictionary = (D.get("sky", {}) as Dictionary).get("sun_disc", {})
	if not real.is_empty():
		var d2: MeshInstance3D = MeshInstance3D.new()
		var s2: SphereMesh = SphereMesh.new()
		s2.radius = float(real.get("r", 16.0))
		s2.height = s2.radius * 2.0
		d2.mesh = s2
		var m2: StandardMaterial3D = StandardMaterial3D.new()
		m2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m2.albedo_color = Color.html(str(real.get("color", "#ffd9a0")))
		m2.disable_fog = true
		d2.material_override = m2
		d2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		d2.position = LevelKit.v3(real.get("p"), Vector3(180, 70, -240))
		add_child(d2)


func set_ad_sun(on: bool) -> void:
	ad_sun_on = on
	if _ad_light != null:
		_ad_light.visible = on
	if _ad_disc != null:
		_ad_disc.visible = on


# ================================================================== actions

func _run(a: Dictionary, source: Node, who: Node) -> void:
	super._run(a, source, who)
	if a.has("if"):
		return
	var quiet: bool = loading
	if a.has("rv_gadget"):
		GadgetManager.grant(StringName(str(a["rv_gadget"])))
	if a.has("rv_lift"):
		var l: ServiceLift = lifts.get(str(a["rv_lift"]))
		if l != null:
			l.enable(bool(a.get("on", true)))
	if a.has("rv_boss") and not quiet:
		start_rv_boss(str(a["rv_boss"]))
	if a.has("rv_stage"):
		var ar: RustvaneArena = arenas.get("sunset")
		if ar != null:
			ar.set_stage_mode(StringName(str(a["rv_stage"])))
	if a.has("rv_show_for") and not quiet:
		var sf: Array = a["rv_show_for"]
		_set_group_visible(str(sf[0]), true)
		_hide_later(str(sf[0]), float(sf[1]) if sf.size() > 1 else 10.0)
	if a.has("rv_hide"):
		_set_group_visible(str(a["rv_hide"]), false)
	if a.has("rv_unlock"):
		SaveProfile.unlock(str(a["rv_unlock"]))
	if a.has("rv_ad_sun"):
		set_ad_sun(bool(a["rv_ad_sun"]))
	if a.has("rv_tether"):
		var t: TetherPoint = tethers.get(str(a["rv_tether"]))
		if t != null:
			t.enabled = bool(a.get("on", true))
			t.set_meta(&"enabled", t.enabled)
	if a.has("rv_popup") and not quiet:
		if str(a["rv_popup"]) == "start":
			_popup_start()
		else:
			_popup_end()
	if a.has("rv_cc_prop"):
		# the demonetized Creator stays on its parked stage (l2_glambot needs it alive), unless the real boss
		# node is still standing there
		if loading or not _boss_present() or (rv_boss.has_method("is_alive") and not bool(rv_boss.call("is_alive"))):
			_set_group_visible("cc_demonetized", true)


func _boss_present() -> bool:
	return rv_boss != null and is_instance_valid(rv_boss) and rv_boss.is_inside_tree()


func _hide_later(group_name: String, seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout
	if is_instance_valid(self):
		_set_group_visible(group_name, false)


# ================================================================== cutscenes owned by the level

func has_level_cutscene(id: String) -> bool:
	return level_cutscenes.has(id)


func level_cutscene_steps(id: String) -> Array:
	return (level_cutscenes.get(id, {}) as Dictionary).get("steps", [])


## Without the planet's cutscene player (plain test hosts), level cutscenes play as their lines.
func play_cutscene(id: String, on_done: Callable = Callable()) -> bool:
	if has_level_cutscene(id) and not (host != null and host.has_method("play_level_cutscene")):
		cutscenes_played.append(id)
		var ids: PackedStringArray = []
		for st: Variant in level_cutscene_steps(id):
			if str((st as Dictionary).get("type", "")) == "line":
				ids.append(str((st as Dictionary)["id"]))
		lines.play_lines(ids)
		BS.set_flag("cs." + id)
		if on_done.is_valid():
			on_done.call()
		return false
	return super.play_cutscene(id, on_done)


## Story beats: a level cutscene with the beat's id plays as the beat (once per save, flag "beat.<id>").
func story_beat(id: String) -> void:
	if has_level_cutscene(id) and not (host != null and host.has_method("story_beat")):
		if BS.flag("beat." + id) or id in beats_played:
			return
		beats_played.append(id)
		BS.set_flag("beat." + id)
		EventBus.story_beat.emit(id)
		play_cutscene(id)
		return
	super.story_beat(id)


# ================================================================== bosses

func boss_cfg(id: String) -> Dictionary:
	return (D.get("bosses", {}) as Dictionary).get(id, {})


func rv_boss_is_down(id: String) -> bool:
	var f: String = str(boss_cfg(id).get("done_flag", id + "_down"))
	return flag(f) or id in bosses_down


## Starts a boss in its arena: on_start actions, then EnemySpawner.spawn(id, BossSpawn, dynamic, {"arena"}).
func start_rv_boss(id: String) -> Node3D:
	var cfg: Dictionary = boss_cfg(id)
	if cfg.is_empty() or rv_boss_is_down(id) or rv_boss_id != "":
		return null
	var arena: RustvaneArena = arenas.get(str(cfg.get("arena", "")))
	rv_boss_id = id
	_rv_phases.clear()
	run_actions(cfg.get("on_start", []), self, bolt())
	var pos: Vector3 = LevelKit.v3(cfg.get("spawn"), arena.anchor("BossSpawn").global_position if arena != null else Vector3.ZERO)
	rv_boss = spawn_boss(StringName(id), pos, arena)
	rv_boss.set_meta(&"level_director", self)
	rv_boss.set_meta(&"arena", arena)
	rv_boss_engaged.emit(id, rv_boss)
	boss_engaged.emit(rv_boss)
	return rv_boss


func spawn_boss(id: StringName, pos: Vector3, arena: RustvaneArena) -> Node3D:
	var n: Node3D = null
	if not EnemyBridge.force_stub:
		var sp: Object = EnemyBridge.spawner()
		if sp != null and spawner_knows(sp, id):
			n = sp.call("spawn", id, pos, dynamic, {"arena": arena}) as Node3D
	if n == null and boss_fallback.is_valid():
		n = boss_fallback.call(id, pos, arena) as Node3D
		if n != null:
			stand_ins_used.append(String(id) + " (fallback)")
	if n == null:
		var cfg: Dictionary = boss_cfg(String(id))
		var s: RustvaneBossStandIn = RustvaneBossStandIn.new()
		s.boss_id = id
		s.display_name = LevelKit.text(str(cfg.get("name", String(id).to_upper())))
		s.max_hp = float(cfg.get("stand_in_hp", 300.0))
		s.hp = s.max_hp
		s.body_color = cfg.get("stand_in_color", "#e8e0d4")
		n = s
		stand_ins_used.append(String(id))
	if n.get_parent() == null:
		dynamic.add_child(n)
		n.global_position = pos
	n.set_meta(&"enemy_id", String(id))
	return n


## True when EnemySpawner has a script for the id (so an unknown id never reaches its push_error).
static func spawner_knows(sp: Object, id: StringName) -> bool:
	if not (sp is Script):
		return true
	var consts: Dictionary = (sp as Script).get_script_constant_map()
	if not consts.has("SCRIPTS"):
		return true
	var rid: StringName = id
	for m: Dictionary in (sp as Script).get_script_method_list():
		if str(m["name"]) == "resolve_id":
			rid = StringName(str(sp.call("resolve_id", id)))
			break
	return (consts["SCRIPTS"] as Dictionary).has(String(rid))


func _on_rv_boss_health(id: StringName, frac: float, _break_frac: float) -> void:
	if rv_boss_id != "" and String(id) == rv_boss_id:
		_rv_check_phases(frac)


func _rv_check_phases(frac: float) -> void:
	var phases: Array = boss_cfg(rv_boss_id).get("phases", [])
	for i: int in phases.size():
		var ph: Dictionary = phases[i]
		if not _rv_phases.has(i) and frac <= float(ph.get("below", 0.0)):
			_rv_phases[i] = true
			run_actions(ph.get("actions", []), self, bolt())


func rv_phase_count() -> int:
	return _rv_phases.size()


func _on_boss_defeated(id: StringName) -> void:
	super._on_boss_defeated(id)
	if rv_boss_id != "" and String(id) == rv_boss_id:
		_rv_defeated()


func _on_enemy_killed(enemy: Node, w: StringName) -> void:
	super._on_enemy_killed(enemy, w)
	if rv_boss_id != "" and enemy == rv_boss:
		_rv_defeated()


func _rv_defeated() -> void:
	if rv_boss_id == "":
		return
	var id: String = rv_boss_id
	rv_boss_id = ""
	bosses_down.append(id)
	var cfg: Dictionary = boss_cfg(id)
	set_flag(str(cfg.get("done_flag", id + "_down")))
	run_actions(cfg.get("on_defeat", []), self, bolt())
	rv_boss_down.emit(id)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if rv_boss_id != "":
		if rv_boss == null or not is_instance_valid(rv_boss) or (rv_boss.has_method("is_alive") and not bool(rv_boss.call("is_alive"))):
			_rv_defeated()
		elif rv_boss.get("hp") != null and rv_boss.get("max_hp") != null and float(rv_boss.get("max_hp")) > 0.0:
			_rv_check_phases(float(rv_boss.get("hp")) / float(rv_boss.get("max_hp")))
	if popup_running:
		popup_t += delta


# ================================================================== GLAMBOT pop-up: Poolside Pile-Up

func _popup_start() -> void:
	var P: Dictionary = D.get("popup", {})
	popup_running = true
	popup_t = 0.0
	set_flag("popup_running")
	set_flag("popup_wet", false)
	var e: Encounter = encounters.get(str(P.get("encounter", "")))
	if e != null:
		if e.started:
			# re-run: a fresh copy of the waves
			var fresh: Encounter = Encounter.new()
			fresh.name = e.name + "_again"
			fresh.encounter_id = e.encounter_id
			fresh.waves = e.waves
			fresh.on_clear = e.on_clear
			fresh.cleared.connect(func(en: Encounter) -> void: run_actions(en.on_clear, en, bolt()))
			dynamic.add_child(fresh)
			encounters[e.encounter_id] = fresh
			e.queue_free()
			e = fresh
		e.start()


func _popup_end() -> void:
	if not popup_running:
		return
	var P: Dictionary = D.get("popup", {})
	popup_running = false
	set_flag("popup_running", false)
	var dry: bool = not flag("popup_wet")
	var reward: int = int(P.get("reward", 200))
	if dry:
		reward = int(round(float(reward) * (1.0 + float(P.get("dry_bonus", 0.25)))))
	BS.add_bolts(reward)
	var bs: Dictionary = SaveProfile.doc["bs"]
	if not bs.has("arena_records") or not (bs["arena_records"] is Dictionary):
		bs["arena_records"] = {}
	var rec: Dictionary = bs["arena_records"]
	var key: String = str(P.get("id", "poolside_pileup"))
	var best: float = float(rec.get(key, INF))
	if popup_t < best:
		rec[key] = snappedf(popup_t, 0.01)
	BS.save_to_profile()
	popup_last = {"bolts": reward, "seconds": popup_t, "dry": dry}
	EventBus.banner.emit(LevelKit.text(str(P.get("banner_done", ""))),
		LevelKit.text(str(P.get("banner_done_sub", ""))).format({"bolts": reward, "time": "%.1f s" % popup_t}), 2.6)
	popup_finished.emit(reward, popup_t, dry)
