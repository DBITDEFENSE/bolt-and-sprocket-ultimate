class_name JakubCompanion
extends Node
## Jakub Ostrowski, the prisoner companion (Update 02 section 6.2; DECISIONS T-051, the Jakub half). A Polish
## miner in his forties who walked out of Kaltenbrunn two days ago; a German patrol caught him on the road and
## locked him in the Crossroads Inn's coal cage before they fled. He is a person and a hero, never a joke, never
## a zombie (ULTIMATE_PROMPT_V2 section 0.1). Data: data/gravelight/companion_jakub.json. Lines: VO_SCRIPT
## section 16 (speaker JAK, voiced with the offline TTS bake). Canon and his arc: docs/CANON.md section 6.4.
##
## He is a bot-style Player (is_bot, is_companion, the fixed pid in the data) driven by the Update 03 brain
## through BotSquad.add_brain(player, options): his personality (personality_jakub.json), no perks / kit / bonus
## perk / shopping, ~70% of a player's accuracy, escort = the player who freed him, ammo boxes paid from that
## player's Scrip at half price, revived after the humans and the bots. He is NOT a player: no id in
## GameState.player_ids / bot_ids, no co-op lobby slot, no round scaling, no scoreboard row, and a solo match
## never stays alive on him alone. His own co-op clock: downed, revivable, bleeds out after 60 s; then he is out
## cold for the rest of the match (his body stays where he fell, nobody can wake him) and comes back on the next
## campaign map, wounded: "Not yet. Not tonight."
##
## States: CAGED (Map 0, before the breakout round; he answers through the bars) -> BREAKOUT (a zombie climbs in
## through the coal window W_CEL_COAL, comes for him and bursts the cage hinge; he shouts in Polish, positional
## and subtitled, and kills it with the coal shovel) -> FREED (he steps out to JakubWait) -> WAITING (by the
## cage, calling out whenever nobody is near; "Talk to Jakub" opens the choice: GIVE HIM A GUN / NOT YET; a
## wall-buy with him beside it sells to him) -> JOINED (follows the one who freed him on the brain) -> FALLEN.
## The breakout comes at its round whether or not Door 5 is open: the coal window is outside the house, and the
## zombie that bursts the hinge needs no door. If nobody has opened the Old Cellar he waits in it, calling out
## (the voice carries up through the floor), until someone comes down: he can't leave a closed zone anyway.
## Online co-op: a companion has no replication yet, so he stays in his cage (data "online": false).
## Campaign: Campaign.snapshot carries snapshot_of() to the next map (state, gun, escort); single-map play on a
## later map brings him along when the profile flag companion_jakub = "joined" is set. On Kaltenbrunn he knows
## the shortcut: the Maintenance Stairs open for 500 less while he is with you (data "discounts").

enum State { CAGED, BREAKOUT, FREED, WAITING, JOINED, FALLEN }

const CFG_PATH: String = "res://data/gravelight/companion_jakub.json"
const INTEL_ID: String = "INT_JAK_01"
const PROFILE_KEY: String = "companion_jakub"
const STATE_NAMES: PackedStringArray = ["caged", "breakout", "freed", "waiting", "joined", "fallen"]
const WREN_SCENE: StringName = &"BNT_WRN_JAK_SCENE_01"

static var _cfg: Dictionary = {}
static var _active_pid: int = 0

var map: MapRoot
var state: State = State.CAGED
var player: Player = null
var brain: BotBrain = null
var cage: HoldingCage = null
var talk: JakubTalk = null
var escort_pid: int = 0
## Back from a bleed-out on the map before (less health, the bandage), or out cold on this one.
var wounded: bool = false
## Online co-op: he stays in his cage.
var online_caged: bool = false
var breakout_round: int = 5
var breakout_zombie: Zombie = null
## Tools / tests: what happened, in order ("caged", "breakout", "burst", "kill", "waiting", "joined", "armed", ...).
var events: PackedStringArray = []

var _now: float = 0.0
var _due: float = INF
var _phase_t: float = 0.0
var _swings: int = 0
var _swing_t: float = 0.0
var _path: PackedVector3Array = PackedVector3Array()
var _walk_t: float = 0.0
var _mi: MoveIntent = MoveIntent.new()
var _call_t: float = 0.0
var _calls: int = 0
var _talk_cd: float = 0.0
var _said: Dictionary = {}
var _later: Array = []            # [due, category, give up at, heard-check until (-1 = not submitted), fired count before]
var _wren_done: bool = false
var _choice: JakubChoice = null
var _discounted: Dictionary = {}  # BuyDoor -> its own cost
var _perk_cd: float = 0.0
var _perk_near_done: bool = false
var _cousins_said: bool = false


# ================================================================== static: data, the one companion, pure rules

static func cfg() -> Dictionary:
	if _cfg.is_empty():
		_cfg = GLData.load_json(CFG_PATH)
	return _cfg


static func pid() -> int:
	return int(cfg().get("pid", 9))


## True for the companion's player id while one is in the match (MapRoot, VOManager).
static func is_companion_pid(p: int) -> bool:
	return _active_pid != 0 and p == _active_pid


static func instance(tree: SceneTree) -> JakubCompanion:
	return tree.get_first_node_in_group(&"jakub_companion") as JakubCompanion if tree != null else null


## The brain options (docs/BOT_AI.md section 5) for an escort and whether he has a gun (pure).
static func brain_options(escort: int, has_gun: bool) -> Dictionary:
	var o: Dictionary = (cfg().get("brain", {}) as Dictionary).duplicate(true)
	o["escort_pid"] = escort
	o["ammo_payer_pid"] = escort
	o["armed"] = has_gun
	return o


## Why he won't take the gun in your hands ("" = he will): your only gun, a wonder weapon, nothing held, you are
## down (pure, unit-tested).
static func offer_rule(slot_count: int, cls: StringName, last_stand: bool, refused: Array) -> String:
	if last_stand:
		return "down"
	if slot_count <= 0:
		return "empty"
	if slot_count <= 1:
		return "only_gun"
	if refused.has(String(cls)):
		return "refused"
	return ""


## The line he says for a gun of this class (pure).
static func gun_category(cls: StringName) -> String:
	match cls:
		&"bolt", &"sniper":
			return "GUN_BOLT"
		&"rifle":
			return "GUN_RIFLE"
		&"smg", &"assault", &"lmg":
			return "GUN_AUTO"
		&"pistol":
			return "GUN_PISTOL"
		&"shotgun":
			return "GUN_SHOTGUN"
	return "GUN_OTHER"


## The carry payload (Campaign.snapshot "companion"), from what he is now (pure).
static func serialize_state(st: State, has_gun: bool, inv: Dictionary, escort: int, was_wounded: bool) -> Dictionary:
	if st != State.JOINED and st != State.FALLEN:
		return {}
	return {"state": STATE_NAMES[st], "armed": has_gun and st == State.JOINED, "inv": inv if st == State.JOINED else {},
		"escort": escort, "wounded": was_wounded or st == State.FALLEN}


## What the next map makes of a carried payload (pure): he joins at once; after a bleed-out (or wounded) he is
## wounded and has lost his gun.
static func restore_plan(d: Dictionary) -> Dictionary:
	if d.is_empty():
		return {}
	var fallen: bool = str(d.get("state", "")) == "fallen"
	var inv: Dictionary = {} if fallen else (d.get("inv", {}) as Dictionary)
	var guns: bool = not fallen and not (inv.get("s", []) as Array).is_empty()
	return {"join": true, "wounded": fallen, "inv": inv, "armed": guns,
		"escort": maxi(1, int(d.get("escort", 1)))}


static func joined_profile() -> bool:
	return str(ProfileSave.profile.get(PROFILE_KEY, "")) == "joined"


## The profile flag (companion_jakub = joined), his letter in the Archive, saved now.
static func mark_joined() -> void:
	ProfileSave.profile[PROFILE_KEY] = "joined"
	ProfileSave.add_intel(StringName(INTEL_ID))
	ProfileSave.save_profile()


## Jakub's dossier pages open with his own XP (data dossier_xp), earned by playing alongside him.
static func add_dossier_xp(event: String) -> void:
	var n: int = int((cfg().get("dossier_xp", {}) as Dictionary).get(event, 0))
	if n <= 0:
		return
	var d: Dictionary = ProfileSave.profile.get("dossiers", {})
	d["jakub"] = int(d.get("jakub", 0)) + n
	ProfileSave.profile["dossiers"] = d


## The carry payload for Campaign.snapshot: {} unless he is with the squad (or out cold) on this map.
static func snapshot_of(map_root: Node) -> Dictionary:
	var jc: JakubCompanion = instance(map_root.get_tree()) if map_root != null and map_root.is_inside_tree() else null
	return jc.serialize() if jc != null else {}


# ================================================================== wall-buys (WallBuy calls these)

## A gun wall-buy with Jakub (out of his cage, no gun of his own) standing beside it sells to him.
static func buys_here(wb: WallBuy, p: Player) -> bool:
	var jc: JakubCompanion = instance(wb.get_tree()) if wb.is_inside_tree() else null
	return jc != null and jc._buys_here(wb, p)


static func bought_for_him(wb: WallBuy, p: Player) -> void:
	var jc: JakubCompanion = instance(wb.get_tree())
	if jc != null:
		jc._receive(WeaponInstance.create(wb.weapon_id), p, true)


func _buys_here(wb: WallBuy, p: Player) -> bool:
	if (state != State.WAITING and state != State.JOINED) or player == null or player.downed or p == null or p.is_bot or p.is_companion:
		return false
	if not player.weapons.slots.is_empty():
		return false
	var row: Dictionary = (GLData.table("weapons")["weapons"] as Dictionary).get(String(wb.weapon_id), {})
	if row.is_empty() or (cfg().get("refuses_classes", []) as Array).has(str(row.get("class", ""))):
		return false
	return _flat(player.global_position, wb.global_position) <= float(cfg().get("wall_buy_beside_m", 3.6))


# ================================================================== setup

## MapRoot._ready: his cage on Map 0, his carried self on an arrival, or (single-map) the profile's Jakub.
static func attach(map_root: MapRoot) -> void:
	_active_pid = 0
	_cfg = {}
	var carried: Dictionary = Campaign.arrival_companion()
	var cage_node: HoldingCage = map_root.find_child("JakubCage", true, false) as HoldingCage
	var mode: String = ""
	if not carried.is_empty() and not Net.is_online():
		mode = "carried"
	elif cage_node != null:
		mode = "cage"
	elif not Net.is_online() and joined_profile() and map_root.map_id != &"test_range" and not Campaign.active:
		mode = "profile"
	if mode == "":
		return
	var jc: JakubCompanion = JakubCompanion.new()
	jc.name = "JakubCompanion"
	map_root.add_child(jc)
	jc.setup(map_root, mode, carried, cage_node)


func setup(map_root: MapRoot, mode: String, carried: Dictionary, cage_node: HoldingCage) -> void:
	map = map_root
	cage = cage_node
	add_to_group(&"jakub_companion")
	var c: Dictionary = cfg()
	breakout_round = int((c.get("breakout", {}) as Dictionary).get("round", 5))
	online_caged = Net.is_online() and not bool(c.get("online", false))
	GLBus.round_started.connect(_on_round_started)
	GLBus.round_ended.connect(_on_round_ended)
	GLBus.perk_bought.connect(_on_perk_bought)
	GLBus.zone_opened.connect(_on_zone_opened)
	GLBus.boss_spawned.connect(_on_boss_spawned)
	GLBus.power_activated.connect(_on_power)
	GLBus.player_revived.connect(_on_revived)
	var con: Node = get_node_or_null("/root/GLConsole")
	if con != null and con.has_method("register"):
		con.call("register", "jakub", _cmd, "jakub status|breakout|join|arm <weapon>|down: Jakub, the prisoner companion (U02 section 6.2)")
	match mode:
		"cage":
			var mk: Node3D = map.find_child("JakubSpawn", true, false) as Node3D
			_make_body(mk.global_transform if mk != null else cage.global_transform)
			_cage_lamp(mk.global_position if mk != null else cage.inside_point())
			state = State.CAGED
			_event("caged")
		"carried":
			var plan: Dictionary = restore_plan(carried)
			wounded = bool(plan.get("wounded", false))
			_make_body(_beside_spawn(int(plan.get("escort", 1))))
			var inv: Dictionary = plan.get("inv", {})
			if bool(plan.get("armed", false)):
				player.weapons.apply_carry(inv)
			_join(int(plan.get("escort", 1)), true)
		"profile":
			_make_body(_beside_spawn(1))
			_join(1, true)


## Jakub's body: a bot-style Player that is no match player (see the class doc).
func _make_body(xf: Transform3D) -> void:
	var p: Player = Player.new()
	p.player_id = pid()
	p.is_local = false
	p.is_bot = true
	p.is_companion = true
	p.name = "Jakub"
	GameState.characters[p.player_id] = &"jakub"
	_active_pid = p.player_id
	map.add_child(p)
	p.global_transform = xf
	p.bleedout_seconds = float(cfg().get("bleedout_seconds", 60.0))
	p.max_hp = float(cfg().get("max_hp", 100.0)) * (float(cfg().get("wounded_hp_mult", 0.7)) if wounded else 1.0)
	p.hp = p.max_hp
	p.bot_damage_mult = 0.0   # nothing can hurt him while the scene plays (he is no zombie target until he joins)
	p.remove_from_group(&"players")
	p.remove_from_group(&"bots")
	p.add_to_group(&"companions")
	p.weapons.slots.clear()
	p.weapons.current_index = 0
	p.weapons.grenades = 0
	p.weapons.melee_id = StringName(str(cfg().get("melee", "coal_shovel")))
	if p.remote_body != null:
		p.remote_body.set_weapon(&"" if cage != null and state == State.CAGED else &"coal_shovel")
		p.remote_body.set_wounded(wounded)
	var rp: RevivePoint = RevivePoint.new()
	rp.name = "Revive"
	rp.owner_player = p
	p.add_child(rp)
	talk = JakubTalk.new()
	talk.name = "Talk"
	talk.companion = self
	p.add_child(talk)
	player = p


## The patrol's storm lantern on its nail by the cage: a low, warm pool on him so he reads in the dark coal room.
func _cage_lamp(at: Vector3) -> void:
	var l: OmniLight3D = OmniLight3D.new()
	l.name = "JakubCageLamp"
	l.light_color = Color(1.0, 0.72, 0.42)
	l.light_energy = 0.55
	l.omni_range = 3.2
	l.omni_attenuation = 1.4
	l.shadow_enabled = false
	map.add_child(l)
	l.global_position = at + Vector3(0.9, 2.1, 0.0)


## Beside a survivor's spawn marker, a step behind.
func _beside_spawn(escort: int) -> Transform3D:
	var xf: Transform3D = map.spawn_transform(escort)
	xf.origin += xf.basis.z * 1.3 + xf.basis.x * 0.9
	return xf


# ================================================================== per frame

func _physics_process(delta: float) -> void:
	_now += delta
	_talk_cd = maxf(0.0, _talk_cd - delta)
	_perk_cd = maxf(0.0, _perk_cd - delta)
	if player == null or not is_instance_valid(player) or GameState.phase != GameState.Phase.PLAYING:
		return
	_tick_later()
	match state:
		State.CAGED:
			_tick_caged(delta)
		State.BREAKOUT:
			_tick_breakout(delta)
		State.FREED:
			_tick_walk(delta)
		State.WAITING:
			_tick_waiting(delta)
		State.JOINED:
			_tick_joined(delta)
		State.FALLEN:
			_pose(delta, 0.0, NetMatch.PF_DOWNED)


func _event(e: String) -> void:
	events.append(e)
	print("[jakub] %s (round %d)" % [e, RoundManager.current_round])


func _tick_caged(delta: float) -> void:
	_stand(delta)
	var h: Player = _nearest_human(8.0)
	if h != null:
		_face(h.global_position)
		if h.global_position.distance_to(player.global_position) < 6.0 and not _said.has("CAGE_HELLO"):
			_said["CAGE_HELLO"] = true
			_say("CAGE_HELLO")
	_pose(delta, 0.0, NetMatch.PF_FLOOR)
	if _now >= _due:
		_start_breakout()


## The breakout (round 5): a zombie through the coal window, for him.
func _start_breakout() -> void:
	_due = INF
	state = State.BREAKOUT
	_phase_t = 0.0
	_swings = 0
	_event("breakout")
	breakout_zombie = _spawn_breakout_zombie()
	if breakout_zombie == null:
		_burst(null)   # no zombie to spare: the old hinge gives to his shoulder
	else:
		_say("ALARM")


func _spawn_breakout_zombie() -> Zombie:
	var d: ZombieDirector = map.director
	if d == null or d._free.is_empty():
		return null
	var b: Dictionary = cfg().get("breakout", {})
	var win: String = str(b.get("zombie_window", "W_CEL_COAL"))
	var sp: ZombieSpawn = null
	for n: Node in get_tree().get_nodes_in_group(&"zombie_spawns"):
		var s: ZombieSpawn = n as ZombieSpawn
		if s != null and s.window() != null and String(s.window().window_id) == win:
			sp = s
	var spec: Dictionary = RoundManager.take_extra_spawn()
	spec["tier"] = &"jog"
	spec["variant"] = d._pick_variant()
	spec["health"] = maxi(int(b.get("zombie_health", 200)), int(spec.get("health", 150)))
	var z: Zombie = null
	if sp != null:
		z = d._free.pop_back()
		z.activate(spec, sp, player)
		GLBus.enemy_spawned.emit(z.enemy_id, z.get_instance_id())
	else:
		z = d._activate_at(spec, cage.front_point() + cage.global_basis.z * -1.5)
	if z != null:
		z.forced_target = player
	return z


func _tick_breakout(delta: float) -> void:
	_phase_t += delta
	_stand(delta)
	var b: Dictionary = cfg().get("breakout", {})
	var z: Zombie = breakout_zombie
	var alive: bool = z != null and is_instance_valid(z) and z.is_active()
	if alive:
		_face(z.global_position)
	_pose(delta, 0.0, NetMatch.PF_FLOOR)
	if not cage.is_open:
		var close: bool = alive and (_flat(z.global_position, cage.front_point()) <= float(b.get("burst_distance_m", 1.6)) \
			or (_flat(z.global_position, player.global_position) < 2.4 and absf(z.global_position.y - player.global_position.y) < 1.2))
		if close or not alive or _phase_t > float(b.get("zombie_timeout_s", 30.0)):
			_burst(z if alive else null)
		return
	if alive:
		var d: float = _flat(z.global_position, player.global_position)
		if d <= 2.5:
			_swing_t -= delta
			if _swing_t <= 0.0:
				_swing_t = float(b.get("swing_every_s", 0.55))
				_swings += 1
				_shovel_swing(z)
				if _swings >= int(b.get("fight_swings", 3)):
					z.forced_target = null
					z.take_damage(z.hp + 99999.0, &"head", &"coal_shovel", player.player_id, &"melee")
					breakout_zombie = null
					_event("kill")
					_after_fight(true)
		elif _phase_t > float(b.get("zombie_timeout_s", 30.0)) + 14.0:
			z.forced_target = null   # it lost interest: he steps out anyway
			_after_fight(false)
	else:
		_after_fight(false)


func _shovel_swing(z: Zombie) -> void:
	var eye: Vector3 = player.global_position + Vector3.UP * 1.4
	player.remote_fire(3, &"coal_shovel", eye, eye + (z.global_position - player.global_position).normalized())
	AudioDirector.play_3d("knife_hit", z.global_position + Vector3.UP * 1.2, 0.0)
	z.force_stagger()


## The hinge gives: the cage door swings out, he grabs the coal shovel leaning on the bars and shouts.
func _burst(by: Node) -> void:
	if cage == null or cage.is_open:
		return
	cage.burst_open(by)
	_event("burst")
	var prop: Node3D = map.find_child("CoalShovel", true, false) as Node3D
	if prop != null and not (prop is Player):
		prop.visible = false
	if player.remote_body != null:
		player.remote_body.set_weapon(&"coal_shovel")
	_say("BREAKOUT" if by != null else "BREAKOUT_SELF")
	_phase_t = 0.0


func _after_fight(killed: bool) -> void:
	if killed:
		_later_say(0.8, "FIGHT_KILL")
	state = State.FREED
	_walk_t = 0.0
	_path = PackedVector3Array()
	if cage != null:
		_path.append(cage.inside_point())
		_path.append(cage.front_point())
	var w: Node3D = map.find_child("JakubWait", true, false) as Node3D
	if w != null:
		_path.append(w.global_position)
	if _path.is_empty():
		_wait_now()


func _tick_walk(delta: float) -> void:
	_walk_t += delta
	if _path.is_empty() or _walk_t > 14.0:
		if not _path.is_empty():
			player.global_position = _path[_path.size() - 1]   # never stuck in the cage door
		_wait_now()
		return
	var to: Vector3 = _path[0] - player.global_position
	to.y = 0.0
	if to.length() < 0.35:
		_path.remove_at(0)
		_pose(delta, 0.0, NetMatch.PF_FLOOR)
		return
	_face(_path[0])
	_mi.clear()
	_mi.move = MoveIntent.local_move(player.global_basis, to.normalized() * 0.55)
	player.drive_bot(delta, _mi)
	_pose(delta, player.horizontal_speed(), NetMatch.PF_FLOOR)


func _wait_now() -> void:
	state = State.WAITING
	_path = PackedVector3Array()
	_call_t = float(cfg().get("call_every_s", 16.0))
	_event("waiting")
	_later_say(0.6, "FREED")


func _tick_waiting(delta: float) -> void:
	_stand(delta)
	var h: Player = _nearest_human(12.0)
	if h != null:
		_face(h.global_position)
	_pose(delta, 0.0, NetMatch.PF_FLOOR)
	_call_t -= delta
	var near: Player = _nearest_human(float(cfg().get("call_unless_within_m", 9.0)))
	if near == null and _call_t <= 0.0:
		# every call_every_s at first, then slower (never more than a minute apart) if nobody comes for a long while
		_calls += 1
		_call_t = minf(60.0, float(cfg().get("call_every_s", 16.0)) * (1.0 + float(_calls) / 4.0))
		_say("CALL")


func _tick_joined(_delta: float) -> void:
	var s: NetMatch = Net.session
	if s != null and s.coop.is_dead(player.player_id):
		_fall()
		return
	if player.downed:
		return
	# he refuses perks: the first time he stands by a machine
	if not _perk_near_done:
		for n: Node in get_tree().get_nodes_in_group(&"perk_machines"):
			var pm: Node3D = n as Node3D
			if pm != null and _flat(pm.global_position, player.global_position) < 3.0 and absf(pm.global_position.y - player.global_position.y) < 2.0:
				_perk_near_done = true
				if _perk_cd <= 0.0 and _say("PERK_REFUSE"):
					_perk_cd = 90.0
				break
	if not _wren_done:
		_try_wren_scene_bot()
	if not _cousins_said and map.director != null:
		var cr: CousinsRound = map.director.get("cousins") as CousinsRound
		if cr != null and cr.phase == CousinsRound.Phase.ACTIVE:
			_cousins_said = true   # the Cousins' rhyme: everyone in the valley knows it
			_later_say(5.0, "COUSINS")
			_later_say(45.0, "COUSINS_AFTER")


# ================================================================== talking and the choice

## The talk point is live: caged, waiting or with you, standing, no choice card open.
func talk_open() -> bool:
	if player == null or player.downed or player.spectating or _choice != null:
		return false
	return state == State.CAGED or state == State.WAITING or state == State.JOINED


func talk_prompt(p: Player) -> String:
	if p == null or p.is_bot or p.is_companion or not talk_open():
		return ""
	var key: String = Interactable.prompt_key(&"interact")
	match state:
		State.CAGED, State.WAITING:
			return "Hold [%s] to talk to Jakub" % key
		State.JOINED:
			var o: Dictionary = gun_offer(p)
			if bool(o.get("ok", false)):
				return "Hold [%s] to give Jakub your %s%s" % [key, str(o["name"]), " (he gives you his)" if not player.weapons.slots.is_empty() else ""]
			if str(o.get("code", "")) in ["only_gun", "refused", "nachtglas"]:
				return "Jakub: %s" % str(o.get("reason", ""))
	return ""


func can_talk(p: Player) -> bool:
	if p == null or p.is_bot or p.is_companion or not talk_open():
		return false
	if state == State.JOINED:
		return bool(gun_offer(p).get("ok", false))
	return true


func on_talk(p: Player) -> void:
	if not can_talk(p):
		return
	match state:
		State.CAGED:
			if _talk_cd <= 0.0:
				_talk_cd = 10.0
				_say("CAGE_TALK")
		State.WAITING:
			_say("TALK_ASK")
			if p.is_local and DisplayServer.get_name() != "headless":
				_choice = JakubChoice.new()
				_choice.companion = self
				_choice.player = p
				_choice.offer = gun_offer(p)
				_choice.timeout_s = float(cfg().get("choice_timeout_s", 12.0))
				_choice.tree_exited.connect(func() -> void: _choice = null)
				map.add_child(_choice)
			else:
				choose(p, bool(gun_offer(p).get("ok", false)))   # headless tools: the gun if he'd take it
		State.JOINED:
			_take_gun(p)


## What GIVE HIM A GUN would hand over: {ok, name, code, reason}.
func gun_offer(p: Player) -> Dictionary:
	if p == null or p.weapons == null:
		return {"ok": false, "code": "empty", "reason": "nothing in your hands"}
	var w: WeaponInstance = p.weapons.current()
	var code: String = offer_rule(p.weapons.slots.size() if w != null else 0, w.weapon_class() if w != null else &"",
		p.weapons.in_last_stand(), cfg().get("refuses_classes", []))
	if code == "" and w != null and not M1911Kit.companion_accepts(w):
		code = "nachtglas"   # UPDATE_04 section 6: he won't carry the Nachtglas rounds
	var reasons: Dictionary = {"down": "not while you are down", "empty": "nothing in your hands",
		"only_gun": "keep it, it's your only gun (buy him one at a wall)", "refused": "he won't touch that one",
		"nachtglas": "he won't carry Nachtglas rounds"}
	if code != "":
		return {"ok": false, "code": code, "reason": str(reasons.get(code, code)), "name": w.display_name() if w != null else ""}
	return {"ok": true, "code": "", "name": w.display_name(), "weapon": w}


## The choice card's answer (also tools / tests): give = the gun in `p`'s hands, else he comes with the shovel.
func choose(p: Player, give: bool) -> void:
	if state != State.WAITING:
		if state == State.JOINED and give:
			_take_gun(p)
		return
	var offer: Dictionary = gun_offer(p)
	_join(p.player_id, false)
	if give and bool(offer.get("ok", false)):
		_take_gun(p)
	else:
		_later_say(0.2, "JOIN_UNARMED")
	if GameState.character_of(p.player_id) == &"wren" and not p.is_bot:
		_wren_scene(p.player_id, 6.0)   # the first time Wren talks to him


## Hands him the weapon in `p`'s hands (they lose it); a gun he already had goes back to `p`.
func _take_gun(p: Player) -> void:
	var o: Dictionary = gun_offer(p)
	if not bool(o.get("ok", false)):
		return
	var w: WeaponInstance = p.weapons.remove_current()
	if w == null:
		return
	_receive(w, p, false)


func _receive(w: WeaponInstance, from: Player, bought: bool) -> void:
	if state == State.WAITING:
		_join(from.player_id, false)
	var old: WeaponInstance = player.weapons.current()
	player.weapons.slots.clear()
	player.weapons.slots.append(w)
	player.weapons.current_index = 0
	if old != null and from != null and from.weapons != null and not bought:
		if from.weapons.find_weapon(old.id) == null:
			from.weapons.give_instance(old)   # "Take mine, then." (the very gun: its ammo and M1911 attachments)
		else:
			from.weapons.give_weapon(old.id)
			var back: WeaponInstance = from.weapons.find_weapon(old.id)
			if back != null:
				back.mag = old.mag
				back.reserve = old.reserve
		_later_say(0.2, "GUN_SWAP")
	_set_armed(true)
	_event("armed:%s" % w.id)
	_later_say(0.9, gun_category(w.weapon_class()))


func _set_armed(on: bool) -> void:
	if brain != null:
		brain.options["armed"] = on
	if player.remote_body != null:
		var cw: WeaponInstance = player.weapons.current()
		player.remote_body.set_weapon(cw.id if cw != null else &"coal_shovel")


## He joins the squad: the brain, the life cycle, the profile flag (unless he arrived with you from a map before).
func _join(escort: int, arrival: bool) -> void:
	if state == State.JOINED or state == State.FALLEN:
		return
	escort_pid = escort if escort > 0 else 1
	var squad: BotSquad = map.ensure_companion_session()
	if squad == null or Net.session == null:
		return   # online co-op: no companion yet
	state = State.JOINED
	Net.session.add_companion(player)
	player.add_to_group(&"players")
	player.add_to_group(&"bots")
	player.bot_damage_mult = 1.0
	if player.remote_body != null and player.weapons.slots.is_empty():
		player.remote_body.set_weapon(&"coal_shovel")
	brain = squad.add_brain(player, brain_options(escort_pid, not player.weapons.slots.is_empty()))
	_apply_discounts(true)
	_event("joined")
	if arrival:
		var cat: String = "RETURN_WOUNDED" if wounded else ("M%s_ARRIVE" % _map_key())
		_later_say(4.0, cat)
		if not _discounted.is_empty():
			_later_say(22.0, "M1_SHORTCUT")
		add_dossier_xp("map_arrival")
	else:
		mark_joined()
		add_dossier_xp("joined")
		if map.hud != null:
			map.hud.show_banner("JAKUB OSTROWSKI JOINS YOU\nHis letter is in the Archive.", 3.5)
		var h: Player = map.players.get(escort_pid) as Player
		if h != null and not h.is_bot:
			GLVO.say_as(escort_pid, "JAKUB_MEET", 1.0)


## "0" Map 0, "1" Kaltenbrunn, "2" Totenhafen.
func _map_key() -> String:
	var m: String = String(map.map_id)
	return "1" if m.begins_with("map01") else ("2" if m.begins_with("map02") else "0")


## The bled-out companion: out cold where he fell for the rest of the match (no respawn), back next map, wounded.
func _fall() -> void:
	state = State.FALLEN
	wounded = true
	_event("fallen")
	if brain != null and map.squad != null:
		map.squad.remove_brain(brain)
	brain = null
	player.remove_from_group(&"players")
	player.remove_from_group(&"bots")
	if Net.session != null:
		Net.session.remove_companion(player.player_id)
	_apply_discounts(false)
	GLVO.squad_say("JAKUB_FALLEN", 1.0, player.player_id)
	if map.hud != null:
		map.hud.show_banner("Jakub is out cold." + ("\nHe'll find you on the next map." if Campaign.active else ""), 3.0)


func serialize() -> Dictionary:
	var inv: Dictionary = player.weapons.to_net() if player != null and player.weapons != null else {}
	if player != null and player.weapons != null and player.weapons.in_last_stand():
		inv = Campaign.stash_to_net(player.weapons)
	var st: State = state
	if st == State.JOINED and player != null and player.downed:
		st = State.FALLEN   # left downed: he crawls after you and arrives wounded
	return serialize_state(st, player != null and not player.weapons.slots.is_empty(), inv, escort_pid, wounded)


# ================================================================== Kaltenbrunn's shortcut

func _apply_discounts(on: bool) -> void:
	var table: Dictionary = (cfg().get("discounts", {}) as Dictionary).get(String(map.map_id), {})
	if on:
		for n: Node in get_tree().get_nodes_in_group(&"doors"):
			var d: BuyDoor = n as BuyDoor
			if d != null and table.has(String(d.door_id)) and not d.is_open and not _discounted.has(d):
				_discounted[d] = d.cost
				d.set_cost(d.cost - int(table[String(d.door_id)]))
	else:
		for d2: Variant in _discounted.keys():
			if is_instance_valid(d2) and not (d2 as BuyDoor).is_open:
				(d2 as BuyDoor).set_cost(int(_discounted[d2]))
		_discounted.clear()


# ================================================================== Wren

func _try_wren_scene_bot() -> void:
	if RoundManager.state == RoundManager.State.ROUND and not (map.director != null and map.director.active_zombies().is_empty()):
		return
	var r: float = float(cfg().get("wren_scene_m", 5.0))
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p != player and p.is_alive() and GameState.character_of(p.player_id) == &"wren" \
				and p.global_position.distance_to(player.global_position) <= r:
			_wren_scene(p.player_id, 0.5)
			return


## The quiet scene: he knew Tomasz (CANON section 6.4). Once per match, the first time Wren and he talk.
func _wren_scene(wren_pid: int, delay: float) -> void:
	if _wren_done:
		return
	_wren_done = true
	_event("wren_scene")
	add_dossier_xp("wren_scene")
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if is_instance_valid(self) and player != null:
			GLVO.play_exchange(WREN_SCENE, {&"WRN": wren_pid, &"JAK": player.player_id}))


# ================================================================== events and lines

func _on_round_started(r: int, _special: bool) -> void:
	if state == State.CAGED and not online_caged and r >= breakout_round and _due == INF:
		_due = _now + float((cfg().get("breakout", {}) as Dictionary).get("delay_s", 5.0))
	if state == State.JOINED and _map_key() == "0" and r == 9:
		_later_say(28.0, "MIDNIGHT")


func _on_round_ended(_r: int) -> void:
	if state == State.JOINED and player != null and not player.downed:
		add_dossier_xp("round_with_him")


func _on_perk_bought(by: int, _perk: StringName) -> void:
	if state != State.JOINED or player == null or player.downed or _perk_cd > 0.0:
		return
	var h: Player = map.players.get(by) as Player
	if h != null and h.global_position.distance_to(player.global_position) <= float(cfg().get("perk_comment_m", 9.0)):
		if randf() < 0.7 and _say("PERK_REFUSE"):
			_perk_cd = 90.0


func _on_zone_opened(zone: StringName) -> void:
	if state == State.JOINED and player != null and not player.downed:
		_later_say(2.5, "ZONE_%s" % String(zone).to_upper())


func _on_boss_spawned(enemy_id: StringName) -> void:
	if state != State.JOINED or player == null or player.downed:
		return
	if enemy_id == &"foreman":
		_later_say(3.0, "M1_FOREMAN")
	elif enemy_id == &"screamer":
		_later_say(3.0, "SCREAMER")


func _on_power() -> void:
	if state == State.JOINED and _map_key() == "1":
		_later_say(6.0, "M1_POWER")


func _on_revived(who: int, _by: int) -> void:
	if who == pid() and state == State.JOINED:
		add_dossier_xp("revived_him")


## One of his lines now (positional at him; subtitled with translations). False when none played.
func _say(category: String) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	return GLVO.play_category(&"JAK", category, 1.0, player.player_id)


## A line for later. If he's down when it comes due, or the line can't play yet (the channel is busy), it waits and
## tries again until `patience` seconds past its time (a down at the Cousins' arrival used to lose his line for good).
## A line the VOManager only queued isn't counted as said: a queued quip expires after a few seconds in a busy
## channel, so the entry waits `HEARD_WAIT` s for the line to actually start (GLVO.fired) and otherwise tries again.
const HEARD_WAIT: float = 6.0

func _later_say(seconds: float, category: String, patience: float = 60.0) -> void:
	_later.append([_now + seconds, category, _now + seconds + patience, -1.0, 0])


func _tick_later() -> void:
	if _later.is_empty():
		return
	var keep: Array = []
	for e: Variant in _later:
		var a: Array = e
		var key: String = "JAK:" + str(a[1])
		if float(a[3]) >= 0.0:
			# submitted: done once it has started; past HEARD_WAIT it was dropped from the queue, so try again
			if int(GLVO.fired.get(key, 0)) > int(a[4]):
				continue
			if _now < float(a[3]):
				keep.append(a)
				continue
			a[3] = -1.0
		if _now < float(a[0]):
			keep.append(a)
		elif state == State.FALLEN or _now > float(a[2]):
			continue
		elif player.downed:
			keep.append(a)
		else:
			var before: int = int(GLVO.fired.get(key, 0))
			if _say(str(a[1])):
				a[3] = _now + HEARD_WAIT
				a[4] = before
			keep.append(a)
	_later = keep


# ================================================================== helpers

func _stand(delta: float) -> void:
	_mi.clear()
	player.drive_bot(delta, _mi)


func _face(p: Vector3) -> void:
	var d: Vector3 = p - player.global_position
	d.y = 0.0
	if d.length() > 0.05:
		player.rotation.y = lerp_angle(player.rotation.y, atan2(-d.x, -d.z), 0.2)


func _pose(delta: float, speed: float, flags: int) -> void:
	player.net_flags = flags
	if player.remote_body != null:
		player.remote_body.calm = speed < 0.3 and state != State.BREAKOUT
		player.remote_body.update_pose(delta, speed, 0.0, flags)


## The nearest standing human within `r` m (bots and the companion excluded), or null.
func _nearest_human(r: float) -> Player:
	var best: Player = null
	var bd: float = r
	for k: Variant in map.players.keys():
		var p: Player = map.players[k] as Player
		if p == null or p.is_bot or p.downed or p.spectating:
			continue
		var d: float = p.global_position.distance_to(player.global_position)
		if d <= bd:
			bd = d
			best = p
	return best


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func state_name() -> String:
	return STATE_NAMES[state]


## Dev console: jakub status|breakout|join|arm <weapon>|down.
func _cmd(a: PackedStringArray) -> String:
	var arg: String = a[0] if a.size() > 0 else "status"
	match arg:
		"breakout":
			if state == State.CAGED:
				_start_breakout()
			return "Jakub: %s" % state_name()
		"join":
			if state == State.CAGED and cage != null:
				_burst(null)
				_wait_now()
			if state == State.WAITING:
				choose(map.player, false)
			return "Jakub: %s" % state_name()
		"arm":
			var wid: StringName = StringName(a[1] if a.size() > 1 else "kar98k")
			if (GLData.table("weapons")["weapons"] as Dictionary).has(String(wid)) and (state == State.WAITING or state == State.JOINED):
				_receive(WeaponInstance.create(wid), map.player, true)
			return "Jakub: %s, %s" % [state_name(), str(player.weapons.current().id) if player.weapons.current() != null else "shovel"]
		"down":
			if state == State.JOINED and not player.downed:
				player.take_hit(player.hp + 1.0, null)
			return "Jakub: %s" % ("down" if player.downed else state_name())
	return "Jakub: %s, escort P%d, %s, hp %.0f/%.0f%s" % [state_name(), escort_pid,
		str(player.weapons.current().id) if player.weapons.current() != null else "coal shovel", player.hp, player.max_hp, " (wounded)" if wounded else ""]
