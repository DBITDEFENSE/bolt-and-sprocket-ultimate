class_name BreachPanel
extends Interactable
## A hull breach panel in the Kranich's wings (UPDATE 07, docs/MAP4_FERNFLUG.md §4.5). Shut, it is a plate in the
## leading-edge wall. `blow()` (the FlightController: on its timer, when a strafing line crosses it, or in sequence
## on a Druckabfall round) opens it: for `seconds` everything within `radius` is sucked toward the hole
## (Player/Zombie.external_push at suction_mps, kind "pull"), the lights dim, the sound goes thin; a zombie that
## reaches the hole is pulled out into the night and dies (nobody's kill unless a player pushed it: 'returned');
## a player can seal it (hold `seal_hold` s) or it seals itself when the time runs out. While open it is a climb
## entry: the Bordschützen rise at it. Pure rules are static for the tests (`suction_for`, `through_hole`).

@export var panel_id: StringName = &"breach"
@export var zone_id: StringName = &""

var is_open: bool = false
var open_t: float = 0.0
var cfg: Dictionary = {}
var times_blown: int = 0
var _plate: MeshInstance3D
var _hole: MeshInstance3D
var _wind: CPUParticles3D
var _light: OmniLight3D
var _whoosh: AudioStreamPlayer3D


## The push a body at `p` gets from a hole at `hole` (flat), zero outside radius; stronger near the hole.
static func suction_for(hole: Vector3, p: Vector3, radius: float, mps: float) -> Vector3:
	var d: Vector3 = hole - p
	d.y = 0.0
	var dist: float = d.length()
	if dist > radius or dist < 0.01:
		return Vector3.ZERO
	return d / dist * mps * (0.6 + 0.4 * (1.0 - dist / radius))


## True when a body at `p` has reached the hole (within `reach` m, flat).
static func through_hole(hole: Vector3, p: Vector3, reach: float = 1.1) -> bool:
	return Vector2(hole.x - p.x, hole.z - p.z).length() <= reach


func _ready() -> void:
	interact_size = Vector3(2.4, 2.2, 0.9)
	interact_offset = Vector3(0, 1.1, 0)
	super._ready()
	add_to_group(&"breach_panels")
	_build()


func _build() -> void:
	_plate = Props.block(self, Vector3(-1.1, 0.1, -0.12), Vector3(1.1, 2.0, 0.12), "feldgrau")
	_hole = Props.block(self, Vector3(-1.0, 0.2, -0.1), Vector3(1.0, 1.9, 0.1), "lead")
	_hole.visible = false
	_light = OmniLight3D.new()
	_light.position = Vector3(0, 1.2, 0.6)
	_light.light_color = Color(0.45, 0.55, 0.9)
	_light.light_energy = 0.0
	_light.omni_range = 7.0
	_light.shadow_enabled = false
	add_child(_light)
	_wind = CPUParticles3D.new()
	_wind.position = Vector3(0, 1.1, 1.0)
	_wind.amount = 60
	_wind.lifetime = 0.8
	_wind.emitting = false
	_wind.direction = Vector3(0, 0, -1)
	_wind.spread = 25.0
	_wind.initial_velocity_min = 6.0
	_wind.initial_velocity_max = 10.0
	_wind.scale_amount_min = 0.03
	_wind.scale_amount_max = 0.08
	_wind.mesh = BoxMesh.new()
	_wind.mesh.set("size", Vector3(0.05, 0.05, 0.3))
	_wind.material_override = Mats.get_mat("lead")
	add_child(_wind)


func hole_pos() -> Vector3:
	return global_position + Vector3(0, 1.0, 0)


## Opens the panel for cfg.seconds (the FlightController's config), unless already open.
func blow(flight_cfg: Dictionary) -> void:
	if is_open:
		return
	cfg = flight_cfg
	is_open = true
	open_t = float(cfg.get("seconds", 8.0))
	times_blown += 1
	_plate.visible = false
	_hole.visible = true
	_light.light_energy = 2.5
	_wind.emitting = true
	AudioDirector.play_3d("grenade_explode", hole_pos(), 6.0, 0.4)
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		if (n as Node3D).global_position.distance_to(hole_pos()) < 14.0:
			n.set("_shake", 0.5)
	print("[breach] %s blown (%d)" % [panel_id, times_blown])


func seal(by_player: int = 0) -> void:
	if not is_open:
		return
	is_open = false
	open_t = 0.0
	_plate.visible = true
	_hole.visible = false
	_light.light_energy = 0.0
	_wind.emitting = false
	AudioDirector.play_3d("board_repair", hole_pos(), 3.0, 0.0)
	print("[breach] %s sealed by %d" % [panel_id, by_player])


func _process(delta: float) -> void:
	if not is_open:
		return
	open_t -= delta
	if open_t <= 0.0:
		seal(0)
		return
	if not Net.is_authority():
		return
	var hole: Vector3 = hole_pos()
	var radius: float = float(cfg.get("radius", 6.0))
	var mps: float = float(cfg.get("suction_mps", 4.0))
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not p.is_alive():
			continue
		var v: Vector3 = suction_for(hole, p.global_position, radius, mps)
		if v != Vector3.ZERO:
			p.external_push(v, 0.15, &"pull")
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	if dir == null:
		return
	for z: Zombie in dir.active_zombies():
		if not z.is_active() or z is HomageBoss:
			continue
		if through_hole(hole, z.global_position):
			z.take_damage(z.hp + 1.0, &"torso", &"breach", 0, &"world")
			continue
		var zv: Vector3 = suction_for(hole, z.global_position, radius, mps)
		if zv != Vector3.ZERO and not z.is_pushed():
			z.external_push(zv, 0.2)


func get_prompt(_player: Player) -> String:
	if not is_open:
		return ""
	return "Hold [%s] to seal the breach" % prompt_key(&"interact")


func can_interact(player: Player) -> bool:
	return is_open and not player.downed


func hold_time(player: Player) -> float:
	var t: float = float(cfg.get("seal_hold", 2.0))
	if player != null and GameState.player_has_trait(player.player_id, &"deacon"):
		t *= float((GLData.table("player")["traits"] as Dictionary).get("deacon_work_speed_mult", 0.85))
	return t


func interact(player: Player) -> void:
	if not Net.is_authority() or not is_open:
		return
	seal(player.player_id)
	feedback_2d(player, "buy", -3.0)
	Net.mirror(self, &"seal", [player.player_id])
