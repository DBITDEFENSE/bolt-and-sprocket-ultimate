class_name MondlichtController
extends Node3D
## Map 4 Act IV's controller (UPDATE 07, docs/MAP4_FERNFLUG.md §6, §11.5–§11.6, T-113): the arrival (the Operator's
## local welcome, Dee's fading radio if her cage egg was done, Peg's delivered variant: no grace and -20 % Scrip),
## the first-time lines (low gravity on the first jump, the vacuum on the first breath from the suit), the columns
## (each `column_N_dark` flag drops a letter off NOBODY CANCELS; three dark = flag `account_open`, the Account's
## door), the Account Manager (summoned when F_CORE opens, the horde cut to horde_fraction, bots-alone scaling like
## the other acts' bosses), the renewal clock (started by her RENEWAL phase, or on its own at the act's fallback
## round if the Account was never opened; the Operator's warnings; zero = the renewal ending), and the two endings'
## runners (`start_cancel`, `start_renewal`; the console verbs `cancel now` / `renewal now` call them).

var act: Dictionary = {}
var cfg: Dictionary = {}
var director: ZombieDirector = null
var boss: HomageBoss = null
var boss_spawned: bool = false
var dark_columns: int = 0
var renewal_left: float = -1.0       # < 0: the clock is not running
var renewal_warned: Array[int] = []
var ending: Node = null
var _no_human_t: float = 0.0
var _human_t: float = 0.0
var bots_alone: bool = false
var _lowg_said: bool = false
var _vac_said: bool = false
var _clock_layer: CanvasLayer = null
var _clock_label: Label = null
var _dee_done: Array[int] = []


## The letters off the sign and the Account's door after `dark` columns (of `total`).
static func account_opens(dark: int, total: int = 3) -> bool:
	return dark >= total


## The renewal clock after `dt`: < 0 stays off; otherwise counts down to zero.
static func clock_after(left: float, dt: float) -> float:
	return left if left < 0.0 else maxf(0.0, left - dt)


## Which warning (index into warn_at) is due at `left` seconds and not yet given, or -1.
static func warning_due(left: float, warn_at: Array, given: Array) -> int:
	for i: int in warn_at.size():
		if left <= float(warn_at[i]) and not given.has(i):
			return i
	return -1


func _ready() -> void:
	name = "MondlichtController"
	add_to_group(&"mondlicht_controller")
	GLBus.match_started.connect(_on_match_started)
	GLBus.round_started.connect(_on_round_started)
	GLBus.flag_changed.connect(_on_flag_changed)
	GLBus.zone_opened.connect(_on_zone_opened)
	GLBus.player_jumped.connect(_on_player_jumped)


func _load_cfg() -> Dictionary:
	var path: String = "res://data/gravelight/%s.json" % String(GameState.map_id).get_slice("_", 0)
	if not FileAccess.file_exists(path):
		return {}
	return GLData.load_json(path)


func _on_match_started(_map: StringName) -> void:
	for n: Node in get_tree().get_nodes_in_group(&"director"):
		director = n as ZombieDirector
	cfg = _load_cfg()
	act = cfg.get("act", {})
	(func() -> void: _arrival()).call_deferred()
	_u10_systems()   # UPDATE 10 §3 (T-158): the terminator, the suit overlay, low gravity, the meteor shower


func _arrival() -> void:
	if not Net.is_authority():
		return
	var a: Dictionary = cfg.get("arrival", {})
	var i: int = 0
	for id: Variant in a.get("vo_arrive", []):
		get_tree().create_timer(2.0 + 6.0 * float(i)).timeout.connect(func() -> void: GLVO.play(StringName(str(id))))
		i += 1
	if GameState.has_flag(&"peg_delivered"):
		# the program's men have the manifest: no arrival grace, and a fifth of the squad's Scrip was "retrieved"
		RoundManager.break_left = minf(RoundManager.break_left, 3.0)
		var mult: float = float(a.get("peg_delivered_scrip_mult", 0.8))
		for pid: int in GameState.player_ids:
			var cut: int = int(round(float(Economy.get_scrip(pid)) * (1.0 - mult)))
			if cut > 0:
				Economy.grant(pid, -cut)
		print("[m4d] peg_delivered: no grace, Scrip x%.2f" % mult)
	var sky: Node = get_tree().get_first_node_in_group(&"earth_sky")
	if sky != null and sky.has_method("refresh_from_flags"):
		sky.call("refresh_from_flags")


func _on_round_started(r: int, special: bool) -> void:
	if not Net.is_authority():
		return
	var ar: int = RoundManager.act_round(r) if RoundManager.has_act() else r
	var a: Dictionary = cfg.get("arrival", {})
	if GameState.has_flag(&"dee_cage_done"):
		var rounds: Array = a.get("dee_rounds", [1, 3, 6])
		var lines: Array = a.get("dee_lines", [])
		for i: int in mini(rounds.size(), lines.size()):
			if ar >= int(rounds[i]) and not _dee_done.has(i):
				_dee_done.append(i)
				var id: String = str(lines[i])
				get_tree().create_timer(8.0).timeout.connect(func() -> void: GLVO.play(StringName(id)))
				break
	# the plan renews on its own when the Account was never opened by the fallback round
	var fb: int = int((act.get("events", {}) as Dictionary).get("renewal_fallback_act_round", 16))
	if ar >= fb and not special and not GameState.has_flag(&"account_open") and not GameState.has_flag(&"cancelled") and not GameState.has_flag(&"renewed"):
		print("[m4d] act round %d: the Account was never opened, the plan renews" % ar)
		start_renewal()


func _on_player_jumped(_pid: int, _at: Vector3) -> void:
	if _lowg_said or not Net.is_authority():
		return
	_lowg_said = true
	var id: String = str((cfg.get("arrival", {}) as Dictionary).get("vo_lowg", ""))
	if id != "":
		GLVO.play(StringName(id))
	GLVO.squad_say("M4D_LOWG", 1.0)


func _process(delta: float) -> void:
	if not Net.is_authority():
		return
	_tick_vacuum_line()
	_tick_clock(delta)
	_tick_bots_alone(delta)


func _tick_vacuum_line() -> void:
	if _vac_said:
		return
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.in_vacuum:
			_vac_said = true
			var id: String = str((cfg.get("arrival", {}) as Dictionary).get("vo_vacuum", ""))
			if id != "":
				GLVO.play(StringName(id))
			return


# ---------------------------------------------------------------- the columns

func _on_flag_changed(flag: StringName, value: Variant) -> void:
	if not String(flag).begins_with("column_") or not String(flag).ends_with("_dark") or not bool(value):
		return
	var n: int = 0
	for i: int in [1, 2, 3]:
		if GameState.has_flag(StringName("column_%d_dark" % i)):
			n += 1
	if n == dark_columns:
		return
	dark_columns = n
	var sign: Node = get_tree().get_first_node_in_group(&"cancel_sign")
	if sign != null and sign.has_method("set_stage"):
		sign.call("set_stage", n)
	var col: Dictionary = cfg.get("columns", {})
	var vo: Array = col.get("vo_opr", [])
	if n - 1 < vo.size() and Net.is_authority():
		GLVO.play(StringName(str(vo[n - 1])))
	if n == 1 and Net.is_authority():
		GLVO.squad_say("M4D_COLUMN", 1.0)
	_wake_the_dead()
	if account_opens(n, (col.get("ids", [1, 2, 3]) as Array).size()) and not GameState.has_flag(&"account_open"):
		GameState.set_flag(&"account_open")
		print("[m4d] three columns dark: the Account opens")


## Every read wakes the dead: a burst at the hall's ground points (Backorders by id when the act has them).
func _wake_the_dead() -> void:
	if director == null or not Net.is_authority():
		return
	var pts: Array = []
	for n: Node in get_tree().get_nodes_in_group(&"zombie_spawns"):
		var sp: ZombieSpawn = n as ZombieSpawn
		if sp != null and sp.zone_id == &"E_HALL" and sp.kind == &"ground":
			pts.append(sp.global_position)
	if pts.is_empty():
		return
	var kind: StringName = &"backorder" if director._map_allows(&"backorder") and (GLData.table("enemies")["enemies"] as Dictionary).has("backorder") else &"ganger"
	director.spawn_special(kind, 3, pts)


# ---------------------------------------------------------------- the Account Manager

func _on_zone_opened(zone_id: StringName) -> void:
	var b: Dictionary = act.get("boss", {})
	if b.is_empty() or boss_spawned or director == null or not Net.is_authority():
		return
	if zone_id != StringName(str(b.get("on_zone", "F_CORE"))):
		return
	(func() -> void: _summon_manager()).call_deferred()


func _summon_manager() -> void:
	if boss_spawned or director == null:
		return
	var b: Dictionary = act.get("boss", {})
	var id: StringName = StringName(str(b.get("id", "account_manager")))
	var table: Dictionary = GLData.table("bosses/map04")
	RoundManager.round_total = maxi(2, int(round(float(RoundManager.round_total) * float(table.get("horde_fraction", 0.5)))))
	RoundManager.to_spawn = mini(RoundManager.to_spawn, RoundManager.round_total)
	var station: Vector3 = Vector3(28, 0, -34)
	var bc: Dictionary = (table.get("bosses", {}) as Dictionary).get(String(id), {})
	if bc.has("station"):
		var s: Array = bc["station"]
		station = Vector3(float(s[0]), float(s[1]), float(s[2]))
	var n: Node3D = director.summon_boss(id, station)
	boss = n as HomageBoss
	boss_spawned = boss != null
	if boss == null:
		push_warning("[m4d] %s is not built in this director; the console stays shielded until `cancel now`" % id)
		return
	GameState.set_flag(&"manager_present")
	_no_human_t = 0.0
	_human_t = 0.0
	bots_alone = false
	GLVO.squad_say("M4D_MANAGER", 1.0)
	print("[m4d] %s attends on round %d (act round %d), hp %d" % [id, RoundManager.current_round, RoundManager.act_round(), int(boss.max_hp)])


func _tick_bots_alone(delta: float) -> void:
	if boss == null or not is_instance_valid(boss) or not boss.is_active():
		return
	var ba: Dictionary = CousinsRound.bots_alone_cfg(GLData.table("bosses/map04"))
	if not bool(ba.get("enabled", false)):
		return
	var humans_up: int = 0
	var humans: int = 0
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or p.is_bot:
			continue
		humans += 1
		if p.is_alive():
			humans_up += 1
	if CousinsRound.squad_is_bots_alone(humans_up, humans):
		_no_human_t += delta
		_human_t = 0.0
		if not bots_alone and _no_human_t >= float(ba.get("engage_after", 4.0)):
			bots_alone = true
			var m: Array[float] = CousinsRound.squad_mults(true, ba)
			boss.set_squad_scale(m[0], m[1], m[2], m[3])
	else:
		_human_t += delta
		_no_human_t = 0.0
		if bots_alone and _human_t >= float(ba.get("release_after", 2.0)):
			bots_alone = false
			var m2: Array[float] = CousinsRound.squad_mults(false, ba)
			boss.set_squad_scale(m2[0], m2[1], m2[2], m2[3])


# ---------------------------------------------------------------- the renewal clock

## The Manager's RENEWAL phase starts the clock (real seconds, map04d.json "renewal").
func begin_renewal_clock() -> void:
	if renewal_left >= 0.0 or GameState.has_flag(&"cancelled") or GameState.has_flag(&"renewed"):
		return
	renewal_left = float((cfg.get("renewal", {}) as Dictionary).get("seconds", 360.0))
	renewal_warned.clear()
	_build_clock()
	print("[m4d] the renewal clock runs: %.0f s" % renewal_left)


func stop_renewal_clock() -> void:
	renewal_left = -1.0
	if _clock_layer != null and is_instance_valid(_clock_layer):
		_clock_layer.queue_free()
		_clock_layer = null


func _tick_clock(delta: float) -> void:
	if renewal_left < 0.0:
		return
	renewal_left = clock_after(renewal_left, delta)
	var rc: Dictionary = cfg.get("renewal", {})
	var w: int = warning_due(renewal_left, rc.get("warn_at", []), renewal_warned)
	if w >= 0:
		renewal_warned.append(w)
		var ids: Array = rc.get("vo_warn", [])
		if w < ids.size():
			GLVO.play(StringName(str(ids[w])))
	if _clock_label != null and is_instance_valid(_clock_label):
		_clock_label.text = "RENEWAL  %d:%02d" % [int(renewal_left) / 60, int(renewal_left) % 60]
		_clock_label.modulate = Color(1.0, 0.5, 0.6) if renewal_left < 60.0 else Color(0.8, 0.6, 1.0)
	if renewal_left <= 0.0:
		stop_renewal_clock()
		start_renewal()


func _build_clock() -> void:
	if _clock_layer != null:
		return
	_clock_layer = CanvasLayer.new()
	_clock_layer.layer = 8
	add_child(_clock_layer)
	_clock_label = Label.new()
	_clock_label.add_theme_font_override("font", MenuKit.stamp_font())
	_clock_label.add_theme_font_size_override("font_size", MenuKit.size("hud_banner"))
	MenuKit.outline(_clock_label, "stamp")
	_clock_label.anchor_left = 0.5
	_clock_label.anchor_right = 0.5
	_clock_label.anchor_top = 0.0
	_clock_label.offset_left = -160
	_clock_label.offset_right = 160
	_clock_label.offset_top = 70
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock_layer.add_child(_clock_label)


# ---------------------------------------------------------------- the endings

## The key turned: the canon ending (KÜNDIGUNG), with `key_pid` at the key.
func start_cancel(key_pid: int) -> void:
	if ending != null and is_instance_valid(ending):
		return
	stop_renewal_clock()
	GameState.set_flag(&"cancelled")
	var path: String = "res://gravelight/world/endings/cancel_ending.gd"
	if not ResourceLoader.exists(path):
		push_warning("[m4d] cancel_ending.gd is not built yet")
		return
	ending = (load(path) as GDScript).new()
	ending.set("key_pid", key_pid)
	ending.set("cfg", (cfg.get("endings", {}) as Dictionary).get("cancel", {}))
	get_tree().current_scene.add_child(ending)
	print("[m4d] CANCEL: the key turned (player %d)" % key_pid)


## The clock ran out (or the fallback round came): the bad ending (AUTO-RENEWAL), then the Retained state.
func start_renewal() -> void:
	if ending != null and is_instance_valid(ending) or GameState.has_flag(&"cancelled") or GameState.has_flag(&"renewed"):
		return
	stop_renewal_clock()
	GameState.set_flag(&"renewed")
	var path: String = "res://gravelight/world/endings/renewal_ending.gd"
	if not ResourceLoader.exists(path):
		push_warning("[m4d] renewal_ending.gd is not built yet")
		return
	ending = (load(path) as GDScript).new()
	ending.set("cfg", (cfg.get("endings", {}) as Dictionary).get("renewal", {}))
	get_tree().current_scene.add_child(ending)
	print("[m4d] AUTO-RENEWAL: the plan renewed")


# ---- U10 Act IV (T-158) ----
# The set-pieces of UPDATE 10 §3 (contract C6): the terminator (Terminator), the suit overlay (MoonSuitHud, local),
# low gravity done right (MoonLowG: the pads' first line, the leapers, the orbit count) and the meteor-shower round
# (MeteorShower). Each is created here when the scene does not carry it (older scenes, the smokes), so the act runs
# them whether or not map04d.tscn was regenerated. Console verbs: `terminator <0..1>|status`, `heaters`,
# `meteors now|status`, `orbit status`.

var _glare_said: bool = false


func _u10_systems() -> void:
	var map: Node = get_parent() if get_parent() != null else get_tree().current_scene
	if map == null:
		return
	if get_tree().get_first_node_in_group(&"terminator") == null and cfg.has("terminator"):
		var t: Terminator = Terminator.new()
		map.add_child(t)
	var tn: Terminator = get_tree().get_first_node_in_group(&"terminator") as Terminator
	if tn != null and tn.cfg.is_empty():
		var sd: Array = (cfg.get("earth", {}) as Dictionary).get("sun_dir", [0.88, 0.26, -0.31])
		tn.setup(cfg.get("terminator", {}), Vector3(float(sd[0]), float(sd[1]), float(sd[2])))
		if Net.is_authority():
			tn.call("_set_round_target", RoundManager.current_round, true)
	var amb: Node = get_tree().get_first_node_in_group(&"map_ambience")
	if amb != null and amb.has_method("_kinds_setup_u10_act4"):
		amb.call_deferred("_kinds_setup_u10_act4")   # the living world (map04d_ambience.json); guarded against a second call
	if get_tree().get_first_node_in_group(&"moon_suit_hud") == null:
		map.add_child(MoonSuitHud.new())
	if get_tree().get_first_node_in_group(&"moon_lowg") == null and cfg.has("low_g"):
		var lg: Node = load("res://gravelight/world/map04/moon_lowg.gd").new()
		map.add_child(lg)
	if get_tree().get_first_node_in_group(&"meteor_shower") == null and cfg.has("meteor_shower"):
		var ms: Node = load("res://gravelight/world/map04/meteor_shower.gd").new()
		map.add_child(ms)
	GLBus.round_started.connect(_u10_round)
	var tick: Timer = Timer.new()
	tick.name = "U10Tick"
	tick.wait_time = 0.5
	tick.autostart = true
	tick.timeout.connect(_u10_tick)
	add_child(tick)
	var con: Node = get_node_or_null("/root/GLConsole")
	if con != null and con.has_method("register"):
		con.call("register", "terminator", _cmd_terminator, "terminator <0..1>|status: put Mondlicht's day/night line at act progress t (T-158)")
		con.call("register", "heaters", _cmd_heaters, "heaters: throw the relay heaters (Mondlicht's power-on, T-158)")


## The first time a player is blinded in the open yard: the Operator on the visor (once).
func glare_hint() -> void:
	if _glare_said or not Net.is_authority():
		return
	_glare_said = true
	var id: String = str((cfg.get("terminator", {}) as Dictionary).get("vo_glare", ""))
	if id != "":
		GLVO.play(StringName(id))


func _cmd_terminator(a: PackedStringArray) -> String:
	var t: Terminator = get_tree().get_first_node_in_group(&"terminator") as Terminator
	if t == null:
		return "no terminator on this map"
	if a.size() > 0 and a[0].is_valid_float():
		t.debug_progress(float(a[0]))
	return "terminator s %.1f (target %.1f), progress %.2f, night zones %s, heaters %s" % [t.s, t.target_s, t.progress(), str(t.night_zones), str(t.heaters_on)]


func _cmd_heaters(_a: PackedStringArray) -> String:
	var hs: HeaterSwitch = get_tree().get_first_node_in_group(&"heater_switch") as HeaterSwitch
	if hs == null:
		GameState.set_flag(&"heaters_on")
		return "no switch on this map: the flag is set"
	hs.throw_switch()
	return "the heaters run"


var _u10_said: Dictionary = {}       # line id -> true (once per match)
var smile_seen: bool = false


func _say_once(id: String) -> void:
	if id == "" or _u10_said.has(id):
		return
	_u10_said[id] = true
	GLVO.play(StringName(id))


func _jakub_here() -> bool:
	return get_tree().get_first_node_in_group(&"jakub") != null


## EarthSky: `done` of `total` cancel steps reversed the violet; the Operator and Wren notice (earth.vo_dim).
func earth_dimmed(done: int, _total: int) -> void:
	if not Net.is_authority():
		return
	var lines: Array = ((cfg.get("earth", {}) as Dictionary).get("vo_dim", {}) as Dictionary).get(str(done), [])
	var i: int = 0
	for id: Variant in lines:
		var lid: String = str(id)
		get_tree().create_timer(3.0 + 5.0 * float(i)).timeout.connect(func() -> void: _say_once(lid))
		i += 1


func _u10_round(r: int, _special: bool) -> void:
	if not Net.is_authority():
		return
	var ar: int = RoundManager.act_round(r) if RoundManager.has_act() else r
	var sp: Dictionary = (cfg.get("earth", {}) as Dictionary).get("vo_spread", {})
	if sp.has(str(ar)):
		var id: String = str(sp[str(ar)])
		if not id.begins_with("JAK_") or _jakub_here():
			get_tree().create_timer(12.0).timeout.connect(func() -> void: _say_once(id))


## Twice a second: Jakub at the console and at Pilch's glass (when he is with the squad), the smile's first sight;
## and the living world once MapRoot has attached its MapAmbience (it comes after match_started).
func _u10_tick() -> void:
	if get_tree().get_first_node_in_group(&"mondlicht_living") == null:
		var amb: Node = get_tree().get_first_node_in_group(&"map_ambience")
		if amb != null and amb.has_method("_kinds_setup_u10_act4"):
			amb.call("_kinds_setup_u10_act4")
	if Net.is_authority() and _jakub_here() and GameState.is_zone_open(&"F_CORE"):
		for n: Node in get_tree().get_nodes_in_group(&"players"):
			var p: Player = n as Player
			if p == null or p.is_bot or not p.is_alive():
				continue
			if p.global_position.distance_to(Vector3(28, 0, -30)) < 3.5:
				_say_once("JAK_M4D_CONSOLE_01")
			if p.global_position.distance_to(Vector3(26.4, 0, -39.8)) < 3.0:
				_say_once("JAK_M4D_PILCH_01")
	_check_smile_sight()


## The smile side egg, findable: the first time the local player in the yard looks up at the grin on the far wall,
## the minimap gets a note at the rim's marker (where the egg's interact is).
func _check_smile_sight() -> void:
	if smile_seen:
		return
	var map: Node = get_tree().current_scene
	var lp: Player = map.get("player") as Player if map != null else null
	var cam: Camera3D = get_viewport().get_camera_3d()
	if lp == null or cam == null or not ZoneVolume.vacuum_at(get_tree(), lp.global_position):
		return
	var to_smile: Vector3 = (Vector3(0.0, 30.0, 214.0) - cam.global_position).normalized()
	if (-cam.global_transform.basis.z).dot(to_smile) < 0.9:
		return
	mark_smile()


func mark_smile() -> void:
	if smile_seen:
		return
	smile_seen = true
	var ms: MapState = MapState.current()
	if ms != null:
		ms.add_marker({"pos": Vector3(0.0, 0.0, 104.0), "kind": "note", "label": "The smile, the rim",
			"color": Color(0.8, 0.55, 1.0), "owner": 0, "target": "me"})
	print("[m4d] the smile is seen: a note on the minimap")
