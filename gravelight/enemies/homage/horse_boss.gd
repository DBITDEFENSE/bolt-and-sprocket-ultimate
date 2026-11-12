class_name HorseBoss
extends HomageBoss
## The undead horses (T-240, the owner: "add boss zombie horses on round 20 and 30"; data/gravelight/bosses/horse.json).
## DAS TOTENROSS (round 20): a carters' dray horse long in the ground, the hide drawn tight over the ribs, the lower jaw
## bare, still in its collar and traces and dragging a broken shaft; Nachtglas burns in the sockets and through the
## gaps between the ribs, and its breath steams. DER FUHRMANN (round 30): the same horse, worse, with its dead carter on
## its back; he lashes with the whip until the horse is at half its health, then he is thrown and fights on foot.
## It runs on the boss framework (HomageBoss: the move clock, the HUD bar, the squad scaling, the shared effects kit
## `fx`) but its body is the horse (HorseRig, the living horse's skeleton and gaits with the "dead" look): the framework's
## own body is hidden and its limb boxes are replaced by the horse's.
## The fight is fast and heavy, and every attack is telegraphed and has a counter (docs/BOSS_REWORK.md section 1):
##   charge    a long wind-up (it paws, the head goes down, it screams, the light rises); the line is set before it
##             runs, so a side-step works; whoever is in the lane is hit, thrown aside and knocked down; a wall staggers
##             it (2.6 s at x1.5 damage). From the second phase it wheels and charges back once.
##   stomp     close in front: it rears (0.9 s) and the fore hooves come down: the inner ring hurts and knocks down,
##             the outer ring hurts anyone on the ground (be in the air, or back out).
##   kick      someone lingering behind it: the ears go flat, the head turns (0.5 s), both hind feet lash out in a
##             cone behind. Circling it is not free.
##   trample   someone knocked down within reach: it walks onto them (0.6 s) and stamps, up to three times; a
##             teammate's fire (2.5% of its health, or one hit in the ribs) breaks it off; getting up and away ends it.
##   whip      (the Fuhrmann, while he rides) a lash down a line to 9.5 m (0.7 s, the arm goes up): hurts and slows.
## Phases by health (data "phases"): faster, shorter cooldowns, the arena's lights dying toward its own glow.
## It only goes where a horse can (data: the map's round_boss_arena zones): a player elsewhere is not chased; with
## nobody in reach it lays siege (its scream sets the dead near it running).
## The living horse in the yard is ignored (it is no target and no obstacle); it shies from this one.
## Pure rules (static) are tested by test_horse_boss.gd; the smoke is smoke_horse_boss.

const PATH: String = "res://data/gravelight/bosses/horse.json"
const VIOLET: Color = Color(0.72, 0.42, 1.0)

static var _table: Dictionary = {}

var rig: HorseRig = null
var zones: Array = []                 # zone ids it may stand in and chase into ([] = anywhere)
var exit_point: Vector3 = Vector3.INF
var phase_i: int = 0
var rider_on: bool = false
var rider_zombie: Zombie = null
var wall_stuns: int = 0
var charges: int = 0
var charge_hits: int = 0
var stomps: int = 0
var kicks: int = 0
var whips: int = 0
var tramples_started: int = 0
var trample_interrupts: int = 0
var sieges: int = 0
var doors_smashed: Array = []
var tele_log: Array = []              # [move id, seconds] of every telegraph (the smoke checks none is short)
var posed: bool = false               # a capture's still pose: the brain is off

var _vis_yaw: float = 0.0
var _aim: Vector3 = Vector3.FORWARD
var _locked: bool = false
var _charge_left: float = 0.0
var _charge_hit: Dictionary = {}
var _charged_twice: bool = false
var _stagger_s: float = 0.0
var _behind_t: float = 0.0
var _behind_side: float = 1.0
var _tramp: Player = null
var _tramp_n: int = 0
var _tramp_t: float = 0.0
var _tramp_dmg: float = 0.0
var _no_target_t: float = 0.0
var _siege_cd: float = 0.0
var _breath_t: float = 1.5
var _warn_t: float = 0.0
var _arrive_to: Vector3 = Vector3.INF
var _horse_boxes: Array[Hitbox] = []
var _glow: OmniLight3D = null
var _steam: GPUParticles3D = null
var _motes: GPUParticles3D = null
var _steam_t: float = 0.0
var _shaft: Node3D = null
var _shaft_pos: Vector3 = Vector3.INF
var _chain: MeshInstance3D = null
var _drag_loop: AudioStreamPlayer3D = null
var _rider: Node3D = null
var _rider_skel: Skeleton3D = null
var _whip_arm: float = 0.0
var _lash: MeshInstance3D = null
var _death_scream: bool = false
var _has_zone_volumes: bool = false
var _retreat_s: float = 0.0


# ================================================================== data and pure rules

static func table() -> Dictionary:
	if _table.is_empty():
		_table = GLData.load_json(PATH)
	return _table


## A boss's block with its "inherits" folded in (the Fuhrmann is the Totenross with a rider and more of everything).
static func block_of(id: String) -> Dictionary:
	var all: Dictionary = table().get("bosses", {})
	var b: Dictionary = (all.get(id, {}) as Dictionary).duplicate(true)
	if b.has("inherits"):
		var base: Dictionary = block_of(str(b["inherits"]))
		b.erase("inherits")
		return merged(base, b)
	return b


## `over` laid on `base`, dictionaries merged key by key.
static func merged(base: Dictionary, over: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for k: Variant in over.keys():
		if out.get(k) is Dictionary and over[k] is Dictionary:
			out[k] = merged(out[k], over[k])
		else:
			out[k] = over[k]
	return out


## The phase for a health fraction: the last one whose "at" the health has fallen to.
static func phase_for(hp_fraction_v: float, phases: Array) -> int:
	var i: int = 0
	for k: int in phases.size():
		if hp_fraction_v <= float((phases[k] as Dictionary).get("at", 1.0)) + 0.0001:
			i = k
	return i


## True when `point` is inside a charge's lane: within `half_width` of the segment from `origin` along `dir` for
## `length` metres (flat).
static func in_lane(origin: Vector3, dir: Vector3, length: float, half_width: float, point: Vector3) -> bool:
	var d: Vector2 = Vector2(dir.x, dir.z)
	if d.length() < 0.0001:
		return false
	d = d.normalized()
	var rel: Vector2 = Vector2(point.x - origin.x, point.z - origin.z)
	var along: float = rel.dot(d)
	if along < -half_width or along > length + half_width:
		return false
	return absf(rel.x * d.y - rel.y * d.x) <= half_width


## True when `to_point` (from the horse) is behind it: more than `behind_deg` off its facing.
static func is_behind(facing: Vector3, to_point: Vector3, behind_deg: float) -> bool:
	var f: Vector2 = Vector2(facing.x, facing.z)
	var t: Vector2 = Vector2(to_point.x, to_point.z)
	if f.length() < 0.0001 or t.length() < 0.0001:
		return false
	return rad_to_deg(absf(f.angle_to(t))) > behind_deg


## True when `to_point` is inside a cone of half-angle `cone_deg` round `axis`, within `reach` metres (flat).
static func in_cone(axis: Vector3, to_point: Vector3, cone_deg: float, reach: float) -> bool:
	var a: Vector2 = Vector2(axis.x, axis.z)
	var t: Vector2 = Vector2(to_point.x, to_point.z)
	if a.length() < 0.0001 or t.length() < 0.0001 or t.length() > reach:
		return false
	return rad_to_deg(absf(a.angle_to(t))) <= cone_deg


## What the stomp does at `dist` metres from where the hooves land: [damage, knocked down]. The outer ring only
## hurts a body on the ground.
static func stomp_hit(dist: float, on_floor: bool, m: Dictionary, ring_add: float = 0.0) -> Array:
	if dist <= float(m.get("r_in", 3.2)):
		return [float(m.get("damage", 60)), dist <= float(m.get("knock_radius", 2.2))]
	if dist <= float(m.get("r_out", 6.5)) + ring_add and on_floor:
		return [float(m.get("damage_out", 30)), false]
	return [0.0, false]


## The move it starts from MOVE, or "": `c` = {dist (to the target, flat; INF = none), clear (a straight line to
## the target), down_near (a knocked-down player within the trample's search), behind_s (seconds someone has been
## behind it), rider (the Fuhrmann rides), ready {move: bool}}.
static func pick_move(c: Dictionary, moves: Dictionary, whip: Dictionary) -> String:
	var ready: Dictionary = c.get("ready", {})
	var dist: float = float(c.get("dist", INF))
	if bool(ready.get("kick", false)) and float(c.get("behind_s", 0.0)) >= float((moves.get("kick", {}) as Dictionary).get("linger", 0.35)):
		return "kick"
	if bool(ready.get("trample", false)) and bool(c.get("down_near", false)):
		return "trample"
	if bool(ready.get("stomp", false)) and dist <= float((moves.get("stomp", {}) as Dictionary).get("range", 4.4)):
		return "stomp"
	var ch: Dictionary = moves.get("charge", {})
	if bool(ready.get("charge", false)) and bool(c.get("clear", false)) and dist >= float(ch.get("min_range", 7.0)) and dist <= float(ch.get("range", 28.0)):
		return "charge"
	if bool(c.get("rider", false)) and bool(ready.get("whip", false)) and bool(c.get("clear", false)) \
			and dist >= float(whip.get("min_range", 3.0)) and dist <= float(whip.get("range", 9.5)):
		return "whip"
	return ""


## A telegraph is never under half a second (docs/BOSS_REWORK.md section 1).
static func tele_seconds(seconds: float) -> float:
	return maxf(0.5, seconds)


## True when it may chase a body standing in `zone` (one of its zones, open) no more than `dy_max` above or below.
static func may_chase(zone: StringName, zone_open: bool, dy: float, allowed: Array, dy_max: float = 1.6) -> bool:
	if allowed.is_empty():
		return absf(dy) <= dy_max
	if zone == &"" or not zone_open:
		return false
	for z: Variant in allowed:
		if StringName(str(z)) == zone:
			return absf(dy) <= dy_max
	return false


## True at the moment the rider is thrown: he rides and the horse's health has fallen to `falls_at`.
static func rider_falls(riding: bool, hp_fraction_v: float, falls_at: float) -> bool:
	return riding and hp_fraction_v <= falls_at


## The thrown rider's health on foot.
static func rider_hp(round_zombie_health: float, r: Dictionary) -> float:
	return round_zombie_health * float(r.get("hp_rounds", 4.0))


# ================================================================== setup

func _init() -> void:
	boss_key = "totenross"


func _ready() -> void:
	super._ready()
	ecfg = table()
	bcfg = block_of(boss_key)
	if fx != null:
		fx.dread_id = StringName(str(bcfg.get("boss_id", boss_key)))
		for k: Variant in (bcfg.get("dread", {}) as Dictionary).keys():
			fx.cfg[k] = bcfg["dread"][k]
	_has_zone_volumes = not get_tree().get_nodes_in_group(&"zone_volumes").is_empty()
	rig = HorseRig.new("dead")
	rig.name = "HorseRig"
	_pivot.add_child(rig)
	rig.wrong = 1.0
	rig.hoof.connect(_on_hoof)
	# the horse's limb boxes replace the framework body's
	for h: Array in [["Head", &"head", Vector3(0.3, 0.36, 0.72), HorseMesh.head_point(0.3, 0.0, -0.02)],
			["Neck2", &"neck", Vector3(0.34, 0.5, 0.75), Vector3(0, 1.66, -0.96)],
			["Body", &"torso", Vector3(0.74, 0.8, 0.95), Vector3(0, 1.18, -0.3)],
			["Hips", &"torso", Vector3(0.74, 0.78, 0.9), Vector3(0, 1.22, 0.55)],
			["Body", &"back", Vector3(0.1, 0.42, 0.52), Vector3(-0.37, 1.2, -0.08)],
			["Body", &"back", Vector3(0.1, 0.22, 0.26), Vector3(0.38, 1.36, -0.12)],
			["LF_B", &"legs", Vector3(0.2, 0.8, 0.22), Vector3(-0.23, 0.5, -0.52)], ["RF_B", &"legs", Vector3(0.2, 0.8, 0.22), Vector3(0.23, 0.5, -0.52)],
			["LH_B", &"legs", Vector3(0.22, 0.85, 0.3), Vector3(-0.25, 0.55, 0.74)], ["RH_B", &"legs", Vector3(0.22, 0.85, 0.3), Vector3(0.25, 0.55, 0.74)]]:
		var hb: Hitbox = Hitbox.new()
		hb.setup(self, h[1], h[2])
		hb.collision_layer = 0
		rig.attach(str(h[0]), hb, h[3])
		_horse_boxes.append(hb)
	# the light in the ribcage, the breath, the motes
	_glow = OmniLight3D.new()
	_glow.light_color = VIOLET
	_glow.light_energy = 2.0
	_glow.omni_range = 4.5
	_glow.omni_attenuation = 1.4
	_glow.shadow_enabled = false
	_glow.set_meta("no_dim", true)
	rig.attach("Body", _glow, Vector3(0, 1.2, -0.05))
	var nose: Node3D = Node3D.new()
	rig.attach("Head", nose, HorseMesh.head_point(0.62, 0.0, 0.02))
	_steam = BossFx.emitter("steam", nose, Vector3.ZERO, 0.55)
	var ribs: Node3D = Node3D.new()
	rig.attach("Body", ribs, Vector3(0, 1.25, -0.05))
	_motes = BossFx.emitter("motes", ribs, Vector3.ZERO, 0.9)
	# the telegraph light rides the chest (the framework hung it on its own, hidden, body)
	if _tele_light != null and _tele_light.get_parent() != null:
		_tele_light.get_parent().remove_child(_tele_light)
		rig.attach("Neck1", _tele_light, Vector3(0, 1.5, -0.95))
		_tele_light.omni_range = 6.0
	_build_shaft()


func modelled() -> bool:
	return false


func person_id() -> String:
	return "totenross"


## Brings it in at `at` with `health`.
func spawn_horse(at: Vector3, health: float) -> void:
	spawn_homage(at, health)


func _on_spawned() -> void:
	enemy_id = StringName(str(bcfg.get("boss_id", boss_key)))
	_body.hide()
	for g: MeshInstance3D in _gear:
		g.hide()
	for hb: Hitbox in _hitboxes:
		if not _horse_boxes.has(hb):
			hb.collision_layer = 0
	_hitboxes.assign(_horse_boxes)
	for hb2: Hitbox in _hitboxes:
		hb2.collision_layer = Hitbox.LAYER_HITBOX
	_marke_layers(false)
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.5
	cap.height = 1.9
	_collision.shape = cap
	_collision.position = Vector3(0, 0.95, 0)
	collision_mask = LAYER_WORLD | LAYER_DOOR
	_look.active = false
	_vis_yaw = rotation.y
	phase_i = 0
	rider_on = bcfg.has("rider")
	if rider_on and _rider == null:
		_build_rider()
	if _rider != null:
		_rider.visible = rider_on
	_shaft_pos = Vector3.INF
	if _drag_loop == null and AudioDirector.has_sound("horse_boss_drag"):
		_drag_loop = AudioDirector.make_loop_3d("horse_boss_drag", self, -40.0)
		if _drag_loop != null:
			_drag_loop.play()
	rig.collapse = 0.0
	rig.wrong = 1.0
	_motes.emitting = false
	_set_glow(1.0)


func _tele_glow() -> float:
	return _tele_light.light_energy   # (the kit's tele() shape owns it)


func _footstep(_left: bool) -> void:
	pass   # the framework body's feet: the horse's own hooves speak (_on_hoof)


func damage_taken_mult() -> float:
	return float((bcfg.get("stagger", {}) as Dictionary).get("mult", 1.5)) if bstate == B.STAGGER else 1.0


func move_speed() -> float:
	return float(_phase_cfg().get("speed", bcfg.get("speed", 4.2))) * squad_speed_mult


func cd_for(seconds: float) -> float:
	return seconds * float(_phase_cfg().get("cd_mult", 1.0)) * squad_cd_mult


func _phase_cfg() -> Dictionary:
	var ph: Array = bcfg.get("phases", [])
	return ph[clampi(phase_i, 0, ph.size() - 1)] if not ph.is_empty() else {}


func _moves() -> Dictionary:
	return bcfg.get("moves", {})


func _whip_cfg() -> Dictionary:
	return (bcfg.get("rider", {}) as Dictionary).get("whip", {})


## The way it is seen to face (the picture turns at its own rate behind the body the framework steers).
func facing() -> Vector3:
	return Vector3(-sin(_vis_yaw), 0.0, -cos(_vis_yaw))


## Where its chest is (the front of a charge, the hooves of a stomp).
func chest() -> Vector3:
	return global_position + facing() * (0.9 * _pivot.scale.x)


# ================================================================== the brain

func _tick(delta: float) -> void:
	_update_picture(delta)
	if posed:
		stand(delta, false)
		return
	_update_phase_cfg()
	_siege_cd = maxf(0.0, _siege_cd - delta)
	target = _pick_target()
	match bstate:
		B.ARRIVE:
			_tick_arrive(delta)
		B.MOVE:
			_tick_move(delta)
		B.TELEGRAPH:
			_tick_telegraph(delta)
		B.ACTIVE:
			_tick_active(delta)
		B.SPECIAL:
			_tick_special(delta)
		B.RECOVER:
			stand(delta, false)
			if _bt >= _stagger_s:
				_go(B.MOVE)
		B.STAGGER:
			stand(delta, false)
			rig.stagger = move_toward(rig.stagger, 1.0, delta * 6.0)
			if _bt >= _stagger_s:
				_go(B.MOVE)
	if bstate != B.STAGGER:
		rig.stagger = move_toward(rig.stagger, 0.0, delta * 3.0)
	_drag_shaft(delta)
	_tick_rider(delta)


## The nearest player it may reach (its zones, about its own level); null when there is none.
func _pick_target() -> Player:
	var best: Player = null
	var best_d: float = INF
	for p: Player in alive_players():
		if p.downed or not _reachable(p.global_position):
			continue
		var d: float = dist_to(p)
		if d < best_d:
			best_d = d
			best = p
	return best


func _reachable(at: Vector3) -> bool:
	var dy: float = at.y - global_position.y
	if not _has_zone_volumes:
		return may_chase(&"", true, dy, [])
	var z: StringName = ZoneVolume.zone_at(get_tree(), at + Vector3.UP * 0.6)
	return may_chase(z, GameState.is_zone_open(z), dy, zones)


func _update_phase_cfg() -> void:
	var want: int = phase_for(hp_fraction(), bcfg.get("phases", []))
	if want > phase_i:
		phase_i = want
		enrage_steps = want
		_on_phase(want)


## A phase begins: the scream, the arena's lights dying toward its own glow, the motes.
func _on_phase(i: int) -> void:
	var ph: Dictionary = _phase_cfg()
	var lc: Dictionary = bcfg.get("lights", {})
	sfx("horse_boss_scream", 4.0, 0.9 - 0.06 * float(i))
	_motes.emitting = true
	_set_glow(1.0 + 0.6 * float(i))
	if fx != null:
		fx.shake_all(global_position, 0.5, 24.0)
		var lvl: float = float(ph.get("lights", 1.0))
		if lvl < 0.999:
			fx.lights_dim(global_position, float(lc.get("radius", 30.0)), lvl, float(lc.get("seconds", 2.5)))
			fx.lights_flicker(float(lc.get("flicker_s", 1.6)), 0.8)
	print("[%s] phase %d: %s" % [boss_key, i, str(ph.get("name", ""))])


func _set_glow(k: float) -> void:
	if _glow != null:
		_glow.light_energy = 2.0 * k
		_glow.omni_range = 4.5 + 1.2 * (k - 1.0)


# ---- arrival

## It comes in at a gallop toward `to` (the yard, the players): the title card is the round's (HorseRound).
func arrive_to(to: Vector3) -> void:
	_arrive_to = to
	_go(B.ARRIVE)


func _tick_arrive(delta: float) -> void:
	var a: Dictionary = bcfg.get("arrival", {})
	var goal: Vector3 = _arrive_to
	if target != null:
		goal = target.global_position
	if not goal.is_finite():
		_go(B.MOVE)
		return
	walk_to(goal, delta, float(a.get("speed", 9.0)) * squad_speed_mult)
	_smash_doors()
	var near: bool = target != null and dist_to(target) <= 12.0
	if near or _bt >= 9.0 or Vector2(goal.x - global_position.x, goal.z - global_position.z).length() < 3.0:
		_go(B.MOVE)


# ---- MOVE: close in, choose

func _tick_move(delta: float) -> void:
	var moves: Dictionary = _moves()
	if target == null:
		_tick_siege(delta)
		return
	_no_target_t = 0.0
	var d: float = dist_to(target)
	# who has been standing behind it
	var behind: bool = false
	var kc: Dictionary = moves.get("kick", {})
	for p: Player in alive_players():
		var to_p: Vector3 = p.global_position - global_position
		if Vector2(to_p.x, to_p.z).length() <= float(kc.get("range", 3.4)) and is_behind(facing(), to_p, float(kc.get("behind_deg", 115.0))):
			behind = true
			_behind_side = signf(facing().cross(to_p).y) if absf(facing().cross(to_p).y) > 0.001 else 1.0
	_behind_t = _behind_t + delta if behind else 0.0
	var tc: Dictionary = moves.get("trample", {})
	var down: Player = _downed_near(float(tc.get("search", 9.0)))
	var ctx: Dictionary = {"dist": d, "clear": _line_clear(target), "down_near": down != null, "behind_s": _behind_t, "rider": rider_on,
		"ready": {"kick": cd_ready("kick"), "trample": cd_ready("trample"), "stomp": cd_ready("stomp"), "charge": cd_ready("charge"), "whip": cd_ready("whip")}}
	var pick: String = pick_move(ctx, moves, _whip_cfg())
	if pick == "trample":
		_tramp = down
	if pick != "":
		_start(pick)
		return
	if d > 2.6:
		walk_to(target.global_position, delta)
		_smash_doors()
	else:
		stand(delta)


## Someone knocked down (not bleeding out: that is the horde's business) it may reach.
func _downed_near(search: float) -> Player:
	for p: Player in alive_players():
		if p.downed or not p.has_status(&"knockdown"):
			continue
		if dist_to(p) <= search and _reachable(p.global_position):
			return p
	return null


## A straight run to `p` with nothing solid in it (a charge, the whip).
func _line_clear(p: Player) -> bool:
	if p == null:
		return false
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.9,
		p.global_position + Vector3.UP * 0.9, LAYER_WORLD | LAYER_DOOR, [get_rid(), p.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## With nobody in reach: it stands its ground, and after a while its scream sets the dead near it running.
func _tick_siege(delta: float) -> void:
	stand(delta, false)
	_no_target_t += delta
	var sc: Dictionary = bcfg.get("siege", {})
	if _no_target_t >= float(sc.get("wait_s", 8.0)) and _siege_cd <= 0.0 and not alive_players().is_empty():
		_siege_cd = float(sc.get("every_s", 14.0))
		sieges += 1
		sfx("horse_boss_scream", 6.0, 0.85)
		rig.alert = 1.0
		rig.jaw = 0.7
		if fx != null:
			fx.tele(VIOLET, 3.0, 0.9, false)
			fx.shake_all(global_position, 0.3, 30.0)
		var n: int = 0
		if director != null:
			for z: Zombie in (director as ZombieDirector).active_zombies():
				if z == self or z is HomageBoss or z is Foreman or z is Screamer or z.is_crawler:
					continue
				if z.global_position.distance_to(global_position) <= float(sc.get("radius", 45.0)) and z.tier != &"sprint":
					z.debug_set_tier(StringName(str(sc.get("tier", "sprint"))))
					n += 1
		print("[%s] siege scream: %d of the dead run" % [boss_key, n])


# ---- moves

func _start(id: String) -> void:
	var seconds: float = 0.5
	match id:
		"charge":
			var m: Dictionary = _moves()["charge"]
			seconds = tele_seconds(float(m.get("telegraph_again", 0.9)) if _charged_twice else float(m.get("telegraph", 1.4)))
			_locked = false
			if target != null:
				_aim = _flat_dir(target.global_position - global_position)
			sfx("horse_boss_scream", 3.0, 1.0)
		"stomp":
			seconds = tele_seconds(float(_moves()["stomp"].get("telegraph", 0.9)))
			sfx("horse_boss_scream", 0.0, 1.15)
		"kick":
			seconds = tele_seconds(float(_moves()["kick"].get("telegraph", 0.5)))
			sfx("horse_boss_snort", 4.0, 0.9)
			rig._tail_vel += 9.0 * _behind_side
		"trample":
			seconds = tele_seconds(float(_moves()["trample"].get("telegraph", 0.6)))
			sfx("horse_boss_snort", 3.0, 0.8)
		"whip":
			seconds = tele_seconds(float(_whip_cfg().get("telegraph", 0.7)))
			_locked = false
			if target != null:
				_aim = _flat_dir(target.global_position - global_position)
			sfx("horse_boss_whip", -2.0, 0.7)
	_go(B.TELEGRAPH, id)
	tele_log.append([id, seconds])
	_stagger_s = seconds   # (the telegraph's length rides here until the move begins)
	if fx != null:
		fx.tele(VIOLET, 4.0 if id == "charge" else 3.0, seconds)


static func _flat_dir(v: Vector3) -> Vector3:
	var f: Vector3 = Vector3(v.x, 0.0, v.z)
	return f.normalized() if f.length() > 0.001 else Vector3.FORWARD


func _tick_telegraph(delta: float) -> void:
	var dur: float = _stagger_s
	var k: float = clampf(_bt / dur, 0.0, 1.0)
	if fx != null:
		fx.extra_dread = 0.3
	match move_id:
		"charge":
			var m: Dictionary = _moves()["charge"]
			stand(delta, false)
			if not _locked:
				if target != null:
					_aim = _flat_dir(target.global_position - global_position)
				if k >= float(m.get("lock_at", 0.7)):
					_locked = true   # the line is set: a side-step from here is a dodge
			_face(global_position + _aim)
			rig.head_low = move_toward(rig.head_low, 1.0, delta * 3.0)
			rig.paw = move_toward(rig.paw, 1.0, delta * 4.0)
			rig.ears_back = 1.0
			rig.jaw = 0.5 * (1.0 - k)
			_warn_lane(delta, float(m.get("range", 28.0)), float(m.get("width", 1.5)) + 0.8)
		"stomp":
			stand(delta, k < 0.6)
			rig.rear = move_toward(rig.rear, 1.0, delta / maxf(0.1, dur * 0.6))
			rig.ears_back = 1.0
			rig.jaw = 0.6
			_warn_disc(delta, chest() + facing() * 1.2, float(_moves()["stomp"].get("r_out", 6.5)))
		"kick":
			stand(delta, false)
			rig.ears_back = 1.0
			rig.look_yaw = move_toward(rig.look_yaw, 0.9 * _behind_side, delta * 6.0)
			_warn_disc(delta, global_position - facing() * 2.0, float(_moves()["kick"].get("range", 3.4)))
		"trample":
			rig.head_low = move_toward(rig.head_low, 0.6, delta * 3.0)
			rig.ears_back = 1.0
			if _tramp != null and is_instance_valid(_tramp):
				walk_to(_tramp.global_position, delta, 2.2)
			else:
				stand(delta, false)
		"whip":
			stand(delta, k < 0.6)
			if k < 0.6 and target != null:
				_aim = _flat_dir(target.global_position - global_position)
			_whip_arm = move_toward(_whip_arm, 1.0, delta * 4.0)
			_warn_lane(delta, float(_whip_cfg().get("range", 9.5)), float(_whip_cfg().get("width", 1.2)) + 0.6)
	if _bt >= dur:
		_begin_move()


func _begin_move() -> void:
	match move_id:
		"charge":
			var m: Dictionary = _moves()["charge"]
			charges += 1
			var reach: float = float(m.get("range", 28.0))
			if target != null:
				reach = minf(reach, dist_to(target) + float(m.get("overrun", 6.0)))
			_charge_left = reach
			_charge_hit.clear()
			set_cd("charge", float(m.get("cooldown", 9.0)))
			rig.paw = 0.0
			rig.jaw = 0.0
			_go(B.SPECIAL, "charge")
		"stomp":
			stomps += 1
			set_cd("stomp", float(_moves()["stomp"].get("cooldown", 7.0)))
			_go(B.ACTIVE, "stomp")
		"kick":
			kicks += 1
			set_cd("kick", float(_moves()["kick"].get("cooldown", 3.5)))
			_behind_t = 0.0
			_go(B.ACTIVE, "kick")
		"trample":
			tramples_started += 1
			set_cd("trample", float(_moves()["trample"].get("cooldown", 10.0)))
			_tramp_n = 0
			_tramp_t = 0.0
			_tramp_dmg = 0.0
			_go(B.SPECIAL, "trample")
		"whip":
			whips += 1
			set_cd("whip", float(_whip_cfg().get("cooldown", 6.0)))
			_go(B.ACTIVE, "whip")


func _tick_active(delta: float) -> void:
	stand(delta, false)
	match move_id:
		"stomp":
			var m: Dictionary = _moves()["stomp"]
			rig.rear = move_toward(rig.rear, 0.0, delta * 7.0)
			if not _hit_done and _bt >= 0.14:
				_hit_done = true
				var at: Vector3 = chest() + facing() * 1.2
				var add: float = float(_phase_cfg().get("stomp_ring_add", 0.0))
				for p: Player in alive_players():
					var hit: Array = stomp_hit(Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length(), p.is_on_floor() or p.carry != null, m, add)
					if float(hit[0]) > 0.0 and absf(p.global_position.y - global_position.y) < 2.2:
						hit_player(p, float(hit[0]))
						if bool(hit[1]):
							p.apply_status(&"knockdown", float(m.get("knockdown", 1.0)))
				sfx("boss_stomp", 6.0, 0.7, at)
				BossFx.burst("dust", at + Vector3.UP * 0.1, get_tree(), 2.5, 1.8)
				Effects.dust_puff(at + Vector3.UP * 0.05, "ground", 14)
				if fx != null:
					fx.shake_all(at, 0.75, 20.0)
			if _bt >= 0.35:
				rig.jaw = 0.0
				_recover(float(m.get("recover", 0.9)))
		"kick":
			var m2: Dictionary = _moves()["kick"]
			rig.kick = move_toward(rig.kick, 1.0, delta * 9.0) if _bt < 0.16 else move_toward(rig.kick, 0.0, delta * 4.0)
			if not _hit_done and _bt >= 0.1:
				_hit_done = true
				var back: Vector3 = -facing()
				for p: Player in alive_players():
					var to_p: Vector3 = p.global_position - global_position
					if in_cone(back, to_p, float(m2.get("cone_deg", 60.0)), float(m2.get("range", 3.4))) and absf(to_p.y) < 2.0:
						hit_player(p, float(m2.get("damage", 55)))
						p.apply_knockback((back + _flat_dir(to_p) * 0.4).normalized() * float(m2.get("knockback", 9.0)))
				sfx("boss_bone_crack", 2.0, 1.2, global_position - facing() * 1.6 + Vector3.UP * 0.9)
			if _bt >= 0.45:
				rig.look_yaw = 0.0
				_recover(float(m2.get("recover", 0.5)))
		"whip":
			var w: Dictionary = _whip_cfg()
			_whip_arm = move_toward(_whip_arm, -0.4, delta * 14.0)
			if not _hit_done and _bt >= 0.08:
				_hit_done = true
				var from: Vector3 = global_position
				for p: Player in alive_players():
					if in_lane(from, _aim, float(w.get("range", 9.5)), float(w.get("width", 1.2)), p.global_position) \
							and absf(p.global_position.y - global_position.y) < 2.2 and _line_clear(p):
						hit_player(p, float(w.get("damage", 35)))
						p.apply_status(StringName(str(w.get("status", "whip_slow"))), float(w.get("slow_s", 2.5)))
				sfx("horse_boss_whip", 5.0, 1.25)
				_show_lash(float(w.get("range", 9.5)))
			if _bt >= 0.3:
				_recover(float(w.get("recover", 0.4)))


func _tick_special(delta: float) -> void:
	match move_id:
		"charge":
			_tick_charge(delta)
		"trample":
			_tick_trample(delta)
		_:
			_go(B.MOVE)


## The run: straight down the line it set; whoever is in the lane is hit once; the dead are flung aside; a wall
## staggers it; it stops at the edge of its ground.
func _tick_charge(delta: float) -> void:
	var m: Dictionary = _moves()["charge"]
	var spd: float = float(m.get("speed", 13.0)) * squad_speed_mult
	rig.head_low = move_toward(rig.head_low, 0.45, delta * 2.0)
	rig.ears_back = 1.0
	state = State.CHASE
	rotation.y = atan2(-_aim.x, -_aim.z)
	var step: Vector3 = _aim * spd * delta
	var before: Vector3 = global_position
	var col: KinematicCollision3D = move_and_collide(step)
	velocity = Vector3(_aim.x * spd, velocity.y, _aim.z * spd)
	_apply_gravity(delta)
	move_and_collide(Vector3(0, velocity.y * delta, 0))
	_charge_left -= step.length()
	_smash_doors()
	var front: Vector3 = chest()
	for p: Player in alive_players():
		if _charge_hit.has(p.player_id):
			continue
		if Vector2(p.global_position.x - front.x, p.global_position.z - front.z).length() <= float(m.get("width", 1.5)) and absf(p.global_position.y - global_position.y) < 2.0:
			_charge_hit[p.player_id] = true
			charge_hits += 1
			hit_player(p, float(m.get("damage", 80)))
			var side: Vector3 = p.global_position - global_position
			side = side - _aim * side.dot(_aim)
			side.y = 0.0
			if side.length() < 0.05:
				side = _aim.cross(Vector3.UP)
			p.apply_knockback((_aim * 0.5 + side.normalized()).normalized() * float(m.get("knockback", 8.0)))
			p.apply_status(&"knockdown", float(m.get("knockdown", 1.1)))
	if director != null:
		for z: Zombie in (director as ZombieDirector).active_zombies():
			if z == self or z is HomageBoss or z == rider_zombie:
				continue
			if z.global_position.distance_to(front) < 1.3:
				var zs: Vector3 = z.global_position - global_position
				zs = zs - _aim * zs.dot(_aim)
				zs.y = 0.0
				z.external_push(((zs.normalized() if zs.length() > 0.05 else _aim.cross(Vector3.UP)) + _aim * 0.5).normalized() * 7.0, 0.5, 0, &"", 60.0)
	if col != null and absf(col.get_normal().y) < 0.5 and not (col.get_collider() is Player) and not (col.get_collider() is Zombie):
		_hit_wall(col.get_position())
		return
	if not _reachable(global_position) and _has_zone_volumes and not zones.is_empty():
		global_position = before   # the edge of where a horse may go: it pulls up
		_end_charge(m)
		return
	if _charge_left <= 0.0:
		_end_charge(m)


func _end_charge(m: Dictionary) -> void:
	rig.head_low = 0.0
	var again: bool = bool(_phase_cfg().get("double_charge", false)) and not _charged_twice and target != null and _line_clear(target) \
		and dist_to(target) >= float(m.get("min_range", 7.0)) * 0.6
	if again:
		_charged_twice = true
		_cds.erase("charge")
		_recover(0.25)
		get_tree().create_timer(0.3).timeout.connect(_charge_again)   # (a method: the timer lets go if the horse is freed)
		return
	_charged_twice = false
	_recover(float(m.get("recover", 1.1)))


func _charge_again() -> void:
	if is_active() and bstate == B.MOVE and target != null and not posed:
		_start("charge")
	else:
		_charged_twice = false


## It ran into something solid: staggered, open to more damage.
func _hit_wall(at: Vector3) -> void:
	var sc: Dictionary = bcfg.get("stagger", {})
	wall_stuns += 1
	_charged_twice = false
	velocity = Vector3.ZERO
	rig.head_low = 0.0
	sfx("horse_boss_crash", 6.0, 1.0, at)
	sfx("boss_bone_crack", 2.0, 0.8, at)
	sfx("horse_boss_scream", 0.0, 1.3)
	BossFx.burst("dust", at, get_tree(), 2.5, 1.8)
	BossFx.burst("chips", at, get_tree(), 1.5, 1.2)
	if fx != null:
		fx.shake_all(global_position, 0.7, 16.0)
	_stagger_s = float(sc.get("wall_seconds", 2.6))
	_go(B.STAGGER)
	print("[%s] ran into a wall: staggered %.1f s" % [boss_key, _stagger_s])


func _recover(seconds: float) -> void:
	_stagger_s = seconds
	rig.rear = 0.0 if move_id != "stomp" else rig.rear
	_go(B.RECOVER)


## Over someone knocked down: onto them, then it stamps; hurt enough (or once in the ribs) and it breaks off.
func _tick_trample(delta: float) -> void:
	var m: Dictionary = _moves()["trample"]
	var p: Player = _tramp
	if p == null or not is_instance_valid(p) or not p.is_alive() or p.downed or (not p.has_status(&"knockdown") and dist_to(p) > float(m.get("reach", 1.5)) + 0.6) or _bt > 6.0:
		rig.head_low = 0.0
		_recover(float(m.get("recover", 1.2)) * 0.5)
		return
	if _tramp_dmg >= max_hp * float(m.get("interrupt_fraction", 0.025)):
		trample_interrupts += 1
		rig.head_low = 0.0
		rig.shy = 1.0
		sfx("horse_boss_scream", 0.0, 1.4)
		_recover(float(m.get("recover", 1.2)))
		return
	rig.head_low = move_toward(rig.head_low, 0.8, delta * 3.0)
	if Vector2(p.global_position.x - chest().x, p.global_position.z - chest().z).length() > float(m.get("reach", 1.5)) * 0.6:
		walk_to(p.global_position, delta, 2.6)
	else:
		stand(delta)
	_tramp_t += delta
	rig.paw = 1.0
	if _tramp_t >= float(m.get("every", 0.6)):
		_tramp_t = 0.0
		_tramp_n += 1
		var at: Vector3 = chest()
		if Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length() <= float(m.get("reach", 1.5)):
			hit_player(p, float(m.get("damage", 30)))
		sfx("boss_stomp", 2.0, 1.1, at)
		Effects.dust_puff(at + Vector3.UP * 0.05, "ground", 8)
		if fx != null:
			fx.shake_all(at, 0.35, 10.0)
		if _tramp_n >= int(m.get("stomps", 3)):
			rig.paw = 0.0
			rig.head_low = 0.0
			_recover(float(m.get("recover", 1.2)))


func _on_damaged(amount: float, limb: StringName, by_player: int, kind: StringName) -> void:
	super._on_damaged(amount, limb, by_player, kind)
	if bstate == B.SPECIAL and move_id == "trample":
		if _tramp == null or by_player != _tramp.player_id:
			_tramp_dmg += amount
		if limb == &"back":
			_tramp_dmg += max_hp   # one hit in the ribs breaks it off
	var sc: Dictionary = bcfg.get("stagger", {})
	if kind == &"explosive" and amount >= max_hp * float(sc.get("blast_fraction", 0.04)) and bstate in [B.MOVE, B.TELEGRAPH, B.RECOVER]:
		_stagger_s = float(sc.get("blast_seconds", 1.4))
		rig.rear = 0.0
		rig.paw = 0.0
		rig.head_low = 0.0
		_go(B.STAGGER)
	rig.shy = maxf(rig.shy, clampf(amount / maxf(1.0, max_hp) * 30.0, 0.0, 0.5))
	# the rider is thrown at half the horse's health
	if rider_falls(rider_on, hp_fraction(), float((bcfg.get("rider", {}) as Dictionary).get("falls_at", 0.5))):
		_throw_rider()


func _smash_doors() -> void:
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		var d: BuyDoor = n as BuyDoor
		if d == null or d.is_open:
			continue
		var dp: Vector3 = d.global_position
		if Vector2(dp.x - global_position.x, dp.z - global_position.z).length() < 2.6 and absf(dp.y - global_position.y) < 3.0:
			d.open(0)
			doors_smashed.append(d.door_id)
			sfx("horse_boss_crash", 4.0, 0.8, dp + Vector3.UP)
			BossFx.burst("chips", dp + Vector3.UP * 1.2, get_tree(), 2.0, 1.4)
			print("[%s] broke %s open" % [boss_key, d.door_id])


# ---- what the squad's bots are told (BotBlackboard.add_danger: the same public call the vacuum uses)

func _blackboard() -> Object:
	var map: Node = get_tree().current_scene
	var squad: Object = map.get("squad") if map != null else null
	if squad == null or not squad.has_method("time"):
		return null
	var bb: Object = squad.get("blackboard")
	return bb if bb != null and bb.has_method("add_danger") else null


func _warn_lane(delta: float, length: float, half_width: float) -> void:
	_warn_t -= delta
	if _warn_t > 0.0:
		return
	_warn_t = 0.25
	var bb: Object = _blackboard()
	if bb == null:
		return
	var now: float = float(get_tree().current_scene.get("squad").call("time"))
	var n: int = int(ceil(length / (half_width * 1.5)))
	for i: int in n:
		bb.call("add_danger", global_position + _aim * (half_width + float(i) * half_width * 1.5), half_width + 0.6, 6.0, now + 0.8, "horse_lane:%d:%d" % [get_instance_id(), i])


func _warn_disc(delta: float, at: Vector3, radius: float) -> void:
	_warn_t -= delta
	if _warn_t > 0.0:
		return
	_warn_t = 0.25
	var bb: Object = _blackboard()
	if bb != null:
		bb.call("add_danger", at, radius + 0.5, 6.0, float(get_tree().current_scene.get("squad").call("time")) + 0.8, "horse_disc:%d" % get_instance_id())


# ================================================================== the picture: gait, breath, the shaft, the rider

func _update_picture(delta: float) -> void:
	var rate: float = float(bcfg.get("turn_rate", 2.6)) * (2.4 if bstate == B.TELEGRAPH or bstate == B.SPECIAL else 1.0)
	var off: float = wrapf(rotation.y - _vis_yaw, -PI, PI)
	_vis_yaw += clampf(off, -rate * delta, rate * delta)
	rig.rotation.y = wrapf(_vis_yaw - rotation.y, -PI, PI)
	var flat: float = Vector2(velocity.x, velocity.z).length()
	rig.speed = flat if state == State.CHASE else 0.0
	rig.turn = clampf(-off * 1.6, -1.0, 1.0) if flat > 0.3 or absf(off) > 0.3 else 0.0
	if bstate == B.MOVE or bstate == B.RECOVER or bstate == B.ARRIVE:
		rig.head_low = move_toward(rig.head_low, 0.0, delta * 2.0)
		rig.paw = move_toward(rig.paw, 0.0, delta * 4.0)
		rig.rear = move_toward(rig.rear, 0.0, delta * 3.0)
		rig.kick = move_toward(rig.kick, 0.0, delta * 4.0)
		rig.ears_back = move_toward(rig.ears_back, 0.35, delta * 2.0)
		rig.jaw = move_toward(rig.jaw, 0.0, delta * 2.0)
		rig.look_yaw = move_toward(rig.look_yaw, 0.0, delta * 3.0)
		rig.alert = move_toward(rig.alert, 0.0, delta * 1.0)
	rig.shy = move_toward(rig.shy, 0.0, delta * 2.0)
	rig.tick(delta)
	# the breath: a rattle and a cloud of steam at the nostrils
	_breath_t -= delta
	_steam_t -= delta
	if _steam_t <= 0.0:
		_steam.emitting = false
	if _breath_t <= 0.0:
		_breath_t = randf_range(2.2, 3.6) / (1.0 + 0.35 * float(phase_i))
		_steam.emitting = true
		_steam_t = 0.7
		AudioDirector.play_3d("horse_boss_breath", rig.muzzle_global(), -5.0, 0.08)


func _update_audio(_delta: float) -> void:
	pass   # (the framework's hum is the Cousins'; the horse breathes in _update_picture)


## A hoof lands: its own weight (the kit's footfall: dust, the thud, the view shake), heavier at a gallop.
func _on_hoof(leg: int, at: Vector3, gait: int) -> void:
	if not is_active() or fx == null:
		return
	var dc: Dictionary = bcfg.get("dread", {})
	var fore: bool = leg == HorseGait.LF or leg == HorseGait.RF
	if gait >= HorseGait.Gait.GALLOP:
		fx.stomp(at, float(dc.get("gallop_shake", 0.4)) if fore else 0.0, "horse_boss_hoof" if AudioDirector.has_sound("horse_boss_hoof") else "boss_stomp")
	elif fore or gait == HorseGait.Gait.TROT:
		fx.stomp(at)


## The broken shaft it drags by a trace: it follows the hip on a fixed length of chain, turning to the pull.
func _build_shaft() -> void:
	_shaft = Node3D.new()
	_shaft.name = "BrokenShaft"
	_shaft.top_level = true
	add_child(_shaft)
	var wood: StandardMaterial3D = HomageBoss.mat_ex(Color(0.2, 0.15, 0.1), 0.9)
	for part: Array in [[Vector3(0.09, 0.08, 1.7), Vector3(0, 0, 0.85), Vector3(0, 0, 0)], [Vector3(0.07, 0.06, 0.5), Vector3(0.05, 0.02, 1.85), Vector3(0, 14, 6)],
			[Vector3(0.05, 0.04, 0.34), Vector3(-0.04, 0.03, 1.8), Vector3(0, -18, -8)], [Vector3(0.4, 0.07, 0.09), Vector3(0, 0, 0.12), Vector3(0, 0, 0)]]:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = part[0]
		bm.material = wood
		mi.mesh = bm
		mi.position = part[1]
		mi.rotation_degrees = part[2]
		_shaft.add_child(mi)
	_chain = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.014
	cm.bottom_radius = 0.014
	cm.height = 1.0
	cm.radial_segments = 5
	cm.rings = 1
	cm.material = HomageBoss.mat_ex(Color(0.18, 0.14, 0.12), 0.6, 0.8)
	_chain.mesh = cm
	_chain.top_level = true
	add_child(_chain)


func _drag_shaft(delta: float) -> void:
	if _shaft == null:
		return
	var hitch: Vector3 = rig.point_global("Hips", Vector3(0.35, 0.86, 0.8))
	var ground_y: float = global_position.y + 0.06
	if not _shaft_pos.is_finite() or _shaft_pos.distance_to(hitch) > 6.0:
		_shaft_pos = Vector3(hitch.x, ground_y, hitch.z) - facing() * 1.5
	var to: Vector3 = Vector3(hitch.x, ground_y, hitch.z) - _shaft_pos
	var len_: float = 1.25
	if to.length() > len_:
		_shaft_pos += to.normalized() * (to.length() - len_)
	_shaft_pos.y = ground_y
	var dir: Vector3 = Vector3(hitch.x - _shaft_pos.x, 0.0, hitch.z - _shaft_pos.z)
	if dir.length() > 0.05:
		dir = dir.normalized()
		# the shaft's near end is at _shaft_pos, the rest trails behind along -dir (the meshes lie along +Z)
		_shaft.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), _shaft_pos)
	var a: Vector3 = hitch
	var b: Vector3 = _shaft_pos + Vector3.UP * 0.04
	var d: Vector3 = b - a
	if d.length() > 0.05:
		var up: Vector3 = d.normalized()
		var side: Vector3 = up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.BACK).normalized()
		_chain.global_transform = Transform3D(Basis(side, up, side.cross(up)).scaled(Vector3(1.0, d.length(), 1.0)), (a + b) * 0.5)
	if _drag_loop != null:
		var spd: float = Vector2(velocity.x, velocity.z).length()
		_drag_loop.volume_db = lerpf(-40.0, -6.0, clampf(spd / 6.0, 0.0, 1.0))
		_drag_loop.global_position = _shaft_pos


## The dead carter in the saddle (the Fuhrmann): a zombie body seated on the horse's back, a wide hat, the whip.
func _build_rider() -> void:
	_rider = Node3D.new()
	_rider.name = "Fuhrmann"
	rig.attach("Body", _rider, HorseMesh.SEAT + Vector3(0, -0.06, 0.06))
	_rider_skel = ZombieRig.build_skeleton()
	_rider.add_child(_rider_skel)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "RiderBody"
	mi.mesh = ZombieBody.build_skinned("villager", "medium", false)
	_rider_skel.add_child(mi)
	mi.skeleton = NodePath("..")
	mi.skin = _rider_skel.create_skin_from_rest_transforms()
	_rider_skel.position = Vector3(0, -ZombieRig.rest_global("Hips").origin.y, 0)
	# seated: the thighs forward and out round the barrel, the knees bent, the back slumped, the head down
	_rb("LeftUpperLeg", Basis(Vector3.BACK, -0.42) * Basis(Vector3.RIGHT, 1.2))
	_rb("RightUpperLeg", Basis(Vector3.BACK, 0.42) * Basis(Vector3.RIGHT, 1.2))
	_rb("LeftLowerLeg", Basis(Vector3.RIGHT, -1.15))
	_rb("RightLowerLeg", Basis(Vector3.RIGHT, -1.15))
	_rb("Spine", Basis(Vector3.RIGHT, -0.16))
	_rb("Chest", Basis(Vector3.RIGHT, -0.14))
	_rb("Neck", Basis(Vector3.RIGHT, -0.25))
	_rb("Head", Basis(Vector3.BACK, 0.2) * Basis(Vector3.RIGHT, -0.3))
	_rb("LeftUpperArm", Basis(Vector3.BACK, -0.12) * Basis(Vector3.RIGHT, 0.7))
	_rb("LeftLowerArm", Basis(Vector3.RIGHT, 0.75))
	# the hat and the whip's stock ride the head and the hand
	var head: BoneAttachment3D = BoneAttachment3D.new()
	_rider_skel.add_child(head)
	head.bone_name = "Head"
	var felt: StandardMaterial3D = HomageBoss.mat_ex(Color(0.07, 0.06, 0.06), 0.95)
	for part: Array in [[0.23, 0.24, 0.02, 0.2], [0.1, 0.12, 0.13, 0.27]]:
		var hm: MeshInstance3D = MeshInstance3D.new()
		var cyl_m: CylinderMesh = CylinderMesh.new()
		cyl_m.top_radius = float(part[0])
		cyl_m.bottom_radius = float(part[1])
		cyl_m.height = float(part[2])
		cyl_m.radial_segments = 12
		cyl_m.material = felt
		hm.mesh = cyl_m
		hm.position = Vector3(0, float(part[3]), 0.0)
		hm.rotation.x = -0.12
		head.add_child(hm)
	var hand: BoneAttachment3D = BoneAttachment3D.new()
	_rider_skel.add_child(hand)
	hand.bone_name = "RightHand" if _rider_skel.find_bone("RightHand") >= 0 else "RightLowerArm"
	var stock: MeshInstance3D = MeshInstance3D.new()
	var sm: CylinderMesh = CylinderMesh.new()
	sm.top_radius = 0.006
	sm.bottom_radius = 0.014
	sm.height = 1.3
	sm.radial_segments = 5
	sm.material = HomageBoss.mat_ex(Color(0.12, 0.08, 0.05), 0.7)
	stock.mesh = sm
	stock.position = Vector3(0, -0.5, 0)
	hand.add_child(stock)
	_lash = MeshInstance3D.new()
	var lm: BoxMesh = BoxMesh.new()
	lm.size = Vector3(0.02, 0.02, 1.0)
	lm.material = HomageBoss.mat_ex(Color(0.1, 0.07, 0.05), 0.8, 0.0, 0.6, VIOLET)
	_lash.mesh = lm
	_lash.top_level = true
	_lash.visible = false
	add_child(_lash)
	_pose_whip_arm()


func _rb(bone: String, b: Basis) -> void:
	var i: int = _rider_skel.find_bone(bone)
	if i >= 0:
		_rider_skel.set_bone_pose_rotation(i, b.get_rotation_quaternion())


## The whip arm: hanging with the stock across the thigh (0), raised over the head (1), cast forward (below 0).
func _pose_whip_arm() -> void:
	if _rider_skel == null:
		return
	var k: float = _whip_arm
	_rb("RightUpperArm", Basis(Vector3.BACK, lerpf(0.25, 0.5, clampf(k, 0.0, 1.0))) * Basis(Vector3.RIGHT, lerpf(0.5, 2.7, clampf(k, 0.0, 1.0)) if k >= 0.0 else lerpf(0.5, 1.5, -k / 0.4)))
	_rb("RightLowerArm", Basis(Vector3.RIGHT, lerpf(0.9, 0.5, clampf(k, 0.0, 1.0))))


func _tick_rider(delta: float) -> void:
	if _rider == null or not rider_on:
		return
	if not (bstate == B.TELEGRAPH and move_id == "whip") and not (bstate == B.ACTIVE and move_id == "whip"):
		_whip_arm = move_toward(_whip_arm, 0.0, delta * 2.5)
	_pose_whip_arm()


## The lash, seen for a moment down the line it struck.
func _show_lash(length: float) -> void:
	if _lash == null:
		return
	var from: Vector3 = global_position + Vector3.UP * 1.9 * _pivot.scale.y
	var to: Vector3 = global_position + _aim * length + Vector3.UP * 0.9
	var d: Vector3 = to - from
	_lash.global_transform = Transform3D(Basis.looking_at(d.normalized(), Vector3.UP).scaled(Vector3(1.0, 1.0, d.length())), (from + to) * 0.5)
	_lash.visible = true
	get_tree().create_timer(0.14).timeout.connect(_hide_lash)


func _hide_lash() -> void:
	if _lash != null and is_instance_valid(_lash):
		_lash.visible = false


## Half its health gone: the horse rears and the carter is thrown; he gets up and fights on foot (an ordinary zombie
## of this round with rider.hp_rounds of its health), counted by the round like any other.
func _throw_rider() -> void:
	rider_on = false
	if _rider != null:
		_rider.visible = false
	var rc: Dictionary = bcfg.get("rider", {})
	rig.rear = 0.8
	sfx("horse_boss_scream", 4.0, 1.2)
	_stagger_s = 1.2
	_go(B.STAGGER)
	var side: Vector3 = facing().cross(Vector3.UP) * 1.6
	var at: Vector3 = global_position + side
	if director != null and director.has_method("rise_at"):
		rider_zombie = (director as ZombieDirector).rise_at(at, str(rc.get("kit", "villager")), 2.0)
		if rider_zombie != null:
			var h: float = rider_hp(float(RoundManager.current_health()), rc)
			rider_zombie.max_hp = h
			rider_zombie.hp = h
			rider_zombie.debug_set_tier(StringName(str(rc.get("tier", "run"))))
	BossFx.burst("dust", at + Vector3.UP * 0.2, get_tree(), 1.5, 1.4)
	print("[%s] the rider is thrown (on foot: %s)" % [boss_key, str(rider_zombie != null)])


# ================================================================== death, retreat, tools

func _start_authored_death() -> void:
	# it goes down on its knees, then over on its side; the light in it goes out
	rig.rear = 0.0
	rig.paw = 0.0
	rig.kick = 0.0
	rig.head_low = 0.0
	rig.jaw = 0.8
	_death_scream = false
	_motes.emitting = false
	_steam.emitting = false
	if _drag_loop != null:
		_drag_loop.volume_db = -60.0
	if _rider != null:
		_rider.visible = false
	sfx("horse_boss_death" if AudioDirector.has_sound("horse_boss_death") else "horse_boss_scream", 6.0, 0.8)
	if fx != null:
		fx.lights_restore(4.0)


func _death_tick(delta: float) -> void:
	rig.collapse = move_toward(rig.collapse, 1.0, delta / 2.4)
	rig.jaw = move_toward(rig.jaw, 0.25, delta * 0.4)
	rig.speed = 0.0
	rig.turn = 0.0
	rig.tick(delta)
	if _glow != null:
		_glow.light_energy = move_toward(_glow.light_energy, 0.25, delta * 0.9)
	if rig.collapse >= 0.5 and not _death_scream:
		_death_scream = true
		sfx("boss_stomp", 4.0, 0.6)
		Effects.dust_puff(global_position + Vector3.UP * 0.1, "ground", 16)


func _hold_after() -> float:
	return 4.0


func _on_retreat() -> void:
	_retreat_s = 0.0
	sfx("horse_boss_scream", 4.0, 1.0)
	if fx != null:
		fx.lights_restore(3.0)


## The fail-safe: it wheels and bolts for the way it came, and is gone.
func _tick_retreat(delta: float) -> void:
	_update_picture(delta)
	_retreat_s += delta
	var goal: Vector3 = exit_point if exit_point.is_finite() else global_position - facing() * 30.0
	walk_to(goal, delta, 11.0)
	_drag_shaft(delta)
	if _retreat_s >= 5.0 or Vector2(goal.x - global_position.x, goal.z - global_position.z).length() < 2.5:
		_vanish()


func _vanish() -> void:
	if _shaft != null:
		_shaft.visible = false
	if _chain != null:
		_chain.visible = false
	super._vanish()


## Dev / smoke: start a move now against the nearest player it may reach (its cooldown is ignored).
func debug_move(id: String) -> void:
	target = _pick_target()
	_cds.erase(id)
	if id == "trample":
		_tramp = target
	if id == "kick" and target != null:
		_behind_side = 1.0
	_charged_twice = false
	_start(id)


## Dev / capture: stand still facing `yaw_deg` in a pose ("", "rear", "low", "kick", "gallop", "stagger").
func debug_pose(yaw_deg: float, pose: String = "") -> void:
	posed = true
	if pose == "none":
		pose = ""
	rotation.y = deg_to_rad(yaw_deg)
	_vis_yaw = rotation.y
	bstate = B.MOVE
	rig.rear = 1.0 if pose == "rear" else 0.0
	rig.jaw = 0.6 if pose == "rear" else 0.0
	rig.head_low = 1.0 if pose == "low" else 0.0
	rig.paw = 1.0 if pose == "low" else 0.0
	rig.kick = 1.0 if pose == "kick" else 0.0
	rig.stagger = 1.0 if pose == "stagger" else 0.0
	rig.ears_back = 1.0 if pose != "" else 0.3
	_motes.emitting = true
