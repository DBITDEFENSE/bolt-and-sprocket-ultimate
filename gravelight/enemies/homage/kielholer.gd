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
## T-233 (the boss rework, docs/BOSS_REWORK.md 4.1; docs/boss_rework/w3_totenhafen.md), on the T-231 kit:
##   - the model: the brass is wet metal with a verdigris bloom (mat_ex), the helmet glass is a translucent port with
##     the violet Marke glow behind it from the start (full once the glass goes) and an inner shell that fogs as he
##     takes damage toward the break, weed and rope strips hang off the shoulders and the belt (SwayStrips), the anchor
##     chain is a real link chain across the chest and a second one drags behind him from the hip (it trails his
##     motion), a wet sheen on the suit;
##   - the effects: the "dread" block (iron, boss_stomp with a 0.4 view shake: lead soles), drips all over him for
##     drip_seconds after he surfaces, kielholer_chain_drag as a 3D loop that rises with his walk, kielholer_water_rise
##     on surfacing and (low) as the ripple's sound, a wake ring where he comes up, kielholer_helmet_knock on every glass
##     hit before the break, fx.tele on the sweep, the charge and the swipe, the dock lamps dip as he sinks and come
##     back once he is under;
##   - the battle: at high and spring tide the surfacing is quicker as well as closer (submerge_seconds x
##     tide_under_mult, ripple x tide_ripple_mult, never under 1.0 s); the grab's dunk: a player held at the water's
##     edge for dunk_after s is pushed under for dunk_seconds (dunk_damage once, the screen under water) while every
##     break-free keeps running and max_hold is unchanged, so every grab still breaks in solo; the squad rule: he hunts
##     the lone wader (a player at a water edge with no teammate near, in sight) over the nearest player.
## Pure rules are static for the tests.

enum K { RISE, WALK, SWIPE_TELE, SWEEP_TELE, SWEEP, CHARGE_TELE, CHARGE, GRAB, RECOVER, SINK, UNDER, RIPPLE }

const BRASS_WET: Color = Color(0.5, 0.43, 0.22)
const DARK_BRASS: Color = Color(0.3, 0.24, 0.12)
const VERDIGRIS: Color = Color(0.3, 0.52, 0.42)
const IRON: Color = Color(0.2, 0.2, 0.21)
const RUBBER: Color = Color(0.16, 0.15, 0.13)
const WEED: Color = Color(0.1, 0.19, 0.12)
const ROPE: Color = Color(0.36, 0.3, 0.2)
const TELE_COLOR: Color = Color(0.55, 0.9, 0.8)   # the cold green-white of his lamp through water

var kcfg: Dictionary = {}
var kstate: K = K.RISE
var dock: String = "dock2"
var submerges: int = 0
var helmet_broken: bool = false
var sweeps_done: int = 0
var charges_done: int = 0
var grabs_done: int = 0
var swipes_done: int = 0
var dunks: int = 0                # T-233: players pushed under
var helmet_knocks: int = 0        # T-233: kielholer_helmet_knock plays
var lone_targets: int = 0         # T-233: the lone-wader rule picked somebody over the nearest
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
var _edge_t: float = 0.0
var _dunk_t: float = 0.0
var _dunk_done: bool = false
var _lamp: SpotLight3D = null
var _lamp_glow: OmniLight3D = null
var _glass: MeshInstance3D = null
var _fog: MeshInstance3D = null
var _fog_mat: StandardMaterial3D = null
var _glow: Node3D = null
var _glow_light: OmniLight3D = null
var _ripple: MeshInstance3D = null
var _wake: MeshInstance3D = null
var _wake_mat: StandardMaterial3D = null
var _wake_t: float = 0.0
var _drips: Array[GPUParticles3D] = []
var _drip_t: float = 0.0
var _drag: Node3D = null              # the dragging chain's pivot at the hip
var _chain_loop: AudioStreamPlayer3D = null
var _tele_t: float = 0.0
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


## T-233: how long he stays under at a tide ([lo, hi] seconds): submerge_seconds x tide_under_mult on a fast tide.
static func under_range(c: Dictionary, fast: bool) -> Vector2:
	var r: Array = c.get("submerge_seconds", [6.0, 10.0])
	var m: float = float(c.get("tide_under_mult", 0.6)) if fast else 1.0
	return Vector2(float(r[0]) * m, float(r[1]) * m)


## T-233: the ripple's length at a tide: ripple_seconds x tide_ripple_mult on a fast tide, never under 1.0 s (the
## telegraph rule).
static func ripple_for(c: Dictionary, fast: bool) -> float:
	var m: float = float(c.get("tide_ripple_mult", 0.75)) if fast else 1.0
	return maxf(1.0, float(c.get("ripple_seconds", 1.6)) * m)


## T-233: the lone wader among `cands` ([distance to him, distance to a water edge, has a teammate near, in sight]
## each): the nearest one within lone_range, within lone_edge_m of an edge, with nobody near and in sight; -1 = none.
static func lone_wader(cands: Array, sq: Dictionary) -> int:
	var best: int = -1
	var bd: float = INF
	for i: int in cands.size():
		var c: Array = cands[i]
		var d: float = float(c[0])
		if d > float(sq.get("lone_range", 18.0)) or float(c[1]) > float(sq.get("lone_edge_m", 3.0)) or bool(c[2]) or not bool(c[3]):
			continue
		if d < bd:
			bd = d
			best = i
	return best


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

func _init() -> void:
	name = "DerKielholer"   # the capture cameras and the console find him by name (a second one is auto-numbered)


func _ready() -> void:
	super._ready()
	boss_key = "der_kielholer"
	ecfg = table()
	kcfg = boss_cfg()
	bcfg = kcfg
	_rng.seed = hash("kielholer_boss_%d" % Time.get_ticks_usec())
	# the kit was made in super._ready() from the base's cousins table: give it his own "dread" block (T-233)
	if fx != null:
		fx.cfg = BossFx.DEFAULTS.duplicate()
		for k: Variant in (kcfg.get("dread", {}) as Dictionary).keys():
			fx.cfg[k] = (kcfg["dread"] as Dictionary)[k]
		fx.dread_id = &"der_kielholer"


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
	_dunk_t = 0.0
	_tele_t = 0.0
	_pivot.position.y = -2.0
	RoundManager.reserve_alive(1)
	_surface_fx(4.0)
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


## A costume piece's one surface made metal (T-233: wet brass, iron).
static func _metal(mi: MeshInstance3D, c: Color, rough: float = 0.28, metal: float = 0.9) -> void:
	if mi != null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
		mi.mesh.surface_set_material(0, mat_ex(c, rough, metal))


## The diving dress: the brass helmet with its glass port and lamp, the corselet, the anchor chain over the left
## shoulder and the one that drags behind, lead-soled boots (primitives on bone attachments; HOMAGE_BOSSES 3.4).
func _build_costume() -> void:
	# the helmet: wet brass with a verdigris bloom round the rim and the ports
	_metal(costume("Head", [
		sph(0.235, Vector3(0, 0.12, 0.0), BRASS_WET, Vector3(1.0, 1.05, 1.0)),
		cyl(0.1, 0.1, 0.05, Vector3(0, 0.12, -0.22), DARK_BRASS, Vector3(PI * 0.5, 0, 0)),
		cyl(0.055, 0.055, 0.035, Vector3(-0.22, 0.14, -0.04), DARK_BRASS, Vector3(0, 0, PI * 0.5)),
		cyl(0.055, 0.055, 0.035, Vector3(0.22, 0.14, -0.04), DARK_BRASS, Vector3(0, 0, PI * 0.5)),
		cyl(0.035, 0.03, 0.12, Vector3(0.0, 0.2, 0.22), DARK_BRASS, Vector3(PI * 0.5, 0, 0)),   # the air hose's fitting
	]), BRASS_WET)
	costume("Head", [
		boxp(Vector3(0.06, 0.07, 0.08), Vector3(0, 0.33, 0.06), IRON),
		sph(0.07, Vector3(-0.12, -0.04, -0.14), VERDIGRIS, Vector3(1.0, 0.55, 0.5)),
		sph(0.06, Vector3(0.16, 0.0, 0.1), VERDIGRIS, Vector3(0.6, 1.0, 0.6)),
		sph(0.05, Vector3(0.08, 0.3, -0.1), VERDIGRIS, Vector3(1.0, 0.4, 0.8)),
		sph(0.045, Vector3(-0.19, 0.2, 0.08), VERDIGRIS, Vector3(0.5, 0.9, 0.6)),
	])
	# the glass port: translucent, with the Marke's glow behind it from the start; an inner shell fogs as he is hurt
	_glass = costume("Head", [cyl(0.085, 0.085, 0.012, Vector3(0, 0.12, -0.246), Color(0.6, 0.75, 0.8), Vector3(PI * 0.5, 0, 0))])
	if _glass != null and _glass.mesh != null:
		var gmat: StandardMaterial3D = StandardMaterial3D.new()
		gmat.albedo_color = Color(0.62, 0.78, 0.85, 0.42)
		gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gmat.roughness = 0.05
		gmat.metallic = 0.35
		gmat.metallic_specular = 0.9
		_glass.mesh.surface_set_material(0, gmat)
	_fog = costume("Head", [cyl(0.08, 0.08, 0.01, Vector3(0, 0.12, -0.232), Color(0.85, 0.9, 0.92), Vector3(PI * 0.5, 0, 0))])
	if _fog != null and _fog.mesh != null:
		_fog_mat = StandardMaterial3D.new()
		_fog_mat.albedo_color = Color(0.85, 0.9, 0.92, 0.0)
		_fog_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_fog_mat.roughness = 1.0
		_fog.mesh.surface_set_material(0, _fog_mat)
	# the corselet (brass) and the rubber dress, wet
	_metal(costume("Chest", [cyl(0.29, 0.31, 0.09, Vector3(0, 0.3, 0.0), BRASS_WET, Vector3.ZERO, Vector3(1.0, 1.0, 0.85))]), BRASS_WET)
	costume("Chest", [
		boxp(Vector3(0.44, 0.4, 0.3), Vector3(0, 0.12, 0.0), RUBBER),
		sph(0.05, Vector3(0.2, 0.33, -0.1), VERDIGRIS, Vector3(1.0, 0.5, 0.7)),
	])
	wet(0.45)
	# the anchor chain: real links from the left shoulder across the chest to the right hip, the stock behind, and the
	# second chain that drags behind him from the left hip (its pivot trails his motion)
	chain("Chest", Vector3(-0.19, 0.36, -0.16), Vector3(0.17, -0.2, -0.17), 10, 0.04, IRON, 0.7)
	_metal(costume("Chest", [boxp(Vector3(0.36, 0.05, 0.05), Vector3(-0.12, -0.18, 0.2), IRON, Vector3(0, 0, 0.3))]), IRON, 0.5, 0.7)
	var hip: Node3D = bone_attachment("Hips")
	if hip != null:
		_drag = Node3D.new()
		_drag.name = "DragChain"
		_drag.position = Vector3(-0.14, -0.12, 0.18)
		hip.add_child(_drag)
		var dc: MeshInstance3D = chain("Hips", Vector3.ZERO, Vector3(0.0, -1.05, 0.7), 14, 0.045, IRON, 0.7)
		if dc != null:
			dc.reparent(_drag, false)
	# weed and rope: strips off the shoulders, the back of the helmet and the belt
	strips("Chest", Vector3(-0.22, 0.36, 0.02), 4, 0.32, 0.05, WEED, 0.18, 31)
	strips("Chest", Vector3(0.2, 0.36, 0.04), 3, 0.28, 0.05, WEED, 0.16, 32)
	strips("Head", Vector3(0.0, 0.08, 0.2), 3, 0.22, 0.04, WEED, 0.2, 33)
	strips("Hips", Vector3(0.16, 0.0, -0.17), 2, 0.42, 0.03, ROPE, 0.08, 34)
	strips("Hips", Vector3(-0.2, 0.0, -0.1), 2, 0.3, 0.04, WEED, 0.1, 35)
	for foot: String in ["LeftFoot", "RightFoot"]:
		_metal(costume(foot, [boxp(Vector3(0.14, 0.07, 0.3), Vector3(0, -0.04, -0.04), DARK_BRASS), boxp(Vector3(0.15, 0.04, 0.31), Vector3(0, -0.085, -0.04), IRON)]), DARK_BRASS, 0.4, 0.8)
	for hand: String in ["LeftHand", "RightHand"]:
		costume(hand, [boxp(Vector3(0.11, 0.13, 0.07), Vector3(0, -0.05, 0), RUBBER)])
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
	_glow.position = Vector3(0, 0.12, -0.185)   # behind the fog shell until the glass goes
	_glow.scale = Vector3.ONE * 0.8
	_glow.visible = true   # the Marke behind the glass, dim until the glass goes
	for c: Node in _glow.get_children():
		if c is OmniLight3D:
			_glow_light = c as OmniLight3D
			_glow_light.light_energy = 0.35
	(head if head != null else self).add_child(_glow)
	# T-233: the drips (ten seconds after every surfacing), the chain-drag loop
	for spec: Array in [["Head", Vector3(0, 0.0, 0), 1.0], ["Chest", Vector3(0, 0.25, 0), 1.6], ["Hips", Vector3(0, -0.1, 0), 1.3]]:
		var at: Node3D = bone_attachment(str(spec[0]))
		if at != null:
			var e: GPUParticles3D = BossFx.emitter("drips", at, spec[1] as Vector3, float(spec[2]))
			_drips.append(e)
	_chain_loop = AudioDirector.make_loop_3d("kielholer_chain_drag", self, -40.0)


# ================================================================== presentation (every frame)

func _process(delta: float) -> void:
	super._process(delta)
	if state == State.INACTIVE:
		return
	_tick_drag_chain(delta)
	_tick_wake(delta)
	_tick_chain_loop()


## The dragging chain trails his motion: its pivot yaws against his velocity and lifts a little with his speed.
func _tick_drag_chain(delta: float) -> void:
	if _drag == null:
		return
	var lv: Vector3 = global_basis.inverse() * velocity
	lv.y = 0.0
	var spd: float = lv.length()
	var yaw: float = atan2(-lv.x, -lv.z) if spd > 0.3 else 0.0
	var k: float = 1.0 - exp(-4.0 * delta)
	_drag.rotation.y = lerp_angle(_drag.rotation.y, yaw, k)
	_drag.rotation.x = lerpf(_drag.rotation.x, -clampf(spd * 0.09, 0.0, 0.4), k)


func _tick_wake(delta: float) -> void:
	if _wake == null or not _wake.visible:
		return
	_wake_t -= delta
	var k: float = clampf(1.0 - _wake_t / 1.6, 0.0, 1.0)
	_wake.scale = Vector3.ONE * (1.0 + k * 3.0)
	if _wake_mat != null:
		_wake_mat.albedo_color.a = 0.55 * (1.0 - k)
	if _wake_t <= 0.0:
		_wake.visible = false


## kielholer_chain_drag rises with his walk; silent under water and when he stands.
func _tick_chain_loop() -> void:
	if _chain_loop == null:
		return
	var spd: float = Vector2(velocity.x, velocity.z).length()
	var want: bool = is_active() and kstate in [K.WALK, K.CHARGE, K.GRAB] and spd > 0.3
	if want:
		_chain_loop.volume_db = lerpf(-30.0, -6.0, clampf(spd / 2.6, 0.0, 1.0))
		if not _chain_loop.playing:
			_chain_loop.play()
	elif _chain_loop.playing:
		_chain_loop.volume_db = move_toward(_chain_loop.volume_db, -40.0, 1.5)
		if _chain_loop.volume_db <= -39.0:
			_chain_loop.stop()


func _set_drips(on: bool) -> void:
	for e: GPUParticles3D in _drips:
		if is_instance_valid(e):
			e.emitting = on


func dripping() -> bool:
	return not _drips.is_empty() and is_instance_valid(_drips[0]) and _drips[0].emitting


## Surfacing: the water sound, the wake ring where he comes up, the spray, the drips for drip_seconds.
func _surface_fx(db: float) -> void:
	AudioDirector.play_3d("kielholer_water_rise", global_position, db, 0.04)
	_show_wake()
	BossFx.burst("steam", global_position + Vector3.UP * 0.6, get_tree(), 1.2, 1.6)
	BossFx.burst("drips", global_position + Vector3.UP * 1.8, get_tree(), 1.5, 1.4)
	_drip_t = float(kcfg.get("drip_seconds", 10.0))
	_set_drips(true)


func _show_wake() -> void:
	if _wake == null:
		_wake = MeshInstance3D.new()
		_wake.name = "Wake"
		var tm: TorusMesh = TorusMesh.new()
		tm.inner_radius = 0.75
		tm.outer_radius = 1.0
		tm.rings = 24
		_wake.mesh = tm
		_wake_mat = StandardMaterial3D.new()
		_wake_mat.albedo_color = Color(0.7, 0.85, 0.9, 0.55)
		_wake_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_wake_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_wake.material_override = _wake_mat
		_wake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_wake.top_level = true
		add_child(_wake)
	_wake.global_position = global_position + Vector3(0, 0.06, 0)
	_wake.global_rotation = Vector3.ZERO
	_wake.scale = Vector3.ONE
	_wake_mat.albedo_color.a = 0.55
	_wake.visible = true
	_wake_t = 1.6


## Dev / capture: the surfacing's effects now (the wake, the spray, the drips).
func debug_surface_fx() -> void:
	_surface_fx(0.0)


# ================================================================== the brain

func _tide_stage() -> StringName:
	var tide: Node = get_tree().get_first_node_in_group(&"tide")
	return StringName(str(tide.get("stage"))) if tide != null and tide.get("stage") != null else &"low"


func _fast_tide() -> bool:
	return tide_mult(_tide_stage(), kcfg) > 1.0


func _speed() -> float:
	return move_speed() * tide_mult(_tide_stage(), kcfg)


func _tick(delta: float) -> void:
	spawn_t += delta
	_kt += delta
	_tele_t = maxf(0.0, _tele_t - delta)
	if _drip_t > 0.0:
		_drip_t -= delta
		if _drip_t <= 0.0:
			_set_drips(false)
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
			if _kt >= ripple_for(kcfg, _fast_tide()):
				_resurface()


func _set_k(k: K) -> void:
	kstate = k
	_kt = 0.0


## T-233: the kit's telegraph: the light's one shape and the rising sound over `seconds`.
func _kit_tele(seconds: float, energy: float, color: Color = TELE_COLOR) -> void:
	if fx != null:
		fx.tele(color, energy, seconds)
	_tele_t = seconds


## T-233: the squad rule: a lone wader (at a water edge, nobody near, in sight, within lone_range) is his target
## over the nearest player.
func _retarget_lone() -> void:
	var sq: Dictionary = kcfg.get("squad", {})
	if sq.is_empty():
		return
	var players: Array[Player] = alive_players()
	var cands: Array = []
	for p: Player in players:
		var mate: bool = false
		for o: Player in players:
			if o != p and o.global_position.distance_to(p.global_position) <= float(sq.get("lone_mate_m", 6.0)):
				mate = true
				break
		cands.append([dist_to(p), KielholerController.edge_distance(p.global_position), mate, has_los(p)])
	var i: int = lone_wader(cands, sq)
	if i >= 0 and players[i] != target:
		target = players[i]
		lone_targets += 1


func _walk_tick(delta: float) -> void:
	if submerge_due(hp_fraction(), submerges, float(kcfg.get("submerge_every", 0.25))):
		_start_sink()
		return
	if target == null:
		stand(delta)
		return
	_retarget_lone()
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
		_kit_tele(tele_len(float(sp.get("telegraph", 0.5))), 2.5)
	elif cd_ready("sweep") and d >= float(sw.get("min_range", 3.0)) and d <= float(sw.get("range", 9.0)) - 0.5 and has_los(target):
		_set_k(K.SWEEP_TELE)
		_go(B.TELEGRAPH, "sweep")
		pose_anim()
		sfx("chain_sweep", 0.0, 0.9)
		_kit_tele(tele_len(float(sw.get("telegraph", 1.2))), 4.0)
	elif cd_ready("charge") and d >= float(cc.get("min_range", 5.0)) and d <= float(cc.get("max_range", 18.0)) and has_los(target):
		_set_k(K.CHARGE_TELE)
		_go(B.TELEGRAPH, "charge")
		pose_anim()
		sfx("kielholer_roar", -6.0, 1.2)
		_kit_tele(tele_len(float(cc.get("telegraph", 1.0))), 4.0, Color(1.0, 0.85, 0.55))
	else:
		walk_to(target.global_position, delta, _speed())


func _do_sweep() -> void:
	var sw: Dictionary = kcfg.get("chain_sweep", {})
	sweeps_done += 1
	set_cd("sweep", float(sw.get("cooldown", 7.0)))
	sfx("chain_sweep", 2.0, 1.0)
	attack_anim("swipe_double", 0.3)
	BossFx.burst("sparks", global_position + _aim * 1.5 + Vector3.UP * 0.2, get_tree(), 0.8, 0.9)   # the chain on the concrete
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
	_edge_t = 0.0
	_dunk_t = 0.0
	_dunk_done = false
	grabs_done += 1
	_set_k(K.GRAB)
	_go(B.SPECIAL, "grab")
	attack_anim("grab", 0.3)
	sfx("kielholer_surface", 0.0, 0.8)


## Dev / smoke: a grab on `p` now.
func debug_grab(p: Player) -> void:
	target = p
	_cds.erase("grab")
	_start_grab(p)


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
	var at_edge: bool = ed <= float(gr.get("edge_m", 1.6))
	_grab_dmg += (float(gr.get("edge_dps", 28.0)) if at_edge else float(gr.get("dps", 12.0))) * delta
	_grab_dmg_t += delta
	if _grab_dmg_t >= 0.5:
		hit_player(p, _grab_dmg)
		_grab_dmg = 0.0
		_grab_dmg_t = 0.0
	# T-233: the dunk: held at the edge for dunk_after s, he pushes them under for a breath-holding second
	_edge_t = _edge_t + delta if at_edge else 0.0
	if not _dunk_done and _edge_t >= float(gr.get("dunk_after", 1.2)):
		_start_dunk(p)
	if _dunk_t > 0.0:
		_dunk_t -= delta
		if fx != null and p.is_local and not p.is_bot:
			fx.extra_dread = 1.0
		if _dunk_t <= 0.0:
			_pose.set_bone("Spine")
	# he walks with his catch toward the water
	var follow: Vector3 = p.global_position + (global_position - p.global_position).normalized() * 0.9
	global_position = Vector3(follow.x, global_position.y, follow.z)


func _start_dunk(p: Player) -> void:
	var gr: Dictionary = kcfg.get("grab", {})
	_dunk_done = true
	_dunk_t = float(gr.get("dunk_seconds", 1.0))
	dunks += 1
	hit_player(p, float(gr.get("dunk_damage", 20.0)))
	p.apply_status(&"wading", _dunk_t)
	_pose.set_bone("Spine", Vector3(0.9, 0, 0))   # he leans over them
	sfx("water_splash", 2.0, 0.7, p.global_position)
	sfx("kielholer_water_rise", -4.0, 0.8, p.global_position)
	BossFx.burst("drips", p.global_position + Vector3.UP * 1.3, get_tree(), 1.8, 1.4)
	BossFx.burst("steam", p.global_position + Vector3.UP * 0.4, get_tree(), 0.8, 1.0)
	var dfx: DreadFx = DreadFx.of(p)
	if dfx != null:
		dfx.punch(1.0)
	print("[kielholer] under: %s is pushed under for %.1f s" % [String(p.character_id), _dunk_t])


func _on_grab_released(_g: Dictionary, _reason: String) -> void:
	if kstate == K.GRAB:
		_end_grab()


func _end_grab() -> void:
	_grab = {}
	_dunk_t = 0.0
	_pose.set_bone("Spine")
	set_cd("grab", float(kcfg.get("grab", {}).get("cooldown", 10.0)))
	_set_k(K.RECOVER)
	bstate = B.RECOVER


# ================================================================== submerge / resurface

## T-233: the dock lamps dip as he goes down (the kit's lights, back once he is under).
func _start_sink() -> void:
	submerges += 1
	_release_all_grabs("submerge")
	_set_k(K.SINK)
	_go(B.SPECIAL, "submerge")
	sfx("kielholer_surface", 0.0, 0.7)
	_hitboxes_on(false)
	_set_drips(false)
	_drip_t = 0.0
	BossFx.burst("steam", global_position + Vector3.UP * 0.4, get_tree(), 0.8, 1.4)
	if fx != null:
		fx.lights_dim(global_position, 16.0, 0.3, float(kcfg.get("sink_seconds", 1.4)) * 0.6)
	if submerges == 2:
		_line_from("lines_hurt", 0.5)


func _go_under() -> void:
	var r: Vector2 = under_range(kcfg, _fast_tide())
	_under_for = _rng.randf_range(r.x, r.y)
	_set_k(K.UNDER)
	hide()
	collision_layer = 0
	velocity = Vector3.ZERO
	if fx != null:
		fx.lights_restore(2.5)


func _start_ripple() -> void:
	var near: bool = _fast_tide()
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
	# the ripple's own sound: the water rising, low and slow (a kielholer_ripple id is asked of the lead)
	var rp: AudioStreamPlayer3D = AudioDirector.play_3d("kielholer_water_rise", global_position, -9.0, 0.0)
	if rp != null:
		rp.pitch_scale = 0.7


func _resurface() -> void:
	if _ripple != null:
		_ripple.visible = false
	show()
	collision_layer = LAYER_ZBODY
	_hitboxes_on(true)
	_pivot.position.y = -2.0
	_set_k(K.RISE)
	_go(B.ARRIVE)
	_surface_fx(4.0)
	if submerges == 1:
		_line_from("lines_hurt", 1.0)


func _hitboxes_on(on: bool) -> void:
	for hb: Hitbox in _hitboxes:
		hb.collision_layer = Hitbox.LAYER_HITBOX if on else 0


## The glass goes on the hit that takes him past helmet_break_fraction (not a frame later). T-233: a hit on the glass
## before then knocks (kielholer_helmet_knock) and the inner shell fogs a step further toward the break.
func _on_damaged(_amount: float, _limb: StringName, _by_player: int, _kind: StringName) -> void:
	super._on_damaged(_amount, _limb, _by_player, _kind)
	if not helmet_broken:
		if _limb == &"helmet_glass" or _limb == &"head":
			helmet_knocks += 1
			sfx("kielholer_helmet_knock", -2.0, randf_range(0.92, 1.08), _glass.global_position if _glass != null else Vector3.INF)
		if _fog_mat != null:
			_fog_mat.albedo_color.a = 0.8 * clampf((max_hp - hp) / maxf(1.0, max_hp * float(kcfg.get("helmet_break_fraction", 0.15))), 0.0, 1.0)
		if helmet_breaks(max_hp - hp, max_hp, kcfg):
			_break_helmet()


## The fog on the inside of the glass (0..0.8; the smoke reads it).
func fog_alpha() -> float:
	return _fog_mat.albedo_color.a if _fog_mat != null else 0.0


## Under water he can't be hurt; a hit that lands on the frame he sinks does nothing.
func damage_taken_mult() -> float:
	return 0.0 if kstate in [K.SINK, K.UNDER, K.RIPPLE] else 1.0


func _break_helmet() -> void:
	helmet_broken = true
	var at: Vector3 = _glass.global_position if _glass != null else global_position + Vector3.UP * 2.0
	if _glass != null:
		_glass.visible = false
	if _fog != null:
		_fog.visible = false
	if _glow != null:
		_glow.visible = true
		_glow.scale = Vector3.ONE * 1.3
	if _glow_light != null:
		_glow_light.light_energy = 0.9
	BossFx.burst("chips", at, get_tree(), 1.6, 1.0)
	BossFx.burst("motes", at, get_tree(), 1.2, 1.1)
	sfx("glass_break", 4.0, 0.8)
	sfx("kielholer_roar", 4.0, 1.0)
	if _lamp_glow != null:
		_lamp_glow.light_color = ZombieBody.MARKE_COLOR


## T-233: the kit's telegraph light keeps its own shape while a tell runs; the base's steady level otherwise.
func _tele_glow() -> float:
	if _tele_t > 0.0:
		return _tele_light.light_energy
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
		if randf() < 0.5:
			sfx("boss_breath", -14.0, 0.7)   # the man inside, through the valve


# ================================================================== death, fail-safe

func _boss_die(limb: StringName, weapon_id: StringName, by_player: int, kind: StringName) -> void:
	super._boss_die(limb, weapon_id, by_player, kind)
	RoundManager.release_alive(1)
	if _ripple != null:
		_ripple.visible = false
	if _wake != null:
		_wake.visible = false
	_set_drips(false)
	if _chain_loop != null:
		_chain_loop.stop()
	BossFx.burst("drips", death_pos + Vector3.UP * 1.2, get_tree(), 1.2, 1.2)
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
	if _glow_light != null:
		var tw: Tween = create_tween()
		tw.tween_property(_glow_light, "light_energy", 0.0, 6.0)   # the Marke's glow goes out with him, slowly
	_drop_key(Vector3(death_pos.x, maxf(0.0, death_pos.y), death_pos.z), false)


func _start_authored_death() -> void:
	_tree_play("Death", "death_knee", 0.7)   # he kneels and is still: no ragdoll, no spectacle


## The fail-safe: he dives for good and the key floats up at the nearest dock edge.
func _on_retreat() -> void:
	RoundManager.release_alive(2)
	sfx("kielholer_surface", 2.0, 0.6)
	_set_drips(false)
	if _chain_loop != null:
		_chain_loop.stop()
	var at: Vector3 = KielholerController.edge_point(global_position)
	_drop_key(at, true)
	GameState.set_flag(&"kielholer_dived", true)


func _drop_key(at: Vector3, floating: bool) -> void:
	var c: KielholerController = KielholerController.of(get_tree())
	if c != null:
		c.spawn_key_at(at, floating)
	else:
		BoatKey.spawn_at(_map(), at, floating)
