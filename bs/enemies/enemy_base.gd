class_name EnemyBase
extends CharacterBody3D
## Shared enemy body + AI framework for Bolt & Sprocket (BS_ENEMIES.md §2). Implements the damageable
## contract (groups "damageable" + "enemies"; take_damage / get_center / is_alive / radius / "Status").
##
## Data: a def from data/bs/enemies.json (EnemySpawner passes it; a bare .new() loads it by `id`).
## State machine (§2.2):
##   SPAWN -> (HIDDEN -> REVEAL) -> IDLE/PATROL -> CHASE  (CHASE = the archetype's POSITION state)
##   CHASE <-> TELEGRAPH -> ATTACK -> RECOVER -> CHASE
##   any -> STATUS (frozen / dancing / gravity_clumped), STAGGER (stun), LAUNCHED; CHASE -> LEASH_RETURN
##   any -> DEAD (enemy_killed, chunks, bolt fountain, then back to the pool)
## A telegraph is cancelled (not delayed) by stun, frozen, dancing, clumped, launch or a boss BREAK.
##
## Subclass hooks (all optional):
##   _build_visual()            greybox meshes into `visual`; push hit-flash materials to flash_mats
##   _initial_state() -> int    SPAWN goes here (HIDDEN for ambush/burrow)
##   _position_update(dt)       CHASE behaviour; set desired_vel and call try_attack()/begin_telegraph()
##   _telegraph_update(dt)      pose while winding up
##   _attack_begin()            the telegraph finished
##   _attack_update(dt) -> bool return true when the attack is over (goes to RECOVER)
##   _on_attack_cancelled()     undo the pose
##   _on_hurt(hit, amount, crit)
##   _weak_point_pos() -> Vector3, weak_point_exposed() -> bool
##   _on_died(hit)
##
## Telegraphs emit `telegraphed(kind, sfx, duration)` for the audio/FX layer (no sound is played here).

signal died(enemy: EnemyBase)
signal state_changed(from: int, to: int)
signal telegraphed(kind: StringName, sfx: StringName, duration: float)
signal attacked(kind: StringName)
signal escaped(enemy: EnemyBase)

enum State { SPAWN, HIDDEN, REVEAL, IDLE, PATROL, CHASE, TELEGRAPH, ATTACK, RECOVER, STAGGER, LAUNCHED, STATUS, LEASH_RETURN, DEAD }
const STATE_NAMES: PackedStringArray = ["spawn", "hidden", "reveal", "idle", "patrol", "chase", "telegraph", "attack",
	"recover", "stagger", "launched", "status", "leash_return", "dead"]

const LAYER_ENEMY: int = 1 << 2
const LAYER_HITBOX: int = 1 << 3
const MASK_WORLD: int = 1 | (1 << 5)

static var _repath_frame: int = -1
static var _repath_count: int = 0

var id: StringName = &""
var def: Dictionary = {}
var G: Dictionary = {}                  # enemies.json globals
var S: Dictionary = {}                  # statuses.json
var arch: StringName = &"chaser"
var hp: float = 10.0
var max_hp: float = 10.0
var radius: float = 0.6
var height: float = 1.0
var heavy: bool = false
var elite: bool = false
var is_add: bool = false
var drops: int = 0
var stolen: int = 0                     # extra bolts carried (vulture loot, garnish) dropped on death
var dmg_mult: float = 1.0
var speed: float = 3.6
var state: int = State.SPAWN
var state_t: float = 0.0
var home: Vector3 = Vector3.ZERO
var leash: float = 9.0
var aggro_radius: float = 14.0
var aggro: bool = false
var target: Node3D = null
var desired_vel: Vector3 = Vector3.ZERO  # AI-requested velocity (horizontal for ground units)
var knock_vel: Vector3 = Vector3.ZERO
var launch_vy: float = 0.0
var contact_cd: float = 0.0
var fire_cd: float = 0.0
var stun_t: float = 0.0
var flash_t: float = 0.0
var spawn_invuln: float = 0.0
var t: float = 0.0
var lod: int = 0
var pooled: bool = false
var last_hit: Combat.Hit = null
var attack_kind: StringName = &""
var tele_t: float = 0.0
var tele_dur: float = 0.0
var last_telegraph: Dictionary = {}     # {"kind", "dur", "started"} (AttackTokens.clock) for tests/HUD
var gravity_on: bool = true
var override_point: Vector3 = Vector3.INF   # when set, the body is driven to this point this frame
var status: StatusEffects
var visual: Node3D
var flash_mats: Array[StandardMaterial3D] = []
var tele_light: OmniLight3D
var nav: NavigationAgent3D
var hitbox: Area3D
var opts: Dictionary = {}
var aura_bonus: float = 0.0             # outgoing-damage bonus from an ally aura (Surge Drone Peak Hours), while aura_t > 0
var aura_t: float = 0.0

var _built: bool = false
var _active: bool = false
var _think_acc: float = 0.0
var _repath_t: float = 0.0
var _los_t: float = 0.0
var _los_ok: bool = true
var _alert_delay: float = -1.0
var _burn_t: float = 0.0
var _death_t: float = 0.0
var _ring: TelegraphDecal = null
var _rims: Array[MeshInstance3D] = []
var _rim_mat: StandardMaterial3D
var _tag: Label3D
var _shape: CollisionShape3D
var _base_scale: Vector3 = Vector3.ONE


# ------------------------------------------------------------------ setup / pooling

## Called by EnemySpawner before the node enters the tree (and again on every reuse).
func configure(id_: StringName, def_: Dictionary, opts_: Dictionary = {}) -> void:
	id = id_
	def = def_
	opts = opts_


func _ready() -> void:
	_load_tables()
	if not _built:
		_build_body()
		_built = true
	if not _active:
		activate()


func _load_tables() -> void:
	var tbl: Dictionary = Data.table("bs/enemies")
	G = tbl["globals"]
	S = Data.table("bs/statuses")
	if def.is_empty() and id != &"":
		def = (tbl["enemies"] as Dictionary).get(String(id), {})


func _build_body() -> void:
	EnemyBase.register_lines()
	add_to_group(&"damageable")
	add_to_group(&"enemies")
	collision_layer = LAYER_ENEMY
	collision_mask = MASK_WORLD
	floor_snap_length = 0.3
	safe_margin = 0.02
	radius = float(def.get("radius", radius))
	height = float(def.get("height", height))
	_shape = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = minf(radius, 0.9)
	cap.height = maxf(height, cap.radius * 2.0)
	_shape.shape = cap
	_shape.position.y = cap.height * 0.5
	add_child(_shape)
	hitbox = Area3D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = LAYER_HITBOX
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	hitbox.set_meta(&"damageable", self)
	var hs: CollisionShape3D = CollisionShape3D.new()
	var hsh: CapsuleShape3D = CapsuleShape3D.new()
	hsh.radius = radius
	hsh.height = maxf(height, radius * 2.0)
	hs.shape = hsh
	hs.position.y = hsh.height * 0.5
	hitbox.add_child(hs)
	add_child(hitbox)
	status = StatusEffects.new()
	status.name = "Status"
	add_child(status)
	status.applied.connect(_on_status_applied)
	nav = NavigationAgent3D.new()
	nav.name = "Nav"
	nav.radius = radius
	nav.path_desired_distance = 0.6
	nav.target_desired_distance = 0.8
	nav.avoidance_enabled = false
	add_child(nav)
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	_build_visual()
	tele_light = OmniLight3D.new()
	tele_light.name = "TelegraphLight"
	tele_light.omni_range = maxf(3.0, radius * 4.0)
	tele_light.light_energy = 0.0
	tele_light.visible = false
	tele_light.position.y = height * 0.6
	add_child(tele_light)


## Resets everything for a fresh life. Safe to call again on reuse from the pool.
func activate() -> void:
	_load_tables()
	_active = true
	arch = StringName(str(def.get("arch", "chaser")))
	heavy = bool(def.get("heavy", false))
	elite = bool(opts.get("elite", false))
	is_add = bool(opts.get("is_add", false))
	var hp_mult: float = float((G["elite"] as Dictionary)["hp_mult"]) if elite else 1.0
	if bool(opts.get("ng_plus", false)):
		hp_mult *= float((G["ng_plus"] as Dictionary)["hp_mult"])
		dmg_mult = float((G["ng_plus"] as Dictionary)["dmg_mult"])
	else:
		dmg_mult = 1.0
	max_hp = roundf(float(def.get("hp", 10)) * hp_mult)
	hp = max_hp
	drops = int(def.get("drops", 0))
	if elite:
		drops = ceili(drops * float((G["elite"] as Dictionary)["drops_mult"]))
	stolen = 0
	speed = float(def.get("speed", 3.6))
	aggro_radius = float(def.get("aggro_radius", G["aggro_radius"]))
	leash = float(opts.get("leash", def.get("leash", G["leash"])))
	home = global_position if is_inside_tree() else position
	aggro = bool(opts.get("aggro", false))
	target = null
	desired_vel = Vector3.ZERO
	knock_vel = Vector3.ZERO
	velocity = Vector3.ZERO
	launch_vy = 0.0
	contact_cd = 0.0
	fire_cd = randf_range(1.0, 2.5)
	stun_t = 0.0
	flash_t = 0.0
	_death_t = 0.0
	_alert_delay = -1.0
	spawn_invuln = 0.0
	override_point = Vector3.INF
	gravity_on = arch != &"flyer" and arch != &"turret" and arch != &"prop"
	collision_layer = LAYER_ENEMY
	hitbox.collision_layer = LAYER_HITBOX
	visible = true
	visual.scale = _base_scale
	visual.rotation = Vector3.ZERO
	visual.position = Vector3.ZERO
	for st: Variant in status.active():
		status.clear(StringName(str(st)))
	t = randf() * 100.0
	state = State.SPAWN
	state_t = 0.0
	_apply_rim()
	_on_activate()
	_set_state(State.SPAWN)


func _apply_rim() -> void:
	for r: MeshInstance3D in _rims:
		if is_instance_valid(r):
			r.queue_free()
	_rims.clear()
	if _tag != null:
		_tag.queue_free()
		_tag = null
	if arch == &"prop":
		return
	var el: Dictionary = def.get("elite", {}) if def.get("elite") is Dictionary else {}
	var c: Color = EnemyFx.col(str(el.get("rim", "#ffd23e"))) if elite else EnemyFx.col(str(G.get("rim_color", "#14141c")))
	_rim_mat = StandardMaterial3D.new()
	_rim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rim_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	_rim_mat.grow = true
	_rim_mat.grow_amount = 0.05 if elite else 0.025
	_rim_mat.albedo_color = c
	if elite:
		_rim_mat.emission_enabled = true
		_rim_mat.emission = c
		_rim_mat.emission_energy_multiplier = 1.5
	for mi: MeshInstance3D in _meshes(visual):
		var r: MeshInstance3D = MeshInstance3D.new()
		r.mesh = mi.mesh
		r.material_override = _rim_mat
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(r)
		_rims.append(r)
	if elite:
		_tag = Label3D.new()
		_tag.text = "PREMIUM"
		_tag.modulate = Color(1.0, 0.82, 0.24)
		_tag.font_size = 28
		_tag.pixel_size = 0.004
		_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_tag.position.y = height + 0.55
		add_child(_tag)


func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c: Node in n.get_children():
		var mi: MeshInstance3D = c as MeshInstance3D
		if mi != null and not mi.has_meta(&"no_rim"):
			var sm: StandardMaterial3D = mi.material_override as StandardMaterial3D
			if sm == null or sm.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
				out.append(mi)
		out.append_array(_meshes(c))
	return out


func telegraph_def(kind: StringName) -> Dictionary:
	var tg: Dictionary = def.get("telegraphs", {})
	return tg.get(String(kind), {})


# ------------------------------------------------------------------ contract

func get_center() -> Vector3:
	return global_position + Vector3(0, height * 0.5, 0)


func is_alive() -> bool:
	return _active and state != State.DEAD and hp > 0.0


func is_attacking() -> bool:
	return state == State.TELEGRAPH or state == State.ATTACK


func state_name() -> String:
	return STATE_NAMES[state]


## Damage pipeline: statuses -> crit -> served -> subclass/boss modifiers -> hp. True when it killed.
func take_damage(hit: Combat.Hit) -> bool:
	if not is_alive():
		return false
	if not _accepts_hit(hit):
		return false
	_apply_hit_statuses(hit)
	var crit: bool = hit.weak_point or is_weak_point(hit.point) or _extra_crit(hit)
	var amt: float = hit.amount
	if crit:
		amt *= crit_mult()
	if status.has(&"served"):
		amt *= float(S["served"]["damage_taken_mult"])
	amt = _modify_damage(amt, hit, crit)
	if spawn_invuln > 0.0:
		amt = 0.0
	amt = roundf(amt)
	last_hit = hit
	hp -= amt
	flash_t = float(G["hit_flash"])
	alert()
	if hit.knock > 0.0 and hit.dir != Vector3.ZERO and arch != &"turret" and arch != &"prop":
		knock_vel += Vector3(hit.dir.x, 0, hit.dir.z).normalized() * hit.knock * (0.3 if heavy else 1.0)
	if hit.launch > 0.0:
		launch(hit.launch)
	_on_hurt(hit, amt, crit)
	var killed: bool = hp <= 0.0
	EventBus.enemy_hit.emit(self, hit, killed)
	if killed:
		die(hit)
	return killed


## Pop a light ground enemy into the air (launchEnemy, index.html:6376).
func launch(vy: float) -> void:
	if not is_alive() or immune(&"launch"):
		return
	status.clear(&"rooted")
	cancel_attack()
	launch_vy = maxf(launch_vy, vy)
	_set_state(State.LAUNCHED)


func stagger(seconds: float) -> void:
	if not is_alive() or immune(&"stun"):
		return
	cancel_attack()
	stun_t = maxf(stun_t, seconds)
	_set_state(State.STAGGER)


func immune(sid: StringName) -> bool:
	var imm: Dictionary = S["immunities"]
	var lists: Array = []
	if is_in_group(&"bosses"):
		lists.append(imm["boss"])
	if heavy:
		lists.append(imm["heavy"])
	if imm.has(String(arch)):
		lists.append(imm[String(arch)])
	for l: Variant in lists:
		if (l as Array).has(String(sid)):
			return true
	if sid == &"rooted" and arch == &"flyer" and global_position.y - home.y > float(S["rooted"]["flyer_immune_above"]):
		return true
	return false


func _apply_hit_statuses(hit: Combat.Hit) -> void:
	for k: Variant in hit.status.keys():
		var sid: StringName = StringName(str(k))
		var secs: float = float(hit.status[k])
		if sid == &"stun":
			stagger(secs)
		elif sid == &"shatter":
			continue
		elif not immune(sid):
			status.apply(sid, secs)


func _on_status_applied(sid: StringName, secs: float) -> void:
	if sid == &"stun":                   # weapons may stun through the Status node
		status.clear(&"stun")
		stagger(secs)
		return
	if immune(sid):
		status.clear(sid)
		return
	var pr: Dictionary = S["priority"]
	if sid == &"frozen":
		for c: Variant in pr["frozen_clears"]:
			status.clear(StringName(str(c)))
	elif sid == &"dancing":
		if status.has(&"frozen"):
			status.clear(&"dancing")
			return
		for c: Variant in pr["dancing_clears"]:
			status.clear(StringName(str(c)))
	elif sid == &"rooted" and (status.has(&"frozen") or status.has(&"dancing")):
		status.clear(&"rooted")
		return
	if _blocked_by_status():
		cancel_attack()


func _blocked_by_status() -> bool:
	return status.has(&"frozen") or status.has(&"dancing") or status.has(&"gravity_clumped")


func can_move() -> bool:
	return not (status.has(&"rooted") or _blocked_by_status())


func can_attack() -> bool:
	return not _blocked_by_status() and stun_t <= 0.0


func move_mult() -> float:
	if not status.has(&"slowed"):
		return 1.0
	var m: float = float(S["slowed"]["move_mult"])
	if is_in_group(&"bosses"):
		m = 1.0 - (1.0 - m) * float(S["slowed"]["boss_effect"])
	return m


func attack_rate() -> float:
	if not status.has(&"slowed"):
		return 1.0
	var m: float = float(S["slowed"]["attack_mult"])
	if is_in_group(&"bosses"):
		m = 1.0 - (1.0 - m) * float(S["slowed"]["boss_effect"])
	return m


## Weapons ask this before take_damage (WeaponManager.deal_damage). The enemy applies crit_mult() itself.
func is_weak_point(point: Vector3) -> bool:
	return weak_point_exposed() and point != Vector3.ZERO and point.distance_to(_weak_point_pos()) < weak_radius()


func crit_mult() -> float:
	var wp: Variant = def.get("weak_point")
	if wp is Dictionary:
		return float((wp as Dictionary).get("crit", G["crit_mult"]))
	return float(G["crit_mult"])


func weak_radius() -> float:
	var wp: Variant = def.get("weak_point")
	if wp is Dictionary:
		return float((wp as Dictionary).get("radius", G["weak_radius"]))
	return float(G["weak_radius"])


## The enemy makes noise or gets hit: aggro, and packmates within share_radius follow 0.3 s later.
func alert() -> void:
	if aggro or not is_alive():
		return
	aggro = true
	var P: Dictionary = G["perception"]
	for n: Node in get_tree().get_nodes_in_group(&"enemies"):
		var o: EnemyBase = n as EnemyBase
		if o == null or o == self or o.aggro or not o.is_alive():
			continue
		if o.global_position.distance_to(global_position) < float(P["share_radius"]):
			o._alert_delay = float(P["share_delay"])


## Gunfire / mallet noise: alerts every enemy within `r` of `pos`. Weapons call this.
static func noise(tree: SceneTree, pos: Vector3, r: float) -> void:
	for n: Node in tree.get_nodes_in_group(&"enemies"):
		var o: EnemyBase = n as EnemyBase
		if o != null and o.is_alive() and o.global_position.distance_to(pos) < r:
			o.alert()


# ------------------------------------------------------------------ death

func die(hit: Combat.Hit) -> void:
	if state == State.DEAD:
		return
	hp = minf(hp, 0.0)
	cancel_attack()
	AttackTokens.release_melee(self)
	_set_state(State.DEAD)
	collision_layer = 0
	hitbox.collision_layer = 0
	desired_vel = Vector3.ZERO
	var c: Vector3 = get_center()
	var parent: Node = get_parent()
	EnemyFx.chunks(parent, c, EnemyFx.col(str(def.get("chunk_color", "#777788"))), radius,
		int((G["chunks"] as Array)[0]), int((G["chunks"] as Array)[1]))
	_on_died(hit)
	EventBus.enemy_killed.emit(self, hit.weapon_id if hit != null else &"")
	drop_loot(c)
	died.emit(self)
	_death_t = float(G["death_time"])


func drop_loot(c: Vector3) -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	Pickup.fountain(parent, c, drops + stolen)
	stolen = 0
	# Ammo orbs (the 22% drop) are spawned by the weapons system on EventBus.enemy_killed (WeaponManager).
	# Without one (tests, levels without guns) we fall back to our own orb so the rule still holds.
	if arch == &"prop" or _weapons_present():
		return
	if (elite and bool((G["elite"] as Dictionary)["guaranteed_orb"])) or randf() < float(G["ammo_orb_chance"]):
		Pickup.spawn(parent, &"ammo_r" if randf() < 0.5 else &"ammo_z", c, Vector3(randf_range(-2, 2), 5, randf_range(-2, 2)))


func _weapons_present() -> bool:
	var p: Node = get_tree().get_first_node_in_group(&"player")
	return p != null and p.get_node_or_null("Weapons") != null


## Leaves without dying (a fleeing Vulture). No kill event, no drops.
func despawn() -> void:
	if state == State.DEAD:
		return
	cancel_attack()
	AttackTokens.release_melee(self)
	escaped.emit(self)
	_set_state(State.DEAD)
	collision_layer = 0
	_death_t = 0.0
	_finish_death()


func _finish_death() -> void:
	_active = false
	visible = false
	if pooled:
		EnemySpawner.release(self)
	else:
		queue_free()


# ------------------------------------------------------------------ main loop

func _physics_process(delta: float) -> void:
	if not _active:
		return
	AttackTokens.tick(delta)
	t += delta
	if state == State.DEAD:
		_death_t -= delta
		visual.scale = _base_scale * clampf(_death_t / maxf(0.01, float(G["death_time"])), 0.0, 1.0)
		if _death_t <= 0.0:
			_finish_death()
		return
	_timers(delta)
	_find_target()
	_update_lod()
	if lod == 2 and not aggro:
		return                                   # asleep: only timers/status decay
	var dt: float = delta
	if lod == 1:
		_think_acc += delta
		if _think_acc < 1.0 / float(G["lod"]["lod1_hz"]):
			_apply_motion(delta)
			return
		dt = _think_acc
	_think_acc = 0.0
	_ai(dt)
	if state == State.DEAD:
		return
	_apply_motion(delta)
	_visual_update(delta)


func _timers(delta: float) -> void:
	var r: float = attack_rate()
	contact_cd -= delta
	fire_cd -= delta * r
	aura_t -= delta
	spawn_invuln -= delta
	state_t += delta
	if _alert_delay > 0.0:
		_alert_delay -= delta
		if _alert_delay <= 0.0:
			aggro = true
	if status.has(&"burning"):
		_burn_t -= delta
		if _burn_t <= 0.0:
			var B: Dictionary = S["burning"]
			_burn_t = float(B["tick"])
			var h: Combat.Hit = Combat.Hit.make(float(B["dps"]) * float(B["tick"]), Combat.Type.FIRE, null)
			h.weapon_id = &"burning"
			h.point = get_center()
			take_damage(h)
	else:
		_burn_t = 0.0


func _find_target() -> void:
	if target != null and is_instance_valid(target) and target.is_inside_tree():
		return
	target = get_tree().get_first_node_in_group(&"player") as Node3D
	var decoys: Array[Node] = get_tree().get_nodes_in_group(&"enemy_decoys")
	if decoys.is_empty() or target == null:
		return
	# LIEN: everybody prioritises Bolt; otherwise the nearest taunt decoy wins if it's closer
	if LienCrawler.lien_owner_of(target) != null:
		return
	var best: float = global_position.distance_to(target.global_position)
	for d: Node in decoys:
		var dn: Node3D = d as Node3D
		if dn != null and dn.global_position.distance_to(global_position) < best:
			best = dn.global_position.distance_to(global_position)
			target = dn


func target_alive() -> bool:
	return target != null and is_instance_valid(target) and (not target.has_method("is_alive") or bool(target.call("is_alive")))


func target_pos() -> Vector3:
	return target.global_position if target != null else global_position


func target_center() -> Vector3:
	if target == null:
		return global_position
	return target.call("get_center") if target.has_method("get_center") else target.global_position


func dist_to_target() -> float:
	return global_position.distance_to(target_pos()) if target != null else INF


func flat_dist_to_target() -> float:
	if target == null:
		return INF
	var d: Vector3 = target_pos() - global_position
	return Vector2(d.x, d.z).length()


func _update_lod() -> void:
	var L: Dictionary = G["lod"]
	var d: float = dist_to_target()
	if d < float(L["near"]) or is_attacking() or is_in_group(&"bosses"):
		lod = 0
	elif d < float(L["far"]):
		lod = 1
	else:
		lod = 2


func _ai(dt: float) -> void:
	# blocking statuses come first: frozen / dancing / clumped cancel and hold the unit
	if _blocked_by_status() and state != State.LAUNCHED:
		if state != State.STATUS:
			cancel_attack()
			_set_state(State.STATUS)
		desired_vel = Vector3.ZERO
		return
	match state:
		State.SPAWN:
			desired_vel = Vector3.ZERO
			if state_t >= float(opts.get("spawn_time", G["spawn_time"])):
				_set_state(_initial_state())
		State.HIDDEN:
			_hidden_update(dt)
		State.REVEAL:
			_reveal_update(dt)
		State.IDLE, State.PATROL:
			_perceive(dt)
			_idle_update(dt)
			if aggro and target_alive():
				_set_state(State.CHASE)
		State.CHASE:
			_perceive(dt)
			if not target_alive():
				desired_vel = Vector3.ZERO
				_set_state(State.IDLE)
				return
			_position_update(dt)
		State.LEASH_RETURN:
			_perceive(dt)
			var to: Vector3 = home - global_position
			to.y = 0.0
			if to.length() < 1.0:
				desired_vel = Vector3.ZERO
				_set_state(State.IDLE)
			else:
				steer_toward(home, speed)
		State.TELEGRAPH:
			tele_t -= dt * attack_rate()
			desired_vel = Vector3.ZERO
			_telegraph_update(dt)
			_tick_light()
			if tele_t <= 0.0 and state == State.TELEGRAPH:
				_end_telegraph_fx()
				_set_state(State.ATTACK)
				attacked.emit(attack_kind)
				_attack_begin()
		State.ATTACK:
			if _attack_update(dt) and state == State.ATTACK:
				_set_state(State.RECOVER)
		State.RECOVER:
			if _recover_update(dt):
				AttackTokens.release_melee(self)
				_set_state(State.CHASE if aggro else State.IDLE)
		State.STAGGER:
			stun_t -= dt
			desired_vel = Vector3.ZERO
			visual.rotation.z = sin(t * float(S["stun"]["wobble_hz"])) * float(S["stun"]["wobble"])
			if stun_t <= 0.0:
				visual.rotation.z = 0.0
				_set_state(State.CHASE if aggro else State.IDLE)
		State.LAUNCHED:
			desired_vel = Vector3.ZERO
		State.STATUS:
			_set_state(State.CHASE if aggro else State.IDLE)


func _set_state(s: int) -> void:
	var from: int = state
	state = s
	state_t = 0.0
	if from != s:
		_on_state(from, s)
		state_changed.emit(from, s)


func _perceive(dt: float) -> void:
	if aggro or target == null:
		return
	var P: Dictionary = G["perception"]
	var d: float = dist_to_target()
	if d > float(P["los_max"]):
		return
	_los_t -= dt
	if _los_t <= 0.0:
		_los_t = 1.0 / float(P["los_hz"])
		_los_ok = EnemyFx.los_clear(self, get_center(), target_center())
	if d < aggro_radius and _los_ok:
		alert()
		return
	# hearing the mallet
	var melee: Node = target.get_node_or_null("Melee")
	if melee != null and d < float(P["mallet_hear"]) and float(melee.get("attack_t")) > 0.0:
		alert()


# ------------------------------------------------------------------ movement

## Moves toward a point on the navmesh (or straight, when the level has no navmesh), honouring the
## leash, rooting and slows. Sets desired_vel; returns the horizontal direction used.
func steer_toward(goal: Vector3, spd: float) -> Vector3:
	if not can_move():
		desired_vel = Vector3.ZERO
		return Vector3.ZERO
	var next: Vector3 = goal
	if _has_navmesh():
		_repath_t -= get_physics_process_delta_time()
		var d: float = global_position.distance_to(goal)
		var Pth: Dictionary = G["path"]
		if _repath_t <= 0.0 and _repath_budget():
			_repath_t = float(Pth["near_every"]) if d < float(Pth["near"]) else (float(Pth["mid_every"]) if d < float(Pth["mid"]) else float(Pth["far_every"]))
			nav.target_position = goal
		if not nav.is_navigation_finished():
			next = nav.get_next_path_position()
	var dir: Vector3 = next - global_position
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		desired_vel = Vector3.ZERO
		return Vector3.ZERO
	dir = dir.normalized()
	if not _leash_allows(dir):
		desired_vel = Vector3.ZERO
		return Vector3.ZERO
	desired_vel = dir * spd * move_mult()
	face(dir, get_physics_process_delta_time())
	return dir


func _leash_allows(dir: Vector3) -> bool:
	if arch == &"flyer" or is_in_group(&"bosses"):
		return true
	var hd: Vector3 = home - global_position
	hd.y = 0.0
	return hd.length() < leash or dir.dot(hd) > 0.0


func _has_navmesh() -> bool:
	if not is_inside_tree():
		return false
	var map: RID = get_world_3d().navigation_map
	return not NavigationServer3D.map_get_regions(map).is_empty()


static func _repath_budget() -> bool:
	var f: int = Engine.get_physics_frames()
	if f != _repath_frame:
		_repath_frame = f
		_repath_count = 0
	if _repath_count >= 6:
		return false
	_repath_count += 1
	return true


func face(dir: Vector3, dt: float, rate: float = -1.0) -> void:
	if dir.length_squared() < 0.0001:
		return
	var want: float = atan2(dir.x, dir.z)
	var k: float = 1.0 - exp(-(float(G["turn_rate"]) if rate < 0.0 else rate) * dt)
	rotation.y = lerp_angle(rotation.y, want, k)


func forward() -> Vector3:
	return Vector3(sin(rotation.y), 0, cos(rotation.y))


func _apply_motion(delta: float) -> void:
	if override_point != Vector3.INF:
		velocity = (override_point - global_position) / maxf(delta, 0.0001)
		override_point = Vector3.INF
		move_and_slide()
		return
	if arch == &"prop":
		return
	if arch == &"turret":
		velocity = Vector3.ZERO
		return
	if state == State.LAUNCHED:
		launch_vy -= float(S["launch"]["gravity"]) * delta
		velocity = Vector3(knock_vel.x, launch_vy, knock_vel.z)
		visual.rotation.x += delta * float(S["launch"]["tumble_x"])
		visual.rotation.z += delta * float(S["launch"]["tumble_z"])
		move_and_slide()
		knock_vel *= 1.0 - minf(1.0, delta * 2.0)
		if launch_vy < 0.0 and is_on_floor():
			launch_vy = 0.0
			visual.rotation = Vector3.ZERO
			_set_state(State.CHASE if aggro else State.IDLE)
		return
	if gravity_on:
		velocity.y = 0.0 if is_on_floor() else velocity.y - float(G["gravity"]) * delta
		velocity.x = desired_vel.x + knock_vel.x
		velocity.z = desired_vel.z + knock_vel.z
	else:
		velocity = desired_vel + knock_vel
	move_and_slide()
	knock_vel *= 1.0 - minf(1.0, delta * 6.0)


func _visual_update(delta: float) -> void:
	if flash_t > 0.0:
		flash_t -= delta
		for m: StandardMaterial3D in flash_mats:
			m.emission_enabled = true
			m.emission = Color.WHITE
			m.emission_energy_multiplier = 0.9 if flash_t > 0.0 else 0.0
	if status.has(&"dancing") and state == State.STATUS:
		var D: Dictionary = S["dancing"]
		visual.position.y = absf(sin(t * float(D["bob_hz"]))) * float(D["bob_height"])
		visual.rotation.y += sin(t * float(D["spin_hz"])) * 0.25
	elif state != State.LAUNCHED and visual.position.y != 0.0 and not _owns_visual_y():
		visual.position.y = 0.0
		visual.rotation.y = 0.0
	if elite and _rim_mat != null:
		_rim_mat.emission_energy_multiplier = 1.0 + 0.8 * sin(t * TAU * float((G["elite"] as Dictionary)["rim_hz"]))
	_anim(delta)


## True when the subclass animates visual.position.y itself (turret rise, burrow).
func _owns_visual_y() -> bool:
	return false


# ------------------------------------------------------------------ telegraph / attack helpers

## Starts a TELEGRAPH (pose + `telegraphed` signal for sound + light + optional ground ring).
## Enforces the §1.2 minimums: heavy/control attacks >= 0.4 s, chip >= 0.25 s.
func begin_telegraph(kind: StringName, dur: float = -1.0, ring_r: float = -1.0, ring_at: Vector3 = Vector3.INF, heavy_hit: bool = true) -> void:
	var td: Dictionary = telegraph_def(kind)
	if dur < 0.0:
		dur = float(td.get("dur", 0.45))
	dur = maxf(dur, float(G["telegraph_min_heavy"]) if heavy_hit else float(G["telegraph_min_chip"]))
	attack_kind = kind
	tele_dur = dur
	tele_t = dur
	last_telegraph = {"kind": kind, "dur": dur, "started": AttackTokens.clock}
	var c: Color = EnemyFx.col(str(td.get("light", "#ff5d2e")))
	tele_light.light_color = c
	tele_light.light_energy = 0.5
	tele_light.visible = true
	if ring_r < 0.0:
		ring_r = float(td.get("ring", 0.0))
	if ring_r > 0.0:
		_ring = EnemyFx.ring(get_parent(), global_position if ring_at == Vector3.INF else ring_at, ring_r, dur, c)
	desired_vel = Vector3.ZERO
	_set_state(State.TELEGRAPH)
	telegraphed.emit(kind, StringName(str(td.get("sfx", ""))), dur)


func _tick_light() -> void:
	var k: float = 1.0 - clampf(tele_t / maxf(tele_dur, 0.01), 0.0, 1.0)
	tele_light.light_energy = 0.5 + k * 3.5 + sin(t * 40.0) * 0.3


func _end_telegraph_fx() -> void:
	tele_light.visible = false
	tele_light.light_energy = 0.0


## Cancels a telegraph or attack in progress (the attack is dropped, not delayed).
func cancel_attack() -> void:
	if state != State.TELEGRAPH and state != State.ATTACK:
		return
	_end_telegraph_fx()
	if _ring != null and is_instance_valid(_ring):
		_ring.queue_free()
	_ring = null
	AttackTokens.release_melee(self)
	override_point = Vector3.INF
	_on_attack_cancelled()
	_set_state(State.RECOVER)


## Hits the current target (or Bolt) through the shared player-damage path.
func hurt_target(amount: float, knock: float = 6.0, kind: Combat.Type = Combat.Type.KINETIC) -> bool:
	if target == null:
		return false
	var h: Combat.Hit = Combat.Hit.make(amount * out_mult(), kind, self)
	h.point = target_center()
	var d: Vector3 = target_pos() - global_position
	h.dir = Vector3(d.x, 0, d.z).normalized()
	h.knock = knock
	h.is_melee = true
	if target.is_in_group(&"player"):
		return hurt_player(target, h, self)
	if target.has_method("take_damage"):
		return bool(target.call("take_damage", h))
	return false


## Multiplier on everything this enemy deals: NG+ x1.35, Meter Maid elite DOUBLE PARKED (+20%),
## Surge Drone elite PEAK HOURS aura (+5% per enemy).
func out_mult() -> float:
	var m: float = dmg_mult
	if status.has(&"double_parked"):
		m *= float(S.get("double_parked", {}).get("damage_mult", 1.2))
	if aura_t > 0.0:
		m *= 1.0 + aura_bonus
	return m


## Copies new bs.* lines from enemies.json / bosses.json "lines" into VOManager when its sources don't
## have them yet (the lead adds these files to VOManager.LINE_SOURCES; until then this keeps them playable).
static var _lines_registered: bool = false

static func register_lines(force: bool = false) -> void:
	if _lines_registered and not force:
		return
	_lines_registered = true
	var store: Variant = VOManager.get("_lines")
	if not store is Dictionary:
		return
	for tbl: String in ["bs/enemies", "bs/bosses"]:
		var t: Variant = Data.table(tbl)
		if not t is Dictionary:
			continue
		var lines: Dictionary = (t as Dictionary).get("lines", {})
		for k: Variant in lines.keys():
			if not str(k).begins_with("_") and not VOManager.has_line(str(k)):
				(store as Dictionary)[str(k)] = lines[k]


static func line_text(line_id: String) -> String:
	EnemyBase.register_lines()
	return str(VOManager.line(line_id).get("text", ""))


## The one place enemies hurt Bolt: applies LIEN's +15% damage taken. Returns true if damage landed.
static func hurt_player(player: Node, h: Combat.Hit, _src: Node = null) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var st: StatusEffects = player_status(player)
	if st.has(&"lien"):
		h.amount *= float((Data.table("bs/statuses") as Dictionary)["lien"]["player_damage_taken_mult"])
	var before: float = float(player.get("hp")) if "hp" in player else 0.0
	player.call("take_damage", h)
	return ("hp" in player) and float(player.get("hp")) < before


## Bolt's status node (LIEN etc.). Created on demand: Bolt's own script doesn't add one.
static func player_status(player: Node) -> StatusEffects:
	var st: StatusEffects = player.get_node_or_null("Status") as StatusEffects
	if st == null:
		st = StatusEffects.new()
		st.name = "Status"
		player.add_child(st)
	return st


## Bolt is mid-dash: dash-throughs make pounces and dives miss (BS_ENEMIES counters).
func target_dodging() -> bool:
	if target == null or not "motor" in target:
		return false
	var m: Object = target.get("motor")
	return m != null and float(m.get("dash_t")) > 0.0


func target_onscreen() -> bool:
	if target == null or not "camera" in target:
		return true
	var bc: Node = target.get("camera")
	if bc == null or not "cam" in bc:
		return true
	var cam: Camera3D = bc.get("cam") as Camera3D
	if cam == null or not cam.is_inside_tree():
		return true
	return not cam.is_position_behind(get_center())


# ------------------------------------------------------------------ default hooks (chaser)

func _build_visual() -> void:
	var m: StandardMaterial3D = EnemyFx.mat(EnemyFx.col(str(def.get("body_color", "#777788"))))
	flash_mats.append(m)
	EnemyFx.box(visual, Vector3(radius * 1.4, height, radius * 1.4), Vector3(0, height * 0.5, 0), m)


func _on_activate() -> void:
	pass


func _initial_state() -> int:
	return State.CHASE if aggro else State.IDLE


func _hidden_update(_dt: float) -> void:
	_set_state(State.REVEAL)


func _reveal_update(_dt: float) -> void:
	_set_state(State.CHASE if aggro else State.IDLE)


func _idle_update(_dt: float) -> void:
	desired_vel = Vector3.ZERO


func _position_update(dt: float) -> void:
	steer_toward(target_pos(), speed)
	var _u: float = dt


func _telegraph_update(_dt: float) -> void:
	pass


func _attack_begin() -> void:
	pass


func _attack_update(_dt: float) -> bool:
	return true


func _recover_update(_dt: float) -> bool:
	desired_vel = Vector3.ZERO
	return state_t >= 0.4


func _on_attack_cancelled() -> void:
	visual.scale = _base_scale


func _on_hurt(_hit: Combat.Hit, _amount: float, _crit: bool) -> void:
	pass


func _on_died(_hit: Combat.Hit) -> void:
	pass


func _on_state(_from: int, _to: int) -> void:
	pass


func _accepts_hit(_hit: Combat.Hit) -> bool:
	return true


func _modify_damage(amount: float, _hit: Combat.Hit, _crit: bool) -> float:
	return amount


func _weak_point_pos() -> Vector3:
	return get_center()


func weak_point_exposed() -> bool:
	return false


## Extra crit rule beyond the weak-point sphere (e.g. a boss's exposed core from the front).
func _extra_crit(_hit: Combat.Hit) -> bool:
	return false


func _anim(_delta: float) -> void:
	pass
