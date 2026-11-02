class_name UndertowWhirl
extends Node3D
## The Undertow's whirlpool (C4, T-153): `radius` m for `seconds`. Every tick it drags the non-boss zombies inside
## toward its eye; one that has been in it `whirl_drown_s` (or reaches the eye) is dragged under: a kill credited to
## the shooter (kind &"wonder"). Bosses inside take `whirl_dps`. In water it is a dark spiral on the surface; on land
## (Maelstrom) a violet vortex in the concrete. Runs where the shot was fired (the host's damage rules apply as for
## every wonder hit); presentation only elsewhere.

const TICK: float = 0.2

var weapon_id: StringName = &"undertow"
var by_player: int = 0
var radius: float = 4.0
var seconds: float = 6.0
var land: bool = false
var h: Dictionary = {}
var drowned: int = 0
var boss_damage_dealt: float = 0.0

var _age: float = 0.0
var _tick: float = 0.0
var _inside: Dictionary = {}     # Zombie -> seconds inside
var _rings: Array[MeshInstance3D] = []
var _disc_mat: StandardMaterial3D


func setup(wid: StringName, pid: int, r: float, secs: float, on_land: bool, harpoon: Dictionary) -> void:
	weapon_id = wid
	by_player = pid
	radius = r
	seconds = secs
	land = on_land
	h = harpoon
	add_to_group(&"undertow_whirls")


func _ready() -> void:
	var col: Color = Undertow.color_of(h)
	_disc_mat = StandardMaterial3D.new()
	_disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_disc_mat.albedo_color = (col if land else Color(0.03, 0.06, 0.08)).lerp(Color(0, 0, 0), 0.3)
	_disc_mat.albedo_color.a = 0.65
	_disc_mat.emission_enabled = land
	_disc_mat.emission = col
	_disc_mat.emission_energy_multiplier = 1.2
	_disc_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var disc: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius * 0.2
	cm.height = 0.5
	cm.cap_top = false
	disc.mesh = cm
	disc.material_override = _disc_mat
	disc.position.y = -0.2
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	for i: int in 3:
		var ring: MeshInstance3D = MeshInstance3D.new()
		var tm: TorusMesh = TorusMesh.new()
		var rr: float = radius * (0.35 + 0.3 * i)
		tm.inner_radius = rr - 0.06
		tm.outer_radius = rr
		ring.mesh = tm
		var rm: StandardMaterial3D = StandardMaterial3D.new()
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rm.albedo_color = Color(col.r, col.g, col.b, 0.55) if land else Color(0.75, 0.85, 0.9, 0.45)
		ring.material_override = rm
		ring.position.y = 0.05 + 0.02 * i
		ring.scale = Vector3(1, 0.3, 1)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		_rings.append(ring)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = col
	light.light_energy = 1.4 if land else 0.6
	light.omni_range = radius + 2.0
	light.shadow_enabled = false
	light.position.y = 0.6
	add_child(light)


func _process(delta: float) -> void:
	_age += delta
	for i: int in _rings.size():
		_rings[i].rotation.y += delta * (3.0 - i * 0.7)
	var fade: float = clampf((seconds - _age) / 0.8, 0.0, 1.0)
	scale = Vector3.ONE * (0.4 + 0.6 * clampf(_age / 0.35, 0.0, 1.0)) * fade + Vector3.ONE * 0.001
	if _age >= seconds:
		queue_free()


func _physics_process(delta: float) -> void:
	if not Net.is_authority() and not _shooter_is_local():
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK
	var dir: Node = get_tree().get_first_node_in_group(&"director")
	if dir == null or not dir.has_method("active_zombies"):
		return
	var center: Vector3 = global_position
	var pull: float = float(h.get("whirl_pull_mps", 3.5))
	var drown_s: float = float(h.get("whirl_drown_s", 0.6))
	for z: Zombie in dir.call("active_zombies"):
		if not Undertow.in_whirl(z.global_position, center, radius):
			_inside.erase(z)
			continue
		if Undertow.is_boss(z):
			var d: float = float(h.get("whirl_dps", 40.0)) * TICK
			z.take_damage(d, &"torso", weapon_id, by_player, &"wonder", true)
			boss_damage_dealt += d
			continue
		var t_in: float = float(_inside.get(z, 0.0)) + TICK
		_inside[z] = t_in
		var to_c: Vector3 = center - z.global_position
		to_c.y = 0.0
		if t_in >= drown_s or to_c.length() < 0.8:
			drown(z)
		elif to_c.length() > 0.2:
			z.external_push(to_c.normalized() * pull, TICK + 0.05)


## Dragged under: the kill (the drowned's scream; the sink is the death's own fall).
func drown(z: Zombie) -> void:
	_inside.erase(z)
	var killed: bool = z.take_damage(maxf(z.hp, 1.0) * 10.0 + 1.0, &"torso", weapon_id, by_player, &"wonder", true)
	if killed:
		drowned += 1
		GLBus.enemy_hit_feedback.emit(by_player, true, false)
		AudioDirector.play_3d(str(h.get("splash_sound", "water_splash")), z.global_position, -2.0, 0.1)


func _shooter_is_local() -> bool:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.player_id == by_player:
			return p.is_local or p.is_bot
	return false
