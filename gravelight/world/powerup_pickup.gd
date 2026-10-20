class_name PowerupPickup
extends Area3D
## A dropped power-up. Spins and bobs, glows, blinks near the end of its life, and vanishes.
## Touching it (any player) emits `collected`; the PowerupManager applies the effect.
## Greybox icon per type; a child named "Visual" (swapped-in art) replaces it.

signal collected(by_player: int)

const LAYER_PICKUP: int = 1 << 7
const MASK_PLAYER: int = 1 << 1
const COLORS: Dictionary = {
	&"resupply": Color(0.42, 0.45, 0.25), &"deaths_door": Color(0.92, 0.9, 0.82),
	&"double_scrip": Color(0.95, 0.75, 0.25), &"blackout": Color(0.55, 0.25, 0.95),
	&"fortify": Color(0.55, 0.3, 0.16), &"clearance": Color(0.3, 0.8, 0.4),
}

@export var powerup_id: StringName = &"resupply"

var _age: float = 0.0
var _lifetime: float = 30.0
var _blink_from: float = 22.0
var _icon: Node3D
var _light: OmniLight3D
var _taken: bool = false


func _ready() -> void:
	var cfg: Dictionary = GLData.table("powerups")
	_lifetime = float(cfg["lifetime_seconds"])
	_blink_from = float(cfg["blink_from_seconds"])
	collision_layer = LAYER_PICKUP
	collision_mask = MASK_PLAYER
	monitoring = not Net.is_client()   # co-op: the host decides who touched it
	monitorable = false
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sph: SphereShape3D = SphereShape3D.new()
	sph.radius = float(cfg.get("pickup_radius", 1.1))
	cs.shape = sph
	add_child(cs)
	var col: Color = COLORS.get(powerup_id, Color.WHITE)
	_light = OmniLight3D.new()
	_light.light_color = col.lerp(Color(0.7, 0.4, 1.0), 0.35)
	_light.light_energy = 1.6
	_light.omni_range = 4.0
	_light.shadow_enabled = false
	add_child(_light)
	if has_node("Visual"):
		_icon = get_node("Visual") as Node3D
	else:
		_icon = Node3D.new()
		_icon.name = "Greybox"
		add_child(_icon)
		_build_icon(col)
	body_entered.connect(_on_body_entered)
	# Spawn / grab sounds: AudioDirector, from GLBus.powerup_spawned / powerup_collected.


func _build_icon(col: Color) -> void:
	var m: StandardMaterial3D = Interactable.greybox_mat(col, 1.2)
	match powerup_id:
		&"resupply":   # olive ammo crate with a lid stripe
			Interactable.add_box(_icon, Vector3(0.6, 0.38, 0.4), Vector3.ZERO, m)
			Interactable.add_box(_icon, Vector3(0.64, 0.06, 0.44), Vector3(0, 0.12, 0), Interactable.greybox_mat(Color(0.85, 0.82, 0.6), 1.0))
		&"deaths_door":   # bone-white skull block with dark eye sockets
			Interactable.add_box(_icon, Vector3(0.42, 0.4, 0.4), Vector3(0, 0.04, 0), m)
			Interactable.add_box(_icon, Vector3(0.28, 0.14, 0.3), Vector3(0, -0.2, 0), m)
			var dark: StandardMaterial3D = Interactable.greybox_mat(Color(0.05, 0.03, 0.06))
			Interactable.add_box(_icon, Vector3(0.11, 0.1, 0.02), Vector3(-0.1, 0.08, -0.205), dark)
			Interactable.add_box(_icon, Vector3(0.11, 0.1, 0.02), Vector3(0.1, 0.08, -0.205), dark)
		&"double_scrip":   # gold coin stack
			for i: int in 4:
				var coin: MeshInstance3D = MeshInstance3D.new()
				var cyl: CylinderMesh = CylinderMesh.new()
				cyl.top_radius = 0.2
				cyl.bottom_radius = 0.2
				cyl.height = 0.07
				coin.mesh = cyl
				coin.material_override = m
				coin.position = Vector3(randf_range(-0.03, 0.03), -0.15 + i * 0.09, 0)
				_icon.add_child(coin)
		&"blackout":   # black sphere, violet glow
			var ball: MeshInstance3D = MeshInstance3D.new()
			var sph: SphereMesh = SphereMesh.new()
			sph.radius = 0.26
			sph.height = 0.52
			ball.mesh = sph
			var bm: StandardMaterial3D = Interactable.greybox_mat(Color(0.03, 0.02, 0.05))
			bm.rim_enabled = true
			bm.rim = 1.0
			ball.material_override = bm
			_icon.add_child(ball)
			Interactable.add_box(_icon, Vector3(0.6, 0.03, 0.03), Vector3.ZERO, m)
		&"fortify":   # two crossed boards
			Interactable.add_box(_icon, Vector3(0.7, 0.13, 0.05), Vector3.ZERO, m).rotation.z = 0.6
			Interactable.add_box(_icon, Vector3(0.7, 0.13, 0.05), Vector3(0, 0, 0.04), m).rotation.z = -0.6
		&"clearance":   # green price tag
			Interactable.add_box(_icon, Vector3(0.36, 0.5, 0.04), Vector3.ZERO, m)
			Interactable.add_box(_icon, Vector3(0.08, 0.08, 0.06), Vector3(0, 0.17, 0), Interactable.greybox_mat(Color(0.1, 0.1, 0.1)))
		_:
			Interactable.add_box(_icon, Vector3(0.4, 0.4, 0.4), Vector3.ZERO, m)


func _process(delta: float) -> void:
	_age += delta
	if _icon != null:
		_icon.rotation.y += delta * 1.8
		_icon.position.y = sin(_age * 2.4) * 0.12
	if _age >= _blink_from:
		# Blink faster as the end nears.
		var rate: float = lerpf(4.0, 12.0, clampf((_age - _blink_from) / maxf(0.01, _lifetime - _blink_from), 0.0, 1.0))
		var on: bool = fmod(_age * rate, 1.0) < 0.55
		if _icon != null:
			_icon.visible = on
		_light.visible = on
	if _age >= _lifetime and not _taken:
		_taken = true
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if _taken or not (body is Player) or not (body as Player).is_alive():
		return
	_taken = true
	collected.emit((body as Player).player_id)
	queue_free()
