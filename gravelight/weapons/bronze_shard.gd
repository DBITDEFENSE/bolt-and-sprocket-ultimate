class_name BronzeShard
extends Node3D
## A shard of the bell's bronze (T-048), dropped by every 5th Totenglocke kill (Totenglocke.drop_shards). Any
## local player or bot carrying a Totenglocke that isn't full picks it up by walking over it: +1 charge
## (Totenglocke.add_charge). It glints, bobs and spins, blinks in its last 5 s and is gone after `life` s.

const PICK_RADIUS: float = 1.4

var life: float = 25.0
var _t: float = 0.0
var _vis: Node3D
var _light: OmniLight3D
var _base_y: float = 0.0


func _ready() -> void:
	add_to_group(&"bronze_shards")
	_vis = Node3D.new()
	add_child(_vis)
	var mat: Material = Interactable.greybox_mat(Color(0.95, 0.62, 0.28), 2.2)
	for i: int in 3:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var pm: PrismMesh = PrismMesh.new()
		pm.size = Vector3(0.09 - i * 0.02, 0.16 - i * 0.03, 0.025)
		pm.material = mat
		mi.mesh = pm
		mi.position = Vector3((i - 1) * 0.05, 0.0, (i % 2) * 0.03)
		mi.rotation = Vector3(0.2 * i, 0.9 * i, 0.35 * (i - 1))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_vis.add_child(mi)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.65, 0.3)
	_light.omni_range = 2.2
	_light.light_energy = 1.4
	_light.shadow_enabled = false
	add_child(_light)
	_base_y = position.y


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	_vis.rotation.y = _t * 2.4
	_vis.position.y = 0.08 * sin(_t * 3.0)
	var left: float = life - _t
	visible = left > 5.0 or fmod(left, 0.4) > 0.15
	_light.light_energy = 1.0 + 0.6 * sin(_t * 7.0)
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not p.is_alive() or not (p.is_local or p.is_bot):
			continue
		var d: Vector3 = p.global_position - global_position
		if Vector2(d.x, d.z).length() > PICK_RADIUS or absf(d.y) > 2.2:
			continue
		var w: WeaponInstance = p.weapons.find_weapon_base(&"totenglocke")
		if w == null or not Totenglocke.add_charge(w):
			continue
		if p.is_bot:
			AudioDirector.play_3d("totenglocke_shard", global_position, -2.0)
		else:
			AudioDirector.play_2d("totenglocke_shard", -2.0)
		queue_free()
		return
