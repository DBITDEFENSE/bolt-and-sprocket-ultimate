class_name PaulEncounter
extends HomageEncounter
## PAUL's round on Kaltenbrunn (HB2, docs/HOMAGE_BOSSES.md sections 5.2-5.7; DECISIONS T-159). Created by the
## ZombieDirector on map01 (host / solo) when bosses/map01.json has the paul block.
## Round 15 (reserved: the Foreman and a Bellringer round move off it; if one still sits on it he moves +1), the
## horde at 60%.
## Arrival: the whole headframe shakes (dust, the girders jitter, every player's view shakes), "WHERE'S MY SQUAD?!"
## over the PA from Fasbender's torn-up radio room (its door lies on the floor, cosmetic; the egg's objects are
## untouched), the Operator, then he leaps down from the head platform and lands in a crater that knocks every player
## within 10 m down for 0.8 s (no damage) and leaves a cracked-concrete decal for the match; the title card.
## Fail-safe (section 13 D5): if he isn't killed within 6:00 he roars, climbs the headframe and leaps away north; he
## is back 8-10 rounds later with +35% HP per return and all six bottles regrown, until he is beaten.
## Death: the twist plays (Paul._death_tick), then the rewards: one PAUL'S LAST ROUND bottle per player at his body
## (free Ironhide without a perk slot until downed, or +100 overshield if you have it), 2000 Scrip each, a Double
## Scrip drop, the "Carried My Share" card, the Archive card and his two documents, the tin cup to the player he
## gave it to. He is gone for the match: the death is never undone.

const FIRST_SIGHT: Dictionary = {"DUT": "DUT_PAUL_02", "PEG": "PEG_PAUL_01", "DEA": "DEA_PAUL_01", "WRN": "WRN_PAUL_01"}
const RAGE_SEEN: Dictionary = {"DUT": "DUT_PAUL_RAGE_01", "PEG": "PEG_PAUL_02", "WRN": "WRN_PAUL_02", "DEA": "DEA_PAUL_02"}
const DEAD: Dictionary = {"DUT": "DUT_PAUL_DEAD_01", "PEG": "PEG_PAUL_DEAD_01", "DEA": "DEA_PAUL_PRAYER_01", "WRN": "WRN_PAUL_NAME_01"}
const CUP: Dictionary = {"DUT": "DUT_PAUL_CUP_01", "PEG": "PEG_PAUL_CUP_01", "DEA": "DEA_PAUL_CUP_01", "WRN": "WRN_PAUL_CUP_01"}

var arrival_done: bool = false
var craters: Array[Node3D] = []
var knocked: Array[int] = []
var cup_holder: int = -1
var bottles_spawned: Array[Node3D] = []
var berserk_said: bool = false
var angry_said: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _shaking: Array = []              # [Node3D, base position]
var _shake_left: float = 0.0
var _rewarded: bool = false


func _init() -> void:
	_init_from("bosses/map01", "paul")
	name = "PaulEncounter"
	_rng.randomize()


## 8-10 rounds after he left (seeded for the tests by `roll`).
static func return_round_for(r: int, c: Dictionary, roll: int) -> int:
	var lo: int = int(c.get("return_after_min", 8))
	var hi: int = int(c.get("return_after_max", 10))
	return r + lo + (absi(roll) % maxi(1, hi - lo + 1))


func return_round(r: int) -> int:
	return return_round_for(r, cfg, _rng.randi())


func paul() -> Paul:
	return boss as Paul if boss != null and is_instance_valid(boss) else null


func speaker_label(spk: String) -> String:
	if spk == "PAU":
		return HomageEncounter.title_of("paul", HomageBoss.names_real(), str(cfg.get("fallback_name", "PAUL")))[0]
	return spk


func _code() -> String:
	return str({"dutch": "DUT", "peg": "PEG", "deacon": "DEA", "wren": "WRN", "bolt": "BLT", "vendelin": "VEN"}.get(String(GameState.character_id), "DUT"))


func _squad(table: Dictionary) -> void:
	var id: String = str(table.get(_code(), ""))
	if id != "":
		say(id)


# ================================================================== the arrival

func _begin() -> void:
	var a: Dictionary = cfg.get("arrival", {})
	arrival_done = false
	var returning: bool = visits > 0
	_shake_headframe(float(a.get("shake_s", 3.0)))
	if not returning:
		_torn_radio_door(_v(a.get("radio_room_door", [-9, 3.8, 16.2])))
		at(float(a.get("pa_at", 0.6)), func() -> void: say("PAU_PA_01"))
		at(float(a.get("pa_at", 0.6)) + 2.2, func() -> void:
			if _code() == "DUT":
				say("DUT_PAUL_01"))
		at(float(a.get("opr_at", 3.0)), func() -> void: say("OPR_BOSS_PAUL_01" if _rng.randf() < 0.5 else "OPR_BOSS_PAUL_02"))
	else:
		at(0.4, func() -> void: say("OPR_BOSS_PAUL_03"))
		at(1.0, func() -> void: say("PAU_PA_01"))
	at(float(a.get("leap_at", 3.6)), func() -> void: _spawn_paul())


func _spawn_paul() -> void:
	var a: Dictionary = cfg.get("arrival", {})
	var ar: Dictionary = cfg.get("arena", {})
	var top: Vector3 = _v(ar.get("headframe", [20, 0, 15])) + Vector3.UP * float(ar.get("headframe_height", 27.4))
	var land: Vector3 = _snap(_v(a.get("land_point", [20, 0, 26])))
	var p: Paul = Paul.new()
	p.name = "Paul"
	adopt(p, HomageEncounter.visit_hp(cfg, RoundManager.players, visits), land)
	p.arrive_leap(top, land, float(a.get("leap_s", 1.1)))
	print("[paul] leaps from the headframe (visit %d, hp %d, bottles %d)" % [visits, int(p.max_hp), p.bottles_left()])


## Paul landed from the headframe (the arrival): the crater, the knockdown, the title card.
func on_arrived(at_pos: Vector3) -> void:
	var a: Dictionary = cfg.get("arrival", {})
	crater(at_pos, true)
	say("PAU_LAND_01")
	var tl: PackedStringArray = HomageEncounter.title_of("paul", HomageBoss.names_real(), str(cfg.get("fallback_name", "PAUL")))
	if hud != null and is_instance_valid(hud):
		hud.title_card(tl[0], tl[1], "20.XII.1944  ·  ZECHE KALTENBRUNN")
		hud.add_bar(boss_id, boss, tl[0], tl[1])
		hud.add_gauge(boss_id, "bottle")
	arrival_done = true
	spawn_t = t
	later(2.5, str(FIRST_SIGHT.get(_code(), "DUT_PAUL_02")))
	print("[paul] lands at %s: crater, %d knocked down" % [str(at_pos.snapped(Vector3.ONE * 0.1)), knocked.size()])


## The fail-safe's clock runs from the landing.
func boss_seconds() -> float:
	return t - spawn_t if arrival_done else 0.0


func on_paul_stage(to: int) -> void:
	if to == PaulRage.ANGRY and not angry_said:
		angry_said = true
		_squad(RAGE_SEEN)
	elif to == PaulRage.BERSERK and not berserk_said:
		berserk_said = true
		later(1.2, "OPR_BOSS_PAUL_RAGE_01")


func on_bottle_broken(n: int) -> void:
	if n == 1 and _code() == "DEA":
		later(1.0, "DEA_PAUL_02")


# ================================================================== the set pieces

## A cracked-concrete crater (kept for the match); `knock`: every player within the radius goes down for 0.8 s.
func crater(at_pos: Vector3, knock: bool) -> void:
	var a: Dictionary = cfg.get("arrival", {})
	var root: Node3D = Node3D.new()
	root.name = "PaulCrater%d" % craters.size()
	_map().add_child(root)
	root.global_position = at_pos + Vector3.UP * 0.03
	var disc: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 2.6
	cm.bottom_radius = 2.6
	cm.height = 0.02
	cm.radial_segments = 20
	disc.mesh = cm
	disc.material_override = HomageBoss.mat(Color(0.12, 0.11, 0.1))
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(disc)
	for i: int in 9:
		var crack: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(0.12, 0.025, 1.6 + 0.5 * float(i % 3))
		crack.mesh = bm
		crack.material_override = HomageBoss.mat(Color(0.07, 0.065, 0.06))
		var ang: float = TAU * float(i) / 9.0 + 0.3 * float(i % 2)
		crack.position = Vector3(sin(ang), 0.005, cos(ang)) * 3.0
		crack.rotation.y = ang
		crack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(crack)
	for j: int in 6:
		var rock: MeshInstance3D = MeshInstance3D.new()
		var rb: BoxMesh = BoxMesh.new()
		rb.size = Vector3(0.35, 0.18, 0.28)
		rock.mesh = rb
		rock.material_override = HomageBoss.mat(Color(0.42, 0.4, 0.38))
		var ra: float = TAU * float(j) / 6.0
		rock.position = Vector3(sin(ra), 0.08, cos(ra)) * 2.4
		rock.rotation = Vector3(0.3, ra, 0.2)
		root.add_child(rock)
	craters.append(root)
	AudioDirector.play_3d("explosion_small" if AudioDirector.has_sound("explosion_small") else "impact_flesh", at_pos + Vector3.UP, 8.0, 0.0)
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not p.is_alive():
			continue
		var d: float = p.global_position.distance_to(at_pos)
		if d < 30.0:
			p.set("_shake", maxf(float(p.get("_shake")), 0.9 * (1.0 - d / 30.0)))
		if knock and d <= float(a.get("knockdown_radius", 10.0)):
			p.apply_status(&"knockdown", float(a.get("knockdown_s", 0.8)))
			var push: Vector3 = p.global_position - at_pos
			push.y = 0.0
			if push.length() > 0.1:
				p.apply_knockback(push.normalized() * 3.0)
			if not knocked.has(p.player_id):
				knocked.append(p.player_id)


## The whole headframe shakes: dust off the girders, every tower piece jittering, the players' views shaking.
func _shake_headframe(seconds: float) -> void:
	_shaking.clear()
	var m: Node = _map()
	if m == null:
		return
	for n: Node in m.find_children("Tower*", "Node3D", true, false):
		_shaking.append([n, (n as Node3D).position])
	for n2: Node in m.find_children("*Headframe*", "Node3D", true, false):
		_shaking.append([n2, (n2 as Node3D).position])
	_shake_left = seconds
	var ar: Dictionary = cfg.get("arena", {})
	var hf: Vector3 = _v(ar.get("headframe", [20, 0, 15]))
	AudioDirector.play_3d("door_creak", hf + Vector3.UP * 10.0, 6.0, 0.0)
	var dust: GPUParticles3D = GPUParticles3D.new()
	dust.amount = 60
	dust.lifetime = 2.2
	dust.one_shot = true
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(4.5, 10.0, 4.5)
	pm.gravity = Vector3(0, -3.0, 0)
	pm.scale_min = 0.4
	pm.scale_max = 0.9
	dust.process_material = pm
	var qm: QuadMesh = QuadMesh.new()
	qm.size = Vector2(0.4, 0.4)
	var sm: StandardMaterial3D = StandardMaterial3D.new()
	sm.albedo_color = Color(0.55, 0.5, 0.45, 0.4)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.material = sm
	dust.draw_pass_1 = qm
	m.add_child(dust)
	dust.global_position = hf + Vector3.UP * 16.0
	dust.emitting = true
	get_tree().create_timer(4.0).timeout.connect(dust.queue_free)


func _tick(delta: float) -> void:
	if _shake_left > 0.0:
		_shake_left -= delta
		for e: Array in _shaking:
			var n: Node3D = e[0]
			if is_instance_valid(n):
				n.position = (e[1] as Vector3) + (Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 0.06 if _shake_left > 0.0 else Vector3.ZERO)
		for n3: Node in get_tree().get_nodes_in_group(&"players"):
			var p: Player = n3 as Player
			if p != null and p.is_alive():
				p.set("_shake", maxf(float(p.get("_shake")), 0.25))


## Fasbender's radio room: he ripped through it; its door lies on the floor (cosmetic: the egg's objects stay).
func _torn_radio_door(at_pos: Vector3) -> void:
	var m: Node = _map()
	if m == null or m.get_node_or_null("PaulTornDoor") != null:
		return
	var door: MeshInstance3D = MeshInstance3D.new()
	door.name = "PaulTornDoor"
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(1.5, 0.06, 2.3)
	door.mesh = bm
	door.material_override = HomageBoss.mat(Color(0.33, 0.24, 0.15))
	m.add_child(door)
	door.global_position = at_pos + Vector3(0, 0.05, 1.0)
	door.rotation = Vector3(0, 0.35, 0.05)


# ================================================================== the death, the twist, the rewards

func _on_boss_died() -> void:
	print("[paul] down: the twist plays")
	if hud != null and is_instance_valid(hud):
		hud.strike(boss_id, true)
	GameState.set_flag(StringName(str((cfg.get("rewards", {}) as Dictionary).get("flag", "paul_down"))), true)
	# safety: the rewards come after the fall; if the body never gets there (freed), grant them anyway
	get_tree().create_timer(14.0).timeout.connect(func() -> void:
		if not _rewarded:
			_grant(boss.global_position if boss != null and is_instance_valid(boss) else Vector3.ZERO, false))


## He pressed the crushed tin cup into this player's hand.
func on_cup_given(pid: int) -> void:
	cup_holder = pid
	var code: String = _code()
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.player_id == pid:
			code = str({"dutch": "DUT", "peg": "PEG", "deacon": "DEA", "wren": "WRN", "bolt": "BLT", "vendelin": "VEN"}.get(String(p.character_id), "DUT"))
			p.set_meta("tin_cup", true)
	later(2.0, str(CUP.get(code, "DUT_PAUL_CUP_01")))


## He fell forward, like a tree going down: the trumpet, the Operator's quiet line, the squad, the rewards.
func on_paul_fallen(at_pos: Vector3) -> void:
	if AudioDirector.has_sound("bugle_phrase"):
		AudioDirector.play_2d("bugle_phrase", 0.0)
	later(3.0, "OPR_BOSS_PAUL_DEAD_01")
	later(6.5, str(DEAD.get(_code(), "DUT_PAUL_DEAD_01")))
	_grant(at_pos, true)


func _grant(at_pos: Vector3, spawn_drops: bool) -> void:
	if _rewarded:
		return
	_rewarded = true
	var plan: Dictionary = HomageEncounter.reward_plan(cfg, GameState.player_ids)
	grant_plan(plan)
	if spawn_drops and at_pos != Vector3.ZERO:
		var i: int = 0
		for d: Variant in plan["drops"]:
			PowerupManager.spawn(StringName(str(d)), at_pos + Vector3(1.6 + 0.8 * float(i), 0, 1.2))
			i += 1
	_spawn_last_rounds(at_pos)
	print("[paul] rewards: %d Scrip each, drops %s, unlocks %s, intel %s, %d bottles of PAUL'S LAST ROUND" % [int((cfg.get("rewards", {}) as Dictionary).get("scrip_per_player", 2000)),
		str(plan["drops"]), str(plan["unlocks"]), str(plan["intel"]), bottles_spawned.size()])


## One battered Ironhide bottle per player at his body (section 13 D7: Paul wouldn't leave anybody out).
func _spawn_last_rounds(at_pos: Vector3) -> void:
	var n: int = 0
	for pid: int in GameState.player_ids:
		var b: PaulsLastRound = PaulsLastRound.new()
		b.for_player = pid
		b.overshield = float((cfg.get("rewards", {}) as Dictionary).get("last_round_overshield", 100))
		b.name = "PaulsLastRound_%d" % pid
		_map().add_child(b)
		b.global_position = at_pos + Vector3(-1.2 + 0.8 * float(n), 0, -1.0)
		bottles_spawned.append(b)
		n += 1


# ================================================================== helpers

func _v(a: Variant) -> Vector3:
	var arr: Array = a as Array
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2])) if arr != null and arr.size() >= 3 else Vector3.ZERO


func _snap(p: Vector3) -> Vector3:
	var w: World3D = get_world_3d()
	if w == null:
		return p
	var c: Vector3 = NavigationServer3D.map_get_closest_point(w.navigation_map, p)
	return c if c.distance_to(p) < 3.0 else p
