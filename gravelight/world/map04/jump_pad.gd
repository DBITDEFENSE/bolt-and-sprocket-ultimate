class_name JumpPad
extends Node3D
## A Darkmatter launch plate (UPDATE 10 §3 Act IV, contract C6 `low_g`, T-158; data map04d.json "low_g.pads"): a
## violet plate in the regolith (and two in the retention hall). Step on it standing and it throws you in a
## ballistic arc onto `target`, `flight_s` seconds in the air under the act's gravity: the yard's long glide over the
## crater, a dash across the yard from the airlock, a hop down the nave. Host-owned (C8): the host sees who stands
## on a plate and launches its own and the bots' players; a remote player's launch is sent to its owner.
## Group `jump_pads` (the bots' routes, C7). Pure rules static for the tests.

@export var target: Vector3 = Vector3.ZERO
@export var flight_s: float = 3.0
@export var radius: float = 1.1
@export var zone_id: StringName = &""

var launches: int = 0
var _cool: Dictionary = {}           # pid -> seconds before this plate takes them again
var _t: float = 0.0
var _ring_mat: StandardMaterial3D
var _flash: float = 0.0
var _light: OmniLight3D


## The launch velocity that carries a body from `from` to `to` in `t` seconds under gravity `g` (m/s²).
static func launch_velocity(from: Vector3, to: Vector3, t: float, g: float) -> Vector3:
	var tt: float = maxf(0.2, t)
	var d: Vector3 = to - from
	return Vector3(d.x / tt, (d.y + 0.5 * g * tt * tt) / tt, d.z / tt)


## The arc's apex above the take-off for a launch velocity under `g`.
static func apex_height(v: Vector3, g: float) -> float:
	return v.y * v.y / (2.0 * maxf(0.01, g))


## Where the arc is `t` seconds after take-off.
static func arc_point(from: Vector3, v: Vector3, g: float, t: float) -> Vector3:
	return from + Vector3(v.x * t, v.y * t - 0.5 * g * t * t, v.z * t)


func _ready() -> void:
	add_to_group(&"jump_pads")
	_build()


func _build() -> void:
	var base: StandardMaterial3D = StandardMaterial3D.new()
	base.albedo_color = Color(0.12, 0.11, 0.15)
	base.metallic = 0.4
	base.roughness = 0.5
	var plate: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = radius + 0.25
	cm.bottom_radius = radius + 0.35
	cm.height = 0.1
	cm.radial_segments = 24
	plate.mesh = cm
	plate.material_override = base
	plate.position = Vector3(0, 0.03, 0)
	add_child(plate)
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.albedo_color = Color(0.75, 0.45, 1.0)
	var ring: MeshInstance3D = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = radius - 0.08
	tm.outer_radius = radius + 0.04
	tm.rings = 24
	tm.ring_segments = 6
	ring.mesh = tm
	ring.material_override = _ring_mat
	ring.scale = Vector3(1, 0.25, 1)
	ring.position = Vector3(0, 0.09, 0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	# a chevron pointing where it throws you
	var dir: Vector3 = target - global_position if is_inside_tree() else target - position
	var yaw: float = atan2(dir.x, dir.z)
	for i: int in 3:
		var chev: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(0.7, 0.02, 0.12)
		chev.mesh = bm
		chev.material_override = _ring_mat
		chev.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var fwd: Vector3 = Vector3(sin(yaw), 0, cos(yaw))
		chev.position = Vector3(0, 0.1, 0) + fwd * (-0.35 + 0.35 * float(i))
		chev.rotation.y = yaw
		add_child(chev)
	var lb: Label3D = Label3D.new()
	lb.text = "LAUNCH"
	lb.font_size = 40
	lb.pixel_size = 0.006
	lb.modulate = Color(0.85, 0.7, 1.0, 0.9)
	lb.rotation = Vector3(-PI * 0.5, yaw + PI, 0)
	lb.position = Vector3(0, 0.1, 0) - Vector3(sin(yaw), 0, cos(yaw)) * 0.85
	add_child(lb)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.72, 0.42, 1.0)
	_light.light_energy = 0.6
	_light.omni_range = 4.0
	_light.shadow_enabled = false
	_light.position = Vector3(0, 0.6, 0)
	if zone_id != &"":
		_light.set_meta("zone", zone_id)
	add_child(_light)


func _physics_process(delta: float) -> void:
	for k: Variant in _cool.keys():
		_cool[k] = float(_cool[k]) - delta
		if float(_cool[k]) <= 0.0:
			_cool.erase(k)
	_flash = maxf(0.0, _flash - delta * 2.0)
	_t += delta
	var pulse: float = 0.6 + 0.4 * sin(_t * 3.0)
	_ring_mat.albedo_color = Color(0.75, 0.45, 1.0) * (0.7 + 0.3 * pulse) + Color(1, 1, 1) * _flash
	_light.light_energy = 0.5 + 0.3 * pulse + 2.0 * _flash
	if not Net.is_authority():
		return
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not p.is_alive() or _cool.has(p.player_id):
			continue
		var d: Vector3 = p.global_position - global_position
		if Vector2(d.x, d.z).length() > radius or absf(d.y) > 0.7:
			continue
		if (p.is_local or p.is_bot) and not p.is_on_floor():
			continue   # a remote player's puppet never reports the floor on the host: the height check stands in
		launch(p)


## Host: throw `p` toward the target (its owner applies it).
func launch(p: Player) -> void:
	_cool[p.player_id] = maxf(1.0, flight_s * 0.5)
	launches += 1
	var v: Vector3 = launch_velocity(p.global_position, target, flight_s, GameState.g_player())
	if p.is_local or p.is_bot:
		p.pad_launch(v, flight_s)
	else:
		Net.mirror(self, &"_net_launch", [p.player_id, v])
	_fx()
	Net.mirror(self, &"_fx", [])
	var lg: Node = get_tree().get_first_node_in_group(&"moon_lowg")
	if lg != null and lg.has_method("pad_used"):
		lg.call("pad_used", p, self)


## A client: the host threw this peer's player.
func _net_launch(pid: int, v: Vector3) -> void:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.player_id == pid and p.is_local:
			p.pad_launch(v, flight_s)


func _fx() -> void:
	_flash = 1.0
	AudioDirector.play_3d("m4d_pad_launch", global_position + Vector3.UP * 0.3, 2.0)
	Effects.dust_puff(global_position + Vector3.UP * 0.1, "earth", 14)
