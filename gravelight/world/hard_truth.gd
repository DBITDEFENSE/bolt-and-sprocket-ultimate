class_name HardTruth
extends Node
## UPDATE 11 (T-192, work order section 6): the fourth-day rule, "Hard Truth". When a squad member bleeds out, their
## body rises as a zombie: it lies where they fell (a dormant pooled zombie in their own risen body, unmarked, no
## hitboxes, no damage), gets up after enemies.json hard_truth.rise_delay_s of round time (4 s, a nod to the fourth
## day; a body that bled out in the break waits for the round) and must be put down; putting it down drops their
## death crate there (FallenCrate, a free ammunition crate). Humans and bots alike; never a companion (Jakub and the
## map companions bleed out "out cold", never dead: Jakub is never a zombie). The respawn rules do not change: the
## survivor comes back at the next round as before, whatever their body is doing.
##
## Settings > Gameplay "hard_truth": auto (the default: on in the story rules, off in Classic Rules), on, off. Host-
## authoritative: one HardTruth per NetMatch (the local bot session and online), run by the authority with the host's
## setting; the body is a normal networked zombie (the spawn event carries the person, net_sub_state 1 keeps the
## client's puppet lying still) and the crate a NetMatch.spawn_dynamic node. Hooked from NetMatch._bleed_out.

const SETTING: String = "hard_truth"
const MODES: PackedStringArray = ["auto", "on", "off"]
const MODE_LABELS: PackedStringArray = ["Story rules (on; off in Classic Rules)", "On", "Off"]
const SQUAD: PackedStringArray = ["dutch", "peg", "deacon", "wren"]
const CRATE_SCRIPT: String = "res://gravelight/world/fallen_crate.gd"

var session: NetMatch = null
## The director that lays the bodies and the node the crates go under: the session's map's unless set (tests hand
## in stand-ins; the director only needs rise_dormant(at, variant, yaw) -> Zombie).
var director: Node = null
var world: Node3D = null
## Bodies lying still: {pid, pos, yaw, left, zombie, person, name}.
var pending: Array[Dictionary] = []
## Bodies that got up and are still on their feet: {pid, zombie, name}.
var risen: Array[Dictionary] = []
var stats: Dictionary = {"bled": 0, "bodies": 0, "rises": 0, "put_down": 0, "crates": 0}
var events: PackedStringArray = []
var last_crate: FallenCrate = null


static func cfg() -> Dictionary:
	return (GLData.table("enemies") as Dictionary).get("hard_truth", {})


## The setting's mode ("auto" for anything unknown).
static func mode_of(values: Dictionary) -> String:
	var m: String = str(values.get(SETTING, "auto"))
	return m if MODES.has(m) else "auto"


## True when the rule is on for these settings: auto follows the rules mode (on in the story rules, off in Classic
## Rules); on / off are the player's own call. Pure.
static func enabled_for(values: Dictionary) -> bool:
	match mode_of(values):
		"on":
			return true
		"off":
			return false
	return not bool(values.get("classic_rules", false))


static func enabled() -> bool:
	return enabled_for(GLSettings.values)


## A survivor whose risen body this rule makes (the squad's person ids in people.json).
static func is_squad_person(id: String) -> bool:
	return SQUAD.has(id)


static func survivor_name(character: String) -> String:
	return str(Net.DISPLAY.get(character, character.capitalize()))


## Whether a bleed-out raises a body (pure): the rule on, a squad member (never a companion), the match still on.
static func should_rise(rule_on: bool, companion: bool, everyone_down: bool, playing: bool) -> bool:
	return rule_on and not companion and not everyone_down and playing


## NetMatch._bleed_out: `pid` just bled out. Authority only; companions never.
func on_bled_out(pid: int) -> void:
	if session == null or not Net.is_authority():
		return
	var p: Player = session.player_of(pid)
	var companion: bool = session.coop.is_companion(pid) or (p != null and p.is_companion)
	if p == null or not should_rise(enabled(), companion, session.coop.everyone_down(), GameState.phase == GameState.Phase.PLAYING):
		return
	begin(pid, String(Net.character_of(pid)), p.global_position, p.rotation.y)


## Lays `pid`'s body (survivor `person`) at `pos` and starts its fourth-day clock.
func begin(pid: int, person: String, pos: Vector3, yaw: float) -> void:
	stats["bled"] = int(stats["bled"]) + 1
	var e: Dictionary = {"pid": pid, "pos": pos, "yaw": yaw, "left": float(cfg().get("rise_delay_s", 4.0)),
		"zombie": null, "person": person, "name": survivor_name(person)}
	pending.append(e)
	_lay_body(e)


## The body on the floor: a dormant pooled zombie in the survivor's risen body. False while the pool is full (the
## next tick tries again; the clock does not start until the body is there).
func _lay_body(e: Dictionary) -> bool:
	var dir: Node = _director()
	if dir == null:
		return false
	var z: Zombie = dir.call(&"rise_dormant", e["pos"] as Vector3, str(cfg().get("fallback_kit", "soldier")), float(e["yaw"])) as Zombie
	if z == null:
		return false
	var person: String = str(e["person"])
	if PeopleBodies.available(person):
		PeopleBodies.dress_risen(z, person)   # the spawn event carries meta "person": every client dresses it the same
	z.clear_marke()   # the squad were never marked (CANON 2.2)
	z.set_meta(&"hard_truth_pid", int(e["pid"]))
	e["zombie"] = z
	stats["bodies"] = int(stats["bodies"]) + 1
	events.append("body:%d" % int(e["pid"]))
	return true


func _director() -> Node:
	if director != null:
		return director
	return session.map.director if session != null and session.map != null else null


func _world() -> Node3D:
	if world != null:
		return world
	return session.map if session != null else null


func _physics_process(delta: float) -> void:
	tick(delta)


## One step of the clocks and the watch on the risen (the physics tick; tests call it directly).
func tick(delta: float) -> void:
	if not Net.is_authority() or (session == null and director == null):
		return
	var ticking: bool = RoundManager.state == RoundManager.State.ROUND and not GameState.in_event()
	for e: Dictionary in pending.duplicate():
		var z: Zombie = e["zombie"] as Zombie if is_instance_valid(e["zombie"]) else null
		if z == null:
			if GameState.phase != GameState.Phase.PLAYING or not _lay_body(e):
				continue
			z = e["zombie"] as Zombie
		if not z.is_dormant() or int(z.get_meta(&"hard_truth_pid", -1)) != int(e["pid"]):
			pending.erase(e)   # recycled while it lay (the pool took it back)
			continue
		if ticking:
			e["left"] = float(e["left"]) - delta
		if float(e["left"]) <= 0.0:
			z.wake_from_dormant(float(cfg().get("getup_s", 2.2)))
			stats["rises"] = int(stats["rises"]) + 1
			events.append("rise:%d" % int(e["pid"]))
			risen.append({"pid": e["pid"], "zombie": z, "name": e["name"]})
			pending.erase(e)
	for r: Dictionary in risen.duplicate():
		var rz: Zombie = r["zombie"] as Zombie if is_instance_valid(r["zombie"]) else null
		if rz == null or int(rz.get_meta(&"hard_truth_pid", -1)) != int(r["pid"]) or rz.state == Zombie.State.INACTIVE:
			risen.erase(r)   # gone without being put down (recycled): no crate
			continue
		if rz.state == Zombie.State.DEAD:
			stats["put_down"] = int(stats["put_down"]) + 1
			events.append("down:%d" % int(r["pid"]))
			rz.remove_meta(&"hard_truth_pid")
			drop_crate(rz.global_position, str(r["name"]))
			risen.erase(r)


## The death crate where the body fell, mirrored to every client.
func drop_crate(at: Vector3, owner: String) -> FallenCrate:
	var w: Node3D = _world()
	if w == null:
		return null
	var c: FallenCrate = FallenCrate.new()
	c.owner_name = owner
	c.uses_left = int(cfg().get("crate_uses", 4))
	c.seconds_left = float(cfg().get("crate_seconds", 90.0))
	w.add_child(c)
	var nav: RID = w.get_world_3d().navigation_map
	var p: Vector3 = NavigationServer3D.map_get_closest_point(nav, at)
	c.global_position = p if p.is_finite() and p != Vector3.ZERO and p.distance_to(at) < 3.0 else at
	stats["crates"] = int(stats["crates"]) + 1
	events.append("crate:" + owner)
	last_crate = c
	if Net.replicating() and session != null:
		session.spawn_dynamic(c, CRATE_SCRIPT, {"owner_name": owner, "uses_left": c.uses_left, "seconds_left": c.seconds_left})
	return c


## The body still lying for `pid` (tests, smokes): its zombie, or null.
func body_of(pid: int) -> Zombie:
	for e: Dictionary in pending:
		if int(e["pid"]) == pid and is_instance_valid(e["zombie"]):
			return e["zombie"] as Zombie
	for r: Dictionary in risen:
		if int(r["pid"]) == pid and is_instance_valid(r["zombie"]):
			return r["zombie"] as Zombie
	return null


## Seconds left before `pid`'s body gets up (-1 when none is lying).
func rise_left(pid: int) -> float:
	for e: Dictionary in pending:
		if int(e["pid"]) == pid:
			return float(e["left"])
	return -1.0
