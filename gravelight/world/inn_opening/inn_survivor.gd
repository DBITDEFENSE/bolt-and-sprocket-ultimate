class_name InnSurvivor
extends Interactable
## One of the survivors hiding upstairs at the Crossroads Inn (T-077; data: data/gravelight/map00_survivors.json,
## run by InnSurvivors). Drawn by a PatronBody (cower / aim poses); no collider and no hitboxes, so players' and
## bots' shots pass through and nobody is blocked. The node is an Interactable: hold interact on a hiding survivor to
## pay for a rifle and arm them, on a downed one to help them up. Zombies go for them through Zombie.prey (this node
## answers is_catchable() and struck(zombie)).
##
## States: HIDDEN (not in the world: before the stair door is opened), HIDING (cowering in the guest room), WALKING
## (armed, on the way to the post in the hall), ARMED (holding the post, shooting what it sees), DOWNED (armed and
## knocked down: a player can help them up until the bleed-out), DEAD (fallen; rises after a warning), RISEN (gone:
## a zombie stands where they fell). Host-authoritative: the host runs the rules and InnSurvivors mirrors each change.

enum State { HIDDEN, HIDING, WALKING, ARMED, DOWNED, DEAD, RISEN }

var sid: String = ""
var row: Dictionary = {}
var display: String = ""
var manager: Node = null   # InnSurvivors
var body: PatronBody = null
var state: State = State.HIDDEN
var hp: float = 0.0
var armed_by: int = 0
var kills: int = 0
var shots: int = 0
var swipes_taken: int = 0
var target: Zombie = null
var risen_zombie: Zombie = null
## State timers (host): the bleed-out, the time since death, the gun's cooldown, the next scared line.
var bleed_left: float = 0.0
var dead_t: float = 0.0
var fire_cd: float = 0.0
var next_scared: float = 0.0
var said_reveal: bool = false
var _path: PackedVector3Array = PackedVector3Array()
var _pi: int = 0
var _pick_t: float = 0.0
var _fight_cd: float = 0.0
var _flinch_cd: float = 0.0
var _warned: bool = false


## Built by InnSurvivors from a survivors[] row of map00_survivors.json.
func setup(r: Dictionary, mgr: Node) -> void:
	row = r
	sid = str(r.get("id", "survivor"))
	display = str(r.get("display", sid.to_upper()))
	manager = mgr
	name = "Survivor_" + sid
	interact_size = Vector3(1.0, 1.5, 1.0)
	interact_offset = Vector3(0, 0.6, 0)


func _ready() -> void:
	super._ready()
	body = PatronBody.new()
	add_child(body)
	var look_row: Dictionary = row.duplicate(true)
	look_row["pose"] = "cower"
	body.setup(look_row)
	body.name = "Body"
	body.enable_life()   # T-246
	position = _v3(row.get("hide", [0, 0, 0]))
	rotation.y = deg_to_rad(float(row.get("hide_yaw", 0.0)))
	_set_present(false)


static func _v3(a: Variant) -> Vector3:
	var arr: Array = a as Array if a is Array else []
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2])) if arr.size() >= 3 else Vector3.ZERO


func build_greybox() -> void:
	pass   # the PatronBody is the visual


func ally() -> Dictionary:
	return manager.get("cfg").get("ally", {}) if manager != null else {}


func arm_cfg() -> Dictionary:
	return manager.get("cfg").get("arm", {}) if manager != null else {}


## Shown and usable, or not in the world at all.
func _set_present(on: bool) -> void:
	visible = on
	if area != null:
		area.collision_layer = LAYER_INTERACTABLE if on else 0


# ================================================================== the prompt (any peer, from mirrored state)

func get_prompt(player: Player) -> String:
	match state:
		State.HIDING:
			var a: Dictionary = arm_cfg()
			return "Hold [%s] to arm %s with a %s [%s]" % [prompt_key(&"interact"), str(row.get("name", display)), str(a.get("weapon_name", "rifle")), price_str(player, int(a.get("cost", 750)))]
		State.DOWNED:
			return "Hold [%s] to help %s up" % [prompt_key(&"interact"), str(row.get("name", display)).get_slice(" ", 0)]
	return ""


func can_interact(_player: Player) -> bool:
	return state == State.HIDING or state == State.DOWNED


func hold_time(_player: Player) -> float:
	if state == State.DOWNED:
		return float(ally().get("revive_hold", 2.5))
	return float(arm_cfg().get("hold_seconds", 1.0))


## The host runs it (a client's hold is forwarded): pay and arm, or help them up.
func interact(player: Player) -> void:
	if not Net.is_authority():
		return
	if state == State.HIDING:
		if try_purchase(player, &"arm_survivor", int(arm_cfg().get("cost", 750))):
			manager.call("arm", self, player.player_id)
	elif state == State.DOWNED:
		manager.call("revive", self, player.player_id)


# ================================================================== Zombie.prey

func is_catchable() -> bool:
	return visible and (state == State.HIDING or state == State.WALKING or state == State.ARMED)


## A zombie's swipe landed (host).
func struck(by: Node) -> void:
	if not Net.is_authority() or not is_catchable():
		return
	swipes_taken += 1
	hp -= float(ally().get("swipe_damage", 45.0))
	manager.call("on_struck", self, by)


# ================================================================== per frame

func _physics_process(delta: float) -> void:
	if state == State.HIDDEN or state == State.RISEN:
		return
	_fight_cd = maxf(0.0, _fight_cd - delta)
	_flinch_cd = maxf(0.0, _flinch_cd - delta)
	match state:
		State.WALKING:
			if _follow(delta):
				if Net.is_authority():
					manager.call("set_state", self, State.ARMED)
		State.ARMED:
			if Net.is_authority():
				_fight(delta)
			elif target != null and is_instance_valid(target):
				_face(target.global_position, delta)
		State.DOWNED:
			if Net.is_authority():
				bleed_left -= delta
				if bleed_left <= 0.0:
					manager.call("kill", self)
		State.DEAD:
			if Net.is_authority():
				dead_t += delta
				manager.call("tick_dead", self)


## Walks the path to the post; true once there.
func _follow(delta: float) -> bool:
	var step: float = float(ally().get("walk_speed", 2.2)) * delta
	while _pi < _path.size():
		var goal: Vector3 = _path[_pi]
		var here: Vector3 = global_position
		var to: Vector3 = goal - here
		var d: float = to.length()
		if d <= step:
			global_position = goal
			step -= d
			_pi += 1
			continue
		global_position = here + to / d * step
		_face(goal, delta)
		return false
	return true


func start_walk(post: Vector3) -> void:
	var map_rid: RID = get_world_3d().navigation_map
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map_rid, global_position, post, true)
	if path.is_empty() or path[path.size() - 1].distance_to(post) > 1.0:
		path = PackedVector3Array([post])   # no path (a test map): walk straight there
	else:
		path.append(post)
		path = shape_path(get_world_3d().direct_space_state, path)
	_path = path
	_pi = 0


## T-143 (the walkers with no collider walk the navmesh path as it is): the path's corners hug a doorway's jamb (a 1.5 m
## door leaves a 0.3 m strip to it: the shoulder went through the wall) and its points sit where the navmesh floats, up
## to 0.5 m over the floor (they walked in the air). Every inner corner is pushed to 0.5 m from the walls round it
## (eight chest-high rays), every point is put on the floor (a ray down); the first and last stay where they are.
static func shape_path(space: PhysicsDirectSpaceState3D, path: PackedVector3Array) -> PackedVector3Array:
	var dense: PackedVector3Array = PackedVector3Array()
	for i: int in path.size():
		if i > 0:
			var n: int = int(path[i - 1].distance_to(path[i]) / 0.3)   # (a segment can run along a jamb between its corners)
			for k: int in range(1, n + 1):
				dense.append(path[i - 1].lerp(path[i], float(k) / float(n + 1)))
		dense.append(path[i])
	var out: PackedVector3Array = PackedVector3Array()
	for i2: int in dense.size():
		var p: Vector3 = dense[i2]
		if i2 > 0 and i2 < dense.size() - 1:
			p = clear_of_walls(space, p, 0.5)
		if i2 < dense.size() - 1:
			p = on_floor(space, p)
		out.append(p)
	return out


static func clear_of_walls(space: PhysicsDirectSpaceState3D, p: Vector3, want_m: float) -> Vector3:
	for _pass: int in 3:
		var push: Vector3 = Vector3.ZERO
		var chest: Vector3 = p + Vector3.UP * 0.3
		for k: int in 8:
			var a: float = TAU * float(k) / 8.0
			var dir: Vector3 = Vector3(cos(a), 0.0, sin(a))
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(chest, chest + dir * want_m, 1)
			var hit: Dictionary = space.intersect_ray(q)
			if not hit.is_empty():
				push -= dir * (want_m - chest.distance_to(hit["position"] as Vector3))
		if push.length() < 0.01:
			break
		p += push.limit_length(0.4)
	return p


static func on_floor(space: PhysicsDirectSpaceState3D, p: Vector3) -> Vector3:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.8, p + Vector3.DOWN * 1.2, 1)
	var hit: Dictionary = space.intersect_ray(q)
	return Vector3(p.x, (hit["position"] as Vector3).y, p.z) if not hit.is_empty() else p


func _face(p: Vector3, delta: float) -> void:
	var to: Vector3 = p - global_position
	if Vector2(to.x, to.z).length() < 0.05:
		return
	var want: float = atan2(-to.x, -to.z)
	rotation.y = lerp_angle(rotation.y, want, clampf(delta * float(ally().get("turn_speed", 8.0)), 0.0, 1.0))


func _eye() -> Vector3:
	return global_position + Vector3.UP * 1.5


## Holding the post (host): pick the nearest zombie in range and in sight, turn to it, fire on the cooldown.
func _fight(delta: float) -> void:
	var a: Dictionary = ally()
	fire_cd -= delta
	_pick_t -= delta
	if _pick_t <= 0.0:
		_pick_t = 0.3
		target = pick_target()
	if target == null or not is_instance_valid(target) or not target.is_active():
		target = null
		var py: float = deg_to_rad(float(row.get("post_yaw", 0.0)))
		rotation.y = lerp_angle(rotation.y, py, clampf(delta * 2.0, 0.0, 1.0))
		return
	_face(target.global_position, delta)
	if fire_cd <= 0.0:
		fire_cd = float(a.get("fire_interval", 1.5))
		manager.call("shoot", self, target)


## The nearest active zombie within range with a clear line from the eye to its chest (walls and doors block).
func pick_target() -> Zombie:
	var dir: ZombieDirector = manager.call("director") as ZombieDirector
	if dir == null:
		return null
	var rng_m: float = float(ally().get("range", 20.0))
	var best: Zombie = null
	var best_d: float = rng_m * rng_m
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for z: Zombie in dir.active_zombies():
		if z.state == Zombie.State.EMERGE or z.state == Zombie.State.TO_WINDOW or z.state == Zombie.State.WAIT_WINDOW:
			continue   # still outside
		var d2: float = z.global_position.distance_squared_to(global_position)
		if d2 >= best_d:
			continue
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(_eye(), z.global_position + Vector3.UP * 1.3, 1 | (1 << 8))
		if not space.intersect_ray(q).is_empty():
			continue
		best = z
		best_d = d2
	return best


## Shown on every peer: the flash, the report and the tracer, the body turned to the shot.
func show_shot(to: Vector3) -> void:
	shots += 1
	var mz: Vector3 = global_position + Vector3.UP * 1.45 + (-global_basis.z) * 0.9
	var flat: Vector3 = to - global_position
	if Vector2(flat.x, flat.z).length() > 0.05:
		rotation.y = atan2(-flat.x, -flat.z)
	AudioDirector.play_3d("fire_" + str(arm_cfg().get("weapon", "kar98k")), mz, -1.0, 0.08)
	Effects.tracer(mz, to, false, &"bolt")
	body.set("_jolt", 0.25)   # the recoil


## A shot close by (any peer): a hiding survivor ducks.
func on_gunfire(origin: Vector3) -> bool:
	if state != State.HIDING:
		return false
	var r: float = float(ally().get("flinch_radius", 14.0))
	if origin.distance_squared_to(global_position) > r * r:
		return false
	body.flinch()
	if _flinch_cd > 0.0:
		return false
	_flinch_cd = float(ally().get("flinch_line_cooldown", 6.0))
	return true


func fight_line_ready() -> bool:
	if _fight_cd > 0.0:
		return false
	_fight_cd = float(ally().get("fight_line_cooldown", 12.0))
	return true


## Applies a state on any peer (InnSurvivors.set_state / _net_state): pose, prompt, visibility.
func apply_state(s: State, at: Vector3, yaw: float) -> void:
	var prev: State = state
	state = s
	if prev == State.HIDDEN and s != State.HIDDEN:
		_set_present(true)
	global_position = at
	rotation.y = yaw
	match s:
		State.HIDDEN:
			_set_present(false)
		State.HIDING:
			body.set_pose(&"cower")
			body.show_rifle(false)
		State.WALKING:
			body.show_rifle(true)
			body.set_pose(&"stand")
			start_walk(_v3(row.get("post", [0, 0, 0])))
		State.ARMED:
			body.show_rifle(true)
			body.set_pose(&"aim")
			fire_cd = float(ally().get("first_shot_delay", 0.6))
		State.DOWNED:
			body.set_pose(&"fall")
			target = null
		State.DEAD:
			if prev != State.DOWNED:
				body.set_pose(&"fall")
			body.show_rifle(false)
			target = null
			dead_t = 0.0
			_warned = false
		State.RISEN:
			_set_present(false)


func warned() -> bool:
	return _warned


func set_warned() -> void:
	_warned = true
