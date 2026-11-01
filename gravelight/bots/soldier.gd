class_name Soldier
extends CharacterBody3D
## T-142 (UPDATE 09 section 4, contract C5): one soldier of a relief squad. A light actor, not a Player: a capsule on
## the player layer (zombies bump it, the players' bullets pass through it), a SoldierBody puppet (the dressed body,
## the gun), a SoldierBrain. Zombies hunt it through their `prey` hook (ReliefSquad hands nearby zombies a soldier;
## Zombie._update_prey calls is_catchable() and struck()).
## Health: down at 0 (down_seconds to bleed out; each zombie hit while down takes 4 s off), revived once by a squad
## mate (SoldierBrain), dead at the end of the bleed-out: ReliefSquad drops its loot and lets it rise 4-8 s later.
## Online: host-authoritative; a client builds a puppet (`puppet`, an InterpBuffer fed by NetMatch's soldier
## snapshot: position, yaw, anim flags, alive / down).

signal downed(s: Soldier)
signal died(s: Soldier)

enum State { ACTIVE, DOWN, DEAD }
const STATE_NAMES: PackedStringArray = ["active", "down", "dead"]
const LAYER_PLAYER: int = 1 << 1
const MASK_MOVE: int = 1 | (1 << 8)   # world | doors
## Net anim bits (the snapshot's flags byte): the RemoteBody PF_* flags plus these.
const NF_REVIVE: int = 128

var squad: ReliefSquad = null
var idx: int = 0
var faction: Dictionary = {}
var look: Dictionary = {}
var tag: String = ""
var marked: bool = false
var weapon_id: StringName = &""
var wrow: Dictionary = {}
var max_hp: float = 150.0
var hp: float = 150.0
var state: State = State.ACTIVE
var revives_left: int = 1
var leaving: bool = false
var survivor: bool = false
var speed_mult: float = 1.0
var aim_mult: float = 1.0
var brain: SoldierBrain = null
var body: SoldierBody = null
var net_id: int = -1
var puppet: bool = false
var interp: InterpBuffer = null
var anim_flags: int = 0
var events: PackedStringArray = []

var _down_t: float = 0.0
var _revive_hold: float = 0.0
var _move_v: Vector3 = Vector3.ZERO
var _running: bool = false
var _pitch: float = 0.0
var _grav: float = 9.8


## Builds the soldier: its look (kit + seed), weapon, health and body. `host` = false builds a client puppet.
func setup(sq: ReliefSquad, i: int, fac: Dictionary, seed_v: int, weapon: StringName, host: bool = true) -> void:
	squad = sq
	idx = i
	faction = fac
	var kit_id: String = str(fac.get("kit", "partisan"))
	var k: Dictionary = SoldierKits.kit(kit_id)
	look = SoldierKits.roll_look(kit_id, seed_v, k)
	marked = bool(fac.get("marked", false))
	tag = SoldierKits.tag_of(kit_id, seed_v, marked)
	weapon_id = weapon
	wrow = (GLData.table("weapons").get("weapons", {}) as Dictionary).get(String(weapon), {})
	max_hp = float(k.get("hp", 150.0))
	hp = max_hp
	speed_mult = float(k.get("speed_mult", 1.0))
	aim_mult = float(k.get("aim_mult", 1.0))
	revives_left = int(ReliefSquad.cfg().get("revives_each", 1))
	name = "Soldier_%s_%d" % [str(fac.get("id", "x")), i]
	add_to_group(&"soldiers")
	collision_layer = LAYER_PLAYER
	collision_mask = MASK_MOVE
	var cs: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.75
	cs.shape = cap
	cs.position = Vector3(0, 0.875, 0)
	add_child(cs)
	_grav = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * GameState.gravity_scale
	puppet = not host
	if puppet:
		interp = InterpBuffer.new()
		collision_layer = 0
	else:
		brain = SoldierBrain.new()
		brain.setup(self)
	body = SoldierBody.new()
	body.name = "Body"
	add_child(body)
	body.setup_soldier(look, 300 + i, weapon)


# ================================================================== the weapon (weapons.json row)

func mag_size() -> int:
	return maxi(1, int(wrow.get("mag", 10)))


func reload_seconds() -> float:
	return float(wrow.get("reload_empty", 2.5)) * 1.15


func weapon_class() -> String:
	return str(wrow.get("class", "rifle"))


func weapon_damage() -> float:
	return float(wrow.get("damage", 50.0))


func pellets() -> int:
	return int(wrow.get("pellets", 1))


func is_auto() -> bool:
	return str(wrow.get("mode", "semi")) == "auto"


func shot_interval() -> float:
	return SoldierBrain.shot_interval(float(wrow.get("rpm", 300.0)))


func max_range() -> float:
	var mr: Dictionary = (GLData.load_json("res://data/gravelight/ai/combat.json").get("aim", {}) as Dictionary).get("max_range_m", {}) if _mr_cache.is_empty() else _mr_cache
	_mr_cache = mr
	return float(mr.get(weapon_class(), 40.0))
var _mr_cache: Dictionary = {}


func height_k() -> float:
	return float(look.get("height", 1.0))


# ================================================================== driven by the brain

func set_move(v: Vector3, running: bool) -> void:
	_move_v = v
	_running = running


func turn_toward(p: Vector3, delta: float) -> void:
	var d: Vector3 = p - global_position
	var flat_d: float = Vector2(d.x, d.z).length()
	if flat_d > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), clampf(delta * 8.0, 0.0, 1.0))
	_pitch = atan2(d.y - 1.2, maxf(0.5, flat_d)) if flat_d > 0.05 else 0.0


func kneel_revive() -> void:
	_revive_hold = 0.25
	if body != null:
		body.hold_action(&"revive")


func on_fired(from: Vector3, end: Vector3) -> void:
	if body != null:
		body.fire(0, weapon_id, from, end)
	if squad != null:
		squad.on_soldier_fired(self, end)


# ================================================================== the frame

func _physics_process(delta: float) -> void:
	if puppet:
		_puppet_tick(delta)
		return
	_revive_hold = maxf(0.0, _revive_hold - delta)
	match state:
		State.ACTIVE:
			if brain != null:
				brain.tick(delta)
		State.DOWN:
			_move_v = Vector3.ZERO
			_down_t -= delta
			if _down_t <= 0.0:
				die()
		State.DEAD:
			_move_v = Vector3.ZERO
	velocity.x = _move_v.x
	velocity.z = _move_v.z
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= _grav * delta
	move_and_slide()
	anim_flags = _flags()
	if body != null:
		body.update_pose(delta, Vector2(velocity.x, velocity.z).length(), _pitch, anim_flags)


func _flags() -> int:
	var f: int = 0
	if is_on_floor():
		f |= NetMatch.PF_FLOOR
	if state != State.ACTIVE:
		f |= NetMatch.PF_DOWNED
	elif _running:
		f |= NetMatch.PF_SPRINT
	if brain != null and brain._reload_t > 0.0:
		f |= NetMatch.PF_RELOAD
	if _revive_hold > 0.0:
		f |= NF_REVIVE
	return f


func _puppet_tick(delta: float) -> void:
	if interp == null or Net.session == null:
		return
	interp.sample(Net.session.render_time_ms())
	var prev: Vector3 = global_position
	global_position = interp.pos
	rotation.y = interp.yaw
	anim_flags = interp.flags
	var st: int = interp.aux
	state = clampi(st, 0, 2) as State
	if (anim_flags & NF_REVIVE) != 0 and body != null:
		body.hold_action(&"revive")
	var spd: float = Vector2(global_position.x - prev.x, global_position.z - prev.z).length() / maxf(0.001, delta)
	if body != null:
		body.update_pose(delta, spd, 0.0, anim_flags & 0x7F)


# ================================================================== being hunted (Zombie prey hook)

## Zombie._update_prey: still worth going for (standing or down; the dead are left for the rise).
func is_catchable() -> bool:
	return not puppet and state != State.DEAD and is_inside_tree()


## Zombie._update_prey_attack: the swipe landed.
func struck(z: Node) -> void:
	var dmg: float = 50.0
	if z != null:
		var zc: Variant = z.get("_cfg")
		if zc is Dictionary:
			dmg = float((zc as Dictionary).get("damage", 50.0))
	take_hit(dmg * (squad.damage_taken_mult(self) if squad != null else 1.0))


func take_hit(amount: float) -> void:
	if puppet or state == State.DEAD:
		return
	if state == State.DOWN:
		_down_t -= 4.0
		return
	hp -= amount
	if squad != null:
		squad.on_soldier_hurt(self)
	if hp <= 0.0:
		go_down()


func go_down() -> void:
	if state != State.ACTIVE:
		return
	state = State.DOWN
	hp = 0.0
	_down_t = float(ReliefSquad.cfg().get("down_seconds", 12.0))
	events.append("down")
	downed.emit(self)


## A squad mate's revive (SoldierBrain): back up at half health. False when it came too late.
func revive() -> bool:
	if state != State.DOWN:
		return false
	state = State.ACTIVE
	hp = max_hp * 0.5
	events.append("revived")
	return true


func die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	hp = 0.0
	collision_layer = 0
	events.append("dead")
	died.emit(self)


func is_alive() -> bool:
	return state != State.DEAD


func state_name() -> String:
	return STATE_NAMES[state]
