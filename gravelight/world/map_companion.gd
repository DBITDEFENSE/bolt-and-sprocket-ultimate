class_name MapCompanion
extends Node
## T-135: one more companion per map, like Jakub (data/gravelight/companions.json): Trudi Hanke on Map 0 (the
## stable), Fw. August "Gustl" Ammer on Kaltenbrunn (the barracks stores), Hinnerk Petersen on Totenhafen (the
## signal tower), Jette Maurer on Fernflug (the station; she stays with you through Act III).
##
## Simpler than Jakub (no cage, no breakout, no tonics, no wall-buys): it waits at its spot and calls out when a
## survivor comes near; a talk opens the same choice card as Jakub (JakubChoice): give it the gun in your hands, or it
## comes with its melee. With you it is a squad bot (BotSquad.add_brain, like Jakub's brain options), it can be
## downed and revived, and a bleed-out leaves it out cold for the rest of the match. At the start of each round it
## brings the one it follows a small gift while they stand near (a grenade, a magazine, some Scrip).
## Offline only (like Jakub online). Its body is a bot-style Player outside the match's players until it joins.

enum State { WAITING, JOINED, FALLEN }
const STATE_NAMES: PackedStringArray = ["waiting", "joined", "fallen"]

static var _pids: Dictionary = {}   # pid -> true for the map companions in this match

var id: String = ""
var cfg: Dictionary = {}           # its companions.json row
var map: MapRoot
var player: Player
var talk: CompanionTalk
var brain: BotBrain
var state: State = State.WAITING
var escort_pid: int = 1
var _mi: MoveIntent = MoveIntent.new()
var _choice: JakubChoice = null
var _call_t: float = 4.0
var _met: bool = false
var _gift_round: int = -1
var _snap_left: float = 0.0
var events: PackedStringArray = []   # tests / tools
## Online client (T-138): the body here is a puppet of the host's companion.
var puppet: bool = false
var _net_sig: Array = []


static func table() -> Dictionary:
	return GLData.table("companions")


static func entry(cid: String) -> Dictionary:
	return (table().get("companions", {}) as Dictionary).get(cid, {})


static func is_companion_pid(p: int) -> bool:
	return _pids.has(p)


## The companion ids that appear on a map (pure over the table): found there, or carried in by its flag.
static func ids_for_map(map_id: String, flags: Dictionary, tbl: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var all: Dictionary = tbl.get("companions", {})
	for cid: Variant in all.keys():
		var e: Dictionary = all[cid]
		var on_map: bool = false
		for m: Variant in e.get("maps", []):
			if map_id.begins_with(str(m)):
				on_map = true
		if not on_map:
			continue
		var found_here: bool = false
		for m2: Variant in e.get("find_on", []):
			if map_id.begins_with(str(m2)):
				found_here = true
		var cf: String = str(e.get("carry_flag", ""))
		if found_here or (cf != "" and flag_on(flags, cf)):
			out.append(str(cid))
	return out


## A world flag under either key type (Campaign.restore_flags writes StringName keys).
static func flag_on(flags: Dictionary, f: String) -> bool:
	return bool(flags.get(f, flags.get(StringName(f), false)))


static func flag_str(flags: Dictionary, f: String) -> String:
	return str(flags.get(f, flags.get(StringName(f), "")))


static func instances(tree: SceneTree) -> Array[MapCompanion]:
	var out: Array[MapCompanion] = []
	if tree != null:
		for n: Node in tree.get_nodes_in_group(&"map_companion"):
			out.append(n as MapCompanion)
	return out


static func attach(map_root: MapRoot) -> void:
	_pids.clear()
	if map_root == null:
		return   # online too (T-138): simulated on the host, a puppet on every client (CompanionNet)
	for cid: String in ids_for_map(String(map_root.map_id), GameState.flags, table()):
		var c: MapCompanion = MapCompanion.new()
		c.name = "Companion_" + cid
		map_root.add_child(c)
		c.setup(map_root, cid)


func setup(map_root: MapRoot, cid: String) -> void:
	map = map_root
	id = cid
	cfg = entry(cid)
	puppet = CompanionNet.puppet_mode()
	add_to_group(&"map_companion")
	GLBus.round_started.connect(_on_round_started)
	var cf: String = str(cfg.get("carry_flag", ""))
	var carried: bool = cf != "" and flag_on(GameState.flags, cf) and not _found_here()
	if carried:
		_make_body(_beside_spawn(1))
		var gun: String = flag_str(GameState.flags, id + "_gun")
		if gun != "" and (GLData.table("weapons").get("weapons", {}) as Dictionary).has(gun):
			player.weapons.give_weapon(StringName(gun))
		_join(1, true)
	elif RoundManager.current_round >= int(cfg.get("appear_round", 1)):
		_appear()
	else:
		_event("not_yet")   # (Trudi: she is still at the inn in round 1, then runs; she turns up in the stable after)


func _appear() -> void:
	_make_body(_spot())
	_event("waiting")
	var con: Node = get_node_or_null("/root/GLConsole")
	if con != null and con.has_method("register"):
		con.call("register", "comp_" + id, _cmd, "comp_%s status|join|down: the map companion %s (T-135)" % [id, str(cfg.get("name", id))])


func _found_here() -> bool:
	for m: Variant in cfg.get("find_on", []):
		if String(map.map_id).begins_with(str(m)):
			return true
	return false


# ================================================================== body

func _make_body(xf: Transform3D) -> void:
	var p: Player = Player.new()
	p.player_id = int(cfg.get("pid", 10))
	p.is_local = false
	p.is_bot = not puppet   # a client's companion is a puppet the host's stream moves (T-138)
	p.is_companion = true
	p.name = id.capitalize()
	GameState.characters[p.player_id] = StringName(id)
	_pids[p.player_id] = true
	map.add_child(p)
	p.global_transform = xf
	if puppet:
		CompanionNet.register_puppet(p)
	p.bleedout_seconds = float(cfg.get("bleedout_seconds", 60.0))
	p.max_hp = float(cfg.get("max_hp", 100.0))
	p.hp = p.max_hp
	p.hp_scale = p.max_hp / maxf(1.0, float(GLData.table("player").get("max_health", 100.0)))
	p.bot_damage_mult = 0.0   # nobody's target until it joins
	p.remove_from_group(&"players")
	p.remove_from_group(&"bots")
	p.add_to_group(&"companions")
	p.weapons.slots.clear()
	p.weapons.current_index = 0
	p.weapons.grenades = 0
	p.weapons.melee_id = StringName(str(cfg.get("melee", "trench_knife")))
	if p.remote_body != null:
		p.remote_body.set_weapon(p.weapons.melee_id)
	var rp: RevivePoint = RevivePoint.new()
	rp.name = "Revive"
	rp.owner_player = p
	p.add_child(rp)
	talk = CompanionTalk.new()
	talk.name = "Talk"
	talk.companion = self
	p.add_child(talk)
	player = p


## Its spot: the table's rough point snapped onto the navmesh (the maps were not rebuilt for it).
func _spot() -> Transform3D:
	var a: Array = cfg.get("spot", [0, 0, 0])
	var want: Vector3 = Vector3(float(a[0]), float(a[1]), float(a[2]))
	_snap_left = 3.0   # the navmesh syncs a few frames after load: _snap_to_nav finishes the job
	return Transform3D(Basis.IDENTITY, want + Vector3(0, 0.05, 0))


## Once the navmesh is up, onto its nearest point (only a short hop: a far answer means a wrong floor).
func _snap_to_nav(delta: float) -> void:
	_snap_left -= delta
	var w: World3D = map.get_world_3d()
	if w == null:
		return
	var nav: RID = w.navigation_map
	if NavigationServer3D.map_get_iteration_id(nav) <= 0:
		return
	var a: Array = cfg.get("spot", [0, 0, 0])
	var want: Vector3 = Vector3(float(a[0]), float(a[1]), float(a[2]))
	var at: Vector3 = NavigationServer3D.map_get_closest_point(nav, want)
	if at.distance_to(want) < 4.0:
		player.global_position = at + Vector3(0, 0.05, 0)
		player.velocity = Vector3.ZERO
		_snap_left = 0.0


func _beside_spawn(escort: int) -> Transform3D:
	var xf: Transform3D = map.spawn_transform(escort)
	xf.origin += xf.basis.z * 1.3 - xf.basis.x * 0.9   # the other side from Jakub
	return xf


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or GameState.phase != GameState.Phase.PLAYING:
		return
	if puppet:
		return   # the host runs it; _net_state / _net_say keep this body in step
	_net_sig = CompanionNet.sync(self, _net_sig, _sig())
	match state:
		State.WAITING:
			if _snap_left > 0.0:
				_snap_to_nav(delta)
			_tick_waiting(delta)
		State.JOINED:
			var s: NetMatch = Net.session
			if s != null and s.coop.is_dead(player.player_id):
				_fall()


func _tick_waiting(delta: float) -> void:
	_mi.clear()
	player.drive_bot(delta, _mi)
	var h: Player = _nearest_human(14.0)
	if h != null:
		_face(h.global_position)
	player.net_flags = NetMatch.PF_FLOOR
	if player.remote_body != null:
		player.remote_body.calm = true
		player.remote_body.update_pose(delta, 0.0, 0.0, NetMatch.PF_FLOOR)
	_call_t -= delta
	if _call_t > 0.0:
		return
	_call_t = float(table().get("call_every_s", 18.0))
	var near: Player = _nearest_human(float(table().get("call_within_m", 26.0)))
	if near != null and _flat(near.global_position, player.global_position) > float(table().get("call_unless_within_m", 6.0)):
		_say("CALL")


# ================================================================== talking

func talk_open() -> bool:
	if player == null or player.downed or player.spectating or _choice != null:
		return false
	return state == State.WAITING or state == State.JOINED


func talk_prompt(p: Player) -> String:
	if state == State.WAITING:
		return "Talk to %s" % str(cfg.get("name", id))
	var o: Dictionary = gun_offer(p)
	return ("Give %s your %s" % [_first_name(), str(o.get("name", "gun"))]) if bool(o.get("ok", false)) else ""


func can_talk(p: Player) -> bool:
	if p == null or p.is_bot or p.downed or not talk_open():
		return false
	if state == State.JOINED:
		return bool(gun_offer(p).get("ok", false))
	return true


func on_talk(p: Player) -> void:
	if not can_talk(p):
		return
	if state == State.JOINED:
		_take_gun(p)
		return
	if not _met:
		_met = true
		_say("MEET")
	if CompanionNet.is_remote_human(p):
		CompanionNet.send_card(self, p, gun_offer(p), {})   # online: the card opens on their screen (T-138)
		return
	_open_card(p)


func _open_card(p: Player) -> void:
	_choice = JakubChoice.new()
	_choice.companion = self
	_choice.player = p
	_choice.offer = gun_offer(p)
	_choice.title = str(cfg.get("title", str(cfg.get("name", id)).to_upper()))
	_choice.ask_text = str(cfg.get("ask", ""))
	_choice.unarmed_text = str(cfg.get("unarmed", "comes with you unarmed"))
	_choice.give_label = "GIVE THEM A GUN"
	_choice.timeout_s = float(table().get("choice_timeout_s", 12.0))
	map.add_child(_choice)
	_choice.tree_exited.connect(func() -> void: _choice = null)


func gun_offer(p: Player) -> Dictionary:
	if p == null or p.weapons == null:
		return {"ok": false, "code": "empty", "reason": "nothing in your hands"}
	var w: WeaponInstance = p.weapons.current()
	var code: String = JakubCompanion.offer_rule(p.weapons.slots.size() if w != null else 0, w.weapon_class() if w != null else &"",
		p.weapons.in_last_stand(), cfg.get("refuses_classes", []))
	if code == "" and w != null and not WeaponKit.companion_accepts(w):
		code = "refused"
	var reasons: Dictionary = {"down": "not while you are down", "empty": "nothing in your hands",
		"only_gun": "keep it, it's your only gun", "refused": "they won't carry that one"}
	if code != "":
		return {"ok": false, "code": code, "reason": str(reasons.get(code, code)), "name": w.display_name() if w != null else ""}
	return {"ok": true, "code": "", "name": w.display_name(), "weapon": w}


## The choice card's answer (JakubChoice; also tests): give = the gun in `p`'s hands, else it comes with its melee.
func choose(p: Player, give: bool) -> void:
	if puppet:
		CompanionNet.forward(self, &"net_by_choose", [give])   # the host's companion decides (T-138)
		return
	if state == State.JOINED:
		if give:
			_take_gun(p)
		return
	if state != State.WAITING:
		return
	var offer: Dictionary = gun_offer(p)
	_join(p.player_id, false)
	if give and bool(offer.get("ok", false)):
		_take_gun(p)
	else:
		_say("JOIN_UNARMED")


func choose_tonic(_p: Player) -> bool:
	return false   # (the choice card's tonic line never shows for a map companion)


func _take_gun(p: Player) -> void:
	if puppet:
		return
	var o: Dictionary = gun_offer(p)
	if not bool(o.get("ok", false)):
		return
	var w: WeaponInstance = p.weapons.remove_current()
	if w == null:
		return
	var old: WeaponInstance = player.weapons.current()
	player.weapons.slots.clear()
	player.weapons.slots.append(w)
	player.weapons.current_index = 0
	if old != null and p.weapons.find_weapon(old.id) == null:
		p.weapons.give_instance(old)   # its old gun goes back to you
	if brain != null:
		brain.options["armed"] = true
	if player.remote_body != null:
		player.remote_body.set_weapon(w.id)
	_note_gun()
	_event("armed:%s" % w.id)
	_say("JOIN_ARMED")


func _note_gun() -> void:
	var cf: String = str(cfg.get("carry_flag", ""))
	var w: WeaponInstance = player.weapons.current()
	if cf != "" and w != null:
		GameState.flags[StringName(id + "_gun")] = String(w.id)   # carried to the next act (campaign.json carry_flags "<id>_*")


# ================================================================== the squad

func brain_options(escort: int, armed: bool) -> Dictionary:
	var o: Dictionary = (table().get("brain", {}) as Dictionary).duplicate(true)
	o["personality"] = str(cfg.get("personality", "jakub"))
	o["escort_pid"] = escort
	o["ammo_payer_pid"] = escort
	o["armed"] = armed
	return o


func _join(escort: int, arrival: bool) -> void:
	if state != State.WAITING or puppet:
		return
	escort_pid = escort if escort > 0 else 1
	var squad: BotSquad = map.ensure_companion_session()
	if squad == null or Net.session == null:
		return
	state = State.JOINED
	Net.session.add_companion(player)
	player.add_to_group(&"players")
	player.add_to_group(&"bots")
	player.bot_damage_mult = float(table().get("damage_taken", 0.6))   # sturdier than a squad bot: it has no perks
	brain = squad.add_brain(player, brain_options(escort_pid, not player.weapons.slots.is_empty()))
	var cf: String = str(cfg.get("carry_flag", ""))
	if cf != "":
		GameState.flags[StringName(cf)] = true
	_event("joined")
	if arrival:
		_later(4.0, "ARRIVE")
	elif map.hud != null:
		map.hud.show_banner(str(cfg.get("banner", "%s JOINS YOU" % str(cfg.get("name", id)).to_upper())), 3.0)


func _fall() -> void:
	state = State.FALLEN
	_event("fallen")
	if brain != null and map.squad != null:
		map.squad.remove_brain(brain)
	brain = null
	player.remove_from_group(&"players")
	player.remove_from_group(&"bots")
	if Net.session != null:
		Net.session.remove_companion(player.player_id)
	var cf: String = str(cfg.get("carry_flag", ""))
	if cf != "":
		GameState.flags[StringName(cf)] = false   # out cold: left behind
	_say("FALLEN")
	if map.hud != null:
		map.hud.show_banner("%s is out cold." % _first_name(), 3.0)


## The round's gift to the one it follows, while they stand near (not on round 1, not while either is down).
func _on_round_started(r: int, _special: bool) -> void:
	if player == null:
		if r >= int(cfg.get("appear_round", 1)):
			_appear()
		return
	if puppet:
		return   # gifts are the host's
	if state != State.JOINED or r == _gift_round or player.downed:
		return
	var h: Player = map.players.get(escort_pid) as Player
	if h == null or h.downed or _flat(h.global_position, player.global_position) > float(table().get("gift_range_m", 15.0)):
		return
	if give_gift(h):
		_gift_round = r
		_later(1.5, "GIFT")


## Applies its gift kind to `h`; false when it would be wasted (full grenades, no gun).
func give_gift(h: Player) -> bool:
	match str(cfg.get("gift", "")):
		"grenade":
			if not h.weapons.gift_grenade():   # (forwarded to a remote teammate's own holder online, T-138)
				return false
		"ammo":
			if not h.weapons.gift_mag():
				return false
		"scrip":
			Economy.grant(h.player_id, int(cfg.get("gift_scrip", 250)))
		_:
			return false
	_event("gift:" + str(cfg.get("gift", "")))
	return true


# ================================================================== helpers

func _say(category: String) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var ok: bool = GLVO.play_category(StringName(str(cfg.get("speaker", ""))), "COMP_" + category, 1.0, player.player_id)
	if ok and Net.replicating():
		Net.mirror(self, &"_net_say", [category])   # online: its line on every client too (T-138)
	return ok


# ================================================================== online (T-138, CompanionNet)

## What the clients mirror: [state, the weapon on its body].
func _sig() -> Array:
	var w: WeaponInstance = player.weapons.current() if player != null and player.weapons != null else null
	return [int(state), String(w.id) if w != null else String(player.weapons.melee_id)]


## Client: the host's companion changed state / weapon.
func _net_state(st: int, wid: String) -> void:
	if player == null or not is_instance_valid(player):
		return
	var was: State = state
	state = st as State
	if player.remote_body != null:
		player.remote_body.set_weapon(StringName(wid))
	if state == State.JOINED and was != State.JOINED:
		_event("joined")
		if map.hud != null:
			map.hud.show_banner(str(cfg.get("banner", "%s JOINS YOU" % str(cfg.get("name", id)).to_upper())), 3.0)
	elif state == State.FALLEN and was != State.FALLEN:
		_event("fallen")
		if map.hud != null:
			map.hud.show_banner("%s is out cold." % _first_name(), 3.0)


func _net_say(category: String) -> void:
	if player != null and is_instance_valid(player):
		GLVO.play_category(StringName(str(cfg.get("speaker", ""))), "COMP_" + category, 1.0, player.player_id)


## Client: the host opened its choice card for us.
func _net_card(_offer: Dictionary, _tonic: Dictionary) -> void:
	var me: Player = map.player
	if me == null or not is_instance_valid(me):
		return
	if DisplayServer.get_name() == "headless":
		choose(me, bool(gun_offer(me).get("ok", false)))
		return
	_open_card(me)


func net_callable() -> Array:
	return ["net_by_choose"]


## Host: a client's card answer (the pid comes from the connection).
func net_by_choose(pid: int, give: bool) -> void:
	var p: Player = CompanionNet.player_for(pid)
	if p != null:
		choose(p, give)


func _later(seconds: float, category: String) -> void:
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if is_instance_valid(self) and state != State.FALLEN:
			_say(category))


func _first_name() -> String:
	var n: String = str(cfg.get("name", id))
	var q: int = n.find("\"")
	if q >= 0:
		return n.substr(q + 1, n.find("\"", q + 1) - q - 1)
	var parts: PackedStringArray = n.replace("Fw. ", "").split(" ")
	return parts[0]


func _event(e: String) -> void:
	events.append(e)


func _face(p: Vector3) -> void:
	var d: Vector3 = p - player.global_position
	d.y = 0.0
	if d.length() > 0.05:
		player.rotation.y = lerp_angle(player.rotation.y, atan2(-d.x, -d.z), 0.2)


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


func _cmd(a: PackedStringArray) -> String:
	match a[0] if a.size() > 0 else "status":
		"join":
			_join(1, false)
		"down":
			if state == State.JOINED:
				player.take_hit(9999.0, null)
		"tp":
			var h: Player = map.players.get(1) as Player
			if h != null:
				player.global_position = h.global_position + h.global_basis.z * 2.0
	return "%s: %s at %s" % [id, state_name(), str(player.global_position.snapped(Vector3.ONE * 0.1)) if player != null else "-"]
