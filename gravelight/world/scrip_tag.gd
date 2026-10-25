class_name ScripTag
extends Node3D
## Salvage (T-078): a dead soldier's dog tags, dropped by a kill (ScripBonuses). Two small stamped tags on a bead
## chain that glint and turn; they drift to a standing survivor within magnet_m and are picked up within
## pickup_radius (worth `value` Scrip, paid by ScripBonuses). They blink near the end and are gone at lifetime_s.
## The drift runs on every peer (it is only looks); the pickup is decided by the host.

signal collected(by_player: int)

@export var value: int = 100

var _age: float = 0.0
var _cfg: Dictionary = {}
var _icon: Node3D
var _light: OmniLight3D
var _taken: bool = false


func _ready() -> void:
	_cfg = (GLData.table("economy").get("bonuses", {}) as Dictionary).get("salvage", {})
	_light = OmniLight3D.new()
	_light.light_color = Color(0.95, 0.82, 0.5)
	_light.light_energy = 0.9
	_light.omni_range = 2.2
	_light.shadow_enabled = false
	add_child(_light)
	_icon = Node3D.new()
	_icon.name = "Greybox"
	add_child(_icon)
	var steel: StandardMaterial3D = Interactable.greybox_mat(Color(0.78, 0.76, 0.7), 1.0)
	steel.metallic = 0.9
	steel.roughness = 0.35
	Interactable.add_box(_icon, Vector3(0.11, 0.17, 0.012), Vector3(-0.025, 0, 0), steel).rotation.z = 0.18
	Interactable.add_box(_icon, Vector3(0.11, 0.17, 0.012), Vector3(0.03, -0.02, 0.012), steel).rotation.z = -0.22
	Interactable.add_box(_icon, Vector3(0.02, 0.09, 0.008), Vector3(0.0, 0.12, 0.006), Interactable.greybox_mat(Color(0.35, 0.33, 0.3)))


func _process(delta: float) -> void:
	_age += delta
	var life: float = float(_cfg.get("lifetime_s", 20.0))
	var blink: float = float(_cfg.get("blink_from_s", 14.0))
	_icon.rotation.y += delta * 3.0
	_icon.position.y = sin(_age * 3.0) * 0.05
	if _age >= blink:
		var on: bool = fmod(_age * 6.0, 1.0) < 0.55
		_icon.visible = on
		_light.visible = on
	var p: Player = _nearest_standing()
	if p != null:
		var to: Vector3 = (p.global_position + Vector3.UP * 0.8) - global_position
		var d: float = to.length()
		if d < float(_cfg.get("magnet_m", 3.5)):
			global_position += to.normalized() * minf(d, float(_cfg.get("magnet_speed", 6.0)) * delta)
		if not _taken and not Net.is_client() and d < float(_cfg.get("pickup_radius", 1.2)):
			_taken = true
			AudioDirector.play_3d("ui_scrip", global_position, -4.0)
			collected.emit(p.player_id)
			queue_free()
			return
	if _age >= life and not _taken and not Net.is_client():
		_taken = true
		queue_free()


func _nearest_standing() -> Player:
	var best: Player = null
	var bd: float = INF
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or p.downed or p.spectating or p.is_companion:
			continue
		var d: float = p.global_position.distance_squared_to(global_position)
		if d < bd:
			bd = d
			best = p
	return best
