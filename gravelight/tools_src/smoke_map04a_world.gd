extends Node
## Headless smoke for Werk Thalbach's world (UPDATE 10 Act I, DECISIONS T-155):
##   1. the living world: MapRoot attached a MapAmbience from map04a_ambience.json and the Act I block runs without
##      a Landscape: posters, hanging sections, the Kranich's glow, the forest searchlights; the timed beats fire on
##      their act rounds (the train at 3, the jet at 4) and the blackout draws blinds; bell, rattle, weld fire
##   2. the power-on spectacle's extras (PA, gantries, a sting per perk) and the fan's one spin
##   3. room story: four Act I StoryProps with fixed Archive text
##   4. Jette's logbook: a minimap note per glider / the hatch on first sight; her eight VO files exist
##   5. the two people: Erich Wendel's coal opens the cellar's side door for good (plug off, link on); Otto Brack's
##      signal lever makes the next train drop a Resupply in the yard
##   6. verticality: a path from the church square up the watch post to the lookout; the lookout sees the Kranich
##      through the hangar's torn south face (no world collider in the way)
##   7. the boarding preloads Act II (Campaign.preload_next, T-157/T-158) and its card has a transition line
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_map04a_world.tscn

const MAP: String = "res://gravelight/maps/map04_fernflug/map04a.tscn"

var _map: MapRoot
var _p: Player
var _fails: PackedStringArray = []


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile_m4a_world.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GameState.character_id = &"dutch"
	GameState.bot_count = 0
	_map = (load(MAP) as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GameState.god_mode = true
	GLBus.round_started.connect(func(_r: int, _s: bool) -> void:
		RoundManager.to_spawn = mini(RoundManager.to_spawn, 2)
		RoundManager.round_total = mini(RoundManager.round_total, 2))
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _check(cond: bool, what: String) -> void:
	print("[m4aw] %-70s %s" % [what, "ok" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _to_round(r: int) -> void:
	RoundManager.debug_set_round(r)
	var t0: int = Time.get_ticks_msec()
	while RoundManager.act_round() < r and Time.get_ticks_msec() - t0 < 20000:
		await _frames(1)
	await _frames(5)


func _run() -> void:
	await _frames(40)
	_p = _map.get_node("Player1") as Player
	RoundManager.stop()
	(_map.get_node("ZombieDirector") as ZombieDirector).kill_all(true)
	var amb: MapAmbience = _map.get_node_or_null("MapAmbience") as MapAmbience
	_check(amb != null and amb.config_path.ends_with("map04a_ambience.json"), "MapRoot attached the MapAmbience from map04a_ambience.json")
	if amb == null:
		_finish()
		return
	await _frames(10)
	_check(amb._a1_on, "the Act I block runs without a Landscape")
	_check(amb._a1_posters.size() == 6 and amb._a1_hangs.size() == 3 and amb._a1_glow != null, "6 flapping posters, 3 hanging wing sections, the Kranich's glow")
	var sky: Node = get_tree().get_first_node_in_group(&"thalbach_sky")
	_check(sky != null and int(sky.call("beam_count")) == 8, "the forest searchlights joined the works' (%s beams)" % (str(sky.call("beam_count")) if sky != null else "-"))
	_check(not amb._a1_lit.is_empty(), "the lit windows are known (%d)" % amb._a1_lit.size())
	var lit0: int = amb._a1_lit.size()
	# ---- 1. the timed beats
	await _to_round(2)
	await _to_round(3)
	var t0: int = Time.get_ticks_msec()
	while int(amb.a1_counts.get("train", 0)) < 1 and Time.get_ticks_msec() - t0 < 40000:
		await _frames(5)
	_check(int(amb.a1_counts.get("train", 0)) >= 1, "act round 3: the train came in behind the goods shed")
	await _to_round(4)
	t0 = Time.get_ticks_msec()
	while int(amb.a1_counts.get("low_pass", 0)) < 1 and Time.get_ticks_msec() - t0 < 40000:
		await _frames(5)
	_check(int(amb.a1_counts.get("low_pass", 0)) == 1, "act round 4: the test jet's low pass")
	t0 = Time.get_ticks_msec()
	while amb._a1_blinds < 2 and Time.get_ticks_msec() - t0 < 80000:
		await _frames(10)
	_check(amb._a1_blinds >= 2 and amb._a1_lit.size() == lit0 - amb._a1_blinds, "the blackout: %d windows went dark" % amb._a1_blinds)
	amb._ev_a1_bell()
	amb._a1_wind = 1.0
	amb._ev_a1_rattle()
	amb._ev_a1_weld()
	_check(int(amb.a1_counts.get("bell", 0)) >= 1 and int(amb.a1_counts.get("rattle", 0)) >= 1 and int(amb.a1_counts.get("weld", 0)) >= 1,
		"the bell, a rattle, welding sparks")
	# ---- 2. the power
	(_map.get_node("Gameplay/Hauptschalter")).call("run_sequence", 1)
	t0 = Time.get_ticks_msec()
	while not GameState.power_on and Time.get_ticks_msec() - t0 < 20000:
		await _frames(1)
	await _secs(1.0)
	_check(int(amb.a1_counts.get("power_on", 0)) == 1, "the power-on spectacle's extras ran")
	_check(GameState.has_flag(&"tunnel_spun"), "the wind tunnel's fan turned over once on the power")
	(_map.get_node("ZombieDirector") as ZombieDirector).kill_all(true)

	# ---- 3. story props
	var props: Array = []
	for n: Node in _map.find_children("*", "StoryProp", true, false):
		if String(n.get("intel_id")).begins_with("INT_M4A_"):
			props.append(n)
	_check(props.size() >= 4, "four Act I story props (%d)" % props.size())
	var texts: int = 0
	for sp: Node in props:
		var row: Dictionary = StoryProp.intel_row(String(sp.get("intel_id")))
		if str(row.get("placement", "")) == "fixed" and str(row.get("text", "")).length() > 80:
			texts += 1
	_check(texts == props.size() and texts >= 4, "each has fixed Archive text (%d)" % texts)

	# ---- 4. Jette's logbook
	var sn: SightNote = _map.get_node_or_null("Gameplay/SightNote_Jette") as SightNote
	_check(sn != null and sn.targets.size() == 4, "the sight notes watch the three gliders and Jette's hatch")
	if sn != null:
		var g1: Node3D = _map.get_node("Gameplay/Glider1") as Node3D
		_check(SightNote.in_view(g1.global_position + Vector3(0, 1.5, -4), Vector3(0, -0.35, 1).normalized(), g1.global_position, 16.0, 0.8),
			"a glider four metres ahead is in view")
		var before: int = sn.seen.size()
		for i: int in 4:
			sn.note(i)
		_check(sn.seen.size() == 4 and before <= 4, "each first sight puts a note on the minimap")
	var vo_ok: int = 0
	for spk: String in ["DUT", "PEG", "DEA", "WRN"]:
		for cat: String in ["GLIDER", "JETTE"]:
			var id: String = "%s_M4A_%s_01" % [spk, cat]
			if GLVO.lines.has(id) and GLVO.audio_path(StringName(id)) != "":
				vo_ok += 1
	_check(vo_ok == 8, "Jette's logbook's eight squad lines are baked (%d/8)" % vo_ok)

	# ---- 5. the people
	var father: ExtraPerson = null
	var brack: ExtraPerson = null
	for n2: Node in get_tree().get_nodes_in_group(&"extra_people"):
		var ep: ExtraPerson = n2 as ExtraPerson
		if ep != null and ep.id == "siedlung_father":
			father = ep
		elif ep != null and ep.id == "railwayman":
			brack = ep
	_check(father != null and brack != null, "Erich Wendel and Otto Brack are on the map")
	var door: TunnelHatch = _map.get_node_or_null("Gameplay/CellarSideDoor") as TunnelHatch
	var link: NavigationLink3D = _map.get_node_or_null("Navigation/Link_CellarSide") as NavigationLink3D
	_check(door != null and not door.is_open and link != null and not link.enabled, "the cellar's side door is barred")
	if father != null and door != null:
		father.accept_favour(_p)
		_check(father.item != null and father.item.shown and father.item.get_prompt(_p).contains("coal"), "Wendel asks for coal (%s)" % father.item.get_prompt(_p))
		father.item.interact(_p)
		father.give_item(_p)
		await _frames(3)
		_check(father.favour == ExtraPerson.Favour.DONE and door.is_open and link.enabled and GameState.has_flag(&"a1_cellar_side_open"), "the coal opens the cellar's side door for good")
	if brack != null:
		brack.accept_favour(_p)
		_check(brack.item != null and brack.item.get_prompt(_p).begins_with("Pull the signal lever"), "Brack asks for the signal (%s)" % brack.item.get_prompt(_p))
		brack.item.interact(_p)
		brack.give_item(_p)
		var pu_before: int = PowerupManager._pickups.size()
		amb._ev_a1_train()
		t0 = Time.get_ticks_msec()
		while not brack.events.has("train_drop:1") and Time.get_ticks_msec() - t0 < 30000:
			await _frames(5)
		_check(brack.events.has("reward:train_drop") and brack.events.has("train_drop:1"), "the next train drops his crate (%s)" % str(brack.events))
		_check(PowerupManager._pickups.size() > pu_before, "a Resupply lies in the yard")

	# ---- 6. verticality and the hero view
	var rid: RID = _map.get_world_3d().navigation_map
	var path: PackedVector3Array = NavigationServer3D.map_get_path(rid, Vector3(24, 0, 72), Vector3(37.5, 12.0, 85.0), true, 0xFF)
	var top: Vector3 = path[path.size() - 1] if not path.is_empty() else Vector3.ZERO
	_check(not path.is_empty() and top.y > 11.0 and Vector2(top.x - 37.5, top.z - 85.0).length() < 1.5, "a path climbs the watch post's ramp to the lookout (%s)" % str(top))
	var space: PhysicsDirectSpaceState3D = _map.get_world_3d().direct_space_state
	var eye: Vector3 = Vector3(38.6, 13.7, 86.0)
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, Vector3(-19.7, 6.3, 170.0), 1)
	var hit: Dictionary = space.intersect_ray(q)
	var hit_at: Vector3 = hit.get("position", Vector3.ZERO)
	_check(hit.is_empty() or hit_at.z > 160.0, "from the lookout the Kranich is in sight through the hangar's gap (%s)" % (str(hit_at) if not hit.is_empty() else "clear"))

	# ---- 7. the boarding's card
	_check(LoadingScreen.lore_line("map04b_kranich") != "", "Act II's loading card has a lore line")
	_check(LoadingScreen.transition_line("map04a_thalbach", "map04b_kranich") != "", "the boarding's card has its own transition line")
	var pre: bool = Campaign.preload_next(&"map04b_kranich")
	await _frames(5)
	_check(pre and LoadingScreen.preloaded.ends_with("map04b.tscn"), "the boarding preloads Act II (%s)" % LoadingScreen.preloaded)
	_finish()


func _finish() -> void:
	RoundManager.stop()
	if _fails.is_empty():
		print("[m4aw] RESULT: PASS")
		get_tree().quit(0)
	else:
		print("[m4aw] RESULT: FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)])
		get_tree().quit(1)
