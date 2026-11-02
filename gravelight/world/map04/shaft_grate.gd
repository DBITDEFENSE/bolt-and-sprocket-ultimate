class_name ShaftGrate
extends Node3D
## The Account's floor vent over the dish's vacuum shaft (UPDATE 10 §3 Act IV, the Bar's row 14, T-158; data
## map04d.json "shaft_grate"): a round steel grate just inside the Account's one door, where the horde comes in.
## Its lever (ShaftGrateLever) opens it for `open_seconds`: the iris folds back, the room's air roars down the shaft
## with a violet glow from below, and every zombie on it is drawn down (a kill, the body dropping out of sight);
## a zombie the Lodestone flings onto the open grate goes the same way. Players on it are thrown clear and hurt,
## never taken. Host-owned (C8): the host opens it and decides who falls; the iris and the falls are mirrored.
## Group `shaft_grate`; flag `shaft_open` while open.

@export var radius: float = 2.4

var open_left: float = 0.0
var taken: int = 0
var cfg: Dictionary = {}
var _slats: Array[Node3D] = []
var _glow: OmniLight3D
var _glow_mat: StandardMaterial3D
var _k: float = 0.0                  # 0 shut .. 1 open (presentation)
var _roar: AudioStreamPlayer3D = null
var _hit_cd: Dictionary = {}


## True when a body at `p` stands on the grate (`r` radius, within 1.2 m of its floor).
static func on_grate(p: Vector3, center: Vector3, r: float) -> bool:
	return Vector2(p.x - center.x, p.z - center.z).length() <= r and absf(p.y - center.y) <= 1.2


func _ready() -> void:
	add_to_group(&"shaft_grate")
	cfg = GLData.load_json("res://data/gravelight/map04d.json").get("shaft_grate", {})
	radius = float(cfg.get("radius_m", radius))
	_build()


func _build() -> void:
	var dark: StandardMaterial3D = StandardMaterial3D.new()
	dark.albedo_color = Color(0.01, 0.01, 0.015)
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var hole: MeshInstance3D = MeshInstance3D.new()
	var hm: CylinderMesh = CylinderMesh.new()
	hm.top_radius = radius
	hm.bottom_radius = radius
	hm.height = 0.02
	hole.mesh = hm
	hole.material_override = dark
	hole.position = Vector3(0, 0.006, 0)
	add_child(hole)
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.albedo_color = Color(0.0, 0.0, 0.0)
	var throat: MeshInstance3D = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = radius * 0.55
	tm.outer_radius = radius * 0.7
	throat.mesh = tm
	throat.material_override = _glow_mat
	throat.scale = Vector3(1, 0.05, 1)
	throat.position = Vector3(0, 0.012, 0)
	add_child(throat)
	var rim_m: StandardMaterial3D = StandardMaterial3D.new()
	rim_m.albedo_color = Color(0.55, 0.55, 0.6)
	rim_m.metallic = 0.5
	rim_m.roughness = 0.4
	var rim: MeshInstance3D = MeshInstance3D.new()
	var rm: TorusMesh = TorusMesh.new()
	rm.inner_radius = radius - 0.05
	rm.outer_radius = radius + 0.18
	rim.mesh = rm
	rim.material_override = rim_m
	rim.scale = Vector3(1, 0.25, 1)
	rim.position = Vector3(0, 0.03, 0)
	add_child(rim)
	var slat_m: StandardMaterial3D = StandardMaterial3D.new()
	slat_m.albedo_color = Color(0.3, 0.3, 0.34)
	slat_m.metallic = 0.6
	slat_m.roughness = 0.45
	var n: int = 8
	for i: int in n:
		var piv: Node3D = Node3D.new()
		piv.rotation.y = TAU * float(i) / float(n)
		add_child(piv)
		var hinge: Node3D = Node3D.new()
		hinge.position = Vector3(0, 0.04, radius - 0.05)
		piv.add_child(hinge)
		var blade: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(2.0 * radius * sin(PI / float(n)) + 0.05, 0.04, radius - 0.05)
		blade.mesh = bm
		blade.material_override = slat_m
		blade.position = Vector3(0, 0, -(radius - 0.05) * 0.5)
		hinge.add_child(blade)
		_slats.append(hinge)
	_glow = OmniLight3D.new()
	_glow.light_color = Color(0.72, 0.42, 1.0)
	_glow.light_energy = 0.0
	_glow.omni_range = 7.0
	_glow.shadow_enabled = false
	_glow.position = Vector3(0, 0.4, 0)
	_glow.set_meta("zone", &"F_CORE")
	add_child(_glow)
	var lb: Label3D = Label3D.new()
	lb.text = "VENT · KEEP CLEAR"
	lb.font_size = 32
	lb.pixel_size = 0.006
	lb.modulate = Color(0.95, 0.75, 0.3, 0.85)
	lb.rotation = Vector3(-PI * 0.5, PI, 0)
	lb.position = Vector3(0, 0.05, radius + 0.45)
	add_child(lb)


func is_open() -> bool:
	return open_left > 0.0


## Host: open for `seconds` (mirrored).
func open_for(seconds: float) -> void:
	_net_open(seconds)
	Net.mirror(self, &"_net_open", [seconds])
	GameState.set_flag(&"shaft_open")


func _net_open(seconds: float) -> void:
	open_left = seconds
	AudioDirector.play_3d("m4d_vent_open", global_position + Vector3.UP, 4.0)
	if _roar == null and AudioDirector.has_sound("m4d_vent_roar"):
		_roar = AudioDirector.make_loop_3d("m4d_vent_roar", self, 2.0)


func _physics_process(delta: float) -> void:
	var was_open: bool = open_left > 0.0
	open_left = maxf(0.0, open_left - delta)
	_k = move_toward(_k, 1.0 if open_left > 0.0 else 0.0, delta * 2.5)
	for h: Node3D in _slats:
		h.rotation.x = -deg_to_rad(84.0) * _k
	_glow.light_energy = 3.0 * _k
	_glow_mat.albedo_color = Color(0.75, 0.45, 1.0) * _k
	if was_open and open_left <= 0.0:
		AudioDirector.play_3d("m4d_vent_close", global_position + Vector3.UP, 2.0)
		if _roar != null and is_instance_valid(_roar):
			_roar.queue_free()
			_roar = null
		if Net.is_authority():
			GameState.set_flag(&"shaft_open", false)
	for k: Variant in _hit_cd.keys():
		_hit_cd[k] = float(_hit_cd[k]) - delta
		if float(_hit_cd[k]) <= 0.0:
			_hit_cd.erase(k)
	if open_left <= 0.0 or _k < 0.6 or not Net.is_authority():
		return
	var dir: Node = get_tree().get_first_node_in_group(&"director")
	if dir != null and dir.has_method("active_zombies"):
		for z: Zombie in dir.call("active_zombies"):
			if z is HomageBoss or not on_grate(z.global_position, global_position, radius):
				continue
			drop(z)
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not p.is_alive() or _hit_cd.has(p.player_id) or not on_grate(p.global_position, global_position, radius):
			continue
		_hit_cd[p.player_id] = 1.0
		var out: Vector3 = Vector3(p.global_position.x - global_position.x, 0, p.global_position.z - global_position.z)
		out = out.normalized() if out.length() > 0.1 else Vector3.BACK
		p.external_push(out * float(cfg.get("push_mps", 7.0)) + Vector3.UP * 3.0, 0.5)
		p.take_hit(float(cfg.get("player_damage", 25.0)), self)


## Host: `z` is drawn down the shaft (a kill; the body drops out of sight).
func drop(z: Zombie) -> void:
	if z == null or not z.is_active():
		return
	var at: Vector3 = z.global_position
	z.take_damage(z.hp + 1.0, &"torso", &"shaft_grate", 0, &"explosive", true)
	if z.state == Zombie.State.DEAD:
		z.set("_death_sink", true)
		z.set("_sink_corpse_s", 1.0)
		var tw: Tween = z.create_tween()
		tw.tween_property(z, "global_position", at - Vector3.UP * 6.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	taken += 1
	_fall_fx(at)
	Net.mirror(self, &"_fall_fx", [at])


func _fall_fx(at: Vector3) -> void:
	Effects.shatter(at + Vector3.UP * 0.6, Color(0.72, 0.45, 1.0), 16, 4.0)
	AudioDirector.play_3d("m4d_vent_fall", at + Vector3.UP, 2.0)
