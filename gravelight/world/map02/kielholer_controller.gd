class_name KielholerController
extends Node
## The drowned of Totenhafen (UPDATE 10 contract C2 "Kielholer", C5; DECISIONS T-153). Attached by Totenhafen (a
## node under MapRoot/Totenhafen with a fixed name, so Net.mirror paths match on every peer).
##
## - The surface points: ZombieSpawns `Surface_<i>` at map02.json "kielholer".surface_points (the pier edges; emerge
##   style "water" by the anim.json name prefix), live only while the GameState flag `flooded` is on.
## - Tagging (authority): a Ganger that rises at a surface point, plus `surface_share` of the Pen Hall's spawns while
##   flooded, becomes a Kielholer (kit drowned) or, `diver_share` of them, a Kielholer diver (kit drowned_diver),
##   never more than max_active at once (max_active_spring on a spring tide). enemies.json kielholer / _diver.
## - The grab: a Kielholer within grab_range of a player takes hold and pulls him toward the nearest water edge
##   (EDGES: the pier and apron edges over the dock basins) at pull_mps; the held player wades (status
##   kielholer_grab), takes hold_dps (edge_dps within edge_m of the edge, never an instant kill); it lets go to the
##   held player's melee, arm_break_damage on its arm_grab hitbox from anyone, team_break_damage from teammates
##   (half weight off the arm), or max_hold; then nobody is re-grabbed by it for regrab_lock (HOMAGE_BOSSES 3.6).
## - The diver's helmet: the helmet_glass hitbox and the head soak hits (helmet_mult) until helmet_break_fraction of
##   its max HP has gone into the helmet; the glass breaks and the violet glow behind it (a Marke in the helmet, U09
##   C1: the hand mark is cleared) takes glow_mult.
## - DER KIELHOLER standalone (bosses/map02.json round, campaign_round) when the Homage Bosses setting is on and the
##   egg has not brought him; the bots-alone scaling for whichever Kielholer boss is up; the ignition key (BoatKey).
## Co-op: the host tags, grabs and summons; a client sees Ganger puppets (the drowned look is host-side, T-153).

## The water edges a grab pulls toward: [a, b] segments on the pier / apron edges over the dock basins (gen_map02's
## railings Rail_P0E, P1W, P1E, P2W, P2E, AEW and the north apron's N1..N3), y 0.
const EDGES: Array = [
	[Vector3(-14, 0, 38), Vector3(-14, 0, 84)], [Vector3(-6, 0, 38), Vector3(-6, 0, 84)], [Vector3(0, 0, 38), Vector3(0, 0, 84)],
	[Vector3(14, 0, 38), Vector3(14, 0, 84)], [Vector3(20, 0, 38), Vector3(20, 0, 84)], [Vector3(32, 0, 38), Vector3(32, 0, 84)],
	[Vector3(-14, 0, 38), Vector3(-6, 0, 38)], [Vector3(0, 0, 38), Vector3(14, 0, 38)], [Vector3(20, 0, 38), Vector3(32, 0, 38)],
]
const KINDS: Array[String] = ["kielholer", "kielholer_diver"]

var t: Node = null              # the Totenhafen node (typed loosely: unit tests build the controller alone)
var cfg: Dictionary = {}        # map02.json "kielholer"
var spawns: Array[ZombieSpawn] = []
var tagged: Dictionary = {}     # Zombie -> state dict
var counts: Dictionary = {}     # kind -> tagged this match
var grabs_started: int = 0
var grabs_broken: Dictionary = {}   # reason -> count
var helmets_broken: int = 0
var boss: HomageBoss = null
var boss_summoned: bool = false
var boss_round: int = 0
var bots_alone: bool = false
var _no_human_t: float = 0.0
var _human_t: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


static func attach(tn: Node) -> void:
	var c: KielholerController = KielholerController.new()
	c.name = "KielholerController"
	tn.add_child(c)
	c.setup(tn)


static func of(tree: SceneTree) -> KielholerController:
	return tree.get_first_node_in_group(&"kielholer_controller") as KielholerController


static func ecfg(kind: String) -> Dictionary:
	return (GLData.table("enemies")["enemies"] as Dictionary).get(kind, {})


static func boss_table() -> Dictionary:
	return GLData.table("bosses/map02")


func setup(tn: Node) -> void:
	add_to_group(&"kielholer_controller")
	t = tn
	var all: Dictionary = tn.get("cfg") if tn != null and tn.get("cfg") is Dictionary else GLData.load_json("res://data/gravelight/map02.json")
	cfg = all.get("kielholer", {})
	_rng.seed = hash("kielholer_%d" % Time.get_ticks_usec())
	var i: int = 0
	for p: Variant in cfg.get("surface_points", []):
		var a: Array = p
		var sp: ZombieSpawn = ZombieSpawn.new()
		sp.zone_id = StringName(str(cfg.get("zone", "D_PENHALL")))
		sp.kind = &"ground"
		sp.min_round = 1
		sp.enabled = GameState.has_flag(&"flooded")
		sp.set_meta("surface", "water")
		if tn != null and tn.has_method(&"place"):
			tn.call(&"place", sp, "Surface_%d" % i, a)
		else:
			sp.name = "Surface_%d" % i
			sp.position = Vector3(float(a[0]), float(a[1]), float(a[2]))
			add_child(sp)
		spawns.append(sp)
		i += 1
	GLBus.flag_changed.connect(_on_flag_changed)
	GLBus.tide_flood_begin.connect(func() -> void: set_surface(true))
	GLBus.tide_flood_end.connect(func() -> void: set_surface(false))
	GLBus.enemy_spawned.connect(_on_enemy_spawned)
	GLBus.round_started.connect(_on_round_started)
	GLBus.boss_spawned.connect(_on_boss_spawned)
	boss_round = standalone_round(boss_table(), Campaign.active)
	if boss_round > 0 and HomageBoss.homage_on() and Net.is_authority():
		RoundManager.reserve_round(boss_round)


# ================================================================== pure rules (unit-tested)

## Should this fresh Ganger become a Kielholer? Surface risers always (while flooded and under the cap); a Pen Hall
## riser by `share`; nothing while dry.
static func should_tag(from_surface: bool, in_zone: bool, flooded: bool, roll: float, active: int, cap: int, share: float) -> bool:
	if not flooded or active >= cap:
		return false
	if from_surface:
		return true
	return in_zone and roll < share


static func kind_for(roll: float, diver_share: float) -> String:
	return "kielholer_diver" if roll < diver_share else "kielholer"


static func cap_for(stage: StringName, c: Dictionary) -> int:
	return int(c.get("max_active_spring", 10)) if stage == &"spring" else int(c.get("max_active", 6))


## The standalone round (0 = none).
static func standalone_round(table: Dictionary, campaign: bool) -> int:
	return int(table.get("campaign_round", 40)) if campaign else int(table.get("round", 20))


## The nearest point on the water edges to `p` (flat; y 0).
static func edge_point(p: Vector3) -> Vector3:
	var best: Vector3 = Vector3(p.x, 0.0, 38.0)
	var bd: float = INF
	for e: Array in EDGES:
		var a: Vector3 = e[0]
		var b: Vector3 = e[1]
		var ab: Vector3 = b - a
		var tt: float = clampf((Vector3(p.x, 0, p.z) - a).dot(ab) / maxf(0.0001, ab.length_squared()), 0.0, 1.0)
		var q: Vector3 = a + ab * tt
		var d: float = Vector2(q.x - p.x, q.z - p.z).length()
		if d < bd:
			bd = d
			best = q
	return best


static func edge_distance(p: Vector3) -> float:
	var q: Vector3 = edge_point(p)
	return Vector2(q.x - p.x, q.z - p.z).length()


## Damage per second for a held player `edge_d` metres from the edge.
static func hold_dps(edge_d: float, c: Dictionary) -> float:
	return float(c.get("edge_dps", 16.0)) if edge_d <= float(c.get("edge_m", 1.6)) else float(c.get("hold_dps", 6.0))


## A grab's counters after one hit on the grabber (mutates `st`): the held player's melee, damage to arm_grab from
## anyone, teammates' damage (full on the arm, half elsewhere).
static func grab_hit(st: Dictionary, amount: float, limb: StringName, by_player: int, kind: StringName) -> void:
	var held: int = int(st.get("pid", 0))
	if held == 0:
		return
	if by_player == held and kind == &"melee":
		st["melee"] = int(st.get("melee", 0)) + 1
	if limb == &"arm_grab":
		st["arm"] = float(st.get("arm", 0.0)) + amount
	if by_player > 0 and by_player != held:
		st["team"] = float(st.get("team", 0.0)) + (amount if limb == &"arm_grab" else amount * 0.5)


## Why a grab ends now ("" = it holds): melee | arm | team | time.
static func grab_breaks(st: Dictionary, c: Dictionary) -> String:
	if int(st.get("melee", 0)) >= 1:
		return "melee"
	if float(st.get("arm", 0.0)) >= float(c.get("arm_break_damage", 60.0)):
		return "arm"
	if float(st.get("team", 0.0)) >= float(c.get("team_break_damage", 150.0)):
		return "team"
	if float(st.get("t", 0.0)) >= float(c.get("max_hold", 6.0)):
		return "time"
	return ""


## Raw damage the helmet must soak before the glass goes (the diver's max HP x helmet_break_fraction).
static func helmet_threshold(max_hp: float, c: Dictionary) -> float:
	return max_hp * float(c.get("helmet_break_fraction", 0.3))


# ================================================================== the surface points

func set_surface(on: bool) -> void:
	for sp: ZombieSpawn in spawns:
		if is_instance_valid(sp):
			sp.enabled = on


func _on_flag_changed(flag: StringName, value: Variant) -> void:
	if flag == &"flooded":
		set_surface(bool(value))


func _stage() -> StringName:
	var tide: Node = get_tree().get_first_node_in_group(&"tide")
	return StringName(str(tide.get("stage"))) if tide != null and tide.get("stage") != null else &"low"


func _from_surface(z: Zombie) -> bool:
	for sp: ZombieSpawn in spawns:
		if is_instance_valid(sp) and Vector2(sp.global_position.x - z.global_position.x, sp.global_position.z - z.global_position.z).length() < 3.5 \
				and absf(sp.global_position.y - z.global_position.y) < 2.0:
			return true
	return false


func active_count() -> int:
	var n: int = 0
	for z: Variant in tagged.keys():
		if is_instance_valid(z) and (z as Zombie).is_active():
			n += 1
	return n


# ================================================================== tagging

func _on_enemy_spawned(enemy_id: StringName, node_id: int) -> void:
	if not Net.is_authority() or enemy_id != &"ganger":
		return
	var z: Zombie = instance_from_id(node_id) as Zombie
	if z == null or z is HomageBoss or tagged.has(z) or z.puppet:
		return
	var zone: StringName = ZoneVolume.zone_at(get_tree(), z.global_position)
	var ok: bool = should_tag(_from_surface(z), zone == StringName(str(cfg.get("zone", "D_PENHALL"))), GameState.has_flag(&"flooded"),
		_rng.randf(), active_count(), cap_for(_stage(), cfg), float(cfg.get("surface_share", 0.35)))
	if ok:
		make(kind_for(_rng.randf(), float(cfg.get("diver_share", 0.25))), z)


## Turns a live Ganger into a Kielholer (the spawn hook, the console and the smoke).
func make(kind: String, z: Zombie) -> void:
	if z == null or not is_instance_valid(z) or tagged.has(z):
		return
	var e: Dictionary = ecfg(kind)
	var st: Dictionary = {"z": z, "kind": kind, "pid": 0, "t": 0.0, "melee": 0, "arm": 0.0, "team": 0.0, "cd": 1.0,
		"regrab": {}, "dmg_acc": 0.0, "dmg_t": 0.0, "helmet": 0.0, "helmet_broken": false, "nodes": []}
	tagged[z] = st
	counts[kind] = int(counts.get(kind, 0)) + 1
	z.set_meta("kielholer", kind)
	z.call("_apply_variant", str(e.get("kit", "drowned")))
	z.max_hp *= float(e.get("health_mult", 1.2))
	z.hp = z.max_hp
	var gc: Dictionary = ecfg("kielholer")
	# the arm the grab is made with (a slightly larger box round the right forearm: rays meet it first)
	var arm: Hitbox = Hitbox.new()
	arm.name = "ArmGrab"
	var asz: Array = gc.get("arm_hitbox", [0.17, 0.46, 0.17])
	arm.setup(z, &"arm_grab", Vector3(float(asz[0]), float(asz[1]), float(asz[2])))
	arm.bone = "RightLowerArm"
	arm.position = Vector3(0, -0.2, -0.01)
	var at: Node3D = z.bone_attachment("RightLowerArm")
	(at if at != null else z).add_child(arm)
	(st["nodes"] as Array).append(arm)
	if kind == "kielholer_diver":
		z.clear_marke()
		var hm: float = float(e.get("helmet_mult", 0.5))
		z.set_meta(&"limb_mults", {"head": hm, "helmet_glass": hm})
		var head: Node3D = z.bone_attachment("Head")
		var hb: Hitbox = Hitbox.new()
		hb.name = "HelmetGlass"
		var hsz: Array = e.get("helmet_hitbox", [0.22, 0.22, 0.1])
		hb.setup(z, &"helmet_glass", Vector3(float(hsz[0]), float(hsz[1]), float(hsz[2])))
		hb.bone = "Head"
		hb.position = Vector3(0, 0.12, -0.2)
		(head if head != null else z).add_child(hb)
		(st["nodes"] as Array).append(hb)
		var glow: Node3D = _glow_node()
		glow.visible = false
		(head if head != null else z).add_child(glow)
		(st["nodes"] as Array).append(glow)
		st["glow"] = glow
	z.damaged.connect(_on_zombie_damaged.bind(z))


## The violet glow behind a broken helmet glass.
static func _glow_node() -> Node3D:
	var g: Node3D = Node3D.new()
	g.name = "HelmetGlow"
	g.position = Vector3(0, 0.12, -0.215)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	mi.mesh = sm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = ZombieBody.MARKE_COLOR
	m.emission_enabled = true
	m.emission = ZombieBody.MARKE_COLOR
	m.emission_energy_multiplier = 3.0
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(mi)
	var l: OmniLight3D = OmniLight3D.new()
	l.light_color = ZombieBody.MARKE_COLOR
	l.light_energy = 0.9
	l.omni_range = 2.2
	l.shadow_enabled = false
	g.add_child(l)
	return g


func _untag(z: Zombie) -> void:
	var st: Dictionary = tagged.get(z, {})
	for n: Variant in st.get("nodes", []):
		if is_instance_valid(n):
			(n as Node).queue_free()
	if is_instance_valid(z):
		if z.damaged.is_connected(_on_zombie_damaged):
			z.damaged.disconnect(_on_zombie_damaged)
		for k: StringName in [&"kielholer", &"limb_mults"]:
			if z.has_meta(k):
				z.remove_meta(k)
	tagged.erase(z)


func _on_zombie_damaged(amount: float, limb: StringName, by_player: int, kind: StringName, z: Zombie) -> void:
	var st: Dictionary = tagged.get(z, {})
	if st.is_empty():
		return
	grab_hit(st, amount, limb, by_player, kind)
	if str(st["kind"]) == "kielholer_diver" and not bool(st["helmet_broken"]) and (limb == &"helmet_glass" or limb == &"head"):
		var e: Dictionary = ecfg("kielholer_diver")
		st["helmet"] = float(st["helmet"]) + amount / maxf(0.05, float(e.get("helmet_mult", 0.5)))
		if float(st["helmet"]) >= helmet_threshold(z.max_hp, e):
			break_helmet(z)
	if int(st.get("pid", 0)) != 0:
		var why: String = grab_breaks(st, ecfg("kielholer"))
		if why != "" and why != "time":
			release(z, why)


## The diver's glass goes: the glow shows and takes glow_mult (the console and the smoke call it too).
func break_helmet(z: Zombie) -> void:
	var st: Dictionary = tagged.get(z, {})
	if st.is_empty() or bool(st.get("helmet_broken", false)):
		return
	st["helmet_broken"] = true
	helmets_broken += 1
	var e: Dictionary = ecfg("kielholer_diver")
	z.set_meta(&"limb_mults", {"head": 1.0, "helmet_glass": float(e.get("glow_mult", 2.0))})
	if st.has("glow") and is_instance_valid(st["glow"]):
		(st["glow"] as Node3D).visible = true
	AudioDirector.play_3d("glass_break", z.global_position + Vector3.UP * 1.7, 0.0, 0.08)


# ================================================================== the grab

func _physics_process(delta: float) -> void:
	if not Net.is_authority():
		return
	var gc: Dictionary = ecfg("kielholer")
	for z: Variant in tagged.keys().duplicate():
		if not is_instance_valid(z):
			tagged.erase(z)
			continue
		var zz: Zombie = z as Zombie
		var st: Dictionary = tagged[z]
		if zz.state == Zombie.State.INACTIVE:
			if int(st["pid"]) != 0:
				release(zz, "gone")
			_untag(zz)
			continue
		if not zz.is_active():
			if int(st["pid"]) != 0:
				release(zz, "down")
			for n: Variant in st["nodes"]:
				if n is Hitbox and is_instance_valid(n):
					(n as Hitbox).collision_layer = 0
			continue
		st["cd"] = maxf(0.0, float(st["cd"]) - delta)
		if int(st["pid"]) != 0:
			_hold_tick(zz, st, gc, delta)
		elif float(st["cd"]) <= 0.0 and zz.state in [Zombie.State.CHASE, Zombie.State.ATTACK]:
			var p: Player = _grab_candidate(zz, st, gc)
			if p != null:
				start_grab(zz, p)


func _grab_candidate(z: Zombie, st: Dictionary, gc: Dictionary) -> Player:
	var best: Player = null
	var bd: float = float(gc.get("grab_range", 2.0))
	var now: float = Time.get_ticks_msec() / 1000.0
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not p.is_alive() or held_by(p.player_id) != null:
			continue
		if float((st["regrab"] as Dictionary).get(p.player_id, -INF)) > now:
			continue
		if p.has_status(&"boss_grab") or p.has_status(&"kielholer_grab"):
			continue
		var d: float = Vector2(p.global_position.x - z.global_position.x, p.global_position.z - z.global_position.z).length()
		if d <= bd and absf(p.global_position.y - z.global_position.y) < 1.2:
			bd = d
			best = p
	return best


## The Kielholer holding player `pid` (null = nobody).
func held_by(pid: int) -> Zombie:
	for z: Variant in tagged.keys():
		if int((tagged[z] as Dictionary).get("pid", 0)) == pid and is_instance_valid(z):
			return z as Zombie
	return null


func start_grab(z: Zombie, p: Player) -> void:
	var st: Dictionary = tagged.get(z, {})
	if st.is_empty() or p == null:
		return
	st["pid"] = p.player_id
	st["t"] = 0.0
	st["melee"] = 0
	st["arm"] = 0.0
	st["team"] = 0.0
	st["dmg_acc"] = 0.0
	st["dmg_t"] = 0.0
	grabs_started += 1
	p.apply_status(StringName(str(ecfg("kielholer").get("grab_status", "kielholer_grab"))), 0.4)
	AudioDirector.play_3d("kielholer_surface", z.global_position + Vector3.UP, -2.0, 0.1)
	if grabs_started == 1:
		GLVO.play_category(&"OPR", "KIELHOLER_GRAB")


func _hold_tick(z: Zombie, st: Dictionary, gc: Dictionary, delta: float) -> void:
	var p: Player = _player(int(st["pid"]))
	st["t"] = float(st["t"]) + delta
	if p == null or not p.is_alive():
		release(z, "down")
		return
	var why: String = grab_breaks(st, gc)
	if why != "":
		release(z, why)
		return
	p.apply_status(StringName(str(gc.get("grab_status", "kielholer_grab"))), 0.4)
	var edge: Vector3 = edge_point(p.global_position)
	var to_edge: Vector3 = Vector3(edge.x - p.global_position.x, 0, edge.z - p.global_position.z)
	var ed: float = to_edge.length()
	var dir: Vector3 = to_edge.normalized() if ed > 0.05 else Vector3.ZERO
	if ed > 0.5 and (p.is_local or p.is_bot):
		p.external_push(dir * float(gc.get("pull_mps", 1.2)), 0.2, &"pull")
	# the drowned man leans out over the water, pulling: he stays between the player and the edge
	var hold_at: Vector3 = p.global_position + (dir if ed > 0.05 else (z.global_position - p.global_position).normalized()) * 0.75
	z.global_position = Vector3(hold_at.x, z.global_position.y, hold_at.z)
	z.velocity = Vector3.ZERO
	z.set("_attack_cd", 1.0)
	z.call("_face", p.global_position)
	st["dmg_acc"] = float(st["dmg_acc"]) + hold_dps(ed, gc) * delta
	st["dmg_t"] = float(st["dmg_t"]) + delta
	if float(st["dmg_t"]) >= 0.5:
		st["dmg_t"] = 0.0
		var amt: float = float(st["dmg_acc"])
		st["dmg_acc"] = 0.0
		p.take_hit(amt, z)


func release(z: Zombie, reason: String) -> void:
	var st: Dictionary = tagged.get(z, {})
	if st.is_empty() or int(st["pid"]) == 0:
		return
	var gc: Dictionary = ecfg("kielholer")
	(st["regrab"] as Dictionary)[int(st["pid"])] = Time.get_ticks_msec() / 1000.0 + float(gc.get("regrab_lock", 4.0))
	st["pid"] = 0
	st["cd"] = float(gc.get("grab_cooldown", 5.0))
	grabs_broken[reason] = int(grabs_broken.get(reason, 0)) + 1
	if is_instance_valid(z) and z.is_active() and reason in ["melee", "arm", "team"] and z.state in [Zombie.State.CHASE, Zombie.State.ATTACK]:
		z.call("_enter", Zombie.State.STAGGER)   # shaken off: a beat to step away


func _player(pid: int) -> Player:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.player_id == pid:
			return p
	return null


# ================================================================== DER KIELHOLER (standalone, bots alone, the key)

func _director() -> ZombieDirector:
	return get_tree().get_first_node_in_group(&"director") as ZombieDirector


func _on_round_started(r: int, special: bool) -> void:
	if special or not Net.is_authority() or boss_summoned or r != boss_round or boss_round <= 0:
		return
	if not HomageBoss.homage_on() or GameState.has_flag(&"boat_key") or GameState.has_flag(&"kielholer_down"):
		return
	summon_standalone()


## Brings him in on the standalone round (the horde at horde_fraction), at dock 2.
func summon_standalone() -> HomageBoss:
	var dir: ZombieDirector = _director()
	if dir == null:
		return null
	var tb: Dictionary = boss_table()
	RoundManager.round_total = maxi(2, int(round(float(RoundManager.round_total) * float(tb.get("horde_fraction", 0.5)))))
	RoundManager.to_spawn = mini(RoundManager.to_spawn, RoundManager.round_total)
	var docks: Dictionary = _docks()
	var a: Array = docks.get("dock2", [13.2, 0.0, 70.0])
	var b: Node3D = dir.summon_boss(&"der_kielholer", Vector3(float(a[0]), float(a[1]), float(a[2])))
	return b as HomageBoss


func _docks() -> Dictionary:
	var all: Dictionary = t.get("cfg") if t != null and t.get("cfg") is Dictionary else GLData.load_json("res://data/gravelight/map02.json")
	return (all.get("letzte_fahrt", {}) as Dictionary).get("boss_docks", {})


func _on_boss_spawned(enemy_id: StringName) -> void:
	if enemy_id != &"der_kielholer":
		return
	boss_summoned = true
	for n: Node in get_tree().get_nodes_in_group(&"homage_bosses"):
		if n is Kielholer and (n as Kielholer).is_active():
			boss = n as HomageBoss
	_no_human_t = 0.0
	_human_t = 0.0
	bots_alone = false


func _process(delta: float) -> void:
	if boss == null or not is_instance_valid(boss) or not boss.is_active() or not Net.is_authority():
		return
	var ba: Dictionary = CousinsRound.bots_alone_cfg(boss_table())
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


## The ignition key at `pos` (the boss's body, or the dock edge after the fail-safe). Host decides; every peer
## places the same node (BoatKey under Gameplay).
func spawn_key_at(pos: Vector3, floating: bool = false) -> void:
	BoatKey.spawn_at(t, pos, floating)
	Net.mirror(self, &"spawn_key_at", [pos, floating])
