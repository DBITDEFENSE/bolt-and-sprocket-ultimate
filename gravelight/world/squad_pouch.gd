class_name SquadPouch
extends Interactable
## T-142: a fallen relief-squad soldier's grenade pouch: hold Use to take `grenades` lethal grenades (squads.json
## loot.grenades), up to your carry limit. Free; gone when emptied or after `seconds_left`.

@export var grenades: int = 2
@export var seconds_left: float = 90.0


func _ready() -> void:
	interact_size = Vector3(0.8, 0.8, 0.8)
	interact_offset = Vector3(0, 0.3, 0)
	super._ready()
	add_to_group(&"squad_loot")


func build_greybox() -> void:
	var m: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.24, 0.12, 0.16)
	m.mesh = bm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.33, 0.22)
	mat.roughness = 0.95
	m.material_override = mat
	m.position = Vector3(0, 0.06, 0)
	add_child(m)
	for i: int in 2:
		var g: MeshInstance3D = MeshInstance3D.new()
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = 0.035
		sm.height = 0.08
		g.mesh = sm
		var gm: StandardMaterial3D = StandardMaterial3D.new()
		gm.albedo_color = Color(0.22, 0.25, 0.18)
		gm.metallic = 0.4
		g.material_override = gm
		g.position = Vector3(-0.04 + 0.08 * i, 0.15, 0)
		add_child(g)


func _process(delta: float) -> void:
	if not Net.is_authority():
		return
	seconds_left -= delta
	if seconds_left <= 0.0:
		queue_free()


func get_prompt(player: Player) -> String:
	if player.weapons == null or player.weapons.grenades >= player.weapons.grenade_max():
		return "Grenades full"
	return "Hold [%s] to take the grenades (%d)" % [prompt_key(&"interact"), grenades]


func can_interact(player: Player) -> bool:
	return grenades > 0 and player.weapons != null and player.weapons.grenades < player.weapons.grenade_max()


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	var take: int = mini(grenades, player.weapons.grenade_max() - player.weapons.grenades)
	player.weapons.grenades += take
	grenades -= take
	AudioDirector.play_3d("grenade_pin", global_position, -6.0)
	if grenades <= 0:
		queue_free()
