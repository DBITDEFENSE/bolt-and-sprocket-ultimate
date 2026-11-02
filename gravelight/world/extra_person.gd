class_name ExtraPerson
extends Node3D
## T-143: one of the extra people (data/gravelight/people_extra.json; ExtraPeople.attach): miners hiding, a field medic
## and a switchboard operator on Kaltenbrunn, a deserter, a carter's widow and a courier on Map 0. A person stands
## where the table puts them (PatronBody bodies: a modelled person from people.json, no collider), shows a Talk card
## (PersonCard), may ask one favour and reacts to round starts, downs, the dead close by and, for some, to Jakub
## or the Operator's slips. Favours: fetch (an item lies somewhere on the map once you accepted: Interactable
## FavourItem; bring it back), gun (hand over the gun in your hands), deliver (T-158: accepting hands you the thing;
## carry it to where it belongs, a TagSlot, which ends the favour). Rewards (reward.kind): scrip_mark, revive_point,
## intel_ping, cover, unbolt_door; the courier sells a tip (trade.kind crate_tip). Offline only.

enum Favour { NONE, ASKED, HAVE, DONE }

var id: String = ""
var cfg: Dictionary = {}
var map: MapRoot
var bodies: Array[PatronBody] = []
var favour: Favour = Favour.NONE
var rounds_left: int = 0            # a timed reward's rounds (medic, deserter's cover, the widow's bolt)
var events: PackedStringArray = []  # tests / tools
var lines_said: int = 0
var talk: ExtraTalk
var item: FavourItem
var marker_id: int = -1
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _said_at: Dictionary = {}
var _last_line: String = ""
var _scared_t: float = 0.0
var _check_t: float = 0.0
var _shot_t: float = 0.0
var _serve_t: float = 0.0
var _trade_round: int = -1
var _door: BuyDoor = null
var _door_cost: int = 0
var _jakub_said: bool = false
var _gun_id: StringName = &""
var _card: PersonCard = null


func setup(map_root: MapRoot, pid: String) -> void:
	map = map_root
	id = pid
	cfg = ExtraPeople.people().get(pid, {})
	_rng.seed = hash("extra_" + pid)
	add_to_group(&"extra_people")
	var bodies_cfg: Array = cfg.get("bodies", [])
	for i: int in bodies_cfg.size():
		var b: Dictionary = bodies_cfg[i]
		if not bool(b.get("body", true)):
			continue   # T-156: a talk point with no body of its own (Ruhland at the Bordkasse, whose teller is BankBranch's; Riedl on the intercom)
		var pb: PatronBody = PatronBody.new()
		pb.name = "Body%d" % i
		add_child(pb)
		pb.global_position = ExtraPeople.vec(b.get("at", [0, 0, 0]))
		pb.rotation.y = deg_to_rad(float(b.get("yaw", 0.0)))
		var row: Dictionary = {"id": str(b.get("person", "wiesner")), "person": str(b.get("person", "wiesner")),
			"look": b.get("look", {}), "pose": str(b.get("pose", "stand"))}
		pb.setup(row)
		bodies.append(pb)
	talk = ExtraTalk.new()
	talk.name = "Talk"
	talk.person = self
	add_child(talk)
	talk.global_position = ExtraPeople.vec((bodies_cfg[0] as Dictionary).get("at", [0, 0, 0]))
	GLBus.round_started.connect(_on_round_started)
	GLBus.player_downed.connect(_on_player_downed)
	GLBus.vo_line_started.connect(_on_vo_line)
	GLBus.weapon_fired.connect(_on_shot)
	_poi_marker()
	_event("waiting")
	var con: Node = get_node_or_null("/root/GLConsole")
	if con != null and con.has_method("register"):
		con.call("register", "person_" + id, _cmd, "person_%s status|done|reward: the extra person %s (T-143)" % [id, str(cfg.get("name", id))])


## The minimap point of interest: a note marker with the person's POI label (MapState markers; limits are ours).
func _poi_marker() -> void:
	var ms: MapState = MapState.current()
	if ms == null:
		return
	marker_id = ms.add_marker({"pos": talk.global_position, "kind": "note", "label": str(cfg.get("poi", cfg.get("name", id))),
		"color": Color(0.85, 0.72, 0.38), "owner": 0, "target": "me"})


func first_name() -> String:
	return str(cfg.get("display", id)).capitalize()


func spot() -> Vector3:
	return talk.global_position if talk != null else global_position


# ================================================================== talking

func can_talk(p: Player) -> bool:
	if not present():
		return false
	return p != null and not p.is_bot and not p.downed and not p.spectating and _card == null


## T-156: a person who is only there until an act round (Riedl answers the intercom until he is the Bordwart).
func present() -> bool:
	if cfg.has("until_act_round") and RoundManager.act_round() >= int(cfg["until_act_round"]):
		return false
	return true


func talk_prompt(_p: Player) -> String:
	return "Talk to %s" % str(cfg.get("name", id))


func on_talk(p: Player) -> void:
	if not can_talk(p):
		return
	say("talk")
	var card: PersonCard = PersonCard.new()
	card.player = p
	card.title = str(cfg.get("title", id.to_upper()))
	card.bio = str(cfg.get("bio", ""))
	card.close_after_s = float(ExtraPeople.cfg().get("card_close_s", 25.0))
	var fav: Dictionary = cfg.get("favour", {})
	var opts: Array = []
	if cfg.has("trade"):
		var tr: Dictionary = cfg["trade"]
		var open: bool = ExtraPeople.trade_open(_trade_round, RoundManager.current_round, bool(tr.get("once_per_round", true)))
		card.said = "A tip about the Crate costs %d Scrip, once a round." % int(tr.get("cost", 200)) if open else "She has given you this round's tip."
		opts.append({"action": &"interact", "label": "BUY THE TIP  (ǂ %d)" % int(tr.get("cost", 200)), "call": buy_tip, "enabled": open})
	elif fav.is_empty():
		card.said = str(cfg.get("said", ""))   # T-156: a voice with no favour to ask (Riedl on the intercom)
	elif fav.get("kind", "") == "gun":
		var offer: Dictionary = gun_offer(p)
		card.said = str(fav.get("done" if favour == Favour.DONE else "ask", ""))
		if favour != Favour.DONE:
			opts.append({"action": &"interact", "label": ("GIVE HIM YOUR %s" % str(offer.get("name", "gun")).to_upper()) if bool(offer.get("ok", false)) else "GIVE HIM A GUN  (%s)" % str(offer.get("reason", "")),
				"call": give_gun, "enabled": bool(offer.get("ok", false))})
	else:
		match favour:
			Favour.NONE:
				card.said = str(fav.get("ask", ""))
				opts.append({"action": &"interact", "label": "I WILL DO IT", "call": accept_favour, "enabled": true})
			Favour.ASKED:
				card.said = str(fav.get("ask", ""))
			Favour.HAVE:
				card.said = str(fav.get("have", ""))
				if fav.get("kind", "") != "deliver":   # T-158: a delivered favour ends where it is taken (TagSlot), not here
					opts.append({"action": &"interact", "label": "GIVE THE %s" % str(fav.get("item_name", "item")).to_upper(), "call": give_item, "enabled": true})
			Favour.DONE:
				card.said = str(fav.get("done", ""))
	card.options = opts
	_card = card
	map.add_child(card)
	card.tree_exited.connect(func() -> void: _card = null)


func accept_favour(_p: Player = null) -> void:
	if favour != Favour.NONE:
		return
	favour = ExtraPeople.favour_next(favour, "accept") as Favour
	_event("asked")
	say("ask")
	if str((cfg.get("favour", {}) as Dictionary).get("kind", "")) == "deliver":
		# T-158 (Pohl): you leave with the thing at once; the favour ends where it is delivered (a TagSlot calls give_item)
		item_taken(_p)
		return
	if item == null:
		item = FavourItem.new()
		item.name = "Item_" + id
		item.person = self
		add_child(item)
		item.global_position = ExtraPeople.vec((cfg.get("favour", {}) as Dictionary).get("item_at", [0, 0, 0]))
	item.show_item()
	if map.hud != null:
		map.hud.show_banner("FAVOUR: find the %s" % str((cfg.get("favour", {}) as Dictionary).get("item_name", "item")), 3.0)


func item_taken(_p: Player) -> void:
	if favour != Favour.ASKED:
		return
	favour = ExtraPeople.favour_next(favour, "item") as Favour
	_event("item")
	if item != null:
		item.hide_item()
	if map.hud != null:
		map.hud.show_banner("YOU TAKE THE %s" % str((cfg.get("favour", {}) as Dictionary).get("item_name", "item")).to_upper(), 2.5)


func give_item(p: Player = null) -> void:
	if favour != Favour.HAVE:
		return
	favour = ExtraPeople.favour_next(favour, "give") as Favour
	_event("done")
	say("thanks")
	_reward(p)


# ================================================================== the gun favour (the deserter)

func gun_offer(p: Player) -> Dictionary:
	if p == null or p.weapons == null:
		return {"ok": false, "code": "empty", "reason": "nothing in your hands"}
	var w: WeaponInstance = p.weapons.current()
	var code: String = JakubCompanion.offer_rule(p.weapons.slots.size() if w != null else 0, w.weapon_class() if w != null else &"",
		p.weapons.in_last_stand(), ["wonder"])
	if code == "" and w != null and not WeaponKit.companion_accepts(w):
		code = "refused"
	var reasons: Dictionary = {"down": "not while you are down", "empty": "nothing in your hands",
		"only_gun": "keep it, it's your only gun", "refused": "he won't carry that one"}
	if code != "":
		return {"ok": false, "code": code, "reason": str(reasons.get(code, code)), "name": w.display_name() if w != null else ""}
	return {"ok": true, "code": "", "name": w.display_name(), "weapon": w}


func give_gun(p: Player = null) -> void:
	if favour == Favour.DONE or not bool(gun_offer(p).get("ok", false)):
		return
	var w: WeaponInstance = p.weapons.remove_current()
	if w == null:
		return
	_gun_id = w.id
	favour = Favour.DONE
	_event("armed:%s" % w.id)
	say("thanks")
	_reward(p)


# ================================================================== rewards

func _reward(p: Player) -> void:
	var r: Dictionary = (cfg.get("favour", {}) as Dictionary).get("reward", {})
	var pid: int = p.player_id if p != null else 1
	match str(r.get("kind", "")):
		"scrip_mark":
			Economy.grant(pid, int(r.get("scrip", 0)))
			var ms: MapState = MapState.current()
			if ms != null and r.has("mark"):
				ms.add_marker({"pos": ExtraPeople.vec(r["mark"]), "kind": "go", "label": str(r.get("mark_label", "")),
					"color": Color(0.85, 0.72, 0.38), "owner": 0, "target": "me"})
			_event("reward:scrip_mark")
		"revive_point":
			rounds_left = ExtraPeople.rounds_after_grant(int(r.get("rounds", 2)), RoundManager.state == RoundManager.State.ROUND)
			_event("reward:revive_point")
		"intel_ping":
			var ms2: MapState = MapState.current()
			var n: int = 0
			if ms2 != null:
				n = ms2.reveal_zombies(spot(), float(r.get("radius_m", 60.0)), float(r.get("seconds", 8.0)))
			say("ping")
			_event("reward:intel_ping:%d" % n)
		"cover":
			rounds_left = ExtraPeople.rounds_after_grant(int(r.get("rounds", 1)), RoundManager.state == RoundManager.State.ROUND)
			if bodies.size() > 0:
				bodies[0].set_pose(&"aim")
				bodies[0].show_rifle(true)
			_event("reward:cover")
		"unbolt_door":
			_unbolt(r, pid)
	if map.hud != null:
		map.hud.show_banner(str((cfg.get("favour", {}) as Dictionary).get("done", "")).split(".")[0].to_upper(), 3.5)


func _unbolt(r: Dictionary, pid: int) -> void:
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		var d: BuyDoor = n as BuyDoor
		if d != null and String(d.door_id) == str(r.get("door", "")) and not d.is_open:
			_door = d
			_door_cost = d.cost
			d.set_cost(0)
			rounds_left = ExtraPeople.rounds_after_grant(int(r.get("rounds", 2)), RoundManager.state == RoundManager.State.ROUND)
			say("bolt")
			_event("reward:unbolt_door")
			return
	Economy.grant(pid, int(r.get("fallback_scrip", 300)))   # the door is already open: a purse instead
	_event("reward:scrip_fallback")


## The courier's tip: Scrip for a marker on the Requisition Crate where it stands now (and a line).
func buy_tip(p: Player = null) -> void:
	var tr: Dictionary = cfg.get("trade", {})
	var pid: int = p.player_id if p != null else 1
	if not ExtraPeople.trade_open(_trade_round, RoundManager.current_round, bool(tr.get("once_per_round", true))):
		say("once")
		return
	var cost: int = int(tr.get("cost", 200))
	if Economy.get_scrip(pid) < cost:
		say("broke")
		AudioDirector.play_2d("deny", -4.0)
		_event("broke")
		return
	if not Economy.spend(pid, &"extra_tip", cost):
		return
	_trade_round = RoundManager.current_round
	var where: Vector3 = spot()
	for n: Node in get_tree().get_nodes_in_group(&"crate_spots"):
		var mc: MysteryCrate = n as MysteryCrate
		if mc != null and mc.spot_index == CrateManager.location_index:
			where = mc.global_position
	var ms: MapState = MapState.current()
	if ms != null:
		var mid: int = ms.add_marker({"pos": where, "kind": "collect", "label": "Crate (the courier's tip)", "color": Color(0.85, 0.72, 0.38), "owner": 0, "target": "me"})
		get_tree().create_timer(float(tr.get("tip_seconds", 90.0))).timeout.connect(func() -> void:
			if MapState.current() != null:
				MapState.current().remove_marker(mid))
	say("tip")
	if map.hud != null:
		map.hud.show_banner("THE REQUISITION CRATE IS MARKED ON YOUR MAP", 3.5)
	_event("tip")


# ================================================================== the world around them

func _physics_process(delta: float) -> void:
	_scared_t = maxf(0.0, _scared_t - delta)
	_check_t -= delta
	if _check_t <= 0.0:
		_check_t = 0.4
		_react_to_dead()
	if rounds_left > 0 and GameState.phase == GameState.Phase.PLAYING:
		match str((cfg.get("favour", {}) as Dictionary).get("reward", {}).get("kind", "")):
			"revive_point":
				_serve(delta)
			"cover":
				_cover(delta)


func _react_to_dead() -> void:
	if map == null or map.director == null:
		return
	var near: bool = false
	var r: float = float(ExtraPeople.cfg().get("scared_m", 8.0))
	for z: Variant in map.director.active_zombies():
		if is_instance_valid(z) and (z as Node3D).global_position.distance_to(spot()) < r:
			near = true
			break
	for i: int in bodies.size():
		var calm: StringName = StringName(str((cfg.get("bodies", [])[i] as Dictionary).get("pose", "stand")))
		if rounds_left > 0 and str((cfg.get("favour", {}) as Dictionary).get("reward", {}).get("kind", "")) == "cover" and i == 0:
			bodies[i].set_pose(&"aim")
		else:
			bodies[i].set_pose(&"cower" if near or _scared_t > 0.0 else calm)


func _on_shot(_p: int, _w: StringName, _u: bool, origin: Vector3, _d: Vector3) -> void:
	if origin.distance_to(spot()) < 9.0:
		_scared_t = 2.0
		for b: PatronBody in bodies:
			b.flinch()


func _on_round_started(r: int, _special: bool) -> void:
	if rounds_left > 0:
		rounds_left = ExtraPeople.rounds_after_start(rounds_left)
		if rounds_left == 0:
			_end_reward()
	if _human_near(float(ExtraPeople.cfg().get("near_m", 25.0))) != null and r > 1:
		say("round")
	_maybe_jakub()


func _end_reward() -> void:
	if _door != null and is_instance_valid(_door) and not _door.is_open:
		_door.set_cost(_door_cost)
	_door = null
	if bodies.size() > 0 and str((cfg.get("favour", {}) as Dictionary).get("reward", {}).get("kind", "")) == "cover":
		bodies[0].show_rifle(false)
	_event("reward_ended")


func _on_player_downed(pid: int) -> void:
	var p: Player = map.players.get(pid) as Player if map != null else null
	if p != null and p.global_position.distance_to(spot()) < float(ExtraPeople.cfg().get("near_m", 25.0)):
		say("down")


## The Operator's slips are relayed by the switchboard operator (cfg.relay): "someone is counting on this line".
func _on_vo_line(line_id: StringName, speaker: StringName, _text: String, _dur: float) -> void:
	var rel: Dictionary = cfg.get("relay", {})
	if rel.is_empty() or String(speaker) != str(rel.get("speaker", "OPR")) or not String(line_id).contains("SLIP"):
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now < float(_said_at.get("_relay", -INF)) + float(rel.get("cooldown_s", 40.0)):
		return
	if _human_near(float(ExtraPeople.cfg().get("near_m", 25.0)) * 2.0) == null:
		return
	if _rng.randf() <= float(rel.get("chance", 0.7)) or GLVO.always_pass_chance:
		_said_at["_relay"] = now
		get_tree().create_timer(2.5).timeout.connect(func() -> void:
			if is_instance_valid(self):
				say("relay", true))


## Jakub, if he is with you, knows the miners: once, in the same room.
func _maybe_jakub() -> void:
	if _jakub_said or str(cfg.get("jakub_line", "")) == "":
		return
	var jk: JakubCompanion = JakubCompanion.instance(get_tree())
	if jk == null or jk.state != JakubCompanion.State.JOINED or jk.player == null:
		return
	if jk.player.global_position.distance_to(spot()) > 20.0:
		return
	_jakub_said = true
	say("jakub", true)
	get_tree().create_timer(4.0).timeout.connect(func() -> void:
		if is_instance_valid(self):
			_say_id(str(cfg.get("jakub_line", "")), jk.player.global_position + Vector3.UP * 1.6, "JAKUB"))
	_event("jakub")


# The medic: anyone downed within reach for two rounds is got up after a few seconds.
func _serve(delta: float) -> void:
	var r: Dictionary = (cfg.get("favour", {}) as Dictionary).get("reward", {})
	var down: Player = null
	for k: Variant in map.players.keys():
		var p: Player = map.players[k] as Player
		if p != null and p.downed and p.global_position.distance_to(spot()) <= float(r.get("range_m", 9.0)) \
				and Net.session != null and Net.session.coop.is_downed(p.player_id):
			down = p
			break
	if down == null:
		_serve_t = 0.0
		return
	if _serve_t == 0.0:
		say("serve")
	_serve_t += delta
	if _serve_t >= float(r.get("delay_s", 2.5)):
		_serve_t = 0.0
		if Net.session.coop.revive(down.player_id):
			down.revive(0)
			_event("revived:%d" % down.player_id)
			say("serve", true)


# The deserter: shoots the nearest zombie in sight within range, the table's pace.
func _cover(delta: float) -> void:
	_shot_t -= delta
	if _shot_t > 0.0 or map.director == null or _gun_id == &"" or bodies.is_empty():
		return
	var r: Dictionary = (cfg.get("favour", {}) as Dictionary).get("reward", {})
	var from: Vector3 = spot() + Vector3.UP * 1.4
	var best: Zombie = null
	var bd: float = float(r.get("range_m", 18.0))
	for z: Zombie in map.director.active_zombies():
		if not is_instance_valid(z) or not z.is_active():
			continue
		var d: float = z.global_position.distance_to(spot())
		if d >= bd:
			continue
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, z.global_position + Vector3.UP * 1.3, 1 | (1 << 8))
		if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			continue
		bd = d
		best = z
	if best == null:
		return
	_shot_t = float(r.get("fire_interval", 1.4))
	var to: Vector3 = best.global_position - spot()
	to.y = 0.0
	if to.length() > 0.05:
		bodies[0].rotation.y = atan2(-to.x, -to.z)
	if _rng.randf() < float(r.get("hit_chance", 0.75)):
		var w: Dictionary = (GLData.table("weapons").get("weapons", {}) as Dictionary).get(String(_gun_id), {})
		best.take_damage(float(w.get("damage", 80.0)) * float(r.get("damage_mult", 1.0)), &"torso", _gun_id, 0, &"bullet")
	if _rng.randf() < 0.3:
		say("cover")


# ================================================================== voice

func say(kind: String, force: bool = false) -> void:
	if not present():
		return
	var ids: Array = (cfg.get("lines", {}) as Dictionary).get(kind, [])
	if ids.is_empty():
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if not force and now < float(_said_at.get(kind, -INF)) + float(ExtraPeople.cfg().get("line_gap_s", 6.0)):
		return
	var pool: Array = ids.filter(func(i: Variant) -> bool: return GLVO.lines.has(str(i)) and str(i) != _last_line)
	if pool.is_empty():
		pool = ids.filter(func(i2: Variant) -> bool: return GLVO.lines.has(str(i2)))
	if pool.is_empty():
		return
	_said_at[kind] = now
	_say_id(str(pool[_rng.randi_range(0, pool.size() - 1)]), spot() + Vector3.UP * 1.6, str(cfg.get("display", id)))


func _say_id(line: String, at: Vector3, display: String) -> void:
	if not GLVO.lines.has(line):
		return
	_last_line = line
	var rec: Dictionary = GLVO.lines[line]
	var text: String = GLVO.strip_tags(str(rec.get("text", "")))
	var dur: float = GLVO.duration_for(text, GLVO.rules)
	var path: String = GLVO.audio_path(StringName(line))
	if path != "":
		var stream: AudioStream = GLVO.load_stream(path)
		if stream != null:
			var ap: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
			ap.bus = &"VO"
			ap.stream = stream
			ap.unit_size = 5.0
			ap.max_distance = 30.0
			add_child(ap)
			ap.global_position = at
			ap.play()
			ap.finished.connect(ap.queue_free)
			dur = maxf(dur, stream.get_length())
	lines_said += 1
	GLBus.vo_line_started.emit(StringName(line), StringName(display), text, dur)


# ================================================================== helpers

func _human_near(r: float) -> Player:
	if map == null:
		return null
	for k: Variant in map.players.keys():
		var p: Player = map.players[k] as Player
		if p != null and not p.is_bot and p.global_position.distance_to(spot()) < r:
			return p
	return null


func _event(e: String) -> void:
	events.append(e)


func state_name() -> String:
	return ["none", "asked", "have", "done"][favour]


func _cmd(a: PackedStringArray) -> String:
	match a[0] if a.size() > 0 else "status":
		"done":
			if favour == Favour.NONE:
				accept_favour()
			if favour == Favour.ASKED:
				item_taken(map.player)
			give_item(map.player)
		"reward":
			_reward(map.player)
	return "%s: favour %s, %d rounds left, at %s" % [id, state_name(), rounds_left, str(spot().snapped(Vector3.ONE * 0.1))]


## "Talk to <name>" on a person (Interactable).
class ExtraTalk extends Interactable:
	var person: ExtraPerson

	func _ready() -> void:
		interact_size = Vector3(1.4, 1.9, 1.4)
		interact_offset = Vector3(0, 0.95, 0)
		super._ready()

	func get_prompt(player: Player) -> String:
		return person.talk_prompt(player) if person != null and person.can_talk(player) else ""

	func can_interact(player: Player) -> bool:
		return person != null and person.can_talk(player)

	func hold_time(_player: Player) -> float:
		return float(ExtraPeople.cfg().get("talk_hold_s", 0.35))

	func interact(player: Player) -> void:
		if person != null:
			person.on_talk(player)


## The thing a favour sends you to fetch: a small prop with a prompt, hidden until the favour is accepted.
class FavourItem extends Interactable:
	var person: ExtraPerson
	var shown: bool = false

	func _ready() -> void:
		interact_size = Vector3(0.9, 0.9, 0.9)
		interact_offset = Vector3(0, 0.3, 0)
		super._ready()
		hide_item()

	func build_greybox() -> void:
		var kind: String = str((person.cfg.get("favour", {}) as Dictionary).get("item", "lamp")) if person != null else "lamp"
		match kind:
			"bandages":
				_box(Vector3(0.42, 0.2, 0.3), Vector3(0, 0.1, 0), Color(0.86, 0.84, 0.78))
				_box(Vector3(0.44, 0.04, 0.32), Vector3(0, 0.2, 0), Color(0.5, 0.36, 0.22))
			"valve":
				_box(Vector3(0.1, 0.04, 0.1), Vector3(0, 0.02, 0), Color(0.7, 0.55, 0.25))
				_ball(0.045, Vector3(0, 0.1, 0), Color(0.7, 0.75, 0.78, 0.6))
			_:
				_box(Vector3(0.16, 0.04, 0.16), Vector3(0, 0.02, 0), Color(0.18, 0.18, 0.18))
				_box(Vector3(0.1, 0.2, 0.1), Vector3(0, 0.14, 0), Color(0.9, 0.72, 0.36, 0.7))
				_box(Vector3(0.12, 0.03, 0.12), Vector3(0, 0.26, 0), Color(0.18, 0.18, 0.18))
				var l: OmniLight3D = OmniLight3D.new()
				l.light_color = Color(1.0, 0.74, 0.46)
				l.light_energy = 0.7
				l.omni_range = 3.5
				l.position = Vector3(0, 0.2, 0)
				add_child(l)

	func _box(size: Vector3, pos: Vector3, col: Color) -> void:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = 0.8
		if col.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_override = m
		mi.position = pos
		add_child(mi)

	func _ball(r: float, pos: Vector3, col: Color) -> void:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = r
		sm.height = r * 2.0
		mi.mesh = sm
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = col
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_override = m
		mi.position = pos
		add_child(mi)

	func show_item() -> void:
		shown = true
		visible = true
		if area != null:
			area.collision_layer = LAYER_INTERACTABLE

	func hide_item() -> void:
		shown = false
		visible = false
		if area != null:
			area.collision_layer = 0

	func get_prompt(_player: Player) -> String:
		return ("Take the %s" % str((person.cfg.get("favour", {}) as Dictionary).get("item_name", "item"))) if shown else ""

	func can_interact(player: Player) -> bool:
		return shown and player != null and not player.is_bot

	func interact(player: Player) -> void:
		if shown and person != null:
			person.item_taken(player)
