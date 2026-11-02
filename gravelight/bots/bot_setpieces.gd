class_name BotSetPieces
extends RefCounted
## UPDATE 10 §7 (contract C7, DECISIONS T-163): one bot's rules for Fernflug's set-pieces. BotBrain owns one, ticks
## it on every think (~5 Hz) and hands it the body (the brain's action "setpiece") while it has a move of its own to
## make (wants_control). Everything else is a modifier the other layers read: no sprint, hold fire, a tighter
## formation, and danger zones on the squad's blackboard (the locomotion layer already paths round those).
##
## Act II (der Kranich; T-156; its classes are read by group and duck typing, so this compiles without them):
##   decompression  a breach warning or pulling within its radius + grip_margin_m: go to the nearest `rail_grips`
##                  rail and hold it (RailGrip.hold) until the event is over; never stand at the hole meanwhile
##   tilt           a warned or running tilt: no sprint; a sliding casing (`tilt_sliders`, moving) is a danger lane
##   wing walk      a `risky` optional task (`wing_walks`, `wing_hatches`, `clip_points`, `wing_chests`): only in a
##                  quiet spell (a break, or nothing known within quiet_m), one bot, never below hp_min; climb out,
##                  clip in at once (the bots never walk the wing unclipped), take the wingtip locker's token
##                  (and its wonder part, when the slot is filled), climb back in
##   aux bus        it is a PowerSwitch (group power_switch): the economy's power plan already throws it
##   bay doors      a TrapLever trap with danger_contains: the brain's trap rules already keep out and use it
## Act III (Groom Lake; T-157):
##   dust storm     GroomController.dust_active(): no sprint, a tight formation (storm_spacing_mult), and no shot at
##                  a stalker (Zombie.hunt_by_sound) farther than quiet_fire_m unless it is already on us, a
##                  teammate is down or the bot is hurt (a shot makes every stalker within 18 m hear it)
##   collapses      a warned, not yet fallen section's box is a danger zone until it falls; the burning hull
##                  (spread_points) is a danger zone for good
##   radar perch    data: routes_map04c.json "high_ground" (the tower deck; Wren's high-ground rule)
##   jukebox, Dee, Hale, the field units: never touched (no errand lists them; asserted by test_bot_u10)
## Act IV (Mondlicht; T-158):
##   terminator     Terminator.night_at: a home loop on the day side wins over one on the night side (BotSquad)
##   visor          a player thing: bots have no glare
##   jump pads      `jump_pads`: a pad's landing is a route link the locomotion layer may use (pad_link)
##   meteor shower  flag `meteor_shower` (and its warning, MeteorShower.active / the banner): out of the yard box,
##                  to the nearest shelter point (routes_map04d.json "setpieces.meteor_shelter"), until it is over
##   shaft grate    `shaft_grate_lever`: pulled when enough of the dead stand on the grate (`shaft_grate`) and the
##                  bot can spare the price; the open grate is a danger zone
##   Pohl's favour  an optional task the bots leave to the player (his tag is a story item; tag_slot is
##                  player-facing): not taken by bots (documented choice, T-163)

const CFG_PATH: String = "res://data/gravelight/ai/setpieces.json"

static var _cfg_cache: Dictionary = {}

var brain: BotBrain
var player: Player
## The move this bot makes now: {} or {"kind": "grip"|"shelter"|"wing_walk"|"lever", ...}.
var move: Dictionary = {}
var storm: bool = false
var tilt_warned: bool = false
## Counters (smoke_bots_u10, the soak's lines).
var grips: int = 0
var shelters: int = 0
var held_fire: int = 0
var levers: int = 0
var wing_walks: int = 0
var wing_clips: int = 0
var wing_tokens: int = 0

var _hold_t: float = 0.0
var _wing_stage: String = ""
var _wing_t: float = 0.0
var _wing_fail_until: float = -INF
var _grip_node: Node = null
var _lever_t: float = 0.0
var _pad_t: float = 0.0
var _perch_t: float = 0.0
var _perch_stage: String = ""
var _perch_climb_t: float = 0.0
var perches: int = 0
var pads_taken: int = 0
var _scan_t: float = 0.0
var _nodes: Dictionary = {}   # group -> Array[Node] (refreshed every 3 s)


func setup(b: BotBrain) -> void:
	brain = b
	player = b.player


static func cfg() -> Dictionary:
	if _cfg_cache.is_empty():
		_cfg_cache = GLData.load_json(CFG_PATH) if FileAccess.file_exists(CFG_PATH) else {}
		if _cfg_cache.is_empty():
			_cfg_cache = {"_empty": true}
	return _cfg_cache


static func c(section: String, key: String, fallback: Variant) -> Variant:
	return (cfg().get(section, {}) as Dictionary).get(key, fallback)


# ================================================================== pure rules (test_bot_u10)

## Storm: may a bot fire at a target `d` m away? `sound` = it hunts by sound; `on_us` = it is already chasing this
## bot (within on_us_m); `urgent` = a teammate down or the bot hurt.
static func storm_may_fire(d: float, sound: bool, on_us: bool, urgent: bool, quiet_m: float) -> bool:
	if not sound or on_us or urgent:
		return true
	return d <= quiet_m


## Decompression: does a bot at `dist` from a breach in `phase` ("warn"/"pull"/other) need a rail?
static func grip_needed(phase: String, dist: float, radius: float, margin: float) -> bool:
	return (phase == "warn" or phase == "pull") and dist <= radius + margin


## Meteor yard box [x0, z0, x1, z1]: is (x, z) inside (grown by m)?
static func in_box2(box: Array, p: Vector3, m: float = 0.0) -> bool:
	if box.size() < 4:
		return false
	return p.x >= minf(float(box[0]), float(box[2])) - m and p.x <= maxf(float(box[0]), float(box[2])) + m \
		and p.z >= minf(float(box[1]), float(box[3])) - m and p.z <= maxf(float(box[1]), float(box[3])) + m


## A collapse section's box [[x0, y0, z0], [x1, y1, z1]] as one danger disc {pos, radius} (its half diagonal).
static func box_disc(box: Array, margin: float) -> Dictionary:
	if box.size() < 2:
		return {}
	var lo: Array = box[0]
	var hi: Array = box[1]
	var cx: float = (float(lo[0]) + float(hi[0])) * 0.5
	var cz: float = (float(lo[2]) + float(hi[2])) * 0.5
	var r: float = Vector2(float(hi[0]) - float(lo[0]), float(hi[2]) - float(lo[2])).length() * 0.5 + margin
	return {"pos": Vector3(cx, float(lo[1]), cz), "radius": r}


## The wing walk (a risky optional task): may this bot set out now?
static func wing_walk_ok(w: Dictionary) -> bool:
	if not bool(w.get("open", false)) or bool(w.get("taken", true)) or bool(w.get("claimed", false)):
		return false
	if not bool(w.get("allowed", false)) or bool(w.get("storm", false)) or bool(w.get("tilt", false)):
		return false
	if float(w.get("hp", 0.0)) < float(w.get("hp_min", 0.7)):
		return false
	return bool(w.get("break", false)) or float(w.get("nearest_m", 0.0)) >= float(w.get("quiet_m", 18.0))


## The shaft grate: worth pulling the lever?
static func lever_worth(on_grate: int, scrip: int, cost: int, cooling: bool, min_dead: int, reserve: int) -> bool:
	return not cooling and on_grate >= min_dead and scrip - cost >= reserve


## Act IV: is `p` on the night side of the terminator (group "terminator", Terminator.night_at)? False elsewhere.
static func night_at(tree: SceneTree, p: Vector3) -> bool:
	if tree == null:
		return false
	var t: Node = tree.get_first_node_in_group(&"terminator")
	return t != null and t.has_method("night_at") and bool(t.call("night_at", p))


## A pad as a route link: worth taking when the landing is much closer to the goal than the bot is (flat m).
static func pad_shortcut(me_to_goal: float, pad_from_me: float, land_to_goal: float, gain_m: float) -> bool:
	return pad_from_me + land_to_goal + gain_m < me_to_goal


# ================================================================== think

func think(now: float) -> void:
	if now >= _scan_t:
		_scan_t = now + 3.0
		_nodes.clear()
	storm = _storm_on()
	tilt_warned = _tilt_on()
	_update_dangers(now)
	_apply_modifiers()
	if brain.player.downed or brain.player.spectating:
		_end_move()
		return
	# the most urgent move first: a breach's pull, then the meteors, then the lever, then the optional wing walk
	var grip: Dictionary = _grip_plan()
	if not grip.is_empty():
		_set_move(grip)
		return
	if str(move.get("kind", "")) == "grip":
		_end_move()
	var shelter: Dictionary = _shelter_plan()
	if not shelter.is_empty():
		_set_move(shelter)
		return
	if str(move.get("kind", "")) == "shelter":
		_end_move()
	if str(move.get("kind", "")) == "wing_walk" or str(move.get("kind", "")) == "perch":
		return   # the walk / the perch runs to its end (run() finishes or ends it)
	var lv: Dictionary = _lever_plan(now)
	if not lv.is_empty():
		_set_move(lv)
		return
	if str(move.get("kind", "")) == "lever" or str(move.get("kind", "")) == "pad":
		return
	var pad: Dictionary = _pad_plan(now)
	if not pad.is_empty():
		_set_move(pad)
		return
	var ww: Dictionary = _wing_plan(now)
	if not ww.is_empty():
		_set_move(ww)
		return
	var pr: Dictionary = _perch_plan(now)
	if not pr.is_empty():
		_set_move(pr)


func wants_control() -> bool:
	return not move.is_empty()


## The brain's override: a grip or a shelter outranks everything but a revive that is already on; the wing walk and
## the lever only a quiet moment (the brain lets an emergency take over: the move stays and comes back).
func urgent() -> bool:
	var k: String = str(move.get("kind", ""))
	if k == "perch" and _perch_stage != "up":
		return true   # on the ladder or the deck: only the ladder brings her down (the perch logic leaves for a revive)
	return k == "grip" or k == "shelter"


func no_sprint() -> bool:
	return storm or tilt_warned or str(move.get("kind", "")) == "grip"


## BotAim's gate: in the storm a stalker far off is let be (a shot is heard 18 m round).
func may_fire_at(z: Zombie, d: float) -> bool:
	if not storm or z == null:
		return true
	var on_us: bool = d <= float(c("storm", "on_us_m", 4.0)) or (z.get("target") == player)
	var urgent_: bool = brain.player.hp < brain.player.max_hp * 0.5 or _any_down()
	var ok: bool = storm_may_fire(d, bool(z.get("hunt_by_sound")), on_us, urgent_, float(c("storm", "quiet_fire_m", 7.0)))
	if not ok:
		held_fire += 1
	return ok


func _apply_modifiers() -> void:
	var loco: Object = brain.loco
	if loco == null:
		return
	if "no_sprint" in loco:
		loco.set("no_sprint", no_sprint())
	if "spacing_mult" in loco:
		loco.set("spacing_mult", float(c("storm", "spacing_mult", 0.6)) if storm else 1.0)


func _set_move(m: Dictionary) -> void:
	if str(move.get("kind", "")) != str(m.get("kind", "")):
		_hold_t = 0.0
		if str(m.get("kind", "")) == "grip":
			grips += 1
		elif str(m.get("kind", "")) == "shelter":
			shelters += 1
		elif str(m.get("kind", "")) == "perch":
			perches += 1
			_perch_stage = "up"
		elif str(m.get("kind", "")) == "wing_walk":
			wing_walks += 1
			_wing_stage = "out"
			_wing_t = 0.0
	move = m


func _end_move() -> void:
	if _grip_node != null and is_instance_valid(_grip_node) and _grip_node.has_method("hold"):
		_grip_node.call("hold", player, false)
	_grip_node = null
	if str(move.get("kind", "")) == "wing_walk":
		brain.squad.blackboard.release("wing_walk", player.player_id)
	move = {}


func on_exit() -> void:
	if str(move.get("kind", "")) == "grip" and _grip_node != null and is_instance_valid(_grip_node):
		_grip_node.call("hold", player, false)
		_grip_node = null


# ================================================================== the world

func _group(g: StringName) -> Array:
	if not _nodes.has(g):
		_nodes[g] = brain.get_tree().get_nodes_in_group(g) if brain.is_inside_tree() else []
	var out: Array = []
	for n: Variant in _nodes[g]:
		if is_instance_valid(n):
			out.append(n)
	return out


func _first(g: StringName) -> Node:
	var a: Array = _group(g)
	return a[0] as Node if not a.is_empty() else null


func _storm_on() -> bool:
	var gc: Node = _first(&"groom_controller")
	return gc != null and gc.has_method("dust_active") and bool(gc.call("dust_active"))


## A warned or running tilt (FlightController: its warning flag / tilt amount; read by duck typing).
func _tilt_on() -> bool:
	var fc: Node = _first(&"flight_controller")
	if fc == null:
		return false
	for k: String in ["turb_warned", "banking"]:
		if k in fc and bool(fc.get(k)):
			return true
	return false


func _any_down() -> bool:
	for b: BotBrain in brain.squad.brains:
		if is_instance_valid(b) and b.player != null and b.player.downed:
			return true
	var h: Player = brain.squad.human()
	return h != null and h.downed


func _update_dangers(now: float) -> void:
	if brain.index != 0 and not brain.is_player_bot:
		return   # the blackboard is the squad's: one brain refreshes it
	var bb: BotBlackboard = brain.squad.blackboard
	# Act III: warned sections, the burning hull
	var gc: Node = _first(&"groom_controller")
	if gc != null:
		var gcfg: Dictionary = gc.get("cfg") if gc.get("cfg") is Dictionary else {}
		var warned: Dictionary = gc.get("warned") if gc.get("warned") is Dictionary else {}
		var fallen: Dictionary = gc.get("collapsed") if gc.get("collapsed") is Dictionary else {}
		for sec: Variant in (gcfg.get("wreck_collapse", {}) as Dictionary).get("sections", []):
			var sd: Dictionary = sec
			var id: String = str(sd.get("id", ""))
			if warned.has(id) and not fallen.has(id):
				var disc: Dictionary = box_disc(sd.get("box", []), float(c("collapse", "margin_m", 1.5)))
				if not disc.is_empty():
					bb.add_danger(disc["pos"], disc["radius"], float(c("collapse", "cost", 6.0)), now + 1.0, "collapse:" + id)
		if gc.has_method("spread_points"):
			for p: Vector3 in gc.call("spread_points"):
				bb.add_danger(p, float(c("collapse", "fire_radius_m", 2.8)), float(c("collapse", "fire_cost", 3.0)), now + 1.0, "hullfire:%d_%d" % [int(p.x), int(p.z)])
	# Act IV: the open grate
	var grate: Node = _first(&"shaft_grate")
	if grate != null and grate.has_method("is_open") and bool(grate.call("is_open")):
		bb.add_danger((grate as Node3D).global_position, float(grate.get("radius")) + 0.8, 4.0, now + 1.0, "shaft_grate")
	# Act II: a sliding casing's lane (moving sliders)
	for s: Node in _group(&"tilt_sliders"):
		if absf(float(s.get("v"))) > 0.5:
			var sp: Vector3 = (s as Node3D).global_position
			bb.add_danger(sp + Vector3(signf(float(s.get("v"))) * 2.0, 0.0, 0.0), 2.6, 3.0, now + 0.6, "slider:%d" % s.get_instance_id())
	# Act II: a pulling breach's hole
	for b: Node in _group(&"decompressions"):
		if _breach_phase(b) == "pull" and b.has_method("hole"):
			bb.add_danger(b.call("hole"), 3.0, 5.0, now + 0.6, "breach:%d" % b.get_instance_id())


## "warn" / "pull" / "" for a DecompressionBreach (Phase enum IDLE, WARN, PULL, DONE by value order).
func _breach_phase(b: Node) -> String:
	var ph: Variant = b.get("phase")
	if ph == null:
		return ""
	match int(ph):
		1:
			return "warn"
		2:
			return "pull"
	return ""


func _grip_plan() -> Dictionary:
	var me: Vector3 = player.global_position
	for b: Node in _group(&"decompressions"):
		var ph: String = _breach_phase(b)
		var hole: Vector3 = b.call("hole") if b.has_method("hole") else (b as Node3D).global_position
		var bc: Dictionary = b.get("cfg") if b.get("cfg") is Dictionary else {}
		var radius: float = float(bc.get("radius", 9.0))
		if not grip_needed(ph, _flat(me, hole), radius, float(c("decompression", "grip_margin_m", 4.0))):
			continue
		var best: Node = null
		var best_d: float = INF
		for r: Node in _group(&"rail_grips"):
			var rb: Variant = r.call("breach") if r.has_method("breach") else null
			if rb != null and rb != b:
				continue
			var d: float = _flat((r as Node3D).global_position, me)
			if d < best_d:
				best_d = d
				best = r
		if best != null:
			return {"kind": "grip", "node": best, "breach": b}
		# no rail: away from the hole, out of its radius
		var away: Vector3 = (me - hole)
		away.y = 0.0
		return {"kind": "grip", "node": null, "to": brain.snap(hole + away.normalized() * (radius + 2.0))}
	return {}


func _shelter_plan() -> Dictionary:
	var ms: Node = _first(&"meteor_shower")
	if ms == null:
		return {}
	if not (GameState.has_flag(&"meteor_shower") or bool(ms.get("active")) or bool(ms.get("warning"))):
		return {}
	var mcfg: Dictionary = ms.get("cfg") if ms.get("cfg") is Dictionary else {}
	var box: Array = mcfg.get("yard_box", [-39.0, 61.0, 39.0, 109.0])
	var me: Vector3 = player.global_position
	if not in_box2(box, me, float(c("meteor", "box_margin_m", 1.5))):
		return {}
	var best: Vector3 = Vector3.INF
	var best_d: float = INF
	for a: Variant in _map_setpieces().get("meteor_shelter", []):
		var p: Vector3 = _v3(a)
		var d: float = _flat(p, me)
		if d < best_d:
			best_d = d
			best = p
	if best == Vector3.INF:
		return {}
	return {"kind": "shelter", "to": brain.snap(best)}


func _lever_plan(now: float) -> Dictionary:
	if now < _lever_t:
		return {}
	_lever_t = now + 1.0
	var lever: Node = _first(&"shaft_grate_lever")
	var grate: Node = _first(&"shaft_grate")
	if lever == null or grate == null or not lever.has_method("pull"):
		return {}
	if _flat((lever as Node3D).global_position, player.global_position) > float(c("shaft_grate", "use_within_m", 14.0)):
		return {}
	var on: int = 0
	var gp: Vector3 = (grate as Node3D).global_position
	var r: float = float(grate.get("radius"))
	for e: Variant in brain.perception.known:
		var zp: Vector3 = (e as Dictionary)["pos"]
		if _flat(zp, gp) <= r + 1.0:
			on += 1
	var lcfg: Dictionary = lever.get("cfg") if lever.get("cfg") is Dictionary else {}
	var cost: int = int(lcfg.get("cost", 1000))
	if not lever_worth(on, Economy.get_scrip(player.player_id), cost, float(lever.get("cool_left")) > 0.0 or bool(grate.call("is_open")),
			int(c("shaft_grate", "min_dead", 4)), int(c("shaft_grate", "reserve_scrip", 1500))):
		return {}
	if not brain.squad.blackboard.claim("shaft_lever", player.player_id, "lever", brain.squad.time(), brain.squad.time() + 6.0):
		return {}
	return {"kind": "lever", "node": lever}


func _wing_plan(now: float) -> Dictionary:
	if now < _wing_fail_until:
		return {}
	var ww: Node = _first(&"wing_walks")
	var chest: Node = _first(&"wing_chests")
	if ww == null or chest == null:
		return {}
	var hatch: Node = _hatch("out")
	var allowed: bool = brain.squad.bot_led() or brain.order_id() == &"wing_walk"
	if not allowed and brain.ee != null and brain.ee.hub != null:
		allowed = brain.ee.hub.mode() == "full"
	var w: Dictionary = {
		"open": bool(ww.get("is_open")) and hatch != null,
		"taken": int(chest.get("state")) == 2,
		"claimed": not brain.squad.blackboard.can_claim("wing_walk", player.player_id, now),
		"allowed": allowed,
		"storm": storm,
		"tilt": tilt_warned,
		"hp": player.hp / maxf(1.0, player.max_hp),
		"hp_min": float(c("wing_walk", "hp_min", 0.7)),
		"break": brain.in_break(),
		"nearest_m": brain.perception.nearest_d,
		"quiet_m": float(c("wing_walk", "quiet_m", 18.0)),
	}
	if not wing_walk_ok(w):
		return {}
	if not brain.squad.blackboard.claim("wing_walk", player.player_id, "wing_walk", now, now + float(c("wing_walk", "max_s", 120.0))):
		return {}
	return {"kind": "wing_walk", "walk": ww, "chest": chest, "t0": now}


## Act IV's jump pads as route links: on the way somewhere (a travel action, nothing close), a pad whose landing
## saves pad_gain_m of path is taken (the pad throws the bot like a player; JumpPad launches bots on the host).
func _pad_plan(now: float) -> Dictionary:
	if now < _pad_t:
		return {}
	_pad_t = now + 1.0
	var pads: Array = _group(&"jump_pads")
	if pads.is_empty() or not ["follow", "regroup", "buy", "resupply", "powerup", "order", "objective"].has(brain.action):
		return {}
	if brain.perception.nearest_d < float(c("jump_pads", "quiet_m", 6.0)) or not player.is_on_floor():
		return {}
	var goal: Variant = brain.loco.get("_goal")
	if not (goal is Vector3) or goal == Vector3.INF:
		return {}
	var g: Vector3 = goal
	var me_to_goal: float = brain.loco.path_length_to(g)
	if me_to_goal == INF or me_to_goal < float(c("jump_pads", "min_trip_m", 18.0)):
		return {}
	for pd: Node in pads:
		var pp: Vector3 = (pd as Node3D).global_position
		var from_me: float = _flat(pp, player.global_position)
		if from_me > float(c("jump_pads", "max_detour_m", 12.0)) or absf(pp.y - player.global_position.y) > 1.5:
			continue
		var tgt: Variant = pd.get("target")
		if not (tgt is Vector3):
			continue
		if pad_shortcut(me_to_goal, from_me, _flat(tgt, g), float(c("jump_pads", "gain_m", 8.0))):
			return {"kind": "pad", "node": pd, "t0": now}
	return {}


func _run_pad(delta: float) -> void:
	var pd: Node3D = move.get("node") as Node3D
	if pd == null or not is_instance_valid(pd) or brain.squad.time() - float(move.get("t0", 0.0)) > 8.0:
		_end_move()
		return
	if not player.is_on_floor() and _flat(pd.global_position, player.global_position) > 1.5:
		pads_taken += 1
		_end_move()   # launched: the arc lands it nearer the goal
		return
	brain.loco.move_to(pd.global_position, 0.6, 0.2)
	if not brain.aim.update(delta, true):
		brain.idle_look(delta)


## Act III's radar tower perch (routes_map04c.json setpieces.perch): a high-ground shooter (personality
## combat.high_ground: Wren) climbs the TowerLadder and fights from the 16 m deck while the squad is near the tower,
## not in the storm (no eyes up there), not hurt, nobody down. The zombies climb up too: two on the deck and she
## climbs down. A sniper spot, not a safe one.
func _perch_plan(now: float) -> Dictionary:
	if now < _perch_t:
		return {}
	_perch_t = now + 2.0
	var pc: Dictionary = _map_setpieces().get("perch", {})
	if pc.is_empty() or storm or not bool(brain.personality_combat("high_ground", false)):
		return {}
	var foot: Node3D = _ladder(false)
	if foot == null:
		return {}
	var top: Vector3 = _v3(pc.get("pos", []))
	var watch: float = float(pc.get("watch_m", 30.0))
	if _perch_leave_reason(top) != "":
		return {}
	var leader: Player = brain.squad.leader_for(brain)
	var ref: Vector3 = leader.global_position if leader != null and leader != player else player.global_position
	if _flat(ref, top) > watch or _flat(player.global_position, foot.global_position) > watch:
		return {}
	if brain.perception.nearest_d < float(c("perch", "quiet_m", 8.0)):
		return {}
	return {"kind": "perch", "top": top, "foot": foot}


## Why to leave (or not go up): "" = stay.
func _perch_leave_reason(top: Vector3) -> String:
	if storm:
		return "storm"
	if player.hp < player.max_hp * float(c("perch", "hp_min", 0.6)):
		return "hurt"
	if _any_down():
		return "revive"
	if brain.perception.count_near(top, 4.0) >= int(c("perch", "crowd", 2)):
		return "crowded"
	return ""


func _ladder(down: bool) -> Node3D:
	for n: Node in _group(&"tower_ladders"):
		if bool(n.get("down")) == down:
			return n as Node3D
	return null


func _run_perch(delta: float) -> void:
	var now: float = brain.squad.time()
	var top: Vector3 = move.get("top", Vector3.INF)
	match _perch_stage:
		"up":
			var foot: Node3D = move.get("foot") as Node3D
			if foot == null or not is_instance_valid(foot) or _perch_leave_reason(top) != "":
				_perch_t = now + 20.0
				_end_move()
				return
			var st: Vector3 = brain.stand_point(foot)
			if _run_walk(st if st != Vector3.INF else brain.snap(foot.global_position), delta, true) or _flat(foot.global_position, player.global_position) < 1.6:
				if bool(foot.call("can_interact", player)):
					brain.loco.stop()
					foot.call("climb", player)
					_perch_stage = "climb_up"
					_perch_climb_t = float(foot.get("climb_s")) + 1.0
		"climb_up", "climb_down":
			brain.loco.stop()
			_perch_climb_t -= delta
			if _perch_climb_t <= 0.0:
				if _perch_stage == "climb_up":
					_perch_stage = "hold"
				else:
					_perch_t = now + float(c("perch", "cooldown_s", 30.0))
					_end_move()
		"hold":
			var why: String = _perch_leave_reason(top)
			if why != "" or brain.in_break():
				_perch_stage = "down"
				return
			var aim_d: Vector3 = (brain.aim.target.global_position - player.global_position) if brain.aim.target != null and is_instance_valid(brain.aim.target) else -player.global_basis.z
			brain.loco.hold(top, aim_d)
			if not brain.aim.update(delta, true):
				brain.idle_look(delta)
		"down":
			var tl: Node3D = _ladder(true)
			if tl == null:
				_end_move()
				return
			if _run_walk(brain.snap(tl.global_position), delta, true) or _flat(tl.global_position, player.global_position) < 1.6:
				if bool(tl.call("can_interact", player)):
					brain.loco.stop()
					tl.call("climb", player)
					_perch_stage = "climb_down"
					_perch_climb_t = float(tl.get("climb_s")) + 1.0


func _hatch(direction: String) -> Node:
	for h: Node in _group(&"wing_hatches"):
		if str(h.get("direction")) == direction:
			return h
	return null


## routes_<map>.json "setpieces" (shelter points, ...).
func _map_setpieces() -> Dictionary:
	if brain.squad.map == null:
		return {}
	var key: String = TrainingRoute.map_key_of(String(brain.squad.map.map_id))
	var path: String = "res://data/gravelight/ai/routes_%s.json" % key
	if not FileAccess.file_exists(path):
		return {}
	return GLData.load_json(path).get("setpieces", {})


# ================================================================== run (the brain's action "setpiece")

func run(delta: float) -> void:
	match str(move.get("kind", "")):
		"grip":
			_run_grip(delta)
		"shelter":
			_run_walk(move["to"], delta, true)
		"lever":
			_run_lever(delta)
		"wing_walk":
			_run_wing(delta)
		"pad":
			_run_pad(delta)
		"perch":
			_run_perch(delta)
		_:
			brain.loco.stop()


func _run_walk(to: Vector3, delta: float, shoot: bool) -> bool:
	if to == Vector3.INF:
		brain.loco.stop()
		return true
	var there: bool = _flat(to, player.global_position) < 1.0 and absf(to.y - player.global_position.y) < 1.5
	if there:
		brain.loco.stop()
	else:
		brain.loco.move_to(to, 0.8, 0.6)
	if shoot and not brain.aim.update(delta, true):
		brain.idle_look(delta)
	return there


func _run_grip(delta: float) -> void:
	var rail: Node = move.get("node") as Node
	if rail == null or not is_instance_valid(rail):
		_run_walk(move.get("to", Vector3.INF), delta, true)
		return
	var stand: Vector3 = brain.stand_point(rail as Node3D)
	if stand == Vector3.INF:
		stand = brain.snap((rail as Node3D).global_position)
	if _run_walk(stand, delta, true) or _flat(stand, player.global_position) < 1.6:
		if _grip_node != rail:
			if _grip_node != null and is_instance_valid(_grip_node):
				_grip_node.call("hold", player, false)
			rail.call("hold", player, true)
			_grip_node = rail
			BotMetrics.note(player.player_id, &"setpiece_grip")


func _run_lever(delta: float) -> void:
	var lever: Node3D = move.get("node") as Node3D
	if lever == null or not is_instance_valid(lever):
		_end_move()
		return
	var stand: Vector3 = brain.stand_point(lever)
	if _run_walk(stand if stand != Vector3.INF else brain.snap(lever.global_position), delta, true) or _flat(lever.global_position, player.global_position) < 1.8:
		_hold_t += delta
		brain.loco.look_at_dir(lever.global_position - player.global_position)
		if _hold_t >= 0.6:
			if lever.has_method("can_interact") and bool(lever.call("can_interact", player)):
				lever.call("interact", player)
				levers += 1
			brain.squad.blackboard.release("shaft_lever", player.player_id)
			_end_move()


func _run_wing(delta: float) -> void:
	var now: float = brain.squad.time()
	var ww: Node = move.get("walk") as Node
	var chest: Node3D = move.get("chest") as Node3D
	if ww == null or chest == null or not is_instance_valid(ww) or not is_instance_valid(chest) or now - float(move.get("t0", now)) > float(c("wing_walk", "max_s", 120.0)):
		_wing_fail_until = now + 60.0
		_end_move()
		return
	_wing_t += delta
	match _wing_stage:
		"out":
			var h: Node3D = _hatch("out") as Node3D
			if h == null:
				_end_move()
				return
			var st: Vector3 = brain.stand_point(h)
			if _run_walk(st if st != Vector3.INF else brain.snap(h.global_position), delta, true) or _flat(h.global_position, player.global_position) < 1.8:
				_hold_t += delta
				var need_h: float = float(h.call("hold_time", player)) if h.has_method("hold_time") else 0.8
				if _hold_t >= need_h:
					h.call("climb", player)
					_hold_t = 0.0
					_wing_stage = "clip"
					brain.loco.stop()
		"clip":
			# the bots never walk the wing unclipped: the nearest tether post first
			if bool(ww.call("is_clipped", player.player_id)):
				wing_clips += 1
				_wing_stage = "chest"
				return
			var post: Node3D = _nearest(&"clip_points")
			if post == null:
				ww.call("clip", player)
				return
			if _run_walk(brain.snap(post.global_position), delta, true) or _flat(post.global_position, player.global_position) < 1.6:
				_hold_t += delta
				if _hold_t >= 1.0:
					post.call("interact", player)
					if not bool(ww.call("is_clipped", player.player_id)):
						ww.call("clip", player)
					_hold_t = 0.0
		"chest":
			if int(chest.get("state")) == 2:
				_wing_stage = "in"
				return
			if _run_walk(brain.snap(chest.global_position), delta, true) or _flat(chest.global_position, player.global_position) < 1.8:
				_hold_t += delta
				var need: float = float(chest.call("hold_time", player)) if chest.has_method("hold_time") else 1.5
				if _hold_t >= need:
					_hold_t = 0.0
					chest.call("interact", player)
					if int(chest.get("state")) == 2 and int(chest.get("taken_by")) == player.player_id:
						wing_tokens += 1
						BotMetrics.note(player.player_id, &"setpiece_wing_token")
		"in":
			var hin: Node3D = _hatch("in") as Node3D
			if hin == null:
				_end_move()
				return
			if _run_walk(brain.snap(hin.global_position), delta, true) or _flat(hin.global_position, player.global_position) < 1.8:
				_hold_t += delta
				if _hold_t >= 0.8:
					hin.call("climb", player)
					_end_move()


func _nearest(g: StringName) -> Node3D:
	var best: Node3D = null
	var best_d: float = INF
	for n: Node in _group(g):
		var d: float = (n as Node3D).global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = n as Node3D
	return best


func describe() -> String:
	if move.is_empty():
		return ""
	var k: String = str(move.get("kind", ""))
	if k == "perch":
		return k + ":" + _perch_stage
	return k + (":" + _wing_stage if k == "wing_walk" else "")


static func _v3(a: Variant) -> Vector3:
	if a is Array and (a as Array).size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.INF


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
