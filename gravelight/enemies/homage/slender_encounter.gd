class_name SlenderEncounter
extends HomageEncounter
## THE SLENDER's round on Totenhafen (HB3 moved from Morgenrot: the Hafenwächter; docs/HOMAGE_BOSSES.md section 6,
## docs/U10_TOTENHAFEN_DESIGN.md section 9; DECISIONS T-160). Created by the ZombieDirector on map02 (host / solo).
## Schedule: round 25 standalone, 45 in the campaign; he needs the power on (the lamp pools are how he is hurt) and
## never comes while the boat is sailing or another boss is up (the first round after); a Foreman or a special
## round on his round moves him +1. The horde at 50%.
## Arrival: keys jingle across the whole harbour, positional from everywhere at once; a calm voice from the catwalks
## ("Evening. Don't mind me. I'm only on my rounds."); a lantern lights at the far end of the west catwalk; the title
## card and his bar with the lantern pip.
## The Watch Room (WatchRoom, built once below the map) takes a player at 100 LOGGED; teammates' lantern hits fill
## its release bar. End of Shift spawns the three fuse boxes (a 5 s hold relights their pools).
## Fail-safe: after failsafe_seconds he walks off the quay into the storm; every door he locked opens; the meters
## clear; he returns 5 rounds later at full HP (section 6.6 / 13 D6).
## Death: he sits down and stays, at peace; the rewards: OVERWATCH for the squad (zombies within 12 m outlined in
## violet through walls, at most 24), 2500 Scrip each, the "Night Shift" card, the "Violet Lantern" charm (record
## only, D9), the Archive card and the Watch-Book (INT_HB_04: pages written from this match's events).

const FIRST_SIGHT: Dictionary = {"DUT": "DUT_SLENDER_01", "DEA": "DEA_SLENDER_01", "WRN": "WRN_SLENDER_02"}
const DEAD: Dictionary = {"DUT": "DUT_SLENDER_DEAD_01", "PEG": "PEG_SLENDER_DEAD_01", "DEA": "DEA_SLENDER_DEAD_01", "WRN": "WRN_SLENDER_DEAD_01"}
const CODES: Dictionary = {"dutch": "DUT", "peg": "PEG", "deacon": "DEA", "wren": "WRN", "bolt": "BLT", "vendelin": "VEN"}

var arrival_done: bool = false
var room: WatchRoom = null
var quarantines: int = 0
var fuse_boxes: Array[Node3D] = []
var overwatch: Node = null
var watch_log: Array[String] = []
var jingles: int = 0
var _rewarded: bool = false


func _init() -> void:
	_init_from("bosses/map02", "the_slender")
	name = "SlenderEncounter"


func _ready() -> void:
	super._ready()
	GLBus.weapon_fired.connect(_on_weapon_fired)
	# bound methods (not lambdas): the connections go away with the encounter when the map is freed
	GLBus.player_downed.connect(_log_down)
	GLBus.player_revived.connect(_log_revive)
	GLBus.perk_bought.connect(_log_perk)
	GLBus.door_opened.connect(_log_door)
	GLBus.power_activated.connect(_log_power)


func _log_down(pid: int) -> void:
	_log("Subject %s went down. Noted." % _who(pid))


func _log_revive(pid: int, by: int) -> void:
	_log("Subject %s got %s back on their feet. Good." % [_who(by), _who(pid)])


func _log_perk(pid: int, perk: StringName) -> void:
	_log("Subject %s bought a %s. Receipt kept." % [_who(pid), String(perk).replace("_", " ")])


func _log_door(door: StringName, pid: int) -> void:
	if pid > 0:
		_log("Subject %s opened the way at %s. Door left open. Noted." % [_who(pid), String(door).replace("door_", "")])


func _log_power() -> void:
	_log("Power restored at the pumps. Lights in the pens. Lovely.")


## Round 25 standalone, 45 in the campaign.
static func round_for(c: Dictionary, campaign: bool) -> int:
	return int(c.get("round_campaign", 45)) if campaign else int(c.get("round", 25))


## He may start: the power is on (if he needs it) and no listed flag is up (the boat sailing, another boss).
static func may_start(c: Dictionary, power: bool, flags: Array) -> bool:
	if bool(c.get("needs_power", true)) and not power:
		return false
	for f: Variant in c.get("waits_for_flags", []):
		if flags.has(str(f)):
			return false
	return true


func first_round() -> int:
	return round_for(cfg, Campaign.active)


func can_start(_r: int) -> bool:
	if _force:
		return true
	var up: Array = []
	for f: Variant in cfg.get("waits_for_flags", []):
		if GameState.has_flag(StringName(str(f))):
			up.append(str(f))
	return may_start(cfg, GameState.power_on, up)


func return_round(r: int) -> int:
	return r + int(cfg.get("return_after", 5))


func slender() -> Slender:
	return boss as Slender if boss != null and is_instance_valid(boss) else null


func speaker_label(spk: String) -> String:
	if spk == "SLN":
		return HomageEncounter.title_of("devin", HomageBoss.names_real(), str(cfg.get("fallback_name", "THE SLENDER")))[0]
	return spk


func _code(character: StringName = &"") -> String:
	var c: StringName = character if character != &"" else GameState.character_id
	return str(CODES.get(String(c), "DUT"))


func _who(pid: int) -> String:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.player_id == pid:
			return String(p.character_id).capitalize()
	return "unknown"


## The Watch-Book's night clock: 22:00 at his arrival, a minute a second (it reads like a night watch).
func _log(line: String) -> void:
	if phase != Phase.ACTIVE and not (phase == Phase.CLEARED and not _rewarded):
		return
	var mins: int = 22 * 60 + int(boss_seconds())
	watch_log.append("%02d:%02d - %s" % [(mins / 60) % 24, mins % 60, line])


# ================================================================== the arrival

func _begin() -> void:
	arrival_done = false
	watch_log.clear()
	var a: Dictionary = cfg.get("arrival", {})
	for pt: Variant in a.get("jingle_points", []):
		var v: Vector3 = _v(pt)
		AudioDirector.play_3d("keys_jingle" if AudioDirector.has_sound("keys_jingle") else "shell_ping", v, 0.0, 0.1)
		jingles += 1
	at(float(a.get("voice_at", 1.6)), func() -> void: say("SLN_ARRIVE_01"))
	at(float(a.get("lantern_at", 3.4)), func() -> void: _spawn_slender())
	at(float(a.get("lantern_at", 3.4)) + 1.0, func() -> void: say("OPR_BOSS_SLENDER_01" if randf() < 0.5 else "OPR_BOSS_SLENDER_02"))


func _spawn_slender() -> void:
	var a: Dictionary = cfg.get("arrival", {})
	var s: Slender = Slender.new()
	s.name = "TheSlender"
	adopt(s, HomageEncounter.visit_hp(cfg, RoundManager.players, 0), _snap(_v(a.get("spawn", [-19, 4, 80]))))
	var tl: PackedStringArray = HomageEncounter.title_of("devin", HomageBoss.names_real(), str(cfg.get("fallback_name", "THE SLENDER")))
	if hud != null and is_instance_valid(hud):
		hud.title_card(tl[0], tl[1], "20.XII.1944  ·  U-BOOT-BUNKER TOTENHAFEN")
		hud.add_bar(boss_id, s, tl[0], tl[1])
		hud.add_gauge(boss_id, "lantern")
	arrival_done = true
	spawn_t = t
	var first: String = str(FIRST_SIGHT.get(_code(), ""))
	if first != "":
		later(3.0, first)
	_log("Night watch begins. All quiet. For now.")
	print("[slender] a lantern lights at the end of the west catwalk (hp %d)" % int(s.max_hp))


func boss_seconds() -> float:
	return t - spawn_t if arrival_done else 0.0


## T-233: the capture cameras (CaptureDo `callv:SlenderEncounter:capture_spawn:x,y,z,yaw`): him standing at a point
## outside any round (the capture tool stops the rounds, so summon_boss's start_now would only reserve one): no title
## card, no arrival, no fail-safe clock; he holds the pose (Slender.capture_pose).
func capture_spawn(x: float, y: float, z: float, yaw: float = 0.0) -> void:
	if slender() == null or not slender().is_active():
		var s: Slender = Slender.new()
		s.name = "TheSlender"
		adopt(s, HomageEncounter.visit_hp(cfg, RoundManager.players, 0), Vector3(x, y, z))
		arrival_done = true
	slender().capture_pose(x, y, z, yaw)


func _on_weapon_fired(pid: int, _weapon: StringName, _up: bool, origin: Vector3, _dir: Vector3) -> void:
	var s: Slender = slender()
	if s != null and s.is_active():
		s.on_shot(pid, origin)


# ================================================================== the Watch Room

func _room() -> WatchRoom:
	if room == null or not is_instance_valid(room):
		room = WatchRoom.new()
		room.cfg = cfg.get("quarantine", {})
		_map().add_child(room)
		room.global_position = _v((cfg.get("quarantine", {}) as Dictionary).get("room_at", [16, -60, 58]))
		room.released.connect(_on_room_released)
	return room


func room_busy() -> bool:
	return room != null and is_instance_valid(room) and room.busy()


func in_room(pid: int) -> bool:
	return room_busy() and room.occupant.player_id == pid


## 100 LOGGED: taken in for review (one player at a time; bots never get here).
func quarantine(p: Player) -> void:
	if room_busy() or p == null or p.is_bot or not p.is_alive():
		return
	var r: WatchRoom = _room()
	var s: Slender = slender()
	if s != null and s.meter(p.player_id) != null:
		s.meter(p.player_id).on_quarantined()
	quarantines += 1
	r.take(p, p.global_position, GameState.player_ids.size() <= 1, say)
	say("OPR_BOSS_SLENDER_QUAR_01")
	_log("Subject %s was taken in for review." % _who(p.player_id))


func _on_room_released(pid: int, how: String) -> void:
	var s: Slender = slender()
	if s != null and s.meter(pid) != null:
		s.meter(pid).on_released()
	_log("Subject %s %s" % [_who(pid), "found their page. Excused." if how != "fail" else "did not find their page. Noted."])
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.player_id == pid and p.is_local:
			later(1.5, "%s_QUARANTINE_01" % _code(p.character_id))


func on_lantern_hit(by_player: int) -> void:
	if room_busy() and room.occupant.player_id != by_player:
		room.lantern_hit()


func on_smoke_hit() -> void:
	if _code() == "PEG":
		say("PEG_SLENDER_01")


func on_shift_change() -> void:
	later(0.8, "OPR_BOSS_SLENDER_03")
	if _code() == "PEG":
		later(2.5, "PEG_SLENDER_02")


## End of Shift: the Operator, and the three fuse boxes (a 5 s hold relights their pools).
func on_end_of_shift() -> void:
	later(1.0, "OPR_BOSS_SLENDER_04")
	var hold: float = float(((cfg.get("moves", {}) as Dictionary).get("end_of_shift", {}) as Dictionary).get("lever_hold", 5.0))
	for lv: Variant in (cfg.get("lights", {}) as Dictionary).get("levers", []):
		var spec: Dictionary = lv
		var f: SlenderFuseBox = SlenderFuseBox.new()
		f.enc = self
		f.pools = spec.get("pools", [])
		f.hold_s = hold
		f.name = "SlenderFuseBox%d" % fuse_boxes.size()
		_map().add_child(f)
		f.global_position = _snap(_v(spec.get("at", [0, 0, 0])))
		fuse_boxes.append(f)


func relight(pools: Array) -> void:
	var s: Slender = slender()
	if s != null:
		s.relight_pools(pools)


# ================================================================== leave, death, rewards

func _on_leave() -> void:
	say("SLN_LEAVE_01")
	later(2.5, "OPR_BOSS_SLENDER_LEFT_01")
	if room_busy():
		room._let_go("released")
	var s: Slender = slender()
	if s != null:
		for m: Variant in s.meters.values():
			(m as WatchMeter).clear()
	_clear_fuse_boxes()


func _clear_fuse_boxes() -> void:
	for f: Node3D in fuse_boxes:
		if is_instance_valid(f):
			f.queue_free()
	fuse_boxes.clear()


func _on_boss_died() -> void:
	print("[slender] the watch ends")
	if hud != null and is_instance_valid(hud):
		hud.strike(boss_id, true)
	if room_busy():
		room._let_go("released")
	_clear_fuse_boxes()
	GameState.set_flag(StringName(str((cfg.get("rewards", {}) as Dictionary).get("flag", "slender_relieved"))), true)
	get_tree().create_timer(12.0).timeout.connect(_grant)


## He sat down: the Operator, the squad, the rewards.
func on_slender_sat(_at_pos: Vector3) -> void:
	later(1.5, "OPR_BOSS_SLENDER_DEAD_01")
	later(4.5, str(DEAD.get(_code(), "DUT_SLENDER_DEAD_01")))
	_grant()


func _grant() -> void:
	if _rewarded:
		return
	_log("Shift ended. Relieved by: %s. Nothing further to report." % _squad_names())
	_rewarded = true
	var plan: Dictionary = HomageEncounter.reward_plan(cfg, GameState.player_ids)
	ProfileSave.profile["watch_book"] = watch_log.duplicate()
	grant_plan(plan)
	_start_overwatch()
	print("[slender] rewards: %d Scrip each, unlocks %s, intel %s, OVERWATCH on, the Watch-Book has %d pages" % [int((cfg.get("rewards", {}) as Dictionary).get("scrip_per_player", 2500)),
		str(plan["unlocks"]), str(plan["intel"]), watch_log.size()])


func _squad_names() -> String:
	var out: PackedStringArray = []
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null:
			out.append(String(p.character_id).capitalize())
	return ", ".join(out)


## OVERWATCH: zombies within 12 m of any player are outlined in faint violet through walls (at most 24).
func _start_overwatch() -> void:
	if overwatch != null and is_instance_valid(overwatch):
		return
	var o: OverwatchOutline = OverwatchOutline.new()
	o.director = director
	o.radius = float((cfg.get("rewards", {}) as Dictionary).get("overwatch_m", 12.0))
	o.max_n = int((cfg.get("rewards", {}) as Dictionary).get("overwatch_max", 24))
	o.name = "Overwatch"
	_map().add_child(o)
	overwatch = o
	GameState.set_flag(&"overwatch", true)


func _v(a: Variant) -> Vector3:
	var arr: Array = a as Array
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2])) if arr != null and arr.size() >= 3 else Vector3.ZERO


func _snap(p: Vector3) -> Vector3:
	var w: World3D = get_world_3d()
	if w == null:
		return p
	var c: Vector3 = NavigationServer3D.map_get_closest_point(w.navigation_map, p)
	return c if c.distance_to(p) < 3.0 else p


## A fuse box for End of Shift (hold 5 s: its pools light again).
class SlenderFuseBox extends Interactable:
	var enc: SlenderEncounter
	var pools: Array = []
	var hold_s: float = 5.0
	var done: bool = false

	func build_greybox() -> void:
		interact_size = Vector3(1.0, 1.6, 0.8)
		var mi: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(0.5, 0.7, 0.25)
		mi.mesh = bm
		mi.material_override = HomageBoss.mat(Color(0.3, 0.32, 0.3))
		mi.position = Vector3(0, 1.3, 0)
		add_child(mi)
		var lamp: OmniLight3D = OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.3, 0.2)
		lamp.omni_range = 1.5
		lamp.light_energy = 0.8
		lamp.shadow_enabled = false
		lamp.position = Vector3(0, 1.75, -0.2)
		lamp.name = "Lamp"
		add_child(lamp)

	func hold_time(_player: Player) -> float:
		return hold_s

	func get_prompt(_player: Player) -> String:
		return "" if done else "Hold [%s] to throw the floodlight fuses" % prompt_key(&"interact")

	func can_interact(_player: Player) -> bool:
		return not done

	func interact(_player: Player) -> void:
		throw_fuses()

	func throw_fuses() -> void:
		if done:
			return
		done = true
		var l: OmniLight3D = get_node_or_null("Lamp") as OmniLight3D
		if l != null:
			l.light_color = Color(0.4, 1.0, 0.4)
		if enc != null:
			enc.relight(pools)
		print("[slender] fuses thrown: %d pools light again" % pools.size())


## The OVERWATCH reward's outline (a depth-ignoring violet rim overlay on the nearest zombies' bodies).
class OverwatchOutline extends Node:
	var director: ZombieDirector
	var radius: float = 12.0
	var max_n: int = 24
	var outlined: Array = []
	var _t: float = 0.0
	static var _mat: ShaderMaterial = null

	static func overlay() -> ShaderMaterial:
		if _mat == null:
			var sh: Shader = Shader.new()
			sh.code = "shader_type spatial;\nrender_mode unshaded, depth_test_disabled, cull_back, blend_add;\nuniform vec4 tint : source_color = vec4(0.7, 0.35, 1.0, 1.0);\nuniform float strength = 0.45;\nvoid fragment() {\n\tfloat rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);\n\tALBEDO = tint.rgb;\n\tALPHA = rim * strength;\n}\n"
			_mat = ShaderMaterial.new()
			_mat.shader = sh
		return _mat

	func _process(delta: float) -> void:
		_t -= delta
		if _t > 0.0 or director == null or not is_instance_valid(director):
			return
		_t = 0.25
		var strength: float = 0.25 if bool(GLSettings.values.get("reduce_screen_effects", false)) else 0.45
		overlay().set_shader_parameter("strength", strength)
		var near: Array = []
		var players: Array = get_tree().get_nodes_in_group(&"players")
		for z: Zombie in director.active_zombies():
			if z is HomageBoss:
				continue
			for n: Node in players:
				var p: Node3D = n as Node3D
				if p != null and p.global_position.distance_to(z.global_position) <= radius:
					near.append(z)
					break
			if near.size() >= max_n:
				break
		for z2: Variant in outlined:
			if is_instance_valid(z2) and not near.has(z2):
				var bm: MeshInstance3D = (z2 as Zombie).body_mesh()
				if bm != null:
					bm.material_overlay = null
		for z3: Variant in near:
			var bm2: MeshInstance3D = (z3 as Zombie).body_mesh()
			if bm2 != null:
				bm2.material_overlay = overlay()
		outlined = near
