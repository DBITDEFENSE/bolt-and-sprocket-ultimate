class_name ShieldCell
extends Zombie
## One of the Account Manager's shield-cells (UPDATE 07 Map 4 Act IV, docs/MAP4_FERNFLUG.md §6.7, T-113): a violet
## sphere that orbits her in COLLECTIONS. A Zombie so every weapon, the explosions and the Lodestone's lift and
## fling work on it unchanged: the body is hidden, the sphere rides the chest, the hitboxes stay. Its health is its
## own (enemies.json shield_cell), it never crawls, staggers or falls; shot to pieces it dies (and she regrows it);
## carried or flung into the vacuum shaft over the console (`in_shaft`) it is gone for good. While it is not
## lifted or pushed it is placed on its orbit every physics step.

var boss: Node3D = null
var orbit_phase: float = 0.0
var orbit_radius: float = 2.6
var orbit_height: float = 1.7
var orbit_rpm: float = 6.0
var shaft_pos: Vector3 = Vector3.INF
var shaft_radius: float = 2.5
var gone_for_good: bool = false
var _sphere: MeshInstance3D
var _glow: OmniLight3D
var _orbit_t: float = 0.0


## True when `p` is inside the shaft's throat: within `r` of its axis and above its mouth.
static func in_shaft(p: Vector3, shaft: Vector3, r: float) -> bool:
	if shaft == Vector3.INF:
		return false
	return Vector2(p.x - shaft.x, p.z - shaft.z).length() <= r and p.y >= shaft.y - 0.5


## Where the cell sits at `t` seconds on its orbit (phase in radians).
static func orbit_pos(center: Vector3, phase: float, t: float, radius: float, height: float, rpm: float) -> Vector3:
	var a: float = phase + t * rpm * TAU / 60.0
	return center + Vector3(cos(a) * radius, height + sin(a * 2.0) * 0.25, sin(a) * radius)


func spawn_cell(at: Vector3, health: float) -> void:
	net_died = false
	enemy_id = &"shield_cell"
	_cfg = Zombie.kind_config(&"shield_cell")
	max_hp = health
	hp = health
	tier = &"walk"
	speed = 0.0
	is_crawler = false
	gone_for_good = false
	_burn_t = 0.0
	_frost_t = 0.0
	armor_torso_mult = 1.0
	_reset_presentation()
	_set_crawl_pose(false)
	_apply_variant("soldier")
	for g: MeshInstance3D in _gear:
		g.hide()
	_body.visible = false
	for k: String in ["glass", "glass_arm", "lantern", "suit", "visor_crack"]:
		if _kind_nodes.has(k):
			(_kind_nodes[k] as Node3D).hide()
	_lantern_light.light_energy = 0.0
	if _sphere == null:
		_sphere = MeshInstance3D.new()
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = 0.42
		sm.height = 0.84
		_sphere.mesh = sm
		_sphere.material_override = Mats.get_mat("nachtglas")
		_sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bone_attachment("Chest").add_child(_sphere)
		_glow = OmniLight3D.new()
		_glow.light_color = Color(0.62, 0.3, 1.0)
		_glow.light_energy = 1.6
		_glow.omni_range = 5.0
		_glow.shadow_enabled = false
		_sphere.add_child(_glow)
	_sphere.visible = true
	show()
	process_mode = Node.PROCESS_MODE_INHERIT
	collision_layer = LAYER_ZBODY
	collision_mask = LAYER_WORLD
	for hb: Hitbox in _hitboxes:
		hb.collision_layer = Hitbox.LAYER_HITBOX
	_pivot.rotation = Vector3.ZERO
	_pivot.position = Vector3.ZERO
	velocity = Vector3.ZERO
	global_position = at
	_agent.avoidance_enabled = false
	_agent.max_speed = 0.0
	state = State.CHASE
	_state_t = 0.0
	_orbit_t = 0.0


func _physics_process(delta: float) -> void:
	if puppet or state == State.INACTIVE:
		return
	if state == State.DEAD:
		_state_t += delta
		_update_dead(delta)
		return
	if gone_for_good:
		return
	if in_shaft(global_position, shaft_pos, shaft_radius):
		vanish_for_good()
		return
	if _push_t > 0.0 or state == State.LIFTED:
		super._physics_process(delta)   # the fling's arc, the lift's hold
		return
	_orbit_t += delta
	var center: Vector3 = boss.global_position if boss != null and is_instance_valid(boss) else global_position
	global_position = orbit_pos(center, orbit_phase, _orbit_t, orbit_radius, orbit_height, orbit_rpm)
	_update_burn(delta)
	if _frost_t > 0.0:
		_frost_t -= delta


## Into the shaft: no death, no Scrip; the round count lets it go (it was an extra spawn).
func vanish_for_good() -> void:
	if gone_for_good or not is_active():
		return
	gone_for_good = true
	_push_t = 0.0
	_push_v = Vector3.ZERO
	AudioDirector.play_3d("zombie_gib", global_position, -4.0, 0.4)
	Effects.explosion(global_position, 1.5)
	if boss != null and is_instance_valid(boss) and boss.has_method("on_cell_lost"):
		boss.call("on_cell_lost", self)
	deactivate()
	RoundManager.release_alive(1)
	if director != null:
		director.call("on_zombie_returned", self)


func become_crawler() -> void:
	pass


func force_stagger() -> void:
	pass


func _knockdown() -> void:
	pass


func recycle() -> void:
	pass


func _footstep(_left: bool) -> void:
	pass
