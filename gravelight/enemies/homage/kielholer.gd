class_name Kielholer
extends HomageBoss
## DER KIELHOLER, Totenhafen's boss (UPDATE 10 contract C5, docs/U10_TOTENHAFEN_DESIGN.md section 4, DECISIONS
## T-153; data bosses/map02.json "der_kielholer"). Kapitaenleutnant Arvid Lenz went down to the pump deck in the
## harbour's salvage diving dress to wreck the battery cells so nobody could take U-1047 out with her cargo; the Marke
## under his helmet glass kept him there. His last impulse is *keep her in the pen*: he is not a joke and not a
## monster for its own sake (the death is quiet; his last line lets the squad go).
##
## The arena is the whole Pen Hall. He surfaces at a dock (dock 2 first), walks the piers and the aprons, and each
## time another quarter of his HP is gone he SINKS (invulnerable), and after submerge_seconds a RIPPLE telegraphs
## where he comes up (another dock; at high / spring tide the dock nearest his target, and he is tide_speed_mult
## faster). Moves: the anchor-chain SWEEP (a 1.2 s overhead wind-up, then a 9 m line that pulls hit players 4 m toward
## him and knocks them down), the helmet-first CHARGE along a pier (the helmet lamp turns to the target first), the
## GRAB at a dock edge (the Kielholer pull, stronger; break by melee, teammates' damage, the weak points, or time) and
## a close SWIPE. Weak points: the helmet glass (x1.0 until helmet_break_fraction of his max HP is gone, then it
## breaks with a roar and the violet glow behind it takes x2.0: the Marke he wears), the back of the suit where the
## chain rubs (x1.3). Fail-safe: failsafe_seconds after he first surfaces he dives for good and the ignition key floats
## up at the nearest dock edge (the egg can never softlock on him). His death drops the key at the body.
## Pure rules are static for the tests.

enum K { RISE, WALK, SWIPE_TELE, SWEEP_TELE, SWEEP, CHARGE_TELE, CHARGE, GRAB, RECOVER, SINK, UNDER, RIPPLE }

var kcfg: Dictionary = {}
var kstate: K = K.RISE
var dock: String = "dock2"
var submerges: int = 0
var helmet_broken: bool = false
var sweeps_done: int = 0
var charges_done: int = 0
var grabs_done: int = 0
var swipes_done: int = 0
var spawn_t: float = 0.0
var failsafe_dived: bool = false
var _kt: float = 0.0
var _under_for: float = 8.0
var _aim: Vector3 = Vector3.FORWARD
var _charge_from: Vector3 = Vector3.ZERO
var _charge_hit: bool = false
var _grab: Dictionary = {}
var _grab_dmg: float = 0.0
var _grab_dmg_t: float = 0.0
var _lamp: SpotLight3D = null
var _lamp_glow: OmniLight3D = null
var _glass: MeshInstance3D = null
var _glow: Node3D = null
var _ripple: MeshInstance3D = null
var _title_done: bool = false
var _hud: BossHud = null
var _lines_said: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


static func table() -> Dictionary:
	return GLData.table("bosses/map02")


func boss_cfg() -> Dictionary:
	return (table().get("bosses", {}) as Dictionary).get("der_kielholer", {})


# ================================================================== pure rules (unit-tested)

## Is a submerge due at this HP fraction after `done` submerges? At every `every` of HP lost (75 / 50 / 25 %), never
## at zero.
static func submerge_due(hp_frac: float, done: int, every: float) -> bool:
	var next: float = 1.0 - every * float(done + 1)
	return next > 0.001 and hp_frac <= next + 0.0001


## Which dock he surfaces at next: never the one he left; `near` (high / spring tide) = the one closest to `target`,
## else one by `roll` in 0..1.
static func pick_dock(docks: Dictionary, current: String, target: Vector3, near: bool, roll: float) -> String:
	var keys: Array = docks.keys()
	keys.sort()
	keys.erase(current)
	if keys.is_empty():
		return current
	if near:
		var best: String = str(keys[0])
		var bd: float = INF
		for k: Variant in keys:
			var a: Array = docks[k]
			var d: float = Vector2(float(a[0]) - target.x, float(a[2]) - target.z).length()
			if d < bd:
				bd = d
				best = str(k)
		return best
	return str(keys[clampi(int(floor(roll * float(keys.size()))), 0, keys.size() - 1)])


## His speed factor for a tide stage (x tide_speed_mult at high and spring).
static func tide_mult(stage: StringName, c: Dictionary) -> float:
	return float(c.get("tide_speed_mult", 1.3)) if (c.get("tide_fast_stages", ["high", "spring"]) as Array).has(String(stage)) else 1.0


## Does the helmet glass break after `taken` damage of `max_hp`?
static func helmet_breaks(taken: float, max_hp: float, c: Dictionary) -> bool:
	return taken >= max_hp * float(c.get("helmet_break_fraction", 0.15))


static func failsafe_due(seconds: float, table_cfg: Dictionary) -> bool:
	return seconds >= float(table_cfg.get("failsafe_seconds", 420.0))


## Is a body at `p` on the chain sweep's line from `origin` along `fwd` (flat)?
static func sweep_hits(origin: Vector3, fwd: Vector3, p: Vector3, reach: float, half_width: float) -> bool:
	var f: Vector3 = Vector3(fwd.x, 0, fwd.z).normalized()
	var d: Vector3 = Vector3(p.x - origin.x, 0, p.z - origin.z)
	var along: float = d.dot(f)
	if along < 0.0 or along > reach:
		return false
	return (d - f * along).length() <= half_width and absf(p.y - origin.y) < 2.5


## HP for the squad: base x (1 + step x (players - 1)) x the bots-alone health mult when no human is up.
static func boss_hp(players: int, bots_alone_on: bool, table_cfg: Dictionary) -> float:
	var b: Dictionary = (table_cfg.get("bosses", {}) as Dictionary).get("der_kielholer", {})
	var hp0: float = scaled_hp(float(b.get("hp_base", 28000)), players, float(table_cfg.get("hp_player_step", 0.75)))
	if bots_alone_on:
		hp0 *= float((table_cfg.get("bots_alone", {}) as Dictionary).get("hp_mult", 0.5))
	return hp0


# ================================================================== setup

func _ready() -> void:
	super._ready()
	boss_key = "der_kielholer"
	ecfg = table()
	kcfg = boss_cfg()
	bcfg = kcfg
	_rng.seed = hash("kielholer_boss_%d" % Time.get_ticks_usec())


func modelled() -> bool:
	return false


func person_id() -> String:
	return "der_kielholer"


func limb_mult(limb: StringName) -> float:
	if limb == &"helmet_glass" and helmet_broken:
		return float((kcfg.get("limb_mult", {}) as Dictionary).get("helmet_glow", 2.0))
	return super.limb_mult(limb)


func _docks() -> Dictionary:
	var t: Node = get_tree().get_first_node_in_group(&"totenhafen")
	var all: Dictionary = t.get("cfg") if t != null and t.get("cfg") is Dictionary else GLData.load_json("res://data/gravelight/map02.json")
	return (all.get("letzte_fahrt", {}) as Dictionary).get("boss_docks", {})


func _dock_pos(key: String) -> Vector3:
	var a: Array = _docks().get(key, [13.2, 0.0, 70.0])
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


## Brings him up at `at` (the quest's dock 2, or the standalone summon) with `health` already scaled.
func spawn_kielholer(at: Vector3, health: float) -> void:
	spawn_homage(at, health)
	enemy_id = &"der_kielholer"
	_apply_variant("drowned_diver")
	for g: MeshInstance3D in _gear:
		g.hide()   # his own helmet (the costume below), not the rank-and-file diver's
	_female = false
	_pivot.scale = Vector3.ONE * float(kcfg.get("height", 1.12))
	_set_inst("inst_tint", Color(0.85, 0.95, 0.95, 1.0))
	_set_inst("inst_dirt", 0.6)
	_add_weak_hitboxes()
	# the nearest dock key to where he came up
	var best: float = INF
	for k: Variant in _docks().keys():
		var d: float = _dock_pos(str(k)).distance_to(at)
		if d < best:
			best = d
			dock = str(k)
	kstate = K.RISE
	_kt = 0.0
	spawn_t = 0.0
	submerges = 0
	helmet_broken = false
	failsafe_dived = false
	_pivot.position.y = -2.0
	RoundManager.reserve_alive(1)
	AudioDirector.play_3d("kielholer_surface", global_position, 4.0, 0.0)
	if not _title_done:
		_title_done = true
		_hud = BossHud.new()
		_map().add_child(_hud)
		var title: String = str(kcfg.get("title", "DER KIELHOLER"))
		var sub: String = str(kcfg.get("subtitle", "Kapitänleutnant Arvid Lenz, U-1047"))
		_hud.title_card(title, sub, str(kcfg.get("date_line", "JANUAR 1945  ·  TOTENHAFEN")))
		_hud.add_bar("der_kielholer", self, title, sub)
		if str(kcfg.get("spawn_vo", "")) != "":
			GLVO.play(StringName(str(kcfg["spawn_vo"])))
		_line_from("lines_spawn", 3.0)
		_squad_line("squad_spawn", 6.0)


func _map() -> Node:
	var n: Node = get_parent()
	while n != null and not (n is MapRoot):
		n = n.get_parent()
	return n if n != null else get_parent()


func _add_weak_hitboxes() -> void:
	if has_node("WeakPoints"):
		return
	var marker: Node = Node.new()
	marker.name = "WeakPoints"
	add_child(marker)
	var head: Node3D = bone_attachment("Head")
	var hg: Hitbox = Hitbox.new()
	hg.name = "HelmetGlass"
	hg.setup(self, &"helmet_glass", Vector3(0.26, 0.26, 0.12))
	hg.bone = "Head"
	hg.position = Vector3(0, 0.12, -0.22)
	(head if head != null else self).add_child(hg)
	_hitboxes.append(hg)
	var chest: Node3D = bone_attachment("Chest")
	var bk: Hitbox = Hitbox.new()
	bk.name = "Back"
	bk.setup(self, &"back", Vector3(0.42, 0.36, 0.1))
	bk.bone = "Chest"
	bk.position = Vector3(0, 0.15, 0.17)
	(chest if chest != null else self).add_child(bk)
	_hitboxes.append(bk)


## The diving dress: the brass helmet with its lit port and lamp, the corselet, the anchor chain over the left
## shoulder, lead-soled boots (primitives on bone attachments; HOMAGE_BOSSES 3.4 costume pieces).
func _build_costume() -> void:
	var brass: Color = Color(0.58, 0.46, 0.22)
	var dark_brass: Color = Color(0.36, 0.28, 0.14)
	var iron: Color = Color(0.22, 0.22, 0.23)
	var rubber: Color = Color(0.16, 0.15, 0.13)
	costume("Head", [
		sph(0.235, Vector3(0, 0.12, 0.0), brass, Vector3(1.0, 1.05, 1.0)),
		cyl(0.1, 0.1, 0.05, Vector3(0, 0.12, -0.22), dark_brass, Vector3(PI * 0.5, 0, 0)),
		cyl(0.055, 0.055, 0.035, Vector3(-0.22, 0.14, -0.04), dark_brass, Vector3(0, 0, PI * 0.5)),
		cyl(0.055, 0.055, 0.035, Vector3(0.22, 0.14, -0.04), dark_brass, Vector3(0, 0, PI * 0.5)),
		boxp(Vector3(0.06, 0.07, 0.08), Vector3(0, 0.33, 0.06), iron),
		cyl(0.035, 0.03, 0.12, Vector3(0.0, 0.2, 0.22), iron, Vector3(PI * 0.5, 0, 0)),   # the air hose's fitting
	])
	_glass = costume("Head", [cyl(0.085, 0.085, 0.012, Vector3(0, 0.12, -0.246), Color(0.9, 0.75, 0.45), Vector3(PI * 0.5, 0, 0))], 0.8)
	costume("Chest", [
		cyl(0.29, 0.31, 0.09, Vector3(0, 0.3, 0.0), brass, Vector3.ZERO, Vector3(1.0, 1.0, 0.85)),
		boxp(Vector3(0.44, 0.4, 0.3), Vector3(0, 0.12, 0.0), rubber),
	])
	# the anchor chain: links from the left shoulder across the chest to the right hip, and a stock hanging behind
	var links: Array = []
	for i: int in 9:
		var f: float = float(i) / 8.0
		var p: Vector3 = Vector3(lerpf(-0.17, 0.16, f), lerpf(0.34, -0.2, f), -0.17 + sin(f * PI) * -0.03)
		links.append(boxp(Vector3(0.05, 0.075, 0.025) if i % 2 == 0 else Vector3(0.025, 0.075, 0.05), p, iron, Vector3(0, 0, -0.75)))
	for j: int in 7:
		var g: float = float(j) / 6.0
		links.append(boxp(Vector3(0.05, 0.075, 0.025) if j % 2 == 0 else Vector3(0.025, 0.075, 0.05), Vector3(-0.17 + g * 0.05, 0.34 - g * 0.5, 0.18), iron))
	links.append(boxp(Vector3(0.36, 0.05, 0.05), Vector3(-0.12, -0.18, 0.2), iron, Vector3(0, 0, 0.3)))
	costume("Chest", links)
	for foot: String in ["LeftFoot", "RightFoot"]:
		costume(foot, [boxp(Vector3(0.14, 0.07, 0.3), Vector3(0, -0.04, -0.04), dark_brass), boxp(Vector3(0.15, 0.04, 0.31), Vector3(0, -0.085, -0.04), iron)])
	for hand: String in ["LeftHand", "RightHand"]:
		costume(hand, [boxp(Vector3(0.11, 0.13, 0.07), Vector3(0, -0.05, 0), rubber)])
	# the helmet lamp (the charge's telegraph turns it to the target) and its glow
	var head: Node3D = bone_attachment("Head")
	_lamp = SpotLight3D.new()
	_lamp.name = "HelmetLamp"
	_lamp.light_color = Color(1.0, 0.85, 0.55)
	_lamp.light_energy = 1.2
	_lamp.spot_range = 14.0
	_lamp.spot_angle = 18.0
	_lamp.shadow_enabled = false
	_lamp.position = Vector3(0, 0.34, -0.1)
	_lamp.set_meta("zone", "D_PENHALL")
	(head if head != null else self).add_child(_lamp)
	_lamp_glow = OmniLight3D.new()
	_lamp_glow.light_color = Color(1.0, 0.8, 0.5)
	_lamp_glow.light_energy = 0.5
	_lamp_glow.omni_range = 2.0
	_lamp_glow.shadow_enabled = false
	_lamp_glow.position = Vector3(0, 0.12, -0.3)
	(head if head != null else self).add_child(_lamp_glow)
	_glow = KielholerController._glow_node()
	_glow.position = Vector3(0, 0.12, -0.24)
	_glow.scale = Vector3.ONE * 1.3
	_glow.visible = false
	(head if head != null else self).add_child(_glow)


# ================================================================== the brain

func _tide_stage() -> StringName:
	var tide: Node = get_tree().get_first_node_in_group(&"tide")
	return StringName(str(tide.get("stage"))) if tide != null and tide.get("stage") != null else &"low"


func _speed() -> float:
	return move_speed() * tide_mult(_tide_stage(), kcfg)


func _tick(delta: float) -> void:
	spawn_t += delta
	_kt += delta
	if failsafe_due(spawn_t, ecfg) and not retreating:
		failsafe_dived = true
		retreat()
		return
	if not helmet_broken and kstate != K.UNDER and helmet_breaks(max_hp - hp, max_hp, kcfg):
		_break_helmet()
	match kstate:
		K.RISE:
			stand(delta)
			_pivot.position.y = lerpf(-2.0, 0.0, clampf(_kt / 1.2, 0.0, 1.0))
			if _kt >= 1.2:
				_pivot.position.y = 0.0
				_set_k(K.WALK)
				bstate = B.MOVE
		K.WALK:
			_walk_tick(delta)
		K.SWIPE_TELE:
			stand(delta)
			var sw: Dictionary = kcfg.get("swipe", {})
			if _kt >= tele_len(float(sw.get("telegraph", 0.5))):
				if target != null and dist_to(target) <= float(sw.get("range", 2.4)) + 0.4:
					hit_player(target, float(sw.get("damage", 55)))
				swipes_done += 1
				set_cd("swipe", float(sw.get("cooldown", 1.6)))
				_set_k(K.RECOVER)
		K.SWEEP_TELE:
			stand(delta, false)
			if target != null and _kt < tele_len(float(kcfg.get("chain_sweep", {}).get("telegraph", 1.2))) * 0.7:
				_aim = Vector3(target.global_position.x - global_position.x, 0, target.global_position.z - global_position.z).normalized()
				_face(global_position + _aim)
			if _kt >= tele_len(float(kcfg.get("chain_sweep", {}).get("telegraph", 1.2))):
				_do_sweep()
				_set_k(K.RECOVER)
		K.CHARGE_TELE:
			stand(delta, false)
			var cc: Dictionary = kcfg.get("charge", {})
			if target != null and _kt < tele_len(float(cc.get("telegraph", 1.0))) * 0.8:
				_aim = Vector3(target.global_position.x - global_position.x, 0, target.global_position.z - global_position.z).normalized()
				_face(global_position + _aim)
			if _lamp != null:
				_lamp.light_energy = lerpf(1.2, 6.0, clampf(_kt / 0.4, 0.0, 1.0))
			if _kt >= tele_len(float(cc.get("telegraph", 1.0))):
				_charge_from = global_position
				_charge_hit = false
				_set_k(K.CHARGE)
				bstate = B.ACTIVE
		K.CHARGE:
			_charge_tick(delta)
		K.GRAB:
			_grab_tick_k(delta)
		K.RECOVER:
			stand(delta)
			if _lamp != null:
				_lamp.light_energy = move_toward(_lamp.light_energy, 1.2, delta * 8.0)
			if _kt >= 0.8:
				_set_k(K.WALK)
				bstate = B.MOVE
		K.SINK:
			_halt(delta)
			_pivot.position.y = lerpf(0.0, -2.2, clampf(_kt / float(kcfg.get("sink_seconds", 1.4)), 0.0, 1.0))
			if _kt >= float(kcfg.get("sink_seconds", 1.4)):
				_go_under()
		K.UNDER:
			velocity = Vector3.ZERO
			if _kt >= _under_for:
				_start_ripple()
		K.RIPPLE:
			velocity = Vector3.ZERO
			if _ripple != null:
				_ripple.scale = Vector3.ONE * (1.0 + _kt * 1.4)
			if _kt >= float(kcfg.get("ripple_seconds", 1.6)):
				_resurface()


func _set_k(k: K) -> void:
	kstate = k
	_kt = 0.0


func _walk_tick(delta: float) -> void:
	if submerge_due(hp_fraction(), submerges, float(kcfg.get("submerge_every", 0.25))):
		_start_sink()
		return
	if target == null:
		stand(delta)
		return
	var d: float = dist_to(target)
	var gr: Dictionary = kcfg.get("grab", {})
	var sw: Dictionary = kcfg.get("chain_sweep", {})
	var cc: Dictionary = kcfg.get("charge", {})
	var sp: Dictionary = kcfg.get("swipe", {})
	if cd_ready("grab") and d <= float(gr.get("range", 2.2)) and can_grab(target) and KielholerController.edge_distance(target.global_position) < 4.0:
		_start_grab(target)
	elif cd_ready("swipe") and d <= float(sp.get("range", 2.4)):
		_set_k(K.SWIPE_TELE)
		bstate = B.TELEGRAPH
		attack_anim("swipe_over", tele_len(float(sp.get("telegraph", 0.5))))
	elif cd_ready("sweep") and d >= float(sw.get("min_range", 3.0)) and d <= float(sw.get("range", 9.0)) - 0.5 and has_los(target):
		_set_k(K.SWEEP_TELE)
		_go(B.TELEGRAPH, "sweep")
		pose_anim()
		sfx("chain_sweep", 0.0, 0.9)
	elif cd_ready("charge") and d >= float(cc.get("min_range", 5.0)) and d <= float(cc.get("max_range", 18.0)) and has_los(target):
		_set_k(K.CHARGE_TELE)
		_go(B.TELEGRAPH, "charge")
		pose_anim()
		sfx("kielholer_roar", -6.0, 1.2)
	else:
		walk_to(target.global_position, delta, _speed())


func _do_sweep() -> void:
	var sw: Dictionary = kcfg.get("chain_sweep", {})
	sweeps_done += 1
	set_cd("sweep", float(sw.get("cooldown", 7.0)))
	sfx("chain_sweep", 2.0, 1.0)
	attack_anim("swipe_double", 0.3)
	for p: Player in alive_players():
		if sweep_hits(global_position, _aim, p.global_position, float(sw.get("range", 9.0)), float(sw.get("half_width", 1.1))):
			hit_player(p, float(sw.get("damage", 45)))
			var to_me: Vector3 = Vector3(global_position.x - p.global_position.x, 0, global_position.z - p.global_position.z)
			var pull: float = minf(float(sw.get("pull_m", 4.0)), maxf(0.0, to_me.length() - 1.5))
			var secs: float = float(sw.get("pull_seconds", 0.35))
			if pull > 0.05:
				p.external_push(to_me.normalized() * (pull / secs), secs, &"pull")
			p.apply_status(&"knockdown", float(sw.get("knockdown_s", 1.2)))


func _charge_tick(delta: float) -> void:
	var cc: Dictionary = kcfg.get("charge", {})
	velocity = _aim * float(cc.get("speed", 9.0)) * squad_speed_mult * tide_mult(_tide_stage(), kcfg)
	velocity.y = -2.0
	move_and_slide()
	_face(global_position + _aim)
	if not _charge_hit:
		for p: Player in alive_players():
			if Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length() <= float(cc.get("hit_radius", 1.3)):
				_charge_hit = true
				hit_player(p, float(cc.get("damage", 70)))
				p.external_push(_aim * float(cc.get("knock_mps", 7.0)), 0.35, &"push")
				break
	var travelled: float = Vector2(global_position.x - _charge_from.x, global_position.z - _charge_from.z).length()
	var blocked: bool = get_slide_collision_count() > 0 and _kt > 0.25 and velocity.length() < 1.0
	if _charge_hit or travelled >= float(cc.get("max_m", 14.0)) or blocked or _kt > 3.0:
		charges_done += 1
		set_cd("charge", float(cc.get("cooldown", 9.0)))
		velocity = Vector3.ZERO
		_set_k(K.RECOVER)
		bstate = B.RECOVER


func _start_grab(p: Player) -> void:
	var gr: Dictionary = kcfg.get("grab", {})
	_grab = grab_start(p, "kielholer", {"mash": int(gr.get("break_melee", 4)), "team": float(gr.get("break_team_damage", 300.0)),
		"weak": float(gr.get("break_weak_damage", 400.0)), "max": float(gr.get("max_hold", 5.0))}, [&"back", &"helmet_glass", &"arms"], "grab")
	_grab_dmg = 0.0
	_grab_dmg_t = 0.0
	grabs_done += 1
	_set_k(K.GRAB)
	_go(B.SPECIAL, "grab")
	attack_anim("grab", 0.3)
	sfx("kielholer_surface", 0.0, 0.8)


func _grab_tick_k(delta: float) -> void:
	stand(delta)
	if _grab.is_empty() or not grabs().has(_grab):
		_end_grab()
		return
	var p: Player = _grab["p"]
	var gr: Dictionary = kcfg.get("grab", {})
	var edge: Vector3 = KielholerController.edge_point(p.global_position)
	drag_player(p, edge, float(gr.get("pull_mps", 1.8)) * squad_speed_mult, delta, 0.4)
	var ed: float = KielholerController.edge_distance(p.global_position)
	_grab_dmg += (float(gr.get("edge_dps", 28.0)) if ed <= float(gr.get("edge_m", 1.6)) else float(gr.get("dps", 12.0))) * delta
	_grab_dmg_t += delta
	if _grab_dmg_t >= 0.5:
		hit_player(p, _grab_dmg)
		_grab_dmg = 0.0
		_grab_dmg_t = 0.0
	# he walks with his catch toward the water
	var follow: Vector3 = p.global_position + (global_position - p.global_position).normalized() * 0.9
	global_position = Vector3(follow.x, global_position.y, follow.z)


func _on_grab_released(_g: Dictionary, _reason: String) -> void:
	if kstate == K.GRAB:
		_end_grab()


func _end_grab() -> void:
	_grab = {}
	set_cd("grab", float(kcfg.get("grab", {}).get("cooldown", 10.0)))
	_set_k(K.RECOVER)
	bstate = B.RECOVER


# ================================================================== submerge / resurface

func _start_sink() -> void:
	submerges += 1
	_release_all_grabs("submerge")
	_set_k(K.SINK)
	_go(B.SPECIAL, "submerge")
	sfx("kielholer_surface", 0.0, 0.7)
	_hitboxes_on(false)
	if submerges == 2:
		_line_from("lines_hurt", 0.5)


func _go_under() -> void:
	var r: Array = kcfg.get("submerge_seconds", [6.0, 10.0])
	_under_for = _rng.randf_range(float(r[0]), float(r[1]))
	_set_k(K.UNDER)
	hide()
	collision_layer = 0
	velocity = Vector3.ZERO


func _start_ripple() -> void:
	var near: bool = tide_mult(_tide_stage(), kcfg) > 1.0
	var tp: Vector3 = target.global_position if target != null and is_instance_valid(target) else global_position
	dock = pick_dock(_docks(), dock, tp, near, _rng.randf())
	global_position = _dock_pos(dock)
	if _ripple == null:
		_ripple = MeshInstance3D.new()
		_ripple.name = "Ripple"
		var tm: TorusMesh = TorusMesh.new()
		tm.inner_radius = 0.9
		tm.outer_radius = 1.1
		tm.rings = 24
		_ripple.mesh = tm
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = Color(0.4, 0.3, 0.6, 0.6)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.emission_enabled = true
		m.emission = Color(0.55, 0.35, 0.95)
		m.emission_energy_multiplier = 1.2
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ripple.material_override = m
		_ripple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ripple.top_level = true
		add_child(_ripple)
	_ripple.global_position = global_position + Vector3(0, 0.05, 0)
	_ripple.scale = Vector3.ONE
	_ripple.visible = true
	_set_k(K.RIPPLE)
	AudioDirector.play_3d("water_splash", global_position, 2.0, 0.05)


func _resurface() -> void:
	if _ripple != null:
		_ripple.visible = false
	show()
	collision_layer = LAYER_ZBODY
	_hitboxes_on(true)
	_pivot.position.y = -2.0
	_set_k(K.RISE)
	_go(B.ARRIVE)
	AudioDirector.play_3d("kielholer_surface", global_position, 4.0, 0.0)
	if submerges == 1:
		_line_from("lines_hurt", 1.0)


func _hitboxes_on(on: bool) -> void:
	for hb: Hitbox in _hitboxes:
		hb.collision_layer = Hitbox.LAYER_HITBOX if on else 0


## The glass goes on the hit that takes him past helmet_break_fraction (not a frame later).
func _on_damaged(_amount: float, _limb: StringName, _by_player: int, _kind: StringName) -> void:
	super._on_damaged(_amount, _limb, _by_player, _kind)
	if not helmet_broken and helmet_breaks(max_hp - hp, max_hp, kcfg):
		_break_helmet()


## Under water he can't be hurt; a hit that lands on the frame he sinks does nothing.
func damage_taken_mult() -> float:
	return 0.0 if kstate in [K.SINK, K.UNDER, K.RIPPLE] else 1.0


func _break_helmet() -> void:
	helmet_broken = true
	if _glass != null:
		_glass.visible = false
	if _glow != null:
		_glow.visible = true
	sfx("glass_break", 4.0, 0.8)
	sfx("kielholer_roar", 4.0, 1.0)
	if _lamp_glow != null:
		_lamp_glow.light_color = ZombieBody.MARKE_COLOR


func _tele_glow() -> float:
	return 4.0 if kstate in [K.SWEEP_TELE, K.CHARGE_TELE] else 0.0


# ================================================================== lines

func _line_from(key: String, delay: float) -> void:
	var lines: Array = kcfg.get(key, [])
	for l: Variant in lines:
		if not _lines_said.has(str(l)):
			_lines_said[str(l)] = true
			_say_later(str(l), delay)
			return


func _say_later(line_id: String, delay: float) -> void:
	if not is_inside_tree():
		return
	get_tree().create_timer(delay).timeout.connect(func() -> void: GLVO.play(StringName(line_id)))


## One squad member's reaction (the first whose character is in the match).
func _squad_line(key: String, delay: float) -> void:
	var by_code: Dictionary = {"DUT": &"dutch", "PEG": &"peg", "DEA": &"deacon", "WRN": &"wren"}
	var present: Dictionary = {}
	for pid: int in GameState.player_ids:
		present[GameState.character_of(pid)] = true
	for l: Variant in kcfg.get(key, []):
		var code: String = str(l).get_slice("_", 0)
		if present.has(by_code.get(code, &"")):
			_say_later(str(l), delay)
			return


func _update_audio(delta: float) -> void:
	if not is_active() or kstate in [K.UNDER, K.RIPPLE] or _hum_mute > 0.0:
		return
	_hum_t -= delta
	if _hum_t <= 0.0:
		_hum_t = randf_range(4.0, 6.5)
		sfx("hull_groan", -10.0, randf_range(0.8, 1.0))   # the air valve and the dress creaking under water's weight


# ================================================================== death, fail-safe

func _boss_die(limb: StringName, weapon_id: StringName, by_player: int, kind: StringName) -> void:
	super._boss_die(limb, weapon_id, by_player, kind)
	RoundManager.release_alive(1)
	if _ripple != null:
		_ripple.visible = false
	for d: Variant in kcfg.get("drops", []):
		PowerupManager.spawn(StringName(str(d)), death_pos + Vector3(1.5, 0.3, 0))
	if str(kcfg.get("flag", "")) != "":
		GameState.set_flag(StringName(str(kcfg["flag"])))
	if str(kcfg.get("death_vo", "")) != "":
		_say_later(str(kcfg["death_vo"]), 4.5)
	if str(kcfg.get("line_death", "")) != "":
		GLVO.play(StringName(str(kcfg["line_death"])))
	_squad_line("squad_death", 8.0)
	if str(kcfg.get("intel", "")) != "":
		GLBus.intel_found.emit(StringName(str(kcfg["intel"])))
	if _lamp != null:
		_lamp.light_energy = 0.0
	_drop_key(Vector3(death_pos.x, maxf(0.0, death_pos.y), death_pos.z), false)


func _start_authored_death() -> void:
	_tree_play("Death", "death_knee", 0.7)   # he kneels and is still: no ragdoll, no spectacle


## The fail-safe: he dives for good and the key floats up at the nearest dock edge.
func _on_retreat() -> void:
	RoundManager.release_alive(2)
	sfx("kielholer_surface", 2.0, 0.6)
	var at: Vector3 = KielholerController.edge_point(global_position)
	_drop_key(at, true)
	GameState.set_flag(&"kielholer_dived", true)


func _drop_key(at: Vector3, floating: bool) -> void:
	var c: KielholerController = KielholerController.of(get_tree())
	if c != null:
		c.spawn_key_at(at, floating)
	else:
		BoatKey.spawn_at(_map(), at, floating)
