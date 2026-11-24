class_name Horse
extends CharacterBody3D
## The rideable horse (T-240, the owner: "add a rideable horse in map 1"): the carters' Noriker tied at a hitching rail
## in the Inn's yard. Hold Use at it to mount (the body is carried up into the saddle: Player.begin_carry); mounted,
## forward urges it on through walk, trot and gallop, back reins it in and stops it (held at a stand it backs up),
## left / right turn it (it answers like an animal: the turn lags, a gallop turns wide and slows in a hard turn);
## hold Use again, or jump, to get down on a free spot beside it. The rider shoots from the saddle at every gait (the
## gait is the sway). T-262 (the owner: "allow player to shot gun while gallobing with horse, add horse upgrade"): at a
## gallop too, with more sway and a wider cone; there the hands rest on the reins until the weapon is wanted (fire,
## aim, reload, swap: the gun comes up, the knotted reins lie on the neck) and go back a moment after. And the tack:
## three pieces sold for Scrip at the tack chest by its rail (HorseTack) to a player on foot while it stands tied,
## kept for the match, worn on the model, every rider's (HorseRules.upgraded: the table it rides by).
## In a zombie game: zombies ignore it and cannot hurt it (its body is on the map-edge layer: players and bots are
## stopped by it, zombies and shots pass); it shies and slows when they crowd it, will not go near a homage boss, and
## flings aside a zombie it gallops through (damage on landing, a cooldown, its own speed lost); a rider can be hit
## and is put down beside it when downed (or knocked down by a boss). Left alone it walks back to its rail. It only
## stands on open ground in its zones (never through a house door, onto the tower or off the map): a step outside is
## refused.
## Co-op: one rider. The host decides who mounts (HorseUse.interact runs there) and mirrors it (the tack the same:
## HorseTack.interact runs on the host, which takes the buyer's Scrip and mirrors net_upgrades); the rider's own
## machine moves the horse (as a ladder or a zip line moves its user), every other peer puts it under the rider's
## replicated body. Bots never ride (may_mount), and nothing in their brains looks for it.
## Data: <map>.json "horses" rows (spawn_all, called by MapRoot beside the ladders and zip lines) and
## data/gravelight/horse.json (HorseRules).

enum Mode { TIED, LOOSE, MOUNTING, RIDDEN, DISMOUNTING, HOMING }

const LAYER_EDGE: int = 1 << 10
const MASK: int = 1 | (1 << 1) | (1 << 5) | (1 << 8) | (1 << 10)   # world, players, barricades, doors, the map's edge
const HAND_R_BASIS: Basis = Basis(Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0))
const HAND_L_BASIS: Basis = Basis(Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, -1, 0))

var look: String = "noriker"
var home_pos: Vector3 = Vector3.ZERO
var home_yaw: float = 0.0
var zones: Array = []
var rail_pos: Vector3 = Vector3.INF
var rail_yaw: float = 0.0

var mode: Mode = Mode.TIED
var rider: Player = null
var pace: float = 0.0
var speed: float = 0.0
var steer: float = 0.0                 # the turn the body is making (-1..1, right positive)
var rig: HorseRig = null
var use: HorseUse = null
var input_override: Variant = null     # smokes: Vector3(steer, throttle, sprint) instead of the rider's keys
var weapon_override: Variant = null    # smokes: true / false = the rider wants the weapon now, instead of the keys
var upgrades: Array = []               # T-262: the tack it wears (ids of horse.json "upgrades", in their order)
var tack: HorseTack = null             # the tack chest at its rail (none without a rail)
var dismount_wanted: bool = false      # smokes: get down now

# counters the smokes read
var rides: int = 0
var dismounts: int = 0
var refusals: int = 0
var tramples: int = 0
var shies: int = 0
var homed: int = 0
var forced_off: int = 0
var bought: int = 0

var _tab: Dictionary = {}              # the table it rides by: horse.json with its tack applied (HorseRules.upgraded)
var _since_weapon: float = 99.0        # seconds since the rider last wanted the weapon (the reins at a gallop)
var _tack_nodes: Array[Node] = []      # what the tack looks like on the model
var _r: Dictionary = {}
var _t: float = 0.0                    # seconds in the current mode
var _from: Vector3 = Vector3.ZERO      # the rider's place when a mount / dismount began
var _yaw0: float = 0.0
var _to: Vector3 = Vector3.ZERO        # where a dismount sets the rider down
var _last_ok: Vector3 = Vector3.ZERO
var _idle: float = 0.0
var _crowd_t: float = 0.0
var _crowd: int = 0
var _boss_d: float = INF
var _shy: float = 0.0
var _trample_cd: float = 0.0
var _blocked_t: float = 0.0
var _hold_t: float = 0.0
var _use_released: bool = false
var _path: PackedVector3Array = []
var _path_i: int = 0
var _home_prog_t: float = 0.0
var _home_prog_from: Vector3 = Vector3.ZERO
var _home_wait: float = 0.0
var _snd_t: float = 6.0
var _hoof_ms: int = 0
var _prev_pos: Vector3 = Vector3.ZERO
var _prev_yaw: float = 0.0
var _hands_on: bool = false
var _rope: MeshInstance3D = null
var _puppet_yaw: float = 0.0
var _has_zones: bool = false
var _demo_after: Variant = null        # captures: the input the horse is ridden with once the rider is up (ride)


func _init() -> void:
	collision_layer = LAYER_EDGE
	collision_mask = MASK
	floor_max_angle = deg_to_rad(40.0)
	floor_snap_length = 0.35
	safe_margin = 0.02


func _ready() -> void:
	_tab = HorseRules.upgraded(upgrades)
	_r = _blk("ride")
	add_to_group(&"horses")
	var bd: Dictionary = _blk("body")
	var cs: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = float(bd.get("radius", 0.55))
	cap.height = float(bd.get("height", 1.7))
	cs.shape = cap
	cs.position = Vector3(0, cap.height * 0.5, 0)
	add_child(cs)
	rig = HorseRig.new(look)
	rig.name = "Rig"
	add_child(rig)
	rig.hoof.connect(_on_hoof)
	use = HorseUse.new()
	use.name = "Use"
	use.horse = self
	var us: Array = bd.get("use_size", [1.5, 2.0, 3.0])
	use.interact_size = Vector3(float(us[0]), float(us[1]), float(us[2]))
	use.interact_offset = Vector3(0, float(us[1]) * 0.5, -0.2)
	add_child(use)
	_last_ok = global_position
	_prev_pos = global_position
	_prev_yaw = rotation.y
	_puppet_yaw = rotation.y
	_has_zones = not get_tree().get_nodes_in_group(&"zone_volumes").is_empty()
	_build_rope()
	_show_tack()


## A block of the table this horse rides by (its tack applied).
func _blk(key: String) -> Dictionary:
	return _tab.get(key, {})


# ================================================================== use (HorseUse forwards here)

func prompt_for(p: Player) -> String:
	if p == null or rider != null:
		return ""
	return "Hold [%s] to ride the horse" % Interactable.prompt_key(&"interact")


func can_use(p: Player) -> bool:
	if p == null:
		return false
	if rider == p:
		return mode == Mode.RIDDEN
	return (mode == Mode.TIED or mode == Mode.LOOSE or mode == Mode.HOMING) \
		and HorseRules.may_mount(rider != null, p.is_alive(), p.downed, p.is_bot or p.bot_driven or p.is_companion, p.carry != null)


## The host's (or solo's) decision: mount, or the rider gets down. Mirrored to every client.
func on_use(p: Player) -> void:
	if not can_use(p):
		return
	if rider == null:
		_begin_mount(p)
		Net.mirror(self, &"net_mount", [p.player_id, global_position, rotation.y])
	else:
		_begin_dismount()
		Net.mirror(self, &"net_dismount", [global_position, rotation.y])


## Client: the host let player `pid` mount.
func net_mount(pid: int, at: Vector3, yaw: float) -> void:
	var p: Player = _player(pid)
	if p == null:
		return
	if not p.is_local:
		global_position = at
		rotation.y = yaw
	_begin_mount(p)


## Client: the rider gets down (the rider's own machine keeps its horse where it is; the others take the host's).
func net_dismount(at: Vector3, yaw: float) -> void:
	if rider == null:
		return
	if not rider.is_local:
		global_position = at
		rotation.y = yaw
	_begin_dismount()


func _player(pid: int) -> Player:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		if n is Player and (n as Player).player_id == pid:
			return n as Player
	return null


## True when this machine moves the horse: its rider is this machine's human (or nobody rides: every peer walks it
## home the same way).
func simulates() -> bool:
	return rider == null or rider.is_local


func is_ridden() -> bool:
	return rider != null


func seated() -> bool:
	return mode == Mode.RIDDEN


# ================================================================== the tack (T-262; HorseTack forwards here)

func tack_prompt(p: Player) -> String:
	if p == null or p.is_bot or p.bot_driven or p.is_companion:
		return ""
	var id: String = HorseRules.next_upgrade(upgrades)
	if id == "":
		return "The horse wears all its tack (%s)" % HorseRules.tack_names(upgrades)
	var row: Dictionary = HorseRules.upgrade(id)
	if mode != Mode.TIED:
		return "%s: the horse must stand tied at its rail" % str(row.get("name", id))
	return "Hold [%s] to fit %s [%s]\n%s" % [Interactable.prompt_key(&"interact"), str(row.get("name", id)),
		tack.price_str(p, int(row.get("cost", 0))) if tack != null else str(int(row.get("cost", 0))), str(row.get("desc", ""))]


func can_buy(p: Player) -> bool:
	return p != null and HorseRules.may_buy(upgrades, HorseRules.next_upgrade(upgrades), p.is_alive(), p.downed,
		p.is_bot or p.bot_driven or p.is_companion, p.carry != null or rider == p, mode == Mode.TIED)


## The host's (or solo's) sale: the next piece, for the buyer's Scrip. Mirrored to every client.
func on_buy(p: Player) -> void:
	if tack == null or not can_buy(p):
		return
	var id: String = HorseRules.next_upgrade(upgrades)
	if not tack.try_purchase(p, StringName("horse_" + id), HorseRules.upgrade_cost(id)):
		return
	bought += 1
	net_upgrades(upgrades + [id])
	Net.mirror(self, &"net_upgrades", [upgrades])


## The tack it wears from now on (the host's word on a client; the dev console and the smokes call it too).
func net_upgrades(owned: Array) -> void:
	var was: int = upgrades.size()
	upgrades = HorseRules.clean_owned(owned)
	_tab = HorseRules.upgraded(upgrades)
	_r = _blk("ride")
	_show_tack()
	if upgrades.size() > was and is_inside_tree():
		_sound("tack", -2.0)
		if rig != null:
			rig.alert = 0.6


## The tack on the model: iron under the hooves, saddlebags and a rolled blanket behind the cantle, a padded breast
## piece. Each rides its bone (HorseRig.attach); children are placed in the model's own axes.
func _show_tack() -> void:
	for n: Node in _tack_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_tack_nodes.clear()
	if rig == null or rig.skel == null:
		return
	if upgrades.has("shoes"):
		for leg: int in 4:
			var j: Array = HorseMesh.leg_joints(leg)
			var foot: Vector3 = j[5]
			var g: Node3D = Node3D.new()
			g.name = "Shoe_" + HorseGait.LEG_NAMES[leg]
			Props.cyl(g, Vector3(0, 0.009, 0.0), 0.082, 0.018, "steel")
			for sx: float in [-0.05, 0.05]:   # the studs at the heels
				Props.cyl(g, Vector3(sx, 0.0, 0.05), 0.012, 0.022, "iron")
			_tack_nodes.append(rig.attach("%s_D" % HorseGait.LEG_NAMES[leg], g, foot))
	if upgrades.has("saddle"):
		var sg: Node3D = _model_group("SaddleKit")
		for sx: float in [-1.0, 1.0]:
			Props.block(sg, Vector3(sx * 0.37, 1.10, 0.16), Vector3(sx * 0.5, 1.42, 0.46), "leather", false)       # a saddlebag
			Props.block(sg, Vector3(sx * 0.365, 1.38, 0.15), Vector3(sx * 0.51, 1.44, 0.47), "leather", false)      # its flap
			Props.block(sg, Vector3(sx * 0.505, 1.24, 0.29), Vector3(sx * 0.515, 1.4, 0.33), "brass", false)        # the buckle strap
			Props.block(sg, Vector3(sx * 0.33, 1.42, -0.5), Vector3(sx * 0.43, 1.56, -0.36), "leather", false)      # a knee roll
		Props.block(sg, Vector3(-0.4, 1.555, 0.27), Vector3(0.4, 1.575, 0.35), "leather", false)                  # the strap over the back
		Props.cyl(sg, Vector3(0.0, 1.645, 0.2), 0.075, 0.64, "cloth_green", Vector3(0, 0, 90))                    # the rolled blanket
		for sx2: float in [-0.2, 0.2]:
			Props.cyl(sg, Vector3(sx2, 1.645, 0.2), 0.079, 0.03, "leather", Vector3(0, 0, 90))
		_tack_nodes.append(rig.attach("Body", sg, Vector3.ZERO))
	if upgrades.has("barding"):
		var bg: Node3D = _model_group("Barding")
		Props.block(bg, Vector3(-0.2, 1.0, -0.94), Vector3(0.2, 1.42, -0.86), "leather", false)                   # the breast pad
		for row: int in 3:
			for sx3: float in [-0.12, 0.0, 0.12]:
				Props.cyl(bg, Vector3(sx3, 1.1 + 0.12 * float(row), -0.945), 0.016, 0.012, "iron", Vector3(90, 0, 0))   # its rivets
		for sx4: float in [-1.0, 1.0]:
			Props.block(bg, Vector3(sx4 * 0.2, 0.98, -0.9), Vector3(sx4 * 0.33, 1.44, -0.76), "leather", false)       # round the shoulder
			Props.block(bg, Vector3(sx4 * 0.3, 1.02, -0.8), Vector3(sx4 * 0.39, 1.46, -0.56), "leather", false)
		Props.block(bg, Vector3(-0.31, 1.59, -0.68), Vector3(0.31, 1.615, -0.6), "leather", false)                # the strap over the withers
		_tack_nodes.append(rig.attach("Body", bg, Vector3.ZERO))


## A holder whose children are placed in the model's rest axes (attach it to a bone with rest_point ZERO).
func _model_group(n: String) -> Node3D:
	var g: Node3D = Node3D.new()
	g.name = n
	return g


# ================================================================== mount / dismount

func _begin_mount(p: Player) -> void:
	rider = p
	mode = Mode.MOUNTING
	_t = 0.0
	_from = p.global_position
	_yaw0 = p.rotation.y
	_hold_t = 0.0
	_use_released = false
	dismount_wanted = false
	_since_weapon = 99.0
	pace = 0.0
	speed = 0.0
	steer = 0.0
	_path = PackedVector3Array()
	rides += 1
	add_collision_exception_with(p)
	p.add_collision_exception_with(self)
	if p.is_local:
		p.begin_carry(self)
		p.carry_fire = false
		_set_hands(true)
	_sound("tack", -6.0)
	if rides == 1 or randf() < 0.4:
		_sound("blow", -4.0)
	if rig != null:
		rig.alert = 0.6


func _begin_dismount() -> void:
	if rider == null or mode == Mode.DISMOUNTING:
		return
	mode = Mode.DISMOUNTING
	_t = 0.0
	_from = rider.global_position
	_to = dismount_spot()
	pace = 0.0
	dismounts += 1
	if rider.is_local:
		rider.carry_fire = false
		rider.carry_spread = 0.0
		_set_hands(true)
	_sound("tack", -6.0)


func _finish_dismount() -> void:
	var p: Player = rider
	rider = null
	mode = Mode.LOOSE
	_t = 0.0
	_idle = 0.0
	speed = 0.0
	pace = 0.0
	_hands_on = false   # (end_carry puts the gun back: the next ride sets the hands afresh)
	if p != null and is_instance_valid(p):
		if p.is_local and p.carry == self:
			p.prompt_text = ""
			p.global_position = _to
			p.velocity = Vector3.ZERO
			p.carry_fire = false
			p.end_carry(self)
			if p.is_alive():
				p.land_dip(2.0)
		# the rider may still stand inside the body for a moment: let them step clear before it is solid to them again
		get_tree().create_timer(1.2).timeout.connect(_solid_again.bind(p.get_instance_id()))


func _solid_again(player_iid: int) -> void:
	var p: Player = instance_from_id(player_iid) as Player
	if p != null and is_instance_valid(p) and rider != p:
		remove_collision_exception_with(p)
		p.remove_collision_exception_with(self)


## The rider is thrown or pulled off (downed, gone): no climb down, the body is left beside the horse.
## The host's own check of a rider on another machine (review, 2026-11-12). A client rider who goes down asks
## for the dismount with a Use, but the host has already heard `report_downed` and drops requests from the downed:
## the horse stayed RIDDEN under the body on the host and every other peer, and nobody else could mount it.
func _host_unseats(p: Player) -> bool:
	if p == null or p.is_local or not Net.is_authority() or not (p.downed or p.spectating):
		return false
	Net.mirror(self, &"net_dismount", [global_position, rotation.y])
	_force_off()
	return true


func _force_off() -> void:
	if rider == null:
		return
	forced_off += 1
	_to = dismount_spot()
	_finish_dismount()
	_sound("whinny", -2.0)
	if rig != null:
		rig.shy = 1.0


## Where the rider's feet are while seated (the saddle's seat under their eye).
func seat_feet() -> Vector3:
	var seat: Vector3 = global_transform * rig.point("Body", HorseMesh.SEAT)
	return seat + Vector3.UP * (float(_r.get("eye", 0.8)) - Player.EYE_STAND)


## The first free spot beside the horse (HorseRules.dismount_offsets): floor under it, room for a body, a clear
## line from the saddle. Falls back to the horse's own place (the rider steps out of it: the collision exception
## stays a moment).
func dismount_spot() -> Vector3:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var ex: Array[RID] = [get_rid()]
	if rider != null:
		ex.append(rider.get_rid())
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.6
	for off: Vector3 in HorseRules.dismount_offsets():
		var w: Vector3 = global_transform * off
		var rq: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(w + Vector3.UP * 1.2, w + Vector3.DOWN * 1.0, 1, ex)
		var hit: Dictionary = space.intersect_ray(rq)
		if hit.is_empty() or absf((hit["position"] as Vector3).y - global_position.y) > 0.7:
			continue
		var spot: Vector3 = hit["position"]
		var sq: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		sq.shape = cap
		sq.transform = Transform3D(Basis.IDENTITY, spot + Vector3.UP * 0.9)
		sq.collision_mask = 1 | (1 << 5) | (1 << 8) | (1 << 10)
		sq.exclude = ex
		if not space.intersect_shape(sq, 1).is_empty():
			continue
		var lq: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.1, spot + Vector3.UP * 1.1, 1 | (1 << 8) | (1 << 10), ex)
		if not space.intersect_ray(lq).is_empty():
			continue
		if not _may_stand(spot):
			continue
		return spot
	return global_position


# ================================================================== the frame

func _physics_process(delta: float) -> void:
	_t += delta
	_trample_cd = maxf(0.0, _trample_cd - delta)
	_prev_pos = global_position
	_prev_yaw = rotation.y
	if rider != null and (not is_instance_valid(rider) or not rider.is_inside_tree()):
		rider = null
		mode = Mode.LOOSE
		_idle = 0.0
	_sense(delta)
	match mode:
		Mode.TIED:
			_stand(delta)
		Mode.LOOSE:
			_stand(delta)
			_idle += delta
			_home_wait = maxf(0.0, _home_wait - delta)
			if _home_wait <= 0.0 and HorseRules.home_due(_idle, _flat(global_position, home_pos), rider != null, _blk("home")):
				_start_home()
		Mode.HOMING:
			_tick_home(delta)
		Mode.MOUNTING:
			_stand(delta)
			_tick_mount(delta)
		Mode.RIDDEN:
			_tick_ridden(delta)
		Mode.DISMOUNTING:
			_stand(delta)
			_tick_dismount(delta)
	if rig != null:
		rig.shy = move_toward(rig.shy, _shy, delta * 2.5)
		rig.ears_back = move_toward(rig.ears_back, clampf(_shy * 1.2, 0.0, 1.0), delta * 3.0)
		if mode != Mode.MOUNTING:
			rig.alert = move_toward(rig.alert, 0.5 if _boss_d < 30.0 else (0.25 if rider != null else 0.0), delta * 1.5)
	_update_rope()


func _process(delta: float) -> void:
	if rig == null:
		return
	# the picture between two physics steps (the body moves at the physics rate, the screen may be faster)
	var f: float = Engine.get_physics_interpolation_fraction()
	if _prev_pos.distance_to(global_position) < 2.0:
		rig.global_position = _prev_pos.lerp(global_position, f)
		rig.global_rotation = Vector3(0, lerp_angle(_prev_yaw, rotation.y, f), 0)
	else:
		rig.position = Vector3.ZERO
		rig.rotation = Vector3.ZERO
	# T-265: a horse standing at its rail (or loose) that the camera does not see is posed every RIG_OUT_DIV-th
	# frame with the time it skipped (its breathing, tail and ears: 0.12 ms a frame for a horse nobody looks at)
	_rig_dt += delta
	rig_frames += 1
	if rider == null and (mode == Mode.TIED or mode == Mode.LOOSE) and Zombie.view_lod and Zombie.view_camera(get_viewport()) 			and Zombie.sphere_out_of_view(global_position + Vector3.UP - Zombie.vl_pos, 2.0, Zombie.vl_fwd, Zombie.vl_cos):
		_rig_skip += 1
		if _rig_skip % RIG_OUT_DIV != 0:
			return
	rig_ticks += 1
	rig.tick(_rig_dt)
	_rig_dt = 0.0


const RIG_OUT_DIV: int = 4
var rig_frames: int = 0   # frames drawn / frames the rig was posed in (the measuring tools)
var rig_ticks: int = 0
var _rig_dt: float = 0.0
var _rig_skip: int = 0


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## What is round it: zombies crowding (5 times a second), the nearest homage boss; how hard it shies.
func _sense(delta: float) -> void:
	_crowd_t -= delta
	if _crowd_t > 0.0:
		return
	_crowd_t = 0.2
	var c: Dictionary = _blk("crowd")
	var bf: Dictionary = _blk("boss_fear")
	var rad: float = float(c.get("radius", 4.5))
	var n: int = 0
	_boss_d = INF
	var dir: Node = get_tree().get_first_node_in_group(&"director")
	if dir != null and dir.has_method("active_zombies"):
		for z: Variant in dir.call("active_zombies"):
			var zn: Node3D = z as Node3D
			if zn == null or not is_instance_valid(zn):
				continue
			var d: float = zn.global_position.distance_to(global_position)
			if zn is HomageBoss or str(zn.get("enemy_id")).begins_with("totenross"):   # (a client's copy of a boss is a plain puppet)
				_boss_d = minf(_boss_d, d)
			elif d <= rad:
				n += 1
	var was: float = _shy
	_crowd = n
	_shy = HorseRules.shy_level(n, _boss_d, c, bf)
	if _shy >= 0.99 and was < 0.99:
		shies += 1
		_sound("whinny" if _boss_d <= float(bf.get("radius", 14.0)) else "snort", -2.0)
	# a blow or a snort of its own now and then
	_snd_t -= 0.2
	if _snd_t <= 0.0:
		_snd_t = randf_range(9.0, 24.0)
		_sound("blow" if randf() < 0.7 else "snort", -10.0)


func pace_cap() -> float:
	return HorseRules.pace_cap(_crowd, _boss_d, _blk("crowd"), _blk("boss_fear"))


## Standing: it keeps its feet, gravity holds it down.
func _stand(delta: float) -> void:
	speed = move_toward(speed, 0.0, float(_r.get("brake", 7.5)) * delta)
	pace = 0.0
	steer = HorseRules.steer_step(steer, 0.0, delta, _r)
	_move(delta)


## One step of travel: the pace answers the throttle, the speed the pace, the heading the steer; then the body
## moves, stops at what it cannot pass and refuses a step out of its ground.
func drive(throttle: float, steer_in: float, sprint: bool, delta: float) -> void:
	pace = HorseRules.pace_step(pace, throttle, sprint, delta, _r, pace_cap())
	var want: float = HorseRules.pace_speed(pace, _r)
	var reining: bool = throttle < -0.1
	if reining and pace <= 0.01 and speed <= 0.3:
		want = -float(_r.get("back_speed", 1.0))
	steer = HorseRules.steer_step(steer, steer_in, delta, _r)
	want = minf(want, HorseRules.turn_speed_cap(steer, _r))
	speed = HorseRules.speed_step(speed, want, reining, delta, _r)
	rotation.y -= steer * HorseRules.turn_rate(speed, _r) * delta
	_move(delta)
	_trample()


func _move(delta: float) -> void:
	var fwd: Vector3 = -global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	velocity.x = fwd.x * speed
	velocity.z = fwd.z * speed
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GameState.g_player() * delta
	var before: Vector3 = global_position
	move_and_slide()
	var moved: float = _flat(global_position, before)
	# a wall, a fence, a cart: it stops rather than grind along it
	if absf(speed) > 0.6 and moved < absf(speed) * delta * 0.35:
		_blocked_t += delta
		if _blocked_t > 0.25:
			speed *= 0.4
			pace = minf(pace, 0.6)
	else:
		_blocked_t = 0.0
	if absf(speed) > 0.05 or not is_on_floor():
		# its place, and the end of it that leads (the nose going forward, the quarters backing): a horse is long
		if _may_stand(global_position) and _may_stand(global_position + fwd * (1.3 if speed >= 0.0 else -1.0)):
			_last_ok = global_position
		else:
			# a house door, the tower, the map's edge: it will not go
			global_position = _last_ok
			if absf(speed) > 0.5:
				refusals += 1
				_sound("snort", -3.0)
				if rig != null:
					rig.shy = maxf(rig.shy, 0.7)
			speed = 0.0
			pace = 0.0
	if rig != null:
		rig.speed = speed if moved > absf(speed) * delta * 0.2 or absf(speed) < 0.3 else speed * 0.3
		rig.turn = steer if absf(speed) > 0.2 or absf(steer) > 0.2 else 0.0


## True when the horse may stand at `at` (HorseRules.may_stand): one of its zones, open, near its rail's height. A
## map with no zone volumes (a test scene) has no such rule.
func _may_stand(at: Vector3) -> bool:
	if not _has_zones or zones.is_empty():
		return true
	var z: StringName = ZoneVolume.zone_at(get_tree(), at + Vector3.UP * 0.6)
	return HorseRules.may_stand(z, GameState.is_zone_open(z), at.y, home_pos.y, zones, _blk("bounds"))


## Galloping through the dead: the first within reach of its chest is flung aside (hurt where it lands), the horse
## loses speed, and it does not happen again for a moment. Bosses are not shoved.
func _trample() -> void:
	var tc: Dictionary = _blk("trample")
	var hit: Dictionary = HorseRules.trample(speed, _trample_cd, tc)
	if hit.is_empty() or not Net.is_authority():
		return
	var dir: Node = get_tree().get_first_node_in_group(&"director")
	if dir == null or not dir.has_method("active_zombies"):
		return
	var fwd: Vector3 = -global_basis.z
	var chest: Vector3 = global_position + fwd * 0.9
	for z: Variant in dir.call("active_zombies"):
		var zn: Zombie = z as Zombie
		if zn == null or zn is HomageBoss or zn is Foreman or zn is Screamer:
			continue
		if _flat(zn.global_position, chest) > float(tc.get("radius", 1.25)) or absf(zn.global_position.y - global_position.y) > 1.2:
			continue
		var side: Vector3 = zn.global_position - global_position
		side.y = 0.0
		side = side - fwd * side.dot(fwd)
		if side.length() < 0.05:
			side = fwd.cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0)
		var push: Vector3 = (fwd * 0.25 + side.normalized()).normalized() * float(hit["push"])
		zn.external_push(push, float(hit["push_s"]), rider.player_id if rider != null else 0, &"", float(hit["damage"]))
		if not zn.is_pushed():
			continue   # still rising, at a window, on a ladder: it cannot be flung (and costs the horse nothing)
		speed *= 1.0 - float(hit["slow"])
		pace = minf(pace, 2.2)
		_trample_cd = float(tc.get("cooldown", 0.7))
		tramples += 1
		AudioDirector.play_3d("impact_flesh", zn.global_position + Vector3.UP, 2.0)
		return


# ================================================================== riding

func _tick_mount(delta: float) -> void:
	var p: Player = rider
	if p == null:
		return
	var dur: float = float(_r.get("mount_s", 1.0))
	var k: float = clampf(_t / dur, 0.0, 1.0)
	if _host_unseats(p):
		return
	if p.is_local:
		if not p.is_alive() or p.carry != self:
			_abort_mount()
			return
		# to the stirrup on the near side, then up and over into the saddle
		var stirrup: Vector3 = global_transform * Vector3(-0.78, 0.0, -0.15)
		var seat: Vector3 = seat_feet()
		var pos: Vector3
		var head: Vector3 = Vector3.ZERO
		var roll: float = 0.0
		if k < 0.35:
			var a: float = smoothstep(0.0, 1.0, k / 0.35)
			pos = _from.lerp(Vector3(stirrup.x, _from.y, stirrup.z), a)
			head.y = -0.04 * sin(a * PI)
		else:
			var b: float = smoothstep(0.0, 1.0, (k - 0.35) / 0.65)
			pos = Vector3(stirrup.x, _from.y, stirrup.z).lerp(seat, b) + Vector3.UP * (0.28 * sin(b * PI))
			roll = 0.16 * sin(b * PI)
			head.y = -0.05 * sin(b * PI * 2.0)
		p.rotation.y = lerp_angle(_yaw0, rotation.y, smoothstep(0.0, 1.0, k))
		p.global_position = pos
		p.velocity = Vector3.ZERO
		p.carry_head = head
		p.carry_roll = roll
		p.carry_pitch = 0.1 * sin(k * PI)
		_place_hands(clampf(k * 2.0, 0.0, 1.0))
	if k >= 1.0:
		mode = Mode.RIDDEN
		_t = 0.0
		if _demo_after is Vector3:
			input_override = _demo_after
			_demo_after = null
		if p.is_local:
			p.carry_roll = 0.0
			p.carry_pitch = 0.0
			p.carry_head = Vector3.ZERO


func _abort_mount() -> void:
	var p: Player = rider
	rider = null
	mode = Mode.LOOSE
	_hands_on = false
	if p != null and is_instance_valid(p):
		if p.carry == self:
			p.end_carry(self)
		remove_collision_exception_with(p)
		p.remove_collision_exception_with(self)


func _tick_ridden(delta: float) -> void:
	var p: Player = rider
	if p == null:
		mode = Mode.LOOSE
		return
	if _host_unseats(p):
		return
	if not p.is_local:
		_follow_rider(delta)
		return
	if not p.is_alive() or p.downed or p.carry != self or p.has_status(&"knockdown"):
		# downed in the saddle, or knocked down by a boss's charge or stomp: off the horse (the host hears it as a use
		# by the rider when this is a client)
		if Net.is_client() and Net.session != null:
			Net.session.request_interact(use)
		else:
			Net.mirror(self, &"net_dismount", [global_position, rotation.y])
		_force_off()
		return
	var throttle: float = 0.0
	var st: float = 0.0
	var sprint: bool = false
	var want_off: bool = dismount_wanted
	if input_override is Vector3:
		st = (input_override as Vector3).x
		throttle = (input_override as Vector3).y
		sprint = (input_override as Vector3).z > 0.5
	elif GameState.phase == GameState.Phase.PLAYING and not GameState.input_blocked and not p.bot_driven:
		var v: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back", 0.2)
		st = v.x
		throttle = -v.y
		sprint = Input.is_action_pressed(&"sprint")
		# Use held again (after the mount's own press is let go), or jump: get down
		if not Input.is_action_pressed(&"interact"):
			_use_released = true
			_hold_t = 0.0
		elif _use_released:
			_hold_t += delta
			if _hold_t >= float(_r.get("hold_s", 0.4)):
				want_off = true
		if Input.is_action_just_pressed(&"jump"):
			want_off = true
	var yaw_before: float = rotation.y
	drive(throttle, st, sprint, delta)
	# the rider turns with the horse and may look round within look_free of its nose
	p.rotation.y += wrapf(rotation.y - yaw_before, -PI, PI)
	var free: float = float(_r.get("look_free", 2.2))
	var d: float = wrapf(p.rotation.y - rotation.y, -PI, PI)
	if absf(d) > free:
		p.rotation.y = rotation.y + clampf(d, -free, free)
	_seat_rider(p, delta)
	if want_off:
		dismount_wanted = false
		_use_released = false     # one request: a client waits a round trip for the host's answer, and a request
		_hold_t = 0.0             # every tick was denied (with its sound) once the first had been taken
		p.use_interactable(use)   # the host decides (and mirrors it); solo runs it here


## The rider in the saddle: the body under the seat, the view riding the gait, the hands on the gun or the reins.
func _seat_rider(p: Player, delta: float) -> void:
	p.global_position = seat_feet()
	p.velocity = Vector3.ZERO
	var g: int = rig.gait
	var fc: Dictionary = _blk("fire")
	var sway: float = HorseRules.fire_sway(g, fc)
	var rock: float = HorseRules.view_rock(p.weapons.ads_t if p.weapons != null and p.carry_fire else 0.0, fc)
	var sm: Vector3 = HorseGait.saddle_motion(g, rig.phase)
	p.carry_pitch = sm.y * 0.6 * rock + 0.01 * sway * sin(TAU * 2.0 * rig.phase)
	p.carry_roll = -sm.z * 0.8 * rock - steer * 0.03 * clampf(absf(speed) / 5.0, 0.0, 1.0) + 0.008 * sway * sin(TAU * rig.phase)
	p.carry_head = Vector3(0.012 * sway * sin(TAU * rig.phase), 0.0, 0.0)
	p.carry_fov = 6.0 * clampf((absf(speed) - 5.0) / 4.5, 0.0, 1.0)
	# the way down is said once, for the first seconds in the saddle (the Player shows no prompt while carried)
	p.prompt_text = "Hold [%s] or press [%s] to get down" % [Interactable.prompt_key(&"interact"), Interactable.prompt_key(&"jump")] if _t < 5.0 and rides <= 3 else ""
	# T-262: the gun is up at every gait; at a gallop the hands rest on the reins until the weapon is wanted
	var busy: bool = _weapon_wanted(p)
	_since_weapon = 0.0 if busy else _since_weapon + delta
	var reins: bool = not HorseRules.can_fire(g, mode == Mode.RIDDEN, fc) or HorseRules.on_reins(g, busy, _since_weapon, fc)
	p.carry_fire = not reins
	p.carry_spread = 0.0 if reins or p.weapons == null else HorseRules.fire_spread(g, p.weapons.ads_t, fc)
	if _hands_on and not reins and p.weapons != null and _keys_live(p) and Input.is_action_pressed(&"fire"):
		p.weapons.keep_fire_press()   # the trigger pulled from the reins: the shot goes when the gun is up
	_set_hands(reins)
	if reins:
		_place_hands(1.0)


## True while the rider wants the weapon: the trigger, the sights, a reload, a swap, a grenade, the knife.
func _weapon_wanted(p: Player) -> bool:
	if weapon_override is bool:
		return weapon_override
	var w: WeaponHolder = p.weapons
	if w == null:
		return false
	if w.is_reloading() or w.is_busy() or w.cook_left() >= 0.0:
		return true
	if not _keys_live(p):
		return false
	for a: StringName in [&"fire", &"ads", &"lethal"]:
		if Input.is_action_pressed(a):
			return true
	for a: StringName in [&"reload", &"melee", &"swap_weapon", &"tactical", &"weapon_1", &"weapon_2", &"weapon_3"]:
		if InputMap.has_action(a) and Input.is_action_just_pressed(a):
			return true
	return false


## True while the rider's own keys count (the match is on, no menu has them, no brain drives the body).
func _keys_live(p: Player) -> bool:
	return GameState.phase == GameState.Phase.PLAYING and not GameState.input_blocked and not p.bot_driven


func _set_hands(on: bool) -> void:
	if rider == null or rider.weapons == null or on == _hands_on:
		return
	_hands_on = on
	rider.weapons.set_hands(&"climb" if on else &"")
	rider.weapons.hands_shoulder = 0.0


## The rider's hands on the reins at the pommel (k 0 = hanging down, 1 = on them).
func _place_hands(k: float) -> void:
	var p: Player = rider
	if p == null or p.weapons == null or not _hands_on:
		return
	var g: Array = rig.rein_grips()
	var gw: Array = [global_transform * rig.to_local(g[0]), global_transform * rig.to_local(g[1])]   # (the rig's picture may trail the body by a frame)
	var hr: Vector3 = LadderClimb.HANDS_DOWN_R.lerp(p.weapons.vm_target(gw[0]), k)
	var hl: Vector3 = LadderClimb.HANDS_DOWN_L.lerp(p.weapons.vm_target(gw[1]), k)
	p.weapons.hand_r = Transform3D(HAND_R_BASIS, hr)
	p.weapons.hand_l = Transform3D(HAND_L_BASIS, hl)


func _tick_dismount(delta: float) -> void:
	var p: Player = rider
	if p == null:
		mode = Mode.LOOSE
		return
	var dur: float = float(_r.get("dismount_s", 0.7))
	var k: float = clampf(_t / dur, 0.0, 1.0)
	if p.is_local and p.carry == self:
		var a: float = smoothstep(0.0, 1.0, k)
		p.global_position = _from.lerp(_to, a) + Vector3.UP * (0.22 * sin(a * PI))
		p.velocity = Vector3.ZERO
		p.carry_roll = -0.12 * sin(a * PI)
		p.carry_head = Vector3(0, -0.04 * sin(a * PI), 0)
		p.carry_pitch = 0.0
		p.carry_fov = 0.0
		_place_hands(1.0 - a)
	if k >= 1.0:
		_finish_dismount()


## A peer that does not move this horse: it goes under the rider's replicated body, heading where the rider goes.
func _follow_rider(delta: float) -> void:
	var p: Player = rider
	var seat_local: Vector3 = rig.point("Body", HorseMesh.SEAT) + Vector3.UP * (float(_r.get("eye", 0.8)) - Player.EYE_STAND)
	_puppet_yaw = HorseRules.puppet_yaw(_puppet_yaw, p.velocity, delta)
	rotation.y = _puppet_yaw
	var want: Vector3 = p.global_position - global_basis * seat_local
	var before: Vector3 = global_position
	global_position = want
	speed = _flat(global_position, before) / maxf(delta, 0.0001)
	if rig != null:
		rig.speed = speed
		rig.turn = clampf(wrapf(rotation.y - _prev_yaw, -PI, PI) / maxf(delta, 0.0001), -1.0, 1.0) * -1.0
	_last_ok = global_position
	if Net.is_authority():
		_trample()   # a client's ride: the trample is the host's to decide (drive() never runs here)


# ================================================================== tools (captures, the dev console, the smokes)

## A capture camera's `use` (tools_src/capture.gd): `p` mounts, and once up rides straight on at an easy trot.
func ride(p: Player) -> void:
	_demo_after = Vector3(0.0, 0.55, 0.0)
	on_use(p)


## Rides with a fixed input from now on (steer -1..1 right positive, throttle -1..1, sprint 0 / 1) instead of the keys.
func demo(steer_in: float, throttle: float, sprint: float = 0.0) -> void:
	input_override = Vector3(steer_in, throttle, sprint)


## Stands the horse loose at (x, z) on its rail's level, facing `yaw_deg` (0 = north); at its rail's own place it is
## tied again.
func stand_at(x: float, z: float, yaw_deg: float) -> void:
	if rider != null:
		_force_off()
		forced_off -= 1
	global_position = Vector3(x, home_pos.y, z)
	rotation.y = deg_to_rad(yaw_deg)
	speed = 0.0
	pace = 0.0
	steer = 0.0
	_last_ok = global_position
	_prev_pos = global_position
	_prev_yaw = rotation.y
	_idle = 0.0
	_home_wait = 600.0
	input_override = null
	mode = Mode.TIED if _flat(global_position, home_pos) < 0.2 else Mode.LOOSE


# ================================================================== going home

func _start_home() -> void:
	var map_rid: RID = get_world_3d().navigation_map
	_path = NavigationServer3D.map_get_path(map_rid, global_position, home_pos, true)
	_path_i = 0
	if _path.size() < 2:
		_path = PackedVector3Array([global_position, home_pos])
	mode = Mode.HOMING
	_t = 0.0
	_home_prog_t = 0.0
	_home_prog_from = global_position


func _tick_home(delta: float) -> void:
	var h: Dictionary = _blk("home")
	var arrive: float = float(h.get("arrive_m", 0.5))
	while _path_i < _path.size() - 1 and _flat(global_position, _path[_path_i]) < 0.8:
		_path_i += 1
	var goal: Vector3 = _path[mini(_path_i, _path.size() - 1)]
	var last: bool = _path_i >= _path.size() - 1
	var d: float = _flat(global_position, goal)
	if last and d <= arrive:
		# at the rail: it turns to stand as it was tied
		var off: float = wrapf(home_yaw - rotation.y, -PI, PI)
		speed = move_toward(speed, 0.0, 6.0 * delta)
		pace = 0.0
		if absf(off) < 0.06:
			rotation.y = home_yaw
			mode = Mode.TIED
			homed += 1
			steer = 0.0
			_move(delta)
			return
		steer = HorseRules.steer_step(steer, clampf(-off * 2.0, -1.0, 1.0), delta, _r)
		rotation.y -= steer * HorseRules.turn_rate(0.0, _r) * delta
		_move(delta)
		return
	var to: Vector3 = goal - global_position
	var want_yaw: float = atan2(-to.x, -to.z)
	var off2: float = wrapf(want_yaw - rotation.y, -PI, PI)
	var throttle: float = 1.0 if pace < float(h.get("pace", 1.0)) and absf(off2) < 1.0 else (-0.6 if pace > float(h.get("pace", 1.0)) + 0.1 or absf(off2) > 1.3 else 0.0)
	if last and d < 1.5 and pace > 0.5:
		throttle = -0.5
	drive(throttle, clampf(-off2 * 2.2, -1.0, 1.0), false, delta)
	if pace < 0.3 and absf(off2) < 1.0 and throttle >= 0.0:
		pace = 0.3   # (it steps off)
	# no way on: it stands where it is and tries again later
	_home_prog_t += delta
	if _home_prog_t >= float(h.get("stuck_s", 6.0)):
		if _flat(global_position, _home_prog_from) < 0.6:
			mode = Mode.LOOSE
			_idle = 0.0
			_home_wait = float(h.get("retry_s", 12.0))
			speed = 0.0
			pace = 0.0
		_home_prog_t = 0.0
		_home_prog_from = global_position


# ================================================================== sound, the rail, the rope

func _sound(key: String, db: float = 0.0) -> void:
	var id: String = str(_blk("sounds").get(key, ""))
	if id != "" and AudioDirector.has_sound(id):
		AudioDirector.play_3d(id, global_position + Vector3.UP * 1.6 - global_basis.z * 1.2, db)


## A hoof lands: the sound of what it lands on (snow in the open, boards under a roof, stone on the roads), louder
## with the gait; a puff of snow at a trot and a gallop.
func _on_hoof(leg: int, at: Vector3, gait: int) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _hoof_ms < 45:
		return
	_hoof_ms = now
	var surface: String = hoof_surface(self, at)
	var key: String = str(_blk("sounds").get("hoof", "horse_hoof_")) + surface
	if not AudioDirector.has_sound(key):
		key = "footstep_" + surface
	AudioDirector.play_3d(key, at, [-30.0, -9.0, -5.0, -1.0][clampi(gait, 0, 3)], 0.07)
	if gait >= HorseGait.Gait.TROT and (leg == HorseGait.LF or leg == HorseGait.RF or gait == HorseGait.Gait.GALLOP):
		Effects.dust_puff(at + Vector3.UP * 0.04, "snow" if surface == "snow" else "ground", 4 if gait == HorseGait.Gait.TROT else 7)


## What a hoof lands on at `at`: the floor's "surface" metadata, else snow in the open and boards under a roof on
## the Inn, stone elsewhere.
static func hoof_surface(body: CollisionObject3D, at: Vector3) -> String:
	var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 0.8, 1 | (1 << 8), [body.get_rid()])
	var hit: Dictionary = space.intersect_ray(q)
	if not hit.is_empty():
		var n: Node = hit.get("collider") as Node
		for m: Node in [n, n.get_parent() if n != null else null]:
			if m != null and m.has_meta("surface"):
				var s: String = str(m.get_meta("surface"))
				return s if s in ["snow", "wood", "stone"] else ("stone" if s in ["metal", "concrete"] else "wood")
	var inn: bool = String(GameState.map_id).begins_with("map00")
	var rq: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2.6, at + Vector3.UP * 14.0, 1, [body.get_rid()])
	var roofed: bool = not space.intersect_ray(rq).is_empty()
	if inn:
		return "wood" if roofed else "snow"
	return "stone"


## The lead rope from the rail to the halter while it stands tied.
func _build_rope() -> void:
	if not rail_pos.is_finite():
		return
	_rope = MeshInstance3D.new()
	_rope.name = "LeadRope"
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.011
	cm.bottom_radius = 0.011
	cm.height = 1.0
	cm.radial_segments = 6
	cm.rings = 1
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.45, 0.38, 0.26)
	m.roughness = 0.95
	cm.material = m
	_rope.mesh = cm
	_rope.top_level = true
	_rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rope)


func _update_rope() -> void:
	if _rope == null:
		return
	_rope.visible = mode == Mode.TIED
	if not _rope.visible:
		return
	var a: Vector3 = rail_pos + Vector3.UP * 1.02
	var b: Vector3 = rig.point_global("Head", HorseMesh.head_point(0.5, 0.0, -0.085))
	var d: Vector3 = b - a
	if d.length() < 0.02:
		return
	var up: Vector3 = d.normalized()
	var side: Vector3 = up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.BACK).normalized()
	_rope.global_transform = Transform3D(Basis(side, up, side.cross(up)).scaled(Vector3(1.0, d.length(), 1.0)), (a + b) * 0.5)


## The hitching rail: two posts and a pole, a ring, a hay net and a bucket. Its collider is on the map-edge layer
## (players and bots are stopped, zombies and shots pass), so it never stands in a zombie's baked path.
static func build_rail(parent: Node3D, at: Vector3, yaw_deg: float) -> Node3D:
	var g: Node3D = Node3D.new()
	g.name = "HitchingRail"
	parent.add_child(g)
	g.position = at
	g.rotation.y = deg_to_rad(yaw_deg)
	for sx: float in [-1.1, 1.1]:
		Props.block(g, Vector3(sx - 0.07, 0.0, -0.07), Vector3(sx + 0.07, 1.16, 0.07), "beam")
		Props.block(g, Vector3(sx - 0.09, 1.16, -0.09), Vector3(sx + 0.09, 1.2, 0.09), "snow", false)
	Props.cyl(g, Vector3(0, 1.02, 0), 0.055, 2.5, "pine", Vector3(0, 0, 90))
	Props.block(g, Vector3(-1.2, 1.07, -0.05), Vector3(1.2, 1.09, 0.05), "snow", false)
	Props.cyl(g, Vector3(0.0, 0.96, 0.0), 0.05, 0.02, "iron", Vector3(90, 0, 0))
	Props.ball(g, Vector3(-0.72, 0.62, -0.12), Vector3(0.44, 0.56, 0.36), "hay")           # the hay net
	Props.cable(g, Vector3(-0.72, 1.0, -0.02), Vector3(-0.72, 0.86, -0.1), 0.0, 0.012, 2, "rope")
	Props.cyl(g, Vector3(0.78, 0.16, -0.38), 0.17, 0.32, "tin")                          # the water bucket
	Props.cyl(g, Vector3(0.78, 0.3, -0.38), 0.15, 0.02, "ice")
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "RailCollider"
	body.collision_layer = LAYER_EDGE
	body.collision_mask = 0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(2.4, 1.15, 0.14)
	cs.shape = bs
	cs.position = Vector3(0, 0.575, 0)
	body.add_child(cs)
	g.add_child(body)
	return g


## Spawns every horse the map's json lists under `root` (a "Horses" holder), with its rail. Returns them.
static func spawn_all(root: Node3D, map_id: StringName) -> Array[Horse]:
	var out: Array[Horse] = []
	var path: String = ClimbLink.json_path_for(map_id)
	if path == "" or not (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
		return out
	var rows: Array = GLData.load_json(path).get("horses", [])
	if rows.is_empty():
		return out
	var holder: Node3D = Node3D.new()
	holder.name = "Horses"
	root.add_child(holder)
	var i: int = 0
	for row: Dictionary in rows:
		var h: Horse = Horse.new()
		h.name = str(row.get("name", "Horse_%d" % i))
		h.look = str(row.get("look", "noriker"))
		h.home_pos = ClimbLink._v3(row.get("pos", [0, 0, 0]))
		h.home_yaw = deg_to_rad(float(row.get("yaw", 0.0)))
		h.zones = (row.get("zones", []) as Array).duplicate()
		if row.has("rail"):
			h.rail_pos = ClimbLink._v3(row["rail"])
			h.rail_yaw = float(row.get("rail_yaw", 0.0))
			build_rail(holder, h.rail_pos, h.rail_yaw)
			if not HorseRules.upgrade_rows().is_empty():
				h.tack = HorseTack.at_rail(holder, h)
		h.position = h.home_pos
		h.rotation.y = h.home_yaw
		holder.add_child(h)
		out.append(h)
		i += 1
	return out


## The Use point on the horse (the Player's interaction ray finds its area; a co-op client's use runs on the host).
class HorseUse extends Interactable:
	var horse: Horse = null

	func get_prompt(player: Player) -> String:
		return horse.prompt_for(player) if horse != null else ""

	func can_interact(player: Player) -> bool:
		return horse != null and horse.can_use(player)

	func hold_time(_player: Player) -> float:
		return float(HorseRules.block("ride").get("hold_s", 0.4))

	func interact(player: Player) -> void:
		if horse != null:
			horse.on_use(player)


## T-262: the tack chest by the hitching rail: hold Use on foot to fit the horse's next piece of tack for Scrip. The
## host runs the sale (not net_local); it draws no collider, like the rail's bucket (nothing baked changes).
class HorseTack extends Interactable:
	var horse: Horse = null

	static func at_rail(holder: Node3D, h: Horse) -> HorseTack:
		var tc: Dictionary = HorseRules.block("tack")
		var t: HorseTack = HorseTack.new()
		t.name = String(h.name) + "_Tack"
		t.horse = h
		var us: Array = tc.get("use_size", [0.8, 1.7, 0.8])
		t.interact_size = Vector3(float(us[0]), float(us[1]), float(us[2]))
		t.interact_offset = Vector3(0, float(us[1]) * 0.5, 0)
		t.position = h.rail_pos + Basis(Vector3.UP, deg_to_rad(h.rail_yaw)) * ClimbLink._v3(tc.get("offset", [1.62, 0, 0]))
		t.rotation.y = deg_to_rad(h.rail_yaw)
		holder.add_child(t)
		return t

	func build_greybox() -> void:
		# a carter's chest with its lid back: a breast strap, shoes on a wire, a tin of nails
		Props.block(self, Vector3(-0.3, 0.0, -0.21), Vector3(0.3, 0.36, 0.21), "furniture")
		Props.block(self, Vector3(-0.31, 0.3, -0.22), Vector3(0.31, 0.33, 0.22), "iron", false)
		Props.block(self, Vector3(-0.3, 0.36, 0.19), Vector3(0.3, 0.74, 0.23), "furniture")                 # the lid, standing open
		Props.block(self, Vector3(-0.27, 0.36, -0.18), Vector3(0.27, 0.4, 0.18), "leather", false)             # folded tack
		Props.cyl(self, Vector3(-0.12, 0.44, 0.0), 0.07, 0.014, "steel", Vector3(0, 0, 0))                    # horseshoes
		Props.cyl(self, Vector3(-0.1, 0.455, 0.03), 0.07, 0.014, "steel", Vector3(0, 0, 0))
		Props.cyl(self, Vector3(0.15, 0.44, -0.06), 0.045, 0.08, "tin")                                        # the nails
		Props.block(self, Vector3(-0.05, 0.4, 0.1), Vector3(0.24, 0.47, 0.17), "cloth_green", false)           # a rolled blanket

	func get_prompt(player: Player) -> String:
		return horse.tack_prompt(player) if horse != null and is_instance_valid(horse) else ""

	func can_interact(player: Player) -> bool:
		return horse != null and is_instance_valid(horse) and horse.can_buy(player)

	func interact(player: Player) -> void:
		if horse != null and is_instance_valid(horse):
			horse.on_buy(player)
