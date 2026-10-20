class_name LienCrawler
extends EnemyBase
## Lien Crawler — NEW burrower (BS_ENEMIES §3.1, §6). Travels underground toward Bolt at 5 m/s,
## leaving a trail of popping rivets. Within 3 m the trail stops and the ground bulges (0.5 s
## telegraph: red seal glow, chain rattle, a ground ring), then it surfaces and STAMPS: 6 damage plus
## LIEN on Bolt (8 s; one LIEN at a time, a new stamp refreshes it). It stays up for 1.2 s (chasing at
## 3 m/s, hittable), then re-burrows. Underground only slams reach it: a slam forces it up, stunned
## for 1.5 s. Killing it, or any slam on it, clears LIEN.
## LIEN: every enemy prioritises Bolt, turrets fire 30% faster at him, he takes +15% damage and 1 in 5
## bolts he picks up is garnished to this crawler (dropped back when it dies).
## Elite (Second Mortgage): LIEN lasts 14 s and every stamp also spawns a Vulture Drone.

static var _owner_ref: WeakRef = null

var burrowed: bool = true
var stamps: int = 0
var garnished: int = 0
var _trail_acc: float = 0.0
var _last_trail: Vector3
var _rise: float = 0.0          # 0 underground, 1 surfaced
var _mound: MeshInstance3D
var _seal_mat: StandardMaterial3D
var _stamp_head: Node3D


func B() -> Dictionary:
	return def["burrow"]


## The crawler whose LIEN Bolt currently carries, or null.
static func lien_owner_of(player: Node) -> Node3D:
	if player == null or not is_instance_valid(player):
		return null
	var st: StatusEffects = player.get_node_or_null("Status") as StatusEffects
	if st == null or not st.has(&"lien"):
		return null
	if _owner_ref == null:
		return null
	var o: Node3D = _owner_ref.get_ref() as Node3D
	if o == null or not is_instance_valid(o) or not bool(o.call("is_alive")):
		return null
	return o


static func clear_lien(player: Node) -> void:
	if player != null and is_instance_valid(player):
		var st: StatusEffects = player.get_node_or_null("Status") as StatusEffects
		if st != null:
			st.clear(&"lien")
	_owner_ref = null


func _build_visual() -> void:
	var shell: StandardMaterial3D = EnemyFx.mat(EnemyFx.col(str(def.get("body_color", "#5a5a68"))))
	flash_mats.append(shell)
	var flat: MeshInstance3D = EnemyFx.cyl(visual, 0.7, 0.22, Vector3(0, 0.16, 0), shell, 0.62)      # manhole-sized shell
	(flat.mesh as CylinderMesh).radial_segments = 8
	_seal_mat = EnemyFx.mat(Color("#d42f2f"), Color("#d42f2f"), 0.6)
	EnemyFx.cyl(visual, 0.38, 0.05, Vector3(0, 0.29, 0), _seal_mat)                               # notary seal plate
	EnemyFx.torus(visual, 0.3, 0.4, Vector3(0, 0.3, 0), EnemyFx.mat(Color("#c8a040")))
	_stamp_head = Node3D.new()
	_stamp_head.position = Vector3(0, 0.22, 0.72)
	visual.add_child(_stamp_head)
	EnemyFx.cyl(_stamp_head, 0.08, 0.3, Vector3(0, 0.12, 0), EnemyFx.mat(Color("#2a2a30")))          # stamp handle
	EnemyFx.box(_stamp_head, Vector3(0.42, 0.14, 0.3), Vector3(0, -0.04, 0), EnemyFx.mat(Color("#8a2020")))
	for i: int in 6:
		var a: float = TAU * i / 6.0
		EnemyFx.box(visual, Vector3(0.08, 0.1, 0.3), Vector3(cos(a) * 0.65, 0.06, sin(a) * 0.65), EnemyFx.mat(Color("#2a2a30"))).rotation.y = -a
	_mound = EnemyFx.sphere(self, 0.6, Vector3(0, 0.0, 0), EnemyFx.mat(Color("#6a5a46")), 0.5)
	_mound.set_meta(&"no_rim", true)


func _on_activate() -> void:
	burrowed = true
	stamps = 0
	garnished = 0
	_rise = 0.0
	_last_trail = global_position
	_set_burrowed_physics(true)


func _initial_state() -> int:
	return State.CHASE if aggro else State.IDLE


func _owns_visual_y() -> bool:
	return true


func _set_burrowed_physics(b: bool) -> void:
	burrowed = b
	collision_layer = 0 if b else LAYER_ENEMY
	hitbox.collision_layer = 0 if b else LAYER_HITBOX


func get_center() -> Vector3:
	return global_position + Vector3(0, 0.15 if burrowed else height * 0.5, 0)


func add_garnished(n: int) -> void:
	garnished += n
	stolen += n


func _accepts_hit(hit: Combat.Hit) -> bool:
	if hit.is_slam:
		LienCrawler.clear_lien_if_owner(self)
		if burrowed:
			_surface_now()
			stagger(float(B()["slam_stun"]))
		return true
	return not burrowed


static func clear_lien_if_owner(c: LienCrawler) -> void:
	if _owner_ref != null and _owner_ref.get_ref() == c:
		clear_lien(c.get_tree().get_first_node_in_group(&"player"))


func _surface_now() -> void:
	_set_burrowed_physics(false)
	_rise = 1.0


func _idle_update(_dt: float) -> void:
	desired_vel = Vector3.ZERO


func _position_update(dt: float) -> void:
	if not burrowed:
		# surfaced outside an attack (after a stagger): dive back under
		desired_vel = Vector3.ZERO
		_rise = maxf(0.0, _rise - dt / float(B()["dive_time"]))
		if _rise <= 0.0 and can_move():
			_set_burrowed_physics(true)
		return
	var d: float = flat_dist_to_target()
	if d < float(B()["surface_range"]) and can_attack() and target_alive():
		if AttackTokens.request_melee(self, target_onscreen()):
			begin_telegraph(&"stamp", float(telegraph_def(&"stamp").get("dur", 0.5)))
			return
	steer_toward(target_pos(), float(B()["speed_under"]))
	_trail(dt)


func _trail(_dt: float) -> void:
	if global_position.distance_to(_last_trail) < float(B()["trail_every"]) or get_parent() == null:
		return
	_last_trail = global_position
	var rivet: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.06
	cm.bottom_radius = 0.1
	cm.height = 0.08
	rivet.mesh = cm
	rivet.material_override = EnemyFx.mat(Color("#9a9aa8"), Color("#d42f2f"), 0.4)
	get_parent().add_child(rivet)
	rivet.global_position = global_position + Vector3(randf_range(-0.2, 0.2), 0.04, randf_range(-0.2, 0.2))
	get_tree().create_timer(float(B()["trail_life"])).timeout.connect(rivet.queue_free)


func _telegraph_update(_dt: float) -> void:
	var k: float = 1.0 - clampf(tele_t / maxf(tele_dur, 0.01), 0.0, 1.0)
	_mound.scale = Vector3.ONE * (1.0 + k * 0.6)                      # the ground bulges
	_seal_mat.emission_energy_multiplier = 0.6 + k * 4.0


func _attack_begin() -> void:
	_mound.scale = Vector3.ONE
	if status.has(&"rooted"):
		_surface_now()                 # Root Canal on its lane: held as it surfaces
		stagger(float(B()["slam_stun"]))
		return
	_surface_now()
	stamps += 1
	if target_alive() and flat_dist_to_target() < float(B()["stamp_reach"]) and not target_dodging():
		hurt_target(float(def["dmg"]), 3.0)
		if target.is_in_group(&"player"):
			var L: Dictionary = S["lien"]
			var st: StatusEffects = EnemyBase.player_status(target)
			st.clear(&"lien")
			st.apply(&"lien", float(L["elite_duration"]) if elite else float(L["duration"]))
			_owner_ref = weakref(self)
	if elite and get_parent() != null:
		EnemySpawner.spawn(StringName(str(def["elite"]["spawn"])), global_position + Vector3(0, 4, 0), get_parent(), {"aggro": true})


func _attack_update(_dt: float) -> bool:
	return state_t >= 0.15


func _recover_update(dt: float) -> bool:
	var st_t: float = float(B()["surface_time"])
	if state_t < st_t:
		steer_toward(target_pos(), float(B()["speed_surface"]))
		return false
	desired_vel = Vector3.ZERO
	_rise = maxf(0.0, 1.0 - (state_t - st_t) / float(B()["dive_time"]))
	if _rise <= 0.0:
		_set_burrowed_physics(true)
		return true
	var _u: float = dt
	return false


func _on_attack_cancelled() -> void:
	_mound.scale = Vector3.ONE


func _on_died(_hit: Combat.Hit) -> void:
	LienCrawler.clear_lien_if_owner(self)


func _anim(delta: float) -> void:
	if state == State.ATTACK or (not burrowed and state != State.RECOVER):
		_rise = minf(1.0, _rise + delta / 0.15)
	visual.position.y = lerpf(-0.5, 0.0, _rise)
	_mound.visible = _rise < 0.9
	_mound.position.y = -0.05
	if _stamp_head != null:
		_stamp_head.position.y = 0.22 + (0.25 if state == State.TELEGRAPH else 0.0)
