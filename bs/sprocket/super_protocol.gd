class_name SuperProtocol
extends Node
## SUPER SPROCKET PROTOCOL (superActivate / updateSuperSprocket / superEnd, index.html:4001-4100; GDD §3.3).
##   Meter: fills from damage dealt (+dmg x 0.0006 per hit, damageEnemy 5301) scaled by the current combo
##          tier (GDD addition), only once the protocol is owned (BS.super_owned) and while it isn't running.
##          The mallet also adds 0.012 per combo hit (BoltMelee.combo_hit).
##   Activate: the super_sprocket action with a full meter. 30 s; everything hits twice as hard (damage_mult()).
##   Modes picked from the situation (GDD section 3.3):
##     OVERCLOCK (otherwise): the original's autonomous twin-cannon turret that zips between targets.
##     BULWARK (Bolt hurting): shield and taunt. Sprocket guards between Bolt and the nearest threat, Bolt takes
##       a fraction of every hit and regenerates, and enemy shots near Bolt are knocked down (T-029).
##     ZIP (a crowd): Sprocket rams from enemy to enemy, a damage burst on every arrival (T-029).
## Child of Sprocket. Tuning: data/bs/sprocket.json "super".

signal activated(mode: StringName, requested: StringName)
signal ended

const MODES: Array[StringName] = [&"overclock", &"bulwark", &"zip"]
const IMPLEMENTED: Array[StringName] = [&"overclock", &"bulwark", &"zip"]

var C: Dictionary
var sprocket: Node3D
var active: bool = false
var t: float = 0.0
var mode: StringName = &""
var requested_mode: StringName = &""
var target: Node3D = null
var retarget: float = 0.0
var bark_t: float = 0.0
var fire_acc: float = 0.0
var zip: float = 0.0
var combo_hits: int = 0
var hop_t: float = 0.0
var hops: int = 0
var denied: int = 0
var shots_fired: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	C = (Data.table("bs/sprocket") as Dictionary)["super"]
	rng.randomize()
	EventBus.enemy_hit.connect(_on_enemy_hit)
	EventBus.combo_changed.connect(func(h: int) -> void: combo_hits = h)


func _init_cfg() -> void:
	if C.is_empty():
		C = (Data.table("bs/sprocket") as Dictionary)["super"]


## Damage-fill multiplier from the combo tier.
func combo_mult(hits: int = -1) -> float:
	_init_cfg()
	var h: int = combo_hits if hits < 0 else hits
	var m: float = 1.0
	for tier: Variant in C["combo_tiers"]:
		if h >= int((tier as Array)[0]):
			m = float((tier as Array)[1])
	return m


## The charge a hit of `amount` adds right now.
func fill_for(amount: float) -> float:
	_init_cfg()
	return amount * float(C["fill_per_damage"]) * combo_mult()


func _on_enemy_hit(_enemy: Node, hit: RefCounted, _killed: bool) -> void:
	var h: Combat.Hit = hit as Combat.Hit
	if h == null or active or h.weapon_id == &"super_sprocket":
		return
	BS.add_super(fill_for(h.amount))


func damage_mult() -> float:
	return float(C.get("damage_mult", 2.0)) if active else 1.0


func _bolt() -> Bolt:
	return sprocket.get("bolt") as Bolt if sprocket != null else null


## Picks a mode from the situation (GDD §3.3).
func pick_mode() -> StringName:
	_init_cfg()
	var P: Dictionary = C["mode_pick"]
	var b: Bolt = _bolt()
	if b == null:
		return &"overclock"
	if b.hp <= b.max_hp * float(P["bulwark_hp_frac"]):
		return &"bulwark"
	var near: int = Combat.in_radius(get_tree(), b.global_position, float(P["scan_range"]), &"enemies") \
		.filter(func(e: Node3D) -> bool: return not e.is_in_group(&"props")).size()
	if near >= int(P["zip_enemies"]):
		return &"zip"
	return &"overclock"


## Tries to start the protocol. Returns true when it started.
func activate() -> bool:
	_init_cfg()
	var b: Bolt = _bolt()
	if not BS.super_owned or active or BS.blocked() or (b != null and b.dead):
		return false
	if BS.super_meter < 1.0:
		EventBus.hint.emit(BSText.text("code.superActivate.01"), "")
		return false
	BS.super_meter = 0.0
	EventBus.super_meter_changed.emit(0.0)
	requested_mode = pick_mode()
	mode = requested_mode if requested_mode in IMPLEMENTED else &"overclock"
	active = true
	t = float(C["duration"])
	target = null
	retarget = 0.0
	bark_t = float(C["bark_first"])
	if not BS.flag("super_seen"):          # first time: slow-mo transform + the big banner
		BS.set_flag("super_seen")
		Game.slowmo(float(C["first_slowmo"]))
		EventBus.banner.emit(BSText.text("code.superActivate.02"), BSText.text("code.superActivate.03"), 2.4)
		BS.save_to_profile()
	else:
		EventBus.banner.emit(BSText.text("code.superActivate.04"), BSText.text("bs.ui.super." + String(requested_mode)), 1.2)
	hop_t = 0.0
	if mode == &"bulwark" and b != null:
		b.damage_taken_mult = float(C["bulwark"]["damage_taken_mult"])
	if sprocket != null and sprocket.has_method("on_super"):
		sprocket.call("on_super", true)
	activated.emit(mode, requested_mode)
	return true


func end() -> void:
	if not active:
		return
	active = false
	target = null
	var b: Bolt = _bolt()
	if b != null:
		b.damage_taken_mult = 1.0
	if sprocket != null and sprocket.has_method("on_super"):
		sprocket.call("on_super", false)
	BSText.say("code.superEnd.01")
	ended.emit()


## Per frame while active. Returns where Sprocket wants to be (Vector3.INF = stay at Bolt's shoulder).
func update(dt: float) -> Vector3:
	if not active:
		return Vector3.INF
	t -= dt
	if t <= 0.0:
		end()
		return Vector3.INF
	retarget -= dt
	bark_t -= dt
	if bark_t <= 0.0:
		bark_t = rng.randf_range(float(C["bark_min"]), float(C["bark_max"]))
		var ids: PackedStringArray = super_lines()
		if not ids.is_empty():
			BSText.say(ids[rng.randi_range(0, ids.size() - 1)])
	if mode == &"bulwark":
		return _update_bulwark(dt)
	if mode == &"zip":
		return _update_zip(dt)
	if target == null or not is_instance_valid(target) or not target.call("is_alive") or retarget <= 0.0:
		var best: Node3D = _nearest()
		if best != null and best != target:
			zip = float(C["zip_time"])      # zip burst to the new mark
		target = best
		retarget = float(C["retarget"])
	if target == null:
		return Vector3.INF
	zip = maxf(0.0, zip - dt)
	var c: Vector3 = target.call("get_center")
	var st: float = Time.get_ticks_msec() / 1000.0
	var want: Vector3 = c + Vector3(cos(st * float(C["orbit_rate"])) * float(C["orbit_radius"]), float(C["orbit_height"]),
		sin(st * float(C["orbit_rate"])) * float(C["orbit_radius"]))
	fire_acc += dt
	if fire_acc > float(C["fire_interval"]):
		fire_acc = 0.0
		fire_at(c)
	return want


## BULWARK: guard position between Bolt and the nearest threat; heal Bolt; swat enemy shots near Bolt.
func _update_bulwark(dt: float) -> Vector3:
	var B: Dictionary = C["bulwark"]
	var b: Bolt = _bolt()
	if b == null:
		return Vector3.INF
	b.heal(float(B["heal_per_s"]) * dt)
	for n: Node in get_tree().get_nodes_in_group(&"enemy_projectiles"):
		var pr: Node3D = n as Node3D
		if pr != null and pr.global_position.distance_to(b.get_center()) < float(B["deny_radius"]) and pr.has_method("deny"):
			pr.call("deny")
			denied += 1
	var threat: Node3D = _nearest()
	var dir: Vector3 = -b.global_basis.z
	if threat != null:
		dir = threat.global_position - b.global_position
		dir.y = 0.0
		dir = dir.normalized() if dir.length() > 0.01 else -b.global_basis.z
		fire_acc += dt
		if fire_acc > float(C["fire_interval"]) * 2.0:   # it still returns fire, at half the turret's rate
			fire_acc = 0.0
			fire_at(threat.call("get_center"))
	return b.global_position + dir * float(B["guard_distance"]) + Vector3.UP * float(B["guard_height"])


## ZIP: hop to the next mark every hop_interval and burst on arrival.
func _update_zip(dt: float) -> Vector3:
	var Z: Dictionary = C["zip"]
	hop_t -= dt
	if target == null or not is_instance_valid(target) or not target.call("is_alive"):
		target = _nearest()
	if target == null:
		return Vector3.INF
	var c: Vector3 = target.call("get_center")
	if hop_t <= 0.0:
		hop_t = float(Z["hop_interval"])
		zip = float(C["zip_time"])
		hops += 1
		for e: Node3D in Combat.in_radius(get_tree(), c, float(Z["hop_radius"]), &"enemies"):
			if e.is_in_group(&"props") or not e.call("is_alive"):
				continue
			var h: Combat.Hit = Combat.Hit.new()
			h.amount = float(Z["hop_damage"]) * damage_mult()
			h.type = Combat.Type.KINETIC
			h.source = sprocket
			h.weapon_id = &"super_sprocket"
			h.point = e.call("get_center")
			h.dir = (h.point - c).normalized() if h.point.distance_to(c) > 0.01 else Vector3.UP
			h.knock = 3.0
			e.call("take_damage", h)
		target = _next_mark(target)   # the next hop goes somewhere else
	return c + Vector3.UP * 0.9


## The closest live enemy to `from_e` that isn't it (falls back to the nearest to Bolt).
func _next_mark(from_e: Node3D) -> Node3D:
	var best: Node3D = null
	var bd: float = float(C["zip"]["hop_range"])
	for n: Node in get_tree().get_nodes_in_group(&"enemies"):
		var e: Node3D = n as Node3D
		if e == null or e == from_e or e.is_in_group(&"props") or not e.call("is_alive"):
			continue
		var d: float = e.global_position.distance_to(from_e.global_position)
		if d < bd:
			bd = d
			best = e
	return best if best != null else _nearest()


func _nearest() -> Node3D:
	var b: Bolt = _bolt()
	var from: Vector3 = b.global_position if b != null else sprocket.global_position
	var best: Node3D = null
	var bd: float = float(C["target_range"])
	for n: Node in get_tree().get_nodes_in_group(&"enemies"):
		var e: Node3D = n as Node3D
		if e == null or e.is_in_group(&"props") or not e.call("is_alive"):
			continue
		var d: float = e.global_position.distance_to(from)
		if d < bd:
			bd = d
			best = e
	return best


func fire_at(point: Vector3) -> SuperShot:
	var from: Vector3 = sprocket.global_position if sprocket != null else Vector3.ZERO
	var dir: Vector3 = (point - from).normalized()
	var s: SuperShot = SuperShot.new()
	s.damage = float(C["shot_damage"]) * damage_mult()
	s.life = float(C["shot_life"])
	s.source = sprocket
	var parent: Node = sprocket.get_parent() if sprocket != null and sprocket.get_parent() != null else get_tree().current_scene
	parent.add_child(s)
	s.launch(from + dir * 0.4, dir * float(C["shot_speed"]))
	shots_fired += 1
	return s


static func super_lines() -> PackedStringArray:
	var out: PackedStringArray = []
	var doc: Variant = Data.table("bs/story/barks")
	if doc is Dictionary:
		for e: Variant in ((doc as Dictionary).get("super_sprocket", {}) as Dictionary).get("all", []):
			out.append(str((e as Dictionary)["id"]))
	return out
