class_name Zombie
extends CharacterBody3D
## Gänger: the standard undead, plus the pooled variants that share its body and state machine:
## Glasshide (crystal-plated, torso armor) and Bellringer (special-round lantern miner, lunge attack).
## Pooled by ZombieDirector, never freed mid-match. Bosses (Foreman, Screamer) subclass this script.
## States: SPAWN -> (window) TO_WINDOW -> WAIT/TEAR -> CLIMB -> CHASE <-> ATTACK, STAGGER, KNOCKDOWN/GETUP,
## CLIMB_LINK (authored climb volumes), DEAD.
## All tuning comes from data/enemies.json; health and tier come from the RoundManager spawn spec.
##
## Animation (MZ, T-041, docs/ZOMBIE_ANIM_SPEC.md): the body is a procedural skinned mesh on the shared ZombieRig
## skeleton, driven by an AnimationTree (ZombieClips) whose parameters this script sets from the state machine:
## locomotion matched to the nav velocity by time scale (root motion = nav speed, no foot-sliding), per-instance
## clip picks, posture trait and start phase, additive flinches with hit springs, foot IK and head look-at within
## range, authored deaths into a ragdoll, dismemberment (ZombieGore), outfit kits and the infection shader
## (ZombieBody). Everything tunable lives in data/gravelight/anim.json.
##
## Co-op (M7): the host simulates every zombie. On a client each zombie is a *puppet* (`puppet = true`): no AI,
## no navigation; it is placed from interpolated snapshots, animates from the replicated state, and plays its
## death from the host's death event (variant, side, head pop). Damage from the client's own weapons is
## predicted locally (hit markers, wounds) and sent to the host with the shot ray (NetMatch.send_hit).

enum State { INACTIVE, EMERGE, TO_WINDOW, WAIT_WINDOW, TEAR, CLIMB, CHASE, ATTACK, STAGGER, DEAD, KNOCKDOWN, GETUP, CLIMB_LINK, LIFTED }

## A hit this zombie took (host / offline; after its multipliers; T-153: the Kielholer's grab and helmet listen).
signal damaged(amount: float, limb: StringName, by_player: int, kind: StringName)

const LAYER_WORLD: int = 1
const LAYER_PLAYER: int = 1 << 1
const LAYER_ZBODY: int = 1 << 2
const LAYER_DOOR: int = 1 << 8
const GRAVITY: float = 18.0   # the 1 g fallback; live: GameState.g_zombie() (world.json x gravity_scale, T-112)

## Shared per-physics-frame repath budget, reset by the director.
static var repath_budget: int = 6
## T-281 (docs/perf/t281_zombie_count_2026-11.md): the horde-size optimisations on (the default). Off, every one of
## them does what it did before, for the before / after from one build (perf_marks --flip=t281, --ab=t281_off; any
## other scene, a smoke: the environment variable CZ_T281_OFF=1).
static var t281_opt: bool = OS.get_environment("CZ_T281_OFF") == ""
## T-283 (phase 2, same notes): the second set, on by default; off (perf_marks --flip=t283, --ab=t283_off, or the
## environment variable CZ_T283_OFF=1) every one does what it did before. Each part has its own switch for the A/B
## of that part alone (perf_marks --flip=t283_skel / t283_rays / t283_lod):
##   t283_skel: the skeleton runs its modifiers (foot IK, springs, look-at) and moves its bone attachments (the
##     hitboxes, the gear) only in the frames the zombie's animation steps (Skeleton3D MANUAL + advance), not in
##     every frame: a body animated every 2nd or 4th frame (far, or out of view) held its pose in the frames between
##     but its skeleton still redid the IK and moved the 14 attachments and 18 hitbox areas to the same place;
##   t283_rays: the foot rays of such a body are cast only in the tick before a frame that steps its animation (the
##     only frames that read them now);
##   t283_lod: the distance LOD the owner asked for: full rate within 12 m of the camera, half to 30 m, a quarter
##     beyond (was 15 / 35; anim.json lod.t283).
static var t283_opt: bool = OS.get_environment("CZ_T283_OFF") == ""
static var t283_skel: bool = true
static var t283_rays: bool = true
static var t283_lod: bool = true
##   t283_death (item 7): a pack killed in one frame (a grenade) does its deaths' cosmetic work over the next frames:
##     the head pop, the blast's loose limb and the death groan go into a queue drained FX_PER_FRAME a frame from the
##     next frame on, and at most RAGDOLLS_PER_TICK ragdolls start in one physics tick (the others play their death
##     clip one more tick). The kill itself (the pay, the kill signals, the round's count, the hitboxes and body
##     leaving play, every random roll that decides an outcome) stays in the frame of the hit, exactly as before.
static var t283_death: bool = true

var enemy_id: StringName = &"ganger"
var state: State = State.INACTIVE
var tier: StringName = &"shamble"
var speed: float = 1.3
var max_hp: float = 150.0
var hp: float = 150.0
var is_crawler: bool = false
var is_last: bool = false
var window: Barricade = null
var target: Player = null
## A scripted target that wins over the nearest player while it stands (Jakub's breakout zombie, U02 section 6.2).
var forced_target: Player = null
## Act III's dust storm (U10 §3, T-157; SoundHunter): while set, this zombie hunts by sound instead of sight: it
## chases only a player it hears within hear_radius_m (×3 when they sprint or fire) and otherwise walks to heard_at.
var hunt_by_sound: bool = false
var hear_radius_m: float = 6.0
var heard_at: Vector3 = Vector3.INF
var director: Node = null
## The hitbox bone of the last shot that landed (weapon_holder / bot_brain set it before take_damage), for the
## side of arm and leg hits. "" = unknown: a side is rolled.
var last_hit_bone: String = ""
## Co-op replication (see the class doc).
var net_id: int = -1
var puppet: bool = false
var net_died: bool = false
var interp: InterpBuffer = null
var _pred_dmg: float = 0.0

var _cfg: Dictionary = {}
var _anim: Dictionary = {}
## T-139: scales anim.json's lod distances (WebProfile halves them on the Compatibility renderer / in the browser).
static var anim_lod_scale: float = 1.0
var _agent: NavigationAgent3D
var _safe_vel: Vector3 = Vector3.ZERO
var _pivot: Node3D
var _parts: Dictionary = {}       # name -> Node3D (the Foreman's own parts)
var _hitboxes: Array[Hitbox] = []
## The Marke (UPDATE 09 section 1, T-137; docs/U09_CONTRACTS.md C1): the site picked from net_id (&"hand" or
## &"forehead"; &"" = none: bosses, the Backorder construct, rig-less bodies), one "marke" hitbox per site (only the
## site's is live; not in _hitboxes, which is the limb layout the tests and the emerge gate walk), the glints, whether
## the last hit landed on it (consumed by _die for the bonus) and whether the marked hand has been shot off.
var marke_site: StringName = &""
var _marke_hit: bool = false
var _marke_lost: bool = false
var _marke_hb: Dictionary = {}       # site -> Hitbox
var _marke_glint: Dictionary = {}    # site -> MeshInstance3D
## UPDATE 11 (T-192): the Soviet risen carry no Marke; their weak point is the wound that killed them. The wound sites
## (ZombieBody.WOUND_SITES) get their own boxes (_wound_hb: the same limb "marke" and multiplier, so every hit path
## and the co-op report work unchanged) and a wound mesh; marke_site then names a wound site (is_wound()).
var _wound_hb: Dictionary = {}       # wound site -> Hitbox
var _wound_nodes: Dictionary = {}    # wound site -> MeshInstance3D
var _collision: CollisionShape3D
var _state_t: float = 0.0
var _repath_t: float = 0.0
var _attack_cd: float = 0.0
var _attack_hit_done: bool = false
var _tear_t: float = 0.0
var _climb_from: Vector3
var _climb_to: Vector3
var _climb_mid: Vector3
var _queue_index: int = 0
var _leg_damage: float = 0.0
var _phase: float = 0.0           # the Foreman's own walk cycle (foreman.gd); the shared body uses the tree
var _groan_t: float = 3.0
var _stuck_t: float = 0.0
var _stuck_origin: Vector3 = Vector3.ZERO
var _anim_skip: int = 0
var _mats: Dictionary = {}
var _flinch: float = 0.0
var _burn_t: float = 0.0
var _burn_dps: float = 0.0
var _burn_by: int = 0
var _burn_tick: float = 0.0
var _flinch_dir: float = 1.0
## Torso damage multiplier (Glasshides, M4). Armor-piercing / armor-ignoring rounds skip it.
var armor_torso_mult: float = 1.0
var _frost_t: float = 0.0
var _frost_slow: float = 0.0
var _vuln_mult: float = 1.0        # Bell Dome (Totenglocke, T-048): damage taken x this until _vuln_until_ms
var _vuln_until_ms: int = 0
var _kind_nodes: Dictionary = {}   # "glass" / "lantern" -> Node3D, shown per kind
var _lantern_light: OmniLight3D
var _lunge_dir: Vector3 = Vector3.ZERO
var _ring_t: float = 0.0
## Shared across zombies: the last time any zombie played a footstep (global rate cap for a 24-zombie horde).
static var _last_step_msec: int = 0
## Map 0's round 1 opening (T-072): an inn patron this zombie goes for before its window or a player (InnOpening
## sets it on the host). The node answers is_catchable() and struck(zombie); it is dropped once they are down.
var prey: Node3D = null
var _prey_attack: bool = false
## A patron risen from where they fell (rise_from_floor): the get-up's length, and the window to make for after it.
var _getup_len: float = -1.0
var _getup_window: bool = false
var _force_female: int = -1   # a spec's "female" (a risen patron keeps their sex); -1 = rolled from the kit
# UPDATE 07 (T-105): outside forces. A push is an added velocity for a while (turbulence, a breach's suction, the
# Lodestone's fling); a lift holds the body in the air (State.LIFTED) until it is dropped or slammed.
var _push_v: Vector3 = Vector3.ZERO
var _push_t: float = 0.0
var _push_by: int = 0
var _push_land_dmg: float = 0.0        # damage dealt when a fling ends (landing), x1.5 into a wall
var _push_weapon: StringName = &""
var _push_wall_hit: bool = false
var _lift_t: float = 0.0
var _lift_total: float = 0.0
var _lift_y0: float = 0.0
var _lift_h: float = 0.0
var _lift_by: int = 0
var _lift_weapon: StringName = &""
var _lift_drop_dmg: float = 0.0
var _lift_slam_dmg: float = 0.0
var _lift_slam_wave: float = 0.0       # the slam's shockwave radius (0 = none)
var _lift_slam_wave_dmg: float = 0.0
## Below this height a flung zombie is "gone" (off a drop, into a shaft); MapRoot sets it from the act json.
static var kill_plane_y: float = -15.0
# UPDATE 07 Map 4 Act IV (T-112): the Suited's visor and the low-g hop.
var visor_cracked: bool = false
var _visor_t: float = -1.0            # > 0: seconds until a cracked visor kills in vacuum
var _visor_by: int = 0
var _visor_weapon: StringName = &""
var hopping: bool = false
var hops_done: int = 0
var _hop_cd: float = 0.0
var _hop_tele: float = -1.0           # > 0: crouched, about to leap
var _hop_v: Vector3 = Vector3.ZERO
## UPDATE 11 (T-192, Hard Truth): a bled-out teammate's body lies here as a zombie that has not got up yet: face
## down, still, no hitboxes, no body collision, ignoring damage, until HardTruth wakes it (wake_from_dormant). The
## host sends it as net_sub_state 1 so a co-op client's puppet lies still too.
var _dormant: bool = false


func _init() -> void:
	collision_layer = LAYER_ZBODY
	collision_mask = LAYER_WORLD | LAYER_PLAYER | LAYER_ZBODY | LAYER_DOOR
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.4
	safe_margin = 0.02


func _ready() -> void:
	_cfg = GLData.table("enemies")["enemies"]["ganger"]
	_anim = GLData.table("anim")
	_collision = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.75
	_collision.shape = cap
	_collision.position = Vector3(0, 0.875, 0)
	add_child(_collision)
	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = 0.45
	_agent.path_max_distance = 3.0
	_agent.radius = 0.4
	_agent.height = 1.8
	_agent.avoidance_enabled = true
	_agent.neighbor_distance = 3.0
	_agent.max_neighbors = 6
	_agent.time_horizon_agents = 0.5
	_agent.avoidance_layers = 1
	_agent.avoidance_mask = 1
	_agent.velocity_computed.connect(_on_velocity_computed)
	_agent.link_reached.connect(_on_link_reached)
	add_child(_agent)
	_build_body()
	deactivate()


# ---------------------------------------------------------------- pool lifecycle

## Ganger tuning with the kind's overrides on top (data/enemies.json).
static func kind_config(kind: StringName) -> Dictionary:
	var all: Dictionary = GLData.table("enemies")["enemies"]
	var c: Dictionary = (all["ganger"] as Dictionary).duplicate(true)
	if kind != &"ganger" and all.has(String(kind)):
		c.merge(all[String(kind)], true)
	return c


func activate(spec: Dictionary, spawn: ZombieSpawn, at_target: Player) -> void:
	_life += 1   # T-283: a death effect queued for this body's last life is dropped
	_contact_lock.reset()
	_foot_ray_from = [Vector3.INF, Vector3.INF]
	_toe_ray_from = [Vector3.INF, Vector3.INF]
	var tiers: Dictionary = GLData.table("enemies")["tiers"]
	var jitter: float = float(GLData.table("enemies")["speed_jitter"])
	net_died = false
	hunt_by_sound = false
	heard_at = Vector3.INF
	enemy_id = StringName(spec.get("enemy_id", "ganger"))
	_cfg = kind_config(enemy_id)
	tier = StringName(spec.get("tier", "shamble"))
	speed = float(tiers.get(String(tier), 1.3)) * randf_range(1.0 - jitter, 1.0 + jitter)
	if _cfg.has("speed"):
		speed = float(_cfg["speed"]) * randf_range(1.0 - jitter, 1.0 + jitter)
	max_hp = float(spec.get("health", 150))
	hp = max_hp
	is_crawler = false
	is_last = false
	_leg_damage = 0.0
	_attack_cd = 0.0
	_stuck_t = 0.0
	_progress_target = null
	_progress_best = INF
	_progress_t = 0.0
	_win_progress_window = null
	_win_progress_best = INF
	_win_progress_t = 0.0
	_burn_t = 0.0
	_frost_t = 0.0
	_frost_slow = 0.0
	visor_cracked = false
	_visor_t = -1.0
	hopping = false
	hops_done = 0
	_hop_cd = randf_range(0.0, 0.6)
	_hop_tele = -1.0
	armor_torso_mult = float(_cfg.get("armor_mult", 1.0))
	target = at_target
	_reset_presentation()
	_set_crawl_pose(false)
	_force_female = (1 if bool(spec["female"]) else 0) if spec.has("female") else -1
	_apply_variant(String(spec.get("variant", "soldier")))
	_force_female = -1
	_apply_kind()
	_apply_marke()
	show()
	process_mode = Node.PROCESS_MODE_INHERIT
	collision_layer = LAYER_ZBODY
	collision_mask = LAYER_WORLD | LAYER_PLAYER | LAYER_ZBODY | LAYER_DOOR
	for hb: Hitbox in _hitboxes:
		hb.collision_layer = Hitbox.LAYER_HITBOX
	_marke_layers(true)
	if bool(spec.get("crawler", false)) and bool(_cfg.get("can_crawl", true)):
		_spawn_as_crawler()
	_pivot.rotation = Vector3.ZERO
	_pivot.position = Vector3.ZERO
	_smooth_off = Vector3.ZERO
	velocity = Vector3.ZERO
	window = spawn.window()
	global_position = spawn.global_position
	_stuck_origin = global_position
	_agent.max_speed = speed
	_agent.avoidance_enabled = true
	_repath_t = randf_range(0.0, 0.2)
	_groan_t = randf_range(0.5, 3.0)
	_spawn_surface = str(spawn.get_meta("surface", ""))
	_emerge_kind = _emerge_kind_for(spawn)
	if spawn.kind == &"ground":
		_enter(State.EMERGE)
	elif window != null:
		_enter(State.TO_WINDOW)
	else:
		_enter(State.CHASE)
	_random_phase()
	if tier == &"sprint":
		AudioDirector.play_3d("zombie_sprint", global_position + Vector3.UP * 1.6, 2.0)
	if enemy_id == &"bellringer":
		_portal_flash()


func deactivate() -> void:
	_contact_lock.reset()
	_turn_motion.reset()
	state = State.INACTIVE
	forced_target = null
	prey = null
	_prey_attack = false
	_getup_len = -1.0
	_getup_window = false
	if window != null:
		window.release(self)
	window = null
	_end_ragdoll()
	_emerge_hitboxes_off = false
	_death_sink = false
	_mound_show(false)
	hide()
	collision_layer = 0
	for hb: Hitbox in _hitboxes:
		hb.collision_layer = 0
	_marke_layers(false)
	velocity = Vector3.ZERO
	global_position = Vector3(0, -200, 0)
	process_mode = Node.PROCESS_MODE_DISABLED


func is_active() -> bool:
	return state != State.INACTIVE and state != State.DEAD


func hitbox_rids() -> Array[RID]:
	var out: Array[RID] = []
	for hb: Hitbox in _hitboxes:
		out.append(hb.get_rid())
	for mhb: Hitbox in _marke_hb.values():
		out.append(mhb.get_rid())
	for whb: Hitbox in _wound_hb.values():
		out.append(whb.get_rid())
	return out


# ---------------------------------------------------------------- the Marke (T-137)

## Picks the Marke's site from net_id (a co-op puppet derives the same one, nothing is sent), shows that site's
## glint and forgets the last hit. Bosses, the Backorder construct and the shield cells (enemies.json "marke":
## false) and rig-less bodies (the Foreman) have none. The hitboxes' layers are the activate / emerge / puppet
## paths' business (_marke_layers), like the limb boxes.
func _apply_marke() -> void:
	_marke_hit = false
	_marke_lost = false
	marke_site = &""
	if has_marke():
		var mk: Dictionary = (GLData.table("enemies") as Dictionary).get("marke", {})
		var id: int = net_id if net_id >= 0 else int(get_instance_id() % 1000003)
		var ws: StringName = ZombieBody.wound_site_for(id, _variant)   # T-192: a Soviet risen: the wound, never a Marke
		if ws != &"" and _wound_hb.has(ws):
			marke_site = ws
		else:
			marke_site = ZombieBody.marke_site_for(id, float(mk.get("hand_chance", 0.6)))
	for site: StringName in _marke_glint.keys():
		(_marke_glint[site] as MeshInstance3D).visible = site == marke_site
	for ws2: StringName in _wound_nodes.keys():
		(_wound_nodes[ws2] as MeshInstance3D).visible = ws2 == marke_site


## T-142: a risen relief-squad soldier of an unmarked faction (CANON 2.2: risen near raw substrate, not by a Marke):
## no site, no glint, no Marke hitbox. Puppets call it too (SoldierKits.dress_risen from the spawn event).
func clear_marke() -> void:
	marke_site = &""
	for site: StringName in _marke_glint.keys():
		(_marke_glint[site] as MeshInstance3D).visible = false
	for ws: StringName in _wound_nodes.keys():
		(_wound_nodes[ws] as MeshInstance3D).visible = false
	_marke_layers(false)


## T-192: the weak point is the wound that killed this body (a Soviet risen), not a Marke: no glint, no Marke signals
## (the HUD's violet tint, the MARKE stat, the Marke VO), the same multiplier and bonus.
func is_wound() -> bool:
	return ZombieBody.is_wound_site(marke_site)


## T-142: a risen soldier's headgear on this body's bones (SoldierKits.add_gear); freed on pool reuse.
var _squad_gear: Array[MeshInstance3D] = []
func dress_squad_gear(look: Dictionary) -> void:
	for sg: MeshInstance3D in _squad_gear:
		if is_instance_valid(sg):
			sg.queue_free()
	_squad_gear = SoldierKits.add_gear(look, func(bone: String) -> Node3D: return bone_attachment(bone), true)


## True when this body carries a Marke (the kind allows it and the body was built with the sites).
func has_marke() -> bool:
	return not _marke_hb.is_empty() and bool(_cfg.get("marke", true))


## The limb a hit on this zombie's Marke continues as (&"arms" for the hand, &"head" for the forehead).
func marke_host_limb() -> StringName:
	return ZombieBody.marke_host_limb(marke_site)


## The Marke hitbox of this zombie (null without one); tools and tests.
func marke_hitbox() -> Hitbox:
	return (_marke_hb.get(marke_site) if _marke_hb.has(marke_site) else _wound_hb.get(marke_site)) as Hitbox


## Turns the site's Marke box on or off with the limb boxes; the other site's box, a lost hand's and a body
## without a Marke stay off.
func _marke_layers(on: bool) -> void:
	for site: StringName in _marke_hb.keys():
		var live: bool = on and site == marke_site and not _marke_lost
		_weak_box_live(_marke_hb[site] as Hitbox, live)
	for ws: StringName in _wound_hb.keys():   # T-192
		_weak_box_live(_wound_hb[ws] as Hitbox, on and ws == marke_site)


## T-281: a weak-point box (the Marke's two sites, the four wound sites) that is not this body's live one has no
## collision layer, so no ray or area can ever find it; it also leaves the physics space (process off: the
## CollisionObject's default disable mode removes it), where it was moved with its bone every animation step for
## nothing. Five of a zombie's eighteen boxes. `t281_opt` false: it stays in the space, as before.
func _weak_box_live(hb: Hitbox, live: bool) -> void:
	hb.collision_layer = Hitbox.LAYER_HITBOX if live else 0
	var mode: Node.ProcessMode = Node.PROCESS_MODE_DISABLED if (t281_opt and not live) else Node.PROCESS_MODE_INHERIT
	if hb.process_mode != mode:
		hb.process_mode = mode


## The marked hand is gone with the arm: no weak point left, the glint goes with the piece.
func _marke_on_sever(bone: String) -> void:
	if marke_site != &"hand" or _marke_lost:
		return
	if bone in ["RightUpperArm", "RightLowerArm", "RightHand"]:
		_marke_lost = true
		_marke_layers(false)
		if _marke_glint.has(&"hand"):
			(_marke_glint[&"hand"] as MeshInstance3D).visible = false


## The Marke bonus a kill from a Marke hit pays `by_player` (enemies.json marke.scrip_bonus; section 3's Ledger
## Lager tier III `marke_tip` adds to it through PerkManager when it exists). Nothing in Classic Rules.
static func marke_bonus_for(by_player: int) -> int:
	if bool(GLSettings.values.get("classic_rules", false)):
		return 0
	var mk: Dictionary = (GLData.table("enemies") as Dictionary).get("marke", {})
	var bonus: int = int(mk.get("scrip_bonus", 25))
	if PerkManager.has_method("stat"):
		bonus += int(PerkManager.stat(by_player, "marke_tip", 0.0))
	return bonus


## A kill from a Marke hit: the signal (always: the stat counts in every mode), then the bonus through
## Economy.award (Double Scrip and the earn multiplier apply) with its slip on the HUD; none in Classic Rules.
func _pay_marke_bonus(by_player: int) -> void:
	var wound: bool = is_wound()   # T-192: a Soviet risen's wound pays the same, under its own name, and is no Marke kill
	if not wound:
		GLBus.marke_kill.emit(by_player, enemy_id)
	var bonus: int = marke_bonus_for(by_player)
	if bonus <= 0:
		return
	Economy.award(by_player, bonus)
	GLBus.bonus_awarded.emit(by_player, &"wound" if wound else &"marke", bonus * Economy.multiplier, "THE WOUND" if wound else "THE MARK")


func _enter(s: State) -> void:
	state = s
	_state_t = 0.0
	if s != State.EMERGE:
		# leaving a rise early (a risen patron's get-up, the opening's attackers, a kill): the hitboxes the rise
		# held back come on and the mound goes, unless the body is sliding back into the ground
		if _emerge_hitboxes_off and s != State.DEAD:
			_set_emerge_hitboxes(true)
		if not (s == State.DEAD and _death_sink):
			_mound_show(false)
	match s:
		State.TEAR:
			_tear_t = _tear_interval() * 0.6
			_tear_clip = _pick(_anim["clips"]["tear"])
			_tree_play("Barricade", _tear_clip, ZombieClips.TEAR_CYCLE / _tear_interval())
		State.ATTACK:
			_attack_hit_done = false
			_attack_clip = _pick_attack()
			AudioDirector.play_3d("zombie_attack", global_position + Vector3.UP * 1.5, float(_anim["vocals"].get("attack_snarl_db", -2.0)))
			_tree_attack(_attack_clip)
		State.EMERGE:
			_tree_emerge()
		State.STAGGER:
			if _react_clip == "":
				_react_clip = str(_anim["clips"]["react"]["stagger"])
				_react_len = float(_cfg["stagger_seconds"])
			_tree_play("React", _react_clip, ZombieClips.length_of(_react_clip) / maxf(0.05, _react_len))
		State.KNOCKDOWN:
			_getup_restarted = false
			var kd: String = str(_anim["clips"]["react"]["knockdown_front" if _down_front else "knockdown_back"])
			_tree_play("React", kd, 1.0)
		State.GETUP:
			var gu: String = str(_anim["clips"]["react"]["getup_front" if _down_front else "getup_back"])
			_tree_play("React", gu, 1.0)
		State.CLIMB:
			_tree_play("Climb", _climb_clip, ZombieClips.length_of(_climb_clip) / maxf(0.1, _climb_dur()))
		State.CLIMB_LINK:
			_tree_play("Climb", str(_anim["clips"]["climb"]["loop"]), 1.0)
		State.LIFTED:
			_tree_play("React", str(_anim["clips"]["react"]["stagger"]), 0.35)   # a slow flail in the air
		State.DEAD:
			if _death_sink:
				_emerge_sink_back()
			else:
				_tree_play("Death", _death_clip, 1.0)
		State.CHASE, State.TO_WINDOW, State.WAIT_WINDOW:
			_tree_locomotion(true)


# ---------------------------------------------------------------- frame update

func _physics_process(delta: float) -> void:
	if smooth_motion:
		_tick_prev = global_position   # T-162: where this tick started (the render-rate smoothing below lerps from it)
	if puppet:
		_puppet_tick(delta)
		return
	_state_t += delta
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_hop_cd = maxf(0.0, _hop_cd - delta)
	if _visor_t > 0.0 and state != State.DEAD and state != State.INACTIVE:
		_visor_t -= delta
		if _visor_t <= 0.0:
			_visor_t = -1.0
			take_damage(hp + 1.0, &"head", _visor_weapon, _visor_by, &"bullet")   # the suit lets go (credited to the cracker)
			return
	if _push_t > 0.0 and state != State.DEAD and state != State.INACTIVE and state != State.LIFTED:
		_update_push(delta)
		return
	match state:
		State.LIFTED:
			_update_lifted(delta)
		State.EMERGE:
			_emerge_tick(delta)
			if _state_t >= _emerge_seconds():
				_enter(State.CHASE)
			else:
				_halt(delta)
		State.TO_WINDOW:
			_update_to_window(delta)
		State.WAIT_WINDOW:
			_update_wait_window(delta)
		State.TEAR:
			_update_tear(delta)
		State.CLIMB:
			_update_climb(delta)
		State.CLIMB_LINK:
			_update_link_climb(delta)
		State.CHASE:
			_update_chase(delta)
		State.ATTACK:
			if _prey_attack:
				_update_prey_attack(delta)
			else:
				_update_attack(delta)
		State.STAGGER:
			_halt(delta)
			if _state_t >= _react_len:
				_react_clip = ""
				_enter(State.CHASE)
		State.KNOCKDOWN:
			_halt(delta)
			if _state_t >= float(_anim["knockdown"]["down_seconds"]):
				_enter(State.GETUP)
		State.GETUP:
			_halt(delta)
			if _dormant:
				pass   # T-192: lying where the teammate bled out until HardTruth wakes it
			elif _state_t >= (_getup_len if _getup_len > 0.0 else float(_anim["knockdown"]["getup_seconds"])):
				_getup_len = -1.0
				var to_window: bool = _getup_window and window != null
				_getup_window = false
				_enter(State.TO_WINDOW if to_window else State.CHASE)
		State.DEAD:
			var pt: int = BotProf.t()
			_update_dead(delta)
			BotProf.add(&"z.dead.tick", pt)
	if state != State.DEAD and global_position.y < -30.0:
		_recycle_for(&"fell")
	_update_burn(delta)
	if _frost_t > 0.0:
		_frost_t -= delta
	if _grab_t > 0.0:
		_update_grab(delta)
	_update_audio(delta)
	_update_senses(delta)


## UPDATE 10 s6 item 1 (T-162): zombies above 60 Hz. The body moves in the physics tick (60 Hz); with `smooth_motion`
## (GLSettings zombie_smooth, default on, never headless) the visual (the Pivot) is offset each rendered frame so the
## mesh shows the position interpolated between the tick's start and its end (Engine.get_physics_interpolation_fraction),
## like the local player's head (T-133). Only within the full-rate animation distance (beyond it a 60 Hz step is not
## visible); a jump over 2 m is a teleport and snaps; collision, hitboxes and every gameplay timer stay on the tick
## (the visual leads the body by at most one tick of travel, under 7 cm at a sprinter's speed).
static var smooth_motion: bool = false
var _tick_prev: Vector3 = Vector3.INF
var _smooth_off: Vector3 = Vector3.ZERO


func _smooth_visual(near: bool) -> void:
	if _pivot == null:
		return
	var off: Vector3 = Vector3.ZERO
	if near and smooth_motion and _tick_prev.is_finite():
		var d: Vector3 = global_position - _tick_prev
		var l2: float = d.length_squared()
		if l2 > 0.000001 and l2 < 4.0:
			off = global_basis.inverse() * (-d * (1.0 - Engine.get_physics_interpolation_fraction()))
	if off != _smooth_off:
		_pivot.position += off - _smooth_off   # (a delta: states that move the Pivot themselves keep their own offset)
		_smooth_off = off


## T-265: the animation's rate follows what the local camera sees. Until now the LOD below went by the distance
## to the zombie's own target, so a horde round a bot 40 m away animated every frame, and so did every zombie
## behind the player's back (each animation step is the tree's advance, the pose code and the skeleton's modifiers:
## about 0.1 ms a zombie, the dearest thing a zombie does after its move). With a camera the distance is the
## camera's, and a body outside the view cone and further than VIEW_NEAR_M is stepped every VIEW_OUT_DIV-th frame
## with the time it skipped, as the far ones always were: the clip keeps its pace, footsteps and events still
## fire (up to 3 frames late), and the first frame it is back in view it is stepped again every frame. The body,
## its hitboxes' place and every gameplay timer are on the physics tick and are not touched. Without a camera
## (headless tests) the distance to the target decides, as before. `view_lod` false: tools that photograph them.
static var view_lod: bool = true
const VIEW_NEAR_M: float = 3.0      # nearer than this a body is never "out of view" (the screen's edge, its shadow)
const VIEW_OUT_DIV: int = 4         # out of view: one animation step every 4th frame
const VIEW_MARGIN_RAD: float = 0.17 # the view cone is the screen's corner angle plus this (10 degrees)
static var _vl_frame: int = -1
static var _vl_vp: Viewport = null
static var _vl_has: bool = false
static var vl_pos: Vector3 = Vector3.ZERO
static var vl_fwd: Vector3 = Vector3.FORWARD
static var vl_cos: float = 0.0
var _out_of_view: bool = false
## Work counters for the measuring tools (perf_marks): animation steps and ticks with foot rays, all zombies.
static var anim_steps: int = 0
static var foot_ray_ticks: int = 0
static var active_frames: int = 0   # frames an active zombie was drawn in (what the two above are a share of)
static var out_frames: int = 0      # of those, out of the camera's view


## Pure: the cosine of the half-angle of the cone that holds everything on screen: a camera with the vertical field
## of view `fov_deg` and the picture's `aspect` (width / height), to the screen's corner, plus `margin_rad`.
static func view_cone_cos(fov_deg: float, aspect: float, margin_rad: float = VIEW_MARGIN_RAD) -> float:
	var tv: float = tan(deg_to_rad(clampf(fov_deg, 1.0, 179.0)) * 0.5)
	var th: float = tv * maxf(0.1, aspect)
	return cos(minf(atan(sqrt(tv * tv + th * th)) + margin_rad, 1.55))


## Pure: is a body at `to` (from the camera) outside the cone round the view axis `fwd` (unit) with the half-angle
## cosine `cone_cos`, and further than `near_m`?
static func out_of_view(to: Vector3, fwd: Vector3, cone_cos: float, near_m: float = VIEW_NEAR_M) -> bool:
	var d2: float = to.length_squared()
	return d2 > near_m * near_m and to.dot(fwd) < cone_cos * sqrt(d2)


## Pure: every how many frames a body `d2` (metres squared) away is animated: 1 within full_m, 2 to half_m, 4
## beyond (anim.json lod), and VIEW_OUT_DIV when it is out of view.
static func anim_div(d2: float, full_m: float, half_m: float, out: bool) -> int:
	if out:
		return VIEW_OUT_DIV
	if d2 > half_m * half_m:
		return 4
	if d2 > full_m * full_m:
		return 2
	return 1


## Pure: is a ball of `radius` at `to` (from the camera) wholly outside the view cone, and not round the camera?
## For things bigger than a body (a column of walkers, a horse).
static func sphere_out_of_view(to: Vector3, radius: float, fwd: Vector3, cone_cos: float, near_m: float = VIEW_NEAR_M) -> bool:
	var d: float = to.length()
	if d <= radius + near_m:
		return false
	return acos(clampf(to.dot(fwd) / d, -1.0, 1.0)) - asin(clampf(radius / d, 0.0, 1.0)) > acos(clampf(cone_cos, -1.0, 1.0))


## The local camera of this body's viewport, read once a frame for the whole horde: true when there is one
## (vl_pos, vl_fwd and vl_cos then hold its place, its axis and its cone).
func _vl_camera() -> bool:
	return view_camera(get_viewport())


## The same for any node's viewport (the landscape's walkers, the horse).
static func view_camera(vp: Viewport) -> bool:
	var f: int = Engine.get_process_frames()
	if f != _vl_frame or vp != _vl_vp:
		_vl_frame = f
		_vl_vp = vp
		var cam: Camera3D = vp.get_camera_3d() if vp != null else null
		_vl_has = cam != null and cam.is_inside_tree()
		if _vl_has:
			vl_pos = cam.global_position
			vl_fwd = -cam.global_basis.z.normalized()
			var size: Vector2 = vp.get_visible_rect().size
			vl_cos = view_cone_cos(cam.fov, size.x / maxf(1.0, size.y))
	return _vl_has


func _process(delta: float) -> void:
	# Animation LOD: full rate within lod.full_m, half to lod.half_m, quarter beyond (anim.json), and a quarter
	# out of the local camera's view (T-265).
	if state == State.INACTIVE:
		return
	if not _fx_q.is_empty() and _fx_frame != Engine.get_process_frames():
		_fx_frame = Engine.get_process_frames()
		var pt: int = BotProf.t()
		drain_death_fx()
		BotProf.add(&"z.fx.drain", pt)
	_anim_skip += 1
	active_frames += 1
	var d2: float = global_position.distance_squared_to(target.global_position) if target != null else 0.0
	_out_of_view = false
	if view_lod and _vl_camera():
		var to: Vector3 = global_position + Vector3.UP - vl_pos
		d2 = to.length_squared()
		_out_of_view = out_of_view(to, vl_fwd, vl_cos)
	var lod: Dictionary = _anim["lod"]
	if t283_opt and t283_lod and lod.has("t283"):
		lod = lod["t283"]
	var half_m: float = float(lod["half_m"]) * anim_lod_scale
	var full_m: float = float(lod["full_m"]) * anim_lod_scale
	if smooth_motion or _smooth_off != Vector3.ZERO:
		_smooth_visual(d2 <= full_m * full_m)
	if _out_of_view:
		out_frames += 1
	var div: int = anim_div(d2, full_m, half_m, _out_of_view)
	_anim_div = div
	lod_frames[0 if div == 1 else (3 if _out_of_view else (1 if div == 2 else 2))] += 1
	_skel_mode_sync()
	if _anim_skip % div != 0:
		return
	if state == State.DEAD:
		var pt: int = BotProf.t()
		_animate(delta * float(div))
		BotProf.add(&"z.dead.anim", pt)
		return
	_animate(delta * float(div))


## T-283: how many frames went at each animation rate (all zombies, a run): full, half, a quarter by distance, a
## quarter out of view. perf_marks prints them.
static var lod_frames: PackedInt64Array = [0, 0, 0, 0]
var _anim_div: int = 1   # the rate of the last frame (the foot rays of the next tick go by it)


## T-283 (`t283_skel`): the skeleton's modifier pass runs when the animation steps (`_animate` calls
## Skeleton3D.advance with the step's time) instead of in every frame. In a frame the animation skips, nothing in
## the skeleton changes, so the IK, the springs, the look-at and the 14 bone attachments (the hitboxes with them)
## stay as they were drawn in the last step: the pose on screen and the pose the hitboxes hold are the same, as
## before. A ragdoll writes the bones itself every tick: the skeleton runs every frame then, as before.
func _skel_mode_sync() -> void:
	if _skel == null:
		return
	var want: Skeleton3D.ModifierCallbackModeProcess = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL if (t283_opt and t283_skel and _ragdoll == null and _tree != null) else Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE
	if _skel.modifier_callback_mode_process != want:
		_skel.modifier_callback_mode_process = want


## T-283 (`t283_rays`): does the coming frame (or one before the next tick) step this body's animation? The foot rays
## are read only by the skeleton's pass in such a frame now; a body at full rate always is.
func _anim_steps_before_next_tick() -> bool:
	if _anim_div <= 1 or not (t283_opt and t283_rays and t283_skel):
		return true
	return anim_steps_within(_anim_skip, _anim_div, maxi(1, ceili(Engine.get_frames_per_second() / float(Engine.physics_ticks_per_second))))


## Pure: with the frame counter at `anim_skip` (the coming frame adds one) and one animation step every `div`-th frame,
## does a step come within the next `horizon` frames (the frames before the next physics tick)?
static func anim_steps_within(anim_skip: int, div: int, horizon: int) -> bool:
	if div <= 1:
		return true
	var r: int = (anim_skip + 1) % div
	var frames_to_step: int = 1 if r == 0 else div - r + 1
	return frames_to_step <= horizon


func _update_to_window(delta: float) -> void:
	if _update_prey(delta):
		return
	if _roam_divert(delta):
		return
	if window == null:
		_enter(State.CHASE)
		return
	var goal: Vector3 = window.outside_point()
	# Someone else is already at this window: queue up nearby instead of crowding it.
	var taken: bool = window.occupant != null and is_instance_valid(window.occupant) and window.occupant != self
	if taken and _flat_dist(goal) < 3.5:
		_queue_index = randi() % 4
		_enter(State.WAIT_WINDOW)
		return
	var mine: bool = window.occupant == self
	if mine:
		# Our turn: slip through the queue (no zombie-zombie collision) and start once close enough.
		collision_mask = LAYER_WORLD | LAYER_PLAYER | LAYER_DOOR
		_agent.avoidance_enabled = false
	var reach: float = 1.2 if mine else 0.7
	if _flat_dist(goal) < reach or (mine and _state_t > 6.0):
		if window.claim(self):
			_enter(State.TEAR)
		else:
			_queue_index = randi() % 4
			_enter(State.WAIT_WINDOW)
		return
	_nav_move(goal, speed, delta, 0.5)
	# No progress on the way to the window: a zombie outside that can't reach its window (blocked path, navmesh
	# island) never enters CHASE, so the chase-state checks never see it and the round can't end. Recycle it.
	var wnp: float = float(_cfg.get("window_no_progress_seconds", 0.0))
	if wnp > 0.0:
		var gd: float = _flat_dist(goal)
		if window != _win_progress_window or gd < _win_progress_best - 1.0:
			_win_progress_window = window
			_win_progress_best = gd
			_win_progress_t = 0.0
		else:
			_win_progress_t += delta
			if _win_progress_t > wnp:
				_win_progress_t = 0.0
				_recycle_for(&"window_no_progress")


var _win_progress_window: Node = null
var _win_progress_best: float = INF
var _win_progress_t: float = 0.0


func _update_wait_window(delta: float) -> void:
	if _roam_divert(delta):
		return
	var spot: Vector3 = window.queue_point(_queue_index)
	if _flat_dist(spot) > 0.4:
		_nav_move(spot, minf(speed, 2.0), delta, 0.6)
	else:
		_halt(delta)
		_face(window.global_position)
	if _state_t > 0.4 and window.claim(self):
		_enter(State.TO_WINDOW)


func _update_tear(delta: float) -> void:
	_halt(delta)
	if _roam_divert(delta):
		return
	var settle: Vector3 = window.outside_point()
	settle.y = global_position.y
	global_position = global_position.move_toward(settle, delta * 1.5)
	_face(window.inside_point())
	# Swipe through a mostly-open window at a player standing right behind it.
	if target != null and window.boards <= 2 and _attack_cd <= 0.0:
		if _window_reach_ok(target, 0.0):
			_attack_cd = float(_cfg["attack_interval"])
			_window_swipe()
	_tear_t -= delta
	if _swipe_t > 0.0:
		_swipe_t -= delta
		if _swipe_t <= 0.0:
			_tree_play("Barricade", _tear_clip, ZombieClips.TEAR_CYCLE / _tear_interval())
	if _tear_t > 0.0:
		return
	if window.boards > 0:
		window.tear_board()
		_tear_t = _tear_interval()
		AudioDirector.play_3d("zombie_groan", global_position + Vector3.UP * 1.5, float(_anim["vocals"].get("rip_db", -4.0)), 0.1)
	else:
		_start_climb()


## The reach-through swipe: the window_swipe clip plays over the tear, the hit lands at the windup if the
## player is still at the boards and the hand reaches them (anim.json attack.window_reach_m / hand_reach_m).
func _window_swipe() -> void:
	AudioDirector.play_3d("zombie_attack", global_position + Vector3.UP * 1.5, -2.0)
	var t: Player = target
	var clip: String = str(_anim["clips"]["attack"]["window"])
	_tree_attack(clip)
	_swipe_t = ZombieClips.length_of(clip) * float(_cfg["attack_windup"]) / ZombieClips.ATTACK_WINDUP
	var tw: Tween = create_tween()
	tw.tween_interval(float(_cfg["attack_windup"]))
	tw.tween_callback(func() -> void:
		if is_active() and window != null and is_instance_valid(t) and _window_reach_ok(t, 0.2) and _hand_reaches(t):
			t.take_hit(float(_cfg["damage"]), self))


## The reach-through hitbox: the swinging hand must get within attack.hand_reach_m of the player's chest.
func _hand_reaches(t: Player) -> bool:
	var hand: Node3D = bone_attachment("RightHand")
	if hand == null:
		return true
	var reach: float = float(_anim["attack"].get("hand_reach_m", 0.75)) + float(_anim["attack"].get("window_reach_m", 0.95))
	return hand.global_position.distance_to(t.global_position + Vector3.UP * 1.2) <= reach


## Melee needs a clear line to the target: no wall or closed door in between. Without it a long-reach
## attacker (a Bellringer reaches 2.4 m, +0.5 m when the hit lands) could hit through a thin wall or a closed
## door (playtest fix, T-026). Window swipes have their own rule (_window_reach_ok).
func _clear_to(t: Player) -> bool:
	if t == null:
		return false
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	# Two rays (chest, head height), each trimmed 0.35 m at both ends so a wall or door frame that both bodies
	# are hugging doesn't count; any clear ray is enough.
	for h: Vector2 in [Vector2(1.2, 1.0), Vector2(1.55, 1.5)]:
		var from: Vector3 = global_position + Vector3.UP * h.x
		var to: Vector3 = t.global_position + Vector3.UP * h.y
		var span: float = from.distance_to(to)
		if span < 0.8:
			return true
		var dir: Vector3 = (to - from) / span
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from + dir * 0.35, to - dir * 0.35, 1 | (1 << 8), [get_rid(), t.get_rid()])
		if space.intersect_ray(q).is_empty():
			return true
	return false


## Through-the-window reach: measured from the window opening (the barricade plane), not from a point 1 m
## inside the room, so only a player standing right at the boards can be swiped (playtest fix, T-026).
func _window_reach_ok(t: Player, grace: float) -> bool:
	var reach: float = float(GLData.table("world")["barricade"]["window_attack_reach"]) + grace
	var w: Vector3 = window.global_position
	var flat: Vector2 = Vector2(t.global_position.x - w.x, t.global_position.z - w.z)
	return flat.length() < reach and absf(t.global_position.y - w.y) < 2.0


func on_board_repaired() -> void:
	if state == State.TEAR:
		_tear_t = _tear_interval()
		_tree_play("Barricade", _tear_clip, ZombieClips.TEAR_CYCLE / _tear_interval())


func _tear_interval() -> float:
	if RoundManager.current_round >= int(_cfg["tear_late_from_round"]):
		return float(_cfg["tear_interval_late"])
	return float(_cfg["tear_interval"])


func _start_climb() -> void:
	_climb_from = global_position
	_climb_mid = window.sill_point()
	_climb_to = window.inside_point()
	collision_mask = 0
	_agent.avoidance_enabled = false
	var high: bool = _climb_mid.y - _climb_to.y > float(_anim["climb"].get("high_window_m", 1.2))
	_climb_clip = str(_anim["clips"]["drop"]) if high else _pick(_anim["clips"]["vault"])
	_enter(State.CLIMB)


func _climb_dur() -> float:
	return float(_cfg["climb_seconds"]) * (1.6 if is_crawler else 1.0)


func _update_climb(_delta: float) -> void:
	var t: float = clampf(_state_t / _climb_dur(), 0.0, 1.0)
	var a: Vector3 = _climb_from.lerp(_climb_mid, t)
	var b: Vector3 = _climb_mid.lerp(_climb_to, t)
	global_position = a.lerp(b, t)
	_face(_climb_to + (_climb_to - _climb_from))
	if t >= 1.0:
		collision_mask = LAYER_WORLD | LAYER_PLAYER | LAYER_ZBODY | LAYER_DOOR
		_agent.avoidance_enabled = true
		if window != null:
			window.release(self)
		window = null
		_stuck_origin = global_position
		_enter(State.CHASE)


# ---------------------------------------------------------------- climb volumes (NavigationLink3D with meta "climb")

## The agent reached a navigation link: a climb link starts the scripted climb (vulnerable, no attacks).
func _on_link_reached(details: Dictionary) -> void:
	if puppet or state != State.CHASE:
		return
	var owner_v: Variant = details.get("owner", null)
	var link: NavigationLink3D = owner_v as NavigationLink3D
	if link == null or not link.has_meta("climb"):
		return
	var start: Vector3 = details.get("link_entry_position", global_position)
	var end: Vector3 = details.get("link_exit_position", global_position)
	if link.has_meta(ClimbLink.LINE):
		_ladder_reached(link, start, end)   # T-268: a ladder (one at a time, up its line, the drop back down)
		return
	if is_crawler:
		return
	if end.y - start.y < 0.5:
		return   # a drop or a flat link: walk it
	_climb_from = start
	_climb_to = end
	_climb_dist = start.distance_to(end)
	collision_mask = 0
	_agent.avoidance_enabled = false
	_enter(State.CLIMB_LINK)


func _update_link_climb(_delta: float) -> void:
	if _ladder != null:
		_update_ladder(_delta)   # T-268
		return
	var spd: float = float(_anim["climb"]["speed_mps"])
	var mantle: float = float(_anim["climb"]["mantle_seconds"])
	var dur: float = _climb_dist / maxf(0.2, spd) + mantle
	var t: float = clampf(_state_t / maxf(0.05, dur), 0.0, 1.0)
	global_position = _climb_from.lerp(_climb_to, t)
	var face_to: Vector3 = _climb_to + (_climb_to - _climb_from)
	face_to.y = global_position.y
	_face(face_to)
	if not _mantling and _state_t >= dur - mantle:
		_mantling = true
		_tree_play("Climb", str(_anim["clips"]["climb"]["mantle"]), 1.0)
	if t >= 1.0:
		_mantling = false
		collision_mask = LAYER_WORLD | LAYER_PLAYER | LAYER_ZBODY | LAYER_DOOR
		_agent.avoidance_enabled = true
		_stuck_origin = global_position
		_enter(State.CHASE)


# ---------------------------------------------------------------- ladders (T-268; climb links with a "line")
# The owner: "zombies need to be able to crawl up the watchtower ... if you go on the ladder, have the zombies be able
# to chase you". A climb link whose map row has a `line` is a ladder (ClimbLink): the dead take it one at a time with
# room between them (the rest wait at the foot), go up the ladder's line and swing over the edge; with `drop` they
# come back down it by dropping. Killed on the rungs, a body falls. Crawlers and the horses do not climb: one whose
# way leads up a ladder is put back in the round's queue after LADDER_REFUSE_S (it comes back on its feet through a
# window or the snow), so nothing waits at a ladder's foot for good and the round can always end. Everything here is
# decided when the agent reaches the link (the path already chose the ladder): no scan runs while it chases.

const LADDER_MOUNT_S: float = 0.35      # from the foot onto the ladder's line
const LADDER_WAIT_LOOK_S: float = 0.25  # a waiting body asks for room this often
const LADDER_WAIT_MAX_S: float = 25.0   # then it looks for another way (a fresh path)
const LADDER_REFUSE_S: float = 8.0      # a body that cannot climb gives up on the ladder after this long
const LADDER_HOP_S: float = 0.45        # the swing out over the edge before a drop
const LADDER_LAND_S: float = 0.25       # from the line's foot back onto the floor after a drop
const LADDER_HUMP: float = 1.15         # the body lifts this far crossing the edge (over a 1.1 m parapet)

var _ladder: NavigationLink3D = null        # the ladder this body is on (state CLIMB_LINK)
var _ladder_line: Vector3 = Vector3.ZERO    # its line (x, z; y unused)
var _ladder_drop: bool = false              # going down it (a drop), not up
var _ladder_fall_s: float = 0.0             # the drop's seconds of free fall
var _ladder_wait: NavigationLink3D = null   # the ladder this body waits at (state CHASE)
var _ladder_wait_from: Vector3 = Vector3.ZERO
var _ladder_wait_to: Vector3 = Vector3.ZERO
var _ladder_wait_t: float = 0.0
var _ladder_wait_look: float = 0.0
var _ladder_fall: bool = false              # dead and falling off a climb


## True for the bodies that take ladders: not a crawler, not a horse (a boss keeps to the ground: HorseBoss lays its
## siege from below, which sets the dead near it running, and they climb).
func can_climb_ladders() -> bool:
	return not is_crawler and not (self is HorseBoss)


## True while this body is on `link`'s rungs going up (ClimbLink's queue asks).
func on_rungs(link: NavigationLink3D) -> bool:
	return state == State.CLIMB_LINK and _ladder == link and not _ladder_drop and not _mantling


## Climbing or dropping on a ladder now.
func on_ladder() -> bool:
	return state == State.CLIMB_LINK and _ladder != null


func _ladder_clear() -> void:
	_ladder = null
	_ladder_drop = false
	_ladder_wait = null
	_ladder_fall = false


## The agent reached a ladder's link, entering at `start`, leaving at `end`.
func _ladder_reached(link: NavigationLink3D, start: Vector3, end: Vector3) -> void:
	var rise: float = end.y - start.y
	if rise < -1.5:
		if bool(link.get_meta(ClimbLink.DROP, false)) and not (self is HorseBoss):
			_ladder_begin(link, start, end, true)   # crawlers drop too: there is no other way down
		return
	if rise < 0.5:
		return
	if _ladder_wait != link:
		_ladder_wait_t = 0.0   # (a body that cannot climb reaches the link again and again: its clock keeps running)
	_ladder_wait = link
	_ladder_wait_from = start
	_ladder_wait_to = end
	_ladder_wait_look = 0.0
	if can_climb_ladders() and ClimbLink.try_enter(link, self, start.y):
		_ladder_wait = null
		_ladder_begin(link, start, end, false)


## One chase tick at a ladder's foot. True while it owns the body (standing, waiting for room on the rungs).
func _ladder_wait_tick(delta: float) -> bool:
	var link: NavigationLink3D = _ladder_wait
	if not is_instance_valid(link) or target.global_position.y < _ladder_wait_from.y + 1.5:
		_ladder_wait = null   # the ladder is gone, or whoever it hunts is no longer up there
		force_repath()
		return false
	_ladder_wait_t += delta
	if not can_climb_ladders():
		if _ladder_wait_t >= LADDER_REFUSE_S:
			_ladder_wait = null
			_recycle_for(&"ladder_refused")
			return true
		return false   # it keeps its chase (and its attack, if the target comes within reach) meanwhile
	if _ladder_wait_t >= LADDER_WAIT_MAX_S or _flat_dist(_ladder_wait_from) > 3.5:
		_ladder_wait = null
		force_repath()
		return false
	if _flat_dist(_ladder_wait_from) > 0.9:
		_nav_move(_ladder_wait_from, speed, delta, 0.5)   # shoved off the foot: back to it
	else:
		_halt(delta)
		_face(_ladder_wait_to)
	_ladder_wait_look -= delta
	if _ladder_wait_look <= 0.0:
		_ladder_wait_look = LADDER_WAIT_LOOK_S
		if ClimbLink.try_enter(link, self, _ladder_wait_from.y):
			_ladder_wait = null
			_ladder_begin(link, _ladder_wait_from, _ladder_wait_to, false)
	return true


func _ladder_begin(link: NavigationLink3D, start: Vector3, end: Vector3, drop: bool) -> void:
	var l2: Vector2 = link.get_meta(ClimbLink.LINE)
	_ladder = link
	_ladder_line = Vector3(l2.x, 0.0, l2.y)
	_ladder_drop = drop
	_ladder_fall_s = sqrt(2.0 * absf(end.y - start.y) / maxf(1.0, GameState.g_zombie()))
	_climb_from = start
	_climb_to = end
	_climb_dist = absf(end.y - start.y)
	_mantling = false
	collision_mask = 0
	_agent.avoidance_enabled = false
	velocity = Vector3.ZERO
	_enter(State.CLIMB_LINK)
	if drop:
		_tree_play("Climb", str(_anim["clips"]["drop"]), 1.0)


## Where the body is `t` seconds into its climb or drop.
func _ladder_pos(t: float) -> Vector3:
	var foot: Vector3 = Vector3(_ladder_line.x, _climb_from.y, _ladder_line.z)
	var head: Vector3 = Vector3(_ladder_line.x, _climb_to.y, _ladder_line.z)
	if _ladder_drop:
		if t < LADDER_HOP_S:
			var k: float = t / LADDER_HOP_S
			return _climb_from.lerp(foot, k) + Vector3.UP * (LADDER_HUMP * sin(k * PI))
		t -= LADDER_HOP_S
		var over: Vector3 = head + Vector3.UP * LADDER_HUMP   # (it comes in over the rail of the floor below, not through it)
		if t < _ladder_fall_s:
			return foot.lerp(over, (t / _ladder_fall_s) * (t / _ladder_fall_s))
		return over.lerp(_climb_to, clampf((t - _ladder_fall_s) / LADDER_LAND_S, 0.0, 1.0))
	if t < LADDER_MOUNT_S:
		return _climb_from.lerp(foot, t / LADDER_MOUNT_S)
	t -= LADDER_MOUNT_S
	var rungs_s: float = _climb_dist / maxf(0.2, float(_anim["climb"]["speed_mps"]))
	if t < rungs_s:
		return foot.lerp(head, t / rungs_s)
	var m: float = clampf((t - rungs_s) / maxf(0.05, float(_anim["climb"]["mantle_seconds"])), 0.0, 1.0)
	return head.lerp(_climb_to, m) + Vector3.UP * (LADDER_HUMP * sin(m * PI))


## Seconds the whole climb (or drop) takes.
func ladder_seconds() -> float:
	if _ladder_drop:
		return LADDER_HOP_S + _ladder_fall_s + LADDER_LAND_S
	return LADDER_MOUNT_S + _climb_dist / maxf(0.2, float(_anim["climb"]["speed_mps"])) + float(_anim["climb"]["mantle_seconds"])


func _update_ladder(_delta: float) -> void:
	if is_crawler and not _ladder_drop:
		_ladder_end(false)   # its legs went on the rungs: it lets go and falls
		return
	var total: float = ladder_seconds()
	global_position = _ladder_pos(minf(_state_t, total))
	var toward: Vector3 = _climb_from if _ladder_drop else _climb_to
	_face(Vector3(toward.x, global_position.y, toward.z) + (toward - _ladder_line) * Vector3(1, 0, 1))
	if not _ladder_drop and not _mantling and _state_t >= total - float(_anim["climb"]["mantle_seconds"]):
		_mantling = true
		_tree_play("Climb", str(_anim["clips"]["climb"]["mantle"]), 1.0)
	if _state_t >= total:
		_ladder_end(true)


## Off the ladder: onto the floor at the far end (arrived), or let go where it is (gravity takes it).
func _ladder_end(arrived: bool) -> void:
	var dropped: bool = _ladder_drop
	_mantling = false
	_ladder = null
	_ladder_drop = false
	collision_mask = LAYER_WORLD | LAYER_PLAYER | LAYER_ZBODY | LAYER_DOOR
	_agent.avoidance_enabled = true
	velocity = Vector3.ZERO
	_stuck_origin = global_position
	force_repath()
	if arrived and dropped:
		_react_clip = ""
		_enter(State.STAGGER)   # it lands hard and reels before it comes on
		AudioDirector.play_3d("zombie_gib", global_position + Vector3.UP * 0.3, -6.0)
	else:
		_enter(State.CHASE)


## Killed on a climb (any climb link): the body is let go and falls. Host and client both come through _start_death.
func _ladder_on_death() -> void:
	_ladder_fall = state == State.CLIMB_LINK
	_ladder_wait = null
	if not _ladder_fall:
		return
	var away: Vector3 = (global_position - _climb_to) * Vector3(1, 0, 1)
	if _ladder != null:
		away = (_ladder_line - (_climb_from if _ladder_drop else _climb_to)) * Vector3(1, 0, 1)
	velocity = away.normalized() * 1.1 if away.length_squared() > 0.0001 else Vector3.ZERO
	collision_mask = LAYER_WORLD
	_ladder = null
	_ladder_drop = false
	_mantling = false


## The dead body's fall off a climb, until the ragdoll takes it or it lies on the floor.
func _ladder_fall_tick(delta: float) -> void:
	if _ragdoll != null:
		_ladder_fall = false   # the ragdoll's own bones fall from here
		return
	velocity.y -= GameState.g_zombie() * delta
	move_and_slide()
	if is_on_floor() or global_position.y < kill_plane_y:
		_ladder_fall = false
		velocity = Vector3.ZERO


## Client: the host's sub-state for a climb (2 = over the edge, 3 = dropping). `entered`: the state is new this sample.
var _puppet_ladder_sub_v: int = 0


func _puppet_ladder_sub(sub: int, entered: bool) -> void:
	if entered:
		_puppet_ladder_sub_v = 0
	if sub == _puppet_ladder_sub_v:
		return
	_puppet_ladder_sub_v = sub
	if entered:
		_ladder_puppet_clip.call_deferred(sub)   # after _enter(CLIMB_LINK) has started the climb loop
	else:
		_ladder_puppet_clip(sub)


func _ladder_puppet_clip(sub: int) -> void:
	if state != State.CLIMB_LINK:
		return
	if sub == 2:
		_tree_play("Climb", str(_anim["clips"]["climb"]["mantle"]), 1.0)
	elif sub == 3:
		_tree_play("Climb", str(_anim["clips"]["drop"]), 1.0)


## Dev / tools: re-tier a live zombie (speed from enemies.json tiers, a fresh locomotion clip for the tier).
func debug_set_tier(t: StringName) -> void:
	tier = t
	speed = float(GLData.table("enemies")["tiers"].get(String(t), speed))
	_agent.max_speed = speed
	_pick_locomotion()


## Dev / tools: start a climb between two points as if a link had been reached.
func debug_climb(from: Vector3, to: Vector3) -> void:
	_climb_from = from
	_climb_to = to
	_climb_dist = from.distance_to(to)
	collision_mask = 0
	_agent.avoidance_enabled = false
	_enter(State.CLIMB_LINK)


func _update_chase(delta: float) -> void:
	# Siren Gramophone: an active lure in range overrides everything else.
	var lure: Node3D = _active_lure()
	if lure != null:
		if _flat_dist(lure.global_position) > 1.2:
			_nav_move(lure.global_position, speed, delta, 0.4)
		else:
			_halt(delta)
			_face(lure.global_position)
		return
	if _update_prey(delta):
		return
	if hunt_by_sound and _update_sound_hunt(delta):
		return
	target = _nearest_player()
	if target == null:
		_halt(delta)
		return
	if _ladder_wait != null and _ladder_wait_tick(delta):
		return   # T-268: at a ladder's foot, waiting for room on the rungs
	if _roam_fallback(delta):
		return
	var to_t: Vector3 = target.global_position - global_position
	var dist: float = to_t.length()
	if _update_hop(delta, dist):
		return
	if dist <= _attack_range() and absf(to_t.y) < 1.3 and _attack_cd <= 0.0 and _clear_to(target):
		_enter(State.ATTACK)
		return
	var rp: Dictionary = GLData.table("enemies")["repath"]
	var interval: float = float(rp["near_s"])
	if dist > float(rp["far_m"]):
		interval = float(rp["far_s"])
	elif dist > float(rp["near_m"]):
		interval = float(rp["mid_s"])
	var spd: float = float(_cfg["crawler_speed"]) if is_crawler else speed
	if is_last and not is_crawler:
		spd = maxf(spd, float(GLData.table("enemies")["tiers"]["jog"]))
	_nav_move(target.global_position, spd, delta, interval)
	# Wedged well above the walkable floor (pushed out of an overlap into a ceiling, etc.): recycle it now.
	if _wedged(delta):
		_recycle_for(&"wedged")
		return
	# Stuck check: barely moved for a long time while far from the player -> recycle into the queue.
	_stuck_t += delta
	if _stuck_t > float(_cfg["stuck_respawn_seconds"]):
		# ...or stuck anywhere it isn't within reach of its target: snagged on a stair corner, a stall, or with a
		# closed door / wall in between (T-026). A recycled zombie re-enters through a window.
		if global_position.distance_to(_stuck_origin) < 1.0 and (dist > float(_cfg["attack_range"]) + 1.0 or not _clear_to(target)) and not is_crawler:
			_recycle_for(&"stuck")
			return
		_stuck_t = 0.0
		_stuck_origin = global_position
	# No progress (T-057): a zombie that hasn't got 1 m closer to its target in no_progress_respawn_seconds while
	# still well out of reach is on ground it can't leave (a navmesh island, the far side of something) or going
	# round in circles; the stuck check above misses those when it keeps moving. Recycled, it re-enters through a
	# window. (Map 1 soak: a scripted player alone looped for 140 minutes and the round never ended.)
	var np: float = float(_cfg.get("no_progress_respawn_seconds", 0.0))
	if np > 0.0 and not is_crawler:
		if target != _progress_target or dist < _progress_best - 1.0:
			_progress_target = target
			_progress_best = dist
			_progress_t = 0.0
		else:
			_progress_t += delta
			if _progress_t > np and dist > float(_cfg.get("no_progress_min_m", 8.0)):
				_progress_t = 0.0
				_recycle_for(&"no_progress")


var _progress_target: Player = null
var _progress_best: float = INF
var _progress_t: float = 0.0


## The storm's hunt (SoundHunter): true when this frame was spent walking to the last heard spot or waiting there
## (nobody heard); false hands the frame to the normal chase (someone is heard: they are the nearest target).
func _update_sound_hunt(delta: float) -> bool:
	if forced_target != null:
		return false
	var heard: Node3D = SoundHunter.heard_player(self, hear_radius_m, get_tree().get_nodes_in_group(&"players"))
	if heard != null:
		heard_at = heard.global_position
		return false
	if heard_at == Vector3.INF or _flat_dist(heard_at) < 1.5:
		heard_at = Vector3.INF
		_halt(delta)
		return true
	_nav_move(heard_at, speed, delta, 0.6)
	return true


# ---------------------------------------------------------------- the low-g hop (T-112)

## enemies.json "leap_hop": the rules every pressurized Gänger hops by below max_gravity_scale.
static func hop_cfg() -> Dictionary:
	return GLData.table("enemies").get("leap_hop", {})


## True when a hop is due: low gravity, a kind that hops, on the floor, the target in range with a clear line,
## not in vacuum, the cooldown spent.
static func hop_due(gravity_scale: float, kind_hops: bool, on_floor: bool, dist: float, clear: bool, in_vacuum: bool, crawler: bool, cd: float, hc: Dictionary) -> bool:
	if hc.is_empty() or gravity_scale > float(hc.get("max_gravity_scale", 0.7)) or not kind_hops or not on_floor or crawler or in_vacuum or cd > 0.0 or not clear:
		return false
	return dist >= float(hc.get("range_min", 5.0)) and dist <= float(hc.get("range_max", 8.0))


## The take-off velocity for a ballistic arc of `apex` m landing `to` (flat) away at gravity `g`.
static func hop_velocity(to: Vector3, apex: float, g: float) -> Vector3:
	var vy: float = sqrt(2.0 * maxf(0.1, g) * maxf(0.2, apex))
	var t: float = 2.0 * vy / maxf(0.1, g)
	var flat: Vector3 = Vector3(to.x, 0.0, to.z)
	var d: float = flat.length()
	var hv: Vector3 = flat.normalized() * (d / maxf(0.05, t)) if d > 0.01 else Vector3.ZERO
	return Vector3(hv.x, vy, hv.z)


## The hop's tick inside the chase: the crouch, the leap, the landing. True while it owns the body.
func _update_hop(delta: float, dist: float) -> bool:
	if hopping:
		velocity.y -= GameState.g_zombie() * delta
		move_and_slide()
		if is_on_floor() and velocity.y <= 0.0 and _state_t > 0.15:
			hopping = false
			hops_done += 1
			_hop_cd = float(hop_cfg().get("cooldown_seconds", 6.0))
			velocity = Vector3.ZERO
			AudioDirector.play_3d("zombie_attack", global_position + Vector3.UP, -6.0, 0.2)
			_react_clip = ""
			_enter(State.STAGGER)
			_react_len = float(hop_cfg().get("land_stagger_seconds", 0.35))
		elif global_position.y < kill_plane_y:
			hopping = false
			_recycle_for(&"hop_fell")
		return true
	if _hop_tele > 0.0:
		_hop_tele -= delta
		_halt(delta)
		if target != null:
			_face(target.global_position)
		if _hop_tele <= 0.0:
			_hop_tele = -1.0
			if target == null or not is_on_floor():
				return false
			hopping = true
			_state_t = 0.0
			_agent.avoidance_enabled = false
			velocity = hop_velocity(target.global_position - global_position, float(hop_cfg().get("apex_height", 2.2)), GameState.g_zombie())
			_agent.avoidance_enabled = true
			_tree_play("React", str(_anim["clips"]["react"]["stagger"]), 0.5)
		return true
	var hc: Dictionary = hop_cfg()
	var kind_hops: bool = bool(_cfg.get("leap_hop", true))
	# (the cheap gates first: at 1 g, out of range or on cooldown no hop is due whatever the line of sight says, so
	# the two rays of _clear_to and the zone lookup are not made for it; they were, every tick, for every chaser)
	if target != null and hop_due(GameState.gravity_scale, kind_hops, is_on_floor(), dist, true, false, is_crawler, _hop_cd, hc) 			and hop_due(GameState.gravity_scale, kind_hops, is_on_floor(), dist, _clear_to(target), ZoneVolume.vacuum_at(get_tree(), global_position), is_crawler, _hop_cd, hc):
		_hop_tele = float(hc.get("telegraph_seconds", 0.5))
		_halt(delta)
		return true
	return false


# ---------------------------------------------------------------- the Suited's visor (T-112)

## A head hit on a Suited: the visor cracks (once); in vacuum the suit lets go `visor_death_seconds` later.
func _crack_visor(by_player: int, weapon_id: StringName) -> void:
	if visor_cracked:
		return
	visor_cracked = true
	_visor_by = by_player
	_visor_weapon = weapon_id
	AudioDirector.play_3d("impact_flesh", global_position + Vector3.UP * 1.6, 3.0, 0.5)
	Effects.dust_puff(global_position + Vector3.UP * 1.65, "snow", 12)
	var crack: Node3D = _kind_nodes.get("visor_crack") as Node3D
	if crack != null:
		crack.visible = true
	if ZoneVolume.vacuum_at(get_tree(), global_position):
		_visor_t = float(_cfg.get("visor_death_seconds", 2.0))


# ---------------------------------------------------------------- open ground (T-080, Map 0's GROUNDS)

var _roam_t: float = 0.0


## enemies.json "roam": how far a zombie on open ground notices a player on it, how often it looks again.
static func roam_cfg() -> Dictionary:
	return GLData.table("enemies").get("roam", {})


## On the way to (or at) its window, out on open ground: a player standing on the open ground within roam.aggro_m
## whom it can walk to (no shut door or window on the way) is a better target than the boards. It lets go of the
## window and chases. Returns true when it did.
func _roam_divert(delta: float) -> bool:
	_roam_t -= delta
	if _roam_t > 0.0 or forced_target != null:
		return false
	var rc: Dictionary = roam_cfg()
	_roam_t = float(rc.get("recheck_s", 0.8)) * randf_range(0.8, 1.2)
	if rc.is_empty() or not ZoneVolume.roam_at(get_tree(), global_position):
		return false
	var aggro: float = float(rc.get("aggro_m", 20.0))
	var best: Player = null
	var best_d: float = INF
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not p.is_alive() or absf(p.global_position.y - global_position.y) > 2.5:
			continue
		var d: float = _flat_dist(p.global_position)
		if d < aggro and d < best_d and ZoneVolume.roam_at(get_tree(), p.global_position):
			best = p
			best_d = d
	if best == null or not can_walk_to(best.global_position):
		return false
	if window != null:
		window.release(self)
	window = null
	target = best
	collision_mask = LAYER_WORLD | LAYER_PLAYER | LAYER_ZBODY | LAYER_DOOR
	_agent.avoidance_enabled = true
	_stuck_origin = global_position
	_enter(State.CHASE)
	return true


## Chasing on open ground after someone it can't walk to (they went back inside behind a shut door, or into the
## yard with the gate shut): it makes for the nearest window it can reach instead, in a zone that is open, the
## one that brings it closest to its target. Returns true when it did.
func _roam_fallback(delta: float) -> bool:
	_roam_t -= delta
	if _roam_t > 0.0 or forced_target != null or is_crawler:
		return false
	var rc: Dictionary = roam_cfg()
	_roam_t = float(rc.get("recheck_s", 0.8)) * randf_range(0.8, 1.2)
	if rc.is_empty() or not ZoneVolume.roam_at(get_tree(), global_position):
		return false
	if can_walk_to(target.global_position):
		return false
	var ranked: Array = []   # [score, Barricade], nearest (with the target in mind) first
	for n: Node in get_tree().get_nodes_in_group(&"barricades"):
		var b: Barricade = n as Barricade
		if b == null or not GameState.is_zone_open(b.zone_id):
			continue
		var op: Vector3 = b.outside_point()
		ranked.append([_flat_dist(op) + 0.5 * op.distance_to(target.global_position), b])
	ranked.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	for i: int in mini(ranked.size(), int(rc.get("window_tries", 4))):
		var cand: Barricade = ranked[i][1]
		if can_walk_to(cand.outside_point()):
			go_to_window(cand)
			return true
	return false


## True when the navmesh takes this zombie to within roam.reach_m of `goal` without crossing a shut BuyDoor or a
## window (doors aren't baked into the navmesh; windows are only crossed by tearing the boards and climbing).
func can_walk_to(goal: Vector3) -> bool:
	# the open zones' layers (T-107): the default mask is layer 1 only, which on a per-zone-region map is one zone
	var mask: int = (director as ZombieDirector).nav_mask if director != null else 0x7FFFFFFF
	var path: PackedVector3Array = NavigationServer3D.map_get_path(get_world_3d().navigation_map, global_position, goal, true, mask)
	if path.is_empty():
		return false
	var end: Vector3 = path[path.size() - 1]
	if Vector2(end.x - goal.x, end.z - goal.z).length() > float(roam_cfg().get("reach_m", 1.5)) or absf(end.y - goal.y) > 1.5:
		return false
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		var d: BuyDoor = n as BuyDoor
		if d != null and not d.is_open and ZombieDirector.door_crossed(d, path):
			return false
	for n2: Node in get_tree().get_nodes_in_group(&"barricades"):
		var b: Barricade = n2 as Barricade
		if b != null and ZombieDirector.window_crossed(b, path):
			return false
	return true


func _attack_range() -> float:
	return float(_cfg["attack_range"])


# ---------------------------------------------------------------- Map 0's round 1 opening (T-072)

## Goes for `prey` (a fleeing inn patron) while they can still be caught: closes in and swipes at them. Returns true
## while it is busy with them (the window or the player waits).
func _update_prey(delta: float) -> bool:
	if prey == null:
		return false
	if not is_instance_valid(prey) or not bool(prey.call("is_catchable")):
		prey = null
		return false
	var reach: float = float(_cfg["attack_range"]) + 0.2
	if _flat_dist(prey.global_position) > reach:
		_nav_move(prey.global_position, speed, delta, 0.3)
		return true
	_halt(delta)
	_face(prey.global_position)
	if _attack_cd <= 0.0:
		_prey_attack = true
		_enter(State.ATTACK)
	return true


## The swipe at a patron: the attack clip, the hit at the windup (they react; their fate is the opening's script).
func _update_prey_attack(delta: float) -> void:
	_halt(delta)
	var windup: float = float(_cfg["attack_windup"])
	if prey != null and is_instance_valid(prey):
		_face(prey.global_position)
		if not _attack_hit_done and _state_t >= windup:
			_attack_hit_done = true
			prey.call("struck", self)
			AudioDirector.play_3d("impact_flesh", prey.global_position + Vector3.UP * 1.2, 0.0)
	if _state_t >= windup + 0.35:
		_prey_attack = false
		_attack_cd = maxf(0.0, float(_cfg["attack_interval"]) - windup - 0.35)
		_enter(State.TO_WINDOW if window != null else State.CHASE)


## Rises from the floor where a patron fell (InnOpening, after activate): the get-up from lying on the back over
## `seconds`, then off to `after_window` if one is given (outside the inn), else the chase.
## UPDATE 11 (T-192, Hard Truth): the body lies face down and still where a teammate bled out: the first frame of
## the face-down get-up held, no hitboxes, no body collision, no damage, no attacks, until wake_from_dormant. Host
## and puppet alike (a puppet follows net_sub_state).
func lie_dormant() -> void:
	_dormant = true
	_down_front = true
	_getup_window = false
	_getup_len = 1e6
	_enter(State.GETUP)
	_tree.set("parameters/SM/React/TimeScale/scale", 0.0)
	_set_emerge_hitboxes(false)
	collision_layer = 0
	velocity = Vector3.ZERO


## The body gets up over `getup_s` (the normal get-up from the floor), its hitboxes and collision back.
func wake_from_dormant(getup_s: float) -> void:
	if not _dormant:
		return
	_dormant = false
	collision_layer = LAYER_ZBODY
	rise_from_floor(getup_s)


func is_dormant() -> bool:
	return _dormant


func rise_from_floor(seconds: float, after_window: Barricade = null) -> void:
	_down_front = false
	if after_window != null:
		window = after_window
	_getup_window = after_window != null
	_getup_len = maxf(0.3, seconds)
	_enter(State.GETUP)
	_tree.set("parameters/SM/React/TimeScale/scale", float(_anim["knockdown"]["getup_seconds"]) / _getup_len)


## Sends a zombie outside the inn on to a window (an opening attacker done with its patron).
func go_to_window(b: Barricade) -> void:
	if b == null or not is_active():
		return
	window = b
	if state == State.CHASE:
		_enter(State.TO_WINDOW)


func _update_attack(delta: float) -> void:
	var windup: float = float(_cfg["attack_windup"])
	var lunging: bool = enemy_id == &"bellringer" or _attack_clip == str(_anim["clips"]["attack"]["lunge"])
	if lunging and _state_t >= windup * 0.5 and _state_t < windup + 0.15 and target != null:
		# Lunge: a short leap at the target during the windup.
		var to_t: Vector3 = target.global_position - global_position
		to_t.y = 0.0
		var leap: float = float(_cfg.get("lunge_distance", 2.0 if enemy_id == &"bellringer" else 1.2)) / maxf(0.05, windup * 0.5 + 0.15)
		if to_t.length() > 0.9:
			velocity.x = to_t.normalized().x * leap
			velocity.z = to_t.normalized().z * leap
			_apply_gravity(delta)
			move_and_slide()
	else:
		_halt(delta)
	if target != null:
		_face(target.global_position)
	if not _attack_hit_done and _state_t >= windup:
		_attack_hit_done = true
		if target != null and target.is_alive():
			var d: float = global_position.distance_to(target.global_position)
			if d <= _attack_range() + 0.5 and _clear_to(target):
				target.take_hit(float(_cfg["damage"]), self)
				if _cfg.has("hit_slow"):
					target.apply_status(&"shard_slow", float(_cfg.get("hit_slow_seconds", 0.5)))
				if enemy_id == &"bellringer":
					AudioDirector.play_3d("bellringer_lantern", global_position + Vector3.UP * 1.4, 2.0)
				if _attack_clip == str(_anim["clips"]["attack"]["grab"]):
					_start_grab(target)
	if _state_t >= windup + 0.35:
		_attack_cd = maxf(0.0, float(_cfg["attack_interval"]) - windup - 0.35)
		_enter(State.CHASE)


## The sprinter grab: the hit pulls the player's view for attack.grab.seconds (cancelled by a melee hit on
## this zombie). Presentation only: the damage is the normal hit.
func _start_grab(t: Player) -> void:
	var g: Dictionary = _anim["attack"]["grab"]
	_grab_target = t
	_grab_t = float(g.get("seconds", 0.4))
	t.kick_camera(float(g.get("pitch_deg", 9.0)), float(g.get("yaw_deg", 22.0)), 0.45, float(g.get("recover", 7.0)), 0.35, 0.0)


func _update_grab(delta: float) -> void:
	_grab_t -= delta
	if _grab_target == null or not is_instance_valid(_grab_target) or not is_active():
		_grab_t = 0.0
		return
	# A steady pull while held: pitch only (kick_camera rolls a fresh yaw sign per call, which per frame is
	# jitter; the opening kick in _start_grab already yanked the yaw) and keep 0, so it all goes into the
	# recoil spring and the view settles back once the grab ends instead of drifting for good.
	var g: Dictionary = _anim["attack"]["grab"]
	_grab_target.kick_camera(float(g.get("pitch_deg", 9.0)) * 2.5 * delta, 0.0, 0.0, float(g.get("recover", 7.0)), 0.0, 0.0)


func _update_dead(delta: float) -> void:
	if _ladder_fall:
		_ladder_fall_tick(delta)   # T-268
	if _death_sink:
		# killed mid-rise: the Emerge clip ran backward and the body is back in the hole; no ragdoll, nothing to dissolve
		if _state_t > _sink_corpse_s:
			deactivate()
			if director != null:
				director.call("on_zombie_returned", self)
		return
	var rd: Dictionary = _anim["ragdoll"]
	if not _ragdoll_started and _state_t >= ZombieClips.death_key_pose_time(_death_clip) and _ragdoll_slot():
		_ragdoll_started = true
		_begin_ragdoll()
	if _ragdoll != null:
		ZombieRagdoll.tick()
		ZombieRagdoll.sync(_ragdoll, _skel)
	var corpse: float = _corpse_seconds
	if director != null and director.has_method("free_count") and int(director.call("free_count")) < int(rd.get("pool_pressure_free", 4)):
		corpse = minf(corpse, float(rd.get("pool_pressure_corpse_seconds", 1.6)))
	var dissolve: float = float(rd.get("dissolve_seconds", 1.4))
	if _state_t > corpse:
		_set_inst("inst_dissolve", clampf((_state_t - corpse) / dissolve, 0.0, 1.0))
	if _state_t > corpse + dissolve:
		deactivate()
		if director != null:
			director.call("on_zombie_returned", self)


# ---------------------------------------------------------------- movement helpers

## True while the agent's current path point is a NavigationLink (a door seam between two zone regions): a
## re-path from inside the seam's eroded gap would start back on the region it came from and the zombie would
## shuttle on the spot (playtest T-040), so links are crossed before the path is recomputed.
func _crossing_link() -> bool:
	var res: NavigationPathQueryResult3D = _agent.get_current_navigation_result()
	if res == null:
		return false
	var types: PackedInt32Array = res.get_path_types()
	var i: int = _agent.get_current_navigation_path_index()
	return i > 0 and i < types.size() and types[i] == NavigationPathQueryResult3D.PATH_SEGMENT_TYPE_LINK


var _link_t: float = 0.0          # seconds spent on the current link point (the re-path hold has a limit)


## Where this zombie's current nav path ends (the agent's last computed path), or INF with no path yet.
func path_end() -> Vector3:
	if _agent == null or not _agent.is_inside_tree():
		return Vector3.INF
	var path: PackedVector3Array = _agent.get_current_navigation_path()
	if path.is_empty():
		return Vector3.INF
	return path[path.size() - 1]


## Recompute the path on the next move tick (after a relocation).
func force_repath() -> void:
	_repath_t = 0.0
	_link_t = 0.0


func _nav_move(goal: Vector3, spd: float, delta: float, repath_interval: float) -> void:
	_repath_t -= delta
	var on_link: bool = _crossing_link()
	_link_t = _link_t + delta if on_link else 0.0
	if _repath_t <= 0.0 and Zombie.repath_budget > 0 and not (on_link and _link_t < 3.0):
		Zombie.repath_budget -= 1
		if director != null:
			_agent.navigation_layers = (director as ZombieDirector).nav_mask
		_agent.target_position = goal
		_repath_t = repath_interval
	var next: Vector3 = _agent.get_next_path_position()
	if _corner_t > 0.0:
		_corner_t -= delta
		if Vector2(_corner_pt.x - global_position.x, _corner_pt.z - global_position.z).length() < 0.12:
			_corner_t = 0.0   # back on the corner: the path's own next point is clear from here
		else:
			next = _corner_pt
	var dir: Vector3 = next - global_position
	if _agent.is_navigation_finished() or (dir.length_squared() < 0.0004 and _corner_t <= 0.0):
		dir = goal - global_position
	dir.y = 0.0
	spd *= frost_speed_mult()
	var desired: Vector3 = dir.normalized() * spd if dir.length_squared() > 0.0001 else Vector3.ZERO
	if _sidestep_t > 0.0:
		_sidestep_t -= delta
		desired = _sidestep_dir * spd
	_agent.max_speed = spd
	if _agent.avoidance_enabled:
		_agent.velocity = desired
	else:
		_safe_vel = desired
	velocity.x = _safe_vel.x
	velocity.z = _safe_vel.z
	_apply_gravity(delta)
	var before: Vector3 = global_position
	move_and_slide()
	# Corner snag: it wants to move but the wall/corner eats all of it -> sidestep at ~75 degrees for a moment,
	# alternating sides, then resume the path (playtest fix, T-028).
	var moved: float = Vector2(global_position.x - before.x, global_position.z - before.z).length()
	if desired.length() > 0.3 and moved < desired.length() * delta * 0.2 and is_on_floor() and _step_up(desired):
		moved = desired.length() * delta
	if desired.length() > 0.3 and moved < desired.length() * delta * 0.2 and _sidestep_t <= 0.0:
		_blocked_t += delta
		if _blocked_t > 0.5:
			_blocked_t = 0.0
			_start_sidestep(desired)
	else:
		_blocked_t = 0.0
	# Progress over a 0.4 s window (T-057): a body jittering against a rail end moves just enough on some frames
	# to reset the per-frame check above, so it never sidestepped. Snagged -> back onto the corner it cut if
	# there is one, else the sidestep.
	if _sidestep_t <= 0.0 and _corner_t <= 0.0:
		_prog_want += desired.length() * delta
	_prog_t += delta
	if _prog_t >= 0.4:
		var got: float = Vector2(global_position.x - _prog_from.x, global_position.z - _prog_from.z).length()
		if _prog_want > 0.6 and got < _prog_want * 0.25:
			var corner: Vector3 = _skipped_corner()
			if corner != Vector3.INF:
				_corner_pt = corner
				_corner_t = 0.8
			elif _sidestep_t <= 0.0:
				_start_sidestep(desired)
		_prog_t = 0.0
		_prog_want = 0.0
		_prog_from = global_position
	var flat: Vector3 = Vector3(velocity.x, 0, velocity.z)
	if flat.length_squared() > 0.05:
		_face(global_position + flat)


## A small step up (T-057): at the crest of Map 0's staircase the ramp meets the hall floor in a seam the slide
## treats as a wall, and a walker stopped dead there (the stair-head idle near (3, 3.8, 9)). When it's blocked
## on the floor and there's room 0.25 m up and a little ahead, lift it over; gravity and the floor snap set it down.
func _step_up(desired: Vector3) -> bool:
	var fwd: Vector3 = Vector3(desired.x, 0.0, desired.z).normalized() * 0.12
	var up: Vector3 = Vector3.UP * 0.25
	if test_move(global_transform, up):
		return false
	if test_move(global_transform.translated(up), fwd):
		return false
	global_position += up + fwd
	return true


func _start_sidestep(desired: Vector3) -> void:
	if desired.length_squared() < 0.0001:
		return
	_sidestep_side = -_sidestep_side
	_sidestep_dir = desired.normalized().rotated(Vector3.UP, deg_to_rad(75.0) * _sidestep_side)
	_sidestep_t = 0.6


## The path corner the agent has just passed when it's snagged (T-057). NavigationAgent3D moves on to the next
## point once it is within path_desired_distance (0.6 m) of a corner, so a fast zombie turns early and runs into
## what the corner goes round: the stair foot's balustrade end (Map 0, at about (3.6, 0, 14.6)) caught every runner
## heading upstairs. Walking back onto the skipped corner first clears it. INF when there is none worth it.
func _skipped_corner() -> Vector3:
	var path: PackedVector3Array = _agent.get_current_navigation_path()
	var i: int = _agent.get_current_navigation_path_index()
	if i < 1 or i >= path.size():
		return Vector3.INF
	var c: Vector3 = path[i - 1]
	var d: float = Vector2(c.x - global_position.x, c.z - global_position.z).length()
	if d < 0.15 or d > 1.5 or absf(c.y - global_position.y) > 1.0:
		return Vector3.INF
	return c


func _on_velocity_computed(safe: Vector3) -> void:
	_safe_vel = safe


var _wedge_t: float = 0.0
## Seconds between two looks for a wedged body (the chase), the time to this body's next look (the pool's bodies
## start on different ticks, so a horde's looks are spread) and the chase time since its last one.
const WEDGE_CHECK_S: float = 0.2
var _wedge_look: float = WEDGE_CHECK_S * float(get_instance_id() % 12) / 12.0
var _wedge_since: float = 0.0


## One chase tick of the wedge check: true once the body has been well above the walkable floor for 3 s (the
## caller recycles it). The navmesh is asked every WEDGE_CHECK_S, not every tick: its closest point was the
## dearest single call of a chaser's tick (0.05 ms each, a quarter of the chase), and a body wedged for 3 s is
## still wedged a fifth of a second later. Each look counts the chase time since the last one, so the 3 s stand.
func _wedged(delta: float) -> bool:
	_wedge_since += delta
	_wedge_look -= delta
	if _wedge_look <= 0.0:
		_wedge_t = _wedge_t + _wedge_since if _off_navmesh_height() > 1.0 else 0.0
		_wedge_since = 0.0
		_wedge_look = WEDGE_CHECK_S
	if _wedge_t > 3.0:
		_wedge_t = 0.0
		return true
	return false
var _blocked_t: float = 0.0
var _corner_t: float = 0.0        # seconds left steering back onto a path corner it cut (T-057)
var _corner_pt: Vector3 = Vector3.ZERO
var _prog_t: float = 0.0          # the 0.4 s progress window (T-057): time in it, metres wanted, where it began
var _prog_want: float = 0.0
var _prog_from: Vector3 = Vector3.ZERO
var _sidestep_t: float = 0.0
var _sidestep_dir: Vector3 = Vector3.ZERO
var _sidestep_side: float = 1.0


## How far this zombie's feet are above the closest walkable navmesh point (about 0 when walking normally).
func _off_navmesh_height() -> float:
	var nav: RID = get_world_3d().navigation_map
	var c: Vector3 = NavigationServer3D.map_get_closest_point(nav, global_position)
	if Vector2(c.x - global_position.x, c.z - global_position.z).length() > 1.5:
		return 0.0   # nowhere near the mesh horizontally (climbing, scripted moves): not this check's business
	return global_position.y - c.y


# ---------------------------------------------------------------- outside forces (UPDATE 07, T-105)

## Adds `v` (m/s, world frame) to this body's motion for `seconds` (turbulence, suction, the Lodestone's fling).
## A fling (land_damage > 0) hurts when it ends: land_damage on landing, x1.5 against a wall; below kill_plane_y the
## body is gone for good (the flinger's kill). Bosses are pushed at a third of the velocity and never flung.
func external_push(v: Vector3, seconds: float, by_player: int = 0, weapon_id: StringName = &"", land_damage: float = 0.0) -> void:
	if puppet or not is_active() or state == State.LIFTED:
		return
	if state in [State.EMERGE, State.TO_WINDOW, State.WAIT_WINDOW, State.TEAR, State.CLIMB, State.CLIMB_LINK]:
		return   # still on its way in: a push here would strand it (window-bound states need their window; T-109)
	var boss: bool = self is Foreman or self is Screamer or self is HomageBoss
	_push_v = v * (0.33 if boss else 1.0)
	_push_t = maxf(0.05, seconds)
	_push_by = by_player
	_push_weapon = weapon_id
	_push_land_dmg = 0.0 if boss else maxf(0.0, land_damage)
	_push_wall_hit = false
	_grab_t = 0.0
	if window != null:
		window.release(self)
		window = null
	_agent.avoidance_enabled = false
	_safe_vel = Vector3.ZERO


func is_pushed() -> bool:
	return _push_t > 0.0


func _update_push(delta: float) -> void:
	_push_t -= delta
	velocity.x = _push_v.x
	velocity.z = _push_v.z
	if _push_v.y != 0.0 and _state_t < 0.05:
		velocity.y = _push_v.y
	else:
		velocity.y -= GameState.g_zombie() * delta
	_push_v.y = 0.0
	move_and_slide()
	if _push_land_dmg > 0.0 and not _push_wall_hit:
		for i: int in get_slide_collision_count():
			var c: KinematicCollision3D = get_slide_collision(i)
			if c.get_normal().y < 0.5 and Vector2(_push_v.x, _push_v.z).length() > 4.0:
				_push_wall_hit = true
				break
	var gone: bool = global_position.y < kill_plane_y and _push_land_dmg > 0.0
	if gone:
		_push_t = 0.0
		_push_v = Vector3.ZERO
		if _push_by > 0:
			Economy.award(_push_by, int((GLData.table("economy") as Dictionary).get("returned_kill", 100)))
		take_damage(hp + 1.0, &"torso", _push_weapon, _push_by, &"world")
		return
	if _push_t <= 0.0 or (is_on_floor() and _state_t > 0.25 and _push_land_dmg > 0.0) or _push_wall_hit:
		_end_push()


func _end_push() -> void:
	var dmg: float = _push_land_dmg * (1.5 if _push_wall_hit else 1.0)
	_push_t = 0.0
	_push_v = Vector3.ZERO
	_push_land_dmg = 0.0
	velocity = Vector3.ZERO
	_agent.avoidance_enabled = true
	if dmg > 0.0:
		if take_damage(dmg, &"torso", _push_weapon, _push_by, &"explosive", true):
			return
		if state == State.CHASE or state == State.ATTACK or state == State.STAGGER:
			_react_clip = ""
			_enter(State.STAGGER)
	_state_t = 0.0


## Lifts the body `height` m off the ground and holds it there `seconds` (the Lodestone's well): no movement, no
## attack. It ends with drop() (drop_damage, a stagger) or slam() (slam_damage and a shockwave of wave_radius /
## wave_damage round the impact). Bosses are never lifted (the caller staggers them instead).
func lift(height: float, seconds: float, by_player: int, weapon_id: StringName, drop_damage: float, slam_damage: float,
		wave_radius: float = 0.0, wave_damage: float = 0.0) -> void:
	if puppet or not is_active() or state == State.DEAD or self is Foreman or self is Screamer or self is HomageBoss:
		return
	_push_t = 0.0
	_push_v = Vector3.ZERO
	_grab_t = 0.0
	if window != null:
		window.release(self)
		window = null
	_lift_t = 0.0
	_lift_total = maxf(0.2, seconds)
	_lift_y0 = global_position.y
	_lift_h = maxf(0.3, height)
	_lift_by = by_player
	_lift_weapon = weapon_id
	_lift_drop_dmg = drop_damage
	_lift_slam_dmg = slam_damage
	_lift_slam_wave = wave_radius
	_lift_slam_wave_dmg = wave_damage
	_agent.avoidance_enabled = false
	_safe_vel = Vector3.ZERO
	velocity = Vector3.ZERO
	_enter(State.LIFTED)


func is_lifted() -> bool:
	return state == State.LIFTED


func _update_lifted(delta: float) -> void:
	if state != State.LIFTED:
		return
	_lift_t += delta
	var k: float = clampf(_lift_t / 0.3, 0.0, 1.0)
	var bob: float = 0.08 * sin(_lift_t * 5.0)
	global_position.y = _lift_y0 + _lift_h * (k * k * (3.0 - 2.0 * k)) + bob * k
	velocity = Vector3.ZERO
	if _lift_t >= _lift_total:
		drop()


## The hold ends: the body falls (drop damage, then a stagger on landing).
func drop() -> void:
	if state != State.LIFTED:
		return
	_agent.avoidance_enabled = true
	velocity = Vector3.ZERO
	global_position.y = _lift_y0
	if take_damage(_lift_drop_dmg, &"torso", _lift_weapon, _lift_by, &"explosive", true):
		return
	_react_clip = ""
	_enter(State.STAGGER)


## Slammed down: the slam damage (lethal to a Gänger of its round), a shockwave round the impact that hurts
## everything near it (zombies included; the Lodestone's holder is immune through its Ballast rule), a knockdown
## if it lives.
func slam() -> void:
	if state != State.LIFTED:
		return
	_agent.avoidance_enabled = true
	velocity = Vector3.ZERO
	global_position.y = _lift_y0
	var pos: Vector3 = global_position
	var killed: bool = take_damage(_lift_slam_dmg, &"torso", _lift_weapon, _lift_by, &"explosive", true)
	if _lift_slam_wave > 0.0 and director != null and director.has_method("active_zombies"):
		for z: Zombie in director.call("active_zombies"):
			if z == self or not z.is_active() or z.state == State.LIFTED:
				continue
			if z.global_position.distance_to(pos) <= _lift_slam_wave:
				z.take_damage(_lift_slam_wave_dmg, &"torso", _lift_weapon, _lift_by, &"explosive", true)
		for n: Node in get_tree().get_nodes_in_group(&"players"):
			var p: Player = n as Player
			if p == null or not p.is_alive() or p.has_method("lodestone_ballast") and bool(p.call("lodestone_ballast")):
				continue
			if p.global_position.distance_to(pos) <= _lift_slam_wave:
				p.take_hit(_lift_slam_wave_dmg * 0.5, self)
	if killed:
		return
	_knockdown()


func _halt(delta: float) -> void:
	_safe_vel = Vector3.ZERO
	if _agent.avoidance_enabled:
		_agent.velocity = Vector3.ZERO
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
	_apply_gravity(delta)
	if _at_rest():
		halt_skips += 1
		return
	_rest_tick = REST_REFRESH_TICKS
	move_and_slide()
	_rest_from = global_position if get_position_delta().length_squared() < 1.0e-10 else Vector3.INF


## T-281: a halted body at rest needs no move_and_slide. A zombie that stands (queued at a window, tearing the
## boards, staggered, getting up, waiting at a ladder) asked the physics engine every tick to slide it nowhere: the
## floor snap pressed it into the ground it already stood on and it came back where it was (0.03-0.05 ms a call, a
## quarter of the horde at the windows in a full round). It is skipped while nothing could move the body: no
## velocity left on the flat, on the floor (the gravity step found it and the step off another zombie's head did not
## fire), not on a moving floor, not moved by anyone since its last real slide, and that slide itself moved it by
## nothing. Every REST_REFRESH_TICKS-th tick slides for real all the same, so the floor contact and the slide's
## collisions stay fresh. `t281_opt` false: every tick slides, as before.
const REST_REFRESH_TICKS: int = 10
var _rest_from: Vector3 = Vector3.INF   # where the last real slide left the body when it moved it by nothing
var _rest_tick: int = 0
static var halt_skips: int = 0          # skipped slides (perf_marks counts them)


func _at_rest() -> bool:
	if not t281_opt or _rest_from != global_position:
		return false
	if velocity.x != 0.0 or velocity.z != 0.0 or velocity.y > 0.0 or not is_on_floor():
		return false
	if get_platform_velocity() != Vector3.ZERO:
		return false
	_rest_tick -= 1
	return _rest_tick > 0


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = -0.5
		_slide_off_zombie()
	else:
		velocity.y -= GameState.g_zombie() * delta


## A zombie must never stand on another zombie's head (two emerging on one spot, or a crush at a window):
## it steps off sideways, away from the one beneath (playtest fix, T-027).
func _slide_off_zombie() -> void:
	for i: int in get_slide_collision_count():
		var c: KinematicCollision3D = get_slide_collision(i)
		if c.get_normal().y > 0.6 and c.get_collider() is Zombie:
			var under: Node3D = c.get_collider() as Node3D
			var away: Vector3 = global_position - under.global_position
			away.y = 0.0
			if away.length_squared() < 0.0001:
				away = Vector3(cos(float(get_instance_id() % 628) * 0.01), 0, sin(float(get_instance_id() % 628) * 0.01))
			away = away.normalized()
			velocity.x = away.x * 3.0
			velocity.z = away.z * 3.0
			return


func _face(p: Vector3) -> void:
	var d: Vector3 = p - global_position
	d.y = 0.0
	if d.length_squared() < 0.0001:
		return
	var yaw: float = atan2(-d.x, -d.z)
	var before: float = rotation.y
	rotation.y = lerp_angle(rotation.y, yaw, 0.25)
	_turn_motion.request(before, yaw, _can_recorded_turn())
	_turn_rate = wrapf(rotation.y - before, -PI, PI) / maxf(0.001, get_physics_process_delta_time())


func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func _active_lure() -> Node3D:
	for n: Node in get_tree().get_nodes_in_group(&"lures"):
		var g: Gramophone = n as Gramophone
		if g != null and global_position.distance_to(g.global_position) <= g.lure_radius():
			return g
	return null


## Sets the zombie on fire (flamethrower, incendiary rounds). Refreshes rather than stacks.
func ignite(dps: float, seconds: float, by_player: int) -> void:
	if puppet:
		if not Net.applying and Net.session != null:
			Net.session.send_zombie_effect(self, &"ignite", dps, seconds)
		_burn_t = maxf(_burn_t, seconds)
		return
	_burn_dps = maxf(_burn_dps if _burn_t > 0.0 else 0.0, dps)
	_burn_t = maxf(_burn_t, seconds)
	_burn_by = by_player


## Red Winter frost: slows movement. Refreshes the timer; never stacks beyond one slow.
func apply_frost(slow: float, seconds: float) -> void:
	if puppet:
		if not Net.applying and Net.session != null:
			Net.session.send_zombie_effect(self, &"frost", slow, seconds)
		return
	_frost_slow = maxf(_frost_slow if _frost_t > 0.0 else 0.0, slow)
	_frost_t = maxf(_frost_t, seconds)


func frost_speed_mult() -> float:
	return 1.0 - _frost_slow if _frost_t > 0.0 else 1.0


## Bell Dome (Totenglocke alt-fire, T-048): takes `mult` x damage for the next `seconds` (real time; the dome
## refreshes it every tick while the zombie is inside).
func set_vulnerable(mult: float, seconds: float) -> void:
	_vuln_mult = mult
	_vuln_until_ms = Time.get_ticks_msec() + int(seconds * 1000.0)


## The Totenhafen searchlight's beam (C2, T-153): lit zombies are slowed by `slow` and take `mult` x damage while
## the beam keeps refreshing them (the station calls this every tick with a short `seconds`); set_lit(false) ends it.
func set_lit(on: bool, slow: float = 0.4, mult: float = 1.25, seconds: float = 0.5) -> void:
	if on:
		apply_frost(slow, seconds)
		if vulnerability() <= mult:
			set_vulnerable(mult, seconds)
		set_meta(&"lit_until", Time.get_ticks_msec() + int(seconds * 1000.0))
	elif has_meta(&"lit_until"):
		remove_meta(&"lit_until")


func is_lit() -> bool:
	return has_meta(&"lit_until") and int(get_meta(&"lit_until")) > Time.get_ticks_msec()


func vulnerability() -> float:
	return _vuln_mult if _vuln_until_ms > Time.get_ticks_msec() else 1.0


## Interrupts the current attack/chase (Ironmonger stagger rounds).
func force_stagger() -> void:
	if puppet:
		if not Net.applying and Net.session != null:
			Net.session.send_zombie_effect(self, &"stagger")
		return
	if state == State.CHASE or state == State.ATTACK:
		_react_clip = ""
		_enter(State.STAGGER)


func is_burning() -> bool:
	return _burn_t > 0.0


func _update_burn(delta: float) -> void:
	if _burn_t <= 0.0 or not is_active():
		return
	_burn_t -= delta
	_burn_tick -= delta
	_char = minf(1.0, _char + delta * 0.25)
	if _burn_tick <= 0.0:
		_burn_tick = 0.25
		take_damage(_burn_dps * 0.25, &"torso", &"fire", _burn_by, &"fire")
		if ZombieGore.blood_allowed():
			Effects.blood(global_position + Vector3.UP * randf_range(0.6, 1.6), Vector3.UP)


func _nearest_player() -> Player:
	if forced_target != null:
		if is_instance_valid(forced_target) and forced_target.is_alive() and forced_target.is_inside_tree():
			return forced_target
		forced_target = null
	var best: Player = null
	var best_d: float = INF
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not p.is_alive():
			continue
		var d: float = global_position.distance_squared_to(p.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


# ---------------------------------------------------------------- damage

## Applies damage from one source in one shot. Returns true if this killed the zombie.
## kind: &"bullet", &"melee", &"explosive", &"world" (traps/blackout: no Scrip).
func take_damage(amount: float, limb: StringName, weapon_id: StringName, by_player: int, kind: StringName = &"bullet", armor_piercing: bool = false) -> bool:
	if puppet:
		return _puppet_damage(amount, limb, weapon_id, by_player, kind, armor_piercing)
	if _dormant:
		last_hit_bone = ""
		return false   # T-192: a bled-out teammate's body that has not got up yet takes nothing
	# the Marke (T-137): damage_mult x, then the hit goes on as one on the host limb (armour, wounds, the death
	# clips, the headshot path); _marke_hit is read by _die for the bonus and cleared by any other hit. T-192: a Soviet
	# risen's wound is the same box with the same numbers in another place, without the Marke's signal.
	_marke_hit = limb == &"marke"
	if _marke_hit:
		limb = marke_host_limb()
		if marke_site != &"":
			last_hit_bone = str(ZombieBody.weak_site(marke_site)[0])
		amount *= float(((GLData.table("enemies") as Dictionary).get("marke", {}) as Dictionary).get("damage_mult", 1.5))
		if not is_wound():
			GLBus.marke_hit.emit(by_player)
	# the caller's hitbox bone belongs to this hit only: consumed before any early return so it can never leak
	# into a later boneless hit (explosions, fire) as the wrong wound side
	var side: String = _hit_side(limb)
	last_hit_bone = ""
	if not is_active():
		return false
	if (limb == &"torso" or limb == &"arms") and kind == &"bullet" and not armor_piercing:
		amount *= armor_torso_mult
	if limb == &"head" and _cfg.has("head_mult"):
		amount *= float(_cfg["head_mult"])   # the Suited's visor (T-112)
	if limb == &"head" and bool(_cfg.get("visor", false)) and kind != &"world" and kind != &"fire":
		_crack_visor(by_player, weapon_id)
	if has_meta(&"limb_mults"):
		amount *= float((get_meta(&"limb_mults") as Dictionary).get(String(limb), 1.0))   # T-153: a tagged kind's own table (the diver's helmet)
	amount *= vulnerability()
	if GameState.has_flag(&"deaths_door") and kind != &"world":
		amount = hp + 1.0
	hp -= amount
	var pt: int = BotProf.t()   # (T-283: the damage path's sections, for the measuring tools; off: one bool read)
	GLBus.enemy_damaged.emit(enemy_id, limb, amount, by_player)
	damaged.emit(amount, limb, by_player, kind)
	BotProf.add(&"z.hit.signals", pt)
	pt = BotProf.t()
	if kind != &"fire" and kind != &"world":
		_wound(limb, side)
	BotProf.add(&"z.hit.wound", pt)
	if kind == &"bullet":
		AudioDirector.play_3d("impact_flesh", global_position + Vector3.UP * 1.2, 0.0, 0.0)
	if kind == &"melee" and _grab_t > 0.0:
		_grab_t = 0.0   # a knife to the grabbing zombie breaks the grab
	if hp <= 0.0:
		pt = BotProf.t()
		_die(limb, weapon_id, by_player, kind)
		BotProf.add(&"z.die", pt)
		return true
	if by_player > 0 and kind != &"fire":
		Economy.award(by_player, int(GLData.table("economy")["hit_nonlethal"]))
	if kind != &"fire":
		_play_flinch(limb, side)
	# Crawlers: a leg damage pool, or a chance from explosions.
	if not is_crawler and bool(_cfg.get("can_crawl", true)):
		if limb == &"legs":
			_leg_damage += amount
			if _leg_damage >= max_hp * float(_cfg["leg_pool_fraction"]):
				_leg_damage = -INF
				if randf() < float(_cfg["leg_sever_chance"]):
					become_crawler()
		elif kind == &"explosive" and randf() < float(_cfg["explosive_crawler_chance"]):
			become_crawler()
	# Arms: a damage pool per side; an emptied pool can take the forearm or the whole arm (anim.json gore).
	if limb == &"arms" and bool(_cfg.get("can_crawl", true)):
		_arm_hit(amount, side)
	elif limb == &"head" and kind == &"bullet" and randf() < float(_anim["gore"].get("jaw_chance_on_head_hit", 0.12)):
		ZombieGore.sever(self, "Jaw", _away_from_target() * 2.0 + Vector3.UP * 2.0)
	var kd: Dictionary = _anim["knockdown"]
	var knock: bool = (kd["kinds"] as Array).has(String(kind)) or (kd["weapons"] as Array).has(String(weapon_id))
	if knock and amount >= max_hp * float(kd.get("min_fraction", 0.08)) and state in [State.CHASE, State.ATTACK, State.STAGGER] and not is_crawler and bool(_cfg.get("can_crawl", true)):
		_knockdown()
		return false
	if state == State.GETUP:
		# A real hit knocks it back down once per knockdown; fire / trap ticks (every 0.25 s) and the rest of an
		# automatic burst don't, so continuous damage can never pin a zombie on the floor.
		if kind != &"fire" and kind != &"world" and not _getup_restarted:
			_getup_restarted = true
			_enter(State.GETUP)
		return false
	var stagger_ok: bool = kind != &"bullet" or bool(_cfg.get("bullet_stagger", true))
	if stagger_ok and (kind == &"melee" or kind == &"explosive" or amount >= max_hp * float(_anim["stagger"].get("damage_fraction", 0.4))) and state == State.CHASE:
		_react_clip = ""
		_enter(State.STAGGER)
	return false


## Which side an arm / leg hit landed on, from the hitbox bone the weapon reported (or a coin toss).
func _hit_side(limb: StringName) -> String:
	if limb != &"arms" and limb != &"legs":
		return ""
	var b: String = ZombieRig.legacy_name(last_hit_bone)
	if b.begins_with("Left"):
		return "l"
	if b.begins_with("Right"):
		return "r"
	return "l" if randf() < 0.5 else "r"


func _arm_hit(amount: float, side: String) -> void:
	var g: Dictionary = _anim["gore"]
	_arm_damage[side] = float(_arm_damage.get(side, 0.0)) + amount
	if _arm_damage[side] >= max_hp * float(g.get("arm_pool_fraction", 0.28)):
		_arm_damage[side] = -INF
		if randf() < float(g.get("arm_sever_chance", 0.55)):
			var upper: String = "LeftUpperArm" if side == "l" else "RightUpperArm"
			var fore: String = "LeftLowerArm" if side == "l" else "RightLowerArm"
			var bone: String = fore if randf() < float(g.get("forearm_vs_upper", 0.65)) else upper
			sever_limb(bone)


## Severs a chain (gameplay + presentation): arm pieces change the attack set, legs at the hip make a crawler.
func sever_limb(bone: String) -> void:
	if puppet and not Net.applying:
		return
	var imp: Vector3 = _away_from_target() * randf_range(1.5, 3.0) + Vector3.UP * randf_range(2.0, 3.5)
	if ZombieGore.severs_allowed() and not is_severed(bone):
		AudioDirector.play_3d("zombie_gib", global_position + Vector3.UP * 1.2, -3.0)
	ZombieGore.sever(self, bone, imp)
	_severed_logic[bone] = true
	_marke_on_sever(bone)
	if Net.replicating():
		Net.session.zombie_event(self, &"fx", [&"sever", bone, imp])


func arms_lost() -> int:
	var n: int = 0
	for side: String in ["Left", "Right"]:
		if _severed_logic.has(side + "UpperArm") or _severed_logic.has(side + "LowerArm"):
			n += 1
	return n


func _away_from_target() -> Vector3:
	var away: Vector3 = global_position - (target.global_position if target != null else global_position + global_basis.z)
	away.y = 0.0
	return away.normalized() if away.length_squared() > 0.001 else -global_basis.z


func _knockdown() -> void:
	# a blast from the front throws the zombie onto its back
	var from_front: bool = true
	if target != null:
		var to_t: Vector3 = target.global_position - global_position
		from_front = (-global_basis.z).dot(to_t) > 0.0
	_down_front = not from_front
	if Net.replicating():
		Net.session.zombie_event(self, &"fx", [&"knockdown", _down_front])
	_enter(State.KNOCKDOWN)


func become_crawler() -> void:
	if is_crawler:
		return
	if puppet and not Net.applying:
		if Net.session != null:
			Net.session.send_zombie_effect(self, &"crawl")
		return
	is_crawler = true
	if Net.replicating():
		Net.session.zombie_event(self, &"crawl", [])
	AudioDirector.play_3d("zombie_gib", global_position + Vector3.UP * 0.6)
	var moving: bool = Vector2(velocity.x, velocity.z).length() > 1.5
	for leg: String in ["LeftUpperLeg", "RightUpperLeg"]:
		ZombieGore.sever(self, leg, Vector3(randf_range(-1.5, 1.5), 2.0, randf_range(-1.5, 1.5)))
	if ZombieGore.blood_allowed():
		Effects.blood(global_position + Vector3.UP * 0.9, Vector3.UP)
		Effects.gore.crawler(self)   # it drags a smear behind it (gore rework)
	_set_crawl_pose(true)
	if state == State.EMERGE and _staged_emerge():
		_emerge_switch_variant("crawler")   # legs blown off while rising: it finishes the rise on its elbows
		return
	# the fall-into-crawler transition: a stumble that ends in the crawl pose, then the crawl locomotion
	if not puppet and state in [State.CHASE, State.ATTACK, State.STAGGER, State.TO_WINDOW, State.WAIT_WINDOW] and moving:
		_react_clip = str(_anim["clips"]["react"]["fall_crawl"])
		_react_len = ZombieClips.length_of(_react_clip)
		_enter(State.STAGGER)
	elif state in [State.CHASE, State.TO_WINDOW, State.WAIT_WINDOW]:
		_tree_locomotion(true)


func _die(limb: StringName, weapon_id: StringName, by_player: int, kind: StringName) -> void:
	if window != null:
		window.release(self)
		window = null
	collision_layer = 0
	collision_mask = LAYER_WORLD
	for hb: Hitbox in _hitboxes:
		hb.collision_layer = 0
	_marke_layers(false)
	_agent.avoidance_enabled = false
	_safe_vel = Vector3.ZERO
	velocity = Vector3.ZERO
	_grab_t = 0.0
	var pt: int = BotProf.t()
	if by_player > 0:
		var econ: Dictionary = GLData.table("economy")
		var value: int = Economy.kill_value(limb, kind == &"melee", econ)
		if _cfg.has("scrip"):
			var sc: Variant = _cfg["scrip"]
			# (a row may give the kill pay per hit zone {head, neck, body, melee} or as one number: the U10 Totenhafen
			# enemies' "scrip": 60 errored here on every kill and paid nothing)
			value = Economy.kill_value(limb, kind == &"melee", {"kill": sc}) if sc is Dictionary else int(sc)
		if limb == &"head" and kind != &"melee" and GameState.player_has_trait(by_player, &"wren"):
			value += int(GLData.table("player")["traits"]["wren_headshot_scrip_bonus"])
		Economy.award(by_player, value)
		if _marke_hit:
			_pay_marke_bonus(by_player)   # T-137: a kill from a Marke hit, right after the normal reward
	BotProf.add(&"z.die.pay", pt)
	pt = BotProf.t()
	var defer: bool = t283_opt and t283_death and not puppet
	if defer:
		_queue_death_fx(&"groan", [global_position + Vector3.UP * 1.2])
	else:
		AudioDirector.play_3d("zombie_death", global_position + Vector3.UP * 1.2, -1.0)
	_death_burst()
	BotProf.add(&"z.die.sound", pt)
	pt = BotProf.t()
	GLBus.enemy_killed.emit(enemy_id, limb, weapon_id, by_player)
	BotProf.add(&"z.die.bus_killed", pt)
	pt = BotProf.t()
	GLBus.enemy_killed_at.emit(enemy_id, global_position, by_player)
	BotProf.add(&"z.die.bus_killed_at", pt)
	pt = BotProf.t()
	RoundManager.on_zombie_died()
	BotProf.add(&"z.die.round", pt)
	pt = BotProf.t()
	_death_kind = _pick_death(limb, kind)
	_death_side = -1.0 if randf() < 0.5 else 1.0
	_death_explosive = kind == &"explosive"
	var pop: bool = false
	if limb == &"head" and kind != &"world" and _death_clip != "death_head_snap":
		pop = true
	elif kind == &"explosive" and randf() < float(_anim["gore"].get("head_pop_explosive_chance", 0.35)):
		pop = true
	_mark_death_sink()
	_start_death()
	BotProf.add(&"z.die.start", pt)
	pt = BotProf.t()
	if pop:
		if defer and not _head_popped:
			_head_popped = true   # (decided now: the co-op event below and every later check see it)
			_queue_death_fx(&"pop", [])
		else:
			_pop_head()
	if kind == &"explosive" and ZombieGore.severs_allowed() and randf() < 0.5:
		var loose: String = _pick(["LeftLowerLeg", "RightLowerLeg", "LeftLowerArm", "RightLowerArm"])
		if defer:
			_queue_death_fx(&"sever", [loose, _away_from_target() * 4.0 + Vector3.UP * 4.0])
		else:
			ZombieGore.sever(self, loose, _away_from_target() * 4.0 + Vector3.UP * 4.0)
	BotProf.add(&"z.die.gore", pt)
	if Net.replicating():
		Net.session.zombie_died(self, limb, kind, _death_kind, _death_side, _head_popped)


## The death clip for the cause: head kills snap or walk headless, sprinters tumble, blasts throw (anim.json).
func _pick_death(limb: StringName, kind: StringName) -> int:
	var deaths: Array = _anim["clips"]["death"]
	var by: Dictionary = _anim["clips"].get("death_by_cause", {})
	var pool: Array = []
	if is_crawler:
		_death_clip = str(_anim["clips"]["death_crawler"])
		return deaths.size()
	if limb == &"head" and kind != &"world":
		pool = (by.get("head", []) as Array).duplicate()
		if randf() >= float(_anim["gore"].get("headless_stagger_chance", 0.5)):
			pool.erase("death_headless")
	elif kind == &"explosive":
		pool = (by.get("explosive", []) as Array).duplicate()
	elif tier == &"sprint":
		pool = (by.get("sprint", []) as Array).duplicate()
	if pool.is_empty():
		pool = deaths.duplicate()
		pool.erase("death_headless")
		pool.erase("death_head_snap")
	_death_clip = str(_pick(pool))
	return maxi(0, deaths.find(_death_clip))


func _start_death() -> void:
	_ladder_on_death()   # T-268: killed on a climb, the body falls (reads the state it died in)
	state = State.DEAD
	_state_t = 0.0
	_ragdoll_started = false
	_death_previous_pose.clear()
	_death_velocity.clear()
	var rd: Array = _anim["ragdoll"].get("corpse_seconds", [8.0, 12.0])
	_corpse_seconds = randf_range(float(rd[0]), float(rd[1]))
	var pt: int = BotProf.t()
	if not _death_sink and enemy_id != &"glasshide":
		Effects.gore.death(self, 1.3 if _death_explosive else 1.0)   # the pool under the body (gore rework)
	BotProf.add(&"z.die.pool", pt)
	if has_rig():
		_look.active = false
		_modifier.ik_weight = 0.0
		if ZombieClips.visual_clip(_death_clip).begins_with("mco_"):
			_tree.set("parameters/Posture/add_amount", 0.0)
	_enter(State.DEAD)


var _death_previous_pose: Dictionary = {}
var _death_velocity: Dictionary = {}


## Velocity of the evaluated recorded fall, including its presentation root displacement.
## Physics starts from the same pose and momentum; no additional death poses are authored.
func _record_death_velocity(dt: float) -> void:
	var settings: Dictionary = ZombieClips.death_motion_config()
	if not bool(settings.get("inherit_velocity", false)) or dt <= 0.0: return
	for bone: String in _anim["ragdoll"]["bones"]:
		var index: int = _skel.find_bone(bone)
		if index < 0: continue
		var pose: Transform3D = _skel.global_transform * _skel.get_bone_global_pose(index)
		if _death_previous_pose.has(bone):
			var previous: Transform3D = _death_previous_pose[bone]
			var rotation_delta: Quaternion = (pose.basis.orthonormalized().get_rotation_quaternion() * previous.basis.orthonormalized().get_rotation_quaternion().inverse()).normalized()
			if rotation_delta.w < 0.0: rotation_delta = -rotation_delta
			var angular: Vector3 = rotation_delta.get_axis() * rotation_delta.get_angle() / dt
			_death_velocity[bone] = {"linear": ((pose.origin - previous.origin) / dt).limit_length(float(settings["max_linear_mps"])), "angular": angular.limit_length(float(settings["max_angular_rps"]))}
		_death_previous_pose[bone] = pose


func _begin_ragdoll() -> void:
	var launch: Vector3 = Vector3.ZERO
	if _death_explosive:
		launch = _away_from_target() * float(_anim["ragdoll"].get("explosive_launch", 5.0)) + Vector3.UP * 3.0
	var pt: int = BotProf.t()
	_ragdoll = ZombieRagdoll.start(_skel, launch, _death_velocity)
	BotProf.add(&"z.ragdoll.start", pt)
	# the tree stays active (deactivating an AnimationTree resets the rendered skin to rest); it simply is not
	# advanced any more while the ragdoll writes the bones (_animate)


func _end_ragdoll() -> void:
	if _ragdoll != null:
		ZombieRagdoll.stop(_ragdoll)
		_ragdoll = null


## Removes this zombie without a kill (stuck or unreachable) and puts it back in the round queue.
## T-283: why bodies were put back, counted for the measuring tools (perf_marks prints them).
static var recycled_why: Dictionary = {}


func _recycle_for(why: StringName) -> void:
	if not puppet and is_active():
		recycled_why[why] = int(recycled_why.get(why, 0)) + 1
	recycle()


func recycle() -> void:
	if puppet or not is_active():
		return
	RoundManager.requeue()
	deactivate()
	if director != null:
		director.call("on_zombie_returned", self)


## Kills with no Scrip (Blackout, dev console).
func kill_silently() -> void:
	if not puppet and is_active():
		hp = 0.0
		_die(&"torso", &"none", 0, &"world")


# ---------------------------------------------------------------- body (skinned procedural body on the shared rig)

var _skel: Skeleton3D
var _body: MeshInstance3D
var _ap: AnimationPlayer
var _tree: AnimationTree
var _sm: AnimationNodeStateMachine
var _playback: AnimationNodeStateMachinePlayback
var _anim_nodes: Dictionary = {}     # state -> AnimationNodeAnimation (one-shot states)
var _loco_bs: AnimationNodeBlendSpace2D
var _crawl_bs: AnimationNodeBlendSpace1D
var _posture_node: AnimationNodeAnimation
var _flinch_node: AnimationNodeAnimation
var _modifier: ZombieBodyModifier
var _look: LookAtModifier3D
var _look_target: Node3D
var _bones: Dictionary = {}          # profile bone name -> BoneAttachment3D (lazy)
var _gear: Array[MeshInstance3D] = []
var _caps: Dictionary = {}           # bone -> stump cap MeshInstance3D
var _severed: Dictionary = {}        # visual
var _severed_logic: Dictionary = {}  # gameplay (also set on puppets from the host's event)
var _arm_damage: Dictionary = {}
var _variant: String = "soldier"
var _build: String = "medium"
var _female: bool = false
var _height: float = 1.0
var _death_kind: int = 0
var _death_side: float = 1.0
var _death_clip: String = "death_back"
var _death_explosive: bool = false
var _corpse_seconds: float = 10.0
var _ragdoll: PhysicalBoneSimulator3D = null
var _ragdoll_started: bool = false
var _decals: Array[MeshInstance3D] = []
var _decal_i: int = 0
var _head_popped: bool = false
var _tree_state: String = ""
var _loco_clip: String = "walk_a"
var _loco_speed: float = 2.0
var _loco_x: float = 0.0
var _loco_turn: float = 0.0
var _turn_rate: float = 0.0
var _cycle: float = 0.0
var _step_phase_valid: bool = false
var _cycle_len: float = 1.0
var _contact_lock: RefCounted = preload("res://gravelight/enemies/zombie_contact_lock.gd").new()
var _turn_motion: RefCounted = preload("res://gravelight/enemies/zombie_turn_motion.gd").new()
var _attack_clip: String = "swipe_l"
var _tear_clip: String = "tear_rip"
var _climb_clip: String = "vault_a"
var _react_clip: String = ""
var _react_len: float = 0.35
var _emerge_kind: String = "ground"
var _emerge_clip: String = "emerge_standard"
## The rise from the ground (T-085, ZombieEmerge): the variant, its length this rise (round-scaled), the next
## stage whose effects fire, the surface class under the spawn, and whether the hitboxes wait for "head_out".
var _emerge_variant: String = "standard"
var _emerge_secs: float = 1.4
var _emerge_stage_i: int = 0
var _emerge_surface: String = "earth"
var _emerge_hitboxes_off: bool = false
var _emerge_dig_t: float = 0.0
var _spawn_surface: String = ""
var _mound: MeshInstance3D = null
var _hole: MeshInstance3D = null
## Killed mid-rise: the body slides back into the ground instead of a death clip (no ragdoll, no corpse).
var _death_sink: bool = false
var _sink_corpse_s: float = 0.0
## Shared across the pool: the variant draw, seeded from the match seed so a seeded match replays its rises, and
## the global rate cap on the claw crunches (24 zombies rising at once would stack a hundred a second).
static var _emerge_rng: RandomNumberGenerator = RandomNumberGenerator.new()
static var _emerge_seed: int = -1
static var _last_dig_msec: int = 0
var _down_front: bool = false
var _getup_restarted: bool = false   # this knockdown's get-up was already restarted by a hit (one restart max)
var _climb_dist: float = 1.0
var _mantling: bool = false
var _swipe_t: float = 0.0
var _grab_t: float = 0.0
var _grab_target: Player = null
var _char: float = 0.0
var _frost_base: float = 0.0
var _inst: Dictionary = {}
var _rm_dist: float = 0.0
var _rm_time: float = 0.0
var _rm_speed: float = 0.0
var _body_dist: float = 0.0
var _body_speed: float = 0.0
var _rm_pos_last: Vector3 = Vector3.ZERO
var _foot_idx: PackedInt32Array = [-1, -1]


func _build_body() -> void:
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	_skel = ZombieRig.build_skeleton()
	_pivot.add_child(_skel)
	_body = MeshInstance3D.new()
	_body.name = "Body"
	_body.mesh = ZombieBody.build_skinned("soldier", "medium", false)
	_skel.add_child(_body)
	_body.skeleton = NodePath("..")   # explicit: the default path does not survive the skin being set first
	_body.skin = _skel.create_skin_from_rest_transforms()
	_foot_idx = [_skel.find_bone("LeftFoot"), _skel.find_bone("RightFoot")]
	for h: Array in ZombieBody.HITBOXES:
		var hb: Hitbox = Hitbox.new()
		var bone: String = ZombieRig.legacy_name(str(h[0]))
		hb.setup(self, h[1], h[2])
		hb.bone = bone
		hb.position = h[3]
		bone_attachment(bone).add_child(hb)
		_hitboxes.append(hb)
	# the Marke (T-137): a hitbox and a glint per site; _apply_marke picks the live one at every spawn
	var mk: Dictionary = (GLData.table("enemies") as Dictionary).get("marke", {})
	var cube: float = float(mk.get("hitbox_m", 0.07))
	for site: StringName in ZombieBody.MARKE_SITES.keys():
		var ms: Array = ZombieBody.MARKE_SITES[site]
		var at: BoneAttachment3D = bone_attachment(str(ms[0]))
		if at == null:
			continue
		var mhb: Hitbox = Hitbox.new()
		mhb.name = "marke"
		mhb.setup(self, &"marke", Vector3(cube, cube, cube))
		mhb.bone = str(ms[0])
		mhb.position = ms[1]
		mhb.collision_layer = 0
		at.add_child(mhb)
		_weak_box_live(mhb, false)
		_marke_hb[site] = mhb
		var gl: MeshInstance3D = MeshInstance3D.new()
		gl.name = "MarkeGlint"
		gl.mesh = ZombieBody.marke_glint_mesh()
		gl.position = ms[1]
		gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gl.visible = false
		at.add_child(gl)
		_marke_glint[site] = gl
	# T-192: the Soviet risen's wound sites: a box like the Marke's and the wound mesh (one shown per body, or none)
	for ws: StringName in ZombieBody.WOUND_SITES.keys():
		var wsd: Array = ZombieBody.WOUND_SITES[ws]
		var wat: BoneAttachment3D = bone_attachment(str(wsd[0]))
		if wat == null:
			continue
		var whb: Hitbox = Hitbox.new()
		whb.name = "wound"
		whb.setup(self, &"marke", Vector3(cube, cube, cube))
		whb.bone = str(wsd[0])
		whb.position = wsd[1]
		whb.collision_layer = 0
		wat.add_child(whb)
		_weak_box_live(whb, false)
		_wound_hb[ws] = whb
		var wm: MeshInstance3D = MeshInstance3D.new()
		wm.name = "Wound"
		wm.mesh = ZombieBody.wound_mesh()
		wm.position = wsd[1]
		wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wm.visible = false
		wat.add_child(wm)
		_wound_nodes[ws] = wm
	# the animation tree
	_ap = AnimationPlayer.new()
	_ap.name = "AP"
	_ap.root_node = NodePath("..")
	_ap.add_animation_library(&"", ZombieClips.library())
	_pivot.add_child(_ap)
	_tree = AnimationTree.new()
	_tree.name = "AT"
	_pivot.add_child(_tree)
	_tree.anim_player = _tree.get_path_to(_ap)
	var root: AnimationNodeBlendTree = ZombieClips.build_tree_root()
	_tree.tree_root = root
	_tree.root_motion_track = NodePath("Skel:Root")
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_tree.active = true
	_sm = root.get_node("SM") as AnimationNodeStateMachine
	_posture_node = root.get_node("PostureAnim") as AnimationNodeAnimation
	_flinch_node = root.get_node("FlinchAnim") as AnimationNodeAnimation
	for s: String in ZombieClips.STATES:
		var st: AnimationNodeBlendTree = _sm.get_node(s) as AnimationNodeBlendTree
		var an: AnimationNode = st.get_node("Anim")
		if an is AnimationNodeAnimation:
			_anim_nodes[s] = an
		elif s == "Locomotion":
			_loco_bs = an as AnimationNodeBlendSpace2D
		elif s == "Crawl":
			_crawl_bs = an as AnimationNodeBlendSpace1D
	_playback = _tree.get("parameters/SM/playback") as AnimationNodeStateMachinePlayback
	# modifiers: head look-at, then foot IK + hit springs
	_look_target = Node3D.new()
	_look_target.name = "LookTarget"
	add_child(_look_target)
	_look = LookAtModifier3D.new()
	_look.name = "LookAt"
	_look.bone_name = "Head"
	_look.forward_axis = SkeletonModifier3D.BONE_AXIS_MINUS_Z
	_look.primary_rotation_axis = Vector3.AXIS_Y
	_look.use_secondary_rotation = true
	_look.use_angle_limitation = true
	_look.symmetry_limitation = true
	_look.primary_limit_angle = deg_to_rad(float(_anim["look_at"].get("cone_deg", 60.0)))
	_look.secondary_limit_angle = deg_to_rad(40.0)
	_look.duration = float(_anim["look_at"].get("smooth_s", 0.2))
	_look.active = false
	_skel.add_child(_look)
	_look.target_node = _look.get_path_to(_look_target)
	_modifier = ZombieBodyModifier.new()
	_modifier.name = "BodyMod"
	_modifier.setup(_anim["foot_ik"], _anim["flinch"]["spring"])
	_skel.add_child(_modifier)
	_build_kind_parts()
	_apply_variant("soldier")


# ---- the public body API ZombieGore / tools use

## True when this body runs on the shared MZ rig (skeleton, AnimationTree, modifiers). The Foreman builds his
## own body in an overriding _ready() and has none of it, so every shared path that drives the rig (senses,
## flinches, tree states, death setup) checks this first; on a co-op client his puppet goes through them.
func has_rig() -> bool:
	return _tree != null and _modifier != null and _look != null and _flinch_node != null


func skeleton() -> Skeleton3D:
	return _skel


func body_mesh() -> MeshInstance3D:
	return _body


func kit_name() -> String:
	return _variant


func build_name() -> String:
	return _build


func is_female() -> bool:
	return _female


func pivot_scale() -> Vector3:
	return _pivot.scale


func is_severed(bone: String) -> bool:
	return _severed.has(bone)


func mark_severed(bone: String) -> void:
	_severed[bone] = true


func clear_severed() -> void:
	_severed.clear()
	for c: MeshInstance3D in _caps.values():
		c.hide()


func stump_cap(bone: String) -> MeshInstance3D:
	if _caps.has(bone):
		return _caps[bone]
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = ZombieBody.stump_mesh()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_caps[bone] = mi
	return mi


## A BoneAttachment3D for a profile (or legacy) bone name, created on first use.
func bone_attachment(name: String) -> BoneAttachment3D:
	var bone: String = ZombieRig.legacy_name(name)
	if _bones.has(bone):
		return _bones[bone]
	if _skel == null or _skel.find_bone(bone) < 0:
		return null
	var at: BoneAttachment3D = BoneAttachment3D.new()
	at.name = "At_" + bone
	at.bone_name = bone
	_skel.add_child(at)
	_bones[bone] = at
	return at


## Legacy accessor (Screamer's throat): bone name -> the attachment node.
func _bone(n: String) -> Node3D:
	return bone_attachment(n)


## Root-motion speed of the current animation (m/s, averaged over the last half second of full-gait locomotion):
## the foot-slide check compares it to body_speed() over the same window.
func anim_speed() -> float:
	return _rm_speed


## Horizontal body speed over the same window as anim_speed().
func body_speed() -> float:
	return _body_speed


func current_clip_state() -> String:
	return _tree_state


func _set_inst(key: String, v: Variant) -> void:
	if _inst.get(key, null) == v:
		return
	_inst[key] = v
	_body.set_instance_shader_parameter(key, v)
	for g: MeshInstance3D in _gear:
		g.set_instance_shader_parameter(key, v)


func _reset_presentation() -> void:
	_turn_motion.reset()
	if has_meta("person"):
		remove_meta("person")   # T-099: a pooled zombie that was a risen person goes back to its kit
	for sg: MeshInstance3D in _squad_gear:
		if is_instance_valid(sg):
			sg.queue_free()   # T-142: a risen soldier's headgear goes with him
	_squad_gear.clear()
	_end_ragdoll()
	ZombieGore.restore(self)
	_severed_logic.clear()
	_arm_damage = {"l": 0.0, "r": 0.0}
	_char = 0.0
	_grab_t = 0.0
	_swipe_t = 0.0
	_mantling = false
	_ladder_clear()
	_react_clip = ""
	_head_popped = false
	_death_sink = false
	_emerge_hitboxes_off = false
	_spawn_surface = ""
	_set_inst("inst_dissolve", 0.0)
	_set_inst("inst_char", 0.0)
	_dormant = false
	if has_meta(&"hard_truth_pid"):
		remove_meta(&"hard_truth_pid")   # T-192: a pooled zombie that was a risen teammate is a plain one again
	_tree_state = ""
	_skel.reset_bone_poses()
	for g: MeshInstance3D in _gear:
		g.hide()


func _apply_variant(variant: String) -> void:
	var kits: Dictionary = _anim["kits"]
	if not kits.has(variant):
		variant = "soldier"
	var kit: Dictionary = kits[variant]
	_variant = variant
	# T-269: in a co-op session the body's own rolls (build, sex, height, gear, tint, dirt, rime) come from the seed
	# every peer has (the net id and the spawn health), so a client sees the host's zombie, not a cousin of it. Alone
	# they are the global generator's, as before.
	_look_rng = null
	if Net.session != null and net_id >= 0:
		_look_rng = RandomNumberGenerator.new()
		_look_rng.seed = ZombieWardrobe.look_seed(net_id, max_hp) + 977
	var builds: Array = kit.get("builds", ["medium"])
	_build = str(_pick(builds)) if _look_rng == null else str(builds[_look_rng.randi() % builds.size()])
	_female = _vr() < float(kit.get("female", 0.0)) if _force_female < 0 else _force_female == 1
	var heights: Array = _anim["builds"].get("heights", [0.95, 1.04])
	_height = _vrr(float(heights[0]), float(heights[1]))
	_body.mesh = ZombieBody.build_skinned(_variant, _build, _female)
	_body.set_surface_override_material(0, null)
	_pivot.scale = Vector3.ONE * _height
	for d: MeshInstance3D in _decals:
		d.hide()
	# gear pieces
	for g: MeshInstance3D in _gear:
		g.hide()
	var gi: int = 0
	var gear: Dictionary = kit.get("gear", {})
	var pieces: Array = []
	for piece0: String in gear.keys():
		if _vr() < float(gear[piece0]):
			pieces.append(piece0)
	# T-192: "gear_one_of": at most one of these (a head wears one hat), rolled in order
	var one_of: Dictionary = kit.get("gear_one_of", {})
	var roll: float = _vr()
	for piece1: String in one_of.keys():
		roll -= float(one_of[piece1])
		if roll < 0.0:
			pieces.append(piece1)
			break
	for piece: String in pieces:
		var spec: Array = ZombieBody.zombie_gear_mesh(piece, _female)   # T-269: one surface on the kit material
		var at: BoneAttachment3D = bone_attachment(str(spec[0]))
		if at == null:
			continue
		var mi: MeshInstance3D
		if gi < _gear.size():
			mi = _gear[gi]
		else:
			mi = MeshInstance3D.new()
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_gear.append(mi)
		gi += 1
		if mi.get_parent() != at:
			if mi.get_parent() != null:
				mi.get_parent().remove_child(mi)
			at.add_child(mi)
		mi.mesh = spec[1]
		mi.show()
	# per-instance look: tint, dirt, frost (anim.json variation)
	var va: Dictionary = _anim["variation"]
	var t: float = float(va.get("tint", 0.08))
	_set_inst("inst_tint", Color(1.0 + _vrr(-t, t), 1.0 + _vrr(-t, t), 1.0 + _vrr(-t, t), 1.0))
	var dirt: Array = va.get("dirt", [0.1, 0.8])
	_set_inst("inst_dirt", _vrr(float(dirt[0]), float(dirt[1])))
	var fbm: Dictionary = va.get("frost_by_map", {})
	var fr: Array = kit.get("frost", fbm.get(String(GameState.map_id), fbm.get("default", [0.0, 0.2])))   # T-192: a kit's own (the Returned's ice)
	_frost_base = _vrr(float(fr[0]), float(fr[1]))
	_set_inst("inst_frost", _frost_base)
	_set_inst("inst_fuel", 0.0)
	_apply_look()
	# posture trait, locomotion clip and the cadence
	_roll_posture()
	_pick_locomotion()


## T-269: the outfit's colours and the dead skin (ZombieWardrobe), as instance parameters of the two shared
## materials. From the net id and the spawn health, both on every peer: a co-op puppet is dressed like the host's
## zombie and nothing is sent. Only plain Gangers are dressed; a special keeps its kit's own look.
func _apply_look() -> void:
	var params: Dictionary = {}
	_outfit = ""
	if enemy_id == &"ganger":
		var id: int = net_id if net_id >= 0 else int(get_instance_id() % 1000003)
		var look: int = ZombieWardrobe.look_seed(id, max_hp)
		params = ZombieWardrobe.look_params(String(GameState.map_id), _variant, look)
		if not params.is_empty():
			_outfit = ZombieWardrobe.outfit_name(String(GameState.map_id), _variant, look)
			# the map's rime was tuned on pale cloth; on a colour it reads as white mould (wear.frost_scale)
			_frost_base *= ZombieWardrobe.frost_scale()
			_set_inst("inst_frost", _frost_base)
	if params.is_empty():
		params = ZombieWardrobe.neutral_params()
	for key: String in params.keys():
		_set_inst(key, params[key])
	# a gear piece made for this activation has none of the values _set_inst found unchanged
	for g: MeshInstance3D in _gear:
		if g.visible:
			for key: String in _inst.keys():
				g.set_instance_shader_parameter(key, _inst[key])


var _outfit: String = ""
var _look_rng: RandomNumberGenerator = null


func _vr() -> float:
	return _look_rng.randf() if _look_rng != null else randf()


func _vrr(a: float, b: float) -> float:
	return _look_rng.randf_range(a, b) if _look_rng != null else randf_range(a, b)


## The wardrobe outfit this body wears ("" = its kit's own colours).
func outfit_name() -> String:
	return _outfit


## The per-instance shader parameters of this body (a severed piece carries the same ones: ZombieGore).
func instance_look() -> Dictionary:
	return _inst


func _roll_posture() -> void:
	var w: Dictionary = _anim["postures"]["weights"]
	var total: float = 0.0
	for k: String in w.keys():
		total += float(w[k])
	var roll: float = randf() * total
	var posture: String = "none"
	for k: String in w.keys():
		roll -= float(w[k])
		if roll <= 0.0:
			posture = k
			break
	var amt: Array = _anim["postures"].get("amount", [0.6, 1.0])
	set_posture(posture, randf_range(float(amt[0]), float(amt[1])))


## Fixes the posture trait (a postures clip name, or "none") at `amount` of the additive layer: the authored
## characters (Bellringer, the Screamer) keep theirs instead of the random roll.
func set_posture(posture: String, amount: float) -> void:
	if _posture_node == null:
		return
	_posture_node.animation = StringName("posture_none" if posture == "none" else posture)
	_tree.set("parameters/Posture/add_amount", 0.0 if posture == "none" else amount)


func _pick_locomotion() -> void:
	var loco: Dictionary = _anim["clips"]["locomotion"]
	var key: String = String(tier) if loco.has(String(tier)) else "walk"
	_loco_clip = str(_pick(ZombieClips.locomotion_clips(key)))
	_loco_speed = ZombieClips.stride_speed(_loco_clip, key)
	_cycle_len = ZombieClips.length_of(_loco_clip)
	(_loco_bs.get_blend_point_node(0) as AnimationNodeAnimation).animation = StringName(str(_pick(ZombieClips.idle_clips())))
	for i: int in 3:
		var clip: String = _loco_clip if i == 0 else _loco_clip + ("_lean_l" if i == 1 else "_lean_r")
		# Imported performances have no fabricated lean versions. Preserve their original motion.
		(_loco_bs.get_blend_point_node(1 + i) as AnimationNodeAnimation).animation = StringName(clip if ZombieClips.has_clip(clip) else _loco_clip)
	var crawl: String = str(_pick(loco["crawl"]))
	(_crawl_bs.get_blend_point_node(1) as AnimationNodeAnimation).animation = StringName(crawl)


func _pick(arr: Array) -> Variant:
	return arr[randi() % arr.size()]


## T-091 tools (lineups, captures): forces the body's kit / build / sex after activation.
func debug_set_body(kit: String, build: String, female: bool) -> void:
	_variant = kit
	_build = build
	_female = female
	_body.mesh = ZombieBody.build_skinned(kit, build, female)


## Shows the variant's extra pieces (crystal plates, lantern) and adjusts the body.
func _apply_kind() -> void:
	(_kind_nodes["glass"] as Node3D).visible = enemy_id == &"glasshide"
	(_kind_nodes["glass_arm"] as Node3D).visible = enemy_id == &"glasshide"
	(_kind_nodes["lantern"] as Node3D).visible = enemy_id == &"bellringer"
	(_kind_nodes["suit"] as Node3D).visible = enemy_id == &"suited"
	(_kind_nodes["visor_crack"] as Node3D).visible = false
	_lantern_light.light_energy = 1.6 if enemy_id == &"bellringer" else 0.0
	match enemy_id:
		&"suited":
			_pivot.scale = Vector3.ONE * 1.05
			set_posture("none", 0.0)
		&"bellringer":
			_body.mesh = ZombieBody.build_skinned("bellringer", "thin", false)
			_variant = "bellringer"
			_build = "thin"
			_female = false
			_pivot.scale = Vector3.ONE * 1.04
			set_posture("hunch", 0.9)
		&"glasshide":
			_body.set_surface_override_material(0, ZombieBody.skin_material("glass"))
			_pivot.scale = Vector3.ONE * 1.1
	_mats["skin"] = ZombieBody.material(_variant, "skin")
	_mats["coat"] = ZombieBody.material(_variant, "cloth")


func _build_kind_parts() -> void:
	var glass: Node3D = Node3D.new()
	glass.name = "GlassPlates"
	bone_attachment("Chest").add_child(glass)
	var crystal: Array = []
	# chest plates and a jagged cluster growing out of one shoulder (reads at 30 m)
	for k: int in 6:
		var fx: float = -0.12 + 0.05 * float(k)
		crystal.append(ZombieBody._box(Vector3(0.11, 0.16 + 0.03 * float(k % 3), 0.03), Vector3(fx, 0.12 + 0.03 * float(k % 2), -0.125),
			"crystal", Vector3(0.25 + 0.1 * float(k % 2), 0.3 * (float(k % 3) - 1.0), 0.4 * (float(k % 2) - 0.5))))
	for k2: int in 4:
		crystal.append(ZombieBody._cyl(0.0, 0.04, 0.2, Vector3(-0.1 + 0.07 * float(k2), 0.2, 0.12), "crystal", Vector3(-1.1, 0, 0.3 * (float(k2) - 1.5)), Vector3.ONE, 4))
	crystal.append(ZombieBody._cyl(0.0, 0.055, 0.5, Vector3(0.2, 0.48, 0), "crystal", Vector3(0, 0, -0.45), Vector3.ONE, 4))
	crystal.append(ZombieBody._cyl(0.0, 0.04, 0.34, Vector3(0.3, 0.4, 0.07), "crystal", Vector3(0.3, 0, -0.9), Vector3.ONE, 4))
	crystal.append(ZombieBody._cyl(0.0, 0.035, 0.3, Vector3(0.12, 0.43, -0.09), "crystal", Vector3(-0.4, 0, -0.2), Vector3.ONE, 4))
	crystal.append(ZombieBody._cyl(0.0, 0.03, 0.24, Vector3(-0.06, 0.3, 0.16), "crystal", Vector3(-0.9, 0, 0.3), Vector3.ONE, 4))
	var gm: MeshInstance3D = MeshInstance3D.new()
	gm.mesh = ZombieBody.build_mesh("_", crystal)
	glass.add_child(gm)
	_kind_nodes["glass"] = glass
	var glass_arm: Node3D = Node3D.new()
	bone_attachment("RightLowerArm").add_child(glass_arm)
	var gm2: MeshInstance3D = MeshInstance3D.new()
	gm2.mesh = ZombieBody.build_mesh("_", [
		ZombieBody._cyl(0.0, 0.035, 0.22, Vector3(0.04, -0.12, 0), "crystal", Vector3(0, 0, -1.1), Vector3.ONE, 4),
		ZombieBody._cyl(0.0, 0.03, 0.18, Vector3(-0.03, -0.18, -0.03), "crystal", Vector3(0.8, 0, 0.9), Vector3.ONE, 4)])
	glass_arm.add_child(gm2)
	_kind_nodes["glass_arm"] = glass_arm
	var lantern: Node3D = Node3D.new()
	lantern.name = "Lantern"
	lantern.position = Vector3(0, -0.06, -0.02)
	bone_attachment("RightHand").add_child(lantern)
	var lm: MeshInstance3D = MeshInstance3D.new()
	lm.mesh = ZombieBody.build_mesh("_", [
		ZombieBody._box(Vector3(0.012, 0.12, 0.012), Vector3(0, -0.03, 0), "metal"),
		ZombieBody._cyl(0.06, 0.07, 0.03, Vector3(0, -0.1, 0), "metal", Vector3.ZERO, Vector3.ONE, 8),
		ZombieBody._cyl(0.055, 0.055, 0.15, Vector3(0, -0.19, 0), "lens", Vector3.ZERO, Vector3.ONE, 8),
		ZombieBody._cyl(0.07, 0.065, 0.03, Vector3(0, -0.28, 0), "metal", Vector3.ZERO, Vector3.ONE, 8)])
	lantern.add_child(lm)
	var flame: MeshInstance3D = Interactable.add_box(lantern, Vector3(0.04, 0.07, 0.04), Vector3(0, -0.19, 0), Interactable.greybox_mat(Color(1.0, 0.65, 0.25), 6.0))
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lantern_light = OmniLight3D.new()
	_lantern_light.light_color = Color(1.0, 0.7, 0.35)
	_lantern_light.omni_range = 6.0
	_lantern_light.light_energy = 0.0
	_lantern_light.shadow_enabled = false
	_lantern_light.position = Vector3(0, -0.19, 0)
	lantern.add_child(_lantern_light)
	_kind_nodes["lantern"] = lantern
	# the Suited's suit (T-112): a helmet over the head, the pack on the back, the visor's crack shown once hit
	var suit: Node3D = Node3D.new()
	suit.name = "Suit"
	bone_attachment("Head").add_child(suit)
	var sm: MeshInstance3D = MeshInstance3D.new()
	sm.mesh = ZombieBody.build_mesh("_", [
		ZombieBody._cyl(0.17, 0.19, 0.3, Vector3(0, 0.06, 0), "lens", Vector3.ZERO, Vector3.ONE, 12),
		ZombieBody._cyl(0.2, 0.2, 0.04, Vector3(0, -0.1, 0), "metal", Vector3.ZERO, Vector3.ONE, 12)])
	suit.add_child(sm)
	_kind_nodes["suit"] = suit
	var pack: Node3D = Node3D.new()
	bone_attachment("Chest").add_child(pack)
	var pm: MeshInstance3D = MeshInstance3D.new()
	pm.mesh = ZombieBody.build_mesh("_", [ZombieBody._box(Vector3(0.3, 0.4, 0.14), Vector3(0, 0.12, 0.17), "metal")])
	pack.add_child(pm)
	pack.visible = false
	suit.visibility_changed.connect(func() -> void: pack.visible = suit.visible)
	var crack: Node3D = Node3D.new()
	crack.name = "VisorCrack"
	crack.visible = false
	suit.add_child(crack)
	var cm: MeshInstance3D = MeshInstance3D.new()
	cm.mesh = ZombieBody.build_mesh("_", [
		ZombieBody._box(Vector3(0.012, 0.16, 0.012), Vector3(0.03, 0.08, -0.19), "crystal", Vector3(0, 0, 0.4)),
		ZombieBody._box(Vector3(0.012, 0.1, 0.012), Vector3(-0.04, 0.05, -0.19), "crystal", Vector3(0, 0, -0.7))])
	crack.add_child(cm)
	_kind_nodes["visor_crack"] = crack


## A burst of glass shards (Glasshide shatter, Bellringer death, portal). Presentation only.
## Nachtglas shatter burst (T-095: the pooled one in Effects, no per-death particle node).
func _shards(color: Color, amount: int, speed_max: float) -> void:
	if get_parent() == null:
		return
	Effects.shatter(global_position + Vector3.UP * 1.1, color, amount, speed_max)


func _death_burst() -> void:
	match enemy_id:
		&"glasshide":
			_shards(Color(0.6, 0.3, 1.0), 40, 6.0)
			AudioDirector.play_3d("glasshide_shatter", global_position + Vector3.UP, 2.0)
			# Flying shards hurt nearby Gangers a little (never players). Host-side only.
			if director != null and not puppet:
				for z: Zombie in (director as ZombieDirector).active_zombies():
					if z != self and z.enemy_id == &"ganger" and z.global_position.distance_to(global_position) <= float(_cfg.get("shatter_radius", 1.5)):
						z.take_damage(float(_cfg.get("shatter_damage", 50)), &"torso", &"glass_shard", 0, &"world")
		&"bellringer":
			_shards(Color(1.0, 0.65, 0.3), 24, 4.0)
			_lantern_light.light_energy = 0.0
			AudioDirector.play_3d("glasshide_shatter", global_position + Vector3.UP, -6.0)   # the lantern breaks


## The violet flash of a fog portal opening.
func _portal_flash() -> void:
	var host: Node = get_parent()
	if host == null:
		return
	var l: OmniLight3D = OmniLight3D.new()
	l.light_color = Color(0.65, 0.3, 1.0)
	l.omni_range = 7.0
	l.light_energy = 5.0
	host.add_child(l)
	l.global_position = global_position + Vector3.UP * 1.2
	var tw: Tween = l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.8)
	tw.tween_callback(l.queue_free)
	_shards(Color(0.6, 0.3, 1.0), 16, 3.0)
	AudioDirector.play_3d("bellringer_lantern", global_position + Vector3.UP * 1.2, 4.0)


func _set_crawl_pose(crawl: bool) -> void:
	var cap: CapsuleShape3D = _collision.shape as CapsuleShape3D
	if crawl:
		for hb: Hitbox in _hitboxes:
			if hb.limb == &"legs":
				hb.collision_layer = 0
		cap.height = 0.7
		cap.radius = 0.3
		_collision.position = Vector3(0, 0.35, 0)
	else:
		cap.height = 1.75
		_collision.position = Vector3(0, 0.875, 0)


# ---------------------------------------------------------------- gore (presentation only)

func _pop_head() -> void:
	if _head_popped:
		return
	_head_popped = true
	_pop_head_fx()


## T-283 item 7: the deaths' cosmetic work queue. Each entry is [zombie, its life, kind, args, the frame it was queued
## in]; a frame drains up to FX_PER_FRAME entries queued in an earlier frame (the first active zombie to run its
## _process drains it). An entry whose body has been put back in the pool since (its life changed) is dropped.
const FX_PER_FRAME: int = 4
const RAGDOLLS_PER_TICK: int = 3
static var _fx_q: Array = []
static var _fx_frame: int = -1
static var _rag_tick: int = -1
static var _rag_n: int = 0
static var fx_deferred: int = 0   # entries queued (perf tools, tests)
static var ragdolls_waited: int = 0   # ticks a ragdoll waited for its slot
var _life: int = 0


func _queue_death_fx(kind: StringName, args: Array) -> void:
	fx_deferred += 1
	_fx_q.append([self, _life, kind, args, Engine.get_process_frames()])


static func drain_death_fx(budget: int = FX_PER_FRAME) -> int:
	var f: int = Engine.get_process_frames()
	var done: int = 0
	while not _fx_q.is_empty() and done < budget:
		var e: Array = _fx_q[0]
		if int(e[4]) >= f:
			break   # queued this frame: from the next one on
		_fx_q.pop_front()
		var z: Zombie = e[0] as Zombie if is_instance_valid(e[0]) else null
		if z == null or z._life != int(e[1]) or z.state != State.DEAD:
			continue
		done += 1
		var args: Array = e[3]
		match e[2]:
			&"groan":
				AudioDirector.play_3d("zombie_death", args[0], -1.0)
			&"pop":
				z._pop_head_fx()
			&"sever":
				ZombieGore.sever(z, str(args[0]), args[1])
	return done


static func pending_death_fx() -> int:
	return _fx_q.size()


## May a ragdoll start in this physics tick? (RAGDOLLS_PER_TICK a tick with t283_death; always without.)
func _ragdoll_slot() -> bool:
	if not (t283_opt and t283_death):
		return true
	var tick: int = Engine.get_physics_frames()
	if tick != _rag_tick:
		_rag_tick = tick
		_rag_n = 0
	if _rag_n >= RAGDOLLS_PER_TICK:
		ragdolls_waited += 1
		return false
	_rag_n += 1
	return true


## The head pop's presentation: the gib sound, the severed head, the neck's burst and spurt.
func _pop_head_fx() -> void:
	AudioDirector.play_3d("zombie_gib", global_position + Vector3.UP * 1.7)
	var away: Vector3 = _away_from_target()
	ZombieGore.sever(self, "Head", Vector3(away.x * 3.0, 4.5, away.z * 3.0))
	if ZombieGore.blood_allowed():
		var at: Node3D = bone_attachment("Neck")
		var p: Vector3 = at.global_position if at != null else global_position + Vector3.UP * 1.6
		Effects.gore_burst(p, Vector3(randf_range(-0.3, 0.3), 1.0, randf_range(-0.3, 0.3)), true)
		Effects.gore.spurt(at)   # the neck keeps pumping (gore rework)


## A wound decal on the struck limb (cheap quads, recycled per zombie).
func _wound(limb: StringName, side: String = "") -> void:
	if ZombieGore.level() == "off":
		return
	var choices: Array = []
	match limb:
		&"head":
			choices = ["Head"]
		&"neck":
			choices = ["Neck"]
		&"torso":
			choices = ["Chest", "Spine"]
		&"arms":
			choices = ["LeftUpperArm", "LeftLowerArm"] if side == "l" else ["RightUpperArm", "RightLowerArm"]
		&"legs":
			choices = ["LeftUpperLeg", "LeftLowerLeg"] if side == "l" else ["RightUpperLeg", "RightLowerLeg"]
		_:
			choices = ["Chest"]
	var bone_name: String = str(choices[randi() % choices.size()])
	var bone: Node3D = bone_attachment(bone_name)
	if bone == null:
		return
	var d: MeshInstance3D
	if _decals.size() < 6:
		d = MeshInstance3D.new()
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2.ONE
		d.mesh = q
		d.material_override = ZombieBody.blood_material()
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_decals.append(d)
	else:
		d = _decals[_decal_i % _decals.size()]
		_decal_i += 1
	if d.get_parent() != bone:
		if d.get_parent() != null:
			d.get_parent().remove_child(d)
		bone.add_child(d)
	var a: float = randf() * TAU
	var up: bool = bone_name in ["Chest", "Spine", "Head", "Neck"]
	var r: float = 0.14 if bone_name == "Chest" else (0.12 if bone_name == "Head" else 0.07)
	var y: float = randf_range(0.05, 0.25) if up else -randf_range(0.05, 0.35)
	var out: Vector3 = Vector3(cos(a), 0, sin(a))
	d.position = out * r + Vector3(0, y, 0)
	d.basis = Basis.looking_at(-out, Vector3.UP).scaled(Vector3.ONE * randf_range(0.07, 0.15))
	d.show()


# ---------------------------------------------------------------- animation (AnimationTree parameters)

func _tree_play(st: String, clip: String, time_scale: float) -> void:
	if _tree == null or _playback == null:
		return
	if _anim_nodes.has(st):
		(_anim_nodes[st] as AnimationNodeAnimation).animation = StringName(ZombieClips.visual_clip(clip))
	_tree.set("parameters/SM/%s/TimeScale/scale" % st, maxf(0.01, time_scale))
	# One-shot states share one AnimationNodeAnimation per state; travel() to the state already playing restarts
	# it from 0 in Godot 4.7 (reset_on_teleport), so a swapped clip (knockdown -> get-up, climb loop -> mantle)
	# starts at its first frame. test_zombie_mz_fixes guards that engine behaviour.
	_playback.travel(st)
	_tree_state = st
	_cycle = 0.0
	_step_phase_valid = false


var _attack_visual_hit_done: bool = false


func _tree_attack(clip: String) -> void:
	_attack_visual_hit_done = false
	_tree.set("parameters/SM/Attack/Anim/blend_position", ZombieClips.attack_index(clip))
	var hit: float = ZombieClips.hit_event_time(clip)
	_tree_play("Attack", clip, (hit if hit >= 0.0 else ZombieClips.ATTACK_WINDUP) / maxf(0.05, float(_cfg["attack_windup"])))


func _tree_emerge() -> void:
	var em: Dictionary = _anim["clips"]["emerge"]
	var e: Dictionary = _anim["emerge"]
	match _emerge_kind:
		"portal":
			_emerge_clip = str(em["portal"])
			_emerge_secs = float(e["portal_seconds"])
		"ceiling":
			_emerge_clip = str(em["ceiling"])
			_emerge_secs = float(e["ceiling_seconds"])
		"water":
			_emerge_clip = str(em["water"])
			_emerge_secs = float(e["water_seconds"])
		_:
			_emerge_begin_variant(ZombieEmerge.pick(emerge_rng(), tier, is_crawler))
			return
	_tree_play("Emerge", _emerge_clip, ZombieClips.length_of(_emerge_clip) / maxf(0.05, _emerge_secs))


## How long this rise takes: a ground variant's seconds times the round multiplier (ZombieEmerge), the other
## kinds anim.json emerge.
func _emerge_seconds() -> float:
	return _emerge_secs


# ---------------------------------------------------------------- the rise from the ground (T-085)

## Starts (or restarts) a staged ground rise with `variant`: the clip, its round-scaled length, the surface class
## under the spawn, the stage cursor, the hitboxes off until "head_out" and the mound at the spawn.
func _emerge_begin_variant(variant: String) -> void:
	_emerge_variant = variant
	_emerge_clip = ZombieEmerge.clip_for(variant)
	_emerge_secs = ZombieEmerge.variant_seconds(variant) * ZombieEmerge.round_multiplier(RoundManager.current_round)
	_emerge_stage_i = 0
	_emerge_dig_t = 0.0
	if _staged_emerge():
		_emerge_surface = _emerge_surface_at()
		_set_emerge_hitboxes(false)
		_mound_show(true)
		_emerge_mound_update(0.0)
	_tree_play("Emerge", _emerge_clip, ZombieClips.length_of(_emerge_clip) / maxf(0.05, _emerge_secs))


## True when the rise is the staged ground dig-out (the shared rig exists; the bosses' own bodies and the portal /
## chute / wade kinds keep their simple timing).
func _staged_emerge() -> bool:
	return has_rig() and _emerge_kind == "ground"


## Normalized progress of the rise (0..1).
func _emerge_k() -> float:
	return clampf(_state_t / maxf(0.05, _emerge_secs), 0.0, 1.0)


## True once a rising zombie's head is out (it looks at its prey from here; its hitboxes are live from here).
func _emerge_head_out() -> bool:
	return state == State.EMERGE and _staged_emerge() and _emerge_k() >= ZombieEmerge.stage(_emerge_variant, "head_out", 0.4)


func emerge_variant() -> String:
	return _emerge_variant


func emerge_surface() -> String:
	return _emerge_surface


## The pool's variant draw, re-seeded from the match seed (QuestManager) whenever a new match starts.
static func emerge_rng() -> RandomNumberGenerator:
	var seed_now: int = QuestManager.match_seed
	if _emerge_seed != seed_now:
		_emerge_seed = seed_now
		_emerge_rng.seed = hash("emerge:%d" % seed_now)
	return _emerge_rng


## Per frame while rising (host and puppet): fires each stage's effects once as its time passes, keeps the mound
## in step, and scrapes while a hand rakes the rim.
func _emerge_tick(delta: float) -> void:
	if not _staged_emerge():
		return
	var k: float = _emerge_k()
	var list: Array = ZombieEmerge.stage_list(_emerge_variant)
	while _emerge_stage_i < list.size() and k >= float((list[_emerge_stage_i] as Array)[1]):
		_emerge_stage_fx(str((list[_emerge_stage_i] as Array)[0]), false)
		_emerge_stage_i += 1
	_emerge_mound_update(k)
	var hand: float = ZombieEmerge.stage(_emerge_variant, "hand", 0.1)
	var head: float = ZombieEmerge.stage(_emerge_variant, "head_out", 0.4)
	var pause: float = ZombieEmerge.stage(_emerge_variant, "pause", -1.0)
	var heave2: float = ZombieEmerge.stage(_emerge_variant, "heave2", -1.0)
	var clawing: bool = (k >= hand and k < head) or (pause > 0.0 and k >= pause and k < heave2)
	if clawing:
		_emerge_dig_t -= delta
		if _emerge_dig_t <= 0.0:
			var every: Array = (ZombieEmerge.cfg().get("effects", {}) as Dictionary).get("dig_every", [0.18, 0.3])
			_emerge_dig_t = randf_range(float(every[0]), float(every[1]))
			_emerge_sound("dig", -2.0, 60)


## One stage's spray, sound and gameplay switch. `silent` (a seek) applies the switches and skips the show.
func _emerge_stage_fx(stage: String, silent: bool) -> void:
	var fx: Dictionary = ZombieEmerge.cfg().get("effects", {})
	var n: int = int((fx.get("spray", {}) as Dictionary).get(stage, 0))
	match stage:
		"head_out":
			_set_emerge_hitboxes(true)
		"done":
			_mound_show(false)
	if silent:
		return
	match stage:
		"hand":
			_emerge_spray(_emerge_point("RightHand", 0.1), n, 1.0, Vector3.UP)
			_emerge_sound("burst", 0.0)
		"hand2":
			_emerge_spray(_emerge_point("LeftHand", 0.1), maxi(4, n / 2), 0.8, Vector3.UP)
			_emerge_sound("burst", -4.0)
		"head_out":
			_emerge_spray(_emerge_point("Head", 0.15), n, 1.3, Vector3.UP)
			_emerge_sound("burst", -1.0)
			_emerge_sound("heave", -2.0)
		"shoulders":
			# clumps falling off the shoulders: slow, low, outward
			_emerge_spray(_emerge_point("LeftUpperArm", 0.05), n, 0.4, Vector3(-0.5, 0.5, 0.2))
			_emerge_spray(_emerge_point("RightUpperArm", 0.05), n, 0.4, Vector3(0.5, 0.5, 0.2))
		"elbow":
			_emerge_spray(_emerge_point("LeftLowerArm", 0.05), n, 0.45, Vector3(-0.3, 0.7, 0.0))
		"knee":
			_emerge_spray(_emerge_point("RightLowerLeg", 0.05), n, 0.45, Vector3(0.3, 0.7, -0.3))
		"heave2":
			_emerge_spray(_emerge_point("Chest", 0.2), n, 1.1, Vector3.UP)
			_emerge_sound("burst", -3.0)
			_emerge_sound("heave", -1.0)
		"flat":
			_emerge_spray(global_position + Vector3.UP * 0.1, n, 0.5, Vector3(0, 0.5, -0.8))
		"stand":
			if _emerge_in_range():
				Effects.dust_puff(global_position + Vector3.UP * 0.05, _emerge_surface, n)
			_emerge_sound("settle", 0.0)


## A bone's world position lifted to at least the ground (the spray starts at the surface, never from under it).
func _emerge_point(bone: String, lift: float) -> Vector3:
	var at: Node3D = bone_attachment(bone)
	var p: Vector3 = at.global_position if at != null else global_position + Vector3.UP * 0.5
	p.y = maxf(p.y, global_position.y + 0.02) + lift
	return p


## Effects are for the players nearby (enemies.json emerge.effects.range_m from this zombie's target).
func _emerge_in_range() -> bool:
	if target == null:
		return true
	var r: float = float((ZombieEmerge.cfg().get("effects", {}) as Dictionary).get("range_m", 24.0))
	return global_position.distance_squared_to(target.global_position) <= r * r


func _emerge_spray(pos: Vector3, n: int, strength: float, dir: Vector3) -> void:
	if n > 0 and _emerge_in_range():
		Effects.dirt_burst(pos, _emerge_surface, strength, dir, n)


## A rise cue by surface class (enemies.json emerge.sounds -> audio.json keys); `gap_ms` rate-caps it horde-wide.
func _emerge_sound(cue: String, db: float, gap_ms: int = 0) -> void:
	var key: String = ZombieEmerge.sound_key(cue, _emerge_surface)
	if key == "" or not _emerge_in_range():
		return
	if gap_ms > 0:
		var now: int = Time.get_ticks_msec()
		if now - _last_dig_msec < gap_ms:
			return
		_last_dig_msec = now
	AudioDirector.play_3d(key, global_position + Vector3.UP * 0.3, db, 0.0)


## The hitboxes wait for the head to be out: a rising zombie can be shot from the moment its head shows, never
## through the ground before. Crawlers keep their leg boxes off.
func _set_emerge_hitboxes(on: bool) -> void:
	_emerge_hitboxes_off = not on
	for hb: Hitbox in _hitboxes:
		if on and is_crawler and hb.limb == &"legs":
			continue
		hb.collision_layer = Hitbox.LAYER_HITBOX if on else 0
	_marke_layers(on)


## Spawned as a crawler (spec "crawler": true): the legs are gone from the start (no gib sound, no pieces) and
## it rises on its elbows (ZombieEmerge "crawler").
func _spawn_as_crawler() -> void:
	is_crawler = true
	for leg: String in ["LeftUpperLeg", "RightUpperLeg"]:
		ZombieGore.sever(self, leg, Vector3.ZERO, false)
	_set_crawl_pose(true)


## The bulge at the spawn and the broken ring under it (shared meshes and per-surface materials, ZombieEmerge).
func _mound_show(on: bool) -> void:
	if not on:
		if _mound != null:
			_mound.hide()
			_hole.hide()
		return
	if _mound == null:
		_mound = MeshInstance3D.new()
		_mound.name = "Mound"
		_mound.mesh = ZombieEmerge.mound_mesh()
		_mound.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_mound)
		_hole = MeshInstance3D.new()
		_hole.name = "Hole"
		_hole.mesh = ZombieEmerge.hole_mesh()
		_hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_hole.position = Vector3(0, 0.012, 0)
		add_child(_hole)
	_mound.material_override = ZombieEmerge.mound_material(_emerge_surface)
	_hole.material_override = ZombieEmerge.hole_material(_emerge_surface)
	_mound.scale = Vector3.ONE * 0.001
	_mound.show()
	_hole.hide()


## Mound shape by rise progress: it swells (trembling) until the first hand breaks it, collapses to a thrown-up
## rim, and the dark broken ring shows from then on.
func _emerge_mound_update(k: float) -> void:
	if _mound == null or not _mound.visible:
		return
	var fx: Dictionary = ZombieEmerge.cfg().get("effects", {})
	var radius: float = float(fx.get("mound_radius", 0.55))
	var height: float = float(fx.get("mound_height", 0.14))
	var hand: float = ZombieEmerge.stage(_emerge_variant, "hand", 0.1)
	var shoulders: float = ZombieEmerge.stage(_emerge_variant, "shoulders", ZombieEmerge.stage(_emerge_variant, "elbow", hand + 0.3))
	if k < hand:
		var s: float = k / maxf(0.01, hand)
		s = s * s * (3.0 - 2.0 * s)
		var tremble: float = 1.0 + 0.08 * s * sin(_state_t * 25.0)
		var r: float = maxf(0.001, radius * (0.4 + 0.6 * s))
		_mound.scale = Vector3(r, maxf(0.001, height * s * tremble), r)
		_hole.hide()
	else:
		var f: float = clampf((k - hand) / maxf(0.01, shoulders - hand), 0.0, 1.0)
		_mound.scale = Vector3(radius * 1.1, height * lerpf(0.4, 0.25, f), radius * 1.1)
		var hr: float = float(fx.get("hole_radius", 0.4))
		_hole.scale = Vector3(hr, 1.0, hr)
		_hole.show()


## Decides, before the death starts, whether this kill happened mid-rise: then the body slides back into the
## ground instead of playing a death clip (the mound stays until it is under).
func _mark_death_sink() -> void:
	_death_sink = state == State.EMERGE and _staged_emerge() and _emerge_k() < ZombieEmerge.stage(_emerge_variant, "stand", 0.9)
	if _death_sink:
		var speed: float = float(ZombieEmerge.cfg().get("death_sink_speed", 1.6))
		_sink_corpse_s = _emerge_k() * _emerge_secs / maxf(0.2, speed) + 0.4


## The Emerge clip runs backward from where it was (no travel: the state machine stays on Emerge).
func _emerge_sink_back() -> void:
	if _tree == null:
		return
	var speed: float = float(ZombieEmerge.cfg().get("death_sink_speed", 1.6))
	_tree.set("parameters/SM/Emerge/TimeScale/scale", -(ZombieClips.length_of(_emerge_clip) / maxf(0.05, _emerge_secs)) * speed)
	_tree_state = "Emerge"
	if _emerge_in_range():
		Effects.dust_puff(global_position + Vector3.UP * 0.05, _emerge_surface)
	_emerge_sound("settle", -2.0)


## Swaps the variant mid-rise at the same progress (legs blown off while rising: it finishes on its elbows).
func _emerge_switch_variant(variant: String) -> void:
	var k: float = _emerge_k()
	_emerge_begin_variant(variant)
	_state_t = k * _emerge_secs
	_tree_seek(_state_t)
	_emerge_catch_up(k, false)


## Applies the switches of every stage up to `k` without their show; with `fx`, the last one's show too.
func _emerge_catch_up(k: float, fx: bool) -> void:
	var list: Array = ZombieEmerge.stage_list(_emerge_variant)
	var last: String = ""
	while _emerge_stage_i < list.size() and k >= float((list[_emerge_stage_i] as Array)[1]):
		last = str((list[_emerge_stage_i] as Array)[0])
		_emerge_stage_fx(last, true)
		_emerge_stage_i += 1
	if fx and last != "":
		_emerge_stage_fx(last, false)
	_emerge_mound_update(k)


## Advances the tree `seconds` into the state just travelled to, in small steps (one big step can skip the travel).
func _tree_seek(seconds: float) -> void:
	if _tree == null:
		return
	_tree.advance(0.0)
	var left: float = seconds
	while left > 0.0:
		var d: float = minf(left, 0.05)
		_tree.advance(d)
		left -= d


## Tools and tests: parks a ground rise of `variant` at normalized time `k` (round multiplier 1) with the stage
## switches applied (hitboxes, mound) and, with `fx`, the effects of the last stage reached.
func debug_emerge_seek(variant: String, k: float, fx: bool = false) -> void:
	if not has_rig():
		return
	_emerge_kind = "ground"
	state = State.EMERGE
	_emerge_begin_variant(variant)
	_emerge_secs = ZombieEmerge.variant_seconds(variant)
	_tree.set("parameters/SM/Emerge/TimeScale/scale", 1.0)
	_state_t = clampf(k, 0.0, 1.0) * _emerge_secs
	_tree_seek(_state_t)
	_emerge_catch_up(clampf(k, 0.0, 1.0), fx)


## Spawn kind -> emerge clip family: Bellringers step out of portals; a spawn's name prefix can pick the chute
## drop or the wade-up (anim.json emerge_by_spawn_prefix per map).
func _emerge_kind_for(spawn: ZombieSpawn) -> String:
	if enemy_id == &"bellringer":
		return "portal"
	var by: Dictionary = (_anim.get("emerge_by_spawn_prefix", {}) as Dictionary).get(String(GameState.map_id), {})
	for prefix: String in by.keys():
		if spawn.name.begins_with(prefix):
			return str(by[prefix])
	return "ground"


func _tree_locomotion(force: bool = false) -> void:
	var st: String = "Crawl" if is_crawler else "Locomotion"
	if _playback == null:
		return
	if _tree_state != st or force:
		_playback.travel(st)
		_tree_state = st


func _random_phase() -> void:
	# Queue the phase until the state machine has actually entered its gait. Ground
	# spawns begin in Emerge, so advancing the tree here used to consume the random
	# offset on the emerge clip and leave every first chase gait in sync.
	if _tree == null or not bool(_anim["random_phase"]):
		return
	var phase: float = randf()
	_cycle = phase
	_tree.set("parameters/SM/Locomotion/TimeSeek/seek_request", phase * _cycle_len)
	var crawl_node: AnimationNodeAnimation = _crawl_bs.get_blend_point_node(1) as AnimationNodeAnimation
	_tree.set("parameters/SM/Crawl/TimeSeek/seek_request", phase * ZombieClips.length_of(String(crawl_node.animation)))
	_step_phase_valid = false


func _pick_attack() -> String:
	var at: Dictionary = _anim["clips"]["attack"]
	if is_crawler:
		return str(at["bite"])
	var lost: int = arms_lost()
	if lost >= 2:
		return str(at["headbutt"])
	if (_anim["attack"]["grab_tiers"] as Array).has(String(tier)) and randf() < 0.5 and lost == 0:
		return str(at["grab"])
	if (_anim["attack"]["lunge_tiers"] as Array).has(String(tier)) and randf() < 0.3 and enemy_id == &"ganger":
		return str(at["lunge"])
	var swipes: Array = (at["swipe"] as Array).duplicate()
	if _severed_logic.has("LeftUpperArm") or _severed_logic.has("LeftLowerArm"):
		swipes = swipes.filter(func(s: String) -> bool: return s == "swipe_r")
	elif _severed_logic.has("RightUpperArm") or _severed_logic.has("RightLowerArm"):
		swipes = swipes.filter(func(s: String) -> bool: return s == "swipe_l")
	return str(_pick(swipes))


func _play_flinch(limb: StringName, side: String) -> void:
	if not has_rig():
		return
	var zone: String = "torso"
	var chain: int = -1
	var kick: Vector3 = Vector3.ZERO
	var imp: float = float(_anim["flinch"]["spring"].get("impulse", 0.9))
	match limb:
		&"head", &"neck":
			zone = "head"
			chain = 2
			kick = Vector3(-imp * 4.0, randf_range(-imp, imp) * 2.0, randf_range(-imp, imp) * 2.0)
		&"arms":
			zone = "arm_" + side
			chain = 0 if side == "l" else 1
			kick = Vector3(imp * 3.0, 0, (-imp if side == "l" else imp) * 4.0)
		&"legs":
			zone = "leg_" + side
		_:
			zone = "torso"
			chain = 0 if randf() < 0.5 else 1
			kick = Vector3(imp * 2.0, 0, (-imp if chain == 0 else imp) * 2.0)
	_flinch_node.animation = StringName(str(_anim["clips"]["flinch"].get(zone, "flinch_torso")))
	_tree.set("parameters/Flinch/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	if chain >= 0:
		_modifier.kick(chain, kick)
	_flinch = float(_anim["flinch"].get("seconds", 0.25))
	_flinch_dir = -1.0 if side == "l" else 1.0


## The contact lock for this frame. With the body modifier running it is handed to it and applied LAST, on the pose
## after the terrain IK and the foot tilt (ZombieBodyModifier); with the modifier off (a far body) it runs here.
func _lock_feet(clip: String, time: float, dt: float, cfg: Dictionary) -> void:
	if _modifier.active and _modifier.is_inside_tree():
		_modifier.lock = _contact_lock
		_modifier.lock_clip = clip
		_modifier.lock_time = time
		_modifier.lock_dt = dt
		_modifier.lock_cfg = cfg
		_modifier.lock_fresh = true
		_modifier.lock_on = true
	else:
		_modifier.lock_on = false
		_contact_lock.apply(_skel, _modifier, clip, time, dt, cfg)


const _TURN_STATES: Array = [State.CHASE, State.TO_WINDOW]
## T-281: the per-frame state tests' lists, built once (an inline list is a new array at every call)
const _MOVING_STATES: Array = [State.CHASE, State.TO_WINDOW, State.WAIT_WINDOW]
const _IK_STATES: Array = [State.CHASE, State.TO_WINDOW, State.WAIT_WINDOW, State.TEAR, State.ATTACK, State.STAGGER]
const _LOOK_STATES: Array = [State.CHASE, State.TO_WINDOW, State.WAIT_WINDOW, State.TEAR, State.ATTACK]
const _TURN_TREE_STATES: Array = ["Locomotion", "Turn"]


## Only stationary upright locomotion can yield presentation to a recorded turn.
func _can_recorded_turn() -> bool:
	return has_rig() and not is_crawler and not hopping and state in _TURN_STATES and _tree_state in _TURN_TREE_STATES and Vector2(velocity.x, velocity.z).length() < float(_anim["turn"].get("in_place_below_mps", 0.5))


## Per visual tick: tree parameters from the state and velocity, LOD-rated advance, animation events.
func _animate(dt: float) -> void:
	if state == State.INACTIVE or _tree == null or _ragdoll != null:
		return   # a ragdolling corpse: the physics bodies drive the bones (ZombieRagdoll.sync)
	anim_steps += 1
	if RoundManager.current_round != ZombieBody._crack_round:   # (T-281: the table is read only when the round changed)
		ZombieBody.update_cracks(RoundManager.current_round, float(GLData.table("enemies").get("visual", {}).get("crack_energy", 2.6)))
	var spd: float = Vector2(velocity.x, velocity.z).length()
	var moving_state: bool = state in _MOVING_STATES
	var can_turn: bool = _can_recorded_turn()
	if not can_turn: _turn_motion.cancel()
	if _turn_motion.active:
		if _tree_state != "Turn": _tree_play("Turn", _turn_motion.clip, 1.0)
	elif moving_state:
		if state == State.WAIT_WINDOW and spd < 0.2:
			if _tree_state != "Barricade":
				_tree_play("Barricade", str(_anim["clips"]["wait"]), 1.0)
		else:
			_tree_locomotion()
	if _tree_state == "Locomotion":
		var below: float = float(_anim["turn"].get("in_place_below_mps", 0.5))
		var target_x: float = 1.0 if spd > below else 0.0
		_loco_x = move_toward(_loco_x, target_x, dt * 6.0)
		var lean_t: Dictionary = _anim["turn"]["lean_tiers"]
		var lean: float = float(lean_t.get(String(tier), 0.0))
		var turn_norm: float = clampf(_turn_rate / float(_anim["turn"].get("full_turn_rate", 2.5)), -1.0, 1.0)
		var want_turn: float = turn_norm * (lean / 0.18 if spd > below else 1.0)
		if spd <= below and ZombieClips.recorded_turns_enabled(): want_turn = 0.0
		_loco_turn = move_toward(_loco_turn, want_turn if absf(turn_norm) > 0.15 else 0.0, dt * 5.0)
		_tree.set(&"parameters/SM/Locomotion/Anim/blend_position", Vector2(_loco_x, _loco_turn))
		# the clip's root motion is in rig space: the height scale on the pivot stretches every stride by that much
		var scale: float = maxf(spd, 0.15) / maxf(0.1, _loco_speed * _pivot.scale.y) if _loco_x > 0.01 else 1.0
		_tree.set(&"parameters/SM/Locomotion/TimeScale/scale", scale)
	elif _tree_state == "Crawl":
		var cx: float = clampf(spd / float(_cfg["crawler_speed"]), 0.0, 1.0)
		_tree.set(&"parameters/SM/Crawl/Anim/blend_position", cx)
		var cs: float = maxf(spd, 0.1) / (float(_anim["gait"]["crawl"]["speed"]) * _pivot.scale.y) if cx > 0.05 else 1.0
		_tree.set(&"parameters/SM/Crawl/TimeScale/scale", cs)
	_turn_rate = move_toward(_turn_rate, 0.0, dt * 8.0)
	if _flinch > 0.0:
		_flinch = maxf(0.0, _flinch - dt)
	if state == State.ATTACK and not _attack_visual_hit_done and _state_t >= float(_cfg["attack_windup"]):
		_attack_visual_hit_done = true
		var recorded_hit: float = ZombieClips.hit_event_time(_attack_clip)
		if recorded_hit >= 0.0:
			# Shared host/puppet presentation: strike at the existing windup, then retain the
			# existing 0.35 s recovery. Gameplay damage remains in the physics state callback.
			_tree.set("parameters/SM/Attack/TimeSeek/seek_request", recorded_hit)
			_tree.set("parameters/SM/Attack/TimeScale/scale", 1.0)
	_tree.advance(dt)
	if _skel.modifier_callback_mode_process == Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL:
		_skel.advance(dt)   # T-283: the modifier pass of this step, with its time (see _skel_mode_sync)
	var turn_time: float = _playback.get_current_play_position() if _playback.get_current_node() == &"Turn" else 0.0
	_pivot.rotation.y = _turn_motion.advance(rotation.y, turn_time, dt, can_turn and _tree_state == "Turn")
	if state == State.DEAD and _tree_state == "Death" and ZombieClips.visual_clip(_death_clip).begins_with("mco_"):
		# The corpse presentation follows the recorded fall before physics takes over. The pooled
		# body's nav position/hit timings are unchanged; activate()/make_puppet() reset the pivot.
		_pivot.position += _tree.get_root_motion_position() * _pivot.scale
		_record_death_velocity(dt)
	var contact_cfg: Dictionary = ZombieClips.contact_lock_config()
	# A one-tick collision stop starts the idle blend. Keep established contacts through its gait-dominant
	# part instead of dropping both pins and planting them elsewhere on the very next moving frame.
	# Entry still requires the full recorded gait; sustained stops release as the idle blend takes over.
	var retain_contacts: bool = _contact_lock.previous_clip == _loco_clip and _loco_x >= float(contact_cfg.get("retain_locomotion_blend", 0.5))
	if _loco_clip.begins_with("mco_") and _tree_state == "Locomotion":
		# Upper-body turn lean is additive to the recording and leaves planted leg motion intact.
		var lean_angle: float = _loco_turn * float(_anim["turn"]["lean_tiers"].get(String(tier), 0.0))
		for bone: String in ["Spine", "Chest"]:
			var idx: int = _skel.find_bone(bone)
			_skel.set_bone_pose_rotation(idx, _skel.get_bone_pose_rotation(idx) * Quaternion(Vector3.BACK, lean_angle * 0.5))
	if _tree_state == "Turn" and _playback.get_fading_from_node() == &"" and bool(contact_cfg.get("enabled", false)):
		_lock_feet(_turn_motion.clip, turn_time, dt, contact_cfg)
		for event: Dictionary in ZombieClips.footstep_events(_turn_motion.clip):
			var at: float = float(event["phase"]) * ZombieClips.length_of(_turn_motion.clip)
			if at > _turn_motion.previous_clock and at <= _turn_motion.clock: _footstep(bool(event["left"]))
	elif _loco_clip.begins_with("mco_") and _tree_state == "Locomotion" and _playback.get_fading_from_node() == &"" and ((_loco_x >= 0.99 and spd > 0.4) or retain_contacts) and bool(contact_cfg.get("enabled", false)):
		_lock_feet(_loco_clip, fposmod(_playback.get_current_play_position(), _cycle_len), dt, contact_cfg)
	else:
		_contact_lock.reset()
		_modifier.lock_on = false
	# Use the evaluated state's clock, including seeks, idle blends and resumes after
	# attacks. A separate integrated clock drifts away from the feet on those paths.
	if _tree_state == "Locomotion" and _playback.get_current_node() == &"Locomotion" and _loco_x > 0.5:
		var phase: float = fposmod(_playback.get_current_play_position() / _cycle_len, 1.0)
		if _step_phase_valid:
			for event: Dictionary in ZombieClips.footstep_events(_loco_clip):
				if ZombieClips.crossed_phase(_cycle, phase, float(event["phase"])):
					_footstep(bool(event["left"]))
		_cycle = phase
		_step_phase_valid = true
	else:
		_step_phase_valid = false
	# root motion bookkeeping for the foot-slide check: the clip's stride distance against the body's travel
	# over the same window, only while fully in the gait (the idle blend scales the root motion down)
	var rm: Vector3 = _tree.get_root_motion_position()
	var here: Vector3 = Vector3(global_position.x, 0, global_position.z)
	if _tree_state == "Locomotion" and _loco_x >= 0.95 and _rm_time > 0.0:
		_rm_dist += rm.length() * _pivot.scale.y
		_body_dist += (here - _rm_pos_last).length()
	elif _tree_state != "Locomotion" or _loco_x < 0.95:
		_rm_dist = 0.0
		_body_dist = 0.0
		_rm_time = 0.0
	_rm_pos_last = here
	_rm_time += dt
	if _rm_time >= 0.5:
		_rm_speed = _rm_dist / _rm_time
		_body_speed = _body_dist / _rm_time
		_rm_dist = 0.0
		_body_dist = 0.0
		_rm_time = 0.0


## Foot IK rays, look-at target and the per-distance modifier gates (physics step).
## T-281: the foot rays' last start points and hits per foot (world space), and how near a new start point must be
## to the last one to meet the same ground (5 mm; the toe's point 1 cm). The ground under a foot that moved less is
## the same ground: the map's colliders do not move under a zombie's feet. Reset with each spawn.
const FOOT_RAY_SAME_M2: float = 0.005 * 0.005
var _foot_ray_from: Array[Vector3] = [Vector3.INF, Vector3.INF]
var _toe_ray_from: Array[Vector3] = [Vector3.INF, Vector3.INF]
var _foot_hit: Array[Vector3] = [Vector3.INF, Vector3.INF]
var _toe_hit: Array[Vector3] = [Vector3.INF, Vector3.INF]
static var foot_ray_reuses: int = 0   # feet whose rays were kept (perf_marks counts them)


func _update_senses(delta: float) -> void:
	if state == State.INACTIVE or state == State.DEAD or not has_rig():
		return
	var d: float = global_position.distance_to(target.global_position) if target != null else 999.0
	var fi: Dictionary = _anim["foot_ik"]
	var la: Dictionary = _anim["look_at"]
	# (T-265: no foot rays for a body the camera does not see: four rays a tick each, and the weight eases back in
	# over a quarter of a second once it is in view again)
	var ik_on: bool = d <= float(fi["range_m"]) and not _out_of_view and is_on_floor() and state in _IK_STATES and not is_crawler
	_modifier.active = d <= float(fi["off_m"]) or _modifier.springs_active()
	if ik_on and not _anim_steps_before_next_tick():
		# T-283: no animation step before the next tick reads them; the last hits stand, the weight eases as before
		_modifier.ik_weight = move_toward(_modifier.ik_weight, 1.0, delta * 4.0)
	elif ik_on:
		foot_ray_ticks += 1
		var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		for i: int in 2:
			var fidx: int = _foot_idx[i]
			if fidx < 0:
				_modifier.foot_ground_y[i] = NAN
				_modifier.toe_ground_y[i] = NAN
				continue
			var foot_g: Vector3 = _skel.to_global(_skel.get_bone_global_pose(fidx).origin)
			var from: Vector3 = Vector3(foot_g.x, global_position.y + float(fi["ray_up"]), foot_g.z)
			var to: Vector3 = Vector3(foot_g.x, global_position.y - float(fi["ray_down"]), foot_g.z)
			var toe_g: Vector3 = _skel.to_global(_skel.get_bone_global_pose(fidx) * Vector3(0, -0.06, -0.15))
			# T-281: a foot that has not moved since its last rays (a body standing at a window, tearing, waiting)
			# meets the same ground: the two hits are kept and only taken into the skeleton's frame again
			if t281_opt and _foot_ray_from[i].distance_squared_to(from) < FOOT_RAY_SAME_M2 and _toe_ray_from[i].distance_squared_to(toe_g) < FOOT_RAY_SAME_M2 * 4.0:
				foot_ray_reuses += 1
			else:
				var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, LAYER_WORLD, [get_rid()])
				var hit: Dictionary = space.intersect_ray(q)
				_foot_hit[i] = (hit["position"] as Vector3) if not hit.is_empty() else Vector3.INF
				# the ground under the toe too: the foot is tilted by the rise between the two (ZombieBodyModifier)
				var tq: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(toe_g.x, from.y, toe_g.z), Vector3(toe_g.x, to.y, toe_g.z), LAYER_WORLD, [get_rid()])
				var toe_hit: Dictionary = space.intersect_ray(tq)
				_toe_hit[i] = (toe_hit["position"] as Vector3) if not toe_hit.is_empty() else Vector3.INF
				_foot_ray_from[i] = from
				_toe_ray_from[i] = toe_g
			_modifier.foot_ground_y[i] = _skel.to_local(_foot_hit[i]).y if _foot_hit[i] != Vector3.INF else NAN
			_modifier.toe_ground_y[i] = _skel.to_local(_toe_hit[i]).y if _toe_hit[i] != Vector3.INF else NAN
		_modifier.ik_weight = move_toward(_modifier.ik_weight, 1.0, delta * 4.0)
	else:
		_modifier.ik_weight = move_toward(_modifier.ik_weight, 0.0, delta * 4.0)
	var look_on: bool = target != null and d <= float(la["range_m"]) and (state in _LOOK_STATES or _emerge_head_out()) and not is_severed("Head")
	if look_on:
		_look_target.global_position = target.global_position + Vector3.UP * 1.6
	_look.active = look_on
	# damage-state materials: burn char builds while burning, frost crust while frosted
	_set_inst("inst_char", snappedf(_char, 0.05))
	_set_inst("inst_frost", snappedf(_frost_base + (0.5 if _frost_t > 0.0 else 0.0), 0.05))


# ---------------------------------------------------------------- audio

func _update_audio(delta: float) -> void:
	if not is_active():
		return
	_groan_t -= delta
	if _groan_t <= 0.0:
		var v: Dictionary = _anim["vocals"]
		var every: Array = v["sprint_every"] if tier == &"sprint" else v["breath_every"]
		_groan_t = randf_range(float(every[0]), float(every[1]))
		var snd: String = "zombie_sprint" if tier == &"sprint" else "zombie_groan"
		if enemy_id == &"bellringer":
			snd = "bellringer_wheeze"
		AudioDirector.play_3d(snd, global_position + Vector3.UP * 1.6, -6.0, 0.0)
	# Glasshide grinding / Bellringer lantern-chain jingle.
	_ring_t -= delta
	if _ring_t <= 0.0 and (enemy_id == &"glasshide" or enemy_id == &"bellringer"):
		_ring_t = 1.6 if enemy_id == &"glasshide" else 0.45
		var ring_key: String = "glasshide_grind" if enemy_id == &"glasshide" else "bellringer_lantern"
		AudioDirector.play_3d(ring_key, global_position + Vector3.UP, -8.0, 0.0)


## A footstep from the locomotion clip's contact events, surface-aware: culled by distance to the
## target player and rate-capped across the horde (anim.json footsteps).
func _footstep(_left: bool) -> void:
	var fs: Dictionary = _anim["footsteps"]
	if (not puppet and not is_on_floor()) or target == null:
		return
	var r: float = float(fs.get("range_m", 18.0))
	if global_position.distance_squared_to(target.global_position) > r * r:
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_step_msec < int(fs.get("gap_ms", 70)):
		return
	_last_step_msec = now
	var surface: String = _floor_surface()
	var key: String = "footstep_" + surface
	if surface == "water" or not (AudioDirector.bank.get("sounds", {}) as Dictionary).has(key):
		key = "zombie_step"   # (the bank's keys live under "sounds"; the old top-level check never matched, T-085)
	AudioDirector.play_3d(key, global_position, float(fs.get("volume_db", -3.0)), 0.08)


## What the zombie stands on, from the floor collider's "surface" metadata or name hints (anim.json footsteps).
func _floor_surface() -> String:
	var col: Object = get_last_slide_collision().get_collider() if get_slide_collision_count() > 0 else null
	var found: String = _surface_of_collider(col)
	if found != "":
		return found
	var defaults: Dictionary = _anim["footsteps"]["default_by_map"]
	return str(defaults.get(String(GameState.map_id), defaults.get("default", "stone")))


## Surface name of a floor collider from its "surface" metadata or name hints (anim.json footsteps); "" = unknown.
func _surface_of_collider(col: Object) -> String:
	var fs: Dictionary = _anim["footsteps"]
	var n: Node = col as Node
	if n == null:
		return ""
	for m: Node in [n, n.get_parent()]:
		if m != null and m.has_meta("surface"):
			return str(m.get_meta("surface"))
	var lname: String = n.name.to_lower()
	for s: String in (fs["surfaces"] as Dictionary).keys():
		for hint: String in fs["surfaces"][s]:
			if lname.contains(hint):
				return s
	return ""


## The surface class under a ground spawn (T-085): the ZombieSpawn's "surface" meta, else the floor collider
## under the feet (metadata / name hints like the footsteps), else the map's default (enemies.json
## emerge.surface_by_map: Map 0 snow, Map 1 earth).
func _emerge_surface_at() -> String:
	var found: String = _spawn_surface
	if found == "" and is_inside_tree():
		var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		if space != null:
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.5, global_position - Vector3.UP * 1.5, LAYER_WORLD, [get_rid()])
			var hit: Dictionary = space.intersect_ray(q)
			if not hit.is_empty():
				found = _surface_of_collider(hit.get("collider"))
	return ZombieEmerge.surface_class(found, GameState.map_id)


# ---------------------------------------------------------------- co-op puppet (client side, M7)

func make_puppet() -> void:
	puppet = true
	interp = InterpBuffer.new()
	if _agent != null:
		_agent.avoidance_enabled = false


func variant_name() -> String:
	return _variant


## Sub-state for the snapshot (the bosses' own state machines); 0 for the shared one.
func net_sub_state() -> int:
	if state == State.CLIMB_LINK and not _dormant:
		return 3 if _ladder_drop else (2 if _mantling else 0)   # T-268: 2 = over the edge, 3 = dropping back down
	return 1 if _dormant else 0   # T-192: 1 = a Hard Truth body still lying (the puppet lies still too)


## The host spawned this zombie: dress it the same way and start following the snapshots.
func puppet_activate(enemy: StringName, tier_v: StringName, variant: String, hp_max: float, pos: Vector3, yaw: float,
		st: int, sub: int, local_p: Player) -> void:
	enemy_id = enemy
	_cfg = kind_config(enemy_id)
	tier = tier_v
	max_hp = hp_max
	hp = hp_max
	_pred_dmg = 0.0
	is_crawler = false
	is_last = false
	_burn_t = 0.0
	armor_torso_mult = float(_cfg.get("armor_mult", 1.0))
	target = local_p
	_reset_presentation()
	_set_crawl_pose(false)
	_apply_variant(variant)
	_apply_kind()
	_apply_marke()   # from net_id: the same site the host picked
	_puppet_show(pos, yaw)
	state = State.CHASE
	_emerge_kind = "portal" if enemy_id == &"bellringer" else "ground"
	_puppet_enter(st, sub)
	_random_phase()
	if tier == &"sprint":
		AudioDirector.play_3d("zombie_sprint", global_position + Vector3.UP * 1.6, 2.0)
	if enemy_id == &"bellringer":
		_portal_flash()
	GLBus.enemy_spawned.emit(enemy_id, get_instance_id())


func _puppet_show(pos: Vector3, yaw: float) -> void:
	_turn_motion.reset()
	show()
	process_mode = Node.PROCESS_MODE_INHERIT
	collision_layer = LAYER_ZBODY
	collision_mask = 0
	for hb: Hitbox in _hitboxes:
		hb.collision_layer = Hitbox.LAYER_HITBOX
	_marke_layers(true)
	_pivot.rotation = Vector3.ZERO
	_pivot.position = Vector3.ZERO
	_smooth_off = Vector3.ZERO
	velocity = Vector3.ZERO
	global_position = pos
	rotation.y = yaw
	interp.snap(float(Time.get_ticks_msec()), pos, yaw)


## Follows the host's state machine (sounds and poses tied to entering a state play here too).
func _puppet_enter(st: int, _sub: int) -> void:
	var s: State = st as State
	if s == State.GETUP and _sub == 1 and not _dormant and enemy_id == &"ganger":
		lie_dormant()   # T-192: the host's body is still lying
		return
	if _dormant and _sub != 1:
		wake_from_dormant(float(_anim["knockdown"]["getup_seconds"]))   # it got up on the host
		return
	if s == State.CLIMB_LINK:
		_puppet_ladder_sub(_sub, s != state)   # T-268: the mantle and the drop show on the client too
	if s == State.INACTIVE or s == State.DEAD or s == state:
		return
	if s == State.CLIMB:
		_climb_clip = _pick(_anim["clips"]["vault"])
	_enter(s)


func _puppet_tick(delta: float) -> void:
	if state == State.DEAD:
		_puppet_dead(delta)
		return
	if state == State.INACTIVE:
		return
	_state_t += delta
	if state == State.EMERGE:
		_emerge_tick(delta)   # the rise's sprays, crunches and the head-out hitbox switch play on the client too
	_pred_dmg *= exp(-delta * 4.0)
	if Net.session != null and interp.sample(Net.session.render_time_ms()):
		_puppet_apply_sample(delta)
		var zf: int = (interp.flags >> 8) & 0xFF
		hp = max_hp * float((interp.aux >> 8) & 0xFF) / 255.0
		is_last = (zf & NetMatch.ZF_LAST) != 0
		if (zf & NetMatch.ZF_CRAWL) != 0 and not is_crawler:
			Net.applying = true
			become_crawler()
			Net.applying = false
		_puppet_enter(interp.flags & 0xFF, interp.aux & 0xFF)
	_puppet_visual_tick(delta)
	_update_audio(delta)
	_update_senses(delta)


## The interpolated sample onto the body (interp.sample() was just taken): place, facing, the observed velocity,
## and the recorded turn's presentation trigger (only the observed yaw is known here: ZombieTurnMotion.observe).
func _puppet_apply_sample(delta: float) -> void:
	var prev: Vector3 = global_position
	global_position = interp.pos
	var before: float = rotation.y
	rotation.y = interp.yaw
	_turn_rate = wrapf(rotation.y - before, -PI, PI) / maxf(delta, 0.0001)
	velocity = (global_position - prev) / maxf(delta, 0.0001)
	velocity.y = 0.0
	_turn_motion.observe(before, interp.yaw, delta, _can_recorded_turn())


func _puppet_visual_tick(_delta: float) -> void:
	pass


func _puppet_dead(delta: float) -> void:
	_state_t += delta
	_update_dead(delta)


## A hit from this client's own weapon: wounds, flinch and the hit marker now (predicted); the host decides.
func _puppet_damage(amount: float, limb: StringName, weapon_id: StringName, by_player: int, kind: StringName, armor_piercing: bool) -> bool:
	# the Marke (T-137): the host gets the report as a Marke hit and does its own mapping and the bonus; the
	# prediction here (wound, flinch, the hitmarker's tint) runs on the host limb
	var marke: bool = limb == &"marke"
	if marke:
		limb = marke_host_limb()
		if marke_site != &"":
			last_hit_bone = str(ZombieBody.weak_site(marke_site)[0])
	var side: String = _hit_side(limb)
	last_hit_bone = ""   # consumed by this hit even when it is not predicted here (see take_damage)
	if not is_active() or _dormant or Net.session == null or by_player != Net.local_player_id() or Net.applying:
		return false
	Net.session.send_hit(self, amount, &"marke" if marke else limb, weapon_id, kind, armor_piercing)
	var eff: float = amount
	if marke:   # the host multiplies the report itself; the prediction matches it
		if not is_wound():
			GLBus.marke_hit.emit(by_player)
		eff *= float(((GLData.table("enemies") as Dictionary).get("marke", {}) as Dictionary).get("damage_mult", 1.5))
	if (limb == &"torso" or limb == &"arms") and kind == &"bullet" and not armor_piercing:
		eff *= armor_torso_mult
	if GameState.has_flag(&"deaths_door") and kind != &"world":
		eff = hp + 1.0
	_pred_dmg += eff
	if kind != &"fire" and kind != &"world":
		_wound(limb, side)
	if kind == &"bullet":
		AudioDirector.play_3d("impact_flesh", global_position + Vector3.UP * 1.2, 0.0, 0.0)
	if kind != &"fire":
		_play_flinch(limb, side)
	return hp - _pred_dmg <= 0.0


## The host's death: the same fall, the same head pop, at the host's position.
func puppet_die(_limb: StringName, kind: StringName, death_kind: int, side: float, pop: bool, pos: Vector3) -> void:
	if state == State.DEAD or state == State.INACTIVE:
		return
	if pos.is_finite():
		global_position = pos
	_puppet_hide_hitboxes()
	AudioDirector.play_3d("zombie_death", global_position + Vector3.UP * 1.2, -1.0)
	_death_burst()
	var deaths: Array = _anim["clips"]["death"]
	_death_kind = death_kind
	_death_side = side
	_death_explosive = kind == &"explosive"
	_death_clip = str(_anim["clips"]["death_crawler"]) if (is_crawler or death_kind >= deaths.size()) else str(deaths[clampi(death_kind, 0, deaths.size() - 1)])
	_mark_death_sink()
	_start_death()
	if pop:
		_pop_head()


func _puppet_hide_hitboxes() -> void:
	collision_layer = 0
	for hb: Hitbox in _hitboxes:
		hb.collision_layer = 0
	velocity = Vector3.ZERO


## Removed on the host without a death (recycled, round skipped).
func puppet_gone() -> void:
	if state == State.INACTIVE:
		return
	deactivate()
	if net_id >= NetMatch.EXTRA_ID_BASE:
		queue_free()


## A one-off presentation event from the host (boss attacks; severs and knockdown sides for the shared body).
func puppet_fx(what: StringName, args: Array) -> void:
	match what:
		&"sever":
			if args.size() >= 2:
				Net.applying = true
				_severed_logic[str(args[0])] = true
				ZombieGore.sever(self, str(args[0]), args[1] as Vector3)
				Net.applying = false
		&"knockdown":
			if args.size() >= 1:
				_down_front = bool(args[0])
