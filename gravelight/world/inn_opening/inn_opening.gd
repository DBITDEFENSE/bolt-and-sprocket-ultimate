class_name InnOpening
extends Node3D
## Map 0's round 1 opening, "the bar empties" (T-072; data: data/gravelight/map00_opening.json, which documents the
## beats). The inn's patrons are in the taproom from the start. When round 1 begins (the first match start on the
## map; never a later round, a dev skip or a campaign arrival) the first zombies hit the windows and the patrons run
## for the front door and out into the snow. Two attackers rise out of the snow by the porch; two patrons are
## caught, one is bitten at the door; those three rise as zombies a few seconds after they fall.
##
## Round accounting: when round 1 starts the host takes the risers' and the attackers' slots off the round's queue
## (RoundManager.take_spawn), so they count toward round 1's total and the round can't end before they are dealt
## with; a slot that is never used (a full pool, a cancelled opening) goes back to the queue (requeue). The round's
## total never changes, so round 1 plays the same size as ever (8 zombies solo) with three of them risen patrons.
##
## The player keeps control throughout (not a cutscene); patrons are presentation only (PatronBody: no collider, no
## hitboxes, immune to fire, ignored by bots). Co-op: the host decides and mirrors the start (or the cancel); every
## peer runs the same timed script from the data, so patrons, the door and the lines match; the zombies are the
## host's and replicate as usual. Lines are lines.json ids (VO_SCRIPT section 21): baked audio plays at the patron
## when it exists, the subtitle always shows.
##
## Being seen (T-076): the opening owns round 1's intro. The host holds RoundManager's intro timer until the player
## has had `look.min_seconds` of settled view (look_ready), is facing the front door (or `look.max_seconds` passed)
## and no patron is mid-line; then the cue (a pounding at the window and the door, Kubiak's "What was that?") plays
## on every peer and round 1 starts `look.cue_lead` seconds later. The patrons chat at the tables meanwhile.
##
## The title card (T-184): while that settled view runs, the opening is framed like a film's first shot without taking
## anything from the player: the letterbox slides in, the HUD steps aside, the place / where / when card is typed in
## (data `title_card`), and all of it slides away at `until` or at the cue, whichever is first. The player keeps their
## hands, the camera and every timing; nothing here touches the patrons, the door or round 1.

const DATA_PATH: String = "res://data/gravelight/map00_opening.json"

enum Phase { IDLE, RUNNING, DONE, CANCELLED }

var phase: Phase = Phase.IDLE
var cfg: Dictionary = {}
## Seconds since round 1 started (RUNNING), and since the patrons appeared.
var t: float = 0.0
var since_ready: float = 0.0
var patrons: Dictionary = {}      # id -> PatronBody
var door: InnFrontDoor = null
## Host bookkeeping, for tests and the smoke: patron id -> reserved round spec, attacker index -> spec.
var riser_specs: Dictionary = {}
var attacker_specs: Dictionary = {}
var risen: Dictionary = {}        # patron id -> Zombie
var attackers: Dictionary = {}    # attacker index -> Zombie
var fates: Dictionary = {}        # patron id -> "escaped" / "dead" / "risen"
var slots_returned: int = 0
var _st: Dictionary = {}          # patron id -> runtime state
var _done_lines: Dictionary = {}
var _done_sfx: Dictionary = {}
var _door_beats: Dictionary = {}
var _arriving: bool = false
var _flared: bool = false
## T-076: seconds of settled view before round 1 (each frame counts at most look.frame_cap), when the last intro
## line ends, whether the gate has opened (no new chatter starts) and whether the cue has played.
var settle_t: float = 0.0
var _busy_until: float = 0.0
var _gate_open: bool = false
var cued: bool = false
var _cue_sfx_left: Array = []
## T-100: when the current intro line started (settle seconds) and its voice, so the cue can cut it short.
var _line_start: float = -1.0
var _line_voice: AudioStreamPlayer3D = null
var _last_voice: AudioStreamPlayer3D = null
## T-184: the opening's title card (a CinemaOverlay while it shows) and its clock (-1 = none / over).
var _card: CinemaOverlay = null
var _card_t: float = -1.0
var _card_titled: bool = false


static func load_cfg() -> Dictionary:
	return GLData.load_json(DATA_PATH)


## The rule: only on the configured round of the configured map, only once, never on a campaign arrival.
static func should_play(map_id: StringName, round_number: int, current_round: int, arriving: bool, already: bool, c: Dictionary) -> bool:
	if already or arriving or c.is_empty():
		return false
	if String(map_id) != str(c.get("map", "")):
		return false
	var r: int = int(c.get("round", 1))
	return round_number == r and current_round == r


## T-076: may the cue play (and round 1 start)? After `min_seconds` of settled view, once the player faces the door
## (or `max_seconds` passed) and no patron is mid-line (the max never waits more than a line's worth).
## T-100: with `look.interrupt_after` set, a line that has played that long may be cut by the cue (the pounding
## interrupts whoever is talking), so a long welcome no longer holds round 1; `line_start` is when it began.
static func look_ready(settle: float, looking: bool, busy_until: float, c: Dictionary, line_start: float = -1.0) -> bool:
	var lk: Dictionary = c.get("look", {})
	if lk.is_empty():
		return true
	var mn: float = float(lk.get("min_seconds", 0.0))
	var mx: float = maxf(mn, float(lk.get("max_seconds", mn)))
	if settle < mn:
		return false
	if settle >= mx + 6.0:
		return true
	if not looking and settle < mx:
		return false
	var cut: float = float(lk.get("interrupt_after", 0.0))
	if cut > 0.0 and line_start >= 0.0 and settle >= line_start + cut:
		return true
	return settle >= busy_until


## T-076: is a camera at `cam` with forward `fwd` facing `p` within `cone_deg` (flat angle)?
static func facing(cam: Vector3, fwd: Vector3, p: Vector3, cone_deg: float) -> bool:
	var to: Vector2 = Vector2(p.x - cam.x, p.z - cam.z)
	var f: Vector2 = Vector2(fwd.x, fwd.z)
	if to.length() < 0.01 or f.length() < 0.01:
		return true
	return rad_to_deg(absf(f.angle_to(to))) <= cone_deg


## How many of the round's queued slots the opening may take: risers first (they are the point), then attackers,
## never more than the queue holds.
static func plan_slots(to_spawn: int, risers: int, attackers_n: int) -> Dictionary:
	var r: int = clampi(risers, 0, maxi(0, to_spawn))
	var a: int = clampi(attackers_n, 0, maxi(0, to_spawn - r))
	return {"risers": r, "attackers": a}


## Patrons who rise (caught or bitten, with a rise variant).
static func riser_ids(c: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for row: Dictionary in c.get("patrons", []):
		if str(row.get("fate", "")) in ["caught", "bitten"] and str(row.get("rise_variant", "")) != "":
			out.append(str(row["id"]))
	return out


static func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


static func path_length(pts: Array) -> float:
	var l: float = 0.0
	for i: int in range(1, pts.size()):
		l += _v3(pts[i - 1]).distance_to(_v3(pts[i]))
	return l


## When each patron goes out of the front door: in order of arrival, a beat apart, not before it opens; a patron
## who holds the door goes when the hold ends; the bitten one never does (-1).
static func exit_times(c: Dictionary) -> Dictionary:
	var door_cfg: Dictionary = c.get("front_door", {})
	var open_at: float = float(door_cfg.get("open_at", 5.0))
	var arrive: Array = []
	for row: Dictionary in c.get("patrons", []):
		var pts: Array = [row["start"]]
		pts.append_array(row.get("route", []))
		var at: float = float(row.get("depart", 0.0)) + 0.4 + path_length(pts) / maxf(0.5, float(row.get("speed", c.get("run_speed", 3.4))))
		arrive.append([at, str(row["id"]), row])
	arrive.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	var out: Dictionary = {}
	var order: int = 0
	for e: Array in arrive:
		var row2: Dictionary = e[2]
		if str(row2.get("fate", "")) == "bitten":
			out[e[1]] = -1.0
			continue
		if row2.has("hold"):
			out[e[1]] = float((row2["hold"] as Dictionary).get("until", open_at))
			continue
		out[e[1]] = maxf(float(e[0]), open_at + 0.15 + 0.45 * order)
		order += 1
	return out


# ================================================================== setup

func _ready() -> void:
	add_to_group(&"inn_opening")   # (VOManager holds the squad's SPAWN lines until the opening is over)
	cfg = load_cfg()
	var map: MapRoot = _map()
	var map_id: StringName = map.map_id if map != null else &""
	if cfg.is_empty() or String(map_id) != str(cfg.get("map", "")):
		phase = Phase.CANCELLED
		return
	_arriving = Campaign.arriving(map_id)
	if _arriving:
		phase = Phase.CANCELLED
		return
	door = get_parent().get_node_or_null(str((cfg.get("front_door", {}) as Dictionary).get("node", "InnFrontDoor"))) as InnFrontDoor
	var exits: Dictionary = exit_times(cfg)
	for row: Dictionary in cfg.get("patrons", []):
		var pb: PatronBody = PatronBody.new()
		add_child(pb)
		pb.setup(row)
		pb.set_fall_seconds(float(cfg.get("fall_seconds", 0.7)))
		pb.global_position = _v3(row["start"])
		pb.rotation.y = deg_to_rad(float(row.get("yaw", 0.0)))
		pb.global_position = pb.global_position   # (keeps _last_pos honest on the first frame)
		pb.enable_life()   # T-246: the patrons look up at the squad, start at a shot; outside, their breath shows
		patrons[str(row["id"])] = pb
		if str(row.get("fate", "")) in ["caught", "bitten"] and str(row.get("rise_variant", "")) != "":
			PeopleBodies.warm_risen(str(row["id"]), str(row["rise_variant"]), bool(row.get("female", false)))   # (not in the tick they rise)
		_st[str(row["id"])] = {"row": row, "stage": "idle", "pts": [], "i": 0, "exit": float(exits.get(str(row["id"]), 0.0)), "t0": 0.0}
	GLBus.round_started.connect(_on_round_started)
	if not (cfg.get("title_card", {}) as Dictionary).is_empty():
		_card_t = 0.0


func _map() -> MapRoot:
	var n: Node = get_parent()
	while n != null:
		if n is MapRoot:
			return n as MapRoot
		n = n.get_parent()
	return null


func _director() -> ZombieDirector:
	var map: Node = _map()
	return map.get_node_or_null("ZombieDirector") as ZombieDirector if map != null else null


func _on_round_started(r: int, _special: bool) -> void:
	if phase != Phase.IDLE:
		return
	if not Net.is_authority():
		return   # the host's _net_begin / _net_cancel
	var map: MapRoot = _map()
	if should_play(map.map_id if map != null else &"", r, RoundManager.current_round, _arriving, false, cfg):
		begin()
		Net.mirror(self, &"_net_begin")
	else:
		cancel()
		Net.mirror(self, &"_net_cancel")


## Round 1 started: the host takes the round slots, then the script runs (every peer).
func begin() -> void:
	if phase != Phase.IDLE:
		return
	if Net.is_authority():
		_reserve()
	_start_script()


func _net_begin() -> void:
	if phase == Phase.IDLE:
		_start_script()


func _net_cancel() -> void:
	cancel()


func _start_script() -> void:
	phase = Phase.RUNNING
	t = 0.0


## Not this time (a later round, a dev skip): the patrons are simply gone, the door stays barred.
func cancel() -> void:
	if phase == Phase.RUNNING:
		_finish()
	phase = Phase.CANCELLED
	for pb: PatronBody in patrons.values():
		pb.catchable = false
		pb.hide()


func _reserve() -> void:
	var ids: PackedStringArray = riser_ids(cfg)
	var att: Array = cfg.get("attackers", [])
	var plan: Dictionary = plan_slots(RoundManager.to_spawn, ids.size(), att.size())
	for i: int in int(plan["risers"]):
		riser_specs[ids[i]] = RoundManager.take_spawn()
	for j: int in int(plan["attackers"]):
		attacker_specs[j] = RoundManager.take_spawn()


## Gives back every slot the opening took and never used.
func _finish() -> void:
	if not Net.is_authority():
		return
	for k: Variant in riser_specs.keys():
		if not risen.has(k):
			RoundManager.requeue()
			slots_returned += 1
	riser_specs.clear()
	for j: Variant in attacker_specs.keys():
		if not attackers.has(j):
			RoundManager.requeue()
			slots_returned += 1
	attacker_specs.clear()


# ================================================================== the script

func _physics_process(delta: float) -> void:
	since_ready += delta
	match phase:
		Phase.RUNNING:
			t += delta
			_beats()
			for id: String in _st.keys():
				_step_patron(id, delta)
			if t >= float(cfg.get("end_by", 45.0)) or _all_resolved():
				_finish()
				phase = Phase.DONE


## Before round 1 (T-076): the settled-view clock, the patrons' chatter, and on the host the hold on the round's intro
## timer until the cue.
func _process(delta: float) -> void:
	if phase == Phase.IDLE and GameState.has_flag(&"cutscene"):
		return   # T-194: GRAVELIGHT ONE (or FOURTH DAY) plays first; the settled view, the card and the cue start after it
	if _card_t >= 0.0:
		_tick_card(delta)
	if phase != Phase.IDLE or RoundManager.current_round != 0:
		return
	var lk: Dictionary = cfg.get("look", {})
	settle_t += minf(delta, float(lk.get("frame_cap", 0.1)))
	if not cued:
		_intro_lines()
	_cue_sfx(delta)
	if not Net.is_authority() or RoundManager.state != RoundManager.State.BREAK or cued:
		return
	if not _gate_open and settle_t >= float(lk.get("min_seconds", 0.0)) and (settle_t >= float(lk.get("max_seconds", 0.0)) or _player_looking(lk)):
		_gate_open = true
	if _gate_open and look_ready(settle_t, true, _busy_until, cfg, _line_start):
		_cue()
		Net.mirror(self, &"_net_cue")
		RoundManager.break_left = float(lk.get("cue_lead", 1.6))
	else:
		RoundManager.break_left = maxf(RoundManager.break_left, 0.5)


## T-184: the opening card: the bars and the card in, then out at `until`, the cue, or round 1 (whichever is first).
func _tick_card(delta: float) -> void:
	var tc: Dictionary = cfg.get("title_card", {})
	_card_t += delta
	var over: bool = _card_t >= float(tc.get("until", 8.0)) or cued or phase != Phase.IDLE or RoundManager.current_round != 0
	if _card == null:
		if over:
			_card_t = -1.0
			return
		if _card_t < float(tc.get("bars_at", 0.4)):
			return
		_card = CinemaOverlay.new()
		_card.name = "OpeningCard"
		_card.skip_enabled = false
		add_child(_card)
		_card.hide_hud(_map())
		_card.bars(true, 1.2)
		return
	if not _card_titled and not over and _card_t >= float(tc.get("at", 1.2)):
		_card_titled = true
		_card.title_card(str(tc.get("title", "")), str(tc.get("subtitle", "")), str(tc.get("time", "")), float(tc.get("hold", 5.5)))
	if over:
		_card_t = -1.0
		var c: CinemaOverlay = _card
		_card = null
		c.restore_hud()
		c.bars(false, 0.8)
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
			if is_instance_valid(c):
				c.queue_free())


## Is the local camera facing the front door? (No camera, e.g. a dedicated tool: yes.)
func _player_looking(lk: Dictionary) -> bool:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return true
	return facing(cam.global_position, -cam.global_basis.z, _v3(lk.get("look_at", [20.0, 1.2, 0.0])), float(lk.get("cone_deg", 50.0)))


## The cue: something pounds at the window and the door, a patron asks what that was (every peer).
func _cue() -> void:
	if cued:
		return
	cued = true
	var lk: Dictionary = cfg.get("look", {})
	if settle_t < _busy_until and is_instance_valid(_line_voice):   # T-100: the pounding cuts the speaker off
		var v: AudioStreamPlayer3D = _line_voice
		var tw: Tween = v.create_tween()
		tw.tween_property(v, "volume_db", -40.0, 0.25)
		tw.tween_callback(v.queue_free)
	_line_voice = null
	_cue_sfx_left = (lk.get("cue_sfx", []) as Array).duplicate(true)
	_cue_sfx(0.0)
	var cl: Dictionary = lk.get("cue_line", {})
	if not cl.is_empty():
		_say(str(cl.get("id", "")), str(cl.get("who", "")))


func _net_cue() -> void:
	_cue()


func _cue_sfx(delta: float) -> void:
	for e: Dictionary in _cue_sfx_left.duplicate():
		e["delay"] = float(e.get("delay", 0.0)) - delta
		if float(e["delay"]) <= 0.0:
			_cue_sfx_left.erase(e)
			AudioDirector.play_3d(str(e["key"]), _v3(e["pos"]), float(e.get("db", 0.0)))


func _intro_lines() -> void:
	for i: int in (cfg.get("lines", []) as Array).size():
		var ln: Dictionary = cfg["lines"][i]
		if bool(ln.get("intro", false)) and not _done_lines.has(i) and settle_t >= float(ln["at"]):
			_done_lines[i] = true
			if _gate_open:
				continue   # the cue is waiting: no new chatter
			_busy_until = maxf(_busy_until, settle_t + _say(str(ln["id"]), str(ln.get("who", ""))))
			_line_start = settle_t
			_line_voice = _last_voice


func _beats() -> void:
	var lines: Array = cfg.get("lines", [])
	for i: int in lines.size():
		var ln: Dictionary = lines[i]
		if not bool(ln.get("intro", false)) and not _done_lines.has(i) and t >= float(ln["at"]):
			_done_lines[i] = true
			var pb: PatronBody = patrons.get(str(ln.get("who", ""))) as PatronBody
			if pb != null and pb.visible and pb.pose != &"dead":
				_say(str(ln["id"]), str(ln.get("who", "")))
	var sfx: Array = cfg.get("sfx", [])
	for k: int in sfx.size():
		var e: Dictionary = sfx[k]
		if not _done_sfx.has(k) and t >= float(e["at"]):
			_done_sfx[k] = true
			AudioDirector.play_3d(str(e["key"]), _v3(e["pos"]), float(e.get("db", 0.0)))
	var dc: Dictionary = cfg.get("front_door", {})
	if door != null:
		_door_beat("unbar", float(dc.get("open_at", 5.0)) - 0.6, func() -> void: door.unbar())
		_door_beat("open", float(dc.get("open_at", 5.0)), func() -> void: door.open(float(dc.get("open_deg", 105.0)), float(dc.get("open_seconds", 0.7))))
		_door_beat("close", float(dc.get("close_at", 11.0)), func() -> void: door.close(float(dc.get("close_seconds", 0.45))))
		_door_beat("bar", float(dc.get("bar_at", 12.0)), func() -> void: door.bar())
	var fl: Dictionary = cfg.get("flare", {})
	if not _flared and not fl.is_empty() and t >= float(fl.get("at", 5.0)):
		_flared = true
		_flare(fl)
	if Net.is_authority():
		var att: Array = cfg.get("attackers", [])
		for j: int in att.size():
			if attacker_specs.has(j) and not attackers.has(j) and t >= float(att[j]["at"]):
				_spawn_attacker(j, att[j])
		for j2: Variant in attackers.keys():
			var z: Zombie = attackers[j2]
			if is_instance_valid(z) and z.is_active() and z.prey == null and z.window == null:
				z.go_to_window(_barricade(str(att[int(j2)].get("then_window", ""))))


func _door_beat(key: String, at: float, f: Callable) -> void:
	if not _door_beats.has(key) and t >= at:
		_door_beats[key] = true
		f.call()


## The hearth fire flares in the draught from the open door.
func _flare(fl: Dictionary) -> void:
	var map: Node = _map()
	var l: Light3D = map.find_child(str(fl.get("light", "Hearthfire")), false, false) as Light3D if map != null else null
	if l == null or not ("base_energy" in l):
		return
	var base: float = float(l.get("base_energy"))
	var tw: Tween = create_tween()
	tw.tween_property(l, "base_energy", base * float(fl.get("mult", 1.6)), 0.35)
	tw.tween_property(l, "base_energy", base, maxf(0.2, float(fl.get("seconds", 2.0)) - 0.35))


func _spawn_attacker(j: int, a: Dictionary) -> void:
	var dir: ZombieDirector = _director()
	var spec: Dictionary = attacker_specs[j]
	var z: Zombie = dir.activate_reserved(spec, _v3(a["pos"])) if dir != null else null
	if z == null:
		RoundManager.requeue()
		attacker_specs.erase(j)
		slots_returned += 1
		return
	attackers[j] = z
	var pb: PatronBody = patrons.get(str(a.get("prey", ""))) as PatronBody
	if pb != null and pb.is_catchable():
		z.prey = pb


func _barricade(name_: String) -> Barricade:
	if name_ == "":
		return null
	var map: Node = _map()
	return map.find_child(name_, true, false) as Barricade if map != null else null


func _all_resolved() -> bool:
	for id: String in _st.keys():
		var stg: String = str(_st[id]["stage"])
		if stg != "gone" and stg != "risen" and stg != "corpse":
			return false
	return true


# ================================================================== one patron

func _step_patron(id: String, delta: float) -> void:
	var s: Dictionary = _st[id]
	var row: Dictionary = s["row"]
	var pb: PatronBody = patrons[id]
	var speed: float = float(row.get("speed", cfg.get("run_speed", 3.4)))
	match str(s["stage"]):
		"idle":
			if t >= float(row.get("depart", 0.0)):
				pb.set_pose(&"panic")
				s["stage"] = "getup"
				s["t0"] = t
		"getup":
			if t - float(s["t0"]) >= 0.4:
				_go(s, row.get("route", []), "to_door")
				pb.set_pose(&"run")
		"to_door":
			if _follow(pb, s, speed, delta):
				if row.has("unbar") and door != null and not door.is_open:
					s["stage"] = "unbar"
					pb.set_pose(&"push")
					_face_point(pb, Vector3(pb.global_position.x, 0, -1.0))
				elif str(row.get("fate", "")) == "bitten":
					s["stage"] = "hold"
					pb.set_pose(&"push")
					_face_point(pb, Vector3(pb.global_position.x, 0, -1.0))
				else:
					s["stage"] = "wait"
					pb.set_pose(&"panic")
		"unbar":
			if door == null or door.is_open:
				if row.has("hold"):
					_go(s, [row["hold"]["at"]], "to_hold")
					pb.set_pose(&"panic")
				else:
					s["stage"] = "wait"
		"to_hold":
			if _follow(pb, s, 1.6, delta):
				s["stage"] = "wait"
				pb.set_pose(&"panic")
		"wait":
			if t >= float(s["exit"]) and (door == null or door.is_open):
				var out: Array = row.get("outside", [])
				_go(s, out, "out")
				pb.set_pose(&"run")
		"out":
			var arrived: bool = _follow(pb, s, speed, delta)
			if str(row.get("fate", "")) == "escape":
				var far: bool = door != null and pb.global_position.distance_to(door.global_position) > float(cfg.get("fade_distance", 32.0))
				if arrived or far:
					pb.catchable = false
					pb.hide()
					s["stage"] = "gone"
					fates[id] = "escaped"
			elif arrived:
				s["stage"] = "caught"
				s["t0"] = t
				pb.set_pose(&"struggle")
		"caught":
			if t - float(s["t0"]) >= float(row.get("struggle", 2.0)):
				_fall(id, s, pb)
		"hold":
			var bt: Dictionary = row.get("bitten", {})
			var hold_until: float = float((row.get("hold", {}) as Dictionary).get("until", 10.0))
			if not bt.is_empty() and t >= hold_until:
				_go(s, [bt["reach"]], "reach")
				pb.set_pose(&"push")
		"reach":
			var bt2: Dictionary = row["bitten"]
			_follow(pb, s, 2.4, delta)
			_face_point(pb, Vector3(pb.global_position.x + 0.6, 0, -2.0))
			if t >= float(bt2.get("at", 10.5)):
				pb.struck(null)
				AudioDirector.play_3d("player_hurt", pb.global_position + Vector3.UP * 1.5, 0.0)
				AudioDirector.play_3d("impact_flesh", pb.global_position + Vector3.UP * 1.2, 0.0)
				s["stage"] = "shut"
		"shut":
			var bt3: Dictionary = row["bitten"]
			if t >= float(bt3.get("shut_at", 11.4)) and pb.pose != &"push":
				pb.set_pose(&"push")
			if t >= float(bt3.get("bar_at", 12.0)) + 0.5:
				_go(s, bt3.get("walk", []), "stagger")
				pb.set_pose(&"clutch")
		"stagger":
			var bt4: Dictionary = row["bitten"]
			var done: bool = _follow(pb, s, float(bt4.get("walk_speed", 0.8)), delta)
			if done and t >= float(bt4.get("collapse_at", 17.0)):
				_fall(id, s, pb)
		"down":
			if pb.pose == &"dead" and t - float(s["t0"]) >= float(row.get("rise_after", cfg.get("rise_after", 6.0))):
				_rise(id, s, pb)


func _go(s: Dictionary, pts: Array, stage: String) -> void:
	s["pts"] = pts
	s["i"] = 0
	s["stage"] = stage


## Moves along the stage's points; true once at the last one.
func _follow(pb: PatronBody, s: Dictionary, speed: float, delta: float) -> bool:
	var pts: Array = s["pts"]
	var i: int = int(s["i"])
	var step: float = speed * delta
	while i < pts.size():
		var goal: Vector3 = _v3(pts[i])
		var here: Vector3 = pb.global_position
		var to: Vector3 = Vector3(goal.x - here.x, 0, goal.z - here.z)
		var d: float = to.length()
		if d <= step:
			pb.global_position = Vector3(goal.x, goal.y, goal.z)
			step -= d
			i += 1
			continue
		pb.global_position = here + to / d * step
		var want: float = atan2(-to.x, -to.z)
		pb.rotation.y = lerp_angle(pb.rotation.y, want, clampf(delta * 10.0, 0.0, 1.0))
		break
	s["i"] = i
	return i >= pts.size()


func _face_point(pb: PatronBody, p: Vector3) -> void:
	var to: Vector3 = p - pb.global_position
	if Vector2(to.x, to.z).length() > 0.01:
		pb.rotation.y = atan2(-to.x, -to.z)


func _fall(id: String, s: Dictionary, pb: PatronBody) -> void:
	pb.set_pose(&"fall")
	AudioDirector.play_3d("player_hurt", pb.global_position + Vector3.UP * 1.4, 2.0)
	s["stage"] = "down"
	s["t0"] = t
	fates[id] = "dead"


func _rise(id: String, s: Dictionary, pb: PatronBody) -> void:
	var row: Dictionary = s["row"]
	if Net.is_authority():
		if not riser_specs.has(id):
			s["stage"] = "corpse"   # no slot for them (a tiny round queue): they stay where they fell
			return
		var spec: Dictionary = (riser_specs[id] as Dictionary).duplicate()
		spec["variant"] = str(row.get("rise_variant", "villager"))
		if row.has("female"):
			spec["female"] = bool(row["female"])
		var dir: ZombieDirector = _director()
		var z: Zombie = dir.activate_reserved(spec, pb.global_position) if dir != null else null
		if z == null:
			RoundManager.requeue()
			riser_specs.erase(id)
			slots_returned += 1
			s["stage"] = "corpse"
			return
		z.global_position = pb.global_position
		z.rotation.y = pb.rotation.y
		PeopleBodies.dress_risen(z, id)   # T-092: the same person gets up
		z.rise_from_floor(float(cfg.get("rise_getup_seconds", 2.4)), _barricade(str(row.get("rise_window", ""))))
		risen[id] = z
	pb.catchable = false
	pb.hide()
	s["stage"] = "risen"
	fates[id] = "risen"
	AudioDirector.play_3d("zombie_groan", pb.global_position + Vector3.UP * 0.6, 2.0, 0.1)
	var sq: Dictionary = cfg.get("squad_line", {})
	if str(sq.get("on_rise", "")) == id:
		get_tree().create_timer(float(sq.get("delay", 0.6))).timeout.connect(func() -> void:
			GLVO.squad_say(str(sq.get("category", "INN_RISE")), 1.0))


# ================================================================== lines

## A patron's line: the subtitle under their name, and the baked voice at them when there is one.
func _say(line_id: String, who: String) -> float:
	var rec: Dictionary = GLVO.lines.get(line_id, {})
	if rec.is_empty():
		return 0.0
	var pb: PatronBody = patrons.get(who) as PatronBody
	var display: String = who.to_upper()
	for row: Dictionary in cfg.get("patrons", []):
		if str(row["id"]) == who:
			display = str(row.get("display", display))
	var text: String = GLVO.strip_tags(str(rec.get("text", "")))
	var dur: float = GLVO.duration_for(text, GLVO.rules)
	var path: String = GLVO.audio_path(StringName(line_id))
	_last_voice = null
	if path != "" and pb != null:
		var stream: AudioStream = GLVO.load_stream(path)
		if stream != null:
			var p: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
			p.bus = GLVO.bus_for_line(StringName(line_id))   # T-205: the room (or VODry for a line with its own channel)
			p.stream = stream
			p.unit_size = 5.0
			p.max_distance = 45.0
			p.position = Vector3(0, 1.6, 0)
			pb.add_child(p)
			p.play()
			p.finished.connect(p.queue_free)
			_last_voice = p
			dur = maxf(dur, stream.get_length())
	GLBus.vo_line_started.emit(StringName(line_id), StringName(display), text, dur)
	return dur
